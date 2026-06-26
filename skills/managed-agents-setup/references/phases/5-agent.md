# Phase 5, Create the agent

**Goal:** create a Managed Agent from a preset and bind it to the vault + environment.

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/create-agent.sh <preset-id>
```

Presets live in `references/business-outcome-presets.json` (canonical, 40 presets across 10 verticals). Examples:
- `trades-quote-triage`
- `coach-dm-responder`
- `real-estate-lead-manager`
- `consultant-proposal-drafter`
- `agency-client-onboarding`

**Each preset specifies:**
- `model`, Haiku 4.5 (high volume), Sonnet 4.6 (nuance), Opus 4.7 (long context)
- `system_prompt`, full prompt with refusal rules
- `mcp_servers`, Rube default, direct MCPs where needed
- `tools`, bash / file / web / mcp toolset selection
- `industries`, vertical tags
- `estimated_cost_per_month`, dollar guidance

**Anthropic beta header:** the script reads the current value from `references/cost-calculator.md` (kept in sync). As of 2026-04-23 it was `managed-agents-2026-04-01`. Verify the live header before each major release; bump via PR if Anthropic ships a new dated version.

Agent ID written to `~/.claude/managed-agents/agents/<preset-id>.txt`.
