# Phase 0 - Pre-flight

**Goal:** verify the local environment can host the install.

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/preflight.sh
```

**Outputs JSON status:**
- `anthropic_key_present` - `$ANTHROPIC_API_KEY` set OR keychain has `anthropic-managed-agents`
- `ant_cli_installed`
- `python_sdk_installed` - `python3 -c "import anthropic"`
- `typescript_sdk_installed`
- `server_setup_detected` - looks for `~/agents-cc` on the user's server (optional)
- `secrets_env_path` - path or null
- `n8n_url` - url or null

If any required item is missing, the script prints exact commands to fix.

**Skip phase 1 if:** `anthropic_key_present=true`. Phase 1 only runs when the user needs to mint a new key.
