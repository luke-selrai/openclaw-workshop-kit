---
title: Jotform — Setup Guide
version: 1.0
date: 2026-04-15
---

# Jotform — Setup Guide

This guide connects your Jotform account to your AI assistant using the official Jotform MCP server. Once set up, your assistant can browse your forms, read submissions, create and edit forms, and assign forms to teammates — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A Jotform account (any plan, including Free)
- A web browser (for the one-time sign-in)
- An internet connection

> **No coding experience required.** No API keys, no tokens to copy and paste — just one click in your browser.

---

## How the Connection Works

Jotform's connector is **hosted by Jotform** — there is nothing to install on your computer. Your assistant points to Jotform's official connection address, then opens a browser window the first time you use it so you can sign in to your Jotform account once. After that, your assistant remembers the connection and you never have to sign in again (unless you sign out manually).

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
| **Forms** | List all your forms, create new ones, edit existing ones, and assign them to teammates |
| **Submissions** | Read entries, count responses, filter by date, summarise feedback |
| **Importing** | Add submissions programmatically (e.g. import 50 leads from a spreadsheet) |
| **Sharing** | Assign forms to other users in your Jotform team |

---

## Step 1 — Tell Your Assistant to Connect

Open Claude Code and say:

> "Help me connect my Jotform account"

Your assistant will:
1. Save the connection details on your computer
2. Ask you to restart Claude Code once
3. Open a browser window so you can sign in to Jotform
4. Verify the connection is working
5. Tell you when it is ready

> **Important:** After your assistant saves the connection, you will need to restart Claude Code once before the sign-in window can open.

---

## Step 2 — Sign In to Jotform (one time only)

When your assistant triggers the sign-in:

1. A browser window will pop up automatically
2. Sign in with your Jotform email and password
3. Click **Allow** on the permission screen
4. Come back to Claude Code

That's it. Your assistant will confirm the connection works and you can start asking it about your forms.

> **Already signed in to Jotform in your browser?** You may not need to type a password — Jotform might just show the **Allow** screen straight away. Just click **Allow**.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"Show me my Jotform forms"*
- *"How many submissions did the contact form get this week?"*
- *"Show me the latest 10 responses on the feedback form"*
- *"Summarise the feedback I got this month"*
- *"Create a new feedback form with name, email, rating, and comments fields"*
- *"Add a phone number field to my contact form"*
- *"Rename the 'Q1 survey' form to 'Q2 survey'"*
- *"Share my intake form with Jane"*
- *"Import these 50 leads from my spreadsheet into my contact form"*

---

## Troubleshooting

### "Your Jotform sign-in has expired"
The OAuth session ended (you signed out of Jotform, or it timed out). Tell your assistant: *"Reconnect my Jotform"* and they will re-trigger the browser sign-in.

### "Your Jotform user doesn't have permission for that form"
You don't have access to that specific form in Jotform. Ask the form owner to share it with you — this is a Jotform permissions setting, not something your assistant can fix.

### "Jotform is asking me to slow down"
You hit Jotform's rate limit (60 requests per minute on Free, 600 per minute on Enterprise). Wait a few seconds and your assistant will retry. For very large imports, your assistant will batch the requests automatically.

### Browser window didn't open
Check behind your other windows — sometimes the sign-in pops up in the background. If you really can't find it, tell your assistant *"try the Jotform sign-in again"* and they will trigger it once more.

### Connection not working after setup
Make sure you restarted Claude Code after the initial setup. The connection only activates after a restart.

### Need to switch Jotform accounts
Sign out of your current Jotform account in your browser, then tell your assistant *"I want to switch to a different Jotform account"*. They will re-trigger the sign-in so you can pick the other account.

---

## Security Notes

- Your assistant never sees your Jotform password — Jotform handles the sign-in itself in your browser
- The connection uses Jotform's official hosted server at `mcp.jotform.com`, maintained by Jotform
- You can revoke access at any time from your Jotform account settings → Apps → Connected Apps
- Your assistant will always confirm with you before creating, editing, assigning, or submitting anything
- No API keys, no tokens to manage — just OAuth, the same standard "Sign in with..." flow you already use for other apps
- Submissions often contain personal data (names, emails, free-text feedback) — your assistant will summarise rather than dump full contents into the chat unless you ask

---

## What Is NOT Included (Yet)

This connector focuses on the **Jotform core data model** — forms, submissions, and assignments.

The following are **not accessible through the connector** and must be done inside Jotform directly:

- Visual form designer (drag-and-drop layout beyond what `edit_form` supports)
- Payment integrations (Stripe, PayPal, Square configuration)
- Account billing and admin settings
- PDF / Excel export of submissions
- Conditional logic and complex form triggers beyond basic field changes
- Managing multiple Jotform accounts at the same time (one account per connection)

If you need any of these, let your assistant know and they can check if support has been added.

---

Built by Selr AI
