# Phase 7 - Handoff

**Goal:** verify everything works, wire the safety net, hand the user a 1-pager.

**Step 1 - smoke test:**
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/smoke-test.sh
```
Checks: ant CLI, anthropic SDK, API key reachable, agents endpoint reachable, vault-id.txt + env-id.txt exist, ≥1 agent ID file.

**Step 2 - kill switch (mandatory):**
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/killswitch.sh --agent <agent-id>
```
Interrupts all **running sessions** scoped to that agent (reversible; add `--archive` to also archive them). It does **not** delete the agent. Important: interrupting/archiving sessions does **not** disable a Routine - if a routine trigger exists it will re-fire the agent on its next cron. The killswitch warns when it detects an armed routine; you must disable it separately at `claude.ai/code/routines`. Document both steps in the user's handoff.

**Step 3 - daily cost monitor (mandatory):**
Schedule the monitor as a Routine (there is **no** `--install-cron` flag; the script does not self-schedule):
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/create-routine.sh \
  --name "daily-cost-monitor" \
  --cron "0 22 * * *" \
  --prompt "python3 ~/.claude/skills/managed-agents-setup/scripts/daily-cost-monitor.py" \
  --repo "https://github.com/your-org/your-repo" \
  --env-id "$(cat ~/.claude/managed-agents/env-id.txt)"
```
Runs every morning and Telegrams a report. Note: the report is an **estimated session COUNT**, not a verified dollar figure - the spend cap is shown for context only and does not by itself trip a killswitch (a webhook fires only if a real, verified cost exceeds the cap and `KILLSWITCH_WEBHOOK_URL` is set).

**Step 4 - write the 1-pager:**
Use `references/handoff-template.md`. Fill in:
- Agent name, preset id, model, agent id, vault id
- Routine cron + routine id
- Cost cap + kill switch command
- "How to use today" + "What to watch the first week"

Save to `~/.claude/managed-agents/handoff-<date>.md`. User reads it once, files it.

**Step 5 - ship.log entry:**
Append one tab-separated line per deploy to `~/.claude/managed-agents/ship.log`:
```
{ISO_DATE}\t{agent_id}\t{preset_id}\t{model}\t{routine_id}\t{cost_estimate}\tship
```

**Done. Stop on success.** No spinners, no recap.
