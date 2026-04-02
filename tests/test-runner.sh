#!/bin/bash
# ============================================================================
#  Test Runner — Lightweight TAP-compliant test harness
#  Source this file in your test scripts.
# ============================================================================

PASS=0; FAIL=0; SKIP=0; TOTAL=0
FAILURES=()
SUITE_NAME="${SUITE_NAME:-Tests}"

# Colors (disabled when not a terminal or NO_COLOR is set)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
  _GREEN='\033[0;32m'; _RED='\033[0;31m'; _YELLOW='\033[1;33m'
  _CYAN='\033[0;36m'; _BOLD='\033[1m'; _DIM='\033[2m'; _NC='\033[0m'
else
  _GREEN=''; _RED=''; _YELLOW=''; _CYAN=''; _BOLD=''; _DIM=''; _NC=''
fi

# --- Assertions ---

assert_file_exists() {
  local description="$1" file="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -f "$file" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — file not found: $file")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}expected file: %s${_NC}\n" "$file"
  fi
}

assert_dir_exists() {
  local description="$1" dir="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -d "$dir" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — directory not found: $dir")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}expected directory: %s${_NC}\n" "$dir"
  fi
}

assert_executable() {
  local description="$1" file="$2"
  TOTAL=$((TOTAL + 1))
  if [[ -x "$file" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — not executable: $file")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
  fi
}

assert_syntax_ok() {
  local description="$1" file="$2"
  TOTAL=$((TOTAL + 1))
  if bash -n "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — syntax error in: $file")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}"; bash -n "$file" 2>&1 | head -3; printf "${_NC}\n"
  fi
}

assert_contains() {
  local description="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — string not found: '$needle'")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}expected to contain: '%s'${_NC}\n" "$needle"
  fi
}

assert_not_contains() {
  local description="$1" haystack="$2" needle="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — should NOT contain: '$needle'")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
  fi
}

assert_equals() {
  local description="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — expected '$expected', got '$actual'")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}expected: '%s'  actual: '%s'${_NC}\n" "$expected" "$actual"
  fi
}

assert_greater_than() {
  local description="$1" value="$2" minimum="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$value" -gt "$minimum" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s ${_DIM}(%s)${_NC}\n" "$description" "$value"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — $value is not > $minimum")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s ${_DIM}(%s <= %s)${_NC}\n" "$description" "$value" "$minimum"
  fi
}

assert_grep() {
  local description="$1" pattern="$2" file="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — pattern '$pattern' not found in $file")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
  fi
}

assert_no_grep() {
  local description="$1" pattern="$2" file="$3"
  TOTAL=$((TOTAL + 1))
  if ! grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    local match=$(grep -nE "$pattern" "$file" 2>/dev/null | head -1)
    FAILURES+=("$description — pattern '$pattern' found: $match")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    printf "    ${_DIM}found: %s${_NC}\n" "$match"
  fi
}

assert_diff() {
  local description="$1" file_a="$2" file_b="$3"
  TOTAL=$((TOTAL + 1))
  if diff -q "$file_a" "$file_b" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — files differ: $file_a vs $file_b")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
  fi
}

assert_frontmatter() {
  local description="$1" file="$2"
  TOTAL=$((TOTAL + 1))
  local first_line=$(head -1 "$file" 2>/dev/null)
  if [[ "$first_line" == "---" ]]; then
    # Check closing delimiter exists
    local closing=$(sed -n '2,$ { /^---$/= }' "$file" | head -1)
    if [[ -n "$closing" ]]; then
      PASS=$((PASS + 1))
      printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s\n" "$description"
    else
      FAIL=$((FAIL + 1))
      FAILURES+=("$description — frontmatter not closed (missing second ---)")
      printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
    fi
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$description — no frontmatter (first line: $first_line)")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s\n" "$description"
  fi
}

skip_test() {
  local description="$1" reason="${2:-}"
  TOTAL=$((TOTAL + 1))
  SKIP=$((SKIP + 1))
  printf "  ${_YELLOW}\xe2\x97\x8b${_NC} ${_DIM}SKIP: %s %s${_NC}\n" "$description" "$reason"
}

# --- Suite Helpers ---

suite_header() {
  printf "\n${_BOLD}${_CYAN}  %s${_NC}\n" "$1"
  printf "  ${_DIM}"; printf '%.0s─' $(seq 1 48); printf "${_NC}\n"
}

print_summary() {
  printf "\n"
  printf "  ${_BOLD}%.0s─${_NC}" $(seq 1 48)
  printf "\n"
  printf "  ${_BOLD}%s — Results${_NC}\n" "$SUITE_NAME"
  printf "  ${_BOLD}%.0s─${_NC}" $(seq 1 48)
  printf "\n"

  printf "  Total:   ${_BOLD}%d${_NC}\n" "$TOTAL"
  printf "  ${_GREEN}Passed:  %d${_NC}\n" "$PASS"
  if [[ $FAIL -gt 0 ]]; then
    printf "  ${_RED}Failed:  %d${_NC}\n" "$FAIL"
  fi
  if [[ $SKIP -gt 0 ]]; then
    printf "  ${_YELLOW}Skipped: %d${_NC}\n" "$SKIP"
  fi

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    printf "\n  ${_RED}${_BOLD}Failures:${_NC}\n"
    for f in "${FAILURES[@]}"; do
      printf "  ${_RED}  \xe2\x9c\x97 %s${_NC}\n" "$f"
    done
  fi
  printf "\n"

  [[ $FAIL -eq 0 ]]
}
