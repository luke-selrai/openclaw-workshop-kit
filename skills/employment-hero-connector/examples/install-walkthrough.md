# Employment Hero Connector — Install Walkthrough

> **Status: partial capture 2026-06-02 (sign-in flow + Hub-only pre-flight verified live; Payroll-product steps still illustrative).** First half (Steps 0-2.5) captured against Rodolfo's platinum free trial — confirmed the Hub-only trial does NOT include the Payroll product (`app.yourpayroll.com.au` returns the "Welcome to Payroll / contact your payroll administrator" dead-end). Steps 3-9 remain projected; the walkthrough will be replaced with a full captured reference run once smoke is performed on a real Payroll-enabled account.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — Employment Hero Payroll has no API sandbox; the participant's real payroll account is the data target.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, clipboard utility on PATH.
- Internet access (secure.employmenthero.com + the regional `app.yourpayroll.*` + `api.yourpayroll.*` hosts).
- Participant has an Employment Hero Payroll account with **Full Access** role on at least one Business (view-only roles can't generate API keys).

Projected total: ~60 seconds cached / ~120 seconds cold.

---

## Step 0 — Credential check

```bash
$ test -f "$HOME/.config/employment-hero/credentials.json" \
    && jq -r '.api_endpoint // "missing"' "$HOME/.config/employment-hero/credentials.json" \
    || echo missing
missing
```

→ run Phase 1.

---

## Step 1 — Welcome

Claude sends the 60-second expectation message.

---

## Step 2 — Sign in (captured 2026-06-02)

```
mcp__playwright__browser_navigate({ url: "https://secure.employmenthero.com/" })
```

Captured: page is two-step. First page shows "Welcome, please enter your email address" with a single email field. After Next, password page renders, then optional 2FA (and first-time 2FA enrolment also auto-downloads `eh_recovery_code.txt` to `.playwright-mcp/` which must be quarantined to `~/.config/employment-hero/recovery-code.txt` mode 600 — see SKILL Step 2).

Probe post-sign-in via `browser_evaluate` returning `{ on_dashboard: !/\\/users\\/sign_in/.test(location.href) && !document.querySelector('input[type="password"]') }`. Don't use `browser_wait_for({ text: "Dashboard", time: 60 })` — the `time` parameter is ignored and the tool hard-caps at 30s.

Captured Hub dashboard URL: `https://secure.employmenthero.com/app/v2/organisations/<org_id>/dashboard`. Top nav: Start Guide / Home / People / Billing / More. Expanded "More" menu adds: Recruitment / Benefits & Perks / Compliance / Time / **Pay** / Engagement / Development / Performance / Reports / Workflows / Settings.

---

## Step 2.5 — Pre-flight: is Payroll product enabled? (captured 2026-06-02)

```
mcp__playwright__browser_navigate({ url: "https://app.yourpayroll.com.au/" })
```

Reference outputs (both captured 2026-06-02):

- **Hub-only / Hub free trial**: page text begins *"Welcome to Payroll. Please check that the page you're trying to access is the correct address for accessing your payroll information."* — the Payroll module is not enabled. **Halt Phase 1 here** with the friendly message in SKILL Step 2.5; do not proceed to Step 3.
- **Payroll-enabled** (projected — not yet captured live): page redirects to `https://app.yourpayroll.com.au/business/<id>/...` or similar tenant-scoped URL. Region detect can proceed.

---

## Step 3 — Launch Payroll product (skip if Step 2.5 already landed in it)

```js
// Click Pay / Payroll / Launch Payroll (Hub v2 UI uses just "Pay")
const link = Array.from(document.querySelectorAll('a, button, [role="menuitem"], li')).find(el => {
  const t = (el.innerText||'').trim();
  return /^(pay|payroll|launch payroll)$/i.test(t) && el.getBoundingClientRect().width > 0;
});
link.click();
```

Projected: opens `app.yourpayroll.com.au` (AU) in the same tab or a new one. Claude detects the region via `window.location.hostname`:

```js
// Reference output for AU account:
{ region_host: "yourpayroll.com.au", api_host: "api.yourpayroll.com.au", region: "au" }
```

For NZ: `yourpayroll.co.nz` → `api.yourpayroll.co.nz`, region `nz`. UK: `yourpayroll.io` → `api.yourpayroll.io`, region `uk`. SG: `yourpayroll.com.sg` → `api.yourpayroll.com.sg`, region `sg`.

---

## Step 4 — Business Settings → API

```
mcp__playwright__browser_navigate({ url: "https://app.yourpayroll.com.au/management/api" })
```

(Adjust host for region.) The API settings page renders.

---

## Step 5 — Generate API Key

Reference: page shows either no existing key + a **Generate** button, OR an existing key with a **Re-generate** button.

If re-generating: Claude warns the participant about breaking other integrations before clicking:

```
Claude: Quick heads-up — if you've connected Employment Hero Payroll
        to any other tool, generating a new connection key will break
        that other connection. Are you sure to continue?
Participant: Yes — no other tools using it.
```

Click Generate. Projected wall-clock: ~3 seconds.

---

## Step 6 — DOM-extract via clipboard transit

Save prior clipboard, then extract:

```js
async () => {
  const inputs = Array.from(document.querySelectorAll('input, code, span, pre'));
  // Employment Hero Payroll keys: typically GUID-like or 32-64 char alphanumeric
  // ...
  return { ok: true, key_len: 36 };  // GUID = 36 with hyphens
}
```

Projected return: `{ ok: true, key_len: 36 }` (GUIDs are 36 chars including 4 hyphens; some Employment Hero keys may be longer base64-flavoured strings).

If the key is hidden behind a "Show" button, Claude tells the participant (using only allowed terms — "connection key" not "API key"): *"I need to see your connection key on the page to capture it — could you click 'Show' if there's a hidden-by-default option, please?"* Then retries.

---

## Step 7 — Detect business_id

```js
() => {
  const m = window.location.pathname.match(/\/business\/(\d+|[a-f0-9-]+)/);
  return { business_id: m ? m[1] : null };
}
```

Projected: returns the participant's business UUID or numeric ID from the URL Path. If absent, navigate to `app.yourpayroll.com.au/business/` and re-detect.

---

## Step 8 — Save credentials.json

```bash
$ jq -r 'keys | join(",")' ~/.config/employment-hero/credentials.json
api_endpoint,api_key,business_id,created_at,key_name,region
$ stat -c %a ~/.config/employment-hero/credentials.json
600
```

File shape:

```json
{
  "api_key": "<36-char GUID or similar>",
  "region": "au",
  "api_endpoint": "https://api.yourpayroll.com.au/api/v2",
  "business_id": "<id>",
  "key_name": "Claude Workshop Connector",
  "created_at": "2026-06-02T06:25:00Z"
}
```

Restore prior clipboard.

---

## Step 9 — Smoke test

```bash
$ curl -sf -u "api:<key>" "https://api.yourpayroll.com.au/api/v2/business/<id>" | jq -r .name
Selrai Pty Ltd
```

Claude tells the participant:

```
Claude: All connected — your Employment Hero Payroll Selrai Pty Ltd
        is ready. Ask me things like 'list my employees' or 'show me
        last week's pay run'.
```

---

## Phase 2 sample (immediately after install)

```
Participant: List my employees.
Claude:      # Real-data gate
             eh_get "/business/<id>" | jq -r .name
             # → "Selrai Pty Ltd"
Claude:      Just confirming — you're connected to your real Employment
             Hero Payroll for Selrai Pty Ltd with 12 employees. Anything
             I do here changes your live payroll. OK to list employees?
Participant: Yes.
Claude:      # Pattern 2
             eh_get "/business/<id>/employee"
Claude:      You have 12 active employees:
             - Alice Anderson (Software Engineer)
             - Bob Brown (Sales Rep)
             - ...
```

A leave-approval write triggers the destructive-op gate:

```
Participant: Approve Alice's pending leave.
Claude:      # Pattern 8 first
             eh_get "/business/<id>/leaverequest?status=Pending"
             # → [{employee_id: "alice-id", leave_category: "Annual Leave",
             #     from_date: "2026-07-15", to_date: "2026-07-19",
             #     total_hours: 40, id: "lr-uuid"}]
Claude:      I'm about to approve Alice Anderson's leave request: 40 hours
             of Annual Leave starting 2026-07-15. This adds it to her pay
             record. OK?
Participant: Yes.
Claude:      # Pattern 9
             eh_put "/business/<id>/leaverequest/lr-uuid/approve" '{}'
Claude:      Approved Alice's 40 hours of Annual Leave starting July 15.
```

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (credential check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (sign-in detect) | 15 s cached / 60 s cold |
| Step 3 (launch Payroll + region detect) | 8 s |
| Step 4 (navigate to API settings) | 5 s |
| Step 5 (Generate button + confirm warning) | 10 s |
| Step 6 (DOM-extract via clipboard) | 2 s |
| Step 7 (business_id detect from URL) | 1 s |
| Step 8 (credentials.json write) | 0.5 s |
| Step 9 (smoke test) | 1 s |
| **Total** | **~45 s cached / ~90 s cold** |

---

## Failure modes anticipated from design review

| Failure | Cause | Fix |
|---|---|---|
| Step 3 Payroll launch button missing | Participant's role doesn't include Payroll access | Tell participant: "I don't see Payroll in your account — your role might not include it. Check with whoever owns your Employment Hero." |
| Step 4 API tab returns "Not Available" | Participant's Payroll role is view-only | Tell participant (allowed terms only): "I need Full Access to set up the connection. Could you ask the account owner to upgrade your role, or have them set up the connection and share the connection key with you?" |
| Step 5 Generate button generates without warning prompt | UI variant — direct generate, no confirm dialog | Apply the warning prose preemptively before clicking |
| Step 6 `{ ok: false }` (no key found) | Key is hidden behind "Show" button | Tell participant to click Show; retry the extract |
| Step 7 business_id is null | URL doesn't contain `/business/<id>` (some Payroll URL patterns differ) | Navigate to `app.yourpayroll.*/business/` (list page) and extract from the first card's link |
| Step 9 HTTP 401 immediately | API key region mismatch (e.g., AU host with NZ key) | Verify `api_endpoint` host matches the region of the participant's Payroll account |

For Phase 2 failures, see the SKILL's Error Handling section.
