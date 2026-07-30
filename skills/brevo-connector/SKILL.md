---
name: brevo-connector
description: "Connect Brevo (formerly Sendinblue) to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect Brevo, or wants Brevo work (contacts, lists, senders, email campaigns, transactional email) and the credentials aren't in place yet. Once connected, Brevo runs directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
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

This skill lets Claude read and update a user's Brevo (formerly Sendinblue) data on their behalf - email marketing, contacts, and transactional email. It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the single-API-key shape, like `mailchimp-connector` / `klaviyo-connector`.

Two Brevo specifics matter:

- **Auth is the `api-key` header** (a custom header name - not `Authorization`). Every call sends `api-key: xkeysib-…`.
- **The key has the `xkeysib-` prefix and CONTAINS HYPHENS** (~89 chars, e.g. `xkeysib-<hex>-<suffix>`). A `[A-Za-z0-9]`-only regex misses it; use `xkeysib-[A-Za-z0-9-]+`. The key is **shown once** at generation (Brevo gates generation behind reCAPTCHA and reveals the full key in a one-time modal with a Copy button).

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** Claude opens the API-keys settings, the user signs in, Claude generates a `Claude Code` key with **No expiration**, captures it via the modal's Copy button, stores it (mode 600), and verifies with `/account`.
- **Phase 2 - Use the connector.** curl against the REST API with the `api-key` header.

**Which phase to run** - Before any Brevo action, check for `~/.config/brevo/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\brevo\credentials.env` (native Windows). If it exists with a non-empty `BREVO_API_KEY`, run the Phase 0 smoke ping; on success go to Phase 2; on 401 run Phase 1. Otherwise run Phase 1.

**Full account access.** A Brevo API key has full access to the account's contacts, campaigns, and sending. Treat it like a password.

**Existing accounts only.** This connector is for users who already have a Brevo (Sendinblue) account. Do not use it to recommend Brevo to users who do not already use it.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - the user only signs in (and may have to tick a reCAPTCHA). Rules:

- **You drive; the user signs in.** The only ask is "please sign in to Brevo in the browser window I just opened" (and tick the 'I'm not a robot' box if it appears).
- **Plain English only.** No jargon (API, key, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection key" / "your Brevo account".
- **Never echo the key** (`xkeysib-…`).
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows Brevo's login, they signed in elsewhere - ask them to sign in **in the window you opened**.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/brevo/credentials.env"
if [ -f "$CRED" ] && grep -q '^BREVO_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → **Phase 2**; HTTP 401 → re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (key never printed):

```bash
set -a; . "$HOME/.config/brevo/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "api-key: $BREVO_API_KEY" -H "accept: application/json" "https://api.brevo.com/v3/account"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

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

## PHASE 2 - Use the connector (REST runtime loop)

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
