# Claude Code Permission Entries for GHL

Add these to your `~/.claude/settings.local.json` under `permissions.allow` to auto-approve GHL MCP tool calls:

```json
"mcp__ghl-official__emails_fetch-template",
"mcp__ghl-official__contacts_get-contacts",
"mcp__ghl-official__contacts_get-contact",
"mcp__ghl-official__contacts_create-contact",
"mcp__ghl-official__contacts_update-contact",
"mcp__ghl-official__contacts_upsert-contact",
"mcp__ghl-official__contacts_add-tags",
"mcp__ghl-official__contacts_remove-tags",
"mcp__ghl-official__contacts_get-all-tasks",
"mcp__ghl-official__calendars_get-calendar-events",
"mcp__ghl-official__calendars_get-appointment-notes",
"mcp__ghl-official__opportunities_search-opportunity",
"mcp__ghl-official__opportunities_get-opportunity",
"mcp__ghl-official__opportunities_update-opportunity",
"mcp__ghl-official__opportunities_get-pipelines",
"mcp__ghl-official__conversations_search-conversation",
"mcp__ghl-official__conversations_get-messages",
"mcp__ghl-official__conversations_send-a-new-message",
"mcp__ghl-official__social-media-posting_get-account",
"mcp__ghl-official__social-media-posting_get-posts",
"mcp__ghl-official__social-media-posting_get-post",
"mcp__ghl-official__social-media-posting_create-post",
"mcp__ghl-official__social-media-posting_edit-post",
"mcp__ghl-official__social-media-posting_get-social-media-statistics",
"mcp__ghl-official__emails_create-template",
"mcp__ghl-official__blogs_get-blog-post",
"mcp__ghl-official__blogs_create-blog-post",
"mcp__ghl-official__blogs_check-url-slug-exists",
"mcp__ghl-official__locations_get-location",
"mcp__ghl-official__locations_get-custom-fields",
"mcp__ghl-official__payments_get-order-by-id",
"mcp__ghl-official__payments_list-transactions"
```

## Playwright MCP permissions (for browser automation)

```json
"mcp__playwright__browser_navigate",
"mcp__playwright__browser_fill_form",
"mcp__playwright__browser_click",
"mcp__playwright__browser_snapshot",
"mcp__playwright__browser_wait_for",
"mcp__playwright__browser_tabs"
```
