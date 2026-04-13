---
title: WhatsApp Channel Setup Guide
version: 1.0
date: 2026-04-09
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
- Bun installed (check by typing `bun --version` in the command window)

> If you don't have Bun installed, run this in your terminal:
>
> **Mac/Linux:**
> ```
> curl -fsSL https://bun.sh/install | bash
> ```
>
> **Windows (PowerShell):**
> ```
> powershell -c "irm bun.sh/install.ps1 | iex"
> ```
> Then close and reopen your terminal.

---

## Part A — Install the WhatsApp Channel

The WhatsApp channel is included in the workshop kit. You need to install its dependencies.

**Step 1 — Install Dependencies**

Open the terminal in VS Code (click **Terminal** in the top menu > **New Terminal**), then run:

```
cd ~/workshop-kit/whatsapp-channel && bun install
```

> This downloads the packages that the WhatsApp channel needs to run. It takes about 30 seconds.

**Step 2 — No Extra Config Needed**

The WhatsApp channel already includes its own `.mcp.json` config file. You don't need to copy anything — just launch Claude Code from the whatsapp-channel folder (see Part B below).

---

## Part B — Connect Your WhatsApp Account

WhatsApp connects by scanning a QR code — the same way you link WhatsApp Web on a computer. No bot tokens or API keys needed.

**Step 1 — Start Claude Code with the WhatsApp Channel**

Close your Claude Code session completely, then open a terminal and run:

```sh
cd ~/workshop-kit/whatsapp-channel && WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

> You must `cd` into the whatsapp-channel folder first — Claude Code reads the `.mcp.json` config from the folder you launch in. The `WA_AUTO_OPEN_QR=1` part tells it to automatically open the QR code in your browser.

**Step 2 — Scan the QR Code**

A browser window will open showing a QR code. On your phone:

1. Open **WhatsApp**
2. Go to **Settings > Linked Devices**
3. Tap **Link a Device**
4. Point your phone camera at the QR code on your computer screen

> Make sure you scan from inside WhatsApp's "Link a Device" screen — not from your phone's camera app.

Once linked, your session persists across restarts. You won't need to scan again unless the session expires.

---

## Part C — Security Setup

By default, **only your own phone number** can message your assistant — strangers are blocked automatically.

**Allow Additional Numbers (Optional)**

If you want a second phone or colleague to reach your assistant, add their numbers to the configuration:

```json
"env": {
  "WA_ALLOW_FROM": "+0987654321,+1122334455"
}
```

Your own number is always allowed, even if not listed in `WA_ALLOW_FROM`.

---

## Part D — Test It

Send a message to the linked WhatsApp number from your phone — something like "Hi, what can you help me with?"

Your assistant should reply directly in WhatsApp. You can now message your assistant from your phone anywhere, anytime.

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
| QR code doesn't appear | Make sure no other WhatsApp Web session is active for this account. Delete `~/.claude/whatsapp-channel/auth/` and restart |
| QR code disappears before scanning | Ask your assistant to regenerate it, or restart Claude Code with `WA_AUTO_OPEN_QR=1` |
| Messages not arriving | Only your linked phone is allowed by default. Run with `WA_VERBOSE=1` to see blocked messages |
| Messages from others are ignored | Add their numbers to `WA_ALLOW_FROM` in the env config |
| Assistant doesn't respond | Make sure Claude Code is running with `--dangerously-load-development-channels server:whatsapp` |
| Session expired | WhatsApp Web sessions expire if your phone is offline too long. Delete `~/.claude/whatsapp-channel/auth/` and scan a new QR code |
| "blocked by org policy" | Your Team or Enterprise admin needs to enable channels in Claude Code settings |
| Photos show as placeholders | Media files are detected but not downloaded — shown as `<media:image>`. Send text descriptions instead |
| Want to reconnect after restart | Sessions persist automatically. Just restart Claude Code with the channel flag — no new QR scan needed |
| "Bun not found" error | Install Bun: `curl -fsSL https://bun.sh/install | bash` then restart your terminal |

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
