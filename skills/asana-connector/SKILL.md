---
name: asana-connector
description: "Connect and operate Asana (work management / projects & tasks) via its direct REST API for users who already have an Asana account or trial. Drives the one-time Personal Access Token setup inside a Playwright MCP browser — opens the Asana developer console (app.asana.com/0/my-apps), the user signs in (email or Google/Microsoft SSO), then Claude creates a token named 'Claude Code', accepts the API terms, and captures the one-time token via the dialog's Copy button — without ever opening the user's own browser. Persists it to ~/.config/asana/credentials.env (mode 600) and reads/writes Asana data with curl against https://app.asana.com/api/1.0 using the Authorization: Bearer header. No vendor MCP server and no OAuth — a standalone direct-REST connector, so there is NO Claude Code restart step. Handles tasks, projects, sections, subtasks, stories (comments), tags, users, teams, workspaces, custom fields, and attachments. Use this skill when the user asks to 'connect my Asana', 'set up Asana', or asks anything about their Asana tasks, projects, assignments, due dates, sections, or workload, or says 'create a task in Asana'. Do NOT use to recommend Asana to users who do not already use it. On the first use of any Asana feature, run Phase 1 to mint and store the token before attempting any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - asana
    - project-management
    - work-management
    - tasks
    - projects
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Asana auth (401) or permission (403) errors
    - skill: email-composer
      reason: Draft status updates or task comments for Asana stakeholders
    - skill: monday-connector
      reason: Sibling work-management connector — same direct-token + curl-runtime shape
---

# Asana Connector

## Overview

This skill lets Claude read and update a user's Asana data on their behalf. Asana is the work-management app (projects, tasks, assignments) popular with SMB and team workflows. It publishes **no first-party MCP server for personal use**, so this is a **standalone direct-REST connector** — the same shape as `pipedrive-connector`, `servicem8-connector`, and `cliniko-connector` in the direct-REST family noted in `skills/CLAUDE.md`. (Its sibling `monday-connector` is the same *category* — work management — but uses the MCP-based Hosted-bearer-PAT pattern, not direct REST.)

The architecture is dead simple. Claude reads one static Personal Access Token (PAT) out of `~/.config/asana/credentials.env`, then runs `curl` against Asana's REST endpoints. Three Asana specifics matter:

- **Auth is `Authorization: Bearer <PAT>`.** Every call carries the Bearer header. There is no query-param token form.
- **The PAT has a THREE-segment format:** `<version>/<user_gid>/<token_gid>:<hex>` — e.g. `2/1215919238271902/1215924623120615:52144db…`. A naive two-segment regex captures a truncated slice and yields a silent 401. **Capture it via the dialog's "Copy" button**, not a DOM regex (and if you must regex, the pattern is `\d+/\d+/\d+:[0-9a-f]+`). The token is shown **once** at creation.
- **Responses are minimal by default.** Asana returns only `{gid, name, resource_type}` per object unless you pass **`opt_fields`**. Always request the fields you need (e.g. `?opt_fields=name,due_on,assignee.name,completed`). This is the #1 "why is my data empty?" gotcha.

The skill has two phases:

- **Phase 1 — Install & Connect (autonomous via Playwright, with one user step).** Claude drives the whole token-mint inside a Playwright MCP browser: open the developer console, let the user sign in, create a `Claude Code` token, accept the API terms, capture it via the Copy button, write `~/.config/asana/credentials.env` (mode 600), and verify with a live ping. The user's only manual moment is signing in to Asana once.
- **Phase 2 — Use the connector.** Once the token is saved, Claude calls the Asana REST API via `curl` to read and update data: tasks, projects, sections, subtasks, stories, tags, users, teams, custom fields, attachments.

**Which phase to run** — Before any Asana action, check for `~/.config/asana/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\asana\credentials.env` (native Windows). If it exists with a non-empty `ASANA_PAT`, run the Phase 0 smoke ping; on success, skip to Phase 2. Otherwise run Phase 1.

**Full account access.** An Asana PAT inherits the **same permissions and visibility as the user who created it**. It can read and write everything that user can see across their workspaces — treat it like a password. There is no read-only PAT type; scope is the user's own permission set.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work. The user only signs in to Asana once. Every message during Phase 1 follows these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, or paste values in the happy path. The only action you request is "please sign in to Asana in the browser window I just opened."
- **Plain English only.** No jargon. Never say API, token, PAT, REST, curl, header, DOM, Playwright, env, JSON, endpoint, or file path. Name technical things plainly: "the connection", "your Asana account", "your browser".
- **Tell them what is about to happen.** "I'm going to connect Asana for you — this takes about a minute."
- **React warmly to success and failure.** Good: "That worked — your Asana is now connected." Never show a raw error message; translate to plain English and try the documented recovery.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never echo the token** in a narration line, a tool return, or a log. It is stored locally and referenced by name only.
- **No restart needed.** Unlike the MCP-based connectors, this one works the instant the token is saved — do NOT ask the user to restart Claude Code.

---

## Cross-cutting: Playwright MCP install contingency

Phase 1 drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag is mandatory — the persistent profile keeps the Asana login alive across sessions.

---

## PHASE 0 — Resume check

Run before any Phase 1 work.

```bash
CRED_FILE="$HOME/.config/asana/credentials.env"
if [ -f "$CRED_FILE" ] && grep -q '^ASANA_PAT=.\+' "$CRED_FILE"; then echo "configured"; else echo "not-configured"; fi
```

- `configured` → run the smoke ping below. On HTTP 200, tell the user warmly "You're already connected — let me check it still works," then go to **Phase 2**. On HTTP 401, the token was revoked or deleted — re-run **Phase 1**.
- `not-configured` → run **Phase 1**.

Smoke ping (token read from file, never printed):

```bash
set -a; . "$HOME/.config/asana/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $ASANA_PAT" \
  "https://app.asana.com/api/1.0/users/me"
```

---

## PHASE 1 — Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step describes a *goal*. Achieve it via `browser_snapshot` → reason → `browser_click` / `browser_type` / `browser_evaluate`. Match elements by visible labels, not brittle selector paths — Asana's UI evolves.

> **Never snapshot the sign-in page.** If you `browser_snapshot` Asana's login page, the accessibility tree can include the literal password value when a password manager has auto-filled the field. Detect post-login by polling `location.href` with `browser_evaluate` instead (memory `reference_playwright_snapshot_password_leak`).

### Step 1 — Open the developer console and confirm a logged-in session

Tell the user: *"Opening a browser window — please sign in to Asana when it appears. I'll do the rest."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.asana.com/0/my-apps" })
```

When signed out this redirects to `app.asana.com/-/login`. Asana supports Google / Microsoft SSO and email. **A cookie-consent banner can intercept the sign-in buttons** — if present, dismiss it first (click "Allow All" / `#onetrust-accept-btn-handler`). Do NOT snapshot. Poll for the signed-in state:

```
mcp__plugin_playwright_playwright__browser_evaluate({ function: "() => ({ url: location.href })" })
```

Re-poll every ~15s until the URL is back on `app.asana.com/0/my-apps` (no longer `/-/login`). SSO bounces through `accounts.google.com` / `login.microsoftonline.com` — that is normal; keep polling. After login, re-navigate to `https://app.asana.com/0/my-apps` to ensure you are on the developer console.

### Step 2 — Reuse or create the "Claude Code" token

Snapshot the console. Under the **Personal access tokens** heading:

- **A `Claude Code` row already exists AND `~/.config/asana/credentials.env` holds a token** → already set up; skip to Step 5 (smoke).
- **A `Claude Code` row exists but no stored token** → the value is unrecoverable (Asana shows each token once). Open it, **Delete** it, then create a fresh one.
- **No `Claude Code` row** → click **Create new token**.

In the **Create new token** dialog: type `Claude Code` into the **Token name** field, tick **I agree to the Asana API Terms**, then click **Create token** (it is disabled until both are done).

### Step 3 — Capture the one-time token via the Copy button (never screenshot)

A **Token details** dialog appears with the token in a readonly field, a **Copy** button, and the warning *"Make sure to copy this access token now. You won't see it again."*

**Click the dialog's "Copy" button** — it puts the full, correct token on the clipboard. This is more reliable than DOM-reading because the Asana PAT is three-segment (`2/userGid/tokenGid:hex`) and easy to truncate with a naive regex. **Do NOT screenshot or snapshot the reveal dialog** — that leaves the secret in an artifact on disk.

```
mcp__plugin_playwright_playwright__browser_click({ element: "Copy token button", target: "<ref of Copy button>" })
```

If no Copy button is found, DOM-extract with the correct three-segment pattern and clipboard-transit, returning only metadata:

```js
async () => {
  const m = (document.body.innerText || '').match(/\d+\/\d+\/\d+:[0-9a-f]{20,}/i);
  if (!m) return { ok: false };
  try { await navigator.clipboard.writeText(m[0]); return { ok: true, len: m[0].length }; }
  catch (e) { return { ok: false, reason: 'clipboard_write_failed' }; }
}
```

### Step 4 — Store the token (silent), verify, scrub artifacts

Read the token from the clipboard, **verify before persisting** (a truncated/stale clipboard value must not be written), then write the credentials file. Never echo the value.

```bash
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
# shape check: three-segment PAT
printf '%s' "$TOKEN" | grep -qE '^[0-9]+/[0-9]+/[0-9]+:[0-9a-f]+$' || { echo "clipboard is not an Asana PAT"; exit 1; }
# verify against the live API BEFORE writing
RESP=$(curl -s -H "Authorization: Bearer $TOKEN" "https://app.asana.com/api/1.0/users/me")
echo "$RESP" | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("data",{}).get("gid") else 1)' || { echo "token failed verification"; exit 1; }
install -d -m 700 "$HOME/.config/asana"; umask 177
cat > "$HOME/.config/asana/credentials.env" <<EOF
# Asana REST API credentials — DO NOT COMMIT, DO NOT SHARE
# Auth: header  Authorization: Bearer \$ASANA_PAT
# Base URL: https://app.asana.com/api/1.0
ASANA_PAT=${TOKEN}
EOF
chmod 600 "$HOME/.config/asana/credentials.env"
unset TOKEN
# Scrub transient Playwright snapshots (auto-captured each action; the reveal dialog can land in one).
# Remove WHOLESALE — never grep-by-token-substring (could match unrelated files).
rm -rf .playwright-mcp 2>/dev/null
```

> **Cross-platform note.** Native Windows stores at `%APPDATA%\asana\credentials.env`; everywhere else `~/.config/asana/credentials.env`. Never hardcode a machine path.

### Step 5 — Report

The verify in Step 4 already confirmed the token. Tell the user: *"All connected — your Asana is ready. You can ask me things like 'show my tasks due this week' or 'add a task to [project]'."* **No restart needed.**

---

## PHASE 2 — Use the connector (REST runtime loop)

Once `~/.config/asana/credentials.env` exists, follow this loop on every Asana request.

1. Load the token (never print it) and define a helper:

   ```bash
   set -a; . "$HOME/.config/asana/credentials.env"; set +a
   A() { curl -s -H "Authorization: Bearer $ASANA_PAT" -H "Accept: application/json" \
           "https://app.asana.com/api/1.0$1"; }
   ```

2. **Always pass `opt_fields`** — default responses are just `{gid, name, resource_type}`:

   ```bash
   # the user's workspace gid (needed for most listings)
   A "/workspaces?opt_fields=name" | jq '.data[] | {gid, name}'
   ```

3. List tasks. Asana cannot list *all* tasks globally — scope by `project`, by `section`, or by `workspace`+`assignee`:

   ```bash
   # my incomplete tasks in a workspace
   A "/tasks?workspace=<ws_gid>&assignee=me&completed_since=now&opt_fields=name,due_on,completed,projects.name&limit=50" \
     | jq '.data[] | {gid, name, due_on}'
   # tasks in a project
   A "/projects/<project_gid>/tasks?opt_fields=name,assignee.name,due_on,completed&limit=50" | jq '.data[]'
   ```

4. Paginate (offset-based opaque cursor). Loop while `next_page` is non-null, passing `next_page.offset` back as `offset=` (`limit` max 100):

   ```bash
   off=""; while :; do
     resp=$(A "/projects/<project_gid>/tasks?opt_fields=name,completed&limit=100${off:+&offset=$off}")
     echo "$resp" | jq -c '.data[]'
     off=$(echo "$resp" | jq -r '.next_page.offset // empty')
     [ -z "$off" ] && break
   done
   ```

5. Write with `POST` (create) / `PUT` (update) / `DELETE`. **Asana wraps the request body in `{"data": {...}}`** and confirm any client-visible write with the user first:

   ```bash
   # create a task in a project
   curl -s -X POST -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
     -d '{"data":{"name":"Draft proposal","notes":"Due Friday","projects":["<project_gid>"],"assignee":"me"}}' \
     "https://app.asana.com/api/1.0/tasks" | jq '.data.gid'
   # complete a task
   curl -s -X PUT -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
     -d '{"data":{"completed":true}}' \
     "https://app.asana.com/api/1.0/tasks/<task_gid>" | jq '.data | {gid, completed}'
   # add a comment (story)
   curl -s -X POST -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
     -d '{"data":{"text":"Following up — any blockers?"}}' \
     "https://app.asana.com/api/1.0/tasks/<task_gid>/stories" | jq '.data.gid'
   ```

**Core resources** (full catalogue + field reference in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Workspaces | `/workspaces` | top-level container; gid needed for most listings |
| Users | `/users`, `/users/me` | `me` = token owner |
| Teams | `/organizations/<ws>/teams`, `/teams/<gid>` | org-tier grouping |
| Projects | `/projects?workspace=<ws>`, `/projects/<gid>` | task containers |
| Sections | `/projects/<gid>/sections` | columns within a project |
| Tasks | `/tasks`, `/projects/<gid>/tasks`, `/tasks/<gid>` | central object; needs a scope to list |
| Subtasks | `/tasks/<gid>/subtasks` | child tasks |
| Stories | `/tasks/<gid>/stories` | comments + activity log |
| Tags | `/tags?workspace=<ws>` | labels |
| Custom fields | `/workspaces/<ws>/custom_fields` | per-workspace field defs |
| Attachments | `/tasks/<gid>/attachments` | files on a task |

---

## Gotchas

- **Empty-looking responses → you forgot `opt_fields`.** Asana returns only `{gid, name, resource_type}` by default. Request fields explicitly; dotted paths expand relations (`assignee.name`, `projects.name`).
- **Three-segment PAT.** `2/userGid/tokenGid:hex`. A two-segment regex truncates it → silent 401. Use the Copy button, or the `\d+/\d+/\d+:[0-9a-f]+` pattern. (This bit the connector's own build — verified 2026-06-22.)
- **Token shown once.** Asana reveals a new PAT a single time. Capture-then-verify-then-store in one pass; if lost, Delete + recreate.
- **Body must be wrapped in `{"data": {...}}`** on writes. A bare `{"name": "..."}` returns 400. Reads also return under `data`.
- **Can't list all tasks globally.** `GET /tasks` requires a scope: `project`, `section`, `tag`, or `workspace`+`assignee`. Asking for everything returns a 400.
- **No substring-negation in self-checks.** Test the explicit success condition (`http_code == 200` / `.data.gid` present), never "output does NOT contain an error word" — negation checks silently pass when the shape changes.
- **401 Unauthorized** → token revoked/deleted or truncated on capture → re-run Phase 1 (Delete any stale `Claude Code` token first).
- **403 Forbidden** → the token owner lacks access to that object. User-permission limit (no read-only token type).
- **429 / rate limits.** Free tier ~1500 req/min, 50 concurrent; respect `Retry-After`. Prefer `limit=100` + offset paging over many small calls.
- **Never snapshot the sign-in page** — auto-filled password leak (see Phase 1 note).

## Token handling

The PAT is a bearer-equivalent secret. It is stored in `~/.config/asana/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, a tool return, or a log. Add `**/credentials.env` to any repo `.gitignore` before committing work near this skill — though the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` — a real, verified Phase 1 transcript (token redacted), including the three-segment-truncation gotcha.
- `references/rest-api.md` — endpoint catalogue, `opt_fields`, pagination, and the `{"data":...}` write envelope.
- `skills/CLAUDE.md` — the direct-REST connector family (`pipedrive`, `servicem8`, `cliniko`, `myob`, `ghl`) and the Playwright contingency.
