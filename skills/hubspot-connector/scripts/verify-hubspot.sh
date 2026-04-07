#!/bin/bash

# HubSpot Connector Verify Script
# Selr AI — Workshop Kit
# Confirms HubSpot CLI is installed and authenticated

echo "======================================"
echo "  HubSpot Connector — Verify"
echo "  Selr AI Workshop Kit"
echo "======================================"

PASS=0
FAIL=0

check_pass() {
  echo "  ✓ $1"
  PASS=$((PASS+1))
}

check_fail() {
  echo "  ✗ FAILED: $1"
  FAIL=$((FAIL+1))
}

echo ""
echo "Checking HubSpot CLI installation..."

# Check Node.js
if command -v node &> /dev/null; then
  check_pass "Node.js installed: $(node --version)"
else
  check_fail "Node.js not found"
fi

# Check HubSpot CLI
if command -v hs &> /dev/null; then
  check_pass "HubSpot CLI installed: $(hs --version)"
else
  check_fail "HubSpot CLI not found — run: npm install -g @hubspot/cli"
fi

# Check authentication
echo ""
echo "Checking HubSpot authentication..."
if hs accounts list &> /dev/null; then
  check_pass "HubSpot authenticated"
  echo ""
  echo "  Connected portals:"
  hs accounts list
else
  check_fail "HubSpot not authenticated — run: hs auth"
fi

echo ""
echo "======================================"
echo "  Results: $PASS passed / $FAIL failed"
echo "======================================"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Run install-hubspot.sh to fix issues."
  exit 1
fi

echo ""
echo "HubSpot Connector is ready to use."
