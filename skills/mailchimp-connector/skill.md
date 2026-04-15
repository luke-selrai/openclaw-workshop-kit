---
name: mailchimp-connector
description: "Connect the user's Mailchimp account to Claude Code so they can manage email marketing campaigns, audiences, subscribers, automations, and reports — all through conversation. Use this skill when the user says 'connect my Mailchimp', 'set up Mailchimp', 'manage my email campaigns', 'add a subscriber', 'create a campaign', 'show my audience', 'check my open rates', or asks about Mailchimp lists, segments, tags, or automations. On first use, run Phase 1 to register the MCP server before attempting any tool calls."
allowed-tools: mcp__mailchimp__*, Bash, Read, Write, Edit
metadata:
  category: Email Marketing
  tags:
    - mailchimp
    - email
    - campaigns
    - audience
    - subscribers
    - automations
    - mcp
  pairs-with:
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
    - skill: systematic-debugging
      reason: Use for troubleshooting API key or MCP connection errors
    - skill: ghl-connector
      reason: Same pattern — MCP connector for an external SaaS platform
---

# Mailchimp Connector

## Overview

This skill connects Claude Code to the user's Mailchimp
account using the `mailchimp-mcp-server`. Once connected,
Claude can manage email campaigns, audiences, subscribers,
automations, tags, segments, and reports — all through
plain English conversation.

The connector has two phases:

- **Phase 1 — Connect.** A conversational walkthrough.
  You guide the user through getting their API key and
  registering Mailchimp with Claude Code. One step at
  a time. Plain English only. No jargon.

- **Phase 2 — Use.** Once connected, you manage their
  Mailchimp account on their behalf using the available
  tools.

**Which phase to run** — Before any Mailchimp action,
check whether the server is already registered. Run
`claude mcp list` silently. If `mailchimp` appears in
the output, skip to Phase 2. If not, run Phase 1.

---

## Communication Rules for Phase 1

The user is a non-technical business owner. Every
message during Phase 1 follows these rules:

- **One step at a time.** Never stack two instructions
  in one message.
- **Plain English only.** Never say MCP, env var, CLI,
  stdio, uvx, terminal, config file, or server prefix.
  Name things plainly: "your Mailchimp key",
  "a small connection step", "your email tool".
- **Tell them what is about to happen** before any
  action: "I'm going to connect Mailchimp to Claude
  now — this takes about 30 seconds."
- **React warmly.** Good: "Mailchimp is connected —
  let's go!" Bad: "MCP server registered successfully."
- **Never show raw error messages.** Translate to plain
  English and diagnose silently.
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or file paths.** You run them
  silently. The user never sees them.

---

## PHASE 1 — Connect Mailchimp

### Step 1 — Check if Python is available

Tell the user:
*"I'm going to connect your Mailchimp account to
Claude — this takes about 30 seconds. First let me
check something on your computer."*

Silently run:
```bash
python3 --version || python --version
```

- If a version appears → go to Step 2.
- If not found → tell the user:
  *"I need one small tool installed first. Could you
  go to python.org/downloads and install Python?
  It takes about 2 minutes. Let me know when it's
  done and I'll continue."*
  Wait for them, then re-check before continuing.

### Step 2 — Ask for their Mailchimp API key

Tell the user:
*"I need your Mailchimp key to make the connection.
Here's how to find it — it takes about a minute:"*

Then send a second message:
*"1. Log in to Mailchimp
2. Click your name in the top right
3. Go to Profile → Extras → API Keys
4. Click 'Create A Key'
5. Copy the key and paste it here
The key looks something like: abc123def456-us8"*

Wait for them to paste the key.
When they do:
- Confirm it looks right (contains a `-` with letters
  after it like `-us8` or `-us21`)
- Never echo the full key back in the transcript
- Store it as `MAILCHIMP_API_KEY` for Step 3

If the format looks wrong → tell them in plain English:
*"That doesn't look quite right — the key should
have a dash near the end, like abc123-us8. Could
you check and paste it again?"*

### Step 3 — Register Mailchimp with Claude Code

Tell the user:
*"Got it — connecting Mailchimp now. This takes
about 30 seconds."*

Silently run:
```bash
claude mcp add mailchimp \
  -s user \
  -e MAILCHIMP_API_KEY=<their_key> \
  -- uvx mailchimp-mcp-server
```

- If it succeeds → go to Step 4.
- If `uvx` is not found → silently run
  `pip install uv --break-system-packages` or
  `pip3 install uv --break-system-packages`
  then retry the command.
- If still failing → tell the user:
  *"I hit a small snag connecting Mailchimp. Could
  you close this window, open a fresh one, and tell
  me 'ready'? I'll try a different way."*

### Step 4 — Verify the connection

Tell the user:
*"Almost there — just checking the connection works."*

Silently run:
```bash
claude mcp list
```

- If `mailchimp` appears → go to Step 5.
- If not → tell the user:
  *"The connection didn't quite stick. Could you
  close Claude Code completely, reopen it, and
  say 'reconnect Mailchimp'? I'll pick up from here."*

### Step 5 — Confirm and hand off to Phase 2

Tell the user:
*"Mailchimp is connected! I can now help you manage
your campaigns, subscribers, audiences, and more —
all from here. What would you like to do first?"*

Phase 1 is complete. Phase 2 takes over from here.

---

## PHASE 2 — Use Mailchimp Tools

Once connected, these tools are available as
`mcp__mailchimp__*` at runtime.

### Key Tools by Category

**Audiences (Lists)**
| What the user wants | Tool to use |
|---|---|
| "Show me my audiences" | `get_lists` |
| "How many subscribers do I have?" | `get_list` with list_id |
| "Create a new audience" | `create_list` |

**Subscribers / Members**
| What the user wants | Tool to use |
|---|---|
| "Add a subscriber" | `add_list_member` |
| "Find a subscriber" | `get_list_member` by email |
| "Unsubscribe someone" | `update_list_member` status: unsubscribed |
| "Add a tag to someone" | `create_segment_member` or `update_list_member` |

**Campaigns**
| What the user wants | Tool to use |
|---|---|
| "Show my campaigns" | `get_campaigns` |
| "Create a campaign" | `create_campaign` |
| "Send a campaign" | `send_campaign` |
| "Check campaign performance" | `get_campaign_report` |

**Automations**
| What the user wants | Tool to use |
|---|---|
| "Show my automations" | `get_automations` |
| "Pause an automation" | `pause_automation` |
| "Start an automation" | `start_automation` |

**Reports**
| What the user wants | Tool to use |
|---|---|
| "What's my open rate?" | `get_campaign_report` |
| "Show click stats" | `get_campaign_click_details` |
| "Who unsubscribed?" | `get_unsubscribes` |

---

## Common Patterns

**"Add jane@example.com to my newsletter list"**
→ `get_lists` to find list_id
→ `add_list_member` with email + list_id
→ "Done — Jane has been added to your newsletter."

**"Create a campaign for our May promotion"**
→ `get_lists` to confirm which audience to use
→ Confirm subject line, sender name with user
→ `create_campaign` with confirmed details
→ "Campaign created — want me to send it now or
save it as a draft?"

**"How did my last campaign perform?"**
→ `get_campaigns` to find most recent campaign_id
→ `get_campaign_report` with campaign_id
→ Summarise: open rate, click rate, unsubscribes
   in plain English

**"Unsubscribe john@example.com"**
→ `get_lists` to find list_id
→ Confirm with user before making any changes
→ `update_list_member` status: unsubscribed
→ "Done — John has been unsubscribed."

---

## Behaviour Rules

- **Confirm before sending** — always confirm with the
  user before sending any campaign or email. Echo
  the subject line and audience back before the call.
- **Confirm before unsubscribing** — always confirm
  the email address before removing a subscriber.
- **Default to read first** — summarise counts before
  showing full lists. "You have 3 campaigns — want
  me to show them?"
- **Read-only safety** — if user seems to be
  exploring, suggest: "Want me to run in read-only
  mode so nothing gets changed accidentally?"
- **Mask emails when listing** — partially mask
  emails in summaries: `j***@example.com` unless
  the user asks for full addresses.
- **Never echo the API key** — it lives in the MCP
  config only. Never write it to a file or include
  it in a commit.
- **Rate limits** — if Mailchimp returns a rate limit
  error, wait 5 seconds and retry once. Tell the
  user in plain English if it happens again:
  "Mailchimp is a little busy right now — I'll
  try again in a moment."

---

## Error Handling

| Error | What to say | How to fix |
|---|---|---|
| 401 Unauthorized | "Your Mailchimp key isn't working. Let me help you reconnect." | Re-run Phase 1 Step 2 to get a fresh key |
| 403 Forbidden | "You don't have permission for that action in Mailchimp." | Check account plan — some features need paid plans |
| 404 Not Found | "I couldn't find that in your Mailchimp account." | Check list_id or campaign_id with `get_lists` |
| 429 Rate limit | "Mailchimp is a little busy — I'll wait a moment." | Wait 5s, retry once |
| MCP not found | "Mailchimp isn't connected yet — let me set that up." | Run Phase 1 from the start |

---

## Related Skills

- **connector-recommender** — recommending which
  connectors to set up
- **ghl-connector** — same MCP pattern for CRM
- **systematic-debugging** — troubleshooting API
  key or connection errors
- **email-composer** — drafting campaign copy before
  pushing it into Mailchimp