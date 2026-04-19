---
name: telegram-connector
description: "Connect the user's Telegram to Claude Code so they can message their assistant from their phone. Handles the full install + BotFather + pairing flow conversationally. Use this skill when the user says 'set up Telegram', 'connect my Telegram', 'install the Telegram channel', 'message Claude from my phone via Telegram', or asks about BotFather, pairing codes, or the Telegram allowlist."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Channels & Messaging
  tags:
    - telegram
    - channel
    - messaging
    - botfather
    - plugin
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Bun / PATH / shell-detection patterns used during install
    - skill: whatsapp-connector
      reason: Same messaging-channel install pattern — reference if the user also wants WhatsApp
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting plugin install, pairing, or message-delivery failures
---

# Telegram Connector

## Overview

This skill lets you connect a user's Telegram to Claude Code and drive everyday Telegram usage on their behalf. Once connected, the user can message their bot from anywhere and the assistant replies — like having Claude in their pocket.

The channel is installed as a Claude Code plugin (`telegram@claude-plugins-official`), paired via a 6-character code from the user's own bot, and then runs whenever the user launches Claude Code with the `--channels plugin:telegram@claude-plugins-official` flag.

**Which phase to run** — if the user has never done this before (no bot token, no Telegram plugin, no successful pair), run Phase 1. If they already have the plugin installed and just need to re-launch or manage access, jump to Phase 2.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say Bun, npm, bash, zsh, PowerShell, CLI, MCP, env var, terminal, plugin registry, config file. If you must refer to a technical thing, name it plainly: "a small helper tool", "the Telegram pieces", "the launch command", "your phone".
- **Tell them what is about to happen.** Before any action: "I'm going to check if a small helper tool is already on your computer — this takes a couple of seconds."
- **React warmly.** Good: "That worked — Telegram is linked." Bad: "Plugin install succeeded, 6-char pair code issued."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem — let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.
- **Security: never repeat the bot token back to the user.** When they share it with you, acknowledge you've received it, save it immediately with `/telegram:configure`, then forget it. Do not log it, echo it back, or write it to any file you read later.

---

## PHASE 1 — Install & Pair

This phase walks the user through creating a bot with BotFather, installing the Telegram plugin, saving the bot token, re-launching Claude Code with the Telegram flag, and entering the 6-character pairing code to link their personal Telegram account to the bot.

### Step 1 — Detect the user's OS and shell

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Ask them: *"Quick question — on your computer, when you open a black or blue text window to type commands, does the prompt start with `PS` or just `C:\...>`? Or are you not sure?"* Map their answer the same way `whatsapp-connector` does.

### Step 2 — Check that Bun is installed

Tell the user: *"I'm going to check if a small helper tool is already on your computer. This takes a few seconds."*

Silently run `bun --version`.

- If it prints a version → "That's ready" and go to Step 3.
- If the command is not found → install Bun silently:
  - **Mac / Linux:** `curl -fsSL https://bun.sh/install | bash`
  - **Windows (PowerShell):** `powershell -c "irm bun.sh/install.ps1 | iex"`

After install, tell the user: *"Almost done with the helper tool. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them, then re-verify.

If it still fails, apply the PATH fix guidance in `skills/first-run-setup/SKILL.md` ("Windows Snags Reference" section).

### Step 3 — Create the Telegram bot with BotFather

The user has to do this part on their phone — only they can talk to BotFather. Walk them through it one message at a time:

1. *"On your phone, open Telegram and search for `@BotFather`. It has a blue checkmark. Tap Start. Tell me when you've done that."*
2. When they confirm, tell them: *"Now send the message `/newbot` to BotFather. It'll ask you two questions — a name (whatever you want, like 'My Assistant') and a username (must end in `bot`, for example `harvey_assistant_bot`). Go through those, then paste the whole token BotFather gives you back to me. It looks like a long string with a colon in the middle."*
3. When they paste the token:
   - Do NOT echo it back.
   - Acknowledge plainly: *"Got it. Saving that now."*
   - Hold it in mind only for Step 5 — do not write it to a file.

### Step 4 — Install the Telegram plugin

Tell the user: *"I'm installing the Telegram pieces. About 30 seconds."*

Silently run in the user's Claude Desktop terminal:

```bash
claude plugin install telegram@claude-plugins-official
```

- Success → "That's done." Go to Step 5.
- Permissions error (`EACCES`, `EPERM`) → translate: "Your computer needs a small permission fix — let me sort it." Apply guidance from `skills/first-run-setup/SKILL.md`, then retry.
- Network error → "Your network is blocking the install — happens on company laptops. Could you try from a home connection?"

### Step 5 — Save the bot token

In the Claude Code chat (not the terminal), run:

```
/telegram:configure <token>
```

Replacing `<token>` with the bot token from Step 3. This saves the token into Claude Code's plugin state. Do NOT print the token in your reply to the user — just say: *"Token saved. Next I'll re-launch Claude Code so Telegram turns on."*

### Step 6 — Hand the user the launch command

Like the WhatsApp channel, Telegram needs a **fresh Claude Code session** started with the `--channels` flag to actually listen for messages. Send two short messages:

1. *"Telegram is ready to link. To finish, you'll need to close this Claude Code session and open a fresh one with Telegram turned on. I'll give you the exact command in a moment — ready?"*
2. When they confirm, paste the block for their shell:

   **Mac / Linux / Windows (any shell):**
   ```
   claude --channels plugin:telegram@claude-plugins-official
   ```

   Say: *"Close this Claude Code session, open a fresh terminal window, paste the command above, and press Enter."*

### Step 7 — In the new session: pair the user's personal Telegram

When the user returns in the new session, walk them through pairing:

1. *"Open Telegram on your phone. Search for your bot by its username (the one you made in Step 3). Tap Start and send any message — something like 'hello'. The bot will reply with a 6-character code. Send me that code."*
2. When they paste the code, run in Claude Code:
   ```
   /telegram:access pair <code>
   ```
3. Wait for the confirmation, then tell the user: *"Perfect — Telegram is linked. Try messaging your bot again and I'll reply there."*

### Step 8 — Lock down access (recommended)

Tell the user: *"One more thing — by default anyone who messages your bot gets a pairing code. I'll switch that off so only you can use it."*

Run in Claude Code:

```
/telegram:access policy allowlist
```

Confirm to the user: *"Done. Strangers can't interact with your bot now."*

Phase 1 is complete.

---

## PHASE 2 — Use the Channel

Once paired, the user can message their bot from Telegram and Claude responds directly in the chat. No tools to invoke from your side — the plugin handles inbound/outbound routing automatically. Your job in Phase 2 is to manage access and troubleshoot.

### Common requests

**"Add another person to my allowlist."** → ask the user for the other person's sender ID (they'll get it by having the person message the bot and running `/telegram:access list`). Once you have it, run:

```
/telegram:access add <senderId>
```

**"Remove someone's access."** → run:

```
/telegram:access remove <senderId>
```

**"Pair a second device."** → ask the user to message the bot from the new device/account, grab the pairing code from the bot's reply, then run `/telegram:access pair <new-code>`.

**"Rotate my bot token."** → ask the user to talk to BotFather again, send `/revoke`, generate a new token, and paste it to you. Run `/telegram:configure <new-token>`, then tell them they need to restart Claude Code with the `--channels` flag for the new token to take effect.

---

## Troubleshooting

| Symptom | Likely cause | What you do |
|---|---|---|
| Bot doesn't respond when user messages it | Claude Code not running with `--channels plugin:telegram@claude-plugins-official` flag | Tell the user to close Claude Code and re-launch with the flag from Phase 1 Step 6 |
| `Bun not found` after install | PATH not refreshed | Tell user to close and reopen the terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| Pairing code never appears in the bot's reply | Claude Code started without the `--channels` flag | Same fix as "bot doesn't respond" — re-launch with the flag |
| Bot replies with pairing code but assistant doesn't reply after pairing | Pair step didn't complete (maybe the wrong code was sent) | Ask the user for the most recent pairing code from the bot, then re-run `/telegram:access pair <code>` |
| `/telegram:configure` reports invalid token | Token was corrupted during copy (extra whitespace, missing colon) | Ask the user to re-copy the full token from BotFather — it has a colon in the middle; they need everything before and after it |
| Photos sent to the bot aren't being read | User sent as compressed photo, not as file | Tell them to long-press the image in Telegram and choose "Send as File" for full quality |
| Bot stops responding after token rotation | Claude Code still running with old token in memory | Restart Claude Code with the `--channels` flag |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step — isolate what changed, form a hypothesis, verify before fixing — and summarise the outcome in plain English.

---

## Reference — what lives where

- Plugin source: installed via `claude plugin install telegram@claude-plugins-official` into the user's Claude Code plugin directory
- Bot token: stored by the plugin itself after `/telegram:configure`; never written to any workshop-kit file
- Allowlist state: managed by the plugin via `/telegram:access` subcommands
