---
name: claude-codex-skill-sync
description: Install a safe local sync between Claude Code skills and Codex skills on the user's own machine. Use when a workshop attendee wants Claude Code and Codex to see the same skill library, or when moving a skill created in Codex back into Claude Code without copying folders by hand.
---

# Claude Codex Skill Sync

## Goal

Make Claude Code and Codex share one skill library on the user's own laptop.

This skill syncs only skill folders. It does not copy API keys, MCP credentials, browser cookies, `.env` files, private machine bundles, or another person's setup.

## What It Installs

- `~/bin/sync-codex-skills` - idempotent sync script.
- `~/.claude/skills` - the source skill folder, created if missing.
- `~/.codex/skills` - Codex's skill view, created if missing.
- `~/Library/LaunchAgents/com.local.claude-codex-skill-sync.plist` on macOS - background watcher that reruns the sync when either skill folder changes.

## Workflow

1. Read `README.md` for the plain-English install shape.
2. Run `bash scripts/install.sh`.
3. Confirm the script reports the number of Claude skills and Codex links.
4. On macOS, verify the watcher:

   ```bash
   launchctl print "gui/$(id -u)/com.local.claude-codex-skill-sync"
   ```

5. Test with one harmless skill folder if needed:

   ```bash
   mkdir -p ~/.codex/skills/example-local-test
   printf '%s\n' '---' 'name: example-local-test' 'description: Test skill.' '---' '# Test' > ~/.codex/skills/example-local-test/SKILL.md
   ~/bin/sync-codex-skills
   test -L ~/.codex/skills/example-local-test
   test -f ~/.claude/skills/example-local-test/SKILL.md
   rm ~/.codex/skills/example-local-test
   rm -rf ~/.claude/skills/example-local-test
   ~/bin/sync-codex-skills
   ```

## Rules

- Never paste or store secrets.
- Never copy another user's `~/.claude.json`, `~/.mcp.json`, `.env`, browser profile, cookies, or Keeper records.
- Preserve `~/.codex/skills/.system`; Codex owns that folder.
- Keep sync idempotent. Re-running the installer or script should be safe.
- If the user is not on macOS, install the script and run it once, but skip the LaunchAgent.

