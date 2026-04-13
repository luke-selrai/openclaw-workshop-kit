---
name: xero-connector
description: "Read and update Xero accounting data on behalf of the user. Handles invoices (list, view, create), contacts (customers and suppliers — list, create), the chart of accounts, bank transactions, payments recorded against invoices and bills, the profit and loss report, the balance sheet, and the connected organisation's details. Use this skill when the user asks about their Xero, invoices, unpaid invoices, contacts, profit and loss, balance sheet, bank transactions, chart of accounts, payments, or when they say 'connect my Xero' or 'help me set up Xero'. On the first use of any Xero feature, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__xero__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - xero
    - accounting
    - invoices
    - contacts
    - finance
    - mcp
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting Xero auth or API errors
    - skill: quickbooks-connector
      reason: Sibling accounting connector — similar MCP pattern for a different platform
---

# Xero Connector

## Overview

This skill lets you read and update a user's Xero accounting data on their behalf. It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap. The user has never used this before. You walk them through it one step at a time, doing all the technical work silently and only asking the user for things that genuinely require them (their credentials, their consent in the browser). The user should never see the words "npm", "bash", "terminal", "OAuth", "install.js", or any file paths. They should feel like they are having a conversation, and at the end their Xero is connected.
- **Phase 2 — Use Tools.** Once the connector is authenticated, you call the 11 MCP tools to read and update Xero data.

**Which phase to run** — Before any tool call, check whether the connector is already authenticated. If it is, skip straight to Phase 2. If it is not, run Phase 1 first.

Check authentication by reading the file at `xero-connector/.xero-token.json` (relative to the workshop-kit folder in the user's home directory, same resolution rules as other connectors in this repo). If the file exists and is non-empty, treat the connector as authenticated. If the file is missing or empty, run Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md` — in particular:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, callback, endpoint, or redirect URI. If you must refer to a technical thing, name it plainly: "the connector pieces", "your browser", "a small file on your computer".
- **Tell them what is about to happen.** Before any action you take: "I am going to check if a tool I need is installed on your computer — this will take a few seconds."
- **React to success and failure warmly.** Good: "That worked — your Xero is now connected." Bad: "OAuth callback received 200."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem at all — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth

This phase gets the connector installed, credentials entered, the browser sign-in completed, and the connector wired into Claude Code. You do every technical action; the user only provides information and clicks things in their browser.

**Important:** Do NOT run `xero-connector/src/install.js` end-to-end. That script is interactive and expects to talk to a human via the terminal. You talk to the human via chat instead, so you do each step yourself and only invoke `xero-connector/src/auth.js` to handle the browser sign-in dance (which is non-interactive once credentials are in place).

### Step 1 — Check Node.js is installed

Tell the user in one short message that you are about to check whether a tool you need is already on their computer.

Silently run:

```bash
node --version
```

- If the version is v20 or higher → tell the user "That's ready" and move to Step 2.
- If the version is v18 or lower, or the command is not found → the user needs Node.js 20+. Follow the Node.js install instructions in `skills/first-run-setup/SKILL.md` Step 3 (nvm on Mac/Linux, winget on Windows). Do not send the user to a website to click an installer. Return here once `node --version` reports v20+.

### Step 2 — Install the connector pieces

Tell the user in one short message: "I am going to install the Xero connector pieces on your computer now. This takes about one minute."

Silently run (from the workshop-kit folder):

```bash
cd xero-connector && npm install
```

- When it finishes successfully → "That's done." Move to Step 3.
- If it fails with a permissions error → translate into plain English: "I need a small permission fix on your computer — let me sort it." Follow the `EACCES`/`EPERM` guidance in `skills/first-run-setup/SKILL.md` (nvm on Mac, Run-As-Admin on Windows), then retry.
- If it fails with a network error → "Your network is blocking the install. This usually happens on company laptops." Ask the user if they are on a corporate network, and if so, ask them to try from a home connection or speak to their IT team. Do not retry endlessly.

### Step 3 — Walk the user through creating a Xero developer app

The user needs to do one manual thing: create a free developer app in their Xero account and copy two values out of it. You cannot do this step for them — Xero requires their authenticated session.

Tell the user (spread across a few short messages, one instruction at a time):

1. "Xero needs me to register with them as an app. This is free and takes about three minutes. I am going to tell you exactly what to click, one step at a time."
2. "First, please open this page in your browser: https://developer.xero.com/app/manage — and sign in with your Xero account. Let me know when you are signed in."
3. When they confirm → "Now click the button that says **New app** in the top-right. A form will appear. Tell me when you see it."
4. When they see the form → deliver the field values one message at a time (or in a short numbered list if appropriate):
   - "For **App name**, type: **Claude Assistant**."
   - "For **Integration type**, choose: **Web app**. (Not 'Public app' and not 'Private app'.)"
   - "For **Company or application URL**, paste: `https://selrai.com.au` — any valid web address works, this is just for display."
   - "For **OAuth 2.0 redirect URI**, paste this exactly: `http://localhost:3000/callback`"
   - "Tick the box to accept the terms, then click the blue **Create app** button. Tell me when you are on the new app's page."
5. When they confirm → "On the left menu, click **Configuration**. At the top of this page is your **Client ID** — please copy it and paste it to me."
6. When they paste the Client ID → "Thanks. Below the Client ID you will see a button that says **Generate a secret**. Click it. A long string will appear. Please copy the **Client Secret** and paste it to me."
7. When they paste the Client Secret → move to Step 4.

Common mistakes to look out for (and correct silently by re-asking):
- The user pasted the placeholder `your_client_id_here` → ask again: "I think that was a copy mistake — please try again and paste the real ID."
- The user pasted something very short (under 20 characters) → probably not the real credential. Ask again.
- The user chose **Public app** or **Private app** instead of **Web app** → tell them: "One small thing — the type needs to be Web app, not Public or Private. You will need to delete this app and create a new one with Web app selected. I'm sorry for the hassle."
- The user entered the redirect URI with `https` instead of `http`, or with a trailing slash → tell them: "The web address I gave you needs to start with http, not https, and must not have a slash at the end. Can you edit it?"

Also warn them once before they click Generate a secret: "Just so you know — the secret Xero shows you only appears in full this one time. Please copy it straight away. If you lose it, you can generate a new one, which replaces the old one automatically."

### Step 4 — Save the credentials

Silently create the file `xero-connector/.env` with these exact contents, using the Client ID and Client Secret the user pasted:

```
# Xero Connector -- Environment Variables
# Generated by the xero-connector skill -- do not commit this file

XERO_CLIENT_ID=<value from Step 3>
XERO_CLIENT_SECRET=<value from Step 3>
```

Never echo the Client ID or Client Secret back to the user after writing them. Never include them in any output visible to the user.

### Step 5 — Browser sign-in

Tell the user: "I am going to open Xero in your browser now. When it appears, please sign in with your Xero account, choose which organisation to connect (if you have more than one), and click the blue **Allow access** button. Then come back here."

Silently run (from the workshop-kit folder):

```bash
cd xero-connector && node src/auth.js
```

This script reads the credentials you just wrote to `.env`, starts a tiny local web server, opens the user's browser at the Xero consent page, waits for them to click Allow access, captures the response, saves the result to `.xero-token.json`, and exits. You do not interact with the script — it runs to completion on its own.

- When it finishes successfully → "Your Xero is signed in. Nearly done." Move to Step 6.
- If it prints a port 3000 error → translate: "Something else on your computer is using the channel I need. Please close any other apps that might be running a local web server and tell me when you have done so." Then retry.
- If it prints `invalid_client` → translate: "Something is off with the ID and Secret you pasted. Let me take them again." Go back to Step 3 Part 5 and ask them to re-copy.
- If it prints `Invalid scope for client` → the user's Xero app is one of the newer app types that only supports granular scopes. Tell them in plain English: "Something about how your Xero app was set up doesn't match what I need. Let me double-check your settings." Then silently verify that the `XERO_CLIENT_ID` in `.env` matches what the user sees in Xero's app page, and retry. If it still fails, ask them to delete the Xero app and create a new one with Web app selected.
- If the user says "it didn't open my browser" → the URL is printed by the script. You can scrape it from the output and paste it back to the user as a clickable link with a short explanation: "Please click this link to sign in to Xero."
- If the user denied access in the browser → translate: "No problem — I saw you cancelled. We can try again whenever you're ready." Ask if they want to retry.

### Step 6 — Wire the connector into Claude Code

Silently add or update the Xero entry in the user's `~/.claude.json` file (the user-level Claude Code config). The file path on Mac/Linux is `$HOME/.claude.json`; on Windows it is `%USERPROFILE%\.claude.json`.

The structure to add is:

```json
{
  "mcpServers": {
    "xero": {
      "command": "node",
      "args": ["<absolute path to xero-connector/src/index.js>"]
    }
  }
}
```

Merge this into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist or is corrupted, back up any existing file to `~/.claude.json.backup` first, then write a fresh config with just the Xero entry.

Use the full absolute path on the current operating system. On Windows, use backslashes; on Mac/Linux, use forward slashes.

### Step 7 — Verify the connection

Tell the user: "Let me just double-check everything is talking to Xero correctly."

Silently run a verification — the cleanest way is to shell out to node and call `getXeroClient()` from `xero-connector/src/index.js`, which internally calls `updateTenants()` so `xero.tenants` is populated. The pattern (run from the `xero-connector` folder so dependencies resolve):

```bash
cd xero-connector && node --input-type=module -e "
import('./src/index.js').then(async ({ getXeroClient }) => {
  const xero = await getXeroClient();
  const org = xero.tenants && xero.tenants[0];
  if (!org) { console.error('FAIL No organisations found'); process.exit(1); }
  console.log('OK', org.tenantName);
});
"
```

- If it prints `OK <organisation name>` → great. Capture the organisation name.
- If it prints `FAIL <reason>` → translate into plain English based on the reason. Expired token → re-run Step 5. Invalid client → credentials wrong, go back to Step 3. No organisations → the user did not select an organisation during sign-in — re-run Step 5 and remind them to pick one.

### Step 8 — Success message

Tell the user, in one short message:

> "All done. I am now connected to your Xero organisation **[organisation name]**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this year?'. Restart Claude Code once so the connection becomes active, then give it a try."

Save to memory that the Xero connector is now installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once the connector is authenticated, use the MCP tools below to answer questions and make changes in Xero. Behaviour rules at the end of this phase apply to every tool call.

### xero_get_organisation

Get the name and details of the connected Xero organisation.

**Use when:** The user asks "what Xero organisation am I connected to?" or you need to confirm the connection is working.

### xero_list_invoices

List invoices in Xero. Supports filtering by status and searching by contact name or invoice number.

**Parameters:**
- `status` — Filter by: `DRAFT`, `SUBMITTED`, `AUTHORISED`, `PAID`, `VOIDED`
- `page` — Page number (100 invoices per page, default 1)
- `search` — Search by contact name or invoice number

**Use when:** The user asks to see invoices, unpaid invoices, overdue invoices, or invoices for a specific client.

**Examples:**
```
User: "Show me my unpaid invoices"
→ Call xero_list_invoices with status: "AUTHORISED"

User: "Find invoices for Acme Corp"
→ Call xero_list_invoices with search: "Acme Corp"

User: "Show me all draft invoices"
→ Call xero_list_invoices with status: "DRAFT"
```

### xero_get_invoice

Get a specific invoice by its Xero ID or invoice number.

**Parameters:**
- `invoice_id` (required) — Xero invoice ID (UUID) or invoice number (e.g. INV-0001)

**Use when:** The user asks for details about a specific invoice, including line items, amounts, and tax.

### xero_create_invoice

Create a new **DRAFT** invoice in Xero. Always created as DRAFT — never auto-approved. The user must review and approve it in Xero.

**Parameters:**
- `contact_name` (required) — Customer name (must match an existing contact, or a new one will be created)
- `description` (required) — Line item description
- `unit_amount` (required) — Price per unit excluding tax
- `quantity` — Quantity (default: 1)
- `account_code` — Account code (e.g. 200 for Sales). Use `xero_list_accounts` to find codes.
- `due_date` — Due date in YYYY-MM-DD format
- `currency_code` — Currency: AUD, NZD, USD, etc. Defaults to the org default.
- `reference` — Optional reference or PO number

**Use when:** The user asks to create, draft, or make an invoice.

**Example:**
```
User: "Create an invoice for Acme Corp for $500 for consulting"
→ Confirm details with the user first, then call xero_create_invoice with:
    contact_name: "Acme Corp"
    description: "Consulting services"
    unit_amount: 500
→ "I've created a draft invoice for Acme Corp for $500. It's saved as a draft — review and approve it in Xero when ready."
```

**If you don't know the account code**, call `xero_list_accounts` first to find the right one, then create the invoice.

### xero_list_contacts

List contacts (customers and suppliers) in Xero.

**Parameters:**
- `search` — Search by name or email address
- `page` — Page number (100 contacts per page)

**Use when:** The user asks to find a customer, supplier, or contact.

### xero_create_contact

Create a new contact (customer or supplier) in Xero.

**Parameters:**
- `name` (required) — Contact display name
- `email` — Email address
- `phone` — Phone number
- `is_customer` — Mark as customer (default: true)
- `is_supplier` — Mark as supplier

### xero_list_accounts

List the chart of accounts in Xero. Returns account codes and names.

**Parameters:**
- `type` — Filter by type: `BANK`, `CURRENT`, `EQUITY`, `EXPENSE`, `FIXED`, `LIABILITY`, `PREPAYMENT`, `REVENUE`, `SALES`, `TERMLIABILITY`

**Use when:** The user asks about their chart of accounts, or you need to find the right account code for creating an invoice.

### xero_list_banktx

List bank transactions in Xero.

**Parameters:**
- `page` — Page number (100 transactions per page)

**Use when:** The user asks about bank transactions, bank feeds, or money in/out.

### xero_list_payments

List payments recorded in Xero against invoices or bills.

**Parameters:**
- `page` — Page number (100 payments per page)

**Use when:** The user asks about payments received or made.

### xero_get_profit_loss

Get the Profit and Loss (Income Statement) report.

**Parameters:**
- `from_date` — Start date YYYY-MM-DD (default: 1 Jan of current year)
- `to_date` — End date YYYY-MM-DD (default: today)

**Use when:** The user asks about income, expenses, net profit, or P&L.

### xero_get_balance_sheet

Get the Balance Sheet report showing assets, liabilities, and equity.

**Parameters:**
- `date` — Report date YYYY-MM-DD (default: today)

**Use when:** The user asks about their balance sheet, assets, liabilities, or equity position.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Show me my invoices" | `xero_list_invoices` |
| "List unpaid invoices" | `xero_list_invoices` with status: `AUTHORISED` |
| "Show me invoice INV-0042" | `xero_get_invoice` |
| "Create an invoice for [client]" | `xero_create_invoice` |
| "Find [name] in my contacts" | `xero_list_contacts` with search |
| "Add a new contact" | `xero_create_contact` |
| "Show me my accounts" | `xero_list_accounts` |
| "List my bank transactions" | `xero_list_banktx` |
| "Show me recent payments" | `xero_list_payments` |
| "Profit and loss for this year" | `xero_get_profit_loss` |
| "Get the balance sheet" | `xero_get_balance_sheet` |
| "What Xero org am I connected to?" | `xero_get_organisation` |
| "Connect my Xero" / "Help me set up Xero" | **Run Phase 1** |

---

## Error Handling (Phase 2)

When a Xero tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| "Not authenticated with Xero" | "Your Xero connection isn't set up yet — let me sort that now." | Run Phase 1 from Step 5 (browser sign-in) |
| "Token expired and refresh failed" | "Your Xero session has expired — one moment while I reconnect you." | Run Phase 1 from Step 5 |
| "No Xero organisations found" | "I can't find a Xero organisation on your account — let me re-run the sign-in." | Run Phase 1 from Step 5; remind the user to pick an organisation |
| "Missing XERO_CLIENT_ID" | "Your credentials are missing — let me set them up again." | Run Phase 1 from Step 3 |
| "Invalid scope for client" | "Your Xero app uses a newer format. Let me check it." | Confirm the Client ID in `.env` matches the current Xero app at developer.xero.com; if the mismatch persists, guide the user to create a new Web app and re-run Phase 1 |
| "invalid_client" | "The details we entered don't match. Let me re-check them." | Run Phase 1 from Step 3 |
| "Invoice not found" | "I couldn't find that invoice — let me list the recent ones so we can pick it." | `xero_list_invoices` |
| "Xero API error" on reports | "Your Xero plan may not include that report type — let me check your subscription level." | Report to user; no automatic retry |
| Any other API error | "Something went wrong with Xero — let me try again." | Retry once; if still failing, run Phase 1 from Step 5 |

---

## Scope Limitations

The Xero connector **can** do:
- Read and create invoices (accounts receivable) — always as DRAFT
- Read and create contacts (customers and suppliers)
- Read chart of accounts
- Read bank transactions
- Read payments
- Read Profit & Loss reports
- Read Balance Sheet reports

The Xero connector **cannot** do:
- Access payroll or employee data
- Access Xero files or attachments
- Delete or void invoices (create as DRAFT — user approves in Xero)
- Create or reconcile bank transactions
- Manage tax rates or tax returns
- Access projects, fixed assets, or budgets
- Send invoices by email (user does this in Xero)
- Access multiple organisations simultaneously (connected to one at a time)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating** invoices or contacts — summarise what you are about to create and wait for the user's OK before calling the tool.
- **Invoices are always DRAFT** — never imply an invoice has been sent or approved. Say "I've created a draft invoice — review and approve it in Xero when ready."
- **Format currency correctly** — use the currency from the Xero response (AUD, NZD, USD, etc.) and format amounts with 2 decimal places.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as a readable table, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Multiple organisations** — the connector uses the first organisation from the user's sign-in. If the user asks about a different Xero organisation, tell them: "I'm currently connected to [current org]. Would you like me to switch?" — then re-run Phase 1 from Step 5.
- **Token errors** → run Phase 1 from Step 5. Do not ask the user to "run a command" — you run it.
- **Never log or echo credentials** — Client ID, Client Secret, and tokens must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **systematic-debugging**: For troubleshooting Xero auth or API errors
- **quickbooks-connector**: Sibling accounting connector for QuickBooks users
