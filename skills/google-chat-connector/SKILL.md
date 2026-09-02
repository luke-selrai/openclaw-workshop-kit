---
name: google-chat-connector
description: "Connect Google Chat to Claude by running the Google Workspace connector's interview with Chat switched on. Use when the user asks to set up or connect Google Chat or their Workspace chat, or wants Chat work (messages, spaces, team rooms, DMs) and Chat isn't connected yet. Once connected, Chat runs through the `mcp__claude_ai_Google_Chat__*` tools or the `gws` CLI, and this skill is the day-to-day reference for it."
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*,mcp__claude_ai_Google_Chat__*
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
    - skill: google-workspace-connector
      reason: Owns the Google connect flow; Chat connects through its interview
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

## Connecting: go to google-workspace-connector

Google Chat is not connected from here. It connects through
[google-workspace-connector](../google-workspace-connector/SKILL.md), which runs
one short interview about what the user wants Claude to do with their Google
account and switches on only the pieces they name — Chat among them.

**To connect Chat:** run `google-workspace-connector`, answer "yes" when it asks
whether the team uses Google Chat, and it will do the rest.

**Chat rides the `gws` route.** There is no built-in Google Chat connector — Chat
is not in Claude's connector directory. It connects through the `gws` tool, using
the same Google Cloud project that ladder already creates, with `chat` added to
the sign-in scopes. The same sign-in covers Gmail, Calendar and Drive.

**One exception to look for.** A machine may already carry a custom Google Chat
connector someone added by hand — it shows in `claude mcp list` as
`claude.ai Google Chat`, and its tools are `mcp__claude_ai_Google_Chat__*`:
listing and searching messages, searching conversations, and sending a message.
If Phase 0 of `google-workspace-connector` finds one already connected, use it
for reading, searching and sending, and `gws` for everything else. Neither skill
sets one up: it needs the same Google Cloud work as `gws` plus a hand-pasted
address, so it buys nothing over `gws`.

**Where the setup facts moved.** The install ladder that used to live in this
file — checking Node, installing `@googleworkspace/cli`, the PATH refresh, the
three Google Cloud project paths (teammate's `client_secret.json`,
`gws auth setup --login`, the manual console walk), the sign-in scope list with
`chat` in it, and the `gws auth status` / `gws chat spaces list` verification —
is now Phase 1-alt of `google-workspace-connector`, so it is written once instead
of twice. The Workspace-account requirement below is repeated here because it
decides whether it is worth starting at all.

> **Account support:** Requires a **Google Workspace** account (work/school domain).
> Personal Gmail accounts (`@gmail.com`) are NOT supported - the Google Chat API is a Workspace-only feature.
> If the user has a personal account, tell them this upfront and stop - do not waste time on setup that will fail at the end.
> Suggest Telegram, WhatsApp, or Slack instead.

**Everything below is the day-to-day reference**, for once Chat is connected.

---

## Part 2 - Operation

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
- `SPACE` - named room/channel
- `GROUP_CHAT` - multi-person chat without a name
- `DIRECT_MESSAGE` - 1:1 DM

### Sending a message

**Shortcut form (preferred):**
```bash
gws chat +send --space "spaces/SPACE_ID" --text "Deploy finished - all green."
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
--format json    # Default - full API response
--format table   # Human-readable table
--format yaml    # YAML
--format csv     # CSV
```

Use `--format table` when showing data to the user. Use `--format json` when parsing programmatically.

### If a custom Chat connector is already on the machine

Some machines carry a hand-added Google Chat connector (`claude.ai Google Chat`
in `claude mcp list`). Its tools sit under `mcp__claude_ai_Google_Chat__*` and
cover listing and searching messages, searching conversations, and sending a
message. Use it for those. Everything above that it does not cover — spaces and
member listings, threaded replies, `cardsV2`, the output formats — is a `gws`
job, and needs the `gws` route from `google-workspace-connector` Phase 1-alt.
The safety rules in Part 4 apply to both routes.

---

## Part 3 - Mapping the User's Spaces

The first time the user runs this skill, their space IDs are unknown. Run this once and update this skill file with their team's spaces so future sends don't need a lookup:

```bash
gws chat spaces list --format table
```

Then edit the **Your Spaces** table below with the results:

### Your Spaces

| Space Name | ID | Type |
|---|---|---|
| _Fill in after running `gws chat spaces list`_ | | |

When the user says "send a message to the Dev Team", look up the ID in this table first. If the name isn't there, list spaces again and fuzzy-match - then add the new row so the lookup works next time.

---

## Part 4 - Safety Rules

1. **Read before writing.** If you're unsure which space the user means, list spaces and confirm the match before sending. Sending to the wrong space is a visible, embarrassing error.
2. **Never send to DMs without explicit instruction.** Default to named spaces/rooms only. A message to `DIRECT_MESSAGE` is personal - don't send one unless the user explicitly names the recipient and intent.
3. **Don't spam.** Send a message only when the user explicitly asks for it. Don't send confirmation pings, status updates, or "I'm done" messages on your own initiative.
4. **Show the user the message before sending** for anything non-trivial (more than a one-line notification), so they can catch mistakes before it's broadcast.
5. **Thread replies stay in-thread.** If the user is responding to a thread, always include the `thread` parameter - a missing thread ID creates a new top-level message, which fragments the conversation.
6. **Never paste OAuth tokens into the transcript.** Tokens live in `~/.config/gws/` and should stay there. The built-in route handles no credentials at all.

---

## Part 5 - Error Handling

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
Either (a) the user has no spaces, or (b) they're signed in with a personal Gmail account. Check `gws auth status` - if the email ends in `@gmail.com`, this is the issue and cannot be fixed without switching accounts.

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

**No `claude.ai Google Chat` line in `claude mcp list`**
Expected, not a fault — there is no built-in Chat connector, so most machines will not have that line. Chat comes through `gws`; check `gws auth status` and the `chat` scope instead.

---

## Part 6 - Playwright Fallback

Use Playwright **only** when there is no `gws chat` command and no built-in Chat tool for the task. Messaging and space listing are well covered, but some surfaces are UI-only:

- **Creating a new space** (can only be done from the Google Chat web/mobile UI as a user)
- **Editing space settings, descriptions, or guidelines**
- **Managing space apps and webhooks** through the admin UI
- **Interacting with message card buttons** (the API sends cards, but clicking buttons is a user action)

For these, use [playwright-skill](../playwright-skill/SKILL.md) to drive `https://chat.google.com` directly. Never reach for Playwright when a `gws chat` command exists for the same task - the CLI is faster, cheaper, and doesn't break when the UI changes. This is an operating fallback, not a sign-in path: never drive a Google sign-in with Playwright.

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

For the last two - initial setup - hand over to
[google-workspace-connector](../google-workspace-connector/SKILL.md) and say yes
to Chat when it asks.
