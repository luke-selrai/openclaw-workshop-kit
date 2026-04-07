#!/bin/bash
# ============================================================================
#  Selr AI Internal Kit — Doctor
#  Diagnoses problems AND offers to fix them.
#  Usage: bash doctor.sh
# ============================================================================

# --- Color & Formatting ---
setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
    BOLD_GREEN='\033[1;32m'; BOLD_RED='\033[1;31m'; BOLD_YELLOW='\033[1;33m'
    BG_GREEN='\033[42m'; BG_RED='\033[41m'; BG_YELLOW='\033[43m'; WHITE='\033[0;37m'
  else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    MAGENTA='' BOLD_GREEN='' BOLD_RED='' BOLD_YELLOW=''
    BG_GREEN='' BG_RED='' BG_YELLOW='' WHITE=''
  fi
}

# --- Print Helpers ---
pass()    { printf "  ${GREEN}\xe2\x9c\x93${RESET} %s\n" "$*"; }
fail()    { printf "  ${RED}\xe2\x9c\x97${RESET} %s\n" "$*"; }
warn_msg() { printf "  ${YELLOW}\xe2\x9a\xa0${RESET} %s\n" "$*"; }
fix_msg() { printf "    ${CYAN}\xe2\x86\x92 Fix:${RESET} %s\n" "$*"; }
divider() { printf "  ${DIM}"; printf '%.0s─' $(seq 1 48); printf "${RESET}\n"; }

section() {
  printf "\n  ${BOLD}${CYAN}\xe2\x96\xb6 %s${RESET}\n" "$1"
  divider
}

prompt_fix() {
  local message="$1"
  if [[ "${AUTO_FIX:-}" == "true" ]]; then
    return 0
  fi
  printf "\n    ${YELLOW}?${RESET} %s ${DIM}[${BOLD}Y${RESET}${DIM}/n]${RESET} " "$message"
  read -r answer
  case "${answer:-y}" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

run_fix() {
  local description="$1"
  shift
  printf "    ${CYAN}\xe2\x96\xb6${RESET} %s..." "$description"
  if "$@" > /dev/null 2>&1; then
    printf " ${GREEN}done${RESET}\n"
    ((FIXES++))
    return 0
  else
    printf " ${RED}failed${RESET}\n"
    return 1
  fi
}

# ============================================================================
#  MAIN
# ============================================================================

setup_colors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"

ISSUES=0
FIXES=0
WARNINGS=0

# Parse flags
AUTO_FIX="false"
for arg in "$@"; do
  case "$arg" in
    --auto-fix|-y) AUTO_FIX="true" ;;
    --help|-h)
      echo "Usage: bash doctor.sh [--auto-fix|-y]"
      echo ""
      echo "Diagnoses issues and offers to fix them interactively."
      echo "Use --auto-fix to automatically apply all safe fixes."
      exit 0
      ;;
  esac
done

# Banner
printf "\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 48)
printf "\n"
printf "  ${BOLD}${CYAN}  SELR AI INTERNAL KIT — DOCTOR${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 48)
printf "\n"
printf "  ${DIM}Diagnosing your environment...${RESET}\n"
if [[ "$AUTO_FIX" == "true" ]]; then
  printf "  ${YELLOW}Auto-fix mode enabled${RESET}\n"
fi

# ══════════════════════════════════════════════════════════════════
section "NODE.JS"
# ══════════════════════════════════════════════════════════════════

if command -v node > /dev/null 2>&1; then
  NODE_VER=$(node --version 2>/dev/null)
  NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
  if [[ "$NODE_MAJOR" -ge 18 ]]; then
    pass "Node.js $NODE_VER (meets v18+ requirement)"
  else
    fail "Node.js $NODE_VER is too old (need v18+)"
    fix_msg "Install Node.js LTS from https://nodejs.org/"
    ((ISSUES++))
  fi
else
  fail "Node.js is not installed"
  fix_msg "Install from https://nodejs.org/ or run: brew install node"
  ((ISSUES++))

  case "$(uname -s)" in
    Darwin*)
      if command -v brew > /dev/null 2>&1; then
        if prompt_fix "Install Node.js via Homebrew?"; then
          run_fix "Installing Node.js" brew install node
        fi
      fi
      ;;
  esac
fi

# ══════════════════════════════════════════════════════════════════
section "GIT"
# ══════════════════════════════════════════════════════════════════

if command -v git > /dev/null 2>&1; then
  pass "Git $(git --version 2>/dev/null | sed 's/git version //')"
else
  fail "Git is not installed"
  fix_msg "Install from https://git-scm.com/"
  ((ISSUES++))
fi

# ══════════════════════════════════════════════════════════════════
section "CLAUDE CODE"
# ══════════════════════════════════════════════════════════════════

if command -v claude > /dev/null 2>&1; then
  CLAUDE_VER=$(claude --version 2>/dev/null | head -1)
  pass "Claude Code CLI ($CLAUDE_VER)"
else
  fail "Claude Code CLI is not installed"
  fix_msg "npm install -g @anthropic-ai/claude-code"
  ((ISSUES++))

  if command -v npm > /dev/null 2>&1; then
    if prompt_fix "Install Claude Code CLI via npm?"; then
      run_fix "Installing Claude Code" npm install -g @anthropic-ai/claude-code
    fi
  fi
fi

# Check ~/.claude directory
if [[ -d "$HOME/.claude" ]]; then
  pass "Claude directory (~/.claude/) exists"
else
  fail "Claude directory (~/.claude/) missing"
  fix_msg "Run 'claude' once to create it, or: mkdir -p ~/.claude"
  ((ISSUES++))

  if prompt_fix "Create ~/.claude/ directory?"; then
    run_fix "Creating ~/.claude/" mkdir -p "$HOME/.claude"
    run_fix "Creating ~/.claude/skills/" mkdir -p "$HOME/.claude/skills"
  fi
fi

# ══════════════════════════════════════════════════════════════════
section "SKILLS"
# ══════════════════════════════════════════════════════════════════

ALL_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")
MISSING_SKILLS=()

for skill in "${ALL_SKILLS[@]}"; do
  if [[ -f "$SKILLS_DIR/$skill/SKILL.md" ]]; then
    # Check frontmatter
    first_line=$(head -1 "$SKILLS_DIR/$skill/SKILL.md" 2>/dev/null)
    if [[ "$first_line" == "---" ]]; then
      pass "$skill — installed, frontmatter OK"
    else
      warn_msg "$skill — installed but missing YAML frontmatter"
      ((WARNINGS++))
      if [[ -f "$SCRIPT_DIR/skills/$skill/SKILL.md" ]]; then
        fix_msg "Source version has frontmatter. Re-install to fix."
        if prompt_fix "Re-install $skill from source?"; then
          run_fix "Re-installing $skill" cp -r "$SCRIPT_DIR/skills/$skill" "$SKILLS_DIR/"
        fi
      fi
    fi

    # Check if outdated vs source
    if [[ -f "$SCRIPT_DIR/skills/$skill/SKILL.md" ]]; then
      if ! diff -q "$SKILLS_DIR/$skill/SKILL.md" "$SCRIPT_DIR/skills/$skill/SKILL.md" > /dev/null 2>&1; then
        warn_msg "  $skill — installed version differs from source"
        ((WARNINGS++))
        if prompt_fix "Update $skill to latest source version?"; then
          run_fix "Updating $skill" cp -r "$SCRIPT_DIR/skills/$skill" "$SKILLS_DIR/"
        fi
      fi
    fi
  else
    fail "$skill — not installed"
    MISSING_SKILLS+=("$skill")
    ((ISSUES++))
  fi
done

if [[ ${#MISSING_SKILLS[@]} -gt 0 ]]; then
  fix_msg "Install missing skills with: bash install.sh"
  if prompt_fix "Install all ${#MISSING_SKILLS[@]} missing skill(s) now?"; then
    mkdir -p "$SKILLS_DIR"
    for skill in "${MISSING_SKILLS[@]}"; do
      if [[ -d "$SCRIPT_DIR/skills/$skill" ]]; then
        run_fix "Installing $skill" cp -r "$SCRIPT_DIR/skills/$skill" "$SKILLS_DIR/"
      fi
    done
  fi
fi

# ══════════════════════════════════════════════════════════════════
section "AGENTS"
# ══════════════════════════════════════════════════════════════════

if [[ -d "$AGENTS_DIR" ]]; then
  if [[ -f "$AGENTS_DIR/server-setup.md" ]]; then
    pass "server-setup agent installed"
  else
    fail "server-setup agent missing from ~/.claude/agents/"
    ((ISSUES++))
    if [[ -f "$SCRIPT_DIR/agents/server-setup.md" ]]; then
      if prompt_fix "Install server-setup agent?"; then
        run_fix "Installing agent" cp "$SCRIPT_DIR/agents/server-setup.md" "$AGENTS_DIR/"
      fi
    fi
  fi
else
  fail "Agents directory (~/.claude/agents/) missing"
  ((ISSUES++))
  if prompt_fix "Create agents directory and install agents?"; then
    run_fix "Creating agents directory" mkdir -p "$AGENTS_DIR"
    if [[ -f "$SCRIPT_DIR/agents/server-setup.md" ]]; then
      run_fix "Installing server-setup agent" cp "$SCRIPT_DIR/agents/server-setup.md" "$AGENTS_DIR/"
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════
section "GHL TOOLKIT"
# ══════════════════════════════════════════════════════════════════

# Check ghl script
GHL_SCRIPT=""
for path in "$HOME/my-assistant/scripts/ghl" "$HOME/.claude/scripts/ghl"; do
  if [[ -f "$path" ]]; then GHL_SCRIPT="$path"; break; fi
done

if [[ -n "$GHL_SCRIPT" ]]; then
  if [[ -x "$GHL_SCRIPT" ]]; then
    pass "ghl CLI installed and executable"
  else
    fail "ghl CLI found but not executable"
    fix_msg "chmod +x $GHL_SCRIPT"
    ((ISSUES++))
    if prompt_fix "Make ghl script executable?"; then
      run_fix "Setting executable bit" chmod +x "$GHL_SCRIPT"
    fi
  fi
else
  warn_msg "ghl CLI not installed (run GHL toolkit setup if needed)"
  ((WARNINGS++))
  fix_msg "bash toolkits/ghl-toolkit/setup.sh"
fi

# Check GHL credentials
GHL_ENV=""
for path in "$HOME/my-assistant/secrets/ghl.env" "$HOME/.claude/secrets/ghl.env"; do
  if [[ -f "$path" ]]; then GHL_ENV="$path"; break; fi
done

if [[ -n "$GHL_ENV" ]]; then
  if grep -q "your_api_key_here" "$GHL_ENV" 2>/dev/null; then
    warn_msg "GHL credentials file exists but still has placeholder values"
    fix_msg "Edit $GHL_ENV with your real GHL API key and location ID"
    ((WARNINGS++))
  else
    pass "GHL credentials configured"

    # Live API test
    source "$GHL_ENV" 2>/dev/null
    if [[ -n "${GHL_API_KEY:-}" ]] && [[ -n "${GHL_LOCATION_ID:-}" ]]; then
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        -H "Authorization: Bearer $GHL_API_KEY" \
        -H "Version: 2021-07-28" \
        "https://services.leadconnectorhq.com/contacts/?locationId=$GHL_LOCATION_ID&limit=1" 2>/dev/null || echo "000")
      case "$HTTP_CODE" in
        200) pass "GHL API connection live (HTTP 200)" ;;
        401)
          fail "GHL API returned 401 Unauthorized"
          fix_msg "Check your GHL_API_KEY in $GHL_ENV"
          ((ISSUES++))
          ;;
        422)
          fail "GHL API returned 422 — bad Location ID"
          fix_msg "Check your GHL_LOCATION_ID in $GHL_ENV"
          ((ISSUES++))
          ;;
        000)
          warn_msg "Could not reach GHL API (network issue or timeout)"
          fix_msg "Check your internet connection"
          ((WARNINGS++))
          ;;
        *)
          warn_msg "GHL API returned unexpected HTTP $HTTP_CODE"
          ((WARNINGS++))
          ;;
      esac
    fi
  fi
else
  warn_msg "GHL credentials not configured (optional)"
  ((WARNINGS++))
fi

# ══════════════════════════════════════════════════════════════════
section "GOOGLE CHAT TOOLKIT"
# ══════════════════════════════════════════════════════════════════

if command -v gws > /dev/null 2>&1; then
  pass "gws CLI installed"

  # Check credentials
  if [[ -d "$HOME/.config/gws" ]]; then
    cred_count=$(find "$HOME/.config/gws" -name "credentials*.json" 2>/dev/null | wc -l)
    if [[ "$cred_count" -gt 0 ]]; then
      pass "GCP credentials found ($cred_count file(s))"
    else
      warn_msg "GCP directory exists but no credentials"
      fix_msg "Run: gws auth login --scopes chat,gmail,calendar,drive"
      ((WARNINGS++))
    fi
  else
    warn_msg "GCP credentials not configured (~/.config/gws/ missing)"
    fix_msg "Run: gws auth login --scopes chat,gmail,calendar,drive"
    ((WARNINGS++))
  fi
else
  warn_msg "gws CLI not installed (optional — needed for Google Chat)"
  fix_msg "npm install -g @googleworkspace/cli"
  ((WARNINGS++))

  if command -v npm > /dev/null 2>&1; then
    if prompt_fix "Install gws CLI via npm?"; then
      run_fix "Installing gws CLI" npm install -g @googleworkspace/cli
    fi
  fi
fi

# ══════════════════════════════════════════════════════════════════
section "SOURCE KIT INTEGRITY"
# ══════════════════════════════════════════════════════════════════

# Verify essential source files
SRC_OK=true
for file in install.sh status.sh doctor.sh README.md; do
  if [[ -f "$SCRIPT_DIR/$file" ]]; then
    pass "Source: $file present"
  else
    fail "Source: $file missing"
    SRC_OK=false
    ((ISSUES++))
  fi
done

# Check tests exist
if [[ -f "$SCRIPT_DIR/tests/run-all.sh" ]]; then
  pass "Test suite present"
else
  warn_msg "Test suite not found"
  ((WARNINGS++))
fi

# ══════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════

printf "\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 48)
printf "\n"
printf "  ${BOLD}${CYAN}  DIAGNOSIS COMPLETE${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 48)
printf "\n\n"

if [[ $ISSUES -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
  printf "  ${BG_GREEN}${WHITE}${BOLD} NO ISSUES FOUND ${RESET}\n\n"
  printf "  ${GREEN}Your environment is healthy. Everything is working.${RESET}\n"
elif [[ $ISSUES -eq 0 ]]; then
  printf "  ${BG_YELLOW}${WHITE}${BOLD} %d WARNING(S) ${RESET}\n\n" "$WARNINGS"
  printf "  ${YELLOW}No critical issues. Warnings are optional items.${RESET}\n"
else
  printf "  ${BG_RED}${WHITE}${BOLD} %d ISSUE(S) FOUND ${RESET}\n\n" "$ISSUES"
  if [[ $WARNINGS -gt 0 ]]; then
    printf "  ${YELLOW}Plus %d warning(s).${RESET}\n" "$WARNINGS"
  fi
fi

if [[ $FIXES -gt 0 ]]; then
  printf "\n  ${GREEN}\xe2\x9c\x93 %d fix(es) applied this session.${RESET}\n" "$FIXES"
  printf "  ${DIM}Run doctor again to verify: bash doctor.sh${RESET}\n"
fi

printf "\n"
if [[ $ISSUES -gt 0 ]]; then
  printf "  ${DIM}Quick fix: bash doctor.sh --auto-fix${RESET}\n"
  printf "  ${DIM}Full install: bash install.sh${RESET}\n"
fi
printf "  ${DIM}Health dashboard: bash status.sh${RESET}\n"
printf "  ${DIM}Run tests: bash tests/run-all.sh${RESET}\n"
printf "\n"

[[ $ISSUES -eq 0 ]] && exit 0 || exit 1
