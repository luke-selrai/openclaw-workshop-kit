# Business Tool Connectors

This is the master guide for all available business tool connectors. Claude reads this file during Phase 3 Tool Step 5 to recommend and install connectors based on the user's tech stack.

---

## Available Connectors

| Connector | What It Does | MCP Package | Auth Type | Setup Time |
|---|---|---|---|---|
| `ghl` | CRM — contacts, pipelines, messaging, calendars, social media | Community MCP (269+ tools) + bash helper | API Key + Login | 5 min |
| `shopify` | E-commerce — products, orders, customers, inventory | `shopify-mcp` (31 tools) | Access Token or OAuth | 5 min |
| `xero` | Accounting — invoices, contacts, bank, payroll, reporting | `@xeroapi/xero-mcp-server` (50+ tools) | OAuth2 Custom Connection | 10 min |
| `stripe` | Payments — customers, subscriptions, invoices, refunds | `@stripe/mcp` (full API) | Restricted API Key | 5 min |
| `quickbooks` | Accounting — invoices, customers, vendors, estimates | `quickbooks-online-mcp-server` | Intuit OAuth | 10 min |
| `hubspot` | CRM — contacts, companies, deals, tickets | `@hubspot/mcp-server` (13 objects) | Private App Token | 5 min |
| `square` | POS/Payments — orders, customers, catalog, bookings, inventory | `square-mcp-server` (40+ services) | Access Token | 5 min |

---

## Auto-Recommendation Logic

Claude reads the user's answer to onboarding Question 5 ("What apps or tools do you use?") and Question 2 (business type). Then matches keywords to recommend connectors.

### Keyword Matching

```
"ghl" / "gohighlevel" / "highlevel" / "high level" / "go high level"  →  ghl
"shopify"                                                               →  shopify
"xero"                                                                  →  xero
"stripe"                                                                →  stripe
"quickbooks" / "qb" / "quickbook" / "intuit"                           →  quickbooks
"hubspot" / "hub spot"                                                  →  hubspot
"square" / "square pos"                                                 →  square
```

### Inference Rules (when no direct keyword match)

Use these rules when the user did NOT mention a tool but their business type suggests they need one:

| Situation | Recommend | Why |
|---|---|---|
| User sells products online but no e-commerce tool mentioned | `shopify` | Most popular e-commerce platform for small business |
| User has no CRM mentioned at all | `ghl` | Included in the workshop, popular with small businesses |
| User has no accounting tool, business is in AU/NZ/UK | `xero` | Dominant accounting platform in those regions |
| User has no accounting tool, business is in US/CA | `quickbooks` | Dominant accounting platform in those regions |
| User takes payments but no payment processor mentioned | `stripe` | Most widely used payment processor |
| User has physical store or takes bookings, no POS mentioned | `square` | Best POS for small business |
| User mentions "invoices" or "billing" but no accounting | `xero` or `quickbooks` (by region) | Invoicing needs accounting software |

### Grouping Rules

- **Maximum 3 recommendations at once** — do not overwhelm the user
- **Primary:** The connector most relevant to their biggest challenge (Question 4)
- **Secondary:** Up to 2 more based on their tool stack (Question 5)
- For the rest, say: "I can also connect [others] later whenever you are ready."
- All connectors are **optional** — never force one

### Recommendation Script (what Claude says)

For each recommended connector:

1. **Describe** in ONE sentence what it does for their specific business
2. **Ask:** "Would you like me to connect [tool name]?"
3. **If yes:**
   a. Run: `bash ~/workshop-kit/connectors/install-connector.sh [name]`
   b. Guide user through getting their credentials (see Credential Guides below)
   c. Run: `bash ~/workshop-kit/connectors/[name]/test.sh` to verify
   d. Save to memory: `connector_[name]: connected, date: [today]`
4. **If no:** "No problem. Just say 'connect [name]' any time."

---

## Credential Guides

For each connector, these are the EXACT steps to get credentials. Claude walks the user through these one at a time.

### GoHighLevel (GHL)
1. Log into GoHighLevel at app.gohighlevel.com
2. Click the gear icon (Settings) in the bottom left
3. Click "Business Profile"
4. Scroll down to find "API Key"
5. Copy the API Key
6. Your Location ID is in your browser URL: `app.gohighlevel.com/v2/location/THIS_PART/...`

### Shopify
1. Log into your Shopify admin at your-store.myshopify.com/admin
2. Click "Settings" in the bottom left corner
3. Click "Apps and sales channels"
4. Click "Develop apps" at the top
5. Click "Create an app" — give it any name like "AI Assistant"
6. Click "Configure Admin API scopes" — select all scopes you want (read_products, read_orders, read_customers, write_products, etc.)
7. Click "Install app"
8. Copy the "Admin API access token" (starts with shpat_)

### Xero
1. Go to developer.xero.com
2. Click "My Apps" in the top menu
3. Click "New App"
4. Choose "Custom Connection" as the app type
5. Give it a name like "AI Assistant"
6. Accept the terms and click "Create App"
7. Copy the "Client ID"
8. Click "Generate a secret" and copy the "Client Secret"
9. Under "Configuration", click "Edit" and add scopes: accounting.transactions, accounting.contacts, accounting.reports.read

### Stripe
1. Go to dashboard.stripe.com
2. Click "Developers" in the top menu
3. Click "API Keys"
4. Click "Create restricted key"
5. Give it a name like "AI Assistant"
6. Set permissions for what you want (Read for most things, Write for creating invoices/payment links)
7. Click "Create key"
8. Copy the key (starts with rk_)

### QuickBooks
1. Go to developer.intuit.com
2. Sign in with your Intuit account
3. Click "My Apps" then "Create an app"
4. Choose "QuickBooks Online and Payments"
5. Give it a name like "AI Assistant"
6. Go to "Keys & credentials"
7. Copy the Client ID and Client Secret

### HubSpot
1. Log into your HubSpot account
2. Click the gear icon (Settings) in the top right
3. Click "Integrations" in the left menu
4. Click "Private Apps"
5. Click "Create a private app"
6. Give it a name like "AI Assistant"
7. Go to the "Scopes" tab and select the permissions you need (crm.objects.contacts.read, crm.objects.deals.read, etc.)
8. Click "Create app"
9. Copy the access token

### Square
1. Go to developer.squareup.com
2. Sign in with your Square account
3. Click "Applications" then your app (or create one)
4. Click "Credentials" in the left menu
5. Copy the "Access Token" (use Production, not Sandbox)

---

## Post-Install: What Claude Can Do

After a connector is installed, Claude can immediately start helping. Here are example prompts by connector:

### GHL
- "Search my contacts for Sarah"
- "Show me all open opportunities"
- "Send an SMS to John saying we will follow up Monday"
- "What is on my calendar this week?"

### Shopify
- "Show me my best-selling products"
- "How many orders came in today?"
- "Look up the customer who ordered #1234"
- "Update the price of [product] to $49.99"

### Xero
- "Show me all unpaid invoices"
- "Create an invoice for $500 for John Smith"
- "What is my profit and loss this month?"
- "Who owes me money right now?"

### Stripe
- "Show me today's payments"
- "Create a payment link for $100"
- "List all active subscriptions"
- "Look up customer john@example.com"

### QuickBooks
- "Show me all unpaid invoices"
- "Create an invoice for ABC Company"
- "What are my expenses this month?"
- "List all customers"

### HubSpot
- "Show me all open deals"
- "Look up contact john@example.com"
- "What tickets are open right now?"
- "List companies added this month"

### Square
- "Show me today's orders"
- "Look up customer Jane Smith"
- "What items are in my catalog?"
- "Show me this week's payouts"

---

## Connector Status Tracking

After installing connectors, save to memory:

```
connectors_installed: [list of installed connectors]
connectors_available: ghl, shopify, xero, stripe, quickbooks, hubspot, square
connector_[name]_installed: true
connector_[name]_date: [date]
```

When the user asks "what is connected?" or "what tools do I have?", check memory and list their connected tools.

When the user mentions a tool that has a connector but is not installed, say:
> "I notice you mentioned [tool]. I can connect to it so I can help you manage it directly. Would you like me to set that up? It takes about 5 minutes."

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
