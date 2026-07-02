# Cloudflare Deployment - Troubleshooting

Plain-English fixes for the most common problems. The skill itself should diagnose silently and never paste raw errors at the user - this doc is the agent's reference, not the user's.

---

## Wrangler install issues

### `wrangler: command not found` after `npm install -g wrangler`

PATH wasn't refreshed. Two fixes:

1. **Easiest:** close the terminal and open a new one.
2. **Force-refresh in the current terminal:**
   - macOS / Linux: `source ~/.bashrc` or `source ~/.zshrc`
   - Windows PowerShell: `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`

If still missing, the npm prefix is misconfigured. Check with `npm config get prefix`. On macOS/Linux, set it to a user-writable dir:

```bash
npm config set prefix ~/.npm-global
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
npm install -g wrangler
```

### `EACCES` permission denied on global install

Don't use sudo. Either fix the npm prefix as above, or fall back to `npx wrangler` for everything. The state file records `wrangler_mode: "npx"` so the agent uses the right command afterwards.

### `EAI_AGAIN` / DNS errors during install

Network issue. Try:
- Switch off VPN
- Use a different DNS resolver (1.1.1.1 or 8.8.8.8)
- Behind a corp firewall: `npm config set registry https://registry.npmjs.org/` (some corps proxy npm)

---

## Authentication issues

### Browser doesn't open on `wrangler login`

Causes:
- WSL with no DISPLAY
- Remote SSH session
- Corporate browser lockdown
- Default browser is misconfigured

**Fix:** fall back to Playwright. Capture the OAuth URL from wrangler's stdout, open it in a Playwright-controlled Chromium window, complete the click, let wrangler's localhost callback finish the loop.

### `localhost:8976 already in use` during login

Another wrangler instance is running its callback server. Either:
- Kill the other wrangler process: `pkill -f 'wrangler login'` (macOS/Linux) or `Get-Process node | Stop-Process` (Windows, carefully)
- Pass a different callback port: `wrangler login --browser=false --callback-port 8977`

### Token returns 401 / "unauthenticated" / "Authentication error [code: 10000]"

Token expired or revoked from the Cloudflare dashboard. Purge and re-login:

```bash
wrangler logout
wrangler login
```

If env var is set, also clear it before re-login:
- macOS/Linux: `unset CLOUDFLARE_API_TOKEN`
- Windows: `Remove-Item Env:\CLOUDFLARE_API_TOKEN`

### Login completes but `wrangler whoami` still fails

Two-account confusion - wrangler may have written credentials to a path that's not on its search path. Check both:

- macOS/Linux: `~/.config/.wrangler/config/default.toml` and `~/.wrangler/config/default.toml`
- Windows: `$env:USERPROFILE\.wrangler\config\default.toml` and `$env:APPDATA\.wrangler\config\default.toml`

Delete the older one and re-run login.

---

## Corporate proxy / firewall

Set proxy env vars before any wrangler command:

```bash
export HTTPS_PROXY=http://proxy.corp.example.com:8080
export HTTP_PROXY=http://proxy.corp.example.com:8080
# Or wrangler-specific:
export WRANGLER_HTTPS_PROXY=http://proxy.corp.example.com:8080
```

If the proxy intercepts TLS (MITM corporate certs), set:

```bash
export NODE_EXTRA_CA_CERTS=/path/to/corp-ca-bundle.pem
```

If wrangler can't reach `localhost:8976` for the OAuth callback (rare - corp firewall blocking loopback), generate a manual API token via Playwright at https://dash.cloudflare.com/profile/api-tokens and write it to `CLOUDFLARE_API_TOKEN`.

---

## Multiple Cloudflare accounts

`wrangler whoami` shows all accessible accounts. To pin a single account per project:

```toml
# wrangler.toml
account_id = "abc123def456..."
```

To switch interactively in a session: there's no built-in switcher - log out and log back in with a different account, or use an API token scoped to the specific account.

---

## Deploy-time errors

### "Account ID is required"

Add `account_id` to `wrangler.toml` or set `CLOUDFLARE_ACCOUNT_ID` env var.

### "You are not entitled to use this service"

The user is on a free plan trying to deploy something that requires a paid plan (e.g. Workers Paid for cron triggers, R2 for object storage). Send them to https://dash.cloudflare.com/?account=workers/plans.

### "The compatibility_date is too old"

Update `compatibility_date` in `wrangler.toml` to today's date in YYYY-MM-DD format.

### Build errors during `wrangler deploy`

Usually wrangler bundles via esbuild. Common causes:
- Missing dependencies: `npm install`
- Wrong main entry path in `wrangler.toml`
- TypeScript syntax that needs compilation - add `tsconfig.json` and use `main = "src/index.ts"`

---

## Cloudflare skills bundle install issues

### `/plugin marketplace add cloudflare/skills` fails

This is a Claude Code harness command, not a shell command. The user must type it in the Claude Code chat box, not a terminal.

### Plugin install succeeds but skills don't appear

Restart Claude Code. The plugin loader reads on startup. After restart, the skills (agents-sdk, durable-objects, sandbox-sdk, web-perf, workers-best-practices, wrangler) appear in the available-skills list.

---

## State file corruption

If `~/.claude/state/cloudflare-deployment.json` is malformed JSON, the skill should detect and overwrite with a fresh state object. Worst case, the user can delete the file and re-run the skill - it's safe to start fresh.

---

## When to ask the user vs auto-recover

| Problem | Auto-fix | Ask user |
|---|---|---|
| `wrangler` not found | Re-install silently | - |
| Token expired (401) | `wrangler logout` + `wrangler login` | - |
| Browser doesn't open | Switch to Playwright | - |
| Corporate proxy | Set proxy env vars from system config | If unknown: ask what proxy URL their corp uses |
| Multiple accounts | Show list | "Which account do you want as default?" |
| No Cloudflare account | - | "Want me to walk you through creating one?" |
| Free-plan blocker | - | "This feature needs the paid Workers plan. Upgrade?" |
