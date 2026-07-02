# Gusto Connector - Install Walkthrough (Demo mode)

> **Status: captured reference run, 2026-06-02 against rodolfo@selrai.com.au's Gusto Developer account + a Demo Company named `Selr AI Demo Co`.** Captured 10 SKILL drifts during this run, all fixed in the accompanying PR. Live OAuth completed end-to-end; `/v1/companies/{uuid}`, `/v1/companies/{uuid}/employees`, and `/v1/companies/{uuid}/payrolls?include[]=totals` all returned real demo data (Selr AI Demo Co, 5+ demo employees including Isaiah Berlin / Patricia Churchland / Soren Kierkegaard / Hannah Arendt / Taylor Swift, 7 historical payrolls).

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → Demo mode). Production mode (the 1-2 week Gusto partner-app review) is documented separately in `install-walkthrough-production.md` (future).

**Why Demo is the default:** Production access to real payroll data requires Gusto to approve the partner app (1-2 business weeks). Demo mode is instant, no review, gives the participant fake but realistically-shaped payroll data to play with.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, `python3`, `ss` (or `netstat`) on PATH.
- Internet access (dev.gusto.com, api.gusto-demo.com).
- Participant has a Gusto Developer account (free; create at dev.gusto.com if absent). They do NOT need an existing Gusto payroll subscription - Demo mode creates a synthetic Demo Company.

Projected total: ~90 seconds for a participant with an existing dev.gusto.com session; ~3 minutes for cold sign-up (including email verification on a new developer account).

---

## Step 0 - Mode prompt

```
Participant: Connect Gusto.
Claude:      Want me to start in demo mode so you can use the
             connection today (fake payroll data, no real money),
             or do you want real payroll data for your actual Gusto
             account? Real data needs Gusto to approve me first -
             they usually take 1 to 2 weeks. Most people pick demo
             first to play with the features.
Participant: Demo is fine.
```

`MODE=demo`, continue to Phase 1.

---

## Step 1 - Welcome

Claude sends the 3-bullet expectation-setting message.

---

## Captured drifts summary (fixed in this PR)

| # | SKILL said | Reality (2026-06-02) |
|---|---|---|
| 1 | URL `/oauth_applications` | `/applications` |
| 2 | Form has scope checkboxes | No scope picker - Demo apps default to `public webhook_subscriptions:read/write` |
| 3 | Scopes `companies:read` etc | `public` alone is sufficient for all Phase 2 Demo reads (companies, employees, payrolls verified live) |
| 4 | Demo Company auto-provisions | Must be created manually at `/demo_companies/new` |
| 5 | Demo Company needs only name | Needs fresh email + password (becomes the OAuth admin) |
| 6 | Credentials shown plainly | Hidden behind `Reveal` buttons; toggle to `Hide` after reveal |
| 7 | client_id ~32, secret ~64 | Both are 43 chars |
| 8 | DOM extract uses any container | Parent div `innerText` slurps adjacent `Copy`+`Hide` button text - must use value-only `<span>` filter |
| 9 | Demo host `api-demo.gusto.com` | **DNS doesn't resolve** at the SKILL's host. Real host is `api.gusto-demo.com` (dashed top-level, not subdomain) |
| 10 | Company UUID via `/v1/me` | `/v1/me` returns 404 not_found on current Gusto API. **Use `/v1/token_info`** - returns `{scope, resource:{type:"Company", uuid:"..."}, resource_owner:{...}}` |

## Step 2 - Open Gusto developer portal

```
mcp__playwright__browser_navigate({ url: "https://dev.gusto.com/applications" })
mcp__playwright__browser_wait_for({ text: "Applications", time: 60 })
```

Captured 2026-06-02: the page renders the empty-state "Get started building your Gusto integration" with a `Create application` button.

---

## Step 3 - Create or find Partner Application (captured)

No existing `Claude Workshop Connector` app, so Claude clicks **Create application** (link to `/applications/new`) and fills the form. **Captured form fields (no scope picker!):**

| Field | Value |
|---|---|
| Application name | `Claude Workshop Connector` |
| Redirect URI | `http://localhost:8765/callback` (textarea - supports multiple lines for multiple redirects) |
| Category | **Other** (closest neutral choice - Gusto's dropdown lists 25 categories including Accounting, Background Checks, Payroll, etc.; pick `Other` for the workshop kit) |
| Disable Gusto's time tracking features | leave **unchecked** |

Submit. Gusto issues client_id + client_secret immediately, redirects to `/applications` listing showing `Claude Workshop Connector | Selr AI | demo` (stage column shows `demo` for Demo mode). Captured wall-clock: ~3 seconds. Click into the app → detail page at `/applications/<uuid>`.

Captured scopes (auto-assigned to Demo apps): `public, webhook_subscriptions:read, webhook_subscriptions:write`. The `public` scope alone is sufficient for all Phase 2 Demo reads - verified live.

---

## Step 4 - DOM-extract via clipboard transit (captured Reveal + value-only span filter)

The app detail page shows Client ID + Secret as masked `*********` values with `Reveal` toggle + `Copy`/`Hide` buttons inline.

Save prior clipboard, click both `Reveal` buttons, then extract:

```js
{ ok: true, client_id_len: 43, client_secret_len: 43 }
```

**Captured drift**: client_id and client_secret are both **43 chars** (not 32/64 as the pre-fix SKILL projected). The captured client_id was `tUj8npd37sQ9sz-HIfMclRijuCG_gt8oJE-IKQfuUU8`.

**Critical extract detail**: the parent `<div>` wrapping each value's `<span>` has `innerText` equal to `<value>CopyHide` because the inline buttons concatenate via the DOM tree. A naive `span,div,code` walk captures `tUj8...UU8CopyHide` (51 chars instead of 43), which then breaks the OAuth `client_authentication_failed` check downstream. Fix: filter for value-only `<span>` elements whose `innerText` matches `/^[A-Za-z0-9_.\-]+$/` with length ≥ 30.

---

## Step 4.5 - Create Demo Company (captured: required separate step)

Navigate to `https://dev.gusto.com/demo_companies/new`. Form fields:

| Field | Value |
|---|---|
| Demo company name | `Selr AI Demo Co` |
| Email | A **fresh email** (use plus-alias: `<your-email>+gusto-demo@<domain>`). Captured: `rodolfo+gusto-demo@selrai.com.au` |
| Password | participant chooses + types directly into Playwright window |
| Password confirmation | same |

Submit. Status flips `generating` → `finished` after ~30-90s. Captured: 90s on the reference run. The Demo Company gets its own UUID (Captured: `e8d85ba3-fce8-4736-9155-88147ed384a3`) and admin account (the fresh email + password become the OAuth sign-in credentials for Step 6).

---

## Step 5 - Start loopback listener

```bash
PORT=8765
nohup python3 -c "http.server..." > /tmp/gusto-listener.log 2>&1 &
echo $! > /tmp/gusto-listener.pid
```

Listener live on `127.0.0.1:8765`, ready to capture the OAuth callback.

---

## Step 6 - OAuth consent (captured: scope param OPTIONAL, host fixed)

Construct AUTH_URL with the CORRECT Demo host (`api.gusto-demo.com`, NOT `api-demo.gusto.com` which doesn't resolve in DNS). Captured: scope parameter omitted - Gusto grants the app's default Demo scopes (`public webhook_subscriptions:read/write`), which is sufficient for Phase 2 Demo reads.

```
https://api.gusto-demo.com/oauth/authorize
  ?client_id=<43 chars>
  &redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback
  &response_type=code
```

Navigate Playwright. Captured flow:
1. Redirected to `https://app.gusto-demo.com/oauth/authorize?...` (note `app.gusto-demo.com` not `api.gusto-demo.com` - Gusto does a redirect under the hood)
2. If the Demo Company admin isn't yet signed in: Keycloak SSO at `https://login.gusto-demo.com/realms/zenpayroll/protocol/openid-connect/auth?...` - participant signs in with the Demo Company admin email + password set in Step 4.5
3. Consent screen: "Authorize Claude Workshop Connector to connect to your account? ... will allow Claude Workshop Connector to view and access Selr AI Demo Co's account information."
4. `<input type="submit" value="Authorize">` button - click it (NOT `<button>` element; the consent button is a submit input)
5. Browser redirects to `http://localhost:8765/callback?code=<43-char-code>`
6. Listener writes the code to `/tmp/gusto-auth-code` and exits

---

## Step 7 - Exchange code for tokens (captured response)

```bash
curl https://api.gusto-demo.com/oauth/token \
  -H 'Content-Type: application/json' \
  -d '{"client_id":"...","client_secret":"...","code":"...","redirect_uri":"http://localhost:8765/callback","grant_type":"authorization_code"}'
```

Captured response shape:

```json
{
  "access_token": "<43 chars>",
  "refresh_token": "<43 chars>",
  "token_type": "Bearer",
  "expires_in": 7200,
  "scope": "public webhook_subscriptions:read webhook_subscriptions:write",
  "created_at": 1780392797
}
```

`expires_at` computed from `created_at` + `expires_in` (Unix timestamp arithmetic).

---

## Step 8 - Discover company via /v1/token_info (captured: NOT /v1/me)

```bash
curl https://api.gusto-demo.com/v1/token_info -H "Authorization: Bearer <token>"
```

**Captured drift**: `/v1/me` returns `{"errors":[{"error_key":"request","category":"not_found","message":"This endpoint does not exist on this version of the Gusto API."}]}` on the current Gusto API (v2026-02-01). The canonical endpoint is `/v1/token_info`, which returns:

```json
{
  "scope": "public webhook_subscriptions:read webhook_subscriptions:write",
  "resource": {
    "type": "Company",
    "uuid": "e8d85ba3-fce8-4736-9155-88147ed384a3"
  },
  "resource_owner": {
    "type": "CompanyAdmin",
    "uuid": "da69a045-ccdd-4238-8480-3cd534d1111c"
  }
}
```

Extract `resource.uuid` as `company_uuid`. For multi-company partner installs, Gusto may return multiple records - verify at first Production-mode smoke.

---

## Step 9 - Save credentials.json

```bash
chmod 700 ~/.config/gusto
# Atomic write
jq -n ... > ~/.config/gusto/credentials.json.tmp
chmod 600 ~/.config/gusto/credentials.json.tmp
mv ~/.config/gusto/credentials.json.tmp ~/.config/gusto/credentials.json
```

File shape:

```json
{
  "mode": "demo",
  "client_id": "<32 chars>",
  "client_secret": "<64 chars>",
  "access_token": "<long token>",
  "refresh_token": "<rotation token>",
  "expires_at": "2026-06-02T07:43:00Z",
  "company_uuid": "<uuid>",
  "api_endpoint": "https://api.gusto-demo.com/v1"
}
```

Mode 0600. Restore prior clipboard.

---

## Step 10 - Smoke test

```bash
curl https://api.gusto-demo.com/v1/companies/<uuid> -H "Authorization: Bearer <token>" | jq -r '.name + " (" + .uuid + ")"'
# → "Acme Demo Company (abc-...)"
```

Claude tells the participant:

```
Claude: All connected - your Gusto Acme Demo Company is ready. Ask
        me things like 'list my employees' or 'show me the last
        payroll'.
```

---

## Phase 2 sample (immediately after install)

```
Participant: List my employees.
Claude:      # ROUTE=demo (no real-data gate, fake data)
             gusto_get "/companies/<uuid>/employees"
             # Demo Company comes with 3-8 synthetic employees
             # → [{first_name: "Alice", last_name: "Anderson", ...}, ...]
Claude:      Your Acme Demo Company has 5 employees:
             - Alice Anderson (Software Engineer)
             - Bob Brown (Sales Rep)
             - ...
```

A write in Demo mode is freely callable (no gate, since fake data):

```
Participant: Approve Alice's pending PTO.
Claude:      gusto_get "/companies/<uuid>/time_off_requests?status=pending"
             # → [{employee_uuid: "alice-uuid", total_hours: 16, ...}]
             gusto_put "/time_off_requests/<tor-uuid>" '{"status":"approved"}'
             # → 200
Claude:      Approved Alice's 16 hours of vacation starting Aug 18.
```

The same flow in Production mode would trigger Gate 2 first ("I'm about to approve Alice's 16 hours...").

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (mode prompt + reply) | 10 s |
| Step 1 (welcome) | 1 s |
| Step 2 (Playwright navigate + sign-in detect) | 15 s (cached) / 60 s cold |
| Step 3 (Partner App create form fill + save) | 30 s |
| Step 4 (DOM-extract via clipboard) | 2 s |
| Step 5 (listener start) | 1 s |
| Step 6 (consent flow + click Allow) | 10 s |
| Step 7 (token exchange) | 1 s |
| Step 8 (company discovery) | 1 s |
| Step 9 (credentials.json write + clipboard restore) | 0.5 s |
| Step 10 (smoke test) | 1 s |
| **Total** | **~75 s cached / ~120 s cold (Demo mode)** |

Production mode adds the partner-app review wait (1-2 business weeks) between Step 3's save and Step 6's OAuth - the SKILL persists `mode=pending-production` in credentials.json during the wait, and Phase 0.3 polls for approval on subsequent invocations.

---

## Failure modes anticipated from design review (will be confirmed on first real smoke)

| Failure | Cause | Fix |
|---|---|---|
| Step 2 `browser_wait_for("Applications")` times out | dev.gusto.com session dead OR sign-up required | Tell participant to sign up at dev.gusto.com if they don't have a developer account yet |
| Step 3 redirect_uri rejected as "not HTTPS" | Some Gusto Production tabs enforce HTTPS-only redirect URIs even in Demo | Use `https://localhost:8765/callback` and tell the participant Chrome will warn about self-signed cert (accept and continue) |
| Step 4 returns `{ ok: false }` | Gusto's UI changed the credentials display | Snapshot the post-create page, look for new container, fall back to asking participant to paste |
| Step 7 HTTP 400 `invalid_grant` | OAuth code expired (~5 minute window) | Restart from Step 5 |
| Step 8 returns zero companies | Demo company didn't auto-provision | Drive Playwright to dev.gusto.com → Demo Companies → New Demo Company; retry |
| Phase 2 calls all return 401 immediately after install | Token wasn't persisted correctly | Verify `credentials.json` has all 7 keys via `jq keys` |

For Phase 2 failures, see the SKILL's Error Handling section.
