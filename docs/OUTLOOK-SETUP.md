---
title: Microsoft Outlook & 365 Setup Guide
version: 3.0
date: 2026-04-01
---

# Microsoft Outlook & 365 — Setup Guide

This guide connects your Microsoft account to your AI assistant. Once set up, your assistant can read and send emails, check your calendar, access OneDrive files, work with Excel, browse SharePoint, use OneNote, interact with Teams, and manage your contacts — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js **version 20 or higher** installed — check by typing `node --version` in the command window
- A Microsoft account — personal (outlook.com, hotmail.com) or work/school (Microsoft 365)
- An internet connection

> **If `node --version` shows v18 or lower:** Update Node.js from [nodejs.org](https://nodejs.org) before continuing.

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

This may take 1–2 minutes. When it finishes, verify it worked:

```
m365 --version
```

You should see a version number. If you see "command not found":
- **Windows:** Close the command window completely and open a new one, then try again
- **Mac:** Run `export PATH="$(npm prefix -g)/bin:$PATH"` and try again

---

## Step 2 — Set Up Your Microsoft Connection (One-Time)

This step creates a secure private link between the tool and your Microsoft account. It only needs to be done once.

```
m365 setup --interactive
```

A browser window will open and walk you through a short setup. Follow the steps it shows — it handles everything automatically.

> If you see any errors during setup, contact your workshop facilitator.

---

## Step 3 — Sign In to Your Microsoft Account

```
m365 login --authType browser
```

A browser window will open:

1. **Select the Microsoft account you want to use** — double-check this is the right one
2. You may see a permissions screen — click **"Accept"** or **"Allow"**
3. You should see a success message in the browser

> **If the browser does not open automatically**, use this instead:
> ```
> m365 login
> ```
> This shows a short code and a URL. Open `https://aka.ms/devicelogin` in your browser, enter the code, and sign in.

---

## Step 4 — Test It

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
| "m365: command not found" after install | Close and reopen your terminal. On Mac, also run: `export PATH="$(npm prefix -g)/bin:$PATH"` |
| Node.js version too old | Update from [nodejs.org](https://nodejs.org) — download the LTS version |
| `m365 setup` fails or freezes | Close and reopen your terminal, then try again. If it keeps failing, contact your workshop facilitator |
| Browser does not open during sign-in | Run `m365 login` (without `--authType browser`) and use the device code method at `https://aka.ms/devicelogin` |
| Wrong Microsoft account connected | Run `m365 logout` then `m365 setup --interactive` and `m365 login --authType browser` — select the correct account |
| "Access denied" for Teams or SharePoint | Personal outlook.com accounts have full access. Work accounts may need IT admin approval for Teams and SharePoint |
| "No emails found" after connecting | Try `m365 outlook mail list --pageSize 20` — your inbox may just be empty or filtered |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Work / Company Accounts

If your Outlook is managed by your employer, some features (Teams, SharePoint) may require your IT administrator to approve the connection during the `m365 setup` step. For personal outlook.com or hotmail.com accounts, everything works immediately with no restrictions.

---

## Playwright Fallback

If any Outlook feature is unavailable through the CLI, your assistant can use its built-in browser automation (Playwright) to access Outlook Web directly. Just ask normally — for example, "Open my Outlook and check the email from last week" — and the assistant will use the browser if the CLI cannot handle it.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
