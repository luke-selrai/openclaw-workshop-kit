---
name: atlassian-connector
description: "Connect and operate Atlassian (Jira + Confluence, plus Compass) via the official first-party Atlassian Rovo Remote MCP server (https://mcp.atlassian.com/v1/mcp). Phase 1 is a 5-step Playwright-driven install: register the server with `claude mcp add`, open Claude Code's OAuth start URL inside the Playwright MCP browser, detect login state and prompt sign-in only if needed, surface the workspace/site picker on the consent screen, auto-click Allow, auto-detect the callback via `browser_wait_for`, then verify with `mcp__atlassian__getAccessibleAtlassianResources`. The user's only manual moment is signing in to Atlassian inside the Playwright window. Use this skill when the user asks to set up Atlassian, connect Jira or Confluence, or interact with issues, tickets, sprints, boards, pages, or spaces."
allowed-tools: mcp__atlassian__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Project Management & Docs
  tags:
    - atlassian
    - jira
    - confluence
    - tickets
    - docs
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Draft follow-ups or status notes based on Jira tickets and Confluence updates
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Jira issues or Confluence changes
    - skill: monday-connector
      reason: Same Playwright-driven autonomous Phase 1 pattern (different auth shape — PAT vs OAuth)
    - skill: slack-connector
      reason: Same Playwright-driven autonomous Phase 1 pattern (different auth shape — OAuth-app vs hosted-MCP OAuth)
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Atlassian consent flow
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Atlassian auth or API errors
---

# Atlassian Connector (Jira + Confluence)

## Overview

This skill lets you read and update a user's Atlassian Cloud workspace on their behalf — Jira, Confluence, and Compass — using the **official first-party Atlassian Rovo Remote MCP server** hosted at `https://mcp.atlassian.com/v1/mcp` (see [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth (autonomous, 5 steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, surfaces the workspace picker on the consent screen, auto-clicks Allow, and auto-detects the callback via `browser_wait_for`. The user's only manual moment is signing in to Atlassian inside the Playwright window. Token storage is handled by Claude Code's MCP runtime — there is no manual `~/.claude.json` token write.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__atlassian__*` native tools to read and update Jira and Confluence data.

**Which phase to run** — Before any tool call, check whether the Atlassian MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.atlassian` entry. If present, attempt a verification tool call (Phase 1 Step 5). If it succeeds, the connector is ready — skip to Phase 2. If it 401s, walk through Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **Atlassian API tokens (legacy 1LO PATs).** Atlassian's Rovo MCP supports OAuth 2.1; we use that.
- **The legacy `/v1/sse` endpoint.** Sunsets 30 June 2026. Always use `https://mcp.atlassian.com/v1/mcp`.
- **A self-hosted Atlassian MCP server.** Atlassian's hosted endpoint is the primary deployment.
- **The community `sooperset/mcp-atlassian` Python package.** Versions before 0.17.0 carry CVE-2026-27825 (unauthenticated RCE via path traversal in Confluence attachment download) and CVE-2026-27826 (SSRF). Not the official server we configure. If the user already has it installed, advise removal as part of setup.
- **A custom OAuth client.** Claude Code's MCP runtime owns the OAuth dance; we do not register our own client, run our own callback listener, or store tokens manually.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Atlassian in the Playwright window. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - workspace / site → **"your Atlassian workspace"**
  - Allow / consent → **"the Allow button"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Atlassian for you now"), once when you need them ("please sign in"), once when you're done ("your Atlassian is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Atlassian is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0 — Pre-flight (silent)

### 0.1 — Resume check

Read `~/.claude.json` via Node (cross-platform safe — Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const at = (j.mcpServers || {}).atlassian;
console.log(at ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 5 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → run full Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright npx @playwright/mcp@latest --scope user`, ask the user to close and reopen the chat, then retry.

### 0.3 — Detect + remove vulnerable community package (silent)

Scan `~/.claude.json` for any `mcpServers` entry whose `command`, `args`, or `url` contains `mcp-atlassian` or `sooperset` (the community Python package, CVE-2026-27825/27826). If found, alert the user once: *"I found an older Atlassian connector on your machine that has a known security issue — I'll remove it as part of this setup."* Then delete that entry from the config (preserving every other server) and continue.

---

## PHASE 1 — Install & Auth (5 steps, autonomous via Playwright)

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your Atlassian now — that covers Jira and Confluence. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 — Register the MCP server with `claude mcp add`

Silently register the hosted Atlassian MCP server in the user's config:

```bash
claude mcp add atlassian https://mcp.atlassian.com/v1/mcp --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output) — write the entry directly to `~/.claude.json` via the same Node merge pattern used by sibling connectors:

```bash
node -e '
  const fs = require("fs"), path = require("path"), home = require("os").homedir();
  const cfg = path.join(home, ".claude.json");
  let j = {};
  if (fs.existsSync(cfg)) {
    try { j = JSON.parse(fs.readFileSync(cfg, "utf8")); }
    catch (e) {
      const backup = cfg + ".backup-" + Date.now();
      fs.copyFileSync(cfg, backup);
      console.error("CONFIG_BACKUP=" + backup);
      j = {};
    }
  }
  j.mcpServers = j.mcpServers || {};
  j.mcpServers.atlassian = { type: "http", url: "https://mcp.atlassian.com/v1/mcp" };
  fs.writeFileSync(cfg + ".tmp", JSON.stringify(j, null, 2));
'
mv ~/.claude.json.tmp ~/.claude.json
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 3 — Open Claude Code's OAuth start URL inside Playwright

When Claude Code's MCP runtime first contacts an unauthenticated hosted server, it emits an OAuth start URL for the user to visit. Capture that URL and open it inside the Playwright MCP browser instead of the user's default browser.

The standard mechanism (Claude Code 2.x): trigger Claude Code's `/mcp` flow programmatically by invoking the management subcommand. The URL is printed to stdout/stderr in the form `https://mcp.atlassian.com/v1/authorize?...`. Capture it via:

```bash
AUTH_URL=$(claude mcp authenticate atlassian 2>&1 | grep -oE 'https://mcp\.atlassian\.com/[^[:space:]]+' | head -1)
echo "AUTH_URL=$AUTH_URL"
```

If the `claude mcp authenticate` subcommand isn't available in the user's Claude Code version, fall back to invoking any `mcp__atlassian__*` tool (e.g. `getAccessibleAtlassianResources`) — Claude Code will surface the OAuth start URL as part of its 401 challenge handling. Capture from that surfacing.

Then drive Playwright to that URL:

```
mcp__playwright__browser_navigate({ url: <AUTH_URL> })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see Atlassian's consent UI — "wants to access your Atlassian account" with Allow / Cancel buttons) → continue to Step 4.
- **Not logged in** (sign-in form, Atlassian logo + email/password fields, or SSO redirect) → tell the user, *once*: *"Please sign in to your Atlassian account in the browser window I just opened — I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent text (`"wants to access"`) or the workspace-picker text (`"Choose a site"`). Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

### Step 4 — Workspace picker + auto-click Allow + auto-detect callback

Once past sign-in, snapshot the consent page and branch:

#### 4a — Site picker (multi-site users)

If the snapshot shows a workspace/site picker (text like "Choose a site to grant access to" with a list of `*.atlassian.net` sites):

- **One site listed** → auto-select via `browser_click` and continue.
- **Multiple sites** → surface the list to the user, once: *"Which Atlassian workspace do you want me to use? I see: \<site 1\>, \<site 2\>, …"* Wait for their answer, click the matching option.

If the user changes their mind later ("switch my Atlassian workspace"), re-run Phase 1 from Step 3 — Atlassian re-prompts the picker on a fresh consent flow.

#### 4b — Admin-approval-required interstitial

If the snapshot shows phrasing like *"Your administrator must approve this app"*, *"This app requires admin consent"*, or *"Site administrator approval required"*, surface cleanly and exit:

> "Atlassian is telling me your organisation needs an administrator to approve this connection first. Your Atlassian admin can enable it from **Manage your organization → Marketplace and third-party apps**. Once they approve, come back and say *'connect to my Atlassian'* and I'll finish setting up."

Close the browser, do not retry — the block is org-policy.

#### 4c — Read scope summary, narrate, click Allow

Snapshot the consent page. Extract the human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items, deduplicated):

> "Atlassian is showing the permissions screen — it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|authori[sz]e|grant access)/i>,
  element: "Allow button on the Atlassian consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically — please click **Allow** in the browser window."*

#### 4d — Auto-detect callback completion

Atlassian redirects to Claude Code's localhost callback (Claude Code's MCP runtime owns the listener). Wait for the redirect to complete via `browser_wait_for` on the post-redirect page text — Claude Code typically renders a "Connection complete, you can close this tab" page or similar. No "tell me when you're back" — detect from the snapshot:

```
mcp__playwright__browser_wait_for({
  text: "you can close this tab" OR "connection complete" OR "successfully authenticated",
  time: 600
})
```

If the wait times out (5+ minutes), check in *once* with the user. Do not nag.

### Step 5 — Close the browser + verify

Close Playwright:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection — let me check it works."*

Verify by calling the canonical Atlassian read-only probe:

```
mcp__atlassian__getAccessibleAtlassianResources()
```

The verification depends on whether the MCP server is already active in the current session:

- **Tools available + call returns the user's site(s)** → capture the count, surface a success message including the site name(s).
- **Tools not yet available** (most likely on first setup, since the MCP config was just written and Claude Code hasn't reloaded the tool surface) → tell the user *"All saved. Please close and reopen the chat once, then say 'test my Atlassian' and I'll verify the new connection."*
- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403** → connection works but permission missing — explain that an Atlassian admin or project owner needs to share the relevant resource.

### Success message

Tell the user, in one short message (include the live site count if available):

> "All done! Your Atlassian is now connected — I can see **\<N\> workspace(s)**. You can ask me things like 'show me my Jira tickets', 'what's assigned to me this sprint?', 'create a Confluence page called Release Notes', or 'summarise the latest comments on PROJ-123'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__atlassian__*` MCP tools to answer questions and make changes in Jira and Confluence. The hosted Atlassian Rovo Remote MCP server provides first-party tools covering Jira issues, search, projects, comments, transitions, and Confluence pages, spaces, and search — plus a smaller set of Compass tools for teams that use it.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__atlassian__`. Verified against [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server).

> **Note on tool names:** Atlassian does not publish a stable public list of tool names, and the set evolves as the remote MCP server adds coverage. **Discover tool names at runtime** the first time you enter Phase 2 in a new session — list the `mcp__atlassian__*` tools available and map them to the categories below. The names in the tables below are the expected shape, not a guarantee.

#### Jira — Issues & search

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `search_issues` / `jira_search` | Search Jira issues using JQL or simple filters | User asks "show me my tickets", "open bugs in PROJ", "tickets assigned to me" |
| `get_issue` / `jira_get_issue` | Get full details of a specific Jira issue by key | User asks about a ticket by key (e.g. PROJ-123) |
| `create_issue` / `jira_create_issue` | Create a new Jira issue | User asks to raise a bug, story, task — **confirm first** |
| `update_issue` / `jira_update_issue` | Update fields on an existing issue | User asks to change a ticket — **confirm first** |
| `transition_issue` / `jira_transition_issue` | Move an issue through its workflow (e.g. To Do → In Progress → Done) | User asks to move a ticket's status — **confirm first** |
| `add_comment` / `jira_add_comment` | Add a comment to an issue | User asks to comment on a ticket — **confirm first** |

#### Jira — Projects & metadata

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `list_projects` / `jira_list_projects` | List Jira projects in the connected workspace | User asks "what projects do I have?" or you need a project key before creating an issue |
| `get_project` / `jira_get_project` | Get details of a specific project | User asks about a project |

#### Confluence — Pages & search

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `search_pages` / `confluence_search` | Search Confluence pages by text or CQL | User asks "find the onboarding doc", "search Confluence for X" |
| `get_page` / `confluence_get_page` | Get the body of a Confluence page | User asks to read a specific page |
| `create_page` / `confluence_create_page` | Create a new Confluence page in a given space | User asks to write a new doc — **confirm first** |
| `update_page` / `confluence_update_page` | Update an existing page | User asks to edit a page — **confirm first** |

#### Confluence — Spaces

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `list_spaces` / `confluence_list_spaces` | List Confluence spaces in the connected workspace | User asks "what Confluence spaces do I have?" or you need a space key before creating a page |

#### Identity & verification

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `getAccessibleAtlassianResources` / `list_sites` | List the Atlassian sites the current connection can access | Phase 1 Step 5 verification; "switch my Atlassian workspace" disambiguation |

#### Compass (optional — only if the workspace uses it)

Atlassian's Compass product (software component catalogue) exposes a small set of read-only tools for components and scorecards. Surface these only if the user's workspace has Compass enabled and the consent screen included Compass scopes — otherwise these tools will return permission errors.

> **If a tool name in the tables above does not resolve**, list the available `mcp__atlassian__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Atlassian" / "Set up Jira" / "Set up Confluence" | **Run Phase 1** |
| "Switch my Atlassian workspace" | Re-run Phase 1 from Step 3 — the consent picker resurfaces |
| "My Atlassian stopped working" / "I'm getting auth errors" | Run Phase 1 from Step 3 (Claude Code re-runs the OAuth dance) |
| "Show me my Jira tickets" | `search_issues` with assignee = currentUser() |
| "What's open in [project]?" | `list_projects` (find key) → `search_issues` filtered by project |
| "Show me ticket PROJ-123" | `get_issue` |
| "Create a bug for [description]" | `list_projects` (find key if unknown) → `create_issue` — **confirm first, summarise fields** |
| "Move PROJ-123 to In Progress" | `get_issue` (find available transitions) → `transition_issue` — **confirm first** |
| "Comment on PROJ-123 saying [text]" | `add_comment` — **confirm first, show the text back** |
| "Update the description on PROJ-123" | `update_issue` — **confirm first** |
| "Search Confluence for [topic]" | `search_pages` |
| "Open the onboarding doc in Confluence" | `search_pages` → `get_page` |
| "Create a Confluence page called [title] in [space]" | `list_spaces` (find key if unknown) → `create_page` — **confirm first, summarise content** |
| "Edit the [page] doc to add [section]" | `search_pages` → `get_page` → `update_page` — **confirm first** |
| "What projects are in my Atlassian?" | `list_projects` |
| "What spaces are in my Confluence?" | `list_spaces` |
| "Which Atlassian workspaces am I in?" | `getAccessibleAtlassianResources` |

---

## Error Handling (Phase 2)

When an Atlassian tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / `invalid_token` | "Your Atlassian connection has expired — let me reconnect you." | Walk Phase 1 from Step 3 (Claude Code re-runs OAuth); retry the original tool call |
| 403 Forbidden | "Your Atlassian user doesn't have permission for that project or page. An admin or the page/project owner may need to share it with you." | User asks the owner to grant access; nothing to fix in the connector |
| 404 Not Found (issue / page / project / space) | "I couldn't find that record — let me search for it again." | Use `search_issues` / `search_pages` / `list_projects` / `list_spaces` to refresh |
| 429 Rate limited | "Atlassian is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| Wrong workspace connected | "Looks like we're pointed at a different Atlassian workspace than you meant. Let me switch you over." | Re-run Phase 1 from Step 3, pick the correct workspace on the consent picker |
| `missing_scope` | "I need one more permission to do that. Let me reconnect with the right access." | Re-run Phase 1 from Step 3 with an expanded consent; user re-clicks Allow |
| MCP server not running | "The Atlassian connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| SSE endpoint used / 410 Gone on `/v1/sse` | "Your Atlassian connection is pointing at the old endpoint — let me update it." | Rewrite `mcpServers.atlassian.url` in `~/.claude.json` to `https://mcp.atlassian.com/v1/mcp` and reload |
| Any other API error | "Something went wrong with Atlassian — let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The Atlassian MCP connector **can** do (via the official Atlassian Rovo Remote MCP server):
- Search, read, create, update, comment on, and transition Jira issues
- List Jira projects and read project metadata
- Search Confluence pages and read page bodies
- Create and update Confluence pages
- List Confluence spaces
- Read Compass components and scorecards (if the workspace uses Compass and the relevant scopes were granted)

The Atlassian MCP connector **cannot** do (needs the Atlassian UI or other tools):
- **Cloud only** — Data Center / Server installations are not supported by the official remote MCP server. Self-hosted Atlassian deployments need a different integration path.
- Configure Jira workflows, custom fields, screen schemes, or permission schemes
- Manage Atlassian users, groups, or billing
- Run Jira automations or Forge app configurations
- Export issues or pages in bulk formats (CSV, PDF, Word) — use the Atlassian UI
- Manage multiple Atlassian workspaces in one session — one workspace per OAuth grant per `~/.claude.json` entry (use "switch my Atlassian workspace" to change)
- Access Atlassian products outside of Jira / Confluence / Compass — Bitbucket, Trello, Statuspage, etc. are separate integrations

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, transitioning, or commenting** — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover project and space keys before writing** — Jira projects are referenced by short keys (e.g. `PROJ`) and Confluence spaces by space keys (e.g. `ENG`). Always call `list_projects` / `list_spaces` once per session before any `create_issue` / `create_page` / `update_page`, unless you already have the key from earlier in the conversation.
- **Issue keys are authoritative** — issue keys like `PROJ-123` are the source of truth. Always show the key when summarising tickets so the user can click through to Atlassian directly.
- **Confluence pages can contain sensitive content** — pages often contain internal strategy, HR, or security content. Never paste a full page into a public log or chat without checking with the user first. Prefer summaries over raw excerpts unless asked.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. For Jira searches, include key, summary, status, and assignee by default.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 47 open tickets across 3 projects; 12 are assigned to you, and 4 are in progress"), then offer to show details.
- **Pagination** — default to 25 issues / 10 pages unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — Atlassian Cloud applies per-workspace rate limits. For bulk updates, batch calls and pause between batches.
- **Transitions depend on the workflow** — valid transitions (e.g. "In Progress", "Done", "Blocked") vary per project. Fetch available transitions on the issue before calling `transition_issue`; if the target transition isn't valid, tell the user plainly instead of guessing.
- **Creating or updating pages is visible to the whole space** — Confluence updates notify watchers. For bulk edits, always show the user a sample of the first change before proceeding with the rest.
- **Never log or echo connection details** — never echo the contents of `~/.claude.json` to the user.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **monday-connector**: Sibling autonomous Playwright connector — simpler PAT case
- **slack-connector**: Sibling autonomous Playwright connector — OAuth-app case
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Atlassian consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Atlassian auth or API errors
- **n8n-workflow-patterns**: Build Jira- or Confluence-triggered automations once the connector is live
