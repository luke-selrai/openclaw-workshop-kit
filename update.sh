#!/bin/bash
# ============================================================================
#  Selr AI Internal Kit — Updater
#  Pulls latest from repo and re-installs only changed components.
#  Usage: bash update.sh [--check] [--force]
# ============================================================================

# --- Color & Formatting ---
setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
    BOLD_GREEN='\033[1;32m'
    BG_GREEN='\033[42m'; BG_YELLOW='\033[43m'; WHITE='\033[0;37m'
  else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
    MAGENTA='' BOLD_GREEN='' BG_GREEN='' BG_YELLOW='' WHITE=''
  fi
}

setup_colors

# --- Parse Flags ---
CHECK_ONLY=false
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --check)    CHECK_ONLY=true ;;
    --force|-f) FORCE=true ;;
    --help|-h)
      echo "Usage: bash update.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --check    Only check for updates, don't install"
      echo "  --force    Re-install all components even if unchanged"
      echo ""
      echo "Pulls latest source and re-installs only changed skills/agents."
      exit 0
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"

# --- Banner ---
printf "\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 48)
printf "\n"
printf "  ${BOLD}${CYAN}  SELR AI INTERNAL KIT — UPDATER${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s─${RESET}" $(seq 1 48)
printf "\n\n"

# ══════════════════════════════════════════════════════════════════
# STEP 1: Pull latest from git (if this is a git repo)
# ══════════════════════════════════════════════════════════════════

if [[ -d "$SCRIPT_DIR/.git" ]]; then
  printf "  ${BOLD}Checking for updates...${RESET}\n\n"

  # Fetch without merging
  cd "$SCRIPT_DIR"
  CURRENT_HASH=$(git rev-parse HEAD 2>/dev/null)
  git fetch origin 2>/dev/null

  REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

  if [[ "$CURRENT_HASH" == "$REMOTE_HASH" ]]; then
    printf "  ${GREEN}\xe2\x9c\x93${RESET} Source is up to date ${DIM}(%s)${RESET}\n" "${CURRENT_HASH:0:7}"
    GIT_UPDATED=false
  else
    BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || git rev-list --count HEAD..origin/master 2>/dev/null || echo "?")
    printf "  ${YELLOW}\xe2\x9a\xa0${RESET} Source is ${BOLD}%s commit(s)${RESET} behind remote\n" "$BEHIND"
    printf "    ${DIM}Local:  %s${RESET}\n" "${CURRENT_HASH:0:7}"
    printf "    ${DIM}Remote: %s${RESET}\n" "${REMOTE_HASH:0:7}"

    if [[ "$CHECK_ONLY" == true ]]; then
      printf "\n  ${DIM}Run without --check to update.${RESET}\n\n"
      exit 0
    fi

    printf "\n  ${CYAN}\xe2\x96\xb6${RESET} Pulling latest changes...\n"
    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
      NEW_HASH=$(git rev-parse HEAD 2>/dev/null)
      printf "  ${GREEN}\xe2\x9c\x93${RESET} Updated to ${BOLD}%s${RESET}\n" "${NEW_HASH:0:7}"
      GIT_UPDATED=true

      # Show what changed
      printf "\n  ${DIM}Changes:${RESET}\n"
      git log --oneline "${CURRENT_HASH}..HEAD" 2>/dev/null | while read -r line; do
        printf "    ${DIM}%s${RESET}\n" "$line"
      done
    else
      printf "  ${RED}\xe2\x9c\x97${RESET} Pull failed — you may have local changes\n"
      printf "    ${DIM}Try: git stash && bash update.sh && git stash pop${RESET}\n"
      exit 1
    fi
  fi
else
  printf "  ${DIM}Not a git repo — skipping source update.${RESET}\n"
  printf "  ${DIM}Working with local files only.${RESET}\n"
  GIT_UPDATED=false
fi

if [[ "$CHECK_ONLY" == true ]]; then
  printf "\n  ${DIM}Check complete. Run without --check to apply updates.${RESET}\n\n"
  exit 0
fi

# ══════════════════════════════════════════════════════════════════
# STEP 2: Compare installed vs source, update changed components
# ══════════════════════════════════════════════════════════════════

printf "\n  ${BOLD}Comparing installed components to source...${RESET}\n\n"

UPDATED=0
SKIPPED=0
INSTALLED_NEW=0

ALL_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")

# --- Skills ---
printf "  ${CYAN}Skills:${RESET}\n"
for skill in "${ALL_SKILLS[@]}"; do
  SRC="$SCRIPT_DIR/skills/$skill/SKILL.md"
  DEST="$SKILLS_DIR/$skill/SKILL.md"

  if [[ ! -f "$SRC" ]]; then
    continue
  fi

  if [[ ! -f "$DEST" ]]; then
    # Not installed — install it
    printf "  ${YELLOW}\xe2\x9c\x9a${RESET} %-25s ${BOLD}NEW${RESET} — installing\n" "$skill"
    mkdir -p "$SKILLS_DIR/$skill"
    cp -r "$SCRIPT_DIR/skills/$skill/"* "$SKILLS_DIR/$skill/"
    ((INSTALLED_NEW++))
  elif [[ "$FORCE" == true ]]; then
    printf "  ${CYAN}\xe2\x86\xbb${RESET} %-25s ${BOLD}FORCE${RESET} — re-installing\n" "$skill"
    cp -r "$SCRIPT_DIR/skills/$skill/"* "$SKILLS_DIR/$skill/"
    ((UPDATED++))
  elif ! diff -q "$SRC" "$DEST" > /dev/null 2>&1; then
    printf "  ${YELLOW}\xe2\x86\x91${RESET} %-25s ${BOLD}CHANGED${RESET} — updating\n" "$skill"
    cp -r "$SCRIPT_DIR/skills/$skill/"* "$SKILLS_DIR/$skill/"
    ((UPDATED++))
  else
    printf "  ${GREEN}\xe2\x9c\x93${RESET} %-25s ${DIM}up to date${RESET}\n" "$skill"
    ((SKIPPED++))
  fi
done

# --- Agents ---
printf "\n  ${CYAN}Agents:${RESET}\n"
for agent_file in "$SCRIPT_DIR/agents"/*.md; do
  [[ -f "$agent_file" ]] || continue
  agent_name="$(basename "$agent_file")"
  DEST="$AGENTS_DIR/$agent_name"

  if [[ ! -f "$DEST" ]]; then
    printf "  ${YELLOW}\xe2\x9c\x9a${RESET} %-25s ${BOLD}NEW${RESET} — installing\n" "$agent_name"
    mkdir -p "$AGENTS_DIR"
    cp "$agent_file" "$DEST"
    ((INSTALLED_NEW++))
  elif [[ "$FORCE" == true ]]; then
    printf "  ${CYAN}\xe2\x86\xbb${RESET} %-25s ${BOLD}FORCE${RESET} — re-installing\n" "$agent_name"
    cp "$agent_file" "$DEST"
    ((UPDATED++))
  elif ! diff -q "$agent_file" "$DEST" > /dev/null 2>&1; then
    printf "  ${YELLOW}\xe2\x86\x91${RESET} %-25s ${BOLD}CHANGED${RESET} — updating\n" "$agent_name"
    cp "$agent_file" "$DEST"
    ((UPDATED++))
  else
    printf "  ${GREEN}\xe2\x9c\x93${RESET} %-25s ${DIM}up to date${RESET}\n" "$agent_name"
    ((SKIPPED++))
  fi
done

# ══════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════

printf "\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 48)
printf "\n"
printf "  ${BOLD}${CYAN}  UPDATE COMPLETE${RESET}\n"
printf "  ${BOLD}${CYAN}%.0s═${RESET}" $(seq 1 48)
printf "\n\n"

TOTAL_CHANGES=$((UPDATED + INSTALLED_NEW))

if [[ $TOTAL_CHANGES -eq 0 ]]; then
  printf "  ${BG_GREEN}${WHITE}${BOLD} EVERYTHING UP TO DATE ${RESET}\n\n"
  printf "  ${GREEN}No changes needed. All components match source.${RESET}\n"
else
  printf "  ${GREEN}\xe2\x9c\x93 Updated:${RESET}       ${BOLD}%d${RESET} component(s)\n" "$UPDATED"
  printf "  ${GREEN}\xe2\x9c\x9a New:${RESET}           ${BOLD}%d${RESET} component(s)\n" "$INSTALLED_NEW"
  printf "  ${DIM}\xe2\x9c\x93 Unchanged:${RESET}     %d component(s)\n" "$SKIPPED"
fi

printf "\n"
printf "  ${DIM}Verify with: bash status.sh${RESET}\n"
printf "  ${DIM}Full check:  bash doctor.sh${RESET}\n"
printf "\n"
