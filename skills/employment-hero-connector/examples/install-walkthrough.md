# Employment Hero Connector — Install Walkthrough

> **Status: illustrative, not yet captured.** Authored from the SKILL design + Employment Hero's documented UX (legacy KeyPay docs at api.yourpayroll.com.au/docs/api/) without an end-to-end run against a real Employment Hero Payroll account. Specific UI selectors and DOM behaviour below are projected; the walkthrough will be replaced with a captured reference run once smoke is performed on a real AU Payroll account.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — Employment Hero Payroll has no API sandbox; the participant's real payroll account is the data target.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, clipboard utility on PATH.
- Internet access (my.employmenthero.com + the regional `app.yourpayroll.*` + `api.yourpayroll.*` hosts).
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

## Step 2 — Sign in

```
mcp__playwright__browser_navigate({ url: "https://my.employmenthero.com/" })
mcp__playwright__browser_wait_for({ text: "Dashboard", time: 60 })
```

Projected: participant signs in or session is cached. The my.employmenthero.com dashboard renders showing modules: People, Payroll, Onboarding, etc.

---

## Step 3 — Launch Payroll product

```js
// Click the Payroll launch tile
const link = Array.from(document.querySelectorAll('a, button')).find(el => /^(launch )?payroll$/i.test((el.innerText||'').trim()));
link.click();
```

Projected: opens `app.yourpayroll.com.au` (AU) in the same tab or a new one. Claude detects the region via `window.location.hostname`:

```js
// Reference output for AU account:
{ region_host: "yourpayroll.com.au", api_host: "api.yourpayroll.com.au" }
```

For NZ: `yourpayroll.co.nz` → `api.yourpayroll.co.nz`. UK: `yourpayroll.io` → `api.yourpayroll.io`. SG: `yourpayroll.com.sg` → `api.yourpayroll.com.sg`.

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
Claude: Quick warning — if you've connected Employment Hero Payroll
        to any other tool with an API key, generating a new one will
        break that connection. Are you sure to continue?
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

If the key is hidden behind a "Show" button, Claude tells the participant: *"I need to see your key to capture it — could you click 'Show' on the key field, please?"* Then retries.

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
| Step 4 API tab returns "Not Available" | Participant's Payroll role is view-only | Tell participant: "I need Full Access to generate an API key. Could you ask the account owner to upgrade your role or generate the key themselves and paste it?" |
| Step 5 Generate button generates without warning prompt | UI variant — direct generate, no confirm dialog | Apply the warning prose preemptively before clicking |
| Step 6 `{ ok: false }` (no key found) | Key is hidden behind "Show" button | Tell participant to click Show; retry the extract |
| Step 7 business_id is null | URL doesn't contain `/business/<id>` (some Payroll URL patterns differ) | Navigate to `app.yourpayroll.*/business/` (list page) and extract from the first card's link |
| Step 9 HTTP 401 immediately | API key region mismatch (e.g., AU host with NZ key) | Verify `api_endpoint` host matches the region of the participant's Payroll account |

For Phase 2 failures, see the SKILL's Error Handling section.
