#!/bin/bash
# Google Chat Toolkit Installer for Claude Code
# Run: bash setup.sh

set -e

echo ""
echo "=== Google Chat Toolkit for Claude Code ==="
echo ""

HOME_DIR="$HOME"
CLAUDE_DIR="$HOME_DIR/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GWS_DIR="$HOME_DIR/.config/gws"

# Prereq check
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "[FAIL] ~/.claude directory not found."
  echo "       Install Claude Code first: https://claude.ai/code"
  exit 1
fi

echo "Step 1/4: Checking dependencies..."
echo ""

# Check Node.js
if command -v node &>/dev/null; then
  echo "[pass] Node.js installed ($(node --version))"
else
  echo "[FAIL] Node.js not found."
  echo "       Install: brew install node"
  exit 1
fi

# Check/install gws CLI
if command -v gws &>/dev/null; then
  GWS_VER=$(gws --version 2>&1 | head -1 | awk '{print $2}')
  echo "[pass] gws CLI installed (v$GWS_VER)"
else
  echo "[info] Installing gws CLI..."
  npm install -g @googleworkspace/cli
  if command -v gws &>/dev/null; then
    echo "[done] gws CLI installed"
  else
    echo "[FAIL] gws CLI install failed. Try: sudo npm install -g @googleworkspace/cli"
    exit 1
  fi
fi

# Check gcloud (needed for GCP project setup)
if command -v gcloud &>/dev/null; then
  echo "[pass] gcloud CLI installed"
else
  echo "[warn] gcloud CLI not found. You'll need it for GCP project setup."
  echo "       Install: https://cloud.google.com/sdk/docs/install"
  echo "       Or: brew install --cask google-cloud-sdk"
  echo ""
  echo "       If you already have a client_secret.json from someone on your team,"
  echo "       you can skip gcloud and just place the file at: ~/.config/gws/client_secret.json"
fi

echo ""
echo "Step 2/4: Installing skill..."

# Install skill
mkdir -p "$SKILLS_DIR"
rm -rf "$SKILLS_DIR/google-chat"
cp -r "$SCRIPT_DIR/skills/google-chat" "$SKILLS_DIR/google-chat"
echo "[done] google-chat skill installed"

echo ""
echo "Step 3/4: Setting up GCP project + OAuth..."
echo ""

mkdir -p "$GWS_DIR"

if [ -f "$GWS_DIR/client_secret.json" ]; then
  echo "[skip] client_secret.json already exists"
else
  echo "You need a GCP project with the Chat API enabled and an OAuth client."
  echo ""
  echo "Option A: Automated (needs gcloud CLI authenticated)"
  echo "  Run: gws auth setup --login"
  echo "  This creates the GCP project, enables APIs, and authenticates in one go."
  echo ""
  echo "Option B: Manual"
  echo "  1. Go to https://console.cloud.google.com"
  echo "  2. Create a new project (or use existing)"
  echo "  3. Enable these APIs: Chat API, Gmail API, Drive API, Calendar API"
  echo "  4. Go to APIs & Services > Credentials > Create OAuth Client ID"
  echo "     - Application type: Desktop app"
  echo "     - Download the JSON"
  echo "  5. Save it as: ~/.config/gws/client_secret.json"
  echo ""
  echo "Option C: Use a shared client_secret.json from your team"
  echo "  Just copy the file to: ~/.config/gws/client_secret.json"
fi

echo ""
echo "Step 4/4: Authentication..."
echo ""

# Check if already authenticated
if ls "$GWS_DIR"/credentials*.json 1>/dev/null 2>&1; then
  AUTH_STATUS=$(gws auth status 2>&1 | grep '"token_valid"' | grep -c 'true' || true)
  if [ "$AUTH_STATUS" = "1" ]; then
    echo "[pass] Already authenticated"
  else
    echo "[info] Credentials exist but may need refresh."
    echo "       Run: gws auth login -s chat,gmail,calendar,drive"
  fi
else
  if [ -f "$GWS_DIR/client_secret.json" ]; then
    echo "Ready to authenticate. Run:"
    echo "  gws auth login -s chat,gmail,calendar,drive"
    echo ""
    echo "This opens a browser window where you sign in with your Google Workspace account."
  else
    echo "[wait] Complete Step 3 first (set up GCP project), then run:"
    echo "       gws auth login -s chat,gmail,calendar,drive"
  fi
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. If you haven't already, set up your GCP project (Step 3 above)"
echo ""
echo "  2. Authenticate:"
echo "     gws auth login -s chat,gmail,calendar,drive"
echo ""
echo "  3. Test it:"
echo "     bash $SCRIPT_DIR/test.sh"
echo ""
echo "  4. Open Claude Code and ask:"
echo "     'List my Google Chat spaces'"
echo "     'Send a message to the Development Team saying hello'"
echo ""
