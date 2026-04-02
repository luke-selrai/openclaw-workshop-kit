#!/bin/bash
# ============================================================================
#  TOOLKIT TESTS — Shell syntax, logic validation, dry-run behavior
# ============================================================================
SUITE_NAME="Toolkit Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

# ── Shell Syntax Validation ──────────────────────────────────────
suite_header "Shell Syntax (bash -n)"

ALL_SCRIPTS=(
  "install.sh"
  "status.sh"
  "doctor.sh"
  "uninstall.sh"
  "update.sh"
  "toolkits/ghl-toolkit/setup.sh"
  "toolkits/ghl-toolkit/test.sh"
  "toolkits/ghl-toolkit/scripts/ghl"
  "toolkits/google-chat-toolkit/setup.sh"
  "toolkits/google-chat-toolkit/test.sh"
)

for script in "${ALL_SCRIPTS[@]}"; do
  assert_syntax_ok "$script syntax valid" "$ROOT_DIR/$script"
done

# ── install.sh Validation ────────────────────────────────────────
suite_header "Master Installer (install.sh)"

INSTALL="$ROOT_DIR/install.sh"
INSTALL_CONTENT=$(cat "$INSTALL")

assert_grep "install.sh has set -e" "^set -e" "$INSTALL"
assert_grep "install.sh has shebang" "^#!/bin/bash" "$INSTALL"
assert_contains "install.sh detects macOS" "$INSTALL_CONTENT" "Darwin"
assert_contains "install.sh detects Windows" "$INSTALL_CONTENT" "MINGW"
assert_contains "install.sh detects Linux" "$INSTALL_CONTENT" "Linux"
assert_contains "install.sh detects WSL" "$INSTALL_CONTENT" "microsoft"
assert_contains "install.sh checks Node.js" "$INSTALL_CONTENT" "node"
assert_contains "install.sh checks Git" "$INSTALL_CONTENT" "git"
assert_contains "install.sh checks Claude" "$INSTALL_CONTENT" "claude"
assert_contains "install.sh has progress bar" "$INSTALL_CONTENT" "progress_bar"
assert_contains "install.sh creates install log" "$INSTALL_CONTENT" "INSTALL_LOG"
assert_contains "install.sh references skills dir" "$INSTALL_CONTENT" "SKILLS_DIR"
assert_contains "install.sh handles NO_COLOR" "$INSTALL_CONTENT" "NO_COLOR"
assert_grep "install.sh copies agents" "agents" "$INSTALL"

# ── status.sh Validation ─────────────────────────────────────────
suite_header "Health Dashboard (status.sh)"

STATUS="$ROOT_DIR/status.sh"
STATUS_CONTENT=$(cat "$STATUS")

assert_grep "status.sh has shebang" "^#!/bin/bash" "$STATUS"
assert_contains "status.sh checks Node.js" "$STATUS_CONTENT" "node"
assert_contains "status.sh checks Git" "$STATUS_CONTENT" "git"
assert_contains "status.sh checks Claude CLI" "$STATUS_CONTENT" "claude"
assert_contains "status.sh checks npm" "$STATUS_CONTENT" "npm"
assert_contains "status.sh checks skills" "$STATUS_CONTENT" "SKILLS"
assert_contains "status.sh checks toolkits" "$STATUS_CONTENT" "TOOLKITS"
assert_contains "status.sh checks agents" "$STATUS_CONTENT" "AGENTS"
assert_contains "status.sh has summary section" "$STATUS_CONTENT" "SUMMARY"
assert_contains "status.sh has ALL SYSTEMS GO" "$STATUS_CONTENT" "ALL SYSTEMS GO"
assert_contains "status.sh has NEEDS ATTENTION" "$STATUS_CONTENT" "NEEDS ATTENTION"
assert_contains "status.sh checks GHL API connectivity" "$STATUS_CONTENT" "HTTP"
assert_contains "status.sh checks bundled skill sync" "$STATUS_CONTENT" "diff"
assert_contains "status.sh checks frontmatter" "$STATUS_CONTENT" "frontmatter"
assert_contains "status.sh exits with correct code" "$STATUS_CONTENT" "exit 1"

# ── doctor.sh Validation ──────────────────────────────────────────
suite_header "Doctor (doctor.sh)"

DOCTOR="$ROOT_DIR/doctor.sh"
DOCTOR_CONTENT=$(cat "$DOCTOR")

assert_grep "doctor.sh has shebang" "^#!/bin/bash" "$DOCTOR"
assert_contains "doctor.sh checks Node.js" "$DOCTOR_CONTENT" "node"
assert_contains "doctor.sh checks Git" "$DOCTOR_CONTENT" "git"
assert_contains "doctor.sh checks Claude" "$DOCTOR_CONTENT" "claude"
assert_contains "doctor.sh has auto-fix flag" "$DOCTOR_CONTENT" "auto-fix"
assert_contains "doctor.sh has NO ISSUES FOUND badge" "$DOCTOR_CONTENT" "NO ISSUES FOUND"
assert_contains "doctor.sh offers interactive repair" "$DOCTOR_CONTENT" "prompt_fix"
assert_contains "doctor.sh checks GHL API" "$DOCTOR_CONTENT" "HTTP"
assert_contains "doctor.sh checks gws CLI" "$DOCTOR_CONTENT" "gws"
assert_contains "doctor.sh tracks fixes applied" "$DOCTOR_CONTENT" "FIXES"

# ── uninstall.sh Validation ───────────────────────────────────────
suite_header "Uninstaller (uninstall.sh)"

UNINSTALL="$ROOT_DIR/uninstall.sh"
UNINSTALL_CONTENT=$(cat "$UNINSTALL")

assert_grep "uninstall.sh has shebang" "^#!/bin/bash" "$UNINSTALL"
assert_contains "uninstall.sh has --dry-run flag" "$UNINSTALL_CONTENT" "dry-run"
assert_contains "uninstall.sh has --yes flag" "$UNINSTALL_CONTENT" "AUTO_YES"
assert_contains "uninstall.sh has --keep-credentials" "$UNINSTALL_CONTENT" "keep-credentials"
assert_contains "uninstall.sh lists kit skills" "$UNINSTALL_CONTENT" "KIT_SKILLS"
assert_contains "uninstall.sh has confirmation prompt" "$UNINSTALL_CONTENT" "This cannot be undone"
assert_contains "uninstall.sh cleans empty dirs" "$UNINSTALL_CONTENT" "rmdir"
assert_contains "uninstall.sh preserves source kit" "$UNINSTALL_CONTENT" "untouched"

# ── update.sh Validation ──────────────────────────────────────────
suite_header "Updater (update.sh)"

UPDATE="$ROOT_DIR/update.sh"
UPDATE_CONTENT=$(cat "$UPDATE")

assert_grep "update.sh has shebang" "^#!/bin/bash" "$UPDATE"
assert_contains "update.sh has --check flag" "$UPDATE_CONTENT" "CHECK_ONLY"
assert_contains "update.sh has --force flag" "$UPDATE_CONTENT" "FORCE"
assert_contains "update.sh does git fetch" "$UPDATE_CONTENT" "git fetch"
assert_contains "update.sh compares installed vs source" "$UPDATE_CONTENT" "diff"
assert_contains "update.sh tracks updated count" "$UPDATE_CONTENT" "UPDATED"
assert_contains "update.sh tracks new installs" "$UPDATE_CONTENT" "INSTALLED_NEW"
assert_contains "update.sh has UP TO DATE badge" "$UPDATE_CONTENT" "EVERYTHING UP TO DATE"

# ── GHL Toolkit ───────────────────────────────────────────────────
suite_header "GHL Toolkit"

GHL_DIR="$ROOT_DIR/toolkits/ghl-toolkit"

# setup.sh checks
GHL_SETUP=$(cat "$GHL_DIR/setup.sh")
assert_grep "ghl setup.sh has set -e" "^set -e" "$GHL_DIR/setup.sh"
assert_contains "ghl setup.sh checks ~/.claude" "$GHL_SETUP" ".claude"
assert_contains "ghl setup.sh copies skills" "$GHL_SETUP" "skills"

# test.sh checks
GHL_TEST=$(cat "$GHL_DIR/test.sh")
assert_contains "ghl test.sh tracks pass/fail" "$GHL_TEST" "PASS"
assert_contains "ghl test.sh checks API" "$GHL_TEST" "curl"
assert_contains "ghl test.sh handles 401" "$GHL_TEST" "401"
assert_contains "ghl test.sh handles 200" "$GHL_TEST" "200"

# scripts/ghl checks
GHL_CLI=$(cat "$GHL_DIR/scripts/ghl")
GHL_LINES=$(wc -l < "$GHL_DIR/scripts/ghl")
assert_greater_than "ghl CLI has 300+ lines" "$GHL_LINES" 299
assert_contains "ghl CLI has usage instructions" "$GHL_CLI" "Usage"
assert_contains "ghl CLI uses Bearer auth" "$GHL_CLI" "Bearer"
assert_contains "ghl CLI has contacts CRUD" "$GHL_CLI" "get-contact"
assert_contains "ghl CLI has opportunities" "$GHL_CLI" "opportunities"
assert_contains "ghl CLI has send-sms" "$GHL_CLI" "send-sms"
assert_contains "ghl CLI has send-email" "$GHL_CLI" "send-email"
assert_contains "ghl CLI has calendars" "$GHL_CLI" "calendars"

# env template
ENV_TEMPLATE=$(cat "$GHL_DIR/secrets/ghl.env.template")
assert_contains "env template has GHL_API_KEY" "$ENV_TEMPLATE" "GHL_API_KEY"
assert_contains "env template has GHL_LOCATION_ID" "$ENV_TEMPLATE" "GHL_LOCATION_ID"
assert_contains "env template has GHL_LOGIN_EMAIL" "$ENV_TEMPLATE" "GHL_LOGIN_EMAIL"
assert_contains "env template has GHL_LOGIN_PASSWORD" "$ENV_TEMPLATE" "GHL_LOGIN_PASSWORD"
assert_contains "env template has placeholder values" "$ENV_TEMPLATE" "your_api_key_here"

# ── Google Chat Toolkit ───────────────────────────────────────────
suite_header "Google Chat Toolkit"

GC_DIR="$ROOT_DIR/toolkits/google-chat-toolkit"

# setup.sh checks
GC_SETUP=$(cat "$GC_DIR/setup.sh")
assert_grep "gc setup.sh has set -e" "^set -e" "$GC_DIR/setup.sh"
assert_contains "gc setup.sh installs gws" "$GC_SETUP" "gws"
assert_contains "gc setup.sh copies skill" "$GC_SETUP" "google-chat"
assert_contains "gc setup.sh has OAuth guidance" "$GC_SETUP" "auth"

# test.sh checks
GC_TEST=$(cat "$GC_DIR/test.sh")
assert_contains "gc test.sh tracks pass/fail" "$GC_TEST" "PASS"
assert_contains "gc test.sh checks gws" "$GC_TEST" "gws"
assert_contains "gc test.sh checks credentials" "$GC_TEST" "credentials"

# .gitignore
GC_GITIGNORE=$(cat "$GC_DIR/.gitignore")
assert_contains "gc .gitignore excludes credentials" "$GC_GITIGNORE" "credentials"
assert_contains "gc .gitignore excludes token_cache" "$GC_GITIGNORE" "token_cache"
assert_contains "gc .gitignore excludes client_secret" "$GC_GITIGNORE" "client_secret"

print_summary
