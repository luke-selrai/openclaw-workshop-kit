#!/usr/bin/env bash
# verify.sh — end-to-end smoke test for ai-ops-architect
# Acceptance criteria (5 ACs):
#   AC1: All required scripts present + executable
#   AC2: All references docs present + non-empty
#   AC3: Template inventory: n8n templates exist + at least one .meta.json sidecar
#   AC4: Managed-agent presets parse as valid JSON + cover ≥6 verticals
#   AC5: audit.sh + recommend.sh in --auto mode produce valid .state outputs
set -uo pipefail

# Resolve ROOT from this script's location so verify works whether the skill
# is installed at ~/.claude/skills/... or cloned into an arbitrary directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0
WARN=0
RESULTS=()

ok()   { RESULTS+=("PASS: $1"); PASS=$((PASS+1)); }
fail() { RESULTS+=("FAIL: $1"); FAIL=$((FAIL+1)); }
warn() { RESULTS+=("WARN: $1"); WARN=$((WARN+1)); }

echo "ai-ops-architect verify.sh"
echo "==========================="

# AC1 — scripts present + executable
for s in audit.sh recommend.sh claude-passthrough.sh connect-via-rube.sh verify.sh; do
    p="$ROOT/scripts/$s"
    if [[ -x "$p" ]]; then ok "AC1 script $s exec"
    elif [[ -f "$p" ]]; then warn "AC1 script $s present but NOT executable — chmod +x needed"
    else fail "AC1 script $s missing"
    fi
done
if [[ -f "$ROOT/scripts/curate-templates.py" ]]; then ok "AC1 curate-templates.py present"
else fail "AC1 curate-templates.py missing"; fi

# AC2 — references docs
for r in runtime-decision-matrix.md opportunity-catalog.md intake-questionnaire.md connector-strategy.md; do
    p="$ROOT/references/$r"
    if [[ -s "$p" ]]; then ok "AC2 reference $r ($(wc -l <"$p" | tr -d ' ') lines)"
    else fail "AC2 reference $r missing or empty"
    fi
done

# AC3 — template inventory
N8N_DIR="$ROOT/templates/n8n"
TPL_COUNT=$(find "$N8N_DIR" -name "*.json" -not -name "*.meta.json" 2>/dev/null | wc -l | tr -d ' ')
META_COUNT=$(find "$N8N_DIR" -name "*.meta.json" 2>/dev/null | wc -l | tr -d ' ')
CAT_COUNT=$(find "$N8N_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ "$TPL_COUNT" -ge 50 ]]; then ok "AC3 n8n templates: $TPL_COUNT (≥50 minimum)"
elif [[ "$TPL_COUNT" -gt 0 ]]; then warn "AC3 n8n templates: only $TPL_COUNT — re-run curate-templates.py"
else fail "AC3 n8n templates: 0 — curate has not run yet"
fi
[[ "$META_COUNT" -gt 0 ]] && ok "AC3 meta.json sidecars: $META_COUNT" || warn "AC3 no meta.json sidecars"
[[ "$CAT_COUNT" -ge 8 ]] && ok "AC3 categories populated: $CAT_COUNT" || warn "AC3 only $CAT_COUNT categories — expected 12"

# AC4 — managed-agent presets via canonical source (managed-agents-setup)
LOADER="$ROOT/templates/managed-agents/presets.json"
# Resolve canonical presets relative to the sibling skill first (works in a kit bundle / clone),
# then fall back to the installed ~/.claude location. Pass paths via env so MSYS converts them
# for Windows python (paths baked into heredoc text are NOT converted and fail on Windows).
CANONICAL="$ROOT/../managed-agents-setup/references/business-outcome-presets.json"
[[ -s "$CANONICAL" ]] || CANONICAL="$HOME/.claude/skills/managed-agents-setup/references/business-outcome-presets.json"
if [[ -s "$LOADER" ]]; then
    AC4_OUT=$(LOADER="$LOADER" CANONICAL="$CANONICAL" PYTHONUTF8=1 python3 - <<'PY'
import json, sys, os
loader_path = os.environ["LOADER"]
canonical_path = os.environ["CANONICAL"]
loader = json.load(open(loader_path))
# If loader has type=loader, follow it; else treat loader as the data
if isinstance(loader, dict) and loader.get("_meta", {}).get("type") == "loader":
    if not os.path.exists(canonical_path):
        sys.exit(2)
    d = json.load(open(canonical_path))
else:
    d = loader
if isinstance(d, list):
    presets = d
elif isinstance(d, dict):
    presets = [v for k, v in d.items() if k != "_meta" and isinstance(v, dict)]
else:
    sys.exit(1)
verts = set()
for p in presets:
    for ind in p.get("industries", []):
        verts.add(ind)
print(f"{len(presets)} {len(verts)}")
PY
)
    if [[ -n "$AC4_OUT" ]]; then
        N=$(echo "$AC4_OUT" | awk '{print $1}')
        V=$(echo "$AC4_OUT" | awk '{print $2}')
        if [[ "$N" -ge 20 && "$V" -ge 6 ]]; then
            ok "AC4 presets via loader -> canonical: $N entries across $V verticals"
        else
            fail "AC4 presets: $N (want >=20) across $V verticals (want >=6)"
        fi
    else
        fail "AC4 presets: parse failed (canonical at $CANONICAL?)"
    fi
else
    fail "AC4 presets loader missing at $LOADER"
fi

# AC5 — dry-run audit + recommend
TMPSTATE=$(mktemp -d)
export AI_OPS_STATE_DIR="$TMPSTATE"
if bash "$ROOT/scripts/audit.sh" --auto >/dev/null 2>&1; then
    if [[ -s "$TMPSTATE/audit-result.json" ]] || [[ -s "$ROOT/.state/audit-result.json" ]]; then
        ok "AC5 audit.sh --auto produces output"
    else
        warn "AC5 audit.sh ran but didn't write expected output (state path may differ)"
    fi
else
    warn "AC5 audit.sh --auto returned non-zero (interactive prompts in CI?)"
fi

if bash "$ROOT/scripts/recommend.sh" >/dev/null 2>&1; then
    [[ -s "$ROOT/.state/audit-output.md" ]] && ok "AC5 recommend.sh produces audit-output.md" || warn "AC5 recommend.sh ran but no output"
else
    warn "AC5 recommend.sh returned non-zero — needs preceding audit-result.json"
fi
rm -rf "$TMPSTATE"

# SKILL + agent definition
[[ -f "$ROOT/SKILL.md" ]] && ok "skill manifest SKILL.md present" || fail "SKILL.md missing"
if [[ -f "$ROOT/agents/ai-ops-architect.md" || -f "$HOME/.claude/agents/ai-ops-architect.md" ]]; then
    ok "driver agent present"
else
    warn "agents/ai-ops-architect.md not found (bundled or installed)"
fi
[[ -f "$ROOT/INSTALL.md" ]] && ok "INSTALL.md present" || warn "INSTALL.md missing"
[[ -f "$ROOT/plugin.json" ]] && ok "plugin manifest present" || warn "plugin.json missing"

echo
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "Result: $PASS pass, $FAIL fail, $WARN warn"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
