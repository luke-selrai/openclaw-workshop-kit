---
name: xero-connector
description: "Connect Xero to Claude by switching on its built-in connector for the headline numbers, or by installing and authenticating Xero's official MCP server for the full service. Use when the user asks to set up or connect Xero, or wants Xero or accounting work (invoices, contacts, payments, quotes, bank transactions, the chart of accounts, profit and loss, balance sheet) and Xero isn't connected yet. Once connected, Xero runs through the mcp__claude_ai_Xero__* or mcp__xero__* tools."
allowed-tools: mcp__claude_ai_Xero__*, mcp__xero__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - xero
    - accounting
    - invoices
    - mcp
    - finance
    - workshop
    - autonomous
  audience: non-technical business owner
  time-to-complete: 10-15 minutes
  cost-to-user: $10 AUD per month including GST (Xero Custom Connection activation fee, paid to Xero; other countries billed in their own currency). The built-in connector route is free.
  autonomy-bar: "Built-in route: press Connect and sign in once. Full-service route: sign in to Xero ONCE, maybe confirm a payment method if none on file. That is it."
  pairs-with:
    - skill: hubspot-connector
      reason: Sibling Playwright-driven autonomous connector - admin-portal + DOM-extract pattern, same Client-ID-style credential model
    - skill: monday-connector
      reason: Sibling Playwright-driven autonomous connector - same admin-portal create-app-and-extract-token shape
    - skill: slack-connector
      reason: Sibling Playwright-driven autonomous connector - same multi-step app-create + scope-tick + token-extract flow
    - skill: quickbooks-connector
      reason: Sibling accounting connector - similar wrap-existing-tooling pattern for a different platform
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Xero developer portal
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Xero Custom Connection or API errors
---

# Xero Connector - Fully Autonomous

> **The standard**: the user signs in to Xero. That is the only thing they do. Playwright drives every click, form fill, scope tick, ID extraction, secret capture, config write, restart prompt, and live verification. Every error is caught and silently recovered. If the agent can't recover, it diagnoses in plain English - never dumps a raw error.
>
> **Applies to**: OpenClaw workshop attendees. Non-technical business owners. They should never type a command, paste a value, or edit a file.
>
> **If Playwright MCP isn't available in this session, STOP.** Do not fall back to a manual walkthrough that asks the user to copy-paste Client ID and Secret. Instead, tell the user: *"I need browser control to set this up hands-off. Let me enable that - give me two minutes."* Then install Playwright MCP in this session and retry. If you genuinely cannot get Playwright working, tell the user plainly and retry in a fresh session rather than make them do manual steps.

---

## Autonomy Bar - What Counts as "User Action"

| User DOES | User DOES NOT |
|---|---|
| Sign in to their own Xero account (email, password, 2FA code from their phone) | Click buttons on developer.xero.com (agent clicks) |
| Possibly add a payment method if none on file (Xero's own billing flow, not Selr AI's) | Fill in form fields (agent fills) |
| Fully quit and reopen Claude Code once | Select which organisation to connect (agent picks based on the one they specify in chat) |
| Confirm in chat when prompted (max 2 yes/no questions in the whole flow) | Tick scope checkboxes (agent ticks) |
|  | Copy Client ID or Client Secret (agent reads DOM directly) |
|  | Paste anything into chat (agent never asks) |
|  | Run curl commands, edit config files, restart services (agent does all silently) |
|  | Read error messages (agent translates or handles silently) |

**If at any point you (the agent) are about to ask the user to copy or paste a value, STOP.** You have the Playwright browser in the same session - read the DOM directly.

---

## How This Skill Works

User says any of:
- "Connect my Xero"
- "Set up Xero"
- "Help me with my accounting"
- "Show me my invoices" (and Xero isn't configured yet)

Agent runs the interview and the built-in route first (next section), then - for anyone who wants the full service - Phases 0 through 7 below. On the full service the user experiences a guided conversation with 3 touchpoints: the safety gate (answer yes/no + country + which Xero org), the sign-in moment (they type their credentials into the browser Playwright opened), the restart moment (they quit + reopen Claude Code). That's it.

---

## Two routes into Xero - interview first

Xero has two routes into Claude, and this skill switches on whichever the user's actual need calls for:

| Route | What it does | Cost | Tools |
|---|---|---|---|
| **The built-in Xero connector** (Claude's own directory listing) | Read-only headline numbers: profit and loss, who owes them money, cash position, top customers. One click, no developer portal. | Free | `mcp__claude_ai_Xero__*` |
| **The full service** (Phases 0-7 below: Xero's official MCP server on a Custom Connection) | Everything - every invoice, bill, quote, contact, bank line, journal and report, **and changes**: create draft invoices, bills, quotes and credit notes, add and update contacts, record payments. Writes are drafts, confirmed first, verified after (see Agent Behaviour Rules). | $10 AUD/month, paid to Xero | `mcp__xero__*` |

**The interview.** Before opening anything, ask **one** question in plain English: what do they want Claude to do with Xero? Offer the two shapes as examples (*"a quick read on how the business is going - profit, who owes you, cash? Or working in the books - raising invoices and bills, updating contacts, digging into individual transactions?"*). If they under-specify ("connect my accounting"), double-check once in the same message: *"Just the numbers, or do you want me to be able to raise invoices and bills too?"* Then route: read-only headline questions → the built-in; anything that touches or digs into the books → the full service. If they want both, the built-in takes one click while you are already talking, and the full service follows.

Connect only what they named, and say in one line what you are *not* connecting and why, so they can ask for it later. Both routes can coexist on one machine - never tear one down to set the other up.

### Is Xero already connected?

Identify the calling surface first. Desktop's account and connectors can differ from the standalone CLI, even when `claude auth status` and `claude mcp list` run from Desktop's Bash. Use the app's visible account, Connectors view, and actual runtime tools for Desktop evidence; those commands describe the CLI account only. Local vendor credentials are independent of the Claude login. A working local route proves its own access, not the Desktop account's built-in connection.

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** In Desktop, discover Xero tools by name and description (the prefix can be an opaque `mcp__<id>__`) and inspect its in-app connected state where accessible. Prove it with the read below. In terminal/VS Code only, `claude mcp list` → look for a line starting `claude.ai Xero`.
   - Connected or tools present → nothing to set up on that route. Prove it with one read from the `mcp__claude_ai_Xero__*` namespace (e.g. this month's profit and loss) before saying so. If the user's need is read-only, answer it; if they want to work in the books, continue to the full service.
   - Reconnect or `! Needs authentication` → follow Step 2 of the built-in route for the same account, choose **Reconnect**, then repeat the read check.
   - No usable built-in found → continue. A missing CLI line alone does not rule out Desktop tools.
2. **The full service.** The "Detect existing Xero config" check in Phase 0 below: any `mcpServers.xero` or `mcpServers."xero-<orgslug>"` entry. If it is present and `mcp__xero__list-organisation-details` answers, say *"Xero is already connected"* and go answer the question. Never make the user redo setup.
3. **Nothing found** → run the interview, then the built-in route below, the full service (Phases 0-7), or both.

Without a shell, keep runtime tool discovery and the read check; skip only unavailable command/file checks. If nothing works, follow the interview and prove the selected route with a read in the calling session.

### The built-in route - switch on Claude's own Xero connector

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in. It covers the read-only "how is the business going" surface with no Xero fee.

**Step 1 - Check this session can see built-in connectors.** In Desktop or claude.ai chat, use that account's Connectors view and runtime tools; a terminal login does not gate the app account. For terminal/VS Code only, `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear in that CLI session: tell the user in one line that this copy of Claude is signed in a different way, and run the full service instead.

**Step 2 - Open the connector page for them.**

Say: *"I'm connecting Xero to this Claude account. I'll handle the setup and let you know if you need to sign in."* Use the browser or computer-use tools actually available for navigation and authorised connection approvals. If a surface is inaccessible, give only the next short click sequence, then resume the work.

- **Desktop first:** **+ → Connectors → Browse connectors → Xero → Connect**. If the app is inaccessible, give this exact sequence to the user. Keep the exact handoff URL opened by **Connect** in a browser profile signed into the same Claude account as Desktop. If the everyday profile differs, use a matching or isolated profile and request sign-in there as needed. Preserve the URL and its parameters; do not invent app deep links. If **Continue connecting** loops, check account matching before retrying; start a fresh in-app Connect if the handoff expired.
- **Browser or terminal/VS Code:** use `https://claude.ai/directory/xero` (public listing: `https://claude.com/connectors/xero`) in a browser signed into the calling Claude account, then **Connect to Claude**. If it fails to load, use `https://claude.ai/customize/connectors` → **Browse** → search **Xero** → **Connect**. With only a shell, use `open` on Mac, `xdg-open` on Linux, or `start ""` on Windows after checking the default browser's account. For re-authentication, choose **Reconnect** on that account's connector instead.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** In Desktop, check Xero's connected state in the app; in browser chat, check that account's Connectors view. If inaccessible, request only that status check. Step 5 remains required. The following command and status branches apply only to terminal/VS Code, never as proof for a different Desktop account: `claude mcp list` again. `claude.ai Xero … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Use the actual tools in this calling session and confirm the response belongs to the intended vendor account. Call one real read through the connector - one `mcp__claude_ai_Xero__*` tool, e.g. this month's profit and loss. Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed for the same account, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now (the profit and loss, who owes them money, the cash position). If they also wanted to work in the books, go straight on to Phase 0 of the full service.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Xero on for the organisation first. Say so plainly and stop; do not run the full service just to get past an admin gate.

---

## Phase 0: Pre-Flight Checks (Silent, Mandatory)

Run these before sending a single message to the user. Fix silently if possible.

```bash
# 1. Claude Code is installed + healthy
which claude || (echo "FAIL: Claude Code missing" && exit 1)

# 2. Node 18+ (required by @xeroapi/xero-mcp-server)
node --version | awk -F. '{if ($1 < "v18") print "NEED: upgrade Node.js"}'

# 3. npx is available
which npx || echo "NEED: npx not available"

# 4. jq is available (used for safe JSON merge)
which jq || (brew install jq --quiet 2>/dev/null || echo "NEED: install jq")

# 5. curl is available (for smoke test)
which curl || echo "FAIL: curl missing"

# 6. ~/.claude.json exists or can be created
[ -f "$HOME/.claude.json" ] || echo '{"mcpServers": {}}' > "$HOME/.claude.json"
```

### Verify Playwright MCP is wired in this session

```bash
# Check in the active session - is browser_navigate available?
# If NOT, attempt to install from the marketplace silently first:
claude mcp add-from-marketplace playwright 2>/dev/null || true
```

If after attempting to add it, Playwright MCP tools (`mcp__plugin_playwright_playwright__*`) are still unavailable, the agent says:

> "Give me two minutes - I need to get browser control set up so I can do this hands-off. You can grab a coffee."

Then the agent installs it, restarts the session, and resumes. **Do NOT proceed without Playwright MCP available.**

### Detect existing Xero config (skip reinstall)

```bash
EXISTING=$(jq -r '.mcpServers.xero.env.XERO_CLIENT_ID // empty' "$HOME/.claude.json" 2>/dev/null)
LAUNCH=$(jq -r '.mcpServers.xero.command // empty' "$HOME/.claude.json" 2>/dev/null)
if [ -n "$EXISTING" ]; then
  case "$LAUNCH" in
    */node) echo "ALREADY_CONFIGURED - skip to Phase 6 verify" ;;
    *)      echo "ALREADY_CONFIGURED_LEGACY_LAUNCH - run the Phase 4 global install and rewrite the entry, keeping the two credentials, then Phase 5" ;;
  esac
fi
```

If already configured with the absolute-`node` launch, skip to **Phase 6** and just verify. If the entry launches through `npx` (an older install of this skill), keep its Client ID and Secret, run the global install in Phase 4 and rewrite the entry in place - that launch shape hangs silently on a cold npm cache (see Phase 4). Never ask the user to redo the portal setup.

---

## Phase 1: Safety Gate - Cost + Country + Org (Mandatory)

**Send ONE message. Wait for a structured reply.** Do not proceed without all three answers.

> **"Before we start, three quick things:**
>
> **1. Cost.** Xero charges **$10 AUD a month including GST** to enable this type of connection - paid to Xero, on top of your normal subscription (outside Australia, Xero bills in that country's currency; the activation screen shows the real amount and wins over this figure).
>
> **2. Country.** This only works for Xero organisations in **Australia, New Zealand, UK, or US**.
>
> **3. Which Xero organisation** do you want me to connect? (If you only have one, just say 'the one I have'.)**
>
> **If you're happy with all three, give me your country + organisation name and I'll take it from here. You'll sign in once, then I'll do everything else."**

### Handle the reply

| User provides | Agent does |
|---|---|
| Country (AU/NZ/UK/US) + org name + implicit cost consent | Proceed to Phase 2 with `ORG_NAME` set |
| Country outside AU/NZ/UK/US | Stop cleanly: *"This path doesn't work for [country] Xero orgs yet - it covers AU, NZ, UK and US."* |
| Hesitant about cost | Answer questions calmly. Wait for explicit consent. Do not pressure. |
| Refuses cost | *"No problem - say 'connect my Xero' any time."* |
| Only one field given | Ask once for the missing field(s). Combine into one message, not multiple. |

---

## Phase 2: Autonomous Xero App Creation (Playwright-Driven)

This is the critical phase. The agent drives Playwright. The user signs in. That's the entire split of responsibilities.

### Step 2.1 - Open the Xero developer portal

```
mcp__plugin_playwright_playwright__browser_navigate
  url: https://developer.xero.com/app/manage
```

Tell the user:

> "I've opened the Xero developer site. Sign in with your Xero email and password - and your 2FA code if you have one. Tell me when you're on the My apps page."

Wait for user confirmation. Use `browser_wait_for` with a text selector for "My apps" or similar dashboard indicator.

### Step 2.2 - Verify sign-in (silent)

```
mcp__plugin_playwright_playwright__browser_snapshot
```

Scan the snapshot for:
- The user's name or email (confirms login)
- A "New app" button (confirms they're on the right page)
- Any "Verify your email" banner → handle: tell user to check their email, wait, retry

### Step 2.3 - Click "New app"

```
mcp__plugin_playwright_playwright__browser_click
  element: "New app button"
  ref: <ref from snapshot>
```

### Step 2.4 - Fill the app creation form

```
mcp__plugin_playwright_playwright__browser_fill_form
  fields:
    - name: App name
      value: "Claude Assistant"
    - name: Company or application URL
      value: "https://claude.ai"  # safe default; any valid URL works
    - name: Integration type
      value: "Custom connection"  # CRITICAL
```

If `Integration type` is a radio group or dropdown, use `browser_click` on the specific "Custom connection" option. DO NOT select "Web app" - that uses a different grant type incompatible with MCP.

### Step 2.5 - Tick terms and click Create

```
mcp__plugin_playwright_playwright__browser_click
  element: "terms and conditions checkbox"

mcp__plugin_playwright_playwright__browser_click
  element: "Create app button"
```

### Step 2.6 - Select organisation

Wait for the app detail page to load:

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Organisation"  # or whatever Xero's current label is
```

Find the organisation dropdown. Click it.

```
mcp__plugin_playwright_playwright__browser_click
  element: "organisation dropdown"
```

Snapshot the opened dropdown. Find the option matching `ORG_NAME` (from Phase 1). Click it.

```
mcp__plugin_playwright_playwright__browser_click
  element: "<ORG_NAME> option in dropdown"
```

If multiple orgs match or none match exactly:
- Tell the user: *"I see these Xero organisations: [list from dropdown]. Which one should I connect?"*
- Wait for reply, click the right one.

### Step 2.7 - Tick required scopes

Navigate to the scopes/permissions section of the app page. Scroll into view if needed.

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: "() => document.querySelector('[data-testid=\"scopes\"]')?.scrollIntoView()"
```

Tick each of these checkboxes (use `browser_click` per checkbox, targeting by label):

- `accounting.transactions`
- `accounting.transactions.read`
- `accounting.contacts`
- `accounting.contacts.read`
- `accounting.settings`
- `accounting.settings.read`
- `accounting.reports.read`

**If the user is in NZ or UK and explicitly wanted payroll, also tick:**
- `payroll.employees`, `payroll.employees.read`
- `payroll.settings`, `payroll.settings.read`
- `payroll.timesheets`, `payroll.timesheets.read`

Otherwise skip payroll - extra scopes are extra attack surface.

### Step 2.8 - Save

```
mcp__plugin_playwright_playwright__browser_click
  element: "Save button"

mcp__plugin_playwright_playwright__browser_wait_for
  text: "Saved" OR "successful" OR similar confirmation
```

### Step 2.9 - Handle activation / billing (the ~$5/mo step)

Xero will now prompt to activate the connection. This is where the charge kicks in. Two paths:

**Path A: User has a payment method already on file**

Playwright confirms the activation, Xero charges silently (or shows a confirmation). Watch for:

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Connection active" OR "Activated" OR "Subscription confirmed"
  timeout: 30000
```

If activation succeeds silently, continue to Step 2.10.

**Path B: User has no payment method on file**

Xero shows a payment form. This is the ONLY step Playwright does not fill in (credit card entry is a user-only action per security + fraud policy).

Tell the user:

> "Xero is asking for a payment method for the connection charge. Fill in your card details in the browser window I opened - I'll wait. Let me know when Xero says the connection is active."

Wait for the user's confirmation, then:

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Connection active"
  timeout: 300000  # 5 min - they may be finding their card
```

### Step 2.10 - Extract Client ID directly from the DOM

**No copy-paste. No user action. The agent reads the value.**

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: |
    () => {
      // Xero displays the Client ID in a read-only text field or <code> element
      const selectors = [
        '[data-testid="client-id"]',
        'input[name="clientId"]',
        'input[aria-label*="Client ID"]',
        'code.client-id',
        // Fallback: find the label "Client ID" and walk to the adjacent value
      ];
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (el) return el.value || el.textContent.trim();
      }
      // Fallback: label-based search
      const labels = [...document.querySelectorAll('label, dt, .label')];
      for (const lbl of labels) {
        if (/client\s*id/i.test(lbl.textContent)) {
          const val = lbl.nextElementSibling?.textContent?.trim()
                   || lbl.parentElement?.querySelector('input,code,span')?.textContent?.trim();
          if (val && val.length > 20) return val;
        }
      }
      return null;
    }
```

Store the returned value as `CLIENT_ID`. Validate: must be hex-like, 32+ chars, no whitespace. If invalid:
- `browser_snapshot` the page
- Re-inspect the DOM with a fresh selector strategy
- If still failing after 2 attempts, tell the user: *"Xero's page has changed slightly. Can you see the Client ID on the screen? Read it out and I'll catch it."* - only as a LAST resort.

### Step 2.11 - Generate + extract Client Secret

Click "Generate a secret":

```
mcp__plugin_playwright_playwright__browser_click
  element: "Generate a secret button"
```

Xero reveals the secret in a modal or inline reveal. **It's only shown once** - capture it immediately:

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: |
    () => {
      // The secret often appears in a modal <code> or <input readonly>
      const selectors = [
        '[data-testid="client-secret"]',
        'input[name="clientSecret"][readonly]',
        'input[aria-label*="Client Secret"]',
        '.modal code',
        '.reveal-secret',
      ];
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (el) {
          const v = el.value || el.textContent.trim();
          if (v && v.length > 30) return v;
        }
      }
      return null;
    }
```

Store as `CLIENT_SECRET`. Validate: 40+ chars, base64-like charset, no whitespace.

If extraction fails (selector mismatch, modal structure changed), use `browser_snapshot` to get the full accessibility tree, find the secret element by its surrounding text ("Save this secret - it will not be shown again"), and extract via ref.

If all DOM extraction attempts fail (Xero has genuinely changed their UI), fall back to:

> "Xero shows a long string on screen labelled Client Secret. Read it out to me once - I'll catch it and close the window."

Only as a last resort after 3 extraction attempts.

### Step 2.12 - Close the "save this secret" modal

```
mcp__plugin_playwright_playwright__browser_click
  element: "I've saved the secret" OR "Close" OR "Done" button
```

---

## Phase 3: Smoke Test (Silent, Mandatory)

Before writing anything to config, verify the credentials actually work. This catches UI-misread errors, missing scopes, and inactive subscriptions.

```bash
RESPONSE=$(curl -s -X POST "https://identity.xero.com/connect/token" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&scope=accounting.transactions.read accounting.contacts.read accounting.settings.read accounting.reports.read")

ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty')

if [ -n "$ACCESS_TOKEN" ]; then
  # Verify tenant is linked
  TENANT=$(curl -s -X GET "https://api.xero.com/connections" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq -r '.[0].tenantName // empty')
  [ -n "$TENANT" ] && echo "OK: linked to $TENANT" || echo "FAIL: no tenant linked"
else
  ERROR=$(echo "$RESPONSE" | jq -r '.error // .error_description // "unknown"')
  echo "FAIL: $ERROR"
fi
```

### Recovery by error type

| Error | Silent fix |
|---|---|
| `invalid_client` | Re-extract from DOM - may have caught a read-only placeholder. Retry Step 2.10-2.11 once. |
| `invalid_scope` | Return to the scopes page in Playwright, tick the specific scope named in the error, Save, retry. |
| `Connection deactivated` | The activation didn't complete. Return to Step 2.9 - check the payment flow. |
| No tenant linked | Return to Step 2.6 - organisation wasn't selected. |
| Network timeout | Retry once. If persistent, tell user: *"Xero's API is slow - give me a minute."* |

**Never show raw error text to the user.** Translate or handle silently.

---

## Phase 4: Safe Merge Into `~/.claude.json` (Silent)

Extract credentials exist and work. Write them in without touching other MCP servers.

**Install the server globally first, pinned.** `npx -y <pkg>@latest` resolves the package from the npm registry at launch time; on a cold npm cache (every first-ever install) that download outlasts Claude Code's MCP start-up window, so the server never registers its tools and nothing logs why. Installing globally during setup moves the download to a moment that can be waited on, and pinning keeps it cacheable.

```bash
PINNED_VERSION="0.0.17"
npm i -g "@xeroapi/xero-mcp-server@${PINNED_VERSION}" --silent

NODE_BIN="$(command -v node)"
SERVER_ENTRY="$(npm root -g)/@xeroapi/xero-mcp-server/dist/index.js"
[ -n "$NODE_BIN" ] || { echo "FAIL: node is not on PATH"; exit 1; }
[ -f "$SERVER_ENTRY" ] || { echo "FAIL: global install missing at $SERVER_ENTRY"; exit 1; }
```

Tell the user while it downloads: *"Installing Xero's connector - this is the slow bit, about a minute the first time."* If `npm i -g` fails with `EACCES`, point npm at a user-writable prefix (`npm config set prefix "$HOME/.npm-global"`), re-run, and re-derive `SERVER_ENTRY` from `npm root -g`. Do not fall back to `npx` to dodge this.

```bash
CLAUDE_CONFIG="$HOME/.claude.json"

# Always back up first
cp "$CLAUDE_CONFIG" "${CLAUDE_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"

# Validate JSON; if corrupt, quarantine
if ! jq empty "$CLAUDE_CONFIG" 2>/dev/null; then
  mv "$CLAUDE_CONFIG" "${CLAUDE_CONFIG}.corrupt.$(date +%Y%m%d-%H%M%S)"
  echo '{"mcpServers": {}}' > "$CLAUDE_CONFIG"
fi

# Merge xero entry via jq - NEVER overwrite the file
jq --arg cid "$CLIENT_ID" --arg sec "$CLIENT_SECRET" \
   --arg node "$NODE_BIN" --arg entry "$SERVER_ENTRY" '
  .mcpServers = (.mcpServers // {}) |
  .mcpServers.xero = {
    "command": $node,
    "args": [$entry],
    "env": {
      "XERO_CLIENT_ID": $cid,
      "XERO_CLIENT_SECRET": $sec
    }
  }
' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp" && mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"
```

### Hard rules

- Always back up with a timestamp before writing.
- Never overwrite - use `jq` to merge.
- Never echo Client ID or Client Secret in any message, log, or tool output after this point.
- If corrupt, quarantine separately - never lose user config silently, and tell the user plainly that any other connectors they had are in the quarantined file, not the new one.
- Never write `"command": "npx"`. The npx form is a last resort for a locked-down machine where a global install is genuinely impossible; if it is ever used, pin the version (`["-y", "@xeroapi/xero-mcp-server@0.0.17"]`), run the package once by hand to warm the cache, and expect the first launch after a cache clear to fail silently.

### Multi-org

If the user has multiple orgs and ran this skill a second time, write to `mcpServers."xero-<orgslug>"` instead of `mcpServers.xero`. Tools appear as `mcp__xero-<orgslug>__*`.

---

## Phase 5: Restart Claude Code (Only Human-Touch Step Besides Sign-In)

Tell the user:

> "All the setup is done on my end. **Fully quit Claude Code and reopen it** - Mac: Cmd+Q, then open again. Windows: close the window AND right-click the tray icon → Quit, then open again. Tell me when you're back. (A window refresh won't work - MCP connections only load at start-up.)"

Wait for their confirmation.

---

## Phase 6: Live Verification (Silent)

After restart, call the real MCP tool. Never report "done" before this succeeds.

```
mcp__xero__list-organisation-details
```

### Outcomes

| Outcome | Action |
|---|---|
| Returns org name + details | Report success with org name in message. Proceed to Phase 7. |
| `mcp__xero__*` tools not discoverable, and `.mcpServers.xero.command` is `npx` | The launch is resolving the package from the registry on a cold npm cache and timing out silently. No number of restarts fixes it: run the Phase 4 global install, rewrite the entry to the absolute-node shape, then quit and reopen. |
| `mcp__xero__*` tools not discoverable, and `.mcpServers.xero.command` is an absolute node path | User didn't fully quit, or the global install moved. Check `[ -f "$SERVER_ENTRY" ]`, then tell them: *"Claude Code didn't pick up the new connection. Fully quit (Cmd+Q) and reopen."* Wait + retry. |
| `invalid_client` / 401 | Trailing whitespace in saved secret. Strip + rewrite config. Retry. |
| `403 insufficient_scope` | Open Playwright back to the app's scopes, tick the missing scope named in the error, Save, retry. No restart needed. |
| Any other | Retry once. If still failing, escalate with the raw error (this is a bug worth logging). |

---

## Phase 7: Hand-Off (Short, Warm, Useful)

Tell the user they're done. Give them 3 starter prompts matched to their business. That's it.

> "Done - you're connected to **[OrgName]**. Try one of these:
>
> 1. *'Show me my unpaid invoices.'*
> 2. *'Pull my P&L for this year.'*
> 3. *'Who owes me money - sorted by how overdue.'*
>
> About 60 Xero tools are available. Ask me anything and I'll use them."

---

## Agent Behaviour Rules (Use After Setup)

These rules govern how the agent uses the connection in every future conversation.

### Writes are drafts
Invoices, bills, quotes, credit notes - always DRAFT on create. Never auto-authorise or send. Say "I've created a draft - review and approve in Xero."

### Confirm before writes
Summarise what you're about to create/update. Wait for yes.

### Verify after writes (mandatory)
After any `create-*` or `update-*` call, immediately `list-*` the affected contact's records and diff against expected state. This catches partial failures, duplicate creates, and mismatched writes.

### Currency + tax
Use the org's currency from API response. Two decimal places. Always call `list-accounts` before creating an invoice (don't guess account codes). Always call `list-tax-rates` for GST-inclusive orgs (don't guess tax codes).

### Never echo credentials
`XERO_CLIENT_ID` and `XERO_CLIENT_SECRET` never appear in any user-visible output. Not in summaries, not in debug messages, not in logs the user can see.

### Rate limits
Xero enforces ~60 calls/min per tenant. On 429, wait 10s, retry once.

---

## Troubleshooting Matrix (Agent-Internal)

| Symptom | Diagnosis | Fix |
|---|---|---|
| Playwright MCP not available at Phase 0 | Session missing the plugin | Install via `claude mcp add-from-marketplace playwright`, restart session, resume. |
| User's Xero login page won't load | Browser navigation error | `browser_navigate` again with a longer timeout. Check internet. |
| "Verify your email" banner on developer.xero.com | Unverified Xero developer account | Tell user to check their inbox, verify, then refresh. Wait for the banner to disappear. |
| App creation 500 error | Xero backend flake | Retry once. If persistent, check Xero status page. |
| Organisation dropdown is empty | User's Xero account has no orgs | Tell user: *"Your Xero account doesn't show any organisations I can connect to. Check you're signed in with the right account."* |
| Activation prompts for business details | New Xero developer account | Walk through the form via Playwright where possible; ask user only for data we can't infer. |
| Payment screen rejects the card | User's card issue | *"Xero couldn't process that card. Try a different one, or contact your bank."* Wait for retry. |
| DOM extraction of Client ID returns null | Xero changed selectors | Try 3 fallback strategies (data-testid, aria-label, label-text-walk). If all fail, last-resort user read-out. |
| Client Secret modal closes before capture | Race condition | Use `browser_wait_for` before the click. Increase timeout. |
| jq merge fails | Corrupt `~/.claude.json` | Quarantine the file, write a fresh minimal one with just the Xero entry. |
| MCP server won't start after restart | Node < 18 OR npm registry blocked | Upgrade Node. Test registry with `npm ping`. Then re-run the Phase 4 global install and confirm `[ -f "$SERVER_ENTRY" ]`. |
| First launch after a cleared npm cache never registers the tools | The entry is on the legacy `npx` launch shape | Convert it to the absolute-node shape (Phase 4). A cold cache is the normal state of a machine that has never run this before. |
| Every call returns "organisation not found" | User unlinked the org in Xero UI | Open Playwright to app page, re-select org, save. |

---

## Setup Checklist (Agent Tracks)

Do NOT tell the user "done" before every box is ticked:

- [ ] Phase 0: Claude, Node 18+, npx, jq, curl, `~/.claude.json` all present
- [ ] Phase 0: Playwright MCP available in this session (if not, installed + session restarted)
- [ ] Interview done; built-in route offered/connected where the need was read-only headline numbers
- [ ] Phase 0: no existing working config (or skipped to verify; a legacy `npx` entry rewritten in place)
- [ ] Phase 1: user confirmed AU/NZ/UK/US + cost + gave org name
- [ ] Phase 2.1-2.2: browser open to developer.xero.com, user signed in verified via snapshot
- [ ] Phase 2.3-2.5: app created as Custom Connection (not Web app)
- [ ] Phase 2.6: correct organisation selected
- [ ] Phase 2.7: all 9 required scopes ticked (+ payroll if requested)
- [ ] Phase 2.8: save confirmed via wait_for
- [ ] Phase 2.9: activation completed (subscription active)
- [ ] Phase 2.10: Client ID extracted from DOM (validated format)
- [ ] Phase 2.11: Client Secret extracted from DOM (validated format)
- [ ] Phase 3: curl smoke test returned a valid access_token
- [ ] Phase 3b: `/connections` returned a non-empty array (tenant linked)
- [ ] Phase 4: server installed globally at the pinned version; `~/.claude.json` backed up + merged (not overwritten) with the absolute-node launch
- [ ] Phase 5: user confirmed full quit + reopen
- [ ] Phase 6: `list-organisation-details` returned the correct org
- [ ] Phase 7: 3 starter prompts matched to their business

---

## The 60+ Xero MCP Tools

After setup, these are available via `mcp__xero__<name>`:

### Read (safe)

| Category | Tools |
|---|---|
| Org | `list-organisation-details` |
| Invoices | `list-invoices`, `get-invoice` |
| Contacts | `list-contacts`, `get-contact` |
| Accounts | `list-accounts` - this is the chart of accounts |
| Bank | `list-bank-transactions`, `list-payments` |
| Items | `list-items` |
| Quotes | `list-quotes` |
| Credit notes | `list-credit-notes` |
| Journals | `list-manual-journals` |
| Tax | `list-tax-rates` |
| Groups | `list-contact-groups` |
| Tracking | `list-tracking-categories` |
| Reports | `list-profit-and-loss`, `list-report-balance-sheet`, `list-trial-balance`, `list-aged-receivables-by-contact`, `list-aged-payables-by-contact` |

### Write (confirm first, then call)

| Category | Tools |
|---|---|
| Invoices | `create-invoice` (DRAFT), `update-invoice` |
| Contacts | `create-contact`, `update-contact` |
| Quotes | `create-quote`, `update-quote` |
| Credit notes | `create-credit-note`, `update-credit-note` |
| Payments | `create-payment` |
| Bank | `create-bank-transaction`, `update-bank-transaction` |
| Items | `create-item`, `update-item` |
| Journals | `create-manual-journal`, `update-manual-journal` |
| Tracking | `create-tracking-category`, `update-tracking-category`, `create-tracking-option`, `update-tracking-options` |

### Payroll (NZ/UK only)

`list-payroll-employees`, `list-payroll-employee-leave`, `list-payroll-employee-leave-balances`, `list-payroll-employee-leave-types`, `list-payroll-leave-periods`, `list-payroll-leave-types`, `list-timesheets`, `create-payroll-timesheet`, `get-payroll-timesheet`, `add-payroll-timesheet-line`, `update-payroll-timesheet-line`, `approve-payroll-timesheet`, `revert-payroll-timesheet`, `delete-payroll-timesheet`

---

## Scope Limitations (Tell User If Asked)

The full service can read + write: invoices (as drafts), contacts, quotes, credit notes, items, bank transactions, payments, manual journals, tracking. Full reports: P&L, balance sheet, trial balance, aged receivables/payables. The built-in connector is read-only and covers the headline numbers only (profit and loss, receivables, cash position, top customers) - it never changes anything.

This skill CANNOT:
- Delete records (use Xero UI)
- Send invoices by email (user sends from Xero after approving)
- Reconcile bank transactions (UI-only)
- File BAS/VAT (not exposed)
- Upload attachments (scope enabled but MCP server doesn't expose upload)
- Access Projects, Fixed Assets, Budgets, Expenses (separate Xero products)
- Connect multiple Xero orgs via a single Custom Connection (1:1 by design)

---

## Security Notes

- Client ID + Secret stored in `~/.claude.json` locally. Never committed, never transmitted except to Xero.
- 30-min access tokens, auto-refreshed by the MCP server via client_credentials grant. User never re-approves.
- Revocation: delete the app at developer.xero.com → monthly charge stops at next billing cycle.
- No data transits Selr AI or Anthropic infrastructure. All API calls are user's machine ↔ Xero.

---

## Reference

- **Official MCP server**: [github.com/XeroAPI/xero-mcp-server](https://github.com/XeroAPI/xero-mcp-server)
- **Xero Developer Portal**: [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
- **Custom Connections guide**: [developer.xero.com/documentation/guides/oauth2/custom-connections](https://developer.xero.com/documentation/guides/oauth2/custom-connections)
- **Xero API reference**: [developer.xero.com/documentation/api](https://developer.xero.com/documentation/api)
- **Sibling skills**: `hubspot-connector`, `monday-connector`, `slack-connector`, `quickbooks-connector` (all Playwright-driven autonomous connectors); see also [`skills/CLAUDE.md`](../CLAUDE.md) for the connector patterns this skill fits into (Pattern 0 for the built-in route)

---

*Built by Selr AI.*
