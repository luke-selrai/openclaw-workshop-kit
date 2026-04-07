#!/bin/bash
# ============================================================================
#  Selr AI Internal Kit — Health Dashboard
#  One command to see everything's status.
#  Usage: bash status.sh
# ============================================================================

# --- Color & Formatting (Git Bash + macOS compatible) ---
setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD_GREEN='\033[1;32m'
    BOLD_CYAN='\033[1;36m'
    BOLD_RED='\033[1;31m'
    BOLD_YELLOW='\033[1;33m'
    BG_GREEN='\033[42m'
    BG_RED='\033[41m'
    BG_YELLOW='\033[43m'
    WHITE='\033[0;37m'
  else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    MAGENTA='' BOLD_GREEN='' BOLD_CYAN='' BOLD_RED='' BOLD_YELLOW=''
    BG_GREEN='' BG_RED='' BG_YELLOW='' WHITE=''
  fi
}

# --- Print Helpers ---
pass()    { printf "  ${GREEN}\xe2\x9c\x93${RESET} %-35s %s\n" "$1" "${DIM}$2${RESET}"; ((PASS_COUNT++)); }
fail()    { printf "  ${RED}\xe2\x9c\x97${RESET} %-35s %s\n" "$1" "${RED}$2${RESET}"; ((FAIL_COUNT++)); }
warn_item() { printf "  ${YELLOW}\xe2\x9a\xa0${RESET} %-35s %s\n" "$1" "${YELLOW}$2${RESET}"; ((WARN_COUNT++)); }
skip_item() { printf "  ${DIM}\xe2\x97\x8b %-35s %s${RESET}\n" "$1" "$2"; }
divider() { printf "  ${DIM}"; printf '%.0s─' $(seq 1 50); printf "${RESET}\n"; }

section() {
  printf "\n"
  printf "  ${BOLD}${CYAN}\xe2\x96\xb6 %s${RESET}\n" "$1"
  divider
}

# --- Platform Detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin*)                PLATFORM_OS="macOS"      ;;
    Linux*)                 PLATFORM_OS="Linux"      ;;
    MINGW*|MSYS*|CYGWIN*)  PLATFORM_OS="Windows"    ;;
    *)                      PLATFORM_OS="Unknown"    ;;
  esac
  if [[ "$PLATFORM_OS" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM_OS="WSL"
  fi
}

# ============================================================================
#  MAIN
# ============================================================================

setup_colors
detect_platform

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# --- Banner ---
printf "\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 50)
printf "\n"
printf "  ${BOLD}${CYAN}  SELR AI INTERNAL KIT — HEALTH DASHBOARD${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 50)
printf "\n"
printf "  ${DIM}%s | %s | %s${RESET}\n" "$(date '+%Y-%m-%d %H:%M')" "$PLATFORM_OS" "v1.1.0"

# ══════════════════════════════════════════════════════════════════
section "ENVIRONMENT"
# ══════════════════════════════════════════════════════════════════

# Node.js
if command -v node > /dev/null 2>&1; then
  pass "Node.js" "$(node --version 2>/dev/null)"
else
  fail "Node.js" "not installed"
fi

# Git
if command -v git > /dev/null 2>&1; then
  pass "Git" "$(git --version 2>/dev/null | sed 's/git version //')"
else
  fail "Git" "not installed"
fi

# Claude Code CLI
if command -v claude > /dev/null 2>&1; then
  pass "Claude Code CLI" "$(claude --version 2>/dev/null | head -1)"
else
  fail "Claude Code CLI" "not installed"
fi

# npm
if command -v npm > /dev/null 2>&1; then
  pass "npm" "$(npm --version 2>/dev/null)"
else
  warn_item "npm" "not found (needed for toolkits)"
fi

# Python 3 (optional)
if command -v python3 > /dev/null 2>&1; then
  pass "Python 3" "$(python3 --version 2>/dev/null | sed 's/Python //')"
elif command -v python > /dev/null 2>&1; then
  ver=$(python --version 2>/dev/null)
  if [[ "$ver" == *"3."* ]]; then
    pass "Python 3" "$(echo "$ver" | sed 's/Python //')"
  else
    skip_item "Python 3" "optional"
  fi
else
  skip_item "Python 3" "optional"
fi

# ~/.claude directory
if [[ -d "$HOME/.claude" ]]; then
  pass "Claude directory (~/.claude)" "exists"
else
  fail "Claude directory (~/.claude)" "missing"
fi

# ══════════════════════════════════════════════════════════════════
section "SKILLS"
# ══════════════════════════════════════════════════════════════════

ALL_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")
SKILL_INSTALLED=0
SKILL_MISSING=0

for skill in "${ALL_SKILLS[@]}"; do
  INSTALLED_PATH="$SKILLS_DIR/$skill/SKILL.md"
  SOURCE_PATH="$SCRIPT_DIR/skills/$skill/SKILL.md"

  if [[ -f "$INSTALLED_PATH" ]]; then
    # Check if it has frontmatter
    first_line=$(head -1 "$INSTALLED_PATH" 2>/dev/null)
    lines=$(wc -l < "$INSTALLED_PATH" 2>/dev/null)
    if [[ "$first_line" == "---" ]]; then
      pass "$skill" "installed (${lines} lines, frontmatter ok)"
    else
      warn_item "$skill" "installed but missing frontmatter"
    fi
    ((SKILL_INSTALLED++))

    # Check sync with source
    if [[ -f "$SOURCE_PATH" ]]; then
      if diff -q "$INSTALLED_PATH" "$SOURCE_PATH" > /dev/null 2>&1; then
        : # in sync, already reported as pass
      else
        warn_item "  $skill sync" "installed version differs from source"
      fi
    fi
  else
    if [[ -f "$SOURCE_PATH" ]]; then
      fail "$skill" "not installed (source available)"
    else
      fail "$skill" "not installed (source missing)"
    fi
    ((SKILL_MISSING++))
  fi
done

printf "\n  ${DIM}Installed: %d/%d${RESET}\n" "$SKILL_INSTALLED" "${#ALL_SKILLS[@]}"

# ══════════════════════════════════════════════════════════════════
section "TOOLKITS"
# ══════════════════════════════════════════════════════════════════

# --- GHL Toolkit ---
printf "  ${BOLD}GHL Toolkit${RESET}\n"

# Check ghl script
GHL_SCRIPT="$HOME/my-assistant/scripts/ghl"
if [[ ! -f "$GHL_SCRIPT" ]]; then
  GHL_SCRIPT="$HOME/.claude/scripts/ghl"
fi
if [[ -f "$GHL_SCRIPT" ]] && [[ -x "$GHL_SCRIPT" ]]; then
  cmds=$(grep -c "^    [a-z]" "$GHL_SCRIPT" 2>/dev/null || echo "?")
  pass "  ghl CLI script" "executable ($cmds commands)"
else
  fail "  ghl CLI script" "not installed or not executable"
fi

# Check GHL credentials
GHL_ENV="$HOME/my-assistant/secrets/ghl.env"
if [[ ! -f "$GHL_ENV" ]]; then
  GHL_ENV="$HOME/.claude/secrets/ghl.env"
fi
if [[ -f "$GHL_ENV" ]]; then
  # Check if still placeholder
  if grep -q "your_api_key_here" "$GHL_ENV" 2>/dev/null; then
    warn_item "  GHL credentials" "template present but not configured"
  else
    pass "  GHL credentials" "configured"
    # Try a connectivity check if credentials exist
    source "$GHL_ENV" 2>/dev/null
    if [[ -n "${GHL_API_KEY:-}" ]] && [[ -n "${GHL_LOCATION_ID:-}" ]]; then
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $GHL_API_KEY" \
        -H "Version: 2021-07-28" \
        "https://services.leadconnectorhq.com/contacts/?locationId=$GHL_LOCATION_ID&limit=1" 2>/dev/null || echo "000")
      case "$HTTP_CODE" in
        200) pass "  GHL API connection" "live (HTTP $HTTP_CODE)" ;;
        401) fail "  GHL API connection" "unauthorized (HTTP 401 — check API key)" ;;
        422) warn_item "  GHL API connection" "bad request (HTTP 422 — check location ID)" ;;
        000) fail "  GHL API connection" "network error (check internet)" ;;
        *)   warn_item "  GHL API connection" "unexpected (HTTP $HTTP_CODE)" ;;
      esac
    fi
  fi
else
  fail "  GHL credentials" "not found"
fi

# Check GHL skills bundled
for ghl_skill in "ghl-crm" "ghl-browser"; do
  if [[ -f "$SKILLS_DIR/$ghl_skill/SKILL.md" ]]; then
    pass "  $ghl_skill skill" "installed"
  else
    fail "  $ghl_skill skill" "not installed"
  fi
done

printf "\n"

# --- Google Chat Toolkit ---
printf "  ${BOLD}Google Chat Toolkit${RESET}\n"

# Check gws CLI
if command -v gws > /dev/null 2>&1; then
  pass "  gws CLI" "installed ($(gws --version 2>/dev/null | head -1 || echo 'unknown version'))"
else
  fail "  gws CLI" "not installed"
fi

# Check GCP credentials
GWS_CREDS_DIR="$HOME/.config/gws"
if [[ -d "$GWS_CREDS_DIR" ]]; then
  cred_files=$(find "$GWS_CREDS_DIR" -name "credentials*.json" 2>/dev/null | wc -l)
  if [[ "$cred_files" -gt 0 ]]; then
    pass "  GCP credentials" "$cred_files credential file(s)"
    # Try a live check
    if command -v gws > /dev/null 2>&1; then
      if gws chat spaces list --limit 1 > /dev/null 2>&1; then
        pass "  Google Chat API" "live connection"
      else
        warn_item "  Google Chat API" "credentials found but API call failed"
      fi
    fi
  else
    warn_item "  GCP credentials" "directory exists but no credential files"
  fi
else
  fail "  GCP credentials" "not configured (~/.config/gws/ missing)"
fi

# Check Google Chat skill
if [[ -f "$SKILLS_DIR/google-chat/SKILL.md" ]]; then
  pass "  google-chat skill" "installed"
else
  fail "  google-chat skill" "not installed"
fi

# ══════════════════════════════════════════════════════════════════
section "AGENTS"
# ══════════════════════════════════════════════════════════════════

if [[ -d "$AGENTS_DIR" ]]; then
  agent_count=0
  for agent_file in "$AGENTS_DIR"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_name="$(basename "$agent_file" .md)"
    lines=$(wc -l < "$agent_file" 2>/dev/null)
    first_line=$(head -1 "$agent_file" 2>/dev/null)
    if [[ "$first_line" == "---" ]]; then
      pass "$agent_name" "installed (${lines} lines, frontmatter ok)"
    else
      pass "$agent_name" "installed (${lines} lines)"
    fi
    ((agent_count++))
  done
  if [[ $agent_count -eq 0 ]]; then
    fail "No agents" "~/.claude/agents/ is empty"
  fi
else
  fail "Agents directory" "~/.claude/agents/ not found"
fi

# ══════════════════════════════════════════════════════════════════
section "SOURCE KIT INTEGRITY"
# ══════════════════════════════════════════════════════════════════

# Check source kit is intact
if [[ -f "$SCRIPT_DIR/install.sh" ]]; then
  pass "Master installer" "present"
else
  fail "Master installer" "install.sh missing"
fi

# Check all source skills exist
SRC_SKILL_COUNT=0
for skill in "${ALL_SKILLS[@]}"; do
  if [[ -f "$SCRIPT_DIR/skills/$skill/SKILL.md" ]]; then
    ((SRC_SKILL_COUNT++))
  fi
done
if [[ $SRC_SKILL_COUNT -eq ${#ALL_SKILLS[@]} ]]; then
  pass "Source skills" "all $SRC_SKILL_COUNT present"
else
  warn_item "Source skills" "$SRC_SKILL_COUNT/${#ALL_SKILLS[@]} present"
fi

# Check toolkits source
for toolkit in "ghl-toolkit" "google-chat-toolkit"; do
  if [[ -f "$SCRIPT_DIR/toolkits/$toolkit/setup.sh" ]]; then
    pass "Source: $toolkit" "setup.sh present"
  else
    fail "Source: $toolkit" "setup.sh missing"
  fi
done

# Check docs
for doc in "README.md" "docs/INTEGRATION.md" "docs/CHANGELOG.md"; do
  if [[ -f "$SCRIPT_DIR/$doc" ]]; then
    lines=$(wc -l < "$SCRIPT_DIR/$doc" 2>/dev/null)
    pass "$(basename "$doc")" "$lines lines"
  else
    warn_item "$(basename "$doc")" "missing"
  fi
done

# Bundled skill sync check
printf "\n  ${DIM}Bundled skill sync:${RESET}\n"
SYNC_OK=true
for pair in "ghl-toolkit:ghl-crm" "ghl-toolkit:ghl-browser" "google-chat-toolkit:google-chat"; do
  toolkit="${pair%%:*}"
  skill="${pair##*:}"
  bundled="$SCRIPT_DIR/toolkits/$toolkit/skills/$skill/SKILL.md"
  canonical="$SCRIPT_DIR/skills/$skill/SKILL.md"
  if [[ -f "$bundled" ]] && [[ -f "$canonical" ]]; then
    if diff -q "$bundled" "$canonical" > /dev/null 2>&1; then
      pass "  $toolkit/$skill" "in sync"
    else
      warn_item "  $toolkit/$skill" "OUT OF SYNC with skills/$skill"
      SYNC_OK=false
    fi
  fi
done

# ══════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════

printf "\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 50)
printf "\n"
printf "  ${BOLD}${CYAN}  SUMMARY${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 50)
printf "\n\n"

# Status badge
TOTAL=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))
if [[ $FAIL_COUNT -eq 0 ]] && [[ $WARN_COUNT -eq 0 ]]; then
  printf "  ${BG_GREEN}${WHITE}${BOLD} ALL SYSTEMS GO ${RESET}\n\n"
elif [[ $FAIL_COUNT -eq 0 ]]; then
  printf "  ${BG_YELLOW}${WHITE}${BOLD} MOSTLY READY ${RESET}  ${DIM}(some warnings)${RESET}\n\n"
else
  printf "  ${BG_RED}${WHITE}${BOLD} NEEDS ATTENTION ${RESET}  ${DIM}(failures detected)${RESET}\n\n"
fi

printf "  ${GREEN}\xe2\x9c\x93 Passed:${RESET}   ${BOLD}%d${RESET}\n" "$PASS_COUNT"
if [[ $WARN_COUNT -gt 0 ]]; then
  printf "  ${YELLOW}\xe2\x9a\xa0 Warnings:${RESET} ${BOLD}%d${RESET}\n" "$WARN_COUNT"
fi
if [[ $FAIL_COUNT -gt 0 ]]; then
  printf "  ${RED}\xe2\x9c\x97 Failed:${RESET}   ${BOLD}%d${RESET}\n" "$FAIL_COUNT"
fi
printf "  ${DIM}Total:    %d checks${RESET}\n" "$TOTAL"

printf "\n"
if [[ $FAIL_COUNT -gt 0 ]]; then
  printf "  ${DIM}Fix failures with: ${RESET}${BOLD}bash install.sh${RESET}\n"
fi
printf "  ${DIM}Full docs: docs/INTEGRATION.md${RESET}\n"
printf "\n"

# Exit with appropriate code
[[ $FAIL_COUNT -eq 0 ]] && exit 0 || exit 1
