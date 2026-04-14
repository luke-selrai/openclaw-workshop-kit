---
title: WhatsApp Channel Setup Guide
version: 1.1
date: 2026-04-14
---

# WhatsApp — Setup Guide

This guide walks you through connecting WhatsApp to Claude Code so your assistant can receive and reply to messages on your phone. Once connected, you can message your assistant from anywhere using the WhatsApp app you already know — like having your AI assistant in your pocket.

---

## ⚠️ STOP — Read This Before You Do Anything

This channel uses an **unofficial** WhatsApp Web protocol (Baileys). It is **not endorsed by Meta**.

| Risk | What Happens |
|---|---|
| **Temporary ban** | Your number is blocked for 24–72 hours. WhatsApp shows a countdown timer. |
| **Permanent ban** | Your number **can never use WhatsApp again**. All chats, groups, and history are gone — unrecoverable. |

**Use a secondary phone number (cheap prepaid SIM) — not your real number.**

If something goes wrong with a secondary number, you lose nothing important. If something goes wrong with your primary number, you lose your entire WhatsApp account permanently.

> This is a real risk, not a disclaimer. Several users have been permanently banned. Use a secondary number.

By continuing past this point, you accept this risk.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A WhatsApp account on your phone (free — download from the App Store or Google Play)

That's it. Don't worry about installing Bun or opening terminals yourself — the fast-setup prompt in Part A handles it for you.

---

## Part A — Install the WhatsApp Channel (Fast Setup)

**You don't have to run any commands yourself.** In your Claude Code chat, just say:

> *"Set up the WhatsApp channel for me."*

Your assistant will load the `whatsapp-connector` skill, detect your OS and shell, install the helper tool if needed, install the channel's packages, and hand you the exact launch command to run. It walks you through it one step at a time in plain English — just like the rest of the workshop-kit setup.

**The skill also handles everyday use** after setup: sending messages, reading past messages via the history log, managing the allowlist, and troubleshooting the QR pairing flow. Just ask in natural language.

<details>
<summary><strong>Advanced: paste this long prompt instead (e.g. if the skill didn't auto-load)</strong></summary>

If for some reason your assistant doesn't pick up the `whatsapp-connector` skill automatically, you can paste this prompt to kick off the same flow manually:

```
I want to set up the WhatsApp channel for Claude Code.

Do these steps for me, one at a time, explaining in plain English what you are
doing. Use the correct commands for my operating system — detect whether I am
on Mac or Windows, and if Windows, detect whether my terminal is PowerShell or
Command Prompt.

1. Check whether Bun is installed by running `bun --version`. If it is not,
   install it using the correct command for my OS:
   - Mac / Linux: curl -fsSL https://bun.sh/install | bash
   - Windows: powershell -c "irm bun.sh/install.ps1 | iex"
   After installing, tell me to close and reopen my terminal, then check again.

2. Change into the whatsapp-channel folder inside workshop-kit and run
   `bun install` to download the channel's packages.

3. When that finishes, give me EXACTLY the command to copy and paste to start
   Claude Code with the WhatsApp channel — using the correct syntax for my
   shell (bash / zsh / PowerShell / Command Prompt). Include the
   WA_AUTO_OPEN_QR=1 environment variable so the QR page opens automatically.

   IMPORTANT: Warn me clearly that before I run this command, I need to:
   (a) close THIS current Claude Code session completely, and
   (b) open a fresh terminal window to run the command in.
   Explain that the launch command starts a new Claude Code session with the
   WhatsApp channel loaded, so this current chat needs to end first.

4. Remind me that only my own phone number will be allowed to message Claude
   by default, and that the easiest way to test is WhatsApp's "Message
   yourself" self-chat.

Talk to me like I am not technical. Go one step at a time and pause between
steps — wait for me to confirm I'm ready with "done", "ok", "next", or
similar before moving on. If I seem stuck or confused, ask me what I'm
seeing on my screen before continuing.
```

**What happens next:** Your assistant will check for Bun, install it if needed, install the WhatsApp channel's packages, and give you the exact command to launch Claude Code with WhatsApp. It will also tell you if anything needs your attention (like closing and reopening your terminal after installing Bun).

Once your assistant tells you the launch command, run it and move on to **Part B — Scan the QR Code**.

</details>

---

<details>
<summary><strong>Prefer to do it manually? Click here for the step-by-step commands.</strong></summary>

### Manual installation (for those who prefer typing commands themselves)

**Step 1 — Open a terminal**

- **Mac:** Press `Cmd + Space`, type **Terminal**, press Enter.
- **Windows:** Press the Windows key, type **PowerShell**, press Enter. (PowerShell is recommended — it comes built-in and works with all our commands.)
- **VS Code (any OS):** Click **Terminal** in the top menu → **New Terminal**. ⚠️ On Windows, check the top-right corner of the terminal panel — it should say `powershell` or `pwsh`. If it says `cmd`, `bash`, `wsl`, or something else, click the ⌄ dropdown next to the + button and pick **PowerShell**.

### Which terminal am I in?

Check your prompt to confirm which shell you're in before picking a command block:

- **macOS / Linux** — prompt ends in `$` or `%` (e.g. `you@mac ~ %`). You're in **bash** or **zsh** — use the **Mac / Linux** blocks.
- **Windows PowerShell** — prompt starts with `PS` (e.g. `PS C:\Users\you>`). Use the **Windows (PowerShell)** blocks.
- **Windows Command Prompt** — prompt looks like `C:\Users\you>` with no `PS`. Use the **Windows (Command Prompt)** blocks.

**Step 2 — Install Bun (one-time, skip if already installed)**

Check first: type `bun --version` and press Enter. If you see a version number, skip this step.

**Mac / Linux (bash, zsh):**
```bash
curl -fsSL https://bun.sh/install | bash
```

**Windows (PowerShell):**
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```

Then **close and reopen your terminal** so `bun` is available. Verify with `bun --version`.

**Step 3 — Install the WhatsApp channel's packages**

**Mac / Linux (bash, zsh):**
```bash
cd ~/workshop-kit/whatsapp-channel && bun install
```

**Windows (PowerShell):**
```powershell
cd $HOME\workshop-kit\whatsapp-channel
bun install
```

**Windows (Command Prompt):**
```cmd
cd %USERPROFILE%\workshop-kit\whatsapp-channel
bun install
```

> This downloads the packages the channel needs. Takes about 30 seconds.

**Step 4 — No extra config needed**

The `whatsapp-channel` folder already has everything Claude Code needs. You don't have to edit or create any files — just launch Claude Code from inside this folder (see Part B).

</details>

---

## Part B — Scan the QR Code

WhatsApp connects by scanning a QR code — the same way you link WhatsApp Web on a computer. No bot tokens or API keys needed.

> **Heads up: the launch command starts a *new* Claude Code session.** The chat you used for the fast-setup prompt in Part A is a separate session — you can close it (or leave it open, but you won't use it again for this setup). When you run the launch command below, a fresh Claude Code session starts with the WhatsApp channel loaded, and the test in Part C happens in that new session.

**If you used the fast-setup prompt in Part A**, your assistant has already given you the exact launch command. Close that chat, open a fresh terminal, paste the command there, and jump to Step 2 below.

**If you did the manual install**, keep reading.

**Step 1 — Start Claude Code with the WhatsApp Channel**

Close your Claude Code session completely, then open a terminal and run the commands for your shell. You must `cd` into the `whatsapp-channel` folder first — Claude Code needs to be launched from inside that folder so it picks up the WhatsApp configuration.

> **What does `--dangerously-load-development-channels` mean?** It sounds scary but isn't. "Channels" (WhatsApp, Telegram, iMessage) are a preview feature Anthropic hasn't turned on by default yet, and the flag name is their internal label for "opt into preview features." Nothing destructive happens when you use it.

**Mac / Linux (bash, zsh):**
```bash
cd ~/workshop-kit/whatsapp-channel
WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

**Windows (PowerShell):**
```powershell
cd $HOME\workshop-kit\whatsapp-channel
$env:WA_AUTO_OPEN_QR = "1"
claude --dangerously-load-development-channels server:whatsapp
```

**Windows (Command Prompt):**
```cmd
cd %USERPROFILE%\workshop-kit\whatsapp-channel
set WA_AUTO_OPEN_QR=1
claude --dangerously-load-development-channels server:whatsapp
```

> **Why the command looks different on each OS:** Mac and Linux shells let you set an environment variable inline at the start of a command (`NAME=value program`). PowerShell and Command Prompt do not — you have to set the variable on its own line first. If you paste the Mac command into PowerShell you'll see an error like *"The term 'WA_AUTO_OPEN_QR=1' is not recognised"*. That's why we show all three.

> You only need `WA_AUTO_OPEN_QR=1` on the **first run** to get the QR page. On later runs the saved credentials are reused and no QR is needed — just run `claude --dangerously-load-development-channels server:whatsapp`.

**Step 2 — Scan the QR Code**

A browser window will open showing a QR code. On your phone:

1. Open **WhatsApp**
2. Go to **Settings > Linked Devices**
3. Tap **Link a Device**
4. Point your phone camera at the QR code on your computer screen

> Make sure you scan from inside WhatsApp's "Link a Device" screen — not from your phone's camera app.

> **Browser didn't open automatically?** Open any browser and go to [http://127.0.0.1:8787](http://127.0.0.1:8787) — the QR code will be there. This happens sometimes on Windows if your default browser isn't set up.

Once linked, your session persists across restarts. You won't need to scan again unless the session expires.

---

## Part C — Test It (Self-Only by Default)

By default, **only your own phone number** can message your assistant — every other number is blocked automatically. Don't change this yet. Get the basics working with your own phone first, then add other numbers later (see Part D).

### Step 1 — Confirm the channel is live

Before you send a test message, glance at the terminal where you started Claude Code. When everything is working, you'll see something like this soon after scanning the QR code:

```
[whatsapp-channel] MCP server connected to Claude Code.
[whatsapp-channel] Auth dir: /Users/you/.claude/whatsapp-channel/auth
[whatsapp-channel] Only your linked phone can message Claude (self-only mode).
[whatsapp-channel] Set WA_ALLOW_FROM=+1234567890 to allow additional numbers.
[whatsapp-channel] QR login page: http://127.0.0.1:8787
[whatsapp-channel] WhatsApp connected!
[whatsapp-channel] Linked to: +1234567890
[whatsapp-channel] WhatsApp monitor active. Listening for messages...
```

**The two lines that mean it's working:**

1. ✅ **`Only your linked phone can message Claude (self-only mode)`** — no one else can reach your assistant yet.
2. ✅ **`Linked to: +…` followed by `Listening for messages...`** — the channel is live and waiting.

**If you *don't* see `Linked to:`**, the QR scan didn't complete. Go back to [Part B](#part-b--scan-the-qr-code) and try again.

> **Tip:** The terminal keeps printing status lines as long as Claude Code is open. You can leave it running in the background — it won't disturb you.

### Step 2 — Send yourself a test message

The easiest way to test is to **message yourself** using WhatsApp's built-in self-chat. You don't need a second phone.

1. On your phone, open **WhatsApp**
2. Tap the **pencil / new-chat** icon
3. Search for **your own name**
4. Tap **Message yourself** (WhatsApp shows this as the first result)
5. Type `hello claude` and send it

Within about 5–15 seconds, your assistant should reply back to you in the self-chat. If you don't get a reply after 30 seconds, scroll down to the [Troubleshooting](#troubleshooting) section.

🎉 **That's it — your WhatsApp channel is working.** You can now message your assistant from your phone anywhere, anytime.

---

## Part D — Allowing Other People to Message Your Assistant (Optional)

Once you've confirmed self-only mode works, you can open it up to other numbers.

**The easy way — ask your assistant to do it for you.** You don't have to edit any files by hand. In Claude Code, say something like:

> *"Add +14155551234 to my WhatsApp allowlist."*

Your assistant knows where the config file lives, will make the change, and tell you to restart. If you have more than one number, list them all at once:

> *"Add +14155551234 and +61412345678 to my WhatsApp allowlist."*

**Phone number format — important.** Phone numbers must include the country code with a `+` at the front and **no spaces, no dashes, no brackets**. Examples:

| Country | What it looks like |
|---|---|
| 🇺🇸 United States | `+14155551234` |
| 🇬🇧 United Kingdom | `+442071838750` |
| 🇦🇺 Australia | `+61412345678` |

If you're not sure of someone's country code, ask your assistant: *"What's the country code for Spain?"*

**If you want to do it by hand instead (advanced).** Open the `.mcp.json` file inside the `whatsapp-channel` folder and find the `"env"` block. Add a new line for `WA_ALLOW_FROM` with the phone numbers separated by commas:

```json
"env": {
  "WA_VERBOSE": "0",
  "WA_AUTO_OPEN_QR": "0",
  "WA_ALLOW_FROM": "+14155551234,+442071838750"
}
```

> ⚠️ **Be careful with commas.** JSON is fussy — a missing comma between lines, or a trailing comma after the last line, will break the file and the channel won't start. If you're not comfortable editing JSON, just ask your assistant (see "The easy way" above).

Your own number is **always** allowed, even if you leave `WA_ALLOW_FROM` blank or don't list it.

**How to restart Claude Code so the change takes effect:**

1. Click into the terminal where Claude Code is running.
2. Press `Ctrl + C` (on Mac or Windows) to stop it. You'll see the prompt return.
3. Run the same launch command from [Part B Step 1](#part-b--scan-the-qr-code) again.

No new QR scan needed — your WhatsApp session is already saved.

---

## Part E — Reading Past WhatsApp Messages on Demand

Your assistant now remembers every WhatsApp message it has seen — both ones you received and ones it replied to — so you can ask about them later, even days after they came in. You don't have to have been in a Claude Code session when the message arrived.

**Just ask in plain English.** Some examples to try:

> *"Read the last 20 WhatsApp messages I received."*

> *"Show me every WhatsApp message mentioning 'invoice' from the last week."*

> *"What WhatsApp chats have I gotten messages in recently?"*

> *"What did Alice say in our group chat yesterday?"*

> *"Summarise the last week of messages from my supplier."*

> *"Did anyone message me about the meeting on Tuesday?"*

You don't need to learn any special commands — just describe what you want in normal sentences. Your assistant will figure out the rest.

### What your assistant remembers, and what it doesn't

✅ **Remembered:** Every message received or sent while the WhatsApp channel has been running on your computer (from the moment you first set it up).

❌ **Not remembered:** Messages from before you installed this channel. WhatsApp doesn't let outside tools read your chat history from its servers — that's a protection built into WhatsApp itself. Your assistant can only see messages that arrived *after* it started watching.

Think of it like a receptionist who started writing down every phone call yesterday — they can tell you about calls from today and yesterday, but they can't tell you about calls from last month because they weren't there yet.

### Where the messages are stored (advanced)

If you ever want to look at the raw log yourself, it lives at:

- **Mac / Linux:** `~/.claude/whatsapp-channel/history.jsonl`
- **Windows:** `%USERPROFILE%\.claude\whatsapp-channel\history.jsonl`

You don't need to open this file — your assistant reads it for you. It's just there if you're curious or want to back it up.

---

## What Your Assistant Can Do via WhatsApp

| Task | What to Send |
|---|---|
| **Ask a question** | "What meetings do I have today?" |
| **Request content** | "Write me a LinkedIn post about AI tools" |
| **Get a summary** | "Summarise my unread emails" |
| **Run research** | "Research my top 3 competitors" |
| **Quick tasks** | "Draft a reply to John's email about the proposal" |
| **Approve tool use** | Reply `yes <code>` or `no <code>` when Claude asks for permission |
| **Read past messages** | "Show me the last 10 WhatsApp messages I received" or "Find WhatsApp messages about the invoice" (uses the history log — see Part E) |

> Your assistant has all the same skills available through WhatsApp — the same ones you use in VS Code.

---

## How It Works (Behind the Scenes)

| Feature | How |
|---|---|
| **Connection** | Uses WhatsApp Web protocol (Baileys) — same as linking a computer |
| **Receiving messages** | WebSocket connection to WhatsApp servers, forwarded to Claude Code |
| **Sending replies** | Claude Code sends replies back through the WhatsApp connection |
| **Permission relay** | Tool approval prompts are forwarded to WhatsApp — reply yes/no from your phone |
| **Session storage** | Credentials stored locally at `~/.claude/whatsapp-channel/auth/` |

No external servers, no cloud services — the connection runs on your computer.

---

## Optional Settings

You can customise behavior with environment variables. Set these in the `env` section of your `.mcp.json`:

| Setting | Default | What It Does |
|---|---|---|
| `WA_ALLOW_FROM` | `""` (self-only) | Additional phone numbers allowed to message your assistant (comma-separated, E.164 format) |
| `WA_AUTH_DIR` | `~/.claude/whatsapp-channel/auth/` | Changes where login credentials are stored |
| `WA_VERBOSE` | `0` | Shows detailed logs for debugging. Set to `1` to enable |
| `WA_AUTO_OPEN_QR` | `0` | Auto-opens QR code page in browser. Set to `1` when starting from CLI |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `'WA_AUTO_OPEN_QR=1' is not recognised` (Windows) | You pasted the Mac command into PowerShell or Command Prompt. Use the Windows block in Part B Step 1 — on PowerShell set `$env:WA_AUTO_OPEN_QR = "1"` on its own line first, on Command Prompt use `set WA_AUTO_OPEN_QR=1` |
| QR code doesn't appear | Make sure no other WhatsApp Web session is active for this account. Delete the auth folder and restart. Mac / Linux: `rm -rf ~/.claude/whatsapp-channel/auth`. Windows (PowerShell): `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\whatsapp-channel\auth"` |
| QR code disappears before scanning | Ask your assistant to regenerate it, or restart Claude Code with `WA_AUTO_OPEN_QR=1` |
| Messages not arriving | Only your linked phone is allowed by default. Run with `WA_VERBOSE=1` to see blocked messages |
| Messages from others are ignored | Add their numbers to `WA_ALLOW_FROM` in the env config |
| Assistant doesn't respond | Make sure Claude Code is running with `--dangerously-load-development-channels server:whatsapp` |
| Session expired | WhatsApp Web sessions expire if your phone is offline too long. Delete the auth folder (see "QR code doesn't appear" above for the commands) and scan a new QR code |
| "blocked by org policy" | Your Team or Enterprise admin needs to enable channels in Claude Code settings |
| Photos show as placeholders | Media files are detected but not downloaded — shown as `<media:image>`. Send text descriptions instead |
| Want to reconnect after restart | Sessions persist automatically. Just restart Claude Code with the channel flag — no new QR scan needed |
| "Bun not found" error | Install Bun, then **close and reopen your terminal**. Mac / Linux: `curl -fsSL https://bun.sh/install \| bash`. Windows (PowerShell): `powershell -c "irm bun.sh/install.ps1 \| iex"` |

---

## Key Differences from Telegram and iMessage

| | WhatsApp | Telegram | iMessage |
|---|---|---|---|
| **Needs a bot?** | No — links your existing WhatsApp account | Yes — create a bot via @BotFather | No — uses your existing Messages app |
| **Needs a token?** | No | Yes — bot token required | No |
| **Needs pairing?** | QR code scan (like WhatsApp Web) | 6-character pairing code | No — self-chat works immediately |
| **Platform** | Any platform | Any platform | macOS only |
| **Access control** | Self-only by default + allowlist by phone number | Allowlist by Telegram user ID | Allowlist by phone/email |
| **Permission relay** | Yes — approve/deny tool use from WhatsApp | No | No |
| **Group chat** | Supported | Not supported | Not supported |
| **Media** | Placeholders only (not downloaded) | Full file support | Full file support |

---

## Still Having Trouble?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more fixes, or ask your assistant:
> "Something went wrong with my WhatsApp setup. Help me fix it."

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
