---
name: asana-connector
description: "Connect Asana to Claude by switching on its built-in connector, or by installing its API credentials for the parts the built-in doesn't reach. Use when the user asks to set up or connect Asana, or wants Asana work (tasks, projects, sections, comments, due dates, custom fields, portfolios) and Asana isn't connected yet. Once connected, Asana runs through the mcp__claude_ai_Asana__* tools, or against its API with the stored credentials."
allowed-tools: mcp__claude_ai_Asana__*,Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
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
      reason: Sibling work-management connector - same direct-token + curl-runtime shape
---

# Asana Connector

## Overview

This skill lets Claude read and update a user's Asana data on their behalf. Asana is the work-management app (projects, tasks, assignments) popular with SMB and team workflows. There are two routes onto it, and **the built-in connector is the default**:

- **Phase 1 - the built-in Asana connector (default).** Asana's own hosted server, listed in Claude's connector directory at `https://claude.com/connectors/asana` (slug verified live, 2 Sep 2026). The user presses one button on their Claude account and signs in. The connection is **account-level**: connect once and it is available everywhere that Claude account is signed in, including Claude Code. Tools arrive as `mcp__claude_ai_Asana__*` - 30-plus of them over Asana's Work Graph: searching, creating, updating and tracking tasks, projects and goals, with Asana's own inline cards in the answer. It handles no credentials at all. **It needs a paid Claude plan.**
- **Phase 1-alt - the kit's own route** (for the two things the built-in can't do - **setting custom fields at the moment a task is created** (dates especially) and **portfolios** - and whenever built-in connectors can't be used in this session, including on a free Claude plan). A **standalone direct-REST connector** - the same shape as `pipedrive-connector`, `servicem8-connector`, and `cliniko-connector` in the direct-REST family noted in `skills/CLAUDE.md`. (Its sibling `monday-connector` is the same *category* - work management - but uses the MCP-based Hosted-bearer-PAT pattern, not direct REST.)
- **Phase 2 - Use the connector.** Whichever route connected, read and update Asana through that route.

The kit's own route is dead simple. Claude reads one static Personal Access Token (PAT) out of `~/.config/asana/credentials.env`, then runs `curl` against Asana's REST endpoints. Three Asana specifics matter:

- **Auth is `Authorization: Bearer <PAT>`.** Every call carries the Bearer header. There is no query-param token form.
- **The PAT has a THREE-segment format:** `<version>/<user_gid>/<token_gid>:<hex>` - e.g. `2/1215919238271902/1215924623120615:52144db…`. A naive two-segment regex captures a truncated slice and yields a silent 401. **Capture it via the dialog's "Copy" button**, not a DOM regex (and if you must regex, the pattern is `\d+/\d+/\d+:[0-9a-f]+`). The token is shown **once** at creation.
- **Responses are minimal by default.** Asana returns only `{gid, name, resource_type}` per object unless you pass **`opt_fields`**. Always request the fields you need (e.g. `?opt_fields=name,due_on,assignee.name,completed`). This is the #1 "why is my data empty?" gotcha.

On the kit's own route, Phase 1-alt is autonomous via Playwright with one user step: Claude drives the whole token-mint inside a Playwright MCP browser - open the developer console, let the user sign in, create a `Claude Code` token, accept the API terms, capture it via the Copy button, write `~/.config/asana/credentials.env` (mode 600), and verify with a live ping. The user's only manual moment is signing in to Asana once. After that, Claude calls the Asana REST API via `curl` to read and update data: tasks, projects, sections, subtasks, stories, tags, users, teams, custom fields, attachments.

**Which phase to run** - always start at **Phase 0** below. It checks the built-in connector first, then the kit's own credentials file (`~/.config/asana/credentials.env` on Mac/Linux/WSL, `%APPDATA%\asana\credentials.env` on native Windows, with a non-empty `ASANA_PAT`) plus a smoke ping. A working connection on either route means skip straight to Phase 2 - never set one route up on top of the other.

**Existing accounts only.** This connector is for users who already have an Asana account or trial. Do not use it to recommend Asana to users who do not already use it.

**Full account access.** An Asana PAT inherits the **same permissions and visibility as the user who created it**. It can read and write everything that user can see across their workspaces - treat it like a password. There is no read-only PAT type; scope is the user's own permission set.

---

## Communication rules (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Both routes are autonomous - Claude does the work. The user only signs in to Asana once. Every message during either route follows these rules:

- **Which browser opens, and why.** On the built-in route you open the user's **own everyday browser** - that is where they are already signed in to Claude - and it reads nothing from that browser. On the kit's own route Claude uses a separate window it drives itself, because that route reads the connection key off the page. The two rules do not conflict; they belong to different routes.
- **Never ask for a password, a sign-in code, or a screenshot of a sign-in screen** on either route.
- **Restart, only on the built-in route.** If the built-in connector doesn't show up after connecting, ask the user to close and reopen Claude once. The kit's own route needs no restart (see below).
- **You drive, not them.** Never ask the user to click menus, copy text, or paste values in the happy path. The only action you request is "please sign in to Asana in the browser window I just opened."
- **Plain English only.** No jargon. Never say API, token, PAT, REST, curl, header, DOM, Playwright, env, JSON, endpoint, or file path. Name technical things plainly: "the connection", "your Asana account", "your browser".
- **Tell them what is about to happen.** "I'm going to connect Asana for you - this takes about a minute."
- **React warmly to success and failure.** Good: "That worked - your Asana is now connected." Never show a raw error message; translate to plain English and try the documented recovery.
- **Short responses.** Maximum 8 lines per message while connecting.
- **Never echo the token** in a narration line, a tool return, or a log. It is stored locally and referenced by name only.
- **No restart needed on the kit's own route.** Unlike the MCP-based connectors, it works the instant the token is saved - do NOT ask the user to restart Claude Code for it. (The built-in route is the exception above.)

---

## Cross-cutting: Playwright MCP install contingency

Phase 1-alt drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag is mandatory - the persistent profile keeps the Asana login alive across sessions.

---

## PHASE 0 - Is Asana already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Asana` (match the vendor word case-insensitively).
   - `✔ Connected` → skip to **Phase 2**. Prove it first with one read from the `mcp__claude_ai_Asana__*` namespace (list the user's tasks due this week) before saying so.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` in the user's own browser (`open` on Mac, `xdg-open` on Linux, `start "" <url>` on Windows) and say: *"Your Asana connection needs a quick re-sign-in. Press Reconnect next to Asana, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Check for the credentials file, then smoke-ping it:

   ```bash
   CRED_FILE="$HOME/.config/asana/credentials.env"
   if [ -f "$CRED_FILE" ] && grep -q '^ASANA_PAT=.\+' "$CRED_FILE"; then echo "configured"; else echo "not-configured"; fi
   ```

   Smoke ping (token read from file, never printed):

   ```bash
   set -a; . "$HOME/.config/asana/credentials.env"; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $ASANA_PAT" \
     "https://app.asana.com/api/1.0/users/me"
   ```

   - `configured` + HTTP 200 → keep using it. Tell the user warmly *"You're already connected - let me check it still works,"* then go to **Phase 2**. Do not set the built-in up on top of a working connection.
   - `configured` + HTTP 401 → the token was revoked or deleted. If the user's need is inside the built-in's coverage (see the routing table), prefer **Phase 1**; otherwise re-run **Phase 1-alt**.
   - `not-configured` → continue.
3. **Nothing found** → **Phase 1**.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Phase 1 Step 5 by calling one of Asana's tools.

---

## Route by need - built-in or the kit's route?

Before installing anything, ask one question in plain English: **what does the user want Claude to do with Asana?** Then route what they name:

| What the user wants | Route |
|---|---|
| See work - my tasks, a project's tasks, what's due, project status, goals | **Built-in** |
| Create and manage tasks and projects - new task, assign it, set a due date, complete it, comment on it | **Built-in** |
| Turn a conversation into a project - tasks, owners, milestones, a timeline | **Built-in** |
| **Setting custom fields as part of creating a task** - especially custom *date* fields | The kit's own route (Phase 1-alt) - the built-in cannot set them at creation |
| **Portfolios** | The kit's own route (Phase 1-alt) |
| The user is on a free Claude plan, the session can't see built-in connectors at all (Phase 1 Step 1 fails), or they explicitly ask for the local setup | The kit's own route (Phase 1-alt) |

Both routes can coexist on one machine. Never tear one down to set the other up, and never burden the user with the kit's extra setup when the built-in already covers what they asked for. Say in one line what you are *not* connecting and why, so they can ask for it later.

---

## PHASE 1 - Switch on the built-in Asana connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in. **It needs a paid Claude plan** - on a free plan, say so plainly in one line and run Phase 1-alt instead.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run **Phase 1-alt** instead.

**Step 2 - Open the connector page for them.** Say: *"I'm opening Asana's page in your browser. Press **Connect to Claude**, sign in to Asana the way you normally do, and say yes when it asks for access. That is the only part only you can do - tell me when it says Connected."* Then open `https://claude.ai/directory/asana` in their own browser (`open` / `xdg-open` / `start`). If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Asana" → Connect.

**Step 3 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.** `claude mcp list` again. `claude.ai Asana … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete - send them back to Step 2.

**Step 5 - Prove it.** Call one real read through the connector - list the user's tasks due this week from the `mcp__claude_ai_Asana__*` namespace. Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app, connectors added during a session are documented to appear without a restart; if one doesn't, start a new session there.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Asana on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-ALT - Install & Connect (autonomous via Playwright)

**Run this only when** the user's named need is in the kit's-route column above (custom fields set at task creation, portfolios), the user is on a free Claude plan, the session can't see built-in connectors (Step 1 failed), the listing is missing on the user's account, or the user explicitly wants the local setup. Otherwise stay on Phase 1.

> **Reasoning model.** Each step describes a *goal*. Achieve it via `browser_snapshot` → reason → `browser_click` / `browser_type` / `browser_evaluate`. Match elements by visible labels, not brittle selector paths - Asana's UI evolves.

> **Never snapshot the sign-in page.** If you `browser_snapshot` Asana's login page, the accessibility tree can include the literal password value when a password manager has auto-filled the field. Detect post-login by polling `location.href` with `browser_evaluate` instead (memory `reference_playwright_snapshot_password_leak`).

### Step 1 - Open the developer console and confirm a logged-in session

Tell the user: *"Opening a browser window - please sign in to Asana when it appears. I'll do the rest."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.asana.com/0/my-apps" })
```

When signed out this redirects to `app.asana.com/-/login`. Asana supports Google / Microsoft SSO and email. **A cookie-consent banner can intercept the sign-in buttons** - if present, dismiss it first (click "Allow All" / `#onetrust-accept-btn-handler`). Do NOT snapshot. Poll for the signed-in state:

```
mcp__plugin_playwright_playwright__browser_evaluate({ function: "() => ({ url: location.href })" })
```

Re-poll every ~15s until the URL is back on `app.asana.com/0/my-apps` (no longer `/-/login`). SSO bounces through `accounts.google.com` / `login.microsoftonline.com` - that is normal; keep polling. After login, re-navigate to `https://app.asana.com/0/my-apps` to ensure you are on the developer console.

### Step 2 - Reuse or create the "Claude Code" token

Snapshot the console. Under the **Personal access tokens** heading:

- **A `Claude Code` row already exists AND `~/.config/asana/credentials.env` holds a token** → already set up; skip to Step 5 (smoke).
- **A `Claude Code` row exists but no stored token** → the value is unrecoverable (Asana shows each token once). Open it, **Delete** it, then create a fresh one.
- **No `Claude Code` row** → click **Create new token**.

In the **Create new token** dialog: type `Claude Code` into the **Token name** field, tick **I agree to the Asana API Terms**, then click **Create token** (it is disabled until both are done).

### Step 3 - Capture the one-time token via the Copy button (never screenshot)

A **Token details** dialog appears with the token in a readonly field, a **Copy** button, and the warning *"Make sure to copy this access token now. You won't see it again."*

**Click the dialog's "Copy" button** - it puts the full, correct token on the clipboard. This is more reliable than DOM-reading because the Asana PAT is three-segment (`2/userGid/tokenGid:hex`) and easy to truncate with a naive regex. **Do NOT screenshot or snapshot the reveal dialog** - that leaves the secret in an artifact on disk.

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

### Step 4 - Store the token (silent), verify, scrub artifacts

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
# Asana REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: header  Authorization: Bearer \$ASANA_PAT
# Base URL: https://app.asana.com/api/1.0
ASANA_PAT=${TOKEN}
EOF
chmod 600 "$HOME/.config/asana/credentials.env"
unset TOKEN
# Scrub transient Playwright snapshots (auto-captured each action; the reveal dialog can land in one).
# Remove WHOLESALE - never grep-by-token-substring (could match unrelated files).
rm -rf .playwright-mcp 2>/dev/null
```

> **Cross-platform note.** Native Windows stores at `%APPDATA%\asana\credentials.env`; everywhere else `~/.config/asana/credentials.env`. Never hardcode a machine path.

### Step 5 - Report

The verify in Step 4 already confirmed the token. Tell the user: *"All connected - your Asana is ready. You can ask me things like 'show my tasks due this week' or 'add a task to [project]'."* **No restart needed.**

---

## PHASE 2 - Use the connector

**Which tool namespace.** Through the built-in connector the tools are `mcp__claude_ai_Asana__*` - 30-plus tools over the Work Graph, with Asana's own inline cards in the answer - and there is no credentials file, no `opt_fields` and no curl. Through the kit's own route it is the REST runtime loop below. The two are named quite differently: on the built-in route, list what is actually in the `mcp__claude_ai_Asana__*` namespace and match by what each tool does, rather than looking for the endpoints in this section. The one behaviour to remember on the built-in route: it **cannot set custom fields at the moment a task is created** (custom date fields especially) - create the task there and set the field here, or run the whole job on the kit's route. Portfolios are the kit's route only.

### The kit's own route - REST runtime loop

Once `~/.config/asana/credentials.env` exists, follow this loop on every Asana request.

1. Load the token (never print it) and define a helper:

   ```bash
   set -a; . "$HOME/.config/asana/credentials.env"; set +a
   A() { curl -s -H "Authorization: Bearer $ASANA_PAT" -H "Accept: application/json" \
           "https://app.asana.com/api/1.0$1"; }
   ```

2. **Always pass `opt_fields`** - default responses are just `{gid, name, resource_type}`:

   ```bash
   # the user's workspace gid (needed for most listings)
   A "/workspaces?opt_fields=name" | jq '.data[] | {gid, name}'
   ```

3. List tasks. Asana cannot list *all* tasks globally - scope by `project`, by `section`, or by `workspace`+`assignee`:

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
     -d '{"data":{"text":"Following up - any blockers?"}}' \
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
- **Three-segment PAT.** `2/userGid/tokenGid:hex`. A two-segment regex truncates it → silent 401. Use the Copy button, or the `\d+/\d+/\d+:[0-9a-f]+` pattern. (This bit the connector's own build - verified 2026-06-22.)
- **Token shown once.** Asana reveals a new PAT a single time. Capture-then-verify-then-store in one pass; if lost, Delete + recreate.
- **Body must be wrapped in `{"data": {...}}`** on writes. A bare `{"name": "..."}` returns 400. Reads also return under `data`.
- **Can't list all tasks globally.** `GET /tasks` requires a scope: `project`, `section`, `tag`, or `workspace`+`assignee`. Asking for everything returns a 400.
- **No substring-negation in self-checks.** Test the explicit success condition (`http_code == 200` / `.data.gid` present), never "output does NOT contain an error word" - negation checks silently pass when the shape changes.
- **401 Unauthorized** → token revoked/deleted or truncated on capture → re-run Phase 1-alt (Delete any stale `Claude Code` token first).
- **403 Forbidden** → the token owner lacks access to that object. User-permission limit (no read-only token type).
- **429 / rate limits.** Free tier ~1500 req/min, 50 concurrent; respect `Retry-After`. Prefer `limit=100` + offset paging over many small calls.
- **Never snapshot the sign-in page** on the kit's own route - auto-filled password leak (see the Phase 1-alt note).

## Token handling

The PAT is a bearer-equivalent secret. It is stored in `~/.config/asana/credentials.env` (mode 600), read into a shell variable at call time, and **never** echoed to a narration line, a tool return, or a log. Add `**/credentials.env` to any repo `.gitignore` before committing work near this skill - though the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1-alt transcript (token redacted), including the three-segment-truncation gotcha.
- `references/rest-api.md` - endpoint catalogue, `opt_fields`, pagination, and the `{"data":...}` write envelope.
- `skills/CLAUDE.md` - the direct-REST connector family (`pipedrive`, `servicem8`, `cliniko`, `myob`, `ghl`) and the Playwright contingency.
