---
name: klaviyo-connector
description: "Connect and operate Klaviyo (e-commerce-focused email + SMS marketing) — read profiles/subscribers, lists, segments, campaigns, flows (automations), campaign performance (opens/clicks/revenue); add profiles to lists, send draft campaigns, suppress profiles. Tier-1 connector for SMBs running e-commerce email + SMS, especially Shopify/WooCommerce stores. Direct-REST against Klaviyo API at https://a.klaviyo.com/api/ with `Authorization: Klaviyo-API-Key <key>` header and a required `revision` header pinning the API version (this SKILL uses `revision: 2025-10-15`). Single-mode connector — Klaviyo's free tier IS real data (up to 250 profiles, 500 email sends/month), no test vs live distinction. Phase 1 drives www.klaviyo.com via Playwright: signs participant in, navigates organization-name → Settings → API keys, clicks Create Private API Key, names it `Claude Workshop Connector` with Full scope, captures the one-time-displayed key via clipboard transit (Klaviyo cannot show the key again after creation), persists to ~/.config/klaviyo/credentials.json (mode 0600). Use this skill when the user asks about their Klaviyo, subscribers, profiles, lists, segments, flows, email/SMS campaigns, or says 'connect Klaviyo', 'send my newsletter', 'show campaign revenue'. On the first use of any Klaviyo feature, run Phase 1 before attempting any tool call."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - klaviyo
    - email-marketing
    - sms-marketing
    - ecommerce
    - profiles
    - segments
    - flows
    - rest-api
  pairs-with:
    - skill: mailchimp-connector
      reason: Sibling Tier-1 email-marketing connector. Same single-mode API-key paste pattern; same per-write gate prose. Use Mailchimp for newsletter-style SMBs, Klaviyo for e-commerce SMBs (Shopify/WooCommerce stores).
    - skill: myob-connector
      reason: Reference SKILL for Direct-REST + Playwright pattern.
    - skill: quickbooks-connector
      reason: Sibling autonomous-Phase-1 connector. Same communication rules; same gate prose for production-mode operations.
    - skill: superpowers:systematic-debugging
      reason: For troubleshooting Klaviyo's revision-header mismatches or scope errors.
---

# Klaviyo Connector

## Overview

This skill lets you read and operate a user's Klaviyo account on their behalf using **Klaviyo's REST API** (no MCP server, no first-party CLI — Direct-REST + Playwright pattern, sibling to `mailchimp-connector` and `myob-connector`).

It has two phases:

- **Phase 1 — Install & Connect (autonomous via Playwright).** Claude drives `www.klaviyo.com` via Playwright MCP: signs the participant in, walks organization-name → Settings → API keys, clicks **Create Private API Key**, names it `Claude Workshop Connector` with Full scope, DOM-extracts the one-time-displayed key via clipboard transit (Klaviyo cannot show the key again after the modal closes — this is the most time-sensitive moment in Phase 1), and persists to `~/.config/klaviyo/credentials.json` (mode 0600). The participant's only manual moment is signing in to Klaviyo once.
- **Phase 2 — Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Klaviyo REST endpoints with `Authorization: Klaviyo-API-Key <key>` + the required `revision: 2025-10-15` header (Klaviyo's API versioning is by date string). Writes (add to list, send campaign, suppress profile) are gated by per-call confirmation prose — every Phase 2 invocation hits real data (Klaviyo has no sandbox).

**Single-mode, no test/live distinction.** Klaviyo's free tier (up to 250 profiles, 500 sends/month) is real data — no sandbox API. Every Phase 2 call touches the participant's real audience. Production-mode gates are the default behaviour.

**API keys don't expire.** Klaviyo Private API Keys are revocable but not time-bounded; no refresh-token cycle. Auth failure path is "key revoked" (HTTP 401) → re-run Phase 1.

**Revision header is mandatory.** Every call needs `revision: <YYYY-MM-DD>`. Klaviyo rejects requests without it (HTTP 400). This SKILL pins to `2025-10-15` — the latest stable revision at SKILL author time. When Klaviyo deprecates that revision (~12-18 months out), bump the constant in the helper.

**Which phase to run** — Before any tool call:

```bash
test -f "$HOME/.config/klaviyo/credentials.json" && jq -r '.api_endpoint // "missing"' "$HOME/.config/klaviyo/credentials.json" 2>/dev/null || echo missing
```

- Starts with `https://` → credentials present. Smoke (`GET /accounts/`); on 200 → Phase 2.
- `missing` → run Phase 1.

---

## Golden rule — do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside the Playwright MCP browser. Never tell the participant to "open Klaviyo in your browser." Claude navigates; the participant types their password directly into the Playwright window. Same as `mailchimp-connector`, `myob-connector`, `quickbooks-connector`.

If Playwright MCP is unavailable, halt and point the participant at install instructions; do not fall back to opening their default browser.

---

## Communication rules for Phase 1

The participant is a non-technical business owner. Plain English only:

- **One step at a time.**
- **Plain English only.** Never say API, key, OAuth, token, scope, refresh, Bearer, REST, endpoint, JSON, revision, env var, curl, terminal, CLI, MCP, callback, loopback, sandbox, file path. If you must, say "your connection key", "your Klaviyo account details".
- **Tell them what is about to happen.** *"I'm opening Klaviyo now — sign in when you see the page. About 45 seconds."*
- **React warmly.** Good: *"Connected — your Klaviyo with **[N] profiles** is ready."* Bad: *"Klaviyo API key persisted with 2025-10-15 revision pinning."*
- **Never show error messages directly.** Translate.
- **Short responses.** Max 8 lines per message.
- **Never echo the API key** back to the participant. It's stored locally, never shown.
- **Klaviyo can only show the key once** — emphasize plain-English urgency at the create-key step: *"I need to grab the key the instant it appears — Klaviyo won't show it a second time."*

---

## ⛔ Pre-flight check

Verify Playwright MCP tools are available (`ToolSearch +playwright`). If absent, halt.

---

## PHASE 0 — Credential check

```bash
CREDS="$HOME/.config/klaviyo/credentials.json"
if [ ! -f "$CREDS" ]; then
  STATE=missing
else
  STATE=$(jq -r '.api_endpoint // "missing"' "$CREDS" 2>/dev/null)
fi
echo "$STATE"
```

- `missing` → run Phase 1.
- Starts with `https://` → smoke (`GET /accounts/`); on 200 → Phase 2; on 401 → re-run Phase 1.

---

## PHASE 1 — Install & Connect (autonomous via Playwright)

### Step 1 — Welcome

> "Great — connecting your Klaviyo. I'll open Klaviyo's settings in a small browser window. Sign in when you see the page (and approve any verification code Klaviyo sends to your phone). About 45 seconds total."

### Step 2 — Sign in to Klaviyo

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/login" })
```

**Do NOT snapshot the sign-in page** (`reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "Dashboard", time: 60 })
```

(Or wait for any post-sign-in marker like "Profiles", "Campaigns" — Klaviyo's sign-in destination depends on the participant's account state. Avoid snapshotting until at least one of these post-sign-in markers is visible.)

### Step 3 — Navigate to API keys

Klaviyo's API keys tab is reached via the org-name dropdown in the top-right → Settings → API keys. Drive this via Playwright:

```js
// Click the organization-name dropdown (top-right corner button)
() => {
  const btn = Array.from(document.querySelectorAll('button, [role=button]')).find(b => {
    const aria = (b.getAttribute('aria-label') || '').toLowerCase();
    return /organization|account|workspace.*menu/.test(aria);
  });
  if (!btn) return { ok: false };
  btn.click();
  return { ok: true };
}
```

Then click **Settings** in the dropdown menu, then click the **API keys** tab on the Settings page. (Klaviyo's URL changes during this navigation; expected end state is `klaviyo.com/account/api-keys` or similar — verify via `window.location.href`.)

Fallback if the dropdown selector fails: navigate directly:

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/account#api-keys-tab" })
```

(Klaviyo has used this URL for several years; if it 404s on a UI rev, the dropdown path above is the reliable alternative.)

### Step 4 — Create the Private API Key

The API keys page shows existing keys + a `Create Private API Key` button.

Idempotent check: if a key already named `Claude Workshop Connector` exists, ask the participant: *"You already have a Claude Workshop Connector key. Want me to use a different name, or are you OK rotating to a fresh one?"* — Klaviyo doesn't let you view existing keys' values, so re-using requires asking the participant to paste the key.

For a fresh key, click Create:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /^create private api key$/i.test((b.innerText||'').trim()));
  if (!btn) return { ok: false };
  btn.click();
  return { ok: true };
}
```

The Create dialog opens. Fill the name field via React-friendly setter:

```js
() => {
  const inputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'));
  const target = inputs.find(i => {
    const aria = (i.getAttribute('aria-label') || '').toLowerCase();
    const placeholder = (i.placeholder || '').toLowerCase();
    return /name|label/.test(aria + placeholder);
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

Pick the **Full** scope (Klaviyo's options are `Read-only`, `Full`, or `Custom` per-resource — Full is needed for the writes in Patterns 5/9/10):

```js
() => {
  // Find the Full scope radio/button (often a card-style radio in Klaviyo's UI)
  const candidates = Array.from(document.querySelectorAll('input[type=radio], button, [role=radio], label'));
  const full = candidates.find(el => /^full$/i.test((el.innerText || el.value || '').trim()));
  if (!full) return { ok: false };
  full.click();
  full.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true };
}
```

Then click the dialog's **Create** button:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^create$/i.test((b.innerText||'').trim()) && !b.disabled);
  if (!btn) return { ok: false };
  btn.click();
  return { ok: true };
}
```

### Step 5 — DOM-extract the key via clipboard transit (TIME-SENSITIVE)

**Klaviyo only displays the key once.** The post-create modal shows it; close it and the key is gone forever.

Save the participant's prior clipboard first:

```bash
SAVED=$(wl-paste 2>/dev/null | base64 -w0)
echo "$SAVED" > /tmp/klaviyo-prev-clipboard.b64
```

Extract:

```js
async () => {
  // Klaviyo Private API Keys start with 'pk_' (Private Key prefix) and are ~40+ characters total
  const re = /\bpk_[A-Za-z0-9_-]{30,}\b/;
  const all = Array.from(document.querySelectorAll('input, code, span, div, p, pre, textarea'));
  for (const el of all) {
    const v = (el.value || el.innerText || el.textContent || '').trim();
    const match = v.match(re);
    if (match) {
      const key = match[0];
      await navigator.clipboard.writeText(JSON.stringify({ api_key: key }));
      return { ok: true, key_len: key.length };
    }
  }
  return { ok: false };
}
```

Returns only `key_len`. The key is in the clipboard, never in the tool return.

**Validation (silent):** key starts with `pk_` and is typically 40-50 chars. If `{ ok: false }`, the modal may have already closed — tell the participant: *"I missed the key, sorry — let me create another one."* Re-run Step 4.

### Step 6 — Save credentials.json

```bash
mkdir -p "$HOME/.config/klaviyo"
chmod 700 "$HOME/.config/klaviyo"
umask 077

API_KEY="$(wl-paste | jq -r '.api_key')"

jq -n \
  --arg key "$API_KEY" \
  --arg ep "https://a.klaviyo.com/api" \
  --arg rev "2025-10-15" \
  --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{api_key:$key, api_endpoint:$ep, revision:$rev, key_name:"Claude Workshop Connector", scope:"Full", created_at:$created}' \
  > "$HOME/.config/klaviyo/credentials.json.tmp"
chmod 600 "$HOME/.config/klaviyo/credentials.json.tmp"
mv "$HOME/.config/klaviyo/credentials.json.tmp" "$HOME/.config/klaviyo/credentials.json"

# Restore prior clipboard
[ -s /tmp/klaviyo-prev-clipboard.b64 ] && base64 -d /tmp/klaviyo-prev-clipboard.b64 | wl-copy
rm -f /tmp/klaviyo-prev-clipboard.b64

unset API_KEY
```

Verify:

```bash
jq -r 'keys | join(",")' "$HOME/.config/klaviyo/credentials.json"
# expect: api_endpoint,api_key,created_at,key_name,revision,scope
```

### Step 7 — Smoke test

```bash
API_KEY="$(jq -r .api_key "$HOME/.config/klaviyo/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/klaviyo/credentials.json")"
REVISION="$(jq -r .revision "$HOME/.config/klaviyo/credentials.json")"

curl -sf "$API_ENDPOINT/accounts/" \
  -H "Authorization: Klaviyo-API-Key $API_KEY" \
  -H "revision: $REVISION" \
  | jq -r '.data[0].attributes.contact_information.organization_name // "(unknown)"'
```

Returns the account's organization name. Tell the participant:

> "All connected — your Klaviyo account **[org_name]** is ready. Ask me things like *'how many subscribers do I have?'* or *'show me my recent campaigns'*."

If the smoke fails:

- HTTP 401 → key didn't paste correctly; re-run Phase 1 from Step 4.
- HTTP 400 with `revision` in message → revision header constant is stale; bump `2025-10-15` to a newer date and retry.

---

## PHASE 2 — Use Tools

### Helper — base curl shape

```bash
kl_get() {
  curl -sf "$API_ENDPOINT$1" \
    -H "Authorization: Klaviyo-API-Key $API_KEY" \
    -H "revision: $REVISION"
}
kl_post() {
  curl -sf -X POST "$API_ENDPOINT$1" \
    -H "Authorization: Klaviyo-API-Key $API_KEY" \
    -H "revision: $REVISION" \
    -H "Content-Type: application/json" \
    -d "$2"
}
kl_patch() {
  curl -sf -X PATCH "$API_ENDPOINT$1" \
    -H "Authorization: Klaviyo-API-Key $API_KEY" \
    -H "revision: $REVISION" \
    -H "Content-Type: application/json" \
    -d "$2"
}
```

### Real-data gate — first invocation per session

```bash
ORG_NAME="$(kl_get "/accounts/" | jq -r '.data[0].attributes.contact_information.organization_name')"
```

Tell the participant: *"Just confirming — you're connected to your real Klaviyo account **[org_name]**. Anything I do here changes your live audience. OK to proceed with **[summary]**?"* Wait for OK. ONCE per session.

### Destructive-op gate — every write

Patterns 5, 9, 10 below. Confirmation prompts:

| Operation | Prompt |
|---|---|
| Add profile to list | "I'm about to add **[email]** to your **[List Name]** list. They'll start receiving your campaigns. OK?" |
| Send campaign | "I'm about to **send** campaign **[Subject]** to **[List/Segment]** (**[N]** recipients). This is irreversible. Are you sure?" |
| Suppress profile | "I'm about to **suppress** **[email]** — they won't receive any future emails or SMS from you. OK?" |

### Common Pattern 1 — List profiles

```bash
kl_get "/profiles?page%5Bsize%5D=20" | jq '.data[] | {id, email: .attributes.email, first_name: .attributes.first_name, created: .attributes.created, last_event_date: .attributes.last_event_date}'
```

Klaviyo paginates via `page[size]` (max 100). Use `page[cursor]` from previous response's `links.next` for next page.

**Use when:** "list my subscribers", "show profiles"

### Common Pattern 2 — Get profile by email

```bash
EMAIL="<email>"
kl_get "/profiles?filter=equals(email,\"$EMAIL\")" | jq '.data[0] | {id, email: .attributes.email, properties: .attributes.properties, location: .attributes.location}'
```

Klaviyo's filter syntax uses JSON:API: `filter=equals(field,"value")`. Other operators: `greater-than`, `less-than`, `contains`, `starts-with`.

**Use when:** "find [email]", "look up [email]", "what's [email]'s info?"

### Common Pattern 3 — List lists

```bash
kl_get "/lists?page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, created: .attributes.created, count: .attributes.profile_count}'
```

Klaviyo lists are explicit static groupings (vs Segments which are dynamic). Returns name + profile count.

**Use when:** "what lists do I have?", "show my lists"

### Common Pattern 4 — List segments

```bash
kl_get "/segments?page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, created: .attributes.created, definition: .attributes.definition}'
```

Segments are dynamic: members are recomputed live based on behaviour rules (e.g., "purchased in last 30 days"). The `definition` field encodes the rule.

**Use when:** "my segments", "behavioural audiences", "who matches X"

### Common Pattern 5 — Add profile to list (write, gated)

Apply the **Add profile to list** gate first.

```bash
LIST_ID="<from Pattern 3>"
EMAIL="<email>"

# Step 1: ensure the profile exists (Klaviyo upserts by email)
PROFILE_ID="$(kl_post "/profiles" "$(jq -n --arg em "$EMAIL" '{data:{type:"profile", attributes:{email:$em}}}')" | jq -r '.data.id')"

# Step 2: add the profile to the list via relationships endpoint
kl_post "/lists/$LIST_ID/relationships/profiles/" "$(jq -n --arg pid "$PROFILE_ID" '{data:[{type:"profile", id:$pid}]}')"
```

Klaviyo's two-step add (create profile → relate to list) is the documented pattern; the `204 No Content` response on the second call indicates success.

**Use when:** "add [email] to [list]", "subscribe [email]"

### Common Pattern 6 — List recent campaigns

```bash
kl_get "/campaigns?filter=equals(messages.channel,\"email\")&page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, status: .attributes.status, send_time: .attributes.send_time}'
```

Filter by `messages.channel` = `email` or `sms`. Status: `Draft`, `Queued`, `Sent`, `Cancelled`. Klaviyo's campaigns include both email and SMS.

**Use when:** "my campaigns", "recent newsletters", "what SMS have I sent?"

### Common Pattern 7 — Campaign performance with revenue

Klaviyo's signature feature is attributed revenue (e-commerce integration with Shopify/WooCommerce). The campaign report endpoint returns opens, clicks, AND revenue:

```bash
CAMPAIGN_ID="<from Pattern 6>"
kl_get "/campaign-recipient-estimations/$CAMPAIGN_ID/" | jq '.data.attributes'
# For the actual sent-report with revenue:
kl_get "/campaign-messages/$CAMPAIGN_ID/?fields[campaign-message]=channel,definition&include=campaign" \
  | jq '.included[0].attributes.send_options'

# Better: use the Reports endpoint which aggregates send + opens + revenue
kl_post "/campaign-values-reports/" "$(jq -n --arg cid "$CAMPAIGN_ID" '{data:{type:"campaign-values-report", attributes:{statistics:["opens","clicks","conversion_value","recipients"], timeframe:{key:"last_30_days"}, filter:"equals(campaign_id, \"\($cid)\")"}}}')" \
  | jq '.data.attributes.results'
```

The Reports API is Klaviyo's canonical analytics endpoint — synchronous for small queries, async for big date ranges. For the workshop's common case (single campaign report), this returns a small payload immediately.

**Use when:** "how did [campaign] perform?", "campaign revenue", "opens for [campaign]"

### Common Pattern 8 — Top flows by revenue

Flows are Klaviyo's automations (welcome series, abandoned cart, post-purchase, etc.).

```bash
kl_post "/flow-values-reports/" "$(jq -n '{data:{type:"flow-values-report", attributes:{statistics:["conversion_value","recipients"], timeframe:{key:"last_30_days"}}}}')" \
  | jq '.data.attributes.results | sort_by(.statistics.conversion_value) | reverse | .[:10]'
```

Returns the top 10 flows by attributed revenue in the last 30 days. Critical metric for e-commerce SMBs.

**Use when:** "best automations", "top flows", "what's driving sales?"

### Common Pattern 9 — Send a campaign (write, gated, IRREVERSIBLE)

Apply the **Send campaign** gate first. Campaign must already be drafted in Klaviyo's web UI (the SKILL doesn't compose campaigns from scratch — Klaviyo's template + Universal Content surface is too complex for v1).

```bash
CAMPAIGN_ID="<from Pattern 6 (filter status='Draft')>"
kl_post "/campaign-send-jobs/" "$(jq -n --arg cid "$CAMPAIGN_ID" '{data:{type:"campaign-send-job", id:$cid}}')"
```

Response: 202 Accepted. The campaign queues for send; actual delivery starts within a few minutes.

Tell the participant: *"**[Campaign Name]** is sending now to **[N]** recipients. You'll see open/click numbers within an hour."*

**Use when:** "send [campaign]", "launch newsletter"

### Common Pattern 10 — Suppress profile (write, gated)

Suppression in Klaviyo means the profile WILL NOT receive any future email/SMS, regardless of which lists or segments they're on. Equivalent to a hard unsubscribe.

Apply the **Suppress profile** gate first.

```bash
EMAIL="<email>"
kl_post "/profile-suppression-bulk-create-jobs/" "$(jq -n --arg em "$EMAIL" '{data:{type:"profile-suppression-bulk-create-job", attributes:{profiles:{data:[{type:"profile", attributes:{email:$em}}]}}}}')"
```

Returns 202 + job id for async processing. Most suppressions are processed within seconds.

**Use when:** "suppress [email]", "remove [email]", "[email] asked to be unsubscribed"

> **Compliance**: Klaviyo's suppression respects GDPR / CAN-SPAM unsubscribe requests. When a participant's own customer asks to opt out, prioritise this operation.

---

## Prompt-to-Tool Mapping

| What the participant says | Pattern |
|---|---|
| "List my subscribers" / "Show profiles" | Pattern 1 |
| "Find [email]" / "Look up [email]" | Pattern 2 |
| "My lists" | Pattern 3 |
| "Segments" / "Who matches [behaviour]?" | Pattern 4 |
| "Add [email] to [list]" / "Subscribe [email]" | Pattern 5 (gated) |
| "Recent campaigns" / "My newsletters" | Pattern 6 |
| "How did [campaign] do?" / "Campaign revenue" | Pattern 7 |
| "Top flows" / "Best automations" / "What's driving sales?" | Pattern 8 |
| "Send [campaign]" / "Launch newsletter" | Pattern 9 (gated, irreversible) |
| "Suppress [email]" / "Remove [email]" | Pattern 10 (gated) |
| "How many subscribers?" | Pattern 3 (sum `profile_count` across lists) or `/accounts/` |
| "Connect Klaviyo" / "Set up Klaviyo" | **Run Phase 1** |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `unauthorized_request` | API key revoked / invalid | Translate: "Looks like the connection was disconnected — let me reconnect." Re-run Phase 1. |
| HTTP 400 with `revision` in message | Klaviyo deprecated the revision constant the SKILL pins to | Bump the revision string in credentials.json + the SKILL's helper to a newer date (Klaviyo publishes revisions roughly every 3 months). |
| HTTP 400 `validation_error` | Filter syntax wrong (Klaviyo's JSON:API filters are strict) | Diagnose silently, retry. |
| HTTP 403 `insufficient_scope` | Private API key was created Read-only when the operation needs Full | Tell participant: "I need a key with full access — let me create a new one." Re-run Phase 1 Step 4 with Full scope. |
| HTTP 404 on `/profiles/<id>` | Profile id stale (deleted or never existed) | Re-fetch via Pattern 2 (filter by email). |
| HTTP 429 | Hit Klaviyo's burst rate cap (75 req/s burst, 700 req/min steady on most endpoints) | Wait 30s, retry once. Surface plain English if still hitting. |
| HTTP 202 with no `data.id` on writes | Async job queued; processing takes seconds-minutes | Note: this is success, not error. Tell participant the action is processing. |

Translate every error to plain English. Never show raw HTTP bodies.

---

## Scope Limitations

This connector **can**:

- Read all standard endpoints: profiles, lists, segments, campaigns (email + SMS), flows, tags, events, accounts.
- Generate campaign + flow performance reports via `/campaign-values-reports/` and `/flow-values-reports/`.
- Add profiles to lists.
- Send a draft campaign that already exists in Klaviyo's web UI.
- Suppress profiles (hard unsubscribe).

It **cannot**:

- **Compose campaigns from scratch** — Klaviyo's drag-drop editor + Universal Content is the participant's design surface; this SKILL doesn't generate email HTML or SMS message content.
- **Modify flows** — flow definition is a visual builder; v1 reads metrics, doesn't edit.
- **Manage Klaviyo Forms** (popups, embedded signup forms) — separate API surface, not in v1.
- **Bulk operations beyond suppression** — `/data-privacy-deletion-jobs/` exists for GDPR-style data deletion but is high-stakes; tracked as v2.
- **A/B testing / Multivariate campaign creation** — separate workflow, not in v1.
- **Coupon code generation** — Klaviyo's coupon endpoints are e-commerce-integration-specific; not in v1.
- **SMS consent management** — SMS in Klaviyo has stricter consent requirements; v1 treats SMS campaigns as read-only.

It **requires** the Private API key to have **Full** scope (not Read-only) for Patterns 5/9/10. Read-only keys work for Patterns 1-4 + 6-8.

---

## Behaviour Guidelines (Phase 2)

- **Real-data awareness** — every Phase 2 call hits real Klaviyo data. Real-data gate on first call per session; per-write gate on every write.
- **List vs Segment vocabulary** — Klaviyo treats Lists (static) and Segments (dynamic) as different objects. When a participant says "my audience", clarify which they mean if needed.
- **Email vs SMS** — Klaviyo campaigns can be email OR SMS. The channel is in `attributes.messages.channel`. Patterns that filter campaigns should specify channel.
- **Revenue formatting** — `conversion_value` is in the participant's account currency (USD/EUR/GBP/etc.) and returned as numeric. Format as currency.
- **Date format** — Klaviyo uses ISO-8601 (`2026-06-02T05:30:00Z`).
- **Pagination** — `page[size]=N` (max 100); `page[cursor]=...` from `links.next`. Multi-page operations should cap at 5 pages unless the participant asks for more.
- **Auth errors** → re-run Phase 1. Do not ask the participant to "run a command" — you run it.
- **Never log or echo the API key** — `api_key` is the only secret. Never appears in participant-visible output.
- **Suppression is firm** — Pattern 10 affects deliverability across ALL of the participant's audience. Gate is strict.
- **Sending is irreversible** — Pattern 9's gate uses "Are you sure?" (stronger than "OK?").

---

## Related Skills

- **`mailchimp-connector`**: Sibling Tier-1 email-marketing connector. Same single-mode + API-key paste pattern; same per-write gates. Recommend Mailchimp for newsletter-style SMBs (blog readers, info-product creators); Klaviyo for e-commerce SMBs (Shopify/WooCommerce stores) because Klaviyo's flows + revenue attribution are tightly coupled to commerce events.
- **`myob-connector`**: Reference Direct-REST + Playwright pattern. credentials.json atomic write borrowed verbatim.
- **`quickbooks-connector`**: Sibling autonomous-Phase-1 connector. Communication rules + gate prose model.
- **`google-ads-connector`** / **`gusto-connector`**: Sibling Tier-1 Direct-REST connectors (different complexity tiers — these have two-mode designs, Klaviyo is single-mode like Mailchimp).
- **`superpowers:systematic-debugging`**: For revision-header / scope edge cases.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) — three-pattern decision tree. Direct-REST connector (out-of-scope for that doc; sibling shape to `mailchimp-connector` and `myob-connector`).
- [Klaviyo API overview](https://developers.klaviyo.com/en/reference/api_overview) — official endpoint catalogue + auth shape.
- [Klaviyo API key management](https://help.klaviyo.com/hc/en-us/articles/115005062267) — how to manage existing keys.
- [Klaviyo Private API Key creation](https://help.klaviyo.com/hc/en-us/articles/7423954176283) — exact UI flow Phase 1 Step 4 drives.
- Memory `reference_playwright_snapshot_password_leak` — sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` — say "audience" / "profiles" to participants. Klaviyo uses both "profiles" and "subscribers" interchangeably in its UI.
