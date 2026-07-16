---
name: activecampaign-connector
description: "Connect and operate ActiveCampaign (marketing automation, email marketing, light CRM) via its v3 REST API for users who already have an ActiveCampaign account. ActiveCampaign needs TWO self-serve credentials: an account-specific API URL (https://<account>.api-us1.com) and an API Key - BOTH shown on the same page in Settings → Developer (persistent, not one-time). Phase 1 is autonomous via Playwright: Claude opens the account's Settings → Developer page, the user signs in, and Claude reads the API URL + Key (via their Copy buttons / readonly fields), stores both at ~/.config/activecampaign/credentials.env (mode 600), and verifies with GET /api/3/users/me. Phase 2 reads and writes via curl against <API_URL>/api/3 using the 'Api-Token' header. Handles contacts, lists, tags, deals (CRM), campaigns, automations, and custom fields. No vendor MCP. Use this skill when the user asks to 'connect my ActiveCampaign', 'set up ActiveCampaign', or asks anything about their ActiveCampaign contacts, lists, tags, deals, or campaigns. Do NOT use to recommend ActiveCampaign to users who do not already use it. On first use, run Phase 1 to capture and store the URL + key before any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - activecampaign
    - marketing-automation
    - email-marketing
    - contacts
    - crm
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting ActiveCampaign auth (401/403) errors
    - skill: email-composer
      reason: Draft campaign / automation email content for ActiveCampaign sends
    - skill: brevo-connector
      reason: Sibling email-marketing connector - same single-key shape; useful for comparisons/migrations
---

# ActiveCampaign Connector

## Overview

This skill lets Claude read and update a user's ActiveCampaign data on their behalf - marketing automation, email marketing, and light CRM (contacts, lists, tags, deals). It publishes **no MCP server**, so this is a **standalone direct-REST connector** - like `brevo-connector` / `mailchimp-connector`, but with one twist:

- **TWO credentials are required: an account-specific API URL AND an API Key.** The base URL is per-account (e.g. `https://selrai.api-us1.com`, region suffix varies: `api-us1`, etc.). Both are shown together on the **Settings → Developer** page (persistent - not shown-once).
- **Auth is the `Api-Token` header** (the API Key value). Every call: `Api-Token: <key>` against `<API_URL>/api/3`.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** Claude opens the account's Settings → Developer page, the user signs in, Claude reads the **API URL** and **API Key** (both on that page), stores them (mode 600), and verifies with `/api/3/users/me`.
- **Phase 2 - Use the connector.** curl against `<API_URL>/api/3` with the `Api-Token` header.

**Which phase to run** - Before any ActiveCampaign action, check for `~/.config/activecampaign/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\activecampaign\credentials.env` (native Windows). If it exists with non-empty `ACTIVECAMPAIGN_API_URL` **and** `ACTIVECAMPAIGN_API_KEY`, run the Phase 0 smoke ping; on success go to Phase 2; on 401/403 run Phase 1. Otherwise run Phase 1.

**Full account access.** An ActiveCampaign API key has full access to the account's contacts, deals, and sending. Treat it like a password.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - the user only signs in. Rules:

- **You drive; the user signs in.** The only ask is "please sign in to ActiveCampaign in the browser window I just opened" (it may ask for the account name first, then email/password).
- **Plain English only.** No jargon (API, key, URL, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection details" / "your ActiveCampaign account".
- **Never echo the key.** (The API URL is not secret; the key is.)
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows ActiveCampaign's login, they signed in elsewhere - ask them to sign in **in the window you opened**.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/activecampaign/credentials.env"
if [ -f "$CRED" ] && grep -q '^ACTIVECAMPAIGN_API_URL=.\+' "$CRED" && grep -q '^ACTIVECAMPAIGN_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → **Phase 2**; HTTP 401/403 → re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (key never printed):

```bash
set -a; . "$HOME/.config/activecampaign/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Api-Token: $ACTIVECAMPAIGN_API_KEY" -H "Accept: application/json" "$ACTIVECAMPAIGN_API_URL/api/3/users/me"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Sign in; learn the account subdomain

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://www.activecampaign.com/login/" })
```

Ask the user to sign in **in this window** (ActiveCampaign may ask for the account name first, then email/password). Poll `location.href` until it's on `https://<account>.activehosted.com/...` - capture `<account>` from the host (e.g. `selrai`).

### Step 2 - Open Settings → Developer and read both values

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://<account>.activehosted.com/app/settings/developer" })
```

The **API Access** section shows **URL** and **Key**, each in a readonly field with a Copy button. Read both:
- **API URL** - matches `https://<account>.api-us1.com` (region suffix varies). NOT secret. (DOM-read is fine.)
- **API Key** - a long hex string (~72 chars). Secret. Capture via its **Copy** button (clipboard-transit) or DOM-read; never echo it.

These are persistent (not shown-once), so re-reading later is fine.

### Step 3 - Store, verify, scrub

```bash
URL="https://<account>.api-us1.com"   # <-- the API URL read in Step 2
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
printf '%s' "$TOKEN" | grep -qE '^[a-f0-9]{40,}$' || { echo "clipboard not an AC key"; exit 1; }
# verify BEFORE persisting
curl -s -H "Api-Token: $TOKEN" -H "Accept: application/json" "$URL/api/3/users/me" \
  | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("user",{}).get("id") else 1)' || { echo "verify failed"; exit 1; }
install -d -m 700 "$HOME/.config/activecampaign"; umask 177
cat > "$HOME/.config/activecampaign/credentials.env" <<EOF
# ActiveCampaign REST API credentials - key (secret) + account base URL.
# Auth: header  Api-Token: \$ACTIVECAMPAIGN_API_KEY
# Base: \$ACTIVECAMPAIGN_API_URL/api/3
ACTIVECAMPAIGN_API_URL=${URL}
ACTIVECAMPAIGN_API_KEY=${TOKEN}
EOF
chmod 600 "$HOME/.config/activecampaign/credentials.env"
unset TOKEN
rm -rf .playwright-mcp 2>/dev/null
```

Tell the user: *"All connected - your ActiveCampaign is ready. Try 'how many contacts do I have' or 'show my lists'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\activecampaign\credentials.env`; everywhere else `~/.config/activecampaign/credentials.env`.

---

## PHASE 2 - Use the connector (REST runtime loop)

```bash
set -a; . "$HOME/.config/activecampaign/credentials.env"; set +a
H="Api-Token: $ACTIVECAMPAIGN_API_KEY"; B="$ACTIVECAMPAIGN_API_URL/api/3"
AC() { curl -s -H "$H" -H "Accept: application/json" "$@"; }
```

**Reads** (paginate with `limit`/`offset`; `meta.total` has the count):

```bash
AC "$B/users/me" | jq '.user | {username, email}'
AC "$B/contacts?limit=50&offset=0" | jq '{total:.meta.total, contacts:[.contacts[]|{id,email}]}'
AC "$B/lists" | jq '.lists[] | {id,name}'
AC "$B/tags" | jq '.tags[] | {id,tag}'
AC "$B/deals?limit=20" | jq '.deals[]? | {id,title,value}'
AC "$B/campaigns?limit=20" | jq '.campaigns[]? | {id,name,status}'
```

**Writes** (body wrapped in the entity key; confirm anything that emails real people):

```bash
# create a contact
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"contact":{"email":"jane@example.com","firstName":"Jane"}}' "$B/contacts" | jq '.contact.id'
# create a tag
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"tag":{"tag":"VIP","tagType":"contact"}}' "$B/tags" | jq '.tag.id'
# add a tag to a contact
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"contactTag":{"contact":"<contactId>","tag":"<tagId>"}}' "$B/contactTags" | jq '.contactTag.id'
# delete a contact (returns 200, not 204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/contacts/<contactId>"
```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| User | `/users/me` | verify / token owner |
| Contacts | `/contacts`, `/contacts/<id>` | body key `contact`; DELETE → 200 |
| Lists | `/lists` | mailing lists |
| Tags | `/tags`, `/contactTags` | body keys `tag` / `contactTag` |
| Deals (CRM) | `/deals`, `/dealStages`, `/pipelines` | light CRM |
| Campaigns | `/campaigns` | **sending delivers real email** |
| Automations | `/automations` | |
| Custom fields | `/fields`, `/fieldValues` | |

---

## Gotchas

- **Two credentials, account-specific base URL.** You need BOTH the `Api-Token` key AND the per-account API URL (`https://<account>.api-us1.com`; region suffix varies). A wrong/region-mismatched URL → connection failures. Read both from Settings → Developer.
- **Header is `Api-Token:`** (the key value), not `Authorization`, not a query param.
- **Write bodies are wrapped in the entity key** - `{"contact":{...}}`, `{"tag":{...}}`. A bare `{"email":...}` fails.
- **DELETE returns 200** (not 204) with a body; reads carry `meta.total` for pagination.
- **Campaigns/automations send real email** - confirm send/activate actions with the user; reads + contact/tag CRUD are safe.
- **No substring-negation in self-checks.** Match `http_code==200` / `.user.id` present, never "output lacks an error word".
- **401/403** → bad key, wrong account URL, or `Authorization` used instead of `Api-Token` → re-run Phase 1 / fix the header+URL.
- **429 rate limit** → ActiveCampaign allows ~5 req/sec per account; back off on 429.

## Token handling

The API key is a bearer-equivalent secret in `~/.config/activecampaign/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. The API URL is not secret. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (key redacted), incl. the two-credentials / account-URL specifics.
- `references/rest-api.md` - endpoints, pagination, entity-key write bodies, deals/CRM.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
