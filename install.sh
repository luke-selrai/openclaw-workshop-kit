#!/bin/bash
# ============================================================================
#  Selr AI Internal Kit — Master Installer
#  One command to set up everything.
#  Usage: bash install.sh
# ============================================================================
set -e

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
  else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW=''
    BLUE='' CYAN='' MAGENTA='' BOLD_GREEN='' BOLD_CYAN=''
    BOLD_RED='' BOLD_YELLOW=''
  fi
}

# --- Print Helpers ---
info()    { printf "${BLUE}${BOLD}==>${RESET}${BOLD} %s${RESET}\n" "$*"; }
success() { printf "${GREEN}${BOLD}==>${RESET}${BOLD} %s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}${BOLD}  Warning:${RESET} %s\n" "$*"; }
error()   { printf "${RED}${BOLD}  Error:${RESET} %s\n" "$*" >&2; }
pass()    { printf "  ${GREEN}\xe2\x9c\x93${RESET} %s\n" "$*"; }
fail()    { printf "  ${RED}\xe2\x9c\x97${RESET} %s\n" "$*"; }
skip()    { printf "  ${YELLOW}\xe2\x97\x8b${RESET} ${DIM}%s${RESET}\n" "$*"; }

# --- Step Counter ---
STEP_CURRENT=0
STEP_TOTAL=6
step() {
  ((STEP_CURRENT++))
  printf "\n${BOLD}${CYAN}[%d/%d]${RESET} ${BOLD}%s${RESET}\n" \
    "$STEP_CURRENT" "$STEP_TOTAL" "$*"
  printf "${DIM}%.0s─${RESET}" $(seq 1 50)
  printf "\n"
}

# --- Platform Detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin*)                PLATFORM_OS="macos"   ;;
    Linux*)                 PLATFORM_OS="linux"   ;;
    MINGW*|MSYS*|CYGWIN*)  PLATFORM_OS="windows" ;;
    *)                      PLATFORM_OS="unknown" ;;
  esac

  if [[ "$PLATFORM_OS" == "linux" ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM_OS="wsl"
  fi
}

# --- Prompt ---
prompt_yes_no() {
  local message="$1" default="${2:-y}"
  local prompt_hint
  if [[ "$default" == "y" ]]; then
    prompt_hint="${BOLD}Y${RESET}/n"
  else
    prompt_hint="y/${BOLD}N${RESET}"
  fi
  printf "\n  ${YELLOW}?${RESET} %s [%b] " "$message" "$prompt_hint"
  read -r answer
  case "${answer:-$default}" in
    [Yy]*) return 0 ;;
    *)     return 1 ;;
  esac
}

prompt_choice() {
  local message="$1"
  shift
  local options=("$@")
  printf "\n  ${YELLOW}?${RESET} %s\n" "$message"
  local i=1
  for opt in "${options[@]}"; do
    printf "    ${BOLD}%d)${RESET} %s\n" "$i" "$opt"
    ((i++))
  done
  printf "  ${DIM}Enter number(s) separated by spaces, or 'all':${RESET} "
  read -r answer
  echo "$answer"
}

# --- Banner ---
print_banner() {
  local colors=("${RED}" "${YELLOW}" "${GREEN}" "${CYAN}" "${BLUE}" "${MAGENTA}")
  local lines=(
    '  ____       _          _    ___  '
    ' / ___|  ___| |_ __    / \  |_ _| '
    ' \___ \ / _ \ |  __|  / _ \  | |  '
    '  ___) |  __/ | |    / ___ \ | |  '
    ' |____/ \___|_|_|   /_/   \_\___| '
  )
  printf "\n"
  local i=0
  for line in "${lines[@]}"; do
    printf "${colors[$((i % ${#colors[@]}))]}%s${RESET}\n" "$line"
    ((i++))
  done
  printf "\n"
  printf "  ${BOLD}Internal Kit Installer${RESET} ${DIM}v1.1.0${RESET}\n"
  printf "  ${DIM}One command. Everything set up.${RESET}\n"
  printf "\n"
}

# --- Progress Bar ---
progress_bar() {
  local current=$1 total=$2 width=30
  local pct=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  printf "\r  ${CYAN}[${bar}]${RESET} ${BOLD}%3d%%${RESET}" "$pct"
  [[ "$current" -eq "$total" ]] && printf "\n"
}

# ============================================================================
#  MAIN
# ============================================================================

setup_colors
print_banner
detect_platform

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
INSTALL_LOG="$SCRIPT_DIR/.install.log"
INSTALLED_SKILLS=0
INSTALLED_TOOLKITS=0
SKIPPED=0
ERRORS=0

# Clear log
echo "Selr AI Internal Kit — Install Log" > "$INSTALL_LOG"
echo "Date: $(date)" >> "$INSTALL_LOG"
echo "Platform: $PLATFORM_OS" >> "$INSTALL_LOG"
echo "---" >> "$INSTALL_LOG"

# ──────────────────────────────────────────────────────────────────
step "Detecting your environment"
# ──────────────────────────────────────────────────────────────────

printf "  ${DIM}Platform:${RESET}  "
case "$PLATFORM_OS" in
  macos)   printf "${GREEN}macOS${RESET}\n" ;;
  linux)   printf "${GREEN}Linux${RESET}\n" ;;
  windows) printf "${GREEN}Windows (Git Bash)${RESET}\n" ;;
  wsl)     printf "${GREEN}Windows (WSL)${RESET}\n" ;;
  *)       printf "${YELLOW}Unknown${RESET}\n" ;;
esac

# Check prerequisites
PREREQ_PASS=0
PREREQ_FAIL=0

for cmd_pair in "node:Node.js" "git:Git" "claude:Claude Code"; do
  cmd="${cmd_pair%%:*}"
  name="${cmd_pair##*:}"
  if command -v "$cmd" > /dev/null 2>&1; then
    ver=$($cmd --version 2>/dev/null | head -1)
    pass "$name ($ver)"
    ((PREREQ_PASS++))
  else
    fail "$name — not installed"
    ((PREREQ_FAIL++))
  fi
done

# Check ~/.claude directory
if [[ -d "$HOME/.claude" ]]; then
  pass "Claude Code directory (~/.claude)"
  ((PREREQ_PASS++))
else
  fail "Claude Code directory (~/.claude) — not found"
  ((PREREQ_FAIL++))
fi

echo "Prerequisites: $PREREQ_PASS pass, $PREREQ_FAIL fail" >> "$INSTALL_LOG"

if [[ $PREREQ_FAIL -gt 0 ]]; then
  warn "Some prerequisites are missing. Installation may be incomplete."
  if ! prompt_yes_no "Continue anyway?" "n"; then
    error "Installation cancelled."
    exit 1
  fi
fi

# ──────────────────────────────────────────────────────────────────
step "Choosing what to install"
# ──────────────────────────────────────────────────────────────────

# Skills selection
AVAILABLE_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")
SKILL_DESCRIPTIONS=(
  "GoHighLevel CRM API — contacts, opportunities, conversations"
  "GHL browser automation — Playwright, 2FA, internal APIs"
  "Google Chat via gws CLI — messages, spaces, threads"
  "12-phase server provisioning — AWS, agents, Supabase"
  "Dispatch & Remote Control — Claude from your phone"
  "Skill creation workflow — build custom skills"
)

printf "\n  ${BOLD}Available Skills:${RESET}\n"
for i in "${!AVAILABLE_SKILLS[@]}"; do
  local_skill="${AVAILABLE_SKILLS[$i]}"
  if [[ -d "$SKILLS_DIR/$local_skill" ]]; then
    printf "    ${DIM}%d) %s — already installed${RESET}\n" "$((i+1))" "$local_skill"
  else
    printf "    ${BOLD}%d)${RESET} %-20s ${DIM}%s${RESET}\n" "$((i+1))" "$local_skill" "${SKILL_DESCRIPTIONS[$i]}"
  fi
done

printf "\n  ${DIM}Enter numbers separated by spaces, 'all', or 'none':${RESET} "
read -r skill_answer

SELECTED_SKILLS=()
if [[ "$skill_answer" == "all" ]]; then
  SELECTED_SKILLS=("${AVAILABLE_SKILLS[@]}")
elif [[ "$skill_answer" != "none" && -n "$skill_answer" ]]; then
  for num in $skill_answer; do
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#AVAILABLE_SKILLS[@]}" ]]; then
      SELECTED_SKILLS+=("${AVAILABLE_SKILLS[$((num-1))]}")
    fi
  done
fi

# Toolkit selection
printf "\n  ${BOLD}Available Toolkits:${RESET}\n"
AVAILABLE_TOOLKITS=("ghl-toolkit" "google-chat-toolkit")
TOOLKIT_DESCRIPTIONS=(
  "Complete GHL CRM integration — CLI, scripts, credentials"
  "Google Chat integration — gws CLI, GCP OAuth setup"
)
for i in "${!AVAILABLE_TOOLKITS[@]}"; do
  printf "    ${BOLD}%d)${RESET} %-25s ${DIM}%s${RESET}\n" "$((i+1))" "${AVAILABLE_TOOLKITS[$i]}" "${TOOLKIT_DESCRIPTIONS[$i]}"
done

printf "\n  ${DIM}Enter numbers separated by spaces, 'all', or 'none':${RESET} "
read -r toolkit_answer

SELECTED_TOOLKITS=()
if [[ "$toolkit_answer" == "all" ]]; then
  SELECTED_TOOLKITS=("${AVAILABLE_TOOLKITS[@]}")
elif [[ "$toolkit_answer" != "none" && -n "$toolkit_answer" ]]; then
  for num in $toolkit_answer; do
    if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#AVAILABLE_TOOLKITS[@]}" ]]; then
      SELECTED_TOOLKITS+=("${AVAILABLE_TOOLKITS[$((num-1))]}")
    fi
  done
fi

TOTAL_ITEMS=$(( ${#SELECTED_SKILLS[@]} + ${#SELECTED_TOOLKITS[@]} ))
if [[ $TOTAL_ITEMS -eq 0 ]]; then
  warn "Nothing selected. Exiting."
  exit 0
fi

success "Selected ${#SELECTED_SKILLS[@]} skill(s) and ${#SELECTED_TOOLKITS[@]} toolkit(s)"

# ──────────────────────────────────────────────────────────────────
step "Installing skills"
# ──────────────────────────────────────────────────────────────────

if [[ ${#SELECTED_SKILLS[@]} -eq 0 ]]; then
  skip "No skills selected"
else
  mkdir -p "$SKILLS_DIR"
  SKILL_IDX=0
  for skill in "${SELECTED_SKILLS[@]}"; do
    ((SKILL_IDX++))
    progress_bar "$SKILL_IDX" "${#SELECTED_SKILLS[@]}"

    SRC="$SCRIPT_DIR/skills/$skill"
    DEST="$SKILLS_DIR/$skill"

    if [[ ! -d "$SRC" ]]; then
      fail "$skill — source not found"
      echo "FAIL: $skill — source directory missing" >> "$INSTALL_LOG"
      ((ERRORS++))
      continue
    fi

    # Remove old version if exists, then copy fresh
    rm -rf "$DEST"
    cp -r "$SRC" "$DEST"

    if [[ -f "$DEST/SKILL.md" ]]; then
      pass "$skill installed"
      echo "INSTALLED: skill/$skill -> $DEST" >> "$INSTALL_LOG"
      ((INSTALLED_SKILLS++))
    else
      fail "$skill — copy failed"
      echo "FAIL: $skill — SKILL.md not found after copy" >> "$INSTALL_LOG"
      ((ERRORS++))
    fi
  done
fi

# ──────────────────────────────────────────────────────────────────
step "Installing toolkits"
# ──────────────────────────────────────────────────────────────────

if [[ ${#SELECTED_TOOLKITS[@]} -eq 0 ]]; then
  skip "No toolkits selected"
else
  for toolkit in "${SELECTED_TOOLKITS[@]}"; do
    TOOLKIT_DIR="$SCRIPT_DIR/toolkits/$toolkit"

    if [[ ! -f "$TOOLKIT_DIR/setup.sh" ]]; then
      fail "$toolkit — setup.sh not found"
      echo "FAIL: $toolkit — setup.sh missing" >> "$INSTALL_LOG"
      ((ERRORS++))
      continue
    fi

    info "Running $toolkit installer..."
    printf "\n"

    if bash "$TOOLKIT_DIR/setup.sh" 2>&1; then
      success "$toolkit installed"
      echo "INSTALLED: toolkit/$toolkit" >> "$INSTALL_LOG"
      ((INSTALLED_TOOLKITS++))
    else
      fail "$toolkit — setup failed (check output above)"
      echo "FAIL: $toolkit — setup.sh returned non-zero" >> "$INSTALL_LOG"
      ((ERRORS++))
    fi
  done
fi

# ──────────────────────────────────────────────────────────────────
step "Copying agent definitions"
# ──────────────────────────────────────────────────────────────────

AGENTS_DIR="$HOME/.claude/agents"
if [[ -d "$SCRIPT_DIR/agents" ]]; then
  mkdir -p "$AGENTS_DIR"
  AGENT_COUNT=0
  for agent_file in "$SCRIPT_DIR/agents"/*.md; do
    [[ -f "$agent_file" ]] || continue
    agent_name="$(basename "$agent_file")"
    cp "$agent_file" "$AGENTS_DIR/$agent_name"
    pass "Agent: $agent_name"
    echo "INSTALLED: agent/$agent_name -> $AGENTS_DIR/$agent_name" >> "$INSTALL_LOG"
    ((AGENT_COUNT++))
  done
  if [[ $AGENT_COUNT -eq 0 ]]; then
    skip "No agent files found"
  fi
else
  skip "No agents directory"
fi

# ──────────────────────────────────────────────────────────────────
step "Installation summary"
# ──────────────────────────────────────────────────────────────────

printf "\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 46)
printf "\n"
printf "  ${BOLD}${CYAN}  INSTALLATION COMPLETE${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 46)
printf "\n\n"

printf "  ${GREEN}\xe2\x9c\x93${RESET} Skills installed:   ${BOLD}%d${RESET}\n" "$INSTALLED_SKILLS"
printf "  ${GREEN}\xe2\x9c\x93${RESET} Toolkits installed: ${BOLD}%d${RESET}\n" "$INSTALLED_TOOLKITS"

if [[ $ERRORS -gt 0 ]]; then
  printf "  ${RED}\xe2\x9c\x97${RESET} Errors:             ${BOLD_RED}%d${RESET}\n" "$ERRORS"
fi

printf "\n"
printf "  ${DIM}Install log saved to: %s${RESET}\n" "$INSTALL_LOG"
printf "\n"

# --- Next Steps ---
printf "  ${BOLD}What's next:${RESET}\n\n"
printf "  ${CYAN}1.${RESET} Run the health dashboard to verify everything:\n"
printf "     ${DIM}bash %s/status.sh${RESET}\n\n" "$SCRIPT_DIR"

if [[ " ${SELECTED_TOOLKITS[*]} " =~ "ghl-toolkit" ]]; then
  printf "  ${CYAN}2.${RESET} Configure GHL credentials:\n"
  printf "     ${DIM}Edit ~/my-assistant/secrets/ghl.env${RESET}\n\n"
fi

if [[ " ${SELECTED_TOOLKITS[*]} " =~ "google-chat-toolkit" ]]; then
  printf "  ${CYAN}3.${RESET} Complete Google Chat OAuth:\n"
  printf "     ${DIM}Follow the prompts from the toolkit setup${RESET}\n\n"
fi

printf "  ${CYAN}%s.${RESET} Open Claude Code and start working:\n" "$((${#SELECTED_TOOLKITS[@]} + 2))"
printf "     ${DIM}cd ~/my-assistant && claude${RESET}\n"
printf "\n"

if [[ $ERRORS -eq 0 ]]; then
  printf "  ${BOLD_GREEN}Everything is ready. Happy building!${RESET}\n\n"
else
  printf "  ${BOLD_YELLOW}Some components had errors. Check the log and retry.${RESET}\n\n"
fi

echo "---" >> "$INSTALL_LOG"
echo "Result: $INSTALLED_SKILLS skills, $INSTALLED_TOOLKITS toolkits, $ERRORS errors" >> "$INSTALL_LOG"
echo "Completed: $(date)" >> "$INSTALL_LOG"
