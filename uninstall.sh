#!/bin/bash
# ============================================================================
#  Selr AI Internal Kit — Uninstaller
#  Clean removal with dry-run preview.
#  Usage: bash uninstall.sh [--dry-run] [--yes] [--keep-credentials]
# ============================================================================

# --- Color & Formatting ---
setup_colors() {
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; BOLD_RED='\033[1;31m'
    BG_RED='\033[41m'; BG_YELLOW='\033[43m'; WHITE='\033[0;37m'
  else
    BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' CYAN=''
    BOLD_RED='' BG_RED='' BG_YELLOW='' WHITE=''
  fi
}

setup_colors

# --- Parse Flags ---
DRY_RUN=false
AUTO_YES=false
KEEP_CREDS=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)          DRY_RUN=true ;;
    --yes|-y)           AUTO_YES=true ;;
    --keep-credentials) KEEP_CREDS=true ;;
    --help|-h)
      echo "Usage: bash uninstall.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --dry-run           Show what would be removed without removing anything"
      echo "  --yes, -y           Skip confirmation prompts"
      echo "  --keep-credentials  Preserve credential files (ghl.env, GCP tokens)"
      echo ""
      echo "Removes all Selr AI Internal Kit components from your system."
      echo "User-created files and other Claude Code skills are never touched."
      exit 0
      ;;
  esac
done

SKILLS_DIR="$HOME/.claude/skills"
AGENTS_DIR="$HOME/.claude/agents"
SCRIPTS_DIR="$HOME/my-assistant/scripts"
SECRETS_DIR="$HOME/my-assistant/secrets"

# Kit-managed components (only these get removed)
KIT_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")
KIT_AGENTS=("server-setup.md")
KIT_SCRIPTS=("ghl")
KIT_SECRETS=("ghl.env")

# --- Banner ---
printf "\n"
printf "  ${BOLD}${RED}%.0s─${RESET}" $(seq 1 48)
printf "\n"
if [[ "$DRY_RUN" == true ]]; then
  printf "  ${BOLD}${YELLOW}  UNINSTALLER — DRY RUN (no changes)${RESET}\n"
else
  printf "  ${BOLD}${RED}  SELR AI INTERNAL KIT — UNINSTALLER${RESET}\n"
fi
printf "  ${BOLD}${RED}%.0s─${RESET}" $(seq 1 48)
printf "\n\n"

# --- Scan what's installed ---
TO_REMOVE=()
CRED_FILES=()
TOTAL_SIZE=0

scan_item() {
  local path="$1" type="$2"
  if [[ -e "$path" ]]; then
    local size=0
    if [[ -d "$path" ]]; then
      size=$(du -sk "$path" 2>/dev/null | cut -f1)
    elif [[ -f "$path" ]]; then
      size=$(wc -c < "$path" 2>/dev/null)
      size=$((size / 1024))
    fi
    TOTAL_SIZE=$((TOTAL_SIZE + size))

    if [[ "$type" == "credential" ]]; then
      CRED_FILES+=("$path")
      if [[ "$KEEP_CREDS" == true ]]; then
        printf "  ${YELLOW}\xe2\x97\x8b${RESET} ${DIM}KEEP: %s (credential, --keep-credentials)${RESET}\n" "$path"
        return
      fi
    fi

    TO_REMOVE+=("$path")
    if [[ "$DRY_RUN" == true ]]; then
      printf "  ${RED}\xe2\x9c\x97${RESET} ${DIM}WOULD REMOVE:${RESET} %s ${DIM}(%d KB)${RESET}\n" "$path" "$size"
    else
      printf "  ${RED}\xe2\x9c\x97${RESET} %s ${DIM}(%d KB)${RESET}\n" "$path" "$size"
    fi
  fi
}

printf "  ${BOLD}Scanning installed components...${RESET}\n\n"

# Skills
printf "  ${CYAN}Skills:${RESET}\n"
for skill in "${KIT_SKILLS[@]}"; do
  scan_item "$SKILLS_DIR/$skill" "skill"
done

# Agents
printf "\n  ${CYAN}Agents:${RESET}\n"
for agent in "${KIT_AGENTS[@]}"; do
  scan_item "$AGENTS_DIR/$agent" "agent"
done

# Scripts
printf "\n  ${CYAN}Scripts:${RESET}\n"
scan_item "$SCRIPTS_DIR/ghl" "script"
# Also check ~/.claude/scripts/
scan_item "$HOME/.claude/scripts/ghl" "script"

# Credentials
printf "\n  ${CYAN}Credentials:${RESET}\n"
scan_item "$SECRETS_DIR/ghl.env" "credential"
scan_item "$HOME/.claude/secrets/ghl.env" "credential"

# Install log
scan_item "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.install.log" "log"

# --- Summary ---
printf "\n"
printf "  ${BOLD}%.0s─${RESET}" $(seq 1 48)
printf "\n"
printf "  Items to remove: ${BOLD}%d${RESET}\n" "${#TO_REMOVE[@]}"
if [[ ${#CRED_FILES[@]} -gt 0 ]] && [[ "$KEEP_CREDS" == true ]]; then
  printf "  Credentials kept: ${BOLD}%d${RESET}\n" "${#CRED_FILES[@]}"
fi
printf "  Estimated space:  ${BOLD}%d KB${RESET}\n" "$TOTAL_SIZE"
printf "\n"

if [[ ${#TO_REMOVE[@]} -eq 0 ]]; then
  printf "  ${GREEN}Nothing to remove. Kit is not installed.${RESET}\n\n"
  exit 0
fi

# --- Dry Run Exit ---
if [[ "$DRY_RUN" == true ]]; then
  printf "  ${YELLOW}${BOLD}DRY RUN — no files were removed.${RESET}\n"
  printf "  ${DIM}Run without --dry-run to actually remove these files.${RESET}\n\n"
  exit 0
fi

# --- Confirmation ---
if [[ "$AUTO_YES" != true ]]; then
  printf "  ${BOLD_RED}This cannot be undone.${RESET}\n"
  printf "  ${DIM}Tip: run with --dry-run first to preview.${RESET}\n\n"
  printf "  ${YELLOW}?${RESET} Remove all ${#TO_REMOVE[@]} items? ${DIM}[y/${BOLD}N${RESET}${DIM}]${RESET} "
  read -r confirm
  case "${confirm}" in
    [Yy]*) ;;
    *)
      printf "\n  ${GREEN}Cancelled. Nothing was removed.${RESET}\n\n"
      exit 0
      ;;
  esac
fi

# --- Remove ---
printf "\n  ${BOLD}Removing...${RESET}\n\n"
REMOVED=0
ERRORS=0

for item in "${TO_REMOVE[@]}"; do
  if [[ -d "$item" ]]; then
    if rm -rf "$item" 2>/dev/null; then
      printf "  ${GREEN}\xe2\x9c\x93${RESET} Removed: %s\n" "$item"
      ((REMOVED++))
    else
      printf "  ${RED}\xe2\x9c\x97${RESET} Failed: %s\n" "$item"
      ((ERRORS++))
    fi
  elif [[ -f "$item" ]]; then
    if rm -f "$item" 2>/dev/null; then
      printf "  ${GREEN}\xe2\x9c\x93${RESET} Removed: %s\n" "$item"
      ((REMOVED++))
    else
      printf "  ${RED}\xe2\x9c\x97${RESET} Failed: %s\n" "$item"
      ((ERRORS++))
    fi
  fi
done

# --- Clean up empty directories ---
for dir in "$SCRIPTS_DIR" "$SECRETS_DIR" "$AGENTS_DIR"; do
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir" 2>/dev/null && printf "  ${DIM}Cleaned empty directory: %s${RESET}\n" "$dir"
  fi
done

# --- Result ---
printf "\n"
printf "  ${BOLD}%.0s─${RESET}" $(seq 1 48)
printf "\n"
if [[ $ERRORS -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}Uninstall complete.${RESET} %d item(s) removed.\n" "$REMOVED"
else
  printf "  ${YELLOW}%d removed, %d failed.${RESET}\n" "$REMOVED" "$ERRORS"
fi
printf "\n"
printf "  ${DIM}The source kit at %s is untouched.${RESET}\n" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf "  ${DIM}To reinstall: bash install.sh${RESET}\n\n"
