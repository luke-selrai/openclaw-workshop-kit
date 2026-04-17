---
title: monday.com — Setup Guide
version: 1.0
date: 2026-04-15
---

# monday.com — Setup Guide

This guide connects your monday.com account to your AI assistant using the official monday.com MCP server. Once set up, your assistant can browse your boards, create and update items, move tasks between groups, add comments, list your team, and more — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A monday.com account (any plan, including Free)
- Node.js 20 or newer installed (check with `node --version`) — **only if you choose the Local option below**
- An internet connection

> **No coding experience required.** Your connection key stays on your machine and is never sent to third parties.

---

## Local or Hosted?

You have two ways to connect. You only need one.

| Option | Best for | Needs Node.js? |
|---|---|---|
| **Hosted** (recommended for most users) | Anyone who wants the simplest setup. Monday.com runs the connection for you. | No |
| **Local** | Users who already have Node.js and prefer everything running on their own computer. Supports extra flags like read-only mode and the full GraphQL API. | Yes (v20+) |

If you are not sure, pick **Hosted**. You can switch later just by telling your assistant.

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
| **Items (tasks / rows)** | Create, search, update, move, and delete items on any board |
| **Comments** | Post updates and comments on any item |
| **Boards** | Create new boards and read their full structure |
| **Groups** | Add new sections to a board and move items between them |
| **Columns** | Add and remove columns (status, date, person, text, etc.) |
| **People** | List users and teams, and assign them to tasks |
| **WorkForms** | Create new intake forms and retrieve existing ones |
| **Full GraphQL** (advanced) | List boards, workspaces, docs, update history — anything in the monday.com API |

---

## Step 1 — Create a Personal API Token in monday.com (you do this)

This step creates a secure connection key that lets your assistant talk to monday.com on your behalf.

1. Open **monday.com** in your browser and sign in
2. Click your **profile picture** in the bottom-left corner of the screen
3. In the menu that appears, click **Developers**
   - If you don't see **Developers**, click **Administration** → **Connections** → **API**
4. On the left side of the Developers page, click **My Access Tokens**
5. Click **Show** (or **Generate**) to reveal your personal token
6. **Copy this token** — you will give it to your assistant in the next step

> **Important:** Treat this token like a password. Do not share it or post it online. It gives full access to everything your monday.com user can see.

> **Personal tokens are available on all plans** — Free, Basic, Standard, Pro, and Enterprise.

---

## Step 2 — Tell Your Assistant to Connect (your assistant does the rest)

Open Claude Code and say:

> "Help me connect my monday.com account"

Your assistant will:
1. Ask you to paste the access token you copied in Step 1
2. Save the connection details securely on your computer
3. Verify the connection is working
4. Tell you when it is ready

> **After setup, restart Claude Code once** so the connection becomes active.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"Show me my boards"*
- *"What's on the Sales board?"*
- *"Find the task called 'Q2 planning'"*
- *"Create an item 'Launch landing page' on the Roadmap board, assigned to me, due Friday"*
- *"Move item 12345 to Done"*
- *"Move this task to the 'In Review' group"*
- *"Assign this task to Jane"*
- *"Post a comment 'shipped' on item 12345"*
- *"Create a new project board called Q2 Marketing"*
- *"Add a 'Due date' column to this board"*
- *"Who's on my team?"*
- *"Which monday.com account am I connected to?"*

---

## Read-Only Mode (Local option only)

If you want your assistant to only **read** from monday.com — never create, update, or delete anything — tell your assistant:

> "Connect my monday.com in read-only mode"

This is a safe way to try the connector for the first time, or to use it on a shared/production account where you want no accidental writes. Only available with the **Local** setup option.

---

## Unlock the Full monday.com API (Local option only, advanced)

The connector ships with 14 typed tools out of the box plus 3 dynamic tools for advanced use. To unlock the full monday.com GraphQL API — listing workspaces, reading docs, archiving/duplicating items, fetching update history, etc. — tell your assistant:

> "Enable the full monday API tools"

Your assistant will update the connection settings. Only available with the **Local** setup option. This is optional and only recommended if you hit a request the 14 default typed tools don't cover.

> ⚠️ **You cannot combine read-only mode with the full API tools.** Pick one or the other. The full API tools need write access to function. If you want both safety and advanced features, start in read-only mode and switch to full tools once you are comfortable.

---

## Troubleshooting

### "Your monday.com connection has expired"
Your Personal API Token may have been regenerated or revoked. Go to monday.com → profile picture → Developers → **My Access Tokens**, copy the current token, and tell your assistant: *"I have a new monday.com connection key."*

### "Your monday.com user doesn't have permission for that action"
Your login can't see or edit that specific board. Ask your workspace admin to grant you access — this is a monday.com permissions setting, not something your assistant can fix.

### "The query is too heavy" (ComplexityException)
monday.com limits how much data one request can ask for. Ask your assistant for a narrower result ("show me the first 10 items instead of all of them") and it will retry.

### "That column isn't on the board anymore"
A column was renamed or deleted since your assistant last looked at the board. Just ask again — your assistant will re-read the board structure.

### Connection not working after setup
Make sure you restarted Claude Code after the initial setup. The connection only activates after a restart.

### "I can't find the Developers menu"
Click your profile picture (bottom-left) and look for **Developers** in the menu. If it's not there, try opening the monday.com Developers page directly in your browser.

### Need to switch monday.com accounts
Sign in to the other account, copy a Personal API Token from its Developers page, and tell your assistant: *"I want to switch to a different monday.com account."* They will walk you through updating the connection.

---

## Security Notes

- Your access token is stored locally on your computer in a settings file — it is never sent to third parties
- The token can be regenerated at any time from monday.com → Developers → My Access Tokens (regenerating will invalidate the old one)
- Your assistant will always confirm with you before creating, updating, moving, or deleting records
- No OAuth, no browser redirects, no client secrets — just a single personal token
- The connection uses the official `@mondaydotcomorg/monday-api-mcp` server maintained by monday.com — see [monday MCP documentation](https://support.monday.com/hc/en-us/articles/28588158981266-Get-started-with-monday-MCP) and the [GitHub repo](https://github.com/mondaycom/mcp)
- Personal tokens inherit your user's permissions — if you can't do something in the monday.com UI, your assistant can't either

---

## What Is NOT Included (Yet)

This connector focuses on the **monday.com core data model** — boards, items, groups, columns, updates, users, teams, and forms.

The following are **not accessible through the connector** and must be done inside monday.com directly:

- Visual automation builder (recipes like "when status changes to Done, notify someone")
- Dashboards and widgets
- OAuth-based integrations (Slack, Gmail, Microsoft Teams, etc.)
- Account billing and admin settings
- Managing multiple monday.com accounts at the same time (one account per connection)

If you need any of these, let your assistant know and they can check if support has been added.

---

Built by Selr AI
