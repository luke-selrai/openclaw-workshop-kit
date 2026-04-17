---
name: google-workspace-connector
description: "Install and operate the Google Workspace connector so the user's assistant can use Gmail, Calendar, Drive, Docs, Sheets, Tasks, Chat, and Meet. Handles the full install and OAuth flow conversationally. Use this skill when the user says 'connect my Google account', 'set up Gmail', 'set up Google Workspace', or asks the assistant to send an email, check a calendar, search Drive, create a Google Doc, or run anything else Google-Workspace-adjacent on their behalf."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - google-workspace
    - gmail
    - calendar
    - drive
    - docs
    - sheets
    - installer
    - oauth
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Node.js / PATH / shell-detection patterns used during install
    - skill: email-composer
      reason: Compose the email content with email-composer, then send it via this connector
    - skill: google-chat-connector
      reason: Google Chat lives in the same Workspace OAuth scope; connect Google Workspace first
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting OAuth scope, unverified-app, or token failures
---

# Google Workspace Connector

## Overview

This skill does two things:

1. **Installs** the Google Workspace connector on the user's computer (one-time setup) and runs them through sign-in.
2. **Operates** the connector — sending emails, checking calendars, searching Drive, creating Docs and Sheets, managing Tasks, sending Google Chat messages, and so on.

The connector uses the `@googleworkspace/cli` tool (command name: `gws`) and authenticates via Google's OAuth flow. It works on Windows, Mac, and Linux.

**Which part to run** — if the user has never installed `gws` before, run Part 1 (Install). If `gws` is already installed and they're signed in, jump to Part 2 (Operate). You can check by silently running `gws --version` and `gws auth list` (if the latter exists) before deciding.

---

## Communication rules for Part 1

The user is a non-technical business owner. Every message during Part 1 follows the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** Never say Node.js, npm, CLI, OAuth, scopes, PATH, terminal, shell, env var. If you must name a technical thing, describe it plainly: "the Google Workspace tool", "your browser", "the command window".
- **Tell them what is about to happen.** Before any action: "I'm going to install the Google Workspace tool for you — this takes about a minute."
- **React warmly.** Good: "Your Google account is connected — I can see your Gmail now." Bad: "OAuth flow completed, scopes `drive,gmail,sheets,calendar` granted."
- **Never show raw error messages.** Translate into plain English.
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.

---

## PART 1 — Install & Sign In

This part installs the `gws` tool, runs the one-time Google Cloud project setup, and completes OAuth sign-in.

### Step 1 — Detect the user's OS

Silently run:

```bash
uname -s           # darwin = Mac, linux = Linux
```

On Windows the above will fail — detect Windows separately (e.g., check `OS=Windows_NT` in env, or presence of `where.exe`).

Remember the OS — you'll adjust permissions messaging in Step 2.

### Step 2 — Check that Node.js is installed

Tell the user: *"I'm checking if Node.js is already on your computer. Takes a few seconds."*

Silently run:

```bash
node --version
```

- If a version prints → "Node.js is ready." Go to Step 3.
- If not found → install it. Follow `skills/first-run-setup/SKILL.md` Step 3 ("Install Node.js") for the platform-appropriate install path (nvm on Mac/Linux, winget on Windows). Do NOT send the user to a website.

### Step 3 — Install the Google Workspace tool

Tell the user: *"I'm installing the Google Workspace tool now. About 30 seconds."*

Silently run:

```bash
npm install -g @googleworkspace/cli
```

Verify:

```bash
gws --version
```

- Version prints → "That's ready." Go to Step 4.
- `gws: command not found` → PATH issue. Apply `skills/first-run-setup/SKILL.md` PATH fix, then re-verify.
- Permissions error on Windows → tell the user plainly: *"The install needs administrator rights. Please close the window, right-click it and choose 'Run as administrator', then say 'ready'."* Wait, then retry.

### Step 4 — One-time Google Cloud project setup

If the user has never set up `gws` on this computer before, they need a Google Cloud project to act as the OAuth client. The tool does this for them.

Tell the user: *"Before signing you in, I need to set up a small Google Cloud project in your Google account — it's the thing that actually talks to Gmail, Calendar, and Drive. The tool does this automatically. Takes about a minute."*

Silently run:

```bash
gws auth setup
```

Follow the prompts on the user's behalf:

- When it asks for a project ID, use something short and user-specific, like `gws-<firstname>-assistant`. If you don't know their first name, use `gws-my-assistant`.
- If it asks for confirmation, confirm.
- Expected output: `Setup complete`.

**If the user has already done this before on this computer** — skip this step. Silently checking whether `gws auth setup` has run before is tricky; if you're not sure, just run it — the tool handles the "already set up" case gracefully.

### Step 5 — Sign the user in

Tell the user: *"Now I'm going to open your browser so you can sign into the Google account you want me to use. Pick the right one — if you use one for personal and one for business, the one you pick here is the one I'll work with."*

Silently run:

```bash
gws auth login
```

This opens the user's default browser to Google's OAuth page. Walk them through it in plain English before they click:

1. *"Your browser just opened Google's sign-in page. Pick the account you want me to use."*
2. *"You might see a warning that says 'Google hasn't verified this app' — that's normal. Click 'Continue' or 'Advanced' and then 'Go to \[your project name\] (unsafe)'. It's your own project, it's safe."*
3. *"Then click 'Allow' to give me permission to read and write on your behalf."*
4. *"You'll see a success message in the browser — that's it."*

Wait for the CLI to return to the prompt with a success message.

**If the browser doesn't open automatically** — look for a URL in the terminal output starting with `https://accounts.google.com/...`. Copy it and tell the user: *"Open this link in your browser manually and follow the same steps."*

**If the user hits 'Access blocked'** — two fixes, both covered in `gws` docs:
1. Limit scopes: retry with `gws auth login -s drive,gmail,sheets,calendar` (unverified apps are capped at around 25 scopes total).
2. Add the user's email as a test user: tell them to go to the GCP Console → APIs & Services → OAuth consent screen → Test users → Add, paste their email, save, then retry.

### Step 6 — Confirm it works

Tell the user: *"Let me check it's working — I'll glance at your inbox. Won't send anything."*

Silently run a read-only command, e.g.:

```bash
gws gmail list --max-results 1
```

- Returns a message → *"Looks good — your Google account is connected. You can ask me to send emails, check your calendar, find files in Drive, or anything else Google-related now."*
- Returns a scope error → rerun `gws auth login -s drive,gmail,sheets,calendar,docs,tasks,chat` and walk the user through sign-in again. Explain plainly: *"I need a little more permission — let me re-do the sign-in with the right set of tick-boxes."*

### Step 7 — Optional: install Google Workspace skills

The `gws` tool can generate dozens of specialist skills for the user's Claude Code install (Gmail triage, calendar management, Drive uploads, standup reports, meeting prep, and so on). This is **optional** — the connector works without them.

Ask the user: *"Want me to install the deeper Google Workspace skills? Things like daily standup reports from your calendar, inbox triage, or weekly digest. Totally optional — you can skip this and I'll still handle everything."*

If yes, silently run:

```bash
gws generate-skills
```

Tell the user: *"Done. You've got extra Gmail and Calendar shortcuts now — they kick in automatically when you ask for them."*

Part 1 is complete.

---

## PART 2 — Operate the Connector

Once installed and signed in, invoke `gws` subcommands on the user's behalf whenever they ask for anything Google-Workspace-adjacent. Never paste the command at them; run it and summarise the result in plain English.

### Common commands

Use `gws --help` or `gws <subcommand> --help` to discover options if you're unsure. Core subcommands (as of April 2026):

| User asks for | Subcommand shape |
|---|---|
| "Send an email" | `gws gmail send --to "..." --subject "..." --body "..."` |
| "Check my inbox" | `gws gmail list --max-results 20` |
| "What's on my calendar today / this week" | `gws calendar list --today` or `gws calendar list --this-week` |
| "Schedule a meeting" | `gws calendar create --title "..." --start "..." --end "..." --attendees "..."` |
| "Find a file in Drive" | `gws drive search "query"` |
| "Create a Google Doc" | `gws docs create --title "..."` |
| "Add a row to [sheet]" | `gws sheets append --sheet-id "..." --range "..." --values "..."` |
| "Show my Google Tasks" | `gws tasks list` |
| "Send a message in Google Chat" | use the `google-chat-connector` skill (it pairs with Google Workspace auth) |

### Multi-step workflows

When the user asks for something that spans multiple subcommands (e.g., "find John's email then check his calendar availability then draft a meeting invite"), chain the calls silently and summarise only the outcome. Do not narrate the individual commands.

### Safety rules

- **Confirm before sending emails.** For any outbound email, draft the content, show the user the subject + recipient + first two lines of the body in plain text, and ask *"Send this?"* Wait for explicit yes before calling `gws gmail send`.
- **Confirm before creating calendar events that affect other people.** For events with attendees, show the user the title, time, and attendees before calling `gws calendar create`. Events with no attendees (personal blocks) can skip confirmation.
- **Never delete without confirmation.** Anything that would remove data (emails, files, events, rows) must be confirmed with the user first.
- **Read-only first.** If the user says something ambiguous like "show me" or "check", default to read-only subcommands.

---

## Troubleshooting

| Symptom | Likely cause | What you do |
|---|---|---|
| `gws: command not found` after install | PATH not refreshed | Close and reopen terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| `permission denied` during `npm install` on Windows | Needs admin | Tell the user to close the terminal, right-click, "Run as administrator", retry |
| `Access blocked` during OAuth | Unverified-app scope cap or missing test user | Retry with limited scopes: `gws auth login -s drive,gmail,sheets,calendar`. If that still fails, tell the user to add themselves as a test user in GCP Console → OAuth consent screen |
| Wrong Google account signed in | User picked the wrong one on the OAuth screen | Run `gws auth logout`, then `gws auth login` again; tell the user to double-check which account they pick |
| Browser didn't open during sign-in | No default browser / CLI running in a headless context | Copy the URL from the terminal, tell the user to open it in their browser manually |
| "Google hasn't verified this app" warning | Normal for personal OAuth projects | Tell the user it's safe — their own project, not a third party |
| `gws` works in terminal but Claude Code says "not found" | Claude Desktop's terminal inherits env at launch | Tell the user to fully quit Claude Desktop and reopen it |
| Subcommand returns scope error | OAuth flow missed a scope | Rerun sign-in with the full scope list: `gws auth login -s drive,gmail,sheets,calendar,docs,tasks,chat` |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step — isolate what changed, form a hypothesis, verify before fixing — and summarise the outcome in plain English.

---

## Reference — what lives where

- `gws` CLI source: npm package `@googleworkspace/cli`
- OAuth client config: user's own Google Cloud project (created by `gws auth setup`)
- Access tokens: stored by `gws` in the user's home folder (exact path is OS-specific; the tool handles it)
- Optional deeper skills: generated into `~/.claude/skills/` by `gws generate-skills`
