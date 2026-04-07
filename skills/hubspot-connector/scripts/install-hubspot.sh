#!/bin/bash

# HubSpot Connector Install Script
# Selr AI — Workshop Kit
# Installs and authenticates HubSpot CLI for Claude Code

set -e

echo "======================================"
echo "  HubSpot Connector — Install"
echo "  Selr AI Workshop Kit"
echo "======================================"

# Step 1: Check Node.js
echo ""
echo "Step 1: Checking Node.js version..."
if ! command -v node &> /dev/null; then
  echo "  ✗ Node.js not found"
  echo ""
  echo "  Please install Node.js v18 or above:"
  echo "  macOS:   brew install node"
  echo "  Windows: winget install OpenJS.NodeJS"
  echo "  Linux:   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
  echo "           sudo apt-get install -y nodejs"
  exit 1
fi

NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "  ✗ Node.js version too low: $(node --version)"
  echo "  Required: v18 or above"
  exit 1
fi

echo "  ✓ Node.js $(node --version) detected"

# Step 2: Install HubSpot CLI
echo ""
echo "Step 2: Installing HubSpot CLI..."
if command -v hs &> /dev/null; then
  echo "  ✓ HubSpot CLI already installed: $(hs --version)"
else
  npm install -g @hubspot/cli
  echo "  ✓ HubSpot CLI installed: $(hs --version)"
fi

# Step 3: Authenticate
echo ""
echo "Step 3: Authenticating with HubSpot..."
echo ""
echo "  You will need your HubSpot Personal Access Key."
echo "  Get it from: HubSpot → Settings → Integrations → Private Apps"
echo ""
read -p "  Press ENTER when you have your Personal Access Key ready..."
echo ""
hs auth

# Step 4: Verify
echo ""
echo "Step 4: Verifying connection..."
hs accounts list

echo ""
echo "======================================"
echo "  HubSpot Connector installed!"
echo "======================================"
echo ""
echo "You can now ask Claude Code to:"
echo "  - Get all contacts from HubSpot"
echo "  - Show all open deals"
echo "  - List pipeline stages"
echo "  - Find contact by email"
echo ""
