---
name: mailchimp-connector
description: "Connect Mailchimp to Claude by switching on its built-in Intuit Mailchimp connector, or by installing and authenticating its API credentials. Use when the user asks to set up or connect Mailchimp, or wants Mailchimp work (audiences, subscribers, campaigns, tags, reports) and Mailchimp isn't connected yet. Once connected, Mailchimp runs through the mcp__claude_ai_Intuit_Mailchimp__* tools, or directly against its API with the stored credentials."
allowed-tools: Bash, Read, Write, Edit, mcp__claude_ai_Intuit_Mailchimp__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*
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

This skill lets you read and operate a user's Mailchimp account on their behalf using **Mailchimp Marketing API v3** (no MCP server, no first-party CLI - Direct-REST + Playwright pattern). `skills/CLAUDE.md` documents the three install patterns (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace) and marks direct-REST connectors as out-of-scope for that doc; this SKILL follows the `myob-connector` shape (loopback listener for OAuth - or in our case API-key clipboard transit - plus atomic `credentials.json` write).

### Mailchimp is built into Claude - start there

Mailchimp has its own listing in Claude's connector directory, under the display
name **Intuit Mailchimp** (`https://claude.ai/directory/intuit-mailchimp`, made by
Intuit Mailchimp, connector URL `https://ai-inc.mailchimp.com/claude/mcp/v2`,
added March 2026, in-chat UI, sign-in required; docs at
`https://mailchimp.com/help/use-mailchimp-connector-claude`). The plain
`mailchimp` slug does **not** resolve - only `intuit-mailchimp` does, the
`claude mcp list` line reads `claude.ai Intuit Mailchimp`, and the tools are
`mcp__claude_ai_Intuit_Mailchimp__*`. Get all three wrong and you will conclude
there is no listing when there is one.

Switching it on is one button and a sign-in - nothing installed, no key for this
skill to store, and the connection is account-level, so it works everywhere that
claude.ai account is signed in.

**But the built-in is narrow.** Per Mailchimp's own help page it is focused on
*campaign planning, editing and saving*: building data-backed campaign plans
across email, SMS and social from business goals, generating ready-to-use email
and social layouts, editing copy, colours, tone and layout in plain language,
recommending off past Mailchimp performance, and saving the plan back to the
Mailchimp account as a draft. The page documents no audience or subscriber
management, no tagging or segments, no reports surface, no automations, no
templates, and no send or schedule - drafts only. So this skill keeps both
routes, and Phase 0.5 routes between them by what the user actually wants.

Requirements the help page names for the built-in: active Claude and Mailchimp
accounts, and **Owner or Admin** permissions on both.

It has three phases:

- **Phase 1 - Switch on the built-in Intuit Mailchimp connector.** One button,
  one sign-in, proved with a real read.
- **Phase 1 (the kit's own route) - Install & Connect (autonomous via Playwright).** Claude drives `admin.mailchimp.com` end-to-end via Playwright MCP to sign the participant in, generate a new API key from the API keys settings page, DOM-extracts the key via the clipboard-transit pattern (key never appears in tool returns), parses the data-center suffix from the key (Mailchimp API keys have the form `<32-char-token>-<dc>` e.g., `abc123def...-us21`), constructs the participant's account-specific API endpoint URL (`https://<dc>.api.mailchimp.com/3.0/`), and persists everything to `~/.config/mailchimp/credentials.json` (mode 0600). The participant's only manual moment is signing in to Mailchimp once and approving any 2FA.
- **Phase 2 - Use Tools (Direct-REST via curl).** Once `credentials.json` is configured, you `curl` Mailchimp REST endpoints with `Authorization: Bearer <api_key>`. Endpoints span audiences (`lists`), members, campaigns, reports, automations, and search. Writes (add subscriber, send campaign, unsubscribe member) are gated by plain-English confirmation prose - every Phase 2 operation hits real data (Mailchimp has no sandbox), so the gates apply unconditionally.

**Single-mode, no test/live distinction.** Mailchimp's free tier (up to 500 contacts) IS real data - there's no separate "test mode" or sandbox API. Every Phase 2 invocation touches the participant's real audience. The production-mode gates from QBO and Google Ads are the default behaviour here, not opt-in.

**API keys don't expire.** Mailchimp API keys are revocable but not time-bounded, so there's no refresh-token cycle in Phase 2. The only auth failure path is "key revoked" (HTTP 401 with `RevokedKey` in the message), which triggers re-running Phase 1 from Step 2.

**Which phase to run** - Phase 0 decides. A live built-in connection or a working
set of stored credentials both count as "connected"; only when neither is present
does anything get set up, and then Phase 0.5 decides which route. The credentials
check on its own:

```bash
test -f "$HOME/.config/mailchimp/credentials.json" && jq -r '.api_endpoint // "missing"' "$HOME/.config/mailchimp/credentials.json" 2>/dev/null || echo missing
```

- Output starts with `https://` → credentials present. Smoke-test with `GET /ping`; on success → Phase 2.
- Output `missing` → run Phase 1.

---

## Golden rule - do not open the participant's own browser

Every Phase 1 step that requires sign-in runs inside the Playwright MCP browser (`mcp__plugin_playwright_playwright__browser_*`). Never tell the participant to "open a link in your browser." Claude navigates, the participant types their Mailchimp password directly into the Playwright window, Claude reads the result programmatically. Same rule as `myob-connector` and `quickbooks-connector`.

If Playwright MCP is unavailable, stop and tell the participant: *"I need a small browser tool that's not installed yet - let me show you how to add it."* Then point them at the Playwright MCP install instructions and stop. Do not fall back to opening the participant's default browser.

**One deliberate exception: Phase 1.** Switching on the built-in connector means
opening `https://claude.ai/directory/intuit-mailchimp` in the participant's **own**
browser, because that is the browser already signed in to Claude and to Mailchimp.
The rule above exists because the route below reads a connection key off the page
inside a driven browser; the built-in page has no key on it and this skill reads
nothing from it. Never drive that sign-in with Playwright.

---

## Communication rules for Phase 1

The participant is a non-technical business owner. Every message during Phase 1 must follow these rules:

- **One step at a time.** Never stack two instructions.
- **Plain English only.** Never say API key, OAuth, token, scope, refresh, Bearer, REST, endpoint, JSON, data center, env var, curl, terminal, CLI, MCP, callback, loopback, sandbox, file path, or `dc` shorthand. If you must refer to a technical thing, name it plainly: "your connection key", "your Mailchimp account details", "the workshop setup step".
- **Tell them what is about to happen.** *"I'm opening Mailchimp's settings now - sign in when you see the page, and I'll do the rest. About a minute."*
- **React warmly.** Good: *"Got it - connected to your **[Audience Name]** audience."* Bad: *"Mailchimp returned 200 with valid api_endpoint; credentials.json written mode 0600."*
- **Never show error messages directly.** Translate. *"No problem - let me try a different way,"* then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the participant. You run them.
- **Never echo the API key** back to the participant - it's stored locally and never shown.

---

## ⛔ Pre-flight check - Playwright availability

**This applies to the kit's own route only.** The built-in connector needs no
browser tool: Phase 0 and Phase 1 run without Playwright, and a missing Playwright
is never a reason to stop before Phase 1.

Before starting the kit's own route, verify Playwright MCP tools are available. If `mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` tools are not in the deferred-tool surface (check via `ToolSearch +playwright`), halt and tell the participant to install Playwright MCP per `skills/CLAUDE.md`'s install contingency section. Do not start the kit's own route without Playwright.

---

## PHASE 0 - Is Mailchimp already connected?

Run these silently, in order, and act on the first that answers.

### Step 0.1 - Built-in connector

```bash
claude mcp list 2>&1 | grep -i "^claude.ai Intuit Mailchimp"
```

Match on **Intuit Mailchimp**, not "Mailchimp" - that is the display name the
directory uses and the line `claude mcp list` prints.

- `✔ Connected` → the built-in is live. Prove it with one read from the
  `mcp__claude_ai_Intuit_Mailchimp__*` tools before saying so, then go to
  **Phase 0.5** - if what the participant wants is inside the built-in's reach,
  you are done and go straight to Phase 2; if it isn't, the kit's own route is
  still needed on top.
- `! Needs authentication` → the connection has lapsed. Open
  `https://claude.ai/customize/connectors` in the participant's own browser and
  say: *"Your Mailchimp connection needs a quick re-sign-in. Press Reconnect next
  to Intuit Mailchimp, sign in, and tell me when it says Connected."* Then re-run
  this check.
- No such line → continue.

### Step 0.2 - Read existing credentials (the kit's own route)

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

- **`missing`** → continue to Phase 0.5.
- **Anything starting with `https://`** → smoke-test (`GET /ping`) and:
  - 200 → the kit's route is live and working. Say *"Mailchimp is already
    connected"* and go to Phase 2. Do not set the built-in up on top of it unless
    the participant asks for something the kit's route can't do.
  - 401 → key revoked or invalid; tell the participant *"Looks like the connection was disconnected - let me set up a new one."* and re-run the kit's own route (or offer the built-in, which is faster).
  - Other error → translate and diagnose silently.

### Step 0.3 - Nothing found

Go to Phase 0.5.

If you cannot run commands at all (you are in claude.ai chat or the desktop app
rather than Claude Code), skip Steps 0.1-0.2: go to Phase 0.5, then Phase 1, and
prove the result at Phase 1 Step 5 by calling one of Mailchimp's tools.

---

## PHASE 0.5 - Route by need

Ask **one** plain-English question before setting anything up: *"What do you want
Claude to do with your Mailchimp?"* Offer the two shapes as examples - *"plan and
write campaigns, or work with your contact lists and results?"* One question, then
act; do not turn this into a questionnaire.

Then route:

| What the participant wants | Route | Why |
|---|---|---|
| Plan a campaign across email, SMS or social from a business goal | **Built-in** (Phase 1) | this is what the built-in is built for |
| Generate a ready-to-use email or social layout | **Built-in** | layouts come with the connector's in-chat UI |
| Edit a campaign's copy, colours, tone or layout in plain language | **Built-in** | |
| Recommendations based on how past Mailchimp campaigns performed | **Built-in** | |
| Save a campaign plan back into Mailchimp as a draft | **Built-in** | drafts only - see below |
| List, search or count audiences, subscribers or members | **The kit's own route** | not documented on the built-in |
| Add, unsubscribe, tag or segment a contact | **The kit's own route** | |
| Pull audience growth stats or a campaign performance report | **The kit's own route** | |
| Automations, templates, or anything the help page doesn't name | **The kit's own route** | |
| **Actually send or schedule a campaign** | **The kit's own route** | Mailchimp's help page describes the built-in as saving drafts; it documents no send or schedule |

Rules for using this table:

- Connect only what they named. If the built-in covers it, stop there - do not
  put the participant through the key-and-Power-Up route for no reason.
- Say in one line what you are *not* connecting and why, so they can ask later.
- Both routes can coexist on one machine. Never tear one down to set the other up.
- The "not documented" rows are the help page's silence, not a tested refusal. If
  a participant is already on the built-in and asks for one of them, it costs
  nothing to try the built-in's tools once; fall through to the kit's route on a
  real failure, not on an assumption.

---

## PHASE 1 - Switch on the built-in Intuit Mailchimp connector

One button and a sign-in, once per account. The participant needs **Owner or
Admin** permissions on both Claude and Mailchimp - that is Mailchimp's own
requirement for this connector.

### Step 1 - Check this session can see built-in connectors

```bash
claude auth status
```

`"authMethod": "claude.ai"` is the pass. Anything else - or
`disableClaudeAiConnectors: true` in `~/.claude/settings.json`, or
`ENABLE_CLAUDEAI_MCP_SERVERS=false` - means built-in connectors will not appear in
this session. Tell the participant in one line that this copy of Claude is signed
in a different way, and run the kit's own route instead.

### Step 2 - Open the connector page for them

Say: *"I'm opening Mailchimp's page in your browser. Press **Connect to Claude**,
sign in to Mailchimp the way you normally do, and say yes when it asks for access.
That's the only part only you can do - tell me when it says Connected."*

```bash
open "https://claude.ai/directory/intuit-mailchimp"          # Mac
# xdg-open "https://claude.ai/directory/intuit-mailchimp"    # Linux
# start "" "https://claude.ai/directory/intuit-mailchimp"    # Windows
```

If that page doesn't load, open `https://claude.ai/customize/connectors` instead
and tell them: Browse → search "Mailchimp" → Connect. It is listed as **Intuit
Mailchimp**.

### Step 3 - Wait

Hands off while they sign in. Never ask for a password, a code, or a screenshot of
the sign-in.

### Step 4 - Verify

```bash
claude mcp list 2>&1 | grep -i "^claude.ai Intuit Mailchimp"
```

`claude.ai Intuit Mailchimp: https://ai-inc.mailchimp.com/claude/mcp/v2 - ✔ Connected`
is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no
line at all means the Connect didn't complete, so send them back to Step 2.

### Step 5 - Prove it

Call one real read through the connector - one tool from the
`mcp__claude_ai_Intuit_Mailchimp__*` namespace. Only a real answer counts; a tool
error here is not "connected". These tools are often deferred in a session, so fetch the namespace first. If the namespace is missing from this session entirely even though Step 4 passed, the session started before the Connect: a running session loads its claude.ai connectors once, at start. Ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again.

### Step 6 - Hand off

Two lines: Mailchimp is connected, and three things they can ask for now ("plan a
launch campaign for next month", "draft a re-engagement email", "what worked best
in my last three campaigns"). If Phase 0.5 flagged needs the built-in doesn't
cover, say in one line that you can set up the fuller connection too, and offer it.

**Team or Enterprise accounts:** if the page shows **Request** instead of
**Connect**, the participant's Claude administrator has to switch Mailchimp on for
the organisation first. Say so plainly and stop; do not fall back to the kit's own
route just to get past an admin gate.

---

## PHASE 1 - Install & Connect (autonomous via Playwright) - the kit's own route

### Step 1 - Welcome message

Send one short message:

> "Great - connecting your Mailchimp. I'll open Mailchimp's settings in a small browser window. Please sign in (and approve any verification code Mailchimp sends to your phone or email) - I'll do the rest. About a minute."

### Step 2 - Open Mailchimp's Create-API-Key modal directly

```
mcp__playwright__browser_navigate({ url: "https://admin.mailchimp.com/account/api/manage/" })
```

**Critical: navigate to `/account/api/manage/`, NOT `/account/api/`.** Mailchimp's settings UI is now wrapped in an Intuit-owned shell (`uxfabric.app.intuit.com` plumbing - Intuit acquired Mailchimp in 2021). The legacy `/account/api/` route renders the API keys listing **inside an iframe** (`id="fallback"` at `/i/account/api/`), which Playwright's outer-document DOM queries cannot reach without `frameLocator`-style traversal. The `/account/api/manage/` route auto-opens the **"Name New API Key" modal at the outer shell level** - same modal you'd reach by clicking the iframe's "Create A Key" button, but accessible from the top frame directly. This was verified live on rodolfo@selrai.com.au's account 2026-06-02.

**Do NOT snapshot the sign-in page** (password-leak risk - see `reference_playwright_snapshot_password_leak`). Use:

```
mcp__playwright__browser_wait_for({ text: "Name New API Key", time: 60 })
```

The text "Name New API Key" is the modal heading and only appears post-sign-in once the modal renders. If the participant has multiple Mailchimp accounts on their Google sign-on, Mailchimp may present an account-chooser before the page renders. Wait for the heading; if the participant gets stuck on the chooser, check in: *"Which Mailchimp account should I connect to?"* and wait for their reply.

> **Onboarding note**: brand-new Mailchimp accounts (those still on the 5-step onboarding wizard at the dashboard) can reach the API keys modal anyway - the wizard is non-blocking. Don't make the participant complete the wizard first.

### Step 3 - Fill the name field and click Generate Key

The `/account/api/manage/` route auto-opens the **"Name New API Key" modal** - no separate Create button click needed. The modal contains a single text input (labeled `API Key Name`) and a `Generate Key` button.

Fill the name via React-friendly setter (the modal's input is the only visible text input on the page when the modal is open):

```js
() => {
  const inputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'));
  const visible = inputs.filter(i => i.offsetWidth > 0 && i.offsetHeight > 0);
  if (visible.length === 0) return { ok: false, reason: 'no_visible_input' };
  const target = visible[0];
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  target.focus();
  setter.call(target, 'Claude Workshop Connector');
  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true };
}
```

Then click the dialog's `Generate Key` button:

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^generate key$/i.test((b.innerText||'').trim()) && !b.disabled);
  if (!btn) return { ok: false };
  btn.scrollIntoView({ block: 'center' });
  btn.click();
  return { ok: true };
}
```

After ~2-4 seconds Mailchimp generates and displays the new key on the same page (no navigation). The key is shown **once** - closing or refreshing the page makes it unrecoverable. Step 4 captures it immediately.

> **Button-copy reality check (2026-06-02)**: the button reads `Generate Key` (not `Create`, `Save`, `Submit`). The regex above is intentionally strict to this - broader variants like `/^(generate|create|save)/i` would match unrelated buttons elsewhere on the page (e.g., the top-nav `Create` campaign button). If Mailchimp's button copy drifts in future, snapshot the dialog to find the new label.

### Step 4 - DOM-extract the API key via clipboard transit

Before extracting, save the participant's existing clipboard so it can be restored after Step 6:

```bash
SAVED=$(wl-paste 2>/dev/null | base64 -w0)
echo "$SAVED" > /tmp/mailchimp-prev-clipboard.b64
```

(`wl-paste` on Linux/Wayland; `pbpaste` on macOS; `powershell.exe Get-Clipboard` on Windows Git Bash - detect at runtime.)

Then extract:

```js
async () => {
  // Find any element whose visible text matches Mailchimp's API-key shape: 32 hex chars + '-' + dc prefix
  const re = /\b([a-f0-9]{30,36}-[a-z]{2,4}[0-9]{1,3})\b/i;
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

Return values: only `key_len` and `dc` (the data-center prefix is not sensitive - it's a public Mailchimp shard identifier like `us21`). The full API key value is in the clipboard and never appears in the tool return.

**Validation (silent):** key is typically 36-38 chars total (32 hex + `-` + 2-4 char dc), all lowercase. If the extract returns `{ ok: false }`, re-snapshot the page and look for a different display widget; fall back to asking the participant: *"I'm having trouble reading your new key - could you paste it for me?"* The key transits the transcript in this fallback path; that's an accepted tradeoff if DOM extraction fails.

### Step 5 - Save `credentials.json`

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

### Step 6 - Smoke test

```bash
API_KEY="$(jq -r .api_key "$HOME/.config/mailchimp/credentials.json")"
API_ENDPOINT="$(jq -r .api_endpoint "$HOME/.config/mailchimp/credentials.json")"

curl -sf "$API_ENDPOINT/ping" \
  -H "Authorization: Bearer $API_KEY" \
  | jq -r '.health_status'
```

Expect: `"Everything's Chimpy!"`. On success, tell the participant:

> "All connected - your Mailchimp is ready. Ask me things like *'how many subscribers do I have?'* or *'show me my recent campaigns'*."

If the smoke fails (HTTP 401 or non-200), translate to plain English and re-check Steps 3-5 silently.

---

## PHASE 2 - Use Tools

**Which surface you are on.** Through the built-in connector (Phase 1), Mailchimp
work runs through the `mcp__claude_ai_Intuit_Mailchimp__*` tools, with the
connector's own in-chat UI for layouts, and nothing read from disk. Through the
kit's own route it runs through the curl loop below. They differ materially: the
built-in plans, writes and edits campaigns and saves them as drafts but documents
no audience, subscriber, tag, report, template or automation surface and no send;
the curl loop below does all of that, including the irreversible send in Common
Pattern 9. If the participant is on the built-in and asks for something in the
second list, offer the kit's own route rather than improvising.

Phase 2 runs after Phase 1 completes. Every call reads `~/.config/mailchimp/credentials.json` for `api_key` + `api_endpoint`, then `curl`s the Mailchimp REST API.

### Helper - base curl shape

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

### Real-data gate - soft confirmation on first invocation

On the first Phase 2 tool call of a session, run:

```bash
mc_get "/" | jq -r '.account_name'
```

(The Mailchimp root endpoint returns the account name and ID - quick identity check.)

Tell the participant:

> "Just confirming - you're connected to your real Mailchimp account **[account_name]**. Anything I do here changes your live audience. OK to proceed with **[summary of what they asked]**?"

Wait for OK. Apply ONCE per session, not per tool call.

### Destructive-op gate - confirm every write

For Patterns 3, 4, 9, and 10 below (add subscriber, tag, send campaign, unsubscribe), confirm in plain English BEFORE the API call:

| Operation | Prompt |
|---|---|
| Add subscriber | "I'm about to add **[email]** to your **[Audience]** audience. They'll start receiving your campaigns from now on. OK?" |
| Tag subscriber | "I'm about to tag **[email]** with **[tag]** in your **[Audience]** audience. OK?" |
| Send campaign | "I'm about to **send** campaign **[Subject Line]** to **[N]** people in **[Audience]**. This is irreversible - once sent, those emails are out. Are you sure?" |
| Unsubscribe member | "I'm about to unsubscribe **[email]** from your **[Audience]** audience. They won't receive future campaigns until they opt back in. OK?" |

Per-write call, not per-session.

### Common Pattern 1 - List audiences

```bash
mc_get "/lists?count=20" | jq '.lists[] | {id, name, stats: {member_count: .stats.member_count, unsubscribe_count: .stats.unsubscribe_count}}'
```

Returns audience id, name, current subscriber count, total unsubscribes. Present as a simple list.

**Use when:** "what audiences do I have?", "list my lists", "show audiences"

### Common Pattern 2 - List subscribers in an audience

```bash
LIST_ID="<from Pattern 1>"
mc_get "/lists/$LIST_ID/members?count=50&status=subscribed" | jq '.members[] | {email_address, status, timestamp_signup}'
```

Returns email, status, signup date. Filter `status=subscribed` to skip unsubscribed/cleaned. Use `count=` up to 1000.

**Use when:** "show my subscribers", "list everyone in [audience]"

### Common Pattern 3 - Add a subscriber (write, gated)

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

Response includes the new member id + `subscriber_hash` (the MD5 of the lowercased email - used in subsequent member-specific URLs). Tell the participant: *"Added **[email]** to your **[Audience]**."*

> **Compliance note**: setting `status:"subscribed"` skips the double-opt-in flow. Mailchimp's terms require explicit consent for that - if the participant is adding someone from a manual signup form they themselves received, this is fine. If they're adding someone whose consent they don't have, use `status:"pending"` instead (Mailchimp sends a confirmation email). When in doubt, use `pending`.

**Use when:** "add [email]", "subscribe [email]", "add [name] to my audience"

### Common Pattern 4 - Tag a subscriber (write, gated)

Apply the **Tag subscriber** gate first. Compute the subscriber hash:

```bash
EMAIL="<email>"
HASH="$(echo -n "${EMAIL,,}" | md5sum | awk '{print $1}')"
mc_post "/lists/$LIST_ID/members/$HASH/tags" "$(jq -n --arg t "$TAG" '{tags:[{name:$t, status:"active"}]}')"
```

To remove a tag, set `status:"inactive"`.

**Use when:** "tag [email] as [tag]", "add tag X to [email]"

### Common Pattern 5 - Audience growth stats

```bash
LIST_ID="<from Pattern 1>"
mc_get "/lists/$LIST_ID/growth-history?count=12" | jq '.history[] | {month, existing, imports, optins, optouts}'
```

Returns the last 12 months of: existing subscribers at month-start, new imports, opt-ins, opt-outs. Present as a monthly trend.

**Use when:** "audience growth", "subscriber trend", "is my list growing?"

### Common Pattern 6 - List recent campaigns

```bash
mc_get "/campaigns?count=20&sort_field=send_time&sort_dir=DESC&status=sent" | jq '.campaigns[] | {id, settings: {subject_line: .settings.subject_line}, send_time, emails_sent}'
```

Returns campaign id, subject line, send time, emails sent. Filter `status=sent` to skip drafts.

**Use when:** "my campaigns", "recent campaigns", "what newsletters have I sent?"

### Common Pattern 7 - Campaign performance report

```bash
CAMPAIGN_ID="<from Pattern 6>"
mc_get "/reports/$CAMPAIGN_ID" | jq '{emails_sent, opens: .opens.unique_opens, open_rate: .opens.open_rate, clicks: .clicks.unique_clicks, click_rate: .clicks.click_rate, unsubscribed}'
```

Returns sends, unique opens, open rate, unique clicks, click rate, unsubscribes. Present as a table.

**Use when:** "how did [campaign] do?", "open rate for [campaign]", "campaign performance"

### Common Pattern 8 - Search for a subscriber by email

```bash
EMAIL="<email>"
mc_get "/search-members?query=$EMAIL" | jq '.exact_matches.members[] | {id, list: .list_id, email_address, status}'
```

Returns all audiences the email appears in. Useful for "where is [email] subscribed?"

**Use when:** "find [email]", "where is [email] subscribed?", "look up [email]"

### Common Pattern 9 - Send a campaign (write, gated, IRREVERSIBLE)

Apply the **Send campaign** gate first. The participant must have already drafted the campaign in Mailchimp's web UI - this SKILL doesn't compose campaigns from scratch (the templating + rich-content surface is too complex for v1).

```bash
CAMPAIGN_ID="<from Pattern 6 (filter status='save' for drafts)>"
mc_post "/campaigns/$CAMPAIGN_ID/actions/send" ""
```

Empty body. Response is empty 204 on success.

Tell the participant: *"**[Subject]** is now sending to **[N]** subscribers. You'll see open/click numbers within an hour or two."* - never imply the campaign is "delivered" instantly (Mailchimp queues sends in waves).

**Use when:** "send [campaign]", "send the newsletter"

### Common Pattern 10 - Unsubscribe a member (write, gated)

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
| HTTP 401 `Your API Key may be invalid` | Key revoked from admin.mailchimp.com or wrong DC suffix | Tell the participant *"Looks like the connection was disconnected - let me set up a new one."* Re-run Phase 1. |
| HTTP 401 `RevokedKey` | Key explicitly revoked | Same as above. |
| HTTP 403 `User does not have access` | Account-level permission issue (rare on free tier) | Tell the participant *"Mailchimp says I don't have permission for that. Let me reconnect."* Re-run Phase 1. |
| HTTP 404 `Resource not found` on `/lists/<id>` | Audience id is stale or wrong | Re-list audiences (Pattern 1), use the current id. |
| HTTP 404 on `/lists/<id>/members/<hash>` | Subscriber hash is wrong (probably miscomputed) | Verify the hash: lowercase email, then MD5. |
| HTTP 400 `Invalid Email Address` on Pattern 3 | Email failed Mailchimp's regex (usually a typo) | Translate: *"That doesn't look like a valid email - want to double-check?"* |
| HTTP 400 `Member Exists` on Pattern 3 | Email already in the audience (possibly unsubscribed) | Translate: *"[email] is already in [audience] (might be unsubscribed). Want me to resubscribe them?"* - if yes, PATCH the member with `status: subscribed`. |
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

- **Compose campaigns from scratch** - Mailchimp's template + drag-drop editor is the participant's canvas; this SKILL doesn't generate HTML email content. The participant drafts in Mailchimp's web UI; Claude sends.
- **Manage automations** (Customer Journeys / Classic Automations) beyond reading status - modifying these requires the Marketing API's complex automation endpoints not covered in v1.
- **Bulk operations** (`/batches`) - not in v1; tracked as a future enhancement for participants with very large audiences.
- **E-commerce data** (`/ecommerce/stores/*`) - separate API surface, not in v1.
- **Transactional emails** (Mandrill / Mailchimp Transactional) - that's a separate product with its own API and pricing tier.
- **File Manager / merge field bulk updates** - not in v1's 10 patterns.

It **requires** the participant to be the Mailchimp account owner or have an Admin role - viewer/author roles can't create API keys.

---

## Behaviour Guidelines (Phase 2)

- **Real-data awareness** - every Phase 2 call hits the participant's real audience. Apply the real-data gate on the first call per session; apply the per-write gate on every write.
- **Audience-id discovery** - most patterns need a `list_id` (Mailchimp's term for audience). If the participant says "my audience" and there's only one, use it silently. If there are multiple, ask which.
- **Subscriber hash** - Mailchimp uses the MD5 of the lowercased email as the URL identifier for member-specific endpoints. Compute as: `printf "%s" "${EMAIL,,}" | md5sum | awk '{print $1}'`.
- **Date format** - Mailchimp returns ISO-8601 timestamps. Present as friendly relative ("3 days ago") or absolute ("2026-05-30") depending on context.
- **Format counts and rates correctly** - open_rate / click_rate are decimal fractions (`0.245` = 24.5%). Multiply by 100 for display.
- **Auth errors** → re-run Phase 1 from Step 2. Do not ask the participant to "run a command" - you run it.
- **Never log or echo the API key** - `api_key` is the only secret in `credentials.json`. Never include it in any output visible to the participant.
- **Compliance defaults** - Pattern 3's `status:"pending"` (double-opt-in) is the safe default when the participant adds an unfamiliar email; switch to `status:"subscribed"` only when the participant confirms they already have explicit consent.
- **Sending is irreversible** - Pattern 9's gate is firmer than the others ("Are you sure?" rather than "OK?") because once sent, emails can't be recalled.

---

## OAuth2 - advanced alternative (NOT primary path)

Mailchimp supports OAuth2 for apps with multiple end-users or for cases where the participant prefers not to issue an API key. The current SKILL defaults to API key because:

1. API key creation is a single ~30-second flow (sign in → API keys page → Create A Key → name it → copy).
2. OAuth2 requires registering an app at `admin.mailchimp.com/account/oauth2_client/` first (~3 min), then doing the OAuth dance with a localhost redirect URI loopback listener - same shape as `myob-connector` Phase 1.
3. For single-participant workshop use cases, the friction-per-feature ratio favours API keys.

If a future participant needs OAuth2 (e.g., they're building an app that other people will install), the OAuth2 endpoints are:

- Authorize: `https://login.mailchimp.com/oauth2/authorize`
- Token: `https://login.mailchimp.com/oauth2/token`
- Metadata: `https://login.mailchimp.com/oauth2/metadata` (returns `dc` + `api_endpoint` after token issued)

The OAuth2 flow is documented as a v2 enhancement; current `credentials.json` schema supports either path (the `api_key` field can hold an API key OR an OAuth2 access token - Mailchimp treats them identically at the API request layer).

---

## Related Skills

- **`myob-connector`**: Reference SKILL for Direct-REST + Playwright. Phase 1 atomic credentials.json write, single-mode pattern, bearer-on-curl Phase 2 all borrowed from MYOB. MYOB's OAuth complexity is reduced here to a single API key paste, but the file structure mirrors MYOB's.
- **`quickbooks-connector`**: Sibling autonomous-Phase-1 connector. Same plain-language communication rules. QBO's mode-detection + production-mode gates were the template for this SKILL's real-data + destructive-op gates.
- **`google-ads-connector`**: Sibling Tier-1 Direct-REST connector. Heavier (test vs Basic Access modes) than Mailchimp; reference for the per-write confirmation pattern.
- **`ghl-connector`**: Sibling marketing connector (different vendor, Hosted-bearer-PAT pattern). Reference if a participant has BOTH GHL and Mailchimp - different APIs, similar workshop UX.
- **`superpowers:systematic-debugging`**: For troubleshooting unexpected Mailchimp API responses.

## See also

- [`skills/CLAUDE.md`](../CLAUDE.md) - the install-pattern decision tree. This SKILL is a **both**-fate connector: Pattern 0 (built-in) first, with its direct-REST route (sibling shape to `myob-connector`) kept in full for the gap.
- [`https://claude.ai/directory/intuit-mailchimp`](https://claude.ai/directory/intuit-mailchimp) - the built-in connector's own page.
- [Mailchimp's connector help page](https://mailchimp.com/help/use-mailchimp-connector-claude) - what the built-in covers, and the Owner/Admin requirement.
- [Mailchimp Marketing API v3 reference](https://mailchimp.com/developer/marketing/api/) - official endpoint catalogue + rate limits + auth shape.
- [Mailchimp API keys docs](https://mailchimp.com/help/about-api-keys/) - where the kit's own route generates the key at its Step 3.
- Memory `reference_playwright_snapshot_password_leak` - sign-in page snapshot rule.
- Memory `feedback_workshop_kit_update_format` - say "audience" to participants, never "list" (Mailchimp's internal term is `list` but their UI says "audience" for the same concept).
