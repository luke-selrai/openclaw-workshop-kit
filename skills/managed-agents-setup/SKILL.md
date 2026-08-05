---
name: managed-agents-setup
description: "Sets up Anthropic Managed Agents and Routines - a scheduled cloud agent with vault-stored credentials, kill switch and cost monitor. Use when the user wants a Claude agent running in the cloud, a scheduled Claude task, or an agent that runs itself."
---

# Managed Agents Setup

> Pairs with `/ai-ops-architect` (orchestrator) + `/n8n` (workflow runtime). The orchestrator decides what to build; this skill builds the agent.

## When to use

- User has an Anthropic API key and wants a cloud-hosted agent on a schedule
- Non-technical business owner going zero-to-production: from "I have an Anthropic account" to a running agent, without typing a command
- Workshop attendee picked an agent preset from `/ai-ops-architect` and is ready to deploy
- Need a Routine (scheduled `claude.ai/code/routines` job) instead of a workflow
- Stateful, conversational, or long-running task with vault-backed MCP credentials

## When NOT to use

- User wants a 2-SaaS webhook flow with no reasoning → `/n8n`
- User wants a sub-hourly cron with bash → server-cron on AWS (or Routine if no server)
- Pure research / strategy questions with no build intent
- Audit / discovery (no preset chosen yet) → `/ai-ops-architect` first

## Phases

The skill walks Phase 0 → 7 in sequence with confirmation between each. Phase detail lives in `references/phases/<n>-*.md` so this file stays scannable.

| # | Phase | Script / output |
|---|---|---|
| 0 | Pre-flight | `bash scripts/preflight.sh` → JSON status |
| 1 | Anthropic Console | Workspace + API key (Playwright or manual paste) |
| 2 | Local CLI + SDK | `bash scripts/install-cli.sh` |
| 3 | Vault seeding | `python3 scripts/vault-seeder.py` + `bash scripts/mcp-bridge.sh` |
| 4 | First environment | `bash scripts/create-environment.sh primary` |
| 5 | Create the agent | `bash scripts/create-agent.sh <preset-id>` (presets in `references/business-outcome-presets.json`) |
| 6 | Schedule via Routine | `bash scripts/create-routine.sh --name NAME --cron "0 9 * * *" --prompt PROMPT --repo URL --env-id ENV` |
| 7 | Handoff | `bash scripts/smoke-test.sh` + 1-pager + kill switch + daily cost monitor |

## Quick start

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/preflight.sh         # Phase 0
bash ~/.claude/skills/managed-agents-setup/scripts/install-cli.sh       # Phase 2
python3 ~/.claude/skills/managed-agents-setup/scripts/vault-seeder.py \
  --secrets-env ~/agents-cc/shared/secrets.env --vault-name primary     # Phase 3
bash ~/.claude/skills/managed-agents-setup/scripts/create-environment.sh primary
bash ~/.claude/skills/managed-agents-setup/scripts/create-agent.sh trades-quote-triage
bash ~/.claude/skills/managed-agents-setup/scripts/create-routine.sh \
  --name trades-quote-triage --cron "0 9 * * *" \
  --prompt "Triage today's quote requests" \
  --repo https://github.com/<org>/<repo> --env-id "$(cat ~/.claude/managed-agents/env-id.txt)"
bash ~/.claude/skills/managed-agents-setup/scripts/smoke-test.sh
bash ~/.claude/skills/managed-agents-setup/scripts/verify.sh             # 5-AC verifier
```

## Reference index - load on demand

| If user asks about | Load |
|---|---|
| "What's in each phase?" | `references/phases/<n>-*.md` |
| "Which MCP servers does it support?" | `references/mcp-servers-catalog.md` |
| "How does the connector setup decide which path?" | `references/connector-strategy.md` (4-tier) |
| "What presets are available?" | `references/business-outcome-presets.json` (40 presets) |
| "How are environments configured?" | `references/environment-templates.json` |
| "Which agent template fits my use case?" | `references/agent-templates.json` |
| "How much will this cost?" | `references/cost-calculator.md` |
| "When/how do scheduled triggers fire?" | `references/routines-cron-cheatsheet.md` |
| "Something's broken" | `references/troubleshooting.md` |
| "What's the handoff one-pager look like?" | `references/handoff-template.md` |

## Hard rules

- **NEVER fabricate facts** - agent IDs, vault IDs, cost figures, URLs come from script output, never invented. Sister to ai-ops-architect's rule.
- **NEVER skip kill switch + cost monitor** - both must be wired before declaring "live". `scripts/killswitch.sh` + `scripts/daily-cost-monitor.py` are mandatory in Phase 7.
- **NEVER use n8n for Luke's own infra** - boundary card from `feedback_no_n8n.md`. Glue is server cron + agents-cc. Exception: explicit ask.
- **NEVER ask the user to type a command** - Playwright + Bash do the work; user only approves prompts.
- **NEVER log secrets** - pasted API keys go to vault via `read -s`, never to stdout / transcript / git.
- **Cap at 1-3 agents per session** - quality over volume. Force selection.
- **Verify Anthropic beta header is current** - check `references/phases/5-agent.md` for the live header value before each agent create.

## Decision matrix (collapsed)

```text
client-facing AI? → managed-agent (this skill)
2+ SaaS, webhook, no reasoning? → /n8n
cadence < 1hr + bash? → server cron
cadence ≥ 1hr + reasoning? → Routine (this skill, Phase 6)
stateful conversation? → managed-agent (this skill)
else → server cron / Routine
```

Full version in `~/.claude/skills/ai-ops-architect/references/runtime-decision-matrix.md`.

## Connector strategy (collapsed)

```text
Tier 1: claude.ai passthrough (claude mcp list shows claude_ai_<service>)
Tier 2: Rube (https://rube.app/mcp) - one OAuth → 500+ apps, default for new
Tier 3: Direct MCP (per service in references/mcp-servers-catalog.md)
Tier 4: Manual API key paste (last resort, masked, vault-stored)
```

Full version: `references/connector-strategy.md`.

## Refusal rules

> The `feedback_*.md` files cited below (and in Hard rules) are optional internal-kit reinforcements; the rules stand alone and this skill doesn't ship them.

- **"Build me 10 agents"** → refuse bulk. Cap 1-3 per session.
- **"Use n8n for Luke's infra"** → refuse, route to server-cron + agents-cc.
- **"Make a Claude bot for me"** → refuse without a north-star outcome. Send to `/ai-ops-architect`.
- **Anything Xero in n8n** → hard refuse, route to server scripts + Xero MCP.
- **"Skip the cost monitor"** → refuse. Mandatory.
- **"Skip the kill switch"** → refuse. Mandatory.
- **"Just give me the deploy instructions, I'll run them later"** → refuse for monitors / watchdogs / alerters per `feedback_deploy_monitors_live.md`. Deploy live to AWS with cron + Telegram wired in this session, or don't ship. Instructions ≠ delivered build.
- **"Hardcode this venue/price/date/name/ID"** without an explicit source → hard refuse per `feedback_never_fabricate_facts.md`. Mark TBC and ask. Inference from past context is never confirmation.
- **Marketing copy that promises refunds / money-back / satisfaction guarantees** → hard refuse per `feedback_no_refund_promises.md`.
- **Marketing copy that promises ongoing support / weekly Q&A / helpdesk** → hard refuse per `feedback_no_support_promises.md`. Use process language, not outcome guarantees.
- **Marketing copy inviting casual drop-ins or free chats** → hard refuse per `feedback_no_drop_in_invites.md`. Every unpaid chat displaces a $1,500 scoping call.
- **Mixing personal finance / banking / tax / bankruptcy with marketing** → hard refuse per `feedback_no_finance_in_marketing.md`.

## State

`~/.claude/managed-agents/` (chmod 700) holds:
- `vault-id.txt`, `env-id.txt` - IDs from Phase 3-4
- `agents/<preset-id>.txt` - agent IDs per preset
- `routines/<agent-id>.txt` - routine IDs
- `ship.log` - append-only deploy trail

`~/.claude/skills/managed-agents-setup/.state/` (chmod 700, gitignored):
- `preflight.json` - last preflight result
- `verify.log` - last verify run

## Architecture (high level)

```
User Mac → ant CLI / SDK / API → Anthropic Platform (Workspace + Agent + Env + Vault + Sessions)
                                                ↓ MCP via vault
                                                Third-party MCP (GHL, Stripe, Notion, Rube, ...)

claude.ai Routines → /fire endpoint or cron schedule → fires a Managed Agent session

Optional: AWS server (server-setup) for sub-hourly cron + webhook glue → managed-agents.sh
```

Full architecture diagram: `SKILL.md.full` (the previous version, kept for reference).

## Pairs with

- `/ai-ops-architect` - orchestrator that picks WHICH agent before delegating here
- `/n8n` - workflow sister skill, called when 2+ SaaS + webhook + no reasoning
- `/schedule (Claude Code built-in scheduling command, no skill dir)` - wrapper for the Routines runtime when cadence ≥ 1hr
- `server-setup` - AWS layer for sub-hourly cron + webhook glue (optional)
