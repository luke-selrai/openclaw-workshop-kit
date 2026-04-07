---
name: stripe
description: Stripe payment management. Customers, payments, subscriptions, invoices, refunds, payment links, and products via official MCP.
---

# Stripe Payments Skill

You are managing Stripe payments via the official `@stripe/mcp` MCP server.

## Access Method

### MCP Server
The official Stripe MCP server provides access to the full Stripe API. Tool availability is controlled by your Restricted API Key permissions.

**MCP server name:** `stripe`

Use `ToolSearch: +stripe` to find and load available tools.

### Credentials
- **Restricted API Key**: In `~/.claude/projects/-Users-<username>/secrets/stripe.env`
- Key format: starts with `rk_live_` or `rk_test_`
- NEVER use the Secret Key (sk_) — always use a Restricted Key for safety

## Key Operations

### Customers
- List customers (search by email, name)
- Create customer (email, name, description, metadata)
- Update customer details
- Delete customer (with approval only)

### Payments
- List payment intents (recent charges)
- Get payment details by ID
- List charges with filters (date, status, customer)

### Subscriptions
- List active subscriptions
- Get subscription details
- Cancel subscription (with approval only)

### Invoices
- List invoices (filter by customer, status, date)
- Create invoice for a customer
- Send invoice (finalise and email)
- Void invoice (with approval only)

### Payment Links
- Create payment link (one-time or recurring)
- List existing payment links
- Deactivate a payment link

### Products & Prices
- List products
- Create product (name, description)
- Create price for a product (amount, currency, recurring interval)
- Update product details

### Refunds
- Create refund (full or partial, with approval only)
- List refunds

## API Quirks

### Amounts Are in Cents
- Stripe uses the smallest currency unit
- $10.00 = `1000` (cents)
- Always divide by 100 when displaying to the user
- Always multiply by 100 when creating charges/invoices

### Currency
- Always lowercase: `aud`, `usd`, `gbp`, `eur`
- Default depends on the account's country

### Pagination
- Uses cursor-based pagination with `starting_after` parameter
- Default limit: 10, max: 100
- Use `has_more` to check for additional pages

### Date Filters
- Timestamps are Unix epoch (seconds since 1970)
- Use `created[gte]` and `created[lte]` for date ranges
- Example: `created[gte]: 1711929600` for after April 1 2026

### Test Mode vs Live Mode
- Keys starting with `rk_test_` only access test data
- Keys starting with `rk_live_` access real payments
- Always confirm with user which mode they want

### Restricted Key Permissions
- The MCP server can only do what the API key allows
- If a tool returns 403, the key needs more permissions
- Guide user to Stripe Dashboard > Developers > API Keys to update permissions

## Common Operations

### Check today's payments
```
List recent payment intents, filter by created date >= today
Display: amount (divide by 100), status, customer email
```

### Create a payment link
```
1. Create or find a product
2. Create a price (amount in cents, currency)
3. Create payment link with that price
4. Share the URL with the user
```

### Create an invoice
```
1. Find or create the customer
2. Create invoice for customer
3. Add invoice items (description, amount in cents)
4. Finalise invoice (changes status to "open")
5. Optionally: send invoice via email
```

### Look up a customer
```
List customers with email filter
→ returns customer object with payment history
```

### Issue a refund
```
1. Find the payment/charge by ID or customer
2. Confirm amount with user
3. Create refund (full or specify amount in cents)
```

## Safety Rules

1. **NEVER issue refunds without explicit approval** — money leaves the account immediately
2. **NEVER cancel subscriptions without approval** — affects recurring revenue
3. **NEVER void invoices without approval** — affects financial records
4. **Always confirm amounts before creating** — display in dollars, not cents
5. **Always use Restricted Keys** — never ask for or use the Secret Key
6. **Always clarify test vs live mode** — test mode charges are not real
7. **Never delete customers without approval** — deletes payment history
