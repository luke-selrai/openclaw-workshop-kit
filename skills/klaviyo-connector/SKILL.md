---
name: klaviyo-connector
description: "Connect Klaviyo to Claude by switching on its built-in connector or storing its API credentials. Use when the user asks to set up or connect Klaviyo, or wants Klaviyo work (profiles, lists, segments, campaigns, flows, revenue reports) and Klaviyo isn't connected yet. Once connected, Klaviyo runs through the `mcp__claude_ai_Klaviyo__*` tools; sending a drafted campaign runs against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__claude_ai_Klaviyo__*
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

This skill lets you read and operate a user's Klaviyo account on their behalf. There are two routes, and the built-in one comes first.

**The built-in connector (the default route).** Klaviyo publishes a connector in Claude's own connector directory (`https://claude.com/connectors/klaviyo`, display name **Klaviyo**, made by Klaviyo, read & write). One click, no credentials handled by this skill. It covers campaign performance analysis, customer profile insights, flow analysis - and it **creates campaigns as drafts**, which is a straight gain: the kit's own route below cannot compose a campaign at all. What it cannot yet do is **send** an already-drafted campaign end to end (Klaviyo targets Q3 2026 for that), and its flow creation is capped at roughly 100 a day.

**The kit's own route.** Klaviyo's **REST API** direct (no MCP server, no first-party CLI - Direct-REST + Playwright pattern, sibling to `mailchimp-connector` and `myob-connector`). This is the route that sends a campaign the user has already drafted. Both routes can live on one machine at once; never tear one down to set the other up.

The kit's own route has two phases:

- **PHASE 1 - Install & Connect (autonomous via Playwright).** Claude drives `www.klaviyo.com` via Playwright MCP: signs the participant in, navigates directly to the canonical `/settings/account/api-keys` URL, clicks **Create Private API Key** (which navigates to a full-page form at `/create-private-api-key`), names it `Claude Workshop Connector` with Full Access Key, DOM-extracts the one-time-displayed key from the post-create confirmation page via clipboard transit (Klaviyo cannot show the key again after navigating away - this is the most time-sensitive moment in Phase 1), and persists to `~/.config/klaviyo/credentials.json` (mode 0600). The participant's only manual moment is signing in to Klaviyo once.
- **PHASE 2 - Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Klaviyo REST endpoints with `Authorization: Klaviyo-API-Key <key>` + the required `revision: 2025-10-15` header (Klaviyo's API versioning is by date string). Writes (add to list, send campaign, suppress profile) are gated by per-call confirmation prose - every PHASE 2 invocation hits real data (Klaviyo has no sandbox).

**Single-mode, no test/live distinction.** Klaviyo's free tier (up to 250 profiles, 500 sends/month) is real data - no sandbox API. Every PHASE 2 call touches the participant's real audience, on either route. Production-mode gates are the default behaviour.

**API keys don't expire.** Klaviyo Private API Keys are revocable but not time-bounded; no refresh-token cycle. Auth failure path is "key revoked" (HTTP 401) → re-run **PHASE 1 - Install & Connect**.

**Revision header is mandatory.** Every call needs `revision: <YYYY-MM-DD>`. Klaviyo rejects requests without it (HTTP 400). This SKILL pins to `2025-10-15` - the latest stable revision at SKILL author time. When Klaviyo deprecates that revision (~12-18 months out), bump the constant in the helper.

**Which phase to run** - always start at Phase 0.

---

## Golden rule - do not open the participant's own browser

Every step of **the kit's own route** that requires sign-in runs inside the Playwright MCP browser. Never tell the participant to "open Klaviyo in your browser." Claude navigates; the participant types their password directly into the Playwright window. Same as `mailchimp-connector`, `myob-connector`, `quickbooks-connector`.

If Playwright MCP is unavailable, halt and point the participant at install instructions; do not fall back to opening their default browser.

**The one exception is Phase 1, the built-in connector.** That sign-in happens on claude.ai, and the participant's own everyday browser is the only one signed in there - so opening `https://claude.com/connectors/klaviyo` in their own browser is correct, and Playwright must not drive it. The golden rule above exists because the kit's own route reads a secret off the page in a driven browser; the built-in route reads nothing.

---

## Communication rules for the kit's own route (PHASE 1 - Install & Connect)

The participant is a non-technical business owner. Plain English only:

- **One step at a time.**
- **Plain English only.** Never say API, key, OAuth, token, scope, refresh, Bearer, REST, endpoint, JSON, revision, env var, curl, terminal, CLI, MCP, callback, loopback, sandbox, file path. If you must, say "your connection key", "your Klaviyo account details".
- **Tell them what is about to happen.** *"I'm opening Klaviyo now - sign in when you see the page. About 45 seconds."*
- **React warmly.** Good: *"Connected - your Klaviyo with **[N] profiles** is ready."* Bad: *"Klaviyo API key persisted with 2025-10-15 revision pinning."*
- **Never show error messages directly.** Translate.
- **Short responses.** Max 8 lines per message.
- **Never echo the API key** back to the participant. It's stored locally, never shown.
- **Klaviyo can only show the key once** - emphasize plain-English urgency at the create-key step: *"I need to grab the key the instant it appears - Klaviyo won't show it a second time."*

---

## ⛔ Pre-flight check (the kit's own route only)

Before running **the kit's own route**, verify Playwright MCP tools are available (`ToolSearch +playwright`). If absent, halt. Phase 1 (the built-in connector) needs no Playwright at all.

---

## Phase 0 - Is Klaviyo already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Klaviyo` (match the vendor word case-insensitively).
   - `✔ Connected` → skip to PHASE 2. Prove it first with one read: call any read tool in the `mcp__claude_ai_Klaviyo__*` namespace (account lookup, or list campaigns) and check a real answer comes back.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` for the participant and say: *"Your Klaviyo connection needs a quick re-sign-in. Press Reconnect next to Klaviyo, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Check for stored credentials:

   ```bash
   CREDS="$HOME/.config/klaviyo/credentials.json"
   if [ ! -f "$CREDS" ]; then
     STATE=missing
   else
     STATE=$(jq -r '.api_endpoint // "missing"' "$CREDS" 2>/dev/null)
   fi
   echo "$STATE"
   ```

   Starts with `https://` → smoke (`GET /accounts/`). On 200, say *"Klaviyo is already connected"* and skip to PHASE 2; do not set the built-in up on top of a working connection. On 401 the key was revoked - re-run **PHASE 1 - Install & Connect**. `missing` → continue.
3. **Nothing found** → Route by need, then Phase 1.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Klaviyo's tools.

---

## Route by need - which Klaviyo route does this participant actually want?

Ask **one** question in plain English before opening anything: *"What do you want me to do with your Klaviyo - look at how campaigns and automations are performing and write you some drafts, or actually press send on a campaign you've already built?"*

Then route each named need:

| What the participant wants | Route |
|---|---|
| Campaign performance, opens, clicks, attributed revenue | Built-in connector (Phase 1) |
| Flow analysis - which automations are earning | Built-in connector (Phase 1) |
| Look up a profile; understand a customer | Built-in connector (Phase 1) |
| **Write** a campaign - compose it as a draft | Built-in connector (Phase 1). The kit's own route cannot compose campaigns at all, so this is the built-in's territory outright. |
| **Send** a campaign that is already drafted | The kit's own route (PHASE 1 - Install & Connect), Pattern 9 |
| Create a lot of flows in one day (more than ~100) | The kit's own route - the built-in is capped at roughly 100 flow creations a day |
| Add a profile to a list, suppress a profile | Built-in connector first (it is read & write); if the write is refused, the kit's own route (Patterns 5 and 10) |

The built-in connector cannot send a campaign end to end yet - Klaviyo targets Q3 2026 for that. So run the kit's own route **only** when the participant named sending, bulk flow creation, or a write the built-in refused. If nothing they asked for is in the gap column, stop after Phase 1 and do not burden them with the key-minting walk. Say in one line what you are not connecting and why, so they can ask for it later.

---

## Phase 1 - Switch on the built-in Klaviyo connector (the default route)

This is a one-time, once-per-account job. The only thing the participant does is press one button and sign in. This skill handles no key on this route.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the participant in one line that this copy of Claude is signed in a different way, and run the kit's own route instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening Klaviyo's page in your browser. Press **Connect to Claude**, sign in to Klaviyo the way you normally do, and say yes when it asks for access. That is the only part only you can do, tell me when it says Connected."* Then open `https://claude.com/connectors/klaviyo` (or `https://claude.ai/directory/klaviyo`) in **the participant's own everyday browser** (`open` on Mac, `xdg-open` on Linux, `start ""` on Windows) - see the exception noted under the golden rule above. If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Klaviyo" → Connect. In the desktop app's Code tab the better route is the composer's **+** → **Connectors** → **Browse connectors** → the **+** next to it: that one shows up in the running session without a restart, whereas the browser page needs the app quit and reopened before any session sees the tools.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Klaviyo … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - any read tool in the `mcp__claude_ai_Klaviyo__*` namespace (account lookup, or list recent campaigns). Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - *"how did my last campaign do?"*, *"which automations are earning the most?"*, *"draft me a campaign for the winter sale"*.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Klaviyo on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

**Local entry precedence.** If a server registered locally with `claude mcp add` points at the same URL, it takes precedence and hides the built-in one. If it works, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the participant's OK.

**Real-data warning applies to both routes.** Klaviyo has no sandbox. Everything the built-in connector writes - including a draft campaign - lands in the participant's real account. Keep the real-data gate below.

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **When to run this.** Only when the participant named a need in the gap column of *Route by need* above - sending an already-drafted campaign, bulk flow creation, or a write the built-in refused - or when Phase 1 Step 1 showed this session cannot see built-in connectors at all. Otherwise stop at Phase 1. Both routes can coexist; setting this one up does not switch the built-in one off.

### Step 1 - Welcome

> "Great - connecting your Klaviyo. I'll open Klaviyo's settings in a small browser window. Sign in when you see the page (and approve any verification code Klaviyo sends to your phone). About 45 seconds total."

### Step 2 - Sign in to Klaviyo

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/login" })
```

**Do NOT snapshot the sign-in page** (`reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "Dashboard", time: 60 })
```

(Or wait for any post-sign-in marker like "Profiles", "Campaigns" - Klaviyo's sign-in destination depends on the participant's account state. Avoid snapshotting until at least one of these post-sign-in markers is visible.)

### Step 3 - Navigate directly to API keys settings

```
mcp__playwright__browser_navigate({ url: "https://www.klaviyo.com/settings/account/api-keys" })
```

**Captured 2026-06-02**: this is the canonical URL. The legacy `klaviyo.com/account#api-keys-tab` URL still works but issues a 302 redirect to `/settings/account/api-keys` (Klaviyo migrated its settings sub-router in 2024-25). Navigate directly to the canonical URL to skip the redirect hop.

The page renders directly (no iframe, no modal). Verify it loaded by checking the page text contains both `Public API Key` and `Private API Keys` sections (the page shows both side-by-side).

If a dropdown-walk alternative is ever needed (canonical URL changes again): click the org-name button in the top-right of the page (post-sign-in), then **Settings** in the dropdown, then the **API keys** tab on the Settings sidebar. Lower-confidence than the direct URL - selectors for the org-menu drift across Klaviyo's product redesigns.

### Step 4 - Create the Private API Key (full-page form, NOT a modal)

The API keys page shows existing keys + a `Create Private API Key` button.

**Captured 2026-06-02 - Klaviyo's create flow is a NEW PAGE, not a modal dialog.** Clicking `Create Private API Key` navigates the browser to `https://www.klaviyo.com/create-private-api-key` (a full-page form). The SKILL's earlier prose implied a modal - that's wrong; the form is page-scoped with three sections (Name input, Access Level radio cards, API Scopes table).

Idempotent check: if a key already named `Claude Workshop Connector` exists in the listing, ask the participant: *"You already have a Claude Workshop Connector key. Want me to use a different name, or are you OK rotating to a fresh one?"* - Klaviyo doesn't let you view existing keys' values, so re-using requires asking the participant to paste the key.

For a fresh key, click the create button on the listing page:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button, a')).find(b => /^create private api key$/i.test((b.innerText||'').trim()));
  if (!btn) return { ok: false };
  btn.scrollIntoView({ block: 'center' });
  btn.click();
  return { ok: true };
}
```

Wait for the navigation to complete:

```
mcp__playwright__browser_wait_for({ text: "New private API key", time: 10 })
```

(`New private API key` is the page heading on `/create-private-api-key`.)

Fill the name field via React-friendly setter. The input has `name="Private API Key Name"` and `placeholder="Name your key"` (verified 2026-06-02):

```js
() => {
  const target = Array.from(document.querySelectorAll('input[type="text"]')).find(i =>
    i.name === 'Private API Key Name' || /name your key/i.test(i.placeholder || '')
  );
  if (!target) return { ok: false };
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  target.focus();
  setter.call(target, 'Claude Workshop Connector');
  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true };
}
```

Pick the **Full Access Key** card (Klaviyo's three options are `Custom Key`, `Read-Only Key`, `Full Access Key` - note the `Key` suffix on each label; verified 2026-06-02). Full is needed for the writes in Patterns 5/9/10:

```js
() => {
  const labels = Array.from(document.querySelectorAll('label, div, span'));
  const fullCard = labels.find(el => /^full access key$/i.test((el.innerText||'').trim()));
  if (!fullCard) return { ok: false };
  // Find the nearest radio in the card's DOM ancestry
  let scope = fullCard.parentElement;
  for (let d = 0; d < 5 && scope; d++) {
    const radio = scope.querySelector('input[type="radio"]');
    if (radio) {
      radio.click();
      radio.dispatchEvent(new Event('change', { bubbles: true }));
      return { ok: true };
    }
    scope = scope.parentElement;
  }
  return { ok: false, reason: 'no_radio_in_card_ancestry' };
}
```

Then click the form's submit button. **Captured 2026-06-02 - the button text is exactly `Create`, NOT `Create Private API Key` / `Generate` / `Save` / `Submit`.** There are TWO `Create` buttons visible on the page: one in the sidebar nav (top-of-page; this is the workshop-feature dropdown) and one at the form's bottom-right. Disambiguate by class (the form submit uses `Mixins-medium-OrkBY` class; the sidebar nav uses `NavRow-*`). The simplest reliable filter is to take the first visible non-nav `Create` button:

```js
() => {
  const candidates = Array.from(document.querySelectorAll('button'))
    .filter(b => /^create$/i.test((b.innerText||'').trim()) && !b.disabled && b.offsetWidth > 0)
    .filter(b => !/NavRow|navRow/.test(b.className?.toString?.() || ''));   // exclude sidebar nav
  if (candidates.length === 0) return { ok: false };
  const btn = candidates[0];
  btn.scrollIntoView({ block: 'center' });
  btn.click();
  return { ok: true, total_candidates: candidates.length };
}
```

After the click, Klaviyo redirects to a confirmation page showing the new key (the `pk_`-prefixed value). Step 5 captures it.

### Step 5 - DOM-extract the key via clipboard transit (TIME-SENSITIVE)

**Klaviyo only displays the key once on the post-create confirmation page; navigating away discards it.** There is no modal - after clicking Create on the full-page form (Step 4), Klaviyo renders a confirmation page with the new `pk_`-prefixed key. Extract before any further navigation.

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

**Validation (silent):** key starts with `pk_` and is typically 40-50 chars. If `{ ok: false }`, the confirmation page may have already been navigated away from - tell the participant: *"I missed the key, sorry - let me create another one."* Re-run Step 4.

### Step 6 - Save credentials.json

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

### Step 7 - Smoke test

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

> "All connected - your Klaviyo account **[org_name]** is ready. Ask me things like *'how many subscribers do I have?'* or *'show me my recent campaigns'*."

If the smoke fails:

- HTTP 401 → key didn't paste correctly; re-run **PHASE 1 - Install & Connect** from its Step 4.
- HTTP 400 with `revision` in message → revision header constant is stale; bump `2025-10-15` to a newer date and retry.

---

## PHASE 2 - Use Tools

**Which tools you have depends on which route connected.** Through the built-in connector the tools are `mcp__claude_ai_Klaviyo__*` - campaign and flow reporting, profile analysis, and drafting campaigns. Through the kit's own route the "tools" are the curl Patterns below. The names differ materially: there is no built-in equivalent of Pattern 9 (`/campaign-send-jobs/`), so an actual send always runs through the kit's own route even on a machine where both are connected. In the other direction, composing a campaign only exists on the built-in - Pattern 9 requires a campaign that already exists as a Draft.

Both routes hit the same live account. The real-data gate below applies whichever route you are on.

### Helper - base curl shape (the kit's own route)

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

### Real-data gate - first invocation per session

```bash
ORG_NAME="$(kl_get "/accounts/" | jq -r '.data[0].attributes.contact_information.organization_name')"
```

Tell the participant: *"Just confirming - you're connected to your real Klaviyo account **[org_name]**. Anything I do here changes your live audience. OK to proceed with **[summary]**?"* Wait for OK. ONCE per session.

### Destructive-op gate - every write

Patterns 5, 9, 10 below. Confirmation prompts:

| Operation | Prompt |
|---|---|
| Add profile to list | "I'm about to add **[email]** to your **[List Name]** list. They'll start receiving your campaigns. OK?" |
| Send campaign | "I'm about to **send** campaign **[Subject]** to **[List/Segment]** (**[N]** recipients). This is irreversible. Are you sure?" |
| Suppress profile | "I'm about to **suppress** **[email]** - they won't receive any future emails or SMS from you. OK?" |

### Common Pattern 1 - List profiles

```bash
kl_get "/profiles?page%5Bsize%5D=20" | jq '.data[] | {id, email: .attributes.email, first_name: .attributes.first_name, created: .attributes.created, last_event_date: .attributes.last_event_date}'
```

Klaviyo paginates via `page[size]` (max 100). Use `page[cursor]` from previous response's `links.next` for next page.

**Use when:** "list my subscribers", "show profiles"

### Common Pattern 2 - Get profile by email

```bash
EMAIL="<email>"
kl_get "/profiles?filter=equals(email,\"$EMAIL\")" | jq '.data[0] | {id, email: .attributes.email, properties: .attributes.properties, location: .attributes.location}'
```

Klaviyo's filter syntax uses JSON:API: `filter=equals(field,"value")`. Other operators: `greater-than`, `less-than`, `contains`, `starts-with`.

**Use when:** "find [email]", "look up [email]", "what's [email]'s info?"

### Common Pattern 3 - List lists

```bash
kl_get "/lists?page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, created: .attributes.created, count: .attributes.profile_count}'
```

Klaviyo lists are explicit static groupings (vs Segments which are dynamic). Returns name + profile count.

**Use when:** "what lists do I have?", "show my lists"

### Common Pattern 4 - List segments

```bash
kl_get "/segments?page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, created: .attributes.created, definition: .attributes.definition}'
```

Segments are dynamic: members are recomputed live based on behaviour rules (e.g., "purchased in last 30 days"). The `definition` field encodes the rule.

**Use when:** "my segments", "behavioural audiences", "who matches X"

### Common Pattern 5 - Add profile to list (write, gated)

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

### Common Pattern 6 - List recent campaigns

```bash
kl_get "/campaigns?filter=equals(messages.channel,\"email\")&page%5Bsize%5D=20" | jq '.data[] | {id, name: .attributes.name, status: .attributes.status, send_time: .attributes.send_time}'
```

Filter by `messages.channel` = `email` or `sms`. Status: `Draft`, `Queued`, `Sent`, `Cancelled`. Klaviyo's campaigns include both email and SMS.

**Use when:** "my campaigns", "recent newsletters", "what SMS have I sent?"

### Common Pattern 7 - Campaign performance with revenue

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

The Reports API is Klaviyo's canonical analytics endpoint - synchronous for small queries, async for big date ranges. For the workshop's common case (single campaign report), this returns a small payload immediately.

**Use when:** "how did [campaign] perform?", "campaign revenue", "opens for [campaign]"

### Common Pattern 8 - Top flows by revenue

Flows are Klaviyo's automations (welcome series, abandoned cart, post-purchase, etc.).

```bash
kl_post "/flow-values-reports/" "$(jq -n '{data:{type:"flow-values-report", attributes:{statistics:["conversion_value","recipients"], timeframe:{key:"last_30_days"}}}}')" \
  | jq '.data.attributes.results | sort_by(.statistics.conversion_value) | reverse | .[:10]'
```

Returns the top 10 flows by attributed revenue in the last 30 days. Critical metric for e-commerce SMBs.

**Use when:** "best automations", "top flows", "what's driving sales?"

### Common Pattern 9 - Send a campaign (write, gated, IRREVERSIBLE)

Apply the **Send campaign** gate first. The campaign must already exist as a Draft - this route doesn't compose campaigns from scratch (Klaviyo's template + Universal Content surface is too complex for v1). The draft can come from Klaviyo's web UI, or from the built-in connector, which does compose campaigns as drafts. That pairing - draft on the built-in, send here - is the intended shape of this pattern.

```bash
CAMPAIGN_ID="<from Pattern 6 (filter status='Draft')>"
kl_post "/campaign-send-jobs/" "$(jq -n --arg cid "$CAMPAIGN_ID" '{data:{type:"campaign-send-job", id:$cid}}')"
```

Response: 202 Accepted. The campaign queues for send; actual delivery starts within a few minutes.

Tell the participant: *"**[Campaign Name]** is sending now to **[N]** recipients. You'll see open/click numbers within an hour."*

**Use when:** "send [campaign]", "launch newsletter"

### Common Pattern 10 - Suppress profile (write, gated)

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
| "Write me a campaign" / "Draft a newsletter" | Built-in connector (`mcp__claude_ai_Klaviyo__*`) - the kit's own route cannot compose |
| "Connect Klaviyo" / "Set up Klaviyo" | **Run Phase 0, then Route by need** |

---

## Error Handling

| Error | What it means | How to respond |
|---|---|---|
| HTTP 401 `unauthorized_request` | API key revoked / invalid | Translate: "Looks like the connection was disconnected - let me reconnect." Re-run **PHASE 1 - Install & Connect**. |
| HTTP 400 with `revision` in message | Klaviyo deprecated the revision constant the SKILL pins to | Bump the revision string in credentials.json + the SKILL's helper to a newer date (Klaviyo publishes revisions roughly every 3 months). |
| HTTP 400 `validation_error` | Filter syntax wrong (Klaviyo's JSON:API filters are strict) | Diagnose silently, retry. |
| HTTP 403 `insufficient_scope` | Private API key was created as a `Read-Only Key` when the operation needs `Full Access Key` | Tell participant: "I need a key with full access - let me create a new one." Re-run **PHASE 1 - Install & Connect** Step 4 with the `Full Access Key` access level. |
| HTTP 404 on `/profiles/<id>` | Profile id stale (deleted or never existed) | Re-fetch via Pattern 2 (filter by email). |
| HTTP 429 | Hit Klaviyo's burst rate cap (75 req/s burst, 700 req/min steady on most endpoints) | Wait 30s, retry once. Surface plain English if still hitting. |
| HTTP 202 with no `data.id` on writes | Async job queued; processing takes seconds-minutes | Note: this is success, not error. Tell participant the action is processing. |

Translate every error to plain English. Never show raw HTTP bodies.

---

## Scope Limitations

**Built-in connector.** Covers campaign performance analysis, flow analysis, profile insights, and campaign creation as drafts. It cannot send a drafted campaign end to end (Klaviyo targets Q3 2026), and flow creation is capped at roughly 100 a day.

**The kit's own route** (everything below):

This connector **can**:

- Read all standard endpoints: profiles, lists, segments, campaigns (email + SMS), flows, tags, events, accounts.
- Generate campaign + flow performance reports via `/campaign-values-reports/` and `/flow-values-reports/`.
- Add profiles to lists.
- Send a draft campaign that already exists in Klaviyo's web UI.
- Suppress profiles (hard unsubscribe).

It **cannot**:

- **Compose campaigns from scratch** - Klaviyo's drag-drop editor + Universal Content is the participant's design surface; this route doesn't generate email HTML or SMS message content. The built-in connector does create campaigns as drafts, so route "write me a campaign" there.
- **Modify flows** - flow definition is a visual builder; v1 reads metrics, doesn't edit.
- **Manage Klaviyo Forms** (popups, embedded signup forms) - separate API surface, not in v1.
- **Bulk operations beyond suppression** - `/data-privacy-deletion-jobs/` exists for GDPR-style data deletion but is high-stakes; tracked as v2.
- **A/B testing / Multivariate campaign creation** - separate workflow, not in v1.
- **Coupon code generation** - Klaviyo's coupon endpoints are e-commerce-integration-specific; not in v1.
- **SMS consent management** - SMS in Klaviyo has stricter consent requirements; v1 treats SMS campaigns as read-only.

It **requires** the Private API key to be a `Full Access Key` (not `Read-Only Key`) for Patterns 5/9/10. `Read-Only Keys` work for Patterns 1-4 + 6-8.

---

## Behaviour Guidelines (PHASE 2)

- **Real-data awareness** - every PHASE 2 call hits real Klaviyo data, on either route. Real-data gate on first call per session; per-write gate on every write.
- **List vs Segment vocabulary** - Klaviyo treats Lists (static) and Segments (dynamic) as different objects. When a participant says "my audience", clarify which they mean if needed.
- **Email vs SMS** - Klaviyo campaigns can be email OR SMS. The channel is in `attributes.messages.channel`. Patterns that filter campaigns should specify channel.
- **Revenue formatting** - `conversion_value` is in the participant's account currency (USD/EUR/GBP/etc.) and returned as numeric. Format as currency.
- **Date format** - Klaviyo uses ISO-8601 (`2026-06-02T05:30:00Z`).
- **Pagination** - `page[size]=N` (max 100); `page[cursor]=...` from `links.next`. Multi-page operations should cap at 5 pages unless the participant asks for more.
- **Auth errors** → on the built-in connector, send the participant to Reconnect on `https://claude.ai/customize/connectors`; on the kit's own route, re-run **PHASE 1 - Install & Connect**. Do not ask the participant to "run a command" - you run it.
- **Never log or echo the API key** - `api_key` is the only secret. Never appears in participant-visible output.
- **Suppression is firm** - Pattern 10 affects deliverability across ALL of the participant's audience. Gate is strict.
- **Sending is irreversible** - Pattern 9's gate uses "Are you sure?" (stronger than "OK?").

---

## Related Skills

- **`mailchimp-connector`**: Sibling Tier-1 email-marketing connector. Same single-mode + API-key paste pattern; same per-write gates. Recommend Mailchimp for newsletter-style SMBs (blog readers, info-product creators); Klaviyo for e-commerce SMBs (Shopify/WooCommerce stores) because Klaviyo's flows + revenue attribution are tightly coupled to commerce events.
- **`myob-connector`**: Reference Direct-REST + Playwright pattern. credentials.json atomic write borrowed verbatim.
- **`quickbooks-connector`**: Sibling autonomous-Phase-1 connector. Communication rules + gate prose model.
- **`google-ads-connector`** / **`gusto-connector`**: Sibling Tier-1 Direct-REST connectors (different complexity tiers - these have two-mode designs, Klaviyo is single-mode like Mailchimp).
- **`superpowers:systematic-debugging`**: For revision-header / scope edge cases.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - three-pattern decision tree. Direct-REST connector (out-of-scope for that doc; sibling shape to `mailchimp-connector` and `myob-connector`).
- [Klaviyo API overview](https://developers.klaviyo.com/en/reference/api_overview) - official endpoint catalogue + auth shape.
- [Klaviyo API key management](https://help.klaviyo.com/hc/en-us/articles/115005062267) - how to manage existing keys.
- [Klaviyo Private API Key creation](https://help.klaviyo.com/hc/en-us/articles/7423954176283) - exact UI flow the kit's own route Step 4 drives.
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` - say "audience" / "profiles" to participants. Klaviyo uses both "profiles" and "subscribers" interchangeably in its UI.
