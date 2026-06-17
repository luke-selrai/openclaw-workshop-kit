#!/usr/bin/env bash
# connect-via-composio.sh — Tier 2 OAuth driver for Composio Tool Router (one-OAuth → 1000+ apps)
# Successor to Rube, which was discontinued (~2026-05-15; rube.app/mcp is dead).
# Idempotent: detects an existing Composio install, registers only if needed,
# then points the user at the one-time OAuth approval.
#
# Usage:
#   ./connect-via-composio.sh           # full setup or "already connected" no-op
#   ./connect-via-composio.sh --check   # just print status, no install
#   ./connect-via-composio.sh --force   # re-add even if present
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
if claude mcp list 2>/dev/null | grep -qE '^composio\b|^mcp__composio'; then
    INSTALLED=1
fi

if [[ $INSTALLED -eq 1 && $FORCE -eq 0 ]]; then
    if [[ $CHECK_ONLY -eq 1 ]]; then
        echo "composio: installed"
        exit 0
    fi
    echo "Composio MCP already installed. Skipping setup."
    echo "If OAuth has expired, re-run with --force."
    exit 0
fi

if [[ $CHECK_ONLY -eq 1 ]]; then
    echo "composio: not installed"
    exit 1
fi

echo "Step 1/2: registering Composio Tool Router MCP server"
# OAuth is automatic — no API-key header and no separate authenticate tool call.
claude mcp add composio --transport http --url https://connect.composio.dev/mcp >/dev/null 2>&1 \
    || claude mcp add composio --transport http --url https://connect.composio.dev/mcp || true

echo "Step 2/2: one-time OAuth approval"
echo "    The first time the agent calls a Composio tool, it prints an approval URL."
echo "    Open it, sign in to Composio, approve. That is the only manual step."
echo
echo "    NOTE: one-time per-laptop. After approval, every Composio-supported"
echo "    service (Slack, GHL, HubSpot, Stripe, Shopify, Calendly, Salesforce, ...)"
echo "    is reachable through mcp__composio__* tools without further OAuth dialogs."
echo
echo "Composio setup primed. Switch to your agent and make any mcp__composio__* call to trigger approval."
