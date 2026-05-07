---
name: github-connector
description: "Connect and operate GitHub via the official GitHub remote MCP server. Use this skill when the user asks to set up GitHub, connect their GitHub account, or interact with repositories, issues, pull requests, commits, branches, releases, Actions workflows, or code search. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__github__*, Bash, Read, Write, Edit
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
    - skill: xero-connector
      reason: Sibling connector — same "walk the user through one-time setup in plain English" flow
    - skill: quickbooks-connector
      reason: Sibling connector — same conversational-bootstrap pattern
    - skill: square-connector
      reason: Sibling connector — same Phase 1/Phase 2 structure
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting GitHub auth or API errors
---

# GitHub Connector

> **Install pattern:** Hosted-bearer-PAT — see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (monday-connector).

## Overview

This skill lets you read and update a user's GitHub account on their behalf using the **official first-party GitHub remote MCP server** hosted by GitHub at `https://api.githubcopilot.com/mcp`. It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤5 steps). The user has never used this before. You walk them through creating a Personal Access Token in GitHub, collecting it, and wiring the GitHub MCP server into Claude Code. The user should never see the words "MCP", "PAT", "token", "HTTP", "Bearer", "scope", "API", "JSON", "terminal", or any file paths. They should feel like they are having a conversation, and at the end their GitHub is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__github__*` native tools to read and update GitHub data.

**Which phase to run** — Before any tool call, check whether the GitHub MCP server is already configured. Run `claude mcp list` (silently) and look for a `github` entry, or read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.github` entry with a `url` containing `api.githubcopilot.com`. If it exists, treat the connector as authenticated and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **`gh` CLI** — the GitHub CLI is a separate tool for terminal users. It is not an MCP server and cannot be driven by Claude directly in the Phase 2 tool-call style. Do not install it.
- **`@modelcontextprotocol/server-github`** — this old npm package is **deprecated as of April 2025**. Do not use it. Use the official remote server at `api.githubcopilot.com/mcp`.
- **Docker / `ghcr.io/github/github-mcp-server`** — the local container version is supported by GitHub but requires Docker Desktop to be installed and running. Skip it unless the user has a specific reason to run locally (GitHub Enterprise Server, offline environment, etc.). The remote server is strictly simpler.
- **OAuth flow with Client ID / Client Secret / redirect URI** — GitHub supports OAuth for hosts that have a registered GitHub App, but Claude Code does not have one. We use a Personal Access Token (PAT) passed as a Bearer header, which is universally supported.
- **GitHub Enterprise Server** — deferred. GHES does not support the remote server; it needs the local Docker version with a `--gh-host` flag. Out of scope for this version.

---

## Communication rules for Phase 1

The user is a non-technical business owner or a developer who does not want to think about configuration. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say MCP, PAT, token, Bearer, HTTP, API, scope, OAuth, terminal, command, bash, CLI, config file, JSON, endpoint, or environment variable. If you must refer to a technical thing, name it plainly: "a GitHub access key", "a small setting on your computer".
- **Say "GitHub access key" instead of "token" or "PAT".** Say "permissions" instead of "scopes". Say "close Claude Code and open it again" instead of "restart".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your GitHub is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the access key back to the user** after they paste it. Never include it in any visible output.

---

## PHASE 1 — Install & Auth (≤5 steps)

This phase gets the Personal Access Token created, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only provides information and clicks things in their browser.

### Step 1 — Orient the user and ask about read vs. write

Tell the user, in one short message:

> "To connect your GitHub, I need you to create a free GitHub access key. This takes about three minutes. First — do you want me to just **read** your GitHub (browse repos, view issues, read pull requests), or do you want me to also be able to **make changes** for you (create issues, open pull requests, push code)? Read-only is safer to start."

Wait for their answer. Remember their choice — it controls which permission boxes they will tick in Step 2.

- **Read-only** → Contents (read), Issues (read), Pull requests (read), Metadata (read — this one is required and selects itself).
- **Read + write** → Contents (read and write), Issues (read and write), Pull requests (read and write), Metadata (read).

### Step 2 — Walk the user through creating a GitHub access key

The user needs to create a fine-grained Personal Access Token in GitHub. You cannot do this step for them — GitHub requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please open this page in your browser: **https://github.com/settings/personal-access-tokens/new** — and sign in with your GitHub account. Let me know when you see the 'New fine-grained personal access token' form."

2. When they confirm → "For **Token name**, type: **Claude Assistant**. Then tell me when you are done."

3. When they confirm → "For **Expiration**, pick **90 days** if you want to renew it every few months, or **No expiration** if you prefer to set it once and forget. Which one do you want?" Wait for their answer.

4. When they pick an expiration → "Scroll down to **Repository access**. Choose **All repositories** if you want me to work across all your repos, or **Only select repositories** if you only want me to touch specific ones — then pick them from the list. Let me know when you have chosen."

5. When they confirm → "Now scroll down to **Repository permissions**. I will tell you which boxes to tick, one at a time." Then, based on their answer from Step 1:

   **For read-only:**
   - "Find **Contents** — click the dropdown on the right and change it from **No access** to **Read-only**. Tell me when done."
   - "Find **Issues** — change it to **Read-only**."
   - "Find **Pull requests** — change it to **Read-only**."
   - "**Metadata** will already say **Read-only** — that one is required, leave it as is."

   **For read + write:**
   - "Find **Contents** — click the dropdown on the right and change it to **Read and write**. Tell me when done."
   - "Find **Issues** — change it to **Read and write**."
   - "Find **Pull requests** — change it to **Read and write**."
   - "**Metadata** will already say **Read-only** — leave that one alone."

6. When they confirm → "Now scroll to the bottom and click the green **Generate token** button."

7. When they confirm → "You should now see your **access key** — it starts with `github_pat_` (or `ghp_` for classic tokens). Please copy it and paste it to me. **Important: this is the only time GitHub will show you the key — if you close the page without copying, you will have to start over.**"

Common mistakes to look out for (and correct by re-asking):
- The user pasted a placeholder like `your_token_here` → "I think that was a copy mistake — please try the real value that starts with `github_pat_` or `ghp_`."
- The user pasted something that does not start with `github_pat_` or `ghp_` → "That doesn't look quite right. The value I need starts with `github_pat_` and is quite long. Can you check and try again?"
- The user says they cannot find Repository permissions → "It is below the Expiration and Repository access sections. Keep scrolling down — you will see a list of permission categories like Actions, Contents, Issues, Pull requests, etc."
- The user closed the page without copying → "No problem — we just need to make a new one. Please go back to **https://github.com/settings/personal-access-tokens/new** and start again. You can use the same settings."

### Step 3 — Save the connection

Once the user pastes the access key, silently run one of the following commands from Bash — **do not mention the command to the user**:

**Default (Mac / Linux / Windows with Claude Code 2.1.1+):**
```bash
claude mcp add-json github '{"type":"http","url":"https://api.githubcopilot.com/mcp","headers":{"Authorization":"Bearer <TOKEN>"}}'
```

**Windows fallback** — if `add-json` returns `Invalid input` (known quirk on Windows for HTTP servers), use the legacy transport-flag form instead:
```bash
claude mcp add github --transport http https://api.githubcopilot.com/mcp/ -H "Authorization: Bearer <TOKEN>"
```

Replace `<TOKEN>` with the access key the user just pasted. Never log or echo the key back.

If both forms fail for a reason other than "already exists", fall back to editing `~/.claude.json` directly and adding this entry to the `mcpServers` object:

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp",
      "headers": {
        "Authorization": "Bearer <TOKEN>"
      }
    }
  }
}
```

Merge this into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the GitHub entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved your connection details. Now I need you to close Claude Code completely and open it again — that is how the new connection becomes active."

### Step 4 — Ask the user to restart Claude Code

Tell the user, in one short message:

> "Please fully close Claude Code (not just this window — the whole app), then open it again, then come back and say **'test my GitHub connection'**. I will check everything is working."

Wait for them to come back. When they do, move to Step 5.

### Step 5 — Verify the connection and celebrate

Call `mcp__github__get_me` to verify the connection. The response includes the user's GitHub login (username) and name.

- **If the call succeeds** — capture the username and deliver the success message:

  > "All done! I am now connected to your GitHub account **[@username]**. You can ask me things like *'show me my repositories'*, *'list open issues in [repo name]'*, or *'what are my recent pull requests?'*. Give it a try!"

- **If the tools are not yet available** (the user may not have fully restarted) — tell them: "It looks like Claude Code has not fully picked up the new connection yet. Please fully close the app and open it again, then try once more."

- **If the call returns an authentication error** (`401 Unauthorized` / `Bad credentials`) — tell them: "The access key didn't work. Could you double-check it? Let's go back to **https://github.com/settings/personal-access-tokens** and make a fresh one." Then re-do Steps 2 and 3 with the new key.

- **If the call returns a permission error** (`403 Forbidden`) — tell them: "Your connection is working, but the key does not have enough permissions for that. Let me tell you which box to tick." Guide them to **https://github.com/settings/personal-access-tokens**, click on **Claude Assistant**, add the missing permission, click **Update**, then retry.

- **Any other error** — "Something went wrong — let me try again." Retry once; if still failing, ask the user to confirm the key is still listed in their GitHub settings.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__github__*` MCP tools to answer questions and make changes in GitHub. The remote GitHub MCP server exposes ~85 tools grouped into toolsets. The default toolsets (enabled automatically when you connect) cover repos, issues, pull requests, context, and users — roughly 80% of everyday GitHub work. The remote server also auto-enables the other toolsets listed below.

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
| `create_repository` | Create a new repository | User asks to create a repo — **confirm first** |
| `fork_repository` | Fork a repository | User asks to fork — **confirm first** |
| `create_branch` | Create a branch | User asks to create a branch — **confirm first** |
| `create_or_update_file` | Create or update a single file | User asks to add or edit one file — **confirm first** |
| `push_files` | Push multiple files in one commit | User asks to commit several files — **confirm first** |
| `delete_file` | Delete a file in a repo | User asks to delete a file — **confirm first** |
| `get_repository_tree` | Get the full file tree of a repo | You need to browse repo structure |

#### Issues

| Tool | Description | Use when |
|---|---|---|
| `list_issues` | List issues in a repo | User asks to see issues |
| `search_issues` | Search issues with GitHub query syntax | User asks to find issues by keyword, label, assignee |
| `issue_read` | Get details of an issue (supports `get`, `get_comments`, `get_sub_issues`, `get_labels`) | User asks about a specific issue |
| `issue_write` | Create or update an issue (`create`, `update`) | User asks to create or edit an issue — **confirm first** |
| `add_issue_comment` | Add a comment to an issue | User asks to comment on an issue — **confirm first** |
| `sub_issue_write` | Add / remove / reprioritize sub-issues | User asks to manage sub-issues — **confirm first** |
| `list_issue_types` | List available issue types in an org | User asks what types are configured |

#### Pull Requests

| Tool | Description | Use when |
|---|---|---|
| `list_pull_requests` | List PRs in a repo | User asks to see PRs |
| `search_pull_requests` | Search PRs with GitHub query syntax | User asks to find PRs by author, label, state |
| `pull_request_read` | Get details of a PR (metadata, files, reviews, diff) | User asks to review a specific PR |
| `create_pull_request` | Open a new pull request | User asks to create a PR — **confirm first** |
| `update_pull_request` | Edit a PR's title, body, state, or base | User asks to edit a PR — **confirm first** |
| `merge_pull_request` | Merge a PR | User asks to merge — **DOUBLE-CONFIRM — irreversible** |
| `update_pull_request_branch` | Update a PR's branch with base | User asks to sync a PR with main — **confirm first** |
| `pull_request_review_write` | Create / submit / delete a PR review | User asks to approve, request changes, or comment on a PR — **confirm first** |
| `add_comment_to_pending_review` | Add a review comment to a pending review | User is writing a multi-comment review — **confirm first** |
| `add_reply_to_pull_request_comment` | Reply to a PR comment | User asks to reply on a PR thread — **confirm first** |

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
| "Create an issue in acme/widget saying X" | `issue_write` (method: create) — **confirm first** |
| "Show me open PRs in acme/widget" | `list_pull_requests` (state: open) |
| "Review PR #42 in acme/widget" | `pull_request_read` (method: get, then get_files / get_reviews) |
| "Create a PR from feat/foo to main" | `create_pull_request` — **confirm first** |
| "Merge PR #42" | `merge_pull_request` — **DOUBLE-CONFIRM** |
| "Show me recent commits in acme/widget" | `list_commits` |
| "Search for `useState` in acme/widget" | `search_code` |
| "Show me the README of acme/widget" | `get_file_contents` (path: README.md) |
| "What's the latest release of acme/widget?" | `get_latest_release` |
| "Create a branch called feat/foo in acme/widget" | `create_branch` — **confirm first** |
| "Push this file to acme/widget" | `create_or_update_file` — **confirm first** |
| "Show me failed GitHub Actions runs on acme/widget" | `actions_list` (method: list_workflow_runs, filter by status) |
| "Why did the CI fail on run 12345?" | `get_job_logs` (failed_only: true) |
| "Who am I connected as?" | `get_me` |
| "Show me my notifications" | `list_notifications` |
| "Star this repo" | `star_repository` — **confirm first** |
| "Connect my GitHub" / "Help me set up GitHub" | **Run Phase 1** |

---

## Error Handling (Phase 2)

When a GitHub tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Bad credentials | "Your GitHub connection has expired or the access key was revoked — let me help you reconnect." | Run Phase 1 from Step 2 (create a new access key) |
| 403 Forbidden / Insufficient permission | "I need an extra permission to do that. Let me walk you through adding it." | Guide user to **https://github.com/settings/personal-access-tokens** → click **Claude Assistant** → adjust Repository permissions → Update. No restart needed. |
| 404 Not Found on a repo the user owns | "I can't see that repo. Either the name is slightly off, or the access key is limited to a different set of repositories." | Either correct the repo name, or guide the user to widen **Repository access** on their access key |
| 422 Unprocessable Entity | "GitHub rejected that request — the input may be invalid. Let me check and try again." | Read the error body, fix the input, retry once |
| 429 / secondary rate limit | "GitHub is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| Tool not available (MCP server not running) | "The GitHub connection isn't active yet. Please fully close Claude Code and open it again so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with GitHub — let me try again." | Retry once; if still failing, check the key is still listed in GitHub settings |

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
- Delete repositories (use the GitHub UI — irreversible)
- File uploads larger than GitHub's REST API limits
- Webhook management
- GitHub App installation or management
- Anything the user's access key does not have permission for — add the permission in GitHub settings and retry

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before writes** — creating issues, opening PRs, pushing files, creating branches, creating repositories, adding comments, changing labels. Summarise what you are about to do and wait for the user's OK before calling the tool.
- **Double-confirm merges.** Merging a PR is irreversible — re-summarise the target branch, the commit count, and ask explicitly: "Are you sure you want me to merge this into main? This cannot be undone." Wait for an explicit yes.
- **Read-only by default.** List and get operations (`list_issues`, `get_file_contents`, `list_commits`, etc.) do not need confirmation — run them freely when the user asks.
- **Never log or echo credentials.** The access key must never appear in any output visible to the user.
- **Identify repos as `owner/repo`.** GitHub's tools take `owner` and `repo` as separate parameters. If the user says "my widget repo", use `get_me` first to get their username, then try `owner=<username>, repo=widget`. Fall back to `search_repositories` if that fails.
- **Default pagination to 10–30 items.** Do not dump 100-item lists. Summarise first, offer to show more.
- **Present data clearly.** Format results as readable tables or short summaries, not raw JSON.
- **Issue and PR numbers are integers.** Do not confuse them with commit SHAs (hex strings) or pull request IDs (internal GraphQL IDs).
- **Respect read-only mode.** If the user set up read-only in Phase 1 and then asks for a write operation, remind them: "Your access key is read-only. I can walk you through upgrading it if you want." Do not attempt the write.
- **Rate limits.** The remote GitHub MCP server inherits GitHub's REST rate limit (5,000 requests/hour for authenticated PATs). Hitting this is rare in normal use; if it happens, wait and retry.
- **Large repos.** For `get_file_contents` on a directory with hundreds of entries, warn the user and ask if they want the full list or just a filtered subset.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting GitHub auth or API errors
- **xero-connector**, **quickbooks-connector**, **square-connector**: Sibling connectors — same Phase 1 / Phase 2 structure for different platforms
- **github-actions-pipeline-builder**: Complementary skill for designing GitHub Actions workflows (this skill operates them; that skill designs them)
