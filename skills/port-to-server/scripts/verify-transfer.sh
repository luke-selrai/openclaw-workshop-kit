#!/bin/bash

# Verify Transfer Script
# Confirms all expected files landed correctly on the remote server

echo "======================================"
echo "  Claude Code — Verify Transfer"
echo "  Selr AI Workshop Kit"
echo "======================================"

read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your SSH username (default: ubuntu): " SSH_USER
SSH_USER=${SSH_USER:-ubuntu}

echo ""
echo "Checking remote server for Claude Code files..."
echo ""

ssh "$SSH_USER@$SERVER_IP" bash << 'EOF'

PASS=0
FAIL=0

check() {
  if [ -e "$1" ]; then
    echo "  ✓ $2"
    PASS=$((PASS+1))
  else
    echo "  ✗ MISSING: $2 ($1)"
    FAIL=$((FAIL+1))
  fi
}

check "$HOME/claude-transfer-temp/skills" "Skills folder"
check "$HOME/claude-transfer-temp/agents" "Agents folder"
check "$HOME/claude-transfer-temp/mcp_config.json" "MCP config"
check "$HOME/claude-transfer-temp/projects" "Project memories"
check "$HOME/claude-transfer-temp/CLAUDE.md" "CLAUDE.md"

echo ""
echo "======================================"
echo "  Results: $PASS passed / $FAIL missing"
echo "======================================"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Re-run port-to-server.sh to retry missing files."
fi

EOF
