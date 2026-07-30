---
name: claude-dispatch
description: "Sets up Claude Dispatch (phone-to-desktop tasks via Cowork) or Claude Code Remote Control. Use when the user wants to run tasks from their phone, pair phone and desktop, fix a QR-scan or pairing failure, or asks whether Dispatch is private."
---

# Claude Dispatch & Remote Control

Bundled artifacts (read these to verify the SKILL works end-to-end):

- [`examples/phone-to-desktop-session.md`](examples/phone-to-desktop-session.md), full worked transcript.
- [`CHANGELOG.md`](CHANGELOG.md), version history.


Control your local Claude session from your phone - assign tasks while away from your desk, come back to finished work.

---

## Two Options - Recommend Based on User Profile

Ask: *"Do you use Claude Desktop (the app with a window) or Claude Code (the text-based command window)?"*

**If Claude Desktop → Dispatch** (preferred for most workshop attendees):
- Non-technical users, Cowork workflows
- ~2-minute setup via QR code pairing
- Entry: Claude Desktop → Cowork tab → Dispatch in sidebar

**If Claude Code → Remote Control:**
- Developers, terminal-based sessions
- Entry: `claude remote-control` or `claude --remote-control`
- Or inside a running session: `/remote-control`

---

## Dispatch Setup (Claude Desktop) - conversational, one step at a time

Walk the user through these in separate messages, waiting for confirmation between each:

1. *"Open Claude Desktop and click the **Cowork** tab at the top. Tell me when you see it."*
2. *"In the left sidebar, click **Dispatch**."*
3. *"Click **Get Started**. Turn on both toggles: **File access** (lets me read and write your local files) and **Keep-awake** (stops your computer sleeping while I'm working). Then click **Finish setup**."*
4. *"A QR code will appear on your screen. Open the **Claude app on your phone**, tap **Dispatch** in the sidebar, tap **Pair with your desktop**, and scan the QR code."*
5. *"You're connected. Try sending a short message from your phone - something like 'what files are on my desktop'."*

### Requirements to flag up-front

- **Plan:** Claude Pro ($20/mo) or Max ($100/mo). Team/Enterprise not supported yet (as of April 2026).
- **Platform:** macOS or Windows x64.
- **Apps:** latest Claude Desktop + latest Claude mobile app, both signed into the same Claude account.
- **Computer must stay awake.** This is not a cloud service - if the laptop sleeps, Dispatch stops. The Keep-awake toggle in Step 3 prevents this during tasks.

---

## Remote Control Setup (Claude Code)

1. Tell the user to start a session with `claude remote-control` or `claude --remote-control`.
2. A URL and QR code print in the terminal.
3. Tell them: *"Open the URL on any browser, or scan the QR code with the Claude app on your phone."*
4. Tip they can use: *"Press spacebar in the command window to hide or show the QR code."*

### Useful flags
- `--name "My Project"` - custom session name (shows on the phone)
- `--spawn worktree` - isolated git worktree per session (advanced, for parallel work)

### Requirements
- Claude Code v2.1.51+
- Claude Pro or Max subscription (not API keys - if the user is API-key-authed, tell them to run `/login` in Claude Code to sign in via claude.ai first)
- Must have run `claude` once before to accept the workspace trust prompt

---

## How Dispatch Connects to Claude Code

When the user sends a **development** task from their phone (e.g., "fix the login bug in my repo"), Dispatch automatically spawns a **Claude Code session** on the desktop:

1. User sends a task from the phone.
2. Dispatch classifies it as dev work vs non-dev.
3. If dev → it opens a Code session automatically (visible in the Code tab with a **Dispatch** badge).
4. The user gets a push notification when it finishes, or when Claude needs approval for something.

> **Approval expiration:** Tool-use approval requests inside Dispatch-spawned Code sessions expire after **30 minutes** of no response and re-prompt. This is shorter than regular Code sessions (where approvals last the full session). Tell the user this up front if they're running a long task and might not check their phone for a while.

---

## Security

Worth telling a privacy-conscious user plainly:

- **All processing happens locally on the user's machine.** Files never leave the computer. The Dispatch bridge is end-to-end encrypted between the phone and the desktop.
- **Destructive actions pause for approval.** Anything that would delete files, move directories, or change protected state pauses and notifies the phone first - the user taps to approve.
- **Scope is explicit.** Claude can only access folders and apps the user turned on during the Get Started toggles (Step 3). There's no hidden default access.

---

## What to Try First - and What to Avoid

### Works well (start here)
- Finding and summarising files on the user's computer
- Analysing spreadsheets and creating reports
- Drafting documents using existing local folders
- Searching emails and Slack via connected apps
- Compiling research from Google Drive

Sample tasks to offer:

```
"Find the latest invoice PDF in my Documents folder and tell me the total."
"Summarise the 3 most recent files in my Downloads."
"Search my emails for anything from [name] in the last week."
"Read the sales CSV on my Desktop and give me a quick summary."
```

### Less reliable (still research preview)
- Opening desktop apps (e.g. Safari, Terminal)
- Complex multi-step automations
- iMessage / native macOS app interactions from Dispatch (use the iMessage plugin for those - see `imessage-connector` skill)
- Anything with a ~50% success rate on complex multi-step operations

Tell the user plainly: *"Dispatch is still research preview. Simple file and email tasks work really well. Complex multi-step automations sometimes fail - try those once you've seen how it behaves on simpler stuff."*

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Dispatch not in sidebar | Update Claude Desktop to latest. If still missing, delete and reinstall - this forces the update to pick up. |
| QR code won't scan | Update Claude mobile app to latest version. |
| Task stops mid-way | Computer went to sleep - turn on the Keep-awake toggle from Step 3. |
| Can't pair phone with desktop | Both devices must be online and signed into the **same** Claude account. |
| "Requires a subscription" error | User is signed in via API key. Tell them to run `/login` in Claude Code to sign into claude.ai, then retry. |
| Connector (Google Workspace / Outlook / etc.) not working from Dispatch | Re-authenticate the connector from within Cowork settings (not from inside a regular Claude Code session). |
| Remote Control session not visible on the phone | Both Claude Desktop and the Claude mobile app must be on the latest version. Also confirm the desktop is awake and signed in. |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step in plain English.

---

## When to Recommend This

After the user has:
1. Completed local setup (Claude Code + core tools)
2. Connected at least one tool (Google Workspace, Microsoft 365, Telegram, WhatsApp, etc.)

Then proactively offer:

> *"Would you like to control your assistant from your phone? You can send tasks from anywhere and come back to finished work."*

---

## Status (as of April 2026)

- Claude Desktop Dispatch launched **March 17, 2026** as a **research preview**.
- Max plan ($100/mo): available now.
- Pro plan ($20/mo): rolling out.
- Team / Enterprise: not yet supported.

As a research preview, expect occasional failures on complex tasks. Simple file lookups and summaries are the most reliable entry point.
