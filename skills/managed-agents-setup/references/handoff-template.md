# Handoff template (Phase 7 output)

> The skill ends each session by writing this one-pager. It's the user's reference for what was deployed, how it runs, what it costs, and how to kill it. Append-only at `~/.claude/managed-agents/ship.log` records the same.

```markdown
# Your managed agent - built {{DATE}}

## What's running

| # | Agent | Model | URL / id | Cost (est) | Kill switch |
|---|---|---|---|---|---|
| 1 | {{name_1}} | {{model_1}} | {{agent_id_1}} | {{cost_1}}/mo | `bash scripts/killswitch.sh --agent {{agent_id_1}}` |
| 2 | {{name_2}} | {{model_2}} | {{agent_id_2}} | {{cost_2}}/mo | `bash scripts/killswitch.sh --agent {{agent_id_2}}` |

> The kill switch interrupts the **running sessions** for that agent - it does not disable its Routine. If the agent has a scheduled Routine it will re-fire on its next cron; disable it separately at `claude.ai/code/routines`. The killswitch warns when it detects an armed routine.

## Routines (scheduled triggers)

| Agent | Cron | Routine ID | Last fire |
|---|---|---|---|
| {{agent_1}} | {{cron_1}} | {{routine_id_1}} | (none yet) |

## How to use it (today)

- Agent 1: {{first_action_1}}
- Agent 2: {{first_action_2}}

## What to watch for the first week

- {{daily_check_1}}
- {{daily_check_2}}
- The morning report from `daily-cost-monitor.py` (scheduled as a Routine) - it reports an estimated **session count**, not verified spend; a real over-cap alert fires only against a verified cost figure

## Connectors connected

| Service | Tier | How |
|---|---|---|
{{services_table}}

Vault ID: `{{vault_id}}`  
Environment ID: `{{env_id}}`

## Where things live

- Agent IDs: `~/.claude/managed-agents/agents/<preset>.txt`
- Routine trigger IDs: `~/.claude/managed-agents/routines/<name>.trig` (keyed by the routine `--name`)
- Vault ID: `~/.claude/managed-agents/vault-id.txt`
- Env ID: `~/.claude/managed-agents/env-id.txt`
- Per-build secrets: stored in Anthropic Vault (never in plaintext)
- Ship log: `~/.claude/managed-agents/ship.log` (tab-separated, append-only)

## If something breaks

1. Re-run `/managed-agents-setup` - pick "diagnose existing agent"
2. Use the kill switch above to interrupt the offender's running sessions without affecting the others (then disable its Routine separately at `claude.ai/code/routines` - interrupting sessions does not disable the schedule):
   - `bash ~/.claude/skills/managed-agents-setup/scripts/killswitch.sh --agent <agent-id>`
3. Check `daily-cost-monitor.py` output for session-count anomalies (it reports an estimated session count, not verified spend):
   - `python3 ~/.claude/skills/managed-agents-setup/scripts/daily-cost-monitor.py`
4. Worst case: `claude mcp remove <service>` removes a misbehaving connector cleanly

## Cost guardrails (mandatory)

- **Cost cap**: $5/day starter, scale based on usage. Set via `DAILY_SPEND_CAP_USD` (the cap is compared only against a verified cost figure, never the session count).
- **How to check cost**:
  - Local: `python3 ~/.claude/skills/managed-agents-setup/scripts/daily-cost-monitor.py` - reports an estimated **session count**, not verified spend
  - Authoritative: Anthropic Usage and Cost API - `GET /v1/organizations/cost_report` returns service-level USD breakdown by workspace/description (verified 2026, see <https://platform.claude.com/docs/en/build-with-claude/usage-cost-api>)
- **If cost spikes**: interrupt the offender's sessions immediately - `bash ~/.claude/skills/managed-agents-setup/scripts/killswitch.sh --agent <agent-id>` - then disable its Routine at `claude.ai/code/routines` so it doesn't re-fire. Re-enable later via the Anthropic console.
- **Daily cost monitor**: scheduled as a Routine via `create-routine.sh` (the script has no self-install cron); reports an estimated session count and only fires a real over-cap alert against a verified cost figure.

## Advanced observability (optional, for 3+ agents)

The built-in monitor is fine for 1-3 agents. If you're running more or want graphs:

- **claude-code-otel** (<https://github.com/ColeMurray/claude-code-otel>) - full OTEL stack: Grafana dashboards, Prometheus metrics, distributed tracing for Claude Code usage and cost.
- **agent-observability** (<https://github.com/nexus-labs-automation/agent-observability>) - Claude Code plugin specifically for multi-agent fleets: LLM tracing, tool calls, cost tracking with per-agent attribution.

Pick whichever integrates with your existing dashboarding tooling. The local monitor + cost_report API is enough for most workshop attendees - only step up if you have multi-agent orchestration in production.

## Next session

Suggested when you have 30+ minutes:
- {{next_build_1}}
- {{next_build_2}}

Or come back any time and run `/ai-ops-architect` for a fresh audit against your current state, or `/skills-discovery` to see what other skills you can use with this stack.
```

## How the skill fills it

- `{{DATE}}` from `date "+%Y-%m-%d"`
- Agent names + IDs from `~/.claude/managed-agents/agents/*.txt`
- Routines from `~/.claude/managed-agents/routines/*.txt`
- Models from `references/business-outcome-presets.json` lookup by preset id
- Costs from preset `estimated_cost_per_month` field
- Connector tier decisions logged by `connector-wizard.sh` during Phase 6 of the orchestrator flow

## Append to ship.log

After writing the handoff, append one line per agent:

```
{{ISO_DATE}}\t{{agent_id}}\t{{preset_id}}\t{{model}}\t{{routine_id}}\t{{cost_estimate}}\tship
```

Format: tab-separated, one line per deploy, never edited (audit trail).

## Pairs with the ai-ops-architect handoff

If the agent was built via `/ai-ops-architect`, the orchestrator generates its own combined handoff (workflows + agents in one table). This per-agent handoff is the slice for managed-agents only and rolls up into the orchestrator's view.
