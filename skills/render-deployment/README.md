# render-deployment

Hands-off assistant for connecting Claude Code to a Render.com account through the Render CLI.

After the user runs this skill once, the agent (Claude) can run any `render` CLI command on the user's behalf - list services, trigger redeploys, tail logs, open psql sessions - without further setup or human input.

## What this skill IS

- An installer + authenticator for the `render` CLI on the user's laptop.
- A "make Claude able to talk to Render hands-off" bootstrap.

## What this skill is NOT

- It is **not** a wrapper around the official Render skills bundle (`render-deploy`, `render-debug`, `render-monitor`, plus 18 more). That bundle scatters 21 top-level directories under `~/.claude/skills/`, and `render skills remove --all` deletes any folder whose name matches Render's catalogue - including this one. We don't run `render skills install` from this skill.
- It does **not** deploy from a local folder. Render's v2.17 CLI has no `render deploy <yaml>` command - every service is connected to a git repository. Pushing to git is what triggers deploys; this skill only gets the CLI talking to Render.

## File tree

```
render-deployment/
  SKILL.md                          # entrypoint - orchestration steps, plain-English flow
  README.md                         # this file
  troubleshooting.md                # plain-English fix reference
  scripts/
    install-render-unix.sh          # macOS (brew tap) / Linux (curl https://render.com/install.sh). Idempotent.
    install-render-windows.ps1      # Windows installer: winget → scoop → direct GitHub release zip. Idempotent.
```

Everything else (login polling, workspace selection, dashboard-driven API-key minting via Playwright, read-only verification) runs as short shell snippets inline from `SKILL.md` - no extra wrapper scripts needed.

## Flow

1. Read `~/.claude/state/render-deployment.json` → skip steps already done
2. Detect Render CLI version → install or upgrade if below 2.10
3. Detect existing `RENDER_API_KEY` env or `~/.render/config.yaml` → if valid, skip ahead
4. `render login` → polls config file, browser opens, user clicks Approve, done
5. If browser can't open → Playwright drives Chromium through the same OAuth URL
6. Pick a default workspace (auto if only one, ask the user if multiple)
7. Drive Playwright to `https://dashboard.render.com/u/settings#api-keys`, mint a key named `claude-code-<hostname>`, read it from the DOM, persist to the User env var + `$PROFILE` / `~/.zshrc` / `~/.bashrc`
8. Read-only verification: `render workspace current`, `render whoami`, `render services --output json`

After that, the agent is free to run any `render` command on the user's behalf when they ask in chat.

## State

All progress is persisted at `~/.claude/state/render-deployment.json`. Re-running the skill is a no-op if everything is wired up.

## Invocation

User types `/render-deployment` or any trigger phrase (e.g. "connect render", "deploy to render", "install render cli", "render login").
