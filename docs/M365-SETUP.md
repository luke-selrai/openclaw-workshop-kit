---
title: Microsoft 365 Setup Guide
version: 1.0
date: 2026-04-01
---

# Microsoft 365 — Setup Guide

This guide walks you through connecting Microsoft 365 (Outlook, Teams, OneDrive, SharePoint, and more) to Claude Code. Once connected, you can ask your assistant things like "draft an email", "check my Teams messages", or "find a file in OneDrive" — no commands needed.

Works on **Windows, Mac, and Linux**.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js installed (check: open your terminal and type `node --version` — you should see a version number)
- A **Microsoft 365 Business** account (not a personal Microsoft account)

> **Don't have Microsoft 365 Business?**
> A personal Microsoft account (e.g. hotmail.com, outlook.com, or a custom domain on a personal account) will **not** work. You need an active Microsoft 365 Business subscription.
> - Sign up at [microsoft.com/en-au/microsoft-365/business/compare-all-plans](https://microsoft.com/en-au/microsoft-365/business/compare-all-plans)
> - **Business Basic** (~$8 AUD/month) is sufficient

---

## Step 1 — Install the Microsoft 365 CLI

> **How to open your terminal:**
> - **Windows** — Press `Windows key + R`, type `cmd`, press Enter. Or search for **Command Prompt** in the Start menu.
> - **Mac** — Press `Cmd + Space`, type `Terminal`, press Enter.
> - **Linux** — Press `Ctrl + Alt + T`.

Type this in your terminal and press Enter:

```
npm install -g @pnp/cli-microsoft365
```

> **Windows users:** If you see a permissions error, close the Command Prompt and reopen it by right-clicking and selecting **"Run as administrator"**, then try again.

Verify it worked:

```
m365 --version
```

✅ You should see a version number printed.

---

## Step 2 — Set Up the App Registration (First Time Only)

Before signing in, run the setup command:

```
m365 setup
```

This will:
1. Open your browser and ask you to sign in to your Microsoft 365 account
2. Create an app registration in your Azure tenant automatically
3. Save the app ID for future logins

Follow the prompts until you see a success message.

✅ You should see: `Setup complete`

> **Skip this step** if you have already done it before on this computer.

---

## Step 3 — Sign In to Your Microsoft 365 Account

Type this and press Enter:

```
m365 login
```

A browser window will open:

1. **Select your Microsoft 365 Business account** — make sure it is the work account, not a personal one
2. Click **Accept** to grant permissions
3. You should see a success message in the browser

✅ Done — your Microsoft 365 account is now connected.

---

## Step 4 — Test It

Ask your assistant:

- "Draft an email to john@example.com about tomorrow's meeting"
- "Show me my unread emails in Outlook"
- "What files do I have in OneDrive?"
- "List my upcoming Teams meetings"

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Draft an email** | "Draft an email to jane@example.com about the project update" |
| **Send an email** | "Send an email to john@example.com saying I'll be 10 minutes late" |
| **Read emails** | "Show me my unread emails" |
| **Check calendar** | "What meetings do I have this week?" |
| **Create a calendar event** | "Schedule a meeting with Sarah on Thursday at 3pm" |
| **Find a file** | "Find the proposal document in my OneDrive" |
| **Teams messages** | "Show me recent messages in the General Teams channel" |
| **SharePoint** | "List files in the Marketing SharePoint site" |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `m365: command not found` (Mac/Linux) or `'m365' is not recognized` (Windows) | Close and reopen your terminal. If still not found, reinstall: `npm install -g @pnp/cli-microsoft365` |
| Permission error during install (Windows) | Reopen Command Prompt as administrator (right-click → Run as administrator) |
| `AADSTS500202` error during login | Your account is a personal Microsoft account — m365 CLI requires a Microsoft 365 Business account. See "What You Need" above. |
| `appId is required` error | Run `m365 setup` first before running `m365 login` |
| Wrong account connected | Run `m365 logout` then `m365 login` — select the correct account |
| Browser doesn't open during sign-in | Copy the URL from the terminal and paste it into your browser manually |
| Tools not responding after setup | Restart Claude Code completely — close and reopen it |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
