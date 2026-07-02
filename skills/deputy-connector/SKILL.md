---
name: deputy-connector
description: "Connect and operate Deputy (employee scheduling, rostering, timesheets, HR) via its direct REST API for users who already have a Deputy business/install. Drives the one-time token setup inside a Playwright MCP browser - the user signs in (Google SSO or email, plus any verification code), then Claude creates an OAuth client named 'Claude Code' at the install's developer page and mints a long-life Permanent Token, DOM-extracting it (shown only once) without ever opening the user's own browser. Deputy installs are addressed by an install+region subdomain (e.g. b9e78716081714.au.deputy.com); both are read from the post-login URL, and the base URL is https://INSTALL.GEO.deputy.com/api/v1. The token is stored at ~/.config/deputy/credentials.env (mode 600) and every call sends Authorization: Bearer TOKEN. No vendor MCP and no OAuth consent loop for the runtime - a standalone direct-REST connector, so there is NO Claude Code restart. Handles the authenticated user, employees, rosters/shifts, timesheets, operational units (areas/locations), leave, and company info. Use this skill when the user asks to 'connect my Deputy', 'set up Deputy', or asks anything about their Deputy rosters, shifts, schedule, timesheets, employees, team, or leave. Do NOT use to recommend Deputy to users who do not already use it, and do NOT create a Deputy business - the connector assumes an existing install. On the first use of any Deputy feature, run Phase 1 to mint and store the token before attempting any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - deputy
    - rostering
    - scheduling
    - timesheets
    - workforce
    - hr
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Deputy auth (401) or permission (403) errors
    - skill: myob-connector
      reason: Sibling direct-REST connector - same Playwright-install + curl-runtime shape
---

# Deputy Connector

## Overview

This skill lets Claude read and update a user's Deputy data on their behalf. Deputy is the employee-scheduling / rostering / timesheets / HR app used widely by hospitality and retail SMBs. It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the same shape as the `ghl-connector` and `myob-connector` direct-REST family noted in `skills/CLAUDE.md`.

The architecture is dead simple. Claude reads one Bearer token out of `~/.config/deputy/credentials.env`, then runs `curl` against Deputy's REST endpoints. Two Deputy specifics shape the connector:

- **Install + region subdomain.** Every Deputy account is an "install" addressed as `{install}.{geo}.deputy.com` (e.g. `b9e78716081714.au.deputy.com`, geo `au`). Both parts are read from the URL after the user signs in; the base URL is `https://{install}.{geo}.deputy.com/api/v1`.
- **Permanent Token via an OAuth client.** There is no settings-page "API key". Instead you create an OAuth client at `/exec/devapp/oauth_clients`, then click **Get An Access Token** to mint a **Permanent Token** (a long-life Bearer token - Deputy states it lasts ~10 years). Auth on every call is `Authorization: Bearer <token>`.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** Claude drives the whole token mint: the user signs in, Claude reads the install+geo from the URL, creates the `Claude Code` OAuth client, mints the Permanent Token, captures it, writes `~/.config/deputy/credentials.env` (mode 600), and verifies with a live ping. The user's only manual moment is signing in (and the connector assumes the user already has a Deputy business - it never creates one).
- **Phase 2 - Use the connector.** Once the token is saved, Claude calls the Deputy REST API via `curl` to read and update data: the authenticated user, employees, rosters, timesheets, operational units, leave, company.

**Which phase to run** - Before any Deputy action, check for `~/.config/deputy/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\deputy\credentials.env` (native Windows). If it exists with a non-empty `DEPUTY_API_TOKEN`, run the Phase 0 smoke ping; on success, skip to Phase 2. Otherwise run Phase 1.

**Assumes an existing install.** Like the other already-a-customer connectors, this skill does NOT onboard a new Deputy business. If the user has no business yet (`once.deputy.com/my/` shows "You aren't currently a member of any business"), tell them to create one in Deputy first - that is product onboarding, not the connector's job.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work. Every message during Phase 1 follows these rules:

- **You drive, not them.** The only action you request is "please sign in to Deputy in the browser window I just opened."
- **Plain English only.** No jargon - no API, token, REST, curl, header, OAuth client, Bearer, subdomain, DOM, Playwright, env, JSON, endpoint. Name things plainly: "the connection", "your Deputy account", "your browser".
- **Tell them what is about to happen** before each action; **react warmly**; **never show raw errors**.
- **Short responses** - max 8 lines per message during Phase 1.
- **Never echo the token** (or the OAuth client secret) in a narration line, a tool return, or a log.
- **No restart needed** - this connector works the instant the token is saved; do NOT ask the user to restart Claude Code.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code, and retry.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/deputy/credentials.env"
if [ -f "$CRED" ] && grep -q '^DEPUTY_API_TOKEN=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → run the smoke ping. On HTTP 200, tell the user "You're already connected - let me check it still works," then go to **Phase 2**. On 401/403, the token was revoked or the role changed - re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (token read from file, never printed):

```bash
set -a; . "$HOME/.config/deputy/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $DEPUTY_API_TOKEN" \
  -H "Accept: application/json" "$DEPUTY_API_BASE/me"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step is a *goal*; achieve it via `browser_snapshot`/`browser_evaluate` → reason → click/type. Match elements by visible labels; re-query after navigations.

> **Never snapshot the sign-in page** - the accessibility tree can include an auto-filled password value. Detect post-login with `browser_wait_for`.

### Step 1 - Sign in and capture the install + geo

Open Deputy's account hub and let the user sign in:

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://once.deputy.com/my/" })
```

Tell the user: *"Please sign in to Deputy in the browser window (Google or email - enter any code it sends)."* Then poll for the signed-in hub:

```
mcp__plugin_playwright_playwright__browser_wait_for({ text: "Businesses", time: 30 })
```

From `once.deputy.com/my/`, the user's business links to their install. Open the business (click it), then read `window.location.host` - it is `{install}.{geo}.deputy.com`. Parse:

```js
() => { const h = location.host; const m = h.match(/^([^.]+)\.([a-z]{2}\d?)\.deputy\.com$/); return { host:h, install:m&&m[1], geo:m&&m[2] }; }
```

Hold `INSTALL` and `GEO` for the next steps. (If `once.deputy.com/my/` shows no business, stop - see "Assumes an existing install" above.)

### Step 2 - Open the developer (OAuth clients) page

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://{install}.{geo}.deputy.com/exec/devapp/oauth_clients" })
```

Snapshot. The page lists existing OAuth clients (Deputy ships several system ones - **leave them alone**) and a **New OAuth Client** button. Check whether a `Claude Code` client already exists:

- exists **and** `~/.config/deputy/credentials.env` has a token → already set up; skip to Step 6 (smoke).
- exists but no stored token → its token is unrecoverable; open it and mint a fresh token (Step 5), or Delete it and recreate (Step 3).
- no `Claude Code` client → continue to Step 3.

### Step 3 - Create the OAuth client

```
mcp__plugin_playwright_playwright__browser_click({ element: "New OAuth Client", target: "text=New OAuth Client" })
```

Fill the form (Name and Redirect URI are required; the redirect URI is unused for a permanent token, so a placeholder is fine):

```
mcp__plugin_playwright_playwright__browser_type({ element: "client name", target: "#fpName", text: "Claude Code" })
mcp__plugin_playwright_playwright__browser_type({ element: "redirect uri", target: "#fpRedirectUri", text: "https://localhost/callback" })
mcp__plugin_playwright_playwright__browser_click({ element: "Save", target: "text=Save This OAuth Client" })
```

### Step 4 - Mint the Permanent Token

On the saved client's detail view, click:

```
mcp__plugin_playwright_playwright__browser_click({ element: "Get An Access Token", target: "text=Get An Access Token" })
```

A modal appears: *"Access Token is XXXX. This is a long life token that will last 10 years."*

### Step 5 - Capture the token (DOM-extract, never screenshot)

**Do NOT screenshot or snapshot the modal** - read the token via `browser_evaluate` into the clipboard, returning only length:

```js
async () => {
  const vis = el => el && el.offsetParent !== null;
  const dlg = [...document.querySelectorAll('[role=dialog], .modal, .ui-dialog, .swal2-popup, .modal-body')].find(vis);
  const txt = (dlg ? dlg.textContent : document.body.textContent) || '';
  const m = txt.match(/Access Token is\s+([A-Za-z0-9]{16,})/);
  if (!m) return { ok:false };
  try { await navigator.clipboard.writeText(m[1]); return { ok:true, len:m[1].length }; }
  catch(e){ return { ok:false, reason:'clipboard', len:m[1].length }; }
}
```

If `ok:false`, re-snapshot and retry once. Conversational fallback: ask the user to paste the token (accepted transcript-leak trade-off, same as other connectors).

### Step 6 - Store the token (silent), scrub artifacts

```bash
install -d -m 700 "$HOME/.config/deputy"
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
umask 077
cat > "$HOME/.config/deputy/credentials.env" <<EOF
# Deputy REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: Bearer token:  curl -H "Authorization: Bearer \$DEPUTY_API_TOKEN" ...
DEPUTY_API_TOKEN=${TOKEN}
DEPUTY_INSTALL=${INSTALL}.${GEO}.deputy.com
DEPUTY_GEO=${GEO}
DEPUTY_API_BASE=https://${INSTALL}.${GEO}.deputy.com/api/v1
EOF
chmod 600 "$HOME/.config/deputy/credentials.env"
( printf '' | wl-copy 2>/dev/null ) || ( printf '' | xclip -selection clipboard -i 2>/dev/null ) || true
rm -rf .playwright-mcp 2>/dev/null   # snapshots can capture the token; never grep+rm on the token substring (it also matches docs/this file)
unset TOKEN INSTALL GEO
```

### Step 7 - Smoke test and report

```bash
set -a; . "$HOME/.config/deputy/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $DEPUTY_API_TOKEN" \
  -H "Accept: application/json" "$DEPUTY_API_BASE/me"
```

Expect `200`. Tell the user: *"All connected - your Deputy is ready. Ask me things like 'who's on my team?' or 'show this week's roster'."* **No restart needed.**

---

## PHASE 2 - Use the connector (REST runtime loop)

Once `~/.config/deputy/credentials.env` exists, follow this loop on every Deputy request.

1. Load credentials (never printed):

   ```bash
   set -a; . "$HOME/.config/deputy/credentials.env"; set +a
   DEP() { curl -s -H "Authorization: Bearer $DEPUTY_API_TOKEN" -H "Accept: application/json" "$@"; }
   ```

2. Read the authenticated user / a resource:

   ```bash
   DEP "$DEPUTY_API_BASE/me" | jq '{Name, Company}'
   DEP "$DEPUTY_API_BASE/resource/Employee" | jq '.[] | {Id, DisplayName, Active}'
   ```

3. Query a resource with filters via `POST /resource/<Object>/QUERY` (Deputy's search API takes `search`, `join`, `sort`, `max`):

   ```bash
   DEP -X POST -H "Content-Type: application/json" \
     -d '{"search":{"f1":{"field":"Active","type":"eq","data":true}},"max":100}' \
     "$DEPUTY_API_BASE/resource/Employee/QUERY" | jq 'length'
   ```

4. Write - create with `POST /resource/<Object>`, update with `POST /resource/<Object>/<id>`, delete with `DELETE /resource/<Object>/<id>`. Always **confirm roster/timesheet/employee writes with the user first**:

   ```bash
   DEP -X POST -H "Content-Type: application/json" \
     -d '{"FirstName":"Test","LastName":"Employee"}' \
     "$DEPUTY_API_BASE/resource/Employee"
   ```

**Core resources** (full catalogue + query syntax in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Authenticated user | `me` | who the token belongs to (live-verified) |
| Employees | `resource/Employee` | team members |
| Rosters / shifts | `resource/Roster` | scheduled shifts |
| Timesheets | `resource/Timesheet` | worked time |
| Operational units | `resource/OperationalUnit` | areas / locations |
| Leave | `resource/Leave` | time-off |
| Company | `resource/Company` | the business/locations |

---

## Gotchas

- **Long-life, high-privilege token.** The Permanent Token lasts ~10 years and inherits the **creating user's permissions** (often the owner - full access). Treat it like a password: mode 600, never in git, and rotate it by deleting the `Claude Code` client at `/exec/devapp/oauth_clients` then re-minting (Phase 1).
- **Install + geo live in the subdomain.** Read both from the post-login URL (`{install}.{geo}.deputy.com`); the base URL and all calls depend on them. Don't hardcode a region.
- **Token shown once.** The "Get An Access Token" modal reveals it a single time. Capture-then-store in the same step; if lost, re-mint.
- **New OAuth Client requires a Redirect URI** even for a permanent token - use a placeholder (`https://localhost/callback`); it is not used by the Bearer flow.
- **Never snapshot the sign-in page** (password leak); detect login via `browser_wait_for`.
- **No substring-negation in self-checks.** Verify success by the explicit condition (`http_code == 200`), never "output does NOT contain an error word" - negation checks silently pass when the output shape changes.
- **Leave Deputy's system OAuth clients alone** (CloudWorks, Deputy Proxy, Exporter, etc.) - only create/edit/delete the `Claude Code` client.
- **401** → token revoked/invalid → re-run Phase 1. **403** → the user's role lacks permission for that resource. **429** → rate limited; back off and retry.

## Token handling

The Bearer token is a high-privilege secret stored in `~/.config/deputy/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, tool return, or log. Note: Deputy prints the token inside the reveal-modal text, so the Step 5 extractor reads dialog text directly - keep that value out of any tool return (return length only). Add `**/credentials.env` to any nearby repo `.gitignore`; the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1 transcript (token redacted).
- `references/rest-api.md` - endpoint catalogue, the `QUERY` search syntax, pagination.
- `skills/CLAUDE.md` - direct-REST connector family (`myob`, `ghl`) and the Playwright contingency.
