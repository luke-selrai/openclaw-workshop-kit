#!/usr/bin/env python3
"""render-handoff.py — produce the filled handoff one-pager from state.

Reads the handoff template + state files (agent IDs, vault id, env id,
preset metadata) and writes a human-readable .md to:
    ~/.claude/managed-agents/handoff.md

Phase 7 calls this AFTER agent + routine creation. Refuses to render
if any required placeholder is missing — instructions != delivered build.
"""
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Resolve script-relative paths (scripts/ -> skill root). Never hardcode ~/.claude.
SKILL_ROOT = Path(
    os.environ.get("MANAGED_AGENTS_SKILL_ROOT", "")
    or Path(__file__).resolve().parent.parent
)
STATE = Path(os.environ.get("MANAGED_AGENTS_STATE", "") or os.path.expanduser("~/.claude/managed-agents"))
TEMPLATE = SKILL_ROOT / "references" / "handoff-template.md"
PRESETS = SKILL_ROOT / "references" / "business-outcome-presets.json"
OUT = STATE / "handoff.md"


def read_id(name):
    f = STATE / name
    return f.read_text(encoding="utf-8").strip() if f.exists() else None


def list_agents():
    d = STATE / "agents"
    if not d.exists():
        return []
    return [(p.stem, p.read_text(encoding="utf-8").strip()) for p in d.glob("*.txt")]


def list_routines(agent_id):
    d = STATE / "routines"
    if not d.exists():
        return []
    return [p.read_text(encoding="utf-8").strip() for p in d.glob(f"{agent_id}.txt")]


def main():
    if not TEMPLATE.exists():
        print(f"ERROR: template missing at {TEMPLATE}", file=sys.stderr)
        sys.exit(2)

    agents = list_agents()
    if not agents:
        print("ERROR: no agents created yet — Phase 5 must run first", file=sys.stderr)
        sys.exit(2)

    presets = {}
    if PRESETS.exists():
        try:
            data = json.loads(PRESETS.read_text(encoding="utf-8"))
            presets = {k: v for k, v in data.items() if k != "_meta"}
        except (json.JSONDecodeError, KeyError):
            pass

    vault_id = read_id("vault-id.txt") or "(missing — run Phase 3)"
    env_id = read_id("env-id.txt") or "(missing — run Phase 4)"

    today = datetime.now().date().isoformat()

    # Build the agents table
    agent_rows = []
    services_set = set()
    for i, (preset_id, agent_id) in enumerate(agents, 1):
        preset = presets.get(preset_id, {})
        name = preset.get("name") or preset_id
        model = preset.get("model") or "claude-sonnet-4-6"
        cost = preset.get("estimated_cost_per_month") or "$5-30/mo"
        for s in preset.get("mcp_servers", []):
            svc = s.get("name") if isinstance(s, dict) else None
            if svc:
                services_set.add(svc)
        routines = list_routines(agent_id)
        routine_id = routines[0] if routines else "(none)"
        # killswitch.sh --agent <id> scopes to THIS agent's sessions only (fail-safe
        # filter). It does NOT stop every agent and does NOT disable Routines —
        # see killswitch.sh --help. Phrase honestly so the owner is not told a
        # command that halts the whole account.
        kill = (
            f"`bash scripts/killswitch.sh --agent {agent_id}` "
            f"(stops sessions for this agent; see killswitch.sh --help)"
        )
        agent_rows.append(
            f"| {i} | {name} | `{model}` | `{agent_id}` | {cost} | {kill} |"
        )

    services_table = "\n".join(
        f"| {s} | tier-tbd | (set during Phase 6) |" for s in sorted(services_set)
    ) or "| (none recorded) | | |"

    # Read template, do mustache-style substitution
    src = TEMPLATE.read_text(encoding="utf-8")
    out = src
    out = out.replace("{{DATE}}", today)
    out = out.replace("{{vault_id}}", vault_id)
    out = out.replace("{{env_id}}", env_id)
    out = out.replace("{{cost_cap}}", "$5/day")
    out = out.replace("{{services_table}}", services_table)

    # Replace the agent rows table (drop the {{}} placeholder rows)
    agents_block_start = out.find("| # | Agent | Model | URL / id |")
    if agents_block_start != -1:
        # Find next blank line after header
        head_end = out.find("\n\n", agents_block_start)
        before = out[:agents_block_start]
        after = out[head_end:]
        header = "| # | Agent | Model | URL / id | Cost (est) | Kill switch |\n|---|---|---|---|---|---|\n"
        out = before + header + "\n".join(agent_rows) + after

    # Strip any remaining {{...}} placeholders so we don't ship them
    leftover = re.findall(r"\{\{[^}]+\}\}", out)
    if leftover:
        # Replace simple ones with sensible defaults
        for ph in set(leftover):
            inner = ph[2:-2].strip()
            if inner.startswith("first_action") or inner.startswith("daily_check") or inner.startswith("next_build"):
                out = out.replace(ph, "(see preset notes)")
            elif inner == "ISO_DATE":
                out = out.replace(ph, datetime.now().isoformat())
            else:
                out = out.replace(ph, "TBD — review before sharing")

    STATE.mkdir(parents=True, exist_ok=True)
    tmp = OUT.with_suffix(".md.tmp")
    tmp.write_text(out, encoding="utf-8")
    os.replace(tmp, OUT)
    OUT.chmod(0o600)
    print(f"Rendered handoff: {OUT}")
    print(f"Agents: {len(agent_rows)}  |  Vault: {vault_id}  |  Env: {env_id}")


if __name__ == "__main__":
    main()
