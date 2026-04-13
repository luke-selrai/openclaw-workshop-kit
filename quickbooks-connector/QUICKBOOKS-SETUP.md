---
title: QuickBooks Connector — Setup Guide
version: 2.0
date: 2026-04-13
---

# QuickBooks Connector — Setup Guide

This guide connects your QuickBooks Online account to Claude Code. Once set up, Claude can read and create invoices, look up customers, view your chart of accounts, check bank transactions, and pull financial reports — all through plain English.

The entire setup takes about 5 minutes. **You only do one manual thing yourself** (create a free Intuit developer app). Everything else — installing the connector pieces, saving credentials, running the browser sign-in, configuring Claude Code, verifying the connection — is handled by Claude Code conversationally.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../docs/FULL-SETUP-PAGE.md) if not done yet)
- Node.js version 20 or higher — Claude will check this for you during setup
- A QuickBooks Online account (sandbox for testing, or a live company for real data)
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
| **Invoices** | List, view, and create invoices for any customer |
| **Customers** | Search customers, add new ones, check balances |
| **Chart of Accounts** | Browse all account types (bank, income, expense, etc.) |
| **Bank Transactions** | List recent purchases and deposits with dates and amounts |
| **Payments** | List customer payments received, with linked invoices |
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

You can switch later by telling Claude: "I want to switch my QuickBooks to practice mode" or "connect my real QuickBooks account". Claude will re-run the sign-in for the new environment.

> **If you are following along in a workshop:** Choose **sandbox**. You will create a free test company in the next sub-step.

### Sandbox users — create a sandbox company first

If you chose **sandbox** (recommended for workshops), you must create a sandbox company **before Claude connects you**. Intuit does not create one automatically.

1. Go to [developer.intuit.com](https://developer.intuit.com)
2. Click **My Hub** → **Sandbox** in the left menu
3. Click **Add sandbox**
4. Select **QuickBooks Online Plus**
5. Select your country (e.g. Australia)
6. Click **Create** — wait about 30 seconds for it to provision
7. You only need to do this once

> **If you skip this step**, you will see this error during the sign-in step:
>
> ```
> There is no sandbox companies found for the user
> ```
>
> Create a sandbox company using the steps above, then ask Claude to try again.

---

## Step 1 — Create Your QuickBooks OAuth App (One-Time)

This is the only manual step. Intuit requires every connection to use a developer "app" — this is free and takes about 3 minutes. Claude cannot do this step for you because Intuit needs you to be signed in as yourself.

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
14. **Copy your Client ID and Client Secret** — you will paste them to Claude when asked
15. **Save both values somewhere safe** (a password manager or text file) in case you need them again

> **Common mistakes to avoid:**
>
> - The redirect URI must be added on the **Development** tab, not the Production tab. (If you chose "production" for your environment, add it on the Production tab instead — the tab must match your environment.)
> - The redirect URI must be **exactly** `http://localhost:3000/callback` — note it is `http`, **not** `https`. No trailing slash. No capital letters. Copy and paste it.
> - The Client Secret is **only shown once in full** when you first reveal it. Copy it before leaving the page. If you lose it, you can generate a new one (which revokes the old one).
> - Your Intuit developer account and your QuickBooks company can use different email addresses — that's fine. Claude will ask which company to connect during sign-in.

---

## Step 2 — Let Claude Do the Rest

Open Claude Code and say:

> **"Help me connect my QuickBooks account"**

Claude will guide you through every remaining step conversationally:

1. Check that Node.js is installed (and install it for you if not)
2. Install the connector pieces
3. Ask you to paste your Client ID and Client Secret from Step 1
4. Ask whether you want practice mode (sandbox) or your real account (production)
5. Save your credentials securely
6. Open QuickBooks in your browser for sign-in — you click **Connect**
7. Wire the connector into Claude Code automatically
8. Verify the connection by fetching your company name
9. Tell you it's done

You will not run any commands yourself. Claude handles all the technical work. You just answer its questions in plain English and click **Connect** when the browser opens.

When Claude tells you it's finished, close Claude Code completely and open it again. That makes the new connection active. Then try asking:

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
| **Payments received** | "Show me recent QuickBooks payments" |
| **Company info** | "What QuickBooks company am I connected to?" |
| **Reconnect** | "My QuickBooks connection has stopped working" |
| **Switch companies** | "I want to switch to a different QuickBooks company" |
| **Switch environments** | "I want to switch my QuickBooks to practice mode" (or "to my real account") |

---

## Keeping Your Connection Active

QuickBooks access tokens refresh automatically in the background. You should almost never need to think about this.

If you ever see an error like "token expired" or "your QuickBooks connection has dropped", just say to Claude:

> **"My QuickBooks connection has stopped working"**

Claude will re-run the browser sign-in for you in under 30 seconds. You click **Connect** once when the browser opens, and you're back.

The underlying refresh token stays valid for 100 days as long as the connection is used at least once in that window. If you haven't touched QuickBooks in over three months, you may need to reconnect.

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
| Path too long error on Windows | Your folder path exceeds Windows' 260-character limit. Move the `quickbooks-connector` folder to `C:\workshop\` and ask Claude to try again. |

### App & Authentication Problems

| Problem | Fix |
|---|---|
| "Missing credentials" during setup | Claude will ask you to re-paste your Client ID and Secret. Get them from [developer.intuit.com](https://developer.intuit.com) → My Hub → App Dashboard → your app → Keys and credentials. |
| "redirect_uri_mismatch" in browser | In your Intuit app settings, confirm the redirect URI is exactly `http://localhost:3000/callback` on the tab (Development or Production) that matches your chosen environment. No `https`. No trailing slash. Then tell Claude to try again. |
| "invalid_client" error in browser | Your Client ID or Secret is wrong, or you are using Development credentials against Production (or vice versa). Tell Claude "I need to re-enter my QuickBooks credentials" and it will take them from you again. |
| Client Secret not visible | At developer.intuit.com, open your app → Keys and credentials → click **Show credentials**. If it is hidden, click **Regenerate** — this creates a new one (the old one is revoked). Then paste the new secret when Claude asks. |
| "Port 3000 is already in use" | Something else is running on port 3000. Close it, then tell Claude to try again. |
| Browser does not open during sign-in | Claude will paste the sign-in URL into the chat as a clickable link. |
| No response from browser after 2 minutes | Close any other apps using port 3000, check your internet connection, and tell Claude to try again. |
| "There is no sandbox companies found for the user" | You need to create a sandbox company first. Go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds, then tell Claude to try again. |

### After Setup

| Problem | Fix |
|---|---|
| Claude says "tool not available" | Close Claude Code completely and reopen it. The connection becomes active on restart. |
| "Token expired" error | Say to Claude: **"my QuickBooks connection has stopped working"** — Claude will reconnect it for you. |
| "No realmId in .quickbooks-token.json" | Say to Claude: **"my QuickBooks connection is broken"** — Claude will re-do the sign-in for you. |
| Wrong QuickBooks company connected | Say to Claude: **"I want to switch to a different QuickBooks company"** — Claude will re-run the sign-in. |
| "QuickBooks API error" on reports | Your QuickBooks subscription may not include this report type. Check your QuickBooks Online plan. |
| "No Products/Services found" when creating an invoice | QuickBooks requires at least one Item before invoices can be created. Open QuickBooks Online → Sales → Products and Services → create a basic service item, then tell Claude to try again. |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

If you are connecting to a **client's** QuickBooks company, the **client must authorise the connection themselves** — Intuit's sign-in cannot be delegated. The practical flow when you run the setup with your client:

1. You tell Claude: "Help me connect my client's QuickBooks account"
2. Claude walks you both through Step 1 (creating the Intuit developer app — this can be in your account or the client's)
3. When Claude opens QuickBooks in the browser, **the client signs in** and selects their own company
4. The client clicks **Connect** to grant access
5. The token is stored on your machine (not theirs)

If you use QuickBooks Online Accountant, you can also have the client add you as an **Accountant user** on their company — but even then, the client still needs to approve the connection in their browser this first time.

If you manage multiple client companies, each one needs its own connection. Claude connects to one company at a time. To switch, say: "I want to switch to a different QuickBooks company" — Claude will re-run the sign-in so the client can select the other company.

---

## Security Notes

- Your QuickBooks credentials are stored only in a local `.env` file on your computer (Claude creates it; you never edit it)
- Your QuickBooks access token and realm ID are stored in a local `.quickbooks-token.json` file — this file is excluded from Git
- Neither file is ever sent to Anthropic, Selr AI, or any third party
- Never share these files with anyone
- The connector only requests the `com.intuit.quickbooks.accounting` scope — it does not access payroll or payments processing

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
