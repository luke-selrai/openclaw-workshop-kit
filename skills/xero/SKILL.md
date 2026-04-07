---
name: xero
description: Xero accounting management. Invoices, contacts, bank transactions, payments, payroll, and financial reporting via official MCP.
---

# Xero Accounting Skill

You are managing Xero accounting via the official `@xeroapi/xero-mcp-server` MCP server.

## Access Method

### MCP Server
The official Xero MCP server provides 50+ tools for accounting and payroll.

**MCP server name:** `xero`

Use `ToolSearch: +xero` to find and load available tools.

### Credentials
- **Client ID**: In `~/.claude/projects/-Users-<username>/secrets/xero.env`
- **Client Secret**: In the same file
- Auth type: OAuth2 Custom Connection

## Available Tools (50+)

### Invoices & Quotes
| Tool | What It Does |
|---|---|
| `xero_list_invoices` | List/filter invoices (by status, date, contact) |
| `xero_create_invoice` | Create new sales invoice |
| `xero_update_invoice` | Update invoice details |
| `xero_list_quotes` | List quotes |
| `xero_create_quote` | Create new quote |
| `xero_update_quote` | Update quote details |
| `xero_list_credit_notes` | List credit notes |
| `xero_create_credit_note` | Create credit note |
| `xero_update_credit_note` | Update credit note |

### Contacts
| Tool | What It Does |
|---|---|
| `xero_list_contacts` | List/search contacts (customers and suppliers) |
| `xero_create_contact` | Create new contact |
| `xero_update_contact` | Update contact details |
| `xero_list_contact_groups` | List contact groups |

### Payments & Banking
| Tool | What It Does |
|---|---|
| `xero_list_payments` | List payments |
| `xero_create_payment` | Record a payment against an invoice |
| `xero_list_bank_transactions` | List bank transactions |
| `xero_create_bank_transaction` | Create bank transaction (spend/receive money) |
| `xero_update_bank_transaction` | Update bank transaction |

### Accounts & Items
| Tool | What It Does |
|---|---|
| `xero_list_accounts` | List chart of accounts |
| `xero_list_items` | List inventory/service items |
| `xero_create_item` | Create new item |
| `xero_update_item` | Update item details |
| `xero_list_tax_rates` | List tax rates |

### Reporting
| Tool | What It Does |
|---|---|
| `xero_get_profit_and_loss` | Profit & Loss report |
| `xero_get_balance_sheet` | Balance Sheet report |
| `xero_get_trial_balance` | Trial Balance report |
| `xero_get_aged_receivables` | Aged Receivables (who owes you) |
| `xero_get_aged_payables` | Aged Payables (who you owe) |
| `xero_get_organisation` | Organisation details |

### Payroll
| Tool | What It Does |
|---|---|
| `xero_list_payroll_employees` | List employees |
| `xero_list_leave_records` | List leave records |
| `xero_list_timesheets` | List timesheets |
| `xero_create_timesheet` | Create timesheet |
| `xero_approve_timesheet` | Approve timesheet |
| `xero_revert_timesheet` | Revert timesheet to draft |
| `xero_update_timesheet_line` | Update timesheet line |

### Other
| Tool | What It Does |
|---|---|
| `xero_list_manual_journals` | List manual journals |
| `xero_create_manual_journal` | Create manual journal |
| `xero_update_manual_journal` | Update manual journal |
| `xero_list_tracking_categories` | List tracking categories |
| `xero_create_tracking_category` | Create tracking category |
| `xero_update_tracking_category` | Update tracking category |

## API Quirks

### Date Format
- All dates use ISO 8601: `2026-04-02T00:00:00`
- For filtering by date range, use `where` parameter with date comparisons

### Invoice Status
- `DRAFT` — not yet approved or sent
- `SUBMITTED` — awaiting approval
- `AUTHORISED` — approved, sent to customer
- `PAID` — fully paid
- `VOIDED` — cancelled

### Pagination
- Default page size: 100
- Use `page` parameter (1-based) for pagination
- Check if results count equals 100 to know if there are more pages

### Amounts
- All amounts are in the organisation's base currency
- Tax-inclusive or tax-exclusive depends on the organisation setting
- Always specify `lineAmountTypes`: `Inclusive`, `Exclusive`, or `NoTax`

### Contact Types
- Contacts can be both customers AND suppliers
- Filter by `isCustomer: true` or `isSupplier: true`

### Rate Limits
- 60 calls per minute per connection
- Daily limit: 5000 calls
- If you get 429, wait 60 seconds

## Common Operations

### List unpaid invoices
```
xero_list_invoices with status: "AUTHORISED"
→ returns all approved but unpaid invoices
```

### Create an invoice
```
xero_create_invoice with:
  contactId, lineItems (description, quantity, unitAmount, accountCode),
  date, dueDate, lineAmountTypes: "Exclusive"
```

### Find a contact
```
xero_list_contacts with searchTerm: "John Smith"
```

### Get P&L report
```
xero_get_profit_and_loss with fromDate, toDate
```

### Record a payment
```
xero_create_payment with:
  invoiceId, accountId (bank account), amount, date
```

### Check who owes you money
```
xero_get_aged_receivables
→ shows all outstanding amounts by contact and age
```

### Create a bank transaction (spend money)
```
xero_create_bank_transaction with:
  type: "SPEND", contactId, bankAccountId,
  lineItems (description, quantity, unitAmount, accountCode)
```

## Safety Rules

1. **NEVER void or delete invoices without explicit approval** — voiding affects financial records
2. **NEVER create payments without confirming the amount** — money is being allocated
3. **NEVER modify bank transactions that are reconciled** — this breaks the reconciliation
4. **Always confirm invoice details** before creating (contact, amount, line items)
5. **Always use DRAFT status** for new invoices unless the user explicitly says to approve them
6. **Never approve timesheets without user confirmation** — this affects payroll
