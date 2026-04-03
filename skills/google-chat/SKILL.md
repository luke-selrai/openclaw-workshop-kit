---
name: google-chat
description: Send and read Google Chat messages, manage spaces, DMs, and group chats via the gws CLI.
---

# Google Chat Skill

Control Google Chat from Claude Code. Send messages, read conversations, list spaces, and manage team communication, all in natural language.

## How It Works

Uses the `gws` CLI (Google Workspace CLI) which wraps the Google Chat API with OAuth2 authentication.

## Quick Commands

### Send a message
```bash
# Shortcut (easiest)
gws chat +send --space "spaces/SPACE_ID" --text "Hello team!"

# Full API method
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{"text":"Your message here"}'
```

### Read messages from a space
```bash
gws chat spaces messages list \
  --params '{"parent":"spaces/SPACE_ID","pageSize":25,"orderBy":"createTime desc"}'
```

### List all spaces (groups, DMs, rooms)
```bash
gws chat spaces list
gws chat spaces list --format table
```

### Get space members
```bash
gws chat spaces members list --params '{"parent":"spaces/SPACE_ID"}'
```

## Your Spaces

Run `gws chat spaces list --format table` after setup and fill in your team spaces here:

| Space | ID | Type |
|-------|-----|------|
| _Fill in after running spaces list_ | | |

## Space Types

- **SPACE** - Named room (like a channel)
- **GROUP_CHAT** - Multi-person chat without a name
- **DIRECT_MESSAGE** - 1:1 DM

## Message Formatting

Google Chat supports basic formatting in messages:

```
*bold*
_italic_
~strikethrough~
`code`
```code block```
```

Links are auto-detected. For rich cards and advanced formatting, use the full API with `--json`.

## Common Operations

### Send to a specific space by name
1. Run `gws chat spaces list --format table` to find the space ID
2. Use `gws chat +send --space "spaces/SPACE_ID" --text "message"`

### Read recent messages
```bash
gws chat spaces messages list \
  --params '{"parent":"spaces/SPACE_ID","pageSize":10,"orderBy":"createTime desc"}'
```

### Reply in a thread
```bash
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{"text":"Reply text","thread":{"name":"spaces/SPACE_ID/threads/THREAD_ID"}}'
```

### Send a message with a card
```bash
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{
    "text": "Fallback text",
    "cardsV2": [{
      "cardId": "card1",
      "card": {
        "header": {"title": "Card Title"},
        "sections": [{
          "widgets": [{"textParagraph": {"text": "Card body"}}]
        }]
      }
    }]
  }'
```

## Output Formats

```bash
--format json    # Default, full API response
--format table   # Human-readable table
--format yaml    # YAML output
--format csv     # CSV output
```

## Pagination

For spaces or messages with many results:
```bash
# Auto-paginate (up to 10 pages)
gws chat spaces list --page-all

# Limit pages
gws chat spaces list --page-all --page-limit 5
```

## Troubleshooting

**"failed to decrypt token cache"**
```bash
rm ~/.config/gws/token_cache.json
gws auth login -s chat
```

**"Request had insufficient authentication scopes"**
You need Chat-specific scopes. Re-auth with:
```bash
gws auth login -s chat
```

**"PERMISSION_DENIED" on a space**
You can only access spaces you're a member of. Check with `gws chat spaces list`.

**No spaces showing up**
Make sure you're authed with a Google Workspace account (not a personal Gmail). Google Chat API requires Workspace.

## Prerequisites

- **Google Workspace account** (not personal Gmail)
- **gws CLI** installed: `npm install -g @googleworkspace/cli`
- **GCP project** with Chat API enabled
- **OAuth client** configured (see setup.sh)

## Safety Rules

1. **Don't spam spaces** - send messages only when explicitly asked
2. **Check the space ID** before sending - wrong space = message to wrong team
3. **Read before writing** - if unsure which space, list them first
4. **Never send to DMs without being asked** - only send to named spaces/rooms by default
