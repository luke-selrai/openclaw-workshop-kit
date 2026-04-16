---
name: slack-connector
description: "Connect and operate a user's Slack workspace via the slack-mcp-server npm package (korotovsky/slack-mcp-server, the most widely adopted Slack MCP server with 1,500+ GitHub stars and 12,000+ weekly npm downloads). Use this skill when the user asks to set up Slack, connect their workspace, post to a channel, read channel history, react to a message, search for users, or manage user groups. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__slack__*, Bash, Read, Write, Edit
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

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You walk them through creating a Slack app in their workspace, copying the Bot User OAuth Token, and wiring the MCP server into Claude Code. No workspace ID is needed — the server discovers it from the token. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", "Bot Token", "scope", "xoxb", or any file paths. They should feel like they are having a conversation, and at the end their Slack is connected.
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

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, Bot Token, xoxb, MCP, endpoint, JSON, or environment variable. If you must refer to a technical thing, name it plainly:
  - Bot User OAuth Token → **"your Slack key"**
  - Scopes → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - Slack app → **"a small connection app inside your Slack"**
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Slack is now connected." Bad: "MCP server initialized, `channels_list` returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the Slack key back to the user** after they paste it.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase gets the Slack app created, the bot token collected, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only provides information and clicks things in their browser. No workspace ID is needed — the server discovers it from the token.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Slack, I will walk you through creating a small connection app inside your Slack workspace. It takes about four minutes, and for most workspaces you do not need admin approval. Which workspace do you want me to connect?"

Wait for the user's answer. If they say they have more than one workspace, ask them to pick one to start with — they can add more later.

### Step 2 — Walk the user through creating the Slack app and copying the Slack key

The user needs to create a Slack app and copy the Bot User OAuth Token. You cannot do this step for them — Slack requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please open this page in your browser: **https://api.slack.com/apps** — and sign in with the Slack account for the workspace you picked. Let me know when you are signed in."

2. When they confirm → "Click the green **Create New App** button, then choose **From scratch** when Slack asks."

3. When they see the form → deliver the field values:
   - "For **App Name**, type: **Claude Assistant**."
   - "For **Pick a workspace**, choose the workspace you want me to connect."
   - "Then click the green **Create App** button."

4. When the app is created → "On the left side you will see a menu. Click **OAuth & Permissions**. Tell me when you see a page with the heading 'OAuth & Permissions'."

5. When they are on the OAuth & Permissions page → "Scroll down to the section called **Bot Token Scopes**, then click **Add an OAuth Scope**. You will add six permissions — I will give them to you one at a time."

6. Walk them through the six scopes, one at a time (wait for confirmation after each):
   - "Add: **channels:history**"
   - "Add: **channels:read**"
   - "Add: **chat:write**"
   - "Add: **reactions:write**"
   - "Add: **users:read**"
   - "Add: **users.profile:read**"
   - "Great — that is all six permissions. You can always add more later without starting over."

7. When all six are added → "Now scroll back to the very top of the page and click the green **Install to Workspace** button. Slack will ask you to confirm — click **Allow**."
   - If the button says **Request to Install** instead of **Install to Workspace**, your workspace requires admin approval. Tell the user: "Your workspace needs an admin to approve this. Please click **Request to Install** and ask your workspace admin to approve it — then come back here and let me know."

8. When the install is complete → "You should now see a screen with your **Slack key** — it starts with `xoxb-` and is quite long. Please copy it and paste it to me."

Common mistakes to look out for (and correct by re-asking):
- The user pasted a placeholder like `your_token_here` → "I think that was a copy mistake — please try the real value that starts with `xoxb-`."
- The user pasted something that does not start with `xoxb-` → "That doesn't look quite right. The value I need starts with `xoxb-` and is around 55 characters long. Can you check and try again?"
- The user pasted a value starting with `xoxp-` → "That is a different kind of key — I need the one under **Bot User OAuth Token** (starts with `xoxb-`), not the one labelled **User OAuth Token**."
- The user says they cannot find **Install to Workspace** → "It is at the top of the OAuth & Permissions page. You may need to scroll up. If you only see **Request to Install**, that means your workspace needs admin approval first."

**Validation rules (silent):**
- Token must start with `xoxb-`
- Token must be longer than 50 characters

Store the token in memory for Step 3; do not write it anywhere yet.

### Step 3 — Save the connection

Once the user pastes the Slack key, tell the user: "I am going to save your connection details now — this takes just a moment."

Silently add or update the Slack MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "slack-mcp-server"],
      "env": {
        "SLACK_MCP_XOXB_TOKEN": "<xoxb- token from Step 2>",
        "SLACK_MCP_ADD_MESSAGE_TOOL": "true"
      }
    }
  }
}
```

The `SLACK_MCP_ADD_MESSAGE_TOOL` setting enables posting messages and adding reactions, which are disabled by default in this server for safety. We set it to `"true"` to enable all channels. If the user later wants to restrict posting to specific channels, this can be set to a comma-separated list of channel IDs instead.

Merge this into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the Slack entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

**Never echo the Slack key back to the user** after writing it. Never include it in any output visible to the user.

Tell the user: "I have saved your connection details. Please fully close Claude Code and reopen it once — that makes the new connection active. When you are back, say 'test my Slack connection' and I will check it."

### Step 4 — Verify the connection

When the user returns after restarting, tell them: "Let me just check that everything is talking to Slack correctly."

The verification depends on whether the MCP server is now active:

- **If `mcp__slack__*` tools are available**: call `mcp__slack__channels_list` with `channel_types: "public_channel"` and `limit: 5`. If it returns a list of channels, count them and move to the success message.
- **If the tools are still not available**: tell the user "The connection is saved but Claude Code has not picked it up yet. Please fully close all Claude Code windows (not just this chat) and reopen — then come back and say 'test my Slack'."

If the verification tool returns an error:
- `invalid_auth` or `not_authed` → "The connection key didn't work. Could you double-check it? Go back to the **OAuth & Permissions** page of your Slack app and copy the key again." Then re-do Step 3 with the new token.
- `missing_scope` → "Your connection is working, but I need one more permission. Let me tell you which box to tick." Guide them to the OAuth & Permissions page, add the missing scope, click **Reinstall to Workspace**, and come back. Then retry.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to confirm their Slack app is still installed to the workspace.

### Success message

Tell the user, in one short message:

> "All done! I am now connected to your Slack. I can see **[N] channels**. You can ask me things like 'what are the latest messages in #general?' or 'post a hello message to #announcements'. Give it a try!"

---

## Token rotation (no full re-setup needed)

If a user's Slack key stops working (revoked, regenerated, or they want to switch workspaces), they do NOT need to redo the entire Slack app creation. Walk them through this shorter flow:

1. Tell them: "Go to **https://api.slack.com/apps**, click on **Claude Assistant**, then click **OAuth & Permissions**."
2. "Click the green **Reinstall to Workspace** button and click **Allow** when asked."
3. "Copy the new Slack key that appears — it starts with `xoxb-` — and paste it to me."
4. Silently update only the `SLACK_MCP_XOXB_TOKEN` value in `~/.claude.json`. Do not touch the rest of the config.
5. Tell them: "Updated. Please close and reopen Claude Code once, then say 'test my Slack' and I will verify the new key."

If they say "I have a new Slack key" or "my Slack stopped working", start this rotation flow rather than running full Phase 1.

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
- **systematic-debugging**: For troubleshooting Slack auth or API errors
