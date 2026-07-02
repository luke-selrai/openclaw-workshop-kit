---
name: cloudflare-deployment
description: Install and authenticate the Cloudflare developer stack (Wrangler CLI, Workers, Pages, R2, KV, D1, Durable Objects) on the user's laptop. Use this skill when the user asks to connect Cloudflare, set up Wrangler, deploy to Workers or Pages, log in to Cloudflare, or mentions any Cloudflare developer service. Handles installation, OAuth authentication, the official Cloudflare skills bundle, and verification conversationally. MANDATORY TRIGGERS - invoke immediately on any of these phrases (case-insensitive, partial match counts) - 'connect cloudflare', 'set up cloudflare', 'install wrangler', 'deploy to workers', 'cloudflare login', 'cloudflare pages', 'cloudflare r2', 'cloudflare kv', 'cloudflare d1', 'durable objects setup'.
allowed-tools: Bash,PowerShell,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - cloudflare
    - workers
    - pages
    - r2
    - kv
    - d1
    - durable-objects
    - wrangler
    - deployment
    - installer
  pairs-with:
    - skill: vercel-deployment
      reason: Similar deployment surface - Cloudflare Workers/Pages is the Vercel alternative for edge workloads
    - skill: nextjs-app-router-expert
      reason: Cloudflare Pages can host Next.js apps via @cloudflare/next-on-pages
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Cloudflare auth, deploy, or quota errors
---

# Cloudflare Deployment

## Overview

This skill does three things:
1. **Installs** the Cloudflare developer stack (Node.js + Wrangler CLI) on the user's computer (one-time setup)
2. **Authenticates** the user via Cloudflare's OAuth flow - one browser click, zero token pasting
3. **Operates** Cloudflare services after setup - Workers, Pages, R2, KV, D1, Durable Objects

The whole flow is hands-off after a single "click Approve in browser" step. The skill is idempotent - running it twice is safe.

> **This is for local laptop setup only.** Production deploys still run from `wrangler deploy` after the user is signed in.

---

## State File

The skill tracks progress at `~/.claude/state/cloudflare-deployment.json` so re-runs know what's already done. Schema:

```json
{
  "version": 1,
  "node_installed": true,
  "wrangler_installed": true,
  "wrangler_version": "3.x.x",
  "skills_bundle_installed": true,
  "authenticated": true,
  "account_id": "abc123",
  "account_email": "user@example.com",
  "last_verified_at": "2026-05-14T10:00:00Z",
  "playwright_fallback_used": false
}
```

Always read this file first. Skip steps that are already done unless the user asks for a re-install or re-auth.

---

## Part 1 - Quick Check (idempotent re-entry)

Before doing anything else, run these checks in order:

1. **Read** `~/.claude/state/cloudflare-deployment.json` (if exists).
2. **Run** `wrangler --version`. If it returns a version, Wrangler is installed.
3. **Run** `wrangler whoami`. If it returns email + account, the user is signed in.

If everything is already wired up correctly:
> "Cloudflare is already set up. You're signed in as [email] with account [account name]. Want to deploy a Worker or do something specific?"

Update the state file's `last_verified_at` and stop. Do not re-run install steps.

If only Wrangler is missing → jump to Part 2.
If Wrangler is installed but auth failed → jump to Part 3.
If everything is broken → start fresh from Part 2.

---

## Part 2 - Install

Guide one step at a time. Plain English. No jargon.

### Step 1: Check Node.js

Run `node --version`. Cloudflare requires Node.js 20 or newer (22 is best).

**If Node is missing or below 20**, say:
> "We need to install Node.js first - that's the runtime Cloudflare's tools need."

Then run the install script for the user's OS. Use the helper scripts in `scripts/`:

- **macOS / Linux:** run `bash scripts/install-node-unix.sh`
- **Windows:** run `powershell -ExecutionPolicy Bypass -File scripts/install-node-windows.ps1`

**If Node 20+ is already present**, say:
> "Good - Node.js is already installed."

### Step 2: Install Wrangler

Say:
> "Now I'm installing Wrangler - that's the Cloudflare command-line tool. This will take about 30 seconds."

Run:

```bash
npm install -g wrangler
```

**If the install fails with a permission error** (no sudo / locked-down machine), say:
> "Your computer doesn't allow global installs. No problem - I'll use a per-project install instead."

Then set the state file's `wrangler_installed: "npx"` and from now on use `npx wrangler` everywhere instead of `wrangler`.

**Try also (optional, preview unified CLI):**

```bash
npm install -g @cloudflare/cf 2>&1 || true
```

This is the new unified CLI. Don't fail the skill if it isn't published yet - it's optional.

### Step 3: Verify install

Run `wrangler --version`. If it returns a version, say:
> "That worked. Wrangler version [X.Y.Z] is installed."

If it says "command not found":
> "The terminal needs a refresh. Please close this terminal window and open a new one, then tell me to continue."

Update state file: `wrangler_installed: true`, `wrangler_version: "<version>"`.

---

## Part 3 - Authenticate

### Step 4: Detect existing credentials FIRST

Before opening a browser, check if the user is already signed in:

1. **Check env var:**
   ```bash
   echo $CLOUDFLARE_API_TOKEN
   ```
   On Windows PowerShell:
   ```powershell
   $env:CLOUDFLARE_API_TOKEN
   ```
   If non-empty, validate it:
   ```bash
   wrangler whoami
   ```

2. **Check wrangler config files:**
   - macOS / Linux: `~/.config/.wrangler/config/default.toml` or `~/.wrangler/config/default.toml`
   - Windows: `$env:USERPROFILE\.wrangler\config\default.toml` or `%APPDATA%\.wrangler\`

3. **Run `wrangler whoami`** - if it returns account + email, skip to Part 4.

If `wrangler whoami` returns 401 / "unauthenticated" / token invalid:
> "Your old Cloudflare login expired. I'll sign you in fresh."

Purge stale credentials:
```bash
wrangler logout
```

Then continue to Step 5.

### Step 5: OAuth login (the one human moment)

Say:
> "I'm going to sign you in to Cloudflare now. A browser window will pop open. Click the green Allow button to approve, then come back here. That's the only thing you need to do."

Run:

```bash
wrangler login
```

This opens https://dash.cloudflare.com/oauth2/auth in the user's default browser.

**While waiting**, poll for the credentials file every 2 seconds (max 120 seconds):
- macOS / Linux: `~/.config/.wrangler/config/default.toml`
- Windows: `$env:USERPROFILE\.wrangler\config\default.toml` (or `%APPDATA%\.wrangler\config\default.toml`)

When the file appears, the user has approved. Say:
> "That worked. You're signed in."

**If the browser doesn't open within 30 seconds**, fall back to Part 5 (Playwright).

**If the user closes the browser without approving**, say:
> "Looks like the sign-in didn't finish. Want me to try again?"

### Step 6: Confirm identity

Run:

```bash
wrangler whoami
```

This prints account ID, email, and accessible scopes. Save these to the state file. Say:

> "You're connected to Cloudflare. Signed in as [email], using the [account name] account."

Update state file: `authenticated: true`, `account_id`, `account_email`, `last_verified_at`.

---

## Part 4 - Install the Official Cloudflare Skills Bundle

Cloudflare publishes a bundle of skills (agents-sdk, durable-objects, sandbox-sdk, web-perf, workers-best-practices, wrangler) at https://github.com/cloudflare/skills. Default to YES - install them.

Say:
> "Cloudflare publishes their own pack of skills for working with Workers, Durable Objects, R2, and KV. Want me to add those too? It takes about 15 seconds. Yes or no?"

**If yes**, run inside Claude Code:

```
/plugin marketplace add cloudflare/skills
/plugin install cloudflare@cloudflare
```

These are Claude Code slash commands, not shell commands. Execute via the harness's plugin system. If the `/plugin` command isn't available in the current session, say:
> "I'll need you to run these two lines yourself - they go in this chat box, not the terminal. Copy and paste this first:"
> ```
> /plugin marketplace add cloudflare/skills
> ```
> "Then press Enter and tell me when it's done. I'll give you the next line."

After both lines run, update state file: `skills_bundle_installed: true`.

**If no**, skip and continue. Update state: `skills_bundle_installed: false`.

---

## Part 5 - Playwright Fallback (only if needed)

Use this path ONLY when `wrangler login` cannot open the browser - e.g.:
- WSL with no display server
- Remote SSH session
- Locked-down corporate machine
- `wrangler login` printed an OAuth URL but no browser launched

Say:
> "Your terminal can't open a browser by itself. I'll open one for you in a controlled window - same one-click approval, just driven by me."

Steps:

1. **Capture the OAuth URL** from `wrangler login`'s output. Wrangler prints something like:
   ```
   Attempting to login via OAuth...
   Opened a link in your default browser: https://dash.cloudflare.com/oauth2/auth?response_type=code&...
   ```

2. **Launch Playwright Chromium** in non-headless mode:
   ```
   mcp__playwright__browser_navigate to the captured OAuth URL
   ```

3. **Wait for the user** to click Allow. Watch for the redirect to `http://localhost:8976/oauth/callback?code=...` (Wrangler runs a localhost callback server).

4. **Wrangler picks up the callback automatically** because its local server is listening. Once the redirect happens, `wrangler login` completes on its own and writes the token to the wrangler config dir.

5. **Verify** with `wrangler whoami`.

6. **If wrangler's localhost callback is blocked** (rare - corporate firewall), generate an API token manually:
   - Use Playwright to navigate to https://dash.cloudflare.com/profile/api-tokens
   - Click "Create Token" → "Edit Cloudflare Workers" template
   - Click "Continue to summary" → "Create Token"
   - Capture the token from the page
   - Write it to the environment:

   **macOS / Linux** - append to `~/.zshrc` or `~/.bashrc`:
   ```bash
   export CLOUDFLARE_API_TOKEN="<captured-token>"
   ```

   **Windows** - append to `$PROFILE` (PowerShell profile):
   ```powershell
   $env:CLOUDFLARE_API_TOKEN = "<captured-token>"
   [System.Environment]::SetEnvironmentVariable('CLOUDFLARE_API_TOKEN', '<captured-token>', 'User')
   ```

   Then re-run `wrangler whoami` in a fresh shell.

Update state: `playwright_fallback_used: true`.

---

## Part 6 - End-to-End Verification

After auth is confirmed, run a real Cloudflare call to prove it works. Two options - ask the user which:

> "Last thing - want me to do a quick test? I can either:
> (1) Just run a 'who am I' check - fast, read-only, nothing changes on your account
> (2) Deploy a tiny Hello World Worker and immediately delete it - proves end-to-end deploy works
> Pick 1 or 2."

### Verification Option 1 (default - read-only)

Run:

```bash
wrangler whoami
wrangler kv namespace list 2>&1
wrangler r2 bucket list 2>&1
```

Print results in plain English:
> "Account: [name]. Email: [email]. You have [N] KV namespaces and [M] R2 buckets. Cloudflare is fully wired up."

### Verification Option 2 (full deploy test)

Create a temp directory, deploy a Hello World Worker, then immediately delete it:

```bash
mkdir -p /tmp/cf-deploy-test && cd /tmp/cf-deploy-test
cat > wrangler.toml <<EOF
name = "cf-deploy-test-$(date +%s)"
main = "index.js"
compatibility_date = "2026-05-14"
EOF
cat > index.js <<EOF
export default {
  fetch() { return new Response("Hello from Claude - Cloudflare is connected."); }
};
EOF
wrangler deploy
```

Capture the deployed URL, curl it once to confirm it works, then:

```bash
wrangler delete --name "cf-deploy-test-<timestamp>"
```

Say:
> "Test deploy succeeded. The Worker responded with 'Hello from Claude - Cloudflare is connected.' I've already deleted it so it doesn't sit on your account."

On Windows the `mkdir`/heredoc syntax differs - use the PowerShell equivalent (see `scripts/verify-deploy.ps1`).

---

## Part 7 - What to Try First

After setup is done, suggest tasks the user can ask for:

> "Want to try something? Here are a few things I can do with your Cloudflare:"

```
"Deploy this folder as a Cloudflare Worker."
"Create a new R2 bucket called 'uploads'."
"List my KV namespaces."
"Spin up a D1 database for my project."
"Set up a Cloudflare Pages site for my website."
```

---

## Part 8 - Common Operations

### Workers

```bash
# List workers
wrangler deployments list

# Deploy from current directory
wrangler deploy

# Tail live logs
wrangler tail <worker-name>

# Delete a worker
wrangler delete --name <worker-name>
```

### Pages

```bash
# List Pages projects
wrangler pages project list

# Create a new Pages project
wrangler pages project create <project-name> --production-branch main

# Deploy a build folder
wrangler pages deploy ./dist --project-name <project-name>
```

### R2 (Object Storage)

```bash
# List buckets
wrangler r2 bucket list

# Create a bucket
wrangler r2 bucket create <bucket-name>

# Upload a file
wrangler r2 object put <bucket-name>/<key> --file ./local-file.txt

# Download a file
wrangler r2 object get <bucket-name>/<key> --file ./local-file.txt
```

### KV (Key-Value)

```bash
# List namespaces
wrangler kv namespace list

# Create a namespace
wrangler kv namespace create <name>

# Set a key
wrangler kv key put --binding=<binding> "<key>" "<value>"

# Get a key
wrangler kv key get --binding=<binding> "<key>"
```

### D1 (SQLite)

```bash
# List D1 databases
wrangler d1 list

# Create a D1 database
wrangler d1 create <db-name>

# Run a query
wrangler d1 execute <db-name> --command "SELECT * FROM users LIMIT 5;"

# Run a migration file
wrangler d1 execute <db-name> --file ./migrations/001.sql
```

### Durable Objects

```bash
# Listed in your wrangler.toml under [[durable_objects.bindings]]
# Deploy with regular `wrangler deploy` - the bindings provision the DOs.

# Inspect a DO namespace
wrangler durable-objects namespace list
```

---

## Part 9 - Auth & Session Management

```bash
# Check who is signed in
wrangler whoami

# Log out (clears credentials)
wrangler logout

# Log back in (browser OAuth)
wrangler login

# Use an API token instead of OAuth (for CI/automation)
export CLOUDFLARE_API_TOKEN="..."
wrangler whoami
```

To rotate or revoke tokens, send the user to https://dash.cloudflare.com/profile/api-tokens.

---

## Part 10 - Troubleshooting

| Problem | Fix |
|---|---|
| `wrangler: command not found` | Shell needs restart - open a new terminal. If still missing, re-run `npm install -g wrangler`. |
| `EACCES` / permission denied on npm install | Use `npx wrangler` per-project instead, or fix npm prefix with `npm config set prefix ~/.npm-global`. |
| `Authentication error [code: 10000]` | Token expired - run `wrangler logout` then `wrangler login`. |
| Browser doesn't open on `wrangler login` | Fall back to Playwright (Part 5). |
| `Failed to fetch` / corporate proxy | Set `HTTPS_PROXY=http://proxy.corp:port` before running wrangler. Or set `WRANGLER_HTTPS_PROXY`. |
| Multiple Cloudflare accounts | Run `wrangler whoami` to see which is active. Add `account_id = "..."` to `wrangler.toml` to pin per-project. |
| `localhost:8976 already in use` during login | Another wrangler is running. Kill it or pass `--browser=false` + `--callback-port=8977`. |
| `command not found: wrangler` after install | PATH not refreshed - open a new terminal window. On Windows, log out and back in. |
| Deploy fails: "Account ID is required" | Run `wrangler whoami` to see your account ID, then add it to `wrangler.toml` under `account_id`. |
| `Invalid token (10001)` on every command | Token was revoked from the dashboard - re-run `wrangler login`. |

When an error occurs, say:
> "No problem - let me try a different way."

Then diagnose silently. Never paste raw stack traces at the user - translate everything into plain English.

For deeper troubleshooting see `troubleshooting.md` next to this file.

---

## Behaviour Guidelines

- **Always run `wrangler whoami` first** at the start of a session to confirm the user is signed in.
- **Read the state file** before doing any work - skip steps already done.
- **Confirm before destructive actions** - deleting Workers, dropping D1 databases, removing R2 objects, wiping KV namespaces.
- **Account context matters** - if the user has multiple accounts, confirm which one before deploying.
- **Auth errors** → `wrangler logout && wrangler login`.
- **Wrangler not found** → restart shell or reinstall via `npm install -g wrangler`.
- **One step at a time** - do not dump all instructions at once. Say what to do, wait for confirmation, then give the next step.
- **Plain English only** - translate `wrangler.toml`, "OAuth", "namespace binding", etc. into business terms when explaining to the user.
- **Idempotent** - always check before creating. Never duplicate Workers, namespaces, or buckets.
- **One question at a time** - never ask the user a list of questions. Pick the highest-value one, make a sensible default for the rest, state assumptions.

---

## References

- [Cloudflare Workers docs](https://developers.cloudflare.com/workers/)
- [Wrangler CLI reference](https://developers.cloudflare.com/workers/wrangler/commands/)
- [Cloudflare Agent Setup for Claude Code](https://developers.cloudflare.com/agent-setup/claude-code/)
- [Official Cloudflare skills bundle](https://github.com/cloudflare/skills)
- [Pages docs](https://developers.cloudflare.com/pages/)
- [R2 docs](https://developers.cloudflare.com/r2/)
- [D1 docs](https://developers.cloudflare.com/d1/)
- [Durable Objects docs](https://developers.cloudflare.com/durable-objects/)
