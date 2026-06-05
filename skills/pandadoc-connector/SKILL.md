---
name: pandadoc-connector
description: "Connect and operate PandaDoc via the official first-party PandaDoc MCP server (https://mcp.pandadoc.com/v1/mcp). Phase 1 is a 6-step Playwright-driven install: register the server with `claude mcp add`, open Claude Code's OAuth start URL inside the Playwright MCP browser, detect login state and prompt sign-in only if needed, auto-click 'Allow access' and 'Authorize' on the consent screen, auto-detect the callback via `browser_wait_for`, then verify with a read-only `mcp__pandadoc__*` smoke call. The user's only manual moment is signing in to PandaDoc inside the Playwright window. Use this skill when the user asks to set up PandaDoc, connect their account, create contracts or proposals from templates, send documents for signature, track signature status, send reminder emails, search or filter documents, run analytics on document completion, expire old drafts, or any e-signature / document-automation workflow."
allowed-tools: mcp__pandadoc__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - pandadoc
    - contracts
    - e-signature
    - document-automation
    - proposals
    - sales-ops
    - mcp
  pairs-with:
    - skill: airtable-connector
      reason: Pair structured customer data (Airtable rows) with PandaDoc templates — generate one contract per row
    - skill: hubspot-connector
      reason: Generate PandaDoc contracts from HubSpot deals at the right pipeline stage
    - skill: ghl-connector
      reason: Trigger PandaDoc contract creation from GoHighLevel opportunity stage moves
    - skill: canva-connector
      reason: Sibling hosted-OAuth Playwright connector — identical install pattern (Pattern 1)
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector — identical install pattern
    - skill: atlassian-connector
      reason: Sibling hosted-bridge-OAuth Playwright connector — same install shape
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the PandaDoc consent flow
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting PandaDoc auth or API errors
---

# PandaDoc Connector

> **Install pattern:** Hosted-OAuth — see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (linear-connector).

## Overview

This skill lets you read and update a user's PandaDoc account on their behalf using the **official first-party PandaDoc MCP server** hosted at `https://mcp.pandadoc.com/v1/mcp`. It has two phases:

- **Phase 1 — Install & Auth (autonomous, 6 steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks **Allow access** and **Authorize** on the consent screen (or races against an **auto-grant** for users with a prior bridge consent — see Step 4 captured 2026-06-05), auto-detects the callback. The user's only manual moment is signing in to PandaDoc inside the Playwright window. Token storage is handled by Claude Code's MCP runtime — there is no manual `~/.claude.json` token write.

> **Captured 2026-06-05 — PandaDoc MCP is a bridge / proxy OAuth server** (same architecture as Canva). `mcp.pandadoc.com/authorize` accepts the MCP client's request, redirects through an intermediate `mcp.pandadoc.com/consent?txn_id=<opaque>` page, then re-frames to `app.pandadoc.com/oauth2/authorize/confirm?client_id=f88018a252b20dcb8987` using PandaDoc's pre-registered MCP bridge client_id. Final hop returns to `localhost:<port>/callback?code=...&state=...`. Four-hop redirect chain — debug from whichever hop returns the error.
>
> **Captured 2026-06-05 — PandaDoc supports RFC 7591 Dynamic Client Registration publicly**. POST to `mcp.pandadoc.com/register` with `{ client_name, redirect_uris }` returns a fresh `client_id` + `client_secret` with NO authentication required. Claude Code's MCP runtime mints a DCR client per `claude mcp add`, but the bridge re-frames every grant through the single pre-registered client_id `f88018a252b20dcb8987` — so user consent is **per-user-per-bridge**, not per-DCR-client. A consequence: if Rodolfo grants the bridge once, every subsequent re-install (any machine, any runtime) auto-grants without showing the consent screen.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__pandadoc__*` native tools to read and update PandaDoc data. The hosted PandaDoc MCP server provides **~50 first-party operations** across 10 categories covering document creation from templates, content updates (fields, tables, pricing, variables), status and lifecycle (send, decline, expire, mark paid), signing (order, identity verification, embedded signing), search and filtering, bulk operations and reminders, analytics and reporting, webhooks, and advanced workflows (multi-party signing, complex proposals, onboarding agreements). Exact tool names are server-side and surfaced post-registration — see *Tool Reference* below for the documented operation set, then list available tools with the `mcp__pandadoc__` prefix at runtime to discover the exact naming.

**Which phase to run** — Before any tool call, check whether the PandaDoc MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.pandadoc` entry. **Also check `claude mcp list`** for a claude.ai-Connectors-layer registration — that layer does NOT write into `mcpServers` but does show in `claude mcp list` as `claude.ai PandaDoc: https://mcp.pandadoc.com/v1/mcp - ✓ Connected`. If either signal is present, attempt a verification tool call (Phase 1 Step 6). If it succeeds, the connector is ready — skip to Phase 2. If it 401s, walk through Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **PandaDoc API keys or OAuth client secrets.** PandaDoc MCP is OAuth-only via the hosted server; there is no Bearer-token / API-key path through MCP. (PandaDoc's regular REST API supports API keys, but the MCP server is OAuth-only.) Do not ask the user for an API key.
- **A self-hosted or community PandaDoc MCP server.** PandaDoc publishes the hosted endpoint at `https://mcp.pandadoc.com/v1/mcp` as the official first-party deployment.
- **Direct PandaDoc REST API calls.** All reads and writes go through the MCP server.
- **A custom OAuth client.** Claude Code's MCP runtime owns the OAuth dance; we do not register our own client, run our own callback listener, or store tokens manually.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to PandaDoc in the Playwright window. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, PKCE, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow access / Authorize / consent → **"the Allow button"** (or "Authorize button")
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening PandaDoc for you now"), once when you need them ("please sign in"), once when you're done ("your PandaDoc is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your PandaDoc is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

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
const pd = (j.mcpServers || {}).pandadoc;
console.log(pd ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 6 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → **also check the claude.ai-layer Connectors surface** before declaring the install needed:

  ```bash
  claude mcp list 2>/dev/null | grep -iE 'pandadoc.*Connected' >/dev/null && echo CLAUDE_AI_LAYER_REGISTERED
  ```

  PandaDoc can be registered via the claude.ai web UI Connectors tab, which does NOT write into `~/.claude.json` `mcpServers` but DOES show in `claude mcp list` as `claude.ai PandaDoc: https://mcp.pandadoc.com/v1/mcp - ✓ Connected`. If the grep matches, treat as REGISTERED (the user's tool surface already exposes `mcp__claude_ai_PandaDoc__*` or, after their next reconciliation, `mcp__pandadoc__*`) and route to Phase 1 Step 6 verification.

  If neither signal matches → run full Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright npx @playwright/mcp@latest --scope user`, ask the user to close and reopen the chat, then retry.

---

## PHASE 1 — Install & Auth (6 steps, autonomous via Playwright)

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your PandaDoc now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 — Register the MCP server with `claude mcp add`

Silently register the hosted PandaDoc MCP server in the user's config:

```bash
claude mcp add pandadoc https://mcp.pandadoc.com/v1/mcp --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output) — write the entry directly to `~/.claude.json` via the Node merge pattern:

```bash
node -e '
  const fs = require("fs"), path = require("path"), home = require("os").homedir();
  const cfg = path.join(home, ".claude.json");
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
  j.mcpServers.pandadoc = { type: "http", url: "https://mcp.pandadoc.com/v1/mcp" };
  fs.writeFileSync(cfg + ".tmp", JSON.stringify(j, null, 2));
'
mv ~/.claude.json.tmp ~/.claude.json
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 3 — Acquire OAuth start URL via `mcp__pandadoc__authenticate` and open it in Playwright

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__pandadoc__authenticate()` — no args, returns the OAuth authorization URL (PandaDoc-shaped: `https://mcp.pandadoc.com/authorize?...` or `https://app.pandadoc.com/oauth/authorize?...` depending on how PandaDoc's bridge / proxy OAuth is implemented).
- `mcp__pandadoc__complete_authentication({ callback_url })` — submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path — **not** a `claude mcp` CLI subcommand.

**Tool-availability precondition.** On the very first session after `claude mcp add pandadoc ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__pandadoc__authenticate` may not be in the tool surface. If that's the case, ask the user *once*: *"I've added PandaDoc. Please close and reopen the chat once, then say 'connect to my PandaDoc' and I'll finish."* On resume, Phase 0's resume check sees the `mcpServers.pandadoc` entry and routes back into Step 3 of this flow.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__pandadoc__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see PandaDoc's consent UI — "Allow Claude access to your PandaDoc account" or similar with **Allow access** and **Authorize** buttons) → continue to Step 4.
- **Not logged in** (PandaDoc sign-in form, email/password fields, or SSO redirect) → tell the user, *once*: *"Please sign in to your PandaDoc account in the browser window I just opened — I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent text (`"Allow access"`) or any admin-block interstitial. Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

### Step 4 — Auto-click Allow access + Authorize + auto-detect callback (with auto-grant race)

> **Captured 2026-06-05 — race the consent screen against the auto-grant.** PandaDoc auto-skips the consent screen for users with a prior bridge grant. If a re-installer (or anyone who previously connected Claude to PandaDoc on any machine) starts Phase 1 again, the URL goes `mcp.pandadoc.com/authorize` → `mcp.pandadoc.com/consent` → `app.pandadoc.com/oauth2/authorize/confirm` → `localhost:<port>/callback?code=...&state=...` with NO user interaction and NO consent buttons rendered. Step 4a's `browser_wait_for({ text: "Allow access" })` would hang indefinitely.
>
> **Drive the race explicitly**: after the navigate in Step 3, poll BOTH the consent-screen marker text AND the localhost-callback URL pattern in parallel. Whichever fires first wins.
>
> ```js
> // browser_evaluate polling loop — race consent screen vs auto-grant callback
> () => {
>   const url = location.href;
>   const callbackMatch = /^http:\/\/(?:localhost|127\.0\.0\.1):\d+\/callback\?/.test(url);
>   const consentVisible = !!Array.from(document.querySelectorAll('button, [role="button"]'))
>     .find(b => /^(allow access|authorize)$/i.test((b.innerText||'').trim()));
>   return { url, callbackMatch, consentVisible };
> }
> ```
>
> - `callbackMatch === true` → **auto-granted**; skip Step 4a/4b consent clicks, capture `window.location.href` via `browser_evaluate`, submit to `mcp__pandadoc__complete_authentication`, proceed to Step 6.
> - `consentVisible === true` → standard consent flow; proceed with Step 4a's Allow-access click below.
> - Neither yet → keep polling for up to 5 minutes (user may still be signing in / typing 2FA).

#### 4a — Read scope summary, narrate, click Allow access

Snapshot the consent page. Extract the human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"], p')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 200);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items, deduplicated, plain English — never raw scope strings):

> "PandaDoc is showing the permissions screen — it's asking to: read your documents, create documents from templates, send for signature, and check signing status. Clicking **Allow access** now."

PandaDoc's consent flow is **two-button**: first click **Allow access**, then a second screen renders with an **Authorize** button. Drive both clicks:

```
mcp__playwright__browser_click({
  target: <ref of button matching role:button, name:/^allow access$/i>,
  element: "Allow access button on the PandaDoc consent screen"
})

mcp__playwright__browser_wait_for({ text: "Authorize" })

mcp__playwright__browser_click({
  target: <ref of button matching role:button, name:/^authorize$/i>,
  element: "Authorize button on the PandaDoc consent screen"
})
```

If either button cannot be located (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the button automatically — please click **Allow access** (or **Authorize**) in the browser window."*

#### 4b — Capture callback URL + submit via `complete_authentication`

PandaDoc redirects to Claude Code's localhost callback (`http://localhost:<port>/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid — that's what `complete_authentication` needs.

Wait for the redirect via a URL-pattern wait, then capture the full `window.location.href` **before** closing the browser (after close there is no page to read):

```
mcp__playwright__browser_wait_for({ time: 600 })
// Note: Playwright MCP's browser_wait_for hard-caps at 30s. Poll via
// browser_evaluate of window.location.href instead for longer waits.

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
```

If `callback_url` does not look like a `localhost`/`127.0.0.1` callback (the user may still be mid-flow), poll once more with a short wait. If after 5+ minutes there is still no callback, check in *once* with the user. Do not nag.

Then submit the callback to Claude Code's MCP runtime to finish the OAuth dance:

```
mcp__pandadoc__complete_authentication({ callback_url })
```

On success, the rest of the `mcp__pandadoc__*` tools become available **in the same session** — no chat restart needed. Proceed to Step 6 for verification.

**Failure handling.** If `complete_authentication` rejects the callback (state mismatch, expired code, malformed URL), surface a plain-English *"let me try once more"* and re-run from `mcp__pandadoc__authenticate()`.

### Step 5 — Detect admin / SSO restrictions

PandaDoc Enterprise / SSO accounts can restrict third-party app installs at the workspace level. After Step 4's Authorize click — *or* in the rare case that an admin has restricted third-party app installs and the consent flow never reached an Authorize button — PandaDoc may render an interstitial page indicating an admin restriction. Detect via `browser_evaluate` against the post-Authorize snapshot:

```javascript
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /administrator (must |approve|approval)/i,
    /admin (consent|approval) (required|needed)/i,
    /workspace administrator/i,
    /your admin/i,
    /SSO (required|enforced)/i,
    /not authorized to install/i,
  ];
  return markers.some(re => re.test(text));
}
```

If the function returns `true`, surface cleanly and exit:

> "PandaDoc is telling me your workspace administrator needs to allow this connection first. Your PandaDoc admin can allowlist the **Claude** integration in their admin console — once they do, come back and say *'connect to my PandaDoc'* and I'll finish setting up."

Close the browser, do not retry — the block is org-policy.

If the function returns `false`, the consent flow completed normally — proceed to Step 6.

> **Captured 2026-06-05 — revoking the grant.** All Claude Code → PandaDoc grants share the bridge client_id `f88018a252b20dcb8987`. To revoke (during workshop debugging or if the user wants to disconnect), have the user navigate to **PandaDoc → Settings → Integrations → Connected Apps** and revoke the entry matching this bridge client_id (UI label may surface as "Claude" or similar — TBD on next live smoke). Revoking from the PandaDoc side will invalidate the token; the SKILL re-installs cleanly via Phase 1.

### Step 6 — Verify via a read-only smoke call

```
mcp__pandadoc__<list-documents-or-similar>({ limit: 1, ... })
```

Exact tool name surfaces post-registration — list available tools with the `mcp__pandadoc__` prefix and pick a non-destructive read tool (typically a documents listing). On `200 OK`, the connection is ready.

**Smoke failure handling:**

- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403 / `plan_required`** → connection works but the user's plan doesn't grant access to that specific tool — explain plan gating and offer an alternative tool.
- **Call returns 403 with admin-block messaging** → re-run Step 5's interstitial detection and surface the admin guidance.

### Success message

Tell the user, in one short message (include the live document count if available):

> "All done! Your PandaDoc is now connected — I can see **\<N\> documents**. You can ask me things like 'create a contract from the Master Services Agreement template', 'show me documents waiting for signatures', 'send reminders to anyone who hasn't signed', or 'report on signed contracts this quarter'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__pandadoc__*` MCP tools below to answer questions and make changes in PandaDoc. The hosted PandaDoc MCP server provides **~50 first-party operations** across 10 categories.

### Tool naming convention

PandaDoc's MCP tool names will surface at runtime — list available tools with the `mcp__pandadoc__` prefix once the connection is verified to discover the exact naming. The categories below reflect PandaDoc's published capability surface; specific tool names may differ slightly (e.g. `list-documents`, `create-document-from-template`, `send-document`).

### Plan gating

PandaDoc has plan tiers (Essentials / Business / Enterprise). The published MCP docs do not enumerate plan-specific tool restrictions, but capabilities like **identity verification**, **approval workflows**, **embedded sending**, and **content library blocks** are historically plan-gated in the REST API. If a tool call returns `403 plan_required`, translate into plain English and offer a plan-appropriate alternative.

### Tool Reference — operation categories

> Every PandaDoc tool call may require a `user_intent` parameter (Canva MCP precedent — verify on first smoke). Pass it on every call: one short sentence framing the user's goal.

#### Document creation & templates

| Operation | Description | Confirmation? |
|---|---|---|
| List templates | Retrieve the workspace's available templates | Read |
| Create document from template | Instantiate a template into a draft document with pre-filled fields | **Confirm first** — creates real document |
| Create document from file upload | Upload a PDF and create a document from it | **Confirm first** |
| Create document from public URL | Create a document by referencing a hosted PDF / URL | **Confirm first** |
| Create document on behalf of member | Specify a different sender (Business+) | **Confirm first** |
| Upload PDF as new template | Save an uploaded PDF as a re-usable template | **Confirm first** |
| Inspect template fields, roles, and tokens | Read template structure for field-mapping | Read |

#### Document content management

| Operation | Description | Confirmation? |
|---|---|---|
| Pre-fill document fields | Populate fields with structured data (e.g. from Airtable rows) | **Confirm first** if document is sent / live |
| Add images to documents | Insert images into draft documents | **Confirm first** |
| Populate and update text blocks | Edit text content in drafts | **Confirm first** |
| Populate and update tables | Insert / update tabular data | **Confirm first** |
| Work with pricing tables | Build / modify pricing tables (quotes) | **Confirm first** |
| Update quotes via API | Modify quote values | **Confirm first** |
| Use variables in document titles | Reference variables in title strings | Read-then-write |
| Set up embedded editing | Generate session URLs for embedded editor | **Confirm first** |
| Set up embedded sending | Generate session URLs for embedded sending | **Confirm first** |

#### Document status & lifecycle

| Operation | Description | Confirmation? |
|---|---|---|
| Check signature completion status | Read which recipients have signed | Read |
| Retrieve full document details | Get document metadata + recipients + status | Read |
| Mark documents as paid | Update payment status | **Confirm first — affects billing records** |
| Decline documents with notes | Mark a document declined with a reason | **Confirm first — visible to recipients** |
| Expire old drafts | Set drafts to expired state | **Confirm first — bulk-safe if filtered** |
| Create, review, send contracts | Full create → review → send flow | **Confirm at send** |
| Walk through document lifecycle | Multi-step state transitions | **Confirm per state change** |
| Send through approval workflows | Route documents through approval chain (Business+) | **Confirm first** |
| Reassign documents to new senders | Transfer document ownership | **Confirm first** |

#### Signing & completion

| Operation | Description | Confirmation? |
|---|---|---|
| Send documents via API | Send a draft to recipients for signing | **CONFIRM — this is the canonical destructive op; sends real legal documents** |
| Set signing order | Specify recipient signing sequence | Pre-send config |
| Enable identity verification | Require ID verification at signing (Enterprise) | **Confirm first** |
| Embed document signing | Generate session URLs for embedded signing | **Confirm first** |
| Set post-completion redirect URLs | Redirect signers after completion | Pre-send config |
| Handle post-completion actions in embedded signing | Wire up completion callbacks | Pre-send config |
| Download completed documents | Fetch the signed PDF | Read |

#### Document search & filtering

| Operation | Description | Confirmation? |
|---|---|---|
| Full-text search across documents | Search by mentions and keywords | Read |
| Filter by tags and status | Filter document list by metadata | Read |
| Find documents expiring in date ranges | Filter by expiry date | Read |
| Find expired unsigned documents | Filter by status + age | Read |
| Locate recently modified documents | Filter by last-modified | Read |
| Search by customer association | Filter by linked customer | Read |

#### Bulk operations & reminders

| Operation | Description | Confirmation? |
|---|---|---|
| Find all documents awaiting signatures | Bulk read | Read |
| Send reminders for unsigned contracts | Send reminder emails to non-signers | **Confirm first — sends real emails to recipients** |
| Archive completed documents from folders | Bulk archive | **Confirm first** |
| Expire multiple old drafts | Bulk expire | **Confirm first — list before expiring** |

#### Analytics & reporting

| Operation | Description | Confirmation? |
|---|---|---|
| Count documents by status | Pivot count by status | Read |
| View full audit trails | Read document audit log | Read |
| Generate AI summaries of documents | LLM summary of document content | Read |
| Report on signed contracts by date range | Date-bounded report | Read |
| Extract document text for analysis | Full-text dump | Read |
| Get headline summaries for multiple documents | Multi-doc summary | Read |

#### Webhooks & notifications

| Operation | Description | Confirmation? |
|---|---|---|
| Set up webhook notifications | Register webhook endpoint | **Confirm first** |
| Verify webhook authenticity | Validate webhook signatures | Read |
| Debug and monitor webhooks | Inspect webhook delivery history | Read |

#### Advanced operations

| Operation | Description | Confirmation? |
|---|---|---|
| Create multi-party signing agreements | Document with multiple signers + roles | **Confirm first** |
| Create proposals with complex pricing and content library blocks | Rich proposal authoring | **Confirm first** |
| Create onboarding agreements with pre-filled customer data | New-customer flow | **Confirm first** |
| Extract document text in markdown format | Markdown dump | Read |

#### Error handling & diagnostics

| Operation | Description | Confirmation? |
|---|---|---|
| Diagnose document sending failures | Inspect send-error reasons | Read |
| Check document existence | Verify a document_id resolves | Read |
| Retrieve request IDs for support escalation | Pull request_id for PandaDoc support | Read |
| Retry operations with retry logic | Retry summary generation | Read |

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my PandaDoc" / "Help me set up PandaDoc" | **Run Phase 1** |
| "My PandaDoc stopped working" / "I'm getting auth errors" | Run Phase 1 from Step 3 (Claude Code re-runs the OAuth dance) |
| "List my templates" / "What templates do I have?" | List-templates |
| "Create a contract from the MSA template" / "Make a new proposal from the X template" | Inspect template fields → Create-document-from-template — **confirm first** |
| "Send the contract for Acme to signature" | Retrieve document details → **CONFIRM** — Send-document |
| "Show me documents waiting for signatures" / "Anything still unsigned?" | Find-all-documents-awaiting-signatures |
| "Check status of the Acme contract" | Check-signature-completion-status |
| "Send reminders to anyone who hasn't signed" | List unsigned → **CONFIRM** — Send-reminders-for-unsigned-contracts |
| "How many contracts did we sign this quarter?" | Report-on-signed-contracts-by-date-range |
| "Mark the Acme invoice as paid" | **CONFIRM (affects billing records)** — Mark-documents-as-paid |
| "Decline that proposal with a note" | **CONFIRM** — Decline-documents-with-notes |
| "Find all contracts expiring in the next 30 days" | Find-documents-expiring-in-date-ranges |
| "Find documents tagged 'legal-review'" | Filter-by-tags-and-status |
| "Expire any draft older than 90 days" | List drafts older than 90 days → **CONFIRM bulk** — Expire-multiple-old-drafts |
| "Summarize this signed contract" | Generate-ai-summaries-of-documents |
| "Download the signed Acme contract" | Download-completed-documents |
| "Search documents mentioning 'indemnity'" | Full-text-search-across-documents |
| "Show me the audit trail for this document" | View-full-audit-trails |
| "Reassign this draft to my colleague Jane" | **CONFIRM** — Reassign-documents-to-new-senders |
| "Set up a webhook for signed contracts" | **CONFIRM** — Set-up-webhook-notifications |

---

## Error Handling (Phase 2)

When a PandaDoc tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your PandaDoc connection has expired — let me reconnect you." | Walk Phase 1 from Step 3 (Claude Code re-runs OAuth); retry the original tool call |
| 403 Forbidden | "Your PandaDoc user doesn't have permission for that. The document owner may need to share it with you, or your admin may need to grant access." | User talks to the document owner or workspace admin |
| 403 `plan_required` | "That feature needs a paid PandaDoc plan. Identity verification, approval workflows, and content library blocks need Business or Enterprise." | User upgrades their plan, or you suggest an alternative tool |
| 404 Not Found (document / template) | "I couldn't find that — let me refresh the list." | Use list / search tools to refresh |
| 422 Invalid request | "PandaDoc rejected the request — usually a bad parameter (missing required field, recipient email malformed, template field not present)." | Re-read the template / document and reformat the call |
| 429 Rate limited | "PandaDoc is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| MCP server not running | "The PandaDoc connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Admin approval required | "Your workspace administrator has restricted this connection. They need to allowlist the Claude integration for your workspace — once done, the sign-in will work for you and your team." | PandaDoc workspace admin allowlists the integration |
| Any other API error | "Something went wrong with PandaDoc — let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The PandaDoc MCP connector **can** do (via the official PandaDoc MCP server):

- Create documents from templates, file uploads, or public URLs
- Update document content (fields, text blocks, tables, pricing tables, quotes, variables, images)
- Manage document lifecycle (send, decline, expire, mark paid, reassign, approval workflows)
- Configure signing (signing order, identity verification, embedded signing, post-completion redirects)
- Search and filter documents (full-text, by tags, status, expiry, customer)
- Run bulk operations (find unsigned, send reminders, archive completed, expire drafts)
- Generate analytics and reports (status counts, audit trails, AI summaries, date-bounded reports, text extraction)
- Set up and verify webhooks
- Build advanced workflows (multi-party signing, complex proposals, onboarding agreements)
- Diagnose document send failures and retrieve support escalation IDs

The PandaDoc MCP connector **cannot** do (needs the PandaDoc UI or other tools):

- **Delete documents permanently.** Use the PandaDoc UI to delete; MCP supports archive / expire only.
- **Connect via API key.** PandaDoc MCP is OAuth-only. No Bearer-token fallback through this skill.
- **Bypass plan gating** — identity verification, approval workflows, content library blocks may require Business+ / Enterprise plans.
- **Bypass admin allowlisting** — if the admin blocks third-party integrations, the only option is for the admin to allowlist Claude.
- **Connect multiple PandaDoc accounts simultaneously** — one connection per `~/.claude.json` entry.

---

## Behaviour Guidelines (Phase 2)

- **Every PandaDoc tool call may require a `user_intent` parameter** — Canva MCP precedent (every Canva tool's schema declares `user_intent` as Mandatory). Pass a one-sentence framing of the user's goal on every call; verify on first smoke.
- **Always confirm before sending, declining, marking paid, reassigning, expiring, or archiving** — these are destructive operations that affect REAL legal documents and may notify recipients or change billing records. Summarise what you are about to do and wait for the user's OK before firing.
- **`send-document` is the canonical destructive op** — it sends real legal documents to real recipients via email. Always re-read the document title, recipient names, and recipient emails back to the user before sending, in plain English: *"I'm about to send 'Master Services Agreement - Acme Corp' to John Smith (john@acme.com) and Jane Doe (jane@acme.com) for signature. OK?"*
- **Bulk reminder sends need an explicit count + sample** — before `Send-reminders-for-unsigned-contracts`, surface: *"I'm about to send reminder emails to 14 recipients across 9 unsigned contracts. Examples: John Smith (Acme MSA, sent 12 days ago), Jane Doe (Beta SOW, sent 8 days ago)... OK to send all 14?"*
- **`Mark-documents-as-paid` affects billing records** — this is not a UI flag; downstream invoicing systems may consume it. Confirm with extra care: *"This will mark the Acme invoice as paid in your PandaDoc records. If your accounting software syncs with PandaDoc, this will flow through. OK?"*
- **Discover IDs before writing** — PandaDoc documents and templates are referenced by opaque IDs. Always call list / search tools once per session before any write or send, unless you already have the IDs from earlier in the conversation.
- **Respect plan gating before calling** — if you're unsure of the user's PandaDoc plan, attempt the call and translate the `403` / `plan_required` response into plain English.
- **Documents often contain confidential content** — contracts, NDAs, customer data, pricing. Never dump full document content into a public log without checking with the user first. Prefer titles and recipient counts over full text dumps.
- **Present documents clearly** — format results as readable lists or summaries, not raw JSON. For document lists, show title, status, recipient count, last-modified-date.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 47 documents; 12 are awaiting signatures"), then offer to show details.
- **Pagination** — default to 25 documents per response unless the user asks for more. Offer to show more if there are additional pages.
- **Never log or echo connection details** — never paste the contents of `~/.claude.json` to the user.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **canva-connector**: Most recent sibling Pattern 1 connector; canonical reference for the captured-smoke shape
- **atlassian-connector**: Sibling hosted-bridge-OAuth Playwright connector
- **calendly-connector**: Sibling hosted-OAuth Playwright connector
- **jotform-connector**: Sibling hosted OAuth-only MCP connector — identical install pattern
- **airtable-connector**: Pair structured customer data with PandaDoc template fields — generate one contract per row
- **hubspot-connector**: Generate PandaDoc contracts from HubSpot deals at the right pipeline stage
- **ghl-connector**: Trigger PandaDoc contract creation from GoHighLevel opportunity stage moves
- **playwright-skill**: The Playwright MCP browser is how this skill drives the PandaDoc consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting PandaDoc auth or API errors
