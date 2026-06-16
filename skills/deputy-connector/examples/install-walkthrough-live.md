# Deputy connector — live install walkthrough (verified)

A real Phase 1 run executed 2026-06-16 against a 31-day Core Plan trial. The token value is **redacted** (Deputy permanent tokens are ~32 alphanumeric chars). Happy path with the real deviations noted.

## What ran

1. **Sign in (user step).** Opened `https://once.deputy.com/my/`; the user signed in with Google. `once.deputy.com/my/` first showed *"You aren't currently a member of any business"* — the user created a business (test-fixture setup, **outside** the connector's scope). After that, opening the business landed on `https://b9e78716081714.au.deputy.com/#/roster/1`. Parsed from the host: **install `b9e78716081714`, geo `au`** → base URL `https://b9e78716081714.au.deputy.com/api/v1`.

2. **Open the developer page.** `GET /exec/devapp/oauth_clients` listed Deputy's system clients (CloudWorks, Deputy Proxy, Deputy.com, Exporter by Deputy — left untouched) plus a **New OAuth Client** button.

3. **Create the OAuth client.** Clicked **New OAuth Client** → form fields `#fpName`, `#fpDescription`, `#fpLogoUrl`, `#fpRedirectUri` (Name + Redirect URI required). Filled `#fpName` = `Claude Code`, `#fpRedirectUri` = `https://localhost/callback` → **Save This OAuth Client** (top toolbar). The saved detail view showed Client Id + Client Secret (not needed for the permanent-token flow) and a **Get An Access Token** toolbar button.

4. **Mint the token.** Clicked **Get An Access Token** → modal: *"Access Token is XXXX. This is a long life token that will last 10 years."*

5. **Capture (once).** Read via `browser_evaluate` matching `/Access Token is\s+([A-Za-z0-9]{16,})/` into the clipboard — **no screenshot of the modal**.
   - *Footgun observed:* a first extraction attempt used a `{40,}` length floor and missed the 32-char token, and the debug fallback **printed the token in its return** — so the value briefly hit the transcript. Match the exact "Access Token is …" phrase and never dump dialog text containing the token.

6. **Store + scrub.**
   ```bash
   install -d -m 700 ~/.config/deputy
   # token read from clipboard, written without echo
   cat > ~/.config/deputy/credentials.env <<EOF
   DEPUTY_API_TOKEN=<redacted>
   DEPUTY_INSTALL=b9e78716081714.au.deputy.com
   DEPUTY_GEO=au
   DEPUTY_API_BASE=https://b9e78716081714.au.deputy.com/api/v1
   EOF
   chmod 600 ~/.config/deputy/credentials.env
   ( printf '' | wl-copy ) ; rm -rf .playwright-mcp   # clear clipboard + transient snapshots wholesale
   ```

7. **Smoke test.**
   ```bash
   set -a; . ~/.config/deputy/credentials.env; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $DEPUTY_API_TOKEN" \
     -H "Accept: application/json" "$DEPUTY_API_BASE/me"
   # => 200
   ```
   Returned the authenticated user ("Rodolfo Raquion") and `CompanyObject.CompanyName` "Selr AI". **No Claude Code restart** — direct REST.

## Write-path verification (2026-06-16)

After install, a resource write path was exercised end-to-end against the same trial and cleaned up:

- `GET /resource/Employee` → read OK (1 employee).
- `POST /resource/OperationalUnit` with a minimal body → **`417 "Column 'show_on_roster' cannot be null"`** — Deputy enforces non-null columns.
- Resent with `{"OperationalUnitName":"ZZ-Claude-Test-DELETE","Company":1,"ShowOnRoster":1,"RosterActive":1}` → created, returned `Id`.
- `GET /resource/OperationalUnit/<id>` → read-back OK.
- `DELETE /resource/OperationalUnit/<id>` → **`200`**.

No live data was left behind. Lesson captured in `references/rest-api.md` → "Required fields (creates)": on a 417, read the named column, add the field, retry.

## Notes / lessons for the next run

- The connector **assumes an existing install** — business creation is product onboarding, not part of this skill.
- Read install + geo from the post-login URL; everything depends on the right region host.
- The token is **long-life (~10 years) and high-privilege** — store mode 600, never echo, and rotate by deleting the `Claude Code` OAuth client then re-minting.
- Extract the token by the exact "Access Token is …" phrase; never let a debug branch return the surrounding dialog text. **Scrub `.playwright-mcp` wholesale** — never `grep <token> | rm`.
- Leave Deputy's system OAuth clients alone; only manage the `Claude Code` one.
