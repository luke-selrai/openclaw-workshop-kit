---
name: servicem8-connector
description: "Connect and operate ServiceM8 (field-service / trades job management) via its direct REST API for users who already have a ServiceM8 account or trial. Drives the one-time API-key setup end-to-end inside a Playwright MCP browser - signs the user in to go.servicem8.com, opens Settings then API Keys, clicks Add API Key, names it 'Claude Code', selects Full Access by default, and DOM-extracts the freshly minted key (shown only once) without ever opening the user's own browser. Persists the key to ~/.config/servicem8/credentials.env (mode 600), then reads and writes ServiceM8 data with curl against https://api.servicem8.com/api_1.0 using the X-API-Key header. No vendor MCP server and no OAuth - this is a standalone direct-REST connector, so there is NO Claude Code restart step. Handles jobs (list, view, create, update status), clients (companies and contacts), job activities and bookings, job materials, staff, job notes, attachments, and queues. Use this skill when the user asks to 'connect my ServiceM8', 'set up ServiceM8', or asks anything about their ServiceM8 jobs, clients, quotes, invoices, dispatch board, materials, or staff, or says 'create a job in ServiceM8'. Do NOT use to recommend ServiceM8 to users who do not already use it. On the first use of any ServiceM8 feature, run Phase 1 to mint and store the API key before attempting any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - servicem8
    - field-service
    - trades
    - jobs
    - dispatch
    - invoicing
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting ServiceM8 auth (401) or permission (403) errors
    - skill: qbo
      reason: Trades businesses sync ServiceM8 jobs to QuickBooks for invoicing
    - skill: xero-connector
      reason: Alternative accounting target for ServiceM8 invoice/job sync
---

# ServiceM8 Connector

## Overview

This skill lets Claude read and update a user's ServiceM8 data on their behalf. ServiceM8 is the field-service / trades job-management app (plumbers, electricians, HVAC, cleaners - "tradies"). It publishes **no MCP server**, so this is a **standalone direct-REST connector**: the same shape as `myob-connector` and `ghl-connector` in the direct-REST family noted in `skills/CLAUDE.md`.

The architecture is dead simple. Claude reads one static API key out of `~/.config/servicem8/credentials.env`, then runs `curl` against ServiceM8's REST endpoints - every call carries the header `X-API-Key: <key>`. The key is minted once inside the ServiceM8 web UI (Settings → API Keys), which Claude drives with Playwright. There is no OAuth, no token refresh, no client id/secret, and **no Claude Code restart** - because there is no MCP server to reconcile.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** The user has never done this before. Claude drives the entire key-mint flow inside a Playwright MCP browser: open `go.servicem8.com`, let the user sign in, walk Settings → API Keys → Add API Key, name it `Claude Code`, select **Full Access** (default), and capture the one-time key from the page. Claude writes it to `~/.config/servicem8/credentials.env` (mode 600) and verifies with a live API ping. The user's only manual moment is signing in to ServiceM8 once.
- **Phase 2 - Use the connector.** Once the key is saved, Claude calls the ServiceM8 REST API via `curl` (the runtime loop in §Phase 2) to read and update data: jobs, clients, job activities, materials, staff, notes, attachments, queues.

**Which phase to run** - Before any ServiceM8 action, check whether the key already exists. Look for `~/.config/servicem8/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\servicem8\credentials.env` (native Windows). If the file exists and contains a non-empty `SERVICEM8_API_KEY`, run a single smoke ping (Phase 0); on success, skip to Phase 2. Otherwise run Phase 1.

**Full Access is the default.** Phase 1 selects the **Full Access** key type so Claude can both read and write (create jobs, add notes, update statuses). A **Read Only** key is the safer alternative for query-only use - if the user asks for read-only, select that radio instead; every write recipe in Phase 2 will then return `403` (documented in §Gotchas).

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work. The user only signs in to ServiceM8 once. Every message during Phase 1 follows these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, or paste values in the happy path. The only action you request is "please sign in to ServiceM8 in the browser window I just opened."
- **Plain English only.** No jargon. Never say API, key, REST, curl, header, DOM, Playwright, env, JSON, endpoint, or file path. Name technical things plainly: "the connection", "your ServiceM8 account", "your browser".
- **Tell them what is about to happen.** "I'm going to connect ServiceM8 for you - this takes about a minute."
- **React warmly to success and failure.** Good: "That worked - your ServiceM8 is now connected." Never show a raw error message; translate to plain English and try the documented recovery.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo the API key** in a narration line, a tool return, or a log. It is stored locally and referenced by name only.
- **No restart needed.** Unlike the MCP-based connectors, this one works the instant the key is saved - do NOT ask the user to restart Claude Code.

---

## Cross-cutting: Playwright MCP install contingency

Phase 1 drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag is mandatory - the persistent profile keeps the ServiceM8 login alive across sessions.

---

## PHASE 0 - Resume check

Run before any Phase 1 work.

```bash
CRED_FILE="$HOME/.config/servicem8/credentials.env"
if [ -f "$CRED_FILE" ] && grep -q '^SERVICEM8_API_KEY=.\+' "$CRED_FILE"; then echo "configured"; else echo "not-configured"; fi
```

- `configured` → run the smoke ping below. On HTTP 200, tell the user warmly "You're already connected - let me check it still works," then go to **Phase 2**. On HTTP 401/403, the key was removed or downgraded - re-run **Phase 1**.
- `not-configured` → run **Phase 1**.

Smoke ping (key read from file, never printed):

```bash
set -a; . "$HOME/.config/servicem8/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "X-API-Key: $SERVICEM8_API_KEY" \
  "$SERVICEM8_API_BASE/company.json"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step describes a *goal*. Achieve it via `browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_type`. Match elements by their visible labels, not brittle selector paths - ServiceM8's UI evolves.

> **Never snapshot the sign-in page.** If you `browser_snapshot` ServiceM8's login page, the accessibility tree can include the literal password value when a password manager has auto-filled the field. Detect post-login with `browser_wait_for({ text: "Dispatch Board" })` instead (memory `reference_playwright_snapshot_password_leak`).

### Step 1 - Open ServiceM8 and confirm a logged-in session

Tell the user: *"Opening a browser window - please sign in to ServiceM8 when it appears. I'll do the rest."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://go.servicem8.com/" })
```

Do NOT snapshot. Poll for the signed-in dashboard:

```
mcp__plugin_playwright_playwright__browser_wait_for({ text: "Dispatch Board", time: 20 })
```

If it times out, check in once: *"Still on the sign-in page? Let me know when you're in."* and re-poll. ServiceM8 offers email+password and Apple / Google / Xero / Intuit sign-in - any is fine.

### Step 2 - Navigate to Settings → API Keys

The Settings tile links to a sub-menu; the API Keys page lives at `PluginApiKeyManagement_Dashboard`. From the dashboard, click the **Settings** tile, then the **API Keys** tile. Confirm arrival with `browser_wait_for({ text: "API Keys" })`, then snapshot.

### Step 3 - Reuse or recreate the "Claude Code" key

Snapshot the key table.

- **A row named `Claude Code` already exists AND `~/.config/servicem8/credentials.env` holds a key** → already set up; skip to Step 7 (smoke).
- **A row named `Claude Code` exists but no stored key** → the value is unrecoverable (ServiceM8 shows each key only once). Click its **Remove** button, then create a fresh one (continue to Step 4).
- **No `Claude Code` row** → continue to Step 4.

### Step 4 - Create the key (Full Access by default)

Click **Add API Key**. A modal appears with an **API Key Name** field and two radios: **Read Only** / **Full Access**.

1. Type `Claude Code` into the name field (`browser_type`).
2. Select **Full Access** (default). Only select **Read Only** if the user explicitly asked for query-only access.
3. Click **Create**.

### Step 5 - Capture the one-time key (DOM-extract, never screenshot)

ServiceM8 now shows the key once with *"store it securely as it will not be shown again."* The value matches `smk-[A-Za-z0-9-]+`. **Do NOT screenshot or snapshot the reveal modal** - that leaves the secret in an artifact on disk. Read it via `browser_evaluate` straight into the clipboard, returning only length metadata:

```js
async () => {
  const m = (document.body.innerText || '').match(/smk-[A-Za-z0-9-]{10,}/);
  if (!m) return { ok: false };
  try { await navigator.clipboard.writeText(m[0]); return { ok: true, len: m[0].length }; }
  catch (e) { return { ok: false, reason: 'clipboard_write_failed' }; }
}
```

If `ok: false`, re-snapshot and retry once. Conversational fallback: *"I'm having trouble reading the key automatically - could you paste it for me?"* (the key transits the transcript in this path; accepted trade-off, same as the GitHub-connector fallback).

### Step 6 - Store the key (silent), scrub artifacts

Read the key from the clipboard and write the credentials file. Never echo the value.

```bash
install -d -m 700 "$HOME/.config/servicem8"
# Cross-platform clipboard read: wl-paste (Wayland) / xclip (X11) / pbpaste (macOS) / powershell Get-Clipboard (Windows)
KEY="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
umask 077
cat > "$HOME/.config/servicem8/credentials.env" <<EOF
# ServiceM8 REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: send header  X-API-Key: \$SERVICEM8_API_KEY
SERVICEM8_API_KEY=${KEY}
SERVICEM8_API_BASE=https://api.servicem8.com/api_1.0
EOF
chmod 600 "$HOME/.config/servicem8/credentials.env"
unset KEY
# Scrub the transient Playwright snapshot dir, which can capture the key from auto-snapshots
# (Playwright MCP snapshots each action - including the one right after the key reveal).
# Remove it WHOLESALE. NEVER `grep -rlF "smk-" | xargs rm`: that substring also appears in this
# skill's own docs AND in credentials.env, so a broad match would delete the skill or the key file.
rm -rf .playwright-mcp 2>/dev/null   # snapshots are written relative to the session working dir
```

> **Cross-platform note.** Native Windows stores at `%APPDATA%\servicem8\credentials.env`; everywhere else `~/.config/servicem8/credentials.env`. Never hardcode a machine path.

### Step 7 - Smoke test and report

```bash
set -a; . "$HOME/.config/servicem8/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "X-API-Key: $SERVICEM8_API_KEY" \
  "$SERVICEM8_API_BASE/company.json"
```

Expect `200`. Tell the user: *"All connected - your ServiceM8 is ready. You can ask me things like 'show my jobs this week' or 'create a job for a client'."* **No restart needed.**

---

## PHASE 2 - Use the connector (REST runtime loop)

Once `~/.config/servicem8/credentials.env` exists, follow this loop on every ServiceM8 request.

1. Load the key (never print it):

   ```bash
   set -a; . "$HOME/.config/servicem8/credentials.env"; set +a
   ```

2. Read with a `GET` to `$SERVICEM8_API_BASE/<resource>.json`, pipe through `jq`:

   ```bash
   curl -s -H "X-API-Key: $SERVICEM8_API_KEY" "$SERVICEM8_API_BASE/job.json" \
     | jq '.[] | {uuid, generated_job_id, status, job_address}'
   ```

3. Filter server-side with the `$filter` query param (ServiceM8 uses OData-style `eq`, `gt`, `lt`):

   ```bash
   curl -s -H "X-API-Key: $SERVICEM8_API_KEY" \
     "$SERVICEM8_API_BASE/job.json?%24filter=status%20eq%20'Work%20Order'"
   ```

4. Write (Full Access only) with `POST` (create) or `PUT` to `/<resource>/<uuid>.json` (update). Always **confirm destructive or client-visible writes with the user first**:

   ```bash
   curl -s -X POST -H "X-API-Key: $SERVICEM8_API_KEY" -H "Content-Type: application/json" \
     -d '{"status":"Quote","job_address":"12 Smith St","company_uuid":"<client-uuid>"}' \
     "$SERVICEM8_API_BASE/job.json"
   ```

**Core resources** (full catalogue + field reference in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Clients (companies) | `company.json` | businesses/customers |
| Client contacts | `companycontact.json` | people at a client |
| Jobs | `job.json` | the central object; `status` ∈ Quote / Work Order / Invoice / Completed |
| Job activities | `jobactivity.json` | scheduled bookings / time |
| Materials | `jobmaterial.json` | line items on a job |
| Staff | `staff.json` | technicians |
| Job notes | `note.json` | notes attached to a job |
| Attachments | `attachment.json` | photos/files |
| Queues | `queue.json` | dispatch board columns |

---

## Gotchas

- **Key shown once.** ServiceM8 reveals a new key a single time. Capture-then-store in the same step; never rely on re-reading it. If lost, Remove + recreate.
- **Never snapshot the sign-in page** - auto-filled password leak (see Phase 1 note).
- **No substring-negation in self-checks.** When testing whether the key works, match the explicit success condition (`http_code == 200`), never "does the output NOT contain an error word" - negation-based success checks silently pass when the output shape changes, a known false-pass audit footgun.
- **401 Unauthorized** → key invalid, removed, or the trial/account lapsed → re-run Phase 1 (Remove any stale `Claude Code` row first).
- **403 Forbidden on a write** → the key is **Read Only**. Mint a Full Access key (Phase 1 Step 4) to enable writes.
- **Bounced owner email blocks sends.** ServiceM8 will not send email/SMS (quotes, "on my way" texts) until the account-owner email is verified. This does NOT affect the REST API, but any send-driven automation will silently no-op. If the user reports messages not arriving, point them to Settings → ServiceM8 Account to fix and re-verify the owner email.
- **Rotation.** The key is long-lived and Full Access. To rotate: Settings → API Keys → Remove the `Claude Code` key → re-run Phase 1. Treat the key as a password; it lives only in `~/.config/servicem8/credentials.env` (mode 600), never in git.
- **Trial expiry.** A 14-day trial still serves the REST API while active; once expired, calls return auth errors until the user picks a plan.

## Token handling

The API key is a bearer-equivalent secret. It is stored in `~/.config/servicem8/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, a tool return, or a log. Add `**/credentials.env` to any repo `.gitignore` before committing work near this skill - though the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1 transcript (key redacted).
- `references/rest-api.md` - endpoint catalogue, field notes, and `$filter` syntax.
- `skills/CLAUDE.md` - direct-REST connector family (`myob`, `ghl`) and the Playwright contingency.
