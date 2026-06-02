# Gusto Connector — Install Walkthrough (Demo mode)

> **Status: illustrative, not yet captured.** Authored from the SKILL design without an end-to-end run against Gusto's live dev portal. Timings, DOM structures, and exact dev-portal field labels below are projected from Gusto's documented API behaviour at design time; the walkthrough will be replaced with a captured reference run once smoke is performed against an actual Gusto Demo Company.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → Demo mode). Production mode (the 1-2 week Gusto partner-app review) is documented separately in `install-walkthrough-production.md` (future).

**Why Demo is the default:** Production access to real payroll data requires Gusto to approve the partner app (1-2 business weeks). Demo mode is instant, no review, gives the participant fake but realistically-shaped payroll data to play with.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, `python3`, `ss` (or `netstat`) on PATH.
- Internet access (dev.gusto.com, api-demo.gusto.com).
- Participant has a Gusto Developer account (free; create at dev.gusto.com if absent). They do NOT need an existing Gusto payroll subscription — Demo mode creates a synthetic Demo Company.

Projected total: ~90 seconds for a participant with an existing dev.gusto.com session; ~3 minutes for cold sign-up (including email verification on a new developer account).

---

## Step 0 — Mode prompt

```
Participant: Connect Gusto.
Claude:      Want me to start in demo mode so you can use the
             connection today (fake payroll data, no real money),
             or do you want real payroll data for your actual Gusto
             account? Real data needs Gusto to approve me first —
             they usually take 1 to 2 weeks. Most people pick demo
             first to play with the features.
Participant: Demo is fine.
```

`MODE=demo`, continue to Phase 1.

---

## Step 1 — Welcome

Claude sends the 3-bullet expectation-setting message.

---

## Step 2 — Open Gusto developer portal

```
mcp__playwright__browser_navigate({ url: "https://dev.gusto.com/oauth_applications" })
mcp__playwright__browser_wait_for({ text: "Applications", time: 60 })
```

Projected: participant signs in or session is cached. The OAuth Applications page renders.

---

## Step 3 — Create or find Partner Application

Projected: no existing `Claude Workshop Connector` app, so Claude clicks **New application** and fills the form via React-friendly setter:

| Field | Value |
|---|---|
| Application name | `Claude Workshop Connector` |
| Application website | `https://localhost/` (any HTTPS URL accepted in Demo) |
| Redirect URI | `http://localhost:8765/callback` |
| Scopes (checkboxes) | `companies:read`, `employees:read`, `payrolls:read`, `time_off_requests:read`, `time_off_requests:write` |

Submit. Gusto issues client_id + client_secret immediately for Demo. Projected timing: ~30 seconds for form fill + save.

---

## Step 4 — DOM-extract via clipboard transit

Save prior clipboard, then run the extract:

```js
{ ok: true, client_id_len: 32, client_secret_len: 64 }
```

Clipboard now holds `{"client_id":"...","client_secret":"..."}`. Tool return contains only the integer lengths.

---

## Step 5 — Start loopback listener

```bash
PORT=8765   # default; auto-increments if in use
nohup python3 -c "http.server..." > /tmp/gusto-listener.log 2>&1 &
echo $! > /tmp/gusto-listener.pid
```

Listener live on `127.0.0.1:8765`, ready to capture the OAuth callback.

---

## Step 6 — OAuth consent

Construct AUTH_URL:

```
https://api-demo.gusto.com/oauth/authorize
  ?client_id=<32 chars>
  &redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback
  &response_type=code
  &scope=companies:read employees:read payrolls:read time_off_requests:read time_off_requests:write
```

Navigate Playwright. Projected: consent screen rendered ("Allow Claude Workshop Connector to access your Gusto demo data?"). Claude clicks **Allow** via `browser_evaluate`.

Browser redirects to `http://localhost:8765/callback?code=<short-lived-code>&state=...`. Listener writes the code to `/tmp/gusto-auth-code` and exits.

---

## Step 7 — Exchange code for tokens

```bash
curl https://api-demo.gusto.com/oauth/token ... # POST with code, client_id, client_secret
```

Response JSON:

```json
{
  "access_token": "<long-lived-token>",
  "refresh_token": "<rotation-token>",
  "token_type": "Bearer",
  "expires_in": 7200,
  "scope": "companies:read employees:read ..."
}
```

Listener torn down, tmp files cleaned.

---

## Step 8 — Discover companies

```bash
curl https://api-demo.gusto.com/v1/me -H "Authorization: Bearer <token>"
```

Projected response: a Demo Company auto-created on first dev sign-up. Single company → silently pick. Capture `company_uuid`.

---

## Step 9 — Save credentials.json

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
  "api_endpoint": "https://api-demo.gusto.com/v1"
}
```

Mode 0600. Restore prior clipboard.

---

## Step 10 — Smoke test

```bash
curl https://api-demo.gusto.com/v1/companies/<uuid> -H "Authorization: Bearer <token>" | jq -r '.name + " (" + .uuid + ")"'
# → "Acme Demo Company (abc-...)"
```

Claude tells the participant:

```
Claude: All connected — your Gusto Acme Demo Company is ready. Ask
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

Production mode adds the partner-app review wait (1-2 business weeks) between Step 3's save and Step 6's OAuth — the SKILL persists `mode=pending-production` in credentials.json during the wait, and Phase 0.3 polls for approval on subsequent invocations.

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
