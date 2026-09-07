---
name: trello-connector
description: "Connect Trello to Claude by switching on its built-in connector, or by installing and authenticating its API credentials. Use when the user asks to set up or connect Trello, or wants Trello work (boards, lists, cards, due dates, checklists, labels, comments, workspaces) and Trello isn't connected yet. Once connected, Trello runs through the mcp__claude_ai_Trello__* tools, or directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__claude_ai_Trello__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - trello
    - project-management
    - kanban
    - boards
    - cards
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Trello auth (401) or invalid-key/token errors
    - skill: asana-connector
      reason: Sibling work-management connector; useful for comparisons/migrations
    - skill: email-composer
      reason: Draft card comments or updates for Trello collaborators
---

# Trello Connector

## Overview

This skill lets Claude read and update a user's Trello data on their behalf. Trello is the kanban board/card app (lists of cards). It publishes **no MCP server**, so this is a **direct-REST connector** - but with a **two-secret auth model** unique among the kit's connectors:

- **API key** - a 32-char hex, **intended to be public** (per Trello's docs). Identifies the app.
- **Token** - an `ATTA`-prefixed string (~76 chars), the **actual secret**. Grants access to the user's account.

Both are sent as **query params on every call**: `?key=<KEY>&token=<TOKEN>`. Base URL `https://api.trello.com/1`. There is no OAuth refresh - the token is minted with `expiration=never`.

> **Scope note.** This connector is for users who **already have a Trello account**. Don't pitch Trello to someone who doesn't use it - if they need a work-management tool recommendation, that is a different conversation.

### ⚠️ The one manual step on the fallback route: creating the Power-Up

To get an API key, Trello **requires you to first create a "Power-Up"** (`trello.com/power-ups/admin`). That creation form is a **React form that resists browser automation**: its "Create" button is gated on validity state that does NOT update from scripted input - verified 2026-06-22, even direct React-fiber `onChange` injection on every field failed to enable Create. **So Phase 1-alt hands the Power-Up form to the user**: Claude opens it and explains exactly what to type; the user fills **App name**, **Workspace**, and **Email** and clicks **Create** by hand (real keystrokes/clicks register where automation can't). Everything after that - API-key generation, the token authorize + Allow, token capture - Claude drives normally.

### Trello is built into Claude - use that first

Trello has its own listing in Claude's connector directory
(`https://claude.ai/directory/trello` - "Trello", Verified, made by Trello,
added July 2026, connector URL `https://mcp.trello.com/v1`, 15 tools). Switching
it on is one button and a sign-in: no Power-Up, no keys, nothing installed, and
nothing for this skill to store. The connection is **account-level** - made once
on claude.ai or the desktop app, it works everywhere that account is signed in,
Claude Code included.

**So the built-in connector is the default route, and everything about the
Power-Up and the two secrets below is the fallback.** All of it is kept, in full,
because it is still the answer when the built-in can't be used - see Phase 1-alt
for exactly when that is.

The skill has three phases:

- **Phase 1 - Switch on the built-in Trello connector (the default route).** One
  button, one sign-in, then proved with a real read.
- **Phase 1-alt - The kit's own route (only when the built-in can't be used).**
  Playwright + one manual form step: Claude drives the developer console, hands
  the Power-Up *creation form* to the user, then auto-generates the API key, runs
  the token authorize flow (user clicks Allow), captures the token, stores both,
  and verifies.
- **Phase 2 - Use the connector.** Either through the built-in connector's tools,
  or curl against the REST API with `?key=&token=`.

**Which phase to run** - Phase 0 decides, in order: a live built-in connection
wins; otherwise a working set of stored credentials wins
(`~/.config/trello/credentials.env` on Mac/Linux/WSL, `%APPDATA%\trello\credentials.env`
on native Windows, with a non-empty `TRELLO_API_KEY` **and** `TRELLO_TOKEN`, smoke
ping 200); otherwise Phase 1. A 401 on the smoke ping means the stored token was
revoked - re-run Phase 1-alt's token step, or switch to the built-in.

**Full account access.** A `read,write,account` token with `expiration=never` can read and modify everything the user can across their boards. Treat the token like a password (the key is public-safe).

---

## Communication rules for Phase 1 and Phase 1-alt

On Phase 1, follow the account-matched route below and drive the available UI tools. Ask only for sign-in or approval input that requires the user; never request credentials in chat.

The rules below are for **Phase 1-alt**, which has an unavoidable hands-on moment
(the Power-Up form). The user is a non-technical business owner:

- **Drive everything you can; hand off only the Power-Up form.** Be explicit and visual about the one manual step - the user fills three fields and clicks Create. Offer a screenshot if they can't find a field/button.
- **Warn about the two "Create" buttons.** The Trello top-nav has a blue "Create" (makes boards); the form's "Create" is at the **bottom-right of the form card** and starts **greyed out**. Tell the user to use the bottom one, and that it turns blue once the fields are filled with real typing.
- **Plain English only** otherwise. No jargon (API, token, key, REST, curl, scope, Playwright, env, JSON). Call the token "your connection key"; the Power-Up "a small app Trello needs you to create to allow the connection."
- **Never echo the token** (the `ATTA…` value). The API key is public-safe and may be shown.
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

Phase 1 (the built-in connector) needs no browser tool at all - skip this section
entirely on that route. It applies only to Phase 1-alt.

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry. The `--user-data-dir` keeps the Trello login alive.

---

## PHASE 0 - Is Trello already connected?

Identify the calling surface first. Desktop's visible account, Connectors view, and actual runtime tools are its evidence. Terminal `claude auth status` and `claude mcp list` describe the CLI account, even when run from Desktop's Bash; they do not establish Desktop identity or access. Trello credentials are independent of either Claude login. Discover existing tools and perform the read below for the intended vendor account before claiming a connection. Preserve a working route.

Run these silently, in order, and act on the first that answers.

**1. Built-in connector.** In Desktop, discover this session's Trello tools (including opaque-ID prefixes) and inspect the app's Connectors view. For a terminal/VS Code caller only, check the CLI listing below. Apply the response branches to the caller's own state; a missing CLI line does not establish Desktop state.

```bash
claude mcp list 2>&1 | grep -i "^claude.ai Trello"
```

- Connected in the caller or tools present → skip to **Phase 2**. Prove it first with one read from the
  `mcp__claude_ai_Trello__*` tools (list the user's boards); only a real answer
  counts.
- Reconnect or `! Needs authentication` → reconnect in the same caller's Connectors view. In Desktop, start inside the app; for a browser route, verify its Claude account matches the caller before opening `https://claude.ai/customize/connectors`. Complete Trello sign-in and repeat the actual read.
- No usable built-in in the caller → continue to step 2; a missing CLI line alone says nothing about Desktop.

**2. The kit's own route.**

```bash
CRED="$HOME/.config/trello/credentials.env"
if [ -f "$CRED" ] && grep -q '^TRELLO_API_KEY=.\+' "$CRED" && grep -q '^TRELLO_TOKEN=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → say *"Trello is already connected"* and
  go to **Phase 2**. Keep using it; do not set the built-in up on top of a
  working connection. HTTP 401 → the stored token was revoked: re-run
  **Phase 1-alt Step 4** to re-mint it (the Power-Up and key survive), or offer
  the built-in connector instead, which is quicker.
- `not-configured` → continue.

Smoke ping (token never printed):

```bash
set -a; . "$HOME/.config/trello/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' "https://api.trello.com/1/members/me?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN"
```

**3. Nothing found** → **Phase 1**.

**No shell?** Runtime discovery and reads still apply. Skip unavailable command/file checks; only set up a connection if no working route is found, following the existing route-by-need rules.

---

## PHASE 1 - Switch on the built-in Trello connector (the default route)

This is a one-time, once-per-account job. Claude handles the available setup steps; the user supplies any sign-in input that requires them.

### Step 1 - Check this session can see built-in connectors

In Desktop, use its visible signed-in account and Connectors view, then continue inside that app. The following auth/settings checks apply only to a terminal/VS Code caller, not Desktop:

```bash
claude auth status
```

`"authMethod": "claude.ai"` is the pass. If it shows anything else, or
`~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or
`ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear
here. Tell the user in one line that this copy of Claude is signed in a different
way, and run **Phase 1-alt** instead.

### Step 2 - Open the connector page for them

Say: *"I'll open Trello's connection page and handle the setup. I'll let you know if it needs you to sign in."*

**Desktop first:** use the app's **+ → Connectors → Browse connectors → Trello → Connect** (or the equivalent visible Customize/Connectors menu). Keep the exact app-created browser handoff URL, including its parameters. Open it in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended Trello account before approval. Do not replace it with a directory link from another Claude account.

**Terminal/VS Code or browser fallback:** open `https://claude.ai/directory/trello` in a browser whose Claude account matches the caller. Use `open` (Mac), `xdg-open` (Linux), or `start` (Windows) only after confirming that browser's account. If the page fails, use `https://claude.ai/customize/connectors` → **Browse** → search "Trello" → **Connect** in that same account.

Drive navigation and approval with available UI tools. If a step requires user input or the harness has no suitable UI tool, give only the exact short next step; do not describe every click as inherently human-only.

### Step 3 - Wait

Complete the visible flow with available tools; wait for any sign-in input that requires the user. Never ask for a password, a code, or a
screenshot of the sign-in.

### Step 4 - Verify

Check Trello in Desktop's own Connectors view, or `claude mcp list` for a terminal/VS Code caller. Connected is registration evidence only; proceed to the real read in Step 5. Reconnect uses the same account's Connectors view. A missing CLI line says nothing about Desktop. If Desktop still lacks a connection completed through the browser directory, verify **Connected** in that browser's matching Claude account. Once that account check passes, rediscover Desktop's tools and use Step 5's one-time Desktop refresh if needed; do not repeat **Connect** to repair a stale app view. Return to Step 2 only when neither the caller's view nor the account-matched browser confirms a completed connection.

### Step 5 - Prove it

Call one real read through the connector - list the user's boards via a
`mcp__claude_ai_Trello__*` tool. Only a real answer counts. A tool error here is
not "connected". These tools are often deferred in a session, so fetch the namespace first. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If tools are missing, first rediscover deferred tools and confirm the same caller account is connected; only then consider a stale session: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

### Step 6 - Hand off

Two lines: Trello is connected, and three things they can ask for now ("what's on
my board this week", "add a card to the design list", "which cards are overdue").

**Team or Enterprise accounts:** if the page shows **Request** instead of
**Connect**, their Claude administrator has to switch Trello on for the
organisation first. Say so plainly and stop; do not fall back to Phase 1-alt just
to get past an admin gate.

---

## PHASE 1-alt - The kit's own route (only when the built-in can't be used)

Run this instead of Phase 1 in exactly three cases: this session can't see
built-in connectors (Step 1 above failed), Trello's listing is missing on the
user's account, or the user explicitly wants the local key-and-token setup.
Otherwise use Phase 1 - it is one button against everything below.

Nothing in this route has been removed or shortened. It is the original install
flow, verified 2026-06-22.

### The flow

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Open the developer console; accept Developer Terms (one-time)

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://trello.com/power-ups/admin" })
```

If signed out, ask the user to sign in (poll `location.href`). On first ever visit, a **"Privacy and compliance"** gate appears - tick "I acknowledge … Trello Developer Terms" (the checkbox is overlaid by a `label[data-testid="clickable-checkbox"]` - click the label, not the input) and click **Continue**.

### Step 2 - Create the Power-Up (HAND THIS TO THE USER)

Navigate to `https://trello.com/power-ups/admin/new`. This is the **automation-resistant React form**. Do NOT try to fill+submit it programmatically - it will silently fail (the Create button never enables from scripted input). Instead:

1. Take a `browser_take_screenshot` so you can point to fields precisely.
2. Tell the user, in plain English, to fill **exactly these** by typing/clicking themselves:
   - **App name**: `Claude Code`
   - **Workspace**: pick their workspace from the dropdown
   - **Email**: their email
   - (Optional: **Author**. Leave **Support contact** and **Iframe connector URL** BLANK - the iframe URL is only for Power-Ups that inject UI; we don't need it.)
3. Tell them to click the **form's** Create (bottom-right of the card, *not* the top-nav blue Create). It's greyed until the fields register.
4. Wait for them to confirm; then verify you've landed on the app's edit page (`/power-ups/<appId>/edit/...`) by polling `location.href`.

> **Why manual:** verified 2026-06-22 - real Playwright clicks, keyboard entry, native-setter+events, and React-fiber `onChange` injection all failed to enable Create. This is genuine trusted-event gating. Don't burn time re-attempting; hand off the form.

### Step 3 - Generate the API key (Claude drives)

Go to the app's **API Key** tab (`/power-ups/<appId>/edit/api-key`). Click **Generate a new API key**, then **Generate API key** in the confirm dialog. DOM-read the 32-hex key from the readonly field (it is public-safe). Persist it now:

```bash
install -d -m 700 "$HOME/.config/trello"; umask 177
cat > "$HOME/.config/trello/credentials.env" <<EOF
# Trello REST API credentials - token is the secret; key is public-safe.
# Auth: query params  ?key=\$TRELLO_API_KEY&token=\$TRELLO_TOKEN
# Base: https://api.trello.com/1
TRELLO_API_KEY=<key>
TRELLO_TOKEN=
EOF
chmod 600 "$HOME/.config/trello/credentials.env"
```

### Step 4 - Mint the token (Claude drives; user clicks Allow)

Navigate to the authorize URL (`name` is cosmetic; scope/expiration as below):

```
https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=<KEY>&name=Claude%20Code
```

The user is signed in → Trello shows a consent screen. Click **Allow** (`#approveButton`). Trello then lands on `https://trello.com/1/token/approve` and **displays the token in the page text** (manual flow - `response_type=token` with no return_url). Capture it (clipboard-transit, masked return) - note the **`ATTA` prefix**, ~76 chars, mixed case (NOT the legacy 64-hex):

```js
async () => { const m=document.body.innerText.match(/ATTA[A-Za-z0-9]{50,}/); if(!m) return {ok:false};
  await navigator.clipboard.writeText(m[0]); return {ok:true, len:m[0].length}; }
```

### Step 5 - Store the token, verify, scrub

Read the token from the clipboard, **verify before trusting**, write it into the creds file, and scrub the snapshot dir (the token-reveal page is captured in auto-snapshots):

```bash
TOKEN="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
printf '%s' "$TOKEN" | grep -qE '^ATTA[A-Za-z0-9]{50,}$' || { echo "not a Trello token"; exit 1; }
set -a; . "$HOME/.config/trello/credentials.env"; set +a
curl -s "https://api.trello.com/1/members/me?key=$TRELLO_API_KEY&token=$TOKEN&fields=id,username" \
  | python3 -c 'import sys,json; sys.exit(0 if json.load(sys.stdin).get("id") else 1)' || { echo "verify failed"; exit 1; }
python3 - "$TOKEN" <<'PY'
import sys,re,os
t=sys.argv[1]; p=os.path.expanduser("~/.config/trello/credentials.env"); s=open(p).read()
s=re.sub(r'^TRELLO_TOKEN=.*$','TRELLO_TOKEN='+t,s,flags=re.M)
tmp=p+'.tmp'; open(tmp,'w').write(s); os.chmod(tmp,0o600); os.replace(tmp,p)
PY
unset TOKEN
rm -rf .playwright-mcp 2>/dev/null   # token-reveal page lands in auto-snapshots
```

Tell the user: *"All connected - your Trello is ready. Try 'show my boards' or 'add a card to [list]'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\trello\credentials.env`; everywhere else `~/.config/trello/credentials.env`.

---

## PHASE 2 - Use the connector

**Which surface you are on.** Through the built-in connector (Phase 1), Trello
work runs through the `mcp__claude_ai_Trello__*` tools - boards, lists, cards,
comments and the rest, named by the connector itself, with nothing to read from
disk. Through the kit's route (Phase 1-alt) it runs through the REST loop below.
The capabilities overlap heavily; where they differ, the REST route reaches the
full endpoint surface in `references/rest-api.md`, and the built-in reaches only
its own published tools. Use whichever route Phase 0 landed on - never both at
once for the same job.

### The REST runtime loop (Phase 1-alt route)

```bash
set -a; . "$HOME/.config/trello/credentials.env"; set +a
AUTH="key=$TRELLO_API_KEY&token=$TRELLO_TOKEN"
B="https://api.trello.com/1"
```

Every call appends `&$AUTH` (or `?$AUTH` if it has no query string yet), as shown below.

**Reads** (most endpoints return full JSON arrays; use `fields=` to trim):

```bash
# my boards
curl -s "$B/members/me/boards?fields=name,url&$AUTH" | jq '.[] | {id,name}'
# lists on a board, then cards in a list
curl -s "$B/boards/<boardId>/lists?fields=name&$AUTH" | jq '.[] | {id,name}'
curl -s "$B/lists/<listId>/cards?fields=name,due,idMembers&$AUTH" | jq '.[] | {id,name,due}'
# my cards across boards
curl -s "$B/members/me/cards?fields=name,due,idBoard,idList&$AUTH" | jq '.[] | {name,due}'
```

**Writes** (params in the query string; confirm client-visible writes with the user):

```bash
# create a card
curl -s -X POST "$B/cards?idList=<listId>&name=Follow%20up%20with%20client&$AUTH" | jq '.id'
# move a card to another list / set due date
curl -s -X PUT "$B/cards/<cardId>?idList=<listId>&due=2026-06-30T17:00:00Z&$AUTH" | jq '{id,idList,due}'
# comment on a card
curl -s -X POST "$B/cards/<cardId>/actions/comments?text=On%20it&$AUTH" | jq '.id'
# delete a card
curl -s -X DELETE "$B/cards/<cardId>?$AUTH"
```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Boards | `/members/me/boards`, `/boards/<id>` | top-level |
| Lists | `/boards/<id>/lists`, `/lists/<id>` | columns |
| Cards | `/lists/<id>/cards`, `/cards/<id>` | central object; create needs `idList` |
| Checklists | `/cards/<id>/checklists` | |
| Labels | `/boards/<id>/labels` | |
| Members | `/members/me`, `/boards/<id>/members` | |
| Comments | `/cards/<id>/actions/comments` (POST) | comments are "commentCard" actions |
| Workspaces | `/members/me/organizations` | "organizations" = workspaces |

---

## Gotchas

- **Power-Up creation form resists automation.** The #1 thing to know. The Create button won't enable from scripted input (verified incl. React-fiber injection). Hand the form to the user; everything else automates. A workshop attendee driving this solo will hit the same wall - tell them up front it's the one hands-on step.
- **Token format is `ATTA…`, ~76 chars, mixed-case** - NOT the legacy 64-hex. A `[a-f0-9]{64}` regex misses it; use `ATTA[A-Za-z0-9]{50,}`.
- **Two "Create" buttons.** Top-nav blue Create = make a board (wrong). Form Create = bottom-right of the card, greyed until valid (right).
- **Key is public, token is secret.** Don't treat the key as sensitive; DO protect the token.
- **Auth is query params**, not a header. `?key=&token=` on every call.
- **No substring-negation in self-checks.** Match `http_code==200` / `.id` present, never "output lacks an error word".
- **401 / "invalid token"** → token revoked (user disabled it) or wrong → re-run Phase 1-alt Step 4 (re-mint token; key/Power-Up persist). Or switch the user to the built-in connector (Phase 1), which needs no key at all.
- **Rate limits:** 300 req/10s per key and 100 req/10s per token; back off on 429.
- **Deleting is permanent** for cards via DELETE; prefer `closed=true` (archive) for reversible "deletes" when the user may want it back.

## Token handling

The token is a bearer-equivalent secret in `~/.config/trello/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. The API key is public-safe. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1-alt run (token redacted), including the automation-resistant-form hand-off.
- `references/rest-api.md` - endpoints, auth, write params, archive-vs-delete.
- `skills/CLAUDE.md` - Pattern 0 (the built-in connector shape), the direct-REST connector family, and the Playwright contingency.
- `https://claude.ai/directory/trello` - the built-in connector's own page.
