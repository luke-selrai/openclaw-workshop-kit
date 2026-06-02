---
name: google-ads-connector
description: "Connect and operate Google Ads (read campaigns, ad groups, ads, keywords, search terms, audiences; pull reports for spend/conversions/ROAS; pause/resume campaigns and adjust budgets) via direct REST against the Google Ads API. Each participant has their own Google Cloud OAuth client and their own developer token. Phase 0 picks between Test mode (immediate dev-token, only works with Google Ads test accounts) and Basic Access mode (live data, real customer, but Google reviews the dev-token application over ~1-3 business days). Phase 1 drives Google Cloud Console (OAuth client creation) + Google Ads API Center (dev-token request) + Google's OAuth consent flow + the optional 'New Google Ads account' wizard, all inside a Playwright MCP browser. Tokens persist at ~/.config/google-ads/credentials.json (mode 0600). Use this skill when the user asks about their Google Ads, says 'connect Google Ads', asks about ad spend / ROAS / conversions / keywords / campaigns / ad groups. For paid-ads strategy advice (vs. data queries), prefer the paid-ads skill — this connector is the data source. On first use of any Google Ads feature, run Phase 0 then Phase 1 before any tool call."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - google-ads
    - adwords
    - ppc
    - paid-media
    - campaigns
    - keywords
    - reports
    - rest-api
    - oauth
  pairs-with:
    - skill: paid-ads
      reason: paid-ads is the strategy advisor (how to plan/optimise campaigns); google-ads-connector is the data source for those decisions. Pair when the user wants both advice and live data.
    - skill: quickbooks-connector
      reason: Same Phase 0 mode-detection + Phase 1 Playwright-driven autonomous install pattern as the Tier-1 reference. QBO's Phase 1L is a heavier variant of this skill's Phase 1L.
    - skill: myob-connector
      reason: Reference SKILL for the Direct-REST + Playwright pattern (no MCP, no first-party CLI, OAuth + bearer-on-curl)
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting OAuth flow failures or Google Ads API errors
---

# Google Ads Connector

## Overview

This skill lets you read and operate a user's Google Ads account on their behalf using **Google Ads API v17 REST endpoints** (no MCP server, no first-party CLI). `skills/CLAUDE.md` documents the three install patterns (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace) and explicitly marks direct-REST connectors (`ghl-connector`, `myob-connector`) as out of scope for that doc — see the per-connector SKILL. This SKILL is the third direct-REST connector in the kit and follows the `myob-connector` shape (loopback listener + Playwright-driven OAuth + atomic `credentials.json` write + bearer-on-curl Phase 2).

It has two phases:

- **Phase 1 — Install & Connect (autonomous via Playwright + REST).** Claude drives Google Cloud Console end-to-end via Playwright MCP to create an OAuth client, drives `ads.google.com/aw/apicenter` to request a developer token (Test mode = instant; Basic Access mode = 1-3 business day Google review), drives the OAuth consent flow to capture access + refresh tokens, lists the participant's accessible customer IDs, and persists everything to `~/.config/google-ads/credentials.json` (mode 0600). The participant's manual moments are signing in to Google once and approving consent.
- **Phase 2 — Use Tools (Direct-REST via curl + GAQL).** Once `credentials.json` is configured, you `curl` Google Ads API REST endpoints. Reports run as GAQL queries via `customers/{cid}/googleAds:searchStream`. Writes (pause/resume campaign, adjust budget) are gated by Production-mode confirmation prose when `mode=basic` (real ads, real money).

**Two modes, picked at Phase 0:**

| Mode | When | What it touches | Wait |
|---|---|---|---|
| **Test** | Default for first-time install. Recommended for "I want to try it today." | Only Google Ads test accounts (auto-created by Google under a Manager Account). No real money. | Immediate (token auto-issued for new dev accounts). |
| **Basic Access** | When the participant says "I want my real ads data." | Real Google Ads customer accounts the participant owns. Real spend numbers, real conversions. | 1-3 business days for Google to approve the developer-token application. The participant can use Test mode immediately while waiting. |

**Live by default is NOT possible** (unlike QBO). Google Ads Basic Access has a mandatory 1-3 business day review by Google. Phase 0 defaults to **Test** to avoid blocking the participant on the wait; **Basic Access** is opt-in via Phase 0 prompt. The participant can also "do both" — Phase 1L kicks off the Basic Access application AND falls back to Test mode immediately so the participant has API access today and an upgrade path for ~3 days from now.

**Which phase to run** — Before any tool call, check whether the credentials file exists:

```bash
test -f "$HOME/.config/google-ads/credentials.json" && jq -r '.mode // "missing"' "$HOME/.config/google-ads/credentials.json" 2>/dev/null || echo missing
```

- Output `test` or `basic` → credentials present, mode known. Go to Phase 2 with the corresponding behavioural switches.
- Output `pending-basic` → Basic Access application was submitted; Phase 0 polls Google for approval, falls through to Phase 1L resume or Phase 2 in Test mode.
- Output `missing` → run Phase 0 + Phase 1.

---

## Golden rule — do not open the participant's own browser

Every Phase 1 step that requires sign-in (Google Cloud, Google Ads, OAuth consent) runs inside the Playwright MCP browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the participant to "open a link in your browser." Claude navigates, the participant types passwords directly into the Playwright window, Claude reads the result programmatically. Same rule as the `myob-connector` and `quickbooks-connector` skills.

If Playwright MCP is unavailable, stop and tell the participant: *"I need a small browser tool that's not installed yet — let me show you how to add it."* Then point them at the install instructions for the Playwright MCP and stop. Do not fall back to opening the participant's default browser.

---

## Communication rules for Phase 1

The participant is a non-technical business owner. Every message during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions.
- **Plain English only.** Never say OAuth, token, dev token, scope, refresh, Bearer, API, endpoint, JSON, GAQL, customer ID, manager account, env var, curl, terminal, CLI, MCP, redirect URI, callback, loopback, sandbox, file path, or `developer-token`. If you must refer to a technical thing, name it plainly: "your connection details", "your Google Ads account number", "the workshop's setup step", "Google's review".
- **Tell them what is about to happen.** *"I'm opening Google Cloud now to set up the connection — sign in when you see the page. About a minute."*
- **React warmly.** Good: *"Got it — connection ready for **[Account Name]**."* Bad: *"OAuth token exchange returned 200, credentials.json written mode 0600."*
- **Never show error messages directly.** Translate. *"No problem — let me try a different way,"* then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the participant. You run them.
- **Never echo CLIENT_ID, CLIENT_SECRET, the dev token, or refresh tokens** back to the participant — all are stored locally and never shown.

---

## ⛔ Pre-flight check — Playwright availability

Before any Phase 0 step, verify Playwright MCP tools are available:

```bash
# Quick test: do any mcp__playwright__* or mcp__plugin_playwright_playwright__* tools exist in this session?
# If not, halt and tell the participant to install Playwright MCP per skills/CLAUDE.md.
```

If unavailable, stop. Do not start Phase 0 or Phase 1.

---

## PHASE 0 — Mode + state detection

Phase 0 picks the mode (test vs basic vs resume-pending) and decides whether Phase 1 runs at all. It runs before any Phase 2 tool call.

### Step 0.1 — Read existing credentials

```bash
CREDS="$HOME/.config/google-ads/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.mode // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

Four states:

- **`missing`** — first-time install. Continue to Step 0.2.
- **`test`** — Test mode set up. Smoke-test by listing accessible customers; if 200, jump to Phase 2 with `MODE=test`. If 401, refresh token (Step 1.10) then retry; if still failing, fall through to Phase 1 re-auth.
- **`basic`** — Basic Access mode active. Same smoke test as `test`; on success, Phase 2 with `MODE=basic` and the production-mode gates ON.
- **`pending-basic`** — Basic Access application submitted, not yet approved. Continue to Step 0.3.

### Step 0.2 — Ask Test or Basic Access (first-time install)

Ask the participant in one warm message:

> "Quick question: want me to start in **test mode** so you can use the connection today (no real money, just practice data), or do you want **real data** for your actual Google Ads account? Real data needs Google to approve me first — they usually take 1 to 3 business days. Most people pick test mode first."

Map the reply:

- "test", "try", "today", "quick", or no specific answer → `MODE=test` → continue to **Phase 1**, with the **Phase 1T** sub-flow after Phase 1's shared steps.
- "real", "live", "basic", "production", "actual" → `MODE=basic` → continue to **Phase 1**, with the **Phase 1L** sub-flow after Phase 1's shared steps. Set the participant's expectation: *"OK — I'll kick off Google's approval too. While we wait for them (1 to 3 business days), I'll set you up in test mode so you can use the connection right away."*
- Ambiguous → ask once for clarification, default `MODE=test`.

Do NOT use the word "sandbox" — use "test mode" (workshop UX rule from `feedback_workshop_kit_update_format`).

### Step 0.3 — Check Basic Access application status (when state = pending-basic)

```bash
APPLIED_AT=$(jq -r '.basic_application.applied_at' "$CREDS")
HOURS_AGO=$(python3 -c "import datetime,sys;a=datetime.datetime.fromisoformat(sys.argv[1].rstrip('Z'));print(int((datetime.datetime.utcnow()-a).total_seconds()/3600))" "$APPLIED_AT")
echo "Applied $HOURS_AGO hours ago"
```

If less than 24 hours: tell the participant *"Google's still reviewing — usually takes 1 to 3 business days. Want to use test mode in the meantime?"* If they say yes, go to Phase 2 with `MODE=test` (Test credentials should already be saved from Phase 1L's fallback). If no, stop.

If 24+ hours: drive Playwright to check `ads.google.com/aw/apicenter` for the application status (Step L.5 below); if approved, capture the Basic Access dev token, flip `mode=basic`, jump to Phase 2; if still pending, repeat the message.

---

## PHASE 1 — Install & Connect (autonomous via Playwright + REST)

Phase 1 has THREE parts:

- **Part A (shared)** — Steps 1–10 below. Always runs. Creates the Google Cloud OAuth client, runs the OAuth flow, captures refresh token + customer IDs.
- **Part B (Phase 1T)** — Test-mode dev token. Runs after Part A when `MODE=test`. Instant; participant can use Phase 2 immediately.
- **Part C (Phase 1L)** — Basic Access dev token. Runs after Part A when `MODE=basic`. Submits application; falls back to Phase 1T for immediate access while waiting.

### Step 1 — Welcome message

Send one short message:

> "Great — connecting your Google Ads. Three quick things:
> 1. Sign in to Google when I open the page.
> 2. Approve the connection when it asks.
> 3. If you don't have a Google Ads account yet, I'll help you make one.
> About 4 minutes total."

### Step 2 — Sign in to Google Cloud Console

```
mcp__playwright__browser_navigate({ url: "https://console.cloud.google.com/welcome" })
```

**Do NOT snapshot the sign-in page** (password-leak risk — see `reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "Welcome", time: 30 })
```

(or wait for the project picker `Select a project` text). If timeout: ask the participant *"Still on the sign-in page? Anything I can help with?"* and re-poll.

### Step 3 — Create or pick a Google Cloud project

Navigate to:

```
mcp__playwright__browser_navigate({ url: "https://console.cloud.google.com/projectselector2/home/dashboard" })
```

Two states:

- **At least one project exists** → pick the first one the participant has owner/editor on. If they have multiple and aren't sure, ask: *"Which Google Cloud project should I use? (You can pick any of yours — it just stores the connection details.)"*
- **Zero projects** → drive `New Project` button: name = `claude-google-ads`, organization = participant's default, location = no organization or their org. Click Create. Wait for the post-create dashboard.

Capture the `PROJECT_ID` from the URL or the project header.

### Step 4 — Enable the Google Ads API

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/library/googleads.googleapis.com?project=${PROJECT_ID}"
})
```

Click the **Enable** button via `browser_evaluate`:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^enable$/i.test((b.innerText||'').trim()));
  if (!btn || btn.disabled) return { ok: false, reason: btn ? 'disabled' : 'no-button' };
  btn.click();
  return { ok: true };
}
```

If the button reads `Manage` (not `Enable`), the API is already enabled — skip.

Wait for the post-enable redirect (`browser_wait_for({ text: "API enabled" })` or check for the Manage button to appear).

### Step 5 — Create the OAuth client

Navigate to:

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}"
})
```

**5a — OAuth consent screen prereq.** If the page shows a banner like "Configure consent screen" before the create-credentials button works, click into Consent Screen, pick `External` (or `Internal` if Workspace org), fill: app name = `Claude Google Ads Connector`, support email = participant's signed-in email, developer contact = same. Save and continue through all four wizard steps with defaults; on the test-users step, add the participant's own email to allow them to sign in. Return to the Credentials page.

**5b — Create OAuth Client ID.**

Click `+ CREATE CREDENTIALS` → `OAuth client ID`. Application type = `Desktop app`. Name = `Claude Google Ads Connector`. Click Create.

A modal pops up showing **Your Client ID** and **Your Client Secret**. Capture both via clipboard-transit (same pattern as QBO Phase 1S Step 7 — clipboard.writeText with values, returns only length integers):

```js
async () => {
  // Find the modal panel with Client ID + Client Secret
  const labels = Array.from(document.querySelectorAll('*'))
    .filter(el => /^(your )?client (id|secret)\s*:?$/i.test((el.innerText||'').trim()));
  const out = {};
  for (const label of labels) {
    const which = /id/i.test(label.innerText) ? 'client_id' : 'client_secret';
    if (out[which]) continue;
    let scope = label.parentElement;
    for (let depth = 0; depth < 6 && scope; depth++) {
      const codes = Array.from(scope.querySelectorAll('code, input[type=text], input:not([type])'));
      const v = codes.map(c => (c.value || c.innerText || '').trim()).find(v => v.length > 20);
      if (v) { out[which] = v; break; }
      scope = scope.parentElement;
    }
  }
  if (!out.client_id || !out.client_secret) return { ok: false, found: Object.keys(out) };
  await navigator.clipboard.writeText(JSON.stringify(out));
  return { ok: true, client_id_len: out.client_id.length, client_secret_len: out.client_secret.length };
}
```

Save the participant's prior clipboard FIRST (same `wl-paste | base64 > /tmp/google-ads-prev-clipboard.b64` pattern). Restore after Step 9.

Client ID is typically ~70 chars (`<numeric>-<random>.apps.googleusercontent.com`); secret is ~35 chars. Validate shapes silently.

### Step 6 — Check for an existing Google Ads account

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/overview" })
```

Two states:

- **Existing Google Ads account** → the page renders the campaigns overview. Continue to Step 7.
- **Account selector with "You don't have any Google Ads accounts" prompt** → drive `New Google Ads account` button:

  ```js
  () => {
    const btn = Array.from(document.querySelectorAll('button, a')).find(b => /new google ads account/i.test((b.innerText||'').trim()));
    if (btn) { btn.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

  Then walk through Google's onboarding wizard. For Test mode, prefer the **Switch to Expert Mode** option (shown on the first onboarding page) — this skips the "Create your first campaign" pressure and gives a bare-account state. If the wizard requires billing info or a real campaign target, tell the participant: *"Google wants some account details to finish the setup. Fill in what they ask — I'll wait."* Wait for the overview page to render.

### Step 7 — Start the loopback listener for the OAuth callback

Start a tiny Python listener on `localhost:8765` to catch the redirect with the authorization code:

```bash
PORT=8765
while ss -tlnp 2>/dev/null | grep -q ":$PORT "; do PORT=$((PORT+1)); done

nohup python3 -c "
import http.server, urllib.parse, sys
class H(http.server.BaseHTTPRequestHandler):
  def log_message(self, *a, **k): pass
  def do_GET(self):
    params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
    code = params.get('code', [''])[0]
    self.send_response(200)
    self.send_header('Content-Type', 'text/html')
    self.end_headers()
    self.wfile.write(b'<h1>Google Ads connected. You can close this tab.</h1>')
    with open('/tmp/google-ads-auth-code', 'w') as f:
      f.write(code)
    sys.exit(0)
http.server.HTTPServer(('127.0.0.1', $PORT), H).serve_forever()
" > /tmp/google-ads-listener.log 2>&1 &
echo $! > /tmp/google-ads-listener.pid
echo "$PORT" > /tmp/google-ads-listener.port
```

If port 8765 is in use, the loop steps up. The chosen port is stored in `/tmp/google-ads-listener.port` for Step 8 and the redirect URI Step 5 added to the OAuth client.

> **OAuth client redirect URI**: Google's Desktop App OAuth flow accepts loopback redirect URIs `http://127.0.0.1:<port>` without pre-registering each port (per RFC 8252 Section 7.3 — Google supports this). Some Desktop clients may default to `http://localhost`. If the OAuth request fails with `redirect_uri_mismatch`, fall back to using `http://localhost:$PORT` (instead of `127.0.0.1`) and edit the OAuth client's authorized redirect URI list to include it.

### Step 8 — Drive the OAuth consent flow

Read the values back from clipboard for the OAuth URL construction (still never echoing them):

```bash
CLIENT_ID="$(wl-paste | jq -r '.client_id')"
PORT="$(cat /tmp/google-ads-listener.port)"
SCOPE="https://www.googleapis.com/auth/adwords"
AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?client_id=${CLIENT_ID}&redirect_uri=http%3A%2F%2F127.0.0.1%3A${PORT}&response_type=code&scope=${SCOPE}&access_type=offline&prompt=consent"
```

Navigate Playwright to `$AUTH_URL`. Three possible page states:

- **Already-signed-in consent screen** → click **Allow** via `browser_evaluate`:

  ```js
  () => {
    const btn = Array.from(document.querySelectorAll('button, span[role=button]'))
      .find(b => /^(continue|allow)$/i.test((b.innerText||'').trim()));
    if (btn) { btn.scrollIntoView({block:'center'}); btn.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

- **"Account chooser"** (when participant has multiple Google accounts) → wait for participant to click their workshop account; then re-detect consent screen and click Allow.
- **"This app isn't verified" warning** (the OAuth consent screen is in Testing mode without verification) → click **Advanced** then **Go to claude-google-ads (unsafe)**. Reassure the participant in plain English: *"Google's warning is because the connection is only used by you — not a public app. Safe to continue."* Then click Allow.

Poll `/tmp/google-ads-auth-code` every 2 seconds for up to 3 minutes:

```bash
for i in $(seq 1 90); do
  [ -s /tmp/google-ads-auth-code ] && break
  sleep 2
done
AUTH_CODE="$(cat /tmp/google-ads-auth-code)"
```

### Step 9 — Exchange the code for access + refresh tokens

```bash
CLIENT_ID="$(wl-paste | jq -r '.client_id')"
CLIENT_SECRET="$(wl-paste | jq -r '.client_secret')"

RESP="$(curl -sf https://oauth2.googleapis.com/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://127.0.0.1:$PORT" \
  -d "grant_type=authorization_code")"

# Tear down listener
kill "$(cat /tmp/google-ads-listener.pid)" 2>/dev/null
rm -f /tmp/google-ads-auth-code /tmp/google-ads-listener.pid /tmp/google-ads-listener.port /tmp/google-ads-listener.log
```

The response is JSON with `access_token`, `refresh_token`, `expires_in`, `scope`, `token_type`. Stash for Step 11; do not write to disk yet.

**Failure cases:**

- HTTP 400 `invalid_grant` → code expired (>10 min). Restart from Step 7.
- HTTP 400 `redirect_uri_mismatch` → the redirect URI Google requires doesn't match. Try `http://localhost:$PORT` and re-edit the OAuth client (Step 5b) to add it as an authorized redirect URI.
- Network error → retry once with 5s delay. If still failing, plain-English the participant.

### Step 10 — Discover accessible customers

The OAuth access token unlocks the API but doesn't tell you which Google Ads customer accounts the participant has access to.

```bash
ACCESS_TOKEN="$(echo "$RESP" | jq -r .access_token)"
CUSTOMERS_JSON="$(curl -sf https://googleads.googleapis.com/v17/customers:listAccessibleCustomers \
  -H "Authorization: Bearer $ACCESS_TOKEN")"
# Response: { "resourceNames": ["customers/1234567890", "customers/9876543210", ...] }
CUSTOMER_IDS="$(echo "$CUSTOMERS_JSON" | jq -r '.resourceNames[] | sub("customers/"; "")' )"
```

Per ID, fetch the customer name (optional — improves UX):

```bash
for CID in $CUSTOMER_IDS; do
  curl -sf "https://googleads.googleapis.com/v17/customers/$CID/googleAds:search" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "developer-token: <DEV_TOKEN_PLACEHOLDER>" \
    -H "Content-Type: application/json" \
    -d '{"query":"SELECT customer.descriptive_name FROM customer LIMIT 1"}'
done
```

(The customer-name lookup requires the dev token, so defer to after Phase 1T or 1L. For the immediate selection prompt, use the raw IDs.)

Selection:

- **One customer ID** → silently pick it. `CUSTOMER_ID=$CID`.
- **Multiple customer IDs** → ask the participant: *"I can see a few Google Ads accounts on your login: **[ID list]**. Which one should I connect to?"* Match by number. If they have manager + sub-accounts, ask which is the **operating** account they advertise from.
- **Zero customer IDs** → re-check whether Step 6 actually created an account; if absent, repeat Step 6. If the new account isn't yet showing up here (Google has a brief propagation delay), wait 30s and retry once.

Save `CUSTOMER_ID` for the credentials.json write below.

---

### Step 1T — Test-mode dev token (`MODE=test`)

Test-mode developer tokens are auto-issued for new Google Cloud accounts that haven't requested Basic Access yet. They work only against Google Ads **test accounts** (the ones Google creates under a Manager Account via the "Create test account" link).

**1T.1 — Navigate to API Center**

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Wait for the page to render. The page shows the developer token (auto-assigned) and the access tier (Test by default).

**1T.2 — DOM-extract the dev token**

```js
() => {
  const labels = Array.from(document.querySelectorAll('*'))
    .filter(el => /^developer token$/i.test((el.innerText||'').trim()));
  for (const label of labels) {
    let scope = label.parentElement;
    for (let depth = 0; depth < 6 && scope; depth++) {
      const lines = (scope.innerText || '').split('\n').map(s => s.trim()).filter(Boolean);
      // Token shape: 22 alphanumeric chars
      const tokenLine = lines.find(l => /^[A-Za-z0-9_-]{20,28}$/.test(l) && l !== label.innerText.trim());
      if (tokenLine) return { ok: true, token_len: tokenLine.length };
      scope = scope.parentElement;
    }
  }
  return { ok: false };
}
```

Use the same clipboard-transit pattern as Step 5b to capture the token without it appearing in tool returns: write to clipboard, return only length.

**1T.3 — Save credentials.json with mode=test**

```bash
mkdir -p ~/.config/google-ads
chmod 700 ~/.config/google-ads

CLIENT_ID="$(wl-paste | jq -r '.client_id // empty')"
CLIENT_SECRET="$(wl-paste | jq -r '.client_secret // empty')"
DEV_TOKEN="$(wl-paste | jq -r '.dev_token // empty')"   # set by Step 1T.2
ACCESS_TOKEN="$(echo "$RESP" | jq -r .access_token)"
REFRESH_TOKEN="$(echo "$RESP" | jq -r .refresh_token)"
EXPIRES_AT="$(python3 -c 'import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$(echo "$RESP" | jq -r .expires_in)")"

jq -n \
  --arg cid "$CLIENT_ID" \
  --arg csec "$CLIENT_SECRET" \
  --arg at "$ACCESS_TOKEN" \
  --arg rt "$REFRESH_TOKEN" \
  --arg dt "$DEV_TOKEN" \
  --arg cust "$CUSTOMER_ID" \
  --arg exp "$EXPIRES_AT" \
  --arg pid "$PROJECT_ID" \
  '{mode:"test", client_id:$cid, client_secret:$csec, access_token:$at, refresh_token:$rt,
    expires_at:$exp, developer_token:$dt, customer_id:$cust, google_cloud_project:$pid}' \
  > ~/.config/google-ads/credentials.json.tmp
chmod 600 ~/.config/google-ads/credentials.json.tmp
mv ~/.config/google-ads/credentials.json.tmp ~/.config/google-ads/credentials.json
```

Restore the prior clipboard. Verify the file has all 9 expected keys.

**1T.4 — Smoke-test with a GAQL query**

```bash
ACCESS_TOKEN="$(jq -r .access_token ~/.config/google-ads/credentials.json)"
DEV_TOKEN="$(jq -r .developer_token ~/.config/google-ads/credentials.json)"
CID="$(jq -r .customer_id ~/.config/google-ads/credentials.json)"

curl -sf "https://googleads.googleapis.com/v17/customers/$CID/googleAds:search" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "developer-token: $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"SELECT customer.descriptive_name, customer.id FROM customer LIMIT 1"}' \
  | jq -r '.results[0].customer.descriptiveName // "NO_NAME"'
```

Returns the account name (or test-account default name). Tell the participant:

> "All connected — your Google Ads test account is ready. Ask me things like *'list my test campaigns'* or *'show me my keywords'*."

Save a memory marker.

---

### Step 1L — Basic Access mode (`MODE=basic`)

Basic Access requires Google's review of an application form (1-3 business days). Phase 1L submits the form via Playwright AND falls back to Test mode for immediate participant access while waiting.

**1L.1 — Navigate to API Center, click Apply for Basic Access**

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Click the **Apply for Basic Access** button (visible in the API Center when the account is in Test tier):

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /apply.*basic access|upgrade.*api access/i.test((b.innerText||'').trim()));
  if (btn) { btn.click(); return { clicked: true }; }
  return { clicked: false };
}
```

**1L.2 — Fill the application form via Playwright**

The form asks ~10 questions. Defaults to use (revise with the participant before submit):

| Field | Default value |
|---|---|
| Tool name | "Claude Google Ads Connector" |
| Tool URL | (the participant's Cloudflare Pages URL from QBO Phase 1L, or `https://example.com` if none — see `quickbooks-connector` SKILL `skills/quickbooks-connector/SKILL.md` for the Pages deploy pattern this connector can borrow if needed) |
| Tool description | "Personal API access to my own Google Ads account for reporting and management via Claude, an AI assistant. Used by me only; not redistributed." |
| Intended use | "Reports and basic management of my own ads accounts" |
| Email | Participant's signed-in Google account email |
| Contact preferences | "Email me about API news" — opt out by default |
| Industry | Participant's industry (ask if not obvious) |
| Are you an agency? | No (default — most workshop participants aren't agencies) |

Use the React-friendly setter pattern (same as QBO Phase 1L Step 1L-C.1):

```js
(fieldLabel, value) => {
  const labels = Array.from(document.querySelectorAll('label, div, span')).filter(el => new RegExp(`^${fieldLabel}`, 'i').test((el.innerText||'').trim()));
  for (const labelEl of labels) {
    let scope = labelEl.parentElement;
    for (let d = 0; d < 4 && scope; d++) {
      const input = scope.querySelector('input[type=text], input[type=url], textarea, select, input:not([type])');
      if (input) {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        input.focus(); setter.call(input, value);
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        input.blur();
        return { ok: true };
      }
      scope = scope.parentElement;
    }
  }
  return { ok: false };
}
```

**1L.3 — Surface the application to the participant for review**

Before submitting, summarise in plain English what you typed:

> "Here's what I'll send Google for the review:
>
> - Tool name: **Claude Google Ads Connector**
> - Purpose: Personal API access to my own Google Ads account
> - Industry: **[X]**
> - Email: **[participant email]**
>
> Want me to adjust anything before I send it?"

Wait for confirmation, adjust if needed, then click **Submit**:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^submit$/i.test((b.innerText||'').trim()));
  if (btn) { btn.scrollIntoView({block:'center'}); btn.click(); return { clicked: true }; }
  return { clicked: false };
}
```

Wait for the post-submit confirmation (`browser_wait_for({ text: "submitted" })` or similar).

**1L.4 — Record pending state + fall back to Test mode for today**

The participant can't wait 1-3 days for a Phase 2 tool call. Save partial credentials with `mode=pending-basic` and a Test-mode fallback by ALSO running Step 1T to capture the Test dev token. The credentials file gets BOTH tokens; Phase 2 picks the right one based on the `mode` field.

```bash
APPLIED_AT="$(python3 -c 'import datetime; print(datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))')"

# (Step 1T.1-1T.2 also ran above to capture TEST dev token into clipboard slot 'dev_token')
TEST_DEV_TOKEN="$(wl-paste | jq -r '.dev_token // empty')"

jq -n \
  --arg cid "$CLIENT_ID" \
  --arg csec "$CLIENT_SECRET" \
  --arg at "$ACCESS_TOKEN" \
  --arg rt "$REFRESH_TOKEN" \
  --arg tdt "$TEST_DEV_TOKEN" \
  --arg cust "$CUSTOMER_ID" \
  --arg exp "$EXPIRES_AT" \
  --arg pid "$PROJECT_ID" \
  --arg ap "$APPLIED_AT" \
  '{mode:"pending-basic",
    client_id:$cid, client_secret:$csec,
    access_token:$at, refresh_token:$rt, expires_at:$exp,
    developer_token:$tdt, customer_id:$cust, google_cloud_project:$pid,
    basic_application:{applied_at:$ap, status:"submitted"}}' \
  > ~/.config/google-ads/credentials.json.tmp
chmod 600 ~/.config/google-ads/credentials.json.tmp
mv ~/.config/google-ads/credentials.json.tmp ~/.config/google-ads/credentials.json
```

Tell the participant:

> "Application sent to Google — they usually review within 1 to 3 business days and email you. In the meantime, I've set up test mode so you can use the connection today. When Google's email arrives, just say *'check my Google Ads approval'* and I'll switch you over."

**1L.5 — Resume after approval (called from Phase 0.3 when status=pending-basic and 24h+ since applied)**

Navigate to `ads.google.com/aw/apicenter`. The page shows either "Basic Access" (approved) or "Pending Review".

If approved:

```js
// Approval page shows the upgraded developer token (different from test token)
// DOM-extract via the same pattern as Step 1T.2
```

Update `credentials.json`: set `mode=basic`, replace `developer_token` with the Basic Access token, remove `basic_application` block.

Tell the participant: *"Google approved you — you're now on real Google Ads data. Anything you ask me will hit your actual account from here on."* Then trigger Phase 2 Gate 1 (real-data confirmation) on the NEXT tool call.

If still pending: see Phase 0.3.

---

## PHASE 2 — Use Tools

Phase 2 runs after Phase 1 completes. Every call:

1. Reads `~/.config/google-ads/credentials.json`.
2. If `access_token` is expired (`expires_at` past), refreshes via Step 2.0 below.
3. Calls Google Ads REST with `Authorization: Bearer <access>` + `developer-token: <dev>` + `Content-Type: application/json`.
4. Applies the mode-dependent behavioural gates.

**Mode-aware behaviour** (set at session start by reading `credentials.json`):

- `MODE=test` (default) — operations target a test Google Ads account. No real money. Free to call read AND write tools without confirmation.
- `MODE=basic` — operations target a real Google Ads account. Real ads, real spend. **Gate 1** + **Gate 2** apply.
- `MODE=pending-basic` — same data path as `MODE=test` (test dev token in use); when participant says "check my approval", run Phase 0.3.

### Production-mode gate 1 — Soft "real-data" confirmation (first tool call per session, MODE=basic only)

On the FIRST Phase 2 tool call of a session when `MODE=basic`:

1. Call the customer-name query silently: `SELECT customer.descriptive_name FROM customer LIMIT 1`.
2. Extract the name.
3. Tell the participant:
   > "Just confirming — you're connected to your real Google Ads account **[CompanyName]** (ID [CID]). Anything I do here will read or change your live campaigns. OK to proceed with **[summary of what they asked]**?"
4. Wait for the OK. Then proceed.

Apply ONCE per session, not per tool call.

### Production-mode gate 2 — Destructive-op confirmation (every write, MODE=basic only)

For Patterns 9 and 10 (the only writes), confirm in plain English first:

| Operation | Confirmation prompt |
|---|---|
| Pause campaign | "I'm about to **pause** campaign **[CampaignName]** (ID [CID]). It will stop showing ads immediately. OK?" |
| Resume campaign | "I'm about to **resume** campaign **[CampaignName]**. It will start showing ads again as soon as Google processes the change. OK?" |
| Change daily budget | "I'm about to change the daily budget of campaign **[CampaignName]** from **$[old]** to **$[new]**. This affects your spend starting tomorrow. OK?" |

Per-write call, not per-session. Reads after a confirmed write don't re-trigger.

### Step 2.0 — Refresh access token (called automatically by every tool)

```bash
CREDS="$HOME/.config/google-ads/credentials.json"
EXPIRES_AT="$(jq -r .expires_at "$CREDS")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$NOW" \> "$EXPIRES_AT" ] 2>/dev/null; then
  CLIENT_ID="$(jq -r .client_id "$CREDS")"
  CLIENT_SECRET="$(jq -r .client_secret "$CREDS")"
  REFRESH_TOKEN="$(jq -r .refresh_token "$CREDS")"

  RESP="$(curl -sf https://oauth2.googleapis.com/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$REFRESH_TOKEN" \
    -d "grant_type=refresh_token")"

  NEW_AT="$(echo "$RESP" | jq -r .access_token)"
  NEW_EXP="$(python3 -c 'import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$(echo "$RESP" | jq -r .expires_in)")"

  jq --arg at "$NEW_AT" --arg exp "$NEW_EXP" '.access_token=$at | .expires_at=$exp' "$CREDS" > "$CREDS.tmp"
  chmod 600 "$CREDS.tmp"
  mv "$CREDS.tmp" "$CREDS"
fi

ACCESS_TOKEN="$(jq -r .access_token "$CREDS")"
DEV_TOKEN="$(jq -r .developer_token "$CREDS")"
CID="$(jq -r .customer_id "$CREDS")"
```

### Common Pattern 1 — Spend this month

```bash
gaql_call() {
  local query="$1"
  curl -sf "https://googleads.googleapis.com/v17/customers/$CID/googleAds:search" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "developer-token: $DEV_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg q "$query" '{query:$q}')"
}

gaql_call "SELECT metrics.cost_micros FROM customer WHERE segments.date DURING THIS_MONTH"
```

Response: `{ "results": [{ "metrics": { "costMicros": "<n>" } }] }`. Divide `costMicros` by 1,000,000 to get the currency unit. Present as "$X.XX this month."

**Use when:** "what's my Google Ads spend?", "how much have I spent this month?"

### Common Pattern 2 — Top campaigns by conversions (last 30 days)

```bash
gaql_call "SELECT campaign.name, metrics.conversions, metrics.cost_micros FROM campaign WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.conversions DESC LIMIT 10"
```

Present as a table with Campaign / Conversions / Cost / Cost per Conversion.

**Use when:** "best campaigns?", "top performers?", "what's working?"

### Common Pattern 3 — Keyword performance

```bash
gaql_call "SELECT ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type, metrics.clicks, metrics.cost_micros, metrics.conversions FROM keyword_view WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.clicks DESC LIMIT 25"
```

Filter client-side for `ad_group_criterion.status = 'ENABLED'` to show only active keywords.

**Use when:** "my keywords", "keyword performance", "what keywords are driving clicks?"

### Common Pattern 4 — Search terms triggering my ads

```bash
gaql_call "SELECT search_term_view.search_term, metrics.clicks, metrics.cost_micros FROM search_term_view WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.clicks DESC LIMIT 25"
```

**Use when:** "what searches show my ads?", "search terms report", "what are people searching to find me?"

### Common Pattern 5 — Ad-level performance

```bash
gaql_call "SELECT ad_group_ad.ad.id, ad_group_ad.ad.responsive_search_ad.headlines, metrics.clicks, metrics.conversions FROM ad_group_ad WHERE segments.date DURING LAST_30_DAYS AND ad_group_ad.status = 'ENABLED' ORDER BY metrics.clicks DESC LIMIT 10"
```

The `responsive_search_ad.headlines` field is an array of text variations. Present the first 2-3 headlines per ad with metrics.

**Use when:** "my ads", "best ads", "ad performance", "which ads are working?"

### Common Pattern 6 — This month vs last month

Two queries, present side-by-side:

```bash
gaql_call "SELECT metrics.cost_micros, metrics.conversions, metrics.clicks FROM customer WHERE segments.date DURING THIS_MONTH"
gaql_call "SELECT metrics.cost_micros, metrics.conversions, metrics.clicks FROM customer WHERE segments.date DURING LAST_MONTH"
```

Compute deltas client-side.

**Use when:** "compare to last month", "month over month", "is performance improving?"

### Common Pattern 7 — Audience performance

```bash
gaql_call "SELECT campaign.name, ad_group.name, metrics.clicks, metrics.conversions FROM audience WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.conversions DESC LIMIT 15"
```

**Use when:** "audience report", "which audiences convert?"

### Common Pattern 8 — List all campaigns

```bash
gaql_call "SELECT campaign.id, campaign.name, campaign.status, campaign_budget.amount_micros FROM campaign ORDER BY campaign.name"
```

Returns id, name, ENABLED/PAUSED/REMOVED status, daily budget. Present as a table.

**Use when:** "list my campaigns", "show all campaigns", "campaign summary"

### Common Pattern 9 — Pause or resume a campaign (write, gated)

`MODE=basic`: run Gate 2 first.

```bash
CAMPAIGN_ID="<the id>"
NEW_STATUS="PAUSED"  # or "ENABLED" to resume

curl -sf "https://googleads.googleapis.com/v17/customers/$CID/campaigns:mutate" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "developer-token: $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg rn "customers/$CID/campaigns/$CAMPAIGN_ID" --arg st "$NEW_STATUS" \
    '{operations:[{update:{resourceName:$rn, status:$st}, updateMask:"status"}]}')"
```

Response includes the resource name and confirmation. Tell the participant *"Campaign **[Name]** is now paused."* — never imply ads have stopped showing instantly (Google's edge cache can take a few minutes).

**Use when:** "pause X", "resume X", "stop my ads"

### Common Pattern 10 — Change daily budget (write, gated)

`MODE=basic`: run Gate 2 first.

Daily budgets live on a `campaign_budget` resource (separate from the campaign). To change a campaign's budget:

```bash
# 1. Find the budget ID
BUDGET_RES="$(gaql_call "SELECT campaign_budget.resource_name FROM campaign WHERE campaign.id = $CAMPAIGN_ID" | jq -r '.results[0].campaignBudget.resourceName')"

# 2. Mutate it (amount in micros — multiply dollar amount by 1,000,000)
NEW_MICROS="$(( NEW_DAILY_USD * 1000000 ))"

curl -sf "https://googleads.googleapis.com/v17/customers/$CID/campaignBudgets:mutate" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "developer-token: $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg rn "$BUDGET_RES" --argjson m "$NEW_MICROS" \
    '{operations:[{update:{resourceName:$rn, amountMicros:($m|tostring)}, updateMask:"amount_micros"}]}')"
```

**Use when:** "increase budget for X", "lower spend on X", "set daily budget to $Y"

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "What's my Google Ads spend?" / "How much have I spent?" | Pattern 1 |
| "Best campaigns?" / "Top performers?" | Pattern 2 |
| "My keywords" / "Keyword performance" | Pattern 3 |
| "Search terms report" / "What searches trigger my ads?" | Pattern 4 |
| "My ads" / "Which ads are working?" | Pattern 5 |
| "Compare to last month" / "Month over month" | Pattern 6 |
| "Audience report" | Pattern 7 |
| "List my campaigns" | Pattern 8 |
| "Pause X" / "Resume X" / "Stop my ads" | Pattern 9 (gated) |
| "Increase budget" / "Change daily budget" | Pattern 10 (gated) |
| "What's my ROAS?" | Pattern 2 with derived metric: `conversions_value / cost_micros` |
| "Connect Google Ads" / "Help me set up Google Ads" | **Run Phase 0** |
| "Check my Google Ads approval" | **Run Phase 0.3** |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `UNAUTHENTICATED` | Access token expired | Run Step 2.0 (refresh) and retry once |
| HTTP 401 `PERMISSION_DENIED` and message includes "developer token" | Test dev token used against a real (non-test) customer, or Basic Access not approved yet | If `MODE=test`, tell the participant: *"I can only see test accounts right now. Want me to apply for real-data access? Takes 1 to 3 business days."* If `MODE=pending-basic`, repeat the application-pending message. |
| HTTP 403 `CUSTOMER_NOT_ENABLED` | The Google Ads account is not active (e.g., suspended for billing) | Tell the participant: *"Your Google Ads account looks inactive — Google probably wants billing info. Open ads.google.com in your browser to fix it, then ping me."* |
| HTTP 400 `INVALID_ARGUMENT` and `query` in message | GAQL syntax error | Diagnose silently, retry with corrected query, fall back to plain English if can't fix |
| HTTP 400 `RESOURCE_EXHAUSTED` | Rate limit (Basic Access: 15,000 ops/day) | Tell the participant: *"Google's asking me to slow down — let me wait a minute and try again."* Sleep 60, retry once. |
| HTTP 429 | Per-second rate cap | Exponential backoff: 1s, 2s, 4s. Three retries then surface. |
| Refresh token revoked (HTTP 400 with `invalid_grant` on refresh) | Participant revoked Google's permission grant | Tell the participant: *"Looks like the connection was disconnected at your end. Let me reconnect."* Run Phase 1 from Step 7 (re-OAuth). |

Translate every error to plain English. Never show raw HTTP bodies to the participant.

---

## Scope Limitations

This connector **can**:

- Read all standard reporting resources (`customer`, `campaign`, `ad_group`, `ad_group_ad`, `keyword_view`, `search_term_view`, `audience`, plus the report-specific resources `geographic_view`, `paid_organic_search_term_view`, etc. — anything queryable via GAQL via `googleAds:search` or `googleAds:searchStream`).
- Pause / resume campaigns and ad groups via the `mutate` endpoints.
- Change campaign budget daily amounts via the `campaignBudgets:mutate` endpoint.

It **cannot** access:

- **Standard Access tier features** — that's a separate Google approval beyond Basic Access; tracked as a future issue. Most workshop participants will not need it.
- **Bulk uploads / bulk mutates** (the `BulkMutateRequest` endpoint) — not in v1; tracked as future.
- **Manager-account-level admin** (creating sub-accounts, billing, account-level changes) — separate flow, not in v1.
- **Conversion-tracking setup** — creating goals, tags, audiences requires the Conversion Action APIs which are not in v1's 10 patterns.
- **Ad-asset upload** (images, videos for image ads) — requires multipart upload to `Asset:mutate`; not in v1.

It **requires** at least one operating Google Ads customer the participant has access to. Manager-only logins with no operating account underneath will fail at Step 10.

---

## Behaviour Guidelines (Phase 2)

- **Mode awareness** — `MODE=test` is freely callable; `MODE=basic` applies Gate 1 (once per session) and Gate 2 (every write). `MODE=pending-basic` behaves as `test` data-wise but on the participant's "check my approval" prompt, run Phase 0.3.
- **Always present money in real units** — divide `costMicros` and `amountMicros` by 1,000,000. Use the account's currency (read from `customer.currency_code` if needed).
- **Date ranges in GAQL** — supported tokens: `TODAY`, `YESTERDAY`, `LAST_7_DAYS`, `LAST_14_DAYS`, `LAST_30_DAYS`, `LAST_BUSINESS_WEEK`, `LAST_WEEK_SUN_SAT`, `LAST_WEEK_MON_SUN`, `THIS_MONTH`, `LAST_MONTH`, `THIS_QUARTER`, `LAST_QUARTER`, `ALL_TIME`. For arbitrary ranges, use `segments.date BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`.
- **Status filter** — by default skip REMOVED entities (they're soft-deleted). Add `WHERE campaign.status != 'REMOVED'` etc.
- **Auth errors** → run Step 2.0 (refresh), retry; if refresh fails, re-run Phase 1 from Step 7.
- **Never log or echo credentials** — `client_id`, `client_secret`, `developer_token`, `access_token`, `refresh_token` are sensitive. None of them appears in any output visible to the participant.
- **MODE=basic destructive ops** — every write triggers Gate 2 before the API call. No silent writes.

---

## Related Skills

- **`paid-ads`**: The strategy advisor. Pair when the participant wants advice on what to DO with the data the connector returns. The advisor asks "what's working?" and Claude uses this connector to answer factually.
- **`quickbooks-connector`**: Same Phase 0 / Phase 1 Playwright-driven autonomous pattern as the SelrAI canonical. QBO's Phase 1L lives-tier work (Cloudflare Pages + tunnel) is heavier than this connector's Phase 1L (Google Ads' API Center is in-portal only).
- **`myob-connector`**: The Direct-REST + Playwright reference SKILL this connector models its Phase 1 on. Loopback listener pattern, atomic `credentials.json` write pattern, and refresh-on-call pattern all borrowed from MYOB.
- **`ghl-connector`**: The other direct-REST sibling. Wraps the GHL hosted MCP (so its frontmatter says Hosted-bearer-PAT pattern), but the Phase 1 shape is closer to direct-REST than Pattern 1 / 2. Reference for the Playwright-driven autonomous-Phase-1 communication rules.
- **`superpowers:systematic-debugging`**: For troubleshooting OAuth flow failures or unexpected GAQL responses.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) — the three-pattern decision tree (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace). This SKILL is explicitly out of scope for that doc (it's a direct-REST connector); follow `myob-connector`'s shape as the closest canonical reference.
- [Google Ads API reference](https://developers.google.com/google-ads/api/docs/start) — the official source of GAQL grammar, resource shapes, and rate limits.
- [Google Ads API Center](https://ads.google.com/aw/apicenter) — where Phase 1T and Phase 1L dev tokens come from.
- Memory `reference_playwright_snapshot_password_leak` — sign-in page snapshot rule (applies to Google Cloud, Google Ads, and the consent screen alike).
- Memory `feedback_workshop_kit_update_format` — say "test mode" to participants, not "sandbox".
