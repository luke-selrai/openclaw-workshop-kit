#!/usr/bin/env bash
# verify-well-known.sh — Re-validate the PandaDoc MCP OAuth metadata shape.
#
# The pandadoc-connector SKILL.md Step 3 narration depends on PandaDoc
# publishing standards-compliant OAuth authorization-server metadata at
# mcp.pandadoc.com/.well-known/oauth-authorization-server. This script
# re-fetches that document and structurally validates it against the
# recorded shape captured 2026-06-05 so the SKILL's claims can be
# re-validated on a schedule.
#
# Captured PandaDoc-specific notes (2026-06-05):
#   - PandaDoc serves authorization-server at the BASE host
#     (https://mcp.pandadoc.com/.well-known/...) — NOT under /v1/ like
#     the MCP endpoint itself (https://mcp.pandadoc.com/v1/mcp).
#   - PandaDoc does NOT publish RFC 9728 oauth-protected-resource
#     metadata. Absence of that document is EXPECTED (recorded as PASS,
#     not drift).
#   - PandaDoc advertises Dynamic Client Registration
#     (registration_endpoint) and coarse-grained scopes
#     (read, read+write) — only 2 scopes, vs Canva's ~15.
#
# Exit codes:
#   0   — all checks pass; shape matches the recorded contract
#   1   — soft drift (e.g. protected-resource newly appears, scopes shift,
#         optional field missing); SKILL still works
#   2   — hard drift (authorization-server unreachable, required field
#         missing, or value drift on issuer / authorization_endpoint /
#         token_endpoint); the SKILL's Step 3 claim is no longer
#         accurate
#
# Dependencies: curl, jq.
#
# Usage:
#   ./verify-well-known.sh                # human-readable
#   ./verify-well-known.sh --json         # machine-readable
#   VERBOSE=1 ./verify-well-known.sh      # show full response bodies

set -u

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# --- Dependency check ---
missing=()
command -v curl >/dev/null 2>&1 || missing+=("curl")
command -v jq   >/dev/null 2>&1 || missing+=("jq")
if (( ${#missing[@]} > 0 )); then
  echo "ERROR: missing required tools: ${missing[*]}" >&2
  exit 2
fi

# --- Endpoints to probe ---
MCP_BASE="https://mcp.pandadoc.com"
AUTH_SERVER_URL="${MCP_BASE}/.well-known/oauth-authorization-server"
PROTECTED_RESOURCE_URL="${MCP_BASE}/.well-known/oauth-protected-resource"

# --- Recorded contract (2026-06-05 reference shape) ---
REQUIRED_AUTH_SERVER_KEYS=(issuer authorization_endpoint token_endpoint scopes_supported response_types_supported grant_types_supported)
OPTIONAL_AUTH_SERVER_KEYS=(code_challenge_methods_supported registration_endpoint token_endpoint_auth_methods_supported)

EXPECTED_ISSUER_PREFIX="${MCP_BASE}"
EXPECTED_AUTH_ENDPOINT="${MCP_BASE}/authorize"
EXPECTED_TOKEN_ENDPOINT="${MCP_BASE}/token"
EXPECTED_SCOPES_SORTED="read,read+write"  # alphabetical join

# --- Result accumulator ---
verdicts=()
soft_count=0
hard_count=0

record() {
  local kind="$1"; shift
  verdicts+=("${kind}: $*")
  case "$kind" in
    SOFT) ((soft_count++)) ;;
    HARD) ((hard_count++)) ;;
  esac
}

# --- Auth-server probe ---
fetch_auth_server() {
  local body http_status
  body=$(curl -sSL --max-time 15 --write-out '\n___HTTP_STATUS___:%{http_code}' "$AUTH_SERVER_URL" 2>&1) || {
    record HARD "auth-server: curl error (${body:0:80})"
    return
  }
  http_status=$(printf '%s\n' "$body" | awk -F: '/^___HTTP_STATUS___:/{print $2}')
  body=$(printf '%s\n' "$body" | awk '/^___HTTP_STATUS___:/{exit} {print}')

  if [[ "$http_status" != "200" ]]; then
    record HARD "auth-server: HTTP ${http_status} (expected 200) at ${AUTH_SERVER_URL}"
    return
  fi

  if ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    record HARD "auth-server: response is not valid JSON"
    return
  fi

  # Required keys
  local missing_required=()
  for k in "${REQUIRED_AUTH_SERVER_KEYS[@]}"; do
    if ! printf '%s' "$body" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1; then
      missing_required+=("$k")
    fi
  done
  if (( ${#missing_required[@]} > 0 )); then
    record HARD "auth-server: missing required keys: ${missing_required[*]}"
  fi

  # Optional keys
  local missing_optional=()
  for k in "${OPTIONAL_AUTH_SERVER_KEYS[@]}"; do
    if ! printf '%s' "$body" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1; then
      missing_optional+=("$k")
    fi
  done
  if (( ${#missing_optional[@]} > 0 )); then
    record SOFT "auth-server: missing optional keys: ${missing_optional[*]}"
  fi

  # Value checks — load-bearing for SKILL Step 3
  local issuer auth_ep token_ep
  issuer=$(printf '%s' "$body" | jq -r '.issuer // empty')
  auth_ep=$(printf '%s' "$body" | jq -r '.authorization_endpoint // empty')
  token_ep=$(printf '%s' "$body" | jq -r '.token_endpoint // empty')

  if [[ -n "$issuer" && "$issuer" != "$EXPECTED_ISSUER_PREFIX"* ]]; then
    record HARD "auth-server: .issuer = ${issuer} (expected prefix ${EXPECTED_ISSUER_PREFIX})"
  fi
  if [[ -n "$auth_ep" && "$auth_ep" != "$EXPECTED_AUTH_ENDPOINT" ]]; then
    record HARD "auth-server: .authorization_endpoint = ${auth_ep} (expected ${EXPECTED_AUTH_ENDPOINT}) — SKILL Step 3 OAuth URL claim drifts"
  fi
  if [[ -n "$token_ep" && "$token_ep" != "$EXPECTED_TOKEN_ENDPOINT" ]]; then
    record HARD "auth-server: .token_endpoint = ${token_ep} (expected ${EXPECTED_TOKEN_ENDPOINT})"
  fi

  # Scope drift (SOFT — adding scopes is forward-compatible, but the user should know)
  local live_scopes_sorted
  live_scopes_sorted=$(printf '%s' "$body" | jq -r '.scopes_supported // [] | sort | join(",")')
  if [[ "$live_scopes_sorted" != "$EXPECTED_SCOPES_SORTED" ]]; then
    record SOFT "auth-server: .scopes_supported = [${live_scopes_sorted}] (recorded: [${EXPECTED_SCOPES_SORTED}]) — coarse-grained 'read'/'read+write' contract may have shifted"
  fi

  if (( ${#missing_required[@]} == 0 )) && (( ${#missing_optional[@]} == 0 )) && [[ "$live_scopes_sorted" == "$EXPECTED_SCOPES_SORTED" ]]; then
    record PASS "auth-server: all required + optional keys present, scope set unchanged, value checks PASS"
  fi

  [[ "${VERBOSE:-0}" == "1" ]] && { echo; echo "--- auth-server body ---"; printf '%s\n' "$body" | jq .; echo; }
}

# --- Protected-resource probe (EXPECTED absent per 2026-06-05 capture) ---
fetch_protected_resource() {
  local code
  code=$(curl -sSL -o /dev/null --max-time 10 -w "%{http_code}" "$PROTECTED_RESOURCE_URL" 2>&1)
  if [[ "$code" == "200" ]]; then
    record SOFT "protected-resource: NOW returns 200 (was 404 on 2026-06-05) — PandaDoc may have added RFC 9728 protected-resource metadata; consider extending the SKILL"
  elif [[ "$code" == "404" ]]; then
    record PASS "protected-resource: 404 (expected per recorded contract — PandaDoc does not publish RFC 9728 metadata)"
  else
    record SOFT "protected-resource: HTTP ${code} (was 404 on 2026-06-05; investigate)"
  fi
}

fetch_auth_server
fetch_protected_resource

# --- Emit result ---
overall="PASS"
(( soft_count > 0 )) && overall="SOFT_DRIFT"
(( hard_count > 0 )) && overall="HARD_DRIFT"

if (( JSON_MODE == 1 )); then
  jq -n \
    --arg overall "$overall" \
    --argjson soft "$soft_count" \
    --argjson hard "$hard_count" \
    --arg verdicts "$(printf '%s\n' "${verdicts[@]}")" \
    '{
      overall: $overall,
      soft_count: $soft,
      hard_count: $hard,
      checks: ($verdicts | split("\n") | map(select(length > 0)))
    }'
else
  echo "PandaDoc MCP well-known shape check — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Recorded reference: 2026-06-05 live capture against mcp.pandadoc.com"
  echo
  for v in "${verdicts[@]}"; do echo "  $v"; done
  echo
  echo "OVERALL: ${overall} (${#verdicts[@]} checks, ${soft_count} soft drift, ${hard_count} hard drift)"
  if (( hard_count > 0 )); then
    echo
    echo "HARD drift means the SKILL's Step 3 documentation no longer matches what"
    echo "PandaDoc publishes. Re-run a live install to capture the new shape, then"
    echo "update SKILL.md Step 3 + this script's recorded-contract section before"
    echo "shipping the next release."
  fi
fi

(( hard_count > 0 )) && exit 2
(( soft_count > 0 )) && exit 1
exit 0
