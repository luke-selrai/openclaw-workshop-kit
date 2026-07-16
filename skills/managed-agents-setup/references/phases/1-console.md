# Phase 1 - Anthropic Console

**Goal:** workspace + API key. Skip if user has a key.

**Option A - Playwright driven:**
1. Open https://platform.claude.com/login
2. User authenticates (OAuth or email). Wait for dashboard.
3. Settings > Workspaces. Create workspace named `AGENTS-<user>`.
4. Settings > API Keys. Create key scoped to that workspace. Name it `managed-agents-key`.
5. Copy value to clipboard, stash in keychain:
   ```bash
   security add-generic-password -a "$USER" -s "anthropic-managed-agents" -w "sk-ant-..." -U
   ```
6. Billing > verify payment method (user approves).

**Option B - User provides key:**
```bash
security add-generic-password -a "$USER" -s "anthropic-managed-agents" -w "$KEY" -U
export ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s "anthropic-managed-agents" -w)
```

**Verify:**
```bash
curl -sS https://api.anthropic.com/v1/models \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" | jq '.data[0]'
```

**Refusal:** never type or store the key in plain text outside keychain or vault.
