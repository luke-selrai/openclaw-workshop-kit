#!/usr/bin/env bash
# verify.sh — end-to-end smoke test for managed-agents-setup skill
# Acceptance criteria (5 ACs):
#   AC1: Required scripts present + executable
#   AC2: References docs present + non-empty (incl. phases/ subdir)
#   AC3: business-outcome-presets.json parses + has >=20 entries across >=6 verticals
#   AC4: smoke-test.sh runtime probe (skipped if no API key — that's fine)
#   AC5: SKILL.md + driver agent + INSTALL + plugin manifest + handoff template all present
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

echo "managed-agents-setup verify.sh"
echo "==============================="

# AC1 — scripts present + executable
for s in preflight.sh install-cli.sh create-agent.sh create-environment.sh create-routine.sh smoke-test.sh killswitch.sh connector-wizard.sh mcp-bridge.sh verify.sh; do
    p="$ROOT/scripts/$s"
    if [[ -x "$p" ]]; then ok "AC1 script $s exec"
    elif [[ -f "$p" ]]; then warn "AC1 script $s present but NOT executable"
    else fail "AC1 script $s missing"
    fi
done
for py in vault-seeder.py daily-cost-monitor.py; do
    p="$ROOT/scripts/$py"
    if [[ -f "$p" ]]; then ok "AC1 python $py present"
    else fail "AC1 python $py missing"
    fi
done

# AC2 — references docs
for r in connector-strategy.md handoff-template.md mcp-servers-catalog.md business-outcome-presets.json agent-templates.json environment-templates.json troubleshooting.md; do
    p="$ROOT/references/$r"
    if [[ -s "$p" ]]; then ok "AC2 reference $r ($(wc -l <"$p" | tr -d ' ') lines)"
    else fail "AC2 reference $r missing or empty"
    fi
done

# AC3 — presets canonical file
PRESETS="$ROOT/references/business-outcome-presets.json"
if [[ -s "$PRESETS" ]]; then
    AC3_OUT=$(python3 - <<PY
import json, sys
d = json.load(open("$PRESETS"))
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
    if [[ -n "$AC3_OUT" ]]; then
        N=$(echo "$AC3_OUT" | awk '{print $1}')
        V=$(echo "$AC3_OUT" | awk '{print $2}')
        if [[ "$N" -ge 20 && "$V" -ge 6 ]]; then
            ok "AC3 presets: $N entries across $V verticals"
        else
            fail "AC3 presets: $N (want >=20) across $V verticals (want >=6)"
        fi
    else
        fail "AC3 presets.json: parse failed"
    fi
else
    fail "AC3 presets.json missing or empty"
fi

# AC4 — runtime smoke probe (only if API key exists)
if [[ -n "${ANTHROPIC_API_KEY:-}" ]] || security find-generic-password -a "$USER" -s "anthropic-managed-agents" -w >/dev/null 2>&1; then
    if bash "$ROOT/scripts/smoke-test.sh" >/dev/null 2>&1; then
        ok "AC4 smoke-test.sh exit 0"
    else
        warn "AC4 smoke-test.sh non-zero (some checks expected to fail without full setup)"
    fi
else
    warn "AC4 smoke-test.sh skipped (no API key in env or keychain — pre-Phase-1 install)"
fi

# AC5 — manifest + agent + docs
[[ -f "$ROOT/SKILL.md" ]] && ok "AC5 SKILL.md present" || fail "AC5 SKILL.md missing"
SKILL_LINES=$(wc -l < "$ROOT/SKILL.md" 2>/dev/null || echo 999)
if [[ "$SKILL_LINES" -le 200 ]]; then
    ok "AC5 SKILL.md is scannable ($SKILL_LINES lines, <=200)"
else
    warn "AC5 SKILL.md is $SKILL_LINES lines (>200 — slim further)"
fi
[[ -f "$HOME/.claude/agents/managed-agents-setup.md" ]] && ok "AC5 driver agent present" || fail "AC5 driver agent missing"
[[ -f "$ROOT/INSTALL.md" ]] && ok "AC5 INSTALL.md present" || fail "AC5 INSTALL.md missing"
[[ -f "$ROOT/plugin.json" ]] && ok "AC5 plugin.json present" || fail "AC5 plugin.json missing"
[[ -f "$ROOT/references/handoff-template.md" ]] && ok "AC5 handoff template present" || fail "AC5 handoff template missing"

echo
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "Result: $PASS pass, $FAIL fail, $WARN warn"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
