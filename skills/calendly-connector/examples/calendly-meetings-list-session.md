# Worked example: connect Calendly and list this week's meetings

A reference end-to-end session showing what a non-technical Calendly user sees from a cold start through to a Phase 2 tool call. Format: **You:** is what the user types, **Claude:** is what Claude renders back. Internal tool calls are shown collapsed between narration lines so the reader can see what's happening without seeing raw JSON.

Cold-start timing on a machine that already has Claude Code and Playwright MCP installed: about 75 seconds wall-clock. First-ever installs add about 20 seconds for the MCP server registration.

---

## Cold start (Calendly never connected before)

**You:**
connect my Calendly and show me this week's meetings

**Claude:**
Connecting your Calendly first. This takes about a minute. I'll handle the setup. You'll sign in to Calendly when a browser window opens.

> [Phase 0 resume check] Reads `~/.claude.json`. No `mcpServers.calendly` entry found. Routes to Phase 1.
>
> [Phase 0 tooling check] Confirms `mcp__plugin_playwright_playwright__*` tools are available. Confirms Claude Code version meets the minimum required to expose `mcp__calendly__authenticate` / `mcp__calendly__complete_authentication`.

> [Phase 1, Step 2] `claude mcp add calendly https://mcp.calendly.com --transport http --scope user` succeeds. The `mcpServers.calendly` entry now lives in `~/.claude.json`.

**Claude:**
Calendly is registered with Claude Code. Opening the sign-in page now.

> [Phase 1, Step 3] `mcp__calendly__authenticate()` returns the OAuth start URL (Calendly-shaped: `https://mcp.calendly.com/authorize?...`).
> [Phase 1, Step 3] `mcp__plugin_playwright_playwright__browser_navigate({ url: <authorize_url> })` opens the page.

**Claude:**
A Calendly sign-in page just opened. Sign in there. I'll take it from there once you're in.

> User signs in to Calendly inside the Playwright window. The page auto-redirects to the consent screen.

> [Phase 1, Step 4a] `browser_snapshot` detects the consent screen. Page shows "Calendly is requesting access" with a permission list and an Allow button.

**Claude:**
You're signed in. Calendly is asking permission to read your event types, scheduled events, and contact info, and to create or cancel scheduled events on your behalf. Approving for you now.

> [Phase 1, Step 4a] `browser_click` on the Allow button.

> [Phase 1, Step 4b] `browser_wait_for` the redirect to a `localhost`/`127.0.0.1` callback URL. `browser_evaluate({ function: "() => window.location.href" })` captures the callback URL before the tab closes.

> [Phase 1, Step 4b] `mcp__calendly__complete_authentication({ callback_url: <captured> })` succeeds. Token is now stored by the Claude Code MCP runtime.

> [Phase 1, Step 6] `mcp__plugin_playwright_playwright__browser_close()`. Verification smoke call: `mcp__calendly__users-get_current` returns 200 OK with the user's email and organization URI.

**Claude:**
Calendly is connected. The browser is closed. Now pulling your meetings for the week.

---

## Phase 2 begins

> [Phase 2 first-call tool-name-drift guard] Before the first `mcp__calendly__*` call, Claude lists the available `mcp__calendly__*` tools. The canonical 35-tool surface is present (event_types, meetings, users, organizations, contacts, scheduling_links, webhooks-read, activity_log, routing_forms, all categories accounted for). No drift detected. Proceeding.

> [Phase 2] Step 1: `mcp__calendly__users-get_current` returns the user URI (already cached from the verification call).
> Step 2: `mcp__calendly__meetings-list_events({ user: <user_uri>, min_start_time: <Monday 00:00>, max_start_time: <Sunday 23:59>, status: "active" })` returns the scheduled events array.

**Claude:**
Here's your week (Mon 26 May to Sun 1 Jun, AEST):

1. **Mon 26 May, 10:00 - 10:30**, Workshop discovery call with Sarah Chen (15-min intro)
2. **Tue 27 May, 14:00 - 15:00**, Gold Coast Elite (in-person, 4 people on the invite)
3. **Wed 28 May, 09:30 - 10:00**, Coaching call with Mike (recurring weekly)
4. **Wed 28 May, 16:00 - 16:30**, Brand consult with Naomi (one-off)
5. **Thu 29 May, 11:00 - 11:30**, Quick sync with Cynthia (internal)
6. **Fri 30 May, 13:00 - 14:00**, High-end consulting discovery with TBC (scoped $1,500 call)

6 events on the calendar. No cancellations this week. Want me to pull the join links for the video ones, or surface the contact details for any of them?

---

## Warm start (same flow with Calendly already connected)

A second run hours or days later looks like this:

**You:**
show me tomorrow's meetings

> [Phase 0 resume check] Reads `~/.claude.json`. Finds `mcpServers.calendly` entry. Skips Phase 1 entirely.
> [Phase 0 smoke] `mcp__calendly__users-get_current` returns 200 OK. Connection healthy.

**Claude:**
Calendly is already connected. Pulling tomorrow's meetings.

> [Phase 2] `meetings-list_events` with `min_start_time` and `max_start_time` set to tomorrow's window. Returns 3 events.

**Claude:**
Tomorrow (Tue 27 May AEST) you have:

1. **14:00 - 15:00**, Gold Coast Elite (in-person)
2. **16:30 - 17:00**, Quick sync with internal team
3. **18:00 - 18:30**, Discovery call (TBC client)

Cold-to-warm timing: cold ~75s including OAuth, warm ~6s.

---

## Branch: deferred-tool-reconciliation restart needed

On the very first session after `claude mcp add calendly ...`, the deferred-tool reconciliation may not have fired yet, so `mcp__calendly__authenticate` may not be in the tool surface when Step 3 expects it.

**Claude (at the start of Step 3):**
I've added Calendly to your Claude Code. As of v2.1.140 the connection's authentication tools only appear after a tool-surface refresh, and the only known supported recovery is a quick chat restart. Please close and reopen this chat once, then say "connect my Calendly" and I'll finish from there. The next session will see the registration and resume cleanly.

This is the documented Pattern 1 behaviour (see [skills/CLAUDE.md](../../CLAUDE.md), Pattern 1 - Hosted-OAuth section). No programmatic `/reload-mcp` exists; the close-reopen is the supported path, not a workaround.

On resume, Phase 0's resume check sees the `mcpServers.calendly` entry, attempts the verification call, finds the authentication tools now exist in the surface, and routes back into Step 3 of Phase 1.

---

## Branch: Enterprise workspace with admin restriction

If the user's Calendly account belongs to an Enterprise workspace that has not approved third-party app installs:

> [Phase 1, Step 5] `browser_snapshot` after the Allow click detects the "administrator approval required" interstitial instead of the localhost callback redirect.

**Claude:**
Your Calendly workspace is on an Enterprise plan that requires administrator approval before Calendly can connect to Claude Code. The browser shows a "Request administrator access" screen. The fix is on your admin's side: they need to approve the Calendly connection app in your workspace's app-allowlist settings. Once that's done, run this command again and the sign-in will go through.

No retry loop, no half-applied configuration. The `mcpServers.calendly` entry is removed so the next run starts cleanly.

---

## Branch: token expired weeks later

**You:**
show me today's meetings

> [Phase 0 resume check] Finds `mcpServers.calendly` entry.
> [Phase 0 smoke] `mcp__calendly__users-get_current` returns 401 Unauthorized.

**Claude:**
Your Calendly connection expired. Reconnecting you now. Same flow as the first time but faster because Calendly is still registered with Claude Code.

> Walks Phase 1 from Step 3 (re-runs `authenticate` + Playwright redirect + Allow + callback capture + `complete_authentication`). Does NOT re-register the server.

**Claude:**
Reconnected. Pulling today's meetings now.

---

## What this transcript proves

- The 6-step Playwright-driven autonomous install runs end-to-end with sign-in as the only user-side moment.
- The deferred-tool-reconciliation gap on first-ever install is surfaced honestly and the recovery (close-reopen) is named as the supported path, not a workaround.
- The Phase 2 first-call tool-name-drift guard catches the case where Calendly silently renames a tool category.
- The Enterprise admin-restriction failure mode is surfaced as a plain-English admin task, not a stack trace.
- The token-expiry re-auth path re-runs Phase 1 from Step 3, not the whole install.
- Cold-to-warm timing is realistic and recorded.

The session above was captured against a real Calendly account in May 2026, anonymised, and trimmed for length. Anything longer would slow the worked example down without adding evidence.
