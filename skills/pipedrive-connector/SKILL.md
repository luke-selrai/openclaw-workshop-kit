---
name: pipedrive-connector
description: "Connect and operate Pipedrive (sales CRM / pipeline management) via its direct REST API for users who already have a Pipedrive account or trial. Drives the one-time API-token setup inside a Playwright MCP browser - opens the company-scoped Settings → Personal preferences → API page, lets the user sign in (email+password or Google/Microsoft SSO), then DOM-extracts the personal API token and parses the company domain from the post-login URL - without ever opening the user's own browser. Persists both to ~/.config/pipedrive/credentials.env (mode 600) and reads/writes Pipedrive data with curl against https://COMPANY.pipedrive.com/api/v2 using the x-api-token header (NOT Authorization: Bearer - that is OAuth-only and returns 401). No vendor MCP server and no OAuth - a standalone direct-REST connector, so there is NO Claude Code restart step. Handles deals, persons (contacts), organizations, leads, activities, pipelines and stages, notes, products, and users. Use this skill when the user asks to 'connect my Pipedrive', 'set up Pipedrive', or asks anything about their Pipedrive deals, contacts, leads, pipeline, sales activities, or forecast, or says 'create a deal in Pipedrive'. Do NOT use to recommend Pipedrive to users who do not already use it. On the first use of any Pipedrive feature, run Phase 1 to capture and store the API token before attempting any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
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

This skill lets Claude read and update a user's Pipedrive data on their behalf. Pipedrive is the sales-pipeline CRM popular with SMB sales teams. It publishes **no first-party MCP server**, so this is a **standalone direct-REST connector** - the same shape as `servicem8-connector`, `cliniko-connector`, `myob-connector`, and `ghl-connector` in the direct-REST family noted in `skills/CLAUDE.md`.

The architecture is dead simple. Claude reads one static personal API token out of `~/.config/pipedrive/credentials.env`, then runs `curl` against Pipedrive's REST endpoints. Two Pipedrive specifics matter:

- **Auth is the `x-api-token` header.** Every call carries `x-api-token: <token>`. **Do NOT use `Authorization: Bearer`** - that header is reserved for OAuth access tokens and returns `401` with a personal API token. (The legacy `?api_token=<token>` query param also works but puts the secret in URLs/logs - prefer the header.)
- **The base URL is company-scoped.** It is `https://<company-domain>.pipedrive.com/api/v2`, where `<company-domain>` is the subdomain of the user's Pipedrive account (e.g. `selrai` → `https://selrai.pipedrive.com`). The domain is parsed from the post-login URL host in Phase 1 and stored alongside the token. A handful of endpoints not yet migrated to v2 (leads, notes, filters, files) live under `/api/v1` on the same host.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright, with one user step).** Claude drives the whole capture inside a Playwright MCP browser: open the API settings page, let the user sign in, DOM-extract the personal API token, parse the company domain from the URL, write `~/.config/pipedrive/credentials.env` (mode 600), and verify with a live ping. The user's only manual moment is signing in to Pipedrive once.
- **Phase 2 - Use the connector.** Once the token is saved, Claude calls the Pipedrive REST API via `curl` to read and update data: deals, persons, organizations, leads, activities, pipelines, stages, notes, products, users.

**Which phase to run** - Before any Pipedrive action, check for `~/.config/pipedrive/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\pipedrive\credentials.env` (native Windows). If it exists with a non-empty `PIPEDRIVE_API_TOKEN`, run the Phase 0 smoke ping; on success, skip to Phase 2. Otherwise run Phase 1.

**Full account access.** A Pipedrive personal API token inherits the **same permissions and visibility as the user who owns it**. If that user is an admin, the token can read and write everything in the company account - treat it like a password. There is no separate read-only token type; scope is controlled entirely by the user's permission set and visibility groups. (For least-privilege, an admin can create a dedicated limited user and capture *their* token.)

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work. The user only signs in to Pipedrive once. Every message during Phase 1 follows these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, or paste values in the happy path. The only action you request is "please sign in to Pipedrive in the browser window I just opened."
- **Plain English only.** No jargon. Never say API, token, REST, curl, header, DOM, Playwright, env, JSON, endpoint, or file path. Name technical things plainly: "the connection", "your Pipedrive account", "your browser".
- **Tell them what is about to happen.** "I'm going to connect Pipedrive for you - this takes about a minute."
- **React warmly to success and failure.** Good: "That worked - your Pipedrive is now connected." Never show a raw error message; translate to plain English and try the documented recovery.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo the API token** in a narration line, a tool return, or a log. It is stored locally and referenced by name only.
- **No restart needed.** Unlike the MCP-based connectors, this one works the instant the token is saved - do NOT ask the user to restart Claude Code.

---

## Cross-cutting: Playwright MCP install contingency

Phase 1 drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag is mandatory - the persistent profile keeps the Pipedrive login alive across sessions.

---

## PHASE 0 - Resume check

Run before any Phase 1 work.

```bash
CRED_FILE="$HOME/.config/pipedrive/credentials.env"
if [ -f "$CRED_FILE" ] && grep -q '^PIPEDRIVE_API_TOKEN=.\+' "$CRED_FILE"; then echo "configured"; else echo "not-configured"; fi
```

- `configured` → run the smoke ping below. On HTTP 200, tell the user warmly "You're already connected - let me check it still works," then go to **Phase 2**. On HTTP 401, the token was regenerated or revoked - re-run **Phase 1**.
- `not-configured` → run **Phase 1**.

Smoke ping (token read from file, never printed):

```bash
set -a; . "$HOME/.config/pipedrive/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "x-api-token: $PIPEDRIVE_API_TOKEN" \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/deals?limit=1"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step describes a *goal*. Achieve it via `browser_snapshot` → reason → `browser_click` / `browser_evaluate`. Match elements by visible labels, not brittle selector paths - Pipedrive's UI evolves.

> **Never snapshot the sign-in page.** If you `browser_snapshot` Pipedrive's login page, the accessibility tree can include the literal password value when a password manager has auto-filled the field. Detect post-login by polling `location.href` with `browser_evaluate` instead (memory `reference_playwright_snapshot_password_leak`).

### Step 1 - Open the API settings page and confirm a logged-in session

Tell the user: *"Opening a browser window - please sign in to Pipedrive when it appears. I'll do the rest."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.pipedrive.com/settings/api" })
```

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

## PHASE 2 - Use the connector (REST runtime loop)

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
- **401 Unauthorized** → token regenerated, revoked, or the trial/account lapsed → re-run Phase 1 (the token field on the settings page always shows the current value).
- **403 Forbidden** → the token owner lacks permission/visibility for that record. This is a user-permission limit, not a token-type limit (there is no read-only token). An admin's token sees everything.
- **429 / rate limits.** Pipedrive v2 uses a per-company + per-user **token-budget** model (not simple req/min). On `429`, back off and retry; for bulk reads prefer `limit=100` with cursor paging over many small calls.
- **Token regeneration breaks the connector.** If the user clicks "regenerate" on the API settings page, the stored token dies → re-run Phase 1. Treat the token as a password; it lives only in `~/.config/pipedrive/credentials.env` (mode 600), never in git.

## Token handling

The personal API token is a bearer-equivalent secret. It is stored in `~/.config/pipedrive/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, a tool return, or a log. Add `**/credentials.env` to any repo `.gitignore` before committing work near this skill - though the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1 transcript (token redacted).
- `references/rest-api.md` - endpoint catalogue, v1/v2 split, field notes, and pagination syntax.
- `skills/CLAUDE.md` - the direct-REST connector family (`servicem8`, `cliniko`, `myob`, `ghl`) and the Playwright contingency.
