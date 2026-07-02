---
name: clickup-connector
description: "Connect and operate ClickUp (work management - spaces, lists, tasks) via its REST API for users who already have a ClickUp account. ClickUp uses a self-serve Personal API Token (prefix pk_). Phase 1 is autonomous via Playwright: Claude opens Settings → Apps (app.clickup.com/settings/apps), the user signs in, Claude clicks Generate under API Token - and if the account uses Google SSO, ClickUp shows a 'Sign in with Google to generate API Token' modal that the user must complete (one quick re-auth) - then Claude captures the token via its Copy button (the value is masked on screen), stores it at ~/.config/clickup/credentials.env (mode 600), and verifies. Phase 2 reads and writes via curl against https://api.clickup.com/api/v2 using a RAW Authorization header (the token alone, NO 'Bearer' prefix). Handles teams/workspaces, spaces, folders, lists, tasks, subtasks, comments, and members. No vendor MCP. Use this skill when the user asks to 'connect my ClickUp', 'set up ClickUp', or asks anything about their ClickUp tasks, lists, spaces, due dates, or to 'create a task'. Do NOT use to recommend ClickUp to users who do not already use it. On first use, run Phase 1 to mint and store the token before any API call."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - clickup
    - project-management
    - work-management
    - tasks
    - lists
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting ClickUp auth (401) or token-generation errors
    - skill: asana-connector
      reason: Sibling work-management connector; useful for comparisons/migrations
    - skill: email-composer
      reason: Draft task comments or updates for ClickUp collaborators
---

# ClickUp Connector

## Overview

This skill lets Claude read and update a user's ClickUp data on their behalf. ClickUp is the work-management app (spaces → folders → lists → tasks). It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the same shape as `asana-connector` / `servicem8-connector` (single personal token + curl).

Two ClickUp specifics matter:

- **Auth is a RAW `Authorization` header - NO `Bearer` prefix.** Every call sends `Authorization: pk_…`. Sending `Authorization: Bearer pk_…` fails. This is the #1 ClickUp integration mistake.
- **Token generation may require a Google re-auth.** The Personal API Token (prefix `pk_`) is self-serve under Settings → Apps, but if the account signs in with Google SSO, clicking **Generate** pops a *"Sign in with Google to generate API Token"* modal the user must complete once. The token is then **masked** on screen with a **Copy** button - capture it via Copy, not a DOM read.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright, with sign-in + maybe a Google re-auth).** Claude opens the Apps settings, the user signs in, Claude clicks Generate, the user completes the Google re-auth modal if shown, Claude clicks Copy to grab the token, stores it (mode 600), and verifies with `/user`.
- **Phase 2 - Use the connector.** curl against the REST API with the raw `Authorization` header.

**Which phase to run** - Before any ClickUp action, check for `~/.config/clickup/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\clickup\credentials.env` (native Windows). If it exists with a non-empty `CLICKUP_TOKEN`, run the Phase 0 smoke ping; on success go to Phase 2; on 401 re-run Phase 1. Otherwise run Phase 1.

**Full account access.** A personal token inherits the owner's permissions across their workspaces - treat it like a password. Note: clicking **Generate** again **regenerates** (invalidates the old token), so only do it when there's no stored token or you're intentionally rotating.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Rules:

- **You drive; the user signs in (and may do one Google re-confirmation).** Don't ask them to navigate menus or copy values - the only asks are "sign in to ClickUp" and, if the modal appears, "click Sign in with Google and pick your account."
- **Plain English only.** No jargon (API, token, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection key" / "your ClickUp account".
- **Never echo the token** (`pk_…`).
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry. The `--user-data-dir` keeps the ClickUp login alive.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows ClickUp's login, they signed in elsewhere - ask them to sign in **in the browser window you opened**.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/clickup/credentials.env"
if [ -f "$CRED" ] && grep -q '^CLICKUP_TOKEN=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → **Phase 2**; HTTP 401 → re-run **Phase 1** (token regenerated/revoked).
- `not-configured` → **Phase 1**.

Smoke ping (token never printed; RAW header):

```bash
set -a; . "$HOME/.config/clickup/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/user"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Open the Apps settings; confirm signed in

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.clickup.com/settings/apps" })
```

If signed out it redirects to `app.clickup.com/login`. Ask the user to sign in **in this window**; poll `location.href` until it's back on `…/settings/apps` (the URL gains the workspace id, e.g. `app.clickup.com/<workspaceId>/settings/apps`).

### Step 2 - Generate the token (handle the Google re-auth modal)

Under the **API Token** heading: if a token already exists you'll see **Copy** + **Regenerate** (skip to Step 3 and Copy - do NOT regenerate unless rotating). If not, click **Generate** (`data-test="apps-settings__user-regenerate-api-key"`).

A modal **"Sign in with Google to generate API Token"** may appear (for Google-SSO accounts). The "Sign in with Google" control is a Google-rendered button (often in a Google iframe) - Claude generally can't click it reliably, and the account-pick is the user's action anyway. **Ask the user to click "Sign in with Google" and pick their account.** After they do, ClickUp generates the token and the section switches to showing **Copy** / **Regenerate**.

### Step 3 - Capture via the Copy button (the value is masked)

The token (`pk_…`) is **masked on screen**; don't DOM-read it. Click the **Copy** button (`data-test="apps-settings__user-copy-api-key"`) to put it on the clipboard.

### Step 4 - Store, verify, scrub

```bash
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
printf '%s' "$TOKEN" | grep -qE '^pk_[A-Za-z0-9_]+$' || { echo "clipboard not a ClickUp token"; exit 1; }
# verify BEFORE persisting (RAW Authorization header - no Bearer)
curl -s -H "Authorization: $TOKEN" "https://api.clickup.com/api/v2/user" \
  | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("user",{}).get("id") else 1)' || { echo "verify failed"; exit 1; }
install -d -m 700 "$HOME/.config/clickup"; umask 177
cat > "$HOME/.config/clickup/credentials.env" <<EOF
# ClickUp REST API credentials - personal token (secret).
# Auth: header  Authorization: \$CLICKUP_TOKEN   (RAW token, NO 'Bearer' prefix)
# Base: https://api.clickup.com/api/v2
CLICKUP_TOKEN=${TOKEN}
EOF
chmod 600 "$HOME/.config/clickup/credentials.env"
unset TOKEN
rm -rf .playwright-mcp 2>/dev/null
```

Tell the user: *"All connected - your ClickUp is ready. Try 'show my tasks' or 'add a task to [list]'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\clickup\credentials.env`; everywhere else `~/.config/clickup/credentials.env`.

---

## PHASE 2 - Use the connector (REST runtime loop)

```bash
set -a; . "$HOME/.config/clickup/credentials.env"; set +a
H="Authorization: $CLICKUP_TOKEN"; B="https://api.clickup.com/api/v2"
```

**Hierarchy:** team (workspace) → space → folder → list → task. You can't list tasks without a list id; walk down from the team.

```bash
# workspace(s)  (ClickUp calls them "teams" in the API)
curl -s -H "$H" "$B/team" | jq '.teams[] | {id,name}'
# spaces in a team
curl -s -H "$H" "$B/team/<teamId>/space" | jq '.spaces[] | {id,name}'
# lists: folderless directly in the space, AND lists inside folders
curl -s -H "$H" "$B/space/<spaceId>/list"   | jq '.lists[] | {id,name}'
curl -s -H "$H" "$B/space/<spaceId>/folder" | jq '.folders[] | {id,name,lists:[.lists[].name]}'
# tasks in a list (paginated: ?page=0,1,… ; response has "last_page": true/false)
curl -s -H "$H" "$B/list/<listId>/task?page=0" | jq '.tasks[] | {id,name,status:.status.status,due_date}'
# my tasks across a workspace
curl -s -H "$H" "$B/team/<teamId>/task?assignees[]=<userId>&page=0" | jq '.tasks[] | {name,status:.status.status}'
```

**Writes** (JSON body; confirm client-visible writes with the user):

```bash
# create a task in a list
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"name":"Follow up with client","status":"to do","due_date":1781827200000}' \
  "$B/list/<listId>/task" | jq '.id'
# update a task (status, name, due date - epoch ms)
curl -s -X PUT -H "$H" -H "Content-Type: application/json" \
  -d '{"status":"complete"}' "$B/task/<taskId>" | jq '{id,status:.status.status}'
# comment on a task
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"comment_text":"On it"}' "$B/task/<taskId>/comment" | jq '.id'
# delete a task (returns 204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/task/<taskId>"
```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Teams (workspaces) | `/team` | top-level container |
| Spaces | `/team/<id>/space`, `/space/<id>` | |
| Folders | `/space/<id>/folder` | optional layer; lists can be folderless |
| Lists | `/space/<id>/list`, `/folder/<id>/list`, `/list/<id>` | task container |
| Tasks | `/list/<id>/task`, `/task/<id>`, `/team/<id>/task` | central object; create needs a list |
| Comments | `/task/<id>/comment` | |
| Members / user | `/user`, `/team/<id>/member` | `/user` = token owner |

---

## Gotchas

- **RAW Authorization header - no `Bearer`.** `Authorization: pk_…`, not `Authorization: Bearer pk_…`. #1 mistake.
- **Generating the token may require a Google re-auth modal** ("Sign in with Google to generate API Token") for SSO accounts - the user must complete it. The token is then masked → capture via the **Copy** button.
- **Generate = regenerate.** Re-clicking Generate invalidates the existing token. Only generate when there's no stored token (or intentionally rotating) - otherwise use Copy.
- **No global task list.** You must scope tasks to a list (or use `/team/<id>/task` with filters). Empty accounts have spaces but possibly **no lists** - create one if needed.
- **Dates are epoch milliseconds** (e.g. `due_date: 1781827200000`), not ISO strings.
- **No substring-negation in self-checks.** Match `http_code==200` / `.user.id` present, never "output lacks an error word".
- **401 Unauthorized** → token regenerated/revoked or `Bearer` prefix mistakenly added → re-run Phase 1 / fix the header.
- **429 rate limit** → ClickUp's free/standard plans allow ~100 req/min per token; back off on 429.
- **DELETE returns 204** (no body); don't parse JSON from it.

## Token handling

The personal token is a bearer-equivalent secret in `~/.config/clickup/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (token redacted), including the Google-re-auth modal and the wrong-browser-session gotcha.
- `references/rest-api.md` - hierarchy, endpoints, pagination, epoch-ms dates, write bodies.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
