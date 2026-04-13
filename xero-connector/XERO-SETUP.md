---
title: Xero Connector — Setup Guide
version: 3.0
date: 2026-04-13
---

# Xero Connector — Setup Guide

This guide connects your Xero accounting account to Claude Code. Once set up, Claude can read and create invoices, look up contacts, view your chart of accounts, check bank transactions, list payments, and pull financial reports — all through plain English.

The entire setup takes about 5 minutes. **You only do one manual thing yourself** (create a free Xero developer app). Everything else — installing the connector pieces, saving credentials, running the browser sign-in, configuring Claude Code, verifying the connection — is handled by Claude Code conversationally.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../docs/FULL-SETUP-PAGE.md) if not done yet)
- Node.js version 20 or higher — Claude will check this for you during setup
- A Xero account (any plan — Starter, Standard, or Premium)
- An internet connection

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

This is the only manual step. Xero requires every connection to use a developer "app" — this is free and takes about 2 minutes. Claude cannot do this step for you because Xero needs you to be signed in as yourself.

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
10. **Save both values somewhere safe** — you will paste them to Claude when asked

> **Common mistakes to avoid:**
>
> - The redirect URI must be **exactly** `http://localhost:3000/callback` — no `https`, no trailing slash, no capital letters. Copy and paste it.
> - The Client Secret is **only shown once**. Copy it before leaving the page. If you lose it, you can generate a new one (which revokes the old one).
> - The integration type must be **Web app**, not "Public app" or "Private app".

---

## Step 2 — Let Claude Do the Rest

Open Claude Code and say:

> **"Help me connect my Xero account"**

Claude will guide you through every remaining step conversationally:

1. Check that Node.js is installed (and install it for you if not)
2. Install the connector pieces
3. Ask you to paste your Client ID and Client Secret from Step 1
4. Save your credentials securely
5. Open Xero in your browser for sign-in — you click **Allow access**
6. Wire the connector into Claude Code automatically
7. Verify the connection by fetching your organisation name
8. Tell you it's done

You will not run any commands yourself. Claude handles all the technical work. You just answer its questions in plain English and click **Allow access** when the browser opens.

When Claude tells you it's finished, close Claude Code completely and open it again. That makes the new connection active. Then try asking:

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
| **Reconnect** | "My Xero connection has stopped working" |
| **Switch organisations** | "I want to switch to a different Xero organisation" |

---

## Keeping Your Connection Active

Xero access tokens refresh automatically in the background. You should almost never need to think about this.

If you ever see an error like "token expired" or "your Xero connection has dropped", just say to Claude:

> **"My Xero connection has stopped working"**

Claude will re-run the browser sign-in for you in under 30 seconds. You click **Allow access** once when the browser opens, and you're back.

The underlying refresh token stays valid for 60 days as long as the connection is used at least once in that window. If you haven't touched Xero in over two months, you may need to reconnect.

---

## Troubleshooting

### Installation Problems

These are issues Claude may report back to you during setup. In most cases Claude will translate the error into plain English and handle it automatically — this table exists so you can recognise what's happening if you're curious.

| Problem | Fix |
|---|---|
| `node --version` shows v18 or lower | Claude will install Node.js v20 for you automatically during setup. If it can't, Claude will tell you what to do. |
| **EPERM / permission denied** on Windows | Claude will ask you to close and reopen your terminal as administrator, then resume. |
| **EACCES** on Mac | Claude will install Node via nvm (which avoids sudo) and retry. You just watch. |
| **EINTEGRITY** error during install | Claude will clean the package cache and retry automatically. |
| **ECONNRESET / 403** during install | Your network (usually a corporate firewall) is blocking npmjs.com. Claude will tell you — you will need to try from a home connection or ask IT to allow `registry.npmjs.org:443`. |
| install fails on Mac — "command not found: node" | Claude will reload the shell profile and retry. |
| Script blocked on Mac ("developer cannot be verified") | Tell Claude "there's a Mac security warning" and it will run the unlock command for you. |
| Script blocked on Windows ("running scripts is disabled") | Tell Claude "scripts are blocked on my Windows" and it will talk you through enabling them. |
| Windows Defender blocks npm install (EBUSY) | Temporarily pause Real-Time Protection in Windows Security, then ask Claude to retry. |
| Path too long error on Windows | Your folder path exceeds Windows' 260-character limit. Move the `xero-connector` folder to `C:\workshop\` and ask Claude to try again. |

### App & Authentication Problems

| Problem | Fix |
|---|---|
| "Missing credentials" during setup | Claude will ask you to re-paste your Client ID and Secret. Get them from [developer.xero.com/app/manage](https://developer.xero.com/app/manage). |
| "redirect_uri_mismatch" in browser | In your Xero app settings at developer.xero.com, confirm the redirect URI is exactly `http://localhost:3000/callback` — no `https`, no trailing slash. Then tell Claude to try again. |
| Client Secret not showing in Xero | Go to your app at developer.xero.com and click **Generate a secret** again — this creates a new one (the old one is revoked). Then paste the new secret when Claude asks. |
| "Invalid scope for client" on auth | Your Xero app was created after 2 March 2026 and only supports granular scopes. The connector uses the correct granular scopes automatically — if you see this, check that your Client ID matches the app at developer.xero.com, then tell Claude to try again. |
| "invalid_client" error in browser | Your Client ID or Secret is wrong. Tell Claude "I need to re-enter my Xero credentials" and it will take them from you again. |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it, then tell Claude to try again. |
| Browser does not open during sign-in | Claude will paste the sign-in URL into the chat as a clickable link. |
| No response from browser after 2 minutes | Close any other apps using port 3000, check your internet connection, and tell Claude to try again. |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Close Claude Code completely and reopen it. The connection becomes active on restart. |
| "Token expired" error | Say to Claude: **"my Xero connection has stopped working"** — Claude will reconnect it for you. |
| "No Xero organisations found" | Say to Claude: **"my Xero connection is broken"** — Claude will re-do the sign-in for you. Remember to select an organisation during sign-in. |
| Wrong Xero organisation connected | Say to Claude: **"I want to switch to a different Xero organisation"** — Claude will re-run the sign-in so you can pick a different one. |
| "Xero API error" on reports | Your Xero plan may not support this report type. Check your Xero subscription level. |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

If you are connecting to a client's Xero organisation, you need **Adviser** or **Standard** user access to that organisation. The organisation owner can add you under Settings → Users in Xero.

If you manage multiple organisations, Claude connects to one at a time — whichever you select during the browser sign-in. To switch to a different organisation, say to Claude: **"I want to switch to a different Xero organisation"** and Claude will re-run the sign-in so you can pick a different one.

---

## Security Notes

- Your Xero credentials are stored only in a local `.env` file on your computer (Claude creates it; you never edit it)
- Your Xero access token is stored in a local `.xero-token.json` file — this file is excluded from Git
- Neither file is ever sent to Anthropic, Selr AI, or any third party
- Never share these files with anyone
- The connector only requests read/write access to accounting data — it does not access payroll or files

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
