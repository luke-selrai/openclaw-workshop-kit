#!/usr/bin/env bash
# install-wrangler.sh
# Install Wrangler globally. Falls back to npx if global install fails.

set -e

# Skip if already installed
if command -v wrangler >/dev/null 2>&1; then
  CURRENT=$(wrangler --version 2>&1 | head -n1)
  echo "Wrangler is already installed: $CURRENT"
  exit 0
fi

echo "Installing Wrangler globally..."
if npm install -g wrangler 2>&1; then
  echo "Wrangler installed globally."
else
  echo "Global install failed (likely a permission issue). Will use 'npx wrangler' going forward."
  # Mark a flag file the skill can read
  mkdir -p "$HOME/.claude/state"
  echo '{"wrangler_mode":"npx"}' > "$HOME/.claude/state/cloudflare-wrangler-mode.json"
  # Verify npx can resolve it
  if npx --yes wrangler --version >/dev/null 2>&1; then
    echo "npx wrangler is reachable."
    exit 0
  else
    echo "npx wrangler also failed. Try 'sudo npm install -g wrangler' or fix your npm prefix."
    exit 1
  fi
fi

# Optional: install preview unified CLI (don't fail if it doesn't publish)
echo "Attempting optional install of @cloudflare/cf (preview unified CLI)..."
npm install -g @cloudflare/cf 2>/dev/null || echo "(@cloudflare/cf not available — skipping. This is optional.)"

# Verify
wrangler --version
