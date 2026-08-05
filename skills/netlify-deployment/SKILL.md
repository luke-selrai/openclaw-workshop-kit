---
name: netlify-deployment
description: Connect Netlify to Claude by installing the Netlify CLI and minting a Personal Access Token persisted as NETLIFY_AUTH_TOKEN — one dashboard sign-in, then every session and sub-agent is authenticated. Use when the user says 'connect netlify', 'deploy to netlify', 'netlify deploy', 'netlify drop', or 'publish to netlify', or wants a static site or plain HTML folder live and the token isn't in place yet. Once connected, deploys run directly through the netlify CLI.
allowed-tools: Bash,PowerShell,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - netlify
    - deployment
    - static-sites
    - installer
    - pat
  pairs-with:
    - skill: render-deployment
      reason: Same install+auth shape — Render is the alternative when a long-running server or managed Postgres is required
    - skill: cloudflare-deployment
      reason: Cloudflare Pages is the alternative static host when the user is already on the Cloudflare stack
---

# Netlify Deployment

## Purpose

**This skill connects Claude Code to a Netlify account and then deploys static sites hands-off.** After the user runs it once, the agent (me) can run any `netlify` CLI command on the user's behalf — create sites, push draft deploys, promote to production, manage env vars, tail deploy logs — without further setup or human input.

The whole flow costs **one human moment**: signing in to the Netlify dashboard once so the agent can mint a Personal Access Token. If the browser is already signed in, even that is zero clicks. There is no `netlify login` step — the PAT *is* the credential, and because it lives in the `NETLIFY_AUTH_TOKEN` env var, non-interactive sub-agents, scheduled tasks, and CI-style runs are authenticated from day one.

## Territory

This skill owns **standalone static sites and loose folders** — plain HTML/CSS/JS folders, one-off client pages, prototypes, and build outputs (`dist/`, `build/`) that need a public URL. Inside a `full-stack-builder-pack` project, Vercel is the deploy target and this skill defers to the pack's own deploy flow.

## What this skill does NOT do

- **It does not use `netlify login` / browser OAuth sessions.** The PAT covers interactive and non-interactive use alike; a second credential would just be a second thing to expire.
- **It does not register Netlify's MCP server.** The CLI covers the full surface (sites, deploys, env, functions, logs) and the PAT authenticates it everywhere. One folder, one skill, one credential.
- **It does not create Netlify accounts.** Signup flows have email verification and bot checks that automation handles badly. If no account exists, the agent says so plainly, points at https://app.netlify.com/signup, and waits.
- **It does not maintain a long catalogue of Netlify CLI commands.** The agent reads `netlify <cmd> --help` at runtime when it needs exact syntax for the installed version.

---

## State File

The skill tracks machine-level progress at `~/.claude/state/netlify-deployment.json`. Schema:

```json
{
  "version": 1,
  "netlify_cli_installed": true,
  "netlify_cli_version": "17.x.x",
  "token_persisted": true,
  "token_name": "claude-code-<hostname>",
  "account_email": "user@example.com",
  "account_slug": "users-team-slug",
  "last_verified_at": "2026-08-05T10:00:00Z"
}
```

**Machine-level facts only.** Which folder deploys to which site is NOT tracked here — that is owned by Netlify's native `netlify link`, which writes `.netlify/state.json` (the site ID) into each project folder. One source of truth per fact.

Always read the state file first. Skip steps that are already done unless the user asks for a re-install or re-auth.

---

## Part 1 — Quick Check (idempotent re-entry)

Before doing anything else, run these checks in order:

1. **Read** `~/.claude/state/netlify-deployment.json` (if exists).
2. **Run** `netlify --version`. If it returns a version, the CLI is installed.
3. **Check** the `NETLIFY_AUTH_TOKEN` env var (`$env:NETLIFY_AUTH_TOKEN` / `$NETLIFY_AUTH_TOKEN`). On Windows, if it's empty, re-read the User scope before concluding the token is missing — harness-spawned shells can inherit an environment that predates the persist: `$env:NETLIFY_AUTH_TOKEN = [System.Environment]::GetEnvironmentVariable('NETLIFY_AUTH_TOKEN','User')`. If non-empty, validate with `netlify status` — it should print the account name and email.

If everything is wired up, say:
> "Netlify is already set up. You're signed in as [email]. Want me to deploy something, or list your sites?"

Update `last_verified_at` and stop. Do not re-run install steps.

Otherwise, the gaps map to the parts below:
- CLI missing → Part 2
- Token missing or invalid → Part 3

---

## Part 2 — Install the Netlify CLI

The CLI is an npm package, so the installer scripts bootstrap Node.js 20+ first if the machine doesn't have it, then install `netlify-cli` globally. Both scripts are idempotent — re-running with everything installed is a no-op.

Say:
> "I'm going to install the Netlify command-line tool now. This takes a minute or two."

Run the helper script for the user's OS:

- **macOS / Linux:** `bash scripts/install-netlify-unix.sh`
- **Windows:** `powershell -ExecutionPolicy Bypass -File scripts/install-netlify-windows.ps1`

Then verify with `netlify --version`. If it says "command not found" after a successful install, the terminal needs a refresh:
> "The terminal needs a refresh. Please close this terminal window and open a new one, then tell me to continue."

Update state file: `netlify_cli_installed: true`, `netlify_cli_version: "<version>"`.

---

## Part 3 — Mint the Personal Access Token (the only human moment)

`NETLIFY_AUTH_TOKEN` is the single credential. Mint it by driving the Netlify dashboard with Playwright — no copy-paste, and the token is never shown in chat.

### Step 1: Detect existing credentials FIRST

1. If `NETLIFY_AUTH_TOKEN` is set, validate via `netlify status`. Valid → skip to Part 4.
2. If it's set but invalid (401 / "Not logged in"), the token was revoked or expired:
   > "Your old Netlify token isn't valid anymore. I'll mint a fresh one — you may need to sign in once."

### Step 2: Drive the PAT page

Say:
> "I'm going to open the Netlify dashboard to create an access key for this machine. If you're already signed in, you won't have to do anything — otherwise sign in once and I'll do the rest. If you don't have a Netlify account yet, tell me and sign up first at app.netlify.com/signup (the free tier is fine)."

Sequence:

1. **Launch Playwright** (non-headless) and navigate to:
   ```
   https://app.netlify.com/user/applications#personal-access-tokens
   ```
2. **If a login page appears**, wait for the user to sign in (poll the page state; do not time out before 180 s). If they say they have no account, stop here and wait — no signup automation.
3. **Snapshot the page and find the Personal access tokens section.** Work from the live accessibility tree, not memorised selectors — Netlify redesigns this page periodically. Click **New access token**.
4. **Name the token** `claude-code-<hostname>` (machine hostname, so the user can later see which laptop minted it). If the form has an expiration option, pick the longest available.
5. **Click Generate token** and read the token from the DOM immediately — it is shown exactly once.
6. **Persist without ever echoing the token into chat:**
   - **Windows** — User env var + PowerShell profile + current session (any previous token line is replaced, not stacked):
     ```powershell
     [System.Environment]::SetEnvironmentVariable('NETLIFY_AUTH_TOKEN', '<captured-token>', 'User')
     if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
     $lines = @(Get-Content $PROFILE) -notmatch 'NETLIFY_AUTH_TOKEN'
     Set-Content -Path $PROFILE -Value ($lines + "`$env:NETLIFY_AUTH_TOKEN = '<captured-token>'")
     $env:NETLIFY_AUTH_TOKEN = '<captured-token>'
     ```
   - **macOS / Linux** — update `~/.zshrc` and `~/.bashrc`, whichever exist (the login shell's rc is created if neither does), replacing any previous token line:
     ```bash
     [ -f "$HOME/.zshrc" ] || [ -f "$HOME/.bashrc" ] || touch "$HOME/.$(basename "${SHELL:-bash}")rc"
     for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
       [ -f "$rc" ] || continue
       grep -v 'NETLIFY_AUTH_TOKEN' "$rc" > "$rc.tmp"; mv "$rc.tmp" "$rc"
       echo 'export NETLIFY_AUTH_TOKEN="<captured-token>"' >> "$rc"
     done
     export NETLIFY_AUTH_TOKEN="<captured-token>"
     ```
7. **Close the Playwright browser** so the token is no longer on screen.
8. **Update state file:** `token_persisted: true`, `token_name: "claude-code-<hostname>"`.

Confirm only:
> "Done. The key is saved to your environment — future Claude sessions and background tasks can use Netlify without asking you to sign in again."

**To rotate or revoke later:** the user deletes the token at https://app.netlify.com/user/applications and re-runs this skill.

### Step 3: Verify

```bash
netlify status
```

Should print the account name, email, and teams. Record `account_email` and `account_slug` in the state file, update `last_verified_at`, and tell the user in plain English:
> "You're connected as [email]. Netlify is fully wired up."

---

## Part 4 — Bind a folder to a site (`netlify link`)

Every project folder that deploys to Netlify gets bound **once** with Netlify's native linking — after that, deploys from that folder always target the right site.

1. **Already linked?** If `<folder>/.netlify/state.json` exists, read the site ID and confirm with `netlify status` (run inside the folder). Done — never re-link.
2. **Site exists on the account but folder not linked?** `netlify link --id <site-id>` (find the ID via `netlify sites:list --json`, matching on name/URL).
3. **No site yet?** Create one non-interactively, then link:
   ```bash
   netlify sites:create --name <site-name> --account-slug <account_slug>
   netlify link --id <new-site-id>
   ```
   Site names are global across Netlify (`<name>.netlify.app`) — if taken, suffix with the team slug or a short qualifier and tell the user what the final name is.

**Note on Netlify Drop sites:** anonymous drag-and-drop sites (app.netlify.com/drop) that were never claimed do not belong to any account — the CLI cannot adopt them. Create a fresh site instead; the old Drop URL simply expires.

If the folder is inside a git repo, make sure `.netlify/` is gitignored (the CLI usually handles this; check).

---

## Part 5 — Deploy

**The deploy gate, stated once:** a **draft deploy runs unprompted** — it's private, free, and reversible by ignoring it. A **production deploy runs only when the user's instruction actually says so** ("deploy to prod", "publish it", "make it live", "push it live"). When the instruction does say so, go straight to prod without a second confirmation.

### Draft (default)

```bash
netlify deploy --dir=<folder> --json
```

- `--dir` points at the folder whose *contents* are the site root (for a plain static site, the folder itself; for a built app, `dist/`/`build/`).
- If the folder has a `netlify.toml` with a build command, the CLI may run it first — pass `--no-build` for plain static folders (check `netlify deploy --help` for the installed version's default).
- Parse `deploy_url` from the JSON output and hand it to the user:
  > "Draft is live at [deploy_url] — check it. Say 'publish it' and I'll put it on the real URL."

### Production (on explicit say-so)

```bash
netlify deploy --dir=<folder> --prod --json
```

Report the live `url` from the JSON output.

### Rollback

Netlify keeps every deploy forever. To revert: `netlify rollback` (restores the previous production deploy) where the installed CLI supports it — check `netlify rollback --help`; otherwise open the site's Deploys page in the dashboard and click **Publish deploy** on any earlier deploy.

---

## Part 6 — What the user can ask for next

```
"Deploy the website folder."                    → draft deploy, preview URL back
"Publish it." / "Make it live."                 → promote to production
"List my Netlify sites."
"Set FOO=bar on the website's environment."     → netlify env:set FOO bar
"What env vars does the site have?"             → netlify env:list
"Show me the last deploy log."                  → netlify logs:deploy / netlify watch
"Roll back the website."                        → netlify rollback (or dashboard)
"Add the custom domain example.com."            → netlify domains guidance + dashboard for DNS
"Open the site's dashboard."                    → netlify open
```

The agent runs these directly via the `netlify` CLI. For commands it isn't sure about, it runs `netlify <command> --help` first to check exact syntax for the installed version.

---

## Part 7 — Quick CLI Reference

The minimal vocabulary to reach for first:

```bash
# Auth + identity (all read NETLIFY_AUTH_TOKEN automatically)
netlify status                          # who am I, which team, which site is linked here
netlify sites:list --json               # every site on the account

# Site binding
netlify sites:create --name <name> --account-slug <slug>
netlify link --id <site-id>             # bind current folder to a site
netlify unlink                          # unbind

# Deploys
netlify deploy --dir=<folder> --json            # DRAFT — private preview URL
netlify deploy --dir=<folder> --prod --json     # PRODUCTION — public URL
netlify rollback                                # restore previous production deploy
netlify watch                                   # wait for an in-flight deploy to finish

# Env vars (per linked site)
netlify env:list
netlify env:set KEY value
netlify env:unset KEY

# Misc
netlify open                            # open the linked site's dashboard
netlify open:site                       # open the live site itself
netlify logs:deploy                     # most recent deploy log
```

When in doubt: `netlify <command> --help`.

---

## Part 8 — Troubleshooting

| Problem | Fix |
|---|---|
| `netlify: command not found` | Shell needs restart — open a new terminal. If still missing, re-run the OS installer script. |
| `npm install -g` permission error | Windows: run PowerShell as administrator. macOS/Linux: fix npm prefix or use the script's `npx netlify` fallback. |
| `netlify status` → "Not logged in" with token set | Token revoked or malformed. Re-run Part 3 to mint a fresh one. |
| 401 / `Unauthorized` on any command | Same — token invalid. Re-mint via Part 3. |
| `netlify deploy` hangs asking questions | Folder isn't linked, so the CLI went interactive. Ctrl-C, run Part 4 (link), retry. |
| Site name already taken on `sites:create` | Names are global. Suffix with team slug or qualifier, tell the user the final name. |
| Draft URL works, prod shows old version | Draft ≠ prod. Promote with `netlify deploy --dir=<folder> --prod`. |
| `--no-build` unrecognised | Older CLI. Drop the flag — without a `netlify.toml` build command it uploads the folder as-is anyway. |
| Deploy shows wrong site | Read `<folder>/.netlify/state.json`, compare against `netlify sites:list`; `netlify unlink` + re-link if wrong. |
| Corporate proxy / `Failed to fetch` | Set `HTTPS_PROXY=http://proxy.corp:port` before running netlify. |
| PAT page layout changed, mint fails | Work from a fresh Playwright snapshot — the flow is always: Applications page → Personal access tokens → New access token → name → generate → read once. |
| Old Drop-site URL stopped working | Anonymous Drop sites expire unclaimed. The CLI-created site is the permanent home; update any bookmarks. |

When an error occurs, say:
> "No problem — let me try a different way."

Then diagnose silently. Never paste raw stack traces at the user — translate everything into plain English.

For deeper troubleshooting see `troubleshooting.md` next to this file.

---

## Behaviour Guidelines

- **Read the state file first** — skip steps already done. Idempotent: never re-install, re-mint, or re-link what already exists.
- **`netlify status` is the session opener** when the user asks for Netlify work — it confirms auth and the linked site in one call.
- **Draft deploys are free actions; production deploys need the user's word** — see the deploy gate in Part 5. That gate is the skill's only confirmation point.
- **Never echo the token** — capture it silently in Part 3, write it to disk, confirm only that it succeeded. Never write it to any file inside a project folder.
- **Use the `netlify` CLI directly** — no wrapper scripts, no MCP registration, no official skills bundles. One folder, one skill, one credential.
- **One step at a time** — say what's happening, do it, report the result. Don't dump the whole flow at the user.
- **Plain English only** — "access key" not "PAT", "draft link" not "deploy preview permalink", when talking to the user.
- **One question at a time** — pick the highest-value question, default the rest, state assumptions.

---

## References

- [Netlify CLI reference](https://docs.netlify.com/cli/get-started/)
- [netlify deploy docs](https://docs.netlify.com/cli/manage-deploys/)
- [Personal access tokens](https://app.netlify.com/user/applications)
- [netlify.toml reference](https://docs.netlify.com/configure-builds/file-based-configuration/)
- [Pricing / free tier](https://www.netlify.com/pricing/)
