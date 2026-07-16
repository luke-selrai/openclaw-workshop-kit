#!/usr/bin/env bash
# promote-v2-to-managed-agents.sh — Reads server v2 CLAUDE.md files and creates
# corresponding Managed Agent definitions for each. v2 local ghost is archived.
#
# Pattern B from server audit: v2 agent files become Managed Agent system prompts,
# v1 agents on cron delegate heavy work to v2 (now hosted).
#
# Usage:
#   bash promote-v2-to-managed-agents.sh                 # DRY-RUN (default): list only, no billing
#   bash promote-v2-to-managed-agents.sh --apply --yes   # actually create billable agents
set -uo pipefail

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

# SAFETY (S11): provisioning N billable Managed Agents is gated.
# Default is DRY-RUN. Real creation needs BOTH --apply and --yes.
DRY_RUN=1
APPLY=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --apply)   APPLY=1 ;;
    --yes)     ASSUME_YES=1 ;;
  esac
done
[[ "$APPLY" == "1" ]] && DRY_RUN=0

SSH_KEY="${SSH_KEY:-$HOME/.ssh/clawd-key.pem}"
SSH_HOST="${SSH_HOST:-ubuntu@100.119.119.120}"
SSH_CMD="ssh -o BatchMode=yes -i $SSH_KEY $SSH_HOST"

STATE_DIR="$HOME/.claude/managed-agents"
mkdir -p "$STATE_DIR/agents" "$STATE_DIR/v2-prompts"

# Pull each v2 CLAUDE.md locally so we can read them
echo "[promote] Pulling v2 CLAUDE.mds from server..."
# NEW-6: use mktemp (per-run, 0600) instead of a predictable /tmp path (symlink/race-safe)
V2_LIST_FILE=$(mktemp "${TMPDIR:-/tmp}/v2_agents.XXXXXX")
trap 'rm -f "$V2_LIST_FILE"' EXIT
$SSH_CMD 'ls -d ~/agents-v2/agents/*/ 2>/dev/null | xargs -I{} basename {}' > "$V2_LIST_FILE"
V2_AGENTS=$(cat "$V2_LIST_FILE")

if [ -z "$V2_AGENTS" ]; then
  echo "[info] No v2 agents found on server. Nothing to promote."
  exit 0
fi

echo "[promote] Found v2 agents:"
for a in $V2_AGENTS; do echo "  - $a"; done

: "${ENV_ID:=$(cat $STATE_DIR/env-id.txt 2>/dev/null)}"
: "${VAULT_ID:=$(cat $STATE_DIR/vault-id.txt 2>/dev/null)}"

if [ -z "$ENV_ID" ]; then
  echo "[fatal] No env_id found. Run create-environment.sh first."
  exit 2
fi

# Model mapping — different v2 agents justify different tiers
pick_model() {
  case "$1" in
    brain|dealmaker|research*) echo "claude-opus-4-7" ;;
    ops|finance|events)        echo "claude-haiku-4-5" ;;
    *)                         echo "claude-sonnet-4-6" ;;
  esac
}

BETA="managed-agents-2026-04-01"

# SAFETY (S11): count + confirm before the first billable POST.
N_AGENTS=$(echo "$V2_AGENTS" | grep -c . || true)
SUCCESS_COUNT=0
if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] Would create up to $N_AGENTS billable Managed Agent(s). Re-run with --apply --yes to proceed."
else
  echo "[promote] About to create up to $N_AGENTS BILLABLE Managed Agent(s):"
  for a in $V2_AGENTS; do echo "    - v2-$a"; done
  if [ "$ASSUME_YES" != "1" ]; then
    if [ -t 0 ]; then
      read -r -p "Proceed and create these billable agents? [y/N] " _confirm
      [[ "$_confirm" == [yY]* ]] || { echo "[abort] Not confirmed."; exit 3; }
    else
      echo "[abort] --apply requires confirmation; pass --yes (no TTY for prompt)." >&2
      exit 3
    fi
  fi
fi

for AGENT in $V2_AGENTS; do
  echo ""
  echo "══ Promoting: $AGENT ══"

  # Fetch CLAUDE.md content
  PROMPT=$($SSH_CMD "cat ~/agents-v2/agents/$AGENT/CLAUDE.md 2>/dev/null" || echo "")
  if [ -z "$PROMPT" ]; then
    echo "  [skip] No CLAUDE.md for $AGENT"
    continue
  fi

  cp /dev/stdin "$STATE_DIR/v2-prompts/$AGENT.md" <<< "$PROMPT"
  MODEL=$(pick_model "$AGENT")

  # Truncate long prompts (Managed Agents has a prompt size cap — be safe)
  PROMPT_SHORT=$(echo "$PROMPT" | head -c 10000)

  BODY=$(python3 <<PY
import json, sys
body = {
    "name": f"v2-$AGENT".replace("_", "-"),
    "model": "$MODEL",
    "system": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$PROMPT_SHORT"),
    "tools": [{"type": "agent_toolset_20260401"}]
}
if "$VAULT_ID":
    # Add Rube by default for universal tool access
    body["mcp_servers"] = [{"type": "url", "name": "rube", "url": "https://rube.app/mcp"}]
    body["tools"].append({"type": "mcp_toolset", "mcp_server_name": "rube"})
print(json.dumps(body))
PY
)

  if [ "$DRY_RUN" = "1" ]; then
    echo "  [dry-run] Would create agent v2-$AGENT with model $MODEL"
    continue
  fi

  # S12: secret x-api-key header fed via curl --config on stdin (never on argv/ps)
  RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/agents" \
    -H "anthropic-version: 2023-06-01" \
    -H "anthropic-beta: $BETA" \
    -H "content-type: application/json" \
    -d "$BODY" \
    --config - <<EOF
header = "x-api-key: ${ANTHROPIC_API_KEY}"
EOF
)

  AGENT_ID=$(echo "$RESP" | jq -r '.id // empty')
  if [ -n "$AGENT_ID" ]; then
    echo "$AGENT_ID" > "$STATE_DIR/agents/v2-$AGENT.txt"
    echo "  [ok] v2-$AGENT → $AGENT_ID (model $MODEL)"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "  [fail] $AGENT — $(echo "$RESP" | jq -c .)"
  fi
done

echo ""
echo "[promote] Done. Agent IDs saved to $STATE_DIR/agents/v2-*.txt"

# Archive the local v2 ghost — ONLY if at least one agent was actually created.
# (S11: never destroy the v2 source on a dry-run or all-fail run.)
if [ "$DRY_RUN" = "1" ]; then
  echo "[archive] Skipped (dry-run): ~/agents-v2 left in place."
elif [ "$SUCCESS_COUNT" -lt 1 ]; then
  echo "[archive] Skipped: 0 agents created, leaving ~/agents-v2 untouched."
elif [ -d "$HOME/agents-v2" ]; then
  ARCHIVE="$HOME/archive/agents-v2-pre-managed-$(date +%Y%m%d)"
  mkdir -p "$HOME/archive"
  mv "$HOME/agents-v2" "$ARCHIVE" 2>/dev/null || true
  echo "[archive] Local ~/agents-v2 moved to $ARCHIVE"
fi
