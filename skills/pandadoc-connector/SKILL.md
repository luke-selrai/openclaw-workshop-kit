---
name: pandadoc-connector
description: "Connect PandaDoc to Claude by installing and authenticating its official MCP server. Use when the user asks to set up or connect PandaDoc, or wants contract, proposal or e-signature work (templates, sending for signature, signing status) and PandaDoc isn't connected yet. Once connected, PandaDoc runs directly through the mcp__pandadoc__* tools."
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
      reason: Pair structured customer data (Airtable rows) with PandaDoc templates - generate one contract per row
    - skill: hubspot-connector
      reason: Generate PandaDoc contracts from HubSpot deals at the right pipeline stage
    - skill: ghl-connector
      reason: Trigger PandaDoc contract creation from GoHighLevel opportunity stage moves
    - skill: canva-connector
      reason: Sibling hosted-OAuth Playwright connector - identical install pattern (Pattern 1)
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector - identical install pattern
    - skill: atlassian-connector
      reason: Sibling hosted-bridge-OAuth Playwright connector - same install shape
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the PandaDoc consent flow
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting PandaDoc auth or API errors
---

# PandaDoc Connector

> **Install pattern:** Hosted-OAuth - see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (linear-connector).

## Overview

This skill lets you read and update a user's PandaDoc account on their behalf using the **official first-party PandaDoc MCP server** hosted at `https://mcp.pandadoc.com/v1/mcp`. It has two phases:

- **Phase 1 - Install & Auth (autonomous, 6 steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks **Allow access** and **Authorize** on the consent screen (or races against an **auto-grant** for users with a prior bridge consent - see Step 4 captured 2026-06-05), auto-detects the callback. The user's only manual moment is signing in to PandaDoc inside the Playwright window. Token storage is handled by Claude Code's MCP runtime - there is no manual `~/.claude.json` token write.

> **Captured 2026-06-05 - PandaDoc MCP is a bridge / proxy OAuth server** (same architecture as Canva). `mcp.pandadoc.com/authorize` accepts the MCP client's request, redirects through an intermediate `mcp.pandadoc.com/consent?txn_id=<opaque>` page, then re-frames to `app.pandadoc.com/oauth2/authorize/confirm?client_id=f88018a252b20dcb8987` using PandaDoc's pre-registered MCP bridge client_id. Final hop returns to `localhost:<port>/callback?code=...&state=...`. Four-hop redirect chain - debug from whichever hop returns the error.
>
> **Captured 2026-06-05 - Claude Code uses the client-id-metadata-document flow, not DCR.** Live, `mcp__pandadoc__authenticate()` returns a URL whose `client_id` is the metadata-document URL `https://claude.ai/oauth/claude-code-client-metadata` (PandaDoc's well-known declares `client_id_metadata_document_supported: true`). PandaDoc's RFC 7591 Dynamic Client Registration endpoint (`mcp.pandadoc.com/register`) *is* publicly reachable with no auth - but the Claude Code runtime does **not** use it for this server; it presents the metadata document instead. The bridge re-frames the grant through PandaDoc's pre-registered MCP bridge client_id `f88018a252b20dcb8987` at the `app.pandadoc.com/oauth2/authorize/confirm` hop, so consent is **per-user-per-bridge**: once a user grants the bridge, every subsequent re-install (any machine, any runtime) auto-grants without showing the consent screen. **Verified live 2026-06-05** - a re-auth from a fresh chat went `mcp.pandadoc.com/authorize` → `mcp.pandadoc.com/consent?txn_id=<opaque>` → straight to `localhost:<port>/callback?code=...` with no consent buttons rendered.
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__pandadoc__*` native tools to read and update PandaDoc data. The hosted PandaDoc MCP server provides **22 first-party tools across 3 namespaces** (verified live 2026-06-05): `documents_*` (15 tools - create, update, send, search, status, content, summary, audit, archive), `recipients_*` (4 tools - add CC, edit, reassign, delete), and `templates_*` (3 tools - list, details, create-from-PDF). Tool names follow a `namespace_object_verb` snake_case convention (e.g. `documents_list`, `templates_details_get`). See *Tool Reference* below for the full verified contract. You can always re-list the live surface with the `mcp__pandadoc__` prefix to confirm.

**Which phase to run** - Before any tool call, check whether the PandaDoc MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.pandadoc` entry. **Also check `claude mcp list`** for a claude.ai-Connectors-layer registration - that layer does NOT write into `mcpServers` but does show in `claude mcp list` as `claude.ai PandaDoc: https://mcp.pandadoc.com/v1/mcp - ✓ Connected`. If either signal is present, attempt a verification tool call (Phase 1 Step 6). If it succeeds, the connector is ready - skip to Phase 2. If it 401s, walk through Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **PandaDoc API keys or OAuth client secrets.** PandaDoc MCP is OAuth-only via the hosted server; there is no Bearer-token / API-key path through MCP. (PandaDoc's regular REST API supports API keys, but the MCP server is OAuth-only.) Do not ask the user for an API key.
- **A self-hosted or community PandaDoc MCP server.** PandaDoc publishes the hosted endpoint at `https://mcp.pandadoc.com/v1/mcp` as the official first-party deployment.
- **Direct PandaDoc REST API calls.** All reads and writes go through the MCP server.
- **A custom OAuth client.** Claude Code's MCP runtime owns the OAuth dance; we do not register our own client, run our own callback listener, or store tokens manually.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work, the user only signs in to PandaDoc in the Playwright window. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, PKCE, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow access / Authorize / consent → **"the Allow button"** (or "Authorize button")
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening PandaDoc for you now"), once when you need them ("please sign in"), once when you're done ("your PandaDoc is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your PandaDoc is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0 - Pre-flight (silent)

### 0.1 - Resume check

Read `~/.claude.json` via Node (cross-platform safe - Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

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

- `REGISTERED` → try Phase 1 Step 6 (verify) first. If it succeeds, the connector is already active - surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → **also check the claude.ai-layer Connectors surface** before declaring the install needed:

  ```bash
  claude mcp list 2>/dev/null | grep -iE 'pandadoc.*Connected' >/dev/null && echo CLAUDE_AI_LAYER_REGISTERED
  ```

  PandaDoc can be registered via the claude.ai web UI Connectors tab, which does NOT write into `~/.claude.json` `mcpServers` but DOES show in `claude mcp list` as `claude.ai PandaDoc: https://mcp.pandadoc.com/v1/mcp - ✓ Connected`. If the grep matches, treat as REGISTERED (the user's tool surface already exposes `mcp__claude_ai_PandaDoc__*` or, after their next reconciliation, `mcp__pandadoc__*`) and route to Phase 1 Step 6 verification.

  If neither signal matches → run full Phase 1 from Step 1.

### 0.2 - Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the setup prompt in `docs/start/setup.md` (its Step 6 installs the Claude CLI). If Playwright MCP is missing, install autonomously with `claude mcp add playwright npx @playwright/mcp@latest --scope user`, ask the user to close and reopen the chat, then retry.

---

## PHASE 1 - Install & Auth (6 steps, autonomous via Playwright)

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your PandaDoc now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 - Register the MCP server with `claude mcp add`

Silently register the hosted PandaDoc MCP server in the user's config:

```bash
claude mcp add pandadoc https://mcp.pandadoc.com/v1/mcp --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output) - write the entry directly to `~/.claude.json` via the Node merge pattern:

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

### Step 3 - Acquire OAuth start URL via `mcp__pandadoc__authenticate` and open it in Playwright

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__pandadoc__authenticate()` - no args, returns the OAuth authorization URL. **Verified live 2026-06-05:** the URL is `https://mcp.pandadoc.com/authorize?response_type=code&client_id=https%3A%2F%2Fclaude.ai%2Foauth%2Fclaude-code-client-metadata&code_challenge=<...>&code_challenge_method=S256&redirect_uri=http%3A%2F%2Flocalhost%3A<port>%2Fcallback&state=<...>&scope=read+read%2Bwrite`. Note the `client_id` is the **client-id-metadata-document URL** `https://claude.ai/oauth/claude-code-client-metadata` (PandaDoc's well-known declares `client_id_metadata_document_supported: true`), **not** a per-install DCR-minted client_id. Scope is the coarse `read read+write` pair.
- `mcp__pandadoc__complete_authentication({ callback_url })` - submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path - **not** a `claude mcp` CLI subcommand.

**Tool-availability precondition.** On the very first session after `claude mcp add pandadoc ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__pandadoc__authenticate` may not be in the tool surface. If that's the case, ask the user *once*: *"I've added PandaDoc. Please close and reopen the chat once, then say 'connect to my PandaDoc' and I'll finish."* On resume, Phase 0's resume check sees the `mcpServers.pandadoc` entry and routes back into Step 3 of this flow.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__pandadoc__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see PandaDoc's consent UI - "Allow Claude access to your PandaDoc account" or similar with **Allow access** and **Authorize** buttons) → continue to Step 4.
- **Not logged in** (PandaDoc sign-in form, email/password fields, or SSO redirect) → tell the user, *once*: *"Please sign in to your PandaDoc account in the browser window I just opened - I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent text (`"Allow access"`) or any admin-block interstitial. Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

### Step 4 - Auto-click Allow access + Authorize + auto-detect callback (with auto-grant race)

> **Captured 2026-06-05 - race the consent screen against the auto-grant.** PandaDoc auto-skips the consent screen for users with a prior bridge grant. If a re-installer (or anyone who previously connected Claude to PandaDoc on any machine) starts Phase 1 again, the URL goes `mcp.pandadoc.com/authorize` → `mcp.pandadoc.com/consent` → `app.pandadoc.com/oauth2/authorize/confirm` → `localhost:<port>/callback?code=...&state=...` with NO user interaction and NO consent buttons rendered. Step 4a's `browser_wait_for({ text: "Allow access" })` would hang indefinitely.
>
> **Drive the race explicitly**: after the navigate in Step 3, poll BOTH the consent-screen marker text AND the localhost-callback URL pattern in parallel. Whichever fires first wins.
>
> ```js
> // browser_evaluate polling loop - race consent screen vs auto-grant callback
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

#### 4a - Read scope summary, narrate, click Allow access

Snapshot the consent page. Extract the human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"], p')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 200);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items, deduplicated, plain English - never raw scope strings):

> "PandaDoc is showing the permissions screen - it's asking to: read your documents, create documents from templates, send for signature, and check signing status. Clicking **Allow access** now."

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

If either button cannot be located (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the button automatically - please click **Allow access** (or **Authorize**) in the browser window."*

#### 4b - Capture callback URL + submit via `complete_authentication`

PandaDoc redirects to Claude Code's localhost callback (`http://localhost:<port>/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid - that's what `complete_authentication` needs.

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

On success, the rest of the `mcp__pandadoc__*` tools become available **in the same session** - no chat restart needed. Proceed to Step 6 for verification.

**Failure handling.** If `complete_authentication` rejects the callback (state mismatch, expired code, malformed URL), surface a plain-English *"let me try once more"* and re-run from `mcp__pandadoc__authenticate()`.

### Step 5 - Detect admin / SSO restrictions

PandaDoc Enterprise / SSO accounts can restrict third-party app installs at the workspace level. After Step 4's Authorize click - *or* in the rare case that an admin has restricted third-party app installs and the consent flow never reached an Authorize button - PandaDoc may render an interstitial page indicating an admin restriction. Detect via `browser_evaluate` against the post-Authorize snapshot:

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

> "PandaDoc is telling me your workspace administrator needs to allow this connection first. Your PandaDoc admin can allowlist the **Claude** integration in their admin console - once they do, come back and say *'connect to my PandaDoc'* and I'll finish setting up."

Close the browser, do not retry - the block is org-policy.

If the function returns `false`, the consent flow completed normally - proceed to Step 6.

> **Captured 2026-06-05 - revoking the grant.** All Claude Code → PandaDoc grants share the bridge client_id `f88018a252b20dcb8987`. To revoke (during workshop debugging or if the user wants to disconnect), have the user navigate to **PandaDoc → Settings → Integrations → Connected Apps** and revoke the entry matching this bridge client_id (UI label may surface as "Claude" or similar - TBD on next live smoke). Revoking from the PandaDoc side will invalidate the token; the SKILL re-installs cleanly via Phase 1.

### Step 6 - Verify via a read-only smoke call

```
mcp__pandadoc__documents_list({ count: 1 })
```

**Verified live 2026-06-05** - `documents_list` is the canonical read smoke. It returns `{"results": [...]}` (an empty `{"results": []}` on a brand-new account is still a success - the connection is ready). Do **not** pass a `user_intent` argument - PandaDoc tool schemas are `additionalProperties: false` and will reject unknown fields (see Tool Reference).

**Smoke failure handling:**

- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403 / `plan_required`** → connection works but the user's plan doesn't grant access to that specific tool - explain plan gating and offer an alternative tool.
- **Call returns 403 with admin-block messaging** → re-run Step 5's interstitial detection and surface the admin guidance.

### Success message

Tell the user, in one short message (include the live document count if available):

> "All done! Your PandaDoc is now connected - I can see **\<N\> documents**. You can ask me things like 'create a contract from the Master Services Agreement template', 'show me documents waiting for signatures', 'send reminders to anyone who hasn't signed', or 'report on signed contracts this quarter'. Give it a try!"

---

## PHASE 2 - Use Tools

Once the connector is configured, use the `mcp__pandadoc__*` MCP tools below to answer questions and make changes in PandaDoc. The hosted PandaDoc MCP server exposes **22 first-party tools across 3 namespaces** - `documents_*` (15), `recipients_*` (4), `templates_*` (3) - all verified live 2026-06-05 against a real PandaDoc account.

### Tool naming convention

Tool names follow a `namespace_object_verb` snake_case convention: `documents_list`, `documents_create`, `templates_details_get`, `recipients_reassign`. They are **not** kebab-case - there is no `list-documents`, `create-document-from-template`, or `send-document`. You can re-list the live surface with the `mcp__pandadoc__` prefix at any time to confirm.

> **No `user_intent` parameter - and passing one breaks the call.** Unlike Canva MCP, PandaDoc tools do **not** accept a `user_intent` field. Every PandaDoc tool schema declares `additionalProperties: false`, so passing `user_intent` (or any other undocumented field) is **rejected with a validation error**. Pass only the documented parameters below. (Verified live 2026-06-05 - the Canva precedent does not carry over.)

### Plan gating

PandaDoc has plan tiers (Essentials / Business / Enterprise). The MCP docs do not enumerate plan-specific tool restrictions, but capabilities like **identity verification** (the `verification_settings` recipient param), **approval workflows** (the `selected_approvers` param on `documents_send`), and **content library blocks** (the `content_placeholders` param on `documents_create`) are historically plan-gated in the REST API. If a tool call returns `403 plan_required`, translate into plain English and offer a plan-appropriate alternative.

### Document status codes

Several tools speak in integer status codes - `documents_list` / `documents_search` filter by them, `documents_status_change` sets them:

| Code | Status | Code | Status |
|---|---|---|---|
| 0 | draft | 7 | approved |
| 1 | sent | 8 | rejected |
| 2 | completed | 9 | waiting_pay |
| 3 | uploaded | 10 | paid |
| 4 | error | 11 | voided / expired\* |
| 5 | viewed | 12 | declined |
| 6 | waiting_approval | 13 | external_review |

\* Code 11 is labelled `voided` by `documents_list` but `expired` by `documents_search` / `documents_status_change` - PandaDoc's own surface is inconsistent here. `documents_status_change` accepts only **2 (completed), 10 (paid), 11 (expired), 12 (declined)**.

### Tool Reference - the 22 verified tools

#### `templates_*` - templates (3)

| Tool | Key params | Description | Confirmation? |
|---|---|---|---|
| `templates_list` | `q`, `tag`, `folder_uuid`, `count`, `page`, `shared`, `deleted` | List / filter the workspace's templates | Read |
| `templates_details_get` | `template_id` | Template structure: roles, fields, tokens, pricing, content placeholders | Read |
| `templates_create` | `url` (HTTPS PDF), `name`, `folder_uuid`, `tokens`, `owner_email` | Create a re-usable template **from a public PDF URL** (no file-upload path) | **Confirm - creates a real template** |

#### `documents_*` - read (8)

| Tool | Key params | Description | Confirmation? |
|---|---|---|---|
| `documents_list` | `count`, `page`, `q`, `status` (int), `tag`, `folder_uuid` | Paginated listing with structured filters | Read |
| `documents_search` | `query` (req), `status` (int[]), `date_filter_column`+`from_date`+`to_date` | Full-text search with status / date-window filters | Read |
| `documents_details_get` | `document_id` | Full details incl **per-recipient signing progress**, fields, pricing | Read |
| `documents_status_get` | `document_id` | Overall document status only (lighter than details) | Read |
| `documents_content_get` | `document_id`, `content_format` (`plaintext`/`markdown`) | Document text content - **text only, not the signed PDF** | Read |
| `documents_summary_get` | `document_id`, `summary_type` (`detailed`/`short`/`headline`) | AI summary; returns `{retry_after:N}` when not ready | Read |
| `documents_metadata_get` | `document_id`, `limit`, `offset` | AI-extracted metadata fields; `{code, retry_after?}` envelope when pending | Read |
| `documents_audit_trail_get` | `document_id` | Document audit log | Read |

#### `documents_*` - write (7)

| Tool | Key params | Description | Confirmation? |
|---|---|---|---|
| `documents_create` | `template_uuid`, `name`, `recipients` (all req); plus `fields`, `tokens`, `pricing_tables`, `tables`, `texts`, `images`, `content_placeholders`, `tags`, `folder_uuid`, `metadata`, `owner` | Create a draft **from a template**. Identity verification (`recipients[].verification_settings`), signing order (`recipients[].signing_order`), pricing tables, and content-library blocks are all **params here - not separate tools** | **Confirm - creates a real document** |
| `documents_create_from_markdown` | `name`, `document_markdown` (req); `recipients`, `role_fields`, `folder_id` | Create a draft from markdown text (supports PandaDoc `[Variable]` / `[[field]]` syntax). Async: starts `UPLOADED` → `DRAFT` | **Confirm - creates a real document** |
| `documents_update` | `document_id` (req); `name`, `fields`, `texts`, `tokens`, `pricing_tables`, `tables`, `images`, `recipients`, `tags`, `metadata` | Update a **draft** (must be `document.draft`). The `recipients` param replaces the entire list - use `recipients_*` for single edits | **Confirm first** |
| `documents_fields_assign` | `document_id` (req), `assignments` (`[{field_id, recipient_id\|null}]`) | Assign / reassign / unassign fields to recipients (draft only) | **Confirm first** |
| `documents_send` | `document_id` (req); `message`, `subject`, `silent`, `sender`, `reply_to`, `forwarding_settings`, `selected_approvers` | **Send a draft to recipients for signature.** Approval workflows via `selected_approvers`; change sender via `sender`; suppress emails via `silent` | **CONFIRM - canonical destructive op; sends real legal documents** |
| `documents_status_change` | `document_id` (req), `status` (req: 2/10/11/12); `note`, `notify_recipients` | Manually set completed / paid / expired / declined - one tool covers all four | **Confirm - affects records; may notify recipients** |
| `documents_archive` | `document_id` (req) | Archive (reversible delete, `forever=false`) | **Confirm first** |

#### `recipients_*` - recipients (4)

| Tool | Key params | Description | Confirmation? |
|---|---|---|---|
| `recipients_add_cc` | `document_id`, `contact_id` (req); `kind` | Add a CC (non-signing) recipient by existing contact ID | **Confirm first** |
| `recipients_edit` | `document_id`, `recipient_id` (req); `email`/`first_name`/`company`/… | Edit one recipient's details in place (cannot change a signer's email after they sign) | **Confirm first** |
| `recipients_reassign` | `document_id`, `recipient_id`, `new_contact_id` (req); `kind` | Replace a **signer** with another contact (transfers their fields). Cannot reassign already-signed recipients | **Confirm first** |
| `recipients_delete` | `document_id`, `recipient_id` (req) | Remove a recipient (signers draft-only; CC any status except Expired/Declined) | **Confirm first** |

### What the server does NOT expose as tools

Earlier drafts of this SKILL documented these as operations; they have **no backing MCP tool** (verified live 2026-06-05). Do not promise them - explain the gap and point to the PandaDoc UI:

- **No reminder tool.** There is no "send reminder to unsigned recipients" endpoint. You can *find* unsigned documents (`documents_list` / `documents_search` with `status:[1]`) and report them, but you cannot auto-remind through MCP.
- **No webhook tools.** No webhook registration, verification, or monitoring.
- **No signed-PDF download.** `documents_content_get` returns **text** (plaintext / markdown), not the signed PDF binary.
- **No embedded editing / sending / signing session-URL tools**, and **no standalone identity-verification or signing-order tools** - identity verification (`verification_settings`) and signing order (`signing_order`) are *recipient parameters* on `documents_create` / `documents_update`.
- **No file-upload document creation** - documents come from a template (`documents_create`) or markdown (`documents_create_from_markdown`); only *templates* can be created from a source (a PDF URL).
- **No "reassign sender / transfer ownership" tool** - `recipients_reassign` swaps a *signer*, not the sender. Change the sender via `documents_send`'s `sender` param (at send) or `documents_create`'s `owner`.

### Response shapes (captured live 2026-06-05)

Real payloads from a live draft (created recipient-less, read, then archived):

- **`documents_list`** → `{"results":[ {id, name, status, date_created, date_modified, date_completed, expiration_date, version, document_url} ]}` (bare `{"results":[]}` when empty).
- **`documents_search`** → `{"total":N, "has_next_page":bool, "scope":"full", "results":[...]}` - a **richer envelope than `documents_list`** (note `total` / `has_next_page` for pagination).
- **`documents_details_get`** → rich object incl. `id`, `status`, `ref_number`, `folder_uuid`, `created_by{id, membership_id, email, first_name, last_name}`, `tokens:[{name,value}]`, `fields:[]`, `pricing:{tables,quotes,total}`, `recipients:[]`, `grand_total:{amount,currency}`, `metadata`, `approval_execution`. (For a markdown-created draft, `uuid` can be `null` - use `id`.)
- **`documents_create` / `documents_create_from_markdown`** → returns immediately with `status:"document.uploaded"` and an `info_message` telling you to poll. **Async** - poll `documents_status_get` until `status:"document.draft"` before updating/sending.
- **`documents_content_get` / `documents_summary_get` / `documents_metadata_get`** → return `{"retry_after":N}` (seconds) while still rendering/extracting; retry after the delay. `summary`/`metadata` may also return `{code:"not_started", ...}` until the document is completed.
- **`documents_status_get`** → `{"id":..., "status":"document.<state>"}`.
- **`documents_archive`** → `{"archived":true, "document_id":..., "forever":false}` (reversible).

> Note: monetary fields carry the account's currency (e.g. `grand_total:{amount:"0", currency:"PHP"}`) - don't assume USD.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my PandaDoc" / "Help me set up PandaDoc" | **Run Phase 1** |
| "My PandaDoc stopped working" / "I'm getting auth errors" | Run Phase 1 from Step 3 (Claude Code re-runs the OAuth dance) |
| "List my templates" / "What templates do I have?" | `templates_list` |
| "Create a contract from the MSA template" | `templates_details_get` (read fields/roles) → **CONFIRM** → `documents_create` |
| "Draft an NDA from this text" | **CONFIRM** → `documents_create_from_markdown` |
| "Change the price / fix a field on that draft" | **CONFIRM** → `documents_update` (draft only) |
| "Send the contract for Acme to signature" | `documents_details_get` (re-read recipients) → **CONFIRM** → `documents_send` |
| "Show me documents waiting for signatures" / "Anything still unsigned?" | `documents_list` / `documents_search` with `status:[1]` (sent) |
| "Check status of the Acme contract" | `documents_status_get` (overall) or `documents_details_get` (per-recipient) |
| "Remind anyone who hasn't signed" | `documents_list` `status:[1]` → **report the list** (no reminder tool - explain you can't auto-send reminders through PandaDoc) |
| "How many contracts did we sign this quarter?" | `documents_search` `status:[2]` + `date_filter_column:signature_date` + date window |
| "Mark the Acme invoice as paid" | **CONFIRM (affects records)** → `documents_status_change` (`status:10`) |
| "Decline that proposal with a note" | **CONFIRM** → `documents_status_change` (`status:12`, `note`) |
| "Expire / void that document" | **CONFIRM** → `documents_status_change` (`status:11`) |
| "Find all contracts expiring in the next 30 days" | `documents_search` with `date_filter_column:date_expiration` + date window |
| "Find documents tagged 'legal-review'" | `documents_list` with `tag:["legal-review"]` |
| "Summarize this signed contract" | `documents_summary_get` (`summary_type:"short"`) |
| "Get the text of the Acme contract" | `documents_content_get` (`content_format:"markdown"`) - text only |
| "Download the signed Acme PDF" | **No tool** - MCP returns text only; direct them to the PandaDoc UI for the PDF |
| "Search documents mentioning 'indemnity'" | `documents_search` (`query:"indemnity"`) |
| "Show me the audit trail for this document" | `documents_audit_trail_get` |
| "Add my colleague as a CC on this" | **CONFIRM** → `recipients_add_cc` |
| "Replace the signer Jane with John" | **CONFIRM** → `recipients_reassign` |
| "Fix the signer's email address" | **CONFIRM** → `recipients_edit` |
| "Archive that completed contract" | **CONFIRM** → `documents_archive` |
| "Set up a webhook for signed contracts" | **No tool** - webhooks aren't available through MCP; direct to the PandaDoc UI |

---

## Error Handling (Phase 2)

When a PandaDoc tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your PandaDoc connection has expired - let me reconnect you." | Walk Phase 1 from Step 3 (Claude Code re-runs OAuth); retry the original tool call |
| 403 Forbidden | "Your PandaDoc user doesn't have permission for that. The document owner may need to share it with you, or your admin may need to grant access." | User talks to the document owner or workspace admin |
| 403 `plan_required` | "That feature needs a paid PandaDoc plan. Identity verification, approval workflows, and content library blocks need Business or Enterprise." | User upgrades their plan, or you suggest an alternative tool |
| 404 Not Found (document / template) | "I couldn't find that - let me refresh the list." | Use list / search tools to refresh |
| 422 Invalid request | "PandaDoc rejected the request - usually a bad parameter (missing required field, recipient email malformed, template field not present)." | Re-read the template / document and reformat the call |
| 429 Rate limited | "PandaDoc is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| MCP server not running | "The PandaDoc connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Admin approval required | "Your workspace administrator has restricted this connection. They need to allowlist the Claude integration for your workspace - once done, the sign-in will work for you and your team." | PandaDoc workspace admin allowlists the integration |
| Any other API error | "Something went wrong with PandaDoc - let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The PandaDoc MCP connector **can** do (via the 22 verified tools):

- Create documents from a **template** (`documents_create`) or from **markdown** (`documents_create_from_markdown`)
- Create templates from a **public PDF URL** (`templates_create`)
- Update draft content - fields, text blocks, tables, pricing tables, tokens/variables, images (`documents_update`, `documents_fields_assign`)
- Manage lifecycle - send (`documents_send`, incl. approval workflows + sender override), mark completed/paid/expired/declined (`documents_status_change`), archive (`documents_archive`)
- Manage recipients - add CC, edit in place, reassign a signer, delete (`recipients_*`)
- Configure signing **as parameters** - signing order and identity verification on `documents_create`/`documents_update` recipients
- Search and filter documents - full-text, by tags, status, date windows (`documents_list`, `documents_search`)
- Read status and reporting - per-recipient signing progress (`documents_details_get`), overall status (`documents_status_get`), audit trail (`documents_audit_trail_get`), AI summaries (`documents_summary_get`), AI metadata (`documents_metadata_get`), text extraction (`documents_content_get`)

The PandaDoc MCP connector **cannot** do (needs the PandaDoc UI or other tools) - all verified absent 2026-06-05:

- **Send reminders to unsigned recipients.** No reminder tool. You can find + report unsigned documents, but cannot auto-remind through MCP.
- **Register / verify / monitor webhooks.** No webhook tools at all. Use the PandaDoc UI.
- **Download the signed PDF.** `documents_content_get` returns text (plaintext/markdown) only, not the PDF binary. Use the PandaDoc UI to download.
- **Create documents from a file upload or a public URL.** Only templates can be created from a (PDF URL) source; documents come from a template or markdown.
- **Generate embedded editing / sending / signing session URLs.** No session-URL tools.
- **Transfer document ownership / reassign the sender** as a standalone op - change the sender via `documents_send.sender` or `documents_create.owner`; `recipients_reassign` swaps a *signer*, not the sender.
- **Delete documents permanently.** `documents_archive` is a reversible delete (`forever=false`); permanent delete needs the PandaDoc UI.
- **Connect via API key.** PandaDoc MCP is OAuth-only. No Bearer-token fallback through this skill.
- **Bypass plan gating** - identity verification, approval workflows, content library blocks may require Business+ / Enterprise plans.
- **Bypass admin allowlisting** - if the admin blocks third-party integrations, the only option is for the admin to allowlist Claude.
- **Connect multiple PandaDoc accounts simultaneously** - one connection per `~/.claude.json` entry.

---

## Behaviour Guidelines (Phase 2)

- **Never pass a `user_intent` parameter** - PandaDoc tools do NOT accept it, and because every schema is `additionalProperties: false`, passing it makes the call fail validation. (This is the opposite of the Canva MCP precedent - verified live 2026-06-05.) Pass only the documented parameters.
- **Always confirm before sending, declining, marking paid, reassigning, expiring, or archiving** - these are destructive operations that affect REAL legal documents and may notify recipients or change billing records. Summarise what you are about to do and wait for the user's OK before firing.
- **`documents_send` is the canonical destructive op** - it sends real legal documents to real recipients via email. Always re-read the document title, recipient names, and recipient emails (from `documents_details_get`) back to the user before sending, in plain English: *"I'm about to send 'Master Services Agreement - Acme Corp' to John Smith (john@acme.com) and Jane Doe (jane@acme.com) for signature. OK?"*
- **There is no reminder tool** - when the user asks to "remind unsigned recipients," do NOT claim you sent reminders. Find unsigned documents (`documents_list`/`documents_search` `status:[1]`), report them clearly, and explain reminders must be sent from the PandaDoc UI. (Confirmed absent 2026-06-05.)
- **`documents_status_change` with `status:10` (paid) affects records** - this is not a UI flag; downstream invoicing systems may consume it. Confirm with extra care: *"This will mark the Acme invoice as paid in your PandaDoc records. If your accounting software syncs with PandaDoc, this will flow through. OK?"*
- **Discover IDs before writing** - PandaDoc documents and templates are referenced by opaque IDs. Always call list / search tools once per session before any write or send, unless you already have the IDs from earlier in the conversation.
- **Respect plan gating before calling** - if you're unsure of the user's PandaDoc plan, attempt the call and translate the `403` / `plan_required` response into plain English.
- **Documents often contain confidential content** - contracts, NDAs, customer data, pricing. Never dump full document content into a public log without checking with the user first. Prefer titles and recipient counts over full text dumps.
- **Present documents clearly** - format results as readable lists or summaries, not raw JSON. For document lists, show title, status, recipient count, last-modified-date.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 47 documents; 12 are awaiting signatures"), then offer to show details.
- **Pagination** - default to 25 documents per response unless the user asks for more. Offer to show more if there are additional pages.
- **Never log or echo connection details** - never paste the contents of `~/.claude.json` to the user.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **canva-connector**: Most recent sibling Pattern 1 connector; canonical reference for the captured-smoke shape
- **atlassian-connector**: Sibling hosted-bridge-OAuth Playwright connector
- **calendly-connector**: Sibling hosted-OAuth Playwright connector
- **jotform-connector**: Sibling hosted OAuth-only MCP connector - identical install pattern
- **airtable-connector**: Pair structured customer data with PandaDoc template fields - generate one contract per row
- **hubspot-connector**: Generate PandaDoc contracts from HubSpot deals at the right pipeline stage
- **ghl-connector**: Trigger PandaDoc contract creation from GoHighLevel opportunity stage moves
- **playwright-skill**: The Playwright MCP browser is how this skill drives the PandaDoc consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting PandaDoc auth or API errors
