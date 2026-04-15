---
title: Xero — Setup Guide
version: 4.0
date: 2026-04-15
---

# Xero — Setup Guide

This guide connects your Xero accounting account to your AI assistant using the **official Xero MCP server** built and maintained by Xero themselves. Once set up, your assistant can read and create invoices, find contacts, manage quotes and credit notes, pull profit & loss and balance sheet reports, check bank transactions, and more — all through plain English.

The entire setup takes about 5 minutes. **You only do one manual thing yourself** (create a Custom Connection in Xero's developer portal). Everything else — saving your connection details, wiring them into Claude Code, verifying the connection — is handled by your assistant conversationally.

---

## ⚠️ Before You Start — Two Things You Need to Know

### 1. This costs about $5 USD per month

Xero charges a small recurring fee — roughly **$5 USD per month** (about $8 AUD, £5 GBP) — to enable the "Custom Connection" type of connection that this guide uses. The fee is billed by Xero on top of your normal Xero subscription.

**Why the cost?** This is the only connection type Xero offers that works silently in the background without making you click "Allow access" every 30 minutes. It's the right choice for a daily-use AI assistant. If the monthly fee is a blocker, contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) and we can discuss alternatives.

### 2. Only available in AU, NZ, UK, and US

Xero currently only offers Custom Connections for organisations in **Australia, New Zealand, the United Kingdom, and the United States**. If your Xero organisation is based in any other country, this setup path will not work for you — please contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) for the alternative.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A Xero account (any plan — Starter, Standard, or Premium)
- A Xero developer account (free — sign up at [developer.xero.com](https://developer.xero.com))
- A payment method saved in Xero (credit card or direct debit — for the monthly Custom Connection charge)
- An internet connection

> **No coding experience required.** Your assistant handles everything technical. You only copy and paste two values from Xero.

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

| Area | What Your Assistant Can Do |
|---|---|
| **Invoices** | List, search, view, create (as drafts), and update invoices |
| **Contacts** | Search customers and suppliers, add new contacts, update details |
| **Quotes** | List, create, and update sales quotes |
| **Credit Notes** | List, create, and update credit notes / refunds |
| **Items** | Browse your product catalogue and pricing |
| **Bank Transactions** | List bank transactions with dates and amounts |
| **Payments** | List payments recorded against invoices and bills, record new payments |
| **Chart of Accounts** | Browse account codes, types, and tax rates |
| **Profit & Loss** | Pull income and expense reports for any date range |
| **Balance Sheet** | View assets, liabilities, and equity at a point in time |
| **Trial Balance** | Pull an accountant-style account summary |
| **Aged Receivables / Payables** | See who owes you money and who you owe, by contact and age |
| **Manual Journals** | Post and view manual journal entries |
| **Tracking Categories** | Manage cost centres, departments, and tracking dimensions |
| **Payroll (NZ/UK only)** | Read and manage employees, leave, and timesheets |
| **Organisation** | Check which Xero organisation is connected |

This is powered by the [official `@xeroapi/xero-mcp-server`](https://github.com/XeroAPI/xero-mcp-server), which exposes around **56 tools** covering the full accounting surface.

---

## Step 1 — Create a Custom Connection in Xero (One-Time, You Do This)

This is the only manual step. Xero requires you to be signed in to create a connection. Your assistant will walk you through it conversationally — you can **skip reading this section** and just say *"Connect my Xero"* to your assistant. The steps below are here for reference or if you prefer to do it yourself.

1. Go to [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
2. Sign in with your Xero account
3. Click **New app** (top right)
4. Fill in the form:
   - **App name:** `Claude Assistant` (or any name you like)
   - **Integration type:** **Custom connection** (⚠️ *not* "Web app" — this is the key choice)
   - **Company or application URL:** your business website URL, e.g. `https://yourbusiness.com.au` (any valid URL works — this is just for display)
5. Tick the box to accept the terms, then click the blue **Create app** button
6. On the new app's page, select which **Xero organisation** you want to connect — Custom connections are linked to one organisation at a time
7. Under **Scopes**, tick these permissions:
   - `accounting.transactions`
   - `accounting.reports.read`
   - `accounting.journals.read`
   - `accounting.settings`
   - `accounting.contacts`
   - `accounting.attachments`
   - *(If you're in NZ or UK and want payroll tools:)* `payroll.employees`, `payroll.payruns`, `payroll.payslip`, `payroll.timesheets`, `payroll.settings`
8. Click **Save**
9. **Activate the connection** — Xero will prompt you to confirm payment details and activate the recurring monthly charge (~$5 USD). Follow Xero's prompts to complete this step
10. Once activated, you'll see your **Client ID** at the top of the connection page — **copy it**
11. Click **Generate a secret** to reveal your **Client Secret** — **copy it immediately**
12. **Save both values somewhere safe** — you will paste them to your assistant in Step 2

> **Common mistakes to avoid:**
>
> - **Integration type must be "Custom connection"** — not "Web app", not "Mobile or desktop app". If you pick the wrong type, you'll need to delete the app and start over.
> - **The Client Secret is only shown once.** Copy it immediately. If you lose it, you can generate a new one (which revokes the old one).
> - **Scopes must be saved** — don't forget to click the **Save** button after ticking the boxes.
> - **The connection must be active** — if you don't complete the payment/activation step, the connection exists but won't work.

---

## Step 2 — Tell Your Assistant to Connect (Your Assistant Does the Rest)

Open Claude Code and say:

> **"Help me connect my Xero account"**

Your assistant will:

1. Ask you the two safety-gate questions (which country is your Xero in, are you OK with the small monthly charge)
2. Walk you through Step 1 above conversationally, one step at a time, in plain English — so if you haven't done Step 1 yet, your assistant will guide you through it now
3. Ask you to paste the Client ID and Client Secret from Step 1
4. Save the connection details securely on your computer
5. Ask you to restart Claude Code once so the connection becomes active
6. Verify the connection is working and tell you which Xero organisation you're connected to

You will not run any commands yourself. Your assistant handles all the technical work. You just answer its questions in plain English and paste the two values when asked.

When your assistant tells you it's finished, try asking:

- *"Show me my recent Xero invoices"*
- *"What Xero organisation am I connected to?"*
- *"Find Acme Corp in my Xero contacts"*
- *"What's my profit and loss for this year?"*

If your assistant responds with your Xero data, you're all set.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Check invoices** | *"Show me my unpaid invoices"* |
| **Create an invoice** | *"Create a Xero invoice for Acme Corp for $500"* |
| **Update an invoice** | *"Update invoice INV-0042 to add a $100 line item"* |
| **Find a contact** | *"Find John Smith in my Xero contacts"* |
| **Add a contact** | *"Add a new contact called ABC Pty Ltd"* |
| **Create a quote** | *"Create a quote for Acme Corp for three months of consulting"* |
| **Issue a credit note** | *"Issue a credit note for Acme Corp for $200"* |
| **Profit & Loss** | *"Show me the Xero profit and loss for this year"* |
| **Balance Sheet** | *"Get the Xero balance sheet as of today"* |
| **Aged receivables** | *"Who owes me money and how overdue are they?"* |
| **Aged payables** | *"Who do I owe money to?"* |
| **Chart of accounts** | *"List my Xero expense accounts"* |
| **Bank transactions** | *"Show me my recent bank transactions in Xero"* |
| **Payments** | *"Show me recent payments in Xero"* |
| **Record a payment** | *"Record a $500 payment from Acme Corp against invoice INV-0042"* |
| **Products / items** | *"List my Xero inventory items"* |
| **Tax rates** | *"What Xero tax codes can I use?"* |
| **Reconnect** | *"My Xero connection has stopped working"* |
| **Switch organisations** | *"I want to connect a different Xero organisation"* |

---

## Keeping Your Connection Active

Custom Connections don't expire the way older OAuth connections did — as long as:

1. Your **Custom Connection is active** in your Xero developer portal (the monthly charge is being paid)
2. Your **Client ID and Client Secret** haven't been revoked or regenerated

…your assistant will keep working silently in the background with no browser sign-ins, no 30-minute token refreshes, and no 60-day expiry.

**If something does stop working**, just say to your assistant:

> **"My Xero connection has stopped working"**

Your assistant will check what's wrong and walk you through the fix. The most common causes:

- The Custom Connection was deactivated (check the billing page in your Xero developer portal)
- You regenerated the Client Secret without updating your assistant (paste the new one)
- A permission you added later hasn't been ticked yet

---

## Adding More Permissions Later

If your assistant tells you it needs an extra permission for something (for example, payroll tools if you didn't tick those originally):

1. Go to [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
2. Click on your **Claude Assistant** Custom Connection
3. Click the **Scopes** section and tick the additional boxes your assistant mentioned
4. Click **Save**
5. Go back to Claude Code and try your request again — **no restart needed**, scope changes apply on the next call

---

## Troubleshooting

### Setup Problems

| Problem | Fix |
|---|---|
| *"I don't see a Custom connection option in the integration type dropdown"* | Your Xero organisation is not in one of the supported countries (AU, NZ, UK, US). Contact Luke at luke@selrai.com.au for the alternative. |
| *"Xero is asking me for a payment method"* | Normal — Custom Connections carry a small monthly charge. Add a card to your Xero developer account and continue. |
| *"The Client Secret didn't show up after I clicked Generate"* | Sometimes it appears below the button. Scroll down. If still nothing, refresh the page and click **Generate a secret** again — this creates a new one and revokes the old. |
| *"I lost the Client Secret"* | Go back to the Custom Connection page, click **Generate a secret** to create a new one, and tell your assistant: *"I have a new Xero connection key."* |
| *"Connection key not working"* (401 invalid_client) | Double-check you copied the full Client ID and Secret — no extra spaces, no missing characters. Ask your assistant to save the details again. |

### After Setup

| Problem | Fix |
|---|---|
| Assistant says *"tool not available"* | Close Claude Code completely and reopen it. The connection becomes active on restart. |
| *"Your Xero connection has been deactivated"* | Your Custom Connection was turned off in Xero — usually because the monthly charge lapsed. Reactivate it at [developer.xero.com/app/manage](https://developer.xero.com/app/manage). |
| *"I need an extra permission"* | See **Adding More Permissions Later** above. Your assistant will tell you which scope to tick. |
| *"Xero is asking me to slow down"* (rate limit) | Xero enforces per-organisation rate limits. Wait a moment and try again — rare in normal use. |
| Wrong Xero organisation connected | Custom Connections are one-per-organisation. To switch, create a second Custom Connection for the other organisation in Xero, then tell your assistant: *"Switch my Xero connection to the new one."* |
| *"Xero API error"* on reports | Your Xero plan may not include that report type. Check your Xero subscription level. |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Accountants and Advisors

Custom Connections are tied to a single Xero organisation at creation time. If you manage multiple client organisations, you'll need to create a separate Custom Connection for each — and each carries its own monthly charge. Your assistant can only connect to one at a time; to switch clients, tell your assistant *"Switch my Xero to [other client name]"* and it will walk you through swapping the connection key.

For accounting practices wanting a more scalable multi-tenant setup, contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) — there are alternative paths for practice-scale deployments.

---

## Security Notes

- Your Client ID and Client Secret are stored only in your local Claude Code settings file on your computer — never sent to Anthropic, Selr AI, or any third party
- Your assistant uses the **official Xero MCP server** published and maintained by Xero themselves at [github.com/XeroAPI/xero-mcp-server](https://github.com/XeroAPI/xero-mcp-server)
- The connection uses Xero's Custom Connection authentication — no OAuth callback URLs, no browser sign-ins, no token refresh cycle
- You can revoke the connection at any time by deactivating the Custom Connection in your Xero developer portal
- The connector respects whatever scopes you ticked — if you only granted read access, your assistant physically cannot create or modify records even if you ask it to
- Never share your Client ID and Client Secret with anyone — treat them like a password

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
