---
name: render-deployment
description: Hands-off assistant that connects Claude Code to the user's Render.com account through the Render CLI. Installs the Render CLI, signs the user in via one browser click, mints a long-lived API key via the Render dashboard so non-interactive sub-agents can use Render too, then steps out of the way. After setup is done, the agent uses the `render` CLI directly on the user's behalf to list services, redeploy, tail logs, open psql sessions, etc. — no extra skills, no scattered folders. Use this skill when the user asks to connect Render, set up the Render CLI, deploy to Render, log in to Render, or mentions any Render developer service. MANDATORY TRIGGERS — invoke immediately on any of these phrases (case-insensitive, partial match counts) - 'connect render', 'set up render', 'install render cli', 'deploy to render', 'render login', 'render postgres', 'render cron', 'render workers', 'render services', 'render workspace'.
allowed-tools: Bash,PowerShell,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - render
    - render-com
    - deployment
    - installer
    - oauth
  pairs-with:
    - skill: cloudflare-deployment
      reason: Similar install+auth shape — Cloudflare is the Workers/Pages alternative when long-running servers are not required
    - skill: vercel-deployment
      reason: Vercel is the most common alternative to Render for full-stack apps that do not need persistent processes or managed databases
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Render auth, install, or build errors
---

# Render Deployment

## Purpose

**This skill is a hands-off assistant for connecting Claude Code to a Render.com account.** After the user runs it once, the agent (me) can run any `render` CLI command on the user's behalf — list services, trigger redeploys, tail logs, open psql sessions, manage cron jobs, etc. — without further setup or human input.

The whole flow takes one click in a browser (to approve `render login`) and one second click in a browser (to mint a long-lived API key from the Render dashboard). After that, hands-off.

## What this skill does NOT do

- **It does not install Render's official 21-skill bundle** (`render-deploy`, `render-debug`, etc.). That bundle scatters 21 top-level directories under `~/.claude/skills/` and `render skills remove --all` is too aggressive — it deletes neighbouring skills too. Instead, the agent uses the `render` CLI directly.
- **It does not deploy from a local folder.** Render's v2.17 CLI has no `render deploy <yaml>` command — every service is connected to a git repository. Once the user pushes their code to git, the agent can run `render services create --repo <url>` to register the service, then `render deploys create <service-id>` for redeploys.
- **It does not maintain a long catalogue of Render CLI commands.** The Render docs already cover that. The agent reads `render <cmd> --help` at runtime when it needs to know more.

---

## State File

The skill tracks progress at `~/.claude/state/render-deployment.json` so re-runs know what's already done. Schema:

```json
{
  "version": 1,
  "render_cli_installed": true,
  "render_cli_version": "2.17.x",
  "authenticated": true,
  "workspace_id": "tea_abc123",
  "workspace_name": "Selr AI",
  "account_email": "user@example.com",
  "api_key_persisted": true,
  "api_key_name": "claude-code-<hostname>",
  "last_verified_at": "2026-05-14T10:00:00Z"
}
```

Always read this file first. Skip steps that are already done unless the user asks for a re-install or re-auth.

---

## Part 1 — Quick Check (idempotent re-entry)

Before doing anything else, run these checks in order:

1. **Read** `~/.claude/state/render-deployment.json` (if exists).
2. **Run** `render --version`. If it returns a version, the CLI is installed.
3. **Run** `render workspace current`. If it prints the active workspace, the user is signed in. (To enumerate every workspace the account can see, use `render workspaces` — plural, no subcommand.)
4. **Check** the User-scope env var `RENDER_API_KEY`. If non-empty, the long-lived key is persisted and sub-agents can use Render.

If everything is wired up, say:
> "Render is already set up. You're signed in as [email] with workspace [workspace name]. Want me to run a render command for you, or list your services?"

Update `last_verified_at` and stop. Do not re-run install steps.

Otherwise, the gaps map to the parts below:
- CLI missing → Part 2
- Auth missing → Part 3 (Step 5)
- API key missing → Part 3 (Step 7)

---

## Part 2 — Install the Render CLI

### Step 1: Detect the OS and run the installer script

The Render CLI ships an OS-specific installer.

- **macOS:** Homebrew tap (`brew tap render-oss/render && brew install render`)
- **Linux:** install script (`curl -fsSL https://render.com/install.sh | sh`)
- **Windows:** direct download from the official GitHub release zip. **The Windows installer tries winget and scoop first but falls through automatically** — neither ships a Render manifest as of CLI v2.17.

Say:
> "I'm going to install the Render command-line tool now. This will take about 30 seconds."

Then run the helper script for the user's OS:

- **macOS / Linux:** `bash scripts/install-render-unix.sh`
- **Windows:** `powershell -ExecutionPolicy Bypass -File scripts/install-render-windows.ps1`

Both scripts are idempotent — re-running with the CLI already installed and ≥ 2.10 is a no-op.

### Step 2: Verify install

Run `render --version`. If it returns a version, say:
> "That worked. Render CLI version [X.Y.Z] is installed."

If it says "command not found":
> "The terminal needs a refresh. Please close this terminal window and open a new one, then tell me to continue."

Update state file: `render_cli_installed: true`, `render_cli_version: "<version>"`.

### Step 3: Confirm version ≥ 2.10

CLI 2.10+ is needed for stable `render workspace`, `render workspaces`, and `render services` semantics. If the installed version is older, re-run the installer script — it pulls the latest GitHub release.

---

## Part 3 — Authenticate (the only human moments)

### Step 4: Detect existing credentials FIRST

Before opening a browser, check:

1. **`echo $RENDER_API_KEY`** (Bash) or **`$env:RENDER_API_KEY`** (PowerShell). If non-empty, validate via `render workspace current`.
2. **Render CLI config file:**
   - macOS / Linux: `~/.render/config.yaml`
   - Windows: `$env:USERPROFILE\.render\config.yaml`
3. **`render workspace current`** — if it prints the active workspace, skip to Step 6 or Step 7 (depending on what is still missing).

If `render workspace current` returns `failed to create client: run \`render login\` to authenticate` / 401 / token invalid:
> "Your old Render login expired. I'll sign you in fresh."

Purge stale credentials:
```bash
render logout
```

Then continue to Step 5.

### Step 5: OAuth login — first human moment

Say:
> "I'm going to sign you in to Render now. A browser window will pop open. Click the **Generate Token** / **Approve** button, then come back here. That's the only thing you need to do."

Run:

```bash
render login
```

This opens https://render.com/cli/login in the user's default browser. After the user approves, the CLI stores a session token at `~/.render/config.yaml`.

**While waiting**, poll the Render CLI config file every 2 seconds (max 120 seconds). When the file appears (or its mtime updates) AND `render workspace current` succeeds, the user has approved. Say:
> "That worked. You're signed in."

**If the browser doesn't open within 30 seconds**, fall back to Part 5 (Playwright drives the OAuth URL).

**If the user closes the browser without approving**, say:
> "Looks like the sign-in didn't finish. Want me to try again?"

### Step 6: Pick the default workspace

Run:

```bash
render workspaces --output json
```

(`workspaces` is plural and takes no subcommand — it enumerates every workspace the account can see. The singular `render workspace` only has `current` and `set`.)

If the user has exactly one workspace, set it as the default automatically:

```bash
render workspace set <workspace-id>
```

If they have multiple:
> "You're signed in to Render. I can see [N] workspaces: [list names]. Which one should I use as default for this machine?"

Save the chosen workspace's id + name to the state file.

### Step 7: Mint a long-lived API key — second (and last) human moment

`render login` writes a session token to the CLI config, but non-interactive sub-agents (CI jobs, scheduled tasks, background scripts) need an env var `RENDER_API_KEY` they can read on any shell. The Render CLI v2.17 has **no** `render api-keys` subcommand — API keys can only be minted through the Render dashboard. Drive that with Playwright; no copy-paste required.

Say:
> "Last setup step — I'm going to mint a long-lived key so future Claude tasks can talk to Render without re-asking you to sign in. A browser will open the Render API-keys page. If you're already signed into the dashboard there, you won't have to do anything; otherwise you'll see a normal Render login page. I'll do the rest."

Sequence the agent must run:

1. **Launch Playwright Chromium** in non-headless mode and navigate to:
   ```
   https://dashboard.render.com/u/settings#api-keys
   ```
2. **If a login page appears**, wait for the user to sign in. The OAuth session from Step 5 is a CLI token, separate from the browser cookie — the dashboard may still require its own sign-in.
3. **Detect the "Create API Key" button** on the API Keys section and click it.
4. **Name the key** `claude-code-<hostname>` — use the machine hostname so the user can later see which laptop minted it.
5. **Click Create** and immediately read the generated key from the DOM. It is shown exactly once — capture it before any navigation.
6. **Persist the key without ever echoing it back to the user in chat**:
   - **Windows** — set it permanently for the user AND in the current PowerShell profile:
     ```powershell
     [System.Environment]::SetEnvironmentVariable('RENDER_API_KEY', '<captured-key>', 'User')
     if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
     Add-Content -Path $PROFILE -Value "`n`$env:RENDER_API_KEY = '<captured-key>'"
     ```
   - **macOS / Linux** — append to `~/.zshrc` AND `~/.bashrc` (whichever exist):
     ```bash
     echo 'export RENDER_API_KEY="<captured-key>"' >> ~/.zshrc
     echo 'export RENDER_API_KEY="<captured-key>"' >> ~/.bashrc
     ```
7. **Close the Playwright browser** so the key is no longer on screen.
8. **Update state file:**
   - `api_key_persisted: true`
   - `api_key_name: "claude-code-<hostname>"`

Confirm only:
> "Done. The key is saved to your environment so future Claude tasks can use it. You'll never have to paste anything by hand."

**To rotate or revoke the key later**, send the user to https://dashboard.render.com/u/settings#api-keys — they can delete it there and re-run this skill to mint a new one.

---

## Part 4 — Playwright Fallback for `render login`

Use this path ONLY when `render login` cannot open the browser by itself — e.g.:
- WSL with no display server
- Remote SSH session
- Locked-down corporate machine
- `render login` printed an OAuth URL but no browser launched

Steps:

1. **Capture the OAuth URL** from `render login`'s output. The CLI prints something like:
   ```
   Opening browser to https://render.com/cli/login?token=...
   ```
2. **Launch Playwright Chromium** in non-headless mode and navigate to the captured URL.
3. **Wait for the user** to click Approve. Render's CLI runs a localhost callback server — once the dashboard redirects to `http://localhost:<port>/cli-callback?...`, the CLI writes the session token to `~/.render/config.yaml`.
4. **Verify** with `render workspace current`.
5. **Continue to Step 6** (workspace pick) and **Step 7** (dashboard API-key mint via Playwright — same browser-driver approach but for a different page).

---

## Part 5 — Read-only Verification

After auth is confirmed AND the API key is persisted, run a real Render call to prove the wiring works end to end. This is read-only — nothing is created or changed.

Say:
> "Last thing — let me confirm everything is wired up."

Run:

```bash
render workspace current
render whoami
render services --output json
```

Print results in plain English:
> "Workspace: [name]. Email: [email]. You have [N] existing services. Render is fully wired up."

Stop. The user is good to go. The next time they want to do anything on Render — list services, trigger a redeploy, tail logs, create a Postgres database — they just ask in chat and the agent runs the right `render` CLI command directly.

---

## Part 6 — What the user can ask for next

Once setup is complete, the user can say things like:

```
"List my Render services."
"Show me the latest deploys for my 'api' service."
"Redeploy my 'api' service."
"Tail logs for my 'api' service."
"Open a psql session to my 'prod' Postgres database."
"Restart my 'worker' service."
"Connect this GitHub repo as a Render web service."
"Create a Postgres database called 'prod' in oregon."
```

The agent runs these directly via the `render` CLI — no extra skills needed. For commands the agent isn't sure about, it runs `render <command> --help` first to check the exact syntax for the installed CLI version.

---

## Part 7 — Quick CLI Reference

The minimal vocabulary the agent should reach for first:

```bash
# Auth + session
render login                            # OAuth via browser
render logout                           # clear session token
render whoami                           # show current user (email, account info)
render workspace current                # active workspace
render workspaces                       # every workspace the account can see (plural, no subcmd)
render workspace set <workspace-id>     # change active workspace

# Listing
render services                         # all services + datastores in active workspace
render services --output json           # same, JSON for parsing
render projects                         # projects in active workspace
render deploys list <service-id>        # past deploys for a service

# Redeploys + restarts
render deploys create <service-id>      # trigger a redeploy of an existing service
render restart <service-id>             # restart a service by resource ID

# Logs
render logs --resources <service-id> --tail              # stream new logs
render logs --resources <service-id> --limit 200         # last 200 lines

# Sessions
render psql <postgres-id>               # psql session to a Render Postgres DB
render pgcli <postgres-id>              # pgcli session
render kv-cli <kv-id>                   # session to a Render Key Value instance
render ssh <service-id>                 # SSH into a service instance

# Service creation (needs a git repo URL — no local-folder deploys)
render services create --type web_service --repo <url> --runtime node --build-command "npm install" --start-command "npm start" --output json
render services create --type cron_job --repo <url> --cron-schedule "0 7 * * *" --cron-command "node scripts/daily-report.js" --output json
render services create --type background_worker --repo <url> --start-command "node worker.js" --output json
```

What is **NOT** in the v2.17 CLI (don't try these — they will fail):
- `render deploy` (singular) — use `render deploys create <service-id>` instead
- `render api-keys ...` — keys are dashboard-only; this skill's Part 3 Step 7 drives that flow via Playwright
- `render postgres list / create / connection-info` — Postgres is created via `render services create --type postgres ...`; listed via `render services`
- `render redis list / create` — same; use `render services` and `render services create`
- `render env-vars ...` — set env vars via `render services create --env-var KEY=VALUE` or the dashboard
- `render cron-jobs runs list` — read cron runs via `render logs` against the cron service id
- `render services delete / restart` as subcommands — use top-level `render restart`; for delete, use the dashboard

When in doubt, the agent runs `render <command> --help`.

---

## Part 8 — Troubleshooting

| Problem | Fix |
|---|---|
| `render: command not found` | Shell needs restart — open a new terminal. If still missing, re-run the OS installer script. |
| Windows installer fails on winget | Expected — `Render.RenderCLI` is not in winget as of CLI v2.17. The script falls through to the GitHub release zip automatically. Watch for "Found cli_v*.exe inside the release zip" in the output. |
| `Authentication error` / 401 / `failed to create client` | Token expired — run `render logout` then re-run this skill from Step 4. |
| Browser doesn't open on `render login` | Fall back to Part 4 (Playwright drives the same OAuth URL). |
| `Failed to fetch` / corporate proxy | Set `HTTPS_PROXY=http://proxy.corp:port` before running render. |
| Multiple workspaces, wrong one is default | Run `render workspace set <workspace-id>` to switch. |
| `localhost:<port> already in use` during login | Another `render login` is running its callback server. Kill it (look for a stray `render` process) and try again. |
| Deploy fails: "No workspace selected" | Run `render workspace set <workspace-id>`. |
| Free-tier service spinning down after inactivity | Expected — free web services sleep after 15 min idle. Either upgrade plan or move to a background worker / cron. |
| `unknown command "deploy"` | The CLI never had a singular `render deploy`. Use `render deploys create <service-id>` to redeploy an existing service. |
| `unknown command "api-keys"` | API keys are dashboard-only. Re-run this skill — Step 7 mints a key via Playwright. |
| `render skills remove --all` deletes neighbouring skills | Known footgun in CLI v2.17. **Never run `render skills install` or `render skills remove`** while using this skill — the `--all` removal deletes any folder under `~/.claude/skills/` whose name matches Render's catalogue, including `render-deployment` itself. This is why this skill explicitly avoids the official bundle. |

When an error occurs, say:
> "No problem — let me try a different way."

Then diagnose silently. Never paste raw stack traces at the user — translate everything into plain English.

For deeper troubleshooting see `troubleshooting.md` next to this file.

---

## Behaviour Guidelines

- **Always run `render workspace current` first** at the start of a session to confirm the user is signed in.
- **Read the state file** before doing any work — skip steps already done.
- **Use the `render` CLI directly to do Render work** — don't suggest installing Render's official skills bundle, don't create wrapper skills, don't fork the deploy logic into other skill folders. One folder, one skill.
- **Confirm before destructive actions** — even though the CLI can't delete services in v2.17, the agent still confirms before triggering anything that costs money or changes state (creating paid plans, redeploys that auto-deploy from main, etc.).
- **Workspace context matters** — if the user has multiple workspaces, confirm which one before deploying.
- **Auth errors** → `render logout`, then re-run this skill from Step 4.
- **CLI not found** → restart shell or reinstall via the OS installer.
- **One step at a time** — do not dump all instructions at once. Say what to do, wait for confirmation, then give the next step.
- **Plain English only** — translate `render.yaml`, "OAuth", "workspace", etc. into business terms when explaining to the user.
- **Idempotent** — always check before creating. Never re-install, re-auth, or re-mint a key that already exists.
- **One question at a time** — never ask the user a list of questions. Pick the highest-value one, make a sensible default for the rest, state assumptions.
- **Never echo API keys** — capture them silently in Step 7, write them to disk, confirm only that it succeeded.

---

## References

- [Render CLI reference](https://render.com/docs/cli)
- [Render LLM support](https://render.com/docs/llm-support)
- [Render API docs](https://api-docs.render.com/)
- [Render dashboard — API keys](https://dashboard.render.com/u/settings#api-keys)
- [Regions](https://render.com/docs/regions)
- [Free tier limits](https://render.com/pricing)
