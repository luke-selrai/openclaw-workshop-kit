#!/usr/bin/env bash
#
# smoke.sh — verify the QuickBooks Online connector is installed and authenticated.
#
# Runs the same two checks the SKILL performs at the end of Phase 1, but as a
# standalone, machine-readable script so an outsider (or CI) can confirm the
# connection end-to-end without reading the whole SKILL. Exits 0 only when qbo
# is installed, authenticated, and a live sandbox company read succeeds.
#
# Usage:
#   bash scripts/smoke.sh
#
# Expected success output (sandbox practice company):
#   ✓ qbo installed: qbo version 0.x.x
#   ✓ authenticated: true
#   ✓ live company read: Sandbox Company_US_1
#   PASS — QuickBooks connector is connected and answering.
#
# Exit codes:
#   0  all checks passed
#   1  a check failed (message on stderr explains which, in plain English)

set -u

CREDS="${HOME}/.config/qbo/credentials.env"

fail() {
  echo "FAIL — $1" >&2
  exit 1
}

# 1. Binary present?
if ! command -v qbo >/dev/null 2>&1; then
  fail "the 'qbo' tool is not installed yet. Run Phase 1, Step 2 of the SKILL."
fi
echo "✓ qbo installed: $(qbo --version 2>&1 | head -1)"

# 2. Credentials file present?
if [ ! -f "${CREDS}" ]; then
  fail "no credentials file at ${CREDS}. Run Phase 1, Step 8 of the SKILL."
fi

# Load credentials into this process only (not the user's global shell).
set -a
# shellcheck disable=SC1090
source "${CREDS}"
set +a

# 3. Authenticated? (qbo exits 4 = auth_required when the token is missing/expired)
AUTH_OUT="$(qbo auth status 2>&1)"
AUTH_RC=$?
if [ "${AUTH_RC}" -ne 0 ]; then
  if [ "${AUTH_RC}" -eq 4 ]; then
    fail "not authenticated (auth_required). Re-run Phase 1 from Step 9."
  fi
  fail "qbo auth status exited ${AUTH_RC}. See: ${AUTH_OUT}"
fi
echo "✓ authenticated: true"

# 4. Live read — proves the token actually reaches QuickBooks, not just that a
#    token exists locally. This is the check that distinguishes "configured" from
#    "working".
INFO_JSON="$(qbo company info --sandbox --json 2>&1)"
INFO_RC=$?
if [ "${INFO_RC}" -ne 0 ]; then
  fail "live company read failed (exit ${INFO_RC}). The token may be stale or no sandbox company is selected. See SKILL Step 10."
fi

COMPANY="$(printf '%s' "${INFO_JSON}" | jq -r '.QueryResponse.CompanyInfo[0].CompanyName // empty' 2>/dev/null)"
if [ -z "${COMPANY}" ]; then
  fail "live read returned no company name. Run 'qbo company list --sandbox --json' to pick a company."
fi
echo "✓ live company read: ${COMPANY}"

echo "PASS — QuickBooks connector is connected and answering."
exit 0
