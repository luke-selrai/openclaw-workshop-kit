---
name: xero-connector
description: "Interact with Xero accounting data through MCP tools. Use this skill when the user asks about invoices, contacts, accounts, bank transactions, payments, profit and loss, balance sheet, or any Xero accounting data. Handles reading invoices, creating invoices, looking up contacts, adding contacts, viewing chart of accounts, listing bank transactions, listing payments, and pulling financial reports. Also use when the user mentions 'Xero,' 'my invoices,' 'profit and loss,' 'balance sheet,' 'unpaid invoices,' 'Xero contacts,' 'bank transactions,' 'chart of accounts,' 'create an invoice,' or 'connect my Xero account.'"
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
    - skill: systematic-debugging
      reason: Use for troubleshooting Xero auth or API errors
    - skill: first-run-setup
      reason: Conversational install pattern — connector phase follows the same model
---

# Xero Connector

This skill connects the user's Xero accounting data to Claude Code through an MCP server. It has **two phases**:

- **Phase 1 — Install & Auth** — guide the user conversationally through first-time setup
- **Phase 2 — Everyday Use** — use the Xero MCP tools to read and create accounting data

Before doing anything, run the **readiness check** below. If the connector is already set up, skip straight to Phase 2. If not, run Phase 1.

---

## Readiness Check

Run these checks silently using the Bash tool. Do not narrate them unless one fails.

1. **Connector directory exists:** `xero-connector/` is present in the current project or a known install location
2. **Dependencies installed:** `xero-connector/node_modules/` exists
3. **Credentials saved:** `xero-connector/.env` exists with real `XERO_CLIENT_ID` and `XERO_CLIENT_SECRET` values (not placeholders like `your_client_id_here`)
4. **Token exists:** `xero-connector/.xero-token.json` exists and is non-empty
5. **MCP server wired up:** `~/.claude.json` has an `mcpServers.xero` entry

If all five checks pass → **go to Phase 2**.
If any check fails → **run Phase 1**, starting from the first failing step.

---

## Phase 1 — Install & Auth

> **This phase is a conversation, not a script.** You are installing Xero *with* the user, not telling them to run commands. Every step below is something **you** do through the Bash, Write, or Edit tools, with plain-English progress updates to the user.

> **Never tell the user to run `node src/install.js`, `npm run auth`, or any other command themselves.** The `xero-connector/src/install.js` file exists as a legacy one-shot script — treat it as internal only. The user should never see it referenced.

### Step 1 — Orient the user

Say something like:

> *"I'm going to connect your Xero account to Claude. This takes about 5 minutes. I'll walk you through it one step at a time — the only thing I'll need from you is a couple of values from your Xero developer account partway through. Ready?"*

Wait for confirmation before proceeding.

### Step 2 — Confirm install location

If `xero-connector/` already exists in the current project, use it. If not, ask the user where they want to install it. Default to the current working directory.

### Step 3 — Check Node.js version

Run `node --version` via Bash. Parse the output:

- If Node is **not installed** → Tell the user plainly: *"You need Node.js 20 or higher. Let me walk you through installing it."* Point them at [nodejs.org](https://nodejs.org) and wait for them to install it before continuing. On Mac/Linux, suggest `nvm` as the easiest path.
- If Node is **older than v20** → Same message, plus offer to help them upgrade via `nvm`.
- If Node is **v20 or higher** → Report: *"✓ Node.js [version] looks good."*

### Step 4 — Install dependencies

Run `cd xero-connector && npm install` via Bash. This takes 1–2 minutes — tell the user so, and don't interrupt them during the wait.

**Handle common failures:**

| Failure | Response |
|---|---|
| `EINTEGRITY` | *"Your npm cache looks corrupted. Let me clean it and try again."* → run `npm cache clean --force`, retry once |
| `EACCES` / permission denied | *"This looks like a permissions issue. The cleanest fix is to use `nvm` so you don't need `sudo`. Want me to walk you through that?"* |
| `ECONNRESET` / `ECONNREFUSED` / 403 | *"Looks like npm can't reach the internet — this usually means a corporate firewall. You'll need to ask your IT team to allow `registry.npmjs.org:443`."* |
| Any other error | Read the error output, summarise it in plain English, suggest a fix, never dump raw logs |

On success, report: *"✓ Dependencies installed."*

### Step 5 — Get Xero credentials from the user

Explain *why* these are needed before asking. Say something like:

> *"Now I need to connect to Xero's developer portal. You'll create a free app there (takes about 2 minutes) and give me two values: a **Client ID** and a **Client Secret**.*
>
> *Here's what to do:*
>
> *1. Open [developer.xero.com/app/manage](https://developer.xero.com/app/manage) and sign in with your normal Xero account*
> *2. Click **New app***
> *3. Give it any name (e.g. "Claude Code")*
> *4. For **Integration type** select **Web app***
> *5. For **Company or application URL** use `https://selrai.com.au` (or your own website)*
> *6. For **Redirect URI** use exactly: `http://localhost:3000/callback`*
> *7. Click **Create app***
> *8. On the app page, click **Generate a secret** and copy both the Client ID and the Secret*
>
> *Paste them back to me when you have them — one at a time is fine."*

Collect both values in conversation. Validate that neither is empty or a literal `your_client_id_here` placeholder.

**Security note:** Never echo the Client Secret back in plain text. Refer to it as *"your Client Secret"* in your replies. Never log it, never include it in error messages, never write it anywhere except `.env`.

### Step 6 — Write the `.env` file

Use the Write tool to create `xero-connector/.env` with this content (substituting the real values):

```
# Xero Connector — Environment Variables
# Generated during conversational install — do not commit this file

XERO_CLIENT_ID=<client-id-from-user>
XERO_CLIENT_SECRET=<client-secret-from-user>
```

Confirm: *"✓ Saved your credentials locally in `xero-connector/.env`. This file is gitignored — it won't leak."*

### Step 7 — Run the Xero OAuth flow

Run `cd xero-connector && npm run auth` via Bash (this invokes `src/auth.js`, which starts a local server on port 3000 and opens the user's browser to Xero's consent page).

Tell the user what's about to happen *before* you run it:

> *"I'm about to open Xero in your browser. Sign in with your Xero account, pick which organisation you want to connect, and click **Allow**. Your browser will show a success page when it's done — come back here when you see it."*

**Handle common failures:**

| Failure | Response |
|---|---|
| `EADDRINUSE` port 3000 | *"Something is already using port 3000 on your machine. Can you close any other local dev servers and let me know when you're ready to try again?"* |
| "No response from browser after 2 minutes" | *"Looks like the sign-in didn't complete. Want me to try again? Or if the browser didn't open, I can give you the URL to paste manually."* |
| "invalid_client" / 401 | *"Xero rejected the credentials — usually this means the Client ID or Secret has a typo. Let's re-check them."* → go back to Step 5 |

On success, the auth script writes `xero-connector/.xero-token.json`. Verify the file exists and is non-empty before moving on. Report: *"✓ Signed in to Xero. Connected to **[organisation name]**."*

### Step 8 — Wire up the MCP server in `~/.claude.json`

Read `~/.claude.json` (create an empty JSON object if it doesn't exist). Add or update the `mcpServers.xero` entry:

```json
{
  "mcpServers": {
    "xero": {
      "command": "node",
      "args": ["<absolute-path-to>/xero-connector/src/index.js"]
    }
  }
}
```

**Platform note:** On Windows, the path must use escaped backslashes in JSON (`C:\\Users\\...`) or forward slashes. Use `Read` to load the current file, modify the JSON object, then `Write` it back. Do not clobber existing `mcpServers` entries — merge in the `xero` key alongside any others.

Report: *"✓ Added Xero to Claude Code's MCP server list."*

### Step 9 — Verify the connection

Run a quick smoke test by calling the MCP server directly. The cleanest way is to use `xero_get_organisation` once MCP is loaded — but since Claude needs a restart to pick up a new MCP server, fall back to running a one-shot verification via Node:

```bash
cd xero-connector && node -e "
import('./src/auth.js').then(async (_) => {
  const { XeroClient } = await import('xero-node');
  const fs = await import('fs');
  const token = JSON.parse(fs.readFileSync('.xero-token.json', 'utf8'));
  const env = fs.readFileSync('.env', 'utf8');
  const id = /XERO_CLIENT_ID=(.+)/.exec(env)[1].trim();
  const secret = /XERO_CLIENT_SECRET=(.+)/.exec(env)[1].trim();
  const client = new XeroClient({ clientId: id, clientSecret: secret, redirectUris: ['http://localhost:3000/callback'], scopes: ['accounting.settings'] });
  await client.setTokenSet(token);
  await client.updateTenants();
  console.log('OK:', client.tenants[0]?.tenantName || 'unknown');
}).catch(e => { console.error('FAIL:', e.message); process.exit(1); });
"
```

If the command prints `OK: <org name>`, verification passed.

If verification fails, diagnose the error and offer to rerun Step 7 (re-auth).

### Step 10 — Report success

Say something like:

> *"✓ You're connected! Here's what's set up:*
>
> *• Organisation: **[name]***
> *• Xero MCP server wired into Claude Code*
> *• Credentials stored locally (gitignored)*
>
> *Restart Claude Code to activate the Xero tools. After restart, try asking me things like:*
>
> *• "Show me my recent Xero invoices"*
> *• "What's my profit and loss this month?"*
> *• "List my Xero contacts"*
>
> *You won't need to repeat any of this — the token refreshes automatically."*

Mark Phase 1 as done. From this point on, the skill runs in Phase 2 mode.

### Recovery paths

If the user comes back later and one of the readiness checks fails (token expired, credentials deleted, MCP entry missing), jump back to the specific step that needs rerunning — you don't need to walk through the whole phase again.

- **Token expired** → Step 7 (re-auth)
- **Credentials missing/wrong** → Step 5 + Step 6
- **MCP entry missing** → Step 8
- **Dependencies missing** → Step 4

---

## Phase 2 — Everyday Use

All tools below are available after Phase 1 is complete and Claude Code has been restarted.

### xero_get_organisation

Get the name and details of the connected Xero organisation.

**Use when:** The user asks "what Xero account am I connected to?" or you need to confirm the connection is working.

**Example:**
```
User: "What Xero org am I connected to?"
→ Call xero_get_organisation
→ "You're connected to Demo Company (AU)."
```

---

### xero_list_invoices

List invoices in Xero. Supports filtering by status and searching by contact name or invoice number.

**Parameters:**
- `status` — Filter by: `DRAFT`, `SUBMITTED`, `AUTHORISED`, `PAID`, `VOIDED`
- `page` — Page number (100 invoices per page, default 1)
- `search` — Search by contact name or invoice number

**Use when:** The user asks to see invoices, unpaid invoices, overdue invoices, or invoices for a specific client.

**Examples:**
```
User: "Show me my unpaid invoices"
→ Call xero_list_invoices with status: "AUTHORISED"

User: "Find invoices for Acme Corp"
→ Call xero_list_invoices with search: "Acme Corp"

User: "Show me all draft invoices"
→ Call xero_list_invoices with status: "DRAFT"
```

---

### xero_get_invoice

Get a specific invoice by its Xero ID or invoice number.

**Parameters:**
- `invoice_id` (required) — Xero invoice ID (UUID) or invoice number (e.g. INV-0001)

**Use when:** The user asks for details about a specific invoice, including line items, amounts, and tax.

**Example:**
```
User: "Show me invoice INV-0042"
→ Call xero_get_invoice with invoice_id: "INV-0042"
```

---

### xero_create_invoice

Create a new DRAFT invoice in Xero.

**Parameters:**
- `contact_name` (required) — Customer name
- `description` (required) — Line item description
- `unit_amount` (required) — Price per unit excluding tax
- `quantity` — Quantity (default: 1)
- `account_code` — Account code (e.g. 200 for Sales). Use `xero_list_accounts` to find codes.
- `due_date` — Due date in YYYY-MM-DD format
- `currency_code` — Currency: AUD, NZD, USD, etc.
- `reference` — Optional reference or PO number

**Use when:** The user asks to create, draft, or make an invoice.

**Important:** Always create as DRAFT. Never auto-approve invoices. Tell the user to review and approve in Xero.

**Example:**
```
User: "Create an invoice for Acme Corp for $500 for consulting"
→ Call xero_create_invoice with:
    contact_name: "Acme Corp"
    description: "Consulting services"
    unit_amount: 500
→ "I've created a draft invoice for Acme Corp for $500.
   It's saved as a draft — review and approve it in Xero when ready."
```

**If you don't know the account code**, call `xero_list_accounts` first to find the right one, then create the invoice.

---

### xero_list_contacts

List contacts (customers and suppliers) in Xero.

**Parameters:**
- `search` — Search by name or email address
- `page` — Page number (100 contacts per page)

**Use when:** The user asks to find a customer, supplier, or contact.

**Example:**
```
User: "Find John Smith in my Xero contacts"
→ Call xero_list_contacts with search: "John Smith"
```

---

### xero_create_contact

Create a new contact (customer or supplier) in Xero.

**Parameters:**
- `name` (required) — Contact display name
- `email` — Email address
- `phone` — Phone number
- `is_customer` — Mark as customer (default: true)
- `is_supplier` — Mark as supplier

**Use when:** The user asks to add a new customer or supplier.

**Example:**
```
User: "Add a new contact called ABC Pty Ltd with email info@abc.com"
→ Call xero_create_contact with:
    name: "ABC Pty Ltd"
    email: "info@abc.com"
```

---

### xero_list_accounts

List the chart of accounts in Xero. Returns account codes and names.

**Parameters:**
- `type` — Filter by type: `BANK`, `CURRENT`, `EQUITY`, `EXPENSE`, `FIXED`, `LIABILITY`, `PREPAYMENT`, `REVENUE`, `SALES`, `TERMLIABILITY`

**Use when:** The user asks about their chart of accounts, or you need to find the right account code for creating an invoice.

**Examples:**
```
User: "List my Xero expense accounts"
→ Call xero_list_accounts with type: "EXPENSE"

User: "What account code should I use for sales?"
→ Call xero_list_accounts with type: "REVENUE"
```

---

### xero_list_banktx

List bank transactions in Xero.

**Parameters:**
- `page` — Page number (100 transactions per page)

**Use when:** The user asks about bank transactions, bank feeds, or money in/out.

**Example:**
```
User: "Show me my recent bank transactions in Xero"
→ Call xero_list_banktx
```

---

### xero_list_payments

List payments recorded in Xero against invoices or bills.

**Parameters:**
- `page` — Page number (100 payments per page)

**Use when:** The user asks about payments received or made.

**Example:**
```
User: "Show me recent payments in Xero"
→ Call xero_list_payments
```

---

### xero_get_profit_loss

Get the Profit and Loss (Income Statement) report.

**Parameters:**
- `from_date` — Start date YYYY-MM-DD (default: 1 Jan of current year)
- `to_date` — End date YYYY-MM-DD (default: today)

**Use when:** The user asks about income, expenses, net profit, or P&L.

**Examples:**
```
User: "Show me the P&L for this year"
→ Call xero_get_profit_loss (defaults to Jan 1 to today)

User: "What was my profit and loss for March?"
→ Call xero_get_profit_loss with from_date: "2026-03-01", to_date: "2026-03-31"
```

---

### xero_get_balance_sheet

Get the Balance Sheet report showing assets, liabilities, and equity.

**Parameters:**
- `date` — Report date YYYY-MM-DD (default: today)

**Use when:** The user asks about their balance sheet, assets, liabilities, or equity position.

**Example:**
```
User: "Get my balance sheet as of today"
→ Call xero_get_balance_sheet
```

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Xero account" | Phase 1 |
| "Set up Xero" | Phase 1 |
| "Show me my invoices" | `xero_list_invoices` |
| "List unpaid invoices" | `xero_list_invoices` with status: `AUTHORISED` |
| "Show me invoice INV-0042" | `xero_get_invoice` |
| "Create an invoice for [client]" | `xero_create_invoice` |
| "Find [name] in my contacts" | `xero_list_contacts` with search |
| "Add a new contact" | `xero_create_contact` |
| "Show me my accounts" | `xero_list_accounts` |
| "List my bank transactions" | `xero_list_banktx` |
| "Show me recent payments" | `xero_list_payments` |
| "Profit and loss for this year" | `xero_get_profit_loss` |
| "Get the balance sheet" | `xero_get_balance_sheet` |
| "What Xero org am I connected to?" | `xero_get_organisation` |

---

## Error Handling (Phase 2)

When a Xero tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| "Not authenticated with Xero" | "Your Xero connection needs a refresh. Let me reconnect." | Jump to Phase 1, Step 7 |
| "Token expired and refresh failed" | "Your Xero session has expired. Let me reconnect you." | Jump to Phase 1, Step 7 |
| "No Xero organisations found" | "I can't find a Xero organisation on your account. Let's reconnect and pick one." | Jump to Phase 1, Step 7 |
| "Missing XERO_CLIENT_ID" | "Your Xero credentials are missing. Let me help you set them up again." | Jump to Phase 1, Step 5 |
| "Invoice not found" | "I couldn't find that invoice. Let me search for it." | Try `xero_list_invoices` with search instead |
| Any other Xero API error | "Something went wrong with Xero. Let me try again." | Retry once, then jump to Phase 1, Step 7 if it persists |

---

## Scope Limitations

The Xero connector **can** do:
- Read and create invoices (accounts receivable)
- Read and create contacts
- Read chart of accounts
- Read bank transactions
- Read payments
- Read Profit & Loss reports
- Read Balance Sheet reports

The Xero connector **cannot** do:
- Access payroll or employee data
- Access Xero files or attachments
- Delete or void invoices (create as DRAFT — user approves in Xero)
- Create or reconcile bank transactions
- Manage tax rates or tax returns
- Access projects, fixed assets, or budgets
- Send invoices by email (user does this in Xero)
- Access multiple organisations simultaneously (connected to one at a time)

---

## Behaviour Guidelines

- **The conversation is the install experience.** During Phase 1, never tell the user to "run this command" or "open this script." You run commands via Bash; the user only provides values and answers.
- **Always confirm before creating.** When creating invoices or contacts, summarise what you are about to create and confirm with the user before calling the tool.
- **Invoices are always DRAFT.** Never imply an invoice has been sent or approved. Say "I've created a draft invoice — review and approve it in Xero."
- **Format currency correctly.** Use the currency from the Xero response (AUD, NZD, USD, etc.) and format amounts with 2 decimal places.
- **Present reports clearly.** When showing P&L or Balance Sheet, format as a readable table, not raw JSON.
- **One step at a time.** Do not dump all data at once. Summarise first, then offer to show details.
- **Never log or echo credentials.** Client ID, Client Secret, and tokens must never appear in output, error messages, or any reply to the user.
- **On token errors, re-auth silently.** Jump to Phase 1, Step 7 without making a big deal of it. The user should experience a short pause and a "reconnected" message, not a wall of technical output.

---

## Related Skills

- **systematic-debugging**: For troubleshooting Xero auth or API errors
- **first-run-setup**: Conversational install pattern — same model, applied at workshop-kit scale
- **connector-recommender**: For recommending which connectors to set up
