# Phase 3 - Vault seeding

**Goal:** push third-party credentials into Anthropic Vaults so MCP calls authenticate without re-prompting.

```bash
python3 ~/.claude/skills/managed-agents-setup/scripts/vault-seeder.py \
  --secrets-env ~/agents-cc/shared/secrets.env \
  --vault-name "primary"
```

Reads `secrets.env`, matches known keys to MCP server URLs (see `references/mcp-servers-catalog.md`), creates a vault, and adds one credential per MCP server.

**Companion: `mcp-bridge.sh`** - mirrors local Claude Code MCPs into the same vault so hosted agents get parity:
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/mcp-bridge.sh \
  --vault "$(cat ~/.claude/managed-agents/vault-id.txt)" --category A
```

**Auto-mappings:**
| Env var | MCP URL | Auth |
|---|---|---|
| `GHL_API_KEY` | `https://services.leadconnectorhq.com/mcp/` | static_bearer |
| `SUPABASE_SERVICE_KEY` | `https://mcp.supabase.com/mcp?project_ref=<SUPABASE_PROJECT_REF>` | static_bearer |
| `META_ADS_TOKEN` | `https://mcp.pipeboard.co/meta-ads-mcp` | static_bearer |
| `COMPOSIO_API_KEY` | `https://backend.composio.dev/v3/mcp` | static_bearer (Rube headless) |

> ManyChat / Telegram / Xero are NOT auto-seeded - `mcp-bridge.json` flags them with no verified remote MCP host (`ma_url: null`). Reach those services via Rube/Composio instead; do not seed a credential to a fabricated host.

**Rube as cheat code:** if user adds `COMPOSIO_API_KEY`, vault-seeder wires Composio's "500+ apps via one credential" gateway. Confirm pricing at rube.app/pricing before workshop rollout.

Vault ID written to `~/.claude/managed-agents/vault-id.txt`.
