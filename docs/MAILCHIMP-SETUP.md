# Mailchimp Setup Guide

Connect your Mailchimp account to Claude Code so you
can manage campaigns, subscribers, and audiences
through conversation — no dashboard needed.

## The Quick Way

Just say **"connect my Mailchimp"** to your assistant
and it will walk you through everything step by step.
You do not need to follow this guide manually.

---

## What You Can Do Once Connected

- Add and remove subscribers
- Create and send email campaigns
- Check open rates and click stats
- Manage audience segments and tags
- Pause and start automations
- Pull campaign performance reports

---

## What You Need

- A Mailchimp account (free or paid)
- Python installed on your computer
  (download from python.org if needed)

---

## Getting Your Mailchimp API Key

1. Log in to your Mailchimp account
2. Click your name in the top right corner
3. Go to **Profile → Extras → API Keys**
4. Click **"Create A Key"**
5. Copy the key — it looks like: `abc123def456-us8`

⚠️ Keep your API key private. Do not share it or
paste it into public chat windows.

---

## Method 1 — Conversational Setup (Recommended)

Simply say to your assistant:
> "Connect my Mailchimp"

Your assistant will:
1. Ask for your API key
2. Connect Mailchimp in the background
3. Confirm when it's ready
4. Ask what you'd like to do first

No commands needed. No config files to edit.

---

## Method 2 — Manual Setup

If the conversational setup doesn't work, you can
connect manually by running this in your terminal:

```bash
claude mcp add mailchimp \
  -s user \
  -e MAILCHIMP_API_KEY=your-key-here \
  -- uvx mailchimp-mcp-server
```

Replace `your-key-here` with your actual API key.

Then restart Claude Code and say:
> "Check my Mailchimp connection"

---

## Read-Only Mode (Recommended for Exploring)

To connect without risk of accidental changes, add
`MAILCHIMP_READ_ONLY=true`:

```bash
claude mcp add mailchimp \
  -s user \
  -e MAILCHIMP_API_KEY=your-key-here \
  -e MAILCHIMP_READ_ONLY=true \
  -- uvx mailchimp-mcp-server
```

In read-only mode, Claude can view all your data
but cannot create, send, or delete anything.

---

## Common Issues

**"I don't see an API Keys option"**
Make sure you are in your Profile settings, not
the Account settings. Look under Extras → API Keys.

**"The connection failed"**
Check that your API key is complete — it should
have a dash near the end like `abc123-us8`.
Try creating a new key and connecting again.

**"Mailchimp is not found after setup"**
Close Claude Code completely, reopen it, and say
"connect my Mailchimp" again.

**"I'm getting permission errors"**
Some Mailchimp features (like transactional email)
require a paid plan. Check your account plan if
you see 403 errors.

---

## Privacy Note

Your Mailchimp API key is stored only in your local
Claude Code config file (`~/.claude.json`). It is
never sent to Anthropic or stored anywhere else.
Subscriber email addresses appear in your conversation
history on your local device only.