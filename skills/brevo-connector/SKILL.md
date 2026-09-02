---
name: brevo-connector
description: "Connect Brevo (formerly Sendinblue) to Claude by switching on its built-in connector or storing its API credentials. Use when the user asks to set up or connect Brevo, or wants Brevo work (contacts, lists, campaigns, transactional email) and Brevo isn't connected yet. Once connected, Brevo runs through the `mcp__claude_ai_Brevo__*` tools; sending, scheduling and deleting run against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*,mcp__claude_ai_Brevo__*
metadata:
  category: Marketing & Advertising
  tags:
    - brevo
    - sendinblue
    - email-marketing
    - contacts
    - transactional-email
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Brevo auth (401) or key-generation errors
    - skill: email-composer
      reason: Draft campaign or transactional email content for Brevo sends
    - skill: mailchimp-connector
      reason: Sibling email-marketing connector - same single-API-key shape; useful for comparisons/migrations
---

# Brevo Connector

## Overview

This skill lets Claude read and update a user's Brevo (formerly Sendinblue) data on their behalf - email marketing, contacts, and transactional email.

**Two routes, and the built-in one comes first.** Brevo publishes a connector in Claude's own connector directory (`https://claude.com/connectors/brevo`, display name **Brevo**, made by Brevo, on every Brevo plan). It is one click and no credentials, and it covers campaign analysis, A/B test results, contact lookup, audience/segment exploration, and drafting email campaigns, SMS campaigns and HTML templates. What it will **never** do is send, schedule or delete anything on the user's behalf. Those three verbs are the gap, and they are what the kit's own route below exists for.

The kit's own route is a **standalone direct-REST connector** - Brevo publishes no server for it, so it is the single-API-key shape, like `mailchimp-connector` / `klaviyo-connector`. Both routes can live on one machine at once; never tear one down to set the other up.

Two Brevo specifics matter to the kit's own route:

- **Auth is the `api-key` header** (a custom header name - not `Authorization`). Every call sends `api-key: xkeysib-…`.
- **The key has the `xkeysib-` prefix and CONTAINS HYPHENS** (~89 chars, e.g. `xkeysib-<hex>-<suffix>`). A `[A-Za-z0-9]`-only regex misses it; use `xkeysib-[A-Za-z0-9-]+`. The key is **shown once** at generation (Brevo gates generation behind reCAPTCHA and reveals the full key in a one-time modal with a Copy button).

The skill has these phases:

- **Phase 0 - Is Brevo already connected?** Checks the built-in connector first, then the kit's own stored credentials.
- **Phase 1 - Switch on the built-in Brevo connector.** The default route. One button, one sign-in, no credentials handled by this skill.
- **PHASE 1 - Install & Connect (autonomous via Playwright).** The kit's own route, for sending, scheduling and deleting. Claude opens the API-keys settings, the user signs in, Claude generates a `Claude Code` key with **No expiration**, captures it via the modal's Copy button, stores it (mode 600), and verifies with `/account`.
- **PHASE 2 - Use the connector.** Through the built-in connector, the tools are `mcp__claude_ai_Brevo__*`. Through the kit's own route, curl against the REST API with the `api-key` header.

**Which phase to run** - always start at Phase 0.

**Full account access.** A Brevo API key has full access to the account's contacts, campaigns, and sending. Treat it like a password.

**Existing accounts only.** This connector is for users who already have a Brevo (Sendinblue) account. Do not use it to recommend Brevo to users who do not already use it.

---

## Communication rules

The user is a non-technical business owner. Both connect routes are autonomous - the user only signs in (and, on the kit's own route, may have to tick a reCAPTCHA). Rules:

- **You drive; the user signs in.** The only ask is "please sign in to Brevo in the browser window I just opened" (and tick the 'I'm not a robot' box if it appears).
- **Plain English only.** No jargon (API, key, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection key" / "your Brevo account".
- **Never echo the key** (`xkeysib-…`). The built-in route in Phase 1 handles no key at all - say so if the user asks what you are storing.
- **No restart needed** on the kit's own route - there is no server to reconcile. (The built-in connector is the opposite: if it doesn't show up after connecting, the user fully quits and reopens Claude Code once.)

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows Brevo's login, they signed in elsewhere - ask them to sign in **in the window you opened**.

---

## Phase 0 - Is Brevo already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Brevo` (match the vendor word case-insensitively).
   - `✔ Connected` → skip to PHASE 2. Prove it first with one read: call any read tool in the `mcp__claude_ai_Brevo__*` namespace (look up the account, or list contact lists) and check a real answer comes back.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` for the user and say: *"Your Brevo connection needs a quick re-sign-in. Press Reconnect next to Brevo, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Check for stored credentials at `~/.config/brevo/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\brevo\credentials.env` (native Windows):

   ```bash
   CRED="$HOME/.config/brevo/credentials.env"
   if [ -f "$CRED" ] && grep -q '^BREVO_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
   ```

   `configured` → run the smoke ping below. HTTP 200 → say *"Brevo is already connected"* and skip to PHASE 2; do not set the built-in up on top of a working connection. HTTP 401 → the key was revoked or regenerated; re-run the kit's own route (**PHASE 1 - Install & Connect**).

   Smoke ping (key never printed):

   ```bash
   set -a; . "$HOME/.config/brevo/credentials.env"; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "api-key: $BREVO_API_KEY" -H "accept: application/json" "https://api.brevo.com/v3/account"
   ```

3. **Nothing found** → Route by need, then Phase 1.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Brevo's tools.

---

## Route by need - which Brevo route does this user actually want?

Ask **one** question in plain English before opening anything: *"What do you want me to do with your Brevo - look at how campaigns are performing and write drafts, or actually send things out?"*

Then route each named need:

| What the user wants | Route |
|---|---|
| See how a campaign performed; A/B test results | Built-in connector (Phase 1) |
| Look up a contact; explore audience segments | Built-in connector (Phase 1) |
| Draft an email campaign, an SMS campaign or an HTML template | Built-in connector (Phase 1) |
| **Send** a campaign, or send a one-off transactional email | The kit's own route (PHASE 1 - Install & Connect) |
| **Schedule** a campaign for later | The kit's own route |
| **Delete** a contact, a list or a campaign | The kit's own route |
| Create or upsert contacts, add them to a list | Built-in connector first; if a write is refused, the kit's own route |

The built-in connector never sends, schedules or deletes - that is Brevo's own design choice, not a bug, and no amount of retrying will change it. So run the kit's own route **only** when the user named one of the gap rows above, or when the built-in genuinely fails on something it claims to cover. If nothing they asked for is in the gap column, stop after Phase 1 and do not burden them with the extra setup. Say in one line what you are not connecting and why, so they can ask for it later.

---

## Phase 1 - Switch on the built-in Brevo connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in. This skill handles no credentials on this route.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening Brevo's page in your browser. Press **Connect to Claude**, sign in to Brevo the way you normally do, and say yes when it asks for access. That is the only part only you can do - tell me when it says Connected."* Then open `https://claude.com/connectors/brevo` (or `https://claude.ai/directory/brevo`) in **the user's own everyday browser** (`open` on Mac, `xdg-open` on Linux, `start ""` on Windows). If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Brevo" → Connect.

> **This is the one place the "never open the participant's own browser" rule does not apply.** That rule exists because the kit's own route reads a secret off the page in a driven browser. This route reads nothing - the user's own browser is the only one signed in to claude.ai, so it is the correct one. Do not drive this sign-in with Playwright.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Brevo … ✔ Connected` is the pass. Not there yet → ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray), then check again. Still missing → `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - any read tool in the `mcp__claude_ai_Brevo__*` namespace (account lookup, or list contact lists). Only a real answer counts. A tool error here is not "connected".

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - *"how did my last campaign do?"*, *"look up jane@example.com"*, *"draft me a campaign about the winter sale"*.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Brevo on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

**Local entry precedence.** If a server registered locally with `claude mcp add` points at the same URL, it takes precedence and hides the built-in one. If it works, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the user's OK.

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **When to run this.** Only when the user named a need in the gap column of *Route by need* above - sending, scheduling or deleting - or when the built-in connector genuinely fails at something it claims to cover, or when Phase 1 Step 1 showed this session cannot see built-in connectors at all. Otherwise stop at Phase 1. Both routes can coexist; setting this one up does not switch the built-in one off.

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Open the API-keys settings; confirm signed in

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.brevo.com/settings/keys/api" })
```

If signed out it redirects to `login.brevo.com`. Ask the user to sign in **in this window**; poll `location.href` until it's back on `app.brevo.com/settings/keys/api`.

### Step 2 - Generate the key

Click **Generate API key**. In the modal:
- **Name** (`#apikey-name-input`): `Claude Code`
- **Expiry** (`#apikey-expiry-select__trigger`): open it and pick **No expiration** (so the connector doesn't silently break later; the default is 1 year).
- Click the modal's **Generate** button.

**reCAPTCHA:** Brevo gates generation behind reCAPTCHA. It's usually invisible, but if an "I'm not a robot" / image challenge appears, ask the user to complete it (Claude can't reliably solve it).

### Step 3 - Capture via the Copy button (key shown ONCE)

A reveal modal appears: *"copy this key and save it somewhere safe. For security reasons, we cannot show it to you again."* The full `xkeysib-…` key is in a readonly field with a **Copy** button. **Click Copy** (more reliable than a DOM read - the key contains hyphens and is ~89 chars). Do NOT screenshot the reveal.

> Timing: the reveal modal can take a moment to render after Generate (and after reCAPTCHA). If the key isn't present yet, wait and re-check before concluding.

### Step 4 - Store, verify, scrub

```bash
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
printf '%s' "$TOKEN" | grep -qE '^xkeysib-[A-Za-z0-9-]+$' || { echo "clipboard not a Brevo key"; exit 1; }
# verify BEFORE persisting
curl -s -H "api-key: $TOKEN" -H "accept: application/json" "https://api.brevo.com/v3/account" \
  | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("email") else 1)' || { echo "verify failed"; exit 1; }
install -d -m 700 "$HOME/.config/brevo"; umask 177
cat > "$HOME/.config/brevo/credentials.env" <<EOF
# Brevo REST API credentials - API key (secret).
# Auth: header  api-key: \$BREVO_API_KEY
# Base: https://api.brevo.com/v3
BREVO_API_KEY=${TOKEN}
EOF
chmod 600 "$HOME/.config/brevo/credentials.env"
unset TOKEN
rm -rf .playwright-mcp 2>/dev/null
```

Tell the user: *"All connected - your Brevo is ready. Try 'how many contacts do I have' or 'show my email lists'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\brevo\credentials.env`; everywhere else `~/.config/brevo/credentials.env`.

---

## PHASE 2 - Use the connector

**Which tools you have depends on which route connected.** Through the built-in connector the tools are `mcp__claude_ai_Brevo__*` - use them for campaign analysis, A/B results, contact and segment lookup, and drafting campaigns and templates. Through the kit's own route the "tools" are the curl shapes below. The names differ materially: there is no built-in equivalent of `/smtp/email`, `sendNow` or any DELETE, so a send, a schedule or a delete always runs through the kit's own route even on a machine where both are connected.

### The kit's own route - REST runtime loop

```bash
set -a; . "$HOME/.config/brevo/credentials.env"; set +a
H="api-key: $BREVO_API_KEY"; B="https://api.brevo.com/v3"
BV() { curl -s -H "$H" -H "accept: application/json" "$@"; }
```

**Reads** (paginate with `limit`/`offset`; responses include a `count`):

```bash
BV "$B/account" | jq '{email, company:.companyName, plan:[.plan[].type]}'
BV "$B/contacts?limit=50&offset=0" | jq '{count, contacts:[.contacts[]|{id,email}]}'
BV "$B/contacts/lists" | jq '.lists[] | {id,name,totalSubscribers}'
BV "$B/contacts/<email-or-id>" | jq '{email, listIds, attributes}'
BV "$B/senders" | jq '.senders[] | {id,email,active}'
BV "$B/emailCampaigns?limit=20" | jq '.campaigns[]? | {id,name,status}'
```

**Writes** (JSON body; confirm anything that emails real people with the user first):

```bash
# create / upsert a contact
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"email":"jane@example.com","attributes":{"FNAME":"Jane"},"listIds":[2],"updateEnabled":true}' \
  "$B/contacts" | jq '.id'
# add a contact to a list
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"emails":["jane@example.com"]}' "$B/contacts/lists/<listId>/contacts/add" | jq '.'
# delete a contact (returns 204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/contacts/jane@example.com"
# send a transactional email (CONFIRM with user - this actually sends)
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"sender":{"email":"<verified-sender>"},"to":[{"email":"jane@example.com"}],"subject":"Hi","htmlContent":"<p>Hello</p>"}' \
  "$B/smtp/email" | jq '.messageId'
```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Account | `/account` | verify / plan info |
| Contacts | `/contacts`, `/contacts/<email-or-id>` | create/upsert/delete; `updateEnabled:true` to upsert |
| Lists | `/contacts/lists`, `/contacts/lists/<id>/contacts/add` | |
| Senders | `/senders` | must be verified to send |
| Marketing campaigns | `/emailCampaigns` | create/schedule email campaigns |
| Transactional email | `/smtp/email` (POST) | **actually sends** - confirm first |

---

## Gotchas

- **The built-in connector never sends, schedules or deletes.** If a send fails through `mcp__claude_ai_Brevo__*`, that is the documented boundary, not a transient error - switch to the kit's own route rather than retrying.
- **Header is `api-key:` (not `Authorization`).** And the key value is the raw `xkeysib-…` (no scheme prefix).
- **Key contains hyphens, ~89 chars, prefix `xkeysib-`.** Validate with `xkeysib-[A-Za-z0-9-]+`, not `[A-Za-z0-9]+`. Shown ONCE → capture via the Copy button at generation.
- **reCAPTCHA gates key generation** - usually invisible; if a challenge appears the user must solve it.
- **Pick "No expiration"** at generation; the default is 1 year (the connector would silently break when it lapses).
- **`/smtp/email` actually sends email** and campaign endpoints can email real contacts - always confirm send/publish actions with the user; reads and contact CRUD are safe.
- **No substring-negation in self-checks.** Match `http_code==200` / `.email` present, never "output lacks an error word".
- **401 Unauthorized** → key revoked/regenerated or wrong header → re-run Phase 1 / fix the header.
- **429 rate limit** → Brevo enforces per-endpoint limits; back off on 429.
- **DELETE returns 204** (no body); don't parse JSON from it.

## Token handling

The API key is a bearer-equivalent secret in `~/.config/brevo/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (key redacted), incl. the reCAPTCHA gate + hyphenated-key gotcha.
- `references/rest-api.md` - endpoints, pagination, contact upsert, transactional send.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
