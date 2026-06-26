# Phase 7, Handoff

**Goal:** verify everything works, wire the safety net, hand the user a 1-pager.

**Step 1, smoke test:**
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/smoke-test.sh
```
Checks: ant CLI, anthropic SDK, API key reachable, agents endpoint reachable, vault-id.txt + env-id.txt exist, ≥1 agent ID file.

**Step 2, kill switch (mandatory):**
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/killswitch.sh <agent-id>
```
Pauses the agent without deleting it. Document this in the user's handoff.

**Step 3, daily cost monitor (mandatory):**
```bash
python3 ~/.claude/skills/managed-agents-setup/scripts/daily-cost-monitor.py --install-cron
```
Runs every morning, compares yesterday's spend per agent against the cap, emails or Telegrams if over.

**Step 4, write the 1-pager:**
Use `references/handoff-template.md`. Fill in:
- Agent name, preset id, model, agent id, vault id
- Routine cron + routine id
- Cost cap + kill switch command
- "How to use today" + "What to watch the first week"

Save to `~/.claude/managed-agents/handoff-<date>.md`. User reads it once, files it.

**Step 5, ship.log entry:**
Append one tab-separated line per deploy to `~/.claude/managed-agents/ship.log`:
```
{ISO_DATE}\t{agent_id}\t{preset_id}\t{model}\t{routine_id}\t{cost_estimate}\tship
```

**Done. Stop on success.** No spinners, no recap.
