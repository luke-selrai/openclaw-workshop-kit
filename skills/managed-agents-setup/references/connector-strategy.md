# Connector strategy, 4 tiers, in order

> When a managed agent needs SaaS credentials, we try 4 mechanisms cheapest-effort first. The user should never paste an API key unless tiers 1-3 all failed.

This file is the canonical 4-tier doc shared with `/ai-ops-architect`. The implementation lives in `scripts/connector-wizard.sh` (interactive) and `scripts/vault-seeder.py` (batch from `secrets.env`).

## Tier 1, Claude Desktop / claude.ai passthrough (PREFERRED)

The user's Claude account already has OAuth connections for many services. Reuse them, zero clicks.

**How we detect:** `claude mcp list` enumerates MCP servers. Names beginning `claude_ai_*` are existing OAuth passthroughs. The skill greps for the service it needs (e.g. `claude_ai_Gmail`).

**Coverage today:**
- Gmail, Google Calendar, Google Drive
- Notion
- Linear, Atlassian, Intercom, Supabase, Figma, Canva
- Airtable
- Xero (read via Desktop connector + Zapier-Xero for write breadth)
- n8n
- Zapier (a meta-tier, see below)

**Zapier-as-meta-tier:** if Zapier is connected via claude.ai, we get `mcp__claude_ai_Zapier__*` for ~250 apps without extra OAuth.

**Decision:** if Tier 1 covers all required services, never go further.

## Tier 2, Rube (one OAuth → 500+ apps)

Default for services not in Tier 1. User does ONE OAuth dance and Rube proxies hundreds of apps (Slack, GHL, HubSpot, Stripe, Shopify, Calendly, Twilio, ManyChat, Telegram, Discord, ...).

**Why Rube as Tier 2 default:** new connections without per-service OAuth fatigue. Workshop attendee clicks "approve" once.

**How we add it:** `claude mcp add --transport http rube https://rube.app/mcp` then `mcp__rube__authenticate` → user approves → `mcp__rube__complete_authentication`.

**When to skip Rube:**
- Service is in Tier 1 already
- Latency-sensitive sub-second loops (Rube adds 300-800ms)
- Service isn't in Rube's catalog (rare)

## Tier 3, Direct MCP server

For services Rube doesn't cover or where we need first-party tools:
- **n8n itself** (`https://selrai.app.n8n.cloud/mcp` or user's own URL)
- **GHL / LeadConnector** (community + official, official needs PIT token)
- **ManyChat** (page-scoped API token)
- **Meta Ads / LinkedIn Ads / Google Ads** (per-platform first-party MCPs)
- Service-specific MCPs from `references/mcp-servers-catalog.md`

**Trade-off:** richer per-service tooling, but per-service auth setup. Use when Tier 2 isn't enough or the build needs platform-specific actions.

## Tier 4, Manual API key paste (LAST RESORT)

If nothing above works, walk the user through getting a key:

1. Print a clickable URL: "Open this → click here → copy this token → paste below"
2. User pastes into terminal (`read -s`, masked, never echoed)
3. Key stored via `vault-seeder.py` into Anthropic Vault (Phase 3), never in plain `secrets.env` if avoidable
4. Reference path is added to the build's config, never the literal key

**Hard rules:**
- Never log a pasted key to stdout, transcript, or git
- Never write a key to a public repo, `.state/` is gitignored
- Never share a key across users, vault is per-environment

## Decision logic (per build)

```text
For each required service S in build.services_required:
  if S in (claude mcp list | grep claude_ai_):
      use Tier 1 (passthrough)
  elif S in RUBE_CATALOG:
      use Tier 2 (Rube — prompt OAuth if not yet connected)
  elif S has direct MCP entry in mcp-servers-catalog.md:
      use Tier 3 (install + authenticate via vault-seeder)
  else:
      use Tier 4 (manual paste with screenshot guide)
```

The skill prints a one-line decision per service:

```text
Gmail        → Tier 1 (claude.ai connector, reused)
GHL          → Tier 3 (community MCP, needs PIT token)
Slack        → Tier 2 (Rube, needs one-time OAuth)
SomeNiche    → Tier 4 (manual paste, guide opening)
```

## Where the scripts live

- `scripts/connector-wizard.sh`, interactive Tier 1→4 walker for a single service
- `scripts/vault-seeder.py`, batch seed all known services from `secrets.env` into Anthropic Vault
- `scripts/mcp-bridge.sh`, mirror your local `claude mcp list` MCP connections into the same vault so the hosted agent has the same toolset
- `references/mcp-servers-catalog.md`, Tier 3 catalog (canonical list of remote MCP endpoints)

## Failure handling

If Tier 1 → 2 → 3 → 4 all fail (network, blocked port, wrong account), the skill stops the build cleanly and asks the user to retry, switch service (e.g. swap MailChimp for Gmail), or skip this opportunity. Never partially-build and walk away.
