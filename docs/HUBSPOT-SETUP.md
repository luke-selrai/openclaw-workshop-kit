---
title: HubSpot — Setup Guide
version: 2.0
date: 2026-04-14
---

# HubSpot — Setup Guide

This guide connects your HubSpot CRM account to your AI assistant using the official HubSpot MCP server. Once set up, your assistant can look up contacts, manage companies, track deals, create tickets, add notes, and more — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A HubSpot account (free CRM available at hubspot.com)
- Node.js 18 or newer installed (check with `node --version`)
- An internet connection

> **No coding experience required.** Your connection key stays on your machine and is never sent to third parties.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Contacts** | Look up, search, create, and update contact records |
| **Companies** | Browse companies, view details, create new records |
| **Deals** | View deal pipelines, create deals, move deals through stages |
| **Tickets** | Create support tickets, update status, track pipelines |
| **Notes & Tasks** | Add notes to records, create follow-up tasks |
| **Associations** | See how contacts, companies, and deals are linked |
| **Properties** | View and create custom fields on any object type |
| **Workflows** | View your automated workflows |

---

## Step 1 — Create a Private App in HubSpot (you do this)

This step creates a secure connection key that lets your assistant talk to HubSpot on your behalf.

1. Open **https://app.hubspot.com/private-apps/** in your browser and sign in
2. Click the orange **Create a private app** button
3. Fill in the form:
   - **Name:** Claude Assistant
   - **Description:** AI assistant connection (optional)
4. Click the **Scopes** tab at the top of the form
5. Under **CRM**, tick these boxes:
   - `crm.objects.contacts.read`
   - `crm.objects.companies.read`
   - `crm.objects.deals.read`
   - `crm.objects.quotes.read`
   - `crm.schemas.contacts.read`
   - If you also want your assistant to create or update records, tick the `.write` versions too
6. Click the orange **Create app** button (top right), then click **Continue creating** if asked
7. You will see your **access token** — it starts with `pat-`
8. **Copy this token** — you will give it to your assistant in the next step

> **Important:** Treat this token like a password. Do not share it or post it online.

> **You can always add more permissions later** by editing the Private App and ticking more scope boxes — no need to start over.

---

## Step 2 — Tell Your Assistant to Connect (your assistant does the rest)

Open Claude Code and say:

> "Help me connect my HubSpot account"

Your assistant will:
1. Ask you to paste the access token you copied in Step 1
2. Save the connection details securely on your computer
3. Verify the connection is working
4. Tell you when it is ready

> **After setup, restart Claude Code once** so the connection becomes active.

---

## Common Things to Ask Your Assistant

Once set up, you can ask your assistant things like:

- *"Show me my recent contacts"*
- *"Find the contact with email jane@example.com"*
- *"Create a new contact for Jane Doe at Acme Corp"*
- *"List my open deals"*
- *"Create a deal called 'Acme Enterprise' for $50,000"*
- *"What deals are linked to Acme Corp?"*
- *"Show me all open tickets"*
- *"Add a note to the Acme deal saying we had a great call"*
- *"What properties are available on contacts?"*
- *"Show me my workflows"*
- *"What HubSpot account am I connected to?"*

---

## Adding More Permissions Later

If your assistant says it needs extra permissions for something:

1. Go to **https://app.hubspot.com/private-apps/** and click on **Claude Assistant**
2. Click the **Scopes** tab
3. Tick the additional boxes your assistant mentioned
4. Click **Save** (top right) and confirm
5. Go back to Claude Code and try your request again — no restart needed

---

## Troubleshooting

### "Your HubSpot connection has expired"
Your Private App token may have been revoked. Go to HubSpot → Private Apps → Claude Assistant and check it is still active. If needed, create a new token and tell your assistant: *"I have a new HubSpot connection key."*

### "I need an extra permission"
See **Adding More Permissions Later** above. Your assistant will tell you which scope to add.

### "HubSpot is asking me to slow down" (rate limit)
HubSpot limits requests to 200 per 10 seconds. Wait a moment and try again. This is rare in normal use.

### Connection not working after setup
Make sure you restarted Claude Code after the initial setup. The connection only activates after a restart.

### "I can't find the Private Apps page"
In HubSpot, click the **Settings gear icon** (top right) → **Integrations** → **Private Apps**. Or go directly to: https://app.hubspot.com/private-apps/

### Need to switch HubSpot accounts
Create a new Private App in the other HubSpot account and tell your assistant: *"I want to switch to a different HubSpot account."* They will walk you through updating the connection.

---

## Security Notes

- Your access token is stored locally on your computer in a settings file — it is never sent to third parties
- The token can be revoked at any time from HubSpot → Private Apps
- Your assistant will always confirm with you before creating, updating, or deleting records
- No OAuth, no browser redirects, no client secrets — just a single private token
- The connection uses the official HubSpot MCP server maintained by HubSpot

---

## What Is NOT Included (Yet)

This connector focuses on **CRM data** — contacts, companies, deals, tickets, notes, tasks, associations, properties, and workflows.

The following are **not included** in this version and will be added in a future update if needed:

- Marketing Hub (email campaigns, forms, landing pages)
- Service Hub (knowledge base, feedback surveys)
- Commerce (quotes, payments, subscriptions)
- File uploads or attachments
- Bulk import/export

If you need any of these, let your assistant know and they can check if support has been added.

---

Built by Selr AI
