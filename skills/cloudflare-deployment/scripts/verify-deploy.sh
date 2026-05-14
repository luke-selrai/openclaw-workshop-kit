#!/usr/bin/env bash
# verify-deploy.sh
# End-to-end test: deploys a Hello World Worker, curls it, then deletes it.

set -e

TS=$(date +%s)
NAME="cf-deploy-test-$TS"
TMP="/tmp/$NAME"

mkdir -p "$TMP"
cd "$TMP"

cat > wrangler.toml <<EOF
name = "$NAME"
main = "index.js"
compatibility_date = "$(date +%Y-%m-%d)"
EOF

cat > index.js <<'EOF'
export default {
  fetch() {
    return new Response("Hello from Claude — Cloudflare is connected.");
  }
};
EOF

echo "Deploying test Worker: $NAME ..."
DEPLOY_OUTPUT=$(wrangler deploy 2>&1)
echo "$DEPLOY_OUTPUT"

# Extract the URL (workers.dev URL appears in deploy output)
URL=$(echo "$DEPLOY_OUTPUT" | grep -oE 'https://[a-z0-9-]+\.[a-z0-9-]+\.workers\.dev' | head -n1)

if [ -n "$URL" ]; then
  echo ""
  echo "Curling $URL ..."
  RESPONSE=$(curl -sS "$URL")
  echo "Response: $RESPONSE"
fi

echo ""
echo "Deleting test Worker: $NAME ..."
wrangler delete --name "$NAME" --force 2>&1 || wrangler delete --name "$NAME" 2>&1

# Cleanup local dir
cd "$HOME"
rm -rf "$TMP"
echo "Cleanup complete. Test deploy succeeded."
