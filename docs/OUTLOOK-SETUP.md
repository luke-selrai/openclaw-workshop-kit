---
title: Microsoft Outlook & 365 Setup Guide
version: 1.0
date: 2026-04-01
---

# Microsoft Outlook & 365 — Setup Guide

This guide connects your Microsoft account to your AI assistant. Once set up, your assistant can read and send emails, check your calendar, access OneDrive files, work with Excel, browse SharePoint, use OneNote, and interact with Teams — all through Outlook and Microsoft 365.

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
| **OneDrive** | Find, open, and work with your files |
| **Excel** | Read and update spreadsheets |
| **SharePoint** | Browse and search company documents |
| **OneNote** | Read and add to your notebooks |
| **Teams** | Read messages and channel conversations |
| **Contacts** | Look up and manage your contacts |

---

## Step 1 — Register Your App (One-Time Setup, ~5 Minutes)

This creates a private connection between your computer and Microsoft. It is free and only takes a few minutes.

### 1.1 — Go to the Azure Portal

Open your browser and go to:

```
https://portal.azure.com
```

Sign in with the **same Microsoft account** you use for Outlook.

> If you have never used Azure before, that is fine — just sign in and it will take you straight to the dashboard.

---

### 1.2 — Find App Registrations

1. In the search bar at the top of the page, type: **App registrations**
2. Click the result that says **"App registrations"** (it has a blue puzzle-piece icon)
3. Click the **"+ New registration"** button near the top left

---

### 1.3 — Fill In the Registration Form

You will see a form with three sections. Fill it in like this:

**Name:**
Type anything — for example: `My AI Assistant`

**Supported account types:**
Select the option that says:
> "Accounts in any organizational directory (Any Microsoft Entra ID tenant - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)"

This makes it work with both personal (outlook.com) and work accounts.

**Redirect URI:**
- Click the dropdown that says "Select a platform" and choose: **"Mobile and desktop applications"**
- In the box that appears, tick the checkbox next to: `https://login.microsoftonline.com/common/oauth2/nativeclient`

Click **"Register"** at the bottom.

---

### 1.4 — Copy Your Client ID

After registering, you will see a summary page. Find the line that says **"Application (client) ID"** — it looks like a long string of letters and numbers.

**Copy that entire ID** — you will need it in Step 3.

> Example of what it looks like: `a1b2c3d4-1234-5678-abcd-ef1234567890`

---

### 1.5 — Add Permissions

Your assistant needs permission to access your Microsoft tools. Here is how to add them:

1. In the left-hand menu, click **"API permissions"**
2. Click **"+ Add a permission"**
3. Click **"Microsoft Graph"**
4. Click **"Delegated permissions"**
5. In the search box, search for and tick each of these permissions one by one:

**Email (Outlook):**
- `Mail.Read`
- `Mail.Send`
- `Mail.ReadWrite`

**Calendar:**
- `Calendars.Read`
- `Calendars.ReadWrite`

**Contacts:**
- `Contacts.Read`
- `Contacts.ReadWrite`

**OneDrive & Files:**
- `Files.Read.All`
- `Files.ReadWrite.All`

**OneNote:**
- `Notes.Read`
- `Notes.ReadWrite`

**SharePoint:**
- `Sites.Read.All`

**Teams:**
- `Team.ReadBasic.All`
- `ChannelMessage.Read.All`

**Profile (required):**
- `User.Read`

6. Click **"Add permissions"** when done

> You do not need to click "Grant admin consent" — your assistant will ask for your approval when it first connects.

---

## Step 2 — Connect Your Assistant

Go back to your Claude Code command window and paste this command. Replace `YOUR_CLIENT_ID` with the ID you copied in Step 1.4:

```
claude mcp add ms365 --scope user -e CLIENT_ID=YOUR_CLIENT_ID -e TENANT_ID=common npx -y ms-365-mcp-server
```

**Example** (with a real-looking Client ID):

```
claude mcp add ms365 --scope user -e CLIENT_ID=a1b2c3d4-1234-5678-abcd-ef1234567890 -e TENANT_ID=common npx -y ms-365-mcp-server
```

Press Enter and wait for it to finish. This installs the connection tool automatically.

---

## Step 3 — Sign In to Microsoft

The first time your assistant tries to use Outlook or any Microsoft tool, it will ask you to sign in.

You will see a message like this in the command window:

```
To sign in, open a browser and go to https://microsoft.com/devicelogin
Enter the code: XXXXX-XXXXX
```

1. Open your browser
2. Go to: `https://microsoft.com/devicelogin`
3. Type in the code shown in your command window
4. Sign in with your Microsoft account
5. Click **"Allow"** to give permission

You only need to do this once. After that, your assistant stays connected automatically.

---

## Step 4 — Verify It Works

Restart Claude Code completely, then ask your assistant:

- "Show me my unread Outlook emails"
- "What meetings do I have this week?"
- "List my recent OneDrive files"

If it responds with your actual data, the connection is working.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Read emails** | "Show me my unread emails" |
| **Send an email** | "Send an email to john@example.com about tomorrow's meeting" |
| **Reply to an email** | "Reply to the email from Sarah and say I will be there at 3pm" |
| **Search emails** | "Find emails from my accountant in the last month" |
| **Check calendar** | "What meetings do I have this week?" |
| **Create a meeting** | "Schedule a call with Lisa on Thursday at 10am" |
| **Find a file** | "Find the budget spreadsheet in my OneDrive" |
| **Read a spreadsheet** | "Open the Sales Tracker in my OneDrive and summarise it" |
| **Check Teams** | "Show me the latest messages in the General channel" |
| **Search SharePoint** | "Find the company policy document on SharePoint" |
| **Check contacts** | "Find the phone number for [contact name]" |
| **Search OneNote** | "Find my notes about the client meeting last month" |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "npx: command not found" | Make sure Node.js is installed: run `node --version`. If not found, reinstall from [nodejs.org](https://nodejs.org) |
| Device login code does not appear | Restart Claude Code and try asking your assistant to check your emails again |
| "Access denied" or "Insufficient permissions" | Go back to Step 1.5 and make sure all the permissions are ticked. You may need to sign out and sign back in after adding new permissions |
| Wrong Microsoft account connected | Sign out of Microsoft in your browser, then trigger the device login again and sign in with the correct account |
| "Client ID not found" | Double-check you copied the full Client ID from Step 1.4 — it should look like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| Works for email but not Teams or SharePoint | Those permissions (`Team.ReadBasic.All`, `Sites.Read.All`) may need approval from your IT department if you are on a company account |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Work / Company Accounts

If your Outlook is managed by your employer (common if your email ends in your company name), some permissions may need to be approved by your IT administrator. If you see a message saying "Need admin approval", forward this guide to your IT team and ask them to grant consent for the permissions listed in Step 1.5.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
