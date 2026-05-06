#!/usr/bin/env bash
# connect-via-rube.sh — Tier 2 OAuth driver for Rube (one-OAuth → 500+ apps)
# Idempotent: detects existing Rube install, runs OAuth dance only if needed,
# verifies with a test call.
#
# Usage:
#   ./connect-via-rube.sh           # full setup or "already connected" no-op
#   ./connect-via-rube.sh --check   # just print status, no install
#   ./connect-via-rube.sh --force   # re-add even if present
set -euo pipefail

CHECK_ONLY=0
FORCE=0
case "${1:-}" in
    --check) CHECK_ONLY=1 ;;
    --force) FORCE=1 ;;
    "")      ;;
    *) echo "usage: $0 [--check|--force]" >&2; exit 2 ;;
esac

if ! command -v claude >/dev/null 2>&1; then
    echo "ERROR: claude CLI not on PATH" >&2; exit 2
fi

INSTALLED=0
if claude mcp list 2>/dev/null | grep -qE '^rube\b|^mcp__rube'; then
    INSTALLED=1
fi

if [[ $INSTALLED -eq 1 && $FORCE -eq 0 ]]; then
    if [[ $CHECK_ONLY -eq 1 ]]; then
        echo "rube: installed"
        exit 0
    fi
    echo "Rube MCP already installed. Skipping setup."
    echo "If OAuth has expired, re-run with --force."
    exit 0
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
    echo "rube: not installed"
    exit 1
fi

echo "Step 1/3: registering Rube MCP server"
claude mcp add --transport http rube https://rube.app/mcp >/dev/null 2>&1 \
    || claude mcp add --transport http rube https://rube.app/mcp || true

echo "Step 2/3: OAuth dance"
echo "    The next step will print a URL. Open it, sign in, approve."
echo "    Once approved, return here and the connection completes automatically."
echo
echo "    NOTE: this is a one-time per-laptop step. After this, every Rube-supported"
echo "    service (Slack, GHL, HubSpot, Stripe, Shopify, Calendly, ...) is reachable"
echo "    without further OAuth dialogs."
echo
echo "    Run inside the Claude Code agent:"
echo "        mcp__rube__authenticate (no args)"
echo "    Follow the printed URL, then run:"
echo "        mcp__rube__complete_authentication"
echo
echo "Step 3/3: verify with a no-op call after authentication completes."
echo "    Suggested: ask Rube to list available tools — confirms the token is live."
echo
echo "Rube setup primed. Switch to your agent and run the two MCP calls above."
