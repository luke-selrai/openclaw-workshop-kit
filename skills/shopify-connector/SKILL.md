---
name: shopify-connector
description: Install and operate the Shopify connector. Use this skill when the user asks to set up Shopify, connect their online store, or interact with products, orders, customers, or inventory. Handles full installation and uses the Shopify CLI + Admin API.
metadata:
  category: Ecommerce & Integrations
  tags:
    - shopify
    - ecommerce
    - products
    - orders
    - customers
    - inventory
    - online-store
  pairs-with:
    - skill: email-composer
      reason: Compose email content for customer communication, then send via Gmail connector
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by Shopify events (new order, low stock, etc.)
---

# Shopify Connector

## Overview

This skill does two things:
1. **Installs** the Shopify CLI on the user's computer (one-time setup)
2. **Operates** the connector — querying products, orders, customers, and inventory via the Shopify Admin API

The connector uses the **Shopify CLI** (`@shopify/cli`) for authentication and store queries via `shopify store auth` and `shopify store execute`.

> **Account support:** Requires a Shopify store with staff/owner access.
> Development stores, Partner stores, and live stores are all supported.

---

## Part 1 — Installation

### Step 1: Check if already installed
```bash
shopify version
```
If this returns a version number, skip to Step 4 (auth check). If "command not found", continue from Step 2.

### Step 2: Check Node.js
```bash
node --version
```
Needs v18 or higher. If missing or too old, tell the user to install from https://nodejs.org (LTS version) before continuing.

### Step 3: Install the CLI

```bash
npm install -g @shopify/cli
```

> **Note:** `@shopify/theme` is bundled inside `@shopify/cli` since v3.59.0 — no need to install it separately.

After install, refresh PATH so the command is available immediately:

**Mac/Linux:**
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```
**Windows (Command Prompt):**
```bat
for /f "tokens=*" %i in ('npm prefix -g') do set PATH=%i\bin;%PATH%
```

Verify:
```bash
shopify version
```

### Step 4: Log in to Shopify

```bash
shopify auth login
```

This opens a browser. The user signs in to their Shopify Partner account or organization. Wait for the success message before proceeding.

> If the browser does not open, copy the URL from the terminal output and paste it into a browser manually.

### Step 5: Authenticate against the store

After login, authenticate with the specific store and request the required API scopes:

```bash
shopify store auth \
  --store your-store-name.myshopify.com \
  --scopes read_products,write_products,read_orders,write_orders,read_customers,write_customers,read_inventory,write_inventory
```

Replace `your-store-name` with the user's actual store subdomain (the part before `.myshopify.com`).

This opens a browser for the user to approve the requested scopes. An access token is stored locally for reuse.

> **To add scopes later**, re-run this command with the additional scopes included.

### Step 6: Verify

```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query "{ shop { name email myshopifyDomain } }"
```

If the store name and email appear, the connector is working.

---

## Part 2 — Products

All store operations use `shopify store execute` which runs Admin API GraphQL queries against the authenticated store.

### List products
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query "{ products(first: 10) { edges { node { id title status productType vendor totalInventory variants(first: 5) { edges { node { id title price sku inventoryQuantity } } } } } } }"
```

### Search products by title
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ products(first: 10, query: "title:*sneaker*") { edges { node { id title status totalInventory } } } }'
```

### Get a single product
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ product(id: "gid://shopify/Product/<PRODUCT_ID>") { id title descriptionHtml status productType vendor tags totalInventory variants(first: 10) { edges { node { id title price sku inventoryQuantity } } } images(first: 5) { edges { node { url altText } } } } }'
```

### Create a product
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --allow-mutations \
  --query 'mutation { productCreate(input: { title: "New Product", productType: "Shirts", vendor: "My Brand", descriptionHtml: "<p>Product description here</p>", tags: ["new", "summer"], status: DRAFT }) { product { id title } userErrors { field message } } }'
```
> Always confirm product details with the user before creating.

### Update a product
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --allow-mutations \
  --query 'mutation { productUpdate(input: { id: "gid://shopify/Product/<PRODUCT_ID>", title: "Updated Product Title", status: ACTIVE }) { product { id title status } userErrors { field message } } }'
```

> **For complex queries**, use the `--query-file` flag to load from a `.graphql` file instead of inline:
> ```bash
> shopify store execute \
>   --store your-store-name.myshopify.com \
>   --query-file ./query.graphql \
>   --variables '{"id": "gid://shopify/Product/12345"}'
> ```

---

## Part 3 — Orders

### List recent orders
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query "{ orders(first: 10, sortKey: CREATED_AT, reverse: true) { edges { node { id name createdAt displayFinancialStatus displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName email } } } } }"
```

### Search orders by status
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ orders(first: 10, query: "fulfillment_status:unfulfilled") { edges { node { id name createdAt displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName } } } } }'
```

### Get a single order
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ order(id: "gid://shopify/Order/<ORDER_ID>") { id name createdAt displayFinancialStatus displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName email } lineItems(first: 20) { edges { node { title quantity originalUnitPriceSet { shopMoney { amount } } variant { sku } } } } shippingAddress { address1 city province country zip } } }'
```

### Search orders by date range
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ orders(first: 20, query: "created_at:>2026-04-01 created_at:<2026-04-08") { edges { node { id name createdAt totalPriceSet { shopMoney { amount currencyCode } } } } } }'
```

---

## Part 4 — Customers

### List customers
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query "{ customers(first: 10) { edges { node { id displayName email phone ordersCount totalSpent createdAt } } } }"
```

### Search customers
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ customers(first: 10, query: "email:*@example.com") { edges { node { id displayName email ordersCount totalSpent } } } }'
```

### Get a single customer
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ customer(id: "gid://shopify/Customer/<CUSTOMER_ID>") { id displayName email phone ordersCount totalSpent createdAt addresses { address1 city province country zip } orders(first: 5) { edges { node { id name totalPriceSet { shopMoney { amount } } } } } } }'
```

### Create a customer
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --allow-mutations \
  --query 'mutation { customerCreate(input: { firstName: "Jane", lastName: "Doe", email: "jane@example.com", phone: "+61400000000", addresses: [{ address1: "123 Main St", city: "Sydney", province: "NSW", country: "AU", zip: "2000" }] }) { customer { id displayName email } userErrors { field message } } }'
```
> Always confirm customer details with the user before creating.

---

## Part 5 — Inventory

### List inventory levels for a product variant
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ inventoryItem(id: "gid://shopify/InventoryItem/<ITEM_ID>") { id sku tracked inventoryLevels(first: 10) { edges { node { id available location { name } } } } } }'
```

### List all locations
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query "{ locations(first: 10) { edges { node { id name isActive address { address1 city province country } } } } }"
```

### Adjust inventory quantity
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --allow-mutations \
  --query 'mutation { inventoryAdjustQuantities(input: { reason: "correction", name: "available", changes: [{ delta: 10, inventoryItemId: "gid://shopify/InventoryItem/<ITEM_ID>", locationId: "gid://shopify/Location/<LOCATION_ID>" }] }) { inventoryAdjustmentGroup { reason changes(first: 5) { edges { node { name delta } } } } userErrors { field message } } }'
```
> Always confirm inventory adjustments with the user before executing. Get the inventoryItemId from a product variant query and locationId from the locations query.

### Check low stock items
```bash
shopify store execute \
  --store your-store-name.myshopify.com \
  --query '{ products(first: 50, query: "inventory_total:<10") { edges { node { id title totalInventory variants(first: 5) { edges { node { title sku inventoryQuantity } } } } } } }'
```

---

## Part 6 — Direct API Access (curl fallback)

If the Shopify CLI is unavailable or you prefer direct API calls, use `curl` with a Custom App access token.

### Step 1: Get the access token

The user needs a Shopify Admin API access token via a Custom App:

1. In Shopify Admin, go to Settings > Apps and sales channels > Develop apps
2. Create app > Configure Admin API scopes (select: `read_products`, `write_products`, `read_orders`, `write_orders`, `read_customers`, `write_customers`, `read_inventory`, `write_inventory`)
3. Install app > Reveal Admin API access token
4. Save the token securely

### Step 2: Make API calls

```bash
SHOPIFY_STORE="your-store-name.myshopify.com"
SHOPIFY_TOKEN="shpat_xxxxxxxxxxxxxxxxxxxxx"

curl -s -X POST \
  "https://${SHOPIFY_STORE}/admin/api/2025-01/graphql.json" \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Access-Token: ${SHOPIFY_TOKEN}" \
  -d '{"query": "{ shop { name email myshopifyDomain } }"}'
```

> Store the token in an environment variable, never hardcode it in scripts.

---

## Part 7 — Auth & Session

```bash
# Log in to Shopify Partner/org account
shopify auth login

# Authenticate against a specific store with scopes
shopify store auth --store your-store-name.myshopify.com \
  --scopes read_products,write_products,read_orders,read_customers,read_inventory

# Re-authenticate with additional scopes
shopify store auth --store your-store-name.myshopify.com \
  --scopes read_products,write_products,read_orders,write_orders,read_customers,write_customers,read_inventory,write_inventory

# Log out
shopify auth logout
```

---

## Behaviour Guidelines

- **Always verify auth first** at the start of a session — run `shopify version` and test with `shopify store execute --store <store> --query "{ shop { name } }"`.
- **Confirm before acting** — always confirm with the user before creating products, adjusting inventory, or modifying orders.
- **Use `--allow-mutations`** — all mutation queries require the `--allow-mutations` flag on `shopify store execute`. Without it, mutations are silently blocked.
- **Use `--query-file` for complex queries** — long inline queries are hard to read. Save the query to a `.graphql` file and use `--query-file ./file.graphql` with `--variables '{"key": "value"}'`.
- **Use GraphQL IDs** — Shopify uses global IDs like `gid://shopify/Product/12345`. Always get IDs from list/search queries first.
- **Pagination** — use `first: N` and `after: cursor` for paginated results. Default to 10 items unless the user asks for more.
- **Rate limits** — Shopify's Admin API has a cost-based rate limit. Avoid requesting too many nested fields in a single query. If you hit a rate limit, wait and retry.
- **Status values** — Products: ACTIVE, DRAFT, ARCHIVED. Orders financial: AUTHORIZED, PAID, PARTIALLY_PAID, PENDING, REFUNDED, VOIDED. Orders fulfillment: FULFILLED, UNFULFILLED, PARTIALLY_FULFILLED.
- **Currency** — always display amounts with the currency code from the response.
- **Auth errors** — if you get a 401 or "Unauthorized", re-run `shopify store auth --store <store>.myshopify.com --scopes <scopes>`.
- **Missing scopes** — if you get a scope error, re-run `shopify store auth` with the missing scopes added to the `--scopes` list.
- **JSON output** — add `--json` to any `shopify store execute` command for structured JSON output, useful for piping to other tools.
