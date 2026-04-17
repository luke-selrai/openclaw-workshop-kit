---
title: QuickBooks Connector — Setup Guide
version: 1.0
date: 2026-04-14
---

# QuickBooks Connector — Setup Guide

This guide connects your **QuickBooks Online practice company** to Claude Code, using the open-source [`qbo`](https://github.com/voska/qbo-cli) command-line tool. Once set up, Claude can read and create invoices, look up customers, view your chart of accounts, check bank transactions, list payments, and pull financial reports — all through plain English.

The entire setup takes about 5 minutes. **You only do one manual thing yourself** (create a free Intuit developer app). Everything else — installing the `qbo` tool, saving your credentials, running the browser sign-in, verifying the connection — is handled by Claude Code conversationally.

> **Sandbox only.** This connector supports QuickBooks Online **practice mode** (sandbox) only. Connecting to a real QuickBooks company (production) is out of scope for the workshop — it requires Intuit's app assessment process, a public domain with a non-localhost redirect URI, and review time that doesn't fit a workshop session. See the [Production note](#production-note-out-of-scope) at the bottom for context.

---

## What You Need Before Starting

- Claude Code installed and working (follow [the setup walkthrough](../start/full-setup.md) if not done yet)
- An Intuit developer account (free — you will create one in Step 1 if you don't already have one)
- An internet connection

**You do NOT need Node.js.** Earlier versions of this connector required Node.js, but the new version uses the `qbo` tool, which is a single standalone binary written in Go. Claude will install it for you during setup.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |
| Linux (Ubuntu, Debian, Fedora, Arch) | Yes |

---

## What This Unlocks

| Tool | What Your Assistant Can Do |
|---|---|
| **Invoices** | List, view, and create invoices; filter by status (unpaid, overdue) |
| **Customers** | Search customers, add new ones, check balances |
| **Chart of Accounts** | Browse all account types (Bank, Income, Expense, etc.) |
| **Bank Transactions** | List recent purchases and deposits with dates and amounts |
| **Payments** | List customer payments received, with linked invoices |
| **Profit & Loss** | Pull income and expense reports for any date range |
| **Balance Sheet** | View assets, liabilities, and equity at a point in time |
| **Company** | Check which QuickBooks practice company is connected |
| **Advanced entities** | Bills, vendors, estimates, journal entries, credit memos, and more — available via the official `voska/qbo-cli` skill, which Claude installs automatically |

---

## Step 1 — Create Your Intuit Developer App (One-Time)

This is the only manual step. Intuit requires every connection to use a developer "app" — this is free and takes about 3 minutes. Claude cannot do this step for you because Intuit needs you to be signed in as yourself.

### Create a free sandbox company first (if you don't have one)

QuickBooks gives every developer account a free practice company. If this is your first time, create one before creating the app:

1. Go to [developer.intuit.com](https://developer.intuit.com)
2. Sign in (or sign up — it's free and only needs an email address)
3. Click **My Hub** → **Sandbox** in the left menu
4. Click **Add sandbox**
5. Select **QuickBooks Online Plus**
6. Select your country (e.g. Australia)
7. Click **Create** — wait about 30 seconds for it to provision

### Create the OAuth app

1. Back at [developer.intuit.com](https://developer.intuit.com), click **My Hub** → **App Dashboard** → **Create an app**
2. Select **QuickBooks Online and Payments**
3. Fill in the form:
   - **App name:** `Claude Assistant` (or any name you like)
   - **Scopes:** check `com.intuit.quickbooks.accounting`
4. Click **Create app**
5. You are now on the app detail page. In the left menu, click **Settings** → **Redirect URIs**
6. Make sure you are on the **Development** tab (not Production)
7. Click **Add URI** and paste exactly: `http://localhost:8844/callback`
8. Click **Save**
9. In the left menu, click **Keys and credentials**
10. Make sure you are on the **Development** tab
11. Click **Show credentials**
12. **Copy your Client ID and Client Secret** — you will paste them to Claude when asked

> **Common mistakes to avoid:**
>
> - **Port 8844, not 3000.** The redirect URI must be exactly `http://localhost:8844/callback`. Earlier versions of this connector used port 3000 — the new `qbo` tool uses port 8844. If you have both tools, register both URIs on the same Intuit app.
> - The redirect URI must be added on the **Development** tab. If you are on the Production tab, you're in the wrong place.
> - The URI must be **exactly** `http://localhost:8844/callback` — note it is `http`, **not** `https`. No trailing slash. No capital letters. Copy and paste it.
> - The Client Secret is **only shown once in full** when you first reveal it. Copy it before leaving the page. If you lose it, click **Regenerate** — this creates a new one and revokes the old.

---

## Step 2 — Let Claude Do the Rest

Open Claude Code and say:

> **"Help me connect my QuickBooks account"**

Claude will guide you through every remaining step conversationally:

1. Check if the `qbo` tool is already on your computer (and install it for you if not — works on Mac via Homebrew, Windows via Scoop or a direct binary download, Linux via Homebrew or a direct binary)
2. Install an extra QuickBooks knowledge pack so Claude understands the full command reference
3. Ask you to paste your Client ID and Client Secret from Step 1
4. Save your credentials securely in a small file only you can read
5. Open QuickBooks in your browser for sign-in — you click **Connect**
6. Verify the connection by fetching your practice company name
7. Tell you it's done

You will not run any commands yourself. Claude handles all the technical work. You just answer its questions in plain English and click **Connect** when the browser opens.

When Claude tells you it's finished, try asking:

- "Show me my recent QuickBooks invoices"
- "What practice company am I connected to?"
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
| **Advanced entities** | "Show me my QuickBooks vendors" / "List my outstanding bills" / "Show my estimates" — Claude uses the extended knowledge pack |
| **Reconnect** | "My QuickBooks connection has stopped working" |
| **Switch companies** | "I want to switch to a different QuickBooks practice company" |

---

## Keeping Your Connection Active

`qbo` stores your QuickBooks access tokens in your operating system's secure credential store — macOS Keychain, Windows Credential Manager, or (on Linux) an encrypted file in your home directory. Tokens refresh automatically in the background. You should almost never need to think about this.

If you ever see an error like "token expired" or "your QuickBooks connection has dropped", just say to Claude:

> **"My QuickBooks connection has stopped working"**

Claude will re-run the browser sign-in for you in about 30 seconds. You click **Connect** once when the browser opens, and you're back.

---

## Troubleshooting

### Installation Problems

These are issues Claude may report back to you during setup. In most cases Claude will translate the error into plain English and handle it automatically — this table exists so you can recognise what's happening if you're curious.

| Problem | Fix |
|---|---|
| **No Homebrew installed (Mac)** | Claude will offer to install Homebrew for you, then retry. You just watch. |
| **No Scoop installed (Windows)** | Claude will skip Scoop and download the `qbo` binary directly from GitHub Releases instead — no action needed. |
| **No Go installed (Linux fallback)** | Claude will skip Go and download the `qbo` binary directly instead. |
| **Binary download blocked by firewall** | Your network (usually a corporate firewall) is blocking GitHub. Claude will tell you — you will need to try from a home connection or ask IT to allow `github.com` and `objects.githubusercontent.com`. |
| **`npx skills add` fails** | This installs an extra knowledge pack that is best-effort — setup continues even if this step fails. You lose access to advanced entity coverage but the 10 common workshop tasks still work. |
| **PATH issues after install on Mac** | Claude will place the binary somewhere on your PATH and update your shell profile if needed. If a new terminal still can't find `qbo`, ask Claude "my QuickBooks tool isn't being found" and it will diagnose. |
| **Windows can't find `qbo` after install** | Same — ask Claude "my QuickBooks tool isn't being found" and it will place the binary in a location Git Bash always sees. |

### App & Authentication Problems

| Problem | Fix |
|---|---|
| **"Missing credentials" during setup** | Claude will ask you to re-paste your Client ID and Secret. Get them from [developer.intuit.com](https://developer.intuit.com) → My Hub → App Dashboard → your app → Keys and credentials. |
| **"redirect_uri_mismatch" in browser** | In your Intuit app settings, confirm the redirect URI is exactly `http://localhost:8844/callback` on the **Development** tab. Note it is port **8844**, not 3000. No `https`. No trailing slash. Then tell Claude to try again. |
| **"invalid_client" error in browser** | Your Client ID or Secret is wrong, OR you copied them from the Production tab instead of the Development tab. Tell Claude "I need to re-enter my QuickBooks credentials" and it will take them from you again. |
| **Client Secret not visible** | At developer.intuit.com, open your app → Keys and credentials → click **Show credentials**. If it is hidden, click **Regenerate** — this creates a new one (the old one is revoked). Then paste the new secret when Claude asks. |
| **"Port 8844 is already in use"** | Something else is running on port 8844. Close any other `qbo` or QuickBooks sign-in processes, then tell Claude to try again. |
| **Browser does not open during sign-in** | Claude will re-run the sign-in in "manual" mode — it will paste the sign-in URL into the chat as a clickable link, you sign in, and then paste the resulting URL back to Claude. |
| **"There is no sandbox companies found for the user"** | You haven't created a sandbox company yet. Go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds, then tell Claude to try again. |

### After Setup

| Problem | Fix |
|---|---|
| **"Token expired" error** | Say to Claude: **"my QuickBooks connection has stopped working"** — Claude will reconnect it for you. |
| **"No company ID"** | Say to Claude: **"my QuickBooks connection is incomplete"** — Claude will re-run the company selection. |
| **Wrong practice company connected** | Say to Claude: **"I want to switch to a different QuickBooks practice company"** — Claude will re-run the sign-in so you can pick a different one. |
| **"QuickBooks API error" on reports** | Usually transient. Claude will retry automatically. If it keeps failing, the specific report may not be supported in sandbox — check developer.intuit.com for known limitations. |
| **"No Products/Services found" when creating an invoice** | QuickBooks requires at least one Item before invoices can be created. Open QuickBooks Online, go to Sales → Products and Services, create a basic service item, then tell Claude to try again. |
| **Something else** | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

If you are connecting to a **client's** QuickBooks company, note that this skill is **sandbox only** — you cannot use it to touch a real client's books in this configuration. Intuit blocks production access for apps with localhost redirect URIs, and completing Intuit's production assessment requires a public-facing domain, terms of service, privacy policy, and review time.

For working with real client data through the workshop-kit ecosystem, use the **Xero connector** instead (`docs/connectors/XERO-SETUP.md`) — Xero allows localhost redirects in production and works out of the box with real company data.

If you need QuickBooks production access for an accounting practice, contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) — there is a path to a production-ready deployment, but it sits outside the standard workshop and requires additional setup time.

---

## Production note (out of scope)

**This connector is sandbox only, by design.** The reasons:

- **Intuit's OAuth production rules** do not allow `http://localhost:*/callback` redirect URIs. Production QuickBooks apps must use a public-facing HTTPS domain as their callback.
- **Intuit's app assessment** — before Intuit will let an app talk to real production companies, they review it (security, privacy, UX). This takes several days and requires documentation the workshop cannot produce on the fly.
- **The workshop goal is to show you what's possible**, not to put real financial data into an experimental configuration. Sandbox gives you a full-featured QuickBooks Online Plus practice company with fake customers, fake invoices, and zero risk.

If you want to connect to real QuickBooks production data after the workshop:

1. Complete Intuit's production assessment (see [developer.intuit.com](https://developer.intuit.com) → your app → Production tab)
2. Register a public-facing HTTPS callback URI (not localhost)
3. Re-run `qbo auth login --redirect-uri https://yourdomain.com/callback` with your production URI
4. Or contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) for a guided production setup

---

## Security Notes

- Your Intuit Client ID and Client Secret are stored in `~/.config/qbo/credentials.env` on your computer, with restricted file permissions (readable only by you)
- Your QuickBooks access tokens are stored in your operating system's secure credential store (macOS Keychain / Windows Credential Manager / encrypted Linux file)
- Neither your credentials nor your tokens are ever sent to Anthropic, Selr AI, or any third party
- Never share these files with anyone
- The connector only requests the `com.intuit.quickbooks.accounting` scope — it does not access payroll, payments processing, or any other QuickBooks product surface

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au) · Powered by [voska/qbo-cli](https://github.com/voska/qbo-cli)*
