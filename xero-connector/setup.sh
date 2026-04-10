#!/bin/bash
# Xero Connector Setup
# Built by Selr AI -- selrai.com.au

# ------------------------------------------------
# MAC: Remove Gatekeeper quarantine FIRST
# ------------------------------------------------
OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
    xattr -d com.apple.quarantine "$0" 2>/dev/null || true
    chmod +x "$0" 2>/dev/null || true
fi

set -uo pipefail

echo "================================================"
echo "  Xero Connector Setup"
echo "  Built by Selr AI -- selrai.com.au"
echo "================================================"
echo ""

# ------------------------------------------------
# LOAD NVM  (if installed)
# ------------------------------------------------
for NVM_PATH in \
    "$HOME/.nvm/nvm.sh" \
    "$HOME/.config/nvm/nvm.sh" \
    "/usr/local/opt/nvm/nvm.sh"; do
    if [ -s "$NVM_PATH" ]; then
        # shellcheck source=/dev/null
        source "$NVM_PATH"
        break
    fi
done

# ------------------------------------------------
# MAC APPLE SILICON: Add Homebrew to PATH
# ------------------------------------------------
if [ "$OS_TYPE" = "Darwin" ] && [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# ------------------------------------------------
# CORPORATE PROXY NOTICE
# ------------------------------------------------
if [ -n "${HTTPS_PROXY:-}" ]; then
    echo "  Corporate proxy detected: $HTTPS_PROXY"
    echo ""
elif [ -n "${HTTP_PROXY:-}" ]; then
    echo "  Corporate proxy detected: $HTTP_PROXY"
    echo "  If sign-in fails, run:  export HTTPS_PROXY=$HTTP_PROXY"
    echo ""
fi

# ------------------------------------------------
# STEP 1  -- Check Node.js
# ------------------------------------------------
echo "[1/4] Checking Node.js..."

if ! command -v node &>/dev/null; then
    echo ""
    echo "  Node.js is not installed."
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "  Install options:"
        echo "    Recommended: https://nodejs.org (download LTS installer)"
        echo "    Homebrew:    brew install node"
        echo "    nvm:         curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        echo "                 then: source ~/.nvm/nvm.sh && nvm install --lts"
    else
        echo "  Install from: https://nodejs.org (download the LTS version)"
    fi
    echo "  Then run this script again."
    echo ""
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//' | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo ""
    echo "  Node.js version too old (found: $(node --version))"
    echo "  This connector needs Node.js v20 or higher."
    echo "  Update at https://nodejs.org and run this script again."
    echo ""
    exit 1
fi

echo "  Node.js $(node --version) -- OK"
echo ""

# ------------------------------------------------
# STEP 2  -- npm install
# ------------------------------------------------
echo "[2/4] Installing dependencies..."
echo "  This may take 1-2 minutes -- that is normal."
echo ""

INSTALL_OK=false
INSTALL_LOG="$(mktemp)"
INSTALL_ATTEMPTS=0

do_npm_install() {
    npm install >"$INSTALL_LOG" 2>&1
}

INSTALL_ATTEMPTS=$((INSTALL_ATTEMPTS + 1))
if do_npm_install; then
    INSTALL_OK=true
else
    INSTALL_ERR=$(cat "$INSTALL_LOG")

    if echo "$INSTALL_ERR" | grep -qi "EINTEGRITY"; then
        echo "  Cache corruption detected -- cleaning and retrying..."
        npm cache clean --force >/dev/null 2>&1 || true
        INSTALL_ATTEMPTS=$((INSTALL_ATTEMPTS + 1))
        if do_npm_install; then INSTALL_OK=true; fi

    elif echo "$INSTALL_ERR" | grep -qi "EACCES\|permission denied"; then
        echo "  Permission error. Recommended fix:"
        echo "    1. Install nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        echo "    2. Restart terminal, then: nvm install --lts"
        echo "    3. Run this script again."
        echo ""
        echo "  Trying with sudo as a fallback..."
        if sudo npm install >"$INSTALL_LOG" 2>&1; then INSTALL_OK=true; fi
    fi
fi

if [ "$INSTALL_OK" != "true" ]; then
    echo ""
    echo "  Install failed:"
    echo "  -----------------------------------------------"
    cat "$INSTALL_LOG"
    echo "  -----------------------------------------------"
    rm -f "$INSTALL_LOG"
    exit 1
fi

rm -f "$INSTALL_LOG"
echo "  Dependencies installed -- OK"
echo ""

# ------------------------------------------------
# STEP 3  -- Check / create .env
# ------------------------------------------------
echo "[3/4] Checking credentials file..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -f "$SCRIPT_DIR/.env" ]; then
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        echo "  Created .env from template."
    else
        printf 'XERO_CLIENT_ID=your_client_id_here\nXERO_CLIENT_SECRET=your_client_secret_here\n' > "$SCRIPT_DIR/.env"
        echo "  Created blank .env file."
    fi
fi

if grep -q "your_client_id_here" "$SCRIPT_DIR/.env" 2>/dev/null; then
    echo ""
    echo "  *** Action needed ***"
    echo ""
    echo "  Your .env file has placeholder values that need to be replaced."
    echo ""
    echo "  1. Go to: https://developer.xero.com/app/manage"
    echo "  2. Click your app (or create one -- it is free)"
    echo "  3. Copy your Client ID and Client Secret"
    echo "  4. Open $SCRIPT_DIR/.env and replace:"
    echo "       XERO_CLIENT_ID=your_client_id_here"
    echo "       XERO_CLIENT_SECRET=your_client_secret_here"
    echo ""
    echo "  See XERO-SETUP.md Step 2 for full instructions."
    echo ""
    echo "  Once you have updated .env, run this script again,"
    echo "  OR sign in directly with:  npm run auth"
    echo ""
    exit 0
fi

echo "  Credentials found -- OK"
echo ""

# ------------------------------------------------
# STEP 4  -- Run auth
# ------------------------------------------------
echo "[4/4] Connecting to Xero..."
echo "  A browser window will open. Sign in to Xero and click Allow."
echo ""

if ! npm run auth; then
    echo ""
    echo "  Sign-in did not complete. You can retry at any time:"
    echo "    npm run auth"
    echo ""
    exit 1
fi

echo ""
echo "================================================"
echo "  All done! Xero is connected to Claude Code."
echo ""
echo "  Next: add Xero to your Claude Code settings."
echo "  See XERO-SETUP.md Step 5 for instructions."
echo ""
echo "  Then try asking Claude:"
echo "    'Show me my recent Xero invoices'"
echo "    'List my Xero contacts'"
echo "    'Show me the Xero profit and loss'"
echo "================================================"

