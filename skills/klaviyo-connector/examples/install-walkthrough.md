# Klaviyo Connector — Install Walkthrough

> **Status: illustrative, not yet captured.** Authored from the SKILL design + Klaviyo's documented help articles without an end-to-end run against a real Klaviyo account. Specific button copy, DOM structures, and exact key-display widget layout below are projected from Klaviyo's documented UX (help.klaviyo.com/hc/en-us/articles/7423954176283) at design time; the walkthrough will be replaced with a captured reference run once smoke is performed against an actual Klaviyo account.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — Klaviyo's free tier IS real data (up to 250 profiles, 500 sends/month); the participant's free or paid Klaviyo account is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed.
- `curl`, `jq`, and a clipboard utility (`wl-paste`/`wl-copy` on Linux/Wayland; `pbpaste`/`pbcopy` on macOS; `powershell.exe Get-Clipboard`/`Set-Clipboard` on Windows Git Bash) on PATH.
- Internet access (www.klaviyo.com + a.klaviyo.com).
- Participant has a Klaviyo account (free tier is fine).

Projected total: ~45 seconds for an account with a cached sign-in cookie; ~90 seconds for cold sign-in including the 2FA / email verification Klaviyo enforces on first new-device login.

---

## Step 0 — Credential check

```bash
$ test -f "$HOME/.config/klaviyo/credentials.json" \
    && jq -r '.api_endpoint // "missing"' "$HOME/.config/klaviyo/credentials.json" \
    || echo missing
missing
```

→ run Phase 1.

---

## Step 1 — Welcome

Claude sends the welcome message.

---

## Step 2 — Sign in to Klaviyo

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/login" })
mcp__playwright__browser_wait_for({ text: "Dashboard", time: 60 })
```

Projected: participant signs in (or session is still active from a prior workshop step). The Dashboard renders.

Klaviyo's first-new-device sign-in flow includes an emailed verification code or 2FA prompt. The `browser_wait_for` polls past it; if it times out, prompt the participant: *"I'm waiting on Klaviyo's verification code — check your email and approve."*

---

## Step 3 — Navigate to API keys

Projected: Claude clicks the organization-name dropdown in the top-right corner via `browser_evaluate`, then clicks **Settings** in the dropdown menu, then clicks the **API keys** tab on the Settings page.

Fallback if any selector fails: navigate directly to `https://www.klaviyo.com/account#api-keys-tab` (a stable Klaviyo URL anchor).

---

## Step 4 — Create the Private API Key

Reference page state: API keys tab shows existing keys (typically empty for fresh accounts) + a **Create Private API Key** button.

Claude clicks Create. A dialog opens with:

- **Name** input → Claude fills `Claude Workshop Connector` via React-friendly setter.
- **Scope** selector with radio cards: `Read-only` / `Full` / `Custom`. Claude clicks **Full**.

Claude clicks the dialog's **Create** button. Klaviyo generates the key and displays it in a follow-up modal — this is the one-and-only chance to capture it.

Projected wall-clock: ~12 seconds (form fill + submit + Klaviyo server-side key generation).

---

## Step 5 — DOM-extract via clipboard transit

Save prior clipboard:

```bash
$ wl-paste 2>/dev/null | base64 -w0 > /tmp/klaviyo-prev-clipboard.b64
```

Extract:

```js
async () => {
  const re = /\bpk_[A-Za-z0-9_-]{30,}\b/;
  // ... walk DOM, find the new key (starts with pk_, ~40-50 chars)
  await navigator.clipboard.writeText(JSON.stringify({ api_key: key }));
  return { ok: true, key_len: 45 };
}
```

Projected return: `{ ok: true, key_len: 45 }` (Klaviyo Private Keys typically 40-50 chars including the `pk_` prefix).

The full key is in the clipboard, never in the tool return.

---

## Step 6 — Save credentials.json

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

## Step 7 — Smoke test

```bash
$ curl -sf "https://a.klaviyo.com/api/accounts/" \
    -H "Authorization: Klaviyo-API-Key <key>" \
    -H "revision: 2025-10-15" \
    | jq -r '.data[0].attributes.contact_information.organization_name'
Reference Run Pty Ltd
```

Claude tells the participant:

```
Claude: All connected — your Klaviyo account Reference Run Pty Ltd
        is ready. Ask me things like 'how many subscribers do I
        have?' or 'show me my top flows by revenue'.
```

---

## Phase 2 sample (immediately after install)

```
Participant: How many subscribers do I have?
Claude:      # Real-data gate: first invocation of session
             kl_get "/accounts/" | jq -r '.data[0].attributes.contact_information.organization_name'
             # → "Reference Run Pty Ltd"
Claude:      Just confirming — you're connected to your real Klaviyo
             account Reference Run Pty Ltd. Anything I do here
             changes your live audience. OK to count subscribers?
Participant: Yes.
Claude:      # Pattern 3 — sum profile_count across lists
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
             1. Welcome Series — $4,521.30
             2. Abandoned Cart — $3,180.75
             3. Post-Purchase — $1,892.40
```

A write would trigger the destructive-op gate:

```
Participant: Suppress noreply@spam.com.
Claude:      I'm about to suppress noreply@spam.com — they won't
             receive any future emails or SMS from you. OK?
Participant: Yes.
Claude:      # Pattern 10
             kl_post "/profile-suppression-bulk-create-jobs/" '...'
             # → 202 accepted
Claude:      Suppressed noreply@spam.com. Klaviyo processes the
             suppression within a few seconds.
```

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (credential check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (Playwright navigate + sign-in detect) | 15 s (cached) / 60 s cold |
| Step 3 (dropdown → Settings → API keys nav) | 10 s |
| Step 4 (Create dialog + fill + Full scope + Create) | 12 s |
| Step 5 (DOM-extract via clipboard transit) | 1 s |
| Step 6 (credentials.json write + clipboard restore) | 0.5 s |
| Step 7 (smoke test) | 1 s |
| **Total** | **~40 s cached / ~85 s cold** |

---

## Failure modes anticipated from design review (will be confirmed on first real smoke)

| Failure | Cause | Fix |
|---|---|---|
| Step 2 `browser_wait_for("Dashboard")` times out | Klaviyo's 2FA / email-verification challenge on cold sign-in | Prompt participant to check email and approve |
| Step 3 dropdown selector returns null | Klaviyo's UI revisions occasionally rename the org-menu button | Snapshot the page, locate the menu by visible text instead of aria-label |
| Step 4 `Full` scope card not found | Klaviyo's scope picker is sometimes a multi-step wizard rather than radios | Snapshot the dialog post-click, find the Full option in whatever shape it takes |
| Step 5 `{ ok: false }` (extract found no `pk_`-prefixed key) | Modal may have closed before extract; or Klaviyo changed key prefix | Tell participant: "I missed it — let me create another." Re-run Step 4. Note new prefix if applicable. |
| Step 7 HTTP 400 with `revision` in message | The `2025-10-15` revision constant is deprecated | Bump revision in credentials.json + the SKILL helper to a newer date |
| Step 7 HTTP 403 `insufficient_scope` | Participant accidentally created Read-only key instead of Full | Re-run Phase 1 from Step 4, explicitly select Full |

For Phase 2 failures, see the SKILL's Error Handling section.
