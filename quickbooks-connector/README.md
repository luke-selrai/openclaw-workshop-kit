# QuickBooks Connector for Claude Code

**Built by Selr AI — selrai.com.au**

Connects your QuickBooks Online account to Claude Code. Once installed, Claude can read and create invoices, look up customers, view your chart of accounts, check bank transactions, and pull financial reports — all through plain English.

---

## What You Need

- Claude Code installed and working
- Node.js version 20 or higher — check by typing `node --version`
- A QuickBooks Online account (sandbox for testing, live for real data)
- A QuickBooks OAuth app at developer.intuit.com (free — see QUICKBOOKS-SETUP.md Step 1 for how to create one)
- **If using sandbox:** a sandbox company created at developer.intuit.com → My Hub → Sandbox → Add sandbox (Intuit does not create one automatically — see QUICKBOOKS-SETUP.md)
- An internet connection

---

## Install — One Prompt

Open Claude Code, paste this prompt, and press Enter:

```
Run the QuickBooks connector installer:
node /full/path/to/quickbooks-connector/src/install.js
```

Replace `/full/path/to/quickbooks-connector` with the actual path to this folder.

Claude Code will handle everything from there. The only things you need to do:

1. Enter your Client ID and Secret when prompted (from QUICKBOOKS-SETUP.md Step 1)
2. Choose sandbox or production when asked
3. Click Connect when QuickBooks opens in your browser

That's it — Claude Code installs dependencies, saves your credentials, runs the OAuth flow, configures itself, and verifies the connection automatically.

---

## What to Say to Claude

- "Show me my recent QuickBooks invoices"
- "Create an invoice for [client name]"
- "What's my profit and loss this month?"
- "List my QuickBooks customers"
- "Show me my bank transactions"
- "Get the QuickBooks balance sheet"

---

## Available Tools

| Tool | What it does |
|---|---|
| `quickbooks_get_company` | Show the connected QuickBooks company name and details |
| `quickbooks_list_invoices` | List invoices (filter by status, limit results) |
| `quickbooks_get_invoice` | Get a specific invoice by ID |
| `quickbooks_create_invoice` | Create a new invoice for a customer |
| `quickbooks_list_customers` | List customers (search by name) |
| `quickbooks_create_customer` | Add a new customer |
| `quickbooks_list_accounts` | Show the chart of accounts |
| `quickbooks_list_bank_transactions` | List bank transactions (purchases and deposits) |
| `quickbooks_get_profit_loss` | Profit & Loss report |
| `quickbooks_get_balance_sheet` | Balance Sheet report |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Missing credentials" during install | Enter your real Client ID and Secret — get them from developer.intuit.com (see QUICKBOOKS-SETUP.md Step 1) |
| Browser does not open during sign-in | The URL is printed in the terminal — paste it into any browser |
| "Token expired" when using Claude | Run `npm run auth` in the quickbooks-connector folder to get a fresh token |
| "invalid_client" or "redirect_uri_mismatch" on auth | Your redirect URI at developer.intuit.com must be exactly `http://localhost:3000/callback` on the **Development** tab (or Production tab if you picked production). See QUICKBOOKS-SETUP.md Step 1 |
| Claude says tool not available | Restart Claude Code. If still broken, check that the path in `~/.claude.json` is correct and absolute |

---

*Built by Selr AI — selrai.com.au*
