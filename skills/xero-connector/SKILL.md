---
name: xero-connector
description: "Read and update Xero accounting data on behalf of the user via the official @xeroapi/xero-mcp-server. Phase 1 is an autonomous Playwright-driven Custom Connection install: register the MCP server with `claude mcp add`, drive `developer.xero.com/app/manage` in the Playwright MCP browser, detect login state and prompt sign-in only if needed, autonomously create the Custom Connection (form fill + V1 scope tick + submit), let the user pick + authorise the org on Xero's consent screen, let the user complete the activation payment, then auto-extract Client ID + Secret from the DOM and write them to the registered server entry. The country/cost safety gate runs unchanged before any browser action. The user's only manual moments are signing in to Xero, picking + authorising the org on the consent screen, and confirming the activation payment. Handles invoices (list, view, create, update), contacts (list, create, update), quotes, credit notes, items, manual journals, bank transactions, payments, tax rates, trial balance, profit and loss, balance sheet, aged receivables and payables, contact groups, tracking categories, and the connected organisation's details. Also handles NZ/UK payroll tools (employees, leave, timesheets). Use this skill when the user asks about their Xero, invoices, unpaid invoices, contacts, profit and loss, balance sheet, bank transactions, chart of accounts, payments, quotes, or when they say 'connect my Xero' or 'help me set up Xero'."
allowed-tools: mcp__xero__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
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
    - skill: hubspot-connector
      reason: Sibling Playwright-driven autonomous connector — admin-portal + DOM-extract pattern, same Client-ID-style credential model
    - skill: monday-connector
      reason: Sibling Playwright-driven autonomous connector — same admin-portal create-app-and-extract-token shape
    - skill: slack-connector
      reason: Sibling Playwright-driven autonomous connector — same multi-step app-create + scope-tick + token-extract flow
    - skill: quickbooks-connector
      reason: Sibling accounting connector — similar wrap-existing-tooling pattern for a different platform
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Xero developer portal
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Xero Custom Connection or API errors
---

# Xero Connector

## Overview

This skill lets you read and update a user's Xero accounting data on their behalf using the **official first-party [`@xeroapi/xero-mcp-server`](https://github.com/XeroAPI/xero-mcp-server)** (maintained by Xero, published to npm). It has two phases:

- **Phase 1 — Install & Connect (autonomous, 9 steps after the safety gate).** Claude registers the hosted MCP server with `claude mcp add`, drives `developer.xero.com/app/manage` inside a Playwright MCP browser, detects login state, autonomously creates the Custom Connection (clicks New app, fills the form, picks the org, ticks the V1 scope set, submits), lets the user authorise the org on Xero's consent screen, lets the user complete the activation payment, then auto-extracts Client ID + Client Secret from the DOM and writes them into the registered server entry. The user's only manual moments are: (1) signing in to Xero, (2) picking + authorising the org on the consent screen, (3) confirming the activation payment. The country/cost safety gate runs unchanged before any browser action.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__xero__*` native tools to read and update Xero data. The official server exposes 51 tools; this skill documents the ~25 most commonly used and notes where the rest live.

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

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Xero, authorises the org on the consent screen, and confirms the activation payment. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md` plus these connector-specific rules:

- **You drive, not them.** Never ask the user to click menus, fill forms, copy values, or paste anything. The only verbal asks across Phase 1 are: signing in to Xero (Step 2), picking + authorising the org on Xero's consent screen (Step 4), and completing the activation payment (Step 5).
- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, client credentials, custom connection (as a technical concept), Playwright, browser automation, redirect URI, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Xero for you now"), once when you need them ("please sign in / authorise / confirm payment"), once when you're done ("your Xero is now connected"). No commentary in between.
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now — this takes just a moment."
- **React warmly.** Good: "That worked — your Xero is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo Client ID or Client Secret back to the user** after extracting them from the DOM. They are extracted, written to the registered server entry, and never surface in chat.

---

## Phase 0 — Pre-flight (silent)

### 0.1 — Resume check

Read `~/.claude.json` via Node (cross-platform safe — Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const xv = (j.mcpServers || {}).xero;
const env = xv && xv.env || {};
console.log(env.XERO_CLIENT_ID && env.XERO_CLIENT_SECRET ? 'CONFIGURED' : 'NOT_CONFIGURED');
"
```

- `CONFIGURED` → try Phase 1 Step 8 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 2 (the user may need a fresh Custom Connection).
- `NOT_CONFIGURED` → run the safety gate above, then Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest`, ask the user to close and reopen the chat, then retry.

---

## PHASE 1 — Install & Connect (autonomous via Playwright, 9 numbered steps)

This phase drives `developer.xero.com/app/manage` end-to-end inside the Playwright MCP browser. The user signs in once, picks + authorises the org on Xero's consent screen, and confirms the activation payment — that's it. Everything else (clicking New app, filling the form, ticking scopes, submitting, reading Client ID + Secret from the DOM, writing them into the registered server entry, verifying) is autonomous.

The country/cost safety gate above runs FIRST and unchanged. Do not start Step 1 until the gate has been explicitly cleared.

### Step 1 — Orient the user

Tell the user in one short message:

> "Great — let's connect your Xero. I'm opening the Xero developer page for you in a browser window. You'll need to sign in once, then on the next screens pick which Xero organisation to connect and confirm the small monthly charge — I'll handle the rest. About three minutes."

### Step 2 — Open `developer.xero.com/app/manage` inside Playwright + handle login

Drive Playwright to the Xero developer portal:

```
mcp__playwright__browser_navigate({ url: "https://developer.xero.com/app/manage" })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see the "My apps" / app-management page heading, a "New app" button, or the user's account chrome at the top, with `developer.xero.com/app/manage` in the URL) → continue to Step 3.
- **Not logged in** (Xero login form — heading reads **"Log in to Xero"** verbatim, email + password textboxes + a **Log in** button, page is on `login.xero.com/identity/user/login`; OR an SSO redirect to a third-party identity provider) → tell the user, *once*: *"Please sign in to your Xero account in the browser window I just opened — I'll wait. Same Xero account that has access to the organisation you want me to connect."* Then `mcp__playwright__browser_wait_for` polling for the post-login signal — either the **New app** button text, the **My apps** heading, or `developer.xero.com/app/manage` in the URL via `browser_evaluate`. Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

> *Live verification 2026-05-01: `developer.xero.com/app/manage` redirects unauthenticated visitors to `login.xero.com/identity/user/login?ReturnUrl=...`. The login page heading is exactly "Log in to Xero" (h2). The post-login redirect URL pattern returns through `developer.xero.com/oidc/callback.html` and lands on `developer.xero.com/app/manage`. The URL-change check is the most reliable post-login signal.*

The user may complete sign-in via password, 2FA, or SSO — all paths converge on the My apps page.

### Step 3 — Create the Custom Connection autonomously

Once on the My apps page, drive the New app form via Playwright. Each step describes a goal — re-snapshot after every action and reason about the rendered page rather than relying on hardcoded selectors. Xero's developer-portal UI may shift; the goal-based descriptions below remain valid.

#### 3a — Click "New app"

Locate the New app control by accessibility role + name (a button or link with name matching `New app`). Click it. Snapshot to confirm a creation form appears.

#### 3b — Fill the form

The form has these fields. Match each by the visible label in the snapshot, not by hardcoded selectors:

- **App name**: type `Claude Assistant`
- **Integration type**: select `Custom connection` (NOT "Web app", NOT "Mobile or desktop app")
- **Company or application URL**: type `https://selrai.com.au` (any valid URL works — this default is safe and recognisable; the user's own business URL is also fine if known)
- **Terms checkbox**: tick it

#### 3c — Pick the organisation

Custom Connections bind to one Xero organisation. Locate the organisation picker (a dropdown/combobox with `data-testid` containing `organisation`/`organization`/`org`, or a select labelled accordingly). Extract the available options via `browser_evaluate`:

```javascript
() => {
  const sel = document.querySelector('[role="combobox"], select, [data-testid*="org" i]');
  if (!sel) return { picker: false, options: [] };
  const opts = [...sel.querySelectorAll('option, [role="option"]')]
    .map(o => (o.textContent || '').trim())
    .filter(t => t.length > 0 && t.length < 80);
  return { picker: true, current: (sel.textContent || sel.value || '').trim().slice(0, 80), options: opts };
}
```

If the user has more than one organisation, narrate the choice once: *"I see you have a few Xero organisations on this account: \<list\>. Which one should I connect?"* Wait for the user's choice, then select it in the picker. If they have only one, narrate the selection: *"You only have one organisation here — **\<name\>** — so I'll use that."*

#### 3d — Tick the V1 scope set

The scope checkboxes appear in the same form (or on the next page after submitting basic info — handle whichever Xero renders). Match by the visible scope name on the label. Tick exactly these:

**Standard set (always tick):**
- `accounting.transactions`
- `accounting.contacts`
- `accounting.settings`
- `accounting.reports.read`

**Payroll set (only if the user is in NZ/UK AND wants payroll tools — ask once before ticking):**
- `payroll.employees`
- `payroll.timesheets`
- `payroll.settings`

> *Why this exact set: these are the V1 scopes the upstream `@xeroapi/xero-mcp-server` tries first. The server falls back to a granular V2 set automatically if Xero ever returns `invalid_scope` on V1 — no SKILL.md change needed when that happens. Source: `XeroAPI/xero-mcp-server/src/clients/xero-client.ts`.*

If you cannot find a checkbox for a scope name in the snapshot, take a fresh snapshot — Xero sometimes paginates scopes. If still not found, fall back: *"I couldn't find the checkbox for **\<scope\>** automatically — could you tick it for me? It should be on the same page."*

#### 3e — Submit

Click the **Create app** button. Snapshot to confirm Xero has accepted the form and shown the new app's page (an "Active connection" banner OR a "Connect" / "Authorise" button).

### Step 4 — Authorise the org on Xero's consent screen

Xero requires the user's authorisation on a consent screen before issuing credentials — this cannot be auto-clicked because it's the legal grant of org-level access.

Locate the **Connect** (or **Authorise**) button on the new app's page and click it via Playwright. Xero opens a consent screen showing the requested scopes plus an org picker (if multi-org) and an Allow button.

Tell the user in one short message:

> "Xero is now showing me the permissions screen — please pick the right organisation if there's a picker and click **Allow** to authorise the connection. I'll wait."

`mcp__playwright__browser_wait_for` polling for the redirect back to the developer portal — detect either:

- The text "Connection active" / "Active" on the app page, OR
- The URL changing back to `developer.xero.com/app/manage/` via `browser_evaluate`

```javascript
() => /developer\.xero\.com\/app\/manage/.test(window.location.href)
```

Generous timeout (5 minutes). If the user closes or cancels the consent screen, surface cleanly: *"Looks like the authorisation didn't go through — want me to try again?"*

### Step 5 — User completes the activation payment

Custom Connections cost ≈$5 USD/month per connection. Xero may now prompt the user for payment confirmation (or it may have been confirmed during Step 4 if their account already has billing set up).

Tell the user in one short message:

> "Xero will ask you to confirm the small monthly charge to activate the connection — please follow Xero's prompts to add or confirm a payment method. I'll wait."

Activation can be slow (the user may need to add a card, choose a billing region, confirm). Run `mcp__playwright__browser_wait_for` against the consent-redirect URL OR poll the page state with a generous outer timeout (10 minutes). Use this `browser_evaluate` as the polling check — repeated calls until it returns `true` or the outer timeout fires:

```javascript
() => {
  const text = document.body?.innerText || '';
  return /\bActive\b/.test(text) && /\b(Client ID|Generate a secret)\b/i.test(text);
}
```

The simplest portable shape is a `browser_wait_for` with `time: 600` against an "Active"-marker text on the page (Xero typically renders "Connection active" or "Active" near the Client ID once activated):

```
mcp__playwright__browser_wait_for({
  text: "Generate a secret",
  time: 600
})
```

Branch on what's rendered after the wait completes (or fires early):

- **Active state reached + Client ID visible** → proceed to Step 6.
- **User says they cancelled / backed out** → say: *"No problem at all — we can stop here. Come back whenever you're ready and say 'connect my Xero' to pick this back up."* Do not proceed.
- **"Payment method required" and the user has no card on file** → say: *"That's normal — Xero needs a card on file for this. Go ahead and add one when prompted; it's only charged for the connection, not a random hold."* Wait for completion.
- **Timeout (10 minutes elapsed)** → check in once: *"Still on the activation screen? Anything I can help with?"* — then retry the wait once.

### Step 6 — Auto-extract Client ID + Client Secret from the DOM

Once the connection is Active, Client ID and the **Generate a secret** button appear on the app's page. Extract both autonomously — never paste either back into chat.

#### 6a — Read Client ID via clipboard transit

`browser_evaluate` extracts the Client ID from the DOM and copies it to the OS clipboard. The function returns metadata only (length / found) — the raw value never enters the tool-call return:

```javascript
() => {
  const labels = [...document.querySelectorAll('label, dt, [data-testid*="client" i]')];
  const idLabel = labels.find(el => /client.id/i.test(el.textContent || ''));
  const container = idLabel?.closest('div, dl, fieldset') || idLabel?.parentElement;
  const valueEl = container?.querySelector('[data-testid*="value" i], code, input, dd, span');
  const text = (valueEl?.value || valueEl?.textContent || '').trim();
  // Xero Client IDs are typically 32-char alphanumeric strings
  const match = text.match(/\b[A-Za-z0-9]{30,40}\b/);
  if (match) navigator.clipboard.writeText(match[0]);
  return { found: !!match, length: match ? match[0].length : 0 };
}
```

Read the clipboard from Bash into a shell-local env var, validate length, **then wipe clipboard immediately** so the value doesn't sit in the system clipboard while Step 6b runs:

```bash
case "$(uname -s 2>/dev/null)" in
  Darwin*)  export XERO_CLIENT_ID=$(pbpaste) ;;
  Linux*)   export XERO_CLIENT_ID=$(xclip -selection clipboard -o 2>/dev/null) ;;
  MINGW*|MSYS*|CYGWIN*) export XERO_CLIENT_ID=$(powershell.exe -NoProfile -Command "Get-Clipboard" | tr -d '\r') ;;
  *) echo "UNKNOWN_PLATFORM" >&2 ;;
esac
[[ ${#XERO_CLIENT_ID} -ge 30 ]] || { echo "CLIENT_ID looked too short, retry"; exit 1; }
# Wipe clipboard now — Client ID has reached the env var
case "$(uname -s 2>/dev/null)" in
  Darwin*)  printf "" | pbcopy ;;
  Linux*)   printf "" | xclip -selection clipboard 2>/dev/null ;;
  MINGW*|MSYS*|CYGWIN*) powershell.exe -NoProfile -Command "Set-Clipboard -Value ''" ;;
esac
```

#### 6b — Click "Generate a secret" + read the Secret from the modal

Locate the **Generate a secret** button (a button with name `Generate a secret` or similar) and click it. Xero opens a modal containing the Secret value — this is shown ONCE and cannot be retrieved later, so capture it on this snapshot.

```javascript
() => {
  // After clicking "Generate a secret", a modal renders the Secret string
  const candidates = [...document.querySelectorAll('[role="dialog"] code, [role="dialog"] input, [data-testid*="secret" i]')];
  for (const el of candidates) {
    const text = (el.value || el.textContent || '').trim();
    const match = text.match(/\b[A-Za-z0-9_-]{40,80}\b/);
    if (match) {
      navigator.clipboard.writeText(match[0]);
      return { found: true, length: match[0].length };
    }
  }
  return { found: false };
}
```

Then read the Secret from clipboard the same way as the Client ID (above). Validate length:

```bash
case "$(uname -s 2>/dev/null)" in
  Darwin*)  export XERO_CLIENT_SECRET=$(pbpaste) ;;
  Linux*)   export XERO_CLIENT_SECRET=$(xclip -selection clipboard -o 2>/dev/null) ;;
  MINGW*|MSYS*|CYGWIN*) export XERO_CLIENT_SECRET=$(powershell.exe -NoProfile -Command "Get-Clipboard" | tr -d '\r') ;;
esac
[[ ${#XERO_CLIENT_SECRET} -ge 40 ]] || { echo "SECRET looked too short, retry"; exit 1; }
```

If the modal doesn't render or the Secret can't be located, fall back: *"I couldn't read the connection key automatically — could you copy it from the modal and paste it to me?"* (Last resort only — autonomous extraction should succeed in normal cases.)

**Wipe clipboard immediately after reading** so the Secret doesn't linger:

```bash
case "$(uname -s 2>/dev/null)" in
  Darwin*)  printf "" | pbcopy ;;
  Linux*)   printf "" | xclip -selection clipboard 2>/dev/null ;;
  MINGW*|MSYS*|CYGWIN*) powershell.exe -NoProfile -Command "Set-Clipboard -Value ''" ;;
esac
```

### Step 7 — Register the MCP server entry with the credentials

With both credentials captured in shell-local env vars, register the Xero MCP server entry. The credentials go directly into the registered server's `env` block; they never appear in chat or tool-call returns.

**Primary path** — `claude mcp add` with `--env` flags. The `--` separator hands off the rest of the command to the stdio server's argv:

```bash
claude mcp add xero --scope user \
  --env XERO_CLIENT_ID="$XERO_CLIENT_ID" \
  --env XERO_CLIENT_SECRET="$XERO_CLIENT_SECRET" \
  -- npx -y "@xeroapi/xero-mcp-server@latest"
```

**Fallback if `claude mcp add --env` errors** (older Claude Code version, CLI not on PATH, or unexpected output) — write the entry directly to `~/.claude.json` via the Node merge pattern (atomic rename inside Node so the swap is atomic on every platform — Mac / Linux / Windows Git Bash — and does not run if the JSON write fails):

```bash
node -e '
  const fs = require("fs"), path = require("path"), home = require("os").homedir();
  const cfg = path.join(home, ".claude.json");
  const cid = process.env.XERO_CLIENT_ID;
  const sec = process.env.XERO_CLIENT_SECRET;
  if (!cid || !sec) { console.error("MISSING_CREDS"); process.exit(1); }
  let j = {};
  if (fs.existsSync(cfg)) {
    try { j = JSON.parse(fs.readFileSync(cfg, "utf8")); }
    catch (e) {
      const backup = cfg + ".backup-" + Date.now();
      fs.copyFileSync(cfg, backup);
      console.error("CONFIG_BACKUP=" + backup);
      j = {};
    }
  }
  j.mcpServers = j.mcpServers || {};
  j.mcpServers.xero = {
    command: "npx",
    args: ["-y", "@xeroapi/xero-mcp-server@latest"],
    env: { XERO_CLIENT_ID: cid, XERO_CLIENT_SECRET: sec },
  };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

**Immediately unset the env vars** in the current shell so they don't linger:

```bash
unset XERO_CLIENT_ID XERO_CLIENT_SECRET
```

### Step 8 — Close the browser + verify

Close Playwright:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your Xero connection — let me check it works."*

Verify by calling `mcp__xero__list-organisation-details` (no arguments — returns the connected organisation's name and details; the canonical smoke call. Verified live 2026-05-07 against `@xeroapi/xero-mcp-server@0.0.16` — 51 tools enumerated, `list-organisation-details` confirmed as the org-introspection tool). The verification depends on whether the MCP server is already active in the current session:

- **Tools available + call returns the organisation details** → capture the organisation's name. Proceed to Step 9 success message including the org name.
- **Tools not yet available** (most likely on first setup, since the MCP config was just written and Claude Code hasn't reloaded the tool surface) → tell the user *"All saved. Please close and reopen the chat once, then say 'test my Xero' and I'll verify the new connection."*
- **Call returns `invalid_client` or `unauthorized`** → the Secret may have been copied incomplete on the one-time-reveal modal. Tell the user: *"Hmm, the connection didn't take — let me try once more."* Re-open Playwright with `mcp__playwright__browser_navigate({ url: "https://developer.xero.com/app/manage" })`, navigate back to the Claude Assistant app's page, and **regenerate** the Secret (Xero allows this — old Secret is invalidated). Re-run Step 6b's extract + Step 7's write. Retry verification once.
- **Call returns `403 Forbidden` or `insufficient_scope`** → "Your connection is working, but one or two extra permissions are needed. Let me sort that." Re-open Playwright, navigate back to the app's scope page, tick the missing scope (the error names it), submit. **No restart needed** for scope changes — they apply on the next API call.
- **Any other error** → "Something's not quite right — let me try once more." Retry the smoke call once. If still failing, surface in plain English (translated, never raw) and ask the user if they want to retry or stop.

### Step 9 — Success message

Tell the user, in one short message (include the connected organisation name from Step 8's verification):

> "All done! I'm now connected to your Xero organisation **\<organisation name\>**. You can ask me things like 'show me my recent invoices', 'what's my profit and loss this year?', or 'find Acme Corp in my contacts'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__xero__*` MCP tools below to answer questions and make changes in Xero. The `@xeroapi/xero-mcp-server` exposes **51 tools total**; this reference covers the ~25 most commonly used and notes where the rest live.

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
