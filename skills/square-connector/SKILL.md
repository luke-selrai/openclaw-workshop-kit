---
name: square-connector
description: "Read and update Square data via the official Square MCP server. Handles payments, refunds, catalog items, inventory, orders, customers, invoices, checkout, bookings, loyalty, gift cards, locations, merchant info, labor, disputes, and payouts. Supports two connection modes: a real Square account via the hosted remote MCP server (mcp.squareup.com, browser sign-in, no token handling) and a sandbox/demo using the local square-mcp-server npm package with a sandbox access token. Drives the entire setup autonomously through a Playwright MCP browser — for sandbox, walks developer.squareup.com to toggle Sandbox mode, open or create an app, reveal the Sandbox Access Token, and read it from the DOM; for the real account, drives the OAuth consent flow in the same Playwright window. The only human moments are signing in to Square and (real-account path) clicking Allow on the consent screen. Use this skill when the user asks about their Square, Square payments, Square orders, Square catalog, Square inventory, Square customers, Square invoices, Square bookings, Square loyalty, Square gift cards, Square disputes, Square payouts, or when they say 'connect my Square' or 'help me set up Square'. On the first use of any Square feature, run Phase 1 to configure the MCP server and authenticate before attempting any tool calls. Note: the Square MCP server is currently in beta — flag this to the user during setup."
allowed-tools: mcp__square__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
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
    - skill: superpowers:systematic-debugging
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

- **Phase 1 — Install & Auth (autonomous via Playwright).** Claude drives the entire setup inside a Playwright MCP browser. On the **sandbox path**, Claude opens `developer.squareup.com/apps`, waits for the user to sign in, toggles the dashboard to Sandbox mode, opens (or creates) an app, clicks the eye icon on **Sandbox Access Token**, reads the token directly from the DOM, registers the MCP server, and verifies — without ever asking the user to copy, paste, or navigate menus themselves. On the **real-account path**, Claude registers the hosted MCP server, drives Square's OAuth URL in the same Playwright window, waits for the user to sign in and click **Allow**, then auto-detects the callback. The user's only actions are signing in to Square (both paths) and clicking **Allow** on the consent screen (real-account path). No Client ID, no Client Secret, no redirect URI on the real-account path.
- **Phase 2 — Use Tools.** Once the MCP server is connected, you call **three meta-tools** — `get_service_info`, `get_type_info`, and `make_api_request` — to discover and execute any Square API call. The Square MCP does not expose static per-endpoint tools (unlike Xero); instead it exposes the whole Square API surface through this discovery pattern. This skill teaches you the pattern and shows example flows for the most common workshop prompts.

**Beta notice.** The Square MCP server is currently in **beta**. Features and tool names may change without notice. This is worth telling the user once, warmly, during Phase 1 — not as a scary warning, but as a heads-up that if something misbehaves, it is usually Square's side and a retry fixes it.

**Which phase to run** — Before any tool call, check whether the Square MCP server is configured and reachable. Try a trivial meta-tool call:

```
mcp__square__get_service_info(service="merchants")
```

- Tool returns a list of methods → the MCP server is live. Go to Phase 2.
- Tool errors with "server not found" / "mcp__square__* not available" → the user has not configured it yet OR has not restarted Claude Code after the config was written. Run Phase 1 from the appropriate step.
- Tool errors with an auth-related message → the remote MCP server's browser sign-in lapsed (real-account path) or the sandbox token is wrong/expired (sandbox path). Re-run Phase 1 — the Playwright browser will reuse the existing session, so the user usually doesn't need to sign in again.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Square (and clicks **Allow** on the real-account consent screen). Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll the developer dashboard, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and (real-account path) "please click Allow on the screen Square just showed you."
- **Plain English only.** No jargon. Never say MCP, server, npm, npx, bash, CLI, terminal, JSON, config file, env var, token, OAuth, scope, endpoint, SSE, remote, stdio, redirect URI, Playwright, browser automation, DOM, selector, or file paths. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must refer to a technical thing, name it plainly: "the Square tool I need", "your browser", "a small setting on your computer".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Square for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Square is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Square is now connected." Bad: "MCP handshake failed at /sse."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem at all — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo the sandbox token** back to the user. Never include it in any output visible to the user.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only roles are: (1) sign in to Square in the Playwright window when prompted, and (2) on the real-account path, click **Allow** on Square's consent screen. Claude handles every other step — navigation, sandbox-mode toggle, app open/create, token reveal, DOM read, MCP register, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Sandbox Access Token reveal control"). Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_type` / `browser_evaluate`. Do not hardcode CSS selectors — Square's developer dashboard UI changes. Re-snapshot whenever the page state changes.

### Step 1 — Ask which path the user wants

Tell the user, in one short message:

> "Quick question before we start. Do you want to connect your **real Square account** (your live business data, read-only unless you ask me to change something), or would you prefer a **practice demo** using Square's sandbox fake data? Both are safe — I'll handle the setup either way; you'll just sign in once."

Also mention, warmly and once:

> "Heads-up: Square's connector for Claude is brand new and still in beta, so if anything looks a little off we can usually fix it by trying again."

Wait for the user to answer. Then:

- **Real account** → Step 2 (Real-account branch below).
- **Sandbox / demo / practice** → Step 2 (Sandbox branch below).
- **Not sure** → "The real account is easier — no setup, just a browser sign-in. The sandbox is only useful if you want to experiment without touching real data. I'd suggest the real account unless you want to play around first."

---

### Sandbox branch — Step 2: Open developer.squareup.com and confirm sign-in

Tell the user, in one short message:

> "I'm opening a browser window for you — please sign in to Square in there when it appears, and I'll handle the rest."

Call `mcp__playwright__browser_navigate({ url: "https://developer.squareup.com/apps" })`. Take a `mcp__playwright__browser_snapshot()` and reason from it:

- **Logged in** (you see the Applications dashboard — a list of apps with **+ Create app** / **New application** controls, or an empty-state with the same control) → continue to Step 3.
- **Not logged in** (sign-in form, "Sign in with Square" button, or the marketing landing page) → tell the user *once*: *"The browser window is open — please sign in to Square when you're ready."* Then poll silently with `mcp__playwright__browser_wait_for({ text: "Applications" })` (or wait for any post-login dashboard element you can see in the snapshot — the **+ Create app** button, the dashboard header, etc.) with a generous timeout. Do **not** ask the user to confirm when they're done — detect the logged-in dashboard from the snapshot yourself. SSO redirects, password resets, and 2FA all resolve back to the same dashboard.

If `browser_wait_for` times out (5+ minutes), then — and only then — check in with the user: *"Still on the sign-in page? Anything I can help with?"*

### Sandbox branch — Step 3: Make sure the dashboard is in Sandbox mode

Square's developer dashboard has a **Sandbox / Production** mode switch. The Sandbox Access Token only appears when the dashboard is in Sandbox mode.

Take a fresh snapshot. Reason: is the mode toggle showing **Sandbox** or **Production**?

- **Already on Sandbox** → continue to Step 4.
- **On Production** → locate the mode toggle in the snapshot (usually a top-bar switch, segmented control, or sidebar selector labelled **Sandbox** / **Production**) and click **Sandbox** via `browser_click`. Re-snapshot to confirm the dashboard now shows Sandbox apps and labels.
- **Toggle not visible** → it may be inside a profile/account menu. Snapshot the page, reason about likely entry points, and try one — re-snapshot after each click. If after two attempts you still cannot toggle to Sandbox, fall back to navigating directly to `https://developer.squareup.com/apps` again — the URL preserves mode in some sessions — and re-evaluate.

### Sandbox branch — Step 4: Open or create a Sandbox application

Take a fresh snapshot of the Applications list (in Sandbox mode).

- **At least one Sandbox app already exists** → click the first one in the list via `browser_click`. Reuse is preferred over create — fewer clicks, less workspace clutter.
- **No apps exist** → click **+ Create app** (or **Create your first application** / **New application**, whichever the snapshot shows) via `browser_click`. A modal or full-page form will ask for an app name. Type `Claude Assistant` into the App Name field via `browser_type`. If a checkbox or radio for "use this app for sandbox testing" appears, ensure it's checked via `browser_click`. Click **Create app** via `browser_click`.

After either branch, Square redirects to the app's overview / credentials page. Take a fresh snapshot to confirm — you should see the app's name at the top, and a left-side or tabbed navigation that includes **Credentials** / **Sandbox** / **OAuth** sections.

### Sandbox branch — Step 5: Reveal the Sandbox Access Token and read it from the page

On the app page, locate the **Sandbox Access Token** field. Depending on the dashboard layout, it may be on the main credentials page, behind a **Credentials** tab/sidebar item, or under a **Sandbox** tab. Take a snapshot, reason about the layout, and click whichever entry surfaces the **Sandbox Access Token** label.

The token is masked by default. Find the **eye icon** (or **Show** / **Reveal** button) next to **Sandbox Access Token** and click it via `browser_click`. Re-snapshot.

> **Important.** The page also shows the **Sandbox Application ID** and (sometimes) a **Production Access Token**. Do not capture either of those. Match the label `Sandbox Access Token` (or `Access Token` clearly inside the Sandbox section) — never the Application ID, never anything labelled Production.

Read the revealed token from the DOM via `browser_evaluate`. Adapt the selector based on what the snapshot shows; an example shape is:

```javascript
() => {
  const labels = Array.from(document.querySelectorAll('label, dt, [data-testid], h3, h4, span'));
  const labelEl = labels.find(el => /sandbox\s+access\s+token/i.test((el.textContent ?? '').trim()));
  if (!labelEl) return null;
  // Walk up to a reasonable container, then look for the visible value (input/textarea/code/pre).
  const scope = labelEl.closest('section, div, li, tr, [class*="credential"], [class*="token"]') ?? labelEl.parentElement;
  const valueEl = scope?.querySelector('input[type="text"], input[readonly], textarea, code, pre, [data-testid*="token-value"]');
  return (valueEl?.value ?? valueEl?.textContent ?? '').trim() || null;
}
```

**Validation rules (silent):**

- Must look like a Square sandbox token: typically starts with `EAAA` and is 40+ characters of base64url-ish characters.
- Must NOT match the Application ID shape (Application IDs typically start with `sandbox-sq0idb-` or `sq0idp-` and are visibly shorter than the access token).

If two snapshot/read attempts don't yield a valid Sandbox Access Token, stop and tell the user, in one short message: *"I'm having trouble reading the test key off the page — could you tell me what you can see under the Credentials section?"* Use their description to locate the right control, then re-attempt the read with an adjusted selector.

Hold the token in memory for Step 6. Never write it to chat.

### Sandbox branch — Step 6: Save the connection (silent)

Silently register the MCP server. **Prefer `claude mcp add` via Bash** — it's the official CLI path, handles JSON merging correctly, and avoids touching `~/.claude.json` directly.

```bash
claude mcp add square \
  --scope user \
  --env ACCESS_TOKEN="<token captured in Step 5>" \
  --env SANDBOX="true" \
  --env DISALLOW_WRITES="true" \
  -- npx -y square-mcp-server start
```

`DISALLOW_WRITES=true` keeps the sandbox read-only for workshop safety. If the user later asks to create a test invoice or customer in the sandbox, you can offer to flip it to `false` after confirming — but default to read-only on first setup.

**Fallback if `claude mcp add` fails** (older Claude Code version, or CLI not on PATH) — write directly to `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) using the equivalent JSON shape:

```json
{
  "mcpServers": {
    "square": {
      "command": "npx",
      "args": ["-y", "square-mcp-server", "start"],
      "env": {
        "ACCESS_TOKEN": "<token>",
        "SANDBOX": "true",
        "DISALLOW_WRITES": "true"
      }
    }
  }
}
```

Read-modify-write — merge into the existing `mcpServers` object, never overwrite. If `~/.claude.json` doesn't exist, create it with `{}` first. If it's corrupt, back up to `~/.claude.json.backup` first.

**Never echo the access token back to the user.** Never include it in any output visible to the user. Never log it to the conversation, even truncated.

### Sandbox branch — Step 7: Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"I've saved your connection — let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__square__*` tools are available** (the MCP server has reloaded): run the smoke call below. If it returns, capture the merchant/business name and continue to Step 8.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user *"All saved. Please close and reopen Claude Code once, then say 'test my Square' and I'll verify the connection."* When they come back, retry the smoke call.

Smoke call — fetch the practice merchant name:

```
mcp__square__make_api_request(service="merchants", method="list", request={})
```

If `merchants.list` errors, fall back to `locations.list` — every Square account, sandbox or real, has at least one location:

```
mcp__square__make_api_request(service="locations", method="list", request={})
```

Use the first merchant's `business_name` (or, on fallback, the first location's `name`) for the success message.

If verification returns an auth-shaped error (`UNAUTHORIZED` / `401`) the captured token was wrong or revoked. Tell the user: *"The test key didn't take — let me grab a fresh one,"* then re-run Sandbox Steps 2–6 (the Playwright browser will resume the existing session, so the user usually doesn't need to sign in again).

### Sandbox branch — Step 8: Success message

Tell the user, in one short message:

> "All done. I'm now connected to your Square **practice sandbox** (account name **[business name]**). You can ask me to list payments, customers, catalog items, orders — the data is all fake but the tools all work the same. Let me know if you want me to switch to your real Square account later."

Save to memory that the Square MCP is configured, the user chose the **sandbox** path, and the merchant name, so that on the next use you go straight to Phase 2.

---

### Real-account branch — Step 2: Save the connection (silent)

Silently register the hosted Square MCP. **Prefer `claude mcp add` via Bash** — it merges `~/.claude.json` correctly.

```bash
claude mcp add square \
  --scope user \
  -- npx -y mcp-remote https://mcp.squareup.com/sse
```

The `mcp-remote` helper is a small npm package that bridges Claude Code (which speaks stdio MCP) to Square's hosted remote MCP server (which speaks SSE). It is downloaded automatically by `npx` on first run — the user does not need to install anything manually, and `npx` ships with Node, which is already a dependency of Claude Code.

**Fallback if `claude mcp add` fails** — write directly to `~/.claude.json` using the equivalent JSON shape:

```json
{
  "mcpServers": {
    "square": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.squareup.com/sse"]
    }
  }
}
```

Read-modify-write — merge into the existing `mcpServers` object, never overwrite.

### Real-account branch — Step 3: Drive Square's OAuth in the Playwright window

Tell the user, in one short message:

> "I'm opening a browser window for you — please sign in to Square in there, then click **Allow** when Square asks. I'll handle the rest."

Trigger the OAuth start. The hosted Square remote MCP issues an OAuth authorization URL on first use; the goal is to present that URL inside the Playwright browser instead of the user's system browser, so the same window can detect the post-Allow callback.

> **Reasoning model.** The exact URL `mcp-remote` opens on first run depends on its current implementation (typically `https://mcp.squareup.com/oauth/authorize?...` with a localhost callback). Capture or reconstruct that URL — for example, by reading what `mcp-remote` prints to stderr on first connect, or by snapshotting whatever sign-in URL the MCP layer surfaces — and pass it to `browser_navigate`. Do **not** hardcode the URL into chat responses; resolve it from the live MCP startup output.

Call `mcp__playwright__browser_navigate({ url: "<oauth start URL>" })`. Take a snapshot and reason from it:

- **Square sign-in form** → tell the user *once*: *"The browser window is open — please sign in to Square when you're ready."* Then poll silently with `mcp__playwright__browser_wait_for` for the next step (consent screen text such as "wants access" or the **Allow** button label).
- **Already signed in, on the consent screen** → tell the user, in one short message: *"Square just opened a permissions screen — please click **Allow** so I can finish connecting."* Then poll silently with `mcp__playwright__browser_wait_for({ text: "<post-callback marker>" })` — for example, the localhost callback page that `mcp-remote` serves usually displays a "you can close this window" / "authentication complete" message.
- **Marketing / landing page** → re-trigger the OAuth start (the MCP server may need another connect attempt).

Generous timeouts. Do **not** ask the user "tell me when you're done" — detect the post-Allow callback from the snapshot or `browser_wait_for` yourself. SSO redirects and 2FA all resolve back to the callback page.

If the user clicks **Cancel** / **Deny** instead of **Allow**, the callback won't fire and the snapshot will show a Square error or stay on the consent page. Tell them: *"Looks like you cancelled the permissions — no problem. Want me to try again?"* If yes, re-trigger the OAuth start and re-navigate.

### Real-account branch — Step 4: Close the browser and verify

Close the Playwright browser via `mcp__playwright__browser_close()`. The OAuth tokens now live in `mcp-remote`'s local store.

Tell the user: *"I've connected your Square — let me check it works."*

Same as the sandbox branch: if `mcp__square__*` tools are available, run the smoke call below; otherwise tell the user to close and reopen Claude Code once, and verify when they come back.

```
mcp__square__get_service_info(service="merchants")
```

Then, for the merchant name:

```
mcp__square__make_api_request(service="merchants", method="list", request={})
```

Fall back to `locations.list` if `merchants.list` errors.

If verification returns an auth-shaped error (`UNAUTHORIZED` / `401`), the OAuth flow didn't complete cleanly. Tell the user: *"The sign-in didn't take — let me try once more,"* then re-run Real-account Step 3.

### Real-account branch — Step 5: Success message

Tell the user, in one short message:

> "All done. I am now connected to your Square account **[business name]**. You can ask me things like 'show me my recent Square payments', 'list my Square customers', 'what's in my Square catalog', or 'show me my Square orders from this week'."

Save to memory that the Square MCP is configured, the user chose the **real-account** path, and the merchant name, so that on the next use you go straight to Phase 2.

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
  request={"location_id": "<location_id from Phase 1 verify-step fallback>"}
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
| `"UNAUTHORIZED"` / `401` | Auth has lapsed. Real-account path: browser session expired. Sandbox path: token was revoked or wrong. | **Re-run Phase 1 autonomously.** Open Playwright back to `developer.squareup.com/apps` (sandbox) or re-trigger the OAuth start (real-account); the existing browser session usually carries over so the user doesn't need to sign in again. Do not ask the user to run anything; you run it. |
| `"NOT_FOUND"` / `404` | Resource not found (payment ID, customer ID, etc.) | Tell the user "I couldn't find [resource]. Let me list the recent ones so you can pick." Then run a list command. |
| `"INVALID_REQUEST_ERROR"` / `400` | The `request` payload is malformed. | Call `get_type_info(type="<RequestType>")` to verify the schema, then rebuild. |
| `"RATE_LIMITED"` / `429` | Hit the Square API rate limit. | Wait 30 seconds, retry once. Tell the user: "Square is asking me to slow down — let me wait a moment." |
| `"FORBIDDEN"` / `403` | Missing scope / permission. Real account may not have granted all scopes during sign-in. | Tell the user: "Your Square sign-in doesn't include permission for that. Let me reconnect you with the right permissions." Re-run Phase 1 (real-account branch) — driving the OAuth screen again surfaces a fresh consent prompt. |
| `"INTERNAL_SERVER_ERROR"` / `500` | Square-side issue. Often transient, especially on the beta MCP server. | Retry once after 2 seconds. If still failing: "Square's side is having a moment. Want me to try again in a minute, or move on to something else?" |
| `"MCP server not found"` / tool name not available | The MCP server isn't configured or Claude Code wasn't restarted after the config write. | Check `~/.claude.json` for an `mcpServers.square` entry. If present, ask the user to close and reopen Claude Code once. If absent, re-run Phase 1 from the start. |

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
- **Auth errors (401/UNAUTHORIZED)** → re-run Phase 1 autonomously via Playwright. The existing browser session usually carries the user's Square login over; if not, prompt them to sign in once more.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Square MCP connection or API errors
- **quickbooks-connector**: Sibling financial-data connector — same conversational bootstrap pattern, different platform
- **xero-connector**: Sibling financial-data connector — same conversational bootstrap pattern, different platform
- **Square Developer Docs** (external): https://developer.squareup.com/docs — definitive reference for every Square API endpoint, request type, and response shape. Use this as the authoritative source when the MCP discovery tools don't have enough detail.
