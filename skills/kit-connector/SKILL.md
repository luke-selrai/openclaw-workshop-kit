---
name: kit-connector
description: "Connect and operate Kit (formerly ConvertKit) - creator email marketing - via its v4 REST API for users who already have a Kit/ConvertKit account. Kit uses a self-serve v4 API key. Phase 1 is autonomous via Playwright: Claude opens Settings → Developer (app.kit.com/account_settings/developer_settings), the user signs in, Claude clicks 'Add a new key' under V4 Keys, names it 'Claude Code', clicks Create API Key, and captures the key (shown ONCE, prefix kit_, ~36 chars) via the reveal's Copy button. Stores it at ~/.config/kit/credentials.env (mode 600) and verifies with GET /account. Phase 2 reads and writes via curl against https://api.kit.com/v4 using the 'X-Kit-Api-Key' header. Handles subscribers, tags, forms, sequences, broadcasts, and custom fields. No vendor MCP. Use this skill when the user asks to 'connect my Kit' / 'ConvertKit', 'set up Kit', or asks anything about their Kit subscribers, tags, forms, sequences, or broadcasts. Do NOT use to recommend Kit to users who do not already use it. On first use, run Phase 1 to mint and store the key before any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Marketing & Advertising
  tags:
    - kit
    - convertkit
    - email-marketing
    - subscribers
    - creators
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Kit auth (401) or key-generation errors
    - skill: email-composer
      reason: Draft broadcast or sequence email content for Kit sends
    - skill: brevo-connector
      reason: Sibling email-marketing connector - same single-API-key shape; useful for comparisons/migrations
---

# Kit Connector (formerly ConvertKit)

## Overview

This skill lets Claude read and update a user's Kit (formerly ConvertKit) data on their behalf - creator-focused email marketing: subscribers, tags, forms, sequences, broadcasts. It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the single-API-key shape, like `brevo-connector` / `mailchimp-connector`.

Two Kit specifics matter:

- **Use the v4 API with the `X-Kit-Api-Key` header.** Every call sends `X-Kit-Api-Key: <key>`. (Kit also has a legacy v3 API at `api.convertkit.com/v3` using `api_key`/`api_secret` query params - do NOT use it; v4 is current and cleaner.)
- **The v4 key is self-serve, prefix `kit_` (~36 chars), shown ONCE** at creation. Capture it via the reveal's Copy button.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** Claude opens Settings → Developer, the user signs in, Claude creates a `Claude Code` V4 key, captures it via the reveal Copy button, stores it (mode 600), and verifies with `/account`.
- **Phase 2 - Use the connector.** curl against the v4 REST API with the `X-Kit-Api-Key` header.

**Which phase to run** - Before any Kit action, check for `~/.config/kit/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\kit\credentials.env` (native Windows). If it exists with a non-empty `KIT_API_KEY`, run the Phase 0 smoke ping; on success go to Phase 2; on 401 run Phase 1. Otherwise run Phase 1.

**Full account access.** A Kit v4 API key has full access to the account's subscribers and sending. Treat it like a password.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - the user only signs in. Rules:

- **You drive; the user signs in.** The only ask is "please sign in to Kit in the browser window I just opened."
- **Plain English only.** No jargon (API, key, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection key" / "your Kit account".
- **Never echo the key** (`kit_…`).
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows Kit's login, they signed in elsewhere - ask them to sign in **in the window you opened**.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/kit/credentials.env"
if [ -f "$CRED" ] && grep -q '^KIT_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → **Phase 2**; HTTP 401 → re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (key never printed):

```bash
set -a; . "$HOME/.config/kit/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "X-Kit-Api-Key: $KIT_API_KEY" -H "Accept: application/json" "https://api.kit.com/v4/account"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Open Developer settings; confirm signed in

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.kit.com/account_settings/developer_settings" })
```

If signed out it redirects to `app.kit.com/users/login`. Ask the user to sign in **in this window**; poll `location.href` until it's back on `…/developer_settings`.

### Step 2 - Create a V4 key

Under **API Keys → V4 Keys**, click **Add a new key**. In the **New API Key** modal: type `Claude Code` into the Name field (`#api-key-name`, "internal use only"), then click **Create API Key**.

> Use the **V4 Keys** section, NOT the **V3 Key (Legacy)** - the connector targets v4 (`X-Kit-Api-Key` header). The legacy 22-char V3 key already shown on the page is a different thing.

### Step 3 - Capture via the Copy button (key shown ONCE)

The reveal shows the new key once - prefix `kit_`, ~36 chars - in a field with a **Copy** button. **Click Copy** (the key cannot be retrieved again). Do NOT screenshot the reveal.

### Step 4 - Store, verify, scrub

```bash
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
printf '%s' "$TOKEN" | grep -qE '^[A-Za-z0-9_-]{24,}$' || { echo "clipboard not a Kit key"; exit 1; }
# verify BEFORE persisting
curl -s -H "X-Kit-Api-Key: $TOKEN" -H "Accept: application/json" "https://api.kit.com/v4/account" \
  | python3 -c 'import sys,json; a=json.load(sys.stdin).get("account",{}); sys.exit(0 if (a.get("primary_email_address") or a.get("plan_type") or a.get("name")) else 1)' || { echo "verify failed"; exit 1; }
install -d -m 700 "$HOME/.config/kit"; umask 177
cat > "$HOME/.config/kit/credentials.env" <<EOF
# Kit (ConvertKit) v4 REST API credentials - API key (secret).
# Auth: header  X-Kit-Api-Key: \$KIT_API_KEY
# Base: https://api.kit.com/v4
KIT_API_KEY=${TOKEN}
EOF
chmod 600 "$HOME/.config/kit/credentials.env"
unset TOKEN
rm -rf .playwright-mcp 2>/dev/null
```

Tell the user: *"All connected - your Kit is ready. Try 'how many subscribers do I have' or 'show my tags'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\kit\credentials.env`; everywhere else `~/.config/kit/credentials.env`.

---

## PHASE 2 - Use the connector (REST runtime loop)

```bash
set -a; . "$HOME/.config/kit/credentials.env"; set +a
H="X-Kit-Api-Key: $KIT_API_KEY"; B="https://api.kit.com/v4"
KIT() { curl -s -H "$H" -H "Accept: application/json" "$@"; }
```

**Reads** - v4 uses **cursor pagination**: `?per_page=N`, then `?after=<end_cursor>` while `pagination.has_next_page` is true:

```bash
KIT "$B/account" | jq '.account | {name, email:.primary_email_address, plan:.plan_type}'
KIT "$B/subscribers?per_page=50" | jq '{next:.pagination.has_next_page, end:.pagination.end_cursor, subs:[.subscribers[]|{id,email_address,state}]}'
KIT "$B/tags" | jq '.tags[] | {id,name}'
KIT "$B/forms" | jq '.forms[] | {id,name}'
KIT "$B/sequences" | jq '.sequences[]? | {id,name}'
KIT "$B/broadcasts?per_page=20" | jq '.broadcasts[]? | {id,subject,public}'
```

**Writes** (JSON body; confirm anything that emails real people):

```bash
# create/upsert a subscriber (Kit upserts by email)
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"email_address":"jane@example.com","first_name":"Jane"}' "$B/subscribers" | jq '.subscriber.id'
# create a tag
curl -s -X POST -H "$H" -H "Content-Type: application/json" -d '{"name":"VIP"}' "$B/tags" | jq '.tag.id'
# tag a subscriber
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"email_address":"jane@example.com"}' "$B/tags/<tagId>/subscribers" | jq '.'
# delete a tag (returns 204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/tags/<tagId>"
```

> Kit has no hard "delete subscriber" via API in the usual flow - you unsubscribe (`POST /subscribers/<id>/unsubscribe`) rather than delete. Tags ARE deletable (DELETE → 204).

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Account | `/account` | verify / plan info |
| Subscribers | `/subscribers`, `/subscribers/<id>` | create = upsert by email; unsubscribe (no hard delete) |
| Tags | `/tags`, `/tags/<id>`, `/tags/<id>/subscribers` | create/delete; tag/untag subscribers |
| Forms | `/forms`, `/forms/<id>/subscribers` | add subscribers via a form |
| Sequences | `/sequences`, `/sequences/<id>/subscribers` | email automations |
| Broadcasts | `/broadcasts` | one-off emails - **sending delivers to real people** |
| Custom fields | `/custom_fields` | |

---

## Gotchas

- **v4, `X-Kit-Api-Key` header.** Not `Authorization`, not a query param. Ignore the legacy v3 API (`api.convertkit.com/v3`, `api_key`/`api_secret`) - different base + auth.
- **Key prefix `kit_`, ~36 chars, shown ONCE.** Use the **V4 Keys → Add a new key** flow and capture via the Copy button; the 22-char value already on the page is the legacy V3 key.
- **Cursor pagination, not offset.** Page with `after=<pagination.end_cursor>` while `pagination.has_next_page` is true (NOT `offset`/`page`).
- **No hard subscriber delete** - use `/subscribers/<id>/unsubscribe`. Tags delete cleanly (204).
- **Broadcasts/sequences send real email** - confirm send/publish with the user; reads + subscriber/tag CRUD are safe.
- **No substring-negation in self-checks.** Match `http_code==200` / `.account` present, never "output lacks an error word".
- **401 Unauthorized** → key revoked/regenerated, wrong header, or you used a v3 key against v4 → re-run Phase 1 / fix the header.
- **DELETE returns 204** (no body); don't parse JSON from it.

## Token handling

The API key is a bearer-equivalent secret in `~/.config/kit/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (key redacted), incl. the v4-vs-v3-key distinction.
- `references/rest-api.md` - endpoints, cursor pagination, subscriber upsert, tag/broadcast usage.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
