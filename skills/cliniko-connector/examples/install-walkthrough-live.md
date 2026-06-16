# Cliniko connector — live install walkthrough (verified)

A real Phase 1 run executed 2026-06-16 against a 30-day Cliniko trial (`selr-ai.au5.cliniko.com`). The API key value is **redacted** (real keys start `MS0…` and end with the region shard, e.g. `-au5`). Happy path with the real deviations noted.

## What ran

1. **Sign in (user step).** Cliniko logins are per-account at `{sub}.{shard}.cliniko.com` — there is no central sign-in. The user signed in (email + password + emailed verification code); the browser landed on `https://selr-ai.au5.cliniko.com/` (Dashboard). The subdomain (`selr-ai`) and shard (`au5`) are both visible in the URL.

2. **Check the API-key permission.** `GET /user/edit` showed *"You cannot create or use API keys"* with a toggle **"Allow yourself to create and use API keys"** (off). Security role: **Administrator**.

3. **Enable API keys (Playwright + one user step).**
   - The toggle's real `<input type=checkbox>` is **covered by a styled `.slider`** (AngularJS); clicking the input times out ("slider intercepts pointer events"). Clicking `label:has-text("Allow yourself to create and use API keys") .slider` worked.
   - Clicking **Update user** raised a **"Security check"** modal: *"Please enter your Cliniko password so we know it's really you."* Claude handed off; the user typed their password and saved.
   - *Footgun observed:* before the Security check is completed, the toggle silently reverts — a reload showed it back to off. The reload-and-recheck is what proved whether it persisted.
   - After the user completed it, `/user/edit` showed *"You have 0 API keys"* and a **Manage API keys** link → `/user/api-keys`.

4. **Mint the key.** `/user/api-keys` → **Add an API key** → `/user/api-keys/new` → filled `#tokenName` = `Claude Code` → **Create API key**.

5. **Capture (once).** The reveal showed *"Copy your new API key now. It won't be shown again."* with the value `MS0…-au5`. Read via `browser_evaluate` matching `/MS0[A-Za-z0-9+/=_-]{20,}-[a-z]{2,4}\d/` straight into the clipboard — **no screenshot of the reveal** (a full-page screenshot taken to debug DID capture it and had to be scrubbed; see below). Length 76, shard `au5`.

6. **Store + scrub.**
   ```bash
   install -d -m 700 ~/.config/cliniko
   # key read from clipboard, shard parsed from suffix, written without echo
   cat > ~/.config/cliniko/credentials.env <<EOF
   CLINIKO_API_KEY=<redacted>
   CLINIKO_SHARD=au5
   CLINIKO_API_BASE=https://api.au5.cliniko.com/v1
   CLINIKO_USER_AGENT="SelrAI-Claude-Connector (rodolfo@selrai.com.au)"
   EOF
   chmod 600 ~/.config/cliniko/credentials.env
   ( printf '' | wl-copy ) ; rm -rf .playwright-mcp   # clear clipboard + transient snapshots wholesale
   ```

7. **Smoke test.**
   ```bash
   set -a; . ~/.config/cliniko/credentials.env; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -u "$CLINIKO_API_KEY:" \
     -H "User-Agent: $CLINIKO_USER_AGENT" -H "Accept: application/json" \
     "$CLINIKO_API_BASE/practitioners"
   # => 200
   ```
   Returned the account's practitioner ("Rodolfo Raquion"). **No Claude Code restart** — direct REST.

## Write-path verification (2026-06-16)

After install, the patient write path was exercised end-to-end against the same trial and cleaned up:

- `GET /patients` → `200`, `total_entries: 0`.
- `POST /patients` (`{"first_name":"ZZClaudeTest","last_name":"DeleteMe"}`) → `200`, returned a patient `id`.
- `GET /patients/<id>` → `200`, record present (`ZZClaudeTest DeleteMe`).
- `DELETE /patients/<id>` → **`204`** — Cliniko archives the patient (not a hard purge).

No live data was left behind. Confirms create/read/delete on Cliniko PHI works with HTTP Basic + User-Agent.

## Notes / lessons for the next run

- The **password Security check** is the only un-automatable step; it persists, so repeat runs skip Steps 2–3.
- Click the `.slider`, not the hidden checkbox. Re-query after every AngularJS state change.
- **Scrub `.playwright-mcp` wholesale** — auto-snapshots and any debug screenshot can contain the key. Never `grep "MS0" | rm`: that substring also appears in this skill's docs and the credentials file.
- Parse the shard from the key suffix; default to `au1` if absent.
