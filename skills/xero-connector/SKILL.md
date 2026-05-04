---
name: xero-connector
description: "Read and update Xero accounting data on behalf of the user via the official @xeroapi/xero-mcp-server. Handles invoices (list, view, create, update), contacts (list, create, update), quotes, credit notes, items, manual journals, bank transactions, payments, tax rates, trial balance, profit and loss, balance sheet, aged receivables and payables, contact groups, tracking categories, and the connected organisation's details. Also handles NZ/UK payroll tools (employees, leave, timesheets). Use this skill when the user asks about their Xero, invoices, unpaid invoices, contacts, profit and loss, balance sheet, bank transactions, chart of accounts, payments, quotes, or when they say 'connect my Xero' or 'help me set up Xero'. On the first use of any Xero feature, run Phase 1 to set up the Custom Connection and wire the MCP server into Claude Code before attempting any tool calls."
allowed-tools: mcp__xero__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - xero
    - accounting
    - invoices
    - contacts
    - finance
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Xero Custom Connection or API errors
    - skill: quickbooks-connector
      reason: Sibling accounting connector — similar wrap-existing-tooling pattern for a different platform
    - skill: hubspot-connector
      reason: Same Client ID / Secret → ~/.claude.json pattern for a different first-party MCP server
---

# Xero Connector

## Overview

This skill lets you read and update a user's Xero accounting data on their behalf using the **official first-party [`@xeroapi/xero-mcp-server`](https://github.com/XeroAPI/xero-mcp-server)** (maintained by Xero, published to npm). It has two phases:

- **Phase 1 — Install & Connect.** A conversational bootstrap (≤5 steps). The user has never used this before. You walk them through creating a Custom Connection inside their Xero developer portal, collecting the Client ID and Client Secret, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "env var", or any file paths. They should feel like they are having a conversation, and at the end their Xero is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__xero__*` native tools to read and update Xero data. The official server exposes ~56 tools; this skill documents the ~25 most commonly used and notes where the rest live.

**Which phase to run** — Before any tool call, check whether the Xero MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.xero` entry with `XERO_CLIENT_ID` and `XERO_CLIENT_SECRET` in its `env` block. If both exist and are non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **Our old custom `xero-connector/src/index.js` Node server** — deleted. We wrap the official `@xeroapi/xero-mcp-server` instead, same wrap-existing-tooling pattern as `quickbooks-connector` (via `qbo-cli`), `hubspot-connector` (via `@hubspot/mcp-server`), `ghl-connector` (via HighLevel's hosted MCP), and `google-chat-connector` (via `gws`).
- **OAuth 2.0 Authorization Code flow / redirect URIs / localhost callbacks / `.xero-token.json`** — Custom Connections use the client credentials grant type. No browser sign-in dance, no refresh token management, no `auth.js` to run. The server gets a fresh access token on demand using just Client ID + Client Secret.
- **`.env` files** — credentials live in the MCP config at `~/.claude.json`, never in a local dotenv.
- **The `@xeroapi/xero-mcp-server` Bearer Token mode** — that mode is for clients that can run their own PKCE flow and inject short-lived tokens. Not applicable here.

---

## ⚠️ Safety gate — run this BEFORE Phase 1 Step 1

Xero Custom Connections carry two real constraints that the user must acknowledge before you touch anything. These are non-negotiable and need to be raised in plain English, upfront, with explicit confirmation.

**Say this verbatim (or very close to it) and wait for the user's answer:**

> "Before we start, two quick things you need to know about connecting Xero:
>
> **1. Cost.** Xero charges about **five US dollars per month** (around $8 AUD) to enable the kind of connection we need. This sits on top of your normal Xero subscription as a small extra charge. It's optional — but it's the only path that lets me talk to your Xero without you having to click 'Allow access' every 30 minutes.
>
> **2. Where you are.** Xero only offers this kind of connection in **Australia, New Zealand, the UK, and the US** right now. If your Xero organisation is in any other country, I can't connect it yet — you'd need to reach out to Luke at luke@selrai.com.au and we'll set you up with the alternative.
>
> Which country is your Xero organisation in, and are you okay with the small monthly charge?"

**Handle the response:**

- **User confirms AU/NZ/UK/US and accepts cost** → proceed to Step 1.
- **User is in another country** → say: *"No worries at all — I can't set you up automatically from here, but Luke at luke@selrai.com.au has the alternative path and will get you sorted. I'll stop here so you can reach out to him when you're ready."* Do not proceed with Phase 1. Do not attempt workarounds.
- **User is hesitant about the cost** → say: *"Totally fair. I won't push you — and I won't set anything up until you're comfortable. Take your time, and let me know when you're ready. Is there anything about the cost you'd like me to explain?"* Answer questions if asked, then wait for clear consent before proceeding.
- **User refuses the cost outright** → say: *"No problem — we can skip Xero for now. If you change your mind later, just say 'connect my Xero' and we'll pick this back up."* Do not proceed.

Only proceed past this gate when the user has **explicitly confirmed both** (region and cost).

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, client credentials, or custom connection as a technical concept. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now — this takes just a moment."
- **React warmly.** Good: "That worked — your Xero is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Connect (≤5 steps)

This phase gets the Xero Custom Connection created, the Client ID and Client Secret collected, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only clicks things in their browser and pastes two values.

### Step 1 — Orient the user

Tell the user in one short message:

> "Great — let's connect your Xero. I'll walk you through creating a small connection key inside Xero, then I'll save it on your computer and check everything is talking. The Xero part takes about three minutes."

### Step 2 — Walk the user through creating a Custom Connection

The user needs to create a Custom Connection inside Xero's developer portal and copy two values. You cannot do this step for them — Xero requires their authenticated session.

Tell the user, one instruction at a time, waiting for confirmation between each:

1. "Please open this page in your browser: **https://developer.xero.com/app/manage** — and sign in with your Xero account. Let me know when you are signed in."

2. When they confirm → "Now click the **New app** button (top right). A form will appear. Tell me when you see it."

3. When they see the form → deliver the field values:
   - "For **App name**, type: **Claude Assistant**."
   - "For **Integration type**, choose: **Custom connection**. (Not 'Web app', not 'Mobile or desktop app'.)"
   - "For **Company or application URL**, you can paste any valid web address — your own business website is fine."
   - "Tick the box to accept the terms, then click the blue **Create app** button. Tell me when you're on the new app's page."

4. When they confirm → "Now I need you to pick which Xero organisation you want me to connect to — Custom connections link to one organisation at a time. On the app's page, you should see a dropdown to choose the organisation. Please pick the one you want me to work with."

5. When they confirm → "Next, you'll see a list of permissions (scopes). Please tick all of these:
   - **accounting.transactions**
   - **accounting.contacts**
   - **accounting.settings**
   - **accounting.reports.read**

   Then click **Save**. Tell me when the scopes are saved."

   > *(If the user mentions payroll or they're in NZ/UK and want payroll tools: also ask them to tick `payroll.employees`, `payroll.timesheets`, and `payroll.settings`. Otherwise skip payroll scopes — we can add them later.)*

   > *Why this exact set: these are the V1 scopes the upstream `@xeroapi/xero-mcp-server` tries first. The server falls back to a granular V2 set automatically if Xero ever returns `invalid_scope` on V1 — no SKILL.md change needed when that happens. Source: `XeroAPI/xero-mcp-server/src/clients/xero-client.ts`.*

6. When they confirm → "Nearly there. Xero will now ask you to **activate** the connection, and this is where the small monthly charge kicks in. Go ahead and follow Xero's prompts to confirm your payment details and activate the connection. Tell me when Xero says the connection is active."

   Handle what they report:
   - **They see a payment screen and complete it** → "Perfect, thank you." Continue.
   - **They see "payment method required" and don't have one saved** → "That's normal — Xero needs a card on file for this. Go ahead and add one when prompted; it's only charged for the connection, not a random hold." Wait for completion.
   - **They cancel or back out** → "No problem at all — we can stop here. Come back whenever you're ready and say 'connect my Xero' to pick this back up." Do not proceed.

7. When they confirm the connection is active → "Last Xero step: on the connection page you should now see your **Client ID** and a button to **Generate a secret**. Please copy the **Client ID** and paste it to me."

8. When they paste the Client ID → "Thanks. Now click **Generate a secret** and a long string will appear. Please copy the **Client Secret** and paste it to me — and don't worry about remembering it, I'll save it for you."

**Common mistakes to look out for (and correct by re-asking):**

- The user pasted a placeholder like `your_client_id_here` → ask again: "I think that was a copy mistake — please try again with the real value."
- The user pasted something very short (under 20 characters) → "That doesn't look quite right — the real value is longer. Can you double-check and try again?"
- The user chose **Web app** instead of **Custom connection** → "One small thing — the type needs to be **Custom connection**, not **Web app**. That's the one that works without a browser sign-in loop. You'll need to delete this app and create a new one. Sorry for the hassle — worth it, I promise."
- The user says *"I don't see Custom connection as an option"* → "That usually means your Xero organisation is in a country where Custom Connections aren't offered yet. The supported countries are Australia, New Zealand, the UK, and the US. If your organisation is elsewhere, let's stop here and you can reach out to Luke at luke@selrai.com.au for the alternative path." Do not proceed.

### Step 3 — Save the credentials

Once the user pastes the Client ID and Client Secret, silently add or update the Xero MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

```json
{
  "mcpServers": {
    "xero": {
      "command": "npx",
      "args": ["-y", "@xeroapi/xero-mcp-server@latest"],
      "env": {
        "XERO_CLIENT_ID": "<client id from Step 2>",
        "XERO_CLIENT_SECRET": "<client secret from Step 2>"
      }
    }
  }
}
```

**Rules:**
- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other `mcpServers` entry the user already has.
- If `~/.claude.json` does not exist, create it with just the Xero entry.
- If the file exists but cannot be parsed as JSON, back it up to `~/.claude.json.backup` first, then write a fresh config with just the Xero entry. Never silently lose the user's existing config.
- Never echo the Client ID or Client Secret back to the user after writing them. Never include them in any output visible to the user.

Tell the user in one short message:

> "I've saved your connection details. One more step — you'll need to close Claude Code and open it again so it picks up the new connection. Do that now, and tell me when you're back."

### Step 4 — User restarts Claude Code

Wait for the user to restart. When they return, tell them: *"Welcome back. Let me just check that everything is talking to Xero."*

### Step 5 — Verify the connection

Call the `mcp__xero__list-organisation-details` tool (no arguments). Handle the response:

- **Tool returns organisation name** → Capture it. Tell the user:
  > "All done! I'm now connected to your Xero organisation **[organisation name]**. You can ask me things like 'show me my recent invoices', 'what's my profit and loss this year?', or 'find Acme Corp in my contacts'. Give it a try!"

- **Tool returns `invalid_client` or `unauthorized`** → "Hmm, the connection key didn't work — let me take them again." Silently go back to Step 2 Part 7 and ask the user to re-copy the Client ID and Secret (they may have copied incomplete strings). Rewrite `~/.claude.json` with the fresh values, ask them to restart Claude Code, and try Step 5 again.

- **Tool returns `403 Forbidden` or `insufficient scope`** → "Your connection is working, but I need one or two extra permissions. Let me show you which boxes to tick." Guide the user back to their Custom Connection page in Xero, have them tick the missing scope(s) based on the error (typically `accounting.transactions`, `accounting.reports.read`, or `accounting.contacts`), click **Save**, and then re-run Step 5. **No restart of Claude Code needed** for scope changes — they apply on the next API call.

- **Tool is not yet available (`mcp__xero__*` tools not discoverable)** → "Looks like Claude Code didn't pick up the new connection yet. Please make sure you fully closed it (not just the window) and opened it again, then let me know." Repeat Step 4.

- **Any other error** → "Something's not quite right — let me try once more." Retry the tool call once. If it still fails, tell the user in plain English what you saw (translated — never raw errors), and ask if they want to retry or stop.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__xero__*` MCP tools below to answer questions and make changes in Xero. The `@xeroapi/xero-mcp-server` exposes **~56 tools total**; this reference covers the ~25 most commonly used and notes where the rest live.

**Tool naming convention:** The official server uses hyphen-separated names (e.g. `list-invoices`), not the underscored `xero_*` names from the old custom server. In Claude Code they appear as `mcp__xero__list-invoices`, `mcp__xero__create-invoice`, etc.

### Core read tools

| Tool | Description | Use when |
|---|---|---|
| `list-organisation-details` | Returns the connected Xero organisation name and details | User asks "what Xero org am I connected to?" or you need to verify the connection is alive |
| `list-invoices` | Lists invoices with optional filters (status, date range, contact, pagination) | User asks to see invoices, unpaid invoices, overdue invoices, draft invoices, or invoices for a specific contact |
| `list-contacts` | Lists contacts (customers and suppliers) with optional search | User asks to find a customer, supplier, or contact |
| `list-accounts` | Lists the chart of accounts with codes and types | User asks about their chart of accounts, or you need to look up an account code before creating an invoice |
| `list-bank-transactions` | Lists bank transactions | User asks about bank feeds, money in/out, or recent bank activity |
| `list-payments` | Lists payments recorded against invoices or bills | User asks about payments received or made |
| `list-items` | Lists inventory items and their prices | User asks about their product catalogue or item pricing |
| `list-quotes` | Lists quotes with optional status filter | User asks about sales quotes, open quotes, or quotes for a specific contact |
| `list-credit-notes` | Lists credit notes | User asks about refunds, returns, or credit notes |
| `list-manual-journals` | Lists manual journal entries | User asks about journal entries or manual postings |
| `list-tax-rates` | Lists available tax rates | User asks what tax codes are available, or you need a tax code for a new invoice |
| `list-contact-groups` | Lists contact groups | User asks about how their contacts are grouped or segmented |
| `list-tracking-categories` | Lists tracking categories and their options | User asks about cost centres, departments, or tracking dimensions |

### Reports

| Tool | Description | Use when |
|---|---|---|
| `list-profit-and-loss` | Returns the P&L report for a date range | User asks about income, expenses, net profit, or P&L — *"P&L for this year", "how did we do last month"* |
| `list-report-balance-sheet` | Returns the balance sheet at a date | User asks about their balance sheet, assets, liabilities, or equity position |
| `list-trial-balance` | Returns the trial balance report | User asks about their trial balance or wants an accountant-style account summary |
| `list-aged-receivables-by-contact` | Returns aged receivables for a contact | User asks "who owes me money and for how long?" or asks about a specific customer's overdue invoices |
| `list-aged-payables-by-contact` | Returns aged payables for a contact | User asks "who do I owe money to?" or asks about a specific supplier's unpaid bills |

### Create tools — **always confirm with the user before calling**

| Tool | Description | Use when |
|---|---|---|
| `create-invoice` | Creates a new **DRAFT** invoice — never auto-approved | User asks to create, draft, or make an invoice. Always created as DRAFT so the user can review and approve in Xero. |
| `create-contact` | Creates a new contact (customer or supplier) | User asks to add a new customer or supplier |
| `create-quote` | Creates a new quote | User asks to create a sales quote |
| `create-credit-note` | Creates a new credit note | User asks to issue a credit note or refund |
| `create-payment` | Records a payment against an invoice or bill | User asks to record that an invoice has been paid |
| `create-bank-transaction` | Creates a bank transaction (spend or receive money) | User asks to record a bank transaction |
| `create-item` | Creates a new inventory item | User asks to add a product or service to their catalogue |
| `create-manual-journal` | Creates a manual journal entry | User asks to post a manual journal |

### Update tools — **always confirm with the user before calling**

| Tool | Description | Use when |
|---|---|---|
| `update-invoice` | Updates an existing draft invoice | User asks to modify a draft invoice (can't modify authorised/paid invoices) |
| `update-contact` | Updates an existing contact | User asks to change a contact's details |
| `update-quote` | Updates an existing draft quote | User asks to modify a draft quote |
| `update-credit-note` | Updates an existing draft credit note | User asks to modify a draft credit note |

### Payroll (NZ/UK only)

The server also exposes a full set of payroll tools (`list-payroll-employees`, `list-payroll-employee-leave`, `create-payroll-timesheet`, `approve-payroll-timesheet`, etc.) for Xero organisations in New Zealand and the United Kingdom. These require the `payroll.*` scopes to be ticked on the Custom Connection. If the user is in NZ/UK and asks about payroll and you get a 403, guide them back to add the payroll scopes (same flow as Phase 1 Step 2 Part 5).

> **Note:** The full 56-tool surface of `@xeroapi/xero-mcp-server` is larger than this table. If a user asks for something not covered above, try searching for a matching tool name using the `mcp__xero__` prefix — the tool may exist upstream and just not be documented here yet.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Xero" / "Help me set up Xero" | **Run Phase 1** (starting with the safety gate) |
| "What Xero org am I connected to?" | `list-organisation-details` |
| "Show me my invoices" | `list-invoices` |
| "List unpaid invoices" | `list-invoices` with status: `AUTHORISED` |
| "Show me overdue invoices" | `list-invoices` with status: `AUTHORISED` + filter by due date in Claude |
| "Find invoices for [client]" | `list-invoices` with contact filter |
| "Create an invoice for [client] for [amount]" | `create-invoice` — **confirm first** |
| "Update invoice INV-0042" | `update-invoice` — **confirm first** |
| "Find [name] in my contacts" | `list-contacts` with search |
| "Add a new contact" / "Create a contact for [name]" | `create-contact` — **confirm first** |
| "Update [contact]'s email/phone" | `update-contact` — **confirm first** |
| "Show me my chart of accounts" | `list-accounts` |
| "List my bank transactions" | `list-bank-transactions` |
| "Record a payment for [invoice]" | `create-payment` — **confirm first** |
| "Show me recent payments" | `list-payments` |
| "Show me my quotes" / "Open sales quotes" | `list-quotes` |
| "Create a quote for [client]" | `create-quote` — **confirm first** |
| "Show me credit notes" / "Refunds" | `list-credit-notes` |
| "Issue a credit note for [client]" | `create-credit-note` — **confirm first** |
| "Show me my products" / "List my items" | `list-items` |
| "Profit and loss for this year" | `list-profit-and-loss` |
| "Get the balance sheet" | `list-report-balance-sheet` |
| "Trial balance" | `list-trial-balance` |
| "Who owes me money?" / "Aged receivables" | `list-aged-receivables-by-contact` |
| "Who do I owe?" / "Aged payables" | `list-aged-payables-by-contact` |
| "What tax rates can I use?" | `list-tax-rates` |
| "List my tracking categories" / "Cost centres" | `list-tracking-categories` |

---

## Error Handling (Phase 2)

When a Xero tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say to the user | How to fix |
|---|---|---|
| `invalid_client` / `401 Unauthorized` | "Your Xero connection key isn't working — let me sort that now." | Run Phase 1 from Step 2 Part 7 (re-copy Client ID and Secret). If re-copying doesn't help, ask the user to confirm the Custom Connection is still **Active** in Xero. |
| `403 Forbidden` / `insufficient scope` | "I need one extra permission for that. Let me show you which box to tick." | Guide the user back to developer.xero.com → their Custom Connection → Scopes → tick the missing scope → Save. No restart needed. Retry the original tool call. |
| `Connection deactivated` / `Subscription not active` | "Your Xero connection has been deactivated — this usually means the monthly charge has lapsed. Could you check the Custom Connections page in your Xero developer portal?" | Send the user to developer.xero.com to reactivate the connection. Do not auto-retry. |
| `No organisations found` / `tenant not linked` | "I can't find a Xero organisation on the connection — let me re-check it." | Verify `XERO_CLIENT_ID` is set in `~/.claude.json`. If the Client ID is correct, the user may have unlinked the organisation in Xero — guide them to reconnect it. |
| `429 Rate limited` | "Xero is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest waiting a minute. |
| `404 Not Found` on a specific record | "I couldn't find that — let me search for it." | Use the matching `list-*` tool to help the user find the correct record. |
| `400 Validation` on create/update | Summarise which field is invalid in plain English (e.g., *"Xero says the invoice date format isn't right — let me fix it and try again"*) | Correct the request and retry once. If the user's input is ambiguous, ask them to clarify. |
| MCP server not discovered (`mcp__xero__*` tools missing) | "The Xero connection isn't active in this session. Please close Claude Code fully and reopen it, then try again." | User restarts Claude Code. |
| Any other API error | "Something went wrong with Xero — let me try again." | Retry once; if still failing, check the Custom Connection is active. |

---

## Scope Limitations

The Xero connector **can** do (via `@xeroapi/xero-mcp-server`):

- Read and write invoices (accounts receivable), contacts, quotes, credit notes, items, bank transactions, payments, manual journals, and tracking categories
- Read the chart of accounts, tax rates, P&L, balance sheet, trial balance, aged receivables, aged payables, and contact groups
- Create new drafts across invoices, quotes, credit notes, and bank transactions — always as DRAFT, never auto-approved
- NZ/UK only: read and write payroll employees, leave, leave types, leave periods, timesheets (including approve/revert/delete)

The Xero connector **cannot** do:
- **Delete** CRM records — use the Xero UI for deletions
- **Send** invoices or quotes via email to customers — the user does this in Xero after approving the draft
- **Reconcile** bank transactions against statement lines
- **File** tax returns or lodge BAS/VAT
- **Access** Xero Files or attachments upload/download
- **Access** Projects, Fixed Assets, Budgets, or Expenses (the separate Xero products, not the core accounting module)
- **Connect to multiple Xero organisations at once** — Custom Connections are scoped to one organisation at creation time. To switch organisations, the user must create a second Custom Connection and re-run Phase 1.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating or updating** records — summarise what you are about to do and wait for the user's OK before calling the tool. This is especially important for invoices, quotes, credit notes, and payments.
- **Invoices, quotes, and credit notes are always DRAFT** — never imply a document has been sent, approved, or invoiced to the customer. Say "I've created a draft — review and approve it in Xero when ready."
- **Format currency correctly** — use the currency from the Xero response (AUD, NZD, USD, GBP, etc.) and format amounts with 2 decimal places.
- **Present reports clearly** — when showing P&L, Balance Sheet, or Trial Balance, format as a readable table, not raw JSON. Summarise the headline numbers first (net profit, total assets, etc.), then offer to show detail.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.
- **Single organisation** — the connector is locked to one Xero organisation per Custom Connection. If the user asks about a different Xero organisation, tell them: *"I'm currently connected to [current org]. To switch, you'd need to create a second Custom connection in Xero for the other organisation, then we can swap the connection key — want to do that now?"*
- **Pagination** — default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits** — Xero enforces rate limits per organisation. If you hit a 429, wait before retrying.
- **Account codes** — when creating an invoice, use `list-accounts` to find the right account code first if you don't already know it.
- **Tax rates** — when creating an invoice in a tax-registered organisation, use `list-tax-rates` to find the right tax code. Do not guess.
- **Never log or echo credentials** — the `XERO_CLIENT_ID` and `XERO_CLIENT_SECRET` must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Xero Custom Connection or API errors
- **quickbooks-connector**: Sibling accounting connector for QuickBooks users — similar wrap-existing-tooling pattern
- **hubspot-connector**: Same Client ID / Secret → `~/.claude.json` pattern for a different first-party MCP server
