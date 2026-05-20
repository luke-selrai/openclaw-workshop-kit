#!/usr/bin/env bash
# login-and-wait.sh
# Trigger `wrangler login` and poll the wrangler config dir until credentials land.
# Times out at 120 seconds.

set -e

CONFIG_PATHS=(
  "$HOME/.config/.wrangler/config/default.toml"
  "$HOME/.wrangler/config/default.toml"
)

# If any config already exists and `wrangler whoami` succeeds, skip.
if wrangler whoami >/dev/null 2>&1; then
  echo "Already authenticated to Cloudflare."
  wrangler whoami
  exit 0
fi

echo "Opening Cloudflare OAuth in your browser. Click Allow to approve, then come back here..."
# Run wrangler login in the background so we can poll
wrangler login &
LOGIN_PID=$!

# Poll for up to 120 seconds
ELAPSED=0
INTERVAL=2
TIMEOUT=120
while [ $ELAPSED -lt $TIMEOUT ]; do
  for path in "${CONFIG_PATHS[@]}"; do
    if [ -f "$path" ]; then
      # Config exists — but make sure whoami actually works (the file may be a stub)
      if wrangler whoami >/dev/null 2>&1; then
        echo "Authentication complete."
        wait $LOGIN_PID 2>/dev/null || true
        wrangler whoami
        exit 0
      fi
    fi
  done
  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "Login timed out after ${TIMEOUT}s. Killing background process."
kill $LOGIN_PID 2>/dev/null || true
echo "Run this skill again, or use the Playwright fallback path."
exit 1
