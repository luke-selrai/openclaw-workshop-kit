#!/usr/bin/env bash
# claude-passthrough.sh — Tier 1 connector detector
# Runs `claude mcp list` and reports which services are reachable via:
#   Tier 1            — claude.ai passthrough, OAuth'd, ready to reuse
#   Tier 1-needs-auth — added but user hasn't OAuth'd yet (one click)
#   Tier 3            — direct MCP server installed (Rube, GHL, etc.)
#
# Usage:
#   claude-passthrough.sh                     # full inventory
#   claude-passthrough.sh Gmail Notion        # check specific services
#   claude-passthrough.sh --json Gmail        # machine-readable output
#
# Exit code: 0 if all requested services are reachable; 1 otherwise.
set -u

JSON_OUT=0
if [[ "${1:-}" == "--json" ]]; then JSON_OUT=1; shift; fi

if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude CLI not on PATH. Install Claude Code first." >&2
    exit 2
fi

# claude mcp list does network health checks; can take 20s+. Capture once.
RAW=$(claude mcp list 2>/dev/null) || RAW=""

# Hand off everything to Python — no bash loops, no pipe weirdness.
RAW="$RAW" JSON_OUT="$JSON_OUT" SERVICES="$*" PYTHONUTF8=1 python3 - <<'PYEOF'
import json, os, re, sys

raw = os.environ.get("RAW", "")
json_out = os.environ.get("JSON_OUT", "0") == "1"
services = [s for s in (os.environ.get("SERVICES", "") or "").split() if s]

# --- Parse `claude mcp list` output ---
connected, needs_auth, direct, failed = [], [], [], []
for line in raw.splitlines():
    m = re.match(r'^claude\.ai (.+?):\s+\S+\s*-\s*(.+)$', line)
    if m:
        name, status = m.group(1), m.group(2)
        if 'Connected' in status:
            connected.append(name)
        elif 'Needs authentication' in status:
            needs_auth.append(name)
        continue
    # plugin:namespace:server: <transport> - <status>  (2026 plugin format)
    mp = re.match(r'^plugin:([^:]+):([^:]+):\s+\S+.*-\s+(.+)$', line)
    if mp:
        name = f"plugin:{mp.group(1)}:{mp.group(2)}"
        status = mp.group(3)
        if 'Connected' in status:
            direct.append(name)
        elif 'Needs authentication' in status:
            needs_auth.append(name)
        elif 'Failed' in status or '✗' in status:
            failed.append(name)
        continue
    m2 = re.match(r'^([a-zA-Z0-9_-]+):\s+\S+\s*-\s*(.+)$', line)
    if m2 and not line.startswith('claude.ai') and not line.startswith('plugin:'):
        if 'Connected' in m2.group(2):
            direct.append(m2.group(1))
        elif '✗' in m2.group(2) or 'Failed' in m2.group(2):
            failed.append(m2.group(1))

connected = sorted(set(connected))
needs_auth = sorted(set(needs_auth))
direct = sorted(set(direct))
failed = sorted(set(failed))

# --- No args: print full inventory ---
if not services:
    if json_out:
        print(json.dumps({
            "connected": connected,
            "needs_auth": needs_auth,
            "direct": direct,
            "failed": failed,
        }))
        sys.exit(0)
    print("Tier 1 — claude.ai passthrough (CONNECTED, reuse free):")
    print("\n".join(f"  - {s}" for s in connected) if connected else "  (none)")
    print()
    if needs_auth:
        print("Tier 1 — claude.ai passthrough (added but NEEDS OAUTH, one click in claude.ai):")
        print("\n".join(f"  - {s}" for s in needs_auth))
        print()
    print("Tier 3 — direct MCP servers (CONNECTED):")
    print("\n".join(f"  - {s}" for s in direct) if direct else "  (none — Rube goes here when added)")
    if failed:
        print()
        print("FAILED / unreachable (check OAuth or network):")
        print("\n".join(f"  - {s}" for s in failed))
    sys.exit(0)

# --- Args: check each service ---
def find_match(needed, lst):
    n = needed.lower()
    for entry in lst:
        if entry.lower() == n or n in entry.lower():
            return entry
    return None

hits, missing = [], []
for svc in services:
    m = find_match(svc, connected)
    if m:
        hits.append({"service": svc, "tier": "tier1", "server": m})
        continue
    m = find_match(svc, needs_auth)
    if m:
        hits.append({"service": svc, "tier": "tier1-needs-oauth", "server": m})
        continue
    m = find_match(svc, direct)
    if m:
        hits.append({"service": svc, "tier": "tier3", "server": m})
        continue
    missing.append(svc)

if json_out:
    print(json.dumps({"hits": hits, "missing": missing}))
else:
    if hits:
        print("Reusable (skip Tier 2/3/4 setup):")
        for h in hits:
            print(f"  {h['service']} = {h['tier']} : {h['server']}")
    if missing:
        print("Need Tier 2 (Rube) / Tier 3 (direct) / Tier 4 (manual) setup:")
        for m in missing:
            print(f"  {m}")

sys.exit(0 if not missing else 1)
PYEOF
