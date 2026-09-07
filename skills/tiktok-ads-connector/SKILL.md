---
name: tiktok-ads-connector
description: "Connect TikTok Ads to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect TikTok Ads, or wants TikTok for Business work (campaigns, ad groups, ads, ad spend and conversion reports, audiences, budgets) and the credentials aren't in place yet. Once connected, TikTok Ads runs directly against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - tiktok-ads
    - tiktok
    - paid-ads
    - ppc
    - social-ads
    - rest-api
    - oauth
  pairs-with:
    - skill: google-ads-connector
      reason: Sibling Tier-1 ads connector. Google Ads + TikTok Ads are the two most common SMB paid-acquisition channels in 2026; SMBs running both want unified reporting. Same Phase 0 sandbox/production split.
    - skill: paid-ads
      reason: Strategy advisor - pair when participant wants advice on what to DO with the data this connector returns.
    - skill: myob-connector
      reason: Reference Direct-REST + Playwright pattern (loopback OAuth listener, atomic credentials.json).
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting TikTok API token-scope edge cases.
---

# TikTok Ads Connector

## Overview

This skill lets you read and operate a user's TikTok For Business Ads account on their behalf using **TikTok Marketing API v1.3** (no MCP server, no first-party CLI - Direct-REST + Playwright pattern).

It has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright + REST).** Claude drives `business-api.tiktok.com` via Playwright MCP to sign the participant in, create a developer App in the TikTok For Business Developer Portal, capture `app_id` + `secret` + `redirect_uri` configuration, run the OAuth2 flow via a local loopback listener on `localhost:8765`, exchange the auth code for a long-lived `access_token`, list accessible `advertiser_id`s, and persist everything to `~/.config/tiktok-ads/credentials.json` (mode 0600). The participant's manual moments: signing in to TikTok For Business once + approving the OAuth consent.
- **Phase 2 - Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` TikTok Marketing API endpoints with the `Access-Token: <token>` header and the appropriate `advertiser_id` query param. Writes (pause/resume campaigns, adjust budgets) gated by per-call confirmation prose in Production mode.

**Two modes, picked at Phase 0:**

| Mode | When | What it touches | Wait |
|---|---|---|---|
| **Sandbox** | Default for first-time install. | TikTok's Sandbox advertiser (auto-provisioned). Fake spend data, no real money, all endpoints work. | Immediate (TikTok auto-creates a Sandbox advertiser on first app creation). |
| **Production** | When the participant says "I want my real TikTok Ads data." | Real advertiser account, real spend. Some scopes (e.g., audience targeting, conversion event access) may require TikTok app review (~1-2 weeks). Read-only scopes for performance reports typically don't require review. | Immediate for basic read scopes; ~1-2 weeks for write scopes that touch audience/conversion data. |

**Sandbox-by-default** matches the Google Ads test-mode framing - instant access for workshop participants. Production mode is opt-in; for the workshop's most common case (reading spend + performance), Production access is usually self-serve once the App is created.

> **Status: design-pending-smoke.** This SKILL was authored without an end-to-end run against TikTok's live developer portal (TikTok's docs are JavaScript-rendered SPAs not reachable from WebFetch). The Playwright selectors, exact button copy, and Sandbox-advertiser auto-provisioning behaviour below are projected from TikTok Marketing API v1.3 documented behaviour at design time. A smoke run will likely surface UI variants that need adjustment. The auth header (`Access-Token: <token>`), base URL (`https://business-api.tiktok.com/open_api/v1.3/`), and OAuth flow shape are well-documented and high-confidence.

**Which phase to run** - Before any tool call:

```bash
test -f "$HOME/.config/tiktok-ads/credentials.json" && jq -r '.mode // "missing"' "$HOME/.config/tiktok-ads/credentials.json" 2>/dev/null || echo missing
```

- `sandbox` or `production` → credentials present. Smoke (`GET /oauth2/advertiser/get/`); on success → Phase 2.
- `missing` → run Phase 0 + Phase 1.

---

## Golden rule - do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside Playwright MCP. Never tell the participant to "open TikTok in your browser." Claude navigates; the participant signs in directly in the Playwright window. Same as every other connector in this kit.

If Playwright MCP is unavailable, halt and point at install instructions.

---

## Communication rules for Phase 1

Plain English only. The participant runs a small business and wants ad performance numbers, not API internals.

- **One step at a time.** Never stack instructions.
- **Plain English only.** Never say API, token, OAuth, scope, refresh, Bearer, Access-Token, header, REST, endpoint, JSON, advertiser_id, app_id, env var, curl, terminal, CLI, MCP, callback, loopback, sandbox (use "test mode" / "practice mode"), file path. If you must, say "your connection details" or "your TikTok Ads connection".
- **Tell them what is about to happen.** *"I'm opening TikTok For Business now - sign in when you see the page. About 90 seconds."*
- **React warmly.** Good: *"Connected to your TikTok Ads - **3 advertisers** loaded."* Bad: *"Access-Token persisted, advertiser_ids: [123, 456, 789]."*
- **Never show error messages directly.** Translate.
- **Short responses.** Max 8 lines per message.
- **Never echo credentials** - app_id, secret, access_token. None of them ever appears in participant-visible output.
- **Sandbox vs Production** - say "test mode" / "practice mode" / "real Ads data" rather than the technical labels.

---

## ⛔ Pre-flight check

Verify Playwright MCP tools are available (`ToolSearch +playwright`). If absent, halt.

---

## PHASE 0 - Mode + state detection

### Step 0.1 - Read existing credentials

```bash
CREDS="$HOME/.config/tiktok-ads/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.mode // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

- `missing` → continue to Step 0.2.
- `sandbox` → Phase 2 with no gates (fake data).
- `production` → Phase 2 with real-data gate + per-write gate.

### Step 0.2 - Ask Sandbox or Production

> "Want me to start in **test mode** so you can use the connection today (fake spend numbers, no real money), or do you want **real TikTok Ads data** for your actual advertiser account? Real data is usually instant for basic reports, but if your TikTok account has any restricted features, those might need TikTok's approval (1-2 weeks). Most people pick test mode first to play with the features."

Map:

- "test", "practice", "today", default → `MODE=sandbox`.
- "real", "live", "production", "actual" → `MODE=production`.

Do NOT say "sandbox" to the participant - say "test mode".

---

## PHASE 1 - Install & Connect

### Step 1 - Welcome

> "Great - connecting your TikTok Ads. Three quick things:
> 1. Sign in to TikTok For Business when I open the page.
> 2. Approve the connection when it asks.
> 3. If this is your first time, TikTok creates a developer account automatically.
> About 90 seconds total."

### Step 2 - Sign in to TikTok For Business Developer Portal

```
mcp__playwright__browser_navigate({ url: "https://business-api.tiktok.com/portal/docs?id=1738855099573250" })
```

(Or the developer-portal landing page. TikTok routes through several URLs; the goal is to land on a page that requires sign-in.)

**Do NOT snapshot the sign-in page.** Use:

```
mcp__playwright__browser_wait_for({ text: "Apps", time: 60 })
```

(or "My Apps", "Developer Console" - TikTok labels the post-sign-in page variably).

### Step 3 - Create or find an App

Navigate to the My Apps page (typically `business-api.tiktok.com/portal/app/list`). Check for existing `Claude Workshop Connector`:

```js
() => {
  const rows = Array.from(document.querySelectorAll('a, tr, [data-app-row]'));
  const existing = rows.find(r => /claude workshop connector/i.test((r.innerText||'').trim()));
  if (existing) { existing.click(); return { existed: true }; }
  const create = Array.from(document.querySelectorAll('button, a')).find(b => /^(create|new)\s+app$/i.test((b.innerText||'').trim()));
  if (create) { create.click(); return { existed: false, clicked_create: true }; }
  return { ok: false, reason: 'no_create_button' };
}
```

Fill the new-app form:

| Field | Value |
|---|---|
| App name | `Claude Workshop Connector` |
| App description | "Personal Claude-assisted connection to my TikTok Ads for reading reports and managing campaigns." |
| Redirect URI | `http://localhost:8765/callback` |
| Scopes | Read-only basic: `Ad Account Management`, `Campaign Management`, `Reporting`. Avoid restricted scopes (Audience, Pixel/Event API write) in v1 - those need TikTok review. |

Submit. TikTok issues `app_id` and `secret` immediately.

### Step 4 - Capture app_id and secret in the isolated browser

Prepare a private transfer directory (macOS and Linux):

```bash
umask 077
ADS_CAPTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ads-capture.XXXXXX")"
ADS_CAPTURE_NAME="$(python3 -c 'import secrets; print("ads-capture-" + secrets.token_hex(12))')"
printf '%s\n' "$ADS_CAPTURE_DIR" "$ADS_CAPTURE_NAME"
```

Before any real credential capture, run the download sequence below on a disposable blank tab with a public synthetic marker and the filename `$ADS_CAPTURE_NAME-probe.txt`. The random name uses only lowercase letters, digits and hyphens: MCP filename sanitization changes interior dots, so do not derive download names from the dotted `mktemp` directory name. Read the MCP's **Downloaded file … to …** event and locate that exact file from Bash. Use the event's actual path even if its basename differs from `link.download`; the requested name is not proof of the saved name. Its parent is the actual MCP output directory; retain its absolute path as `ADS_OUTPUT_DIR`. The MCP saves an additional copy there even when `download.saveAs` points elsewhere and `download.delete()` succeeds. Protect that known directory before continuing:

```bash
test -d "$ADS_OUTPUT_DIR" && test -O "$ADS_OUTPUT_DIR" || exit 1
chmod 700 "$ADS_OUTPUT_DIR"
```

Remove only the synthetic probe files you just created. Preserve other downloads, snapshots and server settings. If the output path cannot be identified or protected, stop before handling a real credential. An absolute `browser_evaluate` filename outside the MCP output directory is rejected; its automatic snapshot also makes it unsuitable for capturing a secret-bearing page.

Use the browser's Playwright run-code tool for the capture below. Substitute the printed directory path in `saveAs` and the unique `ADS_CAPTURE_NAME` in `link.download`; retain both for subsequent shell calls. No Node `require`, `process` or imports are needed in the run-code VM. Only lengths return to the conversation. Do not take a page snapshot while secrets are visible; leave the participant's clipboard untouched. Pre-create the exact two destination files without replacing an existing file:

```bash
umask 077
(set -C; : > "$ADS_CAPTURE_DIR/client.json") || exit 1
(set -C; : > "$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-client.json") || exit 1
```

```js
async (page) => {
  const out = await page.evaluate(() => {
    // TikTok app_id is typically 7-19 numeric digits; secret is 40-64 alphanumeric.
    const labels = Array.from(document.querySelectorAll('*'))
      .filter(el => el.children.length === 0 && /^(app\s*id|client\s*key|secret)\s*:?$/i.test((el.innerText||'').trim()));
    const out = {};
    for (const label of labels) {
      const which = /secret/i.test(label.innerText) ? 'secret' : 'app_id';
      if (out[which]) continue;
      let scope = label.parentElement;
      for (let d = 0; d < 8 && scope; d++) {
        const fields = Array.from(scope.querySelectorAll('input, code, span'));
        for (const f of fields) {
          const v = (f.value || f.innerText || '').trim();
          const valid = which === 'app_id' ? /^\d{7,19}$/.test(v) : /^[A-Za-z0-9_-]{40,64}$/.test(v);
          if (valid) {
            out[which] = v;
            break;
          }
        }
        if (out[which]) break;
        scope = scope.parentElement;
      }
    }
    if (!out.app_id || !out.secret) return null;
    return out;
  });
  if (!out) return { ok: false };
  const download_promise = page.waitForEvent('download');
  await page.evaluate((values) => {
    const link = document.createElement('a');
    const blob_url = URL.createObjectURL(new Blob([JSON.stringify(values)], { type: 'application/json' }));
    link.href = blob_url;
    link.download = "<ADS_CAPTURE_NAME>-client.json";
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(blob_url), 1000);
  }, out);
  const download = await download_promise;
  await download.saveAs("<absolute ADS_CAPTURE_DIR>/client.json");
  await download.delete();
  return { ok: true, app_id_len: out.app_id.length, secret_len: out.secret.length };
}
```

Read this capture's **Downloaded file … to …** event and retain the resolved absolute path as `ADS_CLIENT_OUTPUT`. Verify it belongs to the protected output directory and matches the expected unique name. If the tool changes the name or directory, the guard below rejects it and preserves every file; resolve the mismatch before continuing. Never infer the cleanup path solely from `link.download`.

```bash
python3 - "$ADS_CAPTURE_DIR/client.json" "$ADS_OUTPUT_DIR" "$ADS_CAPTURE_NAME" "$ADS_CLIENT_OUTPUT" <<'PY'
import os
from pathlib import Path
import re
import stat
import sys

private_file, output_dir, capture_name, reported_file = sys.argv[1:]
private_file = Path(private_file)
output_dir = Path(output_dir).resolve(strict=True)
reported_file = Path(reported_file)
if not re.fullmatch(r'ads-capture-[a-f0-9]{24}', capture_name):
    raise SystemExit('Invalid capture name; files preserved')
if not reported_file.is_absolute() or reported_file.name != capture_name + '-' + private_file.name:
    raise SystemExit('Unexpected download name; files preserved')
if reported_file.parent.resolve(strict=True) != output_dir:
    raise SystemExit('Unexpected download directory; files preserved')
for directory in (output_dir, private_file.parent):
    info = directory.stat()
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise SystemExit('Capture directory is not private; files preserved')
for file in (private_file, reported_file):
    info = file.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        raise SystemExit('Unexpected capture file; files preserved')
private_file.chmod(0o600)
reported_file.chmod(0o600)
reported_file.unlink()
PY
```

Validation: `app_id` typically 7-19 numeric chars; `secret` 40-64 alphanumeric.

### Step 5 - Start loopback listener

```bash
umask 077
rm -f /tmp/tiktok-ads-listener.port /tmp/tiktok-ads-auth-code

nohup python3 -c "
import errno, http.server, urllib.parse, sys
class H(http.server.BaseHTTPRequestHandler):
  def log_message(self, *a, **k): pass
  def do_GET(self):
    params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
    code = params.get('auth_code', params.get('code', ['']))[0]
    self.send_response(200)
    self.send_header('Content-Type', 'text/html')
    self.end_headers()
    self.wfile.write(b'<h1>TikTok Ads connected. You can close this tab.</h1>')
    with open('/tmp/tiktok-ads-auth-code', 'w') as f: f.write(code)
    sys.exit(0)
for port in range(8765, 8865):
  try:
    server = http.server.HTTPServer(('127.0.0.1', port), H)
    break
  except OSError as error:
    if error.errno != errno.EADDRINUSE:
      raise
else:
  raise SystemExit('No available loopback port')
with open('/tmp/tiktok-ads-listener.port', 'w') as port_file:
  port_file.write(str(server.server_port))
server.serve_forever()
" > /tmp/tiktok-ads-listener.log 2>&1 &
echo $! > /tmp/tiktok-ads-listener.pid
for i in $(seq 1 50); do
  [ -s /tmp/tiktok-ads-listener.port ] && break
  kill -0 "$(cat /tmp/tiktok-ads-listener.pid)" 2>/dev/null || break
  sleep 0.1
done
[ -s /tmp/tiktok-ads-listener.port ] || { echo 'Connection listener could not start'; exit 1; }
PORT="$(cat /tmp/tiktok-ads-listener.port)"
```

Before Step 6, confirm the app's registered redirect URI matches `http://localhost:$PORT/callback`; update that app setting if the chosen port changed from 8765. Keep the listener running while consent completes.

> TikTok uses `auth_code` as the query parameter name (not `code`) in some flows; the listener accepts either.

### Step 6 - Drive OAuth consent

```bash
APP_ID="$(jq -r '.app_id' "$ADS_CAPTURE_DIR/client.json")"
PORT="$(cat /tmp/tiktok-ads-listener.port)"
STATE="$(python3 -c 'import secrets; print(secrets.token_urlsafe(16))')"
AUTH_URL="https://business-api.tiktok.com/portal/auth?app_id=${APP_ID}&state=${STATE}&redirect_uri=http%3A%2F%2Flocalhost%3A${PORT}%2Fcallback"
```

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Page states:

- **Consent screen** ("Authorize Claude Workshop Connector to access...") → Playwright clicks **Confirm** / **Authorize**.
- **Advertiser-selector** (when participant has multiple TikTok For Business advertisers) → pick the first or the participant's primary.
- **Sandbox auto-create** (if `MODE=sandbox` and no existing TikTok For Business account) → TikTok auto-provisions a Sandbox advertiser and proceeds.

Poll `/tmp/tiktok-ads-auth-code`:

```bash
for i in $(seq 1 90); do
  [ -s /tmp/tiktok-ads-auth-code ] && break
  sleep 2
done
AUTH_CODE="$(cat /tmp/tiktok-ads-auth-code)"
```

### Step 7 - Exchange auth code for access token

```bash
APP_ID="$(jq -r '.app_id' "$ADS_CAPTURE_DIR/client.json")"
SECRET="$(jq -r '.secret' "$ADS_CAPTURE_DIR/client.json")"

RESP="$(curl -sf "https://business-api.tiktok.com/open_api/v1.3/oauth2/access_token/" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg ai "$APP_ID" --arg s "$SECRET" --arg ac "$AUTH_CODE" \
    '{app_id:$ai, secret:$s, auth_code:$ac}')")"

# Tear down listener
kill "$(cat /tmp/tiktok-ads-listener.pid)" 2>/dev/null
rm -f /tmp/tiktok-ads-auth-code /tmp/tiktok-ads-listener.pid /tmp/tiktok-ads-listener.port /tmp/tiktok-ads-listener.log
```

Response shape:

```json
{
  "code": 0,
  "message": "OK",
  "data": {
    "access_token": "<long-lived token>",
    "advertiser_ids": [123456, 789012],
    "scope": [...]
  }
}
```

TikTok returns `advertiser_ids` directly in the token exchange response - no separate discovery call needed. The list includes all advertisers the OAuth grant authorized.

### Step 8 - Pick advertiser_id

```bash
ACCESS_TOKEN="$(echo "$RESP" | jq -r '.data.access_token')"
ADV_IDS=($(echo "$RESP" | jq -r '.data.advertiser_ids[]'))

if [ ${#ADV_IDS[@]} -eq 1 ]; then
  ADVERTISER_ID="${ADV_IDS[0]}"
elif [ ${#ADV_IDS[@]} -gt 1 ]; then
  # Multiple advertisers - ask the participant
  echo "Multiple advertisers: ${ADV_IDS[*]}"
  # Pattern: ask participant which to connect
fi
```

For Sandbox mode, expect 1 auto-provisioned Sandbox advertiser. For Production, the participant may have multiple real advertisers if they manage clients.

### Step 9 - Save credentials.json

```bash
umask 077
mkdir -p "$HOME/.config/tiktok-ads"
chmod 700 "$HOME/.config/tiktok-ads"

APP_ID="$(jq -r '.app_id' "$ADS_CAPTURE_DIR/client.json")"
SECRET="$(jq -r '.secret' "$ADS_CAPTURE_DIR/client.json")"

jq -n \
  --arg mode "$MODE" \
  --arg ai "$APP_ID" \
  --arg s "$SECRET" \
  --arg at "$ACCESS_TOKEN" \
  --arg adv "$ADVERTISER_ID" \
  --arg ep "https://business-api.tiktok.com/open_api/v1.3" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{mode:$mode, app_id:$ai, secret:$s, access_token:$at, advertiser_id:$adv,
    api_endpoint:$ep, created_at:$created}' \
  > "$HOME/.config/tiktok-ads/credentials.json.tmp"
chmod 600 "$HOME/.config/tiktok-ads/credentials.json.tmp"
mv "$HOME/.config/tiktok-ads/credentials.json.tmp" "$HOME/.config/tiktok-ads/credentials.json"

rm -f "$ADS_CAPTURE_DIR/client.json"
rmdir "$ADS_CAPTURE_DIR"

unset APP_ID SECRET ACCESS_TOKEN
```

If setup is abandoned before saving, first run the guarded download cleanup in Step 4 for any remaining MCP copy, then remove the private capture file and its directory. Retain it while resuming an unfinished step.

### Step 10 - Smoke test

```bash
ACCESS_TOKEN="$(jq -r .access_token "$HOME/.config/tiktok-ads/credentials.json")"
ADV="$(jq -r .advertiser_id "$HOME/.config/tiktok-ads/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/tiktok-ads/credentials.json")"

curl -sf "$API_ENDPOINT/advertiser/info/?advertiser_ids=[\"$ADV\"]" \
  -H "Access-Token: $ACCESS_TOKEN" | jq -r '.data.list[0].name'
```

Returns the advertiser name. Tell the participant:

> "All connected - your TikTok Ads **[advertiser name]** is ready. Ask me things like *'what's my TikTok ad spend this month?'* or *'show me my top campaigns'*."

---

## PHASE 2 - Use Tools

### Helper - base curl shape

```bash
tk_get() {
  local path="$1"; local params="$2"
  curl -sf "$API_ENDPOINT$path?$params" -H "Access-Token: $ACCESS_TOKEN"
}
tk_post() {
  local path="$1"; local body="$2"
  curl -sf -X POST "$API_ENDPOINT$path" \
    -H "Access-Token: $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$body"
}
```

### Mode-aware behaviour

- `MODE=sandbox` - fake data, freely callable.
- `MODE=production` - real ad spend, real conversions. Real-data gate + per-write gate apply.

### Production-mode gate 1 - Real-data confirmation (first call per session)

```bash
ADV_NAME="$(tk_get "/advertiser/info/" "advertiser_ids=[\"$ADV\"]" | jq -r '.data.list[0].name')"
```

Tell participant: *"Just confirming - you're connected to your real TikTok Ads account **[ADV_NAME]**. Anything I do here changes your live campaigns. OK to proceed with **[summary]**?"* ONCE per session.

### Production-mode gate 2 - Destructive-op confirmation (every write)

| Operation | Prompt |
|---|---|
| Pause campaign | "I'm about to **pause** campaign **[Name]** (ID [id]). It will stop showing ads immediately. OK?" |
| Resume campaign | "I'm about to **resume** campaign **[Name]**. It will start showing ads as soon as TikTok processes the change. OK?" |
| Change daily budget | "I'm about to change the daily budget of campaign **[Name]** from **$[old]** to **$[new]**. This affects your spend starting tomorrow. OK?" |

### Common Pattern 1 - Spend this month

```bash
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=BASIC&data_level=AUCTION_ADVERTISER&dimensions=[\"advertiser_id\"]&metrics=[\"spend\"]&start_date=$(date +%Y-%m-01)&end_date=$(date +%Y-%m-%d)" | jq '.data.list[0].metrics.spend'
```

Returns total spend this month for the connected advertiser. Format as currency.

**Use when:** "TikTok spend this month", "how much have I spent on TikTok?"

### Common Pattern 2 - Top campaigns by conversions

```bash
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=BASIC&data_level=AUCTION_CAMPAIGN&dimensions=[\"campaign_id\"]&metrics=[\"campaign_name\",\"spend\",\"conversions\",\"cost_per_conversion\"]&start_date=$(python3 -c 'from datetime import date, timedelta; print(date.today() - timedelta(days=30))')&end_date=$(date +%Y-%m-%d)&page_size=10&page=1" | jq '.data.list | sort_by(-.metrics.conversions | tonumber) | .[:10]'
```

Last 30 days top 10 by conversions. Present as table.

**Use when:** "best TikTok campaigns", "top performers", "what's working?"

### Common Pattern 3 - List campaigns

```bash
tk_get "/campaign/get/" "advertiser_id=$ADV&page_size=50" | jq '.data.list[] | {campaign_id, campaign_name, status: .operation_status, budget, budget_mode, objective_type}'
```

`operation_status`: `ENABLE`, `DISABLE` (paused), `DELETE`. Filter as needed.

**Use when:** "list my TikTok campaigns", "show all campaigns"

### Common Pattern 4 - List ad groups in a campaign

```bash
CAMPAIGN_ID="<from Pattern 3>"
tk_get "/adgroup/get/" "advertiser_id=$ADV&filtering={\"campaign_ids\":[\"$CAMPAIGN_ID\"]}&page_size=20" | jq '.data.list[] | {adgroup_id, adgroup_name, status: .operation_status, budget}'
```

**Use when:** "ad groups in [campaign]", "[campaign] details"

### Common Pattern 5 - List ads in an ad group

```bash
ADGROUP_ID="<from Pattern 4>"
tk_get "/ad/get/" "advertiser_id=$ADV&filtering={\"adgroup_ids\":[\"$ADGROUP_ID\"]}&page_size=20" | jq '.data.list[] | {ad_id, ad_name, status: .operation_status, ad_text}'
```

**Use when:** "ads in [adgroup]", "show me the actual ads"

### Common Pattern 6 - This month vs last month spend

Two queries, compute deltas client-side:

```bash
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=BASIC&data_level=AUCTION_ADVERTISER&dimensions=[\"advertiser_id\"]&metrics=[\"spend\",\"clicks\",\"conversions\"]&start_date=$(date +%Y-%m-01)&end_date=$(date +%Y-%m-%d)"
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=BASIC&data_level=AUCTION_ADVERTISER&dimensions=[\"advertiser_id\"]&metrics=[\"spend\",\"clicks\",\"conversions\"]&start_date=$(python3 -c 'from datetime import date, timedelta; print((date.today().replace(day=1) - timedelta(days=1)).replace(day=1))')&end_date=$(python3 -c 'from datetime import date, timedelta; print(date.today().replace(day=1) - timedelta(days=1))')"
```

**Use when:** "compare to last month", "TikTok month over month"

### Common Pattern 7 - Audience performance

```bash
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=AUDIENCE&data_level=AUCTION_ADGROUP&dimensions=[\"adgroup_id\",\"age\",\"gender\"]&metrics=[\"spend\",\"clicks\",\"conversions\"]&start_date=$(python3 -c 'from datetime import date, timedelta; print(date.today() - timedelta(days=30))')&end_date=$(date +%Y-%m-%d)" | jq '.data.list'
```

Breaks down spend + conversions by age + gender. Useful for "who's converting?"

**Use when:** "TikTok audience report", "who's converting on TikTok?"

### Common Pattern 8 - Reach + engagement (creator-economy metric)

```bash
tk_get "/report/integrated/get/" "advertiser_id=$ADV&report_type=BASIC&data_level=AUCTION_AD&dimensions=[\"ad_id\"]&metrics=[\"ad_name\",\"reach\",\"impressions\",\"video_play_actions\",\"video_watched_2s\",\"video_watched_6s\",\"engaged_view\"]&start_date=$(python3 -c 'from datetime import date, timedelta; print(date.today() - timedelta(days=30))')&end_date=$(date +%Y-%m-%d)" | jq '.data.list'
```

TikTok-specific metrics: video watch time at 2s / 6s, engaged views. Critical for ad creative iteration.

**Use when:** "TikTok video performance", "which ads hold attention?"

### Common Pattern 9 - Pause or resume a campaign (write, gated)

`MODE=production`: run Gate 2 first.

```bash
CAMPAIGN_ID="<the id>"
NEW_STATUS="DISABLE"   # or "ENABLE" to resume

tk_post "/campaign/status/update/" "$(jq -n --arg ai "$ADV" --arg cid "$CAMPAIGN_ID" --arg op "$NEW_STATUS" \
  '{advertiser_id:$ai, campaign_ids:[$cid], operation_status:$op}')"
```

Response has `code: 0` for success.

**Use when:** "pause [campaign]", "stop my TikTok ads"

### Common Pattern 10 - Adjust daily budget (write, gated)

`MODE=production`: run Gate 2 first.

```bash
CAMPAIGN_ID="<the id>"
NEW_BUDGET="<USD per day, e.g. 50>"

tk_post "/campaign/update/" "$(jq -n --arg ai "$ADV" --arg cid "$CAMPAIGN_ID" --argjson b "$NEW_BUDGET" \
  '{advertiser_id:$ai, campaign_id:$cid, budget:$b, budget_mode:"BUDGET_MODE_DAY"}')"
```

> TikTok's budgets are in the advertiser account's currency; no micros division like Google Ads.

**Use when:** "increase TikTok budget for [campaign]", "lower spend on [campaign]"

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "TikTok spend this month" | Pattern 1 |
| "Best TikTok campaigns" / "Top performers" | Pattern 2 |
| "List TikTok campaigns" | Pattern 3 |
| "Ad groups in [campaign]" | Pattern 4 |
| "Show me the ads" | Pattern 5 |
| "TikTok month over month" | Pattern 6 |
| "Audience report" / "Who's converting?" | Pattern 7 |
| "Video performance" / "Which ads hold attention?" | Pattern 8 |
| "Pause [campaign]" | Pattern 9 (gated) |
| "Change budget" | Pattern 10 (gated) |
| "Connect TikTok Ads" | **Run Phase 0** |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 200 with `code: 40100` | Access token invalid / expired | Re-run Phase 1 (TikTok long-lived tokens occasionally rotate) |
| HTTP 200 with `code: 40105` | Permission denied - token doesn't have scope for this operation | Tell participant: "I need extra access for that - let me reconnect with the right permissions." Re-run Phase 1 with broader scope. |
| HTTP 200 with `code: 40002` | Invalid advertiser_id | Re-fetch advertiser list from `/oauth2/advertiser/get/` |
| HTTP 200 with `code: 41003` | Audience / restricted scope requires TikTok app review | Translate: "This part needs TikTok's approval first - usually 1-2 weeks. Want me to apply, or stick with the parts that work today?" |
| HTTP 200 with `code: 50000` | TikTok internal server error | Retry once after 5s delay. |
| HTTP 429 | Rate cap | Wait 30s, retry once. |

**Note**: TikTok API returns HTTP 200 with a `code` field in the JSON body for ALL responses - both success (`code: 0`) and error. Always check `code` before treating a 200 as success.

**Token lifetime**: TikTok issues long-lived access tokens (~30 days). A refresh-token cycle is documented in the Marketing API, but is rare for self-serve advertisers - the practical resume path on `code: 40100` is to re-run Phase 1 rather than to attempt a refresh.

Translate every error to plain English. Never show raw HTTP bodies.

---

## Scope Limitations

This connector **can**:

- Read all standard reporting endpoints: advertiser info, campaigns, ad groups, ads, reports (BASIC, AUDIENCE, video metrics).
- Pause / resume campaigns.
- Change campaign daily budgets.

It **cannot**:

- **Create campaigns / ad groups / ads from scratch** - ad creation requires creative assets (videos), audience definitions, tracking pixels, bid strategies. Out of v1; participant creates in TikTok Ads Manager.
- **Upload creative assets** - multipart video upload to `/file/video/ad/upload/` is a separate workflow.
- **Pixel / Event API write** - conversion event posting requires Pixel API access; out of v1.
- **Audience management (custom audiences, lookalikes)** - requires TikTok app review for those scopes; out of v1.
- **TikTok Creator Marketplace integration** - separate API surface.

It **requires** the participant to be an advertiser admin on at least one TikTok For Business account.

---

## Behaviour Guidelines (Phase 2)

- **Mode awareness** - `MODE=sandbox` is freely callable; `MODE=production` applies Gate 1 (once per session) and Gate 2 (every write).
- **TikTok response shape** - every TikTok API response has `code`, `message`, `data` at top level. Success = `code: 0`. Check `code` before treating a response as success.
- **Currency** - TikTok returns spend / budget values in the advertiser's account currency (no micros). Format as `$X.XX <currency>`.
- **Dates** - TikTok uses `YYYY-MM-DD` for report date ranges. The examples use Python calendar arithmetic on macOS and Linux; previous-month boundaries also handle January and leap years.
- **Pagination** - most list endpoints support `page` + `page_size`. Reports cap at `page_size=1000`. Multi-page operations should cap at 5 pages unless participant asks for more.
- **Filtering** - TikTok filters are JSON-stringified objects, URL-encoded: `filtering={"campaign_ids":["123"]}`.
- **Auth errors** → re-run Phase 1.
- **Never log or echo credentials** - app_id, secret, access_token.
- **Writes are real** - Production-mode writes affect ad delivery within minutes. Gate firmly.

---

## Related Skills

- **`google-ads-connector`**: Sibling Tier-1 ads connector. Same Phase 0 sandbox/production split. Pair when participant runs both Google Ads + TikTok Ads (very common for e-commerce SMBs in 2026).
- **`paid-ads`**: Strategy advisor. Pair when participant wants advice on what to DO with the data (e.g., "should I pause this campaign?"). Advisor asks the strategy question; this connector answers it factually.
- **`myob-connector`**: Reference Direct-REST + Playwright pattern.
- **`mailchimp-connector`** / **`klaviyo-connector`**: Email-marketing connectors for the same e-commerce SMB stack - combine with TikTok Ads for full top-of-funnel + bottom-of-funnel visibility.
- **`superpowers:systematic-debugging`**: For TikTok-specific token-scope or response-code edge cases.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - three-pattern decision tree.
- [TikTok Marketing API v1.3 reference](https://business-api.tiktok.com/portal/docs) - official endpoint catalogue. Note: TikTok's docs are JavaScript-rendered SPAs; reading them requires a real browser, not WebFetch-style tools.
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` - say "test mode" / "real TikTok Ads" to participants, not "sandbox" / "production".
