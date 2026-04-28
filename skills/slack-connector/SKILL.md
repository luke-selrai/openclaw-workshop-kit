---
name: slack-connector
description: "Connect and operate a user's Slack workspace via the slack-mcp-server npm package (korotovsky/slack-mcp-server, the most widely adopted Slack MCP server with 1,500+ GitHub stars and 12,000+ weekly npm downloads). Use this skill when the user asks to set up Slack, connect their workspace, post to a channel, read channel history, react to a message, search for users, or manage user groups. On first use, run Phase 1 — Claude drives app creation, scope setup, and install end-to-end via Playwright; the user only signs in to Slack once and clicks 'Allow' on the consent screen."
allowed-tools: mcp__slack__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Communication & Collaboration
  tags:
    - slack
    - messaging
    - channels
    - workspace
    - mcp
  pairs-with:
    - skill: hubspot-connector
      reason: Post CRM updates (new deals, contact changes) to a Slack channel
    - skill: github-connector
      reason: Announce pull request activity or CI results in a Slack channel
    - skill: square-connector
      reason: Post daily sales summaries or refund alerts to a Slack channel
    - skill: xero-connector
      reason: Post invoice paid / overdue alerts to a finance Slack channel
---

# Slack Connector

## Overview

This skill lets you read from and post to a user's Slack workspace on their behalf using the **`slack-mcp-server`** npm package ([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth.** An autonomous bootstrap. Claude drives a Playwright-MCP browser through Slack's app-creation flow: signs in (with the user's help), creates the Slack app, configures all six bot token scopes, installs to workspace, captures the Bot User OAuth Token directly from the DOM, and registers the MCP server. The user's only actions are signing in to Slack once and clicking "Allow" on the workspace consent screen. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", "Bot Token", "scope", "xoxb", "Playwright", "browser automation", or any file paths.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__slack__*` native tools to list channels, read history, post messages, search users, manage user groups, and react.

**Which phase to run** — Before any tool call, check whether the Slack MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.slack` entry. If it exists and has a `SLACK_MCP_XOXB_TOKEN` in its `env` block, treat the connector as authenticated and skip to Phase 2. Otherwise, run Phase 1.

### Why this package

We chose `slack-mcp-server` (korotovsky) over `@zencoderai/slack-mcp-server` (the maintained fork of Anthropic's archived reference server) because:
- **24× more npm downloads** (12,100/week vs 506/week as of April 2026)
- **Actively maintained** (v1.2.3, last published March 2026 vs v0.0.1, last published July 2025)
- **More tools** (14 vs 8) — adds user search, user groups, reactions remove, `#channel-name` lookup
- **Write-safety by default** — posting and reactions are disabled unless explicitly opted in via environment variable
- **No Team ID required** — simpler setup (4 steps vs 5)
- **npx-compatible** — has a `bin` entry (`slack-mcp-server` → `bin/index.js`), works identically to the hubspot/xero/github pattern

### What this skill does NOT use

- **Anthropic's archived `@modelcontextprotocol/server-slack`** — deprecated on npm as of April 2025. Do not install.
- **`@zencoderai/slack-mcp-server`** — the maintained fork of Anthropic's reference server. Legitimate but stale (v0.0.1, last published July 2025) and significantly fewer features. Superseded by korotovsky for this kit.
- **User tokens (`xoxp-`) or browser session tokens (`xoxc`/`xoxd`)** — we only use a Bot User OAuth Token (`xoxb-`). No stealth mode, no cookie extraction. Some tools (search, unreads) require `xoxp-` and are documented as unavailable with the default setup.
- **Slack Incoming Webhooks or the RTM API** — the MCP server wraps the Web API directly.
- **A hosted Slack MCP endpoint** — Slack does not publish one. We run the server locally via `npx`.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work. The user only signs in to Slack and clicks "Allow" once. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, type field values, copy text, or paste tokens. The only actions you ever request are "please sign in to Slack" and "please click Allow on the consent screen."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, Bot Token, xoxb, MCP, endpoint, JSON, environment variable, Playwright, or browser automation. If you must refer to a technical thing, name it plainly:
  - Bot User OAuth Token → **"your Slack key"**
  - Scopes → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - Slack app → **"a small connection app inside your Slack"**
  - The Playwright browser → **"the browser window I just opened for you"**
- **Narrate at boundaries, not inside tool sequences.** Tell the user once when you start, once when you need them ("please sign in" / "please click Allow"), once when you're done. No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Slack is now connected." Bad: "MCP server initialized, `channels_list` returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo the Slack key back to the user** after capturing it.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude drives the entire app creation, scope configuration, and install via Playwright MCP. The user's only actions are signing in to Slack once and clicking "Allow" on the workspace consent screen — Slack genuinely requires both. All other steps (creating the app, naming it, adding the six bot token scopes, installing to workspace, capturing the Bot User OAuth Token) are Claude-driven.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the scope-add control"). Achieve it by `mcp__playwright__browser_snapshot` → reason about the page → call `browser_click` / `browser_evaluate` / `browser_navigate` / `browser_select_option`. Do not hardcode CSS selectors — Slack's admin UI changes regularly. Re-snapshot whenever the page state changes.

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your Slack now. I'm opening a browser window — please sign in to Slack there, and I'll set up a small connection app for you. About a minute. Which workspace should I connect?"

Wait for the workspace name. If they have multiple workspaces, you'll use this name to disambiguate the workspace dropdown later.

### Step 2 — Open the Slack app dashboard and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://api.slack.com/apps" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see "Your Apps" header, "Create New App" button, list of existing apps) → continue to Step 3.
- **Not logged in** (sign-in form, marketing page) → tell the user *once*: *"The browser window is open — please sign in to Slack when you're ready."* Then poll silently with `browser_wait_for({ text: "Create New App" })` (or any logged-in shell element from a fresh snapshot). Do not ask the user to confirm; detect login completion yourself. SSO, 2FA, and email-link logins all resolve to the same dashboard.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 — Create the app

From the apps dashboard, locate the "Create New App" button in the snapshot and click it via `browser_click`. A modal appears — snapshot, then click "From scratch".

Fill the resulting form via `browser_fill_form` (or individual `browser_type` calls):
- **App Name** → `"Claude Assistant"`
- **Pick a workspace** → match the workspace name the user gave in Step 1 against the dropdown options; if multiple workspaces partially match, list them in plain English and ask the user to pick.

Click "Create App". Snapshot to confirm you've landed on the app's "Basic Information" page (shows app name, app credentials, etc.).

### Step 4 — Navigate to OAuth & Permissions

Locate "OAuth & Permissions" in the left sidebar from the snapshot. Click it. Snapshot to confirm the page heading reads "OAuth & Permissions".

### Step 5 — Add the six Bot Token Scopes

Locate the "Bot Token Scopes" section (usually below "User Token Scopes"). For each scope below, click "Add an OAuth Scope", type the scope into the searchable select that appears, then click the matching option:

- `channels:history`
- `channels:read`
- `chat:write`
- `reactions:write`
- `users:read`
- `users.profile:read`

After each addition, re-snapshot to confirm the scope chip appears in the Bot Token Scopes list. If a scope fails to add (typo'd, search didn't surface it), retry the click on the matching option from a fresh snapshot.

### Step 6 — Install to workspace

Scroll to the top of the OAuth & Permissions page (use `browser_evaluate({ function: "() => window.scrollTo(0, 0)" })` if needed). Locate the install control:

- **"Install to Workspace"** button visible → click it. Slack redirects to a consent screen. Tell the user *once*: *"Slack is asking for your permission — please click 'Allow' in the browser to finish."* Then `browser_wait_for({ text: "Bot User OAuth Token" })` to detect the post-install OAuth & Permissions page.
- **"Request to Install"** button (workspace requires admin approval) → click it (this sends the request), then stop and tell the user: *"Your workspace requires an admin to approve the connection. I've sent the request. Please ask your admin to approve it, then say 'continue connecting Slack' once they have."* Do not proceed to Step 7 until they confirm.

### Step 7 — Capture the Bot User OAuth Token

You should now be on the post-install OAuth & Permissions page, which displays the Bot User OAuth Token (starts with `xoxb-`). Read it via `browser_evaluate`:

```
() => {
  const candidates = [...document.querySelectorAll('input, code, textarea, [data-testid*="token"], [class*="token"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (v.startsWith('xoxb-') && v.length > 50) return v;
  }
  return null;
}
```

If the token is masked behind a "Copy" or "Show" button, click it via `browser_click`, re-snapshot, then re-evaluate.

**Validation (silent):**
- Token must start with `xoxb-`
- Token must be longer than 50 characters

If two snapshot attempts don't surface a valid token, stop and ask the user: *"I'm having trouble finding the Slack key on the page — could you describe what's visible?"*

### Step 8 — Save the connection (silent)

Silently register the MCP server. **Prefer `claude mcp add` via Bash** — it's the official path and handles JSON merging.

```bash
claude mcp add slack \
  --scope user \
  --env SLACK_MCP_XOXB_TOKEN="<token captured in Step 7>" \
  --env SLACK_MCP_ADD_MESSAGE_TOOL="true" \
  -- npx -y slack-mcp-server
```

`SLACK_MCP_ADD_MESSAGE_TOOL=true` enables posting messages and adding reactions (off by default in the server for safety). To restrict posting to specific channels later, set this to a comma-separated list of channel IDs instead.

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) — write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`):

<details>
<summary>Direct JSON write</summary>

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "slack-mcp-server"],
      "env": {
        "SLACK_MCP_XOXB_TOKEN": "<token>",
        "SLACK_MCP_ADD_MESSAGE_TOOL": "true"
      }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object — never overwrite. If `~/.claude.json` doesn't exist, create it. If it's corrupt, back up to `~/.claude.json.backup` first.

Never echo the Slack key back to the user. Never include it in any output visible to the user. Never log it to the conversation, even truncated.

### Step 9 — Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"Saved — let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__slack__*` tools are available**: call `mcp__slack__channels_list({ channel_types: "public_channel", limit: 5 })`. If it returns a list, capture the count and move to Step 10.
- **If the tools are not yet available** (most likely on first setup): tell the user *"All saved. Please close and reopen Claude Code once so the connection becomes active, then come back and say 'test my Slack' — I'll verify it."*

If verification returns an error:
- `invalid_auth` / `not_authed` → "The connection key didn't take — let me grab a fresh one." Re-run Steps 2–8 against the same Slack app (clicking "Reinstall to Workspace" instead of "Install to Workspace") and overwrite the config.
- `missing_scope` → "I need one more permission to do that. Let me add it." Re-run Step 5 to add the missing scope, then click "Reinstall to Workspace" in Step 6 to refresh the token, capture the new token, update the config.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, re-run Steps 2–8.

### Step 10 — Success message

Tell the user, in one short message:

> "All done! I'm now connected to your Slack. I can see **[N] channels**. You can ask me 'what are the latest messages in #general?' or 'post a hello message to #announcements'. Give it a try!"

---

## Token rotation (no full re-setup needed)

If a user's Slack key stops working (revoked, regenerated, or they want to switch workspaces), they do NOT need to redo the entire app creation. Drive a shorter Playwright flow:

1. Tell the user: *"I'll refresh your Slack connection. Opening the browser now — please sign in if asked, and click 'Allow' on the consent screen when it appears."*
2. `mcp__playwright__browser_navigate({ url: "https://api.slack.com/apps" })`. Detect login the same way as Phase 1 Step 2 (poll `browser_wait_for` for the apps dashboard).
3. Locate "Claude Assistant" in the apps list from the snapshot and click it.
4. Click "OAuth & Permissions" in the left sidebar.
5. Locate and click "Reinstall to Workspace". Tell the user *once*: *"Please click 'Allow' in the browser."* Poll `browser_wait_for` for the post-install screen.
6. Capture the new `xoxb-` token via `browser_evaluate` (same selector pattern as Phase 1 Step 7). Validate.
7. Silently update **only** the `SLACK_MCP_XOXB_TOKEN` value in `~/.claude.json` — do not touch any other env vars or the rest of the config. Use `claude mcp remove slack && claude mcp add slack ...` (with the new token, preserving `SLACK_MCP_ADD_MESSAGE_TOOL=true`) or edit the JSON directly.
8. `mcp__playwright__browser_close()`.
9. Tell the user: *"Updated. Please close and reopen Claude Code once, then say 'test my Slack' and I'll verify the new key."*

If the user says "I have a new Slack key" or "my Slack stopped working", start this rotation flow rather than running full Phase 1.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__slack__*` MCP tools below to answer questions and take action in Slack. The `slack-mcp-server` provides tools covering channel listing, message history, thread replies, posting, reactions, user search, and user group management.

### Tool Reference

The MCP server exposes tools with the prefix `mcp__slack__`. The tool names follow korotovsky's naming convention (not the zencoderai `slack_*` convention).

#### Channels

| Tool | Description | Use when |
|---|---|---|
| `channels_list` | List channels by type (`public_channel`, `private_channel`, `im`, `mpim`), sorted optionally by popularity, paginated by cursor (up to 999 per page) | User asks "what channels do we have?" or you need to confirm a channel exists before posting |

#### Reading messages

| Tool | Description | Use when |
|---|---|---|
| `conversations_history` | Get messages from a channel by channel ID or `#name`. Supports smart pagination by date (`1d`, `7d`, `30d`) or count (`50`). Optional: include activity messages like join/leave. | User asks "what's happening in #general?" or "show me the last week of messages in sales" |
| `conversations_replies` | Get all replies in a message thread, given channel ID or `#name` and parent `thread_ts`. Same smart pagination as `conversations_history`. | User asks "show me the replies on that message" or you need to read a full thread |

#### Posting messages (confirm first)

| Tool | Description | Use when |
|---|---|---|
| `conversations_add_message` | Post a new message to a channel OR reply in a thread. Accepts channel ID or `#name`. If `thread_ts` is provided, it replies in the thread; otherwise it posts to the channel. Supports `text/markdown` and `text/plain` content types. **Disabled by default** — enabled via `SLACK_MCP_ADD_MESSAGE_TOOL` env var (already set to `"true"` in our config). | User asks "post a message to #announcements" or "reply in that thread saying..." — **confirm first, showing the exact channel and text** |

#### Reactions (confirm first)

| Tool | Description | Use when |
|---|---|---|
| `reactions_add` | Add an emoji reaction to a message (channel ID or `#name` + message timestamp + emoji name without colons, e.g. `thumbsup`). **Disabled by default** — same env var enables it. | User asks "react with a thumbs up" — **confirm first** |
| `reactions_remove` | Remove an emoji reaction from a message (channel ID or `#name` + message timestamp + emoji name). Same env var enables it. | User asks "remove that reaction" — **confirm first** |

#### Users

| Tool | Description | Use when |
|---|---|---|
| `users_search` | Search for users by name, email, or display name. Returns user ID, username, real name, display name, email, title, and DM channel ID. Default limit: 10, max: 100. | User asks "who is Jane Doe?" or "find the user with email jane@example.com" |

#### User groups

| Tool | Description | Use when |
|---|---|---|
| `usergroups_list` | List all user groups (subteams) in the workspace. Optional: include member lists, member counts, disabled groups. | User asks "what user groups do we have?" |
| `usergroups_create` | Create a new user group with name, handle, description, and default channels. Requires `usergroups:write` scope. | User asks "create a user group called Engineering" — **confirm first** |
| `usergroups_update` | Update an existing user group's name, handle, description, or default channels. Requires `usergroups:write` scope. | User asks "rename that user group" — **confirm first** |
| `usergroups_users_update` | Replace all members of a user group with a new list. Requires `usergroups:write` scope. | User asks "add these people to the Engineering group" — **confirm first** |
| `usergroups_me` | List groups you're in, join a group, or leave a group. | User asks "what groups am I in?" or "join the Engineering group" |

#### Not available with xoxb- bot tokens

These tools exist in the server but require a User OAuth Token (`xoxp-`) instead of a bot token. They are **not available with the default setup**:

| Tool | Description | Why unavailable |
|---|---|---|
| `conversations_search_messages` | Search messages across the workspace with filters (date, user, channel, thread). Rich query support. | Slack's `search.messages` API does not support bot tokens (`xoxb-`). Requires a `xoxp-` User OAuth Token. |
| `conversations_unreads` | Get unread messages across all channels with priority sorting (DMs > partner channels > internal). | Best with browser tokens; fallback with `xoxp-`. Not available with `xoxb-`. |

If a user asks to search messages, tell them: "Message search is available in this server, but it needs a different type of Slack key that requires extra setup. For now, I can read the recent history of a specific channel instead — which channel should I look in?"

> **Note:** Tool names are from `slack-mcp-server` v1.2.3. If a tool name does not resolve, try listing available tools with the `mcp__slack__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "What channels do we have?" / "List my Slack channels" | `channels_list` with `channel_types: "public_channel"` |
| "Show me private channels too" | `channels_list` with `channel_types: "public_channel,private_channel"` |
| "What's happening in #general?" | `conversations_history` with `channel_id: "#general"` |
| "Show me the last week of messages in sales" | `conversations_history` with `channel_id: "#sales"`, `limit: "7d"` |
| "Show me the last 20 messages in #announcements" | `conversations_history` with `channel_id: "#announcements"`, `limit: "20"` |
| "Show me the replies on that message" | `conversations_replies` with `channel_id` and `thread_ts` |
| "Post 'hello team' to #announcements" | `conversations_add_message` with `channel_id: "#announcements"`, `payload: "hello team"` — **confirm first** |
| "Reply to that message saying thanks" | `conversations_add_message` with `channel_id`, `thread_ts`, `payload: "thanks"` — **confirm first** |
| "React with a thumbs up to the latest message in #general" | `conversations_history` → `reactions_add` with `emoji: "thumbsup"` — **confirm first** |
| "Remove that reaction" | `reactions_remove` — **confirm first** |
| "Who is Jane Doe?" / "Find the user with that email" | `users_search` with `query` |
| "What user groups do we have?" | `usergroups_list` |
| "What groups am I in?" | `usergroups_me` with `action: "list"` |
| "Search for messages about the marketing report" | Tell user this requires a different Slack key type. Offer `conversations_history` on a specific channel instead. |
| "Connect my Slack" / "Help me set up Slack" | **Run Phase 1** |
| "I have a new Slack key" / "My Slack stopped working" | **Run token rotation** (see section above) |

---

## Error Handling (Phase 2)

When a Slack tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| `invalid_auth` / `not_authed` | "Your Slack connection key isn't being accepted. Let me help you reconnect." | Run token rotation flow (not full Phase 1). Guide user to reinstall the app and copy a fresh key. |
| `missing_scope` | "I need one more permission to do that. Let me walk you through adding it." | Guide user to Slack app → OAuth & Permissions → add the missing scope → **Reinstall to Workspace** → retry. No restart needed. |
| `channel_not_found` | "I couldn't find that channel — let me list the ones I can see." | Call `channels_list` to confirm available channels; the bot may not be invited to private channels |
| `not_in_channel` | "I can see that channel but I haven't been invited to it yet. In Slack, type `/invite @Claude Assistant` in that channel and try again." | User runs `/invite` in the target channel |
| `ratelimited` (429) | "Slack is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. If still rate-limited, tell the user and suggest trying again in a minute. |
| `user_not_found` | "I couldn't find that user — let me search for them." | Call `users_search` with a broader query |
| `message_not_found` | "I couldn't find that specific message — can you tell me which channel it is in?" | Narrow down the channel and re-fetch history |
| `token_revoked` | "Your Slack key has been revoked. Let me help you get a new one." | Run token rotation flow |
| `account_inactive` | "Your Slack key appears to belong to a deactivated account." | Create a new Slack app from an active account |
| MCP server not running | "The Slack connection isn't active yet. Please fully close Claude Code and reopen it, then try again." | User closes and reopens Claude Code |
| Any other API error | "Something went wrong with Slack — let me try again." | Retry once; if still failing, suggest checking the Slack app is still installed |

---

## Scope Limitations

The Slack MCP connector **can** do (via `slack-mcp-server` with `xoxb-` bot token):
- List channels by type (public, private the bot is invited to, DMs, group DMs)
- Read recent messages from any channel the bot can see, with smart date/count pagination
- Read all replies in a thread
- Post messages to channels the bot is in (with `#name` or channel ID)
- Reply in threads
- Add and remove emoji reactions to messages
- Search for users by name, email, or display name
- List, create, update, and manage user groups (with appropriate scopes)
- Reference channels by `#name` — no need to look up channel IDs first

The Slack MCP connector **cannot** do with the default `xoxb-` bot token setup:
- **Search messages across the workspace** — requires a `xoxp-` User OAuth Token (Slack API limitation, not a server limitation). Read specific channel history instead.
- **Get unread messages** — requires `xoxp-` or browser tokens. Not available with `xoxb-`.
- **Delete messages** — not exposed by the server. Use Slack directly.
- **Edit messages after posting** — not exposed by the server.
- **Archive or create channels** — not exposed by the server. Use Slack directly.
- **Post to private channels the bot has not been invited to** — the user must type `/invite @Claude Assistant` in the target private channel first.
- **Upload files or attachments** — not exposed by the server.
- **Send @mention notifications reliably** — mentions in message text work syntactically (`<@U12345>`) but the bot does not resolve display names to IDs automatically. Use `users_search` to look up the user ID first.

If the user asks for any of the above, tell them plainly what is not supported and offer the closest supported action.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before posting, replying, or reacting.** Summarise the exact channel and message text, and wait for the user's OK before calling the tool. Posting to the wrong channel is embarrassing and cannot be undone through this connector (no delete tool).
- **Use `#channel-name` for channels.** This server supports referencing channels by `#general`, `#sales`, etc. — you do NOT need to call `channels_list` first to look up a channel ID. However, if a `#name` does not resolve, fall back to `channels_list` to find the correct name.
- **Private channels require an invite.** If you get `not_in_channel`, tell the user to run `/invite @Claude Assistant` in the target channel.
- **Message timestamps (`ts`)** are strings like `1709914567.123456` — always treat them as strings, never as numbers.
- **Thread replies vs channel posts:** `conversations_add_message` handles both. If `thread_ts` is provided, it replies in the thread; if omitted, it posts to the channel.
- **Emoji names** for `reactions_add` and `reactions_remove` must be without colons — pass `thumbsup`, not `:thumbsup:`.
- **Smart pagination.** `conversations_history` and `conversations_replies` support date-based limits (`1d`, `7d`, `1m`) and count-based limits (`50`). Use date-based for "show me the last week" and count-based for "show me the last 20 messages".
- **Present data clearly.** Format channel lists, user lists, and message history as readable summaries or small tables, not raw CSV or JSON.
- **One step at a time.** Do not dump entire channel histories at once. Summarise first, then offer to show details or post a message.
- **Rate limits.** Slack rate-limits aggressively per method. If you hit `ratelimited`, back off and retry once.
- **Never log or echo credentials.** The Slack key must never appear in any output visible to the user.
- **Scope expansion.** If a tool call fails with `missing_scope`, guide the user to add the scope in their Slack app's OAuth & Permissions tab, then click **Reinstall to Workspace**. No restart of Claude Code is needed afterwards.
- **User group scopes.** The `usergroups_create`, `usergroups_update`, and `usergroups_users_update` tools require the `usergroups:write` scope, which is not in the default six scopes. If the user wants to manage user groups, guide them to add `usergroups:read` and `usergroups:write` in their Slack app's OAuth & Permissions page, then **Reinstall to Workspace**.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **hubspot-connector**: Sibling CRM connector — post HubSpot deal updates to a Slack channel
- **github-connector**: Sibling dev connector — announce pull request activity in a Slack channel
- **square-connector**: Sibling payments connector — post daily sales summaries to a Slack channel
- **xero-connector**: Sibling accounting connector — post invoice paid / overdue alerts to a finance channel
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Slack auth or API errors
