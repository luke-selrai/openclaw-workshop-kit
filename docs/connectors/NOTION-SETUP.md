---
title: Notion — Setup Guide
version: 1.0
date: 2026-04-15
---

# Notion — Setup Guide

This guide connects your Notion workspace to your AI assistant using the **official Claude Code Notion plugin** — built and maintained jointly by Notion and Anthropic. Once set up, your assistant can search your workspace, read and create pages, query databases, add tasks, and update meeting notes — all through plain English.

**Setup takes about two minutes.** You don't run any commands yourself — your assistant walks you through the plugin install conversationally, and the plugin handles everything else (signing into Notion, wiring the connection, making the skills available).

---

## What You Need Before Starting

- Claude Code installed and working (follow [the setup walkthrough](../start/full-setup.md) if not done yet)
- A Notion account (free or paid — both work)
- An internet connection

> **No coding experience required.** The plugin uses Notion's official OAuth sign-in — no API keys, no copy-pasted tokens, nothing to save on your computer.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM | Yes |
| Mac — Intel | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

Once the plugin is installed, your assistant can:

| Area | What Your Assistant Can Do |
|---|---|
| **Search** | Search your entire workspace for pages, databases, and content |
| **Read pages** | Pull the content of any Notion page into the chat |
| **Create pages** | Create new Notion pages in any parent |
| **Update pages** | Add blocks, edit text, and update properties on existing pages |
| **Databases** | Query databases by name or ID and return structured results |
| **Database rows** | Insert new rows into any database with natural-language properties |
| **Tasks** | Create and manage tasks in your tasks database |
| **Task boards** | Plan tasks, build tasks from page links, set up task boards |
| **Comments** | Read and create comments on pages |
| **Move & duplicate** | Move or duplicate pages within your workspace |

Under the hood this is powered by the [official Notion MCP server](https://developers.notion.com/docs/mcp) — you don't need to know that, but it means every Notion feature is first-party and maintained by Notion.

---

## How to Connect

Open Claude Code and say:

> **"Help me connect my Notion account"**

Your assistant will:

1. Ask you to type `/plugin` in the chat (a menu of available plugins will appear)
2. Walk you through selecting the **Notion** plugin and installing it
3. Wait while you sign into Notion in your browser and click **Allow**
4. Verify the connection is live and tell you it's ready

That's the whole setup. You'll type `/plugin` once, pick Notion from the menu, and sign in — your assistant handles the rest.

---

## Trying It Out

Once your assistant confirms the plugin is live, try asking:

- *"Search my Notion for meeting notes from this week"*
- *"Create a Notion page called R&D Log in my Engineering space"*
- *"What's in my Tasks database?"*
- *"Add today's progress to my R&D page"*
- *"Find the proposal template in my Notion"*
- *"Create a task called 'Review Q2 numbers' in my tasks database"*

If your assistant responds with your Notion content, you're all set.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Search your workspace** | *"Search my Notion for 'proposal'"* |
| **Find a specific page** | *"Find my R&D Log page"* |
| **Read a page** | *"Show me my latest meeting notes from Notion"* |
| **Create a page** | *"Create a Notion page called 'Monday Standup' in my Team workspace"* |
| **Update a page** | *"Add a new section to my Q2 plan called 'Risks'"* |
| **Query a database** | *"List the open items in my Tasks database"* |
| **Create a database row** | *"Add a new row to my CRM database for Acme Corp"* |
| **Create a task** | *"Create a task called 'Call the accountant' due Friday"* |
| **Plan tasks** | *"Plan the tasks for this sprint based on my roadmap page"* |
| **Move a page** | *"Move my Meeting Notes page into the Archive workspace"* |
| **Add a comment** | *"Add a comment on the proposal page saying we need to revise section 3"* |
| **Reconnect** | *"My Notion connection has stopped working"* |

---

## Adding More Pages to the Connection

When you first install the plugin and sign into Notion, you'll be asked which pages and databases to give your assistant access to. **You can always change this later**:

1. Go to your Notion account settings → **My connections**
2. Find the **Claude** connection
3. Click **Access** to see what your assistant can read/write
4. Add or remove pages as needed

No re-install required — changes take effect immediately.

---

## Troubleshooting

### *"The `/plugin` command isn't recognised"*
Your Claude Code version may be older than the plugin system. Close Claude Code and reinstall from the workshop-kit setup guide to get the latest version.

### *"I don't see Notion in the plugin menu"*
The plugin marketplace may not be enabled for your setup. Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au).

### *"The browser didn't open for the Notion sign-in"*
Look for a sign-in link in the plugin install flow — there's usually a URL you can copy and paste into your browser manually.

### *"I signed in but my assistant says Notion isn't connected"*
Close the current Claude Code chat and start a new one — the plugin sometimes needs a session refresh to appear. Then say *"test my Notion connection"*.

### *"It says 'not authorised' when I ask about Notion"*
The plugin's sign-in may have expired or been revoked. Say to your assistant: *"reconnect my Notion"* — it will re-run the plugin install flow to get you a fresh sign-in.

### *"I want to disconnect Notion"*
Go to your Notion account settings → **My connections** → **Claude** → **Revoke**. This disconnects the plugin from your workspace. To reconnect later, just say *"connect my Notion"* to your assistant.

---

## Security Notes

- **No API keys or tokens on your computer.** The plugin uses Notion's OAuth sign-in — your credentials stay with Notion and are never stored locally.
- **You choose what the assistant can see.** During sign-in, you pick which pages and databases the plugin can access. You can change this at any time from Notion settings.
- **First-party plugin.** The connector is maintained by Notion and Anthropic — not a third-party wrapper.
- **Revocable instantly.** Disconnecting from Notion settings is immediate and takes effect on the next request.
- **You can see every request.** Notion keeps an audit log of connection activity in your workspace settings.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
