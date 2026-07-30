---
name: calendly-connector
description: "Connect Calendly to Claude by installing and authenticating its official MCP server. Use when the user asks to set up or connect Calendly, or wants scheduling work (event types, availability, meetings, booking links) and Calendly isn't connected yet. Once connected, Calendly runs directly through the mcp__calendly__* tools."
allowed-tools: mcp__calendly__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Scheduling & Booking
  tags:
    - calendly
    - scheduling
    - meetings
    - availability
    - booking
    - mcp
  pairs-with:
    - skill: linear-connector
      reason: Sibling hosted OAuth-only MCP connector with DCR, the canonical 6-step Playwright-driven install pattern this skill mirrors.
    - skill: jotform-connector
      reason: Sibling hosted OAuth-only MCP connector, identical install pattern.
    - skill: monday-connector
      reason: Sibling Playwright-driven autonomous connector, reference for snapshot-and-reason model.
    - skill: slack-connector
      reason: Sibling Playwright-driven autonomous connector, reference for the autonomous-install rules.
    - skill: email-composer
      reason: Draft follow-ups tied to upcoming or cancelled Calendly meetings.
    - skill: google-workspace-connector
      reason: Cross-reference Calendly meetings against Google Calendar availability.
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Calendly bookings.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the Calendly consent flow.
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Calendly auth or API errors.
---

# Calendly Connector

> **Install pattern:** Hosted-OAuth, see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (linear-connector).

Bundled artifacts in this skill folder (read these to verify the SKILL works end-to-end without a live install):

- [`examples/calendly-meetings-list-session.md`](examples/calendly-meetings-list-session.md), full worked transcript: cold start, warm start, deferred-tool-reconciliation restart branch, Enterprise admin-restriction branch, token-expiry re-auth branch.
- [`references/calendly-mcp-shape-snapshot.json`](references/calendly-mcp-shape-snapshot.json), captured `mcp.calendly.com/.well-known/oauth-protected-resource` shape and 35-tool surface inventory at the empirical-verification timestamp. Drift-check recipe included.
- [`CHANGELOG.md`](CHANGELOG.md), version history.

## Overview

This skill lets you read and update a user's Calendly account on their behalf using the **official first-party Calendly MCP server** hosted at `https://mcp.calendly.com` (announced [March 2026](https://calendly.com/blog/mcp-server); docs at [developer.calendly.com/calendly-mcp-server](https://developer.calendly.com/calendly-mcp-server)). It has two phases:

- **Phase 1, Install & Auth (autonomous, 6 steps).** Claude registers the hosted MCP server with `claude mcp add`, opens Claude Code's OAuth start URL inside a Playwright MCP browser, detects login state, auto-clicks Allow on the consent screen, auto-detects the callback via `browser_wait_for`, then verifies with a `mcp__calendly__*` smoke call. The user's only manual moments are signing in to Calendly inside the Playwright window and clicking Allow on the consent screen. Token storage is handled by Claude Code's MCP runtime, there is no manual `~/.claude.json` token write.
- **Phase 2, Use Tools.** Once the connector is configured, you call the `mcp__calendly__*` native tools to read and update Calendly data.

**Which phase to run**, Before any tool call, check whether the Calendly MCP server is already configured. Read `~/.claude.json` (Mac/Linux: `$HOME/.claude.json`; Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.calendly` entry. If present, attempt a verification tool call (Phase 1 Step 6). If it succeeds, the connector is ready, skip to Phase 2. If it 401s, walk Phase 1 from Step 3 to re-trigger the OAuth flow (the registration is already in place).

### What this skill does NOT use

- **Calendly personal access tokens or API keys.** The Calendly MCP server is OAuth-only with Dynamic Client Registration (RFC 7591). There is no pre-registered app, no client secret, and no personal access token to paste. Do not ask the user for any key.
- **A self-hosted Calendly MCP server.** Calendly publishes the hosted endpoint at `https://mcp.calendly.com` as the only deployment. Self-hosting is not supported.
- **Direct Calendly REST API calls.** All reads and writes go through the MCP server, not direct HTTP calls to the Calendly Public API.
- **The "Calendly connector for Claude" Desktop entry.** That is a Claude Desktop feature, not available in Claude Code. In Code we wire the MCP URL directly per Phase 1.
- **A custom OAuth client (DCR replication, custom PKCE, loopback listener).** Claude Code's MCP runtime owns the OAuth dance natively; we do not register our own client, run our own callback listener, or store OAuth tokens manually. The skill's job is to choreograph Playwright + Claude Code's native OAuth handler, not to replicate OAuth.

### How auth works under the hood

The Calendly MCP server is a hosted OAuth 2.1 server (verified live 2026-04-30 against `mcp.calendly.com/.well-known/oauth-protected-resource`): the protected-resource document declares `authorization_servers: ["https://calendly.com/"]`, `scopes_supported: ["mcp:scheduling:write", "mcp:scheduling:read"]`, and `bearer_methods_supported: ["header"]`. Auth discovery follows the standard well-known path: Claude Code's MCP runtime fetches `mcp.calendly.com/.well-known/oauth-protected-resource` to locate the authorization server. The authorization server itself is `calendly.com` (not `mcp.calendly.com`), its discovery document at `calendly.com/.well-known/oauth-authorization-server` advertises `authorization_endpoint = https://calendly.com/oauth/authorize`, `token_endpoint = https://calendly.com/oauth/token`, `registration_endpoint = https://calendly.com/oauth/register`, `code_challenge_methods_supported = ["plain","S256"]`, and public-client `none` auth method (RFC 7591 DCR).

From the SKILL's perspective this is a standard OAuth 2.1 + PKCE flow at `calendly.com`, Claude Code's MCP runtime drives it natively. The skill only opens the start URL inside Playwright, auto-clicks Allow, and waits for the callback.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous, Claude does the work, the user only signs in to Calendly in the Playwright window and clicks Allow. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values. The only actions you ever request are: "please sign in to the browser window I just opened" and "please click Allow on the screen Calendly just showed you."
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, DCR, PKCE, scope, token, MCP, endpoint, JSON, REST, environment variable, Playwright, browser automation, redirect URI, or DOM. The browser window you open is "a browser window I just opened for you" or "the connection page", not "Playwright" or "Chromium". If you must name a technical concept, plainly:
  - access token / bearer → **"your connection key"**
  - Allow / consent → **"the Allow button"**
  - close and reopen Claude Code → **"close and reopen the chat"**
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening Calendly for you now"), once when you need them ("please sign in", "please click Allow"), once when you're done ("your Calendly is now connected"). No commentary in between snapshots, clicks, or evaluates.
- **React to success and failure warmly.** Good: "That worked, your Calendly is now connected." Bad: "Token exchange returned 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## Phase 0, Pre-flight (silent)

### 0.1, Resume check

Read `~/.claude.json` via Node (cross-platform safe, Bash variable expansion of `%USERPROFILE%` on Git Bash for Windows is fragile):

```bash
node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const av = (j.mcpServers || {}).calendly;
console.log(av ? 'REGISTERED' : 'NOT_CONFIGURED');
"
```

- `REGISTERED` → try Phase 1 Step 6 (verify) first. If it succeeds, the connector is already active, surface a friendly message and stop. If 401, walk Phase 1 from Step 3.
- `NOT_CONFIGURED` → run full Phase 1 from Step 1.

### 0.2, Tooling check (silent)

Verify Node 18+, the `claude` CLI is on PATH (`claude --version`), and Playwright MCP is available (`mcp__playwright__browser_navigate` or `mcp__plugin_playwright_playwright__browser_navigate` in the tool surface). If `claude` is missing, fall back to the `first-run-setup` skill. If Playwright MCP is missing, install autonomously with `claude mcp add playwright --scope user -- npx @playwright/mcp@latest` (the `--` separator keeps Claude Code from consuming `npx` as an `add` flag), ask the user to close and reopen the chat, then retry.

**Claude Code minimum version.** Phase 1 Step 4b calls `mcp__calendly__complete_authentication({ callback_url })`. The `mcp__<server>__authenticate` / `mcp__<server>__complete_authentication` runtime tool pair is the Pattern 1 contract documented in [skills/CLAUDE.md](../CLAUDE.md). The tools appear after `claude mcp add` registers the server and the deferred-tool surface reconciles. If `claude --version` reports a build older than the version that introduced this surface (Claude Code v2.1.140, May 2026), the user must upgrade before Phase 1 can complete. The failure mode on older builds is silent: `mcp__calendly__authenticate` simply does not exist in the tool surface. Surface this as a plain-English version-upgrade prompt rather than a "tool not found" loop.

---

## PHASE 1, Install & Auth (6 steps, autonomous via Playwright)

### Step 1, Orient the user

Tell the user, in one short message:

> "I'll connect your Calendly now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2, Register the MCP server with `claude mcp add`

Silently register the hosted Calendly MCP server in the user's config:

```bash
claude mcp add calendly https://mcp.calendly.com --transport http --scope user
```

This writes the server entry to `~/.claude.json` and lets Claude Code's MCP runtime own the OAuth dance from here forward.

**Fallback if `claude mcp add` errors** (older Claude Code version, CLI not on PATH, or unexpected output), write the entry directly to `~/.claude.json` via the Node merge pattern. The rename is inside Node so the swap is atomic on every platform (Mac / Linux / Windows Git Bash) and does not run if the JSON write fails:

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
  j.mcpServers.calendly = { type: "http", url: "https://mcp.calendly.com" };
  const tmp = cfg + ".tmp";
  fs.writeFileSync(tmp, JSON.stringify(j, null, 2));
  fs.renameSync(tmp, cfg);
'
```

If the merge stderr emits `CONFIG_BACKUP=`, the existing config was unreadable and Claude has just made a backup. Surface this to the user once: *"Your settings file was unreadable, so I made a safe backup before saving."*

### Step 3, Acquire OAuth start URL via `mcp__calendly__authenticate` and open it in Playwright

When Claude Code registers a hosted MCP server that requires auth, its runtime exposes a **per-server pair of OAuth-bootstrap tools** in the deferred-tool surface:

- `mcp__calendly__authenticate()`, no args, returns the OAuth authorization URL.
- `mcp__calendly__complete_authentication({ callback_url })`, submits the post-redirect callback URL to finish the OAuth dance.

These appear after `claude mcp add` registers the server and the tool surface refreshes. They are the supported programmatic OAuth-bootstrap path, not a `claude mcp` CLI subcommand.

**Tool-availability precondition.** On the very first session after `claude mcp add calendly ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__calendly__authenticate` may not be in the tool surface. This is the documented Pattern 1 behaviour (see [skills/CLAUDE.md](../CLAUDE.md) → Pattern 1 → "Deferred-tool reconciliation timing"). As of Claude Code v2.1.140 there is no programmatic `/reload-mcp` or soft tool-surface refresh, the supported recovery is a chat restart. Ask the user *once*, framed as an apology plus the action, not a blank request:

> "Apologies, Calendly is added, but its authentication tools take a chat restart to appear. Close and reopen this chat once, then say 'connect to my Calendly' and I'll finish from there."

On resume, Phase 0's resume check sees the `mcpServers.calendly` entry, attempts the verification call, finds the authentication tools now exist in the tool surface, and routes back into Step 3 of this flow. If a future Claude Code build exposes a programmatic refresh, replace the restart with that, until then, the close-reopen is the path.

**Mint the URL and open it:**

```
{ authorization_url } = mcp__calendly__authenticate()
mcp__playwright__browser_navigate({ url: authorization_url })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in + consent UI visible** (you see Calendly's app-permission screen with an Allow / Authorize button and the Claude Code app name) → continue to Step 4.
- **Not logged in** (Calendly sign-in form, "Continue with Google/Microsoft", magic-link prompt, or SSO redirect) → tell the user, *once*: *"Please sign in to your Calendly account in the browser window I just opened. On the next screen you'll see an **Allow** button, click it once you're there."* Then `mcp__playwright__browser_wait_for` polling for consent text (`"would like access"` / `"requesting access"` / `"Allow"` / `"Authorize"`). Generous timeout (5 minutes); no nagging. After a long timeout, check in once: *"Still on the sign-in page? Anything I can help with?"*
- **Wrong account signed in** (the user has multiple Calendly accounts and the session is on the wrong one) → tell them: *"Looks like you're signed in to a different Calendly account than you meant. Please sign out and sign back in with the right account, then I'll continue."*

### Step 4, Auto-click Allow + auto-detect callback

#### 4a, Narrate, click Allow

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

> "Calendly is showing the permissions screen, it's asking to: \<scope 1\>, \<scope 2\>, \<scope 3\>. Clicking **Allow** now."

Then locate the Allow button by accessibility role + name (case-insensitive, allow `Allow` / `Accept` / `Authorize` / `Authorise` / `Grant access`):

```
mcp__playwright__browser_click({
  target: <ref of the button matching role:button, name:/^(allow|accept|authori[sz]e|grant access)/i>,
  element: "Allow button on the Calendly consent screen"
})
```

If the Allow button cannot be located in the snapshot (UI shifted, embedded iframe, unexpected layout), fall back to a one-time user-click prompt: *"I couldn't find the Allow button automatically, please click **Allow** in the browser window."*

#### 4b, Capture callback URL + submit via `complete_authentication`

Calendly redirects to Claude Code's localhost callback (`http://localhost:<port>/callback?code=...&state=...`). On remote sessions that page may fail to load, but the URL in the address bar is still valid, that's what `complete_authentication` needs.

Wait for the redirect via a URL-pattern wait, then capture the full `window.location.href` **before** closing the browser (after close there is no page to read):

```
mcp__playwright__browser_wait_for({
  // Generous timeout, the user may take a minute on the consent screen.
  time: 300
})

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
```

If `callback_url` does not look like a `localhost`/`127.0.0.1` callback (the user may still be mid-flow), poll once more with a short wait. If after 5 minutes there is still no callback, check in *once* with the user. Do not nag.

Then submit the callback to Claude Code's MCP runtime to finish the OAuth dance:

```
mcp__calendly__complete_authentication({ callback_url })
```

On success, the rest of the `mcp__calendly__*` tools become available **in the same session**, no chat restart needed. Proceed to Step 6 for verification.

**Failure handling.** If `complete_authentication` rejects the callback (state mismatch, expired code, malformed URL), surface a plain-English *"let me try once more"* and re-run from `mcp__calendly__authenticate()`.

If the user clicks **Cancel** or **Deny** instead of **Allow**, Calendly redirects back without a code. Tell them: *"Looks like you declined the permission, no problem. Want me to try again?"* If yes, re-mint via `mcp__calendly__authenticate()` and re-run Step 4.

### Step 5, Detect plan/admin restriction interstitial (rare)

Some Calendly accounts (older trials, suspended seats, or workspaces with admin-managed integration policies) may render an interstitial after the Allow click that blocks the connection rather than redirecting to the callback. This is distinct from a normal consent flow, the Allow button completes but Calendly shows an "approval required" / "plan does not include" page instead of redirecting.

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
    /your (calendly )?plan does not (include|allow)/i,
    /upgrade .* plan/i,
  ];
  return markers.some(re => re.test(text));
}
```

If the function returns `true`, surface cleanly and exit:

> "Calendly is telling me your account or workspace administrator needs to allow this connection first. Once that's sorted, come back and say *'connect to my Calendly'* and I'll finish setting up."

If the function returns `false`, the consent flow completed normally, proceed to Step 6.

### Step 6, Close the browser + verify

Close Playwright (if not already closed):

```
mcp__playwright__browser_close()
```

Tell the user: *"I've saved your connection, let me check it works."*

Verify by calling a canonical Calendly read-only smoke tool. Tool names aren't always discoverable up-front, discover at runtime by listing the `mcp__calendly__*` tools available in the current session and pick a safe read-only one (e.g. `users-get_current_user` with no arguments). If it returns a result, the connection works.

Because `complete_authentication` unblocks the rest of the `mcp__calendly__*` surface in the same session, the smoke call should run immediately:

- **Call returns a profile** → capture the user's name / email / timezone, surface a success message including the user's name.
- **Call returns 401 / `invalid_token`** → walk Phase 1 from Step 3 once. If still failing, surface the user-facing error and stop.
- **Call returns 403** → "Your connection is working, but your Calendly account doesn't have permission for that action, your plan may not include it." Stop here.
- **`429 Rate limited`** → "Calendly is asking me to slow down, let me wait a moment and try again." Wait 10 seconds, retry once.

### Success message

Tell the user, in one short message (include the live name from the smoke call if available):

> "All done! Your Calendly is now connected. You can ask me things like 'what meetings do I have this week?', 'show me my event types', or 'create a one-time booking link for a 30-minute intro call'. Give it a try!"

---

## PHASE 2, Use Tools

Once the connector is configured, use the `mcp__calendly__*` MCP tools below to answer questions and make changes in Calendly. The hosted Calendly MCP server provides **35 first-party tools** covering scheduling, no-show management, routing forms, and user/organization management.

### First-call tool-name-drift guard (run once per Phase 2 session)

Before the first `mcp__calendly__*` call in any Phase 2 session, list the available `mcp__calendly__*` tools and confirm the canonical 35-tool surface is intact. The canonical category names (used as the `<category>` half of the `mcp__calendly__<category>-<action>` shape) are:

`event_types`, `meetings`, `users`, `organizations`, `contacts`, `scheduling_links`, `webhooks_read`, `activity_log`, `routing_forms`.

If a canonical category name is missing from the live tool surface (Calendly may have renamed a tool category, or the MCP server may have shipped a partial deploy), surface a plain-English warning instead of silently mis-routing:

> "Heads up: Calendly's tool surface looks different from what this skill expects. I can see categories X, Y, Z but the canonical W category is missing. The connection still works, but a specific request may route oddly. Want me to keep going and adapt as I find live tool names, or wait for a fix?"

The reference snapshot at [`references/calendly-mcp-shape-snapshot.json`](references/calendly-mcp-shape-snapshot.json) documents the canonical surface at the empirical-verification timestamp. The drift-check recipe inside that JSON is the slower out-of-band path; the in-session guard above is the fast in-line path.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__calendly__`. Tool names follow a `<category>-<action>` shape. Verified against the [official supported-tools list](https://developer.calendly.com/supported-tools).

#### Users & Organization

| Tool | Description | Use when |
|---|---|---|
| `users-get_current_user` | Get the authenticated user's profile | Kick-off / verification; resolve `user_uri` for scoped queries |
| `users-get_user` | Get another user's profile by UUID | Looking up a teammate on the same org |
| `organizations-get_organization` | Retrieve org details | User asks "what plan are we on?" or needs the org URI |
| `organizations-list_organization_memberships` | List all teammates | User asks "who is on my Calendly team?" |
| `organizations-get_organization_membership` | Get a specific membership | Drilling into one teammate's role |
| `organizations-delete_organization_membership` | Remove a member | **Destructive, confirm twice** |
| `organizations-list_organization_invitations` | List pending invitations | User asks "who have I invited?" |
| `organizations-create_organization_invitation` | Invite a new user | **Confirm first** |
| `organizations-revoke_organization_invitation` | Revoke a pending invitation | **Confirm first** |

#### Event Types (meeting templates)

| Tool | Description | Use when |
|---|---|---|
| `event_types-list_event_types` | List the user's / org's event types | User asks "show me my booking links" |
| `event_types-get_event_type` | Retrieve one event type | Need details before updating or linking |
| `event_types-create_event_type` | Create a new event type | User asks for a new booking type, **confirm first** |
| `event_types-update_event_type` | Update an event type | User wants to rename, re-colour, or change settings, **confirm first** |
| `event_types-list_event_type_available_times` | List open time slots for a given event type | User asks "when am I free for a 30-min intro next week?" |
| `event_types-list_event_type_availability_schedule` | List availability schedules attached to an event type | Diagnosing why open slots look wrong |
| `event_types-update_event_type_availability_schedule` | Change the availability schedule on an event type | **Confirm first** |

#### Meeting Locations

| Tool | Description | Use when |
|---|---|---|
| `locations-list_user_meeting_locations` | List a user's saved meeting locations (Zoom, Google Meet, phone, in-person) | Before creating a booking that needs a specific location |

#### Meetings / Scheduled Events

| Tool | Description | Use when |
|---|---|---|
| `meetings-list_events` | List scheduled events (filter by user, org, invitee, status, date) | User asks "what's on my calendar", "show me cancelled meetings", "what did I have last Friday?" |
| `meetings-get_event` | Retrieve a single scheduled event | Drilling into one meeting |
| `meetings-cancel_event` | Cancel a scheduled event | **Confirm first**, notifies the invitee automatically |
| `meetings-create_invitee` | Book a meeting on behalf of a user via the Scheduling API | User asks to book a specific client into a slot, **confirm first, show the slot & invitee before booking** |
| `meetings-list_event_invitees` | List invitees for a given event | User asks "who showed up to that meeting?" |
| `meetings-get_event_invitee` | Get details for one invitee | Need email / answers to booking questions |

#### No-Show Management

| Tool | Description | Use when |
|---|---|---|
| `meetings-create_invitee_no_show` | Mark an invitee as a no-show | **Confirm first**, they may see this reflected in analytics |
| `meetings-get_invitee_no_show` | Retrieve a no-show record | Checking whether someone has already been marked |
| `meetings-delete_invitee_no_show` | Remove a no-show mark (i.e. they actually did attend) | **Confirm first** |

#### Scheduling Links & Shares

| Tool | Description | Use when |
|---|---|---|
| `scheduling_links-create_single_use_scheduling_link` | Create a one-time booking link for an event type | User asks "send Jane a one-off link for a 30-min intro" |
| `shares-create_share` | Create a customised single-use link (with pre-filled questions, custom copy) | User wants a more personalised one-off link, **confirm first** |

#### User Availability

| Tool | Description | Use when |
|---|---|---|
| `availability-list_user_availability_schedules` | List all availability schedules for the user | User asks "what working hours do I have set?" |
| `availability-get_user_availability_schedule` | Get one availability schedule | Drilling in before editing hours |
| `availability-list_user_busy_times` | List the user's busy times within a date range | User asks "when am I double-booked next week?" |

#### Routing Forms *(Teams plan or higher)*

| Tool | Description | Use when |
|---|---|---|
| `routing_forms-list_routing_forms` | List routing forms on the account | User asks about lead-routing forms |
| `routing_forms-get_routing_form` | Get one routing form | Drilling in before reviewing submissions |
| `routing_forms-list_routing_form_submissions` | List submissions to a routing form | User asks "show me leads from this week's routing form" |
| `routing_forms-get_routing_form_submission` | Get one submission | Drilling into a single lead |

> **If a tool name in the table above does not resolve**, list the available `mcp__calendly__*` tools in the current session, match by description to the category you need, and use the actual name. Never guess, list first, then call.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Calendly" / "Help me set up Calendly" | **Run Phase 1** |
| "My Calendly stopped working" / "I'm getting auth errors" | Walk Phase 1 from Step 3 (Claude Code re-runs the OAuth dance) |
| "What meetings do I have this week?" | `meetings-list_events` (filter by date range) |
| "Show me my booking links" / "List my event types" | `event_types-list_event_types` |
| "When am I free for a 30-min intro next week?" | `event_types-list_event_types` (find the 30-min one) → `event_types-list_event_type_available_times` |
| "Create a one-time booking link for a 30-min intro" | `event_types-list_event_types` → `scheduling_links-create_single_use_scheduling_link` |
| "Send Jane a personalised one-off link" | `event_types-list_event_types` → `shares-create_share`, **confirm first** |
| "Cancel my 3pm meeting tomorrow" | `meetings-list_events` (find it) → `meetings-cancel_event`, **confirm first** |
| "Book John Smith into my 30-min slot at 2pm Friday" | `event_types-list_event_types` → `meetings-create_invitee`, **confirm slot + invitee first** |
| "Who came to that strategy call on Tuesday?" | `meetings-list_events` → `meetings-list_event_invitees` |
| "Mark Sarah as a no-show for the 10am" | `meetings-list_events` → `meetings-list_event_invitees` → `meetings-create_invitee_no_show`, **confirm first** |
| "What working hours do I have set?" | `availability-list_user_availability_schedules` |
| "When am I busy next week?" | `availability-list_user_busy_times` |
| "Invite Emma to our Calendly team" | `organizations-create_organization_invitation`, **confirm first, need org URI** |
| "Show me this week's routing form leads" | `routing_forms-list_routing_forms` → `routing_forms-list_routing_form_submissions` *(Teams plan required)* |

---

## Error Handling (Phase 2)

When a Calendly tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Calendly sign-in has expired, let me reconnect you." | Walk Phase 1 from Step 3; Claude Code re-runs OAuth |
| 403 Forbidden / insufficient scope | "Your Calendly plan doesn't include that action, or your role on the team doesn't allow it." | No fix in the connector, user talks to their Calendly admin or upgrades plan (e.g. Teams for routing forms) |
| 404 Not Found (event / event type) | "I couldn't find that, let me list your events again." | Use `meetings-list_events` or `event_types-list_event_types` to refresh |
| 429 Rate limited | "Calendly is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once |
| 400 Invalid request | "The details I tried to send didn't match what Calendly expected, let me try again." | Re-fetch the event type / event UUID, retry once |
| MCP server not running | "The Calendly connection isn't active yet. Please close and reopen the chat so it picks up the new settings." | User closes and reopens Claude Code |
| Any other API error | "Something went wrong with Calendly, let me try again." | Retry once; if still failing, walk Phase 1 from Step 3 |

---

## Scope Limitations

The Calendly MCP connector **can** do (via the official Calendly MCP server):
- List and inspect event types, meetings, invitees, and availability
- Book meetings on behalf of the user via `meetings-create_invitee`
- Cancel scheduled events and manage no-show status
- Create one-time scheduling links (plain and customised)
- Create and update event types and availability schedules
- Manage organization memberships and invitations
- Read routing form submissions (Teams plan or higher)

The Calendly MCP connector **cannot** do (needs the Calendly UI or other tools):
- Change the user's Calendly account plan or billing settings
- Change two-factor authentication or security settings
- Set up webhooks. Calendly has a separate developer setup for that. If the user asks about webhooks, say: "This connector cannot set up webhooks. Calendly has a separate developer setup for that. Want me to walk you through it?" Then refer them to the Calendly developer docs.
- Configure payment integrations (Stripe / PayPal) attached to event types
- Access Calendly data for users outside the authenticated user's organization
- Export meeting data to CSV (use the Calendly UI)
- Manage multiple Calendly accounts simultaneously (one OAuth session per `~/.claude.json` entry)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, cancelling, booking, inviting, or marking a no-show**, summarise what you are about to do and wait for the user's OK before calling the tool. Cancelling a meeting notifies the invitee automatically.
- **Resolve UUIDs before writing**, Calendly objects are referenced by URIs / UUIDs (e.g. `https://api.calendly.com/event_types/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`). Before any `cancel_event`, `create_invitee`, `update_event_type`, `create_share`, etc., fetch the relevant list first unless you already have the URI from earlier in the conversation.
- **UUIDs are long strings**, always confirm the short name ("30-min Intro", "3pm Tuesday with Jane") back to the user rather than the raw UUID.
- **Time zones matter**, Calendly stores times in ISO 8601 with timezone offsets. When the user says "3pm tomorrow", resolve to their account's local time zone (fetch from `users-get_current_user`), and show times back to them in that zone.
- **Invitee data is sensitive**, invitees' names, emails, and their answers to booking questions are personal data. Never paste raw invitee answers into a public log or screenshot without checking with the user first. When summarising meetings, prefer counts and short quotes over full question/answer dumps.
- **Present data clearly**, format results as readable tables or summaries, not raw JSON. For "what's on my calendar this week?", group by day.
- **One step at a time**, do not dump all data at once. Summarise first ("You have 14 meetings this week across 3 event types; the busiest day is Thursday"), then offer to show detail.
- **Pagination**, default to 25 events unless the user asks for more. Offer to show more if there are additional pages.
- **Routing forms require Teams plan or higher**, if `routing_forms-*` calls return 403, tell the user plainly and suggest they check their plan rather than retrying.
- **Never log or echo credentials**, there are no tokens to leak (OAuth is handled by Claude Code and DCR means there's no client secret to manage), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **first-run-setup**: Source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **linear-connector**: Sibling hosted OAuth-only MCP connector with DCR, the canonical 6-step Playwright-driven install pattern this skill mirrors
- **jotform-connector**: Sibling hosted OAuth-only MCP connector, identical install pattern
- **monday-connector**: Sibling Playwright-driven autonomous connector, reference for snapshot-and-reason model
- **slack-connector**: Sibling Playwright-driven autonomous connector, reference for autonomous-install rules
- **google-workspace-connector**: Cross-reference Calendly meetings with the user's Google Calendar
- **email-composer**: Draft follow-ups tied to upcoming or cancelled Calendly bookings
- **n8n-workflow-patterns**: Build automations triggered by new Calendly bookings once the connector is live
- **playwright-skill**: The Playwright MCP browser is how this skill drives the Calendly consent flow
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Calendly auth or API errors
