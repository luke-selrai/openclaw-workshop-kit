---
name: slack-connector
description: "Connect and operate a user's Slack workspace via the slack-mcp-server npm package (korotovsky/slack-mcp-server, the most widely adopted Slack MCP server with 1,500+ GitHub stars and 12,000+ weekly npm downloads). Drives the entire setup autonomously through api.slack.com/apps in a Playwright MCP browser: creates the Slack app, fills the app name and workspace, walks the OAuth & Permissions page to add the seven bot scopes, clicks Install to Workspace, and reads the Bot User OAuth Token directly from the DOM. The only human moments are the user signing in to Slack once and clicking Allow on Slack's workspace consent screen. Use this skill when the user asks to set up Slack, connect their workspace, post to a channel, read channel history, react to a message, search for users, or manage user groups. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
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
    - skill: telegram-connector
      reason: Same Playwright-MCP-driven autonomous-install pattern. Reference for the rules + cleanup branches.
    - skill: monday-connector
      reason: Same autonomous Playwright Phase 1 pattern, simpler PAT case. Reference for snapshot-and-reason model.
    - skill: meta-business-suite-connector
      reason: Same autonomous Playwright Phase 1 pattern, more complex multi-step OAuth case. Reference for OAuth consent handling.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives api.slack.com/apps.
---

# Slack Connector

## Overview

This skill lets you read from and post to a user's Slack workspace on their behalf using the **`slack-mcp-server`** npm package ([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth (autonomous).** Claude drives the entire api.slack.com/apps flow inside a Playwright MCP browser. The user does exactly TWO things: (1) sign in to Slack in the Playwright window, (2) click **Allow** on the workspace consent screen when Slack asks. Everything else — clicking *Create an app* → *From scratch*, filling the app name and workspace, walking *OAuth & Permissions* and adding the seven bot scopes, clicking *Install to Workspace*, reading the Bot User OAuth Token from the DOM, writing `~/.claude.json` — is autonomous. The user never copies, never pastes, never opens a tab themselves, never reads a token aloud, never types into chat anything other than confirmations. No workspace ID is needed — the server discovers it from the token.
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

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Slack and clicks **Allow** on the workspace consent screen. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and "please click Allow on the screen Slack just showed you."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, Bot Token, xoxb, MCP, endpoint, JSON, environment variable, Playwright, browser automation, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - Bot User OAuth Token → **"your Slack key"**
  - Scopes / OAuth permissions → **"permissions"**
  - Restart Claude Code → **"close and reopen"**
  - Slack app → **"a small connection app inside your Slack"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Slack for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Slack is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Slack is now connected." Bad: "MCP server initialized, `channels_list` returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo the Slack key** back to the user. Never include it in any output visible to the user.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only roles are: (1) sign in to Slack when prompted, (2) click **Allow** on Slack's workspace-install consent dialog. Claude handles every other step — navigation, form fills, scope additions, install click, token capture, config write, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Add an OAuth Scope control"). Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_type` / `browser_select_option` / `browser_evaluate`. Do not hardcode CSS selectors — Slack's developer UI changes. Re-snapshot whenever the page state changes.

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your Slack now. I'm opening a browser window for you — please sign in there when it appears, and I'll handle the rest. Should take about three minutes. Which workspace do you want me to connect?"

Wait for the user's answer. If they have more than one workspace, ask them to pick one to start with — they can add more later by re-running Phase 1.

### Step 2 — Open api.slack.com/apps and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://api.slack.com/apps" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see the apps dashboard — a list of apps with a **Create an app** button at top, or an empty-state with the same button) → continue to Step 3.
- **Not logged in** (sign-in form, "Sign in with Slack" button, or a workspace-picker prompt) → tell the user *once*: *"The browser window is open — please sign in to Slack when you're ready."* Then poll silently: call `mcp__playwright__browser_wait_for({ text: "Create an app" })` (or wait for any post-login dashboard element from the snapshot) with a generous timeout. Do **not** ask the user to confirm when they're done — detect the logged-in dashboard from the snapshot yourself. SSO redirects, magic-link emails, and password resets will all resolve to the same dashboard.

If `browser_wait_for` times out (5+ minutes), then — and only then — check in with the user: *"Still on the sign-in page? Anything I can help with?"*

If the snapshot shows the user is signed into a different workspace than the one they picked in Step 1, navigate to `https://<workspace>.slack.com` first to switch sessions, then re-navigate to `https://api.slack.com/apps`.

### Step 3 — Create the Slack app autonomously

From the dashboard:

1. Click the **Create an app** button (`browser_click` after locating it in the snapshot).
2. Slack shows a modal with options for how to start the app. Click **From scratch** (`browser_click`).
3. Slack shows the create-app form with two fields: **App Name** and **Pick a workspace**.
   - Type `Claude Assistant` into the App Name field via `browser_type`.
   - Select the user's workspace in the **Pick a workspace** dropdown via `browser_select_option`. If the user has only one workspace and it's already selected, skip this. If multiple workspaces are listed, pick the one the user named in Step 1; if Step 1 gave no name, take a snapshot and present the options once: *"Which of these is the workspace you want me to connect?"*
4. Click the **Create App** button (`browser_click`).

Slack will redirect to the new app's **Basic Information** page. Take a fresh snapshot to confirm the redirect — you should see the left sidebar listing **Basic Information**, **OAuth & Permissions**, **Event Subscriptions**, etc.

If the create flow fails:
- **Network error** → tell the user: *"The connection to Slack hiccuped — let me try once more."* Re-attempt the click sequence once.
- **"App name already in use"** → an earlier run of this skill in the same workspace already created a `Claude Assistant` app. Tell the user: *"Looks like there's already a Claude Assistant app in this workspace from a previous setup. Want me to reuse it (we just need to reinstall to refresh the key) or create a new one with a different name?"* If reuse → navigate to the existing app from the dashboard and skip to Step 4. If new → ask for a new name (e.g. `Claude Assistant 2`) and retry the create.
- **Workspace lacks app-creation permission** → surface a plain-English message: *"Slack says your workspace doesn't allow new apps without admin approval. An admin will need to enable that, or you can ask them to create the app for you."*

### Step 4 — Add the seven bot token scopes autonomously

Click **OAuth & Permissions** in the left sidebar (`browser_click` after locating it in the snapshot). Take a fresh snapshot.

Scroll the page to the **Bot Token Scopes** section. Click **Add an OAuth Scope** (`browser_click`). Slack opens a searchable dropdown of scopes.

For each of the seven scopes below, type the scope name into the search box (`browser_type`) and click the matching result in the dropdown (`browser_click`). Re-snapshot between each addition to confirm the scope landed in the list and to re-locate the **Add an OAuth Scope** control (it shifts down the page as scopes accumulate).

The seven scopes to add, in order:

- `channels:history`
- `channels:read`
- `chat:write`
- `reactions:write`
- `users:read`
- `users.profile:read`
- `usergroups:read`

Validate after the seventh: re-snapshot and confirm all seven labels are visible in the **Bot Token Scopes** list. If any scope failed to land (Slack's autocomplete sometimes mismatches), retry that single scope.

These seven scopes cover every read-path Phase 2 tool: channels, history, replies, posting, reactions, user search, and user-group listing. The user-group **write** tools (`usergroups_create`, `usergroups_update`, `usergroups_users_update`) require the additional `usergroups:write` scope, which is not added by default. If the user later asks to manage user groups, walk them through adding `usergroups:write` and clicking **Reinstall to Workspace** — see the Behaviour Guidelines section below.

### Step 5 — Install to Workspace + capture the user's Allow click

Scroll back to the top of the OAuth & Permissions page. Locate the **Install to Workspace** button.

- **If the button says "Install to Workspace"** → click it (`browser_click`).
- **If the button says "Request to Install"** → the user's workspace requires admin approval. Stop and tell the user: *"Your workspace needs an admin to approve this. I've set the app up, but you'll need to ask your workspace admin to approve the install request before I can finish. Once they approve, come back and say 'finish setting up Slack'."* Save the partial state (app exists, scopes added, install requested) and exit Phase 1.

After clicking **Install to Workspace**, Slack redirects to the workspace consent screen — a page that shows the bot's name, the requested permissions, and an **Allow** button. This is the **one human moment** in Phase 1.

Tell the user, in one short message:

> "Slack just opened a permissions screen — please click **Allow** so I can finish connecting."

Then poll silently: call `mcp__playwright__browser_wait_for({ text: "OAuth Tokens" })` (or wait for the post-Allow redirect back to the OAuth & Permissions page — the snapshot will show **Bot User OAuth Token** as a freshly populated field). Generous timeout, no nagging.

If the user clicks **Cancel** or **Deny** instead of **Allow**, Slack redirects back to OAuth & Permissions without a token. The snapshot will show no token populated. Tell them: *"Looks like you denied the permissions — no problem. Want me to try again?"* If yes, re-navigate to the same OAuth & Permissions page and re-click **Install to Workspace**.

### Step 6 — Capture the Bot User OAuth Token from the DOM

Once the consent flow completes, the OAuth & Permissions page now shows two fields at the top:
- **Bot User OAuth Token** — starts with `xoxb-`, ~55+ characters
- **User OAuth Token** — starts with `xoxp-` (we do NOT use this one)

Take a snapshot. Read the **Bot User OAuth Token** value via `browser_evaluate` — adapt the selector based on what the snapshot shows (Slack often masks the token behind a **Show** button; click **Show** if needed, then re-snapshot, then read).

Example shape (selector will depend on the live snapshot — prefer the snapshot's labelled accessibility node over a generic readonly-input fallback, because the same page also exposes the `xoxp-` User OAuth Token in a similar input and you must not capture that one):
```javascript
() => {
  const inputs = Array.from(document.querySelectorAll('input[type="text"], textarea, code'));
  const xoxb = inputs.map(el => (el.value ?? el.textContent ?? '').trim())
                     .find(v => v.startsWith('xoxb-'));
  return xoxb || null;
}
```

**Validation rules (silent):**
- Token must start with `xoxb-` (NOT `xoxp-` — that's the User OAuth Token, do not use it)
- Token must be longer than 50 characters

If two snapshot attempts don't yield a valid token, stop and tell the user: *"I'm having trouble reading the connection key off the page — could you tell me what you see at the top of the OAuth & Permissions section?"* Use their description to locate the right control, then re-attempt the read via `browser_evaluate` with an adjusted selector.

Store the token in memory for Step 7. Never write it to chat.

### Step 7 — Save the connection (silent)

Silently register the MCP server. **Prefer `claude mcp add` via Bash** — it's the official CLI path, handles JSON merging correctly, and avoids touching `~/.claude.json` directly.

```bash
claude mcp add slack \
  --scope user \
  --env SLACK_MCP_XOXB_TOKEN="<token captured in Step 6>" \
  --env SLACK_MCP_ADD_MESSAGE_TOOL="true" \
  -- npx -y slack-mcp-server
```

The `SLACK_MCP_ADD_MESSAGE_TOOL` setting enables posting messages and adding reactions, which are disabled by default in this server for safety. Setting it to `"true"` enables all channels. If the user later wants to restrict posting to specific channels, the value can be changed to a comma-separated list of channel IDs.

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) — write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) using the equivalent JSON shape:

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

Merge into the existing `mcpServers` object — never overwrite. If `~/.claude.json` doesn't exist, create it. If it's corrupt, back up to `~/.claude.json.backup` first.

Never echo the Bot User OAuth Token back to the user. Never include it in any output visible to the user. Never log it to the conversation, even truncated.

### Step 8 — Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"I've saved your connection — let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__slack__*` tools are available** (the MCP server has reloaded): call `mcp__slack__channels_list` with `channel_types: "public_channel"` and `limit: 5`. If it returns a list of channels, count them and move to Step 9.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user *"All saved. Please close and reopen Claude Code once, then say 'test my Slack' and I'll verify the new key."*

If the verification tool returns an error:
- `invalid_auth` or `not_authed` → "The connection key didn't take — let me grab a fresh one." Re-run Steps 2–7 to mint a new token via the **Reinstall to Workspace** path and overwrite the config.
- `missing_scope` → "Your connection is working, but I need one more permission for that action." Guide via the autonomous Playwright flow back to OAuth & Permissions, add the missing scope, click **Reinstall to Workspace**, capture the new token, and rewrite the config.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, re-run Steps 2–7.

### Step 9 — Success message

Tell the user, in one short message:

> "All done! I'm now connected to your Slack. I can see **[N] channels**. You can ask me things like 'what are the latest messages in #general?' or 'post a hello message to #announcements'. Give it a try!"

---

## Token rotation (autonomous, no full re-setup)

If a user's Slack key stops working (revoked, regenerated, or they want to switch workspaces), they do NOT need to redo the entire Slack app creation. Drive the rotation autonomously:

1. Open Playwright via `mcp__playwright__browser_navigate({ url: "https://api.slack.com/apps" })`. Confirm logged-in dashboard via snapshot (re-prompt sign-in if not, same as Phase 1 Step 2).
2. From the dashboard, locate and click the **Claude Assistant** app row (`browser_click`).
3. Click **OAuth & Permissions** in the left sidebar (`browser_click`).
4. Scroll to the top of the page. Click the **Reinstall to Workspace** button (`browser_click`). Slack will *sometimes* show the workspace consent screen again here — only when the requested scopes have changed since the last install. If a consent screen appears, tell the user, *once*: *"Slack just opened a permissions screen again — please click **Allow** so I can refresh your key."* If no consent screen appears (Slack rotated the token silently because scopes are unchanged), the page will redirect straight back to OAuth & Permissions with a fresh token — no user prompt needed. Detect via `browser_wait_for` on either the post-Allow redirect or a refreshed token field; do not assume Allow always fires.
5. After the redirect back, capture the fresh **Bot User OAuth Token** from the DOM (same `browser_evaluate` pattern as Phase 1 Step 6).
6. Silently update **only** the `SLACK_MCP_XOXB_TOKEN` value via `claude mcp add slack ... --env SLACK_MCP_XOXB_TOKEN=...` (which overwrites by name) or by editing the single env field in `~/.claude.json`. Do not touch any other field.
7. Close the browser via `mcp__playwright__browser_close()`. Tell the user: *"Updated. Please close and reopen Claude Code once, then say 'test my Slack' and I'll verify the new key."*

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
- **User group scopes.** The default seven scopes include `usergroups:read`, so `usergroups_list` and `usergroups_me` work out of the box. The **write** tools (`usergroups_create`, `usergroups_update`, `usergroups_users_update`) require the additional `usergroups:write` scope, which is NOT added by default. If the user wants to manage user groups, drive them autonomously through Playwright back to OAuth & Permissions, add `usergroups:write` to the Bot Token Scopes list, click **Reinstall to Workspace** (and prompt for Allow if Slack shows the consent screen — it will, because scopes changed), capture the fresh token, and rewrite the config via the rotation flow above.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **telegram-connector**: Same Playwright-MCP-driven autonomous-install pattern. Reference for the rules + cleanup branches.
- **monday-connector**: Same autonomous Playwright Phase 1 pattern, simpler PAT case. Reference for snapshot-and-reason model.
- **meta-business-suite-connector**: Same autonomous Playwright Phase 1 pattern, more complex multi-step OAuth case. Reference for OAuth consent handling.
- **playwright-skill**: The Playwright MCP browser is how this skill drives api.slack.com/apps.
- **hubspot-connector**: Sibling CRM connector — post HubSpot deal updates to a Slack channel
- **github-connector**: Sibling dev connector — announce pull request activity in a Slack channel
- **square-connector**: Sibling payments connector — post daily sales summaries to a Slack channel
- **xero-connector**: Sibling accounting connector — post invoice paid / overdue alerts to a finance channel
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Slack auth or API errors
