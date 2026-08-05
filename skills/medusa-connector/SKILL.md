---
name: medusa-connector
description: "Connect a self-hosted Medusa v2 store to Claude by capturing its admin and storefront API credentials, scaffolding a new store first if needed. Use when the user asks to set up or connect Medusa, or wants Medusa work (products, orders, customers, discounts, inventory, a Next.js storefront) and the credentials aren't in place yet. Once connected, Medusa runs directly against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__plugin_medusa-dev_MedusaDocs__*
metadata:
  category: Ecommerce & Integrations
  tags:
    - medusa
    - ecommerce
    - self-hosted
    - products
    - orders
    - customers
    - inventory
    - nextjs
    - admin-api
    - store-api
  pairs-with:
    - skill: shopify-connector
      reason: Sibling ecommerce connector for the hosted-SaaS path. If the user is undecided, route to agent-teams-recommender's ecommerce decision (Phase 3) which presents Shopify vs Next.js+Medusa.
    - skill: railway-deployment
      reason: Step 10B Path 1 (workshop-default self-host stack) dispatches here for the Medusa Railway template - backend + Postgres + Redis in one click. Do not duplicate the Railway signup flow inline; route into the dedicated skill.
    - skill: wordpress-connector
      reason: Same "self-hosted + user-supplies-the-URL" pattern. The Playwright admin-login → token-capture → env-file flow is structurally identical; reuse the URL-prompt and resume-check shape from there.
    - skill: stripe-connector
      reason: Medusa stores almost always wire Stripe as the payment provider. If the user mentions checkout or payments, run stripe-connector after medusa-connector lands.
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by Medusa events (new order email, low-stock Slack ping, abandoned-cart follow-up) once the connector is live.
---

# Medusa Connector

## Overview

This skill captures the credentials Claude needs to talk to the user's **self-hosted Medusa v2 store** and persists them so any later Claude Code session - agent or interactive - can operate the store via REST.

Two credentials are captured in one Playwright pass:

- **Secret Admin API Key** - `Authorization: Bearer sk_...` on `/admin/*` endpoints. Full CRUD on products, orders, customers, discounts, inventory, regions, fulfillment. This is what agents (Phase 3 Medusa team, support persona, ops persona) call.
- **Publishable Store Key** - `x-publishable-api-key: pk_...` on `/store/*` endpoints. Read-only-ish public surface for the customer-facing storefront. This is what the Next.js front-end uses at runtime.

> **Account support:** Requires a Medusa v2 self-hosted instance (Medusa v1 admin UI is different - out of scope for this SKILL). The user must have a Medusa admin account on that instance with API Key Management permissions. Local dev instances (`http://localhost:9000`) work the same as production URLs.

> **No upstream MCP for Medusa exists** as of January 2026. This SKILL captures credentials and documents the curl-based operation pattern; for docs lookups, pair with the official `medusa-dev:MedusaDocs` plugin (already in the user's plugin marketplace). If/when Medusa ships a hosted MCP, this SKILL will be re-classified to Pattern 2 (Hosted-bearer-PAT) and the env-file approach below will be deprecated.

**The user does exactly TWO things across the entire setup. Everything else is autonomous.**

1. Tell me the URL of their Medusa admin (one short answer, e.g. `https://store.example.com` or `http://localhost:9000`).
2. Log in to their Medusa admin in the Playwright browser when it opens (Step 3). One-time, their credentials, on screen they already know.

That's the complete list. The user does NOT click menus, do NOT generate the Secret API Key, do NOT copy or paste it. Claude drives Medusa admin from Step 3 onward.

---

## Communication rules

Identical contract to `shopify-connector` and `wordpress-connector`. Summary:

- **You drive, not them.** Never ask the user to click menus, copy tokens, or paste anything.
- **Plain English only.** No jargon. Never say Bearer, Authorization header, REST, GraphQL, JWT, secret key, publishable key, env var, claude.json, mcpServers, jq. Say "the Medusa key" or "your store connection".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start, once when you need them ("please sign in"), once when you're done. No commentary in between.
- **Short responses.** Max 8 lines per message during the install phase.
- **React warmly.** Good: "That worked - your Medusa store is now connected." Bad: "POST /admin/api-keys 201 Created."
- **Never echo any key.** Once written to disk, the keys' job is done. Do not re-read the env file, do not include the keys in any later tool-call return value the user can see. Same rule for the user's Medusa login password - Claude never sees it (it goes to the Medusa login form), and Claude must never ask for it.

---

## PHASE A - Bootstrap a new Medusa project (skip if Medusa is already running)

Before anything else, ask the user exactly once:

> *"Do you already have a Medusa store running somewhere - local dev or hosted - or do we need to create one from scratch?"*

Branch:

- **Already running** (local on `:9000`, or hosted somewhere) → skip to **Phase 0**. The rest of this SKILL connects Claude to the existing instance.
- **Need to create one** → continue with the rest of Phase A. **Use the Medusa CLI, NOT Playwright** - project scaffolding is an npm operation, not a browser flow.

> **Why CLI, not Playwright, for this part.** Steps 1-7 (credential capture from a *running* Medusa admin) are Playwright-driven because that's a browser flow. Project *scaffolding* is `npx create-medusa-app@latest <name>` - it creates a directory of files via npm. There's nothing to drive in a browser. The CLI is the canonical Medusa-blessed path (see https://docs.medusajs.com/learn/installation and https://docs.medusajs.com/resources/medusa-cli).

### Step A.1 - Run `create-medusa-app`

Ask the user for a project name (default: `medusa-store` if they don't have a preference). Validate the shape (letters, digits, hyphens, no spaces):

```bash
echo "$MEDUSA_PROJECT_NAME" | grep -qE '^[a-z][a-z0-9-]{2,40}$' || echo "INVALID"
```

Ask where to create it (default: `~/projects/`). Then run:

```bash
mkdir -p "$HOME/projects"
cd "$HOME/projects"
npx create-medusa-app@latest "$MEDUSA_PROJECT_NAME" 2>&1 | tail -30
```

The scaffolder runs interactively by default - it asks about a starter storefront (default Next.js) and database (default Postgres or SQLite for first-run). Drive the prompts in Bash via `--yes` flags where supported, OR (more reliably for v2's evolving CLI) just stream the output and pass through the user's preferences if they speak up. Default to: **yes** to the Next.js storefront, **yes** to Postgres if available locally, **no** to SQLite (Medusa v2 ships Postgres as the production target).

After scaffolding completes, the project lives at `$HOME/projects/$MEDUSA_PROJECT_NAME/`. Inside:

- `apps/backend/` - the Medusa server
- `apps/storefront/` - the Next.js storefront (if the user said yes to the starter)

### Step A.2 - Start the dev server + create the admin user

Tell the user *"Starting Medusa locally - this takes about 30 seconds."* Then:

```bash
cd "$HOME/projects/$MEDUSA_PROJECT_NAME/apps/backend"

# Start the dev server in the background so we can hit the admin from this same session
nohup npm run dev > /tmp/medusa-dev.log 2>&1 &
MEDUSA_PID=$!
echo "medusa-pid=$MEDUSA_PID" > "$HOME/.claude/state/medusa-connector-dev.json"

# Poll for the backend to be ready (Medusa announces "Server is ready on port: 9000")
for i in {1..60}; do
  if grep -q "Server is ready" /tmp/medusa-dev.log 2>/dev/null; then
    break
  fi
  sleep 1
done

# Create the admin user via the CLI (workshop-friendly defaults)
ADMIN_EMAIL="admin@${MEDUSA_PROJECT_NAME}.local"
ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)"
npx medusa user -e "$ADMIN_EMAIL" -p "$ADMIN_PASSWORD" 2>&1 | tail -5

# Persist the admin creds so the user can log in via Playwright in Step 3
cat > "$HOME/.claude/state/medusa-connector-bootstrap.json" <<EOF
{
  "project_name": "$MEDUSA_PROJECT_NAME",
  "project_path": "$HOME/projects/$MEDUSA_PROJECT_NAME",
  "backend_path": "$HOME/projects/$MEDUSA_PROJECT_NAME/apps/backend",
  "storefront_path": "$HOME/projects/$MEDUSA_PROJECT_NAME/apps/storefront",
  "dev_pid": $MEDUSA_PID,
  "admin_email": "$ADMIN_EMAIL",
  "admin_password": "$ADMIN_PASSWORD",
  "admin_url": "http://localhost:9000/app",
  "backend_url": "http://localhost:9000",
  "bootstrapped_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
chmod 600 "$HOME/.claude/state/medusa-connector-bootstrap.json"
```

> **Security caveat for the bootstrap credentials**: the generated admin password is stored in `~/.claude/state/medusa-connector-bootstrap.json` (mode 600). It's a *local-dev* password for an instance running on `localhost:9000` - fine for workshop runs. Before promoting the project to a public URL, the user should rotate this password (Settings → Profile → Change Password in the admin UI). Do NOT use this generated password as the production admin password.

### Step A.3 - Hand off to the Phase 1 capture flow (clipboard transit, no password in chat)

The generated admin password MUST NOT be echoed to chat, tool returns, or log lines. Use the same clipboard-transit pattern that `notion-pit-setup` uses for the Notion PIT - copy the password to the OS clipboard, then tell the user to paste it.

```bash
# Read the password from the state file written in Step A.2; copy to clipboard via the OS-appropriate tool
ADMIN_PASSWORD=$(jq -r .admin_password "$HOME/.claude/state/medusa-connector-bootstrap.json")

# Linux (Wayland) → wl-copy; macOS → pbcopy; X11 fallback → xclip; Windows → clip.exe
if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$ADMIN_PASSWORD" | wl-copy
elif command -v pbcopy >/dev/null 2>&1; then
  printf '%s' "$ADMIN_PASSWORD" | pbcopy
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$ADMIN_PASSWORD" | xclip -selection clipboard
elif command -v clip.exe >/dev/null 2>&1; then
  printf '%s' "$ADMIN_PASSWORD" | clip.exe
else
  echo "NO_CLIPBOARD_TOOL"
fi

# Wipe the variable from this shell context
unset ADMIN_PASSWORD
```

Tell the user, once, exactly:

> *"Your Medusa store is running locally. I've put the admin password on your clipboard. When the browser opens, the email is `admin@<project-name>.local` and you paste the password (Ctrl-V on Linux/Windows, Cmd-V on Mac) into the password field."*

The email `admin@<project-name>.local` is synthetic - fine to display since it carries no secret. The password lives only in `~/.claude/state/medusa-connector-bootstrap.json` (mode 600) and on the user's clipboard until they paste it.

If clipboard transit failed (`NO_CLIPBOARD_TOOL` output above - rare; happens on minimal Linux containers without `wl-copy` / `xclip`), fall back to telling the user *"I generated a password and saved it to `~/.claude/state/medusa-connector-bootstrap.json` - open that file with a text editor and copy the `admin_password` value into the login form. Close the file when you're done."* That's a small leak (the password transits the user's editor + file system) but is the only path when clipboard tooling is missing.

**After the user pastes and logs in successfully** (Playwright detects the URL changed to `/app/orders`), wipe the clipboard so the password doesn't linger:

```bash
if command -v wl-copy >/dev/null 2>&1; then printf '' | wl-copy
elif command -v pbcopy >/dev/null 2>&1; then printf '' | pbcopy
elif command -v xclip >/dev/null 2>&1; then printf '' | xclip -selection clipboard
elif command -v clip.exe >/dev/null 2>&1; then printf '' | clip.exe
fi
```

Set `MEDUSA_BACKEND_URL="http://localhost:9000"` and continue with Phase 0 (resume check, which will be a no-op for a fresh bootstrap), then Step 1 onward. The connector skill flows the same way from Step 2 - the only difference is the user didn't bring their own URL.

### Stopping the local dev server later

`npm run dev` is running in the background as PID stored in `~/.claude/state/medusa-connector-dev.json`. The dev server dies when the laptop sleeps or reboots - to restart it later:

```bash
cd $(jq -r .backend_path "$HOME/.claude/state/medusa-connector-bootstrap.json")
nohup npm run dev > /tmp/medusa-dev.log 2>&1 &
```

To stop it explicitly:

```bash
kill $(jq -r .dev_pid "$HOME/.claude/state/medusa-connector-dev.json") 2>/dev/null
```

Workshop participants don't need to do either - the connector skill leaves the server running so Phase 1 can hit it. They can let it die naturally on reboot.

### What about deploying this local instance later?

The user's local Medusa is on `localhost:9000` - fine for development, but it dies when the laptop sleeps and isn't reachable from a hosted storefront. When they're ready to deploy:

- **Self-host path**: Step 9 → 10B will dispatch into `railway-deployment` (workshop default) or another platform skill. The local project's Git repo gets pushed to GitHub, and Railway deploys from there. The local creds in the bootstrap state file get rotated to production keys after the deploy.
- **Cloud path**: Step 9 → 10A will install the `medusa-cloud` plugin and link the project. Medusa Cloud watches the Git repo and deploys on push.

In both cases, **the local project IS the source of truth** for the backend code - Medusa CLI scaffolded it, the user (and Phase 3 agents) extend it with custom modules, and the deploy is just "push this to where it'll run."

---

## PHASE 0 - Resume check

If a previous run got partway through, do not start from scratch. Check `~/.claude/medusa-connector.env`:

```bash
test -f "$HOME/.claude/medusa-connector.env" && grep -E '^MEDUSA_(BACKEND_URL|ADMIN_SECRET_KEY|PUBLISHABLE_KEY)=' "$HOME/.claude/medusa-connector.env"
```

- All three vars present and non-empty → connector is configured. Run the smoke test in Step 7 (1 curl call) to verify the URL is reachable and the Secret Key still authenticates. Report result, stop.
- Some vars present but not all → tell the user *"Looks like you started this earlier. Want me to pick up where you left off, or start completely fresh?"* On **resume**, continue from the first step whose output is missing. On **fresh**, wipe `~/.claude/medusa-connector.env` (and the `mcpServers.medusa` block from `~/.claude.json` if present), then start at Step 1.
- File missing entirely → run Phase 1.

---

## PHASE 1 - Install & capture credentials (autonomous via Playwright)

### Step 1 - Ask the user for their Medusa admin URL

Exactly one question:

> *"What's the URL of your Medusa store's admin? Something like `https://store.yoursite.com` or `http://localhost:9000` if you're testing locally."*

Wait for the answer. Validate the shape:

```bash
echo "$MEDUSA_URL" | grep -qE '^https?://[A-Za-z0-9.:_/-]+/?$' || echo "INVALID"
```

If invalid, re-ask once with a softer prompt. After two failures, stop and tell the user the URL format you need.

Normalize: strip any trailing `/`, strip any trailing `/app` (admin route - Medusa appends it itself). Store the base in `MEDUSA_BACKEND_URL` for later steps.

### Step 2 - Sanity-check the URL is reachable

```bash
curl -sS -m 10 -o /dev/null -w "%{http_code}" "$MEDUSA_BACKEND_URL/health"
```

- `200` → the backend is up. Proceed.
- `404` → the URL points somewhere that's not a Medusa backend. Tell the user, ask them to double-check.
- Connection refused / timeout / DNS error → tell the user *"I can't reach that URL from your computer. Is the store running? If it's local, is the server started?"* Stop.

### Step 3 - Open the admin in Playwright, the user signs in

```bash
# Make sure Playwright MCP is installed; install if not (see skills/CLAUDE.md "Playwright MCP install contingency")
```

Open `${MEDUSA_BACKEND_URL}/app/login` in Playwright. Tell the user:

> *"I've opened your Medusa admin. Please sign in - I'll take it from there."*

Poll with `browser_snapshot` every few seconds until the URL changes to `/app/orders` or `/app/dashboard` (Medusa v2's post-login landing) - that's the success signal. **Do not ask the user to confirm they've signed in.** The URL change is the signal.

If after 5 minutes there's no sign-in (likely the user hit a snag), ask once: *"Everything OK on the sign-in? Let me know if you need a new link."* Re-snapshot, retry.

### Step 4 - Create the Secret Admin API Key

Navigate inside the Playwright session to **Settings → Developer → API Key Management** (in Medusa v2 admin this is at `/app/settings/api-key-management`). Take a snapshot to confirm the page loaded.

> **UI drift caveat.** Medusa v2's admin has been moving menu items around as it stabilizes. If "API Key Management" isn't where the SKILL describes, look for it under: Settings → Developer, Settings → Integrations, or the gear icon → API Keys. Re-snapshot and reason from the page. If the user is on v1, stop and tell them this skill is for v2.

Click the **"Create API Key"** button (or **"+"** add button on that page). In the modal:

- **Type:** select **Secret** (not Publishable - Publishable is for the storefront, covered in Step 5).
- **Title:** type `Claude Code agent ($(date -u +%Y-%m-%d))` so the user can recognize it later in their admin.

Click **Create**. The token reveals once (this is the only time Medusa shows it).

Read the token from the DOM. It will look like `sk_01HXXX...` (Medusa Secret Keys are `sk_` prefixed). Capture it into the `MEDUSA_ADMIN_SECRET_KEY` shell variable.

**Mask immediately:** treat `MEDUSA_ADMIN_SECRET_KEY` like `NOTION_PIT` in `notion-pit-setup`. Do not print it to chat. Do not include it in any tool-call return value the user can see. The first thing Step 6 does is persist it; from that moment, never re-read its value into anything visible.

### Step 5 - Capture (or create) the Publishable Store Key

Still on **API Key Management**. Switch the type filter to **Publishable**. The page lists existing publishable keys.

- If at least one publishable key exists → click it, read the value, capture into `MEDUSA_PUBLISHABLE_KEY`. Done.
- If none exist → click **"Create API Key"** → Type **Publishable** → Title `Claude storefront ($(date -u +%Y-%m-%d))` → Create. Read the value, capture into `MEDUSA_PUBLISHABLE_KEY`.

> **Why both keys.** The Secret Key is for agents (Phase 3 backend-builder, ops personas, this SKILL's curl recipes). The Publishable Key is for the Next.js storefront - the Phase 3 ecommerce-medusa team will inject it into the frontend at build time. Capturing both now saves a round-trip when the Phase 3 team starts.

### Step 6 - Persist both keys to disk

Two writes:

**Write 1: plain env file at `~/.claude/medusa-connector.env`.** This is the source of truth for the Bash recipes in Phase 2 and for any agent reading creds:

```bash
mkdir -p "$HOME/.claude"
umask 077
cat > "$HOME/.claude/medusa-connector.env" <<EOF
# Medusa Connector - credentials captured $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Source this file before calling /admin/* or /store/* endpoints.
# DO NOT commit this file. DO NOT share publicly.
MEDUSA_BACKEND_URL="${MEDUSA_BACKEND_URL}"
MEDUSA_ADMIN_SECRET_KEY="${MEDUSA_ADMIN_SECRET_KEY}"
MEDUSA_PUBLISHABLE_KEY="${MEDUSA_PUBLISHABLE_KEY}"
EOF
chmod 600 "$HOME/.claude/medusa-connector.env"
```

**Write 2: credentials-only stub in `~/.claude.json`** under `mcpServers.medusa`. This is **not** a launchable MCP entry (Medusa ships no MCP) - it's a parking spot so resume-check (Phase 0) and other connector audits can see the install:

Resolve the path:
- Mac/Linux: `$HOME/.claude.json`
- Windows: `%USERPROFILE%\.claude.json`

Always back up first:

```bash
cp -p "$HOME/.claude.json" "$HOME/.claude.json.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null
```

Read the file, parse JSON, merge into `mcpServers`:

```json
{
  "mcpServers": {
    "medusa": {
      "type": "credentials-only",
      "env": {
        "MEDUSA_BACKEND_URL": "<the URL>",
        "MEDUSA_ADMIN_SECRET_KEY": "<the sk_ key>",
        "MEDUSA_PUBLISHABLE_KEY": "<the pk_ key>"
      },
      "_note": "No launchable command - Medusa has no upstream MCP. Credentials are duplicated in ~/.claude/medusa-connector.env. Source that file from Bash to operate the store."
    }
  }
}
```

Preserve every other `mcpServers` entry. Use `Write` (not `Edit`) so the merge happens via parsed-JSON → re-serialize, not regex on the raw file.

After write, re-read both files with `Read`, parse, confirm all three vars are present and non-empty in `mcpServers.medusa.env` AND in `~/.claude/medusa-connector.env`. If either fails, do not proceed to Step 7 - tell the user something went wrong with saving and offer to retry.

### Step 7 - Smoke-test the connection

One Admin REST call, one Store REST call:

```bash
source "$HOME/.claude/medusa-connector.env"

# Admin smoke - list 1 product (proves Secret Key auth works)
ADMIN_HTTP=$(curl -sS -m 10 -o /tmp/medusa-admin-smoke.json -w "%{http_code}" \
  -H "Authorization: Bearer $MEDUSA_ADMIN_SECRET_KEY" \
  "$MEDUSA_BACKEND_URL/admin/products?limit=1")

# Store smoke - list regions (proves Publishable Key works against /store/*)
STORE_HTTP=$(curl -sS -m 10 -o /tmp/medusa-store-smoke.json -w "%{http_code}" \
  -H "x-publishable-api-key: $MEDUSA_PUBLISHABLE_KEY" \
  "$MEDUSA_BACKEND_URL/store/regions?limit=1")

echo "admin=$ADMIN_HTTP store=$STORE_HTTP"
```

- `admin=200 store=200` → fully connected. Tell the user: *"All set - your Medusa store is now connected. I can read products, orders, customers, and discounts, and your future Next.js storefront can talk to the store too."*
- `admin=401` → the Secret Key didn't authenticate. Most common cause: Medusa version mismatch (this SKILL targets v2). Stop, tell the user.
- `admin=200 store=401` → Publishable Key is invalid. Re-run Step 5 only; agents will still work, only the storefront path is broken.
- Connection error → the URL stopped responding between Step 2 and now. Suggest the user check the server is still up.

**Wipe the smoke-test files** so the key payloads don't linger:

```bash
rm -f /tmp/medusa-admin-smoke.json /tmp/medusa-store-smoke.json
unset MEDUSA_ADMIN_SECRET_KEY MEDUSA_PUBLISHABLE_KEY
```

---

## PHASE 2 - Operate the store

Whenever Claude is asked to read or change something in the Medusa store, the recipe is the same: source the env file, curl the right endpoint, never expose the Secret Key.

```bash
source "$HOME/.claude/medusa-connector.env"
```

### Common Admin recipes

```bash
# List the 10 most recent orders
curl -sS -H "Authorization: Bearer $MEDUSA_ADMIN_SECRET_KEY" \
  "$MEDUSA_BACKEND_URL/admin/orders?limit=10&order=-created_at" | jq

# Get a specific order
curl -sS -H "Authorization: Bearer $MEDUSA_ADMIN_SECRET_KEY" \
  "$MEDUSA_BACKEND_URL/admin/orders/$ORDER_ID" | jq

# Create a product (minimal shape; for full schema query medusa-dev:MedusaDocs)
curl -sS -X POST -H "Authorization: Bearer $MEDUSA_ADMIN_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{"title":"Demo Tee","status":"draft","options":[{"title":"Size","values":["S","M","L"]}]}' \
  "$MEDUSA_BACKEND_URL/admin/products" | jq

# List active discount codes
curl -sS -H "Authorization: Bearer $MEDUSA_ADMIN_SECRET_KEY" \
  "$MEDUSA_BACKEND_URL/admin/promotions?limit=20" | jq
```

### Common Store recipes (storefront-grade - uses Publishable Key)

```bash
# List regions for the storefront's region selector
curl -sS -H "x-publishable-api-key: $MEDUSA_PUBLISHABLE_KEY" \
  "$MEDUSA_BACKEND_URL/store/regions" | jq

# Browse the catalog (what the customer sees)
curl -sS -H "x-publishable-api-key: $MEDUSA_PUBLISHABLE_KEY" \
  "$MEDUSA_BACKEND_URL/store/products?limit=12" | jq
```

For any endpoint not in this list, query `medusa-dev:MedusaDocs` at runtime - it has the full v2 API reference and tends to be more current than any frozen recipe sheet here.

### Step 8 - Install the upstream Medusa skill plugins (autonomous, no prompts)

Medusa Labs publishes four official Claude Code plugins at [`medusajs/medusa-agent-skills`](https://github.com/medusajs/medusa-agent-skills) (the same place `mcp__plugin_medusa-dev_MedusaDocs` came from). The dev-side three install **automatically** - no per-plugin prompts. The fourth (`medusa-cloud`) is conditional on the next step's answer.

> **Why this is a plugin install, not a mirrored set of files.** The upstream repo has no LICENSE, so redistributing the content is not permitted. The marketplace install is the official path.

Add the marketplace once and install the dev bundle (idempotent - safe to re-run):

```bash
claude plugin marketplace add medusajs/medusa-agent-skills >/dev/null 2>&1 || true
claude plugin install medusa-dev@medusa >/dev/null 2>&1
claude plugin install ecommerce-storefront@medusa >/dev/null 2>&1
claude plugin install learn-medusa@medusa >/dev/null 2>&1
```

After install, tell the user once: *"I've added three Medusa knowledge packs to Claude - you'll need to close and reopen Claude Code once before they activate."* The reopen is unavoidable (Claude Code reconciles new MCP surface only at startup); do not narrate further.

On the next launch, these become available:

- **`mcp__plugin_medusa-dev_MedusaDocs__*`** - fast Medusa docs lookup at runtime
- **SKILLs auto-activating on Medusa work** - `building-with-medusa`, `building-storefronts`, `building-admin-dashboard-customizations`, `storefront-best-practices`, plus utility commands `db-generate`, `db-migrate`, `new-user`, and the interactive tutorial `learning-medusa`

If `claude plugin marketplace add` fails (rare - usually network or rate limit), tell the user *"The Medusa skill pack didn't install but your store is still connected. You can run the install yourself later; for now I can still operate your store via the connection."* The connector itself does not depend on these plugins - they're an enrichment, not a requirement.

---

### Step 9 - Self-host or Medusa Cloud?

Exactly one question:

> *"For your store's backend, do you want to **self-host it** - you (or this agent team) provision the server, the database, and the deploy pipeline; you own everything, no monthly platform fee - or use **Medusa Cloud** - Medusa Labs hosts the backend for you, you get a managed deploy with logs and metrics, monthly subscription?"*

Two short bullets if they ask for clarification:

- **Self-host** - pick this if you want full ownership, have credits on AWS/GCP/Azure/Vercel/Railway, or expect cost to matter at scale. Setup takes ~30 min via this skill on the workshop default stack (Railway + Vercel + Supabase).
- **Medusa Cloud** - pick this if you want zero infra work, prefer a managed deploy story, and are OK with the subscription cost. Setup takes ~10 min - Medusa Labs handles provisioning, you just point them at your Git repo.

Branch on the answer:

- **Medusa Cloud** → continue to **Step 10A**.
- **Self-host** → continue to **Step 10B**.
- **Not sure** → recommend Medusa Cloud for time-constrained workshop runs, self-host for users who want to learn the full stack. Then re-ask.

---

### Step 10A - Medusa Cloud setup (if Step 9 answered "Medusa Cloud")

Install the cloud plugin (adds the `mcloud` CLI skills + cloud-CLI MCP tools):

```bash
claude plugin install medusa-cloud@medusa >/dev/null 2>&1
```

Tell the user *"Adding the Medusa Cloud skill pack - close and reopen Claude Code once when this finishes."*

The plugin ships its own `using-medusa-cloud` SKILL which is the canonical operating guide for `mcloud login`, project creation, environment provisioning, deploy, logs, and variable management. **Do not re-implement those flows here** - after reopen, the `using-medusa-cloud` SKILL auto-activates on cloud operations and is more current than anything frozen in this connector.

What this connector skill does after reopen, in the next conversation turn:

1. Install the `mcloud` CLI (`npm install -g @medusajs/cli-cloud` or follow the cloud SKILL's recommended path).
2. Run `mcloud login` - this opens a browser flow for Medusa Cloud auth. Drive it in Playwright if Step 3's Playwright session is still up, or let the OS browser handle it.
3. Either link an existing Cloud project or create a new one.
4. Persist `MEDUSA_CLOUD_PROJECT_SLUG` into `~/.claude/medusa-connector.env` for the Phase 3 team's deployer to read.

After Step 10A completes, the Phase 3 ecommerce-medusa-cloud team (`prompts/07-ecommerce-medusa-cloud-team.md` in `claude-workshop-v3-building`) is the right next step - its deployer agent assumes `mcloud` is logged in and the project is linked.

Set the deploy-target flag and stop:

```bash
echo 'MEDUSA_DEPLOY_TARGET="cloud"' >> "$HOME/.claude/medusa-connector.env"
```

---

### Step 10B - Self-host platform menu (if Step 9 answered "Self-host")

Five pieces of infrastructure are needed for a self-hosted Medusa store: **backend host** (runs the Medusa Node.js process), **Postgres** (Medusa's persistence), **Redis** (Medusa v2 requires it for events/cache), **file storage** (product images, S3-compatible), and **storefront host** (the Next.js front-end). Two paths:

#### Path 1 - Workshop default stack (Playwright-drivable, ~20 min total)

This is the recommended path for any user who doesn't already have AWS/GCP/Azure accounts wired up. All four signups can be driven through Playwright.

| Piece | Platform | Why | Skill to dispatch into |
|---|---|---|---|
| Backend + Postgres + Redis | **Railway** | Has an official Medusa template - one-click provisioning, ~3 min | [`railway-deployment`](../railway-deployment/SKILL.md) (Phase 3A - Medusa template path) |
| File storage | **Cloudflare R2** | S3-compatible, generous free tier, ~2 min | [`cloudflare-deployment`](../cloudflare-deployment/SKILL.md) |
| Storefront | **Vercel** | Next.js's home turf, native preview deployments | [`deploy-to-vercel`](../deploy-to-vercel/SKILL.md), [`vercel-deployment`](../vercel-deployment/SKILL.md) |

> *"My recommendation: Railway for the backend (it has an official Medusa template, so the database, Redis, and the backend deploy together in one click), Cloudflare R2 for product images, and Vercel for the storefront. Want me to set those up now? You'll click 'Allow' a couple times in a browser window - nothing else."*

After confirmation, dispatch into the three skills in this order. Each one is workshop-grade UX (Playwright-driven, no terminal prompts to the user) and writes back to a known state file the next skill in the chain reads:

1. **Railway** - switch to the `railway-deployment` SKILL. Its **Phase 3A** is specifically built for this hand-off: drives Railway's official Medusa template, provisions backend + Postgres + Redis in ~3 minutes, and appends `RAILWAY_MEDUSA_URL` + `RAILWAY_DATABASE_URL` + `RAILWAY_REDIS_URL` + `RAILWAY_PROJECT_SLUG` to `~/.claude/medusa-connector.env`. **Important**: this provisions a *fresh* Medusa instance - if the user already had one running (from Step 1 of Phase 1), they should not double-provision. Before dispatching, ask: *"Earlier you told me your Medusa is running at `${MEDUSA_BACKEND_URL}`. Want me to migrate that to Railway, or keep your current backend and only set up storefront + storage here?"* If keep, skip the Railway dispatch and only continue to R2 + Vercel.
2. **Cloudflare R2** - switch to the `cloudflare-deployment` SKILL. Drives Cloudflare signup if needed, then navigates to R2, creates a bucket named `medusa-${random-suffix}`, generates an R2-edit-scoped API token, and writes `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT` to `~/.claude/medusa-connector.env`.
3. **Vercel** - switch to the `deploy-to-vercel` SKILL. Drives Vercel signup (GitHub OAuth). The storefront repo gets created by the Phase 3 frontend-builder agent, so the Vercel skill here only needs to confirm the account exists and capture the team slug - persist `VERCEL_TEAM` to the env file so the deployer agent can target it later.

Append every captured value to `~/.claude/medusa-connector.env`:

```bash
cat >> "$HOME/.claude/medusa-connector.env" <<EOF

# === Self-host stack provisioned $(date -u +%Y-%m-%dT%H:%M:%SZ) ===
MEDUSA_DEPLOY_TARGET="self-host"
MEDUSA_DEPLOY_BACKEND_HOST="railway"
MEDUSA_DEPLOY_STOREFRONT_HOST="vercel"
MEDUSA_DEPLOY_STORAGE="cloudflare-r2"

# Railway (backend + DB + Redis) - only present if Step 10B path 1 provisioned a fresh stack
RAILWAY_DATABASE_URL="..."
RAILWAY_REDIS_URL="..."

# Cloudflare R2 (file storage)
R2_ENDPOINT="..."
R2_ACCESS_KEY_ID="..."
R2_SECRET_ACCESS_KEY="..."
R2_BUCKET="..."

# Vercel (storefront)
VERCEL_TEAM="..."
EOF
chmod 600 "$HOME/.claude/medusa-connector.env"
```

#### Path 2 - User already has cloud accounts (BYO platforms)

If the user already runs workloads on AWS / GCP / Azure / their own VPS, don't push them onto Railway. Present this menu and let them pick:

| Backend host | Postgres | Redis | File storage | Skill to dispatch into |
|---|---|---|---|---|
| **Railway** (workshop default) | Railway Postgres | Railway Redis | (use R2 or S3) | [`railway-deployment`](../railway-deployment/SKILL.md) |
| **AWS** ECS Fargate / App Runner / EC2 | RDS Postgres / Aurora | ElastiCache | S3 | [`aws-connector`](../aws-connector/SKILL.md) |
| **GCP** Cloud Run / GKE | Cloud SQL Postgres | Memorystore | GCS | (no kit skill - defer to user) |
| **Azure** Container Apps / AKS | Azure DB for Postgres | Azure Cache for Redis | Blob Storage | [`azure-connector`](../azure-connector/SKILL.md) |
| **Render** | Render Postgres | Render Key-Value (Redis) | (use R2 or S3) | [`render-deployment`](../render-deployment/SKILL.md) |
| **Fly.io** | Fly Postgres | Fly Upstash Redis | Cloudflare R2 / Tigris | (no kit skill - CLI-driven; the user runs `flyctl launch`) |
| **DigitalOcean** App Platform | Managed Postgres | Managed Redis | Spaces | (no kit skill - defer to user) |
| **Self-managed VPS** | self-managed | self-managed | self-managed | (no kit skill - user owns the infra) |
| **Storefront - Vercel** | - | - | - | [`deploy-to-vercel`](../deploy-to-vercel/SKILL.md) |
| **Storefront - Cloudflare Pages** | - | - | - | [`cloudflare-deployment`](../cloudflare-deployment/SKILL.md) |
| **Storefront - Netlify** | - | - | - | [`netlify-deployment`](../netlify-deployment/SKILL.md) |
| **Storefront - AWS Amplify** | - | - | - | (no kit skill - defer) |

Ask:

> *"Which platform do you want for the backend? And for the storefront, do you want Vercel (the default) or something else?"*

After they pick, persist their choice and dispatch:

```bash
cat >> "$HOME/.claude/medusa-connector.env" <<EOF

# === BYO platform choice ===
MEDUSA_DEPLOY_TARGET="self-host"
MEDUSA_DEPLOY_BACKEND_HOST="<their-pick>"          # e.g. "aws", "gcp", "azure", "render", "fly", "do", "vps"
MEDUSA_DEPLOY_STOREFRONT_HOST="<their-pick>"       # e.g. "vercel", "cloudflare-pages", "netlify"
MEDUSA_DEPLOY_STORAGE="<their-pick>"               # e.g. "s3", "gcs", "blob", "spaces", "r2"
EOF
chmod 600 "$HOME/.claude/medusa-connector.env"
```

Then dispatch into the paired skill:

- Railway pick → "I'll continue your Railway setup in the `railway-deployment` skill - switching there now."
- AWS pick → switch to `aws-connector`
- Azure pick → switch to `azure-connector`
- Render pick → switch to `render-deployment`
- Cloudflare Pages pick → switch to `cloudflare-deployment`
- Vercel pick (for storefront) → switch to `deploy-to-vercel`
- Netlify pick (for storefront) → switch to `netlify-deployment`
- For platforms without a kit skill (GCP, Fly.io, DigitalOcean, VPS): the Phase 3 deployer agent reads `MEDUSA_DEPLOY_BACKEND_HOST` and follows the platform's CLI/console docs - Claude will guide the user platform-by-platform at deploy time.

#### Important for BOTH paths

The Phase 3 ecommerce-medusa team's deployer agent reads `MEDUSA_DEPLOY_*` from `~/.claude/medusa-connector.env` and uses them to:

- Decide which deploy path to follow.
- Wire the Medusa backend's `medusa-config.ts` to point at the captured Postgres / Redis / file-storage credentials.
- Inject `MEDUSA_BACKEND_URL` and `MEDUSA_PUBLISHABLE_KEY` (not the secret key - never the secret key) into the storefront's `.env.local` at build time.

If the user picks "I'm not sure / I'll figure it out at deploy time", set `MEDUSA_DEPLOY_TARGET="self-host"` with empty `MEDUSA_DEPLOY_BACKEND_HOST=""` and let the Phase 3 deployer re-ask at deploy time. That's a valid path for workshop time-pressure - defer the choice but record that they're on self-host.

---

### Hand-off to a Phase 3 ecommerce-medusa team

The Phase 3 ecommerce-medusa team (`prompts/05-ecommerce-medusa-team.md` in `claude-workshop-v3-building`) expects these env vars to exist. After this SKILL completes, that team can read the env file directly:

```bash
source ~/.claude/medusa-connector.env
# Now MEDUSA_BACKEND_URL, MEDUSA_ADMIN_SECRET_KEY, MEDUSA_PUBLISHABLE_KEY are available
```

The frontend-builder agent in that team will inject `MEDUSA_BACKEND_URL` and `MEDUSA_PUBLISHABLE_KEY` (NOT the Secret Key - never ship the Secret Key to the browser) into `.env.local` for the Next.js project at build time.

---

## Troubleshooting

### `admin=401` on the smoke test

The Secret Key didn't authenticate. Three possible causes, in order of likelihood:

1. **Medusa version is v1.** This SKILL is v2-only. v1's admin auth uses session cookies + JWT, not Secret Keys. Tell the user and stop.
2. **The user revoked the key in the admin between Step 4 and Step 7.** Re-run Phase 1 from Step 4.
3. **The token captured from the DOM was truncated.** Medusa's reveal modal can have a "Copy" button next to the value; if the snapshot read from the wrong DOM node, the key may be missing a suffix. Re-run Phase 1 from Step 4, this time use `browser_evaluate` to read the input's `.value` property directly instead of innerHTML.

### "API Key Management" menu item is missing from Settings

Most likely the logged-in admin user doesn't have the `api_key:manage` permission. Tell the user *"Your Medusa account doesn't have permission to create API keys. Ask whoever runs your Medusa instance to give you that permission, or sign in as an admin user."* Stop.

### `health` endpoint returns 404

Some self-hosted Medusa deployments behind reverse proxies don't expose `/health` at the root. As a fallback, try `/admin/auth` (returns 401 if not logged in but proves the backend is reachable) or `/store/regions` (returns 200 with empty data if no regions are seeded yet). If neither works, the URL is wrong; ask the user to double-check.

### Medusa admin UI says the URL is "localhost" but Claude is running on the same machine

`localhost` resolves on the same host - fine. But if the user is running Medusa in Docker with a different port mapping, the host port (e.g. `9000:9000`) is what Claude needs, not the in-container port. If `curl http://localhost:9000/health` errors with connection refused but the admin UI works in the user's browser, ask: *"Are you running Medusa in Docker? If so, what port did you map it to on your computer?"*

### Token was leaked to chat by accident

If the Secret Key appears in any chat output, tool-call return, or screen recording before Step 6 completes:

1. **Immediately rotate.** Go to the Medusa admin → Settings → Developer → API Key Management → click the leaked key → **Revoke**. The leaked key becomes invalid instantly.
2. Create a fresh Secret Key (re-run Step 4 with a new title like `Claude Code agent (rotated YYYY-MM-DD)`).
3. Update `~/.claude/medusa-connector.env` with the new value (re-run Step 6).
4. Save a memory entry noting how the leak happened so future sessions avoid the same path.

The same rotation playbook applies to the Publishable Key, but the consequences are smaller (Publishable Keys are designed to be embedded in client-side code; they're scoped to read-only operations on `/store/*` plus cart creation).

---

## What this SKILL does NOT cover

- **Hosting/deploying a Medusa instance to a public URL.** This SKILL handles *local* scaffolding via Phase A (`npx create-medusa-app@latest`) and credentials capture (Steps 1-7), but *promoting* the local instance to a hosted URL happens in Steps 9-10 (dispatch to `railway-deployment`, `aws-connector`, etc., OR Medusa Cloud via the `medusa-cloud` plugin). The Phase 3 ecommerce-medusa team's deployer agent picks up from there.
- **Stripe wiring.** Medusa needs a payment provider, typically Stripe. After this SKILL lands, run `stripe-connector` to capture Stripe creds, then the Phase 3 backend-builder will wire `medusa-payment-stripe` into the Medusa config.
- **Migrating from Shopify to Medusa.** Out of scope. Medusa's `medusa-source-shopify` exists for product import but isn't part of this connector.
- **Multi-store / multi-region beyond a single instance.** This SKILL captures creds for one Medusa instance. If the user runs multiple stores, run the SKILL once per store and the env file will be overwritten - manual `medusa-connector.env` editing is needed for multi-instance setups.
- **Medusa v1.** v1's admin auth is JWT+session-cookie; this SKILL targets v2's Secret API Key model.

---

## See also

- [`shopify-connector/SKILL.md`](../shopify-connector/SKILL.md) - sibling, hosted-SaaS variant
- [`wordpress-connector/SKILL.md`](../wordpress-connector/SKILL.md) - structurally identical (self-hosted, user-supplied URL, Playwright admin-login)
- [`stripe-connector/SKILL.md`](../stripe-connector/SKILL.md) - pair with this for the payment side
- [`../CLAUDE.md`](../CLAUDE.md) - the three install-pattern reference (Medusa is "first-party-stdio" alongside shopify/wordpress)
- [Medusa CLI reference](https://docs.medusajs.com/resources/medusa-cli) - canonical CLI command docs. Used by Phase A (project scaffolding via `npx create-medusa-app@latest`) and in-project commands (`npx medusa db:migrate`, `npx medusa user`, `npx medusa exec`).
- [Medusa v2 install guide](https://docs.medusajs.com/learn/installation) - the official "create a new project" walkthrough. Phase A above mirrors this exactly via Bash.
- [Medusa v2 Admin API docs](https://docs.medusajs.com/api/admin) - full endpoint reference
- [Medusa v2 Store API docs](https://docs.medusajs.com/api/store) - storefront endpoint reference
- [Medusa agentic skills overview](https://docs.medusajs.com/learn/introduction/build-with-llms-ai/agentic-skills) - Medusa Labs' official rationale for the four plugins and how they're meant to be used
- [`medusajs/medusa-agent-skills`](https://github.com/medusajs/medusa-agent-skills) - upstream repo for the four Claude Code plugins (`medusa-dev`, `ecommerce-storefront`, `learn-medusa`, `medusa-cloud`). No LICENSE on the repo - use via the marketplace install path in Step 8, not by mirroring files.
- `medusa-dev:MedusaDocs` plugin - answers Medusa-specific questions at agent runtime; pair-with for all Phase 2 operate-the-store work
