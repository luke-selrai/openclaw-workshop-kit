# Square Connector for Claude Code

Manage your Square POS and payments with natural language. Orders, customers, catalog, bookings, inventory, and more.

---

## Setup (5 minutes)

### Step 1: Get your Square access token
1. Go to developer.squareup.com > Applications > Credentials
2. Copy the Production Access Token

### Step 2: Run the installer
```bash
cd square
bash setup.sh
```

### Step 3: Enter credentials and test
```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/square.env
bash test.sh
```

---

## What you can do

- "Show me today's orders"
- "Look up customer Jane Smith"
- "What items are in my catalog?"
- "Show me this week's payouts"
- "Check inventory for [product]"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/square/SKILL.md` | Teaches Claude Square POS operations and safety rules |
| `secrets/square.env.template` | Your credentials template |
| `setup.sh` / `test.sh` | Installer and health check |
