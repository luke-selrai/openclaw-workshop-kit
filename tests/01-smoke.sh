#!/bin/bash
# ============================================================================
#  SMOKE TESTS — Does everything exist and is it structurally sound?
#  These run first. If smoke tests fail, nothing else matters.
# ============================================================================
SUITE_NAME="Smoke Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/test-runner.sh"

# ── Core Files ──────────────────────────────────────────────────
suite_header "Core Files"

assert_file_exists "README.md exists" "$ROOT_DIR/README.md"
assert_file_exists "install.sh exists" "$ROOT_DIR/install.sh"
assert_file_exists "status.sh exists" "$ROOT_DIR/status.sh"
assert_file_exists "doctor.sh exists" "$ROOT_DIR/doctor.sh"
assert_file_exists "uninstall.sh exists" "$ROOT_DIR/uninstall.sh"
assert_file_exists "update.sh exists" "$ROOT_DIR/update.sh"

assert_executable "install.sh is executable" "$ROOT_DIR/install.sh"
assert_executable "status.sh is executable" "$ROOT_DIR/status.sh"
assert_executable "doctor.sh is executable" "$ROOT_DIR/doctor.sh"
assert_executable "uninstall.sh is executable" "$ROOT_DIR/uninstall.sh"
assert_executable "update.sh is executable" "$ROOT_DIR/update.sh"

# ── Directory Structure ─────────────────────────────────────────
suite_header "Directory Structure"

assert_dir_exists "skills/ directory" "$ROOT_DIR/skills"
assert_dir_exists "toolkits/ directory" "$ROOT_DIR/toolkits"
assert_dir_exists "agents/ directory" "$ROOT_DIR/agents"
assert_dir_exists "docs/ directory" "$ROOT_DIR/docs"
assert_dir_exists "tests/ directory" "$ROOT_DIR/tests"

# ── All Skills Have SKILL.md ────────────────────────────────────
suite_header "Skills Exist"

ALL_SKILLS=("ghl-crm" "ghl-browser" "google-chat" "server-setup" "claude-dispatch" "skill-creator" "connector-recommender")
for skill in "${ALL_SKILLS[@]}"; do
  assert_file_exists "$skill/SKILL.md" "$ROOT_DIR/skills/$skill/SKILL.md"
done

# ── Toolkits Have Required Files ────────────────────────────────
suite_header "Toolkit Files"

for toolkit in "ghl-toolkit" "google-chat-toolkit"; do
  assert_file_exists "$toolkit/setup.sh" "$ROOT_DIR/toolkits/$toolkit/setup.sh"
  assert_file_exists "$toolkit/test.sh" "$ROOT_DIR/toolkits/$toolkit/test.sh"
  assert_file_exists "$toolkit/README.md" "$ROOT_DIR/toolkits/$toolkit/README.md"
  assert_file_exists "$toolkit/.gitignore" "$ROOT_DIR/toolkits/$toolkit/.gitignore"
  assert_executable "$toolkit/setup.sh executable" "$ROOT_DIR/toolkits/$toolkit/setup.sh"
  assert_executable "$toolkit/test.sh executable" "$ROOT_DIR/toolkits/$toolkit/test.sh"
done

# ── GHL-Specific Files ──────────────────────────────────────────
suite_header "GHL Toolkit Extras"

assert_file_exists "ghl CLI script" "$ROOT_DIR/toolkits/ghl-toolkit/scripts/ghl"
assert_executable "ghl CLI is executable" "$ROOT_DIR/toolkits/ghl-toolkit/scripts/ghl"
assert_file_exists "ghl.env.template" "$ROOT_DIR/toolkits/ghl-toolkit/secrets/ghl.env.template"
assert_file_exists "settings-permissions.md" "$ROOT_DIR/toolkits/ghl-toolkit/settings-permissions.md"

# ── Agent Files ─────────────────────────────────────────────────
suite_header "Agent Files"

assert_file_exists "server-setup agent" "$ROOT_DIR/agents/server-setup.md"

# ── Documentation Files ─────────────────────────────────────────
suite_header "Documentation"

assert_file_exists "docs/PREREQUISITES.md" "$ROOT_DIR/docs/PREREQUISITES.md"
assert_file_exists "docs/INTEGRATION.md" "$ROOT_DIR/docs/INTEGRATION.md"
assert_file_exists "docs/CHANGELOG.md" "$ROOT_DIR/docs/CHANGELOG.md"

# ── File Count Sanity ────────────────────────────────────────────
suite_header "File Count"

FILE_COUNT=$(find "$ROOT_DIR" -not -path "*/.git/*" -type f | wc -l)
assert_greater_than "Total files >= 27" "$FILE_COUNT" 26

SKILL_COUNT=$(find "$ROOT_DIR/skills" -name "SKILL.md" | wc -l)
assert_greater_than "SKILL.md files include our 7 additions" "$SKILL_COUNT" 6

print_summary
