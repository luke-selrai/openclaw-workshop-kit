---
title: Google Workspace MCP Setup Guide
version: 3.0
date: 2026-03-25
---

# Google Workspace MCP — Setup Guide

This guide walks you through connecting Google Workspace (Gmail, Calendar, Drive, Docs, Sheets) to Claude Code as a built-in tool. Once connected, you can just ask your assistant things like "send an email" or "check my calendar" — no commands needed.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js installed (check by typing `node --version` in the command window)
- A Google account (e.g. yourname@gmail.com or yourname@yourbusiness.com)

---

## Part A — Set Up a Google Cloud Project

This is a one-time step. It creates a "bridge" between Claude Code and your Google account.

**Step 1 — Create the Project**

1. Open your browser and go to **console.cloud.google.com**
2. Sign in with your Google account
3. Click the project dropdown at the top of the page (it might say "Select a project")
4. Click **"New Project"**
5. Name it something like **"Claude Workspace"**
6. Click **"Create"**

**Step 2 — Turn On Google Services**

1. Click the menu icon (three horizontal lines, top-left)
2. Click **"APIs & Services"**, then **"Library"**
3. Search for and enable each of these (click on each one, then click the blue **"Enable"** button):
   - Gmail API
   - Google Calendar API
   - Google Drive API
   - Google Docs API
   - Google Sheets API
   - Google Slides API
   - People API

**Step 3 — Set Up the Login Screen**

1. Go to **"APIs & Services"** → **"OAuth consent screen"**
2. Select **"External"** and click **"Create"**
3. Fill in the app name (e.g. "Claude Workspace") and your email
4. Click **"Save and Continue"** through the remaining steps
5. On the **"Test users"** page, click **"Add users"**
6. Add your email address (the one you want to use with Claude)
7. Click **"Save"**

**Step 4 — Create Login Credentials**

1. Go to **"APIs & Services"** → **"Credentials"**
2. Click **"+ Create Credentials"** at the top
3. Choose **"OAuth client ID"**
4. For Application type, choose **"Desktop app"**
5. Name it anything (e.g. "Claude Desktop")
6. Click **"Create"**
7. You will see a **Client ID** and **Client Secret** — copy both and save them somewhere safe

**Step 5 — Download the Credentials File**

1. Stay on the **"Credentials"** page
2. Find your OAuth client and click the **download icon** (arrow pointing down) on the right
3. This downloads a JSON file — you will need it in Part B

---

## Part B — Connect Google Workspace MCP to Claude Code

**Step 1 — Add the MCP Server**

Take the **Client ID** and **Client Secret** from Part A, Step 4. Type this in the command window, replacing the two placeholder values with your actual credentials:

```
claude mcp add google-workspace --scope user -e GOOGLE_CLIENT_ID=YOUR_CLIENT_ID_HERE -e GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET_HERE -e GOOGLE_WORKSPACE_SERVICES=drive,gmail,calendar,docs,sheets -- npx @dguido/google-workspace-mcp
```

You should see: `Added stdio MCP server google-workspace`

**Step 2 — Copy the Credentials File**

The MCP also needs the credentials file you downloaded in Part A, Step 5.

**Mac/Linux:**
```
mkdir -p ~/.config/google-workspace-mcp
cp ~/Downloads/client_secret_*.json ~/.config/google-workspace-mcp/credentials.json
```

**Windows:**
```
mkdir %USERPROFILE%\.config\google-workspace-mcp
copy %USERPROFILE%\Downloads\client_secret_*.json %USERPROFILE%\.config\google-workspace-mcp\credentials.json
```

**Step 3 — Sign In to Google**

1. Type this in the command window and press Enter:

```
npx @dguido/google-workspace-mcp auth
```

2. A URL will appear in the command window — if the browser doesn't open, copy the URL and paste it into your browser
3. On the Google sign-in screen, **select your account**
4. You may see a warning that says "Google hasn't verified this app" — click **"Continue"**
5. Click **"Allow"** to give permission
6. You should see a success message

> **If you get a `redirect_uri_mismatch` error:** Check the URL in your browser — it will show something like `http://127.0.0.1:45107/oauth2callback`. Go back to Google Cloud → **Credentials** → click your OAuth client → **Authorised redirect URIs** → add that exact URI → click **Save**. Then try the sign-in command again.

**Step 4 — Restart Claude Code**

Close Claude Code completely and reopen it. The Google Workspace tools will now be available.

---

## Part C — Test It

Once Claude Code is restarted, test it by asking your assistant:

- "Send a test email to someone@example.com"
- "What's on my calendar today?"
- "List my recent Drive files"

Your assistant can now use Gmail, Calendar, Drive, Docs, and Sheets directly — no commands needed.

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

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `redirect_uri_mismatch` error | Check the URL in the browser for the port and path (e.g. `http://127.0.0.1:45107/oauth2callback`). Add that exact URI as a redirect URI in Google Cloud credentials (Part A, Step 4 → click the OAuth client → Authorised redirect URIs). |
| "Access blocked" during sign-in | Your email needs to be added as a test user in Google Cloud (Part A, Step 3) |
| "API not enabled" error | Go back to Part A, Step 2 and make sure all APIs are turned on |
| `credentials.json not found` | Make sure you copied the downloaded file to the right location (Part B, Step 2) |
| Browser doesn't open during sign-in | Copy the URL from the command window and paste it into your browser manually |
| MCP tools not showing in Claude Code | Restart Claude Code completely — close and reopen it |
| Wrong Google account connected | Delete the saved login and sign in again: `rm -rf ~/.config/google-workspace-mcp/tokens.json` then run `npx @dguido/google-workspace-mcp auth` |
| MCP still connecting after restart | Wait about 10 seconds — the first load can take a moment to download the package |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
