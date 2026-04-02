#!/bin/bash
set -e

CONNECTOR="shopify"
echo "=== Setting up Shopify connector ==="
echo ""

# Detect home directory
HOME_DIR="$HOME"
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  HOME_DIR="$USERPROFILE"
fi

USERNAME=$(whoami)
SKILL_DIR="$HOME_DIR/.claude/skills/$CONNECTOR"
PROJECT_DIR="$HOME_DIR/.claude/projects/-Users-$USERNAME"
SECRETS_DIR="$PROJECT_DIR/secrets"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create directories
mkdir -p "$SKILL_DIR"
mkdir -p "$SECRETS_DIR"

# Copy skill file
cp "$SCRIPT_DIR/skills/$CONNECTOR/SKILL.md" "$SKILL_DIR/SKILL.md"
echo "[done] Skill file installed to $SKILL_DIR"

# Copy secrets template (do not overwrite existing)
if [ ! -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
  cp "$SCRIPT_DIR/secrets/$CONNECTOR.env.template" "$SECRETS_DIR/$CONNECTOR.env"
  echo "[done] Credentials file created at $SECRETS_DIR/$CONNECTOR.env"
  echo "       You need to edit this file with your Shopify credentials."
else
  echo "[skip] Credentials file already exists at $SECRETS_DIR/$CONNECTOR.env"
fi

# Add MCP server to Claude Code
echo ""
echo "Adding Shopify MCP server to Claude Code..."
if command -v claude &> /dev/null; then
  # Read access token from secrets if available
  if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
    source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  fi

  if [ -n "$SHOPIFY_ACCESS_TOKEN" ] && [ "$SHOPIFY_ACCESS_TOKEN" != "shpat_your_access_token_here" ] && [ -n "$SHOPIFY_STORE_DOMAIN" ] && [ "$SHOPIFY_STORE_DOMAIN" != "your-store.myshopify.com" ]; then
    claude mcp add shopify -- npx shopify-mcp --accessToken "$SHOPIFY_ACCESS_TOKEN" --domain "$SHOPIFY_STORE_DOMAIN" 2>/dev/null && echo "[done] MCP server added" || echo "[warn] Could not add MCP server automatically. Add it manually after entering credentials."
  else
    echo "[info] MCP server will be added after you fill in your credentials."
    echo "       Then run: claude mcp add shopify -- npx shopify-mcp --accessToken YOUR_TOKEN --domain YOUR_STORE.myshopify.com"
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
echo "3. Open Claude Code and start managing your Shopify store!"
