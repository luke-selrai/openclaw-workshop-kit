#!/bin/bash
# ============================================================================
#  DOCUMENTATION TESTS — Markdown structure, internal links, completeness
# ============================================================================
SUITE_NAME="Documentation Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

# ── Documentation Files Exist ─────────────────────────────────────
suite_header "Documentation Completeness"

DOC_FILES=("README.md" "docs/PREREQUISITES.md" "docs/INTEGRATION.md" "docs/CHANGELOG.md")
for doc in "${DOC_FILES[@]}"; do
  assert_file_exists "$doc exists" "$ROOT_DIR/$doc"
done

# ── Minimum Content Length ────────────────────────────────────────
suite_header "Content Length"

for doc in "${DOC_FILES[@]}"; do
  file="$ROOT_DIR/$doc"
  if [[ -f "$file" ]]; then
    lines=$(wc -l < "$file")
    assert_greater_than "$doc has substantial content (>50 lines)" "$lines" 50
  fi
done

# ── README Structure ──────────────────────────────────────────────
suite_header "README.md Structure"

README="$ROOT_DIR/README.md"
README_CONTENT=$(cat "$README")

assert_grep "README has title heading" "^# Selr AI" "$README"
assert_contains "README mentions install.sh" "$README_CONTENT" "install.sh"
assert_contains "README mentions status.sh" "$README_CONTENT" "status.sh"
assert_contains "README links to PREREQUISITES" "$README_CONTENT" "PREREQUISITES.md"
assert_contains "README links to INTEGRATION" "$README_CONTENT" "INTEGRATION.md"
assert_contains "README links to CHANGELOG" "$README_CONTENT" "CHANGELOG.md"
assert_contains "README has Quick Start section" "$README_CONTENT" "Quick Start"
assert_contains "README has Contributors section" "$README_CONTENT" "Contributors"
assert_contains "README credits luke-selrai" "$README_CONTENT" "luke-selrai"
assert_contains "README credits Khushi-selrai" "$README_CONTENT" "Khushi-selrai"
assert_contains "README credits cenred-selrai" "$README_CONTENT" "cenred-selrai"
assert_contains "README credits Gian Carino" "$README_CONTENT" "Gian Carino"

# ── PREREQUISITES Structure ───────────────────────────────────────
suite_header "PREREQUISITES.md Structure"

PREREQ="$ROOT_DIR/docs/PREREQUISITES.md"
PREREQ_CONTENT=$(cat "$PREREQ")

assert_contains "PREREQ has Quick Checklist" "$PREREQ_CONTENT" "Quick Checklist"
assert_contains "PREREQ has System Requirements" "$PREREQ_CONTENT" "System Requirements"
assert_contains "PREREQ has Core Requirements" "$PREREQ_CONTENT" "Core Requirements"
assert_contains "PREREQ has GHL section" "$PREREQ_CONTENT" "GHL Toolkit Requirements"
assert_contains "PREREQ has Google Chat section" "$PREREQ_CONTENT" "Google Chat Toolkit Requirements"
assert_contains "PREREQ has Server Setup section" "$PREREQ_CONTENT" "Server Setup Requirements"
assert_contains "PREREQ has Dispatch section" "$PREREQ_CONTENT" "Claude Dispatch Requirements"
assert_contains "PREREQ has Cost Summary" "$PREREQ_CONTENT" "Cost Summary"
assert_contains "PREREQ has Network section" "$PREREQ_CONTENT" "Network and Firewall"
assert_contains "PREREQ has Pre-Install Verification" "$PREREQ_CONTENT" "Pre-Install Verification"
assert_contains "PREREQ mentions Node.js" "$PREREQ_CONTENT" "Node.js"
assert_contains "PREREQ mentions Claude Code" "$PREREQ_CONTENT" "Claude Code"
assert_contains "PREREQ mentions GoHighLevel" "$PREREQ_CONTENT" "GoHighLevel"
assert_contains "PREREQ mentions Google Workspace" "$PREREQ_CONTENT" "Google Workspace"
assert_contains "PREREQ mentions AWS" "$PREREQ_CONTENT" "AWS"
assert_contains "PREREQ mentions Supabase" "$PREREQ_CONTENT" "Supabase"

# ── CHANGELOG Structure ───────────────────────────────────────────
suite_header "CHANGELOG.md Structure"

CHANGELOG="$ROOT_DIR/docs/CHANGELOG.md"
CHANGELOG_CONTENT=$(cat "$CHANGELOG")

assert_grep "CHANGELOG has title" "^# Changelog" "$CHANGELOG"
assert_contains "CHANGELOG has version 1.0.0" "$CHANGELOG_CONTENT" "[1.0.0]"
assert_contains "CHANGELOG has version 1.1.0" "$CHANGELOG_CONTENT" "[1.1.0]"
assert_contains "CHANGELOG has version 1.2.0" "$CHANGELOG_CONTENT" "[1.2.0]"
assert_contains "CHANGELOG has Added sections" "$CHANGELOG_CONTENT" "#### Added"
assert_contains "CHANGELOG credits luke-selrai" "$CHANGELOG_CONTENT" "luke-selrai"
assert_contains "CHANGELOG credits Khushi-selrai" "$CHANGELOG_CONTENT" "Khushi-selrai"
assert_contains "CHANGELOG credits cenred-selrai" "$CHANGELOG_CONTENT" "cenred-selrai"
assert_contains "CHANGELOG credits Gian Carino" "$CHANGELOG_CONTENT" "Gian Carino"
assert_contains "CHANGELOG references PR #1" "$CHANGELOG_CONTENT" "PR #1"
assert_contains "CHANGELOG references PR #12" "$CHANGELOG_CONTENT" "PR #12"

# ── INTEGRATION Structure ─────────────────────────────────────────
suite_header "INTEGRATION.md Structure"

INTEG="$ROOT_DIR/docs/INTEGRATION.md"
INTEG_CONTENT=$(cat "$INTEG")

assert_contains "INTEGRATION has Contributors section" "$INTEG_CONTENT" "Contributors and Credits"
assert_contains "INTEGRATION has Test Results" "$INTEG_CONTENT" "Test Results"
assert_contains "INTEGRATION has Troubleshooting Log" "$INTEG_CONTENT" "Troubleshooting"
assert_contains "INTEGRATION has Decisions section" "$INTEG_CONTENT" "Decisions and Rationale"
assert_contains "INTEGRATION references official kit URL" "$INTEG_CONTENT" "openclaw-workshop-kit"
assert_contains "INTEGRATION references internal kit URL" "$INTEG_CONTENT" "selrai-internal-kit"

# ── Internal Links ────────────────────────────────────────────────
suite_header "Internal Link Validation"

# Check that links in README point to files that exist
while IFS= read -r link; do
  # Skip external URLs, anchors, and empty
  [[ "$link" =~ ^https?:// ]] && continue
  [[ "$link" =~ ^# ]] && continue
  [[ -z "$link" ]] && continue

  # Strip anchor
  target="${link%%#*}"
  [[ -z "$target" ]] && continue

  resolved="$ROOT_DIR/$target"
  TOTAL=$((TOTAL + 1))
  if [[ -e "$resolved" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} README link: %s\n" "$link"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("Broken link in README: $link -> $resolved")
    printf "  ${_RED}\xe2\x9c\x97${_NC} README link broken: %s\n" "$link"
  fi
done < <(grep -oP '\[.*?\]\(\K[^)]+' "$ROOT_DIR/README.md" 2>/dev/null)

# ── Toolkit READMEs ───────────────────────────────────────────────
suite_header "Toolkit README Completeness"

for toolkit in "ghl-toolkit" "google-chat-toolkit"; do
  file="$ROOT_DIR/toolkits/$toolkit/README.md"
  content=$(cat "$file")
  assert_contains "$toolkit README has setup steps" "$content" "setup"
  assert_grep "$toolkit README has troubleshooting" "[Tt]roubleshooting" "$file"
done

print_summary
