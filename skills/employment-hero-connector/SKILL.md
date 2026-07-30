---
name: employment-hero-connector
description: "Connect Employment Hero Payroll (formerly KeyPay) to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect Employment Hero, or wants payroll work (employees, pay runs, pay slips, leave requests and approvals) and the credentials aren't in place yet. Once connected, Employment Hero Payroll runs directly against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - employment-hero
    - keypay
    - payroll
    - australia
    - employees
    - leave
    - rest-api
  pairs-with:
    - skill: gusto-connector
      reason: Sibling Tier-1 payroll connector. Gusto is US-focused; Employment Hero Payroll is AU-leaning. Same shape (employees, pay runs, leave) but different auth surface (HTTP Basic with tenant key vs OAuth2).
    - skill: myob-connector
      reason: Reference Direct-REST + Playwright pattern. Atomic credentials.json write borrowed from MYOB.
    - skill: xero-connector
      reason: Sibling AU SMB connector. Xero handles bookkeeping; Employment Hero Payroll handles payroll. Both pair with QuickBooks in mixed AU-SMB stacks.
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting Employment Hero Payroll's region-host detection or tenant-id surfaces.
---

# Employment Hero Connector (Payroll surface)

## Overview

This skill lets you read and operate a user's Employment Hero Payroll account (formerly KeyPay, rebranded after Employment Hero's 2020 acquisition) on their behalf using **the Employment Hero Payroll REST API** (no MCP server, no first-party CLI - Direct-REST + Playwright pattern).

**Scope: Payroll only.** Employment Hero has two distinct API surfaces:

| Surface | Endpoint | Auth | Access |
|---|---|---|---|
| **Employment Hero Payroll** (this SKILL) | `https://api.yourpayroll.com.au/api/v2/` (AU; region-specific) | HTTP Basic with tenant API key | **Self-serve** - every Payroll customer can generate their own API key from Business Settings → API |
| Employment Hero core HR | `https://api.employmenthero.com/api/` via OAuth at `oauth.employmenthero.com` | OAuth2 partner app | **Partner-gated** - requires Employment Hero to approve the partner application; out of v1 scope |

The Payroll surface (this SKILL) is what AU SMB participants running PAYG payroll actually need - it covers employees, pay runs, leave. The core HR surface is for partners building white-label HR products; if SelrAI ever applies as a partner, v2 of this SKILL can add it.

**Regional hosts**: Employment Hero Payroll runs separate regional instances. The API host varies:

| Region | API base |
|---|---|
| AU (Australia) | `https://api.yourpayroll.com.au/api/v2/` |
| UK (United Kingdom) | `https://api.yourpayroll.io/api/v2/` |
| NZ (New Zealand) | `https://api.yourpayroll.co.nz/api/v2/` |
| SG (Singapore) | `https://api.yourpayroll.com.sg/api/v2/` |

Phase 1 detects the participant's region from the host their Employment Hero Payroll account redirects to after sign-in (`app.yourpayroll.com.au` vs `app.yourpayroll.io` etc.) and saves the correct API base.

It has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** Claude drives `secure.employmenthero.com` → Payroll-enabled pre-flight (verifies the account actually has the Payroll product, not just Hub) → Payroll product launch → Business Settings → API → Generate API Key. DOM-extract the new key via clipboard transit. Persist to `~/.config/employment-hero/credentials.json` (mode 0600). The participant's manual moment: signing in once.
- **Phase 2 - Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Employment Hero Payroll REST endpoints with HTTP Basic auth (`-u "api:<api_key>"`, where the username is conventionally `api` - Employment Hero Payroll's Basic auth ignores the username field). Writes (approve/decline leave) gated by per-call confirmation prose.

**Single-mode, no test/live distinction.** Employment Hero Payroll has no API sandbox. Every Phase 2 call touches real employees + real money. Production-mode gates apply unconditionally.

**API keys are tenant-scoped and don't expire** until manually revoked from Business Settings → API. No refresh-token cycle. Auth failure path: HTTP 401 → re-run Phase 1.

**Which phase to run** - Before any tool call:

```bash
test -f "$HOME/.config/employment-hero/credentials.json" && jq -r '.api_endpoint // "missing"' "$HOME/.config/employment-hero/credentials.json" 2>/dev/null || echo missing
```

- Starts with `https://` → credentials present. Smoke (`GET /business`); on 200 → Phase 2.
- `missing` → run Phase 1.

---

## Golden rule - do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside Playwright MCP. Never tell the participant to "open Employment Hero in your browser." Claude navigates; the participant types passwords directly into the Playwright window. Same as other connectors.

If Playwright MCP is unavailable, halt and point at install instructions.

---

## Communication rules for Phase 1

Plain English only. The participant is an HR admin or business owner.

- **One step at a time.** Never stack instructions.
- **Plain English only.** Never say API, key, token, HTTP, Basic auth, header, REST, endpoint, JSON, env var, curl, terminal, CLI, MCP, callback, file path, tenant, KeyPay (the legacy product name - most participants now know it as "Employment Hero Payroll"). If you must, say "your connection key" or "your payroll connection".
- **Tell them what is about to happen.** *"I'm opening Employment Hero now - sign in when you see the page. About 60 seconds."*
- **React warmly.** Good: *"Connected to **[Business Name]** with **[N] employees** on payroll."* Bad: *"Tenant API key persisted with HTTP Basic auth shape."*
- **Never show error messages directly.** Translate.
- **Short responses.** Max 8 lines per message.
- **Never echo the API key.** Stored locally, never shown.
- **Don't mention "KeyPay"** to the participant unless they say it first - the rebrand is over 4 years old and the UI now says "Employment Hero Payroll" everywhere.

---

## ⛔ Pre-flight check

Verify Playwright MCP tools are available (`ToolSearch +playwright`). If absent, halt.

---

## PHASE 0 - Credential check

```bash
CREDS="$HOME/.config/employment-hero/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.api_endpoint // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

- `missing` → run Phase 1.
- Starts with `https://` → smoke (`GET /business`); on 200 → Phase 2; on 401 → re-run Phase 1.

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

### Step 1 - Welcome

> "Great - connecting your Employment Hero Payroll. I'll open Employment Hero in a small browser window. Sign in when you see the page (and approve any verification code), and I'll do the rest. About 60 seconds."

### Step 2 - Sign in to Employment Hero

```
mcp__playwright__browser_navigate({ url: "https://secure.employmenthero.com/" })
```

**Do NOT snapshot the sign-in page** (password-leak rule). The auto-snapshot returned by `browser_navigate` itself is also a leak surface - mask `input[type=password]` immediately after navigate (see `reference_playwright_snapshot_password_leak`). Then probe page state via `browser_evaluate` rather than `browser_wait_for` (which hard-caps at 30s regardless of the `time` parameter).

Employment Hero's sign-in is **two-step**: email page first ("Welcome, please enter your email address"), password page next, then optional 2FA. The MutationObserver-based password masker handles the page transition correctly.

**2FA recovery code quarantine.** First-time sign-in triggers 2FA enrolment which auto-downloads a tiny `eh_recovery_code.txt` (the 2FA recovery code, ~20 bytes) to the Playwright download dir (defaults to `.playwright-mcp/` in the current working directory - i.e., the project workspace, world-readable). Immediately after sign-in lands, move it to a 0600 location:

```bash
if ls .playwright-mcp/eh_recovery_code*.txt >/dev/null 2>&1; then
  mkdir -p "$HOME/.config/employment-hero"
  chmod 700 "$HOME/.config/employment-hero"
  mv .playwright-mcp/eh_recovery_code*.txt "$HOME/.config/employment-hero/recovery-code.txt"
  chmod 600 "$HOME/.config/employment-hero/recovery-code.txt"
  echo "Recovery code saved at ~/.config/employment-hero/recovery-code.txt (mode 600)"
fi
```

Then tell the participant in plain English: *"Employment Hero gave you a 2FA recovery code I've saved at `~/.config/employment-hero/recovery-code.txt`. Please copy it to your password manager - you'll need it if you lose access to your authenticator app."*

### Step 2.5 - Pre-flight: verify the account has the Payroll product

**Critical gate.** Employment Hero sells the HR Hub (People, Compliance, Time, Performance) separately from Employment Hero Payroll (the former KeyPay product). Hub-only subscriptions and the platinum free trial include Hub but NOT Payroll. The Payroll connector cannot install on a Hub-only account.

Detect by navigating to the regional Payroll product root and checking for the not-subscribed dead-end page (text begins with "Welcome to Payroll. Please check that the page you're trying to access is the correct address..."):

```
mcp__playwright__browser_navigate({ url: "https://app.yourpayroll.com.au/" })
```

(Use the regional host the participant's account is in; AU is `com.au`, UK `io`, NZ `co.nz`, SG `com.sg`. If region is unknown at this point, start with `com.au` - non-AU accounts will fail this probe AND the region detect in Step 3, surface to participant in both cases.)

```js
() => {
  const txt = (document.body.innerText || '').slice(0, 500);
  const hasDeadEnd = /welcome to payroll[\s\S]{0,200}correct address/i.test(txt);
  const onBusinessOrPayrollDashboard = /\/business\//.test(location.href) || /pay run|employees on payroll/i.test(txt);
  return { hub_only: hasDeadEnd, payroll_enabled: onBusinessOrPayrollDashboard };
}
```

If `hub_only: true`, surface to the participant and halt Phase 1:

> "Your Employment Hero account doesn't have the Payroll product enabled - this connector only works with Employment Hero Payroll (the former KeyPay product). To use it, you'll need either a paid Payroll subscription or a Payroll free trial through your Employment Hero account manager. I'll skip this connector for now - let me know once Payroll is enabled and I'll come back."

If `payroll_enabled: true`, proceed to Step 3 (the navigation already landed inside the Payroll product, so Step 3's region detect can read `window.location.hostname` directly without another launch click).

### Step 3 - Launch the Payroll product (skip if Step 2.5 already landed in it)

If Step 2.5 detected `payroll_enabled: true`, skip to the region-detect block below - you're already in the Payroll product. Otherwise (Step 2.5 returned neither hub_only nor payroll_enabled - e.g., landed on a Payroll login page because the Hub session doesn't auto-SSO), look on the Hub dashboard for the Payroll launcher.

In the current Hub v2 UI, the Payroll launcher is in the expanded "More" menu and is labeled **"Pay"** (not "Payroll"). Older UI variants used "Payroll" or "Launch Payroll". Match all three:

```js
() => {
  const links = Array.from(document.querySelectorAll('a, button, [role="menuitem"], li'));
  const payrollLink = links.find(el => {
    const t = (el.innerText||'').trim();
    return /^(pay|payroll|launch payroll)$/i.test(t) && el.getBoundingClientRect().width > 0;
  });
  if (payrollLink) {
    payrollLink.click();
    return { ok: true, label: (payrollLink.innerText||'').trim() };
  }
  return { ok: false, reason: 'no_payroll_launch_button' };
}
```

Wait for the new tab (or in-window navigation) to land on `app.yourpayroll.com.au` (or regional). Detect the region from `window.location.hostname` and save to `region`:

```js
() => {
  const host = window.location.hostname;
  const m = host.match(/yourpayroll\.(com\.au|com\.sg|co\.nz|io)/);
  if (!m) return { region_host: host, api_host: null, region: null };
  const tldToRegion = { 'com.au': 'au', 'io': 'uk', 'co.nz': 'nz', 'com.sg': 'sg' };
  return {
    region_host: m[0],
    api_host: `api.yourpayroll.${m[1]}`,
    region: tldToRegion[m[1]]
  };
}
```

This returns `region` as one of `au` / `uk` / `nz` / `sg` directly, so Step 8 can use it without additional derivation logic.

If `api_host` is null, surface to the participant: *"I see your Employment Hero Payroll is on a region I don't have wired up yet. Let me know what country your business is in."*

### Step 4 - Navigate to Business Settings → API

The Payroll product's left navigation has **Business Settings** (sometimes "Business" → "Settings"). Inside, the API tab is named **API** or **API Access**.

```
mcp__playwright__browser_navigate({ url: "https://app.yourpayroll.com.au/management/api" })
```

(Adjust hostname for region. Verify via Playwright snapshot that the API settings page loaded - fallback to clicking through the Business Settings nav menu if direct URL changes.)

### Step 5 - Generate API Key

The API page shows the participant's existing API key (if any) plus a **Generate** or **Re-generate** button.

Idempotent check: if a key already exists and the participant remembers it, they can paste it. Otherwise generate a fresh one:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /^(generate|create|new)\s*(api\s*key)?$/i.test((b.innerText||'').trim()));
  if (!btn) return { ok: false };
  btn.click();
  return { ok: true };
}
```

> **Warning**: regenerating an existing key invalidates the old one. If other integrations (e.g., a third-party HRIS pulling payroll data) are using the existing key, they'll break. Tell the participant: *"Quick heads-up - if you've connected Employment Hero Payroll to any other tool, generating a new connection key will break that other connection. Are you sure to continue?"* Wait for OK. (Note the participant-facing phrasing uses "connection key" not "API key" per the communication rules above.)

### Step 6 - DOM-extract via clipboard transit

Employment Hero Payroll usually displays the key in a read-only text field on the API settings page. It can be re-displayed (unlike Klaviyo which shows once), but the clipboard-transit pattern keeps the key out of tool returns regardless.

Save prior clipboard:

```bash
SAVED=$(wl-paste 2>/dev/null | base64 -w0)
echo "$SAVED" > /tmp/employment-hero-prev-clipboard.b64
```

Extract:

```js
async () => {
  // Employment Hero Payroll keys are typically GUID-like or ~32+ alphanumeric chars
  const inputs = Array.from(document.querySelectorAll('input, code, span, pre'));
  for (const el of inputs) {
    const v = (el.value || el.innerText || '').trim();
    if (v && v.length >= 32 && /^[A-Za-z0-9+/=_-]+$/.test(v)) {
      await navigator.clipboard.writeText(JSON.stringify({ api_key: v }));
      return { ok: true, key_len: v.length };
    }
  }
  return { ok: false };
}
```

If extraction fails (the page may render the key inside a tooltip or behind a "Show" button), surface a participant-friendly fallback: *"I need to see your connection key on the page to capture it - could you click 'Show' if there's a hidden-by-default option, please?"* (Using "connection key" not "API key" per the communication rules.)

### Step 7 - Detect business (tenant) ID

The Employment Hero Payroll API is tenant-scoped. The base path is `/business/{business_id}/...` for most endpoints. Detect the business UUID from the Payroll product's URL:

```js
() => {
  // URLs in the Payroll product include /business/<id>/... after sign-in
  const path = window.location.pathname;
  const m = path.match(/\/business\/(\d+|[a-f0-9-]+)/);
  return { business_id: m ? m[1] : null };
}
```

If multiple businesses are visible, ask the participant which to connect.

### Step 8 - Save credentials.json

Only the `api_key` came through the clipboard (Step 6). The `api_host` (from Step 3), `region` (derived from `api_host`), and `business_id` (from Step 7) are NOT clipboard values - they were returned as JS function results from Playwright `browser_evaluate` calls and must be captured into shell variables at that point (each `browser_evaluate` call in Steps 3 and 7 returns the value directly; assign them to `API_HOST`, `REGION`, `BUSINESS_ID` immediately in the Bash glue that wraps those Playwright calls).

Once those four values are in scope as shell variables, write `credentials.json`:

```bash
umask 077
mkdir -p "$HOME/.config/employment-hero"
chmod 700 "$HOME/.config/employment-hero"

API_KEY="$(wl-paste | jq -r '.api_key')"
# API_HOST, REGION, BUSINESS_ID already set by the Bash wrappers around Steps 3 and 7

jq -n \
  --arg key "$API_KEY" \
  --arg region "$REGION" \
  --arg ep "https://${API_HOST}/api/v2" \
  --arg bid "$BUSINESS_ID" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{api_key:$key, region:$region, api_endpoint:$ep, business_id:$bid, key_name:"Claude Workshop Connector", created_at:$created}' \
  > "$HOME/.config/employment-hero/credentials.json.tmp"
chmod 600 "$HOME/.config/employment-hero/credentials.json.tmp"
mv "$HOME/.config/employment-hero/credentials.json.tmp" "$HOME/.config/employment-hero/credentials.json"

# Restore prior clipboard
[ -s /tmp/employment-hero-prev-clipboard.b64 ] && base64 -d /tmp/employment-hero-prev-clipboard.b64 | wl-copy
rm -f /tmp/employment-hero-prev-clipboard.b64

unset API_KEY
```

> **Why the variables differ from the clipboard**: the clipboard-transit pattern is for the **secret** (the API key). Non-secret values (region, api_host, business_id) don't need clipboard isolation; they're captured from the Playwright JS return values directly into shell variables in the same script step that ran the `browser_evaluate`. Pattern is: `RESULT="$(jq -r .api_host /tmp/playwright-region-result.json)"` after the Playwright call writes its return value to a known temp file, OR - cleaner - the Playwright wrapper Claude uses captures the JSON result and exports `API_HOST`/`REGION`/`BUSINESS_ID` directly. The exact wiring depends on how the Bash-Playwright glue is implemented in your runtime; what matters is that those three values are populated as shell variables at this point.

### Step 9 - Smoke test

```bash
API_KEY="$(jq -r .api_key "$HOME/.config/employment-hero/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/employment-hero/credentials.json")"
BIZ="$(jq -r .business_id "$HOME/.config/employment-hero/credentials.json")"

curl -sf -u "api:$API_KEY" "$API_ENDPOINT/business/$BIZ" | jq -r '.name'
```

Returns the business name (e.g., `Selrai Pty Ltd`). Tell the participant:

> "All connected - your Employment Hero Payroll **[business name]** is ready. Ask me things like *'list my employees'* or *'show me last week's pay run'*."

If the smoke fails:

- HTTP 401 → key didn't paste correctly; re-run Phase 1 from Step 5.
- HTTP 404 → business_id wrong; re-run Step 7 to detect the right one.

---

## PHASE 2 - Use Tools

### Helper - base curl shape

```bash
eh_get() {
  curl -sf -u "api:$API_KEY" "$API_ENDPOINT$1"
}
eh_post() {
  curl -sf -u "api:$API_KEY" -X POST "$API_ENDPOINT$1" \
    -H 'Content-Type: application/json' \
    -d "$2"
}
eh_put() {
  curl -sf -u "api:$API_KEY" -X PUT "$API_ENDPOINT$1" \
    -H 'Content-Type: application/json' \
    -d "$2"
}
```

### Real-data gate - first invocation per session

```bash
BIZ_NAME="$(eh_get "/business/$BIZ" | jq -r .name)"
```

Tell the participant: *"Just confirming - you're connected to your real Employment Hero Payroll for **[BIZ_NAME]** with **[N]** employees. Anything I do here changes your live payroll. OK to proceed with **[summary]**?"* ONCE per session.

### Destructive-op gate - every write

Patterns 9-10 below (approve / decline leave). Confirmation prompts:

| Operation | Prompt |
|---|---|
| Approve leave | "I'm about to **approve** **[Employee]**'s leave request: **[N hours]** of **[leave type]** starting **[date]**. This adds it to their pay record. OK?" |
| Decline leave | "I'm about to **decline** **[Employee]**'s leave request: **[N hours]** of **[leave type]** starting **[date]**. They'll see the decline in their Employment Hero inbox. OK?" |

### Common Pattern 1 - Business info

```bash
eh_get "/business/$BIZ" | jq '{name, abn, address: .address.full_address, default_pay_run_invoice_email: .default_pay_run_invoice_email}'
```

Returns name, ABN (AU tax ID), address. Present as 2-3 line summary.

**Use when:** "what business am I connected to?", "Employment Hero info"

### Common Pattern 2 - List employees

```bash
eh_get "/business/$BIZ/employee" | jq '.[] | {id, first_name: .first_name, surname: .surname, employee_status: .employee_status, job_title: .job_title}'
```

Returns active + terminated employees. Filter `employee_status = 'Active'` client-side to skip terminated.

**Use when:** "list my employees", "show team", "who's on payroll?"

### Common Pattern 3 - Pay schedule

```bash
eh_get "/business/$BIZ/payschedule" | jq '.[] | {id, name, frequency, next_pay_date, period_ending}'
```

`frequency`: `Weekly`, `Fortnightly`, `Monthly`, `Quarterly`. `next_pay_date` is when the next pay run is due.

**Use when:** "when's next payday?", "pay schedule"

### Common Pattern 4 - Recent pay runs

```bash
eh_get "/business/$BIZ/payrun?status=Finalised&top=10" | jq '.[] | {id, name, date_paid, payment_total: .totals.payment, period_ending: .pay_period_ending}'
```

Returns the last 10 finalised pay runs. Filter `status=Draft` for pending; `status=Finalised` for paid.

**Use when:** "recent pay runs", "last paycheck", "what's my latest payroll?"

### Common Pattern 5 - Specific pay run summary

```bash
PAYRUN_ID="<from Pattern 4>"
eh_get "/business/$BIZ/payrun/$PAYRUN_ID/totals" | jq '.'
```

Returns gross, net, taxes, super, total cost for the pay run. For per-employee detail:

```bash
eh_get "/business/$BIZ/payrun/$PAYRUN_ID/paymentsummary" | jq '.[] | {employee_name, gross: .gross_earnings, net: .net_earnings, tax: .total_tax, super: .super_contributions}'
```

**Use when:** "pay run details for [date]", "what did I pay each person on [date]"

### Common Pattern 6 - Employee details (compensation)

```bash
EMP_ID="<from Pattern 2>"
eh_get "/business/$BIZ/employee/$EMP_ID/paydetails" | jq '{primary_pay_category, hourly_rate, primary_pay_schedule_id, hours_per_week}'
```

Returns current pay rate, weekly hours, primary pay category (e.g., `Hourly`, `Salary`).

**Use when:** "what does [employee] earn?", "[employee]'s pay rate"

### Common Pattern 7 - Leave balances

```bash
EMP_ID="<from Pattern 2>"
eh_get "/business/$BIZ/employee/$EMP_ID/leavebalances" | jq '.[] | {leave_category_name, accrued_amount, balance, units}'
```

Returns balances per leave type (Annual Leave, Personal/Carer's Leave, Long Service Leave, etc.). `units`: usually `Hours` or `Days`.

**Use when:** "[employee]'s leave balance", "how much annual leave does [employee] have?"

### Common Pattern 8 - Pending leave requests

```bash
eh_get "/business/$BIZ/leaverequest?status=Pending" | jq '.[] | {id, employee_id, leave_category, from_date, to_date, total_hours, status, notes}'
```

Filter by `status` = `Pending`, `Approved`, `Rejected`.

**Use when:** "pending leave", "approval queue", "who has time off coming up?"

### Common Pattern 9 - Approve leave (write, gated)

Run Gate 2 first.

```bash
LR_ID="<from Pattern 8>"
eh_put "/business/$BIZ/leaverequest/$LR_ID/approve" '{}'
```

Returns the updated leave request with `status: Approved`. Tells participant: *"Approved [Employee]'s [N hours] of [leave type]."*

**Use when:** "approve [employee]'s leave", "approve PTO for [date]"

### Common Pattern 10 - Decline leave (write, gated)

Run Gate 2 first.

```bash
LR_ID="<from Pattern 8>"
REASON="<optional plain-English decline reason>"
eh_put "/business/$BIZ/leaverequest/$LR_ID/reject" "$(jq -n --arg r "$REASON" '{notes:$r}')"
```

**Use when:** "decline [employee]'s leave", "reject this leave"

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "Business info" / "What am I connected to?" | Pattern 1 |
| "List my employees" / "Show team" | Pattern 2 |
| "Pay schedule" / "Next payday?" | Pattern 3 |
| "Recent pay runs" / "Last payroll" | Pattern 4 |
| "Pay run details for [date]" | Pattern 5 |
| "Pay slips" / "What was on [employee]'s pay slip?" | Pattern 5 (`paymentsummary` per-employee line items - the API has no pay-slip PDF endpoint in v1; point the participant at the web UI for the PDF) |
| "What does [employee] earn?" | Pattern 6 |
| "[Employee]'s leave balance" / "How much leave does X have?" | Pattern 7 |
| "Pending leave" / "Approval queue" | Pattern 8 |
| "Approve [employee]'s leave" | Pattern 9 (gated) |
| "Decline [employee]'s leave" | Pattern 10 (gated) |
| "Connect Employment Hero" / "Set up payroll" | **Run Phase 1** |
| "Run payroll" / "Process pay run" / "Finalise pay run" | **NOT in v1** - tell the participant: "Running payroll is too high-stakes for me to do automatically. Please finalise the pay run from Employment Hero's web UI." |
| Anything about leave types, performance reviews, HR onboarding | **Out of v1 scope** - those are in Employment Hero's core HR API (partner-gated). Suggest the participant manage in the web UI. |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `Unauthorized` | API key revoked or wrong region host | Tell participant: "Looks like the connection was disconnected - let me reconnect." Re-run Phase 1. |
| HTTP 401 `User does not have permission for this business` | API key was generated under a different business's tenant | Re-detect business_id in Phase 1 Step 7. |
| HTTP 404 on `/business/<id>` | business_id stale or wrong | Re-run Step 7 to detect the right id. |
| HTTP 422 `Validation` on Pattern 9/10 | Leave request no longer pending (approved/rejected by someone else) | Translate: "Looks like that request was already handled. Want me to check the queue again?" |
| HTTP 429 | Hit Employment Hero Payroll's rate cap | Wait 30s, retry once. |
| Network error to `api.yourpayroll.*` | Region host wrong (e.g., AU host for UK account) | Verify `region` and `api_endpoint` match the participant's account location. |

Translate every error to plain English. Never show raw HTTP bodies.

---

## Scope Limitations

This connector **can**:

- Read all standard read endpoints: business info, employees, pay schedules, pay runs (history + per-pay-run line items), employee compensation, leave balances, leave requests.
- Approve / decline pending leave requests.

It **cannot**:

- **Run / finalise a pay run** - `POST /payrun/.../finalise` is out of v1 scope. Too high-stakes; participant finalises in the web UI. Tracked as v2 with extra gates.
- **Onboard new employees** - requires sensitive PII (TFN, super fund, bank). Out of v1.
- **Modify pay rates** - writes affect future paychecks. v1 keeps these read-only.
- **Generate STP (Single Touch Payroll) submissions** - compliance-critical AU obligation; v1 does not touch.
- **Access core HR API** (people module, performance, learning) - that surface is partner-gated at oauth.employmenthero.com. Out of v1 scope. v2 enhancement if SelrAI applies as an Employment Hero partner.
- **Multi-business switching** mid-session - the `business_id` is locked in `credentials.json` at install time. To switch businesses, re-run Phase 1.

It **requires** the participant to have **Full Access** role on the Payroll product. View-only roles can't generate API keys.

---

## Behaviour Guidelines (Phase 2)

- **Real-data awareness** - every Phase 2 call hits real payroll. Real-data gate on first call per session; per-write gate on every write.
- **Currency presentation** - Employment Hero Payroll returns monetary values as numeric (e.g., `2548.50`). Format as `$X.XX AUD` (or regional currency).
- **Employee names** - Pattern 2 returns `first_name` + `surname` separately; concatenate for display.
- **Dates** - Employment Hero Payroll uses ISO-8601 (`2026-06-02T00:00:00`).
- **Leave types** - AU-specific (Annual, Personal/Carer's, Long Service, Compassionate, Parental). Don't translate the names; present as Employment Hero Payroll labels them.
- **Hours vs Days** - leave balances may be in either unit. Always check `units` field before assuming.
- **Auth errors** → re-run Phase 1.
- **Never log or echo the API key**.
- **Write confirmations** - name the employee, hours, leave type, dates in plain English before each write.

---

## Related Skills

- **`gusto-connector`**: Sibling Tier-1 payroll connector for the US market. Same pattern shape (employees, pay runs, leave) but different auth (OAuth2 vs HTTP Basic) and different leave-type vocabulary (PTO vs Annual Leave).
- **`myob-connector`**: AU SMB sibling for the accounting side. Many AU SMBs use MYOB for bookkeeping + Employment Hero Payroll for payroll. Pair when participant runs both.
- **`xero-connector`**: AU SMB sibling for the accounting side (larger market share than MYOB). Same pairing pattern.
- **`quickbooks-connector`**: Less common in AU but pairs with Employment Hero Payroll for global SMBs running QBO + AU operations.
- **`superpowers:systematic-debugging`**: For region-host detection or tenant-id edge cases.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - three-pattern decision tree. Direct-REST out-of-scope sibling.
- [Employment Hero Payroll API reference](https://api.yourpayroll.com.au/docs/api/) - official endpoint catalogue (formerly KeyPay docs).
- [Employment Hero core developer portal](https://developer.employmenthero.com/) - partner-gated HR API (out of v1 scope).
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` - say "Employment Hero Payroll" not "KeyPay" to participants.
