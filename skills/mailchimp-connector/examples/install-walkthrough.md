# Mailchimp Connector — Install Walkthrough

> **Status: illustrative, not yet captured.** Authored from the SKILL design without an end-to-end run against Mailchimp's live UI. Timings, DOM structures, and key shape examples below are projected from Mailchimp's documented API behaviour and reference patterns at the design time; the walkthrough will be replaced with a real captured run once a smoke test is performed against an actual Mailchimp account.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — Mailchimp has no test/live distinction; the participant's free or paid Mailchimp account is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed and reachable.
- `curl`, `jq`, `md5sum`, and a clipboard utility (`wl-paste`/`wl-copy` on Linux/Wayland; `pbpaste`/`pbcopy` on macOS; `powershell.exe Get-Clipboard`/`Set-Clipboard` on Windows Git Bash) on PATH.
- Internet access (admin.mailchimp.com + the participant's data-center API endpoint, e.g., `us21.api.mailchimp.com`).
- Participant has a Mailchimp account (free tier is fine — Mailchimp's free tier supports up to 500 contacts and full API access).

Projected total time: ~2 minutes for an account that's already signed in (sign-in cookies cached in the Playwright profile); ~3 minutes for cold sign-in including 2FA.

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

## Step 2 — Open Mailchimp API keys page

```
mcp__playwright__browser_navigate({ url: "https://admin.mailchimp.com/account/api/" })
mcp__playwright__browser_wait_for({ text: "API keys", time: 60 })
```

Projected: participant signs in (or session is still active from a prior workshop step). Page renders the API keys settings.

Reference snapshot (illustrative): the page typically shows a section titled "Your API Keys" with a table of existing keys (often empty for fresh accounts) + a `Create A Key` button (or `Create Key` on newer UI revisions).

---

## Step 3 — Create the API key

Claude clicks the create button via `browser_evaluate`:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /^create.*key$/i.test((b.innerText||'').trim()));
  btn.click();
  return { ok: true };
}
```

A dialog opens asking for the key name. Claude fills `Claude Workshop Connector` via the React-friendly setter pattern, then clicks `Create` / `Generate`.

Projected wall-clock: ~3 seconds. Mailchimp generates the key server-side and displays it once on the resulting screen.

---

## Step 4 — DOM-extract via clipboard transit

Save prior clipboard:

```bash
$ wl-paste 2>/dev/null | base64 -w0 > /tmp/mailchimp-prev-clipboard.b64
```

Extract:

```js
async () => {
  const re = /\b([a-f0-9]{30,34}-[a-z]{2}[0-9]{1,3})\b/i;
  // ... walk DOM, find the new key
  await navigator.clipboard.writeText(JSON.stringify({ api_key: key, dc }));
  return { ok: true, key_len: 38, dc: "us21" };
}
```

Projected return: `{ ok: true, key_len: 38, dc: "us21" }`. Key length and dc may vary — Mailchimp's data center shards are `us1` through ~`us22` (and a few EU shards: `eu1`); typical full key length is 36-38 chars.

The full API key value is in the clipboard, never in the tool return.

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

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (credential check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (Playwright navigate + wait for API keys page) | 30 s if signed in / +60 s for cold sign-in |
| Step 3 (Create key dialog + submit) | 8 s |
| Step 4 (DOM-extract via clipboard transit) | 1 s |
| Step 5 (credentials.json write + clipboard restore) | 0.5 s |
| Step 6 (smoke ping) | 1 s |
| **Total** | **~40 s for cached session; ~100 s cold** |

---

## Failure modes anticipated from design review (will be confirmed on first real smoke)

| Failure | Cause | Fix |
|---|---|---|
| Step 2 `browser_wait_for("API keys")` times out | Mailchimp's session is dead OR participant is on a different Mailchimp account that doesn't have admin role | Surface plain English: *"I can't get to the API keys page — are you signed in as an admin on the right Mailchimp account?"* |
| Step 3 dialog doesn't appear after Create button click | Mailchimp's UI variant — newer versions inline the key creation | Snapshot the page, look for an inline form instead of a dialog; same React-friendly setter pattern works |
| Step 4 returns `{ ok: false }` | DOM extraction regex didn't match — Mailchimp may have changed the key-display widget | Re-snapshot, look for the new container; fall back to asking the participant to paste the key |
| Step 6 `health_status` is not "Everything's Chimpy!" | Key was malformed OR data center mismatch | Verify the DC suffix in `credentials.json` matches the API key's actual suffix |
| Step 2 prompts for 2FA | First sign-in or new device | Tell the participant to approve the 2FA prompt on their phone, then `browser_wait_for` resumes |

For Phase 2 failures, see the SKILL's Error Handling section.

---

## Notes for the smoke runner

When the first real smoke is run, capture:

1. **Exact button copy** at Step 3 (`Create A Key` vs `Create Key` vs `Create new key` vs something else).
2. **Whether the key appears in a dialog or inline** at Step 3.
3. **Whether Mailchimp triggers 2FA** for cold sign-in (Reference Run testing should use a fresh Playwright profile, not the persistent one used by other workshop connectors, to exercise the cold path).
4. **Real key length and DC suffix** to confirm the regex `[a-f0-9]{30,34}-[a-z]{2}[0-9]{1,3}` matches Mailchimp's current format.
5. **Total wall-clock** to compare against the projection above.

The captured run replaces this document.
