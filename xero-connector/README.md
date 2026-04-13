# Xero Connector for Claude Code

**Built by Selr AI — selrai.com.au**

Connects your Xero accounting account to Claude Code. Once installed, Claude can read and create invoices, look up contacts, view your chart of accounts, check bank transactions, list payments, and pull financial reports — all through plain English.

---

## How to Install

Open Claude Code and say:

> *"Connect my Xero account"*

Claude will walk you through the whole setup conversationally — checking Node.js, installing dependencies, asking for your Xero credentials, running the OAuth sign-in, and wiring everything into Claude Code. You don't need to run any commands yourself.

The only things you'll need to hand over during the conversation:

1. A Xero **Client ID** and **Client Secret** (free, from your Xero developer app — Claude tells you how to create one)
2. A click on **Allow** when Xero opens in your browser

See the `skills/xero-connector/SKILL.md` skill for the full conversational flow Claude follows.

---

## What You Need

- Claude Code installed and working
- Node.js version 20 or higher (Claude will check this and help you install it if needed)
- A Xero account (Starter, Standard, or Premium)

---

## What to Say to Claude (after setup)

- "Show me my recent Xero invoices"
- "List all unpaid invoices in Xero"
- "Create a Xero invoice for [client] for [amount]"
- "Find [client name] in my Xero contacts"
- "Show me the Xero profit and loss for this year"
- "Get the Xero balance sheet"
- "List my Xero bank transactions"
- "Show me recent payments in Xero"

---

## Available Tools

| Tool | What it does |
|---|---|
| `xero_get_organisation` | Show the connected Xero organisation name |
| `xero_list_invoices` | List invoices (filter by status, search by contact) |
| `xero_get_invoice` | Get a specific invoice by ID or number |
| `xero_create_invoice` | Create a new draft invoice |
| `xero_list_contacts` | List customers and suppliers |
| `xero_create_contact` | Add a new contact |
| `xero_list_accounts` | Show the chart of accounts |
| `xero_list_banktx` | List bank transactions |
| `xero_list_payments` | List recorded payments |
| `xero_get_profit_loss` | Profit & Loss report |
| `xero_get_balance_sheet` | Balance Sheet report |

---

## If Something Breaks

Just tell Claude what's wrong — it knows how to recover. Common recoveries:

| Problem | What to say |
|---|---|
| Token expired | *"My Xero connection expired — reconnect it"* |
| Wrong credentials | *"Re-do my Xero credentials"* |
| Claude says "Xero tool not available" | Restart Claude Code, then try again |
| Not sure what went wrong | *"My Xero connection isn't working — can you check it?"* |

Claude will jump to the specific step in the install flow that needs rerunning, without making you start over.

---

## Internal Files

If you're contributing to this connector:

- `src/index.js` — the MCP server that Claude Code connects to
- `src/auth.js` — standalone OAuth flow (`npm run auth`) used by the skill during install
- `src/install.js` — **legacy one-shot installer.** Retained for backwards compatibility but not part of the canonical install path. The conversational skill in `skills/xero-connector/SKILL.md` is the primary install experience.
- `.env` — your credentials (gitignored)
- `.xero-token.json` — your auth tokens (gitignored)

---

*Built by Selr AI — selrai.com.au*
