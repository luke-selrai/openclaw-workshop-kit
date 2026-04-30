---
name: whatsapp-connector
description: "Connect the user's WhatsApp to Claude Code so they can message their assistant from their phone. Drives the install + QR-pairing flow autonomously: Claude installs Bun if missing, installs the channel's packages, writes a one-word `claude-wa` launch shortcut, kills any stale listener, then asks the user to start the listener in a fresh terminal and scan the QR with their phone. The only human moments are scanning the QR code, typing `claude-wa` once, and (if a fresh Bun install was needed) restarting the host app once. Use this skill when the user says 'set up WhatsApp', 'connect my WhatsApp', 'install the WhatsApp channel', or asks about past WhatsApp messages, the allowlist, or the QR pairing flow. On the first use, run Phase 1 before attempting any tool calls."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Channels & Messaging
  tags:
    - whatsapp
    - channel
    - messaging
    - baileys
    - mcp
  pairs-with:
    - skill: first-run-setup
      reason: Shares the Bun / PATH / shell-detection patterns used during install
    - skill: telegram-connector
      reason: Same messaging-channel install pattern. Reference for the listener health check, alias creation, and app-restart discipline
    - skill: playwright-skill
      reason: The Playwright MCP browser is available for any browser-side troubleshooting (e.g. inspecting the local QR page if it does not render)
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting QR, auth, or message-delivery failures
---

# WhatsApp Connector

## Overview

This skill connects a user's WhatsApp to Claude Code so they can message their assistant from their phone. Once paired, the user texts the assistant from WhatsApp on their phone and Claude replies as if it were a chat thread.

**The user only ever talks to ONE Claude Code session — this one.** Setup, install, pairing, verification all happen here. There is a second `claude` process running in another terminal (started with `--dangerously-load-development-channels`) but that is just the WhatsApp listener — a background server. The user pastes ONE word to start it, then leaves it alone. No two-session handoff, no resume flow, no "switch to the other window".

**The user does exactly THREE things across the entire setup. Everything else is autonomous.**

1. Scan a QR code with their phone to pair WhatsApp Web (Step 7).
2. Type `claude-wa` in a fresh terminal to start the WhatsApp listener (Step 7). Claude creates the `claude-wa` shortcut autonomously before this. The user never types or pastes the long `claude --dangerously-load-development-channels …` form, and Claude does NOT auto-open a terminal via `osascript`, `gnome-terminal`, or `Start-Process`.
3. Restart the host app (Claude Desktop or VS Code) if a prerequisite step (e.g. fresh Bun install) needs a fresh session to pick up new PATH entries.

That is the complete list. **The user does NOT search for the linking screen on their phone, does NOT paste the launch command, does NOT edit any config files for the allowlist.** Claude drives every install-side action; the user's phone only does what it has to do — scan the QR shown by the local QR page.

If you find yourself about to ask the user to "paste this into your terminal" with anything longer than `claude-wa`, or to "edit `.mcp.json` and add this line", stop. That is the wrong path. Drive the install via Bash and Write tools instead. The phone is a WhatsApp authentication device, not a workflow step.

**Which phase to run.** Phase 1 is first-time setup. Phase 2 is day-to-day operation — sending messages, reading inbound messages, querying history, and managing the allowlist.

**Resume check.** Before any WhatsApp action, check whether the channel is already paired. Read `~/.claude/whatsapp-channel/auth/creds.json`. If it exists and is non-empty, treat the channel as paired and skip to Phase 2. If it is missing or empty, run Phase 1.

---

## Golden rule — Claude drives the install autonomously

**Claude does the work; the user only does what genuinely requires them.** Across Phase 1, the user's only physical actions are:

- Scanning the QR code shown on the local QR page with their phone (Step 7).
- Typing `claude-wa` in a fresh terminal once, to start the listener (Step 7).
- Restarting the host app if Step 3 had to install Bun (Step 3).

Everything else — detecting OS and shell, installing Bun, running `bun install` for the channel, writing the launch shortcut, ensuring PATH, killing stale listeners, polling for `creds.json` — Claude does via Bash and Write tools without asking the user to type or paste anything else.

**Do NOT, at any point in Phase 1, ask the user to:**

- Open WhatsApp on their phone for any reason other than the linking screen (Step 7)
- Paste the long `claude --dangerously-load-development-channels server:whatsapp` form
- Open `.mcp.json` to edit the allowlist
- Run `bun install`, `curl`, or any package-install command themselves
- Copy a file path, an env var, or a credential value into chat

If you find yourself about to type any of those, stop. Bash + Write can do all of them.

The Phone Fallback section at the bottom of this file is the contingency for when Step 7's `claude-wa` shortcut fails twice in a row. It is NOT the path to use because manual instructions feel simpler. They don't, they make the user do extra work.

---

## Autonomy rule — Claude edits state files in place, the user does not paste commands

The WhatsApp channel reads its state from on-disk files inside the workshop-kit checkout and inside the user's home directory. **This skill does not ask the user to edit any of them.** Instead, Claude edits them directly via Bash, Write, and python3:

- `whatsapp-channel/.mcp.json` — channel config including the `WA_ALLOW_FROM` env var (instead of "open `.mcp.json` and add a number")
- `~/.claude/whatsapp-channel/auth/creds.json` — pairing credentials (written by the Baileys listener after a successful QR scan; Claude only reads it to check pair state, never writes it)
- `~/.claude/whatsapp-channel/history.jsonl` — on-demand message log (written by the listener; Claude reads via the `whatsapp_history` tool in Phase 2)
- `~/.local/bin/claude-wa` — the launch shortcut (Claude writes this once in Step 5)

Same end result, no paste required. The Baileys listener re-reads `.mcp.json` on every restart and uses `creds.json` for session continuity, so direct edits take effect without the user touching anything.

The only command the user runs themselves is the listener launch in Step 7 — they type `claude-wa` (one word) into a fresh terminal. The current Claude Code session cannot start that listener from inside itself (it would lock up the Bash tool with a long-running interactive child), and auto-opening a terminal via `osascript` / `gnome-terminal` / `Start-Process` is explicitly banned in Step 7 because it is flaky and confusing. The user opens their own terminal deliberately and runs the one-word shortcut. That is the entire user-side terminal interaction across Phase 1.

If you find yourself about to type "paste this into the chat", stop. Either run it via Bash, write the file directly, or note that this is a true exception and explain why.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise — do not start a standalone `bun src/index.ts` outside Claude (it polls WhatsApp Web but has no Claude attached), do not edit the channel server source, do not invent new env vars. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## ⚠️ Safety gate — run this BEFORE Phase 1

The WhatsApp channel uses an unofficial Web protocol (Baileys). Meta can **permanently ban** the linked number, losing all chats, groups, and history. Before touching any install step, say this to the user in plain English and wait for explicit acknowledgement:

> "Before we start, connecting WhatsApp to Claude uses an unofficial method that Meta hasn't approved. There's a real chance the phone number you link gets banned, sometimes permanently. I strongly recommend using a cheap second SIM, not your main number. Are you okay with that risk, and which number are you planning to link, your main one or a secondary?"

If they pick their main number, push back once: *"I'd really prefer you used a secondary SIM here. People have lost their main WhatsApp accounts doing this. Want to grab a prepaid SIM first?"* If they still insist, proceed. It's their call, but you've warned them.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous: Claude does the work, the user only scans the QR and types `claude-wa`. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values, with the single carve-out for `claude-wa` in Step 7. The only verbal asks across Phase 1 are: "are you okay with the Meta-ban risk on this number?", "say 'ready' when your app is back open" (after a Bun install + restart), "open a fresh terminal and type `claude-wa`, then scan the QR with your phone", and "send yourself a test WhatsApp message".
- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say Bun, npm, bash, zsh, PowerShell, CLI, MCP, env var, terminal (except in Step 7 where it is unavoidable, and there explain "a brand-new terminal window" rather than just "terminal"), WebSocket, JSONL, config file, contenteditable, selector. For technical things, name them plainly: "a small helper tool", "the WhatsApp pieces", "your phone", "the connection key".
- **Tell them what is about to happen.** Before any action: *"I'm going to check if a small helper tool is already on your computer. This takes a couple of seconds."*
- **React warmly.** Good: *"That worked. WhatsApp is linked."* Bad: *"Pairing session established, ws handshake 200."*
- **Never show raw error messages.** Translate into plain English, then diagnose silently: *"No problem, let me try a different way."*
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths**, with the single carve-out for `claude-wa` in Step 7. Claude runs everything else; the user does not see it.
- **No em dashes inside italicised user-facing strings or `> "..."` blockquotes.** Use commas or full stops in user-facing speech. Em dashes are fine in section headings and Claude-facing prose.

---

## PHASE 1 — Install & Pair

**Run Steps 1 through 10 in order, all in this one Claude Code session.** Step 5 creates the `claude-wa` shortcut; Step 7 asks the user to run it in a fresh terminal and scan the QR. That one word is the only thing the user types in a terminal across the whole flow. The Phone Fallback section at the bottom of this file is only for when Step 7 fails twice in a row. Do not start there.

**Resume check.** If the user is starting a new conversation but `~/.claude/whatsapp-channel/auth/creds.json` already exists and is non-empty, the channel was paired by an earlier run. Verify the listener is up (Step 8's health check) and skip to Phase 2. If `creds.json` is missing, start at Step 1.

### Step 1 — Prerequisite check

Before any technical step, confirm the user has what they need. Send:

*"Before we begin, two quick checks. (1) Do you have your phone with you with WhatsApp installed and signed in? You'll only need it once, to scan a QR code in a moment. (2) Have you decided whether to use your main number or a secondary SIM? See the safety note above if you want a refresher."*

Wait for confirmation on both. If they say no to (1), pause until they have WhatsApp on their phone. If (2) is unresolved, return to the safety gate.

### Step 2 — Detect OS and shell

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Ask them: *"Quick question. On your computer, when you open a black or blue text window to type commands, does the prompt start with `PS` or just `C:\...>`? Or are you not sure?"* Map their answer:

- Starts with `PS` → **PowerShell**
- No `PS`, just `C:\...>` → **Command Prompt**
- Not sure → default to **PowerShell** (it's the Windows default since Win10)

Remember the detected OS. Step 5 needs it to write the right shortcut.

### Step 3 — Check the runtime stack

The WhatsApp channel server is a TypeScript program. Its `.mcp.json` runs it via `node` plus the `tsx` loader (already in `node_modules` after Step 4), and the upstream README also lists Bun as a supported alternative runtime + a fast dependency installer. Claude itself runs on Node, so Node is already present whenever this skill is loaded; Bun is the optional install we manage.

Tell the user: *"I'm going to check if a small helper tool is already on your computer. This takes a few seconds."*

Silently run `bun --version`.

- **If it prints a version** → *"That's ready."* Go to Step 4. No restart needed.
- **If the command is not found** → install Bun silently. This is where the third action in the user-action contract (restart the app) becomes mandatory because Step 4 will use Bun as the dependency installer and any future swap of `.mcp.json`'s runtime to Bun would also need it on PATH:

  - **Mac / Linux:** `curl -fsSL https://bun.sh/install | bash`
  - **Windows (PowerShell):** `powershell -c "irm bun.sh/install.ps1 | iex"`

  After install completes, tell the user:

  *"I just installed the helper tool. There's one thing I need you to do before we keep going: fully quit and reopen the app you're using to talk to me, whether that's Claude Desktop or VS Code. Just closing the terminal isn't enough. The app inherits its environment from when it first launched, so the new tool won't be available until the whole app restarts. On Mac, that's Cmd+Q to quit, then reopen from the dock. After it's back open, come back to this conversation (it'll resume from where we left off) and say 'ready'."*

  **Why this matters:** the Step 7 listener launches in a terminal inside the user's app. That terminal inherits the app's PATH from launch time. If we install Bun now and don't restart, Step 4's `bun install` will work (it runs in this very Bash, not the user's terminal), but the user's terminal in Step 7 will still see the pre-install PATH. Restart at this point is cheap (the conversation resumes); skipping it leaves the user's future terminals with a stale PATH and creates confusing intermittent failures the next time they need a Bun-aware shell.

  Wait for the user to confirm. Then re-verify with `bun --version`. If it still fails after the restart, apply the PATH fix guidance in `skills/first-run-setup/SKILL.md` ("Windows Snags Reference" section).

### Step 4 — Install the WhatsApp channel's packages

Tell the user: *"I'm installing the WhatsApp pieces now. About 30 seconds."*

Silently run from the workshop-kit folder:

```bash
WS_KIT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
cd "$WS_KIT/whatsapp-channel" && bun install
```

- **Success** → *"That's done."* Go to Step 5.
- **Permissions error (`EACCES`, `EPERM`, `EBUSY`)** → translate: *"Your computer needs a small permission fix, give me a moment to sort it."* Apply guidance from `skills/first-run-setup/SKILL.md`, then retry.
- **Network error** → *"Your network is blocking the install. This happens on company laptops. Could you try from a home connection, or ask your IT team?"*

Remember `$WS_KIT` for Step 5.

### Step 5 — Create the `claude-wa` shortcut autonomously

The user's only terminal action across this entire setup is one word: `claude-wa`. To make that possible, Claude creates the `claude-wa` shortcut autonomously **before** asking the user to do anything in a terminal. The user never types or pastes the long `WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp` form.

**Do NOT use `osascript`, `gnome-terminal`, `Start-Process`, or any auto-open-terminal trick.** The user opens their own terminal and types `claude-wa` deliberately; auto-opening is flaky and confusing.

Build an executable in `~/.local/bin/claude-wa`. A script in a PATH directory beats a `.zshrc` alias because aliases don't load in non-interactive shells, VS Code's integrated terminal, or already-open windows:

```bash
WS_KIT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-wa <<EOF
#!/bin/sh
cd "$WS_KIT/whatsapp-channel" || exit 1
WA_AUTO_OPEN_QR=1 exec claude --dangerously-load-development-channels server:whatsapp "\$@"
EOF
chmod +x ~/.local/bin/claude-wa
```

Ensure `~/.local/bin/` is on PATH for fresh terminals. Append to the user's shell rc only if not already present:

```bash
SHELL_RC=~/.zshrc
[ ! -f "$SHELL_RC" ] && [ -f ~/.bash_profile ] && SHELL_RC=~/.bash_profile
[ ! -f "$SHELL_RC" ] && [ -f ~/.bashrc ] && SHELL_RC=~/.bashrc
[ ! -f "$SHELL_RC" ] && SHELL_RC=~/.zshrc && touch "$SHELL_RC"

if ! grep -q '.local/bin' "$SHELL_RC"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
fi
```

Don't run `which claude-wa` in this Bash session to verify. The current shell's PATH was set at session start and won't see the new entry. The user's fresh terminal in Step 7 will pick it up. Verification is the user successfully running `claude-wa` in Step 7.

**Why `WA_AUTO_OPEN_QR=1` is baked in:** the env var triggers the local QR page to open in the user's default browser on first run. After pairing, `creds.json` exists and the env var is harmless on subsequent runs (no QR page opens). Leaving it on permanently keeps the shortcut single-purpose.

**Windows note:** if the user is on Windows, write `%USERPROFILE%\.local\bin\claude-wa.cmd` instead, with body:

```
@echo off
cd /d "%WS_KIT%\whatsapp-channel"
set WA_AUTO_OPEN_QR=1
claude --dangerously-load-development-channels server:whatsapp %*
```

Add `%USERPROFILE%\.local\bin` to user PATH via `setx PATH "%PATH%;%USERPROFILE%\.local\bin"`.

### Step 6 — Kill any stale listener (silent, autonomous)

Before asking the user to start a new listener, kill any pre-existing one. Two listeners polling the same WhatsApp Web session is always wrong (the Baileys session lock corrupts; the second listener will tear down the first):

```bash
pkill -f "whatsapp-channel/src/index.ts" 2>/dev/null
sleep 1
```

This is silent. No need to mention it to the user. It either kills a stale process or does nothing.

### Step 7 — User starts the listener with the shortcut

Tell the user, in one short message:

*"WhatsApp is ready to link. The last thing I need you to do is start the listener in a fresh terminal. Open a brand-new terminal window (Cmd+N if Terminal is already open). Type this one word and press Enter:"*

```
claude-wa
```

*"A QR code will open in your browser after a few seconds. On your phone, open WhatsApp, go to Settings, then Linked Devices, then Link a Device, and scan the QR. When it's linked, come back here and tell me 'scanned'."*

Wait for the user to confirm.

**Fallback only if `claude-wa` is not found in their fresh terminal** (PATH didn't propagate): tell them to paste the long form from the Phone Fallback section at the bottom of this file, just for this launch. Debug PATH later. Degraded path, not the default.

### Step 8 — MANDATORY: verify the listener actually spawned

Once the user says "scanned", **do not proceed to Step 9 yet.** Verify the listener process actually exists. This is non-negotiable: if `node_modules/` is missing or corrupt, or if a stale-environment terminal masks the runtime tooling, `claude --dangerously-load-development-channels` will silently fail to spawn the channel server. The Claude session looks fine, the prompt is responsive, but no WhatsApp listener is actually running.

Wait ~3 seconds after "scanned", then:

```bash
sleep 3
pgrep -fa "whatsapp-channel/src/index.ts" 2>&1
```

**Branches:**

- **One process found, command line includes `node` (or `bun`) and the channel path** → listener is alive. Continue to Step 9.

- **No process found** → silent-spawn failure. Two most-likely causes, in order:

  1. **Stale-environment terminal.** If Step 3 had to install Bun and the user's app wasn't fully restarted after, the terminal the user ran `claude-wa` from inherited the pre-Bun PATH. `claude` itself is on PATH (always), so the prompt comes up — but anything `claude` tries to spawn that depends on the freshly-installed tooling silently fails. This applies even when the channel's `.mcp.json` currently runs via `node` and Node was already on PATH, because future `.mcp.json` revisions or any tsx-loader-side resolution may pull from the same shell environment.

  2. **Missing or corrupt `node_modules/`.** Step 4's `bun install` may have failed silently. Check via `test -d "$WS_KIT/whatsapp-channel/node_modules/tsx" && echo OK || echo MISSING`. If `MISSING`, re-run `cd "$WS_KIT/whatsapp-channel" && bun install`, ask user to re-run `claude-wa`, re-check.

  **For cause (1), this should have been prevented by Step 3's restart instruction.** If we're hitting it now, that restart either didn't happen or didn't take. Tell the user, plainly:

  *"The listener started Claude but couldn't load the WhatsApp piece. The terminal you used picked up an old environment from before I installed the helper tool. The fix is to fully quit your Claude Desktop or VS Code app (whichever you're in), Cmd+Q on Mac (not just closing the terminal), and reopen it. Then come back here, say 'restarted', and I'll have you run `claude-wa` again in a fresh terminal."*

  After the user says "restarted", run Step 6 again (kill any leftover stale listener) and Step 7 (have them run `claude-wa` and re-scan if needed), then re-run this Step 8 health check.

  If after the full app restart and a verified `node_modules/tsx` `pgrep` STILL finds nothing, something deeper is wrong (channel source corrupted, claude itself can't read `.mcp.json`, or a real Claude Code bug). At that point stop Phase 1 and walk the Troubleshooting table. **Do not improvise.** Do not start a standalone `node src/index.ts` or `bun src/index.ts` outside Claude. It polls WhatsApp Web but has no Claude attached, which gives the user a worse half-broken experience than a clean stop.

- **Multiple processes found** → Step 6's pkill missed something. Kill all matches and ask user to re-run `claude-wa`:

  ```bash
  pkill -9 -f "whatsapp-channel/src/index.ts"
  sleep 1
  ```

  Then re-run Step 7 (which may need a fresh QR scan).

**Why this gate matters:** without it, Step 9 polls `creds.json` for up to 60 seconds, finds nothing, and reports a generic "pair didn't complete". The user has no idea why (looks like phone-camera issue or wrong QR). The health check turns a silent failure into an honest one.

### Step 9 — Wait for the QR scan to complete pairing

The Baileys listener writes `~/.claude/whatsapp-channel/auth/creds.json` once the user's phone successfully scans the QR and WhatsApp Web confirms the link. Poll for that file:

```bash
for i in $(seq 1 30); do
  if [ -s ~/.claude/whatsapp-channel/auth/creds.json ]; then
    echo "PAIRED"
    break
  fi
  sleep 2
done
```

30 iterations × 2-second sleep = 60-second total polling window.

**Branches:**

- **`PAIRED` printed** → tell the user *"Linked. WhatsApp is paired."* and continue to Step 10.
- **Timeout (loop completes without `PAIRED`)** → either the QR expired (Baileys QRs expire after about 60 seconds), or the user hasn't scanned yet, or the phone-side scan failed. Tell the user: *"Looks like the QR scan didn't complete. Want to try again?"* If yes, restart the listener (Step 6's pkill, then Step 7), and a fresh QR will appear.

### Step 10 — Verbal verification

Setup session has no `--channels` of its own, so it cannot see WhatsApp inbound. Verification is verbal: ask the user to send themselves a test message, and trust their report.

Tell the user: *"To confirm everything's working, on your phone, open WhatsApp, find your own chat (use the 'Message yourself' chat, pencil icon, search for your own name), and send 'hello'. You should see Claude reply within a few seconds. Tell me what you see."*

Wait for their report.

- **They got a reply** → *"Perfect. WhatsApp is connected and working. From now on, you can message me from WhatsApp anytime that listener is running. To start it again later, type `claude-wa` in a fresh terminal."* Phase 1 complete.
- **They got no reply** → walk the Troubleshooting table starting with "Inbound messages not arriving".
- **They got an error message instead of a reply** → ask them to read it in plain English, translate, and diagnose silently.

---

## PHASE 2 — Use the Channel

Once paired, the channel exposes these tools via the workshop-kit's `whatsapp-channel` MCP server (loaded in the user's `claude-wa` session, not in this setup session — Phase 2 instructions describe how the listener-side Claude handles tool calls):

| Tool | Use when the user wants to... |
|---|---|
| `whatsapp_send` | Send a message to a chat (self or allowlisted number) |
| `whatsapp_history` | Read past messages, filter by `chat_id`, `sender_phone`, `contains`, `since_ts`, `until_ts`, `direction`, `limit` (1–500) |
| `whatsapp_list_chats` | List chats the assistant has seen, sorted by most recent activity |

### Common patterns

**"Read the last 20 WhatsApp messages I got."** → `whatsapp_history` with `direction: "inbound"`, `limit: 20`.

**"What chats have I been active in this week?"** → `whatsapp_list_chats`, then filter by `last_ts` within the last 7 days.

**"Show me everything about the invoice from Alice."** → `whatsapp_history` with `contains: "invoice"`, then narrow by `sender_phone` if multiple people mentioned it.

**"Reply to Alice that I'll send it tomorrow."** → find Alice's `chat_id` via `whatsapp_list_chats`, then `whatsapp_send`.

**History predates the current session.** The history log at `~/.claude/whatsapp-channel/history.jsonl` persists across sessions. You can answer questions about messages from days ago, not just the current chat.

### Allowlist management — autonomous via direct file edit

The channel is **self-only by default**: only the linked phone can message the assistant. To add other numbers, Claude edits the `WA_ALLOW_FROM` env var in `whatsapp-channel/.mcp.json` directly via python3. **Do NOT ask the user to open `.mcp.json` themselves.** Same autonomy rule as Phase 1: Claude edits state files in place; the user does not paste edits.

When a user says "add +14155551234 to my WhatsApp allowlist", run:

```bash
python3 - <<'PYEOF'
import json, os
NEW_NUMBER = "+14155551234"  # substitute the real number
ws_kit = os.popen("git rev-parse --show-toplevel 2>/dev/null").read().strip() or os.path.expanduser("~/workshop-kit")
path = os.path.join(ws_kit, "whatsapp-channel", ".mcp.json")
with open(path) as f:
    data = json.load(f)
env = data.setdefault("mcpServers", {}).setdefault("whatsapp", {}).setdefault("env", {})
existing = [n.strip() for n in env.get("WA_ALLOW_FROM", "").split(",") if n.strip()]
if NEW_NUMBER not in existing:
    existing.append(NEW_NUMBER)
env["WA_ALLOW_FROM"] = ",".join(existing)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print(f"Added {NEW_NUMBER}. Allowlist now: {env['WA_ALLOW_FROM']}")
PYEOF
```

To remove a number, swap `if NEW_NUMBER not in existing: existing.append(NEW_NUMBER)` for `existing = [n for n in existing if n != NEW_NUMBER]`.

**Format rules** (validate before mutating):

- Phone numbers must be E.164 format: leading `+`, country code, no spaces, dashes, or brackets.
- The linked number is always allowed even if the list is empty.
- After editing, the user must restart Claude Code (close their `claude-wa` session and re-run `claude-wa` in a fresh terminal) for the change to take effect. Tell them in plain English: *"I've added that number. To pick up the change, close your WhatsApp Claude window and run `claude-wa` again in a fresh terminal."*

Never show the user the JSON. Never ask them to validate it.

### Safety rules

- **Never send unsolicited messages.** Only send when the user has explicitly asked, or in direct reply to an inbound message they asked you to handle.
- **Never DM a number that isn't on the allowlist**, even if the user asks. Push back: *"I can't message that number yet because it isn't on your allowlist. Want me to add it first?"*
- **Read before write** when handling a thread. Use `whatsapp_history` to pull the last few messages for context before replying, so you don't miss tone or open questions.
- **Permission prompts** from Claude Code tool approvals get forwarded to WhatsApp. If a user replies `yes <code>` or `no <code>` in a chat, treat that as the approval response and do not interpret it as conversation.

---

## Phone Fallback (degraded path)

If Step 7's `claude-wa` shortcut fails twice in a row (PATH not propagating despite the Step 5 rc append), fall back to having the user paste the long form once. **This is a degraded path, not the default.** Use it only when the autonomous shortcut path has failed twice.

Tell the user, in one short message: *"The shortcut isn't picking up. Just for this launch, please paste this exact line into your fresh terminal and press Enter:"*

Then send the appropriate one-line block for their shell, with `<WS_KIT>` substituted with the actual workshop-kit path resolved in Step 4:

**Mac / Linux (bash, zsh):**
```
cd <WS_KIT>/whatsapp-channel && WA_AUTO_OPEN_QR=1 claude --dangerously-load-development-channels server:whatsapp
```

**Windows (PowerShell):**
```
cd <WS_KIT>\whatsapp-channel; $env:WA_AUTO_OPEN_QR = "1"; claude --dangerously-load-development-channels server:whatsapp
```

After this works once, debug the PATH issue offline. The user shouldn't need to paste the long form a second time.

---

## Troubleshooting (Phase 1 and Phase 2)

| Symptom | What's going on | What you do |
|---|---|---|
| Listener not running after `claude-wa` (Step 8 finds zero processes) | Stale-environment terminal: Bun was installed in Step 3 but the host app wasn't fully restarted. Integrated terminals inherit the app's pre-Bun PATH. | Full host-app quit (Cmd+Q) and reopen. Step 3 was meant to prevent this; if it didn't take, recover here. |
| `claude-wa: command not found` in fresh terminal | `~/.local/bin/` not on PATH yet | Step 5's rc append should fix this on next terminal open. Use Phone Fallback for the immediate launch. |
| QR page never opens | Default browser not set on Windows, or `WA_AUTO_OPEN_QR` got stripped from `claude-wa` | Tell the user to open `http://127.0.0.1:8787` manually in any browser. |
| QR disappears before scanning | Pairing timed out (Baileys QRs expire ~60s) | Restart the listener: in their `claude-wa` terminal, Ctrl+C, then re-run `claude-wa`. A new QR appears. |
| Two listeners colliding | Step 6's pkill missed a stale process or a second `claude-wa` was started by accident | `pkill -9 -f "whatsapp-channel/src/index.ts"`, ask user to re-run `claude-wa`. Re-scan QR. |
| "Session expired" on reconnect | Phone was offline too long; WhatsApp invalidated the link | Silently delete `~/.claude/whatsapp-channel/auth/`, then run Phase 1 from Step 6. |
| Inbound messages not arriving | Sender isn't on the allowlist, or channel isn't running | Re-run Step 8's health check. If listener is up, check `WA_ALLOW_FROM` in `.mcp.json`; ask the user which number they sent from. |
| "blocked by org policy" | Team/Enterprise plan with channels disabled | Tell the user their workspace admin needs to enable development channels in Claude Code settings. |

For anything not covered here, if the Superpowers plugin is installed, invoke `superpowers:systematic-debugging` and diagnose silently before reporting back to the user in plain English. If it isn't installed, work through the failure step by step yourself: isolate what changed, form a hypothesis, verify before fixing, and summarise the outcome in plain English. Never paste a raw stack trace at the user either way.

---

## Reference — what lives where

- Channel source: `whatsapp-channel/` in the workshop-kit repo
- Channel config (allowlist + env): `whatsapp-channel/.mcp.json`
- Pairing credentials: `~/.claude/whatsapp-channel/auth/creds.json`
- On-demand message log: `~/.claude/whatsapp-channel/history.jsonl`
- Launch shortcut: `~/.local/bin/claude-wa` (Mac/Linux) or `%USERPROFILE%\.local\bin\claude-wa.cmd` (Windows)
