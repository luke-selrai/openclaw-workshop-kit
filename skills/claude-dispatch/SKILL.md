---
name: claude-dispatch
description: Set up Claude Dispatch (phone-to-desktop task delegation) or Remote Control (terminal sessions from phone). Guides pairing, QR scan, and troubleshooting.
---

# Claude Dispatch & Remote Control

Control your local Claude session from your phone — assign tasks while away from your desk.

> **Full setup guide for users:** `~/workshop-kit/docs/dispatch/DISPATCH-SETUP.md`

---

## Two Options — Recommend Based on User Profile

Ask: "Do you use Claude Desktop (the app) or Claude Code (the terminal)?"

**If Claude Desktop → Dispatch:**
- Non-technical users, Cowork workflows
- QR code setup, ~2 minutes
- Entry: Claude Desktop → Cowork → Dispatch tab

**If Claude Code → Remote Control:**
- Developers, terminal sessions
- Entry: `claude remote-control` or `claude --remote-control`
- Or inside a session: `/remote-control`

---

## Dispatch Setup (Claude Desktop)

Guide conversationally — one step at a time:

1. "Open Claude Desktop and click the **Cowork** tab at the top."
2. "Click **Dispatch** in the left sidebar."
3. "Click **Get Started**. Turn on both toggles: **File access** and **Keep-awake**. Then click **Finish setup**."
4. "A QR code will appear on your screen. Open the **Claude app on your phone**, go to **Dispatch** in the sidebar, tap **Pair with your desktop**, and scan the QR code."
5. "You're connected. Try sending a message from your phone."

### Requirements
- Claude Pro ($20/mo) or Max ($100/mo)
- Claude Desktop (latest) + Claude mobile app (latest)
- macOS or Windows
- Computer must stay awake

---

## Remote Control Setup (Claude Code)

1. Start a session: `claude remote-control` or `claude --remote-control`
2. A URL and QR code appear in the terminal
3. Open the URL on any browser, or scan the QR in the Claude mobile app
4. Press spacebar to toggle QR display

### Useful flags
- `--name "My Project"` — custom session name
- `--spawn worktree` — isolated git worktree per session

### Requirements
- Claude Code v2.1.51+
- Claude Pro or Max subscription (not API keys)
- Must run `claude` once first to accept workspace trust

---

## What to Try First

Suggest simple tasks:

```
"Find the latest invoice PDF in my Documents folder and tell me the total."
"Summarise the 3 most recent files in my Downloads."
"Search my emails for anything from [name] in the last week."
```

Say: "Start with simple file tasks. More complex automations work but are less reliable — Dispatch is still a research preview."

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Dispatch not in sidebar | Reinstall Claude Desktop to force the update |
| QR code won't scan | Update Claude mobile app to latest version |
| Task stops mid-way | Computer went to sleep — enable Keep-awake toggle |
| Can't pair phone | Both devices must be online and logged into the same Claude account |
| "Requires a subscription" | User is on API key — run `/login` to sign in via claude.ai |
| Remote Control session not visible | Both apps must be latest version; check desktop is awake |

---

## When to Recommend This

After the user has:
1. Completed local setup (Claude Code + tools)
2. Connected at least one tool (GWS, M365, Telegram, etc.)

Say: "Would you like to control your Claude from your phone? You can send tasks from anywhere and come back to finished work."
