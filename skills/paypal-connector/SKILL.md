---
name: paypal-connector
description: "Connect and operate PayPal via the official @paypal/mcp server. Use this skill when the user asks to set up PayPal, connect their account, or interact with invoices, payments, orders, refunds, disputes, subscriptions, products, shipment tracking, or transactions. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__paypal__*, Bash, Read, Write, Edit
metadata:
  category: Payments & Billing
  tags:
    - paypal
    - invoices
    - payments
    - orders
    - refunds
    - subscriptions
    - commerce
    - mcp
  pairs-with:
    - skill: stripe-connector
      reason: Sibling payment processor — many businesses run both
    - skill: square-connector
      reason: Sibling payment processor for in-person and online sales
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by PayPal events (new order, payment received, dispute opened)
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting PayPal auth or API errors
---

# PayPal Connector

## Overview

This skill lets you read and update a user's PayPal account on their behalf using the **official first-party [`@paypal/mcp`](https://www.npmjs.com/package/@paypal/mcp)** (published by PayPal's SDK team, built on `@modelcontextprotocol/sdk`). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You walk them through creating an app in the PayPal Developer Dashboard, generating an access token, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "env var", or any file paths. They should feel like they are having a conversation, and at the end their PayPal is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__paypal__*` native tools to read and update PayPal data.

**Which phase to run** — Before any tool call, check whether the PayPal MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.paypal` entry with `PAYPAL_ACCESS_TOKEN` in its `env` block. If it exists and is non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **Client ID and Secret directly in the MCP config** — the `@paypal/mcp` server requires a pre-generated **Access Token** (`PAYPAL_ACCESS_TOKEN`), not raw Client ID / Secret. The user generates the token from the PayPal Developer Dashboard or via a REST API call using their Client ID and Secret.
- **A self-hosted or community MCP server** — `@paypal/mcp` is the official first-party package from PayPal. Always use it.
- **Direct PayPal REST API calls** — all reads and writes go through the MCP server, not direct HTTP calls.
- **`.env` files** — credentials live in the MCP config at `~/.claude.json`, never in a local dotenv.

### How auth works under the hood

The `@paypal/mcp` server accepts three CLI arguments:
- `--access-token=<token>` (or `PAYPAL_ACCESS_TOKEN` env var) — **required**
- `--tools=all` (or comma-separated list) — **required** — which tools to enable
- `--paypal-environment=<sandbox|production>` (or `PAYPAL_ENVIRONMENT` env var) — defaults to sandbox if not set

The access token is obtained by exchanging the app's Client ID + Secret via PayPal's OAuth 2.0 token endpoint. During Phase 1, you silently generate this token for the user so they never have to deal with it.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your PayPal is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase gets the PayPal app created, the access token generated, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only provides information and clicks things in their browser.

### Step 1 — Orient the user and choose path

Tell the user in one short message:

> "To connect your PayPal, I need you to create a free connection key inside your PayPal Developer account. This takes about three minutes. I will tell you exactly what to click, one step at a time.
>
> One quick question first — do you want to connect your **real PayPal account** (recommended), or would you prefer to start with a **practice sandbox** so you can try things out with fake data first?"

**Handle the response:**

- **User picks real account (or says "real", "live", "production")** → proceed to Step 2 with `PAYPAL_ENVIRONMENT` set to `PRODUCTION`. This is the default.
- **User picks sandbox (or says "test", "practice", "sandbox")** → proceed to Step 2, but when you reach Step 3, set `PAYPAL_ENVIRONMENT` to `SANDBOX`. Tell them: *"Great — we'll use the practice sandbox. Everything works the same way, but none of your real PayPal data will be affected."* Make sure the user copies credentials from the **Sandbox** tab (not Live) in Step 2.
- **User is unsure** → recommend the real account: *"I'd suggest the real account — you can always ask me to switch to sandbox later if you want to experiment. Shall we go with that?"*

### Step 2 — Walk the user through creating an app and getting the credentials

The user needs to create an app in the PayPal Developer Dashboard and copy the Client ID and Secret. You cannot do this step for them — PayPal requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please open this page in your browser: **https://developer.paypal.com/dashboard/applications** — and sign in with your PayPal account. Let me know when you are signed in."
   - If the user has multiple accounts (personal vs business), say: "Use your PayPal **business** account — that's the one with access to invoices, payments, and orders."

2. When they confirm → "Now click the **Create App** button. A form will appear. Tell me when you see it."

3. When they see the form → deliver the field values:
   - "For **App Name**, type: **Claude Assistant**."
   - "For **App Type**, choose: **Merchant**."
   - "Click the **Create App** button. Tell me when you see the app details page."

4. When they confirm → "You should now see two values on this page: a **Client ID** and a **Secret**. You may need to click **Show** next to the Secret to reveal it. Please copy the **Client ID** and paste it to me."

5. When they paste the Client ID → "Thanks. Now copy the **Secret** and paste it to me — don't worry about remembering it, I'll save it for you."

   **Important — Sandbox vs Live:** The PayPal Developer Dashboard shows both **Sandbox** and **Live** credentials. Make sure the user is copying from the tab that matches the path they chose in Step 1:
   - **Real account path** → copy from the **Live** tab. If the values look like test strings, ask: "Are you copying from the **Live** tab? We want the Live credentials so I can work with your real PayPal data."
   - **Sandbox path** → copy from the **Sandbox** tab. If they accidentally copy Live credentials, say: "Those look like your real account credentials — we want the **Sandbox** ones since you chose the practice path. Can you switch to the Sandbox tab and copy from there?"

Common mistakes to look out for (and correct by re-asking):

- The user pasted a placeholder like `your_client_id_here` → ask again: "I think that was a copy mistake — please try the real value from the page."
- The user pasted something very short (under 10 characters) → "That doesn't look quite right — the real value is longer. Can you double-check and try again?"
- The user says they can't find the Secret → "On the app details page, look for the word **Secret** with a **Show** link or button next to it. Click **Show** and the value will appear. If you need to generate one, there should be a **Generate** button."

### Step 3 — Generate the access token and save the connection

Once the user pastes the Client ID and Secret, you need to **silently generate an access token** using PayPal's OAuth 2.0 token endpoint, then save the config.

**Generate the access token** (the user never sees this):

```bash
# For PRODUCTION:
curl -s -X POST "https://api-m.paypal.com/v1/oauth2/token" \
  -u "<CLIENT_ID>:<SECRET>" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"

# For SANDBOX:
curl -s -X POST "https://api-m.sandbox.paypal.com/v1/oauth2/token" \
  -u "<CLIENT_ID>:<SECRET>" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

The response contains an `access_token` field. Extract it silently.

If the token request fails:
- `401` → "Those credentials didn't work. Could you double-check the Client ID and Secret in PayPal? Make sure you're copying from the right tab." Re-ask for both values.
- Network error → "I couldn't reach PayPal — is your internet working? Let me try again in a moment."

Once you have the access token, silently add or update the PayPal MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

```json
{
  "mcpServers": {
    "paypal": {
      "command": "npx",
      "args": ["-y", "@paypal/mcp", "--tools=all", "--paypal-environment=production"],
      "env": {
        "PAYPAL_ACCESS_TOKEN": "<access token from OAuth exchange>"
      }
    }
  }
}
```

For sandbox, replace `--paypal-environment=production` with `--paypal-environment=sandbox`.

**Rules:**
- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other `mcpServers` entry the user already has.
- If `~/.claude.json` does not exist, create it with just the PayPal entry.
- If the file exists but cannot be parsed as JSON, back it up to `~/.claude.json.backup` first, then write a fresh config with just the PayPal entry. Never silently lose the user's existing config.
- Never echo the access token, Client ID, or Secret back to the user after writing them. Never include them in any output visible to the user.
- **Also save the Client ID and Secret** to a local file at `~/.paypal-mcp-credentials.json` (with restricted permissions) so you can re-generate the access token later when it expires. Structure: `{"client_id": "...", "client_secret": "...", "environment": "production|sandbox"}`. Never show this file path or its contents to the user.

Tell the user in one short message:

> "I've saved your connection details. One more step — you'll need to close Claude Code and open it again so it picks up the new connection. Do that now, and tell me when you're back."

### Access token expiry

PayPal access tokens expire (typically after ~9 hours). When a tool call returns `401 Unauthorized` during Phase 2, **silently re-generate the token** using the saved Client ID and Secret from `~/.paypal-mcp-credentials.json`, update `PAYPAL_ACCESS_TOKEN` in `~/.claude.json`, and ask the user to restart Claude Code. Tell them: *"Your PayPal connection needed a quick refresh — please close and reopen Claude Code, then try again."*

### Step 4 — Verify the connection

When the user returns after restarting, tell them: "Welcome back. Let me just check that everything is talking to PayPal correctly."

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__paypal__*` tools are available**: call `mcp__paypal__list_invoices` or `mcp__paypal__list_transactions`. If it returns a result (including an empty list — that's fine), the connection works. Move to the success message.
- **If the tools are not yet available** (most likely on first setup): tell the user "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my PayPal connection' and I will verify it."

If the verification tool returns an error:
- `401 Unauthorized` or `Invalid credentials` → The access token may already be expired or the generation failed. Silently re-generate the token using the saved credentials. If re-generation also fails, ask the user to re-copy Client ID and Secret from PayPal.
- `403 Forbidden` → "Your connection is working, but PayPal is saying your app doesn't have permission for that. Let me try a different check." Try another read-only tool.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-check their app is active.

### Step 5 — Success message

Tell the user, in one short message:

> "All done! Your PayPal is now connected. You can ask me things like 'show me my recent invoices', 'create an invoice for a client', 'list my recent transactions', or 'check my disputes'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__paypal__*` MCP tools below to answer questions and make changes in PayPal. The `@paypal/mcp` server provides **28 tools** covering invoicing, payments, disputes, tracking, products, subscriptions, and reporting.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__paypal__`. All 28 tool names below are **verified against a live `@paypal/mcp` v1.8.0 server instance**.

#### Invoices (7 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_invoice` | Create a new draft invoice | User asks to invoice a client — **confirm first** |
| `list_invoices` | List invoices with optional filters | User asks "show me my invoices", "unpaid invoices", etc. |
| `get_invoice` | Get details of a specific invoice | User asks about a particular invoice |
| `send_invoice` | Send an invoice to the recipient | User asks to send/email an invoice — **confirm first** |
| `send_invoice_reminder` | Send a payment reminder for an invoice | User asks to remind someone to pay — **confirm first** |
| `cancel_sent_invoice` | Cancel a sent invoice | User asks to cancel an invoice — **confirm first** |
| `generate_invoice_qr_code` | Generate a QR code for invoice payment | User asks for a QR code to share for payment |

#### Orders (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_order` | Create a new payment order | User asks to set up a payment — **confirm first** |
| `get_order` | Get details of a specific order | User asks about an order's status |
| `pay_order` | Capture payment for an approved order | User asks to process/capture a payment — **confirm first** |

#### Payments (2 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_refund` | Refund a captured payment | User asks to refund a customer — **confirm first** |
| `get_refund` | Get details of a specific refund | User asks about a refund's status |

#### Disputes (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `list_disputes` | List open disputes and claims | User asks "do I have any disputes?" or "show me chargebacks" |
| `get_dispute` | Get details of a specific dispute | User asks about a particular dispute |
| `accept_dispute_claim` | Accept liability for a dispute claim | User asks to accept/concede a dispute — **confirm first** |

#### Shipment Tracking (2 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_shipment_tracking` | Add tracking info to a transaction | User asks to add tracking to an order — **confirm first** |
| `get_shipment_tracking` | Retrieve tracking details | User asks about shipping status |

#### Products (4 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_product` | Create a new product in the catalog | User asks to add a product — **confirm first** |
| `list_products` | List products in the catalog | User asks "show me my products" |
| `update_product` | Update an existing product | User asks to change a product — **confirm first** |
| `show_product_details` | Get details of a specific product | User asks about a particular product |

#### Subscription Plans (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_subscription_plan` | Create a new subscription plan | User asks to set up a recurring plan — **confirm first** |
| `list_subscription_plans` | List existing subscription plans | User asks "show me my subscription plans" |
| `show_subscription_plan_details` | Get details of a specific plan | User asks about a particular plan |

#### Subscriptions (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_subscription` | Create a new subscription for a customer | User asks to subscribe someone — **confirm first** |
| `show_subscription_details` | Get details of a specific subscription | User asks about a particular subscription |
| `cancel_subscription` | Cancel a subscription | User asks to cancel a subscription — **confirm first** |

#### Transactions (1 tool)

| Tool | Description | Use when |
|---|---|---|
| `list_transactions` | List recent transactions with optional filters | User asks "show me recent transactions", "what came in this week" |

> **Note:** All 28 tool names verified against a live `@paypal/mcp` v1.8.0 server via `tools/list` MCP call. In Claude Code they appear as `mcp__paypal__<tool_name>` (e.g. `mcp__paypal__list_invoices`, `mcp__paypal__create_refund`).

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my PayPal" / "Help me set up PayPal" | **Run Phase 1** |
| "Show me my invoices" | `list_invoices` |
| "Show me unpaid invoices" | `list_invoices` (filter by status) |
| "Create an invoice for [client] for [amount]" | `create_invoice` — **confirm first** |
| "Send that invoice" | `send_invoice` — **confirm first** |
| "Remind [client] to pay" | `send_invoice_reminder` — **confirm first** |
| "Cancel invoice [number]" | `cancel_sent_invoice` — **confirm first** |
| "Generate a QR code for this invoice" | `generate_invoice_qr_code` |
| "Show me recent transactions" | `list_transactions` |
| "What came in this week?" | `list_transactions` (filter by date) |
| "Refund [customer] for [amount]" | `create_refund` — **confirm first** |
| "Check on refund [id]" | `get_refund` |
| "Do I have any disputes?" | `list_disputes` |
| "Tell me about dispute [id]" | `get_dispute` |
| "Accept this dispute" | `accept_dispute_claim` — **confirm first** |
| "Add tracking to order [id]" | `create_shipment_tracking` — **confirm first** |
| "Where is my shipment?" | `get_shipment_tracking` |
| "Show me my products" | `list_products` |
| "Add a new product" | `create_product` — **confirm first** |
| "Update product [name]" | `update_product` — **confirm first** |
| "Show me product details" | `show_product_details` |
| "Show me my subscription plans" | `list_subscription_plans` |
| "Create a monthly plan for [amount]" | `create_subscription_plan` — **confirm first** |
| "Show plan details" | `show_subscription_plan_details` |
| "Cancel subscription [id]" | `cancel_subscription` — **confirm first** |
| "Show subscription details" | `show_subscription_details` |
| "Set up a new order" | `create_order` — **confirm first** |
| "Capture payment on order [id]" | `pay_order` — **confirm first** |
| "Switch my PayPal to sandbox" / "Switch to real account" | Update config and restart |

---

## Error Handling (Phase 2)

When a PayPal tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your PayPal connection needs a refresh — give me a moment." | Silently re-generate the access token using saved Client ID / Secret from `~/.paypal-mcp-credentials.json`. Update `~/.claude.json`. Ask user to restart Claude Code. |
| 403 Forbidden | "Your PayPal app doesn't have permission for that action. This might be a restriction on your PayPal account type." | Check if the user has a business account; some features require specific account tiers |
| 404 Not Found | "I couldn't find that record — let me search for it." | Use the matching list tool to help find the correct record |
| 429 Rate limited | "PayPal is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| INVALID_RESOURCE_ID | "That ID doesn't match any PayPal record. Let me look it up." | Use a list tool to find the correct ID |
| PERMISSION_DENIED | "Your PayPal account doesn't have access to that feature. This may need to be enabled in your PayPal business settings." | Guide user to check their PayPal account features |
| MCP server not running | "The PayPal connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with PayPal — let me try again." | Retry once; if still failing, check credentials |

---

## Scope Limitations

The PayPal MCP connector **can** do (via `@paypal/mcp` — 28 tools verified):
- Create, list, get, send, remind, and cancel invoices
- Generate invoice QR codes for easy payment
- Create, get, and capture (pay) payment orders
- Issue and check refunds
- List, get, and accept dispute claims
- Add and retrieve shipment tracking
- Create, list, update, and show product catalog items
- Create, list, and show subscription plans
- Create, show, and cancel subscriptions
- List transactions

The PayPal MCP connector **cannot** do:
- **Update shipment tracking** — only create and retrieve (no update tool in v1.8.0)
- **Update subscriptions** — only create, show, and cancel (no update tool in v1.8.0)
- **Retrieve merchant insights** — not available in v1.8.0
- **Withdraw funds** or transfer money between accounts
- **Access** PayPal Wallet, balance, or bank account details
- **Send** peer-to-peer payments (PayPal.me / friends and family)
- **Manage** account settings, users, or permissions
- **Access** PayPal Checkout button integration or web SDKs
- **Manage** PayPal Business Debit Card or credit products
- **Access** PayPal Giving Fund or charity features
- **Connect multiple PayPal accounts** at once — one set of credentials per `~/.claude.json` entry

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, sending, cancelling, or refunding** — summarise what you are about to do and wait for the user's OK before calling the tool. This is especially important for invoices, payments, refunds, and subscription changes.
- **Invoices start as drafts** — when creating an invoice, clarify that it has been created as a draft. The user must explicitly ask you to send it.
- **Format currency correctly** — use the currency from the PayPal response (USD, EUR, GBP, AUD, etc.) and format amounts with 2 decimal places.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 8 unpaid invoices totalling $12,450"), then offer to show details.
- **Pagination** — default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Sandbox vs Production** — the connector defaults to PRODUCTION. If the user chose sandbox in Step 1, `--paypal-environment=sandbox` is set in the args. The user can switch at any time by saying "switch my PayPal to the real account" or "switch my PayPal to sandbox" — re-generate the access token with the other environment's credentials, update `~/.claude.json`, and ask them to restart Claude Code.
- **Access token expiry** — PayPal tokens expire (~9 hours). On 401 errors, silently re-generate the token before asking the user to restart. Never mention tokens, OAuth, or expiry to the user — just say "your connection needed a quick refresh."
- **Refunds are irreversible** — always confirm the amount and transaction before processing a refund.
- **Disputes are time-sensitive** — when showing disputes, highlight any approaching deadlines.
- **Never log or echo credentials** — the access token, Client ID, and Secret must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting PayPal auth or API errors
- **stripe-connector**: Sibling payment connector — many businesses run both Stripe and PayPal
- **square-connector**: Sibling payment connector for in-person and online sales
- **hubspot-connector**: Same access-token → `~/.claude.json` pattern for a different first-party MCP server
