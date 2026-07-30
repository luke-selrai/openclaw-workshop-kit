---
name: playwright-parallel-session
description: "Recovers a Playwright profile-lock failure by cloning the browser profile into a parallel Playwright server, logins intact. Use when Playwright will not start because the user data directory is already in use, or a second chat needs its own browser."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Browser Automation
  tags:
    - playwright
    - mcp
    - recovery
    - multi-session
  pairs-with:
    - skill: first-run-setup
      reason: First-run-setup registers the canonical `playwright` MCP server; this skill registers parallel variants on demand.
---

# playwright-parallel-session

When the user has two or more Claude Desktop chats running and both want to use Playwright, the second one fails because Chromium locks `$HOME/.cache/playwright-mcp-profile` at the OS level. The visible symptom is a Playwright launch failure reading `user data directory is already in use`. The holder of the canonical profile is usually another Claude Desktop chat, but it can equally be a background `/loop` or `/schedule` task running Playwright inside one. This skill resolves the lock without forcing the user to close anything and without sacrificing the persistent logins that make Playwright usable in the first place.

The high-level flow: detect the lock → pick the lowest-numbered free slot (`-2` up to `-5`) → clone the canonical profile into it (skipping the lock files and the disposable Chromium caches) → register a `playwright_N` MCP variant pointing at the clone → ask the user to restart Claude Desktop → verify the new `mcp__playwright_N__*` tool surface → continue the session.

Maximum of 5 parallel sessions (canonical + 4 alts). If all slots are in use, tell the user clearly which slots are busy and let them choose: close one of the other chats, or wait.

## Voice

Plain English. This skill runs unannounced from the user's perspective until you hit the restart step - narrate the restart the same way the kit narrates every other MCP-add restart. Never echo any path or command in a way that reads as jargon. The user does not need to know about Chromium profile directories; what they need to know is "I'm setting up a second Playwright window for this chat - one moment."

## Phase 0 - Detect lock state

Goal: confirm that the lock is real and identify which slot to use.

1. List the existing profile directories:

   - Mac/Linux: `ls -d $HOME/.cache/playwright-mcp-profile* 2>/dev/null`
   - Windows (PowerShell): `Get-ChildItem -Path $env:USERPROFILE\.cache -Filter "playwright-mcp-profile*" -Directory`

2. For each directory, check whether its `SingletonLock` file exists and points to a live process:

   - Mac/Linux: `[ -f "$DIR/SingletonLock" ] && readlink "$DIR/SingletonLock"` returns `HOSTNAME-PID` shape; `kill -0 PID 2>/dev/null` confirms the process is alive. If the symlink exists but the PID is gone, the lock is stale - that slot is free.
   - Windows: PowerShell `Test-Path "$DIR\SingletonLock"`; check the lock-owner PID against `Get-Process` for a live match.

3. Pick the **lowest-numbered free slot** as the target - if `-2` is stale or absent, use `-2`. If `-2` is live and `-3` is free, use `-3`. Cap at `-5`.

4. If every slot from canonical through `-5` is held by a live process, abort with this user-visible narration:
   > "Five Claude Desktop chats are already using Playwright. Close one of the other chats or wait for it to finish, then ask me to try again."

   Do NOT fall back to a different browser tool. Do NOT spawn a `--isolated` Playwright. The "Browser Automation" rule in the workspace CLAUDE.md is binding here.

## Phase 1 - Clone the canonical profile

Goal: copy the canonical `playwright-mcp-profile` into the target slot, skipping anything that would either fight the live lock or bloat the copy.

The slot path is `$HOME/.cache/playwright-mcp-profile-N` (or `%USERPROFILE%\.cache\playwright-mcp-profile-N` on Windows) where N is the slot number from Phase 0.

Exclude these from the copy - they are either disposable Chromium caches that will rebuild themselves on next launch, or live lock files that would corrupt the destination:
- `Default/Cache/`
- `Default/Code Cache/`
- `Default/GPUCache/`
- `Default/Service Worker/CacheStorage/`
- `Default/Service Worker/ScriptCache/`
- `SingletonLock`
- `SingletonCookie`
- `SingletonSocket`
- `lockfile`

Files to preserve (these carry the user's logins - the whole point of this skill):
- `Default/Cookies`
- `Default/Cookies-journal`
- `Default/Login Data`
- `Default/Local Storage/`
- `Default/Session Storage/`
- `Default/IndexedDB/`
- `Default/Local State`
- `Default/Preferences`
- `Default/Web Data`

Commands:

- Mac/Linux (uses `rsync` so the exclude list is honoured cleanly):

  ```
  rsync -a \
    --exclude='Default/Cache/' \
    --exclude='Default/Code Cache/' \
    --exclude='Default/GPUCache/' \
    --exclude='Default/Service Worker/CacheStorage/' \
    --exclude='Default/Service Worker/ScriptCache/' \
    --exclude='SingletonLock' \
    --exclude='SingletonCookie' \
    --exclude='SingletonSocket' \
    --exclude='lockfile' \
    "$HOME/.cache/playwright-mcp-profile/" \
    "$HOME/.cache/playwright-mcp-profile-N/"
  ```

- Windows (PowerShell, `robocopy` with explicit excludes):

  ```
  robocopy "$env:USERPROFILE\.cache\playwright-mcp-profile" "$env:USERPROFILE\.cache\playwright-mcp-profile-N" /E `
    /XD "Default\Cache" "Default\Code Cache" "Default\GPUCache" "Default\Service Worker\CacheStorage" "Default\Service Worker\ScriptCache" `
    /XF SingletonLock SingletonCookie SingletonSocket lockfile
  ```

Verification after the clone:

1. `du -sh $HOME/.cache/playwright-mcp-profile-N` should be on the order of 1-50MB (not hundreds of MB - that means cache excludes did not take). If it is over 100MB, something is wrong; abort and report.
2. The destination must NOT contain `SingletonLock` - confirm absence.
3. `Default/Cookies` must exist in the destination.

If verification fails, delete the partial clone and abort with a clear user-facing message - do not proceed to Phase 2 with a corrupt profile.

## Phase 2 - Register the new MCP server

Goal: tell Claude Desktop about the new `playwright_N` MCP server so the next session sees it.

Use the same registration shape the kit uses for the canonical Playwright (see the "Browser Automation" section of `~/Desktop/my-assistant/CLAUDE.md` for the canonical command). The only differences are the server name and the `--user-data-dir` path:

- Mac/Linux:

  ```
  claude mcp add playwright_N --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile-N"
  ```

- Windows: same command; `$HOME` resolves in PowerShell 6+ and Git Bash.

Replace `N` with the slot number chosen in Phase 0 - `playwright_2`, `playwright_3`, etc. The underscore is intentional: MCP tool prefixes are derived from the server name, so `playwright_2` becomes `mcp__playwright_2__browser_navigate` (etc.) - predictable and pattern-compatible with how the existing Playwright tools are named.

Verify the entry landed in `~/.claude.json`:

- Mac/Linux: `python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude.json'))); print('playwright_N' in d.get('mcpServers',{}))"` should print `True`.
- Windows: equivalent PowerShell one-liner reading `$env:USERPROFILE\.claude.json`.

If the entry is missing, retry the `claude mcp add` once. If it still fails, fall back to writing the entry directly into `~/.claude.json` under `mcpServers.playwright_N` - see the "Direct-config fallback" pattern in `skills/CLAUDE.md` Pattern 2 for the exact JSON shape.

## Phase 3 - Restart Claude Desktop

Goal: get the new MCP server visible to the runtime by following the kit's standard restart pattern.

Narrate to the user something like:

> "I've set up a second Playwright window for this chat. To make it visible, fully quit and reopen Claude Desktop - that's a one-time step. Closing this window won't be enough; the app keeps running in the background."

Then give the platform-specific instructions verbatim:

- **Mac:** "Press **Command + Q** to fully quit Claude Desktop. Clicking the red close button on the window just closes the window - the app keeps running. After Cmd+Q, click the Claude Desktop icon in your dock to reopen it."
- **Windows:** "In the system tray (bottom-right of your screen, near the clock - you may need to click the small up-arrow to see hidden icons), right-click the Claude Desktop icon and choose **Quit Claude Desktop**. Closing the chat window leaves the app running. Then double-click the Claude Desktop shortcut to reopen it."

Ask the user to type `ready` when they are back.

## Phase 4 - Verify the variant is live and use it

Goal: confirm the new tool surface exists and run one smoke call against it before declaring the recovery complete.

1. After the user says `ready`, list the deferred MCP tools available in this session. The set should include `mcp__playwright_N__*` entries (`browser_navigate`, `browser_snapshot`, etc.).

2. Run a single smoke call:

   ```
   mcp__playwright_N__browser_navigate(url: "about:blank")
   mcp__playwright_N__browser_snapshot()
   ```

   Both should succeed without a profile-lock error. The snapshot should show a blank page.

3. If both succeed, narrate:

   > "Done. This chat now has its own Playwright window with all your existing logins. Whatever you wanted to do - let's continue."

   Then return control to the original task that triggered this skill.

If the smoke calls fail with a lock error, the canonical profile's lock did not release in time, or the clone collided with another session that started in parallel. Repeat Phase 0 from the top, choosing a fresh slot.

## Cleanup (manual for now)

Slots are not garbage-collected automatically by this skill. Over time, an inactive user may accumulate clones from earlier sessions. To clean up:

- Mac/Linux: `rm -rf $HOME/.cache/playwright-mcp-profile-N` for any slot that is no longer needed, then `claude mcp remove playwright_N --scope user`.
- Windows: `Remove-Item -Recurse -Force $env:USERPROFILE\.cache\playwright-mcp-profile-N` plus `claude mcp remove playwright_N --scope user`.

Run cleanup only after confirming the slot is not actively held by any running Claude Desktop chat (Phase 0 detection logic, in reverse - if `SingletonLock` is live, do NOT delete).

A future iteration may add automated cleanup at session start; this skill explicitly does not include it.
