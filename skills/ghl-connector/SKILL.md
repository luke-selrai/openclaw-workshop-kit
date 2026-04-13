---
name: ghl-connector
description: "Interact with GoHighLevel (GHL) through the official HighLevel MCP server. Use this skill when the user asks about GHL contacts, conversations, opportunities, pipelines, calendar, payments, blogs, email templates, or social posts, or says things like 'my GHL contacts', 'move this deal to Proposal Sent', 'today's bookings', 'search my GHL conversations', 'list my pipelines', or 'tag jane@example.com as VIP'. Handles reading and writing contacts, moving opportunities, reading calendar bookings, reading transactions and orders, managing blog posts, and scheduling social posts — all through `mcp__ghl__*` tools. Falls back to Playwright browser automation only for UI-only surfaces (sending SMS, visual workflow editor, campaign builder edits). For initial setup, guide the user through `docs/GHL-SETUP.md`."
allowed-tools: mcp__ghl__*,Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: CRM & Marketing
  tags:
    - ghl
    - gohighlevel
    - crm
    - contacts
    - pipelines
    - opportunities
    - calendar
    - campaigns
    - mcp
  pairs-with:
    - skill: systematic-debugging
      reason: Use for troubleshooting PIT/scope or MCP connection errors
    - skill: playwright-skill
      reason: Used only as a fallback for UI-only surfaces the official MCP server doesn't cover (SMS composer, visual workflow editor)
    - skill: xero-connector
      reason: Same pattern — MCP connector for an external SaaS
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
---

# GoHighLevel (GHL) Connector

## Overview

This skill uses the **official HighLevel MCP server** to read and write data in the user's GHL sub-account. The connector must already be configured in `~/.claude.json` before these tools work.

- **Endpoint:** `https://services.leadconnectorhq.com/mcp/`
- **Auth:** `Authorization: Bearer <PIT>` + `locationId: <sub-account-id>` headers
- **Transport:** HTTP MCP — no custom server, no source tree, no shell envvars
- **Tool surface:** 36 first-party tools covering Contacts, Conversations, Opportunities, Calendar, Payments, Locations, Blogs, Email templates, Social Media

> **Not set up yet?** Walk the user through `docs/GHL-SETUP.md` — it's four steps: create a Private Integration Token, copy the Location ID, add the `ghl` MCP server entry to `~/.claude.json`, then verify with a cheap tool call.

> **Fallback:** A small number of GHL surfaces are UI-only (sending SMS from the conversations view, editing the visual workflow builder, authoring full email campaigns). For those, and **only** those, fall back to [playwright-skill](../playwright-skill/SKILL.md). Never reach for Playwright when an `mcp__ghl__*` tool exists for the task.

---

## Prerequisites

Before using any GHL tools, confirm:

1. **MCP server is configured** — `~/.claude.json` has a `"ghl"` entry under `mcpServers` pointing at `https://services.leadconnectorhq.com/mcp/`
2. **PIT and locationId are set** — the entry has `Authorization` and `locationId` headers with real values (not placeholders)
3. **Scopes are granted** — the Private Integration the PIT was minted from has the scopes the user's task requires (see Error Handling below)

If any of these are missing, guide the user through `docs/GHL-SETUP.md`. Do not fall back to curl recipes or shell envvars — the MCP config is the only supported install path.

**MCP server entry (for reference — never paste the real PIT into the transcript):**

```json
{
  "mcpServers": {
    "ghl": {
      "url": "https://services.leadconnectorhq.com/mcp/",
      "headers": {
        "Authorization": "Bearer <PIT>",
        "locationId": "<sub-account-id>"
      }
    }
  }
}
```

---

## Available Tools

The HighLevel MCP server exposes **36 tools** grouped into nine resource areas. Exact tool names surface as `mcp__ghl__*` at runtime — use the descriptions below to pick the right one.

### Contacts (6 tools)

| Tool | Purpose |
|---|---|
| `get_contact` | Fetch a single contact by ID |
| `get_contacts` | List contacts in the sub-account with pagination |
| `create_contact` | Create a new contact |
| `update_contact` | Patch an existing contact |
| `upsert_contact` | Create or update in one call (matches on email/phone) |
| `get_all_tasks` | List tasks across contacts |

**Use when:** The user asks to find a person, create/update a lead, or look up their assigned tasks.

**Example:**
```
User: "Find jane@example.com and tag her as VIP"
→ mcp__ghl__upsert_contact  (matches Jane by email, returns contactId)
→ mcp__ghl__add_tags         (contactId, tags: ["VIP"])
→ "Found Jane Doe and tagged her as VIP."
```

### Contacts Management (2 tools)

| Tool | Purpose |
|---|---|
| `add_tags` | Add one or more tags to a contact |
| `remove_tags` | Remove one or more tags from a contact |

**Use when:** Segmenting, opting in/out of lists, or applying workflow entry tags.

### Conversations (3 tools)

| Tool | Purpose |
|---|---|
| `search_conversations` | Find conversations by contact, channel, or query |
| `get_messages` | Fetch the message history for a conversation |
| `send_message` | Send a new message (SMS/Email/GMB/etc.) into a conversation |

**Use when:** Reading conversation history or sending a reply. For outbound SMS where the user wants to review before sending, **draft via Playwright instead** (see Fallback section) so the Send click stays with the user.

### Opportunities & Pipelines (4 tools)

| Tool | Purpose |
|---|---|
| `get_pipelines` | List pipelines and their stages for the sub-account |
| `search_opportunities` | Find opportunities by pipeline, stage, status, or contact |
| `get_opportunity` | Fetch a single opportunity with full detail |
| `update_opportunity` | Move stages, change status (won/lost), or patch fields |

**Use when:** Looking at the sales pipeline, moving deals, marking won/lost, or searching by customer.

**Example:**
```
User: "Move the Acme Co deal to Proposal Sent"
→ mcp__ghl__get_pipelines          (find Proposal Sent stageId)
→ mcp__ghl__search_opportunities    (find Acme Co opportunityId)
→ Confirm source stage + target stage with the user
→ mcp__ghl__update_opportunity     (opportunityId, pipelineStageId)
```

### Calendar (2 tools)

| Tool | Purpose |
|---|---|
| `get_calendar_events` | List bookings for a calendar in a time range |
| `get_appointment_notes` | Read notes attached to an appointment |

**Use when:** "What's on the calendar tomorrow?", "Did anyone leave notes on the 3 PM discovery call?", etc.

> **Booking creation is not in the MCP surface.** If the user wants to create or cancel a booking, fall back to Playwright.

### Payments (2 tools)

| Tool | Purpose |
|---|---|
| `list_transactions` | List payments / transactions for the sub-account |
| `get_order` | Fetch a single order by ID |

**Use when:** "What did Jane pay last month?", "Show me the order for this contact."

### Locations & Fields (2 tools)

| Tool | Purpose |
|---|---|
| `get_location` | Fetch details of the connected sub-account (name, timezone, etc.) |
| `get_custom_fields` | List custom fields defined for contacts/opportunities |

**Use when:** Confirming which sub-account is connected (run at the start of a session), or discovering field IDs before an update.

### Blogs (7 tools)

| Tool | Purpose |
|---|---|
| `get_blogs_by_location` | List all blogs for the sub-account |
| `get_blog_posts_by_blog_id` | List posts inside a blog |
| `create_blog_post` | Create a new blog post |
| `update_blog_post` | Edit an existing blog post |
| `get_blog_authors` | List available authors |
| `get_blog_categories` | List blog categories |
| `check_blog_url_slug` | Validate a URL slug before publishing |

**Use when:** Drafting, publishing, or editing blog content inside GHL.

### Email Templates (2 tools)

| Tool | Purpose |
|---|---|
| `get_email_templates` | List available email templates |
| `create_email_template` | Create a new email template |

**Use when:** Authoring a template for campaigns. Note that **sending** a one-off email uses `send_message` under Conversations, not these tools.

### Social Media (6 tools)

| Tool | Purpose |
|---|---|
| `get_social_media_accounts` | List connected social accounts |
| `get_social_media_statistics` | Pull reach/engagement stats |
| `create_social_media_post` | Schedule or publish a post |
| `update_social_media_post` | Edit an existing post |
| `get_social_media_post` | Fetch one post |
| `get_social_media_posts` | List posts with filtering |

**Use when:** Scheduling content across the user's connected social channels.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "What GHL account am I on?" | `get_location` |
| "Find jane@example.com" | `get_contacts` or `upsert_contact` |
| "Add a new contact" | `create_contact` (or `upsert_contact` if you want idempotency) |
| "Tag this contact as VIP" | `add_tags` |
| "What are my pipelines?" | `get_pipelines` |
| "List opportunities in 'Proposal Sent'" | `search_opportunities` (filter by stage) |
| "Move Acme Co to 'Won'" | `get_pipelines` → `search_opportunities` → `update_opportunity` |
| "What's on the calendar tomorrow?" | `get_calendar_events` |
| "Show me recent conversations with Jane" | `search_conversations` → `get_messages` |
| "Send Jane a follow-up email" | `send_message` (type: Email) |
| "How much has Jane paid?" | `list_transactions` filtered by contact |
| "Draft a blog post titled …" | `create_blog_post` |
| "Schedule a LinkedIn post for Thursday" | `create_social_media_post` |

---

## Playwright Fallback (UI-only surfaces)

Use [playwright-skill](../playwright-skill/SKILL.md) **only** for the narrow set of operations the 36 MCP tools do not cover:

| Task | Why MCP doesn't cover it | Playwright approach |
|---|---|---|
| **Send an SMS** where the user wants to review before send | MCP's `send_message` sends immediately; there's no "draft and stop" primitive | Open the contact's conversation view, type the body, **leave the window for the user to click Send** — never auto-click |
| **Create or cancel a calendar booking** | MCP exposes read-only calendar tools | Open the calendar, book or cancel, confirm with the user first |
| **Edit the visual workflow builder** | Not in the API | Open the workflow, let the user edit live |
| **Full email campaign authoring** (builder UI) | MCP has `create_email_template` but not the full campaign builder | Open the campaign builder and hand control back |

**Rules for Playwright fallback:**
- Reuse the saved storage state at `~/.claude/state/ghl-storage.json`. If missing or expired (you land on the login page), run a one-time login script first.
- Write every Playwright script to `/tmp/ghl-*.js`, never inside the skill dir.
- Launch `headless: false` so the user can see (and take over) what's happening.
- **Never auto-click Send, Delete, or Cancel.** Draft the state and hand the browser to the user.
- If a selector fails, **stop and ask** — GHL's UI changes often; don't retry destructive clicks.

---

## Error Handling

When a GHL MCP tool call fails, diagnose and respond in plain English. Never show raw JSON errors or the PIT.

| Error | What to say | How to fix |
|---|---|---|
| 401 / "Unauthorized" | "Your GHL token is no longer valid. Let me help you reconnect." | Guide user to re-create the Private Integration Token in GHL and update `~/.claude.json` |
| 403 / "Insufficient scope" | "Your GHL token is missing a permission for this action." | Tell the user which resource (e.g. "opportunities") and ask them to re-create the PIT with that scope |
| 404 on a contactId/opportunityId | "I couldn't find that record in your sub-account." | Try `get_contacts` / `search_opportunities` with the user's hint instead |
| "Wrong location" / data from another sub-account | "Your locationId points to a different sub-account." | Update `locationId` in `~/.claude.json` — check Settings → Business Profile for the right value |
| 429 / rate limit | "GHL is rate-limiting me — I'll wait a few seconds and retry." | Wait 5s, retry once. On a mutating call, re-confirm with the user before retry. |
| MCP server unreachable | "I can't reach HighLevel right now." | Check `curl -I https://services.leadconnectorhq.com/mcp/`, retry in a minute |

---

## Scope Limitations

The GHL connector **can** (via MCP):
- Read and create/update contacts (`get_contacts`, `create_contact`, `update_contact`, `upsert_contact`, `get_contact`)
- Tag and untag contacts (`add_tags`, `remove_tags`)
- Read contact tasks (`get_all_tasks`)
- Read and update opportunities; read pipelines (`get_pipelines`, `search_opportunities`, `get_opportunity`, `update_opportunity`)
- Read calendar events and appointment notes
- Send messages (SMS/Email/etc.) via `send_message`, search conversations, read messages
- Read transactions and orders
- Manage blog posts (CRUD) and social media posts (CRUD)
- Create/list email templates
- Read the connected location and custom fields

The GHL connector **cannot** (needs Playwright fallback, or isn't exposed at all):
- Draft an SMS for user review before sending (send is immediate via MCP)
- Create or cancel a calendar booking
- Edit the visual workflow builder
- Author full email campaigns in the campaign builder
- Manage agency-wide settings (this skill operates at sub-account scope by default)
- Delete contacts or opportunities
- Create custom fields or manage forms/surveys
- Manage multiple sub-accounts simultaneously (one `locationId` per `~/.claude.json` entry)

---

## Behaviour Guidelines

- **Verify connection first** — at the start of a session that touches GHL, call `get_location` to confirm which sub-account is connected. Report the name back to the user before mutating anything.
- **Confirm before mutating** — always confirm with the user before creating or updating contacts, moving opportunities, sending messages, or publishing blog/social posts. Echo the contact's name, opportunity title, or post body back before the tool call.
- **Default to sub-account scope** — never attempt agency-wide changes without explicit user confirmation.
- **Send is immediate in MCP** — `send_message` goes out the moment it's called. If the user wants to "draft" or "review first," use the Playwright fallback, not `send_message`.
- **Never auto-click Send, Delete, or Cancel in the browser** — Playwright drafts the state; the user clicks.
- **One step at a time** — don't dump all results at once. Summarise counts first ("You have 12 opportunities in 'Proposal Sent'"), then offer to show details.
- **Mask PII when echoing** — when summarising contacts back in the transcript, partially mask phone numbers (`+61 400 *** 000`) and emails (`j***@example.com`) unless the user explicitly asks for the full value.
- **Token hygiene** — never echo `Authorization` or the PIT to the transcript, never write them to a file inside the project, never include them in a commit. The PIT lives in `~/.claude.json` only.
- **Selector failure in Playwright** → stop and ask the user. Never blind-retry a destructive click.
- **Wrong-location errors** → stop, report the locationId to the user, and ask them to confirm before you edit `~/.claude.json`.

---

## Related Skills

- **playwright-skill** — required fallback engine for UI-only surfaces (SMS review-before-send, calendar create/cancel, workflow builder)
- **xero-connector** — same MCP pattern for accounting
- **connector-recommender** — recommending which connectors to set up
- **systematic-debugging** — troubleshooting PIT scope or MCP connection errors
- **email-composer** — drafting campaign copy before pushing it into a GHL email template
- **n8n-workflow-patterns** — building GHL-triggered automations
