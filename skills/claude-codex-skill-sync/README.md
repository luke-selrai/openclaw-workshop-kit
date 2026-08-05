# Claude Codex Skill Sync

Built by Selr AI.

This skill makes Claude Code and Codex use the same local skill library.

## Use This For

- A workshop attendee who uses both Claude Code and Codex.
- A skill created in Codex that should appear in Claude Code.
- A Claude Code skill library that should show up inside Codex without hand-copying folders.

## What It Does

- Treats `~/.claude/skills` as the source of truth.
- Creates symlinks in `~/.codex/skills` so Codex can see those skills.
- Moves any real Codex-created skill folder back into `~/.claude/skills`, then replaces it with a symlink.
- Leaves Codex's own `~/.codex/skills/.system` folder alone.

## What It Does Not Do

- It does not copy MCP credentials.
- It does not copy API keys, cookies, passwords, tokens, or `.env` files.
- It does not clone another person's machine setup.
- It does not install Claude Code or Codex.

## Install

From this skill folder:

```bash
bash scripts/install.sh
```

The installer writes `~/bin/sync-codex-skills`, runs it once, and on macOS adds a background LaunchAgent so future skill changes stay synced.

## Verify

```bash
~/bin/sync-codex-skills
find ~/.codex/skills -maxdepth 1 -type l | wc -l
```

On macOS:

```bash
launchctl print "gui/$(id -u)/com.local.claude-codex-skill-sync"
```

