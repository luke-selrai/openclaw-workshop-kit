---
name: google-ads-connector
description: "Connect Google Ads to Claude by installing and authenticating its API credentials, optionally with Google's official MCP server. Use when the user asks to set up or connect Google Ads, or wants Google Ads work (campaigns, ad groups, keywords, ad spend, conversions, ROAS) and the credentials aren't in place yet. Once connected, Google Ads runs directly against its API with the stored credentials, through the mcp__google_ads__* tools when they are installed."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__google_ads__*
metadata:
  category: Marketing & Advertising
  tags:
    - google-ads
    - adwords
    - ppc
    - paid-media
    - campaigns
    - keywords
    - reports
    - rest-api
    - oauth
  pairs-with:
    - skill: paid-ads
      reason: paid-ads is the strategy advisor (how to plan/optimise campaigns); google-ads-connector is the data source for those decisions. Pair when the user wants both advice and live data.
    - skill: quickbooks-connector
      reason: Same Phase 0 mode-detection + Phase 1 Playwright-driven autonomous install pattern as the Tier-1 reference. QBO's Phase 1L is a heavier variant of this skill's Phase 1L.
    - skill: myob-connector
      reason: Reference SKILL for the Direct-REST + Playwright pattern (no MCP, no first-party CLI, OAuth + bearer-on-curl)
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting OAuth flow failures or Google Ads API errors
---

# Google Ads Connector

## Overview

This skill lets you read and operate a user's Google Ads account on their behalf. Read operations route through **Google's official `google-ads-mcp` MCP server** (`github.com/googleads/google-ads-mcp`, Apache-2.0); write operations stay on **direct REST** because the official MCP is read-only.

`skills/CLAUDE.md` documents the three install patterns (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace) and explicitly marks direct-REST connectors (`ghl-connector`, `myob-connector`) as out of scope for that doc. This SKILL is a hybrid that doesn't fit any of the three cleanly: it wraps an official vendor MCP for reads (similar to how `quickbooks-connector` wraps Intuit's MCP) AND keeps direct REST for the writes the vendor MCP doesn't cover. `myob-connector`'s loopback listener + atomic credentials.json pattern is reused for the OAuth capture; the wrap-the-vendor-MCP step (Phase 1F) is closer to QBO's shape.

It has three phases:

- **Phase 1 - Install & Connect (autonomous via Playwright + REST).** Claude drives Google Cloud Console end-to-end via Playwright MCP to create an OAuth client, drives `ads.google.com/aw/apicenter` to request a developer token (Test Account or Explorer access as actually issued; Basic Access requires Google review), drives the OAuth consent flow to capture access + refresh tokens, lists the participant's accessible customer IDs, and persists everything to `~/.config/google-ads/credentials.json` (mode 0600). The participant's manual moments are signing in to Google once and approving consent.
- **Phase 1F - Wrap the official MCP for reads.** After Phase 1's credential capture, Phase 1F writes an Application Default Credentials JSON at `~/.config/google-ads/adc-credentials.json` from the same refresh token Phase 1 just minted, ensures `pipx` is installed, and registers the official `google-ads-mcp` server via `claude mcp add google_ads --scope user --env GOOGLE_APPLICATION_CREDENTIALS=... --env GOOGLE_PROJECT_ID=... --env GOOGLE_ADS_DEVELOPER_TOKEN=... -- pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp`. The MCP exposes three tools: `mcp__google_ads__search`, `mcp__google_ads__list_accessible_customers`, `mcp__google_ads__get_resource_metadata`. Phase 1F can be skipped if `pipx` install fails or Python is unavailable; Phase 2 reads then fall back to the bundled REST helper.
- **Phase 2 - Use Tools.** Once Phase 1F completes and Claude Code has been restarted, **prefer `mcp__google_ads__*` tools for reads** (Patterns 1-8); the structured `search(customer_id, fields, resource, conditions, orderings, limit)` call replaces the curl + GAQL string approach. If the MCP is not registered (Phase 1F was skipped or failed), reads fall back to the documented REST helper examples. Writes (Patterns 9-10 - pause/resume campaign, adjust budget) ALWAYS run direct REST because the official MCP is read-only. Production gates apply whenever the verified target is a real account, regardless of saved mode or developer-token access level.

**Two modes, picked at Phase 0:**

| Mode | When | What it touches | Wait |
|---|---|---|---|
| **Test** | Default for first-time install. Recommended for "I want to try it today." | Only a verified test client in a separately created test-manager hierarchy. No real money. | After manager/API registration, test hierarchy creation, and authentication succeed. |
| **Production target** | When the participant wants their real ads data. | Real Google Ads clients they can access. | Explorer, Basic, or Standard access may already permit the requested reads. Apply for Basic only when needed; Google currently lists five business days as typical, not guaranteed. |

**Target type and developer-token access level are separate.** Google may issue Explorer access automatically, allowing production reads without a Basic application. Record the observed access level; never infer test safety from the token, an approval state, or `mode=test`. Verify `customer.test_account` on the selected client before reporting or mutating data. Keep the legacy `mode=basic` value for a production target even when its token has Explorer or Standard access; also save explicit `target_mode` and `developer_token_access_level`. [Current access levels](https://developers.google.com/google-ads/api/docs/api-policy/access-levels).

The shared request helper uses the supported `v25` API. Version 17 was retired on June 4, 2025; do not retry its failures as authentication problems. All REST recipes below use [scripts/ads_request.py](scripts/ads_request.py), which centralizes the version, required headers, and target guard. Resolve its absolute location from this loaded skill as `ADS_REQUEST_HELPER` in each shell invocation. [Version lifecycle](https://developers.google.com/google-ads/api/docs/sunset-dates).

**Which phase to run** - Before any tool call, check whether the credentials file exists:

```bash
test -f "$HOME/.config/google-ads/credentials.json" && jq -r '.mode // "missing"' "$HOME/.config/google-ads/credentials.json" 2>/dev/null || echo missing
```

- Output `test` or `basic` → credentials exist. Run Phase 0's target inspection before Phase 2; the saved mode alone does not prove a connection.
- Output `pending-basic` → Basic Access application was submitted; check its status without changing the selected target. Test use still requires a verified test client.
- Output `missing` → run Phase 0 + Phase 1.

---

## Golden rule - do not open the participant's own browser

Every Phase 1 step that requires sign-in (Google Cloud, Google Ads, OAuth consent) runs inside the Playwright MCP browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the participant to "open a link in your browser." Claude navigates, the participant types passwords directly into the Playwright window, Claude reads the result programmatically. Same rule as the `myob-connector` and `quickbooks-connector` skills.

If Playwright MCP is unavailable, stop and tell the participant: *"I need a small browser tool that's not installed yet - let me show you how to add it."* Then point them at the install instructions for the Playwright MCP and stop. Do not fall back to opening the participant's default browser.

---

## Communication rules for Phase 1

The participant is a non-technical business owner. Every message during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions.
- **Plain English only.** Never say OAuth, token, dev token, scope, refresh, Bearer, API, endpoint, JSON, GAQL, customer ID, manager account, env var, curl, terminal, CLI, MCP, redirect URI, callback, loopback, sandbox, file path, or `developer-token`. If you must refer to a technical thing, name it plainly: "your connection details", "your Google Ads account number", "the workshop's setup step", "Google's review".
- **Tell them what is about to happen.** *"I'm opening Google Cloud now to set up the connection - sign in when you see the page. About a minute."*
- **React warmly.** Good: *"Got it - connection ready for **[Account Name]**."* Bad: *"OAuth token exchange returned 200, credentials.json written mode 0600."*
- **Never show error messages directly.** Translate. *"No problem - let me try a different way,"* then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the participant. You run them.
- **Never echo CLIENT_ID, CLIENT_SECRET, the dev token, or refresh tokens** back to the participant - all are stored locally and never shown.

---

## ⛔ Pre-flight check - Playwright availability

Before any Phase 0 step, verify Playwright MCP tools are available:

```bash
# Quick test: do any mcp__playwright__* or mcp__plugin_playwright_playwright__* tools exist in this session?
# If not, halt and tell the participant to install Playwright MCP per skills/CLAUDE.md.
```

If unavailable, stop. Do not start Phase 0 or Phase 1.

---

## PHASE 0 - Mode + state detection

Phase 0 picks the mode (test vs basic vs resume-pending) and decides whether Phase 1 runs at all. It runs before any Phase 2 tool call.

### Step 0.1 - Read existing credentials

```bash
CREDS="$HOME/.config/google-ads/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.mode // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

Four states:

- **`missing`** - first-time install. Continue to Step 0.2.
- **`test`** - Refresh an expired access token if needed, then run the helper’s `inspect`. Continue only when it verifies the selected client and returns `test_account: true`; listing accessible customers alone is insufficient. If 401, refresh token (Step 2.0) then retry; if still failing, fall through to Phase 1 re-auth.
- **`basic`** - Production target requested, regardless of the token’s access level. Run `inspect`, then apply the production gates whenever the actual target is not a test account.
- **`pending-basic`** - Basic Access application submitted, not yet approved. Continue to Step 0.3.

### Step 0.2 - Ask Test or Basic Access (first-time install)

Ask the participant in one warm message:

> "Quick question: want me to set up **test mode** (no real money; performance data stays empty), or do you want **real data** for your actual Google Ads account? I’ll check whether your existing access already permits real data. If Google needs to review an application, that can take about a business week or longer."

Map the reply:

- "test", "try", "today", "quick", or no specific answer → `MODE=test` → continue to **Phase 1**, with the **Phase 1T** sub-flow after Phase 1's shared steps.
- "real", "live", "basic", "production", "actual" → `MODE=basic` → continue to **Phase 1**, with the **Phase 1L** sub-flow after Phase 1's shared steps. Check existing access first. Apply for Basic only if needed; offer a separate test account while review is pending, and call it ready only after verification.
- Ambiguous → ask once for clarification, default `MODE=test`.

Do NOT use the word "sandbox" - use "test mode" (workshop UX rule from `feedback_workshop_kit_update_format`).

### Step 0.3 - Check Basic Access application status (when state = pending-basic)

```bash
APPLIED_AT=$(jq -r '.basic_application.applied_at' "$CREDS")
HOURS_AGO=$(python3 -c "import datetime,sys;a=datetime.datetime.fromisoformat(sys.argv[1].rstrip('Z'));print(int((datetime.datetime.utcnow()-a).total_seconds()/3600))" "$APPLIED_AT")
echo "Applied $HOURS_AGO hours ago"
```

If less than 24 hours, avoid submitting again. Explain the pending review and continue only with an already verified test target, or finish the separate test-account setup in Step 6 first. Do not turn a production client into a test target by changing `mode`.

If 24+ hours, check the API Center in the non-test manager that owns the developer token (Step 1L.5). Approval upgrades the same token; it does not select a new account. Preserve the target and apply the target-based Phase 2 gates.

---

## PHASE 1 - Install & Connect (autonomous via Playwright + REST)

Phase 1 has THREE parts:

- **Part A (shared)** - Steps 1-5 prepare the OAuth client. Step 6 establishes the intended manager/client hierarchy and runs Step 1T.1-1T.2 to capture the developer token. Only then run Steps 7-9 for the correct target-access Google identity and Step 10 for customer discovery. Both OAuth and the developer token are required before discovery.
- **Part B (Phase 1T)** - Shared developer-token capture runs during Step 6, before discovery. Step 1T.3 saves the selected target and Step 1T.4 verifies it. Test mode becomes ready only after a real test-client read succeeds.
- **Part C (Phase 1L)** - Apply for Basic only if the observed token access level cannot serve the requested production work. Test fallback requires its own verified test client and matching OAuth principal; an application or token alone does not create one.

### Step 1 - Welcome message

Send one short message:

> "Great - connecting your Google Ads. Three quick things:
> 1. Sign in to Google when I open the page.
> 2. Approve the connection when it asks.
> 3. If you don't have a Google Ads account yet, I'll help you make one.
> About 4 minutes total."

### Step 2 - Sign in to Google Cloud Console

```
mcp__playwright__browser_navigate({ url: "https://console.cloud.google.com/welcome" })
```

**Do NOT snapshot the sign-in page** (password-leak risk - see `reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "Welcome", time: 30 })
```

(or wait for the project picker `Select a project` text). If timeout: ask the participant *"Still on the sign-in page? Anything I can help with?"* and re-poll.

### Step 3 - Create or pick a Google Cloud project

Navigate to:

```
mcp__playwright__browser_navigate({ url: "https://console.cloud.google.com/projectselector2/home/dashboard" })
```

Two states:

- **At least one project exists** → pick the first one the participant has owner/editor on. If they have multiple and aren't sure, ask: *"Which Google Cloud project should I use? (You can pick any of yours - it just stores the connection details.)"*
- **Zero projects** → drive `New Project` button: name = `claude-google-ads`, organization = participant's default, location = no organization or their org. Click Create. Wait for the post-create dashboard.

Capture the `PROJECT_ID` from the URL or the project header.

### Step 4 - Enable the Google Ads API

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/library/googleads.googleapis.com?project=${PROJECT_ID}"
})
```

Click the **Enable** button via `browser_evaluate`:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^enable$/i.test((b.innerText||'').trim()));
  if (!btn || btn.disabled) return { ok: false, reason: btn ? 'disabled' : 'no-button' };
  btn.click();
  return { ok: true };
}
```

If the button reads `Manage` (not `Enable`), the API is already enabled - skip.

Wait for the post-enable redirect (`browser_wait_for({ text: "API enabled" })` or check for the Manage button to appear).

### Step 5 - Create the OAuth client

Navigate to:

```
mcp__playwright__browser_navigate({
  url: "https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}"
})
```

**5a - OAuth consent screen prereq.** If the page shows a banner like "Configure consent screen" before the create-credentials button works, click into Consent Screen, pick `External` (or `Internal` if Workspace org), fill: app name = `Claude Google Ads Connector`, support email = participant's signed-in email, developer contact = same. Save and continue through all four wizard steps with defaults; on the test-users step, add the participant's own email to allow them to sign in. Return to the Credentials page.

**5b - Create OAuth Client ID.**

Click `+ CREATE CREDENTIALS` → `OAuth client ID`. Application type = `Desktop app`. Name = `Claude Google Ads Connector`. Complete the capture preflight below before clicking Create, because the next modal displays the secret.

Before opening the modal showing **Your Client ID** and **Your Client Secret**, prepare capture in the isolated browser. Keep the system clipboard untouched. Prepare a private transfer directory (macOS and Linux):

```bash
umask 077
ADS_CAPTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ads-capture.XXXXXX")"
ADS_CAPTURE_NAME="$(python3 -c 'import secrets; print("ads-capture-" + secrets.token_hex(12))')"
ADS_CAPTURE_METHOD=evaluate
printf '%s\n' "$ADS_CAPTURE_DIR" "$ADS_CAPTURE_NAME"
```

**Choose and probe the capture route before displaying credentials.** When `browser_evaluate` supports `filename`, prefer `ADS_CAPTURE_METHOD=evaluate`. On a disposable blank tab, locate the actual MCP output directory from an emitted snapshot/artifact path or the server's configured output path; resolve it from Bash and retain its absolute path as `ADS_OUTPUT_DIR`. Do not assume the shell's working directory is the MCP root. Protect that known directory:

```bash
test -d "$ADS_OUTPUT_DIR" && test -O "$ADS_OUTPUT_DIR" || exit 1
chmod 700 "$ADS_OUTPUT_DIR"
```

For the evaluate route, pre-create `$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-probe.json` with `umask 077` and shell noclobber, then call `browser_evaluate` with `function: () => ({probe: true})` and `filename` set to that **absolute path**. Verify the returned artifact link resolves to that exact regular file, its mode remains 0600 and only the artifact link appears in the tool result. This tests the tool's allowed roots without a credential. Absolute paths outside allowed roots are rejected. Remove only that tracked public probe file after checking it; preserve other artifacts and server settings.

The random capture name uses lowercase letters, digits and hyphens, avoiding the MCP's normalization of interior dots. If the private directory, allowed destination or result withholding cannot be verified, stop before handling a real credential.

**Snapshot privacy:** navigation and evaluation may create snapshots containing visible credentials. Protect the actual MCP output directory before opening the secret-bearing UI; keep snapshots private and track the exact files emitted by this task. Inspect only structural results. Clean up only snapshots positively attributed to this capture, preserving unrelated files. A file-output result does not imply that snapshots contain no secrets.

**Blob fallback:** use `ADS_CAPTURE_METHOD=blob` only when this runtime already has a successful synthetic download/saveAs test. The affected Chrome 152.0.7977.82 runtime crashed twice during blob downloads; that route remains unproven there, and further blob retries are not the recovery path. The evaluate route does not use downloads or Node filesystem globals.

After the public probe passes, click Create and pre-create the two capture destinations without replacing an existing file:

```bash
umask 077
(set -C; : > "$ADS_CAPTURE_DIR/client.json") || exit 1
(set -C; : > "$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-client.json") || exit 1
```

**Evaluate route:** call `browser_evaluate` with the DOM extraction function passed to the **first** `page.evaluate` in the example below, returning the credential object directly (not `JSON.stringify(out)`). Set `filename` to the absolute `$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-client.json` path. Omit the download portion entirely. The tool must return only an artifact link; resolve that observed path as `ADS_CLIENT_OUTPUT`, then run the shared verification block below with the same `ADS_CAPTURE_METHOD` value. An unset method is rejected without changing files. Keep credentials out of tool arguments, printed output and chat.

**Blob route only:** run the complete example below, substituting the printed directory path in `saveAs` and the unique capture name in `link.download`.

```js
async (page) => {
  const out = await page.evaluate(() => {
    // Find the modal panel with Client ID + Client Secret
    const labels = Array.from(document.querySelectorAll('*'))
      .filter(el => el.children.length === 0 && /^(your )?client (id|secret)\s*:?$/i.test((el.innerText||'').trim()));
    const out = {};
    for (const label of labels) {
      const which = /id/i.test(label.innerText) ? 'client_id' : 'client_secret';
      if (out[which]) continue;
      let scope = label.parentElement;
      for (let depth = 0; depth < 6 && scope; depth++) {
        const codes = Array.from(scope.querySelectorAll('code, input[type=text], input:not([type])'));
        const v = codes.map(c => (c.value || c.innerText || '').trim()).find(v => v.length > 20);
        if (v) { out[which] = v; break; }
        scope = scope.parentElement;
      }
    }
    if (!out.client_id || !out.client_secret) return null;
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
  return { ok: true, client_id_len: out.client_id.length, client_secret_len: out.client_secret.length };
}
```

For evaluate, read this capture's **Evaluation result** link; for blob, read its **Downloaded file … to …** event. Retain the resolved absolute path as `ADS_CLIENT_OUTPUT`. Verify it belongs to the protected output directory and matches the expected unique name. If the tool changes the name or directory, the guard below rejects it and preserves every file; resolve the mismatch before continuing. Never infer the cleanup path solely from `link.download`.

```bash
python3 - "$ADS_CAPTURE_DIR/client.json" "$ADS_OUTPUT_DIR" "$ADS_CAPTURE_NAME" "$ADS_CLIENT_OUTPUT" "${ADS_CAPTURE_METHOD:-}" <<'PY'
import json
import os
from pathlib import Path
import re
import stat
import sys

private_file, output_dir, capture_name, reported_file, capture_method = sys.argv[1:]
private_file = Path(private_file)
output_dir = Path(output_dir).resolve(strict=True)
reported_file = Path(reported_file)
if capture_method not in ('evaluate', 'blob'):
    raise SystemExit('Unknown capture method; files preserved')
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
if capture_method == 'evaluate':
    if private_file.stat().st_size or reported_file.stat().st_mode & 0o077:
        raise SystemExit('Capture destination changed; files preserved')
    try:
        payload = json.loads(reported_file.read_text())
    except (ValueError, UnicodeError):
        raise SystemExit('Invalid captured data; files preserved')
    valid = isinstance(payload, dict)
    if valid:
        valid = all(isinstance(payload.get(key), str) and len(payload[key]) > 20 for key in ('client_id', 'client_secret'))
    if valid:
        valid = payload['client_id'] != payload['client_secret']
    if not valid:
        raise SystemExit('Missing or invalid credential fields; files preserved')
    private_file.write_text(json.dumps(payload))
private_file.chmod(0o600)
reported_file.chmod(0o600)
reported_file.unlink()
PY
```

Client ID is typically ~70 chars (`<numeric>-<random>.apps.googleusercontent.com`); secret is ~35 chars. Validate shapes silently.

### Step 6 - Establish the manager, token, and intended client

A normal advertiser account is not a test account. Start with the user's existing **non-test Google Ads manager account**, or create one through [Google’s manager-account instructions](https://developers.google.com/google-ads/api/docs/api-policy/developer-token) when authorized. API Center is available only to non-test managers; a Google Cloud project does not automatically receive a developer token. Complete the actual API Access form and terms with accurate business details and a working website. Run **Step 1T.1-1T.2 now** to capture the issued token using the protected capture route. Record its displayed access level as `DEV_ACCESS_LEVEL` (`test`, `explorer`, `basic`, or `standard`).

- **Test target:** follow [Google’s test-account guide](https://developers.google.com/google-ads/api/docs/best-practices/test-accounts). Use its **Create a test manager account** link, with the Google identity required by that flow (the guide specifies one not linked to the production manager). In that test manager, choose **Accounts → + → Create new account** to create a test client. Record the test manager and client IDs without hyphens. The production manager's developer token is used for calls to this separate test hierarchy. Test and production accounts cannot be linked together. Do not enter billing or launch a real campaign to satisfy this branch; test accounts have no billing and do not serve ads. Empty campaigns and metrics are expected.
- **Production target:** use the existing intended advertiser client. Explorer, Basic, or Standard access may permit the reads immediately. If access is Test Account only, use Phase 1L's application branch; do not claim production access while it is pending.

For Steps 7-9, authorize the Google identity that actually has access to the selected test or production client. It may differ from the Cloud-project owner or developer-token manager login. Save `MANAGER_CUSTOMER_ID` when access is through a manager, and use that ID as `login-customer-id` on client requests. Do not silently select a manager as the operating client.

New refresh-token authorization may require a passkey; existing refresh tokens are unaffected. Complete the normal challenge and preserve any security waiting period. Do not regenerate working credentials to avoid it. [Google’s current security requirements](https://developers.google.com/google-ads/api/docs/oauth/security-requirements).

### Step 7 - Start the loopback listener for the OAuth callback

Start a tiny Python listener on `localhost:8765` to catch the redirect with the authorization code:

```bash
umask 077
rm -f /tmp/google-ads-listener.port /tmp/google-ads-auth-code

nohup python3 -c "
import errno, http.server, urllib.parse, sys
class H(http.server.BaseHTTPRequestHandler):
  def log_message(self, *a, **k): pass
  def do_GET(self):
    params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
    code = params.get('code', [''])[0]
    self.send_response(200)
    self.send_header('Content-Type', 'text/html')
    self.end_headers()
    self.wfile.write(b'<h1>Google Ads connected. You can close this tab.</h1>')
    with open('/tmp/google-ads-auth-code', 'w') as f:
      f.write(code)
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
with open('/tmp/google-ads-listener.port', 'w') as port_file:
  port_file.write(str(server.server_port))
server.serve_forever()
" > /tmp/google-ads-listener.log 2>&1 &
echo $! > /tmp/google-ads-listener.pid
for i in $(seq 1 50); do
  [ -s /tmp/google-ads-listener.port ] && break
  kill -0 "$(cat /tmp/google-ads-listener.pid)" 2>/dev/null || break
  sleep 0.1
done
[ -s /tmp/google-ads-listener.port ] || { echo 'Connection listener could not start'; exit 1; }
PORT="$(cat /tmp/google-ads-listener.port)"
```

If port 8765 is in use, the loop steps up. The chosen port is stored in `/tmp/google-ads-listener.port` for Step 8. Binding the listener itself reserves the port; no platform-specific port-listing command is needed.

> **OAuth client redirect URI**: Google's Desktop App OAuth flow accepts loopback redirect URIs `http://127.0.0.1:<port>` without pre-registering each port (per RFC 8252 Section 7.3 - Google supports this). Some Desktop clients may default to `http://localhost`. If the OAuth request fails with `redirect_uri_mismatch`, fall back to using `http://localhost:$PORT` (instead of `127.0.0.1`) and edit the OAuth client's authorized redirect URI list to include it.

### Step 8 - Drive the OAuth consent flow

Read the captured file for the OAuth URL construction (still never echoing values):

```bash
CLIENT_ID="$(jq -r '.client_id' "$ADS_CAPTURE_DIR/client.json")"
PORT="$(cat /tmp/google-ads-listener.port)"
SCOPE="https://www.googleapis.com/auth/adwords"
AUTH_URL="https://accounts.google.com/o/oauth2/v2/auth?client_id=${CLIENT_ID}&redirect_uri=http%3A%2F%2F127.0.0.1%3A${PORT}&response_type=code&scope=${SCOPE}&access_type=offline&prompt=consent"
```

Navigate Playwright to `$AUTH_URL`. Three possible page states:

- **Already-signed-in consent screen** → click **Allow** via `browser_evaluate`:

  ```js
  () => {
    const btn = Array.from(document.querySelectorAll('button, span[role=button]'))
      .find(b => /^(continue|allow)$/i.test((b.innerText||'').trim()));
    if (btn) { btn.scrollIntoView({block:'center'}); btn.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

- **"Account chooser"** (when participant has multiple Google accounts) → wait for participant to click their workshop account; then re-detect consent screen and click Allow.
- **"This app isn't verified" warning** (the OAuth consent screen is in Testing mode without verification) → click **Advanced** then **Go to claude-google-ads (unsafe)**. Reassure the participant in plain English: *"Google's warning is because the connection is only used by you - not a public app. Safe to continue."* Then click Allow.

Poll `/tmp/google-ads-auth-code` every 2 seconds for up to 3 minutes:

```bash
for i in $(seq 1 90); do
  [ -s /tmp/google-ads-auth-code ] && break
  sleep 2
done
AUTH_CODE="$(cat /tmp/google-ads-auth-code)"
```

### Step 9 - Exchange the code for access + refresh tokens

```bash
CLIENT_ID="$(jq -r '.client_id' "$ADS_CAPTURE_DIR/client.json")"
CLIENT_SECRET="$(jq -r '.client_secret' "$ADS_CAPTURE_DIR/client.json")"

RESP="$(curl -sf https://oauth2.googleapis.com/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://127.0.0.1:$PORT" \
  -d "grant_type=authorization_code")"

# Tear down listener
kill "$(cat /tmp/google-ads-listener.pid)" 2>/dev/null
rm -f /tmp/google-ads-auth-code /tmp/google-ads-listener.pid /tmp/google-ads-listener.port /tmp/google-ads-listener.log
```

The response is JSON with `access_token`, `refresh_token`, `expires_in`, `scope`, `token_type`. Retain `RESP` privately in the same shell session through Step 10 and Step 1T.3; do not print it or assume shell variables survive a new tool invocation. The selected client and manager IDs should already be established in Step 6.

**Failure cases:**

- HTTP 400 `invalid_grant` → code expired (>10 min). Restart from Step 7.
- HTTP 400 `redirect_uri_mismatch` → the redirect URI Google requires doesn't match. Try `http://localhost:$PORT` and re-edit the OAuth client (Step 5b) to add it as an authorized redirect URI.
- Network error → retry once with 5s delay. If still failing, plain-English the participant.

### Step 10 - Discover accessible customers after both credentials exist

Run this only after Steps 1T.1-1T.2 and 7-9 succeeded. The developer token is required even for `listAccessibleCustomers`. Create a private request draft from the captured values; never print it:

```bash
umask 077
ACCESS_TOKEN="$(echo "$RESP" | jq -r .access_token)"
DEV_TOKEN="$(jq -r '.dev_token // empty' "$ADS_CAPTURE_DIR/developer.json")"
jq -n --arg at "$ACCESS_TOKEN" --arg dt "$DEV_TOKEN" \
  '{access_token:$at, developer_token:$dt}' > "$ADS_CAPTURE_DIR/request.json"
python3 "$ADS_REQUEST_HELPER" --credentials "$ADS_CAPTURE_DIR/request.json" list-customers
```

The helper refuses missing OAuth or developer credentials before sending anything. This endpoint lists only accounts the OAuth principal can access directly, and ignores `login-customer-id`. A returned manager does not imply its children are listed. Use the client ID already established in Step 6; if discovery is needed, run `list-clients --manager-id <observed-manager-id>` against the same request draft to inspect that manager’s `customer_client` hierarchy. Choose the intended non-manager client, preserving the matching manager ID for subsequent requests. [Discovery semantics](https://developers.google.com/google-ads/api/docs/account-management/listing-accounts), [required headers](https://developers.google.com/google-ads/api/rest/auth).

Save the chosen client ID as `CUSTOMER_ID`, the manager route as `MANAGER_CUSTOMER_ID` (empty for direct client access), and continue to Step 1T.3. An empty list or permission error requires checking the OAuth identity and hierarchy; do not create another advertiser account or add billing as recovery.

---

### Step 1T - Developer-token capture and selected-target persistence

A developer token comes from the non-test manager’s API Center after API registration. Its access tier may be Test Account, Explorer, Basic, or Standard. It is not issued merely by creating a Google Cloud account. Upgrading access normally upgrades the same token; do not assume a separate test token or automatically rotate it on approval.

**1T.1 - Navigate to API Center (called during Step 6)**

Open `https://ads.google.com/aw/apicenter` in the intended non-test manager account. If API Center is unavailable, verify the selected account type. Complete the actual registration if needed, then observe its issued token and access level. Preserve the protected capture preflight already prepared in Step 5b.

**1T.2 - DOM-extract the dev token**

Use the same protected output directory and unique capture name as Step 5b; save the developer details separately so they cannot overwrite the OAuth client details. Pre-create both destinations before capture:

```bash
umask 077
(set -C; : > "$ADS_CAPTURE_DIR/developer.json") || exit 1
(set -C; : > "$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-developer.json") || exit 1
```

For evaluate, use the extraction function passed to the first `page.evaluate` below with `filename` set to the absolute `$ADS_OUTPUT_DIR/$ADS_CAPTURE_NAME-developer.json` path, returning the credential object directly and skipping the download. Resolve the observed artifact link as `ADS_DEVELOPER_OUTPUT`. For blob, use the complete example and its reported download path. Apply the same parent-directory and filename checks as Step 5b.

```js
async (page) => {
  const out = await page.evaluate(() => {
    const labels = Array.from(document.querySelectorAll('*'))
      .filter(el => el.children.length === 0 && /^developer token$/i.test((el.innerText||'').trim()));
    for (const label of labels) {
      let scope = label.parentElement;
      for (let depth = 0; depth < 6 && scope; depth++) {
        const lines = (scope.innerText || '').split('\n').map(s => s.trim()).filter(Boolean);
        // Token shape: 22 alphanumeric chars
        const tokenLine = lines.find(l => /^[A-Za-z0-9_-]{20,28}$/.test(l) && l !== label.innerText.trim());
        if (tokenLine) return { dev_token: tokenLine };
        scope = scope.parentElement;
      }
    }
    return null;
  });
  if (!out) return { ok: false };
  const download_promise = page.waitForEvent('download');
  await page.evaluate((values) => {
    const link = document.createElement('a');
    const blob_url = URL.createObjectURL(new Blob([JSON.stringify(values)], { type: 'application/json' }));
    link.href = blob_url;
    link.download = "<ADS_CAPTURE_NAME>-developer.json";
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(blob_url), 1000);
  }, out);
  const download = await download_promise;
  await download.saveAs("<absolute ADS_CAPTURE_DIR>/developer.json");
  await download.delete();
  return { ok: true, token_len: out.dev_token.length };
}
```

```bash
python3 - "$ADS_CAPTURE_DIR/developer.json" "$ADS_OUTPUT_DIR" "$ADS_CAPTURE_NAME" "$ADS_DEVELOPER_OUTPUT" "${ADS_CAPTURE_METHOD:-}" <<'PY'
import json
import os
from pathlib import Path
import re
import stat
import sys

private_file, output_dir, capture_name, reported_file, capture_method = sys.argv[1:]
private_file = Path(private_file)
output_dir = Path(output_dir).resolve(strict=True)
reported_file = Path(reported_file)
if capture_method not in ('evaluate', 'blob'):
    raise SystemExit('Unknown capture method; files preserved')
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
if capture_method == 'evaluate':
    if private_file.stat().st_size or reported_file.stat().st_mode & 0o077:
        raise SystemExit('Capture destination changed; files preserved')
    try:
        payload = json.loads(reported_file.read_text())
    except (ValueError, UnicodeError):
        raise SystemExit('Invalid captured data; files preserved')
    valid = isinstance(payload, dict) and isinstance(payload.get('dev_token'), str) and re.fullmatch(r'[A-Za-z0-9_-]{20,28}', payload['dev_token'])
    if not valid:
        raise SystemExit('Missing or invalid credential fields; files preserved')
    private_file.write_text(json.dumps(payload))
private_file.chmod(0o600)
reported_file.chmod(0o600)
reported_file.unlink()
PY
```

**1T.3 - Save credentials.json for the selected target**

```bash
mkdir -p ~/.config/google-ads
chmod 700 ~/.config/google-ads

CLIENT_ID="$(jq -r '.client_id // empty' "$ADS_CAPTURE_DIR/client.json")"
CLIENT_SECRET="$(jq -r '.client_secret // empty' "$ADS_CAPTURE_DIR/client.json")"
DEV_TOKEN="$(jq -r '.dev_token // empty' "$ADS_CAPTURE_DIR/developer.json")"   # set by Step 1T.2
ACCESS_TOKEN="$(echo "$RESP" | jq -r .access_token)"
REFRESH_TOKEN="$(echo "$RESP" | jq -r .refresh_token)"
EXPIRES_AT="$(python3 -c 'import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$(echo "$RESP" | jq -r .expires_in)")"

jq -n \
  --arg cid "$CLIENT_ID" \
  --arg csec "$CLIENT_SECRET" \
  --arg at "$ACCESS_TOKEN" \
  --arg rt "$REFRESH_TOKEN" \
  --arg dt "$DEV_TOKEN" \
  --arg cust "$CUSTOMER_ID" \
  --arg exp "$EXPIRES_AT" \
  --arg pid "$PROJECT_ID" \
  --arg mode "$MODE" --arg level "$DEV_ACCESS_LEVEL" --arg manager "${MANAGER_CUSTOMER_ID:-}" \
  '{mode:$mode, target_mode:(if $mode == "test" then "test" else "production" end), developer_token_access_level:$level, manager_customer_id:$manager, client_id:$cid, client_secret:$csec, access_token:$at, refresh_token:$rt,
    expires_at:$exp, developer_token:$dt, customer_id:$cust, google_cloud_project:$pid}' \
  > ~/.config/google-ads/credentials.json.tmp
chmod 600 ~/.config/google-ads/credentials.json.tmp
mv ~/.config/google-ads/credentials.json.tmp ~/.config/google-ads/credentials.json
```

Verify all required credential fields are populated without printing values. After the final credential file is saved, remove only the client capture, developer-token capture, discovery draft, and their private directory. For the pending-Basic branch, defer this cleanup until Step 1L.4 has saved its application metadata. When abandoning setup, first run the guarded download cleanup above for any remaining MCP copy; retain the files while resuming an unfinished step.

```bash
rm -f "$ADS_CAPTURE_DIR/client.json" "$ADS_CAPTURE_DIR/developer.json" "$ADS_CAPTURE_DIR/request.json"
rmdir "$ADS_CAPTURE_DIR"
```

**1T.4 - Verify the actual target**

```bash
python3 "$ADS_REQUEST_HELPER" inspect
```

This makes only a minimal identity lookup, verifies the exact client ID and `customer.test_account`, and refuses manager targets. A test request requires an explicit `true` result; a missing flag or production client is not accepted as test. Only then report the test connection ready. For a verified production client, apply the production gates regardless of the token’s access tier or pending application. A failed inspection leaves setup incomplete; do not claim success from a saved file or token alone.

For a test client, say: “Your Google Ads test account is connected. I can read its setup; performance figures will be empty because test ads don’t run.”

---

### Step 1L - Basic Access mode (`MODE=basic`)

Basic Access requires Google review, currently typically five business days and sometimes longer. Skip this application when the observed Explorer, Basic, or Standard access already permits the requested work. A test fallback is ready only after the separate test setup and real identity check succeed.

**1L.1 - Navigate to API Center, click Apply for Basic Access**

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Click the **Apply for Basic Access** button (visible in the API Center when the account is in Test tier):

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /apply.*basic access|upgrade.*api access/i.test((b.innerText||'').trim()));
  if (btn) { btn.click(); return { clicked: true }; }
  return { clicked: false };
}
```

**1L.2 - Fill the application form via Playwright**

The form asks ~10 questions. Defaults to use (revise with the participant before submit):

| Field | Default value |
|---|---|
| Tool name | "Claude Google Ads Connector" |
| Tool URL | The participant’s actual working tool or business website; do not submit `example.com` or invent a deployed tool |
| Tool description | "Personal API access to my own Google Ads account for reporting and management via Claude, an AI assistant. Used by me only; not redistributed." |
| Intended use | "Reports and basic management of my own ads accounts" |
| Email | Participant's signed-in Google account email |
| Contact preferences | "Email me about API news" - opt out by default |
| Industry | Participant's industry (ask if not obvious) |
| Are you an agency? | No (default - most workshop participants aren't agencies) |

Use the React-friendly setter pattern (same as QBO Phase 1L Step 1L-C.1):

```js
(fieldLabel, value) => {
  const labels = Array.from(document.querySelectorAll('label, div, span')).filter(el => new RegExp(`^${fieldLabel}`, 'i').test((el.innerText||'').trim()));
  for (const labelEl of labels) {
    let scope = labelEl.parentElement;
    for (let d = 0; d < 4 && scope; d++) {
      const input = scope.querySelector('input[type=text], input[type=url], textarea, select, input:not([type])');
      if (input) {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        input.focus(); setter.call(input, value);
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        input.blur();
        return { ok: true };
      }
      scope = scope.parentElement;
    }
  }
  return { ok: false };
}
```

**1L.3 - Surface the application to the participant for review**

Before submitting, summarise in plain English what you typed:

> "Here's what I'll send Google for the review:
>
> - Tool name: **Claude Google Ads Connector**
> - Purpose: Personal API access to my own Google Ads account
> - Industry: **[X]**
> - Email: **[participant email]**
>
> Want me to adjust anything before I send it?"

Wait for confirmation, adjust if needed, then click **Submit**:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^submit$/i.test((b.innerText||'').trim()));
  if (btn) { btn.scrollIntoView({block:'center'}); btn.click(); return { clicked: true }; }
  return { clicked: false };
}
```

Wait for the post-submit confirmation (`browser_wait_for({ text: "submitted" })` or similar).

**1L.4 - Record the application without inventing a test fallback**

Persist the application timestamp and status in `basic_application`, preserving the captured developer token and selected target. Keep `target_mode` explicit; `mode=pending-basic` describes review status, not whether an account is a test account. There are not separate Test and Basic developer tokens to switch between.

If a practice connection is wanted while review is pending, complete Step 6's separate test hierarchy, authorize its actual user, select its client and manager IDs, and run the shared persistence and inspection steps. For this fallback set `MODE=test` when running Step 1T.3 so it saves `target_mode=test`; then attach the pending application metadata and set `mode=pending-basic` without changing that explicit target type. If a test fallback has not passed inspection, report the pending review and actual remaining setup rather than saying it is connected. Preserve any intended production client details separately; approval alone must not silently repoint an existing test connection.

**1L.5 - Resume after approval (called from Phase 0.3 when status=pending-basic and 24h+ since applied)**

Navigate to `ads.google.com/aw/apicenter`. The page shows either "Basic Access" (approved) or "Pending Review".

If approved, observe the actual access tier and retain the existing developer token unless Google explicitly rotated it.

Update the observed `developer_token_access_level` and application status. Keep the existing token and current test target. To connect production, select the intended production client and manager, verify the matching OAuth principal, set `target_mode=production` and legacy `mode=basic`, then run `inspect` and the production gates. Do not claim production access until that read succeeds.

Tell the participant: *"Google approved the access upgrade. I’ll verify your chosen account before using its real data."* Then trigger Phase 2 Gate 1 (real-data confirmation) on the NEXT tool call.

If still pending: see Phase 0.3.

---

## PHASE 1F - Wrap the official google-ads-mcp for reads

After Phase 1T or Phase 1L completes (credentials.json populated), Phase 1F writes an Application Default Credentials JSON file and registers Google's official MCP server as `google_ads` in Claude Code. Three tools become available after restart: `mcp__google_ads__search`, `mcp__google_ads__list_accessible_customers`, `mcp__google_ads__get_resource_metadata`. The MCP is read-only - Phase 2 writes still go through direct REST.

Phase 1F is **best-effort**. If `pipx` install fails (no Python, restricted environment, corporate network) or the MCP registration fails, log the failure silently and proceed; Phase 2 reads then fall back to the REST helper examples documented below.

### Step 1F.1 - Write the ADC credentials file

Google's MCP authenticates via `google.auth.default()` which resolves Application Default Credentials. Rather than requiring `gcloud` CLI install (heavy - ~100MB toolchain), we write the credentials JSON directly from Phase 1's captured `client_id` + `client_secret` + `refresh_token`. The Google auth library accepts `{"type":"authorized_user", ...}` JSON files via `GOOGLE_APPLICATION_CREDENTIALS`, dispatching on the `type` field.

```bash
CREDS="$HOME/.config/google-ads/credentials.json"
ADC="$HOME/.config/google-ads/adc-credentials.json"
mkdir -p "$(dirname "$ADC")"
chmod 700 "$(dirname "$ADC")"

jq '{type:"authorized_user", client_id, client_secret, refresh_token}' "$CREDS" > "$ADC.tmp"
chmod 600 "$ADC.tmp"
mv "$ADC.tmp" "$ADC"
```

Verify the file shape:

```bash
jq -r 'keys | join(",")' "$ADC"
# expect: client_id,client_secret,refresh_token,type
```

> **Why a custom path, not gcloud's default `~/.config/gcloud/application_default_credentials.json`?** If the participant already uses `gcloud` for unrelated work (other GCP projects, BigQuery, etc.), writing to gcloud's default ADC path would silently clobber their existing credentials. Our own path at `~/.config/google-ads/adc-credentials.json` is dedicated to this connector and pointed-to via `GOOGLE_APPLICATION_CREDENTIALS` set in `claude mcp add --env` (Step 1F.4). The participant's gcloud setup is untouched.

### Step 1F.2 - Detect or install `pipx`

```bash
if ! command -v pipx >/dev/null 2>&1; then
  # pipx installs cleanly via `python3 -m pip install --user pipx` on every supported platform
  python3 -m pip install --user pipx 2>&1 | tail -3
  python3 -m pipx ensurepath 2>&1 | tail -3
  # Refresh PATH so the just-installed pipx is visible without a shell restart
  export PATH="$HOME/.local/bin:$PATH"
fi

pipx --version 2>&1 | head -1
```

If `python3 --version` returns < 3.7 or fails entirely, surface to the participant in plain English: *"I'd love to plug Google's official Google Ads tool in for you - but it needs Python on your computer, and I don't see it. Want to install Python first (it's free), or skip this step? Either way your connection works either way; Google's tool just makes reads a bit cleaner."*

If they skip: set `MCP_INTEGRATION=skipped` in a sidecar marker (`~/.config/google-ads/.mcp-skipped`) and exit Phase 1F. Phase 2 will route reads through direct REST.

### Step 1F.3 - Validate the MCP runs

Before registering with Claude Code, smoke-test that `pipx run google-ads-mcp` can actually start (catches missing system libraries, Python version issues, network failures during the first git clone):

```bash
timeout 30 pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp --help 2>&1 | head -10
```

The first run downloads the MCP package from GitHub and creates an isolated venv via pipx (~20-40 seconds depending on network). Subsequent runs are near-instant. If `--help` returns non-zero, surface the error briefly and skip to Step 1F.5 (skip registration). Common causes: corporate firewall blocking `github.com`, Python 3.7+ missing, pip install denied.

### Step 1F.4 - Register the MCP server with Claude Code

```bash
ADC="$HOME/.config/google-ads/adc-credentials.json"
GOOGLE_PROJECT_ID="$(jq -r .google_cloud_project "$CREDS")"
DEV_TOKEN="$(jq -r .developer_token "$CREDS")"
# Manager-customer-id only if the participant uses a manager account (rare for SMBs; field optional)
MANAGER_CID="$(jq -r '.manager_customer_id // empty' "$CREDS")"

CMD=(claude mcp add google_ads --scope user
  --env "GOOGLE_APPLICATION_CREDENTIALS=$ADC"
  --env "GOOGLE_PROJECT_ID=$GOOGLE_PROJECT_ID"
  --env "GOOGLE_ADS_DEVELOPER_TOKEN=$DEV_TOKEN")
if [ -n "$MANAGER_CID" ]; then
  CMD+=(--env "GOOGLE_ADS_LOGIN_CUSTOMER_ID=$MANAGER_CID")
fi
CMD+=(-- pipx run --spec git+https://github.com/googleads/google-ads-mcp.git google-ads-mcp)

"${CMD[@]}" >/dev/null 2>&1
```

> **Why `>/dev/null 2>&1`?** `claude mcp add` v2.1.x echoes `--env` values verbatim on stdout - see memory `reference_claude_mcp_add_token_echo`. The redirect prevents the dev token from leaking into the tool stream.

Verify the terminal registration (this does not verify a different Desktop caller):

```bash
claude mcp list 2>&1 | grep -E '^google_ads:'
```

Expect `google_ads: pipx run ... - ✓ Connected`. If `✗ Failed to connect`, the most common cause is `GOOGLE_APPLICATION_CREDENTIALS` pointing to a malformed JSON file - re-check Step 1F.1's output.

### Step 1F.5 - Prompt restart Claude Code

A restart is required only because Phase 1F registered a new MCP server (`google_ads`); the new `mcp__google_ads__*` tools only enter Claude Code's deferred-tool surface after the MCP runtime reconciles them at startup. Phase 1T's and Phase 1L's completion prose (the *"All connected - your Google Ads test account is ready"* / *"Google approved you"* messages) deliberately omits any restart instruction so the SKILL can decide where to place it based on whether Phase 1F ran.

If Phase 1F ran successfully, replace Phase 1T's / 1L's plain completion message with a restart-prompt variant:

> "All connected. One last step: please close this window and reopen Claude Code, then say hi. The Google Ads tools will be ready for you."

If Phase 1F was skipped (`.mcp-skipped` marker present), keep the original Phase 1T / 1L completion message - no restart needed, reads route through direct REST immediately.

After restart, discover the actual caller's Google Ads tools, then run the Phase 2 minimal identity query through that tool before claiming the MCP route connected. If Desktop does not expose this terminal registration, continue with the verified REST helper route; do not claim terminal status proves Desktop access.

### Phase 1F skip-state

If Phase 1F was skipped (no Python, install failure, participant opted out), `~/.config/google-ads/.mcp-skipped` exists. Phase 2 reads detect this and use the direct-REST fallback path documented under each Pattern below.

---

## PHASE 2 - Use Tools

Phase 2 runs after a successful target inspection. Before every report or write:

1. Read the saved target and credentials; refresh expired REST access via Step 2.0.
2. Verify the exact client ID, `customer.manager`, and `customer.test_account` using the route that will perform the operation. This minimal identity lookup is allowed before the production gate; it is not a campaign report.
3. Require an explicit `test_account: true` for a test target. A missing flag, manager account, or different ID stops the operation. `mode=test`, a pending application, and a token access tier never prove that an account is a test account.
4. If the verified client is production, apply Gate 1 before reporting and Gate 2 before each write. Do not repoint an intended test connection to production without the participant's instruction.

### Production gate 1 - Confirm real data once per target per session

Use the verified identity to say: *"You're connected to your real Google Ads account **[CompanyName]** ([CID]). I'll **[requested action]** there."* Obtain approval if the user's existing request has not already authorized that specific account and action. Reuse clear authorization for the same target in this session. Changing targets requires a new check.

### Production gate 2 - Confirm the specific change before each write

For Patterns 9 and 10, make the proposed change concrete: campaign name, current and proposed status or daily budget, and account. Obtain approval when that exact change is not already authorized. Explain that pausing/resuming takes effect when Google processes the change, and that budget changes affect real spend; do not promise an instant stop or a next-day-only effect.

The helper refuses production operations unless `--production-approved` is supplied. The harness may supply it only after the applicable gate is satisfied, never because of `MODE` or token tier. Initialize `ADS_PRODUCTION_ARGS=()` in each shell invocation; set `ADS_PRODUCTION_ARGS=(--production-approved)` only for that approved production operation. Do not persist this flag in credentials.

### Read routing - MCP-first, direct-REST fallback

Use the actual caller's available tools. A terminal `claude mcp list` result is not proof that the current Desktop session has those tools or the same identity. If the official Google Ads search tool is callable, make its first query against the exact selected `CID` with fields `customer.id`, `customer.descriptive_name`, `customer.manager`, `customer.test_account`, resource `customer`, limit 1. Validate that result with the rules above before any report, and repeat before subsequent operations. A REST identity check alone does not verify another MCP session's credentials.

- `ROUTE=mcp` → use the actual search tool and the structured recipes below after its own identity check. Missing or ambiguous identity results stop that route.
- `ROUTE=rest` → use the bundled helper via `gaql_call`; it performs the identity check before every report or mutation. If MCP is unavailable, this route remains supported.

The MCP's `search` tool signature (from `ads_mcp/tools/search.py`):

```
mcp__google_ads__search({
  customer_id: string,         // required
  fields: string[],            // required, e.g. ["metrics.cost_micros", "campaign.name"]
  resource: string,            // required, e.g. "customer", "campaign", "keyword_view"
  conditions?: string[],       // optional, e.g. ["segments.date DURING THIS_MONTH"]
  orderings?: string[],        // optional, e.g. ["metrics.cost_micros DESC"]
  limit?: number               // optional
})
```

The MCP constructs the GAQL query internally from the structured args. The 8 read patterns below show both shapes - MCP first, direct-REST fallback below it.

**Writes (Patterns 9-10) always run direct REST** regardless of `ROUTE` - the official MCP doesn't expose mutate endpoints.

### Step 2.0 - Refresh access token (called automatically by every tool, direct-REST path only)

Only runs when `ROUTE=rest`. The MCP handles its own token refresh internally via `google.auth.default()`.

```bash
CREDS="$HOME/.config/google-ads/credentials.json"
EXPIRES_AT="$(jq -r .expires_at "$CREDS")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "$NOW" \> "$EXPIRES_AT" ] 2>/dev/null; then
  CLIENT_ID="$(jq -r .client_id "$CREDS")"
  CLIENT_SECRET="$(jq -r .client_secret "$CREDS")"
  REFRESH_TOKEN="$(jq -r .refresh_token "$CREDS")"

  RESP="$(curl -sf https://oauth2.googleapis.com/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "client_id=$CLIENT_ID" \
    -d "client_secret=$CLIENT_SECRET" \
    -d "refresh_token=$REFRESH_TOKEN" \
    -d "grant_type=refresh_token")"

  NEW_AT="$(echo "$RESP" | jq -r .access_token)"
  NEW_EXP="$(python3 -c 'import datetime,sys; print((datetime.datetime.utcnow()+datetime.timedelta(seconds=int(sys.argv[1]))).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$(echo "$RESP" | jq -r .expires_in)")"

  jq --arg at "$NEW_AT" --arg exp "$NEW_EXP" '.access_token=$at | .expires_at=$exp' "$CREDS" > "$CREDS.tmp"
  chmod 600 "$CREDS.tmp"
  mv "$CREDS.tmp" "$CREDS"
fi

ACCESS_TOKEN="$(jq -r .access_token "$CREDS")"
DEV_TOKEN="$(jq -r .developer_token "$CREDS")"
CID="$(jq -r .customer_id "$CREDS")"
```

### Common Pattern 1 - Spend this month

**MCP path (`ROUTE=mcp`):**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["metrics.cost_micros"],
  resource: "customer",
  conditions: ["segments.date DURING THIS_MONTH"]
})
```

**Direct-REST fallback (`ROUTE=rest`):**

```bash
gaql_call() {
  python3 "$ADS_REQUEST_HELPER" "${ADS_PRODUCTION_ARGS[@]}" search --query "$1"
}

gaql_call "SELECT metrics.cost_micros FROM customer WHERE segments.date DURING THIS_MONTH"
```

Response shape (both paths): `[{ metrics: { costMicros: "<n>" } }]` (MCP returns a flat list; direct REST wraps it as `{ results: [...] }`). Divide `costMicros` by 1,000,000 to get the currency unit. Present as "$X.XX this month."

**Use when:** "what's my Google Ads spend?", "how much have I spent this month?"

### Common Pattern 2 - Top campaigns by conversions (last 30 days)

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["campaign.name", "metrics.conversions", "metrics.cost_micros"],
  resource: "campaign",
  conditions: ["segments.date DURING LAST_30_DAYS"],
  orderings: ["metrics.conversions DESC"],
  limit: 10
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT campaign.name, metrics.conversions, metrics.cost_micros FROM campaign WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.conversions DESC LIMIT 10"
```

Present as a table with Campaign / Conversions / Cost / Cost per Conversion.

**Use when:** "best campaigns?", "top performers?", "what's working?"

### Common Pattern 3 - Keyword performance

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["ad_group_criterion.keyword.text", "ad_group_criterion.keyword.match_type",
           "metrics.clicks", "metrics.cost_micros", "metrics.conversions"],
  resource: "keyword_view",
  conditions: ["segments.date DURING LAST_30_DAYS"],
  orderings: ["metrics.clicks DESC"],
  limit: 25
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type, metrics.clicks, metrics.cost_micros, metrics.conversions FROM keyword_view WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.clicks DESC LIMIT 25"
```

Filter client-side for `ad_group_criterion.status = 'ENABLED'` to show only active keywords.

**Use when:** "my keywords", "keyword performance", "what keywords are driving clicks?"

### Common Pattern 4 - Search terms triggering my ads

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["search_term_view.search_term", "metrics.clicks", "metrics.cost_micros"],
  resource: "search_term_view",
  conditions: ["segments.date DURING LAST_30_DAYS"],
  orderings: ["metrics.clicks DESC"],
  limit: 25
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT search_term_view.search_term, metrics.clicks, metrics.cost_micros FROM search_term_view WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.clicks DESC LIMIT 25"
```

**Use when:** "what searches show my ads?", "search terms report", "what are people searching to find me?"

### Common Pattern 5 - Ad-level performance

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["ad_group_ad.ad.id", "ad_group_ad.ad.responsive_search_ad.headlines",
           "metrics.clicks", "metrics.conversions"],
  resource: "ad_group_ad",
  conditions: ["segments.date DURING LAST_30_DAYS",
               "ad_group_ad.status = 'ENABLED'"],
  orderings: ["metrics.clicks DESC"],
  limit: 10
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT ad_group_ad.ad.id, ad_group_ad.ad.responsive_search_ad.headlines, metrics.clicks, metrics.conversions FROM ad_group_ad WHERE segments.date DURING LAST_30_DAYS AND ad_group_ad.status = 'ENABLED' ORDER BY metrics.clicks DESC LIMIT 10"
```

The `responsive_search_ad.headlines` field is an array of text variations. Present the first 2-3 headlines per ad with metrics.

**Use when:** "my ads", "best ads", "ad performance", "which ads are working?"

### Common Pattern 6 - This month vs last month

Two queries, present side-by-side. Compute deltas client-side.

**MCP path** (call once per range):

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["metrics.cost_micros", "metrics.conversions", "metrics.clicks"],
  resource: "customer",
  conditions: ["segments.date DURING THIS_MONTH"]
})
// then again with conditions: ["segments.date DURING LAST_MONTH"]
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT metrics.cost_micros, metrics.conversions, metrics.clicks FROM customer WHERE segments.date DURING THIS_MONTH"
gaql_call "SELECT metrics.cost_micros, metrics.conversions, metrics.clicks FROM customer WHERE segments.date DURING LAST_MONTH"
```

**Use when:** "compare to last month", "month over month", "is performance improving?"

### Common Pattern 7 - Audience performance

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["campaign.name", "ad_group.name", "metrics.clicks", "metrics.conversions"],
  resource: "audience",
  conditions: ["segments.date DURING LAST_30_DAYS"],
  orderings: ["metrics.conversions DESC"],
  limit: 15
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT campaign.name, ad_group.name, metrics.clicks, metrics.conversions FROM audience WHERE segments.date DURING LAST_30_DAYS ORDER BY metrics.conversions DESC LIMIT 15"
```

**Use when:** "audience report", "which audiences convert?"

### Common Pattern 8 - List all campaigns

**MCP path:**

```
mcp__google_ads__search({
  customer_id: "<CID>",
  fields: ["campaign.id", "campaign.name", "campaign.status", "campaign_budget.amount_micros"],
  resource: "campaign",
  orderings: ["campaign.name"]
})
```

**Direct-REST fallback:**

```bash
gaql_call "SELECT campaign.id, campaign.name, campaign.status, campaign_budget.amount_micros FROM campaign ORDER BY campaign.name"
```

Returns id, name, ENABLED/PAUSED/REMOVED status, daily budget. Present as a table.

**Use when:** "list my campaigns", "show all campaigns", "campaign summary"

> **For the `list_accessible_customers` shape**: `mcp__google_ads__list_accessible_customers({})` - no args, returns `[{ "customer_id": "1234567890" }, ...]`. This lists directly accessible accounts, not every client under a manager; use the manager hierarchy discovery from Step 10 for those clients. No direct-REST equivalent in this SKILL because Step 10 (Phase 1) already covers that endpoint during install.

> **For the `get_resource_metadata` shape**: `mcp__google_ads__get_resource_metadata({ resource: "campaign" })` returns the field metadata for the named GAQL resource (selectable fields, segments, etc.). Useful when constructing a non-standard GAQL query for an ad-hoc participant question.

### Common Pattern 9 - Pause or resume a campaign (write, gated)

Inspect the target and apply both production gates when it is a real account. Set `ADS_PRODUCTION_ARGS` only as authorized above.

```bash
CAMPAIGN_ID="<the id>"
NEW_STATUS="PAUSED"  # or "ENABLED" to resume

umask 077
ADS_PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/google-ads-mutation.XXXXXXXX")"
jq -n --arg rn "customers/$CID/campaigns/$CAMPAIGN_ID" --arg st "$NEW_STATUS" \
  '{operations:[{update:{resourceName:$rn, status:$st}, updateMask:"status"}]}' > "$ADS_PAYLOAD"
python3 "$ADS_REQUEST_HELPER" "${ADS_PRODUCTION_ARGS[@]}" mutate --resource campaigns --payload-file "$ADS_PAYLOAD"
ADS_RESULT=$?
rm -- "$ADS_PAYLOAD"
[ "$ADS_RESULT" -eq 0 ]
```

Response includes the resource name and confirmation. Tell the participant *"Campaign **[Name]** is now paused."* - never imply ads have stopped showing instantly (Google's edge cache can take a few minutes).

**Use when:** "pause X", "resume X", "stop my ads"

### Common Pattern 10 - Change daily budget (write, gated)

Inspect the target and apply both production gates when it is a real account. Set `ADS_PRODUCTION_ARGS` only as authorized above.

Daily budgets live on a `campaign_budget` resource (separate from the campaign). To change a campaign's budget:

```bash
# 1. Find the budget ID
BUDGET_RES="$(gaql_call "SELECT campaign_budget.resource_name FROM campaign WHERE campaign.id = $CAMPAIGN_ID" | jq -r '.results[0].campaignBudget.resourceName')"

# 2. Mutate it (amount in micros - multiply dollar amount by 1,000,000)
NEW_MICROS="$(( NEW_DAILY_USD * 1000000 ))"

umask 077
ADS_PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/google-ads-mutation.XXXXXXXX")"
jq -n --arg rn "$BUDGET_RES" --argjson m "$NEW_MICROS" \
  '{operations:[{update:{resourceName:$rn, amountMicros:($m|tostring)}, updateMask:"amount_micros"}]}' > "$ADS_PAYLOAD"
python3 "$ADS_REQUEST_HELPER" "${ADS_PRODUCTION_ARGS[@]}" mutate --resource campaignBudgets --payload-file "$ADS_PAYLOAD"
ADS_RESULT=$?
rm -- "$ADS_PAYLOAD"
[ "$ADS_RESULT" -eq 0 ]
```

**Use when:** "increase budget for X", "lower spend on X", "set daily budget to $Y"

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "What's my Google Ads spend?" / "How much have I spent?" | Pattern 1 |
| "Best campaigns?" / "Top performers?" | Pattern 2 |
| "My keywords" / "Keyword performance" | Pattern 3 |
| "Search terms report" / "What searches trigger my ads?" | Pattern 4 |
| "My ads" / "Which ads are working?" | Pattern 5 |
| "Compare to last month" / "Month over month" | Pattern 6 |
| "Audience report" | Pattern 7 |
| "List my campaigns" | Pattern 8 |
| "Pause X" / "Resume X" / "Stop my ads" | Pattern 9 (gated) |
| "Increase budget" / "Change daily budget" | Pattern 10 (gated) |
| "What's my ROAS?" | Pattern 2 with derived metric: `conversions_value / cost_micros` |
| "Connect Google Ads" / "Help me set up Google Ads" | **Run Phase 0** |
| "Check my Google Ads approval" | **Run Phase 0.3** |
| "List all my Google Ads accounts" | `mcp__google_ads__list_accessible_customers({})` (MCP) or the helper's `list-customers` command as in Phase 1 Step 10 (REST) |
| "What fields can I query for X?" | `mcp__google_ads__get_resource_metadata({ resource: "<X>" })` (MCP only - no direct-REST shortcut) |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| `mcp__google_ads__*` tools missing after restart | Phase 1F skipped, failed, or pipx not on PATH | Re-run Phase 1F; if it still fails, fall back to direct REST and tell the participant *"Google's tool isn't installable on your system; I'll use a backup connection. Same results, just a bit slower."* |
| `mcp__google_ads__search` returns `PERMISSION_DENIED` referencing `developer-token` | Token access or the MCP's configured token may not match the selected target | Check the actual token tier, target, and manager route first. Update registration only if its saved token is demonstrably stale; do not rotate a valid token or reauthorize as a substitute for API access review. |
| `mcp__google_ads__search` returns `INVALID_RESOURCE` | `fields` or `resource` arg names are wrong (e.g. typo in a field) | Run `mcp__google_ads__get_resource_metadata({ resource: "<x>" })` to confirm the legal field list, then retry |
| HTTP 401 `UNAUTHENTICATED` (direct-REST path only) | Access token expired | Run Step 2.0 (refresh) and retry once |
| Developer-token access error | The token's observed access level or permissible use may not allow the selected target | Check the owning non-test manager's API Center and actual client type. Explorer, Basic, and Standard can allow production; an upgrade uses the same token. Never change a test target to production as error recovery. |
| `CUSTOMER_NOT_ENABLED` | The selected account is unavailable | Verify the selected client and its actual account status. Test accounts can appear cancelled and never require billing; do not add billing to recover a test connection. |
| `TEST_TARGET_REQUIRED_NO_REPORTS_OR_WRITES_SENT` or `TARGET_IDENTITY_NOT_VERIFIED` | The intended test client was not verified | Preserve credentials and select the correct test hierarchy/account. No report or write was sent. |
| `GOOGLE_ADS_HTTP_<status>` | The helper withheld the raw error body | Check token expiry, manager route, target access, and API version as appropriate. A retired API version requires updating the helper from current official docs, not reauthorization. |
| HTTP 400 `INVALID_ARGUMENT` and `query` in message | GAQL syntax error | Diagnose silently, retry with corrected query, fall back to plain English if can't fix |
| HTTP 400 `RESOURCE_EXHAUSTED` | Rate limit (Basic Access: 15,000 ops/day) | Tell the participant: *"Google's asking me to slow down - let me wait a minute and try again."* Sleep 60, retry once. |
| HTTP 429 | Per-second rate cap | Exponential backoff: 1s, 2s, 4s. Three retries then surface. |
| Refresh token revoked (HTTP 400 with `invalid_grant` on refresh) | Participant revoked Google's permission grant | Tell the participant: *"Looks like the connection was disconnected at your end. Let me reconnect."* Run Phase 1 from Step 7 (re-OAuth). |

Translate every error to plain English. Never show raw HTTP bodies to the participant.

---

## Scope Limitations

This connector **can**:

- Read all standard reporting resources (`customer`, `campaign`, `ad_group`, `ad_group_ad`, `keyword_view`, `search_term_view`, `audience`, plus the report-specific resources `geographic_view`, `paid_organic_search_term_view`, etc. - anything queryable via GAQL via `googleAds:search` or `googleAds:searchStream`).
- Pause / resume campaigns and ad groups via the `mutate` endpoints.
- Change campaign budget daily amounts via the `campaignBudgets:mutate` endpoint.

It **cannot** access:

- **Standard Access tier features** - that's a separate Google approval beyond Basic Access; tracked as a future issue. Most workshop participants will not need it.
- **Bulk uploads / bulk mutates** (the `BulkMutateRequest` endpoint) - not in v1; tracked as future.
- **Manager-account-level admin** (creating sub-accounts, billing, account-level changes) - separate flow, not in v1.
- **Conversion-tracking setup** - creating goals, tags, audiences requires the Conversion Action APIs which are not in v1's 10 patterns.
- **Ad-asset upload** (images, videos for image ads) - requires multipart upload to `Asset:mutate`; not in v1.
- **Writes via the official MCP** - `googleads/google-ads-mcp` is strictly read-only. Patterns 9 and 10 in this SKILL go through direct REST regardless of `ROUTE`. When that MCP eventually adds write tools (no roadmap signal yet), this SKILL can swap them in with a localised edit to Patterns 9 and 10.

It **requires** at least one operating Google Ads customer the participant has access to. Manager-only logins with no operating account underneath will fail at Step 10.

---

## Behaviour Guidelines (Phase 2)

- **Read routing** - use the actual caller's tools and verify the selected client through that route. Terminal status is not Desktop proof. The REST helper is the fallback.
- **Target awareness** - verify `customer.test_account` before every report or write. Test intentions require `true`; actual production targets require Gate 1 and each write requires Gate 2 regardless of saved mode, approval state, or token tier. Pending review never makes a production account a test account.
- **Always present money in real units** - divide `costMicros` and `amountMicros` by 1,000,000. Use the account's currency (read from `customer.currency_code` if needed).
- **Date ranges in GAQL** - supported tokens: `TODAY`, `YESTERDAY`, `LAST_7_DAYS`, `LAST_14_DAYS`, `LAST_30_DAYS`, `LAST_BUSINESS_WEEK`, `LAST_WEEK_SUN_SAT`, `LAST_WEEK_MON_SUN`, `THIS_MONTH`, `LAST_MONTH`, `THIS_QUARTER`, `LAST_QUARTER`, `ALL_TIME`. For arbitrary ranges, use `segments.date BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'`.
- **Status filter** - by default skip REMOVED entities (they're soft-deleted). Add `WHERE campaign.status != 'REMOVED'` etc.
- **Auth errors** → run Step 2.0 (refresh), retry; if refresh fails, re-run Phase 1 from Step 7.
- **Never log or echo credentials** - `client_id`, `client_secret`, `developer_token`, `access_token`, `refresh_token` are sensitive. None of them appears in any output visible to the participant.
- **Production writes** - apply Gate 2 before every write to a real account. Never derive `--production-approved` from saved mode or token tier.

---

## Related Skills

- **`paid-ads`**: The strategy advisor. Pair when the participant wants advice on what to DO with the data the connector returns. The advisor asks "what's working?" and Claude uses this connector to answer factually.
- **`quickbooks-connector`**: Same Phase 0 / Phase 1 Playwright-driven autonomous pattern. QBO's Phase 1L (Cloudflare Pages + tunnel) is heavier than this connector's Phase 1L (Google Ads' API Center is in-portal). Both connectors wrap an official vendor MCP in the same shape - QBO via `intuit/quickbooks-online-mcp-server`, this connector via `googleads/google-ads-mcp` for the read surface.
- **`myob-connector`**: The Direct-REST + Playwright reference SKILL this connector models Phase 1 on. Loopback listener pattern, atomic `credentials.json` write pattern, and refresh-on-call pattern all borrowed from MYOB. MYOB has no official MCP so it stays pure direct-REST; this SKILL is the hybrid example.
- **`ghl-connector`**: The other vendor-MCP wrapper in the kit. Reference for the Playwright-driven autonomous-Phase-1 communication rules.
- **`superpowers:systematic-debugging`**: For troubleshooting OAuth flow failures or unexpected GAQL responses.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - the three-pattern decision tree (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace). This SKILL is a hybrid (vendor-MCP wrap for reads + direct REST for writes) explicitly out of scope for that doc; follow `myob-connector`'s shape for the direct-REST half and `quickbooks-connector`'s shape for the vendor-MCP-wrap half.
- [google-ads-mcp official repo](https://github.com/googleads/google-ads-mcp) - Google's read-only MCP server (Apache-2.0). Source for the `search` / `list_accessible_customers` / `get_resource_metadata` tool signatures Phase 2 calls.
- [FastMCP framework](https://github.com/jlowin/fastmcp) - the framework `googleads/google-ads-mcp` is built on. Useful for understanding the OAuth proxy mode the MCP supports (which this SKILL deliberately does not use - see Phase 1F.1's design note).
- [Google Ads API reference](https://developers.google.com/google-ads/api/docs/start) - the official source of GAQL grammar, resource shapes, and rate limits.
- [Google Ads API Center](https://ads.google.com/aw/apicenter) - where Phase 1T and Phase 1L dev tokens come from.
- [Google Application Default Credentials reference](https://cloud.google.com/docs/authentication/application-default-credentials) - confirms the `{"type":"authorized_user", ...}` JSON file format Phase 1F.1 writes.
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule (applies to Google Cloud, Google Ads, and the consent screen alike).
- Memory `reference_claude_mcp_add_token_echo` - `>/dev/null 2>&1` requirement on `claude mcp add --env`.
- Memory `feedback_workshop_kit_update_format` - say "test mode" to participants, not "sandbox".
