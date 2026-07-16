---
name: paypal-connector
description: "Connect and operate PayPal via the official @paypal/mcp server. Drives the entire setup autonomously through developer.paypal.com/dashboard/applications in a Playwright MCP browser: switches to the chosen Live or Sandbox tab, clicks Create App, fills the app name, captures Client ID and Secret from the DOM after clicking Show, silently exchanges them for an access token, and writes ~/.claude.json. The only human moments are the user signing in to PayPal once and answering live-vs-sandbox. Use this skill when the user asks to set up PayPal, connect their account, or interact with invoices, payments, orders, refunds, disputes, subscriptions, products, shipment tracking, or transactions. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__paypal__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
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
      reason: Sibling payment processor - many businesses run both
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

- **Phase 1 - Install & Auth (autonomous).** Claude drives the entire `developer.paypal.com/dashboard/applications` flow inside a Playwright MCP browser. The user does exactly two things: sign in to PayPal in the Playwright window, and answer "live or sandbox?" when Claude asks. Everything else - switching to the matching tab, clicking *Create App*, filling the name and Merchant type, clicking *Show* on the Secret, capturing both Client ID and Secret from the DOM, exchanging them for an access token via PayPal's OAuth endpoint, persisting credentials to disk for future refreshes, writing `~/.claude.json` - is autonomous. The user never copies, never pastes, never reads a Client ID or Secret aloud, never opens a tab themselves.
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__paypal__*` native tools to read and update PayPal data.

**Which phase to run** - Before any tool call, check whether the PayPal MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.paypal` entry with `PAYPAL_ACCESS_TOKEN` in its `env` block. If it exists and is non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **Client ID and Secret directly in the MCP config** - the `@paypal/mcp` server requires a pre-generated **Access Token** (`PAYPAL_ACCESS_TOKEN`), not raw Client ID / Secret. The user generates the token from the PayPal Developer Dashboard or via a REST API call using their Client ID and Secret.
- **A self-hosted or community MCP server** - `@paypal/mcp` is the official first-party package from PayPal. Always use it.
- **Direct PayPal REST API calls** - all reads and writes go through the MCP server, not direct HTTP calls.
- **`.env` files** - credentials live in the MCP config at `~/.claude.json`, never in a local dotenv.

### How auth works under the hood

The `@paypal/mcp` server accepts three CLI arguments:
- `--access-token=<token>` (or `PAYPAL_ACCESS_TOKEN` env var) - **required**
- `--tools=all` (or comma-separated list) - **required** - which tools to enable
- `--paypal-environment=<sandbox|production>` (or `PAYPAL_ENVIRONMENT` env var) - defaults to sandbox if not set

The access token is obtained by exchanging the app's Client ID + Secret via PayPal's OAuth 2.0 token endpoint. During Phase 1, you silently generate this token for the user so they never have to deal with it.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work, the user only signs in to PayPal and answers live-vs-sandbox once. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and "live or sandbox?" The live-vs-sandbox question is the *one* unavoidable user input, because Claude cannot infer it from PayPal alone.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - Client ID + Secret → **"your connection details"** (collectively)
  - Access token → don't mention; the user never sees it
  - Restart Claude Code → **"close and reopen"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening PayPal for you now"), once when you need them ("please sign in", "live or sandbox?"), once when you're done ("your PayPal is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your PayPal is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **No fabricated UI assertions.** Don't reference button colours ("the orange button") or specific positioning ("top-right corner") - verify from the live snapshot. PayPal's developer dashboard changes frequently.
- **Never echo Client ID, Secret, or access token** back to the user. Never include any of them in any output visible to the user.

---

## PHASE 1 - Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only roles are: (1) sign in to PayPal once, (2) answer "live or sandbox?" once. Claude handles every other step - environment tab switch, app creation, Client ID and Secret capture from DOM, OAuth token exchange, credentials persistence, config write, verify.

> **Reasoning model.** Each Playwright step describes a *goal*. Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_navigate` / `browser_fill_form` / `browser_select_option` / `browser_type`. Do not hardcode CSS selectors or button colours - PayPal's developer dashboard changes regularly. Re-snapshot whenever the page state changes.

### Step 1 - Orient the user and choose environment

Tell the user, in one short message:

> "I'll connect your PayPal now. I'm opening a browser window - please sign in to PayPal there, and I'll set up the connection for you. About a minute.
>
> One quick question first - do you want to connect your **real PayPal account** (recommended), or start with a **practice sandbox** to try things with fake data?"

Wait for the answer. Save the result as `environment ∈ {production, sandbox}`:

- "real", "live", "production", "yes" → `production` (default if unclear)
- "test", "practice", "sandbox" → `sandbox`. Tell them: *"Great - practice sandbox it is. None of your real PayPal data will be affected."*
- Unsure → recommend production: *"I'd suggest the real account - you can always switch to sandbox later. Shall we go with that?"*

### Step 2 - Open the PayPal Developer Dashboard and confirm a logged-in session

Call `mcp__playwright__browser_navigate({ url: "https://developer.paypal.com/dashboard/applications" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see an apps list, a "Create App" control, the developer dashboard chrome, or environment tabs labelled "Live" / "Sandbox") → continue to Step 3.
- **Not logged in** → tell the user *once*: *"The browser window is open - please sign in to PayPal when you're ready."* Poll silently with `mcp__playwright__browser_wait_for({ text: "Create App" })` (or any post-login dashboard element from a fresh snapshot). Do not ask the user to confirm; detect login completion yourself. SSO and 2FA all resolve to the same dashboard.
- **Account type modal** (PayPal sometimes asks personal vs business on first developer login) → if a business option is available, click it. If only personal is available, tell the user: *"PayPal recommends a business account for invoicing and payments. Want to continue with personal anyway, or pause and upgrade first?"*

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 - Switch to the matching environment tab

The dashboard shows two environment tabs (typically labelled "Live" and "Sandbox"). Locate the tab matching the `environment` chosen in Step 1 from the snapshot. Click it via `browser_click`. Re-snapshot to confirm the tab is active (the URL or app list will change; the active tab will visually indicate selection in the accessibility tree).

Identify *active* tab by examining the snapshot's role/state attributes (`aria-selected="true"`, `aria-current`, or similar) - never rely on visual position or colour.

### Step 4 - Create the app

Locate the "Create App" control in the snapshot of the active environment tab. Click it. Snapshot the resulting form.

Fill the form:
- **App Name** → `"Claude Assistant"` (via `browser_type` or `browser_fill_form`)
- **App Type** → select **Merchant** (use `browser_click` on the Merchant radio/option, or `browser_select_option` if it's a dropdown)

Click the form's submit button (typically labelled "Create App"). Snapshot to confirm you've landed on the app details page (Client ID will be visible).

If PayPal shows a confirmation/intermediate dialog, snapshot it and click the affirmative option.

### Step 5 - Capture Client ID and Secret

The app details page shows the Client ID inline and a Secret behind a "Show" / "Reveal" button.

**Capture Client ID** via `browser_evaluate`:

```
() => {
  // Look for inputs/codes whose label or aria-label mentions "Client ID"
  const candidates = [...document.querySelectorAll('input, code, textarea, [data-testid*="client"], [class*="client-id"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (v && v.length > 30 && /^[A-Za-z0-9_-]+$/.test(v)) return v;
  }
  return null;
}
```

**Reveal the Secret**: locate the Show / Reveal control next to the Secret field from the snapshot, click it via `browser_click`, re-snapshot.

**Capture Secret** via `browser_evaluate` (symmetric to the Client ID block above, biased toward Secret markers, with a Client-ID exclusion filter so the same input/code/textarea selectors don't return the previously-captured Client ID):

```
() => {
  // Pass the captured Client ID via template substitution so the closure can exclude it.
  const clientId = "<CLIENT_ID_FROM_STEP_5_PART_1>";
  const candidates = [...document.querySelectorAll('input, code, textarea, [data-testid*="secret"], [class*="secret"]')];
  for (const el of candidates) {
    const v = (el.value || el.textContent || '').trim();
    if (v && v !== clientId && v.length > 30 && /^[A-Za-z0-9_-]+$/.test(v)) return v;
  }
  return null;
}
```

> **Note on the regex.** The `^[A-Za-z0-9_-]+$` validation matches PayPal's documented Client ID + Secret shape. If a future PayPal release ships Secrets with `=` padding or other characters, expand the character class here and at line ~149's validation in tandem.

**Validation (silent):**
- Both values must be longer than 30 characters
- Both must match `^[A-Za-z0-9_-]+$`
- Client ID and Secret must be different from each other

If both values aren't surfaced after two snapshot rounds, stop and ask: *"I'm having trouble finding the connection details on the page - could you describe what's visible?"*

### Step 6 - Exchange credentials for an access token (silent, Bash)

Silently exchange Client ID + Secret for an access token via PayPal's OAuth 2.0 token endpoint. Pick the endpoint matching the `environment`:

- production → `https://api-m.paypal.com/v1/oauth2/token`
- sandbox → `https://api-m.sandbox.paypal.com/v1/oauth2/token`

Run via Bash:

```bash
curl -sf -X POST "<endpoint>" \
  -u "<CLIENT_ID>:<SECRET>" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials"
```

Parse the response JSON for `access_token`. If parsing fails or the field is missing:
- HTTP `401` → "Those credentials didn't take - let me try grabbing fresh ones." Re-run Step 5 (re-reveal the Secret, re-capture). If still failing, re-run Steps 4-5.
- Network error → tell the user *"I couldn't reach PayPal - let me try again."* Retry once.

### Step 7 - Persist credentials and register the MCP server

**Save Client ID + Secret + environment** to `~/.paypal-mcp-credentials.json` for future token refreshes (PayPal access tokens expire ~9 hours):

```json
{
  "client_id": "<CLIENT_ID>",
  "client_secret": "<SECRET>",
  "environment": "production"
}
```

(Use `"sandbox"` for sandbox.) Restrict permissions: `chmod 600` on Mac/Linux. On Windows, rely on home-dir ACLs.

**Register the MCP server**. Prefer `claude mcp add` via Bash:

```bash
# production:
claude mcp add paypal \
  --scope user \
  --env PAYPAL_ACCESS_TOKEN="<access token from Step 6>" \
  -- npx -y @paypal/mcp --tools=all --paypal-environment=production

# sandbox: replace --paypal-environment=production with --paypal-environment=sandbox
```

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) - write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`):

<details>
<summary>Direct JSON write</summary>

```json
{
  "mcpServers": {
    "paypal": {
      "command": "npx",
      "args": ["-y", "@paypal/mcp", "--tools=all", "--paypal-environment=production"],
      "env": { "PAYPAL_ACCESS_TOKEN": "<access token>" }
    }
  }
}
```
</details>

Merge into the existing `mcpServers` object - never overwrite. If `~/.claude.json` doesn't exist, create it. If it's corrupt, back up to `~/.claude.json.backup` first.

Never echo the Client ID, Secret, or access token back to the user. Never include any of them in any output visible to the user. Never log them to the conversation, even truncated. Never describe the credentials file path.

### Step 8 - Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. Credentials now live only in `~/.claude.json` and `~/.paypal-mcp-credentials.json`.

Tell the user: *"Saved - let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__paypal__*` tools are available**: call `mcp__paypal__list_invoices` (or `list_transactions`). If it returns a result (including an empty list - that's fine), success. Move to Step 9.
- **If the tools are not yet available** (most likely on first setup): tell the user *"All saved. Please close and reopen Claude Code once so the connection becomes active, then say 'test my PayPal' and I'll verify it."*

If verification returns an error:
- `401 Unauthorized` / `Invalid credentials` → silently re-run Step 6 with the saved Client ID + Secret to refresh the access token, then update `PAYPAL_ACCESS_TOKEN` in `~/.claude.json`. If still failing, re-run Steps 2-7.
- `403 Forbidden` → "Your PayPal app doesn't have permission for that. This may need a business account upgrade in PayPal."
- Any other error → retry once; if still failing, re-run Phase 1.

### Step 9 - Success message

Tell the user, in one short message:

> "All done! Your PayPal is now connected. You can ask me things like 'show me my recent invoices', 'create an invoice for a client', 'list my recent transactions', or 'check my disputes'. Give it a try!"

---

### Access token expiry (Phase 2)

PayPal access tokens expire after ~9 hours. When a Phase 2 tool call returns `401 Unauthorized`, **silently** re-run Step 6 using the saved `client_id` + `client_secret` + `environment` from `~/.paypal-mcp-credentials.json`. Update `PAYPAL_ACCESS_TOKEN` in `~/.claude.json` (preserving every other field). Then tell the user: *"Your PayPal connection needed a quick refresh - please close and reopen Claude Code, then try again."* Never mention tokens, OAuth, or expiry to the user.

---

## PHASE 2 - Use Tools

Once the connector is configured, use the `mcp__paypal__*` MCP tools below to answer questions and make changes in PayPal. The `@paypal/mcp` server provides **30 tools** covering invoicing, payments, disputes, tracking, products, subscriptions, and reporting.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__paypal__`. All 30 tool names below are **verified against the published `@paypal/mcp` v1.8.1 README under `## Available tools` (re-extracted from npm 2026-05-07)**. v1.8.0 and v1.8.1 expose the same 30-tool set.

#### Invoices (7 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_invoice` | Create a new draft invoice | User asks to invoice a client - **confirm first** |
| `list_invoices` | List invoices with optional filters | User asks "show me my invoices", "unpaid invoices", etc. |
| `get_invoice` | Get details of a specific invoice | User asks about a particular invoice |
| `send_invoice` | Send an invoice to the recipient | User asks to send/email an invoice - **confirm first** |
| `send_invoice_reminder` | Send a payment reminder for an invoice | User asks to remind someone to pay - **confirm first** |
| `cancel_sent_invoice` | Cancel a sent invoice | User asks to cancel an invoice - **confirm first** |
| `generate_invoice_qr_code` | Generate a QR code for invoice payment | User asks for a QR code to share for payment |

#### Orders (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_order` | Create a new payment order | User asks to set up a payment - **confirm first** |
| `get_order` | Get details of a specific order | User asks about an order's status |
| `pay_order` | Capture payment for an approved order | User asks to process/capture a payment - **confirm first** |

#### Payments (2 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_refund` | Refund a captured payment | User asks to refund a customer - **confirm first** |
| `get_refund` | Get details of a specific refund | User asks about a refund's status |

#### Disputes (3 tools)

| Tool | Description | Use when |
|---|---|---|
| `list_disputes` | List open disputes and claims | User asks "do I have any disputes?" or "show me chargebacks" |
| `get_dispute` | Get details of a specific dispute | User asks about a particular dispute |
| `accept_dispute_claim` | Accept liability for a dispute claim | User asks to accept/concede a dispute - **confirm first** |

#### Shipment Tracking (2 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_shipment_tracking` | Add tracking info to a transaction | User asks to add tracking to an order - **confirm first** |
| `get_shipment_tracking` | Retrieve tracking details | User asks about shipping status |

#### Products (4 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_product` | Create a new product in the catalog | User asks to add a product - **confirm first** |
| `list_products` | List products in the catalog | User asks "show me my products" |
| `update_product` | Update an existing product | User asks to change a product - **confirm first** |
| `show_product_details` | Get details of a specific product | User asks about a particular product |

#### Subscription Plans (4 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_subscription_plan` | Create a new subscription plan | User asks to set up a recurring plan - **confirm first** |
| `list_subscription_plans` | List existing subscription plans | User asks "show me my subscription plans" |
| `show_subscription_plan_details` | Get details of a specific plan | User asks about a particular plan |
| `update_plan` | Update an existing subscription plan | User asks to change pricing/terms on a plan - **confirm first** |

#### Subscriptions (4 tools)

| Tool | Description | Use when |
|---|---|---|
| `create_subscription` | Create a new subscription for a customer | User asks to subscribe someone - **confirm first** |
| `show_subscription_details` | Get details of a specific subscription | User asks about a particular subscription |
| `update_subscription` | Update an existing subscription | User asks to change a subscription's quantity/billing - **confirm first** |
| `cancel_subscription` | Cancel a subscription | User asks to cancel a subscription - **confirm first** |

#### Transactions (1 tool)

| Tool | Description | Use when |
|---|---|---|
| `list_transactions` | List recent transactions with optional filters | User asks "show me recent transactions", "what came in this week" |

> **Note:** All 30 tool names verified against the `@paypal/mcp` v1.8.1 README's `## Available tools` listing (re-extracted from npm 2026-05-07; v1.8.0 and v1.8.1 expose the same set). In Claude Code they appear as `mcp__paypal__<tool_name>` (e.g. `mcp__paypal__list_invoices`, `mcp__paypal__create_refund`).

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my PayPal" / "Help me set up PayPal" | **Run Phase 1** |
| "Show me my invoices" | `list_invoices` |
| "Show me unpaid invoices" | `list_invoices` (filter by status) |
| "Create an invoice for [client] for [amount]" | `create_invoice` - **confirm first** |
| "Send that invoice" | `send_invoice` - **confirm first** |
| "Remind [client] to pay" | `send_invoice_reminder` - **confirm first** |
| "Cancel invoice [number]" | `cancel_sent_invoice` - **confirm first** |
| "Generate a QR code for this invoice" | `generate_invoice_qr_code` |
| "Show me recent transactions" | `list_transactions` |
| "What came in this week?" | `list_transactions` (filter by date) |
| "Refund [customer] for [amount]" | `create_refund` - **confirm first** |
| "Check on refund [id]" | `get_refund` |
| "Do I have any disputes?" | `list_disputes` |
| "Tell me about dispute [id]" | `get_dispute` |
| "Accept this dispute" | `accept_dispute_claim` - **confirm first** |
| "Add tracking to order [id]" | `create_shipment_tracking` - **confirm first** |
| "Where is my shipment?" | `get_shipment_tracking` |
| "Show me my products" | `list_products` |
| "Add a new product" | `create_product` - **confirm first** |
| "Update product [name]" | `update_product` - **confirm first** |
| "Show me product details" | `show_product_details` |
| "Show me my subscription plans" | `list_subscription_plans` |
| "Create a monthly plan for [amount]" | `create_subscription_plan` - **confirm first** |
| "Show plan details" | `show_subscription_plan_details` |
| "Cancel subscription [id]" | `cancel_subscription` - **confirm first** |
| "Show subscription details" | `show_subscription_details` |
| "Set up a new order" | `create_order` - **confirm first** |
| "Capture payment on order [id]" | `pay_order` - **confirm first** |
| "Switch my PayPal to sandbox" / "Switch to real account" | Update config and restart |

---

## Error Handling (Phase 2)

When a PayPal tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your PayPal connection needs a refresh - give me a moment." | Silently re-generate the access token using saved Client ID / Secret from `~/.paypal-mcp-credentials.json`. Update `~/.claude.json`. Ask user to restart Claude Code. |
| 403 Forbidden | "Your PayPal app doesn't have permission for that action. This might be a restriction on your PayPal account type." | Check if the user has a business account; some features require specific account tiers |
| 404 Not Found | "I couldn't find that record - let me search for it." | Use the matching list tool to help find the correct record |
| 429 Rate limited | "PayPal is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| INVALID_RESOURCE_ID | "That ID doesn't match any PayPal record. Let me look it up." | Use a list tool to find the correct ID |
| PERMISSION_DENIED | "Your PayPal account doesn't have access to that feature. This may need to be enabled in your PayPal business settings." | Guide user to check their PayPal account features |
| MCP server not running | "The PayPal connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with PayPal - let me try again." | Retry once; if still failing, check credentials |

---

## Scope Limitations

The PayPal MCP connector **can** do (via `@paypal/mcp` - 30 tools verified):
- Create, list, get, send, remind, and cancel invoices
- Generate invoice QR codes for easy payment
- Create, get, and capture (pay) payment orders
- Issue and check refunds
- List, get, and accept dispute claims
- Add and retrieve shipment tracking
- Create, list, update, and show product catalog items
- Create, list, update, and show subscription plans
- Create, show, update, and cancel subscriptions
- List transactions

The PayPal MCP connector **cannot** do:
- **Update shipment tracking** - only create and retrieve (no update tool in v1.8.1)
- **Retrieve merchant insights** - not available in v1.8.1
- **Withdraw funds** or transfer money between accounts
- **Access** PayPal Wallet, balance, or bank account details
- **Send** peer-to-peer payments (PayPal.me / friends and family)
- **Manage** account settings, users, or permissions
- **Access** PayPal Checkout button integration or web SDKs
- **Manage** PayPal Business Debit Card or credit products
- **Access** PayPal Giving Fund or charity features
- **Connect multiple PayPal accounts** at once - one set of credentials per `~/.claude.json` entry

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, sending, cancelling, or refunding** - summarise what you are about to do and wait for the user's OK before calling the tool. This is especially important for invoices, payments, refunds, and subscription changes.
- **Invoices start as drafts** - when creating an invoice, clarify that it has been created as a draft. The user must explicitly ask you to send it.
- **Format currency correctly** - use the currency from the PayPal response (USD, EUR, GBP, AUD, etc.) and format amounts with 2 decimal places.
- **Present data clearly** - format results as readable tables or summaries, not raw JSON.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 8 unpaid invoices totalling $12,450"), then offer to show details.
- **Pagination** - default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Sandbox vs Production** - the connector defaults to PRODUCTION. If the user chose sandbox in Step 1, `--paypal-environment=sandbox` is set in the args. The user can switch at any time by saying "switch my PayPal to the real account" or "switch my PayPal to sandbox" - re-generate the access token with the other environment's credentials, update `~/.claude.json`, and ask them to restart Claude Code.
- **Access token expiry** - PayPal tokens expire (~9 hours). On 401 errors, silently re-generate the token before asking the user to restart. Never mention tokens, OAuth, or expiry to the user - just say "your connection needed a quick refresh."
- **Refunds are irreversible** - always confirm the amount and transaction before processing a refund.
- **Disputes are time-sensitive** - when showing disputes, highlight any approaching deadlines.
- **Never log or echo credentials** - the access token, Client ID, and Secret must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting PayPal auth or API errors
- **stripe-connector**: Sibling payment connector - many businesses run both Stripe and PayPal
- **square-connector**: Sibling payment connector for in-person and online sales
- **hubspot-connector**: Same access-token → `~/.claude.json` pattern for a different first-party MCP server
