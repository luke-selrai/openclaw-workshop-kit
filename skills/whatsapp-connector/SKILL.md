---
name: whatsapp-connector
description: "Connect the user's WhatsApp to Claude Code so they can message their assistant from their phone. Handles the full install and QR-pairing flow conversationally (Phase 1) and supports everyday use once the channel is loaded — sending messages, reading inbound messages, querying on-demand history, and managing the self-only allowlist (Phase 2). Use this skill when the user says 'set up WhatsApp', 'connect my WhatsApp', 'install the WhatsApp channel', or asks about past WhatsApp messages, the allowlist, or the QR pairing flow. On the first use, run Phase 1 before attempting any tool calls."
allowed-tools: Bash, Read, Write, Edit
metadata:
  category: Channels & Messaging
  tags:
    - whatsapp
    - channel
    - messaging
    - baileys
    - mcp
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Bun / PATH / shell-detection patterns used during install
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting QR, auth, or message-delivery failures
---

# WhatsApp Connector

## Overview

This skill lets you connect a user's WhatsApp to Claude Code and drive everyday WhatsApp usage on their behalf. It has two phases:

- **Phase 1 — Install & Pair.** A conversational bootstrap. The user has never done this before. You walk them through it one step at a time, detecting their OS and shell, running the technical work silently, and only asking the user for things that genuinely require them (scanning the QR code with their phone, confirming readiness). The user should never see the words "bash", "PowerShell", "terminal", "MCP", "WebSocket", "env var", or any file paths. At the end, their WhatsApp is paired and the channel is live in a fresh Claude Code session.
- **Phase 2 — Use the Channel.** Once the channel is running, you send messages, read inbound messages, query the on-demand history log, and manage the allowlist on the user's behalf.

**Which phase to run** — Before any WhatsApp action, check whether the channel is already paired. Read the file at `~/.claude/whatsapp-channel/auth/creds.json`. If it exists and is non-empty, treat the channel as paired and skip to Phase 2. If it is missing or empty, run Phase 1.

---

## ⚠️ Safety gate — run this BEFORE Phase 1

The WhatsApp channel uses an unofficial Web protocol (Baileys). Meta can **permanently ban** the linked number — losing all chats, groups, and history. Before touching any install step, say this to the user in plain English and wait for explicit acknowledgement:

> "Before we start — connecting WhatsApp to Claude uses an unofficial method that Meta hasn't approved. There's a real chance the phone number you link gets banned, sometimes permanently. I strongly recommend using a cheap second SIM, not your main number. Are you okay with that risk, and which number are you planning to link — your main one or a secondary?"

If they pick their main number, push back once: *"I'd really prefer you used a secondary SIM here — people have lost their main WhatsApp accounts doing this. Want to grab a prepaid SIM first?"* If they still insist, proceed — it's their call, but you've warned them.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say Bun, npm, bash, zsh, PowerShell, CLI, MCP, env var, terminal, WebSocket, JSONL, config file. If you must refer to a technical thing, name it plainly: "a small helper tool", "the WhatsApp pieces", "the launch command", "your browser", "your phone".
- **Tell them what is about to happen.** Before any action: "I'm going to check if a small helper tool is already on your computer — this takes a couple of seconds."
- **React warmly.** Good: "That worked — WhatsApp is linked." Bad: "Pairing session established, ws handshake 200."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem — let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.

---

## PHASE 1 — Install & Pair

This phase gets Bun installed if missing, installs the WhatsApp channel's packages, produces the exact launch command for the user's shell, walks them through closing the current session and re-launching, and confirms the QR scan succeeded.

### Step 1 — Detect the user's OS and shell

Silently run, in order, until one identifies the environment:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Ask them in plain English: *"Quick question — on your computer, when you open a black or blue text window to type commands, does the prompt start with `PS` (like `PS C:\Users\you>`) or just `C:\Users\you>`? Or are you not sure?"* Map their answer:

- Starts with `PS` → **PowerShell**
- No `PS`, just `C:\...>` → **Command Prompt**
- Not sure → default to **PowerShell** (it's the Windows default since Win10)

Remember the detected shell — you'll use it in Step 4.

### Step 2 — Check that Bun is installed

Tell the user: *"I'm going to check if a small helper tool is already on your computer. This takes a few seconds."*

Silently run:

```bash
bun --version
```

- If it prints a version → tell the user "That's ready" and go to Step 3.
- If the command is not found → go to Step 2a.

#### Step 2a — Install Bun

Tell the user: *"I need to install one small helper tool first. This takes about a minute — I'll do it for you."*

Silently run the install command for their OS:

- **Mac / Linux:** `curl -fsSL https://bun.sh/install | bash`
- **Windows (PowerShell):** `powershell -c "irm bun.sh/install.ps1 | iex"`

When the install finishes, the new tool isn't in the current shell's PATH yet. Tell the user: *"Almost done with the helper tool. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them. On resume, re-run `bun --version` to confirm. If it still fails, check `~/.bun/bin/bun` directly; if present, guide the user through the PATH fix in `skills/first-run-setup/SKILL.md` ("Windows Snags Reference" / PATH section).

### Step 3 — Install the WhatsApp channel's packages

Tell the user: *"I'm installing the WhatsApp pieces now. About 30 seconds."*

Silently run (from the workshop-kit folder — resolve the same way other connectors in this repo do):

```bash
cd whatsapp-channel && bun install
```

- Success → "That's done." Go to Step 4.
- Permissions error (`EACCES`, `EPERM`, `EBUSY`) → translate: "Your computer needs a small permission fix — let me sort it." Apply the guidance in `skills/first-run-setup/SKILL.md`, then retry.
- Network error → "Your network is blocking the install — this happens on company laptops. Could you try from a home connection, or ask your IT team?"

### Step 4 — Hand the user the launch command

The launch command must run in a **fresh terminal, in a fresh Claude Code session** — the current session can't load the channel after the fact. Warn the user clearly, then give them the command for their shell (detected in Step 1).

Send two short messages:

1. *"WhatsApp is ready to link. To finish, you'll need to close this Claude Code session and open a fresh one with WhatsApp turned on. I'll give you the exact command to paste in a moment — ready?"*
2. When they confirm, paste the **one** block that matches their shell:

   **Mac / Linux:**
   ```
   cd ~/workshop-kit/whatsapp-channel && WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
   ```

   **Windows (PowerShell):**
   ```
   cd $HOME\workshop-kit\whatsapp-channel
   $env:WA_AUTO_OPEN_QR = "1"
   claude --dangerously-load-development-channels server:whatsapp
   ```

   **Windows (Command Prompt):**
   ```
   cd %USERPROFILE%\workshop-kit\whatsapp-channel
   set WA_AUTO_OPEN_QR=1
   claude --dangerously-load-development-channels server:whatsapp
   ```

   Say: *"Close this Claude Code session, open a fresh terminal window, paste the block above, and press Enter. A QR code will open in your browser. When you see it, open WhatsApp on your phone → Settings → Linked Devices → Link a Device → scan the code. Once it's linked, say hi to yourself on WhatsApp (use the 'Message yourself' chat) and Claude will reply."*

This is the handoff point. Phase 1 is complete once the user runs that command — the rest of the pairing happens in the new session, where this skill will auto-load (because it's triggered by WhatsApp-related context) and Phase 2 takes over.

### Step 5 — In the new session: confirm pairing worked

When you re-enter this skill in the new session (user says "I scanned it" or similar, or tool calls into `whatsapp_*` are made), check `~/.claude/whatsapp-channel/auth/creds.json` is non-empty. If yes → *"Perfect — WhatsApp is linked and listening. Send yourself a test message from your phone."* If no → go back to Step 4 and give them the launch command again.

---

## PHASE 2 — Use the Channel

Once paired, the channel exposes these tools via the workshop-kit's `whatsapp-channel` MCP server:

| Tool | Use when the user wants to... |
|---|---|
| `whatsapp_send` | Send a message to a chat (self or allowlisted number) |
| `whatsapp_history` | Read past messages — filter by `chat_id`, `sender_phone`, `contains`, `since_ts`, `until_ts`, `direction`, `limit` (1–500) |
| `whatsapp_list_chats` | List chats the assistant has seen, sorted by most recent activity |

### Common patterns

**"Read the last 20 WhatsApp messages I got."** → `whatsapp_history` with `direction: "inbound"`, `limit: 20`.

**"What chats have I been active in this week?"** → `whatsapp_list_chats`, then filter by `last_ts` within the last 7 days.

**"Show me everything about the invoice from Alice."** → `whatsapp_history` with `contains: "invoice"`, then narrow by `sender_phone` if multiple people mentioned it.

**"Reply to Alice that I'll send it tomorrow."** → find Alice's `chat_id` via `whatsapp_list_chats`, then `whatsapp_send`.

**History predates the current session.** The history log at `~/.claude/whatsapp-channel/history.jsonl` persists across sessions — you can answer questions about messages from days ago, not just the current chat.

### Allowlist management

The channel is **self-only by default**: only the linked phone can message the assistant. To add other numbers, edit the `WA_ALLOW_FROM` env var in `whatsapp-channel/.mcp.json`:

```json
"env": {
  "WA_VERBOSE": "0",
  "WA_AUTO_OPEN_QR": "0",
  "WA_ALLOW_FROM": "+14155551234,+442071838750"
}
```

**Rules:**
- Phone numbers must be E.164 format: leading `+`, country code, no spaces/dashes/brackets.
- Comma-separated, no trailing comma.
- The linked number is always allowed even if the list is empty.
- After editing, the user must restart Claude Code (same launch command as Phase 1 Step 4) for the change to take effect.

When a user asks to add a number, you edit `.mcp.json`, validate the JSON, tell them in plain English that you've added it and they need to restart. Never show them the JSON.

### Safety rules

- **Never send unsolicited messages.** Only send when the user has explicitly asked, or in direct reply to an inbound message they asked you to handle.
- **Never DM a number that isn't on the allowlist**, even if the user asks — push back: *"I can't message that number yet because it isn't on your allowlist. Want me to add it first?"*
- **Read before write** when handling a thread — use `whatsapp_history` to pull the last few messages for context before replying, so you don't miss tone or open questions.
- **Permission prompts** from Claude Code tool approvals get forwarded to WhatsApp. If a user replies `yes <code>` or `no <code>` in a chat, treat that as the approval response and do not interpret it as conversation.

---

## Troubleshooting (Phase 1 and Phase 2)

| Symptom | What's going on | What you do |
|---|---|---|
| `'WA_AUTO_OPEN_QR=1' is not recognised` on Windows | User pasted the Mac launch block into PowerShell/cmd | Re-send the correct shell block from Phase 1 Step 4 |
| QR page never opens | Default browser not set on Windows, or `WA_AUTO_OPEN_QR` missing | Tell the user to open `http://127.0.0.1:8787` manually |
| QR disappears before scanning | Pairing timed out | Restart Claude Code with the Phase 1 Step 4 command — a new QR appears |
| `Bun not found` after install | PATH not refreshed | Tell user to close and reopen the terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| "Session expired" on reconnect | Phone was offline too long; WhatsApp invalidated the link | Delete `~/.claude/whatsapp-channel/auth/` silently, then run Phase 1 Step 4 again |
| Inbound messages not arriving | Sender isn't on the allowlist, or channel isn't running | Check `~/.claude/whatsapp-channel/auth/creds.json` exists; check `WA_ALLOW_FROM`; ask the user which number they sent from |
| "blocked by org policy" | Team/Enterprise plan with channels disabled | Tell the user their workspace admin needs to enable development channels in Claude Code settings |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging` and diagnose silently before reporting back to the user in plain English. If it isn't installed, work through the failure step by step yourself — isolate what changed, form a hypothesis, verify before fixing — and summarise the outcome in plain English. Never paste a raw stack trace at the user either way.

---

## Reference — what lives where

- Channel source: `whatsapp-channel/` in the workshop-kit repo
- Pairing credentials: `~/.claude/whatsapp-channel/auth/`
- On-demand message log: `~/.claude/whatsapp-channel/history.jsonl`
