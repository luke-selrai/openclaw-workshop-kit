#!/bin/bash

# Port-to-Server Script
# Selr AI — Workshop Kit
# Packages local Claude Code setup and transfers to remote server via scp

set -e

echo "======================================"
echo "  Claude Code — Port to Server"
echo "  Selr AI Workshop Kit"
echo "======================================"

# Load transfer manifest
MANIFEST="$(dirname "$0")/../config/transfer-manifest.json"

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: transfer-manifest.json not found at $MANIFEST"
  exit 1
fi

echo ""
echo "Step 1: Detecting local Claude Code setup..."

CLAUDE_DIR="$HOME/.claude"
BUNDLE_NAME="claude-transfer.tar.gz"
BUNDLE_PATH="$HOME/$BUNDLE_NAME"
TEMP_DIR="$HOME/claude-transfer-temp"

# Create temp staging directory
mkdir -p "$TEMP_DIR"

# Copy core Claude files
echo ""
echo "Copying skills..."
[ -d "$CLAUDE_DIR/skills" ] && cp -r "$CLAUDE_DIR/skills" "$TEMP_DIR/" && echo "  ✓ Skills copied" || echo "  - No skills folder found"

echo "Copying agents..."
[ -d "$CLAUDE_DIR/agents" ] && cp -r "$CLAUDE_DIR/agents" "$TEMP_DIR/" && echo "  ✓ Agents copied" || echo "  - No agents folder found"

echo "Copying MCP config..."
[ -f "$CLAUDE_DIR/mcp_config.json" ] && cp "$CLAUDE_DIR/mcp_config.json" "$TEMP_DIR/" && echo "  ✓ MCP config copied" || echo "  - No MCP config found"

echo "Copying memories..."
[ -d "$CLAUDE_DIR/projects" ] && cp -r "$CLAUDE_DIR/projects" "$TEMP_DIR/" && echo "  ✓ Project memories copied" || echo "  - No project memories found"

echo "Copying environment files..."
find "$HOME" -maxdepth 2 -name ".env" -exec cp {} "$TEMP_DIR/" \; && echo "  ✓ .env files copied" || echo "  - No .env files found"

echo "Copying CLAUDE.md..."
[ -f "$HOME/CLAUDE.md" ] && cp "$HOME/CLAUDE.md" "$TEMP_DIR/" && echo "  ✓ CLAUDE.md copied" || echo "  - No CLAUDE.md found"

# Bundle everything
echo ""
echo "Step 2: Creating transfer bundle..."
tar -czf "$BUNDLE_PATH" -C "$HOME" "claude-transfer-temp"
echo "  ✓ Bundle created at $BUNDLE_PATH"

# Cleanup temp
rm -rf "$TEMP_DIR"

# Get server details
echo ""
echo "Step 3: Transfer to server"
echo ""
read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your SSH username (default: ubuntu): " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}

echo ""
echo "Transferring bundle to $SSH_USER@$SERVER_IP..."
scp "$BUNDLE_PATH" "$SSH_USER@$SERVER_IP:~/"

echo ""
echo "======================================"
echo "  Transfer complete!"
echo "======================================"
echo ""
echo "Next steps — SSH into your server and run:"
echo ""
echo "  ssh $SSH_USER@$SERVER_IP"
echo "  cd ~"
echo "  tar -xzf claude-transfer.tar.gz"
echo "  npm install -g @anthropic-ai/claude-code"
echo "  claude"
echo ""
echo "Then paste your setup prompt to restore your assistant."
echo ""
