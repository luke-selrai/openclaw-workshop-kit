#!/usr/bin/env bash
# create-routine.sh — Create a Claude Code routine (cloud scheduled task).
# Requires: RemoteTrigger tool available OR interactive fallback via claude.ai/code/routines.
#
# Usage:
#   create-routine.sh --name NAME --cron "0 23 * * *" --prompt "PROMPT" --repo URL --env-id ENV
#
# Note: This script FORMATS the create body and prints it. RemoteTrigger API is
# not exposed via a public REST endpoint as of 2026-04-23 — the create call must
# be made from within a Claude Code session that has RemoteTrigger loaded, OR via
# the web UI at claude.ai/code/routines.
#
# When run, this script prints the JSON body you can paste into:
#   - A Claude Code prompt: "Create a routine with: <paste>"
#   - The RemoteTrigger tool call directly
set -euo pipefail

# Per-client namespacing: --client=<slug> writes IDs under ~/.claude/managed-agents/<slug>/
# (P0.5 fix — multi-tenant agency was overwriting state per client)
CLIENT_SLUG="${CLIENT_SLUG:-}"
PARSED=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --client) CLIENT_SLUG="$2"; shift 2 ;;
        --client=*) CLIENT_SLUG="${1#--client=}"; shift ;;
        *) PARSED+=("$1"); shift ;;
    esac
done
set -- "${PARSED[@]}"
MA_BASE="${HOME}/.claude/managed-agents${CLIENT_SLUG:+/$CLIENT_SLUG}"
mkdir -p "$MA_BASE"
# H4: honor --client namespacing — state goes under MA_BASE, not a hardcoded path.
STATE_DIR="$MA_BASE"

NAME=""
CRON=""
PROMPT=""
REPO=""
ENV_ID=""
RUN_ONCE_AT=""
TRIG_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) NAME="$2"; shift 2 ;;
    --cron) CRON="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --env-id) ENV_ID="$2"; shift 2 ;;
    --run-once-at) RUN_ONCE_AT="$2"; shift 2 ;;
    # M2: if the caller already has the trigger ID returned by RemoteTrigger /
    # the web UI, the script records it itself instead of telling the user to
    # hand-run `echo ... > ...`. We never fabricate a trigger ID.
    --trig-id) TRIG_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$PROMPT" ] || [ -z "$REPO" ] || [ -z "$ENV_ID" ]; then
  echo "Usage: create-routine.sh --name N --cron CRON --prompt P --repo URL --env-id ENV [--run-once-at ISO]" >&2
  exit 2
fi
if [ -z "$CRON" ] && [ -z "$RUN_ONCE_AT" ]; then
  echo "[fatal] --cron or --run-once-at required" >&2
  exit 2
fi

# Generate UUIDv4 for event
UUID=$(python3 -c "import uuid; print(uuid.uuid4())")

# NOTE (L2): cron_expression is interpreted in UTC by the routines scheduler —
# convert local times to UTC before passing --cron.

# M1: build the ENTIRE create body in Python via json.dumps, passing every
# field by argv so nothing is interpolated raw into the JSON. This also covers
# the L1 empty-array guard: an empty --repo yields an empty sources array
# rather than a fabricated {"url": ""} source.
BODY=$(python3 - "$NAME" "$RUN_ONCE_AT" "$CRON" "$ENV_ID" "$REPO" "$UUID" "$PROMPT" <<'PY'
import json, sys
name, run_once_at, cron, env_id, repo, uuid_, prompt = sys.argv[1:8]

body = {
    "name": name,
    "enabled": True,
    "job_config": {
        "ccr": {
            "environment_id": env_id,
            "session_context": {
                "model": "claude-sonnet-4-6",
                # L1: only include a source when a repo URL was actually given.
                "sources": (
                    [{"git_repository": {"url": repo}}] if repo else []
                ),
                "allowed_tools": [
                    "Bash", "Read", "Write", "Edit", "Glob", "Grep", "Task"
                ],
            },
            "events": [{
                "data": {
                    "uuid": uuid_,
                    "session_id": "",
                    "type": "user",
                    "parent_tool_use_id": None,
                    "message": {"content": prompt, "role": "user"},
                }
            }],
        }
    },
}

# Schedule: prefer an explicit one-time run, else the cron expression.
if run_once_at:
    body["run_once_at"] = run_once_at
elif cron:
    body["cron_expression"] = cron

print(json.dumps(body, indent=2))
PY
)
printf '%s\n' "$BODY"

# M2: when the caller passes the real trigger ID back in, record it ourselves
# (creating the routines dir first) instead of leaving it as a manual step.
if [ -n "$TRIG_ID" ]; then
  mkdir -p "$STATE_DIR/routines"
  printf '%s\n' "$TRIG_ID" > "$STATE_DIR/routines/$NAME.trig"
  echo "[ok] Saved trigger ID to $STATE_DIR/routines/$NAME.trig" >&2
fi

cat <<NEXT >&2

[next] To create this routine, either:
  A) Inside a Claude Code session with RemoteTrigger: call RemoteTrigger.create(body={...})
  B) Paste the JSON above into https://claude.ai/code/routines (New routine > Advanced)
  C) Ask Claude: "Create a routine with the following config: <paste JSON>"

After creation, record the trigger ID returned by the API by re-running with:
  create-routine.sh ... --trig-id trig_...
(this writes $STATE_DIR/routines/$NAME.trig for you)

To fire it manually:
  bash ~/.claude/skills/managed-agents-setup/scripts/fire-routine.sh trig_...
NEXT
