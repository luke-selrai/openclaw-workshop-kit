---
name: stripe-connector
description: Install and operate the Stripe connector autonomously. Use this skill when the user asks to set up Stripe, connect their payment account, or interact with payments, invoices, subscriptions, or customers. Phase 1 is fully autonomous — Claude drives the Stripe CLI install and OAuth via a Playwright MCP browser; the user only signs in to Stripe Dashboard once. Phase 2 uses the `stripe` CLI for API operations.
allowed-tools: mcp__playwright__*, Bash, Read, Write, Edit
metadata:
  category: Payments & Billing
  tags:
    - stripe
    - payments
    - invoices
    - subscriptions
    - customers
    - billing
  pairs-with:
    - skill: email-composer
      reason: Compose payment confirmation or invoice emails, then send via Gmail connector
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by Stripe webhooks (payment succeeded, subscription cancelled, etc.)
---

# Stripe Connector

## Overview

This skill does two things:
1. **Installs** the Stripe CLI on the user's computer (one-time setup)
2. **Operates** the connector — querying payments, invoices, subscriptions, and customers via the Stripe CLI and API

The connector uses the **Stripe CLI** (`stripe`) for authentication and API operations via `stripe login` and `stripe <resource> <command>`.

> **Account support:** Requires a Stripe account (live or test mode). Both standard accounts and Connect platforms are supported.

> **Why this skill is autonomous.** Stripe's CLI ships a built-in agent flow: `stripe login` auto-detects non-TTY stdin and emits a JSON object with `browser_url`, `verification_code`, and a `next_step` command. Claude drives Playwright to the browser URL, confirms the verification code matches (Stripe's designed safety check against pairing-code spoofing), clicks Allow, and the `next_step` polling command captures credentials. No CLI patches, no env-var hacks — the upstream design supports this end-to-end.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Stripe once. Every message during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy URLs, paste codes, or read terminal output. The only action you ever request is: "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say OAuth, API key, JSON, stdin, TTY, polling, callback, or file paths to the user. If you must refer to a technical thing, name it plainly: "the Stripe connection tool", "the browser window I just opened", "a small one-time setup step on your computer".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm setting up Stripe for you now"), once when you need them ("please sign in"), once when you're done ("your Stripe is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Stripe is now connected." Bad: "Verification code matched, polling endpoint returned 200, credentials saved to config.toml."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo the API key or verification code** back to the user. Both are stored locally; never include them in any output visible to the user.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude installs the Stripe CLI, runs the non-interactive auth flow, and drives the consent click-through entirely inside a Playwright MCP browser. The user's only role is signing in to Stripe Dashboard in the Playwright window when prompted in Step 3.

> **Reasoning model.** Each step describes a *goal*. Achieve it by reading CLI output, taking `browser_snapshot` when navigating Stripe pages, and reasoning about what's on the page. Re-snapshot whenever the page state changes. Don't hardcode CSS selectors against the Stripe Dashboard — the UI evolves.

### Step 1 — Check if `stripe` is already installed and authenticated

```bash
stripe --version
```

If this returns a version number, proceed to the auth check. If `stripe` is missing, jump to Step 2.

**Auth check:** probe the saved config without triggering interactive prompts:

```bash
stripe config --list 2>/dev/null | grep -E '^test_mode_api_key|^live_mode_api_key' | head -1
```

If a key line prints (test or live), the CLI is already authenticated. Skip to Phase 2. If no keys are configured, proceed to Step 3 (auth).

If both checks pass and the user's account is already cached, the connector is set up. Skip to Phase 2.

### Step 2 — Install the Stripe CLI

Pick the platform-appropriate installer and run silently. After install, refresh PATH for the current shell so subsequent steps can find the binary in this Bash session.

**macOS (Homebrew):**
```bash
brew install stripe/stripe-cli/stripe
```

**Windows (winget):**
```bash
winget install --id Stripe.StripeCLI --accept-package-agreements --accept-source-agreements
```

> **Windows PATH note.** winget appends to the user PATH but the current shell does not see it until restart. Resolve the binary directly for the rest of this session:
> ```bash
> STRIPE_BIN="$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages/" -name 'stripe.exe' 2>/dev/null | head -1)"
> alias stripe="\"$STRIPE_BIN\""
> ```
> The user's next fresh terminal will see `stripe` on PATH naturally; this alias keeps Phase 1 working without forcing a restart mid-flow.

**Windows (Scoop) — fallback if winget unavailable:**
```bash
scoop bucket add stripe https://github.com/stripe/scoop-stripe-cli.git
scoop install stripe
```

**Linux (Debian/Ubuntu via APT — the canonical Stripe-maintained path):**
```bash
curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | sudo tee /usr/share/keyrings/stripe.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee -a /etc/apt/sources.list.d/stripe.list
sudo apt update
sudo apt install stripe
```

**Linux (other distros) — manual fallback:** download the appropriate release tarball from `https://github.com/stripe/stripe-cli/releases/latest`, extract, and place `stripe` on PATH (e.g., `/usr/local/bin`).

Verify:
```bash
stripe --version
```

If the verify command still errors after install (`command not found` on Mac/Linux even with brew on PATH), tell the user plainly: *"The terminal needs a refresh — please close this window, open a new one, then say 'ready'."* Wait, then retry.

### Step 3 — Authenticate (autonomous via Playwright)

Tell the user, in one short message:

> "I'm opening a browser window for you — please sign in to your Stripe Dashboard when it appears, and I'll handle the rest."

**3a. Get the auth URL via the non-interactive flow.** Stripe's CLI auto-activates non-interactive mode when stdin is not a TTY (which is the case in any agent context); the `--non-interactive` flag forces it explicitly:

```bash
stripe login --non-interactive
```

The CLI prints a JSON object to stdout and exits immediately:

```json
{
  "browser_url": "https://dashboard.stripe.com/stripecli/confirm_auth?t=...",
  "verification_code": "<four-words-pairing-code>",
  "next_step": "stripe login --complete '<poll-url>'"
}
```

Parse the three fields. Store `verification_code` for the Step 3c safety check. Store the `next_step` command for Step 3b.

**3b. Start the polling background task.** Run the captured `next_step` command as a background process so it polls Stripe's auth endpoint while Playwright drives the consent page:

```
Bash(command: "<next_step command from JSON>", run_in_background: true, description: "Poll Stripe approval")
```

This returns a `bash_id`. The polling command blocks until the user clicks Allow in the browser (then captures + stores credentials and exits successfully).

**3c. Drive Playwright to the browser_url.** Navigate using the user's persistent Playwright profile (signed in to Stripe Dashboard if previously logged in there):

```
mcp__playwright__browser_navigate({ url: "<browser_url>" })
```

Take a `browser_snapshot`. Reason about state:

- **Sign-in page** (Email + Password inputs visible) → tell the user *once*: *"Please sign in to Stripe in the browser window I just opened."* Wait for the page to advance. The Stripe sign-in flow handles 2FA automatically; the page redirects to the verification step once auth completes.
- **Account picker** (Connect platforms with multiple accounts) → click the account the user wants the CLI to use. If unclear which account, tell the user *once* and wait.
- **Onboarding wizard** (alertdialog with `Welcome to Stripe`, `Stripe N` heading, and a `Step X of 7` progressbar — Stripe blocks the consent page behind this for fresh accounts that haven't completed business-profile setup) → click **Skip** when the wizard offers it (Step 4 onwards typically does), **This doesn't apply to me** when present, **Continue** for product-selection screens (Step 5) where defaults are accepted, and **Go to sandbox** on the final Step 7. After the final step, Stripe redirects automatically to `/auth_stripecli`. **Caution on poll timeout:** if the wizard takes more than ~5 minutes (default `stripe login --complete` polling window), the polling task times out with `exceeded max attempts` — restart Step 3a (fresh JSON) once the wizard is past the user-input screens and the rest of the flow can run quickly. If the wizard demands real business info the user doesn't want to type via Claude (e.g., legal name, ABN), tell the user *once*: *"Stripe wants your business details before letting me connect — please fill those in, then I'll handle the rest."*
- **Verification page** ("Allow CLI access?" or similar wording showing a pairing code) → **safety check first:** confirm the displayed pairing code on the page matches `verification_code` captured in Step 3a. If it matches, click **Allow access** via DOM-extract. **If it doesn't match, abort cleanly — never click Allow on a mismatched code.** This match is the security guarantee Stripe designed in to prevent pairing-code spoofing.

**3d. Wait for the polling background task to capture credentials.** Poll `BashOutput(bash_id: "<id>")` until the success line appears (typically 1-3 seconds after Allow click; up to 30 seconds on slow networks). The CLI prints a confirmation message such as `Done! The Stripe CLI is configured for ...` to stdout when credentials are stored. Use a 15-minute timeout (first-time 2FA setup commonly takes 8-12 minutes).

> **Token storage.** Stripe's CLI stores credentials in `~/.config/stripe/config.toml` on Mac/Linux or `%APPDATA%\stripe\config.toml` on Windows. Subsequent `stripe ...` calls reuse the credentials. The default profile is `[default]`; multiple Connect accounts use named profiles via `stripe login --project-name=<name>`.

### Step 4 — Verify (binary smoke gate)

```bash
stripe customers list --limit 1
```

If customer data (or an empty list) is returned, the connector is working. Continue to Phase 2.

If the verify command returns a 401 / `Unauthorized`, the credentials didn't persist correctly. Re-run Step 3 (`stripe logout` first to clear partial state, if it errors).

---

## Part 2 — Customers

All operations use the `stripe` CLI which calls the Stripe API directly.

### List customers
```bash
stripe customers list --limit 10
```

### Search customers by email
```bash
stripe customers search --query "email:'user@example.com'"
```

### Get a single customer
```bash
stripe customers retrieve cus_XXXXXXXXXXXXXXXX
```

### Create a customer
```bash
stripe customers create \
  --name="Jane Doe" \
  --email="jane@example.com" \
  --phone="+61400000000" \
  --description="VIP customer"
```
> Always confirm customer details with the user before creating.

### Update a customer
```bash
stripe customers update cus_XXXXXXXXXXXXXXXX \
  --description="Updated description"
```

### List a customer's payment methods
```bash
stripe payment_methods list \
  --customer=cus_XXXXXXXXXXXXXXXX \
  --type=card
```

---

## Part 3 — Payments

### List recent payment intents
```bash
stripe payment_intents list --limit 10
```

### Get a single payment intent
```bash
stripe payment_intents retrieve pi_XXXXXXXXXXXXXXXX
```

### List charges
```bash
stripe charges list --limit 10
```

### Get a single charge
```bash
stripe charges retrieve ch_XXXXXXXXXXXXXXXX
```

### List charges for a customer
```bash
stripe charges list --customer=cus_XXXXXXXXXXXXXXXX --limit 10
```

### Create a payment intent (test mode)
```bash
stripe payment_intents create \
  --amount=2000 \
  --currency=usd \
  --customer=cus_XXXXXXXXXXXXXXXX \
  --description="Order #1234"
```
> Amount is in the smallest currency unit (e.g. cents for USD). Always confirm with the user before creating.

### Refund a charge
```bash
stripe refunds create \
  --charge=ch_XXXXXXXXXXXXXXXX
```
> Confirm the charge ID and refund amount with the user before executing. Partial refunds: add `--amount=<cents>`.

---

## Part 4 — Invoices

### List invoices
```bash
stripe invoices list --limit 10
```

### List invoices for a customer
```bash
stripe invoices list --customer=cus_XXXXXXXXXXXXXXXX --limit 10
```

### Get a single invoice
```bash
stripe invoices retrieve in_XXXXXXXXXXXXXXXX
```

### Create an invoice
```bash
stripe invoices create \
  --customer=cus_XXXXXXXXXXXXXXXX \
  --collection_method=send_invoice \
  --days_until_due=30
```

### Add a line item to an invoice
```bash
stripe invoiceitems create \
  --customer=cus_XXXXXXXXXXXXXXXX \
  --invoice=in_XXXXXXXXXXXXXXXX \
  --amount=5000 \
  --currency=usd \
  --description="Consulting fee"
```

### Finalize and send an invoice
```bash
# Finalize (locks the invoice)
stripe invoices finalize_invoice in_XXXXXXXXXXXXXXXX

# Send to customer
stripe invoices send_invoice in_XXXXXXXXXXXXXXXX
```
> Confirm with the user before finalizing or sending — finalized invoices cannot be edited.

### Void an invoice
```bash
stripe invoices void_invoice in_XXXXXXXXXXXXXXXX
```

---

## Part 5 — Subscriptions

### List subscriptions
```bash
stripe subscriptions list --limit 10
```

### List subscriptions for a customer
```bash
stripe subscriptions list --customer=cus_XXXXXXXXXXXXXXXX
```

### Get a single subscription
```bash
stripe subscriptions retrieve sub_XXXXXXXXXXXXXXXX
```

### Create a subscription
```bash
stripe subscriptions create \
  --customer=cus_XXXXXXXXXXXXXXXX \
  --items[0][price]=price_XXXXXXXXXXXXXXXX
```
> Get the price ID from `stripe prices list`. Confirm with the user before creating.

### Update a subscription (e.g. change plan)
```bash
stripe subscriptions update sub_XXXXXXXXXXXXXXXX \
  --items[0][price]=price_XXXXXXXXXXXXXXXX
```

### Cancel a subscription
```bash
# Cancel at period end (recommended)
stripe subscriptions update sub_XXXXXXXXXXXXXXXX \
  --cancel_at_period_end=true

# Cancel immediately
stripe subscriptions cancel sub_XXXXXXXXXXXXXXXX
```
> Always confirm cancellation with the user. Prefer `cancel_at_period_end` to avoid prorating.

### List available prices / plans
```bash
stripe prices list --limit 20
```

### List products
```bash
stripe products list --limit 20
```

---

## Part 6 — Webhooks (listen locally)

Use this to test webhook events during development without exposing a public endpoint.

### Start a local webhook listener
```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

This prints a webhook signing secret (`whsec_...`) — use this in your local `.env` as `STRIPE_WEBHOOK_SECRET`.

### Trigger a test event
```bash
# Payment succeeded
stripe trigger payment_intent.succeeded

# Invoice paid
stripe trigger invoice.paid

# Subscription cancelled
stripe trigger customer.subscription.deleted
```

### List available trigger events
```bash
stripe trigger --help
```

---

## Part 7 — Direct API Access (curl fallback)

If the Stripe CLI is unavailable, use `curl` with a secret API key.

### Get the API key

1. Go to the Stripe Dashboard → Developers → API keys
2. Copy the **Secret key** (`sk_live_...` for live, `sk_test_...` for test)
3. Store it securely — never commit it to code

### Make API calls
```bash
STRIPE_KEY="sk_test_xxxxxxxxxxxxxxxxxxxxx"

# List customers
curl -s https://api.stripe.com/v1/customers?limit=10 \
  -u "${STRIPE_KEY}:"

# Get a payment intent
curl -s https://api.stripe.com/v1/payment_intents/pi_XXXXXXXXXXXXXXXX \
  -u "${STRIPE_KEY}:"
```

> The colon after the key is intentional — Stripe uses HTTP Basic Auth with the key as the username and an empty password.

---

## Part 8 — Auth & Session

```bash
# Log in (opens browser)
stripe login

# Log in with a specific account (Connect platforms)
stripe login --project-name=my-project

# View current auth config
stripe config --list

# Switch between live and test mode
stripe --live <command>   # live mode
stripe <command>          # test mode by default

# Log out
stripe logout
```

> **Test mode is the default.** The CLI operates in test mode unless `--live` is passed. Always confirm with the user which mode to use before mutations.

---

## Behaviour Guidelines

- **Always verify auth first** at the start of a session — run `stripe config --list` and confirm the account looks correct.
- **Test mode by default** — never use `--live` unless the user explicitly asks for live mode. Remind the user if they are about to act on live data.
- **Confirm before mutating** — always confirm with the user before creating customers, payments, subscriptions, invoices, or issuing refunds.
- **Confirm before cancelling** — subscription cancellation is not easily reversible. Prefer `cancel_at_period_end=true` unless the user wants immediate cancellation.
- **Confirm before finalizing invoices** — finalized invoices cannot be edited.
- **IDs are prefixed by type** — `cus_` = customer, `pi_` = payment intent, `ch_` = charge, `in_` = invoice, `sub_` = subscription, `price_` = price, `prod_` = product. Use these prefixes to validate IDs.
- **Amounts are in smallest currency unit** — USD amounts are in cents (e.g. `2000` = $20.00). Always display to the user with the decimal in the right place.
- **Pagination** — use `--limit N` and `--starting_after=<id>` for paginated results. Default to 10 items unless the user asks for more.
- **Rate limits** — Stripe's API has rate limits. If you hit a 429, wait a few seconds before retrying.
- **Status values** — Payment intents: `requires_payment_method`, `requires_confirmation`, `requires_action`, `processing`, `requires_capture`, `canceled`, `succeeded`. Subscriptions: `active`, `past_due`, `unpaid`, `canceled`, `incomplete`, `incomplete_expired`, `trialing`. Invoices: `draft`, `open`, `paid`, `void`, `uncollectible`.
- **JSON output** — add `-r` (raw) or pipe to `jq` for structured output: `stripe customers list | jq '.data[].email'`.
- **Auth errors** — if you get a 401, re-run `stripe login`.
