---
name: telegram-connector
description: "Connect the user's Telegram to Claude Code so they can message their assistant from their phone. Drives the entire install + BotFather + pairing flow autonomously through Telegram Web in a Playwright MCP browser; the only human moment is the user scanning a QR code with their phone. Use this skill when the user says 'set up Telegram', 'connect my Telegram', 'install the Telegram plugin', 'install the Telegram channel', 'message Claude from my phone via Telegram', asks about BotFather, pairing codes, or the Telegram allowlist, AND when they return after relaunching Claude Code with --channels and say 'continue Telegram setup', 'I'm back', 'what's next', or anything similar that implies they're mid-flow."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Channels & Messaging
  tags:
    - telegram
    - channel
    - messaging
    - botfather
    - plugin
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Bun / PATH / shell-detection patterns used during install
    - skill: whatsapp-connector
      reason: Same messaging-channel install pattern. Reference if the user also wants WhatsApp
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives Telegram Web and BotFather
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting plugin install, pairing, or message-delivery failures
---

# Telegram Connector

## Overview

This skill connects a user's Telegram to Claude Code so they can message their assistant from anywhere. Once paired, the user texts their bot from their phone and the assistant replies as if it were a chat thread.

The setup runs in two Claude Code sessions:

1. **Setup session** — installs the plugin, drives @BotFather inside a Playwright MCP browser, captures the bot token, saves it.
2. **Channel session** — launched with `claude --channels plugin:telegram@claude-plugins-official`. This is the session that actually listens to Telegram. The user pairs their personal Telegram account here, then sends a test message to confirm the round-trip works.

The skill carries state across the restart via `~/.claude/channels/telegram/.handoff-state.json`, so the channel session greets the user proactively instead of forcing them to re-explain where they are.

**Which phase to run.** Phase 1 is for first-time setup or recovery from an interrupted setup. Phase 2 is day-to-day operation — adding/removing people from the allowlist, rotating tokens, troubleshooting.

---

## Golden rule — do not open the user's own browser

Every step that needs a browser runs inside the **Playwright MCP** browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the user to open Telegram Web themselves, never launch `https://web.telegram.org` in their default browser. The only human-in-the-loop moment is the QR scan from their phone — Claude shows the QR code on screen via the Playwright window, the user scans it with their phone Telegram app to authenticate Telegram Web, and Claude takes it from there.

If for any reason the Playwright MCP browser cannot be used (extension not installed, non-recoverable launch failure), fall back to **Phone Fallback** at the end of this file. Do not open the user's own browser as an intermediate step.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise with `curl https://api.telegram.org/...`, do not edit the plugin's `server.ts`, do not invent new slash commands. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say Bun, npm, bash, zsh, PowerShell, CLI, MCP, env var, terminal, plugin registry, config file, contenteditable, selector. If you must refer to a technical thing, name it plainly: "a small helper tool", "the Telegram pieces", "the launch command", "your phone", "the browser window I'm using".
- **Tell them what is about to happen.** Before any action: "I'm going to open Telegram in a browser window now. This takes a few seconds."
- **React warmly.** Good: "That worked. Telegram is linked." Bad: "Plugin install succeeded, 6-char pair code issued."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem, let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.
- **Security: never repeat the bot token back to the user.** When @BotFather gives you the token in the Playwright window, save it via `/telegram:configure` and forget it. Do not log it, echo it back, or write it to any file you read later.

---

## PHASE 1 — Install & Pair

### Step 0 — Resume check (run this first, every time)

Before greeting the user or starting anything new, check whether this is a resumed session.

Read `~/.claude/channels/telegram/.handoff-state.json` if it exists. The file shape is:

```json
{
  "phase": "awaiting_pair",
  "botUsername": "harvey_assistant_bot",
  "savedAt": 1714187600
}
```

**Branches:**

- **File present, `phase` is `awaiting_pair`, `savedAt` is within the last hour** → this is the channel session post-relaunch. The plugin is installed, the token is saved. Skip Steps 1 through 8. Greet the user proactively:

  *"Welcome back. Telegram is set up with your bot @\<botUsername\>. To finish, open Telegram on your phone, search for your bot, tap Start, and send any message like 'hi'. The bot will reply with a 6-character code. Send me that code here."*

  Then jump to **Step 9 — Pair**.

- **File present but `savedAt` is older than 1 hour** → previous setup was interrupted. Ask: *"It looks like there's a half-finished Telegram setup from earlier. Want me to pick up from where you left off, or start completely fresh?"* If continue, jump to Step 9. If fresh, delete the file and start at Step 1.

- **File absent** → fresh setup. Continue to Step 1.

### Step 1 — Prerequisite check

Before any technical step, confirm the user has what they need. Send:

*"Before we begin, two quick checks. Do you have your phone with you with the Telegram app installed and a Telegram account already set up? If you've never used Telegram, you'll need to install it and create an account first."*

Wait for "yes" before moving on. If they say no, pause the setup. Tell them to install Telegram on their phone, create an account, then come back. Do not try to work around this. Pairing requires their phone Telegram account.

### Step 2 — Detect OS and shell

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Ask them: *"Quick question. On your computer, when you open a black or blue text window to type commands, does the prompt start with `PS` or just `C:\...>`? Or are you not sure?"* Map their answer the same way `whatsapp-connector` does.

### Step 3 — Check that Bun is installed

Tell the user: *"I'm going to check if a small helper tool is already on your computer. This takes a few seconds."*

Silently run `bun --version`.

- If it prints a version → "That's ready" and go to Step 4.
- If the command is not found → install Bun silently:
  - **Mac / Linux:** `curl -fsSL https://bun.sh/install | bash`
  - **Windows (PowerShell):** `powershell -c "irm bun.sh/install.ps1 | iex"`

After install, tell the user: *"Almost done with the helper tool. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them, then re-verify.

If it still fails, apply the PATH fix guidance in `skills/first-run-setup/SKILL.md` ("Windows Snags Reference" section).

### Step 4 — Open Telegram Web in the Playwright MCP browser

Tell the user: *"I'm going to open Telegram in a browser window now. You'll see a QR code in a moment. Get your phone ready."*

**Pre-flight cleanup.** A previous Playwright Chrome instance with the same user-data-dir can hold a singleton lock and block the next launch. Try the navigation first; if it errors with `SingletonLock`, `process is already running`, or similar, run the cleanup branch then retry once:

- **Mac:**
  ```bash
  pkill -9 -f "Google Chrome.*Playwright" 2>/dev/null
  rm -f "$HOME/Library/Application Support/Google/Chrome/SingletonLock"
  ```
- **Linux:**
  ```bash
  pkill -9 -f "chrome.*Playwright" 2>/dev/null
  rm -f "$HOME/.config/google-chrome/SingletonLock"
  ```
- **Windows (PowerShell):**
  ```powershell
  Get-Process | Where-Object { $_.ProcessName -like "chrome*" } | Stop-Process -Force
  ```

Do not run cleanup pre-emptively — only after a launch failure, and only once.

**Navigate.** Use `mcp__plugin_playwright_playwright__browser_navigate` to `https://web.telegram.org/k/`.

**Wait for the QR code.** Use `mcp__plugin_playwright_playwright__browser_snapshot` to confirm the page rendered. The QR code is the dominant element on the login screen.

Tell the user: *"A Telegram login screen has opened with a QR code. On your phone, open Telegram, tap the menu (three lines, top left), tap Settings, tap Devices, then tap 'Link Desktop Device'. Point your phone camera at the QR code on screen. Tell me when you've done that."*

**Wait for login.** After the user confirms, take a fresh snapshot. The chat list should be visible (a left-hand pane with chat thread tiles). If still on the QR screen after 30 seconds, ask the user if they hit any issues and re-take the snapshot.

If login fails repeatedly (more than two retries), fall back to **Phone Fallback**.

### Step 5 — Drive @BotFather autonomously

Once Telegram Web is logged in, Claude does the entire BotFather conversation in the Playwright window. The user does not touch their phone for this step.

**Find @BotFather.** Use `browser_snapshot` to locate the search input in the chat list pane. Click it, then type `BotFather`. From the search results, click the entry with the official blue checkmark — its handle reads `@BotFather`. Be deliberate: there are scammer copycats; the genuine one has the verified-account checkmark.

**Open the chat.** When the BotFather profile pane shows, click **Start** at the bottom — **not** Open. The "Open" button is for an unrelated mini-app and will not trigger the bot conversation. Confirm the chat opened by snapshot — you should see the BotFather chat with a welcome message.

**Send `/newbot`.** The Telegram Web message input is a contenteditable element, not a standard `<input>`. `browser_type` may not target it correctly. Use `browser_evaluate` to programmatically insert text and submit:

```javascript
() => {
  const input = document.querySelector('.input-message-input');
  input.focus();
  document.execCommand('insertText', false, '/newbot');
  // Submit by dispatching Enter
  const event = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true });
  input.dispatchEvent(event);
}
```

If the contenteditable selector has changed, take a fresh snapshot and locate the input by its placeholder ("Message…") or aria role.

**Send the bot name.** Take a snapshot to confirm BotFather replied with "Alright, a new bot. How are we going to call it?". If the user has told you a name preference earlier in the conversation, use that. Otherwise, use a sensible default like "My Assistant" — this is just the display name and can be anything. Send via the same `browser_evaluate` pattern.

**Send the bot username.** BotFather replies asking for a unique username ending in `bot`. Propose one based on the user's first name if known: `<firstname>_assistant_bot`. If the user's name is not known, ask them now: *"BotFather needs a unique handle for your bot. Something short ending in 'bot', for example `harvey_assistant_bot`. What would you like?"*

After sending the username, snapshot. BotFather either:
- Replies with the bot token (success) — extract it
- Replies "Sorry, this username is already taken" — try a variant (`<firstname>_assistant_bot2`, `<firstname>_ai_bot`, etc.) up to 3 times before asking the user

**Capture the token.** The token appears in BotFather's reply, formatted like `123456789:AAH...`. Extract via `browser_evaluate`:

```javascript
() => {
  const messages = document.querySelectorAll('.message');
  const last = messages[messages.length - 1];
  const text = last.innerText;
  const match = text.match(/\b\d{8,}:[A-Za-z0-9_-]{30,}\b/);
  return match ? match[0] : null;
}
```

Hold the token in mind for Step 7. Do not echo it. Do not write it to any file other than via `/telegram:configure` in Step 7.

### Step 6 — Install the Telegram plugin

Tell the user: *"I'm installing the Telegram pieces. About 30 seconds."*

The install runs **inside this Claude Code session** so the new pieces become available without restarting. Run, in order:

```
/plugin install telegram@claude-plugins-official
/reload-plugins
```

After the reload, verify install succeeded by running `/plugin` (no args) and confirming `telegram@claude-plugins-official` shows as enabled. Do not parse the install command's chat output — `/plugin` is the stable success check.

- Success → "That's done." Go to Step 7.
- Permissions error (`EACCES`, `EPERM`) → translate: "Your computer needs a small permission fix, give me a moment to sort it." Apply guidance from `skills/first-run-setup/SKILL.md`, then retry.
- Network error → "Your network is blocking the install. This happens on company laptops. Could you try from a home connection?"

### Step 7 — Save the bot token + write handoff state

In the Claude Code chat, run:

```
/telegram:configure <token>
```

Replacing `<token>` with the bot token from Step 5. This saves the token into Claude Code's plugin state. Do NOT print the token in your reply to the user.

Immediately after the configure call succeeds, write the handoff state file so the channel session can pick up where this one leaves off:

```bash
mkdir -p ~/.claude/channels/telegram
cat > ~/.claude/channels/telegram/.handoff-state.json <<EOF
{
  "phase": "awaiting_pair",
  "botUsername": "<botUsername>",
  "savedAt": $(date +%s)
}
EOF
```

Replace `<botUsername>` with the username chosen in Step 5 (without the `@`).

Then say to the user: *"Token saved. Next, we'll re-launch Claude Code together so Telegram turns on."*

### Step 8 — Hand off to the channel session

Tell the user, in two short messages:

1. *"Telegram is ready to link. To finish, you'll close this Claude Code session and open a fresh one with Telegram turned on. I'll give you the exact command in a moment. Ready?"*
2. When they confirm, paste:

   ```
   claude --channels plugin:telegram@claude-plugins-official
   ```

   Say: *"Close this Claude Code session, open a fresh terminal window, paste the command above, and press Enter. When the new session opens, just say 'I'm back' and I'll pick up from there."*

The phrase 'I'm back' (or anything similar) lets this skill auto-load in the channel session via the description match. The Step 0 resume check then takes over.

### Step 9 — Pair the user's personal Telegram (channel session)

This step runs in the channel session — the one started with `--channels`. Step 0 has already greeted the user proactively. The user is now opening Telegram on their phone.

Walk them through:

1. *"Open Telegram on your phone. Search for your bot by its username (the one we picked, @\<botUsername\>). Tap Start and send any message, something like 'hi'. The bot will reply with a 6-character code. Send me that code."*
2. When they paste the code, run in Claude Code:
   ```
   /telegram:access pair <code>
   ```
3. Wait for the confirmation, then move to Step 10.

### Step 10 — Lock down access

Tell the user: *"One more thing. By default anyone who messages your bot gets a pairing code. I'll switch that off so only you can use it."*

Run:

```
/telegram:access policy allowlist
```

Confirm: *"Done. Strangers can't trigger pairing on your bot now."*

### Step 11 — Round-trip verification

The channel is paired and locked. Now confirm it actually works end-to-end before declaring success.

Tell the user: *"Last check. Send any quick message to your bot from your phone, like 'test'. I should see it come through here."*

Wait for the inbound message. The Telegram channel server delivers it to this Claude Code session as a normal user message. When it arrives:

- If you see the message → reply through the channel: *"Got it. Telegram is fully working. Anything you send your bot from now on will land here, and I'll reply on your phone."* Then delete the handoff state file:
  ```bash
  rm -f ~/.claude/channels/telegram/.handoff-state.json
  ```
  Phase 1 is complete. Move to Step 12.
- If nothing arrives within 60 seconds → ask: *"Did you send the message? If yes, let me check the connection."* Snapshot via `claude plugin list` and confirm the channel is enabled. Walk through the Troubleshooting table below before retrying.

### Step 12 — Offer a launch shortcut (recommended)

The user just typed `claude --channels plugin:telegram@claude-plugins-official`. That is brutal to type every time. Offer a shortcut.

Ask: *"Want me to set up a shortcut so you can just type `claude-tg` next time, instead of the long command?"*

If yes, ask one more question: *"When you're driving Claude from your phone over Telegram, you can't tap an 'allow' button on your laptop, so permission prompts will stall things. I can skip those prompts when running via Telegram so commands go through unprompted. Your Telegram allowlist still controls who can talk to your bot. Skip prompts? (Recommended for solo use.)"*

**Build the shortcut as an executable script, not a shell alias.** Aliases in `~/.zshrc` don't load in non-interactive shells, VS Code's integrated terminal, or already-open windows — that's fragile. A script in a directory that's already on PATH is reliable.

Pick a target directory in this priority order:

1. `~/.local/bin/` if it exists and is on PATH (`echo $PATH | grep -q "$HOME/.local/bin"`)
2. The directory containing the existing `claude` binary if it's user-owned (`dirname "$(which claude)"`)
3. `~/.local/bin/` — create it and add to PATH if neither of the above worked

Write the script (replace `<flags>` with ` --dangerously-skip-permissions` if user said yes, empty otherwise):

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-tg <<'EOF'
#!/bin/sh
exec claude --channels plugin:telegram@claude-plugins-official<flags> "$@"
EOF
chmod +x ~/.local/bin/claude-tg
```

If `~/.local/bin/` was not already on PATH, append to the user's shell rc:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```

(Substitute `~/.bashrc` for bash users; on Windows, write a `claude-tg.cmd` shim into a directory on PATH instead.)

**Verify** by running `which claude-tg`. If it resolves, tell the user: *"Done. Next time you want to chat with me on Telegram, just open a terminal and type `claude-tg`."* If you added the PATH line to `.zshrc`, also say: *"You'll need to open a fresh terminal window for the shortcut to work. The current one won't see it yet."*

If the script approach fails for any reason, fall back to a `.zshrc` alias and warn the user it may not work in every terminal:

```bash
echo "alias claude-tg='claude --channels plugin:telegram@claude-plugins-official<flags>'" >> ~/.zshrc
```

Phase 1 is now genuinely complete.

---

## PHASE 2 — Use the Channel

Once paired, the user messages their bot from Telegram and Claude responds directly in the chat. No tools to invoke from your side — the plugin handles inbound/outbound routing automatically. Your job in Phase 2 is to manage access, run the shortcut, and troubleshoot.

### Common requests

**"Add another person to my allowlist."** → easiest path is to have the new person DM the bot. The bot replies with a 6-character pairing code (briefly flip policy to `pairing` first if you locked it down: `/telegram:access policy pairing`). The user pastes the code and you run:

```
/telegram:access pair <code>
```

Then flip back: `/telegram:access policy allowlist`.

If you already have the person's numeric Telegram user ID (e.g. they got it from @userinfobot), you can skip pairing and add them directly:

```
/telegram:access allow <senderId>
```

To see who is currently allowed and any pending pairing codes, run `/telegram:access` with no arguments.

**"Remove someone's access."** → run:

```
/telegram:access remove <senderId>
```

**"Pair a second device."** → ask the user to message the bot from the new device/account, grab the pairing code from the bot's reply, then run `/telegram:access pair <new-code>`. (Same flip-to-pairing-then-back trick as adding a person if currently locked down.)

**"Rotate my bot token."** → ask the user to talk to BotFather again, send `/revoke`, generate a new token, and paste it to you. Run `/telegram:configure <new-token>`, then tell them they need to restart Claude Code with the `--channels` flag (or just run `claude-tg`) for the new token to take effect.

**"My shortcut stopped working / I'm in a new terminal and `claude-tg` isn't found."** → the most common cause is a freshly-opened terminal that hasn't sourced the updated PATH. Tell them: *"Open a brand-new terminal window (not the current one) and try again. If it still doesn't work, tell me and I'll check the shortcut."* If still broken, verify with `which claude-tg` and `ls -la ~/.local/bin/claude-tg`.

---

## Troubleshooting

| Symptom | Likely cause | What you do |
|---|---|---|
| Bot doesn't respond when user messages it | Channel session not running (no `claude --channels` open) | Tell the user to open a terminal and run `claude-tg` (or the long form if no shortcut yet) |
| `Bun not found` after install | PATH not refreshed | Tell user to close and reopen the terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| Pairing code never appears in the bot's reply | Channel session not running with the `--channels` flag | Same fix as "bot doesn't respond" — re-launch with the flag (or `claude-tg`) |
| Bot replies with pairing code but assistant doesn't reply after pairing | Pair step didn't complete (wrong code sent, code expired) | Ask the user to send a fresh message to the bot to get a new code, then re-run `/telegram:access pair <code>` |
| `/telegram:configure` reports invalid token | Token corrupted during copy (extra whitespace, missing colon) | Ask the user to re-copy the full token; it has a colon in the middle and they need everything before and after it |
| Photos sent to the bot aren't being read | User sent as compressed photo, not as file | Tell them to long-press the image in Telegram and choose "Send as File" for full quality |
| Bot stops responding after token rotation | Channel session running with old token in memory | Restart Claude Code (or run `claude-tg` again) |
| Telegram Web QR scan fails repeatedly | Phone clock skew, or scanning the wrong QR | Have the user check their phone's date/time is automatic; if still failing, fall back to Phone Fallback |
| Playwright `browser_navigate` errors with `SingletonLock` | Stale Chrome process from a previous Playwright session | Run the pre-flight cleanup in Step 4; retry navigate once |
| `claude-tg` command not found in a new terminal | `~/.local/bin/` not yet on PATH for that shell | User opens a fresh terminal window after `.zshrc` was updated; or add to PATH manually |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step — isolate what changed, form a hypothesis, verify before fixing — and summarise the outcome in plain English.

---

## Phone Fallback — when Playwright MCP cannot be used

Use this ONLY when:
- Playwright MCP is not installed and cannot be installed (rare in the workshop kit; first-run-setup installs it)
- Telegram Web login fails repeatedly via QR (more than two attempts) and the user wants to push through anyway

This path puts BotFather creation back on the user's phone. It works, but it's slower and more error-prone than the Playwright path.

### Phone-driven Step 5 (replaces browser-driven Step 5)

Walk the user through @BotFather one message at a time:

1. *"On your phone, open Telegram and search for `@BotFather`. It has a blue checkmark next to its name. Tap it, then tap Start. Tell me when you've done that."*
2. When they confirm: *"Now send `/newbot` to BotFather. It'll ask you two questions: a name (whatever you want, like 'My Assistant') and a username (must end in `bot`, for example `harvey_assistant_bot`). Go through those, then paste the whole token BotFather gives you back to me. It looks like a long string with a colon in the middle."*
3. When they paste the token:
   - Do NOT echo it back.
   - Acknowledge plainly: *"Got it. Saving that now."*
   - Hold it in mind only for Step 7. Do not write it to a file other than via `/telegram:configure`.

The rest of Phase 1 (Steps 6 onward) is unchanged.

---

## Reference — what lives where

- Plugin source: installed via `/plugin install telegram@claude-plugins-official` into the user's Claude Code plugin directory.
- Bot token: stored by the plugin at `~/.claude/channels/telegram/.env` after `/telegram:configure`. Never written to any workshop-kit file.
- Allowlist state: managed by the plugin via `/telegram:access` subcommands; file at `~/.claude/channels/telegram/access.json`.
- Handoff state (this skill's only state): `~/.claude/channels/telegram/.handoff-state.json`. Written in Step 7, deleted in Step 11.
- Launch shortcut: `~/.local/bin/claude-tg` (preferred) or a `.zshrc` alias (fallback).
