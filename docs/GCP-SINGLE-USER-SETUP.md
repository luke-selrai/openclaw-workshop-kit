---
title: GCP Single-User Server Setup Guide
version: 5.0
date: 2026-04-02
---

# Claude Assistant — GCP Server Setup

> 💡 **Keep this page open on your screen throughout the setup.** Everything you need is right here.

Today you are setting up a personal AI assistant that runs **24/7 on a Google Cloud server**. It learns about your business, remembers everything, and has 86 specialist skills built in — available anytime from your phone, even when your laptop is off.

---

## What You Are Building

| What | Description |
|---|---|
| **Your AI Assistant** | Runs 24/7 on a server. Always on, always ready. |
| **Messaging Access** | Message your assistant via Telegram, Discord, WhatsApp, or iMessage |
| **86 Skills** | Research, copywriting, sales emails, competitor analysis, and more |
| **Memory System** | Saves what it learns about you and your business |
| **Voice Messages** | Send voice notes — assistant transcribes and responds |

---

## What You Need Before Starting

- A **Google Cloud account** — [cloud.google.com](https://cloud.google.com) (credit card required even for free tier)
- The **gcloud CLI** installed on your laptop — [cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install)
- A **Claude Max account** — [claude.ai](https://claude.ai) → Settings → Billing → Upgrade to Max ($100 USD/month)
- One of the following messaging apps on your phone: **Telegram** (recommended), **Discord**, **WhatsApp**, or **iMessage**

> 💳 **Platform quick-start:**
> - **Telegram** — Open Telegram → search **@BotFather** → send `/newbot` → copy the token it gives you
> - **Discord** — Have your server ID ready (right-click your server → Copy Server ID)
> - **WhatsApp** — You will need a WhatsApp Business API token (setup guided during install)
> - **iMessage** — Mac only; no token needed

---

## How This Setup Works

There are only **two things you do manually** — both require a browser to sign in. Everything else is handled by Claude automatically.

| Step | Who does it | Why |
|---|---|---|
| Sign in to Google Cloud | **You** (once) | Needs your browser |
| Sign in to Claude on the server | **You** (once) | Needs your browser |
| Create the VM, install everything, set up the service | **Claude** | Fully automated |
| Clone skills, configure messaging, start the assistant | **Claude** | Fully automated |

---

## Step 1 — Sign In to Google Cloud

Open your terminal on your laptop and run:

```bash
gcloud auth login
```

A browser window will open. Sign in with your Google account.

✅ Done when: your terminal says `You are now logged in as [yourname@gmail.com]`

---

## Step 2 — Paste the Setup Prompt

1. Open **Claude Code** on your laptop
2. Copy the entire prompt below and paste it into the Claude chat — **do not fill anything in**, Claude will ask you the questions
3. Press **Enter** and follow what Claude tells you

### The Setup Prompt — Copy Everything Below

```
I am setting up a Claude AI Business Assistant on a Google Cloud Platform server.
It should work exactly like the full laptop setup — same skills, same memory, same tools
— but running 24/7 on a server I can message from Telegram.

Do these steps one at a time in plain English.
Do NOT ask for confirmation before proceeding — just do each step and tell me when it is done.

Before doing anything, ask me these questions one at a time:

QUESTION 1 — GCP Project:
Run: gcloud projects list
Show me the list of my existing GCP projects as a numbered list.
Ask me: "Which project would you like to use? Type the number, or type NEW to create a new one."
If I say NEW, ask me: "What would you like to call the new project?" then run:
  gcloud projects create <name> --name="<name>"
Wait for my answer before continuing.

QUESTION 2 — Region:
Ask me: "Which region is closest to you?" and show these options:
  1. Australia (Sydney) — australia-southeast1
  2. USA (Iowa) — us-central1
  3. USA (Virginia) — us-east1
  4. Europe (Belgium) — europe-west1
  5. Asia (Singapore) — asia-southeast1
  6. Other — I will type it myself
Wait for my answer before continuing.

QUESTION 3 — Messaging platform:
Ask me: "Which messaging app would you like to use to talk to your assistant?" and show these options:
  1. Telegram (recommended — easiest to set up)
  2. Discord
  3. WhatsApp
  4. iMessage (Mac only)
Wait for my answer before continuing.

Then, depending on my choice:
- If Telegram: Ask "Please paste your Telegram bot token." and remind me: "Open Telegram, search @BotFather, send /newbot, and copy the token it gives you."
- If Discord: Ask "Please paste your Discord bot token." and remind me: "Go to discord.com/developers → New Application → Bot → Reset Token."
- If WhatsApp: Ask "Please paste your WhatsApp Business API token." and remind me: "You need a Meta Business account at developers.facebook.com to get this."
- If iMessage: Confirm they are on a Mac. No token needed.
Wait for my answer before continuing.

Once you have all three answers, proceed with everything below automatically.

─────────────────────────────────────
PART 1 — CREATE THE SERVER
─────────────────────────────────────

1. Create a GCP VM with these exact specs:
   - Name: claude-assistant (if taken, use claude-assistant-v2)
   - Machine type: e2-standard-2 (2 vCPU, 8GB RAM)
   - Image: ubuntu-2404-lts-amd64 from ubuntu-os-cloud
   - Boot disk: 50GB standard
   - Zone: first available in my chosen region
   Tell me the VM name and IP when ready.

2. Wait 15 seconds for the VM to boot, then SSH in:
   gcloud compute ssh <vm-name> --project=<project-id> --zone=<zone>

─────────────────────────────────────
PART 2 — INSTALL EVERYTHING
─────────────────────────────────────

Run all of the following on the server:

3. Add 4GB swap space:
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

4. Install system tools:
   sudo apt-get update -qq
   sudo apt-get install -y curl git ffmpeg python3 python3-pip build-essential unzip

5. Install Node.js v22 LTS:
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
   sudo apt-get install -y nodejs

6. Install Bun:
   curl -fsSL https://bun.sh/install | bash
   source ~/.bashrc

7. Install Whisper and pre-download the tiny model:
   pip3 install openai-whisper --quiet --break-system-packages
   echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
   source ~/.bashrc
   python3 -c "import whisper; whisper.load_model('tiny')"

8. Install Claude Code:
   curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh && bash /tmp/install.sh

─────────────────────────────────────
PART 3 — SIGN IN TO CLAUDE (USER DOES THIS)
─────────────────────────────────────

9. Tell me to open a NEW terminal on my laptop and run this to sign in to Claude on the server:

   gcloud compute ssh <vm-name> --project=<project-id> --zone=<zone>

   Then on the server, run:
   ~/.local/bin/claude auth login

   Tell me: "A URL will appear. Open it in your browser, sign in with your Claude account,
   and come back here when done."

   Wait for me to confirm I have signed in before continuing.

─────────────────────────────────────
PART 4 — SET UP THE ASSISTANT
─────────────────────────────────────

10. Set up the workspace:
    a. git clone https://github.com/luke-selrai/openclaw-workshop-kit.git ~/workshop-kit
    b. mkdir -p ~/my-assistant
    c. cp ~/workshop-kit/my-assistant/CLAUDE.md ~/my-assistant/CLAUDE.md
    d. mkdir -p ~/.claude/skills
    e. cp -r ~/workshop-kit/skills/*/ ~/.claude/skills/

11. Mark the workspace as trusted and onboarding as complete so Claude starts cleanly:
    python3 -c "
import json
with open('/home/$USER/.claude.json') as f:
    d = json.load(f)
d['hasCompletedOnboarding'] = True
d['lastOnboardingVersion'] = 100
d['theme'] = 'dark'
if 'projects' not in d:
    d['projects'] = {}
d['projects']['/home/$USER/my-assistant'] = {
    'allowedTools': [],
    'mcpContextUris': [],
    'mcpServers': {},
    'enabledMcpjsonServers': [],
    'disabledMcpjsonServers': [],
    'hasTrustDialogAccepted': True,
    'projectOnboardingSeenCount': 1,
    'hasClaudeMdExternalIncludesApproved': True,
    'hasClaudeMdExternalIncludesWarningShown': True
}
with open('/home/$USER/.claude.json', 'w') as f:
    json.dump(d, f, indent=2)
print('Done')
"

─────────────────────────────────────
PART 5 — INSTALL MESSAGING PLUGIN
─────────────────────────────────────

12. Install the plugin for the platform the user chose:

    IF Telegram:
      mkdir -p ~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.4

      cat > ~/.claude/settings.json << 'EOF'
      {
        "enabledPlugins": {
          "telegram@claude-plugins-official": true
        }
      }
      EOF

      cat > ~/.claude/plugins/installed_plugins.json << EOF
      {
        "telegram@claude-plugins-official": [
          {
            "scope": "user",
            "installPath": "/home/$USER/.claude/plugins/cache/claude-plugins-official/telegram/0.0.4",
            "version": "0.0.4",
            "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "lastUpdated": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "gitCommitSha": "b10b583de281385442474e836644534b938b2678"
          }
        ]
      }
      EOF

      cat > ~/.claude/plugins/cache/claude-plugins-official/telegram/0.0.4/access.json << EOF
      {
        "token": "<telegram-bot-token>",
        "allowlist": [],
        "policy": "allowlist"
      }
      EOF

    IF Discord:
      mkdir -p ~/.claude/plugins/cache/claude-plugins-official/discord/0.0.1

      cat > ~/.claude/settings.json << 'EOF'
      {
        "enabledPlugins": {
          "discord@claude-plugins-official": true
        }
      }
      EOF

      cat > ~/.claude/plugins/installed_plugins.json << EOF
      {
        "discord@claude-plugins-official": [
          {
            "scope": "user",
            "installPath": "/home/$USER/.claude/plugins/cache/claude-plugins-official/discord/0.0.1",
            "version": "0.0.1",
            "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "lastUpdated": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
          }
        ]
      }
      EOF

      cat > ~/.claude/plugins/cache/claude-plugins-official/discord/0.0.1/access.json << EOF
      {
        "token": "<discord-bot-token>",
        "policy": "allowlist",
        "allowlist": []
      }
      EOF

    IF WhatsApp:
      mkdir -p ~/.claude/plugins/cache/claude-plugins-official/whatsapp/0.0.1

      cat > ~/.claude/settings.json << 'EOF'
      {
        "enabledPlugins": {
          "whatsapp@claude-plugins-official": true
        }
      }
      EOF

      cat > ~/.claude/plugins/installed_plugins.json << EOF
      {
        "whatsapp@claude-plugins-official": [
          {
            "scope": "user",
            "installPath": "/home/$USER/.claude/plugins/cache/claude-plugins-official/whatsapp/0.0.1",
            "version": "0.0.1",
            "installedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "lastUpdated": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
          }
        ]
      }
      EOF

      cat > ~/.claude/plugins/cache/claude-plugins-official/whatsapp/0.0.1/access.json << EOF
      {
        "token": "<whatsapp-api-token>",
        "policy": "allowlist",
        "allowlist": []
      }
      EOF

    IF iMessage:
      Tell me: "iMessage integration requires additional setup on a Mac. For now, your assistant is running on the server. Ask your assistant 'How do I connect iMessage?' once it is running and it will guide you through it."
      Skip the access.json step — no token needed at this stage.

─────────────────────────────────────
PART 6 — RUN 24/7 AS A SERVICE
─────────────────────────────────────

13. Create a PTY wrapper so Claude runs correctly without a terminal.
    Use the correct --channels flag for the platform the user chose:
    - Telegram:  plugin:telegram@claude-plugins-official
    - Discord:   plugin:discord@claude-plugins-official
    - WhatsApp:  plugin:whatsapp@claude-plugins-official
    - iMessage:  plugin:imessage@claude-plugins-official

    cat > ~/start-claude.sh << 'EOF'
    #!/usr/bin/env python3
    import pty, os

    def read(fd):
        return os.read(fd, 1024)

    pty.spawn(
        [os.path.expanduser("~/.local/bin/claude"), "--channels", "plugin:<platform>@claude-plugins-official"],
        master_read=read
    )
    EOF
    (Replace <platform> with telegram, discord, whatsapp, or imessage as appropriate.)
    chmod +x ~/start-claude.sh

14. Create the systemd service:
    mkdir -p ~/.config/systemd/user
    cat > ~/.config/systemd/user/claude-assistant.service << EOF
    [Unit]
    Description=Claude AI Assistant
    After=network.target

    [Service]
    Type=simple
    WorkingDirectory=%h/my-assistant
    Environment=PATH=/home/$USER/.local/bin:/home/$USER/.bun/bin:/usr/local/bin:/usr/bin:/bin
    Environment=HOME=%h
    Environment=WHISPER_CACHE_DIR=%h/.cache/whisper
    ExecStart=/usr/bin/python3 /home/$USER/start-claude.sh
    Restart=on-failure
    RestartSec=10
    StandardOutput=append:%h/claude-assistant.log
    StandardError=append:%h/claude-assistant.log

    [Install]
    WantedBy=default.target
    EOF

15. Enable and start:
    loginctl enable-linger $USER
    systemctl --user daemon-reload
    systemctl --user enable claude-assistant
    systemctl --user start claude-assistant

16. Wait 15 seconds, then show me the service status and last 20 lines of the log.

─────────────────────────────────────
PART 7 — FINISH
─────────────────────────────────────

17. Walk me through pairing my account with the bot on whichever platform I chose, step by step.

18. When everything is done, tell me to open my messaging app, find my bot, and send "hello".
    My assistant will introduce itself and ask me 7 questions to learn about my business.

Talk to me in plain English throughout. One step at a time.
```

**What happens next:** Claude will ask you 3 quick questions (including which messaging app you want to use), then build and configure everything automatically. The only moment you step in is Step 3 — signing in to Claude on the server.

---

## Step 3 — Sign In to Claude on the Server

When Claude reaches Part 3, it will tell you to open a new terminal and run a command. Here is what that looks like:

**Open a new terminal on your laptop and run:**

```bash
gcloud compute ssh claude-assistant --project=<your-project> --zone=<your-zone>
```

**Then on the server, run:**

```bash
~/.local/bin/claude auth login
```

A URL will appear. Open it in your laptop browser and sign in with your Claude account. Come back and tell Claude you are done — it will continue automatically.

✅ Done when: the server terminal says you are logged in

---

## Step 4 — Your Assistant Will Ask You 7 Questions

After pairing your messaging app, open it on your phone, find your bot, and send **hello**. Your assistant will introduce itself and ask:

| # | Question |
|---|---|
| 1 | What is your first name? |
| 2 | What is your business called, and what do you do in one sentence? |
| 3 | Who are your customers — who do you help? |
| 4 | What is the biggest frustration or problem in your business right now? |
| 5 | What apps or tools do you use? (Gmail, Facebook, Xero, Instagram, etc.) |
| 6 | How do you prefer I communicate — casual and friendly, or professional and direct? |
| 7 | What would feel like a win for you today? |

> 💡 After this, your assistant knows who you are. Every future conversation starts with that context already loaded.

---

## What You Can Do Now

| Task | What to Say (via Telegram) |
|---|---|
| **Research your competitors** | "Research my top 3 competitors and tell me what they do better" |
| **Write a sales email** | "Write a cold outreach email for [my ideal customer]" |
| **Create social content** | "Write me 5 LinkedIn posts about [topic]" |
| **Analyse a market** | "What are the trends in [my industry] right now?" |
| **Plan your week** | "Help me plan my most important tasks for this week" |
| **Write a blog post** | "Write a 1000-word blog post about [topic] for my website" |
| **Send a voice note** | Send a voice message in your messaging app — it transcribes and responds |

---

## Connect More Tools — Optional

> 💡 Your assistant knows how to set all of these up. Just ask in plain English via Telegram.

**Google Workspace — Gmail, Calendar, Drive, Docs, Sheets**

Ask your assistant: *"Help me connect my Google Workspace account"*

For the full server-specific guide, see [GOOGLE-WORKSPACE-SERVER-SETUP.md](GOOGLE-WORKSPACE-SERVER-SETUP.md).

**Microsoft 365 — Outlook, OneDrive, Teams**

Ask your assistant: *"Help me connect my Microsoft 365 account"*

Requires a Microsoft 365 Business subscription. See [M365-SETUP.md](M365-SETUP.md).

**Browser Automation — Playwright**

Ask your assistant: *"Help me set up browser automation"*

---

## Your 86 Skills — Quick Reference

<details>
<summary>Click to see all skill categories</summary>

**Marketing & Content**
Copywriting, email sequences, email composer, social media posts, ad copy, blog content, direct response copy, paid ads, content marketing, avoid-AI-writing patterns

**Research & Intelligence**
Deep research, competitor analysis, competitive cartography, Reddit insights, market trends, YouTube summaries, last 30 days trends, Apify market research, Apify competitor intelligence, Apify content analytics

**Strategy & Business**
Brainstorming, writing plans, systems thinking, product appeal analysis, CEO-mode plan reviews, engineering plan reviews, personal finance coaching, ADHD entrepreneur coaching, indie monetisation, AI product development, analytics

**AI & Automation**
AI agents architect, AI engineer, agent creator, agent memory systems, agent memory MCP, agent tool builder, agent orchestration, autonomous agent patterns, orchestrator, prompt engineer, skill creator, MCP builder, MCP creator, Claude API, bot developer, n8n workflow patterns, n8n MCP tools, agentfolio

**Engineering & Development**
API architect, code architecture, full-stack debugger, systematic debugging, Next.js App Router, TypeScript advanced patterns, Supabase admin, PostgreSQL optimization, security auditor, modern auth 2026, OAuth/OIDC, microservices patterns, performance profiling, logging & observability, test-driven development, verification before completion, QA, webapp testing, Playwright

**DevOps & Infrastructure**
DevOps automator, Terraform, GitHub Actions, site reliability engineer, Vercel deployment, git workflow expert, gstack-ship, git worktrees, finishing dev branches, cost optimizer, task decomposer, dispatching parallel agents, subagent-driven development

**Design & UX**
shadcn/ui, web design guidelines, web accessibility, diagramming expert

**Other**
Remotion video, retrospectives, feature manifest, sales automator, technical writer, first-run setup

</details>

---

## Useful Links

| Resource | Link |
|---|---|
| Workshop Kit (GitHub) | [github.com/luke-selrai/openclaw-workshop-kit](https://github.com/luke-selrai/openclaw-workshop-kit) |
| Claude.ai | [claude.ai](https://claude.ai) |
| Google Cloud Console | [console.cloud.google.com](https://console.cloud.google.com) |
| gcloud CLI Install | [cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install) |
| Selr AI | [selrai.com.au](https://selrai.com.au) |
| Email Luke | [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## If Something Breaks

> 🛠️ **Don't worry. Everything is fixable.**

| Problem | Solution |
|---|---|
| SSH connection fails | Check VM is running: [console.cloud.google.com](https://console.cloud.google.com) → Compute Engine |
| Claude login URL doesn't work | Open it in the browser where you are logged into claude.ai |
| Bot not responding | SSH into server and run: `tail -50 ~/claude-assistant.log` |
| Assistant crashed | SSH into server and run: `systemctl --user restart claude-assistant` |
| Disk full or out of memory | SSH into server and run: `df -h` and `free -h` |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

Your assistant is designed to handle problems too — once it is running, just describe what happened in plain English and it will figure it out.

---

## Monthly Cost Estimate (GCP)

| Resource | Estimated Cost |
|---|---|
| e2-standard-2 VM (24/7) | ~$45–55 AUD/month |
| 50GB persistent disk | ~$3 AUD/month |
| **Total** | **~$48–58 AUD/month** |

> 💡 **Tip:** Stop the VM when not in use to save costs. In GCP Console → Compute Engine → select VM → **Stop**.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
