---
name: apify-installer
description: Autonomously install the Apify CLI + Apify MCP client and capture the user's Personal API token via Playwright. Use this skill when the user says "set up Apify", "install Apify CLI", "connect my Apify account", "I need to use the Apify scraping skills", "apify-competitor-intelligence is asking me for a token", or when any sibling apify-* skill (apify-competitor-intelligence, apify-content-analytics, apify-market-research) detects that `~/.claude/apify.env` is missing and dispatches here. The skill drives the entire setup autonomously: installs `apify-cli` and `@apify/mcpc` via npm, opens `console.apify.com/account/integrations` in a Playwright MCP browser, asks the user to sign in once, navigates to Personal API tokens, creates a new one named "Claude Code agent", reads the token from the DOM, writes `~/.claude/apify.env` (mode 600), writes `~/.apify/auth.json` directly so the native CLI is also authenticated (without `apify login -t` which leaks the token via argv), and smoke-tests via `apify whoami`. The only human moment is signing in to Apify once.
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - apify
    - installer
    - cli
    - mcp-client
    - scraping
    - token-mint
    - playwright
  pairs-with:
    - skill: apify-competitor-intelligence
      reason: Sibling that calls this installer from its Step 0 if `~/.claude/apify.env` is missing
    - skill: apify-content-analytics
      reason: Same — Step 0 dispatch
    - skill: apify-market-research
      reason: Same — Step 0 dispatch
    - skill: monday-connector
      reason: Reference for the Pattern 2 Hosted-bearer-PAT token-mint sub-flow (DOM read of a revealed bearer token), although this skill stores the token in a plain env file rather than `~/.claude.json` because the three downstream Apify skills consume it via `node --env-file`, not via an MCP server entry
    - skill: airtable-connector
      reason: Same Pattern 2 reference; uses `airtable.com/create/tokens` deep-link the same way this skill uses `console.apify.com/account/integrations`
---

# Apify Installer

## Overview

This skill captures the user's Apify Personal API token and installs the two npm packages the workshop kit's three Apify skills depend on:

- **`apify-cli`** — the official Apify CLI (https://docs.apify.com/cli/docs/installation). Provides `apify login` + token storage at `~/.apify/auth.json` for any future native CLI work the user wants to do.
- **`@apify/mcpc`** — the Apify MCP client. The three apify-* skills use this at runtime to fetch Actor input schemas from `mcp.apify.com`.

Both packages are npm-published and install non-interactively. The only human moment in the entire flow is signing in to `apify.com` once in the Playwright browser. Token capture, CLI install, env-file write, and CLI login are all autonomous.

> **Why a single installer for three skills.** The three apify-* skills (competitor-intelligence, content-analytics, market-research) all consume the same token and the same CLI. Per the kit's dispatch-architecture pattern (see `feedback_dispatch_architecture` memory), the install logic lives in one skill that the three siblings dispatch to from their Step 0. This matches the medusa-connector → railway-deployment / cloudflare-deployment / deploy-to-vercel pattern.

## Communication rules

Standard CWK connector contract:

- **You drive, not them.** Never ask the user to click menus, copy tokens, or paste anything. The only ask is "please sign in to Apify in the window I just opened."
- **Plain English only.** No jargon — "Apify scraping helper", not "Apify Actor MCP client". No `mcpc`, no `apify-cli`, no `~/.claude/apify.env`, no `bash`, no `npm` in user-facing text.
- **Narrate at action boundaries.** One sentence when you start, one when you need them, one when you're done. Nothing in between.
- **React warmly to outcomes.** "All set — your Apify is ready." Not "POST /v2/users/me 200 OK".
- **Never echo the captured token.** Once it's written to `~/.claude/apify.env` (mode 600), it should not appear in any subsequent narration, tool-call return, or log line. The user's clipboard is wiped after the Playwright capture too.

## Phase 0 — Resume check

```bash
if [ -f "$HOME/.claude/apify.env" ] && grep -q '^APIFY_TOKEN=apify_api_' "$HOME/.claude/apify.env" 2>/dev/null; then
  # Already installed. Smoke-test then exit success.
  source "$HOME/.claude/apify.env"
  if apify whoami >/dev/null 2>&1; then
    echo "READY"
  else
    echo "TOKEN_PRESENT_BUT_INVALID"
  fi
else
  echo "NOT_INSTALLED"
fi
```

Branch:

- `READY` → tell the user once *"Your Apify is already connected. We're good to go."* Stop. Sibling skill that dispatched here can continue.
- `TOKEN_PRESENT_BUT_INVALID` → the env file has a token but it's been revoked or expired. Skip Phase 1's npm install (CLI is likely already there), jump to Phase 2's token re-capture, overwrite the env file.
- `NOT_INSTALLED` → run Phase 1.

## Phase 1 — Install both packages autonomously

Tell the user once: *"I'm installing the Apify helper tools — about 30 seconds."* Then proceed silently.

Detect OS, pick the right package manager:

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

If `MISSING_NPM`: tell the user *"I need Node.js installed first — that's a separate one-time thing. Want me to open the Node.js installer page in your browser?"* Open https://nodejs.org/en/download in Playwright and stop; the user installs Node then restarts the skill. (Node 22+ is required per the Apify CLI docs.)

Otherwise install both packages in one shot:

```bash
npm install -g apify-cli @apify/mcpc 2>&1 | tail -10
APIFY_CLI_VERSION=$(apify --version 2>&1 | head -1)
MCPC_VERSION=$(mcpc --version 2>&1 | head -1)
echo "installed: apify-cli=$APIFY_CLI_VERSION mcpc=$MCPC_VERSION"
```

If either `--version` call fails: surface a plain-English error to the user and stop. Most likely cause is a `PATH` issue with the npm global bin — solvable but out of this skill's autonomous scope.

## Phase 2 — Open the token mint page in Playwright

Playwright MCP install contingency: if `mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` tools are unreachable, install Playwright first per `skills/CLAUDE.md`'s "Playwright MCP install contingency" section.

Open `https://console.apify.com/account/integrations` in Playwright. Take a snapshot.

> **UI drift caveat.** Apify Console has two known URL shapes: `https://console.apify.com/account/integrations` (current path-routed) and `https://console.apify.com/account#/integrations` (older hash-routed). If the first redirects to login, that's fine — sign-in handling is below. If the page loads but doesn't show a "Personal API tokens" section, try `https://console.apify.com/settings/integrations` as a fallback.

### Sign-in (only if signed out)

Snapshot the page. If a login form is visible (email/password field, "Sign in" button, or a "Continue with Google/GitHub" button cluster), tell the user once:

> *"I've opened your Apify account in a browser. Please sign in — I'll take it from there."*

Poll snapshots every 3 seconds until the URL changes to one of:
- `console.apify.com/account/integrations` (success — already on the right page)
- `console.apify.com/dashboard` or similar account-internal page (signed in but redirected; navigate back to `/account/integrations`)

If after 5 minutes there's no sign-in, ask once *"Everything OK on the sign-in?"* and retry.

## Phase 3 — Mint or pull the API token

Snapshot the integrations page. Look for the **"Personal API tokens"** section. The page renders existing tokens (masked) and a **"Create new token"** (or **"+ New token"**) button.

Two paths:

### 3a — Create a fresh token (preferred for clean workshop runs)

Click **"Create new token"**. In the modal:

- **Token name:** `Claude Code agent ($(date -u +%Y-%m-%d))` — workshop-friendly label so the user can recognise it later
- **Scopes:** if the modal asks for scopes, tick the all-Actor read/write scopes — the three apify-* skills need to run Actors and read their output. If there's a "Full account access" option, prefer that for a workshop run (the user can rotate later).
- **Expiration:** if there's an expiry field, pick "Never" (Apify's default).

Click **"Create"**. The token reveals once on the resulting screen.

### 3b — Reuse an existing token (only if the user explicitly says so)

If the user said "I already have an Apify token, just plug it in", skip the create flow. Look for an existing token in the list named `Claude Code agent (...)` — click its **eye/reveal** icon to expose the value, then extract from DOM.

This path is rarer; default to 3a.

### Extract the token from the DOM

Apify Personal API tokens start with `apify_api_` followed by 40+ alphanumeric characters. Use `browser_evaluate` on the token input's `.value`:

```javascript
// Try the most likely selectors in order
document.querySelector('input[name="apiToken"]')?.value
  || document.querySelector('[data-testid="api-token-value"]')?.textContent?.trim()
  || document.querySelector('code.api-token, code.token-value')?.textContent?.trim()
  || 'NOT_FOUND'
```

Validate the shape:

```bash
echo "$APIFY_TOKEN" | grep -qE '^apify_api_[A-Za-z0-9]{30,}$' || echo "INVALID_TOKEN_SHAPE"
```

If `INVALID_TOKEN_SHAPE`: the DOM extraction grabbed wrong content. Re-snapshot, look for the visible token (Apify shows it briefly with a copy button), use `browser_evaluate` again. If two attempts fail, surface the error to the user once and stop.

**Mask immediately.** Never print the token to chat or tool returns. The variable lives in the shell context only until Phase 4 persists it.

## Phase 4 — Persist the token + run `apify login` to auth the machine + smoke-test

Three operations, all silent from the user's perspective. Per the Apify CLI quick-start (https://docs.apify.com/cli/docs/quick-start), the canonical sequence after install is **install → `apify login` → `apify whoami` verification**. This skill runs that sequence non-interactively using the token captured in Phase 3, so the user never sees a browser prompt for OAuth a second time.

### Step 4a — Write `~/.claude/apify.env` (source of truth for the three sibling skills)

```bash
mkdir -p "$HOME/.claude"
umask 077
# Write APIFY_TOKEN UNQUOTED — the resume checks in this skill (Phase 0)
# and in the three sibling skills' Step 0 grep with the regex
# `^APIFY_TOKEN=apify_api_`, which does NOT match a quoted value
# (`APIFY_TOKEN="apify_api_..."`). Writing unquoted keeps the regex simple
# and prevents an infinite re-install loop where the post-install resume
# check would immediately report MISSING and re-trigger this installer.
# node --env-file parses unquoted values identically to quoted ones.
cat > "$HOME/.claude/apify.env" <<EOF
# Apify Installer — credentials captured $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Sourced by the three apify-* skills (competitor-intelligence,
# content-analytics, market-research) via node --env-file.
# DO NOT commit this file. DO NOT share publicly.
APIFY_TOKEN=${APIFY_TOKEN}
EOF
chmod 600 "$HOME/.claude/apify.env"
```

### Step 4b — Authenticate the native CLI by writing `~/.apify/auth.json` directly (NOT `apify login -t`)

> **Security rationale — do not use `apify login -t "$APIFY_TOKEN"`.** That invocation puts the token on the command line. On Linux/macOS, `/proc/PID/cmdline` (or `ps aux`) exposes argv to anyone with read access to the process — meaning any user, any monitoring agent, any inadvertent `ps` diagnostic during install can capture the token. Apify's own quick-start docs (https://docs.apify.com/cli/docs/quick-start) demonstrate `apify login --token apify_api_xxxxx` as their canonical pattern, but the workshop's "never echo the token" rule is stricter than Apify's own posture. We bypass the CLI's leak-prone invocation and write `~/.apify/auth.json` directly — the canonical authentication-store location that every subsequent `apify ...` command reads from.

Schema confirmed from the apify-cli source (`_register-*.js`, `getTokenWithAuthFileFallback`): the CLI only needs `{token: "..."}` to authenticate API calls. Optional user-info fields (`userId`, `username`) get populated by `apify login` after a server round-trip but are not required for the CLI to function.

```bash
# Equivalent end-state to `apify login -t`, without the argv leak:
mkdir -p "$HOME/.apify"
umask 077
cat > "$HOME/.apify/auth.json" <<EOF
{
	"token": "${APIFY_TOKEN}"
}
EOF
chmod 600 "$HOME/.apify/auth.json"
```

After this runs successfully, both credential locations are populated:
- `~/.claude/apify.env` — read by the three sibling skills' Step 2 / Step 4 bash blocks via `node --env-file`
- `~/.apify/auth.json` — read by the native `apify` CLI for any `apify run`, `apify push`, `apify call` etc. the user runs directly

The smoke test in Step 4c (`apify whoami`) verifies the file works end-to-end — it does a server round-trip with the stored token and prints the authenticated user's email + username if and only if the token is valid AND the file was readable.

### Step 4c — Smoke test with `apify whoami`

```bash
WHOAMI=$(apify whoami 2>&1 | head -3)
echo "$WHOAMI" | grep -qE 'Email|Username|@' && echo "OK" || echo "SMOKE_FAILED"

# Wipe the variable from this shell context
unset APIFY_TOKEN
```

`apify whoami` is the canonical verification step from the quick-start docs — it prints the authenticated user's email + username if the login worked, or "You are not logged in" if it didn't.

If `OK`: tell the user once: *"All set — your Apify is now connected. The three Apify skills (competitor research, content analytics, market research) will work without any more setup."*

If `SMOKE_FAILED`: the most common cause is a token that lacks "Run Actors" scope. Tell the user once, then offer to re-run Phase 3 with broader scope ticked.

## Phase 5 — Clean up the Playwright browser

Close the Apify console tab. The persistent profile keeps the user signed in for next time — no logout. Workshop attendees should never re-sign-in to the same SaaS twice.

## Token rotation

If the user later wants to rotate (e.g. a token leaked, or they want one with narrower scope), they re-invoke this skill. Phase 0's resume check sees the existing env file but Phase 3 overwrites the token. They should also revoke the old token manually in `https://console.apify.com/account/integrations` after the rotation completes — this skill does not automate revocation (that's a destructive action requiring explicit user intent).

## Troubleshooting

### "Personal API tokens" section is missing from the page

Apify has redesigned the account UI a few times. If the section isn't where this skill describes, try:

1. `https://console.apify.com/settings/integrations` — newer settings path
2. Click the user's avatar (top-right) → "Account" → "Integrations" tab
3. Browser refresh — sometimes the Console JS doesn't fully load on first paint

### `apify whoami` returns "You are not logged in"

The direct write to `~/.apify/auth.json` in Phase 4b silently failed, OR the token was truncated during DOM extraction. Diagnose in order:

1. **Does the file exist and have content?** `cat ~/.apify/auth.json` should print `{"token":"apify_api_..."}`. If the file is empty or missing, Phase 4b's heredoc didn't write — most likely cause is `$APIFY_TOKEN` was empty at the point of the heredoc (Phase 3 capture failed silently). Re-run Phase 3.
2. **Is the token shape right?** The token inside the JSON should be `apify_api_` + 36 chars. If it's truncated (shorter), Phase 3's DOM extraction grabbed wrong content — re-extract using `browser_evaluate` on the input's `.value` property (NOT `.textContent`, NOT `innerHTML`).
3. **Does the file have the right mode?** `stat -c '%a' ~/.apify/auth.json` should print `600`. If world-readable (644), the heredoc ran but `chmod 600` didn't — fix manually with `chmod 600 ~/.apify/auth.json`.

### Token leaked to chat by accident

If `apify_api_...` appears in any chat output or tool-call return before Phase 4 completes:

1. **Immediately revoke.** Open `https://console.apify.com/account/integrations` and click the leaked token → "Delete" → type `delete my token` in the confirmation dialog → click Delete. The leaked token is invalid instantly. Verify with `curl -H "Authorization: Bearer <leaked>" https://api.apify.com/v2/users/me` returning HTTP 401.
2. Re-run this skill from Phase 3 with a fresh token.
3. Save a memory entry noting how the leak happened so future sessions avoid the same path.

### Token leaked via `ps aux` / `/proc/PID/cmdline` (argv exposure)

This is the gap that motivated the Phase 4b direct-write approach above. If for any reason the SKILL or a derivative runs `apify login -t "$TOKEN"` (or any CLI that takes the token on argv), the token is visible to:

- Any `ps aux | grep apify` during the install
- Any monitoring agent reading `/proc/*/cmdline` (Datadog, New Relic, security-scanning daemons, etc.)
- Any unprivileged user on a shared host

**Detection**: during install, `ps aux 2>&1 | grep -E 'apify.*-t.*apify_api_'` should return zero results. If it returns the login command, the install is leaking — kill the process, revoke the token, and check whether `apify login -t` got reintroduced into the SKILL or any wrapper script.

**Prevention** (the canonical fix shipped in this skill): write `~/.apify/auth.json` directly per Phase 4b. The token never appears on a command line, so argv exposure is structurally impossible.

### `mcpc: command not found` after install

Node's global-bin directory may not be in `PATH`. Show `npm config get prefix` — the result's `bin/` subdirectory should be in `PATH`. On macOS Homebrew systems, that's typically `/opt/homebrew/bin/`; on Linux it's `/usr/local/bin/` or `~/.nvm/versions/node/v22.x/bin/`. Add to the user's shell rc if needed.

## What this SKILL does NOT cover

- **Apify account creation.** If the user doesn't have an Apify account yet, the sign-in form has a "Create account" link — surface that and let them sign up. After signup, the Console redirects to `/account/integrations` so the rest of this flow works.
- **Apify subscription plan choice.** Apify has a Free tier (limited credits/month) and paid tiers. Most workshop work fits in the Free tier; if the user later hits Actor-run limits, that's an upgrade conversation, not a setup issue.
- **Per-Actor authentication.** Some Actors require additional auth (e.g. a Facebook login cookie). Those are captured at run-time by the relevant sibling apify-* skill, not by this installer.

## See also

- [`apify-competitor-intelligence/SKILL.md`](../apify-competitor-intelligence/SKILL.md) — sibling that dispatches here
- [`apify-content-analytics/SKILL.md`](../apify-content-analytics/SKILL.md) — sibling that dispatches here
- [`apify-market-research/SKILL.md`](../apify-market-research/SKILL.md) — sibling that dispatches here
- [Apify CLI install docs](https://docs.apify.com/cli/docs/installation) — canonical source for the install command (`npm install -g apify-cli`, Node 22+)
- [Apify CLI quick-start](https://docs.apify.com/cli/docs/quick-start) — canonical post-install sequence (install → `apify login` → `apify whoami` verification); this skill mirrors that sequence non-interactively
- [Apify CLI reference](https://docs.apify.com/cli/docs/reference) — `apify login -t <token>`, `apify whoami`, etc., with the exact flag shapes
- [`skills/CLAUDE.md`](../CLAUDE.md) — the three connector patterns (this skill is Pattern 2 / Hosted-bearer-PAT shape)
- [`feedback_dispatch_architecture` memory] — why one installer + three dispatching siblings is the right shape
