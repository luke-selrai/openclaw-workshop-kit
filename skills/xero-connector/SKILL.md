---
name: xero-connector
description: "Interact with Xero accounting data through MCP tools. Use this skill when the user asks about invoices, contacts, accounts, bank transactions, payments, profit and loss, balance sheet, or any Xero accounting data. Handles reading invoices, creating invoices, looking up contacts, adding contacts, viewing chart of accounts, listing bank transactions, listing payments, and pulling financial reports. Also use when the user mentions 'Xero,' 'my invoices,' 'profit and loss,' 'balance sheet,' 'unpaid invoices,' 'Xero contacts,' 'bank transactions,' 'chart of accounts,' or 'create an invoice.' For initial setup and installation, guide the user to run the installer at xero-connector/src/install.js."
allowed-tools: mcp__xero__*
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
    - skill: aws-connector
      reason: Similar pattern — MCP connector for an external service
---

# Xero Connector

## Overview

This skill uses the Xero MCP server to read and write accounting data in the user's Xero organisation. The connector must already be installed and authenticated before these tools work.

> **Not set up yet?** Tell the user to run the installer:
> `node /path/to/xero-connector/src/install.js`
> See `xero-connector/XERO-SETUP.md` for full instructions.

---

## Prerequisites

Before using any Xero tools, confirm:

1. **Connector is installed** — `xero-connector/node_modules/` exists
2. **Credentials are saved** — `xero-connector/.env` has real values (not placeholders)
3. **Token exists** — `xero-connector/.xero-token.json` exists and is not empty
4. **MCP server is configured** — `~/.claude.json` has a `"xero"` entry under `mcpServers`

If any of these are missing, guide the user to run the installer.

---

## Available Tools

### xero_get_organisation

Get the name and details of the connected Xero organisation.

**Use when:** The user asks "what Xero account am I connected to?" or you need to confirm the connection is working.

**Example:**
```
User: "What Xero org am I connected to?"
→ Call xero_get_organisation
→ "You're connected to Demo Company (AU)."
```

---

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

---

### xero_get_invoice

Get a specific invoice by its Xero ID or invoice number.

**Parameters:**
- `invoice_id` (required) — Xero invoice ID (UUID) or invoice number (e.g. INV-0001)

**Use when:** The user asks for details about a specific invoice, including line items, amounts, and tax.

**Example:**
```
User: "Show me invoice INV-0042"
→ Call xero_get_invoice with invoice_id: "INV-0042"
```

---

### xero_create_invoice

Create a new DRAFT invoice in Xero.

**Parameters:**
- `contact_name` (required) — Customer name
- `description` (required) — Line item description
- `unit_amount` (required) — Price per unit excluding tax
- `quantity` — Quantity (default: 1)
- `account_code` — Account code (e.g. 200 for Sales). Use `xero_list_accounts` to find codes.
- `due_date` — Due date in YYYY-MM-DD format
- `currency_code` — Currency: AUD, NZD, USD, etc.
- `reference` — Optional reference or PO number

**Use when:** The user asks to create, draft, or make an invoice.

**Important:** Always create as DRAFT. Never auto-approve invoices. Tell the user to review and approve in Xero.

**Example:**
```
User: "Create an invoice for Acme Corp for $500 for consulting"
→ Call xero_create_invoice with:
    contact_name: "Acme Corp"
    description: "Consulting services"
    unit_amount: 500
→ "I've created a draft invoice for Acme Corp for $500. 
   It's saved as a draft — review and approve it in Xero when ready."
```

**If you don't know the account code**, call `xero_list_accounts` first to find the right one, then create the invoice.

---

### xero_list_contacts

List contacts (customers and suppliers) in Xero.

**Parameters:**
- `search` — Search by name or email address
- `page` — Page number (100 contacts per page)

**Use when:** The user asks to find a customer, supplier, or contact.

**Example:**
```
User: "Find John Smith in my Xero contacts"
→ Call xero_list_contacts with search: "John Smith"
```

---

### xero_create_contact

Create a new contact (customer or supplier) in Xero.

**Parameters:**
- `name` (required) — Contact display name
- `email` — Email address
- `phone` — Phone number
- `is_customer` — Mark as customer (default: true)
- `is_supplier` — Mark as supplier

**Use when:** The user asks to add a new customer or supplier.

**Example:**
```
User: "Add a new contact called ABC Pty Ltd with email info@abc.com"
→ Call xero_create_contact with:
    name: "ABC Pty Ltd"
    email: "info@abc.com"
```

---

### xero_list_accounts

List the chart of accounts in Xero. Returns account codes and names.

**Parameters:**
- `type` — Filter by type: `BANK`, `CURRENT`, `EQUITY`, `EXPENSE`, `FIXED`, `LIABILITY`, `PREPAYMENT`, `REVENUE`, `SALES`, `TERMLIABILITY`

**Use when:** The user asks about their chart of accounts, or you need to find the right account code for creating an invoice.

**Examples:**
```
User: "List my Xero expense accounts"
→ Call xero_list_accounts with type: "EXPENSE"

User: "What account code should I use for sales?"
→ Call xero_list_accounts with type: "REVENUE"
```

---

### xero_list_banktx

List bank transactions in Xero.

**Parameters:**
- `page` — Page number (100 transactions per page)

**Use when:** The user asks about bank transactions, bank feeds, or money in/out.

**Example:**
```
User: "Show me my recent bank transactions in Xero"
→ Call xero_list_banktx
```

---

### xero_list_payments

List payments recorded in Xero against invoices or bills.

**Parameters:**
- `page` — Page number (100 payments per page)

**Use when:** The user asks about payments received or made.

**Example:**
```
User: "Show me recent payments in Xero"
→ Call xero_list_payments
```

---

### xero_get_profit_loss

Get the Profit and Loss (Income Statement) report.

**Parameters:**
- `from_date` — Start date YYYY-MM-DD (default: 1 Jan of current year)
- `to_date` — End date YYYY-MM-DD (default: today)

**Use when:** The user asks about income, expenses, net profit, or P&L.

**Examples:**
```
User: "Show me the P&L for this year"
→ Call xero_get_profit_loss (defaults to Jan 1 to today)

User: "What was my profit and loss for March?"
→ Call xero_get_profit_loss with from_date: "2026-03-01", to_date: "2026-03-31"
```

---

### xero_get_balance_sheet

Get the Balance Sheet report showing assets, liabilities, and equity.

**Parameters:**
- `date` — Report date YYYY-MM-DD (default: today)

**Use when:** The user asks about their balance sheet, assets, liabilities, or equity position.

**Example:**
```
User: "Get my balance sheet as of today"
→ Call xero_get_balance_sheet
```

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

---

## Error Handling

When a Xero tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| "Not authenticated with Xero" | "Your Xero connection needs to be set up. Let me help you." | Guide user to run `npm run auth` in the xero-connector folder |
| "Token expired and refresh failed" | "Your Xero session has expired. Let's reconnect." | Run `npm run auth` in the xero-connector folder |
| "No Xero organisations found" | "I can't find a Xero organisation on your account. Let's reconnect." | Run `npm run auth` and select an organisation |
| "Missing XERO_CLIENT_ID" | "Your Xero credentials are missing. Let's set them up." | Guide user to check `.env` file or re-run the installer |
| "Invoice not found" | "I couldn't find that invoice. Let me search for it." | Try `xero_list_invoices` with search instead |
| Any other Xero API error | "Something went wrong with Xero. Let me try again." | Retry once, then suggest `npm run auth` |

---

## Scope Limitations

The Xero connector **can** do:
- Read and create invoices (accounts receivable)
- Read and create contacts
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

## Behaviour Guidelines

- **Always confirm before creating** — when creating invoices or contacts, summarise what you are about to create and confirm with the user before calling the tool.
- **Invoices are always DRAFT** — never imply an invoice has been sent or approved. Say "I've created a draft invoice — review and approve it in Xero."
- **Format currency correctly** — use the currency from the Xero response (AUD, NZD, USD, etc.) and format amounts with 2 decimal places.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as a readable table, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Token errors** → tell the user to run `npm run auth` in the xero-connector folder.
- **Never log or echo credentials** — Client ID, Client Secret, and tokens must never appear in output.

---

## Related Skills

- **systematic-debugging**: For troubleshooting Xero auth or API errors
- **connector-recommender**: For recommending which connectors to set up
- **aws-connector**: Similar pattern — CLI connector for a cloud provider
- **azure-connector**: Similar pattern — CLI connector for a cloud provider
