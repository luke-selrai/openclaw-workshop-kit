---
name: linear-connector
description: "Connect and operate Linear via the official first-party Linear MCP server (https://mcp.linear.app/mcp). Use this skill when the user asks to set up Linear, connect their issue tracker, or interact with issues, projects, teams, comments, or documentation. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__linear__*, Bash, Read, Write, Edit
metadata:
  category: Project Management & Issue Tracking
  tags:
    - linear
    - issues
    - projects
    - tickets
    - sprints
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Draft follow-ups based on issue updates or status changes
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by Linear issue events
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Linear auth or API errors
---

# Linear Connector

## Overview

This skill lets you read and update a user's Linear workspace on their behalf using the **official first-party Linear MCP server** hosted at `https://mcp.linear.app/mcp` (see [linear.app/changelog/2025-05-01-mcp](https://linear.app/changelog/2025-05-01-mcp) and [linear.app/docs/mcp](https://linear.app/docs/mcp)). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Linear. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Linear is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__linear__*` native tools to read and update Linear data.

**Which phase to run** — Before any tool call, check whether the Linear MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.linear` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the OAuth session is still valid). Otherwise, run Phase 1.

### Authentication — OAuth is the default; API keys are a fallback

The Linear MCP server accepts **two** authentication methods, per Linear's docs:

1. **OAuth 2.1 with Dynamic Client Registration (RFC 7591)** — the default. Clients self-register at runtime; there is no pre-registered app, no client secret to copy, and no personal access token to paste. This is what Phase 1 below walks the user through.
2. **API key / personal access token via `Authorization: Bearer <token>` header** — supported but not the user-friendly path. Use it only if the interactive OAuth flow is blocked (e.g. a headless environment, or a workspace that has disabled third-party OAuth apps). Keys are issued from Linear → Settings → API → Personal API keys.

For a non-technical user, **always attempt Phase 1 (OAuth) first**. Only fall back to API keys if OAuth explicitly fails for a workspace-policy reason — and even then, ask the user whether they are comfortable generating a key before walking them through it.

### What this skill does NOT use

- **A self-hosted Linear MCP server** — Linear publishes the hosted endpoint at `https://mcp.linear.app/mcp` as the only deployment. Self-hosting is not supported.
- **Direct Linear GraphQL API calls** — all reads and writes go through the MCP server, not direct HTTP calls to the Linear API.
- **The legacy `/sse` transport endpoint** — Linear's original SSE endpoint is deprecated. Always use the streamable HTTP endpoint at `https://mcp.linear.app/mcp`.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, GraphQL, or environment variable. If you must refer to a technical thing, name it plainly: "a small setting on your computer", "a sign-in window".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Linear is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Linear MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Linear once in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Linear, I am going to set up the connection on your computer, then ask you to sign in to Linear once in your browser. The whole thing takes about a minute. Ready?"

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the linear MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Linear MCP server is **hosted only** — there is no local transport option. Use this exact entry:

```json
{
  "mcpServers": {
    "linear": {
      "url": "https://mcp.linear.app/mcp"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the linear entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved the connection. Now I just need you to sign in to your Linear once."

### Step 3 — Walk the user through the browser sign-in

The first time the Linear MCP server is contacted, Claude Code will open a browser window asking the user to sign in to Linear and approve the connection. You cannot do this for them — Linear requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please close and reopen Claude Code so the new connection becomes active. Let me know when you're back."

2. When they confirm → "Now say to me: **'connect to my linear now'**. A browser window will pop up asking you to sign in to Linear. Tell me when you see it."

3. When they see the sign-in window → "Sign in with your Linear account, then click **Allow** on the permission screen. Let me know when you're back here."
   - If the user already signed in to Linear recently → "You may not need to type a password — Linear might just show the **Allow** screen straight away. That's fine, just click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."

Common mistakes to look out for (and correct by re-asking):
- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Linear workspace → "I think you might have signed in with a different workspace than you meant to. In your browser, sign out of Linear, then tell me 'try again' and I'll re-trigger the sign-in."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Linear correctly."

Call `mcp__linear__list_teams` with a small page size (e.g. 1 team). If it returns a result, the connection works. Move to the success message.

If the verification tool returns an error:
- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Linear user doesn't have permission for that action. An admin on your Linear workspace may need to adjust your access."
- `429 Rate limited` → "Linear is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Linear connection' and I will verify it."
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message:

> "All done! Your Linear is now connected. You can ask me things like 'show me my open issues', 'what's in the mobile project this sprint?', or 'create a bug report for the login page'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__linear__*` MCP tools below to answer questions and make changes in Linear. The hosted Linear MCP server provides **21 first-party tools** covering issues, projects, teams, users, comments, statuses, labels, and documents.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__linear__`. The [Linear MCP docs](https://linear.app/docs/mcp) describe the server's purpose ("finding, creating, and updating objects in Linear like issues, projects, and comments") but do not enumerate tool names — Linear adds tools over time. The list below reflects the tools advertised at the time of writing; if a name does not resolve after Phase 1, call `tools/list` on the active connection to discover the current inventory.

#### Issue Management

| Tool | Description | Use when |
|---|---|---|
| `list_issues` | List issues across the workspace with filters (team, status, assignee, project) | User asks "show me the bugs", "what's in progress", or needs a pick list |
| `get_issue` | Fetch a single issue by ID or identifier (e.g. `ENG-123`) | User references a specific ticket |
| `create_issue` | Create a new issue | User asks to file a bug, task, or feature — **confirm first** |
| `update_issue` | Edit an issue (title, description, status, assignee, priority, labels) | User asks to change a ticket — **confirm first** |
| `list_my_issues` | List issues assigned to the authenticated user | User asks "what am I working on", "what's on my plate" |

#### Project & Team Coordination

| Tool | Description | Use when |
|---|---|---|
| `list_projects` | List projects in the workspace | User asks "what projects do we have", or needs a project ID |
| `get_project` | Fetch a single project by ID | User asks about a specific project |
| `create_project` | Create a new project | User asks to start a new initiative — **confirm first** |
| `update_project` | Edit a project (name, description, status, lead, dates) | User asks to change a project — **confirm first** |
| `list_teams` | List teams in the workspace | Verification call, or user asks "who's on what team" |
| `get_team` | Fetch a single team by ID | User references a specific team |
| `list_users` | List users in the workspace | User asks "who can I assign this to", or needs a user ID |
| `get_user` | Fetch a single user by ID | User asks about a specific teammate's workload |

#### Comments, Statuses, Labels, Documents

| Tool | Description | Use when |
|---|---|---|
| `list_comments` | List comments on an issue | User asks "what's the latest on ENG-123" |
| `create_comment` | Add a comment to an issue | User asks to leave a note on a ticket — **confirm first** |
| `list_issue_statuses` | List possible statuses for a team (Backlog, Todo, In Progress, Done, etc.) | Before `update_issue` when changing status |
| `get_issue_status` | Fetch a single status by ID | Verifying a specific workflow state |
| `list_issue_labels` | List labels available for issues | Before `create_issue` or `update_issue` when adding labels |
| `get_document` | Fetch a Linear document by ID | User references a spec or design doc |
| `list_documents` | List documents in a project or workspace | User asks "what docs do we have" |
| `search_documentation` | Search Linear documentation (help center content) | User asks "how do I use Linear's X feature" |

> **Note:** If a tool call returns "tool not found", the server's inventory may have changed — call `tools/list` on the live MCP session to see the current names.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Linear" / "Help me set up Linear" | **Run Phase 1** |
| "Show me my open issues" / "What am I working on?" | `list_my_issues` |
| "What's in the backlog for the mobile team?" | `list_teams` → `list_issues` (team filter, status=Backlog) |
| "Show me ENG-123" / "What's the status of that login bug?" | `get_issue` |
| "Create a bug report for the login page" | `list_teams` → `list_issue_labels` → `create_issue` — **confirm first** |
| "Move ENG-123 to In Progress and assign it to Jane" | `list_users` → `list_issue_statuses` → `update_issue` — **confirm first** |
| "What projects are active?" | `list_projects` |
| "Tell me about the Q2 roadmap project" | `list_projects` → `get_project` |
| "Start a new project called 'Customer Portal'" | `create_project` — **confirm first, summarise fields** |
| "Who's on the engineering team?" | `list_teams` → `list_users` |
| "What's the latest on ENG-123?" | `get_issue` → `list_comments` |
| "Leave a note on ENG-123 saying I'll pick it up tomorrow" | `create_comment` — **confirm first** |
| "Show me the PRD for the checkout rework" | `list_documents` → `get_document` |
| "How do I use Linear's triage feature?" | `search_documentation` |

---

## Error Handling (Phase 2)

When a Linear tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Linear sign-in has expired — let me reconnect you." | Re-trigger the OAuth flow (Phase 1, Step 3) |
| 403 Forbidden | "Your Linear user doesn't have permission for that team or project. A workspace admin may need to adjust your access." | User talks to a workspace admin; nothing to fix in the connector |
| 404 Not Found (issue / project / user) | "I couldn't find that record — let me search again." | Use `list_issues` or `list_projects` to refresh the list |
| 429 Rate limited | "Linear is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. Linear applies per-workspace rate limits — for bulk operations, batch and pause. |
| MCP server not running | "The Linear connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with Linear — let me try again." | Retry once; if still failing, re-do the sign-in |

---

## Scope Limitations

The Linear MCP connector **can** do (via the official Linear MCP server):
- List, read, create, and update issues across teams and projects
- List and manage projects (create, edit metadata, status, leads, dates)
- Inspect teams, users, statuses, and labels
- Read and post comments on issues
- Read Linear documents and search Linear's documentation

The Linear MCP connector **cannot** do (needs the Linear UI or other tools):
- Manage workspace billing, seat counts, or plan changes
- Configure SSO, SCIM, or identity provider settings
- Create or delete teams (team creation is admin-only via UI)
- Manage workflow states / custom issue statuses beyond reading them
- Configure Linear's GitHub/GitLab/Slack integrations
- Export issues in CSV / PDF format (use the Linear UI)
- Trigger Linear automation rules directly (rules fire on issue events)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, editing, or commenting** — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover IDs before writing** — Linear teams, projects, users, statuses, and labels are referenced by their IDs. Always call the relevant `list_*` tool once per session before any `create_*` or `update_*`, unless you already have the ID from earlier in the conversation.
- **Issue identifiers are human-readable** — Linear issues have identifiers like `ENG-123` or `DES-45` alongside their internal ID. Accept either from the user, but confirm which one you used before a mutation.
- **Status names are per-team** — each team defines its own workflow states. Always call `list_issue_statuses` for the target team before `update_issue` when changing status; do not assume "In Progress" has the same ID across teams.
- **Labels are workspace-scoped or team-scoped** — always call `list_issue_labels` before applying labels so you use the right ID.
- **Mentions and assignees** — use `list_users` to look up the right user ID before assigning; never guess from a display name.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. For issue lists, show at minimum: identifier, title, status, assignee.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 23 open issues across 4 teams; 7 are assigned to you"), then offer to show details.
- **Pagination** — default to 25 issues unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — Linear applies per-workspace rate limits. For bulk operations (e.g. bulk-closing stale issues), batch `update_issue` calls and pause between batches.
- **Bulk updates are destructive** — closing, re-assigning, or deleting many issues at once is hard to reverse. Always show the user a sample of the first change before proceeding with the rest, and prefer to act in batches of 5–10 with a confirmation between batches.
- **Never log or echo credentials** — there is no token to leak (OAuth is handled by Claude Code), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Linear auth or API errors
- **monday-connector**: Sibling project-management connector — same MCP bootstrap pattern for Monday.com
- **jotform-connector**: Sibling data-collection connector — identical hosted-MCP wiring pattern
- **n8n-workflow-patterns**: Build Linear-triggered automations once the connector is live
