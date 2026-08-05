# SETUP-PROMPT.md

Paste this into Claude Code from inside the `claude-codex-skill-sync` skill folder.

```text
Install the claude-codex-skill-sync skill.

1. Read SKILL.md and README.md so you understand what will be changed.
2. Run `bash scripts/install.sh`.
3. Verify `~/bin/sync-codex-skills` runs successfully.
4. If this is macOS, verify `launchctl print "gui/$(id -u)/com.local.claude-codex-skill-sync"` returns a LaunchAgent entry.
5. Report the result in plain English, including the skill counts printed by the script.

Do not copy credentials, MCP config, `.env` files, cookies, browser profiles, or another person's setup. This skill only syncs local skill folders.
```

