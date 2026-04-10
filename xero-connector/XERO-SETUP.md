---
title: Xero Connector — Setup Guide
version: 2.0
date: 2026-04-10
---

# Xero Connector — Setup Guide

This guide connects your Xero accounting account to Claude Code. Once set up, Claude can read and create invoices, look up contacts, view your chart of accounts, check bank transactions, list payments, and pull financial reports — all through plain English.

The entire setup takes about 5 minutes. There is only one manual step (creating a free Xero app) — the installer handles everything else.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../docs/FULL-SETUP-PAGE.md) if not done yet)
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
| **Invoices** | List, view, search, and create invoices |
| **Contacts** | Search customers and suppliers, add new contacts |
| **Chart of Accounts** | Browse your account codes and types |
| **Bank Transactions** | List bank transactions with dates and amounts |
| **Payments** | List payments recorded against invoices and bills |
| **Profit & Loss** | Pull income and expense reports for any date range |
| **Balance Sheet** | View assets, liabilities, and equity at a point in time |
| **Organisation** | Check which Xero organisation is connected |

---

## Step 1 — Create Your Xero OAuth App (One-Time)

This is the only manual step. Xero requires every connection to use a developer "app" — this is free and takes about 2 minutes.

1. Go to [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
2. Sign in with your Xero account
3. Click **New app**
4. Fill in the form:
   - **App name:** `Claude Assistant` (or any name you like)
   - **Integration type:** Web app
   - **Company or application URL:** `https://selrai.com.au` (or any valid URL — this is just for display)
   - **OAuth 2.0 redirect URI:** `http://localhost:3000/callback`
5. Click **Create app**
6. You are now on the app detail page. Click **Configuration** in the left menu
7. **Copy your Client ID** — it is shown at the top of the page
8. Click **Generate a secret** to reveal your Client Secret
9. **Copy your Client Secret** — it is shown below the button
10. **Save both values somewhere safe** — you will need them in Step 3

> **Common mistakes to avoid:**
>
> - The redirect URI must be **exactly** `http://localhost:3000/callback` — no `https`, no trailing slash, no capital letters. Copy and paste it.
> - The Client Secret is **only shown once**. Copy it before leaving the page. If you lose it, you can generate a new one (which revokes the old one).
> - The integration type must be **Web app**, not "Public app" or "Private app".

---

## Step 2 — Run the Installer via Claude Code

Open Claude Code, paste this prompt, and press Enter:

```
Run the Xero connector installer:
node /full/path/to/xero-connector/src/install.js
```

Replace `/full/path/to/xero-connector` with the actual path to the xero-connector folder on your computer.

### How to find the full path

**Windows:** Open the `xero-connector` folder in File Explorer. Click the address bar at the top — it shows the full path (e.g. `C:\Users\You\claude-workshop-kit\xero-connector`).

**Mac:** Open Terminal, drag the `xero-connector` folder into the window, and press Space — the full path appears (e.g. `/Users/You/claude-workshop-kit/xero-connector`).

The installer will:
- Check your Node.js version
- Install all required packages
- Prompt you for your Xero credentials (Step 3)
- Open your browser for sign-in (Step 4)
- Configure Claude Code automatically
- Verify the connection works

---

## Step 3 — Enter Credentials When Prompted

The installer will ask you to paste two values:

```
Paste your Xero Client ID: ████████████████████████████████
Paste your Xero Client Secret: ████████████████████████████████████████████████
```

Paste the values you saved from Step 1. Your input is visible so you can check for typos.

> If you already ran the installer before and your credentials are saved, it will ask if you want to reuse them — type `y` and press Enter.

---

## Step 4 — Approve in Browser

After you enter your credentials, a browser window will open showing the Xero sign-in page:

1. Sign in with your Xero account if prompted
2. Select the Xero organisation you want to connect
3. Click **Allow access**
4. You should see a green success page — return to your terminal

Your terminal should display:

```
[4/7] Connecting to Xero...
  Signed in to Xero -- OK
```

> **If the browser does not open:** The sign-in URL is printed in your terminal. Copy and paste it into any browser.

---

## Step 5 — Restart Claude Code

The installer configures Claude Code automatically by adding the Xero MCP server to your `~/.claude.json` file.

For the new configuration to take effect, **restart Claude Code**:
- Close Claude Code completely
- Open it again

> You only need to restart once after the initial setup.

---

## Step 6 — Test It

After restarting, try asking Claude:

- "Show me my recent Xero invoices"
- "What organisation am I connected to in Xero?"
- "List my Xero contacts"

If Claude responds with your Xero data, you are all set.

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
| **Bank transactions** | "Show me my recent bank transactions in Xero" |
| **Payments** | "Show me recent payments in Xero" |

---

## Keeping Your Connection Active

Xero tokens refresh automatically. If you see a "token expired" error in Claude, run this in your terminal inside the `xero-connector` folder:

```
npm run auth
```

This reconnects your account in under 30 seconds.

---

## Troubleshooting

### Installation Problems

| Problem | Fix |
|---|---|
| `node --version` shows v18 or lower | Update Node.js at [nodejs.org](https://nodejs.org) — download the LTS version (v22 or v20) |
| **EPERM / permission denied** on Windows | Close the window, right-click your terminal → "Run as administrator", and try again |
| **EACCES** on Mac | Avoid using `sudo npm`. Instead install via nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` then `nvm install --lts` and retry |
| **EINTEGRITY** error during install | npm cache is corrupted. Run `npm cache clean --force` then try again |
| **ECONNRESET / 403** during install | Corporate firewall blocking npmjs.com. Ask IT to allow `registry.npmjs.org:443` |
| install fails on Mac — "command not found: node" | nvm installed but not loaded. Run `source ~/.nvm/nvm.sh` then retry |
| Script blocked on Mac ("developer cannot be verified") | Right-click the file → Open, or run: `xattr -d com.apple.quarantine src/install.js` |
| Script blocked on Windows ("running scripts is disabled") | Run in PowerShell: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then retry |
| Windows Defender blocks npm install (EBUSY) | Temporarily pause Real-Time Protection in Windows Security, run the installer, then re-enable |
| Path too long error on Windows | Your folder path may exceed Windows' 260-character limit. Move the `xero-connector` folder to `C:\workshop\` and try again |

### App & Authentication Problems

| Problem | Fix |
|---|---|
| "Missing credentials" during install | Enter your real Client ID and Secret — get them from [developer.xero.com/app/manage](https://developer.xero.com/app/manage) |
| "redirect_uri_mismatch" in browser | In your Xero app settings at developer.xero.com, confirm the redirect URI is exactly `http://localhost:3000/callback` — no https, no trailing slash |
| Client Secret not showing in Xero | Go to your app at developer.xero.com and click **Generate a secret** again — this creates a new one (the old one is revoked) |
| "Invalid scope for client" on auth | Your Xero app was created after 2 March 2026 and only supports granular scopes. The installer uses the correct granular scopes automatically — if you see this error, check that your Client ID in `.env` matches the app at developer.xero.com |
| "invalid_client" error in browser | Your Client ID or Secret is wrong. Double-check both values match exactly what Xero shows |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it and try again, or stop the other process first |
| Browser does not open during sign-in | The sign-in URL is printed in your terminal — copy and paste it into any browser |
| No response from browser after 2 minutes | Close any other apps using port 3000, check your internet connection, and run the installer again |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Restart Claude Code. If still broken, check the path in `~/.claude.json` — it must be the full absolute path, not a relative path |
| "Token expired" error | Run `npm run auth` in the xero-connector folder to refresh your token |
| "No Xero organisations found" | Run `npm run auth` again — the previous token may be invalid or for the wrong account |
| Wrong Xero organisation connected | Run `npm run auth` again and select the correct organisation when prompted |
| "Xero API error" on reports | Your Xero plan may not support this report type. Check your Xero subscription level |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

If you are connecting to a client's Xero organisation, you need **Adviser** or **Standard** user access to that organisation. The organisation owner can add you under Settings → Users in Xero.

If you manage multiple organisations, the installer connects to the first one you select during sign-in. To switch organisations, run `npm run auth` again and select a different one.

---

## Security Notes

- Your Xero credentials are stored only in the `.env` file on your computer
- Your Xero access token is stored in `.xero-token.json` — this file is excluded from Git
- Never share your `.env` or `.xero-token.json` files with anyone
- The connector only requests read/write access to accounting data — it does not access payroll or files

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

## Appendix — Manual Token Refresh

If `npm run auth` is not available or you need to refresh the token programmatically, you can do it manually:

```bash
cd /path/to/xero-connector
node src/auth.js
```

This runs the same OAuth flow as the installer — it opens your browser, waits for you to sign in and click Allow, then saves the new token to `.xero-token.json`.

The token includes a refresh token that the MCP server uses to automatically renew access. Under normal use, you should never need to manually refresh. The main reasons you would run `npm run auth` again are:

- The refresh token itself has expired (after 60 days of inactivity)
- You want to switch to a different Xero organisation
- You regenerated your Client Secret at developer.xero.com

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
