#!/usr/bin/env python3
"""Generate `.mcp.json` content + env-var manifest from a resolution document.

Input is the JSON from map_deps_to_connectors.py. For each MCP server:

- HTTP servers: emit url + headers. User-specific header values (per
  resolution["mcp_servers"][n]["env_var_headers"]) get replaced with
  `${ENV_VAR_NAME}` placeholders in `.mcp.json`. The original values land in
  the env_vars list — to be pasted into the routine env config by the user.
- stdio servers: emit command + args + env. Anything in `env` whose key looks
  user-specific gets the same treatment.

For `Authorization: Bearer <token>` headers, the env var holds just the token
(no Bearer prefix) and the `.mcp.json` keeps `Bearer ${ENV_VAR}` — this lets
users rotate tokens without thinking about the prefix.

The default env-var name for header X on server S is `<S_UPPER>_<X_UPPER>` with
camelCase split on underscores (so `locationId` -> `LOCATION_ID`). The
`Authorization` header is special-cased to `<S_UPPER>_TOKEN` since it almost
always carries a bearer token. Override any name via --name-overrides which
takes a JSON file mapping `<server>.<header>` to a custom env var name.

Real env-var values are secrets. By default they are MASKED on stdout so they
never enter the model's chat context; pass --out to write the real bundle to a
file (gitignored scratch) for the env-capture step to read. Use --no-redact to
print raw values on stdout.

Usage:
    python3 generate_mcp_json.py <resolution.json> --out <bundle.json> \\
        [--name-overrides <overrides.json>] [--no-redact]
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from secret_redaction import redactMcpBundle, looksRedacted


def splitCamelCase(name):
    # locationId -> location Id -> LOCATION_ID ; XApiKey -> X Api Key
    spaced = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", name)
    return spaced


def defaultEnvVarName(serverName, headerName):
    server = re.sub(r"[^A-Za-z0-9]+", "_", serverName).upper().strip("_")
    # Authorization headers almost always carry a bearer token — name it cleanly.
    if headerName.lower() == "authorization":
        return f"{server}_TOKEN"
    header = re.sub(r"[^A-Za-z0-9]+", "_", splitCamelCase(headerName)).upper().strip("_")
    return f"{server}_{header}"


def splitBearerPrefix(value):
    """If value looks like 'Bearer <token>', return ('Bearer ', '<token>').
    Otherwise return ('', value). The prefix stays inline; the token goes to env."""
    if isinstance(value, str) and value.startswith("Bearer "):
        return "Bearer ", value[len("Bearer "):]
    return "", value


def renderHttpServer(server, nameOverrides):
    headers = server.get("headers", {}) or {}
    envVarHeaders = set(server.get("env_var_headers", []) or [])
    serverName = server["name"]
    newHeaders = {}
    envVarRecords = []
    for headerName, headerValue in headers.items():
        if headerName in envVarHeaders:
            overrideKey = f"{serverName}.{headerName}"
            envName = nameOverrides.get(overrideKey) or defaultEnvVarName(serverName, headerName)
            prefix, secretValue = splitBearerPrefix(headerValue)
            newHeaders[headerName] = f"{prefix}${{{envName}}}"
            envVarRecords.append({
                "name": envName,
                "value": secretValue,
                "purpose": f"{serverName} MCP {headerName} header",
            })
        else:
            newHeaders[headerName] = headerValue
    mcpEntry = {
        "type": "http",
        "url": server["url"],
        "headers": newHeaders,
    }
    return mcpEntry, envVarRecords


def renderStdioServer(server, nameOverrides):
    serverName = server["name"]
    envBlock = server.get("env", {}) or {}
    newEnv = {}
    envVarRecords = []
    # Heuristic: stdio env keys that look like all-caps env vars stay as-is
    # but their values get env-var substituted if they appear to be secrets.
    for k, v in envBlock.items():
        # Heuristic for "is this value a secret?": treat any non-empty string
        # value as user-specific by default for stdio MCPs (most stdio env
        # entries are tokens or paths the user shouldn't bake in).
        if isinstance(v, str) and v:
            envName = nameOverrides.get(f"{serverName}.{k}") or defaultEnvVarName(serverName, k)
            prefix, secretValue = splitBearerPrefix(v)
            newEnv[k] = f"{prefix}${{{envName}}}"
            envVarRecords.append({
                "name": envName,
                "value": secretValue,
                "purpose": f"{serverName} stdio MCP env {k}",
            })
        else:
            newEnv[k] = v
    mcpEntry = {
        "command": server["command"],
        "args": server.get("args", []),
    }
    if newEnv:
        mcpEntry["env"] = newEnv
    return mcpEntry, envVarRecords


def generate(resolution, nameOverrides):
    mcpServers = {}
    envVars = []
    for server in resolution.get("mcp_servers", []):
        if server.get("type") == "http":
            entry, records = renderHttpServer(server, nameOverrides)
        elif server.get("type") == "stdio":
            entry, records = renderStdioServer(server, nameOverrides)
        else:
            continue
        mcpServers[server["name"]] = entry
        envVars.extend(records)
    return {
        "mcp_json": {"mcpServers": mcpServers},
        "env_vars": envVars,
    }


def resolutionLooksRedacted(resolution):
    """Guard against being fed a redacted resolution (e.g. from an old
    `map_deps... > file` pattern). Masked header values can't produce real
    env vars, so fail loud rather than silently emitting placeholders."""
    for server in resolution.get("mcp_servers", []):
        for v in (server.get("headers", {}) or {}).values():
            if looksRedacted(v):
                return True
        for v in (server.get("env", {}) or {}).values():
            if looksRedacted(v):
                return True
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("resolution", help="Resolution JSON from map_deps_to_connectors.py")
    parser.add_argument("--name-overrides", default=None,
                        help="JSON file mapping <server>.<header|env-key> to a custom env-var name")
    parser.add_argument("--out", default=None,
                        help="Write the REAL (unredacted) bundle to this file for the env-capture step")
    parser.add_argument("--no-redact", action="store_true",
                        help="Print raw secret values to stdout (default masks them)")
    args = parser.parse_args()

    try:
        with open(args.resolution) as f:
            resolution = json.load(f)
    except FileNotFoundError:
        print(f"generate_mcp_json: resolution not found: {args.resolution}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"generate_mcp_json: invalid resolution JSON ({e})", file=sys.stderr)
        sys.exit(1)

    if resolutionLooksRedacted(resolution):
        print("generate_mcp_json: resolution contains redacted values — re-run "
              "map_deps_to_connectors.py with --out <file> and pass that file here.",
              file=sys.stderr)
        sys.exit(2)

    nameOverrides = {}
    if args.name_overrides:
        try:
            with open(args.name_overrides) as f:
                nameOverrides = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"generate_mcp_json: invalid overrides ({e})", file=sys.stderr)
            sys.exit(1)

    output = generate(resolution, nameOverrides)

    # Real values always go to --out (gitignored scratch); stdout masked by default.
    if args.out:
        with open(args.out, "w") as f:
            json.dump(output, f, indent=2)

    forDisplay = output if args.no_redact else redactMcpBundle(output)
    sys.stdout.write(json.dumps(forDisplay, indent=2))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
