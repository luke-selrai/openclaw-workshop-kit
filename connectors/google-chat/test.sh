#!/bin/bash
# Test that Google Chat Toolkit is installed and working
# Run: bash test.sh

HOME_DIR="$HOME"
GWS_DIR="$HOME_DIR/.config/gws"

echo ""
echo "=== Google Chat Toolkit Health Check ==="
echo ""

PASS=0
FAIL=0

# Check skill installed
if [ -f "$HOME_DIR/.claude/skills/google-chat/SKILL.md" ]; then
  echo "[pass] google-chat skill installed"
  PASS=$((PASS+1))
else
  echo "[FAIL] google-chat skill not found at ~/.claude/skills/google-chat/"
  FAIL=$((FAIL+1))
fi

# Check gws CLI
if command -v gws &>/dev/null; then
  GWS_VER=$(gws --version 2>&1 | head -1 | awk '{print $2}')
  echo "[pass] gws CLI installed (v$GWS_VER)"
  PASS=$((PASS+1))
else
  echo "[FAIL] gws CLI not found. Run: npm install -g @googleworkspace/cli"
  FAIL=$((FAIL+1))
fi

# Check client_secret.json
if [ -f "$GWS_DIR/client_secret.json" ]; then
  echo "[pass] client_secret.json exists"
  PASS=$((PASS+1))
else
  echo "[FAIL] No client_secret.json at ~/.config/gws/"
  echo "       Set up a GCP project or get the file from your team"
  FAIL=$((FAIL+1))
fi

# Check credentials
CRED_FOUND=false
for f in "$GWS_DIR"/credentials*.json; do
  if [ -f "$f" ] && [ "$(basename "$f")" != "client_secret.json" ]; then
    CRED_FOUND=true
    break
  fi
done

if $CRED_FOUND; then
  echo "[pass] OAuth credentials found"
  PASS=$((PASS+1))
else
  echo "[FAIL] No OAuth credentials. Run: gws auth login -s chat"
  FAIL=$((FAIL+1))
fi

# Test live API - list spaces
if $CRED_FOUND && command -v gws &>/dev/null; then
  echo ""
  echo "Testing Chat API connection..."
  RESULT=$(gws chat spaces list --format json 2>&1)

  if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('spaces',[])))" 2>/dev/null; then
    SPACE_COUNT=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('spaces',[])))" 2>/dev/null)
    echo "[pass] Chat API working - found $SPACE_COUNT spaces"
    PASS=$((PASS+1))
  elif echo "$RESULT" | grep -q "PERMISSION_DENIED\|UNAUTHENTICATED\|insufficient"; then
    echo "[FAIL] Chat API returned permission error"
    echo "       Run: gws auth login -s chat"
    FAIL=$((FAIL+1))
  elif echo "$RESULT" | grep -q "decrypt token"; then
    echo "[FAIL] Token cache corrupted"
    echo "       Fix: rm ~/.config/gws/token_cache.json && gws auth login -s chat"
    FAIL=$((FAIL+1))
  else
    echo "[FAIL] Chat API returned unexpected response"
    echo "       First 200 chars: $(echo "$RESULT" | head -c 200)"
    FAIL=$((FAIL+1))
  fi
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -eq 0 ]; then
  echo ""
  echo "All good! Open Claude Code and try:"
  echo "  'List my Google Chat spaces'"
  echo "  'Read the latest messages in the Development Team chat'"
  echo ""
else
  echo ""
  echo "Fix the issues above, then run this test again."
  echo ""
fi
