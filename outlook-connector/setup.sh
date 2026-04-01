#!/bin/bash
set -euo pipefail

echo "================================================"
echo "  Outlook & Microsoft 365 Connector Setup"
echo "  Built by Selr AI -- selrai.com.au"
echo "================================================"
echo ""

# ------------------------------------------------
# STEP 1 -- Check Node.js
# ------------------------------------------------
echo "[1/5] Checking Node.js..."

if ! command -v node &> /dev/null; then
    echo ""
    echo "  Node.js is not installed on this computer."
    echo "  Please install it from: https://nodejs.org"
    echo "  Download the LTS version, run the installer, then run this script again."
    echo ""
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//' | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo ""
    echo "  Your Node.js version is too old (found: $(node --version))"
    echo "  This connector needs Node.js version 20 or higher."
    echo "  Please update from: https://nodejs.org and run this script again."
    echo ""
    exit 1
fi

echo "  Node.js $(node --version) -- OK"
echo ""

# ------------------------------------------------
# STEP 2 -- Install m365 CLI
# ------------------------------------------------
echo "[2/5] Installing the Microsoft 365 tool..."
echo "  This may take 1-2 minutes -- that is normal."
echo ""

# Try without sudo first, fall back to sudo if needed
if npm install -g @pnp/cli-microsoft365 2>/dev/null; then
    echo "  Installed successfully."
else
    echo "  Retrying with elevated permissions (you may be asked for your password)..."
    if sudo npm install -g @pnp/cli-microsoft365; then
        echo "  Installed successfully."
    else
        echo ""
        echo "  Install failed. Please check your internet connection and try again."
        echo "  If the problem persists, contact your workshop facilitator."
        echo ""
        exit 1
    fi
fi

# Refresh shell so m365 command is found
export PATH="$(npm prefix -g)/bin:$PATH"

if ! command -v m365 &> /dev/null; then
    echo ""
    echo "  The tool installed but cannot be found in this terminal session."
    echo "  Please close this terminal, open a new one, and run this script again."
    echo ""
    exit 1
fi

echo "  Microsoft 365 tool $(m365 --version) -- OK"
echo ""

# ------------------------------------------------
# STEP 3 -- Set up app connection (one-time)
# ------------------------------------------------
echo "[3/5] Setting up your Microsoft connection..."
echo "  A browser window will open. Sign in with your Microsoft account"
echo "  and follow the steps to approve the connection."
echo ""

if ! m365 setup --interactive; then
    echo ""
    echo "  Setup did not complete. Please try again or contact your workshop facilitator."
    echo ""
    exit 1
fi

echo "  Connection set up -- OK"
echo ""

# ------------------------------------------------
# STEP 4 -- Sign in
# ------------------------------------------------
echo "[4/5] Signing in to your Microsoft account..."
echo "  A browser window will open. Pick the account you want to use"
echo "  and click Accept or Allow when asked."
echo ""

if m365 login --authType browser; then
    echo "  Signed in -- OK"
elif m365 login; then
    # Device code fallback
    echo "  Signed in via device code -- OK"
else
    echo ""
    echo "  Sign-in failed. Please check your internet connection and try again."
    echo ""
    exit 1
fi

echo ""

# ------------------------------------------------
# STEP 5 -- Verify
# ------------------------------------------------
echo "[5/5] Checking the connection works..."

if m365 outlook mail list --pageSize 3 > /dev/null 2>&1; then
    echo "  Connection verified -- OK"
else
    echo "  Connected but could not read emails."
    echo "  This is usually fine -- try asking your assistant anyway."
fi

echo ""
echo "================================================"
echo "  All done! Your Microsoft 365 account is set up."
echo ""
echo "  Go to your AI assistant and try saying:"
echo "    'Show me my unread emails'"
echo "    'What meetings do I have this week?'"
echo "    'List my recent OneDrive files'"
echo "================================================"
