---
name: stripe-connector
description: Install and operate the Stripe connector. Use this skill when the user asks to set up Stripe, connect their payment account, or interact with payments, invoices, subscriptions, or customers. Handles full installation and uses the Stripe CLI + API.
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

---

## Part 1 — Installation

### Step 1: Check if already installed
```bash
stripe --version
```
If this returns a version number, skip to Step 3 (auth check). If "command not found", continue from Step 2.

### Step 2: Install the CLI

**Mac (Homebrew):**
```bash
brew install stripe/stripe-cli/stripe
```

**Windows (Scoop):**
```bash
scoop bucket add stripe https://github.com/stripe/scoop-stripe-cli.git
scoop install stripe
```

**Windows (winget):**
```bash
winget install Stripe.StripeCLI
```

**Windows (manual):** Download the latest release from https://github.com/stripe/stripe-cli/releases — extract the zip and add the folder to your PATH.

After install, verify:
```bash
stripe --version
```

### Step 3: Log in to Stripe

```bash
stripe login
```

**In a terminal (TTY):** This prints a pairing code and opens a browser. The user signs in to their Stripe account and clicks **Allow access**. A restricted API key is saved locally.

**In a non-TTY / agent context:** The CLI outputs JSON with a `browser_url` and a `next_step` command. Show the `browser_url` to the user and ask them to approve in the browser, then run the `next_step` command to complete login:
```bash
stripe login --complete '<poll-url-from-next_step>'
```

> If the browser does not open, copy the URL from the terminal output and paste it into a browser manually.

### Step 4: Verify

```bash
stripe customers list --limit 1
```

If customer data (or an empty list) is returned, the connector is working. You can also check the saved config:

```bash
stripe config --list
```

If customer data (or an empty list) is returned, the connector is working.

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
