# QuickBooks Connector for Claude Code

Manage your QuickBooks Online accounting with natural language. Invoices, customers, vendors, expenses, and estimates.

---

## Setup (10 minutes)

### Step 1: Create an Intuit developer app
1. Go to developer.intuit.com and sign in
2. Click "My Apps" > "Create an app" > "QuickBooks Online and Payments"
3. Copy the Client ID and Client Secret

### Step 2: Run the installer
```bash
cd quickbooks
bash setup.sh
```

### Step 3: Enter credentials and test
```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/quickbooks.env
bash test.sh
```

---

## What you can do

- "Show me all unpaid invoices"
- "Create an invoice for ABC Company"
- "What are my expenses this month?"
- "List all customers"
- "Record this expense"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/quickbooks/SKILL.md` | Teaches Claude QuickBooks operations and safety rules |
| `secrets/quickbooks.env.template` | Your credentials template |
| `setup.sh` / `test.sh` | Installer and health check |
