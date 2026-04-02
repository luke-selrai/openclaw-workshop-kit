#!/bin/bash
# ============================================================================
#  SECURITY TESTS — Secret scanning, credential exposure, gitignore protection
# ============================================================================
SUITE_NAME="Security Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

# ── No Exposed Secrets ───────────────────────────────────────────
suite_header "Secret Scanning"

# Check for real .env files (not templates)
env_files=$(find "$ROOT_DIR" -name "*.env" -not -name "*.template" -not -path "*/.git/*" 2>/dev/null | wc -l)
assert_equals "No exposed .env files" "0" "$env_files"

# Check for credential files
cred_files=$(find "$ROOT_DIR" -name "client_secret*" -not -path "*/.git/*" 2>/dev/null | wc -l)
assert_equals "No exposed client_secret files" "0" "$cred_files"

# Check for private keys
key_files=$(find "$ROOT_DIR" -name "*.pem" -o -name "*.key" -not -path "*/.git/*" 2>/dev/null | wc -l)
assert_equals "No exposed private key files" "0" "$key_files"

# Check for token files
token_files=$(find "$ROOT_DIR" -name "token_cache*" -not -path "*/.git/*" 2>/dev/null | wc -l)
assert_equals "No exposed token cache files" "0" "$token_files"

# ── Secret Pattern Scanning ──────────────────────────────────────
suite_header "Secret Patterns in Code"

# Scan all non-git files for common secret patterns
ALL_FILES=$(find "$ROOT_DIR" -type f -not -path "*/.git/*" -not -name "04-security.sh" \
  \( -name "*.sh" -o -name "*.md" -o -name "*.json" -o -name "*.template" \))

# AWS Access Keys (AKIA followed by 16 uppercase alphanumeric)
aws_keys=$(echo "$ALL_FILES" | xargs grep -lE "AKIA[0-9A-Z]{16}" 2>/dev/null | wc -l)
assert_equals "No AWS access keys in code" "0" "$aws_keys"

# GitHub Personal Access Tokens
github_tokens=$(echo "$ALL_FILES" | xargs grep -lE "ghp_[a-zA-Z0-9]{36}" 2>/dev/null | wc -l)
assert_equals "No GitHub PATs in code" "0" "$github_tokens"

# Slack tokens
slack_tokens=$(echo "$ALL_FILES" | xargs grep -lE "xox[baprs]-[0-9a-zA-Z]{10,}" 2>/dev/null | wc -l)
assert_equals "No Slack tokens in code" "0" "$slack_tokens"

# Real API keys (long base64 strings after api_key= or apikey=, excluding templates)
# Only check .sh and scripts, not .md docs or templates
SCRIPT_FILES=$(find "$ROOT_DIR" -type f -not -path "*/.git/*" -not -name "*.template" \
  \( -name "*.sh" -o -name "ghl" \))
real_keys=$(echo "$SCRIPT_FILES" | xargs grep -lE "(api_key|apikey|API_KEY)\s*=\s*['\"][a-zA-Z0-9+/]{32,}" 2>/dev/null | wc -l)
assert_equals "No hardcoded API keys in scripts" "0" "$real_keys"

# ── .gitignore Protection ────────────────────────────────────────
suite_header "Gitignore Protection"

# GHL toolkit gitignore
GHL_GI="$ROOT_DIR/toolkits/ghl-toolkit/.gitignore"
assert_file_exists "GHL toolkit has .gitignore" "$GHL_GI"
assert_grep "GHL .gitignore excludes ghl.env" "ghl\\.env" "$GHL_GI"

# Google Chat toolkit gitignore
GC_GI="$ROOT_DIR/toolkits/google-chat-toolkit/.gitignore"
assert_file_exists "Google Chat toolkit has .gitignore" "$GC_GI"
assert_grep "GC .gitignore excludes credentials" "credentials" "$GC_GI"
assert_grep "GC .gitignore excludes token_cache" "token_cache" "$GC_GI"
assert_grep "GC .gitignore excludes client_secret" "client_secret" "$GC_GI"

# ── Template Files Are Safe ──────────────────────────────────────
suite_header "Credential Templates"

# GHL env template should only have placeholders
GHL_TEMPLATE="$ROOT_DIR/toolkits/ghl-toolkit/secrets/ghl.env.template"
assert_file_exists "GHL env template exists" "$GHL_TEMPLATE"
assert_grep "Template has placeholder API key" "your_api_key_here" "$GHL_TEMPLATE"
assert_grep "Template has placeholder location ID" "your_location_id_here" "$GHL_TEMPLATE"

# Template should NOT have real-looking credentials
TEMPLATE_CONTENT=$(cat "$GHL_TEMPLATE")
assert_not_contains "Template has no real-looking JWT" "$TEMPLATE_CONTENT" "eyJhbGciOi"
assert_not_contains "Template has no real email address" "$TEMPLATE_CONTENT" "@gmail.com"

# ── No Passwords in Code ─────────────────────────────────────────
suite_header "No Hardcoded Passwords"

# Check scripts for hardcoded passwords (password=something without placeholder language)
for script in install.sh status.sh doctor.sh uninstall.sh update.sh \
  toolkits/ghl-toolkit/setup.sh toolkits/ghl-toolkit/test.sh \
  toolkits/ghl-toolkit/scripts/ghl toolkits/google-chat-toolkit/setup.sh \
  toolkits/google-chat-toolkit/test.sh; do
  file="$ROOT_DIR/$script"
  assert_no_grep "$script: no hardcoded password assignments" \
    "password\s*=\s*['\"][^'\"\$][^'\"]{5,}" "$file"
done

# ── Install Log Not Committed ─────────────────────────────────────
suite_header "Ephemeral Files"

assert_equals "No .install.log committed" "0" \
  "$(find "$ROOT_DIR" -name ".install.log" -not -path "*/.git/*" 2>/dev/null | wc -l)"

print_summary
