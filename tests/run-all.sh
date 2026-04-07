#!/bin/bash
# ============================================================================
#  MASTER TEST RUNNER — Runs all test suites in order
#  Usage: bash tests/run-all.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
  BG_GREEN='\033[42m'; BG_RED='\033[41m'; BG_YELLOW='\033[43m'
  WHITE='\033[0;37m'
else
  BOLD='' DIM='' RESET='' RED='' GREEN='' YELLOW='' CYAN='' MAGENTA=''
  BG_GREEN='' BG_RED='' BG_YELLOW='' WHITE=''
fi

# Banner
printf "\n"
printf "${BOLD}${CYAN}"
printf "  ╔══════════════════════════════════════════════╗\n"
printf "  ║   SELR AI INTERNAL KIT — FULL TEST SUITE    ║\n"
printf "  ╚══════════════════════════════════════════════╝\n"
printf "${RESET}\n"
printf "  ${DIM}%s | %s${RESET}\n\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$(uname -s)"

# Suite definitions
SUITES=(
  "01-smoke.sh:Smoke Tests"
  "02-skills.sh:Skill Validation"
  "03-toolkits.sh:Toolkit Tests"
  "04-security.sh:Security Tests"
  "05-docs.sh:Documentation Tests"
  "06-cross-platform.sh:Cross-Platform Tests"
)

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
FAILED_NAMES=()

START_TIME=$(date +%s)

for suite_entry in "${SUITES[@]}"; do
  suite_file="${suite_entry%%:*}"
  suite_name="${suite_entry##*:}"
  suite_path="$SCRIPT_DIR/$suite_file"

  ((TOTAL_SUITES++))

  printf "${BOLD}${MAGENTA}"
  printf "  ┌──────────────────────────────────────────────┐\n"
  printf "  │  SUITE %d/%d: %-33s│\n" "$TOTAL_SUITES" "${#SUITES[@]}" "$suite_name"
  printf "  └──────────────────────────────────────────────┘\n"
  printf "${RESET}"

  if [[ ! -f "$suite_path" ]]; then
    printf "  ${RED}Suite file not found: %s${RESET}\n\n" "$suite_path"
    ((FAILED_SUITES++))
    FAILED_NAMES+=("$suite_name (file missing)")
    continue
  fi

  suite_start=$(date +%s)

  if bash "$suite_path"; then
    ((PASSED_SUITES++))
    suite_end=$(date +%s)
    suite_duration=$((suite_end - suite_start))
    printf "  ${GREEN}${BOLD}SUITE PASSED${RESET} ${DIM}(%ds)${RESET}\n\n" "$suite_duration"
  else
    ((FAILED_SUITES++))
    FAILED_NAMES+=("$suite_name")
    suite_end=$(date +%s)
    suite_duration=$((suite_end - suite_start))
    printf "  ${RED}${BOLD}SUITE FAILED${RESET} ${DIM}(%ds)${RESET}\n\n" "$suite_duration"
  fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# ── Grand Summary ─────────────────────────────────────────────────
printf "${BOLD}${CYAN}"
printf "  ╔══════════════════════════════════════════════╗\n"
printf "  ║              GRAND SUMMARY                   ║\n"
printf "  ╚══════════════════════════════════════════════╝\n"
printf "${RESET}\n"

# Status badge
if [[ $FAILED_SUITES -eq 0 ]]; then
  printf "  ${BG_GREEN}${WHITE}${BOLD} ALL %d SUITES PASSED ${RESET}\n\n" "$TOTAL_SUITES"
else
  printf "  ${BG_RED}${WHITE}${BOLD} %d/%d SUITES FAILED ${RESET}\n\n" "$FAILED_SUITES" "$TOTAL_SUITES"
fi

# Details
printf "  ${GREEN}\xe2\x9c\x93 Passed suites:${RESET}  ${BOLD}%d${RESET}\n" "$PASSED_SUITES"
if [[ $FAILED_SUITES -gt 0 ]]; then
  printf "  ${RED}\xe2\x9c\x97 Failed suites:${RESET}  ${BOLD}%d${RESET}\n" "$FAILED_SUITES"
  printf "\n  ${RED}${BOLD}Failed:${RESET}\n"
  for name in "${FAILED_NAMES[@]}"; do
    printf "  ${RED}  \xe2\x9c\x97 %s${RESET}\n" "$name"
  done
fi
printf "  ${DIM}Total time:     %ds${RESET}\n" "$TOTAL_DURATION"
printf "\n"

# Exit code
if [[ $FAILED_SUITES -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}Kit is 101%% ready for upload.${RESET}\n\n"
  exit 0
else
  printf "  ${RED}${BOLD}Fix failures before uploading.${RESET}\n\n"
  exit 1
fi
