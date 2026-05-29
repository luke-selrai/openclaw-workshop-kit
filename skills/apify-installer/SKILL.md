---
name: apify-installer
description: Autonomously install the Apify CLI + Apify MCP client and authenticate the user's Apify account via the CLI's built-in OAuth-style callback flow. Use this skill when the user says "set up Apify", "install Apify CLI", "connect my Apify account", "I need to use the Apify scraping skills", "apify-competitor-intelligence is asking me for a token", or when any sibling apify-* skill (apify-competitor-intelligence, apify-content-analytics, apify-market-research) detects that `~/.claude/apify.env` is missing and dispatches here. The skill drives the entire setup non-interactively from the user's perspective: installs `apify-cli` and `@apify/mcpc` via npm, runs `apify login --method=console` which opens the user's default browser to Apify Console where they sign up or sign in once, the CLI's local callback server receives the token automatically, the skill reads `~/.apify/auth.json` and writes `~/.claude/apify.env` for the three sibling skills, hardens permissions to mode 600, and smoke-tests via `apify info`. The only human moment is signing in to Apify once in their default browser.
allowed-tools: Bash, Read, Write, Edit
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
      reason: Same — Step 0 dispatch
    - skill: apify-market-research
      reason: Same — Step 0 dispatch
---

# Apify Installer

## Overview

This skill captures the user's Apify Personal API token and installs the two npm packages the workshop kit's three Apify skills depend on:

- **`apify-cli`** — the official Apify CLI (https://docs.apify.com/cli/docs/installation). Provides `apify login --method=console` which handles the entire OAuth-style callback authentication flow.
- **`@apify/mcpc`** — the Apify MCP client. The three apify-* skills use this at runtime to fetch Actor input schemas from `mcp.apify.com`.

Both packages are npm-published and install non-interactively.

**This skill uses `apify login --method=console` as the canonical auth path** — not a Playwright DOM-extraction flow. Apify CLI itself spins up a localhost HTTP server, opens the user's default browser to Apify Console (with a CSRF-protected callback URL), and receives the token via callback after the user signs in. The token never appears on a command line, never transits a Bash variable beyond the file-read step, and never requires Playwright to drive the browser.

## Why this design (replacing the Playwright DOM dance)

Earlier versions of this skill drove `console.apify.com/account/integrations` in Playwright to mint a named token. That worked but:

1. **Apify already has a proper CLI auth flow** (`apify login --method=console`) that handles browser opening + token capture itself. Re-implementing it in Playwright is over-engineering.
2. **The Playwright approach is fragile** — Apify Console UI redesigns break DOM selectors. The CLI's callback flow is a documented contract Apify maintains.
3. **The CLI flow uses the user's default browser** which has familiar sign-in state, password manager, etc. Workshop attendees aren't surprised by a new browser window controlled by the skill.
4. **Token leakage class is structurally eliminated** — the token transits CLI ↔ Apify ↔ localhost callback, never through argv, environment, or chat output.

The previous SKILL's Playwright approach is preserved at git history (PRs #266, #273, #276) for reference. This rewrite is the production design.

## Communication rules

Standard CWK connector contract:

- **You drive, not them.** The only ask is "please sign in to Apify in the browser tab I just opened."
- **Plain English only.** No `mcpc`, no `apify-cli`, no `~/.claude/apify.env`, no `bash`, no `npm`, no `mode 600` in user-facing text. Say "the Apify helper tools" or "your Apify connection".
- **Narrate at action boundaries.** One sentence at start, one when you need them, one at done. Nothing in between.
- **React warmly to outcomes.** "All set — your Apify is ready." Not "POST /v2/users/me 200 OK".
- **Never echo the captured token.** Once it's written to disk (mode 600), it should not appear in any subsequent narration, tool-call return, or log line.

## Phase 0 — Resume check

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

## Phase 1 — Install both packages autonomously

Tell the user once: *"I'm installing the Apify helper tools — about 15 seconds."* Then proceed silently.

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

If `MISSING_NPM`: tell the user *"I need Node.js installed first — that's a separate one-time thing. Node 22 or higher is required."* Stop; the user installs Node then restarts the skill. (Node 22+ is required per the Apify CLI docs.)

Otherwise install both packages in one shot:

```bash
npm install -g apify-cli @apify/mcpc 2>&1 | tail -3
APIFY_CLI_VERSION=$(apify --version 2>&1 | head -1)
MCPC_VERSION=$(mcpc --version 2>&1 | head -1)
echo "installed: apify-cli=$APIFY_CLI_VERSION mcpc=$MCPC_VERSION"
```

If either `--version` call fails: surface a plain-English error and stop. Most likely cause is a `PATH` issue with the npm global bin.

## Phase 2 — Run `apify login --method=console` and let the CLI handle the browser

Tell the user once:

> *"Now I'll connect your Apify account. A browser tab will open — sign up to Apify (or sign in if you already have an account) and click Authorize. Takes about 60 seconds."*

Spawn the login in the background with a 5-minute timeout. The CLI prints a URL to its log, opens the OS default browser, and listens on a random local port for the OAuth callback:

```bash
# CRITICAL: remove any pre-existing auth.json before starting login.
# Without this, a stale ~/.apify/auth.json from a previous `apify login`
# run will be misread by Phase 3 as "this run's token", silently
# propagating the OLD token to ~/.claude/apify.env. The Phase 2 polling
# loop below races against the existence of auth.json — it cannot
# distinguish "fresh-from-this-run" from "left over from last time"
# without this rm.
rm -f "$HOME/.apify/auth.json"

nohup timeout 300 apify login --method=console > /tmp/apify-login.log 2>&1 &
LOGIN_PID=$!
sleep 2

# Sanity-check the CLI actually printed the login URL
LOGIN_URL=$(grep -oE 'https://console.apify.com/settings/integrations\?localCliCommand=login[^"]*' /tmp/apify-login.log | head -1)
if [ -z "$LOGIN_URL" ]; then
  echo "LOGIN_URL_NOT_PRINTED"
  # Fall back to telling the user to run `apify login` manually
fi
```

If `LOGIN_URL` was captured but the OS default browser didn't auto-open (this happens on Wayland sessions without `xdg-open`, or in containers), tell the user the URL and ask them to paste it into their browser:

> *"If a browser tab didn't auto-open, paste this into your browser: `$LOGIN_URL`"*

> **Why we don't use Playwright here.** Apify's CLI manages the browser open + callback receive itself. Driving it from Playwright would just duplicate what the CLI already does, while adding a brittle DOM-selector dependency on Apify Console's UI. The user's default browser is the right tool: familiar UX, persistent state (so re-sign-in is fast), real password manager.

### Poll for completion

The CLI writes `~/.apify/auth.json` once the OAuth callback completes. Poll for that file's existence (or the login process exiting, in case of error):

```bash
for i in {1..60}; do  # 5 minutes max
  if [ -f "$HOME/.apify/auth.json" ]; then
    echo "AUTH_FILE_APPEARED"
    break
  fi
  if ! ps -p $LOGIN_PID >/dev/null 2>&1; then
    echo "LOGIN_EXITED"
    break
  fi
  sleep 5
done
```

If `LOGIN_EXITED` without `AUTH_FILE_APPEARED`, read `/tmp/apify-login.log` for the error message. Common cases:

- Browser tab was closed before authorize → user re-runs the skill
- Network error reaching `mcp.apify.com` callback → check connection
- User abandoned the flow → no harm, just re-run

## Phase 3 — Harden the auth file and write the env file for the three sibling skills

Once `~/.apify/auth.json` exists, two operations are needed:

### Step 3a — Fix Apify CLI's insecure default file mode

Apify CLI writes `~/.apify/auth.json` at mode **644 (world-readable)** by default — any user on the system can `cat` it and read the token. This is an upstream Apify defect. We harden to mode 600 immediately:

```bash
chmod 600 "$HOME/.apify/auth.json"
echo "hardened: $(stat -c '%a' $HOME/.apify/auth.json)"
```

### Step 3b — Extract token, write `~/.claude/apify.env` for the sibling skills

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
  echo "# Apify Installer — credentials captured $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# Sourced by the three apify-* skills (competitor-intelligence,"
  echo "# content-analytics, market-research) via node --env-file."
  echo "# DO NOT commit. DO NOT share publicly."
  echo "APIFY_TOKEN=${APIFY_TOKEN}"
} > "$HOME/.claude/apify.env"
chmod 600 "$HOME/.claude/apify.env"

unset APIFY_TOKEN  # wipe from shell context
```

Both credential locations are now populated and hardened:

- `~/.claude/apify.env` — read by the three sibling skills' Step 2 / Step 4 via `node --env-file`
- `~/.apify/auth.json` — read by the native `apify` CLI for `apify run`, `apify push`, `apify call`, `apify info`, etc.

## Phase 4 — Smoke-test

```bash
INFO=$(apify info 2>&1 | head -3)
echo "$INFO"
if echo "$INFO" | grep -qE 'username:|userId:'; then
  echo "OK"
else
  echo "SMOKE_FAILED"
fi
```

If `OK`: tell the user once: *"All set — your Apify account is connected. The three Apify skills (competitor research, content analytics, market research) will work without any more setup."*

If `SMOKE_FAILED`: rare. Most common cause is a token-shape mismatch between `auth.json` and `apify.env`. Re-run from Phase 3b — the cure is a fresh env-file write.

## Token rotation

If the user later wants to rotate (token leak, scope change, joining a new workspace), they re-invoke this skill. Phase 0's resume check sees the existing env file but the resume-on-`TOKEN_PRESENT_BUT_INVALID` path overwrites it. They should also `apify logout` to clear `~/.apify/auth.json` and revoke the old token in `https://console.apify.com/settings/integrations` after the rotation completes.

## Troubleshooting

### "Browser tab didn't open" / "I'm on a headless server"

`apify login --method=console` calls `xdg-open` (Linux) or `open` (macOS) or `start` (Windows) to launch the user's default browser. On Wayland sessions, in containers, or on SSH-only servers, those commands may no-op silently. The fix is to manually paste the URL the CLI printed (visible in `/tmp/apify-login.log`) into any browser that can reach `console.apify.com` AND `localhost:<port>` on the user's machine — typically via SSH local port-forward on the relevant port:

```bash
# On the headless server, find the port the CLI is listening on:
ss -tlnp | grep mcpc-login || ss -tlnp | grep node

# On the user's laptop, SSH-forward that port:
ssh -L <port>:localhost:<port> user@server

# Then paste the URL the CLI printed into the laptop browser
```

### "I have a token already and want to use it manually"

Use `apify login --method=manual` (or `apify login -t <token>` for non-interactive, **but ONLY if you accept the argv-leak risk** — see the security note in the next section). The manual method prompts for a token at the terminal and stores it the same way.

### Token leaked via `ps aux` / `/proc/PID/cmdline` (argv exposure)

`apify login -t "$TOKEN"` puts the token on the command line where any user can `ps aux` and read it. This is why this SKILL uses `--method=console` (callback flow, no argv) instead. If you must use `-t` (e.g. inside a CI pipeline where the token is in a secrets store), wrap it so the token isn't on the same line as the command:

```bash
# Risky — token on argv:
apify login -t "$APIFY_TOKEN"

# Safer — pipe token via stdin, where /proc/PID/0 isn't world-readable:
echo "$APIFY_TOKEN" | apify login --method=manual --no-confirm 2>/dev/null
```

### `apify info` returns "You are not logged in"

`~/.apify/auth.json` is missing, empty, or has the wrong shape. Diagnose in order:

1. `cat ~/.apify/auth.json` — should print `{"token":"apify_api_...", ...other fields}`. If missing or empty, re-run Phase 2.
2. `stat -c '%a' ~/.apify/auth.json` — should be `600`. If `644`, Phase 3a's `chmod` didn't run; fix manually.
3. `jq -r '.token' ~/.apify/auth.json | head -c 14` — should print `apify_api_` + 4 more chars. If shorter, the file is corrupted; `rm ~/.apify/auth.json` and re-run.

### `mcpc` reports "Unknown command: mcp.apify.com"

mcpc 0.3.0+ uses a session-based syntax — `mcpc connect <server> @<session>` first, then `mcpc @<session> tools-call ...`. The three sibling SKILLs' Step 2 documents the current syntax. If you're following older docs that show `mcpc --json mcp.apify.com tools-call ...`, that's the pre-0.3.0 pattern and needs updating.

### Token leaked to chat by accident

If `apify_api_...` appears in any chat output, tool-call return, or screen recording:

1. **Immediately revoke.** Open `https://console.apify.com/settings/integrations`, click the leaked token → Delete → type `delete my token` in the confirmation dialog → click Delete. Confirm dead via `curl -H "Authorization: Bearer <leaked>" https://api.apify.com/v2/users/me` returning HTTP 401.
2. Re-run this skill from Phase 2 to mint a fresh token.
3. Save a memory entry noting how the leak happened so future sessions avoid the same path.

## What this SKILL does NOT cover

- **Apify account creation specifically.** `apify login --method=console` shows Apify Console's signup page if the user isn't signed in, so signup happens naturally in-flow — but this skill doesn't pre-fill name/email/etc. The user types those themselves.
- **Apify plan upgrade.** Most workshop work fits in the Free plan ($5/mo usage credits, ~1250 Google Maps places, generous proxy budget). If the user hits Actor-run limits, that's an upgrade conversation, not a setup issue.
- **Per-Actor authentication.** Some Actors require additional auth (e.g. a Facebook login cookie). Those are captured at run-time by the relevant sibling apify-* skill.

## See also

- [`apify-competitor-intelligence/SKILL.md`](../apify-competitor-intelligence/SKILL.md) — sibling that dispatches here
- [`apify-content-analytics/SKILL.md`](../apify-content-analytics/SKILL.md) — sibling that dispatches here
- [`apify-market-research/SKILL.md`](../apify-market-research/SKILL.md) — sibling that dispatches here
- [Apify CLI install docs](https://docs.apify.com/cli/docs/installation) — canonical install commands (`npm install -g apify-cli`, Node 22+)
- [Apify CLI quick-start](https://docs.apify.com/cli/docs/quick-start) — canonical post-install sequence; `apify login --method=console` is the recommended method-choice
- [Apify CLI reference](https://docs.apify.com/cli/docs/reference) — full command list (`apify info` is the auth-verify command; `apify whoami` does NOT exist in v1.6.1 despite older docs hinting at it)
- [`skills/CLAUDE.md`](../CLAUDE.md) — three connector patterns; this skill is "first-party stdio / out-of-pattern" — relies on Apify's own CLI's callback flow rather than the kit's three documented connector patterns
