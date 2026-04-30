---
name: atlassian-connector
description: "Connect and operate Atlassian (Jira + Confluence, plus Compass) via the official first-party Atlassian Remote MCP server (https://mcp.atlassian.com/v1/mcp). Phase 1 is a 5-step Playwright-driven install with 3-stage bridge OAuth: register the server with `claude mcp add`, open Claude Code's OAuth start URL inside the Playwright MCP browser, detect login state and prompt sign-in only if needed, auto-click Allow on the consent screen (workspace picker handled there), auto-detect the callback via `browser_wait_for`, surface the organization-administrator-approval-required interstitial cleanly if it appears, then verify with a `mcp__atlassian__*` smoke call. The user's only manual moment is signing in to Atlassian inside the Playwright window. Use this skill when the user asks to set up Atlassian, connect Jira or Confluence, or interact with issues, tickets, sprints, boards, pages, or spaces."
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
    - skill: canva-connector
      reason: Sibling Playwright-driven autonomous connector — identical install pattern, hosted bridge OAuth
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector — identical install pattern
    - skill: email-composer
      reason: Draft follow-ups or status notes based on Jira tickets and Confluence updates
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Jira issues or Confluence changes
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Atlassian consent flow
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Atlassian auth or API errors
---

# Atlassian Connector (Jira + Confluence)

## Overview

This skill lets you read and update a user's Atlassian Cloud workspace on their behalf — Jira, Confluence, and Compass — using the **official first-party Atlassian Remote MCP server** hosted at `https://mcp.atlassian.com/v1/mcp`. It has two phases:

- **Phase 1 — Install & Auth (autonomous, 5 numbered steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks Allow on the consent screen (which also surfaces the workspace picker), auto-detects the callback via `browser_wait_for`, surfaces the organization-administrator-approval-required interstitial cleanly when present. The user's only manual moment is signing in to Atlassian inside the Playwright window. Token storage is handled by Claude Code's MCP runtime — there is no manual `~/.claude.json` token write.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__atlassian__*` native tools to read and update Jira and Confluence data.

**Which phase to run** — Before any tool call, check whether the Atlassian MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.atlassian` entry. If present, attempt a verification tool call (Phase 1 Step 6). If it succeeds, the connector is ready — skip to Phase 2. If it 401s, walk Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### Prerequisites the user must already have

Phase 1 fails cleanly but cannot proceed without these. Surface them in Step 1 before opening Playwright so the user can fix the gap before any browser opens.

- **An Atlassian Cloud account** the user can sign in to (free tier is fine).
- **At least one Jira and/or Confluence site** their account has access to. If the account has no site provisioned (fresh accounts, personal accounts that never joined a workspace, or org members who haven't been granted permissions), Phase 1 hits Atlassian's verbatim **"Access denied"** interstitial at stage 3: *"This app requires access to a Jira & Confluence & User identity site which you don't have or don't have the permission to access."* This is a permissions-side gap, not a SKILL bug — Phase 1 catches it in Step 4b2 and surfaces clean guidance, but you can avoid the round-trip by checking up front. Two paths to acquire site access:
  - **Self-serve** — create a free workspace at `https://www.atlassian.com` (≈2 minutes; pick Jira, Confluence, or both)
  - **Org-managed** — ask the Atlassian organization admin to add the user to a workspace with Jira or Confluence on it, or grant the user site permissions
- **Authority to install third-party apps** on the workspace, OR an Atlassian organization admin who has allowlisted the Atlassian Remote MCP. If the org has app-install restrictions enforced and the MCP isn't allowlisted, Phase 1 reaches an *"administrator approval required"* interstitial (Step 4b) and bails out — the admin needs to approve the app from the connected-apps area of `admin.atlassian.com` before Phase 1 can complete. There is **no API-token alternative** for the remote MCP.

### What this skill does NOT use

- **Atlassian API tokens.** The Atlassian Remote MCP server is OAuth-only on first connect; bearer-token / API-token access is not supported. Do not ask the user for an API token.
- **The legacy `/v1/sse` endpoint.** Atlassian's SSE endpoint sunsets **30 June 2026**. Always use the streamable endpoint at `https://mcp.atlassian.com/v1/mcp`.
- **A self-hosted Atlassian MCP server.** Atlassian publishes the hosted endpoint as the primary deployment.
- **Direct Jira / Confluence REST API calls.** All reads and writes go through the MCP server.
- **A custom OAuth client.** Claude Code's MCP runtime owns the OAuth dance; we do not register our own client, run our own callback listener, or store tokens manually.

### How auth works under the hood

Atlassian's hosted MCP is a **bridge / proxy OAuth server** (verified live 2026-04-30 against `mcp.atlassian.com/.well-known/oauth-authorization-server` AND empirically against the live flow on 2 different Atlassian accounts). The discovery document advertises `authorization_endpoint = https://mcp.atlassian.com/v1/authorize`, `token_endpoint = https://cf.mcp.atlassian.com/v1/token`, `registration_endpoint = https://cf.mcp.atlassian.com/v1/register`, S256 PKCE, and public-client `none` auth (issuer `cf.mcp.atlassian.com`). From the SKILL's perspective this is a standard OAuth 2.1 + PKCE flow at `mcp.atlassian.com` — Claude Code's MCP runtime drives it natively.

**The browser flow has THREE visible stages** (different from Canva's 2-stage rendering — important for the Phase 1 logic):

1. **Pre-login client-approval at `mcp.atlassian.com/v1/authorize`** — shows the third-party client's name + which Atlassian apps it wants (Jira / Confluence / Compass checkboxes) + Approve / Cancel. The bridge confirming the user wants to grant the third-party client access.
2. **Sign-in at `id.atlassian.com/login`** — Atlassian's central identity provider, after Approve. Skipped if the Playwright profile has Atlassian cookies.
3. **Final scope consent at `api.atlassian.com/oauth2/authorize/server/consent`** — Atlassian's central OAuth runs through using its OWN pre-registered MCP application (`pVrZtjGOkBrahLr0ge4iVlstqGVRJfi3`) and an EXPANDED scope set. The bridge encodes the third-party client's original `redirect_uri` inside its `state` parameter so it can return to it after this flow completes.

Practical implications surfaced in the SKILL:

- **Auto-click Approve on stage 1** is the canonical pattern — same shape as auto-Allow on the final consent of stage 3.
- **The user lands on Atlassian's central login first**, not on the third-party consent screen — Phase 1's branching reflects this.
- **Stage 3 has up to four converged outcomes**: workspace picker (multi-site), Allow button (single-site), administrator-approval-required interstitial (org-block), or "Access denied — site access required" (account has no Jira/Confluence site provisioning). The last two are distinct failure modes with distinct user-facing fixes.
- **Cloud only.** Atlassian Data Center / Server installations are not supported by the official remote MCP server.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to Atlassian in the Playwright window. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only action you ever request is "please sign in to the browser window I just opened, then pick which Atlassian workspace you want me to use."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, PKCE, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - workspace / site → **"your Atlassian workspace"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Atlassian for you now"), once when you need them ("please sign in and pick your workspace"), once when you're done ("your Atlassian is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your Atlassian is now connected." Bad: "Token exchange returned 200 OK."
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
const av = (j.mcpServers || {}).atlassian;
console.log(av ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 6 (verify) first. If it succeeds, the connector is already active — surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → run full Phase 1 from Step 1.

### 0.2 — Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest` (the `--` separator keeps Claude Code from consuming `npx` as an `add` flag), ask the user to close and reopen the chat, then retry.

---

## PHASE 1 — Install & Auth (5 numbered steps, autonomous via Playwright; Stage 3 has multi-state branching at 4a/4b/4b2/4c/4d)

### Step 1 — Orient the user + confirm prerequisites

Tell the user, in one short message:

> "I'll connect your Atlassian now — that covers Jira and Confluence. Quick check first: do you already have access to at least one Jira or Confluence workspace on your Atlassian account? If yes, say 'yes' and I'll open the connection page. If you've never used Jira or Confluence, or you're not sure, say 'not sure' and I'll walk you through creating a free workspace first — without one, the connection can't complete."

Branch on the user's reply:

- **"Yes" / "I have one" / equivalent** → continue to Step 2.
- **"Not sure" / "No" / "I've never used Jira"** → tell them: *"No problem — head to https://www.atlassian.com and create a free workspace (it'll ask you to pick Jira, Confluence, or both — pick whichever you'll use, or both, takes about two minutes). Once you can sign in to the new workspace, come back and say 'I have a workspace now' and we'll continue."* Wait for confirmation before proceeding to Step 2.
- **"My company manages it but I'm not sure I have access"** → tell them: *"In that case, let me try opening the connection — if your account has Jira or Confluence access, it'll work; if not, I'll tell you exactly what to ask your Atlassian admin for. Ready when you are."* Continue to Step 2 — Step 4b2 will catch the missing-site-access case cleanly if it comes up.

### Step 2 — Register the MCP server with `claude mcp add`

Silently register the hosted Atlassian MCP server in the user's config:

```bash
claude mcp add atlassian https://mcp.atlassian.com/v1/mcp --transport http --scope user
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
  j.mcpServers.atlassian = { type: "http", url: "https://mcp.atlassian.com/v1/mcp" };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

> **Do not write `https://mcp.atlassian.com/v1/sse`.** That endpoint sunsets 30 June 2026.

### Step 3 — Open Claude Code's OAuth start URL inside Playwright

When Claude Code's MCP runtime first contacts an unauthenticated hosted server, it emits an OAuth start URL for the user to visit. Capture that URL and open it inside the Playwright MCP browser instead of the user's default browser.

**How to obtain the OAuth start URL.** Claude Code 2.x does not publish a stable scriptable subcommand to mint the URL on demand — the supported way is to let the runtime emit it as part of the 401 challenge when an unauthenticated tool call is made. Two paths, in order of preference:

1. **401-challenge capture (primary).** Invoke any `mcp__atlassian__*` tool. Claude Code surfaces the OAuth start URL alongside the 401, in the form `https://mcp.atlassian.com/v1/authorize?...` (or, in some flows, on the `cf.mcp.atlassian.com` host). Capture the first matching URL from the surfacing.

2. **`claude mcp` subcommand (best-effort).** Some Claude Code builds expose an `authenticate` or equivalent subcommand. Probe with `claude mcp --help` and parse for an authenticate-style verb; if present, run it and capture stdout/stderr. If absent, fall back to path 1. Either way, the URL pattern to grep for is broad — Claude Code may emit either `mcp.atlassian.com` or `cf.mcp.atlassian.com`:

```bash
# Adjust the input source to whatever you have available (subcommand stderr, tool surfacing, etc.)
AUTH_URL=$(echo "$INPUT" | grep -oE 'https://(cf\.)?mcp\.atlassian\.com/[^[:space:]]+' | head -1)
echo "AUTH_URL=$AUTH_URL"
```

Then drive Playwright to that URL:

```
mcp__playwright__browser_navigate({ url: <AUTH_URL> })
```

Take a `mcp__playwright__browser_snapshot()`. Atlassian's flow has three visible stages — the page first lands on stage 1.

#### 3a — Stage 1: pre-login client-approval (`mcp.atlassian.com/v1/authorize`)

The page heading reads **"Atlassian Rovo MCP server"** with a subheading like "\<client_name\> is requesting access" and a paragraph "If you approve, you will be redirected to Atlassian to complete authentication." The Apps section shows **Jira / Confluence / Compass** checkboxes (Jira and Confluence checked by default; Compass off). Two buttons: **Approve** and **Cancel**.

Auto-click Approve (no user input — same shape as the final Allow click in Step 4):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^Approve$/i>,
  element: "Approve button on the Atlassian Rovo MCP pre-login consent screen"
})
```

After click, Atlassian redirects to stage 2.

#### 3b — Stage 2: sign-in (`id.atlassian.com/login`)

Snapshot. If the Playwright profile already has Atlassian cookies, this stage is skipped and the page lands directly on stage 3 — proceed to Step 4.

If not signed in, tell the user *once*: *"Please sign in to your Atlassian account in the browser window I just opened — I'll wait."* Then `mcp__playwright__browser_wait_for` polling for any of the four converged stage-3 markers:

- workspace-picker text (`"Choose a site"`)
- final consent text (`"is requesting access to"` / `"would like access"`)
- admin-approval interstitial text (`"administrator approval"` / `"admin approval required"` / `"awaiting approval"`)
- access-denied text (`"Access denied"` / `"This app requires access to a Jira"`)

Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

The user may complete sign-in via password, 2FA, SSO, or magic link — all paths converge to stage 3.

### Step 4 — Stage 3 multi-state branching (`api.atlassian.com/oauth2/authorize/server/consent`)

Stage 3 of the bridge flow lands on `api.atlassian.com/oauth2/authorize/server/consent` and renders one of four converged outcomes — workspace picker, Allow, admin-block, or Access-denied. Snapshot the page and branch on which outcome rendered. Run the failure-mode detections **before** the Allow click — both failure modes show *instead* of the Allow button, not after it.

#### 4a — Site picker (multi-site users)

If the snapshot shows a workspace/site picker (text like `"Choose a site"` or a combobox/select with `data-testid` containing `site` or `workspace`), extract the currently-selected workspace via `browser_evaluate`:

```javascript
() => {
  const sel = document.querySelector('[role="combobox"], select, [data-testid*="site" i], [data-testid*="workspace" i]');
  return sel ? (sel.textContent || sel.value || '').trim().slice(0, 80) : null;
}
```

Mention the workspace to the user before proceeding so they can object: *"Atlassian is asking which workspace to connect — looks like **\<workspace name\>** is selected. If that's right, I'll click Allow; if you want a different one, say so."* Wait for OK, then proceed to Step 4c.

If the user wants to switch later ("switch my Atlassian workspace"), re-run Phase 1 from Step 3 — Atlassian re-prompts the picker on a fresh consent flow.

#### 4b — Failure mode 1: organization-administrator-approval-required

If the snapshot shows phrasing like *"Your administrator must approve this app"*, *"This app requires admin consent"*, *"Site administrator approval required"*, or *"awaiting approval"*, this is a hard block — the user cannot proceed without their Atlassian organization admin approving the connector for the organization.

Detect via `browser_evaluate`:

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

If `true`, surface cleanly and exit:

> "Atlassian is telling me your organization administrator needs to approve this connection first. Your Atlassian admin can review and approve the connector for your organization in the connected-apps area of `admin.atlassian.com` (the exact label varies by org tier — usually under Settings → Connected apps or Products → Connected apps; the app appears under the name Atlassian uses for its hosted MCP). Once they've approved it, come back and say *'connect to my Atlassian'* and I'll finish setting up. There isn't an API-token alternative for this connector, so the admin step is the only way through."

Close the browser, do not retry — the block is org-policy. **Skip Step 5 (verify)** in this branch — there is nothing to verify until the admin approves.

#### 4b2 — Failure mode 2: account has no Jira/Confluence site access

Distinct from the admin-allowlist case — this is a user-side permissions gap, not an org-side restriction. Atlassian shows verbatim (captured live 2026-04-30):

> **Heading:** *"Access denied"*
> 
> **Body paragraph 1:** *"This app requires access to a Jira & Confluence & User identity site which you don't have or don't have the permission to access."*
> 
> **Body paragraph 2:** *"Visit http://www.atlassian.com to create a site."*
> 
> **Body paragraph 3:** *"Something's not right? Raise a support request."*

Common causes: signed-in account has never joined a workspace, personal account with no site, or org member not yet granted Jira/Confluence permissions on any site. The note quotes both apostrophes as Unicode `’` (U+2019) — the regex below uses `.` to match either ASCII or Unicode apostrophes.

Detect via `browser_evaluate`:

```javascript
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /access denied/i,
    /requires access to .* (jira|confluence|user identity site)/i,
    /you don.t have or don.t have the permission/i,
    /to create a site/i,
  ];
  return markers.filter(re => re.test(text)).length >= 2; // require ≥2 matches to avoid false positives
}
```

If `true`, surface cleanly and exit:

> "Atlassian is telling me your account doesn't have access to any Jira or Confluence site yet — that's a permissions thing on the Atlassian side, not a problem with the connection. To use this connector you need access to at least one Atlassian workspace with Jira or Confluence on it. Two ways to get there: (1) if you're new to Atlassian, you can create a free workspace at **https://www.atlassian.com** in about two minutes, or (2) if you should have access through your organisation, ask your Atlassian admin to add you to the workspace. Once that's sorted, come back and say *'connect to my Atlassian'* and I'll pick up from here."

Close the browser, do not retry — the user needs to acquire site access before continuing. **Skip Step 5 (verify)** — there is nothing to verify until the user has site access.

#### 4c — Read scope summary, narrate, click Allow

If neither failure-mode detection fired and you saw either the picker (4a, after the user OK'd) or a direct Allow screen (single-site account), extract the human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative scopes deduplicated):

> "Atlassian is showing the permissions screen — it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Accept` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|accept|authori[sz]e|grant access)/i>,
  element: "Allow button on the Atlassian consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically — please click **Allow** in the browser window."*

#### 4d — Auto-detect callback completion

Atlassian's bridge redirects to Claude Code's localhost callback (Claude Code's MCP runtime owns the listener). Wait for the redirect to complete via `browser_wait_for` on the post-redirect page text. The exact callback page text is not stable across Claude Code 2.x builds — poll for any of several plausible markers, and as a stronger signal also detect a URL change to `localhost`/`127.0.0.1` via a `browser_evaluate`:

```
mcp__playwright__browser_wait_for({
  text: "you can close this tab" OR "connection complete" OR "successfully authenticated" OR "authentication successful",
  time: 300
})
```

If the text wait does not match, run a follow-up `browser_evaluate` to check whether the URL has changed to a localhost callback — this is the more reliable signal that the OAuth bridge has handed back the code:

```javascript
() => /^https?:\/\/(localhost|127\.0\.0\.1)(:|\/)/.test(window.location.href)
```

If either succeeds, treat the callback as complete and proceed to Step 5. If neither succeeds within 5 minutes, check in *once* with the user. Do not nag.

### Step 5 — Close the browser + verify

Close Playwright:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection — let me check it works."*

Verify by calling a canonical Atlassian read-only smoke tool. Tool names aren't publicly documented and the set evolves — discover at runtime by listing the `mcp__atlassian__*` tools available in the current session and pick a safe read-only one (a "list accessible resources" / "list sites" / `getAccessibleAtlassianResources` shape, or a Jira issue search with no filters and a small `limit`). If it returns a result (including an empty list — that's fine), the connection works.

The verification depends on whether the MCP server is already active in the current session:

- **Tools available + call returns a result (or empty list)** → capture any obvious counts (resources, projects, issues), surface a success message including a live count.
- **Tools not yet available** (most likely on first setup, since the MCP config was just written and Claude Code hasn't reloaded the tool surface) → tell the user *"All saved. Please close and reopen the chat once, then say 'test my Atlassian' and I'll verify the new connection."*
- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403 with admin-block messaging** → re-run Step 5's interstitial detection and surface the admin-allowlist guidance.
- **Wrong workspace visible** → tell the user *"Looks like we connected to a different workspace than you meant — say 'switch my Atlassian workspace' and I'll re-run the sign-in so you can pick the right one."*

### Success message

Tell the user, in one short message (include any obvious live count if available — projects, sites, or issues assigned-to-currentUser):

> "All done! Your Atlassian is now connected — that covers your Jira and Confluence. You can ask me things like 'show me my Jira tickets', 'what's assigned to me this sprint?', 'create a Confluence page called Release Notes', or 'summarise the latest comments on PROJ-123'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__atlassian__*` MCP tools below to answer questions and make changes in Jira and Confluence. The hosted Atlassian Remote MCP server provides first-party tools covering Jira issues, search, projects, comments, transitions, and Confluence pages, spaces, and search — plus a smaller set of Compass tools for teams that use it.

> **Note on tool names:** Atlassian does not publish a stable public list of tool names, and the set evolves as the remote MCP server adds coverage. **Discover tool names at runtime** the first time you enter Phase 2 in a new session — list the `mcp__atlassian__*` tools available and map them to the categories below. The names in the tables below are the expected shape, not a guarantee.

### Tool Reference

#### Jira — Issues & search

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `search_issues` / `jira_search` | Search Jira issues using JQL or simple filters | User asks "show me my tickets", "open bugs in PROJ", "tickets assigned to me" |
| `get_issue` / `jira_get_issue` | Get full details of a specific Jira issue by key | User asks about a ticket by key (e.g. PROJ-123) |
| `create_issue` / `jira_create_issue` | Create a new Jira issue — **confirm first** | User asks to raise a bug, story, task |
| `update_issue` / `jira_update_issue` | Update fields on an existing issue — **confirm first** | User asks to change a ticket |
| `transition_issue` / `jira_transition_issue` | Move an issue through its workflow (e.g. To Do → In Progress → Done) — **confirm first** | User asks to move a ticket's status |
| `add_comment` / `jira_add_comment` | Add a comment to an issue — **confirm first** | User asks to comment on a ticket |

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
| `create_page` / `confluence_create_page` | Create a new Confluence page in a given space — **confirm first** | User asks to write a new doc |
| `update_page` / `confluence_update_page` | Update an existing page — **confirm first** | User asks to edit a page |

#### Confluence — Spaces

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `list_spaces` / `confluence_list_spaces` | List Confluence spaces in the connected workspace | User asks "what Confluence spaces do I have?" or you need a space key before creating a page |

#### Compass (optional — only if the workspace uses it)

Atlassian's Compass product (software component catalogue) exposes a small set of read-only tools for components and scorecards. Surface these only if the user's workspace has Compass enabled — otherwise these tools will return permission errors.

| Tool (expected shape) | Description | Use when |
|---|---|---|
| `compass_list_components` / `list_compass_components` | List Compass software components in the workspace | User asks "what services do we own?", "list our Compass components" |
| `compass_get_component` / `get_compass_component` | Get a single Compass component's metadata and scorecards | User asks about a specific service or component by name |

> **If a tool name in the tables above does not resolve**, list the available `mcp__atlassian__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess — list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Atlassian" / "Set up Jira" / "Set up Confluence" | **Run Phase 1** |
| "Switch my Atlassian workspace" | Re-run Phase 1 from Step 3 so the user can pick a different workspace on the Allow screen |
| "My Atlassian stopped working" / "I'm getting auth errors" | Run Phase 1 from Step 3 (Claude Code re-runs the OAuth dance) |
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

---

## Error Handling (Phase 2)

When an Atlassian tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Atlassian sign-in has expired — let me reconnect you." | Walk Phase 1 from Step 3 (Claude Code re-runs OAuth); retry the original tool call |
| 403 Forbidden | "Your Atlassian user doesn't have permission for that project or page. An admin or the page/project owner may need to share it with you." | User asks the owner to grant access; nothing to fix in the connector |
| 403 with admin-block messaging | "Your organization administrator has restricted this connection. They need to approve the connector in the connected-apps area of `admin.atlassian.com` — once they do, the sign-in will work for you and your team." | Atlassian organization admin approves the connector via Settings → Connected apps (or Products → Connected apps depending on org tier); there is no API-token fallback |
| 404 Not Found (issue / page / project / space) | "I couldn't find that record — let me search for it again." | Use `search_issues` / `search_pages` / `list_projects` / `list_spaces` to refresh |
| 422 Invalid request | "Atlassian rejected the request — usually a bad parameter. Let me check and try again." | Re-read with `get_issue` / `get_page` and reformat the call |
| 429 Rate limited | "Atlassian is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once |
| Wrong workspace connected | "Looks like we're pointed at a different Atlassian workspace than you meant. Let me switch you over." | Re-run Phase 1 from Step 3 so the user picks a different workspace on the Allow screen |
| MCP server not running | "The Atlassian connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| SSE endpoint used / 410 Gone on `/v1/sse` | "Your Atlassian connection is pointing at the old endpoint — let me update it." | Rewrite the `mcpServers.atlassian.url` in `~/.claude.json` to `https://mcp.atlassian.com/v1/mcp` and ask the user to restart |
| Any other API error | "Something went wrong with Atlassian — let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The Atlassian MCP connector **can** do (via the official Atlassian Remote MCP server):

- Search, read, create, update, comment on, and transition Jira issues
- List Jira projects and read project metadata
- Search Confluence pages and read page bodies
- Create and update Confluence pages
- List Confluence spaces
- Read Compass components and scorecards (if the workspace uses Compass)

The Atlassian MCP connector **cannot** do (needs the Atlassian UI or other tools):

- **Cloud only** — Data Center / Server installations are not supported by the official remote MCP server. Self-hosted Atlassian deployments need a different integration path.
- **Connect via API token** — Atlassian remote MCP is OAuth-only. No bearer-token fallback.
- Configure Jira workflows, custom fields, screen schemes, or permission schemes
- Manage Atlassian users, groups, or billing
- Run Jira automations or Forge app configurations
- Export issues or pages in bulk formats (CSV, PDF, Word) — use the Atlassian UI
- Manage multiple Atlassian workspaces in one session — one workspace per OAuth grant per `~/.claude.json` entry (use "switch my Atlassian workspace" to change)
- Access Atlassian products outside Jira / Confluence / Compass — Bitbucket, Trello, Statuspage, etc. are separate integrations
- **Bypass organization admin allowlisting** — if the admin blocks third-party app installs, the only option is for the admin to allowlist the Atlassian Remote MCP from `admin.atlassian.com`

---

## Organization-admin note — allowlisting can block first connect

On Atlassian organizations with app-install restrictions enforced, the workspace administrator can require admin review for third-party MCP apps. If this is enforced, the consent screen surfaces an "administrator approval required" interstitial (detected by Phase 1 Step 5).

1. There is **no API-token fallback for the Atlassian remote MCP** — OAuth is the only auth path supported by the hosted server.
2. The user's Atlassian organization admin needs to approve the connector in the connected-apps area of `admin.atlassian.com` — typically under Settings → Connected apps or Products → Connected apps depending on org tier. The app surfaces under whatever name Atlassian uses for its hosted MCP. That is a one-time setup on the admin's side. Once approved, other team members can connect normally.

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
- **Transitions depend on the workflow** — valid transitions vary per project. Fetch available transitions on the issue before calling `transition_issue`; if the target transition isn't valid, tell the user plainly instead of guessing.
- **Creating or updating pages is visible to the whole space** — Confluence updates notify watchers. For bulk edits, always show the user a sample of the first change before proceeding with the rest.
- **Never log or echo connection details** — never paste the contents of `~/.claude.json` to the user.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **canva-connector**: Sibling Playwright-driven autonomous connector — same shape, plus an Enterprise-allowlist branch
- **jotform-connector**: Sibling hosted OAuth-only MCP connector — identical install pattern, no API-key fallback
- **monday-connector**: Sibling project-management connector — similar conversational install
- **notion-connector**: Sibling docs / workspace connector — similar conversational install
- **n8n-workflow-patterns**: Build Jira- or Confluence-triggered automations once the connector is live
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Atlassian consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Atlassian auth or API errors
