---
name: notion-connector
description: "Connect Notion to Claude by installing and signing in to the official `ntn` CLI. Use when the user asks to set up or connect Notion, or wants Notion work (pages, databases, search, comments, meeting notes) and the `ntn` CLI isn't signed in yet. Once connected, Notion runs directly through the `ntn` CLI."
allowed-tools: Bash, Read, Write, mcp__playwright__*, mcp__plugin_playwright_playwright__*
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

> **Install pattern:** CLI-based (first-party CLI + OAuth login), like `google-chat-connector` (`gws`) and `quickbooks-connector` (`qbo`). **Not** a hosted-MCP or plugin connector - see the rationale below.

## Overview

This skill connects and operates a user's Notion workspace through the **official Notion CLI**, `ntn` (https://developers.notion.com/cli). It has two phases:

- **Phase 1 - Install & Log in (autonomous via Playwright).** Claude installs `ntn`, runs `ntn login --no-browser`, reads the verification URL + code the CLI prints, opens that URL in a Playwright browser, the user signs in to Notion and confirms the matching code, then `ntn login poll` completes the login. The token is stored in the **OS keychain** (`notion-cli` service) - never in a file, never in `~/.claude.json`.
- **Phase 2 - Operate.** Claude runs `ntn` commands to search, read, create, and update Notion pages and databases on the user's behalf.

The only manual moment for the user is signing in to Notion in the browser window.

### Why the CLI, not the Notion plugin or a hand-wired MCP server

This connector deliberately uses the `ntn` CLI instead of the `notion@claude-plugins-official` plugin or a hand-wired hosted-MCP entry. Reasons, in order:

1. **No secret ever lands in a file.** `ntn login` stores the OAuth token in the **OS keychain**. There is no `Authorization: Bearer …` line in `~/.claude.json` (the hosted-bearer-PAT shape that has leaked into config + logs before) and no manual integration token to paste.
2. **Works in any session.** A CLI runs the same whether or not the MCP tool surface has reconciled. (Plugin-/MCP-exposed Notion tools can fail to appear in a running session until a chat restart; a CLI never has that problem.)
3. **Markdown-native.** `ntn pages get/create/update` speak Markdown, which is the natural format for Claude to read and write.

> If you ever find yourself adding a `mcpServers.notion` entry with a Bearer token to `~/.claude.json`, **stop** - that is the leak-prone path this skill exists to avoid. Use `ntn login` instead.

### What this skill does NOT use

- **No bearer token / integration token in any config file.** OAuth login → OS keychain. (`NOTION_API_TOKEN` is an *override* the CLI supports, but this skill does not use it - verified on `ntn` v0.16.0 that `ntn login` alone authorizes the full public API.)
- **No `claude mcp add` / MCP server registration.**
- **No Claude Code plugin install.**
- **No manual integration-app creation in Notion.** `ntn login` is an OAuth flow against Notion's own pre-registered CLI app; there is no integration to create.

---

## Security rules

- **Never echo a token.** `ntn` stores the token in the OS keychain - macOS **Keychain**, Linux **Secret Service** - and you never see it and must never print it. Never set or echo `NOTION_API_TOKEN`. Never run `claude mcp get` or print `~/.claude.json`.
- **The verification code is short-lived and low-risk**, but still don't paste it into chat unnecessarily - drive it through Playwright.
- If a user is on a system with no keychain, `ntn` falls back to `~/.config/notion/auth.json` (set `NOTION_KEYRING=0`). Treat that file as a secret: never read it back into chat, never commit it.

---

## Communication rules (non-technical user)

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work; the user only signs in to Notion in the browser window. Every message follows these rules:

- **You drive, not them.** The only thing you ever ask is "please sign in to Notion in the window I just opened (and confirm the code matches)."
- **Plain English only.** No jargon. Never say CLI, npm, OAuth, keychain, token, API, MCP, terminal, config, JSON, data source. The browser window is "a sign-in window I opened for you"; the connection is "your Notion connection".
- **Narrate at action boundaries.** Once when you start, once when you need them, once when done.
- **Short messages** (max ~8 lines). **Never show raw errors** - translate to plain English and diagnose silently.

---

## PHASE 0 - Resume check (silent)

Before installing anything, check whether `ntn` is already installed and logged in.

```bash
command -v ntn >/dev/null 2>&1 && ntn --version    # installed?
ntn whoami 2>&1                                     # logged in? prints the user, or an error
```

- `ntn whoami` returns a user → **already connected.** Skip to Phase 2. Optionally greet: *"Good news - your Notion is already connected. Want me to search something or create a page?"*
- `ntn` missing, or `whoami` errors with "No workspace selected" / "Run `ntn login`" → run Phase 1.
- For a fuller health read use `ntn doctor` (shows CLI version, config dir, default workspace, token source, public-API access).

---

## PHASE 1 - Install & Log in (autonomous via Playwright)

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

## PHASE 2 - Operate (verified `ntn` command surface, v0.16.0)

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
| "Connect my Notion" / "Set up Notion" | **Run Phase 1** |
| "My Notion stopped working" / "reconnect Notion" | `ntn login --no-browser` (re-run Phase 1 Step 3) |
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
| "No workspace selected" / "Run `ntn login`" | "Your Notion connection needs a quick refresh - one moment." | Re-run Phase 1 Step 3 (`ntn login --no-browser`) |
| 401 / unauthorized / expired | "Let me reconnect your Notion." | `ntn login --no-browser` again |
| 404 not found (page/db) | "I couldn't find that - let me re-search." | `ntn api v1/search` to get the right id |
| "needs a data source id" on a database query | (silent) | `ntn datasources resolve <database-id>` first, then query the data-source id |
| 429 rate limited | "Notion asked me to slow down - trying again in a moment." | Wait, retry once |
| Markdown truncated on `pages get` | (silent) | Re-run with `--json` to inspect `unknown_block_ids` |
| Node too old / `ntn` missing | "Let me finish setting up the connection." | Phase 1 Step 2 |

---

## Scope Limitations

**Can** (via `ntn`): search by title; read/create/update/trash pages as Markdown; query database rows (via data sources, with filters + pagination); read/append blocks; read/create comments; list users; and any other public-API endpoint via `ntn api` (44 endpoints; `ntn api ls`).

**Cannot:**
- **No bearer token in any config file** - by design (token lives in the OS keychain).
- **Query a database by database-id directly** - resolve to a data-source-id first (`ntn datasources resolve`).
- **Permanently delete a page** - `ntn pages trash` is reversible; permanent delete needs the Notion UI.
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
- **orientation** - conversational-bootstrap pattern this skill's Phase 1 follows
- **playwright-skill** - the Playwright MCP browser drives the Notion sign-in / code-confirm screen
