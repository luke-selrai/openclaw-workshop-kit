---
title: Google Workspace Setup Guide
version: 6.0
date: 2026-04-02
---

# Google Workspace — Setup Guide

This guide walks you through connecting Google Workspace (Gmail, Calendar, Drive, Docs, Sheets, and more) to Claude Code. Once connected, you can just ask your assistant things like "send an email" or "check my calendar" — no commands needed.

Works on **Windows, Mac, and Linux**.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js installed (check: open your terminal and type `node --version` — you should see a version number)
- A Google account (e.g. yourname@gmail.com or yourname@yourbusiness.com)

> **How to open your terminal:**
> - **Windows** — Press `Windows key + R`, type `cmd`, press Enter. Or search for **Command Prompt** or **Terminal** in the Start menu.
> - **Mac** — Press `Cmd + Space`, type `Terminal`, press Enter.
> - **Linux** — Press `Ctrl + Alt + T` or search for **Terminal** in your applications.

---

## Step 1 — Install the Google Workspace Tool

Type this in your terminal and press Enter:

```
npm install -g @googleworkspace/cli
```

> **Windows users:** If you see a permissions error, close the Command Prompt and reopen it by right-clicking and selecting **"Run as administrator"**, then try again.

When it finishes, verify it worked:

```
gws --version
```

✅ You should see a version number printed.

If you see an error instead, close and reopen your terminal, then try again.

---

## Step 2 — Set Up Your Google Cloud Project (First Time Only)

Before signing in, run this to create the required Google Cloud project automatically:

```
gws auth setup
```

Follow the prompts. It will set everything up for you. When it asks for a project ID, type something short like `gws-my-assistant` and press Enter.

✅ You should see: `Setup complete`

> **Skip this step** if you have already done it before on this computer.

---

## Step 3 — Sign In to Your Google Account

Type this and press Enter:

```
gws auth login -s drive,gmail,sheets,calendar
```

> **Important:** Always include `-s drive,gmail,sheets,calendar`. Without it, Google may block the login because the app requests too many permissions at once. This flag limits it to just what you need.

A browser window will open automatically:

1. **Select the Google account you want to use** — double-check this is the right one
2. You may see a warning that says **"Google hasn't verified this app"** — click **"Continue"** (this is normal)
3. Click **"Allow"** to give permission
4. You should see a success message in the browser

✅ Done — your Google account is now connected.

> **If no browser window opens**, look in the terminal for a URL starting with `https://accounts.google.com/...` — copy it and paste it into your browser manually.

> **If you see "Access blocked: This app's request is invalid"**, your Google account needs to be added as a test user. Go to [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → OAuth consent screen → Test users → Add your email address → Save. Then run `gws auth login -s drive,gmail,sheets,calendar` again.

---

## Step 4 — Test It

Ask your assistant:

- "What's on my calendar today?"
- "Show me my recent emails"
- "List my recent Drive files"

Your assistant can now use Gmail, Calendar, Drive, Docs, Sheets, and more — just ask in plain English.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Send an email** | "Send an email to jane@example.com about the meeting tomorrow" |
| **Read emails** | "Show me my unread emails" |
| **Check calendar** | "What meetings do I have this week?" |
| **Create a calendar event** | "Schedule a meeting with John on Friday at 2pm" |
| **Find a file** | "Find the proposal document in my Drive" |
| **Create a document** | "Create a new Google Doc called Project Plan" |
| **Work with spreadsheets** | "Open the Sales Tracker spreadsheet and add a new row" |
| **Manage tasks** | "Show me my Google Tasks" |
| **Chat** | "Send a message in Google Chat to [space name]" |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "gws: command not found" (Mac/Linux) or "'gws' is not recognized" (Windows) | Close and reopen your terminal. If still not found, reinstall: `npm install -g @googleworkspace/cli` |
| Permission error during install (Windows) | Reopen Command Prompt as administrator (right-click → Run as administrator) |
| "Access blocked: This app's request is invalid" | Your Google account needs to be added as a test user. Go to [console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → OAuth consent screen → Test users → Add your email → Save. Then try again. |
| Login fails or asks for too many permissions | Always use `gws auth login -s drive,gmail,sheets,calendar` — not plain `gws auth login` |
| Wrong Google account connected | Run `gws auth logout` then `gws auth login -s drive,gmail,sheets,calendar` — select the correct account |
| Browser doesn't open during sign-in | Copy the URL from the terminal and paste it into your browser manually |
| "Google hasn't verified this app" warning | Click **"Continue"** — this is normal for personal projects |
| Tools not responding after setup | Restart Claude Code completely — close and reopen it |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
