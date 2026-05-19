---
name: ghl-connector
description: "Connect and operate GoHighLevel (GHL) via the official HighLevel MCP server (services.leadconnectorhq.com/mcp/). Use this skill when the user asks to set up GHL, connect their CRM, or interact with contacts, conversations, opportunities, pipelines, calendar, payments, blogs, email templates, or social posts. On first use, run Phase 1: Claude drives the browser end-to-end via Playwright, mints the Private Integration Token autonomously, ticks every available scope, and saves the connection. The user only signs in to GHL, names the sub-account if they have several, and restarts Claude Code once at the end."
allowed-tools: mcp__ghl__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
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
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting PIT/scope or MCP connection errors
    - skill: playwright-skill
      reason: Used only as a fallback for UI-only surfaces the official MCP server doesn't cover (visual workflow editor, full email campaign builder, SMS draft-before-send, calendar create/cancel, invoices, products)
    - skill: monday-connector
      reason: Sibling Pattern-2 connector with the same Playwright-driven Phase 1 shape
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
---

# GoHighLevel (GHL) Connector

> **Install pattern:** Hosted-bearer-PAT. See [skills/CLAUDE.md](../CLAUDE.md) for the cross-pattern overview.

## Overview

This skill reads and writes data in the user's GoHighLevel sub-account using the **official HighLevel MCP server** at `https://services.leadconnectorhq.com/mcp/`. It has two phases:

- **Phase 1: Install & Auth.** Autonomous. Claude opens GHL in a Playwright-driven browser, waits for the user to sign in, identifies the right sub-account, navigates to Settings → Private Integrations, revokes any prior "Claude Code" integration, runs the two-step Create wizard, ticks every available scope (146 scopes via a single "Select all" checkbox), confirms past the "Security Risk" modal that GHL pops on broad scope grants, reads the token from the success modal, writes the MCP config with both required headers (`Authorization` and `locationId`), and verifies. The user's only manual actions are: sign in once, name the sub-account if they have several, and restart Claude Code once at the end.
- **Phase 2: Use Tools.** Once the connector is configured, call the `mcp__ghl__*` native tools. The HighLevel MCP server currently exposes **36 tools** across 10 resource areas (verified live 2026-05-18 against `https://services.leadconnectorhq.com/mcp/`): blogs, calendars (read-only), contacts, conversations, emails (templates only), locations, opportunities, payments (read-only), and social media posting.

**Which phase to run.** Before any tool call, run the Phase 0 resume check below. If GHL is already configured and the token still works, skip straight to Phase 2.

### What this skill does NOT use

- **Curl recipes, shell envvars, manual JSON editing.** All install paths go through `claude mcp add` (with a direct JSON-write fallback only if the CLI fails).
- **Agency-level API keys.** PITs are minted on a single sub-account. Agency-wide access is a separate workflow the user can request later.
- **OAuth.** GHL Private Integrations are long-lived bearer tokens minted from a settings page. No OAuth dance.
- **Reading the PIT back from GHL after creation.** GHL shows the PIT once. If we lose it, the only path is to revoke and mint a new one (which is exactly what Phase 1 does on re-run).

---

## Phase 0: Resume check

Before any other action, decide whether to run Phase 1 or skip to Phase 2.

> **Critical — memory is NOT authoritative.** Memory files, the user profile, past conversation context, prior knowledge, and the assistant's training prior may all suggest GHL is already connected. **Ignore all of them.** The only ground truth for "is GHL configured" is the live contents of `~/.claude.json`. You **MUST** read that file on every invocation before saying anything to the user about state. Never claim "GHL is already connected" without proving it from the file in this same turn. If the file has no `mcpServers.ghl` entry, GHL is not configured, regardless of what memory or context says.

Read `~/.claude.json` (Windows: `%USERPROFILE%\.claude.json`) and look for `mcpServers.ghl`. Three branches:

1. **Entry exists, has both `headers.Authorization` (non-placeholder) and `headers.locationId` (non-placeholder).** Run a single smoke call: `mcp__ghl__locations_get-location`.
   - **Returns the sub-account.** Tell the user they're already connected, surface the sub-account name (from the response's `name` field), skip to Phase 2.
   - **Returns 401 / Unauthorized / Invalid token.** Token is dead. Run Phase 1 (the revoke-and-remint logic handles the stale GHL-side PIT).
   - **Returns 403 / Insufficient scope.** A previous install minted the PIT with too few scopes. Run Phase 1 (the all-scopes mint will fix it).
   - **MCP tools not yet visible in this session.** The entry exists on disk but Claude Code hasn't reconciled. Tell the user to restart Claude Code and re-ask, then stop.
2. **Entry exists but `Authorization` or `locationId` is a placeholder string** (e.g. `"Bearer <PIT>"`, `"<sub-account-id>"`). Treat as not configured. Run Phase 1.
3. **No entry.** Run Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous. Claude does the work; the user signs in, names a sub-account if asked, restarts Claude Code at the end. Every message during Phase 1 follows these rules:

- **Claude drives, not the user.** Never ask the user to click menus, copy text, or paste values. The only actions ever requested are sign-in, sub-account name (if applicable), and the final restart.
- **Plain English only.** Banned words in user-facing messages: `npm`, `npx`, `bash`, `CLI`, `API`, `terminal`, `config file`, `OAuth`, `scope`, `token`, `tenant`, `MCP`, `endpoint`, `JSON`, `GraphQL`, `Playwright`, `browser automation`, `environment variable`, `Private Integration`, `PIT`, `locationId`, `Bearer`, `header`. The browser window is "a browser window I just opened for you" or "the GoHighLevel page". The Private Integration Token is "the connection key". The MCP config is "your settings".
- **Narrate at action boundaries, not inside tool sequences.** One message when starting ("I'm opening GoHighLevel now"), one when needing the user ("please sign in"), one when needing a choice ("which sub-account"), one when done ("you're connected"). No commentary in between.
- **React warmly to success and failure.** Good: "That worked. Your GoHighLevel is now connected." Bad: "200 OK from locations_get-location."
- **Never show error messages.** Translate. If something fails, say "No problem, let me try a different way," and diagnose silently.
- **Short responses.** Maximum 8 lines per user-facing message during Phase 1.
- **Never reveal file paths, commands, scripts, snapshot details, or selectors.**
- **No name greetings.** Do not address the user by name unless they used their own name in this conversation. Names that live in memory or user profiles belong to past sessions; using them here breaks the workshop-attendee illusion and the test-user check. Open with "Hi there" or just start the work.

---

## PHASE 1: Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user signs in to GHL once, optionally names a sub-account, and restarts Claude Code at the end. Everything else is automatic.

> **Reasoning model.** Each step below describes a goal. Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_evaluate` / `browser_navigate` / `browser_type`. Do not hardcode CSS selectors. GHL's UI changes frequently. Re-snapshot whenever the page state changes.

### Step 1: Ensure Playwright MCP is available

If `mcp__playwright__*` (or `mcp__plugin_playwright_playwright__*`) tools are not visible in this session, install Playwright MCP first per the cross-cutting contingency in [skills/CLAUDE.md](../CLAUDE.md):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then tell the user to close and reopen Claude Code once so the surface reconciles, and stop. The user will return and re-trigger Phase 1.

### Step 2: Orient the user

Send one short message:

> "I'll connect your GoHighLevel now. I'm opening a browser window for you. Please sign in there when it appears, and I'll take it from there. Should take about a minute."

### Step 3: Open GHL and wait for a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://app.gohighlevel.com/" })`. Take a snapshot.

- **Logged-in shell visible** (agency dashboard at `/agency_dashboard?tab=summary`, or a sub-account inner page with a left sidebar containing "Conversations" / "Contacts" / "Opportunities"). Continue to Step 4.
- **Not logged in** (sign-in form, marketing landing, or "Get Started" CTA). Send one message: *"The browser is open. Please sign in to GoHighLevel when you're ready."* Then poll silently for the URL to change.

> **Playwright MCP timeout cap.** `browser_wait_for({ text: "...", time: 300 })` does **not** wait 5 minutes. The Playwright MCP backend hard-caps every tool call at 30 seconds and throws `TimeoutError: browserBackend.callTool: Timeout 30000ms exceeded` if `text` hasn't appeared by then. Do not pass a `time` value above 25 expecting the SKILL to wait that long. The correct pattern is a poll loop:
>
> 1. `mcp__playwright__browser_evaluate({ function: "() => window.location.href" })`.
> 2. If the URL is still the marketing/login page (`https://app.gohighlevel.com/` exactly, or `/login...`), call `mcp__playwright__browser_wait_for({ time: 25 })` to sleep 25 seconds within the cap.
> 3. Loop back to step 1.
> 4. Exit the loop when the URL contains `/agency_dashboard`, `/v2/location/`, or any other authenticated path.
>
> Run the loop for up to 12 iterations (~5 minutes). Do not ask the user to confirm they signed in — detect from the URL.

If the user has not signed in after 12 loop iterations, check in once: *"Still on the sign-in page? Anything I can help with?"*

### Step 4: Land the user on a sub-account and capture the locationId

GHL's sub-account URL shape is `https://app.gohighlevel.com/v2/location/<locationId>/...`. The locationId is the ground truth — capture it from `window.location.href`.

Call:

```
mcp__playwright__browser_evaluate({ function: "() => window.location.href" })
```

Three branches based on the URL:

- **URL already contains `/v2/location/<id>/`.** The user is inside a sub-account. Extract the locationId via regex (`/v2/location/([A-Za-z0-9]+)/`). Save it. Continue to Step 5.
- **URL is `/agency_dashboard...` or another agency-level path.** The user is in the agency view and has not picked a sub-account. Send one short message:

  > "I can see your GoHighLevel. Which sub-account would you like me to connect to?"

  Wait for the user's answer. Once they name one, navigate to the sub-accounts list (`https://app.gohighlevel.com/sub-accounts`).

  The sub-account list is **virtualised** by React, so most rows are not in the DOM until you filter. Type the user's answer into the page's search box, then read the visible row's `href` to get the locationId without clicking. The search input has placeholder `Search by Sub-Account`, and a native React-controlled value setter is required to fire the search:

  ```
  mcp__playwright__browser_evaluate({ function: `() => {
    const inp = Array.from(document.querySelectorAll('input')).find(i => i.placeholder === 'Search by Sub-Account');
    if (!inp) return 'no-search-input';
    inp.focus();
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    setter.call(inp, '<sub-account name>');
    inp.dispatchEvent(new Event('input', { bubbles: true }));
    inp.dispatchEvent(new Event('change', { bubbles: true }));
    return 'typed';
  }` })
  ```

  Wait 2-3 seconds for the filtered list to render, then read the locationId straight from the row's `href`:

  ```
  mcp__playwright__browser_evaluate({ function: `() => {
    const a = document.querySelector('a[href*="/accounts/detail/"]');
    return a ? { text: a.textContent.trim(), href: a.getAttribute('href') } : null;
  }` })
  ```

  The `href` is `/accounts/detail/<locationId>`. Extract the locationId from there and skip clicking — you have what you need. Continue to Step 5 with this locationId.

  If the search returns zero matches, ask the user for a more distinguishing word (or the exact name) and retry. If it returns multiple matches, ask the user to disambiguate.
- **URL is some other authenticated path.** Navigate to `https://app.gohighlevel.com/sub-accounts` and handle as the agency case above.

The locationId is 20+ alphanumeric chars (e.g. `nNuYnWnDjcVfDq5aYUze`). If the regex returns something shorter or with hyphens/slashes, re-snapshot and re-read `window.location.href` after a brief `browser_wait_for`.

### Step 5: Navigate to Private Integrations

Navigate directly to the deep link:

```
mcp__playwright__browser_navigate({ url: "https://app.gohighlevel.com/v2/location/<locationId>/settings/private-integrations" })
```

Wait for the heading "Private Integrations" to be visible (`browser_wait_for({ text: "Private Integrations" })`). The page shows a "Create New Integration" button and a table of existing integrations. Continue to Step 6.

### Step 6: Revoke any existing "Claude Code" integration

Snapshot the integrations table. Look for a row whose name cell is exactly "Claude Code" (case-insensitive).

- **Found.** Each integration row has a three-dots icon button whose **accessible name is exactly** `Actions for integration <name>` (so for the Claude Code row, it's `Actions for integration Claude Code`). The button has no visible text — match it by `aria-label`, not by text content:

  ```
  mcp__playwright__browser_evaluate({ function: `() => {
    const btn = document.querySelector('button[aria-label="Actions for integration Claude Code"]');
    if (!btn) return 'not-found';
    btn.click();
    return 'clicked';
  }` })
  ```

  A popup menu appears with a destructive option (label varies: "Delete", "Revoke"). Snapshot the page, find that button by text, click it. A confirmation modal then appears with Cancel and Confirm buttons — click Confirm. Re-snapshot the integrations table and verify the "Claude Code" row is gone before continuing. If the row is still there, retry once.
- **Not found.** Continue to Step 7.

If the deletion fails or the row reappears after re-snapshot, retry once. If still failing, stop and tell the user: *"There's an old Claude Code connection that I can't remove. Could you delete it manually and let me know when it's done?"* Wait for them, then re-snapshot.

### Step 7: Create a fresh Private Integration with every scope

The Create flow is a **two-step wizard**, not a single form. The skill walks both steps.

**Step 7a — Basic info.** Click the `Create new integration` button. A side panel opens with two tabs at the top: "Basic info" (active) and "Scopes". Fill the form:

- **Name field** (labelled "Enter name", required, marked with `*`). Type `Claude Code`. The Next button is disabled until this is filled.
- **Description field** (labelled "Provide a description of your integration"). Leave blank or type `Claude Code workshop install`.

Click the `Next` button. The panel transitions to the Scopes step.

**Step 7b — Scopes.** The scopes selector is a custom searchable dropdown with a single `Select all` checkbox that ticks every available scope in one click. The dropdown trigger has CSS class `.hr-base-selection` and the checkboxes have class `.hr-checkbox`.

Open the dropdown:

```
mcp__playwright__browser_evaluate({ function: `() => {
  const target = document.querySelector('.hr-base-selection');
  if (!target) return 'no-target';
  target.click();
  return 'opened';
}` })
```

Wait 1 second for the popover to render, then click the Select-all checkbox. Match by the parent `.hr-checkbox` element whose text content is exactly "Select all" (the inner `<input>` element doesn't carry the label):

```
mcp__playwright__browser_evaluate({ function: `() => {
  const all = Array.from(document.querySelectorAll('.hr-checkbox'));
  const selectAll = all.find(el => /^select all$/i.test((el.textContent || '').trim()));
  if (!selectAll) return 'not-found';
  selectAll.click();
  return 'clicked';
}` })
```

Verify by reading the counter (a leaf element whose text matches `N of N selected`):

```
mcp__playwright__browser_evaluate({ function: `() => {
  const el = Array.from(document.querySelectorAll('*'))
    .find(e => /^\d+ of \d+ selected$/i.test((e.textContent || '').trim()) && e.children.length === 0);
  return el ? el.textContent.trim() : null;
}` })
```

The counter should read "N of N selected" (both numbers equal — currently 146, but the GHL surface grows; don't hardcode 146). If the counter still shows `0 of N selected`, the click missed — re-snapshot and retry. If it shows `K of N selected` with K between 0 and N, the click toggled into half-selected; click `Select all` once more.

Press `Escape` to close the dropdown. The selected scopes now render as chips in the field, and the bottom `Create` button is enabled.

Click the bottom `Create` button (match by visible text `Create`, not by class — there are usually two Cancel buttons + Create + Confirm on the page at this point, find the one in the form footer):

```
mcp__playwright__browser_evaluate({ function: `() => {
  const buttons = Array.from(document.querySelectorAll('button')).filter(b => {
    const r = b.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  });
  const create = buttons.find(b => /^Create$/i.test((b.textContent || '').trim()));
  if (!create || create.disabled) return 'no-create-or-disabled';
  create.click();
  return 'clicked-create';
}` })
```

**Step 7c — Security Risk confirmation.** GHL pops a "Security Risk" confirmation modal whenever sensitive scopes are part of the grant. The modal heading reads "Security Risk — Are you sure you want to proceed with creating the private integration token with sensitive scopes?" with Cancel and Confirm buttons. This is **expected** on every all-scopes mint, **not** an error — click the Confirm button:

```
mcp__playwright__browser_evaluate({ function: `() => {
  const buttons = Array.from(document.querySelectorAll('button')).filter(b => {
    const r = b.getBoundingClientRect();
    return r.width > 0 && r.height > 0;
  });
  const confirm = buttons.find(b => /^Confirm$/i.test((b.textContent || '').trim()));
  if (!confirm) return 'no-confirm';
  confirm.click();
  return 'clicked-confirm';
}` })
```

The success modal with the token follows. Continue to Step 8.

### Step 8: Capture the Private Integration Token

After the Security Risk confirmation, GHL displays the token once in a success modal. The modal heading reads "Your private integration was created. Claude Code is installed and ready to use." with the token shown as a paragraph and a single `Copy` button next to it.

The token shape is `pit-<UUIDv4>`: exactly 40 chars, lowercase hex, 5 hyphen-separated groups. Example: `pit-66f8ddf8-6a0c-48fa-88f2-6f4f61a64a7c`. The regex is:

```
^pit-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$
```

Read it via `browser_evaluate`. Iterate **leaf elements only** (`children.length === 0`) so the surrounding "Copy" button text doesn't concatenate with the token in a parent div's `textContent`:

```
() => {
  const pitRe = /^pit-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  const leafs = Array.from(document.querySelectorAll('*')).filter(el => el.children.length === 0);
  for (const el of leafs) {
    const v = (el.value || el.textContent || '').trim();
    if (pitRe.test(v)) return v;
  }
  return null;
}
```

**Fallback if DOM read returns `null`.** Click the `Copy` button visible in the modal, then read the clipboard via Bash:

```bash
pbpaste 2>/dev/null
```

(macOS) or `xclip -selection clipboard -o` (Linux) or `powershell -command "Get-Clipboard"` (Windows). Validate the captured string against the same regex.

If after two attempts no valid token is captured, stop and ask the user: *"I'm having trouble reading the connection key off the page. Could you tell me what you see in the dialog?"* Use their description to locate the right control.

**Never echo the token to the user. Never log it. Never write it anywhere except the MCP config.**

### Step 9: Save the connection

Register the MCP server via `claude mcp add` over Bash. GHL needs **two headers**: the bearer token and the locationId.

```bash
claude mcp add ghl https://services.leadconnectorhq.com/mcp/ \
  --transport http \
  --header "Authorization: Bearer <token captured in Step 8>" \
  --header "locationId: <locationId captured in Step 4>" \
  --scope user
```

Expected output: `Added HTTP MCP server ghl with URL: https://services.leadconnectorhq.com/mcp/ to user config`.

Verify the entry registered:

```bash
claude mcp list | grep '^ghl:'
```

Should report `ghl: https://services.leadconnectorhq.com/mcp/ (HTTP) - ✓ Connected`.

**Fallback if `claude mcp add` fails** (older Claude Code, missing CLI, header-flag issues). Write directly to `~/.claude.json` (Mac/Linux) or `%USERPROFILE%\.claude.json` (Windows), merging into the existing `mcpServers` object:

```json
{
  "mcpServers": {
    "ghl": {
      "type": "http",
      "url": "https://services.leadconnectorhq.com/mcp/",
      "headers": {
        "Authorization": "Bearer <token>",
        "locationId": "<locationId>"
      }
    }
  }
}
```

Read the existing file, merge the `ghl` key into `mcpServers` (never overwrite the whole object), write back. If the file is malformed, back up to `~/.claude.json.backup` first and write a fresh minimal file containing only the `mcpServers.ghl` entry plus any other top-level keys you parsed successfully.

### Step 10: Close the browser, verify, prompt restart if needed

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json` and is no longer in any tool-return string.

Tell the user: *"I've saved your connection. Let me check it works."*

Two paths from here:

- **`mcp__ghl__locations_get-location` is callable in this session.** Call it (no arguments needed — `locationId` is sourced from the header). The response includes `data.location.name` (the sub-account name). Capture the name and go to Step 11. **Note: in most cases this tool will NOT be visible immediately after install** because Claude Code reconciles new MCP servers on session start. The path below is the common one.
- **`mcp__ghl__*` tools are not yet visible in this session.** Tell the user, in one message:

  > "All saved. Please close and reopen Claude Code once so the connection becomes active, then say 'test my GoHighLevel' and I'll confirm it's working."

  Stop. The user will return and trigger Phase 0, which will run the smoke call and surface success.

**If you want to confirm the connection works without waiting for a restart**, do a direct HTTP smoke test (don't show this to the user — it's just a sanity check Claude can run silently). The Cloudflare front on `services.leadconnectorhq.com` **blocks** the default Python `urllib` user-agent (returns `Error 1010: browser_signature_banned`). Use `curl` with a browser-like User-Agent, **not** Python `urllib.request`:

```bash
curl -s -X POST https://services.leadconnectorhq.com/mcp/ \
  -H "Authorization: Bearer <token>" \
  -H "locationId: <locationId>" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -A "Mozilla/5.0" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"locations_get-location","arguments":{}}}'
```

A `200` with `"success": true` and a `data.location.name` confirms the headers, PIT, and locationId all work end-to-end. If you get `Error 1010`, you forgot the `-A "Mozilla/5.0"` flag.

If `mcp__ghl__locations_get-location` returns an error in-session:
- **401 / Unauthorized / Invalid token.** Tell the user *"That didn't take. Let me grab a fresh key."* and re-run from Step 5 (the existing PIT will be detected and revoked, a new one minted).
- **403 / Insufficient scope.** Re-run from Step 5 with a more careful Step 7b verify-counter pass.
- **Wrong-location-data response.** The locationId is wrong. Re-run from Step 4 to re-pick the sub-account.
- **Any other error.** Retry once. If it still fails, tell the user *"Something on GoHighLevel's side isn't responding. Could you try again in a minute?"* and stop.

### Step 11: Success message

Send one short message, using the sub-account name from the in-session verify (or from the post-restart Phase 0 verify):

> "All done. You're connected to your GoHighLevel account as **[sub-account name]**. You can now ask me things like 'show me my pipelines', 'tag jane@example.com as VIP', or 'what's on the calendar tomorrow'. Give it a try."

---

## PHASE 2: Use Tools

Once the connector is configured, call the `mcp__ghl__*` tools to answer questions and make changes in GoHighLevel. The HighLevel MCP server exposes **36 tools** across 10 resource areas (verified live 2026-05-18). Tool names use the shape `<resource>_<verb>-<sub>` with hyphens in the verb-resource part, and surface in Claude Code as `mcp__ghl__<resource>_<verb>-<sub>`.

### Available Tools

#### Contacts (8 tools)

| Tool | Purpose |
|---|---|
| `contacts_get-contact` | Fetch detailed contact info by contact ID |
| `contacts_get-contacts` | List contacts with pagination, filterable by location, query |
| `contacts_create-contact` | Create a new contact in the CRM |
| `contacts_update-contact` | Modify contact info (any property) |
| `contacts_upsert-contact` | Create or update based on duplicate detection (matches on email/phone) |
| `contacts_add-tags` | Add one or more tags to a contact |
| `contacts_remove-tags` | Remove one or more tags from a contact |
| `contacts_get-all-tasks` | Retrieve all tasks for a contact |

**Use when.** The user asks to find a person, create or update a lead, or look up assigned tasks.

**Example.**

```
User: "Find jane@example.com and tag her as VIP"
→ mcp__ghl__contacts_upsert-contact  (matches Jane by email, returns contactId)
→ mcp__ghl__contacts_add-tags         (contactId, tags: ["VIP"])
→ "Found Jane Doe and tagged her as VIP."
```

#### Conversations (3 tools)

| Tool | Purpose |
|---|---|
| `conversations_search-conversation` | Find conversations by contact, assigned user, follower, etc. |
| `conversations_get-messages` | Fetch message history for a conversation |
| `conversations_send-a-new-message` | Send a new message (SMS / Email / WhatsApp / GMB / Live Chat / IG) |

**Use when.** Reading conversation history or sending a reply. The send tool is **immediate**: there is no MCP-side draft-before-send. Confirm body, channel, and recipient with the user before calling. If the user wants a UI-driven draft, fall back to Playwright (see Playwright Fallback section).

#### Opportunities & Pipelines (4 tools)

| Tool | Purpose |
|---|---|
| `opportunities_get-pipelines` | List sales pipelines and stages for the location |
| `opportunities_search-opportunity` | Search opportunities by pipeline, stage, status, contact |
| `opportunities_get-opportunity` | Fetch a single opportunity by ID |
| `opportunities_update-opportunity` | Move stages, change status (won/lost), patch fields |

**Use when.** Looking at the sales pipeline, moving deals, marking won or lost, or searching by customer.

**Example.**

```
User: "Move the Acme Co deal to Proposal Sent"
→ mcp__ghl__opportunities_get-pipelines     (find Proposal Sent stageId)
→ mcp__ghl__opportunities_search-opportunity (find Acme Co opportunityId)
→ Confirm source stage and target stage with the user
→ mcp__ghl__opportunities_update-opportunity (opportunityId, pipelineStageId)
```

#### Calendars (2 tools — read-only)

| Tool | Purpose |
|---|---|
| `calendars_get-calendar-events` | List bookings in a time range |
| `calendars_get-appointment-notes` | Read notes attached to an appointment |

**Use when.** "What's on the calendar tomorrow?", "Did anyone leave notes on the 3 PM discovery call?".

**Calendar CRUD is NOT in the public MCP surface.** Creating, updating, deleting, or blocking calendar slots requires the Playwright fallback (see below).

#### Locations & Custom Fields (2 tools)

| Tool | Purpose |
|---|---|
| `locations_get-location` | Fetch details of the connected sub-account (name, timezone, etc.) |
| `locations_get-custom-fields` | List custom fields for the location, filterable by model type |

**Use when.** Confirming which sub-account is connected (run at the start of a session), or discovering field IDs before an update.

#### Payments (2 tools — read-only)

| Tool | Purpose |
|---|---|
| `payments_get-order-by-id` | Fetch a single order by ID |
| `payments_list-transactions` | List transactions with filtering options |

**Use when.** "What did Jane pay last month?", "Show me the order for this contact." Payment mutations (refunds, invoice writes, subscription edits) are not in the MCP surface — fall back to Playwright or the GHL UI.

#### Blogs (7 tools)

| Tool | Purpose |
|---|---|
| `blogs_get-blogs` | List blog sites for the location |
| `blogs_get-blog-post` | List posts inside a blog with filtering and pagination |
| `blogs_create-blog-post` | Create a new blog post |
| `blogs_update-blog-post` | Edit content, metadata, categories, tags, publication |
| `blogs_get-all-blog-authors-by-location` | List blog authors |
| `blogs_get-all-categories-by-location` | List blog categories |
| `blogs_check-url-slug-exists` | Validate a URL slug before publishing |

**Use when.** Drafting, publishing, or editing blog content inside GHL.

#### Email Templates (2 tools)

| Tool | Purpose |
|---|---|
| `emails_fetch-template` | List email templates with filtering |
| `emails_create-template` | Create a new email template (HTML, builder, blank, folder, etc.) |

**Use when.** Authoring a template. Sending a one-off email uses `conversations_send-a-new-message`, not these tools. Full visual-builder campaign authoring is not in the MCP surface — fall back to Playwright.

#### Social Media Posting (6 tools)

| Tool | Purpose |
|---|---|
| `social-media-posting_get-account` | List connected social accounts and groups |
| `social-media-posting_get-post` | Fetch one post by ID |
| `social-media-posting_get-posts` | List posts with filtering and pagination |
| `social-media-posting_create-post` | Create a post for multiple platforms (FB, IG, etc.) |
| `social-media-posting_edit-post` | Modify an existing post |
| `social-media-posting_get-social-media-statistics` | Retrieve analytics for connected accounts |

**Use when.** Scheduling content across the user's connected social channels.

### Resource areas NOT in the MCP surface

The HighLevel MCP server (as of 2026-05-18) does **not** expose:
- Invoices (CRUD, schedules, templates, record-payment, void, send, text2pay)
- Estimates
- Subscriptions
- Products, collections, prices
- Shipping zones / rates
- Coupons
- Custom objects (schemas + records)
- Associations / relations
- Media library (search / upload / delete)
- Surveys
- Workflows, campaigns (read or membership)
- Bulk operations (bulk-update-contacts, bulk-delete-social-media-posts)
- Verification (`verify_email`)
- Payment config (late-fee, store-settings, payment-integrations, custom-payment-providers)
- Calendar CRUD (create / update / delete / blocked-slot)
- SMS-specific outbound tools (use `conversations_send-a-new-message` with channel=SMS)
- Documents & contracts
- Voice AI, knowledge bases, conversation AI configuration
- Brand boards, chat widget config
- Phone numbers, Twilio account
- Users (list, create, update)

For any of these, fall back to the GHL UI via the Playwright fallback section below, or tell the user the MCP doesn't cover that surface yet.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my GHL" / "Set up my GoHighLevel" | **Run Phase 0, then Phase 1 if not configured** |
| "Reconnect my GHL" / "Reset my GoHighLevel connection" | **Force Phase 1** (skip Phase 0's short-circuit) |
| "What GHL account am I on?" | `locations_get-location` |
| "Find jane@example.com" | `contacts_get-contacts` (with query) or `contacts_upsert-contact` |
| "Add a new contact" | `contacts_create-contact` (or `contacts_upsert-contact` for idempotency) |
| "Update Jane's phone number" | `contacts_update-contact` |
| "Tag this contact as VIP" | `contacts_add-tags` |
| "Remove the VIP tag" | `contacts_remove-tags` |
| "What are Jane's tasks?" | `contacts_get-all-tasks` |
| "What are my pipelines?" | `opportunities_get-pipelines` |
| "List opportunities in 'Proposal Sent'" | `opportunities_search-opportunity` (filter by stage) |
| "Move Acme Co to 'Won'" | `opportunities_get-pipelines` → `opportunities_search-opportunity` → `opportunities_update-opportunity` |
| "Show me opportunity 12345" | `opportunities_get-opportunity` |
| "What's on the calendar tomorrow?" | `calendars_get-calendar-events` |
| "Read the notes on appointment X" | `calendars_get-appointment-notes` |
| "Show me recent conversations with Jane" | `conversations_search-conversation` → `conversations_get-messages` |
| "Send Jane a follow-up email" | `conversations_send-a-new-message` (type: Email) — **confirm body and recipient first** |
| "What custom fields do I have?" | `locations_get-custom-fields` |
| "Show me Jane's order" | `payments_get-order-by-id` |
| "List transactions last month" | `payments_list-transactions` |
| "List my blogs" | `blogs_get-blogs` |
| "Draft a blog post titled …" | `blogs_create-blog-post` |
| "Update the URL on blog post X" | `blogs_update-blog-post` |
| "List email templates" | `emails_fetch-template` |
| "Create an email template called X" | `emails_create-template` |
| "Schedule a LinkedIn post for Thursday" | `social-media-posting_create-post` |
| "Show me last month's social stats" | `social-media-posting_get-social-media-statistics` |

---

## Playwright Fallback (UI-only surfaces)

Use [playwright-skill](../playwright-skill/SKILL.md) **only** for operations the MCP does not cover (see "Resource areas NOT in the MCP surface" above). Common ones:

| Task | Why MCP doesn't cover it | Playwright approach |
|---|---|---|
| **Draft-before-send for SMS or Email** | `conversations_send-a-new-message` sends immediately | Open the conversation, type the draft, hand control back to the user to click Send |
| **Create / cancel a calendar booking** | Calendar CRUD not in MCP | Open the calendar, click the slot, fill the form, hand to user to confirm |
| **Edit the visual workflow builder** | Not in the API | Open the workflow, let the user edit live |
| **Full email campaign authoring** (builder UI) | MCP has template creation but not the visual builder | Open the campaign builder and hand control back |
| **Invoice / estimate / subscription / product management** | Not in MCP | Open the relevant settings page, hand control back |
| **Bulk operations** | Not in MCP | Use the UI bulk actions, do not auto-confirm |

**Rules for Playwright fallback.**
- Reuse the saved storage state at `~/.claude/state/ghl-storage.json`. If missing or expired (you land on the login page), run a one-time login script first.
- Write every Playwright script to `/tmp/ghl-*.js`, never inside the skill dir.
- Launch `headless: false` so the user can see and take over what's happening.
- **Never auto-click Send, Delete, or Cancel.** Draft the state and hand the browser to the user.
- If a selector fails, **stop and ask.** GHL's UI changes often. Don't retry destructive clicks.

---

## Error Handling

When a GHL MCP tool call fails, diagnose and respond in plain English. Never show raw JSON errors or the PIT.

| Error | What to say | How to fix |
|---|---|---|
| 401 / "Unauthorized" | "Your GoHighLevel connection isn't valid anymore. Let me reconnect." | Run Phase 1 from Step 5. The revoke-and-remint logic handles the stale PIT |
| 403 / "Insufficient scope" | "Your connection is missing a permission for this action." | Run Phase 1 from Step 5 (the all-scopes mint fixes it) |
| 404 on a contactId / opportunityId | "I couldn't find that record in your sub-account." | Try `contacts_get-contacts` or `opportunities_search-opportunity` with the user's hint |
| "Wrong location" / data from another sub-account | "Your settings point to a different sub-account." | Run Phase 1 from Step 4 to re-pick the sub-account |
| 429 / rate limit | "GoHighLevel is asking me to slow down. I'll wait a moment." | Wait 5s, retry once. On a mutating call, re-confirm with the user before retry |
| MCP server unreachable | "I can't reach GoHighLevel right now." | Check `curl -I https://services.leadconnectorhq.com/mcp/`, retry in a minute |
| MCP tools not visible after install | "Please restart Claude Code so the connection becomes active." | User restarts, Phase 0 will smoke-test on return |
| "Security Risk" modal in Phase 1 Step 7c | This is expected — click Confirm to proceed | Not an error |

---

## Scope Limitations

The GHL connector **can** (via MCP, 36 tools):
- Read and create / update contacts (`contacts_*`); upsert; tag / untag; read tasks per contact
- Read and update opportunities; read pipelines (`opportunities_*`)
- Read calendar events and appointment notes (`calendars_*`)
- Send messages (SMS / Email / WhatsApp / GMB / Live Chat / IG) via `conversations_send-a-new-message`; search conversations; read messages
- Read transactions and orders (`payments_*`)
- Manage blog posts (CRUD) (`blogs_*`)
- List / create email templates (`emails_*`)
- Manage social media posts (CRUD) and read analytics (`social-media-posting_*`)
- Read the connected location and custom fields (`locations_*`)

The GHL connector **cannot** (needs Playwright fallback, or isn't exposed at all):
- Draft an SMS or email for user review before sending (send is immediate via MCP)
- Create / update / delete calendar events; block calendar slots
- Edit the visual workflow builder
- Author full email campaigns in the campaign builder
- Manage invoices, estimates, subscriptions, products, shipping, coupons
- Manage custom objects, surveys, workflows, campaigns membership
- Bulk operations
- Manage agency-wide settings (this skill operates at sub-account scope by default)
- Manage multiple sub-accounts simultaneously (one `locationId` per `~/.claude.json` entry)
- Manage users, phone numbers, Twilio config, brand boards, chat widget, voice AI

---

## Behaviour Guidelines

- **Verify connection first.** At the start of a session that touches GHL, call `locations_get-location` to confirm which sub-account is connected. Report the name back to the user before mutating anything.
- **Confirm before mutating.** Always confirm with the user before creating or updating contacts, moving opportunities, sending messages, or publishing blog or social posts. Echo the contact's name, opportunity title, or post body back before the tool call.
- **Default to sub-account scope.** Never attempt agency-wide changes without explicit user confirmation.
- **Send is immediate in MCP.** `conversations_send-a-new-message` goes out the moment it's called. If the user wants to "draft" or "review first", use the Playwright fallback, not the MCP send.
- **Never auto-click Send, Delete, or Cancel in the browser.** Playwright drafts the state; the user clicks.
- **One step at a time.** Don't dump all results at once. Summarise counts first ("You have 12 opportunities in 'Proposal Sent'"), then offer to show details.
- **Mask PII when echoing.** When summarising contacts back in the transcript, partially mask phone numbers (`+61 400 *** 000`) and emails (`j***@example.com`) unless the user explicitly asks for the full value.
- **Token hygiene.** Never echo `Authorization` or the PIT to the transcript. Never write them to a file inside the project. Never include them in a commit. The PIT lives in `~/.claude.json` only.
- **Selector failure in Playwright.** Stop and ask the user. Never blind-retry a destructive click.
- **Wrong-location errors.** Stop, report the locationId to the user, and ask them to confirm before you re-run Phase 1.

---

## Related Skills

- **playwright-skill.** Required fallback engine for UI-only surfaces (draft-before-send, calendar CRUD, workflow builder, full email campaign builder, invoices, products)
- **monday-connector.** Sibling Pattern-2 connector with the same autonomous Playwright-driven Phase 1 shape
- **xero-connector.** Same MCP pattern for accounting
- **connector-recommender.** Recommending which connectors to set up
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended). Troubleshooting PIT scope or MCP connection errors
- **email-composer.** Drafting campaign copy before pushing it into a GHL email template
- **n8n-workflow-patterns.** Building GHL-triggered automations
