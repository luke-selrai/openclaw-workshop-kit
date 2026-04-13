---
name: quickbooks-connector
description: "Interact with QuickBooks Online accounting data through MCP tools. Use this skill when the user asks about invoices, customers, accounts, bank transactions, payments, profit and loss, balance sheet, or any QuickBooks accounting data. Handles reading invoices, creating invoices, looking up customers, adding customers, viewing chart of accounts, listing bank transactions (purchases and deposits), listing customer payments, and pulling financial reports. Also use when the user mentions 'QuickBooks,' 'QBO,' 'my invoices,' 'profit and loss,' 'balance sheet,' 'unpaid invoices,' 'QuickBooks customers,' 'bank transactions,' 'chart of accounts,' or 'create an invoice.' For initial setup and installation, guide the user to run the installer at quickbooks-connector/src/install.js."
allowed-tools: mcp__quickbooks__*
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

This skill uses the QuickBooks MCP server to read and write accounting data in the user's QuickBooks Online company. The connector must already be installed and authenticated before these tools work.

> **Not set up yet?** Tell the user to run the installer:
> `node /path/to/quickbooks-connector/src/install.js`
> See `quickbooks-connector/QUICKBOOKS-SETUP.md` for full instructions.

---

## Prerequisites

Before using any QuickBooks tools, confirm:

1. **Connector is installed** — `quickbooks-connector/node_modules/` exists
2. **Credentials are saved** — `quickbooks-connector/.env` has real values (not placeholders) including `QUICKBOOKS_CLIENT_ID`, `QUICKBOOKS_CLIENT_SECRET`, and `QUICKBOOKS_ENVIRONMENT`
3. **Token exists** — `quickbooks-connector/.quickbooks-token.json` exists and contains a `token`, `realmId`, and `environment` field
4. **MCP server is configured** — `~/.claude.json` has a `"quickbooks"` entry under `mcpServers`

If any of these are missing, guide the user to run the installer.

> **Sandbox vs Production.** QuickBooks has two separate environments. The `QUICKBOOKS_ENVIRONMENT` field in `.env` must be either `sandbox` (test company with fake data, recommended for workshops) or `production` (real QuickBooks Online account). The Client ID and Secret in `.env` must come from the **matching tab** in the Intuit developer dashboard — Development credentials for sandbox, Production credentials for production. To switch environments, update `.env` and re-run `npm run auth` in the quickbooks-connector folder.

---

## Available Tools

### quickbooks_get_company

Get the name, address, industry, and contact details of the connected QuickBooks company.

**Use when:** The user asks "what QuickBooks company am I connected to?" or you need to confirm the connection is working.

**Example:**
```
User: "What QuickBooks company am I connected to?"
→ Call quickbooks_get_company
→ "You're connected to Sandbox Company AU (Australia)."
```

---

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

---

### quickbooks_get_invoice

Get a specific invoice by its QuickBooks ID.

**Parameters:**
- `invoice_id` (required) — QuickBooks invoice ID

**Use when:** The user asks for details about a specific invoice, including line items and amounts.

**Example:**
```
User: "Show me invoice 1022"
→ Call quickbooks_get_invoice with invoice_id: "1022"
```

---

### quickbooks_create_invoice

Create a new invoice in QuickBooks for a customer. If the customer does not exist, it will be created automatically. The invoice is saved as pending (not emailed).

**Parameters:**
- `customer_name` (required) — Customer display name
- `description` (required) — Line item description
- `amount` (required) — Total amount excluding tax
- `due_date` — Due date in YYYY-MM-DD format

**Use when:** The user asks to create, draft, or make an invoice.

**Important:** QuickBooks requires at least one **Product/Service Item** to exist in the company before any invoice can be created — the connector picks the first available Item automatically. If there are no Items, the tool returns an error and the user must create one in QuickBooks first (Sales → Products and Services → New).

**Example:**
```
User: "Create an invoice for Acme Corp for $500 for consulting"
→ Call quickbooks_create_invoice with:
    customer_name: "Acme Corp"
    description: "Consulting services"
    amount: 500
→ "I've created an invoice for Acme Corp for $500. 
   It's saved in QuickBooks as pending — review and send it from QuickBooks when ready."
```

**If the customer does not exist**, the connector will create them automatically using just the name. If you want to set email or phone, call `quickbooks_create_customer` first, then create the invoice.

---

### quickbooks_list_customers

List customers in QuickBooks. Supports searching by display name.

**Parameters:**
- `search` — Search by customer display name
- `limit` — Maximum number of customers (default 20)

**Use when:** The user asks to find a customer or list customers.

**Example:**
```
User: "Find John Smith in my QuickBooks customers"
→ Call quickbooks_list_customers with search: "John Smith"
```

---

### quickbooks_create_customer

Create a new customer in QuickBooks.

**Parameters:**
- `name` (required) — Customer display name
- `email` — Email address
- `phone` — Phone number

**Use when:** The user asks to add a new customer to QuickBooks.

**Example:**
```
User: "Add a new customer called ABC Pty Ltd with email info@abc.com"
→ Call quickbooks_create_customer with:
    name: "ABC Pty Ltd"
    email: "info@abc.com"
```

---

### quickbooks_list_accounts

List the chart of accounts in QuickBooks. Optionally filter by account type.

**Parameters:**
- `type` — Filter by type: `Bank`, `Accounts Receivable`, `Income`, `Expense`, `Cost of Goods Sold`, `Fixed Asset`, `Other Asset`, `Credit Card`, `Accounts Payable`, `Long Term Liability`, `Equity`

**Use when:** The user asks about their chart of accounts or wants to see specific account types.

**Examples:**
```
User: "List my QuickBooks expense accounts"
→ Call quickbooks_list_accounts with type: "Expense"

User: "Show me my bank accounts"
→ Call quickbooks_list_accounts with type: "Bank"
```

---

### quickbooks_list_bank_transactions

List recent bank transactions in QuickBooks. Returns both purchases (money out) and deposits (money in), combined and sorted by date. Purchases appear as negative amounts.

**Parameters:**
- `limit` — Maximum number of transactions per type (default 20)

**Use when:** The user asks about bank transactions, bank feeds, money in/out, or recent spending.

**Example:**
```
User: "Show me my recent QuickBooks bank transactions"
→ Call quickbooks_list_bank_transactions
```

---

### quickbooks_list_payments

List payments received from customers in QuickBooks. Returns payment ID, date, customer, amount, payment method, and any linked invoice references.

**Parameters:**
- `limit` — Maximum number of payments (default 20)

**Use when:** The user asks about customer payments received, or wants to see which invoices have been paid.

**Example:**
```
User: "Show me recent QuickBooks payments"
→ Call quickbooks_list_payments

User: "Who paid us last week?"
→ Call quickbooks_list_payments and filter the results by date in your response
```

---

### quickbooks_get_profit_loss

Get the Profit and Loss (Income Statement) report.

**Parameters:**
- `from_date` — Start date YYYY-MM-DD (default: 1 Jan of current year)
- `to_date` — End date YYYY-MM-DD (default: today)

**Use when:** The user asks about income, expenses, net profit, or P&L.

**Examples:**
```
User: "Show me the P&L for this year"
→ Call quickbooks_get_profit_loss (defaults to Jan 1 to today)

User: "What was my profit and loss for March?"
→ Call quickbooks_get_profit_loss with from_date: "2026-03-01", to_date: "2026-03-31"
```

---

### quickbooks_get_balance_sheet

Get the Balance Sheet report showing assets, liabilities, and equity at a point in time.

**Parameters:**
- `as_of_date` — Report date YYYY-MM-DD (default: today)

**Use when:** The user asks about their balance sheet, assets, liabilities, or equity position.

**Example:**
```
User: "Get my QuickBooks balance sheet as of today"
→ Call quickbooks_get_balance_sheet
```

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

---

## Error Handling

When a QuickBooks tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| "Not authenticated with QuickBooks" | "Your QuickBooks connection needs to be set up. Let me help you." | Guide user to run `npm run auth` in the quickbooks-connector folder |
| "Token expired and refresh failed" | "Your QuickBooks session has expired. Let's reconnect." | Run `npm run auth` in the quickbooks-connector folder |
| "Missing realmId in .quickbooks-token.json" | "Your QuickBooks connection is incomplete — I can't tell which company to talk to. Let's re-run the installer." | Re-run the installer: `node quickbooks-connector/src/install.js` |
| "Missing QUICKBOOKS_CLIENT_ID" | "Your QuickBooks credentials are missing. Let's set them up." | Guide user to check `.env` file or re-run the installer |
| "No Products/Services found" (on create invoice) | "QuickBooks needs at least one product or service before invoices can be created." | Tell the user to open QuickBooks Online → Sales → Products and Services → New, then try again |
| "Invoice not found" | "I couldn't find that invoice. Let me search for it." | Try `quickbooks_list_invoices` instead |
| "invalid_client" or "invalid_grant" | "Your QuickBooks credentials don't match the environment. Let's reconnect." | Confirm `.env` `QUICKBOOKS_ENVIRONMENT` matches the tab the credentials were copied from (Development vs Production), then run `npm run auth` |
| Any other QuickBooks API error | "Something went wrong with QuickBooks. Let me try again." | Retry once, then suggest `npm run auth` |

---

## Scope Limitations

The QuickBooks connector **can** do:
- Read and create invoices (accounts receivable)
- Read and create customers
- Read chart of accounts
- Read bank transactions (purchases and deposits)
- Read customer payments
- Read Profit & Loss reports
- Read Balance Sheet reports
- Read company information

The QuickBooks connector **cannot** do:
- Access payroll or employee data
- Access QuickBooks Payments processing
- Access attachments or file uploads
- Delete, void, or send invoices by email (user does this in QuickBooks)
- Create bank transactions, reconcile accounts, or match bank feeds
- Manage tax rates, sales tax, or tax returns
- Access classes, locations, or custom fields
- Access multiple QuickBooks companies simultaneously (connected to one realm at a time)
- **Create an invoice without an existing Product/Service Item** — QuickBooks requires at least one Item in the company before any invoice can be created. The connector auto-picks the first available Item; if none exist, the user must create one first in QuickBooks.

---

## Behaviour Guidelines

- **Always confirm before creating** — when creating invoices or customers, summarise what you are about to create and confirm with the user before calling the tool.
- **Invoices are saved as pending, not emailed** — never imply an invoice has been sent. Say "I've saved the invoice in QuickBooks — review and send it from QuickBooks when ready."
- **Customer auto-creation** — when using `quickbooks_create_invoice` for a new customer, tell the user a new customer was created alongside the invoice, so they can add email/phone details afterwards if needed.
- **Format currency correctly** — use the currency from the QuickBooks response and format amounts with 2 decimal places.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as a readable table, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Sandbox vs production awareness** — if the user mentions real financial decisions and the environment is `sandbox`, remind them they are looking at test data, not real figures.
- **Token errors** → tell the user to run `npm run auth` in the quickbooks-connector folder.
- **Never log or echo credentials** — Client ID, Client Secret, realmId, and tokens must never appear in output.

---

## Related Skills

- **systematic-debugging**: For troubleshooting QuickBooks auth or API errors
- **connector-recommender**: For recommending which connectors to set up
- **xero-connector**: Sibling accounting connector — same MCP pattern for Xero users
