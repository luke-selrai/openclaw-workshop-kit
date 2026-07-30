---
name: railway-deployment
description: "Railway.com deployment - installs the Railway CLI, signs the user in with one browser click, then deploys and runs projects directly. Use when the user wants to connect Railway, deploy a repo or the Medusa template, or link an existing project."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - railway
    - deployment
    - hosting
    - postgres
    - redis
    - installer
    - oauth
    - medusa-template
  pairs-with:
    - skill: medusa-connector
      reason: medusa-connector's Step 10B Path 1 dispatches here for the workshop-default Railway-based Medusa stack. The Medusa template path (Phase 3A below) is specifically built for that hand-off.
    - skill: render-deployment
      reason: Similar install+auth shape - Render is the closest alternative to Railway for Node + Postgres workloads. If Railway pricing or capabilities don't fit, route the user to render-deployment.
    - skill: cloudflare-deployment
      reason: Pairs well for static storefronts on Cloudflare Pages or product-image storage on R2 in front of a Railway-hosted backend.
    - skill: deploy-to-vercel
      reason: Vercel is the workshop default for the Next.js storefront half when Railway hosts the backend. Use both together for a typical Phase 3 ecommerce-medusa team.
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Railway auth, install, or deploy errors
---

# Railway Deployment

## Purpose

**This skill is a hands-off assistant for connecting Claude Code to a Railway.com account.** After the user runs it once, the agent (me) can run any `railway` CLI command on the user's behalf - deploy services, link projects, read variables, tail logs, redeploy, etc. - without further setup or human input.

The whole flow takes one click in a browser (to approve `railway login`), and that's the only required user interaction. If the user is on the workshop-default Medusa stack, the agent can additionally deploy the official Medusa template in one further automated step - backend + Postgres + Redis provisioned in ~3 minutes.

## Why a dedicated Railway skill (when the kit already has Render / Vercel / Cloudflare / AWS / Azure)

Railway is the recommended **backend host for self-host Medusa** because Medusa Labs publishes an official Railway template that provisions backend + Postgres + Redis in one click - no equivalent exists on Render or Vercel as of January 2026. The workshop default for the Phase 3 ecommerce-medusa team picks Railway specifically for this reason. This skill makes that path one tool call away.

For non-Medusa Node/Postgres workloads, Railway is also a clean alternative to Render (similar pricing, similar UX). The skill is useful beyond the Medusa case - it just happens to be where the Medusa hand-off lands.

## What this skill does NOT do

- **It does not install Railway's official skill bundle** (if/when one exists). The agent uses `railway` CLI directly.
- **It does not deploy from a local folder for arbitrary apps.** Railway's deploy model is mostly Git-based - services are connected to a GitHub/GitLab repository. The exception is the Medusa template path, which provisions a fresh-template-backed service that auto-deploys on Railway-side defaults.
- **It does not maintain a long catalogue of Railway CLI commands.** Railway's docs already do that. The agent reads `railway <cmd> --help` at runtime when it needs to know more.

---

## State File

The skill tracks progress at `~/.claude/state/railway-deployment.json` so re-runs skip already-done work:

```json
{
  "version": 1,
  "railway_cli_installed": true,
  "railway_cli_version": "4.x.x",
  "authenticated": true,
  "account_email": "user@example.com",
  "team_id": "team_abc123",
  "team_slug": "selrai",
  "last_verified_at": "2026-05-28T10:00:00Z",
  "projects": [
    {
      "project_id": "...",
      "project_slug": "medusa-store-prod",
      "purpose": "medusa-backend",
      "created_at": "2026-05-28T10:05:00Z",
      "public_url": "https://medusa-store-prod.up.railway.app",
      "database_url_present": true,
      "redis_url_present": true
    }
  ]
}
```

Always read this file first. Skip steps that are already done unless the user asks for a re-install, re-auth, or new project.

---

## PHASE 0 - Resume check

Read `~/.claude/state/railway-deployment.json` if it exists:

- `authenticated: true` and `last_verified_at` < 24h ago → skip Phase 1 + Phase 2. Run a single smoke call to verify auth still works:
  ```bash
  railway whoami 2>&1 | head -3
  ```
  If it returns the user's email, jump to Phase 3 (project work). If it returns a "not logged in" error, fall through to Phase 2 (re-auth).
- File missing entirely → start at Phase 1.
- File present but `railway_cli_installed: false` → start at Phase 1.

---

## PHASE 1 - Install the Railway CLI

Detect the OS and install accordingly. **Tell the user once:** *"Installing the Railway tool on your computer - this takes about 30 seconds."* Then proceed silently.

```bash
# Detect OS
OS=$(uname -s)

case "$OS" in
  Darwin|Linux)
    if command -v railway >/dev/null 2>&1; then
      echo "already-installed: $(railway --version)"
    else
      # Preferred: Homebrew on macOS, npm everywhere
      if [[ "$OS" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
        brew install railway 2>&1 | tail -5
      elif command -v npm >/dev/null 2>&1; then
        npm install -g @railway/cli 2>&1 | tail -5
      else
        # Fallback to the official shell installer
        bash -c "$(curl -fsSL railway.com/install.sh)" 2>&1 | tail -5
      fi
    fi
    ;;
  MINGW*|CYGWIN*|MSYS*)
    # Windows - recommend npm path; the .exe installer is also available at railway.com/install
    if command -v npm >/dev/null 2>&1; then
      npm install -g @railway/cli 2>&1 | tail -5
    else
      echo "Need npm on Windows. Install Node.js first from https://nodejs.org, then re-run this skill."
      exit 1
    fi
    ;;
esac

# Verify
RAILWAY_VERSION=$(railway --version 2>&1 | head -1)
echo "railway-version: $RAILWAY_VERSION"
```

Persist `railway_cli_installed: true` + `railway_cli_version` to the state file.

If install failed, tell the user *"Something went wrong installing the Railway tool. Let me check what's blocking it,"* then diagnose silently (PATH issues, npm not installed, network) and offer one retry. After two failures, stop and ask the user.

---

## PHASE 2 - Authenticate via `railway login` (Playwright-driven OAuth)

Railway's `railway login` opens a browser for OAuth. The workshop-UX rule (no terminal interactions for participants) means the user should click "Allow" in a browser window we open for them, not paste pairing codes.

> **Playwright MCP install contingency.** If `mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` tools are not reachable, install Playwright first per `../CLAUDE.md` "Playwright MCP install contingency" section. The Railway OAuth callback fires at `https://railway.com/cli-login?...` - needs a real browser.

```bash
# Kick off the login flow. Railway opens its own URL in the user's default browser,
# but we want to drive it in Playwright so we control the success signal.
# Capture the URL Railway is trying to open by intercepting stdout.
railway login --browserless 2>&1 | tee /tmp/railway-login.log &
LOGIN_PID=$!
sleep 2

# Read the URL the CLI printed
LOGIN_URL=$(grep -oE 'https://railway.com/cli-login[^[:space:]]*' /tmp/railway-login.log | head -1)
```

If `LOGIN_URL` is empty, the CLI's output format may have changed. Fallback: kill the background `railway login`, run plain `railway login` (which auto-opens the browser), and let the OS browser handle it - the user will need to switch focus to their default browser, which is friction but works.

Otherwise, drive the URL in Playwright:

```
Open <LOGIN_URL> in Playwright MCP.

Take browser_snapshot. The page will show Railway's "Authorize Claude Code CLI" consent screen (or it may bounce to railway.com/login first if the user isn't signed in yet).

If a sign-in form is showing, tell the user once: "Please sign in to your Railway account in the window I just opened."

Poll browser_snapshot every few seconds until the URL changes to one of:
- railway.com/cli-login?status=success  → success signal
- railway.com/dashboard                  → Railway logged in but redirected; check the CLI's exit status

When the URL settles, switch back to the terminal:
- `wait $LOGIN_PID` to let the railway login command exit.
- `railway whoami` to confirm the auth landed.
```

After Playwright shows success, the CLI side persists the token to `~/.railway/config.json` automatically - no extra Bash write needed.

Verify and persist:

```bash
railway whoami 2>&1 | head -3
# Capture email + team for the state file
RAILWAY_EMAIL=$(railway whoami 2>&1 | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}')
echo "authenticated as: $RAILWAY_EMAIL"
```

Write to state file:

```bash
mkdir -p "$HOME/.claude/state"
umask 077
cat > "$HOME/.claude/state/railway-deployment.json" <<EOF
{
  "version": 1,
  "railway_cli_installed": true,
  "railway_cli_version": "$(railway --version | head -1)",
  "authenticated": true,
  "account_email": "$RAILWAY_EMAIL",
  "team_id": null,
  "team_slug": null,
  "last_verified_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projects": []
}
EOF
chmod 600 "$HOME/.claude/state/railway-deployment.json"
```

Tell the user *"You're connected to Railway."* and move on.

> **Security note:** the Railway token in `~/.railway/config.json` is account-level - it can deploy services, read secrets, delete projects, and bill the user's card. Never echo this file's contents back to the user, do not include them in any tool-call return value, and treat the file with the same care as `~/.claude.json`.

---

## PHASE 3 - Project work

Three sub-flows; pick based on the user's context:

- **3A** - Deploy the official Medusa template. Use when the medusa-connector skill's Step 10B Path 1 dispatched here, or when the user explicitly asks to deploy Medusa to Railway.
- **3B** - Deploy a custom Git repository. Use when the user has a non-Medusa app on GitHub/GitLab.
- **3C** - Link to an existing Railway project. Use when the user already has a project running on Railway and wants Claude to operate it.

### PHASE 3A - Deploy the official Medusa template

Medusa Labs maintains a Railway template at https://railway.com/template/medusa (verify the canonical URL once at runtime in case it moves). The template provisions:

- A Medusa v2 backend service
- A Postgres database service
- A Redis service
- All wired together with the correct env vars

Drive the template-deploy flow in Playwright:

```
Open https://railway.com/template/medusa in Playwright MCP.

Take browser_snapshot. The template page shows a "Deploy Now" button.

If the user is not signed in to Railway in this Playwright session yet, the page redirects to /login first - Phase 2 should have handled this, but if not, run Phase 2 now then return.

Click "Deploy Now". Railway prompts for project name and team selection.

For the project name: use `medusa-${random-suffix-3-chars}` (a workshop-friendly default). Tell the user this name so they can find the project in their dashboard later.

For team: pick the default personal team unless the user has previously specified a team in the state file.

Click "Create Project" or equivalent. Wait for the deploy to start - Railway shows three services (Medusa, Postgres, Redis) entering "Building..." state.

The Medusa service typically takes 2-4 minutes to first-build. Postgres and Redis are ready in ~30 seconds. Poll the page every 30 seconds until all three services show "Active" (green).
```

Once active, capture the URLs and connection strings via the CLI (faster than DOM scraping):

```bash
# Link the new project to the current directory's CLI context so subsequent commands target it
railway link --project medusa-${SUFFIX} 2>&1

# Get the Medusa backend's public URL
MEDUSA_URL=$(railway domain 2>&1 | grep -oE 'https://[^[:space:]]+\.up\.railway\.app' | head -1)

# Read DB + Redis URLs from project env vars
DATABASE_URL=$(railway variables --service Postgres --kv 2>&1 | grep '^DATABASE_PUBLIC_URL=' | cut -d= -f2-)
REDIS_URL=$(railway variables --service Redis --kv 2>&1 | grep '^REDIS_PUBLIC_URL=' | cut -d= -f2-)

# Verify
echo "MEDUSA_URL=$MEDUSA_URL"
[[ -n "$MEDUSA_URL" && -n "$DATABASE_URL" && -n "$REDIS_URL" ]] || echo "CAPTURE_FAILED"
```

If the medusa-connector skill dispatched here, append to its env file so the Phase 3 deployer agent has the values ready:

```bash
if [[ -f "$HOME/.claude/medusa-connector.env" ]]; then
  cat >> "$HOME/.claude/medusa-connector.env" <<EOF

# === Railway-provisioned Medusa stack ($(date -u +%Y-%m-%dT%H:%M:%SZ)) ===
RAILWAY_PROJECT_SLUG="medusa-${SUFFIX}"
RAILWAY_MEDUSA_URL="$MEDUSA_URL"
RAILWAY_DATABASE_URL="$DATABASE_URL"
RAILWAY_REDIS_URL="$REDIS_URL"
EOF
  chmod 600 "$HOME/.claude/medusa-connector.env"
fi
```

Also update `~/.claude/state/railway-deployment.json` with the new project entry.

Tell the user *"Your Medusa store is now running on Railway. The admin URL is ${MEDUSA_URL}/app - sign in there to finish setup."* and stop. The medusa-connector skill (if it dispatched here) will resume with its own Step 4 - admin login + API key creation - against the new URL.

> **The user may want a custom domain.** Railway gives every service a `*.up.railway.app` subdomain by default. Mapping a custom domain is two clicks in the Railway dashboard (Settings → Domains → Add Custom Domain → enter `store.example.com` → add the CNAME at the user's DNS provider). Offer to walk the user through this, but it's not required for Phase 3 to proceed - Medusa works fine on the Railway subdomain for development and small-scale production.

### PHASE 3B - Deploy a custom Git repository

For non-Medusa apps. The user must already have a GitHub or GitLab repository for the app - Railway pulls from there, not from a local folder.

Ask exactly:

> *"What's the URL of the Git repo you want to deploy? Something like `https://github.com/<user>/<repo>` or `https://gitlab.com/<user>/<repo>`."*

Validate the shape with `gh api repos/<owner>/<repo>` (for GitHub) or `curl -sS <gitlab-url>` (for GitLab). If the repo is private and Railway doesn't yet have access to the user's GitHub org, Railway's UI will prompt for repo access during the link step - Playwright handles this.

```
Open https://railway.com/new in Playwright MCP.

Click "Deploy from GitHub repo".

If Railway asks for GitHub access first (common on first project), click "Configure GitHub App" → grant access to the specific repo (NOT "All repositories") → return to Railway.

Pick the repo from the list. Railway auto-detects the framework and proposes build/start commands.

Read the proposed config back to the user once: "Railway is proposing to build with `npm run build` and start with `npm start`. Looks right?" If the user says yes, click Deploy.

Poll for the service to enter Active state.
```

Capture the public URL via CLI:

```bash
railway link --project ${PROJECT_NAME}
RAILWAY_URL=$(railway domain 2>&1 | grep -oE 'https://[^[:space:]]+\.up\.railway\.app' | head -1)
```

Persist to state file. Tell the user the URL.

### PHASE 3C - Link to an existing Railway project

Ask:

> *"You already have a project on Railway? Tell me the project name or slug - or just say 'pick from a list' and I'll show you what's there."*

If the user gives a slug:

```bash
railway link --project <slug>
```

If "pick from a list":

```bash
railway list 2>&1
```

Show the user the list (project names only - don't show internal IDs), let them pick by name. Then run `railway link --project <selected>`.

After link, smoke-test:

```bash
railway status 2>&1 | head -10
railway domain 2>&1 | head -3
```

Capture the URL + project metadata, persist to state file. Stop.

---

## Common operations after Phase 3

Once Phase 3 has linked a project, these are the most-used commands. The agent runs them directly on the user's behalf - no further skill setup needed.

```bash
# Tail logs for a service
railway logs --service <service-name>

# Set or read environment variables
railway variables --service <service-name>             # read
railway variables --service <service-name> --set "FOO=bar"  # write

# Trigger a fresh deploy from the latest Git commit
railway up

# Get the project's public domain
railway domain

# Open the project dashboard in a browser
railway open

# Disconnect from this project (useful when switching contexts)
railway unlink
```

For deeper docs, the agent runs `railway <command> --help` at the moment it needs them - Railway's CLI surface evolves and the help is canonical.

---

## Troubleshooting

### `railway login` opens a browser but the CLI never exits

The OAuth callback didn't fire. Most common causes:

1. **A previous `railway login` is still running.** Check `pgrep -f 'railway login'` and kill stale processes.
2. **The browser opened to railway.com/login instead of cli-login.** The user wasn't signed in. Have them sign in, then the cli-login URL should auto-load. If not, re-run `railway login`.
3. **Playwright's Allow-the-OAuth step landed but the CLI was killed (SIGKILL) before the callback returned.** Re-run `railway login` and don't kill the background process this time.

### `railway link` returns "Project not found"

The user is authenticated against a different team than the project lives in. Run `railway whoami` to see the current team, then either `railway login --team <slug>` to switch context, or have the user grant their workshop team access to the project from the Railway dashboard.

### Medusa template deploy is stuck in "Building..."

Three common causes:

1. **Build logs show npm install errors.** Most often a Medusa version pin in the template repo is out of sync. Re-deploy from the template - Medusa Labs updates the template regularly. If it persists, the user should fall back to deploying Medusa from their own repo (Phase 3B) using `medusajs/medusa-starter-default` as the source.
2. **Postgres/Redis not ready yet.** The Medusa service depends on both - if either Postgres or Redis is still "Building", wait. They usually finish in ~30 seconds; if longer than 2 minutes, check the database logs in the Railway dashboard.
3. **The Medusa service is in restart loop on first launch.** Usually a missing JWT_SECRET or COOKIE_SECRET env var. Railway's Medusa template sets these by default, but if you're deploying from a fork or modified template, set them via `railway variables --service Medusa --set 'JWT_SECRET=$(openssl rand -base64 32)' --set 'COOKIE_SECRET=$(openssl rand -base64 32)'`.

### "Your trial has ended" or "Usage limit reached"

Railway's free Hobby plan caps at $5/month of resource usage. For workshop runs, this is usually enough for a short Medusa demo, but a fully-populated store with traffic can blow through it. If the user hits this:

- Tell them once *"Railway's free trial doesn't have enough room left for this - you'll need a paid plan ($5+/month) to continue, or we can switch to a different host."*
- Offer alternatives: Render (also has a free tier; pair-with skill ready to dispatch), Fly.io (generous free tier), AWS (free tier eligible but more complex setup via `aws-connector`).

### Token leaked to chat by accident

If the Railway token from `~/.railway/config.json` appears in any chat output or tool-call return:

1. **Immediately revoke it.** Run `railway logout` in the terminal - this invalidates the token server-side and removes it from the local config.
2. **Re-auth from scratch.** Run Phase 2 again with a fresh login. Railway will generate a new token.
3. **Save a memory entry** explaining how the leak happened so future sessions avoid the same path.

---

## What this SKILL does NOT cover

- **Multi-region deploys.** Railway has region selection per service; this SKILL deploys to whatever the user's default region is. For multi-region, the user manages it via the Railway dashboard.
- **Database backup / restore strategies.** Railway has automated daily backups for Postgres in paid tiers; configuration is via the dashboard.
- **Custom Dockerfiles for non-Node services.** This SKILL assumes Railway's framework auto-detect. For Docker-based services, the user follows Railway's `railway.toml` and `Dockerfile` docs - out of scope here.
- **CI/CD orchestration beyond Railway's built-in auto-deploy-on-push.** For complex CI flows, pair with GitHub Actions (use `gh` CLI directly) - Railway integrates well with CI but this SKILL doesn't orchestrate it.

---

## See also

- [`../medusa-connector/SKILL.md`](../medusa-connector/SKILL.md) - Step 10B Path 1 dispatches here for the workshop-default Medusa stack
- [`../render-deployment/SKILL.md`](../render-deployment/SKILL.md) - closest alternative; pair-with reference
- [`../deploy-to-vercel/SKILL.md`](../deploy-to-vercel/SKILL.md) - typical storefront-half companion for Railway-backed Medusa
- [`../cloudflare-deployment/SKILL.md`](../cloudflare-deployment/SKILL.md) - for storefronts on Cloudflare Pages or product-image storage on R2
- [Railway CLI reference](https://docs.railway.com/reference/cli-api) - canonical command docs
- [Railway templates catalog](https://railway.com/templates) - official + community templates, search for "Medusa"
