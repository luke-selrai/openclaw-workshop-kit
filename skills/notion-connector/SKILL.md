---
name: notion-connector
description: "Connect Notion to Claude by switching on its built-in connector, or by signing in to the official `ntn` CLI as the fallback. Use when the user asks to set up or connect Notion, or wants Notion work (pages, databases, search, comments, meeting notes) and Notion isn't connected yet. Once connected, Notion runs through the mcp__claude_ai_Notion__* tools, or the `ntn` CLI on the kit's own route."
allowed-tools: Bash, Read, Write, mcp__claude_ai_Notion__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - notion
    - workspace
    - documentation
    - cli
    - ntn
  pairs-with:
    - skill: google-chat-connector
      reason: Sibling CLI-based connector - wraps a first-party CLI (`gws`) with OAuth, same instructions-only shape
    - skill: quickbooks-connector
      reason: Sibling CLI-based connector - wraps a first-party CLI (`qbo`) the same way
    - skill: orientation
      reason: Shares the conversational-bootstrap pattern for non-technical users
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Notion sign-in / consent screen
---

# Notion Connector

> **Install pattern:** built-in connector first; CLI-based (first-party CLI + OAuth login, like `google-chat-connector`'s `gws` and `quickbooks-connector`'s `qbo`) as the fallback. **Not** a plugin connector - see the rationale below.

## Overview

This skill connects and operates a user's Notion workspace. There are two new-setup routes, and **the built-in connector is the default**. Phase 0 also adopts an already-working local Notion server without reinstalling or changing its credentials:

- **Phase 1 - the built-in Notion connector (default).** Notion's own hosted server at `mcp.notion.com`, listed in Claude's connector directory at `https://claude.com/connectors/notion` (verified live, 2 Sep 2026). The user connects it once on their Claude account by pressing one button, and it is then available everywhere that account is signed in, including Claude Code. It reads and writes: create pages with structured content, search across the workspace, update page properties, and work with databases and wikis. Tools arrive as `mcp__claude_ai_Notion__*`. Nothing material is missing versus the `ntn` route.
- **Phase 1-alt - the kit's own route** (only when the built-in can't be used): the **official Notion CLI**, `ntn` (https://developers.notion.com/cli). Claude installs `ntn`, runs `ntn login --no-browser`, reads the verification URL + code the CLI prints, opens that URL in a Playwright browser, the user signs in to Notion and confirms the matching code, then `ntn login poll` completes the login. The token is stored in the **OS keychain** (`notion-cli` service) - never in a file, never in `~/.claude.json`. The only manual moment for the user is signing in to Notion in the browser window.
- **Phase 2 - Operate.** Whichever route connected: search, read, create, and update Notion pages and databases on the user's behalf.

> **The same page-sharing rule applies on both routes.** Notion only exposes pages and databases that have been shared with the connection - this is a Notion permission, not a Claude one, and switching routes does not change it. If a search comes back empty or a known page 404s, that is almost always the cause. Say it plainly: *"Notion only shows me the pages you've shared with this connection. Open the page in Notion, use its share control, and add the Claude connection - then I'll find it."* Do not diagnose it as a broken connection.

### Why the `ntn` CLI is the fallback, not the Notion plugin or a hand-wired server

When Phase 1 is unavailable, this connector deliberately uses the `ntn` CLI instead of the `notion@claude-plugins-official` plugin or a hand-wired hosted-MCP entry. Reasons, in order:

1. **No secret ever lands in a file.** `ntn login` stores the OAuth token in the **OS keychain**. There is no `Authorization: Bearer …` line in `~/.claude.json` (the hosted-bearer-PAT shape that has leaked into config + logs before) and no manual integration token to paste.
2. **Works in any session.** A CLI runs the same whether or not the MCP tool surface has reconciled. (Plugin-/MCP-exposed Notion tools can fail to appear in a running session until a chat restart; a CLI never has that problem.)
3. **Markdown-native.** `ntn pages get/create/update` speak Markdown, which is the natural format for Claude to read and write.

> If you ever find yourself adding a `mcpServers.notion` entry with a Bearer token to `~/.claude.json`, **stop** - that is the leak-prone path this skill exists to avoid. Use the built-in connector (Phase 1), or `ntn login` (Phase 1-alt). Neither of them writes a Bearer token into config: the built-in connector's sign-in is held by the user's Claude account, and `ntn`'s is held by the OS keychain.

### What this skill does NOT set up

- **No new bearer token / integration token in any config file.** True on both new-setup routes; an existing working server is preserved by Phase 0 without reading or rewriting its credentials. On the kit's own route: OAuth login → OS keychain. (`NOTION_API_TOKEN` is an *override* the CLI supports, but this skill does not use it - verified on `ntn` v0.16.0 that `ntn login` alone authorizes the full public API.)
- **No `claude mcp add` / hand-wired MCP server registration.** The built-in connector is not registered this way either - it is switched on once on the user's Claude account and needs no local entry.
- **No Claude Code plugin install.**
- **No manual integration-app creation in Notion.** Neither route asks the user to build an integration: the built-in connector is Notion's own listed app, and `ntn login` is an OAuth flow against Notion's own pre-registered CLI app.

---

## Security rules

- **Never echo a token.** `ntn` stores the token in the OS keychain - macOS **Keychain**, Linux **Secret Service** - and you never see it and must never print it. Never set or echo `NOTION_API_TOKEN`. Never run `claude mcp get` or print `~/.claude.json`.
- **The verification code is short-lived and low-risk**, but still don't paste it into chat unnecessarily - drive it through Playwright.
- If a user is on a system with no keychain, `ntn` falls back to `~/.config/notion/auth.json` (set `NOTION_KEYRING=0`). Treat that file as a secret: never read it back into chat, never commit it.

---

## Communication rules (non-technical user)

The user is a non-technical business owner. Connecting is autonomous - Claude does the work; the user only presses one button and signs in to Notion (**Connect to Claude** on the built-in route in Phase 1, the confirm screen in the window Claude opens on the kit's own route in Phase 1-alt). Every message follows these rules:

- **You drive, not them.** Use available tools for setup. If the app is inaccessible, give the short in-app sequence from Step 2 and resume from its handoff. When sign-in needs the user, say "please press the connect button and sign in to Notion in the window that opens" (built-in route), or "please sign in to Notion in the window I just opened, and confirm the code matches" (kit's own route).
- **Plain English only.** No jargon. Never say CLI, npm, OAuth, keychain, token, API, MCP, terminal, config, JSON, data source. The browser window is "a sign-in window I opened for you"; the connection is "your Notion connection".
- **Narrate at action boundaries.** Once when you start, once when you need them, once when done.
- **Short messages** (max ~8 lines). **Never show raw errors** - translate to plain English and diagnose silently.

---

## PHASE 0 - Is Notion already connected? (silent)

Identify the calling surface first. Desktop's account and connectors can differ from the standalone CLI, even when `claude auth status` and `claude mcp list` run from Desktop's Bash. Those commands describe the CLI account; use the app's visible account, Connectors view, and actual runtime tools for Desktop evidence. Local Notion credentials are independent of either Claude login.

Run these silently, in order, and act on the first that answers for the intended Notion workspace.

1. **Built-in connector.** In Desktop, discover the app-supplied hosted Notion connector by tool names/descriptions and its Connectors view (the prefix can be an opaque `mcp__<id>__`). Locally registered server tools belong to step 2, even if they are the only Notion tools present. Prove access with the read below using the actual runtime tool. In terminal/VS Code only, `claude mcp list` → look for a line starting `claude.ai Notion`.
   - Built-in connected or its tools present → prove it with the actual hosted Notion search tool in this session (`mcp__claude_ai_Notion__notion-search` in terminal/VS Code), using a word likely to be in the intended workspace. Only then proceed to Phase 2.
   - Reconnect or `! Needs authentication` → follow Step 2 of the built-in route for the same account, choose **Reconnect**, then repeat the read check.
   - No usable built-in found → continue. A missing CLI line alone does not rule out Desktop tools.
2. **Existing local Notion server.** Discover actual Notion operations in this calling session, including servers registered under a different name: an official `@notionhq/notion-mcp-server` may appear as `mcp__<server-name>__API-get-self` (for example, `mcp__selr-notion__API-get-self`). Match the tool's name and description, not a required registration name. Call the available identity/read tool and check the returned bot/user and workspace against the intended workspace. A successful `API-get-self` is a real identity/read; it does not imply access to every page. If identity is insufficient to select the intended workspace, use an available read of a known shared page or clarify which workspace is intended.
   - Read succeeds for the intended workspace → adopt this existing connection and go to Phase 2. Preserve its server name, registration, and credentials; do not require `ntn`, re-register the server, or set up another route. Report existing access, not fresh onboarding or a proven Desktop built-in connection.
   - Tools missing or read fails → continue to the `ntn` check and existing setup routes. Inspect tool errors without printing credentials or configuration. A page-sharing restriction alone is not a reason to replace the connection.

3. **The kit's own route.** Check whether `ntn` is installed and logged in:

   ```bash
   command -v ntn >/dev/null 2>&1 && ntn --version    # installed?
   ntn whoami 2>&1                                     # logged in? prints the user, or an error
   ```

   - `ntn whoami` returns a user → **already connected.** Keep using it - say *"Good news - your Notion is already connected. Want me to search something or create a page?"* and skip to Phase 2. Do not set the built-in up on top of a working connection.
   - `ntn` missing, or `whoami` errors with "No workspace selected" / "Run `ntn login`" → continue.
   - For a fuller health read use `ntn doctor` (shows CLI version, config dir, default workspace, token source, public-API access).
4. **Nothing found** → Phase 1.

Without a shell, keep runtime discovery and read checks; skip only unavailable commands. Use Phase 1 only when no working connection is found, then prove the result with a read in the calling session.

---

## PHASE 1 - Switch on the built-in Notion connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in.

**Step 1 - Check this session can see built-in connectors.** In Desktop or claude.ai chat, use that account's Connectors view and runtime tools; a terminal login does not gate the app account. For terminal/VS Code only, `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear in that CLI session: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route (Phase 1-alt) instead.

**Step 2 - Open the connector page for them.**

Say: *"I'm connecting Notion to this Claude account. I'll handle the setup and let you know if you need to sign in."* Use browser or computer-use tools actually available for navigation and authorised connection approvals. If a surface is inaccessible, give only the next short click sequence, then resume the work.

- **Desktop first:** **+ → Connectors → Browse connectors → Notion → Connect**. If the app is inaccessible, give this exact sequence to the user. Keep the exact handoff URL opened by **Connect** in a browser profile signed into the same Claude account as Desktop. If the everyday profile differs, use a matching or isolated profile and request sign-in there as needed. Preserve the URL and its parameters; do not invent app deep links. If **Continue connecting** loops, check account matching before retrying; start a fresh in-app Connect if the handoff expired.
- **Browser or terminal/VS Code:** use `https://claude.ai/directory/notion` in a browser signed into the calling Claude account, then **Connect to Claude**. If it fails to load, use `https://claude.ai/customize/connectors` → **Browse** → **Notion** → **Connect**. With only a shell, use `open` on Mac, `xdg-open` on Linux, or `start ""` on Windows after checking the default browser's account. For re-authentication, choose **Reconnect** on that account's connector instead.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** In Desktop, check Notion's connected state in the app; in browser chat, check that account's Connectors view. If inaccessible, request only that status check. Step 5 remains required. The following command and status branches apply only to terminal/VS Code, never as proof for a different Desktop account: `claude mcp list` again. `claude.ai Notion … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call the actual Notion search tool in this session (`mcp__claude_ai_Notion__notion-search` in terminal/VS Code, or its discovered Desktop equivalent) and confirm the intended workspace. Only a real answer counts. A tool error here is not "connected". An *empty* result is not a failure either - it usually means nothing is shared with the connection yet, so give the page-sharing line from the Overview. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed for the same account, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - for example *"search my Notion for the Q3 plan"*, *"create a page called R&D Log"*, *"what's in my Tasks database?"*.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Notion on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-alt - The kit's own route (only when the built-in can't be used)

Run this **only** when one of these is true: Step 1 above failed (this session cannot see built-in connectors); the Notion listing is missing on the user's account; or the user explicitly wants the local CLI. Otherwise Phase 1 is the route. The `ntn` route loses nothing material against the built-in one, so there is no capability warning to give - it is simply more setup.

### Step 1 - Orient the user

> "I'll connect your Notion now. I'll open a sign-in window in a moment - just sign in to Notion there and I'll handle the rest. About a minute."

### Step 2 - Install `ntn` (silent)

Check Node first (`ntn` needs **Node 22+**):

```bash
node --version    # need v22+
```

Install (npm is the cross-platform path; Windows must use npm):

```bash
npm install --global ntn
```

Fallback if npm is unavailable on macOS/Linux:

```bash
curl -fsSL https://ntn.dev | bash
```

Verify:

```bash
ntn --version     # expect e.g. "ntn 0.16.0"
```

- **`EACCES` / `EPERM` on npm global install** → translate: *"Your computer needs a small permission fix - one moment."* Install via a Node version manager rather than a global sudo install (see `docs/start/setup.md` Step 0), then retry once.
- **Node too old (`< 22`)** → install/upgrade Node via the user's package manager or a version manager, then retry. Translate to plain English.

### Step 3 - Log in (the captured two-step flow)

Run the headless login. The CLI prints a URL (with a verification code) and a matching code, then tells you to poll:

```bash
ntn login --no-browser
```

**Captured output shape (`ntn` v0.16.0):**

```
Open this URL in your browser to log in:

  https://www.notion.so/workers/cli-login?verificationCode=XXX-XXXX

Confirm that this verification code matches what you see in the browser:

  XXX-XXXX

Then run this command to complete login:

  ntn login poll

  hint: For agents: You must show the URL above to the user to click, then run
  `ntn login poll`. The poll command will wait for the user to confirm in the
  browser and exit once login is complete. Do not ask the user before polling -
  they have already requested to log in.
```

Drive it:

1. **Parse** the `https://www.notion.so/workers/cli-login?verificationCode=…` URL and the verification code from stdout.
2. **Open the URL in the Playwright browser:**

   ```
   mcp__playwright__browser_navigate({ url: <login_url> })
   mcp__playwright__browser_snapshot()
   ```

   - **Not signed in** (Notion login form / SSO) → tell the user *once*: *"Please sign in to your Notion account in the window I opened - I'll wait."* Then `browser_wait_for` the confirm screen.
   - **Signed in** → Notion shows a confirm screen with the verification code. **Check the on-screen code matches** the one from stdout (`browser_evaluate` reads the page text), then click **Confirm** / **Allow**:

     ```
     mcp__playwright__browser_click({ target: <Confirm/Allow button>, element: "Notion CLI login Confirm button" })
     ```

3. **Complete the login** (run this without asking again - per the CLI's own agent hint; `poll` blocks until the browser confirm lands):

   ```bash
   ntn login poll
   ```

   Run it in the background or with a generous timeout - it waits for the user to confirm, then exits 0.

> **Browser variant.** Plain `ntn login` (no `--no-browser`) tries to open a browser itself. In a Playwright-driven workshop flow prefer `--no-browser` so the only browser is the one you control.

### Step 4 - Verify

```bash
ntn whoami        # prints the authenticated Notion user → success
ntn doctor        # all green: token source found, public API access ok
```

If `whoami` still errors, re-run Step 3 once. If it persists, surface in plain English and stop.

### Success message

> "All done - your Notion is connected! You can ask me things like 'search my Notion for the Q3 plan', 'create a page called R&D Log', 'add today's notes to my R&D page', or 'what's in my Tasks database?'. Give it a try!"

---

## PHASE 2 - Operate

**Which tools you have depends on which route connected.**

- **Through the built-in connector (Phase 1):** the tools are `mcp__claude_ai_Notion__*` - search, fetch, create pages, update pages and page properties, query data sources, comments. Names come from Notion's own hosted server, so discover them in the session rather than translating a `ntn` command from the tables below. Everything in [Behaviour Guidelines](#behaviour-guidelines-phase-2) still applies: confirm before create/update/trash/comment, discover IDs before acting, present results readably.
- **Through an existing local server adopted in Phase 0:** keep using that server's actual tools. Its operation names and supported API version can differ from the hosted connector and `ntn`; discover its tool descriptions rather than translating commands or assuming the tables below fit. Page-sharing and Behaviour Guidelines still apply.
- **Through the kit's own route (Phase 1-alt):** the tools are `ntn` commands, documented in full below.

The database-vs-data-source distinction is a Notion API fact, not a CLI quirk, so it bites on both routes: a database can hold several data sources, and a row query wants the data-source id. On the built-in route, resolve it with the connector's own fetch/search tools rather than `ntn datasources resolve`.

### The `ntn` command surface (the kit's own route, verified v0.16.0)

`ntn`'s command groups: `pages`, `datasources`, `files`, and a generic `api` passthrough, plus `whoami` / `doctor` / `login` / `logout`. There is **no** top-level `search` or `databases` command - search and everything else go through `ntn api`.

Add `--json` to most commands for machine-readable output; default output is human-readable Markdown.

### Search - `ntn api v1/search`

```bash
ntn api v1/search -X POST -d '{"query":"quarterly plan","page_size":10}'
# or with inline body inputs:
ntn api v1/search query="quarterly plan" page_size:=10
```

`POST /v1/search` matches pages and databases **by title**. Returns objects with their `id` (use the id with `ntn pages get`, etc.).

### Pages - `ntn pages` (Markdown-native)

```bash
ntn pages get <page-id>                 # Markdown, with page properties as frontmatter
ntn pages get <page-id> --json          # inspect blocks / unknown_block_ids if Markdown truncates
ntn pages create --parent page:<id> --content '# Title\n\nBody'
ntn pages create --parent database:<id> < page.md
ntn pages create --parent data-source:<id> --content '# Title'
ntn pages update <page-id> --content '# Updated body'
ntn pages update <page-id> < page.md
ntn pages trash <page-id>               # moves the page to trash (reversible)
```

- `--parent` (create only) is optional and takes `page:<id>`, `database:<id>`, or `data-source:<id>`.
- Content comes from `--content`, stdin, or - interactively - `$EDITOR`. In an automated flow **always pass `--content` or stdin**; never rely on `$EDITOR` opening.
- For page **properties**, templates, or moves, use the `ntn api` paths (`v1/pages`, `v1/pages/{id}`, `v1/pages/{id}/move`, `v1/pages/{id}/properties/{property_id}`).

### Databases & data sources - `ntn datasources`

> **Gotcha (real, non-obvious):** `ntn datasources query` needs a **data-source ID, not a database ID**. A Notion database can hold multiple data sources. Resolve first.

```bash
ntn datasources resolve <database-id>                       # → the data-source IDs in that database
ntn datasources query <data-source-id>                      # query rows (pages)
ntn datasources query <data-source-id> --limit 50 --json
ntn datasources query <data-source-id> --filter '{"property":"Done","checkbox":{"equals":true}}'
ntn datasources query <data-source-id> --start-cursor <cursor>   # pagination
```

### Everything else - `ntn api` (full public API, 44 endpoints)

```bash
ntn api ls                              # list all supported endpoints
ntn api <path> --spec                   # reduced OpenAPI fragment for an endpoint
ntn api <path> --docs                   # full official docs for an endpoint
```

Common endpoints (discover the rest with `ntn api ls`):

| Need | Call |
|---|---|
| Search by title | `ntn api v1/search -X POST -d '{"query":"…"}'` |
| Who am I (token's bot user) | `ntn api v1/users/me` (or `ntn whoami`) |
| List workspace users | `ntn api v1/users` |
| Retrieve a page (raw) | `ntn api v1/pages/{page_id}` |
| Page as markdown | `ntn api v1/pages/{page_id}/markdown` |
| Block children (read) | `ntn api v1/blocks/{block_id}/children` |
| Append blocks | `ntn api v1/blocks/{block_id}/children -X PATCH -d '{…}'` |
| List / create comments | `ntn api v1/comments` (GET / POST) |
| Query a data source | `ntn api v1/data_sources/{data_source_id}/query -X POST -d '{…}'` |
| Retrieve / update a database | `ntn api v1/databases/{database_id}` |

**Inline input syntax** (alternative to `-d` JSON): `Header:Value` (header), `name==value` (query param), `path=value` (body string), `path:=json` (typed JSON, e.g. `archived:=true`). Method is GET by default, POST when a body is present, and `-X` always wins.

---

## Prompt-to-command mapping

| What the user says | Command |
|---|---|
| "Connect my Notion" / "Set up Notion" | **Run Phase 0**, then Phase 1 (or Phase 1-alt if the built-in is unavailable) |
| "My Notion stopped working" / "reconnect Notion" | Built-in route: re-run Phase 0 step 1 → Reconnect on the connector settings page. Kit's own route: `ntn login --no-browser` (re-run Phase 1-alt Step 3) |
| "Search my Notion for X" / "find the Q3 plan" | `ntn api v1/search -X POST -d '{"query":"X"}'` |
| "Find my meeting notes from X" / "read the meeting notes" | `ntn api v1/search -X POST -d '{"query":"…"}'` → `ntn pages get <page-id>` (meeting notes are ordinary pages) |
| "Open / read the <page>" | search → `ntn pages get <page-id>` |
| "Create a page called X" / "add a note" | **CONFIRM** → `ntn pages create --parent … --content '# X …'` |
| "Update / append to <page>" | `ntn pages get <id>` → **CONFIRM** → `ntn pages update <id> …` |
| "Delete / archive <page>" | **CONFIRM** → `ntn pages trash <page-id>` |
| "What's in my Tasks database?" / "show rows where …" | `ntn datasources resolve <db-id>` → `ntn datasources query <data-source-id> [--filter …]` |
| "Add a row to <database>" | **CONFIRM** → `ntn pages create --parent data-source:<id> …` |
| "Comment on <page>" | **CONFIRM** → `ntn api v1/comments -X POST -d '{…}'` |
| "Who's in the workspace?" | `ntn api v1/users` |

---

## Error handling (Phase 2)

Diagnose and respond in plain English; never show raw errors.

| Error | What to say | Fix |
|---|---|---|
| "No workspace selected" / "Run `ntn login`" | "Your Notion connection needs a quick refresh - one moment." | Re-run Phase 1-alt Step 3 (`ntn login --no-browser`) |
| 401 / unauthorized / expired | "Let me reconnect your Notion." | `ntn login --no-browser` again |
| 404 not found (page/db), or a search that returns nothing for a page the user swears exists | "Notion only shows me the pages you've shared with this connection - open that page in Notion, use its share control, and add the Claude connection." | Re-search for the right id first; if the page genuinely isn't there, it is the sharing rule, on either route |
| Built-in connector: any auth failure, or its tools have vanished | "Your Notion connection needs a quick re-sign-in - one moment." | Re-run Phase 0 step 1; `! Needs authentication` → Reconnect at `https://claude.ai/customize/connectors`; no line at all → re-run Phase 1. Never `ntn login` to fix a built-in-route failure |
| "needs a data source id" on a database query | (silent) | `ntn datasources resolve <database-id>` first, then query the data-source id |
| 429 rate limited | "Notion asked me to slow down - trying again in a moment." | Wait, retry once |
| Markdown truncated on `pages get` | (silent) | Re-run with `--json` to inspect `unknown_block_ids` |
| Node too old / `ntn` missing | "Let me finish setting up the connection." | Phase 1-alt Step 2 |

---

## Scope Limitations

**Can, on the built-in connector:** read and write pages, databases and wikis - create pages with structured content, search the workspace, update page properties, query data sources. Nothing material in the list below is missing from it.

**Can, via `ntn`:** search by title; read/create/update/trash pages as Markdown; query database rows (via data sources, with filters + pagination); read/append blocks; read/create comments; list users; and any other public-API endpoint via `ntn api` (44 endpoints; `ntn api ls`).

**Cannot, on either route:**
- **See a page that has not been shared with the connection** - a Notion permission, identical on both routes. Fix it in Notion's share control, not in Claude.
- **Query a database by database-id directly** - resolve to a data-source-id first (`ntn datasources resolve` on the kit's own route; the connector's own fetch/search tools on the built-in route).
- **Permanently delete a page** - trashing is reversible; permanent delete needs the Notion UI.

**Cannot, on the kit's own route specifically:**
- **No bearer token in any config file** - by design (token lives in the OS keychain).
- **Operate without `ntn login`** - there is no API-key-paste path in this skill (deliberately).
- Some endpoints are marked **beta** in `ntn` (`api`, `files`, `workers`) - behaviour may change; re-check with `ntn api <path> --spec`.

---

## Behaviour Guidelines (Phase 2)

- **Confirm before create / update / trash / comment** - these change the user's real workspace. Summarise what you'll do (page title, parent, content gist) and wait for OK.
- **Discover IDs before acting** - call `ntn api v1/search` (or `datasources resolve`) once per session to get page/database/data-source IDs before reads or writes.
- **Never echo tokens or read keychain/`auth.json` into chat.**
- **Present results readably** - format `--json` output as lists/summaries, not raw JSON dumps. For database rows, show the key properties, not the full payload.
- **One step at a time** - summarise first ("Found 12 pages matching 'plan'"), then offer detail.
- **Prefer `ntn pages`/`ntn datasources` typed commands** for the common cases; reach for `ntn api` only when the typed commands don't cover the need.

---

## Related Skills

- **google-chat-connector** - sibling CLI-based connector (`gws`); same instructions-only, OAuth-login shape
- **quickbooks-connector** - sibling CLI-based connector (`qbo`)
- **orientation** - conversational-bootstrap pattern this skill's Phase 1-alt follows
- **playwright-skill** - the Playwright MCP browser drives the Notion sign-in / code-confirm screen
