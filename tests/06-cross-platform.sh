#!/bin/bash
# ============================================================================
#  CROSS-PLATFORM TESTS — Path handling, command compatibility, portability
# ============================================================================
SUITE_NAME="Cross-Platform Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

# Detect current platform
case "$(uname -s)" in
  Darwin*)                CURRENT_OS="macos"   ;;
  Linux*)                 CURRENT_OS="linux"   ;;
  MINGW*|MSYS*|CYGWIN*)  CURRENT_OS="windows" ;;
  *)                      CURRENT_OS="unknown" ;;
esac

suite_header "Current Platform: $CURRENT_OS"

# ── Shebang Lines ────────────────────────────────────────────────
suite_header "Shebang Portability"

# All shell scripts should use #!/bin/bash (not #!/usr/bin/env bash for max compat)
for script in install.sh status.sh toolkits/ghl-toolkit/setup.sh \
  toolkits/ghl-toolkit/test.sh toolkits/google-chat-toolkit/setup.sh \
  toolkits/google-chat-toolkit/test.sh; do
  file="$ROOT_DIR/$script"
  shebang=$(head -1 "$file")
  TOTAL=$((TOTAL + 1))
  if [[ "$shebang" == "#!/bin/bash" || "$shebang" == "#!/usr/bin/env bash" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s has valid shebang\n" "$script"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$script has invalid shebang: $shebang")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s has invalid shebang: %s\n" "$script" "$shebang"
  fi
done

# ── ANSI Color Compatibility ─────────────────────────────────────
suite_header "ANSI Color Safety"

# Scripts should use \033 (not \e) for Git Bash compatibility
for script in install.sh status.sh; do
  file="$ROOT_DIR/$script"
  # Check for \e usage (Git Bash incompatible)
  if grep -qP '\\e\[' "$file" 2>/dev/null; then
    TOTAL=$((TOTAL + 1))
    FAIL=$((FAIL + 1))
    FAILURES+=("$script uses \\e (not Git Bash compatible)")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s uses \\\\e (use \\\\033 instead)\n" "$script"
  else
    TOTAL=$((TOTAL + 1))
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s uses \\\\033 (Git Bash compatible)\n" "$script"
  fi
done

# Scripts should handle NO_COLOR
for script in install.sh status.sh; do
  assert_grep "$script supports NO_COLOR" "NO_COLOR" "$ROOT_DIR/$script"
done

# Scripts should handle dumb terminals
for script in install.sh status.sh; do
  assert_grep "$script handles dumb terminal" "dumb" "$ROOT_DIR/$script"
done

# ── Path Handling ─────────────────────────────────────────────────
suite_header "Path Handling"

# No Windows-style backslash paths in scripts
for script in install.sh status.sh toolkits/ghl-toolkit/setup.sh \
  toolkits/google-chat-toolkit/setup.sh; do
  file="$ROOT_DIR/$script"
  # Check for C:\ or hardcoded Windows paths
  assert_no_grep "$script: no Windows backslash paths" 'C:\\' "$file"
done

# All scripts use $HOME or ~ (not hardcoded /Users/ or /home/)
for script in install.sh status.sh; do
  file="$ROOT_DIR/$script"
  assert_grep "$script uses \$HOME for paths" 'HOME' "$file"
done

# ── Platform Detection in Scripts ─────────────────────────────────
suite_header "Platform Detection"

# install.sh and status.sh must detect all platforms
for script in install.sh status.sh; do
  file="$ROOT_DIR/$script"
  content=$(cat "$file")
  assert_contains "$script detects macOS (Darwin)" "$content" "Darwin"
  assert_contains "$script detects Linux" "$content" "Linux"
  assert_contains "$script detects Windows (MINGW)" "$content" "MINGW"
done

# install.sh should also detect WSL
assert_grep "install.sh detects WSL" "microsoft" "$ROOT_DIR/install.sh"
assert_grep "status.sh detects WSL" "microsoft" "$ROOT_DIR/status.sh"

# ── Line Endings ──────────────────────────────────────────────────
suite_header "Line Endings"

# Shell scripts must not have Windows line endings (\r\n)
for script in install.sh status.sh toolkits/ghl-toolkit/setup.sh \
  toolkits/ghl-toolkit/test.sh toolkits/ghl-toolkit/scripts/ghl \
  toolkits/google-chat-toolkit/setup.sh toolkits/google-chat-toolkit/test.sh; do
  file="$ROOT_DIR/$script"
  TOTAL=$((TOTAL + 1))
  if grep -qP '\r' "$file" 2>/dev/null; then
    FAIL=$((FAIL + 1))
    FAILURES+=("$script has Windows line endings (CRLF)")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s has CRLF line endings\n" "$script"
  else
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s has Unix line endings (LF)\n" "$script"
  fi
done

# ── Unicode Safety ────────────────────────────────────────────────
suite_header "Unicode Rendering"

# Scripts that use Unicode should use \xe2\x... hex encoding (most portable)
# or direct UTF-8 characters (works in modern terminals)
for script in install.sh status.sh; do
  file="$ROOT_DIR/$script"
  # Check it uses hex-encoded checkmarks (most portable method)
  assert_grep "$script uses hex-encoded Unicode" 'xe2' "$file"
done

# ── Temp Directory Handling ───────────────────────────────────────
suite_header "Temp Directory Safety"

# Scripts should use mktemp or well-known paths, not hardcoded temp dirs
for script in install.sh; do
  file="$ROOT_DIR/$script"
  assert_no_grep "$script: no hardcoded /tmp/ paths" "^[^#]*/tmp/" "$file"
done

print_summary
