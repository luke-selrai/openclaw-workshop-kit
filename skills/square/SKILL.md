---
name: square
description: Square POS and payments. Orders, customers, catalog, invoices, bookings, inventory, loyalty, subscriptions, and team management via official MCP.
---

# Square POS & Payments Skill

You are managing Square via the official `square-mcp-server`.

## Access Method

### MCP Server
The official Square MCP server provides 40+ services covering payments, orders, catalog, and more.

**MCP server name:** `square`

Use `ToolSearch: +square` to find and load available tools.

### Credentials
- **Access Token**: In `~/.claude/projects/-Users-<username>/secrets/square.env`
- Get from: developer.squareup.com > Applications > Credentials

## Key Services (40+)

### Payments & Orders
| Service | What It Does |
|---|---|
| Payments | List, get, and manage payment transactions |
| Orders | Create, search, and manage orders |
| Refunds | Issue full or partial refunds |
| Checkout | Create payment links and checkout URLs |
| Invoices | Create and manage invoices |
| Disputes | View and manage payment disputes |
| Payouts | View payout history and details |

### Customers
| Service | What It Does |
|---|---|
| Customers | CRUD operations for customer records |
| Customer Groups | Manage customer segments |
| Customer Segments | Filter customers by criteria |

### Catalog & Inventory
| Service | What It Does |
|---|---|
| Catalog | Manage items, categories, taxes, discounts, modifiers |
| Inventory | Track and adjust stock levels |

### Bookings & Appointments
| Service | What It Does |
|---|---|
| Bookings | Manage appointment bookings |
| Locations | List and manage business locations |

### Loyalty & Gift Cards
| Service | What It Does |
|---|---|
| Loyalty | Manage loyalty programs and rewards |
| Gift Cards | Create and manage gift cards |

### Team & Labour
| Service | What It Does |
|---|---|
| Team | Manage team members |
| Labor | Track shifts, breaks, and wages |

### Subscriptions
| Service | What It Does |
|---|---|
| Subscriptions | Manage recurring billing |

## API Quirks

### Amounts Are in Cents
- Like Stripe, Square uses smallest currency unit
- $10.00 = `1000` cents
- Always divide by 100 when displaying
- Currency is an object: `{ amount: 1000, currency: "AUD" }`

### Location-Based
- Most operations require a `location_id`
- List locations first to get the right ID
- A business can have multiple locations

### Idempotency Keys
- Create operations require an `idempotency_key` (unique string)
- This prevents duplicate transactions if a request is retried
- Use a UUID or timestamp-based key

### Pagination
- Uses cursor-based pagination
- Check `cursor` in the response for next page
- Default page size varies by endpoint

### Catalog IDs
- Catalog objects use string IDs prefixed with type
- Items, variations, categories, taxes, discounts all live in the catalog
- An "item" contains one or more "variations" (like sizes/options)

### Timestamps
- All timestamps are RFC 3339 format: `2026-04-02T10:30:00Z`
- Timezone is always UTC in the API

## Common Operations

### Check today's orders
```
Search orders with date filter >= today
Filter by location_id
Returns: order total, items, payment status
```

### Look up a customer
```
Search customers by name, email, or phone
Returns: name, email, phone, creation date, visit count
```

### List catalog items
```
List catalog objects with type: "ITEM"
Returns: name, description, variations (with prices)
```

### Create a checkout link
```
1. Find or create catalog items
2. Create a checkout/payment link with line items
3. Share the URL
```

### Check inventory
```
Get inventory counts for specific catalog item variation IDs
Returns: quantity on hand by location
```

### View payouts
```
List payouts for a location
Returns: amount, status, arrival date
```

## Safety Rules

1. **NEVER issue refunds without explicit approval** — money leaves the account
2. **NEVER delete catalog items without approval** — affects active orders and reports
3. **NEVER cancel orders without approval** — triggers refund process
4. **Always confirm amounts before creating** — display in dollars not cents
5. **Always specify the correct location** — wrong location affects reporting
6. **Check inventory before adjusting** — avoid negative stock
