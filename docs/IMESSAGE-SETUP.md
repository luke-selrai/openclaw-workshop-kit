---
title: iMessage Plugin Setup Guide
version: 1.0
date: 2026-03-27
---

# iMessage — Setup Guide

This guide walks you through connecting iMessage to Claude Code so your assistant can receive and reply to messages on your Mac, iPhone, and iPad. Once connected, you can text your assistant from anywhere and it will respond — like having your AI assistant in your pocket, using the Messages app you already know.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A Mac (iMessage channel is macOS only — it reads your local Messages database)
- Bun installed (check by typing `bun --version` in the command window)

> If you don't have Bun installed, run this in your terminal:
> ```
> curl -fsSL https://bun.sh/install | bash
> ```
> Then close and reopen your terminal.

---

## Part A — Grant Full Disk Access

iMessage stores your messages in a database file on your Mac (`~/Library/Messages/chat.db`). Claude Code needs permission to read this file.

**Step 1 — Open System Settings**

1. Click the Apple menu () in the top-left corner of your screen
2. Click **System Settings**
3. Click **Privacy & Security** in the sidebar
4. Scroll down and click **Full Disk Access**

**Step 2 — Add Your Terminal**

1. Click the **+** button
2. Find and select your terminal app (e.g. **Terminal**, **iTerm**, **Ghostty**, or **Visual Studio Code**)
3. Toggle it **on**

> You may not need to do this manually — the first time Claude Code tries to read your messages, macOS will pop up a permission prompt. Click **Allow** and you're done. If you accidentally clicked "Don't Allow", follow the steps above.

---

## Part B — Install the iMessage Plugin

This is a terminal command — run it in the VS Code terminal (not inside the Claude chat).

**Step 1 — Install the Plugin**

Open the terminal in VS Code (click **Terminal** in the top menu → **New Terminal**), then run:

```
claude plugin install imessage@claude-plugins-official
```

No tokens or passwords needed — iMessage reads your local Messages database directly.

---

## Part C — Connect and Test

**Step 1 — Restart Claude Code with iMessage Enabled**

Close your Claude Code session completely, then start a new one with the channel flag:

```sh
claude --channels plugin:imessage@claude-plugins-official
```

> This flag tells Claude Code to listen for iMessage texts. Without it, the assistant won't receive messages.

**Step 2 — Text Yourself**

1. Open the **Messages** app on your Mac or iPhone
2. Start a new message **to yourself** (type your own phone number or Apple ID email)
3. Send any message — something like "Hello, are you there?"

The message reaches your assistant immediately. Self-chat bypasses access control, so this works straight away with no pairing needed.

> The first time your assistant replies, macOS will show an **Automation** permission prompt: "Terminal wants to control Messages." Click **OK** to allow replies.

**Step 3 — Allow Other Contacts (Optional)**

By default, only your own messages reach the assistant — texts from everyone else are silently dropped. To let someone else message your assistant:

```
/imessage:access allow +15551234567
```

Or for an Apple ID email:

```
/imessage:access allow someone@icloud.com
```

> Use the phone number or email exactly as it appears in their iMessage profile.

---

## Part D — Test It

Send a message to yourself (or have an allowed contact send one) — something like "Hi, what can you help me with?"

Your assistant should reply directly in iMessage. You can now text your assistant from your iPhone, iPad, or Mac anywhere, anytime.

---

## What Your Assistant Can Do via iMessage

| Task | What to Send |
|---|---|
| **Ask a question** | "What meetings do I have today?" |
| **Request content** | "Write me a LinkedIn post about AI tools" |
| **Get a summary** | "Summarise my unread emails" |
| **Run research** | "Research my top 3 competitors" |
| **Send files** | Send a photo or document — your assistant can read it |
| **Quick tasks** | "Draft a reply to John's email about the proposal" |
| **Search message history** | "Find the last message from Sarah about the project" |

> Your assistant has all the same skills available through iMessage — the same ones you use in VS Code.

---

## How It Works (Behind the Scenes)

| Feature | How |
|---|---|
| **Receiving messages** | Polls your Messages database once a second for new messages |
| **Sending replies** | Uses AppleScript to send through the Messages app |
| **Message history** | Reads your full iMessage history via the local database |
| **Photos & files** | Inbound images are read directly from disk; outbound files send as separate messages |

No external servers, no cloud services, no background processes — everything stays on your Mac.

---

## Optional Settings

You can customise behavior with environment variables. Set these in your terminal before launching Claude Code:

| Setting | Default | What It Does |
|---|---|---|
| `IMESSAGE_APPEND_SIGNATURE` | `true` | Adds "Sent by Claude" to the end of replies. Set to `false` to disable |
| `IMESSAGE_STATE_DIR` | `~/.claude/channels/imessage` | Changes where access settings are stored |

Example — disable the signature:

```sh
export IMESSAGE_APPEND_SIGNATURE=false
claude --channels plugin:imessage@claude-plugins-official
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Assistant doesn't respond to messages | Make sure Claude Code is running with the `--channels plugin:imessage@claude-plugins-official` flag |
| "authorization denied" error on launch | Grant Full Disk Access to your terminal app (Part A, Step 2) |
| "Bun not found" error | Install Bun: `curl -fsSL https://bun.sh/install | bash` then restart your terminal |
| First reply doesn't send | Click **OK** on the Automation prompt ("Terminal wants to control Messages") |
| Messages from others are ignored | Add their handle: `/imessage:access allow +15551234567` |
| Want to remove someone's access | Run `/imessage:access remove +15551234567` |
| Photos not being read by assistant | Send the photo as a file attachment for full quality |
| Messages stop being received after a reply | The server ignores your messages for ~15 seconds after sending a reply (to avoid echo). Wait 15 seconds, or restart Claude Code if it stays stuck |
| Only works on Mac, not iPhone | The channel runs on your Mac — but you can text from any Apple device and it reaches the Mac |
| Tapbacks/reactions don't work | This is an Apple limitation — AppleScript can send text but not tapbacks or reactions |

---

## Key Differences from Telegram

| | iMessage | Telegram |
|---|---|---|
| **Needs a bot?** | No — uses your existing Messages app | Yes — create a bot via @BotFather |
| **Needs a token?** | No | Yes — bot token required |
| **Needs pairing?** | No — self-chat works immediately | Yes — 6-character pairing code |
| **Platform** | macOS only | Any platform |
| **Message history** | Full native history available | Only messages since bot was started |
| **Access control** | Allowlist by phone/email | Allowlist by Telegram user ID |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
