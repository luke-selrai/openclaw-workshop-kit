# WhatsApp Channel for Claude Code

A two-way WhatsApp channel for Claude Code sessions, built on [Baileys](https://github.com/WhiskeySockets/Baileys) (WhatsApp Web). Send messages to Claude from WhatsApp, and Claude replies back.

## Features

- **QR Code Login** — scan with your phone to link (no Business API needed)
- **Two-way messaging** — receive messages in Claude, Claude replies via WhatsApp
- **Permission relay** — approve/deny Claude's tool use from WhatsApp
- **Self-only by default** — only your linked phone can message Claude (add more numbers via config)
- **Group chat support** — works in group chats with group metadata
- **Reactions** — Claude can react to messages with emoji
- **Deduplication** — prevents duplicate message processing
- **Auto-reconnect** — Claude Code restarts the server on disconnect

## Requirements

- [Bun](https://bun.sh) runtime (or Node.js 22+)
- Claude Code v2.1.80+ with channels enabled
- A WhatsApp account on your phone

## Quick Start

### 1. Install dependencies

```bash
cd whatsapp-channel
bun install
```

### 2. Configure Claude Code

Copy the `.mcp.json` to your project or add to `~/.claude.json`:

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

> **Tip:** Keep `WA_AUTO_OPEN_QR` set to `"0"` in `.mcp.json` so the QR page doesn't auto-open when the server loads as a regular MCP server. Pass `WA_AUTO_OPEN_QR=1` as a shell env var when starting via the CLI (see step 3).

### 3. Start Claude Code with the channel

```bash
WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

> **Note:** `WA_AUTO_OPEN_QR=1` tells the server to automatically open the QR code page in your browser on first login. Without it, the QR page URL is logged but the browser won't open automatically. This prevents the QR page from popping up when the server is loaded as a regular MCP server (e.g. when opening Claude Code chat normally).

### 4. Scan the QR code

A browser window will open with the QR code (if `WA_AUTO_OPEN_QR=1` is set). Open WhatsApp on your phone:
1. Go to **Settings > Linked Devices**
2. Tap **Link a Device**
3. Scan the QR code

Once linked, your session persists across restarts (credentials stored in `~/.claude/whatsapp-channel/auth/`).

### 5. Send a message

Message the linked WhatsApp number from another phone, or from a group. The message arrives in your Claude Code session as:

```
<channel source="whatsapp" chat_id="1234567890@s.whatsapp.net" sender_phone="+1234567890" sender_name="John" chat_type="direct">
Hello Claude, can you help me with something?
</channel>
```

Claude reads it, acts on it, and replies back through WhatsApp.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `WA_ALLOW_FROM` | Additional E.164 phone numbers to allow (your own is always included) | `""` (self-only) |
| `WA_AUTH_DIR` | Custom auth directory path | `~/.claude/whatsapp-channel/auth/` |
| `WA_VERBOSE` | Enable verbose logging (`1` or `true`) | `0` |
| `WA_AUTO_OPEN_QR` | Auto-open QR code page in browser when login is needed (`1` or `true`) | `0` |

### Sender Allowlist

By default, **only your linked phone number** can message Claude (self-only mode). Your phone is auto-detected and added to the allowlist automatically — no configuration needed.

To allow additional phone numbers (e.g. a second phone or a colleague):

```json
"env": {
  "WA_ALLOW_FROM": "+0987654321,+1122334455"
}
```

Your own number is always allowed, even if not listed in `WA_ALLOW_FROM`.

## Permission Relay

When Claude needs to run a tool that requires approval, the permission prompt is forwarded to WhatsApp:

```
🔧 *Claude wants to run Bash:*
List files in the current directory

Reply *yes abcde* or *no abcde*
```

Reply with `yes <code>` or `no <code>` to approve or deny. You can also answer in the Claude Code terminal — whichever comes first is used.

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
    │                                              │
    └── reply tool ◄───────────────────────────────┘
```

- **session.ts** — Baileys socket creation, QR auth, credential management
- **monitor.ts** — Inbound message listener, deduplication, access control
- **index.ts** — MCP server with channel capability, reply tool, permission relay

## Troubleshooting

### QR code doesn't appear
- Make sure no other WhatsApp Web session is active for this account
- Delete `~/.claude/whatsapp-channel/auth/` and restart

### Messages not arriving
- Only your linked phone is allowed by default. To allow others, add their numbers to `WA_ALLOW_FROM`
- Run with `WA_VERBOSE=1` to see blocked messages in the debug log
- Verify Claude Code started with `--dangerously-load-development-channels`

### Session expired
- WhatsApp Web sessions can expire if your phone is offline too long
- Delete the auth directory and scan a new QR code

### "blocked by org policy"
- Your Team or Enterprise admin needs to enable channels in the Claude Code settings

## Limitations

- Media files are detected but not downloaded (shown as placeholders like `<media:image>`)
- WhatsApp Web requires your phone to have internet access
- Uses the unofficial WhatsApp Web protocol (Baileys) — not endorsed by Meta
- Custom channels need `--dangerously-load-development-channels` during the research preview

## License

MIT
