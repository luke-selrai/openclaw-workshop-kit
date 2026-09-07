---
name: clickup-connector
description: "Connect ClickUp to Claude by switching on its built-in connector, or by capturing its API credentials when that route is unavailable. Use when the user asks to set up or connect ClickUp, or wants ClickUp work (tasks, lists, spaces, docs, time tracking, due dates, comments) and ClickUp isn't connected yet. Once connected, ClickUp runs through the mcp__claude_ai_ClickUp__* tools, or against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__claude_ai_ClickUp__*,mcp__plugin_playwright_playwright__*
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

This skill lets Claude read and update a user's ClickUp data on their behalf. ClickUp is the work-management app (spaces → folders → lists → tasks). There are two routes, and **the built-in connector is the default**:

- **Phase 1 - the built-in ClickUp connector (default).** ClickUp's own hosted server, listed in Claude's connector directory at `https://claude.com/connectors/clickup` (verified live, 2 Sep 2026). The user connects it once on their Claude account by pressing one button, and it is then available everywhere that account is signed in, including Claude Code. Read and write: find workspace members, create and organise tasks, update task details, **manage documents**, **track time**, comments, custom fields, send team messages. Tools arrive as `mcp__claude_ai_ClickUp__*`. **Docs and time tracking are a straight gain** - the kit's own route below does neither.
- **Phase 1-alt - the kit's own route** (only when the built-in can't be used). A **standalone direct-REST connector** - the same shape as `asana-connector` / `servicem8-connector` (single personal token + curl). Claude opens the Apps settings in a Playwright browser, the user signs in, Claude clicks Generate, the user completes the Google re-auth modal if shown, Claude clicks Copy to grab the token, stores it (mode 600), and verifies with `/user`.
- **Phase 2 - Use the connector.** Whichever route connected: tasks, lists, spaces, comments and the rest.

**The one place the kit's own route wins: volume.** The built-in connector is sign-in-only and is reported to cap daily calls tightly - roughly **50 a day on ClickUp's Free plan and 300 a day on Unlimited and above**. *This cap is unverified*: treat it as a thing to watch for, not a fact to quote at the user up front. If a run stops partway with a limit error, that is the signal - say so plainly and offer Phase 1-alt, which has **no such cap** (it is bounded only by ClickUp's ~100 requests/minute rate limit). Bulk jobs - a few hundred tasks to read, a mass status update, a migration - are the case for going that way from the start.

**Already-a-customer connector.** This skill is for users who **already have a ClickUp account**. Do NOT use it to recommend or pitch ClickUp to users who do not already use it, and do not create a ClickUp workspace for them.

Two ClickUp specifics matter **on the kit's own route** (they are the token's quirks; the built-in connector has no token and neither applies):

- **Auth is a RAW `Authorization` header - NO `Bearer` prefix.** Every call sends `Authorization: pk_…`. Sending `Authorization: Bearer pk_…` fails. This is the #1 ClickUp integration mistake.
- **Token generation may require a Google re-auth.** The Personal API Token (prefix `pk_`) is self-serve under Settings → Apps, but if the account signs in with Google SSO, clicking **Generate** pops a *"Sign in with Google to generate API Token"* modal the user must complete once. The token is then **masked** on screen with a **Copy** button - capture it via Copy, not a DOM read.

**Which phase to run** - always start at Phase 0 below. It checks the built-in connector first, then the kit's own credentials file. A working connection on either route means skip straight to Phase 2 - never set one route up on top of the other.

**Full account access (the kit's own route).** A personal token inherits the owner's permissions across their workspaces - treat it like a password. Note: clicking **Generate** again **regenerates** (invalidates the old token), so only do it when there's no stored token or you're intentionally rotating. The built-in route stores no token at all - Claude never sees or handles one.

---

## Communication rules for connecting (Phase 1 and Phase 1-alt)

The user is a non-technical business owner. Rules:

- **You drive; the user signs in.** Don't ask them to navigate menus or copy values. On the built-in route the only ask is "press Connect and sign in to ClickUp". On the kit's own route the asks are "sign in to ClickUp" and, if the modal appears, "click Sign in with Google and pick your account."
- **Plain English only.** No jargon (API, token, REST, curl, header, DOM, Playwright, env, JSON). Call it "your connection key" / "your ClickUp account".
- **Never echo the token** (`pk_…`). There is no token on the built-in route.
- **Restarts.** The kit's own route needs no restart. The built-in route may need one close-and-reopen before the connection shows up - Phase 1 Step 4 handles it.

---

## Cross-cutting: Playwright MCP install contingency (Phase 1-alt only)

Phase 0 and Phase 1 need no browser automation at all - only **the kit's own route** drives a browser. So a missing Playwright is a reason to prefer Phase 1, not a reason to stop.

If Phase 1-alt is the route and `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry. The `--user-data-dir` keeps the ClickUp login alive.

> **Persistent-profile note:** the Playwright browser is its OWN Chromium instance. If the user says "I'm logged in" but the page still shows ClickUp's login, they signed in elsewhere - ask them to sign in **in the browser window you opened**.

---

## PHASE 0 - Is ClickUp already connected?

Identify the calling surface first. Desktop's visible account, Connectors view, and actual runtime tools are its evidence. Terminal `claude auth status` and `claude mcp list` describe the CLI account, even when run from Desktop's Bash; they do not establish Desktop identity or access. ClickUp credentials are independent of either Claude login. Discover existing tools and perform the read below for the intended vendor account before claiming a connection. Preserve a working route.

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** In Desktop, discover this session's ClickUp tools (including opaque-ID prefixes) and inspect the app's Connectors view. For a terminal/VS Code caller only: `claude mcp list` → look for a line starting `claude.ai ClickUp`.
   - Connected in the caller or tools present → skip to Phase 2. Prove it first with one read from the `mcp__claude_ai_ClickUp__*` namespace (find the workspace's members, or list its spaces) before saying so.
   - Reconnect or `! Needs authentication` → reconnect in the same caller's Connectors view. In Desktop, start inside the app; for a browser route, verify its Claude account matches the caller before opening `https://claude.ai/customize/connectors`. Complete ClickUp sign-in and repeat the actual read.
   - No usable built-in in the caller → continue to step 2; a missing CLI line alone says nothing about Desktop.
2. **The kit's own route.** Check for the stored credentials - `~/.config/clickup/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\clickup\credentials.env` (native Windows):

   ```bash
   CRED="$HOME/.config/clickup/credentials.env"
   if [ -f "$CRED" ] && grep -q '^CLICKUP_TOKEN=.\+' "$CRED"; then echo configured; else echo not-configured; fi
   ```

   Smoke ping (token never printed; RAW header):

   ```bash
   set -a; . "$HOME/.config/clickup/credentials.env"; set +a
   curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: $CLICKUP_TOKEN" "https://api.clickup.com/api/v2/user"
   ```

   - `configured` + HTTP 200 → keep using it. Say *"ClickUp is already connected"* and skip to **Phase 2**. Do not set the built-in up on top of a working connection.
   - `configured` + HTTP 401 → the token was regenerated or revoked. Re-run **Phase 1-alt** to mint a fresh one (or switch to Phase 1 if the user would rather have the one-button connection).
   - `not-configured` → continue.
3. **Nothing found** → Phase 1.

**No shell?** Runtime discovery and reads still apply. Skip unavailable command/file checks; only set up a connection if no working route is found, following the existing route-by-need rules.

---

## PHASE 1 - Switch on the built-in ClickUp connector (the default route)

This is a one-time, once-per-account job. Claude handles the available setup steps; the user supplies any sign-in input that requires them.

**Step 1 - Check this session can see built-in connectors.** In Desktop, use its visible signed-in account and Connectors view, then continue inside that app. The following auth/settings checks apply only to a terminal/VS Code caller, not Desktop: `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route (Phase 1-alt) instead.

**Step 2 - Open the connector page for them.**

Say: *"I'll open ClickUp's connection page and handle the setup. I'll let you know if it needs you to sign in."*

**Desktop first:** use the app's **+ → Connectors → Browse connectors → ClickUp → Connect** (or the equivalent visible Customize/Connectors menu). Keep the exact app-created browser handoff URL, including its parameters. Open it in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended ClickUp account before approval. Do not replace it with a directory link from another Claude account.

**Terminal/VS Code or browser fallback:** open `https://claude.ai/directory/clickup` in a browser whose Claude account matches the caller. Use `open` (Mac), `xdg-open` (Linux), or `start` (Windows) only after confirming that browser's account. If the page fails, use `https://claude.ai/customize/connectors` → **Browse** → search "ClickUp" → **Connect** in that same account.

Drive navigation and approval with available UI tools. If a step requires user input or the harness has no suitable UI tool, give only the exact short next step; do not describe every click as inherently human-only.

**Step 3 - Wait.** Complete the visible flow with available tools; wait for any sign-in input that requires the user. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.**

Check ClickUp in Desktop's own Connectors view, or `claude mcp list` for a terminal/VS Code caller. Connected is registration evidence only; proceed to the real read in Step 5. Reconnect uses the same account's Connectors view. A missing CLI line says nothing about Desktop. If Desktop still lacks a connection completed through the browser directory, verify **Connected** in that browser's matching Claude account. Once that account check passes, rediscover Desktop's tools and use Step 5's one-time Desktop refresh if needed; do not repeat **Connect** to repair a stale app view. Return to Step 2 only when neither the caller's view nor the account-matched browser confirms a completed connection.

**Step 5 - Prove it.** Call one real read through the connector: a tool from the `mcp__claude_ai_ClickUp__*` namespace that finds workspace members or lists spaces. Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If tools are missing, first rediscover deferred tools and confirm the same caller account is connected; only then consider a stale session: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - for example *"show my tasks"*, *"add a task to [list]"*, *"how much time went on [project] this week?"*.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch ClickUp on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

---

## PHASE 1-alt - The kit's own route (only when the built-in can't be used)

Run this **only** when one of these is true: Step 1 above failed (this session cannot see built-in connectors); the ClickUp listing is missing on the user's account; the user explicitly wants the local setup; or the job is a **bulk one** and the built-in connector's daily call cap would bite (see the Overview - the cap is unverified, so let a real limit error or an obviously large job be the trigger, not a guess). Otherwise Phase 1 is the route. Note what this route does **not** get: documents and time tracking, both of which the built-in connector covers.

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

## PHASE 2 - Use the connector

**Which tools you have depends on which route connected.**

- **Through the built-in connector (Phase 1):** the tools are `mcp__claude_ai_ClickUp__*`. Names come from ClickUp's own hosted server, so discover them in the session rather than translating an endpoint from the table below. This set reaches two things the REST loop below does not: **documents** and **time tracking**. It also sends team messages. The hierarchy facts below still hold - they are ClickUp's data model, not an artifact of the REST route - as do the confirm-before-a-client-visible-write rule and the epoch-milliseconds date format.
- **Through the kit's own route (Phase 1-alt):** `curl` against the REST API with the raw `Authorization` header, exactly as below.

If a run on the built-in route stops on a call limit, that is the daily cap described in the Overview: say so plainly and offer Phase 1-alt, which has no daily cap.

### The REST runtime loop (the kit's own route)

```bash
set -a; . "$HOME/.config/clickup/credentials.env"; set +a
H="Authorization: $CLICKUP_TOKEN"; B="https://api.clickup.com/api/v2"
```

**Hierarchy:** team (workspace) → space → folder → list → task → subtask. You can't list tasks without a list id; walk down from the team. Subtasks are tasks with a `parent` task id - create one by POSTing to `/list/<listId>/task` with `"parent":"<taskId>"`.

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

**On the built-in connector:**

- **A tight daily call cap, reported but unverified** - roughly 50/day on ClickUp's Free plan, 300/day on Unlimited and above. It shows up as a limit error partway through a run, not as a warning at the start. Response: say what happened in plain English and offer the kit's own route, which has no daily cap. Do not pre-emptively steer people away from the built-in connector over a number nobody has confirmed.
- **Sign-in only** - there is no key to paste, rotate or store, so none of the token gotchas below apply.

**On the kit's own route:**

- **RAW Authorization header - no `Bearer`.** `Authorization: pk_…`, not `Authorization: Bearer pk_…`. #1 mistake.
- **Generating the token may require a Google re-auth modal** ("Sign in with Google to generate API Token") for SSO accounts - the user must complete it. The token is then masked → capture via the **Copy** button.
- **Generate = regenerate.** Re-clicking Generate invalidates the existing token. Only generate when there's no stored token (or intentionally rotating) - otherwise use Copy.
- **No global task list.** You must scope tasks to a list (or use `/team/<id>/task` with filters). Empty accounts have spaces but possibly **no lists** - create one if needed.
- **Dates are epoch milliseconds** (e.g. `due_date: 1781827200000`), not ISO strings.
- **No substring-negation in self-checks.** Match `http_code==200` / `.user.id` present, never "output lacks an error word".
- **401 Unauthorized** → token regenerated/revoked or `Bearer` prefix mistakenly added → re-run Phase 1-alt / fix the header. (On the built-in route an auth failure means the account connection lapsed - go back to Phase 0 step 1 and press Reconnect; there is no token to re-mint.)
- **429 rate limit** → ClickUp's free/standard plans allow ~100 req/min per token; back off on 429.
- **DELETE returns 204** (no body); don't parse JSON from it.

## Token handling

Only the kit's own route has a token. On the built-in route Claude never sees, stores or handles a credential - the sign-in is held by the user's Claude account - so say that plainly if they ask where it is kept.

The personal token is a bearer-equivalent secret in `~/.config/clickup/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified run of the kit's own route (Phase 1-alt) with the token redacted, including the Google-re-auth modal and the wrong-browser-session gotcha.
- `https://claude.com/connectors/clickup` - the built-in connector's directory page (name, capabilities, Connect button).
- `references/rest-api.md` - hierarchy, endpoints, pagination, epoch-ms dates, write bodies.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
