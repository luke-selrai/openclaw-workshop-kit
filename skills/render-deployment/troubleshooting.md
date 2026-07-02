# Render Deployment - Troubleshooting

Plain-English fixes for the most common problems. The skill itself should diagnose silently and never paste raw errors at the user - this doc is the agent's reference, not the user's.

---

## Install issues

### `render: command not found` after installer ran

PATH wasn't refreshed. Two fixes:

1. **Easiest:** close the terminal and open a new one.
2. **Force-refresh in the current terminal:**
   - macOS / Linux: `source ~/.bashrc` or `source ~/.zshrc`
   - Windows PowerShell: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`

If still missing on Windows, check whether the installer placed `render.exe` under `%USERPROFILE%\bin\` and confirm that folder is on the user PATH.

### `winget install Render.RenderCLI` fails with "No applicable installer"

Expected as of CLI v2.17 - `Render.RenderCLI` is not in the winget catalogue. The Windows install script handles this automatically: when winget reports "No package found", it falls through to scoop, then to a direct download from `https://api.github.com/repos/render-oss/cli/releases/latest`.

If you want to force the GitHub-release path manually:
1. Download the latest `cli_*_windows_amd64.zip` from https://github.com/render-oss/cli/releases
2. Extract the `cli_v*.exe` inside, rename it to `render.exe`
3. Copy to `%USERPROFILE%\bin\` and ensure that folder is on user PATH

To check whether scoop is on the machine:
```powershell
Get-Command scoop -ErrorAction SilentlyContinue
```

To install scoop:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb get.scoop.sh | iex
```

### Homebrew tap fails on macOS

```bash
brew tap render-oss/render
# Error: Failed to tap render-oss/render
```

Causes:
- Old Homebrew - run `brew update` first.
- Apple silicon vs Intel mismatch - make sure brew is in the right location (`/opt/homebrew/bin/brew` on Apple silicon, `/usr/local/bin/brew` on Intel).

If the tap doesn't exist, fall back to the install script:

```bash
curl -fsSL https://render.com/install.sh | sh
```

### Linux install script needs sudo

The `curl | sh` installer writes to `/usr/local/bin`. If that fails:

```bash
curl -fsSL https://render.com/install.sh | RENDER_INSTALL_DIR=$HOME/.local/bin sh
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### CLI version is below 2.10

CLI 2.10+ is needed for stable `render workspace`, `render workspaces`, and `render services` semantics. Upgrade:

- macOS: `brew upgrade render`
- Linux: re-run `curl -fsSL https://render.com/install.sh | sh`
- Windows: re-run `scripts/install-render-windows.ps1` - it detects an existing-but-too-old install and pulls the latest GitHub release.

---

## Authentication issues

### Browser doesn't open on `render login`

Causes:
- WSL with no DISPLAY
- Remote SSH session
- Corporate browser lockdown
- Default browser misconfigured

**Fix:** fall back to Playwright. Capture the OAuth URL from render's stdout (it prints `Opening browser to https://render.com/cli/login?token=...`), open it in a Playwright-controlled Chromium window, complete the click, let render's localhost callback finish the loop.

### `localhost:<port> already in use` during login

Another render instance is running its callback server. Either:
- Kill the other process: `pkill -f 'render login'` (macOS/Linux) or `Get-Process render | Stop-Process` (Windows, carefully)
- Pass a different callback port if the CLI supports `--port` - check `render login --help` for the installed version.

### Token returns 401 / "unauthorized"

Token expired or was revoked from the dashboard. Purge and re-login:

```bash
render logout
render login
```

If env var is set, also clear it before re-login:
- macOS/Linux: `unset RENDER_API_KEY`
- Windows: `Remove-Item Env:\RENDER_API_KEY`

To clear the persistent User env var on Windows:
```powershell
[System.Environment]::SetEnvironmentVariable('RENDER_API_KEY', $null, 'User')
```

### Login completes but `render workspace current` still fails

Two possibilities:
1. **Config wrote to wrong path** - check both `~/.render/config.yaml` (macOS/Linux) and `$env:USERPROFILE\.render\config.yaml` + `%APPDATA%\Render\config.yaml` (Windows). Delete the older one.
2. **Workspace not selected** - `render workspaces` (plural) lists every workspace the account can see and always works without a selection, but `render workspace current` and most other commands need an active workspace. Run `render workspace set <workspace-id>`.

### API key shown only once - what if the user lost it?

Render shows an API key exactly once at creation time. In CLI v2.17 there is no `render api-keys` subcommand, so deletion and creation both happen through the dashboard:
1. Open https://dashboard.render.com/u/settings#api-keys
2. Delete the old `claude-code-<hostname>` key from the list.
3. Click "Create API Key", name it the same, copy the new key.
4. Re-run this skill from Step 7 - the Playwright flow will mint and persist a fresh key, or you can manually set:
   ```powershell
   [System.Environment]::SetEnvironmentVariable('RENDER_API_KEY', '<new-key>', 'User')
   ```
   ```bash
   echo 'export RENDER_API_KEY="<new-key>"' >> ~/.zshrc
   ```

---

## No-browser / headless environments

If the user is on a remote box (SSH, Codespaces, GitHub Codespaces, devcontainer, WSL without WSLg):

1. Run `render login`. The CLI prints "Opening browser to https://render.com/cli/login?token=..." and waits.
2. Have the user copy that URL to a browser on their local machine.
3. The user approves in their browser; the localhost callback completes on the remote box and the CLI writes its config.
4. If the remote box can't accept the localhost callback (rare - usually corporate firewall blocking loopback), fall back to the API-key dashboard path below.

API-key dashboard path (for fully headless or firewalled environments):
1. User opens https://dashboard.render.com/u/settings#api-keys on any device with a browser.
2. Clicks "Create API Key", names it `claude-code-<hostname>`, copies the key.
3. On the remote box, the user pastes the key into a prompt the skill runs, or sets it directly:
   ```bash
   export RENDER_API_KEY="<the-key>"
   echo 'export RENDER_API_KEY="<the-key>"' >> ~/.bashrc
   ```
4. Verify with `render workspace current`.

---

## Corporate proxy / firewall

Set proxy env vars before any render command:

```bash
export HTTPS_PROXY=http://proxy.corp.example.com:8080
export HTTP_PROXY=http://proxy.corp.example.com:8080
```

If the proxy intercepts TLS (MITM corporate certs), the Render CLI honours the system trust store. On Linux:

```bash
export SSL_CERT_FILE=/path/to/corp-ca-bundle.pem
```

If render can't reach `localhost:<port>` for the OAuth callback (rare - corp firewall blocking loopback), use the dashboard API-key path described above.

---

## Multiple Render workspaces

`render workspaces` (plural, no subcommand) shows all workspaces the user belongs to. To pin a single workspace per machine:

```bash
render workspace set <workspace-id>
```

To pin per-project, set the env var in that project's `.env` file:

```bash
RENDER_WORKSPACE=<workspace-id>
```

To switch interactively in a session: run `render workspace set <other-id>` - no need to log out.

---

## Deploy-time errors

### "No workspace selected"

Run `render workspace set <workspace-id>`.

### "Service name already exists"

Render service names are unique per workspace. Either pick a different name, or delete the conflicting service from the dashboard at https://dashboard.render.com/ - v2.17 has no CLI service-delete subcommand.

### "You are not entitled to use this region"

Some regions (Frankfurt, Singapore) require a paid plan. Switch the `region:` field in `render.yaml` to `oregon` (free tier) or upgrade the plan.

### "Free service spun down due to inactivity"

Expected behaviour - free web services sleep after 15 minutes idle and take ~30s to wake on first request. Options:
- Upgrade to Starter ($7/mo) to keep it always-on.
- Move the workload to a Render cron job instead (still free).

### Build fails: "Could not detect runtime"

Render auto-detects runtime from `package.json`, `requirements.txt`, `Cargo.toml`, etc. If none are present, pass `--runtime` to `render services create`:

```bash
render services create --type web_service --repo <url> --runtime node ...
# or python, ruby, go, rust, docker, elixir
```

---

## The `render skills install` / `render skills remove` footgun

**Do not call `render skills install` or `render skills remove --all` from inside this skill.**

`render skills install` scatters 21 top-level skill directories (`render-deploy`, `render-debug`, `render-monitor`, plus 18 more) under `~/.claude/skills/`. This skill deliberately avoids that to keep its footprint to one folder.

`render skills remove --all --tool claude` is the bigger footgun: it deletes every directory under `~/.claude/skills/` whose name matches anything in Render's catalogue - and the CLI's name-matching is loose enough that it deletes neighbouring skills too, including `render-deployment` itself. **Confirmed in CLI v2.17, May 2026.** If the user really wants Render's official bundle, install it manually outside this skill's flow and accept the directory scatter.

To recover from accidental removal of `render-deployment`: re-run this skill from a fresh chat - the skill content lives in source control / the skill catalogue and can be re-written from there.

---

## State file corruption

If `~/.claude/state/render-deployment.json` is malformed JSON, the skill should detect and overwrite with a fresh state object. Worst case, the user can delete the file and re-run the skill - it's safe to start fresh.

---

## When to ask the user vs auto-recover

| Problem | Auto-fix | Ask user |
|---|---|---|
| `render` not found | Re-install silently via the OS installer script | - |
| Token expired (401) | `render logout` + `render login` | - |
| Browser doesn't open | Switch to Playwright | - |
| `render login` callback port collision | Retry with `--port <next>` if supported | - |
| Corporate proxy | Set proxy env vars from system config | If unknown: ask what proxy URL their corp uses |
| Multiple workspaces | Show list | "Which workspace do you want as default?" |
| No Render account | - | "Want me to walk you through creating one at https://render.com/register?" |
| Free-plan blocker (region, always-on, custom domain count) | - | "This feature needs a paid Render plan. Upgrade?" |
| API key lost / never persisted | Drive Playwright to dashboard to mint a fresh key | - |
