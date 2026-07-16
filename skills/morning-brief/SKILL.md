---
name: morning-brief
description: Produce a daily start-of-day HTML email briefing and send it to your own inbox. Triages inbox noise (Hubstaff/GitHub/Notion/calendar invites/past briefs/generic noreply get labelled, marked read, archived), gathers today's calendar plus any new CRM contacts in the last 24h, classifies the remaining threads into Needs Action vs FYI, then composes and sends a clean HTML email to the connected Google account's own address. Trigger phrases include "morning brief", "morning briefing", "start of day report", "daily brief", "run my morning briefing".
---

# Morning Brief

This skill produces and sends a daily HTML morning brief covering today's calendar, any fresh CRM contacts from the last 24 hours, and a triage pass over the inbox that files noise out of sight and surfaces what actually matters. It sends the brief to your own connected mailbox.

## When to use this skill

Trigger any of:

- "morning brief", "morning briefing", "start of day report", "daily brief"
- Direct invocation via `/morning-brief`
- Any invocation prompt that asks for "the morning brief" or "Run the /morning-brief skill"

Output: an HTML email lands in your own inbox within ~30 seconds. The inbox is also visibly tidier - known noise (Hubstaff, GitHub, Notion, calendar invites, past briefs, generic noreply) has been labelled, marked read, and archived.

Recipient is your own connected mailbox (the Google account this assistant is signed into) - see Phase 0. Do not ask who to send to. Do not add CC/BCC.

## Run order

Four phases. Run them in order. Each content phase fails soft - if one fails, the brief still sends, that section is replaced with a single italic line noting the failure and the cause.

0. Identify the account (your own email + business name)
1. Triage inbox noise
2. Gather context (calendar + CRM contacts)
3. Compose and send HTML email

## Phase 0: Identify the account (run first)

This skill sends the brief to *you* - the owner of the connected mailbox. Determine that address once, here, and reuse it everywhere below (recipient, and the "your address" tests in the classification phase). Do not hardcode an address.

```
gws gmail users getProfile --params '{"userId":"me"}' --format json
```

Read `emailAddress` from the response - that is **your address** for the rest of this run. If the call fails, fall back to `gws auth status` (it prints the signed-in account); if you still cannot determine the address, stop and ask the user which of their email addresses to send to.

**Business name (optional):** if you already know the user's business name from memory, hold it as `business_name` for the email header/footer. If you do not know it, leave it unset - the renderer produces a clean brief without it. Do not interrupt the run to ask.

## Phase 1: Triage inbox noise

Find notification emails currently in the inbox, file each one (apply matching label, remove `INBOX`, remove `UNREAD`).

Six triage groups. Each has a label **name** (not a hardcoded ID - IDs differ per mailbox). Resolve names to IDs first, creating any that don't exist.

| # | Sender / subject pattern | Label name | Notes |
|---|---|---|---|
| 1 | Hubstaff notifications | `Hubstaff Notifications` | |
| 2 | GitHub bot emails | `GitHub Bot` | |
| 3 | Notion notifications (any sender at `notion.so` or `mail.notion.so`) | `Notion Notifications` | |
| 4 | Calendar invite subjects (`Accepted:`, `Invitation:`, `Cancelled event:`, `Declined:`) | `Calendar Notifications` | |
| 5 | Self-sent morning briefs (`from:me subject:"Morning Brief"`) | `Morning Briefs` | Recursive filing of past briefs |
| 6 | Generic noreply / promotional / DMARC / Gmail Promotions, Updates, Social categories | `Auto Notifications` | Catch-all, runs LAST. Aggressive - includes `no_reply` (underscore), `category:promotions`, `category:updates`, `category:social` |

### Resolve (or create) the triage labels first

Before any triage, list the mailbox's labels and build a name→id map:

```
gws gmail users labels list --params '{"userId":"me"}' --format json
```

For each label name in the table above, find the matching `id` in the response. For any name that does not exist yet, create it:

```
gws gmail users labels create --params '{"userId":"me"}' --json '{"name":"<LABEL NAME>","labelListVisibility":"labelShow","messageListVisibility":"show"}'
```

The create call returns the new label's `id`. Use the resolved IDs (looked up or freshly created) in the `batchModify` calls below. Never hardcode a `Label_...` id - they are mailbox-specific.

### Why the order matters

Groups 1-3 are explicit senders. Groups 4-5 are subject / self patterns. Group 6 is the catch-all for everything else with a `noreply`-shaped From. Run them **in numerical order** - each group's `batchModify` removes those messages from INBOX, so the next group's `label:INBOX` query naturally excludes already-filed items. No deduping needed.

### Search queries (in order)

Use `gws gmail users messages list` with Gmail's standard `q` search syntax. One call per group, scoped to inbox.

**Group 1 - Hubstaff:**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX from:hubstaff","maxResults":100}' --format json
```

**Group 2 - GitHub:**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX (from:noreply@github.com OR from:notifications@github.com)","maxResults":100}' --format json
```

**Group 3 - Notion (broader pattern):**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX (from:notion.so OR from:mail.notion.so)","maxResults":100}' --format json
```

**Group 4 - Calendar invites:**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX (subject:\"Accepted:\" OR subject:\"Invitation:\" OR subject:\"Cancelled event:\" OR subject:\"Declined:\" OR subject:\"Tentatively accepted:\")","maxResults":100}' --format json
```

**Group 5 - Self-sent morning briefs:**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX from:me (subject:\"Morning Brief\" OR subject:\"Morning Briefing\" OR subject:Briefing)","maxResults":100}' --format json
```
The `subject:Briefing` term catches future variants without needing exact-phrase tokenisation. Gmail's quoted phrase search is token-boundary-strict so `"Morning Brief"` does NOT match `Morning Briefing` - keep both terms in the OR. `from:me` resolves to the connected account, so this works in any mailbox.

**Group 6 - Generic noreply, Promotions, Updates, Social (catch-all, aggressive):**
```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX (from:noreply OR from:no-reply OR from:no_reply OR from:notifications@ OR from:dmarc OR from:make.com OR category:promotions OR category:updates OR category:social)","maxResults":200}' --format json
```

Parse each response's JSON. Collect message IDs per group.

If a query returns zero matches, skip the `batchModify` for that group - do not call the API with an empty `ids` array.

### Capture inbox-size stat before triage

Before running any batchModify, capture the **pre-triage inbox count** with a large `maxResults` and use `len(messages)`:

```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX","maxResults":500}' --format json
```

Use `len(d["messages"])` - **do not trust `resultSizeEstimate`**. Gmail's estimate is stale for INBOX queries and can stay at the pre-mutation value for minutes after a batchModify. The actual paginated count is reliable. If the response has a `nextPageToken`, page through and sum (rare for typical inboxes).

### File each group

For each non-empty group, one batchModify call. Use the label ID you resolved (or created) for that group's name:

```
gws gmail users messages batchModify --params '{"userId":"me"}' --json '{"ids":[<message ids>],"addLabelIds":["<RESOLVED_LABEL_ID>"],"removeLabelIds":["INBOX","UNREAD"]}'
```

`batchModify` returns an empty 204 response on success. Count the IDs you submitted - that's the per-group file count. Sum across groups for the total-filed count.

### Capture inbox-size stat after triage

Same approach - large `maxResults` and `len()`:

```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX","maxResults":500}' --format json
```

Save the post-triage count via `len(d["messages"])`. The difference confirms how many were filed (should equal the sum of the per-group filed counts).

### What does NOT get touched

- Anything not matching one of the sender/subject patterns above (real humans + anything ambiguous → leave in inbox)
- Anything already out of the inbox (search is scoped to `label:INBOX`)
- Newsletters and promotions are only filed by the aggressive Group 6 catch-all; anything else stays

If you want to extend triage in the future, add more groups in the table above. Do not introduce conditional logic for individual emails - keep it pattern-based.

## Phase 2: Gather context

### Today's calendar

```
gws calendar +agenda --today --format json
```

Returns a JSON object with shape `{"count": N, "events": [...], "timeMax": "...", "timeMin": "..."}`. The `events` array entries each have `summary`, `start`, `end`, `location`, `calendar`. Times come back as ISO 8601 with timezone offset (e.g. `2026-05-25T10:00:00+10:00`). For the email, render each event as `HH:MM - HH:MM · <summary>` in local time. If `location` is non-empty AND not a URL, append ` · <location>`. If it's a meeting URL (starts with `http`), drop it - clutter.

If `events` is empty, render a single italic line: `Nothing scheduled today.`

### New CRM contacts in last 24h (optional - only if GoHighLevel is connected)

If the user has the GoHighLevel (GHL) connector set up, include new contacts from the last 24 hours. If GHL is not connected, skip this section entirely (the brief still sends; the renderer simply omits an empty contacts list).

Use the `mcp__ghl__contacts_get-contacts` MCP tool. Location ID is set in the MCP server's headers - no `query_locationId` argument needed on the call.

Call:

```
mcp__ghl__contacts_get-contacts(query_limit=100)
```

**Response envelope - parse carefully.** The MCP wraps the GHL payload in an outer object:

```json
{
  "success": true,
  "status": 200,
  "data": {
    "contacts": [...],
    "meta": {...}
  },
  "mcp_trace_id": "...",
  "tool": {...}
}
```

Read contacts from `response["data"]["contacts"]` - **NOT** from `response["contacts"]`. Top-level `success` / `status` are MCP envelope fields, not GHL fields. If you read the wrong path you get an empty list back even when there are dozens of new contacts.

Results come back sorted by `dateAdded` descending (newest first). Filter client-side: keep entries where `dateAdded` (ISO 8601 UTC) is within the last 24 hours of `now`.

For each kept contact, capture: `contactName` (or `firstNameRaw lastNameRaw` if `contactName` empty), `email`, `phone`, `source`, `tags` (joined with comma), `dateAdded` (rendered as "Xh ago" in local time).

If zero contacts in last 24h, render italic: `No new contacts in the last 24 hours.`

### Remaining-inbox summary

After Phase 1's triage, list **everything** still in the inbox - no cap.

```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX","maxResults":500}' --format json
```

If a `nextPageToken` is returned, page through and concatenate. Don't truncate.

For each message ID, fetch headers **and snippet** (not full body - snippet is enough for triage):

```
gws gmail users messages get --params '{"userId":"me","id":"<MSG_ID>","format":"metadata","metadataHeaders":["From","To","Cc","Subject","Date"]}' --format json
```

The response includes a top-level `snippet` field - Gmail's auto-generated preview (~150 chars). Capture: From, To, Cc, Subject, Date, snippet.

Hold these in memory - Phase 2.5 classifies them.

## Phase 2.5: Thread-aware classification (the priority pass)

Email is a thread game, not a message game. A single thread can have 12 inbox messages - you don't want 12 line items, you want ONE entry that reflects the current state of the conversation. Group by thread, look at the latest message, then classify.

Throughout this phase, **"your address"** means the `emailAddress` you determined in Phase 0 - the owner of this mailbox.

### Step 1 - Dedupe by thread

After Phase 1's triage, list everything still in the inbox (`messages.list` returns individual messages, often multiple per thread):

```
gws gmail users messages list --params '{"userId":"me","q":"label:INBOX","maxResults":500}' --format json
```

Each result has both `id` and `threadId`. **Group by `threadId`** - keep one entry per unique thread.

### Step 2 - Fetch each thread, find the latest message

For each unique thread, fetch the full thread (with metadata headers + snippet):

```
gws gmail users threads get --params '{"userId":"me","id":"<THREAD_ID>","format":"metadata","metadataHeaders":["From","To","Cc","Subject","Date"]}' --format json
```

The response is `{messages: [...]}`. Sort by `internalDate` descending - `messages[0]` is the latest. Capture:

- `latest.from` - display name + address of the sender
- `latest.to` - the To: header (raw, may have multiple addresses)
- `latest.cc` - the Cc: header
- `latest.subject`
- `latest.date`
- `latest.snippet`
- `len(messages)` (thread size - useful for context badge)
- **Derive `recipient`**: parse the `To:` header, drop your own address, take the first remaining recipient's display name (fall back to the local-part of the email if no display name). If multiple non-self recipients remain, append ` +N` (e.g. `Brendan +2`). If everyone in To: is you or empty, leave `recipient` as `null`. This is what the FYI section uses to render `sender → recipient` lines like `Mike → Brendan` - the missing context that turns a sender name into a situation.

### Step 3 - Classify each thread into one of three buckets

Apply these rules in order, top-down. First match wins.

**HIDDEN** - drop from the brief entirely:
- Latest message's `From:` is your own address → **you replied last, ball is in their court, nothing to do**
- OR you are in neither `To:` nor `Cc:` of the latest message → **stale thread you're no longer addressed on**

These are NOT shown in the FYI list. Just counted for the "stale threads hidden" footer.

**FYI** - show in compact list, no snippet, just sender/subject/ago:
- Latest message `From:` is an auto-alias (`noreply`, `no-reply`, `no_reply`, `support@`, `info@`, `team@`, `hello@`, `notifications@`, `dmarc`, `sales@`, `admin@`, `accounting@`) - even if you are in To. These are SaaS check-ins, billing, marketing that escaped Phase 1
- OR you are in `Cc:` only (CC = informational copy)
- OR you are in `To:` but the snippet shows no clear ask (FYI confirmations, "thanks", thread closers, status updates)

**NEEDS ACTION** - show in full (sender, subject, snippet, ago):
- You are in `To:` (not just Cc)
- Latest sender is a real human (not an auto-alias per the list above)
- Snippet OR subject signals an open ask: question mark, "please", "can/could/would you", "let me know", "review", "approve", "follow up", "looking forward", "available?", "confirm", "thoughts on", "to ask", "had a question", "wanted to ask", or active negotiation language

Lean toward FYI when borderline. Better to under-promote than to flood the action list.

### Sort within each bucket

- **NEEDS ACTION**: most recent first (newest asks at the top)
- **FYI**: most recent first

### What the brief shows

- **NEEDS ACTION section**: full detail per item (sender, subject, snippet, ago, optional thread-size badge if size > 1). If the list is empty, render line `All clear. Nothing waiting on you right now.`
- **FYI section**: compact rows (sender + ago + subject, no snippet). Tighter than Needs Action so it doesn't overwhelm.
- **Hidden tally**: small grey callout at the bottom of the FYI section: `N stale threads hidden (you replied last, or no longer addressed).`

Do not show hidden items individually. They exist only as a count.

## Phase 3: Compose and send HTML email

### Email envelope

- To: your own address (from Phase 0)
- Subject: `Morning Briefing - YYYY-MM-DD` (date in local time)
- Body: HTML (use `--html` flag)
- Sender: account default (omit `--from`)

### Render via the helper script - MANDATORY

The HTML body **must** come from the Python helper at `scripts/render_brief.py` inside this skill. Do NOT generate the email HTML inline. Do NOT recreate the layout from memory. The helper is the single source of truth for the email's visual structure.

```
python3 scripts/render_brief.py < /tmp/brief-data.json > /tmp/morning-brief-body.html
```

If `python3` isn't available or the script errors, **STOP** and report the failure in the chat reply. Do not fall back to inline HTML generation - that path produces the wrong output (re-adds elements that were intentionally removed from the renderer).

The JSON input has this shape:

```json
{
  "business_name": "Acme Co",
  "long_date": "MONDAY, 25 MAY 2026",
  "calendar_events": [{"start": "ISO", "end": "ISO", "summary": "...", "location": "..."}],
  "calendar_error": null,
  "contacts": [{"name":"...","email":"...","phone":"...","source":"...","tags":"...","ago":"3h ago"}],
  "contacts_error": null,
  "needs_action": [{"sender":"...","recipient":null,"subject":"...","snippet":"one-line summary","ago":"2h ago","thread_size":3}],
  "fyi": [{"sender":"Mike Briones","recipient":"Brendan +2","subject":"Re: project update","ago":"6d ago","thread_size":5}],
  "hidden_count": 6,
  "inbox_error": null,
  "triage": {"pre": 81, "post": 67, "filed_total": 14, "per_group": {"calendar": 14, "noreply": 6, "morning-briefs": 4}}
}
```

- `business_name` is optional - set it if you know the user's business from memory, otherwise omit it (the renderer produces a clean brief without it).
- If a section's data fetch failed, set `<section>_error` to a short reason string. The renderer handles the italic "Could not load - <reason>" line.
- `needs_action` items have a snippet shown in the brief
- `fyi` items show sender + subject + ago + optional thread-size badge (no snippet)
- `hidden_count` is the number of threads where you replied last OR are no longer addressed; shown as a small "N stale threads hidden" footer

### Branding

The renderer owns the look - a clean, neutral layout (Helvetica, a single accent colour, white cards on a light page). Do NOT edit the colours or inject a logo. If `business_name` is provided, the renderer shows it as a small header eyebrow and a footer line; that is the only personalisation. There is no external brand file to read.

### Layout (what the rendered email looks like)

1. **Outer page** - light grey background, generous padding.
2. **White card** - max-width 680 px, centred, 1 px border, 12 px rounded corners, 32 px padding.
3. **Header** - optional business-name eyebrow (only if `business_name` is set), then the `Morning Briefing` title, then the date breadcrumb in the accent colour. No logo.
4. **Section cards** in this order - each a nested white card:
   - `TODAY'S CALENDAR`
   - `NEEDS ACTION · <N>`
   - `FYI · <N> TO BE ACROSS`
5. **Triage callout** - rounded box with the stat line in bold inline numerics.
6. **NEW CONTACTS · LAST 24H** - after the triage block (less prominent; new leads are useful but rarely action-critical).
7. **Sign-off** - "Have a good one, / Your morning briefing agent".
8. **Footer** - outside the card, small grey text: the business name if provided, otherwise nothing.

**Triage stat line (always rendered):**

`Triaged <PRE_COUNT> emails - filed <FILED_TOTAL> as noise (<filed-per-group breakdown>) - <POST_COUNT> remain for your attention.`

Example: `Triaged 201 emails - filed 38 as noise (1 Hubstaff · 3 Calendar · 34 noreply) - 163 remain for your attention.`

Only include groups with non-zero counts in the breakdown. Drop the empty ones.

### Send

```
gws gmail +send \
  --to "<your own address>" \
  --subject "Morning Briefing - YYYY-MM-DD" \
  --body "<HTML BODY>" \
  --html
```

Bash quoting: write the HTML body to a temp file (`/tmp/morning-brief-body.html`) and pass it inline via `--body "$(cat /tmp/morning-brief-body.html)"`. Trying to inline 2KB of HTML with shell escaping is a footgun - use the temp file.

After send, the +send response includes the message ID. Report it back to the user in the chat reply along with the triage stat line.

## End-of-run report (assistant-to-user, not in the email)

After everything completes, respond in chat with a single short paragraph:

```
Morning brief sent (msgId: <ID>). Triaged <N> emails - filed <X> as noise (<breakdown>) - <Y> remain in inbox.
```

If any phase failed, mention the failure here too. No long retros.

## Failure modes - handle these explicitly

- **gws CLI not authed**: call `gws auth status` first; if it errors and a `GOOGLE_WORKSPACE_CLI_CREDENTIALS_JSON` env var is set, write it to `~/.config/gws/credentials.json`, export `GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND=file`, retry. If Gmail/Calendar still can't be reached, you cannot determine the recipient or triage - stop and tell the user their Google account needs reconnecting. (This typically only matters in isolated execution contexts where the local keychain isn't reachable.)
- **GHL not connected or unavailable**: skip the contacts section, brief still ships.
- **Calendar empty**: not a failure - italic "Nothing scheduled today."
- **Inbox empty after triage**: not a failure - italic "Inbox clear - no follow-ups needed."
- **`batchModify` returns 200/204 but `resultSizeEstimate` shows the inbox unchanged**: Gmail's `resultSizeEstimate` lags behind actual mutations - sometimes by minutes. The skill already uses `len(messages)` instead of the estimate, which IS reliable. If you ever see `resultSizeEstimate` numbers that don't match, ignore them.
- **Gmail's `from:hubstaff` style queries occasionally miss messages that match the full email address**: index inconsistency. The 6-group order means anything missed by an explicit group gets caught by the generic noreply catch-all (Group 6), so it still ends up filed.

## Things not to do

- Do not summarise email *bodies* - just sender + subject + time. Bodies are slow to fetch and add noise.
- Do not auto-reply, auto-archive, or auto-task-create from real human emails. The skill triages noise only.
- Do not modify CRM contacts (no tag changes, no DND toggles). Read-only against GHL.
- Do not write to Notion. Email is the only output surface.
- Do not change the recipient. Always send to your own connected mailbox (the address from Phase 0).
- Do not include the day of week as a separator, emoji, or decoration in the email. Plain, tight, scannable.
