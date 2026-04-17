---
title: PayPal — Setup Guide
version: 1.0
date: 2026-04-17
---

# PayPal — Setup Guide

This guide connects your PayPal business account to your AI assistant using the official PayPal MCP server. Once set up, your assistant can create and send invoices, track payments, manage disputes, handle subscriptions, and more — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [full-setup.md](../start/full-setup.md) if not done yet)
- A PayPal **Business** account (personal accounts have limited API access)
- Node.js 20 or newer installed (check with `node --version`)
- An internet connection

> **No coding experience required.** You will copy two values from PayPal's website and paste them to your assistant. Your connection keys stay on your machine and are never sent to third parties.

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
| **Invoices** | Create, send, remind, cancel invoices and generate QR codes for payment |
| **Payments** | Create orders, capture payments, issue refunds |
| **Disputes** | View disputes and accept claims |
| **Tracking** | Add and view shipment tracking on orders |
| **Products** | Create, update, and manage your product catalog |
| **Subscriptions** | Create plans, manage subscribers, cancel subscriptions |
| **Transactions** | View recent transactions |

---

## Step 1 — Choose Your Path

Your assistant will ask whether you want to connect your **real PayPal account** or a **practice sandbox**:

- **Real account (recommended)** — connects to your live PayPal data. Best for everyday use.
- **Practice sandbox** — uses fake data so you can try things out without affecting anything real. Great if you want to experiment first.

> You can switch between the two at any time — just tell your assistant "switch my PayPal to sandbox" or "switch my PayPal to the real account."

## Step 2 — Create an App in PayPal Developer Dashboard (you do this)

This step creates a secure connection key that lets your assistant talk to PayPal on your behalf.

1. Open **https://developer.paypal.com/dashboard/applications** in your browser and sign in with your **business** PayPal account
2. Click the **Create App** button
3. Fill in the form:
   - **App Name:** Claude Assistant
   - **App Type:** Merchant
4. Click **Create App**
5. You will see your app details page with a **Client ID** and a **Secret**
   - **Real account path:** Make sure you are on the **Live** tab (not Sandbox)
   - **Sandbox path:** Make sure you are on the **Sandbox** tab (not Live)
   - You may need to click **Show** next to the Secret to reveal it
6. **Copy both values** — you will give them to your assistant in the next step

> **Important:** Treat these values like a password. Do not share them or post them online.

---

## Step 3 — Tell Your Assistant to Connect (your assistant does the rest)

Open Claude Code and say:

> "Help me connect my PayPal account"

Your assistant will:
1. Ask whether you want the real account or sandbox path
2. Ask you to paste the Client ID and Secret you copied in Step 2
3. Save the connection details securely on your computer
4. Verify the connection is working
5. Tell you when it is ready

> **After setup, restart Claude Code once** so the connection becomes active.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"Show me my recent invoices"*
- *"Create an invoice for Acme Corp for $500"*
- *"Send that invoice now"*
- *"Remind Jane to pay her invoice"*
- *"Show me my unpaid invoices"*
- *"List my recent transactions"*
- *"What came in this week?"*
- *"Refund $50 to order ABC123"*
- *"Do I have any open disputes?"*
- *"Add tracking number XYZ to order ABC"*
- *"Show me my products"*
- *"Create a monthly subscription plan for $29"*
- *"Show me my subscription plans"*
- *"Switch my PayPal to sandbox"* / *"Switch my PayPal to the real account"*

---

## Troubleshooting

### "Your PayPal connection needed a quick refresh"
This is normal — PayPal connections refresh periodically. Your assistant handles this automatically. Just restart Claude Code when asked and carry on. If it keeps happening, tell your assistant: *"My PayPal connection keeps dropping"* and they will re-do the setup.

### "Your PayPal connection has expired"
Your app credentials may have been revoked or changed. Go to PayPal Developer Dashboard → Apps → Claude Assistant and check it is still active. If needed, copy the Client ID and Secret again and tell your assistant: *"I have new PayPal connection keys."*

### "PayPal says your app doesn't have permission"
Some features require a PayPal Business account or specific account tiers. Check that you are using a Business account (not Personal). If the issue persists, check your app permissions in the PayPal Developer Dashboard.

### "PayPal is asking me to slow down" (rate limit)
PayPal limits how many requests can be made per minute. Wait a moment and try again. This is rare in normal use.

### Connection not working after setup
Make sure you restarted Claude Code after the initial setup. The connection only activates after a restart.

### Copied the wrong credentials (Sandbox instead of Live)
Go back to **https://developer.paypal.com/dashboard/applications**, click on your **Claude Assistant** app, switch to the **Live** tab, and copy the Client ID and Secret from there. Tell your assistant: *"I need to update my PayPal connection keys."*

### Need to switch PayPal accounts
Create a new app in the other PayPal business account and tell your assistant: *"I want to switch to a different PayPal account."* They will walk you through updating the connection.

---

## Security Notes

- Your Client ID, Secret, and connection details are stored locally on your computer — they are never sent to third parties
- The app can be deleted at any time from the PayPal Developer Dashboard
- Your assistant will always confirm with you before creating, sending, cancelling, or refunding anything
- The connection uses PayPal's official OAuth 2.0 system — the same standard used by major platforms
- The connection uses the official PayPal MCP server maintained by PayPal's SDK team

---

## What Is NOT Included (Yet)

This connector focuses on **business operations** — invoicing, payments, disputes, tracking, products, subscriptions, and transactions.

The following are **not accessible through the connector** and must be done inside PayPal directly:

- Withdrawing funds or transferring money between accounts
- Peer-to-peer payments (PayPal.me / friends and family)
- Account settings, users, or permissions management
- PayPal Checkout button integration or web SDKs
- Responding to disputes with evidence (use the PayPal Resolution Centre)
- PayPal Business Debit Card or credit products
- Managing multiple PayPal accounts at the same time (one account per connection)

If you need any of these, let your assistant know and they can check if support has been added.

---

## Still Having Trouble?

See [troubleshoot.md](../troubleshoot.md) for more fixes, or ask your assistant:
> "Something went wrong with my PayPal connection. Help me fix it."

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
