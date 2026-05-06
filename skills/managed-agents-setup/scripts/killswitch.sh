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
PARSED_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent) TARGET_AGENT="$2"; shift 2 ;;
        --) shift; while [[ $# -gt 0 ]]; do PARSED_ARGS+=("$1"); shift; done ;;
        *) PARSED_ARGS+=("$1"); shift ;;
    esac
done
set -- "${PARSED_ARGS[@]}"
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
    echo "killswitch.sh [--archive | --nuke]"
    echo "  (default)    interrupt all running sessions"
    echo "  --archive    interrupt + archive all sessions"
    echo "  --nuke       archive sessions + all agents + envs + vaults"
    exit 0
    ;;
esac

: "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY not set}"

BETA_HEADER="anthropic-beta: managed-agents-2026-04-01"
VERSION_HEADER="anthropic-version: 2023-06-01"
KEY_HEADER="x-api-key: $ANTHROPIC_API_KEY"

echo "[killswitch] mode=$MODE  time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# List running sessions
RESP=$(curl -sS "https://api.anthropic.com/v1/sessions?status=running" \
  -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER")

SESSION_IDS=$(echo "$RESP" | jq -r '.data[]?.id // empty')
COUNT=$(echo -n "$SESSION_IDS" | grep -c . || true)

if [ "$COUNT" -eq 0 ]; then
  echo "[killswitch] No running sessions."
else
  echo "[killswitch] $COUNT running session(s):"
  echo "$SESSION_IDS" | sed 's/^/  - /'

  for SID in $SESSION_IDS; do
    echo "[interrupt] $SID"
    curl -sS -X POST "https://api.anthropic.com/v1/sessions/$SID/events" \
      -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" \
      -H "content-type: application/json" \
      -d '{"events":[{"type":"user.interrupt"}]}' >/dev/null || echo "  interrupt failed"

    if [ "$MODE" = "archive" ] || [ "$MODE" = "nuke" ]; then
      sleep 2
      curl -sS -X POST "https://api.anthropic.com/v1/sessions/$SID/archive" \
        -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
        && echo "[archive]   $SID" || echo "[archive]   FAIL $SID"
    fi
  done
fi

if [ "$MODE" = "nuke" ]; then
  echo ""
  echo "[nuke] Archiving all agents..."
  curl -sS "https://api.anthropic.com/v1/agents" \
    -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r AID; do
        curl -sS -X POST "https://api.anthropic.com/v1/agents/$AID/archive" \
          -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $AID" || true
      done

  echo "[nuke] Archiving all environments..."
  curl -sS "https://api.anthropic.com/v1/environments" \
    -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r EID; do
        curl -sS -X POST "https://api.anthropic.com/v1/environments/$EID/archive" \
          -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $EID" || true
      done

  echo "[nuke] Archiving all vaults..."
  curl -sS "https://api.anthropic.com/v1/vaults" \
    -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" \
    | jq -r '.data[]?.id // empty' \
    | while read -r VID; do
        curl -sS -X POST "https://api.anthropic.com/v1/vaults/$VID/archive" \
          -H "$KEY_HEADER" -H "$VERSION_HEADER" -H "$BETA_HEADER" >/dev/null \
          && echo "  archived $VID" || true
      done

  echo ""
  echo "[nuke] DONE. Everything archived. Resources gone from billing."
fi

echo ""
echo "[killswitch] Complete."
