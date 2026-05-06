# Connector strategy — 4 tiers, in order

> When the user picks something to build, the skill needs the right SaaS credentials wired up. We try 4 mechanisms, cheapest-effort first. The user should never paste an API key unless tiers 1–3 all failed.

## Tier 1 — Claude Desktop / claude.ai passthrough (PREFERRED)

The user's Claude account already has OAuth connections for many of the big-rocks: Gmail, Google Calendar, Drive, Notion, Linear, Atlassian, Canva, Airtable, Supabase, Figma, Xero, n8n, Zapier (which itself proxies 7,000+ apps).

**How we detect:** `claude mcp list` enumerates servers configured for the running CLI. Server names beginning with `claude_ai_*` are the user's existing OAuth connections. The skill greps for the service we need (e.g. `claude_ai_Gmail`) and reuses the connection — zero clicks for the user.

**Coverage today (Tier 1 is enough for these):**
- Gmail / Google Calendar / Google Drive
- Notion
- Linear / Atlassian / Intercom / Supabase / Figma / Canva
- Airtable
- Xero (read-side via Desktop connector + Zapier-Xero for write breadth)
- n8n
- Zapier (a meta-tier — see below)

**Zapier-as-meta-tier:** if the user has Zapier connected via Claude.ai, we get `mcp__claude_ai_Zapier__*` tools for ~250 apps (Slack, Google Ads, Outlook, GHL/LeadConnector, Apify, Make, Facebook Lead Ads, ManyChat, etc.) with no extra OAuth.

**Decision:** if Tier 1 covers all required services for the chosen build, never go further. Done.

## Tier 2 — Rube (one OAuth → 500+ apps)

For services not in Tier 1, default to **Rube** (`https://rube.app/mcp`). User does ONE OAuth dance and Rube proxies hundreds of apps (Slack, GHL, HubSpot, Stripe, Shopify, Calendly, Twilio, ManyChat, Telegram, Discord, etc).

**Why Rube as Tier 2 default:** new connections without per-service OAuth fatigue. The workshop attendee clicks "approve" once. Every downstream service "just works" through `mcp__rube__*` tools.

**How we add it:** `claude mcp add --transport http rube https://rube.app/mcp` then `mcp__rube__authenticate` → user gets a one-time URL → approves → `mcp__rube__complete_authentication`.

**When to skip Rube:**
- Service is in Tier 1 already
- The build is latency-sensitive (sub-second loops) — Rube adds an extra hop
- Service isn't in Rube's catalog (rare; Rube covers 500+)

## Tier 3 — Direct MCP server

For services Rube doesn't cover or where we need first-party tools:
- **n8n itself** (`https://selrai.app.n8n.cloud/mcp` or the user's own n8n.cloud URL)
- **GHL / LeadConnector** (`mcp__ghl-community__*` and `mcp__ghl-official__*` — official requires per-location PIT token)
- **ManyChat** (`mcp__manychat__*` — needs page-scoped API token)
- **Meta Ads / LinkedIn Ads / Google Ads** (per-platform MCPs with first-party APIs)
- **Apify** (workflow scraping)
- Service-specific MCP servers from `~/.claude/skills/managed-agents-setup/references/mcp-servers-catalog.md`

**Trade-off:** richer per-service tooling, but per-service auth setup. Use when Tier 2 isn't enough or the build needs platform-specific actions Rube doesn't expose.

## Tier 4 — Manual API key paste (LAST RESORT)

If nothing above works, the skill walks the user through getting a key:
1. Print a clickable URL: "Open this → click here → copy this token → paste below"
2. User pastes the key into the terminal (the script reads via `read -s`, masks input, never echoes)
3. Key is stored in `~/.claude/skills/ai-ops-architect/.state/secrets/<service>.env` (chmod 600, gitignored)
4. Reference path is added to the build's config — never the literal key

**Hard rules:**
- Never log a pasted key to stdout, transcript, or git
- Never write a key to a public repo, even by accident — `.state/` is gitignored
- Never share a key across users — the .state dir is per-machine

## Decision logic (per build)

```text
For each required service S in build.services_required:
  if S in (claude mcp list | grep claude_ai_):
      use Tier 1 (passthrough)
  elif S in RUBE_CATALOG:
      use Tier 2 (Rube — prompt OAuth if not yet connected)
  elif S has direct MCP entry in mcp-servers-catalog.md:
      use Tier 3 (install + authenticate)
  else:
      use Tier 4 (manual paste with screenshot guide)
```

The skill prints a one-line decision per service so the user sees what's happening:

```text
Gmail        → Tier 1 (claude.ai connector, reused)
GHL          → Tier 3 (community MCP, needs PIT token)
Slack        → Tier 2 (Rube, needs one-time OAuth)
SomeNiche    → Tier 4 (manual paste, guide opening)
```

## Where the scripts live

- `scripts/claude-passthrough.sh` — Tier 1 detector
- `scripts/connect-via-rube.sh` — Tier 2 OAuth driver
- `references/mcp-servers-catalog.md` — Tier 3 catalog (lives in managed-agents-setup, referenced from here)
- Manual fallbacks: per-service `.md` in managed-agents-setup `references/connector-walkthroughs/`

## Failure handling

If Tier 1 → 2 → 3 → 4 all fail (network, blocked port, wrong account), the skill stops the build cleanly and asks the user to either retry, switch service (e.g. swap MailChimp for Gmail), or skip this opportunity. It never partially-builds and walks away.
