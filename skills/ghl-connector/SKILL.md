---
name: ghl-connector
description: Install and operate the GoHighLevel (GHL) connector. Use this skill when the user asks to set up GHL, connect their CRM, or work with contacts, pipelines/opportunities, calendar bookings, email/SMS campaigns, or conversations. GHL has no CLI — operations run through Playwright browser automation, with the GHL REST API as a fallback for headless or bulk tasks.
metadata:
  category: CRM & Marketing
  tags:
    - ghl
    - gohighlevel
    - crm
    - contacts
    - pipelines
    - opportunities
    - calendar
    - campaigns
    - sms
    - email
  pairs-with:
    - skill: playwright-skill
      reason: Required engine for all GHL UI automation — GHL ships no CLI, every browser action goes through this skill
    - skill: email-composer
      reason: Draft campaign copy or one-off emails before pushing them into a GHL template
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by GHL webhook events (new contact, opportunity stage change, booking created)
---

# GoHighLevel (GHL) Connector

## Overview

This skill does two things:
1. **Installs** the GHL connector on the user's computer (one-time browser login + optional API token)
2. **Operates** the connector — managing contacts, pipelines, calendar bookings, campaigns, and conversations

GHL has **no official CLI**. The connector uses two transports:

| Mode | Engine | When to use |
|---|---|---|
| **Browser (primary)** | `playwright-skill` automating app.gohighlevel.com | UI-only flows: SMS/conversations, campaign builder, anything not exposed by the API, or when the user has no Private Integration Token |
| **API (fallback)** | `curl` against `https://services.leadconnectorhq.com` with a Private Integration Token | Headless/bulk reads, scheduled jobs, anything where opening a browser is overkill |

> **Decision rule:** Default to API for read operations on contacts, opportunities, calendars, and conversations once a token is configured. Use the browser for SMS sends, campaign edits, workflow enrolment UI, and any operation the API does not cover.

> **Account support:** Works with both Sub-Account (Location) and Agency contexts. Always confirm with the user which scope they want before mutating data.

---

## Part 1 — Installation & Auth

### Step 1: Confirm `playwright-skill` is installed

The browser path requires it. Check for it under one of:
- `~/.claude/plugins/marketplaces/playwright-skill/skills/playwright-skill`
- `~/.claude/skills/playwright-skill`
- `<project>/.claude/skills/playwright-skill`

If missing, install it first, then run its one-time setup:
```bash
cd $PLAYWRIGHT_SKILL_DIR && npm run setup
```
This installs Playwright + Chromium. Only needed once per machine.

### Step 2: Pick the scope

Ask the user: **Sub-Account (Location)** or **Agency**?
- **Sub-Account** is the normal answer — single business, single location. All examples below assume this.
- **Agency** scope is needed only for multi-location reporting or cross-location user management. Confirm explicitly before agency mutations.

### Step 3: Browser login (one-time)

Launch a visible Chromium via the playwright-skill, navigate to `https://app.gohighlevel.com/`, let the user sign in, then save the storage state so future sessions reuse it.

Write the script to `/tmp/ghl-login.js` (never inside the skill dir):

```js
// /tmp/ghl-login.js
const { chromium } = require('playwright');
const path = require('path');
const os = require('os');
const fs = require('fs');

(async () => {
  const stateDir = path.join(os.homedir(), '.claude', 'state');
  fs.mkdirSync(stateDir, { recursive: true });
  const statePath = path.join(stateDir, 'ghl-storage.json');

  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.goto('https://app.gohighlevel.com/');
  console.log('Sign in to GHL in the open window. Press Enter in this terminal when the dashboard is loaded.');
  process.stdin.resume();
  await new Promise(r => process.stdin.once('data', r));
  await ctx.storageState({ path: statePath });
  console.log('Saved storage state to', statePath);
  await browser.close();
})();
```

Run it via the playwright-skill's executor:
```bash
cd $PLAYWRIGHT_SKILL_DIR && node run.js /tmp/ghl-login.js
```

> **Reuse:** Every subsequent script should load this state with `chromium.launch({ headless: false }).then(b => b.newContext({ storageState: '~/.claude/state/ghl-storage.json' }))`. If the state expires (you land on the login page), re-run Step 3.

### Step 4: API token (recommended fallback)

1. In GHL, go to **Settings → Private Integrations** (sub-account scope).
2. Click **Create New Integration**, give it a name like "Claude Code", and grant the scopes you need (start with `contacts.readonly`, `contacts.write`, `opportunities.readonly`, `opportunities.write`, `calendars.readonly`, `calendars/events.readonly`, `conversations.readonly`).
3. Copy the token (`pit-...`) — GHL only shows it once.
4. Copy the **Location ID** from **Settings → Business Profile**.
5. Save both to your shell profile (`~/.zshrc` / `~/.bashrc`):
   ```bash
   export GHL_PIT="pit-xxxxxxxxxxxxxxxxxxxxxxxx"
   export GHL_LOCATION_ID="xxxxxxxxxxxxxxxxxxxxxxxx"
   ```
6. `source` the file or open a new terminal.

### Step 5: Verify

**API path:**
```bash
curl -s "https://services.leadconnectorhq.com/contacts/?locationId=${GHL_LOCATION_ID}&limit=1" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Accept: application/json"
```
A JSON body with a `contacts` array (possibly empty) means the API is wired up. A 401 means the token is wrong; a 403 means the integration is missing the required scope.

**Browser path:** run a one-line script that opens the contacts page using the saved storage state and prints the page title — if it shows the GHL dashboard title (not "Login"), the storage state is good.

---

## Part 2 — Contacts

> **Confirm before creating, updating, deleting, or tagging.** Always echo the change back to the user with the contact's name and ID before executing.

### List recent contacts (API)
```bash
curl -s "https://services.leadconnectorhq.com/contacts/?locationId=${GHL_LOCATION_ID}&limit=10" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Search contacts by email (API)
```bash
curl -s "https://services.leadconnectorhq.com/contacts/search/duplicate?locationId=${GHL_LOCATION_ID}&email=user@example.com" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Get a single contact (API)
```bash
curl -s "https://services.leadconnectorhq.com/contacts/CONTACT_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Create a contact (API)
```bash
curl -s -X POST "https://services.leadconnectorhq.com/contacts/" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "locationId": "'"${GHL_LOCATION_ID}"'",
    "firstName": "Jane",
    "lastName": "Doe",
    "email": "jane@example.com",
    "phone": "+61400000000",
    "tags": ["lead"],
    "source": "Claude Code"
  }'
```
> Always confirm the full payload with the user before posting.

### Update a contact (API)
```bash
curl -s -X PUT "https://services.leadconnectorhq.com/contacts/CONTACT_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "firstName": "Janet" }'
```

### Add or remove a tag (API)
```bash
# Add
curl -s -X POST "https://services.leadconnectorhq.com/contacts/CONTACT_ID/tags" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "tags": ["vip", "newsletter"] }'

# Remove
curl -s -X DELETE "https://services.leadconnectorhq.com/contacts/CONTACT_ID/tags" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "tags": ["newsletter"] }'
```

### Add a note (API)
```bash
curl -s -X POST "https://services.leadconnectorhq.com/contacts/CONTACT_ID/notes" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "body": "Called and left voicemail.", "userId": "USER_ID" }'
```

### Browser fallback — search and open a contact

Use only when the API token is unavailable or the user asks for the UI view.

```js
// /tmp/ghl-find-contact.js
const { chromium } = require('playwright');
const STATE = require('os').homedir() + '/.claude/state/ghl-storage.json';
const QUERY = process.env.QUERY || 'jane@example.com';

(async () => {
  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext({ storageState: STATE });
  const page = await ctx.newPage();
  await page.goto('https://app.gohighlevel.com/v2/location/contacts/smart_list/All');
  await page.getByPlaceholder(/search/i).fill(QUERY);
  await page.waitForTimeout(1500);
  const rows = await page.locator('[data-testid="contact-row"]').allTextContents();
  console.log(JSON.stringify(rows, null, 2));
  await browser.close();
})();
```
Run with `QUERY="jane@example.com" node run.js /tmp/ghl-find-contact.js`.

> If a selector fails, **stop and ask the user** to confirm the GHL UI hasn't changed — never blind-retry destructive clicks.

---

## Part 3 — Pipelines & Opportunities

### List pipelines (API)
```bash
curl -s "https://services.leadconnectorhq.com/opportunities/pipelines?locationId=${GHL_LOCATION_ID}" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```
Returns pipeline IDs and their stage IDs — capture both for the next calls.

### List opportunities by stage (API)
```bash
curl -s "https://services.leadconnectorhq.com/opportunities/search?location_id=${GHL_LOCATION_ID}&pipeline_id=PIPELINE_ID&pipeline_stage_id=STAGE_ID&limit=20" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Get a single opportunity (API)
```bash
curl -s "https://services.leadconnectorhq.com/opportunities/OPPORTUNITY_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Create an opportunity (API)
```bash
curl -s -X POST "https://services.leadconnectorhq.com/opportunities/" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "locationId": "'"${GHL_LOCATION_ID}"'",
    "pipelineId": "PIPELINE_ID",
    "pipelineStageId": "STAGE_ID",
    "name": "Acme Co — discovery call",
    "monetaryValue": 5000,
    "status": "open",
    "contactId": "CONTACT_ID"
  }'
```

### Move an opportunity to another stage (API)
```bash
curl -s -X PUT "https://services.leadconnectorhq.com/opportunities/OPPORTUNITY_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "pipelineStageId": "NEW_STAGE_ID" }'
```
> Always confirm the source stage, target stage, and opportunity name with the user before moving.

### Update status (won / lost / abandoned) (API)
```bash
curl -s -X PUT "https://services.leadconnectorhq.com/opportunities/OPPORTUNITY_ID/status" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{ "status": "won" }'
```

---

## Part 4 — Calendar

### List calendars (API)
```bash
curl -s "https://services.leadconnectorhq.com/calendars/?locationId=${GHL_LOCATION_ID}" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### List bookings for a calendar in a date range (API)
```bash
# Times are unix milliseconds
curl -s "https://services.leadconnectorhq.com/calendars/events?locationId=${GHL_LOCATION_ID}&calendarId=CALENDAR_ID&startTime=1712880000000&endTime=1712966400000" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Create a booking (API)
```bash
curl -s -X POST "https://services.leadconnectorhq.com/calendars/events/appointments" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "calendarId": "CALENDAR_ID",
    "locationId": "'"${GHL_LOCATION_ID}"'",
    "contactId": "CONTACT_ID",
    "startTime": "2026-04-20T15:00:00+10:00",
    "endTime":   "2026-04-20T15:30:00+10:00",
    "title": "Discovery call",
    "appointmentStatus": "confirmed"
  }'
```
> Confirm the contact, calendar, start time, and timezone with the user before creating.

### Cancel a booking (API)
```bash
curl -s -X DELETE "https://services.leadconnectorhq.com/calendars/events/appointments/APPOINTMENT_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```
> Cancellation triggers GHL's notification workflows. Always confirm with the user first.

---

## Part 5 — Email Campaigns

> The Marketing → Emails area is mostly UI-driven. Use the API for one-off sends and workflow enrolment; use the browser for the campaign builder.

### Send a one-off email via a template (API)
```bash
curl -s -X POST "https://services.leadconnectorhq.com/conversations/messages" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "Email",
    "contactId": "CONTACT_ID",
    "subject": "Following up",
    "html": "<p>Hi Jane, just checking in.</p>",
    "emailFrom": "you@yourdomain.com"
  }'
```
> Always show the user the subject + body before sending.

### Enrol a contact in a workflow (API)
```bash
# List workflows
curl -s "https://services.leadconnectorhq.com/workflows/?locationId=${GHL_LOCATION_ID}" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"

# Add contact
curl -s -X POST "https://services.leadconnectorhq.com/contacts/CONTACT_ID/workflow/WORKFLOW_ID" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Browser — open the campaign builder for editing
```js
// /tmp/ghl-open-campaign.js
const { chromium } = require('playwright');
const STATE = require('os').homedir() + '/.claude/state/ghl-storage.json';
(async () => {
  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext({ storageState: STATE });
  const page = await ctx.newPage();
  await page.goto('https://app.gohighlevel.com/v2/location/marketing/emails/campaigns');
  console.log('Campaign list loaded — leave window open for the user.');
  // intentionally no browser.close() — let the user drive
})();
```

---

## Part 6 — SMS / Conversations (browser-only)

The conversations API can read messages but **sending SMS is reliably handled in the UI**. Default to the browser for sends.

### List recent conversations (API)
```bash
curl -s "https://services.leadconnectorhq.com/conversations/search?locationId=${GHL_LOCATION_ID}&limit=10" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Get messages in a conversation (API)
```bash
curl -s "https://services.leadconnectorhq.com/conversations/CONVERSATION_ID/messages" \
  -H "Authorization: Bearer ${GHL_PIT}" \
  -H "Version: 2021-07-28"
```

### Send an SMS (browser)

```js
// /tmp/ghl-send-sms.js
const { chromium } = require('playwright');
const STATE = require('os').homedir() + '/.claude/state/ghl-storage.json';
const CONTACT_ID = process.env.CONTACT_ID;   // required
const BODY = process.env.BODY;                // required

(async () => {
  if (!CONTACT_ID || !BODY) throw new Error('CONTACT_ID and BODY required');
  const browser = await chromium.launch({ headless: false });
  const ctx = await browser.newContext({ storageState: STATE });
  const page = await ctx.newPage();
  await page.goto(`https://app.gohighlevel.com/v2/location/contacts/detail/${CONTACT_ID}`);
  await page.getByRole('tab', { name: /conversation/i }).click();
  await page.getByRole('button', { name: /sms/i }).click();
  await page.getByRole('textbox', { name: /message/i }).fill(BODY);
  // PAUSE for user confirmation — do NOT auto-click send
  console.log('Message drafted. Switch to the browser and click Send if the body looks right.');
})();
```
> **Never auto-click Send for SMS.** Draft the message, then hand the browser to the user to review and send. Echoing the recipient and body back to the user in the transcript is required.

---

## Part 7 — Direct API Reference

- **Base URL:** `https://services.leadconnectorhq.com`
- **Required headers on every call:**
  - `Authorization: Bearer ${GHL_PIT}`
  - `Version: 2021-07-28`
  - `Content-Type: application/json` (on POST/PUT/DELETE with a body)
- **Pagination:** Most list endpoints accept `limit` (default 20, max 100) and a `startAfterId` / `offset` cursor in the response. Default to `limit=10` unless the user asks for more.
- **Rate limits:** GHL enforces per-token rate limits. On HTTP 429, back off for at least 5 seconds before retrying. Never retry mutating calls without re-confirming with the user.
- **ID prefixes:** Contacts, opportunities, calendars, and conversations use opaque alphanumeric IDs with no human-readable prefix — always echo the related name (contact name, opportunity title) back to the user when an ID appears in output.
- **Scopes:** A 403 means the Private Integration is missing a scope. Tell the user which scope to add and re-issue the token.

---

## Behaviour Guidelines

- **Verify auth at session start.** Run the verification curl from Step 5 (or a tiny browser title check) before the first mutating action of a session.
- **Confirm before mutating.** Always confirm with the user before creating, updating, tagging, deleting contacts; before moving or creating opportunities; before booking or cancelling appointments; before sending emails or SMS.
- **Default to API for reads, browser for UI-only writes.** Don't burn a Playwright session on a contact lookup if the API can answer it.
- **Sub-account scope by default.** Never make agency-wide changes without explicit user confirmation of the scope.
- **Reuse browser storage state.** Never prompt the user to log in again unless `~/.claude/state/ghl-storage.json` is missing or expired (you land on the GHL login page).
- **Write Playwright scripts to `/tmp/ghl-*.js`.** Per the playwright-skill conventions — never inside the skill dir or the workshop kit.
- **Use a visible browser (`headless: false`)** for any flow that may need user intervention. Headless is fine only for fully scripted reads.
- **Mask PII when echoing.** When summarising contacts back to the user in the transcript, partially mask phone numbers (`+61 400 *** 000`) and emails (`j***@example.com`) unless the user explicitly asks for the full value.
- **Stop on selector failure.** If a Playwright locator can't find an element, stop and report it. Do not retry destructive clicks (Send, Delete, Move) blindly — the GHL UI changes often.
- **Never auto-click Send for SMS.** Draft the message in the UI and hand control back to the user.
- **Token hygiene.** The Private Integration Token is sensitive — never echo `GHL_PIT` to the transcript, never write it to a file inside the project, never include it in a commit. If the user pastes one inline, treat it as a one-time secret and tell them to move it into `~/.zshrc`.
- **Auth errors.** A 401 means the token is wrong or revoked — tell the user to re-issue it. A 403 means a missing scope — tell the user which one.
