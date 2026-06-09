#!/usr/bin/env bash
# scaffold_repo.sh — assemble a routine repo from generated pieces.
#
# Lays out the canonical routine-repo shape:
#
#   <target>/
#   ├── setup.sh
#   ├── .mcp.json
#   ├── CLAUDE.md   (optional)
#   ├── README.md
#   └── .claude/
#       ├── settings.json   (pre-approves tools so runs never prompt)
#       └── skills/<skill-name>/   (one copy per --skill flag)
#
# Initialises git, makes a clean first commit. Does NOT push to GitHub or
# create a remote. SKILL.md Phase 8 handles the push (gh repo create) after the
# user has reviewed the repo contents and confirmed the owner/visibility.
#
# Usage:
#   scaffold_repo.sh \
#     --target ~/.claude/routine-installer/my-routine-repo \
#     --setup-sh /tmp/setup.sh \
#     --mcp-json /tmp/mcp.json \
#     --readme /tmp/README.md \
#     --claude-md /tmp/CLAUDE.md \
#     --skill ~/.claude/skills/my-skill \
#     [--skill /path/to/another/skill ...]
#     [--no-git]
set -euo pipefail

TARGET=""
SETUP_SH=""
MCP_JSON=""
README=""
CLAUDE_MD=""
RESTORE_SH=""
SKILLS=()
DO_GIT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --setup-sh) SETUP_SH="$2"; shift 2 ;;
    --mcp-json) MCP_JSON="$2"; shift 2 ;;
    --readme) README="$2"; shift 2 ;;
    --claude-md) CLAUDE_MD="$2"; shift 2 ;;
    --restore-sh) RESTORE_SH="$2"; shift 2 ;;
    --skill) SKILLS+=("$2"); shift 2 ;;
    --no-git) DO_GIT=0; shift ;;
    *) echo "scaffold_repo.sh: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "scaffold_repo.sh: --target is required" >&2
  exit 1
fi
if [ -z "$SETUP_SH" ] || [ ! -f "$SETUP_SH" ]; then
  echo "scaffold_repo.sh: --setup-sh must point at an existing file" >&2
  exit 1
fi
if [ -z "$MCP_JSON" ] || [ ! -f "$MCP_JSON" ]; then
  echo "scaffold_repo.sh: --mcp-json must point at an existing file" >&2
  exit 1
fi
if [ "${#SKILLS[@]}" -eq 0 ]; then
  echo "scaffold_repo.sh: at least one --skill is required" >&2
  exit 1
fi

# Don't blat an existing directory unless it's empty
if [ -e "$TARGET" ]; then
  if [ "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    echo "scaffold_repo.sh: $TARGET is not empty; refusing to overwrite" >&2
    exit 1
  fi
fi

mkdir -p "$TARGET/.claude/skills"

# Copy generated files in
cp "$SETUP_SH" "$TARGET/setup.sh"
chmod 755 "$TARGET/setup.sh"
cp "$MCP_JSON" "$TARGET/.mcp.json"

# Credential restore must run INSIDE the agent session (where the routine's
# secret env vars exist), NOT in the pre-launch setup.sh (which they don't reach).
# If a restore script was generated, ship it and wire a SessionStart hook below.
# The restore script references env-var NAMES only - no secret values - so it is
# safe to commit.
RESTORE_REL=""
if [ -n "$RESTORE_SH" ]; then
  if [ ! -f "$RESTORE_SH" ]; then
    echo "scaffold_repo.sh: --restore-sh must point at an existing file" >&2
    exit 1
  fi
  cp "$RESTORE_SH" "$TARGET/.claude/restore-credentials.sh"
  chmod 755 "$TARGET/.claude/restore-credentials.sh"
  RESTORE_REL=".claude/restore-credentials.sh"
fi

# Pre-approve tools so the routine runs non-interactively. A scheduled cloud run
# has no human to click "Allow", so any permission prompt (e.g. the first MCP
# tool call) would stall the run. We auto-enable the project's MCP servers and
# allow every server from .mcp.json plus the base tools, and set the default
# permission mode to bypass as a catch-all. This is the fix for runs that pause
# on "Allow Claude to use <tool>?".
#
# When a restore script is present, we also wire a SessionStart hook that runs it
# at agent start - that is the only context that sees the routine's secret env
# vars, so it is where credentials get decoded into the files the CLIs expect.
python3 - "$TARGET/.mcp.json" "$TARGET/.claude/settings.json" "$RESTORE_REL" <<'PYEOF'
import json
import sys

mcpPath, outPath = sys.argv[1], sys.argv[2]
restoreRel = sys.argv[3] if len(sys.argv) > 3 else ""
try:
    with open(mcpPath) as f:
        servers = list((json.load(f).get("mcpServers") or {}).keys())
except Exception:
    servers = []

allow = ["mcp__" + name for name in servers]
allow += ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "WebFetch", "WebSearch", "Task", "TodoWrite"]

settings = {
    "enableAllProjectMcpServers": True,
    "permissions": {
        "defaultMode": "bypassPermissions",
        "allow": allow,
    },
}

if restoreRel:
    settings["hooks"] = {
        "SessionStart": [
            {
                "hooks": [
                    {
                        "type": "command",
                        "command": 'bash "$CLAUDE_PROJECT_DIR/%s"' % restoreRel,
                    }
                ]
            }
        ]
    }

with open(outPath, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

hookNote = " + SessionStart restore hook" if restoreRel else ""
print("scaffold_repo.sh: wrote .claude/settings.json (pre-approved %d MCP server(s) + base tools%s)" % (len(servers), hookNote), file=sys.stderr)
PYEOF

if [ -n "$README" ] && [ -f "$README" ]; then
  cp "$README" "$TARGET/README.md"
else
  cat > "$TARGET/README.md" <<README_EOF
# Routine repo

Packaged by routine-installer-plugin. Contains:

- \`setup.sh\` — installs CLIs in the routine sandbox before Claude Code launches.
- \`.claude/restore-credentials.sh\` — decodes credentials from the routine's env
  vars into the files the CLIs expect. Runs at agent start via a SessionStart
  hook (env vars reach the agent session, not \`setup.sh\`). Env-var NAMES only;
  no secret values, so it is committed.
- \`.mcp.json\` — MCP server config; env-var placeholders are filled by the
  routine environment.
- \`.claude/settings.json\` — pre-approves tools (no permission prompts) and wires
  the SessionStart restore hook.
- \`.claude/skills/\` — the skill(s) this routine drives.

Configure the routine env vars at claude.ai/code/routines, paste \`setup.sh\`
into the env's setup-script field, and you're done.
README_EOF
fi

if [ -n "$CLAUDE_MD" ] && [ -f "$CLAUDE_MD" ]; then
  cp "$CLAUDE_MD" "$TARGET/CLAUDE.md"
fi

# Copy each skill into .claude/skills/<skill-name>/
for skill in "${SKILLS[@]}"; do
  if [ ! -d "$skill" ]; then
    echo "scaffold_repo.sh: skill path does not exist: $skill" >&2
    exit 1
  fi
  if [ ! -f "$skill/SKILL.md" ]; then
    echo "scaffold_repo.sh: $skill has no SKILL.md" >&2
    exit 1
  fi
  skillName=$(basename "$skill")
  destDir="$TARGET/.claude/skills/$skillName"
  mkdir -p "$destDir"
  # rsync excluding common junk
  rsync -a --quiet \
    --exclude='.DS_Store' --exclude='__pycache__' --exclude='*.pyc' \
    --exclude='.git' --exclude='node_modules' \
    "$skill/" "$destDir/"
done

# Add a .gitignore for routine state we don't want committed
cat > "$TARGET/.gitignore" <<'GITIGNORE_EOF'
.DS_Store
__pycache__/
*.pyc
node_modules/
.env
GITIGNORE_EOF

if [ "$DO_GIT" -eq 1 ]; then
  if command -v git >/dev/null 2>&1; then
    (
      cd "$TARGET"
      git init -q
      git add .
      # Don't fail the whole scaffold if user.email isn't configured
      git -c user.email=routine-installer@localhost \
          -c user.name="routine-installer-plugin" \
          commit -q -m "Initial scaffold via routine-installer-plugin" || {
        echo "scaffold_repo.sh: git commit failed (continuing)" >&2
      }
    )
  else
    echo "scaffold_repo.sh: git not on PATH; skipping git init" >&2
  fi
fi

echo "scaffold_repo.sh: scaffolded routine repo at $TARGET"
echo "  - $(find "$TARGET" -type f | wc -l | tr -d ' ') files"
echo "  - skills: ${SKILLS[*]}"
