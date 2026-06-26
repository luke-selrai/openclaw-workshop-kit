# WhatsApp Channel for Claude Code

> 🧑‍🏫 **Workshop attendee? Don't read this file.** Just ask your assistant: *"Connect WhatsApp."* It'll walk you through the install and QR pairing conversationally. This README is a technical reference for developers wiring the channel into their own projects.

A two-way WhatsApp channel for Claude Code sessions, built on [Baileys](https://github.com/WhiskeySockets/Baileys) (WhatsApp Web). Send messages to Claude from WhatsApp, and Claude replies back.

## Features

- **QR Code Login**, scan with your phone to link (no Business API needed)
- **Two-way messaging**, receive messages in Claude, Claude replies via WhatsApp
- **Persistent history**, every message is logged to disk so Claude can read past conversations on demand, even from before the current session started
- **Permission relay**, approve/deny Claude's tool use from WhatsApp
- **Self-only by default**, only *your own* linked phone can message Claude until you explicitly allow more numbers
- **Group chat support**, works in group chats with group metadata
- **Reactions**, Claude can react to messages with emoji
- **Deduplication**, prevents duplicate message processing
- **Auto-reconnect**, Claude Code restarts the server on disconnect

## Requirements

- [Bun](https://bun.sh) runtime (or Node.js 22+)
- Claude Code v2.1.80+ with channels enabled
- A WhatsApp account on your phone

---

## Setup

The steps below use **tabs for your operating system**. Pick the tab that matches the terminal you're in, the commands differ between **PowerShell** (Windows default), **Command Prompt** (Windows classic), and **macOS / Linux** (bash or zsh).

> **How to tell which shell you're in on Windows:**
> - If your prompt looks like `PS C:\Users\you>`, you're in **PowerShell**.
> - If it looks like `C:\Users\you>`, you're in **Command Prompt (cmd.exe)**.
> - We recommend **PowerShell** on Windows. It's installed by default (search "PowerShell" in the Start menu).

### 1. Install Bun

Bun is the JavaScript runtime the server runs on. Install it once per machine.

**macOS / Linux (bash, zsh):**
```bash
curl -fsSL https://bun.sh/install | bash
```

**Windows (PowerShell):**
```powershell
powershell -c "irm bun.sh/install.ps1 | iex"
```

**Windows (Command Prompt):** Bun only installs via PowerShell on Windows. Open PowerShell, run the command above, then come back to your preferred terminal.

After installing, **close and reopen your terminal** so `bun` is on your `PATH`. Verify:

```bash
bun --version
```

### 2. Install dependencies

From the folder where you cloned this repo:

**macOS / Linux:**
```bash
cd whatsapp-channel
bun install
```

**Windows (PowerShell or cmd):**
```powershell
cd whatsapp-channel
bun install
```

(`cd` works the same everywhere.)

### 3. Configure Claude Code

Claude Code needs to know where the server lives. Add this to your project's `.mcp.json` (or `~/.claude.json` to make it global):

```json
{
  "mcpServers": {
    "whatsapp": {
      "command": "bun",
      "args": ["/full/path/to/whatsapp-channel/src/index.ts"],
      "env": {
        "WA_VERBOSE": "0",
        "WA_AUTO_OPEN_QR": "0"
      }
    }
  }
}
```

**What to put for `/full/path/to/whatsapp-channel/src/index.ts`:**

- **macOS / Linux:** an absolute path like `/Users/you/workshop-kit/whatsapp-channel/src/index.ts`
- **Windows:** use forward slashes or escaped backslashes, e.g. `C:/Users/you/workshop-kit/whatsapp-channel/src/index.ts`. JSON does not allow raw backslashes. You can get the absolute path quickly:
  - **PowerShell:** `(Resolve-Path .\src\index.ts).Path`
  - **Command Prompt:** `cd src && echo %cd%\index.ts`
  - **macOS / Linux:** `realpath src/index.ts`

> **Why `WA_AUTO_OPEN_QR=0` in `.mcp.json`:** when Claude Code opens a normal chat it loads MCP servers quietly in the background. You don't want a QR page popping up every time, so we leave auto-open *off* here and turn it *on* only for the first-run CLI command in step 4.

### 4. First-run: start Claude Code with the channel and scan the QR code

This is the only command that differs across shells, environment variables are set differently in each one.

**macOS / Linux (bash, zsh):**
```bash
WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

**Windows (PowerShell):**
```powershell
$env:WA_AUTO_OPEN_QR = "1"
claude --dangerously-load-development-channels server:whatsapp
```

**Windows (Command Prompt):**
```cmd
set WA_AUTO_OPEN_QR=1
claude --dangerously-load-development-channels server:whatsapp
```

A browser window will open to a local QR code page. On your phone:

1. Open **WhatsApp** → **Settings** → **Linked Devices**
2. Tap **Link a Device**
3. Scan the QR code

Once linked, your session persists across restarts. Credentials are stored in:

- **macOS / Linux:** `~/.claude/whatsapp-channel/auth/`
- **Windows:** `%USERPROFILE%\.claude\whatsapp-channel\auth\`

You only need `WA_AUTO_OPEN_QR=1` for the first run. On subsequent runs the saved credentials are reused and no QR is needed, so you can drop the env var and just run `claude --dangerously-load-development-channels server:whatsapp`.

### 5. Send yourself a message

By default, only *your own* linked phone can talk to Claude. The easiest way to test is to message *yourself*:

- On your phone, open WhatsApp → tap the pencil/new-chat icon → search for your own name → tap **Message yourself** (WhatsApp's built-in self-chat).
- Type `hello claude` and send it.

The message arrives in your Claude Code session as:

```
<channel source="whatsapp" chat_id="1234567890@s.whatsapp.net" sender_phone="+1234567890" sender_name="You" chat_type="direct">
hello claude
</channel>
```

Claude reads it, acts on it, and replies back through WhatsApp.

---

## Allowing other people to message Claude

**Start self-only.** Get the basics working with your own phone first. Once you've confirmed messages are flowing both ways, *then* add other numbers.

To allow additional phone numbers, edit your `.mcp.json` and add them to `WA_ALLOW_FROM` as a comma-separated list of E.164 phone numbers (with the `+` and country code):

```json
"env": {
  "WA_VERBOSE": "0",
  "WA_AUTO_OPEN_QR": "0",
  "WA_ALLOW_FROM": "+14155551234,+442071838750"
}
```

Your own number is **always** allowed, even if you leave `WA_ALLOW_FROM` blank or don't list it.

Restart Claude Code for the change to take effect.

---

## Reading past WhatsApp messages on demand

Every inbound message (and every reply Claude sends) is appended to a persistent log at:

- **macOS / Linux:** `~/.claude/whatsapp-channel/history.jsonl`
- **Windows:** `%USERPROFILE%\.claude\whatsapp-channel\history.jsonl`

This means you can ask Claude about messages that arrived **before** the current session started, or messages Claude wasn't actively listening for. Two tools are exposed:

### `whatsapp_history`

Read past messages with optional filters.

Parameters (all optional):

| Parameter | Description |
|-----------|-------------|
| `chat_id` | Limit to a single chat (direct JID or group JID) |
| `sender_phone` | Limit to messages from a specific phone number (`+1234567890`) |
| `contains` | Case-insensitive substring match on the message body |
| `since_ts` | Only messages at or after this Unix timestamp (ms) |
| `until_ts` | Only messages at or before this Unix timestamp (ms) |
| `direction` | `"in"` (received) or `"out"` (sent by you/Claude) |
| `limit` | Max results, 1-500 (default 50) |

Example prompts:
- *"Read the last 20 WhatsApp messages I've received."*
- *"Show me every WhatsApp message mentioning 'invoice' from the last week."*
- *"What did Alice say in her group chat yesterday?"*

### `whatsapp_list_chats`

List all chats that have appeared in the history log, sorted by most recent activity. Useful when Claude needs to find a `chat_id` for a conversation it didn't see live.

Example prompt: *"What WhatsApp chats have I received messages in recently?"*

> **Note on scope:** The history log only contains messages the server has *observed while running*. It is not a dump of your entire WhatsApp account, Baileys cannot fetch historical messages from WhatsApp's servers. Think of it as "everything the channel has seen since you first installed it."

---

## Configuration Reference

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WA_ALLOW_FROM` | Additional E.164 phone numbers to allow, comma-separated (your own is always included) | `""` (self-only) |
| `WA_AUTH_DIR` | Custom auth directory path | `~/.claude/whatsapp-channel/auth/` |
| `WA_VERBOSE` | Enable verbose logging (`1` or `true`) | `0` |
| `WA_AUTO_OPEN_QR` | Auto-open QR code page in browser when login is needed (`1` or `true`) | `0` |

### Permission Relay

When Claude needs to run a tool that requires approval, the permission prompt is forwarded to WhatsApp:

```
🔧 Claude wants to run Bash:
List files in the current directory

Reply yes abcde or no abcde
```

Reply with `yes <code>` or `no <code>` to approve or deny. You can also answer in the Claude Code terminal, whichever comes first is used.

---

## Architecture

```
WhatsApp (phone)
    │
    ▼
Baileys WebSocket ──── WhatsApp Web servers
    │
    ▼
monitor.ts (inbound message handler)
    │
    ▼
index.ts (MCP channel server) ──── stdio ──── Claude Code
    │        │                                      │
    │        └── history.jsonl (append on in/out)   │
    │                                               │
    └── reply tool ◄───────────────────────────────┘
```

- **session.ts**, Baileys socket creation, QR auth, credential management
- **monitor.ts**, Inbound message listener, deduplication, access control
- **history.ts**, JSONL persistence and query for past messages
- **index.ts**, MCP server with channel capability, reply/react/history tools, permission relay

---

## Troubleshooting

### I'm on Windows and the README gave me `curl | bash` commands
Earlier versions of this README were Unix-only. Make sure you're reading the version in this branch, and use the **Windows (PowerShell)** tabs above, they use `$env:NAME = "value"` for environment variables instead of `NAME=value`.

### `bun` is not recognised after installing
Close and reopen your terminal window. On Windows you may need to open a *new* PowerShell session (not the one you installed from).

### QR code doesn't appear
- Make sure no other WhatsApp Web session is active for this account
- Delete the auth directory and restart:
  - **macOS / Linux:** `rm -rf ~/.claude/whatsapp-channel/auth`
  - **Windows (PowerShell):** `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\whatsapp-channel\auth"`

### Messages not arriving
- Only your linked phone is allowed by default. To allow others, add their numbers to `WA_ALLOW_FROM` (see section above)
- Run with `WA_VERBOSE=1` to see blocked messages in the debug log at `~/.claude/whatsapp-channel/debug.log`
- Verify Claude Code started with `--dangerously-load-development-channels`

### Session expired
- WhatsApp Web sessions can expire if your phone is offline too long
- Delete the auth directory and scan a new QR code (see QR troubleshooting above)

### "blocked by org policy"
Your Team or Enterprise admin needs to enable channels in the Claude Code settings.

---

## Limitations

- Media files are detected but not downloaded (shown as placeholders like `<media:image>`)
- WhatsApp Web requires your phone to have internet access
- Uses the unofficial WhatsApp Web protocol (Baileys), not endorsed by Meta
- Custom channels need `--dangerously-load-development-channels` during the research preview
- The `whatsapp_history` tool can only return messages that the server observed while running, it cannot back-fill messages from before you installed the channel

## License

MIT
