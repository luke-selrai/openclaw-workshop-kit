# TikTok Ads Connector — Install Walkthrough

> **Status: design-pending-smoke (lower confidence than other Tier-1 walkthroughs).** Authored from documented TikTok Marketing API v1.3 behaviour at design time; TikTok's developer-portal docs are JavaScript-rendered SPAs that WebFetch can't read, so specific UI selectors and exact button copy are projected, not verified. The auth header (`Access-Token: <token>`), base URL, and OAuth flow shape are high-confidence (well-documented in TikTok's API reference). UI navigation specifics will likely need adjustment after the first real smoke.

This walkthrough covers the **default install path** (Phase 0 → Phase 1 → Sandbox mode). Production mode walkthrough deferred to a future companion document.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, `python3` on PATH.
- Internet access (business-api.tiktok.com).
- Participant has a TikTok For Business account OR is willing to create one during sign-up (free).

Projected total: ~90 seconds with cached session; ~3-4 minutes cold (TikTok For Business sign-up + verification).

---

## Step 0 — Mode prompt

```
Participant: Connect TikTok Ads.
Claude:      Want me to start in test mode so you can use the
             connection today (fake spend numbers, no real money),
             or do you want real TikTok Ads data for your actual
             advertiser account? Real data is usually instant for
             basic reports, but if your TikTok account has any
             restricted features, those might need TikTok's
             approval (1-2 weeks). Most people pick test mode first.
Participant: Test mode.
```

`MODE=sandbox`. Continue to Phase 1.

---

## Step 1 — Welcome

Claude sends the 3-bullet expectation message.

---

## Step 2 — Sign in to TikTok For Business Developer Portal

```
mcp__playwright__browser_navigate({ url: "https://business-api.tiktok.com/portal/docs" })
mcp__playwright__browser_wait_for({ text: "Apps", time: 60 })
```

Projected: participant signs in (or session cached). The TikTok For Business Developer Portal lands on a post-sign-in page.

For cold sign-up: TikTok For Business may require email verification + phone confirmation. Walkthrough caps the wait at 60s; if it times out, prompt the participant to complete sign-up.

---

## Step 3 — Create App

Projected: existing `Claude Workshop Connector` not found, Claude clicks **New App** / **Create App**.

Form fill:

| Field | Value |
|---|---|
| App name | `Claude Workshop Connector` |
| App description | "Personal Claude-assisted connection to my TikTok Ads for reading reports and managing campaigns." |
| Redirect URI | `http://localhost:8765/callback` |
| Scopes | Ad Account Management, Campaign Management, Reporting (avoid restricted scopes in v1) |

Submit. TikTok issues `app_id` (~7-19 digit numeric) and `secret` (~40-64 alphanumeric).

---

## Step 4 — DOM-extract app_id and secret

Save prior clipboard, then:

```js
{ ok: true, app_id_len: 19, secret_len: 56 }
```

Projected lengths typical of TikTok dev apps. Clipboard holds `{"app_id":"...","secret":"..."}`; tool return contains only lengths.

---

## Step 5 — Start loopback listener

Port 8765 default; auto-increment if taken. Listener accepts either `code` or `auth_code` query parameter (TikTok uses both depending on flow variant).

---

## Step 6 — OAuth consent

Construct AUTH_URL with `app_id`, `state` (random), `redirect_uri`. Navigate Playwright.

Projected: consent screen renders ("Authorize Claude Workshop Connector to access..."). Claude clicks **Confirm**. Sandbox advertiser auto-provisions if none exists. Browser redirects to `http://localhost:8765/callback?auth_code=...&state=...`. Listener captures the auth_code.

---

## Step 7 — Token exchange

```bash
curl -X POST https://business-api.tiktok.com/open_api/v1.3/oauth2/access_token/ \
  -H 'Content-Type: application/json' \
  -d '{"app_id":"...","secret":"...","auth_code":"..."}'
```

Projected response:

```json
{
  "code": 0,
  "message": "OK",
  "data": {
    "access_token": "<token>",
    "advertiser_ids": [7000000000123456789],
    "scope": [4, 5, 6]
  }
}
```

`advertiser_ids` are returned directly — no separate discovery call. For Sandbox mode, expect 1 auto-provisioned ID.

---

## Step 8 — Pick advertiser

Single advertiser → silently pick. Multiple → ask participant. `ADVERTISER_ID="<chosen>"`.

---

## Step 9 — Save credentials.json

```bash
$ jq -r 'keys | join(",")' ~/.config/tiktok-ads/credentials.json
access_token,advertiser_id,api_endpoint,app_id,created_at,mode,secret
$ stat -c %a ~/.config/tiktok-ads/credentials.json
600
```

Mode 0600; `umask 077` before mkdir as defense-in-depth.

---

## Step 10 — Smoke test

```bash
$ curl -sf "https://business-api.tiktok.com/open_api/v1.3/advertiser/info/?advertiser_ids=[\"<adv>\"]" \
    -H "Access-Token: <token>" | jq -r '.data.list[0].name'
Sandbox Advertiser
```

Claude tells the participant:

```
Claude: All connected — your TikTok Ads Sandbox Advertiser is ready.
        Ask me things like 'what's my TikTok spend this month?' or
        'show me my top campaigns'.
```

---

## Phase 2 sample

```
Participant: TikTok spend this month.
Claude:      # MODE=sandbox, no gate
             tk_get "/report/integrated/get/" "..."
Claude:      You've spent $1,247 on TikTok Ads so far this month
             across 3 active campaigns.
```

(Sandbox spend is fake data; real shape match for Production mode.)

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (mode prompt) | 10 s |
| Step 1 (welcome) | 1 s |
| Step 2 (sign-in detect) | 15 s cached / 90 s cold for sign-up |
| Step 3 (App create form + submit) | 30 s |
| Step 4 (DOM-extract) | 2 s |
| Step 5 (listener) | 1 s |
| Step 6 (consent + redirect) | 10 s |
| Step 7 (token exchange) | 1 s |
| Step 8 (advertiser pick) | 1 s |
| Step 9 (credentials.json) | 0.5 s |
| Step 10 (smoke) | 1 s |
| **Total** | **~70 s cached / ~150 s cold** |

---

## Failure modes anticipated from design review (lower confidence — verify at first smoke)

| Failure | Possible cause | Fix |
|---|---|---|
| Step 2 `browser_wait_for("Apps")` times out | TikTok For Business sign-up flow blocks at email/phone verification | Prompt participant to complete verification; re-poll |
| Step 3 form fields don't match | TikTok's developer portal UI was redesigned post-design-time | Snapshot the form, adjust selectors |
| Step 4 returns `{ ok: false }` | TikTok's credential display widget is in a non-standard container (e.g., tooltip, copy-button only) | Tell participant: "Could you copy your App ID and Secret manually — they're on the App overview page" |
| Step 6 auth_code redirect uses different param name | TikTok's auth-code flow has shipped variants (`code` vs `auth_code`) | Listener already accepts both; verify which TikTok sends in the smoke |
| Step 7 returns `code: 40002` "invalid app_id" | App still propagating server-side | Wait 30s, retry once |
| Step 7 `advertiser_ids` empty | Sandbox advertiser didn't auto-provision | Drive Playwright to create one manually; or surface the issue to the participant |
| Step 10 HTTP 200 with `code != 0` | Permission scope insufficient | Re-run Phase 1, ensure all 3 scopes (Ad Account, Campaign Management, Reporting) were ticked at App creation |

For Phase 2 failures, see the SKILL's Error Handling section. Note: TikTok returns HTTP 200 for ALL responses; check `code: 0` for success, not the HTTP status.
