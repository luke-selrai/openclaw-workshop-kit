---
name: quickbooks
description: QuickBooks Online accounting. Invoices, customers, vendors, estimates, bills, expenses, and journal entries via official Intuit MCP.
---

# QuickBooks Online Skill

You are managing QuickBooks Online via the official `quickbooks-online-mcp-server` by Intuit.

## Access Method

### MCP Server
The official QuickBooks MCP server provides CRUD operations for 11 entity types.

**MCP server name:** `quickbooks`

Use `ToolSearch: +quickbooks` to find and load available tools.

### Credentials
- **Client ID**: In `~/.claude/projects/-Users-<username>/secrets/quickbooks.env`
- **Client Secret**: In the same file
- Auth type: Intuit OAuth (automatic browser-based flow)

## Available Operations

### Invoices
- List invoices (filter by status, date, customer)
- Get invoice by ID
- Create invoice (customer, line items, due date)
- Update invoice
- Send invoice via email

### Customers
- List customers (search by name, email)
- Get customer by ID
- Create customer (name, email, phone, address)
- Update customer details

### Vendors (Suppliers)
- List vendors
- Get vendor by ID
- Create vendor
- Update vendor

### Estimates (Quotes)
- List estimates
- Get estimate by ID
- Create estimate
- Update estimate

### Bills (Money You Owe)
- List bills
- Get bill by ID
- Create bill
- Update bill

### Bill Payments
- List bill payments
- Create bill payment (pay a bill)

### Items (Products/Services)
- List items
- Get item by ID
- Create item
- Update item

### Employees
- List employees
- Get employee by ID

### Purchases (Expenses)
- List purchases
- Create purchase (record an expense)

### Journal Entries
- List journal entries
- Create journal entry

### Accounts (Chart of Accounts)
- List accounts
- Get account by ID

## API Quirks

### OAuth Authentication
- First time: browser opens for Intuit login and approval
- After that: token refreshes automatically
- If token expires after 100 days of inactivity, re-authenticate

### Amounts
- All amounts are in the company's home currency
- Decimals are supported (e.g., 149.99)
- Tax handling depends on company settings

### Pagination
- Default page size: 100
- Use `startPosition` and `maxResults` for pagination
- startPosition is 1-based

### Query Language
- QuickBooks uses a SQL-like query language for filtering
- Example: `SELECT * FROM Invoice WHERE Balance > '0' AND TxnDate > '2026-01-01'`

### Entity References
- Related entities use `Ref` objects: `{ value: "123", name: "Customer Name" }`
- When creating, you only need the `value` (ID), name is optional

## Common Operations

### List unpaid invoices
```
List invoices where Balance > 0
Display: customer name, amount, due date, days overdue
```

### Create an invoice
```
1. Find or create the customer
2. Create invoice with:
   - CustomerRef (customer ID)
   - Line items (Description, Amount, DetailType: "SalesItemLineDetail")
   - DueDate
```

### Record an expense
```
Create purchase with:
- AccountRef (expense account)
- PaymentType: "Cash" or "Check" or "CreditCard"
- Line items (description, amount, account)
```

### Find a customer
```
List customers with displayName filter
```

### Create an estimate (quote)
```
Similar to invoice but entity type is Estimate
Can be converted to invoice later
```

## Safety Rules

1. **NEVER delete invoices or bills without approval** — affects financial records
2. **NEVER create payments without confirming amounts** — allocates real money
3. **NEVER modify closed-period transactions** — affects tax reporting
4. **Always confirm line items and amounts** before creating invoices
5. **Use estimates (quotes) first** when the user is unsure about pricing
6. **Always specify the correct account** for expenses and journal entries
