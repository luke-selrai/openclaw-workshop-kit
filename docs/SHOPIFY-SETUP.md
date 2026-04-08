---
title: Shopify Store Setup Guide
version: 1.1
date: 2026-04-08
---

# Shopify Store — Setup Guide

This guide connects your Shopify store to your AI assistant. Once set up, your assistant can look up products, check orders, find customers, and manage inventory — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js **version 18 or higher** installed — check by typing `node --version` in the command window
- A Shopify store (live store, development store, or Partner store all work)
- Staff or owner access to the store
- An internet connection

> **If `node --version` shows v16 or lower:** Update Node.js from [nodejs.org](https://nodejs.org) before continuing.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Products** | Search, view, create, and update products and variants |
| **Orders** | View order details, search by status, check fulfillment |
| **Customers** | Look up customers, search by email, view order history |
| **Inventory** | Check stock levels, adjust quantities, find low-stock items |

---

## Step 1 — Install the Shopify CLI

Type this in the command window and press Enter:

```
npm install -g @shopify/cli
```

> **Note:** The theme toolkit (`@shopify/theme`) is bundled inside `@shopify/cli` since v3.59.0 — no separate install needed.

This may take 1–2 minutes. When it finishes, verify it worked:

```
shopify version
```

You should see a version number (e.g., `3.93.1`). If you see "command not found":
- **Windows:** Close the command window completely and open a new one, then try again
- **Mac:** Run `export PATH="$(npm prefix -g)/bin:$PATH"` and try again

---

## Step 2 — Log In to Shopify

```
shopify auth login
```

A browser window will open:

1. **Sign in with your Shopify Partner or organization account**
2. You should see a success message in the browser

> **If the browser does not open automatically**, copy the URL shown in the terminal and paste it into your browser manually.

---

## Step 3 — Connect to Your Store

This authenticates your assistant against your specific store and requests the permissions it needs:

```
shopify store auth --store your-store-name.myshopify.com --scopes read_products,write_products,read_orders,write_orders,read_customers,write_customers,read_inventory,write_inventory
```

Replace `your-store-name` with your actual store name — it's the part before `.myshopify.com` in your Shopify admin URL.

A browser window will open asking you to approve the requested permissions. Click **Install** or **Allow**.

> **To add more permissions later**, re-run this command with the additional scopes included in the `--scopes` list.

---

## Step 4 — Test It

Once connected, verify everything is working:

```
shopify store execute --store your-store-name.myshopify.com --query "{ shop { name email myshopifyDomain } }"
```

You should see your store's name and email in the response.

Now try asking your assistant:

- "Show me my recent Shopify orders"
- "List my products"
- "How many items are low on stock?"
- "Look up the customer with email john@example.com"

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **View products** | "Show me my Shopify products" |
| **Search products** | "Find products with 'sneaker' in the title" |
| **Create a product** | "Create a new draft product called Summer Tee for $29.99" |
| **Check orders** | "Show me today's orders" |
| **Find unfulfilled orders** | "Which orders haven't been shipped yet?" |
| **Look up a customer** | "Find the customer with email jane@example.com" |
| **Check inventory** | "What products are low on stock?" |
| **Adjust stock** | "Add 50 units of SKU-1234 to the main warehouse" |
| **Order details** | "Show me the details for order #1042" |
| **Revenue check** | "What were my total sales this week?" |

---

## Alternative: Direct API Access (Custom App)

If you prefer to use the Admin API directly (without the Shopify CLI), you can create a Custom App and use curl.

### Create the Custom App

1. Open your Shopify admin: `https://your-store-name.myshopify.com/admin`
2. Go to **Settings** (bottom-left) > **Apps and sales channels**
3. Click **Develop apps** (top-right)
4. If prompted, click **Allow custom app development**
5. Click **Create an app**
6. Name it something like `AI Assistant` and click **Create app**

### Configure Permissions

1. Click **Configure Admin API scopes**
2. Check these boxes:

| Scope | What it allows |
|---|---|
| `read_products` | View products and variants |
| `write_products` | Create and update products |
| `read_orders` | View orders and transactions |
| `write_orders` | Update orders |
| `read_customers` | View customer information |
| `write_customers` | Create and update customers |
| `read_inventory` | View inventory levels |
| `write_inventory` | Adjust inventory quantities |

3. Click **Save**

### Install and Get Your Token

1. Click the **API credentials** tab
2. Click **Install app** > **Install**
3. Under "Admin API access token", click **Reveal token once**
4. **Copy and save this token somewhere safe** — you will not be able to see it again

> **Important:** Treat this token like a password. Never share it publicly or commit it to code.

### Store the Token

Set it as an environment variable so your assistant can use it:

**Mac/Linux — add to your shell profile:**
```bash
echo 'export SHOPIFY_ACCESS_TOKEN="shpat_your_token_here"' >> ~/.zshrc
echo 'export SHOPIFY_STORE="your-store-name.myshopify.com"' >> ~/.zshrc
source ~/.zshrc
```

**Windows — set in your terminal:**
```bat
setx SHOPIFY_ACCESS_TOKEN "shpat_your_token_here"
setx SHOPIFY_STORE "your-store-name.myshopify.com"
```

> After running `setx` on Windows, close and reopen your terminal for the variables to take effect.

### Test Direct API Access

```bash
curl -s -X POST \
  "https://${SHOPIFY_STORE}/admin/api/2025-01/graphql.json" \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Access-Token: ${SHOPIFY_ACCESS_TOKEN}" \
  -d '{"query": "{ shop { name email myshopifyDomain } }"}' | python3 -m json.tool
```

---

## Troubleshooting

### Installation Problems

| Problem | Fix |
|---|---|
| "shopify: command not found" after install | Close and reopen your terminal. On Mac, also run: `export PATH="$(npm prefix -g)/bin:$PATH"` |
| Node.js version too old | Update from [nodejs.org](https://nodejs.org) — download the LTS version (v22 or v20) |
| **EPERM / permission denied** during install on Windows | Close the window, right-click your terminal → "Run as administrator", and try again |
| **EACCES** during install on Mac | Avoid using `sudo npm`. Instead install via nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` then `nvm install --lts` and retry |
| npm install hangs or times out | Check your internet connection. If behind a corporate firewall, ask IT to allow `registry.npmjs.org:443` |
| Script blocked on Windows ("running scripts is disabled") | Run in PowerShell: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then retry |

### Authentication Problems

| Problem | Fix |
|---|---|
| Browser does not open during login | Copy the URL from the terminal output and paste it into your browser manually |
| "Store not found" error | Double-check your store name — it should be just the subdomain, e.g., `my-store` not the full URL |
| Login fails or loops | Run `shopify auth logout` then try `shopify auth login` again |
| "You don't have permission" | Your Shopify account needs staff or owner access to the store |
| Scope error after `store auth` | Re-run `shopify store auth --store <store> --scopes <all-needed-scopes>` with the missing scopes added |

### Query Problems

| Problem | Fix |
|---|---|
| "Mutations are not allowed" | Add `--allow-mutations` to your `shopify store execute` command |
| 401 Unauthorized | Your stored token expired. Re-run `shopify store auth --store <store> --scopes <scopes>` |
| "Access denied" on orders | Some Shopify plans restrict API access. Check that your plan supports Admin API access |
| Rate limit errors (429) | Wait a moment and try again. Your assistant handles this automatically |
| Environment variable not set (curl method) | Verify with `echo $SHOPIFY_ACCESS_TOKEN` (Mac) or `echo %SHOPIFY_ACCESS_TOKEN%` (Windows). Re-run the export/setx command if empty |
| Something else | Contact your workshop facilitator |

---

## Note for Development Stores

Development stores created through the Shopify Partner dashboard have full API access with no restrictions. They're perfect for testing this integration before connecting a live store.

---

## Note for Shopify Plus Stores

Shopify Plus stores have additional API resources available (e.g., Gift Cards, Multipass). If you're on Shopify Plus and need access to these, add the corresponding scopes when running `shopify store auth`.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
