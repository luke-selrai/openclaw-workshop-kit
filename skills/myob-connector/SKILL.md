---
name: myob-connector
description: "Connect MYOB accounting to Claude by switching on its built-in connector, or by installing and authenticating its API credentials, for existing paid MYOB subscribers. Use when the user asks to set up or connect MYOB, or wants MYOB work (profit and loss, receivables, invoices, bills, contacts, payroll) and MYOB isn't connected yet. Once connected, MYOB runs through the mcp__claude_ai_MYOB__* tools, or directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__claude_ai_MYOB__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - myob
    - accounting
    - invoices
    - contacts
    - finance
    - australia
    - rest-api
    - oauth
  pairs-with:
    - skill: xero-connector
      reason: Sibling AU accounting connector - Xero is the larger market share, MYOB is #2 in AU SMB. Some attendees use one, some the other, some both.
    - skill: quickbooks-connector
      reason: Sibling accounting connector for the global market - same conversational install pattern.
    - skill: outlook-connector
      reason: Same Playwright-MCP-driven OAuth Auth Code flow pattern. Reference for the no-user-browser golden rule and Playwright fallback handling.
    - skill: superpowers:systematic-debugging
      reason: Use when MYOB API errors are unclear or when token refresh fails repeatedly.
---

# MYOB Connector

## Overview

This skill lets you read and update a user's MYOB accounting data on their behalf using **MYOB's direct REST API** (no MCP server, no CLI - see [issue #146](https://github.com/selrai-company/claude-workshop-kit/issues/146) for the architectural decision).

> **How this connector works (read this once before reading the rest):**
> The architecture is dead simple. Claude reads the user's saved tokens out of `~/.config/myob/tokens.json`, then runs `curl` against MYOB's REST endpoints - every API call carries the user's `Authorization: Bearer ...` token plus the workshop's `x-myobapi-key`. **The user's own paid MYOB subscription is what authorises the data access** - the workshop's developer credentials only authorise the *connection point*, not the data itself.
>
> Two paid layers exist; both are required for the connector to function:
>
> 1. **Workshop side (one-off, the workshop pays).** MYOB is the only connector in this kit with no free developer tier - API access requires Developer Program membership at AUD $110/month (incl. GST). The workshop covers this on behalf of all attendees and ships the resulting `client_id` / `client_secret` in `skills/myob-connector/.workshop-credentials` (gitignored). This is a fixed line item; attendees never see the credentials and never pay this fee.
> 2. **User side (recurring, the user pays).** Each attendee needs their own **paid MYOB Business or AccountRight subscription**. Free trials and accountant-only logins do **not** work. Without a real subscription, there's no company file for the connector to read, and OAuth will refuse to issue tokens. Same constraint as Xero/QuickBooks - the data lives in the user's account, so the user has to be the account holder.

### MYOB is built into Claude now - try that first

MYOB has its own listing in Claude's connector directory
(`https://claude.ai/directory/myob` - "MYOB", Verified, made by MYOB, added
July 2026, connector URL `https://mcp.myob.com/mcp`, sign-in required; docs at
`https://www.myob.com/au/support/myob-business/product-account/connecting-myob`).
The page notes it is **currently in beta**.

It is **read-only, and deliberately narrow** - MYOB describes it as *"a fast,
read-only view of your MYOB Business numbers, from profit and loss to sales,
receivables and payables"*. Six tools:

| Tool | Answers |
|---|---|
| `myob_get_profit_loss` | how the business is performing |
| `myob_get_outstanding_customer_balances` | who owes you money |
| `myob_get_outstanding_payables` | what you owe |
| `myob_get_sales_invoice_totals` | how much you've invoiced |
| `myob_get_standard_payment_terms` | the terms on file |
| `myob_get_financial_year_dates` | the financial year boundaries |

Switching it on is one button and a sign-in: nothing installed, no developer
credentials, no workshop fee, and nothing for this skill to store. **So it runs
first, and it answers the headline questions most users actually ask.**

Everything below - the workshop developer credentials, the $110/month tier, the
Playwright sign-in - is the kit's own route, and it is still the only way to reach
invoices, quotes, bills, contacts, items, banking and payroll in detail, and the
only way to write anything at all. Phase 0.5 routes between them.

It has three phases:

- **Phase 1 - Switch on the built-in MYOB connector.** One button, one sign-in,
  read-only.
- **Phase 1 (the kit's own route) - Install & Connect.** A conversational bootstrap (≤6 steps). The user has never used this before. You drive the entire OAuth flow inside a **Playwright MCP** browser, capture the access + refresh tokens, save them to `~/.config/myob/tokens.json`, and verify the connection with a live API ping. The user should never see the words "OAuth", "token", "client_id", "curl", "API", "JSON", or any file path. They should feel like they are having a conversation, and at the end their MYOB is connected.
- **Phase 2 - Use the connector.** Once tokens are saved, you call the MYOB REST API via `curl` (using the runtime loop in §Phase 2) to read and update MYOB data. Endpoints span Sales (invoices, quotes), Purchases (bills), Contacts (customer/supplier/employee), Inventory (items), Banking, General Ledger, and Payroll.

**Which phase to run** - Phase 0 decides, and it runs before everything else in
this file including the pre-flight credential check. A live built-in connection
counts as connected; so does a saved set of tokens. For the kit's own route the
token check is: `~/.config/myob/tokens.json` (Mac/Linux/WSL) or
`%APPDATA%\myob\tokens.json` (native Windows), containing a valid `access_token`
+ `refresh_token` + `company_file.uri`. If that is present, treat the connector as
configured and skip to Phase 2.

### What this skill does NOT use

- **An MCP server, on this route.** When this route was designed none existed for MYOB. That changed in July 2026: MYOB now publishes `https://mcp.myob.com/mcp`, which is what Claude's built-in MYOB connector uses (Phase 1) - but it is read-only and limited to six summary reports, so it cannot replace this route. CData also ships a third-party read-only MCP via JDBC; the Java runtime dependency + read-only limitation make it a poor fit for the workshop install bar. Direct REST remains the route for detail and for every write.
- **A first-party CLI** - MYOB doesn't ship one (unlike Google Workspace's `gws` or GitHub's `gh`).
- **Bearer-only auth** - MYOB requires *both* `Authorization: Bearer <token>` *and* `x-myobapi-key: <client_id>` on every API call. Most generic OAuth client implementations forget the second header and fail with confusing 401s. Always set both.
- **The `x-myobapi-cftoken` header** - only relevant for AccountRight cloud company files (legacy product line). MYOB Business doesn't need it. Document as a v2 gotcha; do not implement in v1.
- **`.env` files for token storage** - tokens rotate every 20 minutes. An env-var pattern would force a shell reload on each refresh. Tokens live in `~/.config/myob/tokens.json` (mode 0600), atomically rewritten on each refresh.

---

## Golden rule - do not open the user's own browser

Every OAuth step in Phase 1 runs inside the **Playwright MCP** browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the user to "open a link in your browser" for the my.MYOB sign-in step. Claude navigates, clicks, reads the redirected URL out of the address bar, and extracts the authorization code - the user's role is to type their my.MYOB password into the Playwright-controlled window.

If the Playwright MCP is unavailable, stop and tell the user plainly: *"I need a small browser tool that's not installed yet - let me show you how to add it."* Then point them at the Playwright MCP install instructions. Do not fall back to opening the user's default browser.

**Browser routing for the built-in connector.** Follow Phase 1's Desktop in-app-first route and account-matched browser handoff. Use available UI tools; ask the user only for input the harness cannot complete. The kit's separate credential-capture browser rules still apply to its own route.

---

## No-deviation rule

If a step in this skill fails, follow the `if X fails, try Y` branch documented for that step. **Do not improvise** with `gcloud`, `curl --user`, basic auth, or any other tool/auth scheme this skill does not name. If you hit a failure with no documented recovery, tell the user exactly what failed and stop - don't silently pivot.

---

## PHASE 0 - Is MYOB already connected?

Identify the calling surface first. Desktop's visible account, Connectors view, and actual runtime tools are its evidence. Terminal `claude auth status` and `claude mcp list` describe the CLI account, even when run from Desktop's Bash; they do not establish Desktop identity or access. MYOB credentials are independent of either Claude login. Discover existing tools and perform the read below for the intended vendor account before claiming a connection. Preserve a working route.

Run these silently, in order, and act on the first that answers. **This runs
before the pre-flight credential check below** - the built-in connector needs none
of the workshop's developer credentials, so a missing credential file must never
stop a user reaching it.

**1. Built-in connector.** In Desktop, discover this session's MYOB tools (including opaque-ID prefixes) and inspect the app's Connectors view. For a terminal/VS Code caller only, check the CLI listing below. Apply the response branches to the caller's own state; a missing CLI line does not establish Desktop state.

```bash
claude mcp list 2>&1 | grep -i "^claude.ai MYOB"
```

- Connected in the caller or tools present → the built-in is live. Prove it with one read
  (`mcp__claude_ai_MYOB__myob_get_financial_year_dates` is the cheapest;
  `myob_get_profit_loss` is the most convincing), then go to **Phase 0.5**: if
  what the user wants is inside the built-in's six tools, you are done - go to
  Phase 2. If it isn't, the kit's own route is needed as well.
- Reconnect or `! Needs authentication` → reconnect in the same caller's Connectors view. In Desktop, start inside the app; for a browser route, verify its Claude account matches the caller before opening `https://claude.ai/customize/connectors`. Complete MYOB sign-in and repeat the actual read.
- No usable built-in in the caller → continue to step 2; a missing CLI line alone says nothing about Desktop.

**2. The kit's own route.** Look for `~/.config/myob/tokens.json` (Mac/Linux/WSL)
or `%APPDATA%\myob\tokens.json` (native Windows) with a valid `access_token` +
`refresh_token` + `company_file.uri`. Present and pinging → say *"MYOB is already
connected"* and go to Phase 2. Do not set the built-in up on top of a working
connection.

**3. Nothing found** → **Phase 0.5**.

**No shell?** Runtime discovery and reads still apply. Skip unavailable command/file checks; only set up a connection if no working route is found, following the existing route-by-need rules.

---

## PHASE 0.5 - Route by need

Ask **one** plain-English question before setting anything up: *"What do you want
Claude to do with your MYOB?"* Offer the two shapes as examples - *"see how the
business is tracking, or work with individual invoices, bills and contacts?"* One
question, then act.

| What the user wants | Route |
|---|---|
| How is the business going - profit and loss | **Built-in** (Phase 1) |
| Who owes me money - outstanding customer balances | **Built-in** |
| What do I owe - outstanding payables | **Built-in** |
| How much have I invoiced - sales invoice totals | **Built-in** |
| Standard payment terms; financial-year dates | **Built-in** |
| Individual invoices, quotes, bills, orders | **The kit's own route** |
| Contacts (customers, suppliers, employees) in detail | **The kit's own route** |
| Items and inventory; banking lines; general ledger | **The kit's own route** |
| Payroll (AU) | **The kit's own route** |
| **Creating or changing anything at all** | **The kit's own route** - the built-in is read-only by design |

Rules:

- If the built-in covers what they asked for, stop there. It costs the user one
  click and nothing else; the kit's own route needs the workshop's developer
  credentials and a longer sign-in, and there is no reason to spend that when the
  question is "how did we do last quarter".
- Say in one line what you are *not* connecting and why, so they can ask later.
- Both routes can coexist on one machine. Never tear one down to set the other up.
- The built-in is in beta. If one of its six reads errors or returns nothing
  usable, that is a real failure, not a "connected" - fall through to the kit's
  own route and say so plainly.

---

## PHASE 1 - Switch on the built-in MYOB connector

One button and a sign-in, once per account. Read-only, and free on the workshop's
side.

### Step 1 - Check this session can see built-in connectors

In Desktop, use its visible signed-in account and Connectors view, then continue inside that app. The following auth/settings checks apply only to a terminal/VS Code caller, not Desktop:

```bash
claude auth status
```

`"authMethod": "claude.ai"` is the pass. Anything else - or
`disableClaudeAiConnectors: true` in `~/.claude/settings.json`, or
`ENABLE_CLAUDEAI_MCP_SERVERS=false` - means built-in connectors will not appear in
this session. Tell the user in one line that this copy of Claude is signed in a
different way, and go to the kit's own route.

### Step 2 - Open the connector page for them

Say: *"I'll open MYOB's connection page and handle the setup. I'll let you know if it needs you to sign in."*

**Desktop first:** use the app's **+ → Connectors → Browse connectors → MYOB → Connect** (or the equivalent visible Customize/Connectors menu). Keep the exact app-created browser handoff URL, including its parameters. Open it in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended MYOB account before approval. Do not replace it with a directory link from another Claude account.

**Terminal/VS Code or browser fallback:** open `https://claude.ai/directory/myob` in a browser whose Claude account matches the caller. Use `open` (Mac), `xdg-open` (Linux), or `start` (Windows) only after confirming that browser's account. If the page fails, use `https://claude.ai/customize/connectors` → **Browse** → search "MYOB" → **Connect** in that same account.

Drive navigation and approval with available UI tools. If a step requires user input or the harness has no suitable UI tool, give only the exact short next step; do not describe every click as inherently human-only.

### Step 3 - Wait

Complete the visible flow with available tools; wait for any sign-in input that requires the user.

### Step 4 - Verify

Check MYOB in Desktop's own Connectors view, or `claude mcp list` for a terminal/VS Code caller. Connected is registration evidence only; proceed to the real read in Step 5. Reconnect uses the same account's Connectors view. A missing CLI line says nothing about Desktop. If Desktop still lacks a connection completed through the browser directory, verify **Connected** in that browser's matching Claude account. Once that account check passes, rediscover Desktop's tools and use Step 5's one-time Desktop refresh if needed; do not repeat **Connect** to repair a stale app view. Return to Step 2 only when neither the caller's view nor the account-matched browser confirms a completed connection.

### Step 5 - Prove it

Call one real read - `mcp__claude_ai_MYOB__myob_get_financial_year_dates`, or
`myob_get_profit_loss` if you want the user to see something they recognise. Only
a real answer counts; a tool error is not "connected". These tools are often deferred in a session, so fetch the namespace first. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If tools are missing, first rediscover deferred tools and confirm the same caller account is connected; only then consider a stale session: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

### Step 6 - Hand off

Two lines: MYOB is connected, and three things they can ask for now ("how did we
do last quarter", "who still owes me money", "what am I due to pay"). Add one line
naming what this route can't do - it only reads, and it doesn't go down to
individual invoices or bills - and offer the fuller connection if they need it.

**Team or Enterprise accounts:** if the page shows **Request** instead of
**Connect**, the user's Claude administrator has to switch MYOB on for the
organisation first. Say so plainly and stop.

---

## ⛔ Pre-flight credential check - run this FIRST, before the safety gate

> **Scope: this gate guards the kit's own route only.** The built-in MYOB
> connector (Phase 1 above) needs none of these credentials and costs the
> workshop nothing, so it runs before this check. "First" below means first on
> the kit's own route - reach here only when Phase 0.5 said the user needs
> something the built-in's six read-only tools can't answer, or Phase 1 couldn't
> be used. Everything in this gate is unchanged.

The MYOB connector cannot function without workshop developer credentials. These are issued by MYOB after the workshop org subscribes to the **MYOB Developer Access** tier (AUD $110/month - there is no free tier; see §Overview). The credentials ship in `skills/myob-connector/.workshop-credentials` (gitignored, distributed via the workshop install bundle).

Before saying anything else, run this check:

```bash
# Look for the workshop credentials file
CRED_FILE="$(dirname "$0")/.workshop-credentials"  # or use the absolute skill path
if [ ! -f "$CRED_FILE" ]; then
  echo "MISSING"
elif ! grep -q "MYOB_CLIENT_ID=" "$CRED_FILE" || ! grep -q "MYOB_CLIENT_SECRET=" "$CRED_FILE"; then
  echo "INCOMPLETE"
else
  echo "OK"
fi
```

If the result is **`MISSING`** or **`INCOMPLETE`**, **stop immediately**. Do not run the safety gate. Do not start Phase 1. Do not open a browser.

First, check whether the user actually uses MYOB before pushing them toward any solution. The user may have triggered this skill from an ambient match (e.g., asking "can you connect my accounting?") rather than because they actually use MYOB. Ask them in plain English:

> "Quick check before I help - do you currently have a **paid MYOB subscription** that you use for your business, or are you just curious about MYOB?"

**Handle the response:**

- **User confirms they have a paid MYOB subscription** → tell them this:
  > "Got it. I'd love to help you connect it - but the MYOB connection isn't switched on in this workshop kit yet. The workshop team is finalising the setup on their end (one-off; doesn't affect your subscription or cost you anything). It should be ready shortly - track progress at <https://github.com/selrai-company/claude-workshop-kit/issues/146>.
  >
  > In the meantime, if you also use Xero alongside MYOB, I can connect that instead - let me know."

- **User says they don't currently use MYOB / they're just curious / they're shopping for accounting software** → tell them this and **do not push MYOB**:
  > "No worries - in that case I won't try to set up MYOB for you, since it only makes sense if you already pay for an MYOB subscription. If you're already using **Xero** for accounting (or want to start), Xero is set up in this workshop and I can connect that instead. If you're using something else like QuickBooks, I can help with that too. What does your business actually use today?"
  Then route them to the right connector (`xero-connector`, `quickbooks-connector`, etc.) based on their answer. Do not return to MYOB.

- **User says they have something else (Xero, QuickBooks, Stripe, etc.)** → route to the matching connector skill. Do not return to MYOB.

- **User asks why MYOB costs money on the workshop's side** → say in plain English: *"MYOB charges developers like us about $110 a month just to access their connection point - most other accounting tools (Xero, QuickBooks) give that to developers for free. The workshop covers it so you don't see any extra cost - you just pay your normal MYOB subscription, same as before."*

- **User says they'll cover the workshop's developer fee** → say: *"That's really generous, but no need - the workshop's already covering the developer-side fee on their end. You only need your own MYOB subscription, same as you'd be paying anyway."* Do not proceed.

Only proceed past this check when **both** of these are true:
1. The credential file exists and contains non-empty `MYOB_CLIENT_ID` and `MYOB_CLIENT_SECRET`
2. The user has confirmed they have a paid MYOB subscription

> **Note for the skill author:** the credential file format is a simple shell-sourceable env file:
>
> ```
> MYOB_CLIENT_ID=<workshop-dev-app-key>
> MYOB_CLIENT_SECRET=<workshop-dev-app-secret>
> ```
>
> The file should be `chmod 600` and never committed to git. Add `skills/myob-connector/.workshop-credentials` to the repo's `.gitignore` before any work that touches real credentials.

---

## ⚠️ Safety gate - run this BEFORE Phase 1 Step 1

This skill is for users who **already have a paid MYOB subscription**. It does not provision MYOB for them, does not sell them MYOB, and does not work against a free trial. Two checks are required before touching anything.

### Step 0a - Confirm the user has a paid MYOB subscription

Even if the pre-flight credential check passed, you still need to confirm the user is actually a current MYOB subscriber. The skill auto-loads on phrases like "connect my MYOB" but the user might have said it speculatively. **Without a real paid subscription on the user's side, MYOB itself will refuse to issue OAuth tokens - there's no company file to authorise.** Set this expectation upfront in plain English so the user understands why the question matters.

**Say this and wait for the user's answer:**

> "Before we start - quick check: do you currently have a **paid MYOB subscription** that you use for your business?
>
> *(Heads-up on how this works: when you ask me anything about your MYOB - invoices, customers, sales - I run the request directly against MYOB's website using your account. So I need you to be a real paid MYOB subscriber on your end, with your own login. Free trials and accountant-only logins won't work. The good news: you don't pay anything extra to use the connection itself - just your normal MYOB subscription.)*"

**Handle the response:**

- **Yes, paid MYOB subscriber** → continue to Step 0b (product line).
- **No / not yet / shopping around / on a free trial** → say: *"In that case I won't try to set up MYOB - it only works once you've got a real subscription. If you already use Xero or QuickBooks, I can connect either of those instead. What does your business currently use?"* Route to the matching connector (`xero-connector` is the closest sibling for AU SMBs). **Do not proceed past this gate.**
- **User asks if they should sign up for MYOB** → say: *"That's really up to you - MYOB and Xero are both solid AU options and most businesses pick one or the other. If you don't already have an accountant suggesting one, Xero tends to be a smoother starting point because it's already set up in this workshop and has a free trial. If you go with MYOB later, just say 'connect my MYOB' once you're subscribed and I'll pick this back up."* Do not proceed.
- **User confirms they have MYOB but only through their accountant / it's not their own login** → say: *"Got it. I'll need a login that's directly on the MYOB account - typically the business owner's. Do you have one of those, or would you need to ask your accountant for access first?"* Wait for clarification before continuing.

Only continue to Step 0b when the user has confirmed they're a current MYOB subscriber **with their own login**.

### Step 0b - Confirm the product line

MYOB has two product lines that materially change the endpoint shape. Confirm which one the user has.

**Say this and wait for the user's answer:**

> "Great - MYOB makes two flavours of accounting software, and the connection works slightly differently for each:
>
> - **MYOB Business** is the cloud-first one most newer accounts use. Plans are called Lite, Pro, or Solo, with a monthly subscription.
> - **MYOB AccountRight** is the older desktop-and-cloud hybrid. Plans are called Plus or Premier.
>
> Which do you have? If you're not sure, sign in at my.myob.com and the product name appears at the top of your dashboard."

**Handle the response:**

- **MYOB Business** → main path. Continue to Step 1. (Most common for accounts opened in the last few years.)
- **MYOB AccountRight** → say: *"That works too - the connection's similar but the data lives in a slightly different shape. I'll set you up the same way and just adjust the endpoints. Let's go."* Continue to Step 1, but in Phase 2 use the AccountRight company file URI shape (`/accountright/<file-id>/...`) rather than the Business shape.
- **User isn't sure which product they have** → say: *"No worries - easiest way: open my.myob.com in your browser and tell me what the dashboard says at the top. If it says 'MYOB Business' you're on Business; if it says 'AccountRight' you're on AccountRight."* Wait, then proceed.
- **User says they only have MYOB Solo** → say: *"Solo is MYOB's mobile-first product, and it doesn't expose the same data through the connection I use. I can't connect Solo accounts yet - sorry. The workshop team is tracking this if it comes up enough."* Stop. (Solo uses a different API surface that this skill doesn't support.)
- **User refuses to clarify** → say: *"No problem - we can pick this up another time. Just say 'connect my MYOB' whenever you're ready."* Do not proceed.

Only proceed past this gate when the user has **explicitly confirmed** the product line.

> **Note for the skill author, not the user:** the workshop's shared developer credentials work against either product line - the only thing that changes is the company-file URI returned in Step 5 and the resource paths used in Phase 2. The user does not need to choose between "real account" and "sandbox" - they always authorize their own real MYOB account; the sandbox is a workshop-internal testing tool, not a per-user one.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in the installed assistant persona (`~/.claude/selr-assistant.md`):

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say OAuth, token, scope, refresh, Bearer, API, endpoint, JSON, environment variable, curl, terminal, CLI, MCP, client ID, redirect URI, callback, loopback, sandbox, or file path as technical concepts. If you must refer to a technical thing, name it plainly: "the connection key", "your account details", "MYOB's website".
- **Tell them what is about to happen.** Before any action you take: *"I'm going to open MYOB's sign-in page now in a small browser window - sign in like normal when you see it."*
- **React warmly.** Good: *"Got it - your MYOB is now connected to Acme Trading."* Bad: *"OAuth token exchange returned 200, tokens persisted to disk."*
- **Never show error messages directly.** Translate. If something fails, say *"No problem - let me try a different way,"* then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 - Install & Connect (≤6 steps) - the kit's own route

This phase opens MYOB's authorization page in a Playwright MCP browser, has the user sign in once, captures the authorization code from the redirect, exchanges it for access + refresh tokens, lets the user pick which company file to connect, and verifies the connection with a live API call.

### Step 1 - Orient the user

After the safety gate is passed, send one short message:

> "Great - let's connect your MYOB. I'll open MYOB's sign-in page in a small browser window in just a moment. Sign in like normal, pick the business you want me to connect to, and approve. The whole thing takes about two minutes."

### Step 2 - Spin up the loopback listener

Silently start a tiny localhost listener on port 8765 to catch the redirect with the authorization code. Run this in the background:

```bash
nohup python3 -c "
import http.server, urllib.parse, sys
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a, **k): pass
    def do_GET(self):
        q = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(q)
        code = params.get('code', [''])[0]
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(b'<h1>MYOB connected. You can close this tab.</h1>')
        with open('/tmp/myob-auth-code', 'w') as f:
            f.write(code)
        sys.exit(0)
http.server.HTTPServer(('127.0.0.1', 8765), H).serve_forever()
" > /tmp/myob-listener.log 2>&1 &
echo $! > /tmp/myob-listener.pid
```

If port 8765 is already in use, increment to 8766, 8767, etc. - also update the `redirect_uri` in Step 3 accordingly.

> **Note:** the workshop developer credentials (`MYOB_CLIENT_ID` / `MYOB_CLIENT_SECRET`) ship with this skill in `skills/myob-connector/.workshop-credentials` (gitignored, distributed via the workshop install bundle). They are the same for every attendee - only the per-user `access_token` / `refresh_token` is unique.

### Step 3 - Open the MYOB authorization page in Playwright MCP

Construct the URL using the workshop-shipped client ID. Default scope set covers all the demos this skill supports; trim if the user only wants a subset.

```
https://secure.myob.com/oauth2/account/authorize
  ?client_id=<MYOB_CLIENT_ID>
  &redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback
  &response_type=code
  &scope=CompanyFile%20la.global%20sme-company-file%20sme-company-settings%20sme-sales%20sme-purchases%20sme-banking%20sme-contacts-customer%20sme-contacts-supplier%20sme-contacts-employee%20sme-payroll%20sme-inventory%20sme-general-ledger
  &prompt=consent
```

Open it with `mcp__plugin_playwright_playwright__browser_navigate`. Then tell the user:

> "I've opened MYOB's sign-in window. Please sign in with the email and password you use for MYOB, then pick the business you want me to connect to and click Allow."

Wait for the user to complete the flow. Poll `/tmp/myob-auth-code` every 3 seconds for up to 5 minutes (the authorization code expires in 2-5 minutes after MYOB issues it, so any longer wait is wasted).

**Common mistakes to look out for:**

- User picks a personal MYOB login that has no company file attached → the post-Allow page will say "no companies available". Tell the user: *"Looks like the account you signed in with doesn't have a business attached yet. If you have a different MYOB login that's tied to your business, let's try that instead - otherwise you might need to set up a company file in MYOB first."* Stop and let them choose.
- User cancels at the Allow step → the redirect will carry `?error=access_denied` instead of `?code=...`. Tell the user: *"No worries - looks like you didn't approve the connection. Want to try again, or stop here?"*
- The Playwright window closes accidentally → re-open with the same URL. The user may need to re-sign-in.

### Step 4 - Exchange the code for tokens

When the listener writes `/tmp/myob-auth-code`, read it and exchange for tokens:

```bash
AUTH_CODE=$(cat /tmp/myob-auth-code)
RESP=$(curl -sf https://secure.myob.com/oauth2/v1/authorize \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$MYOB_CLIENT_ID" \
  -d "client_secret=$MYOB_CLIENT_SECRET" \
  -d "scope=CompanyFile" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://localhost:8765/callback" \
  -d "grant_type=authorization_code")

# Tear down the listener
kill "$(cat /tmp/myob-listener.pid)" 2>/dev/null
rm -f /tmp/myob-auth-code /tmp/myob-listener.pid /tmp/myob-listener.log
```

The response is JSON with `access_token`, `refresh_token`, `expires_in` (seconds), `scope`, and `user`. Stash for Step 5; do not write to disk yet.

**Failure cases:**

- HTTP 400 with `invalid_grant` → the code expired (>5 minutes since user clicked Allow). Tell the user: *"The connection code timed out - let's try once more, faster."* Restart from Step 2.
- HTTP 400 with `invalid_client` → the workshop-shipped credentials are wrong or revoked. Tell the user plainly: *"There's a problem with my end of the connection - I'll need to flag this so the workshop team can fix it. For now, MYOB won't work."* Do not retry.
- Network error → retry once with 5-second delay. If still failing, tell the user: *"MYOB's servers aren't responding right now. Want to try again in a minute?"*

### Step 5 - Discover the company file

The token unlocks the API but doesn't tell you which company file to target. List company files and ask the user to pick:

```bash
ACCESS_TOKEN=$(echo "$RESP" | jq -r .access_token)
FILES=$(curl -sf https://api.myob.com/accountright \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-myobapi-key: $MYOB_CLIENT_ID" \
  -H "x-myobapi-version: v2" \
  -H "Accept: application/json")
```

The response is a JSON array. Each item has `Id`, `Name`, `Uri`, `LibraryPath`. Show the user the **names only** in plain English:

- **One company file** → silently pick it. Continue to Step 6.
- **Multiple company files** → "I can see a few businesses on your MYOB account: **Acme Trading**, **Beta Holdings**, **Gamma Pty Ltd**. Which one would you like me to connect to?" Wait for the user's pick. Match case-insensitively.
- **Zero company files** → "Hmm, your MYOB account doesn't seem to have any businesses set up yet. You'd need to create one in MYOB first - happy to wait if you want to do that now." Stop.

> **AccountRight cloud files note:** if the user is on AccountRight and the picked file shows `"ProductLevel": { "Code": ... }` indicating a cloud-stored file with a company-file password, you'll later need `x-myobapi-cftoken: Base64(file-username:file-password)` on data-endpoint calls. This v1 skill does **not** support password-protected AccountRight files - tell the user: *"This MYOB file has its own password I can't get past from here. The workshop team is working on a follow-up that handles this - for now, MYOB won't work for you."* Stop.

### Step 6 - Save tokens and verify

Compute `expires_at` (now + `expires_in` seconds, ISO 8601 UTC), then atomically write `~/.config/myob/tokens.json`:

```bash
mkdir -p ~/.config/myob
chmod 700 ~/.config/myob

# Compute expiry
EXPIRES_AT=$(python3 -c "
import datetime, sys
secs = int(sys.argv[1])
print((datetime.datetime.utcnow() + datetime.timedelta(seconds=secs)).strftime('%Y-%m-%dT%H:%M:%SZ'))
" "$(echo "$RESP" | jq -r .expires_in)")

# Build the tokens file
jq -n \
  --arg cid "$MYOB_CLIENT_ID" \
  --arg csec "$MYOB_CLIENT_SECRET" \
  --arg at "$(echo "$RESP" | jq -r .access_token)" \
  --arg rt "$(echo "$RESP" | jq -r .refresh_token)" \
  --arg sc "$(echo "$RESP" | jq -r .scope)" \
  --arg user "$(echo "$RESP" | jq -r .user.username)" \
  --arg fid "$FILE_ID" \
  --arg fname "$FILE_NAME" \
  --arg furi "$FILE_URI" \
  --arg exp "$EXPIRES_AT" \
  '{client_id:$cid, client_secret:$csec, access_token:$at, refresh_token:$rt,
    expires_at:$exp, scope:$sc, username:$user,
    company_file:{id:$fid, name:$fname, uri:$furi}}' \
  > ~/.config/myob/tokens.json.tmp

chmod 600 ~/.config/myob/tokens.json.tmp
mv ~/.config/myob/tokens.json.tmp ~/.config/myob/tokens.json
```

**Rules:**
- Always atomic (write `.tmp`, chmod, then rename) - never leave a partially-written `tokens.json` on disk.
- File mode `0600` enforced. Directory mode `0700`.
- Never echo `client_secret`, `access_token`, or `refresh_token` to the user. Never include them in any output visible to the user.

Then verify with one live read - list customer contacts (a low-stakes read every account has):

```bash
COMPANY_URI=$(jq -r .company_file.uri ~/.config/myob/tokens.json)
curl -sf "$COMPANY_URI/Contact/Customer?\$top=1" \
  -H "Authorization: Bearer $(jq -r .access_token ~/.config/myob/tokens.json)" \
  -H "x-myobapi-key: $(jq -r .client_id ~/.config/myob/tokens.json)" \
  -H "x-myobapi-version: v2" \
  -H "Accept: application/json" > /dev/null
```

- **Success (HTTP 200)** → Tell the user:
  > "All done - your MYOB is now connected to **[company file name]**. You can ask me things like 'show me my recent invoices', 'who owes me money?', or 'create an invoice for [client] for [amount]'. Give it a try!"
- **HTTP 401** → token didn't take. Run the refresh flow once (see Phase 2 §Refresh), retry the verify call. If still 401, ask the user to run Phase 1 again from Step 2.
- **HTTP 403** → scope mismatch. Tell the user: *"I'm connected, but I'm missing one permission. Let me re-run the connection with the right one."* Restart Phase 1 with the missing scope added to Step 3's URL.
- **Any other error** → tell the user: *"The connection went through but I can't read anything yet. Let me try once more."* Retry once. If still failing, surface the HTTP status in plain English (*"MYOB's saying 503 - its servers may be having a moment"*) and ask the user whether to retry or stop.

---

## PHASE 2 - Use the connector

**Which surface you are on.** Through the built-in connector (Phase 1), MYOB work
runs through the `mcp__claude_ai_MYOB__*` tools - six read-only reports and
nothing else, with no tokens on disk and no refresh cycle. Through the kit's own
route it runs through the curl loop below, which reaches the full REST surface and
is the only route that writes. The two differ materially: if the user is on the
built-in and asks for an individual invoice, a contact record, a banking line, or
any change at all, that is the kit's own route - say so and offer it rather than
improvising.

Once `~/.config/myob/tokens.json` exists, follow this loop on every MYOB-related request from the user.

### Runtime loop

```
1. Read ~/.config/myob/tokens.json.
   - If missing → run Phase 1.
   - If expires_at is within the next 60 seconds → run §Refresh below before continuing.
2. Build the request:
   - URL = company_file.uri + endpoint path
   - Headers (every call):
       Authorization: Bearer <access_token>
       x-myobapi-key: <client_id>
       x-myobapi-version: v2
       Accept: application/json
   - Headers (POST/PUT only): Content-Type: application/json
3. Execute via Bash curl. Use -sf so non-2xx triggers a non-zero exit.
4. Handle the response:
   - 2xx → parse JSON, present the result in plain English (never raw JSON to the user).
   - 401 → run §Refresh, retry the original request once.
   - 403 → scope missing. Tell the user which capability needs re-authorizing and offer to re-run Phase 1.
   - 429 → respect Retry-After header (default 30s if absent), wait, retry once.
   - 5xx → tell the user MYOB is having trouble, offer to retry once.
   - 4xx (other) → translate the error to plain English; do not retry blindly.
```

### Refresh

The access token lives 20 minutes (1200s). Refresh proactively when `expires_at` is < 60s away, or reactively on the first 401:

```bash
RESP=$(curl -sf https://secure.myob.com/oauth2/v1/authorize \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$(jq -r .client_id ~/.config/myob/tokens.json)" \
  -d "client_secret=$(jq -r .client_secret ~/.config/myob/tokens.json)" \
  -d "refresh_token=$(jq -r .refresh_token ~/.config/myob/tokens.json)" \
  -d "grant_type=refresh_token")

# Atomically rewrite the tokens file with new access_token + refresh_token + expires_at
EXPIRES_AT=$(python3 -c "
import datetime, sys
print((datetime.datetime.utcnow() + datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))
" "$(echo "$RESP" | jq -r .expires_in)")

jq --arg at "$(echo "$RESP" | jq -r .access_token)" \
   --arg rt "$(echo "$RESP" | jq -r .refresh_token)" \
   --arg exp "$EXPIRES_AT" \
   '.access_token=$at | .refresh_token=$rt | .expires_at=$exp' \
   ~/.config/myob/tokens.json > ~/.config/myob/tokens.json.tmp
chmod 600 ~/.config/myob/tokens.json.tmp
mv ~/.config/myob/tokens.json.tmp ~/.config/myob/tokens.json
```

Refresh tokens **rotate** on every refresh - always save the new one. If the refresh response is `invalid_grant`, the refresh chain is dead; run Phase 1 from Step 2.

### Endpoint reference

All endpoints are relative to `$COMPANY_URI` (read from `~/.config/myob/tokens.json` `company_file.uri`).

#### Sales

| Operation | Endpoint | Method |
|---|---|---|
| List invoices (item) | `$COMPANY_URI/Sale/Invoice/Item` | GET |
| List invoices (service) | `$COMPANY_URI/Sale/Invoice/Service` | GET |
| Get invoice by UID | `$COMPANY_URI/Sale/Invoice/Item/{UID}` | GET |
| Create item invoice | `$COMPANY_URI/Sale/Invoice/Item` | POST |
| Update item invoice | `$COMPANY_URI/Sale/Invoice/Item/{UID}` | PUT |
| List quotes | `$COMPANY_URI/Sale/Quote/Item` | GET |
| Create quote | `$COMPANY_URI/Sale/Quote/Item` | POST |

#### Purchases

| Operation | Endpoint | Method |
|---|---|---|
| List bills | `$COMPANY_URI/Purchase/Bill/Item` | GET |
| Create bill | `$COMPANY_URI/Purchase/Bill/Item` | POST |
| List orders | `$COMPANY_URI/Purchase/Order/Item` | GET |

#### Contacts

| Operation | Endpoint | Method |
|---|---|---|
| List customers | `$COMPANY_URI/Contact/Customer` | GET |
| Get customer by UID | `$COMPANY_URI/Contact/Customer/{UID}` | GET |
| Create customer | `$COMPANY_URI/Contact/Customer` | POST |
| List suppliers | `$COMPANY_URI/Contact/Supplier` | GET |
| Create supplier | `$COMPANY_URI/Contact/Supplier` | POST |
| List employees | `$COMPANY_URI/Contact/Employee` | GET |

#### Inventory

| Operation | Endpoint | Method |
|---|---|---|
| List items | `$COMPANY_URI/Inventory/Item` | GET |
| Get item by UID | `$COMPANY_URI/Inventory/Item/{UID}` | GET |
| Create item | `$COMPANY_URI/Inventory/Item` | POST |

#### Banking

| Operation | Endpoint | Method |
|---|---|---|
| List accounts | `$COMPANY_URI/GeneralLedger/Account` | GET |
| List bank transactions | `$COMPANY_URI/Banking/SpendMoneyTxn` (out) / `$COMPANY_URI/Banking/ReceiveMoneyTxn` (in) | GET |
| Record spend money | `$COMPANY_URI/Banking/SpendMoneyTxn` | POST |
| Record receive money | `$COMPANY_URI/Banking/ReceiveMoneyTxn` | POST |
| List tax codes | `$COMPANY_URI/GeneralLedger/TaxCode` | GET |

#### Payroll (AU only, requires `sme-payroll` scope)

| Operation | Endpoint | Method |
|---|---|---|
| List pay items | `$COMPANY_URI/Payroll/PayrollCategory/Wage` | GET |
| List super funds | `$COMPANY_URI/Payroll/SuperannuationFund` | GET |
| List employees | `$COMPANY_URI/Contact/Employee` | GET |

> **Filtering**: MYOB endpoints support OData query syntax - `?$filter=Status eq 'Open'`, `?$top=20`, `?$orderby=Date desc`, `?$select=UID,Number,Date,TotalAmount`. Use `$top=10` by default to keep payloads small; offer to fetch more.

> **Field shapes**: invoice / contact / item payloads vary by endpoint subtype (e.g., Item invoice vs Service invoice have different `Lines` shapes). When in doubt, GET an existing record first to learn the schema, then mirror it on POST.

---

## Prompt-to-action mapping

| What the user says | What you do |
|---|---|
| "Connect my MYOB" / "Set up MYOB" / "Help with my MYOB" | **Run Phase 1** (starting with the safety gate) |
| "Show me my invoices" | GET `/Sale/Invoice/Item?$top=10&$orderby=Date desc` |
| "List unpaid invoices" / "Who hasn't paid me?" | GET `/Sale/Invoice/Item?$filter=Status eq 'Open'` |
| "Show me overdue invoices" | GET `/Sale/Invoice/Item?$filter=Status eq 'Open'`, then filter client-side by `DueDate < today` |
| "Find invoices for [client]" | GET `/Contact/Customer?$filter=substringof('[name]',CompanyName)` to get UID, then `/Sale/Invoice/Item?$filter=Customer/UID eq guid'<UID>'` |
| "Create an invoice for [client] for [amount]" | **Confirm first.** Then POST `/Sale/Invoice/Item` with the customer UID, today's date, and the line. |
| "Find [name] in my contacts" | GET `/Contact/Customer?$filter=substringof('[name]',CompanyName)` |
| "Add a new customer for [name]" | **Confirm first.** Then POST `/Contact/Customer`. |
| "Show me my chart of accounts" | GET `/GeneralLedger/Account` |
| "List my bank transactions" | GET `/Banking/SpendMoneyTxn` and `/Banking/ReceiveMoneyTxn`, merge by date. |
| "Record a payment from [client] for [amount]" | **Confirm first.** Then POST `/Banking/ReceiveMoneyTxn`. |
| "What tax codes are available?" | GET `/GeneralLedger/TaxCode` |
| "Show me my products" / "List my items" | GET `/Inventory/Item` |
| "Show me my suppliers" | GET `/Contact/Supplier` |
| "Create a quote for [client]" | **Confirm first.** Then POST `/Sale/Quote/Item`. |
| "Show me my bills" / "What do I owe?" | GET `/Purchase/Bill/Item?$filter=Status eq 'Open'` |
| "Switch to my other MYOB business" | Re-run Phase 1 from Step 5 (re-discover company file). The auth tokens stay valid; only `company_file.*` in `tokens.json` changes. |

---

## Error handling (Phase 2)

When a MYOB API call fails, diagnose and respond in plain English. Never show raw HTTP status codes or JSON error bodies to the user.

| Error | What to say to the user | How to fix |
|---|---|---|
| HTTP 401 (first time) | (silent) | Run §Refresh; retry the original request once. |
| HTTP 401 (after refresh) | "Your MYOB connection has expired - let me reconnect you." | Run Phase 1 from Step 2. |
| HTTP 403 / `insufficient_scope` | "I'm connected, but I don't have permission for that yet - let me get the right access." | Identify which scope is missing from the error body, re-run Phase 1 with that scope added to the URL in Step 3. |
| HTTP 404 on a record | "I couldn't find that - let me search for it." | Use the matching `list-*` endpoint to help the user find the right one. |
| HTTP 400 with field validation error | Translate the field name from the error body into plain English (*"MYOB says the invoice date is wrong - let me fix that and try again"*). | Correct and retry once. If the user's input is the issue, ask for clarification. |
| HTTP 429 | "MYOB's asking me to slow down - I'll wait a moment and try again." | Wait for `Retry-After` (default 30s), retry once. |
| HTTP 5xx | "MYOB's servers are having a moment - want me to try again in a minute?" | Do not auto-retry beyond once. Let the user decide. |
| Network timeout | "I can't reach MYOB right now - want me to try again?" | Wait for user OK, retry once. |
| `invalid_grant` on refresh | "Your MYOB connection has expired completely - let me reconnect you from scratch." | Run Phase 1 from Step 2. |
| `tokens.json` missing or corrupted | "Looks like your MYOB connection got reset - let's set it up again." | Run Phase 1 from Step 2. |
| Company file URI returns 404 | "The MYOB business I was connected to seems to have been deleted or renamed - let me re-pick it." | Run Phase 1 from Step 5 (re-discover company file). |

---

## Scope limitations

The MYOB connector **can** do:

- Read invoices, quotes, bills, contacts (customer/supplier/employee), inventory items, bank transactions, the chart of accounts, tax codes
- Create invoices (item + service), quotes, bills, customers, suppliers, items, spend-money / receive-money transactions
- Read payroll metadata (pay items, super funds, employees) where the `sme-payroll` scope was granted
- Switch between company files on the same MYOB login (via Phase 1 Step 5 re-run)
- Refresh access tokens silently every 20 minutes

The MYOB connector **cannot** do (in v1):

- **Delete** records - use the MYOB UI for deletions
- **Send** invoices/quotes by email to customers - the user does this in the MYOB UI after the draft is created
- **Reconcile** bank transactions against statement lines
- **File** BAS, IAS, or any tax return / payroll lodgement
- **Connect to multiple company files at once** - single file per `tokens.json`. To switch, re-run Phase 1 Step 5.
- **AccountRight cloud files with a company-file password** - the `x-myobapi-cftoken` header is not supported in v1. Tell affected users the workshop team is working on a v2.
- **MYOB Solo by MYOB** (mobile-only product) - not supported by the same API surface; out of scope.
- **Reports** - MYOB's REST API doesn't expose pre-built reports (P&L, Balance Sheet) the way Xero does. Compose them from `/Sale/Invoice` + `/Banking/*` + `/GeneralLedger/Account` aggregations if the user asks.

---

## Behaviour guidelines (Phase 2)

- **Always confirm before creating, updating, or recording money movements.** Summarise what you're about to do (*"I'm going to create an invoice for Acme Trading for $1,200 plus GST, dated today - does that look right?"*) and wait for the user's OK.
- **Invoices are created as Open by default in MYOB**, not Draft (different from Xero). Be explicit: *"I've created the invoice - it's now in MYOB ready to send. You can preview and email it from the MYOB website."*
- **Format currency from the company file's currency.** Default AUD for AU MYOB; respect the file's currency if multi-currency is enabled.
- **Present results as readable summaries**, not raw JSON. *"You have 12 unpaid invoices totalling $34,500. The biggest one is Acme Trading for $8,200, dated 14 days ago. Want me to list them all?"*
- **Default to small page sizes.** `$top=10` unless the user asks for everything. Offer to fetch more.
- **Always look up reference data before write operations**: customer UID before creating an invoice, account code before recording a bank transaction, tax code before creating an invoice in a tax-registered file. Don't guess UIDs.
- **Never log or echo credentials.** `client_id`, `client_secret`, `access_token`, `refresh_token` must never appear in user-visible output.
- **Single company file at a time.** If the user asks about a different MYOB business, tell them: *"I'm currently connected to [current company file]. Want me to switch over?"* - then re-run Phase 1 Step 5.
- **Respect rate limits.** MYOB enforces per-app rate limits. On 429, wait the `Retry-After` and retry once; on a second 429, tell the user and ask them to retry later.
- **Token refresh is invisible to the user.** Don't narrate it. Just refresh and continue.

---

## Related skills

- **xero-connector**: The other major AU accounting connector. Larger market share, different auth model (Custom Connection client_credentials, no per-user OAuth). Use the right one based on which platform the user has.
- **quickbooks-connector**: Sibling for QuickBooks Online users (global market).
- **outlook-connector**: Reference implementation for the Playwright-MCP-driven OAuth Auth Code flow. Same golden rule (no user browser).
- **orientation**: The conversational bootstrap pattern Phase 1 follows.
- **superpowers:systematic-debugging** (optional): Use when token refresh fails repeatedly or API calls return errors with no documented recovery path.

---

## Open items (tracked in [issue #146](https://github.com/selrai-company/claude-workshop-kit/issues/146))

The skill itself is complete and ready to ship. The remaining items are operational (registering MYOB's developer-side credentials) and verification.

**Decided / not blocking merge:**

- [x] **Workshop budget approved** - the workshop subscribes to MYOB Developer Access at AUD $110/mo. Treated as fixed workshop infrastructure cost, comparable to the AWS / Supabase / domain registrations the kit already pays for. Attendees never see this cost.
- [x] **Architecture confirmed: direct REST via `curl`** - the skill ships against MYOB Business + AccountRight REST APIs, no MCP server, no CLI. Decided per #146 discussion.
- [x] **Audience scoped to existing paid subscribers** - the skill self-filters; attendees without a paid MYOB subscription get routed to the Xero connector instead. Decided 2026-04-27.

**Operational follow-ups (post-merge):**

- [ ] **Developer Program application submitted** at <https://apisupport.myob.com/hc/en-us/requests/new?ticket_form_id=6175906535311> using the workshop's business email + ABN. 1-5 business day approval.
- [ ] **Workshop developer credentials registered** at developer.myob.com after approval → distributed via `skills/myob-connector/.workshop-credentials` (gitignored). The skill reads `MYOB_CLIENT_ID` and `MYOB_CLIENT_SECRET` from this file in Phase 1. Until this lands, the pre-flight check correctly tells users the connector isn't switched on yet.
- [ ] **Phase -1 self-install** - zip-based bootstrap so attendees can install this skill from a Downloads zip per Luke's 6-criterion bar.
- [ ] **Live API verification against the bundled MYOB Business Pro live subscription** - confirms the OAuth flow against a real (private, workshop-controlled) account. This is the canonical demo file.
- [ ] **Live API verification against the shared developer sandbox** - confirms the same flow works against sandbox for workshop-internal testing without polluting the demo account. (Sandbox is shared with other developers - never use it for live attendee demos.)
- [ ] **AccountRight company file URI shape verified** - Phase 2 endpoint reference is written for MYOB Business; AccountRight may need `/accountright/<file-id>/...` prefix instead of the `Uri` returned by the discover-company-files call.
- [ ] **Cross-platform verification** - Phase 1 needs PowerShell-equivalent commands for native Windows users (currently bash-only, works on macOS/WSL).
- [ ] **Idempotent re-run** - running Phase 1 twice in a row should detect existing valid tokens and skip; corrupted/expired tokens should trigger fresh auth without leaving the user confused.
- [ ] **Troubleshooting matrix** - current error table covers the common cases; add MYOB-specific quirks discovered during real testing.
