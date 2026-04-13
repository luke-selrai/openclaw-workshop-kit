---
title: GoHighLevel Setup Guide
version: 1.0
date: 2026-04-13
---

# GoHighLevel — Setup Guide

This guide connects your GoHighLevel (GHL) account to your AI assistant. Once set up, your assistant can look up contacts, manage your sales pipelines, view and create calendar bookings, and help you run email and SMS campaigns — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A GoHighLevel account (sub-account login — the one you use to manage a single business)
- An internet connection
- About 10 minutes

> **No coding experience required.** GHL has no command-line tool, so your assistant uses a real browser to log you in once and remembers you for next time. Optionally, you can also create a small "API key" to make read-only operations faster — the guide walks you through both.

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
| **Contacts** | Search, view, create, update, tag, and add notes to contacts |
| **Pipelines** | List opportunities, move them between stages, mark won/lost, create new ones |
| **Calendar** | List bookings for any day, create appointments, cancel appointments |
| **Email Campaigns** | Send one-off emails from a template, enrol contacts in workflows, open the campaign builder |
| **SMS / Conversations** | Read recent conversations, draft an SMS in the GHL UI for you to send |

---

## Step 1: Install the browser engine (one-time)

Your assistant uses a tool called **playwright-skill** to drive a real browser for GHL. If you've never used it before, ask your assistant:

> "Set up the playwright-skill for me."

It will run `npm run setup` once to install Chromium. You only do this once per computer.

---

## Step 2: Sign in to GHL (one-time)

Ask your assistant:

> "Set up my GoHighLevel connector — sign me in."

A Chrome window will open at **app.gohighlevel.com**. Sign in normally — username, password, and any 2FA codes. When you reach your GHL dashboard, tell your assistant **"I'm in"** and it will save your session.

After this step, your assistant can act on your GHL account without asking you to log in again — until your GHL session naturally expires (usually weeks later).

> **Where is my session stored?** In a hidden file at `~/.claude/state/ghl-storage.json` on your computer. Nothing leaves your machine.

---

## Step 3: Create a Private Integration Token (recommended)

The browser path works for everything, but a small "Private Integration Token" lets your assistant answer simple questions much faster (no browser needed).

1. In GHL, click **Settings** in the left sidebar.
2. Scroll down to **Private Integrations** and click it.
3. Click **Create New Integration**.
4. Name it: `Claude Code`
5. Tick these scopes (you can add more later):
   - View Contacts
   - Edit Contacts
   - View Opportunities
   - Edit Opportunities
   - View Calendars
   - View Calendar Events
   - View Conversations
6. Click **Create**.
7. **Copy the token** that appears (it starts with `pit-`). GHL shows it only once — if you lose it, you'll need to create a new integration.

Now grab your **Location ID**:

1. Still in **Settings**, click **Business Profile**.
2. Copy the long **Location ID** value near the top.

---

## Step 4: Save your token and Location ID

Open a terminal and tell your assistant:

> "Save my GHL token and Location ID."

It will help you add these two lines to your shell profile (`~/.zshrc` on Mac, `~/.bashrc` on most Linux/Windows-WSL setups):

```bash
export GHL_PIT="pit-xxxxxxxxxxxxxxxxxxxxxxxx"
export GHL_LOCATION_ID="xxxxxxxxxxxxxxxxxxxxxxxx"
```

Then close the terminal and open a fresh one so the values load.

> **Keep this token private.** Don't paste it into chats, screenshots, or shared documents. Treat it like a password.

---

## Step 5: Verify it works

Ask your assistant:

> "Show me my five most recent GHL contacts."

You should see a short list of contact names within a few seconds. If you do — **you're done.** Your GHL is connected.

---

## Troubleshooting

**"It keeps asking me to log in again."**
Your saved session expired. Ask your assistant to re-run the GHL login (Step 2). This happens naturally every few weeks.

**"It says 401 Unauthorized."**
Your Private Integration Token is wrong or has been revoked. Re-do Step 3, copy the new token, and update the value in Step 4.

**"It says 403 Forbidden on opportunities/calendar/etc."**
Your token is missing a scope. Go back to Step 3, edit the integration, tick the missing scope, and **regenerate the token** (you'll need to update Step 4 again).

**"It found a contact in the wrong location."**
Your `GHL_LOCATION_ID` points to a different sub-account. Re-check the value in **Settings → Business Profile** for the location you actually want.

**"The browser opened but a button isn't where it should be."**
GoHighLevel updates its UI often. Tell your assistant exactly what you see and it will report the change instead of clicking blindly.

**"Sending an SMS — my assistant drafted it but didn't send."**
This is on purpose. SMS is sent from your phone number, so the assistant always hands the browser back to you to click **Send** yourself. Review the message and click Send.

---

## What's Next

- "List all my open opportunities in the Sales pipeline"
- "Show me bookings for tomorrow"
- "Add a tag 'newsletter-signup' to jane@example.com"
- "Move opportunity 'Acme Co' to the 'Proposal Sent' stage"
- "Draft an SMS to John reminding him about our 3pm call"

Try any of these to see what your new GHL connector can do.
