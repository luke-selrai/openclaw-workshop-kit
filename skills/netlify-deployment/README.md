# netlify-deployment

Hands-off assistant for connecting Claude Code to a Netlify account and deploying static sites.

After the user runs this skill once, the agent (Claude) can run any `netlify` CLI command on the user's behalf — create sites, push draft deploys with preview URLs, promote to production, manage env vars — without further setup or human input.

## What this skill IS

- An installer + authenticator for the `netlify` CLI (Node bootstrap included for bare machines).
- A deploy operator for standalone static sites and loose folders — the "folder → live URL" path that replaces dragging onto app.netlify.com/drop.

## What this skill is NOT

- It does **not** use `netlify login` OAuth sessions — a single Playwright-minted Personal Access Token in `NETLIFY_AUTH_TOKEN` covers interactive and non-interactive use alike (sub-agents and scheduled tasks work from day one).
- It does **not** register Netlify's MCP server or install any skills bundle. One folder, one skill, one credential.
- It does **not** create Netlify accounts — signup is the user's 60 seconds, once.
- It does **not** deploy full-stack-builder-pack projects. Those deploy to Vercel via the pack's own flow; this skill owns the ground the pack doesn't touch.

## File tree

```
netlify-deployment/
  SKILL.md                          # entrypoint — flow, deploy gate, CLI reference
  README.md                         # this file
  troubleshooting.md                # plain-English fix reference
  scripts/
    install-netlify-unix.sh         # Node 22 bootstrap (brew/NodeSource/nvm) + npm i -g netlify-cli. Idempotent.
    install-netlify-windows.ps1     # Node 22 bootstrap (winget/MSI) + npm i -g netlify-cli. Idempotent.
```

Everything else (PAT mint via Playwright, site linking, deploys, verification) runs inline from `SKILL.md` — no extra wrapper scripts.

## Flow

1. Read `~/.claude/state/netlify-deployment.json` → skip steps already done
2. Install Node (if missing) + `netlify-cli` via the OS script
3. Playwright drives `app.netlify.com/user/applications` → user signs in ONCE (or zero clicks if already in) → agent mints a token named `claude-code-<hostname>`, reads it from the DOM, persists `NETLIFY_AUTH_TOKEN` to User env + shell profile. Never echoed to chat.
4. `netlify status` verifies the wiring
5. Per project folder, once: `netlify sites:create` (if needed) + `netlify link` → site ID lives in the folder's own `.netlify/state.json`
6. Deploys: **draft runs unprompted** (private preview URL back to the user); `--prod` only when the user's instruction says live/publish/prod — then no second confirmation

## State

Machine-level facts (CLI installed, token persisted, account email) live at `~/.claude/state/netlify-deployment.json`. Folder→site binding is Netlify-native (`.netlify/state.json` per project) — this skill never keeps a second registry.

## Invocation

User types any trigger phrase — "connect netlify", "deploy to netlify", "publish to netlify", "netlify deploy", "netlify drop", etc.
