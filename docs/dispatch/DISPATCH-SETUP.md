# Claude Desktop Dispatch
## Workshop Setup Guide

**What it is:** A feature inside Claude Desktop that turns your phone into a remote control for your desktop AI agent. Assign a task from your phone, walk away, come back to finished work.

---

## How It Works (Plain English)

```
Your Phone  →  sends task  →  Claude Desktop (your computer)
                                      ↓
                              executes using your local files,
                              connectors, plugins, and apps
                                      ↓
Your Phone  ←  gets results  ←  Claude Desktop
```

- Your **computer does the work** — not the cloud
- Your **phone is the remote control**
- One persistent conversation thread across both devices
- Everything stays on your machine — files never leave your computer

---

## Requirements

| Item | Details |
|---|---|
| Claude Desktop | Latest version — [claude.ai/download](https://claude.ai/download) |
| Claude Mobile App | Latest version — iOS or Android |
| Plan | Pro ($20/mo) or Max ($100/mo) |
| Platform | macOS or Windows x64 |
| Internet | Both devices must be connected |
| Computer | Must stay **awake** — this is not cloud-based |

> ⚠️ **Important:** If your computer goes to sleep, Dispatch stops. Enable the Keep-awake toggle during setup.

---

## Setup Steps (~2 minutes)

### Step 1: Update Claude Desktop
Make sure you have the latest version installed.
👉 [claude.ai/download](https://claude.ai/download)

### Step 2: Open Cowork tab
In Claude Desktop, click the **Cowork** tab at the top.

### Step 3: Click Dispatch
In the left sidebar, click **Dispatch**.

### Step 4: Click Get Started
You'll see two toggle options — turn both on:
- ✅ **File access** — allows Claude to read/write your local files
- ✅ **Keep-awake** — prevents your computer from sleeping during tasks

Then click **Finish setup**.

### Step 5: Scan the QR Code
A QR code appears on your desktop screen.

Open the **Claude app on your phone** → go to **Dispatch** in the sidebar → tap **Pair with your desktop** → scan the QR code.

### Step 6: You're connected ✅
A conversation thread appears in the Dispatch section on **both devices**.

Type a message from your phone — Claude gets to work on your desktop.

---

## What You Can Do With It

### ✅ Works well
- Find and summarise files on your computer
- Analyse spreadsheets and create reports
- Draft documents using files in your local folders
- Search emails and Slack via connected apps
- Compile research from Google Drive

### ❌ Less reliable (research preview limitations)
- Opening desktop apps (e.g. Safari, Terminal)
- Complex multi-step automations
- iMessage and native macOS app interactions
- Tasks with ~50% success rate on complex operations

---

## Key Differences — Dispatch vs Other Tools

| | Dispatch | Claude Workshop Kit (Channels) | Claude Code Remote |
|---|---|---|---|
| **Setup time** | ~2 minutes (QR code) | Complex (Node.js, Docker, env vars) | Terminal / SSH |
| **Who it's for** | Non-technical users | Advanced users | Developers |
| **Connection** | One-shot task delegation | Persistent bidirectional session | Code execution |
| **Always-on** | ❌ Needs computer awake | ✅ Can run cron jobs | ❌ Needs computer awake |
| **Best for** | Files, docs, email, research | Telegram/iMessage automation | Writing and running code |

---

## How Dispatch Connects to Claude Code

Dispatch is not just for Cowork. When you send a development task from your phone (e.g. "fix the login bug"), Dispatch automatically spawns a **Claude Code session** on your desktop:

1. You send a task from your phone
2. Dispatch decides if it's development work
3. If yes — it opens a Code session automatically (visible in the Code tab with a **Dispatch** badge)
4. You get a push notification when it finishes or needs approval

> App approvals in Dispatch-spawned Code sessions expire after **30 minutes** and re-prompt (vs. full session duration for regular Code sessions).

---

## Security Notes

- All processing happens **locally on your machine**
- Files never leave your computer
- The Dispatch bridge is **end-to-end encrypted**
- Claude will **pause and notify your phone** before destructive actions (deleting files, moving directories)
- Claude can only access folders and apps you explicitly approved during setup

---

## Example Tasks to Try First

Start with simple, file-focused tasks:

```
"Find the latest invoice PDF in my Documents folder and tell me the total amount."

"Summarise the 3 most recent files in my Downloads folder."

"Search my emails for anything from Luke in the last 7 days and give me a summary."

"Read the sales CSV on my Desktop and give me a quick summary of the top 3 rows."
```

Avoid complex multi-step tasks until you're comfortable with how Dispatch behaves.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Dispatch not in sidebar | Delete and reinstall Claude Desktop — this forces the update |
| QR code won't scan | Make sure Claude mobile app is updated to latest version |
| Task stops mid-way | Your computer went to sleep — enable Keep-awake toggle |
| Can't pair phone | Make sure both devices are on the internet and logged into same Claude account |
| Connector not working | Re-authenticate the connector in Cowork settings first |

---

## Status

Claude Desktop Dispatch launched **March 17, 2026** as a **research preview**.

- Max plan ($100/mo): ✅ Available now
- Pro plan ($20/mo): ✅ Rolling out now
- Team / Enterprise: Coming soon

As a research preview, expect occasional failures on complex tasks. Simple file lookups and summaries are most reliable.

---

*Last updated: April 2026 | Source: Anthropic Help Center, Claude Code Docs*
