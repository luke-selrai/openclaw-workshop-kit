# Starshipit connector — live install walkthrough (verified)

A real Phase 1 run executed 2026-06-16. Both key values are **redacted** (Starshipit API key and subscription key are each ~32 alphanumeric chars). Happy path with the real deviations noted.

## What ran

1. **Sign in (user step).** Opened `https://app.starshipit.com/` → redirected to `Account/MemberLogin.aspx`. Did **not** snapshot (password-leak rule). The user signed in; post-login landed on `Templates/Admin4/Orders.aspx` ("New Orders"). Detected via the "Orders" nav text.

2. **Open Settings → API.** Navigated to `https://app.starshipit.com/Members/Settings/API2.aspx` (legacy ASP.NET form). Inspected the two key fields (lengths only):
   - `#ctl00_ContentPlaceHolder1_tbApiKey` → **32 chars** (API key already existed, read-only).
   - `#ctl00_ContentPlaceHolder1_tbAzurePrimaryKey` → **0 chars** (subscription key not yet generated).

3. **Generate + save the subscription key.** Clicked `#ctl00_ContentPlaceHolder1_RadButton_GenerateAzurePrimaryKey_input` (Generate) → field populated to 32 chars → clicked `#ctl00_ContentPlaceHolder1_bSave_input` (Save) to persist.

4. **Capture both keys.** Read both field values via `browser_evaluate` into the clipboard as `{"api_key":…,"sub_key":…}`, returning only lengths (32/32). **No screenshot of the keys.** Notably, neither key value entered the transcript — the cleanest capture of the connector set.

5. **Store + scrub.**
   ```bash
   install -d -m 700 ~/.config/starshipit
   # keys read from clipboard via jq, written without echo
   cat > ~/.config/starshipit/credentials.env <<EOF
   STARSHIPIT_API_KEY=<redacted>
   STARSHIPIT_SUBSCRIPTION_KEY=<redacted>
   STARSHIPIT_API_BASE=https://api.starshipit.com/api
   EOF
   chmod 600 ~/.config/starshipit/credentials.env
   ( printf '' | wl-copy ) ; rm -rf .playwright-mcp   # clear clipboard + transient snapshots wholesale
   ```

6. **Smoke test.** First tried `GET /deliveryservices` → **404 with a JSON body** (`{"statusCode":404,...}`) — which proved *auth worked* (a 401/403 would mean bad keys); the path was just wrong. Probing found the real reads:
   ```
   GET /orders/unshipped -> 200  {"orders":[],"total_pages":1,"success":true}
   GET /addressbook      -> 200  {"addresses":[]}
   GET /orders           -> 200  {paged, empty on a fresh account}
   ```
   **No Claude Code restart** — direct REST.

## Notes / lessons for the next run

- **Two keys, always.** Both `StarShipIT-Api-Key` and `Ocp-Apim-Subscription-Key` on every call.
- The **API key pre-exists**; the **subscription key may be empty** → Generate + Save once.
- **404-with-JSON means wrong path, not bad keys** — probe a couple of documented endpoints rather than assuming one.
- Capture via clipboard-transit returning lengths only — keeps both keys out of the transcript.
- Scrub `.playwright-mcp` wholesale (the API-settings snapshot can contain the key field values); never `grep <key> | rm`.
- ASP.NET element ids (`ctl00_ContentPlaceHolder1_*`) are observed-live but brittle — match by the "API Key" / "Subscription" labels if they drift.
