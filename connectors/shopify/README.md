# Shopify Connector for Claude Code

Manage your Shopify store with natural language. Products, orders, customers, inventory — just ask Claude.

"Show me my best-selling products" — and Claude does it.

---

## Setup (5 minutes)

### Step 1: Run the installer

```bash
cd shopify
bash setup.sh
```

### Step 2: Get your Shopify credentials

The installer creates a credentials file. Open it:

```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/shopify.env
```

You need 2 things:

| Field | Where to find it |
|-------|-----------------|
| `SHOPIFY_STORE_DOMAIN` | Your store URL: `your-store.myshopify.com` |
| `SHOPIFY_ACCESS_TOKEN` | Shopify Admin > Settings > Apps > Develop apps > Create app > Admin API access token |

### Step 3: Test it

```bash
bash test.sh
```

All `[pass]`? You're done.

---

## What you can do

Once set up, just ask Claude:

- "Show me my best-selling products"
- "How many orders came in today?"
- "Look up the customer who ordered #1234"
- "Update the price of [product] to $49.99"
- "What's my current inventory for [product]?"
- "Create a new product called [name] at $[price]"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/shopify/SKILL.md` | Teaches Claude the Shopify MCP tools, API quirks, and safety rules |
| `secrets/shopify.env.template` | Your credentials template |
| `setup.sh` | One-command installer |
| `test.sh` | Verifies everything works |

---

## Troubleshooting

**API returns 401**
Your access token is wrong or expired. Create a new one in Shopify Admin > Settings > Apps > Develop apps.

**MCP not showing up**
Run: `claude mcp add shopify -- npx shopify-mcp --accessToken YOUR_TOKEN --domain YOUR_STORE.myshopify.com`

**"Permission denied" on a resource**
Your app needs more API scopes. Go to Shopify Admin > Settings > Apps > your app > Configure Admin API scopes.
