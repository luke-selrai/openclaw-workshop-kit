---
name: shopify-connector
description: Install and operate the Shopify connector autonomously. Use this skill when the user asks to set up Shopify, connect their online store, or interact with products, orders, customers, or inventory. Phase 1 is fully autonomous - Claude drives `@shopify/cli` installation and OAuth via a Playwright MCP browser; the user only signs in to Shopify once. Phase 2 uses `shopify store execute` against the Admin API GraphQL.
allowed-tools: mcp__playwright__*, Bash, Read, Write, Edit
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
1. **Installs** `@shopify/cli` on the user's computer and authenticates it against their store (one-time setup, autonomous via Playwright)
2. **Operates** the connector - querying products, orders, customers, inventory, and locations via `shopify store execute` against the Admin API GraphQL

> **Account support:** Requires a Shopify store with staff/owner access. Development stores, Partner stores, and live stores are all supported.

> **Why a CLI patch is part of Phase 1.** The Shopify CLI's `store auth` step uses a PKCE OAuth flow with a localhost callback (`http://127.0.0.1:13387/auth/callback`). It tries to auto-open the OS default browser to the OAuth URL, but **does not print the URL** when it does. If the user's default browser is signed in to a different Shopify account than the CLI (a common workshop scenario), the OAuth lands on a login page rather than the Install-app page and the CLI silently times out. To make Phase 1 fully autonomous, Claude applies a one-line patch to the CLI bundle that forces the URL to print, then drives the URL into the same Playwright MCP browser the user already signed in to in Step 4. The patch is benign - it only disables auto-open. Manual users still get the URL printed in their terminal and can copy-paste; this is more reliable than auto-open landing in the wrong browser profile.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work, the user only signs in to Shopify once. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, paste URLs, or read terminal output. The only action you ever request is: "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say PKCE, OAuth, redirect URI, callback, scope, bundle, sed, patch, npm, child process, GraphQL, Admin API, or file paths to the user. If you must refer to a technical thing, name it plainly: "the Shopify connection tool", "the browser window I just opened", "a small one-time setup step on your computer".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm setting up Shopify for you now"), once when you need them ("please sign in"), once when you're done ("your Shopify is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your Shopify is now connected." Bad: "Token exchange failed at /admin/oauth/access_token."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo the access token** back to the user. The CLI stores it locally; never include it in any output visible to the user.

---

## PHASE 1 - Install & Auth (autonomous via Playwright)

Claude installs `@shopify/cli`, applies the `openURL` patch, and drives the two CLI auth flows (`shopify auth login` for the Partner/org account, then `shopify store auth` for store-specific scopes) entirely inside a Playwright MCP browser. The user's only role is signing in to Shopify in the Playwright window when prompted in Step 4.

> **Reasoning model.** Each step describes a *goal*. Achieve it by reading CLI output, taking `browser_snapshot` when navigating Shopify pages, and reasoning about what's on the page. Re-snapshot whenever the page state changes. Don't hardcode CSS selectors against the Shopify admin - the UI evolves.

### Step 1 - Check if `shopify` is already installed and authenticated

```bash
shopify version
```

If this returns `3.94.3` (or higher within the same major), proceed to the auth check. If `shopify` is missing, jump to Step 2.

**Auth check** (no store-subdomain known yet): inspect the CLI's persisted auth state. The CLI writes session details under `${XDG_CONFIG_HOME:-$HOME/.config}/@shopify/cli` on Unix and `%APPDATA%\@shopify\cli-nodejs\` on Windows. Probe via:

```bash
shopify auth login --help >/dev/null 2>&1 && shopify organization list 2>&1 | head -3
```

If `organization list` returns an org table (not "you must log in"), the Partner-side auth from Step 4 is already done. Re-running Step 5 against a known store is still required if no token exists for that store yet - but the user's manual sign-in from Step 4 won't be needed again.

If both checks pass and the user's intended store is already in the cached token list (visible via `shopify store list 2>/dev/null` if the command is available, otherwise via Playwright store discovery in Step 5a), the connector is set up. Skip to Phase 2.

If anything's missing, proceed to Step 2.

### Step 2 - Verify Node 20.10+

```bash
node --version
```

Needs **v20.10.0 or higher** (`@shopify/cli@3.94.3` declares `engines.node >= 20.10.0`; older Node fails install with `EBADENGINE`). If missing or older, tell the user (in plain English): *"Before I install Shopify, you need Node.js 20.10 or newer. The fastest way is to install the most recent LTS from nodejs.org."* Wait for them to confirm install, then continue.

### Step 3 - Install `@shopify/cli` and apply the autonomy patch

**3a. Install (pinned for workshop reproducibility):**

```bash
npm install -g @shopify/cli@3.94.3
```

> **Why pin?** The Step 3c patch anchors on a regex over the minified bundle. New CLI releases occasionally restructure the auth code path. Pinning `3.94.3` (verified against this SKILL on 2026-05-06) keeps the install reproducible across workshop dates. Bump deliberately when the SKILL is re-QA'd against a newer release.

> **Note.** `@shopify/theme` is bundled inside `@shopify/cli` since v3.59.0; don't install it separately. On Ubuntu/WSL2 with the NodeSource Node package, `npm install -g` requires `sudo` because the global prefix is root-owned by default; on macOS via the official installer, `sudo` is also commonly needed. If the install errors with `EACCES`, retry with `sudo npm install -g @shopify/cli@3.94.3`, or change npm's prefix to a user-writable path: `npm config set prefix ~/.npm-global` then add `~/.npm-global/bin` to PATH.

**3b. Refresh PATH if needed:**

```bash
# Mac/Linux: usually no action needed; npm global bin is on PATH at $(npm prefix -g)/bin.
#   If `shopify version` still errors:
#     export PATH="$(npm prefix -g)/bin:$PATH"
#
# Windows (Git Bash): the binary lives AT the npm prefix root (no /bin subdir).
#   If `shopify version` errors after install:
#     export PATH="$(npm prefix -g):$PATH"
```

Verify:

```bash
shopify version
```

**3c. Apply the autonomy patch.** This forces the CLI to print the OAuth URL to stdout instead of silently auto-opening the OS default browser, so Step 5 can drive Playwright autonomously. Claude runs:

```bash
# Resolve the global node_modules root (works for npm-installed @shopify/cli).
GLOBAL_ROOT="$(npm root -g)"
CLI_BUNDLE="${GLOBAL_ROOT}/@shopify/cli/dist/index.js"
test -f "$CLI_BUNDLE" || { echo "CLI bundle not found at $CLI_BUNDLE - confirm @shopify/cli was installed with npm globally (Yarn/pnpm/Volta installs land elsewhere)."; exit 1; }

# Idempotency: already patched? Skip cleanly.
if grep -qF 'openURL:async()=>!1' "$CLI_BUNDLE"; then
  echo "Already patched. Skipping."
  shopify version >/dev/null 2>&1 || { echo "Patched bundle no longer parses; rolling back from $CLI_BUNDLE.bak."; cp "$CLI_BUNDLE.bak" "$CLI_BUNDLE"; exit 1; }
else
  # Precondition: the openURL:<symbol> site must appear exactly once. The symbol is minifier-assigned and changes per build (today's bundle has 'openURL:v0', tomorrow's might be 'openURL:o3'). Anchor on the regex, not the literal.
  HITS="$(grep -cE 'openURL:[A-Za-z_$][A-Za-z0-9_$]*' "$CLI_BUNDLE")"
  [ "$HITS" = "1" ] || { echo "Expected exactly one openURL:<sym> site, found $HITS - bundle layout drifted; abort."; exit 1; }

  # Back up only if no .bak exists yet (preserves the original-vanilla bundle across multi-session re-runs).
  [ -f "$CLI_BUNDLE.bak" ] || cp "$CLI_BUNDLE" "$CLI_BUNDLE.bak"

  # Atomic-replace patch via tempfile + mv (avoids half-written-file corruption on interrupt).
  sed -E 's/openURL:[A-Za-z_$][A-Za-z0-9_$]*/openURL:async()=>!1/' "$CLI_BUNDLE.bak" > "$CLI_BUNDLE.tmp"
  mv "$CLI_BUNDLE.tmp" "$CLI_BUNDLE"

  grep -qF 'openURL:async()=>!1' "$CLI_BUNDLE" || { echo "Patch did not apply; rolling back."; cp "$CLI_BUNDLE.bak" "$CLI_BUNDLE"; exit 1; }
  shopify version >/dev/null 2>&1 || { echo "Patched bundle no longer parses; rolling back."; cp "$CLI_BUNDLE.bak" "$CLI_BUNDLE"; exit 1; }
fi
```

If the precondition fails (`HITS != 1`) or the patched bundle errors on `shopify version`, **do not fall back to asking the user to paste URLs** - that violates the autonomous-connector lock. Instead, restore the backup, tell the user warmly that the install needs a tooling update, and stop. The next session retry, or a fresh `npm install -g @shopify/cli` followed by Step 3c, often clears it.

> **Re-applying after upgrade.** The patch lives in the installed CLI bundle. If the user later runs `shopify upgrade` or `npm install -g @shopify/cli`, the patch is overwritten. Re-run Step 3c after any upgrade.

> **Rollback.** To restore the vanilla CLI: `cp "$CLI_BUNDLE.bak" "$CLI_BUNDLE"`.

### Step 4 - Sign in to Shopify (one manual step)

Tell the user, in one short message:

> "I'm opening a browser window for you - please sign in to your Shopify Partner / org account when it appears, and I'll handle the rest."

Start `shopify auth login` as a background process so Claude can poll its stdout while Playwright drives the browser. Use the `Bash` tool with `run_in_background: true`:

```
Bash(command: "shopify auth login", run_in_background: true, description: "Start Shopify CLI Partner login in background")
```

This returns a `bash_id` for the background task. **Poll the task's stdout** via `BashOutput(bash_id: "<id>")` repeatedly until the activation URL is emitted (typically 1-3 seconds, but up to 30s on slow disks / corporate AV / Defender-scanning installs). Stop polling once the regex below matches; abort with a clean error if 30s elapses without a match. The CLI's stdout looks like:

```
User verification code: PWGR-KFNZ
👉 Open this link to start the auth process: https://accounts.shopify.com/activate-with-code?device_code%5Buser_code%5D=PWGR-KFNZ
```

Apply this regex to the captured stdout:

```
/https:\/\/accounts\.shopify\.com\/activate-with-code\?[^\s]+/
```

Drive Playwright to the captured URL:

```
mcp__playwright__browser_navigate({ url: "<captured-activation-url>" })
```

Take a `browser_snapshot`. Reason about state:

- **Sign-in form visible** → tell the user *once*: *"The browser window is open - please sign in when you're ready."* Then poll the **CLI background task's stdout** for the success line (`✔ Logged in.`) via `BashOutput(bash_id: "<id>")` rather than `browser_wait_for`. The CLI's stdout is locale-stable; the browser success-page text varies by user locale (German "Authentifizierung erfolgreich", Japanese "認証に成功しました", etc.). Use a 15-minute timeout (first-time 2FA setup commonly takes 8-12 minutes). SSO redirects, password resets, and 2FA all resolve back to the same CLI success line.
- **Account picker** ("Choose an account to continue to Shopify CLI") → click the user's developer account via `browser_click`.
- **Security-settings nudge** ("Review your security settings") → click **Confirm** or **Remind me next time** to dismiss; this is a periodic prompt, not a real auth step.

The `shopify auth login` background process will exit on its own once Shopify confirms activation. The CLI prints `✔ Logged in. ✔ Current account: <user-email>` to stdout. If 5 minutes elapse without progress, check in with the user *once* ("Still on the sign-in page? Anything I can help with?"); the 15-minute hard timeout from above still applies before giving up.

### Step 5 - Authenticate against the user's store (autonomous)

**5a. Discover the store subdomain.** The Shopify CLI doesn't provide a `store list` command, so Claude discovers the store subdomain by navigating Playwright (still signed in from Step 4) to `admin.shopify.com/?no_redirect=true` - the "Your stores" page lists every store the user has access to with its `<subdomain>.myshopify.com` URL. Read the list from the DOM via `browser_evaluate`:

```javascript
() => Array.from(document.querySelectorAll('a[href*="/store/"]')).map(a => ({
  text: a.innerText.slice(0, 100).trim(),
  href: a.href,
  inactive: /\binactive\b|\btrial expired\b/i.test(a.innerText)
}))
```

If exactly one **active** store is listed, use that subdomain. If multiple active stores, ask the user *once* which one to connect - present a numbered list of human-readable store names (never URLs), wait for their pick, map to the subdomain.

If the only listed store is `Inactive` / `Trial expired`, tell the user plainly: *"The Shopify store I'd connect to is currently inactive - you'd need to subscribe (Shopify charges $1/mo for the first 3 months on Basic) or use a different store. Want to do that, or shall I stop here?"* Do not auth against an expired store; admin is locked behind the plan picker and OAuth scope-approval will never load.

**5b. Free callback port 13387.** A killed prior `shopify store auth` (Ctrl+C, terminal close, etc.) can leave a process bound to `127.0.0.1:13387` (or `[::1]:13387` on dual-stack systems). The next attempt fails with `Port 13387 is already in use.` Preflight:

```bash
# Cross-platform port-13387 owner-PID lookup. Tries lsof → ss (modern Linux) → netstat (Windows + older Linux).
STALE_PID=""
if command -v lsof >/dev/null 2>&1; then
  STALE_PID="$(lsof -ti :13387 2>/dev/null | head -1 || true)"
elif command -v ss >/dev/null 2>&1; then
  # ss output: ...,pid=<n>,...
  STALE_PID="$(ss -tlnp 2>/dev/null | awk '$4 ~ /:13387$/' | grep -oE 'pid=[0-9]+' | head -1 | cut -d= -f2)"
elif command -v netstat >/dev/null 2>&1; then
  # Match port in column 2 (works for 127.0.0.1:13387 AND [::1]:13387 AND 0.0.0.0:13387).
  # Locale-tolerant: don't require literal LISTENING (localized on non-EN Windows).
  STALE_PID="$(netstat -ano 2>/dev/null | awk '$2 ~ /:13387$/ {print $NF}' | grep -E '^[0-9]+$' | head -1)"
fi

if [ -n "$STALE_PID" ] && [ "$STALE_PID" -gt 0 ] 2>/dev/null; then
  if command -v taskkill >/dev/null 2>&1; then
    # Git Bash auto-translates // to / for Windows tools; PowerShell users invoke directly with /F /PID.
    taskkill //F //PID "$STALE_PID" 2>/dev/null || taskkill /F /PID "$STALE_PID" 2>/dev/null || true
  else
    kill -9 "$STALE_PID" 2>/dev/null || true
  fi
fi
```

**5c. Run store auth in background.** With the chosen subdomain (e.g. `acme-shop.myshopify.com`):

```
Bash(command: "shopify store auth --store <subdomain>.myshopify.com --scopes read_products,write_products,read_orders,write_orders,read_customers,write_customers,read_inventory,write_inventory,read_locations", run_in_background: true, description: "Start Shopify store auth in background")
```

Because of the Step 3c patch, the CLI now prints (typically within 1-3s):

```
Browser did not open automatically. Open this URL manually:
https://<subdomain>.myshopify.com/admin/oauth/authorize?client_id=...&scope=...&redirect_uri=http://127.0.0.1:13387/auth/callback&state=...&response_type=code&code_challenge=...&code_challenge_method=S256
```

Poll `BashOutput(bash_id: "<id>")` until the URL appears (up to 30s for slow boxes); abort cleanly if it doesn't. Extract via regex:

```
/https:\/\/[^\/\s]+\.myshopify\.com\/admin\/oauth\/authorize\?[^\s]+/
```

**5d. Drive Playwright through the consent page.** Navigate to the captured URL (same Playwright window from Step 4 - session is preserved, so Shopify routes straight to the consent page rather than re-asking for sign-in):

```
mcp__playwright__browser_navigate({ url: "<captured-oauth-url>" })
```

Take a `browser_snapshot`. The primary-action button is one of:
- **Install** - first-time auth, page title `<store name> · Install app · Shopify`
- **Update** - re-auth on an already-installed app with new scopes, page title `<store name> · Update data access · Shopify`
- **Continue** / **Review and accept** - Shopify Plus + EU-DSA stores sometimes show a "Review permissions" interstitial before the final Install button

Click the primary action via `browser_click`. After clicking, `browser_snapshot` again - if the URL is still on `/admin/oauth/authorize` or `/admin/apps/review`, click the next primary button. Loop up to 3 times. Once the page redirects to `http://127.0.0.1:13387/auth/callback?code=...&state=...`, the CLI's localhost listener captures the code, exchanges it for an access token, stores it locally, and exits with:

```
✔ Logged in.
✔ Authenticated as <user-email> against <subdomain>.myshopify.com.
```

> **Token storage.** The access token persists in the CLI's `conf` cache: `~/.config/@shopify/cli/` (Unix, XDG-respecting) or `%APPDATA%\@shopify\cli-nodejs\` (Windows). Subsequent `shopify store execute` calls reuse the token; no further auth needed unless scopes change or the token expires.

### Step 6 - Verify (binary smoke gate)

```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query "{ shop { name myshopifyDomain } }"
```

If the response is shaped `{ "shop": { "name": "...", "myshopifyDomain": "..." } }`, the connector is working. Tell the user warmly, using only the human-readable store name: *"Your Shopify is now connected - I can read products, orders, customers, inventory, and locations."* (Don't echo the `myshopifyDomain` subdomain or any tokens to the user.)

If it errors with auth, re-run Step 5. If it errors with `ACCESS_DENIED` on a specific scope, re-run Step 5 with the missing scope added to `--scopes`.

---

## Part 2 - Products

All store operations use `shopify store execute` which runs Admin API GraphQL queries against the authenticated store.

### List products
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query "{ products(first: 10) { edges { node { id title status productType vendor totalInventory variants(first: 5) { edges { node { id title price sku inventoryQuantity } } } } } } }"
```

### Search products by title
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ products(first: 10, query: "title:sneaker*") { edges { node { id title status totalInventory } } } }'
```
> **Search syntax:** `title:sneaker*` (trailing) matches anything starting with "sneaker". See Part 4's wildcard note for the full placement rules across fields.

### Get a single product
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ product(id: "gid://shopify/Product/<PRODUCT_ID>") { id title descriptionHtml status productType vendor tags totalInventory variants(first: 10) { edges { node { id title price sku inventoryQuantity } } } images(first: 5) { edges { node { url altText } } } } }'
```

### Create a product
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --allow-mutations \
  --query 'mutation { productCreate(input: { title: "New Product", productType: "Shirts", vendor: "My Brand", descriptionHtml: "<p>Product description here</p>", tags: ["new", "summer"], status: DRAFT }) { product { id title } userErrors { field message } } }'
```
> Always confirm product details with the user before creating.

### Update a product
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --allow-mutations \
  --query 'mutation { productUpdate(input: { id: "gid://shopify/Product/<PRODUCT_ID>", title: "Updated Product Title", status: ACTIVE }) { product { id title status } userErrors { field message } } }'
```

> **For complex queries**, use the `--query-file` flag to load from a `.graphql` file instead of inline:
> ```bash
> shopify store execute \
>   --store <subdomain>.myshopify.com \
>   --version 2026-04 \
>   --query-file ./query.graphql \
>   --variables '{"id": "gid://shopify/Product/12345"}'
> ```

---

## Part 3 - Orders

### List recent orders
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query "{ orders(first: 10, sortKey: CREATED_AT, reverse: true) { edges { node { id name createdAt displayFinancialStatus displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName email } } } } }"
```

### Search orders by status
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ orders(first: 10, query: "fulfillment_status:unfulfilled") { edges { node { id name createdAt displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName } } } } }'
```

### Get a single order
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ order(id: "gid://shopify/Order/<ORDER_ID>") { id name createdAt displayFinancialStatus displayFulfillmentStatus totalPriceSet { shopMoney { amount currencyCode } } customer { displayName defaultEmailAddress { emailAddress } } lineItems(first: 20) { edges { node { title quantity originalUnitPriceSet { shopMoney { amount } } variant { sku } } } } shippingAddress { address1 city province country zip } } }'
```

### Search orders by date range
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ orders(first: 20, query: "created_at:>2026-04-01 created_at:<2026-04-08") { edges { node { id name createdAt totalPriceSet { shopMoney { amount currencyCode } } } } } }'
```

---

## Part 4 - Customers

> **Field shape note (modern Admin API):**
> - `numberOfOrders` (UnsignedInt64; JSON-encoded as a string for values >2^53) - replaces deprecated `ordersCount`.
> - `amountSpent { amount currencyCode }` (MoneyV2) - replaces deprecated `totalSpent` (which returned a bare string).
> - `defaultEmailAddress { emailAddress marketingState }` - replaces deprecated `email` field.
> - `defaultPhoneNumber { phoneNumber marketingState }` - replaces deprecated `phone` field.
> - `addressesV2(first: N) { edges { node { ... } } }` (a connection) - replaces deprecated `addresses` plain list.
>
> The legacy field names still resolve on older API versions but are removed from the latest schema. Use the modern shapes for forward compatibility.

### List customers
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query "{ customers(first: 10) { edges { node { id displayName defaultEmailAddress { emailAddress } defaultPhoneNumber { phoneNumber } numberOfOrders amountSpent { amount currencyCode } createdAt } } } }"
```

### Search customers
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ customers(first: 10, query: "email:jane*") { edges { node { id displayName defaultEmailAddress { emailAddress } numberOfOrders amountSpent { amount currencyCode } } } } }'
```

> **Search syntax:** Wildcards behave differently across fields. **`email:`** is substring-indexed, so trailing, leading, and middle all work (`email:jane*`, `email:*@example.com`, `email:*acme*`). **Most other fields** (`first_name:`, `last_name:`, `title:`) are token-indexed: trailing wildcards always work (`first_name:Jane*`); leading wildcards (`first_name:*Jane`) only match when the search term is a complete token in the field's value; middle wildcards within a token (`first_name:*ane*`) silently return zero. Default to trailing, it's the most predictable placement across all fields.

### Get a single customer
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ customer(id: "gid://shopify/Customer/<CUSTOMER_ID>") { id displayName defaultEmailAddress { emailAddress } defaultPhoneNumber { phoneNumber } numberOfOrders amountSpent { amount currencyCode } createdAt addressesV2(first: 5) { edges { node { address1 city province country zip } } } orders(first: 5) { edges { node { id name totalPriceSet { shopMoney { amount } } } } } } }'
```

### Create a customer
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --allow-mutations \
  --query 'mutation { customerCreate(input: { firstName: "Jane", lastName: "Doe", email: "jane@example.com", phone: "+61400000000" }) { customer { id displayName defaultEmailAddress { emailAddress } } userErrors { field message } } }'
```
> Always confirm customer details with the user before creating.
>
> **Address note:** `customerCreate` input still accepts an `addresses: [{ ... }]` array (marked deprecated but fully functional in 2026-04). The modern alternative is to create the customer first, then add or update addresses via `customerUpdate` with an `addresses` array. Address inputs use `countryCode` (CountryCode enum, e.g. `AU`) and `provinceCode` (e.g. `"NSW"`) - the legacy string `country`/`province` input fields were removed.

---

## Part 5 - Inventory & Locations

### List inventory levels for a product variant
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ inventoryItem(id: "gid://shopify/InventoryItem/<ITEM_ID>") { id sku tracked inventoryLevels(first: 10) { edges { node { id quantities(names: ["available"]) { name quantity } location { name } } } } } }'
```

### List all locations
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query "{ locations(first: 10) { edges { node { id name isActive address { address1 city province country } } } } }"
```

### Adjust inventory quantity

```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --allow-mutations \
  --query 'mutation { inventoryAdjustQuantities(input: { reason: "correction", name: "available", changes: [{ delta: 10, changeFromQuantity: null, inventoryItemId: "gid://shopify/InventoryItem/<ITEM_ID>", locationId: "gid://shopify/Location/<LOCATION_ID>" }] }) @idempotent(key: "<UUID_V4>") { inventoryAdjustmentGroup { reason changes { name delta } } userErrors { field message } } }'
```

> Always confirm inventory adjustments with the user before executing. Get the `inventoryItemId` from a product variant query and `locationId` from the locations query. Generate a fresh `UUID_V4` for `key` per call (e.g. `uuidgen` on macOS / `python3 -c "import uuid;print(uuid.uuid4())"` cross-platform); reuse the same key only when retrying the *same* logical operation, so the server can dedupe.
>
> **`@idempotent(key:)` is required on stores that enforce it.** Shopify Plus stores (and stores with @idempotent enforcement enabled in admin settings) reject the mutation without the directive: `BAD_REQUEST - The @idempotent directive is required for this mutation but was not provided`. The directive's location is `FIELD` (not `MUTATION`) - verified via live `__schema { directives }` introspection on API 2026-04 by [@gianselrai](https://github.com/selrai-company/claude-workshop-kit/issues/218#issuecomment-4394072013) - so it goes after the field's input/argument list, not on the operation. Stores without enforcement accept the directive harmlessly, so the example above is safe to use universally. The directive's own description gives the canonical example: `@idempotent(key: "123e4567-e89b-12d3-a456-426614174000")`. Constraint: `key` is a non-empty string (whitespace-only fails validation).
>
> **`changeFromQuantity` must be passed explicitly.** The schema types this field as optional (`Int`), but Shopify's mutation handler requires you to provide a value: pass `null` to skip the compare-and-swap check (only safe when your system is the source of truth), or pass the quantity you expect to find for a CAS-protected adjust. Omitting the field returns `INVALID_FIELD_ARGUMENTS - InventoryChangeInput must include the following argument: changeFromQuantity.` Reference: [Shopify CAS docs](https://shopify.dev/docs/apps/build/orders-fulfillment/inventory-management-apps/manage-quantities-states#compare-and-swap).
>
> **`inventoryAdjustmentGroup.changes` is a plain list, not a connection.** Type `[InventoryChange!]!` - so the response shape is `changes { name delta }`, NOT `changes(first: N) { edges { node { ... } } }`. The latter errors with `Field 'edges' doesn't exist on type 'InventoryChange'`.
>
> **Valid `reason` values:** `correction`, `cycle_count_available`, `damaged`, `movement_created`, `movement_updated`, `other`, `received`, `reservation_created`, `reservation_deleted`, `reservation_updated`, `restock`, `safety_stock`, `shrinkage`. Any other string returns `userErrors: [{ field: "reason", message: "Invalid reason" }]`. Note: validation runs *after* the schema check, so test plan items must use the modern shape above before `reason` is even reached.

### Check low stock items
```bash
shopify store execute \
  --store <subdomain>.myshopify.com \
  --version 2026-04 \
  --query '{ products(first: 50, query: "inventory_total:<10") { edges { node { id title totalInventory variants(first: 5) { edges { node { title sku inventoryQuantity } } } } } } }'
```

---

## Part 6 - Reset / re-auth

If the access token is missing, expired, or scopes need to change:

```bash
# Re-run with the same or expanded scope list
shopify store auth \
  --store <subdomain>.myshopify.com \
  --scopes read_products,write_products,read_orders,write_orders,read_customers,write_customers,read_inventory,write_inventory,read_locations
```

Drive the captured URL via Playwright (same flow as Step 5).

To log out of the Partner/org account:

```bash
shopify auth logout
```

> **Direct curl fallback.** Shopify migrated new stores from the legacy "Custom apps" path (Settings → Apps → Develop apps) to **Dev Dashboard** (`dev.shopify.com/dashboard`). For new stores, the legacy Admin API token via Custom App is no longer available. Use the CLI flow above instead. If the user has a pre-existing legacy custom app on an older store, you can still call the Admin API via `curl -X POST https://<store>/admin/api/2026-04/graphql.json -H "X-Shopify-Access-Token: <token>"` with the legacy token, but do not document Custom App creation as a fresh-install path.

---

## Behaviour Guidelines

- **Always verify auth first** at the start of a session - run `shopify version` and test with `shopify store execute --store <subdomain>.myshopify.com --query "{ shop { name } }"`. If both pass, skip Phase 1 entirely.
- **Confirm before acting** - always confirm with the user before creating products, adjusting inventory, or modifying orders.
- **Use `--allow-mutations`** - all mutation queries require the `--allow-mutations` flag on `shopify store execute`. Without it, mutations are silently blocked.
- **Use `--query-file` for complex queries** - long inline queries are hard to read. Save the query to a `.graphql` file and use `--query-file ./file.graphql` with `--variables '{"key": "value"}'`.
- **Use GraphQL IDs** - Shopify uses global IDs like `gid://shopify/Product/12345`. Always get IDs from list/search queries first.
- **Pagination** - use `first: N` and `after: cursor` for paginated results. Default to 10 items unless the user asks for more.
- **Rate limits** - Shopify's Admin API has a cost-based rate limit. Avoid requesting too many nested fields in a single query. If you hit a rate limit, wait and retry.
- **Status values** - Products: `ACTIVE`, `DRAFT`, `ARCHIVED`. Orders financial: `AUTHORIZED`, `EXPIRED`, `PAID`, `PARTIALLY_PAID`, `PARTIALLY_REFUNDED`, `PENDING`, `REFUNDED`, `VOIDED`. Orders fulfillment: `FULFILLED`, `IN_PROGRESS`, `ON_HOLD`, `OPEN`, `PARTIALLY_FULFILLED`, `PENDING_FULFILLMENT`, `REQUEST_DECLINED`, `RESTOCKED`, `SCHEDULED`, `UNFULFILLED`. Full enum lists: [OrderDisplayFinancialStatus](https://shopify.dev/docs/api/admin-graphql/2026-04/enums/OrderDisplayFinancialStatus), [OrderDisplayFulfillmentStatus](https://shopify.dev/docs/api/admin-graphql/2026-04/enums/OrderDisplayFulfillmentStatus).
- **Currency** - always display amounts with the currency code from the response.
- **Auth errors** - if you get a 401 or "Unauthorized", re-run the Phase 1 Step 5 flow.
- **Missing scopes** - if you get an `ACCESS_DENIED` scope error, re-run Step 5 with the missing scope added to the `--scopes` list. The default 9-scope set covers products, orders, customers, inventory, and locations read+write.
- **JSON output** - add `--json` to any `shopify store execute` command for structured JSON output, useful for piping to other tools.
- **Patch persistence** - the Step 3c patch survives normal use but is overwritten by `shopify upgrade` or `npm install -g @shopify/cli`. Re-apply after any CLI upgrade.
