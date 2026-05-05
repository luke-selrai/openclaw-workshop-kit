---
name: docusign-connector
description: "Connect and operate DocuSign eSignature via the official first-party DocuSign Remote MCP server (https://mcp-d.docusign.com/v1/mcp for sandbox, https://mcp.docusign.com/v1/mcp for production). Phase 1 is a 9-step Playwright-driven install: drive `admindemo.docusign.com/api-integrator-key` to create an app + Integration Key, auto-extract the Integration Key from the DOM, generate a Secret Key from the one-time-reveal modal and capture it before close, add a Redirect URI matching Claude Code's MCP-runtime callback, save, register the hosted MCP server with `claude mcp add` (env-pinned to the captured Integration Key + Secret), open the OAuth start URL via `mcp__docusign__authenticate()`, the user signs in once in the Playwright window, Claude auto-clicks Allow on the consent screen, callback URL is captured and submitted via `mcp__docusign__complete_authentication`. The user's only manual moment is signing in to DocuSign inside the Playwright window. Use this skill when the user asks to set up DocuSign, send envelopes, manage templates, view envelope status, or interact with eSignature workflows."
allowed-tools: mcp__docusign__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Documents & Signing
  tags:
    - docusign
    - esignature
    - envelopes
    - templates
    - signing
    - mcp
  pairs-with:
    - skill: atlassian-connector
      reason: Sibling hosted-MCP autonomous connector — identical Step 6-9 OAuth shape (claude mcp add + authenticate + auto-Allow + complete_authentication)
    - skill: hubspot-connector
      reason: Sibling admin-portal Integration Key creation pattern (Step 2-4 above mirrors hubspot Private App creation)
    - skill: xero-connector
      reason: Sibling one-time-reveal Secret Key extraction pattern (Step 4 modal handling)
    - skill: email-composer
      reason: Compose follow-ups based on envelope status changes
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the DocuSign portal + consent flow
---

# DocuSign Connector (eSignature)

> **⚠️ Status: BLOCKED pending empirical finding [#213](https://github.com/selrai-company/claude-workshop-kit/issues/213).** Live-test 2026-05-05 showed DocuSign's hosted MCP gateway at `mcp-d.docusign.com/v1/mcp` rejects Auth Code Grant access tokens with `401 Jwt payload is an invalid JSON`. The Phase 1 flow described below is correct in shape but does NOT currently complete because the bearer Claude Code's MCP runtime obtains via `mcp__docusign__authenticate()` is not the format the gateway accepts. See issue #213 for the empirical evidence + three forward paths (JWT Grant pivot / Selr-built shim / punt #148). This SKILL is preserved as-is for the design record; do NOT use it to drive a real install until the gateway-token mismatch is resolved.

## Overview

This skill lets you read and update a user's DocuSign account on their behalf — envelopes, templates, recipients, and account settings — using the **official first-party DocuSign Remote MCP server** hosted at `https://mcp-d.docusign.com/v1/mcp` (sandbox) or `https://mcp.docusign.com/v1/mcp` (production). It has two phases:

- **Phase 1 — Install & Auth (autonomous, 9 numbered steps).** Claude drives the DocuSign developer portal end-to-end: opens `admindemo.docusign.com/api-integrator-key` in a Playwright MCP browser, creates an app named `Selr AI Assistant`, auto-extracts the Integration Key from the DOM, configures Authorization Code Grant authentication, generates a Secret Key and captures it from the one-time-reveal modal before close, adds a Redirect URI matching Claude Code's MCP-runtime callback, saves the app, registers the hosted MCP server with `claude mcp add`, calls `mcp__docusign__authenticate()` to mint the OAuth start URL, opens it in Playwright, the user signs in (the only manual moment), Claude auto-clicks Allow on the consent screen, the callback URL is captured via `browser_evaluate` before browser close, and `mcp__docusign__complete_authentication({ callback_url })` finalises auth in-session.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__docusign__*` native tools to send envelopes, manage templates, and check status.

**Which phase to run** — Before any tool call, check whether the DocuSign MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.docusign` entry. If present, attempt a verification tool call (Phase 1 Step 9). If it succeeds, the connector is ready — skip to Phase 2. If it 401s, walk Phase 1 from Step 7 to re-trigger the OAuth flow (the registration is already in place; the Integration Key + Secret are already captured).

### Prerequisites the user must already have

Phase 1 fails cleanly but cannot proceed without these. Surface them in Step 1 before opening Playwright so the user can fix the gap before any browser opens.

- **A DocuSign Developer Account** at `https://developers.docusign.com/sandbox` (free, ~5 minutes to create — DocuSign sends a 6-digit email verification code, then asks for SMS phone verification). The sandbox uses `account-d.docusign.com` for sign-in and `mcp-d.docusign.com` for the MCP host. **All workshop attendees should start with the sandbox** — production migration is a v2 concern.
- **Phone number** the user can receive SMS on for one-time identity verification during account creation. Cannot be skipped.
- **Authority to install third-party apps** on their DocuSign account. Personal Developer accounts can self-approve; enterprise sandbox accounts may require admin allowlisting (rare for sandbox, common in production).

### What this skill does NOT use

- **Production DocuSign by default.** The SKILL targets the sandbox (`mcp-d.docusign.com` + `account-d.docusign.com`). Switching to production requires creating a new Integration Key in the production admin portal (`admin.docusign.com/api-integrator-key`) — Integration Keys do not cross-migrate. Document the production flip as a separate "Reconnect to production" path.
- **DocuSign API tokens / personal access tokens.** DocuSign does not offer a personal-access-token model for the eSignature REST API. Auth is OAuth 2.0 Authorization Code Grant + PKCE only, mediated by Claude Code's MCP runtime.
- **JWT Grant.** DocuSign's hosted MCP advertises only `authorization_code` and `refresh_token` grant types in its RFC 8414 metadata. JWT Grant (`urn:ietf:params:oauth:grant-type:jwt-bearer`) is not supported by `mcp.docusign.com` — that's the JWT-only community MCPs' lane. This SKILL uses Authorization Code Grant exclusively.
- **Self-hosted DocuSign MCP server.** DocuSign publishes the hosted endpoint as the primary deployment. Community alternatives surveyed in the Phase 0 audit (PR #201) were rejected on grounds of license / scope / auth-mismatch.
- **Direct DocuSign REST API calls.** All reads and writes go through the MCP server.

### How auth works under the hood

DocuSign's hosted MCP is **NOT** a bridge OAuth proxy — unlike atlassian's `mcp.atlassian.com` or canva's `mcp.canva.com`, DocuSign exposes a direct OAuth endpoint at `account-d.docusign.com/oauth/auth` (sandbox) and does NOT support RFC 7591 Dynamic Client Registration. This means the SKILL must **pre-create an Integration Key** in the developer portal before the OAuth flow can run — distinct from atlassian/canva where the runtime auto-mints client_id at install time.

Verified live 2026-05-04 against `https://mcp-d.docusign.com/.well-known/oauth-authorization-server`:

```json
{
  "issuer": "https://account-d.docusign.com/",
  "authorization_endpoint": "https://account-d.docusign.com/oauth/auth",
  "token_endpoint": "https://account-d.docusign.com/oauth/token",
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"]
}
```

Protocol-level OAuth Bearer challenge confirmed via `POST` with bogus bearer:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="https://mcp-d.docusign.com/v1/mcp", error="invalid_token"
```

This is the RFC 6750 OAuth Bearer challenge shape — the trigger Claude Code's MCP runtime needs to auto-emit `mcp__docusign__authenticate()` / `complete_authentication({callback_url})` after `claude mcp add` registers the server.

**Practical implications surfaced in the SKILL:**

- **Phase 1 has portal-driven Steps 2-5** (create app, extract Integration Key, generate Secret, configure Redirect URI, save) — these run BEFORE the OAuth flow. atlassian's SKILL skips this entirely because of DCR.
- **One-time-reveal Secret Key modal** — DocuSign shows the Secret only once when generated. Step 4 must capture it from the DOM before the user navigates away or refreshes.
- **Redirect URI must match the runtime callback** — Claude Code's MCP runtime emits a `http://localhost:<port>/callback` URI (port can vary). Step 4 registers `http://localhost:8080/callback` as the canonical workshop port; if the runtime uses a different port at `authenticate()` time, Phase 1 Step 7 catches the mismatch and walks back to Step 4 to add the correct URI.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to DocuSign in the Playwright window. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened — I'll handle the rest."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, PKCE, integration key, or DOM. The browser window you open is "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - Integration Key + Secret → **"app credentials"** (don't even use this — handle silently)
  - sandbox / developer account → **"your DocuSign developer account"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm setting up DocuSign for you now"), once when you need them ("please sign in"), once when you're done ("your DocuSign is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your DocuSign is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user.
- **Never echo Integration Key or Secret Key** back to the user. They flow silently from DOM → MCP server registration. Treat them like passwords.

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
const dv = (j.mcpServers || {}).docusign;
console.log(dv ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 9 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 7 (re-trigger the OAuth flow; registration + Integration Key are already in place).
- `NOT_CONFIGURED` → run full Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest` (the `--` separator keeps Claude Code from consuming `npx` as an `add` flag), ask the user to close and reopen the chat, then retry.

### 0.3 — Environment selection (silent default: sandbox)

The SKILL uses sandbox by default for workshop attendees:

| Variable | Sandbox (default) | Production |
| --- | --- | --- |
| Admin portal | `https://admindemo.docusign.com/api-integrator-key` | `https://admin.docusign.com/api-integrator-key` |
| OAuth host | `https://account-d.docusign.com` | `https://account.docusign.com` |
| MCP host | `https://mcp-d.docusign.com/v1/mcp` | `https://mcp.docusign.com/v1/mcp` |

Production mode requires the user to opt in via the trigger phrase "switch my DocuSign to production" — not the default install path.

---

## PHASE 1 — Install & Auth (9 numbered steps, autonomous via Playwright)

### Step 1 — Orient the user + confirm prerequisites

Tell the user, in one short message:

> "I'll connect your DocuSign now. Quick check first: do you already have a DocuSign developer account? If yes, say 'yes' and I'll open the connection page. If you've never used DocuSign for development, or you're not sure, say 'not sure' and I'll walk you through creating a free developer account first — it takes about five minutes including email and SMS verification."

Branch on the user's reply:

- **"Yes" / "I have one" / equivalent** → continue to Step 2.
- **"Not sure" / "No"** → tell them: *"No problem — head to https://developers.docusign.com/sandbox and sign up. They'll send a 6-digit code by email, then ask for an SMS phone verification. Once you can sign in to your developer account, come back and say 'I have an account now' and we'll continue."* Wait for confirmation before proceeding to Step 2.

### Step 2 — Drive the DocuSign developer portal in Playwright

Navigate Playwright to the sandbox admin portal:

```
mcp__playwright__browser_navigate({
  url: "https://admindemo.docusign.com/api-integrator-key"
})
```

Take a snapshot. Detect login state:

- **Logged in** — page title contains `Apps and Keys | Docusign` and the secondary navigation shows `Apps and Keys` highlighted under `Integrations`. The main panel shows either "No Integration Keys found" or a list of existing apps. Proceed to Step 3.
- **Not logged in** — page redirects to `account-d.docusign.com` with a sign-in form. Tell the user *once*: *"Please sign in to your DocuSign developer account in the browser window I just opened — I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the apps-and-keys page heading.

The user may complete sign-in via password, 2FA, or SSO — all paths converge to the apps-and-keys page.

### Step 3 — Create the Integration Key (DOM-extract)

Click the **"Add App and Integration Key"** button. A modal opens with an `App Name` textbox.

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Add App and Integration Key$/i>,
  element: "Add App and Integration Key button on the Apps and Keys page"
})
```

Fill the name and submit:

```
mcp__playwright__browser_type({
  target: <ref of the textbox matching role:textbox, name:/App Name/i>,
  text: "Selr AI Assistant"
})

mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Create App$/i>,
  element: "Create App button on the Add Integration Key modal"
})
```

After click, DocuSign navigates to the new app's edit page. Snapshot. The `Integration Key` field is a textbox under the `General Info` section — auto-extract its value via `browser_evaluate`:

```javascript
() => {
  const labels = [...document.querySelectorAll('*')].filter(el => el.textContent?.trim() === 'Integration Key');
  for (const label of labels) {
    const tb = label.parentElement?.querySelector('input, textarea, [role="textbox"]');
    if (tb) return tb.value || tb.textContent || '';
  }
  return '';
}
```

Store the returned Integration Key in a shell variable (do not echo to chat).

### Step 4 — Configure Authentication + capture Secret Key + add Redirect URI

The new app's edit page has an `Authentication` section. By default the auth method is `Authorization Code Grant` — that's correct, no change needed.

#### 4a — Generate Secret Key (one-time-reveal modal)

Click the **"Add Secret Key"** button under `Secret Keys`:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Add Secret Key$/i>,
  element: "Add Secret Key button under Authentication section"
})
```

DocuSign generates a UUID-shaped secret and renders it inline as a textbox under the `Secret Keys` heading. **Capture it immediately** — DocuSign shows the secret only once at generation time; navigating away or refreshing the page hides it. Use `browser_evaluate`:

```javascript
() => {
  const sectionLabel = [...document.querySelectorAll('*')].find(el => el.textContent?.trim() === 'Secret Keys');
  if (!sectionLabel) return '';
  const tb = sectionLabel.parentElement?.querySelector('input[type="text"], textarea');
  return tb ? (tb.value || '').trim() : '';
}
```

Store the returned Secret Key in a shell variable (do not echo to chat).

#### 4b — Add Redirect URI

Scroll to the `Additional settings → Redirect URIs` section. Click **"Add URI"**:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Add URI$/i, ancestor:section/Redirect URIs/>,
  element: "Add URI button under Redirect URIs section"
})
```

Type the canonical workshop callback URL:

```
mcp__playwright__browser_type({
  target: <ref of the textbox matching role:textbox, name:/Redirect URIs/i>,
  text: "http://localhost:8080/callback"
})
```

### Step 5 — Save the app config

Click **"Save"** at the bottom of the page:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Save$/i>,
  element: "Save button at the bottom of the app edit page"
})
```

DocuSign redirects back to the apps-and-keys list with the new app showing. The Integration Key and Secret Key are now active and usable.

### Step 6 — Register the MCP server with `claude mcp add`

Silently register the hosted DocuSign MCP server in the user's config, env-pinning the Integration Key and Secret captured in Step 3 + Step 4a:

```bash
claude mcp add docusign https://mcp-d.docusign.com/v1/mcp \
  --transport http \
  --scope user \
  --env DOCUSIGN_INTEGRATION_KEY="$DS_INTEGRATION_KEY" \
  --env DOCUSIGN_SECRET="$DS_SECRET"
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
  j.mcpServers.docusign = {
    type: "http",
    url: "https://mcp-d.docusign.com/v1/mcp",
    env: {
      DOCUSIGN_INTEGRATION_KEY: process.env.DS_INTEGRATION_KEY,
      DOCUSIGN_SECRET: process.env.DS_SECRET,
    }
  };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 7 — Acquire OAuth start URL via `mcp__docusign__authenticate` and open it

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__docusign__authenticate()` — no args, returns the OAuth authorization URL (DocuSign-shaped: `https://account-d.docusign.com/oauth/auth?...`).
- `mcp__docusign__complete_authentication({ callback_url })` — submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path — not a `claude mcp` CLI subcommand.

**Tool-availability precondition.** On the very first session after `claude mcp add docusign ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__docusign__authenticate` may not be in the tool surface. If that's the case, ask the user *once*: *"I've added DocuSign. Please close and reopen the chat once, then say 'connect to my DocuSign' and I'll finish."* On resume, Phase 0's resume check sees the `mcpServers.docusign` entry and routes back into Step 7 of this flow.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__docusign__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. DocuSign's OAuth flow has two visible stages — sign-in (if not already signed in from Step 2) and consent.

#### 7a — Stage 1: sign-in (`account-d.docusign.com/login`)

If the Playwright profile already has DocuSign cookies from Step 2, this stage is skipped and the page lands directly on stage 2 — proceed to Step 8.

If not signed in (rare — Step 2 already drove sign-in), tell the user *once*: *"Please sign in to DocuSign in the browser window — I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent screen markers.

### Step 8 — Auto-click Allow on the consent screen + capture callback URL

Per memory rule `feedback_human_touch_only_login.md` (Gian 2026-04-30 tightening of Harvey's autonomous-connector pattern): the user's ONLY manual touchpoint is signing in. The Allow click on consent is **auto-clicked by Claude**, not user-driven.

#### 8a — Read scope summary, narrate, click Allow

Snapshot. Extract the human-readable scope list via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items deduplicated, in plain English):

> "DocuSign is asking to: send and manage envelopes, read account info. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name and auto-click:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button against the consent verbs (allow / accept / authorise / authorize / grant access)>,
  element: "Allow button on the DocuSign consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically — please click **Allow** in the browser window."*

#### 8b — Capture callback URL + close browser

DocuSign redirects to the localhost callback registered in Step 4b (`http://localhost:8080/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid.

Wait for the redirect via a URL-pattern wait, then capture the full `window.location.href` **before** closing the browser (after close there is no page to read):

```
mcp__playwright__browser_wait_for({
  time: 60
})

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
```

If `callback_url` does not look like a `localhost`/`127.0.0.1` callback (the user may still be mid-flow), poll once more with a short wait. If after 5 minutes there is still no callback, check in *once* with the user.

### Step 9 — Submit callback + verify

Submit the callback to Claude Code's MCP runtime to finish the OAuth dance:

```
mcp__docusign__complete_authentication({ callback_url })
```

On success, the rest of the `mcp__docusign__*` tools become available **in the same session** — no chat restart needed.

Close Playwright:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection — let me check it works."*

Verify by calling a canonical DocuSign read-only smoke tool. Tool names aren't publicly documented and the set evolves — discover at runtime by listing the `mcp__docusign__*` tools available in the current session and pick a safe read-only one (a "list envelopes" / "get account info" / `getAccountInfo` shape with no filters and a small `count`). If it returns a result (including an empty list — that's fine), the connection works.

- **Call returns a result (or empty list)** → capture any obvious counts (envelopes, templates), surface a success message including a live count.
- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 7 once. If still failing, surface the user-facing error and stop.
- **Call returns redirect_uri_mismatch** → the runtime's actual callback port differs from the registered `http://localhost:8080/callback`. Walk back to Step 4b, add the runtime's actual port (extract from the failed callback URL), save, retry from Step 7.

### Success message

Tell the user, in one short message:

> "All done! Your DocuSign is now connected. You can ask me things like 'send a contract to alex@example.com', 'show me my envelopes', 'check the status of the contract I sent yesterday', or 'list my templates'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__docusign__*` MCP tools below to answer questions and make changes in DocuSign. The hosted DocuSign Remote MCP server provides first-party tools covering envelopes, templates, recipients, documents, and account metadata.

> **Note on tool names:** DocuSign does not publish a stable public list of MCP tool names, and the set evolves as the remote MCP server adds coverage. **Discover tool names at runtime** the first time you enter Phase 2 in a new session — list the `mcp__docusign__*` tools available and map them to the categories below. The names in the tables below are the expected shape based on DocuSign's eSignature REST API surface, not a guarantee.

### Tool Reference

#### Envelopes — Create, send, read

| Tool (expected shape) | Description | Use when |
| --- | --- | --- |
| `list_envelopes` / `envelopes_list` | List envelopes filtered by status, date, or recipient | User asks "show me my contracts", "what's pending signature?", "envelopes I sent this week" |
| `get_envelope` / `envelopes_get` | Get full details of a specific envelope by envelope ID | User asks about a contract by ID or after a `list_envelopes` result |
| `create_envelope` / `envelopes_create` | Create + send a new envelope (document + recipients + subject) — **confirm first** | User asks to "send a contract to X", "draft a signing request for Y" |
| `void_envelope` / `envelopes_void` | Void an in-progress envelope before all recipients sign — **confirm first** | User asks to cancel a sent contract |
| `resend_envelope` / `envelopes_resend` | Resend the email notification to a pending recipient — **confirm first** | User asks "remind X to sign" |

#### Envelopes — Recipients & status

| Tool (expected shape) | Description | Use when |
| --- | --- | --- |
| `list_recipients` / `envelopes_list_recipients` | List recipients of a specific envelope and their signing status | User asks "who's signed the X contract?", "is Y still pending?" |
| `update_recipient` / `envelopes_update_recipient` | Update a pending recipient's email or name (before they sign) — **confirm first** | User asks "fix the email on the contract I sent" |
| `get_envelope_status` / `envelopes_get_status` | Get the high-level status (sent / delivered / completed / declined / voided) | User asks "is the contract signed yet?" |

#### Templates

| Tool (expected shape) | Description | Use when |
| --- | --- | --- |
| `list_templates` / `templates_list` | List the user's saved envelope templates | User asks "what templates do I have?" or you need a template ID before sending |
| `get_template` / `templates_get` | Get full details of a specific template | User asks about a specific template |
| `create_envelope_from_template` / `envelopes_create_from_template` | Send an envelope using a template + recipient overrides — **confirm first** | User asks "send the [template] to X" |

#### Documents

| Tool (expected shape) | Description | Use when |
| --- | --- | --- |
| `list_documents` / `envelopes_list_documents` | List documents attached to a specific envelope | User asks "what's in the X contract?" |
| `get_document` / `envelopes_get_document` | Download / read a specific document from an envelope | User asks "show me the contract Y signed" |

#### Account

| Tool (expected shape) | Description | Use when |
| --- | --- | --- |
| `get_account_info` / `accounts_get` | Get the connected DocuSign account name, plan, and base URI | User asks "which DocuSign account am I connected to?" or you need the base URI for a downstream call |
| `list_users` / `users_list` | List users in the connected DocuSign account (admin scope only) | User asks "who's on my DocuSign team?" — surface "admin only" guidance if the call returns 403 |

> **If a tool name in the tables above does not resolve**, list the available `mcp__docusign__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
| --- | --- |
| "Connect my DocuSign" / "Set up DocuSign" | **Run Phase 1** |
| "Switch my DocuSign to production" | Re-run Phase 1 with `DOCUSIGN_ENV=production` (different admin portal + MCP host + OAuth host); creates a NEW Integration Key in production portal |
| "My DocuSign stopped working" / "I'm getting auth errors" | Run Phase 1 from Step 7 (Claude Code re-runs the OAuth dance — registration + Integration Key already in place) |
| "Show me my envelopes" / "What's pending signature?" | `list_envelopes` filtered by status |
| "Send a contract to [email]" | `list_templates` (find template if user mentioned one) → `create_envelope` or `create_envelope_from_template` — **confirm recipients + subject + body first** |
| "Is the [contract name] signed?" | `list_envelopes` to find the envelope ID → `get_envelope_status` |
| "Who's signed the X contract?" | `list_recipients` for that envelope ID |
| "Cancel the contract I sent to Y" | `list_envelopes` → `void_envelope` — **confirm first, name the envelope** |
| "Remind Y to sign" | `list_envelopes` to find the pending envelope → `resend_envelope` — **confirm first** |
| "Show me my templates" | `list_templates` |
| "What's in the X contract?" | `list_documents` for that envelope ID |
| "Which DocuSign account am I connected to?" | `get_account_info` |

---

## Error Handling (Phase 2)

When a DocuSign tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
| --- | --- | --- |
| 401 Unauthorized / Not authenticated | "Your DocuSign sign-in has expired — let me reconnect you." | Walk Phase 1 from Step 7 (Claude Code re-runs OAuth); retry the original tool call |
| 403 Forbidden — insufficient_scope | "Your DocuSign sign-in doesn't include permission for that action. Let me reconnect with broader permissions." | Walk Phase 1 from Step 7 — on the consent screen, ensure the relevant scope is included |
| 403 Forbidden — admin-only | "That action is restricted to DocuSign admins. Your account doesn't have admin permissions on this DocuSign workspace." | User asks their DocuSign admin to grant permissions; nothing to fix in the connector |
| 404 Not Found (envelope / template / document) | "I couldn't find that record — let me search for it again." | Use `list_envelopes` / `list_templates` to refresh |
| 422 Invalid request | "DocuSign rejected the request — usually a bad parameter. Let me check and try again." | Re-read with `get_envelope` / `get_template` and reformat the call |
| 429 Rate limited | "DocuSign is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| `redirect_uri_mismatch` (during Step 9 verify) | "The connection page used a different return address than I registered. Let me update it." | Walk back to Phase 1 Step 4b, add the runtime's actual callback URL, save, retry from Step 7 |
| Sandbox vs production mismatch | "Looks like you're connected to your DocuSign developer account, but you asked about a production envelope. Say 'switch my DocuSign to production' and I'll set that up." | Re-run Phase 1 with production environment |
| MCP server not running | "The DocuSign connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Any other API error | "Something went wrong with DocuSign — let me try again." | Retry once; if still failing, walk Phase 1 from Step 7 |

---

## Scope Limitations

The DocuSign MCP connector **can** do (via the official DocuSign Remote MCP server with the `signature` scope baseline):

- List, send, void, and resend envelopes
- Read envelope and recipient status
- Update pending-recipient details (before they sign)
- List and use envelope templates
- Read documents attached to envelopes
- Read account metadata

The DocuSign MCP connector **cannot** do (needs DocuSign UI or other tools):

- **Sandbox-to-production migration in one session** — sandbox and production are logically separate accounts. Integration Keys created in `admindemo` only authenticate against `account-d.docusign.com`. Use "switch my DocuSign to production" to walk Phase 1 against the production portal.
- **JWT Grant / server-to-server auth** — DocuSign's hosted MCP advertises only `authorization_code` and `refresh_token` grants. JWT-based community MCPs (e.g. `luthersystems/mcp-server-docusign`) are NOT compatible with `mcp.docusign.com`.
- **Click / web-forms / notary / IAM (Intelligent Agreement Management)** — these are separate DocuSign products with their own scopes (`click.manage`, `webforms_manage`, `notary_*`, `adm_*`, etc.). The default `signature` scope does not unlock them. If the user asks about Click clickwrap agreements, web-forms intake, eNotary sessions, or IAM (Navigator) workflows, surface "those need extra permissions; let me reconnect with broader access" and walk Phase 1 from Step 7 with the additional scopes ticked at consent.
- **Bulk send / payment integrations** — these may require admin scopes or paid plan tiers. Bulk-send (`bulk_send_*`) typically requires admin permissions.
- **Modify a recipient's signing fields after they've already signed** — DocuSign locks an envelope after completion. Read-only after that point.
- **Production envelopes from the sandbox connector** — sandbox and production envelopes do not interoperate. Connecting to sandbox cannot read production envelopes.

---

## Sandbox-to-production migration

DocuSign sandbox and production are logically separate accounts. Workshop attendees who flip environments after the workshop discover:

- The sandbox Integration Key is valid only on `account-d.docusign.com`. They must create a NEW Integration Key in `admin.docusign.com/api-integrator-key` (production portal).
- The production app needs separate consent — going through the OAuth flow once on sandbox does not consent the production app.
- `~/.claude.json` `mcpServers.docusign` entry must be updated: change `mcp-d.docusign.com` → `mcp.docusign.com`, and replace `DOCUSIGN_INTEGRATION_KEY` + `DOCUSIGN_SECRET` with production values.

If the user says **"switch my DocuSign to production"**, walk Phase 1 again with the production URLs:

- Step 2: drive `https://admin.docusign.com/api-integrator-key`
- Step 6: register `https://mcp.docusign.com/v1/mcp` (no `-d` suffix), env-pinned to the new production Integration Key + Secret
- Step 7: `mcp__docusign__authenticate()` mints a `https://account.docusign.com/oauth/auth?...` URL

Both sandbox and production entries can coexist in `~/.claude.json` if needed (`mcpServers.docusign` for sandbox, `mcpServers.docusign-prod` for production), but the default workshop install assumes sandbox-only.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before sending, voiding, or modifying envelopes** — eSignature requests are legally binding and visible to recipients. Summarise recipient + subject + body before calling `create_envelope`.
- **Discover envelope IDs before reading or modifying** — DocuSign envelopes are referenced by long UUIDs. Always call `list_envelopes` once per session before any `get_envelope` / `void_envelope` / `resend_envelope`, unless you already have the ID from earlier in the conversation.
- **Recipient emails are visible to the whole envelope chain** — DocuSign sends signing notifications to each recipient with the full recipient list. Confirm recipient emails letter-for-letter before sending.
- **Templates are reusable across envelopes** — prefer `create_envelope_from_template` over `create_envelope` when the user mentions a template by name. Saves the user from re-uploading documents.
- **Present envelope status clearly** — format results as readable tables, not raw JSON. For envelope listings, include subject, recipient(s), status, and sent date by default.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 12 pending envelopes; 3 are waiting on you, 9 are waiting on others"), then offer to show details.
- **Pagination** — default to 25 envelopes / 10 templates unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — DocuSign Cloud applies per-account rate limits. For bulk reads, batch calls with a short pause.
- **Sending an envelope is irreversible (post-recipient-sign)** — once a recipient signs, you cannot recall the envelope or modify the signed document. Void only works while at least one recipient is still pending.
- **Sandbox envelopes are NOT legally binding** — they're for testing only. Tell the user clearly when they're connected to sandbox: *"You're connected to your DocuSign developer account — envelopes you send from here are for testing only, they aren't legally binding."*
- **Never log or echo connection details** — never paste the contents of `~/.claude.json` to the user, never echo the Integration Key or Secret Key.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **atlassian-connector**: Sibling hosted-MCP autonomous connector — same Step 6-9 OAuth shape (claude mcp add + authenticate + auto-Allow + complete_authentication)
- **hubspot-connector**: Sibling admin-portal Integration Key creation pattern — Step 2-4 mirrors HubSpot Private App creation
- **xero-connector**: Sibling one-time-reveal Secret extraction pattern — Step 4a modal handling
- **canva-connector**: Sibling hosted-MCP connector with bridge-OAuth (DCR-supported); contrasts with DocuSign's no-DCR portal-driven shape
- **playwright-skill**: The Playwright MCP browser is how this skill drives the DocuSign portal + consent flow
