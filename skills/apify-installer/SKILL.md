---
name: apify-installer
description: "Connect Apify to Claude by installing and authenticating the apify CLI and its MCP client. Use when the user asks to set up Apify, or an apify-* scraping skill needs a token, and the apify CLI isn't signed in yet. Once connected, Apify work runs through the sibling apify-* skills and the apify CLI."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - apify
    - installer
    - cli
    - mcp-client
    - scraping
    - oauth-callback
  pairs-with:
    - skill: apify-competitor-intelligence
      reason: Sibling that calls this installer from its Step 0 if `~/.claude/apify.env` is missing
    - skill: apify-content-analytics
      reason: Same - Step 0 dispatch
    - skill: apify-market-research
      reason: Same - Step 0 dispatch
---

# Apify Installer

## Overview

This skill captures the user's Apify Personal API token and installs the two npm packages the workshop kit's three Apify skills depend on:

- **`apify-cli`** - the official Apify CLI (https://docs.apify.com/cli/docs/installation). Provides `apify login --method=console` which handles the entire OAuth-style callback authentication flow.
- **`@apify/mcpc`** - the Apify MCP client. The three apify-* skills use this at runtime to fetch Actor input schemas from `mcp.apify.com`.

Both packages are npm-published and install non-interactively.

**This skill uses a hybrid auth flow** - `apify login --method=console` is the primary path (Apify CLI's own localhost-callback OAuth flow against the user's default browser), with Playwright DOM extraction as a documented fallback when the primary path fails. Both paths converge on the same end-state (`~/.apify/auth.json` + `~/.claude/apify.env`, mode 600).

## Why this design (hybrid, not pure CLI-callback)

The first iteration of this design (PR #277) dropped Playwright entirely in favor of `apify login --method=console`. Sanity testing on a macOS-style default-browser environment passed in 75 seconds. Live screencast attempts on Linux Wayland surfaced two failure modes the original test missed:

1. **Wayland + xdg-open** - the CLI prints the URL but no browser opens. User often doesn't notice. CLI times out. No tokens minted.
2. **Mixed-content / private-network blocking** - when a hardened Chrome profile (notably, the Playwright-managed one) is the browser that processes the OAuth, Chrome refuses to POST from `https://console.apify.com` to `http://localhost:<port>` as a private-network request. User sees "Error: Could not send API token to CLI" banner. Apify server-side **still mints** a valid token named `"Apify CLI login for <hostname>"` that can be recovered.

Hybrid design properties:

1. **Primary path wins when it works.** Workshop attendees on macOS, Windows, working-xdg-open Linux all get the CLI's clean default-browser flow with full mixed-content compatibility (since they're using their real Chrome/Brave/Firefox profile, not a sandboxed one). ~75s end-to-end.
2. **Fallback wins when primary fails.** Wayland users without working xdg-open, container/CI environments without a default browser, and Playwright-controlled browser scenarios all recover cleanly via the DOM-extraction path.
3. **Detection is structural.** After 90s the primary path either succeeded (auth.json written) or it didn't. There's no ambiguous state. The fallback triggers automatically.
4. **Token leakage stays controlled.** Primary path: no argv, no env, no chat-visible transit. Fallback path: clipboard transit (wl-paste/xclip/pbpaste), variable wiped immediately after disk write. Either path's end-state file is mode 600.

The previous Playwright-only design (PR #273) and the Playwright-free design (PR #277) are preserved in git history for reference. This is the current production design.

## Communication rules

Standard CWK connector contract:

- **You drive, not them.** The only ask is "please sign in to Apify in the browser tab I just opened."
- **Plain English only.** No `mcpc`, no `apify-cli`, no `~/.claude/apify.env`, no `bash`, no `npm`, no `mode 600` in user-facing text. Say "the Apify helper tools" or "your Apify connection".
- **Narrate at action boundaries.** One sentence at start, one when you need them, one at done. Nothing in between.
- **React warmly to outcomes.** "All set - your Apify is ready." Not "POST /v2/users/me 200 OK".
- **Never echo the captured token.** Once it's written to disk (mode 600), it should not appear in any subsequent narration, tool-call return, or log line.

## Phase 0 - Resume check

```bash
if [ -f "$HOME/.claude/apify.env" ] && grep -q '^APIFY_TOKEN=apify_api_' "$HOME/.claude/apify.env" 2>/dev/null; then
  # Already installed. Smoke-test then exit success.
  if apify info >/dev/null 2>&1; then
    echo "READY"
  else
    echo "TOKEN_PRESENT_BUT_INVALID"
  fi
else
  echo "NOT_INSTALLED"
fi
```

Branch:

- `READY` → tell the user *"Your Apify is already connected. We're good to go."* Stop. Sibling skill that dispatched here can continue.
- `TOKEN_PRESENT_BUT_INVALID` → the env file has a token but `apify info` rejects it (revoked or expired). Skip Phase 1's npm install (CLI is likely already there), jump to Phase 2's re-auth, overwrite the env file.
- `NOT_INSTALLED` → run Phase 1.

## Phase 1 - Install both packages autonomously

Tell the user once: *"I'm installing the Apify helper tools - about 15 seconds."* Then proceed silently.

```bash
OS=$(uname -s)
case "$OS" in
  Darwin|Linux|MINGW*|CYGWIN*|MSYS*)
    if ! command -v npm >/dev/null 2>&1; then
      echo "MISSING_NPM"
    fi
    ;;
esac
```

If `MISSING_NPM`: tell the user *"I need Node.js installed first - that's a separate one-time thing. Node 22 or higher is required."* Stop; the user installs Node then restarts the skill. (Node 22+ is required per the Apify CLI docs.)

Otherwise install both packages in one shot:

```bash
npm install -g apify-cli @apify/mcpc 2>&1 | tail -3
APIFY_CLI_VERSION=$(apify --version 2>&1 | head -1)
MCPC_VERSION=$(mcpc --version 2>&1 | head -1)
echo "installed: apify-cli=$APIFY_CLI_VERSION mcpc=$MCPC_VERSION"
```

If either `--version` call fails: surface a plain-English error and stop. Most likely cause is a `PATH` issue with the npm global bin.

## Phase 2 - Hybrid auth: CLI callback first, Playwright fallback if it fails

### Step 2a - Primary path: `apify login --method=console`

Tell the user once:

> *"Now I'll connect your Apify account. A browser tab will open - sign in (or sign up) and click Authorize. Takes about 60 seconds."*

Spawn the login in the background. The CLI prints a URL to its log, opens the OS default browser, and listens on a random local port for the OAuth callback:

```bash
# CRITICAL: remove any pre-existing auth.json before starting login.
# Without this, a stale ~/.apify/auth.json from a previous `apify login`
# run will be misread by Phase 3 as "this run's token", silently
# propagating the OLD token to ~/.claude/apify.env.
rm -f "$HOME/.apify/auth.json"

# 90s timeout matches the empirical default-browser success window
# (verified 2026-05-29 - successful run completed in 75s end-to-end).
# Beyond 90s we activate the fallback rather than waiting indefinitely.
nohup timeout 90 apify login --method=console > /tmp/apify-login.log 2>&1 &
LOGIN_PID=$!
sleep 2

LOGIN_URL=$(grep -oE 'https://console.apify.com/settings/integrations\?localCliCommand=login[^"]*' /tmp/apify-login.log | head -1)
HOSTNAME=$(uname -n)
```

If `$LOGIN_URL` is empty, the CLI failed at startup - abort and report.

### Step 2b - Poll for completion or detect failure

```bash
for i in {1..18}; do  # 90s in 5s ticks
  if [ -f "$HOME/.apify/auth.json" ]; then
    OUTCOME="PRIMARY_OK"
    break
  fi
  if ! ps -p $LOGIN_PID >/dev/null 2>&1; then
    OUTCOME="CLI_EXITED_WITHOUT_AUTH"
    break
  fi
  sleep 5
done
[ -z "$OUTCOME" ] && OUTCOME="PRIMARY_TIMEOUT"
```

Branch on outcome:

- **`PRIMARY_OK`** - auth.json written by the CLI's callback. Skip to Phase 3.
- **`PRIMARY_TIMEOUT` or `CLI_EXITED_WITHOUT_AUTH`** - primary path failed. Continue to Step 2c (Playwright fallback). Kill the CLI process if still alive: `kill $LOGIN_PID 2>/dev/null`.

> **Why the primary path can fail silently.** Two known failure modes (verified 2026-05-29):
>
> 1. **Wayland / xdg-open** - CLI prints the URL but no browser actually opens. User often doesn't notice. No tokens minted, no callback fires.
> 2. **Browser blocks the callback** - Playwright-controlled Chrome (or some hardened user Chrome profiles) refuses to POST from `https://console.apify.com` to `http://localhost:<port>` as a mixed-content / private-network request. User sees "Error: Could not send API token to CLI" banner in the browser. Apify still server-side mints a token named `"Apify CLI login for <hostname>"` in the account - that token is fully valid and recoverable.
>
> The fallback handles both: it drives Playwright through sign-in if needed, then either uses any auto-minted token (case 2) or mints a fresh one via the "Create new token" UI (case 1).

### Step 2c - Playwright fallback (DOM extraction)

Tell the user once:

> *"The auto-flow didn't complete - switching to a backup route. Sign in if asked, then I'll capture the token myself."*

Open `https://console.apify.com/settings/integrations` in Playwright MCP (install Playwright MCP first if needed - see `skills/CLAUDE.md` "Playwright MCP install contingency").

Sign-in handling: snapshot the page. If a sign-in form is showing, narrate `"please sign in to Apify"` and `browser_wait_for` the integrations page to load (URL matches `/settings/integrations` without `/sign-in`).

Once on the integrations page, capture the token via DOM. The fallback prefers any auto-minted `"Apify CLI login for <hostname>"` token (from a failed Step 2a attempt against this same hostname) before minting a fresh one:

```javascript
// browser_evaluate against console.apify.com/settings/integrations
async () => {
  const HOSTNAME = '<HOSTNAME_FROM_BASH>';  // injected from the $HOSTNAME bash var
  const LABEL = `Apify CLI login for ${HOSTNAME}`;

  // Prefer existing auto-minted token (Apify mints these even when callback fails)
  const labels = Array.from(document.querySelectorAll('div')).filter(d =>
    d.textContent?.trim() === LABEL && d.children.length === 0
  );

  let row = null;
  if (labels.length > 0) {
    // Most recent is last in DOM order
    row = labels[labels.length - 1];
    while (row && !row.querySelector('code')) row = row.parentElement;
  }

  // No auto-minted token - mint a fresh one via "Create new token" UI
  if (!row) {
    const createBtn = Array.from(document.querySelectorAll('button')).find(b => b.textContent?.includes('Create a new token'));
    if (!createBtn) return { error: 'no Create-new-token button found' };
    createBtn.click();
    await new Promise(r => setTimeout(r, 600));

    const desc = document.querySelector('[data-test="token-description"]');
    if (!desc) return { error: 'token description input not found' };
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    setter.call(desc, `Claude Code agent (${new Date().toISOString().slice(0,10)})`);
    desc.dispatchEvent(new Event('input', { bubbles: true }));

    const submit = document.querySelector('[data-test="submit-button"]');
    submit.click();
    await new Promise(r => setTimeout(r, 1500));

    // After mint, the newly-created token row should be visible
    const newLabels = Array.from(document.querySelectorAll('div')).filter(d =>
      d.textContent?.trim()?.startsWith('Claude Code agent') && d.children.length === 0
    );
    if (newLabels.length === 0) return { error: 'minted token row not found' };
    row = newLabels[newLabels.length - 1];
    while (row && !row.querySelector('code')) row = row.parentElement;
  }

  if (!row) return { error: 'no usable token row' };

  // Reveal value (click eye/toggle button)
  const code = row.querySelector('code');
  let value = code.textContent?.trim() || '';
  if (value.startsWith('*')) {
    const buttons = Array.from(row.querySelectorAll('button'));
    const eye = buttons.find(b => !b.getAttribute('aria-label')?.includes('Copy') && b.textContent === '');
    if (eye) {
      eye.click();
      await new Promise(r => setTimeout(r, 400));
      value = code.textContent?.trim() || '';
    }
  }

  if (!value.startsWith('apify_api_')) return { error: 'value not revealed' };
  await navigator.clipboard.writeText(value);
  return { copied: true, length: value.length };
}
```

After clipboard transit, read it in Bash, validate the shape, write `~/.apify/auth.json` directly (since the CLI callback never wrote it):

```bash
APIFY_TOKEN=$(wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null)

if ! echo "$APIFY_TOKEN" | grep -qE '^apify_api_[A-Za-z0-9]{20,}$'; then
  echo "FALLBACK_TOKEN_SHAPE_INVALID"
  unset APIFY_TOKEN
  exit 1
fi

mkdir -p "$HOME/.apify"
umask 077
printf '{"token":"%s"}\n' "$APIFY_TOKEN" > "$HOME/.apify/auth.json"
chmod 600 "$HOME/.apify/auth.json"

# Wipe clipboard immediately
printf '' | wl-copy 2>/dev/null || printf '' | xclip -selection clipboard 2>/dev/null || printf '' | pbcopy 2>/dev/null
unset APIFY_TOKEN
```

Phase 3's `chmod` + env-file write then runs as usual. The end-state is identical to the primary path.

## Phase 3 - Harden the auth file and write the env file for the three sibling skills

Once `~/.apify/auth.json` exists, two operations are needed:

### Step 3a - Fix Apify CLI's insecure default file mode

Apify CLI writes `~/.apify/auth.json` at mode **644 (world-readable)** by default - any user on the system can `cat` it and read the token. This is an upstream Apify defect. We harden to mode 600 immediately:

```bash
chmod 600 "$HOME/.apify/auth.json"
echo "hardened: $(stat -c '%a' $HOME/.apify/auth.json)"
```

### Step 3b - Extract token, write `~/.claude/apify.env` for the sibling skills

The sibling skills read the token from `~/.claude/apify.env` via `node --env-file`. Write it now from auth.json's `.token` field (validated by jq), unquoted per the earlier-discovered regex-vs-quote mismatch:

```bash
mkdir -p "$HOME/.claude"
umask 077

# Extract token via jq (never let it touch a printed variable)
APIFY_TOKEN=$(jq -r '.token' "$HOME/.apify/auth.json")

# Validate shape
if ! echo "$APIFY_TOKEN" | grep -qE '^apify_api_[A-Za-z0-9]{20,}$'; then
  echo "TOKEN_SHAPE_INVALID"
  unset APIFY_TOKEN
  exit 1
fi

# Write env file UNQUOTED (must match the regex `^APIFY_TOKEN=apify_api_` in Phase 0 of this skill + Step 0 of the three sibling skills)
{
  echo "# Apify Installer - credentials captured $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Sourced by the three apify-* skills (competitor-intelligence,"
  echo "# content-analytics, market-research) via node --env-file."
  echo "# DO NOT commit. DO NOT share publicly."
  echo "APIFY_TOKEN=${APIFY_TOKEN}"
} > "$HOME/.claude/apify.env"
chmod 600 "$HOME/.claude/apify.env"

unset APIFY_TOKEN  # wipe from shell context
```

Both credential locations are now populated and hardened:

- `~/.claude/apify.env` - read by the three sibling skills' Step 2 / Step 4 via `node --env-file`
- `~/.apify/auth.json` - read by the native `apify` CLI for `apify run`, `apify push`, `apify call`, `apify info`, etc.

## Phase 4 - Smoke-test

```bash
INFO=$(apify info 2>&1 | head -3)
echo "$INFO"
if echo "$INFO" | grep -qE 'username:|userId:'; then
  echo "OK"
else
  echo "SMOKE_FAILED"
fi
```

If `OK`: tell the user once: *"All set - your Apify account is connected. The three Apify skills (competitor research, content analytics, market research) will work without any more setup."*

If `SMOKE_FAILED`: rare. Most common cause is a token-shape mismatch between `auth.json` and `apify.env`. Re-run from Phase 3b - the cure is a fresh env-file write.

## Token rotation

If the user later wants to rotate (token leak, scope change, joining a new workspace), they re-invoke this skill. Phase 0's resume check sees the existing env file but the resume-on-`TOKEN_PRESENT_BUT_INVALID` path overwrites it. They should also `apify logout` to clear `~/.apify/auth.json` and revoke the old token in `https://console.apify.com/settings/integrations` after the rotation completes.

## Troubleshooting

### "Browser tab didn't open" / "I'm on a headless server"

`apify login --method=console` calls `xdg-open` (Linux) or `open` (macOS) or `start` (Windows) to launch the user's default browser. On Wayland sessions, in containers, or on SSH-only servers, those commands may no-op silently. The fix is to manually paste the URL the CLI printed (visible in `/tmp/apify-login.log`) into any browser that can reach `console.apify.com` AND `localhost:<port>` on the user's machine - typically via SSH local port-forward on the relevant port:

```bash
# On the headless server, find the port the CLI is listening on:
ss -tlnp | grep mcpc-login || ss -tlnp | grep node

# On the user's laptop, SSH-forward that port:
ssh -L <port>:localhost:<port> user@server

# Then paste the URL the CLI printed into the laptop browser
```

### "I have a token already and want to use it manually"

Use `apify login --method=manual` (or `apify login -t <token>` for non-interactive, **but ONLY if you accept the argv-leak risk** - see the security note in the next section). The manual method prompts for a token at the terminal and stores it the same way.

### Token leaked via `ps aux` / `/proc/PID/cmdline` (argv exposure)

`apify login -t "$TOKEN"` puts the token on the command line where any user can `ps aux` and read it. This is why this SKILL uses `--method=console` (callback flow, no argv) instead. If you must use `-t` (e.g. inside a CI pipeline where the token is in a secrets store), wrap it so the token isn't on the same line as the command:

```bash
# Risky - token on argv:
apify login -t "$APIFY_TOKEN"

# Safer - pipe token via stdin, where /proc/PID/0 isn't world-readable:
echo "$APIFY_TOKEN" | apify login --method=manual --no-confirm 2>/dev/null
```

### `apify info` returns "You are not logged in"

`~/.apify/auth.json` is missing, empty, or has the wrong shape. Diagnose in order:

1. `cat ~/.apify/auth.json` - should print `{"token":"apify_api_...", ...other fields}`. If missing or empty, re-run Phase 2.
2. `stat -c '%a' ~/.apify/auth.json` - should be `600`. If `644`, Phase 3a's `chmod` didn't run; fix manually.
3. `jq -r '.token' ~/.apify/auth.json | head -c 14` - should print `apify_api_` + 4 more chars. If shorter, the file is corrupted; `rm ~/.apify/auth.json` and re-run.

### `mcpc` reports "Unknown command: mcp.apify.com"

mcpc 0.3.0+ uses a session-based syntax - `mcpc connect <server> @<session>` first, then `mcpc @<session> tools-call ...`. The three sibling SKILLs' Step 2 documents the current syntax. If you're following older docs that show `mcpc --json mcp.apify.com tools-call ...`, that's the pre-0.3.0 pattern and needs updating.

### Token leaked to chat by accident

If `apify_api_...` appears in any chat output, tool-call return, or screen recording:

1. **Immediately revoke.** Open `https://console.apify.com/settings/integrations`, click the leaked token → Delete → type `delete my token` in the confirmation dialog → click Delete. Confirm dead via `curl -H "Authorization: Bearer <leaked>" https://api.apify.com/v2/users/me` returning HTTP 401.
2. Re-run this skill from Phase 2 to mint a fresh token.
3. Save a memory entry noting how the leak happened so future sessions avoid the same path.

## What this SKILL does NOT cover

- **Apify account creation specifically.** `apify login --method=console` shows Apify Console's signup page if the user isn't signed in, so signup happens naturally in-flow - but this skill doesn't pre-fill name/email/etc. The user types those themselves.
- **Apify plan upgrade.** Most workshop work fits in the Free plan ($5/mo usage credits, ~1250 Google Maps places, generous proxy budget). If the user hits Actor-run limits, that's an upgrade conversation, not a setup issue.
- **Per-Actor authentication.** Some Actors require additional auth (e.g. a Facebook login cookie). Those are captured at run-time by the relevant sibling apify-* skill.

## See also

- [`apify-competitor-intelligence/SKILL.md`](../apify-competitor-intelligence/SKILL.md) - sibling that dispatches here
- [`apify-content-analytics/SKILL.md`](../apify-content-analytics/SKILL.md) - sibling that dispatches here
- [`apify-market-research/SKILL.md`](../apify-market-research/SKILL.md) - sibling that dispatches here
- [Apify CLI install docs](https://docs.apify.com/cli/docs/installation) - canonical install commands (`npm install -g apify-cli`, Node 22+)
- [Apify CLI quick-start](https://docs.apify.com/cli/docs/quick-start) - canonical post-install sequence; `apify login --method=console` is the recommended method-choice
- [Apify CLI reference](https://docs.apify.com/cli/docs/reference) - full command list (`apify info` is the auth-verify command; `apify whoami` does NOT exist in v1.6.1 despite older docs hinting at it)
- [`skills/CLAUDE.md`](../CLAUDE.md) - three connector patterns; this skill is "first-party stdio / out-of-pattern" - relies on Apify's own CLI's callback flow rather than the kit's three documented connector patterns
