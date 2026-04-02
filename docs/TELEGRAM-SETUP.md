---
title: Telegram Plugin Setup Guide
version: 1.0
date: 2026-03-25
---

# Telegram — Setup Guide

This guide walks you through connecting Telegram to Claude Code so your assistant can receive and reply to messages on your phone. Once connected, you can message your bot from anywhere and your assistant will respond — like having your AI assistant in your pocket.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A Telegram account (free — download the app on your phone from the App Store or Google Play)
- Bun installed (check by typing `bun --version` in the command window)

> If you don't have Bun installed, run this in your terminal:
> ```
> curl -fsSL https://bun.sh/install | bash
> ```
> Then close and reopen your terminal.

---

## Part A — Create a Telegram Bot

Telegram lets anyone create a bot for free. You do this by talking to a special bot called **BotFather**.

**Step 1 — Open BotFather**

1. Open Telegram on your phone or computer
2. Search for **@BotFather** (it has a blue checkmark)
3. Tap **Start** to begin a chat

**Step 2 — Create Your Bot**

1. Send the message: `/newbot`
2. BotFather will ask for a **name** — this is the display name (e.g. "My Assistant")
3. BotFather will ask for a **username** — this must end in `bot` (e.g. `my_assistant_bot`)
4. BotFather will reply with a **token** that looks like `123456789:AAHfiqksKZ8...`
5. **Copy the entire token** — you need it in Part B

> The token includes the numbers, the colon, and everything after it. Copy the whole thing.

---

## Part B — Install the Telegram Plugin

This is a terminal command — run it in the VS Code terminal (not inside the Claude chat).

**Step 1 — Install the Plugin**

Open the terminal in VS Code (click **Terminal** in the top menu → **New Terminal**), then run:

```
claude plugin install telegram@claude-plugins-official
```

**Step 2 — Save Your Bot Token**

Type this in the Claude Code chat, replacing the example token with your actual token from Part A:

```
/telegram:configure 123456789:AAHfiqksKZ8...
```

This saves your token so Claude Code can connect to your bot.

---

## Part C — Connect and Pair

**Step 1 — Restart Claude Code with Telegram Enabled**

Close your Claude Code session completely, then start a new one with the channel flag:

```sh
claude --channels plugin:telegram@claude-plugins-official
```

> This flag tells Claude Code to listen for Telegram messages. Without it, the bot won't respond.

**Step 2 — Pair Your Account**

1. Open Telegram on your phone
2. Search for your bot by its username (the one you created in Part A)
3. Tap **Start** and send any message
4. The bot will reply with a **6-character pairing code** (e.g. `e47906`)
5. Back in Claude Code, type:

```
/telegram:access pair <code>
```

Replace `<code>` with the 6-character code the bot gave you.

You should see a confirmation that your account was approved. Your next message to the bot will reach your assistant.

**Step 3 — Lock Down Access (Recommended)**

By default, anyone who messages your bot gets a pairing code. Once you are paired, switch to allowlist mode so strangers can't interact with your bot:

```
/telegram:access policy allowlist
```

---

## Part D — Test It

Send a message to your bot on Telegram — something like "Hi, what can you help me with?"

Your assistant should reply directly in Telegram. You can now message your assistant from your phone anywhere, anytime.

---

## What Your Assistant Can Do via Telegram

| Task | What to Send |
|---|---|
| **Ask a question** | "What meetings do I have today?" |
| **Request content** | "Write me a LinkedIn post about AI tools" |
| **Get a summary** | "Summarise my unread emails" |
| **Run research** | "Research my top 3 competitors" |
| **Send files** | Send a photo or document — your assistant can read it |
| **Quick tasks** | "Draft a reply to John's email about the proposal" |

> Your assistant has all 86 skills available through Telegram — the same ones you use in VS Code.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Bot doesn't respond to messages | Make sure Claude Code is running with the `--channels plugin:telegram@claude-plugins-official` flag |
| "Bun not found" error | Install Bun: `curl -fsSL https://bun.sh/install | bash` then restart your terminal |
| Pairing code not appearing | Make sure you started Claude Code with the `--channels` flag, then try messaging the bot again |
| Bot responds but assistant doesn't reply | Check that you completed the pairing step (Part C, Step 2) |
| Want to pair a second device/account | Run `/telegram:access pair <new-code>` with the code from the new account |
| Need to remove someone's access | Run `/telegram:access remove <senderId>` |
| Token changed or bot recreated | Run `/telegram:configure <new-token>` and restart Claude Code |
| Photos not being read by assistant | Send the photo as a file (long-press → Send as File) for full quality |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
