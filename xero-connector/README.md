# Xero Connector for Claude Code

**Built by Selr AI — selrai.com.au**

Connects your Xero accounting account to Claude Code. Once installed, Claude can read and create invoices, look up contacts, view your chart of accounts, check bank transactions, list payments, and pull financial reports — all through plain English.

---

## What You Need

- Claude Code installed and working
- Node.js version 20 or higher — Claude will check this for you during setup
- A Xero account (Starter, Standard, or Premium)
- A Xero developer app (free — see XERO-SETUP.md Step 1 for how to create one)

---

## Install

Claude Code will guide you through the setup conversationally. Open Claude Code and say:

> **"Help me connect my Xero account"**

Claude will walk you through each step one at a time, in plain English. You will not need to run any commands yourself — Claude handles all of that. You only need to:

1. Create a free Xero developer app when Claude tells you how (Claude will give you exact click-by-click instructions)
2. Paste your Client ID and Client Secret into the chat when Claude asks
3. Click **Allow access** in your browser when Xero opens for sign-in

That's it. Claude installs everything, saves your credentials, runs the sign-in flow, configures itself, and verifies the connection — all while talking you through it in normal language.

---

## What to Say to Claude

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

## Troubleshooting

| Problem | Fix |
|---|---|
| "Missing credentials" during install | Enter your real Client ID and Secret — get them from developer.xero.com (see XERO-SETUP.md Step 1) |
| Browser does not open during sign-in | The URL is printed in the terminal — paste it into any browser |
| "Token expired" when using Claude | Say to Claude: "my Xero connection has stopped working" and Claude will reconnect it for you |
| "Invalid scope for client" on auth | Your Xero app was created after 2 March 2026 and only supports granular scopes. The installer uses the correct scopes automatically — check that your Client ID in .env matches your app at developer.xero.com |
| Claude says tool not available | Restart Claude Code. If still broken, check that the path in `~/.claude.json` is correct and absolute |

---

*Built by Selr AI — selrai.com.au*
