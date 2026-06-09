#!/usr/bin/env python3
"""Map an introspected skill manifest to existing connectors and MCP configs.

Takes the dependency manifest emitted by introspect_skill.py and walks two
resources:

1. An optional connector library — one folder per CLI tool (gws, gh,
   claude-oauth, ...), each with detect.sh, export.sh, server-install.sh,
   server-import.sh (and optionally routine-export.sh + routine-restore.sh for
   routine-target use). The library is an accelerator, not a requirement: point
   at one with --connectors-dir or the ROUTINE_CONNECTORS_DIR env var. If
   neither is set, no CLI is matched here and every dependency falls through to
   the resolution ladder in SKILL.md (the intended path on a machine without a
   library).

2. The user's ~/.claude.json `mcpServers` section — the canonical source for
   how the user's MCP servers are configured locally. Filtered to just the
   servers the skill actually uses.

Output is a resolution document the rest of the plugin pipeline consumes
(generate_setup_sh.py, generate_mcp_json.py, the env-var capture loop in
SKILL.md).

The resolution contains REAL MCP header values (secrets). By default they are
MASKED on stdout so they never enter the model's chat context; pass --out to
write the real resolution to a file (in the gitignored scratch folder) for the
next pipeline step to read. Use --no-redact only when you deliberately need the
raw values on stdout (e.g. piping to another tool).

Usage:
    python3 map_deps_to_connectors.py <manifest.json> --out <resolution.json> \\
        [--connectors-dir <path>] \\
        [--claude-json <path>] [--no-redact]
"""
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from secret_redaction import redactResolution

# No machine-specific default: the connector library is optional. Set it
# explicitly via --connectors-dir or the ROUTINE_CONNECTORS_DIR env var. When
# unset, CLI matching is skipped and everything resolves via the ladder.
DEFAULT_CONNECTORS_DIR = os.environ.get("ROUTINE_CONNECTORS_DIR")
DEFAULT_CLAUDE_JSON = Path.home() / ".claude.json"

# CLIs that exist in the routine sandbox by default and don't need a connector.
BASE_TOOLS = {"python3", "python", "node", "npx", "bash", "sh", "jq", "curl", "wget", "git"}

# Header keys whose values vary per user — secret or identifier — and must
# move to env vars so the .mcp.json is portable across users.
# Case-insensitive substring match.
USER_SPECIFIC_HEADER_HINTS = (
    "authorization", "token", "apikey", "api-key", "api_key", "secret", "bearer",
    "id",  # catches locationId, workspaceId, accountId, tenantId, etc.
    "x-team", "x-account", "x-tenant", "x-workspace",
)

# Header keys whose values are conventionally static across users.
# Checked first; a match here overrides USER_SPECIFIC matching.
STATIC_HEADER_HINTS = (
    "content-type", "accept", "user-agent", "version", "x-api-version",
)


def detectIsUserSpecificHeader(headerName):
    lowered = headerName.lower()
    if any(hint in lowered for hint in STATIC_HEADER_HINTS):
        return False
    return any(hint in lowered for hint in USER_SPECIFIC_HEADER_HINTS)


def loadManifest(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"map_deps_to_connectors: manifest not found: {path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"map_deps_to_connectors: invalid manifest JSON ({e})", file=sys.stderr)
        sys.exit(1)


def loadClaudeJson(path):
    try:
        with open(path) as f:
            d = json.load(f)
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError:
        return {}
    return d.get("mcpServers", {}) or {}


def matchCli(connectorsDir, cliName):
    if not connectorsDir:
        return None
    connectorPath = Path(connectorsDir) / cliName
    if not connectorPath.is_dir():
        return None
    if not (connectorPath / "detect.sh").is_file():
        return None
    detectPassed = False
    try:
        result = subprocess.run(
            ["bash", str(connectorPath / "detect.sh")],
            capture_output=True,
            timeout=10,
        )
        detectPassed = result.returncode == 0
    except (subprocess.TimeoutExpired, OSError):
        detectPassed = False
    return {
        "dep_name": cliName,
        "connector_path": str(connectorPath),
        "detect_passed": detectPassed,
        "has_routine_export": (connectorPath / "routine-export.sh").is_file(),
        "has_routine_restore": (connectorPath / "routine-restore.sh").is_file(),
    }


def classifyMcp(name, config):
    if not isinstance(config, dict):
        return None
    if config.get("url"):
        headers = config.get("headers", {}) or {}
        envVarHeaders = sorted(h for h in headers if detectIsUserSpecificHeader(h))
        return {
            "name": name,
            "type": "http",
            "url": config["url"],
            "headers": headers,
            "env_var_headers": envVarHeaders,
        }
    if config.get("command"):
        return {
            "name": name,
            "type": "stdio",
            "command": config["command"],
            "args": config.get("args", []),
            "env": config.get("env", {}) or {},
        }
    return None


def mapDeps(manifest, connectorsDir, claudeJsonPath):
    matchedConnectors = []
    unmatchedClis = []
    baseTools = []
    mcpServers = []
    unknownMcps = []

    for cli in manifest.get("clis", []):
        if cli in BASE_TOOLS:
            baseTools.append(cli)
            continue
        match = matchCli(connectorsDir, cli)
        if match:
            matchedConnectors.append(match)
        else:
            unmatchedClis.append(cli)

    mcpConfigs = loadClaudeJson(claudeJsonPath)
    for serverName in manifest.get("mcp_servers", []):
        config = mcpConfigs.get(serverName)
        if config is None:
            unknownMcps.append(serverName)
            continue
        classified = classifyMcp(serverName, config)
        if classified:
            mcpServers.append(classified)
        else:
            unknownMcps.append(serverName)

    return {
        "skill_name": manifest.get("name"),
        "matched_connectors": matchedConnectors,
        "unmatched_clis": sorted(unmatchedClis),
        "base_tools": sorted(baseTools),
        "mcp_servers": mcpServers,
        "unknown_mcps": sorted(unknownMcps),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", help="Path to manifest JSON from introspect_skill.py")
    parser.add_argument("--connectors-dir", default=DEFAULT_CONNECTORS_DIR,
                        help="Optional connector library dir (or set ROUTINE_CONNECTORS_DIR); unset = ladder handles all")
    parser.add_argument("--claude-json", default=str(DEFAULT_CLAUDE_JSON))
    parser.add_argument("--out", default=None,
                        help="Write the REAL (unredacted) resolution to this file for the next pipeline step")
    parser.add_argument("--no-redact", action="store_true",
                        help="Print raw secret values to stdout (default masks them)")
    args = parser.parse_args()

    manifest = loadManifest(args.manifest)
    resolution = mapDeps(manifest, args.connectors_dir, args.claude_json)

    # Real values always go to --out (gitignored scratch); stdout is masked by default.
    if args.out:
        with open(args.out, "w") as f:
            json.dump(resolution, f, indent=2)

    forDisplay = resolution if args.no_redact else redactResolution(resolution)
    sys.stdout.write(json.dumps(forDisplay, indent=2))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
