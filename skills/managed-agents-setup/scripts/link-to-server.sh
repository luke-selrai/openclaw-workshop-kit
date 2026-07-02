#!/usr/bin/env bash
# link-to-server.sh — Wire existing server-setup EC2 agents to Managed Agents.
# Copies API key to server, adds call_managed_agent helper to run-agent.sh.
#
# Requires: server-setup already installed (~/agents-cc on server).
set -euo pipefail

SSH_KEY="${SSH_KEY:-$HOME/.ssh/clawd-key.pem}"
SSH_HOST="${SSH_HOST:-ubuntu@100.119.119.120}"

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

if [ ! -f "$SSH_KEY" ]; then
  echo "[fatal] SSH key not found: $SSH_KEY" >&2
  exit 2
fi

SSH_CMD="ssh -i $SSH_KEY -o ConnectTimeout=5 $SSH_HOST"

echo "[link] Checking server..."
if ! $SSH_CMD 'test -d ~/agents-cc' 2>/dev/null; then
  echo "[fatal] ~/agents-cc not found on server. Run server-setup first." >&2
  exit 3
fi

echo "[link] Backing up server secrets.env (locked 600, removed after success)..."
$SSH_CMD 'umask 077; cp ~/agents-cc/shared/secrets.env ~/agents-cc/shared/secrets.env.bak 2>/dev/null && chmod 600 ~/agents-cc/shared/secrets.env.bak 2>/dev/null || true'

echo "[link] Injecting ANTHROPIC_API_KEY (key piped over stdin, not argv)..."
$SSH_CMD "sed -i '/^# --- Managed Agents ---/,/^# --- End Managed Agents ---/d' ~/agents-cc/shared/secrets.env 2>/dev/null || true"
# Pipe the API key in over stdin so it never appears in the ssh argv / server process list.
# The remote command is single-quoted so the local shell does not expand $__MA_KEY;
# the value arrives only via the piped stdin line read by the remote `read -r`.
printf '%s\n' "$ANTHROPIC_API_KEY" | $SSH_CMD 'umask 077; read -r __MA_KEY; {
  printf "\n# --- Managed Agents ---\n"
  printf "export ANTHROPIC_API_KEY=%s\n" "\"$__MA_KEY\""
  printf "# --- End Managed Agents ---\n"
} >> ~/agents-cc/shared/secrets.env; chmod 600 ~/agents-cc/shared/secrets.env'

echo "[link] Installing call_managed_agent helper..."
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/managed-agents.sh << '\''SCRIPT'\''
#!/bin/bash
# managed-agents.sh — Call Anthropic Managed Agents from server-side scripts.
# Usage: managed-agents.sh <agent_id> <env_id> <message> [vault_id]
source "$HOME/agents-cc/shared/secrets.env" 2>/dev/null

AGENT_ID="${1:?agent_id required}"
ENV_ID="${2:?env_id required}"
MESSAGE="${3:?message required}"
VAULT_ID="${4:-}"

BODY="{\"agent\":\"$AGENT_ID\",\"environment_id\":\"$ENV_ID\",\"title\":\"server-triggered\""
if [ -n "$VAULT_ID" ]; then
  BODY="$BODY,\"vault_ids\":[\"$VAULT_ID\"]"
fi
BODY="$BODY}"

# S12: secret x-api-key header fed via curl --config on stdin (never on argv/ps)
RESP=$(curl -sS -X POST "https://api.anthropic.com/v1/sessions" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: managed-agents-2026-04-01" \
  -H "content-type: application/json" \
  -d "$BODY" \
  --config - <<CURLCFG
header = "x-api-key: ${ANTHROPIC_API_KEY}"
CURLCFG
)

SESSION_ID=$(echo "$RESP" | jq -r '.id // empty')
if [ -z "$SESSION_ID" ]; then
  echo "[fail] session create:" >&2
  echo "$RESP" | jq . >&2
  exit 4
fi

# Send user message
MSG_ESCAPED=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$MESSAGE")
# S12: secret x-api-key header fed via curl --config on stdin (never on argv/ps)
curl -sS -X POST "https://api.anthropic.com/v1/sessions/$SESSION_ID/events" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: managed-agents-2026-04-01" \
  -H "content-type: application/json" \
  -d "{\"events\":[{\"type\":\"user.message\",\"content\":[{\"type\":\"text\",\"text\":$MSG_ESCAPED}]}]}" \
  --config - <<CURLCFG >/dev/null
header = "x-api-key: ${ANTHROPIC_API_KEY}"
CURLCFG

echo "session_id=$SESSION_ID"
echo "url=https://platform.claude.com/sessions/$SESSION_ID"
SCRIPT
chmod +x ~/agents-cc/shared/scripts/managed-agents.sh'

echo "[link] Pushing agent IDs + env ID to server..."
STATE_DIR="$HOME/.claude/managed-agents"
if [ -f "$STATE_DIR/env-id.txt" ]; then
  $SSH_CMD "mkdir -p ~/agents-cc/shared/managed-agents && echo '$(cat $STATE_DIR/env-id.txt)' > ~/agents-cc/shared/managed-agents/env-id.txt"
fi
if [ -d "$STATE_DIR/agents" ]; then
  for f in "$STATE_DIR/agents"/*.txt; do
    [ -f "$f" ] || continue
    NAME=$(basename "$f" .txt)
    $SSH_CMD "mkdir -p ~/agents-cc/shared/managed-agents/agents && echo '$(cat "$f")' > ~/agents-cc/shared/managed-agents/agents/$NAME.txt"
  done
fi

echo "[link] Testing helper on server..."
$SSH_CMD 'ls ~/agents-cc/shared/scripts/managed-agents.sh && echo "helper installed"'

echo "[link] Removing plaintext secrets backup..."
$SSH_CMD 'rm -f ~/agents-cc/shared/secrets.env.bak 2>/dev/null || true'

echo "[ok] Server linked to Managed Agents."
echo "[ok] On the server, call: ~/agents-cc/shared/scripts/managed-agents.sh <agent_id> <env_id> \"msg\""
