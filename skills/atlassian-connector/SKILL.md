---
name: atlassian-connector
description: "Connect and operate Atlassian (Jira + Confluence, plus Compass) via the official first-party Atlassian Rovo Remote MCP server (https://mcp.atlassian.com/v1/mcp). Drives the entire OAuth 2.1 install autonomously through a Playwright MCP browser: discovers the auth-server metadata, dynamically registers a public OAuth client against a 127.0.0.1 loopback redirect, generates PKCE/S256 + CSRF state, opens the consent flow inside Playwright, detects the workspace/site picker, captures the authorization code via a local Node listener, exchanges it for an access + refresh token, and writes the bearer header straight into ~/.claude.json. The user's only manual moments are signing in to Atlassian and clicking Allow inside the Playwright window. Use this skill when the user asks to set up Atlassian, connect Jira or Confluence, or interact with issues, tickets, sprints, boards, pages, or spaces. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__atlassian__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Project Management & Docs
  tags:
    - atlassian
    - jira
    - confluence
    - tickets
    - docs
    - mcp
  pairs-with:
    - skill: email-composer
      reason: Draft follow-ups or status notes based on Jira tickets and Confluence updates
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Jira issues or Confluence changes
    - skill: monday-connector
      reason: Same autonomous Playwright Phase 1 pattern, simpler PAT case. Reference for the snapshot-and-reason model.
    - skill: slack-connector
      reason: Same autonomous Playwright Phase 1 pattern, OAuth-app case. Reference for the consent-screen handling and Allow-click choreography.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Atlassian consent flow.
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Atlassian auth or API errors
---

# Atlassian Connector (Jira + Confluence)

## Overview

This skill lets you read and update a user's Atlassian Cloud workspace on their behalf — Jira, Confluence, and Compass — using the **official first-party Atlassian Rovo Remote MCP server** hosted at `https://mcp.atlassian.com/v1/mcp` (see [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth (autonomous).** Claude drives the entire OAuth 2.1 dance inside a Playwright MCP browser. Discovery, dynamic client registration, PKCE/S256, CSRF state, the consent flow, the workspace/site picker, the local-loopback callback, and the token exchange are all handled autonomously by Claude via Bash + Playwright. The user does exactly THREE things: (1) sign in to Atlassian in the Playwright window, (2) click **Allow** on Atlassian's consent screen, (3) click **Allow** on the small permission box Claude Code shows when it saves the connection key to your settings. Everything else — discovery, registration, generating cryptographic challenges, capturing the callback, exchanging the code for a token, refreshing the token when it expires — happens silently. The user never copies, never pastes, never opens a tab themselves, never reads a token aloud, never types into chat anything other than confirmations.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__atlassian__*` native tools to read and update Jira and Confluence data.

**Which phase to run** — Before any tool call, check whether the Atlassian MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.atlassian` entry with both a `url` of `https://mcp.atlassian.com/v1/mcp` AND a `headers.Authorization` value starting with `Bearer `. If both are present, treat the connector as authenticated and skip to Phase 2 (verify with a tool call before assuming the access token is still valid — if it 401s, run the **Token refresh flow** below before falling back to a full Phase 1).

### What this skill does NOT use

- **Atlassian API tokens (legacy 1LO PATs).** The Atlassian Rovo Remote MCP server does support API-token auth as a fallback path for headless agents, but for an interactive workshop install we use OAuth 2.1 because it lets the user keep their normal Atlassian password + 2FA + SSO and lets the workspace admin revoke per-client access. Do not ask the user for an API token unless the OAuth flow has failed three times in a row.
- **The legacy `/v1/sse` endpoint.** Atlassian's SSE endpoint sunsets **30 June 2026**. Always use the current streamable endpoint at `https://mcp.atlassian.com/v1/mcp`.
- **A self-hosted Atlassian MCP server.** Atlassian publishes the hosted endpoint at `https://mcp.atlassian.com/v1/mcp` as the primary deployment. Always use the hosted URL.
- **The community `sooperset/mcp-atlassian` Python package.** This is a separate, third-party Python MCP server that wraps Atlassian's REST API — *not* the official hosted Atlassian Rovo MCP. **Versions before 0.17.0 carry CVE-2026-27825 (unauthenticated RCE via path traversal in Confluence attachment download) and CVE-2026-27826 (SSRF via header-controlled base URLs).** Do not install `sooperset/mcp-atlassian`. If the user already has it installed from an earlier setup attempt, advise them to remove it and use this skill instead.
- **Direct Jira / Confluence REST API calls.** All reads and writes go through the MCP server, not direct HTTP calls.
- **Claude Code's built-in `/mcp` OAuth handler.** Path A in this skill replicates the OAuth dance autonomously inside Playwright + Bash, so the user never sees the "please restart Claude Code, then say 'connect to Atlassian'" ritual. The token lands as a manual `Authorization: Bearer …` header in `~/.claude.json`, which Claude Code respects without re-running its own auth flow.

### Why a hand-rolled OAuth flow

The merged autonomous reference connectors in this repo (`monday-connector`, `slack-connector`) extract their tokens from a third-party DOM (a Personal API Token page, an OAuth app's "Bot User OAuth Token" field). Atlassian's Rovo Remote MCP is hosted: there is no token to copy from a DOM, only an OAuth 2.1 + PKCE + Dynamic Client Registration flow between an OAuth client and `mcp.atlassian.com`. To stay autonomous the skill plays the role of the OAuth client itself — discover, register, generate PKCE, drive the consent flow inside Playwright, capture the code on a local loopback listener, exchange the code, and write the resulting bearer to `~/.claude.json`.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Atlassian and clicks **Allow** on the consent screen. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and "please click Allow on the screen Atlassian just showed you."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, PKCE, redirect URI, dynamic client registration, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - workspace / site → **"your Atlassian workspace"**
  - Allow / consent → **"the Allow button"**
  - restart Claude Code → **"close and reopen"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Atlassian for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Atlassian is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Atlassian is now connected." Bad: "Token exchange returned 200 OK with access_token + refresh_token."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo the access token, refresh token, client ID, code verifier, or authorization code** back to the user. Never include them in any output visible to the user. Never log them to the conversation, even truncated.

---

## Phase 0 — Pre-flight

Before opening anything, run these checks silently. They take seconds and save dead-ends.

### 0.1 — Resume / refresh check

Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`). Look for `mcpServers.atlassian`:

- **Entry exists with `headers.Authorization` and `url == https://mcp.atlassian.com/v1/mcp`** → the connector was set up before. Try a verification tool call (Phase 1 Step 13). If it succeeds, the user is already connected — tell them so and stop.
- **Entry exists but a verification tool call returns 401** → the access token has expired. Run the **Token refresh flow** below (uses the saved refresh token; no user interaction needed). If refresh succeeds, retry verification. If refresh fails, fall through to a full Phase 1.
- **Entry missing or malformed** → run a full Phase 1.

### 0.2 — Tooling check (silent)

Verify these are available on the user's machine. Run each with a short timeout; do not surface anything to the user unless something is missing.

- `node --version` — required for the loopback callback listener and the OAuth client. Must be 18.0.0 or higher.
- `curl --version` — required for the discovery, registration, and token-exchange HTTP calls.
- `openssl version` — required for PKCE and CSRF-state generation.
- `mcp__playwright__browser_navigate` (or `mcp__plugin_playwright_playwright__browser_navigate`) — must be in the available tool surface.

If any are missing, fall back to the appropriate `first-run-setup` install path (Node via nvm or the user's package manager; Playwright MCP via `claude mcp add playwright npx @playwright/mcp@latest --scope user`). After install, ask the user to close and reopen the chat once, then retry Phase 1.

### 0.3 — Detect + remove vulnerable community Atlassian MCP server (silent)

Scan `~/.claude.json` for any `mcpServers` entry whose `command`, `args`, or `url` contains `mcp-atlassian` or `sooperset`. This identifies the community `sooperset/mcp-atlassian` Python package, which carries CVE-2026-27825 + CVE-2026-27826 (versions before 0.17.0) and is *not* the official Atlassian Rovo Remote MCP we're configuring.

If found, alert the user *once*: *"I found an older Atlassian connector on your machine that has a known security issue — I'll remove it as part of this setup."* Then delete that entry from the config (preserving every other `mcpServers` entry). Continue with Phase 1.

### 0.4 — Privacy note (silent unless asked)

This skill makes network calls only to `mcp.atlassian.com` (and its CDN at `cf.mcp.atlassian.com`) and to `127.0.0.1:<PORT>` on your own machine. No data leaves your machine to Selr or anyone else outside Atlassian. Surface this only if the user asks where their connection key goes.

### 0.5 — Site-admin pre-warning

The Atlassian Rovo MCP server is *automatically* installed for an Atlassian site the first time a user from that site completes the OAuth consent flow. Atlassian requires that **the first user on each site has access to the Atlassian apps requested by the MCP scopes** (Jira and/or Confluence) and is allowed to install third-party apps for that site. If the user's organisation has tightly restricted third-party app installs, the consent screen will show an *"administrator approval required"* interstitial instead of the Allow button. Phase 1 Step 9 detects this and exits cleanly with a plain-English message.

You do not need to ask the user about admin status up-front — most users on small teams or single-site orgs will sail through. The flow itself surfaces the failure cleanly when it happens.

---

## PHASE 1 — Install & Auth (autonomous OAuth replication via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP and replicates the OAuth 2.1 dance autonomously via Bash. The user's only roles are: (1) sign in to Atlassian when prompted, (2) click **Allow** on the consent screen. Claude handles every other step — discovery, registration, PKCE generation, the consent flow, callback capture, token exchange, config write, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the workspace picker control"). Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_evaluate` / `browser_navigate`. Do not hardcode CSS selectors — Atlassian's identity UI changes. Re-snapshot whenever the page state changes.

> **Security model.** Use `127.0.0.1` (not `localhost`), bind the listener to `127.0.0.1` only (not `0.0.0.0`), pick an unbound free port at runtime, generate cryptographically random PKCE + state, validate `state` on callback (CSRF), use S256 challenge method (never `plain`), and write tokens with restrictive file permissions. These are RFC 8252 §7.3 + RFC 7636 + RFC 6819 defaults — they exist because OAuth-on-loopback has been attacked through every weak corner of these choices.

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your Atlassian now — that covers Jira and Confluence. I'm opening a browser window for you. Please sign in there when it appears, and click Allow when Atlassian asks. I'll handle the rest. Should take about a minute."

### Step 2 — Discover the OAuth endpoints (silent)

Silently fetch the Atlassian Rovo MCP authorisation-server metadata. This is RFC 8414 discovery — the response tells us where to register a client, where to send the user for consent, and where to redeem the resulting code.

Try the RFC 9728 protected-resource metadata path first (forward-compat — Atlassian may publish it later); fall back to RFC 8414 root discovery (currently the only path that returns 200):

```bash
DISCOVERY=$(curl -fsS -m 15 https://mcp.atlassian.com/.well-known/oauth-protected-resource 2>/dev/null \
  || curl -fsS -m 15 https://mcp.atlassian.com/.well-known/oauth-authorization-server)
```

Parse the JSON response. You need these four values:

- `authorization_endpoint` — where Step 7 sends the user (currently `https://mcp.atlassian.com/v1/authorize`)
- `token_endpoint` — where Step 11 exchanges the code (currently `https://cf.mcp.atlassian.com/v1/token`)
- `registration_endpoint` — where Step 3 registers the OAuth client (currently `https://cf.mcp.atlassian.com/v1/register`)
- `code_challenge_methods_supported` — must contain `S256` (sanity check; both providers do)

Do not hardcode these URLs in your tool calls. Read them from the discovery response so the skill survives Atlassian moving its endpoints.

If discovery fails (network down, DNS, 5xx) — tell the user *"I'm having trouble reaching Atlassian — give me a moment to retry."* Retry once after 5 seconds. If still failing, ask them to check their internet and retry.

### Step 3 — Pick a free local port and start the loopback listener (silent)

Order matters: bind the listener *first*, *then* register the client with that exact port, so we never lose a port to a race.

#### 3a — Pick a free port

```bash
PORT=$(node -e "
  const net = require('net');
  const s = net.createServer();
  s.listen(0, '127.0.0.1', () => { console.log(s.address().port); s.close(); });
")
```

Capture `PORT` as a Bash variable. The redirect URI for this run is `http://127.0.0.1:${PORT}/callback`. **Use `127.0.0.1`, not `localhost`** — RFC 8252 §7.3 explicitly permits the former and some auth servers reject the latter.

#### 3b — Write the listener script

`mktemp -d -t` semantics differ between GNU (Linux, Git Bash on Windows) and BSD (macOS) — use the cross-platform safe form:

```bash
LISTENER_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'atlassian-oauth')
LISTENER_SCRIPT="$LISTENER_DIR/listener.js"
LISTENER_OUT="$LISTENER_DIR/callback.txt"
cat > "$LISTENER_SCRIPT" <<'NODE_EOF'
const http = require('http');
const url = require('url');
const port = parseInt(process.argv[2], 10);
const out = process.argv[3];
const fs = require('fs');
const server = http.createServer((req, res) => {
  const u = url.parse(req.url, true);
  if (u.pathname === '/callback') {
    const q = u.query || {};
    const lines = [
      'CODE=' + (q.code || ''),
      'STATE=' + (q.state || ''),
      'ERROR=' + (q.error || ''),
      'ERROR_DESCRIPTION=' + (q.error_description || ''),
    ].join('\n');
    fs.writeFileSync(out, lines);
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end('<!doctype html><html><head><meta charset="utf-8"><title>Connected</title></head><body style="font-family:system-ui,-apple-system,Segoe UI,Helvetica,Arial,sans-serif;text-align:center;margin-top:30vh;color:#172B4D"><h2>Connection complete.</h2><p>You can close this tab and return to the chat.</p></body></html>');
    setTimeout(() => { server.close(() => process.exit(0)); }, 250);
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' }); res.end('Not found');
  }
});
server.listen(port, '127.0.0.1');
NODE_EOF
node "$LISTENER_SCRIPT" "$PORT" "$LISTENER_OUT" &
LISTENER_PID=$!
```

The listener binds `127.0.0.1` only (not `0.0.0.0`), responds only to `/callback`, writes the captured query parameters to a tempfile, and exits 250ms after the response so the browser tab can render the success page before the socket closes.

If the listener cannot bind (rare — should not happen because we just picked the port from `net.createServer({ port: 0 })`), pick a new port and retry once.

### Step 4 — Register a public OAuth client (Dynamic Client Registration, silent)

Atlassian's Rovo MCP authorisation server supports RFC 7591 Dynamic Client Registration with public clients (no client secret). Register a fresh client per Phase 1 run — it costs nothing and avoids stale-port issues if the user retries:

```bash
REG_BODY=$(cat <<JSON
{
  "redirect_uris": ["http://127.0.0.1:${PORT}/callback"],
  "token_endpoint_auth_method": "none",
  "grant_types": ["authorization_code", "refresh_token"],
  "response_types": ["code"],
  "client_name": "Selr AI Workshop Atlassian Connector"
}
JSON
)
curl -fsS -m 15 -X POST "<registration_endpoint from Step 2>" \
  -H 'Content-Type: application/json' \
  -d "$REG_BODY"
```

Parse the response — you need `client_id`. There is no `client_secret` for a public client; Atlassian returns `token_endpoint_auth_method: "none"`.

Persist `client_id` and the redirect URI to a sidecar file at `~/.claude/atlassian-client.json` so subsequent refresh-flow runs have it. The sidecar shape:

```json
{
  "client_id": "<from registration>",
  "redirect_uri": "http://127.0.0.1:<port>/callback",
  "registered_at": <unix epoch>,
  "registration_endpoint": "<from discovery>",
  "token_endpoint": "<from discovery>",
  "authorization_endpoint": "<from discovery>"
}
```

On Mac/Linux, `chmod 600 ~/.claude/atlassian-client.json` after writing. On Windows the equivalent is `icacls "%USERPROFILE%\.claude\atlassian-client.json" /inheritance:r /grant:r "%USERNAME%:F"`.

If registration fails:
- **HTTP 429** → auth server is rate-limiting `/register`. Wait 30 seconds and retry once.
- **HTTP 4xx with `invalid_redirect_uri`** → the redirect URI was malformed; this should not happen if you used `127.0.0.1` and the literal port. Sanity-check and retry.
- **Network / 5xx** → tell the user *"I'm having trouble reaching Atlassian — give me a moment to retry."* Retry once.

### Step 5 — Generate PKCE verifier + challenge + CSRF state (silent)

Use OpenSSL (universally available on Mac, Linux, and Git Bash on Windows). **Use `printf '%s'` not `echo`** when feeding the verifier into SHA-256 — `echo` adds a trailing newline that corrupts the challenge and the auth server returns `invalid_grant` later with no useful diagnostic.

```bash
# 64-char URL-safe code_verifier (RFC 7636 §4.1: 43-128 chars from [A-Z][a-z][0-9]-._~)
CODE_VERIFIER=$(openssl rand -base64 64 | tr -d '=\n' | tr '+/' '-_' | head -c 64)

# S256 challenge: BASE64URL(SHA256(verifier)), no padding
CODE_CHALLENGE=$(printf '%s' "$CODE_VERIFIER" | openssl dgst -sha256 -binary | openssl base64 | tr -d '=\n' | tr '+/' '-_')

# 32-char URL-safe state (CSRF token, validated on callback)
STATE=$(openssl rand -base64 24 | tr -d '=\n' | tr '+/' '-_' | head -c 32)
```

Store all three in memory variables. Never write them to chat. Never persist them to disk — they are single-use, per-flow secrets.

**S256 only.** Both Atlassian and Canva advertise `plain` as supported, but never use it — `plain` does not protect against authorization-code interception on the loopback callback, and using it where S256 is available is a documented downgrade attack vector.

### Step 6 — Build the authorisation URL (silent)

Construct the URL Claude will navigate to in Playwright. URL-encode every parameter value:

```
<authorization_endpoint>?
  response_type=code&
  client_id=<from Step 4>&
  redirect_uri=http%3A%2F%2F127.0.0.1%3A<PORT>%2Fcallback&
  code_challenge=<from Step 5>&
  code_challenge_method=S256&
  scope=<see scope list below>&
  state=<from Step 5>
```

Atlassian's authorisation server shows the consent screen + workspace picker on every fresh PKCE flow because the `client_id` was just dynamically registered with no prior grant — no need for `prompt=consent` (which is OIDC syntax, not part of OAuth 2.1, and Atlassian's `/v1/authorize` does not document support).

**Scopes for the workshop default install** (read + write Jira + Confluence + identity + offline refresh):

```
read:me read:account read:jira-work write:jira-work read:jira-user read:confluence-content.all write:confluence-content read:confluence-user offline_access
```

Space-separated, then URL-encoded as `+` or `%20` in the URL.

Why each:
- `read:me`, `read:account` — identity probes; `getAccessibleAtlassianResources` works with either of these
- `read:jira-work`, `write:jira-work`, `read:jira-user` — Jira issue read + write + assignee lookup
- `read:confluence-content.all`, `write:confluence-content`, `read:confluence-user` — Confluence page read + write + user lookup
- `offline_access` — required to receive a `refresh_token`. Without this, the access token expires and the user has to redo Phase 1 every hour.

If the user later asks for Compass support, add `read:component:compass` and `write:component:compass` and re-run Phase 1; the new scopes will appear on the consent screen.

### Step 7 — Open the consent flow inside Playwright

Tell the user:

> "I'm opening Atlassian's connection page now. Please sign in there if it asks, then click **Allow** when you see the permissions screen. If you have Atlassian already open in another browser, please close that tab first so we don't get our wires crossed."

Call `mcp__playwright__browser_navigate({ url: <auth URL from Step 6> })`. Take a `mcp__playwright__browser_snapshot()` to see the landing state.

### Step 8 — Detect login state, prompt sign-in if needed

Reason from the snapshot:

- **User is already signed in to Atlassian (cookies present)** → the page goes straight to a consent screen showing "Selr AI Workshop Atlassian Connector wants to access your Atlassian account". Continue to Step 9.
- **User is not signed in** → the page is the Atlassian sign-in form (`id.atlassian.com/login` or similar). Tell the user, *once*: *"Please sign in to your Atlassian account in the browser window I just opened — I'll wait."* Then call `mcp__playwright__browser_wait_for` with a generous timeout, polling for either the consent screen text (e.g. `"wants to access"` or the **Allow** button) or the workspace-picker text (`"Choose a site"`).

If `browser_wait_for` times out (5+ minutes), check in *once*: *"Still on the sign-in page? Anything I can help with?"*

If the user sees an error on the sign-in page (locked account, wrong password, SSO redirect failure), surface their description in a follow-up message and offer to retry from Step 7. Do not advise on Atlassian password reset — that's their identity provider's job.

### Step 9 — Detect the workspace picker or admin-required interstitial

Once past sign-in, the Atlassian consent flow may show one of three states. Snapshot and branch:

#### 9a — Single-site users: straight to consent

The page reads "wants to access your Atlassian account" with **Allow** and **Cancel** buttons. No site picker. Skip to Step 10.

#### 9b — Multi-site users: site picker first

The page shows "Choose a site to grant access to" with a list of the user's Atlassian sites (e.g. `acme.atlassian.net`, `acme-dev.atlassian.net`). Snapshot the options.

If the user has **only one site listed** despite the picker rendering — auto-select it via `browser_click` and continue.

If they have **multiple sites** — surface the list to the user *once*: *"Which Atlassian workspace do you want me to use? I see: \<site 1\>, \<site 2\>, …"* Wait for their answer, then click the matching option in the snapshot.

If the user changes their mind later ("switch my Atlassian workspace"), re-run Phase 1 from Step 3 (fresh DCR + PKCE + state) — Atlassian will prompt the picker again because the freshly-registered client has no prior grant.

#### 9c — Admin-approval-required interstitial

If the snapshot shows phrasing like *"Your administrator must approve this app"*, *"This app requires admin consent"*, or *"Site administrator approval required"*, the user's organisation has gated third-party app installs and the user cannot proceed without admin involvement.

Surface this cleanly and exit:

> "Atlassian is telling me your organisation needs an administrator to approve this connection first. That's a one-time setting — your Atlassian admin can enable it from **Manage your organization → Marketplace and third-party apps**. Once they approve, come back and say *'connect to my Atlassian'* and I'll finish setting up."

Cancel the listener (`kill $LISTENER_PID 2>/dev/null`), close the browser (`mcp__playwright__browser_close()`), delete the temp listener directory, and stop. Do not retry — the block is org-policy, not transient.

### Step 10 — Capture the user's Allow click + the callback

Tell the user:

> "Atlassian is showing the permissions screen now — please click **Allow** so I can finish connecting."

After they click Allow, Atlassian redirects the Playwright tab to `http://127.0.0.1:<PORT>/callback?code=…&state=…`. The Node listener captures the query parameters, writes them to `$LISTENER_OUT`, and renders the success page; the listener process exits ~250ms later.

Wait silently for the listener to finish, with a 10-minute hard timeout to defend against a "user clicked the link in a different browser" race where the callback never lands on the Playwright window:

```bash
( sleep 600 && kill -TERM "$LISTENER_PID" 2>/dev/null ) &
TIMEOUT_PID=$!
wait "$LISTENER_PID"
# Reap the timeout subshell. On Git Bash for Windows the inherited `sleep` can
# orphan if not explicitly killed and waited; this pattern handles all shells.
kill "$TIMEOUT_PID" 2>/dev/null
pkill -P "$TIMEOUT_PID" 2>/dev/null || true
wait "$TIMEOUT_PID" 2>/dev/null || true
sync 2>/dev/null || true
test -s "$LISTENER_OUT" || sleep 0.5  # NTFS write-cache guard on Windows
```

Then read the captured values with a portable parser (no process substitution — Git Bash on Windows lacks reliable `<(...)`):

```bash
CB_CODE=$(grep '^CODE=' "$LISTENER_OUT" | cut -d= -f2-)
CB_STATE=$(grep '^STATE=' "$LISTENER_OUT" | cut -d= -f2-)
CB_ERROR=$(grep '^ERROR=' "$LISTENER_OUT" | cut -d= -f2-)
CB_ERROR_DESCRIPTION=$(grep '^ERROR_DESCRIPTION=' "$LISTENER_OUT" | cut -d= -f2-)
```

If `CB_CODE` and `CB_ERROR` are both empty after the timeout, the callback never landed — most commonly because the user signed in from a different browser than the Playwright window. Tell them: *"Looks like the Allow click landed in a different browser. Let me start fresh — I'll open the connection page again."* Then re-run from Step 3.

#### 10a — Validate `state` (CSRF protection)

If `CB_STATE` does not exactly equal `STATE` from Step 5 → abort. Possible CSRF / interception attempt. Tell the user *once*: *"Something didn't look right with the connection — let me start over."* Re-run Phase 1 from Step 3 with fresh PKCE + state.

#### 10b — Detect denial / error

If `CB_ERROR` is non-empty (e.g. `access_denied`) → the user cancelled. Tell them: *"Looks like you cancelled the permissions screen — no problem. Want me to try again?"* If yes, re-run from Step 7 (same client, same listener — re-bind a new listener if the previous one already exited).

If `CB_CODE` is empty *and* `CB_ERROR` is also empty → the listener received a malformed callback. Re-run from Step 3.

### Step 11 — Exchange the authorisation code for tokens (silent)

Trade the captured code for an access + refresh token:

```bash
curl -fsS -m 30 -X POST "<token_endpoint from Step 2>" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "grant_type=authorization_code" \
  --data-urlencode "code=$CB_CODE" \
  --data-urlencode "redirect_uri=http://127.0.0.1:${PORT}/callback" \
  --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "code_verifier=$CODE_VERIFIER"
```

Parse the JSON response — you need:

- `access_token` — the bearer to write into `~/.claude.json`
- `refresh_token` — the long-lived rotation key, written to a sidecar
- `expires_in` — access-token TTL in seconds (typically 3600)
- `token_type` — must be `Bearer`
- `scope` — confirms which scopes the user actually granted (may be a subset of what we requested)

If the exchange returns an error:
- `invalid_grant` → either the code was already used, expired (codes are short-lived, ~60s), or the `code_verifier` doesn't match. Re-run from Step 5 (fresh PKCE + new authorisation request).
- `invalid_client` → the `client_id` is bad. Delete `~/.claude/atlassian-client.json`, re-run from Step 4.
- `invalid_request` → check that `redirect_uri` exactly matches what was registered (literal `http://127.0.0.1:<port>/callback`).
- Any other error → tell the user *"Atlassian didn't accept the connection — let me try the whole thing again."* Re-run from Step 3.

### Step 12 — Write the bearer header to `~/.claude.json` + persist refresh artifacts

#### 12a — Tell the user about the permission popup, then write `~/.claude.json`

Claude Code's runtime guards `~/.claude/` and `~/.claude.json` with a hardcoded permission gate that the SDK's `bypassPermissions` mode does NOT cover (verified live on PR #157/#158). When Claude writes the bearer header to `~/.claude.json`, the user **will** see a small "allow access to ~/.claude.json" popup. Acknowledge it before the write so the popup is expected, not surprising:

> Tell the user: *"One last thing — you'll see a small permission box pop up asking me to save your connection key. Please click **Allow**."*

Then perform the merge using a canonical Node-based snippet (Node is already required per Phase 0; this avoids `jq` and the `Edit` tool's exact-string-match limits when other servers already exist in the config):

```bash
AT_TOKEN="<access_token from Step 11>" node -e '
  const fs = require("fs");
  const path = require("path");
  const home = require("os").homedir();
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
  j.mcpServers.atlassian = {
    type: "http",
    url: "https://mcp.atlassian.com/v1/mcp",
    headers: { Authorization: "Bearer " + process.env.AT_TOKEN }
  };
  fs.writeFileSync(cfg + ".tmp", JSON.stringify(j, null, 2));
'
mv ~/.claude.json.tmp ~/.claude.json
```

If the merge step's stderr contains `CONFIG_BACKUP=`, the existing `~/.claude.json` was unreadable JSON and Claude has just made a backup. Surface this to the user *once*: *"Your settings file was unreadable, so I made a safe backup before saving — if any of your other connections seem to disappear, the backup is at the path I just created."* (Read the path from `CONFIG_BACKUP=` in stderr.)

The `type: "http"` field is the canonical hosted-MCP transport indicator (per `code.claude.com/docs/en/mcp` — `type: "sse"` is deprecated). A manually-set `headers.Authorization` is documented to bypass Claude Code's own OAuth flow at the time of writing; if a future Claude Code release changes that behaviour, this skill will need revision (track at `code.claude.com/docs/en/mcp`).

On Mac/Linux: `chmod 600 ~/.claude.json` only if you just created the file. Do not change permissions on an existing file the user may have configured. Windows equivalent (Git Bash):

```bash
if [ -n "$WINDIR" ]; then
  icacls "$(cygpath -w ~/.claude.json)" //inheritance:r //grant:r "$USERNAME:F" >/dev/null 2>&1
fi
```

#### 12b — Persist the refresh token to a sidecar

Write `~/.claude/atlassian-refresh.json`:

```json
{
  "refresh_token": "<from Step 11>",
  "access_token_expires_at": <unix epoch + expires_in>,
  "client_id": "<from Step 4>",
  "token_endpoint": "<from Step 2>",
  "scope": "<from Step 11 response>"
}
```

This file is the long-lived state that powers silent token refresh. Treat it like a credential file: `chmod 600` on Mac/Linux; on Windows the `icacls` equivalent.

Do not write the access token to the sidecar — only `~/.claude.json` should hold the access token, and it gets rewritten on every refresh.

#### 12c — Cleanup

Remove the temp listener directory:

```bash
rm -rf "$LISTENER_DIR"
```

Wipe `CODE_VERIFIER`, `STATE`, `CB_CODE` from any in-memory variables you can. They have served their purpose.

### Step 13 — Close the browser and verify

Close the Playwright browser:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection — let me check it works."*

The verification depends on whether the MCP server is already active in the current session:

- **If `mcp__atlassian__*` tools are available** (the MCP server has reloaded): call a read-only Atlassian tool — `getAccessibleAtlassianResources` is the canonical "do you have a working connection?" probe. If it returns the user's site(s), capture the count and continue to Step 14.
- **If the tools are not yet available** (most likely on first setup, since `~/.claude.json` was just written): tell the user *"All saved. Please close and reopen the chat once, then say 'test my Atlassian' and I'll verify the new key."*

If the verification tool returns an error:
- `401 Unauthorized` / `invalid_token` → run the **Token refresh flow** below. If refresh fails, fall through to a full Phase 1 from Step 3.
- `403 Forbidden` → the connection works but your Atlassian user doesn't have permission for that specific resource. Tell the user: *"Your connection is working, but your Atlassian user doesn't have access to that. An admin or the project/space owner may need to share it with you."*
- `429` → "Atlassian is asking us to slow down. Let me try in a moment." Wait 10s, retry once.
- Any other → "Something went wrong — let me try again." Retry once; if still failing, re-run Phase 1 from Step 3.

### Step 14 — Success message

Tell the user, in one short message (include the live site count if available):

> "All done! Your Atlassian is now connected — I can see **\<N\> workspace(s)**. You can ask me things like 'show me my Jira tickets', 'what's assigned to me this sprint?', 'create a Confluence page called Release Notes', or 'summarise the latest comments on PROJ-123'. Give it a try!"

---

## Token refresh flow (autonomous, no user interaction)

Atlassian access tokens are short-lived (typically 1 hour). The sidecar at `~/.claude/atlassian-refresh.json` holds the refresh token, which is single-use and rotated on every refresh — drop a single rotation and the user is locked out.

Run this flow proactively whenever a Phase 2 tool call returns `401`/`invalid_token`, or pre-emptively when `access_token_expires_at` is within 10 minutes of expiring.

### R1 — Read the sidecar

Use Node (already required per Phase 0) — `jq` is unreliable on Git Bash for Windows:

```bash
read_json() { node -e "console.log((JSON.parse(require('fs').readFileSync('$1','utf8'))['$2'])||'')"; }
test -r ~/.claude/atlassian-refresh.json || { echo "no sidecar"; exit 1; }
REFRESH_TOKEN=$(read_json ~/.claude/atlassian-refresh.json refresh_token)
CLIENT_ID=$(read_json ~/.claude/atlassian-refresh.json client_id)
TOKEN_ENDPOINT=$(read_json ~/.claude/atlassian-refresh.json token_endpoint)
```

### R2 — Exchange refresh token for new access + new refresh token

```bash
curl -fsS -m 30 -X POST "$TOKEN_ENDPOINT" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode "grant_type=refresh_token" \
  --data-urlencode "refresh_token=$REFRESH_TOKEN" \
  --data-urlencode "client_id=$CLIENT_ID"
# scope is intentionally omitted — Atlassian preserves the granted scopes on refresh.
# If a future test shows scope is required for refresh, add: --data-urlencode "scope=$SCOPE_FROM_SIDECAR"
```

Parse the response — you get a fresh `access_token`, a fresh `refresh_token` (rotated — the one you sent is now invalid), and a fresh `expires_in`.

### R3 — Atomic-write tokens (refresh sidecar FIRST)

**Critical: write the refresh-token sidecar BEFORE the access-token config.** If we crash between writes:
- **Sidecar-first (this order)** → next tool call hits 401, refresh flow runs, recovers from disk-resident refresh token. **Self-healing.**
- **Access-token-first (the wrong order)** → next tool call hits 401, refresh flow runs, but the on-disk refresh token is the *old* one (rotated and invalidated server-side), refresh returns `invalid_grant`, full Phase 1 required. **Lockout.**

Pattern:
1. Write `~/.claude/atlassian-refresh.json.tmp` with the new refresh token + new `access_token_expires_at`.
2. `mv ~/.claude/atlassian-refresh.json.tmp ~/.claude/atlassian-refresh.json` — atomic rename of sidecar.
3. Write `~/.claude.json.tmp` with the new access token in `mcpServers.atlassian.headers.Authorization` (using the same Node merge snippet as Step 12a).
4. `mv ~/.claude.json.tmp ~/.claude.json` — atomic rename of config.

`chmod 600` both targets (Mac/Linux) after the renames; `icacls` equivalent on Windows.

> **NTFS rename-over-existing caveat.** POSIX guarantees `mv` over an existing target is atomic; on Windows NTFS this is true on most configurations but not strictly guaranteed on every filesystem layout. In the unlikely event a power-loss interrupts the sidecar rename mid-write, the user re-runs Phase 1 from Step 3 and the connector recovers cleanly.

### R4 — Handle refresh failures

If the token endpoint returns:
- `invalid_grant` → the refresh token has been revoked, expired, or already rotated by a parallel session. Delete `~/.claude/atlassian-refresh.json` and run a full Phase 1 from Step 3.
- `invalid_client` → the registered client was revoked. Delete `~/.claude/atlassian-client.json` AND `~/.claude/atlassian-refresh.json` and run a full Phase 1 from Step 3.
- 429 → wait 10s, retry once.
- 5xx / network → tell the user *"Atlassian is slow right now — let me try once more."* Retry once with backoff. If still failing, surface "Atlassian seems to be down — try again in a few minutes."

Never refresh tokens echo back to the user. Never log them to the conversation, even truncated.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__atlassian__*` MCP tools to answer questions and make changes in Jira and Confluence. The hosted Atlassian Rovo Remote MCP server provides first-party tools covering Jira issues, search, projects, comments, transitions, and Confluence pages, spaces, and search — plus a smaller set of Compass tools for teams that use it.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__atlassian__`. Verified against [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server).

> **Note on tool names:** Atlassian does not publish a stable public list of tool names, and the set evolves as the remote MCP server adds coverage. **Discover tool names at runtime** the first time you enter Phase 2 in a new session — list the `mcp__atlassian__*` tools available and map them to the categories below. The names in the tables below are the expected shape, not a guarantee.

#### Jira — Issues & search

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `search_issues` / `jira_search` | Search Jira issues using JQL or simple filters | User asks "show me my tickets", "open bugs in PROJ", "tickets assigned to me" |
| `get_issue` / `jira_get_issue` | Get full details of a specific Jira issue by key | User asks about a ticket by key (e.g. PROJ-123) |
| `create_issue` / `jira_create_issue` | Create a new Jira issue | User asks to raise a bug, story, task — **confirm first** |
| `update_issue` / `jira_update_issue` | Update fields on an existing issue | User asks to change a ticket — **confirm first** |
| `transition_issue` / `jira_transition_issue` | Move an issue through its workflow (e.g. To Do → In Progress → Done) | User asks to move a ticket's status — **confirm first** |
| `add_comment` / `jira_add_comment` | Add a comment to an issue | User asks to comment on a ticket — **confirm first** |

#### Jira — Projects & metadata

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `list_projects` / `jira_list_projects` | List Jira projects in the connected workspace | User asks "what projects do I have?" or you need a project key before creating an issue |
| `get_project` / `jira_get_project` | Get details of a specific project | User asks about a project |

#### Confluence — Pages & search

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `search_pages` / `confluence_search` | Search Confluence pages by text or CQL | User asks "find the onboarding doc", "search Confluence for X" |
| `get_page` / `confluence_get_page` | Get the body of a Confluence page | User asks to read a specific page |
| `create_page` / `confluence_create_page` | Create a new Confluence page in a given space | User asks to write a new doc — **confirm first** |
| `update_page` / `confluence_update_page` | Update an existing page | User asks to edit a page — **confirm first** |

#### Confluence — Spaces

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `list_spaces` / `confluence_list_spaces` | List Confluence spaces in the connected workspace | User asks "what Confluence spaces do I have?" or you need a space key before creating a page |

#### Identity & verification

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `getAccessibleAtlassianResources` / `list_sites` | List the Atlassian sites the current bearer can access | Phase 1 Step 13 verification; "switch my Atlassian workspace" disambiguation |

#### Compass (optional — only if the workspace uses it)

Atlassian's Compass product (software component catalogue) exposes a small set of read-only tools for components and scorecards. Surface these only if the user's workspace has Compass enabled and the Phase 1 scopes included `read:component:compass` — otherwise these tools will return permission errors.

> **If a tool name in the tables above does not resolve**, list the available `mcp__atlassian__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Atlassian" / "Set up Jira" / "Set up Confluence" | **Run Phase 1** |
| "Switch my Atlassian workspace" | Re-run Phase 1 from Step 3 (fresh DCR + PKCE so the consent screen surfaces the picker again) |
| "My Atlassian stopped working" / "I'm getting auth errors" | Run the **Token refresh flow** first; if it fails, full Phase 1 |
| "Show me my Jira tickets" | `search_issues` with assignee = currentUser() |
| "What's open in [project]?" | `list_projects` (find key) → `search_issues` filtered by project |
| "Show me ticket PROJ-123" | `get_issue` |
| "Create a bug for [description]" | `list_projects` (find key if unknown) → `create_issue` — **confirm first, summarise fields** |
| "Move PROJ-123 to In Progress" | `get_issue` (find available transitions) → `transition_issue` — **confirm first** |
| "Comment on PROJ-123 saying [text]" | `add_comment` — **confirm first, show the text back** |
| "Update the description on PROJ-123" | `update_issue` — **confirm first** |
| "Search Confluence for [topic]" | `search_pages` |
| "Open the onboarding doc in Confluence" | `search_pages` → `get_page` |
| "Create a Confluence page called [title] in [space]" | `list_spaces` (find key if unknown) → `create_page` — **confirm first, summarise content** |
| "Edit the [page] doc to add [section]" | `search_pages` → `get_page` → `update_page` — **confirm first** |
| "What projects are in my Atlassian?" | `list_projects` |
| "What spaces are in my Confluence?" | `list_spaces` |
| "Which Atlassian workspaces am I in?" | `getAccessibleAtlassianResources` |

---

## Error Handling (Phase 2)

When an Atlassian tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / `invalid_token` | "Your Atlassian connection key has expired — let me refresh it." | Run **Token refresh flow** silently, retry the original tool call. If refresh fails, run full Phase 1 from Step 3. |
| 403 Forbidden | "Your Atlassian user doesn't have permission for that project or page. An admin or the page/project owner may need to share it with you." | User asks the owner to grant access; nothing to fix in the connector |
| 404 Not Found (issue / page / project / space) | "I couldn't find that record — let me search for it again." | Use `search_issues` / `search_pages` / `list_projects` / `list_spaces` to refresh |
| 429 Rate limited | "Atlassian is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| Wrong workspace connected | "Looks like we're pointed at a different Atlassian workspace than you meant. Let me switch you over." | Re-run Phase 1 from Step 3 (fresh DCR + PKCE), pick the correct workspace on the consent picker |
| `missing_scope` | "I need one more permission to do that. Let me reconnect with the right access." | Re-run Phase 1 from Step 5 with an expanded scope list, user re-clicks Allow |
| MCP server not running | "The Atlassian connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| SSE endpoint used / 410 Gone on `/v1/sse` | "Your Atlassian connection is pointing at the old endpoint — let me update it." | Rewrite `mcpServers.atlassian.url` in `~/.claude.json` to `https://mcp.atlassian.com/v1/mcp` and reload |
| Any other API error | "Something went wrong with Atlassian — let me try again." | Retry once; if still failing, run **Token refresh flow** |

---

## Scope Limitations

The Atlassian MCP connector **can** do (via the official Atlassian Rovo Remote MCP server):
- Search, read, create, update, comment on, and transition Jira issues
- List Jira projects and read project metadata
- Search Confluence pages and read page bodies
- Create and update Confluence pages
- List Confluence spaces
- Read Compass components and scorecards (if the workspace uses Compass and the relevant scopes were granted)

The Atlassian MCP connector **cannot** do (needs the Atlassian UI or other tools):
- **Cloud only** — Data Center / Server installations are not supported by the official remote MCP server. Self-hosted Atlassian deployments need a different integration path (manual REST API wrapper, community MCP, or a Jira/Confluence plugin inside the server).
- Configure Jira workflows, custom fields, screen schemes, or permission schemes
- Manage Atlassian users, groups, or billing
- Run Jira automations or Forge app configurations
- Export issues or pages in bulk formats (CSV, PDF, Word) — use the Atlassian UI
- Manage multiple Atlassian workspaces in one session — one workspace per OAuth grant per `~/.claude.json` entry (use "switch my Atlassian workspace" to change)
- Access Atlassian products outside of Jira / Confluence / Compass — Bitbucket, Trello, Statuspage, etc. are separate integrations

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, transitioning, or commenting** — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover project and space keys before writing** — Jira projects are referenced by short keys (e.g. `PROJ`) and Confluence spaces by space keys (e.g. `ENG`). Always call `list_projects` / `list_spaces` once per session before any `create_issue` / `create_page` / `update_page`, unless you already have the key from earlier in the conversation.
- **Issue keys are authoritative** — issue keys like `PROJ-123` are the source of truth. Always show the key when summarising tickets so the user can click through to Atlassian directly.
- **Confluence pages can contain sensitive content** — pages often contain internal strategy, HR, or security content. Never paste a full page into a public log or chat without checking with the user first. Prefer summaries over raw excerpts unless asked.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. For Jira searches, include key, summary, status, and assignee by default.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 47 open tickets across 3 projects; 12 are assigned to you, and 4 are in progress"), then offer to show details.
- **Pagination** — default to 25 issues / 10 pages unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — Atlassian Cloud applies per-workspace rate limits. For bulk updates, batch calls and pause between batches.
- **Refresh tokens proactively** — when an access token is within 10 minutes of expiring (`access_token_expires_at` from the sidecar minus current time), run the refresh flow before the next tool call. This avoids mid-tool-call 401s.
- **Transitions depend on the workflow** — valid transitions (e.g. "In Progress", "Done", "Blocked") vary per project. Fetch available transitions on the issue before calling `transition_issue`; if the target transition isn't valid, tell the user plainly instead of guessing.
- **Creating or updating pages is visible to the whole space** — Confluence updates notify watchers. For bulk edits, always show the user a sample of the first change before proceeding with the rest.
- **Never log or echo credentials** — never echo the contents of `~/.claude.json` or `~/.claude/atlassian-*.json` to the user; never paste sign-in URLs, codes, or tokens into chat.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **monday-connector**: Sibling autonomous Playwright connector — simpler PAT case, same snapshot-and-reason model
- **slack-connector**: Sibling autonomous Playwright connector — OAuth-app case, same Allow-click choreography
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Atlassian consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Atlassian auth or API errors
- **n8n-workflow-patterns**: Build Jira- or Confluence-triggered automations once the connector is live
