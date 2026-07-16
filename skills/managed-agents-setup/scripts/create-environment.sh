#!/usr/bin/env bash
# create-environment.sh — Create a Managed Agents environment from a template.
# Usage: create-environment.sh <preset-name>
# Presets defined in references/environment-templates.json.
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

PRESET="${1:-primary}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../references/environment-templates.json"
# H4: honor --client namespacing — state goes under MA_BASE, not a hardcoded path.
STATE_DIR="$MA_BASE"
mkdir -p "$STATE_DIR"

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

echo "[env] Creating environment from preset '$PRESET'..."
# S12: pass the secret header off argv via curl --config - (stdin) so the
# API key never appears in the process table / argv.
RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/environments" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: managed-agents-2026-04-01" \
  -H "content-type: application/json" \
  -d "$CONFIG" \
  --config - <<CURLCFG
header = "x-api-key: ${ANTHROPIC_API_KEY}"
CURLCFG
)

ENV_ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$ENV_ID" ]; then
  echo "[fatal] Environment creation failed:" >&2
  echo "$RESP" | jq . >&2
  exit 3
fi

echo "$ENV_ID" > "$STATE_DIR/env-id.txt"
echo "[ok] env_id = $ENV_ID"
echo "[ok] Saved to $STATE_DIR/env-id.txt"
