---
title: Xero Connector — Setup Guide
version: 1.0
date: 2026-04-10
---

# Xero Connector — Setup Guide

This guide connects your Xero accounting account to Claude Code. Once set up, Claude can read and create invoices, look up contacts, view your chart of accounts, check payments, and pull financial reports — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js **version 20 or higher** installed — check by typing `node --version` in the command window
- A Xero account (any plan — Starter, Standard, or Premium)
- An internet connection

> **If `node --version` shows v18 or lower:** Update Node.js from [nodejs.org](https://nodejs.org) before continuing. Download the LTS version (v22 or v20).

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
| **Invoices** | List, view, and create invoices |
| **Contacts** | Search customers and suppliers, add new contacts |
| **Chart of Accounts** | Browse your account codes and types |
| **Profit & Loss** | Pull income and expense reports for any date range |
| **Balance Sheet** | View assets, liabilities, and equity at a point in time |
| **Payments** | List payments recorded against invoices and bills |
| **Organisation** | Check which Xero organisation is connected |

---

## Step 1 — Install the Connector

**Windows:** Double-click `setup.bat` and follow the on-screen prompts.

**Mac:** Open Terminal, drag the `setup.sh` file into the window, and press Enter.

The script will install the required packages automatically.

> If the scripts don't run, open your terminal, navigate to the `xero-connector` folder, and run `npm install` manually.

---

## Step 2 — Create a Xero Developer App (One-Time)

Xero requires every connection to use a developer "app" — this is free and takes about 2 minutes.

1. Go to [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
2. Sign in with your Xero account
3. Click **New app**
4. Fill in the form:
   - **App name:** `Claude Code Connector` (or any name you like)
   - **Company or application URL:** `https://selrai.com.au` (or your own website)
   - **OAuth 2.0 redirect URI:** `http://localhost:3000/callback`
   - **What do you intend to use this app for?** — select **My own use**
5. Click **Create app**
6. You are now on the app detail page — click **Generate a secret** to reveal your Client Secret
7. **Copy both values:**
   - **Client ID** — shown at the top of the page
   - **Client Secret** — shown after you click Generate a secret

> **Important:** The Client Secret is only shown once. Copy it now before leaving the page.

---

## Step 3 — Add Your Credentials

1. In the `xero-connector` folder, find the file called `.env.example`
2. Copy it and rename the copy to `.env`:
   - **Windows:** Right-click `.env.example` → Copy → Paste → rename to `.env`
   - **Mac/Linux:** Run `cp .env.example .env` in your terminal
3. Open `.env` in any text editor (Notepad, TextEdit, VS Code)
4. Replace the placeholder values:

```
XERO_CLIENT_ID=paste_your_client_id_here
XERO_CLIENT_SECRET=paste_your_client_secret_here
```

Save and close the file.

---

## Step 4 — Sign In to Xero

Run this command in your terminal (inside the `xero-connector` folder):

```
npm run auth
```

A browser window will open:

1. Sign in with your Xero account if prompted
2. Select the Xero organisation you want to connect
3. Click **Allow access**
4. You should see a green success page — return to your terminal

Your terminal should display:
```
Connected to: Your Organisation Name
================================================
  All done! Xero is connected to Claude Code.
================================================
```

> **If the browser does not open:** The sign-in URL is printed in your terminal. Copy and paste it into any browser.

---

## Step 5 — Add Xero to Claude Code

You need to tell Claude Code where to find the Xero server. This is a one-time configuration.

### Find the full path to your xero-connector folder

**Windows:** Open the `xero-connector` folder in File Explorer. Click the address bar at the top — it shows the full path (e.g. `C:\Users\You\xero-connector`).

**Mac:** Open Terminal, drag the `xero-connector` folder into the window, and press Space — the full path appears.

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

If you already have other MCP servers configured, add the `"xero"` block alongside them — do not replace the existing entries.

### Where is `~/.claude.json`?

| Operating System | Location |
|---|---|
| Windows | `C:\Users\YourName\.claude.json` |
| Mac | `/Users/YourName/.claude.json` |

---

## Step 6 — Test It

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

## What Your Assistant Can Do Now

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

## Troubleshooting

### Installation Problems

| Problem | Fix |
|---|---|
| `node --version` shows v18 or lower | Update Node.js at [nodejs.org](https://nodejs.org) — download the LTS version (v22 or v20) |
| **EPERM / permission denied** on Windows | Close the window, right-click `setup.bat` → "Run as administrator", try again |
| **EACCES** on Mac | Avoid using `sudo npm`. Instead install via nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` then `nvm install --lts` and retry |
| **EINTEGRITY** error during install | npm cache is corrupted. Run `npm cache clean --force` then try again |
| **ECONNRESET / 403** during install | Corporate firewall blocking npmjs.com. Ask IT to allow `registry.npmjs.org:443` |
| install fails on Mac — "command not found: node" | nvm installed but not loaded. Run `source ~/.nvm/nvm.sh` then retry |
| Script blocked on Mac ("developer cannot be verified") | Right-click `setup.sh` → Open, or run: `xattr -d com.apple.quarantine setup.sh` |
| Script blocked on Windows ("running scripts is disabled") | Run in PowerShell: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then retry |
| Windows Defender blocks npm install (EBUSY) | Temporarily pause Real-Time Protection in Windows Security, run setup.bat, then re-enable |
| Path too long error on Windows | Your folder path may exceed Windows' 260-character limit. Move the `xero-connector` folder to `C:\workshop\` and try again |

### App & Credentials Problems

| Problem | Fix |
|---|---|
| "Missing credentials" on `npm run auth` | Open `.env` and confirm you replaced `your_client_id_here` and `your_client_secret_here` with real values |
| "redirect_uri_mismatch" in browser | In your Xero app settings at developer.xero.com, confirm the redirect URI is exactly `http://localhost:3000/callback` |
| Client Secret not showing in Xero | Go to your app at developer.xero.com and click **Generate a secret** again — this creates a new one (the old one is revoked) |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it and try again, or stop the other process first |
| "invalid_client" error in browser | Your Client ID or Secret is wrong. Double-check both values in `.env` match exactly what Xero shows |
| "Invalid scope for client" on auth | Your Xero app was created after 2 March 2026 and only supports granular scopes. The setup script uses the correct granular scopes automatically — if you see this error, check that your Client ID in `.env` matches the app at developer.xero.com |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Check the path in `~/.claude.json` — it must be the full absolute path, not a relative path |
| "Token expired" error | Run `npm run auth` again to refresh your token |
| "No Xero organisations found" | Run `npm run auth` again — the previous token may be invalid or for the wrong account |
| Wrong Xero organisation connected | Run `npm run auth` again and select the correct organisation when prompted |
| "Xero API error" on reports | Your Xero plan may not support this report type. Check your Xero subscription level |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Work / Company Xero Accounts

If your Xero account is managed by your employer or accountant, you may need them to grant you Adviser or Standard user access before the connector can read invoices and reports. The person who owns the Xero organisation can add you under Settings → Users.

---

## Server / Headless VM Setup

If you are running your assistant on a server or headless VM without a browser, the OAuth sign-in needs a small workaround.

### On your laptop (not the server)

1. Run `npm run auth` on your laptop to complete the browser sign-in
2. Copy the `.xero-token.json` file from your laptop to the server's `xero-connector` folder
3. Copy the `.env` file as well (same credentials)

### On the server

```bash
cd /path/to/xero-connector
npm install
node src/index.js
```

The server will use the token file you copied. Tokens refresh automatically. If they expire, repeat the process from your laptop.

---

## Security Notes

- Your Xero credentials are stored only in the `.env` file on your computer
- Your Xero access token is stored in `.xero-token.json` — this file is excluded from Git
- Never share your `.env` or `.xero-token.json` files with anyone
- The connector only requests read/write access to accounting data — it does not access payroll or files

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
