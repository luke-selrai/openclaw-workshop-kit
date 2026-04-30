---
name: linear-connector
description: "Connect and operate Linear via the official first-party Linear MCP server (https://mcp.linear.app/mcp). Phase 1 is a 6-step Playwright-driven install: register the server with `claude mcp add`, open Claude Code's OAuth start URL inside the Playwright MCP browser, detect login state and prompt sign-in only if needed, auto-click Allow on the consent screen, auto-detect the callback via `browser_wait_for`, then verify with a `mcp__linear__*` smoke call. If the user's workspace blocks third-party OAuth apps, Phase 1 silently switches to an autonomous Personal API key fallback — Claude drives Linear → Settings → API → Personal API keys, mints/reveals the key, reads it directly from the DOM via `browser_evaluate`, and re-registers the MCP entry with an `Authorization: Bearer` header. The user's only manual moments are signing in to Linear inside the Playwright window and (OAuth path) clicking Allow. Use this skill when the user asks to set up Linear, connect their issue tracker, or interact with issues, projects, teams, comments, or documentation."
allowed-tools: mcp__linear__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Project Management & Issue Tracking
  tags:
    - linear
    - issues
    - projects
    - tickets
    - sprints
    - mcp
  pairs-with:
    - skill: atlassian-connector
      reason: Sibling hosted OAuth-only MCP connector — the canonical 6-step Playwright-driven install pattern. Reference for OAuth choreography.
    - skill: monday-connector
      reason: Sibling project-management connector — reference for the autonomous PAT-page DOM-extract fallback pattern.
    - skill: canva-connector
      reason: Sibling Playwright-driven autonomous connector — same OAuth shape with an admin-allowlist branch.
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector — identical install pattern.
    - skill: email-composer
      reason: Draft follow-ups based on issue updates or status changes.
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by Linear issue events.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Linear consent flow and the API-key page.
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Linear auth or API errors.
---

# Linear Connector

## Overview

This skill lets you read and update a user's Linear workspace on their behalf using the **official first-party Linear MCP server** hosted at `https://mcp.linear.app/mcp` (see [linear.app/changelog/2025-05-01-mcp](https://linear.app/changelog/2025-05-01-mcp) and [linear.app/docs/mcp](https://linear.app/docs/mcp)). It has two phases:

- **Phase 1 — Install & Auth (autonomous, 6 steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks Allow on the consent screen, auto-detects the callback via `browser_wait_for`, then verifies with a `mcp__linear__*` smoke call. The user's only manual moments are signing in to Linear inside the Playwright window and clicking Allow on the consent screen. Token storage is handled by Claude Code's MCP runtime — there is no manual `~/.claude.json` token write on the OAuth path. If the workspace blocks third-party OAuth apps (or OAuth otherwise fails for a workspace-policy reason), Phase 1 silently switches to an autonomous Personal API key fallback (Step 3B onward) that drives the Linear settings page, mints/reveals a key, captures it from the DOM, and re-registers the MCP entry with an `Authorization: Bearer` header.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__linear__*` native tools to read and update Linear data.

**Which phase to run** — Before any tool call, check whether the Linear MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.linear` entry. If present, attempt a verification tool call (Phase 1 Step 6). If it succeeds, the connector is ready — skip to Phase 2. If it 401s, walk Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **A self-hosted Linear MCP server.** Linear publishes the hosted endpoint at `https://mcp.linear.app/mcp` as the only deployment. Self-hosting is not supported.
- **Direct Linear GraphQL API calls.** All reads and writes go through the MCP server, not direct HTTP calls to the Linear API.
- **The legacy `/sse` transport endpoint.** Linear's original SSE endpoint is deprecated. Always use the streamable HTTP endpoint at `https://mcp.linear.app/mcp`.
- **A custom OAuth client (DCR replication, custom PKCE, loopback listener).** Claude Code's MCP runtime owns the OAuth dance natively; we do not register our own client, run our own callback listener, or store OAuth tokens manually. The skill's job is to choreograph Playwright + Claude Code's native OAuth handler — not to replicate OAuth.

### How auth works under the hood

The Linear MCP server is a hosted OAuth 2.1 server (verified live 2026-04-30 against `mcp.linear.app/.well-known/oauth-authorization-server`): the discovery document advertises `authorization_endpoint = https://mcp.linear.app/authorize`, `token_endpoint = https://mcp.linear.app/token`, `registration_endpoint = https://mcp.linear.app/register`, `code_challenge_methods_supported = ["S256"]`, public-client `none` auth method, and `client_id_metadata_document_supported = true` (RFC 7591 + the metadata-document DCR variant). The MCP transport endpoint `https://mcp.linear.app/mcp` returns `401 WWW-Authenticate: Bearer realm="OAuth"` with `resource_metadata=https://mcp.linear.app/.well-known/oauth-protected-resource`, and that protected-resource doc confirms `bearer_methods_supported: ["header"]` — both auth paths flow through an `Authorization: Bearer` header.

The Linear MCP server supports two authentication paths, per Linear's MCP documentation:

1. **OAuth 2.1 with Dynamic Client Registration (RFC 7591) — default.** Clients self-register at runtime via `POST https://mcp.linear.app/register`; there is no pre-registered app, no client secret to copy, and no token to paste. From the SKILL's perspective this is a standard OAuth 2.1 + PKCE flow at `mcp.linear.app` — Claude Code's MCP runtime drives it natively. The skill only opens the start URL inside Playwright, auto-clicks Allow, and waits for the callback.
2. **Personal API key via `Authorization: Bearer <key>` header — fallback.** Linear Personal API keys (prefix `lin_api_`) are issued from Linear → Settings → API → Personal API keys. The hosted MCP server accepts them via a request header. We use this branch only when OAuth is blocked — for example, when a workspace admin has disabled third-party OAuth apps. The skill drives this branch end-to-end too: Playwright opens the keys page, clicks Create key, fills a name, reads the freshly revealed key from the DOM via `browser_evaluate`, and re-registers the MCP entry with the captured key as a header.

Practical implications:

- **OAuth is always tried first.** It needs no key storage on the user's machine and no key rotation.
- **The PAT fallback is silent.** If Step 3A's snapshot detects an OAuth-blocked state, the skill quietly switches to Step 3B without surfacing OAuth-internal jargon to the user.
- **Personal API keys are revealed only once.** Linear shows the key value at creation time and never again. We mint a fresh key rather than asking the user to surface an existing one.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Linear in the Playwright window (and on the OAuth path, clicks Allow). Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and (OAuth path) "please click Allow on the screen Linear just showed you."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, DCR, PKCE, scope, token, tenant, MCP, endpoint, JSON, REST, GraphQL, environment variable, Playwright, browser automation, redirect URI, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer / Personal API key → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - workspace → **"your Linear workspace"**
  - close and reopen Claude Code → **"close and reopen the chat"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Linear for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Linear is now connected"). No commentary in between snapshots, clicks, or evaluates.
- **React to success and failure warmly.** Good: "That worked — your Linear is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails (including OAuth-blocked-by-policy), say "No problem — let me try a different way," then silently switch to the PAT fallback.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.
- **Never echo the connection key** back to the user. Never include it in any output visible to the user, even truncated.

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
const av = (j.mcpServers || {}).linear;
console.log(av ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 6 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → run full Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest` (the `--` separator keeps Claude Code from consuming `npx` as an `add` flag), ask the user to close and reopen the chat, then retry.

---

## PHASE 1 — Install & Auth (6 steps, autonomous via Playwright)

### Step 1 — Orient the user

Tell the user, in one short message:

> "I'll connect your Linear now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 — Register the MCP server with `claude mcp add`

Silently register the hosted Linear MCP server in the user's config:

```bash
claude mcp add linear https://mcp.linear.app/mcp --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output) — write the entry directly to `~/.claude.json` via the Node merge pattern. The rename is inside Node so the swap is atomic on every platform (Mac / Linux / Windows Git Bash) and does not run if the JSON write fails:

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
  j.mcpServers.linear = { type: "http", url: "https://mcp.linear.app/mcp" };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

> **Do not write the legacy `/sse` transport URL.** Linear's SSE endpoint is deprecated. The streamable endpoint above is the only one you should wire in.

### Step 3 — Open Claude Code's OAuth start URL inside Playwright (default branch)

When Claude Code's MCP runtime first contacts an unauthenticated hosted server, it emits an OAuth start URL for the user to visit. Capture that URL and open it inside the Playwright MCP browser instead of the user's default browser.

**How to obtain the OAuth start URL.** Claude Code 2.x does not publish a stable scriptable subcommand to mint the URL on demand — the supported way is to let the runtime emit it as part of the 401 challenge when an unauthenticated tool call is made. Two paths, in order of preference:

1. **401-challenge capture (primary).** Invoke any `mcp__linear__*` tool. Claude Code surfaces the OAuth start URL alongside the 401. Per the live discovery document, the canonical authorize URL is `https://mcp.linear.app/authorize?...` (with `client_id`, `redirect_uri`, `response_type=code`, `code_challenge`, `code_challenge_method=S256`, and `state` query params); some Claude Code builds may also surface a `linear.app/oauth/authorize` shape on the way through. Capture the first matching URL from the surfacing.

2. **`claude mcp` subcommand (best-effort).** Some Claude Code builds expose an `authenticate` or equivalent subcommand. Probe with `claude mcp --help` and parse for an authenticate-style verb; if present, run it and capture stdout/stderr. If absent, fall back to path 1. Either way, the URL pattern to grep for is broad enough to catch both shapes:

```bash
# Adjust the input source to whatever you have available (subcommand stderr, tool surfacing, etc.)
AUTH_URL=$(echo "$INPUT" | grep -oE 'https://(mcp\.linear\.app|linear\.app/oauth)/[^[:space:]]+' | head -1)
echo "AUTH_URL=$AUTH_URL"
```

Then drive Playwright to that URL:

```
mcp__playwright__browser_navigate({ url: <AUTH_URL> })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in + consent UI visible** (you see Linear's app-permission screen with an Allow / Authorize button and the Claude Code app name) → continue to Step 4.
- **Not logged in** (Linear sign-in form, "Continue with Google/Apple/Email", magic-link prompt, or SSO redirect) → tell the user, *once*: *"Please sign in to your Linear account in the browser window I just opened. On the next screen you'll see an **Allow** button — click it once you're there."* Then `mcp__playwright__browser_wait_for` polling for consent text (`"would like access"` / `"requesting access"` / `"Allow"` / `"Authorize"`) or admin-block text (`"administrator"` / `"workspace admin"` / `"third-party"` / `"disabled"`). Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*
- **Workspace policy blocks third-party OAuth** (Linear shows a message like "third-party apps are disabled by your workspace admin", or the Authorize button is missing/disabled, or a permission-denied screen renders without an Allow control) → silently switch to **Step 3B** (PAT fallback). Do not surface OAuth-internal jargon to the user; just say *"Let me try a different way — should still take about a minute."*

### Step 3B — Personal API key fallback (only when OAuth is blocked)

This branch is only entered when Step 3's snapshot detects an OAuth-blocked state (workspace admin has disabled third-party OAuth apps, missing/disabled Allow button on a permission-denied screen, or a clear "third-party apps disabled" message). The user is not told why — just that you're trying a different way. After this branch completes, jump straight to Step 6 (verify) — Steps 4 and 5 are OAuth-only.

Tell the user, in one short message:

> "Your workspace blocks the one-click path, so I'll use the access-key route — same browser window, no extra steps for you."

Navigate to Linear's Personal API keys page. The canonical URL is workspace-scoped: `https://linear.app/<workspace>/settings/api`. If you don't yet know the workspace slug, navigate to `https://linear.app/settings/api` first — Linear redirects to the workspace-scoped path automatically. Once on a workspace path, capture the slug for any later operations:

```
mcp__playwright__browser_navigate({ url: "https://linear.app/settings/api" })
```

Then, after the redirect:

```javascript
() => {
  const m = window.location.pathname.match(/^\/([^/]+)\/settings\/api/);
  return m ? m[1] : null;
}
```

Take a snapshot. Reason from it:

- **Not signed in** → tell the user *once*: *"Please sign in to your Linear account in the browser window I just opened — I'll take it from there."* Poll silently with `mcp__playwright__browser_wait_for({ text: "Personal API keys" })` (or any settings-shell element such as the **Create key** / **New key** control).
- **Signed in, on the API page** → continue.

Find the **Personal API keys** section (scroll if needed). The page will show one of these states:

- **No keys yet** → click the **Create key** / **New key** button (`browser_click`). A modal or inline form will appear asking for a label/name. Fill it via `browser_type` with `Claude Assistant` (use a unique suffix like `Claude Assistant 2026-04-30` if a key with that label already exists). Submit.
- **Existing keys listed but no fresh-key reveal in view** → click **Create key** anyway. We mint a fresh one rather than reusing an old one — Linear only shows the key value once, at creation time, and the page never re-reveals an existing key.

After creating, Linear reveals the new key inline (a long string in a textarea or code block, often with a **Copy** button next to it). Re-snapshot. Read the revealed key directly via `browser_evaluate` — adapt the selector based on what the snapshot shows. Prefer the snapshot's labelled accessibility node over a generic readonly-input fallback:

```javascript
() => {
  const candidates = [
    ...document.querySelectorAll(
      'input[readonly], textarea[readonly], code, pre, [data-testid*="key" i], [data-testid*="token" i]'
    ),
  ];
  const value = candidates
    .map(el => (el.value ?? el.textContent ?? '').trim())
    .find(v => /^lin_api_[A-Za-z0-9_-]{20,}$/.test(v));
  return value || null;
}
```

**Validation rules (silent):**
- Linear Personal API keys start with `lin_api_` and are typically 40+ characters long. The regex above enforces both prefix and a minimum body length.
- If the captured string doesn't match, re-snapshot once and try again — the reveal sometimes takes a beat after the click. If two snapshot attempts still don't yield a valid key, stop and tell the user: *"I'm having trouble reading the connection key off the page — could you tell me what you see on screen?"* Use their description to locate the right control, then re-attempt the read.

Store the key in memory for the registration step. Never write it to chat. Never echo it, even truncated.

**Re-register the MCP server with the captured key.** Prefer `claude mcp add`:

```bash
claude mcp add linear https://mcp.linear.app/mcp \
  --transport http \
  --scope user \
  --header "Authorization: Bearer <key captured above>"
```

**Fallback if `claude mcp add` errors** — overwrite the previously-written entry from Step 2 via the same Node merge pattern, this time including a `headers` field. Atomic via Node `renameSync`. Pass the captured key via the `LINEAR_KEY` env var on the same line so the value never appears as a literal positional arg in shell history:

```bash
LINEAR_KEY="<key captured above>" node -e '
  const fs = require("fs"), path = require("path"), home = require("os").homedir();
  const cfg = path.join(home, ".claude.json");
  const key = process.env.LINEAR_KEY;
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
  j.mcpServers.linear = {
    type: "http",
    url: "https://mcp.linear.app/mcp",
    headers: { Authorization: "Bearer " + key }
  };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

(The `LINEAR_KEY=…` prefix is bash syntax. On Windows cmd.exe use `set LINEAR_KEY=… && node -e '…'` instead — though in practice this skill runs from bash on every supported platform via Claude Code's harness.)

Close the Playwright browser via `mcp__playwright__browser_close()` and skip to **Step 6**.

### Step 4 — Auto-click Allow + auto-detect callback

#### 4a — Narrate, click Allow

Snapshot the consent page. Extract human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return { scopes: items.slice(0, 12) };
}
```

Surface a one-line summary so the user has visibility into what's being authorised (3-5 representative scopes deduplicated):

> "Linear is showing the permissions screen — it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Accept` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|accept|authori[sz]e|grant access)/i>,
  element: "Allow button on the Linear consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically — please click **Allow** in the browser window."*

#### 4b — Auto-detect callback completion

Linear redirects to Claude Code's localhost callback (Claude Code's MCP runtime owns the listener). Wait for the redirect to complete via `browser_wait_for` on the post-redirect page text. The exact callback page text is not stable across Claude Code 2.x builds — poll for any of several plausible markers, and as a stronger signal also detect a URL change to `localhost`/`127.0.0.1` via a `browser_evaluate`:

```
mcp__playwright__browser_wait_for({
  text: "you can close this tab" OR "connection complete" OR "successfully authenticated" OR "authentication successful",
  time: 300
})
```

If the text wait does not match, run a follow-up `browser_evaluate` to check whether the URL has changed to a localhost callback — this is the more reliable signal that the OAuth flow has handed back the code:

```javascript
() => /^https?:\/\/(localhost|127\.0\.0\.1)(:|\/)/.test(window.location.href)
```

If either succeeds, treat the callback as complete and skip to **Step 6**. If neither succeeds within 5 minutes, check in *once* with the user. Do not nag.

If the user clicks **Cancel** or **Deny** instead of **Allow**, Linear redirects back without a code. Tell them: *"Looks like you declined the permission — no problem. Want me to try again?"* If yes, re-navigate to the OAuth start URL and re-run Step 4.

### Step 5 — Detect organization-administrator-approval-required interstitial (rare)

Some Linear workspaces enforce admin review for third-party connectors. After Step 4's Allow click — or in the rare case that the consent flow never reached an Allow button despite a valid OAuth start URL — Linear may render an interstitial requiring administrator approval. This is distinct from the OAuth-disabled case in Step 3 (which surfaces before the consent screen).

Detect via `browser_evaluate` against the post-Allow snapshot:

```javascript
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /administrator (must |approve|approval)/i,
    /admin (consent|approval) (required|needed)/i,
    /your (organization |organisation |org )?admin/i,
    /awaiting approval/i,
    /requires admin/i,
  ];
  return markers.some(re => re.test(text));
}
```

If the function returns `true`, surface cleanly and exit:

> "Linear is telling me your workspace administrator needs to allow this connection first. Once they've approved it, come back and say *'connect to my Linear'* and I'll finish setting up. If they can't approve it, tell me and I'll try a different way."

If the user comes back later and the admin still hasn't approved it, fall through to the **Step 3B** PAT fallback — Personal API keys do not require workspace-admin approval and bypass this block.

If the function returns `false`, the consent flow completed normally — proceed to Step 6.

### Step 6 — Close the browser + verify

Close Playwright (if not already closed):

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection — let me check it works."*

Verify by calling a canonical Linear read-only smoke tool. Tool names aren't always discoverable up-front — discover at runtime by listing the `mcp__linear__*` tools available in the current session and pick a safe read-only one (e.g. `list_teams` with `limit: 1`, or a current-user fetch). If it returns a result (including an empty list — that's fine), the connection works.

The verification depends on whether the MCP server is already active in the current session:

- **Tools available + call returns a result (or empty list)** → capture any obvious counts (teams, projects, issues), surface a success message including a live count.
- **Tools not yet available** (most likely on first setup, since the MCP config was just written and Claude Code hasn't reloaded the tool surface) → tell the user *"All saved. Please close and reopen the chat once, then say 'test my Linear' and I'll verify the new connection."*
- **Call returns 401 / `invalid_token`** → on the OAuth path, walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop. On the PAT path, the captured key may have been truncated or revoked — re-run Step 3B to mint a fresh one.
- **Call returns 403** → on the PAT path, the captured key is valid but lacks the right scopes; re-run Step 3B and re-mint. On the OAuth path, the user's Linear role may be insufficient for the smoke call; surface as a permission issue rather than an auth issue.
- **`429 Rate limited`** → "Linear is asking me to slow down — let me wait a moment and try again." Wait 10 seconds, retry once.

### Success message

Tell the user, in one short message (include any obvious live count if available — teams, projects, or issues assigned-to-currentUser):

> "All done! Your Linear is now connected. You can ask me things like 'show me my open issues', 'what's in the mobile project this sprint?', or 'create a bug report for the login page'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__linear__*` MCP tools below to answer questions and make changes in Linear. The hosted Linear MCP server provides **21 first-party tools** covering issues, projects, teams, users, comments, statuses, labels, and documents.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__linear__`. The [Linear MCP docs](https://linear.app/docs/mcp) describe the server's purpose ("finding, creating, and updating objects in Linear like issues, projects, and comments") but do not enumerate tool names — Linear adds tools over time. The list below reflects the tools advertised at the time of writing; if a name does not resolve after Phase 1, list the available `mcp__linear__*` tools in the current session to discover the current inventory.

#### Issue Management

| Tool | Description | Use when |
|---|---|---|
| `list_issues` | List issues across the workspace with filters (team, status, assignee, project) | User asks "show me the bugs", "what's in progress", or needs a pick list |
| `get_issue` | Fetch a single issue by ID or identifier (e.g. `ENG-123`) | User references a specific ticket |
| `create_issue` | Create a new issue — **confirm first** | User asks to file a bug, task, or feature |
| `update_issue` | Edit an issue (title, description, status, assignee, priority, labels) — **confirm first** | User asks to change a ticket |
| `list_my_issues` | List issues assigned to the authenticated user | User asks "what am I working on", "what's on my plate" |

#### Project & Team Coordination

| Tool | Description | Use when |
|---|---|---|
| `list_projects` | List projects in the workspace | User asks "what projects do we have", or needs a project ID |
| `get_project` | Fetch a single project by ID | User asks about a specific project |
| `create_project` | Create a new project — **confirm first** | User asks to start a new initiative |
| `update_project` | Edit a project (name, description, status, lead, dates) — **confirm first** | User asks to change a project |
| `list_teams` | List teams in the workspace | Verification call, or user asks "who's on what team" |
| `get_team` | Fetch a single team by ID | User references a specific team |
| `list_users` | List users in the workspace | User asks "who can I assign this to", or needs a user ID |
| `get_user` | Fetch a single user by ID | User asks about a specific teammate's workload |

#### Comments, Statuses, Labels, Documents

| Tool | Description | Use when |
|---|---|---|
| `list_comments` | List comments on an issue | User asks "what's the latest on ENG-123" |
| `create_comment` | Add a comment to an issue — **confirm first** | User asks to leave a note on a ticket |
| `list_issue_statuses` | List possible statuses for a team (Backlog, Todo, In Progress, Done, etc.) | Before `update_issue` when changing status |
| `get_issue_status` | Fetch a single status by ID | Verifying a specific workflow state |
| `list_issue_labels` | List labels available for issues | Before `create_issue` or `update_issue` when adding labels |
| `get_document` | Fetch a Linear document by ID | User references a spec or design doc |
| `list_documents` | List documents in a project or workspace | User asks "what docs do we have" |
| `search_documentation` | Search Linear documentation (help center content) | User asks "how do I use Linear's X feature" |

> **If a tool name in the table above does not resolve**, list the available `mcp__linear__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Linear" / "Help me set up Linear" | **Run Phase 1** |
| "My Linear stopped working" / "I'm getting auth errors" | Walk Phase 1 from Step 3 (Claude Code re-runs the OAuth dance, or re-mints a Personal API key on the PAT path) |
| "Show me my open issues" / "What am I working on?" | `list_my_issues` |
| "What's in the backlog for the mobile team?" | `list_teams` → `list_issues` (team filter, status=Backlog) |
| "Show me ENG-123" / "What's the status of that login bug?" | `get_issue` |
| "Create a bug report for the login page" | `list_teams` → `list_issue_labels` → `create_issue` — **confirm first** |
| "Move ENG-123 to In Progress and assign it to Jane" | `list_users` → `list_issue_statuses` → `update_issue` — **confirm first** |
| "What projects are active?" | `list_projects` |
| "Tell me about the Q2 roadmap project" | `list_projects` → `get_project` |
| "Start a new project called 'Customer Portal'" | `create_project` — **confirm first, summarise fields** |
| "Who's on the engineering team?" | `list_teams` → `list_users` |
| "What's the latest on ENG-123?" | `get_issue` → `list_comments` |
| "Leave a note on ENG-123 saying I'll pick it up tomorrow" | `create_comment` — **confirm first** |
| "Show me the PRD for the checkout rework" | `list_documents` → `get_document` |
| "How do I use Linear's triage feature?" | `search_documentation` |

---

## Error Handling (Phase 2)

When a Linear tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Linear sign-in has expired — let me reconnect you." | OAuth path: walk Phase 1 from Step 3; Claude Code re-runs OAuth. PAT path: re-run Step 3B to mint a fresh Personal API key. |
| 403 Forbidden | "Your Linear user doesn't have permission for that team or project. A workspace admin may need to adjust your access." | User talks to a workspace admin; nothing to fix in the connector |
| 404 Not Found (issue / project / user) | "I couldn't find that record — let me search again." | Use `list_issues` or `list_projects` to refresh the list |
| 429 Rate limited | "Linear is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. Linear applies per-workspace rate limits — for bulk operations, batch and pause. |
| MCP server not running | "The Linear connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Any other API error | "Something went wrong with Linear — let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The Linear MCP connector **can** do (via the official Linear MCP server):

- List, read, create, and update issues across teams and projects
- List and manage projects (create, edit metadata, status, leads, dates)
- Inspect teams, users, statuses, and labels
- Read and post comments on issues
- Read Linear documents and search Linear's documentation

The Linear MCP connector **cannot** do (needs the Linear UI or other tools):

- Manage workspace billing, seat counts, or plan changes
- Configure SSO, SCIM, or identity provider settings
- Create or delete teams (team creation is admin-only via UI)
- Manage workflow states / custom issue statuses beyond reading them
- Configure Linear's GitHub/GitLab/Slack integrations
- Export issues in CSV / PDF format (use the Linear UI)
- Trigger Linear automation rules directly (rules fire on issue events)
- **Bypass workspace admin allowlisting** — if a workspace blocks third-party OAuth and Personal API keys are also disabled, the only path forward is for the workspace admin to allowlist the Linear MCP or re-enable Personal API keys

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, editing, or commenting** — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover IDs before writing** — Linear teams, projects, users, statuses, and labels are referenced by their IDs. Always call the relevant `list_*` tool once per session before any `create_*` or `update_*`, unless you already have the ID from earlier in the conversation.
- **Issue identifiers are human-readable** — Linear issues have identifiers like `ENG-123` or `DES-45` alongside their internal ID. Accept either from the user, but confirm which one you used before a mutation.
- **Status names are per-team** — each team defines its own workflow states. Always call `list_issue_statuses` for the target team before `update_issue` when changing status; do not assume "In Progress" has the same ID across teams.
- **Labels are workspace-scoped or team-scoped** — always call `list_issue_labels` before applying labels so you use the right ID.
- **Mentions and assignees** — use `list_users` to look up the right user ID before assigning; never guess from a display name.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. For issue lists, show at minimum: identifier, title, status, assignee.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 23 open issues across 4 teams; 7 are assigned to you"), then offer to show details.
- **Pagination** — default to 25 issues unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — Linear applies per-workspace rate limits. For bulk operations (e.g. bulk-closing stale issues), batch `update_issue` calls and pause between batches.
- **Bulk updates are destructive** — closing, re-assigning, or deleting many issues at once is hard to reverse. Always show the user a sample of the first change before proceeding with the rest, and prefer to act in batches of 5–10 with a confirmation between batches.
- **Never log or echo credentials** — on the OAuth path there's no token to leak (handled by Claude Code). On the PAT path, never echo the captured key; never include it in any output visible to the user, even truncated; never echo the contents of `~/.claude.json`.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **atlassian-connector**: Sibling hosted OAuth-only MCP connector — the canonical 6-step Playwright-driven install pattern this skill is derived from
- **canva-connector**: Sibling Playwright-driven autonomous connector — same OAuth shape with an admin-allowlist branch
- **jotform-connector**: Sibling hosted OAuth-only MCP connector — identical install pattern, no PAT fallback
- **monday-connector**: Sibling project-management connector — reference for the autonomous PAT-page DOM-extract fallback pattern
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Linear consent flow and the API-key page
- **n8n-workflow-patterns**: Build Linear-triggered automations once the connector is live
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Linear auth or API errors
