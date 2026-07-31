---
name: github-connector
description: "Connect GitHub to Claude by installing and authenticating its official remote MCP server. Use when the user asks to set up or connect GitHub, or wants GitHub work (repositories, issues, pull requests, commits, releases, Actions runs, code search) and GitHub isn't connected yet. Once connected, GitHub runs directly through the mcp__github__* tools."
allowed-tools: mcp__github__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Developer Tools & Integrations
  tags:
    - github
    - git
    - repositories
    - issues
    - pull-requests
    - actions
    - mcp
  pairs-with:
    - skill: airtable-connector
      reason: Sibling Pattern-2 connector - same autonomous Playwright PAT-mint shape
    - skill: monday-connector
      reason: Canonical Pattern-2 reference - same hosted-bearer-PAT install pattern
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting GitHub auth or API errors
---

# GitHub Connector

> **Install pattern:** Hosted-bearer-PAT - see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (monday-connector).

## Overview

This skill lets you read and update a user's GitHub account on their behalf using the **official first-party GitHub remote MCP server** hosted by GitHub at `https://api.githubcopilot.com/mcp`. It has two phases:

- **Phase 1 - Install & Auth (autonomous).** Claude drives the entire `github.com/settings/personal-access-tokens/new` flow inside a Playwright MCP browser. The user does at most two things: sign in to GitHub once when prompted, and complete any 2FA challenge their account requires. Everything else - filling the token name, picking expiration, picking Repository access, walking the Repository permissions list to set Contents / Issues / Pull requests to the correct level, clicking *Generate token*, reading the fine-grained Personal Access Token from the DOM, registering the MCP server with the token as a Bearer header - is autonomous. The user never copies, never pastes, never reads a token aloud, never opens a tab themselves.
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__github__*` native tools to read and update GitHub data.

**Which phase to run** - Before any tool call, check whether the GitHub MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.github` entry with a `url` containing `api.githubcopilot.com` and `headers.Authorization`. If it exists, treat the connector as configured and skip to Phase 2 (verify with one tool call before assuming the session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **`gh` CLI** - the GitHub CLI is a separate tool for terminal users. It is not an MCP server and cannot be driven by Claude directly in the Phase 2 tool-call style. Do not install it.
- **`@modelcontextprotocol/server-github`** - this old npm package is **deprecated as of April 2025**. Do not use it. Use the official remote server at `api.githubcopilot.com/mcp`.
- **Docker / `ghcr.io/github/github-mcp-server`** - the local container version is supported by GitHub but requires Docker Desktop to be installed and running. Skip it unless the user has a specific reason to run locally (GitHub Enterprise Server, offline environment, etc.). The remote server is strictly simpler.
- **OAuth flow with Client ID / Client Secret / redirect URI** - GitHub supports OAuth for hosts that have a registered GitHub App, but Claude Code does not have one. We use a fine-grained Personal Access Token (PAT) passed as a Bearer header, which is universally supported.
- **GitHub Enterprise Server** - deferred. GHES does not support the remote server; it needs the local Docker version with a `--gh-host` flag. Out of scope for this version.

### How auth works under the hood

The hosted GitHub MCP server accepts a fine-grained Personal Access Token (PAT) passed in an `Authorization: Bearer <token>` header. Claude drives the entire token mint via Playwright at `https://github.com/settings/personal-access-tokens/new` - no copy/paste in the happy path, no OAuth callback. This works on personal accounts, organisations the user has access to, and GitHub Free / Pro / Team / Enterprise Cloud plans.

---

## Communication rules for Phase 1

The user is a non-technical business owner or a developer who does not want to think about configuration. Phase 1 is autonomous - Claude does the work. The user only signs in to GitHub once (and answers 2FA if challenged). Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to the browser window I just opened" and (if challenged) "please approve the 2FA prompt on your phone."
- **Plain English only.** No jargon. Never say MCP, PAT, token, Bearer, HTTP, API, scope, OAuth, terminal, command, bash, CLI, config file, JSON, endpoint, environment variable, Playwright, browser automation, or DOM. If you must name a technical concept, plainly:
  - Personal Access Token (PAT) → **"your GitHub access key"**
  - Repository permissions / scopes → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - The Playwright browser → **"the browser window I just opened for you"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start, once when you need them ("please sign in" / "please approve the 2FA prompt"), once when you're done. No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your GitHub is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **No fabricated UI assertions.** Don't reference button colours or specific positioning - verify from the live snapshot. GitHub's settings UI changes (the fine-grained PAT page has shifted permission groupings during 2025-2026).
- **Never echo the access key** back to the user. Never include it in any output visible to the user.

---

## PHASE 1 - Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only role is signing in to GitHub when prompted (and only the first time - the persistent Playwright profile keeps the session for future runs) and approving any 2FA challenge their account requires. Claude handles every other step - navigation, form fills, permission selection, token capture from DOM, MCP registration, verify.

> **Why fine-grained PAT (not OAuth, not classic PAT):** Fine-grained PATs let the user (and the SKILL on their behalf) pick exact per-permission read/write levels - matching the read-only-vs-read-and-write choice - and scope the key to specific repositories. OAuth would require a registered GitHub App for Claude Code (none exists) and a localhost callback that Playwright can't easily proxy. Classic PATs work, but their permission model is coarse-grained "all-or-nothing scopes" and GitHub flags them as legacy. Fine-grained is the cleaner single-path solution.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Contents permission dropdown and set it to Read-only"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form` / `browser_select_option` / `browser_type`. Match permission rows by their visible labels ("Contents", "Issues", "Pull requests"), not by selector paths - GitHub's settings UI changes.

### Step 1 - Orient the user and ask read-only vs read-and-write

Tell the user, in one short message:

> "I'll connect your GitHub now. First - do you want me to just **read** your GitHub (browse repos, view issues, read pull requests), or do you want me to also be able to **make changes** for you (create issues, open pull requests, push code)? Read-only is safer to start."

Wait for their answer. Remember their choice - it controls which level you select for each permission row in Step 5.

- **Read-only** → Contents (Read-only), Issues (Read-only), Pull requests (Read-only). Metadata (Read-only - GitHub auto-selects this).
- **Read + write** → Contents (Read and write), Issues (Read and write), Pull requests (Read and write). Metadata (Read-only).

### Step 2 - Open the token page and confirm a logged-in session

Tell the user, in one short message:

> "Opening a browser window for you - please sign in to GitHub when it appears (and approve any 2FA prompt). I'll do the rest. About a minute."

Call `mcp__playwright__browser_navigate({ url: "https://github.com/settings/personal-access-tokens/new" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see the "New fine-grained personal access token" form with a Token name input) → continue to Step 3.
- **Not logged in** (sign-in form, "Sign in to GitHub") → poll silently with `mcp__playwright__browser_wait_for({ text: "New fine-grained personal access token" })` (or "Token name"). Do not ask the user to confirm; detect login completion yourself.
- **2FA challenge appears** (text like "Two-factor authentication", "Verify", "Authenticator app", "Confirm sign in") → poll silently with `mcp__playwright__browser_wait_for({ text: "New fine-grained personal access token" })`. The 2FA action happens on the user's phone or hardware key; the SKILL just waits for the post-2FA settings page to load.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 - Fill the token name

Locate the "Token name" / "Name" input in the snapshot and type via `browser_type` or `browser_fill_form`:

- **Name** → `"Claude Assistant"`

### Step 4 - Pick expiration

Locate the "Expiration" dropdown / select control in the snapshot. Pick **90 days** (`browser_select_option`). This balances safety (auto-rotation) with not bothering the user too often. If a "Custom" or "No expiration" option exists and 90 days is unavailable on the user's plan, fall back to the longest reasonable preset.

### Step 5 - Pick Repository access

Locate the "Repository access" section. Click **"All repositories"** via `browser_click` (preferred - works for repos the user has now or adds later, and across orgs they have access to).

If "All repositories" is not available (some Enterprise org policies disable it), fall back to "Public repositories (read-only)" or, last resort, "Only select repositories" with no repos pre-selected - and warn the user briefly that you couldn't pick all repos so they may need to widen access later.

### Step 6 - Set Repository permissions

Locate the "Repository permissions" section. It is a list of permission rows; each row has a label on the left and a dropdown / select on the right with options like *No access*, *Read-only*, *Read and write*. For each of the three permissions below, find the matching row and set it to the level matching the user's Step 1 choice via `browser_click` (open the dropdown) → `browser_click` (pick the option) - or `browser_select_option` if the control is a native `<select>`.

- **Contents** → Read-only or Read and write
- **Issues** → Read-only or Read and write
- **Pull requests** → Read-only or Read and write

GitHub auto-selects **Metadata: Read-only** when any other repository permission is chosen - leave it as-is. Re-snapshot after each set to confirm state changed.

If the permission rows are paginated or collapsed under category headers, click the category header to expand, or look for a search/filter input and type the permission name to filter the list.

### Step 7 - Generate the token

Locate the "Generate token" submit button at the bottom of the form (it is typically a green button). Click via `browser_click`.

If GitHub shows a confirmation modal (occasional second-factor sudo-prompt before token creation), snapshot it. If it asks for password / 2FA again, narrate once: *"GitHub is asking to confirm - please approve on your phone."* Then `browser_wait_for` the post-confirmation page.

Poll `mcp__playwright__browser_wait_for({ text: "github_pat_" })` (or wait for the token-reveal screen - GitHub's fine-grained PAT page renders the new token in a copyable readonly input near the top).

### Step 8 - Capture the access token

The post-creation screen displays the fine-grained PAT (starts with `github_pat_`). Read it via `browser_evaluate`:

```
() => {
  const candidates = [...document.querySelectorAll('input, code, textarea, pre, [data-testid*="token"], [class*="token"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (/^github_pat_[A-Za-z0-9_]+$/.test(v) && v.length >= 50) return v;
    if (/^ghp_[A-Za-z0-9_]+$/.test(v) && v.length >= 40) return v;
  }
  return null;
}
```

If the token is masked behind a "Copy" or "Show" button, click it via `browser_click`, re-snapshot, then re-evaluate.

**Validation (silent):**
- Token must start with `github_pat_` (fine-grained) or `ghp_` (classic - only if GitHub falls back to classic for some account types)
- Fine-grained: token must be ≥ 50 characters; classic: ≥ 40 characters

**Conversational fallback** - if two snapshot attempts don't surface a valid token (e.g., GitHub has moved the token reveal to a non-DOM-readable toast on this account), narrate once: *"I'm having trouble reading the access key automatically - could you paste it for me? It starts with `github_pat_`."* Wait for the user to paste, validate the shape, and continue. The token transits the transcript in this fallback path; that's an accepted trade-off documented in [skills/CLAUDE.md](../CLAUDE.md) Pattern 2 → "Conversational fallback".

### Step 9 - Save the connection (silent)

Silently register the MCP server with the PAT as a Bearer header. **Prefer `claude mcp add-json` via Bash** (default for Mac / Linux / Windows with Claude Code 2.1.1+):

```bash
claude mcp add-json github '{"type":"http","url":"https://api.githubcopilot.com/mcp","headers":{"Authorization":"Bearer <token captured in Step 8>"}}' --scope user
```

**Windows fallback** - if `add-json` returns `Invalid input` (known quirk on Windows for HTTP servers), use the legacy transport-flag form instead:

```bash
claude mcp add github --transport http https://api.githubcopilot.com/mcp/ -H "Authorization: Bearer <token>" --scope user
```

**Last-resort fallback if `claude mcp add` fails for any reason other than "already exists"** - write directly to `~/.claude.json`:

<details>
<summary>Direct JSON write</summary>

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object - never overwrite. If `~/.claude.json` doesn't exist, create it. If corrupt, back up to `~/.claude.json.backup` first.

Never echo the access key back to the user. Never include it in any output visible to the user. Never paste the contents of `~/.claude.json` to the user.

### Step 10 - Close the browser, verify, success message

`mcp__playwright__browser_close()`.

Tell the user: *"Saved - let me check it works."*

- **If `mcp__github__*` tools are available**: call `mcp__github__get_me`. Capture the username and deliver the success message:

  > "All done! I am now connected to your GitHub account **[@username]**. You can ask me things like *'show me my repositories'*, *'list open issues in [repo name]'*, or *'what are my recent pull requests?'*. Give it a try!"

- **If tools not available**: *"All saved. Please close and reopen Claude Code once, then say 'test my GitHub' and I'll verify."*

If verification returns `401 Unauthorized` / `Bad credentials`, the most likely cause is a partial token capture. Re-run Steps 7-9 to mint a fresh token. If verification returns `403 Forbidden` on a write operation the user expects to work, the most likely cause is the user picked Read-only in Step 1 - guide them: *"Your access key is read-only. Want me to refresh it with write access?"* and re-run from Step 1.

---

## PHASE 2 - Use Tools

Once the connector is configured, use the `mcp__github__*` MCP tools to answer questions and make changes in GitHub. The remote GitHub MCP server exposes ~85 tools grouped into toolsets. The default toolsets (enabled automatically when you connect) cover repos, issues, pull requests, context, and users - roughly 80% of everyday GitHub work. The remote server also auto-enables the other toolsets listed below.

### Tool Reference

Tool names follow the pattern `mcp__github__<tool_name>`. The tables below list the tools by toolset and when to use each.

#### Context (who am I?)

| Tool | Description | Use when |
|---|---|---|
| `get_me` | Get the authenticated user's profile | User asks "who am I connected as?" or you need to verify the connection |
| `get_team_members` | List members of an org team | User asks who is on a specific team |
| `get_teams` | List the authenticated user's teams | User asks "what teams am I in?" |

#### Repos

| Tool | Description | Use when |
|---|---|---|
| `search_repositories` | Search repositories by query | User asks "what repos do I have?" or "find repos about X" |
| `get_file_contents` | Read a file or list a directory in a repo | User asks to see code or a file from a repo |
| `list_branches` | List branches in a repo | User asks what branches exist |
| `list_commits` | List commits on a branch | User asks for recent commits |
| `get_commit` | Get full details of one commit | User asks about a specific SHA |
| `search_code` | Full-text code search across GitHub | User asks to find code matching a term |
| `list_releases` | List releases in a repo | User asks about releases |
| `get_latest_release` | Get the latest release | User asks "what's the latest version of X?" |
| `get_release_by_tag` | Get a release by tag name | User asks about a specific version tag |
| `list_tags` | List tags in a repo | User asks what tags exist |
| `get_tag` | Get a specific tag | User asks about a specific tag |
| `create_repository` | Create a new repository | User asks to create a repo - **confirm first** |
| `fork_repository` | Fork a repository | User asks to fork - **confirm first** |
| `create_branch` | Create a branch | User asks to create a branch - **confirm first** |
| `create_or_update_file` | Create or update a single file | User asks to add or edit one file - **confirm first** |
| `push_files` | Push multiple files in one commit | User asks to commit several files - **confirm first** |
| `delete_file` | Delete a file in a repo | User asks to delete a file - **confirm first** |
| `get_repository_tree` | Get the full file tree of a repo | You need to browse repo structure |

#### Issues

| Tool | Description | Use when |
|---|---|---|
| `list_issues` | List issues in a repo | User asks to see issues |
| `search_issues` | Search issues with GitHub query syntax | User asks to find issues by keyword, label, assignee |
| `issue_read` | Get details of an issue (supports `get`, `get_comments`, `get_sub_issues`, `get_labels`) | User asks about a specific issue |
| `issue_write` | Create or update an issue (`create`, `update`) | User asks to create or edit an issue - **confirm first** |
| `add_issue_comment` | Add a comment to an issue | User asks to comment on an issue - **confirm first** |
| `sub_issue_write` | Add / remove / reprioritize sub-issues | User asks to manage sub-issues - **confirm first** |
| `list_issue_types` | List available issue types in an org | User asks what types are configured |

#### Pull Requests

| Tool | Description | Use when |
|---|---|---|
| `list_pull_requests` | List PRs in a repo | User asks to see PRs |
| `search_pull_requests` | Search PRs with GitHub query syntax | User asks to find PRs by author, label, state |
| `pull_request_read` | Get details of a PR (metadata, files, reviews, diff) | User asks to review a specific PR |
| `create_pull_request` | Open a new pull request | User asks to create a PR - **confirm first** |
| `update_pull_request` | Edit a PR's title, body, state, or base | User asks to edit a PR - **confirm first** |
| `merge_pull_request` | Merge a PR | User asks to merge - **DOUBLE-CONFIRM - irreversible** |
| `update_pull_request_branch` | Update a PR's branch with base | User asks to sync a PR with main - **confirm first** |
| `pull_request_review_write` | Create / submit / delete a PR review | User asks to approve, request changes, or comment on a PR - **confirm first** |
| `add_comment_to_pending_review` | Add a review comment to a pending review | User is writing a multi-comment review - **confirm first** |
| `add_reply_to_pull_request_comment` | Reply to a PR comment | User asks to reply on a PR thread - **confirm first** |

#### Users

| Tool | Description | Use when |
|---|---|---|
| `search_users` | Search GitHub users | User asks to find a user by name or handle |

#### Secondary toolsets (auto-enabled on the remote server)

| Toolset | What it covers | Key tools |
|---|---|---|
| **actions** | GitHub Actions workflows, runs, jobs, logs | `actions_list`, `actions_get`, `actions_run_trigger`, `get_job_logs` |
| **notifications** | Your GitHub inbox | `list_notifications`, `get_notification_details`, `dismiss_notification`, `mark_all_notifications_read` |
| **gists** | Gists (code snippets) | `list_gists`, `get_gist`, `create_gist`, `update_gist` |
| **labels** | Repo labels | `list_label`, `get_label`, `label_write` |
| **orgs** | Organizations | `search_orgs` |
| **projects** | GitHub Projects (v2) | `projects_list`, `projects_get`, `projects_write` |
| **discussions** | GitHub Discussions | `list_discussions`, `get_discussion`, `get_discussion_comments`, `list_discussion_categories` |
| **code_security** | Code Scanning alerts | `list_code_scanning_alerts`, `get_code_scanning_alert` |
| **dependabot** | Dependabot alerts | `list_dependabot_alerts`, `get_dependabot_alert` |
| **secret_protection** | Secret scanning alerts | `list_secret_scanning_alerts`, `get_secret_scanning_alert` |
| **security_advisories** | Global and repo security advisories | `list_global_security_advisories`, `get_global_security_advisory`, `list_repository_security_advisories` |
| **stargazers** | Starring repos | `list_starred_repositories`, `star_repository`, `unstar_repository` |
| **copilot** | Copilot coding agent assignment | `assign_copilot_to_issue`, `request_copilot_review` |

> **Note:** If a tool name does not resolve, the server version may have renamed it. Older names are preserved as aliases in most cases. If you hit an unknown-tool error, try listing available tools with the `mcp__github__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "What repos do I have?" | `search_repositories` (filter by user) |
| "Show me open issues in acme/widget" | `list_issues` (state: open) |
| "Find issues about login bug" | `search_issues` |
| "Create an issue in acme/widget saying X" | `issue_write` (method: create) - **confirm first** |
| "Show me open PRs in acme/widget" | `list_pull_requests` (state: open) |
| "Review PR #42 in acme/widget" | `pull_request_read` (method: get, then get_files / get_reviews) |
| "Create a PR from feat/foo to main" | `create_pull_request` - **confirm first** |
| "Merge PR #42" | `merge_pull_request` - **DOUBLE-CONFIRM** |
| "Show me recent commits in acme/widget" | `list_commits` |
| "Search for `useState` in acme/widget" | `search_code` |
| "Show me the README of acme/widget" | `get_file_contents` (path: README.md) |
| "What's the latest release of acme/widget?" | `get_latest_release` |
| "Create a branch called feat/foo in acme/widget" | `create_branch` - **confirm first** |
| "Push this file to acme/widget" | `create_or_update_file` - **confirm first** |
| "Show me failed GitHub Actions runs on acme/widget" | `actions_list` (method: list_workflow_runs, filter by status) |
| "Why did the CI fail on run 12345?" | `get_job_logs` (failed_only: true) |
| "Who am I connected as?" | `get_me` |
| "Show me my notifications" | `list_notifications` |
| "Star this repo" | `star_repository` - **confirm first** |
| "Connect my GitHub" / "Help me set up GitHub" | **Run Phase 1** |

---

## Error Handling (Phase 2)

When a GitHub tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Bad credentials | "Your GitHub connection has expired or the access key was revoked - let me reconnect you." | Re-run Phase 1 from Step 2 (Playwright re-mints a fresh token) |
| 403 Forbidden / Insufficient permission | "I need an extra permission to do that - let me refresh your access." | If user picked Read-only in Step 1 and now wants to write, re-run Phase 1 with read-and-write. Otherwise the user may need to widen Repository access - re-run Phase 1 and pick a broader scope at Step 5. |
| 404 Not Found on a repo the user owns | "I can't see that repo. Either the name is slightly off, or the access key is limited to a different set of repositories." | Either correct the repo name, or re-run Phase 1 and widen Repository access at Step 5 |
| 422 Unprocessable Entity | "GitHub rejected that request - the input may be invalid. Let me check and try again." | Read the error body, fix the input, retry once |
| 429 / secondary rate limit | "GitHub is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| Tool not available (MCP server not running) | "The GitHub connection isn't active yet. Please fully close Claude Code and open it again so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with GitHub - let me try again." | Retry once; if still failing, re-run Phase 1 to mint a fresh token |

---

## Scope Limitations

The GitHub MCP connector **can** do (via the default + auto-enabled remote toolsets):

- Read and write repositories, files, branches, commits, releases, tags
- Create and manage issues, comments, labels, and sub-issues
- Create, review, update, and merge pull requests
- Read and trigger GitHub Actions workflows, read job logs
- Browse notifications and dismiss them
- Create and update gists
- Read discussions, projects, and organization data
- Read code scanning, Dependabot, and secret scanning alerts
- Star and unstar repositories
- Search code, repos, issues, PRs, users, and orgs

The GitHub MCP connector **cannot** do (deferred):

- GitHub Enterprise Server (requires local Docker version with `--gh-host` flag)
- Admin operations on organizations (billing, member management, SSO)
- Delete repositories (use the GitHub UI - irreversible)
- File uploads larger than GitHub's REST API limits
- Webhook management
- GitHub App installation or management
- Anything the user's access key does not have permission for - re-run Phase 1 to widen permissions and retry

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before writes** - creating issues, opening PRs, pushing files, creating branches, creating repositories, adding comments, changing labels. Summarise what you are about to do and wait for the user's OK before calling the tool.
- **Double-confirm merges.** Merging a PR is irreversible - re-summarise the target branch, the commit count, and ask explicitly: "Are you sure you want me to merge this into main? This cannot be undone." Wait for an explicit yes.
- **Read-only by default.** List and get operations (`list_issues`, `get_file_contents`, `list_commits`, etc.) do not need confirmation - run them freely when the user asks.
- **Never log or echo credentials.** The access key must never appear in any output visible to the user.
- **Identify repos as `owner/repo`.** GitHub's tools take `owner` and `repo` as separate parameters. If the user says "my widget repo", use `get_me` first to get their username, then try `owner=<username>, repo=widget`. Fall back to `search_repositories` if that fails.
- **Default pagination to 10-30 items.** Do not dump 100-item lists. Summarise first, offer to show more.
- **Present data clearly.** Format results as readable tables or short summaries, not raw JSON.
- **Issue and PR numbers are integers.** Do not confuse them with commit SHAs (hex strings) or pull request IDs (internal GraphQL IDs).
- **Respect read-only mode.** If the user picked read-only in Phase 1 and then asks for a write operation, remind them: "Your access key is read-only. Want me to refresh it with write access?" Do not attempt the write - re-run Phase 1 if they say yes.
- **Rate limits.** The remote GitHub MCP server inherits GitHub's REST rate limit (5,000 requests/hour for authenticated PATs). Hitting this is rare in normal use; if it happens, wait and retry.
- **Large repos.** For `get_file_contents` on a directory with hundreds of entries, warn the user and ask if they want the full list or just a filtered subset.

---

## Related Skills

- **orientation**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting GitHub auth or API errors
- **airtable-connector**, **monday-connector**: Sibling Pattern-2 connectors - same autonomous Playwright PAT-mint shape
- **github-actions-pipeline-builder**: Complementary skill for designing GitHub Actions workflows (this skill operates them; that skill designs them)
