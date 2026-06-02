# Google Ads Connector — Install Walkthrough (Test mode)

> **Status: illustrative, not yet captured.** This walkthrough was authored from the SKILL design (selectors, scripts, expected response shapes) without an end-to-end run against Google's live infrastructure. Timings, IDs, and DOM responses below are projections, not measurements. The walkthrough will be updated with a real captured run once a live smoke test is performed against an actual Google Cloud + Google Ads account; until then, treat the specific numbers as estimates.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 shared → Phase 1T test-mode dev token). The Basic Access path (Phase 1L, 1-3 day wait) is documented separately in `install-walkthrough-live.md`.

**Why test mode is the default:** Basic Access has a mandatory Google review (1-3 business days). A participant who installs at the start of a session can't query data until Test mode is up; the SKILL defaults to Test so the participant has something working today, and Phase 1L is an opt-in upgrade.

**Pre-conditions:**

- Playwright MCP installed and reachable.
- Node, Python 3, jq, and curl on PATH.
- Internet access (Google Cloud, accounts.google.com, ads.google.com, googleads.googleapis.com).
- Participant has a Google account.

Projected end-to-end timing: ~5 minutes from "connect Google Ads" to first GAQL query returning data, about 90 seconds of which is human moments (Google sign-in + consent click + test-account onboarding).

---

## Step 0 — Mode prompt

```
Participant: Connect Google Ads.
Claude:      Quick question: want me to start in test mode so you
             can use the connection today (no real money, just
             practice data), or do you want real data for your
             actual Google Ads account? Real data needs Google to
             approve me first — they usually take 1 to 3 business
             days. Most people pick test mode first.
Participant: test mode is fine.
```

Claude sets `MODE=test` and proceeds to Phase 1.

---

## Phase 1 — Shared OAuth setup

### Step 1 — Welcome

Claude sends the 4-bullet "what to expect" message. No work done yet.

### Step 2 — Sign in to Google Cloud Console

```
mcp__playwright__browser_navigate({ url: "https://console.cloud.google.com/welcome" })
mcp__playwright__browser_wait_for({ text: "Welcome" })   # NOT snapshot — password leak
```

Projected run: participant has an existing Google account session; the page renders the project picker directly. Cold case (no session) is handled by the participant signing in inside the Playwright window.

### Step 3 — Pick a project

Projected run (illustrative `PROJECT_ID=my-personal-projects-2024`): participant has one existing Cloud project; Claude picks it silently.

For a participant with zero projects: Claude drives the `+ Create Project` flow with name `claude-google-ads`.

### Step 4 — Enable the Google Ads API

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/library/googleads.googleapis.com?project=my-personal-projects-2024"
})
```

Projected: API not yet enabled. Claude clicks Enable via `browser_evaluate`. Wait ~10-15 seconds for the post-enable redirect. Page shows "API enabled" and a Manage button. If the button reads `Manage` on first paint, skip.

### Step 5 — Create the OAuth client

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/credentials?project=my-personal-projects-2024"
})
```

**5a — Consent screen prereq.** Projected: consent screen not yet configured. Claude drives the External wizard:
- App name: `Claude Google Ads Connector`
- Support email + developer email: participant's signed-in email
- Test users: added participant's own email (so they can sign in without verification)
- Saved through all 4 steps.

**5b — Create OAuth Client ID.** Application type = Desktop app, name = `Claude Google Ads Connector`. Clicked Create.

The post-create modal shows the Client ID and Client Secret. Claude DOM-extracts both:

```js
{ ok: true, client_id_len: 71, client_secret_len: 35 }
```

Clipboard now holds `{"client_id":"...","client_secret":"..."}`. Tool returns only the length integers — values never appear in the transcript.

### Step 6 — Google Ads account check

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/overview" })
```

Two states the page can be in. Projected: participant has no Google Ads account yet. The page shows *"You don't have any Google Ads accounts. Would you like to create a new one?"* (page copy verified at design time; full end-to-end SKILL run still pending).

Claude clicks **New Google Ads account**, then on the first onboarding page clicks **Switch to Expert Mode** (bottom-left link). The Expert Mode account creation skips the "create your first campaign" pressure and gives a bare-account state immediately. Projected wall-clock: ~25 seconds including Google's billing-skip step (Test-mode accounts don't require billing).

### Step 7 — Start the loopback listener

```bash
PORT=8765   # not in use
python3 -c "...HTTPServer..." > /tmp/google-ads-listener.log 2>&1 &
echo $! > /tmp/google-ads-listener.pid
echo $PORT > /tmp/google-ads-listener.port
```

Listener running on `127.0.0.1:8765`, will write the OAuth code to `/tmp/google-ads-auth-code` on first GET.

### Step 8 — OAuth consent flow

Construct AUTH_URL with `redirect_uri=http://127.0.0.1:8765` and `scope=https://www.googleapis.com/auth/adwords`. Navigate Playwright.

Projected variants:

- Account chooser (when participant has multiple Google accounts) → wait for participant to click their workshop account.
- "This app isn't verified" warning (because the OAuth consent screen is in Testing mode) → Claude clicks **Advanced** → **Go to claude-google-ads (unsafe)**, reassuring the participant in plain English: *"Google's warning is because the connection is only used by you — not a public app. Safe to continue."*
- Consent screen with the `adwords` scope → Claude clicks **Continue**.

The browser redirects to `http://127.0.0.1:8765/?code=4/0Adeu5BU...`. The listener writes the code to `/tmp/google-ads-auth-code`.

### Step 9 — Token exchange

```bash
curl https://oauth2.googleapis.com/token ...  # POST with code, client_id, client_secret
```

Response JSON contained:
- `access_token` — 1 hour TTL
- `refresh_token` — long-lived (rotates only if revoked)
- `expires_in` — 3599
- `scope`: `https://www.googleapis.com/auth/adwords`

Listener torn down. Tmp files cleaned.

### Step 10 — Customer discovery

```bash
curl https://googleads.googleapis.com/v17/customers:listAccessibleCustomers \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Projected response: `{"resourceNames": ["customers/<10 digits>"]}` — one customer (the test account created in Step 6). Single customer → picked silently. (Customer ID `4123456789` is used as an illustrative placeholder throughout the rest of this document.)

---

## Phase 1T — Test mode dev token

### Step 1T.1-1T.2 — DOM-extract the test dev token

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Projected: the API Center page renders with the Test-tier developer token already visible (Google auto-issues this for fresh accounts). Claude DOM-extracts via the same clipboard-transit pattern:

```js
{ ok: true, token_len: 22 }
```

### Step 1T.3 — Save credentials.json

```bash
mkdir -p ~/.config/google-ads
chmod 700 ~/.config/google-ads
jq -n ... > ~/.config/google-ads/credentials.json.tmp
chmod 600 ~/.config/google-ads/credentials.json.tmp
mv ~/.config/google-ads/credentials.json.tmp ~/.config/google-ads/credentials.json
```

Final file structure:

```json
{
  "mode": "test",
  "client_id": "<71 chars>",
  "client_secret": "<35 chars>",
  "access_token": "<token>",
  "refresh_token": "<token>",
  "expires_at": "2026-06-02T06:05:33Z",
  "developer_token": "<22 chars>",
  "customer_id": "4123456789",
  "google_cloud_project": "my-personal-projects-2024"
}
```

Mode 0600. All 9 keys set.

### Step 1T.4 — Smoke test

```bash
curl -sf "https://googleads.googleapis.com/v17/customers/4123456789/googleAds:search" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "developer-token: $DEV_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"SELECT customer.descriptive_name, customer.id FROM customer LIMIT 1"}'
```

Projected response: `{"results":[{"customer":{"resourceName":"customers/<cid>","descriptiveName":"Test account – <project-id>","id":"<cid>"}}]}`.

```
Claude: All connected — your Google Ads test account is ready. Ask
        me things like 'list my test campaigns' or 'show me my
        keywords'.
```

---

## Phase 1F — Wrap the official MCP for reads

Runs after Phase 1T's smoke test succeeds. Best-effort: failures don't block; Phase 2 falls back to direct REST.

### Step 1F.1 — Write ADC credentials JSON

```bash
jq '{type:"authorized_user", client_id, client_secret, refresh_token}' \
  "$HOME/.config/google-ads/credentials.json" \
  > "$HOME/.config/google-ads/adc-credentials.json.tmp"
chmod 600 "$HOME/.config/google-ads/adc-credentials.json.tmp"
mv "$HOME/.config/google-ads/adc-credentials.json.tmp" \
   "$HOME/.config/google-ads/adc-credentials.json"

jq -r 'keys | join(",")' "$HOME/.config/google-ads/adc-credentials.json"
# expected: client_id,client_secret,refresh_token,type
```

### Step 1F.2 — Install pipx if absent

```bash
$ command -v pipx || python3 -m pip install --user pipx
Successfully installed pipx-1.4.3 ...
$ python3 -m pipx ensurepath
Note: PATH already contains /home/<user>/.local/bin
$ export PATH="$HOME/.local/bin:$PATH"
$ pipx --version
1.4.3
```

Projected time: ~10s if pipx absent (downloads + installs from PyPI); 0s if already present.

### Step 1F.3 — Smoke-test the MCP

```bash
$ timeout 30 pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp --help 2>&1 | head -5
Cloning into /tmp/pipx-...  # first run only
Successfully installed google-ads-mcp-... in /home/<user>/.local/share/pipx/...
usage: google-ads-mcp [-h]
Google Ads MCP server
```

First run downloads + venv ~25s; subsequent runs ~2s.

### Step 1F.4 — Register with Claude Code

```bash
$ claude mcp add google_ads --scope user \
    --env "GOOGLE_APPLICATION_CREDENTIALS=$HOME/.config/google-ads/adc-credentials.json" \
    --env "GOOGLE_PROJECT_ID=my-personal-projects-2024" \
    --env "GOOGLE_ADS_DEVELOPER_TOKEN=<22-char token>" \
    -- pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp \
    >/dev/null 2>&1
$ echo $?
0

$ claude mcp list 2>&1 | grep google_ads
google_ads: pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp - ✓ Connected
```

### Step 1F.5 — Restart prompt

The participant restarts Claude Code. On the next session, the `mcp__google_ads__search`, `mcp__google_ads__list_accessible_customers`, and `mcp__google_ads__get_resource_metadata` tools appear.

---

## Phase 2 sample (immediately after install + restart)

```
Participant: List my test campaigns.
Claude:      # ROUTE check: claude mcp list shows google_ads ✓ Connected → ROUTE=mcp
             mcp__google_ads__search({
               customer_id: "4123456789",
               fields: ["campaign.id", "campaign.name", "campaign.status",
                        "campaign_budget.amount_micros"],
               resource: "campaign",
               orderings: ["campaign.name"]
             })
             # → empty results (brand-new test account has no campaigns)
Claude:      Your test account doesn't have any campaigns yet — that's
             expected for a fresh setup. Want me to walk you through
             creating a test campaign so you can see what the data
             looks like?
```

If Phase 1F had been skipped (no Python, or pipx install denied), the same prompt would fall back to:

```
Claude:      # ROUTE=rest (mcp__google_ads__* not registered or .mcp-skipped marker present)
             gaql_call "SELECT campaign.id, campaign.name, campaign.status,
                       campaign_budget.amount_micros FROM campaign
                       ORDER BY campaign.name"
             # → same data, different transport
```

For a test account with pre-existing campaigns (e.g. linked to a manager account's seed data), the response would contain the campaign list.

---

## Total projected timing (illustrative)

| Stage | Wall-clock |
|---|---|
| Step 0 (mode prompt + reply) | 10 s |
| Step 1 (welcome) | 1 s |
| Step 2 (Cloud sign-in detect) | 5 s (participant already signed in) |
| Step 3 (project pick) | 3 s |
| Step 4 (Enable API) | 15 s |
| Step 5a (consent screen wizard) | 60 s |
| Step 5b (OAuth client create + DOM extract) | 15 s |
| Step 6 (New Google Ads account incl. onboarding) | 25 s |
| Step 7 (listener start) | 2 s |
| Step 8 (consent flow incl. 2 human clicks) | 35 s |
| Step 9 (token exchange) | 1 s |
| Step 10 (customer discovery) | 2 s |
| Step 1T.1-1T.2 (dev token extract) | 8 s |
| Step 1T.3-1T.4 (.env write + smoke) | 4 s |
| **Total** | **~3 min** for a participant whose consent screen was already configured; **~5 min** cold (with Step 5a's wizard) |

---

## Failure modes anticipated from design review (will be confirmed once smoke run is performed)

| Failure | Cause | Fix |
|---|---|---|
| Step 4 Enable button missing | API already enabled (button reads Manage) | Skip step |
| Step 5b Client ID field empty in DOM extract | Modal still animating in | Wait 2s and re-run the extract |
| Step 6 New Google Ads account form asks for billing info | Some regions / account types require it even for Test | Tell participant: "Google wants billing details. Fill what they ask — Test accounts won't be charged." |
| Step 8 redirect_uri_mismatch | Google rejected `127.0.0.1` in the OAuth client config | Fall back to `localhost:$PORT`; re-edit OAuth client to add it |
| Step 8 "This app isn't verified" warning blocks Continue button | OAuth consent screen in Testing mode | Click Advanced → Go to claude-google-ads (unsafe). Explain warmly. |
| Step 10 returns empty resourceNames | New Google Ads account not yet propagated | Sleep 30 and retry once |
| Step 1T.2 returns `{ ok: false }` | API Center page structure changed | Snapshot the page, locate dev-token text by visible label, re-run with adjusted selector |

For Basic Access path failures, see `install-walkthrough-live.md`.
