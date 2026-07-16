---
name: cliniko-connector
description: "Connect and operate Cliniko (allied-health / clinic practice management) via its direct REST API for users who already have a Cliniko account or trial. Drives the one-time API-key setup inside a Playwright MCP browser - the user signs in (email, password, and the emailed verification code), then Claude enables the per-user API-key permission, mints a key named 'Claude Code', and DOM-extracts it (shown only once) without ever opening the user's own browser. The key's region shard (e.g. au1, au5, uk2, us1) is parsed from the key suffix to build the base URL https://api.SHARD.cliniko.com/v1. The key is stored at ~/.config/cliniko/credentials.env (mode 600) and every call uses HTTP Basic auth (the key as username, blank password) plus a required User-Agent header. No vendor MCP and no OAuth - a standalone direct-REST connector, so there is NO Claude Code restart. Handles practitioners, patients, appointments and bookings, businesses, appointment types, invoices, products, and contacts. Use this skill when the user asks to 'connect my Cliniko', 'set up Cliniko', or asks anything about their Cliniko patients, appointments, bookings, practitioners, invoices, or clinic schedule. Do NOT use to recommend Cliniko to users who do not already use it. On the first use of any Cliniko feature, run Phase 1 to enable API keys, mint and store the key before attempting any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - cliniko
    - allied-health
    - healthcare
    - practice-management
    - appointments
    - patients
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Cliniko auth (401) or permission (403) errors
    - skill: myob-connector
      reason: Sibling direct-REST connector - same Playwright-install + curl-runtime shape
---

# Cliniko Connector

## Overview

This skill lets Claude read and update a user's Cliniko data on their behalf. Cliniko is the allied-health clinic-management app (physiotherapy, psychology, chiropractic, podiatry) dominant in AU/NZ. It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the same shape as the `ghl-connector` and `myob-connector` direct-REST family noted in `skills/CLAUDE.md`.

The architecture is dead simple. Claude reads one static API key out of `~/.config/cliniko/credentials.env`, then runs `curl` against Cliniko's REST endpoints. Two Cliniko specifics differ from a vanilla key connector:

- **Sharding.** Cliniko runs regional shards (`au1`, `au2`, `au5`, `uk2`, `us1`, …). The shard is **appended to the API key** (e.g. `…-au5`). The base URL is derived from it: `https://api.SHARD.cliniko.com/v1`.
- **Auth + required User-Agent.** Every call uses **HTTP Basic** auth - the API key as the username with a blank password (`curl -u "$CLINIKO_API_KEY:"`) - **and** a `User-Agent` header that Cliniko *requires* (include a contact email). Omitting the User-Agent fails.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright, with one user step).** Claude drives the whole key-mint inside a Playwright MCP browser: the user signs in, Claude enables the per-user API-key permission, mints a key named `Claude Code`, captures it, parses the shard, writes `~/.config/cliniko/credentials.env` (mode 600), and verifies with a live ping. The user's manual moments are (1) signing in (email + password + emailed code) and (2) a one-time password **Security check** Cliniko shows when the API-key permission is first enabled.
- **Phase 2 - Use the connector.** Once the key is saved, Claude calls the Cliniko REST API via `curl` to read and update data: practitioners, patients, appointments, bookings, businesses, invoices, products, contacts.

**Which phase to run** - Before any Cliniko action, check for `~/.config/cliniko/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\cliniko\credentials.env` (native Windows). If it exists with a non-empty `CLINIKO_API_KEY`, run the Phase 0 smoke ping; on success, skip to Phase 2. Otherwise run Phase 1.

**Full account access.** A Cliniko API key inherits the **same permissions as the user who created it**. If that user is an Administrator, the key can read and write everything in the account - treat it like a password. There is no separate read-only key type; scope is controlled entirely by the user's security role.

---

## Communication rules for Phase 1

The user is a non-technical clinic owner. Phase 1 is autonomous - Claude does the work. Every message during Phase 1 follows these rules:

- **You drive, not them.** The only actions you request are "please sign in to Cliniko in the browser window I just opened (you'll get a code by email)" and, once, "please type your Cliniko password into the Security check box."
- **Plain English only.** No jargon - no API, key, REST, curl, header, shard, DOM, Playwright, env, JSON, endpoint. Name things plainly: "the connection", "your Cliniko account", "your browser".
- **Tell them what is about to happen** before each action; **react warmly** to success/failure; **never show raw errors**.
- **Short responses** - max 8 lines per message during Phase 1.
- **Never echo the API key** in a narration line, a tool return, or a log.
- **No restart needed** - this connector works the instant the key is saved; do NOT ask the user to restart Claude Code.

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
CRED="$HOME/.config/cliniko/credentials.env"
if [ -f "$CRED" ] && grep -q '^CLINIKO_API_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → run the smoke ping. On HTTP 200, tell the user "You're already connected - let me check it still works," then go to **Phase 2**. On 401/403, re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (key read from file, never printed):

```bash
set -a; . "$HOME/.config/cliniko/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -u "$CLINIKO_API_KEY:" \
  -H "User-Agent: $CLINIKO_USER_AGENT" -H "Accept: application/json" \
  "$CLINIKO_API_BASE/practitioners"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step is a *goal*; achieve it via `browser_snapshot`/`browser_evaluate` → reason → click/type. Match elements by visible labels - Cliniko's app is AngularJS and re-renders, so re-query after each change rather than caching refs.

> **Never snapshot the sign-in page** - the accessibility tree can include an auto-filled password value. Detect post-login with `browser_wait_for({ text: "Dashboard" })`.

### Step 1 - Sign in (user step) and capture the account URL + shard

Cliniko logins are **per-account** at `{subdomain}.{shard}.cliniko.com`; there is no central sign-in to navigate to. Ask the user for their Cliniko web address (e.g. `myclinic.cliniko.com`), then:

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://<their-address>/" })
```

Tell the user: *"Please sign in in the browser window - you'll get a verification code by email; enter that too."* Then poll:

```
mcp__plugin_playwright_playwright__browser_wait_for({ text: "Dashboard", time: 30 })
```

Once in, read the current URL - it is `https://<sub>.<shard>.cliniko.com/...`. The shard (`au5`, `uk2`, …) is confirmed again from the key suffix in Step 5; either source works.

### Step 2 - Check the API-key permission

Navigate to My Info and inspect the permission toggle:

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://<sub>.<shard>.cliniko.com/user/edit" })
```

```js
() => {
  const lab = [...document.querySelectorAll('label')].find(l=>/allow yourself to create and use api keys/i.test(l.textContent||''));
  const cb = lab && lab.querySelector('input[type=checkbox]');
  const enabled = [...document.querySelectorAll('h2,h3')].some(h=>/you have \d+ api keys?/i.test(h.textContent||''));
  return { permissionToggleChecked: cb?cb.checked:null, apiKeysAlreadyEnabled: enabled };
}
```

- `apiKeysAlreadyEnabled: true` → permission already on (one-time step done previously) → skip to Step 4.
- otherwise → continue to Step 3.

### Step 3 - Enable API keys (Playwright + ONE user step)

Cliniko hides the real checkbox under a styled slider; **click the `.slider`, not the hidden input** (the input intercepts as non-clickable):

```
mcp__plugin_playwright_playwright__browser_click({
  element: "API-keys permission slider",
  target: 'label:has-text("Allow yourself to create and use API keys") .slider'
})
```

Then save:

```
mcp__plugin_playwright_playwright__browser_click({ element: "Update user", target: 'button:has-text("Update user")' })
```

**Cliniko now shows a password "Security check" modal** ("enter your Cliniko password so we know it's really you"). This is the one step Claude must NOT automate - entering the user's password through automation is the boundary this skill does not cross (same principle as never snapshotting a password field). Hand off:

> *"Cliniko needs to confirm it's really you - please type your Cliniko password into the Security check box and click Update user. Tell me when it's done."*

Wait for the user. After they confirm, **reload `/user/edit`** and re-run the Step 2 check - `apiKeysAlreadyEnabled` should now be `true`. This permission **persists**, so future runs skip Steps 2-3 entirely.

### Step 4 - Mint the key

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://<sub>.<shard>.cliniko.com/user/api-keys/new" })
```

Fill the name field and create:

```
mcp__plugin_playwright_playwright__browser_type({ element: "API key name", target: "#tokenName", text: "Claude Code" })
mcp__plugin_playwright_playwright__browser_click({ element: "Create API key", target: 'button:has-text("Create API key")' })
```

### Step 5 - Capture the one-time key (DOM-extract, never screenshot)

Cliniko shows the key once ("Copy your new API key now. It won't be shown again."). Cliniko keys start with `MS0` and end with the shard (e.g. `-au5`). **Do NOT screenshot or snapshot the reveal** - read it via `browser_evaluate` into the clipboard, returning only metadata:

```js
async () => {
  let key = null;
  for (const el of document.querySelectorAll('*')) {
    if (el.children.length) continue;
    const t = (el.value || el.textContent || '').replace(/\s+/g,'');
    const m = t.match(/MS0[A-Za-z0-9+/=_-]{20,}-[a-z]{2,4}\d/);
    if (m) { key = m[0]; break; }
  }
  if (!key) return { ok:false };
  const shard = (key.match(/-([a-z]{2,4}\d)$/)||[])[1] || null;
  try { await navigator.clipboard.writeText(key); return { ok:true, len:key.length, shard }; }
  catch(e){ return { ok:false, reason:'clipboard', len:key.length, shard }; }
}
```

If `ok:false`, re-snapshot and retry once. Conversational fallback: ask the user to paste the key (accepted transcript-leak trade-off, same as other connectors).

### Step 6 - Store the key (silent), scrub artifacts

```bash
install -d -m 700 "$HOME/.config/cliniko"
KEY="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
SHARD="$(printf '%s' "$KEY" | sed -nE 's/.*-([a-z]{2,4}[0-9])$/\1/p')"   # parse shard from key suffix
[ -z "$SHARD" ] && SHARD="au1"   # keys minted long ago with no suffix default to au1
umask 077
cat > "$HOME/.config/cliniko/credentials.env" <<EOF
# Cliniko REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: HTTP Basic - API key as username, blank password:  curl -u "\$CLINIKO_API_KEY:" ...
# User-Agent header is REQUIRED by Cliniko (include a contact email).
CLINIKO_API_KEY=${KEY}
CLINIKO_SHARD=${SHARD}
CLINIKO_API_BASE=https://api.${SHARD}.cliniko.com/v1
CLINIKO_USER_AGENT="YourApp (you@example.com)"
EOF
chmod 600 "$HOME/.config/cliniko/credentials.env"
# clear clipboard + remove the transient Playwright snapshot dir WHOLESALE
( printf '' | wl-copy 2>/dev/null ) || ( printf '' | xclip -selection clipboard -i 2>/dev/null ) || true
rm -rf .playwright-mcp 2>/dev/null   # snapshots can capture the key; never grep+rm on the key substring (it also matches docs/this file)
unset KEY SHARD
```

> Set `CLINIKO_USER_AGENT` to something identifying with a real contact email - Cliniko uses it to reach you about your integration and **rejects requests without it**.

### Step 7 - Smoke test and report

```bash
set -a; . "$HOME/.config/cliniko/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -u "$CLINIKO_API_KEY:" \
  -H "User-Agent: $CLINIKO_USER_AGENT" -H "Accept: application/json" \
  "$CLINIKO_API_BASE/practitioners"
```

Expect `200`. Tell the user: *"All connected - your Cliniko is ready. Ask me things like 'who are my practitioners?' or 'show this week's appointments'."* **No restart needed.**

---

## PHASE 2 - Use the connector (REST runtime loop)

Once `~/.config/cliniko/credentials.env` exists, follow this loop on every Cliniko request.

1. Load credentials (never printed):

   ```bash
   set -a; . "$HOME/.config/cliniko/credentials.env"; set +a
   CK() { curl -s -u "$CLINIKO_API_KEY:" -H "User-Agent: $CLINIKO_USER_AGENT" -H "Accept: application/json" "$@"; }
   ```

2. Read a resource (responses are wrapped, e.g. `{"patients":[...],"total_entries":N,"links":{...}}`):

   ```bash
   CK "$CLINIKO_API_BASE/practitioners" | jq '.practitioners[] | {id, label, active}'
   ```

3. Filter server-side with `q[]` params, paginate via `per_page` (max 100) and `links.next`:

   ```bash
   CK "$CLINIKO_API_BASE/patients?per_page=100&q%5B%5D=updated_at:%3E2026-01-01T00:00:00Z" | jq '.total_entries'
   ```

4. Write (`POST` to create, `PUT` to `/<resource>/<id>` to update, `DELETE` to remove) - always **confirm patient-affecting writes with the user first**:

   ```bash
   CK -X POST -H "Content-Type: application/json" \
     -d '{"first_name":"Test","last_name":"Patient"}' \
     "$CLINIKO_API_BASE/patients"
   ```

**Core resources** (full catalogue + filter syntax in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Practitioners | `practitioners` | clinicians (live-verified) |
| Patients | `patients` | clients/patients |
| Appointments | `individual_appointments`, `group_appointments` | booked appointments |
| Bookings / availability | `bookings`, `availability_blocks` | schedule |
| Businesses | `businesses` | clinic locations |
| Appointment types | `appointment_types` | services |
| Invoices | `invoices` | billing |
| Products | `products` | sellable items |
| Contacts | `contacts` | non-patient contacts |

> **Privacy.** Cliniko holds health records (PHI). Only fetch what the user's request needs, never dump full patient datasets into the transcript, and confirm before any write that changes patient data or appointments.

---

## Gotchas

- **User-Agent is required.** Cliniko rejects requests with no `User-Agent`. Always send it.
- **Shard is in the key.** The base URL host comes from the key's suffix (`…-au5` → `api.au5.cliniko.com`). Keys minted long ago without a suffix default to `au1`.
- **Key inherits the user's permissions.** An Administrator's key can do anything in the account - treat it like a password; store mode 600, never in git.
- **API keys require a one-time enablement** (`/user/edit` toggle) that triggers a **password Security check** - a user step, like a 2FA challenge. It persists; Phase 0 / Step 2 detects "API keys already enabled" and skips it.
- **Key shown once.** Capture-then-store in the same step. If lost, delete the `Claude Code` key and re-mint.
- **Never snapshot the sign-in page** (password leak); detect login via `browser_wait_for`.
- **No substring-negation in self-checks.** Verify success by the explicit condition (`http_code == 200`), never "output does NOT contain an error word" - negation checks silently pass when the output shape changes.
- **AngularJS re-renders.** The `/user/edit` toggle is a styled slider over a hidden checkbox - click the `.slider`. Re-query elements after each change instead of reusing refs.
- **401** → key invalid/removed or trial lapsed → re-run Phase 1. **403** → the user's security role lacks permission for that resource. **429** → rate limited; back off and retry.

## Token handling

The API key is a bearer-equivalent secret stored in `~/.config/cliniko/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, tool return, or log. Add `**/credentials.env` to any nearby repo `.gitignore`; the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1 transcript (key redacted).
- `references/rest-api.md` - endpoint catalogue, `q[]` filter syntax, pagination.
- `skills/CLAUDE.md` - direct-REST connector family (`myob`, `ghl`) and the Playwright contingency.
