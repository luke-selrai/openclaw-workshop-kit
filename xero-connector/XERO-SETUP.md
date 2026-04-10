---
title: Xero Connector â€” Setup Guide
version: 1.0
date: 2026-04-09
---

# Xero Connector â€” Setup Guide

This guide connects your Xero accounting account to Claude Code. Once set up, Claude can read and create invoices, look up contacts, view your chart of accounts, and pull financial reports â€” all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working
- Node.js **version 20 or higher** â€” check by typing `node --version` in your terminal
- A Xero account (any plan â€” Starter, Standard, or Premium)
- An internet connection

> **If `node --version` shows v18 or lower:** Update Node.js from [nodejs.org](https://nodejs.org) before continuing. Download the LTS version (v22 or v20).

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 â€” x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac â€” Intel (2020 and older) | Yes |
| Mac â€” Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What Claude Can Do With Xero

| Task | What to Say |
|---|---|
| **Check invoices** | "Show me my unpaid invoices" |
| **Create an invoice** | "Create a Xero invoice for Acme Corp for $500" |
| **Find a contact** | "Find John Smith in my Xero contacts" |
| **Add a contact** | "Add a new contact called ABC Pty Ltd" |
| **Profit & Loss** | "Show me the Xero profit and loss for this year" |
| **Balance Sheet** | "Get the Xero balance sheet as of today" |
| **Chart of accounts** | "List my Xero expense accounts" |
| **Payments** | "Show me recent payments in Xero" |

---

## Step 1 â€” Install the Connector

**Windows:** Double-click `setup.bat` and follow the on-screen prompts.

**Mac:** Open Terminal, drag the `setup.sh` file into the window, and press Enter.

The script will install the required packages automatically.

> If the scripts don't run, open your terminal and run `npm install` inside the `xero-connector` folder manually.

---

## Step 2 â€” Create a Xero Developer App (One-Time)

Xero requires every connection to use a developer "app" â€” this is free and takes about 2 minutes.

1. Go to [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
2. Sign in with your Xero account
3. Click **New app**
4. Fill in the form:
   - **App name:** `Claude Code Connector` (or any name you like)
   - **Company or application URL:** `https://selrai.com.au` (or your own website)
   - **OAuth 2.0 redirect URI:** `http://localhost:3000/callback`
   - **What do you intend to use this app for?** â€” select **My own use**
5. Click **Create app**
6. You are now on the app detail page â€” click **Generate a secret** to reveal your Client Secret
7. **Copy both values:**
   - **Client ID** â€” shown at the top of the page
   - **Client Secret** â€” shown after you click Generate a secret

> **Important:** The Client Secret is only shown once. Copy it now before leaving the page.

---

## Step 3 â€” Add Your Credentials

1. In the `xero-connector` folder, find the file called `.env.example`
2. Copy it and rename the copy to `.env`:
   - **Windows:** Right-click `.env.example` â†’ Copy â†’ Paste â†’ rename to `.env`
   - **Mac/Linux:** Run `cp .env.example .env` in your terminal
3. Open `.env` in any text editor (Notepad, TextEdit, VS Code)
4. Replace the placeholder values:

```
XERO_CLIENT_ID=paste_your_client_id_here
XERO_CLIENT_SECRET=paste_your_client_secret_here
```

Save and close the file.

---

## Step 4 â€” Sign In to Xero

Run this command in your terminal (inside the `xero-connector` folder):

```
npm run auth
```

A browser window will open:

1. Sign in with your Xero account if prompted
2. Select the Xero organisation you want to connect
3. Click **Allow access**
4. You should see a green success page â€” return to your terminal

Your terminal should display:
```
âœ…  Connected to: Your Organisation Name
================================================
  All done! Xero is connected to Claude Code.
================================================
```

> **If the browser does not open:** The sign-in URL is printed in your terminal. Copy and paste it into any browser.

---

## Step 5 â€” Add Xero to Claude Code

You need to tell Claude Code where to find the Xero server. This is a one-time configuration.

### Find the full path to your xero-connector folder

**Windows:** Open the `xero-connector` folder in File Explorer. Click the address bar at the top â€” it shows the full path (e.g. `C:\Users\You\xero-connector`).

**Mac:** Open Terminal, drag the `xero-connector` folder into the window, and press Space â€” the full path appears.

### Add to Claude Code settings

Open (or create) the file `~/.claude.json` in a text editor and add the `xero` block under `mcpServers`:

**Windows example:**
```json
{
  "mcpServers": {
    "xero": {
      "command": "node",
      "args": ["C:\\Users\\YourName\\xero-connector\\src\\index.js"]
    }
  }
}
```
> On Windows, use double backslashes (`\\`) in the path.

**Mac/Linux example:**
```json
{
  "mcpServers": {
    "xero": {
      "command": "node",
      "args": ["/Users/YourName/xero-connector/src/index.js"]
    }
  }
}
```

If you already have other MCP servers configured, add the `"xero"` block alongside them â€” do not replace the existing entries.

### Where is `~/.claude.json`?

| Operating System | Location |
|---|---|
| Windows | `C:\Users\YourName\.claude.json` |
| Mac | `/Users/YourName/.claude.json` |

---

## Step 6 â€” Test It

Restart Claude Code, then try asking:

- "Show me my recent Xero invoices"
- "What organisation am I connected to in Xero?"
- "List my Xero contacts"

Or test the server directly in your terminal:

```bash
# List available tools
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | node src/index.js

# Get your organisation
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"xero_get_organisation","arguments":{}}}' | node src/index.js
```

---

## Keeping Your Connection Active

Xero tokens refresh automatically. If you see a "token expired" error in Claude, run:

```
npm run auth
```

This reconnects your account in under 30 seconds.

---

## Troubleshooting

### Installation Problems

| Problem | Fix |
|---|---|
| `node --version` shows v18 or lower | Update Node.js at [nodejs.org](https://nodejs.org) â€” download the LTS version |
| **EPERM / permission denied** on Windows | Close the window, right-click `setup.bat` â†’ "Run as administrator", try again |
| **EACCES** on Mac | Install via nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` then `nvm install --lts` and retry |
| **ECONNRESET / 403** during install | Corporate firewall blocking npmjs.com. Ask IT to allow `registry.npmjs.org:443` |
| Script blocked on Mac ("developer cannot be verified") | Right-click `setup.sh` â†’ Open, or run: `xattr -d com.apple.quarantine setup.sh` |
| Script blocked on Windows ("running scripts is disabled") | Run in PowerShell: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then retry |

### App & Credentials Problems

| Problem | Fix |
|---|---|
| "Missing credentials" on `npm run auth` | Open `.env` and confirm you replaced `your_client_id_here` and `your_client_secret_here` with real values |
| "redirect_uri_mismatch" in browser | In your Xero app settings at developer.xero.com, confirm the redirect URI is exactly `http://localhost:3000/callback` |
| Client Secret not showing in Xero | Go to your app at developer.xero.com and click **Generate a secret** again â€” this creates a new one |
| "Invalid scope for client" on auth | Your Xero app was created after 2 March 2026 and only supports granular scopes. The setup script uses the correct granular scopes automatically — if you see this error, check that your Client ID in `.env` matches the app at developer.xero.com |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it and try again |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Check the path in `~/.claude.json` â€” it must be the full absolute path, not a relative path |
| "Token expired" error | Run `npm run auth` again to refresh your token |
| "No Xero organisations found" | Run `npm run auth` again â€” the previous token may be invalid |
| Wrong Xero organisation connected | Run `npm run auth` again and select the correct organisation |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Security Notes

- Your Xero credentials are stored only in the `.env` file on your computer
- Your Xero access token is stored in `.xero-token.json` â€” this file is excluded from Git
- Never share your `.env` or `.xero-token.json` files with anyone
- The connector only requests read/write access to accounting data â€” it does not access payroll or files

---

*Built by Selr AI â€” [selrai.com.au](https://selrai.com.au)*

