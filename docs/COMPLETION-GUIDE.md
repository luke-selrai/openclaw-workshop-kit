# Completion Guide — Finishing Your AI Setup After the Workshop

If you didn't get through everything today, this guide walks you through completing your setup at home. Take your time. There's no rush.

> For the full end-to-end setup guide, see [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md)

---

## What You Should Have Done Today

Tick these off:

- [ ] Claude Desktop installed and signed in
- [ ] New Code session opened in Claude Desktop
- [ ] Workshop kit downloaded (handled by the bootstrap prompt)
- [ ] Skills installed (check `~/.claude/skills/`)
- [ ] Playwright (browser automation) connected
- [ ] `~/my-assistant/` folder opened in Claude Desktop via the folder icon
- [ ] Google Workspace connected (Gmail + Calendar) (optional — if you got to it)
- [ ] Onboarding completed (told your assistant about your business)
- [ ] Tested a first task with your assistant

---

## Finishing at Home — Step by Step

### If you didn't finish the install:

**Windows users:** Make sure [Git for Windows](https://gitforwindows.org) is installed first. Then open Claude Desktop, start a new Code session, and paste the bootstrap prompt from the workshop page — your assistant walks you through the whole install conversationally, including any Windows-specific snags.

**Mac users:** Open Claude Desktop, start a new Code session, and paste the bootstrap prompt from the workshop page. If macOS prompts you to install the Xcode Command Line Tools during setup, click **Install** and wait for it to finish — your assistant will pick up from there.

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

#### 3. Microsoft Outlook & 365 (Email, Calendar, OneDrive, Teams)

Install the Microsoft 365 tool:
```bash
npm install -g @pnp/cli-microsoft365
m365 setup --interactive
m365 login --authType browser
```

A browser window opens — pick your Microsoft account and click Accept. Once connected, your assistant can read emails, manage calendar, access OneDrive, and more.

> For the full guide with troubleshooting, see [OUTLOOK-SETUP.md](OUTLOOK-SETUP.md)

#### 4. Slack or Microsoft Teams (if you use them)
Your assistant can help you set this up — just ask in the Claude chat:
> "Help me connect Slack so you can send and read messages."

---

### Set Up Phone Notifications (Telegram, WhatsApp, or iMessage)

This lets you chat with your assistant from your phone — ask questions, request tasks, and get replies wherever you are. Pick whichever app you already use.

#### Telegram

**Step 1:** Download Telegram on your phone (free) and sign up
**Step 2:** Search for `@BotFather` in Telegram, send `/newbot`, and follow the prompts to create a bot
**Step 3:** Copy the bot token BotFather gives you
**Step 4:** In Claude Desktop's terminal (bottom panel of a Code session), run: `claude plugin install telegram@claude-plugins-official`
**Step 5:** Save your token: `/telegram:configure [your token]`
**Step 6:** Install Bun (required): Mac/Linux: `curl -fsSL https://bun.sh/install | bash` — Windows: `powershell -c "irm bun.sh/install.ps1 | iex"`
**Step 7:** Restart Claude Code with: `claude --channels plugin:telegram@claude-plugins-official`
**Step 8:** Message your bot on Telegram, get a pairing code, then type: `/telegram:access pair [code]`

> For the full guide with troubleshooting, see [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md)

#### WhatsApp

Your assistant connects to WhatsApp via QR code — no Business API needed.

**Step 1:** Make sure WhatsApp is installed on your phone
**Step 2:** Tell your assistant: "I want to set up WhatsApp notifications"
**Step 3:** Your assistant will show a QR code — scan it with WhatsApp (Settings > Linked Devices > Link a Device)
**Step 4:** Once linked, your assistant can send you messages and you can reply directly from WhatsApp

#### iMessage (Mac Only)

If you're on a Mac, you can use iMessage instead — no extra apps, no bots, just text yourself.

**Step 1:** Install Bun (required): `curl -fsSL https://bun.sh/install | bash`
**Step 2:** Grant Full Disk Access to Claude Desktop (System Settings → Privacy & Security → Full Disk Access → add Claude)
**Step 3:** In Claude Desktop's terminal (bottom panel of a Code session), run: `claude plugin install imessage@claude-plugins-official`
**Step 4:** Restart Claude Code with: `claude --channels plugin:imessage@claude-plugins-official`
**Step 5:** Open Messages and text yourself — your assistant replies instantly

> The first reply triggers a macOS prompt: "Claude wants to control Messages." Click **OK** to allow replies.

> For the full guide with troubleshooting, see [IMESSAGE-SETUP.md](IMESSAGE-SETUP.md)

---

### Connect Your CRM (GoHighLevel or HubSpot)

Your assistant can help you set this up — just ask in the Claude chat:
> "Help me connect my CRM so you can manage my contacts."

Your assistant will walk you through the right steps for your CRM:

- **GoHighLevel:** Needs your GHL API key from Settings → Integrations → API Keys. See [GHL-SETUP.md](GHL-SETUP.md)
- **HubSpot:** Creates a Private App in your HubSpot account — no API key to find manually. See [HUBSPOT-SETUP.md](HUBSPOT-SETUP.md)

---

### Connect GitHub, Square, or CircleCI

If you use any of these tools, your assistant can connect to them too:

- **GitHub** — read issues, pull requests, code, and CI status across your repos. Tell your assistant: "Help me connect my GitHub account." See [GITHUB-SETUP.md](GITHUB-SETUP.md)
- **Square** — read sales, orders, customers, and invoices from your Square account. Tell your assistant: "Connect my Square account." See [SQUARE-SETUP.md](SQUARE-SETUP.md)
- **CircleCI** — check build status, read failure logs, trigger reruns. Tell your assistant: "Connect my CircleCI account." See [CIRCLECI-SETUP.md](CIRCLECI-SETUP.md)

---

### The Most Useful Things to Do in Week 1

Now that everything's set up, here's what to try first:

**Day 1: Research**
> "Research the top 5 pain points for [your target customer] in 2026. Give me a structured report I can use for marketing."

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

Your assistant will capture that in its memory automatically and apply it from that point on. You can always check what it remembers by typing `/memory` in a Code session.

---

### Save Your Best Prompts

When you find a prompt that works really well, tell your assistant:
> "Save this prompt to a file called my-best-prompts.md so I can reuse it."

Your assistant will create and update the file for you.

### Automate Recurring Tasks

Once you have tasks you do regularly, automate them:
> "Check my emails every morning at 9am and send me a summary on Telegram"
> "Post to LinkedIn every weekday at 10am using my saved content"

Your assistant uses `/schedule` and `/loop` to run these automatically.

- **`/schedule`** — runs in the cloud. Your computer does not need to be on.
- **`/loop`** — runs locally on your machine. Your computer must be on and Claude Code must be running.

> For full details, see [AUTOMATION-LOOP-AND-SCHEDULE.md](AUTOMATION-LOOP-AND-SCHEDULE.md)

---

## Troubleshooting Common Issues

### "Claude says it can't find my skills"
```bash
ls ~/.claude/skills/
```
Your skills were installed during the workshop setup. They live at `~/.claude/skills/`. If the folder is empty, ask your assistant for help:
> "My skills folder is empty. Help me reinstall the workshop skills."

### "Claude isn't remembering me"
Ask your assistant directly in the chat:
> "What do you know about me?"

If the answer comes back blank or wrong, say: *"I haven't been onboarded yet — please run the setup questions again."* Your assistant will kick off the 7 onboarding questions. You can also type `/memory` in a Code session to see exactly what Claude has stored.

### "Google Workspace isn't connecting"
Your assistant can help you set this up — just ask in the Claude chat:
> "Google Workspace isn't working. Help me reconnect it."

### "Something broke and I don't know what"
Tell your assistant:
> "Something broke. Here's the error: [paste the red error text]. Help me fix it step by step."

Your `systematic-debugging` skill handles this — your assistant will walk you through diagnosing and fixing it in plain English.

### "I forgot how to start my assistant"
Open Claude Desktop → start a new Code session → click the folder icon at the top and pick `~/my-assistant/`. Your assistant loads automatically. Put a sticky note on your monitor if needed!

---

## Getting More Advanced (Month 2+)

Once you're comfortable with the basics, here's what to explore next:

### n8n (Automation Workflows)
n8n is a visual automation tool (like Zapier, but you own it). Your AI assistant can build and manage n8n workflows. Things like:
- "When someone fills in my contact form, add them to my CRM and send them a welcome email"
- "Every Monday, pull my sales numbers and email me a summary"

### Your Own Agents
Once you see the value of AI in your business, you can deploy your own agents that run 24/7. Luke and the Selr AI team can set this up for you.

### Claude Dispatch (Run Multiple Agents in Parallel)
Dispatch lets you run several Claude agents at once, each handling a different part of a complex task. See [dispatch/DISPATCH-SETUP.md](dispatch/DISPATCH-SETUP.md) for details.

### Voice Interface
You can talk to your AI assistant instead of typing, using tools like Wispr Flow (what Luke uses).

---

## Support

- **Workshop resources:** All documents in `~/workshop-kit/docs/`
- **Skills reference:** `~/workshop-kit/skills/SKILLS-LIST.md`
- **Luke / Selr AI:** selrai.com.au

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
