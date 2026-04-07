---
name: shopify
description: Shopify store management. Products, orders, customers, inventory, variants, tags, fulfillment, and refunds via MCP.
---

# Shopify Store Management Skill

You are managing a Shopify store via the `shopify-mcp` MCP server.

## Access Method

### MCP Server (Preferred)
The `shopify-mcp` MCP server provides 31 tools for store management.

**MCP server name:** `shopify`

Use `ToolSearch: +shopify` to find and load available tools.

### Store Details
- **Store Domain**: `<STORE>.myshopify.com` (from secrets)
- **Access Token**: In `~/.claude/projects/-Users-<username>/secrets/shopify.env`

## Available Tools (31)

### Products
| Tool | What It Does |
|---|---|
| `get_products` | List/search products (paginated) |
| `get_product` | Get single product by ID |
| `create_product` | Create new product |
| `update_product` | Update product fields (title, description, price, etc.) |
| `delete_product` | Delete a product |
| `get_product_variants` | List variants for a product |
| `create_product_variant` | Add variant (size, color, etc.) |
| `update_product_variant` | Update variant details |
| `delete_product_variant` | Remove a variant |

### Customers
| Tool | What It Does |
|---|---|
| `get_customers` | List/search customers |
| `get_customer` | Get single customer by ID |
| `create_customer` | Create new customer |
| `update_customer` | Update customer fields |
| `merge_customers` | Merge duplicate customers |
| `get_customer_addresses` | List customer addresses |

### Orders
| Tool | What It Does |
|---|---|
| `get_orders` | List/search orders (filter by status, date, etc.) |
| `get_order` | Get single order by ID |
| `update_order` | Update order fields |
| `cancel_order` | Cancel an open order |
| `close_order` | Close/archive an order |
| `create_fulfillment` | Fulfill an order (mark as shipped) |
| `create_refund` | Issue a refund |
| `get_draft_orders` | List draft orders |
| `create_draft_order` | Create a draft order |

### Inventory & Tags
| Tool | What It Does |
|---|---|
| `get_inventory_levels` | Check stock quantities |
| `update_inventory_quantity` | Adjust stock levels |
| `get_metafields` | Read custom data fields |
| `create_metafield` | Add custom data to products/customers/orders |
| `add_tags` | Add tags to products/customers/orders |
| `remove_tags` | Remove tags |

## API Quirks

### Pagination
- Most list endpoints return max 50 items per page
- Use `pageInfo` cursor for pagination, not page numbers
- Always check `hasNextPage` before requesting more

### Product Prices
- Prices are set on **variants**, not on the product itself
- A product with no variants has a default variant that holds the price
- To update price: update the variant, not the product

### Order Status
- `open` — unfulfilled, payment captured
- `closed` — fulfilled and completed
- `cancelled` — cancelled by store or customer
- Filter orders by `status`, `financial_status`, `fulfillment_status`

### Rate Limits
- Shopify uses a leaky bucket algorithm
- 2 requests/second for standard plans
- If you get 429 errors, wait 1 second and retry

### IDs
- All Shopify IDs are numeric (not UUIDs)
- Product IDs, variant IDs, order IDs, customer IDs are all large integers

## Common Operations

### Search products
```
Find products matching "fire extinguisher"
→ get_products with query parameter
```

### Update a product price
```
1. get_product → find the product
2. get_product_variants → find the variant
3. update_product_variant → set new price
```

### Check order status
```
get_orders with status filter
→ returns list with financial and fulfillment status
```

### Adjust inventory
```
1. get_inventory_levels for the product variant
2. update_inventory_quantity with adjustment amount
```

### Create a simple product
```
create_product with:
  title, description, product_type, vendor
  variants: [{ price, sku, inventory_quantity }]
```

## Safety Rules

1. **NEVER delete products without explicit approval** — deletions are permanent
2. **NEVER cancel orders without approval** — this triggers refunds
3. **NEVER issue refunds without approval** — money leaves the account
4. **Always confirm product details** before creating (title, price, description)
5. **Always confirm quantities** before adjusting inventory
6. **Tag products/orders** when performing bulk actions for traceability
