---
name: imessage-connector
description: "Connect the user's iMessage to Claude Code (Mac only) so they can text their assistant from any Apple device. Handles the Full Disk Access grant, plugin install, and self-chat test conversationally. Use this skill when the user says 'set up iMessage', 'connect my iMessage', 'text Claude from my iPhone', or asks about iMessage allowlists, Full Disk Access, or AppleScript replies."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Channels & Messaging
  tags:
    - imessage
    - channel
    - messaging
    - macos
    - plugin
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Bun / PATH / shell-detection patterns used during install
    - skill: whatsapp-connector
      reason: Same messaging-channel install pattern — reference if the user also wants WhatsApp
    - skill: telegram-connector
      reason: Same messaging-channel install pattern — reference if the user also wants Telegram
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Full Disk Access, AppleScript, or message-delivery failures
---

# iMessage Connector

## Overview

This skill lets you connect a user's iMessage to Claude Code so they can text their assistant from their iPhone, iPad, or Mac. Unlike Telegram and WhatsApp, iMessage reads the user's **existing Messages app** — no bot, no token, no separate account. Self-chat works immediately; adding other contacts is done via the plugin's allowlist.

**macOS only.** The channel reads the local Messages database at `~/Library/Messages/chat.db` and sends replies via AppleScript. It does not run on Windows or Linux. If the user is on Windows or Linux, tell them so early and suggest Telegram or WhatsApp as alternatives.

**Which phase to run** — if the user has never done this (no Full Disk Access, no iMessage plugin), run Phase 1. If already installed and they just need to re-launch or manage access, jump to Phase 2.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** Never say Bun, npm, bash, zsh, CLI, MCP, env var, terminal, AppleScript, AppleScript permission, full disk access API. If you must name a technical thing, describe it plainly: "a small helper tool", "the iMessage pieces", "the launch command", "a permission Windows — sorry, I mean macOS — asks you for".
- **Tell them what is about to happen.** Before any action: "I'm going to install a small helper tool — this takes a few seconds."
- **React warmly.** Good: "That worked — texts from your phone reach me now." Bad: "Plugin install succeeded, self-chat handle verified."
- **Never show raw error messages.** Translate into plain English.
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.

---

## PHASE 1 — Install & Test

This phase checks the user is on Mac, walks them through Full Disk Access, installs the iMessage plugin, re-launches Claude Code with the iMessage flag, and confirms a self-chat test message reaches Claude.

### Step 1 — Confirm the user is on Mac

Silently run:

```bash
uname -s
```

- `Darwin` → Mac. Continue to Step 2.
- Anything else → Tell the user: *"iMessage only runs on a Mac — Apple doesn't let the Messages app run on Windows or Linux. If you want to message me from your phone, Telegram or WhatsApp will both work instead. Want me to set one of those up for you?"* Do not continue this skill.

### Step 2 — Check that Bun is installed

Tell the user: *"I'm going to check if a small helper tool is already on your computer. Takes a few seconds."*

Silently run `bun --version`.

- If it prints a version → go to Step 3.
- If not found → install Bun: `curl -fsSL https://bun.sh/install | bash`. Tell the user: *"Almost done with the helper tool — please close this terminal and open a fresh one, then tell me 'ready'."* Wait for them, re-verify.

### Step 3 — Grant Full Disk Access

Claude needs to read the user's Messages database. Tell the user plainly what's about to happen and why:

*"iMessage stores your messages in a protected file. To read them, the Claude Desktop app needs a permission called Full Disk Access. I'll walk you through giving it that permission — takes about 30 seconds."*

Walk them through one step at a time:

1. *"Click the Apple menu in the top-left corner of your screen, then click System Settings."*
2. When they confirm: *"Click Privacy & Security in the sidebar, then scroll down and click Full Disk Access."*
3. When they confirm: *"Click the plus button, find Claude in the list of apps (the Claude Desktop app), select it, and toggle it on. Tell me when that's done."*

*Note*: If the user runs the plugin first, macOS will usually pop up the permission request automatically. If they click Allow, they're done — the manual steps above are the fallback for when they clicked "Don't Allow" by accident.

### Step 4 — Install the iMessage plugin

Tell the user: *"I'm installing the iMessage pieces. About 30 seconds."*

Silently run in the user's Claude Desktop terminal:

```bash
claude plugin install imessage@claude-plugins-official
```

- Success → "That's done." Go to Step 5.
- Permissions error → apply `skills/first-run-setup/SKILL.md` guidance, then retry.

### Step 5 — Hand the user the launch command

iMessage, like Telegram and WhatsApp, needs a **fresh Claude Code session** started with the `--channels` flag to listen.

Send two short messages:

1. *"iMessage is ready. To finish, you'll need to close this Claude Code session and open a fresh one with iMessage turned on. I'll give you the exact command in a moment — ready?"*
2. When they confirm, paste:

   ```
   claude --channels plugin:imessage@claude-plugins-official
   ```

   Say: *"Close this Claude Code session, open a fresh terminal window, paste the command above, and press Enter."*

### Step 6 — In the new session: self-chat test

When the user returns:

1. *"Open the Messages app on your Mac or iPhone. Start a new message to yourself — type your own phone number or Apple ID email in the To field. Send any message, like 'hello'. Tell me when you've done that."*
2. Self-chat bypasses access control — the message should reach Claude immediately. When it does, reply in iMessage to complete the round-trip.
3. The first time Claude replies, macOS will pop up an **Automation** permission prompt: *"Terminal wants to control Messages."* Tell the user ahead of time: *"The first time I reply, a small box will pop up on your Mac asking if Terminal can control Messages — click OK."*
4. Once the round-trip works: *"Perfect — texts from your phone reach me, and my replies go back to Messages. You're done."*

Phase 1 is complete.

---

## PHASE 2 — Use the Channel

Once paired, the plugin handles inbound/outbound routing automatically. Self-chat always works. Other contacts must be explicitly added to the allowlist.

### Common requests

**"Let [person] message my assistant."** → ask the user for the person's phone number (E.164 format, e.g. `+15551234567`) or Apple ID email. Run in Claude Code:

```
/imessage:access allow +15551234567
```

or

```
/imessage:access allow someone@icloud.com
```

Tell the user plainly: *"Added. They can message you now — the handle has to match exactly how it appears in their iMessage profile."*

**"Remove someone's access."** → run:

```
/imessage:access remove +15551234567
```

**"Turn off the 'Sent by Claude' signature on replies."** → the plugin honours the `IMESSAGE_APPEND_SIGNATURE` setting. Tell the user: *"I'll turn that off. You'll need to restart Claude Code with the setting included."* Give them the command for their shell:

**Mac (zsh / bash):**
```
export IMESSAGE_APPEND_SIGNATURE=false
claude --channels plugin:imessage@claude-plugins-official
```

Explain briefly: *"The first line turns the signature off; the second launches Claude Code with iMessage listening. You'll need both in the same terminal window."*

---

## Troubleshooting

| Symptom | Likely cause | What you do |
|---|---|---|
| Assistant doesn't respond to messages | Claude Code not running with `--channels plugin:imessage@claude-plugins-official` | Tell the user to close Claude Code and re-launch with the flag from Phase 1 Step 5 |
| "authorization denied" error on launch | Full Disk Access not granted | Walk the user through Phase 1 Step 3 again — make sure Claude Desktop (not Terminal, not Claude Code) is in the Full Disk Access list |
| First reply never sends | Automation permission denied when the prompt appeared | Tell the user to open System Settings → Privacy & Security → Automation, find Terminal (or Claude Desktop), and toggle Messages on |
| `Bun not found` after install | PATH not refreshed | Close and reopen terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| Messages from other people are silently dropped | They're not on the allowlist | Walk through the "let [person] message" flow above |
| Messages stop arriving for ~15 seconds after a reply | Echo-suppression window by design | Tell the user to wait 15 seconds. If it stays stuck longer, restart Claude Code |
| Messages from iPhone don't reach the Mac-resident channel | The Mac must be awake and signed into iMessage with the same Apple ID as the iPhone | Ask the user to check their Mac is awake and their Apple ID is signed into Messages on both devices |
| Tapbacks / reactions not supported | Apple limitation — AppleScript can send text but not reactions | Tell the user plainly: "That's a limit of how iMessage works on a Mac — I can send text replies but not tapbacks or reactions" |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step in plain English.

---

## Reference — what lives where

- Plugin source: installed via `claude plugin install imessage@claude-plugins-official` into the user's Claude Code plugin directory
- Messages database (read-only): `~/Library/Messages/chat.db`
- Access state (allowlist): default `~/.claude/channels/imessage/` (overridable via `IMESSAGE_STATE_DIR`)
- Reply signature: controlled by `IMESSAGE_APPEND_SIGNATURE` (default `true`)
