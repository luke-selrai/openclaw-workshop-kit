---
title: Claude Code — Full Setup Guide
version: 2.0
date: 2026-03-27
---

# Claude Code — Your AI Business Assistant

> **Keep this page open on your screen throughout the setup.** Everything you need is right here.

Today you are setting up a personal AI assistant that lives on YOUR computer. It learns about your business, remembers everything, and has 86 specialist skills built in.

---

## What You Are Building

| What | Description |
|---|---|
| **Your AI Assistant** | Runs locally on your computer. Knows your business. |
| **Browser Control** | Can open websites and automate tasks for you |
| **86 Skills** | Research, copywriting, sales emails, competitor analysis, and more |
| **Memory System** | Saves what it learns about you and your business |

---

## Step 1 — Create a Claude Account

1. Go to [**claude.ai**](https://claude.ai)
2. Click **"Get started"** — the easiest option is **"Continue with Google"**
3. Once signed in, go to **Settings** (click your name, bottom-left) → **Billing**
4. Upgrade to **Claude Max** ($100 USD/month) — this is required for Claude Code to work

Done when: You see "Max" next to your plan name in Settings → Billing.

<details>
<summary>How to upgrade to Claude Max</summary>

1. Go to [claude.ai](https://claude.ai) and log in
2. Click your profile photo (bottom left)
3. Click **Settings → Billing**
4. Click **Upgrade** and choose **Claude Max** — $100 USD/month

Without Claude Max, Claude Code will not work.

</details>

---

## Step 2 — Install VS Code

**Mac:**

1. Go to [code.visualstudio.com](https://code.visualstudio.com)
2. Click **"Download for Mac"**
3. Open the downloaded .zip file
4. Drag **Visual Studio Code** into your **Applications** folder
5. Open it from Applications

**Windows:**

1. Go to [code.visualstudio.com](https://code.visualstudio.com)
2. Click **"Download for Windows"**
3. Run the installer
4. On the "Select Additional Tasks" screen: make sure **"Add to PATH"** is ticked
5. Click **Install**, then **Finish**

---

## Step 3 — Install the Claude Code Extension

1. Open VS Code
2. Click the **Extensions** icon on the left sidebar (it looks like 4 small squares) — or press **Cmd+Shift+X** (Mac) / **Ctrl+Shift+X** (Windows)
3. In the search box, type: **Claude Code**
4. Find the result by **Anthropic** and click **Install**
5. A Claude icon will appear in your left sidebar — click it
6. Follow the prompts to **sign in** with your Claude account

---

## Windows Users Only — Install Git

> **Mac users: skip this section entirely.** Git installs automatically on Mac when needed.

### Download and Install

1. Go to [git-scm.com/download/win](https://git-scm.com/download/win)
2. The download should start automatically. If not, click **"Click here to download"**
3. Run the installer
4. Click **Next** through every screen — all default settings are fine
5. Click **Install**, then **Finish**

### Fix the PATH (IMPORTANT)

The installer does not always add Git to your system correctly. Do this manually:

1. Press the **Windows key** on your keyboard
2. Type: **Environment Variables**
3. Click **"Edit the system environment variables"**
4. Click the **"Environment Variables"** button at the bottom of the window
5. In the bottom section (System variables), find the row called **Path** and click it
6. Click **Edit**
7. Click **New**
8. Type exactly: `C:\Program Files\Git\cmd`
9. Click **OK**, **OK**, **OK** to close all windows

### Close and Reopen VS Code

**You must close VS Code completely and reopen it** for the changes to take effect. Do this now.

### Verify It Worked

1. Open VS Code
2. Open a terminal: **Terminal** menu → **New Terminal**
3. Type: `git --version`
4. You should see something like: `git version 2.43.0.windows.1`

If you still see "git is not recognized", double-check the PATH fix — make sure the path is exactly right.

---

## Step 4 — Install Node.js

Node.js is needed to connect Gmail, Calendar, browser automation, and Telegram later. Install it now so everything is ready.

**Mac:**

1. Go to [nodejs.org](https://nodejs.org)
2. Click the big green button that says **"Download Node.js (LTS)"**
3. Open the downloaded file
4. Click **Continue**, then **Continue** again, then **Install**
5. Enter your Mac password if asked

**Windows:**

1. Go to [nodejs.org](https://nodejs.org)
2. Click the big green button that says **"Download Node.js (LTS)"**
3. Open the downloaded file
4. Click **Next**, then **Next**, then **Next**, then **Install**
5. **Close and reopen VS Code completely** after installing

### Verify It Worked

1. Open a terminal in VS Code: **Terminal** menu → **New Terminal**
2. Type: `node --version`
3. You should see a version number like `v22.x.x`

---

## Step 5 — Paste the Setup Prompt

1. Click the **Claude icon** in the left sidebar
2. **Copy the entire prompt below** and paste it into the Claude chat
3. Press **Enter** and follow what Claude tells you

### The Setup Prompt — Copy Everything Below

```
I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

1. Download the workshop content by running:
   git clone https://github.com/luke-selrai/openclaw-workshop-kit.git ~/workshop-kit

   NOTE: On Mac, if a popup appears asking to install developer tools,
   tell me to click "Install" and wait a few minutes before continuing.

2. Create a folder called "my-assistant" in my home directory.

3. Copy this file from the downloaded workshop-kit into my-assistant:
   - workshop-kit/my-assistant/CLAUDE.md → my-assistant/CLAUDE.md

4. Install all 86 skills: copy every folder from workshop-kit/skills/
   into ~/.claude/skills/ (create the skills directory if it does not exist).
   Do not copy SKILLS-LIST.md — only the folders.

5. When everything is done, tell me to open the folder "my-assistant" in VS Code:
   - Mac: Cmd+Shift+P → type "open folder" → navigate to my home folder → my-assistant
   - Windows: Ctrl+Shift+P → type "open folder" → navigate to C:\Users\[my username]\my-assistant

Talk to me like I am not technical. Plain English, one step at a time.
```

**What happens next:** Claude will download your tools, install 86 skills, and set up your workspace. This takes 1–2 minutes. When it is done, it will tell you to open a new folder.

---

## Step 6 — Open Your Workspace

After Claude finishes the setup above, it will tell you to open your workspace folder. Here is how:

**Mac:**

1. Press **Cmd+Shift+P**
2. Type: **open folder**
3. Navigate to your **home folder** → **my-assistant**
4. Click **Open**

**Windows:**

1. Press **Ctrl+Shift+P**
2. Type: **open folder**
3. Navigate to **C:\Users\[your username]\my-assistant**
4. Click **Open**

**Then:**

1. VS Code will reload with your new workspace
2. You will see **CLAUDE.md** in the left panel
3. Click the **Claude icon** in the sidebar
4. Type **hello** and press Enter
5. Your assistant will introduce itself, check its tools, and start asking about your business

---

## Step 7 — Your Assistant Will Ask You 7 Questions

After opening your workspace, your assistant will ask 7 quick questions to learn about your business:

| # | Question |
|---|---|
| 1 | What is your first name? |
| 2 | What is your business called, and what do you do in one sentence? |
| 3 | Who are your customers — who do you help? |
| 4 | What is the biggest frustration or problem in your business right now? |
| 5 | What apps or tools do you use? (Gmail, Facebook, Xero, Instagram, etc.) |
| 6 | How do you prefer I communicate — casual and friendly, or professional and direct? |
| 7 | What would feel like a win for you from today? |

> After this, your assistant knows who you are. Every future conversation starts with that context already loaded.

---

## Step 8 — Connect Your Tools

These connections let your assistant do more. Now that Node.js is installed, each one takes about 1 minute.

---

### Playwright — Browser Automation

This lets your assistant open websites and do tasks in the browser for you (research, fill forms, take screenshots).

1. In the Claude chat, type this and press Enter:

```
claude mcp add playwright npx @playwright/mcp@latest --scope user
```

2. No sign-in needed — it installs automatically

---

### Google Workspace — Gmail, Calendar, Drive, Docs, Sheets, and More

This connects your Google account so your assistant can read emails, check your calendar, access Drive, and work with Docs and Sheets.

**Step 1 — Install the Google Workspace tool**

In the Claude chat, type this and press Enter:

```
npm install -g @googleworkspace/cli
```

**Step 2 — Sign in to your Google account**

Type this and press Enter:

```
gws auth login
```

A browser window will open. **Select the Google account you want to use** — double-check this is the right one. Click **Allow** through the permissions.

**Important:** The sign-in screen defaults to whichever Google account is already logged into your browser. If you have multiple accounts, make sure you pick the correct one. If the wrong account gets connected, run `gws auth logout` then `gws auth login` again.

**Step 3 — Test it**

Ask your assistant: *"What's on my calendar today?"* or *"Show me my recent emails"*

> For the full setup guide with troubleshooting, see [GOOGLE-WORKSPACE-SETUP.md](GOOGLE-WORKSPACE-SETUP.md)

---

### Phone Messaging — Choose One

You only need one messaging channel. Pick whichever app you already use: **Telegram**, **WhatsApp**, or **iMessage** (Mac only). Your assistant will recommend one based on your setup.

### Telegram — Message Your Assistant from Your Phone

This lets you chat with your assistant directly from Telegram on your phone — ask questions, request tasks, send photos, and get replies wherever you are.

**Step 1 — Install Telegram and Create a Bot**

1. Download Telegram on your phone:
   - **iPhone:** Open the App Store, search **Telegram**, tap **Get**
   - **Android:** Open Google Play, search **Telegram**, tap **Install**
2. Open Telegram and sign up with your phone number
3. Search for **@BotFather** (look for the blue checkmark) and tap **Start**
4. Send: `/newbot`
5. BotFather will ask for a **name** — type anything (e.g. "My Assistant")
6. BotFather will ask for a **username** — must end in `bot` (e.g. `my_assistant_bot`)
7. BotFather will reply with a **token** — copy the entire thing (numbers, colon, and all)

**Step 2 — Install the Telegram Plugin**

In the Claude Code chat, type:

```
/plugin install telegram@claude-plugins-official
```

Then save your bot token (replace with your actual token):

```
/telegram:configure 123456789:AAHfiqksKZ8...
```

**Step 3 — Install Bun (Required)**

The Telegram plugin runs on Bun. Install it:

**Mac/Linux:**
```
curl -fsSL https://bun.sh/install | bash
```

**Windows:**
```
powershell -c "irm bun.sh/install.ps1 | iex"
```

Close and reopen your terminal after installing.

**Step 4 — Connect and Pair**

Close Claude Code and restart it with the Telegram channel enabled:

```sh
claude --channels plugin:telegram@claude-plugins-official
```

Then on your phone, open Telegram, find your bot, tap **Start**, and send any message. The bot will reply with a **6-character code**. Back in Claude Code, type:

```
/telegram:access pair <code>
```

Your next message to the bot will reach your assistant.

**Step 5 — Lock Down Access (Recommended)**

Once you are paired, stop strangers from getting pairing codes:

```
/telegram:access policy allowlist
```

> For the full guide with troubleshooting, see [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md)

> **Prefer a different app?** See [iMessage (Mac only)](#imessage--message-your-assistant-from-your-iphone-mac-only) or WhatsApp below.

---

### iMessage — Message Your Assistant from Your iPhone (Mac Only)

If you use a Mac, you can text your assistant directly from iMessage — no extra apps needed. Messages go through your local Messages database, so everything stays on your machine.

**Step 1 — Grant Full Disk Access**

Your Mac needs to let Claude Code read your Messages database. The first time it tries, macOS will pop up a permission prompt — click **Allow**.

If the prompt doesn't appear, grant it manually:
1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click the **+** button and add your terminal app (Terminal, iTerm, or VS Code)
3. Toggle it **on**

**Step 2 — Install Bun (Required)**

The iMessage plugin runs on Bun. Install it:

**Mac:**
```
curl -fsSL https://bun.sh/install | bash
```

Close and reopen your terminal after installing.

**Step 3 — Install the iMessage Plugin**

In the Claude Code chat, type:

```
claude plugin install imessage@claude-plugins-official
```

No tokens or passwords needed.

**Step 4 — Connect and Test**

Close Claude Code and restart it with the iMessage channel enabled:

```sh
claude --channels plugin:imessage@claude-plugins-official
```

Then open the Messages app on your Mac or iPhone and **text yourself**. The message reaches your assistant immediately — no pairing codes needed.

> The first reply triggers a macOS prompt: "Terminal wants to control Messages." Click **OK**.

**Step 5 — Allow Other Contacts (Optional)**

By default, only your own messages reach the assistant. To allow someone else:

```
/imessage:access allow +15551234567
```

> For the full guide with troubleshooting, see [IMESSAGE-SETUP.md](IMESSAGE-SETUP.md)

> **Want multiple channels?** Launch with: `claude --channels plugin:telegram@claude-plugins-official plugin:imessage@claude-plugins-official`
>
> **Prefer a different app?** See [Telegram](#telegram--message-your-assistant-from-your-phone) or WhatsApp above.

---

## After Connecting Tools

**Restart Claude Code** to make sure all tools are active.

To check what is connected, ask your assistant: *"What tools do you have connected?"*

---

## What You Can Do Now

| Task | What to Say |
|---|---|
| **Research your competitors** | "Research my top 3 competitors and tell me what they do better" |
| **Write a sales email** | "Write a cold outreach email for [my ideal customer]" |
| **Create social content** | "Write me 5 LinkedIn posts about [topic]" |
| **Analyse a market** | "What are the trends in [my industry] right now?" |
| **Plan your week** | "Help me plan my most important tasks for this week" |
| **Write a blog post** | "Write a 1000-word blog post about [topic] for my website" |
| **Check your email** | "Summarise my unread emails" (requires Gmail connection) |
| **Automate a browser task** | "Go to [website] and find [information]" (requires Playwright) |

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
| VS Code | [code.visualstudio.com](https://code.visualstudio.com) |
| Git for Windows | [git-scm.com/download/win](https://git-scm.com/download/win) |
| Node.js | [nodejs.org](https://nodejs.org) |
| Selr AI | [selrai.com.au](https://selrai.com.au) |
| Email Luke | [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## If Something Breaks

> **Don't worry. Everything is fixable.**

| Problem | Solution |
|---|---|
| "git is not recognized" (Windows) | Go back to the "Windows Users Only" section and follow the PATH fix steps |
| Skills not showing up | Close VS Code completely and reopen it. Skills load on fresh start. |
| Claude keeps asking to set up | Start a new conversation — your assistant will remember your setup status automatically |
| Claude login loop | Ask your assistant to run: `claude logout` then `claude login` |
| Mac popup about developer tools | Click "Install" (NOT "Get Xcode") and wait 3–5 minutes |
| Google connected to wrong account | Run `gws auth logout` then `gws auth login` and select the correct account |
| Node.js "command not found" | Restart VS Code completely, or reinstall from [nodejs.org](https://nodejs.org) |
| Telegram bot not responding | Make sure Claude Code is running with `--channels plugin:telegram@claude-plugins-official`. See [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md) |
| iMessage not working | Grant Full Disk Access to your terminal, then restart with `--channels plugin:imessage@claude-plugins-official`. See [IMESSAGE-SETUP.md](IMESSAGE-SETUP.md) |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

Your assistant is designed to handle problems too — just describe what happened in plain English and it will figure it out.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
