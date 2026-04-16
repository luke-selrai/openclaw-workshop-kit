---
title: Claude Code — Full Setup Guide
version: 2.0
date: 2026-03-27
---

# Claude Code — Your AI Business Assistant

> **Keep this page open on your screen throughout the setup.** Everything you need is right here.

Today you are setting up a personal AI assistant that lives on YOUR computer. It learns about your business, remembers everything, and has <!-- skills-audit:total -->106<!-- /skills-audit:total --> specialist skills built in.

---

## What You Are Building

| What | Description |
|---|---|
| **Your AI Assistant** | Runs locally on your computer. Knows your business. |
| **Browser Control** | Can open websites and automate tasks for you |
| **<!-- skills-audit:total -->106<!-- /skills-audit:total --> Skills** | Research, copywriting, sales emails, competitor analysis, and more |
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

## Step 2 — Install Claude Desktop

Claude Desktop is the app where you will chat with your assistant, open your workspace folder, and run any commands it needs. One download replaces the old "VS Code + extension" setup.

**Mac:**

1. Go to [**claude.ai/download**](https://claude.ai/download)
2. Click **"Download for Mac"**
3. Open the downloaded `.dmg` file
4. Drag **Claude** into your **Applications** folder
5. Open it from Applications
6. Sign in with the Claude account you just created

**Windows:**

1. Go to [**claude.ai/download**](https://claude.ai/download)
2. Click **"Download for Windows"**
3. Run the installer and click through with the default settings
4. Open **Claude** from the Start menu
5. Sign in with the Claude account you just created

Done when: You see the main Claude window and can start a new chat.

> **Prefer VS Code?** The old "VS Code + Claude Code extension" path still works and is supported as an advanced option — see [ADVANCED-VSCODE.md](ADVANCED-VSCODE.md). We don't recommend it for first-time users.

---

## Windows Users Only — Install Git

> **Mac users: skip this section entirely.** Git installs automatically on Mac when needed.

### Download and Install

1. Go to [git-scm.com/download/win](https://git-scm.com/download/win)
2. The download should start automatically. If not, click **"Click here to download"**
3. Run the installer
4. Click **Next** through every screen — all default settings are fine
5. Click **Install**, then **Finish**

### Close and reopen Claude Desktop after installing Git

**This step is not optional.** Windows only picks up the new Git location in Claude Desktop's terminal after a full restart of the app. Completely quit Claude Desktop (don't just minimise) and reopen it before you move on.

### Verify It Worked

1. Open **Claude Desktop**, start a new **Code** session, and show the terminal panel at the bottom (use the View menu if you don't see it)
2. Type: `git --version`
3. You should see something like: `git version 2.43.0.windows.1`

If you see `git is not recognized`, the installer didn't add Git to your system PATH. Follow the fallback below.

### Fallback — If Git still isn't recognised after restarting Claude Desktop

Some Git installers do not add themselves to the system PATH. If the verification above failed, add it manually. The assistant cannot fix this for you — `git` must be available before the bootstrap can run its first command.

1. Press the **Windows key** on your keyboard
2. Type: **Environment Variables**
3. Click **"Edit the system environment variables"**
4. Click the **"Environment Variables"** button at the bottom of the window
5. In the bottom section (System variables), find the row called **Path** and click it
6. Click **Edit**
7. Click **New**
8. Type exactly: `C:\Program Files\Git\cmd`
9. Click **OK**, **OK**, **OK** to close all windows
10. **Completely quit Claude Desktop and reopen it** — the PATH change only takes effect in new processes
11. Re-run `git --version` in a new Code session to confirm

> **Why can't Claude fix this itself?** If `git` isn't on the PATH when Claude Desktop starts, the assistant's first command (`git clone …`) fails before the conversation can even begin. There's no in-session fix — the app has to restart with the new PATH before anything else works.

---

## Step 4 — Install Node.js and Bun

Node.js is needed to connect Gmail, Calendar, and browser automation. **Bun is also required** if you plan to use Telegram, WhatsApp, or iMessage. Install both now so everything is ready later.

> **Note:** If you skip Bun here, you will need to install it before setting up any messaging channel.

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
5. **Close and reopen Claude Desktop completely** after installing

### Verify Node.js

1. Open Claude Desktop, start a new Code session, and show the terminal at the bottom (View menu if hidden)
2. Type: `node --version`
3. You should see a version number like `v22.x.x`

### Install Bun

Bun is required for Telegram, WhatsApp, and iMessage integrations.

**Mac / Linux:**
```bash
curl -fsSL https://bun.sh/install | bash
```
Then close and reopen your terminal.

**Windows:**
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```
Then close and reopen Claude Desktop.

### Verify Bun
```bash
bun --version
```
You should see a version number like `1.x.x`.

---

## Step 5 — Paste the Setup Prompt

1. In **Claude Desktop**, start a **new Code session**
2. **Copy the entire prompt below** and paste it into the chat
3. Press **Enter** and follow what Claude tells you

### The Setup Prompt — Copy Everything Below

```
I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

1. Download the workshop content by running:
   git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit

   NOTE: On Mac, if a popup appears asking to install developer tools,
   tell me to click "Install" and wait a few minutes before continuing.
   On Windows, if Git is not recognised, pause and tell me to install
   Git for Windows from https://git-scm.com/download/win, then to close
   and reopen Claude Desktop before we continue.

2. Create a folder called "my-assistant" in my home directory.

3. Copy this file from the downloaded workshop-kit into my-assistant:
   - workshop-kit/my-assistant/CLAUDE.md → my-assistant/CLAUDE.md

4. Install all skills: copy every folder from workshop-kit/skills/
   into ~/.claude/skills/ (create the skills directory if it does not exist).
   Do not copy SKILLS-LIST.md — only the folders.

5. When everything is done, tell me to start a new Code session in Claude
   Desktop and click the folder icon at the top to point it at my
   "my-assistant" folder:
   - Mac: ~/my-assistant
   - Windows: C:\Users\[my username]\my-assistant

Talk to me like I am not technical. Plain English, one step at a time.
```

**What happens next:** Claude will download your tools, install <!-- skills-audit:total -->106<!-- /skills-audit:total --> skills, and set up your workspace. This takes 1–2 minutes. When it is done, it will tell you to open a new folder.

---

## Step 6 — Open Your Workspace

After Claude finishes the setup above, it will tell you to open your workspace folder. Here is how:

1. In **Claude Desktop**, start a **new Code session**
2. At the top of the Code session there is a **folder icon**. Click it.
3. Navigate to your **my-assistant** folder:
   - **Mac:** `~/my-assistant` (your home folder → my-assistant)
   - **Windows:** `C:\Users\[your username]\my-assistant`
4. Click **Open**

**Then:**

1. Claude Desktop will load your workspace — you'll see `CLAUDE.md` in the file list on the left
2. Type **hello** in the chat and press Enter
3. Your assistant will introduce itself, check its tools, and start asking about your business

> No keyboard shortcut needed — the folder icon does the whole job.

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

### Microsoft Outlook & 365 — Email, Calendar, OneDrive, Excel, Teams, SharePoint, OneNote

This connects your Microsoft account so your assistant can read and send emails, manage your calendar, access OneDrive, work with Excel files, search SharePoint, read OneNote, view Teams messages, and manage your contacts. No Azure account or app registration needed.

**Step 1 — Install the Microsoft 365 tool**

In the Claude chat, type this and press Enter:

```
npm install -g @pnp/cli-microsoft365
```

**Step 2 — Set up the Microsoft connection (one-time)**

```
m365 setup --interactive
```

A browser window will open and walk you through a short setup. Follow what it shows and click Allow when asked.

**Step 3 — Sign in to your Microsoft account**

```
m365 login --authType browser
```

A browser window will open. **Select the Microsoft account you want to use** — double-check it is the right one. Click **Accept** or **Allow**.

> **If the browser does not open**, run `m365 login` instead. It will show a short code — go to `https://aka.ms/devicelogin`, enter the code, and sign in.

**Step 4 — Test it**

Ask your assistant: *"Show me my unread Outlook emails"*

> For the full guide with troubleshooting and OS compatibility, see [OUTLOOK-SETUP.md](OUTLOOK-SETUP.md)

---

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

**Step 2 — Install Bun (Required)**

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

**Step 3 — Install the Telegram Plugin**

Open Claude Desktop's terminal (the panel at the bottom of a Code session — use the View menu to show it if it's hidden), then run:

```
claude plugin install telegram@claude-plugins-official
```

Then save your bot token (replace with your actual token):

```
/telegram:configure 123456789:AAHfiqksKZ8...
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

> **Prefer a different app?** See [iMessage (Mac only)](#imessage--message-your-assistant-from-your-iphone-mac-only) below.

---

### iMessage — Message Your Assistant from Your iPhone (Mac Only)

If you use a Mac, you can text your assistant directly from iMessage — no extra apps needed. Messages go through your local Messages database, so everything stays on your machine.

**Step 1 — Grant Full Disk Access**

Your Mac needs to let Claude Code read your Messages database. The first time it tries, macOS will pop up a permission prompt — click **Allow**.

If the prompt doesn't appear, grant it manually:
1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click the **+** button and add the **Claude** app (Claude Desktop)
3. Toggle it **on**

**Step 2 — Install Bun (Required)**

The iMessage plugin runs on Bun. Install it:

**Mac:**
```
curl -fsSL https://bun.sh/install | bash
```

Close and reopen your terminal after installing.

**Step 3 — Install the iMessage Plugin**

Open Claude Desktop's terminal (the panel at the bottom of a Code session — use the View menu to show it if it's hidden), then run:

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
> **Prefer a different app?** See [Telegram](#telegram--message-your-assistant-from-your-phone) above or [WhatsApp](#whatsapp--message-your-assistant-from-your-phone) below.

---

### WhatsApp — Message Your Assistant from Your Phone

This lets you chat with your assistant directly from WhatsApp — ask questions, request tasks, and get replies wherever you are. It connects using the same QR code method as WhatsApp Web — no bot tokens or API keys needed.

**Step 1 — Install Bun (Required)**

The WhatsApp channel runs on Bun. Install it:

**Mac/Linux:**
```
curl -fsSL https://bun.sh/install | bash
```

**Windows:**
```
powershell -c "irm bun.sh/install.ps1 | iex"
```

Close and reopen your terminal after installing.

**Step 2 — Install the WhatsApp Channel**

Open Claude Desktop's terminal (the panel at the bottom of a Code session — use the View menu to show it if it's hidden), then run the commands for your shell.

*Mac / Linux (bash, zsh):*
```bash
cd ~/workshop-kit/whatsapp-channel && bun install
```

*Windows (PowerShell):*
```powershell
cd $HOME\workshop-kit\whatsapp-channel
bun install
```

*Windows (Command Prompt):*
```cmd
cd %USERPROFILE%\workshop-kit\whatsapp-channel
bun install
```

**Step 3 — Connect**

No extra config needed — the whatsapp-channel folder already has its own config. Open a terminal and run the commands for your shell. Environment variables are set differently in each one — paste the block that matches yours.

*Mac / Linux (bash, zsh):*
```bash
cd ~/workshop-kit/whatsapp-channel
WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

*Windows (PowerShell):*
```powershell
cd $HOME\workshop-kit\whatsapp-channel
$env:WA_AUTO_OPEN_QR = "1"
claude --dangerously-load-development-channels server:whatsapp
```

*Windows (Command Prompt):*
```cmd
cd %USERPROFILE%\workshop-kit\whatsapp-channel
set WA_AUTO_OPEN_QR=1
claude --dangerously-load-development-channels server:whatsapp
```

> If you see `'WA_AUTO_OPEN_QR=1' is not recognised` on Windows, you pasted the Mac command. Use the PowerShell or Command Prompt block instead.

A browser window will open with a QR code. On your phone, open **WhatsApp → Settings → Linked Devices → Link a Device** and scan the code.

**Step 4 — Test It (Self-Only by Default)**

By default, only **your own phone number** can message your assistant — every other number is blocked automatically. The easiest way to test is to use WhatsApp's built-in self-chat: open WhatsApp → tap the pencil icon → search for your own name → tap **Message yourself** → send "hello claude". Your assistant replies back in the self-chat.

Once that works, you can add other phone numbers via `WA_ALLOW_FROM` in `.mcp.json` — see [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) Part D.

> **Read past messages on demand:** every inbound message is saved to a persistent log, so your assistant can answer questions like *"Show me the last 10 WhatsApp messages I received"* even across sessions. See [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) Part E.

> For the full guide with troubleshooting, see [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md)

> **Want multiple channels?** You can run WhatsApp alongside Telegram and iMessage.
>
> **Prefer a different app?** See [Telegram](#telegram--message-your-assistant-from-your-phone) or [iMessage](#imessage--message-your-assistant-from-your-iphone-mac-only) above.

---

### Jotform — Forms, Submissions, and Intake Data

This connects your Jotform account so your assistant can browse your forms, read submissions, create and edit forms, and assign forms to teammates — all through plain English. **No API keys needed** — Jotform handles the sign-in in your browser.

**Step 1 — Tell your assistant to connect**

In the Claude chat, say:

```
Help me connect my Jotform account
```

Your assistant will save the connection settings and ask you to restart Claude Code once.

**Step 2 — Restart Claude Code**

Close and reopen Claude Code so the new connection becomes active.

**Step 3 — Sign in to Jotform once in your browser**

Tell your assistant: *"Connect to my Jotform now"*. A browser window will pop up:

1. Sign in with your Jotform email and password
2. Click **Allow** on the permission screen
3. Come back to Claude Code

That's it. Your assistant will confirm the connection works.

**Step 4 — Test it**

Ask your assistant: *"Show me my Jotform forms"* or *"How many submissions did the contact form get this week?"*

> For the full guide with troubleshooting, see [JOTFORM-SETUP.md](JOTFORM-SETUP.md)

> **Works on every plan** — Free, Bronze, Silver, Gold, and Enterprise. Free tier is rate-limited to 60 requests per minute, which is plenty for normal use.

> **Sensitive data note** — submissions often contain personal information (names, emails, free-text feedback). Your assistant will summarise rather than dump raw entries into the chat unless you ask.

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

## Automation — Schedules and Loops

Your assistant can run tasks automatically on a schedule or in a loop.

| What to Say | What It Does |
|---|---|
| "Check my emails every morning at 9am" | Creates a scheduled task that runs daily |
| "Post to social media every weekday at 10am" | Creates a recurring automation |
| "Monitor my website every 5 minutes" | Runs a check on a loop |

**How it works:**
- `/schedule` — creates a task that runs at set times (like a cron job)
- `/loop` — runs something repeatedly on an interval

> **Note:** `/schedule` runs in the cloud — your computer does not need to be on. `/loop` runs locally and requires your computer to be on with Claude Code running.

For full details, see [AUTOMATION-LOOP-AND-SCHEDULE.md](AUTOMATION-LOOP-AND-SCHEDULE.md)

---

## Your 95 Skills — Quick Reference

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
| Workshop Kit (GitHub) | [github.com/selrai-company/claude-workshop-kit](https://github.com/selrai-company/claude-workshop-kit) |
| Claude.ai | [claude.ai](https://claude.ai) |
| Claude Desktop | [claude.ai/download](https://claude.ai/download) |
| Git for Windows | [git-scm.com/download/win](https://git-scm.com/download/win) |
| Node.js | [nodejs.org](https://nodejs.org) |
| Claude Code Docs | [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code) |
| MCP Documentation | [modelcontextprotocol.io](https://modelcontextprotocol.io) |
| Selr AI | [selrai.com.au](https://selrai.com.au) |
| Email Luke | [luke@selrai.com.au](mailto:luke@selrai.com.au) |
| VS Code (advanced fallback) | [code.visualstudio.com](https://code.visualstudio.com) — see [ADVANCED-VSCODE.md](ADVANCED-VSCODE.md) |

---

## If Something Breaks

> **Don't worry. Everything is fixable.**

| Problem | Solution |
|---|---|
| "git is not recognized" (Windows) | Install [Git for Windows](https://git-scm.com/download/win), then **fully quit and reopen Claude Desktop** (required — the new PATH only applies to Claude Desktop after a restart). If it still isn't recognised, Git's installer didn't add itself to PATH — follow the [Fallback section](#fallback--if-git-still-isnt-recognised-after-restarting-claude-desktop) above, then restart Claude Desktop again. |
| Mac popup: "command line tools are required" | Click **Install** (NOT "Get Xcode") and wait 3–5 minutes. Your assistant pauses until the install finishes. |
| Claude Desktop sign-in loop | Sign out of claude.ai in your browser, then sign in again inside Claude Desktop. If the loop continues, restart the app. |
| Skills not showing up | Close Claude Desktop completely and reopen it. Skills load on fresh start. |
| Claude keeps asking to set up | Start a new conversation — your assistant will remember your setup status automatically |
| Claude login loop (terminal) | Ask your assistant to run: `claude logout` then `claude login` |
| Google connected to wrong account | Run `gws auth logout` then `gws auth login` and select the correct account |
| Outlook not connecting | Run `m365 logout` then `m365 login --authType browser` and select the correct account. See [OUTLOOK-SETUP.md](OUTLOOK-SETUP.md) |
| Outlook "Access denied" for Teams or SharePoint | Those features may need IT admin approval on work/company accounts. Personal outlook.com accounts have full access. |
| Node.js "command not found" | Restart Claude Desktop completely, or reinstall from [nodejs.org](https://nodejs.org) |
| Telegram bot not responding | Make sure Claude Code is running with `--channels plugin:telegram@claude-plugins-official`. See [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md) |
| WhatsApp not connecting | Make sure Claude Code is running with `--dangerously-load-development-channels server:whatsapp`. See [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

Your assistant is designed to handle problems too — just describe what happened in plain English and it will figure it out.

---

## Going Further — Claude Dispatch (Advanced)

Once you're comfortable with your assistant, **Claude Dispatch** lets you run multiple AI agents in parallel — delegating complex, multi-step work across several Claude instances at once.

> This is an advanced feature. Get your assistant working well first, then explore this.

See [dispatch/DISPATCH-SETUP.md](dispatch/DISPATCH-SETUP.md) for setup instructions.

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
