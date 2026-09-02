---
name: activecampaign-connector
description: "Connect ActiveCampaign to Claude by switching on its built-in connector, or by installing its API credentials for the parts the built-in doesn't reach. Use when the user asks to set up or connect ActiveCampaign, or wants ActiveCampaign work (contacts, lists, tags, deals, campaigns, automations) and ActiveCampaign isn't connected yet. Once connected, ActiveCampaign runs through the mcp__claude_ai_ActiveCampaign__* tools, or against its API with the stored credentials."
allowed-tools: mcp__claude_ai_ActiveCampaign__*,Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
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

This skill lets Claude read and update a user's ActiveCampaign data on their behalf - marketing automation, email marketing, and light CRM (contacts, lists, tags, deals). There are two routes onto it, and **the built-in connector is the default**:

- **Phase 1 - the built-in ActiveCampaign connector (default).** Listed in Claude's connector directory at `https://claude.com/connectors/activecampaign` (slug verified live, 2 Sep 2026; the page badges it **Read & Write**). The user presses one button on their Claude account and signs in. The connection is **account-level**: connect once and it is available everywhere that Claude account is signed in, including Claude Code. Tools arrive as `mcp__claude_ai_ActiveCampaign__*`. It covers **contacts, lists, tags and automations - read and write** - and handles no credentials at all. One extra gate: **an ActiveCampaign account admin has to allow the connection at the ActiveCampaign end as well as pressing Connect at the Claude end.**
- **Phase 1-alt - the kit's own route** (for what the built-in doesn't reach - deals, custom-field create/update/delete, and deleting a contact - and whenever built-in connectors can't be used in this session). A **standalone direct-REST connector** - like `brevo-connector` / `mailchimp-connector`, but with one twist:
  - **TWO credentials are required: an account-specific API URL AND an API Key.** The base URL is per-account (e.g. `https://selrai.api-us1.com`, region suffix varies: `api-us1`, etc.). Both are shown together on the **Settings → Developer** page (persistent - not shown-once).
  - **Auth is the `Api-Token` header** (the API Key value). Every call: `Api-Token: <key>` against `<API_URL>/api/3`.

  Claude opens the account's Settings → Developer page, the user signs in, Claude reads the **API URL** and **API Key** (both on that page), stores them (mode 600), and verifies with `/api/3/users/me`. After that it is curl against `<API_URL>/api/3` with the `Api-Token` header.
- **Phase 2 - Use the connector.** Whichever route connected, read and update ActiveCampaign through that route.

**Which phase to run** - always start at **Phase 0** below. It checks the built-in connector first, then the kit's own credentials file (`~/.config/activecampaign/credentials.env` on Mac/Linux/WSL, `%APPDATA%\activecampaign\credentials.env` on native Windows, needing non-empty `ACTIVECAMPAIGN_API_URL` **and** `ACTIVECAMPAIGN_API_KEY`) plus a smoke ping. A working connection on either route means skip straight to Phase 2 - never set one route up on top of the other.

### Deals, custom fields and delete: probe, don't assume

The directory listing is explicit about contacts, lists, tags and automations, and **silent** about deals, custom-field create/update/delete, and contact deletion. Silent is not the same as absent. When the user's need is one of those three, try it on the built-in first and let the result decide: a real tool error (or no such tool in the `mcp__claude_ai_ActiveCampaign__*` namespace) is the signal to run Phase 1-alt for that half of the work. Never fall back on a guess.

**Full account access.** An ActiveCampaign API key has full access to the account's contacts, deals, and sending. Treat it like a password.

**Existing accounts only.** This connector is for users who already have an ActiveCampaign account. Do not use it to recommend ActiveCampaign to users who do not already use it.

---

## Communication rules (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Both routes are autonomous - the user only signs in. Rules:

- **Which browser opens, and why.** On the built-in route you open the user's **own everyday browser** - that is where they are already signed in to Claude - and it reads nothing from that browser. On the kit's own route Claude uses a separate window it drives itself, because that route reads the connection details off the page. The two rules do not conflict; they belong to different routes.
- **Never ask for a password, a sign-in code, or a screenshot of a sign-in screen** on either route.
- **You drive; the user signs in.** The only ask is "please sign in to ActiveCampaign in the browser window I just opened" (it may ask for the account name first, then email/password).
- **Plain English only.** No jargon (API, key, URL, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection details" / "your ActiveCampaign account".
- **Never echo the key.** (The API URL is not secret; the key is.)
- **Restart, only on the built-in route.** If the built-in connector doesn't show up after connecting, ask the user to close and reopen Claude once. The kit's own route needs no restart - it works the instant the details are saved.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows ActiveCampaign's login, they signed in elsewhere - ask them to sign in **in the window you opened**.

---

## PHASE 0 - Is ActiveCampaign already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai ActiveCampaign` (match the vendor word case-insensitively).
   - `✔ Connected` → skip to **Phase 2**. Prove it first with one read from the `mcp__claude_ai_ActiveCampaign__*` namespace (list the mailing lists) before saying so.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` in the user's own browser (`open` on Mac, `xdg-open` on Linux, `start "" <url>` on Windows) and say: *"Your ActiveCampaign connection needs a quick re-sign-in. Press Reconnect next to ActiveCampaign, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Check for the credentials file, then smoke-ping it:

   ```bash
   CRED="$HOME/.config/activecampaign/credentials.env"
   if [ -f "$CRED" ] && grep -q '^ACTIVECAMPAIGN_API_URL=.\+' "$CRED" && grep -q '^ACTIVECAMPAIGN_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
   ```

   Smoke ping (key never printed):

   ```bash
   set -a; . "$HOME/.config/activecampaign/credentials.env"; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "Api-Token: $ACTIVECAMPAIGN_API_KEY" -H "Accept: application/json" "$ACTIVECAMPAIGN_API_URL/api/3/users/me"
   ```

   - `configured` + HTTP 200 → keep using it and go to **Phase 2**. Do not set the built-in up on top of a working connection.
   - `configured` + HTTP 401/403 → the key or account URL is stale. If the user's need is inside the built-in's coverage (see the routing table), prefer **Phase 1**; otherwise re-run **Phase 1-alt**.
   - `not-configured` → continue.
3. **Nothing found** → **Phase 1**.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of ActiveCampaign's tools.

---

## Route by need - built-in or the kit's route?

Before installing anything, ask one question in plain English: **what does the user want Claude to do with ActiveCampaign?** Then route what they name:

| What the user wants | Route |
|---|---|
| Contacts - look up, add, update | **Built-in** |
| Mailing lists - look up, subscribe or unsubscribe a contact | **Built-in** |
| Tags - look up, create, apply to a contact | **Built-in** |
| Automations - see them, add a contact to one | **Built-in** |
| Campaign performance - what went out, how it did | **Built-in** |
| Deals / the light CRM (pipelines, stages, deal values) | Try the built-in first; on a real failure, the kit's own route (Phase 1-alt) |
| Custom fields - creating, changing or removing field definitions and values | Try the built-in first; on a real failure, the kit's own route (Phase 1-alt) |
| Deleting a contact outright | Try the built-in first; on a real failure, the kit's own route (Phase 1-alt) |
| The session can't see built-in connectors at all (Phase 1 Step 1 fails), or the user explicitly asks for the local setup | The kit's own route (Phase 1-alt) |

Both routes can coexist on one machine. Never tear one down to set the other up, and never burden the user with the kit's extra setup when the built-in already covers what they asked for. Say in one line what you are *not* connecting and why, so they can ask for it later.

---

## PHASE 1 - Switch on the built-in ActiveCampaign connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening ActiveCampaign's page in your browser. Press **Connect to Claude**, sign in to ActiveCampaign the way you normally do, and say yes when it asks for access. That is the only part only you can do - tell me when it says Connected."* Then open `https://claude.ai/directory/activecampaign` in their own browser (`open` / `xdg-open` / `start`). If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "ActiveCampaign" → Connect.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in. **If ActiveCampaign refuses the connection**, an ActiveCampaign account admin has to allow it at the ActiveCampaign end as well - say so plainly: *"Whoever runs your ActiveCampaign account needs to allow this connection on their side. Once they have, press Connect again."*

**Step 4 - Verify.** `claude mcp list` again. `claude.ai ActiveCampaign … ✔ Connected` is the pass. Not there yet → ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray), then check again. Still missing → `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - list the mailing lists from the `mcp__claude_ai_ActiveCampaign__*` namespace. Only a real answer counts. A tool error here is not "connected".

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch ActiveCampaign on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-ALT - Install & Connect (autonomous via Playwright)

**Run this only when** a named need failed on the built-in for real (deals, custom-field work, deleting a contact), the session can't see built-in connectors (Step 1 failed), the listing is missing on the user's account, or the user explicitly wants the local setup. Otherwise stay on Phase 1.

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

## PHASE 2 - Use the connector

**Which tool namespace.** Through the built-in connector the tools are `mcp__claude_ai_ActiveCampaign__*` - contacts, lists, tags, automations and campaign reporting, read and write - with no credentials file, no account URL and no curl. Through the kit's own route it is the REST runtime loop below. The two are named quite differently: on the built-in route, list what is actually in the `mcp__claude_ai_ActiveCampaign__*` namespace and match by what each tool does, rather than looking for the endpoints in this section. Deals, custom-field CRUD and contact deletion are the parts to try on the built-in and, on a real failure, run here instead.

### The kit's own route - REST runtime loop

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
- **401/403** → bad key, wrong account URL, or `Authorization` used instead of `Api-Token` → re-run Phase 1-alt / fix the header+URL.
- **429 rate limit** → ActiveCampaign allows ~5 req/sec per account; back off on 429.

## Token handling

The API key is a bearer-equivalent secret in `~/.config/activecampaign/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. The API URL is not secret. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1-alt run (key redacted), incl. the two-credentials / account-URL specifics.
- `references/rest-api.md` - endpoints, pagination, entity-key write bodies, deals/CRM.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
