---
name: docusign-connector
description: "Connect DocuSign to Claude by switching on its built-in connector or storing its eSignature API credentials. Use when the user asks to set up or connect DocuSign, or wants eSignature work (envelopes, templates, recipients, signing status, voiding contracts) and DocuSign isn't connected yet. Once connected, template sends run through the `mcp__claude_ai_Docusign__*` tools; document uploads and event triggers run against its API with the stored credentials."
allowed-tools: mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit, mcp__claude_ai_Docusign__*
metadata:
  category: Documents & Signing
  tags:
    - docusign
    - esignature
    - envelopes
    - templates
    - signing
    - rest-api
  pairs-with:
    - skill: meta-business-suite-connector
      reason: Sibling Playwright-OAuth + REST-API pattern (Phase 1 Playwright drive, Phase 2 curl-against-REST)
    - skill: hubspot-connector
      reason: Sibling admin-portal Integration Key creation pattern (Step 2-4 mirrors HubSpot Private App creation)
    - skill: xero-connector
      reason: Sibling one-time-reveal Secret extraction pattern (Step 4 modal handling)
    - skill: email-composer
      reason: Compose follow-ups based on envelope status changes
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the DocuSign portal + consent flow
---

# DocuSign Connector (eSignature, REST API direct)

## Overview

This skill lets you read and update a user's DocuSign account on their behalf - envelopes, templates, recipients, and account settings. There are two routes.

**The built-in connector (try it first, but do not trust it until it answers).** DocuSign publishes a connector in Claude's own connector directory (`https://claude.com/connectors/docusign`, display name **Docusign**, category Productivity, read & write). It is **in beta and English-only**. It creates, sends and manages agreements **from templates**, tracks renewal dates, and gives read-only access to Agreement Manager. It is one click and no credentials, so it is the first thing to try - but its sign-in has a known history of failing (see below), which is why Phase 1's smoke test is a **hard gate**: a connector that is listed as Connected but cannot complete a real read or a real template send is not connected, and the moment that happens you switch to the kit's own route without further retries.

**The kit's own route.** DocuSign's official **eSignature REST API** direct, at `demo.docusign.net/restapi/v2.1` (sandbox) or the user's `<base_uri>/restapi/v2.1` (production). This is what uploads an existing PDF for signature, drives envelope-event work, and covers anything the built-in refuses or fails at. Both routes can live on one machine at once; never tear one down to set the other up.

The kit's own route has two phases:

- **PHASE 1 - Install & Auth (autonomous, 7 numbered steps).** Claude drives the DocuSign developer portal end-to-end: opens `admindemo.docusign.com/api-integrator-key` in a Playwright MCP browser, creates an app named `Selr AI Assistant`, auto-extracts the Integration Key from the DOM, generates a Secret Key and captures it from the one-time-reveal modal before close, adds a Redirect URI, saves, spins up a local Node listener on `:8080`, opens DocuSign's OAuth start URL in Playwright, the user signs in (the only manual moment), Claude auto-clicks Allow on the consent screen, the listener captures the authorization code and immediately exchanges it for an access token + refresh token (60-second code expiry - the listener+exchange-in-one-script pattern is required here), and writes both tokens + Account ID + Base URI into `~/.claude.json` `mcpServers.docusign.env` for PHASE 2's REST calls to read.
- **PHASE 2 - Use Tools.** Once the connector is configured, Claude calls DocuSign's eSignature REST API directly via Bash + `curl`. No MCP server is registered - DocuSign's hosted `mcp.docusign.com` gateway rejects the OAuth-issued tokens (empirical finding 2026-05-05, [issue #213](https://github.com/selrai-company/claude-workshop-kit/issues/213)). Each "tool" in PHASE 2 is a documented `curl` invocation pattern that Claude composes against the REST API; the SKILL handles auto-refresh (refresh token → new access token, write back to `~/.claude.json`) when the current access token 401s.

**Which phase to run** - always start at Phase 0.

### Prerequisites the user must already have (the kit's own route)

The kit's own route fails cleanly but cannot proceed without these. Surface them in its Step 1 before opening Playwright so the user can fix the gap before any browser opens. The built-in connector needs none of them - it works against the user's ordinary DocuSign account, with no developer account, no phone verification and no local port.

- **A DocuSign Developer Account** at `https://developers.docusign.com/sandbox` (free, ~5 minutes to create - DocuSign sends a 6-digit email verification code, then asks for SMS phone verification). The sandbox uses `account-d.docusign.com` for sign-in and `demo.docusign.net` for the REST API base URI. **All workshop attendees should start with the sandbox** - production migration is a v2 concern.
- **Phone number** the user can receive SMS on for one-time identity verification during account creation. Cannot be skipped.
- **Authority to install third-party apps** on their DocuSign account. Personal Developer accounts can self-approve; enterprise sandbox accounts may require admin allowlisting (rare for sandbox, common in production).
- **Local port 8080 available** for the OAuth callback listener. If another process holds 8080 (uncommon but possible - a dev server, another OAuth flow), the kit's own route fails fast at its Step 5 with a clean message; the user can free the port or the SKILL can be patched to use a different port (the registered Redirect URI in Step 4 must match).

### What the kit's own route does NOT use

- **DocuSign's hosted MCP server (`mcp.docusign.com`), registered locally.** The hosted MCP gateway rejects DocuSign-issued OAuth Authorization Code Grant access tokens with `401 Jwt payload is an invalid JSON` - DocuSign's MT-format access tokens have a proprietary binary payload, not the JSON-payload JWT the gateway parser expects. Empirical finding 2026-05-05, tracked in issue #213 (see also `docs/DOCUSIGN-CONNECTOR-AUDIT.md`, which recommended that gateway before the failure was found). The kit's own route bypasses the broken gateway entirely and calls the REST API directly.
  - **Why this matters to the built-in connector.** The built-in connector is a different, directory-listed path with its own sign-in, and it may well work - but the failure above was in DocuSign's own hosted gateway, and as of May 2026 that gateway rejected DocuSign's own tokens. So treat the built-in's sign-in as unproven until a real read comes back. That is exactly why Phase 1's smoke test is a hard gate and why the kit's own route is the standing fallback rather than a last resort.
- **JWT Grant / RSA keypair.** That's a separate auth flow (server-to-server, no per-user consent). This SKILL uses Authorization Code Grant + PKCE because it's user-interactive and matches the workshop attendee's mental model (sign in once, like every other connector).
- **Composio / Rube MCP / any third-party aggregator.** All credentials and tokens stay on the user's local machine (`~/.claude.json` env block). No SaaS middleman holds the user's DocuSign access.
- **DocuSign API tokens / personal access tokens.** DocuSign does not offer a personal-access-token model for the eSignature REST API. Auth is OAuth 2.0 Authorization Code Grant + PKCE only.
- **The `mcp__docusign__*` tool surface.** That namespace is what a locally-registered hosted MCP would have provided. The kit's own route doesn't register an MCP server; its tool invocations are Bash + curl in PHASE 2. (The built-in connector's namespace is different again - `mcp__claude_ai_Docusign__*` - and does not collide with this.)

### How auth works under the hood

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

Standard OAuth 2.0 Authorization Code Grant with PKCE S256. Practical implications for the SKILL:

- **DocuSign auth codes expire in ~60 seconds.** Don't accept the code in one step and exchange it in another - race the user. The SKILL spins up a local listener that captures the code AND immediately exchanges it for a token in the same Node process (sub-second latency).
- **Access tokens last 8 hours; refresh tokens last 30 days.** The SKILL stores both in `~/.claude.json` `env` and auto-refreshes the access token when REST calls return 401.
- **Token scope is `signature` only** for the workshop default - minimum permission per DocuSign's eSignature REST API docs. Broader scopes (`click.manage`, `webforms_manage`, `notary_*`, etc.) are out of scope for v1.
- **Redirect URI is `http://localhost:8080/callback`** - registered by **PHASE 1 - Install & Auth** Step 4 against the user's Integration Key. DocuSign accepts `http://localhost` for sandbox; production requires HTTPS.

---

## Communication rules

The user is a non-technical business owner. Both connect routes are autonomous - Claude does the work, the user only signs in to DocuSign. Every message you send while connecting must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened - I'll handle the rest."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, REST, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, Playwright, browser automation, redirect URI, PKCE, integration key, listener, port, or DOM. The browser window you open is "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - Integration Key + Secret → **"app credentials"** (don't even use this - handle silently)
  - sandbox / developer account → **"your DocuSign developer account"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm setting up DocuSign for you now"), once when you need them ("please sign in"), once when you're done ("your DocuSign is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your DocuSign is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English.
- **Short responses.** Maximum 8 lines per message while connecting.
- **Never mention file paths, commands, scripts, listener PIDs, or DOM/snapshot details** to the user.
- **Never echo Integration Key, Secret Key, access token, or refresh token** back to the user. They flow silently from DOM/listener-capture into `~/.claude.json` env. Treat them like passwords.

---

## Phase 0 - Is DocuSign already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Docusign` (match the vendor word case-insensitively - the directory spells it "Docusign", the vendor's own branding is "DocuSign").
   - `✔ Connected` → **do not believe the line on its own.** Prove it with one read: call any read tool in the `mcp__claude_ai_Docusign__*` namespace (list templates, or list recent agreements). A real answer → skip to PHASE 2. A tool error, an auth error, or an empty failure → this is the known sign-in failure mode; stop retrying and go to *Route by need*, then run the kit's own route.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` for the user and say: *"Your DocuSign connection needs a quick re-sign-in. Press Reconnect next to DocuSign, sign in, and tell me when it says Connected."* Then re-run this check **once**. If it fails a second time, go to the kit's own route.
   - no such line → continue.
2. **The kit's own route.** Run the resume check at *Pre-flight for the kit's own route* → 0.1, below.
3. **Nothing found** → Route by need, then Phase 1.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of DocuSign's tools.

---

## Route by need - which DocuSign route does this user actually want?

Ask **one** question in plain English before opening anything: *"What do you want me to do with DocuSign - send out contracts you already have set up as templates, or send a document you'll hand me each time?"*

Then route each named need:

| What the user wants | Route |
|---|---|
| Send an agreement built from a **template** they already have in DocuSign | Built-in connector (Phase 1) |
| Review, search or surface existing agreements; check renewal dates | Built-in connector (Phase 1) |
| Read-only Agreement Manager work | Built-in connector (Phase 1) |
| **Upload an existing PDF** and send it for signature | The kit's own route (PHASE 1 - Install & Auth) |
| Anything driven by **envelope events** - reminders, status triggers, reacting to a signature | The kit's own route |
| Void or resend an envelope, download the signed PDF, read recipient-level status | The kit's own route |
| Working in a language other than English | The kit's own route - the built-in beta is English-only |
| The built-in's sign-in failed, or a template send through it failed | The kit's own route, immediately - see the hard gate below |

The built-in connector is a beta with a known sign-in failure history (issue #213). Try it first, but the **moment sign-in fails or a template send fails, switch to the kit's own route** - do not retry, do not troubleshoot the beta, do not leave the user waiting on it. If everything the user named is in the built-in's column and it works, stop after Phase 1 and do not burden them with the developer-account walk. Say in one line what you are not connecting and why, so they can ask for it later.

---

## Phase 1 - Switch on the built-in DocuSign connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in. This skill handles no credentials on this route.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening DocuSign's page in your browser. Press **Connect to Claude**, sign in to DocuSign the way you normally do, and say yes when it asks for access. That is the only part only you can do, tell me when it says Connected."* Then open `https://claude.com/connectors/docusign` (or `https://claude.ai/directory/docusign`) in **the user's own everyday browser** (`open` on Mac, `xdg-open` on Linux, `start ""` on Windows). If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "DocuSign" → Connect. In the desktop app's Code tab the better route is the composer's **+** → **Connectors** → **Browse connectors** → the **+** next to it: that one shows up in the running session without a restart, whereas the browser page needs the app quit and reopened before any session sees the tools.

> **This is the one place the driven-browser rule does not apply.** The kit's own route drives a Playwright browser because it reads app credentials off the page. This route reads nothing, and the user's own browser is the only one signed in to claude.ai. Do not drive this sign-in with Playwright.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Docusign … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2 **once**. If Step 2 has already been attempted twice, treat it as the hard gate below.

**Step 5 - Prove it. This is a HARD GATE.** Call one real read through the connector - any read tool in the `mcp__claude_ai_Docusign__*` namespace (list templates is the best one, because a template list is also what a template send needs). Only a real answer counts. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

- **Real answer** → connected. Continue to Step 6.
- **Any tool error, auth error, `401`, or empty failure** → the built-in is not usable on this account. Do **not** retry, do **not** troubleshoot, do **not** ask the user to reconnect a third time. Say one plain-English line - *"DocuSign's quick connection isn't accepting the sign-in. I'll set it up the other way, it takes a few minutes longer."* - and run the kit's own route (**PHASE 1 - Install & Auth**) from its Step 1. The same rule applies later: if the first real template send through the built-in fails, that is the gate closing, and the kit's own route takes over from there.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - *"send the services agreement to alex@example.com"*, *"what's waiting on a signature?"*, *"which contracts renew next month?"*. Also say in one line what this route cannot do, so they don't hit it cold: it sends from templates, not from a document they hand you, and it is English-only while in beta.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch DocuSign on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

**Local entry precedence.** If a server registered locally with `claude mcp add` points at the same URL, it takes precedence and hides the built-in one. If it works, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the user's OK. Note the specific trap here: a machine that ran an older version of this skill may carry a `mcpServers.docusign` entry that is a **metadata-only sentinel**, not a runnable server (`command: 'true'`) - that entry is the kit's own credential store, not a competing MCP registration, and must be left alone.

---

## Pre-flight for the kit's own route (silent)

### 0.1 - Resume check

Read `~/.claude.json` via Node (cross-platform safe - Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const ds = (j.mcpServers || {}).docusign;
if (!ds || !ds.env) { console.log('NOT_CONFIGURED'); process.exit(0); }
const { DS_REFRESH_TOKEN, DS_INTEGRATION_KEY, DS_ACCOUNT_ID } = ds.env;
console.log(DS_REFRESH_TOKEN && DS_INTEGRATION_KEY && DS_ACCOUNT_ID ? 'CONFIGURED' : 'PARTIAL');
"
```

- `CONFIGURED` → run **PHASE 1 - Install & Auth** Step 7 (verify smoke) directly. If it succeeds, the kit's own route is active - say *"DocuSign is already connected"* and skip to PHASE 2; do not set the built-in up on top of a working connection. If it 401s, run the refresh-token rotation; if THAT 400s (refresh expired after 30 days), walk **PHASE 1 - Install & Auth** from its Step 5.
- `PARTIAL` → existing entry but missing fields; treat as `NOT_CONFIGURED` and re-run **PHASE 1 - Install & Auth** from its Step 1 with a one-line "I see a partial DocuSign config - let me redo it cleanly" message.
- `NOT_CONFIGURED` → nothing found on either route; go to *Route by need*, then Phase 1.

### 0.2 - Tooling check (silent)

Verify Node 18+ is on PATH (`node --version`), Playwright MCP is reachable (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the deferred-tool surface), `curl` is available (`curl --version`), and TCP port 8080 is free (`node -e "require('net').createServer().listen(8080, () => process.exit(0)).on('error', () => process.exit(1))"`).

If `claude` CLI is missing, fall back to the setup prompt in `docs/start/setup.md` (its Step 6 installs the Claude CLI). If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest --user-data-dir=$HOME/.playwright-profile/selr-default --browser=chrome`, ask the user to close and reopen the chat once, then retry. If port 8080 is held, surface plainly: *"Something's already running on the connection port (8080). Please close any other dev servers or app installers, then say 'connect to DocuSign' to retry."*

### 0.3 - Environment selection (silent default: sandbox)

The SKILL uses sandbox by default for workshop attendees:

| Variable | Sandbox (default) | Production |
| --- | --- | --- |
| Admin portal | `https://admindemo.docusign.com/api-integrator-key` | `https://admin.docusign.com/api-integrator-key` |
| OAuth host | `https://account-d.docusign.com` | `https://account.docusign.com` |
| REST API base URI | `https://demo.docusign.net` | per-account `<base_uri>` returned by `/oauth/userinfo` |

Production mode requires the user to opt in via the trigger phrase "switch my DocuSign to production" - not the default install path. Sandbox + production are logically separate accounts; Integration Keys do NOT cross-migrate.

---

## PHASE 1 - Install & Auth (7 numbered steps, autonomous via Playwright + Node listener)

> **When to run this.** The kit's own route. Run it when the user named a need in the gap column of *Route by need* above - uploading an existing PDF for signature, envelope-event work, voiding, resending, downloading signed PDFs, recipient-level status, or working in a language other than English - **or the moment the built-in connector's hard gate closes** (Phase 1 Step 5 failed, or the first real template send through it failed), or when Phase 1 Step 1 showed this session cannot see built-in connectors at all. Otherwise stop at Phase 1. Both routes can coexist; setting this one up does not switch the built-in one off.

### Step 1 - Orient the user + confirm prerequisites

Tell the user, in one short message:

> "I'll connect your DocuSign now. Quick check first: do you already have a DocuSign developer account? If yes, say 'yes' and I'll open the connection page. If you've never used DocuSign for development, say 'not sure' and I'll walk you through creating a free developer account first - it takes about five minutes including email and SMS verification."

Branch on the user's reply:

- **"Yes" / "I have one" / equivalent** → continue to Step 2.
- **"Not sure" / "No"** → tell them: *"No problem - head to https://developers.docusign.com/sandbox and sign up. They'll send a 6-digit code by email, then ask for an SMS phone verification. Once you can sign in to your developer account, come back and say 'I have an account now' and we'll continue."* Wait for confirmation before proceeding to Step 2.

### Step 2 - Drive the DocuSign developer portal in Playwright

Navigate Playwright to the sandbox admin portal:

```
mcp__playwright__browser_navigate({
  url: "https://admindemo.docusign.com/api-integrator-key"
})
```

Take a snapshot. Detect login state:

- **Logged in** - page title contains `Apps and Keys | Docusign` and the secondary navigation shows `Apps and Keys` highlighted under `Integrations`. The main panel shows either "No Integration Keys found" or a list of existing apps. Capture the user's `Account ID` and `API Account ID` from the `My Account Information` panel (the API Account ID is a UUID; we'll need it for REST calls). Proceed to Step 3.
- **Not logged in** - page redirects to `account-d.docusign.com` with a sign-in form. Tell the user *once*: *"Please sign in to your DocuSign developer account in the browser window I just opened - I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the apps-and-keys page heading.

The user may complete sign-in via password, 2FA, or SSO - all paths converge to the apps-and-keys page.

#### 2a - Capture Account ID + API Account ID via `browser_evaluate`

```javascript
() => {
  const out = { accountId: null, apiAccountId: null };
  const labels = [...document.querySelectorAll('*')].filter(el => {
    const t = el.textContent?.trim();
    return t === 'Account ID' || t === 'API Account ID';
  });
  for (const label of labels) {
    const tb = label.parentElement?.querySelector('input, [role="textbox"]');
    if (!tb) continue;
    if (label.textContent.trim() === 'Account ID') out.accountId = tb.value || tb.textContent || '';
    else out.apiAccountId = tb.value || tb.textContent || '';
  }
  return out;
}
```

Store in shell variables `DS_ACCOUNT_ID` (numeric short ID, used in REST URLs) and `DS_API_ACCOUNT_ID` (UUID, used for some endpoints). Some REST endpoints prefer the UUID; the SKILL uses `DS_ACCOUNT_ID` (numeric) by default since it's what `/restapi/v2.1/accounts/<id>/...` expects.

### Step 3 - Create the Integration Key (DOM-extract)

Click the **"Add App and Integration Key"** button:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Add App and Integration Key$/i>,
  element: "Add App and Integration Key button on the Apps and Keys page"
})
```

Fill the App Name and submit:

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

After click, DocuSign navigates to the new app's edit page. Snapshot. Auto-extract the Integration Key from the `General Info` section via `browser_evaluate`:

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

Store in shell variable `DS_INTEGRATION_KEY` (do not echo to chat).

### Step 4 - Generate Secret Key (one-time-reveal modal) + add Redirect URI

#### 4a - Generate Secret Key

Click **"Add Secret Key"** under the `Authentication → Secret Keys` section:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Add Secret Key$/i>,
  element: "Add Secret Key button under Authentication section"
})
```

DocuSign generates a UUID-shaped secret and renders it inline as a textbox. **Capture immediately** - DocuSign shows the secret only once at generation time; navigating away or refreshing hides it. Use `browser_evaluate`:

```javascript
() => {
  const sectionLabel = [...document.querySelectorAll('*')].find(el => el.textContent?.trim() === 'Secret Keys');
  if (!sectionLabel) return '';
  const tb = sectionLabel.parentElement?.querySelector('input[type="text"], textarea');
  return tb ? (tb.value || '').trim() : '';
}
```

Store in shell variable `DS_SECRET` (do not echo to chat).

#### 4b - Add Redirect URI

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

#### 4c - Save the app config

Click **"Save"** at the bottom of the page:

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Save$/i>,
  element: "Save button at the bottom of the app edit page"
})
```

DocuSign redirects back to the apps-and-keys list with the new app showing. The Integration Key + Secret + Redirect URI are now active.

### Step 5 - Spin up local listener + drive OAuth flow

DocuSign auth codes expire in ~60 seconds, so the SKILL races the user: spin up a Node http listener on `:8080` that captures the code AND immediately exchanges it for tokens in a single process, sub-second latency.

#### 5a - Generate PKCE state + write to a temp file

```bash
node -e "
const crypto = require('crypto');
const fs = require('fs');
const code_verifier = crypto.randomBytes(64).toString('base64url');
const code_challenge = crypto.createHash('sha256').update(code_verifier).digest('base64url');
const state = crypto.randomBytes(16).toString('base64url');
fs.writeFileSync(process.env.HOME + '/.docusign-oauth-state.json', JSON.stringify({ code_verifier, state }));
console.log('AUTH_URL=https://account-d.docusign.com/oauth/auth?response_type=code&client_id=' + process.env.DS_INTEGRATION_KEY + '&redirect_uri=' + encodeURIComponent('http://localhost:8080/callback') + '&scope=signature&code_challenge=' + code_challenge + '&code_challenge_method=S256&state=' + state);
" | tee /tmp/ds-auth-out.txt
```

Capture `AUTH_URL=...` from the output.

#### 5b - Start the listener-and-exchange Node script in the background

Write `~/.docusign-listener.mjs` and run it as a background process:

```bash
cat > ~/.docusign-listener.mjs <<'EOF'
import http from 'node:http';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const ck = process.env.DS_INTEGRATION_KEY;
const sk = process.env.DS_SECRET;
const accountId = process.env.DS_ACCOUNT_ID;
const homeCfg = path.join(process.env.HOME, '.claude.json');
const stateFile = path.join(process.env.HOME, '.docusign-oauth-state.json');
const state = JSON.parse(readFileSync(stateFile, 'utf8'));

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost:8080');
  if (url.pathname !== '/callback') { res.writeHead(404); res.end(); return; }
  const code = url.searchParams.get('code');
  if (!code) { res.writeHead(400); res.end('no code'); return; }

  const basic = Buffer.from(`${ck}:${sk}`).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: 'http://localhost:8080/callback',
    code_verifier: state.code_verifier,
  });

  try {
    const r = await fetch('https://account-d.docusign.com/oauth/token', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${basic}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body: body.toString(),
    });
    const text = await r.text();
    if (!r.ok) {
      res.writeHead(500); res.end('exchange failed: ' + text);
      console.error('TOKEN_FAIL ' + r.status + ' ' + text);
      process.exit(1);
    }
    const data = JSON.parse(text);

    // Resolve base URI from /oauth/userinfo
    const userinfo = await fetch('https://account-d.docusign.com/oauth/userinfo', {
      headers: { Authorization: 'Bearer ' + data.access_token, Accept: 'application/json' },
    }).then(r => r.json());
    const baseUri = userinfo.accounts?.find(a => a.account_id === process.env.DS_API_ACCOUNT_ID)?.base_uri || userinfo.accounts?.[0]?.base_uri;

    // Merge into ~/.claude.json
    let cfg = {};
    try { cfg = JSON.parse(readFileSync(homeCfg, 'utf8')); }
    catch { /* fresh file */ }
    cfg.mcpServers = cfg.mcpServers || {};
    cfg.mcpServers.docusign = {
      type: 'stdio',
      command: 'true',  // sentinel - this entry is metadata-only, not a runnable MCP
      env: {
        DS_INTEGRATION_KEY: ck,
        DS_SECRET: sk,
        DS_ACCOUNT_ID: accountId,
        DS_API_ACCOUNT_ID: process.env.DS_API_ACCOUNT_ID,
        DS_BASE_URI: baseUri,
        DS_ACCESS_TOKEN: data.access_token,
        DS_REFRESH_TOKEN: data.refresh_token,
        DS_TOKEN_EXPIRES_AT: String(Date.now() + (data.expires_in * 1000)),
      },
    };
    const tmp = homeCfg + '.tmp';
    writeFileSync(tmp, JSON.stringify(cfg, null, 2));
    require('node:fs').renameSync(tmp, homeCfg);

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<h1>DocuSign connected</h1><p>You can close this tab.</p>');
    console.log('TOKEN_OK scope=' + data.scope);
  } catch (err) {
    res.writeHead(500); res.end('error: ' + err.message);
    console.error('EXCHANGE_ERROR ' + err.message);
  }
  setTimeout(() => process.exit(0), 200);
});

server.listen(8080, '127.0.0.1', () => console.log('LISTENER_UP'));
setTimeout(() => { console.error('LISTENER_TIMEOUT'); process.exit(2); }, 5 * 60_000);
EOF

DS_INTEGRATION_KEY="$DS_INTEGRATION_KEY" DS_SECRET="$DS_SECRET" \
DS_ACCOUNT_ID="$DS_ACCOUNT_ID" DS_API_ACCOUNT_ID="$DS_API_ACCOUNT_ID" \
nohup node ~/.docusign-listener.mjs > /tmp/ds-listener.log 2>&1 &

# Wait for LISTENER_UP confirmation
sleep 1
grep -q LISTENER_UP /tmp/ds-listener.log || { echo "LISTENER_FAILED_TO_BIND"; exit 1; }
```

The listener exits cleanly after one capture (success or token-exchange failure) or after a 5-minute timeout if the user never returns.

#### 5c - Open the OAuth URL in Playwright

```
mcp__playwright__browser_navigate({ url: <AUTH_URL> })
```

Take a snapshot. The flow has two visible stages - sign-in (if the Playwright profile doesn't have DocuSign cookies from Step 2) and consent.

If on the sign-in form (page title contains `Enter your password to sign in`), tell the user *once*: *"Please sign in to DocuSign in the browser window - I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent screen markers OR the final `localhost:8080/callback` redirect (which DocuSign may auto-trigger if consent was previously granted).

### Step 6 - Auto-click Allow on the consent screen

Per memory rule `feedback_human_touch_only_login.md` (Gian 2026-04-30 strict-Allow tightening): the user's ONLY manual touchpoint is signing in. The Allow click on consent is **auto-clicked by Claude**.

#### 6a - If consent screen renders

Snapshot. Extract the human-readable scope list via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items, plain English):

> "DocuSign is asking to: send and manage envelopes, read account info. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive - match against `allow`, `accept`, `authorise`, `authorize`, `grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button against the consent verbs>,
  element: "Allow button on the DocuSign consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically - please click **Allow** in the browser window."*

#### 6b - If the page already redirected to localhost (consent previously granted)

Re-running this route against an Integration Key the user has already consented to skips the consent screen and lands directly at `http://localhost:8080/callback?code=...`. The listener captures and exchanges immediately. Skip 6a, proceed to Step 7.

### Step 7 - Verify the listener completed + smoke-test REST API

Wait for the listener's exit:

```bash
# Poll /tmp/ds-listener.log for TOKEN_OK or TOKEN_FAIL
for i in $(seq 1 30); do
  if grep -q "TOKEN_OK\|TOKEN_FAIL\|EXCHANGE_ERROR\|LISTENER_TIMEOUT" /tmp/ds-listener.log; then break; fi
  sleep 2
done
```

Branch on the log:

- `TOKEN_OK` → `~/.claude.json` now has the full env block. Proceed to smoke-test.
- `TOKEN_FAIL <status> <body>` → surface plainly: *"DocuSign rejected the connection. Let me try again."* Walk this route from Step 5 once. If it fails again, surface the user-facing error and stop.
- `EXCHANGE_ERROR ...` / `LISTENER_TIMEOUT` → surface and stop.

#### 7a - Smoke-test REST API

Read the env from `~/.claude.json` and call DocuSign's `/accounts/<id>` endpoint:

```bash
node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync(process.env.HOME + '/.claude.json', 'utf8'));
const env = cfg.mcpServers.docusign.env;
console.log('ACCESS_TOKEN=' + env.DS_ACCESS_TOKEN);
console.log('BASE_URI=' + env.DS_BASE_URI);
console.log('ACCOUNT_ID=' + env.DS_ACCOUNT_ID);
" > /tmp/ds-env-export.sh
source /tmp/ds-env-export.sh

curl -fsS -H "Authorization: Bearer $ACCESS_TOKEN" \
  "$BASE_URI/restapi/v2.1/accounts/$ACCOUNT_ID" \
  | node -e "process.stdin.pipe(process.stdout); process.stdin.on('end', () => console.error('SMOKE_OK'))"

rm -f /tmp/ds-env-export.sh /tmp/ds-listener.log "$HOME/.docusign-oauth-state.json"
```

If the call returns the account JSON (with `accountId`, `accountName`, `baseUri` etc.), the connector is fully working.

### Step 8 - Close the browser + success message

```
mcp__playwright__browser_close()
```

Tell the user, in one short message:

> "All done! Your DocuSign is now connected. You can ask me things like 'send a contract to alex@example.com', 'show me my envelopes', 'check the status of the contract I sent yesterday', or 'list my templates'. Give it a try!"

---

## PHASE 2 - Use Tools

**Which tools you have depends on which route connected.** Through the built-in connector the tools are `mcp__claude_ai_Docusign__*` - creating, sending and managing agreements **from templates**, renewal dates, and read-only Agreement Manager. Through the kit's own route the "tools" are the `curl` shapes below.

The names differ materially, and the split is not cosmetic. There is no built-in equivalent of creating an envelope from an uploaded document, of `voided`/`resend_envelope`, of the combined-PDF download, or of recipient-level status, so all of those run through the kit's own route even on a machine where both are connected. In the other direction, if the built-in is working, prefer it for a plain template send: it needs no token refresh and no local listener.

If a call through `mcp__claude_ai_Docusign__*` fails - especially the first template send - treat that as the hard gate closing, not as a transient error. Say one plain line and move the work to the kit's own route.

### The kit's own route - REST API via Bash + curl

Once the kit's own route is configured, Claude calls DocuSign's eSignature REST API at `<base_uri>/restapi/v2.1/accounts/<account_id>/...` directly. No MCP server is involved. Each "tool" is a documented Bash invocation pattern that Claude composes from the user's request.

### Pre-flight for every kit-route PHASE 2 call: load env + auto-refresh

Before any REST call, read the current env from `~/.claude.json` and check whether the access token is expired (using the `DS_TOKEN_EXPIRES_AT` we stored at issuance). If expired (or within 5 minutes of expiry), run the refresh-token rotation:

```bash
ds_load_env() {
  eval "$(node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync(process.env.HOME + '/.claude.json', 'utf8'));
    const e = cfg.mcpServers.docusign.env;
    for (const [k, v] of Object.entries(e)) console.log(\`export \${k}='\${v}'\`);
  ")"
}

ds_refresh_token_if_needed() {
  ds_load_env
  if [ -n "$DS_TOKEN_EXPIRES_AT" ] && [ "$DS_TOKEN_EXPIRES_AT" -gt "$(($(date +%s) * 1000 + 300000))" ]; then
    return 0  # still valid, ≥5 min remaining
  fi
  # Refresh
  local basic=$(printf '%s:%s' "$DS_INTEGRATION_KEY" "$DS_SECRET" | base64 -w0)
  local response
  response=$(curl -fsS -X POST -H "Authorization: Basic $basic" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "grant_type=refresh_token&refresh_token=$DS_REFRESH_TOKEN" \
    https://account-d.docusign.com/oauth/token)
  if [ $? -ne 0 ]; then return 1; fi
  # Write new tokens back to ~/.claude.json
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync(process.env.HOME + '/.claude.json', 'utf8'));
    const r = JSON.parse(process.argv[1]);
    const e = cfg.mcpServers.docusign.env;
    e.DS_ACCESS_TOKEN = r.access_token;
    if (r.refresh_token) e.DS_REFRESH_TOKEN = r.refresh_token;
    e.DS_TOKEN_EXPIRES_AT = String(Date.now() + (r.expires_in * 1000));
    const tmp = process.env.HOME + '/.claude.json.tmp';
    fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2));
    fs.renameSync(tmp, process.env.HOME + '/.claude.json');
  " "$response"
  ds_load_env
}
```

If the refresh-token rotation 400s (refresh expired after 30 days), surface plainly: *"Your DocuSign sign-in has fully expired. Let me reconnect you."* Walk **PHASE 1 - Install & Auth** from its Step 5.

### Tool Reference

#### Envelopes - Create, send, read

| User asks | Bash invocation pattern |
| --- | --- |
| "Show me my envelopes" / "What's pending signature?" | `ds_refresh_token_if_needed && curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes?from_date=$(date -d '30 days ago' -Iseconds 2>/dev/null \|\| date -v-30d -Iseconds)&status=$STATUS"` (STATUS = `sent,delivered,completed,declined,voided` filter) |
| "Show me envelope `<id>`" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>"` |
| "Send a contract to alex@example.com" | `curl -fsS -X POST -H "Authorization: Bearer $DS_ACCESS_TOKEN" -H "Content-Type: multipart/form-data" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes" --form 'envelope=<json-with-recipients-and-documents>;type=application/json' --form 'document=@contract.pdf;type=application/pdf'` - **confirm recipients + subject + body first** |
| "Void contract `<id>`" | `curl -fsS -X PUT -H "Authorization: Bearer $DS_ACCESS_TOKEN" -H "Content-Type: application/json" -d '{"status":"voided","voidedReason":"<reason>"}' "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>"` - **confirm first** |
| "Remind alice to sign envelope `<id>`" | `curl -fsS -X PUT -H "Authorization: Bearer $DS_ACCESS_TOKEN" -H "Content-Type: application/json" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>?resend_envelope=true"` - **confirm first** |

#### Envelopes - Recipients & status

| User asks | Bash invocation pattern |
| --- | --- |
| "Who's signed envelope `<id>`?" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>/recipients"` |
| "Status of envelope `<id>`?" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>?include=status"` |

#### Templates

| User asks | Bash invocation pattern |
| --- | --- |
| "Show me my templates" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/templates"` |
| "Show me template `<id>`" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/templates/<templateId>"` |
| "Send template `<name>` to alice@example.com" | `curl -fsS -X POST -H "Authorization: Bearer $DS_ACCESS_TOKEN" -H "Content-Type: application/json" -d '{"templateId":"<id>","templateRoles":[{"email":"alice@example.com","name":"Alice","roleName":"<role>"}],"status":"sent"}' "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes"` - **confirm first; show recipient mapping** |

#### Documents

| User asks | Bash invocation pattern |
| --- | --- |
| "What's in envelope `<id>`?" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>/documents"` |
| "Download the contract from envelope `<id>`" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" -o ~/Downloads/<id>-combined.pdf "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID/envelopes/<envelopeId>/documents/combined"` |

#### Account

| User asks | Bash invocation pattern |
| --- | --- |
| "Which DocuSign account am I connected to?" | `curl -fsS -H "Authorization: Bearer $DS_ACCESS_TOKEN" "$DS_BASE_URI/restapi/v2.1/accounts/$DS_ACCOUNT_ID"` |

> **DocuSign REST API reference**: full endpoint list at `https://developers.docusign.com/docs/esign-rest-api/reference/`. For any user request that doesn't match the patterns above, look up the canonical endpoint in the reference, compose the curl invocation, **always source `ds_refresh_token_if_needed` first**, and surface the response in plain English.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
| --- | --- |
| "Connect my DocuSign" / "Set up DocuSign" | **Run Phase 0, then Route by need** |
| "Switch my DocuSign to production" | Re-run **PHASE 1 - Install & Auth** with production URLs (`admin.docusign.com`, `account.docusign.com`, `<base_uri>` from production userinfo); creates a NEW Integration Key in production portal |
| "My DocuSign stopped working" / "I'm getting auth errors" | On the built-in connector, send them to Reconnect on `https://claude.ai/customize/connectors`; on the kit's own route, run `ds_refresh_token_if_needed` and if it 400s walk **PHASE 1 - Install & Auth** from its Step 5 |
| "Show me my envelopes" / "What's pending signature?" | `list_envelopes` filtered by status |
| "Send a contract to [email]" | `list_templates` (if user mentioned a template) → `create_envelope` or `create_envelope_from_template` - **confirm recipients + subject + body first** |
| "Is the [contract name] signed?" | `list_envelopes` to find ID → `get_envelope_status` |
| "Who's signed [contract]?" | `list_recipients` for that envelope ID |
| "Cancel the contract I sent to [name]" | `list_envelopes` → `void_envelope` - **confirm first** |
| "Remind [name] to sign" | `list_envelopes` to find pending → `resend_envelope` - **confirm first** |
| "Show me my templates" | `list_templates` |
| "Download the contract from envelope X" | `get_documents/combined` |
| "Which DocuSign account am I on?" | `get_account_info` |

---

## Error Handling (PHASE 2, the kit's own route)

When a DocuSign REST call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
| --- | --- | --- |
| 401 Unauthorized | "Your DocuSign sign-in has expired - let me refresh it." | Run `ds_refresh_token_if_needed`; retry the original call |
| 401 even after refresh | "Your DocuSign sign-in has fully expired. Let me reconnect you." | Walk **PHASE 1 - Install & Auth** from its Step 5 |
| 400 + `redirect_uri_mismatch` (during Phase 1 token exchange) | "Connection page used a different return address than I registered. Let me update it." | Walk back to **PHASE 1 - Install & Auth** Step 4b, add the runtime's actual callback URL, save, retry from Step 5 |
| 400 + `consent_required` | "DocuSign is asking you to grant permission first. Let me reconnect you." | Walk **PHASE 1 - Install & Auth** from its Step 5; the consent screen will render this time |
| 403 Forbidden - admin-only endpoint | "That action is restricted to DocuSign admins. Your account doesn't have admin permissions." | User asks their DocuSign admin to grant permissions; nothing to fix in the connector |
| 403 + `insufficient_scope` | "Your DocuSign sign-in doesn't include permission for that action. Let me reconnect with broader permissions." | Walk **PHASE 1 - Install & Auth** from its Step 5 with broader `scope=` query param |
| 404 Not Found (envelope / template) | "I couldn't find that record - let me search for it again." | Use `list_envelopes` / `list_templates` to refresh |
| 422 Unprocessable Entity | "DocuSign rejected the request - usually a bad parameter. Let me check and try again." | Re-read with `get_envelope` / `get_template` and reformat the call |
| 429 Rate limited | "DocuSign is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| Sandbox-vs-production mismatch | "Looks like you're connected to sandbox but asked about a production envelope. Say 'switch my DocuSign to production' and I'll set that up." | Re-run **PHASE 1 - Install & Auth** with production environment |
| Any other 5xx | "Something went wrong on DocuSign's side - let me try again." | Retry once with 5-second backoff; if still failing, surface plainly and stop |

---

## Scope Limitations

**Built-in connector.** Beta, English-only. Creates, sends and manages agreements **from templates**; tracks renewal dates; read-only Agreement Manager. It **cannot** upload an existing PDF for signature and it has no envelope-event triggers. Its sign-in is not guaranteed - see the hard gate at Phase 1 Step 5.

**The kit's own route** (everything below):

The DocuSign connector **can** do (with the default `signature` scope baseline):

- List, send, void, and resend envelopes
- Read envelope and recipient status
- Update pending-recipient details (before they sign)
- List and use envelope templates
- Read documents attached to envelopes
- Download combined PDFs of envelopes
- Read account metadata

The DocuSign connector **cannot** do (needs DocuSign UI or other tools):

- **Sandbox-to-production migration in one session** - sandbox and production are logically separate accounts. Integration Keys created in `admindemo` only authenticate against `account-d.docusign.com`.
- **JWT Grant / server-to-server auth** - this SKILL uses Authorization Code Grant only. JWT Grant is a different flow with RSA keypair, out of scope.
- **DocuSign hosted MCP server (`mcp.docusign.com`), registered locally** - the gateway rejects OAuth-issued tokens (issue #213). This route bypasses it. The directory-listed built-in connector is a separate path; try that first, and fall through here the moment its hard gate closes.
- **Click / web-forms / notary / IAM (Intelligent Agreement Management)** - separate DocuSign products with their own scopes (`click.manage`, `webforms_manage`, `notary_*`, `adm_*`). The default `signature` scope does not unlock them.
- **Bulk send** - typically requires admin scopes or paid plan tiers; surface 403 cleanly with admin-permission guidance.
- **Modify a recipient's signing fields after they've signed** - DocuSign locks an envelope after completion. Read-only after that point.

---

## Sandbox-to-production migration

DocuSign sandbox and production are logically separate accounts. Workshop attendees who flip environments after the workshop discover:

- The sandbox Integration Key is valid only on `account-d.docusign.com`. They must create a NEW Integration Key in `admin.docusign.com/api-integrator-key` (production portal).
- The production app needs separate consent.
- `~/.claude.json` `mcpServers.docusign.env` must be updated: change `DS_BASE_URI` to the production base URI returned by production userinfo, replace `DS_INTEGRATION_KEY` + `DS_SECRET` with production values, re-do OAuth.

If the user says **"switch my DocuSign to production"**, walk **PHASE 1 - Install & Auth** again with the production URLs:

- Step 2: drive `https://admin.docusign.com/api-integrator-key`
- Step 5: OAuth start URL points to `https://account.docusign.com/oauth/auth?...`
- Step 7: smoke against the production base URI returned by `oauth/userinfo`

Both sandbox and production entries can coexist in `~/.claude.json` (`mcpServers.docusign` for sandbox, `mcpServers.docusign-prod` for production), but the default workshop install assumes sandbox-only.

---

## Behaviour Guidelines (PHASE 2)

- **Always confirm before sending, voiding, or modifying envelopes** - eSignature requests are legally binding (in production) and visible to recipients. Summarise recipient + subject + body before calling `create_envelope`.
- **Discover envelope IDs before reading or modifying** - DocuSign envelopes are referenced by long UUIDs. Always call `list_envelopes` once per session before any `get_envelope` / `void_envelope` / `resend_envelope`, unless you already have the ID from earlier in the conversation.
- **Recipient emails are visible to the whole envelope chain** - confirm recipient emails letter-for-letter before sending.
- **Templates are reusable across envelopes** - prefer `create_envelope_from_template` when the user mentions a template by name.
- **Present envelope status clearly** - format results as readable tables, not raw JSON. Include subject, recipient(s), status, and sent date by default.
- **One step at a time** - summarise first ("You have 12 pending envelopes; 3 are waiting on you, 9 are waiting on others"), then offer to show details.
- **Pagination** - DocuSign returns up to 100 envelopes per page (`?count=100`). Default to 25 in summaries; offer to show more.
- **Respect the rate limit** - DocuSign Cloud applies per-account rate limits. For bulk reads, batch with a 1-second pause.
- **Sandbox envelopes are NOT legally binding** - they're for testing only. Tell the user clearly when connected to sandbox: *"You're connected to your DocuSign developer account - envelopes you send from here are for testing only, they aren't legally binding."*
- **Never log or echo the env block** - never paste the contents of `~/.claude.json.mcpServers.docusign.env` to the user.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap; both connect routes above follow the same rules
- **meta-business-suite-connector**: Sibling Playwright-OAuth + REST-API pattern (Phase 1 Playwright drive + curl token exchange, Phase 2 curl against Graph API). DocuSign mirrors the shape; the only structural difference is DocuSign's Authorization Code Grant + PKCE vs Meta's Page Access Token mint.
- **hubspot-connector**: Sibling admin-portal Integration Key creation pattern - Step 2-4 mirrors HubSpot Private App creation
- **xero-connector**: Sibling one-time-reveal Secret extraction pattern - Step 4a modal handling
- **playwright-skill**: The Playwright MCP browser is how this skill drives the DocuSign portal + consent flow
