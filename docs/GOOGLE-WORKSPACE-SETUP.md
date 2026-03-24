---
title: Google Workspace CLI & MCP Setup Guide
version: 2.0
date: 2026-03-24
---

# Google Workspace — CLI & MCP Setup Guide

This guide walks you through connecting Google Workspace (Gmail, Calendar, Drive, Docs, Sheets) to Claude Code using the `gws` command.

There are three parts:
- **Part A** — Install the Google Workspace CLI
- **Part B** — Set up Google Cloud credentials
- **Part C** — Log in and start using it

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

You should see a version number (e.g. `gws 0.19.0`). That means the CLI is installed.

---

## Part B — Set Up Google Cloud Credentials

This is a one-time step. You need a Google Cloud project with login credentials so that `gws` can connect to Google on your behalf.

### Option 1 — Automatic Setup (if you have `gcloud` installed)

1. Type this and press Enter:

```
gws auth setup
```

2. Follow the prompts — it will create a project, turn on the right settings, and log you in
3. Skip to **Part C**

### Option 2 — Manual Setup (if you don't have `gcloud`)

**Step 1 — Create a Google Cloud Project**

1. Open your browser and go to **console.cloud.google.com**
2. Sign in with your Google account
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

**Step 5 — Add Redirect URIs (IMPORTANT)**

The `gws` tool uses a random port number each time it runs the login. You need to allow this in your Google Cloud project:

1. Stay on the **"Credentials"** page
2. Click on the OAuth client you just created
3. Scroll down to **"Authorised redirect URIs"**
4. Add these URIs (click **"+ Add URI"** for each one):
   - `http://localhost`
   - `http://127.0.0.1`
5. Click **"Save"**

> **Note:** If you get a `redirect_uri_mismatch` error during login, check the URL in your browser — it will show something like `http://localhost:42599`. Copy that port number and add `http://localhost:[that port]` as another redirect URI in Google Cloud. Then try again.

**Step 6 — Download the Credentials File**

1. Go back to **"APIs & Services"** → **"Credentials"**
2. Find your OAuth client and click the **download icon** (arrow pointing down) on the right
3. This downloads a JSON file
4. Move or copy that file to: `~/.config/gws/client_secret.json`

On Mac/Linux, you can do this in the command window:
```
mkdir -p ~/.config/gws
mv ~/Downloads/client_secret_*.json ~/.config/gws/client_secret.json
```

---

## Part C — Log In and Start Using It

1. Type this in the command window and press Enter:

```
gws auth login -s gmail,drive,calendar,sheets
```

2. A long URL will appear in the command window
3. If a browser window does not open automatically, **copy the URL** and paste it into your browser manually
4. On the Google sign-in screen, **select the account you want to use** (e.g. rodolfo@selrai.com.au)
5. You may see a warning that says "Google hasn't verified this app" — click **"Continue"**
6. Click **"Allow"** to give permission

Done! You can now use `gws` to work with your Google services.

---

## What You Can Do Now

### Send an Email

```
gws gmail +send --to "someone@example.com" --subject "Hello" --body "This is a test email."
```

### Check Your Email

```
gws gmail +triage
```

### List Your Drive Files

```
gws drive files list
```

### See Your Calendar

```
gws calendar +agenda
```

### Other Services

```
gws sheets +append
gws docs +create
```

Your AI assistant can also run these commands for you — just ask in plain English (e.g. "Send a test email to someone@example.com").

---

## Connecting as an MCP Server (Optional — Advanced)

If you want Claude Code to have Google Workspace tools built in (instead of using `gws` commands), you can connect a separate MCP server:

1. Take the **Client ID** and **Client Secret** from Part B, Step 4
2. Type this in the command window (replace the two placeholder values with your actual credentials):

```
claude mcp add google-workspace -e GOOGLE_CLIENT_ID=YOUR_CLIENT_ID_HERE -e GOOGLE_CLIENT_SECRET=YOUR_CLIENT_SECRET_HERE -e GOOGLE_WORKSPACE_SERVICES=drive,gmail,calendar,docs,sheets -- npx @dguido/google-workspace-mcp
```

3. Restart Claude Code
4. The first time you use a Google tool, a browser window will open asking you to sign in
5. **Sign in with your own Google account** — not the developer account
6. Click **"Allow"**

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `gws: command not found` | Restart your command window, or reinstall with `npm i -g @googleworkspace/cli` |
| `redirect_uri_mismatch` error | Check the URL in the browser for the port number (e.g. `:42599`). Add `http://localhost:[port]` as a redirect URI in Google Cloud credentials. See Part B, Step 5. |
| `invalid_request` / missing `response_type` | Your credentials file may be outdated. Re-download it from Google Cloud (Part B, Step 6) and replace `~/.config/gws/client_secret.json` |
| "Access blocked" during sign-in | Your email needs to be added as a test user in Google Cloud (Part B, Step 3) |
| "API not enabled" error | Go back to Part B, Step 2 and make sure all APIs are turned on |
| Browser doesn't open automatically | Copy the URL from the command window and paste it into your browser manually |
| Login URL opens but nothing happens after clicking Allow | Close the browser tab, go back to the command window — it should show a success message |
| MCP not showing tools | Restart Claude Code after adding the MCP server |
| Wrong Google account connected | Clear saved tokens: `rm -rf ~/.config/google-workspace-mcp/` then restart Claude Code |
| Wrong account on `gws` CLI | Run `gws auth logout` then `gws auth login -s gmail,drive,calendar` and pick the correct account |
