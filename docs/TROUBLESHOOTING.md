# Troubleshooting — Common Problems and Fixes

Something not working? Find your issue below. Each fix is written in plain English — no technical knowledge needed.

---

## Setup Problems

### "I can't find Claude Code in VS Code"

1. Open VS Code
2. Click the **Extensions** icon on the left sidebar (it looks like four squares)
3. Search **"Claude Code"**
4. Click **Install**
5. Restart VS Code once it finishes

If it still doesn't appear, close VS Code completely and reopen it.

---

### "The bootstrap prompt didn't work"

The bootstrap prompt copies the workshop kit to your computer. If something went wrong:

1. Open VS Code and start Claude Code in the terminal
2. Type exactly: `What happened when I ran the setup? Can you check what's installed and what's missing?`
3. Your assistant will diagnose what's missing and offer to fix it

If you see a red error message, copy it and tell your assistant: *"Here is the error I got: [paste error]. Please help me fix this step by step."*

---

### "My skills folder is empty or missing"

Your skills live at `~/.claude/skills/`. To check if they're there, ask your assistant:

> "Can you check if my skills are installed? Look in the skills folder and tell me what you find."

If the skills are missing, tell your assistant:

> "My skills didn't install. Help me reinstall them from the workshop kit."

---

### "Claude says it can't find my CLAUDE.md"

This means Claude Code is not looking in the right folder. Fix it by:

1. In VS Code, go to **File → Open Folder**
2. Navigate to your home folder, then open `my-assistant`
3. Once that folder is open, start Claude Code in the terminal
4. Claude will automatically pick up the CLAUDE.md file

---

### "Node.js is too old" or "Unsupported Node.js version"

Claude Code requires **Node.js version 18 or higher**. To check yours:
```bash
node --version
```

If you see `v16.x.x` or lower, update Node.js:

1. Go to [nodejs.org](https://nodejs.org)
2. Download the **LTS** version (the big green button)
3. Run the installer — it will replace your old version
4. Close VS Code completely and reopen it
5. Run `node --version` again to confirm it updated

---

### "I don't know how to open the terminal in VS Code"

- **Mac:** Press `` Ctrl + ` `` (the backtick key, top-left of keyboard)
- **Windows:** Press `` Ctrl + ` `` or go to **View → Terminal**

The terminal is the black/dark panel that opens at the bottom of VS Code.

---

## Memory and Onboarding

### "Claude isn't remembering me between sessions"

Tell your assistant:

> "Please check your memory notes and tell me what you know about me."

If nothing is saved, say: *"Please run the onboarding questions again so you can learn about my business."*

---

### "I already did onboarding but Claude is asking me again"

This is normal if you start Claude Code from a different folder. Always open the `~/my-assistant/` folder in VS Code before starting Claude. That's where your memory and instructions live.

---

### "Claude seems to have forgotten what I told it"

Ask your assistant to check its own memory:

> "Read my user profile and tell me what you know about me and my business."

If something is missing, just tell it again — it will update its memory file right away.

---

## Google Workspace (Gmail, Calendar, Drive)

### "Google Workspace isn't connecting"

Try these steps:

1. Ask your assistant: *"Google Workspace isn't working. Walk me through reconnecting it."*
2. If the issue is the wrong Google account being used, see the section below.

The most common issue is being logged into multiple Google accounts. The fix is to log out of Google Workspace and log back in, being careful to pick the right account.

---

### "I got logged into the wrong Google account"

Short fix:
1. In the terminal, type: `gws auth logout`
2. Then type: `gws auth login`
3. When the browser opens, make sure you click on the correct Google account

---

## Microsoft 365 / Outlook

### "Outlook isn't connecting"

Microsoft 365 only works with **work or school accounts** — it does not work with personal `@outlook.com` or `@hotmail.com` accounts.

If you have a work Microsoft 365 account:
1. Ask your assistant: *"Walk me through connecting my Microsoft 365 account step by step."*

---

## Phone Messaging (Telegram / WhatsApp / iMessage)

### "Telegram isn't responding to my messages"

1. Make sure you started Claude Code with the Telegram channel enabled
2. The correct start command is: `claude --channels plugin:telegram@claude-plugins-official`
3. If you're unsure, ask your assistant: *"How do I start Claude with Telegram enabled?"*

For the full setup: [docs/TELEGRAM-SETUP.md](TELEGRAM-SETUP.md)

---

### "WhatsApp QR code isn't scanning"

1. Open WhatsApp on your phone
2. Go to **Settings → Linked Devices → Link a Device**
3. Point your phone camera at the QR code on your computer screen
4. Make sure you're scanning from within the "Link a Device" screen — not from the camera app

If the QR code disappears before you can scan it, ask your assistant to regenerate it.

---

### "'WA_AUTO_OPEN_QR=1' is not recognised" (Windows)

You pasted the Mac launch command into PowerShell or Command Prompt. Mac/Linux shells allow inline env vars (`NAME=value program`); Windows shells do not. Use the shell-specific block from [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) Part B Step 1:

- **PowerShell:** set `$env:WA_AUTO_OPEN_QR = "1"` on its own line before running `claude …`
- **Command Prompt:** use `set WA_AUTO_OPEN_QR=1` on its own line before running `claude …`

---

### "WhatsApp messages aren't arriving"

1. Make sure Claude Code is running with `--dangerously-load-development-channels server:whatsapp`
2. Only your own phone number is allowed by default — if someone else is messaging, their number needs to be added to `WA_ALLOW_FROM`
3. Run with `WA_VERBOSE=1` to see if messages are being blocked in the debug log

---

### "WhatsApp session expired"

WhatsApp Web sessions can expire if your phone is offline for too long.

1. Delete the auth folder:
   - **Mac / Linux:** `rm -rf ~/.claude/whatsapp-channel/auth`
   - **Windows (PowerShell):** `Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\whatsapp-channel\auth"`
   - **Windows (Command Prompt):** `rmdir /S /Q "%USERPROFILE%\.claude\whatsapp-channel\auth"`
2. Restart Claude Code with the channel flag (see [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) Part B Step 1 for the shell-specific launch command)
3. Scan a new QR code

---

### "WhatsApp shows 'blocked by org policy'"

Your Team or Enterprise admin needs to enable channels in the Claude Code settings. Contact your admin.

For the full WhatsApp guide: [docs/WHATSAPP-SETUP.md](WHATSAPP-SETUP.md)

---

### "iMessage isn't working (Mac only)"

The most common issue is missing permissions. Check:

1. Go to **System Settings → Privacy & Security → Full Disk Access**
2. Make sure **Terminal** (or **VS Code**) has a tick next to it
3. If not, click the lock icon, enter your Mac password, and add the app

For the full guide: [docs/IMESSAGE-SETUP.md](IMESSAGE-SETUP.md)

---

## General Errors

### "I see a red error message and don't know what it means"

Copy the full red error text and tell your assistant:

> "I got this error. Please help me fix it step by step: [paste the error]"

Your assistant's `systematic-debugging` skill will walk you through diagnosing and fixing it in plain English.

---

### "Something is broken and I don't know what"

Tell your assistant:

> "Something broke in my setup. Can you run a health check and tell me what's working and what isn't?"

Your assistant will check all the key parts of your setup and tell you exactly what needs fixing.

---

### "I forgot the command to start my assistant"

```bash
cd ~/my-assistant && claude
```

That's the only command you need. Bookmark this guide or write it on a sticky note!

---

### "Everything was working and now it's not"

Try restarting from scratch:

1. Close VS Code completely
2. Reopen VS Code
3. Open the `~/my-assistant/` folder
4. Start Claude Code in the terminal
5. Tell your assistant: *"I had a problem. Can you check that everything is working correctly?"*

Most issues are fixed by a fresh restart.

---

## Connector-Specific Known Issues

Some connectors have limitations that are not bugs — they are known constraints of the underlying tool. If a connector is behaving unexpectedly, check the known-issues folder before troubleshooting further:

| Issue | File |
|---|---|
| QuickBooks only shows test/demo data | `known-issues/QUICKBOOKS-SANDBOX-ONLY.md` |
| Stripe login does not open a browser | `known-issues/STRIPE-NON-TTY-LOGIN.md` |
| Outlook does not work with @outlook.com / @hotmail.com accounts | `known-issues/OUTLOOK-PERSONAL-ACCOUNTS.md` |

---

## Still Stuck?

If none of the above fixes your problem:

1. Take a screenshot of the error
2. Note what you were trying to do when it broke
3. Contact Selr AI at [selrai.com.au](https://selrai.com.au)

Or ask your assistant directly — it is designed to help you troubleshoot even its own setup issues.

---

*Original content by vishwa603 (PR #23). Cleaned up and merged by Selr AI — selrai.com.au*
