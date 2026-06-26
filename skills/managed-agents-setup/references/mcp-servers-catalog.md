# MCP Servers Catalog

Reference list of remote MCP servers usable with Managed Agents. Update as new providers publish MCP endpoints.

**Constraint**: Managed Agents only supports remote MCP via `type: "url"` (streamable HTTP). No stdio / local MCP.

## Confirmed Remote MCP Endpoints

A hosted MCP server URL must include the server's streamable-HTTP path (almost
always a `/mcp` suffix). A bare host (e.g. `https://mcp.example.com` with no
path) does not resolve as an MCP server and the connection silently does not
form. The "Verified" column marks which URLs are confirmed against the vendor's
own MCP docs; treat an unverified row as a lead to confirm, not a ready URL.

| Provider | MCP URL | Auth | Verified | Notes |
|----------|---------|------|----------|-------|
| GoHighLevel | `https://services.leadconnectorhq.com/mcp/` | static_bearer (PIT token) | yes | Community + official MCPs available. PIT token scoped to location. |
| Supabase | `https://mcp.supabase.com/mcp?project_ref=<project_ref>` | static_bearer (service key) | yes | Scope per project; pass the project ref in the query. |
| Notion | `https://mcp.notion.com/mcp` | mcp_oauth or static_bearer | yes | OAuth preferred; integration tokens also work. |
| Stripe | `https://mcp.stripe.com` | static_bearer | yes | Restricted keys recommended. |
| Linear | `https://mcp.linear.app/mcp` | static_bearer (`lin_api_...`) | yes | Per-user or per-team API keys. |
| GitHub Copilot | `https://api.githubcopilot.com/mcp/` | mcp_oauth | yes | Requires GitHub Copilot plan. |
| Meta Ads | (no verified public remote MCP url, confirm before use) | static_bearer (long-lived token) | no | Community MCP; the bare host `mcp.meta.com/ads` is unconfirmed and likely will not form. |
| ManyChat | (no verified public remote MCP url, confirm before use) | static_bearer | no | Community MCP; the bare host `mcp.manychat.com` is unconfirmed. |
| Hubstaff | (no verified public remote MCP url, confirm before use) | static_bearer | no | Community MCP; the bare host `mcp.hubstaff.com` is unconfirmed. |
| Telegram Bot | (no verified public remote MCP url, confirm before use) | static_bearer (bot token) | no | Community MCP; the bare host `mcp.telegram.org` is unconfirmed. |
| n8n | `https://selrai.app.n8n.cloud/mcp` | static_bearer (n8n API key) | confirm | User's own n8n instance; URL forms only if the n8n MCP node is enabled on that instance. |
| **Rube (Composio), interactive** | `https://rube.app/mcp` | mcp_oauth | **"One connection, 500+ apps" meta-MCP.** Gmail, Slack, Notion, GitHub, Linear, HubSpot, Stripe, Drive, Calendar, Shopify, Twitter and more. Uses `RUBE_SEARCH_TOOLS` + `RUBE_EXECUTE_TOOL` to avoid context explosion. OAuth 2.1, free in beta. **Best for workshop attendees**, they authorize once per service in the Rube UI. |
| **Composio (static), headless** | `https://backend.composio.dev/v3/mcp` | static_bearer (`COMPOSIO_API_KEY`) | Same 500+ app gateway but using a Composio API key in `x-api-key` header. **Best for Luke's cron jobs and server agents**, no interactive consent needed. Requires per-user entity setup in Composio dashboard. |

## When to Use Rube vs Direct MCPs

**Default every new agent to Rube unless you have a reason not to.** Reasons to pick a direct MCP instead:

1. **Latency-sensitive loops**: Rube adds ~300-800ms per call via Composio's gateway. For tight polling or sub-second ops agents, use direct MCPs.
2. **Already-configured service**: if `GHL_API_KEY` is already in `secrets.env` and seeded to vault, the direct `mcp.gohighlevel.com` MCP is one hop instead of two.
3. **Provider not in Rube catalog**: niche or self-hosted services (Luke's n8n, Hubstaff, custom webhook receivers) have no Rube route, use direct.
4. **Auth that Rube doesn't support yet**: Private Integration Tokens, custom bearer schemes, mTLS.

**Reasons to always prefer Rube:**
- Workshop attendee has 1 API key to manage instead of 12.
- Adding a new service = authorize in Rube UI, no vault re-seed, no agent redeploy.
- Discovery-first (`RUBE_SEARCH_TOOLS`) keeps the context window lean even across 500+ tools.

## Auth Types

**`static_bearer`**, single static token. Most SaaS API keys, PATs, and service keys.
```json
{"type": "static_bearer", "mcp_server_url": "https://...", "token": "..."}
```

**`mcp_oauth`**, OAuth 2.0 with refresh. Required for providers that mandate OAuth (Gmail, Calendar, some Notion setups).
```json
{
  "type": "mcp_oauth",
  "mcp_server_url": "https://...",
  "client_id": "...",
  "client_secret": "...",
  "token_endpoint": "https://.../token",
  "token_endpoint_auth": "client_secret_basic",
  "refresh_token": "..."
}
```

## Adding a New Provider

1. Confirm provider publishes a remote MCP endpoint (not stdio).
2. Determine auth type by reading their MCP docs.
3. Add a row to the table above.
4. If needed, add a mapping in `scripts/vault-seeder.py` under `MAPPINGS`.
5. Add the server URL to `references/environment-templates.json` `allowed_hosts` if using `locked-down` networking.

## Provider-Specific Gotchas

- **Notion**: "Claude AI Notion" MCP from the claude.ai integration does NOT apply to API / Managed Agents. Use the Notion-hosted MCP directly.
- **Gmail / Google Calendar**: OAuth refresh flow. You'll need a Google Cloud project with domain-wide delegation or per-user consent. The `managed-agents-setup` skill does NOT automate this, point users to Google Cloud Console.
- **GoHighLevel**: PIT tokens are long-lived but scoped. Do NOT use a sub-account API key where a PIT works, PIT is the preferred pattern.
- **n8n**: The n8n MCP exposes workflow + execution tools. Use it for agent-to-n8n calls; for n8n-to-agent use standard HTTP Request node.
