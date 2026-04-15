---
name: square-connector
description: "Read and update Square data via the official Square MCP server. Handles payments, refunds, catalog items, inventory, orders, customers, invoices, checkout, bookings, loyalty, gift cards, locations, merchant info, labor, disputes, and payouts. Supports two connection modes: a real Square account via the hosted remote MCP server (mcp.squareup.com, browser sign-in, no token handling) and a sandbox/demo using the local square-mcp-server npm package with a sandbox access token. Use this skill when the user asks about their Square, Square payments, Square orders, Square catalog, Square inventory, Square customers, Square invoices, Square bookings, Square loyalty, Square gift cards, Square disputes, Square payouts, or when they say 'connect my Square' or 'help me set up Square'. On the first use of any Square feature, run Phase 1 to configure the MCP server and authenticate before attempting any tool calls. Note: the Square MCP server is currently in beta — flag this to the user during setup."
allowed-tools: mcp__square__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - square
    - payments
    - catalog
    - inventory
    - orders
    - customers
    - mcp
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting Square MCP connection or API errors
    - skill: quickbooks-connector
      reason: Sibling financial-data connector — same conversational bootstrap pattern
    - skill: xero-connector
      reason: Sibling financial-data connector — same conversational bootstrap pattern
---

# Square Connector

## Overview

This skill lets you read and update a user's Square data on their behalf via the **official Square MCP server**. There is no CLI to install and no binary to download — Square ships a hosted remote MCP server (`https://mcp.squareup.com/sse`) for real accounts and a local npm package (`square-mcp-server`) for sandbox use. The connector is configured by writing a small block into the user's `~/.claude.json` and restarting Claude Code.

The skill has two phases:

- **Phase 1 — Configure & Auth.** A conversational bootstrap. The user has never used this before. You ask one question — real Square account, or sandbox/demo? — and then do all the technical work silently. You edit `~/.claude.json`, ask the user to restart Claude Code, and (for real accounts) they sign in to Square in their browser once. No Client ID, no Client Secret, no redirect URI for the real-account path.
- **Phase 2 — Use Tools.** Once the MCP server is connected, you call **three meta-tools** — `get_service_info`, `get_type_info`, and `make_api_request` — to discover and execute any Square API call. The Square MCP does not expose static per-endpoint tools (unlike Xero); instead it exposes the whole Square API surface through this discovery pattern. This skill teaches you the pattern and shows example flows for the most common workshop prompts.

**Beta notice.** The Square MCP server is currently in **beta**. Features and tool names may change without notice. This is worth telling the user once, warmly, during Phase 1 — not as a scary warning, but as a heads-up that if something misbehaves, it is usually Square's side and a retry fixes it.

**Which phase to run** — Before any tool call, check whether the Square MCP server is configured and reachable. Try a trivial meta-tool call:

```
mcp__square__get_service_info(service="merchants")
```

- Tool returns a list of methods → the MCP server is live. Go to Phase 2.
- Tool errors with "server not found" / "mcp__square__* not available" → the user has not configured it yet OR has not restarted Claude Code after the config was written. Run Phase 1 from the appropriate step.
- Tool errors with an auth-related message → the remote MCP server's browser sign-in lapsed (real-account path) or the sandbox token is wrong/expired (sandbox path). Run Phase 1 from Step 3.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md` — in particular:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say MCP, server, npm, npx, JSON, config file, env var, token, OAuth, scope, endpoint, SSE, remote, stdio, redirect URI, or file paths. If you must refer to a technical thing, name it plainly: "the Square tool I need", "your browser", "a small setting on your computer".
- **Tell them what is about to happen.** Before any action: "I am going to set up the Square connection on your computer — this takes about one minute."
- **React to success and failure warmly.** Good: "That worked — your Square is now connected." Bad: "MCP handshake failed at /sse."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem at all — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Configure & Auth

This phase asks which path the user wants, edits `~/.claude.json` with the correct MCP server block, asks the user to restart Claude Code, and verifies the connection on next use.

### Step 1 — Ask which path the user wants

Tell the user, in one short message:

> "Quick question before we start. Do you want to connect your **real Square account** (your live business data, read-only unless you ask me to change something), or would you prefer a **practice demo** using Square's sandbox fake data? Both are safe — the real account path uses Square's official sign-in, so I never see your password."

Also mention, warmly and once:

> "Heads-up: Square's connector for Claude is brand new and still in beta, so if anything looks a little off we can usually fix it by trying again."

Wait for the user to answer. Then:

- **Real account** → Step 2A.
- **Sandbox / demo / practice** → Step 2B.
- **Not sure** → "The real account is easier — no setup, just a browser sign-in. The sandbox is only useful if you want to experiment without touching real data. I'd suggest the real account unless you want to play around first."

### Step 2A — Real account path (edit ~/.claude.json for the hosted remote MCP)

Tell the user: "Great. I am going to set up the Square connection now — about thirty seconds, and then I will ask you to restart Claude Code once."

Silently:

1. Read `~/.claude.json` (it should exist — Claude Code creates it on first run). If it is missing, create it with `{}` as the starting content.
2. Parse it as JSON.
3. Ensure there is a top-level `mcpServers` object (create it if missing).
4. Add (or replace, if a `square` entry already exists) this block under `mcpServers`:

   ```json
   "square": {
     "command": "npx",
     "args": ["mcp-remote", "https://mcp.squareup.com/sse"]
   }
   ```

5. Write the file back, preserving all other existing keys and entries untouched. Use a safe write — read-modify-write, not overwrite.

Here is the shape the relevant fragment should end up as (the rest of the file is preserved):

```json
{
  "mcpServers": {
    "square": {
      "command": "npx",
      "args": ["mcp-remote", "https://mcp.squareup.com/sse"]
    }
  }
}
```

The `mcp-remote` helper is a small npm package that bridges Claude Code (which speaks stdio MCP) to Square's hosted remote MCP server (which speaks SSE). It is downloaded automatically by `npx` on first run — the user does not need to install anything manually, and they do **not** need Node.js installed separately. `npx` ships with Node, and Node is a dependency of Claude Code, so it is already on their machine.

Then go to Step 3.

### Step 2B — Sandbox path (edit ~/.claude.json for the local square-mcp-server)

Tell the user, in one short message:

> "The practice sandbox needs one thing from you: a special test key from Square's developer site. This is free and takes about two minutes. I will walk you through it."

Then, one instruction per message:

1. "Please open https://developer.squareup.com/apps in your browser and sign in with any email address. Tell me when you are on the Applications page."
2. "Click the **+** button (or **Create your first application** / **New application**) to create a new application. Give it any name — **Claude Assistant** is fine. Click **Create**. Tell me when you are on the new application's page."
3. "On the app page, make sure you are on the **Sandbox** tab at the top of the page (not Production). Then click **Credentials** in the left menu."
4. "You will see a field called **Sandbox Access Token**. Click the eye icon to reveal it, then copy the whole value and paste it to me. The Sandbox Application ID is a different value — we do not need that one, only the Access Token."

When the user pastes the token:

- If the value looks very short (under 40 characters), or looks like a placeholder, ask again: "That looks a little short to me — could you double-check you copied the Sandbox Access Token in full?"
- If it looks right, silently:

  1. Read `~/.claude.json` (create with `{}` if missing).
  2. Ensure a top-level `mcpServers` object.
  3. Add (or replace) this block under `mcpServers`:

     ```json
     "square": {
       "command": "npx",
       "args": ["square-mcp-server", "start"],
       "env": {
         "ACCESS_TOKEN": "<sandbox token from user>",
         "SANDBOX": "true",
         "DISALLOW_WRITES": "true"
       }
     }
     ```

  4. Substitute the actual pasted token for `<sandbox token from user>`.
  5. Write the file back, preserving everything else.

**Never echo the token back to the user after writing it.** Never include it in any output visible to the user.

Note on `DISALLOW_WRITES`: the sandbox defaults to read-only for workshop safety. If the user later says "I want to create a test invoice in the sandbox", you can offer to flip `DISALLOW_WRITES` to `false` in `~/.claude.json` after confirming with them — but default to read-only for first-time setup.

Then go to Step 3.

### Step 3 — Restart Claude Code

Tell the user, in one short message:

> "All set. I need you to **fully close and re-open Claude Code** once so it picks up the new Square connection. When you are back, just say 'I'm back' and I will verify everything is working."

This is the only moment in Phase 1 where the user has to do something technical, and it is just a restart. Do **not** try to hot-reload the MCP config — Claude Code only loads `~/.claude.json` on startup.

When the user comes back ("I'm back", "done", "ready", etc.), go to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check the connection is live."

Silently run a trivial meta-tool call via the Square MCP:

```
mcp__square__get_service_info(service="merchants")
```

- Returns a method list → the server is reachable. Continue.
- Returns an error about the server not being found → either the user did not restart Claude Code (ask them to confirm they fully quit and reopened), or the `~/.claude.json` edit failed. Re-check the file, fix if needed, and ask for another restart.
- Returns an auth error on the real-account path → the browser sign-in has not happened yet. On the real-account path, the *first* call to the Square remote MCP will automatically trigger a browser window asking the user to sign in to Square and consent. Tell the user: "Square is about to open a sign-in page in your browser. Please sign in to your Square account and click **Allow** or **Approve** — then come back and tell me you're done." Then retry the verify call.
- Returns an auth error on the sandbox path → the pasted token was wrong. Say: "The test key from Square didn't work. Let's grab a fresh one." Go back to Step 2B.

Once `get_service_info` succeeds, fetch the merchant's name for the success message. The Square MCP uses short method names (`list`, `get`, `create`, etc.) with the service passed separately — not `list_merchants` or `retrieve_merchant`:

```
mcp__square__make_api_request(
  service="merchants",
  method="list",
  request={}
)
```

Response shape: `{"merchant": [{"business_name": "...", "country": "...", "currency": "...", ...}]}`. Parse the first merchant's `business_name` for the success message.

If the merchants call fails, try `locations` as a fallback — every Square account has at least one location:

```
mcp__square__make_api_request(service="locations", method="list", request={})
```

Use the first location's `name` or `business_name` for the success message.

### Step 5 — Success message

Tell the user, in one short message:

> "All done. I am now connected to your Square account **[business name]**. You can ask me things like 'show me my recent Square payments', 'list my Square customers', 'what's in my Square catalog', or 'show me my Square orders from this week'."

On the sandbox path, adjust:

> "All done. I am now connected to your Square **practice sandbox**. You can ask me to list payments, customers, catalog items, orders — the data is all fake but the tools all work the same. Let me know if you want me to switch to your real Square account later."

Save to memory that the Square MCP is configured, which path the user chose (real vs sandbox), and the merchant name, so that on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools (the discovery pattern)

The Square MCP server does **not** expose a static per-endpoint tool set like the Xero connector does. Instead it exposes the entire Square API surface through **three meta-tools**:

| Meta-tool | What it does |
|---|---|
| `mcp__square__get_service_info` | Lists the methods available on a Square service (e.g. `payments`, `catalog`, `customers`). Call this first when you don't know the exact method name. |
| `mcp__square__get_type_info` | Returns the JSON schema for a specific request type — parameter names, types, which are required, nested object shapes. Call this before building a `request` payload if you're not sure of the fields. |
| `mcp__square__make_api_request` | Executes the API call. Takes `service`, `method`, and `request` (a JSON object matching the request type schema). Returns the Square API response. |

### The three-step flow

For any Square task, the pattern is:

1. **Discover the service and method.** Call `get_service_info(service="<service>")` to see what methods exist on a service. This is cheap and often unnecessary if you already know the method name from prior use or from this skill's example flows below.
2. **Check the parameter schema.** Call `get_type_info(type="<request type name>")` to see what fields the request needs. Again, skip this if you already know the shape from the examples below — you only need it for fields you are uncertain about.
3. **Execute.** Call `make_api_request(service=..., method=..., request={...})` with the concrete payload.

For simple read-only queries with no parameters, you can often skip straight to step 3.

### Available services

The Square MCP exposes these services (as of the current beta). Use the exact lowercase names below as the `service` parameter:

| Service | What it covers |
|---|---|
| `payments` | Payments — list, retrieve, create, complete, cancel |
| `refunds` | Refunds against payments |
| `catalog` | Catalog items, variations, categories, modifiers, taxes, discounts |
| `inventory` | Inventory counts, adjustments, transfers, physical counts |
| `orders` | Orders — list (search), retrieve, create, update, calculate |
| `customers` | Customer directory — list, retrieve, search, create, update, delete |
| `invoices` | Invoices — list, retrieve, create, publish, cancel, delete |
| `checkout` | Hosted checkout links for payment collection |
| `bookings` | Appointments — list, retrieve, create, cancel (Square Appointments) |
| `loyalty` | Loyalty programs, accounts, rewards, events |
| `giftcards` | Gift card activation, balance, redemption, linking |
| `giftcardactivities` | Gift card activity history |
| `locations` | Business locations — list, retrieve, create, update |
| `merchants` | Merchant account info — list, retrieve |
| `labor` | Team member shifts, timecards, break types (Square Team / Labor) |
| `disputes` | Chargebacks and disputes |
| `payouts` | Bank payouts from Square to the merchant's bank account |
| `subscriptions` | Square Subscriptions — recurring billing plans |
| `team` | Team members |
| `terminal` | Square Terminal API — checkout, refund, action |
| `cards` | Saved cards on file |
| `devices` | Square hardware devices |
| `vendors` | Vendor/supplier directory |

This list mirrors the Square API surface. If you aren't sure whether a service exists, call `get_service_info(service="<name>")` — if it errors, the service name is wrong.

**Method naming convention.** The Square MCP uses short verbs as method names: `list`, `get`, `create`, `update`, `delete`, `search`, `cancel`, `publish`, etc. These are NOT `list_payments` or `retrieve_merchant` — they are just `list` and `get`, with the service passed separately. Some services have additional camelCase methods (`catalog.searchObjects`, `catalog.upsertObject`, `inventory.getCount`, `inventory.batchGetcounts`, `payouts.listEntries`, `refunds.payment`). When in doubt, call `get_service_info(service="<name>")` to see the exact method list before calling `make_api_request`.

---

## Phase 2 — Example flows

These are the most common workshop prompts, rewritten in the three-step discovery pattern.

### Example 1 — List recent payments

User says: *"Show me my recent Square payments"*

```
mcp__square__make_api_request(
  service="payments",
  method="list",
  request={}
)
```

Response is a paginated list of payment objects. Fields of interest per payment: `id`, `amount_money.amount`, `amount_money.currency`, `status` (`APPROVED`, `PENDING`, `COMPLETED`, `CANCELED`, `FAILED`), `created_at`, `source_type`, `receipt_number`, `customer_id`.

To filter by date:

```
mcp__square__make_api_request(
  service="payments",
  method="list",
  request={
    "begin_time": "2026-04-01T00:00:00Z",
    "end_time": "2026-04-14T23:59:59Z"
  }
)
```

Square amounts are in **minor units** (cents). Format as dollars by dividing by 100 when presenting to the user.

### Example 2 — Retrieve a specific payment

User says: *"Show me payment abc123"*

```
mcp__square__make_api_request(
  service="payments",
  method="get",
  request={"payment_id": "abc123"}
)
```

### Example 3 — List customers

User says: *"Show me my Square customers"*

```
mcp__square__make_api_request(
  service="customers",
  method="list",
  request={}
)
```

To search by name or email, use the search endpoint instead:

```
mcp__square__get_type_info(type="SearchCustomersRequest")
# See the filter/query schema

mcp__square__make_api_request(
  service="customers",
  method="search",
  request={
    "query": {
      "filter": {
        "email_address": {"exact": "jane@example.com"}
      }
    }
  }
)
```

Fields of interest per customer: `id`, `given_name`, `family_name`, `email_address`, `phone_number`, `company_name`, `created_at`.

### Example 4 — Create a customer

User says: *"Add a new Square customer called Jane Doe"*

Always confirm details with the user in plain English before calling the create endpoint.

```
mcp__square__get_type_info(type="CreateCustomerRequest")
# See required vs optional fields

mcp__square__make_api_request(
  service="customers",
  method="create",
  request={
    "given_name": "Jane",
    "family_name": "Doe",
    "email_address": "jane@example.com"
  }
)
```

After the call returns, tell the user: "I've added **Jane Doe** to your Square customers."

### Example 5 — List catalog items

User says: *"Show me what's in my Square catalog"*

```
mcp__square__make_api_request(
  service="catalog",
  method="list",
  request={"types": "ITEM"}
)
```

The `types` parameter filters by object type. Common values: `ITEM` (products), `ITEM_VARIATION` (sizes/options), `CATEGORY`, `MODIFIER`, `MODIFIER_LIST`, `DISCOUNT`, `TAX`, `IMAGE`. Multiple can be comma-separated.

Response contains a list of `CatalogObject` entries. For `ITEM` objects, the human-visible name is at `item_data.name`, description at `item_data.description`, and variations (with prices) are nested in `item_data.variations`.

### Example 6 — Check inventory for a catalog item

User says: *"How many [item] do I have in stock?"*

First, find the item's `ITEM_VARIATION` ID (inventory is tracked at the variation level, not the item level):

```
mcp__square__make_api_request(
  service="catalog",
  method="list",
  request={"types": "ITEM"}
)
```

Locate the item by name, then read `item_data.variations[0].id` (or the relevant variation). Then:

```
mcp__square__make_api_request(
  service="inventory",
  method="getCount",
  request={"catalog_object_id": "<variation_id>"}
)
```

Response includes `counts` — an array of `{location_id, quantity, state}`. `state` is typically `IN_STOCK` or `SOLD`.

### Example 7 — List invoices

User says: *"Show me my Square invoices"*

```
mcp__square__make_api_request(
  service="invoices",
  method="list",
  request={"location_id": "<location_id from Phase 1 Step 4 fallback>"}
)
```

Square invoice listing **requires** a `location_id`. If you don't have one cached, fetch it first:

```
mcp__square__make_api_request(service="locations", method="list", request={})
# Use the first location's id
```

Fields of interest per invoice: `id`, `invoice_number`, `title`, `status` (`DRAFT`, `UNPAID`, `SCHEDULED`, `PARTIALLY_PAID`, `PAID`, `CANCELED`, `FAILED`), `primary_recipient.customer_id`, `order_id`, `payment_requests[].due_date`, `payment_requests[].computed_amount_money`.

### Example 8 — List locations

User says: *"What Square locations do I have?"*

```
mcp__square__make_api_request(
  service="locations",
  method="list",
  request={}
)
```

Fields of interest: `id`, `name`, `address.address_line_1`, `address.locality`, `address.administrative_district_level_1`, `timezone`, `status` (`ACTIVE` or `INACTIVE`), `business_name`, `currency`.

### Example 9 — Recent orders

User says: *"Show me my Square orders from this week"*

Orders use a search endpoint, not list:

```
mcp__square__make_api_request(
  service="orders",
  method="search",
  request={
    "location_ids": ["<location_id>"],
    "query": {
      "filter": {
        "date_time_filter": {
          "created_at": {
            "start_at": "2026-04-08T00:00:00Z",
            "end_at": "2026-04-14T23:59:59Z"
          }
        }
      },
      "sort": {
        "sort_field": "CREATED_AT",
        "sort_order": "DESC"
      }
    }
  }
)
```

Fields of interest per order: `id`, `state` (`OPEN`, `COMPLETED`, `CANCELED`, `DRAFT`), `created_at`, `total_money.amount`, `line_items[].name`, `line_items[].quantity`, `customer_id`.

### Example 10 — Recent payouts (money transferred to the user's bank)

User says: *"When did Square last pay me out?"*

```
mcp__square__make_api_request(
  service="payouts",
  method="list",
  request={"location_id": "<location_id>"}
)
```

Fields: `id`, `status` (`SENT`, `PAID`, `FAILED`), `amount_money`, `destination.type`, `arrival_date`.

---

## Prompt-to-Flow Mapping

| What the user says | Service | Method |
|---|---|---|
| "Show me my Square payments" | `payments` | `list` |
| "Show me payment abc123" | `payments` | `get` |
| "Refund this payment" | `refunds` | `payment` (confirm first — unusual name, this is the create-refund method) |
| "Show me my Square customers" | `customers` | `list` |
| "Find [name] in my Square customers" | `customers` | `search` |
| "Add a Square customer" | `customers` | `create` (confirm first!) |
| "Show me my Square catalog" | `catalog` | `list` |
| "How much [item] is in stock?" | `inventory` | `getCount` |
| "Show me my Square invoices" | `invoices` | `list` |
| "Create a Square invoice" | `invoices` | `create` (confirm first!) |
| "What Square locations do I have?" | `locations` | `list` |
| "Show me my Square orders this week" | `orders` | `search` with date filter |
| "When did Square last pay me out?" | `payouts` | `list` |
| "Show me Square disputes" | `disputes` | `list` |
| "Show me my Square bookings" | `bookings` | `list` |
| "What loyalty points does [customer] have?" | `loyalty` | `search` (on loyalty accounts) |
| "Check a gift card balance" | `giftcards` | `get` |
| "What Square account am I connected to?" | `merchants` | `list` |
| "Connect my Square" / "Help me set up Square" | — | **Run Phase 1** |

---

## When to use `get_service_info` and `get_type_info`

You do not need to call the discovery meta-tools on every request. The example flows above already give you the service name, method name, and request shape for the 10 most common patterns. Call discovery tools when:

- **The user asks for something not in the examples above** (e.g. "list my team members' shifts" — you know it's `labor`, but you don't know the exact method). Start with `get_service_info(service="labor")`.
- **The request payload fails with a schema error.** Call `get_type_info(type="<RequestType>")` to see the exact field names and required flags, then rebuild.
- **You want to offer the user a feature you aren't sure Square supports.** Call `get_service_info` on the relevant service to check.

Avoid calling discovery tools *preemptively* on every turn — it adds latency and clutters your working context. Call them only when you need the information.

---

## Error Handling

The Square MCP beta returns errors as part of the `make_api_request` result. Every Phase 2 invocation should inspect the response and respond accordingly:

| Error shape | What it means | How to respond |
|---|---|---|
| `"UNAUTHORIZED"` / `401` | Auth has lapsed. Real-account path: browser session expired. Sandbox path: token was revoked or wrong. | **Run Phase 1 from Step 3 (restart)**. Do not ask the user to run anything; you run it. |
| `"NOT_FOUND"` / `404` | Resource not found (payment ID, customer ID, etc.) | Tell the user "I couldn't find [resource]. Let me list the recent ones so you can pick." Then run a list command. |
| `"INVALID_REQUEST_ERROR"` / `400` | The `request` payload is malformed. | Call `get_type_info(type="<RequestType>")` to verify the schema, then rebuild. |
| `"RATE_LIMITED"` / `429` | Hit the Square API rate limit. | Wait 30 seconds, retry once. Tell the user: "Square is asking me to slow down — let me wait a moment." |
| `"FORBIDDEN"` / `403` | Missing scope / permission. Real account may not have granted all scopes during sign-in. | Tell the user: "Your Square sign-in doesn't include permission for that. Let me reconnect you with the right permissions." Run Phase 1 from Step 3. |
| `"INTERNAL_SERVER_ERROR"` / `500` | Square-side issue. Often transient, especially on the beta MCP server. | Retry once after 2 seconds. If still failing: "Square's side is having a moment. Want me to try again in a minute, or move on to something else?" |
| `"MCP server not found"` / tool name not available | The MCP server isn't configured or Claude Code wasn't restarted. | Run Phase 1 from Step 2A or 2B (check `~/.claude.json`), then Step 3. |

**Never show raw error codes or JSON to the user.** Translate into plain English, tell the user what you're doing next, and re-run or fall back to Phase 1 as appropriate.

---

## Scope Limitations

The Square connector **can** read and write (write requires confirmation): payments, refunds, catalog items, inventory counts, orders, customers, invoices, checkout links, bookings, loyalty accounts and rewards, gift cards, locations, merchant info, team labor / shifts, disputes, and payouts.

It **cannot** access:
- **Square Banking / Square Savings** balances and internal transfers — not exposed by the Square MCP beta.
- **Square for Restaurants** specific endpoints beyond the standard orders/catalog surface.
- **Subscriptions** (Square Subscriptions) — depends on MCP beta coverage; confirm with `get_service_info(service="subscriptions")` if the user asks.
- **Tax filings / 1099-K data.**
- **Historical data older than Square's API retention** (typically the last 2 years for payments).

The sandbox path defaults to **read-only** (`DISALLOW_WRITES=true`). You can offer to flip this to allow writes in the sandbox after confirming with the user, but on first setup, keep writes disabled to prevent accidents.

The real-account path permissions are whatever the user granted during browser sign-in. If a write fails with `FORBIDDEN`, ask the user to reconnect and grant the additional scope.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before writing** — payments, refunds, creating customers, creating invoices, creating catalog items, creating orders. Summarise what you are about to create or change in plain English and wait for the user's OK before calling `make_api_request`.
- **Refunds are irreversible** — double-confirm before calling the refund-create method (the Square MCP exposes this as `refunds.payment`, not `create`). Quote the payment amount, the payment ID, and the customer name (if available) back to the user and require an explicit "yes, refund it".
- **Format currency correctly** — Square amounts are in **minor units** (cents). Divide by 100 and present with 2 decimal places and the correct currency symbol from `currency` (e.g. `USD` → `$`, `AUD` → `$`, `GBP` → `£`, `EUR` → `€`).
- **Use ISO 8601 UTC timestamps** in request payloads (e.g. `2026-04-14T00:00:00Z`). Square is picky about timezone suffixes.
- **Pagination** — Square list endpoints return a `cursor` field when results are paginated. If the user asks for "all" of something large, iterate until the cursor is empty. For "recent" or "latest", the first page is usually enough.
- **Location-scoped endpoints** — invoices, orders, payouts, bookings, and team/labor all require a `location_id`. Cache the first `location_id` from `locations.list` in memory during a session so you don't have to re-fetch it for every call.
- **Sandbox awareness** — when on the sandbox path, gently remind the user every so often that they are looking at practice data. Say "practice account" or "sandbox", not "fake".
- **Beta awareness** — if something fails inexplicably and retries don't help, tell the user: "Square's connector is still in beta, so occasionally it gets confused. Would you like me to try a different approach, or shall we come back to this later?" — do not blame the user.
- **Never log or echo the sandbox token** — if the user is on the sandbox path, the `ACCESS_TOKEN` env var in `~/.claude.json` must never appear in any output visible to the user. Do not quote the file contents back.
- **Auth errors (401/UNAUTHORIZED)** → run Phase 1 from Step 3 (restart). You do the work; the user just restarts.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap
- **systematic-debugging**: For troubleshooting Square MCP connection or API errors
- **quickbooks-connector**: Sibling financial-data connector — same conversational bootstrap pattern, different platform
- **xero-connector**: Sibling financial-data connector — same conversational bootstrap pattern, different platform
- **Square Developer Docs** (external): https://developer.squareup.com/docs — definitive reference for every Square API endpoint, request type, and response shape. Use this as the authoritative source when the MCP discovery tools don't have enough detail.
