---
name: quickbooks-connector
description: "Read and update QuickBooks Online accounting data via the qbo CLI (github.com/voska/qbo-cli). Handles invoices (list, view, create, filter by status), customers (list, create), the chart of accounts, bank transactions, customer payments, the Profit and Loss report, the Balance Sheet, and company information. Supports sandbox only — production is out of scope. Use this skill when the user asks about their QuickBooks, QBO, invoices, unpaid invoices, overdue invoices, customers, profit and loss, balance sheet, bank transactions, chart of accounts, payments received, or when they say 'connect my QuickBooks' or 'help me set up QuickBooks'. On the first use of any QuickBooks feature, run Phase 1 to install qbo and authenticate before attempting any tool calls."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - quickbooks
    - qbo
    - accounting
    - invoices
    - customers
    - finance
    - cli
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting qbo auth or API errors
    - skill: xero-connector
      reason: Sibling accounting connector — similar conversational bootstrap pattern for a different platform
---

# QuickBooks Connector

## Overview

This skill lets you read and update a user's QuickBooks Online data on their behalf. It is a **thin Bash wrapper around [`voska/qbo-cli`](https://github.com/voska/qbo-cli)** — a single-binary Go CLI with structured JSON output, machine-readable exit codes, and OS-keyring token storage. There is no MCP server, no Node.js layer, and no wrapper code in this repo.

The skill has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap. The user has never used this before. You walk them through it one step at a time, doing all the technical work silently and only asking the user for things that genuinely require them (their credentials, their consent in the browser). The user should never see the words "binary", "PATH", "env var", "Homebrew", "Scoop", "keyring", or any file paths. At the end, `qbo auth status` reports a valid session and `qbo company info --sandbox --json` returns the user's sandbox company.
- **Phase 2 — Use Tools.** Once qbo is installed and authenticated, you shell out to `qbo` via Bash to answer questions and make changes. This skill documents the 10 most common workshop prompt patterns. For advanced entities (bills, vendors, estimates, journal entries, budgets, etc.) delegate to the official `voska/qbo-cli` skill installed in Phase 1 Step 3.

**Which phase to run** — Before any tool call, check whether qbo is installed and authenticated. Run:

```bash
qbo auth status 2>&1
```

- Exit code 0 → authenticated. Go to Phase 2.
- Exit code 4 (`auth_required`) or exit code 127 (`command not found`) → run Phase 1 from the appropriate step.
- Any other exit → translate the error, diagnose, run Phase 1 if needed.

**Sandbox only.** This skill supports QuickBooks Online sandbox only. Production requires Intuit app assessment and a non-localhost redirect URI, which is out of scope for the workshop.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md` — in particular:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say CLI, binary, PATH, env var, export, Homebrew, Scoop, keyring, keychain, OAuth, scope, token, callback, redirect URI, or realmId. If you must refer to a technical thing, name it plainly: "the QuickBooks tool I need", "your browser", "a small file on your computer".
- **Tell them what is about to happen.** Before any action: "I am going to install a small tool I need to talk to QuickBooks — this takes about one minute."
- **React to success and failure warmly.** Good: "That worked — your QuickBooks is now connected." Bad: "exit 4 auth_required."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem at all — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth

This phase installs the `qbo` binary, installs the official `voska/qbo-cli` skill as a reference, collects the user's Intuit developer credentials, runs the browser sign-in, and verifies the connection.

### Step 1 — Check if qbo is already installed

Silently run:

```bash
qbo --version 2>&1
```

- If it prints a version string → "Good news — the QuickBooks tool is already on your computer." Skip to Step 3.
- If it errors with "command not found" (exit 127) → Move to Step 2.
- Any other error → translate and continue to Step 2 (re-install is the safest path).

### Step 2 — Install the qbo tool

Tell the user: "I am going to install a small tool I need to talk to QuickBooks — this will take about one minute."

Silently detect the user's OS. Run the install command for that platform:

**macOS (Intel or Apple Silicon):**
```bash
brew install voska/tap/qbo
```
- Success → Step 3.
- "brew: command not found" → Homebrew is missing. Tell the user: "I need to install a helper first — it takes about two extra minutes." Install Homebrew via:
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
  Then retry `brew install voska/tap/qbo`. If Homebrew install fails on a corporate laptop (common), fall back to the binary download path below.

**Linux:**
```bash
brew install voska/tap/qbo
```
- If Homebrew isn't present, fall back to:
  ```bash
  go install github.com/voska/qbo-cli/cmd/qbo@latest
  ```
  (If Go isn't present either, fall back to the binary download path below.)

**Windows (Git Bash):**
```bash
scoop bucket add voska https://github.com/voska/scoop-bucket && scoop install qbo
```
- "scoop: command not found" → Scoop is missing. **Do not try to install Scoop automatically** — it requires PowerShell and user elevation. Fall straight through to the binary download path below.

**Binary download fallback (any platform, when the package manager path fails):**

Fetch the latest release metadata from GitHub to find the right asset for the user's OS and architecture:

```bash
curl -s https://api.github.com/repos/voska/qbo-cli/releases/latest
```

Parse the JSON and pick the asset whose name matches the user's platform:

| OS | Arch | Asset name pattern |
|---|---|---|
| Windows | x64 | `qbo_windows_amd64.zip` or `qbo_windows_amd64.exe` |
| macOS | Intel | `qbo_darwin_amd64.tar.gz` |
| macOS | Apple Silicon | `qbo_darwin_arm64.tar.gz` |
| Linux | x64 | `qbo_linux_amd64.tar.gz` |
| Linux | arm64 | `qbo_linux_arm64.tar.gz` |

Download the asset, extract the `qbo` binary, place it in a directory on the user's PATH:
- Mac/Linux: `~/.local/bin/qbo` (create the dir if needed; ensure it's on PATH via `~/.zshrc` or `~/.bashrc` append)
- Windows: `~/bin/qbo.exe` (create via `mkdir -p ~/bin`; Git Bash picks up `~/bin` automatically from the Windows PATH if the user has it; otherwise fall back to placing it in a directory you know is on PATH, such as `~/AppData/Local/Microsoft/WindowsApps/`)

After placing the binary, `chmod +x` it on Mac/Linux and verify:

```bash
qbo --version 2>&1
```

- Version string → "That worked." Step 3.
- Still not found → tell the user: "I couldn't install the QuickBooks tool automatically on your computer. It usually means something on your system is blocking downloads. Can you let me know if you're on a work laptop?" Then ask them to try from a home network, or escalate.

### Step 3 — Install the official qbo skill (best-effort)

The qbo CLI project publishes its own Claude Code skill that documents every command and supported entity. Installing it gives Claude a second reference for advanced patterns beyond the 10 common ones this skill covers.

Silently run:

```bash
npx skills add -g voska/qbo-cli 2>&1
```

- Success → "Good. I've added extra QuickBooks knowledge to myself." Step 4.
- Any failure → **ignore it silently** and continue to Step 4. This step is best-effort. Do not tell the user it failed. The skill works fine without it — this skill file has enough information to cover the common workshop prompts.

### Step 4 — Walk the user through creating an Intuit developer app

The user needs to do one manual thing: create a free developer app in their Intuit account and copy two values out of it. You cannot do this step for them — Intuit requires their authenticated session.

Tell the user (spread across a few short messages, one instruction at a time):

1. "QuickBooks needs me to register with them as an app. This is free and takes about three minutes."
2. "Please open https://developer.intuit.com and sign in with your Intuit account. Let me know when you are signed in."
3. "Click **My Hub** at the top, then **App Dashboard**, then **Create an app**. Tell me when you see the list of app types."
4. "Choose **QuickBooks Online and Payments**. For app name, type: **Claude Assistant**. Tick the box next to **com.intuit.quickbooks.accounting**. Then click **Create app**."
5. "On the left menu, click **Settings**, then **Redirect URIs**. Make sure you are on the **Development** tab (not Production)."
6. "Click **Add URI** and paste this exactly: `http://localhost:8844/callback`. Click **Save**."
7. "On the left, click **Keys and credentials**, on the **Development** tab, then **Show credentials**."
8. "Please copy your **Client ID** and paste it to me."
9. When they paste it → "Thanks. Now please copy your **Client Secret** and paste it to me."
10. Both received → Step 5.

Important redirect URI note: qbo uses **port 8844**, not 3000. If the user previously used a different QuickBooks tool and already has a `:3000/callback` redirect registered, they need to **add** the `:8844/callback` URI (not replace the existing one). Both can coexist on the same Intuit app.

Common mistakes to look out for (and correct silently by re-asking):
- The user pasted the placeholder `your_client_id_here` → ask again.
- The user pasted something very short (under 20 characters) → probably not the real credential. Ask again.
- The user added the redirect URI on the Production tab instead of Development → tell them: "One small thing — the web address I gave you needs to go on the tab that says Development, not Production. Can you move it across?"

### Step 5 — Save the credentials

The `qbo` tool reads client credentials from the environment variables `QBO_CLIENT_ID` and `QBO_CLIENT_SECRET`. For persistence across sessions (so the user does not have to re-enter them every time Claude Code starts), write them to a small file you will source before every qbo command:

Silently create `~/.config/qbo/credentials.env` with contents:

```
QBO_CLIENT_ID=<value from Step 4>
QBO_CLIENT_SECRET=<value from Step 4>
```

Create the directory first if it does not exist:

```bash
mkdir -p ~/.config/qbo
```

Set restrictive permissions on the file (Mac/Linux):

```bash
chmod 600 ~/.config/qbo/credentials.env
```

Never echo the Client ID or Client Secret back to the user after writing them. Never include them in any output visible to the user.

For every subsequent qbo invocation in Phase 1 and Phase 2, **always source this file first** so the env vars are set for the child process:

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo <command>
```

This pattern is required. `qbo` will error with exit code 10 (`config_error`) if `QBO_CLIENT_ID` is missing from its environment.

### Step 6 — Browser sign-in

Tell the user: "I am going to open QuickBooks in your browser now. Please sign in with your Intuit account, choose your practice company, and click the blue **Connect** button. Then come back here."

Silently run:

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo auth login --sandbox
```

`qbo auth login --sandbox` starts a local web server on port 8844, opens the user's browser to the Intuit consent page, waits for them to click Connect, captures the callback, and stores the resulting tokens in the OS keyring (macOS Keychain, Windows Credential Manager, or `~/.config/qbo/tokens/` fallback). Exit code 0 means success.

- Exit 0 → "Your QuickBooks is signed in. Nearly done." Step 7.
- Exit 4 (`auth_required`) persists after login → the OAuth flow failed. Check the stderr for the actual reason:
  - "port 8844 in use" → tell the user: "Something else on your computer is using the channel I need. Please close any other apps that might be running a local web server and tell me when you have done so." Retry.
  - "invalid_client" → credentials are wrong. Go back to Step 4 and ask the user to re-paste the Client ID and Secret.
  - "redirect_uri_mismatch" → the user missed adding `http://localhost:8844/callback` to their Intuit app, or added it on the wrong tab. Walk them back through Step 4 parts 5–6.
- User says "my browser didn't open" → re-run with the `--manual` flag:
  ```bash
  set -a && source ~/.config/qbo/credentials.env && set +a && qbo auth login --sandbox --manual
  ```
  This prints the auth URL instead of opening a browser. Paste the printed URL back to the user as a clickable link: "Please click this link to sign in to QuickBooks, and copy the full URL of the page it takes you to after you click Connect. Then paste that URL back to me." Feed the pasted URL to qbo as instructed by its prompt.
- User says "I don't want to do this right now" / "I cancelled" → "No problem — we can try again whenever you're ready."

### Step 7 — Verify the connection

Tell the user: "Let me just double-check everything is talking to QuickBooks correctly."

Silently run two verification commands in sequence:

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo auth status 2>&1
```

- Exit 0 → authenticated. Continue.
- Any other exit → diagnose and retry Step 6.

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo company info --sandbox --json
```

- Exit 0 and valid JSON in stdout → parse the `CompanyName` field. That's what you show the user in Step 8.
- Exit 4 → token got invalidated between login and verify. Retry Step 6.
- Exit 5 (`not_found`) or "no company ID" → the sandbox company needs to be selected. Run:
  ```bash
  set -a && source ~/.config/qbo/credentials.env && set +a && qbo company list --sandbox --json
  ```
  If there's exactly one company, run `qbo company switch <realm-id>` with its ID. If there are multiple, tell the user "You have more than one practice company — which one would you like me to use?" and list them by name.
  If there are zero, the user has not created a sandbox company at developer.intuit.com. Tell them: "You need to create a practice company first. Please go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds, then tell me to try again."

### Step 8 — Success message

Tell the user, in one short message:

> "All done. I am now connected to your QuickBooks practice company **[company name]**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this month?'."

Save to memory that the qbo CLI is installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once qbo is installed and authenticated, shell out to it via Bash to answer questions and make changes. **Every Phase 2 command must be prefixed with the credentials source line**:

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo <command>
```

For brevity, the recipes below omit the prefix — but you must include it in every actual Bash invocation.

### Common Pattern 1 — List recent invoices

```bash
qbo list invoices --sandbox --json --results-only
```

Returns an array of invoice objects. Fields of interest: `Id`, `DocNumber`, `CustomerRef.name`, `TxnDate`, `DueDate`, `TotalAmt`, `Balance`, `CurrencyRef.value`.

**Use when:** The user asks "show me my invoices", "recent invoices", "latest invoices".

### Common Pattern 2 — List unpaid / overdue invoices

```bash
qbo list invoices --where "Balance > '0'" --sandbox --json --results-only
```

Returns only invoices with an outstanding balance. Derive "overdue" vs "pending" client-side by comparing `DueDate` to today.

**Use when:** The user asks "show me unpaid invoices", "what invoices are overdue?", "who owes me money?".

### Common Pattern 3 — Get a specific invoice by ID

```bash
qbo get invoice <id> --sandbox --json
```

Response is wrapped: `{"Invoice": {...}}`. Pipe through `jq '.Invoice'` to unwrap:

```bash
qbo get invoice 145 --sandbox --json | jq '.Invoice'
```

Line items are in the `Line` array. `SalesItemLineDetail` line types contain the billable amounts.

**Use when:** The user asks "show me invoice 145" or "details of invoice INV-1022". (QuickBooks uses numeric `Id` internally; `DocNumber` like "1022" is the user-facing label. If the user gives a `DocNumber`, first run `qbo list invoices --where "DocNumber = '1022'" --sandbox --json --results-only` to get the `Id`.)

### Common Pattern 4 — Create an invoice

Creating an invoice requires a customer (auto-create if missing) and at least one Product/Service Item. Confirm all details with the user in plain English before building the JSON.

Steps:

1. **Find or create the customer:**
   ```bash
   qbo list customers --where "DisplayName = 'Acme Corp'" --sandbox --json --results-only
   ```
   If empty, create one:
   ```bash
   echo '{"DisplayName":"Acme Corp"}' | qbo create customer -f - --sandbox --json
   ```
   Capture `Customer.Id` from the wrapped response.

2. **Find a default Product/Service Item** (QuickBooks requires one on every invoice line):
   ```bash
   qbo list items --sandbox --json --results-only
   ```
   Pick the first active item. Capture its `Id` and `Name`. If zero items exist, tell the user: "Before I can create invoices, QuickBooks needs at least one product or service in your company. Please open QuickBooks, go to Sales then Products and Services, create a basic service item, and tell me when it is done."

3. **Build and submit the invoice JSON:**
   ```bash
   echo '{
     "CustomerRef": {"value": "<customer-id>"},
     "Line": [{
       "Amount": 500,
       "DetailType": "SalesItemLineDetail",
       "Description": "Consulting services",
       "SalesItemLineDetail": {
         "ItemRef": {"value": "<item-id>"},
         "Qty": 1,
         "UnitPrice": 500
       }
     }]
   }' | qbo create invoice -f - --sandbox --json
   ```

   Optional top-level fields: `"DueDate": "2026-05-01"`, `"DocNumber": "INV-1042"`.

After the command returns, tell the user: "I've saved an invoice for **[Customer]** for **$[Amount]**. Review and send it from QuickBooks when ready." — never imply the invoice has been emailed.

### Common Pattern 5 — List customers

```bash
qbo list customers --sandbox --json --results-only
```

To search by name:

```bash
qbo list customers --where "DisplayName LIKE '%Smith%'" --sandbox --json --results-only
```

Fields of interest: `Id`, `DisplayName`, `PrimaryEmailAddr.Address`, `PrimaryPhone.FreeFormNumber`, `Balance`, `Active`.

**Use when:** The user asks "show me my customers", "find [name]", "list active customers".

### Common Pattern 6 — Create a customer

```bash
echo '{"DisplayName":"ABC Pty Ltd","PrimaryEmailAddr":{"Address":"info@abc.com"},"PrimaryPhone":{"FreeFormNumber":"+61 412 345 678"}}' \
  | qbo create customer -f - --sandbox --json
```

Only `DisplayName` is required. Email and phone are optional.

### Common Pattern 7 — List accounts (chart of accounts)

```bash
qbo list accounts --sandbox --json --results-only
```

Filter by type:

```bash
qbo list accounts --where "AccountType = 'Expense'" --sandbox --json --results-only
qbo list accounts --where "AccountType = 'Bank'" --sandbox --json --results-only
```

Valid `AccountType` values: `Bank`, `Accounts Receivable`, `Income`, `Expense`, `Cost of Goods Sold`, `Fixed Asset`, `Other Asset`, `Credit Card`, `Accounts Payable`, `Long Term Liability`, `Equity`.

### Common Pattern 8 — Bank transactions (purchases)

```bash
qbo list purchases --sandbox --json --results-only
```

QuickBooks models bank transactions as `Purchase` (money out) and `Deposit` (money in) entities. To get both money flows, run both and merge client-side:

```bash
qbo list purchases --sandbox --json --results-only
qbo list deposits --sandbox --json --results-only
```

Fields: `Id`, `TxnDate`, `EntityRef.name` (payee), `AccountRef.name`, `TotalAmt`, `CurrencyRef.value`.

### Common Pattern 9 — Profit and Loss report

```bash
qbo report profit-and-loss --sandbox --json
```

With a date range:

```bash
qbo report profit-and-loss --start-date 2026-01-01 --end-date 2026-12-31 --sandbox --json
```

Default date range is from 1 Jan of the current year to today. Response shape is `{"Header": {...}, "Rows": {...}}` — the `Rows.Row` tree is nested and needs recursive walking to flatten into a display table.

Present to the user as a clean table with sections (Income, Cost of Goods Sold, Gross Profit, Expenses, Net Income) — never as raw JSON.

### Common Pattern 10 — Balance Sheet report

```bash
qbo report balance-sheet --sandbox --json
```

With a specific as-of date:

```bash
qbo report balance-sheet --end-date 2026-04-14 --sandbox --json
```

Same nested response shape as Profit and Loss. Present as Assets / Liabilities / Equity sections.

---

## Advanced Entities — Delegate to the Official Skill

This skill documents the 10 most common workshop prompts. The `qbo` CLI supports full CRUD on **29 entities**: Account, Bill, BillPayment, Budget, Class, CompanyInfo, CreditMemo, Customer, Department, Deposit, Employee, Estimate, Invoice, Item, JournalEntry, Payment, PaymentMethod, Preferences, Purchase, PurchaseOrder, RefundReceipt, SalesReceipt, TaxCode, TaxRate, Term, TimeActivity, Transfer, Vendor, VendorCredit.

If the user asks about any entity not covered above (bills, vendors, estimates, journal entries, credit memos, sales receipts, time activities, transfers, etc.), **consult the official `voska/qbo-cli` skill installed in Phase 1 Step 3** — it documents every entity and every report type. You can also introspect at runtime:

```bash
qbo schema --json              # Full CLI tree with all entities
qbo schema get --json          # Schema for the get command specifically
qbo list <entity> --sandbox --json --results-only
```

---

## Prompt-to-Command Mapping

| What the user says | Command |
|---|---|
| "Show me my invoices" | `qbo list invoices --sandbox --json --results-only` |
| "List unpaid invoices" | `qbo list invoices --where "Balance > '0'" --sandbox --json --results-only` |
| "Show me invoice 1022" | `qbo get invoice <id> --sandbox --json \| jq '.Invoice'` |
| "Create an invoice for [client]" | Pattern 4 above |
| "Find [name] in my customers" | `qbo list customers --where "DisplayName LIKE '%<name>%'" --sandbox --json --results-only` |
| "Add a new customer" | `qbo create customer -f - --sandbox --json` with JSON via echo |
| "Show me my accounts" | `qbo list accounts --sandbox --json --results-only` |
| "List my bank transactions" | `qbo list purchases` + `qbo list deposits`, merge |
| "Show me recent payments" | `qbo list payments --sandbox --json --results-only` |
| "Profit and loss for this year" | `qbo report profit-and-loss --sandbox --json` |
| "Get the balance sheet" | `qbo report balance-sheet --sandbox --json` |
| "What QuickBooks company am I connected to?" | `qbo company info --sandbox --json` |
| "Connect my QuickBooks" / "Help me set up QuickBooks" | **Run Phase 1** |

---

## Exit Code Handling

`qbo` uses structured exit codes for machine-readable error handling. Every Phase 2 invocation should check the exit code and respond accordingly:

| Code | Name | What it means | How to respond |
|---|---|---|---|
| 0 | `success` | Operation completed | Parse stdout, present to user |
| 1 | `error` | General error | Translate stderr to plain English; retry once if likely transient |
| 2 | `usage` | Invalid arguments | Bug in the command you constructed; diagnose and fix |
| 3 | `empty` | No results | **Not an error.** Tell the user "I didn't find any [invoices/customers/etc.] matching that." Do not retry. |
| 4 | `auth_required` | Token expired or missing | **Run Phase 1 from Step 6** — re-do the browser sign-in. Do not ask the user to run anything; you run it. |
| 5 | `not_found` | Resource not found (e.g. invoice ID doesn't exist) | Tell the user "I couldn't find [resource]. Let me list the recent ones so you can pick." Then run a list command. |
| 6 | `forbidden` | Permission denied (rare on sandbox) | Translate: "QuickBooks says I don't have permission for that. This is unusual on a practice company — let me reconnect you." Run Phase 1 from Step 6. |
| 7 | `rate_limited` | API rate limit exceeded | Wait 30 seconds, then retry once. If still rate-limited, tell the user: "QuickBooks is asking me to slow down. Let me wait a minute and try again." |
| 8 | `retryable` | Transient error | **Automatically retry once** after a 2-second delay. If still failing, translate and continue as a regular error. |
| 10 | `config_error` | Missing/invalid config (e.g. `QBO_CLIENT_ID` not set) | You forgot to source `~/.config/qbo/credentials.env` in the Bash call. Fix the command and retry. If the file is missing entirely, run Phase 1 from Step 5. |

When in doubt, translate stderr to plain English, tell the user what you're doing next, and re-run or fall back to Phase 1 as appropriate. Never show raw exit codes or stderr to the user.

---

## Scope Limitations

The qbo connector **can** read and write: invoices, customers, accounts, bank transactions (purchases and deposits), customer payments, items, reports (P&L, Balance Sheet, and 4 others), and company info. It can also full-CRUD on 20+ additional entities via the official voska skill.

It **cannot** access:
- **Production QuickBooks companies** — this skill is sandbox only. Production requires Intuit app assessment and a non-localhost redirect URI, which is out of scope for the workshop.
- Payroll or employee payroll data
- QuickBooks Payments processing (credit card processing)
- File attachments
- Sending invoices by email (user does this in QuickBooks)
- Bank reconciliation / bank feed matching

It **requires** at least one Product/Service Item to exist in the company before creating an invoice. Auto-picks the first available Item if the user doesn't specify one.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating** invoices or customers — summarise what you are about to create and wait for the user's OK before calling the tool.
- **Invoices are saved, not emailed** — never imply an invoice has been sent. Say "I've saved the invoice in QuickBooks — review and send it from QuickBooks when ready."
- **Customer auto-creation** — when creating an invoice for a new customer, tell the user a new customer was created alongside the invoice.
- **Always prefix qbo calls** with `set -a && source ~/.config/qbo/credentials.env && set +a &&` — never call `qbo` without sourcing the credentials file first. `qbo` will exit 10 (`config_error`) if you forget.
- **Always use `--json --results-only`** on list commands when you're going to parse the output — it strips the QBO pagination wrapper and gives you a clean array.
- **Unwrap `get` responses** — they come back as `{"Invoice": {...}}`. Pipe through `jq '.Invoice'` (or the relevant entity key) to get the flat object.
- **Format currency correctly** — 2 decimal places, use the currency from the QuickBooks response.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as readable tables, not raw JSON.
- **Sandbox awareness** — remind the user gently, when relevant, that they are looking at practice data, not real figures. Say "practice company" when referring to the sandbox, not "sandbox".
- **Token errors (exit 4)** → run Phase 1 from Step 6. Do not ask the user to "run a command" — you run it.
- **Never log or echo credentials** — Client ID, Client Secret, and token values must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap
- **systematic-debugging**: For troubleshooting qbo auth or API errors
- **xero-connector**: Sibling accounting connector for Xero users — same bootstrap pattern
- **voska/qbo-cli** (external, installed in Phase 1 Step 3): Comprehensive reference for every qbo entity and command
