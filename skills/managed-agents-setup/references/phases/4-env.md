# Phase 4 — First environment

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/create-environment.sh primary
```

Uses `references/environment-templates.json` with `primary` preset (basic Python + networking unrestricted). Other presets:
- `full-stack` — Python + Node + Postgres client + Playwright
- `locked-down` — minimal packages, no network egress except allow-listed
- `content-engine` — adds yt-dlp, ffmpeg, Pandoc

Env ID written to `~/.claude/managed-agents/env-id.txt`.
