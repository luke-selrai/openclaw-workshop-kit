---
title: Stripe Setup Guide
version: 1.0
date: 2026-04-10
---

# Stripe — Setup Guide

This guide connects your Stripe account to your AI assistant. Once set up, your assistant can look up payments, manage customers, send invoices, and handle subscriptions — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [the setup walkthrough](../start/full-setup.md) if not done yet)
- A Stripe account (free to create at stripe.com)
- An internet connection

> **No coding experience required.** The Stripe CLI handles authentication — your API keys never need to leave your machine.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Payments** | View payment intents, charges, and issue refunds |
| **Invoices** | Create, send, finalize, and void invoices |
| **Subscriptions** | View, create, update, and cancel subscriptions |
| **Customers** | Look up customers, search by email, manage payment methods |

---

## Step 1 — Install the Stripe CLI

Open your command window (Terminal on Mac, Command Prompt or PowerShell on Windows).

**Mac:**
```
brew install stripe/stripe-cli/stripe
```

> If you don't have Homebrew, install it first from [brew.sh](https://brew.sh).

**Windows — Option A (Scoop):**
```
scoop bucket add stripe https://github.com/stripe/scoop-stripe-cli.git
scoop install stripe
```

**Windows — Option B (winget):**
```
winget install Stripe.StripeCLI
```

**Windows — Option C (manual):**
1. Go to https://github.com/stripe/stripe-cli/releases
2. Download the latest `stripe_X.X.X_windows_x86_64.zip`
3. Extract the zip
4. Move `stripe.exe` to a folder that is in your PATH (e.g. `C:\Windows\System32`)

After install, verify it worked:
```
stripe --version
```

You should see a version number (e.g. `stripe version 1.40.3`). If you see "command not found":
- **Windows:** Close the command window and open a new one, then try again
- **Mac:** Run `brew doctor` and follow any instructions, then try again

---

## Step 2 — Log In to Stripe

```
stripe login
```

A pairing code will appear in the terminal and a browser window will open:

1. **Sign in to your Stripe account** (or create one at stripe.com if you don't have one yet)
2. **Verify the pairing code** shown in the terminal matches what you see in the browser
3. Click **Allow access** when prompted
4. You should see a success message: `Done! The Stripe CLI is configured for your-account-name`

> **If the browser does not open automatically**, copy the URL shown in the terminal and paste it into your browser manually.

> **Note:** The Stripe CLI creates a **restricted API key** with read/write access. It is stored securely on your machine and is separate from your main secret key.

---

## Step 3 — Verify the Connection

```
stripe customers list --limit 1
```

You should see either a customer record or an empty list `[]`. If you see an error, check the troubleshooting section below.

---

## Test Mode vs Live Mode

By default, the Stripe CLI operates in **test mode** — all operations are safe and no real money moves.

When you are ready to work with real data, add `--live` to your command:

```
stripe customers list --live --limit 5
```

> Your assistant will always confirm with you before switching to live mode.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"List my last 10 customers"*
- *"Find the customer with email jane@example.com"*
- *"Show me all unpaid invoices"*
- *"Create an invoice for customer cus_xxx for $500 due in 30 days"*
- *"Cancel the subscription sub_xxx at the end of the billing period"*
- *"Show me all active subscriptions"*
- *"How many payments did I receive this month?"*
- *"Issue a refund for charge ch_xxx"*

---

## Troubleshooting

### "command not found: stripe"
The CLI is not in your PATH. Try:
- **Mac:** Run `brew link stripe-cli` then open a new terminal window
- **Windows:** Close and reopen the command window. If still not found, re-install using winget: `winget install Stripe.StripeCLI`

### "You are not logged in"
Run `stripe login` again. Your session may have expired.

### "Error: No such customer"
The ID you provided doesn't exist in the current mode. Check you are in the right mode (test vs live) with `stripe config --list`.

### "Rate limit exceeded"
Stripe limits how many API calls can be made per second. Wait a few seconds and try again.

### Browser didn't open during login
Copy the URL printed in the terminal and paste it into your browser manually.

### Need to switch Stripe accounts
Run `stripe logout` then `stripe login` to authenticate with a different account.

---

## Security Notes

- The Stripe CLI stores a **restricted key** locally — it has access only to your account data, not to Stripe's infrastructure
- Never share your **secret key** (`sk_live_...` or `sk_test_...`) — treat it like a password
- The CLI key can be revoked at any time from the Stripe Dashboard under Developers → API keys
- Your assistant operates in **test mode by default** and will ask before switching to live mode
