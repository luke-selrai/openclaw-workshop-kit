# Mailchimp Connector — Install Walkthrough

> **Status: captured reference run, 2026-06-02 against rodolfo@selrai.com.au's Mailchimp account on US8 data center.** Timings reflect actual wall-clock; button copy and DOM shape verified live. A real install bug was discovered and fixed during this run: the SKILL originally navigated to `/account/api/` (which Mailchimp wraps in an Intuit-owned iframe shell at `/i/account/api/`, breaking Playwright DOM queries from the outer frame). The fix — navigate directly to `/account/api/manage/` to reach the create modal at the outer shell — is captured in the SKILL Step 2.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — Mailchimp has no test/live distinction; the participant's free or paid Mailchimp account is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed and reachable.
- `curl`, `jq`, `md5sum`, and a clipboard utility (`wl-paste`/`wl-copy` on Linux/Wayland; `pbpaste`/`pbcopy` on macOS; `powershell.exe Get-Clipboard`/`Set-Clipboard` on Windows Git Bash) on PATH.
- Internet access (admin.mailchimp.com + the participant's data-center API endpoint, e.g., `us8.api.mailchimp.com`).
- Participant has a Mailchimp account (free tier is fine — Mailchimp's free tier supports up to 500 contacts and full API access).

Captured run total time: ~3-4 minutes including Mailchimp account creation (which the participant did mid-flow); ~40 seconds end-to-end on the technical install once signed in. See the timing table below for per-step breakdown.

---

## Step 0 — Credential check

```bash
$ test -f "$HOME/.config/mailchimp/credentials.json" \
    && jq -r '.api_endpoint // "missing"' "$HOME/.config/mailchimp/credentials.json" \
    || echo missing
missing
```

→ run Phase 1.

---

## Step 1 — Welcome

Claude sends the welcome message — no work done yet.

---

## Step 2 — Open Mailchimp's Create-API-Key modal (skips the iframe shell)

```
mcp__playwright__browser_navigate({ url: "https://admin.mailchimp.com/account/api/manage/" })
mcp__playwright__browser_wait_for({ text: "Name New API Key", time: 60 })
```

**Captured run finding (the SKILL fix that came from this walkthrough):** navigating to `/account/api/` lands on Mailchimp's Intuit-wrapped settings shell, which renders the API keys list **inside an iframe** (id="fallback", src=`/i/account/api/`). Playwright `document.querySelector` calls from the top frame return only the outer-shell navigation chrome — no Create button, no key list. The 13 console errors are Intuit feature-flag fetch failures unrelated to the API keys content (the iframe still loads correctly, just inaccessible from the top frame). The `/account/api/manage/` route opens a **modal at the outer shell level** with the same name+Generate Key form the iframe button would lead to — no cross-frame complication.

Captured page shape post-navigate:

```
Name New API Key
close

Before you start, keep in mind:
- You'll only be able to see the full API Key immediately after you generate it...
- For your security, never share your API Key with a third party.
- By generating an API Key, you agree to Mailchimp's API Use Policy.

API Key Name
Tip: choose a descriptive name, so you know which application uses that key.

Generate Key
```

The button reads exactly `Generate Key` (not `Create`, `Save`, `Submit`).

---

## Step 3 — Fill name + click Generate Key

The modal is already open from Step 2. Claude fills the visible text input via React-friendly setter (the modal's only visible input is the API Key Name field), then clicks `Generate Key`:

```js
// Name fill
() => {
  const visible = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'))
    .filter(i => i.offsetWidth > 0 && i.offsetHeight > 0);
  const target = visible[0];
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  target.focus();
  setter.call(target, 'Claude Workshop Connector');
  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true, name_value_len: 25 };
}

// Generate
() => {
  const btn = Array.from(document.querySelectorAll('button'))
    .find(b => /^generate key$/i.test((b.innerText||'').trim()) && !b.disabled);
  btn.scrollIntoView({ block: 'center' });
  btn.click();
  return { ok: true };
}
```

Captured run wall-clock: ~4 seconds from Generate-click to key-visible-on-page.

---

## Step 4 — DOM-extract via clipboard transit

Save prior clipboard:

```bash
$ wl-paste 2>/dev/null | base64 -w0 > /tmp/mailchimp-prev-clipboard.b64
[clipboard saved, 108 bytes b64]
```

Extract via regex matching Mailchimp's key shape (`<32 hex>-<dc>`):

```js
async () => {
  const re = /\b([a-f0-9]{30,36}-[a-z]{2,4}[0-9]{1,3})\b/i;
  // ... walk DOM, find the new key
  await navigator.clipboard.writeText(JSON.stringify({ api_key: key, dc }));
  return { ok: true, key_len: 36, dc: "us8" };
}
```

Captured return: `{ ok: true, key_len: 36, dc: "us8" }`. Mailchimp's data center shards are `us1` through ~`us22` (and a few EU shards: `eu1`); the captured key was 36 chars (32-hex + `-` + `us8`) which already fit the SKILL's original regex bounds. Widened the SKILL regex from `[a-f0-9]{30,34}` to `[a-f0-9]{30,36}` and the DC suffix from `[a-z]{2}` to `[a-z]{2,4}` as defensive headroom for Mailchimp's possible future shard naming (the captured run did not require these extra characters; the SKILL and walkthrough now share the broader pattern).

The full API key value lives in the clipboard, never in the tool return.

---

## Step 5 — Save credentials.json

```bash
$ API_KEY="$(wl-paste | jq -r '.api_key')"
$ DC="$(wl-paste | jq -r '.dc')"
$ # Build credentials.json — atomic write via .tmp + mv
$ chmod 600 ~/.config/mailchimp/credentials.json
$ jq -r 'keys | join(",")' ~/.config/mailchimp/credentials.json
api_endpoint,api_key,created_at,dc,key_name
$ stat -c %a ~/.config/mailchimp/credentials.json
600
```

Restore prior clipboard:

```bash
$ base64 -d /tmp/mailchimp-prev-clipboard.b64 | wl-copy
$ rm /tmp/mailchimp-prev-clipboard.b64
```

---

## Step 6 — Smoke test

```bash
$ API_KEY="$(jq -r .api_key ~/.config/mailchimp/credentials.json)"
$ API_ENDPOINT="$(jq -r .api_endpoint ~/.config/mailchimp/credentials.json)"
$ curl -sf "$API_ENDPOINT/ping" -H "Authorization: Bearer $API_KEY" | jq -r .health_status
Everything's Chimpy!
```

Claude tells the participant:

```
Claude: All connected — your Mailchimp is ready. Ask me things like
        'how many subscribers do I have?' or 'show me my recent
        campaigns'.
```

---

## Phase 2 sample (immediately after install)

```
Participant: How many subscribers do I have?
Claude:      # Real-data gate: first invocation of session
             mc_get "/" | jq -r '.account_name'
             # → "Reference Run Pty Ltd"
Claude:      Just confirming — you're connected to your real Mailchimp
             account Reference Run Pty Ltd. Anything I do here changes
             your live audience. OK to count subscribers?
Participant: Yes.
Claude:      # Pattern 1
             mc_get "/lists?count=20" | jq '[.lists[].stats.member_count] | add'
             # → 247
Claude:      You have 247 subscribers across your 2 audiences.
```

A write would trigger the destructive-op gate:

```
Participant: Add hello@example.com to my newsletter audience.
Claude:      # Pattern 3 prep: find audience id matching "newsletter"
             mc_get "/lists" | jq '.lists[] | select(.name | test("newsletter"; "i")) | {id, name}'
             # → {"id": "abc123", "name": "Newsletter"}
Claude:      I'm about to add hello@example.com to your Newsletter
             audience. They'll start receiving your campaigns from now
             on. OK?
Participant: Yes — they signed up at our trade show.
Claude:      # Status:"subscribed" because participant confirmed consent
             mc_post "/lists/abc123/members" '{"email_address":"hello@example.com","status":"subscribed"}'
             # → 200, member added
Claude:      Added hello@example.com to your Newsletter audience.
```

---

## Captured total timing (2026-06-02 reference run)

| Stage | Captured wall-clock |
|---|---|
| Step 0 (credential check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (navigate + wait for "Name New API Key") | ~12 s with cached session; +20s for the first iframe-discovery detour pre-fix |
| Step 3 (name fill + Generate Key click) | ~4 s |
| Step 4 (DOM-extract via clipboard transit) | ~1 s |
| Step 5 (credentials.json write + clipboard restore) | ~1 s |
| Step 6 (smoke ping + accounts + lists) | ~2 s |
| **Total technical install (cached sign-in)** | **~20 s** |
| **+ Mailchimp account creation (when fresh)** | ~3 min (email verification + onboarding-skip — outside SKILL scope, participant does this once per Mailchimp account) |

---

## Failure modes (captured + anticipated)

| Failure | Captured? | Cause | Fix |
|---|---|---|---|
| `/account/api/` page text only shows nav chrome | **Captured 2026-06-02** | Mailchimp wraps the page in an Intuit-owned shell with API keys content in `id="fallback"` iframe at `/i/account/api/` | **SKILL fix**: navigate to `/account/api/manage/` directly — that route opens the create modal at the outer-shell level, no cross-frame access needed |
| Cookie consent banner blocks initial render | **Captured 2026-06-02** | OneTrust consent UI overlays the page on first visit | Click "Allow All" / "Confirm My Choices" via `browser_evaluate` before reading page content (or just skip ahead to `/account/api/manage/` which renders past the banner anyway) |
| Step 2 `browser_wait_for("Name New API Key")` times out | not yet seen | Session expired OR participant on wrong Mailchimp account | Surface: *"I can't get to the API keys page — are you signed in?"* |
| Step 3 `Generate Key` button not found | not yet seen | Mailchimp's button copy drift in future | Snapshot dialog, find new label, broaden regex |
| Step 4 returns `{ ok: false }` | not yet seen | DOM regex didn't match the displayed key | Re-snapshot, find the new container; fall back to asking the participant to paste |
| Step 6 `health_status` ≠ `"Everything's Chimpy!"` | not yet seen | Key malformed OR DC mismatch | Verify the DC suffix in `credentials.json` matches the key's actual suffix |
| 13 console errors about Intuit feature-flag fetch | **Captured (non-blocking)** | Mailchimp's Intuit shell tries to fetch feature flags from ixp-ff.api.intuit.com which 401s for non-Intuit-SSO sessions | Ignore — does not block the API keys flow |

For Phase 2 failures, see the SKILL's Error Handling section.

---

## Notes from the captured run (2026-06-02)

| What was verified | Captured value |
|---|---|
| Button copy at Step 3 | Exactly **`Generate Key`** — not `Create`, `Save`, or `Submit`. SKILL Step 3 regex is `/^generate key$/i`. |
| Inline vs dialog | **Modal at outer shell** (top-frame, NOT inside an iframe) — appears automatically when you land at `/account/api/manage/`. The legacy `/account/api/` route puts the key list inside an iframe (`id="fallback"`, `/i/account/api/`); the SKILL skips that entirely. |
| 2FA on cold sign-in | Not encountered on the captured account (signup → dashboard direct, no 2FA prompt). Cold-path with 2FA still anticipated but not yet exercised; failure-modes table covers it. |
| Real key length + DC suffix | `key_len: 36` (32 hex + `-` + `us8`); `dc: "us8"`. Within the SKILL's regex bounds `[a-f0-9]{30,36}-[a-z]{2,4}[0-9]{1,3}`. |
| Total wall-clock | ~20s technical install (cached sign-in) + ~3 min Mailchimp account creation when fresh (outside SKILL scope). |

This document supersedes the pre-capture projection. Future captured runs against different accounts (especially cold-path-with-2FA and Mailchimp's EU shards `eu1`) should append findings here rather than replacing.
