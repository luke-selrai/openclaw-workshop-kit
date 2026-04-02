#!/bin/bash
# ============================================================================
#  SKILL VALIDATION TESTS — Frontmatter, structure, content quality
# ============================================================================
SUITE_NAME="Skill Validation"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

ALL_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator")

# ── YAML Frontmatter ────────────────────────────────────────────
suite_header "YAML Frontmatter"

for skill in "${ALL_SKILLS[@]}"; do
  assert_frontmatter "$skill has valid frontmatter" "$ROOT_DIR/skills/$skill/SKILL.md"
done

assert_frontmatter "server-setup agent has frontmatter" "$ROOT_DIR/agents/server-setup.md"

# ── Required Frontmatter Fields ─────────────────────────────────
suite_header "Frontmatter Fields"

for skill in "${ALL_SKILLS[@]}"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  # Extract frontmatter block (between first and second ---)
  fm=$(sed -n '2,/^---$/p' "$file" | sed '$d')
  assert_contains "$skill has 'name' field" "$fm" "name:"
  assert_contains "$skill has 'description' field" "$fm" "description:"
done

# ── Skill Name Matches Directory ─────────────────────────────────
suite_header "Skill Name Consistency"

for skill in "${ALL_SKILLS[@]}"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  fm_name=$(sed -n '2,/^---$/p' "$file" | grep "^name:" | head -1 | sed 's/^name:[[:space:]]*//')
  assert_equals "$skill name matches directory" "$skill" "$fm_name"
done

# ── Content Quality ──────────────────────────────────────────────
suite_header "Content Quality"

for skill in "${ALL_SKILLS[@]}"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  lines=$(wc -l < "$file")

  # Must have meaningful content (> 50 lines)
  assert_greater_than "$skill has substantial content" "$lines" 50

  # Must have at least one markdown heading
  heading_count=$(grep -c "^#" "$file" 2>/dev/null || echo "0")
  assert_greater_than "$skill has markdown headings" "$heading_count" 0

  # Must not be empty or stub
  word_count=$(wc -w < "$file")
  assert_greater_than "$skill has >200 words" "$word_count" 200
done

# ── No Hardcoded User Paths ──────────────────────────────────────
suite_header "No Hardcoded User Paths"

for skill in "${ALL_SKILLS[@]}"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  # Check for real hardcoded paths like /Users/john/ or /Users/erichowens/
  # Exclude: placeholders like /Users/<YOUR_USER>/, example warnings like /Users/username/
  # Only flag lines that look like real paths (not inside backticks warning against them)
  real_paths=$(grep -nE "/Users/[a-z][a-z]*/" "$file" 2>/dev/null \
    | grep -vE "username|<YOUR|example|placeholder|hardcode|Never|Do not" || true)
  TOTAL=$((TOTAL + 1))
  if [[ -z "$real_paths" ]]; then
    PASS=$((PASS + 1))
    printf "  ${_GREEN}\xe2\x9c\x93${_NC} %s: no hardcoded /Users/ paths\n" "$skill"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$skill: hardcoded path found: $real_paths")
    printf "  ${_RED}\xe2\x9c\x97${_NC} %s: hardcoded /Users/ path found\n" "$skill"
    printf "    ${_DIM}%s${_NC}\n" "$real_paths"
  fi
done

# Also check agent
assert_no_grep "agent: no hardcoded /Users/[a-z]* paths" \
  "/Users/[a-z][a-z]*/" "$ROOT_DIR/agents/server-setup.md"

# ── Selr AI Tags (where applicable) ──────────────────────────────
suite_header "Ecosystem Tags"

for skill in "skill-creator" "claude-dispatch" "server-setup"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  assert_grep "$skill has selr-ai tag" "selr-ai" "$file"
done

# ── No Heredoc Artifacts ─────────────────────────────────────────
suite_header "No Heredoc Artifacts"

for skill in "${ALL_SKILLS[@]}"; do
  file="$ROOT_DIR/skills/$skill/SKILL.md"
  first_line=$(head -1 "$file")
  # Should NOT start with "cat >"
  assert_not_contains "$skill: no heredoc wrapper" "$first_line" "cat >"
done

# ── Bundled Skills Match Canonical ────────────────────────────────
suite_header "Bundled Skill Sync"

assert_diff "ghl-crm bundled matches canonical" \
  "$ROOT_DIR/toolkits/ghl-toolkit/skills/ghl-crm/SKILL.md" \
  "$ROOT_DIR/skills/ghl-crm/SKILL.md"

assert_diff "ghl-browser bundled matches canonical" \
  "$ROOT_DIR/toolkits/ghl-toolkit/skills/ghl-browser/SKILL.md" \
  "$ROOT_DIR/skills/ghl-browser/SKILL.md"

assert_diff "google-chat bundled matches canonical" \
  "$ROOT_DIR/toolkits/google-chat-toolkit/skills/google-chat/SKILL.md" \
  "$ROOT_DIR/skills/google-chat/SKILL.md"

print_summary
