---
name: hubspot-connector
description: Connects Claude Code to HubSpot CRM using the 
  official HubSpot CLI. Enables access to contacts, deals, 
  pipelines, marketing emails, forms, and landing pages 
  directly from Claude Code. Use when user mentions HubSpot, 
  CRM, contacts, deals, pipelines, marketing emails, or asks 
  to connect to HubSpot. Do NOT use for Salesforce, GHL, 
  or other CRM platforms.
metadata:
  author: Khushi Bhanderi (Selr AI)
  version: 1.0.0
  category: connectors
---

# HubSpot Connector

Connects Claude Code to HubSpot CRM using the official 
HubSpot CLI so participants can manage contacts, deals, 
pipelines, and marketing assets directly from their 
Claude Code session.

---

## Prerequisites

- Node.js v18 or above installed
- HubSpot account (Free, Starter, Pro, or Enterprise)
- HubSpot Personal Access Key
  (Get it from: HubSpot Settings → Integrations → 
  Private Apps → Create private app)

---

## Instructions

### Step 1: Check Node.js Version

Run this inside Claude Code:
```bash
node --version
```

Expected output: v18.0.0 or higher

If Node.js is not installed or below v18:
```bash
# macOS
brew install node

# Windows
winget install OpenJS.NodeJS

# Linux
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

---

### Step 2: Install HubSpot CLI
```bash
npm install -g @hubspot/cli
```

Verify installation:
```bash
hs --version
```

Expected output: version number e.g. `6.x.x`

---

### Step 3: Authenticate with HubSpot

Run the authentication command:
```bash
hs auth
```

This will:
1. Open your browser to HubSpot login
2. Ask you to select your portal
3. Ask for your Personal Access Key
4. Store credentials locally for future use

To get your Personal Access Key:
1. Log into HubSpot
2. Go to Settings → Integrations → Private Apps
3. Click Create a private app
4. Name it (e.g. Claude Code Integration)
5. Set required scopes:
   - crm.objects.contacts.read
   - crm.objects.contacts.write
   - crm.objects.deals.read
   - crm.objects.deals.write
6. Click Create app
7. Copy the access token

---

### Step 4: Verify Connection

Run the verification script:
```bash
bash scripts/verify-hubspot.sh
```

Or manually verify:
```bash
hs accounts list
```

Expected output: your HubSpot portal name and ID

---

### Step 5: Run Install Script

Run the full install script to configure everything:
```bash
bash scripts/install-hubspot.sh
```

The script will:
1. Check Node.js version
2. Install HubSpot CLI if not present
3. Run authentication flow
4. Verify connection to HubSpot portal
5. Confirm scopes are correctly set

---

## What You Can Do After Connection

Once connected, ask Claude Code to:

**Contacts:**
- "Get all contacts from HubSpot"
- "Find contact by email john@example.com"
- "Create a new contact in HubSpot"
- "Update contact phone number"

**Deals:**
- "Show all open deals in HubSpot"
- "Create a new deal for this contact"
- "Move deal to closed won stage"
- "Get deals closing this month"

**Pipelines:**
- "Show me all pipeline stages"
- "How many deals are in each stage"
- "Move deal to next stage"

**Marketing:**
- "List all marketing emails"
- "Show recent form submissions"
- "Get landing page performance"

---

## Examples

### Example 1: Basic Connection

User says: "Connect my HubSpot to Claude"

Actions:
1. Check Node.js version
2. Install HubSpot CLI
3. Run hs auth to authenticate
4. Verify with hs accounts list
5. Confirm connection successful

Result: Claude Code connected to HubSpot portal

---

### Example 2: Contact Management

User says: "Get all my HubSpot contacts"

Actions:
1. Verify HubSpot CLI is authenticated
2. Run hs crm list contacts
3. Return contact list to user

Result: Full contact list returned inside Claude Code

---

### Example 3: Deal Tracking

User says: "Show me all open deals"

Actions:
1. Verify authentication
2. Run hs crm list deals --filter stage=open
3. Return deal list with stages and values

Result: Full deal pipeline visible inside Claude Code

---

## Troubleshooting

### Error: `hs: command not found`

Cause: HubSpot CLI not installed or npm path issue
Solution:
```bash
npm install -g @hubspot/cli
# If still not found on macOS/Linux:
export PATH="$PATH:$(npm bin -g)"
```

### Error: `Invalid access token`

Cause: Personal Access Key expired or incorrect scopes
Solution:
1. Go to HubSpot → Settings → Private Apps
2. Delete existing app
3. Create new private app with correct scopes
4. Re-run hs auth with new token

### Error: `Portal not found`

Cause: Wrong HubSpot account authenticated
Solution:
```bash
hs accounts list
hs accounts use YOUR_PORTAL_ID
```

### Error: `Insufficient permissions`

Cause: Private app missing required scopes
Solution:
1. Go to HubSpot → Settings → Private Apps
2. Edit your private app
3. Add missing scopes:
   - crm.objects.contacts.read
   - crm.objects.contacts.write
   - crm.objects.deals.read
   - crm.objects.deals.write
4. Save and copy new access token
5. Re-run hs auth

### Error: `npm ERR! EACCES permission denied`

Cause: npm global install permission issue on Linux/macOS
Solution:
```bash
sudo npm install -g @hubspot/cli
# Or fix npm permissions:
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
export PATH=~/.npm-global/bin:$PATH
```

---

## Known Limitations

- HubSpot CLI primarily designed for CMS/developer tasks — 
  some CRM operations require direct API calls
- Personal Access Key expires if private app is deleted
- Free HubSpot accounts have API rate limits 
  (100 requests per 10 seconds)
- Bulk operations may hit rate limits — add delays 
  between large requests
- HubSpot CLI does not support all CRM objects — 
  custom objects may require API MCP instead

---

## Workshop Placement

Introduced at the connectors step of the standard workshop 
when participant mentions HubSpot or CRM during the 
onboarding questions.

Recommended flow:
1. Participant mentions HubSpot in tech stack
2. Assistant recommends hubspot-connector skill
3. Run install-hubspot.sh
4. Authenticate with Personal Access Key
5. Verify connection
6. Demo contact or deal retrieval
