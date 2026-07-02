#!/usr/bin/env bash
# fire-routine.sh — Fire a Claude Code routine via the /fire webhook.
# Usage:
#   fire-routine.sh <trig_id> [payload_text]
# Env:
#   ROUTINE_OAT_TOKEN — per-routine token (sk-ant-oat01-...) generated in routine settings
set -euo pipefail

TRIG_ID="${1:?trig_id required (e.g. trig_abc123)}"
PAYLOAD="${2:-triggered by fire-routine.sh}"

: "${ROUTINE_OAT_TOKEN:?ROUTINE_OAT_TOKEN not set — get one from claude.ai/code/routines settings}"

if [[ ! "$TRIG_ID" =~ ^trig_ ]]; then
  echo "[warn] trig_id should start with 'trig_' — got: $TRIG_ID" >&2
fi

echo "[fire] POST /v1/claude_code/routines/$TRIG_ID/fire"
RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/claude_code/routines/$TRIG_ID/fire" \
  --config - \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
  -H "content-type: application/json" \
  -d "$(python3 -c "import json,sys; print(json.dumps({'text': sys.argv[1]}))" "$PAYLOAD")" <<EOF
header = "Authorization: Bearer ${ROUTINE_OAT_TOKEN}"
EOF
)

echo "$RESP" | jq . 2>/dev/null || echo "$RESP"
SESSION_URL=$(echo "$RESP" | jq -r '.claude_code_session_url // empty' 2>/dev/null || true)
if [ -n "$SESSION_URL" ]; then
  echo "[ok] Session: $SESSION_URL"
fi
