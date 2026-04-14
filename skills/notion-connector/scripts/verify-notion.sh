#!/bin/bash

# ============================================
# Notion Connector — Verify Script
# Selr AI Workshop Kit
# ============================================

echo ""
echo "====================================="
echo " Notion Connector — Verification"
echo "====================================="
echo ""

PASS=0
FAIL=0

# Check 1 — Node.js
echo "Checking Node.js..."
if command -v node &> /dev/null; then
  echo "✅ Node.js: $(node --version)"
  PASS=$((PASS + 1))
else
  echo "❌ Node.js not found"
  FAIL=$((FAIL + 1))
fi

echo ""

# Check 2 — Claude Code
echo "Checking Claude Code..."
if command -v claude &> /dev/null; then
  echo "✅ Claude Code: $(claude --version)"
  PASS=$((PASS + 1))
else
  echo "❌ Claude Code not found"
  FAIL=$((FAIL + 1))
fi

echo ""

# Check 3 — Notion MCP registered
echo "Checking Notion MCP server registration..."
if claude mcp list 2>/dev/null | grep -q "notion"; then
  echo "✅ Notion MCP server is registered"
  PASS=$((PASS + 1))
else
  echo "❌ Notion MCP server not found"
  echo "   Run: claude mcp add --transport http notion https://mcp.notion.com/mcp"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "====================================="
echo " Results: $PASS passed / $FAIL failed"
echo "====================================="
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✅ Notion Connector is ready!"
  echo ""
  echo "Open Claude Code and test with:"
  echo '   "Search my Notion workspace for workshop"'
else
  echo "⚠️  Fix the issues above then run this script again."
fi

echo ""
