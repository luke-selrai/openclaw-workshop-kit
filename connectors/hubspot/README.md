# HubSpot Connector for Claude Code

Search your HubSpot CRM with natural language. Contacts, companies, deals, tickets, and more.

---

## Setup (5 minutes)

### Step 1: Create a HubSpot private app
1. HubSpot Settings > Integrations > Private Apps > Create
2. Name it "AI Assistant", select CRM read scopes
3. Copy the access token

### Step 2: Run the installer
```bash
cd hubspot
bash setup.sh
```

### Step 3: Enter credentials and test
```bash
open ~/.claude/projects/-Users-$(whoami)/secrets/hubspot.env
bash test.sh
```

---

## What you can do

- "Show me all open deals"
- "Look up contact john@example.com"
- "What tickets are open right now?"
- "List companies added this month"
- "Find all deals for ABC Company"

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/hubspot/SKILL.md` | Teaches Claude HubSpot CRM objects and queries |
| `secrets/hubspot.env.template` | Your credentials template |
| `setup.sh` / `test.sh` | Installer and health check |

## Note

The official HubSpot MCP server is currently **read-only** (public beta). You can search and view records but not create or update them.
