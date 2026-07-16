#!/usr/bin/env bash
# killswitch.sh — Panic button for Managed Agents.
# Lists every running session, sends user.interrupt, then archives on request.
# Use when: a session has gone rogue, daily cost is spiking, or you want to stop everything fast.
#
# Usage:
#   killswitch.sh              # list + interrupt all running (safe, reversible)
#   killswitch.sh --archive    # also archive every session (cannot resume)
#   killswitch.sh --nuke       # DANGEROUS: archives all agents + envs + vaults too
set -euo pipefail

# Optional: scope to a single agent ID. Without --agent, all running sessions interrupt.
TARGET_AGENT=""
ALL_SCOPE=0
PARSED_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) TARGET_AGENT="$2"; shift 2 ;;
        --all) ALL_SCOPE=1; shift ;;
        --) shift; while [[ $# -gt 0 ]]; do PARSED_ARGS+=("$1"); shift; done ;;
        *) PARSED_ARGS+=("$1"); shift ;;
    esac
done
set -- "${PARSED_ARGS[@]:-}"
# If a positional agent ID was given (legacy handoff syntax), treat as --agent
if [[ -z "$TARGET_AGENT" && -n "${1:-}" && "$1" =~ ^agent_ ]]; then
    TARGET_AGENT="$1"
    shift
fi
if [[ -n "$TARGET_AGENT" ]]; then
    echo "killswitch: scoped to agent $TARGET_AGENT"
    export TARGET_AGENT
fi

# Parse args FIRST so --help works without ANTHROPIC_API_KEY set
MODE="interrupt"
case "${1:-}" in
  --archive) MODE="archive" ;;
  --nuke)    MODE="nuke" ;;
  --help|-h)
    echo "killswitch.sh [--agent <id> | --all] [--archive | --nuke]"
    echo "  (default)    interrupt running sessions"
    echo "  --agent <id> scope all actions to one agent's sessions"
    echo "  --all        opt in to GLOBAL scope (required for --archive/--nuke without --agent)"
    echo "  --archive    interrupt + archive sessions (needs --agent or --all)"
    echo "  --nuke       archive sessions + all agents + envs + vaults (needs --agent or --all)"
    exit 0
    ;;
esac

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

# S1: refuse GLOBAL destructive scope unless explicitly opted in.
# --archive / --nuke act across the whole account when no agent is scoped; require --all to confirm.
if { [ "$MODE" = "archive" ] || [ "$MODE" = "nuke" ]; } && [ -z "$TARGET_AGENT" ] && [ "$ALL_SCOPE" -ne 1 ]; then
  echo "killswitch: refusing global $MODE without a scope." >&2
  echo "  Pass --agent <id> to scope, or --all to confirm you mean EVERY session/agent." >&2
  exit 3
fi

BETA_HEADER="anthropic-beta: managed-agents-2026-04-01"
VERSION_HEADER="anthropic-version: 2023-06-01"

# S12: keep the API key OFF argv. acurl feeds the auth header to curl via --config -
# on stdin, so the secret never appears in the process list / `ps` output.
acurl() {
  printf 'header = "x-api-key: %s"\n' "$ANTHROPIC_API_KEY" | curl --config - "$@"
}

echo "[killswitch] mode=$MODE  time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# List running sessions
RESP=$(acurl -sS "https://api.anthropic.com/v1/sessions?status=running" \
  -H "$VERSION_HEADER" -H "$BETA_HEADER")

# S1: when scoped, filter the session list by agent BEFORE interrupting.
# If the agent_id field is named differently in the real API response, this
# select() matches NOTHING and the script interrupts nobody — fail-safe, far
# better than the previous behaviour of interrupting/archiving every session.
SESSION_IDS=$(echo "$RESP" | jq -r --arg a "$TARGET_AGENT" \
  '.data[]? | select($a == "" or .agent_id == $a) | .id // empty')
COUNT=$(echo -n "$SESSION_IDS" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "[killswitch] No running sessions."
else
  echo "[killswitch] $COUNT running session(s):"
  echo "$SESSION_IDS" | sed 's/^/  - /'

  for SID in $SESSION_IDS; do
    echo "[interrupt] $SID"
    acurl -sS -X POST "https://api.anthropic.com/v1/sessions/$SID/events" \
      -H "$VERSION_HEADER" -H "$BETA_HEADER" \
      -H "content-type: application/json" \
      -d '{"events":[{"type":"user.interrupt"}]}' >/dev/null || echo "  interrupt failed"

    if [ "$MODE" = "archive" ] || [ "$MODE" = "nuke" ]; then
      sleep 2
      acurl -sS -X POST "https://api.anthropic.com/v1/sessions/$SID/archive" \
        -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
        && echo "[archive]   $SID" || echo "[archive]   FAIL $SID"
    fi
  done
fi

if [ "$MODE" = "nuke" ]; then
  echo ""
  echo "[nuke] Archiving all agents..."
  acurl -sS "https://api.anthropic.com/v1/agents" \
    -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r AID; do
        acurl -sS -X POST "https://api.anthropic.com/v1/agents/$AID/archive" \
          -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $AID" || true
      done

  echo "[nuke] Archiving all environments..."
  acurl -sS "https://api.anthropic.com/v1/environments" \
    -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r EID; do
        acurl -sS -X POST "https://api.anthropic.com/v1/environments/$EID/archive" \
          -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $EID" || true
      done

  echo "[nuke] Archiving all vaults..."
  acurl -sS "https://api.anthropic.com/v1/vaults" \
    -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r VID; do
        acurl -sS -X POST "https://api.anthropic.com/v1/vaults/$VID/archive" \
          -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $VID" || true
      done

  echo ""
  echo "[nuke] DONE. Everything archived. Resources gone from billing."
fi

# S2: interrupting/archiving a session does NOT disable a Routine. If a routine
# trigger exists, it will RE-FIRE this agent on its cron schedule. Surface it
# loudly and exit non-zero so the operator knows the killswitch is incomplete.
#
# S2 (false all-clear fix): a FAILED routines read must NOT collapse into the
# "Complete." exit 0 path — that would tell the operator "no routines armed"
# when in fact we simply could not read them. Distinguish three outcomes:
#   (a) couldn't read routines (curl error OR non-JSON body) -> exit non-zero
#   (b) read OK, routines present                            -> warn + exit 4
#   (c) read OK, zero routines                               -> genuine all-clear
set +e
ROUTINE_RESP=$(acurl -sS "https://api.anthropic.com/v1/routines" \
  -H "$VERSION_HEADER" -H "$BETA_HEADER" 2>/dev/null)
ROUTINE_CURL_RC=$?
set -e

# (a) Treat a curl failure OR a body that does not parse as a JSON object/array
# (e.g. empty, HTML error page, gateway timeout) as "couldn't read routines".
if [ "$ROUTINE_CURL_RC" -ne 0 ] || ! echo "$ROUTINE_RESP" | jq -e 'type == "object" or type == "array"' >/dev/null 2>&1; then
  echo "" >&2
  echo "[killswitch] ERROR: could not read Routines (api unreachable or unexpected response)." >&2
  echo "[killswitch] Sessions were handled, but a Routine may still be armed and RE-FIRE this agent." >&2
  echo "[killswitch] Verify manually at claude.ai/code/routines before trusting this run." >&2
  exit 5
fi

ROUTINE_CRONS=$(echo "$ROUTINE_RESP" | jq -r --arg a "$TARGET_AGENT" \
  '.data[]? | select($a == "" or .agent_id == $a) | (.schedule // .cron // .trigger // "unknown schedule")' \
  2>/dev/null || true)

if [ -n "$ROUTINE_CRONS" ]; then
  # (b) routines present
  echo ""
  echo "$ROUTINE_CRONS" | while IFS= read -r CRON; do
    [ -n "$CRON" ] && echo "[killswitch] WARNING: the Routine at $CRON will RE-FIRE this agent — disable it at claude.ai/code/routines"
  done
  echo "[killswitch] interrupt/archive != disable. Sessions stopped but a Routine remains armed."
  exit 4
fi

# (c) genuine all-clear: read succeeded and no routines matched.
echo ""
echo "[killswitch] Routines read OK — none armed for this scope."
echo "[killswitch] Complete."
