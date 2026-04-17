---
name: jotform-connector
description: "Connect and operate Jotform via the official first-party Jotform MCP server (https://mcp.jotform.com). Use this skill when the user asks to set up Jotform, connect their account, or interact with forms, submissions, or assignments. On first use, run Phase 1 to install and authenticate the connector before attempting any tool calls."
allowed-tools: mcp__jotform__*, Bash, Read, Write, Edit
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
    - skill: email-composer
      reason: Draft follow-ups based on Jotform submission data
    - skill: n8n-workflow-patterns
      reason: Build automations triggered by new Jotform submissions
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Jotform auth or API errors
---

# Jotform Connector

## Overview

This skill lets you read and update a user's Jotform account on their behalf using the **official first-party Jotform MCP server** hosted at `https://mcp.jotform.com` (see [jotform/mcp-server](https://github.com/jotform/mcp-server)). It has two phases:

- **Phase 1 — Install & Auth.** A conversational bootstrap (≤4 steps). The user has never used this before. You wire the hosted MCP server into Claude Code and walk the user through a one-click browser sign-in to Jotform. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "OAuth", or any file paths. They should feel like they are having a conversation, and at the end their Jotform is connected.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__jotform__*` native tools to read and update Jotform data.

**Which phase to run** — Before any tool call, check whether the Jotform MCP server is already configured. Read `~/.claude.json` (or `%USERPROFILE%\.claude.json` on Windows) and look for an `mcpServers.jotform` entry. If it exists, treat the connector as configured and skip to Phase 2 (verify with a tool call before assuming the OAuth session is still valid). Otherwise, run Phase 1.

### What this skill does NOT use

- **Jotform API keys** — Jotform MCP **requires OAuth for every user on first connect**. Bearer-token / API-key access to the MCP server is not supported. Do not ask the user for an API key.
- **A self-hosted Jotform MCP server** — Jotform publishes the hosted endpoint at `https://mcp.jotform.com` as the primary deployment. Always use the hosted URL.
- **Direct Jotform REST API calls** — all reads and writes go through the MCP server, not direct HTTP calls.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, REST, or environment variable. If you must refer to a technical thing, name it plainly: "a small setting on your computer", "a sign-in window".
- **Tell them what is about to happen.** Before any action you take: "I am going to save your connection details now — this takes just a moment."
- **React to success and failure warmly.** Good: "That worked — your Jotform is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (≤4 steps)

This phase wires the hosted Jotform MCP server into Claude Code and walks the user through the one-time browser sign-in. You do every technical action; the user only signs in to Jotform once in their browser.

### Step 1 — Orient the user

Tell the user in one short message:

> "To connect your Jotform, I am going to set up the connection on your computer, then ask you to sign in to Jotform once in your browser. The whole thing takes about a minute. Ready?"

### Step 2 — Save the connection

Once the user says they're ready, silently add or update the jotform MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The Jotform MCP server is **hosted only** — there is no local transport option. Use this exact entry:

```json
{
  "mcpServers": {
    "jotform": {
      "url": "https://mcp.jotform.com"
    }
  }
}
```

Merge into the existing `mcpServers` object rather than overwriting it. If `~/.claude.json` does not exist, create it with just the jotform entry. If the file exists but is corrupted, back it up to `~/.claude.json.backup` first, then write a fresh config.

Tell the user: "I have saved the connection. Now I just need you to sign in to your Jotform once."

### Step 3 — Walk the user through the browser sign-in

The first time the Jotform MCP server is contacted, Claude Code will open a browser window asking the user to sign in to Jotform and approve the connection. You cannot do this for them — Jotform requires their authenticated session.

Tell the user (one instruction at a time, waiting for confirmation between each):

1. "Please close and reopen Claude Code so the new connection becomes active. Let me know when you're back."

2. When they confirm → "Now say to me: **'connect to my jotform now'**. A browser window will pop up asking you to sign in to Jotform. Tell me when you see it."

3. When they see the sign-in window → "Sign in with your Jotform email and password, then click **Allow** on the permission screen. Let me know when you're back here."
   - If the user already signed in to Jotform recently → "You may not need to type a password — Jotform might just show the **Allow** screen straight away. That's fine, just click **Allow**."
   - If the user can't see the browser window → "Check behind your other windows — sometimes it opens in the background. If you really can't find it, tell me and I'll try again."

Common mistakes to look out for (and correct by re-asking):
- The user closes the browser window without clicking **Allow** → "No problem — let me try once more. I'll trigger the sign-in again, just click **Allow** when it pops up this time."
- The user signs in to the wrong Jotform account → "I think you might have signed in with a different email than you meant to. In your browser, sign out of Jotform, then tell me 'try again' and I'll re-trigger the sign-in."
- The user reports a "this site can't be reached" page → "Sounds like a network hiccup. Is your internet working? Once you confirm, I'll try once more."

When the user confirms they clicked **Allow**, immediately move to Step 4.

### Step 4 — Verify the connection

Tell the user: "Let me just check that everything is talking to Jotform correctly."

Call `mcp__jotform__list_forms` with a small page size (e.g. 1 form). If it returns a result (including an empty list — that's fine), the connection works. Move to the success message.

If the verification tool returns an error:
- `401 Unauthorized` / `Not authenticated` → "The sign-in didn't quite stick. Let me trigger it once more for you." Re-do Step 3.
- `403 Forbidden` → "Your connection is working, but your Jotform user doesn't have permission for that action. An admin on your Jotform team may need to adjust your access."
- `429 Rate limited` → "Jotform is asking us to slow down for a moment — let me try again in a few seconds." Wait 10s, retry.
- Tools not available in current session → "I have saved everything. Please restart Claude Code once so the connection becomes active, then say 'test my Jotform connection' and I will verify it."
- Any other error → "Something went wrong — let me try again." Retry once; if still failing, ask the user to re-do the sign-in (Step 3).

### Step 5 — Success message

Tell the user, in one short message:

> "All done! Your Jotform is now connected. You can ask me things like 'show me my forms', 'how many submissions did the contact form get this week?', or 'create a new feedback form'. Give it a try!"

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__jotform__*` MCP tools below to answer questions and make changes in Jotform. The hosted Jotform MCP server provides **6 first-party tools** covering forms, submissions, and assignments.

### Tool Reference

The official MCP server exposes tools with the prefix `mcp__jotform__`. Verified against [jotform/mcp-server](https://github.com/jotform/mcp-server).

#### Forms

| Tool | Description | Use when |
|---|---|---|
| `list_forms` | Retrieve all forms in the user's Jotform account | User asks "show me my forms", or you need a form ID before another call |
| `create_form` | Build a new form | User asks to create an intake/feedback/registration form — **confirm first** |
| `edit_form` | Modify an existing form (fields, settings, title) | User asks to change a form — **confirm first** |
| `assign_form` | Delegate (assign) a form to another user | User asks to share a form with a teammate — **confirm first** |

#### Submissions

| Tool | Description | Use when |
|---|---|---|
| `get_submissions` | Fetch submissions (entries) for a form | User asks "how many people filled out X", "show me the latest responses", or wants to read entries |
| `create_submission` | Add an entry to a form programmatically | User asks to log a response on behalf of someone, e.g. importing data — **confirm first** |

> **Note:** Tool names are from the official `jotform/mcp-server` (latest). If a tool name does not resolve, try listing available tools with the `mcp__jotform__` prefix to discover the current naming.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Jotform" / "Help me set up Jotform" | **Run Phase 1** |
| "Show me my forms" | `list_forms` |
| "How many submissions did the contact form get this week?" | `list_forms` (find form ID) → `get_submissions` (filter by date) |
| "Show me the latest 10 responses on the feedback form" | `list_forms` → `get_submissions` (limit 10) |
| "Create a new feedback form" | `create_form` — **confirm first, summarise fields before creating** |
| "Add a phone number field to my contact form" | `list_forms` → `edit_form` — **confirm first** |
| "Rename the 'Q1 survey' form to 'Q2 survey'" | `list_forms` → `edit_form` — **confirm first** |
| "Share my intake form with Jane" | `list_forms` → `assign_form` — **confirm first** |
| "Log a test entry on my contact form" | `list_forms` → `create_submission` — **confirm first** |
| "Import these 50 leads into my Jotform" | `list_forms` → loop `create_submission` — **confirm first, in batches** |

---

## Error Handling (Phase 2)

When a Jotform tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized / Not authenticated | "Your Jotform sign-in has expired — let me reconnect you." | Re-trigger the OAuth flow (Phase 1, Step 3) |
| 403 Forbidden | "Your Jotform user doesn't have permission for that form. The form owner may need to share it with you." | User talks to the form owner; nothing to fix in the connector |
| 404 Not Found (form / submission) | "I couldn't find that record — let me list your forms again." | Use `list_forms` to refresh the list |
| 429 Rate limited | "Jotform is asking me to slow down. I will wait a moment and try again." | Wait 10 seconds and retry once. Free tier is 60 requests/minute; Enterprise is 600/min. |
| MCP server not running | "The Jotform connection isn't active yet. Please restart Claude Code so it picks up the new settings." | User restarts Claude Code |
| Any other API error | "Something went wrong with Jotform — let me try again." | Retry once; if still failing, re-do the sign-in |

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

- **Always confirm before creating, editing, assigning, or submitting** — summarise what you are about to do and wait for the user's OK before calling the tool.
- **Discover form IDs before writing** — Jotform forms are referenced by numeric IDs. Always call `list_forms` once per session before any `edit_form`, `assign_form`, `get_submissions`, or `create_submission`, unless you already have the ID from earlier in the conversation.
- **IDs are numeric strings** — form and submission IDs are long numeric strings. Always confirm them back before a mutation.
- **Submissions are sensitive data** — they often contain personal information (names, emails, phone numbers, free-text feedback). Never paste full submission contents into a public log or chat without checking with the user first. When summarising, prefer counts and aggregates over raw quotes unless asked.
- **Present data clearly** — format results as readable tables or summaries, not raw JSON.
- **One step at a time** — do not dump all data at once. Summarise first ("You have 12 forms; the busiest is 'Contact Us' with 142 submissions this month"), then offer to show details.
- **Pagination** — default to 25 submissions unless the user asks for more. Offer to show more if there are additional pages.
- **Respect the rate limit** — Free tier is 60 requests/minute; Enterprise is 600/min. For bulk imports, batch `create_submission` calls and pause between batches.
- **Importing leads is irreversible** — `create_submission` writes a real entry. For bulk imports, always show the user a sample of the first row before proceeding with the rest.
- **Never log or echo credentials** — there is no token to leak (OAuth is handled by Claude Code), but never echo the contents of `~/.claude.json` or any sign-in URLs to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Jotform auth or API errors
- **monday-connector**: Sibling project/data connector — same MCP bootstrap pattern for a different platform
- **notion-connector**: Sibling workspace connector — similar conversational install
- **n8n-workflow-patterns**: Build Jotform-triggered automations once the connector is live
