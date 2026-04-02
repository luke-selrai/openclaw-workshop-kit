#!/bin/bash
set -e

CONNECTOR="hubspot"
echo "=== Setting up HubSpot connector ==="
echo ""

HOME_DIR="$HOME"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  HOME_DIR="$USERPROFILE"
fi

USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
SECRETS_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME/secrets"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILL_DIR"
mkdir -p "$SECRETS_DIR"

cp "$SCRIPT_DIR/skills/$CONNECTOR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "[done] Skill file installed"

if [ ! -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  cp "$SCRIPT_DIR/secrets/$CONNECTOR.env.template" "$SECRETS_DIR/$CONNECTOR.env"
  echo "[done] Credentials file created at $SECRETS_DIR/$CONNECTOR.env"
else
  echo "[skip] Credentials file already exists"
fi

echo ""
echo "Adding HubSpot MCP server..."
if command -v claude &> /dev/null; then
  if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
    source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  fi
  if [ -n "$PRIVATE_APP_ACCESS_TOKEN" ] && [ "$PRIVATE_APP_ACCESS_TOKEN" != "pat-na1-your_token_here" ]; then
    claude mcp add hubspot -e PRIVATE_APP_ACCESS_TOKEN="$PRIVATE_APP_ACCESS_TOKEN" -- npx -y @hubspot/mcp-server 2>/dev/null && echo "[done] MCP server added" || echo "[warn] Could not add MCP server automatically."
  else
    echo "[info] MCP server will be added after you fill in your credentials."
  fi
else
  echo "[warn] Claude Code not found."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "1. Edit your credentials: $SECRETS_DIR/$CONNECTOR.env"
echo "2. Run the test: bash $SCRIPT_DIR/test.sh"
