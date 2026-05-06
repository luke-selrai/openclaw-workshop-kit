# Installing ai-ops-architect

> Private skill. Requires GitHub auth on the `luke-selrai` org or invitation.

## What you get

- `/ai-ops-architect` — guided 8-question audit → opportunity map → 1-3 builds in one session
- 250 curated n8n workflow templates (sticky-note headers + meta sidecars)
- 32 managed-agent presets across 8 verticals (real-estate, trades, coaches, etc.)
- 4-tier connector strategy (Claude.ai passthrough → Rube → direct MCP → manual)
- Pairs with `/n8n` and `/managed-agents-setup` already on your machine

## Prerequisites

- macOS or Linux
- Claude Code CLI installed (`brew install claude` or follow Anthropic install)
- `gh` CLI authenticated (`gh auth login`)
- `python3`, `bash`, `jq` on PATH
- An existing Anthropic key (for managed-agent builds) — set via `claude /login`

## Install

```bash
# Clone (private repo — gh handles auth)
gh repo clone luke-selrai/ai-ops-architect ~/.claude/skills/ai-ops-architect

# Make scripts executable
chmod +x ~/.claude/skills/ai-ops-architect/scripts/*.sh
chmod +x ~/.claude/skills/ai-ops-architect/scripts/*.py

# Verify (lists discovered MCP passthroughs + checks tools)
bash ~/.claude/skills/ai-ops-architect/scripts/verify.sh
```

## First run

In Claude Code, type:

```
/ai-ops-architect
```

The skill walks Phase 0 → 7 in sequence. Confirmation between each.

## Updating

```bash
cd ~/.claude/skills/ai-ops-architect && git pull
```

## Uninstall

```bash
rm -rf ~/.claude/skills/ai-ops-architect
```

(The `/n8n` and `/managed-agents-setup` skills remain — they're independent.)

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/ai-ops-architect` not found | Restart Claude Code — skills are scanned on startup |
| `audit.sh: command not found` | Run `chmod +x scripts/*.sh` |
| Memory extraction returns nothing | Skill falls back to interactive 8Q intake — that's fine |
| Rube auth fails | `claude mcp remove rube` then re-run `connect-via-rube.sh --force` |
| Template count < 250 | n8n.io rate-limited the curate run. Re-run `python3 scripts/curate-templates.py` |

## Where things live

```
~/.claude/skills/ai-ops-architect/
├── SKILL.md                      # entry, decision matrix
├── INSTALL.md                    # this file
├── references/                   # decision matrix, opportunity catalog, intake spec, connector strategy
├── templates/n8n/<12 cats>/      # 250 curated workflows
├── templates/managed-agents/     # 32 presets across 8 verticals
├── scripts/                      # audit, recommend, curate, claude-passthrough, connect-via-rube, verify
└── .state/                       # per-machine, gitignored, chmod 600
```

## Privacy

- `.state/` is per-laptop and gitignored. It holds the audit answers and selected builds. Never pushed.
- API keys typed at Tier 4 prompts are written to `.state/secrets/` (chmod 600) — same gitignore rule.
- The skill never logs secrets to stdout, the Claude transcript, or telemetry.
