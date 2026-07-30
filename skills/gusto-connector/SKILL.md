---
name: gusto-connector
description: "Connect Gusto to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect Gusto, or wants payroll work (employees, pay schedules, payroll history, compensation, paychecks, time off) and the Gusto credentials aren't in place yet. Once connected, Gusto runs directly against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - gusto
    - payroll
    - employees
    - time-off
    - hr
    - rest-api
    - oauth
  pairs-with:
    - skill: quickbooks-connector
      reason: Sibling Phase 0 mode-detection + Phase 1 Playwright-driven autonomous install. QBO is accounting; Gusto is the payroll side of the same SMB operations.
    - skill: google-ads-connector
      reason: Sibling Tier-1 Direct-REST connector with the same test/live mode-detection split (Demo vs Production for Gusto; Test vs Basic Access for Google Ads).
    - skill: myob-connector
      reason: Reference SKILL for Direct-REST + Playwright pattern (loopback OAuth listener, atomic credentials.json, bearer-on-curl Phase 2).
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting Gusto API auth or partner-app approval edge cases.
---

# Gusto Connector

## Overview

This skill lets you read and operate a user's Gusto payroll account on their behalf using **Gusto API v1 REST endpoints** (no MCP server, no first-party CLI - Direct-REST + Playwright pattern, sibling to `myob-connector` and `google-ads-connector`).

It is a Tier-1 connector aimed at **US SMBs running W-2 payroll** - the data it reads (EIN, USD pay, W-2 employees, US pay schedules) is US-payroll-shaped throughout.

It has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright + REST).** Claude drives `dev.gusto.com` (Demo mode) or `dev.gusto.com` Production tab via Playwright MCP to sign the participant in, create a Partner Application, capture client_id + client_secret + redirect_uri configuration, run the OAuth2 authorization-code flow via a local loopback listener on `localhost:8765`, exchange the code for access_token + refresh_token, list accessible companies, and persist everything to `~/.config/gusto/credentials.json` (mode 0600). The participant's manual moments: signing in to Gusto once + approving the OAuth consent screen.
- **Phase 2 - Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Gusto REST endpoints with `Authorization: Bearer <access_token>`. The base URL switches between `https://api.gusto-demo.com/v1/` (Demo mode) and `https://api.gusto.com/v1/` (Production mode) based on `mode` in credentials.json. Writes are gated by production-mode confirmation prose.

**Two modes, picked at Phase 0:**

| Mode | When | What it touches | Wait |
|---|---|---|---|
| **Demo** | Default for first-time install; recommended for "I want to try it today." | Demo company data on api.gusto-demo.com - fake employees, fake paychecks, fake time-off. No real money, no real PII. | Immediate (Gusto auto-creates a Partner Application; the participant manually creates a Demo Company at `/demo_companies/new` - separate one-page wizard with name + admin email + password). |
| **Production** | When the participant says "I want to see my real payroll data." | Real Gusto company on api.gusto.com - real employees, real money. | 1-2 week review by Gusto's partner-app team. Application must explain the use case. |

**Demo-by-default is the right framing** (unlike QBO where Production-Development tier is immediate). Gusto's Production review is a 1-2 week wait; the SKILL defaults to Demo so participants can use the connection today, with Production as an explicit upgrade path.

**Which phase to run** - Before any tool call:

```bash
test -f "$HOME/.config/gusto/credentials.json" && jq -r '.mode // "missing"' "$HOME/.config/gusto/credentials.json" 2>/dev/null || echo missing
```

- `demo` or `production` → credentials present. Smoke-test (`GET /v1/token_info`); on success → Phase 2 with appropriate gates. Captured 2026-06-02: `/v1/me` returns `404 not_found` on the current Gusto API version; `/v1/token_info` is the canonical token + resource introspection endpoint.
- `pending-production` → Production application submitted, waiting for Gusto review. Phase 0 polls status; falls through to Phase 2 in Demo mode meanwhile.
- `missing` → run Phase 0 + Phase 1.

---

## Golden rule - do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside the Playwright MCP browser. Never tell the participant to "open a link in your browser." Claude navigates; the participant types passwords directly into the Playwright window. Same as `myob-connector` and `quickbooks-connector`.

If Playwright MCP is unavailable, halt and point the participant at the install instructions; do not fall back to opening their default browser.

---

## Communication rules for Phase 1

The participant is a non-technical business owner (and Gusto specifically - they're probably an HR admin or business owner who runs payroll). Plain English only:

- **One step at a time.** Never stack instructions.
- **Plain English only.** Never say API, token, OAuth, scope, refresh, Bearer, endpoint, JSON, env var, curl, terminal, CLI, MCP, callback, loopback, partner app, redirect URI, sandbox, file path. If you must, name plainly: "your connection key", "your Gusto account details", "the workshop setup step".
- **Tell them what is about to happen.** *"I'm opening Gusto's developer settings now - sign in when you see the page. About 90 seconds total."*
- **React warmly.** Good: *"Connected to your demo Gusto with **3 employees** loaded."* Bad: *"OAuth exchange returned 200, refresh_token persisted to disk."*
- **Never show error messages directly.** Translate.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo credentials** - client_id, client_secret, access_token, refresh_token.

---

## ⛔ Pre-flight check

Verify Playwright MCP tools are available (`ToolSearch +playwright`). If absent, halt; do not start Phase 0.

---

## PHASE 0 - Mode + state detection

### Step 0.1 - Read existing credentials

```bash
CREDS="$HOME/.config/gusto/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.mode // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

States:

- `missing` → continue to Step 0.2.
- `demo` → Phase 2 with no gates (fake data).
- `production` → Phase 2 with real-data gate + per-write gate.
- `pending-production` → Production application in flight; poll Gusto for status (Step 0.3) or fall through to Phase 2 in Demo mode while waiting.

### Step 0.2 - Ask Demo or Production

> "Want me to start in **demo mode** so you can use the connection today (fake payroll data, no real money), or do you want **real payroll data** for your actual Gusto account? Real data needs Gusto to approve me first - they usually take 1 to 2 weeks. Most people pick demo first to play with the features."

Map the reply:

- "demo", "test", "today", "play", default → `MODE=demo` → Phase 1 (Demo path).
- "real", "live", "production", "actual" → `MODE=production` → Phase 1 (Production path), set expectation about the 1-2 week wait.

Do NOT say "sandbox" to the participant - say "demo".

### Step 0.3 - Check Production application status (when state = pending-production)

```bash
APPLIED_AT=$(jq -r '.production_application.applied_at' "$CREDS")
DAYS_AGO=$(python3 -c "import datetime,sys;a=datetime.datetime.fromisoformat(sys.argv[1].rstrip('Z'));print(int((datetime.datetime.utcnow()-a).days))" "$APPLIED_AT")
echo "Applied $DAYS_AGO days ago"
```

- < 5 days: *"Gusto's still reviewing - they usually take 1 to 2 weeks. Want to use demo mode in the meantime?"*
- 5+ days: drive Playwright to dev.gusto.com to check application status; if approved, capture the Production credentials, flip `mode=production`, jump to Phase 2.

---

## PHASE 1 - Install & Connect

### Step 1 - Welcome

> "Great - connecting your Gusto. Three quick things:
> 1. Sign in to Gusto when I open the developer page.
> 2. Approve the connection when it asks.
> 3. If this is your first time, Gusto will create a demo company automatically.
> About 90 seconds total."

### Step 2 - Open Gusto developer portal

For Demo mode:

```
mcp__playwright__browser_navigate({ url: "https://dev.gusto.com/applications" })
```

`browser_wait_for({ text: "Applications", time: 60 })` (NOT snapshot - password-leak rule). If the participant has multiple Gusto identities (admin, accountant), the dev portal lands on a personal-developer dashboard regardless.

For Production mode: same URL - the dev portal hosts both Demo and Production app settings as separate tabs after sign-in.

### Step 3 - Create or find a Partner Application

The Applications page shows existing apps + a `Create application` (or `New application`) button.

Idempotent: check if `Claude Workshop Connector` already exists:

```js
() => {
  const rows = Array.from(document.querySelectorAll('a, tr, .application-card'));
  const existing = rows.find(r => /claude workshop connector/i.test((r.innerText||'').trim()));
  if (existing) {
    existing.click();
    return { existed: true };
  }
  const create = Array.from(document.querySelectorAll('button, a')).find(b => /^(create|new)\s+application/i.test((b.innerText||'').trim()));
  if (create) {
    create.click();
    return { existed: false, clicked_create: true };
  }
  return { ok: false, reason: 'no_create_button' };
}
```

If creating a new app, fill the form via React-friendly setter:

| Field | Value |
|---|---|
| Application name | `Claude Workshop Connector` |
| Application website | (any HTTPS URL - placeholder OK in Demo mode: `https://localhost/` works) |
| Redirect URI | `http://localhost:8765/callback` |
| Category | Pick `Other` (closest neutral choice; SKILL not building a vertical-specific integration) |
| Disable Gusto's time tracking | leave **unchecked** (we're not building a time-tracking integration) |

> **Captured 2026-06-02 - there is NO scope picker on the Create Application form.** The SKILL's earlier prose said scopes are selected at app creation; that's wrong. Demo Partner Apps auto-default to scope set `public webhook_subscriptions:read webhook_subscriptions:write`. Empirically the `public` scope alone is sufficient for the Phase 2 Demo reads (companies, employees, payrolls, leave balances, leave requests, etc.). Production apps may need explicit scope review by Gusto - verify at the first Production-mode smoke.

For Demo mode, Gusto issues credentials immediately. For Production mode, a "Submit for review" button appears after save - clicking it triggers the 1-2 week review.

**When Production review is kicked off**, persist a partial credentials.json immediately so Phase 0.3 can poll for approval on future sessions:

```bash
mkdir -p "$HOME/.config/gusto"
chmod 700 "$HOME/.config/gusto"
umask 077

# Capture client_id/client_secret already via Step 4 below; here we ALSO record the pending-production marker
APPLIED_AT="$(python3 -c 'import datetime; print(datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))')"

jq -n \
  --arg cid "$CLIENT_ID" \
  --arg csec "$CLIENT_SECRET" \
  --arg ap "$APPLIED_AT" \
  '{mode:"pending-production",
    client_id:$cid, client_secret:$csec,
    api_endpoint:"https://api.gusto.com/v1",
    production_application:{applied_at:$ap, status:"submitted"}}' \
  > "$HOME/.config/gusto/credentials.json.tmp"
chmod 600 "$HOME/.config/gusto/credentials.json.tmp"
mv "$HOME/.config/gusto/credentials.json.tmp" "$HOME/.config/gusto/credentials.json"
```

(The full token write happens in Step 9 once Gusto approves and OAuth completes. Until then `access_token`/`refresh_token`/`company_uuid`/`expires_at` are absent from the file - Phase 0.3 detects this absence to know the application is still pending.)

Optionally, in Production mode, also drop the participant into Demo mode in parallel so they have a working connection while waiting: run the rest of Phase 1 against the Demo tab as a fallback (`MODE=demo` for the actual token capture path), and store the demo tokens alongside the pending-production marker. Phase 2 uses Demo creds; Phase 0.3 watches for Production approval.

### Step 4 - DOM-extract client_id and client_secret via clipboard transit

Captured 2026-06-02: navigate to the app's detail page `https://dev.gusto.com/applications/<app-uuid>`. The Client ID and Secret are both shown as masked `*****` values with `Reveal` toggle buttons + `Copy`/`Hide` buttons inline. **Click both Reveal buttons first**, then DOM-extract via a value-only span filter (NOT the parent div whose `innerText` slurps in the adjacent button labels).

Save the participant's prior clipboard first:

```bash
SAVED=$(wl-paste 2>/dev/null | base64 -w0)
echo "$SAVED" > /tmp/gusto-prev-clipboard.b64
```

Extract:

```js
async () => {
  // 1. Click both Reveal buttons (no-op if already revealed)
  const reveals = Array.from(document.querySelectorAll('button')).filter(b => /^reveal$/i.test((b.innerText||'').trim()) && b.offsetWidth > 0);
  reveals.forEach(b => b.click());
  await new Promise(r => setTimeout(r, 700));

  // 2. Find Client ID / Secret labels
  const labelEls = Array.from(document.querySelectorAll('*'))
    .filter(el => /^(client id|secret)$/i.test((el.innerText||'').trim()));
  const out = {};
  for (const label of labelEls) {
    const which = /id/i.test(label.innerText) ? 'client_id' : 'client_secret';
    if (out[which]) continue;
    // 3. CRITICAL: look for value-only <span> elements (NOT div.innerText - that slurps Copy/Hide button labels and concatenates them to the value)
    let scope = label.parentElement;
    for (let d = 0; d < 3 && scope && !out[which]; d++) {
      const valueSpans = Array.from(scope.querySelectorAll('span')).filter(s => {
        const t = (s.innerText||'').trim();
        return t.length >= 30 && /^[A-Za-z0-9_.\-]+$/.test(t);
      });
      if (valueSpans.length) { out[which] = valueSpans[0].innerText.trim(); }
      scope = scope.parentElement;
    }
  }
  if (!out.client_id || !out.client_secret) return { ok: false, found: Object.keys(out) };
  await navigator.clipboard.writeText(JSON.stringify(out));
  return { ok: true, client_id_len: out.client_id.length, client_secret_len: out.client_secret.length };
}
```

> **Captured 2026-06-02 - value-only span filter is required.** The credentials are wrapped in a parent `<div>` whose `innerText` is `<value>CopyHide` (the `Copy` and `Hide` button labels concatenate into the parent's text content). An earlier broader extract that walked `span, div, code` indiscriminately captured `tUj8...UU8CopyHide` as the client_id, which then failed the OAuth `client_authentication_failed` check. The fix: filter ONLY for `<span>` whose `innerText` matches the alphanumeric shape AND has no adjacent button-label contamination.
>
> Captured client_id and secret are both **43 chars** (not 32/64 as the SKILL's earlier prose projected) - both alphanumeric with `_` and `-` allowed.

Returns only the lengths. Tool output never contains the values; clipboard holds them for Step 8 below.

### Step 4.5 - Create a Demo Company (one-time, separate flow)

**Captured 2026-06-02 - Demo Companies are NOT auto-provisioned on first app creation.** The SKILL's earlier prose implied they were. Reality: the participant must manually create one at `dev.gusto.com/demo_companies/new`. Each Demo Company is its own isolated environment with its own admin email + password.

Navigate:

```
mcp__playwright__browser_navigate({ url: "https://dev.gusto.com/demo_companies/new" })
```

Form fields:

| Field | Value |
|---|---|
| Demo company name | `Selr AI Demo Co` (or other workshop-appropriate name) |
| Email | A **fresh email** the participant doesn't use elsewhere - plus-alias works: `<their-email>+gusto-demo@<domain>` |
| Password | The participant chooses + types directly into the Playwright window (don't auto-fill - it's a real credential they'll need to OAuth-sign-in with in Step 6) |
| Password confirmation | Same |

Submit. The Demo Company enters `generating` status; Gusto says "allow a few minutes for the account to be created." Poll until status flips to `finished`:

```bash
# Check via Playwright: navigate to /demo_companies and look for "finished" next to the company name
until mcp__playwright__browser_evaluate(...) returns status="finished"; do sleep 30; done
```

Typical generation time: ~30-90 seconds. The status table on `/demo_companies` shows columns: `Name | Admin email | Status | Date created`. Filter for `Status: finished`.

> **Quota**: Gusto allows up to 3 Demo Company creations per day per developer account. If a participant hits this limit, they can use an existing Demo Company (find it on `/demo_companies`).

### Step 5 - Start loopback listener for OAuth callback

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
    self.wfile.write(b'<h1>Gusto connected. You can close this tab.</h1>')
    with open('/tmp/gusto-auth-code', 'w') as f: f.write(code)
    sys.exit(0)
http.server.HTTPServer(('127.0.0.1', $PORT), H).serve_forever()
" > /tmp/gusto-listener.log 2>&1 &
echo $! > /tmp/gusto-listener.pid
echo "$PORT" > /tmp/gusto-listener.port
```

> **Port note**: If port 8765 is taken, the listener increments. The Redirect URI registered on the Gusto Partner App in Step 3 is `http://localhost:8765/callback` - if a higher port was needed, you must update the redirect URI on the dev portal too (via Playwright, re-edit the app's redirect URI field). For Demo mode this is usually fine since 8765 is rarely contended.

### Step 6 - Drive OAuth consent flow

```bash
CLIENT_ID="$(wl-paste | jq -r '.client_id')"
PORT="$(cat /tmp/gusto-listener.port)"
# Demo: api.gusto-demo.com (note dashed top-level); Production: api.gusto.com
AUTH_HOST=$([ "$MODE" = "production" ] && echo "api.gusto.com" || echo "api.gusto-demo.com")
# Captured 2026-06-02: scope parameter is OPTIONAL - omitting it lets Gusto grant the app's default scopes (public + webhook_subscriptions:read/write for Demo apps), which is sufficient for the Phase 2 Demo reads. For Production, scopes may need to be explicitly listed and pre-approved by Gusto's partner-review process.
AUTH_URL="https://${AUTH_HOST}/oauth/authorize?client_id=${CLIENT_ID}&redirect_uri=http%3A%2F%2Flocalhost%3A${PORT}%2Fcallback&response_type=code"
```

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Three page states:

- **Consent screen rendered** ("Allow Claude Workshop Connector to access...") → click **Allow** via `browser_evaluate`.
- **Already signed in + auto-redirect** → callback hits `localhost:$PORT/callback?code=...`, listener captures.
- **Company selector** (if participant has multiple Gusto companies on this identity) → pick the first (or the participant's primary).

Poll `/tmp/gusto-auth-code`:

```bash
for i in $(seq 1 90); do
  [ -s /tmp/gusto-auth-code ] && break
  sleep 2
done
AUTH_CODE="$(cat /tmp/gusto-auth-code)"
```

### Step 7 - Exchange code for tokens

```bash
CLIENT_ID="$(wl-paste | jq -r '.client_id')"
CLIENT_SECRET="$(wl-paste | jq -r '.client_secret')"

RESP="$(curl -sf "https://${AUTH_HOST}/oauth/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://localhost:$PORT/callback" \
  -d "grant_type=authorization_code")"

# Tear down listener
kill "$(cat /tmp/gusto-listener.pid)" 2>/dev/null
rm -f /tmp/gusto-auth-code /tmp/gusto-listener.pid /tmp/gusto-listener.port /tmp/gusto-listener.log
```

Response JSON has `access_token`, `refresh_token`, `token_type` (`Bearer`), `expires_in` (typically 7200s = 2 hours), `scope`.

### Step 8 - Discover companies

```bash
ACCESS_TOKEN="$(echo "$RESP" | jq -r .access_token)"
COMPANIES="$(curl -sf "https://${AUTH_HOST}/v1/token_info" -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.resource | select(.type == "Company") | .uuid')"
```

**Captured 2026-06-02 - use `/v1/token_info`, NOT `/v1/me`.** The SKILL's earlier prose called for `/v1/me` which returns `404 not_found` on the current Gusto API version. The canonical endpoint is `/v1/token_info` which returns `{scope, resource: {type, uuid}, resource_owner: {type, uuid}}`. For Demo apps, `resource.type` is `Company` and `resource.uuid` is the Demo Company UUID. For production multi-company partners, may need a different discovery shape - verify at first Production-mode smoke.

- **One company** → silently pick it.
- **Multiple companies** → ask the participant which one to connect (rare for SMBs; common for accountants/bookkeepers).
- **Zero companies** → in Demo mode this means Gusto's auto-demo-company wasn't provisioned; create one via dev.gusto.com → Demo Companies → New Demo Company.

### Step 9 - Save `credentials.json`

```bash
mkdir -p "$HOME/.config/gusto"
chmod 700 "$HOME/.config/gusto"
umask 077

EXPIRES_AT=$(python3 -c "import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))" "$(echo "$RESP" | jq -r .expires_in)")

jq -n \
  --arg mode "$MODE" \
  --arg cid "$CLIENT_ID" \
  --arg csec "$CLIENT_SECRET" \
  --arg at "$(echo "$RESP" | jq -r .access_token)" \
  --arg rt "$(echo "$RESP" | jq -r .refresh_token)" \
  --arg cuuid "$COMPANY_UUID" \
  --arg ep "https://${AUTH_HOST}/v1" \
  --arg exp "$EXPIRES_AT" \
  '{mode:$mode, client_id:$cid, client_secret:$csec, access_token:$at, refresh_token:$rt,
    expires_at:$exp, company_uuid:$cuuid, api_endpoint:$ep}' \
  > "$HOME/.config/gusto/credentials.json.tmp"
chmod 600 "$HOME/.config/gusto/credentials.json.tmp"
mv "$HOME/.config/gusto/credentials.json.tmp" "$HOME/.config/gusto/credentials.json"

# Restore prior clipboard
[ -s /tmp/gusto-prev-clipboard.b64 ] && base64 -d /tmp/gusto-prev-clipboard.b64 | wl-copy
rm -f /tmp/gusto-prev-clipboard.b64

unset CLIENT_ID CLIENT_SECRET ACCESS_TOKEN RESP
```

### Step 10 - Smoke test

```bash
ACCESS_TOKEN="$(jq -r .access_token "$HOME/.config/gusto/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/gusto/credentials.json")"
CUUID="$(jq -r .company_uuid "$HOME/.config/gusto/credentials.json")"

curl -sf "$API_ENDPOINT/companies/$CUUID" -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.name + " (" + .uuid + ")"'
```

Expect: a company name like `Acme Demo Company (abc-...)` for Demo mode, or the participant's real company for Production. Tell the participant:

> "All connected - your Gusto **[company name]** is ready. Ask me things like *'list my employees'* or *'show me the last payroll'*."

---

## PHASE 2 - Use Tools

Every call:

1. Reads `credentials.json`.
2. Checks `expires_at`; if expired, refreshes via Step 2.0 below.
3. Calls Gusto REST with `Authorization: Bearer <access_token>`.
4. Applies mode-aware gates.

### Mode-aware behaviour

- `MODE=demo` - fake data, freely callable. No gates.
- `MODE=production` - real employees, real money. **Real-data gate** + **destructive-op gate** apply.
- `MODE=pending-production` - same data path as Demo (Demo credentials in use while Gusto reviews); when participant says "check my Gusto approval", run Phase 0.3.

### Production-mode gate 1 - Real-data confirmation (first call per session, MODE=production)

Fetch company name silently:

```bash
curl -sf "$API_ENDPOINT/companies/$CUUID" -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r .name
```

Tell participant:

> "Just confirming - you're connected to your real Gusto company **[Company Name]** with **[N]** employees. Anything I do here is on your live payroll data. OK to proceed with **[summary]**?"

ONCE per session.

### Production-mode gate 2 - Destructive-op confirmation (every write, MODE=production)

For Patterns 9-10 (approve / deny time-off):

| Operation | Prompt |
|---|---|
| Approve time-off | "I'm about to **approve** **[Employee Name]**'s time-off request: **[N hours]** of **[type]** starting **[date]**. This adds it to their pay record. OK?" |
| Deny time-off | "I'm about to **deny** **[Employee Name]**'s time-off request: **[N hours]** of **[type]** starting **[date]**. They'll see the denial in their Gusto inbox. OK?" |

Per-write call.

### Step 2.0 - Refresh access token

```bash
CREDS="$HOME/.config/gusto/credentials.json"
EXPIRES_AT="$(jq -r .expires_at "$CREDS")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$NOW" \> "$EXPIRES_AT" ] 2>/dev/null; then
  CLIENT_ID="$(jq -r .client_id "$CREDS")"
  CLIENT_SECRET="$(jq -r .client_secret "$CREDS")"
  REFRESH_TOKEN="$(jq -r .refresh_token "$CREDS")"
  HOST="$(jq -r .api_endpoint "$CREDS" | sed -E 's|^https?://([^/]+)/?.*|\1|')"

  RESP="$(curl -sf "https://${HOST}/oauth/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=$CLIENT_ID" -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$REFRESH_TOKEN" -d "grant_type=refresh_token")"

  NEW_AT="$(echo "$RESP" | jq -r .access_token)"
  NEW_RT="$(echo "$RESP" | jq -r .refresh_token)"  # Gusto rotates refresh tokens
  NEW_EXP="$(python3 -c 'import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$(echo "$RESP" | jq -r .expires_in)")"

  jq --arg at "$NEW_AT" --arg rt "$NEW_RT" --arg exp "$NEW_EXP" '.access_token=$at | .refresh_token=$rt | .expires_at=$exp' "$CREDS" > "$CREDS.tmp"
  chmod 600 "$CREDS.tmp"; mv "$CREDS.tmp" "$CREDS"
fi
```

> **Refresh-token rotation**: Gusto rotates refresh tokens on every use, unlike Mailchimp or QBO. Always persist the new refresh token from the response, never reuse the old one.

### Helper - base curl shape

```bash
gusto_get() { curl -sf "$API_ENDPOINT$1" -H "Authorization: Bearer $ACCESS_TOKEN"; }
gusto_put() { curl -sf -X PUT "$API_ENDPOINT$1" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "$2"; }
```

### Common Pattern 1 - Company info

```bash
gusto_get "/companies/$CUUID" | jq '{name, ein: .ein, locations: .locations[].street_1}'
```

Returns name, EIN (tax ID), locations. Present as a 2-3 line summary.

**Use when:** "what company am I connected to?", "Gusto company info"

### Common Pattern 2 - List employees

```bash
gusto_get "/companies/$CUUID/employees" | jq '.[] | {first_name, last_name, email: .work_email, department, jobs: [.jobs[].title]}'
```

Returns active + terminated employees. Add `?terminated=false` to filter.

**Use when:** "list my employees", "show team", "who do I have on payroll?"

### Common Pattern 3 - Pay schedule

```bash
gusto_get "/companies/$CUUID/pay_schedules" | jq '.[] | {frequency, anchor_pay_date, anchor_end_of_pay_period, day_1, day_2}'
```

Returns pay frequency (weekly, biweekly, semimonthly, monthly), anchor dates that calibrate the cycle. Present as a friendly summary: *"You're on a biweekly schedule, next payday Friday October 6."*

**Use when:** "when's next payday?", "pay schedule", "how often do I pay people?"

### Common Pattern 4 - Recent payrolls

```bash
gusto_get "/companies/$CUUID/payrolls?include[]=totals" | jq '.[] | {check_date, period_start: .pay_period.start_date, period_end: .pay_period.end_date, processed: .processed, totals: .totals}'
```

Returns the last ~24 payrolls (default page). Filter for `processed:true` to see only paid ones (not drafts).

**Use when:** "show recent payrolls", "last paycheck"

### Common Pattern 5 - Specific payroll details

```bash
PAYROLL_UUID="<from Pattern 4>"
gusto_get "/companies/$CUUID/payrolls/$PAYROLL_UUID?include[]=employee_compensations" \
  | jq '.employee_compensations[] | {employee: .employee_uuid, gross_pay, net_pay, taxes: .taxes_summary.total_amount}'
```

Returns per-employee gross, net, total taxes for that payroll. Cross-reference with Pattern 2's employee names client-side.

**Use when:** "payroll details for [date]", "what did I pay each person on [date]"

### Common Pattern 6 - Employee compensation

```bash
EMP_UUID="<from Pattern 2>"
gusto_get "/employees/$EMP_UUID/jobs" | jq '.[] | {title, compensations: .compensations | map({rate, payment_unit, flsa_status})}'
```

Returns current pay rate per job (Gusto supports multiple jobs per employee). `payment_unit` = `Hour`, `Year`, `Paycheck`, or `Month`.

**Use when:** "what does [employee] earn?", "[employee]'s pay rate"

### Common Pattern 7 - Year-to-date earnings

```bash
EMP_UUID="<from Pattern 2>"
YEAR="$(date +%Y)"
gusto_get "/employees/$EMP_UUID/payrolls?start_date=${YEAR}-01-01&end_date=$(date +%Y-%m-%d)&include[]=totals" \
  | jq '[.[] | .totals.gross_pay] | add'
```

Sum of gross pay across all payrolls this year. Present as "$X year-to-date".

**Use when:** "[employee] YTD", "year-to-date earnings"

### Common Pattern 8 - List time-off requests

```bash
gusto_get "/companies/$CUUID/time_off_requests?status=pending" | jq '.[] | {employee_uuid, request_type: .request_type.name, start_date, end_date, status, total_hours}'
```

Filter by `status` = `pending`, `approved`, `denied`. Useful for "what's pending for approval?"

**Use when:** "pending time-off", "approval queue", "who's on leave?"

### Common Pattern 9 - Approve time-off (write, gated)

`MODE=production`: run Gate 2 first.

```bash
TOR_UUID="<from Pattern 8>"
gusto_put "/time_off_requests/$TOR_UUID" '{"status":"approved"}'
```

Tells the participant: *"Approved [Employee]'s [N] hours of [type]."*

**Use when:** "approve [employee]'s leave", "approve PTO for [date]"

### Common Pattern 10 - Deny time-off (write, gated)

`MODE=production`: run Gate 2 first.

```bash
TOR_UUID="<from Pattern 8>"
REASON="<optional plain-English denial reason>"
gusto_put "/time_off_requests/$TOR_UUID" "$(jq -n --arg r "$REASON" '{status:"denied", denial_reason:$r}')"
```

**Use when:** "deny [employee]'s leave", "reject this PTO request"

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "Who am I connected to?" / "Gusto company info" | Pattern 1 |
| "List my employees" / "Show team" | Pattern 2 |
| "Pay schedule" / "When's next payday?" | Pattern 3 |
| "Recent payrolls" / "Last paycheck" | Pattern 4 |
| "Payroll details for [date]" | Pattern 5 |
| "[Employee]'s pay rate" / "What does X earn?" | Pattern 6 |
| "[Employee] YTD" / "Year-to-date" | Pattern 7 |
| "Pending time-off" / "Approval queue" | Pattern 8 |
| "Approve [employee]'s leave" | Pattern 9 (gated) |
| "Deny [employee]'s leave" | Pattern 10 (gated) |
| "Connect Gusto" / "Set up Gusto" | **Run Phase 0** |
| "Check my Gusto approval" | **Run Phase 0.3** (only when state=pending-production) |
| "Run payroll" / "Submit payroll" | **NOT in v1** - tell the participant: "Running payroll is too high-stakes for me to do automatically. Please submit it from Gusto's web UI." |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `Unauthorized` | Access token expired | Run Step 2.0 (refresh), retry once |
| HTTP 401 with `invalid_grant` on refresh | Refresh token rotated out / revoked | Tell participant: "Looks like the connection was disconnected. Let me reconnect." Run Phase 1 from Step 5 (re-OAuth). |
| HTTP 403 `Forbidden` on Demo endpoints | Wrong API host (`api.gusto.com` instead of `api.gusto-demo.com` or vice versa) | Check `mode` in credentials.json matches the `api_endpoint` host. |
| HTTP 404 `Resource not found` on `/companies/<uuid>` | Company UUID is wrong or the connected role lost access | Re-run `/v1/token_info` (NOT `/v1/me` - that endpoint doesn't exist on current Gusto API) to refresh accessible companies via `resource.uuid`. |
| HTTP 422 `Validation error` on Pattern 9/10 | Time-off request is no longer pending (already approved/denied by someone else) | Translate: "Looks like that request was already handled. Want me to check the queue again?" |
| HTTP 429 | Per-minute rate cap (200/min default in Demo, 1000/min in Production) | Wait 60s, retry once. Surface plain English if still hitting. |
| Network error to api.gusto.com | DNS / outbound block | Plain English. Mention check VPN / corporate firewall. |

Translate every error to plain English. Never show raw HTTP bodies.

---

## Scope Limitations

This connector **can**:

- Read all standard read endpoints: company, employees, pay schedules, payrolls (history + per-payroll details), employee compensations, time-off requests, locations.
- Approve / deny pending time-off requests.

It **cannot**:

- **Run payroll** - `POST /payrolls/{id}/submit` is explicitly out of v1 scope. Too high-stakes; participant should run payroll from Gusto's web UI. Tracked as a future enhancement with extra gates (multi-stage confirmation, dollar-amount summary, etc.).
- **Onboard new employees** - `POST /employees` requires sensitive PII (SSN, address, bank routing) that's a poor fit for plain-English Phase 2.
- **Modify pay rates** - `PUT /jobs/{id}/compensations` writes affect every future paycheck; v1 keeps these read-only.
- **Issue tax forms** (W-2, 1099) - separate API surface, complex compliance.
- **Run reports on benefits / 401(k)** - separate API endpoints; not in v1's 10 patterns.
- **Production-mode access without partner-app review** - Gusto requires a 1-2 week review for production access. The SKILL kicks off the application in Phase 1 Step 3's Production-tab submit path but cannot bypass the wait. Phase 0.3 polls for approval status on subsequent sessions.

It **requires** the participant to be a payroll admin on the company (other Gusto roles like `manager`, `accountant`, `employee_self_service` have limited or no API access).

---

## Behaviour Guidelines (Phase 2)

- **Mode awareness** - `MODE=demo` is freely callable; `MODE=production` applies Gate 1 (once per session) and Gate 2 (every write). `MODE=pending-production` uses Demo data while the application is in review; the "check my approval" prompt triggers Phase 0.3.
- **Currency presentation** - Gusto returns monetary values as numeric strings ("523.42") in USD. Format as $X.XX in display.
- **Employee names** - payroll responses return employee UUIDs, not names. Cache the employee name → UUID map from Pattern 2 at session start to enrich downstream output.
- **Dates** - Gusto uses ISO-8601 dates (`YYYY-MM-DD`) for pay period bounds.
- **Refresh-token rotation** - every refresh issues a new refresh_token; persist it immediately (Step 2.0 handles this).
- **Auth errors** → run Step 2.0; if refresh fails, re-run Phase 1 from Step 5.
- **Never log or echo credentials** - client_id, client_secret, access_token, refresh_token never appear in participant-visible output.
- **Production writes** - always confirm in plain English. Time-off approvals especially: this changes someone's actual paycheck. Frame the prompt with employee name, hours, and date.

---

## Related Skills

- **`quickbooks-connector`**: Same mode-detection (Demo vs Production for Gusto; sandbox vs Production-Development for QBO) + Phase 1 Playwright-driven autonomous install pattern. QBO is accounting, Gusto is payroll - siblings in the SMB operations stack.
- **`google-ads-connector`**: Same two-mode test/live design. Google Ads has Test Account (instant) + Basic Access (1-3 day review); Gusto has Demo (instant) + Production (1-2 week review). The pending-state Phase 0.3 polling pattern is borrowed from Google Ads.
- **`myob-connector`**: Reference SKILL for Direct-REST + Playwright. Loopback OAuth listener (Step 5), atomic credentials.json write (Step 9), bearer-on-curl Phase 2 all model on MYOB.
- **`superpowers:systematic-debugging`**: For troubleshooting Gusto's partner-app approval edge cases or unexpected payroll-response shapes.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - three-pattern decision tree. This SKILL is a direct-REST connector (out of scope for that doc; sibling shape to `myob-connector`).
- [Gusto API v1 reference](https://docs.gusto.com/embedded-payroll/reference) - official endpoint catalogue.
- [Gusto Developer Portal](https://dev.gusto.com) - where Phase 1 Step 2 lands.
- [Gusto Demo Company](https://docs.gusto.com/embedded-payroll/docs/demo-company) - how Demo Companies are provisioned (manual create at `dev.gusto.com/demo_companies/new` with name + fresh admin email + password - NOT auto-provisioned per the SKILL's earlier prose).
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule (applies to dev.gusto.com).
- Memory `feedback_workshop_kit_update_format` - say "demo mode" / "real payroll" to participants, never "sandbox" / "production environment".
