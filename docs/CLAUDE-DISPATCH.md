# Claude Dispatch & Remote Control

Prepared for: Claude Code Workshop Kit
Built by: Selr AI — selrai.com.au

---

## Table of Contents

1. [Overview](#1-overview)
2. [What Is Claude Dispatch](#2-what-is-claude-dispatch)
3. [What Is Remote Control](#3-what-is-remote-control)
4. [How They Differ](#4-how-they-differ)
5. [When to Use Each One](#5-when-to-use-each-one)
6. [Setting Up Dispatch](#6-setting-up-dispatch)
7. [Setting Up Remote Control](#7-setting-up-remote-control)
8. [Known Limitations](#8-known-limitations)
9. [Troubleshooting](#9-troubleshooting)
10. [Official Documentation](#10-official-documentation)

---

## 1. Overview

Claude Dispatch and Remote Control are two separate features that 
let you interact with your Claude session from your phone or any 
browser — so you can assign tasks while away from your desk and 
come back to finished work.

They are different features designed for different types of users:

| Feature | For Who | Entry Point |
|---|---|---|
| **Dispatch** | Business owners, non-developers | Claude Desktop → Cowork → Dispatch tab |
| **Remote Control** | Developers, terminal users | `claude remote-control` command |

Both work the same way at the core: your computer does the 
heavy lifting locally, and your phone is just the control 
interface.

---

## 2. What Is Claude Dispatch

Claude Dispatch is a feature inside **Cowork mode in Claude 
Desktop**. It lets non-technical users delegate tasks to Claude 
from their phone using a simple QR code — no terminal, no 
commands, no configuration files.

**Released:** 17 March 2026

**How it works:**
- You scan a QR code on your desktop with the Claude mobile app
- A single conversation thread syncs between your phone and desktop
- You send a task from your phone
- Claude runs it on your desktop using all your local files, 
  connectors, and plugins
- You can close your phone after sending — Claude keeps working 
  and sends you the result when done

**Every connector you have set up in Cowork is automatically 
available through Dispatch** — Gmail, Slack, Notion, Google 
Drive, and anything else. Nothing extra to configure.

**Example tasks you can delegate from your phone:**

"Summarise all unread emails from the last 24 hours"
"Pull the March CSV files from my Sales folder and create a summary"
"Check my Slack messages and flag anything urgent"
"Update the client follow-up doc in Google Drive with today's notes"

---

## 3. What Is Remote Control

Remote Control (`/rc`) is a feature inside **Claude Code 
terminal sessions**. It lets developers connect a phone or 
any browser to an active local Claude Code session — giving 
full access to the local filesystem, MCP servers, tools, 
and project config remotely.

**Released:** 25 February 2026
**Requires:** Claude Code v2.1.51 or later

**How it works:**
- You run `claude remote-control` in your terminal
- A session URL and QR code appear in the terminal
- You connect from your phone or any browser
- Your full local Claude Code environment is available remotely
- Your terminal and phone stay in sync simultaneously

**Nothing moves to the cloud** — your local Claude Code session 
keeps running on your machine. Your phone is just a window into 
that local session.

---

## 4. How They Differ

| | Dispatch | Remote Control |
|---|---|---|
| Setup | QR code scan, 2 minutes | Terminal command |
| For who | Business owners, non-devs | Developers |
| Works in | Cowork (Claude Desktop) | Claude Code (terminal) |
| OS support | macOS, Windows | macOS, Linux, Windows |
| Local files | ✅ | ✅ |
| MCP servers / connectors | ✅ (via Cowork) | ✅ |
| Skills / plugins | ✅ | ✅ |
| Works on Linux servers | ❌ | ✅ |
| API key support | ❌ | ❌ |
| Requires subscription | Pro or Max | Pro or Max |

**Key difference:**
- Dispatch is a task delegation tool — you send a job and 
  come back to results
- Remote Control is a session mirror — you see and control 
  the live terminal session in real time

---

## 5. When to Use Each One

**Use Dispatch if:**
- The participant is a business owner or non-developer
- They use Claude primarily through the Desktop app
- They want a simple phone setup with no terminal commands
- They want to delegate tasks and check results later

**Use Remote Control if:**
- The participant is a developer working in Claude Code terminal
- They want to continue an active coding or agent session 
  from their phone
- They need access to their local filesystem and MCP servers 
  remotely
- They are working on Linux or need server access

**Workshop assistant decision prompt:**
> "Do you use Claude Code in the terminal, or mainly 
> Claude Desktop?"
- Claude Desktop → recommend Dispatch
- Claude Code terminal → recommend Remote Control

---

## 6. Setting Up Dispatch

### Requirements
- Claude Pro or Max subscription
- Claude Desktop (latest version — macOS or Windows)
- Claude mobile app (iOS or Android, latest version)
- Desktop must stay awake during use

### Steps

**Step 1 —** Open Claude Desktop on your computer

**Step 2 —** Click **Cowork** in the left sidebar

**Step 3 —** Click **Dispatch** in the left panel

**Step 4 —** Click **Get Started** — a QR code appears on screen

**Step 5 —** Open the Claude mobile app on your phone

**Step 6 —** Tap the **Dispatch tab** in the sidebar

**Step 7 —** Tap **Pair with your desktop** and scan the QR code

That is it — no API keys, no config files, no terminal commands.

---

## 7. Setting Up Remote Control

### Requirements
- Claude Pro or Max subscription
- Claude Code v2.1.51 or later
  - Check with: `claude --version`
  - Update with: `npm update -g @anthropic-ai/claude-code`
- Run `claude` at least once in your project directory to 
  accept workspace trust

### Steps

**Step 1 —** Start a Remote Control session:
```bash
claude remote-control
```
This starts a server in your terminal and displays a 
session URL and QR code.

**Step 2 —** Connect from your phone or browser using 
any of these methods:
- Open the session URL shown in your terminal in any browser
- Scan the QR code with the Claude mobile app
  (press spacebar to toggle QR display)
- Open `claude.ai/code` → find your session by name 
  in the session list (look for the computer icon 
  with a green dot)

**Useful flags:**

| Flag | What It Does |
|---|---|
| `--name "Project Name"` | Sets a custom session title |
| `--spawn worktree` | Each remote session gets its own git worktree |
| `--capacity N` | Max concurrent sessions (default: 32) |
| `--verbose` | Show detailed connection logs |

**Enable Remote Control from inside an existing session:**

/remote-control
**Enable automatically for every session:**
Run `/config` inside Claude Code and toggle Remote Control on.

---

## 8. Known Limitations

**Dispatch:**
- Desktop must stay awake — enable Prevent Sleep during setup
- Single conversation thread only — no separate threads per task
- Sequential tasks must be sent one at a time
- macOS and Windows only — no Linux support
- Pro or Max subscription required — API keys not supported

**Remote Control:**
- Computer must stay on — session pauses if laptop sleeps
- Pro or Max subscription required — API keys not supported
- Claude Code v2.1.51 or later required
- Team or Enterprise accounts require admin to enable 
  Remote Control in Claude Code admin settings

---

## 9. Troubleshooting

| Error | Fix |
|---|---|
| "Remote Control requires a claude.ai subscription" | Logged in via API key — run `/login` to sign in through claude.ai |
| "Remote Control requires a full-scope login token" | Run `/login` to re-authenticate through browser |
| Session not appearing in mobile app | Make sure both apps are on latest version and desktop is awake |
| Desktop goes to sleep mid-task | Enable Prevent Sleep in Dispatch setup or adjust power settings |
| Team accounts — feature not showing | Admin must enable Remote Control toggle in Claude Code admin settings |
| QR code not scanning | Press spacebar in terminal to toggle QR display |

---

## 10. Official Documentation

- Remote Control Docs: https://code.claude.com/docs/en/remote-control
- Dispatch Support: https://support.claude.com/en/articles/13947068-assign-tasks-to-claude-from-anywhere-in-cowork
- Anthropic Blog — Dispatch + Computer Use: https://claude.com/blog/dispatch-and-computer-use

---

## Workshop Placement

Introduce this as an **optional step** after participants have:
1. Installed Claude Code or Claude Desktop
2. Set up at least one connector (GWS, Outlook, GHL, etc.)
3. Installed a basic skills package

**Suggested assistant prompt:**
> "Would you like to be able to talk to your Claude from your 
> phone, even when you are away from your desk? You can set up 
> Dispatch (easy, no terminal) or Remote Control (for developers) 
> to do exactly that."

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
