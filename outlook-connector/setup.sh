#!/bin/bash
# Outlook & Microsoft 365 Connector Setup
# Built by Selr AI -- selrai.com.au

# ------------------------------------------------
# MAC: Remove Gatekeeper quarantine FIRST
# Downloaded files are blocked by default on macOS.
# This must run before set -euo pipefail so it doesn't abort on error.
# ------------------------------------------------
OS_TYPE="$(uname -s)"
if [ "$OS_TYPE" = "Darwin" ]; then
    xattr -d com.apple.quarantine "$0" 2>/dev/null || true
    chmod +x "$0" 2>/dev/null || true
fi

set -uo pipefail

echo "================================================"
echo "  Outlook & Microsoft 365 Connector Setup"
echo "  Built by Selr AI -- selrai.com.au"
echo "================================================"
echo ""

# ------------------------------------------------
# LOAD NVM  (Node Version Manager -- common alternative to system Node)
# Non-interactive shells don't source ~/.bashrc, so nvm is often missing.
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
# On M1/M2/M3 Macs Homebrew installs to /opt/homebrew, not /usr/local.
# ------------------------------------------------
if [ "$OS_TYPE" = "Darwin" ] && [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# ------------------------------------------------
# CORPORATE PROXY NOTICE
# npm reads HTTP_PROXY / HTTPS_PROXY but the m365 MSAL auth engine
# needs HTTPS_PROXY set separately at the shell level.
# ------------------------------------------------
if [ -n "${HTTPS_PROXY:-}" ]; then
    echo "  Corporate proxy detected: $HTTPS_PROXY"
    echo "  The sign-in tool will use this automatically."
    echo ""
elif [ -n "${HTTP_PROXY:-}" ]; then
    echo "  Corporate proxy detected: $HTTP_PROXY"
    echo "  Note: If sign-in fails through the proxy, run:"
    echo "    export HTTPS_PROXY=$HTTP_PROXY"
    echo "  then re-run this script."
    echo ""
fi

# ------------------------------------------------
# STEP 1  -- Check Node.js
# ------------------------------------------------
echo "[1/5] Checking Node.js..."

if ! command -v node &>/dev/null; then
    echo ""
    echo "  Node.js is not installed on this computer."
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "  Install options:"
        echo "    Option A (recommended): https://nodejs.org  -- download the LTS installer"
        echo "    Option B (Homebrew):    brew install node"
        echo "    Option C (nvm):         curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        echo "                            then: source ~/.nvm/nvm.sh && nvm install --lts"
    else
        echo "  Please install from: https://nodejs.org (download the LTS version)"
    fi
    echo "  Then run this script again."
    echo ""
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//' | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo ""
    echo "  Your Node.js version is too old (found: $(node --version))"
    echo "  This connector needs Node.js v20 or higher."
    echo "  Please update at https://nodejs.org and run this script again."
    echo ""
    exit 1
fi

echo "  Node.js $(node --version) -- OK"
echo ""

# ------------------------------------------------
# STEP 2  -- Install m365 CLI
# ------------------------------------------------
echo "[2/5] Installing the Microsoft 365 tool..."
echo "  This may take 1-2 minutes -- that is normal."
echo ""

INSTALL_OK=false
INSTALL_LOG="$(mktemp)"
INSTALL_ATTEMPTS=0

do_npm_install() {
    npm install -g @pnp/cli-microsoft365 >"$INSTALL_LOG" 2>&1
}

# First attempt (no sudo)
INSTALL_ATTEMPTS=$((INSTALL_ATTEMPTS + 1))
if do_npm_install; then
    INSTALL_OK=true
else
    INSTALL_ERR=$(cat "$INSTALL_LOG")

    # EINTEGRITY -- corrupted npm cache; clean and retry once
    if echo "$INSTALL_ERR" | grep -qi "EINTEGRITY"; then
        echo "  npm cache corruption detected -- cleaning and retrying..."
        npm cache clean --force >/dev/null 2>&1 || true
        INSTALL_ATTEMPTS=$((INSTALL_ATTEMPTS + 1))
        if do_npm_install; then
            INSTALL_OK=true
        fi

    # EACCES / permission denied -- needs elevated permissions
    elif echo "$INSTALL_ERR" | grep -qi "EACCES\|permission denied"; then
        echo "  Permission error on global install."
        echo ""
        if command -v nvm &>/dev/null; then
            # nvm is available but still getting EACCES -- something is wrong
            echo "  nvm is installed, but permissions are still blocked."
            echo "  Try: nvm use --lts && nvm alias default node"
            echo "  Then run this script again."
            echo ""
            cat "$INSTALL_LOG"
            rm -f "$INSTALL_LOG"
            exit 1
        else
            echo "  Recommended fix (avoids sudo entirely):"
            echo "    1. Install nvm:"
            echo "       curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
            echo "    2. Restart your terminal, then run:"
            echo "       nvm install --lts"
            echo "    3. Run this script again."
            echo ""
            echo "  Quick fix (sudo -- may cause issues later):"
            echo "    Retrying with sudo now..."
            echo ""
        fi
        if sudo npm install -g @pnp/cli-microsoft365 >"$INSTALL_LOG" 2>&1; then
            INSTALL_OK=true
        fi
    fi
fi

if [ "$INSTALL_OK" != "true" ]; then
    echo ""
    echo "  Install failed. Full error details:"
    echo "  -----------------------------------------------"
    cat "$INSTALL_LOG"
    echo "  -----------------------------------------------"
    echo ""
    echo "  Common fixes:"
    echo "  - Check your internet connection"
    echo "  - Corporate firewall? Ask IT to allow: registry.npmjs.org:443"
    rm -f "$INSTALL_LOG"
    exit 1
fi

rm -f "$INSTALL_LOG"

# Refresh PATH so m365 is found in this same terminal session
export PATH="$(npm prefix -g)/bin:$PATH"

if ! command -v m365 &>/dev/null; then
    echo ""
    echo "  The tool installed but cannot be found in this terminal session."
    echo "  Please close this terminal, open a new one, and run this script again."
    echo ""
    exit 1
fi

echo "  Microsoft 365 tool $(m365 --version) -- OK"
echo ""

# ------------------------------------------------
# STEP 3  -- Set up app connection  (one-time)
# ------------------------------------------------
echo "[3/5] Setting up your Microsoft connection..."
echo "  A browser window will open. Sign in with your Microsoft account"
echo "  and click Accept when asked to approve the connection."
echo "  (This links the Selr AI workshop app to your account -- one time only.)"
echo ""
echo "  If no browser opens, a URL will appear -- paste it into any browser."
echo ""

if ! m365 setup --interactive; then
    echo ""
    echo "  Setup did not complete. Possible causes:"
    echo "  - Browser was closed before approving"
    echo "  - Your organisation requires admin approval for new apps"
    echo ""
    echo "  If you see 'admin consent required':"
    echo "    Ask your IT admin or workshop facilitator to grant consent at:"
    echo "    https://entra.microsoft.com > Enterprise Applications > Grant admin consent"
    echo ""
    echo "  To retry just this step:"
    echo "    m365 setup --interactive"
    echo ""
    exit 1
fi

echo "  Connection set up -- OK"
echo ""

# ------------------------------------------------
# STEP 4  -- Sign in
# ------------------------------------------------
echo "[4/5] Signing in to your Microsoft account..."
echo "  A browser window will open. Pick the account you want to use"
echo "  and click Accept or Allow when asked."
echo ""

# Clear any stale session first
if m365 status >/dev/null 2>&1; then
    echo "  Existing session found -- refreshing..."
    m365 logout >/dev/null 2>&1 || true
fi

LOGIN_LOG="$(mktemp)"
LOGIN_OK=false

if m365 login --authType browser >"$LOGIN_LOG" 2>&1; then
    LOGIN_OK=true
else
    LOGIN_ERR=$(cat "$LOGIN_LOG")

    # AADSTS53003 -- Conditional Access blocks browser login
    if echo "$LOGIN_ERR" | grep -qi "53003\|AADSTS53003"; then
        echo "  Your organisation's security policy blocked browser sign-in."
        echo "  Switching to device code sign-in instead..."
        echo ""
        rm -f "$LOGIN_LOG"; LOGIN_LOG="$(mktemp)"
        if m365 login >"$LOGIN_LOG" 2>&1; then
            LOGIN_OK=true
        fi

    # AADSTS90094 -- Admin consent required
    elif echo "$LOGIN_ERR" | grep -qi "90094\|AADSTS90094"; then
        echo ""
        echo "  Your Microsoft tenant requires an IT administrator to approve this app."
        echo "  Ask your admin or workshop facilitator to grant consent at:"
        echo "    https://entra.microsoft.com"
        echo "    > Enterprise Applications > PnP Management Shell > Grant admin consent"
        echo ""
        rm -f "$LOGIN_LOG"
        exit 1

    # AADSTS70043 -- Token or session expired
    elif echo "$LOGIN_ERR" | grep -qi "70043\|AADSTS70043"; then
        echo "  Previous session expired -- clearing and retrying..."
        m365 logout >/dev/null 2>&1 || true
        rm -f "$LOGIN_LOG"; LOGIN_LOG="$(mktemp)"
        if m365 login --authType browser >"$LOGIN_LOG" 2>&1; then
            LOGIN_OK=true
        fi

    # Generic failure -- try device code as fallback
    else
        echo "  Browser sign-in failed. Trying device code sign-in..."
        echo "  (You will see a short code -- visit https://aka.ms/devicelogin and enter it)"
        echo ""
        rm -f "$LOGIN_LOG"; LOGIN_LOG="$(mktemp)"
        if m365 login >"$LOGIN_LOG" 2>&1; then
            LOGIN_OK=true
        fi
    fi
fi

if [ "$LOGIN_OK" != "true" ]; then
    echo ""
    echo "  Sign-in failed. Please check:"
    echo "  - Your internet connection"
    echo "  - Whether your organisation blocks external apps"
    echo "  - Contact your workshop facilitator if the problem continues"
    echo ""
    cat "$LOGIN_LOG"
    rm -f "$LOGIN_LOG"
    exit 1
fi

rm -f "$LOGIN_LOG"
echo "  Signed in -- OK"
echo ""

# ------------------------------------------------
# STEP 5  -- Verify
# ------------------------------------------------
echo "[5/5] Checking the connection works..."

if m365 outlook mail list --pageSize 3 >/dev/null 2>&1; then
    echo "  Connection verified -- OK"
else
    echo "  Connected but could not read emails right now."
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
