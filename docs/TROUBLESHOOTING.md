# Troubleshooting — Common Problems and Fixes

Something not working? Find your issue below. Each fix is written in plain English — no technical knowledge needed.

---

## Setup Problems

### "Claude Desktop won't sign me in" / sign-in loop

This is one of the most common first-launch snags at workshops.

1. Open a normal browser window and go to [claude.ai](https://claude.ai)
2. **Sign out** of your Claude account in the browser
3. Close Claude Desktop completely and reopen it
4. Sign in again — this time the browser hand-off works cleanly
5. If it still loops: quit Claude Desktop, delete the app's stored session (Mac: `~/Library/Application Support/Claude/`; Windows: `%APPDATA%\Claude\`), then reopen and sign in

---

### "git is not recognized" on first Windows launch

This is the other common first-launch snag. The bootstrap prompt needs `git` to download the workshop kit, and Windows doesn't ship with it.

**Step 1 — Install Git for Windows**

1. Install [Git for Windows](https://git-scm.com/download/win) with default settings — click **Next** on every screen
2. **Fully quit Claude Desktop** (not just minimise — actually close it) and reopen it. This step is non-negotiable. Claude Desktop's terminal inherits the Windows PATH at launch, so it can't see a freshly-installed Git until the app restarts.
3. Paste the bootstrap prompt again — your assistant retries `git --version` and continues from where it stopped.

**Step 2 — If it STILL says "not recognized" after restart**

The Git installer didn't add itself to the system PATH. There are two options:

**Option A (if you have admin access):** Ask your assistant: *"Git installed but Windows still can't find it. Please add it to my PATH."* Your assistant will run one PowerShell command and then tell you to **fully quit and reopen Claude Desktop again** for the change to take effect. If the PowerShell command says "access denied", go to Option B.

**Option B (always works, no admin needed):** Follow the manual walkthrough in [FULL-SETUP-PAGE.md → Windows Users Only → Fallback — If Git still isn't recognised after restarting Claude Desktop](FULL-SETUP-PAGE.md#fallback--if-git-still-isnt-recognised-after-restarting-claude-desktop). It takes about a minute. After finishing the walkthrough, fully quit and reopen Claude Desktop before retrying the bootstrap.

> **Why can't the assistant fix this itself in the same session?** If `git` isn't on the PATH when Claude Desktop started, Claude can't run `git clone` — the very first bootstrap command fails before the conversation can proceed. A PATH change only applies to Claude Desktop after a full restart. There is no in-session recovery.

---

### "Command Line Tools are required" popup on first Mac launch

macOS shows this the first time Claude tries to run `git` on a fresh machine. Do NOT click "Get Xcode" (that's the 10GB full IDE).

1. Click **Install** (the smaller option)
2. Wait 3–5 minutes for the install to finish
3. Your assistant pauses until the popup is gone, then continues automatically

If you dismissed the popup by accident, tell your assistant *"please retry"* — it triggers the same popup again.

---

### "The bootstrap prompt didn't work"

The bootstrap prompt copies the workshop kit to your computer. If something went wrong:

1. In Claude Desktop, start a new Code session
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

This means your workspace is pointing at the wrong folder. Fix it by:

1. In Claude Desktop, start a new Code session
2. At the top of the session there's a folder icon — click it
3. Navigate to your home folder, then pick `my-assistant`
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
4. Close Claude Desktop completely and reopen it
5. Run `node --version` again to confirm it updated

---

### "I don't know how to open the terminal in Claude Desktop"

1. In Claude Desktop, start a new **Code session** (not a regular chat)
2. The terminal is the panel at the bottom of the Code session
3. If you don't see it, use the **View** menu and turn on the terminal panel
4. It's the black/dark panel — you paste commands in there when your assistant asks you to

---

## Memory and Onboarding

### "Claude isn't remembering me between sessions"

Ask your assistant directly:

> "What do you know about me?"

If nothing is saved, say: *"Please run the onboarding questions again so you can learn about my business."*

You can also type `/memory` in a Code session to see exactly what Claude has stored — this is Claude's built-in memory view and covers everything it remembers across conversations.

---

### "I already did onboarding but Claude is asking me again"

This is normal if your Code session is pointing at a different folder. In Claude Desktop, start a new Code session, click the folder icon, and pick `~/my-assistant/`. That's where your assistant's instructions (`CLAUDE.md`) live. Memory itself is managed by Claude and follows you across sessions.

---

### "Claude seems to have forgotten what I told it"

Ask your assistant directly:

> "What do you know about me and my business?"

If something is missing or wrong, just tell it again — Claude's memory updates automatically. For a technical view of what's stored, type `/memory` in a Code session.

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
2. Make sure **Claude** (the Desktop app) has a tick next to it
3. If not, click the lock icon, enter your Mac password, and add the app

For the full guide: [docs/IMESSAGE-SETUP.md](IMESSAGE-SETUP.md)

---

## General Errors

### "Claude says I've hit my usage limit"

Claude Max has a usage cap that resets roughly every 5 hours. When you hit it, your assistant stops mid-task with a message like *"You've reached your usage limit. Try again at 3:42pm."* This is normal — it does not mean anything is broken, and your memory (everything Claude knows about you and your business) stays intact across the cooldown. If your assistant was halfway through a task when it stopped, ask it to summarise what it had finished and what was still in progress before you decide what to do next — partial work like a half-written file or a half-filled form may need picking up after the reset.

**What's happening**

Anthropic limits how much Claude any single account can use in a 5-hour window so that all paying subscribers get a fair share of capacity. Long, heavy conversations (lots of file reading, browser automation, big web searches) use up the cap faster than short chats. The cooldown applies to the Claude model you were using (usually Opus) on every device signed into your account — switching to a less-heavy model like Sonnet (see option 2 below) usually still works during the cooldown.

**A note on the weekly cap**

Since August 2025, Claude Max also has a **weekly cap** on top of the 5-hour one. Most workshop users never hit it, but heavy users — running long automations every day, or sharing an account across a team — sometimes do. If the message Claude shows you mentions a *weekly* limit rather than a 5-hour reset, the wait is longer (usually until the start of the next week). The same fixes below still apply.

**What to do — pick whichever fits**

1. **Wait it out.** The exact reset time is in the message Claude showed you — usually within a couple of hours. Good for non-urgent work. Your assistant will pick up exactly where it left off.
2. **Switch to Sonnet for the rest of the session.** In a Code session, type `/model` and pick **Sonnet 4.6**. Sonnet uses far less of your quota than Opus and is plenty capable for routine work (drafting emails, summarising notes, light research). Switch back to Opus the next morning.
3. **Upgrade your plan.** If you keep hitting the limit during normal work, Claude Max has higher tiers that raise the cap significantly. See [claude.ai/pricing](https://claude.ai/pricing) — or just ask your assistant *"what are my Claude Max plan options?"* and it will summarise them.

**To avoid hitting it again**

- Start a new conversation when you finish a task instead of letting one chat run all day. Longer chats use more of your cap per message.
- For heavy automation jobs (scraping a big website, processing a long document), ask: *"Use Sonnet for this task."* Save Opus for the work that genuinely needs it.
- If you are in a live workshop and your trainer is screen-sharing your account, the trainer's actions count against your quota too — let them know if you start hitting the cap.

---

### "I see a red error message and don't know what it means"

Copy the full red error text and tell your assistant:

> "I got this error. Please help me fix it step by step: [paste the error]"

Your assistant will walk you through diagnosing and fixing it in plain English, step by step. (If you have the Superpowers plugin installed, it uses `superpowers:systematic-debugging` for a more rigorous diagnosis.)

---

### "Something is broken and I don't know what"

Tell your assistant:

> "Something broke in my setup. Can you run a health check and tell me what's working and what isn't?"

Your assistant will check all the key parts of your setup and tell you exactly what needs fixing.

---

### "I forgot how to start my assistant"

Open **Claude Desktop** → start a new **Code session** → click the **folder icon** and pick `~/my-assistant/`. Your assistant loads automatically. Bookmark this guide or write it on a sticky note!

---

### "Everything was working and now it's not"

Try restarting from scratch:

1. Close Claude Desktop completely
2. Reopen Claude Desktop
3. Start a new Code session and click the folder icon → pick `~/my-assistant/`
4. Tell your assistant: *"I had a problem. Can you check that everything is working correctly?"*

Most issues are fixed by a fresh restart.

---

## Connector-Specific Known Issues

Some connectors have limitations that are not bugs — they are known constraints of the underlying tool. If a connector is behaving unexpectedly, check the known-issues folder before troubleshooting further:

| Issue | File |
|---|---|
| Google connects to the wrong account | [known-issues/GMAIL-ACCOUNT-SWITCH.md](../known-issues/GMAIL-ACCOUNT-SWITCH.md) |
| QuickBooks only shows test/demo data | [known-issues/QUICKBOOKS-SANDBOX-ONLY.md](../known-issues/QUICKBOOKS-SANDBOX-ONLY.md) |
| Stripe login does not open a browser | [known-issues/STRIPE-NON-TTY-LOGIN.md](../known-issues/STRIPE-NON-TTY-LOGIN.md) |
| Outlook does not work with @outlook.com / @hotmail.com accounts | [known-issues/OUTLOOK-PERSONAL-ACCOUNTS.md](../known-issues/OUTLOOK-PERSONAL-ACCOUNTS.md) |
| QuickBooks only shows test/demo data | [known-issues/QUICKBOOKS-SANDBOX-ONLY.md](../known-issues/QUICKBOOKS-SANDBOX-ONLY.md) |
| Stripe login does not open a browser | [known-issues/STRIPE-NON-TTY-LOGIN.md](../known-issues/STRIPE-NON-TTY-LOGIN.md) |
| Outlook does not work with @outlook.com / @hotmail.com accounts | [known-issues/OUTLOOK-PERSONAL-ACCOUNTS.md](../known-issues/OUTLOOK-PERSONAL-ACCOUNTS.md) |
| GitHub: read-only access key, Enterprise Server not supported, request limits | [known-issues/GITHUB-REMOTE-MCP-CAVEATS.md](../known-issues/GITHUB-REMOTE-MCP-CAVEATS.md) |
| Square: beta status, intermittent auth errors, sandbox token expiry | [known-issues/SQUARE-BETA-STATUS.md](../known-issues/SQUARE-BETA-STATUS.md) |
| Notion: requires plugin marketplace — cannot be set up from the terminal | [known-issues/NOTION-PLUGIN-ONLY.md](../known-issues/NOTION-PLUGIN-ONLY.md) |
| HubSpot: 403 errors after setup mean a permission needs to be added | [known-issues/HUBSPOT-MISSING-SCOPES.md](../known-issues/HUBSPOT-MISSING-SCOPES.md) |

---

## Still Stuck?

If none of the above fixes your problem:

1. Take a screenshot of the error
2. Note what you were trying to do when it broke
3. Contact Selr AI at [selrai.com.au](https://selrai.com.au)

Or ask your assistant directly — it is designed to help you troubleshoot even its own setup issues.

---

*Original content by vishwa603 (PR #23). Cleaned up and merged by Selr AI — selrai.com.au*
