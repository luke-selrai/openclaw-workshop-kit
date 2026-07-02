# Phase 6 - Schedule via Routine

**Goal:** wire the agent to a `claude.ai/code/routines` schedule so it fires on cron.

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/create-routine.sh \
  --name "trades-quote-triage-daily" \
  --cron "0 9 * * *" \
  --prompt "Run the trades quote triage pass" \
  --repo "https://github.com/your-org/your-repo" \
  --env-id "$(cat ~/.claude/managed-agents/env-id.txt)"
```

The script takes **named flags** (`--name --cron --prompt --repo --env-id`); there is **no** positional agent-id argument. The agent it runs is the one configured in the routine's repo/env context, not passed on the CLI. `--cron` is UTC (`0 9 * * *` = 9am UTC daily). The script does not call the API directly - it formats the routine JSON and prints it for you to paste into `claude.ai/code/routines`, the RemoteTrigger tool, or a Claude prompt. Pass `--trig-id trig_...` back in afterwards to record the returned trigger ID. Use `--run-once-at` (RFC3339 UTC) instead of `--cron` for a one-shot.

**Cron rules** (full cheatsheet: `references/routines-cron-cheatsheet.md`):
- Cadence ≥ 1 hour - Routines is correct
- Cadence < 1 hour - use server-cron + agents-cc helper
- All times UTC. Anthropic does not auto-localize.
- Max 50 routines per workspace; if exceeded, consolidate by widening the agent's responsibility

**Manual fire** (for testing without waiting for cron):
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/fire-routine.sh \
  "$(cat ~/.claude/managed-agents/routines/<routine-id>.txt)"
```

Trigger ID is recorded (when you pass `--trig-id`) to `~/.claude/managed-agents/routines/<name>.trig`, keyed by the `--name` you gave, not an agent id.
