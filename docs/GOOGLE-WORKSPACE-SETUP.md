---
title: Google Workspace CLI & MCP Setup Guide
version: 1.0
date: 2026-03-24
---

# Google Workspace — CLI & MCP Setup Guide

This guide walks you through connecting Google Workspace (Gmail, Calendar, Drive, Docs, Sheets) to Claude Code.

There are two parts:
- **Part A** — Install the Google Workspace CLI (the `gws` command)
- **Part B** — Set up Google Cloud credentials (required for both CLI and MCP)
- **Part C** — Connect Google Workspace as an MCP server in Claude Code

---

## Important Note

The Google Cloud project and credentials are typically set up under a **developer account** (e.g. developer@selrai.com.au), not a personal account. However, the person **using** the tools signs in with their own Google account (e.g. rodolfo@selrai.com.au) during the login step.

---

## Part A — Install the Google Workspace CLI

**What this does:** Installs a command called `gws` that lets you interact with Google services (Drive, Gmail, Calendar, Sheets, etc.) from the command window.

1. Make sure Node.js is installed — type `node --version` and press Enter
2. If you see a version number, you're good. If not, follow the Node.js install steps in [SETUP-GUIDE.md](SETUP-GUIDE.md)
3. Type this and press Enter:

```
npm i -g @googleworkspace/cli
```

4. Once it finishes, type this to confirm it worked:

```
gws --version
```

You should see a version number. That means the CLI is installed.

---

## Part B — Set Up Google Cloud Credentials

This is a one-time step. You need a Google Cloud project with login credentials so that the CLI and MCP can talk to Google on your behalf.

### Option 1 — Automatic Setup (if you have `gcloud` installed)

1. Type this and press Enter:

```
gws auth setup
```

2. Follow the prompts — it will create a project, turn on the right settings, and log you in

### Option 2 — Manual Setup (if you don't have `gcloud`)

**Step 1 — Create a Google Cloud Project**

1. Open your browser and go to **console.cloud.google.com**
2. Sign in with the developer account (e.g. developer@selrai.com.au)
3. Click the project dropdown at the top of the page (it might say "Select a project")
4. Click **"New Project"**
5. Name it something like **"Claude Workspace"**
6. Click **"Create"**

**Step 2 — Turn On the Google Services**

1. In the Google Cloud console, click the menu icon (three horizontal lines, top-left)
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
6. Add the email addresses of anyone who will use this (e.g. rodolfo@selrai.com.au)
7. Click **"Save"**

**Step 4 — Create Login Credentials**

1. Go to **"APIs & Services"** → **"Credentials"**
2. Click **"+ Create Credentials"** at the top
3. Choose **"OAuth client ID"**
4. For Application type, choose **"Desktop app"**
5. Name it anything (e.g. "Claude Desktop")
6. Click **"Create"**
7. You will see a **Client ID** and **Client Secret** — copy both and save them somewhere safe

---

## Part C — Connect Google Workspace MCP to Claude Code

This lets Claude Code directly use Gmail, Calendar, Drive, Docs, and more as tools.

1. Take the **Client ID** and **Client Secret** from Part B, Step 4
2. Type this in the command window (replace the two placeholder values with your actual credentials):

```
claude mcp add google-workspace -e GOOGLE_CLIENT_ID=YOUR_CLIENT_ID_HERE -e GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET_HERE -e GOOGLE_WORKSPACE_SERVICES=drive,gmail,calendar,docs,sheets -- npx @dguido/google-workspace-mcp
```

3. Restart Claude Code
4. The first time you use a Google tool, a browser window will open asking you to sign in
5. **Sign in with your own Google account** (e.g. rodolfo@selrai.com.au) — not the developer account
6. Click **"Allow"**

That's it — Claude Code can now work with your Google services directly.

---

## Using the CLI Separately

Once set up, you can also use the `gws` command on its own:

- **Log in:** `gws auth login -s drive,gmail,calendar,sheets`
- **List Drive files:** `gws drive files list`
- **Check email:** `gws gmail +triage`
- **See your calendar:** `gws calendar +agenda`

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `gws: command not found` | Restart your command window, or reinstall with `npm i -g @googleworkspace/cli` |
| "Access blocked" during sign-in | The user's email needs to be added as a test user in Google Cloud (Part B, Step 3) |
| "API not enabled" error | Go back to Part B, Step 2 and make sure all APIs are turned on |
| MCP not showing tools | Restart Claude Code after adding the MCP server |
| Wrong Google account connected | Clear saved tokens: `rm -rf ~/.config/google-workspace-mcp/` then restart Claude Code |
