# Worked example: pair a phone with desktop Claude Code via Cowork

A reference end-to-end session for setting up Claude Dispatch (phone-to-desktop task delegation through Cowork). **You:** is the user, **Claude:** is the response.

The skill's job is to walk a non-technical owner through the QR-scan pairing, security review, and first dispatched task. Cold-start timing: ~3 minutes including the phone-side install.

---

## You

set up Claude Dispatch so I can fire off tasks from my phone

## Claude

I'll walk you through this. Two paths and we pick the right one for you.

> [Probe] Reads `~/.claude.json` for an existing `cowork` MCP entry. Reads `claude config get device-name` to check the desktop device name. No existing pairing detected. Selects fresh-pairing path.

**Path A: Claude Dispatch (recommended for you).** You dispatch a task from your phone, Claude Code runs it on this desktop in the background, then your phone gets a push notification with the result. You don't watch a live terminal session on your phone.

**Path B: Claude Remote Control.** You drive a live Claude Code session on this desktop from your phone, like SSH'ing in. Heavier, useful when you need to steer mid-task.

For "fire off tasks from your phone" Path A is what you want. Going there.

---

### Step 1: Install the Cowork app on your phone

> [Narrate] Walks the user to the App Store / Play Store search.

Open the App Store or Play Store, search for **Cowork**, install it. Tell me when you have it open.

---

### Step 2: Generate a pairing QR on this desktop

> [Tool] `Bash: claude dispatch pair --device-name "Luke MBP" --output qr` opens a QR code in a Quick Look window. Output also logged to `~/.claude/dispatch-pair.png` for fallback.

A QR code just opened on your desktop. In the Cowork app on your phone:

1. Tap the **+** at the top right.
2. Tap **Pair with desktop**.
3. Point your phone at the QR code on screen.

When the phone shows "Paired with Luke MBP", tell me.

---

### Step 3: Security review

> [Narrate] Reads the Cowork pairing manifest at `~/.claude/dispatch-pair.json`. Confirms the pairing scope is `dispatch-only` (no shell escape, no arbitrary file writes outside `~/`).

You're paired. The phone can now dispatch Claude Code tasks to this desktop. What it can NOT do:

- Run arbitrary shell commands outside the Claude Code sandbox
- Write files outside your home directory
- Access keychain / Keeper directly
- Run when this desktop is asleep or offline

If you ever want to unpair, say "unpair Claude Dispatch" and I'll revoke the device key. Or you can revoke from the Cowork app's Settings → Paired Devices → Remove.

---

### Step 4: Dispatch a test task

Open the Cowork app, type a task in the dispatch field. Try this one to verify everything's working:

```
list the 5 most recent emails in my Gmail and summarise them
```

Hit send. The dispatch will:

1. Land on this desktop as a background Claude Code session.
2. Run for ~30-60 seconds.
3. Push the result back to your phone as a notification you can tap to read in full.

Tell me when the notification arrives.

---

### Step 5: Confirm + close

> [Verify] Polls `~/.claude/dispatch-history.jsonl` for the latest dispatch entry. Confirms `status: completed` and a `result_artifact` path.

You should see "Gmail summary" in your phone notifications now. Tap it to read the full result.

Dispatch is wired. From now on:

- Fire any task from your phone, Cowork → desktop → result back on phone.
- Long tasks (30+ min) are fine, the dispatch holds open.
- You can dispatch multiple in parallel, they queue.
- Results stay in Cowork's history; full conversation logs stay on this desktop at `~/.claude/dispatch-history/`.

If a dispatch hangs or fails, say "what's stuck in dispatch" and I'll surface the queue + tail the failing session's logs.

---

## Failure branch: Cowork can't reach the desktop

Common cause: the desktop's Tailscale or Cowork relay isn't running. The phone shows "Cannot reach Luke MBP".

> [Diagnose] `Bash: ps -ef | grep cowork-relay` confirms relay process. `tailscale status` confirms network.

If the relay is dead, I restart it via `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.cowork.relay.plist` and tell you when it's back up. You don't have to touch a terminal.

---

## What this transcript proves

- The 5-step setup is concrete: install, QR pair, security-review the manifest, fire a test dispatch, confirm.
- The Path A vs Path B decision is documented so the user picks the right one (most workshop owners want A).
- The security boundary (sandboxed, sleep-safe, revocable) is named explicitly so the non-technical owner doesn't panic.
- The failure mode (Cowork can't reach desktop) has a concrete diagnosis + recovery path that doesn't require the user to type a command.
- The dispatch test ("list the 5 most recent emails") gives an outsider a 60-second smoke check they can replicate.

The session above was captured against a real desktop + phone pairing in May 2026, anonymised, and trimmed for length.
