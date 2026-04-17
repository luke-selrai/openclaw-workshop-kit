---
title: Slack — Setup Guide
version: 2.0
date: 2026-04-16
---

# Slack — Setup Guide

This guide connects your Slack workspace to your AI assistant using the `slack-mcp-server` package ([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server), the most widely adopted Slack MCP server). Once set up, your assistant can list channels, read recent messages, post to channels, reply in threads, add and remove reactions, search for users, and manage user groups — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [the setup walkthrough](../start/full-setup.md) if not done yet)
- A Slack account with access to the workspace you want to connect
- Node.js 20 or newer installed (check with `node --version`)
- An internet connection

> **Most workspaces do not require admin approval** to create a simple connection app like this. If yours does, you will see a **Request to Install** button instead of **Install to Workspace** — in that case, ask your workspace admin to approve the request. This is a one-time approval.

> **No coding experience required.** Your connection key stays on your machine and is never sent to third parties.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Channels** | List public, private (if invited), and group channels in your workspace |
| **Channel history** | Read recent messages from any channel, with smart date or count pagination |
| **Threads** | Read all replies in a message thread |
| **Posting** | Post new messages to channels — with your confirmation first |
| **Replies** | Reply inside an existing message thread — with your confirmation first |
| **Reactions** | Add or remove emoji reactions to messages — with your confirmation first |
| **User search** | Search for people by name, email, or display name |
| **User groups** | List, create, and manage user groups (requires extra permissions) |

---

## Step 1 — Create a Slack connection app (you do this)

This step creates a small connection app inside your Slack workspace and gives you a secure **Slack key** that lets your assistant talk to Slack on your behalf.

1. Open **https://api.slack.com/apps** in your browser and sign in to the workspace you want to connect
2. Click the green **Create New App** button
3. Choose **From scratch** when asked
4. Fill in the form:
   - **App Name:** Claude Assistant
   - **Pick a workspace:** choose the workspace you want to connect
5. Click the green **Create App** button
6. On the left side menu, click **OAuth & Permissions**
7. Scroll down to the **Bot Token Scopes** section and click **Add an OAuth Scope**
8. Add these six permissions, one at a time:
   - `channels:history` — read messages in public channels
   - `channels:read` — see the list of channels
   - `chat:write` — post messages
   - `reactions:write` — add and remove emoji reactions
   - `users:read` — see the list of people in the workspace
   - `users.profile:read` — see profile details like job title
9. Scroll back to the top of the same page and click the green **Install to Workspace** button
   - If the button says **Request to Install** instead, your workspace needs admin approval — click it and ask your admin to approve the request
10. Click **Allow** when Slack asks you to confirm
11. You will see your **Slack key** on the next page under the heading **Bot User OAuth Token** — it starts with `xoxb-` and is quite long
12. **Copy this Slack key** — you will give it to your assistant in Step 2

> **Important:** Treat this Slack key like a password. Do not share it or post it online.

> **You can always add more permissions later** by going back to the OAuth & Permissions page, adding more scope boxes, and clicking **Reinstall to Workspace**. No need to start over.

---

## Step 2 — Tell your assistant to connect (your assistant does the rest)

Open Claude Code and say:

> "Help me connect my Slack workspace"

Your assistant will:
1. Ask you to paste the Slack key you copied in Step 1
2. Save the connection details securely on your computer
3. Ask you to fully close and reopen Claude Code once
4. Verify the connection is working when you come back

> **After setup, fully close and reopen Claude Code once** so the connection becomes active. Closing the chat tab is not enough — close all Claude Code windows and reopen.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"What channels do we have in Slack?"*
- *"Show me the latest messages in #general"*
- *"What happened in the sales channel this week?"*
- *"Post 'hello team' to #announcements"*
- *"Reply in that thread saying thanks"*
- *"React with a thumbs up to the latest message in #general"*
- *"Remove that reaction"*
- *"Who is Jane Doe in Slack?"*
- *"Find the user with email jane@example.com"*
- *"What user groups do we have?"*
- *"Show me the replies on that message"*

---

## What Your Assistant Can Do Now

| Ask your assistant to… | It will… |
|---|---|
| List channels | Return channels in the workspace (public, private if invited, group) |
| Read a channel | Pull recent messages with smart date or count pagination |
| Read a thread | Return every reply under a specific message |
| Post a message | Post to a channel — after confirming with you first |
| Reply in a thread | Add a reply under an existing message — after confirming |
| React to a message | Add an emoji reaction — after confirming |
| Remove a reaction | Remove an emoji reaction — after confirming |
| Search for a user | Find people by name, email, or display name |
| List user groups | Show all user groups in the workspace |
| Manage user groups | Create, update, and manage group membership (requires extra permissions) |

---

## Using the Assistant in Private Channels

By default, the connection app can only see **public channels** in your workspace.

To use it in a **private channel**, you need to invite it:

1. Open the private channel in Slack
2. Type `/invite @Claude Assistant` and press enter
3. That's it — your assistant can now read and post in that channel

You only need to do this once per private channel.

---

## Keeping Your Connection Active

- **Slack keys do not expire** — once set up, your connection will keep working until you revoke it
- **No renewal required** — unlike some connections, you never need to refresh the Slack key
- **You can revoke the connection at any time** by going to https://api.slack.com/apps → Claude Assistant → **Basic Information** → **Delete App**
- **Adding more permissions later** does NOT require a new Slack key — just add the scope in OAuth & Permissions and click **Reinstall to Workspace**

---

## If Your Slack Stops Working (Token Rotation)

If your Slack connection stops working (key was revoked, accidentally deleted, or you want to switch workspaces), you do NOT need to redo the entire setup. Follow these steps:

1. Go to **https://api.slack.com/apps** and click on **Claude Assistant**
2. Click **OAuth & Permissions** in the left menu
3. Click the green **Reinstall to Workspace** button and click **Allow**
4. Copy the new **Slack key** that appears (starts with `xoxb-`)
5. Open Claude Code and say: *"I have a new Slack key"*
6. Your assistant will update the connection — no restart of the whole setup process needed

If you accidentally deleted the entire Slack app, you will need to redo Step 1 above to create a new one.

---

## Known Limitations

This connector supports the most common Slack actions through the bot token setup. The following have limited or no support:

- **Message search across the workspace** — the server supports this, but it requires a different type of Slack key (User OAuth Token) that is not part of the default setup. Your assistant can read a specific channel's recent history instead.
- **Unread message summary** — the server supports this, but it requires a different type of Slack key. Not available with the default setup.
- **Deleting messages** — not exposed by the server. Delete from Slack directly if needed.
- **Editing messages after posting** — not exposed by the server.
- **Creating or archiving channels** — not exposed by the server. Use Slack directly.
- **File uploads or attachments** — not exposed by the server.
- **Reliable @mentions** — mentioning someone by name in a posted message requires your assistant to look up their user ID first. If a mention doesn't notify the right person, let your assistant know.

If you need any of these, let your assistant know and they can check if support has been added.

---

## Troubleshooting

### Setup problems

| Problem | What to do |
|---|---|
| "Create New App" button is missing | Make sure you are signed in to the correct Slack workspace at https://api.slack.com/apps |
| Button says "Request to Install" instead of "Install to Workspace" | Your workspace requires admin approval — click the button and ask your workspace admin to approve the request |
| Cannot find the OAuth & Permissions page | It is in the left side menu of your Slack app. Scroll the menu if needed. |
| Cannot find "Bot Token Scopes" | Scroll down the OAuth & Permissions page — it is below the access tokens section |
| Slack key starts with `xoxp-` not `xoxb-` | You copied the User OAuth Token by mistake. The one you want is under **Bot User OAuth Token** on the OAuth & Permissions page |

### Authentication problems

| Problem | What to do |
|---|---|
| "Your Slack connection key isn't being accepted" | Go to your Slack app → OAuth & Permissions → copy the **Bot User OAuth Token** again (starts with `xoxb-`) and give it to your assistant |
| "I need one more permission to do that" | Go to your Slack app → OAuth & Permissions → add the scope your assistant mentioned → click **Reinstall to Workspace** |
| "Your Slack key has been revoked" | Follow the **If Your Slack Stops Working** section above to reinstall and get a new key |

### After-setup problems

| Problem | What to do |
|---|---|
| Connection not working after setup | Make sure you **fully closed all Claude Code windows** and reopened. Closing the chat tab alone is not enough. |
| "I can see that channel but I haven't been invited" | In Slack, open the channel and type `/invite @Claude Assistant` |
| "Slack is asking me to slow down" (rate limit) | Wait 10 seconds and try again. Slack limits posting to roughly one message per second per channel. |
| Assistant posts to the wrong channel | There is no delete tool in this connector — you will need to delete the message from Slack directly. Always confirm the channel name before posting. |
| Need to switch to a different Slack workspace | Create a new connection app in the other workspace and tell your assistant: *"I want to switch to a different Slack workspace."* They will walk you through updating the connection. |
| Assistant cannot find a private channel | Private channels require the assistant to be invited first. Run `/invite @Claude Assistant` in that channel. |
| "Search is not available with this setup" | Message search requires a User OAuth Token. Your assistant can read specific channel history as an alternative. |

---

## Security Notes

- Your Slack key is stored locally on your computer in a settings file — it is never sent to third parties
- The Slack key can be revoked at any time from https://api.slack.com/apps → Claude Assistant
- Your assistant will always confirm with you before posting, replying, or reacting — posting and reactions are disabled by default in the server and only enabled because the setup explicitly opts in
- No OAuth redirects, no client secrets — just a single bot token
- The connection uses `slack-mcp-server` ([korotovsky/slack-mcp-server](https://github.com/korotovsky/slack-mcp-server)), the most widely adopted Slack MCP server (1,500+ GitHub stars, 12,000+ weekly npm downloads)
- The connection app only has the six permissions you granted — nothing more. You can review them at any time on the OAuth & Permissions page of your Slack app.

---

## What Is NOT Included (Yet)

This connector focuses on the most common Slack actions using a bot token. The server itself supports more features (message search, unread summaries) that require a User OAuth Token — these may be added in a future version if there is demand.

The following are **not included** in this version:

- Message search (available with User OAuth Token setup — ask if needed)
- Unread message summaries (available with User OAuth Token setup)
- Deleting or editing messages
- Creating or archiving channels
- File uploads and attachments

If you need any of these, let your assistant know and they can check if support has been added.

---

Built by Selr AI
