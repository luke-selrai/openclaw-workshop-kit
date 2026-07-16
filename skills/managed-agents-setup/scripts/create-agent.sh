#!/usr/bin/env bash
# create-agent.sh — Create a Managed Agent from a template.
# Usage: create-agent.sh <preset-name>
# Presets defined in references/business-outcome-presets.json.
set -euo pipefail

# Per-client namespacing: --client=<slug> writes IDs under ~/.claude/managed-agents/<slug>/
# (P0.5 fix — multi-tenant agency was overwriting state per client)
CLIENT_SLUG="${CLIENT_SLUG:-}"
PARSED=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --client) CLIENT_SLUG="$2"; shift 2 ;;
        --client=*) CLIENT_SLUG="${1#--client=}"; shift ;;
        *) PARSED+=("$1"); shift ;;
    esac
done
set -- ${PARSED[@]+"${PARSED[@]}"}
MA_BASE="${HOME}/.claude/managed-agents${CLIENT_SLUG:+/$CLIENT_SLUG}"
mkdir -p "$MA_BASE"

PRESET="${1:-general}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../references/business-outcome-presets.json"
STATE_DIR="$MA_BASE"
mkdir -p "$STATE_DIR/agents"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[fatal] Template file missing: $TEMPLATE_FILE" >&2
  exit 2
fi

if [ "$PRESET" = "_meta" ]; then
  echo "[fatal] '_meta' is not a preset." >&2
  echo "Available: $(jq -r '(keys - ["_meta"]) | join(", ")' "$TEMPLATE_FILE")" >&2
  exit 2
fi

CONFIG=$(jq -r --arg p "$PRESET" 'if (.[$p] == null) then empty else (.[$p] | {name,model,description,system,tools,mcp_servers,skills} | with_entries(select(.value!=null))) end' "$TEMPLATE_FILE")
if [ -z "$CONFIG" ]; then
  echo "[fatal] Preset '$PRESET' not found in $TEMPLATE_FILE" >&2
  echo "Available: $(jq -r '(keys - ["_meta"]) | join(", ")' "$TEMPLATE_FILE")" >&2
  exit 2
fi

ID_FILE="$STATE_DIR/agents/$PRESET.txt"
if [ -f "$ID_FILE" ] && [ "${FORCE:-0}" != "1" ]; then
  echo "[ok] agent already exists for preset '$PRESET' = $(cat "$ID_FILE")"
  echo "[ok] (set FORCE=1 to recreate)"
  exit 0
fi

echo "[agent] Creating agent from preset '$PRESET'..."
# S12: pass the secret x-api-key header off argv via curl --config on stdin
# (so it never appears in `ps`/process listings); non-secret headers stay as -H.
RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/agents" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: managed-agents-2026-04-01" \
  -H "content-type: application/json" \
  -d "$CONFIG" \
  --config - <<EOF
header = "x-api-key: ${ANTHROPIC_API_KEY}"
EOF
)

AGENT_ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$AGENT_ID" ]; then
  echo "[fatal] Agent creation failed:" >&2
  echo "$RESP" | jq . >&2
  exit 3
fi

echo "$AGENT_ID" > "$ID_FILE"
echo "[ok] agent_id = $AGENT_ID (preset: $PRESET)"
echo "[ok] Saved to $ID_FILE"
