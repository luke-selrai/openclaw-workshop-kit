---
title: Square Connector — Setup Guide
version: 1.0
date: 2026-04-14
---

# Square Connector — Setup Guide

This guide connects your **Square account** to Claude Code, using Square's official MCP (Model Context Protocol) server. Once set up, Claude can read and update your payments, customers, catalog, inventory, orders, invoices, bookings, loyalty, gift cards, locations, disputes, and payouts — all through plain English.

The entire setup takes about **1 minute** if you pick the real-account path, or about **3 minutes** if you pick the sandbox path. **You do almost nothing yourself** — Claude edits the one small configuration file on your computer for you, and then you just restart Claude Code once.

> **Two paths, one guide.** You can connect your **real Square account** (recommended — one click through Square's own sign-in page, no keys to copy) or a **practice sandbox** (for experimentation with fake data). Step 1 below helps you pick.

> **Beta notice.** Square's MCP connector is currently in **beta**. This means the tool list and behaviours may shift slightly over time. If something misbehaves during setup or normal use, a retry usually fixes it — and Claude will translate any errors into plain English for you.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../start/full-setup.md) if not done yet)
- A Square account (for the real-account path) **OR** a free Square developer account (for the sandbox path — takes 2 minutes to create)
- An internet connection

**You do NOT need Node.js installed separately.** The Square connector uses a helper called `npx`, which ships with Node, and Node is already on your computer as a dependency of Claude Code. There is nothing for you to install by hand.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |
| Linux (Ubuntu, Debian, Fedora, Arch) | Yes |

---

## What This Unlocks

| Tool | What Your Assistant Can Do |
|---|---|
| **Payments** | List recent payments, look up a specific payment, view status and amounts |
| **Refunds** | Issue refunds against payments (with confirmation before it happens) |
| **Customers** | List and search your customer directory, add new customers, update details |
| **Catalog** | Browse items, variations, categories, modifiers, taxes, and discounts |
| **Inventory** | Check stock levels per item variation at each location |
| **Orders** | Search orders by date range, location, status; view line items and totals |
| **Invoices** | List, view, and create invoices; check payment status |
| **Checkout** | Generate hosted checkout links for collecting payments |
| **Bookings** | List and manage Square Appointments |
| **Loyalty** | View loyalty accounts, points balances, and rewards |
| **Gift Cards** | Check balances, activate, redeem, link to customers |
| **Locations** | List your business locations and their details |
| **Merchant** | Check your Square business account name and status |
| **Labor** | View team member shifts and timecards |
| **Disputes** | List chargebacks and disputes |
| **Payouts** | See when Square last paid out to your bank account |

---

## Step 1 — Choose Your Path

Before you open Claude Code, decide which path you want:

### Path A — Real Square Account (Recommended)

Pick this if you want Claude to work with your **actual business data**. The connection uses Square's official sign-in page in your browser — you enter your Square credentials directly with Square, never with Claude, and Claude never sees your password or any long-lived token. This path is:

- **Fastest setup** — about 1 minute total
- **No developer account needed** — just your normal Square login
- **No keys to copy** — no Client ID, no Access Token, nothing for you to paste
- **Safest** — you can revoke access at any time from your Square account settings

Claude will default to **read-only** behaviour — it will always ask you before creating, updating, or deleting anything in your Square account.

### Path B — Sandbox (Practice Data)

Pick this if you want to **experiment with fake data** first before touching your real Square account. Square provides a free developer sandbox with fake customers, fake payments, and fake catalog items — the tools all behave identically to production, but nothing you do affects anything real.

This path requires you to:

1. Create a free Square developer account (if you don't already have one) at [developer.squareup.com](https://developer.squareup.com)
2. Create a "sandbox application" in the developer dashboard (2 minutes)
3. Copy a **Sandbox Access Token** out of the dashboard and paste it to Claude

The sandbox path defaults to **read-only** — Claude will only list and retrieve data, not create or modify it. You can ask Claude to flip this later if you want to practice creating invoices or customers in the sandbox.

### Not sure which one to pick?

Go with **Path A (Real Account)**. It is faster, requires no developer signup, and it is impossible for Claude to accidentally change anything in your account because every write is confirmed with you first. Path B is only useful if you specifically want to practice in a no-risk environment.

---

## Step 2 — Let Claude Do the Rest

Open Claude Code and say:

> **"Help me connect my Square account"**

Claude will ask you one question — real account or sandbox — and then handle every remaining technical step conversationally. You will not run any commands, edit any files, or copy any file paths. Claude does all of that for you.

### If you picked Path A (Real Account)

1. Claude writes a small Square entry into the configuration file on your computer
2. Claude asks you to **fully close and reopen Claude Code** once — this is the only thing you do
3. When Claude Code reopens, Claude makes its first call to Square — this automatically opens a Square sign-in page in your browser
4. You sign in to Square with your normal business login and click **Allow**
5. Claude verifies the connection by fetching your Square business name
6. Claude tells you it's done and suggests a few example questions

Total elapsed time: about **1 minute**, including the restart and sign-in.

### If you picked Path B (Sandbox)

1. Claude walks you through opening [developer.squareup.com](https://developer.squareup.com), signing in, creating a sandbox application, and copying your **Sandbox Access Token** — one step at a time, in plain English
2. You paste the Sandbox Access Token to Claude
3. Claude writes it into the configuration file on your computer (encrypted file permissions, only readable by you)
4. Claude asks you to **fully close and reopen Claude Code** once
5. When Claude Code reopens, Claude verifies the connection by fetching your practice merchant's name
6. Claude tells you it's done

Total elapsed time: about **3 minutes**, most of which is signing in to the Square developer site and creating the sandbox application.

### When Claude tells you it's finished, try asking:

- "Show me my recent Square payments"
- "What Square account am I connected to?"
- "List my Square customers"
- "Show me what's in my Square catalog"
- "What Square locations do I have?"
- "When did Square last pay me out?"

If Claude responds with your Square data (real or sandbox), you are all set.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Check payments** | "Show me my recent Square payments" / "Any failed payments this week?" |
| **Look up a payment** | "Show me Square payment abc123" |
| **Issue a refund** | "Refund Square payment abc123" (Claude will confirm before doing it) |
| **Find a customer** | "Find Jane Doe in my Square customers" |
| **Add a customer** | "Add a Square customer called ABC Ltd with email info@abc.com" |
| **Browse catalog** | "What's in my Square catalog?" / "List my catalog items" |
| **Check stock** | "How many [item] do I have in stock at my main location?" |
| **List invoices** | "Show me my Square invoices" / "Which Square invoices are unpaid?" |
| **Create an invoice** | "Create a Square invoice for Jane Doe for $500" (Claude confirms first) |
| **Recent orders** | "Show me my Square orders from this week" |
| **Locations** | "What Square locations do I have?" |
| **Payouts to my bank** | "When did Square last pay me out?" / "Show me my recent Square payouts" |
| **Disputes** | "Are there any Square disputes I need to look at?" |
| **Bookings** | "Show me my Square appointments for tomorrow" |
| **Loyalty points** | "What loyalty points does Jane Doe have?" |
| **Gift cards** | "Check the balance on gift card abc123" |
| **Switch paths** | "Switch my Square connector to sandbox" / "Switch my Square connector to the real account" |
| **Reconnect** | "My Square connection has stopped working" |

---

## Keeping Your Connection Active

**Real-account path:** Square's hosted sign-in session lasts for a long time (typically months), and refreshes automatically in the background. You should almost never need to sign in again. If you ever see an error like "Square connection expired", just say:

> **"My Square connection has stopped working"**

Claude will trigger a fresh browser sign-in and you click **Allow** once — back up in about 30 seconds.

**Sandbox path:** Your Sandbox Access Token does not expire (Square sandbox tokens are long-lived unless you regenerate them manually from the developer dashboard). You only need to update it if you explicitly regenerate it from [developer.squareup.com](https://developer.squareup.com).

---

## Troubleshooting

### Setup Problems

These are issues Claude may report back to you during Phase 1. In most cases Claude will translate the error into plain English and handle it automatically — this table exists so you can recognise what's happening if you're curious.

| Problem | Fix |
|---|---|
| **"Configuration file not found"** | This is normal on a brand-new Claude Code install — Claude will create it for you. No action needed. |
| **"npx: command not found"** | Extremely rare — means Node.js isn't on your computer, despite Claude Code usually installing it. Ask Claude "my Node.js isn't installed" and it will guide you through installing it, or fall back to the sandbox path which bundles its own helper. |
| **After restart, Claude says "Square connector not found"** | You may not have *fully* closed Claude Code. On Mac, this means quitting from the menu bar (not just closing the window). On Windows, right-click the tray icon and choose Quit. Then re-open and say "I'm back". |
| **Sandbox token looks too short** | You likely copied the Application ID by mistake instead of the Sandbox Access Token. Go back to the developer dashboard, click **Credentials** → **Sandbox** tab, and copy the value labelled **Sandbox Access Token** specifically. |
| **Sandbox token doesn't work after paste** | You may have copied from the **Production** tab instead of the **Sandbox** tab. Go back, switch to the Sandbox tab, copy that token, and tell Claude "I need to re-enter my Square sandbox token". |
| **"mcp-remote" is slow on first run** | First-time use downloads a small helper package. This takes 5–20 seconds on a good connection. Subsequent use is instant. |

### Sign-in & Authentication Problems

| Problem | Fix |
|---|---|
| **Browser doesn't open automatically (real account path)** | Claude will paste a sign-in URL into the chat. Click the link, sign in to Square, click **Allow**, then tell Claude "I'm back". |
| **"Square sign-in expired"** | Say to Claude: **"My Square connection has stopped working"** — Claude will re-trigger the sign-in. |
| **"Unauthorized" error mid-conversation** | Same as above — Claude will reconnect you. On the sandbox path, this may also mean your token was revoked; Claude will ask for a fresh one. |
| **"Forbidden" when Claude tries to do something** | Your Square sign-in didn't include the scope for that feature (e.g. Team/Labor, Bookings). Say **"I need to re-sign-in to Square with all permissions"** and Claude will trigger a fresh sign-in — this time click **Allow** for everything on the consent screen. |
| **Multiple Square accounts / businesses** | Claude will detect this and ask which account you want to use. On the sandbox path, each sandbox application belongs to one merchant. |

### After Setup

| Problem | Fix |
|---|---|
| **"Invalid request" on a specific command** | Usually a minor schema mismatch — Claude will inspect Square's type info and retry. If it keeps failing, the specific feature may not be in the Square MCP beta yet. |
| **"Rate limited" error** | Claude will wait 30 seconds and retry. If you hit this often, you may be asking for too much historical data at once — ask for shorter date ranges. |
| **"Internal server error" from Square** | Usually transient and Square's fault. Claude will retry once automatically. If it still fails, wait a few minutes and try again — this is more common on the beta MCP server. |
| **Sandbox is read-only but I want to test writes** | Say **"Allow writes in my Square sandbox"** — Claude will flip the read-only guard off after confirming with you. |
| **Want to switch from sandbox to real account (or vice versa)** | Say **"Switch my Square connector to the real account"** or **"Switch my Square connector to sandbox"** — Claude will update the configuration for you and walk you through the restart. |
| **Something else** | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Security Notes

- **Real-account path:** Your Square login is entered directly on Square's own sign-in page at [squareup.com](https://squareup.com). Claude, Anthropic, and Selr AI never see your Square email, password, or any long-lived secret. The browser session is stored by the `mcp-remote` helper in your user profile directory with restricted file permissions.
- **Sandbox path:** Your Sandbox Access Token is stored in `~/.claude.json` on your computer, which has file permissions that restrict it to your user account only. Neither the token nor any data it unlocks is sent to Anthropic, Selr AI, or any third party — the Square MCP server runs either remotely on Square's infrastructure (real-account path) or locally on your computer (sandbox path).
- **Confirmation-before-write** is the default for both paths. Claude will always summarise and confirm before creating, updating, deleting, or refunding anything — even in the sandbox.
- **Revoking access (real-account path):** Open your Square account, go to Account & Settings → Application Authorizations, find "Claude" (or the name shown during sign-in), and click Revoke. This invalidates the browser session immediately.
- **Revoking access (sandbox path):** Go to [developer.squareup.com](https://developer.squareup.com) → your application → Credentials → Sandbox, and click **Regenerate** on the Sandbox Access Token. The old token is invalidated immediately. Then tell Claude "I need to re-enter my Square sandbox token".
- The connector only requests the scopes granted during Square's consent screen (real-account path) or whatever the sandbox application is configured for (sandbox path). It does not access any Square product beyond what you see in the [What This Unlocks](#what-this-unlocks) table above.

---

## Note on the Beta

The Square MCP server is currently a **beta** product from Square. This means:

- The exact list of supported services and methods may change between Square releases
- Occasional transient errors ("internal server error") are more likely than on mature APIs
- New features may appear, and a small number of edge cases may not yet be covered
- You may see behaviour changes without notice as Square iterates

None of this affects the setup flow in this guide, and Claude translates all errors into plain English. If anything feels broken for more than a retry or two, it is almost always a Square-side hiccup and not something wrong with your setup. If you hit something persistent, email Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au).

---

## Still Having Trouble?

See [TROUBLESHOOTING.md](../troubleshoot.md) for more fixes, or ask your assistant:
> "Something went wrong with my Square connection. Help me fix it."

For beta-related issues (intermittent auth errors, tool name changes), see [known-issues/SQUARE-BETA-STATUS.md](../known-issues/SQUARE-BETA-STATUS.md).

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au) · Powered by the [official Square MCP server](https://developer.squareup.com/docs) (beta)*
