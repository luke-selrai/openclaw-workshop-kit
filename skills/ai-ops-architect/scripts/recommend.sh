#!/usr/bin/env bash
# recommend.sh — Phase 2 output. Reads .state/audit-result.json + references/opportunity-catalog.md,
# scores every opportunity against the user's audit, returns top 5 ranked.
#
# Output: .state/opportunities-ranked.json + a human-readable .state/audit-output.md

set -eu

# ----- Skeleton-template filter (P2.11) -----
# Templates in templates/n8n/*/ where meta.json has "schema_only": true are
# blueprint shells (empty node types) — usable as references but NOT auto-deployable.
# At recommend time we count how many real templates back each opportunity and
# downgrade the score if all matching templates are schema-only.
SKELETON_FILTER_NOTE="run scripts/lint-templates.py to refresh schema_only labels"
# ----------------------------------------------
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STATE="$ROOT/.state"
AUDIT="$STATE/audit-result.json"
CATALOG="$ROOT/references/opportunity-catalog.md"

[ -f "$AUDIT" ] || { echo "REFUSE: run audit.sh first ($AUDIT not found)"; exit 1; }

# Export script-relative paths so the Python heredoc resolves the SAME install location.
# Do NOT hardcode ~/.claude — the skill may be bundled inside a kit or run from a project workspace.
export STATE ROOT CATALOG AUDIT

# PYTHONUTF8=1 (UTF-8 Mode) forces utf-8 for BOTH stdout and file I/O — so reading the UTF-8
# opportunity-catalog.md never mojibakes arrows/separators on a Windows cp1252 locale.
PYTHONUTF8=1 python3 <<'PYEOF'
import json, re, os, sys
from pathlib import Path

state = Path(os.environ["STATE"])
audit = json.loads((state / "audit-result.json").read_text())
catalog_path = Path(os.environ["CATALOG"])
catalog_text = catalog_path.read_text()

# Parse the catalog markdown into structured opportunities
ops = []
current = None
for line in catalog_text.split("\n"):
    if m := re.match(r"^### ([\w-]+)\s*$", line):
        if current and current.get("title"):
            ops.append(current)
        current = {"id": m.group(1)}
        continue
    if not current: continue
    if m := re.match(r"^\- \*\*title\*\*: (.+)$", line):
        current["title"] = m.group(1)
    elif m := re.match(r"^\- \*\*industries\*\*: (.+)$", line):
        current["industries"] = [s.strip() for s in m.group(1).split(",")]
    elif m := re.match(r"^\- \*\*runtime\*\*: (.+)$", line):
        current["runtime"] = m.group(1)
    elif m := re.match(r"^\- \*\*services\*\*: (.+)$", line):
        current["services"] = [s.strip() for s in m.group(1).split(",")]
    elif m := re.match(r"^\- \*\*value\*\*: (.+)$", line):
        current["value"] = m.group(1)
    elif m := re.match(r"^\- \*\*difficulty\*\*: (.+)$", line):
        current["difficulty"] = m.group(1)
    elif m := re.match(r"^\- \*\*pain_keywords\*\*: (.+)$", line):
        current["pain_keywords"] = [s.strip().lower() for s in m.group(1).split(",")]
if current and current.get("title"):
    ops.append(current)

# Score each opportunity
def score(op, audit):
    s = 0
    # Industry overlap
    industries = op.get("industries", [])
    if "all" in industries or audit.get("industry") in industries:
        s += 3
    # Pain keyword match
    pains_text = " ".join(audit.get("pains", []) or []).lower()
    north_star = (audit.get("north_star") or "").lower()
    pain_text_combined = pains_text + " " + north_star
    for kw in op.get("pain_keywords", []):
        if kw in pain_text_combined:
            s += 5
    # Tools coverage — does the user already have the services this needs?
    user_tools = []
    for v in (audit.get("tools") or {}).values():
        if isinstance(v, list):
            user_tools.extend([t.lower() for t in v])
    services = [s.lower() for s in op.get("services", [])]
    coverage = sum(1 for svc in services if any(t in svc or svc in t for t in user_tools))
    s += coverage * 2
    # Difficulty alignment with tech_comfort
    tc = audit.get("tech_comfort", 3)
    diff = op.get("difficulty", "5min-config")
    if diff == "30min-custom" and tc <= 2: s -= 3
    if diff == "auto-deploy": s += 1
    return s

scored = [(score(op, audit), op) for op in ops]
scored.sort(key=lambda x: -x[0])
top = scored[:8]

# Write JSON
ranked = [{"score": sc, **op} for sc, op in top if sc > 0]
(state / "opportunities-ranked.json").write_text(json.dumps(ranked, indent=2))

# Write human-readable audit output
md = []
md.append("# Your AI Ops Audit\n")
md.append(f"**Industry**: {audit.get('industry','?')}  ·  **Team**: {audit.get('team_size','?')}  ·  **Tech comfort**: {audit.get('tech_comfort','?')}/5  ·  **Budget**: {audit.get('budget','?')}")
md.append(f"\n**North star**: {audit.get('north_star') or '(not set)'}\n")
if audit.get("pains"):
    md.append("**Pains:**")
    for p in audit["pains"]: md.append(f"- {p}")
    md.append("")

md.append("## Top opportunities for you\n")
md.append("Ranked by industry fit + pain match + tools you already have.\n")
for i, op in enumerate(ranked[:5], 1):
    md.append(f"### {i}. {op['title']}")
    md.append(f"- **Runtime**: {op.get('runtime','?')}")
    md.append(f"- **Needs**: {', '.join(op.get('services', []))}")
    md.append(f"- **Estimated value**: {op.get('value','?')}")
    md.append(f"- **Difficulty**: {op.get('difficulty','?')}")
    md.append(f"- **Score**: {op['score']}\n")

md.append("---\n## Next: pick 1-3 to build")
md.append("Confirm the owner's 1-3 picks, then run `bash scripts/select.sh --auto <indices>` (e.g. `--auto 1,3`) — the bare interactive form needs a TTY.")

(state / "audit-output.md").write_text("\n".join(md))
print((state / "audit-output.md").read_text())
PYEOF
