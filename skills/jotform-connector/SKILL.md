---
name: jotform-connector
description: "Connect Jotform to Claude by switching on its built-in connector, or by registering Jotform's official server locally. Use when the user asks to set up or connect Jotform, or wants Jotform work (forms, submissions, form assignments) and Jotform isn't connected yet. Once connected, Jotform runs through the mcp__claude_ai_Jotform__* or mcp__jotform__* tools."
allowed-tools: mcp__claude_ai_Jotform__*, mcp__jotform__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Forms & Data Collection
  tags:
    - jotform
    - forms
    - submissions
    - intake
    - data-collection
    - mcp
  pairs-with:
    - skill: calendly-connector
      reason: Sibling hosted OAuth-only MCP connector - identical 6-step Playwright-driven install pattern.
    - skill: linear-connector
      reason: Sibling hosted OAuth-only MCP connector with DCR - canonical autonomous-install reference.
    - skill: monday-connector
      reason: Sibling Playwright-driven autonomous connector - reference for snapshot-and-reason model.
    - skill: slack-connector
      reason: Sibling Playwright-driven autonomous connector - reference for the autonomous-install rules.
    - skill: email-composer
      reason: Draft follow-ups based on Jotform submission data.
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Jotform submissions.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Jotform consent flow.
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Jotform auth or API errors.
---

# Jotform Connector

> **Install pattern:** Hosted-OAuth - see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (linear-connector).

## Overview

This skill lets you read and update a user's Jotform account on their behalf using the **official first-party Jotform MCP server** hosted at `https://mcp.jotform.com` (see [jotform/mcp-server](https://github.com/jotform/mcp-server)).

**There are two ways in, and they reach the same server.** Claude's own connector directory ships a built-in **Jotform** connector that points at that exact hosted endpoint, so its tool surface is identical to the kit's. Switching it on is one button and a sign-in, once per Claude account, with no local registration and no connection key on the machine - so it is the default route. The kit's own route (Phase 1-alt) stays in full for the cases the built-in cannot serve. Both can coexist on one machine; never tear one down to set the other up.

The skill has these phases:

- **Phase 0 - Is Jotform already connected?** Checks the built-in connector first, then the kit's own registration, and routes.
- **Phase 1 - Switch on the built-in Jotform connector (the default route).** Open Jotform's connector page in the user's own browser, they press **Connect to Claude** and sign in, then verify and prove with one read.
- **Phase 1-alt - The kit's own route (only when the built-in can't be used), autonomous, 6 steps.** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks Allow on the consent screen, auto-detects the callback via `browser_wait_for`, then verifies with a `mcp__jotform__list_forms` smoke call. The user's only manual moments are signing in to Jotform inside the Playwright window and clicking Allow on the consent screen. Token storage is handled by Claude Code's MCP runtime - there is no manual `~/.claude.json` token write.
- **Phase 2 - Use Tools.** Once Jotform is connected by either route, you call its native tools to read and update Jotform data - `mcp__claude_ai_Jotform__*` on the built-in route, `mcp__jotform__*` on the kit's.

**Which phase to run** - always start at Phase 0. On the kit's own route the resume signal is unchanged: read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.jotform` entry. If present, attempt a verification tool call (Phase 1-alt Step 6). If it succeeds, the connector is ready - skip to Phase 2. If it 401s, walk Phase 1-alt from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **Jotform API keys or personal access tokens.** Jotform MCP **requires OAuth for every user on first connect**. Bearer-token / API-key access to the MCP server is not supported. Do not ask the user for any key.
- **A self-hosted Jotform MCP server.** Jotform publishes the hosted endpoint at `https://mcp.jotform.com` as the primary deployment. Always use the hosted URL.
- **Direct Jotform REST API calls.** All reads and writes go through the MCP server, not direct HTTP calls to the Jotform Public API.
- **A custom OAuth client (custom PKCE, loopback listener).** Claude Code's MCP runtime owns the OAuth dance natively; we do not register our own client, run our own callback listener, or store OAuth tokens manually. The skill's job is to choreograph Playwright + Claude Code's native OAuth handler - not to replicate OAuth.

### How auth works under the hood

The Jotform MCP server is a hosted OAuth 2.1 server. The transport endpoint at `https://mcp.jotform.com` returns a `401` for unauthenticated calls and publishes its OAuth metadata via the standard `/.well-known/oauth-protected-resource` and `/.well-known/oauth-authorization-server` documents (resource = `mcp.jotform.com`, authorization server = `oauth2.jotform.com`). Claude Code's MCP runtime fetches those documents on first contact, then performs PKCE against the auth server and handles the token exchange natively. From the SKILL's perspective this is a standard OAuth 2.1 + PKCE flow - Claude Code drives it natively. The skill only opens the start URL inside Playwright, auto-clicks Allow, and waits for the callback.

---

## Communication rules for Phase 1 and Phase 1-alt

These rules apply to **both** connect routes. On Phase 1 (the built-in connector) the user presses one button in their own browser and signs in; on Phase 1-alt the browser window is one Claude drives. Either way the user is a non-technical business owner - Claude does the work, the user only signs in and clicks Allow. Every message you send while connecting must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and "please click Allow on the screen Jotform just showed you."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, PKCE, scope, token, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - close and reopen Claude Code → **"close and reopen the chat"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Jotform for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Jotform is now connected"). No commentary in between snapshots, clicks, or evaluates.
- **React to success and failure warmly.** Good: "That worked - your Jotform is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message while connecting (Phase 1 or Phase 1-alt).
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0 - Is Jotform already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** Run `claude mcp list` and look for a line starting `claude.ai Jotform` (match the vendor word case-insensitively; there is no `--json` flag).
   - `✔ Connected` → skip to **Phase 2**. Prove it first with one read through the built-in - list the account's forms - before saying so.
   - `! Needs authentication` → the connection is on the account but its sign-in has lapsed. Open `https://claude.ai/customize/connectors` in the user's own browser and say: *"Your Jotform connection needs a quick re-sign-in. Press **Reconnect** next to Jotform, sign in, and tell me when it says Connected."* Then re-run this check.
   - No such line → continue to step 2.
2. **The kit's own route.** Run the resume check below. If an `mcpServers.jotform` entry is present and a smoke call works, keep using it - say *"Jotform is already connected"* and skip to **Phase 2**. Do not set the built-in up on top of a working connection.
3. **Nothing found** → go to **Phase 1**.

**Precedence note.** A server registered locally at the same address takes precedence over the built-in one and hides it (`/mcp` shows the built-in as hidden). If a machine carries an `mcpServers.jotform` entry from an earlier run of the kit's route and it works, leave it and say so. Only remove it - and only with the user's explicit OK - if it is broken and the built-in is the better route.

**No shell?** If you cannot run commands at all (this is claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2 entirely: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Jotform's tools.

### 0.1 - Resume check (the kit's own route)

Read `~/.claude.json` via Node (cross-platform safe - Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const jf = (j.mcpServers || {}).jotform;
console.log(jf ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1-alt Step 6 (verify) first. If it succeeds, the connector is already active - surface a friendly message and stop. If 401, walk Phase 1-alt from Step 3.
- `NOT_CONFIGURED` → nothing of the kit's is in place; go to Phase 1.

### 0.2 - Tooling check (silent, needed for Phase 1-alt)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the setup prompt in `docs/start/setup.md` (its Step 6 installs the Claude CLI). If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest` (the `--` separator keeps Claude Code from consuming `npx` as an `add` flag), ask the user to close and reopen the chat, then retry.

---

## Phase 1 - Switch on the built-in Jotform connector (the default route)

Claude's connector directory carries a **Jotform** connector that points at the same hosted endpoint the kit registers (`https://mcp.jotform.com`), so the tool surface is identical. This is a one-time, once-per-account job: connect it once on the user's Claude account and it is available everywhere that account is signed in, including here. The only thing the user does is press one button and sign in. Nothing on this route captures, stores, or echoes a connection key - there is no key.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set in the environment, built-in connectors will not appear in this session. Tell the user in one line that this copy of Claude is signed in a different way, then run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.** Say:

> "I'm opening Jotform's page in your browser. Press **Connect to Claude**, sign in to Jotform the way you normally do, and say yes when it asks for access. That's the only part only you can do - tell me when it says Connected."

Then open `https://claude.ai/directory/jotform` (the public mirror of the same page is `https://claude.com/connectors/jotform`) in the user's **own** everyday browser: `open <url>` on Mac, `xdg-open <url>` on Linux, `start "" <url>` on Windows. That is where they are already signed in. If the page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: **Browse**, search "Jotform", **Connect**.

> **Why the user's own browser here.** Phase 1-alt's rule - never use the user's own browser - exists because that route drives a sign-in in a browser Claude controls. This route reads nothing and handles no key, so the user's own browser is the correct place for the button press. Do not drive this sign-in with the automated browser.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a picture of the sign-in screen.

**Step 4 - Verify.** Run `claude mcp list` again. A line reading `claude.ai Jotform ... ✔ Connected` is the pass.
- Not there yet → no restart will change this answer: `claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes. Read on:
- `! Needs authentication` → send them to `https://claude.ai/customize/connectors` and have them press **Reconnect** next to Jotform.
- Still no line at all → the Connect didn't complete; send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - list the account's forms. Only a real answer counts (an empty list is a real answer; a tool error is not "connected"). The built-in's tools are often deferred in a session, so list the `mcp__claude_ai_Jotform__*` tools actually available and pick a safe read rather than hard-coding a name. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - for example *"show me my forms"*, *"how many people filled in the contact form this week?"*, *"summarise last month's submissions"*.

**Team or Enterprise accounts.** If the page shows **Request** instead of **Connect**, the user's Claude administrator has to switch Jotform on for the organisation first, and connectors only work in private projects there. Say so plainly and stop. Do not fall back to the kit's route just to get past an admin gate.

**Plan note.** Assume a paid Claude plan for built-in connectors. Free accounts are limited to a single custom connector, which is not this route.

---

## Phase 1-alt - The kit's own route (only when the built-in can't be used)

Run this **instead of** Phase 1 in exactly three cases:

- Phase 1 Step 1 failed - this copy of Claude is signed in a way that cannot see built-in connectors.
- The Jotform connector is not listed on the user's Claude account (no directory listing, and nothing under **Browse**).
- The user explicitly asks for the locally registered server.

Otherwise Phase 1 is the route: it reaches the same server with none of this setup, and there is no reason to burden the user with it. Both routes can live on one machine - never tear one down to set the other up.

Everything below is the kit's original install: 6 steps, autonomous via Playwright.

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your Jotform now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 - Register the MCP server with `claude mcp add`

Silently register the hosted Jotform MCP server in the user's config:

```bash
claude mcp add jotform https://mcp.jotform.com --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output) - write the entry directly to `~/.claude.json` via the Node merge pattern. The rename is inside Node so the swap is atomic on every platform (Mac / Linux / Windows Git Bash) and does not run if the JSON write fails:

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
  j.mcpServers.jotform = { type: "http", url: "https://mcp.jotform.com" };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 3 - Acquire OAuth start URL via `mcp__jotform__authenticate` and open it in Playwright

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__jotform__authenticate()` - no args, returns the OAuth authorization URL.
- `mcp__jotform__complete_authentication({ callback_url })` - submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path - not a `claude mcp` CLI subcommand.

**Tool-availability precondition.** On the very first session after `claude mcp add jotform ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__jotform__authenticate` may not be in the tool surface. If that's the case, ask the user *once*: *"I've added Jotform. Please close and reopen the chat once, then say 'connect to my Jotform' and I'll finish."* On resume, Phase 0's resume check sees the `mcpServers.jotform` entry and routes back into Step 3 of this flow.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__jotform__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in + consent UI visible** (you see Jotform's app-permission screen with an Allow / Authorize button and the Claude Code app name) → continue to Step 4.
- **Not logged in** (Jotform sign-in form, "Continue with Google", "Continue with Apple", SSO redirect) → tell the user, *once*: *"Please sign in to your Jotform account in the browser window I just opened. On the next screen you'll see an **Allow** button - click it once you're there."* Then `mcp__playwright__browser_wait_for` polling for consent text (`"would like access"` / `"requesting access"` / `"Allow"` / `"Authorize"`). Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*
- **Wrong account signed in** (the user has multiple Jotform accounts and the session is on the wrong one) → tell them: *"Looks like you're signed in to a different Jotform account than you meant. Please sign out and sign back in with the right account, then I'll continue."*

### Step 4 - Auto-click Allow + auto-detect callback

#### 4a - Narrate, click Allow

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

> "Jotform is showing the permissions screen - it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Accept` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|accept|authori[sz]e|grant access)/i>,
  element: "Allow button on the Jotform consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically - please click **Allow** in the browser window."*

#### 4b - Capture callback URL + submit via `complete_authentication`

Jotform redirects to Claude Code's localhost callback (`http://localhost:<port>/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid - that's what `complete_authentication` needs.

Wait for the redirect via a URL-pattern wait, then capture the full `window.location.href` **before** closing the browser (after close there is no page to read):

```
mcp__playwright__browser_wait_for({
  // Wait until URL changes to the localhost callback. Use a JS-evaluate poll
  // since browser_wait_for's `text` matcher targets DOM text, not the URL.
  // Generous timeout - the user may take a minute on the consent screen.
  time: 300
})

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
```

If `callback_url` does not look like a `localhost`/`127.0.0.1` callback (the user may still be mid-flow), poll once more with a short wait. If after 5 minutes there is still no callback, check in *once* with the user. Do not nag.

Then submit the callback to Claude Code's MCP runtime to finish the OAuth dance:

```
mcp__jotform__complete_authentication({ callback_url })
```

On success, the rest of the `mcp__jotform__*` tools become available **in the same session** - no chat restart needed. Proceed to Step 6 for verification.

**Failure handling.** If `complete_authentication` rejects the callback (state mismatch, expired code, malformed URL), surface a plain-English *"let me try once more"* and re-run from `mcp__jotform__authenticate()`.

If the user clicks **Cancel** or **Deny** instead of **Allow**, Jotform redirects back without a code. Tell them: *"Looks like you declined the permission - no problem. Want me to try again?"* If yes, re-mint via `mcp__jotform__authenticate()` and re-run Step 4.

### Step 5 - Detect plan/admin restriction interstitial (rare)

Some Jotform accounts (Enterprise tenants with admin-managed integration policies, suspended seats, or trial accounts with restricted features) may render an interstitial after the Allow click that blocks the connection rather than redirecting to the callback. This is distinct from a normal consent flow - the Allow button completes but Jotform shows an "approval required" / "plan does not include" page instead of redirecting.

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
    /your (jotform )?plan does not (include|allow)/i,
    /upgrade .* plan/i,
  ];
  return markers.some(re => re.test(text));
}
```

If the function returns `true`, surface cleanly and exit:

> "Jotform is telling me your account or workspace administrator needs to allow this connection first. Once that's sorted, come back and say *'connect to my Jotform'* and I'll finish setting up."

If the function returns `false`, the consent flow completed normally - proceed to Step 6.

### Step 6 - Close the browser + verify

Close Playwright (if not already closed):

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection - let me check it works."*

Verify by calling `mcp__jotform__list_forms` with a small page size (e.g. 1 form). If it returns a result (including an empty list - that's fine), the connection works.

Because `complete_authentication` unblocks the rest of the `mcp__jotform__*` surface in the same session, the smoke call should run immediately:

- **Call returns a list** → capture the form count, surface a success message including the count if non-zero ("I can see N forms in your account").
- **Call returns 401 / `invalid_token`** → walk Phase 1-alt from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403** → "Your connection is working, but your Jotform account doesn't have permission for that action - your plan or role may not include it." Stop here.
- **`429 Rate limited`** → "Jotform is asking me to slow down - let me wait a moment and try again." Wait 10 seconds, retry once.

### Success message

Tell the user, in one short message (include the live count from the smoke call if available):

> "All done! Your Jotform is now connected. You can ask me things like 'show me my forms', 'how many submissions did the contact form get this week?', or 'create a new feedback form'. Give it a try!"

---

## PHASE 2 - Use Tools

Once the connector is configured, use Jotform's MCP tools below to answer questions and make changes in Jotform. The hosted Jotform MCP server provides **6 first-party tools** covering forms, submissions, and assignments.

> **Which prefix you get.** Through the built-in connector (Phase 1) the tools are `mcp__claude_ai_Jotform__*`; through the kit's own route (Phase 1-alt) they are `mcp__jotform__*`. Both routes reach the same hosted Jotform server, so the tool names after the prefix are the same - only the prefix differs, and the tables below apply to both. List the tools present in the session and use the prefix that is actually there; never mix the two prefixes in one session.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__jotform__`. Verified against [jotform/mcp-server](https://github.com/jotform/mcp-server).

#### Forms

| Tool | Description | Use when |
|---|---|---|
| `list_forms` | Retrieve all forms in the user's Jotform account | User asks "show me my forms", or you need a form ID before another call |
| `create_form` | Build a new form | User asks to create an intake/feedback/registration form - **confirm first** |
| `edit_form` | Modify an existing form (fields, settings, title) | User asks to change a form - **confirm first** |
| `assign_form` | Delegate (assign) a form to another user | User asks to share a form with a teammate - **confirm first** |

#### Submissions

| Tool | Description | Use when |
|---|---|---|
| `get_submissions` | Fetch submissions (entries) for a form | User asks "how many people filled out X", "show me the latest responses", or wants to read entries |
| `create_submission` | Add an entry to a form programmatically | User asks to log a response on behalf of someone, e.g. importing data - **confirm first** |

> **If a tool name in the table above does not resolve**, list the available `mcp__jotform__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess - list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Jotform" / "Help me set up Jotform" | **Run Phase 0, then Phase 1** (Phase 1-alt only if Phase 1 is unavailable) |
| "My Jotform stopped working" / "I'm getting auth errors" | Re-run Phase 0. Built-in route: `! Needs authentication` means **Reconnect** at `https://claude.ai/customize/connectors`. Kit's route: walk Phase 1-alt from Step 3 (Claude Code re-runs the OAuth dance) |
| "Show me my forms" | `list_forms` |
| "How many submissions did the contact form get this week?" | `list_forms` (find form ID) → `get_submissions` (filter by date) |
| "Show me the latest 10 responses on the feedback form" | `list_forms` → `get_submissions` (limit 10) |
| "Create a new feedback form" | `create_form` - **confirm first, summarise fields before creating** |
| "Add a phone number field to my contact form" | `list_forms` → `edit_form` - **confirm first** |
| "Rename the 'Q1 survey' form to 'Q2 survey'" | `list_forms` → `edit_form` - **confirm first** |
| "Share my intake form with Jane" | `list_forms` → `assign_form` - **confirm first** |
| "Log a test entry on my contact form" | `list_forms` → `create_submission` - **confirm first** |
| "Import these 50 leads into my Jotform" | `list_forms` → loop `create_submission` - **confirm first, in batches** |

---

## Error Handling (Phase 2)

When a Jotform tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Jotform sign-in has expired - let me reconnect you." | Built-in route: press **Reconnect** at `https://claude.ai/customize/connectors`. Kit's route: walk Phase 1-alt from Step 3; Claude Code re-runs OAuth |
| 403 Forbidden | "Your Jotform user doesn't have permission for that form. The form owner may need to share it with you." | User talks to the form owner; nothing to fix in the connector |
| 404 Not Found (form / submission) | "I couldn't find that record - let me list your forms again." | Use `list_forms` to refresh the list |
| 429 Rate limited | "Jotform is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. Free tier is 60 requests/minute; Enterprise is 600/min. |
| 400 Invalid request | "The details I tried to send didn't match what Jotform expected - let me try again." | Re-fetch the form ID, retry once |
| MCP server not running | "The Jotform connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Any other API error | "Something went wrong with Jotform - let me try again." | Retry once; if still failing, re-run Phase 0 and reconnect by whichever route is in use |

---

## Scope Limitations

The Jotform MCP connector **can** do (via the official Jotform MCP server):
- List all forms in the user's account
- Create, edit, and assign forms
- Read form submissions (entries)
- Create new submissions programmatically (e.g. importing leads)

The Jotform MCP connector **cannot** do (needs the Jotform UI or other tools):
- Build complex visual form layouts beyond what `create_form` / `edit_form` expose
- Configure payment integrations (Stripe, PayPal, Square)
- Manage account-level billing or user permissions
- Export submissions in PDF / Excel format (use the Jotform UI or REST API directly)
- Configure form triggers / conditional logic beyond what `edit_form` supports
- Manage multiple Jotform accounts simultaneously (one OAuth session per `~/.claude.json` entry)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, editing, assigning, or submitting** - summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover form IDs before writing** - Jotform forms are referenced by numeric IDs. Always call `list_forms` once per session before any `edit_form`, `assign_form`, `get_submissions`, or `create_submission`, unless you already have the ID from earlier in the conversation.
- **IDs are numeric strings** - form and submission IDs are long numeric strings. Always confirm them back via the form's title rather than the raw ID.
- **Submissions are sensitive data** - they often contain personal information (names, emails, phone numbers, free-text feedback). Never paste full submission contents into a public log or chat without checking with the user first. When summarising, prefer counts and aggregates over raw quotes unless asked.
- **Present data clearly** - format results as readable tables or summaries, not raw JSON.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 12 forms; the busiest is 'Contact Us' with 142 submissions this month"), then offer to show details.
- **Pagination** - default to 25 submissions unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** - Free tier is 60 requests/minute; Enterprise is 600/min. For bulk imports, batch `create_submission` calls and pause between batches.
- **Importing leads is irreversible** - `create_submission` writes a real entry. For bulk imports, always show the user a sample of the first row before proceeding with the rest.
- **Never log or echo credentials** - there is no token to leak (OAuth is handled by Claude Code), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap; Phase 1 and Phase 1-alt above follow the same rules
- **calendly-connector**: Sibling hosted OAuth-only MCP connector - identical 6-step Playwright-driven install pattern
- **linear-connector**: Sibling hosted OAuth-only MCP connector with DCR - canonical autonomous-install reference
- **monday-connector**: Sibling Playwright-driven autonomous connector - reference for snapshot-and-reason model
- **slack-connector**: Sibling Playwright-driven autonomous connector - reference for autonomous-install rules
- **email-composer**: Draft follow-ups based on Jotform submission data
- **n8n-workflow-patterns**: Build Jotform-triggered automations once the connector is live
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Jotform consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Jotform auth or API errors
