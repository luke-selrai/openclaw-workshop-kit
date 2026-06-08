#!/usr/bin/env bash
# Re-runnable health check for the Higgsfield connector.
# Exit 0 = installed AND authenticated; 1 = installed but NOT authenticated;
#        2 = CLI not installed.
# Never prints the access token.
set -u

if ! command -v higgsfield >/dev/null 2>&1; then
  echo "FAIL: higgsfield CLI not installed. Install: npm install -g @higgsfield/cli"
  exit 2
fi

echo "OK:   higgsfield installed — $(higgsfield --version 2>&1 | head -1)"

# account status prints "email — plan, N credits" when authed,
# or "Error: Not authenticated." when not. Do NOT use `auth token` (prints secret).
status="$(higgsfield account status 2>&1)"
if printf '%s' "$status" | grep -qi "not authenticated"; then
  echo "WARN: not authenticated. Run: higgsfield auth login"
  exit 1
fi

echo "OK:   authenticated — $status"
exit 0
