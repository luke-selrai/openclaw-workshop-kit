# Phase 2 — Local CLI + SDK install

```bash
bash ~/.claude/skills/managed-agents-setup/scripts/install-cli.sh
```

**Installs:**
- `ant` CLI via Homebrew tap (`anthropics/tap/ant`)
- Python SDK: `pip3 install --user anthropic`
- TypeScript SDK: `npm install -g @anthropic-ai/sdk` (optional)
- Sets `ANTHROPIC_API_KEY` in shell profile if not already set

**Verify:**
```bash
ant --version
python3 -c "from anthropic import Anthropic; print(Anthropic().api_key[:10])"
```

If `ant` install fails on a non-Homebrew system, fall back to:
```bash
curl -fsSL https://anthropic.com/install/ant.sh | sh
```
