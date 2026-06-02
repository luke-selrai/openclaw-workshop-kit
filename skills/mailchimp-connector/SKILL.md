---
name: mailchimp-connector
description: "Connect and operate Mailchimp (read audiences/lists, members/subscribers, campaigns, automations, recent reports; add/tag subscribers; send campaigns; unsubscribe members) via direct REST against Mailchimp Marketing API v3. Single-mode connector — Mailchimp's free tier IS real data (up to 500 contacts), no test vs live distinction; every operation hits the participant's real audience. Phase 1 drives admin.mailchimp.com inside a Playwright MCP browser to generate an API key from the API keys settings page, parses the data center suffix (e.g., 'us21' in `abc123-us21`) which determines the per-account API base URL, and persists tokens at ~/.config/mailchimp/credentials.json (mode 0600). API keys don't expire, so there's no refresh token cycle. Use this skill when the user asks about their Mailchimp audiences, subscribers, campaigns, email lists, or says 'connect Mailchimp', 'set up Mailchimp', 'add a subscriber', 'send my newsletter', or asks about email-marketing reports (opens, clicks, growth). OAuth2 (preferred for production apps) is documented as advanced alternative but Phase 1 defaults to the API-key path because it's a single ~30 second flow vs OAuth2's app-registration + consent flow. On the first use of any Mailchimp feature, run Phase 1 before attempting any tool call."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - mailchimp
    - email-marketing
    - audiences
    - subscribers
    - campaigns
    - reports
    - rest-api
  pairs-with:
    - skill: myob-connector
      reason: Reference SKILL for the Direct-REST + Playwright pattern (atomic credentials.json write, bearer-on-curl Phase 2, single-mode no test/live split)
    - skill: quickbooks-connector
      reason: Sibling Playwright-driven autonomous Phase 1 connector (different vendor, different auth shape). Same plain-language communication rules; same per-write confirmation prose for production-mode operations.
    - skill: google-ads-connector
      reason: Sibling Tier-1 Direct-REST connector. Different complexity (Mailchimp is single-mode, Google Ads has test vs Basic Access modes), same workshop UX rules.
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting Mailchimp API errors or unexpected response shapes
---

# Mailchimp Connector

## Overview

This skill lets you read and operate a user's Mailchimp account on their behalf using **Mailchimp Marketing API v3** (no MCP server, no first-party CLI — Direct-REST + Playwright pattern). `skills/CLAUDE.md` documents the three install patterns (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace) and marks direct-REST connectors as out-of-scope for that doc; this SKILL follows the `myob-connector` shape (loopback listener for OAuth — or in our case API-key clipboard transit — plus atomic `credentials.json` write).

It has two phases:

- **Phase 1 — Install & Connect (autonomous via Playwright).** Claude drives `admin.mailchimp.com` end-to-end via Playwright MCP to sign the participant in, generate a new API key from the API keys settings page, DOM-extracts the key via the clipboard-transit pattern (key never appears in tool returns), parses the data-center suffix from the key (Mailchimp API keys have the form `<32-char-token>-<dc>` e.g., `abc123def...-us21`), constructs the participant's account-specific API endpoint URL (`https://<dc>.api.mailchimp.com/3.0/`), and persists everything to `~/.config/mailchimp/credentials.json` (mode 0600). The participant's only manual moment is signing in to Mailchimp once and approving any 2FA.
- **Phase 2 — Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Mailchimp REST endpoints with `Authorization: Bearer <api_key>`. Endpoints span audiences (`lists`), members, campaigns, reports, automations, and search. Writes (add subscriber, send campaign, unsubscribe member) are gated by plain-English confirmation prose — every Phase 2 operation hits real data (Mailchimp has no sandbox), so the gates apply unconditionally.

**Single-mode, no test/live distinction.** Mailchimp's free tier (up to 500 contacts) IS real data — there's no separate "test mode" or sandbox API. Every Phase 2 invocation touches the participant's real audience. The production-mode gates from QBO and Google Ads are the default behaviour here, not opt-in.

**API keys don't expire.** Mailchimp API keys are revocable but not time-bounded, so there's no refresh-token cycle in Phase 2. The only auth failure path is "key revoked" (HTTP 401 with `RevokedKey` in the message), which triggers re-running Phase 1 from Step 2.

**Which phase to run** — Before any tool call, check whether the credentials file exists:

```bash
test -f "$HOME/.config/mailchimp/credentials.json" && jq -r '.api_endpoint // "missing"' "$HOME/.config/mailchimp/credentials.json" 2>/dev/null || echo missing
```

- Output starts with `https://` → credentials present. Smoke-test with `GET /ping`; on success → Phase 2.
- Output `missing` → run Phase 1.

---

## Golden rule — do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside the Playwright MCP browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the participant to "open a link in your browser." Claude navigates, the participant types their Mailchimp password directly into the Playwright window, Claude reads the result programmatically. Same rule as `myob-connector` and `quickbooks-connector`.

If Playwright MCP is unavailable, stop and tell the participant: *"I need a small browser tool that's not installed yet — let me show you how to add it."* Then point them at the Playwright MCP install instructions and stop. Do not fall back to opening the participant's default browser.

---

## Communication rules for Phase 1

The participant is a non-technical business owner. Every message during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions.
- **Plain English only.** Never say API key, OAuth, token, scope, refresh, Bearer, REST, endpoint, JSON, data center, env var, curl, terminal, CLI, MCP, callback, loopback, sandbox, file path, or `dc` shorthand. If you must refer to a technical thing, name it plainly: "your connection key", "your Mailchimp account details", "the workshop setup step".
- **Tell them what is about to happen.** *"I'm opening Mailchimp's settings now — sign in when you see the page, and I'll do the rest. About a minute."*
- **React warmly.** Good: *"Got it — connected to your **[Audience Name]** audience."* Bad: *"Mailchimp returned 200 with valid api_endpoint; credentials.json written mode 0600."*
- **Never show error messages directly.** Translate. *"No problem — let me try a different way,"* then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the participant. You run them.
- **Never echo the API key** back to the participant — it's stored locally and never shown.

---

## ⛔ Pre-flight check — Playwright availability

Before any Phase 0 step, verify Playwright MCP tools are available. If `mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` tools are not in the deferred-tool surface (check via `ToolSearch +playwright`), halt and tell the participant to install Playwright MCP per `skills/CLAUDE.md`'s install contingency section. Do not start Phase 0 or Phase 1 without Playwright.

---

## PHASE 0 — Credential check

### Step 0.1 — Read existing credentials

```bash
CREDS="$HOME/.config/mailchimp/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.api_endpoint // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

Two states:

- **`missing`** → run Phase 1.
- **Anything starting with `https://`** → smoke-test (`GET /ping`) and:
  - 200 → Phase 2.
  - 401 → key revoked or invalid; tell the participant *"Looks like the connection was disconnected — let me set up a new one."* and re-run Phase 1.
  - Other error → translate and diagnose silently.

---

## PHASE 1 — Install & Connect (autonomous via Playwright)

### Step 1 — Welcome message

Send one short message:

> "Great — connecting your Mailchimp. I'll open Mailchimp's settings in a small browser window. Please sign in (and approve any verification code Mailchimp sends to your phone or email) — I'll do the rest. About a minute."

### Step 2 — Open Mailchimp API keys page

```
mcp__playwright__browser_navigate({ url: "https://admin.mailchimp.com/account/api/" })
```

**Do NOT snapshot the sign-in page** (password-leak risk — see `reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "API keys", time: 60 })
```

If the participant has multiple Mailchimp accounts on their Google sign-on, Mailchimp may present an account-chooser before the API keys page renders. Wait for `API keys` to appear; if the participant gets stuck on the chooser, check in: *"Which Mailchimp account should I connect to?"* and wait for their reply.

### Step 3 — Generate a new API key

The API keys page lists existing keys (if any) plus a `Create A Key` button (variants: "Create Key", "Create new key" — Mailchimp's button copy changes over time, so match by intent not exact text).

Click the create button via `browser_evaluate`:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /^create.*key$/i.test((b.innerText||'').trim()));
  if (!btn) return { ok: false, reason: 'no_create_button' };
  btn.scrollIntoView({ block: 'center' });
  btn.click();
  return { ok: true };
}
```

Mailchimp typically opens a small dialog asking for a key name. Fill `Claude Workshop Connector`:

```js
() => {
  // Find the visible name input in the create-key dialog
  const inputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'));
  const target = inputs.find(i => {
    const aria = (i.getAttribute('aria-label') || '').toLowerCase();
    const placeholder = (i.placeholder || '').toLowerCase();
    return /name|label|key name/.test(aria + placeholder);
  });
  if (!target) return { ok: false };
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  target.focus();
  setter.call(target, 'Claude Workshop Connector');
  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true };
}
```

Then click the dialog's submit button (`Create`, `Generate`, `Save`):

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^(create|generate|save)$/i.test((b.innerText||'').trim()) && !b.disabled);
  if (!btn) return { ok: false };
  btn.click();
  return { ok: true };
}
```

Mailchimp shows the key value ONCE on the post-create screen — the same key is never displayed again after the page is reloaded. Phase 1 captures it in Step 4 below before any navigation away.

### Step 4 — DOM-extract the API key via clipboard transit

Before extracting, save the participant's existing clipboard so it can be restored after Step 6:

```bash
SAVED=$(wl-paste 2>/dev/null | base64 -w0)
echo "$SAVED" > /tmp/mailchimp-prev-clipboard.b64
```

(`wl-paste` on Linux/Wayland; `pbpaste` on macOS; `powershell.exe Get-Clipboard` on Windows Git Bash — detect at runtime.)

Then extract:

```js
async () => {
  // Find any element whose visible text matches Mailchimp's API-key shape: 32 hex chars + '-' + dc prefix
  const re = /\b([a-f0-9]{30,34}-[a-z]{2}[0-9]{1,3})\b/i;
  const all = Array.from(document.querySelectorAll('input, code, span, div, p, pre'));
  for (const el of all) {
    const v = (el.value || el.innerText || el.textContent || '').trim();
    const match = v.match(re);
    if (match) {
      const key = match[1];
      const dc = key.split('-').pop();
      await navigator.clipboard.writeText(JSON.stringify({ api_key: key, dc }));
      return { ok: true, key_len: key.length, dc };
    }
  }
  return { ok: false };
}
```

Return values: only `key_len` and `dc` (the data-center prefix is not sensitive — it's a public Mailchimp shard identifier like `us21`). The full API key value is in the clipboard and never appears in the tool return.

**Validation (silent):** key is typically 36-38 chars total (32 hex + `-` + 2-4 char dc), all lowercase. If the extract returns `{ ok: false }`, re-snapshot the page and look for a different display widget; fall back to asking the participant: *"I'm having trouble reading your new key — could you paste it for me?"* The key transits the transcript in this fallback path; that's an accepted tradeoff if DOM extraction fails.

### Step 5 — Save `credentials.json`

```bash
mkdir -p "$HOME/.config/mailchimp"
chmod 700 "$HOME/.config/mailchimp"
umask 077

API_KEY="$(wl-paste | jq -r '.api_key')"
DC="$(wl-paste | jq -r '.dc')"
API_ENDPOINT="https://${DC}.api.mailchimp.com/3.0"

jq -n \
  --arg key "$API_KEY" \
  --arg dc "$DC" \
  --arg ep "$API_ENDPOINT" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{api_key:$key, dc:$dc, api_endpoint:$ep, key_name:"Claude Workshop Connector", created_at:$created}' \
  > "$HOME/.config/mailchimp/credentials.json.tmp"
chmod 600 "$HOME/.config/mailchimp/credentials.json.tmp"
mv "$HOME/.config/mailchimp/credentials.json.tmp" "$HOME/.config/mailchimp/credentials.json"

# Restore prior clipboard
if [ -s /tmp/mailchimp-prev-clipboard.b64 ]; then
  base64 -d /tmp/mailchimp-prev-clipboard.b64 | wl-copy
fi
rm -f /tmp/mailchimp-prev-clipboard.b64

unset API_KEY DC API_ENDPOINT
```

Verify the file shape:

```bash
jq -r 'keys | join(",")' "$HOME/.config/mailchimp/credentials.json"
# expect: api_endpoint,api_key,created_at,dc,key_name
```

### Step 6 — Smoke test

```bash
API_KEY="$(jq -r .api_key "$HOME/.config/mailchimp/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/mailchimp/credentials.json")"

curl -sf "$API_ENDPOINT/ping" \
  -H "Authorization: Bearer $API_KEY" \
  | jq -r '.health_status'
```

Expect: `"Everything's Chimpy!"`. On success, tell the participant:

> "All connected — your Mailchimp is ready. Ask me things like *'how many subscribers do I have?'* or *'show me my recent campaigns'*."

If the smoke fails (HTTP 401 or non-200), translate to plain English and re-check Steps 3–5 silently.

---

## PHASE 2 — Use Tools

Phase 2 runs after Phase 1 completes. Every call reads `~/.config/mailchimp/credentials.json` for `api_key` + `api_endpoint`, then `curl`s the Mailchimp REST API.

### Helper — base curl shape

```bash
mc_get() {
  local path="$1"
  curl -sf "$API_ENDPOINT$path" -H "Authorization: Bearer $API_KEY"
}
mc_post() {
  local path="$1"; local body="$2"
  curl -sf -X POST "$API_ENDPOINT$path" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body"
}
mc_patch() {
  local path="$1"; local body="$2"
  curl -sf -X PATCH "$API_ENDPOINT$path" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$body"
}
```

### Real-data gate — soft confirmation on first invocation

On the first Phase 2 tool call of a session, run:

```bash
mc_get "/" | jq -r '.account_name'
```

(The Mailchimp root endpoint returns the account name and ID — quick identity check.)

Tell the participant:

> "Just confirming — you're connected to your real Mailchimp account **[account_name]**. Anything I do here changes your live audience. OK to proceed with **[summary of what they asked]**?"

Wait for OK. Apply ONCE per session, not per tool call.

### Destructive-op gate — confirm every write

For Patterns 3, 4, 9, and 10 below (add subscriber, tag, send campaign, unsubscribe), confirm in plain English BEFORE the API call:

| Operation | Prompt |
|---|---|
| Add subscriber | "I'm about to add **[email]** to your **[Audience]** audience. They'll start receiving your campaigns from now on. OK?" |
| Tag subscriber | "I'm about to tag **[email]** with **[tag]** in your **[Audience]** audience. OK?" |
| Send campaign | "I'm about to **send** campaign **[Subject Line]** to **[N]** people in **[Audience]**. This is irreversible — once sent, those emails are out. Are you sure?" |
| Unsubscribe member | "I'm about to unsubscribe **[email]** from your **[Audience]** audience. They won't receive future campaigns until they opt back in. OK?" |

Per-write call, not per-session.

### Common Pattern 1 — List audiences

```bash
mc_get "/lists?count=20" | jq '.lists[] | {id, name, stats: {member_count: .stats.member_count, unsubscribe_count: .stats.unsubscribe_count}}'
```

Returns audience id, name, current subscriber count, total unsubscribes. Present as a simple list.

**Use when:** "what audiences do I have?", "list my lists", "show audiences"

### Common Pattern 2 — List subscribers in an audience

```bash
LIST_ID="<from Pattern 1>"
mc_get "/lists/$LIST_ID/members?count=50&status=subscribed" | jq '.members[] | {email_address, status, timestamp_signup}'
```

Returns email, status, signup date. Filter `status=subscribed` to skip unsubscribed/cleaned. Use `count=` up to 1000.

**Use when:** "show my subscribers", "list everyone in [audience]"

### Common Pattern 3 — Add a subscriber (write, gated)

Apply the **Add subscriber** gate first, then:

```bash
LIST_ID="<from Pattern 1>"
EMAIL="<email>"
FNAME="<first name optional>"
LNAME="<last name optional>"

mc_post "/lists/$LIST_ID/members" "$(jq -n \
  --arg em "$EMAIL" --arg fn "$FNAME" --arg ln "$LNAME" \
  '{email_address:$em, status:"subscribed", merge_fields:{FNAME:$fn, LNAME:$ln}}')"
```

Response includes the new member id + `subscriber_hash` (the MD5 of the lowercased email — used in subsequent member-specific URLs). Tell the participant: *"Added **[email]** to your **[Audience]**."*

> **Compliance note**: setting `status:"subscribed"` skips the double-opt-in flow. Mailchimp's terms require explicit consent for that — if the participant is adding someone from a manual signup form they themselves received, this is fine. If they're adding someone whose consent they don't have, use `status:"pending"` instead (Mailchimp sends a confirmation email). When in doubt, use `pending`.

**Use when:** "add [email]", "subscribe [email]", "add [name] to my audience"

### Common Pattern 4 — Tag a subscriber (write, gated)

Apply the **Tag subscriber** gate first. Compute the subscriber hash:

```bash
EMAIL="<email>"
HASH="$(echo -n "${EMAIL,,}" | md5sum | awk '{print $1}')"
mc_post "/lists/$LIST_ID/members/$HASH/tags" "$(jq -n --arg t "$TAG" '{tags:[{name:$t, status:"active"}]}')"
```

To remove a tag, set `status:"inactive"`.

**Use when:** "tag [email] as [tag]", "add tag X to [email]"

### Common Pattern 5 — Audience growth stats

```bash
LIST_ID="<from Pattern 1>"
mc_get "/lists/$LIST_ID/growth-history?count=12" | jq '.history[] | {month, existing, imports, optins, optouts}'
```

Returns the last 12 months of: existing subscribers at month-start, new imports, opt-ins, opt-outs. Present as a monthly trend.

**Use when:** "audience growth", "subscriber trend", "is my list growing?"

### Common Pattern 6 — List recent campaigns

```bash
mc_get "/campaigns?count=20&sort_field=send_time&sort_dir=DESC&status=sent" | jq '.campaigns[] | {id, settings: {subject_line: .settings.subject_line}, send_time, emails_sent}'
```

Returns campaign id, subject line, send time, emails sent. Filter `status=sent` to skip drafts.

**Use when:** "my campaigns", "recent campaigns", "what newsletters have I sent?"

### Common Pattern 7 — Campaign performance report

```bash
CAMPAIGN_ID="<from Pattern 6>"
mc_get "/reports/$CAMPAIGN_ID" | jq '{emails_sent, opens: .opens.unique_opens, open_rate: .opens.open_rate, clicks: .clicks.unique_clicks, click_rate: .clicks.click_rate, unsubscribed}'
```

Returns sends, unique opens, open rate, unique clicks, click rate, unsubscribes. Present as a table.

**Use when:** "how did [campaign] do?", "open rate for [campaign]", "campaign performance"

### Common Pattern 8 — Search for a subscriber by email

```bash
EMAIL="<email>"
mc_get "/search-members?query=$EMAIL" | jq '.exact_matches.members[] | {id, list: .list_id, email_address, status}'
```

Returns all audiences the email appears in. Useful for "where is [email] subscribed?"

**Use when:** "find [email]", "where is [email] subscribed?", "look up [email]"

### Common Pattern 9 — Send a campaign (write, gated, IRREVERSIBLE)

Apply the **Send campaign** gate first. The participant must have already drafted the campaign in Mailchimp's web UI — this SKILL doesn't compose campaigns from scratch (the templating + rich-content surface is too complex for v1).

```bash
CAMPAIGN_ID="<from Pattern 6 (filter status='save' for drafts)>"
mc_post "/campaigns/$CAMPAIGN_ID/actions/send" ""
```

Empty body. Response is empty 204 on success.

Tell the participant: *"**[Subject]** is now sending to **[N]** subscribers. You'll see open/click numbers within an hour or two."* — never imply the campaign is "delivered" instantly (Mailchimp queues sends in waves).

**Use when:** "send [campaign]", "send the newsletter"

### Common Pattern 10 — Unsubscribe a member (write, gated)

Apply the **Unsubscribe member** gate first.

```bash
EMAIL="<email>"
HASH="$(echo -n "${EMAIL,,}" | md5sum | awk '{print $1}')"
mc_patch "/lists/$LIST_ID/members/$HASH" '{"status":"unsubscribed"}'
```

The member is moved to unsubscribed status (not deleted). They won't receive future campaigns until they manually opt back in via a signup form.

**Use when:** "unsubscribe [email]", "remove [email] from my list", "[email] asked to be unsubscribed"

> **Compliance reminder**: in many jurisdictions, an unsubscribe request from the subscriber themselves must be processed within a regulatory window (US: CAN-SPAM 10 business days; EU: GDPR "without undue delay"). When the participant's own customer asks to be removed, prioritise this operation.

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "List my audiences" / "What audiences do I have?" | Pattern 1 |
| "Show my subscribers" / "Who's in [audience]?" | Pattern 2 |
| "Add [email] to my audience" / "Subscribe [email]" | Pattern 3 (gated) |
| "Tag [email] as [tag]" | Pattern 4 (gated) |
| "Audience growth" / "Is my list growing?" | Pattern 5 |
| "Recent campaigns" / "My newsletters" | Pattern 6 |
| "Campaign report for X" / "How did X do?" | Pattern 7 |
| "Find [email]" / "Look up [email]" | Pattern 8 |
| "Send [campaign]" / "Send the newsletter" | Pattern 9 (gated, irreversible) |
| "Unsubscribe [email]" / "Remove [email]" | Pattern 10 (gated) |
| "How many subscribers do I have?" | Pattern 1 (sum `stats.member_count` across audiences) |
| "Connect my Mailchimp" / "Help me set up Mailchimp" | **Run Phase 1** |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `Your API Key may be invalid` | Key revoked from admin.mailchimp.com or wrong DC suffix | Tell the participant *"Looks like the connection was disconnected — let me set up a new one."* Re-run Phase 1. |
| HTTP 401 `RevokedKey` | Key explicitly revoked | Same as above. |
| HTTP 403 `User does not have access` | Account-level permission issue (rare on free tier) | Tell the participant *"Mailchimp says I don't have permission for that. Let me reconnect."* Re-run Phase 1. |
| HTTP 404 `Resource not found` on `/lists/<id>` | Audience id is stale or wrong | Re-list audiences (Pattern 1), use the current id. |
| HTTP 404 on `/lists/<id>/members/<hash>` | Subscriber hash is wrong (probably miscomputed) | Verify the hash: lowercase email, then MD5. |
| HTTP 400 `Invalid Email Address` on Pattern 3 | Email failed Mailchimp's regex (usually a typo) | Translate: *"That doesn't look like a valid email — want to double-check?"* |
| HTTP 400 `Member Exists` on Pattern 3 | Email already in the audience (possibly unsubscribed) | Translate: *"[email] is already in [audience] (might be unsubscribed). Want me to resubscribe them?"* — if yes, PATCH the member with `status: subscribed`. |
| HTTP 429 | Hit Mailchimp's per-account rate cap (10 simultaneous, 120 req/sec) | Wait 30s, retry once. Surface plain English if still rate-limited. |
| Network/connection error to `*.api.mailchimp.com` | DC suffix wrong, or transient network | Re-check `dc` field in credentials.json matches the API key's suffix. |

Translate every error to plain English. Never show raw HTTP bodies to the participant.

---

## Scope Limitations

This connector **can**:

- Read all standard read endpoints (audiences/lists, members, campaigns, reports, automations metadata, segments, tags, growth history, search).
- Add subscribers to an audience (`status: subscribed` for confirmed-consent flows, `status: pending` for double-opt-in).
- Tag and untag subscribers.
- Send a draft campaign that already exists in Mailchimp's web UI.
- Unsubscribe a member.

It **cannot**:

- **Compose campaigns from scratch** — Mailchimp's template + drag-drop editor is the participant's canvas; this SKILL doesn't generate HTML email content. The participant drafts in Mailchimp's web UI; Claude sends.
- **Manage automations** (Customer Journeys / Classic Automations) beyond reading status — modifying these requires the Marketing API's complex automation endpoints not covered in v1.
- **Bulk operations** (`/batches`) — not in v1; tracked as a future enhancement for participants with very large audiences.
- **E-commerce data** (`/ecommerce/stores/*`) — separate API surface, not in v1.
- **Transactional emails** (Mandrill / Mailchimp Transactional) — that's a separate product with its own API and pricing tier.
- **File Manager / merge field bulk updates** — not in v1's 10 patterns.

It **requires** the participant to be the Mailchimp account owner or have an Admin role — viewer/author roles can't create API keys.

---

## Behaviour Guidelines (Phase 2)

- **Real-data awareness** — every Phase 2 call hits the participant's real audience. Apply the real-data gate on the first call per session; apply the per-write gate on every write.
- **Audience-id discovery** — most patterns need a `list_id` (Mailchimp's term for audience). If the participant says "my audience" and there's only one, use it silently. If there are multiple, ask which.
- **Subscriber hash** — Mailchimp uses the MD5 of the lowercased email as the URL identifier for member-specific endpoints. Compute as: `printf "%s" "${EMAIL,,}" | md5sum | awk '{print $1}'`.
- **Date format** — Mailchimp returns ISO-8601 timestamps. Present as friendly relative ("3 days ago") or absolute ("2026-05-30") depending on context.
- **Format counts and rates correctly** — open_rate / click_rate are decimal fractions (`0.245` = 24.5%). Multiply by 100 for display.
- **Auth errors** → re-run Phase 1 from Step 2. Do not ask the participant to "run a command" — you run it.
- **Never log or echo the API key** — `api_key` is the only secret in `credentials.json`. Never include it in any output visible to the participant.
- **Compliance defaults** — Pattern 3's `status:"pending"` (double-opt-in) is the safe default when the participant adds an unfamiliar email; switch to `status:"subscribed"` only when the participant confirms they already have explicit consent.
- **Sending is irreversible** — Pattern 9's gate is firmer than the others ("Are you sure?" rather than "OK?") because once sent, emails can't be recalled.

---

## OAuth2 — advanced alternative (NOT primary path)

Mailchimp supports OAuth2 for apps with multiple end-users or for cases where the participant prefers not to issue an API key. The current SKILL defaults to API key because:

1. API key creation is a single ~30-second flow (sign in → API keys page → Create A Key → name it → copy).
2. OAuth2 requires registering an app at `admin.mailchimp.com/account/oauth2_client/` first (~3 min), then doing the OAuth dance with a localhost redirect URI loopback listener — same shape as `myob-connector` Phase 1.
3. For single-participant workshop use cases, the friction-per-feature ratio favours API keys.

If a future participant needs OAuth2 (e.g., they're building an app that other people will install), the OAuth2 endpoints are:

- Authorize: `https://login.mailchimp.com/oauth2/authorize`
- Token: `https://login.mailchimp.com/oauth2/token`
- Metadata: `https://login.mailchimp.com/oauth2/metadata` (returns `dc` + `api_endpoint` after token issued)

The OAuth2 flow is documented as a v2 enhancement; current `credentials.json` schema supports either path (the `api_key` field can hold an API key OR an OAuth2 access token — Mailchimp treats them identically at the API request layer).

---

## Related Skills

- **`myob-connector`**: Reference SKILL for Direct-REST + Playwright. Phase 1 atomic credentials.json write, single-mode pattern, bearer-on-curl Phase 2 all borrowed from MYOB. MYOB's OAuth complexity is reduced here to a single API key paste, but the file structure mirrors MYOB's.
- **`quickbooks-connector`**: Sibling autonomous-Phase-1 connector. Same plain-language communication rules. QBO's mode-detection + production-mode gates were the template for this SKILL's real-data + destructive-op gates.
- **`google-ads-connector`**: Sibling Tier-1 Direct-REST connector. Heavier (test vs Basic Access modes) than Mailchimp; reference for the per-write confirmation pattern.
- **`ghl-connector`**: Sibling marketing connector (different vendor, Hosted-bearer-PAT pattern). Reference if a participant has BOTH GHL and Mailchimp — different APIs, similar workshop UX.
- **`superpowers:systematic-debugging`**: For troubleshooting unexpected Mailchimp API responses.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) — three-pattern decision tree. This SKILL is a direct-REST connector (out-of-scope for that doc, sibling shape to `myob-connector`).
- [Mailchimp Marketing API v3 reference](https://mailchimp.com/developer/marketing/api/) — official endpoint catalogue + rate limits + auth shape.
- [Mailchimp API keys docs](https://mailchimp.com/help/about-api-keys/) — where Phase 1 Step 3 generates the key.
- Memory `reference_playwright_snapshot_password_leak` — sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` — say "audience" to participants, never "list" (Mailchimp's internal term is `list` but their UI says "audience" for the same concept).
