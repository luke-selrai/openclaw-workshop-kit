#!/bin/bash
# GHL Toolkit Installer for Claude Code
# Run: bash setup.sh

set -e

echo ""
echo "=== GHL Toolkit for Claude Code ==="
echo ""

# Detect home and OS
HOME_DIR="$HOME"
CLAUDE_DIR="$HOME_DIR/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect project directory (use the default home project)
PROJECT_DIR="$CLAUDE_DIR/projects/-Users-$(whoami)"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
SECRETS_DIR="$PROJECT_DIR/secrets"

# Prereq check
if [ ! -d "$CLAUDE_DIR" ]; then
  echo "ERROR: ~/.claude directory not found."
  echo "Install Claude Code first: https://claude.ai/code"
  exit 1
fi

echo "Installing to:"
echo "  Skills:  $SKILLS_DIR/"
echo "  Scripts: $SCRIPTS_DIR/"
echo "  Secrets: $SECRETS_DIR/"
echo ""

# Create directories
mkdir -p "$SKILLS_DIR"
mkdir -p "$SCRIPTS_DIR"
mkdir -p "$SECRETS_DIR"

# Copy skills (overwrite if re-running)
rm -rf "$SKILLS_DIR/ghl-crm" "$SKILLS_DIR/ghl-browser"
cp -r "$SCRIPT_DIR/skills/ghl-crm" "$SKILLS_DIR/ghl-crm"
cp -r "$SCRIPT_DIR/skills/ghl-browser" "$SKILLS_DIR/ghl-browser"
echo "[done] Skills installed"

# Copy bash helper
cp "$SCRIPT_DIR/scripts/ghl" "$SCRIPTS_DIR/ghl"
chmod +x "$SCRIPTS_DIR/ghl"
echo "[done] Bash helper installed"

# Update the source path in the ghl script to point to the actual secrets location
# Use a temp file approach (reliable across macOS and Linux)
GHL_SCRIPT="$SCRIPTS_DIR/ghl"
sed "s|source.*ghl\.env.*|source \"$SECRETS_DIR/ghl.env\"|" "$GHL_SCRIPT" > "$GHL_SCRIPT.tmp"
mv "$GHL_SCRIPT.tmp" "$GHL_SCRIPT"
chmod +x "$GHL_SCRIPT"
echo "[done] Script paths configured"

# Copy secrets template (don't overwrite existing)
if [ -f "$SECRETS_DIR/ghl.env" ]; then
  echo "[skip] ghl.env already exists, not overwriting"
else
  cp "$SCRIPT_DIR/secrets/ghl.env.template" "$SECRETS_DIR/ghl.env"
  echo "[done] Secrets template copied"
fi

# Update skill files with correct paths
sed -i.bak "s|<your-project>|-Users-$(whoami)|g" "$SKILLS_DIR/ghl-crm/SKILL.md"
rm -f "$SKILLS_DIR/ghl-crm/SKILL.md.bak"

sed -i.bak "s|<your-project>|-Users-$(whoami)|g" "$SKILLS_DIR/ghl-browser/SKILL.md"
rm -f "$SKILLS_DIR/ghl-browser/SKILL.md.bak"

sed -i.bak "s|<YOUR_USER>|$(whoami)|g" "$SKILLS_DIR/ghl-browser/SKILL.md"
rm -f "$SKILLS_DIR/ghl-browser/SKILL.md.bak"

echo "[done] Paths updated in skill files"

echo ""
echo "=== Installation complete ==="
echo ""
echo "NEXT STEPS:"
echo ""
echo "  1. Edit your credentials file:"
echo "     open $SECRETS_DIR/ghl.env"
echo ""
echo "  2. Fill in these 4 values (instructions inside the file):"
echo "     - GHL_API_KEY"
echo "     - GHL_LOCATION_ID"
echo "     - GHL_LOGIN_EMAIL"
echo "     - GHL_LOGIN_PASSWORD"
echo ""
echo "  3. Test it works:"
echo "     bash $SCRIPT_DIR/test.sh"
echo ""
echo "  4. Open Claude Code and ask:"
echo "     'Search my GHL contacts for John'"
echo ""
