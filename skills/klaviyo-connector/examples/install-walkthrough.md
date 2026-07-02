# Klaviyo Connector - Install Walkthrough

> **Status: captured reference run, 2026-06-02 against rodolfo@selrai.com.au's Klaviyo account.** Three real SKILL drifts were discovered during this run and fixed in PR (separate commit): (1) the SKILL's documented URL `/account#api-keys-tab` 302-redirects to `/settings/account/api-keys` (canonical), (2) the Create Private API Key click navigates to a **new full page** at `/create-private-api-key` - NOT a modal as the SKILL prose implied, (3) the form's submit button is exactly **`Create`** (NOT `Create Private API Key` / `Generate Key` / `Save`). All three are now reflected in SKILL.md Steps 3-4. The captured key was 44 chars `pk_`-prefixed; verified live calls to `/accounts/` and `/lists` returned correct shapes.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL - Klaviyo's free tier IS real data (up to 250 profiles, 500 sends/month); the participant's free or paid Klaviyo account is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, and a clipboard utility (`wl-paste`/`wl-copy` on Linux/Wayland; `pbpaste`/`pbcopy` on macOS; `powershell.exe Get-Clipboard`/`Set-Clipboard` on Windows Git Bash) on PATH.
- Internet access (www.klaviyo.com + a.klaviyo.com).
- Participant has a Klaviyo account (free tier is fine).

Projected total: ~45 seconds for an account with a cached sign-in cookie; ~90 seconds for cold sign-in including the 2FA / email verification Klaviyo enforces on first new-device login.

---

## Step 0 - Credential check

```bash
$ test -f "$HOME/.config/klaviyo/credentials.json" \
    && jq -r '.api_endpoint // "missing"' "$HOME/.config/klaviyo/credentials.json" \
    || echo missing
missing
```

→ run Phase 1.

---

## Step 1 - Welcome

Claude sends the welcome message.

---

## Step 2 - Sign in to Klaviyo

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/login" })
mcp__playwright__browser_wait_for({ text: "Dashboard", time: 60 })
```

Projected: participant signs in (or session is still active from a prior workshop step). The Dashboard renders.

Klaviyo's first-new-device sign-in flow includes an emailed verification code or 2FA prompt. The `browser_wait_for` polls past it; if it times out, prompt the participant: *"I'm waiting on Klaviyo's verification code - check your email and approve."*

---

## Step 3 - Navigate to API keys settings (captured: canonical URL)

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/settings/account/api-keys" })
```

**Captured 2026-06-02**: navigating to the legacy `klaviyo.com/account#api-keys-tab` issues a 302 redirect to `klaviyo.com/settings/account/api-keys` (clean URL, no hash fragment). The canonical URL is the new one. Both work but the canonical avoids the redirect hop. Page renders directly without iframe or modal - text content shows `Public API Key`, `Private API Keys`, `Create Private API Key` button, all flat on the page.

---

## Step 4 - Create the Private API Key (captured: full-page form, NOT a modal)

**Real form layout (captured 2026-06-02):**

Claude clicks `Create Private API Key`. The browser navigates to `https://www.klaviyo.com/create-private-api-key` - a full page form, NOT a modal dialog. Page heading: `New private API key`.

The form has three sections:

1. **Private API Key Name** (text input; `name="Private API Key Name"`, `placeholder="Name your key"`)
2. **Select Access Level** (three radio cards, in order): **`Custom Key`** / **`Read-Only Key`** / **`Full Access Key`** - note the `Key` suffix on each card label, not just `Read-only` / `Full` / `Custom` as the SKILL prose suggested.
3. **API Scopes** table (per-resource scopes - only visible when Custom is selected)

Claude fills `Claude Workshop Connector` into the name input, then clicks the `Full Access Key` radio card (Patterns 5/9/10 need write access).

Submit button: **exact text is `Create`** (NOT `Create Private API Key`, NOT `Generate`, NOT `Submit`). There are TWO `Create` buttons visible on the page - one is the sidebar workshop-feature dropdown (`NavRow-*` classes), one is the form's submit button (`Mixins-medium-OrkBY` class). The SKILL Step 4 script filters out the `NavRow` button to pick the right one.

Captured wall-clock: ~5 seconds (name fill + radio click + Create click + ~3s server-side key generation).

---

## Step 5 - DOM-extract via clipboard transit

Save prior clipboard:

```bash
$ wl-paste 2>/dev/null | base64 -w0 > /tmp/klaviyo-prev-clipboard.b64
[clipboard saved]
```

Extract:

```js
async () => {
  const re = /\bpk_[A-Za-z0-9_-]{30,}\b/;
  // ... walk DOM, find the new key (starts with pk_)
  await navigator.clipboard.writeText(JSON.stringify({ api_key: key }));
  return { ok: true, key_len: 44 };
}
```

Captured return: `{ ok: true, key_len: 44 }`. Klaviyo's Private Key was exactly 44 chars including `pk_` prefix. Existing regex `pk_[A-Za-z0-9_-]{30,}` matches comfortably.

The full key is in the clipboard, never in the tool return.

---

## Step 6 - Save credentials.json

```bash
$ API_KEY="$(wl-paste | jq -r '.api_key')"
$ # Build credentials.json with atomic write
$ jq -r 'keys | join(",")' ~/.config/klaviyo/credentials.json
api_endpoint,api_key,created_at,key_name,revision,scope
$ stat -c %a ~/.config/klaviyo/credentials.json
600
```

Restore prior clipboard:

```bash
$ base64 -d /tmp/klaviyo-prev-clipboard.b64 | wl-copy
$ rm /tmp/klaviyo-prev-clipboard.b64
```

File shape:

```json
{
  "api_key": "<45-char pk_-prefixed key>",
  "api_endpoint": "https://a.klaviyo.com/api",
  "revision": "2025-10-15",
  "key_name": "Claude Workshop Connector",
  "scope": "Full",
  "created_at": "2026-06-02T06:14:00Z"
}
```

---

## Step 7 - Smoke test (captured 2026-06-02)

```bash
$ API_KEY="$(jq -r .api_key ~/.config/klaviyo/credentials.json)"

$ curl -sf "https://a.klaviyo.com/api/accounts/" \
    -H "Authorization: Klaviyo-API-Key $API_KEY" \
    -H "revision: 2025-10-15" \
    | jq '.data[0] | {id, attributes: {organization_name: .attributes.contact_information.organization_name, timezone: .attributes.timezone, locale: .attributes.locale}}'
{
  "id": "YdTwvt",
  "attributes": {
    "organization_name": "Selrai",
    "timezone": "Asia/Manila",
    "locale": "en-US"
  }
}

$ curl -sf "https://a.klaviyo.com/api/lists?page%5Bsize%5D=5" \
    -H "Authorization: Klaviyo-API-Key $API_KEY" \
    -H "revision: 2025-10-15" \
    | jq '{total: (.data | length), lists: [.data[] | {id, name: .attributes.name}]}'
{
  "total": 3,
  "lists": [
    {"id": "R7YJK8", "name": "Email List"},
    {"id": "SZ3SAZ", "name": "Text Messaging List"},
    {"id": "YhGgM4", "name": "Preview List"}
  ]
}
```

Klaviyo auto-provisions three lists on new accounts (Email List, Text Messaging List, Preview List). All API calls succeeded on first try with the captured `pk_`-prefixed key.

Claude tells the participant:

```
Claude: All connected - your Klaviyo account Selrai is ready with
        3 lists (Email List, Text Messaging List, Preview List). Ask
        me things like 'how many subscribers do I have?' or 'show
        me my top flows by revenue'.
```

---

## Phase 2 sample (immediately after install)

```
Participant: How many subscribers do I have?
Claude:      # Real-data gate: first invocation of session
             kl_get "/accounts/" | jq -r '.data[0].attributes.contact_information.organization_name'
             # → "Reference Run Pty Ltd"
Claude:      Just confirming - you're connected to your real Klaviyo
             account Reference Run Pty Ltd. Anything I do here
             changes your live audience. OK to count subscribers?
Participant: Yes.
Claude:      # Pattern 3 - sum profile_count across lists
             kl_get "/lists?page[size]=20" | jq '[.data[].attributes.profile_count] | add'
             # → 187
Claude:      You have 187 subscribers across your 3 lists.
```

A revenue-focused query (Klaviyo's signature use case):

```
Participant: Top flows by revenue last 30 days.
Claude:      # Pattern 8
             kl_post "/flow-values-reports/" '{"data":{"type":"flow-values-report",...}}'
             # → [{"flow":"Welcome Series", "conversion_value": 4521.30}, ...]
Claude:      Your top 3 flows by revenue (last 30 days):
             1. Welcome Series - $4,521.30
             2. Abandoned Cart - $3,180.75
             3. Post-Purchase - $1,892.40
```

A write would trigger the destructive-op gate:

```
Participant: Suppress noreply@spam.com.
Claude:      I'm about to suppress noreply@spam.com - they won't
             receive any future emails or SMS from you. OK?
Participant: Yes.
Claude:      # Pattern 10
             kl_post "/profile-suppression-bulk-create-jobs/" '...'
             # → 202 accepted
Claude:      Suppressed noreply@spam.com. Klaviyo processes the
             suppression within a few seconds.
```

---

## Captured total timing (2026-06-02)

| Stage | Captured wall-clock |
|---|---|
| Step 0 (credential check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (Playwright navigate + sign-in detect) | ~15 s with cached session; +30 s for cold sign-in including Klaviyo's onboarding-guide redirect |
| Step 3 (direct nav to canonical URL) | ~4 s |
| Step 4 (Create Private API Key click → page nav → fill name + radio + Create) | ~5 s |
| Step 5 (DOM-extract via clipboard transit) | ~1 s |
| Step 6 (credentials.json write + clipboard restore) | ~1 s |
| Step 7 (smoke test: /accounts/ + /lists) | ~2 s |
| **Total technical install (cached sign-in)** | **~25 s** |
| **+ Klaviyo account creation (when fresh)** | ~2-3 min (signup form + email verification - outside SKILL scope) |

---

## Failure modes (captured + anticipated)

| Failure | Captured? | Cause | Fix |
|---|---|---|---|
| `/account#api-keys-tab` URL hash fragment redirects to `/settings/account/api-keys` | **Captured 2026-06-02** | Klaviyo migrated its settings sub-router in 2024-25; the hash-fragment URL is now legacy | **SKILL fix**: navigate to canonical `/settings/account/api-keys` directly. Both URLs still work; the canonical avoids the 302 hop. |
| SKILL prose assumed "Create dialog" / modal flow | **Captured 2026-06-02** | Klaviyo's Create Private API Key is actually a full-page navigation to `/create-private-api-key`, not a modal | **SKILL fix**: Step 4 prose now says "full-page form, NOT a modal"; added `browser_wait_for("New private API key")` between the click and the form fill. |
| Submit button text mismatch | **Captured 2026-06-02** | Real button text is exactly `Create`, NOT `Create Private API Key`/`Generate`/`Save` | **SKILL fix**: regex tightened to `/^create$/i` AND class filter excludes `NavRow-*` (the sidebar Create button) |
| Step 2 `browser_wait_for("Dashboard")` times out | not seen on captured run | Klaviyo's onboarding-guide redirect captures fresh accounts at `/onboarding/guide` not `/dashboard` | Use broader wait-for text or just check `window.location.href` is NOT login |
| Step 5 `{ ok: false }` (no `pk_` match) | not seen | Navigated away from the confirmation page before extract / Klaviyo changed key prefix | Tell participant: "I missed it - let me create another." Re-run Step 4 |
| Step 7 HTTP 400 with `revision` in message | not seen | The `2025-10-15` constant is deprecated | Bump revision string in credentials.json + SKILL helper |
| Step 7 HTTP 403 `insufficient_scope` | not seen | Participant accidentally created Read-only key | Re-run Phase 1 from Step 4, select Full Access Key |

For Phase 2 failures, see the SKILL's Error Handling section.
