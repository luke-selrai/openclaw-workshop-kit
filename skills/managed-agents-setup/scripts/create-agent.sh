#!/usr/bin/env bash
# create-agent.sh — Create a Managed Agent from a template.
# Usage: create-agent.sh <preset-name>
# Presets defined in references/agent-templates.json.
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
set -- "${PARSED[@]}"
MA_BASE="${HOME}/.claude/managed-agents${CLIENT_SLUG:+/$CLIENT_SLUG}"
mkdir -p "$MA_BASE"

PRESET="${1:-general}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../references/agent-templates.json"
STATE_DIR="$HOME/.claude/managed-agents"
mkdir -p "$STATE_DIR/agents"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[fatal] Template file missing: $TEMPLATE_FILE" >&2
  exit 2
fi

CONFIG=$(jq -r --arg p "$PRESET" '.[$p] // empty' "$TEMPLATE_FILE")
if [ -z "$CONFIG" ]; then
  echo "[fatal] Preset '$PRESET' not found in $TEMPLATE_FILE" >&2
  echo "Available: $(jq -r 'keys | join(", ")' "$TEMPLATE_FILE")" >&2
  exit 2
fi

echo "[agent] Creating agent from preset '$PRESET'..."
RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/agents" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: managed-agents-2026-04-01" \
  -H "content-type: application/json" \
  -d "$CONFIG")

AGENT_ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$AGENT_ID" ]; then
  echo "[fatal] Agent creation failed:" >&2
  echo "$RESP" | jq . >&2
  exit 3
fi

echo "$AGENT_ID" > "$STATE_DIR/agents/$PRESET.txt"
echo "[ok] agent_id = $AGENT_ID (preset: $PRESET)"
echo "[ok] Saved to $STATE_DIR/agents/$PRESET.txt"
