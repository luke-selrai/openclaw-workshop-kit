---
name: hubspot-connector
description: "Connect HubSpot to Claude by switching on its built-in connector, or by installing HubSpot's own private-app server when the built-in can't do a needed write. Use when the user asks to set up HubSpot or connect their CRM, or wants HubSpot work (contacts, companies, deals, tickets, notes, tasks, properties, workflows) and HubSpot isn't connected yet. Once connected, HubSpot runs through the mcp__claude_ai_HubSpot__* tools, or the mcp__hubspot__* tools on the kit's own route."
allowed-tools: mcp__claude_ai_HubSpot__*, mcp__hubspot__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: CRM & Marketing
  tags:
    - hubspot
    - crm
    - contacts
    - companies
    - deals
    - tickets
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Compose follow-up emails for deals or contacts
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by HubSpot events (deal stage change, new contact, etc.)
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting HubSpot auth or API errors
---

# HubSpot Connector

## Overview

This skill lets you read and update a user's HubSpot CRM data on their behalf. There are two routes onto HubSpot, and **the built-in connector is the default**:

- **Phase 1 - the built-in HubSpot connector (default).** HubSpot's own hosted server, listed in Claude's connector directory at `https://claude.com/connectors/hubspot` (slug verified live, 2 Sep 2026). The user presses one button on their Claude account and signs in to HubSpot the way they normally do. The connection is **account-level**: connect once and it is available everywhere that account is signed in, including Claude Code. Tools arrive as `mcp__claude_ai_HubSpot__*`. Nothing is captured, stored or written to disk on this route - there are no credentials to handle.
- **Phase 1-alt - the kit's own route** (only when a write through the built-in genuinely fails, or the session can't see built-in connectors at all). Claude drives the entire `app.hubspot.com/private-apps/` flow inside a Playwright MCP browser and registers the **official first-party `@hubspot/mcp-server`** (npm, beta) against a Private App access token. The user does exactly one thing: sign in to HubSpot in the Playwright window. Everything else - clicking *Create a private app*, filling the name and description, walking the *Scopes* tab to tick the required CRM scopes, clicking *Create app*, reading the Private App access token from the DOM, writing `~/.claude.json` - is autonomous. The user never copies, never pastes, never opens a tab themselves, never reads a token aloud, never types into chat anything other than confirmations. Tools arrive as `mcp__hubspot__*`.
- **Phase 2 - Use Tools.** Whichever route connected, read and update CRM data through that route's tools.

**Which phase to run** - always start at **Phase 0** below. It checks the built-in connector first, then the kit's own registration (an `mcpServers.hubspot` entry in `~/.claude.json`, or `%USERPROFILE%\.claude.json` on Windows, with a `PRIVATE_APP_ACCESS_TOKEN` in its `env` block). A working connection on either route means skip straight to Phase 2 - never set one route up on top of the other.

### Read-only or read-and-write? Verify live; never route on the badge

The directory page badges HubSpot **Read** (checked 2 Sep 2026). **That badge lags reality.** HubSpot says the underlying server went read / create / update GA on **13 April 2026** across contacts, companies, deals, tickets, custom objects, products, line items and engagements. So treat the built-in as read *and* write, prove it with one harmless write the first time a write is needed (Phase 1, Step 5b), and fall back to the kit's route **only on a real failure** - never on the badge alone.

### What the kit's own route does NOT use

- **`@hubspot/cli` (`hs` command)** - that is a CMS development tool for themes, HubL, and serverless functions. Wrong audience for a CRM connector. Do not install it.
- **OAuth / Client ID / Client Secret / Redirect URI** - HubSpot Private Apps use a simple access token. No OAuth flow needed.
- **Marketing Hub / Service Hub / Commerce APIs** - deferred to a future version. Do not build curl-based API wrappers.

---

## Communication rules (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Both routes are autonomous - Claude does the work, the user only signs in to HubSpot once. Every message you send during either route must follow these rules:

- **Browser routing for the built-in connector.** Follow Phase 1's Desktop in-app-first route and account-matched browser handoff. Use available UI tools; ask the user only for input the harness cannot complete. The kit's separate credential-capture browser rules still apply to its own route.
- **Never ask for a password, a sign-in code, or a screenshot of a sign-in screen** on either route.
- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, Playwright, browser automation, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - Private App access token → **"your HubSpot key"**
  - Scopes → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - Private App → **"a small connection app inside your HubSpot"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening HubSpot for you now"), once when you need them ("please sign in"), once when you're done ("your HubSpot is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your HubSpot is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message while connecting.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **No fabricated UI assertions.** Don't reference button colours ("the orange button") or specific positioning ("top-right corner") - verify from the live snapshot. HubSpot's admin UI changes frequently.
- **Never echo the HubSpot key** back to the user. Never include it in any output visible to the user.

---

## PHASE 0 - Is HubSpot already connected?

Identify the calling surface first. Desktop's visible account, Connectors view, and actual runtime tools are its evidence. Terminal `claude auth status` and `claude mcp list` describe the CLI account, even when run from Desktop's Bash; they do not establish Desktop identity or access. HubSpot credentials are independent of either Claude login. Discover existing tools and perform the read below for the intended vendor account before claiming a connection. Preserve a working route.

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** In Desktop, discover this session's HubSpot tools (including opaque-ID prefixes) and inspect the app's Connectors view. For a terminal/VS Code caller only: `claude mcp list` → look for a line starting `claude.ai HubSpot` (match the vendor word case-insensitively - the directory renders it "Hubspot" in places).
   - Connected in the caller or tools present → skip to **Phase 2**. Prove it first with one read from the `mcp__claude_ai_HubSpot__*` namespace (list a couple of contacts) before saying so.
   - Reconnect or `! Needs authentication` → reconnect in the same caller's Connectors view. In Desktop, start inside the app; for a browser route, verify its Claude account matches the caller before opening `https://claude.ai/customize/connectors`. Complete HubSpot sign-in and repeat the actual read.
   - No usable built-in in the caller → continue to step 2; a missing CLI line alone says nothing about Desktop.
2. **The kit's own route.** Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.hubspot` entry with a `PRIVATE_APP_ACCESS_TOKEN` in its `env` block. If it is there and `mcp__hubspot__hubspot-get-user-details` returns the portal name, keep using it - say *"HubSpot is already connected"* and skip to **Phase 2**. Do not set the built-in up on top of a working connection.
3. **Nothing found** → **Phase 1**.

**Local entry precedence (terminal/VS Code only).** A server registered locally at the same URL takes precedence and hides the built-in one. If a machine that ran the kit's route still has a working `mcpServers.hubspot` entry, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the user's OK. Desktop may expose local and built-in tools simultaneously; discover the actual runtime and keep each result attached to its connection.

**No shell?** Runtime discovery and reads still apply. Skip unavailable command/file checks; only set up a connection if no working route is found, following the existing route-by-need rules.

---

## Route by need - built-in or the kit's route?

Before installing anything, ask one question in plain English: **what does the user want Claude to do with HubSpot?** Then route what they name:

| What the user wants | Route |
|---|---|
| Look things up - contacts, companies, deals, tickets, properties, workflows, "how many deals are open" | **Built-in** |
| Everyday CRM writes - create or update contacts, companies, deals, tickets, custom objects, products, line items, notes and tasks | **Built-in** (read/create/update GA since 13 Apr 2026; the Read badge is stale) |
| A write that **genuinely fails** through the built-in - a real tool error, not a guess | The kit's own route (Phase 1-alt) |
| The session can't see built-in connectors at all (Phase 1 Step 1 fails), or the user explicitly asks for the local server | The kit's own route (Phase 1-alt) |

Both routes can coexist on one machine. Never tear one down to set the other up, and never burden the user with the kit's extra setup when the built-in already covers what they asked for.

---

## PHASE 1 - Switch on the built-in HubSpot connector (the default route)

This is a one-time, once-per-account job. Claude handles the available setup steps; the user supplies any sign-in input that requires them.

**Step 1 - Check this session can see built-in connectors.** In Desktop, use its visible signed-in account and Connectors view, then continue inside that app. The following auth/settings checks apply only to a terminal/VS Code caller, not Desktop: `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.**

Say: *"I'll open HubSpot's connection page and handle the setup. I'll let you know if it needs you to sign in."*

**Desktop first:** use the app's **+ → Connectors → Browse connectors → HubSpot → Connect** (or the equivalent visible Customize/Connectors menu). Keep the exact app-created browser handoff URL, including its parameters. Open it in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended HubSpot account before approval. Do not replace it with a directory link from another Claude account.

**Terminal/VS Code or browser fallback:** open `https://claude.ai/directory/hubspot` in a browser whose Claude account matches the caller. Use `open` (Mac), `xdg-open` (Linux), or `start` (Windows) only after confirming that browser's account. If the page fails, use `https://claude.ai/customize/connectors` → **Browse** → search "HubSpot" → **Connect** in that same account.

Drive navigation and approval with available UI tools. If a step requires user input or the harness has no suitable UI tool, give only the exact short next step; do not describe every click as inherently human-only.

**Step 3 - Wait.** Complete the visible flow with available tools; wait for any sign-in input that requires the user. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.**

Check HubSpot in Desktop's own Connectors view, or `claude mcp list` for a terminal/VS Code caller. Connected is registration evidence only; proceed to the real read in Step 5. Reconnect uses the same account's Connectors view. A missing CLI line says nothing about Desktop. If Desktop still lacks a connection completed through the browser directory, verify **Connected** in that browser's matching Claude account. Once that account check passes, rediscover Desktop's tools and use Step 5's one-time Desktop refresh if needed; do not repeat **Connect** to repair a stale app view. Return to Step 2 only when neither the caller's view nor the account-matched browser confirms a completed connection.

**Step 5 - Prove it (read).** Call one real read through the connector - list a couple of contacts from the `mcp__claude_ai_HubSpot__*` namespace. Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If tools are missing, first rediscover deferred tools and confirm the same caller account is connected; only then consider a stale session: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 5b - Prove it (write), the first time a write is wanted.** The directory badge says Read; HubSpot says writes went GA on 13 Apr 2026. Settle it with a real probe, not the badge: ask the user to nominate a record and create a **note** on it (a note is the least invasive write, and they can remove it in HubSpot in one click), or simply let their first genuine write be the probe. If it succeeds, the built-in writes - stay on it. If it fails with a real tool error, say so plainly and run **Phase 1-alt** for the write half. Do not pre-emptively fall back.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch HubSpot on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-ALT - Install & Auth (autonomous via Playwright)

**Run this only when** a write through the built-in genuinely failed (Step 5b), the session can't see built-in connectors (Step 1 failed), the directory listing is missing on the user's account, or the user explicitly wants the local server. Otherwise stay on Phase 1.

Claude drives the user's browser end-to-end via Playwright MCP. The user's only role is signing in to HubSpot when prompted. Claude handles every other step - navigation, form fills, scope ticks, app creation, token capture, config write, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the scope checkbox for `crm.objects.contacts.read`"). Achieve it via `mcp__playwright__browser_snapshot` → reason about the page → call `browser_click` / `browser_evaluate` / `browser_navigate` / `browser_fill_form` / `browser_type`. Do not hardcode CSS selectors or button colours - HubSpot's admin UI changes regularly. Re-snapshot whenever the page state changes.

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your HubSpot now. I'm opening a browser window - please sign in to HubSpot there, and I'll set up a small connection app for you. About a minute."

If the user has mentioned a specific portal/account name, remember it for the disambiguation in Step 2.

### Step 2 - Open the Private Apps page and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://app.hubspot.com/private-apps/" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in to a single portal** (you see the Private Apps list, "Create a private app" control, or HubSpot navigation chrome) → continue to Step 3.
- **Not logged in** → tell the user *once*: *"The browser window is open - please sign in to HubSpot when you're ready."* Poll silently with `mcp__playwright__browser_wait_for({ text: "Create a private app" })` (or any post-login HubSpot shell element from a fresh snapshot). Do not ask the user to confirm; detect login completion yourself. SSO, 2FA, and email verification all resolve to the same Private Apps page.
- **Portal selector / multi-account picker** (HubSpot shows a list of portals to pick) → snapshot the portal options. If the user named a specific portal, match it against the list and click that option. Otherwise list the visible portal names plainly and ask the user to pick one.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 - Open the Create-a-private-app form

From the Private Apps page, locate the create-app control in the snapshot (label is typically "Create a private app" - verify from the snapshot, do not assume colour or position) and click it via `browser_click`. Snapshot to confirm a creation form appears with a Basic Info or Name field.

### Step 4 - Fill Basic Info

Fill the form via `browser_fill_form` (or individual `browser_type` calls):
- **Name** → `"Claude Assistant"`
- **Description** → `"AI assistant connection"` (skip if the field isn't present)

If the form has a logo/image upload, leave it blank.

### Step 5 - Configure scopes on the Scopes tab

Locate the "Scopes" tab in the snapshot (commonly adjacent to "Basic Info"). Click it. Snapshot to confirm a scope list appears.

Tick the following scope checkboxes. Re-snapshot after each tick to confirm the checkbox state changed.

**CRM read scopes** (always - read-only baseline):
- `crm.objects.contacts.read`
- `crm.objects.companies.read`
- `crm.objects.deals.read`
- `crm.objects.tickets.read`
- `crm.schemas.contacts.read`

**CRM write scopes** (default - full functionality, skip only if user explicitly asked for read-only mode):
- `crm.objects.contacts.write`
- `crm.objects.companies.write`
- `crm.objects.deals.write`
- `crm.objects.tickets.write`

The HubSpot scope list is grouped by category (CRM, Settings, etc.) and may use collapsed sections, search, or pagination. Strategy:

- If a scope checkbox is visible in the snapshot → click it.
- If not visible → look for a search/filter input on the page. If present, type the scope name into it via `browser_type` to filter the list, then click the matching checkbox.
- If no search → look for a collapsed CRM category header and click it to expand, then snapshot again and click the checkboxes.

Verify silently: re-snapshot and confirm all selected scopes are ticked before proceeding.

### Step 6 - Create the app

Locate the "Create app" button in the snapshot. Click it.

If HubSpot shows a confirmation modal ("Continue creating", "Yes, create", or similar), snapshot the modal and click the affirmative option.

Poll `mcp__playwright__browser_wait_for({ text: "access token" })` (or any post-creation indicator like "Show token", "Copy", or the masked token preview).

### Step 7 - Capture the access token

The post-creation screen displays the Private App access token (starts with `pat-`). Read it via `browser_evaluate`:

```
() => {
  const candidates = [...document.querySelectorAll('input, code, textarea, [data-testid*="token"], [class*="token"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (v.startsWith('pat-') && v.length > 30) return v;
  }
  return null;
}
```

If the token is masked behind a "Show", "Reveal", or "Copy" button, click it via `browser_click`, re-snapshot, then re-evaluate.

**Validation (silent):**
- Token must start with `pat-`
- Token must be longer than 30 characters

If two snapshot attempts don't surface a valid token, stop and ask the user: *"I'm having trouble finding the connection key on the page - could you describe what's visible?"*

### Step 8 - Save the connection (silent)

Silently register the MCP server. **Prefer `claude mcp add` via Bash** - it's the official path and handles JSON merging.

```bash
claude mcp add hubspot \
  --scope user \
  --env PRIVATE_APP_ACCESS_TOKEN="<token captured in Step 7>" \
  -- npx -y @hubspot/mcp-server
```

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) - write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`):

<details>
<summary>Direct JSON write</summary>

```json
{
  "mcpServers": {
    "hubspot": {
      "command": "npx",
      "args": ["-y", "@hubspot/mcp-server"],
      "env": { "PRIVATE_APP_ACCESS_TOKEN": "<token>" }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object - never overwrite. If `~/.claude.json` doesn't exist, create it. If it's corrupt, back up to `~/.claude.json.backup` first.

Never echo the access token back to the user. Never include it in any output visible to the user. Never log it to the conversation, even truncated.

### Step 9 - Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"Saved - let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__hubspot__*` tools are available**: call `mcp__hubspot__hubspot-get-user-details`. If it returns the portal name, capture and move to Step 10.
- **If the tools are not yet available** (most likely on first setup): tell the user *"All saved. Please close and reopen Claude Code once so the connection becomes active, then say 'test my HubSpot' and I'll verify it."*

If verification returns an error:
- `401 Unauthorized` / `Invalid token` → "The connection key didn't take - let me grab a fresh one." Re-run Steps 2-8 against the existing Claude Assistant Private App: navigate to its Auth tab, click "Rotate" / "Regenerate", capture the new token, update the config.
- `403 Forbidden` / `Missing scope` → "I need one more permission to do that. Let me add it." Drive Playwright back to the existing Private App's Scopes tab, tick the missing scope, click Save (HubSpot doesn't issue a new token on scope edit), then retry the failing tool call.
- Any other error → "Something went wrong - let me try again." Retry once; if still failing, re-run Steps 2-8.

### Step 10 - Success message

Tell the user, in one short message:

> "All done! I'm now connected to your HubSpot account **[portal name if available]**. You can ask me things like 'show me my recent contacts' or 'list my open deals'. Give it a try!"

---

## PHASE 2 - Use Tools

Once the connector is configured, answer questions and make changes in HubSpot through whichever route connected.

**Which tool namespace.** Through the built-in connector the tools are `mcp__claude_ai_HubSpot__*`; through the kit's own route they are `mcp__hubspot__*`. **The tool names differ materially between the two** - the catalogue below is the `@hubspot/mcp-server` naming and applies to the kit's route only. On the built-in route, list what is actually in the `mcp__claude_ai_HubSpot__*` namespace and match by what each tool does, not by the names in this table. Everything under "Prompt-to-Tool Mapping", "Error Handling" and "Behaviour Guidelines" below applies to both routes; only the literal tool names are route-specific.

### Tool Reference (the kit's own route)

The official MCP server exposes tools with the prefix `mcp__hubspot__`. The exact tool names follow the pattern `mcp__hubspot__hubspot-<action>`. Below are the known tools and when to use them:

#### CRM Objects (Contacts, Companies, Deals, Tickets)

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-objects` | Retrieves a paginated list of CRM records for a specified object type | User asks to list/browse contacts, companies, deals, or tickets |
| `hubspot-search-objects` | Performs filtered searches across CRM records using complex criteria | User asks to find records by name, email, or property value |
| `hubspot-batch-read-objects` | Retrieves multiple CRM records by their IDs in a single batch | User asks for details about specific records by ID |
| `hubspot-batch-create-objects` | Creates multiple CRM records of the same type in a single call | User asks to create a new contact, company, deal, or ticket - **confirm first** |
| `hubspot-batch-update-objects` | Updates multiple existing CRM records with new property values | User asks to update properties on any CRM object - **confirm first** |

#### Properties

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-properties` | Retrieves the complete catalog of properties for any CRM object type | User asks what fields are available on contacts, companies, deals, etc. |
| `hubspot-get-property` | Retrieves detailed information about a specific property definition | User asks about a specific field's options or configuration |
| `hubspot-create-property` | Creates new custom properties for CRM object types | User asks to add a custom field - **confirm first** |
| `hubspot-update-property` | Updates settings for existing custom properties | User asks to modify a custom field - **confirm first** |

#### Associations

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-associations` | Retrieves existing relationships between a record and associated records | User asks what is linked to a contact/company/deal (e.g., "what deals does Acme have?") |
| `hubspot-batch-create-associations` | Establishes multiple relationships between CRM records | User asks to link a contact to a company, a deal to a contact, etc. - **confirm first** |
| `hubspot-get-association-definitions` | Retrieves valid association types and labels between object types | You need to know which association types are valid before creating one |

#### Engagements (Notes & Tasks)

| Tool | Description | Use when |
|---|---|---|
| `hubspot-create-engagement` | Creates engagements (Notes or Tasks) associated with CRM records | User asks to create a note or task on a contact, company, or deal - **confirm first** |
| `hubspot-get-engagement` | Retrieves engagement details by ID | User asks to see a specific note or task |
| `hubspot-update-engagement` | Updates an existing engagement with new information | User asks to edit a note or task - **confirm first** |

#### Custom Objects

| Tool | Description | Use when |
|---|---|---|
| `hubspot-get-schemas` | Retrieves available custom object schemas with objectTypeId and definitions | User asks about custom object types in their portal |

#### Workflows

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-workflows` | Retrieves a paginated list of workflows | User asks to see their automated workflows |
| `hubspot-get-workflow` | Retrieves detailed info about a specific workflow (actions, enrollment criteria) | User asks about a specific workflow's configuration |

#### Account & Links

| Tool | Description | Use when |
|---|---|---|
| `hubspot-get-user-details` | Authenticates token and returns user info, hub details, and scopes | User asks "what HubSpot account am I connected to?" or you need to verify the connection |
| `hubspot-get-link` | Generates HubSpot UI URLs to directly access records in the browser | User wants a link to open a record in HubSpot |
| `hubspot-generate-feedback-link` | Generates a feedback link for reporting tool issues to HubSpot | User wants to report an issue with the MCP tools |

> **Note:** Tool names are from `@hubspot/mcp-server` v0.4.0 (beta). If a tool name does not resolve, try listing available tools with the `mcp__hubspot__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Show me my contacts" | `hubspot-list-objects` (objectType: contacts) |
| "Find the contact with email jane@example.com" | `hubspot-search-objects` (objectType: contacts, search by email) |
| "Show me details for contact #12345" | `hubspot-batch-read-objects` (objectType: contacts) |
| "Create a new contact for Jane Doe" | `hubspot-batch-create-objects` (objectType: contacts) - **confirm first** |
| "List my companies" | `hubspot-list-objects` (objectType: companies) |
| "Show me my open deals" | `hubspot-search-objects` (objectType: deals, filter by stage) |
| "Create a deal for Acme Corp" | `hubspot-batch-create-objects` (objectType: deals) - **confirm first** |
| "Update the phone number on contact #12345" | `hubspot-batch-update-objects` (objectType: contacts) - **confirm first** |
| "What deals are linked to Acme Corp?" | `hubspot-list-associations` |
| "Link this deal to that contact" | `hubspot-batch-create-associations` |
| "Add a note to this deal" | `hubspot-create-engagement` (type: note) |
| "Show me tasks on this contact" | `hubspot-get-engagement` |
| "What properties does a contact have?" | `hubspot-list-properties` (objectType: contacts) |
| "Show me my workflows" | `hubspot-list-workflows` |
| "What HubSpot account am I connected to?" | `hubspot-get-user-details` |
| "Connect my HubSpot" / "Help me set up HubSpot" | **Run Phase 0**, then Phase 1 |

---

## Error Handling (Phase 2)

When a HubSpot tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your HubSpot connection has expired or the key was revoked - let me help you reconnect." | Run Phase 1-alt from Step 2 (create a new Private App or copy a fresh token) |
| 403 Forbidden / Missing scope | "I need an extra permission to do that. Let me walk you through adding it." | Guide user to Private App → Scopes tab → tick the needed scope → Save. Then retry. |
| 429 Rate limited | "HubSpot is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| "Token revoked" | "Your connection key has been revoked in HubSpot. Let me help you create a new one." | Run Phase 1-alt from Step 2 |
| Object not found (404) | "I couldn't find that record - let me search for it." | Use search tool to help find the correct object |
| MCP server not running | "The HubSpot connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with HubSpot - let me try again." | Retry once; if still failing, check token validity |

---

## Scope Limitations (the kit's own route)

The HubSpot MCP connector **can** do (via `@hubspot/mcp-server`):
- Read and write contacts, companies, deals, and tickets
- Search CRM objects by any property
- Read and create custom object schemas
- Read and create properties on any object type
- Read and create associations between objects
- Create engagements (notes, tasks) on CRM records
- Read workflows
- Read account/user details

The HubSpot MCP connector **cannot** do (deferred to a future version):
- Marketing Hub operations (email campaigns, forms, landing pages)
- Service Hub operations (knowledge base, feedback surveys)
- Commerce operations (quotes, payments, subscriptions)
- File uploads or attachments
- Bulk import/export
- Delete CRM records (use the HubSpot UI for deletions)
- Send emails directly
- Trigger or modify workflows (read-only)

**On the built-in route** the covered surface is HubSpot's own hosted server: contacts, companies, deals, tickets, custom objects, products, line items and engagements - read, create and update (GA 13 Apr 2026). Deletions, Marketing/Service/Commerce Hub operations and file uploads are out of scope on **both** routes; those stay in HubSpot's own screens.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating or updating** records - summarise what you are about to do and wait for the user's OK before calling the tool.
- **IDs are numeric** - HubSpot uses numeric IDs (e.g. `12345`) for all CRM objects.
- **Amounts are in full currency units** - deal amounts are in dollars (e.g. `50000` = $50,000), not cents.
- **Present data clearly** - format results as readable tables or summaries, not raw JSON.
- **One step at a time** - do not dump all data at once. Summarise first, then offer to show details.
- **Pagination** - default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits** - HubSpot enforces 200 requests per 10 seconds for Private Apps. If you hit a 429, wait before retrying.
- **Deal stages** - stage IDs vary by pipeline and account. List pipeline stages first before setting a deal stage.
- **Properties** - use `hubspot-list-properties` to discover available fields before assuming a property exists.
- **Associations** - check existing associations before creating duplicates.
- **Never log or echo credentials** - the Private App access token must never appear in any output visible to the user.
- **Scope expansion** - if a tool call fails with 403 / missing scope, guide the user to add the scope in their Private App settings. They do NOT need to create a new app - just edit the existing one and click Save.

---

## Related Skills

- **orientation**: The source pattern for conversational bootstrap; the connect flows above follow the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting HubSpot auth or API errors
- **xero-connector**: Sibling accounting connector - similar MCP pattern for a different platform
