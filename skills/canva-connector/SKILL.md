---
name: canva-connector
description: "Connect Canva to Claude by switching on its built-in connector, or by installing and authenticating its official MCP server. Use when the user asks to set up or connect Canva, or wants Canva work (designs, exports, AI generation, comments, folders, brand kits) and Canva isn't connected yet. Once connected, Canva runs through the mcp__claude_ai_Canva__* or mcp__canva__* tools."
allowed-tools: mcp__claude_ai_Canva__*, mcp__canva__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - canva
    - design
    - export
    - presentations
    - ai-design
    - brand-templates
    - mcp
  pairs-with:
    - skill: airtable-connector
      reason: Pair structured data (Airtable rows) with Canva designs - generate one design per row
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector - identical install pattern
    - skill: ad-creative
      reason: Generate ad copy variations then render them as Canva designs
    - skill: social-content
      reason: Turn social posts into Canva-ready visuals and resize for each platform
    - skill: atlassian-connector
      reason: Same Playwright-driven autonomous Phase 1 pattern (no Enterprise allowlist branch)
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Canva consent flow
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Canva auth or API errors
---

# Canva Connector

> **Install pattern:** Hosted-OAuth - see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (linear-connector).

## Overview

This skill lets you read and update a user's Canva account on their behalf. Both routes below reach the same **official first-party Canva MCP server** hosted at `https://mcp.canva.com/mcp` - the difference is who does the wiring.

- **Phase 1 - the built-in Canva connector (the default route).** Canva is in Claude's own connector directory, so the server is already wired up: the user presses one button, signs in, and Canva is available on their account everywhere - claude.ai, the desktop app, and Claude Code - with nothing registered on their computer. It is the same server and the same tool surface, so **there is nothing the kit's route can do that this route cannot**, and the directory entry additionally ships three ready-made Canva skills (Branded Presentation, Design Translation, Social Media Resize). Two plan caveats: the built-in connector needs a **paid Claude plan**, and brand-kit features still need a **paid Canva plan** whichever route connects. Tools arrive as `mcp__claude_ai_Canva__*`.
- **Phase 1-alt - the kit's own route (autonomous, 6 steps).** Kept in full below. Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks Allow on the consent screen, auto-detects the callback via `browser_wait_for`, surfaces the Enterprise administrator-approval-required interstitial cleanly when present. The user's only manual moment is signing in to Canva inside the Playwright window. Token storage is handled by Claude Code's MCP runtime - there is no manual `~/.claude.json` token write. Use it only in the cases listed at the head of Phase 1-alt.
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__canva__*` native tools to read and update Canva data. The hosted Canva MCP server provides **37 first-party tools** across 11 categories covering designs (read, generate, duplicate, merge, shortlink-resolution), assets, folders, comments, exports, AI generation, a transactional editing flow, brand templates and kits, and help-answers. **Drift caveat**: 3 of those tools (`search-brand-templates`, `get-brand-template-dataset`, `autofill-design`) are Enterprise-plan-gated and only surface in the tool list for Enterprise users; the other 34 are available across plans.

Both routes can sit on the same machine. Never tear one down to set the other up.

**Which phase to run** - run Phase 0 below before any tool call. It checks the built-in connector first and the kit's registration second, and routes from whichever answers.

### What this skill does NOT use

- **Canva API keys or personal access tokens.** Canva MCP is OAuth-only; there is no Bearer-token / API-key path. Do not ask the user for an API key.
- **A self-hosted or community Canva MCP server.** Canva publishes the hosted endpoint at `https://mcp.canva.com/mcp` as the official first-party deployment.
- **Direct Canva REST API calls (Canva Connect API).** All reads and writes go through the MCP server.
- **A custom OAuth client.** Claude Code's MCP runtime owns the OAuth dance; we do not register our own client, run our own callback listener, or store tokens manually.

### How auth works under the hood

Canva's hosted MCP is a **bridge / proxy OAuth server** (verified empirically 2026-04-30): `mcp.canva.com/authorize` redirects users through Canva's central OAuth (`canva.com/api/oauth/authorize`) using Canva's pre-registered MCP application, then on a successful Allow it issues its own authorization code back to the registered client's redirect URI with the original PKCE/state preserved. From the SKILL's perspective this is a standard OAuth 2.1 + PKCE flow at `mcp.canva.com` - Claude Code's MCP runtime drives it natively.

Two practical implications:

- **The consent screen shows ~15 permissions** (the full set Canva's pre-registered MCP app declares: `profile:read`, `design:meta:read`, `design:content:read`, `design:content:write`, `folder:read`, `folder:write`, `brandtemplate:content:read`, `brandtemplate:meta:read`, `comment:read`, `comment:write`, `asset:read`, `asset:write`, `brandkit:read`, `help:answers:read`, `help:answers:write`). The bearer Canva mints back is **re-scoped down to what Claude Code's MCP runtime actually requested** - typically a subset suited to the active toolset. The user sees the worst-case set on the consent screen; the working set is narrower.
- **Enterprise admin allowlisting is the only hard block.** If the user's Canva Enterprise admin has restricted third-party app installs, the consent flow surfaces an "administrator approval required" interstitial instead of completing. There is no API-key fallback.

---

## Communication rules for connecting Canva (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Connecting is autonomous - Claude does the work; the user presses one button and signs in to Canva once. Every message you send while connecting must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are "please press Connect to Claude on the page I just opened" and "please sign in to the browser window I just opened."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, PKCE, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page" - not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Canva for you now"), once when you need them ("please sign in"), once when you're done ("your Canva is now connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your Canva is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0 - Is Canva already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Canva` (match the vendor word case-insensitively; there is no `--json` flag). Captured 2026-06-05, it shows as `claude.ai Canva: https://mcp.canva.com/mcp - ✓ Connected`. Note this layer does NOT write into `~/.claude.json` `mcpServers`, so `claude mcp list` is the only place it shows.

   ```bash
   claude mcp list 2>/dev/null | grep -iE 'canva.*Connected' >/dev/null && echo CLAUDE_AI_LAYER_REGISTERED
   ```

   - `✔ Connected` → skip to Phase 2. Prove it first with one read from the `mcp__claude_ai_Canva__*` namespace - the design-search tool with an empty query is the standard probe (it is `search-designs` on the kit's route). Only a real answer counts; an empty design list is still a pass. Remember every Canva tool requires a `user_intent` string on both routes.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` for the user and say: *"Your Canva connection needs a quick re-sign-in. Press Reconnect next to Canva, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Read `~/.claude.json` via Node (cross-platform safe - Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile) and look for an `mcpServers.canva` entry:

   ```bash
   node -e "
   const fs = require('fs');
   const path = require('path');
   const p = path.join(require('os').homedir(), '.claude.json');
   if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
   const j = JSON.parse(fs.readFileSync(p, 'utf8'));
   const cv = (j.mcpServers || {}).canva;
   console.log(cv ? 'REGISTERED' : 'NOT_CONFIGURED');
   "
   ```

   - `REGISTERED` → try the Phase 1-alt Step 6 verify call first. If it succeeds, the connector is already active - say *"Canva is already connected"* and skip to Phase 2. Do not set the built-in up on top of a working connection. If it 401s, walk Phase 1-alt from Step 3 to re-trigger the sign-in (the registration is already in place).
   - `NOT_CONFIGURED` → continue.
3. **Nothing found** → Phase 1.

A locally-registered Canva entry at the same address as the built-in one takes precedence and hides the built-in. If it works, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the user's OK.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Canva's tools.

---

## Phase 1 - Switch on the built-in Canva connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in.

> **Plan notes.** The built-in Canva connector needs a **paid Claude plan**. Canva-side plan gating is unchanged by the route: brand kits need a paid Canva plan to hold anything, `resize-design` needs Canva Pro or above, and brand templates plus autofill need Canva Enterprise.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route (Phase 1-alt) instead.

**Step 2 - Open the connector page for them.** Say:

> "I'm opening Canva's page in your browser. Press **Connect to Claude**, sign in to Canva the way you normally do, and say yes when it asks for access. That's the only part only you can do - tell me when it says Connected."

Then open `https://claude.ai/directory/canva` in the user's own everyday browser - `open <url>` on Mac, `xdg-open <url>` on Linux, `start "" <url>` on Windows. If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Canva" → Connect.

> **Why the user's own browser here, when Phase 1-alt uses its own window.** Phase 1-alt drives a separate browser window because it has to read the redirect back out of the page. This route reads nothing - it only needs the browser where the user is already signed in to Claude. Send them to their own browser and do not automate this sign-in.
>
> Canva's consent screen still lists ~15 permissions on this route - the full set Canva's pre-registered app declares. The connection key Canva actually issues is re-scoped down to what is needed. Tell the user that once, plainly, if they ask why the list is long.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Canva … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete, so send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector: the design-search tool from the `mcp__claude_ai_Canva__*` namespace with an empty query and a one-sentence `user_intent`. Only a real answer counts - an empty design list is a pass, a tool error is not. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app, connectors added during a session are documented to appear without a restart; if one doesn't, start a new session there.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - for example *"show me my latest designs"*, *"export my pitch deck as a PDF"*, *"generate a social post about our launch"*. Mention the three ready-made Canva skills the directory entry ships (Branded Presentation, Design Translation, Social Media Resize) only if the user asks for that kind of work.

**Canva Enterprise workspaces** can still block the sign-in on Canva's side - see the Enterprise note near the end of this skill, and Phase 1-alt Step 5 for how the block presents. It applies to both routes and there is no key-based way around it.

**Team or Enterprise Claude accounts:** if the page shows **Request** instead of **Connect**, their Claude administrator has to switch Canva on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## Phase 1-alt - The kit's own route (only when the built-in can't be used)

Run this instead of Phase 1 when one of these is true, and say which one in a single plain-English line:

- Step 1 of Phase 1 failed - this copy of Claude is signed in a different way and built-in connectors will not appear.
- The user is on a free Claude plan, or the Canva listing is missing from their connector settings, or their organisation shows **Request** and they want to keep moving on their own account.
- The user explicitly wants the connection registered on their own computer rather than on their Claude account.

Outside those cases there is no capability reason to prefer this route: it is the same Canva server with the same 37 tools. Everything below is this route, kept unchanged. Step references elsewhere in this skill ("walk Phase 1 from Step 3", "Phase 1 Step 6") point at the numbered steps in this route.

### Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the setup prompt in `docs/start/setup.md` (its Step 6 installs the Claude CLI). If Playwright MCP is missing, install autonomously with `claude mcp add playwright npx @playwright/mcp@latest --scope user`, ask the user to close and reopen the chat, then retry.

---

## PHASE 1-alt - Install & Auth (6 steps, autonomous via Playwright)

### Step 1 - Orient the user

Tell the user, in one short message:

> "I'll connect your Canva now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 - Register the MCP server with `claude mcp add`

Silently register the hosted Canva MCP server in the user's config:

```bash
claude mcp add canva https://mcp.canva.com/mcp --transport http --scope user
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
  j.mcpServers.canva = { type: "http", url: "https://mcp.canva.com/mcp" };
  fs.writeFileSync(cfg + ".tmp", JSON.stringify(j, null, 2));
'
mv ~/.claude.json.tmp ~/.claude.json
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 3 - Acquire OAuth start URL via `mcp__canva__authenticate` and open it in Playwright

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__canva__authenticate()` - no args, returns the OAuth authorization URL (Canva-shaped: `https://mcp.canva.com/authorize?...`).
- `mcp__canva__complete_authentication({ callback_url })` - submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path - **not** a `claude mcp` CLI subcommand. Earlier versions of this SKILL invoked a non-existent `authenticate` verb on the `claude mcp` CLI; no such subcommand ships in any Claude Code build.

**Tool-availability precondition.** On the very first session after `claude mcp add canva ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__canva__authenticate` may not be in the tool surface. If that's the case, ask the user *once*: *"I've added Canva. Please close and reopen the chat once, then say 'connect to my Canva' and I'll finish."* On resume, Phase 0's resume check sees the `mcpServers.canva` entry and routes back into Step 3 of this flow.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__canva__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in** (you see Canva's consent UI - "Canva AI Connector would like access to your Canva account" with a permissions list and Allow / Cancel buttons) → continue to Step 4.
- **Not logged in** (Canva sign-in form, email/password fields, or SSO redirect) → tell the user, *once*: *"Please sign in to your Canva account in the browser window I just opened - I'll wait."* Then `mcp__playwright__browser_wait_for` polling for the consent text (`"would like access"`) or the admin interstitial text (`"administrator approval required"`). Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*

> **Note on the consent screen surprise:** Canva's consent screen lists ~15 permissions (the full set Canva's pre-registered MCP app declares - `profile:read`, `design:meta:read`, `design:content:read/write`, `folder:read/write`, `brandtemplate:*`, `comment:read/write`, `asset:read/write`, `brandkit:read`, `help:answers:read/write`). The connection key Canva ultimately issues is re-scoped down to what Claude Code actually needs. The user is granting the worst-case set; the working set is narrower.

### Step 4 - Auto-click Allow + auto-detect callback

#### 4a - Read scope summary, narrate, click Allow

Snapshot the consent page. Extract the human-readable scope items via `browser_evaluate`:

```javascript
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Tell the user, in one short message (3-5 representative items, deduplicated):

> "Canva is showing the permissions screen - it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|authori[sz]e|grant access)/i>,
  element: "Allow button on the Canva consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically - please click **Allow** in the browser window."*

#### 4b - Capture callback URL + submit via `complete_authentication`

Canva redirects to Claude Code's localhost callback (`http://localhost:<port>/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid - that's what `complete_authentication` needs.

Wait for the redirect via a URL-pattern wait, then capture the full `window.location.href` **before** closing the browser (after close there is no page to read):

```
mcp__playwright__browser_wait_for({
  // Generous timeout - the long Canva permissions list can take a minute.
  time: 600
})

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
```

If `callback_url` does not look like a `localhost`/`127.0.0.1` callback (the user may still be mid-flow), poll once more with a short wait. If after 5+ minutes there is still no callback, check in *once* with the user. Do not nag.

Then submit the callback to Claude Code's MCP runtime to finish the OAuth dance:

```
mcp__canva__complete_authentication({ callback_url })
```

On success, the rest of the `mcp__canva__*` tools become available **in the same session** - no chat restart needed. Proceed to Step 6 for verification.

**Failure handling.** If `complete_authentication` rejects the callback (state mismatch, expired code, malformed URL), surface a plain-English *"let me try once more"* and re-run from `mcp__canva__authenticate()`.

### Step 5 - Detect Enterprise administrator-approval-required interstitial

After Step 4's Allow click - *or* in the rare case that an Enterprise admin has restricted third-party app installs and the consent flow never reached an Allow button - Canva may render an interstitial page like *"Your administrator must approve this app"*, *"This app requires admin consent"*, or *"Administrator approval required to install"*. This is a hard block - the user cannot proceed without their Canva Enterprise admin allowlisting the Canva MCP app for the workspace.

Detect via `browser_evaluate` against the post-Allow snapshot:

```javascript
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /administrator (must |approve|approval)/i,
    /admin (consent|approval) (required|needed)/i,
    /workspace administrator/i,
    /your admin/i,
    /awaiting approval/i,
  ];
  return markers.some(re => re.test(text));
}
```

If the function returns `true`, surface cleanly and exit:

> "Canva is telling me your workspace administrator needs to allow this connection first. Your Canva Enterprise admin can allowlist the **Canva AI Connector** app in their admin console - once they do, come back and say *'connect to my Canva'* and I'll finish setting up. There isn't an alternative key-based path for Canva, so the admin step is the only way through."

Close the browser, do not retry - the block is org-policy. There is **no API-key fallback** for Canva (unlike Airtable, which offers a PAT path).

If the function returns `false`, the consent flow completed normally - proceed to Step 6.

### Step 6 - Close the browser + verify

Close Playwright:

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection - let me check it works."*

Verify by calling a canonical Canva read-only smoke tool - `search-designs` with an empty query is the standard probe (returns the user's recent designs, including an empty list if the account is brand new):

```
mcp__canva__search-designs({ query: "" })
```

Because `complete_authentication` unblocks the rest of the `mcp__canva__*` surface in the same session, the smoke call should run immediately:

- **Call returns design results (or an empty list)** → capture the count, surface a success message including the live count.
- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403 / `plan_required`** → connection works but the user's plan doesn't grant access to that specific tool - explain plan gating and offer an alternative tool.
- **Call returns 403 with admin-block messaging** → re-run Step 5's interstitial detection and surface the admin-allowlist guidance.

### Success message

Tell the user, in one short message (include the live design count if available):

> "All done! Your Canva is now connected - I can see **\<N\> designs**. You can ask me things like 'show me my latest designs', 'export my pitch deck as a PDF', 'generate a new social post about X', or 'add a comment to that design'. Give it a try!"

---

## PHASE 2 - Use Tools

**Which namespace.** Through the built-in connector the tools are `mcp__claude_ai_Canva__*`; through the kit's route they are `mcp__canva__*`. It is the same server, so the hyphenated tool names in the Tool Reference below are the same on both - only the prefix changes. Everywhere this skill writes `mcp__canva__<name>`, read `mcp__claude_ai_Canva__<name>` if that is the route that connected. If a name does not resolve, list the tools in whichever namespace is live and match by description. The mandatory `user_intent` parameter, the plan gating, the confirmation gates and the editing-transaction rules below apply identically on both routes.

Once the connector is configured, use the Canva MCP tools below to answer questions and make changes in Canva. The hosted Canva MCP server provides **37 first-party tools** across 11 categories covering designs (read, generate, duplicate, merge, shortlink-resolution), assets, folders, comments, exports, AI generation, a transactional editing flow, brand templates and kits, and help-answers. **Drift caveat**: 3 of those tools (`search-brand-templates`, `get-brand-template-dataset`, `autofill-design`) are Enterprise-plan-gated and only surface in the tool list for Enterprise users; the other 34 are available across plans.

### Tool names use hyphens

Canva's tool names use hyphens, not underscores - e.g. `mcp__canva__search-designs`, `mcp__canva__export-design`. If a tool name does not resolve, list available tools with the `mcp__canva__` prefix to discover the current naming.

### Plan gating - know before you call

Some tools are gated by the user's Canva plan. Calling a gated tool on a lower plan returns `403 Forbidden` or a `plan_required` error. Check before calling:

| Plan | Tools available |
|---|---|
| **Free / all plans** | 33 tools - designs (read, generate, copy, merge, shortlink-resolve), assets, folders, comments, exports, imports, AI generation, editing transactions, help-answers, brand-kit listing, brand-template instantiation |
| **Pro and above** | Adds `resize-design` |
| **Enterprise only** | Adds `autofill-design`, `get-brand-template-dataset`, `search-brand-templates` |

> **Captured 2026-06-05 - `list-brand-kits` is NOT Enterprise-gated** despite older Canva docs implying it was. A non-Enterprise smoke (Rodolfo's account) returned `{ items: [] }` (success, empty list) - the tool surfaces for all plans; it just returns empty if the user has no brand kits set up. Route brand-colour questions to `list-brand-kits` first, only plan-warn if the user expected results AND another signal suggests they're below the brand-kit-creation tier.

**Export quality is also plan-gated.** `export-design` works on all plans, but Free plans only get standard-quality exports; Pro and above get lossless PNG, transparent backgrounds, and premium element export. If a design on a Free plan contains premium elements, the export may fail with `license_required` - tell the user they need a paid plan for that specific design.

### Tool Reference

> **Captured 2026-06-05 - every Canva tool requires a `user_intent` parameter.** The live JSON schema on every `mcp__canva__*` tool declares `user_intent` as a string field with description `"Mandatory description of what the user is trying to accomplish with this tool call... (255 characters or less recommended)"`. Pass it on every call - a one-sentence framing of what the user is trying to do. This is server-side enforced framing, not a no-op convention.

#### Designs - read (no confirmation needed)

| Tool | Rate | Description |
|---|---|---|
| `search-designs` | 100/min | Find designs by name or keyword. If `query` is set, `sort_by` MUST be `"relevance"` |
| `get-design` | 100/min | Retrieve a single design's metadata. Design IDs are exactly 11 chars, regex `^D[a-zA-Z0-9_-]+$` |
| `get-design-pages` | 100/min | Retrieve the page structure of a design |
| `get-design-content` | 100/min | Retrieve text and element content from a design |
| `get-presenter-notes` | 100/min | Retrieve speaker notes from a presentation |
| `get-export-formats` | 100/min | Check which formats a design can be exported as. Returns `{ formats: { pdf: {}, jpg: {}, png: {}, pptx: {}, gif: {}, mp4: {}, ... } }` - keys are the supported formats, empty-object values |
| `resolve-shortlink` | 100/min | Resolve a `canva.link/<id>` short URL to a full `canva.com/d/<id>` design URL (use BEFORE `get-design` when the user pastes a shortlink) |

#### Designs - generate, copy, merge (destructive - always confirm)

| Tool | Rate | Description |
|---|---|---|
| `generate-design` | 20/min | AI-generate a new design from a prompt - **confirm first** |
| `generate-design-structured` | 20/min | AI-generate a design with a specified structure - **confirm first** |
| `create-design-from-candidate` | 20/min | Create a design from a previously generated AI candidate - **confirm first** |
| `create-design-from-brand-template` | 20/min | Instantiate a brand template into a new editable design (distinct from `autofill-design` which fills with structured data) - **confirm first** |
| `copy-design` | 20/min | Duplicate an existing design as a new design - **confirm first** |
| `merge-designs` | 20/min | Combine multiple designs into one - **confirm first**; the source designs are unchanged |
| `request-outline-review` | 20/min | Request a review pass on an AI-generated outline |

#### Design imports & exports

| Tool | Rate | Plan | Description |
|---|---|---|---|
| `import-design-from-url` | 20/min | All plans | Import an external design from a URL - **confirm first** |
| `export-design` | 20/min | All plans* | Export a design as image or PDF - **confirm first**. Free = standard quality; Pro+ = lossless PNG, transparent bg, premium elements |

#### Assets

| Tool | Rate | Description |
|---|---|---|
| `upload-asset-from-url` | 30/min | Upload an image or video asset from a URL - **confirm first** |
| `get-assets` | 100/min | List or search assets in the user's library |

#### Comments

| Tool | Rate | Description |
|---|---|---|
| `list-comments` | 100/min | Read comment threads on a design |
| `list-replies` | 100/min | Read replies within a comment thread |
| `comment-on-design` | 100/min | Add a new comment to a design - **confirm first** |
| `reply-to-comment` | 20/min | Reply to an existing comment - **confirm first** |

#### Folders

| Tool | Rate | Description |
|---|---|---|
| `search-folders` | 100/min | Find folders by name |
| `list-folder-items` | 100/min | List the contents of a folder |
| `create-folder` | 20/min | Create a new folder - **confirm first** |
| `move-item-to-folder` | 100/min | Move a design or asset into a folder - **confirm first** |

#### Resize (Pro and above only)

| Tool | Rate | Description |
|---|---|---|
| `resize-design` | 20/min | Resize a design to new dimensions - **confirm first**. Returns `403` / `plan_required` on Free plans |

#### Brand kits (all plans)

| Tool | Rate | Description |
|---|---|---|
| `list-brand-kits` | 100/min | List the user's brand kits. Works on all plans; returns `{ items: [] }` (success, empty) for users with no brand kits set up. May surface `Missing scopes: [brandkit:read]` if the connector token lacks the scope - surface "please reconnect" guidance |

#### Brand templates and autofill (Enterprise only)

| Tool | Rate | Description |
|---|---|---|
| `search-brand-templates` | 100/min | Find Enterprise brand templates |
| `get-brand-template-dataset` | 100/min | Retrieve the field schema of an autofill-capable brand template |
| `autofill-design` | 10/min | Fill a brand template with data (one design per row) - **confirm first** |

#### Help & resources

| Tool | Rate | Description |
|---|---|---|
| `help` | 100/min | Search Canva's help-answers knowledge base (e.g. *"remove background"*, *"resize a design"*). Returns `{ job: { id, status, result: { answer } } }` - an async-job pattern with a SINGLE markdown answer string, not a list of snippets. Prompt: `minLength: 1, maxLength: 2000`. May surface `Missing scopes: [help:answers:read]` requiring reconnect |

#### Editing transactions - the 4-step edit pattern

Canva uses an explicit **transactional editing flow** for structural edits (different from simple write tools). To modify a design's content you open a transaction, apply operations, then commit or cancel. Never leave an uncommitted transaction dangling.

| Step | Tool | Rate | Purpose |
|---|---|---|---|
| 1. Open | `start-editing-transaction` | 20/min | Begin an edit session on a design |
| 2. Apply | `perform-editing-operations` | 50/min | Apply one or more operations within the transaction |
| 3a. Save | `commit-editing-transaction` | 20/min | Persist the changes |
| 3b. Abort | `cancel-editing-transaction` | 20/min | Discard the changes (use this on error or if the user backs out) |
| Inspect | `get-design-thumbnail` | 100/min | Fetch a preview thumbnail - helpful before/after an edit |

Rules for editing transactions:

- **Always confirm before `commit-editing-transaction`** - this is the destructive step. Summarise what is about to be saved and wait for the user's OK.
- **Always cancel on failure** - if `perform-editing-operations` fails or the user aborts, call `cancel-editing-transaction` so no half-applied edit sits open.
- **One transaction per design at a time** - don't open a second transaction on the same design before committing or cancelling the first.
- **Show a thumbnail first** when the user has not seen the current state of the design - it grounds the conversation in what they'll actually be changing.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "Connect my Canva" / "Help me set up Canva" | **Run Phase 0**, then Phase 1 (or Phase 1-alt if Phase 1 Step 1 fails) |
| "My Canva stopped working" / "I'm getting auth errors" | **Run Phase 0.** Built-in connector → the Reconnect path in Phase 0 step 1. Kit's route → run Phase 1-alt from Step 3 (Claude Code re-runs the OAuth dance) |
| "Show me my latest designs" | `search-designs` (empty or recency-sorted query) |
| "Find my pitch deck" | `search-designs` (name match) |
| "Check my brand colours" / "What's in my brand kit?" / "List my brand kits" | `list-brand-kits` - works on all plans; returns empty list if no brand kits set up (surface "I don't see any brand kits set up in your Canva account - want to create one?") |
| "I have this URL: canva.link/abc123" / "Open this shortlink" | `resolve-shortlink` → then `get-design` with the resolved ID |
| "Duplicate this design" / "Copy this and make a new version" | `copy-design` - **confirm first** |
| "Combine these designs into one" / "Merge slide deck A and slide deck B" | `merge-designs` - **confirm first**; source designs are unchanged |
| "Start from this brand template" / "Make a design from our brand template" | `create-design-from-brand-template` - **confirm first** (distinct from `autofill-design` which needs structured data) |
| "Show me the Canva help on backgrounds" / "How do I resize a design in Canva?" | `help` (search-style query against Canva's help knowledge base - works on all plans) |
| "What pages are in this design?" | `get-design` → `get-design-pages` |
| "Read the text in this design" | `get-design-content` |
| "Show me the speaker notes" | `get-presenter-notes` |
| "Export my pitch deck as a PDF" | `get-export-formats` → `export-design` - **confirm first** |
| "Generate a social post about our product launch" | `generate-design` → `create-design-from-candidate` - **confirm before creating** |
| "Import this design from <URL>" | `import-design-from-url` - **confirm first** |
| "Upload this image to my Canva assets" | `upload-asset-from-url` - **confirm first** |
| "Find the image I uploaded last week" | `get-assets` |
| "Show me the comments on this design" | `list-comments` (optionally `list-replies`) |
| "Leave a comment on this design saying X" | `comment-on-design` - **confirm first** |
| "Reply to that comment with Y" | `reply-to-comment` - **confirm first** |
| "Find my 'Q1 campaigns' folder" | `search-folders` → `list-folder-items` |
| "Create a new folder called 'Launch Week'" | `create-folder` - **confirm first** |
| "Move this design into my Launch Week folder" | `search-folders` → `move-item-to-folder` - **confirm first** |
| "Resize my Instagram post to a LinkedIn post" | `resize-design` - **confirm first** (Pro+ only) |
| "Fill this brand template with data from my spreadsheet" | `search-brand-templates` → `get-brand-template-dataset` → `autofill-design` - **Enterprise only, confirm per row** |
| "Change the title on slide 2 to 'Revenue'" | `get-design-thumbnail` → `start-editing-transaction` → `perform-editing-operations` → **confirm** → `commit-editing-transaction` |
| "Show me a preview of that design" | `get-design-thumbnail` |

---

## Error Handling (Phase 2)

When a Canva tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Canva connection has expired - let me reconnect you." | Re-run Phase 0. Built-in connector → the Reconnect path in Phase 0 step 1. Kit's route → walk Phase 1-alt from Step 3 (Claude Code re-runs OAuth). Then retry the original tool call |
| 403 Forbidden | "Your Canva user doesn't have permission for that. The design owner may need to share it with you, or your admin may need to grant access." | User talks to the design owner or workspace admin |
| 403 `plan_required` (on `resize-design` or Enterprise tools) | "That feature needs a paid Canva plan. `resize-design` needs Pro or above; brand templates and autofill need Enterprise." | User upgrades their plan, or you suggest an alternative tool |
| `license_required` on `export-design` | "This design uses premium Canva elements - exporting it needs a paid plan. On the Free plan, exports skip or fail if there are premium items." | User upgrades to Canva Pro, or removes the premium elements before export |
| 404 Not Found (design / folder / asset) | "I couldn't find that item - let me refresh the list." | Use `search-designs` / `search-folders` / `get-assets` to refresh |
| 422 Invalid request | "Canva rejected the request - usually a bad parameter. Let me check and try again." | Re-read the design with `get-design` / `get-design-pages` and reformat the call |
| 429 Rate limited | "Canva is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. Per-tool rate limits are listed in the Tool Reference above |
| Editing transaction already open | "I had an edit session open - let me close that first, then retry." | Call `cancel-editing-transaction` on the stale session before starting a new one |
| Editing transaction expired mid-edit | "The edit session timed out. Let me start fresh." | Re-open with `start-editing-transaction` and re-apply the operations |
| MCP server not running | "The Canva connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Admin approval required (Enterprise) | "Your workspace administrator has restricted this connection. They need to allowlist the Canva AI Connector app for your workspace - once done, the sign-in will work for you and your team." | Canva workspace admin allowlists the MCP app; there is no API-key fallback |
| Any other API error | "Something went wrong with Canva - let me try again." | Retry once; if still failing, re-run Phase 0 and reconnect by whichever route is in use |

---

## Scope Limitations

The Canva MCP connector **can** do (via the official Canva MCP server):

- Search, read, and retrieve designs, pages, content, presenter notes, and export formats
- Generate new designs from AI prompts (with or without a specified structure)
- Import designs from external URLs
- Export designs as image or PDF (quality depends on plan)
- Upload and list assets (images, videos)
- List, add, and reply to comments on designs
- Search folders, list folder contents, create folders, move items between folders
- Resize designs (Pro and above)
- Search Enterprise brand templates, list brand kits, and autofill brand templates with data (Enterprise)
- Run transactional edits on design content (start → perform → commit / cancel)
- Fetch design thumbnails for visual confirmation
- Search Canva's help knowledge base (`help`) - answer "how do I…" questions without leaving the chat
- Duplicate, copy, and merge designs (`copy-design`, `merge-designs`)
- Instantiate brand templates into editable designs (`create-design-from-brand-template`)
- Resolve `canva.link/<id>` shortlinks to full design URLs (`resolve-shortlink`)

The Canva MCP connector **cannot** do (needs the Canva UI or other tools):

- **Delete** designs, assets, folders, or comments - none of the 37 tools supports deletion. Use the Canva UI to delete.
- **Connect via API key** - Canva MCP is OAuth-only. No Bearer-token fallback.
- **Bypass plan gating** - `resize-design` requires Pro+; brand templates and autofill require Enterprise. Calling them on lower plans returns `403`.
- **Export premium elements on Free plans** - exports may fail with `license_required` if the design contains premium Canva content.
- **Edit structurally without a transaction** - all content edits go through the 4-step transactional flow.
- **Access Canva Docs, Websites, or Print orders** via MCP - the current tool set is scoped to designs, assets, folders, comments, exports, and brand templates.
- **Run more than one edit transaction on the same design at a time** - commit or cancel the first before opening another.
- **Connect multiple Canva accounts simultaneously** - one connection per `~/.claude.json` entry on the kit's route, one per Claude account on the built-in connector.
- **Bypass Enterprise admin allowlisting** - if the admin blocks third-party app installs, the only option is for the admin to allowlist the Canva AI Connector app. There is no PAT fallback.

---

## Enterprise note - admin allowlisting can block first connect

On **Canva Enterprise workspaces**, the workspace administrator can restrict which third-party apps are allowed to connect via OAuth. If this is enforced, the consent screen surfaces an "administrator approval required" interstitial (detected by Phase 1-alt Step 5). This block applies to the built-in connector too - it is Canva's policy, not the route's.

1. There is **no API-key fallback for Canva MCP** - OAuth is the only auth path supported by the hosted server.
2. The user's Canva workspace admin needs to allowlist the **Canva AI Connector** app for the workspace. That is a one-time setup on the admin's side. Once allowlisted, other team members can connect normally.

This mirrors the same shape as the Jotform "workspace admin must install first" limitation documented in `known-issues/JOTFORM-ADMIN-ONLY.md`.

---

## Behaviour Guidelines (Phase 2)

- **Every Canva tool call requires a `user_intent` parameter** - captured 2026-06-05: every `mcp__canva__*` JSON schema declares `user_intent: string` as a "Mandatory description of what the user is trying to accomplish... (255 chars or less recommended)". Pass it on every call: one short sentence framing the user's goal. Omitting it is a tool-call shape error, not a no-op.
- **Always confirm before creating, generating, editing, exporting, copying, merging, or moving** - summarise what you are about to do and wait for the user's OK before calling a write/generate/export tool. AI generation (`generate-design`, `generate-design-structured`, `create-design-from-candidate`, `create-design-from-brand-template`) and structural transforms (`copy-design`, `merge-designs`) cost the user's Canva AI credits / consume their design quota - always confirm before firing.
- **Discover IDs before writing** - Canva designs, folders, and assets are referenced by opaque IDs. Always call `search-designs` / `search-folders` / `get-assets` once per session before any write or edit, unless you already have the IDs from earlier in the conversation.
- **Handle the editing transaction lifecycle carefully** - always commit or cancel. Never leave a transaction open. If `perform-editing-operations` fails, call `cancel-editing-transaction` before retrying.
- **Show thumbnails before structural edits** - `get-design-thumbnail` grounds the user in what they are about to change. Cheap, fast, worth calling.
- **Respect plan gating before calling** - if the user is on Free, don't call `resize-design` or the Enterprise-only tools without warning. If you're unsure of their plan, attempt the call and translate the `403` / `plan_required` response into plain English.
- **Export quality caveat** - on the Free plan, `export-design` gives standard-quality output and may fail with `license_required` on designs with premium elements. Warn the user proactively when you detect premium content.
- **Designs often contain confidential content** - pitch decks, client work, internal campaigns. Never dump full design content into a public log without checking with the user first. Prefer titles and page counts over full text dumps.
- **Present designs clearly** - format results as readable lists or summaries, not raw JSON. For comment threads, group by thread and show author + text only.
- **One step at a time** - do not dump all data at once. Summarise first ("You have 84 designs; the most recent is 'Q2 Launch Deck' from yesterday"), then offer to show details.
- **Pagination** - default to 25 designs or folder items per response unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits vary by tool** - the Tool Reference above lists per-minute limits. Bulk operations (autofill batches, multi-design exports) should respect the tightest limit in the chain.
- **Never log or echo connection details** - never paste the contents of `~/.claude.json` to the user.

---

## Related Skills

- **orientation**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **atlassian-connector**: Sibling Playwright-driven autonomous connector - same shape, no Enterprise allowlist branch
- **airtable-connector**: Sibling hosted OAuth MCP connector - pair structured data with Canva autofill to generate one design per row
- **jotform-connector**: Sibling hosted OAuth-only MCP connector - identical install pattern, no API-key fallback
- **ad-creative**: Generate ad copy variations then render them as Canva designs with `autofill-design` (Enterprise) or `generate-design`
- **social-content**: Turn social posts into Canva-ready visuals and `resize-design` across platforms (Pro+)
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Canva consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Canva auth or API errors
- **canva-sdks/canva-claude-skills** (external repo): Canva publishes ready-made Claude Skills that layer on top of this connector - branded-presentation, design-translation, implement-feedback, presentation-time-fitting, resize-for-social-media, bulk-create, classroom-helper. Three of them (Branded Presentation, Design Translation, Social Media Resize) ship with the built-in connector's directory entry, so a Phase 1 connection brings them along. Mention these when the user wants a higher-level workflow.
