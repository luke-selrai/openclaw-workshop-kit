#!/usr/bin/env bash
# verify-well-known.sh — Re-validate the Canva MCP OAuth metadata shape.
#
# The canva-connector SKILL.md (Overview "verified empirically" note + Step 3)
# makes a load-bearing claim:
# "mcp.canva.com/authorize is a bridge / proxy OAuth endpoint that redirects
# through canva.com/api/oauth/authorize using Canva's pre-registered MCP app."
# That claim was verified empirically 2026-04-30. This script re-fetches the
# OAuth metadata documents and structurally validates them so the SKILL's
# claim can be re-validated on a schedule (e.g. monthly), independent of a
# full install run.
#
# Exit codes:
#   0   — all checks pass; shape matches the recorded contract
#   1   — soft drift (a known-optional field is missing, or a status is non-200
#         on a known-optional endpoint); SKILL still works, but worth a look
#   2   — hard drift (required field missing, JSON parse failure, mcp.canva.com
#         endpoints unreachable); the SKILL's Step 3 claim is no longer accurate
#         and needs re-verification before the next release
#
# Dependencies: curl, jq (standard on macOS / Linux dev boxes). On Windows,
# run from Git Bash; both are bundled in the repo's dev-env install.
#
# Usage:
#   ./verify-well-known.sh                # human-readable
#   ./verify-well-known.sh --json         # machine-readable (one JSON object)
#   VERBOSE=1 ./verify-well-known.sh      # show full response bodies

set -u  # do NOT set -e — we want to keep going on individual endpoint failures

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

# --- Dependency check ---
missing=()
command -v curl >/dev/null 2>&1 || missing+=("curl")
command -v jq   >/dev/null 2>&1 || missing+=("jq")
if (( ${#missing[@]} > 0 )); then
  echo "ERROR: missing required tools: ${missing[*]}" >&2
  echo "Install: brew install ${missing[*]}  (macOS) or apt install ${missing[*]}  (Debian/Ubuntu)" >&2
  exit 2
fi

# --- Endpoints to probe ---
MCP_BASE="https://mcp.canva.com"
PROTECTED_RESOURCE_URL="${MCP_BASE}/.well-known/oauth-protected-resource"
AUTH_SERVER_URL="${MCP_BASE}/.well-known/oauth-authorization-server"
OPENID_CONFIG_URL="${MCP_BASE}/.well-known/openid-configuration"

# --- Recorded contract (2026-04-30 reference shape) ---
# These are the fields the SKILL's Step 3 documentation relies on. If any of
# these REQUIRED keys disappear, Step 3's bridge-OAuth narration becomes
# inaccurate and needs to be re-verified before the SKILL ships an update.
REQUIRED_PROTECTED_RESOURCE_KEYS=(resource authorization_servers)
OPTIONAL_PROTECTED_RESOURCE_KEYS=(scopes_supported bearer_methods_supported)
REQUIRED_AUTH_SERVER_KEYS=(issuer authorization_endpoint token_endpoint)
OPTIONAL_AUTH_SERVER_KEYS=(response_types_supported code_challenge_methods_supported)

# Expected canonical values (load-bearing for the SKILL):
EXPECTED_RESOURCE_PREFIX="${MCP_BASE}"
EXPECTED_AUTH_ENDPOINT_PREFIX="${MCP_BASE}/authorize"   # bridge endpoint on mcp.canva.com
EXPECTED_ISSUER_PREFIX="${MCP_BASE}"

# --- Result accumulator ---
verdicts=()           # one line per check, "PASS|SOFT|HARD: <msg>"
soft_count=0
hard_count=0
declare -A bodies     # endpoint URL -> response body (for --json output)

record() {
  local kind="$1"; shift
  verdicts+=("${kind}: $*")
  case "$kind" in
    SOFT) ((soft_count++)) ;;
    HARD) ((hard_count++)) ;;
  esac
}

# --- Helper: fetch + structural validation ---
fetch_and_check() {
  local url="$1" label="$2" required_keys_var="$3" optional_keys_var="$4" required_value_check="${5:-}"

  local body http_status
  body=$(curl -sSL --max-time 15 --write-out '\n___HTTP_STATUS___:%{http_code}' "$url" 2>&1) || {
    record HARD "${label}: curl error (${body:0:80})"
    return
  }
  http_status=$(printf '%s\n' "$body" | awk -F: '/^___HTTP_STATUS___:/{print $2}')
  body=$(printf '%s\n' "$body" | awk '/^___HTTP_STATUS___:/{exit} {print}')
  bodies[$url]=$body

  if [[ "$http_status" != "200" ]]; then
    if [[ "$label" == "openid-configuration" ]]; then
      record SOFT "${label}: HTTP ${http_status} (optional endpoint — Canva MCP may not publish OpenID metadata)"
    else
      record HARD "${label}: HTTP ${http_status} (expected 200) at ${url}"
    fi
    return
  fi

  if ! printf '%s' "$body" | jq -e . >/dev/null 2>&1; then
    record HARD "${label}: response is not valid JSON"
    return
  fi

  # Required keys
  local -n required=$required_keys_var
  local missing_required=()
  for k in "${required[@]}"; do
    if ! printf '%s' "$body" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1; then
      missing_required+=("$k")
    fi
  done
  if (( ${#missing_required[@]} > 0 )); then
    record HARD "${label}: missing required keys: ${missing_required[*]}"
  fi

  # Optional keys (soft drift)
  local -n optional=$optional_keys_var
  local missing_optional=()
  for k in "${optional[@]}"; do
    if ! printf '%s' "$body" | jq -e --arg k "$k" 'has($k)' >/dev/null 2>&1; then
      missing_optional+=("$k")
    fi
  done
  if (( ${#missing_optional[@]} > 0 )); then
    record SOFT "${label}: missing optional keys: ${missing_optional[*]}"
  fi

  # Value checks
  if [[ -n "$required_value_check" ]]; then
    eval "$required_value_check"
  fi

  if (( ${#missing_required[@]} == 0 )) && (( ${#missing_optional[@]} == 0 )); then
    record PASS "${label}: all expected keys present"
  fi

  [[ "${VERBOSE:-0}" == "1" ]] && { echo; echo "--- ${label} body ---"; printf '%s\n' "$body" | jq .; echo; }
}

# --- Custom value-checks ---
check_protected_resource_values() {
  local resource
  resource=$(printf '%s' "$body" | jq -r '.resource // empty')
  if [[ -z "$resource" ]]; then
    return  # already flagged by required-keys check
  fi
  if [[ "$resource" != "$EXPECTED_RESOURCE_PREFIX"* ]]; then
    record HARD "protected-resource: .resource = ${resource} (expected prefix ${EXPECTED_RESOURCE_PREFIX})"
  fi

  local auth_servers_count
  auth_servers_count=$(printf '%s' "$body" | jq -r '.authorization_servers | length' 2>/dev/null || echo 0)
  if [[ "$auth_servers_count" == "0" ]]; then
    record HARD "protected-resource: .authorization_servers is empty (SKILL Step 3 needs at least one)"
  fi
}

check_auth_server_values() {
  local issuer auth_ep
  issuer=$(printf '%s' "$body" | jq -r '.issuer // empty')
  auth_ep=$(printf '%s' "$body" | jq -r '.authorization_endpoint // empty')

  if [[ -n "$issuer" && "$issuer" != "$EXPECTED_ISSUER_PREFIX"* ]]; then
    record HARD "auth-server: .issuer = ${issuer} (expected prefix ${EXPECTED_ISSUER_PREFIX})"
  fi
  if [[ -n "$auth_ep" && "$auth_ep" != "$EXPECTED_AUTH_ENDPOINT_PREFIX"* ]]; then
    record HARD "auth-server: .authorization_endpoint = ${auth_ep} (expected prefix ${EXPECTED_AUTH_ENDPOINT_PREFIX}) — SKILL Step 3's 'bridge endpoint on mcp.canva.com' claim drifts"
  fi
}

# --- Run probes ---
fetch_and_check "$PROTECTED_RESOURCE_URL" "protected-resource" \
  REQUIRED_PROTECTED_RESOURCE_KEYS OPTIONAL_PROTECTED_RESOURCE_KEYS \
  "check_protected_resource_values"

fetch_and_check "$AUTH_SERVER_URL" "auth-server" \
  REQUIRED_AUTH_SERVER_KEYS OPTIONAL_AUTH_SERVER_KEYS \
  "check_auth_server_values"

# OpenID discovery is optional — Canva may or may not publish it. SOFT-flag on miss.
fetch_and_check "$OPENID_CONFIG_URL" "openid-configuration" \
  REQUIRED_AUTH_SERVER_KEYS OPTIONAL_AUTH_SERVER_KEYS \
  ""

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
  echo "Canva MCP well-known shape check — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Recorded reference: SKILL.md Overview (\"verified empirically 2026-04-30\")"
  echo
  for v in "${verdicts[@]}"; do echo "  $v"; done
  echo
  echo "OVERALL: ${overall} (${#verdicts[@]} checks, ${soft_count} soft drift, ${hard_count} hard drift)"
  if (( hard_count > 0 )); then
    echo
    echo "HARD drift means the SKILL's Step 3 documentation no longer matches what"
    echo "Canva publishes. Re-run a live install to capture the new shape, then"
    echo "update SKILL.md Step 3 + this script's recorded-contract section before"
    echo "shipping the next release."
  fi
fi

(( hard_count > 0 )) && exit 2
(( soft_count > 0 )) && exit 1
exit 0
