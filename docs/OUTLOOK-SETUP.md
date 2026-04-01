---
title: Microsoft Outlook & 365 Setup Guide
version: 2.0
date: 2026-04-01
---

# Microsoft Outlook & 365 — Setup Guide

This guide connects your Microsoft account to your AI assistant. Once set up, your assistant can read and send emails, check your calendar, access OneDrive files, work with Excel, browse SharePoint, use OneNote, interact with Teams, and manage your contacts — all through plain English.

No Azure account or app registration needed.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js installed (check by typing `node --version` in the command window)
- A Microsoft account — personal (outlook.com, hotmail.com) or work/school (Microsoft 365)

---

## What This Unlocks

| Tool | What Your Assistant Can Do |
|---|---|
| **Outlook Email** | Read, search, send, reply, and organise your emails |
| **Outlook Calendar** | Check, create, and update meetings and appointments |
| **Contacts** | Look up and manage your contacts |
| **OneDrive** | Find, open, and work with your files |
| **SharePoint** | Browse and search company documents |
| **Teams** | Read messages and channel conversations |
| **OneNote** | Read and add to your notebooks |
| **Excel** | Read and update spreadsheets |
| **To Do** | Manage your Microsoft To Do tasks |

---

## Step 1 — Install the Microsoft 365 Tool

Type this in the command window and press Enter:

```
npm install -g @pnp/cli-microsoft365
```

You should see it download and install. When it finishes, verify it worked:

```
m365 --version
```

You should see a version number. If you see "command not found", close and reopen your terminal, then try again.

---

## Step 2 — Sign In to Your Microsoft Account

Type this and press Enter:

```
m365 login --authType browser
```

A browser window will open:

1. **Select the Microsoft account you want to use** — double-check this is the right one
2. You may see a permissions screen — click **"Accept"** or **"Allow"**
3. You should see a success message in the browser

> **If the browser does not open automatically**, use the device code flow instead:
> ```
> m365 login
> ```
> This will show a short code and a URL. Open the URL in your browser, enter the code, and sign in with your Microsoft account.

---

## Step 3 — Test It

Once signed in, test it by asking your assistant:

- "Show me my unread Outlook emails"
- "What meetings do I have this week?"
- "List my recent OneDrive files"

Or test directly in the command window:

```
m365 outlook mail list
```

```
m365 outlook calendar event list
```

Your assistant can now use Outlook Mail, Calendar, OneDrive, Teams, SharePoint, OneNote, Excel, Contacts, and To Do — just ask in plain English.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Read emails** | "Show me my unread emails" |
| **Send an email** | "Send an email to john@example.com about tomorrow's meeting" |
| **Reply to an email** | "Reply to Sarah's email and say I will be there at 3pm" |
| **Search emails** | "Find emails from my accountant in the last month" |
| **Check calendar** | "What meetings do I have this week?" |
| **Create a meeting** | "Schedule a call with Lisa on Thursday at 10am" |
| **Find a file** | "Find the budget spreadsheet in my OneDrive" |
| **Check Teams** | "Show me the latest messages in the General channel" |
| **Search SharePoint** | "Find the company policy document on SharePoint" |
| **Check contacts** | "Find the phone number for [contact name]" |
| **Manage tasks** | "Show me my Microsoft To Do tasks" |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "m365: command not found" | Close and reopen your terminal. If still not found, reinstall: `npm install -g @pnp/cli-microsoft365` |
| Browser does not open during sign-in | Run `m365 login` (without `--authType browser`) — use the device code method instead |
| Wrong Microsoft account connected | Run `m365 logout` then `m365 login --authType browser` — select the correct account |
| "Access denied" for Teams or SharePoint | Those features may need approval from your IT department on a work account. Personal accounts (outlook.com) have full access. |
| "No emails found" after login | Try `m365 outlook mail list --pageSize 20` to load more results |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Work / Company Accounts

If your Outlook is managed by your employer, some features (Teams, SharePoint) may require your IT administrator to approve the connection. For personal outlook.com or hotmail.com accounts, everything works immediately with no restrictions.

---

## Playwright Fallback

If any Outlook feature is unavailable through the CLI, your assistant can use its built-in browser automation (Playwright) to access Outlook Web directly. Just ask normally — for example, "Open my Outlook and check if there are any emails from last week" — and the assistant will use the browser if needed.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
