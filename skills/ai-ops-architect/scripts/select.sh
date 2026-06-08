#!/usr/bin/env bash
# select.sh — Phase 3: user picks 1-3 opportunities from the ranked list.
#
# Reads .state/opportunities-ranked.json (written by recommend.sh), prompts
# for selection, writes .state/selected-builds.json with the chosen IDs +
# resolved runtime per pick. The orchestrator's Phase 5 reads this to
# delegate to /n8n, /managed-agents-setup, or both (hybrid).
#
# Modes:
#   bash scripts/select.sh                     # interactive
#   bash scripts/select.sh --auto 1,3          # CI / non-interactive
#   bash scripts/select.sh --client <slug>     # write to .state/<slug>/selected-builds.json
#
# Cap: 3 picks per session (enforced).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="$ROOT/.state"
CLIENT=""
AUTO_PICKS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO_PICKS="$2"; shift 2 ;;
        --client) CLIENT="$2"; shift 2 ;;
        --help|-h)
            sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ -n "$CLIENT" ]]; then
    STATE_DIR="$STATE_DIR/$CLIENT"
fi
mkdir -p "$STATE_DIR"

RANKED="$STATE_DIR/opportunities-ranked.json"
SELECTED="$STATE_DIR/selected-builds.json"

# Fall back to non-namespaced state if --client is not yet propagated everywhere
if [[ ! -f "$RANKED" && -z "$CLIENT" ]]; then
    RANKED="$ROOT/.state/opportunities-ranked.json"
fi

if [[ ! -f "$RANKED" ]]; then
    echo "ERROR: $RANKED not found. Run 'bash scripts/recommend.sh' first." >&2
    exit 2
fi

PYTHONUTF8=1 RANKED="$RANKED" SELECTED="$SELECTED" AUTO_PICKS="$AUTO_PICKS" python3 - <<'PYEOF'
import json, os, sys
from datetime import datetime, timezone
from pathlib import Path

ranked_path = Path(os.environ["RANKED"])
selected_path = Path(os.environ["SELECTED"])
auto_picks = os.environ.get("AUTO_PICKS", "").strip()

data = json.loads(ranked_path.read_text())
if isinstance(data, list):
    opps = data
elif isinstance(data, dict):
    opps = data.get("opportunities") or data.get("ranked") or list(data.values())
else:
    print("ERROR: ranked file shape unexpected", file=sys.stderr)
    sys.exit(2)
if not isinstance(opps, list):
    print("ERROR: opportunities not a list after flattening", file=sys.stderr)
    sys.exit(2)

top = opps[:5]
print()
print("Top 5 opportunities for you:")
print("-" * 60)
for i, opp in enumerate(top, 1):
    name = opp.get("title") or opp.get("id") or f"#{i}"
    runtime = opp.get("runtime", "?")
    fit = opp.get("score") or opp.get("fit") or "?"
    desc = (opp.get("description") or "")[:80]
    print(f"  {i}. [{runtime:^7}]  {name}")
    print(f"     fit: {fit}  | {desc}")
print("-" * 60)
print("Cap: pick 1-3. Quality > volume.")
print()

if auto_picks:
    raw = auto_picks
    print(f"--auto mode: picking {raw}")
else:
    try:
        raw = input("Your picks (comma-separated indices, e.g. 1,3): ").strip()
    except EOFError:
        print("ERROR: no stdin (use --auto N,M for non-interactive)", file=sys.stderr)
        sys.exit(2)

try:
    picks = [int(x.strip()) for x in raw.split(",") if x.strip()]
except ValueError:
    print(f"ERROR: bad picks '{raw}' — expect '1', '1,2', '1,2,3'", file=sys.stderr)
    sys.exit(2)

if not 1 <= len(picks) <= 3:
    print(f"ERROR: pick 1-3 items, got {len(picks)}", file=sys.stderr)
    sys.exit(2)
if any(p < 1 or p > len(top) for p in picks):
    print(f"ERROR: indices must be 1..{len(top)}", file=sys.stderr)
    sys.exit(2)

selected_opps = [top[p - 1] for p in picks]

# Atomic write via tmpfile + os.replace
out = {
    "selected_at": datetime.now(timezone.utc).isoformat(),
    "count": len(selected_opps),
    "builds": [
        {
            "id": opp.get("id") or opp.get("title"),
            "title": opp.get("title") or opp.get("id"),
            "runtime": opp.get("runtime", "n8n"),
            "score": opp.get("score") or opp.get("fit"),
            "delegate_to": (
                "/managed-agents-setup" if opp.get("runtime") == "managed-agents"
                else "/n8n" if opp.get("runtime") == "n8n"
                else "hybrid:/n8n+/managed-agents-setup" if opp.get("runtime") == "hybrid"
                else "/n8n"
            ),
        }
        for opp in selected_opps
    ],
}
tmp = selected_path.with_suffix(".json.tmp")
tmp.write_text(json.dumps(out, indent=2))
os.replace(tmp, selected_path)
selected_path.chmod(0o600)

print()
print(f"Selected {len(selected_opps)} build(s):")
for b in out["builds"]:
    print(f"  - {b['title']:<40} -> {b['delegate_to']}")
print()
print(f"Wrote: {selected_path}")
print("Next: orchestrator delegates each pick to its runtime in Phase 5.")
PYEOF
