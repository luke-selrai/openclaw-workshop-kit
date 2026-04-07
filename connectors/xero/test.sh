#!/bin/bash

CONNECTOR="xero"
PASS=0
FAIL=0

check() {
  if [ $1 -eq 0 ]; then echo "[pass] $2"; ((PASS++)); else echo "[FAIL] $2"; ((FAIL++)); fi
}

HOME_DIR="$HOME"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  HOME_DIR="$USERPROFILE"
fi

USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
SECRETS_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME/secrets"

echo "=== Testing Xero connector ==="
echo ""

[ -f "$SKILL_DIR/SKILL.md" ]; check $? "Skill file installed"
[ -f "$SECRETS_DIR/$CONNECTOR.env" ]; check $? "Credentials file exists"

if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  [ -n "$XERO_CLIENT_ID" ] && [ "$XERO_CLIENT_ID" != "your_client_id_here" ]; check $? "Xero Client ID is set"
  [ -n "$XERO_CLIENT_SECRET" ] && [ "$XERO_CLIENT_SECRET" != "your_client_secret_here" ]; check $? "Xero Client Secret is set"
else
  check 1 "Xero Client ID is set"
  check 1 "Xero Client Secret is set"
fi

if command -v claude &> /dev/null; then
  claude mcp list 2>/dev/null | grep -qi "$CONNECTOR"; check $? "MCP server registered"
else
  check 1 "MCP server registered (Claude Code not found)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -gt 0 ] && echo "" && echo "Fix: Edit $SECRETS_DIR/$CONNECTOR.env with your Xero credentials, then re-run setup.sh"
