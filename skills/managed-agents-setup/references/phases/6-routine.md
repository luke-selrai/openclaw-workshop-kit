# Phase 6 — Schedule via Routine

**Goal:** wire the agent to a `claude.ai/code/routines` schedule so it fires on cron.

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/create-routine.sh \
  "$(cat ~/.claude/managed-agents/agents/<preset-id>.txt)" \
  "0 9 * * *"     # 9am UTC daily
```

**Cron rules** (full cheatsheet: `references/routines-cron-cheatsheet.md`):
- Cadence ≥ 1 hour — Routines is correct
- Cadence < 1 hour — use server-cron + agents-cc helper
- All times UTC. Anthropic does not auto-localize.
- Max 50 routines per workspace; if exceeded, consolidate by widening the agent's responsibility

**Manual fire** (for testing without waiting for cron):
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/fire-routine.sh \
  "$(cat ~/.claude/managed-agents/routines/<routine-id>.txt)"
```

Routine ID written to `~/.claude/managed-agents/routines/<agent-id>.txt`.
