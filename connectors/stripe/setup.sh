#!/bin/bash
set -e

CONNECTOR="stripe"
echo "=== Setting up Stripe connector ==="
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
echo "Adding Stripe MCP server..."
if command -v claude &> /dev/null; then
  if [ -f "$SECRETS_DIR/$CONNECTOR.env" ]; then
    source "$SECRETS_DIR/$CONNECTOR.env" 2>/dev/null || true
  fi
  if [ -n "$STRIPE_API_KEY" ] && [ "$STRIPE_API_KEY" != "rk_live_your_restricted_key_here" ]; then
    claude mcp add stripe -- npx -y @stripe/mcp --api-key="$STRIPE_API_KEY" 2>/dev/null && echo "[done] MCP server added" || echo "[warn] Could not add MCP server automatically."
  else
    echo "[info] MCP server will be added after you fill in your credentials."
    echo "       Then run: claude mcp add stripe -- npx -y @stripe/mcp --api-key=YOUR_KEY"
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
