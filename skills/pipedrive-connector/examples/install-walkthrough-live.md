# Pipedrive connector - live Phase 1 walkthrough (verified)

A real, verified run of Phase 1 on 2026-06-22. The token is redacted; everything else is the actual flow. This is the reference transcript for what a clean install looks like.

## Setup

- Account: SelrAI Pipedrive (domain `selrai`), token owner Rodolfo Raquion (admin).
- Environment: Linux, Playwright MCP with persistent profile.
- Pre-state: no `~/.config/pipedrive/credentials.env`.

## What Claude did (happy path)

1. **Phase 0 resume check** - `not-configured` (no credentials file) → proceed to Phase 1.

2. **Opened the API settings page** - `browser_navigate("https://app.pipedrive.com/settings/api")`. Signed-out, so Pipedrive redirected to `…/auth/login?return_url=…/settings/api`.
   - User-facing: *"Opening a browser window - please sign in to Pipedrive when it appears. I'll do the rest."*
   - **Did not snapshot the login page** (password-leak avoidance).

3. **Waited for sign-in** - polled `browser_evaluate(() => ({url: location.href, host: location.host}))`. The user signed in with Google SSO, which bounced through `accounts.google.com` mid-flow (normal). Polling settled on:
   ```
   { url: "https://selrai.pipedrive.com/settings/api", host: "selrai.pipedrive.com" }
   ```
   → signed in, on the right page, company domain = `selrai`.

4. **Extracted the token + domain** - `browser_evaluate` scanned inputs for a 40-char hex value, wrote it to the clipboard, and returned only metadata:
   ```json
   { "ok": true, "len": 40, "domain": "selrai" }
   ```
   The token value never appeared in a tool return or narration line.

5. **Stored credentials** - wrote `~/.config/pipedrive/credentials.env` (mode 600):
   ```
   PIPEDRIVE_API_TOKEN=ee54****************************redacted
   PIPEDRIVE_COMPANY_DOMAIN=selrai
   ```
   Then `rm -rf .playwright-mcp` to scrub auto-snapshots.

6. **Smoke test** - `GET /api/v1/users/me` with the `x-api-token` header:
   ```
   OK - Rodolfo Raquion - SelrAI
   ```
   - User-facing: *"All connected - your Pipedrive is ready. You can ask me things like 'show my open deals' or 'add a deal for a new lead'."*
   - No Claude Code restart (no MCP server).

## Verification facts captured during this run

- `x-api-token` header → **200**; `Authorization: Bearer` → **401** (confirms header, not Bearer).
- v2 envelope: `{success, data, additional_data:{next_cursor}}` (cursor pagination).
- Default pipelines present: **Sales pipeline** (id 2), **Onboarding pipeline** (id 3), 14 stages total.
- `/api/v1/leads`, `/api/v1/notes` → **200** (v1-only entities reachable on the company host).

## Failure branches exercised / documented

- **`browser_wait_for` text-based wait timed out at 30s** during the Google SSO redirect - switched to URL polling via `browser_evaluate`, which is robust to the OAuth bounce. (Use polling, not text-wait, for SSO logins.)
- **Token field collapsed** (not seen here, but documented): if no 40-hex input is found on the settings page, click the reveal/generate control, then re-extract.
