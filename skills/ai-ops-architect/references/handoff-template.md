# Handoff template (Phase 7 output)

> The skill ends each session by writing this one-pager. It's the user's
> reference for what was deployed, how it runs, what it costs, and how to kill
> it if it misbehaves. Append-only at `.state/ship.log` records the same.

```markdown
# Your AI ops setup - built {{DATE}}

## What's running

| # | Build | Runtime | URL / handle | Cost (est) | Kill switch |
|---|---|---|---|---|---|
| 1 | {{name_1}} | {{runtime_1}} | {{url_1}} | {{cost_1}}/mo | {{kill_1}} |
| 2 | {{name_2}} | {{runtime_2}} | {{url_2}} | {{cost_2}}/mo | {{kill_2}} |
| 3 | {{name_3}} | {{runtime_3}} | {{url_3}} | {{cost_3}}/mo | {{kill_3}} |

## How to use it (today)

- Build 1: {{first_action_1}}
- Build 2: {{first_action_2}}
- Build 3: {{first_action_3}}

## What to watch for the first week

- {{daily_check_1}}
- {{daily_check_2}}
- Any failure email from `daily-cost-monitor` - runs every morning, alerts if any build crosses {{cost_cap}}/day

## Connectors connected

| Service | Tier | How |
|---|---|---|
{{services_table}}

## Where things live

- Audit: `~/.claude/skills/ai-ops-architect/.state/audit-output.md`
- Selected builds: `~/.claude/skills/ai-ops-architect/.state/selected-builds.json`
- Per-build secrets: `~/.claude/skills/ai-ops-architect/.state/secrets/<service>.env` (chmod 600)
- Ship log: `~/.claude/skills/ai-ops-architect/.state/ship.log`

## If something breaks

1. Re-run `/ai-ops-architect` and pick "diagnose existing build"
2. Check the kill switch in the table above - it stops the offender without affecting the others
3. Check daily-cost-monitor for spend anomalies
4. Worst case: `claude mcp remove <service>` removes the connector cleanly

## Next session

Suggested when you have 30+ minutes:
- {{next_build_1}}
- {{next_build_2}}

Or come back any time and run `/ai-ops-architect` for a fresh audit against your current state.
```

## How the skill fills it

- `{{DATE}}` from `date "+%Y-%m-%d"`
- Builds from `.state/selected-builds.json` after each successful deploy
- URLs from each child skill's deploy output (`/n8n` returns webhook URL, `/managed-agents-setup` returns agent_id)
- Costs from preset `estimated_cost_per_month` field, or n8n template's value field
- Kill switches:
  - n8n: "Deactivate workflow in the n8n.cloud UI"
  - Managed agent: "Pause in the claude.ai/code/agents UI", or run the managed-agents-setup skill's `scripts/killswitch.sh <agent-id>`
  - Routine: "Disable in claude.ai/code/routines UI"
  - Server cron: comment out the line in crontab

## Append to ship.log

After writing the handoff, append one line per build:

```
{{ISO_DATE}}\t{{build_id}}\t{{runtime}}\t{{url}}\t{{cost_estimate}}\tship
```

Format: tab-separated, one line per deploy, never edited (audit trail).
