# Connector Framework — Documentation

Built for the Claude Code Workshop by Selr AI — selrai.com.au

---

## What Is This?

The connector framework lets Claude automatically connect to the business tools your users already use. Instead of manually configuring each tool, Claude recommends the right connectors based on what the user says during onboarding, then installs everything itself.

The user only provides their login credentials. Everything else is automated.

---

## How It Works

### Step 1 — User Answers Onboarding Questions

During Phase 2 of the workshop setup, the user answers 7 questions. Two of them drive connector recommendations:

- **Question 2:** "What is your business called, and what do you do in one sentence?"
- **Question 5:** "What apps or tools do you use? For example: Gmail, Facebook, Xero, Instagram."

### Step 2 — Claude Reads CONNECTORS.md

Claude reads the master connector guide and matches the user's answers using two methods:

**Keyword Matching** — Direct mentions:

| User says... | Claude recommends... |
|---|---|
| "I use GoHighLevel" | GHL connector |
| "I use Shopify" | Shopify connector |
| "I use Xero" | Xero connector |
| "I use Stripe" | Stripe connector |
| "I use QuickBooks" | QuickBooks connector |
| "I use HubSpot" | HubSpot connector |
| "I use Square" | Square connector |

**Inference Rules** — When no tool is mentioned but the business type suggests one:

| Business situation | Claude infers... |
|---|---|
| Sells products online, no e-commerce tool mentioned | Shopify |
| No CRM mentioned at all | GHL |
| No accounting tool, business in AU/NZ/UK | Xero |
| No accounting tool, business in US/CA | QuickBooks |
| Takes payments, no payment processor mentioned | Stripe |
| Physical store or bookings, no POS mentioned | Square |

### Step 3 — Claude Recommends (Max 3)

Claude presents up to 3 recommendations, one at a time, in plain English:

```
Example conversation:

Claude: "Based on what you told me, I can connect to your Xero accounting.
        This means I can create invoices, check who owes you money, and pull
        financial reports — all just by asking me.
        Would you like me to connect Xero?"

User:   "Yes"

Claude: "Great. I am setting that up now..."
```

### Step 4 — Claude Installs the Connector

Claude runs the setup script:

```
bash ~/workshop-kit/connectors/install-connector.sh xero
```

This does three things automatically:
1. Copies the skill file to ~/.claude/skills/xero/
2. Creates a credentials file with a template
3. Registers the MCP server with Claude Code

### Step 5 — User Provides Credentials

Claude walks the user through getting their login credentials step by step. For example, for Xero:

```
Claude: "Now I need your Xero credentials. Here is how to get them:

        1. Open developer.xero.com in your browser
        2. Click 'My Apps' in the top menu
        3. Click 'New App'
        4. Choose 'Custom Connection'
        5. Name it 'AI Assistant' and click Create
        6. Copy the Client ID and paste it here"

User:   "abc123def456"

Claude: "Got it. Now click 'Generate a secret' and paste the Client Secret"
```

### Step 6 — Claude Verifies

Claude runs the test script to confirm everything works:

```
bash ~/workshop-kit/connectors/xero/test.sh

=== Testing Xero connector ===

[pass] Skill file installed
[pass] Credentials file exists
[pass] Xero Client ID is set
[pass] Xero Client Secret is set
[pass] MCP server registered

=== Results: 5 passed, 0 failed ===
```

### Step 7 — User Talks Naturally

The connector is live. The user just asks questions in plain English:

```
User:   "Show me all unpaid invoices"
Claude: [uses Xero MCP to fetch invoices and displays them]

User:   "Create an invoice for $500 for John Smith"
Claude: [uses Xero MCP to create the invoice]
```

---

## Available Connectors

| Connector | What It Does | Tools | Setup Time |
|---|---|---|---|
| **GHL** | CRM — contacts, pipelines, messaging, calendars, social media | 269+ | 5 min |
| **Shopify** | E-commerce — products, orders, customers, inventory | 31 | 5 min |
| **Xero** | Accounting — invoices, contacts, bank, payroll, reporting | 50+ | 10 min |
| **Stripe** | Payments — customers, subscriptions, invoices, refunds | Full API | 5 min |
| **QuickBooks** | Accounting — invoices, customers, vendors, estimates | 11 entities | 10 min |
| **HubSpot** | CRM — contacts, companies, deals, tickets | 13 objects | 5 min |
| **Square** | POS — orders, customers, catalog, bookings, inventory | 40+ | 5 min |
| **Google Chat** | Team messaging — spaces, DMs, group chats | Spaces | 10 min |

---

## File Structure

Every connector follows the same pattern:

```
connectors/
  CONNECTORS.md              ← Master guide + recommendation engine
  install-connector.sh       ← Universal installer
  
  shopify/                   ← One folder per connector
    skills/
      shopify/
        SKILL.md             ← Teaches Claude the Shopify API
    setup.sh                 ← Automated installer
    test.sh                  ← Health check (pass/fail)
    secrets/
      shopify.env.template   ← Credentials template
    README.md                ← User guide
```

### What Each File Does

| File | Purpose |
|---|---|
| `SKILL.md` | Teaches Claude how to use the tool — available operations, API quirks, safety rules |
| `setup.sh` | Copies skill to ~/.claude/skills/, creates credentials file, registers MCP server |
| `test.sh` | Checks skill is installed, credentials are filled, MCP server is registered |
| `secrets/*.env.template` | Template with placeholder values and instructions for getting real credentials |
| `README.md` | Setup guide, usage examples, troubleshooting for that specific connector |

---

## Example: Full GHL Flow

Here is a complete example of what happens when a user mentions GoHighLevel:

**1. During onboarding:**
```
Claude: "What apps or tools do you use?"
User:   "I use GoHighLevel and Gmail"
```

**2. Claude recommends:**
```
Claude: "I can manage your contacts, send messages, book appointments,
        and post to social media — all through GoHighLevel.
        Would you like me to connect it?"
User:   "Yes"
```

**3. Claude installs:**
```
Claude runs: bash ~/workshop-kit/connectors/install-connector.sh ghl

Output:
  [done] Skill file installed
  [done] Credentials file created
  [info] MCP server will be added after you fill in your credentials.
```

**4. Claude gets credentials:**
```
Claude: "I need your GoHighLevel login details.

        1. Open GoHighLevel at app.gohighlevel.com
        2. Click the gear icon in the bottom left (Settings)
        3. Click 'Business Profile'
        4. Scroll down to 'API Key'
        5. Copy it and paste it here"

User:   "eyJhbGciOi..."

Claude: "Got it. Now I need your Location ID.
        Look at your browser URL bar — it shows:
        app.gohighlevel.com/v2/location/THIS_PART/...
        Copy that part and paste it here"
```

**5. Claude verifies:**
```
Claude runs: bash ~/workshop-kit/connectors/ghl/test.sh

Output:
  [pass] Skill file installed
  [pass] Credentials file exists
  [pass] GHL API Key is set
  [pass] GHL Location ID is set
  [pass] API connection works

Claude: "GoHighLevel is connected! Try asking me something like
        'search my contacts for Sarah' or 'show me my pipeline'"
```

**6. User starts working:**
```
User:   "Search my contacts for Sarah"
Claude: "Found 3 contacts matching 'Sarah':
         1. Sarah Johnson — sarah@email.com — Last contacted 2 days ago
         2. Sarah Williams — sarah.w@company.com — New lead
         3. Sarah Chen — schen@business.com — Won deal"
```

---

## Example: Inference (No Tool Mentioned)

When the user does not mention a specific tool but their business suggests one:

**1. During onboarding:**
```
Claude: "What is your business called, and what do you do?"
User:   "I run a plumbing company in Melbourne"

Claude: "What apps or tools do you use?"
User:   "Just Gmail and my phone"
```

**2. Claude infers:**
```
Claude: "Since you are running a service business, I would recommend
        connecting a client management tool. GoHighLevel is popular
        with small businesses and is included in the workshop —
        it lets me manage your contacts, send messages, and book
        appointments for you. Would you like to try it?"

Claude: "I also noticed you do not have accounting software connected.
        Since you are in Australia, Xero is the most popular option —
        I can create invoices, track who owes you money, and pull
        financial reports. Want me to set that up too?"
```

---

## Adding a New Connector

To add a new connector (for example, Mailchimp):

1. Create the folder: `connectors/mailchimp/`
2. Create these 5 files following the same pattern:
   - `skills/mailchimp/SKILL.md` — Teach Claude the Mailchimp API
   - `setup.sh` — Install script
   - `test.sh` — Health check
   - `secrets/mailchimp.env.template` — Credentials template
   - `README.md` — User guide
3. Add the connector to the keyword matching table in `CONNECTORS.md`
4. Add the connector to the recommendation table in `my-assistant/CLAUDE.md` (Tool Step 5)

The install-connector.sh universal installer will automatically pick up the new connector.

---

## Safety Rules

Every connector skill includes safety rules to prevent accidental damage:

- Never delete records without explicit user approval
- Never send bulk messages without approval
- Never issue refunds or void invoices without approval
- Never modify financial records in closed periods
- Always confirm amounts before creating invoices or payments
- Always use draft status for new documents unless told otherwise

---

## Troubleshooting

**Connector not recommended during onboarding:**
- Check the keyword matching table in CONNECTORS.md
- The user's answer to Question 5 must contain a matching keyword

**Setup script fails:**
- Check Node.js is installed: `node --version`
- Check Claude Code is installed: `claude --version`

**Test shows FAIL for credentials:**
- The user has not entered their real credentials yet
- Edit the .env file in ~/.claude/projects/-Users-{username}/secrets/

**MCP server not registered:**
- Re-run setup.sh after entering credentials
- Or manually add: `claude mcp add [name] -- [mcp command]`

**API returns 401 or 403:**
- Credentials are wrong or expired
- Follow the credential guide in CONNECTORS.md to get fresh ones

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
