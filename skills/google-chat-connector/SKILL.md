---
name: google-chat-connector
description: Install and operate the Google Chat connector. Use this skill when the user asks to set up Google Chat, connect their Google Workspace chat, send or read messages, manage spaces, post to team rooms, or interact with group chats and DMs. Handles full installation and uses the Google Workspace CLI (`gws`) with OAuth2. Falls back to Playwright for UI-only surfaces.
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - google-chat
    - gchat
    - google-workspace
    - messaging
    - team-communication
    - spaces
    - installer
  pairs-with:
    - skill: email-composer
      reason: Draft message content with email-composer, then post it to a Google Chat space
    - skill: gcloud-connector
      reason: Use when the user needs to set up the underlying GCP project and enable the Chat API
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
    - skill: playwright-skill
      reason: Fallback for UI-only surfaces (space settings, managing webhooks, card interactions)
---

# Google Chat Connector

## Overview

This skill does two things:
1. **Installs** the Google Workspace CLI (`gws`) on the user's computer (one-time setup)
2. **Operates** the connector, sending messages, reading conversations, listing spaces, managing team communication via the Google Chat API

The connector uses the **Google Workspace CLI** (`@googleworkspace/cli`, invoked as `gws`) which wraps the Google Chat REST API with OAuth2 authentication. One tool, one auth flow, covers Chat, Gmail, Calendar, and Drive.

> **Account support:** Requires a **Google Workspace** account (work/school domain).
> Personal Gmail accounts (`@gmail.com`) are NOT supported, the Google Chat API is a Workspace-only feature.
> If the user has a personal account, tell them this upfront and stop, do not waste time on setup that will fail at the end.

---

## Part 1, Installation

Guide conversationally, one step at a time.

### Step 1: Confirm account type

Ask the user:
> "Is your Google account a work/school Workspace account (like `you@company.com`), or a personal Gmail account?"

If personal Gmail → stop and explain this won't work. Suggest Telegram, WhatsApp, or Slack instead.

### Step 2: Check if already installed

```bash
gws --version
```

If this returns a version number, skip to Step 5 (auth check). If "command not found", continue from Step 3.

### Step 3: Check Node.js

```bash
node --version
```

Needs v18 or higher. If missing or too old, tell the user to install from https://nodejs.org (LTS version) before continuing.

### Step 4: Install the CLI

```bash
npm install -g @googleworkspace/cli
```

After install, refresh PATH so the command is available immediately:

**Mac/Linux:**
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```

**Windows (Command Prompt):**
```bat
for /f "tokens=*" %i in ('npm prefix -g') do set PATH=%i\bin;%PATH%
```

Verify:
```bash
gws --version
```

If the install fails with a permission error on macOS/Linux, try `sudo npm install -g @googleworkspace/cli`.

### Step 5: Set up the GCP project + OAuth client

The Chat API needs a GCP project with OAuth credentials. There are three paths, pick one based on what the user has.

**Path A, Teammate already set it up (fastest):**
If someone on the user's team already configured this, ask them for their `client_secret.json` file. It is safe to share within an org, it identifies the OAuth app, not any individual's login.

Save the file to:
```
~/.config/gws/client_secret.json
```

Then skip to Step 6.

**Path B, Automated (user has `gcloud` CLI authenticated):**
```bash
gws auth setup --login
```

This creates the GCP project, enables the Chat/Gmail/Calendar/Drive APIs, configures OAuth, and authenticates in one shot. If the user doesn't have `gcloud`, either install it via [gcloud-connector](../gcloud-connector/SKILL.md) first, or use Path C.

**Path C, Manual:**
1. Go to https://console.cloud.google.com
2. Create a new project (or use an existing one)
3. Enable these APIs: **Google Chat API**, Gmail API, Google Calendar API, Google Drive API
4. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**
5. If prompted, configure the OAuth consent screen (choose **Internal** if inside a Workspace org)
6. Application type: **Desktop app** → name it → **Create**
7. Click **Download JSON** on the credential you just made
8. Save it as `~/.config/gws/client_secret.json`

### Step 6: Authenticate

```bash
gws auth login -s chat,gmail,calendar,drive
```

A browser window opens. The user signs in with their Google **Workspace** account and approves the scopes. Wait for the success message before proceeding.

### Step 7: Verify auth

```bash
gws auth status
```

Look for `"token_valid": true`. Then do a cheap API call to confirm the Chat API actually works:

```bash
gws chat spaces list --format table
```

If this returns a list of spaces (even an empty one), installation is complete. Continue to Part 2.

---

## Part 2, Operation

Once installed, use these commands to read and write Google Chat data.

### Listing spaces

```bash
# Default JSON output
gws chat spaces list

# Human-readable table
gws chat spaces list --format table

# Paginate through all spaces (up to 10 pages by default)
gws chat spaces list --page-all
gws chat spaces list --page-all --page-limit 5
```

**Space types** returned:
- `SPACE`, named room/channel
- `GROUP_CHAT`, multi-person chat without a name
- `DIRECT_MESSAGE`, 1:1 DM

### Sending a message

**Shortcut form (preferred):**
```bash
gws chat +send --space "spaces/SPACE_ID" --text "Deploy finished — all green."
```

**Full API form (for threads, cards, attachments):**
```bash
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{"text":"Your message here"}'
```

### Reading messages

```bash
gws chat spaces messages list \
  --params '{"parent":"spaces/SPACE_ID","pageSize":25,"orderBy":"createTime desc"}'
```

### Replying in a thread

```bash
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{
    "text":"Reply text",
    "thread":{"name":"spaces/SPACE_ID/threads/THREAD_ID"}
  }'
```

### Listing space members

```bash
gws chat spaces members list --params '{"parent":"spaces/SPACE_ID"}'
```

### Sending a rich card message

```bash
gws chat spaces messages create \
  --params '{"parent":"spaces/SPACE_ID"}' \
  --json '{
    "text": "Fallback text for notifications",
    "cardsV2": [{
      "cardId": "deploy-status",
      "card": {
        "header": {"title": "Production Deploy", "subtitle": "v2.4.1"},
        "sections": [{
          "widgets": [
            {"textParagraph": {"text": "All services healthy."}},
            {"decoratedText": {"text": "Build time: 4m 12s"}}
          ]
        }]
      }
    }]
  }'
```

### Message formatting

Google Chat supports inline formatting in message text:

```
*bold*
_italic_
~strikethrough~
`inline code`
```code block```
```

URLs are auto-linked. For anything richer than basic formatting (buttons, images, decorated widgets), use `cardsV2` via the full API.

### Output formats

```bash
--format json    # Default, full API response
--format table   # Human-readable table
--format yaml    # YAML
--format csv     # CSV
```

Use `--format table` when showing data to the user. Use `--format json` when parsing programmatically.

---

## Part 3 — Mapping the User's Spaces

The first time the user runs this skill, their space IDs are unknown. Run this once and update this skill file with their team's spaces so future sends don't need a lookup:

```bash
gws chat spaces list --format table
```

Then edit the **Your Spaces** table below with the results:

### Your Spaces

| Space Name | ID | Type |
|---|---|---|
| _Fill in after running `gws chat spaces list`_ | | |

When the user says "send a message to the Dev Team", look up the ID in this table first. If the name isn't there, list spaces again and fuzzy-match — then add the new row so the lookup works next time.

---

## Part 4 — Safety Rules

1. **Read before writing.** If you're unsure which space the user means, list spaces and confirm the match before sending. Sending to the wrong space is a visible, embarrassing error.
2. **Never send to DMs without explicit instruction.** Default to named spaces/rooms only. A message to `DIRECT_MESSAGE` is personal — don't send one unless the user explicitly names the recipient and intent.
3. **Don't spam.** Send a message only when the user explicitly asks for it. Don't send confirmation pings, status updates, or "I'm done" messages on your own initiative.
4. **Show the user the message before sending** for anything non-trivial (more than a one-line notification), so they can catch mistakes before it's broadcast.
5. **Thread replies stay in-thread.** If the user is responding to a thread, always include the `thread` parameter — a missing thread ID creates a new top-level message, which fragments the conversation.
6. **Never paste OAuth tokens into the transcript.** Tokens live in `~/.config/gws/` and should stay there.

---

## Part 5 — Error Handling

**`failed to decrypt token cache`**
The local token cache is corrupted. Fix:
```bash
rm ~/.config/gws/token_cache.json
gws auth login -s chat,gmail,calendar,drive
```

**`PERMISSION_DENIED` or `insufficient authentication scopes`**
The OAuth grant is missing the Chat scope. Re-auth with the full scope list:
```bash
gws auth login -s chat,gmail,calendar,drive
```

**`PERMISSION_DENIED` on a specific space**
The user is not a member of that space. `gws chat` can only operate on spaces the authenticated user has joined. Ask the user to join the space in the Google Chat UI first.

**`No spaces returned` (empty list, no error)**
Either (a) the user has no spaces, or (b) they're signed in with a personal Gmail account. Check `gws auth status` — if the email ends in `@gmail.com`, this is the issue and cannot be fixed without switching accounts.

**`gws: command not found` after install**
PATH didn't pick up the global npm bin. Either restart the terminal, or run:
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```

**`429 Too Many Requests`**
Chat API quotas are per-minute and per-user. Wait 60 seconds and retry. If this is recurring, batch messages instead of sending one per loop iteration.

**User needs to switch Google accounts**
```bash
gws auth logout
gws auth login -s chat,gmail,calendar,drive
```

---

## Part 6 — Playwright Fallback

Use Playwright **only** when there is no `gws chat` command for the task. The Chat API covers messaging and space listing well, but some surfaces are UI-only:

- **Creating a new space** (can only be done from the Google Chat web/mobile UI as a user)
- **Editing space settings, descriptions, or guidelines**
- **Managing space apps and webhooks** through the admin UI
- **Interacting with message card buttons** (the API sends cards, but clicking buttons is a user action)

For these, use [playwright-skill](../playwright-skill/SKILL.md) to drive `https://chat.google.com` directly. Never reach for Playwright when a `gws chat` command exists for the same task — the CLI is faster, cheaper, and doesn't break when the UI changes.

---

## When to Use This Skill

Activate when the user says things like:
- "Send a message to the Dev Team saying standup is cancelled"
- "Read the latest messages in the Workshop R&D chat"
- "List my Google Chat spaces"
- "Who's in the Leadership team chat?"
- "Reply in the thread about the deploy"
- "Post a card to the #announcements room when the build finishes"
- "Set up Google Chat"
- "Connect my Workspace chat"

For initial setup, run this skill's Part 1 (Installation) in order.
