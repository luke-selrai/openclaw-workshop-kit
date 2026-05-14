# cloudflare-deployment

Zero-touch install + authenticate of the Cloudflare developer stack (Wrangler, Workers, Pages, R2, KV, D1, Durable Objects) on the user's laptop.

## File tree

```
cloudflare-deployment/
  SKILL.md                          # entrypoint
  README.md                         # this file
  troubleshooting.md                # plain-English fix reference
  scripts/
    install-node-unix.sh            # macOS / Linux Node 22 installer (idempotent)
    install-node-windows.ps1        # Windows Node 22 installer via winget (idempotent)
    install-wrangler.sh             # global wrangler install with npx fallback
    install-wrangler.ps1            # same, PowerShell
    login-and-wait.sh               # triggers OAuth + polls config file
    login-and-wait.ps1              # same, PowerShell
    verify.sh                       # read-only verification (whoami, kv, r2, d1)
    verify.ps1                      # same, PowerShell
    verify-deploy.sh                # full deploy test (deploys + curls + deletes)
    verify-deploy.ps1               # same, PowerShell
    state.sh                        # state-file get/set helpers
    state.ps1                       # same, PowerShell
```

## Flow

1. Read `~/.claude/state/cloudflare-deployment.json` → skip steps already done
2. Check Node 22+ → install if missing
3. `npm install -g wrangler` → fall back to `npx wrangler` if no global permission
4. Detect existing `CLOUDFLARE_API_TOKEN` env or wrangler config → if valid, skip login
5. `wrangler login` → polls config dir, browser opens, user clicks Allow, done
6. If browser can't open → Playwright fallback drives Chromium through the same OAuth
7. Offer to install the official `cloudflare/skills` plugin bundle (default yes)
8. End-to-end verify: read-only (`whoami` + lists) OR full deploy test (deploys + curls + deletes a Hello World Worker)

## State

All progress is persisted at `~/.claude/state/cloudflare-deployment.json`. Re-running the skill is a no-op if everything is wired up.

## Invocation

User types `/cloudflare-deployment` or any trigger phrase (e.g. "connect cloudflare", "deploy to workers", "install wrangler").
