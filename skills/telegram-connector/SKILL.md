---
name: telegram-connector
description: "Connect Telegram to Claude by installing and pairing the official Telegram plugin, so the user can message their assistant from their phone. Use when the user asks to set up or connect Telegram or its channel, or to message Claude from their phone, and the Telegram plugin isn't installed and paired yet. Also handles BotFather, pairing codes and the Telegram allowlist once connected."
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

> **Install pattern:** Plugin-marketplace - this SKILL is the canonical reference. See [skills/CLAUDE.md](../CLAUDE.md) for the cross-pattern overview.

## Overview

This skill connects a user's Telegram to Claude Code so they can message their assistant from anywhere. Once paired, the user texts their bot from their phone and the assistant replies as if it were a chat thread.

**The user only ever talks to ONE Claude Code session - this one.** Setup, install, pairing, lockdown, verification all happen here. There is a second `claude` process running in another terminal (started with `--channels`) but that's just the bot listener - a background server. The user pastes ONE command to start it, then leaves it alone. No two-session handoff, no resume flow, no "switch to the other window".

**The user does exactly THREE things across the entire setup. Everything else is autonomous.**

1. Scan a QR code with their phone to authenticate Telegram Web (Step 4).
2. Type `claude-tg` in a fresh terminal to start the bot listener (Step 8). Claude creates the `claude-tg` shortcut autonomously before this - the user never types or pastes the long `claude --channels …` form, and Claude does NOT auto-open a terminal via `osascript` or anything similar.
3. Restart Claude Code if a prerequisite step (e.g. fresh Bun install) needs a fresh session to pick up new PATH entries.

That is the complete list. **The user does NOT message the bot from their phone, does NOT paste a pairing code, does NOT verify anything manually.** After Step 4 the Playwright window is logged into Telegram Web AS the user - same Telegram account, same user_id. Claude drives every Telegram Web action from there: opening the bot's chat, clicking Start, sending `/start`, reading the 6-character pairing code from the bot's reply, sending a test message for verification, reading the bot's verification reply. To the listener, those messages look identical to messages the user would have sent from their phone, because they ARE the user (Telegram-Web-as-the-user is just the user on a different client).

If you find yourself about to ask the user to "open Telegram on your phone and search for your bot" or "paste the code back to me", stop. That's the wrong path. Drive Telegram Web in the Playwright window instead. The phone is a Telegram authentication device, not a workflow step.

**Which phase to run.** Phase 1 is first-time setup. Phase 2 is day-to-day operation - adding/removing people from the allowlist, rotating tokens, troubleshooting.

---

## Golden rule - Claude drives Telegram Web for EVERY Telegram action

**The default path for every Telegram-side action is the Playwright MCP browser.** Once Step 4 logs the Playwright window into Telegram Web (the user's QR scan), that window IS the user's Telegram client for the rest of the flow. Claude uses it for:

- Step 5: BotFather chat (create the bot, capture the token).
- Step 9: the user's new bot chat (click Start, send `/start`, read the pairing-code reply).
- Step 11: the user's new bot chat again (send a verification message, read the assistant's reply).

These all happen in the same Playwright window, driven by `mcp__plugin_playwright_playwright__browser_*` tools. Same Telegram account, same `user_id` Telegram sees on the wire - the listener cannot distinguish "Telegram Web driven by Claude" from "Telegram on the user's phone", because both are the user.

**Do NOT, at any point in Phase 1, ask the user to:**
- Open Telegram on their phone (after the QR scan in Step 4)
- Search for, message, or interact with the bot from their phone
- Paste a pairing code back to you
- Send a verification message from their phone
- Read the bot's reply on their phone

If you find yourself about to type any of those, stop. The Playwright window can do all of them.

The Phone Fallback section at the bottom of this file is the contingency for when the Playwright MCP browser cannot be used at all (extension not installed, non-recoverable launch failure after two attempts). It is NOT the path to use because phone instructions feel simpler - they don't, they make the user do extra work.

---

## Autonomy rule - Claude does the work, the user does not paste commands

The plugin ships user-invocable skills for token save (`/telegram:configure`), pairing (`/telegram:access pair`), and policy (`/telegram:access policy`). **This skill does not use any of them.** Asking a non-technical user to paste slash commands into chat is the wrong experience. Instead, Claude edits the underlying state files directly via Bash and Write tools:

- `~/.claude/channels/telegram/.env` - bot token (instead of `/telegram:configure`)
- `~/.claude/channels/telegram/access.json` - allowlist + pending pairings + policy (instead of `/telegram:access *`)
- `~/.claude/channels/telegram/approved/<senderId>` - approval signal file the channel server polls (written as part of pairing)

Same end result, no paste required. The channel server reads these files at boot and re-reads `access.json` on every inbound, so direct edits take effect without any plugin skill being invoked.

The only command the user runs themselves is the channel-session launch in Step 8 - they type `claude-tg` (one word) into a fresh terminal. The current Claude Code session cannot start that listener from inside itself (it'd lock up the Bash tool with a long-running interactive child), and auto-opening a terminal via `osascript` / `gnome-terminal` / `Start-Process` is explicitly banned in Step 8 because it's flaky and confusing. The user opens their own terminal deliberately and runs the one-word shortcut. That's the entire user-side terminal interaction across Phase 1.

If you find yourself about to type "paste this into the chat", stop. Either run it via Bash, write the file directly, or note that this is a true exception and explain why.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise with `curl https://api.telegram.org/...`, do not edit the plugin's `server.ts`, do not invent new slash commands. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say Bun, npm, bash, zsh, PowerShell, CLI, MCP, env var, plugin registry, config file, contenteditable, selector. The word "terminal" is acceptable (Step 8 unavoidably uses it) but explain "a brand-new terminal window" rather than just "terminal". For other technical things, name them plainly: "a small helper tool", "the Telegram pieces", "your phone", "the browser window I'm using".
- **Tell them what is about to happen.** Before any action: "I'm going to open Telegram in a browser window now. This takes a few seconds."
- **React warmly.** Good: "That worked. Telegram is linked." Bad: "Plugin install succeeded, 6-char pair code issued."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem, let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths**, with one carve-out: Step 8 Part C deliberately shows the user `claude-tg` because they have to type it. That's the only exception; do not show shell commands or file paths anywhere else.
- **Security: never repeat the bot token back to the user.** Step 5's clipboard-transit pattern keeps the token out of any tool-call return value. Once `~/.claude/channels/telegram/.env` is written, the token's job is done - do not re-read that file, do not echo it, do not include it in any later message.

---

## PHASE 1 - Install & Pair

**Run Steps 1 through 11 in order, all in this one Claude Code session. Step 4 opens Telegram Web in the Playwright MCP browser; Step 5 drives @BotFather autonomously inside that browser. Step 8 creates the `claude-tg` shortcut and asks the user to run it in a fresh terminal - that one word is the only thing the user types in a terminal across the whole flow. The Phone Fallback section at the bottom of this file is only for when Step 4 fails twice in a row - do not start there.**

**Resume check.** If the user is starting a new conversation but `~/.claude/channels/telegram/.env` already exists with a `TELEGRAM_BOT_TOKEN` line, the bot was at least partially configured by an earlier run. Ask: *"Looks like you started this earlier. Want me to pick up from where you left off, or start completely fresh?"*

- **Pick up** → run **Step 8 Part B** (pkill any stale listener) first, then **Step 8 Part C** (have the user run `claude-tg`), then **Step 8 Part D** (mandatory health check). Do not assume any prior listener is alive - the user almost certainly closed that terminal. From Part D, continue normally.
- **Fresh** → wipe all local state, then start at Step 1:
  ```bash
  pkill -f "claude-plugins-official/telegram" 2>/dev/null
  rm -rf ~/.claude/channels/telegram/
  rm -f ~/.local/bin/claude-tg
  ```
  Note this only wipes local state; the bot still exists in BotFather upstream. If the user wants the bot revoked too, drive Telegram Web in Playwright after Step 4 to send `/revoke` then `/deletebot` to BotFather.

### Step 1 - Prerequisite check

Before any technical step, confirm the user has what they need. Send:

*"Before we begin, one quick check. Do you have your phone with you with the Telegram app installed and a Telegram account already signed in? You'll only need it once, to scan a QR code in a moment. If you've never used Telegram, you'll need to install it and sign in first."*

Wait for "yes" before moving on. If they say no, pause the setup until they've installed and signed in. Do not try to work around this - Telegram Web requires a QR scan from a logged-in Telegram client to authenticate, and the user's phone is the easiest one. (Once Telegram Web is logged in via Step 4, the phone is no longer needed for the rest of Phase 1 - Claude drives all Telegram-side actions through the Playwright window.)

### Step 2 - Detect OS and shell

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Ask them: *"Quick question. On your computer, when you open a black or blue text window to type commands, does the prompt start with `PS` or just `C:\...>`? Or are you not sure?"* Map their answer the same way `whatsapp-connector` does.

### Step 3 - Check that Bun is installed

Tell the user: *"I'm going to check if a small helper tool is already on your computer. This takes a few seconds."*

Silently run `bun --version`.

- **If it prints a version** → "That's ready." Go to Step 4. No restart needed; the rest of Phase 1 will work.
- **If the command is not found** → install Bun silently. This is where the third action in the user-action contract (restart the app) becomes mandatory:

  - **Mac / Linux:** `curl -fsSL https://bun.sh/install | bash`
  - **Windows (PowerShell):** `powershell -c "irm bun.sh/install.ps1 | iex"`

  **Defensive PATH patch (Mac / Linux only).** The official Bun installer is non-deterministic about whether it appends the `BUN_INSTALL` and PATH-export lines to the user's shell rc - sometimes it writes only the completions line. When that happens, the binary lands at `~/.bun/bin/bun` but isn't on PATH for fresh login shells, and Step 8's listener silently fails to spawn the bun-based channel MCP server even after a clean app restart. Patch the rc explicitly so the install is deterministic across installer versions:

  ```bash
  # Detect shell rc (same logic as Step 8 Part A)
  SHELL_RC=~/.zshrc
  [ ! -f "$SHELL_RC" ] && [ -f ~/.bash_profile ] && SHELL_RC=~/.bash_profile
  [ ! -f "$SHELL_RC" ] && [ -f ~/.bashrc ] && SHELL_RC=~/.bashrc
  [ ! -f "$SHELL_RC" ] && SHELL_RC=~/.zshrc && touch "$SHELL_RC"

  if ! grep -qE 'BUN_INSTALL|\.bun/bin' "$SHELL_RC"; then
    {
      echo ''
      echo '# bun'
      echo 'export BUN_INSTALL="$HOME/.bun"'
      echo 'export PATH="$BUN_INSTALL/bin:$PATH"'
    } >> "$SHELL_RC"
  fi
  ```

  This is symmetrical to the `~/.local/bin` PATH check in Step 8 Part A. On Windows the installer's PowerShell variant has its own (different) PATH-management semantics, so this defensive patch is Mac/Linux only.

  After install completes (and the rc is patched), tell the user:

  *"I just installed the helper tool. There's one thing I need you to do before we keep going: fully quit and reopen the app you're using to talk to me, whether that's Claude Desktop or VS Code. Just closing the terminal isn't enough. The app inherits its environment from when it first launched, so the new tool won't be available until the whole app restarts. On Mac, that's Cmd+Q to quit, then reopen from the dock. After it's back open, come back to this conversation (it'll resume from where we left off) and say 'ready'."*

  **Why this matters:** the Step 8 listener launches in a terminal - either inside the user's app, or a freshly-opened Terminal.app / iTerm window. Either path needs `bun` on PATH at terminal-launch time. The defensive rc patch above guarantees `bun` lands in the rc. The app restart then guarantees the app's own integrated terminal also picks up the patched rc on its next launch. Skipping either half lets Step 8's listener silently fail with no clue why.

  Wait for the user to confirm. Then re-verify with `bun --version`. If it still fails after the restart, apply the PATH fix guidance in `skills/first-run-setup/SKILL.md` ("Windows Snags Reference" section).

### Step 4 - Open Telegram Web in the Playwright MCP browser

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

Do not run cleanup pre-emptively - only after a launch failure, and only once.

**Navigate.** Use `mcp__plugin_playwright_playwright__browser_navigate` to `https://web.telegram.org/k/`.

**Wait for the QR code.** Use `mcp__plugin_playwright_playwright__browser_snapshot` to confirm the page rendered. The QR code is the dominant element on the login screen.

Tell the user: *"A Telegram login screen has opened with a QR code. On your phone, open Telegram, tap the menu (three lines, top left), tap Settings, tap Devices, then tap 'Link Desktop Device'. Point your phone camera at the QR code on screen. Tell me when you've done that."*

**Wait for login.** After the user confirms, take a fresh snapshot. The chat list should be visible (a left-hand pane with chat thread tiles). If still on the QR screen after 30 seconds, ask the user if they hit any issues and re-take the snapshot.

If login fails repeatedly (more than two retries), fall back to **Phone Fallback**.

### Step 5 - Drive @BotFather autonomously

Once Telegram Web is logged in, Claude does the entire BotFather conversation in the Playwright window. The user does not touch their phone for this step.

**Find @BotFather.** Use `browser_snapshot` to locate the search input in the chat list pane. Click it, then type `BotFather`. From the search results, click the entry with the official blue checkmark - its handle reads `@BotFather`. Be deliberate: there are scammer copycats; the genuine one has the verified-account checkmark.

**Open the chat.** When the BotFather profile pane shows, click **Start** at the bottom - **not** Open. The "Open" button is for an unrelated mini-app and will not trigger the bot conversation. Confirm the chat opened by snapshot - you should see the BotFather chat with a welcome message.

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

**Send the bot name.** Take a snapshot to confirm BotFather replied with "Alright, a new bot. How are we going to call it?". If the user has told you a name preference earlier in the conversation, use that. Otherwise, use a sensible default like "My Assistant" - this is just the display name and can be anything. Send via the same `browser_evaluate` pattern.

**Send the bot username.** BotFather replies asking for a unique username ending in `bot`. Propose one based on the user's first name if known: `<firstname>_assistant_bot`. If the user's name is not known, ask them now: *"BotFather needs a unique handle for your bot. Something short ending in 'bot', for example `jamie_assistant_bot`. What would you like?"*

After sending the username, snapshot. BotFather either:
- Replies with the bot token (success) - extract it
- Replies "Sorry, this username is already taken" - try a variant (`<firstname>_assistant_bot2`, `<firstname>_ai_bot`, etc.) up to 3 times before asking the user

**Capture the token - without ever returning it to Claude's transcript.** The naive approach is to extract the token via `browser_evaluate` and have Claude hold it in memory until Step 7. The problem: tool-call returns become part of the conversation transcript. A token returned from `browser_evaluate` is logged, even if Claude itself "doesn't echo it back" to the user. That's a leak.

Instead, write the token directly to its final destination from inside the browser-evaluate via `fetch` to a local sidecar - but Playwright has no filesystem access. So use a two-step approach: copy to clipboard via JS, then read clipboard via shell. The token transits clipboard for less than a second and never appears in Claude's tool returns.

Step 1, run this `browser_evaluate`:

```javascript
() => {
  const messages = document.querySelectorAll('.message');
  const last = messages[messages.length - 1];
  const text = last.innerText;
  const match = text.match(/\b\d{8,}:[A-Za-z0-9_-]{30,}\b/);
  if (!match) return { found: false };
  navigator.clipboard.writeText(match[0]);
  // Return only metadata - never the token itself
  return { found: true, length: match[0].length };
}
```

Step 2, immediately read clipboard from Bash and write `.env` in one shot, never letting the token surface:

```bash
mkdir -p ~/.claude/channels/telegram
pbpaste | awk 'NF { printf "TELEGRAM_BOT_TOKEN=%s\n", $0 }' > ~/.claude/channels/telegram/.env
chmod 600 ~/.claude/channels/telegram/.env
# Wipe clipboard so the token doesn't linger
printf "" | pbcopy
```

(On Linux substitute `xclip -selection clipboard -o` for `pbpaste` and `xclip -selection clipboard` for `pbcopy`.)

Verify the env file was written without echoing it:

```bash
test -s ~/.claude/channels/telegram/.env && grep -c "^TELEGRAM_BOT_TOKEN=" ~/.claude/channels/telegram/.env
```

Expect `1`. The token is now in `.env` (chmod 600) and out of clipboard. It was never in any tool-call return value.

This captures and writes the token in one move; Step 7 is now just a sanity check.

Remember the bot's username (the handle BotFather accepted in the `/newbot` exchange above, e.g. `jamie_assistant_bot` without the `@`). Keep it in conversation context - Step 9 needs it to navigate to the bot's chat.

### Step 6 - Install the Telegram plugin

Tell the user: *"I'm installing the Telegram pieces. About 30 seconds."*

Silently run the install via Bash:

```bash
claude plugin install telegram@claude-plugins-official
```

Verify with a separate, stable command (do not parse the install output):

```bash
claude plugin list | grep telegram@claude-plugins-official
```

Expect a line showing `telegram@claude-plugins-official` with a version. The plugin's own skills (`/telegram:configure`, `/telegram:access`) won't be loaded into the running session until a restart, but that's fine - per the Autonomy rule above, this skill never invokes them. The only thing that matters here is that the plugin is registered in `~/.claude/plugins/installed_plugins.json` so the channel session in Step 8 can find it.

- Success → "That's done." Go to Step 7.
- Permissions error (`EACCES`, `EPERM`) → translate: *"Your computer needs a small permission fix, give me a moment to sort it."* Apply guidance from `skills/first-run-setup/SKILL.md`, then retry.
- Network error → *"Your network is blocking the install. This happens on company laptops. Could you try from a home connection?"*

### Step 7 - Confirm the token landed

Step 5 already captured the token via clipboard and wrote it to `~/.claude/channels/telegram/.env` with chmod 600. Nothing more to do here except sanity-check and tell the user where we are.

```bash
test -s ~/.claude/channels/telegram/.env && grep -c "^TELEGRAM_BOT_TOKEN=" ~/.claude/channels/telegram/.env
```

Expect `1`. If it's `0` or the file is missing, the clipboard read in Step 5 failed - try re-running Step 5's clipboard-read step. If still failing, fall back to extracting the token via `browser_evaluate` direct return (accepting the transcript leak as a tradeoff for getting unblocked) and write it via the older `printf` approach.

Then say to the user: *"Token saved. Next, you'll start the bot's listener in a new terminal. I'll give you the exact command in a moment."*

### Step 8 - Create the launch shortcut, then have the user start the bot listener

The user's only terminal action across this entire setup is one word: `claude-tg`. To make that possible, Claude creates the `claude-tg` shortcut autonomously **before** asking the user to do anything in a terminal. The user never types or pastes the long `claude --channels …` form.

**Do NOT use `osascript`, `gnome-terminal`, `Start-Process`, or any auto-open-terminal trick.** The user opens their own terminal and types `claude-tg` deliberately; auto-opening is flaky and confusing.

#### Part A - Create the `claude-tg` shortcut autonomously

Ask the user one question about permission prompts (this controls a flag baked into the shortcut):

*"Quick question before I set up your shortcut. When you're driving me from your phone over Telegram, you can't tap an 'allow' button on your laptop, so permission prompts will stall things. I can build the shortcut so it skips permission prompts when you're running via Telegram. Your Telegram allowlist still controls who can talk to your bot, so it's safe for solo use. Skip prompts? (Recommended.)"*

Capture the answer:
- **Yes** → `FLAGS=" --dangerously-skip-permissions"`
- **No** → `FLAGS=""`

Then build the script. Use an executable in `~/.local/bin/claude-tg` (a script in a PATH directory beats a `.zshrc` alias - aliases don't load in non-interactive shells, VS Code's integrated terminal, or already-open windows):

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-tg <<EOF
#!/bin/sh
exec claude --channels plugin:telegram@claude-plugins-official${FLAGS} "\$@"
EOF
chmod +x ~/.local/bin/claude-tg
```

Ensure `~/.local/bin/` is on PATH for fresh terminals - append to the user's shell rc only if not already present:

```bash
# Detect shell rc (zsh first, fallback to bash)
SHELL_RC=~/.zshrc
[ ! -f "$SHELL_RC" ] && [ -f ~/.bash_profile ] && SHELL_RC=~/.bash_profile
[ ! -f "$SHELL_RC" ] && [ -f ~/.bashrc ] && SHELL_RC=~/.bashrc
[ ! -f "$SHELL_RC" ] && SHELL_RC=~/.zshrc && touch "$SHELL_RC"

if ! grep -q '.local/bin' "$SHELL_RC"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
fi
```

Don't run `which claude-tg` in this Bash session to verify - the current shell's PATH was set at session start and won't see the new entry. The user's fresh terminal in Part B will pick it up. Verification is the user successfully running `claude-tg` in Part B.

**Windows note:** if the user is on Windows, write `%USERPROFILE%\.local\bin\claude-tg.cmd` instead, with body `@echo off` then `claude --channels plugin:telegram@claude-plugins-official%FLAGS% %*`. Add `%USERPROFILE%\.local\bin` to user PATH via `setx PATH "%PATH%;%USERPROFILE%\.local\bin"`.

#### Part B - Kill any stale listener (silent, autonomous)

Before asking the user to start a new listener, kill any pre-existing one. Two listeners polling the same Telegram bot is always wrong (long-poll conflicts, duplicated messages):

```bash
pkill -f "claude-plugins-official/telegram" 2>/dev/null
sleep 1
```

This is silent - no need to mention it to the user. It either kills a stale process or does nothing.

#### Part C - User starts the listener with the shortcut

Tell the user, in one short message:

*"Telegram is ready to link. The last thing you need to do is start the bot's listener. It's a small program that runs in the background. Open a brand-new terminal window (Cmd+N if Terminal is already open). Type this one word and press Enter:"*

```
claude-tg
```

*"Leave that window alone after it loads. That's the listener running. Come back here and tell me 'started' when it's up."*

Wait for the user to confirm.

**Fallback only if `claude-tg` is not found in their fresh terminal** (PATH didn't propagate): tell them to paste `claude --channels plugin:telegram@claude-plugins-official` instead, just for this launch. Debug PATH later. Degraded path, not the default.

#### Part D - MANDATORY: verify the listener actually spawned

Once the user says "started", **do not proceed to Step 9 yet.** Verify the bun listener process actually exists. This is non-negotiable: in some Claude Code versions (notably 2.1.121), `--channels plugin:…` in interactive mode silently fails to spawn the channel MCP server. The Claude session looks fine, the prompt is responsive, but no Telegram listener is actually running. Pairing then fails with no feedback.

Wait ~3 seconds after "started", then:

```bash
sleep 3
pgrep -fa "claude-plugins-official/telegram" 2>&1
```

**Branches:**

- **One process found, command line includes `bun` and the plugin path** → listener is alive. Tell the user *"Listener is up. Pairing now."* and proceed to Step 9.

- **No process found** → silent-spawn failure. The terminal that ran `claude-tg` started `claude` (which is on PATH globally) but the spawn of the bun-based channel MCP server child failed silently because `bun` wasn't reachable. Two distinct manifestations cause this; they need different fixes, so diagnose first:

  ```bash
  # Probe a fresh login shell - does it find bun?
  zsh -ilc 'command -v bun' >/dev/null 2>&1 && echo "RC_OK" || echo "RC_BROKEN"
  ```

  **Case A - probe prints `RC_OK`:** `bun` IS reachable from a fresh login shell. The user's listener terminal launched from a stale environment (typically Claude Desktop's or VS Code's integrated terminal, opened before Bun was installed). Step 3's restart instruction is the fix. Tell the user, plainly:

  *"The listener started Claude but couldn't load the Telegram piece. The terminal you used picked up an old environment from before I installed the helper tool. The fix is to fully quit your Claude Desktop or VS Code app (whichever you're in), Cmd+Q on Mac (not just closing the terminal), and reopen it. Then come back here, say 'restarted', and I'll have you run `claude-tg` again in a fresh terminal."*

  After "restarted", run Part B again (kill any leftover stale listener) and Part C (have them run `claude-tg`), then re-run this Part D health check.

  **Case B - probe prints `RC_BROKEN`:** `bun` is NOT reachable from a fresh login shell. The Bun installer didn't patch the user's shell rc, so even a freshly-opened Terminal.app / iTerm window won't find `bun`. App restart will not help - the rc itself is broken. Step 3's defensive PATH patch is the proactive prevention; if we're here it didn't run or didn't take. Patch the rc now (same code as Step 3) and have the user re-launch in a fresh terminal:

  ```bash
  SHELL_RC=~/.zshrc
  [ ! -f "$SHELL_RC" ] && [ -f ~/.bash_profile ] && SHELL_RC=~/.bash_profile
  [ ! -f "$SHELL_RC" ] && [ -f ~/.bashrc ] && SHELL_RC=~/.bashrc
  [ ! -f "$SHELL_RC" ] && SHELL_RC=~/.zshrc && touch "$SHELL_RC"

  if ! grep -qE 'BUN_INSTALL|\.bun/bin' "$SHELL_RC"; then
    {
      echo ''
      echo '# bun'
      echo 'export BUN_INSTALL="$HOME/.bun"'
      echo 'export PATH="$BUN_INSTALL/bin:$PATH"'
    } >> "$SHELL_RC"
  fi
  ```

  Then run Part B (kill any leftover listener) and tell the user:

  *"I just patched a missing line in your shell config. The terminal you used didn't have the helper tool on its path. Close that terminal window completely, open a new one, and run `claude-tg` again - say 'started' once it's up."*

  Re-run this Part D health check after they do so.

  If after both fixes (app restart for Case A, rc patch for Case B) `pgrep` STILL finds nothing, something deeper is wrong (Bun got uninstalled, plugin install corrupted, or a real Claude Code bug). At that point stop Phase 1 and walk the Troubleshooting table. **Do not improvise** - do not start a standalone `bun server.ts` outside Claude, it polls Telegram but has no Claude attached, which gives the user a worse half-broken experience (pair codes work but no message round-trip works) than a clean stop.

- **Multiple processes found** → Part B's pkill missed something. Kill all matches and ask user to re-run `claude-tg`:

  ```bash
  pkill -9 -f "claude-plugins-official/telegram"
  sleep 1
  ```

  Then re-run Part C.

**Why this gate matters:** without it, Steps 9-11 all run "successfully" (Claude drives Telegram Web, sends `/start`, sees no reply, times out, reports failure to the user) but the user has no idea WHY - looks like network issue or wrong code. The health check turns a silent failure into an honest one.

**Why one terminal action is unavoidable:** the listener is a child process of `claude`, an interactive program. The current Claude Code session can run shell commands via Bash, but a long-running interactive `claude --channels` would lock up the Bash tool until the listener exits. Spawning it via `nohup` or `&` is fragile (TTY allocation, stdin/stdout handling). A separate terminal window is the right primitive. The shortcut shrinks the user's typing to one word.

### Step 9 - Pair the user's Telegram autonomously via the Playwright browser

The Playwright window is still logged into Telegram Web as the user (from Step 4). The listener is running in the user's other terminal. Claude pairs by driving Telegram Web - opening the user's new bot, clicking Start, reading the 6-character pairing code from the bot's reply, then writing the pair op directly to `access.json`. **The user's phone is not involved.** Do not ask the user to message the bot from their phone, do not ask them to paste a code.

Tell the user once: *"Pairing your account now. Hold tight, this takes about 10 seconds."*

Then:

1. **Wait ~3 seconds** for the listener to fully boot (it just started in Step 8). A short `sleep 3` is fine.

2. **Navigate to the user's bot in Telegram Web.** Take a fresh `mcp__plugin_playwright_playwright__browser_snapshot`. The Playwright window is currently on the BotFather chat from Step 5. Click the search input in the chat-list pane, type the bot's username from Step 5 (no `@`), wait for results, click the matching bot.

   If search structure is unclear from the snapshot, fall back to direct navigation:
   ```
   mcp__plugin_playwright_playwright__browser_navigate to https://web.telegram.org/k/#@<botusername>
   ```
   That URL deep-links to the bot's chat inside the same Web app session.

3. **Click Start (first-time chats only).** Snapshot. If a "START" button is visible at the bottom of the chat (Telegram shows this once for any bot the user has never messaged), click it. That sends `/start` automatically. If "START" isn't visible (chat already initiated), send `/start` via the contenteditable input pattern from Step 5:

   ```javascript
   () => {
     const input = document.querySelector('.input-message-input');
     input.focus();
     document.execCommand('insertText', false, '/start');
     const event = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true });
     input.dispatchEvent(event);
   }
   ```

4. **Wait for the bot's pairing-code reply.** The listener will see the inbound, generate a 6-character code, write it into `access.json`'s `pending`, and reply through Telegram with the code embedded in the message. Don't rely on a specific reply phrase - the listener's wording may change. Instead, snapshot the chat right after sending `/start` to record the message count, then poll `browser_snapshot` every 2 seconds for up to 30 seconds until a NEW bot message appears (count > snapshot count). The new message is the pairing reply. Alternative: poll `~/.claude/channels/telegram/access.json` for a non-empty `pending` object - that's the most reliable signal since the listener writes to `access.json` BEFORE replying via Telegram.

5. **Read the code from `access.json` directly** - more reliable than parsing Telegram Web's rendered message text. The listener writes `pending[<code>]` to `access.json` before sending its Telegram reply, so the code is available in the file as soon as the reply lands:

   ```bash
   python3 - <<'PYEOF'
   import json, os, time
   path = os.path.expanduser("~/.claude/channels/telegram/access.json")
   for _ in range(15):
       if os.path.exists(path):
           with open(path) as f:
               data = json.load(f)
           pending = data.get("pending", {})
           if pending:
               # Take the most recently issued code (highest createdAt)
               code = max(pending, key=lambda k: pending[k].get("createdAt", 0))
               print(code)
               break
       time.sleep(2)
   PYEOF
   ```

   Capture the printed code into `$CODE` for the next step.

6. **Run the pair op against `access.json`** (same file mutation as before, no user input needed):

   ```bash
   CODE='<extracted-code>'
   python3 - <<PYEOF
   import json, os, sys, time
   path = os.path.expanduser("~/.claude/channels/telegram/access.json")
   if not os.path.exists(path):
       sys.exit(1)
   with open(path) as f:
       data = json.load(f)
   pending = data.get("pending", {})
   entry = pending.get("$CODE")
   if not entry: sys.exit(2)
   if entry.get("expiresAt", 0) < int(time.time() * 1000): sys.exit(3)
   sender, chat = entry["senderId"], entry["chatId"]
   allow = data.get("allowFrom", [])
   if sender not in allow:
       allow.append(sender)
   data["allowFrom"] = allow
   pending.pop("$CODE", None)
   data["pending"] = pending
   with open(path, "w") as f:
       json.dump(data, f, indent=2)
   approved_dir = os.path.expanduser("~/.claude/channels/telegram/approved")
   os.makedirs(approved_dir, exist_ok=True)
   with open(os.path.join(approved_dir, sender), "w") as f:
       f.write(chat)
   PYEOF
   ```

7. **Branches by exit code:**
   - **0 (success)** → tell the user *"Paired."* Continue to Step 10. (The listener polls `approved/` and sends a "you're in" confirmation via Telegram, which will appear in the Playwright window.)
   - **1 (access.json missing)** → listener didn't boot. Ask the user to check the listener terminal window for errors and retry.
   - **2 (code not in pending)** → snapshot extraction read the wrong text. Re-run extraction or send `/start` again to get a fresh code.
   - **3 (expired)** → send `/start` again to get a fresh code, retry pair op.

### Step 10 - Lock down access

Tell the user: *"One more thing. By default anyone who messages your bot gets a pairing code. I'll switch that off so only you can use it."*

Edit `access.json` directly - do NOT ask the user to run `/telegram:access policy allowlist`:

```bash
python3 - <<'PYEOF'
import json, os
path = os.path.expanduser("~/.claude/channels/telegram/access.json")
with open(path) as f:
    data = json.load(f)
data["dmPolicy"] = "allowlist"
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print("locked")
PYEOF
```

Confirm: *"Done. Strangers can't trigger pairing on your bot now."*

### Step 11 - Round-trip verification (autonomous via Playwright)

Confirm the round-trip works by sending a real message from Telegram Web and reading the bot's reply - same Playwright window that just paired. **Do not ask the user to send a test message from their phone.**

1. Tell the user: *"Last check. Sending a test message and reading the reply now."*

2. **Send a verification message** in the bot's chat (still focused in the Playwright window from Step 9):

   ```javascript
   () => {
     const input = document.querySelector('.input-message-input');
     input.focus();
     document.execCommand('insertText', false, 'Verification: are you alive?');
     const event = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true });
     input.dispatchEvent(event);
   }
   ```

3. **Wait for the assistant's reply.** The listener receives the inbound, dispatches it to the channel session's assistant, the assistant replies via the listener, and the reply appears in the Telegram Web chat. Use `mcp__plugin_playwright_playwright__browser_wait_for` for new content with a 60-second timeout, or poll `browser_snapshot` for a new message after the verification one.

4. **Read the reply** with the same `.innerText` extraction pattern used in Step 9. Confirm it's not the listener's "you're paired" auto-confirmation (that may also appear around this time - distinguish by text or message order).

5. **Branches:**
   - **Sensible reply received** → tell the user: *"Telegram is fully working. Next time you want to chat with me on Telegram, just open a terminal and type `claude-tg`. That's the shortcut we set up earlier."* Phase 1 is complete.
   - **Timeout / no reply within 60s** → check the listener terminal status. Most common cause is the listener crashed or the channel session has no model assigned. Walk the Troubleshooting table.
   - **Reply contains an error message** → surface a plain-English version of the error to the user and walk Troubleshooting.

---

## PHASE 2 - Use the Channel

Once paired, the user messages their bot from Telegram and Claude responds directly in the chat. No tools to invoke from your side - the plugin handles inbound/outbound routing automatically. Your job in Phase 2 is to manage access, run the shortcut, and troubleshoot.

### Common requests

All Phase 2 mutations are direct edits to `~/.claude/channels/telegram/access.json` (or `.env` for tokens). The user is never asked to run `/telegram:configure` or `/telegram:access *` themselves.

**"Add another person to my allowlist."** - easiest path is to have the new person DM the bot. If the policy is currently `allowlist`, flip it to `pairing` first so the bot will reply with a code, then flip it back after pairing:

```bash
python3 - <<'PYEOF'
import json, os
p = os.path.expanduser("~/.claude/channels/telegram/access.json")
with open(p) as f: d = json.load(f)
d["dmPolicy"] = "pairing"
with open(p, "w") as f: json.dump(d, f, indent=2)
PYEOF
```

Tell the user the new person should DM the bot now. When the user pastes the resulting 6-char code to you, run the same pair script as Step 9 (the `python3 - <<PYEOF` block). After success, flip policy back to `allowlist` (same script as Step 10).

If you already have the person's numeric Telegram user ID (e.g. they got it from @userinfobot), skip pairing and add directly:

```bash
SENDER_ID='<id>'
python3 - <<PYEOF
import json, os
p = os.path.expanduser("~/.claude/channels/telegram/access.json")
with open(p) as f: d = json.load(f)
allow = d.get("allowFrom", [])
if "$SENDER_ID" not in allow: allow.append("$SENDER_ID")
d["allowFrom"] = allow
with open(p, "w") as f: json.dump(d, f, indent=2)
PYEOF
```

**"Remove someone's access."** - direct edit:

```bash
SENDER_ID='<id>'
python3 - <<PYEOF
import json, os
p = os.path.expanduser("~/.claude/channels/telegram/access.json")
with open(p) as f: d = json.load(f)
d["allowFrom"] = [x for x in d.get("allowFrom", []) if x != "$SENDER_ID"]
with open(p, "w") as f: json.dump(d, f, indent=2)
PYEOF
```

**"Pair a second device."** - same as adding a person via pairing. Flip to pairing, ask the user to message the bot from the new device, run the pair script with the new code, flip back to allowlist.

**"Rotate my bot token."** - drive Telegram Web in the Playwright window to BotFather. Send `/revoke`, BotFather lists the user's bots, click the relevant one, BotFather replies with a new token. Capture the new token using the same clipboard-transit pattern as Step 5 - never let the token surface in tool returns:

```javascript
() => {
  const messages = document.querySelectorAll('.message');
  const last = messages[messages.length - 1];
  const match = last.innerText.match(/\b\d{8,}:[A-Za-z0-9_-]{30,}\b/);
  if (!match) return { found: false };
  navigator.clipboard.writeText(match[0]);
  return { found: true, length: match[0].length };
}
```

```bash
pbpaste | awk 'NF { printf "TELEGRAM_BOT_TOKEN=%s\n", $0 }' > ~/.claude/channels/telegram/.env
chmod 600 ~/.claude/channels/telegram/.env
printf "" | pbcopy
```

Tell the user the listener needs a restart for the new token to take effect (the server reads `.env` at boot, not on every message). Tell them: *"Close the listener terminal window, then open a fresh one and run `claude-tg`."*

**"My shortcut stopped working / I'm in a new terminal and `claude-tg` isn't found."** - most common cause is a fresh terminal that hasn't sourced the updated PATH. Tell them: *"Open a brand-new terminal window (not the current one) and try again. If it still doesn't work, tell me and I'll check the shortcut."* If still broken, verify with `which claude-tg` and `ls -la ~/.local/bin/claude-tg`.

**"Toggle skip-permissions on the shortcut."** - the `--dangerously-skip-permissions` flag is baked into `~/.local/bin/claude-tg` at creation time (Step 8 Part A). Flipping it later is a one-line edit:

```bash
# Add the flag (skip prompts when running via Telegram)
sed -i.bak 's|plugin:telegram@claude-plugins-official\([^ ]*\) "\$@"|plugin:telegram@claude-plugins-official --dangerously-skip-permissions "$@"|' ~/.local/bin/claude-tg

# Remove the flag (restore prompts)
sed -i.bak 's| --dangerously-skip-permissions||' ~/.local/bin/claude-tg
```

Tell the user the change applies on the listener's next launch (kill the listener terminal, reopen, run `claude-tg`).

**"What's currently allowed?"** - read and summarise:

```bash
python3 -c 'import json,os; print(json.dumps(json.load(open(os.path.expanduser("~/.claude/channels/telegram/access.json"))), indent=2))'
```

Report it in plain English to the user, never as raw JSON.

---

## Troubleshooting

| Symptom | Likely cause | What you do |
|---|---|---|
| `claude-tg` runs and shows a Claude prompt, but no bun listener process exists (`pgrep -f "claude-plugins-official/telegram"` returns nothing) | Two distinct manifestations: (a) **stale-environment terminal** - the user's Claude Desktop / VS Code app was launched BEFORE Bun was installed, so its integrated terminal doesn't have `bun` on PATH; or (b) **broken Bun installer** - the official installer didn't append the `BUN_INSTALL` / PATH-export lines to the user's shell rc, so `bun` isn't on PATH for ANY fresh login shell. Either way, `claude` runs fine (globally installed) but the bun-based channel MCP server silently fails to spawn | Run Step 8 Part D's diagnostic to distinguish: `zsh -ilc 'command -v bun' >/dev/null 2>&1 && echo RC_OK \|\| echo RC_BROKEN`. **`RC_OK`** → manifestation (a); fully quit (Cmd+Q on Mac) and reopen Claude Desktop / VS Code, then re-run `claude-tg` in a fresh terminal. **`RC_BROKEN`** → manifestation (b); append the `BUN_INSTALL` / PATH-export lines to the user's shell rc (see the rc-patch block in Step 3 or Step 8 Part D Case B), then have the user open a fresh terminal - no app restart needed. Step 3's defensive rc patch is the proactive prevention for (b); Step 3's restart is the prevention for (a) |
| Bot doesn't respond when user messages it | Channel listener not running (`claude-tg` window closed, or silent-spawn case above) | Run `pgrep -f "claude-plugins-official/telegram"` to confirm. If nothing: `claude-tg` again. If a process IS running and still no replies: check the listener terminal for errors |
| `Bun not found` after install | PATH not refreshed | Tell user to close and reopen the terminal; if still broken, apply `skills/first-run-setup/SKILL.md` PATH fix |
| Pairing code never appears in the bot's reply (Telegram Web shows nothing back from the bot after `/start`) | Listener silent-spawn bug, OR listener crashed mid-poll | First check the listener: `pgrep -f "claude-plugins-official/telegram"`. If missing, walk row 1. If present, check the listener terminal for stack traces |
| Bot replies with pairing code but assistant doesn't reply after pairing | Pair op didn't complete (Step 9's python3 mutation failed, or wrote to the wrong code) | Re-read `~/.claude/channels/telegram/access.json` to confirm the user's senderId is in `allowFrom` AND `~/.claude/channels/telegram/approved/<senderId>` exists. If either is missing, drive Telegram Web to send `/start` again and re-run Step 9's pair op against the new code |
| Listener errors with "invalid token" or "401 Unauthorized" on startup | Token in `.env` corrupted (extra whitespace, missing colon, or clipboard read picked up the wrong text) | Verify with `grep "^TELEGRAM_BOT_TOKEN=" ~/.claude/channels/telegram/.env` and check the line contains a colon plus 30+ chars after. If wrong, drive Telegram Web back to BotFather, send `/token` to retrieve, re-run Step 5's clipboard-transit capture |
| Photos sent to the bot aren't being read | User sent as compressed photo, not as file | Tell them to long-press the image in Telegram and choose "Send as File" for full quality |
| Bot stops responding after token rotation | Channel session running with old token in memory | Restart Claude Code (or run `claude-tg` again) |
| Telegram Web QR scan fails repeatedly | Phone clock skew, or scanning the wrong QR | Have the user check their phone's date/time is automatic; if still failing, fall back to Phone Fallback |
| Playwright `browser_navigate` errors with `SingletonLock` | Stale Chrome process from a previous Playwright session | Run the pre-flight cleanup in Step 4; retry navigate once |
| `claude-tg` command not found in a new terminal | `~/.local/bin/` not yet on PATH for that shell | User opens a fresh terminal window after `.zshrc` was updated; or add to PATH manually |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging`. Otherwise work through the failure step by step - isolate what changed, form a hypothesis, verify before fixing - and summarise the outcome in plain English.

---

## Phone Fallback - when Playwright MCP cannot be used

Use this ONLY when:
- Playwright MCP is not installed and cannot be installed (rare in the workshop kit; first-run-setup installs it)
- Telegram Web login fails repeatedly via QR (more than two attempts) and the user wants to push through anyway

This path puts BotFather creation back on the user's phone. It works, but it's slower and more error-prone than the Playwright path.

### Phone-driven Step 5 (replaces browser-driven Step 5)

Walk the user through @BotFather one message at a time:

1. *"On your phone, open Telegram and search for `@BotFather`. It has a blue checkmark next to its name. Tap it, then tap Start. Tell me when you've done that."*
2. When they confirm: *"Now send `/newbot` to BotFather. It'll ask you two questions: a name (whatever you want, like 'My Assistant') and a username (must end in `bot`, for example `jamie_assistant_bot`). Go through those, then paste the whole token BotFather gives you back to me. It looks like a long string with a colon in the middle."*
3. When they paste the token, do NOT echo it back. Acknowledge plainly: *"Got it. Saving that now."* Then immediately write it to `.env` with the same shell pipeline pattern, holding the token only long enough to write the file:

   ```bash
   mkdir -p ~/.claude/channels/telegram
   TOKEN='<token-from-user>' bash -c 'printf "TELEGRAM_BOT_TOKEN=%s\n" "$TOKEN" > ~/.claude/channels/telegram/.env'
   chmod 600 ~/.claude/channels/telegram/.env
   ```

   This is a transcript leak (the token is in a tool-call argument), accepted as the cost of the phone path. Phone Fallback should be rare; if it happens, recommend the user rotate the token afterwards.

**Phase 1 caveat for the phone path:** because Telegram Web is NOT logged in (Step 4 didn't run), Steps 9 and 11 cannot drive Telegram Web autonomously. The user has to message the bot from their phone to trigger pairing, paste the code back into chat, and send a verification message manually. This is the experience the main flow specifically avoids - that's why Phone Fallback is the contingency, not the default.

---

## Reference - what this skill owns on the user's machine

- **Plugin source:** installed by Step 6 via `claude plugin install telegram@claude-plugins-official` into `~/.claude/plugins/cache/claude-plugins-official/telegram/<version>/`. The plugin ships its own user-invocable skills (`/telegram:configure`, `/telegram:access`); this skill bypasses them and writes the same state files directly.
- **Bot token:** `~/.claude/channels/telegram/.env`, written by Step 5 (or Phase 2 token rotation) via the clipboard-transit pattern. chmod 600. Read by the listener at boot.
- **Allowlist + pairing state:** `~/.claude/channels/telegram/access.json`, written by Steps 9, 10, and Phase 2 access ops via direct python3 mutation. Re-read by the listener on every inbound, so direct edits take effect immediately.
- **Approval signal:** `~/.claude/channels/telegram/approved/<senderId>` files, written by Step 9 with the user's chatId. The listener polls this directory and sends a "you're approved" Telegram reply when it sees a new file.
- **Launch shortcut:** `~/.local/bin/claude-tg`, written by Step 8 Part A. Optionally bakes in `--dangerously-skip-permissions`. PATH export added to the user's shell rc if not already present.

When cleaning up, the resume-check "fresh" path covers everything except the upstream BotFather state (the bot itself).
