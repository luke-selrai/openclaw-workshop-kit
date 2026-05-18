---
name: ghl-connector
description: "Connect and operate GoHighLevel (GHL) via the official HighLevel MCP server (services.leadconnectorhq.com/mcp/). Use this skill when the user asks to set up GHL, connect their CRM, or interact with contacts, conversations, opportunities, pipelines, calendar, payments, blogs, email templates, or social posts. On first use, run Phase 1: Claude drives the browser end-to-end via Playwright, mints the Private Integration Token autonomously, ticks every available scope, and saves the connection. The user only signs in to GHL, picks a sub-account if they have several, and restarts Claude Code once at the end."
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
      reason: Used only as a fallback for UI-only surfaces the official MCP server doesn't cover (visual workflow editor, full email campaign builder)
    - skill: monday-connector
      reason: Sibling Pattern-2 connector with the same Playwright-driven Phase 1 shape
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
---

# GoHighLevel (GHL) Connector

> **Install pattern:** Hosted-bearer-PAT. See [skills/CLAUDE.md](../CLAUDE.md) for the cross-pattern overview.

## Overview

This skill reads and writes data in the user's GoHighLevel sub-account using the **official HighLevel MCP server** at `https://services.leadconnectorhq.com/mcp/`. It has two phases:

- **Phase 1: Install & Auth.** Autonomous. Claude opens GHL in a Playwright-driven browser, waits for the user to sign in, identifies the right sub-account, navigates to Settings → Private Integrations, revokes any prior "Claude Code" integration, creates a fresh Private Integration Token (PIT) with every available scope ticked, reads the token from the post-create modal, writes the MCP config with both required headers (`Authorization` and `locationId`), and verifies. The user's only manual actions are: sign in once, pick a sub-account if they have several, and restart Claude Code once at the end.
- **Phase 2: Use Tools.** Once the connector is configured, call the `mcp__ghl__*` native tools (about 207 tools across Contacts, Conversations, Opportunities, Calendar, Payments, Blogs, Email Templates, Social Media, Invoices, Estimates, Subscriptions, Orders, Products, Custom Objects, Workflows, and Bulk Operations).

**Which phase to run.** Before any tool call, run the Phase 0 resume check below. If GHL is already configured and the token still works, skip straight to Phase 2.

### What this skill does NOT use

- **Curl recipes, shell envvars, manual JSON editing.** All install paths go through `claude mcp add` (with a direct JSON-write fallback only if the CLI fails).
- **Agency-level API keys.** PITs are minted on a single sub-account. If the user wants agency-wide access, that is a separate workflow they can request later.
- **OAuth.** GHL Private Integrations are long-lived bearer tokens minted from a settings page. No OAuth dance.
- **Reading the PIT back from GHL after creation.** GHL shows the PIT once. If we lose it, the only path is to revoke and mint a new one (which is exactly what Phase 1 does on re-run).

---

## Phase 0: Resume check

Before any other action, decide whether to run Phase 1 or skip to Phase 2.

Read `~/.claude.json` (Windows: `%USERPROFILE%\.claude.json`) and look for `mcpServers.ghl`. Three branches:

1. **Entry exists, has both `headers.Authorization` (non-placeholder) and `headers.locationId` (non-placeholder).** Run a single smoke call: `mcp__ghl__get_location`.
   - **Returns the sub-account.** Tell the user they're already connected, surface the sub-account name, skip to Phase 2.
   - **Returns 401 / Unauthorized / Invalid token.** Token is dead. Run Phase 1 (the revoke-and-remint logic handles the stale GHL-side PIT).
   - **Returns 403 / Insufficient scope.** Tell the user a previous install minted the PIT with too few scopes, then run Phase 1 (the all-scopes mint will fix it).
   - **MCP tools not yet visible in this session.** The entry exists on disk but Claude Code hasn't reconciled. Tell the user to restart Claude Code and re-ask, then stop.
2. **Entry exists but `Authorization` or `locationId` is a placeholder string** (e.g. `"Bearer <PIT>"`, `"<sub-account-id>"`). Treat as not configured. Run Phase 1.
3. **No entry.** Run Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous. Claude does the work; the user signs in, picks a sub-account if asked, restarts Claude Code at the end. Every message during Phase 1 follows these rules:

- **Claude drives, not the user.** Never ask the user to click menus, copy text, or paste values. The only actions ever requested are sign-in, sub-account name (if applicable), and the final restart.
- **Plain English only.** Banned words in user-facing messages: `npm`, `npx`, `bash`, `CLI`, `API`, `terminal`, `config file`, `OAuth`, `scope`, `token`, `tenant`, `MCP`, `endpoint`, `JSON`, `GraphQL`, `Playwright`, `browser automation`, `environment variable`, `Private Integration`, `PIT`, `locationId`, `Bearer`, `header`. The browser window is "a browser window I just opened for you" or "the GoHighLevel page". The Private Integration Token is "the connection key". The MCP config is "your settings".
- **Narrate at action boundaries, not inside tool sequences.** One message when starting ("I'm opening GoHighLevel now"), one when needing the user ("please sign in"), one when needing a choice ("which sub-account"), one when done ("you're connected"). No commentary in between.
- **React warmly to success and failure.** Good: "That worked. Your GoHighLevel is now connected." Bad: "200 OK from get_location."
- **Never show error messages.** Translate. If something fails, say "No problem, let me try a different way," and diagnose silently.
- **Short responses.** Maximum 8 lines per user-facing message during Phase 1.
- **Never reveal file paths, commands, scripts, snapshot details, or selectors.**

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

- **Logged-in shell visible** (left sidebar with Conversations / Contacts / Opportunities, or an agency-view sub-account picker). Continue to Step 4.
- **Not logged in** (sign-in form, marketing landing, or "Get Started" CTA). Send one message: *"The browser is open. Please sign in to GoHighLevel when you're ready."* Then poll silently with `browser_wait_for` against a post-login shell signal (text like "Sub-Accounts", "Conversations", "Dashboard", or an avatar/profile control). Use a generous timeout (5+ minutes) to absorb 2FA, SSO, password resets. Do not ask the user to confirm they're done. Detect from the snapshot yourself.

If the wait times out, check in once: *"Still on the sign-in page? Anything I can help with?"*

If after sign-in the page still looks like a marketing landing, navigate explicitly to `https://app.gohighlevel.com/v2/` and re-snapshot.

### Step 4: Land the user on a sub-account and capture the locationId

GHL's sub-account URL shape is `https://app.gohighlevel.com/v2/location/<locationId>/...`. The locationId is the ground truth: capture it from `window.location.href`.

Call:

```
mcp__playwright__browser_evaluate({ function: "() => window.location.href" })
```

Three branches based on the URL and snapshot:

- **URL already contains `/v2/location/<id>/`.** The user is inside a sub-account. Extract the locationId via regex (`/location/([A-Za-z0-9]+)/`). Save it. Continue to Step 5.
- **URL is an agency-level path** (e.g. `/v2/agency-dashboard/`, `/v2/agency/`), and the snapshot shows a sub-account list or switcher. The user has not picked a sub-account yet. Send one short message:

  > "I can see your GoHighLevel. Which sub-account would you like me to connect to?"

  Wait for the user's answer. Once they name one, find that name in the sub-account list (snapshot, then click the matching row). Wait for the URL to change to `/v2/location/<id>/...` using `browser_wait_for` against the new URL pattern, then capture the locationId. If the name doesn't match exactly, fuzzy-match (case-insensitive, ignore extra spaces). If you can't find it, ask the user to clarify with a unique distinguishing word.
- **URL is agency-level and the snapshot shows only one sub-account** (single-sub-account agency, or freelancer). Click that sub-account, wait for URL update, capture locationId.

If at any point the locationId regex returns nothing valid (must be at least 16 alphanumeric chars), re-snapshot and re-read `window.location.href` after a brief `browser_wait_for`.

### Step 5: Navigate to Private Integrations

Navigate directly:

```
mcp__playwright__browser_navigate({ url: "https://app.gohighlevel.com/v2/location/<locationId>/settings/private-integrations" })
```

Snapshot. If the page loads with a "Private Integrations" heading and a table or empty-state, continue to Step 6.

If the page 404s or redirects (GHL has shipped the route at slightly different paths over time), try these fallbacks in order:
- `/v2/location/<locationId>/settings/integrations`
- `/v2/location/<locationId>/settings/business-info` then click the "Private Integrations" link if visible in the settings sidebar
- Snapshot the settings sidebar and click whichever entry is named "Private Integrations" or contains the phrase

### Step 6: Revoke any existing "Claude Code" integration

Snapshot the integrations list. Look for a row whose name is "Claude Code" (case-insensitive, exact match).

- **Found.** Click the row's overflow menu (typically a three-dots icon or a "Delete" action visible on hover), then click Delete or Revoke. A confirmation dialog will appear. Click the destructive-confirm button (text varies: "Delete", "Revoke", "Confirm", "Yes, delete"). Re-snapshot, verify the row is gone before continuing.
- **Not found.** Continue to Step 7.

If the deletion fails or the row reappears after re-snapshot, retry once. If still failing, stop and tell the user: *"There's an old Claude Code connection that I can't remove. Could you delete it manually and let me know when it's done?"* Wait for them, then re-snapshot.

### Step 7: Create a fresh Private Integration with every scope

Click the "Create New Integration" button (label varies: "Create", "New Integration", "Add Integration", "+"). A creation form or modal opens.

Fill the form:

- **Name field.** Type `Claude Code`.
- **Scopes / permissions selector.** This is the load-bearing step. GHL presents scopes as a multi-select dropdown or a list of checkboxes covering Contacts (View/Edit), Conversations (View/Edit), Opportunities (View/Edit), Calendars (View/Edit), Workflows (View), Locations (View), Custom Fields (View/Edit), Forms, Surveys, Payments, Invoices, Estimates, Products, Blogs (View/Edit), Social Media (View/Edit), Email Templates (View/Edit), Campaigns (View/Edit), and more.

  **Tick every available scope.** Workshop attendees expect the full 207-tool surface to be usable, and any half-ticked PIT will silently 403 mid-demo. Three sub-strategies, in order of preference:

  1. If the UI offers a "Select All" toggle or master checkbox, click it once. Re-snapshot to verify all rows show as ticked.
  2. If the UI is a multi-select dropdown, click to open it, then iterate every option by clicking it. Re-snapshot between batches of ~10 clicks to catch any virtual-scrolling that hides options below the fold.
  3. If the UI is a flat checkbox grid, walk each checkbox and click it if not already ticked. Snapshot every 5-10 clicks to verify state.

  After ticking, snapshot one more time. Count the number of ticked rows and the number of total rows. If they don't match, identify the unticked rows from the snapshot and click them individually.

- **Other fields.** If GHL prompts for a description, leave it blank or type `Claude Code workshop install`. If it asks for a webhook URL, leave it blank.

Click the final "Create" button.

### Step 8: Capture the Private Integration Token

After creation, GHL displays the token once in a modal or banner with a Copy button. The token shape is one of:
- `pit-<UUID>-<segments>` (newer accounts, ~80+ chars total)
- A JWT-style three-segment base64url string (older accounts, ~200+ chars)

Snapshot. Read the token via `browser_evaluate`. Use a targeted selector pass and fall back to a regex sweep of the modal text:

```
() => {
  const candidates = Array.from(document.querySelectorAll('input, textarea, code, span, div'));
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (/^pit-[A-Za-z0-9-]{30,}$/.test(v)) return v;
    if (/^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(v)) return v;
  }
  return null;
}
```

If that returns `null`, click the Copy button visible in the modal, then read the clipboard via Bash:

```bash
pbpaste 2>/dev/null
```

(macOS) or `xclip -selection clipboard -o` (Linux) or `powershell -command "Get-Clipboard"` (Windows). Validate the captured string with the same two regex patterns.

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

- **`mcp__ghl__get_location` is callable in this session.** Call it. If it returns a sub-account object with a name, capture the name and go to Step 11 with the name in hand.
- **`mcp__ghl__*` tools are not yet visible in this session.** Claude Code has not reconciled the new server. Tell the user, in one message:

  > "All saved. Please close and reopen Claude Code once so the connection becomes active, then say 'test my GoHighLevel' and I'll confirm it's working."

  Stop. The user will return and trigger Phase 0, which will run the smoke call and surface success.

If `get_location` returns an error in-session:
- **401 / Unauthorized / Invalid token.** Tell the user *"That didn't take. Let me grab a fresh key."* and re-run from Step 5 (the existing PIT will be detected and revoked, a new one minted).
- **403 / Insufficient scope.** Re-run from Step 5 with a more careful Step 7 tick-pass (some scopes were missed).
- **Wrong-location-data response.** The locationId is wrong. Re-run from Step 4 to re-pick the sub-account.
- **Any other error.** Retry once. If it still fails, tell the user *"Something on GoHighLevel's side isn't responding. Could you try again in a minute?"* and stop.

### Step 11: Success message

Send one short message, using the sub-account name if you got it from the in-session verify:

> "All done. You're connected to your GoHighLevel account as **[sub-account name]**. You can now ask me things like 'show me my pipelines', 'tag jane@example.com as VIP', or 'what's on the calendar tomorrow'. Give it a try."

If the user had to restart, the equivalent message is sent after the post-restart smoke call succeeds in Phase 0.

---

## PHASE 2: Use Tools

Once the connector is configured, call the `mcp__ghl__*` tools to answer questions and make changes in GoHighLevel. The HighLevel MCP server exposes about **207 tools** across 20+ resource areas (verified live 2026-05-07).

### Available Tools

Tool names surface as `mcp__ghl__ghl_*` at runtime. The nine areas below cover the most common workshop operations. For everything else, see **Additional resource areas** at the end of this section.

#### Contacts (6 tools)

| Tool | Purpose |
|---|---|
| `get_contact` | Fetch a single contact by ID |
| `get_contacts` | List contacts in the sub-account with pagination |
| `create_contact` | Create a new contact |
| `update_contact` | Patch an existing contact |
| `upsert_contact` | Create or update in one call (matches on email/phone) |
| `get_all_tasks` | List tasks across contacts |

**Use when.** The user asks to find a person, create or update a lead, or look up assigned tasks.

**Example.**

```
User: "Find jane@example.com and tag her as VIP"
→ mcp__ghl__upsert_contact  (matches Jane by email, returns contactId)
→ mcp__ghl__add_tags         (contactId, tags: ["VIP"])
→ "Found Jane Doe and tagged her as VIP."
```

#### Contacts Management (2 tools)

| Tool | Purpose |
|---|---|
| `add_tags` | Add one or more tags to a contact |
| `remove_tags` | Remove one or more tags from a contact |

**Use when.** Segmenting, opting in or out of lists, or applying workflow entry tags.

#### Conversations (3 tools)

| Tool | Purpose |
|---|---|
| `search_conversations` | Find conversations by contact, channel, or query |
| `get_messages` | Fetch the message history for a conversation |
| `send_message` | Send a new message (SMS / Email / GMB / etc.) into a conversation |

**Use when.** Reading conversation history or sending a reply. For outbound SMS, use `mcp__ghl__ghl_send_sms` (requires `confirmAction: true`, so confirm the body and recipient with the user before passing the flag). For outbound email, use `mcp__ghl__ghl_send_email_message` (same `confirmAction: true` gate). Only fall back to Playwright if the user wants a UI-driven draft they can edit before sending.

#### Opportunities & Pipelines (4 tools)

| Tool | Purpose |
|---|---|
| `get_pipelines` | List pipelines and their stages for the sub-account |
| `search_opportunities` | Find opportunities by pipeline, stage, status, or contact |
| `get_opportunity` | Fetch a single opportunity with full detail |
| `update_opportunity` | Move stages, change status (won / lost), or patch fields |

**Use when.** Looking at the sales pipeline, moving deals, marking won or lost, or searching by customer.

**Example.**

```
User: "Move the Acme Co deal to Proposal Sent"
→ mcp__ghl__get_pipelines           (find Proposal Sent stageId)
→ mcp__ghl__search_opportunities    (find Acme Co opportunityId)
→ Confirm source stage and target stage with the user
→ mcp__ghl__update_opportunity      (opportunityId, pipelineStageId)
```

#### Calendar (2 tools, plus CRUD)

| Tool | Purpose |
|---|---|
| `get_calendar_events` | List bookings for a calendar in a time range |
| `get_appointment_notes` | Read notes attached to an appointment |

**Use when.** "What's on the calendar tomorrow?", "Did anyone leave notes on the 3 PM discovery call?".

**Booking CRUD is in the MCP surface.** Use `mcp__ghl__ghl_create_appointment`, `mcp__ghl__ghl_update_appointment`, and `mcp__ghl__ghl_delete_appointment` (the delete tool requires `confirmAction: true`). For blocking time without booking a contact, use `mcp__ghl__ghl_create_blocked_slot`. Only fall back to Playwright if the user wants UI-driven calendar manipulation.

#### Payments (2 tools)

| Tool | Purpose |
|---|---|
| `list_transactions` | List payments and transactions for the sub-account |
| `get_order` | Fetch a single order by ID |

**Use when.** "What did Jane pay last month?", "Show me the order for this contact."

#### Locations & Fields (2 tools)

| Tool | Purpose |
|---|---|
| `get_location` | Fetch details of the connected sub-account (name, timezone, etc.) |
| `get_custom_fields` | List custom fields defined for contacts or opportunities |

**Use when.** Confirming which sub-account is connected (run at the start of a session), or discovering field IDs before an update.

#### Blogs (7 tools)

| Tool | Purpose |
|---|---|
| `get_blogs_by_location` | List all blogs for the sub-account |
| `get_blog_posts_by_blog_id` | List posts inside a blog |
| `create_blog_post` | Create a new blog post |
| `update_blog_post` | Edit an existing blog post |
| `get_blog_authors` | List available authors |
| `get_blog_categories` | List blog categories |
| `check_blog_url_slug` | Validate a URL slug before publishing |

**Use when.** Drafting, publishing, or editing blog content inside GHL.

#### Email Templates (2 tools)

| Tool | Purpose |
|---|---|
| `get_email_templates` | List available email templates |
| `create_email_template` | Create a new email template |

**Use when.** Authoring a template for campaigns. Sending a one-off email uses `send_message` under Conversations, not these tools.

#### Social Media (6 tools)

| Tool | Purpose |
|---|---|
| `get_social_media_accounts` | List connected social accounts |
| `get_social_media_statistics` | Pull reach and engagement stats |
| `create_social_media_post` | Schedule or publish a post |
| `update_social_media_post` | Edit an existing post |
| `get_social_media_post` | Fetch one post |
| `get_social_media_posts` | List posts with filtering |

**Use when.** Scheduling content across the user's connected social channels.

### Additional resource areas

The MCP also exposes full or partial coverage for: **invoices** (CRUD + schedules + templates + record-payment + void + send + text2pay), **estimates** (CRUD + templates + send), **subscriptions** (read + list), **transactions** (read + list), **orders + fulfillments** (read + create), **products + collections** (CRUD), **shipping zones + rates** (CRUD), **coupons** (CRUD), **custom objects** (schemas + records, CRUD), **associations + relations** (CRUD), **media library** (search + upload + delete), **surveys** (read + submissions), **workflows + campaigns** (read + add/remove contact), **bulk operations** (bulk-update-contacts, bulk-delete-social-media-posts), **verification** (`verify_email`), and **payment config** (late-fee, store-settings, payment-integrations, custom-payment-providers).

Tab-complete `mcp__ghl__ghl_<verb>_<resource>` to discover the right tool name. Common patterns: `get_*` / `get_*s` for read, `create_*` for create, `update_*` for patch, `delete_*` (with `confirmAction: true`) for destructive ops, `search_*` for filtered list, `send_*` (with `confirmAction: true`) for outbound messaging, `upsert_*` for create-or-update.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my GHL" / "Set up my GoHighLevel" | **Run Phase 0, then Phase 1 if not configured** |
| "Reconnect my GHL" / "Reset my GoHighLevel connection" | **Force Phase 1** (skip Phase 0's short-circuit) |
| "What GHL account am I on?" | `get_location` |
| "Find jane@example.com" | `get_contacts` or `upsert_contact` |
| "Add a new contact" | `create_contact` (or `upsert_contact` if you want idempotency) |
| "Tag this contact as VIP" | `add_tags` |
| "What are my pipelines?" | `get_pipelines` |
| "List opportunities in 'Proposal Sent'" | `search_opportunities` (filter by stage) |
| "Move Acme Co to 'Won'" | `get_pipelines` → `search_opportunities` → `update_opportunity` |
| "What's on the calendar tomorrow?" | `get_calendar_events` |
| "Show me recent conversations with Jane" | `search_conversations` → `get_messages` |
| "Send Jane a follow-up email" | `send_message` (type: Email) |
| "How much has Jane paid?" | `list_transactions` filtered by contact |
| "Draft a blog post titled …" | `create_blog_post` |
| "Schedule a LinkedIn post for Thursday" | `create_social_media_post` |

---

## Playwright Fallback (UI-only surfaces)

Use [playwright-skill](../playwright-skill/SKILL.md) **only** for the narrow set of operations the MCP does not cover:

| Task | Why MCP doesn't cover it | Playwright approach |
|---|---|---|
| **Edit the visual workflow builder** | Not in the API | Open the workflow, let the user edit live |
| **Full email campaign authoring** (builder UI) | MCP has `create_email_template` and `create_email_campaign` for header-level campaign creation but not the full visual builder | Open the campaign builder and hand control back |

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
| 404 on a contactId / opportunityId | "I couldn't find that record in your sub-account." | Try `get_contacts` or `search_opportunities` with the user's hint |
| "Wrong location" / data from another sub-account | "Your settings point to a different sub-account." | Run Phase 1 from Step 4 to re-pick the sub-account |
| 429 / rate limit | "GoHighLevel is asking me to slow down. I'll wait a moment." | Wait 5s, retry once. On a mutating call, re-confirm with the user before retry |
| MCP server unreachable | "I can't reach GoHighLevel right now." | Check `curl -I https://services.leadconnectorhq.com/mcp/`, retry in a minute |
| MCP tools not visible after install | "Please restart Claude Code so the connection becomes active." | User restarts, Phase 0 will smoke-test on return |

---

## Scope Limitations

The GHL connector **can** (via MCP):
- Read and create / update contacts (`get_contacts`, `create_contact`, `update_contact`, `upsert_contact`, `get_contact`)
- Tag and untag contacts (`add_tags`, `remove_tags`)
- Read contact tasks (`get_all_tasks`)
- Read and update opportunities; read pipelines (`get_pipelines`, `search_opportunities`, `get_opportunity`, `update_opportunity`)
- Read calendar events and appointment notes; create / update / delete appointments; create blocked slots
- Send messages (SMS / Email / etc.) via `send_message`, search conversations, read messages
- Read transactions and orders
- Manage blog posts (CRUD) and social media posts (CRUD)
- Create / list email templates
- Read the connected location and custom fields
- Read and operate invoices, estimates, subscriptions, products, custom objects, surveys, workflow membership

The GHL connector **cannot** (needs Playwright fallback, or isn't exposed at all):
- Edit the visual workflow builder
- Author full email campaigns in the campaign builder
- Manage agency-wide settings (this skill operates at sub-account scope by default)
- Manage multiple sub-accounts simultaneously (one `locationId` per `~/.claude.json` entry)

---

## Behaviour Guidelines

- **Verify connection first.** At the start of a session that touches GHL, call `get_location` to confirm which sub-account is connected. Report the name back to the user before mutating anything.
- **Confirm before mutating.** Always confirm with the user before creating or updating contacts, moving opportunities, sending messages, or publishing blog or social posts. Echo the contact's name, opportunity title, or post body back before the tool call.
- **Default to sub-account scope.** Never attempt agency-wide changes without explicit user confirmation.
- **Send is immediate in MCP.** `send_message` goes out the moment it's called. If the user wants to "draft" or "review first", use the Playwright fallback, not `send_message`.
- **Never auto-click Send, Delete, or Cancel in the browser.** Playwright drafts the state; the user clicks.
- **One step at a time.** Don't dump all results at once. Summarise counts first ("You have 12 opportunities in 'Proposal Sent'"), then offer to show details.
- **Mask PII when echoing.** When summarising contacts back in the transcript, partially mask phone numbers (`+61 400 *** 000`) and emails (`j***@example.com`) unless the user explicitly asks for the full value.
- **Token hygiene.** Never echo `Authorization` or the PIT to the transcript. Never write them to a file inside the project. Never include them in a commit. The PIT lives in `~/.claude.json` only.
- **Selector failure in Playwright.** Stop and ask the user. Never blind-retry a destructive click.
- **Wrong-location errors.** Stop, report the locationId to the user, and ask them to confirm before you re-run Phase 1.

---

## Related Skills

- **playwright-skill.** Required fallback engine for UI-only surfaces (workflow builder, full email campaign builder)
- **monday-connector.** Sibling Pattern-2 connector with the same autonomous Playwright-driven Phase 1 shape
- **xero-connector.** Same MCP pattern for accounting
- **connector-recommender.** Recommending which connectors to set up
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended). Troubleshooting PIT scope or MCP connection errors
- **email-composer.** Drafting campaign copy before pushing it into a GHL email template
- **n8n-workflow-patterns.** Building GHL-triggered automations
