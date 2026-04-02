---
name: claude-dispatch
description: Guide for controlling Claude remotely from your phone or any browser.
  Covers both Dispatch (for non-technical Cowork users) and Remote Control (for
  developers using Claude Code terminal). Triggers on "set up dispatch", "remote
  control", "control Claude from my phone", "assign tasks remotely", or "use Claude
  from mobile".
metadata:
  category: AI & Automation
  tags:
    - remote
    - mobile
    - dispatch
    - cowork
    - selr-ai
    - openclaw
---

# Claude Dispatch & Remote Control

## Overview

Claude Dispatch and Remote Control let you control your local Claude session from your phone or any browser — so you can assign tasks while away from your desk and come back to finished work.

There are **two versions** of this feature depending on how you use Claude:

| Feature | Best For | Entry Point |
|---|---|---|
| **Dispatch** | Non-technical users, Cowork workflows | Claude Desktop → Cowork → Dispatch tab |
| **Remote Control** | Developers, Claude Code terminal sessions | `claude remote-control` command |

Both work the same way at the core: your computer does the heavy lifting locally, and your phone is just the control interface.

---

## Which One Should I Use?

**Use Dispatch if:**
- You're a business owner or non-developer
- You use Claude primarily through the Desktop app (Cowork mode)
- You want a simple QR-code setup with no terminal commands

**Use Remote Control if:**
- You're a developer working in the Claude Code terminal
- You want to continue an active coding/agent session from your phone
- You need access to your local filesystem, MCP servers, and project config remotely

---

## Requirements

Both options require:
- **Claude Pro or Max subscription** (API keys are not supported)
- **Claude Desktop** (latest version — macOS or Windows)
- **Claude mobile app** (iOS or Android, latest version)
- **Desktop must stay awake** — enable "Prevent Sleep" during setup or your session will pause

Remote Control additionally requires:
- **Claude Code v2.1.51 or later** — check with `claude --version`
- Run `claude` at least once in your project directory to accept workspace trust

---

## Option A: Dispatch (for Cowork users)

### Setup Steps

1. Open **Claude Desktop** on your computer
2. Click **Cowork** in the left sidebar
3. Click **Dispatch** in the left panel
4. Click **Get Started** — you'll see a QR code on screen
5. Open the **Claude mobile app** on your phone
6. Tap the **Dispatch tab** in the sidebar
7. Tap **Pair with your desktop** and scan the QR code

That's it — no API keys, no config files, no terminal commands.

### How It Works

- A single persistent conversation thread syncs across your phone and desktop
- Send a task from your phone → Claude runs it on your desktop using all your local files, connectors, and plugins
- Every connector you've set up in Cowork (Gmail, Slack, Notion, Google Drive, etc.) is automatically available through Dispatch — nothing extra to configure
- You can close your phone after sending a task; Claude keeps working and messages you the result

### Example Tasks You Can Delegate From Your Phone

```
"Summarise all unread emails from the last 24 hours"
"Pull the March CSV files from my Sales folder and create a summary table"
"Check my Slack messages and flag anything urgent"
"Update the client follow-up doc in Google Drive with today's notes"
```

### Limitations

- Desktop must stay awake (enable "Prevent Sleep" toggle during setup)
- Single conversation thread only — no separate threads per task
- Sequential tasks (where task B depends on task A) must be sent one at a time
- Currently macOS and Windows only; no Linux support for Dispatch

---

## Option B: Remote Control (for Claude Code / terminal users)

### Setup Steps

**Start a new Remote Control session:**
```bash
claude remote-control
```
This starts a server in your terminal and displays a session URL + QR code.

**Start an interactive session with Remote Control enabled:**
```bash
claude --remote-control
# or with a custom name:
claude --remote-control "My Project"
```

**Enable Remote Control from inside an existing session:**
```
/remote-control
# or with a name:
/remote-control My Project
```

**Enable Remote Control automatically for every session:**
Run `/config` inside Claude Code and toggle the Remote Control setting on.

### Connecting From Your Phone or Browser

Once a session is running, connect using any of these methods:

1. **Open the session URL** shown in your terminal in any browser → goes straight to `claude.ai/code`
2. **Scan the QR code** shown in terminal → opens directly in the Claude mobile app (press spacebar to toggle QR display)
3. **Open `claude.ai/code` or the Claude app** → find your session by name in the session list (look for the computer icon with a green dot)

### Useful Flags

| Flag | What It Does |
|---|---|
| `--name "Project Name"` | Sets a custom session title visible in the session list |
| `--spawn worktree` | Each remote session gets its own git worktree (prevents file conflicts) |
| `--capacity N` | Max concurrent sessions (default: 32) |
| `--verbose` | Show detailed connection logs |

### How It Works

- Your local Claude Code session keeps running on your machine — nothing moves to the cloud
- Your phone or browser is just a window into that local session
- Your full local environment is available: filesystem, MCP servers, tools, project config
- If your laptop sleeps or network drops, the session reconnects automatically when your machine comes back online
- You can type from your terminal and your phone simultaneously — conversation stays in sync

---

## Dispatch vs Remote Control — Quick Comparison

| | Dispatch | Remote Control |
|---|---|---|
| Setup | QR code scan, 2 minutes | Terminal command |
| For who | Business owners, non-devs | Developers |
| Works in | Cowork (Claude Desktop) | Claude Code (terminal) |
| OS support | macOS, Windows | macOS, Linux, Windows |
| Local files | ✅ | ✅ |
| MCP servers / connectors | ✅ (via Cowork) | ✅ |
| Skills / plugins | ✅ | ✅ |
| Cron / scheduled tasks | ✅ (via Cowork schedules) | ✅ |
| Works on Linux servers | ❌ | ✅ |
| API key support | ❌ | ❌ |

---

## Workshop Recommendation

Introduce this as an **optional step** after participants have:
1. Installed Claude Code / Claude Desktop
2. Set up at least one connector (GWS, Outlook, GHL, etc.)
3. Installed a basic skills package

**Suggested prompt for the assistant to recommend this:**
> "Would you like to be able to talk to your Claude from your phone, even when you're away from your desk? You can set up Dispatch (easy, no terminal) or Remote Control (for developers) to do exactly that."

The assistant should ask: *"Do you use Claude Code in the terminal, or mainly Claude Desktop?"* and recommend accordingly.

---

## Troubleshooting

| Error | Fix |
|---|---|
| "Remote Control requires a claude.ai subscription" | You're logged in via API key — run `/login` to sign in through claude.ai instead |
| "Remote Control requires a full-scope login token" | Run `/login` to re-authenticate through the browser |
| Session not appearing in mobile app | Make sure both apps are on the latest version; check desktop is awake |
| Desktop goes to sleep mid-task | Enable "Prevent Sleep" in Dispatch setup, or adjust macOS/Windows power settings |
| Team/Enterprise: feature not showing | Admin needs to enable Remote Control toggle in Claude Code admin settings |

---

## References

- [Official Remote Control Docs](https://code.claude.com/docs/en/remote-control)
- [Dispatch Support Article](https://support.claude.com/en/articles/13947068-assign-tasks-to-claude-from-anywhere-in-cowork)
- [Anthropic Blog: Dispatch + Computer Use](https://claude.com/blog/dispatch-and-computer-use)
