---
name: pipedrive-connector
description: "Connect Pipedrive to Claude by switching on its built-in connector, or by installing its API credentials for the parts the built-in doesn't reach. Use when the user asks to set up or connect Pipedrive, or wants Pipedrive CRM work (deals, contacts, leads, pipelines, activities, notes) and Pipedrive isn't connected yet. Once connected, Pipedrive runs through the mcp__claude_ai_Pipedrive__* tools, or against its API with the stored credentials."
allowed-tools: mcp__claude_ai_Pipedrive__*,Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - pipedrive
    - crm
    - sales
    - deals
    - pipeline
    - contacts
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Pipedrive auth (401) or permission (403) errors
    - skill: email-composer
      reason: Draft follow-up emails to Pipedrive contacts and deal stakeholders
    - skill: hubspot-connector
      reason: Sibling CRM connector - same direct-token shape; useful for CRM migrations/comparisons
---

# Pipedrive Connector

## Overview

This skill lets Claude read and update a user's Pipedrive data on their behalf. Pipedrive is the sales-pipeline CRM popular with SMB sales teams. There are two routes onto it, and **the built-in connector is the default**:

- **Phase 1 - the built-in Pipedrive connector (default).** Pipedrive is listed in Claude's connector directory - Pipedrive's own newsroom confirmed the listing, and a logged-in check on 2 Sep 2026 found exactly one listing, "Pipedrive", at `https://claude.ai/directory/pipedrive-mcp`. **Mind the slug**: it is `pipedrive-mcp`, not `pipedrive` (`https://claude.ai/directory/pipedrive` answers "This connector doesn't exist", and the public mirror `https://claude.com/connectors/pipedrive` 404s). If the deep link ever fails, fall back to `https://claude.ai/customize/connectors` → **Browse** → search "Pipedrive" → **Connect**. The user presses one button and signs in. The connection is **account-level**: connect once and it is available everywhere that Claude account is signed in, including Claude Code. Tools arrive as `mcp__claude_ai_Pipedrive__*`. It covers deals, persons and activities - get, add, update and search - and handles no credentials at all.
- **Phase 1-alt - the kit's own route** (for what the built-in doesn't reach: notes, products, organisations, leads, users and filters - and whenever built-in connectors can't be used in this session). This is a **standalone direct-REST connector** - the same shape as `servicem8-connector`, `cliniko-connector`, `myob-connector`, and `ghl-connector` in the direct-REST family noted in `skills/CLAUDE.md`.
- **Phase 2 - Use the connector.** Whichever route connected, read and update Pipedrive through that route.

The kit's own route is dead simple. Claude reads one static personal API token out of `~/.config/pipedrive/credentials.env`, then runs `curl` against Pipedrive's REST endpoints. Two Pipedrive specifics matter:

- **Auth is the `x-api-token` header.** Every call carries `x-api-token: <token>`. **Do NOT use `Authorization: Bearer`** - that header is reserved for OAuth access tokens and returns `401` with a personal API token. (The legacy `?api_token=<token>` query param also works but puts the secret in URLs/logs - prefer the header.)
- **The base URL is company-scoped.** It is `https://<company-domain>.pipedrive.com/api/v2`, where `<company-domain>` is the subdomain of the user's Pipedrive account (e.g. `selrai` → `https://selrai.pipedrive.com`). The domain is parsed from the post-login URL host in Phase 1-alt and stored alongside the token. A handful of endpoints not yet migrated to v2 (leads, notes, filters, files) live under `/api/v1` on the same host.

On the kit's own route, Phase 1-alt is autonomous via Playwright with one user step: Claude drives the whole capture inside a Playwright MCP browser - open the API settings page, let the user sign in, DOM-extract the personal API token, parse the company domain from the URL, write `~/.config/pipedrive/credentials.env` (mode 600), and verify with a live ping. The user's only manual moment is signing in to Pipedrive once. After that, Claude calls the Pipedrive REST API via `curl` to read and update data: deals, persons, organizations, leads, activities, pipelines, stages, notes, products, users.

**Which phase to run** - always start at **Phase 0** below. It checks the built-in connector first, then the kit's own credentials file (`~/.config/pipedrive/credentials.env` on Mac/Linux/WSL, `%APPDATA%\pipedrive\credentials.env` on native Windows, with a non-empty `PIPEDRIVE_API_TOKEN`) plus a smoke ping. A working connection on either route means skip straight to Phase 2 - never set one route up on top of the other.

**Existing accounts only.** This connector is for users who **already have a Pipedrive account or trial**. Do NOT use it to recommend or pitch Pipedrive to someone who does not already use it - if the user has no Pipedrive account, say so plainly and stop rather than walking them through a signup.

**Full account access.** A Pipedrive personal API token inherits the **same permissions and visibility as the user who owns it**. If that user is an admin, the token can read and write everything in the company account - treat it like a password. There is no separate read-only token type; scope is controlled entirely by the user's permission set and visibility groups. (For least-privilege, an admin can create a dedicated limited user and capture *their* token.)

---

## Communication rules (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Both routes are autonomous - Claude does the work. The user only signs in to Pipedrive once. Every message during either route follows these rules:

- **Which browser opens, and why.** On the built-in route you open the user's **own everyday browser** - that is where they are already signed in to Claude - and it reads nothing from that browser. On the kit's own route everything happens in a separate window Claude drives, and you **never** open the user's own browser, because that route reads the connection key off the page. The two rules do not conflict; they belong to different routes.
- **Never ask for a password, a sign-in code, or a screenshot of a sign-in screen** on either route.
- **Restart, only on the built-in route.** If the built-in connector doesn't show up after connecting, ask the user to close and reopen Claude once. The kit's own route needs no restart (see below).
- **You drive, not them.** Never ask the user to click menus, copy text, or paste values in the happy path. The only action you request is "please sign in to Pipedrive in the browser window I just opened."
- **Plain English only.** No jargon. Never say API, token, REST, curl, header, DOM, Playwright, env, JSON, endpoint, or file path. Name technical things plainly: "the connection", "your Pipedrive account", "your browser".
- **Tell them what is about to happen.** "I'm going to connect Pipedrive for you - this takes about a minute."
- **React warmly to success and failure.** Good: "That worked - your Pipedrive is now connected." Never show a raw error message; translate to plain English and try the documented recovery.
- **Short responses.** Maximum 8 lines per message while connecting.
- **Never echo the API token** in a narration line, a tool return, or a log. It is stored locally and referenced by name only.
- **No restart needed on the kit's own route.** Unlike the MCP-based connectors, it works the instant the token is saved - do NOT ask the user to restart Claude Code for it. (The built-in route is the exception above.)

---

## Cross-cutting: Playwright MCP install contingency

Phase 1-alt drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag is mandatory - the persistent profile keeps the Pipedrive login alive across sessions.

---

## PHASE 0 - Is Pipedrive already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Pipedrive` (match the vendor word case-insensitively).
   - `✔ Connected` → skip to **Phase 2**. Prove it first with one read from the `mcp__claude_ai_Pipedrive__*` namespace (list a couple of deals) before saying so.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` in the user's own browser (`open` on Mac, `xdg-open` on Linux, `start "" <url>` on Windows) and say: *"Your Pipedrive connection needs a quick re-sign-in. Press Reconnect next to Pipedrive, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Check for the credentials file, then smoke-ping it:

   ```bash
   CRED_FILE="$HOME/.config/pipedrive/credentials.env"
   if [ -f "$CRED_FILE" ] && grep -q '^PIPEDRIVE_API_TOKEN=.\+' "$CRED_FILE"; then echo "configured"; else echo "not-configured"; fi
   ```

   Smoke ping (token read from file, never printed):

   ```bash
   set -a; . "$HOME/.config/pipedrive/credentials.env"; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "x-api-token: $PIPEDRIVE_API_TOKEN" \
     "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/deals?limit=1"
   ```

   - `configured` + HTTP 200 → keep using it. Tell the user warmly *"You're already connected - let me check it still works,"* then go to **Phase 2**. Do not set the built-in up on top of a working connection.
   - `configured` + HTTP 401 → the token was regenerated or revoked. If the user's need is inside the built-in's coverage (see the routing table), prefer **Phase 1**; otherwise re-run **Phase 1-alt**.
   - `not-configured` → continue.
3. **Nothing found** → **Phase 1**.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Pipedrive's tools.

---

## Route by need - built-in or the kit's route?

Before installing anything, ask one question in plain English: **what does the user want Claude to do with Pipedrive?** Then route what they name:

| What the user wants | Route |
|---|---|
| Deals - list, look up, add, update, search | **Built-in** |
| People (persons/contacts) - look up, add, update, search | **Built-in** |
| Activities - calls, meetings, tasks: look up, add, update, search | **Built-in** |
| Notes on deals, people or organisations | The kit's own route (Phase 1-alt) |
| Products and the product catalogue | The kit's own route (Phase 1-alt) |
| Organisations (companies) | The kit's own route (Phase 1-alt) |
| Leads - the pre-deal inbox | The kit's own route (Phase 1-alt) |
| Users and saved filters | The kit's own route (Phase 1-alt) |
| The session can't see built-in connectors at all (Phase 1 Step 1 fails), or the user explicitly asks for the local setup | The kit's own route (Phase 1-alt) |

Both routes can coexist on one machine. Never tear one down to set the other up, and never burden the user with the kit's extra setup when the built-in already covers what they asked for. Say in one line what you are *not* connecting and why, so they can ask for it later.

---

## PHASE 1 - Switch on the built-in Pipedrive connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening Pipedrive's page in your browser. Press **Connect to Claude**, sign in to Pipedrive the way you normally do, and say yes when it asks for access. That is the only part only you can do - tell me when it says Connected."* Then open `https://claude.ai/directory/pipedrive-mcp` in their own browser (`open` / `xdg-open` / `start`) - note the `-mcp` on the end; the bare `pipedrive` slug is not the listing. If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Pipedrive" → Connect. In the desktop app's Code tab the better route is the composer's **+** → **Connectors** → **Browse connectors** → the **+** next to it: that one shows up in the running session without a restart, whereas the browser page needs the app quit and reopened before any session sees the tools.

The page is listed as a **community** connector - it carries no Verified badge and says community connectors have had automated reviews but aren't verified by Anthropic. Tell the user that plainly in one line before they press Connect, and tell them the other half too: it is Pipedrive's own server (Pipedrive announced it themselves), which is why it is still the right first stop. Blurb on the page: *"Find deals, update records, manage activities and work with your live CRM data"*.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Pipedrive … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the same settings page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - list a couple of deals from the `mcp__claude_ai_Pipedrive__*` namespace. Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now.

**Team or Enterprise accounts:** if the row shows **Request** instead of **Connect**, their Claude admin has to switch Pipedrive on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-ALT - Install & Connect (autonomous via Playwright)

**Run this only when** the user's named need is in the kit's-route column above (notes, products, organisations, leads, users, filters), the session can't see built-in connectors (Step 1 failed), no Pipedrive listing appears under Browse on the user's account, or the user explicitly wants the local setup. Otherwise stay on Phase 1.

> **Reasoning model.** Each step describes a *goal*. Achieve it via `browser_snapshot` → reason → `browser_click` / `browser_evaluate`. Match elements by visible labels, not brittle selector paths - Pipedrive's UI evolves.

> **Never snapshot the sign-in page.** If you `browser_snapshot` Pipedrive's login page, the accessibility tree can include the literal password value when a password manager has auto-filled the field. Detect post-login by polling `location.href` with `browser_evaluate` instead (memory `reference_playwright_snapshot_password_leak`).

### Step 1 - Open the API settings page and confirm a logged-in session

Tell the user: *"Opening a browser window - please sign in to Pipedrive when it appears. I'll do the rest."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.pipedrive.com/settings/api" })
```

This is the company-scoped **Settings → Personal preferences → API** page; navigate straight to the URL rather than clicking the menu path. Everything happens in the Playwright window - **never open the user's own browser** for any part of this flow.

`app.pipedrive.com` redirects to the login page when signed out, then to the user's own `https://<company>.pipedrive.com/settings/api` after sign-in. Pipedrive supports email+password and Google / Microsoft SSO - any is fine. Do NOT snapshot. Poll for the signed-in state by watching the URL settle on the API settings path:

```
mcp__plugin_playwright_playwright__browser_evaluate({ function: "() => ({ url: location.href, host: location.host })" })
```

Re-poll every ~10-15s until `host` matches `*.pipedrive.com` AND `url` ends with `/settings/api` (i.e. no longer `/auth/login`). If it stalls, check in once: *"Still on the sign-in page? Let me know when you're in."* SSO can bounce through `accounts.google.com` / `login.microsoftonline.com` mid-flow - that is normal; keep polling.

### Step 2 - Capture the token and company domain (DOM-extract, never screenshot)

The personal API token sits in a readonly input on this page (a 40-char hex string). It is **persistent**, not shown-once - so capture is safe and re-runnable. Read it via `browser_evaluate` straight into the clipboard, returning only metadata plus the (non-secret) company domain:

```js
async () => {
  // Pipedrive personal API token: 40-char hex, lives in a readonly input.
  let tok = null;
  for (const i of document.querySelectorAll('input')) {
    const v = (i.value || '').trim();
    if (/^[a-f0-9]{40}$/i.test(v)) { tok = v; break; }
  }
  const domain = location.host.split('.')[0];   // e.g. "selrai" from selrai.pipedrive.com
  if (!tok) return { ok: false, domain };
  try { await navigator.clipboard.writeText(tok); return { ok: true, len: tok.length, domain }; }
  catch (e) { return { ok: false, reason: 'clipboard_write_failed', domain }; }
}
```

If `ok: false` and the host is still a login domain, the user is not signed in yet - return to Step 1's polling. If `ok: false` on the right page, the token field may be collapsed under a "Show/Generate" control - `browser_snapshot`, click the reveal/generate control, then re-run this extraction. Conversational fallback: *"I'm having trouble reading your connection key automatically - could you paste it for me?"* (the token transits the transcript in this path; accepted trade-off, same as the GitHub-connector fallback).

### Step 3 - Store the token (silent), scrub artifacts

Read the token from the clipboard and write the credentials file. Never echo the value. Substitute the domain captured in Step 2.

```bash
install -d -m 700 "$HOME/.config/pipedrive"
# Cross-platform clipboard read: wl-paste (Wayland) / xclip (X11) / pbpaste (macOS) / powershell Get-Clipboard (Windows)
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
DOMAIN="selrai"   # <-- replace with the `domain` value returned by Step 2
umask 077
cat > "$HOME/.config/pipedrive/credentials.env" <<EOF
# Pipedrive REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: send header  x-api-token: \$PIPEDRIVE_API_TOKEN   (NOT Authorization: Bearer)
# Base URL: https://\$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2  (v1 for leads/notes/filters/files)
PIPEDRIVE_API_TOKEN=${TOKEN}
PIPEDRIVE_COMPANY_DOMAIN=${DOMAIN}
EOF
chmod 600 "$HOME/.config/pipedrive/credentials.env"
unset TOKEN
# Scrub the transient Playwright snapshot dir, which auto-snapshots each action and can
# capture the token from the settings page. Remove it WHOLESALE.
# NEVER `grep -rl <hex> | xargs rm`: a 40-hex substring could match unrelated files.
rm -rf .playwright-mcp 2>/dev/null   # snapshots are written relative to the session working dir
```

> **Cross-platform note.** Native Windows stores at `%APPDATA%\pipedrive\credentials.env`; everywhere else `~/.config/pipedrive/credentials.env`. Never hardcode a machine path.

### Step 4 - Smoke test and report

```bash
set -a; . "$HOME/.config/pipedrive/credentials.env"; set +a
curl -s -H "x-api-token: $PIPEDRIVE_API_TOKEN" \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v1/users/me" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); u=d.get("data",{}); print("OK" if d.get("success") else "FAIL", "-", u.get("name"), "-", u.get("company_name"))'
```

Expect `OK - <name> - <company>`. Tell the user: *"All connected - your Pipedrive is ready. You can ask me things like 'show my open deals' or 'add a deal for a new lead'."* **No restart needed.**

---

## PHASE 2 - Use the connector

**Which tool namespace.** Through the built-in connector the tools are `mcp__claude_ai_Pipedrive__*` - deals, persons and activities, get/add/update/search - and there is no `curl`, no credentials file and no company domain to manage. Through the kit's own route it is the REST runtime loop below. The two are named quite differently: on the built-in route, list what is actually in the `mcp__claude_ai_Pipedrive__*` namespace and match by what each tool does, rather than looking for the endpoints in this section. Anything in the table below that the built-in has no tool for (notes, products, organisations, leads, users, filters) is what the kit's own route is for.

### The kit's own route - REST runtime loop

Once `~/.config/pipedrive/credentials.env` exists, follow this loop on every Pipedrive request.

1. Load the token (never print it) and define a helper:

   ```bash
   set -a; . "$HOME/.config/pipedrive/credentials.env"; set +a
   PD() { curl -s -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Accept: application/json" \
            "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com$@"; }
   ```

2. Read with a `GET`, pipe through `jq`:

   ```bash
   PD /api/v2/deals?limit=20 | jq '.data[] | {id, title, value, currency, status, stage_id, person_id}'
   ```

3. Paginate (v2 is **cursor-based**). Loop while `additional_data.next_cursor` is non-null, passing it back as `cursor=`:

   ```bash
   cursor=""; while :; do
     resp=$(PD "/api/v2/deals?limit=100${cursor:+&cursor=$cursor}")
     echo "$resp" | jq -c '.data[]'
     cursor=$(echo "$resp" | jq -r '.additional_data.next_cursor // empty')
     [ -z "$cursor" ] && break
   done
   ```

   > **v1 paginates differently** (offset-based): pass `start=` / `limit=` and loop while `additional_data.pagination.more_items_in_collection` is `true`.

4. Search (v2 exposes per-entity search):

   ```bash
   PD "/api/v2/persons/search?term=jane%40example.com&fields=email" | jq '.data.items[].item | {id, name}'
   ```

5. Write with `POST` (create) / `PATCH` (update, v2) to the entity collection. **Confirm any client-visible or destructive write with the user first**:

   ```bash
   # create a deal
   curl -s -X POST -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Content-Type: application/json" \
     -d '{"title":"Acme Pty Ltd - website refresh","value":4500,"currency":"AUD","person_id":123}' \
     "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/deals" | jq '.data.id'
   ```

   > **v1 updates use `PUT`**, not `PATCH`. If a v2 `PATCH` returns 404 for an entity, that entity is v1-only - fall back to `/api/v1/<entity>/<id>` with `PUT`.

**Core resources** (full catalogue + field reference in `references/rest-api.md`):

| Resource | v2 endpoint | Notes |
|---|---|---|
| Deals | `/api/v2/deals` | central object; `status` ∈ open / won / lost / deleted |
| Persons (contacts) | `/api/v2/persons` | people |
| Organizations | `/api/v2/organizations` | companies |
| Pipelines | `/api/v2/pipelines` | sales pipelines |
| Stages | `/api/v2/stages` | columns within a pipeline |
| Activities | `/api/v2/activities` | calls/meetings/tasks |
| Products | `/api/v2/products` | catalogue items |
| Users | `/api/v1/users` | account users (`/users/me` for the token owner) |
| Leads | `/api/v1/leads` | **v1 only** - pre-deal inbox |
| Notes | `/api/v1/notes` | **v1 only** - notes on deals/persons/orgs |
| Filters | `/api/v1/filters` | **v1 only** - saved filters |

---

## Gotchas

- **`Authorization: Bearer` returns 401.** Personal API tokens authenticate via the `x-api-token` header (or the legacy `?api_token=` query param). Bearer is OAuth-only. This is the #1 Pipedrive integration mistake.
- **Company-scoped host is mandatory.** Calls must go to `https://<company>.pipedrive.com`. The generic `https://api.pipedrive.com` also accepts the token but the company subdomain is the documented, lowest-latency path and is what Phase 1 stores. Never hardcode a domain - read `$PIPEDRIVE_COMPANY_DOMAIN`.
- **v1 vs v2 split.** Most CRUD is on `/api/v2`, but **leads, notes, filters, and files are v1-only**. v2 uses cursor pagination + `PATCH`; v1 uses offset pagination + `PUT`. Pick the right pair per entity (table above).
- **No substring-negation in self-checks.** When testing whether the token works, match the explicit success condition (`http_code == 200` or `.success == true`), never "does the output NOT contain an error word" - negation-based checks silently pass when the output shape changes, a known false-pass audit footgun.
- **401 Unauthorized** → token regenerated, revoked, or the trial/account lapsed → re-run Phase 1-alt (the token field on the settings page always shows the current value).
- **403 Forbidden** → the token owner lacks permission/visibility for that record. This is a user-permission limit, not a token-type limit (there is no read-only token). An admin's token sees everything.
- **429 / rate limits.** Pipedrive v2 uses a per-company + per-user **token-budget** model (not simple req/min). On `429`, back off and retry; for bulk reads prefer `limit=100` with cursor paging over many small calls.
- **Token regeneration breaks the connector.** If the user clicks "regenerate" on the API settings page, the stored token dies → re-run Phase 1-alt. Treat the token as a password; it lives only in `~/.config/pipedrive/credentials.env` (mode 600), never in git.

## Token handling

The personal API token is a bearer-equivalent secret. It is stored in `~/.config/pipedrive/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, a tool return, or a log. Add `**/credentials.env` to any repo `.gitignore` before committing work near this skill - though the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1-alt transcript (token redacted).
- `references/rest-api.md` - endpoint catalogue, v1/v2 split, field notes, and pagination syntax.
- `skills/CLAUDE.md` - the direct-REST connector family (`servicem8`, `cliniko`, `myob`, `ghl`) and the Playwright contingency.
