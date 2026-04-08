---
name: shopify-connector
description: Install and operate the Shopify connector. Use this skill when the user asks to set up Shopify, connect their online store, or interact with products, orders, customers, or inventory. Handles full installation and uses the Shopify CLI + Admin API.
allowed-tools: Bash,Read,Write,Edit
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

The connector uses the **Shopify CLI** (`@shopify/cli`) for authentication and store selection, then the **Shopify Admin GraphQL API** for all store operations.

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
npm install -g @shopify/cli @shopify/theme
```

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

### Step 4: Authenticate
```bash
shopify auth login
```

This opens a browser. The user signs in to their Shopify Partner account or store admin. Wait for the success message before proceeding.

> If the browser does not open, copy the URL from the terminal output and paste it into a browser manually.

### Step 5: Select the store

After login, connect to the specific store:
```bash
shopify auth login --store your-store-name.myshopify.com
```

Replace `your-store-name` with the user's actual store subdomain (the part before `.myshopify.com`).

### Step 6: Verify

```bash
shopify store info
```

If store details appear, the connector is working.

---

## Part 2 — Products

All store operations use the Shopify Admin GraphQL API via `shopify app function run` or direct API calls. The recommended approach is using `curl` with the store's Admin API access token, or the Shopify CLI's built-in GraphQL console.

### Using the GraphQL console
```bash
shopify admin graphql --query '{ products(first: 5) { edges { node { id title status } } } }'
```

> **Note:** If `shopify admin graphql` is not available in your CLI version, use curl with the Admin API directly (see "Direct API Access" section below).

### List products
```graphql
{
  products(first: 10) {
    edges {
      node {
        id
        title
        status
        productType
        vendor
        totalInventory
        variants(first: 5) {
          edges {
            node {
              id
              title
              price
              sku
              inventoryQuantity
            }
          }
        }
      }
    }
  }
}
```

### Search products by title
```graphql
{
  products(first: 10, query: "title:*sneaker*") {
    edges {
      node {
        id
        title
        status
        totalInventory
      }
    }
  }
}
```

### Get a single product
```graphql
{
  product(id: "gid://shopify/Product/<PRODUCT_ID>") {
    id
    title
    descriptionHtml
    status
    productType
    vendor
    tags
    totalInventory
    variants(first: 10) {
      edges {
        node {
          id
          title
          price
          sku
          inventoryQuantity
        }
      }
    }
    images(first: 5) {
      edges {
        node {
          url
          altText
        }
      }
    }
  }
}
```

### Create a product
```graphql
mutation {
  productCreate(input: {
    title: "New Product"
    productType: "Shirts"
    vendor: "My Brand"
    descriptionHtml: "<p>Product description here</p>"
    tags: ["new", "summer"]
    status: DRAFT
  }) {
    product {
      id
      title
    }
    userErrors {
      field
      message
    }
  }
}
```
> Always confirm product details with the user before creating.

### Update a product
```graphql
mutation {
  productUpdate(input: {
    id: "gid://shopify/Product/<PRODUCT_ID>"
    title: "Updated Product Title"
    status: ACTIVE
  }) {
    product {
      id
      title
      status
    }
    userErrors {
      field
      message
    }
  }
}
```

---

## Part 3 — Orders

### List recent orders
```graphql
{
  orders(first: 10, sortKey: CREATED_AT, reverse: true) {
    edges {
      node {
        id
        name
        createdAt
        displayFinancialStatus
        displayFulfillmentStatus
        totalPriceSet {
          shopMoney {
            amount
            currencyCode
          }
        }
        customer {
          displayName
          email
        }
      }
    }
  }
}
```

### Search orders by status
```graphql
{
  orders(first: 10, query: "fulfillment_status:unfulfilled") {
    edges {
      node {
        id
        name
        createdAt
        displayFulfillmentStatus
        totalPriceSet {
          shopMoney {
            amount
            currencyCode
          }
        }
        customer {
          displayName
        }
      }
    }
  }
}
```

### Get a single order
```graphql
{
  order(id: "gid://shopify/Order/<ORDER_ID>") {
    id
    name
    createdAt
    displayFinancialStatus
    displayFulfillmentStatus
    totalPriceSet {
      shopMoney {
        amount
        currencyCode
      }
    }
    customer {
      displayName
      email
    }
    lineItems(first: 20) {
      edges {
        node {
          title
          quantity
          originalUnitPriceSet {
            shopMoney {
              amount
            }
          }
          variant {
            sku
          }
        }
      }
    }
    shippingAddress {
      address1
      city
      province
      country
      zip
    }
  }
}
```

### Search orders by date range
```graphql
{
  orders(first: 20, query: "created_at:>2026-04-01 created_at:<2026-04-08") {
    edges {
      node {
        id
        name
        createdAt
        totalPriceSet {
          shopMoney {
            amount
            currencyCode
          }
        }
      }
    }
  }
}
```

---

## Part 4 — Customers

### List customers
```graphql
{
  customers(first: 10) {
    edges {
      node {
        id
        displayName
        email
        phone
        ordersCount
        totalSpent
        createdAt
      }
    }
  }
}
```

### Search customers
```graphql
{
  customers(first: 10, query: "email:*@example.com") {
    edges {
      node {
        id
        displayName
        email
        ordersCount
        totalSpent
      }
    }
  }
}
```

### Get a single customer
```graphql
{
  customer(id: "gid://shopify/Customer/<CUSTOMER_ID>") {
    id
    displayName
    email
    phone
    ordersCount
    totalSpent
    createdAt
    addresses {
      address1
      city
      province
      country
      zip
    }
    orders(first: 5) {
      edges {
        node {
          id
          name
          totalPriceSet {
            shopMoney {
              amount
            }
          }
        }
      }
    }
  }
}
```

### Create a customer
```graphql
mutation {
  customerCreate(input: {
    firstName: "Jane"
    lastName: "Doe"
    email: "jane@example.com"
    phone: "+61400000000"
    addresses: [{
      address1: "123 Main St"
      city: "Sydney"
      province: "NSW"
      country: "AU"
      zip: "2000"
    }]
  }) {
    customer {
      id
      displayName
      email
    }
    userErrors {
      field
      message
    }
  }
}
```
> Always confirm customer details with the user before creating.

---

## Part 5 — Inventory

### List inventory levels for a product variant
```graphql
{
  inventoryItem(id: "gid://shopify/InventoryItem/<ITEM_ID>") {
    id
    sku
    tracked
    inventoryLevels(first: 10) {
      edges {
        node {
          id
          available
          location {
            name
          }
        }
      }
    }
  }
}
```

### List all locations
```graphql
{
  locations(first: 10) {
    edges {
      node {
        id
        name
        isActive
        address {
          address1
          city
          province
          country
        }
      }
    }
  }
}
```

### Adjust inventory quantity
```graphql
mutation {
  inventoryAdjustQuantities(input: {
    reason: "correction"
    name: "available"
    changes: [{
      delta: 10
      inventoryItemId: "gid://shopify/InventoryItem/<ITEM_ID>"
      locationId: "gid://shopify/Location/<LOCATION_ID>"
    }]
  }) {
    inventoryAdjustmentGroup {
      reason
      changes(first: 5) {
        edges {
          node {
            name
            delta
          }
        }
      }
    }
    userErrors {
      field
      message
    }
  }
}
```
> Always confirm inventory adjustments with the user before executing. Get the inventoryItemId from a product variant query and locationId from the locations query.

### Check low stock items
```graphql
{
  products(first: 50, query: "inventory_total:<10") {
    edges {
      node {
        id
        title
        totalInventory
        variants(first: 5) {
          edges {
            node {
              title
              sku
              inventoryQuantity
            }
          }
        }
      }
    }
  }
}
```

---

## Part 6 — Direct API Access

If the Shopify CLI's GraphQL console is unavailable, use `curl` with the Admin API directly.

### Step 1: Get the access token

The user needs a Shopify Admin API access token. Two ways to get one:

**Option A — Custom app (recommended for production):**
1. In Shopify Admin, go to Settings > Apps and sales channels > Develop apps
2. Create app > Configure Admin API scopes (select: `read_products`, `write_products`, `read_orders`, `write_orders`, `read_customers`, `write_customers`, `read_inventory`, `write_inventory`)
3. Install app > Reveal Admin API access token
4. Save the token securely

**Option B — Shopify CLI session token:**
If already authenticated via `shopify auth login`, the CLI manages tokens internally.

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
# Check current auth status
shopify auth login

# Switch store
shopify auth login --store different-store.myshopify.com

# Log out
shopify auth logout
```

---

## Behaviour Guidelines

- **Always verify auth first** at the start of a session — run `shopify version` and check store connection.
- **Confirm before acting** — always confirm with the user before creating products, adjusting inventory, or modifying orders.
- **Use GraphQL IDs** — Shopify uses global IDs like `gid://shopify/Product/12345`. Always get IDs from list/search queries first.
- **Pagination** — use `first: N` and `after: cursor` for paginated results. Default to 10 items unless the user asks for more.
- **Rate limits** — Shopify's Admin API has a cost-based rate limit. Avoid requesting too many nested fields in a single query. If you hit a rate limit, wait and retry.
- **Status values** — Products: ACTIVE, DRAFT, ARCHIVED. Orders financial: AUTHORIZED, PAID, PARTIALLY_PAID, PENDING, REFUNDED, VOIDED. Orders fulfillment: FULFILLED, UNFULFILLED, PARTIALLY_FULFILLED.
- **Currency** — always display amounts with the currency code from the response.
- **Auth errors** — if you get a 401 or "Unauthorized", re-run `shopify auth login --store <store>.myshopify.com`.
- **Missing scopes** — if you get a "scope" error, the custom app needs additional API permissions added in Shopify Admin > Settings > Apps.
