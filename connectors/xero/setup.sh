#!/bin/bash
set -e

CONNECTOR="xero"
echo "=== Setting up Xero connector ==="
echo ""

HOME_DIR="$HOME"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  HOME_DIR="$USERPROFILE"
fi

USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
PROJECT_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME"
SECRETS_DIR="$PROJECT_DIR/secrets"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$SKILL_DIR"
mkdir -p "$SECRETS_DIR"

cp "$SCRIPT_DIR/skills/$CONNECTOR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "[done] Skill file installed to $SKILL_DIR"

if [ ! -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  cp "$SCRIPT_DIR/secrets/$CONNECTOR.env.template" "$SECRETS_DIR/$CONNECTOR.env"
  echo "[done] Credentials file created at $SECRETS_DIR/$CONNECTOR.env"
  echo "       You need to edit this file with your Xero credentials."
else
  echo "[skip] Credentials file already exists at $SECRETS_DIR/$CONNECTOR.env"
fi

echo ""
echo "Adding Xero MCP server to Claude Code..."
if command -v claude &> /dev/null; then
  if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
    source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  fi

  if [ -n "$XERO_CLIENT_ID" ] && [ "$XERO_CLIENT_ID" != "your_client_id_here" ] && [ -n "$XERO_CLIENT_SECRET" ] && [ "$XERO_CLIENT_SECRET" != "your_client_secret_here" ]; then
    claude mcp add xero -e XERO_CLIENT_ID="$XERO_CLIENT_ID" -e XERO_CLIENT_SECRET="$XERO_CLIENT_SECRET" -- npx -y @xeroapi/xero-mcp-server@latest 2>/dev/null && echo "[done] MCP server added" || echo "[warn] Could not add MCP server automatically."
  else
    echo "[info] MCP server will be added after you fill in your credentials."
    echo "       Then run: claude mcp add xero -e XERO_CLIENT_ID=xxx -e XERO_CLIENT_SECRET=xxx -- npx -y @xeroapi/xero-mcp-server@latest"
  fi
else
  echo "[warn] Claude Code not found. Install it first, then re-run setup."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "1. Edit your credentials: $SECRETS_DIR/$CONNECTOR.env"
echo "2. Run the test: bash $SCRIPT_DIR/test.sh"
echo "3. Open Claude Code and start managing your Xero accounting!"
