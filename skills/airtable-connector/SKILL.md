---
name: airtable-connector
description: "Connect and operate Airtable via the official first-party Airtable MCP server (https://mcp.airtable.com/mcp). Drives the entire setup autonomously through airtable.com/create/tokens in a Playwright MCP browser: clicks Create new token, fills the name, ticks the required scope checkboxes, selects All current and future bases, clicks Create token, reads the Personal Access Token from the DOM, and registers the MCP server with the token as a Bearer header. The only human moment is signing in to Airtable once. Use this skill when the user asks to set up Airtable, connect their bases, list tables, read or create records, or update their database schema. On first use run Phase 1 to configure the MCP server and authenticate before attempting tool calls."
allowed-tools: mcp__airtable__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - airtable
    - bases
    - records
    - databases
    - ops
    - crm-lite
    - mcp
  pairs-with:
    - skill: notion-connector
      reason: Sibling workspace/data connector - many teams run both
    - skill: monday-connector
      reason: Sibling project/data connector - often used alongside Airtable
    - skill: jotform-connector
      reason: Pair Jotform intake with Airtable storage (Jotform → Airtable)
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new or updated Airtable records
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Airtable auth or API errors
---

# Airtable Connector

> **Install pattern:** Hosted-bearer-PAT - see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (monday-connector).

## Overview

This skill lets you read and update a user's Airtable account on their behalf using the **official first-party Airtable MCP server** hosted at `https://mcp.airtable.com/mcp`. It has two phases:

- **Phase 1 - Install & Auth (autonomous).** Claude drives the entire `airtable.com/create/tokens` flow inside a Playwright MCP browser. The user does exactly one thing: sign in to Airtable in the Playwright window. Everything else - clicking *Create new token*, filling the name, walking the scope list to tick the required scope checkboxes, selecting "All current and future bases", clicking *Create token*, reading the Personal Access Token from the DOM, registering the MCP server with the token as a Bearer header - is autonomous. The user never copies, never pastes, never reads a token aloud, never opens a tab themselves. This works on Enterprise workspaces too (PAT bypasses the OAuth admin-allowlist).
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__airtable__*` native tools to read and update Airtable data.

**Which phase to run** - Before any tool call, check whether the Airtable MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.airtable` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **A self-hosted or community Airtable MCP server** - Airtable publishes the hosted endpoint at `https://mcp.airtable.com/mcp` as the official first-party deployment (GA since February 2026, available on all plans including Free). Always use the hosted URL.
- **Direct Airtable REST API calls** - all reads and writes go through the MCP server, not direct HTTP calls.
- **`.env` files** - nothing is stored in a local dotenv; the MCP config lives in `~/.claude.json`.

### How auth works under the hood

The hosted Airtable MCP server accepts a Personal Access Token (PAT) passed in an `Authorization: Bearer <token>` header. Claude drives the entire token mint via Playwright at `https://airtable.com/create/tokens` - no copy/paste, no OAuth callback, no admin-allowlist friction. The scopes Airtable documents for the MCP server are `data.records:read`, `data.records:write`, `schema.bases:read`, `schema.bases:write`, `data.recordComments:read`, `data.recordComments:write`, and `workspacesAndBases:read`. The last one (`workspacesAndBases:read`) gates base and workspace discovery - without it `list_bases` / `search_bases` (the first calls Phase 2 makes) return nothing or fail, so it must always be ticked. This works identically on Free, Pro, Team, Business, and Enterprise plans.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work. The user only signs in to Airtable once. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, PAT, Bearer, scope, token, tenant, MCP, endpoint, URL, JSON, REST, environment variable, Playwright, browser automation, or DOM. If you must name a technical concept, plainly:
  - Personal Access Token (PAT) → **"your Airtable access key"**
  - Scopes / OAuth scopes → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - The Playwright browser → **"the browser window I just opened for you"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start, once when you need them ("please sign in" / "please click Allow"), once when you're done. No commentary in between.
- **React to success and failure warmly.** Good: "That worked. Your Airtable is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Plain punctuation.** Write the way a person texts. Use full stops, commas, and parentheses. Do not use em-dashes (-) in anything the user sees, including messages you improvise (timeout check-ins, reassurances); they read as machine-generated.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **No fabricated UI assertions.** Don't reference button colours or specific positioning - verify from the live snapshot. Airtable's token UI changes occasionally.
- **Never echo the access key** back to the user (PAT path). Never include it in any output visible to the user.

---

## PHASE 1 - Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only role is signing in to Airtable when prompted (and only the first time - the persistent Playwright profile keeps the session for future runs). Claude handles every other step - navigation, form fills, scope ticks, base-access selection, token capture from DOM, MCP registration, verify.

> **Why PAT (not OAuth):** the Personal Access Token path works on every Airtable plan including Enterprise, gives identical tool access, and can be driven end-to-end via Playwright (OAuth's localhost callback would require either Claude Code's native launcher or invasive proxying - neither plays well with full autonomy). PAT is the cleaner single-path solution.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the data.records:read scope checkbox"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form` / `browser_select_option` / `browser_type`. Match scope checkboxes by their visible labels, not by selector paths - Airtable's token UI changes.

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your Airtable now. I'm opening a browser window for you. Please sign in to Airtable when it appears, and I'll do the rest. About a minute."

### Step 2 - Open the token page and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://airtable.com/create/tokens" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see the token-management page with a "Create new token" button or the existing tokens list) → continue to Step 3.
- **Not logged in** (sign-in form, "Sign in to Airtable") → tell the user *once*: *"The browser window is open. Please sign in to Airtable when you're ready."* Poll silently with `mcp__playwright__browser_wait_for({ text: "Create new token" })` (or any post-login token-page element). Do not ask the user to confirm; detect login completion yourself.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 - Open the create-token form

Locate the "Create new token" control in the snapshot. Click it via `browser_click`. Snapshot to confirm a creation form/page appears with a name field and scope list.

### Step 4 - Fill the token name

Locate the name input in the snapshot and type via `browser_type` or `browser_fill_form`:
- **Name** → `"Claude Assistant"`

### Step 5 - Tick the required scopes

Airtable's scope list is a series of checkboxes labelled by scope name. For each of the scopes below, locate the matching checkbox from the snapshot (search for the scope text) and click via `browser_click`. Re-snapshot after each tick to confirm state changed.

- `data.records:read`
- `data.records:write`
- `schema.bases:read`
- `schema.bases:write`
- `data.recordComments:read`
- `data.recordComments:write`
- `workspacesAndBases:read`

These are the scopes Airtable documents for the hosted MCP server. `workspacesAndBases:read` is the one most easily missed and the most important - base/workspace discovery (`list_bases`, the first thing Phase 2 does) depends on it, so verify it is ticked before continuing.

If the scope list is collapsed by category, click the category header to expand it before clicking checkboxes. If a scope checkbox isn't visible, look for a search/filter input and type the scope name into it to filter the list.

### Step 6 - Select base access

Locate the "Access" or "Add a base" section in the snapshot. Pick the broadest option:
- Click **"All current and future bases in all workspaces"** if available (preferred - works for all bases the user has now or adds later).
- Otherwise, look for an "Add base" / "Add all bases" control and click it.

If neither is available and the user has only one workspace, select that workspace.

### Step 7 - Create the token

Locate the "Create token" submit button in the snapshot and click it via `browser_click`.

If Airtable shows a confirmation modal, snapshot it and click the affirmative option.

Poll `mcp__playwright__browser_wait_for({ text: "pat" })` (or wait for the token-reveal screen - typically shows a `pat...` value in a code block with a Copy button).

### Step 8 - Capture the access token

The post-creation screen displays the Personal Access Token (starts with `pat`). Read it via `browser_evaluate`:

```
() => {
  const candidates = [...document.querySelectorAll('input, code, textarea, [data-testid*="token"], [class*="token"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (v.startsWith('pat') && v.length > 30) return v;
  }
  return null;
}
```

If the token is masked behind a "Copy" or "Show" button, click it via `browser_click`, re-snapshot, then re-evaluate.

**Validation (silent):**
- Token must start with `pat`
- Token must be longer than 30 characters

If two snapshot attempts don't surface a valid token, stop and ask the user: *"I'm having trouble finding the access key on the page. Could you describe what's visible?"*

### Step 9 - Save the connection (silent)

Silently register the MCP server with the PAT as a Bearer header. **Prefer `claude mcp add` via Bash**:

```bash
claude mcp add airtable \
  --scope user \
  --transport http \
  --header "Authorization: Bearer <token captured in Step 8>" \
  -- https://mcp.airtable.com/mcp
```

**Fallback if `claude mcp add` fails** - write directly to `~/.claude.json`:

<details>
<summary>Direct JSON write</summary>

```json
{
  "mcpServers": {
    "airtable": {
      "type": "http",
      "url": "https://mcp.airtable.com/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object - never overwrite. If `~/.claude.json` doesn't exist, create it. If corrupt, back up to `~/.claude.json.backup` first.

Never echo the access key back to the user. Never include it in any output visible to the user. Never paste the contents of `~/.claude.json` to the user.

### Step 10 - Close the browser, verify, success message

`mcp__playwright__browser_close()`.

Tell the user: *"Saved. Let me check it works."*

- **If `mcp__airtable__*` tools are available**: call `mcp__airtable__list_bases`. If it returns a result (even empty), capture the count and use the same success message as the OAuth path.
- **If tools not available**: *"All saved. Please close and reopen Claude Code once, then say 'test my Airtable' and I'll verify."*

If verification returns `401`, the most likely causes are a partial token capture or a missing scope. Re-run Steps 2-9 to mint a fresh token with all required scopes ticked.

---

## PHASE 2 - Use Tools

Once the connector is configured, use the `mcp__airtable__*` MCP tools below to answer questions and make changes in Airtable. The hosted Airtable MCP server exposes a set of first-party tools covering base/workspace discovery, records, schema mutations, and connection health. The most common ones are documented below; the server also exposes additional tools (e.g. `search_records`, `create_base`, `list_workspaces`, and page tools) - if you need one that is not in the tables below, list the available tools with the `mcp__airtable__` prefix to discover the current set rather than assuming a name.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__airtable__`. If a tool name does not resolve, list available tools with the `mcp__airtable__` prefix to discover the current naming.

#### Discovery (read-only - no confirmation needed)

| Tool | Description | Use when |
|---|---|---|
| `list_bases` | List all Airtable bases the user can access | User asks "show me my bases", or you need a base ID before another call |
| `search_bases` | Search bases by name | User names a specific base and you need to locate it |
| `list_tables_for_base` | List all tables inside a base | User asks "what tables are in my CRM?" |
| `get_table_schema` | Retrieve the fields and schema of a table | Before any record write, or when the user asks "what fields does this table have?" |

#### Records

| Tool | Description | Use when |
|---|---|---|
| `list_records_for_table` | Fetch records from a table | User asks to read entries - default page size 25 |
| `display_records_for_table` | Fetch records formatted for display | When the user wants a readable table rather than raw data |
| `search_records` | Find records matching a query within a table | User asks to find a specific row ("find the lead named Acme") without reading the whole table |
| `create_records_for_table` | Create up to 10 records in a table | User asks to add rows - **confirm first, max 10 per batch** |
| `update_records_for_table` | Update existing records in a table | User asks to change a row - **confirm first** |

#### Schema mutations (destructive - always confirm)

| Tool | Description | Use when |
|---|---|---|
| `create_table` | Create a new table in a base | User asks to add a table - **double-confirm, irreversible via this connector** |
| `create_field` | Add a new field to a table | User asks to add a column - **double-confirm, irreversible via this connector** |
| `update_table` | Rename or update a table | User asks to rename or reshape a table - **confirm first** |
| `update_field` | Update a field's definition | User asks to change a column's name or type - **confirm first** |

#### Utility

| Tool | Description | Use when |
|---|---|---|
| `ping` | Verify the MCP connection is live | Diagnostic only - use if tool calls start failing and you want to isolate whether the server is reachable |

> **Note:** Tool names are from the official `mcp.airtable.com` server (GA since Feb 2026). If a name does not resolve, list available tools with the `mcp__airtable__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Airtable" / "Help me set up Airtable" | **Run Phase 1** |
| "Show me my bases" | `list_bases` |
| "Find my CRM base" | `search_bases` |
| "What tables are in my CRM base?" | `list_bases` (find base ID) → `list_tables_for_base` |
| "What fields does the Leads table have?" | `list_tables_for_base` → `get_table_schema` |
| "Show me all records in my Leads table" | `list_tables_for_base` → `list_records_for_table` |
| "Show the latest 10 records in Leads" | `list_records_for_table` (limit 10, sorted by created time desc) |
| "Find the lead named Acme in my Leads table" | `search_records` (avoids paging the whole table) |
| "Display the Contacts table nicely" | `display_records_for_table` |
| "Add this lead to the Leads table" | `get_table_schema` → `create_records_for_table` - **confirm first** |
| "Import these 30 contacts into Airtable" | Split into batches of 10 → loop `create_records_for_table` - **confirm first** |
| "Update the status of that lead to Qualified" | `update_records_for_table` - **confirm first** |
| "Add a new 'Phone' column to my Contacts table" | `get_table_schema` → `create_field` - **double-confirm, irreversible** |
| "Rename the 'Q1 leads' table to 'Q2 leads'" | `update_table` - **confirm first** |
| "Change the 'Status' field to a dropdown with these options" | `update_field` - **confirm first** |
| "Create a new table called 'Projects' in my Ops base" | `create_table` - **double-confirm, irreversible** |
| "Is my Airtable working?" | `ping` |

---

## Error Handling (Phase 2)

When an Airtable tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Airtable sign-in has expired. Let me reconnect you." | Re-run Phase 1 (Steps 2-9) to mint a fresh access key via the browser automation. Never ask the user to generate or paste a token by hand - the autonomy rules forbid it. |
| 403 Forbidden | "Your Airtable user doesn't have permission for that. The base owner may need to share it with you, or an admin may need to grant access." | User talks to the base owner or workspace admin |
| 404 Not Found (base / table / record) | "I couldn't find that record. Let me refresh the list." | Use `list_bases` / `list_tables_for_base` / `list_records_for_table` to refresh |
| 422 Invalid request | "Airtable rejected the change. This is usually a field type mismatch. Let me check the schema and try again." | Call `get_table_schema` and re-format the write |
| 429 Rate limited | "Airtable is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. Airtable's standard limit is 5 requests per second per base. |
| MCP server not running | "The Airtable connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Admin approval required (Enterprise) | "Your workspace administrator has restricted this sign-in. No problem, I can connect it a different way." | This skill already uses the access-key (PAT) path, which bypasses the OAuth admin-allowlist. Re-run Phase 1 to mint the key via the browser. |
| Any other API error | "Something went wrong with Airtable. Let me try again." | Retry once; if still failing, re-do the sign-in |

---

## Scope Limitations

The Airtable MCP connector **can** do (via the official Airtable MCP server):

- List and search bases the user has access to
- List tables within a base and inspect a table's field schema
- Read and display records (with pagination)
- Create records (up to 10 per call) and update records
- Create and update tables, create and update fields
- Ping the connection to verify it is live

The Airtable MCP connector **cannot** do (needs the Airtable UI or other tools):

- **Delete** records, tables, or fields - none of the connector's tools supports deletion
- Batch-create more than 10 records in a single call (loop with batches of 10)
- Attach files to record cells via the MCP (use the Airtable UI or REST API directly)
- Access **Interfaces**, **Automations**, or **Extensions** - schema-level access only
- Manage workspace-level billing, users, or permissions
- Connect multiple Airtable accounts simultaneously - one browser session or PAT per `~/.claude.json` entry
- Bypass Enterprise admin allowlisting - if the admin blocks OAuth app installs, the PAT fallback is the only option

---

## Enterprise note - admin allowlisting can block first connect

On **Enterprise Airtable workspaces**, the workspace administrator can restrict which third-party apps are allowed to connect via OAuth. If this is enforced, the browser sign-in will show an "administrator approval required" screen or silently fail. In that case:

1. Offer the PAT fallback path - it works on Enterprise because a PAT is scoped to the user's own Airtable permissions and does not require an OAuth app install.
2. If the user wants the browser path to work long-term, their Airtable admin needs to allowlist the Airtable MCP app for the workspace. That is a one-time setup on the admin's side. Once allowlisted, other team members can connect normally via the browser.

This mirrors the same shape as the Jotform "workspace admin must install first" limitation documented in `known-issues/JOTFORM-ADMIN-ONLY.md`.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, or changing schema** - summarise what you are about to do and wait for the user's OK before calling a write tool. Schema changes (`create_table`, `create_field`, `update_table`, `update_field`) are irreversible via this connector - **double-confirm** them and repeat the exact name back before calling.
- **Discover IDs before writing** - Airtable bases, tables, fields, and records are referenced by opaque IDs (`appXXXX`, `tblXXXX`, `fldXXXX`, `recXXXX`). Always call `list_bases` → `list_tables_for_base` → `get_table_schema` once per session before any write, unless you already have the IDs from earlier in the conversation.
- **Respect the 10-record batch limit** - `create_records_for_table` accepts at most 10 records per call. For bulk imports, split into batches and pause briefly between batches (Airtable limits you to 5 requests per second per base).
- **Records often contain personal data** - leads, contacts, customer feedback. Never paste full record contents into a public log without checking with the user first. When summarising, prefer counts and a sample over full dumps.
- **Present data clearly** - format results as readable tables or summaries, not raw JSON. `display_records_for_table` is designed for this; prefer it when the user wants a readable view.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 3 bases; your CRM base has 4 tables with 1,240 records in Leads"), then offer to show details.
- **Pagination** - default to 25 records unless the user asks for more. Offer to show more if there are additional pages.
- **Schema changes are irreversible via this connector** - there are no delete tools. Once `create_table` or `create_field` fires, the only way to remove the change is via the Airtable UI.
- **Importing data is destructive if wrong** - `create_records_for_table` writes real rows. For bulk imports, show the user a sample of the first row before proceeding with the rest.
- **Respect read-only Airtable roles** - if the user's Airtable role is viewer/commenter only, write tools will return `403 Forbidden`. Do not retry - fall back to read-only operations and let the user know which tools are unavailable for their role.
- **Never log or echo credentials** - on the PAT path, never echo the access key back. On the browser path, there is no user-visible token, but never paste the contents of `~/.claude.json` to the user either.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Airtable auth or API errors
- **jotform-connector**: Sibling hosted-OAuth MCP connector - same ≤4-step install pattern, URL-only config
- **notion-connector**: Sibling workspace/data connector - similar conversational install
- **monday-connector**: Sibling project/data connector - similar conversational install
- **n8n-workflow-patterns**: Build Airtable-triggered automations once the connector is live
