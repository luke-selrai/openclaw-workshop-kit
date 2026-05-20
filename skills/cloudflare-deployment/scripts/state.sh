#!/usr/bin/env bash
# state.sh
# Read / write the state file at ~/.claude/state/cloudflare-deployment.json
# Requires jq.

CF_STATE_PATH="$HOME/.claude/state/cloudflare-deployment.json"

cf_state_init() {
  mkdir -p "$HOME/.claude/state"
  if [ ! -f "$CF_STATE_PATH" ]; then
    cat > "$CF_STATE_PATH" <<EOF
{
  "version": 1,
  "node_installed": false,
  "wrangler_installed": false,
  "wrangler_version": null,
  "skills_bundle_installed": false,
  "authenticated": false,
  "account_id": null,
  "account_email": null,
  "last_verified_at": null,
  "playwright_fallback_used": false
}
EOF
  fi
}

cf_state_get() {
  local field="$1"
  cf_state_init
  jq -r ".$field" "$CF_STATE_PATH"
}

cf_state_set() {
  local field="$1"
  local value="$2"
  cf_state_init
  local tmp
  tmp=$(mktemp)
  jq ".$field = $value | .last_verified_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$CF_STATE_PATH" > "$tmp"
  mv "$tmp" "$CF_STATE_PATH"
}

# CLI usage: state.sh get <field>  |  state.sh set <field> <json-value>
if [ "$1" = "get" ]; then
  cf_state_get "$2"
elif [ "$1" = "set" ]; then
  cf_state_set "$2" "$3"
fi
