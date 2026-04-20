---
name: calendly-connector
description: "Connect and operate Calendly via the official first-party Calendly MCP server (https://mcp.calendly.com). Use this skill when the user asks to set up Calendly, connect their scheduling account, or interact with event types, availability, meetings, or scheduling links. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__calendly__*, Bash, Read, Write, Edit
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
    - skill: email-composer
      reason: Draft follow-ups tied to upcoming or cancelled Calendly meetings
    - skill: google-workspace-connector
      reason: Cross-reference Calendly meetings against Google Calendar availability
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Calendly bookings
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Calendly auth or API errors
---

# Calendly Connector

## Overview

This skill lets you read and update a user's Calendly account on their behalf using the **official first-party Calendly MCP server** hosted at `https://mcp.calendly.com` (announced [March 2026](https://calendly.com/blog/mcp-server); docs at [developer.calendly.com/calendly-mcp-server](https://developer.calendly.com/calendly-mcp-server)). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Calendly. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Calendly is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__calendly__*` native tools to read and update Calendly data.

**Which phase to run** — Before any tool call, check whether the Calendly MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.calendly` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the OAuth session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **Calendly personal access tokens or API keys** — the Calendly MCP server uses OAuth 2.1 with Dynamic Client Registration (RFC 7591). Clients self-register at runtime; there is no pre-registered app, no client secret to copy, and no personal access token to paste. Do not ask the user for any key.
- **A self-hosted Calendly MCP server** — Calendly publishes the hosted endpoint at `https://mcp.calendly.com` as the only deployment. Self-hosting is not supported.
- **Direct Calendly REST API calls** — all reads and writes go through the MCP server, not direct HTTP calls to the Calendly Public API.
- **The "Calendly connector for Claude" Desktop entry** — that is a Claude Desktop feature, not available in Claude Code. In Code we wire the MCP URL directly per Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a small setting on your computer", "a sign-in window".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Calendly is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Calendly MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Calendly once in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Calendly, I am going to set up the connection on your computer, then ask you to sign in to Calendly once in your browser. The whole thing takes about a minute. Ready?"

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the calendly MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Calendly MCP server is **hosted only** — there is no local transport option. Use this exact entry:

```json
{
  "mcpServers": {
    "calendly": {
      "url": "https://mcp.calendly.com"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the calendly entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved the connection. Now I just need you to sign in to your Calendly once."

### Step 3 — Walk the user through the browser sign-in

The first time the Calendly MCP server is contacted, Claude Code will open a browser window asking the user to sign in to Calendly and approve the connection. You cannot do this for them — Calendly requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please close and reopen Claude Code so the new connection becomes active. Let me know when you're back."

2. When they confirm → "Now say to me: **'connect to my calendly now'**. A browser window will pop up asking you to sign in to Calendly. Tell me when you see it."

3. When they see the sign-in window → "Sign in with your Calendly email and password, then click **Allow** on the permission screen. Let me know when you're back here."
   - If the user already signed in to Calendly recently → "You may not need to type a password — Calendly might just show the **Allow** screen straight away. That's fine, just click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."

Common mistakes to look out for (and correct by re-asking):
- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Calendly account → "I think you might have signed in with a different email than you meant to. In your browser, sign out of Calendly, then tell me 'try again' and I'll re-trigger the sign-in."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Calendly correctly."

Call `mcp__calendly__users-get_current_user` (no arguments). If it returns the user's profile, the connection works. Move to the success message.

If the verification tool returns an error:
- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Calendly account doesn't have permission for that action. Your Calendly plan may not include it."
- `429 Rate limited` → "Calendly is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Calendly connection' and I will verify it."
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message:

> "All done! Your Calendly is now connected. You can ask me things like 'what meetings do I have this week?', 'show me my event types', or 'create a one-time booking link for a 30-minute intro call'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__calendly__*` MCP tools below to answer questions and make changes in Calendly. The hosted Calendly MCP server provides **35 first-party tools** covering scheduling, no-show management, routing forms, and user/organization management.

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
| `organizations-delete_organization_membership` | Remove a member | **Destructive — confirm twice** |
| `organizations-list_organization_invitations` | List pending invitations | User asks "who have I invited?" |
| `organizations-create_organization_invitation` | Invite a new user | **Confirm first** |
| `organizations-revoke_organization_invitation` | Revoke a pending invitation | **Confirm first** |

#### Event Types (meeting templates)

| Tool | Description | Use when |
|---|---|---|
| `event_types-list_event_types` | List the user's / org's event types | User asks "show me my booking links" |
| `event_types-get_event_type` | Retrieve one event type | Need details before updating or linking |
| `event_types-create_event_type` | Create a new event type | User asks for a new booking type — **confirm first** |
| `event_types-update_event_type` | Update an event type | User wants to rename, re-colour, or change settings — **confirm first** |
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
| `meetings-cancel_event` | Cancel a scheduled event | **Confirm first** — notifies the invitee automatically |
| `meetings-create_invitee` | Book a meeting on behalf of a user via the Scheduling API | User asks to book a specific client into a slot — **confirm first, show the slot & invitee before booking** |
| `meetings-list_event_invitees` | List invitees for a given event | User asks "who showed up to that meeting?" |
| `meetings-get_event_invitee` | Get details for one invitee | Need email / answers to booking questions |

#### No-Show Management

| Tool | Description | Use when |
|---|---|---|
| `meetings-create_invitee_no_show` | Mark an invitee as a no-show | **Confirm first** — they may see this reflected in analytics |
| `meetings-get_invitee_no_show` | Retrieve a no-show record | Checking whether someone has already been marked |
| `meetings-delete_invitee_no_show` | Remove a no-show mark (i.e. they actually did attend) | **Confirm first** |

#### Scheduling Links & Shares

| Tool | Description | Use when |
|---|---|---|
| `scheduling_links-create_single_use_scheduling_link` | Create a one-time booking link for an event type | User asks "send Jane a one-off link for a 30-min intro" |
| `shares-create_share` | Create a customised single-use link (with pre-filled questions, custom copy) | User wants a more personalised one-off link — **confirm first** |

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

> **Note:** Tool names are from the official Calendly supported-tools list. If a tool name does not resolve, list the available tools with the `mcp__calendly__` prefix to discover the current naming. Calendly may add or rename tools as the server evolves.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Calendly" / "Help me set up Calendly" | **Run Phase 1** |
| "What meetings do I have this week?" | `meetings-list_events` (filter by date range) |
| "Show me my booking links" / "List my event types" | `event_types-list_event_types` |
| "When am I free for a 30-min intro next week?" | `event_types-list_event_types` (find the 30-min one) → `event_types-list_event_type_available_times` |
| "Create a one-time booking link for a 30-min intro" | `event_types-list_event_types` → `scheduling_links-create_single_use_scheduling_link` |
| "Send Jane a personalised one-off link" | `event_types-list_event_types` → `shares-create_share` — **confirm first** |
| "Cancel my 3pm meeting tomorrow" | `meetings-list_events` (find it) → `meetings-cancel_event` — **confirm first** |
| "Book John Smith into my 30-min slot at 2pm Friday" | `event_types-list_event_types` → `meetings-create_invitee` — **confirm slot + invitee first** |
| "Who came to that strategy call on Tuesday?" | `meetings-list_events` → `meetings-list_event_invitees` |
| "Mark Sarah as a no-show for the 10am" | `meetings-list_events` → `meetings-list_event_invitees` → `meetings-create_invitee_no_show` — **confirm first** |
| "What working hours do I have set?" | `availability-list_user_availability_schedules` |
| "When am I busy next week?" | `availability-list_user_busy_times` |
| "Invite Emma to our Calendly team" | `organizations-create_organization_invitation` — **confirm first, need org URI** |
| "Show me this week's routing form leads" | `routing_forms-list_routing_forms` → `routing_forms-list_routing_form_submissions` *(Teams plan required)* |

---

## Error Handling (Phase 2)

When a Calendly tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Calendly sign-in has expired — let me reconnect you." | Re-trigger the OAuth flow (Phase 1, Step 3) |
| 403 Forbidden / insufficient scope | "Your Calendly plan doesn't include that action, or your role on the team doesn't allow it." | No fix in the connector — user talks to their Calendly admin or upgrades plan (e.g. Teams for routing forms) |
| 404 Not Found (event / event type) | "I couldn't find that — let me list your events again." | Use `meetings-list_events` or `event_types-list_event_types` to refresh |
| 429 Rate limited | "Calendly is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once |
| 400 Invalid request | "The details I tried to send didn't match what Calendly expected — let me try again." | Re-fetch the event type / event UUID, retry once |
| MCP server not running | "The Calendly connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with Calendly — let me try again." | Retry once; if still failing, re-do the sign-in |

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
- Configure webhooks (use the Calendly REST API directly)
- Configure payment integrations (Stripe / PayPal) attached to event types
- Access Calendly data for users outside the authenticated user's organization
- Export meeting data to CSV (use the Calendly UI)
- Manage multiple Calendly accounts simultaneously (one OAuth session per `~/.claude.json` entry)

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating, updating, cancelling, booking, inviting, or marking a no-show** — summarise what you are about to do and wait for the user's OK before calling the tool. Cancelling a meeting notifies the invitee automatically.
- **Resolve UUIDs before writing** — Calendly objects are referenced by URIs / UUIDs (e.g. `https://api.calendly.com/event_types/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`). Before any `cancel_event`, `create_invitee`, `update_event_type`, `create_share`, etc., fetch the relevant list first unless you already have the URI from earlier in the conversation.
- **UUIDs are long strings** — always confirm the short name ("30-min Intro", "3pm Tuesday with Jane") back to the user rather than the raw UUID.
- **Time zones matter** — Calendly stores times in ISO 8601 with timezone offsets. When the user says "3pm tomorrow", resolve to their account's local time zone (fetch from `users-get_current_user`), and show times back to them in that zone.
- **Invitee data is sensitive** — invitees' names, emails, and their answers to booking questions are personal data. Never paste raw invitee answers into a public log or screenshot without checking with the user first. When summarising meetings, prefer counts and short quotes over full question/answer dumps.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON. For "what's on my calendar this week?", group by day.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 14 meetings this week across 3 event types; the busiest day is Thursday"), then offer to show detail.
- **Pagination** — default to 25 events unless the user asks for more. Offer to show more if there are additional pages.
- **Routing forms require Teams plan or higher** — if `routing_forms-*` calls return 403, tell the user plainly and suggest they check their plan rather than retrying.
- **Never log or echo credentials** — there are no tokens to leak (OAuth is handled by Claude Code and DCR means there's no client secret to manage), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **jotform-connector**: Sibling hosted-MCP connector — same conversational install pattern, different platform
- **google-workspace-connector**: Cross-reference Calendly meetings with the user's Google Calendar
- **email-composer**: Draft follow-ups tied to upcoming or cancelled Calendly bookings
- **n8n-workflow-patterns**: Build automations triggered by new Calendly bookings once the connector is live
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Calendly auth or API errors
