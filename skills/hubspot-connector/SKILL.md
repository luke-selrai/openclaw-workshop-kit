---
name: hubspot-connector
description: "Connect and operate HubSpot CRM via the official @hubspot/mcp-server. Use this skill when the user asks to set up HubSpot, connect their CRM, or interact with contacts, companies, deals, tickets, notes, tasks, associations, properties, custom objects, or workflows. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__hubspot__*, Bash, Read, Write, Edit
metadata:
  category: CRM & Marketing
  tags:
    - hubspot
    - crm
    - contacts
    - companies
    - deals
    - tickets
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Compose follow-up emails for deals or contacts
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by HubSpot events (deal stage change, new contact, etc.)
    - skill: systematic-debugging
      reason: Use for troubleshooting HubSpot auth or API errors
---

# HubSpot Connector

## Overview

This skill lets you read and update a user's HubSpot CRM data on their behalf using the **official first-party `@hubspot/mcp-server`** (npm, beta). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤5 steps). The user has never used this before. You walk them through creating a Private App in HubSpot, collecting the access token, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", or any file paths. They should feel like they are having a conversation, and at the end their HubSpot is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__hubspot__*` native tools to read and update CRM data.

**Which phase to run** — Before any tool call, check whether the HubSpot MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.hubspot` entry. If it exists and has a `PRIVATE_APP_ACCESS_TOKEN` in its `env` block, treat the connector as authenticated and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **`@hubspot/cli` (`hs` command)** — that is a CMS development tool for themes, HubL, and serverless functions. Wrong audience for a CRM connector. Do not install it.
- **OAuth / Client ID / Client Secret / Redirect URI** — HubSpot Private Apps use a simple access token. No OAuth flow needed.
- **Marketing Hub / Service Hub / Commerce APIs** — deferred to a future version. Do not build curl-based API wrappers.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, or environment variable. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your HubSpot is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤5 steps)

This phase gets the Private App created, the access token collected, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only provides information and clicks things in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your HubSpot, I need you to create a free connection key inside your HubSpot account. This takes about three minutes. I will tell you exactly what to click, one step at a time."

### Step 2 — Walk the user through creating a Private App

The user needs to create a Private App in HubSpot and copy the access token. You cannot do this step for them — HubSpot requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please open this page in your browser: **https://app.hubspot.com/private-apps/** — and sign in with your HubSpot account. Let me know when you are signed in."
   - If the user has multiple portals, they may need to select one first. If they mention this, say: "Pick the account you want me to work with, then let me know."

2. When they confirm → "Now click the orange **Create a private app** button. A form will appear. Tell me when you see it."

3. When they see the form → deliver the field values:
   - "For **Name**, type: **Claude Assistant**."
   - "For **Description**, you can type: **AI assistant connection** — or leave it blank."
   - "Now click the **Scopes** tab at the top of the form."

4. When they are on the Scopes tab → guide them through selecting scopes. Start with read-only for safety:
   - "Under **CRM**, tick these boxes: **crm.objects.contacts.read**, **crm.objects.companies.read**, **crm.objects.deals.read**, **crm.objects.quotes.read**, and **crm.schemas.contacts.read**."
   - "If you also want me to create or update records for you, also tick: **crm.objects.contacts.write**, **crm.objects.companies.write**, and **crm.objects.deals.write**."
   - "You can always add more permissions later without starting over."
   - "When you have ticked the boxes, click the orange **Create app** button in the top right. Then click **Continue creating** if HubSpot asks you to confirm."

5. When they confirm → "You should now see a screen with your **access token** — it starts with `pat-`. Please copy it and paste it to me."

Common mistakes to look out for (and correct by re-asking):
- The user pasted a placeholder like `your_token_here` → ask again: "I think that was a copy mistake — please try the real value that starts with `pat-`."
- The user pasted something that does not start with `pat-` → "That doesn't look quite right. The value I need starts with `pat-` and is quite long. Can you check and try again?"
- The user says they cannot find the Scopes tab → "It is a tab at the top of the form, next to **Basic Info**. Click on it and you should see a list of permissions."

### Step 3 — Save the connection

Once the user pastes the access token, silently add or update the HubSpot MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

```json
{
  "mcpServers": {
    "hubspot": {
      "command": "npx",
      "args": ["-y", "@hubspot/mcp-server"],
      "env": {
        "PRIVATE_APP_ACCESS_TOKEN": "<token from Step 2>"
      }
    }
  }
}
```

Merge this into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the HubSpot entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Never echo the access token back to the user after writing it. Never include it in any output visible to the user.

Tell the user: "I have saved your connection details. Let me verify everything is working."

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to HubSpot correctly."

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__hubspot__*` tools are available** (i.e., the MCP server was already running or has reloaded): call `mcp__hubspot__hubspot-get-user-details` (or the equivalent user/account info tool). If it returns the portal name, capture it and move to Step 5.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my HubSpot connection' and I will verify it."

If the verification tool returns an error:
- `401 Unauthorized` or `Invalid token` → "The connection key didn't work. Could you double-check it in HubSpot? Go back to the Private App page and copy the token again." Then re-do Step 3 with the new token.
- `403 Forbidden` or `Missing scope` → "Your connection is working, but I need an extra permission for that action. Let me tell you which box to tick." Guide them to the Private App's Scopes tab to add the missing scope, then tell them to click **Save** and come back.
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-check their Private App is active.

### Step 5 — Success message

Tell the user, in one short message:

> "All done! I am now connected to your HubSpot account **[portal name if available]**. You can ask me things like 'show me my recent contacts' or 'list my open deals'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__hubspot__*` MCP tools below to answer questions and make changes in HubSpot. The `@hubspot/mcp-server` provides ~20 native tools covering CRM data CRUD.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__hubspot__`. The exact tool names follow the pattern `mcp__hubspot__hubspot-<action>`. Below are the known tools and when to use them:

#### CRM Objects (Contacts, Companies, Deals, Tickets)

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-objects` | Retrieves a paginated list of CRM records for a specified object type | User asks to list/browse contacts, companies, deals, or tickets |
| `hubspot-search-objects` | Performs filtered searches across CRM records using complex criteria | User asks to find records by name, email, or property value |
| `hubspot-batch-read-objects` | Retrieves multiple CRM records by their IDs in a single batch | User asks for details about specific records by ID |
| `hubspot-batch-create-objects` | Creates multiple CRM records of the same type in a single call | User asks to create a new contact, company, deal, or ticket — **confirm first** |
| `hubspot-batch-update-objects` | Updates multiple existing CRM records with new property values | User asks to update properties on any CRM object — **confirm first** |

#### Properties

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-properties` | Retrieves the complete catalog of properties for any CRM object type | User asks what fields are available on contacts, companies, deals, etc. |
| `hubspot-get-property` | Retrieves detailed information about a specific property definition | User asks about a specific field's options or configuration |
| `hubspot-create-property` | Creates new custom properties for CRM object types | User asks to add a custom field — **confirm first** |
| `hubspot-update-property` | Updates settings for existing custom properties | User asks to modify a custom field — **confirm first** |

#### Associations

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-associations` | Retrieves existing relationships between a record and associated records | User asks what is linked to a contact/company/deal (e.g., "what deals does Acme have?") |
| `hubspot-batch-create-associations` | Establishes multiple relationships between CRM records | User asks to link a contact to a company, a deal to a contact, etc. — **confirm first** |
| `hubspot-get-association-definitions` | Retrieves valid association types and labels between object types | You need to know which association types are valid before creating one |

#### Engagements (Notes & Tasks)

| Tool | Description | Use when |
|---|---|---|
| `hubspot-create-engagement` | Creates engagements (Notes or Tasks) associated with CRM records | User asks to create a note or task on a contact, company, or deal — **confirm first** |
| `hubspot-get-engagement` | Retrieves engagement details by ID | User asks to see a specific note or task |
| `hubspot-update-engagement` | Updates an existing engagement with new information | User asks to edit a note or task — **confirm first** |

#### Custom Objects

| Tool | Description | Use when |
|---|---|---|
| `hubspot-get-schemas` | Retrieves available custom object schemas with objectTypeId and definitions | User asks about custom object types in their portal |

#### Workflows

| Tool | Description | Use when |
|---|---|---|
| `hubspot-list-workflows` | Retrieves a paginated list of workflows | User asks to see their automated workflows |
| `hubspot-get-workflow` | Retrieves detailed info about a specific workflow (actions, enrollment criteria) | User asks about a specific workflow's configuration |

#### Account & Links

| Tool | Description | Use when |
|---|---|---|
| `hubspot-get-user-details` | Authenticates token and returns user info, hub details, and scopes | User asks "what HubSpot account am I connected to?" or you need to verify the connection |
| `hubspot-get-link` | Generates HubSpot UI URLs to directly access records in the browser | User wants a link to open a record in HubSpot |
| `hubspot-generate-feedback-link` | Generates a feedback link for reporting tool issues to HubSpot | User wants to report an issue with the MCP tools |

> **Note:** Tool names are from `@hubspot/mcp-server` v0.4.0 (beta). If a tool name does not resolve, try listing available tools with the `mcp__hubspot__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Show me my contacts" | `hubspot-list-objects` (objectType: contacts) |
| "Find the contact with email jane@example.com" | `hubspot-search-objects` (objectType: contacts, search by email) |
| "Show me details for contact #12345" | `hubspot-batch-read-objects` (objectType: contacts) |
| "Create a new contact for Jane Doe" | `hubspot-batch-create-objects` (objectType: contacts) — **confirm first** |
| "List my companies" | `hubspot-list-objects` (objectType: companies) |
| "Show me my open deals" | `hubspot-search-objects` (objectType: deals, filter by stage) |
| "Create a deal for Acme Corp" | `hubspot-batch-create-objects` (objectType: deals) — **confirm first** |
| "Update the phone number on contact #12345" | `hubspot-batch-update-objects` (objectType: contacts) — **confirm first** |
| "What deals are linked to Acme Corp?" | `hubspot-list-associations` |
| "Link this deal to that contact" | `hubspot-batch-create-associations` |
| "Add a note to this deal" | `hubspot-create-engagement` (type: note) |
| "Show me tasks on this contact" | `hubspot-get-engagement` |
| "What properties does a contact have?" | `hubspot-list-properties` (objectType: contacts) |
| "Show me my workflows" | `hubspot-list-workflows` |
| "What HubSpot account am I connected to?" | `hubspot-get-user-details` |
| "Connect my HubSpot" / "Help me set up HubSpot" | **Run Phase 1** |

---

## Error Handling (Phase 2)

When a HubSpot tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Invalid token | "Your HubSpot connection has expired or the key was revoked — let me help you reconnect." | Run Phase 1 from Step 2 (create a new Private App or copy a fresh token) |
| 403 Forbidden / Missing scope | "I need an extra permission to do that. Let me walk you through adding it." | Guide user to Private App → Scopes tab → tick the needed scope → Save. Then retry. |
| 429 Rate limited | "HubSpot is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest trying again in a minute. |
| "Token revoked" | "Your connection key has been revoked in HubSpot. Let me help you create a new one." | Run Phase 1 from Step 2 |
| Object not found (404) | "I couldn't find that record — let me search for it." | Use search tool to help find the correct object |
| MCP server not running | "The HubSpot connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with HubSpot — let me try again." | Retry once; if still failing, check token validity |

---

## Scope Limitations

The HubSpot MCP connector **can** do (via `@hubspot/mcp-server`):
- Read and write contacts, companies, deals, and tickets
- Search CRM objects by any property
- Read and create custom object schemas
- Read and create properties on any object type
- Read and create associations between objects
- Create engagements (notes, tasks) on CRM records
- Read workflows
- Read account/user details

The HubSpot MCP connector **cannot** do (deferred to a future version):
- Marketing Hub operations (email campaigns, forms, landing pages)
- Service Hub operations (knowledge base, feedback surveys)
- Commerce operations (quotes, payments, subscriptions)
- File uploads or attachments
- Bulk import/export
- Delete CRM records (use the HubSpot UI for deletions)
- Send emails directly
- Trigger or modify workflows (read-only)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating or updating** records — summarise what you are about to do and wait for the user's OK before calling the tool.
- **IDs are numeric** — HubSpot uses numeric IDs (e.g. `12345`) for all CRM objects.
- **Amounts are in full currency units** — deal amounts are in dollars (e.g. `50000` = $50,000), not cents.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Pagination** — default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits** — HubSpot enforces 200 requests per 10 seconds for Private Apps. If you hit a 429, wait before retrying.
- **Deal stages** — stage IDs vary by pipeline and account. List pipeline stages first before setting a deal stage.
- **Properties** — use `hubspot-list-properties` to discover available fields before assuming a property exists.
- **Associations** — check existing associations before creating duplicates.
- **Never log or echo credentials** — the Private App access token must never appear in any output visible to the user.
- **Scope expansion** — if a tool call fails with 403 / missing scope, guide the user to add the scope in their Private App settings. They do NOT need to create a new app — just edit the existing one and click Save.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **systematic-debugging**: For troubleshooting HubSpot auth or API errors
- **xero-connector**: Sibling accounting connector — similar MCP pattern for a different platform
