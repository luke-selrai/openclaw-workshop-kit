# Xero Connector for Claude Code

Manage your Xero accounting with natural language. Invoices, contacts, bank transactions, payroll, and financial reports — just ask Claude.

"Show me all unpaid invoices" — and Claude does it.

---

## Setup (10 minutes)

### Step 1: Create a Xero developer app

1. Go to developer.xero.com and sign in
2. Click "My Apps" then "New App"
3. Choose "Custom Connection"
4. Name it "AI Assistant" and create it
5. Copy the Client ID
6. Click "Generate a secret" and copy the Client Secret

### Step 2: Run the installer

```bash
cd xero
bash setup.sh
```

### Step 3: Enter your credentials

Edit the credentials file:

```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/xero.env
```

Paste your Client ID and Client Secret.

### Step 4: Test it

```bash
bash test.sh
```

---

## What you can do

- "Show me all unpaid invoices"
- "Create an invoice for $500 for John Smith"
- "Who owes me money right now?"
- "What is my profit and loss this month?"
- "Record a payment of $200 against invoice #1234"
- "List all my bank transactions this week"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/xero/SKILL.md` | Teaches Claude the Xero MCP tools and accounting safety rules |
| `secrets/xero.env.template` | Your credentials template |
| `setup.sh` | One-command installer |
| `test.sh` | Verifies everything works |

---

## Troubleshooting

**"Token expired" or 401 errors**
Re-authenticate: the MCP server handles token refresh, but if the connection is broken, re-run setup.sh with fresh credentials.

**"Insufficient scope"**
Your Xero app needs more scopes. Go to developer.xero.com > My Apps > your app > Configuration > Scopes.

**MCP not showing up**
Run: `claude mcp add xero -e XERO_CLIENT_ID=xxx -e XERO_CLIENT_SECRET=xxx -- npx -y @xeroapi/xero-mcp-server@latest`
