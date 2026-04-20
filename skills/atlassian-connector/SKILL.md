---
name: atlassian-connector
description: "Connect and operate Atlassian (Jira + Confluence, plus Compass) via the official first-party Atlassian Remote MCP server (https://mcp.atlassian.com/v1/mcp). Use this skill when the user asks to set up Atlassian, connect Jira or Confluence, or interact with issues, tickets, sprints, boards, pages, or spaces. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__atlassian__*, Bash, Read, Write, Edit
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
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Atlassian auth or API errors
---

# Atlassian Connector (Jira + Confluence)

## Overview

This skill lets you read and update a user's Atlassian Cloud workspace on their behalf — Jira, Confluence, and Compass — using the **official first-party Atlassian Remote MCP server** hosted at `https://mcp.atlassian.com/v1/mcp` (see [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Atlassian where they also pick which workspace (site) to connect. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Atlassian is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__atlassian__*` native tools to read and update Jira and Confluence data.

**Which phase to run** — Before any tool call, check whether the Atlassian MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.atlassian` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the OAuth session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **Atlassian API tokens** — the Atlassian Remote MCP server **requires OAuth 2.1 for every user on first connect**. Bearer-token / API-token access to the remote MCP server is not supported. Do not ask the user for an API token.
- **The legacy `/v1/sse` endpoint** — Atlassian's SSE endpoint sunsets **30 June 2026**. Always use the current streamable endpoint at `https://mcp.atlassian.com/v1/mcp`.
- **A self-hosted Atlassian MCP server** — Atlassian publishes the hosted endpoint at `https://mcp.atlassian.com/v1/mcp` as the primary deployment. Always use the hosted URL.
- **Direct Jira / Confluence REST API calls** — all reads and writes go through the MCP server, not direct HTTP calls.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a small setting on your computer", "a sign-in window", "your Atlassian workspace".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Atlassian is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Atlassian MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Atlassian once in their browser and picks which workspace to connect.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Atlassian — that covers Jira and Confluence — I am going to set up the connection on your computer, then ask you to sign in to Atlassian once in your browser. When you sign in, you'll also pick which workspace you want me to use. The whole thing takes about a minute. Ready?"

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the atlassian MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Atlassian Remote MCP server is **hosted only** — there is no local transport option. Use this exact entry:

```json
{
  "mcpServers": {
    "atlassian": {
      "url": "https://mcp.atlassian.com/v1/mcp"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the atlassian entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

> **Do not use `https://mcp.atlassian.com/v1/sse`** — Atlassian's SSE endpoint sunsets 30 June 2026. The streamable endpoint above is the only one you should wire in.

Tell the user: "I have saved the connection. Now I just need you to sign in to your Atlassian once."

### Step 3 — Walk the user through the browser sign-in

The first time the Atlassian MCP server is contacted, Claude Code will open a browser window asking the user to sign in to Atlassian and approve the connection. You cannot do this for them — Atlassian requires their authenticated session, and they also need to **choose which workspace (site) to connect** on the Allow screen.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please close and reopen Claude Code so the new connection becomes active. Let me know when you're back."

2. When they confirm → "Now say to me: **'connect to my atlassian now'**. A browser window will pop up asking you to sign in to Atlassian. Tell me when you see it."

3. When they see the sign-in window → "Sign in with your Atlassian email and password. On the next screen you'll see an **Allow** button, and above it a **picker for which Atlassian workspace to connect** — if you have more than one (for example, separate workspaces for different teams or clients), pick the one that has the Jira and Confluence you want me to work with, then click **Allow**. Let me know when you're back here."
   - If the user already signed in to Atlassian recently → "You may not need to type a password — Atlassian might just show the **Allow** screen straight away with the workspace picker. That's fine, just make sure the correct workspace is selected and click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."
   - If the user only has one Atlassian workspace → "You might not see a picker at all — that just means there's only one workspace on your account, so Atlassian skips the choice. Go ahead and click **Allow**."

Common mistakes to look out for (and correct by re-asking):
- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Atlassian account → "I think you might have signed in with a different email than you meant to. In your browser, sign out of Atlassian, then tell me 'try again' and I'll re-trigger the sign-in."
- The user picked the wrong workspace on the Allow screen → "No worries — tell me 'switch my atlassian workspace' and I'll re-trigger the sign-in. When you get to the Allow screen again, pick the correct workspace before clicking Allow."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Atlassian correctly."

Call a read-only Atlassian tool to verify the connection. Tool names aren't publicly documented — discover them at runtime by listing the `mcp__atlassian__*` tools available in the current session and pick a safe read-only one (for example, a "list accessible resources" / "list sites" tool, or a simple Jira issue search with no filters). If it returns a result (including an empty list — that's fine), the connection works. Move to the success message.

If the verification tool returns an error:
- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Atlassian user doesn't have permission for that action. An admin on your Atlassian workspace may need to adjust your access, or the project may not be shared with your account."
- `429 Rate limited` → "Atlassian is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Atlassian connection' and I will verify it."
- Wrong workspace visible → "Looks like we connected to a different workspace than you meant. Tell me 'switch my atlassian workspace' and I'll re-run the sign-in so you can pick the right one."
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message:

> "All done! Your Atlassian is now connected — that covers your Jira and Confluence. You can ask me things like 'show me my Jira tickets', 'what's assigned to me this sprint?', 'create a Confluence page called Release Notes', or 'summarise the latest comments on PROJ-123'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__atlassian__*` MCP tools to answer questions and make changes in Jira and Confluence. The hosted Atlassian Remote MCP server provides first-party tools covering Jira issues, search, projects, comments, transitions, and Confluence pages, spaces, and search — plus a smaller set of Compass tools for teams that use it.

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

#### Compass (optional — only if the workspace uses it)

Atlassian's Compass product (software component catalogue) exposes a small set of read-only tools for components and scorecards. Surface these only if the user's workspace has Compass enabled — otherwise these tools will return permission errors.

> **If a tool name in the tables above does not resolve**, list the available `mcp__atlassian__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Atlassian" / "Set up Jira" / "Set up Confluence" | **Run Phase 1** |
| "Switch my Atlassian workspace" | Re-run Phase 1 Step 3 so the user can pick a different workspace on the Allow screen |
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

---

## Error Handling (Phase 2)

When an Atlassian tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Atlassian sign-in has expired — let me reconnect you." | Re-trigger the OAuth flow (Phase 1, Step 3) |
| 403 Forbidden | "Your Atlassian user doesn't have permission for that project or page. An admin or the page/project owner may need to share it with you." | User asks the owner to grant access; nothing to fix in the connector |
| 404 Not Found (issue / page / project / space) | "I couldn't find that record — let me search for it again." | Use `search_issues` / `search_pages` / `list_projects` / `list_spaces` to refresh |
| 429 Rate limited | "Atlassian is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. |
| Wrong workspace connected | "Looks like we're pointed at a different Atlassian workspace than you meant. Let me switch you over." | Re-run Phase 1 Step 3 so the user picks a different workspace on the Allow screen |
| MCP server not running | "The Atlassian connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| SSE endpoint used / 410 Gone on `/v1/sse` | "Your Atlassian connection is pointing at the old endpoint — let me update it." | Rewrite the `mcpServers.atlassian.url` in `~/.claude.json` to `https://mcp.atlassian.com/v1/mcp` and restart |
| Any other API error | "Something went wrong with Atlassian — let me try again." | Retry once; if still failing, re-do the sign-in |

---

## Scope Limitations

The Atlassian MCP connector **can** do (via the official Atlassian Remote MCP server):
- Search, read, create, update, comment on, and transition Jira issues
- List Jira projects and read project metadata
- Search Confluence pages and read page bodies
- Create and update Confluence pages
- List Confluence spaces
- Read Compass components and scorecards (if the workspace uses Compass)

The Atlassian MCP connector **cannot** do (needs the Atlassian UI or other tools):
- **Cloud only** — **Data Center / Server installations are not supported by the official remote MCP server.** Self-hosted Atlassian deployments need a different integration path (manual REST API wrapper, community MCP, or a Jira/Confluence plugin inside the server).
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
- **Never log or echo credentials** — there is no token to leak (OAuth is handled by Claude Code), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Atlassian auth or API errors
- **jotform-connector**: Sibling OAuth-based hosted-MCP connector — same bootstrap pattern for a different platform
- **monday-connector**: Sibling project-management connector — similar conversational install
- **notion-connector**: Sibling docs / workspace connector — similar conversational install
- **n8n-workflow-patterns**: Build Jira- or Confluence-triggered automations once the connector is live
