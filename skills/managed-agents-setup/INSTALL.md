# Installing managed-agents-setup

> Private skill. Pairs with `/ai-ops-architect` and `/n8n`. Together: a workshop attendee gets from "I have a business" to "agents and workflows running" without typing a command.

## What you get

- `/managed-agents-setup` — Phase 0→7 guided setup of an Anthropic Managed Agent + Routine, with vault-backed MCP credentials
- 35 business-outcome presets across 8 verticals (real-estate, trades, coaches, consultants, ecommerce, agencies, prof-services, hospitality, creators) — canonical preset file
- 25 working scripts (preflight, install, vault-seeder, mcp-bridge, create-agent/env/routine, smoke-test, killswitch, daily-cost-monitor, ...)
- 4-tier connector strategy (Claude.ai passthrough → Rube → direct MCP → manual paste)
- Pairs with `/ai-ops-architect` and `/n8n` — same connector strategy, same refusal rules, single source of truth for presets

## Prerequisites

- macOS or Linux
- Claude Code CLI (`brew install claude` or per-Anthropic install)
- `gh` CLI authenticated (`gh auth login`)
- `python3`, `bash`, `jq` on PATH
- An Anthropic API key (will be set up in Phase 1 if you don't have one)

## Install

```bash
# Clone (private repo — gh handles auth)
gh repo clone luke-selrai/managed-agents-setup ~/.claude/skills/managed-agents-setup

# Make scripts executable
chmod +x ~/.claude/skills/managed-agents-setup/scripts/*.sh
chmod +x ~/.claude/skills/managed-agents-setup/scripts/*.py

# Verify
bash ~/.claude/skills/managed-agents-setup/scripts/verify.sh
```

## First run

In Claude Code, type:

```
/managed-agents-setup
```

The driver agent walks Phase 0 → 7 with confirmation between each. You only approve prompts.

If you don't already know which agent to build, run `/ai-ops-architect` first — it handles the discovery + audit and hands off to this skill with a chosen preset.

## Updating

```bash
cd ~/.claude/skills/managed-agents-setup && git pull
```

## Uninstall

```bash
rm -rf ~/.claude/skills/managed-agents-setup
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/managed-agents-setup` not found | Restart Claude Code — skills scanned on startup |
| `ant: command not found` | Phase 2 install failed; `bash scripts/install-cli.sh` again |
| API call returns 401 | Wrong API key; check keychain `security find-generic-password -a $USER -s anthropic-managed-agents -w` |
| `vault-seeder.py` errors on a service | That service isn't in `references/mcp-servers-catalog.md`; either add it or use Tier 2 (Rube) |
| Routine never fires | Check timezone (Anthropic uses UTC); cadence < 1hr is server-cron territory, not Routines |
| Cost spike alert | `bash scripts/killswitch.sh <agent-id>` to pause; investigate via daily-cost-monitor logs |
| `verify.sh` fails AC4 | Presets file empty/malformed; `git checkout references/business-outcome-presets.json` and re-run |

Full troubleshooting tree: `references/troubleshooting.md`.

## Where things live

```
~/.claude/skills/managed-agents-setup/
├── SKILL.md                              # entry, decision matrix, refusal rules
├── INSTALL.md                            # this file
├── .claude-plugin/plugin.json            # Claude Code plugin manifest
├── references/
│   ├── phases/0..7-*.md                  # phase-by-phase walkthroughs
│   ├── connector-strategy.md             # 4-tier doc
│   ├── handoff-template.md               # Phase 7 1-pager
│   ├── business-outcome-presets.json     # CANONICAL 35 presets
│   ├── mcp-servers-catalog.md            # remote MCP endpoint reference
│   ├── agent-templates.json
│   ├── environment-templates.json
│   ├── cost-calculator.md
│   ├── routines-cron-cheatsheet.md
│   └── troubleshooting.md
├── scripts/                              # 25 mature scripts (preflight, install, vault-seeder, ...)
└── .state/                               # per-machine, gitignored, chmod 700
```

## Privacy

- `~/.claude/managed-agents/` is per-laptop; never pushed to git.
- Pasted API keys go to Mac keychain or Anthropic Vault; never logged or echoed.
- Server pairing (Phase 9 in the full reference) is OPTIONAL — skill works standalone.

## Pairs with

- **`/ai-ops-architect`** — discovery + audit + opportunity map → delegates here for Managed Agent builds
- **`/n8n`** — sister skill for workflow runtime; chosen when 2+ SaaS + webhook + no reasoning
- **`server-setup`** — AWS infra layer; optional but enables sub-hourly cron + webhook glue
