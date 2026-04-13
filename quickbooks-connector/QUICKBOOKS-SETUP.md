---
title: QuickBooks Connector — Setup Guide
version: 1.0
date: 2026-04-13
---

# QuickBooks Connector — Setup Guide

This guide connects your QuickBooks Online account to Claude Code. Once set up, Claude can read and create invoices, look up customers, view your chart of accounts, check bank transactions, and pull financial reports — all through plain English.

The entire setup takes about 5 minutes. There is only one manual step (creating a free Intuit developer app) — the installer handles everything else.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../docs/FULL-SETUP-PAGE.md) if not done yet)
- Node.js **version 20 or higher** installed — check by typing `node --version` in the command window
- A QuickBooks Online account (sandbox for testing, or a live company for real data)
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
| **Invoices** | List, view, and create invoices for any customer |
| **Customers** | Search customers, add new ones, check balances |
| **Chart of Accounts** | Browse all account types (bank, income, expense, etc.) |
| **Bank Transactions** | List recent purchases and deposits with dates and amounts |
| **Profit & Loss** | Pull income and expense reports for any date range |
| **Balance Sheet** | View assets, liabilities, and equity at a point in time |
| **Company** | Check which QuickBooks company is connected |

---

## Sandbox vs Production

QuickBooks gives you two environments. **Pick one before you start.**

| Environment | What it is | When to use |
|---|---|---|
| **Sandbox** | A free test company Intuit creates for you — fake customers, fake invoices, zero risk | Workshops, learning, trying out new prompts, any testing |
| **Production** | Your real QuickBooks Online account — real customers, real financial data | Day-to-day use once you trust the setup |

You can switch later by editing `QUICKBOOKS_ENVIRONMENT` in the `.env` file (inside the `quickbooks-connector` folder) and re-running `npm run auth`.

> **If you are following along in a workshop:** Choose **sandbox**. You will create a free test company in the next sub-step.

### Sandbox users — create a sandbox company first

If you chose **sandbox** (recommended for workshops), you must create a sandbox company **before running the installer**. Intuit does not create one automatically.

1. Go to [developer.intuit.com](https://developer.intuit.com)
2. Click **My Hub** → **Sandbox** in the left menu
3. Click **Add sandbox**
4. Select **QuickBooks Online Plus**
5. Select your country (e.g. Australia)
6. Click **Create** — wait about 30 seconds for it to provision
7. You only need to do this once

> **If you skip this step**, the browser will show this error when the installer reaches the OAuth step:
>
> ```
> There is no sandbox companies found for the user
> ```
>
> Create a sandbox company using the steps above and re-run the installer.

---

## Step 1 — Create Your QuickBooks OAuth App (One-Time)

This is the only manual step. Intuit requires every connection to use a developer "app" — this is free and takes about 3 minutes.

1. Go to [developer.intuit.com](https://developer.intuit.com)
2. Sign in (or sign up — it's free and only needs an email address)
3. Click **My Hub** → **App Dashboard** → **Create an app**
4. Select **QuickBooks Online and Payments**
5. Fill in the form:
   - **App name:** `Claude Assistant` (or any name you like)
   - **Scopes:** check `com.intuit.quickbooks.accounting`
6. Click **Create app**
7. You are now on the app detail page. In the left menu, click **Settings** → **Redirect URIs**
8. Make sure you are on the **Development** tab (not Production)
9. Click **Add URI** and paste: `http://localhost:3000/callback`
10. Click **Save**
11. In the left menu, click **Keys and credentials**
12. Make sure you are on the **Development** tab
13. Click **Show credentials**
14. **Copy your Client ID and Client Secret** — you will need them in Step 3
15. **Save both values somewhere safe** (a password manager or text file)

> **Common mistakes to avoid:**
>
> - The redirect URI must be added on the **Development** tab, not the Production tab. (If you chose "production" for your environment, add it on the Production tab instead — the tab must match your environment.)
> - The redirect URI must be **exactly** `http://localhost:3000/callback` — note it is `http`, **not** `https`. No trailing slash. No capital letters. Copy and paste it.
> - The Client Secret is **only shown once in full** when you first reveal it. Copy it before leaving the page. If you lose it, you can generate a new one (which revokes the old one).
> - Your Intuit developer account and your QuickBooks company can use different email addresses — that's fine. The OAuth flow asks which company to connect in Step 4.

---

## Step 2 — Run the Installer via Claude Code

Open Claude Code, paste this prompt, and press Enter:

```
Run the QuickBooks connector installer:
node /full/path/to/quickbooks-connector/src/install.js
```

Replace `/full/path/to/quickbooks-connector` with the actual path to the quickbooks-connector folder on your computer.

### How to find the full path

**Windows:** Open the `quickbooks-connector` folder in File Explorer. Click the address bar at the top — it shows the full path (e.g. `C:\Users\You\claude-workshop-kit\quickbooks-connector`).

**Mac:** Open Terminal, drag the `quickbooks-connector` folder into the window, and press Space — the full path appears (e.g. `/Users/You/claude-workshop-kit/quickbooks-connector`).

The installer will:
- Check your Node.js version
- Install all required packages
- Prompt you for your QuickBooks credentials and environment (Step 3)
- Open your browser for sign-in (Step 4)
- Configure Claude Code automatically
- Verify the connection works

---

## Step 3 — Enter Credentials and Choose Environment

The installer will ask you to paste two values and pick an environment:

```
Paste your QuickBooks Client ID: ████████████████████████████████
Paste your QuickBooks Client Secret: ████████████████████████████████████████████████
Are you using sandbox or production? (sandbox/production) [sandbox]:
```

Paste the values you saved from Step 1. Your input is visible so you can check for typos.

For the environment prompt, press Enter to accept the default (`sandbox`), or type `production` if you want to connect your real QuickBooks company.

> If you already ran the installer before and your credentials are saved, it will ask if you want to reuse them — type `y` and press Enter.

---

## Step 4 — Approve in Browser

After you enter your credentials, a browser window will open showing the Intuit sign-in page:

1. Sign in with your Intuit account if prompted
2. Select the QuickBooks company you want to connect
3. Click **Connect**
4. You should see a green success page — return to your terminal

Your terminal should display:

```
[4/7] Connecting to QuickBooks...
  Connected to: [Your Company]
  Realm ID: 123456789
```

> **If the browser does not open:** The sign-in URL is printed in your terminal. Copy and paste it into any browser.

---

## Step 5 — Restart Claude Code

The installer configures Claude Code automatically by adding the QuickBooks MCP server to your `~/.claude.json` file.

For the new configuration to take effect, **restart Claude Code**:
- Close Claude Code completely
- Open it again

> You only need to restart once after the initial setup.

---

## Step 6 — Test It

After restarting, try asking Claude:

- "Show me my recent QuickBooks invoices"
- "What company am I connected to in QuickBooks?"
- "List my QuickBooks customers"

If Claude responds with your QuickBooks data, you are all set.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Check invoices** | "Show me my unpaid QuickBooks invoices" |
| **Create an invoice** | "Create a QuickBooks invoice for Acme Corp for $500" |
| **Find a customer** | "Find John Smith in my QuickBooks customers" |
| **Add a customer** | "Add a new customer called ABC Pty Ltd" |
| **Profit & Loss** | "Show me the QuickBooks profit and loss for this year" |
| **Balance Sheet** | "Get the QuickBooks balance sheet as of today" |
| **Chart of accounts** | "List my QuickBooks expense accounts" |
| **Bank transactions** | "Show me my recent QuickBooks bank transactions" |
| **Company info** | "What QuickBooks company am I connected to?" |

---

## Keeping Your Connection Active

QuickBooks access tokens expire every hour but refresh automatically in the background. Refresh tokens last 100 days as long as the connection is used at least once in that time.

If you see a "token expired" error in Claude, run this in your terminal inside the `quickbooks-connector` folder:

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
| Path too long error on Windows | Your folder path may exceed Windows' 260-character limit. Move the `quickbooks-connector` folder to `C:\workshop\` and try again |

### App & Authentication Problems

| Problem | Fix |
|---|---|
| "Missing credentials" during install | Enter your real Client ID and Secret — get them from [developer.intuit.com](https://developer.intuit.com) (My Hub → App Dashboard → your app → Keys and credentials) |
| "redirect_uri_mismatch" in browser | In your Intuit app settings, confirm the redirect URI is exactly `http://localhost:3000/callback` on the same tab (Development or Production) that matches your chosen environment. No `https`. No trailing slash |
| "invalid_client" error in browser | Your Client ID or Secret is wrong, or you are using Development credentials against Production (or vice versa). Confirm both values and that your environment setting matches the tab you copied them from |
| Client Secret not visible | At developer.intuit.com, open your app → Keys and credentials → click **Show credentials**. If it is hidden, click **Regenerate** — this creates a new one (the old one is revoked) |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it and try again, or stop the other process first |
| Browser does not open during sign-in | The sign-in URL is printed in your terminal — copy and paste it into any browser |
| No response from browser after 2 minutes | Close any other apps using port 3000, check your internet connection, and run the installer again |
| "There is no sandbox companies found for the user" | You need to create a sandbox company first. Go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds then re-run the installer |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Restart Claude Code. If still broken, check the path in `~/.claude.json` — it must be the full absolute path, not a relative path |
| "Token expired" error | Run `npm run auth` in the quickbooks-connector folder to refresh your token |
| "No realmId in .quickbooks-token.json" | Run `npm run auth` again — the token file is incomplete |
| Wrong QuickBooks company connected | Run `npm run auth` again and pick the correct company when prompted |
| "QuickBooks API error" on reports | Your QuickBooks subscription may not include this report type. Check your QuickBooks Online plan |
| "No Products/Services found" when creating an invoice | QuickBooks requires at least one Item before invoices can be created. Open QuickBooks Online → Sales → Products and Services → create a basic service item, then try again |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

If you are connecting to a **client's** QuickBooks company, the **client must authorise the connection themselves** — OAuth consent cannot be delegated. The practical flow is:

1. The client signs in to their QuickBooks account during Step 4
2. They select their own company and click **Connect**
3. The token is stored on your machine (not theirs)

If you use QuickBooks Online Accountant, you can also have the client add you as an **Accountant user** on their company — but even then, the connector still needs the client to run the initial OAuth once to grant access for this specific app.

If you manage multiple client companies, each one needs its own connection. The current installer connects to one company at a time. To switch, re-run `npm run auth` and select a different company during sign-in.

---

## Security Notes

- Your QuickBooks credentials are stored only in the `.env` file on your computer
- Your QuickBooks access token and realm ID are stored in `.quickbooks-token.json` — this file is excluded from Git
- Never share your `.env` or `.quickbooks-token.json` files with anyone
- The connector only requests the `com.intuit.quickbooks.accounting` scope — it does not access payroll or payments processing

---

## Server / Headless VM Setup

If you are running your assistant on a server or headless VM without a browser, the OAuth sign-in needs a small workaround.

### On your laptop (not the server)

1. Run `npm run auth` on your laptop to complete the browser sign-in
2. Copy the `.quickbooks-token.json` file from your laptop to the server's `quickbooks-connector` folder
3. Copy the `.env` file as well (same credentials, same environment)

### On the server

```bash
cd /path/to/quickbooks-connector
npm install
node src/index.js
```

The server will use the token file you copied. Tokens refresh automatically. If they expire, repeat the process from your laptop.

---

## Appendix — Manual Token Refresh

If `npm run auth` is not available or you need to refresh the token programmatically, you can do it manually:

```bash
cd /path/to/quickbooks-connector
node src/auth.js
```

This runs the same OAuth flow as the installer — it opens your browser, waits for you to sign in and click Connect, then saves the new token to `.quickbooks-token.json`.

The token file includes a refresh token that the MCP server uses to automatically renew access every hour. Under normal use, you should never need to manually refresh. The main reasons you would run `npm run auth` again are:

- The refresh token itself has expired (after 100 days of no activity)
- You want to switch to a different QuickBooks company
- You switched environments (sandbox ↔ production)
- You regenerated your Client Secret at developer.intuit.com

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
