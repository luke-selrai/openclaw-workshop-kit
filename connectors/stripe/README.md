# Stripe Connector for Claude Code

Manage your Stripe payments with natural language. Customers, payments, subscriptions, invoices, and refunds — just ask Claude.

---

## Setup (5 minutes)

### Step 1: Run the installer
```bash
cd stripe
bash setup.sh
```

### Step 2: Get your Stripe restricted key
1. Go to dashboard.stripe.com > Developers > API Keys
2. Click "Create restricted key"
3. Name it "AI Assistant", set permissions, create it
4. Copy the key (starts with `rk_`)

### Step 3: Enter credentials and test
```bash
# Edit credentials
open ~/.claude/projects/-Users-$(whoami)/secrets/stripe.env

# Test
bash test.sh
```

---

## What you can do

- "Show me today's payments"
- "Create a payment link for $100"
- "List all active subscriptions"
- "Look up customer john@example.com"
- "Create an invoice for $500 for John Smith"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/stripe/SKILL.md` | Teaches Claude the Stripe MCP tools and safety rules |
| `secrets/stripe.env.template` | Your credentials template |
| `setup.sh` | One-command installer |
| `test.sh` | Verifies everything works |
