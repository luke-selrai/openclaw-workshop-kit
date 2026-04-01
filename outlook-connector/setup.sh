#!/bin/bash

echo "================================================"
echo "  Outlook & Microsoft 365 Connector Setup"
echo "  Built by Selr AI — selrai.com.au"
echo "================================================"
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed."
    echo "Please install it from https://nodejs.org and run this again."
    exit 1
fi
echo "Node.js found: $(node --version)"
echo ""

# Install m365 CLI
echo "Installing the Microsoft 365 tool..."
echo "This may take a minute — that is normal."
echo ""
npm install -g @pnp/cli-microsoft365

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Install failed. Try running with sudo:"
    echo "  sudo npm install -g @pnp/cli-microsoft365"
    exit 1
fi
echo ""
echo "Install complete!"
echo ""

# Sign in
echo "Signing in to your Microsoft account..."
echo "A browser window is about to open."
echo "Pick the Microsoft account you want to use, then click Allow."
echo ""
m365 login --authType browser

if [ $? -ne 0 ]; then
    echo ""
    echo "Browser login failed. Trying device code login instead..."
    m365 login
fi
echo ""

# Verify
echo "Verifying the connection..."
m365 outlook mail list --pageSize 3
echo ""
echo "================================================"
echo "  Done! Your Microsoft 365 account is connected."
echo "  Ask your assistant: 'Show me my unread emails'"
echo "================================================"
