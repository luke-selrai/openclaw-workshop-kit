---
title: GoHighLevel Setup Guide
version: 2.0
date: 2026-04-13
---

# GoHighLevel — Setup Guide

This guide connects your GoHighLevel (GHL) account to your AI assistant using HighLevel's **official MCP server**. Once set up, your assistant can look up contacts, manage your sales pipelines, read calendar bookings, send messages, and post to your blog and social accounts — all through plain English.

**Total time: about 5 minutes. Four steps.**

---

## What You Need Before Starting

- Claude Code installed and working (follow [the setup walkthrough](../start/full-setup.md) if not done yet)
- A GoHighLevel sub-account login (the one you use to manage a single business)
- A text editor (or you can ask your assistant to edit the config file for you)

> **No coding experience required.** HighLevel publishes an official MCP server that Claude talks to directly. You don't install anything — you just give your assistant a token and your location ID once.

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
| **Contacts** | Search, view, create, update, tag, and untag contacts; list tasks |
| **Pipelines** | List pipelines, search opportunities, move between stages, mark won/lost |
| **Calendar** | View today's/tomorrow's bookings and read appointment notes |
| **Conversations** | Search conversations, read messages, send SMS/email/GMB replies |
| **Payments** | List transactions and look up orders |
| **Blogs** | Draft, edit, and publish blog posts |
| **Email Templates** | List and create email templates |
| **Social Media** | Schedule posts, pull stats, and manage content across connected accounts |

> **Not covered (yet):** Creating or cancelling calendar bookings, editing the visual workflow builder, and authoring full email campaigns in the campaign builder. For those, your assistant falls back to a regular browser window so you can click through yourself.

---

## Step 1: Create a Private Integration Token

1. In GHL, click **Settings** in the left sidebar (you must be inside your sub-account, not the agency view).
2. Scroll to **Private Integrations** and click it.
3. Click **Create New Integration**.
4. Name it: `Claude Code`
5. Tick the scopes you want your assistant to have. For a full experience:
   - **Contacts** — View, Edit
   - **Conversations** — View, Edit
   - **Opportunities** — View, Edit
   - **Calendars** — View, View Events
   - **Payments** — View Transactions, View Orders
   - **Locations** — View, View Custom Fields
   - **Blogs** — View, Edit
   - **Email Templates** — View, Edit
   - **Social Media** — View, Edit
6. Click **Create**.
7. **Copy the token** that appears (it starts with `pit-`). GHL shows it only once — if you lose it, you'll need to create a new integration.

> **Keep this token private.** Treat it like a password. Don't paste it into chats, screenshots, or shared documents.

---

## Step 2: Copy your Location ID

1. Still in **Settings**, click **Business Profile**.
2. Near the top you'll see a long alphanumeric **Location ID** — copy it.

That's the sub-account your assistant will be acting inside.

---

## Step 3: Add the GHL MCP server to `~/.claude.json`

Tell your assistant:

> "Add the GHL MCP server to my `~/.claude.json`. Here's my token: `pit-...` and my location ID: `...`"

Your assistant will add this block (or merge it with your existing `mcpServers` section):

```json
{
  "mcpServers": {
    "ghl": {
      "url": "https://services.leadconnectorhq.com/mcp/",
      "headers": {
        "Authorization": "Bearer pit-YOUR-TOKEN",
        "locationId": "YOUR-LOCATION-ID"
      }
    }
  }
}
```

**Prefer to do it yourself?** Open `~/.claude.json` in your editor and paste the block into the `mcpServers` object. Make sure the file remains valid JSON (no trailing commas).

> **Why `~/.claude.json` and not a shell variable?** That's where Claude Code reads MCP server configuration. Keeping the token there means it travels with your Claude config and never leaks into shell history or environment dumps.

After saving, **restart Claude Code** so it picks up the new MCP server.

---

## Step 4: Verify

Ask your assistant:

> "What GHL account am I connected to?"

It will call `mcp__ghl__get_location` and reply with your sub-account's name — for example, "You're connected to **Acme Marketing**." If you see that, **you're done.** Your GHL is connected.

Now try:

> "Show me my five most recent GHL contacts."

You should see a short list within a few seconds.

---

## Troubleshooting

**"I get a 401 Unauthorized when my assistant calls a GHL tool."**
Your Private Integration Token is wrong, expired, or has been revoked. Re-do Step 1, copy the new token, and ask your assistant to update `~/.claude.json`. Restart Claude Code.

**"I get a 403 Forbidden on opportunities / calendar / payments / etc."**
Your token is missing a scope for that resource. Go back to Step 1, edit the integration, tick the missing scope, and **create a new token** (GHL doesn't let you edit an existing one in place — it'll issue a fresh `pit-...`). Update `~/.claude.json` with the new token and restart Claude Code.

**"My assistant sees contacts from the wrong business."**
Your `locationId` points to a different sub-account. Go back to Step 2, grab the right Location ID from the sub-account you actually want, and ask your assistant to update it in `~/.claude.json`.

**"I get 'MCP server unreachable' errors."**
Check your internet connection and try `curl -I https://services.leadconnectorhq.com/mcp/` in a terminal. If that works and Claude Code still can't reach the server, restart Claude Code.

**"I want to send an SMS but my assistant says it will 'send immediately'."**
That's by design — the MCP `send_message` tool sends the moment it's called. If you want to review the SMS before it goes out, ask your assistant to **draft it in a browser instead** — it'll open the contact's conversation view, type the message, and hand the browser back to you to click Send.

**"I want to book or cancel a calendar appointment."**
The official MCP server is read-only for calendar. Your assistant will fall back to opening GHL in a browser for creates and cancellations.

**"My assistant says 'the skill is blocked' or shows an `allowed-tools` warning."**
Ignore any `allowed-tools` warning from a linter (whether you see it in Claude Desktop, VS Code, or another editor) — it's a cosmetic hint, not an error. The skill works normally in Claude.

---

## What's Next

Try any of these to see what your new GHL connector can do:

- "What GHL account am I connected to?"
- "List all my open opportunities in the Sales pipeline"
- "Show me bookings for tomorrow"
- "Find jane@example.com and tag her as VIP"
- "Move opportunity 'Acme Co' to the 'Proposal Sent' stage"
- "Search my conversations with John from the last week"
- "Draft a blog post titled 'Spring launch' and put it in the Announcements blog"
- "Schedule a LinkedIn post for Thursday at 9am: 'We're hiring!'"
