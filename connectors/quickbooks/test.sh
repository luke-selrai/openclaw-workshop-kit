#!/bin/bash
CONNECTOR="quickbooks"; PASS=0; FAIL=0
check() { if [ $1 -eq 0 ]; then echo "[pass] $2"; ((PASS++)); else echo "[FAIL] $2"; ((FAIL++)); fi; }

HOME_DIR="$HOME"
[[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]] && HOME_DIR="$USERPROFILE"
USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
SECRETS_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME/secrets"

echo "=== Testing QuickBooks connector ==="
echo ""
[ -f "$SKILL_DIR/SKILL.md" ]; check $? "Skill file installed"
[ -f "$SECRETS_DIR/$CONNECTOR.env" ]; check $? "Credentials file exists"

if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  [ -n "$INTUIT_CLIENT_ID" ] && [ "$INTUIT_CLIENT_ID" != "your_client_id_here" ]; check $? "Client ID is set"
  [ -n "$INTUIT_CLIENT_SECRET" ] && [ "$INTUIT_CLIENT_SECRET" != "your_client_secret_here" ]; check $? "Client Secret is set"
else
  check 1 "Client ID is set"
  check 1 "Client Secret is set"
fi

command -v claude &> /dev/null && { claude mcp list 2>/dev/null | grep -qi "$CONNECTOR"; check $? "MCP server registered"; } || check 1 "MCP server registered"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
