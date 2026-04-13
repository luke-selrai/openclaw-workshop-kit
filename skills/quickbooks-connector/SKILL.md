---
name: quickbooks-connector
description: "Read and update QuickBooks Online accounting data on behalf of the user. Handles invoices (list, view, create), customers (list, create), the chart of accounts, bank transactions, customer payments, the profit and loss report, the balance sheet, and company information. Use this skill when the user asks about their QuickBooks, QBO, invoices, unpaid invoices, customers, profit and loss, balance sheet, bank transactions, chart of accounts, payments received, or when they say 'connect my QuickBooks' or 'help me set up QuickBooks'. On the first use of any QuickBooks feature, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__quickbooks__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - quickbooks
    - qbo
    - accounting
    - invoices
    - customers
    - finance
    - mcp
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting QuickBooks auth or API errors
    - skill: xero-connector
      reason: Sibling accounting connector — similar MCP pattern for a different platform
---

# QuickBooks Connector

## Overview

This skill lets you read and update a user's QuickBooks Online data on their behalf. It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap. The user has never used this before. You walk them through it one step at a time, doing all the technical work silently and only asking the user for things that genuinely require them (their credentials, their consent in the browser). The user should never see the words "npm", "bash", "terminal", "OAuth", "install.js", or any file paths. They should feel like they are having a conversation, and at the end their QuickBooks is connected.
- **Phase 2 — Use Tools.** Once the connector is authenticated, you call the 11 MCP tools to read and update QuickBooks data.

**Which phase to run** — Before any tool call, check whether the connector is already authenticated. If it is, skip straight to Phase 2. If it is not, run Phase 1 first.

Check authentication by reading the file at `quickbooks-connector/.quickbooks-token.json` (relative to the workshop-kit folder in the user's home directory, same resolution rules as other connectors in this repo). If the file exists and contains `realmId`, treat the connector as authenticated. If the file is missing or empty, run Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md` — in particular:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, bash, CLI, API, terminal, config file, OAuth, scope, token, realmId, MCP, callback, endpoint, or redirect URI. If you must refer to a technical thing, name it plainly: "the connector pieces", "your browser", "a small file on your computer".
- **Tell them what is about to happen.** Before any action you take: "I am going to check if a tool I need is installed on your computer — this will take a few seconds."
- **React to success and failure warmly.** Good: "That worked — your QuickBooks is now connected." Bad: "OAuth callback received 200."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem at all — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth

This phase gets the connector installed, credentials entered, the browser sign-in completed, and the connector wired into Claude Code. You do every technical action; the user only provides information and clicks things in their browser.

**Important:** Do NOT run `quickbooks-connector/src/install.js` end-to-end. That script is interactive and expects to talk to a human via the terminal. You talk to the human via chat instead, so you do each step yourself and only invoke `quickbooks-connector/src/auth.js` to handle the browser sign-in dance (which is non-interactive once credentials are in place).

### Step 1 — Check Node.js is installed

Tell the user in one short message that you are about to check whether a tool you need is already on their computer.

Silently run:

```bash
node --version
```

- If the version is v20 or higher → tell the user "That's ready" and move to Step 2.
- If the version is v18 or lower, or the command is not found → the user needs Node.js 20+. Follow the Node.js install instructions in `skills/first-run-setup/SKILL.md` Step 3 (nvm on Mac/Linux, winget on Windows). Do not send the user to a website to click an installer. Return here once `node --version` reports v20+.

### Step 2 — Install the connector pieces

Tell the user in one short message: "I am going to install the QuickBooks connector pieces on your computer now. This takes about one minute."

Silently run (from the workshop-kit folder):

```bash
cd quickbooks-connector && npm install
```

- When it finishes successfully → "That's done." Move to Step 3.
- If it fails with a permissions error → translate into plain English: "I need a small permission fix on your computer — let me sort it." Follow the same `EACCES`/`EPERM` guidance the xero-connector setup uses (nvm on Mac, Run-As-Admin on Windows), then retry.
- If it fails with a network error → "Your network is blocking the install. This usually happens on company laptops." Ask the user if they are on a corporate network, and if so, ask them to try from a home connection or speak to their IT team. Do not retry endlessly.

### Step 3 — Walk the user through creating a QuickBooks developer app

The user needs to do one manual thing: create a free developer app in their Intuit account and copy two values out of it. You cannot do this step for them — Intuit requires their authenticated session.

Tell the user (spread across a few short messages, one instruction at a time):

1. "QuickBooks needs me to register with them as an app. This is free and takes about three minutes. I am going to tell you exactly what to click, one step at a time."
2. "First, please open this page in your browser: https://developer.intuit.com — and sign in with your Intuit account. Let me know when you are signed in."
3. When they confirm → "Now click 'My Hub' at the top, then 'App Dashboard', then the button that says 'Create an app'. Let me know when you see the list of app types."
4. "Choose 'QuickBooks Online and Payments'. For app name, type exactly: **Claude Assistant**. Tick the box next to 'com.intuit.quickbooks.accounting'. Then click 'Create app'. Tell me when you are on the new app's page."
5. "On the left, click 'Settings', then 'Redirect URIs'. Make sure you are on the **Development** tab (not Production). Click 'Add URI' and paste this exactly: `http://localhost:3000/callback`. Click Save. Tell me when it is saved."
6. "On the left, click 'Keys and credentials'. Make sure you are on the **Development** tab. Click 'Show credentials'. You should see two long strings labeled **Client ID** and **Client Secret**."
7. "Please copy your Client ID and paste it to me."
8. When they paste the ID → "Thanks. Now please copy your Client Secret and paste it to me."
9. When they paste both → move to Step 4.

Common mistakes to look out for (and correct silently by re-asking):
- The user pasted the placeholder `your_client_id_here` → ask again: "I think that was a copy mistake — please try again and paste the real ID."
- The user pasted something very short (under 20 characters) → probably not the real credential. Ask again.
- The user added the redirect URI on the Production tab instead of Development → tell them: "One small thing — the web address I gave you needs to go on the tab that says Development, not Production. Can you move it across?"

### Step 4 — Ask sandbox or production

Tell the user (in one message): "QuickBooks has two modes — a safe practice mode with fake data, and your real business account. For today I recommend the safe practice mode so we can try things without touching your real books. Would you like to use the practice mode or your real account?"

- If practice mode → use `sandbox`. Tell the user: "Good choice. One small extra step — I need you to create a practice company first. In the same Intuit page, click 'My Hub' then 'Sandbox' on the left, then 'Add sandbox', then 'QuickBooks Online Plus', then your country. Click Create and wait about 30 seconds. Let me know when it says your practice company is ready."
- If real account → use `production`. Tell the user: "Got it. We will connect to your real QuickBooks in a moment."

### Step 5 — Save the credentials

Silently create the file `quickbooks-connector/.env` with these exact contents, using the Client ID and Client Secret the user pasted and the environment they picked:

```
# QuickBooks Connector -- Environment Variables
# Generated by the quickbooks-connector skill -- do not commit this file

QUICKBOOKS_CLIENT_ID=<value from Step 3>
QUICKBOOKS_CLIENT_SECRET=<value from Step 3>
QUICKBOOKS_ENVIRONMENT=<sandbox|production from Step 4>
```

Never echo the Client ID or Client Secret back to the user after writing them. Never include them in any output visible to the user.

### Step 6 — Browser sign-in

Tell the user: "I am going to open QuickBooks in your browser now. When it appears, please sign in with your Intuit account, choose your practice company (or your real company), and click the blue Connect button. Then come back here."

Silently run (from the workshop-kit folder):

```bash
cd quickbooks-connector && node src/auth.js
```

This script reads the credentials you just wrote to `.env`, starts a tiny local web server, opens the user's browser at the Intuit consent page, waits for them to click Connect, captures the response, saves the result to `.quickbooks-token.json`, and exits. You do not interact with the script — it runs to completion on its own.

- When it finishes successfully → "Your QuickBooks is signed in. Nearly done." Move to Step 7.
- If it prints a port 3000 error → translate: "Something else on your computer is using the channel I need. Please close any other apps that might be running a local web server and tell me when you have done so." Then retry.
- If it prints `invalid_client` → translate: "Something is off with the ID and Secret you pasted. Let me take them again." Go back to Step 3 Part 6 and ask them to re-copy.
- If the user says "it didn't open my browser" → the URL is printed by the script. You can scrape it from the output and paste it back to the user as a clickable link with a short explanation: "Please click this link to sign in to QuickBooks."
- If the user denied access in the browser → translate: "No problem — I saw you cancelled. We can try again whenever you're ready." Ask if they want to retry.

### Step 7 — Wire the connector into Claude Code

Silently add or update the QuickBooks entry in the user's `~/.claude.json` file (the user-level Claude Code config). The file path on Mac/Linux is `$HOME/.claude.json`; on Windows it is `%USERPROFILE%\.claude.json`.

The structure to add is:

```json
{
  "mcpServers": {
    "quickbooks": {
      "command": "node",
      "args": ["<absolute path to quickbooks-connector/src/index.js>"]
    }
  }
}
```

Merge this into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist or is corrupted, back up any existing file to `~/.claude.json.backup` first, then write a fresh config with just the QuickBooks entry.

Use the full absolute path on the current operating system. On Windows, use backslashes; on Mac/Linux, use forward slashes.

### Step 8 — Verify the connection

Tell the user: "Let me just double-check everything is talking to QuickBooks correctly."

Silently run a verification — the cleanest way is to shell out to node and call `getQuickBooksClient()` from `quickbooks-connector/src/index.js`, then call `getCompanyInfo` on the resulting client. The pattern (run from the `quickbooks-connector` folder so dependencies resolve):

```bash
cd quickbooks-connector && node --input-type=module -e "
import('./src/index.js').then(async ({ getQuickBooksClient }) => {
  const { qbo, realmId } = await getQuickBooksClient();
  qbo.getCompanyInfo(realmId, (err, info) => {
    if (err) { console.error('FAIL', err.message || JSON.stringify(err)); process.exit(1); }
    console.log('OK', info.CompanyName);
  });
});
"
```

- If it prints `OK <company name>` → great. Capture the company name.
- If it prints `FAIL <reason>` → translate into plain English based on the reason. Missing realmId → re-run Step 6. Expired token → re-run Step 6. Invalid client → credentials wrong, go back to Step 3.

### Step 9 — Success message

Tell the user, in one short message:

> "All done. I am now connected to your QuickBooks company **[company name]**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this month?'. Restart Claude Code once so the connection becomes active, then give it a try."

Save to memory that the QuickBooks connector is now installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once the connector is authenticated, use the MCP tools below to answer questions and make changes in QuickBooks. Behaviour rules at the end of this phase apply to every tool call.

### quickbooks_get_company

Get the name, address, industry, and contact details of the connected QuickBooks company.

**Use when:** The user asks "what QuickBooks company am I connected to?" or you need to confirm the connection is working.

### quickbooks_list_invoices

List invoices in QuickBooks. Status is derived from each invoice's balance and due date (QuickBooks has no top-level status field).

**Parameters:**
- `status` — Filter by: `Draft`, `Pending`, `Voided`, `Deleted`, `Synced` (paid in full), `Overdue`
- `limit` — Maximum number of invoices (default 20)

**Use when:** The user asks to see invoices, unpaid invoices, overdue invoices, or recent invoices.

**Examples:**
```
User: "Show me my unpaid invoices"
→ Call quickbooks_list_invoices with status: "Pending"

User: "Which invoices are overdue?"
→ Call quickbooks_list_invoices with status: "Overdue"

User: "Show me my last 5 invoices"
→ Call quickbooks_list_invoices with limit: 5
```

### quickbooks_get_invoice

Get a specific invoice by its QuickBooks ID.

**Parameters:**
- `invoice_id` (required) — QuickBooks invoice ID

**Use when:** The user asks for details about a specific invoice, including line items and amounts.

### quickbooks_create_invoice

Create a new invoice in QuickBooks for a customer. If the customer does not exist, it will be created automatically. The invoice is saved as pending (not emailed).

**Parameters:**
- `customer_name` (required) — Customer display name
- `description` (required) — Line item description
- `amount` (required) — Total amount excluding tax
- `due_date` — Due date in YYYY-MM-DD format

**Important:** QuickBooks requires at least one **Product/Service Item** to exist in the company before any invoice can be created — the connector picks the first available Item automatically. If there are no Items, the tool returns an error and the user must create one in QuickBooks first (Sales → Products and Services → New).

**Example:**
```
User: "Create an invoice for Acme Corp for $500 for consulting"
→ Confirm details with the user first, then call quickbooks_create_invoice with:
    customer_name: "Acme Corp"
    description: "Consulting services"
    amount: 500
→ "I've saved an invoice for Acme Corp for $500. Review and send it from QuickBooks when ready."
```

### quickbooks_list_customers

List customers in QuickBooks. Supports searching by display name.

**Parameters:**
- `search` — Search by customer display name
- `limit` — Maximum number of customers (default 20)

### quickbooks_create_customer

Create a new customer in QuickBooks.

**Parameters:**
- `name` (required) — Customer display name
- `email` — Email address
- `phone` — Phone number

### quickbooks_list_accounts

List the chart of accounts in QuickBooks.

**Parameters:**
- `type` — Filter by type: `Bank`, `Accounts Receivable`, `Income`, `Expense`, `Cost of Goods Sold`, `Fixed Asset`, `Other Asset`, `Credit Card`, `Accounts Payable`, `Long Term Liability`, `Equity`

### quickbooks_list_bank_transactions

List recent bank transactions in QuickBooks (both purchases and deposits, merged and sorted by date, with purchases shown as negative amounts).

**Parameters:**
- `limit` — Maximum number of transactions per type (default 20)

### quickbooks_list_payments

List payments received from customers in QuickBooks. Returns payment ID, date, customer, amount, payment method, and any linked invoice references.

**Parameters:**
- `limit` — Maximum number of payments (default 20)

### quickbooks_get_profit_loss

Get the Profit and Loss (Income Statement) report.

**Parameters:**
- `from_date` — Start date YYYY-MM-DD (default: 1 Jan of current year)
- `to_date` — End date YYYY-MM-DD (default: today)

### quickbooks_get_balance_sheet

Get the Balance Sheet report showing assets, liabilities, and equity at a point in time.

**Parameters:**
- `as_of_date` — Report date YYYY-MM-DD (default: today)

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Show me my invoices" | `quickbooks_list_invoices` |
| "List unpaid invoices" | `quickbooks_list_invoices` with status: `Pending` |
| "Which invoices are overdue?" | `quickbooks_list_invoices` with status: `Overdue` |
| "Show me invoice 1022" | `quickbooks_get_invoice` |
| "Create an invoice for [client]" | `quickbooks_create_invoice` |
| "Find [name] in my customers" | `quickbooks_list_customers` with search |
| "Add a new customer" | `quickbooks_create_customer` |
| "Show me my accounts" | `quickbooks_list_accounts` |
| "List my bank transactions" | `quickbooks_list_bank_transactions` |
| "Show me recent payments" | `quickbooks_list_payments` |
| "Profit and loss for this year" | `quickbooks_get_profit_loss` |
| "Get the balance sheet" | `quickbooks_get_balance_sheet` |
| "What QuickBooks company am I connected to?" | `quickbooks_get_company` |
| "Connect my QuickBooks" / "Help me set up QuickBooks" | **Run Phase 1** |

---

## Error Handling (Phase 2)

When a QuickBooks tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| "Not authenticated with QuickBooks" | "Your QuickBooks connection isn't set up yet — let me sort that now." | Run Phase 1 from Step 6 (browser sign-in) |
| "Token expired and refresh failed" | "Your QuickBooks session has expired — one moment while I reconnect you." | Run Phase 1 from Step 6 |
| "Missing realmId in .quickbooks-token.json" | "Your connection is incomplete — I need to re-do the sign-in." | Run Phase 1 from Step 6 |
| "Missing QUICKBOOKS_CLIENT_ID" | "Your credentials are missing — let me set them up again." | Run Phase 1 from Step 3 |
| "No Products/Services found" (create invoice) | "Before I can create invoices, QuickBooks needs at least one product or service in your company. Please open QuickBooks, go to Sales then Products and Services, create a basic service item, and let me know when it is done." | User action in QuickBooks; retry after |
| "Invoice not found" | "I couldn't find that invoice — let me list the recent ones so we can pick it." | `quickbooks_list_invoices` |
| "invalid_client" / "invalid_grant" | "The details we entered don't match. Let me re-check them." | Run Phase 1 from Step 3; verify the environment matches the tab the credentials came from |
| Any other API error | "Something went wrong with QuickBooks — let me try again." | Retry once; if still failing, run Phase 1 from Step 6 |

---

## Scope Limitations

The QuickBooks connector **can** read invoices, customers, accounts, bank transactions, payments, P&L, balance sheet, and company information. It **can** create invoices and customers.

It **cannot** access payroll, QuickBooks Payments processing, attachments, email send, bank reconciliation, sales tax, classes/locations/custom fields, or multiple QuickBooks companies at once. It **cannot** create an invoice in a QuickBooks company that has zero Products/Services — one Item must exist first.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating** invoices or customers — summarise what you are about to create and wait for the user's OK before calling the tool.
- **Invoices are saved as pending, not emailed** — never imply an invoice has been sent. Say "I've saved the invoice in QuickBooks — review and send it from QuickBooks when ready."
- **Customer auto-creation** — when `quickbooks_create_invoice` auto-creates a new customer, tell the user a new customer was created alongside the invoice, so they can add email/phone details afterwards if they want.
- **Format currency correctly** — 2 decimal places, use the currency from the QuickBooks response (most users see their local currency; the connector respects whatever the company is configured for).
- **Present reports clearly** — when showing P&L or Balance Sheet, format as a readable table, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Sandbox awareness** — if the connector is in `sandbox` mode and the user mentions real financial decisions, remind them gently that they are looking at practice data, not their real figures.
- **Token errors** → run Phase 1 from Step 6. Do not ask the user to "run a command" — you run it.
- **Never log or echo credentials** — Client ID, Client Secret, realmId, and tokens must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **systematic-debugging**: For troubleshooting QuickBooks auth or API errors
- **xero-connector**: Sibling accounting connector for Xero users
