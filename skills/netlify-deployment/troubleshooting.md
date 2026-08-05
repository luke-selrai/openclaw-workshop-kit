# netlify-deployment — Troubleshooting

Deeper fixes than the quick table in `SKILL.md` Part 8. Everything here is written so the agent can act on it directly.

## Install

**`netlify: command not found` right after a successful install**
The npm global bin directory isn't on this shell's PATH yet. New terminals pick it up automatically. In the current PowerShell session:
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```
If it's STILL missing, find where npm puts globals: `npm prefix -g` — the shim lives there (Windows: directly in that folder; Unix: in `bin/` under it).

**`npm install -g netlify-cli` fails with EACCES / EPERM**
- Windows: PowerShell as administrator, or fix the npm prefix to a user-writable dir.
- macOS/Linux: never `sudo npm` blindly — prefer moving the prefix: `npm config set prefix ~/.npm-global` and add `~/.npm-global/bin` to PATH. Or accept the script's `npx netlify` fallback.

**Install is slow / appears hung**
`netlify-cli` is a large package (hundreds of deps). 1–3 minutes on a normal connection is normal. Only investigate past ~5 minutes.

## Auth

**Token set but `netlify status` says "Not logged in"**
The env var the CLI sees isn't the one you think it sees. Check in the SAME shell the CLI runs in:
- PowerShell: `$env:NETLIFY_AUTH_TOKEN.Length` (don't print the value)
- Bash: `echo ${#NETLIFY_AUTH_TOKEN}`
A length of 0 in a fresh shell means the persist step wrote to a profile that shell doesn't source (e.g. wrote to `~/.zshrc` but the shell is bash). Fix the profile, or re-run the mint.

**Freshly persisted token invisible to new tool-spawned shells**
Harness shells (Claude Code tool calls) are spawned from a parent process that predates the User-env write, so `$env:NETLIFY_AUTH_TOKEN` is empty even though the persist succeeded. Prefix netlify commands with:
```powershell
$env:NETLIFY_AUTH_TOKEN = [System.Environment]::GetEnvironmentVariable('NETLIFY_AUTH_TOKEN','User')
```
New real terminals (opened after the persist) see it automatically.

**`netlify status` exits 1 but prints the correct user/team**
Not an auth failure — the cwd just isn't linked to a site ("Did you run `netlify link` yet?"). Auth is proven by the Email/Teams block. Link the folder or run from a linked one.

**`netlify api <op> --data` rejects the JSON on Windows**
Backslash-escaped quotes get mangled between the harness and the CLI. Put the JSON in a variable first:
```powershell
$d = '{"site_id":"<id>"}'
netlify api listSiteFiles --data $d
```

**401 Unauthorized mid-session after months of working**
The user (or a security sweep) revoked the token at app.netlify.com/user/applications. Re-run SKILL.md Part 3. Old tokens can't be un-revoked.

**Multiple Netlify accounts (personal + team)**
`netlify status` shows which account the token belongs to. If it's the wrong one, the token was minted while signed into the wrong account — revoke it there, sign into the right account in the Playwright browser, re-mint.

## PAT mint (Playwright)

**Login page never resolves**
The user may be stuck on 2FA or an SSO redirect. Wait — don't reload the page for them, reloading can dump form state. After ~3 minutes, ask if they're stuck.

**"New access token" button not found**
Netlify redesigns the applications page occasionally. Take a fresh accessibility snapshot and look for the Personal access tokens *section* first, then its create button — the flow is stable even when the DOM isn't: Applications → Personal access tokens → create → name → generate → token shown once.

**Token field shows dots / can't be read from DOM**
Some redesigns mask the token behind a "copy" button. Use the copy button, then read the clipboard from Playwright (`page.evaluate(() => navigator.clipboard.readText())` needs clipboard permission granted at context level) — or click the reveal/eye toggle if present.

## Sites + linking

**`netlify link` went interactive and is waiting on stdin**
Non-interactive shells can't answer its menu. Always pass `--id <site-id>` (from `netlify sites:list --json`). Kill the hung process first.

**`.netlify/state.json` exists but points at a deleted site**
`netlify unlink` (or just delete the `.netlify/` folder), then re-create + re-link.

**`sites:create` rejects the name**
Site names are global across all of Netlify. Try `<name>-<team-slug>`. The user can rename later in the dashboard (Site settings → Site details).

**Old anonymous Drop site**
Never-claimed drops (app.netlify.com/drop without signing in) belong to no account and expire. They cannot be adopted by the CLI or transferred. Create a fresh site; treat the Drop URL as dead.

## Deploys

**Deploy uploads but the preview shows a directory listing / 404**
`--dir` pointed one level too high or too low. The dir must contain `index.html` at its root. For a plain HTML folder the folder itself is the site root.

**CLI tries to run a build and fails**
A `netlify.toml` with a `[build]` command is present. For plain static folders either pass `--no-build` (newer CLIs) or remove/fix the build command.

**Draft URL 404s immediately after deploy**
Large deploys finish uploading before the CDN finishes propagating. `netlify watch` waits for the deploy to reach "ready". Rare on small static sites.

**Prod deploy succeeded but the custom domain shows the old site**
DNS/CDN cache, not a deploy problem. The `*.netlify.app` URL is the truth of what's deployed; the custom domain follows within minutes.

**Rollback needed**
The CLI has no rollback command. Restore an earlier deploy via the API: `netlify api restoreSiteDeploy --data '{"site_id": "<site-id>", "deploy_id": "<deploy-id>"}'` — find the deploy_id with `netlify api listSiteDeploys --data '{"site_id": "<site-id>"}'`. Fallback that always works: dashboard → Deploys → pick any earlier deploy → **Publish deploy**. Netlify keeps every deploy indefinitely.
