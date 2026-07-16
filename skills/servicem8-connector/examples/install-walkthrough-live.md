# ServiceM8 connector - live install walkthrough (verified)

A real Phase 1 run executed 2026-06-16 against a 14-day ServiceM8 trial. The API key value is **redacted** (real keys match `smk-NNNNNN-XXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXX`). This is the happy path; deviations are noted inline.

## What ran

1. **Open ServiceM8.** `browser_navigate("https://go.servicem8.com/")` → redirected to `www.servicem8.com/login-page`. Did **not** snapshot (password-leak rule). Asked the user to sign in.
   - *Observed footgun:* the login email was pre-filled `rodolfo@selria.com.au` - a typo (`selria` vs `selrai`) that had bounced ServiceM8's verification email. REST works regardless, but email/SMS sends are blocked until the owner email is fixed. Flagged to the user; did not block the install.

2. **Detect login.** After the user signed in, `browser_wait_for({ text: "Dispatch Board" })` confirmed the dashboard (`us-west-1.go.servicem8.com/dashboard`). Account: "Rodolfo Raquion", 14 days left on trial.

3. **Settings → API Keys.** Clicked the **Settings** tile → landed on `Plugin_Graphic_Menu_System_SubMenu?...Settings`. The Settings grid showed an **API Keys** tile (a blue shield) → clicked it → `PluginApiKeyManagement_Dashboard`. Table read: *"No API keys found. Click 'Add API Key' to create one."*

4. **Create the key.** Clicked **Add API Key**. Modal fields:
   - **API Key Name** (text)
   - **API Key Type**: radios **Read Only** / **Full Access**
   - **Create** / **Cancel**
   Named it `Claude Code`, selected **Full Access**, clicked **Create**.

5. **Capture (once).** The reveal panel showed *"Below is your API key. Please store it securely as it will not be shown again."* with the value `smk-…` and a **Copy** link. Read it via `browser_evaluate` matching `/smk-[A-Za-z0-9-]{10,}/` straight into the clipboard - **no screenshot of the reveal modal**.

6. **Store + scrub.**
   ```bash
   install -d -m 700 ~/.config/servicem8
   # key read from clipboard, written without echo
   cat > ~/.config/servicem8/credentials.env <<EOF
   SERVICEM8_API_KEY=<redacted>
   SERVICEM8_API_BASE=https://api.servicem8.com/api_1.0
   EOF
   chmod 600 ~/.config/servicem8/credentials.env
   rm -rf .playwright-mcp 2>/dev/null   # remove transient snapshot dir wholesale; never grep+rm on the "smk-" substring (it matches docs + credentials.env)
   ```

7. **Smoke test.**
   ```bash
   set -a; . ~/.config/servicem8/credentials.env; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "X-API-Key: $SERVICEM8_API_KEY" \
     "$SERVICEM8_API_BASE/company.json"
   # => 200
   ```
   `GET /company.json` returned HTTP 200 with one record (the built-in "Help Guide Job" company, `active:0` - the sample data a fresh trial ships with). Connection confirmed. **No Claude Code restart** - direct REST, no MCP server.

## Write-path verification (2026-06-16)

After install, the Phase 2 write path was exercised end-to-end against the same trial and cleaned up:

- `POST /job.json` → `200`, `{"errorCode":0,"message":"OK"}`, new uuid in the `x-record-uuid` header.
- `GET /job/<uuid>.json` → `200`, record present (`active: 1`).
- `POST /note.json` (`related_object:"job"`, `related_object_uuid:<job>`) → `200` - confirms the note endpoint.
- `DELETE /note/<uuid>.json` and `DELETE /job/<uuid>.json` → `200` each.
- `GET /job/<uuid>.json` after delete → `active: 0` (soft-delete; record hidden, not purged).

No live data was left behind beyond the soft-deleted throwaway job.

## Notes for the next run

- The whole flow is ~6 browser actions plus two shell blocks. Sub-minute once the user is signed in.
- If a `Claude Code` key already exists but the stored file is gone, the value is unrecoverable - Remove the row and recreate.
- The persistent Playwright profile keeps the ServiceM8 login alive, so repeat runs skip the sign-in prompt.
