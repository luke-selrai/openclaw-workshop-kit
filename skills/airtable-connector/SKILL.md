---
name: airtable-connector
description: "Connect and operate Airtable via the official first-party Airtable MCP server (https://mcp.airtable.com/mcp). Use this skill when the user asks to set up Airtable, connect their bases, list tables, read or create records, or update their database schema. On first use run Phase 1 to configure the MCP server and authenticate before attempting tool calls."
allowed-tools: mcp__airtable__*, Bash, Read, Write, Edit
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
      reason: Sibling workspace/data connector — many teams run both
    - skill: monday-connector
      reason: Sibling project/data connector — often used alongside Airtable
    - skill: jotform-connector
      reason: Pair Jotform intake with Airtable storage (Jotform → Airtable)
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new or updated Airtable records
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Airtable auth or API errors
---

# Airtable Connector

## Overview

This skill lets you read and update a user's Airtable account on their behalf using the **official first-party Airtable MCP server** hosted at `https://mcp.airtable.com/mcp`. It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Airtable. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Airtable is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__airtable__*` native tools to read and update Airtable data.

**Which phase to run** — Before any tool call, check whether the Airtable MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.airtable` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **A self-hosted or community Airtable MCP server** — Airtable publishes the hosted endpoint at `https://mcp.airtable.com/mcp` as the official first-party deployment (GA since February 2026, available on all plans including Free). Always use the hosted URL.
- **Direct Airtable REST API calls** — all reads and writes go through the MCP server, not direct HTTP calls.
- **`.env` files** — nothing is stored in a local dotenv; the MCP config lives in `~/.claude.json`.

### How auth works under the hood

The hosted Airtable MCP server supports two authentication paths:

- **OAuth (primary, recommended)** — on first use, Claude Code opens a browser window, the user signs in to Airtable, and the session is stored by Claude Code. No credentials are ever pasted. This is the default path.
- **Personal Access Token (PAT, fallback)** — for users on Enterprise Airtable workspaces where an admin blocks OAuth app installs, fall back to a PAT generated at `https://airtable.com/create/tokens` with scopes: `data.records:read`, `data.records:write`, `schema.bases:read`, `schema.bases:write`. The PAT is passed in an `Authorization: Bearer <token>` header on the MCP config.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, PAT, Bearer, scope, token, tenant, MCP, endpoint, URL, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a small connection setting on your computer", "your Airtable sign-in page", or (fallback path only) "your Airtable access key".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Airtable is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Airtable MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Airtable once in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Airtable, I am going to set up the connection on your computer, then ask you to sign in to Airtable once in your browser. The whole thing takes about a minute. There is no key to copy — Airtable handles the sign-in for us. Ready?"

If the user volunteers that they are on an **Enterprise Airtable workspace** or says their workspace admin restricts apps, tell them the browser path may be blocked and that you have a quick fallback using an access key. Do not pre-empt this otherwise — for most users the browser path just works.

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the airtable MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Airtable MCP server is **hosted only** — there is no local transport option. Use this exact entry:

```json
{
  "mcpServers": {
    "airtable": {
      "url": "https://mcp.airtable.com/mcp"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the airtable entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved the connection. Now please close Claude Code completely and reopen it once, so it picks up the new setting. Let me know when you're back."

### Step 3 — Walk the user through the browser sign-in

The first time the Airtable MCP server is contacted after the restart, Claude Code will open a browser window asking the user to sign in to Airtable and approve the connection. You cannot do this for them — Airtable requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "You should now be back in a fresh Claude Code session. Say to me: **'connect to my Airtable now'**. A browser window will pop up asking you to sign in to Airtable. Tell me when you see it."

2. When they see the sign-in window → "Sign in with your Airtable email and password, then click **Allow** on the permission screen. Let me know when you're back here."
   - If the user already signed in to Airtable recently → "You may not need to type a password — Airtable might just show the **Allow** screen straight away. That's fine, just click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."

Common mistakes to look out for (and correct by re-asking):

- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Airtable account (e.g. personal vs work) → "I think you might have signed in with a different email than you meant to. In your browser, sign out of Airtable, then tell me 'try again' and I'll re-trigger the sign-in."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."
- The user reports their admin blocked the sign-in or they see an "administrator approval required" screen → switch to the **PAT fallback path** below.

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Airtable correctly."

Call `mcp__airtable__list_bases`. If it returns a result (including an empty list — that's fine), the connection works. Move to the success message, including the live count.

If the verification tool returns an error:

- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Airtable user doesn't have permission for that action. An admin on your Airtable workspace may need to adjust your access."
- `429 Rate limited` → "Airtable is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Airtable connection' and I will verify it."
- Admin approval required → switch to the PAT fallback path below.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message, and include the live base count from `list_bases` so the success feels real:

> "All done! Your Airtable is now connected — I can see **N bases**. You can ask me things like 'show me my bases', 'list the tables in my CRM base', 'show me the latest 10 records in the Leads table', or 'add a new record to the Contacts table'. Give it a try!"

---

## PAT fallback path

Use this path only when the browser sign-in is blocked — typically on **Enterprise Airtable workspaces** where an admin restricts third-party app installs, or when the user cannot complete the browser sign-in for any reason. Functionally it gives the user the same tool access as the browser path.

### Step A — Explain and open the token page

Tell the user: "No problem — we can connect it a different way using a personal access key instead. I will walk you through generating one. Ready?"

Then: "Please open this page in your browser: **https://airtable.com/create/tokens** — and sign in if needed. Let me know when you're there."

### Step B — Create the access key

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Click **Create new token**."
2. "For the name, type: **Claude Assistant**."
3. "Tick all four of these permission boxes: **data.records:read**, **data.records:write**, **schema.bases:read**, **schema.bases:write**."
4. "Under **Access**, choose which of your Airtable bases you want to connect — either 'All current and future bases in all workspaces', or pick specific ones."
5. "Click **Create token**. Airtable will show you a long value — please copy it and paste it to me. Don't worry about remembering it, I'll save it for you."

Common mistakes:

- The user pastes something very short (under 20 characters) → "That doesn't look quite right — the real value is much longer. Can you double-check and try again?"
- The user skips one of the four permissions → when verification later fails with `403`, re-ask them to generate a fresh token with all four ticked.
- The user restricts the token to a single base by mistake and then asks about another base → ask them to regenerate with the broader access they need, or list an additional base on the token.

### Step C — Save the connection with the access key

Silently write the PAT config to `~/.claude.json`, merging into the existing `mcpServers` object:

```json
{
  "mcpServers": {
    "airtable": {
      "url": "https://mcp.airtable.com/mcp",
      "headers": {
        "Authorization": "Bearer <token the user pasted>"
      }
    }
  }
}
```

Never echo the token back to the user. Never include it in any user-visible output. Never paste the contents of `~/.claude.json` to the user.

Tell the user: "I have saved your access key. Please close Claude Code completely and reopen it once, then tell me when you're back."

### Step D — Verify

When they return, run the same `mcp__airtable__list_bases` check and deliver the same success message as the browser path. If `list_bases` returns `401` on the PAT path, the most likely causes are a typo'd token or a token missing one of the four required permissions — ask the user to generate a fresh one and paste it again.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__airtable__*` MCP tools below to answer questions and make changes in Airtable. The hosted Airtable MCP server provides **13 first-party tools** covering base discovery, records, schema mutations, and connection health.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__airtable__`. If a tool name does not resolve, list available tools with the `mcp__airtable__` prefix to discover the current naming.

#### Discovery (read-only — no confirmation needed)

| Tool | Description | Use when |
|---|---|---|
| `list_bases` | List all Airtable bases the user can access | User asks "show me my bases", or you need a base ID before another call |
| `search_bases` | Search bases by name | User names a specific base and you need to locate it |
| `list_tables_for_base` | List all tables inside a base | User asks "what tables are in my CRM?" |
| `get_table_schema` | Retrieve the fields and schema of a table | Before any record write, or when the user asks "what fields does this table have?" |

#### Records

| Tool | Description | Use when |
|---|---|---|
| `list_records_for_table` | Fetch records from a table | User asks to read entries — default page size 25 |
| `display_records_for_table` | Fetch records formatted for display | When the user wants a readable table rather than raw data |
| `create_records_for_table` | Create up to 10 records in a table | User asks to add rows — **confirm first, max 10 per batch** |
| `update_records_for_table` | Update existing records in a table | User asks to change a row — **confirm first** |

#### Schema mutations (destructive — always confirm)

| Tool | Description | Use when |
|---|---|---|
| `create_table` | Create a new table in a base | User asks to add a table — **double-confirm, irreversible via this connector** |
| `create_field` | Add a new field to a table | User asks to add a column — **double-confirm, irreversible via this connector** |
| `update_table` | Rename or update a table | User asks to rename or reshape a table — **confirm first** |
| `update_field` | Update a field's definition | User asks to change a column's name or type — **confirm first** |

#### Utility

| Tool | Description | Use when |
|---|---|---|
| `ping` | Verify the MCP connection is live | Diagnostic only — use if tool calls start failing and you want to isolate whether the server is reachable |

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
| "Display the Contacts table nicely" | `display_records_for_table` |
| "Add this lead to the Leads table" | `get_table_schema` → `create_records_for_table` — **confirm first** |
| "Import these 30 contacts into Airtable" | Split into batches of 10 → loop `create_records_for_table` — **confirm first** |
| "Update the status of that lead to Qualified" | `update_records_for_table` — **confirm first** |
| "Add a new 'Phone' column to my Contacts table" | `get_table_schema` → `create_field` — **double-confirm, irreversible** |
| "Rename the 'Q1 leads' table to 'Q2 leads'" | `update_table` — **confirm first** |
| "Change the 'Status' field to a dropdown with these options" | `update_field` — **confirm first** |
| "Create a new table called 'Projects' in my Ops base" | `create_table` — **double-confirm, irreversible** |
| "Is my Airtable working?" | `ping` |

---

## Error Handling (Phase 2)

When an Airtable tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Airtable sign-in has expired — let me reconnect you." | Browser path: re-trigger Phase 1 Step 3. PAT path: ask the user to generate a fresh token and paste it. |
| 403 Forbidden | "Your Airtable user doesn't have permission for that. The base owner may need to share it with you, or an admin may need to grant access." | User talks to the base owner or workspace admin |
| 404 Not Found (base / table / record) | "I couldn't find that record — let me refresh the list." | Use `list_bases` / `list_tables_for_base` / `list_records_for_table` to refresh |
| 422 Invalid request | "Airtable rejected the change — usually a field type mismatch. Let me check the schema and try again." | Call `get_table_schema` and re-format the write |
| 429 Rate limited | "Airtable is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. Airtable's standard limit is 5 requests per second per base. |
| MCP server not running | "The Airtable connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Admin approval required (Enterprise) | "Your workspace administrator has restricted this sign-in. No problem — I can connect it using an access key instead." | Switch to the PAT fallback path above |
| Any other API error | "Something went wrong with Airtable — let me try again." | Retry once; if still failing, re-do the sign-in |

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

- **Delete** records, tables, or fields — none of the 13 tools supports deletion
- Batch-create more than 10 records in a single call (loop with batches of 10)
- Attach files to record cells via the MCP (use the Airtable UI or REST API directly)
- Access **Interfaces**, **Automations**, or **Extensions** — schema-level access only
- Manage workspace-level billing, users, or permissions
- Connect multiple Airtable accounts simultaneously — one browser session or PAT per `~/.claude.json` entry
- Bypass Enterprise admin allowlisting — if the admin blocks OAuth app installs, the PAT fallback is the only option

---

## Enterprise note — admin allowlisting can block first connect

On **Enterprise Airtable workspaces**, the workspace administrator can restrict which third-party apps are allowed to connect via OAuth. If this is enforced, the browser sign-in will show an "administrator approval required" screen or silently fail. In that case:

1. Offer the PAT fallback path — it works on Enterprise because a PAT is scoped to the user's own Airtable permissions and does not require an OAuth app install.
2. If the user wants the browser path to work long-term, their Airtable admin needs to allowlist the Airtable MCP app for the workspace. That is a one-time setup on the admin's side. Once allowlisted, other team members can connect normally via the browser.

This mirrors the same shape as the Jotform "workspace admin must install first" limitation documented in `known-issues/JOTFORM-ADMIN-ONLY.md`.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, or changing schema** — summarise what you are about to do and wait for the user's OK before calling a write tool. Schema changes (`create_table`, `create_field`, `update_table`, `update_field`) are irreversible via this connector — **double-confirm** them and repeat the exact name back before calling.
- **Discover IDs before writing** — Airtable bases, tables, fields, and records are referenced by opaque IDs (`appXXXX`, `tblXXXX`, `fldXXXX`, `recXXXX`). Always call `list_bases` → `list_tables_for_base` → `get_table_schema` once per session before any write, unless you already have the IDs from earlier in the conversation.
- **Respect the 10-record batch limit** — `create_records_for_table` accepts at most 10 records per call. For bulk imports, split into batches and pause briefly between batches (Airtable limits you to 5 requests per second per base).
- **Records often contain personal data** — leads, contacts, customer feedback. Never paste full record contents into a public log without checking with the user first. When summarising, prefer counts and a sample over full dumps.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. `display_records_for_table` is designed for this; prefer it when the user wants a readable view.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 3 bases; your CRM base has 4 tables with 1,240 records in Leads"), then offer to show details.
- **Pagination** — default to 25 records unless the user asks for more. Offer to show more if there are additional pages.
- **Schema changes are irreversible via this connector** — there are no delete tools. Once `create_table` or `create_field` fires, the only way to remove the change is via the Airtable UI.
- **Importing data is destructive if wrong** — `create_records_for_table` writes real rows. For bulk imports, show the user a sample of the first row before proceeding with the rest.
- **Respect read-only Airtable roles** — if the user's Airtable role is viewer/commenter only, write tools will return `403 Forbidden`. Do not retry — fall back to read-only operations and let the user know which tools are unavailable for their role.
- **Never log or echo credentials** — on the PAT path, never echo the access key back. On the browser path, there is no user-visible token, but never paste the contents of `~/.claude.json` to the user either.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Airtable auth or API errors
- **jotform-connector**: Sibling hosted-OAuth MCP connector — same ≤4-step install pattern, URL-only config
- **notion-connector**: Sibling workspace/data connector — similar conversational install
- **monday-connector**: Sibling project/data connector — similar conversational install
- **n8n-workflow-patterns**: Build Airtable-triggered automations once the connector is live
