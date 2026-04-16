---
name: monday-connector
description: "Connect and operate monday.com via the official @mondaydotcomorg/monday-api-mcp server. Use this skill when the user asks to set up monday.com, connect their account, or interact with boards, items, groups, columns, updates, users, teams, or WorkForms. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__monday__*, Bash, Read, Write, Edit
metadata:
  category: Project Management
  tags:
    - monday
    - monday.com
    - project-management
    - boards
    - items
    - tasks
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Draft updates or comments on monday.com items
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by monday.com events (item created, status changed, etc.)
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting monday.com auth or API errors
---

# monday.com Connector

## Overview

This skill lets you read and update a user's monday.com account on their behalf using the **official first-party `@mondaydotcomorg/monday-api-mcp`** server (from [mondaycom/mcp](https://github.com/mondaycom/mcp)). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤5 steps). The user has never used this before. You walk them through minting a Personal API Token inside monday.com, collecting it, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", or any file paths. They should feel like they are having a conversation, and at the end their monday.com is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__monday__*` native tools to read and update monday.com data.

**Which phase to run** — Before any tool call, check whether the monday.com MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.monday` entry. If it exists and has a `MONDAY_TOKEN` in its `env` block, treat the connector as authenticated and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **OAuth / Client ID / Client Secret / Redirect URI** — monday.com Personal API Tokens are a simple long-lived bearer. No OAuth dance needed for personal use.
- **The monday.com Apps Framework** (`@mondaydotcomorg/apps-cli`) — that is for building marketplace apps. Wrong audience for a connector skill. Do not install it.
- **Curl-based GraphQL wrappers** — all reads and writes go through the MCP server, not direct HTTP calls.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, GraphQL, or environment variable. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your monday.com is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤5 steps)

This phase gets the Personal API Token minted, the token collected, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only provides information and clicks things in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your monday.com, I need you to grab a free connection key from inside your monday.com account. This takes about two minutes. I will tell you exactly what to click, one step at a time."

### Step 2 — Walk the user through minting a Personal API Token

The user needs to copy a Personal API Token from monday.com. You cannot do this step for them — monday.com requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please open monday.com in your browser and sign in. Let me know when you are signed in."

2. When they confirm → "Click your **profile picture** in the bottom-left corner of the screen. A menu will pop up. Let me know when you see it."

3. When they see the menu → "Click **Developers**. A new page will open with a few options. Tell me when you're there."
   - If the user says they can't see "Developers" → "No problem. In the same menu, look for **Administration** first, then click **Connections** → **API**. Let me know what you see."

4. When they're on the Developers page → "On the left side, click **My Access Tokens**. You will see a long key. Please copy it and paste it to me."
   - If they don't see one → "Click the **Show** button (or **Generate**) to reveal it, then copy it."

Common mistakes to look out for (and correct by re-asking):
- The user pasted a placeholder like `your_token_here` → ask again: "I think that was a copy mistake — please try the real value. It's a long string of letters and numbers."
- The user pasted something clearly too short (under 40 characters) → "That doesn't look like the full key. Can you go back and copy it all? It's quite long."
- The user says they can't find **Developers** in the profile menu → "No problem — I'll send you a direct link to the Developers page." Then provide a clickable link rather than a raw path.

### Step 3 — Save the connection

Once the user pastes the Personal API Token, silently add or update the monday MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

**Pick one of two transports.** Default to **Local (npx)** unless the user has had trouble with Node.js or has specifically asked for the hosted option.

**Option A — Local (default)** — runs the MCP server on the user's machine via `npx`. Requires Node.js 20+.

```json
{
  "mcpServers": {
    "monday": {
      "command": "npx",
      "args": ["-y", "@mondaydotcomorg/monday-api-mcp@latest"],
      "env": {
        "MONDAY_TOKEN": "<token from Step 2>"
      }
    }
  }
}
```

**Option B — Hosted** — monday.com's first-party hosted MCP endpoint. No Node.js required, more reliable for non-technical users. Use this as a fallback if the user hits `npx` or Node.js errors, or simply prefers not to run anything locally.

```json
{
  "mcpServers": {
    "monday": {
      "url": "https://mcp.monday.com/mcp",
      "headers": {
        "Authorization": "Bearer <token from Step 2>"
      }
    }
  }
}
```

Merge your chosen option into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the monday entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

**Optional flags** (Local transport only — hosted doesn't accept CLI flags):
- `"--read-only"` — locks the connector to read-only operations. Recommended for first-time users or shared machines.
- `"--enable-dynamic-api-tools", "true"` — exposes the full monday.com GraphQL surface (listing boards/workspaces, reading `me`, etc.). Enable this when the user wants anything beyond the 14 typed tools.

> ⚠️ **`--read-only` and `--enable-dynamic-api-tools` are mutually exclusive.** Dynamic API Tools require full API access and will not work in read-only mode. Pick one or the other — never both. If the user asks for both, pick read-only and tell them they can re-enable Dynamic Tools later when they're comfortable with write access.

Never echo the access token back to the user after writing it. Never include it in any output visible to the user.

Tell the user: "I have saved your connection details. Let me verify everything is working."

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to monday.com correctly."

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__monday__*` tools are available** (the MCP server was already running or has reloaded): call `mcp__monday__list_users_and_teams` (or, if Dynamic API Tools are enabled, run `all_monday_api` with `query { me { id name email } }`). If it returns the user's name, capture it and move to Step 5.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my monday connection' and I will verify it."

If the verification tool returns an error:
- `401 Unauthorized` or `Invalid token` → "The connection key didn't work. Could you double-check it in monday.com? Go back to the Developers page and copy the token again." Then re-do Step 3 with the new token.
- `403 Forbidden` → "Your connection is working, but your user doesn't have permission for that action inside monday.com. An admin may need to adjust your access."
- `ComplexityException` → Rare on verification, but if it happens just retry once with a smaller query.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-check their token is active.

### Step 5 — Success message

Tell the user, in one short message:

> "All done! I am now connected to your monday.com account as **[user name if available]**. You can ask me things like 'show me my boards' or 'create an item on the Sales board'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__monday__*` MCP tools below to answer questions and make changes in monday.com. The `@mondaydotcomorg/monday-api-mcp` server provides **14 typed tools** covering the most common operations, plus **3 optional Dynamic API Tools** (enabled via `--enable-dynamic-api-tools true`) for arbitrary GraphQL.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__monday__`. Verified against [mondaycom/mcp](https://github.com/mondaycom/mcp).

#### Items (tasks / rows)

| Tool | Description | Use when |
|---|---|---|
| `create_item` | Create a new item on a board | User asks to add a task, row, lead, or ticket — **confirm first** |
| `delete_item` | Delete an item permanently | User asks to delete — **confirm first, warn irreversible** |
| `get_board_items_by_name` | Search items on a board by name/term | User asks to find a specific item |
| `change_item_column_values` | Update one or more column values on an item | User asks to change a status, set a date, assign a person, etc. — **confirm first** |
| `move_item_to_group` | Move an item between groups on the same board | User asks to move a task to a different section — **confirm first** |
| `create_update` | Post an update (comment) on an item | User asks to add a comment or note — **confirm first** |

#### Boards & Structure

| Tool | Description | Use when |
|---|---|---|
| `create_board` | Create a new board | User asks to start a new project/pipeline — **confirm first** |
| `get_board_schema` | Retrieve a board's groups, columns, and their IDs | **Always call this before `create_item` or `change_item_column_values`** — columns are referenced by opaque IDs, not labels |
| `create_group` | Add a group (section) to a board | User asks to add a new section/category — **confirm first** |
| `create_column` | Add a column to a board | User asks to track a new field — **confirm first** |
| `delete_column` | Remove a column from a board | User asks to remove a field — **confirm first, warn data loss** |

#### Account

| Tool | Description | Use when |
|---|---|---|
| `list_users_and_teams` | Retrieve users and teams in the account | User asks "who's on my team?" or you need a user ID for a person column |

#### WorkForms

| Tool | Description | Use when |
|---|---|---|
| `create_form` | Build a new monday WorkForm | User asks to create an intake form |
| `get_form` | Retrieve a form by token | User asks about an existing form |

#### Dynamic API Tools (beta, opt-in)

Enable with `--enable-dynamic-api-tools true` in the server args. These unlock the full monday.com GraphQL API.

| Tool | Description | Use when |
|---|---|---|
| `all_monday_api` | Execute an arbitrary GraphQL query or mutation | Anything not covered by the typed tools above — listing boards, reading `me`, fetching update history, archiving items, duplicating boards, managing docs |
| `get_graphql_schema` | Fetch the full GraphQL schema | You need to discover available queries/mutations |
| `get_type_details` | Get details on a specific GraphQL type | You know the type name and need its fields |

**Dynamic tool workflow:**
1. Call `get_graphql_schema` once (or `get_type_details` on a known type) to find the right query shape.
2. Call `all_monday_api` with the composed query.

**Example — list boards (no typed tool exists):**
```graphql
query { boards(limit: 50) { id name state workspace { id name } } }
```
Run via `all_monday_api`.

> **Note:** Tool names are from `@mondaydotcomorg/monday-api-mcp` (latest). If a tool name does not resolve, try listing available tools with the `mcp__monday__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my monday.com" / "Help me set up monday" | **Run Phase 1** |
| "Who am I connected as?" | `all_monday_api` (`query { me { id name email } }`) — requires Dynamic Tools |
| "List my boards" | `all_monday_api` (`query { boards { id name } }`) — requires Dynamic Tools |
| "What's on the Sales board?" | `get_board_schema` → `all_monday_api` items query |
| "Find the task called 'Q2 planning'" | `get_board_items_by_name` |
| "Create an item on the Roadmap board" | `get_board_schema` → `create_item` — **confirm first** |
| "Move item 12345 to Done" | `get_board_schema` (find status column ID) → `change_item_column_values` — **confirm first** |
| "Assign this task to Jane" | `list_users_and_teams` → `change_item_column_values` (person column) — **confirm first** |
| "Move this task to the 'In Review' group" | `move_item_to_group` — **confirm first** |
| "Comment 'shipped' on item 12345" | `create_update` — **confirm first** |
| "Create a new project board" | `create_board` — **confirm first** |
| "Add a 'Due date' column to this board" | `create_column` — **confirm first** |
| "Who's on my team?" | `list_users_and_teams` |
| "Delete item 12345" | `delete_item` — **confirm first, warn irreversible** |

---

## Error Handling (Phase 2)

When a monday.com tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your monday.com connection has expired or the key was revoked — let me help you reconnect." | Run Phase 1 from Step 2 (mint a fresh Personal API Token) |
| 403 Forbidden | "Your monday.com user doesn't have permission for that board or item. An admin may need to grant access." | User talks to their workspace admin; nothing to fix in the connector |
| 404 Not Found (board/item) | "I couldn't find that record — let me search for it." | Use `get_board_items_by_name` or the Dynamic boards query to help find it |
| `ComplexityException` | "The query is too heavy for monday.com — I'll simplify and retry." | Reduce `limit`, fetch fewer columns, split into two calls |
| 429 Rate limited | "monday.com is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once |
| "Column does not exist" | "That column isn't on the board anymore — let me refresh the structure." | Re-call `get_board_schema` to pick up the current column IDs |
| MCP server not running | "The monday.com connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with monday.com — let me try again." | Retry once; if still failing, check token validity |

---

## Scope Limitations

The monday.com MCP connector **can** do (via `@mondaydotcomorg/monday-api-mcp`):
- Create, update, move, and delete items (tasks / rows)
- Post updates (comments) on items
- Search items on a board by name
- Create boards, groups, and columns; delete columns
- Read board structure (groups, columns, IDs) via `get_board_schema`
- List users and teams
- Create and retrieve WorkForms
- Execute arbitrary GraphQL queries/mutations (with Dynamic API Tools enabled) — unlocks workspaces, docs, archive/duplicate, update history, webhooks, and everything else in the monday.com API

The monday.com MCP connector **cannot** do (needs the monday.com UI):
- Build or edit visual automations (recipe builder)
- Edit dashboards and widgets
- Configure OAuth integrations (Slack, Gmail, etc.)
- Manage account-level billing/admin settings
- Act across multiple monday.com accounts simultaneously (one token per `~/.claude.json` entry)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, moving, or deleting** items, boards, groups, or columns — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover column IDs before writing** — monday.com columns are referenced by opaque IDs (like `status_1`, `date4`), not labels. Always call `get_board_schema` once per board before any `create_item` / `change_item_column_values`.
- **IDs are numeric strings** — board and item IDs are long numeric strings. Always confirm them back before a mutation.
- **Delete is permanent** — `delete_item` and `delete_column` cannot be undone. Always warn the user, and prefer leaving items in an "Archive" group or adding a status of "Archived" unless the user explicitly says "delete permanently".
- **Present data clearly** — format results as readable tables or summaries, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 42 items in 'Working on it'"), then offer to show details.
- **Pagination** — default to 25 items unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the complexity budget** — monday.com GraphQL has a per-query complexity cap. Prefer narrow queries (specific boards, limited page size) over "fetch everything". If you hit a `ComplexityException`, split the call or shrink `limit`.
- **Person columns need user IDs** — to assign a task, first call `list_users_and_teams` to find the correct ID, then pass it to `change_item_column_values`.
- **Status columns use label indexes or text** — check the format returned by `get_board_schema` for the specific column before setting values.
- **Never log or echo credentials** — the `MONDAY_TOKEN` must never appear in any output visible to the user.
- **Read-only mode exists** — if the user is nervous about write access, suggest they re-run Phase 1 with the `--read-only` flag.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting monday.com auth or API errors
- **hubspot-connector**: Sibling CRM connector — same MCP bootstrap pattern for a different platform
- **notion-connector**: Sibling project/knowledge connector — similar workspace model
- **n8n-workflow-patterns**: Build monday.com-triggered automations once the connector is live
