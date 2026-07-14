---
title: Claude Code - Full Setup Guide
version: 2.0
date: 2026-03-27
---

# Claude Code - Your AI Business Assistant

> **Keep this page open on your screen throughout the setup.** Everything you need is right here.

Today you are setting up a personal AI assistant that lives on YOUR computer. It learns about your business, remembers everything, and has <!-- skills-audit:total -->204<!-- /skills-audit:total --> specialist skills built in.

---

## What You Are Building

| What | Description |
|---|---|
| **Your AI Assistant** | Runs locally on your computer. Knows your business. |
| **Browser Control** | Can open websites and automate tasks for you |
| **<!-- skills-audit:total -->204<!-- /skills-audit:total --> Skills** | Research, copywriting, sales emails, competitor analysis, and more |
| **Memory System** | Saves what it learns about you and your business |

---

## Step 1 - Create a Claude Account

1. Go to [**claude.ai**](https://claude.ai)
2. Click **"Get started"** - the easiest option is **"Continue with Google"**
3. Once signed in, go to **Settings** (click your name, bottom-left) → **Billing**
4. Upgrade to **Claude Max** ($100 USD/month) - this is required for Claude Code to work

Done when: You see "Max" next to your plan name in Settings → Billing.

<details>
<summary>How to upgrade to Claude Max</summary>

1. Go to [claude.ai](https://claude.ai) and log in
2. Click your profile photo (bottom left)
3. Click **Settings → Billing**
4. Click **Upgrade** and choose **Claude Max** - $100 USD/month

Without Claude Max, Claude Code will not work.

</details>

---

## Step 2 - Install Claude Desktop

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

> **Prefer VS Code?** The old "VS Code + Claude Code extension" path still works and is supported as an advanced option - see [vscode](../extend/vscode.md). We don't recommend it for first-time users.

---

## Step 4 - Install Node.js (and Bun if you want messaging)

**Node.js is required for everyone.** Your assistant needs it to connect Gmail, Calendar, browser automation, and most other tools.

**Bun is only required if you plan to use a messaging channel** - Telegram, WhatsApp, or iMessage. If you are not using any of those, you can skip the Bun section below. (You can also come back to it later - each messaging setup section further down this page repeats the Bun install for anyone who skipped it here.)

| If you plan to use… | Install Node.js? | Install Bun? |
|---|---|---|
| Email, Calendar, browser automation, CRM, accounting, etc. | Yes | No |
| Telegram, WhatsApp, or iMessage | Yes | Yes |

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

### Install Bun (optional - only if you want messaging)

**Skip this section if you are not planning to connect Telegram, WhatsApp, or iMessage.** Bun is only used by those three messaging channels. Everything else in the workshop kit runs on Node.js alone.

If you do want messaging now, install Bun:

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

## Step 5 - Open Your Workspace Folder, Then Paste the Setup Prompt

You will create your assistant's workspace folder on your **Desktop** (so you can always find it), open Claude Code in that folder, then paste the setup prompt.

### Step 5a - Create the workspace folder and open it

1. In **Claude Desktop**, start a **new Code session**
2. The file picker will open. In the left sidebar, click **Desktop**
3. Click the **New Folder** button at the top (Mac) or right-click in the empty area and choose **New → Folder** (Windows)
4. Name the new folder exactly: **my-assistant**
5. Click **Open** (or **Select Folder** on Windows) so the Code session opens IN that folder

You should now have a Code session running at `~/Desktop/my-assistant/`. The chat panel is empty and waiting for input.

### Step 5b - Paste the setup prompt

1. **Copy the entire prompt below** and paste it into the chat
2. Press **Enter** and follow what Claude tells you

### The Setup Prompt - Copy Everything Below

````
I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

The Code session you are running in right now is open at my workspace folder
(`~/Desktop/my-assistant/`). All of the file drops below go INTO this current
folder. Do not create a separate workspace anywhere else.

1. Make sure Node.js is installed. First check by running `node --version`.
   If that prints a version number, Node is already installed - skip the rest of
   this step. If it says "command not found" (or similar), install it now. This
   is part of setup, not something I needed to do beforehand:

   - On **Mac or Linux**, install it with nvm (the Node Version Manager). nvm
     installs Node into my home folder, so it never needs admin rights and never
     hits the permission errors a manual install can. Run:

         curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
         export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
         nvm install --lts
         nvm use --lts

     Then confirm with `node --version`. Node, npm, and npx are usable in this
     same session straight away - nothing needs to be reopened.

   - On **Windows**, install it with winget, then make it usable in THIS session
     without reopening anything:

         winget install --id OpenJS.NodeJS.LTS -e --source winget

     A Windows "allow this app to make changes?" box may appear - I just click
     Yes. When winget finishes, Node is on disk but this session's PATH has not
     picked it up yet. Refresh the PATH from the registry (machine + user) and
     check Node in ONE PowerShell command - both halves must run in the SAME
     invocation, because a fresh shell would lose the refreshed PATH:

         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); node --version

     That assignment changes the PATH for THIS process only - it never writes to
     the registry, so nothing on my machine is permanently changed and a later
     reopen behaves exactly as the proven baseline. If `node --version` now
     prints a version, Node is ready immediately and I do NOT need to reopen
     anything. For the rest of setup, prepend that same `$env:Path = ...;`
     refresh to every PowerShell command you run (each command is a new shell
     that has not seen the new PATH) - e.g. the `npx` install in step 2 becomes:

         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); npx @louphq/install selr-ai/workshop-kit --token loupit_...

     ONLY if `node --version` still fails after that refresh: tell me to fully
     quit and reopen Claude Desktop so the new tools are picked up, then come
     back to this chat and tell you I'm ready. Once I'm back, confirm with
     `node --version`. Do not ask me to reopen unless the refresh actually
     failed - it almost always works without it.

   - If neither package manager is available, open https://nodejs.org in the
     browser (Playwright) and download the LTS installer for me automatically.
     Never ask me to click through a download myself.

2. Get and run my personalised install command. The workshop kit is delivered
   privately through Loup, so I paste in my own command rather than cloning
   anything:

   - Ask me to open my Loup dashboard, click "Get install command", copy the
     whole line - it looks like
     `npx @louphq/install selr-ai/workshop-kit --token loupit_...` - and paste it
     to you here.
   - Run exactly the command I paste. The same command works on Mac and Windows.
   - Then check the kit actually downloaded before going any further. The kit
     folder is `~/.loup/selr-ai/workshop-kit`. Confirm that this folder exists
     AND that BOTH `~/.loup/selr-ai/workshop-kit/my-assistant/CLAUDE.md` and
     `~/.loup/selr-ai/workshop-kit/skills/` exist inside it.
   - If that check passes, carry on to step 3.
   - If it does NOT pass, STOP here. Do not run any of steps 3-7 - they all
     depend on the kit being downloaded, so running them now would only pile
     confusing errors on top of the real one. From here you and I fix this
     together, in this chat, until the check passes. There is no limit on how
     many tries we take, and there is no one else to bring in - we sort it out
     between us. Loop through this until the kit is there:

       a. Show me the real, unedited output of the install command - every line
          it printed, word for word. Never swallow it, shorten it, or hide it
          behind a summary; that output is what tells us what went wrong.
       b. Tell me in plain English exactly which part of the check failed:
          whether the `~/.loup/selr-ai/workshop-kit` folder is missing
          altogether, or it exists but `my-assistant/CLAUDE.md` or `skills/`
          inside it is missing - a partial, half-finished download.
       c. Give me the one targeted fix that matches what you saw:
            - If the install was refused and the kit did not download - my
              command was not accepted (by far the most common cause: my command
              has gone stale, or my access had not switched on yet) - then the
              fix is to mint a fresh command. Ask me to open my Loup dashboard,
              click "Get install command" again, copy the whole new line, and
              paste it back to you. A freshly minted command almost always
              clears it on the next try.
            - If it looks like a network or download problem - a timeout, a
              dropped connection, a half-finished download - have me check I am
              online and run the same command again.
            - For anything else, tell me plainly what the output points to and
              the single next thing to try.
       d. Let me run the fix, then re-check the folder exactly as above.

     Keep repeating a-d - with no cap on attempts - until the check passes.
     Only then carry on to step 3.

3. Copy the assistant's instructions file into my current folder:
     - `~/.loup/selr-ai/workshop-kit/my-assistant/CLAUDE.md` → `./CLAUDE.md`
   (Note: `./CLAUDE.md` means the current folder, which is `~/Desktop/my-assistant/`.)

4. Create a small marker file in my current folder so the assistant knows to
   run first-run setup the next time I say hello:
     - touch `./.first-run-pending`
   (On Windows PowerShell: `New-Item -ItemType File -Path .\.first-run-pending`.)

5. Install all <!-- skills-audit:total -->204<!-- /skills-audit:total --> skills: copy every folder from `~/.loup/selr-ai/workshop-kit/skills/`
   into `~/.claude/skills/` (create the skills directory if it does not exist).
   Do not copy `SKILLS-LIST.md` - only the folders.

6. Install the routine packager. The kit bundles a plugin that lets me turn one
   of my skills into a scheduled cloud routine. Set it up now so it is ready
   when I need it. Run both commands:
     - claude plugin marketplace add ~/.loup/selr-ai/workshop-kit
     - claude plugin install routine-installer-plugin@selrai-workshop-kit
   If either reports it is already added or installed, that is fine. Carry on.
   (The packager only becomes active after the next Claude Desktop restart;
   nothing else is needed now. Do not try to use it yet.)

7. When everything is done, print this exact block to me, formatted as shown
   (the diagram inside a fenced code block, then the markdown banner below it),
   with no extra paragraphs after it:

Here's what your assistant can now do for you:

```
                              ┌───────────────────────┐
                              │      CLAUDE CODE      │
                              │   your AI assistant   │
                              └───────────┬───────────┘
                                          │
         ┌────────────────────┬───────────┴───────────┬────────────────────┐
         ▼                    ▼                       ▼                    ▼
┌─────────────────┐  ┌─────────────────┐     ┌─────────────────┐  ┌─────────────────┐
│   204 SKILLS    │  │  42 CONNECTORS  │     │     BROWSER     │  │     MEMORY      │
│                 │  │                 │     │                 │  │                 │
│ Saves hours on: │  │ Plugs into:     │     │ On the web:     │  │ Learns you:     │
│                 │  │                 │     │                 │  │                 │
│ • Writes quotes │  │ • Your email    │     │ • Connects apps │  │ • Your style    │
│ • Chases leads  │  │ • Your calendar │     │ • Creates ads   │  │ • Your clients  │
│ • Drafts emails │  │ • Slack/Teams   │     │ • Pulls quotes  │  │ • Your projects │
│ • Files reports │  │ • Your CRM      │     │ • Fills forms   │  │ • Your team     │
│ • Cleans data   │  │ • Cloud files   │     │ • Tests apps    │  │ • No repeating  │
└─────────────────┘  └─────────────────┘     └─────────────────┘  └─────────────────┘
```

## ✅ Install complete

### Do this next

1. **Start a new Code session** in Claude Desktop
2. **Type "hi"** and press Enter

Your assistant will introduce itself and walk you through the rest from there.

---

*Why a new session? Your assistant's instructions are now in this folder, but this session started before those instructions existed. A fresh session reads them at startup.*

Talk to me like I am not technical. Plain English, one step at a time.
````

**What happens next:** Claude installs Node if it's missing, downloads the kit with your personalised install command, installs all <!-- skills-audit:total -->204<!-- /skills-audit:total --> skills, sets up the routine packager plugin, and writes its instructions into your `my-assistant` folder. This takes 1-2 minutes. When it finishes, it prints the **INSTALL COMPLETE** block - follow it.

---

## Step 6 - Start a New Code Session and Say Hello

After the install-complete block prints in Step 5, you're already inside `~/Desktop/my-assistant/`. You don't need to navigate anywhere - you just need a fresh Code session so Claude Desktop re-reads the folder and picks up the new `CLAUDE.md` your assistant just wrote.

1. In **Claude Desktop**, start a **new Code session**. The new session uses the same `my-assistant` folder you're already in - you don't need to pick a folder again.
2. The new Code session loads your workspace - you'll see `CLAUDE.md` in the file list on the left.
3. Type **hi** in the chat and press Enter.
4. Your assistant will introduce itself, check its tools, and start asking about your business.

> **If Claude Desktop does ask you to pick a folder when you start the new session**, just click `my-assistant` in the Recent list - it'll be at the top.

> **Why a new Code session at all?** The bootstrap session was started before any `CLAUDE.md` existed in this folder, so it does not see the assistant's instructions yet. Starting a new session re-reads the folder and picks them up.

---

## Step 7 - Your Assistant Will Ask You 7 Questions

After opening your workspace, your assistant will ask 7 quick questions to learn about your business:

| # | Question |
|---|---|
| 1 | What is your first name? |
| 2 | What is your business called, and what do you do in one sentence? |
| 3 | Who are your customers - who do you help? |
| 4 | What is the biggest frustration or problem in your business right now? |
| 5 | What apps or tools do you use? (Gmail, Facebook, Xero, Instagram, etc.) |
| 6 | How do you prefer I communicate - casual and friendly, or professional and direct? |
| 7 | What would feel like a win for you from today? |

> After this, your assistant knows who you are. Every future conversation starts with that context already loaded.

---

## Step 8 - Connect Your Tools

These connections let your assistant do more. Now that Node.js is installed, each one takes about 1 minute.

---

### Playwright - Browser Automation

This lets your assistant open websites and do tasks in the browser for you (research, fill forms, take screenshots). Your logins are remembered - sign in to a site once and you stay signed in for next time.

1. In the Claude chat, type this and press Enter:

```
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

2. No sign-in needed - it installs automatically.

---

### Google Workspace - Gmail, Calendar, Drive, Docs, Sheets, and More

This connects your Google account so your assistant can read emails, check your calendar, access Drive, and work with Docs and Sheets.

**Step 1 - Install the Google Workspace tool**

In the Claude chat, type this and press Enter:

```
npm install -g @googleworkspace/cli
```

**Step 2 - Sign in to your Google account**

Type this and press Enter:

```
gws auth login
```

A browser window will open. **Select the Google account you want to use** - double-check this is the right one. Click **Allow** through the permissions.

**Important:** The sign-in screen defaults to whichever Google account is already logged into your browser. If you have multiple accounts, make sure you pick the correct one. If the wrong account gets connected, run `gws auth logout` then `gws auth login` again.

**Step 3 - Test it**

Ask your assistant: *"What's on my calendar today?"* or *"Show me my recent emails"*


---

### Microsoft Outlook & 365 - Email, Calendar, OneDrive, Excel, Teams, SharePoint, OneNote

This connects your Microsoft account so your assistant can read and send emails, manage your calendar, access OneDrive, work with Excel files, search SharePoint, read OneNote, view Teams messages, and manage your contacts. No Azure account or app registration needed.

**Step 1 - Install the Microsoft 365 tool**

In the Claude chat, type this and press Enter:

```
npm install -g @pnp/cli-microsoft365
```

**Step 2 - Set up the Microsoft connection (one-time)**

```
m365 setup --interactive
```

A browser window will open and walk you through a short setup. Follow what it shows and click Allow when asked.

**Step 3 - Sign in to your Microsoft account**

```
m365 login --authType browser
```

A browser window will open. **Select the Microsoft account you want to use** - double-check it is the right one. Click **Accept** or **Allow**.

> **If the browser does not open**, run `m365 login` instead. It will show a short code - go to `https://aka.ms/devicelogin`, enter the code, and sign in.

**Step 4 - Test it**

Ask your assistant: *"Show me my unread Outlook emails"*


---

### Telegram - Message Your Assistant from Your Phone

This lets you chat with your assistant directly from Telegram on your phone - ask questions, request tasks, send photos, and get replies wherever you are.

**Step 1 - Install Telegram and Create a Bot**

1. Download Telegram on your phone:
   - **iPhone:** Open the App Store, search **Telegram**, tap **Get**
   - **Android:** Open Google Play, search **Telegram**, tap **Install**
2. Open Telegram and sign up with your phone number
3. Search for **@BotFather** (look for the blue checkmark) and tap **Start**
4. Send: `/newbot`
5. BotFather will ask for a **name** - type anything (e.g. "My Assistant")
6. BotFather will ask for a **username** - must end in `bot` (e.g. `my_assistant_bot`)
7. BotFather will reply with a **token** - copy the entire thing (numbers, colon, and all)

**Step 2 - Install Bun (skip if you already installed it in Step 4 above)**

The Telegram plugin runs on Bun. If you already installed Bun back in Step 4, skip ahead to Step 3. Otherwise, install it now:

**Mac/Linux:**
```
curl -fsSL https://bun.sh/install | bash
```

**Windows:**
```
powershell -c "irm bun.sh/install.ps1 | iex"
```

Close and reopen your terminal after installing.

**Step 3 - Install the Telegram Plugin**

Open Claude Desktop's terminal (the panel at the bottom of a Code session - use the View menu to show it if it's hidden), then run:

```
claude plugin install telegram@claude-plugins-official
```

Then save your bot token (replace with your actual token):

```
/telegram:configure 123456789:AAHfiqksKZ8...
```

Close and reopen your terminal after installing.

**Step 4 - Connect and Pair**

Close Claude Code and restart it with the Telegram channel enabled:

```sh
claude --channels plugin:telegram@claude-plugins-official
```

Then on your phone, open Telegram, find your bot, tap **Start**, and send any message. The bot will reply with a **6-character code**. Back in Claude Code, type:

```
/telegram:access pair <code>
```

Your next message to the bot will reach your assistant.

**Step 5 - Lock Down Access (Recommended)**

Once you are paired, stop strangers from getting pairing codes:

```
/telegram:access policy allowlist
```


> **Prefer a different app?** See [iMessage (Mac only)](#imessage--message-your-assistant-from-your-iphone-mac-only) below.

---

### iMessage - Message Your Assistant from Your iPhone (Mac Only)

If you use a Mac, you can text your assistant directly from iMessage - no extra apps needed. Messages go through your local Messages database, so everything stays on your machine.

**Step 1 - Grant Full Disk Access**

Your Mac needs to let Claude Code read your Messages database. The first time it tries, macOS will pop up a permission prompt - click **Allow**.

If the prompt doesn't appear, grant it manually:
1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click the **+** button and add the **Claude** app (Claude Desktop)
3. Toggle it **on**

**Step 2 - Install Bun (skip if you already installed it in Step 4 above)**

The iMessage plugin runs on Bun. If you already installed Bun back in Step 4, skip ahead to Step 3. Otherwise, install it now:

**Mac:**
```
curl -fsSL https://bun.sh/install | bash
```

Close and reopen your terminal after installing.

**Step 3 - Install the iMessage Plugin**

Open Claude Desktop's terminal (the panel at the bottom of a Code session - use the View menu to show it if it's hidden), then run:

```
claude plugin install imessage@claude-plugins-official
```

No tokens or passwords needed.

**Step 4 - Connect and Test**

Close Claude Code and restart it with the iMessage channel enabled:

```sh
claude --channels plugin:imessage@claude-plugins-official
```

Then open the Messages app on your Mac or iPhone and **text yourself**. The message reaches your assistant immediately - no pairing codes needed.

> The first reply triggers a macOS prompt: "Terminal wants to control Messages." Click **OK**.

**Step 5 - Allow Other Contacts (Optional)**

By default, only your own messages reach the assistant. To allow someone else:

```
/imessage:access allow +15551234567
```


> **Want multiple channels?** Launch with: `claude --channels plugin:telegram@claude-plugins-official plugin:imessage@claude-plugins-official`
>
> **Prefer a different app?** See [Telegram](#telegram--message-your-assistant-from-your-phone) above or [WhatsApp](#whatsapp--message-your-assistant-from-your-phone) below.

---

### WhatsApp - Message Your Assistant from Your Phone

This lets you chat with your assistant directly from WhatsApp - ask questions, request tasks, and get replies wherever you are. It connects using the same QR code method as WhatsApp Web - no bot tokens or API keys needed.

**Step 1 - Install Bun (skip if you already installed it in Step 4 above)**

The WhatsApp channel runs on Bun. If you already installed Bun back in Step 4, skip ahead to Step 2. Otherwise, install it now:

**Mac/Linux:**
```
curl -fsSL https://bun.sh/install | bash
```

**Windows:**
```
powershell -c "irm bun.sh/install.ps1 | iex"
```

Close and reopen your terminal after installing.

**Step 2 - Install the WhatsApp Channel**

Open Claude Desktop's terminal (the panel at the bottom of a Code session - use the View menu to show it if it's hidden), then run the commands for your shell.

*Mac / Linux (bash, zsh):*
```bash
cd ~/.loup/selr-ai/workshop-kit/whatsapp-channel && bun install
```

*Windows (PowerShell):*
```powershell
cd $HOME\workshop-kit\whatsapp-channel
bun install
```

*Windows (Command Prompt):*
```cmd
cd %USERPROFILE%\.loup\selr-ai\workshop-kit\whatsapp-channel
bun install
```

**Step 3 - Connect**

No extra config needed - the whatsapp-channel folder already has its own config. Open a terminal and run the commands for your shell. Environment variables are set differently in each one - paste the block that matches yours.

*Mac / Linux (bash, zsh):*
```bash
cd ~/.loup/selr-ai/workshop-kit/whatsapp-channel
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
cd %USERPROFILE%\.loup\selr-ai\workshop-kit\whatsapp-channel
set WA_AUTO_OPEN_QR=1
claude --dangerously-load-development-channels server:whatsapp
```

> If you see `'WA_AUTO_OPEN_QR=1' is not recognised` on Windows, you pasted the Mac command. Use the PowerShell or Command Prompt block instead.

A browser window will open with a QR code. On your phone, open **WhatsApp → Settings → Linked Devices → Link a Device** and scan the code.

**Step 4 - Test It (Self-Only by Default)**

By default, only **your own phone number** can message your assistant - every other number is blocked automatically. The easiest way to test is to use WhatsApp's built-in self-chat: open WhatsApp → tap the pencil icon → search for your own name → tap **Message yourself** → send "hello claude". Your assistant replies back in the self-chat.

Once that works, you can add other phone numbers via `WA_ALLOW_FROM` in `.mcp.json` - see `Connect WhatsApp` Part D.

> **Read past messages on demand:** every inbound message is saved to a persistent log, so your assistant can answer questions like *"Show me the last 10 WhatsApp messages I received"* even across sessions. See `Connect WhatsApp` Part E.


> **Want multiple channels?** You can run WhatsApp alongside Telegram and iMessage.
>
> **Prefer a different app?** See [Telegram](#telegram--message-your-assistant-from-your-phone) or [iMessage](#imessage--message-your-assistant-from-your-iphone-mac-only) above.

---

### Slack - Channels, Messages, and Team

This connects your Slack workspace so your assistant can list channels, read recent messages, post to channels, reply in threads, add reactions, and search for users - all through plain English.

**Step 1 - Create a Slack connection app**

1. Open **https://api.slack.com/apps** and sign in
2. Click **Create New App** → **From scratch**
3. Name it **Claude Assistant**, pick your workspace, click **Create App**
4. Click **OAuth & Permissions** in the left menu
5. Under **Bot Token Scopes**, add these six permissions:
   - `channels:history`, `channels:read`, `chat:write`, `reactions:write`, `users:read`, `users.profile:read`
6. Scroll to the top and click **Install to Workspace** → **Allow**
7. Copy the **Bot User OAuth Token** (starts with `xoxb-`)

**Step 2 - Tell your assistant to connect**

In the Claude chat, say:

```
Help me connect my Slack workspace
```

Your assistant will ask for the token you copied, save the connection securely, and verify it works.

**Step 3 - Fully close and reopen Claude Code once**

The connection activates after a full restart (closing the chat tab alone is not enough).

**Step 4 - Test it**

Ask your assistant: *"What channels do we have in Slack?"* or *"Show me the latest messages in #general"*


> **Private channels?** Your assistant needs to be invited first. In Slack, type `/invite @Claude Assistant` in the channel you want to use.

---

### monday.com - Boards, Items, Tasks, and Team

This connects your monday.com account so your assistant can browse your boards, create and update tasks, move items between groups, post comments, and manage your team - all through plain English.

**Step 1 - Get your monday.com connection key**

1. Open **monday.com** and sign in
2. Click your **profile picture** in the bottom-left corner
3. Click **Developers** → **My Access Tokens**
4. Click **Show** (or **Generate**) and **copy** the token

> If you don't see "Developers" in the menu, try **Administration** → **Connections** → **API**.

**Step 2 - Tell your assistant to connect**

In the Claude chat, say:

```
Help me connect my monday.com account
```

Your assistant will ask for the token you copied, save the connection securely, and verify it works.

**Step 3 - Restart Claude Code once**

The connection activates after a restart.

**Step 4 - Test it**

Ask your assistant: *"Show me my boards"* or *"What's on the Roadmap board?"*


> **Don't have Node.js?** No problem - say *"Connect my monday.com using the hosted option"* and your assistant will use monday.com's hosted connection instead. No installation needed.

> **Want a safe first try?** Say *"Connect my monday.com in read-only mode"* instead - it blocks all writes so you can explore without risk. (Note: read-only is only available with the Local setup option.)

---

### Jotform - Forms, Submissions, and Intake Data

This connects your Jotform account so your assistant can browse your forms, read submissions, create and edit forms, and assign forms to teammates - all through plain English. **No API keys needed** - Jotform handles the sign-in in your browser.

**Step 1 - Tell your assistant to connect**

In the Claude chat, say:

```
Help me connect my Jotform account
```

Your assistant will save the connection settings and ask you to restart Claude Code once.

**Step 2 - Restart Claude Code**

Close and reopen Claude Code so the new connection becomes active.

**Step 3 - Sign in to Jotform once in your browser**

Tell your assistant: *"Connect to my Jotform now"*. A browser window will pop up:

1. Sign in with your Jotform email and password
2. Click **Allow** on the permission screen
3. Come back to Claude Code

That's it. Your assistant will confirm the connection works.

**Step 4 - Test it**

Ask your assistant: *"Show me my Jotform forms"* or *"How many submissions did the contact form get this week?"*


> **Works on every plan** - Free, Bronze, Silver, Gold, and Enterprise. Free tier is rate-limited to 60 requests per minute, which is plenty for normal use.

> **Sensitive data note** - submissions often contain personal information (names, emails, free-text feedback). Your assistant will summarise rather than dump raw entries into the chat unless you ask.

---

### More Connectors - Set Up After the Workshop

The tools above cover the most common setups. Once you are up and running, your assistant can also connect to:

| Tool | What It Plugs Into | Guide |
|---|---|---|
| **HubSpot** | CRM - contacts, deals, companies, notes | `Connect HubSpot` |
| **GoHighLevel** | All-in-one CRM and marketing platform | `Connect GoHighLevel` |
| **Stripe** | Payments, invoices, subscriptions, refunds | `Connect Stripe` |
| **Xero** | Accounting - invoices, contacts, P&L | `Connect Xero` |
| **QuickBooks** | Accounting - invoices, customers, P&L | `Connect QuickBooks` |
| **Shopify** | Online store - products, orders, inventory | `Connect Shopify` |
| **Square** | Payments, orders, customers, bookings | `Connect Square` |
| **GitHub** | Repos, issues, pull requests, CI status | `Connect GitHub` |
| **CircleCI** | Build pipelines, logs, flaky tests | `Connect CircleCI` |
| **Notion** | Pages, databases, notes | `Connect Notion` |
| **Google Chat** | Google Workspace messaging | `Connect Google Chat` |

Not sure which ones to connect? Ask your assistant: *"What connectors should I set up for a business like mine?"*

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

## Automation - Schedules and Loops

Your assistant can run tasks automatically. It picks the right method for the job, and if your request does not say when and where it should run, it asks you first.

| What to Say | What It Does |
|---|---|
| "Check my emails every morning at 9am" | Packages your email connection into a cloud routine that runs daily |
| "Post to social media every weekday at 10am" | Packages your social account connection into a cloud routine that runs on weekdays |
| "Monitor my website every 5 minutes" | Runs a check on a loop while your session is open |

**How it works:**
- `/loop` - repeats something while your session is open
- `/schedule` - a cloud routine that runs even when your computer is off, for tasks needing nothing from your computer
- `/package-as-routine` - also a cloud routine, but it first carries across the connections and sign-ins your task needs (email, Xero, and so on)

> **Note:** a plain `/schedule` starts fresh in the cloud and cannot see connections set up on your computer - that is what `/package-as-routine` is for.

For full details, see [automation-loop-and-schedule](../extend/automation-loop-and-schedule.md)

---

## Skills - Quick Reference

Your assistant has <!-- skills-audit:total -->204<!-- /skills-audit:total --> specialist skills covering marketing, research, strategy, AI/automation, engineering, DevOps, and design. For the full categorised list, see [skills reference](../skills/README.md).

---

## Useful Links

| Resource | Link |
|---|---|
| Claude.ai | [claude.ai](https://claude.ai) |
| Claude Desktop | [claude.ai/download](https://claude.ai/download) |
| Node.js | [nodejs.org](https://nodejs.org) |
| Claude Code Docs | [docs.anthropic.com/en/docs/claude-code](https://docs.anthropic.com/en/docs/claude-code) |
| MCP Documentation | [modelcontextprotocol.io](https://modelcontextprotocol.io) |
| Selr AI | [selrai.com.au](https://selrai.com.au) |
| VS Code (advanced fallback) | [code.visualstudio.com](https://code.visualstudio.com) - see [vscode](../extend/vscode.md) |

---

## If Something Breaks

> **Don't worry. Everything is fixable.**

| Problem | Solution |
|---|---|
| Claude Desktop sign-in loop | Sign out of claude.ai in your browser, then sign in again inside Claude Desktop. If the loop continues, restart the app. |
| Skills not showing up | Close Claude Desktop completely and reopen it. Skills load on fresh start. |
| Claude keeps asking to set up | Start a new conversation - your assistant will remember your setup status automatically |
| Claude login loop (terminal) | Ask your assistant to run: `claude logout` then `claude login` |
| Google connected to wrong account | Run `gws auth logout` then `gws auth login` and select the correct account |
| Outlook not connecting | Run `m365 logout` then `m365 login --authType browser` and select the correct account. See `Connect Outlook` |
| Outlook "Access denied" for Teams or SharePoint | Those features may need IT admin approval on work/company accounts. Personal outlook.com accounts have full access. |
| Node.js "command not found" | Restart Claude Desktop completely, or reinstall from [nodejs.org](https://nodejs.org) |
| Telegram bot not responding | Make sure Claude Code is running with `--channels plugin:telegram@claude-plugins-official`. See `Connect Telegram` |
| WhatsApp not connecting | Make sure Claude Code is running with `--dangerously-load-development-channels server:whatsapp`. See `Connect WhatsApp` |
| Something else | Describe what happened to your assistant in plain English - it will figure it out |

Your assistant is designed to handle problems too - just describe what happened in plain English and it will figure it out.

---

## Recommended Optional Plugin - Superpowers

**Superpowers** is an official Anthropic plugin that gives your assistant four engineering skills: planning complex work, diagnosing errors step by step, writing tests before code, and verifying work before claiming it's done. It's optional - your assistant works without it - but most workshop attendees install it the same day they finish setup.

**Install it:**

In a new Code session, paste these two commands one at a time (press Enter after each):

```
/plugin marketplace add anthropics/claude-plugins-official
```

```
/plugin install superpowers@claude-plugins-official
```

Claude Desktop confirms the install and the plugin is active immediately - nothing else to configure.

> **Why can't your assistant install it for you?** The `/plugin` command is run by *you*, not your assistant - a deliberate guardrail so AI can never silently install code on your machine. You paste the two lines above once, and it's done.

For the full feature list, see [claude.com/plugins/superpowers](https://claude.com/plugins/superpowers).

---

## Going Further - Claude Dispatch (Advanced)

Once you're comfortable with your assistant, **Claude Dispatch** lets you run multiple AI agents in parallel - delegating complex, multi-step work across several Claude instances at once.

> This is an advanced feature. Get your assistant working well first, then explore this.

Just ask your assistant: *"Set up Claude Dispatch."* - it walks you through the QR-code pairing conversationally.

---

*Built by Selr AI - [selrai.com.au](https://selrai.com.au)*
