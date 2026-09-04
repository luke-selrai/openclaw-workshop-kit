---
name: monday-connector
description: "Connect monday.com to Claude by switching on its built-in connector, or by registering monday.com's official server locally. Use when the user asks to set up or connect monday.com, or wants monday work (boards, items, columns, updates, users, teams, WorkForms) and monday.com isn't connected yet. Once connected, monday.com runs through the mcp__claude_ai_monday_com__* or mcp__monday__* tools."
allowed-tools: mcp__claude_ai_monday_com__*, mcp__monday__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
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

> **Install pattern:** Hosted-bearer-PAT - this SKILL is the canonical reference. See [skills/CLAUDE.md](../CLAUDE.md) for the cross-pattern overview.

## Overview

This skill lets you read and update a user's monday.com account on their behalf using the **official first-party `@mondaydotcomorg/monday-api-mcp`** server (from [mondaycom/mcp](https://github.com/mondaycom/mcp)).

**There are two ways in, and they reach the same official server.** Claude's own connector directory ships a built-in **monday.com** connector running monday's own server, so its everyday surface - searching boards, creating and updating items and columns, assigning owners, setting timelines, posting updates - matches the kit's. Switching it on is one button and a sign-in, once per Claude account, with no local install and no connection key on the machine, so it is the default route. Two things gate it on monday's side: the account needs a **Pro, Max, Team or Enterprise** monday plan, and a monday administrator has to approve the connector. The kit's own route (Phase 1-alt) stays in full for the cases the built-in cannot serve. Both can coexist on one machine; never tear one down to set the other up.

**The one known gap: listing boards.** monday has no typed "list my boards" tool - that query rides the opt-in Dynamic API Tools (see Phase 2). The kit's route turns those on with a flag. If a generic *"show me my boards"* fails through the built-in, that is the signal to use Phase 1-alt for this user; everything else stays on the built-in.

The skill has these phases:

- **Phase 0 - Is monday.com already connected?** Checks the built-in connector first, then the kit's own registration, and routes.
- **Phase 1 - Switch on the built-in monday.com connector (the default route).** Open monday.com's connector page in the user's own browser, they press **Connect to Claude** and sign in, then verify and prove with one read.
- **Phase 1-alt - The kit's own route (only when the built-in can't be used).** An autonomous bootstrap. Claude opens monday.com in a Playwright-driven browser, waits for the user to sign in, navigates to the Personal API Token page, mints/reveals the token, reads it directly from the DOM, writes the MCP config, and verifies - without ever asking the user to copy, paste, or navigate menus themselves. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", or any file paths. They feel like they are having a conversation; their only action is logging in to monday.com once.
- **Phase 2 - Use Tools.** Once monday.com is connected by either route, you call its native tools to read and update monday.com data - `mcp__claude_ai_monday_com__*` on the built-in route, `mcp__monday__*` on the kit's.

**Which phase to run** - always start at Phase 0. On the kit's own route the resume signal is unchanged: read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.monday` entry. If it exists and has a `MONDAY_TOKEN` in its `env` block, treat the kit's connector as authenticated and skip to Phase 2.

### What this skill does NOT use

- **OAuth / Client ID / Client Secret / Redirect URI** - monday.com Personal API Tokens are a simple long-lived bearer. No OAuth dance needed for personal use.
- **The monday.com Apps Framework** (`@mondaydotcomorg/apps-cli`) - that is for building marketplace apps. Wrong audience for a connector skill. Do not install it.
- **Curl-based GraphQL wrappers** - all reads and writes go through the MCP server, not direct HTTP calls.

---

## Communication rules for Phase 1 and Phase 1-alt

These rules apply to **both** connect routes. On Phase 1 (the built-in connector) the user presses one button in their own browser and signs in; on Phase 1-alt the browser window is one Claude drives. Either way the user is a non-technical business owner - Claude does the work, the user only signs in when prompted. Every message you send while connecting must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, GraphQL, Playwright, browser automation, or environment variable. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening monday.com for you now"), once when you need them ("please sign in"), once when you're done ("your monday.com is connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your monday.com is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message while connecting (Phase 1 or Phase 1-alt).
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0 - Is monday.com already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** Run `claude mcp list` and look for the line `claude.ai monday.com` (the directory display name is "monday.com", all lower case, so the tools are `mcp__claude_ai_monday_com__*`; there is no `--json` flag).
   - `✔ Connected` → skip to **Phase 2**. Prove it first with one read through the built-in - retrieve the users and teams on the account - before saying so.
   - `! Needs authentication` → the connection is on the account but its sign-in has lapsed. Open `https://claude.ai/customize/connectors` in the user's own browser and say: *"Your monday.com connection needs a quick re-sign-in. Press **Reconnect** next to monday.com, sign in, and tell me when it says Connected."* Then re-run this check.
   - No such line → continue to step 2.
2. **The kit's own route.** Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.monday` entry with a `MONDAY_TOKEN` in its `env` block. If it is present and a smoke call works, keep using it - say *"monday.com is already connected"* and skip to **Phase 2**. Do not set the built-in up on top of a working connection.
3. **Nothing found** → go to **Phase 1**.

**Precedence note.** A monday server registered locally takes precedence over the built-in one and hides it (`/mcp` shows the built-in as hidden). If a machine carries an `mcpServers.monday` entry from an earlier run of the kit's route and it works, leave it and say so. Only remove it - and only with the user's explicit OK - if it is broken and the built-in is the better route.

**No shell?** If you cannot run commands at all (this is claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2 entirely: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of monday.com's tools.

**Tooling check (silent, needed for Phase 1-alt only).** Verify the `claude` command is on PATH (`claude --version`) and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). Phase 1 needs neither.

---

## Phase 1 - Switch on the built-in monday.com connector (the default route)

Claude's connector directory carries a **monday.com** connector running monday's own official server, so the everyday surface matches the kit's route. This is a one-time, once-per-account job: connect it once on the user's Claude account and it is available everywhere that account is signed in, including here. The only thing the user does is press one button and sign in. Nothing on this route mints, captures, stores, or echoes a connection key - there is no key.

**Before you start, two monday-side gates.** The account needs a **Pro, Max, Team or Enterprise** monday plan, and a monday administrator has to approve the connector for the account. If the user is on a Basic or free plan, or their admin declines, Phase 1 cannot complete - say so plainly and offer Phase 1-alt, which works off a personal access key instead.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set in the environment, built-in connectors will not appear in this session. Tell the user in one line that this copy of Claude is signed in a different way, then run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.** Say:

> "I'm opening monday.com's page in your browser. Press **Connect to Claude**, sign in to monday.com the way you normally do, and say yes when it asks for access. That's the only part only you can do, tell me when it says Connected."

Then open `https://claude.ai/directory/monday` (the public mirror of the same page is `https://claude.com/connectors/monday`) in the user's **own** everyday browser: `open <url>` on Mac, `xdg-open <url>` on Linux, `start "" <url>` on Windows. That is where they are already signed in. If the page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: **Browse**, search "monday", **Connect**.

> **Why the user's own browser here.** Phase 1-alt's rule (never use the user's own browser) exists because that route reads a connection key off the page in a browser Claude drives. This route reads nothing and handles no key, so the user's own browser is the correct place for the button press. Do not drive this sign-in with the automated browser.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a picture of the sign-in screen. If the connect stalls waiting on a monday administrator's approval, say so plainly and stop.

**Step 4 - Verify.** Run `claude mcp list` again. A line reading `claude.ai monday.com … ✔ Connected` is the pass.
- Not there yet → no restart will change this answer: `claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes. Read on:
- `! Needs authentication` means the sign-in lapsed: send them to `https://claude.ai/customize/connectors` and have them press **Reconnect** next to monday.com.
- Still no line at all means the Connect didn't complete, so send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector, retrieving the users and teams on the account. Only a real answer counts (an empty list is a real answer; a tool error is not "connected"). The built-in's tools are often deferred in a session, so list the `mcp__claude_ai_monday_com__*` tools actually available and pick a safe read rather than hard-coding a name. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app, connectors added during a session are documented to appear without a restart; if one doesn't, start a new session there.

**Step 5b - Probe the boards gap once.** Ask the built-in for a generic list of the user's boards. If it answers, nothing more is needed. If it cannot (no typed board-listing tool and no Dynamic API Tools behind it), note it silently: everyday item and column work stays on the built-in, and *"show me all my boards"* is the one request that needs **Phase 1-alt**. Do not run Phase 1-alt on the spot; offer it only if the user actually asks for that kind of listing.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now, for example *"add a task to the Sales board"*, *"what's the status of the launch item?"*, *"who's on my team?"*.

**Team or Enterprise Claude accounts.** If the page shows **Request** instead of **Connect**, the user's Claude administrator has to switch monday.com on for the organisation first, and connectors only work in private projects there. Say so plainly and stop. Do not fall back to the kit's route just to get past an admin gate.

**Plan note.** Assume a paid Claude plan for built-in connectors. Free accounts are limited to a single custom connector, which is not this route.

---

## Phase 1-alt - The kit's own route (only when the built-in can't be used)

Run this **instead of** Phase 1 in these cases:

- Phase 1 Step 1 failed, meaning this copy of Claude is signed in a way that cannot see built-in connectors.
- The monday.com connector is not listed on the user's Claude account (no directory listing, and nothing under **Browse**), or the account is on a monday plan below Pro, or the monday administrator will not approve it.
- The user needs generic board listing (the gap at Step 5b), which rides the Dynamic API Tools this route can switch on.
- The user explicitly asks for the locally installed server.

Otherwise Phase 1 is the route: it reaches monday's own server with none of this setup, and there is no reason to burden the user with it. Both routes can live on one machine, so never tear one down to set the other up.

Everything below is the kit's original install, autonomous via Playwright.

Claude drives the user's browser end-to-end via Playwright MCP. The user's only role is to sign in to monday.com when prompted (and approve 2FA if their account requires it). Claude handles every other step - navigation, token reveal, capture, config write, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the token control"). Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_evaluate` / `browser_navigate`. Do not hardcode CSS selectors - monday.com's UI changes. Re-snapshot whenever the page state changes.

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your monday.com now. I'm opening a browser window for you - please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 - Open monday.com and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://monday.com" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see a workspace shell - sidebar, board list, profile avatar, or workspace switcher) → continue to Step 3.
- **Not logged in** (sign-in form, marketing landing page, "Get started" CTA) → tell the user *once*: *"The browser window is open - please sign in to monday.com when you're ready."* Then poll silently: call `mcp__playwright__browser_wait_for({ text: "Boards" })` (or wait for any post-login shell element from the snapshot - workspace switcher, "Inbox", "My work", etc.) with a generous timeout. Do **not** ask the user to confirm when they're done - detect the logged-in shell from the snapshot yourself. 2FA, password resets, and SSO redirects will all resolve to the same workspace shell.

If `browser_wait_for` times out (5+ minutes), then - and only then - check in with the user: *"Still on the sign-in page? Anything I can help with?"*

If after login the snapshot still looks like a marketing page, navigate explicitly to `https://auth.monday.com/auth/login_redirect` and re-snapshot.

### Step 3 - Capture the user's monday workspace subdomain

Once logged in, the URL will be `https://<workspace>.monday.com/...`. Read it via:

```
mcp__playwright__browser_evaluate({ function: "() => window.location.host" })
```

The host returns `<workspace>.monday.com` - save the `<workspace>` slug for the next step. If the host is bare `monday.com` (still on the marketing/redirect page), click any board or workspace tile from the snapshot to enter the workspace, then re-read the host.

### Step 4 - Open the Personal API Token page and capture the token

Navigate directly: `mcp__playwright__browser_navigate({ url: "https://<workspace>.monday.com/admin/integrations/api" })`. This is the deep-link path and is more reliable than walking the profile menu.

Take a snapshot. The page will show the Personal API Token in one of these states:

- **Already revealed** - a long string is visible in a textarea or code block. Read it directly with `browser_evaluate` (e.g., `() => document.querySelector('textarea, code, [data-testid*="token"]')?.textContent?.trim()` - adapt the selector based on what the snapshot shows).
- **Masked behind a Show / Reveal / Copy button** - click the button via `browser_click`, re-snapshot, then read.
- **No token yet** - click the **Generate** / **Create new token** button, re-snapshot, then read.

A valid Personal API Token is a JWT-style string: ~200+ characters, three base64url segments separated by two `.` separators. Validate locally before saving - if the captured string is shorter than 40 chars or doesn't match the JWT shape, re-snapshot and try again.

If two snapshot attempts don't yield a valid token, stop and tell the user: *"I'm having trouble finding the connection key on the page - could you tell me what's on screen?"* Use their description to locate the right control.

### Step 5 - Save the connection (silent)

Silently register the MCP server. **Prefer `claude mcp add` via Bash** - it's the official CLI path, handles JSON merging correctly, and avoids touching `~/.claude.json` directly.

**Pick one of two transports.** Default to **Local (npx)** unless the user has had trouble with Node.js or has specifically asked for the hosted option.

**Option A - Local (default)** - runs the MCP server on the user's machine via `npx`. Requires Node.js 20+.

```bash
claude mcp add monday \
  --scope user \
  --env MONDAY_TOKEN="<token captured in Step 4>" \
  -- npx -y @mondaydotcomorg/monday-api-mcp@latest
```

**Option B - Hosted** - monday.com's first-party hosted MCP endpoint. No Node.js required, more reliable for non-technical users. Use this as a fallback if the user hits `npx` or Node.js errors, or simply prefers not to run anything locally.

```bash
claude mcp add monday \
  --scope user \
  --transport http \
  --header "Authorization: Bearer <token captured in Step 4>" \
  -- https://mcp.monday.com/mcp
```

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) - write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) using the equivalent JSON shape:

<details>
<summary>Direct JSON write - Local</summary>

```json
{
  "mcpServers": {
    "monday": {
      "command": "npx",
      "args": ["-y", "@mondaydotcomorg/monday-api-mcp@latest"],
      "env": { "MONDAY_TOKEN": "<token>" }
    }
  }
}
```
</details>

<details>
<summary>Direct JSON write - Hosted</summary>

```json
{
  "mcpServers": {
    "monday": {
      "url": "https://mcp.monday.com/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object - never overwrite. If `~/.claude.json` doesn't exist, create it. If it's corrupt, back up to `~/.claude.json.backup` first.

**Optional flags** (Local transport only - hosted doesn't accept CLI flags):
- `"--read-only"` - locks the connector to read-only operations. Recommended for first-time users or shared machines.
- `"--enable-dynamic-api-tools", "true"` - exposes the full monday.com GraphQL surface (listing boards/workspaces, reading `me`, etc.). Enable this when the user wants anything beyond the 14 typed tools.

> ⚠️ **`--read-only` and `--enable-dynamic-api-tools` are mutually exclusive.** Dynamic API Tools require full API access and will not work in read-only mode. Pick one or the other - never both. If the user asks for both, pick read-only and tell them they can re-enable Dynamic Tools later when they're comfortable with write access.

Never echo the access token back to the user. Never include it in any output visible to the user. Never log it to the conversation, even truncated.

### Step 6 - Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"I've saved your connection - let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__monday__*` tools are available** (the MCP server was already running or has reloaded): call `mcp__monday__list_users_and_teams` (or, if Dynamic API Tools are enabled, run `all_monday_api` with `query { me { id name email } }`). If it returns the user's name, capture it and move to Step 7.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user *"All saved. Please restart Claude Code once so the connection becomes active, then say 'test my monday connection' and I'll verify it."*

If the verification tool returns an error:
- `401 Unauthorized` or `Invalid token` → "The connection key didn't take - let me grab a fresh one." Re-run Steps 2-5 to mint a new token and overwrite the config.
- `403 Forbidden` → "Your connection is working, but your monday.com user doesn't have permission for that action. An admin may need to adjust your access."
- `ComplexityException` → Rare on verification; retry once with a smaller query.
- Any other error → "Something went wrong - let me try again." Retry once; if still failing, re-run Steps 2-5.

### Step 7 - Success message

Tell the user, in one short message:

> "All done! I'm now connected to your monday.com account as **[user name if available]**. You can ask me things like 'show me my boards' or 'create an item on the Sales board'. Give it a try!"

---

## PHASE 2 - Use Tools

> **Which prefix you get.** Through the built-in connector (Phase 1) the tools are `mcp__claude_ai_monday_com__*`; through the kit's own route (Phase 1-alt) they are `mcp__monday__*`. Both routes reach monday's own official server, so the typed tools in the tables below apply to both and only the prefix differs. The one material difference is the **Dynamic API Tools** section at the end: those are the kit's opt-in flag, so generic board listing may be missing on the built-in. List the tools present in the session and use the prefix that is actually there; never mix the two prefixes in one session.

Once the connector is configured, use the monday.com MCP tools below to answer questions and make changes in monday.com. The `@mondaydotcomorg/monday-api-mcp` server provides **14 typed tools** covering the most common operations, plus **3 optional Dynamic API Tools** (enabled via `--enable-dynamic-api-tools true`) for arbitrary GraphQL.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__monday__`. Verified against [mondaycom/mcp](https://github.com/mondaycom/mcp).

#### Items (tasks / rows)

| Tool | Description | Use when |
|---|---|---|
| `create_item` | Create a new item on a board | User asks to add a task, row, lead, or ticket - **confirm first** |
| `delete_item` | Delete an item permanently | User asks to delete - **confirm first, warn irreversible** |
| `get_board_items_by_name` | Search items on a board by name/term | User asks to find a specific item |
| `change_item_column_values` | Update one or more column values on an item | User asks to change a status, set a date, assign a person, etc. - **confirm first** |
| `move_item_to_group` | Move an item between groups on the same board | User asks to move a task to a different section - **confirm first** |
| `create_update` | Post an update (comment) on an item | User asks to add a comment or note - **confirm first** |

#### Boards & Structure

| Tool | Description | Use when |
|---|---|---|
| `create_board` | Create a new board | User asks to start a new project/pipeline - **confirm first** |
| `get_board_schema` | Retrieve a board's groups, columns, and their IDs | **Always call this before `create_item` or `change_item_column_values`** - columns are referenced by opaque IDs, not labels |
| `create_group` | Add a group (section) to a board | User asks to add a new section/category - **confirm first** |
| `create_column` | Add a column to a board | User asks to track a new field - **confirm first** |
| `delete_column` | Remove a column from a board | User asks to remove a field - **confirm first, warn data loss** |

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
| `all_monday_api` | Execute an arbitrary GraphQL query or mutation | Anything not covered by the typed tools above - listing boards, reading `me`, fetching update history, archiving items, duplicating boards, managing docs |
| `get_graphql_schema` | Fetch the full GraphQL schema | You need to discover available queries/mutations |
| `get_type_details` | Get details on a specific GraphQL type | You know the type name and need its fields |

**Dynamic tool workflow:**
1. Call `get_graphql_schema` once (or `get_type_details` on a known type) to find the right query shape.
2. Call `all_monday_api` with the composed query.

**Example - list boards (no typed tool exists):**
```graphql
query { boards(limit: 50) { id name state workspace { id name } } }
```
Run via `all_monday_api`.

> **Note:** Tool names are from `@mondaydotcomorg/monday-api-mcp` (latest). If a tool name does not resolve, try listing available tools with the `mcp__monday__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my monday.com" / "Help me set up monday" | **Run Phase 0, then Phase 1** (Phase 1-alt only if Phase 1 is unavailable) |
| "Who am I connected as?" | `all_monday_api` (`query { me { id name email } }`) - requires Dynamic Tools |
| "List my boards" | `all_monday_api` (`query { boards { id name } }`) - requires Dynamic Tools |
| "What's on the Sales board?" | `get_board_schema` → `all_monday_api` items query |
| "Find the task called 'Q2 planning'" | `get_board_items_by_name` |
| "Create an item on the Roadmap board" | `get_board_schema` → `create_item` - **confirm first** |
| "Move item 12345 to Done" | `get_board_schema` (find status column ID) → `change_item_column_values` - **confirm first** |
| "Assign this task to Jane" | `list_users_and_teams` → `change_item_column_values` (person column) - **confirm first** |
| "Move this task to the 'In Review' group" | `move_item_to_group` - **confirm first** |
| "Comment 'shipped' on item 12345" | `create_update` - **confirm first** |
| "Create a new project board" | `create_board` - **confirm first** |
| "Add a 'Due date' column to this board" | `create_column` - **confirm first** |
| "Who's on my team?" | `list_users_and_teams` |
| "Delete item 12345" | `delete_item` - **confirm first, warn irreversible** |

---

## Error Handling (Phase 2)

When a monday.com tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your monday.com connection has expired or the key was revoked - let me help you reconnect." | Built-in route: press **Reconnect** next to monday.com at `https://claude.ai/customize/connectors`. Kit's route: run Phase 1-alt from Step 2 (mint a fresh Personal API Token) |
| 403 Forbidden | "Your monday.com user doesn't have permission for that board or item. An admin may need to grant access." | User talks to their workspace admin; nothing to fix in the connector |
| 404 Not Found (board/item) | "I couldn't find that record - let me search for it." | Use `get_board_items_by_name` or the Dynamic boards query to help find it |
| `ComplexityException` | "The query is too heavy for monday.com - I'll simplify and retry." | Reduce `limit`, fetch fewer columns, split into two calls |
| 429 Rate limited | "monday.com is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once |
| "Column does not exist" | "That column isn't on the board anymore - let me refresh the structure." | Re-call `get_board_schema` to pick up the current column IDs |
| MCP server not running | "The monday.com connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with monday.com - let me try again." | Retry once; if still failing, check token validity |

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
- Execute arbitrary GraphQL queries/mutations (with Dynamic API Tools enabled) - unlocks workspaces, docs, archive/duplicate, update history, webhooks, and everything else in the monday.com API

The monday.com MCP connector **cannot** do (needs the monday.com UI):
- Build or edit visual automations (recipe builder)
- Edit dashboards and widgets
- Configure OAuth integrations (Slack, Gmail, etc.)
- Manage account-level billing/admin settings
- Act across multiple monday.com accounts simultaneously (one token per `~/.claude.json` entry)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, moving, or deleting** items, boards, groups, or columns - summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover column IDs before writing** - monday.com columns are referenced by opaque IDs (like `status_1`, `date4`), not labels. Always call `get_board_schema` once per board before any `create_item` / `change_item_column_values`.
- **IDs are numeric strings** - board and item IDs are long numeric strings. Always confirm them back before a mutation.
- **Delete is permanent** - `delete_item` and `delete_column` cannot be undone. Always warn the user, and prefer leaving items in an "Archive" group or adding a status of "Archived" unless the user explicitly says "delete permanently".
- **Present data clearly** - format results as readable tables or summaries, not raw JSON.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 42 items in 'Working on it'"), then offer to show details.
- **Pagination** - default to 25 items unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the complexity budget** - monday.com GraphQL has a per-query complexity cap. Prefer narrow queries (specific boards, limited page size) over "fetch everything". If you hit a `ComplexityException`, split the call or shrink `limit`.
- **Person columns need user IDs** - to assign a task, first call `list_users_and_teams` to find the correct ID, then pass it to `change_item_column_values`.
- **Status columns use label indexes or text** - check the format returned by `get_board_schema` for the specific column before setting values.
- **Never log or echo credentials** - the `MONDAY_TOKEN` must never appear in any output visible to the user.
- **Read-only mode exists** - if the user is nervous about write access, suggest they re-run Phase 1-alt with the `--read-only` flag. The built-in connector has no read-only switch, so that request is a reason to use the kit's route.

---

## Related Skills

- **orientation**: The source pattern for conversational bootstrap; Phase 1 and Phase 1-alt above follow the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting monday.com auth or API errors
- **hubspot-connector**: Sibling CRM connector - same MCP bootstrap pattern for a different platform
- **notion-connector**: Sibling project/knowledge connector - similar workspace model
- **n8n-workflow-patterns**: Build monday.com-triggered automations once the connector is live
