#!/usr/bin/env python3
"""
build-hybrid-tool.py — convert an n8n webhook into a managed-agent tool spec.

In a hybrid build, the managed agent calls n8n workflows as custom tools.
This script writes a JSON tool definition that gets passed to
`/managed-agents-setup` Phase 4 (create-agent.sh --tools <file>).

Workshop attendees never see this file directly — the orchestrator runs it
between Phase 5 (n8n build complete) and Phase 4 of managed-agents (agent
creation).

Usage:
    build-hybrid-tool.py \
        --name qualify_lead \
        --description "Score an inbound lead as hot, warm, or cold" \
        --webhook-url https://selrai.app.n8n.cloud/webhook/qualify-lead \
        --inputs email:string,company:string,message:string \
        --output-shape '{"tier":"string","confidence":"number"}'

Multiple tools at once:
    build-hybrid-tool.py --bundle agent-tools.txt > tools.json

Where agent-tools.txt has one --name=... --description=... --webhook-url=...
per line.
"""
import argparse
import json
import re
import shlex
import sys
from pathlib import Path


SUPPORTED_TYPES = {"string", "number", "integer", "boolean", "array", "object"}
NAME_RE = re.compile(r"^[a-zA-Z0-9_-]{1,64}$")


def validate_name(name, kind):
    """Validate a tool/property name against ^[a-zA-Z0-9_-]{1,64}$.

    Errors with a clear message instead of producing a malformed tool spec.
    """
    if name is None or not NAME_RE.match(name):
        print(
            f"ERROR: {kind} name {name!r} is invalid; must match "
            f"^[a-zA-Z0-9_-]{{1,64}}$ (1-64 chars, letters/digits/_/- only)",
            file=sys.stderr,
        )
        sys.exit(2)
    return name


def parse_inputs(inputs_csv):
    """Parse 'email:string,company:string,message:string' into JSON Schema properties."""
    if not inputs_csv:
        return {}, []
    properties = {}
    required = []
    for spec in inputs_csv.split(","):
        spec = spec.strip()
        if not spec:
            continue
        if ":" in spec:
            name, typ = spec.split(":", 1)
            name, typ = name.strip(), typ.strip()
        else:
            name, typ = spec, "string"
        if typ.endswith("?"):
            typ = typ[:-1]
            optional = True
        else:
            optional = False
        if typ not in SUPPORTED_TYPES:
            print(f"WARN: unsupported type '{typ}' for '{name}', defaulting to string", file=sys.stderr)
            typ = "string"
        validate_name(name, "property")
        properties[name] = {"type": typ}
        if not optional:
            required.append(name)
    return properties, required


def build_tool(name, description, webhook_url, inputs_csv, output_shape):
    """Return a managed-agent custom tool spec dict.

    Two layers in the output:
    - The Anthropic-compliant tool spec (name, description, input_schema)
      that gets passed straight to the API. NO type/url/method fields —
      Anthropic's tool spec doesn't have a webhook routing layer.
    - A `_dispatch` block consumed by the caller (create-agent.sh) to know
      where to POST when this tool fires. The caller code dispatches the
      actual webhook after receiving the tool_use block.
    """
    validate_name(name, "tool")
    properties, required = parse_inputs(inputs_csv)
    tool = {
        "name": name,
        "description": description,
        "input_schema": {
            "type": "object",
            "properties": properties,
            "required": required,
        },
        "_dispatch": {
            "transport": "webhook",
            "url": webhook_url,
            "method": "POST",
            "runtime": "n8n",
            "pattern": "hybrid",
            "ownership": "n8n owns the credential, agent never sees raw API keys",
        },
    }
    if output_shape:
        try:
            tool["_dispatch"]["output_shape"] = json.loads(output_shape)
        except json.JSONDecodeError:
            print(f"WARN: --output-shape is not valid JSON, ignoring", file=sys.stderr)
    return tool


def parse_bundle_line(line):
    """Parse one line of bundle file into kwargs for build_tool."""
    kwargs = {}
    line = line.strip()
    if not line or line.startswith("#"):
        return None
    parts = shlex.split(line)
    for p in parts:
        if p.startswith("--name="):
            kwargs["name"] = p[len("--name="):]
        elif p.startswith("--description="):
            kwargs["description"] = p[len("--description="):]
        elif p.startswith("--webhook-url="):
            kwargs["webhook_url"] = p[len("--webhook-url="):]
        elif p.startswith("--inputs="):
            kwargs["inputs_csv"] = p[len("--inputs="):]
        elif p.startswith("--output-shape="):
            kwargs["output_shape"] = p[len("--output-shape="):]
    return kwargs


def main():
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--name", help="Tool name (snake_case), e.g. qualify_lead")
    ap.add_argument("--description", help="One-line description Claude reads to decide when to call this tool")
    ap.add_argument("--webhook-url", help="The n8n webhook URL (must be production webhook, not test)")
    ap.add_argument("--inputs", default="", help="CSV of name:type pairs, e.g. 'email:string,company:string'")
    ap.add_argument("--output-shape", default="", help="JSON describing what the workflow returns (for docs only)")
    ap.add_argument("--bundle", help="Path to a file with one --name=... --description=... --webhook-url=... per line")
    ap.add_argument("--out", help="Write to this path instead of stdout")
    args = ap.parse_args()

    tools = []

    if args.bundle:
        path = Path(args.bundle)
        if not path.exists():
            print(f"ERROR: bundle file not found: {path}", file=sys.stderr)
            sys.exit(2)
        for line in path.read_text(encoding='utf-8').splitlines():
            kwargs = parse_bundle_line(line)
            if not kwargs:
                continue
            if "name" not in kwargs or "description" not in kwargs or "webhook_url" not in kwargs:
                print(f"WARN: skipping incomplete bundle line: {line[:80]}", file=sys.stderr)
                continue
            tools.append(build_tool(
                name=kwargs["name"],
                description=kwargs["description"],
                webhook_url=kwargs["webhook_url"],
                inputs_csv=kwargs.get("inputs_csv", ""),
                output_shape=kwargs.get("output_shape", ""),
            ))
    elif args.name is not None or args.description is not None or args.webhook_url is not None:
        # Single-tool path: name the missing/blank field instead of falling
        # through to the unhelpful full help text.
        missing = [
            field
            for field, value in (
                ("--name", args.name),
                ("--description", args.description),
                ("--webhook-url", args.webhook_url),
            )
            if value is None or not value.strip()
        ]
        if missing:
            print(
                f"ERROR: missing or empty required field(s): {', '.join(missing)}",
                file=sys.stderr,
            )
            sys.exit(2)
        tools.append(build_tool(
            name=args.name,
            description=args.description,
            webhook_url=args.webhook_url,
            inputs_csv=args.inputs,
            output_shape=args.output_shape,
        ))
    else:
        ap.print_help()
        sys.exit(2)

    # Reject duplicate tool names before writing anything.
    seen = set()
    for t in tools:
        n = t["name"]
        if n in seen:
            print(f"ERROR: duplicate tool name: {n!r}", file=sys.stderr)
            sys.exit(2)
        seen.add(n)

    # A --bundle that yields no tools is an error, not an empty success.
    if not tools:
        print("ERROR: no tools produced (bundle had no valid tool lines)", file=sys.stderr)
        sys.exit(2)

    output = json.dumps({"tools": tools}, indent=2)

    if args.out:
        Path(args.out).write_text(output + "\n", encoding='utf-8')
        print(f"Wrote {len(tools)} tool(s) to {args.out}")
    else:
        print(output)


if __name__ == "__main__":
    main()
