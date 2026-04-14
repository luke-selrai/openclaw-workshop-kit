#!/bin/bash

# ============================================
# Notion Connector — Install Script
# Selr AI Workshop Kit
# ============================================

echo ""
echo "====================================="
echo " Notion Connector Setup"
echo "====================================="
echo ""

# Step 1 — Check Node.js
echo "Checking Node.js..."
if ! command -v node &> /dev/null; then
  echo "❌ Node.js not found. Install from https://nodejs.org"
  exit 1
fi

NODE_VERSION=$(node --version)
echo "✅ Node.js installed: $NODE_VERSION"
echo ""

# Step 2 — Check Claude Code
echo "Checking Claude Code..."
if ! command -v claude &> /dev/null; then
  echo "❌ Claude Code not found."
  echo "   Install it: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

CLAUDE_VERSION=$(claude --version)
echo "✅ Claude Code installed: $CLAUDE_VERSION"
echo ""

# Step 3 — Add Notion MCP Server
echo "Adding Notion MCP server to Claude Code..."
echo ""
echo "Running: claude mcp add --transport http notion https://mcp.notion.com/mcp"
echo ""

claude mcp add --transport http notion https://mcp.notion.com/mcp

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Notion MCP server added successfully!"
else
  echo ""
  echo "❌ Failed to add Notion MCP server."
  echo "   Try running manually:"
  echo "   claude mcp add --transport http notion https://mcp.notion.com/mcp"
  exit 1
fi

echo ""
echo "====================================="
echo " Next Step — Authenticate"
echo "====================================="
echo ""
echo "1. Open Claude Code:  claude"
echo "2. Run inside Claude: /mcp"
echo "3. Follow the OAuth flow to connect your Notion workspace"
echo ""
echo "After authentication, test with:"
echo '   "Search my Notion workspace for workshop"'
echo ""
echo "====================================="
echo " Setup Complete"
echo "====================================="
echo ""
