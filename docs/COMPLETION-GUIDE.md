# Completion Guide — Finishing Your AI Setup After the Workshop

If you didn't get through everything today, this guide walks you through completing your setup at home. Take your time. There's no rush.

> For the full end-to-end setup guide, see [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md)

---

## What You Should Have Done Today

Tick these off:

- [ ] VS Code installed
- [ ] Terminal basics understood
- [ ] Claude Code installed (`npm install -g @anthropic-ai/claude-code`)
- [ ] Logged in to Claude (`claude login`)
- [ ] Workshop kit downloaded (`git clone ...`)
- [ ] Skills installed (check `~/.claude/skills/`)
- [ ] Playwright (browser automation) connected
- [ ] Google Workspace connected (Gmail + Calendar) (optional — if you got to it)
- [ ] Onboarding completed (told your assistant about your business)
- [ ] Tested a first task with your assistant

---

## Finishing at Home — Step by Step

### If you didn't finish the install:

Open Terminal (Mac: press Command + Space, type "Terminal", press Enter) and run:

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

Your skills were installed during the workshop setup. They live at `~/.claude/skills/`

---

### Connect More Tools

These are the most valuable next connections. Do them in this order:

#### 1. Google Workspace (Gmail + Calendar + Drive + Docs + Sheets + More)

Install the Google Workspace tool and sign in:
```bash
npm install -g @googleworkspace/cli
gws auth login
```

A browser window opens — pick your Google account and click Allow. Once connected, your assistant can read and send emails, check your calendar, access Drive, Docs, Sheets, and more.

> For the full guide with troubleshooting, see [GOOGLE-WORKSPACE-SETUP.md](GOOGLE-WORKSPACE-SETUP.md)

#### 2. Notion (knowledge base)
Your assistant can help you set this up — just ask in the Claude chat:
> "Help me connect Notion so you can read and update my workspace."

Great for keeping a business knowledge base.

#### 3. Slack or Microsoft Teams (if you use them)
Your assistant can help you set this up — just ask in the Claude chat:
> "Help me connect Slack so you can send and read messages."

---

### Set Up Phone Notifications (Telegram and/or WhatsApp)

This lets you chat with your assistant from your phone — ask questions, request tasks, and get replies wherever you are. You can set up one or both.

#### Telegram

**Step 1:** Download Telegram on your phone (free) and sign up
**Step 2:** Search for `@BotFather` in Telegram, send `/newbot`, and follow the prompts to create a bot
**Step 3:** Copy the bot token BotFather gives you
**Step 4:** In Claude Code, type: `/plugin install telegram@claude-plugins-official`
**Step 5:** Save your token: `/telegram:configure [your token]`
**Step 6:** Install Bun (required): `curl -fsSL https://bun.sh/install | bash`
**Step 7:** Restart Claude Code with: `claude --channels plugin:telegram@claude-plugins-official`
**Step 8:** Message your bot on Telegram, get a pairing code, then type: `/telegram:access pair [code]`

> For the full guide with troubleshooting, see [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md)

#### WhatsApp

Your assistant connects to WhatsApp via QR code — no Business API needed.

**Step 1:** Make sure WhatsApp is installed on your phone
**Step 2:** Tell your assistant: "I want to set up WhatsApp notifications"
**Step 3:** Your assistant will show a QR code — scan it with WhatsApp (Settings > Linked Devices > Link a Device)
**Step 4:** Once linked, your assistant can send you messages and you can reply directly from WhatsApp

### Set Up iMessage — Text Your Assistant from Your iPhone (Mac Only)

If you're on a Mac, you can skip Telegram entirely and use iMessage instead. No extra apps — just text yourself.

**Step 1:** In Claude Code, type: `/plugin install imessage@claude-plugins-official`
**Step 2:** Install Bun (required): `curl -fsSL https://bun.sh/install | bash`
**Step 3:** Grant Full Disk Access to your terminal (System Settings → Privacy & Security → Full Disk Access)
**Step 4:** Restart Claude Code with: `claude --channels plugin:imessage@claude-plugins-official`
**Step 5:** Open Messages and text yourself — your assistant replies instantly

> For the full guide with troubleshooting, see [IMESSAGE-SETUP.md](IMESSAGE-SETUP.md)

---

### Connect Your CRM (GoHighLevel or HubSpot)

Your assistant can help you set this up — just ask in the Claude chat:
> "Help me connect my CRM (GoHighLevel / HubSpot) so you can manage my contacts. My API key is [key]."

---

### The Most Useful Things to Do in Week 1

Now that everything's set up, here's what to try first:

**Day 1: Research**
> "Research the top 5 pain points for [your target customer] in 2025. Give me a structured report I can use for marketing."

**Day 2: Content**
> "Write 10 LinkedIn posts for the next 2 weeks for my business. My business is [describe]. My audience is [describe]. Make them sound like a real person."

**Day 3: Email**
> "Build me a 5-email welcome sequence for new leads. Each email should be under 200 words. The sequence is for [your business type]."

**Day 4: Competitors**
> "Analyse my top 3 competitors. Go to their websites, summarise what they offer, what their pricing looks like, and where I could position differently."

**Day 5: Strategy**
> "I want to increase my revenue by 30% in the next 90 days. Help me brainstorm 10 specific strategies based on what you know about my business."

---

## How to Get Better Results

### The Golden Rule of AI Prompts
More context = better results. Always include:
1. **Who** you're writing for
2. **What** you want
3. **Why** it matters (the goal)
4. **How** you want it (tone, length, format)

**Example:**
> "Write a cold email [WHAT] to a restaurant owner in Brisbane [WHO] offering social media management services [WHY: get them as a client]. Keep it under 150 words, casual but professional, with a specific question at the end to start a conversation [HOW]."

---

### Teach Your Assistant Over Time

The more you tell your assistant, the better it gets. After any conversation, you can say:
> "Remember that for future — I prefer emails to be under 200 words and always end with a question."

Your assistant will update its memory file and apply it from that point on.

---

### Save Your Best Prompts

When you find a prompt that works really well, save it. Create a file:
```bash
nano ~/my-assistant/my-best-prompts.md
```
Paste in your best prompts so you can reuse them.

---

## Troubleshooting Common Issues

### "Claude says it can't find my skills"
```bash
ls ~/.claude/skills/
```
Your skills were installed during the workshop setup. They live at `~/.claude/skills/`. If the folder is empty, ask your assistant for help:
> "My skills folder is empty. Help me reinstall the workshop skills."

### "Claude isn't remembering me"
Check your memory file exists:
```bash
cat ~/my-assistant/memory/USER.md
```
If it says "status: not-yet-onboarded", start a new conversation and your assistant will run the onboarding questions again.

### "Google Workspace isn't connecting"
Your assistant can help you set this up — just ask in the Claude chat:
> "Google Workspace isn't working. Help me reconnect it."

### "Something broke and I don't know what"
Tell your assistant:
> "Something broke. Here's the error: [paste the red error text]. Help me fix it step by step."

Your `systematic-debugging` skill handles this — your assistant will walk you through diagnosing and fixing it in plain English.

### "I forgot how to start my assistant"
```bash
cd ~/my-assistant && claude
```
That's the only command you need to remember. Put a note on your monitor if needed!

---

## Getting More Advanced (Month 2+)

Once you're comfortable with the basics, here's what to explore next:

### n8n (Automation Workflows)
n8n is a visual automation tool (like Zapier, but you own it). Your AI assistant can build and manage n8n workflows. Things like:
- "When someone fills in my contact form, add them to my CRM and send them a welcome email"
- "Every Monday, pull my sales numbers and email me a summary"

### Your Own Agents
Once you see the value of AI in your business, you can deploy your own agents that run 24/7. Luke and the Selr AI team can set this up for you.

### Voice Interface
You can talk to your AI assistant instead of typing, using tools like Wispr Flow (what Luke uses).

---

## Support

- **Workshop resources:** All documents in `~/workshop-kit/docs/`
- **Skills reference:** `~/workshop-kit/skills/SKILLS-LIST.md`
- **Luke / Selr AI:** selrai.com.au

---

*Built for the OpenClaw Workshop by Selr AI — selrai.com.au*
