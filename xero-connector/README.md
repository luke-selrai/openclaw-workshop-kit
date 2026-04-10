# Xero Connector for Claude Code

**Built by Selr AI â€” selrai.com.au**

Connects your Xero accounting account to Claude Code. Once installed, Claude can read invoices, create invoices, look up contacts, view your chart of accounts, and pull financial reports â€” all through plain English.

---

## What You Need

- Claude Code installed and working
- Node.js version 20 or higher â€” check by typing `node --version`
- A Xero account (Starter, Standard, or Premium)
- A Xero developer app (free â€” see XERO-SETUP.md for how to create one)

---

## Install â€” Pick Your Computer Type

**Windows:** Double-click `setup.bat` and follow the prompts.

**Mac:** Open Terminal, drag the `setup.sh` file into the window, press Enter.

---

## Manual Install (if scripts don't work)

Open your terminal or command window and run these commands one at a time:

**Step 1 â€” Install dependencies:**
```
npm install
```

**Step 2 â€” Copy and fill in your credentials:**
```
cp .env.example .env
```
Open `.env` and add your Xero `XERO_CLIENT_ID` and `XERO_CLIENT_SECRET`.  
(See XERO-SETUP.md Step 2 for how to get these.)

**Step 3 â€” Sign in to Xero:**
```
npm run auth
```
A browser window will open â€” sign in with your Xero account and click Allow.

**Step 4 â€” Add to Claude Code:**

Add this to your Claude Code MCP settings (`~/.claude.json`):
```json
{
  "mcpServers": {
    "xero": {
      "command": "node",
      "args": ["/FULL/PATH/TO/xero-connector/src/index.js"]
    }
  }
}
```
Replace `/FULL/PATH/TO/xero-connector` with the actual path to this folder.  
See XERO-SETUP.md Step 4 for exact instructions by operating system.

---

## What to Say to Claude

- "Show me my recent Xero invoices"
- "List all unpaid invoices in Xero"
- "Create a Xero invoice for [client] for [amount]"
- "Find [client name] in my Xero contacts"
- "Show me the Xero profit and loss for this year"
- "Get the Xero balance sheet"
- "List my Xero accounts"

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
| `xero_get_profit_loss` | Profit & Loss report |
| `xero_get_balance_sheet` | Balance Sheet report |
| `xero_list_payments` | List recorded payments |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `npm run auth` â€” "Missing credentials" | Open `.env` and replace the placeholder values with your real Client ID and Secret |
| Browser does not open during sign-in | The URL is printed in the terminal â€” paste it into any browser |
| "Token expired" when using Claude | Run `npm run auth` again to get a fresh token |
| "No Xero organisations found" | Run `npm run auth` again â€” the token may be for the wrong account |
| Claude says tool not available | Check that the path in `~/.claude.json` is correct and absolute |

---

*Built by Selr AI â€” selrai.com.au*

