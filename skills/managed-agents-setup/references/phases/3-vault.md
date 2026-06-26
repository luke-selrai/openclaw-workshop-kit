# Phase 3, Vault seeding

**Goal:** push third-party credentials into Anthropic Vaults so MCP calls authenticate without re-prompting.

```bash
python3 ~/.claude/skills/managed-agents-setup/scripts/vault-seeder.py \
  --secrets-env ~/agents-cc/shared/secrets.env \
  --vault-name "primary"
```

Reads `secrets.env`, matches known keys to MCP server URLs (see `references/mcp-servers-catalog.md`), creates a vault, and adds one credential per MCP server.

**Companion: `mcp-bridge.sh`**, mirrors local Claude Code MCPs into the same vault so hosted agents get parity:
```bash
bash ~/.claude/skills/managed-agents-setup/scripts/mcp-bridge.sh \
  --vault "$(cat ~/.claude/managed-agents/vault-id.txt)" --category A
```

**Auto-mappings:**
A hosted MCP server URL must include the server's streamable-HTTP path (almost
always `/mcp`); a bare host does not resolve as an MCP server and the connection
silently does not form. Verified URLs below carry the path; unverified ones are
marked and must be confirmed against the vendor's own MCP docs before use.

| Env var | MCP URL | Auth | Verified |
|---|---|---|---|
| `GHL_API_KEY` | `https://services.leadconnectorhq.com/mcp/` | static_bearer | yes |
| `SUPABASE_SERVICE_KEY` | `https://mcp.supabase.com/mcp?project_ref=<project_ref>` | static_bearer | yes |
| `META_ADS_TOKEN` | (no verified public remote MCP url, confirm before use) | static_bearer | no |
| `MANYCHAT_API_KEY` | (no verified public remote MCP url, confirm before use) | static_bearer | no |
| `COMPOSIO_API_KEY` | `https://backend.composio.dev/v3/mcp` | static_bearer (Rube headless) | yes |

**Rube as cheat code:** if user adds `COMPOSIO_API_KEY`, vault-seeder wires Composio's "500+ apps via one credential" gateway. Confirm pricing at rube.app/pricing before workshop rollout.

Vault ID written to `~/.claude/managed-agents/vault-id.txt`.
