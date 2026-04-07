---
name: ghl-crm
description: GoHighLevel CRM management. Contacts, pipelines, calendars, messaging, workflows.
---

# GoHighLevel CRM Skill

You are managing GoHighLevel CRM for [YOUR BUSINESS NAME].

## Access Methods (Use in This Priority Order)

### 1. GHL MCP Servers (Preferred for Mac-side Claude Code)
Two cloud MCP servers are connected: `ghl-official` and `ghl-community`.
- Use ToolSearch to find and load GHL tools: `+ghl contacts`, `+ghl opportunities`, etc.
- ghl-official: ~25 high-quality tools (contacts, opps, conversations, calendars, social, blogs, emails, payments)
- ghl-community: 300+ tools covering virtually every GHL endpoint

### 2. Bash Helper Script (Mac-side)
```bash
~/.claude/projects/<your-project>/scripts/ghl <command> [args...]
```
Credentials in `~/.claude/projects/<your-project>/secrets/ghl.env`

## Location Details
- **Location ID**: `<YOUR_LOCATION_ID>` (from your GHL URL)
- **Business**: [YOUR BUSINESS NAME]
- **Timezone**: [YOUR_TIMEZONE] (e.g., Australia/Brisbane, America/New_York)
- **Contacts**: [YOUR COUNT]
- **Pipelines**: [YOUR COUNT]

## API Quirks (CRITICAL — Memorize These)

### Email Sending
GHL Email API requires `html` field, NOT `message`. Always use:
```json
{
  "type": "Email",
  "contactId": "<id>",
  "html": "<p>Your email body here</p>",
  "subject": "Subject line",
  "emailFrom": "Your Name from Your Business",
  "userId": "<ghl-user-id>"
}
```
SMS uses `message` field. Email uses `html` field. Mixing these up causes 422 errors.

### Parameter Naming
- Request parameters: `snake_case` (e.g., `location_id`, `pipeline_id`, `contact_id`)
- Response body: `camelCase` (e.g., `locationId`, `pipelineId`, `contactId`)
- Always use snake_case when sending, expect camelCase back.

### User-Agent Header
GHL/Cloudflare blocks default Python User-Agent. Set a custom one like `YourBusiness-GHL/2.0.0`.

### Rate Limits
- 429 responses: exponential backoff (2s, 4s, 8s)
- 5xx responses: retry up to 3 times
- Bulk operations: add 0.5s delay between calls

### Conversation Search
The `/conversations/search` endpoint can return 404 in some cases. Use `ghl conversations` (bash helper) as fallback.

### Tags
- `add_contact_tags`: POST to `/contacts/{id}/tags` with `{"tags": ["tag1", "tag2"]}`
- `remove_contact_tags`: DELETE to `/contacts/{id}/tags` with `{"tags": ["tag1"]}` in body
- Tags are strings, not IDs

## Pipelines & Stages

**IMPORTANT**: Run `ghl pipelines` to populate this section with YOUR pipeline and stage IDs.

Example format:
```
### Pipeline: Sales (`<PIPELINE_ID>`)
| Stage | ID |
|---|---|
| New Lead | `<stage-uuid>` |
| Qualified | `<stage-uuid>` |
| Proposal Sent | `<stage-uuid>` |
| Won | `<stage-uuid>` |
| Lost | `<stage-uuid>` |
```

Paste your pipeline/stage data here after running the command.

## MCP Server Notes

### ghl-official (~25 tools) — Recommended
All tools auto-inject OAuth. Use `ToolSearch: +ghl <keyword>` to find tools.
Covers: contacts, opportunities, pipelines, conversations, calendars, social-media-posting, emails, blogs, payments, locations/custom-fields.

### ghl-community (300+ tools) — Requires Manual Auth
Community server does NOT auto-inject auth headers. You may need to pass authorization manually.
**If you get 401 errors**: Use ghl-official tools or the bash helper instead.

## Key User IDs
| User | ID |
|---|---|
| [Your Name] | `<YOUR_USER_ID>` (run `ghl users` to find this) |

## Connected Social Media Accounts

Run `mcp__ghl-official__social-media-posting_get-account` to populate this table with your accounts.

| Platform | Account | Profile ID | Type | Expires |
|---|---|---|---|---|
| _Fill in after running get-account_ | | | | |

**Post Groups:**
Set up post groups in GHL Social Planner to post to multiple platforms at once.

**Social Media MCP Operations (ghl-official):**
```
# Get connected accounts
mcp__ghl-official__social-media-posting_get-account

# Get posts (filter by type: all/published/scheduled/draft/failed)
mcp__ghl-official__social-media-posting_get-posts

# Create a post
mcp__ghl-official__social-media-posting_create-post

# Edit a post
mcp__ghl-official__social-media-posting_edit-post

# Get analytics (pass profileIds array)
mcp__ghl-official__social-media-posting_get-social-media-statistics
```

## Email Templates
- Use `mcp__ghl-official__emails_fetch-template` to list/search your templates
- Use `mcp__ghl-official__emails_create-template` to create new ones

## Safety Rules

1. **NEVER delete contacts without explicit approval**
2. **NEVER send bulk SMS/Email without approval** — individual messages OK for agent follow-ups
3. **NEVER modify pipeline structure** (stages, names, order)
4. **Always check for existing opportunity** before creating a new one for a contact
5. **Always tag contacts** when performing actions (e.g., "ai-contacted", "inbound-lead")

## Common Operations

### Search for a contact
```bash
# Bash helper
ghl search-contacts "John Smith"

# MCP
# Use ToolSearch: +ghl contacts, then call contacts_get-contacts
```

### Move opportunity to next stage
```bash
ghl move-opp <oppId> <stageId>
```

### Send SMS
```bash
ghl send-sms <contactId> "Your message"
```

### Send Email
```bash
ghl send-email <contactId> "Subject" "<p>HTML body</p>"
```

### Book appointment
```bash
# Check availability first
ghl calendar-slots <calendarId> 2026-03-11 2026-03-15

# Then book
ghl create-appointment '{"calendarId":"xxx","contactId":"xxx","startTime":"2026-03-12T09:00:00+10:00","endTime":"2026-03-12T09:30:00+10:00","title":"Discovery Call"}'
```

### Read conversation history
```bash
ghl get-messages <conversationId> 50
```

### Add/read notes
```bash
ghl add-note <contactId> '{"body":"Note content here"}'
ghl get-notes <contactId>
```

## Discovery Call Calendar
- **Calendar ID**: `<YOUR_CALENDAR_ID>` (run `ghl calendars` to find this)
- Always check free slots before booking
- Timezone: [YOUR_TIMEZONE]

## Complete ghl-official MCP Tool Reference

All tools below auto-inject OAuth. Load with `ToolSearch: select:mcp__ghl-official__<tool_name>`.

### Contacts
| Tool | What It Does |
|---|---|
| `contacts_get-contacts` | List/search contacts (paginated) |
| `contacts_get-contact` | Get single contact by ID |
| `contacts_create-contact` | Create new contact |
| `contacts_update-contact` | Update contact fields |
| `contacts_upsert-contact` | Create or update (dedup by email/phone) |
| `contacts_add-tags` | Add tags (appends, doesn't overwrite) |
| `contacts_remove-tags` | Remove tags from contact |
| `contacts_get-all-tasks` | Get tasks for a contact |

### Opportunities
| Tool | What It Does |
|---|---|
| `opportunities_search-opportunity` | Search/filter opportunities |
| `opportunities_get-opportunity` | Get single opportunity |
| `opportunities_update-opportunity` | Update opp (stage, value, status) |
| `opportunities_get-pipelines` | List all pipelines + stages |

### Conversations & Messaging
| Tool | What It Does |
|---|---|
| `conversations_search-conversation` | Search convos (filter by status/type/contact) |
| `conversations_get-messages` | Get messages in a conversation |
| `conversations_send-a-new-message` | Send SMS/Email/WhatsApp/IG/FB/Live_Chat |

**Send message params:**
- SMS: `body_type: "SMS"`, `body_contactId`, `body_message`
- Email: `body_type: "Email"`, `body_contactId`, `body_html`, `body_subject`, `body_emailFrom`
- WhatsApp/IG/FB: `body_type: "<TYPE>"`, `body_contactId`, `body_message`

### Social Media
| Tool | What It Does |
|---|---|
| `social-media-posting_get-account` | Get all connected accounts |
| `social-media-posting_get-posts` | List posts (filter: all/published/draft/scheduled/failed) |
| `social-media-posting_get-post` | Get single post by ID |
| `social-media-posting_create-post` | Create post (draft/scheduled/published) |
| `social-media-posting_edit-post` | Edit existing post |
| `social-media-posting_get-social-media-statistics` | Analytics (7-day with comparison) |

### Calendars
| Tool | What It Does |
|---|---|
| `calendars_get-calendar-events` | Get events (needs calendarId + startTime + endTime) |
| `calendars_get-appointment-notes` | Get notes for an appointment |

### Emails
| Tool | What It Does |
|---|---|
| `emails_fetch-template` | List/search email templates |
| `emails_create-template` | Create new email template |

### Blogs
| Tool | What It Does |
|---|---|
| `blogs_get-blog-post` | Get blog posts |
| `blogs_get-all-categories-by-location` | Get blog categories |
| `blogs_get-all-blog-authors-by-location` | Get blog authors |
| `blogs_create-blog-post` | Create blog post (DRAFT/PUBLISHED/SCHEDULED) |
| `blogs_check-url-slug-exists` | Validate URL slug availability |

### Location & Settings
| Tool | What It Does |
|---|---|
| `locations_get-location` | Get location details |
| `locations_get-custom-fields` | Get custom fields (contact/opportunity/all) |

### Payments
| Tool | What It Does |
|---|---|
| `payments_get-order-by-id` | Get order details |
| `payments_list-transactions` | List transactions |

## Browser Automation (UI-Only Operations)
For anything the API can't do (pipeline stages, workflow config, social re-auth, form builder):
**See `~/.claude/skills/ghl-browser/SKILL.md`** — the single source of truth for all browser + GHL interaction.

## Social Auth Notes
- Social media connections expire periodically (typically every 60-90 days)
- Re-auth via GHL Social Planner settings, or use Playwright browser automation
- Check `mcp__ghl-official__social-media-posting_get-account` for current auth status
