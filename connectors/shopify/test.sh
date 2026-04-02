#!/bin/bash

CONNECTOR="shopify"
PASS=0
FAIL=0

check() {
  if [ $1 -eq 0 ]; then
    echo "[pass] $2"
    ((PASS++))
  else
    echo "[FAIL] $2"
    ((FAIL++))
  fi
}

HOME_DIR="$HOME"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  HOME_DIR="$USERPROFILE"
fi

USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
SECRETS_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME/secrets"

echo "=== Testing Shopify connector ==="
echo ""

# Check skill file
[ -f "$SKILL_DIR/SKILL.md" ]
check $? "Skill file installed at $SKILL_DIR/SKILL.md"

# Check secrets file exists
[ -f "$SECRETS_DIR/$CONNECTOR.env" ]
check $? "Credentials file exists at $SECRETS_DIR/$CONNECTOR.env"

# Check credentials are filled in
if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  [ -n "$SHOPIFY_ACCESS_TOKEN" ] && [ "$SHOPIFY_ACCESS_TOKEN" != "shpat_your_access_token_here" ]
  check $? "Shopify access token is set (not placeholder)"

  [ -n "$SHOPIFY_STORE_DOMAIN" ] && [ "$SHOPIFY_STORE_DOMAIN" != "your-store.myshopify.com" ]
  check $? "Shopify store domain is set (not placeholder)"
else
  check 1 "Shopify access token is set"
  check 1 "Shopify store domain is set"
fi

# Check MCP server
if command -v claude &> /dev/null; then
  claude mcp list 2>/dev/null | grep -qi "$CONNECTOR"
  check $? "MCP server registered in Claude Code"
else
  check 1 "MCP server registered (Claude Code not found)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Troubleshooting:"
  echo "- Missing credentials? Edit: $SECRETS_DIR/$CONNECTOR.env"
  echo "- MCP not registered? Run: claude mcp add shopify -- npx shopify-mcp --accessToken YOUR_TOKEN --domain YOUR_STORE.myshopify.com"
fi
