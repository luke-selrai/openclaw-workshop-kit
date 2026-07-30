---
name: trello-connector
description: "Connect Trello to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect Trello, or wants Trello work (boards, lists, cards, due dates, checklists, labels, comments, workspaces) and the credentials aren't in place yet. Once connected, Trello runs directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
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

### ⚠️ The one manual step: creating the Power-Up

To get an API key, Trello **requires you to first create a "Power-Up"** (`trello.com/power-ups/admin`). That creation form is a **React form that resists browser automation**: its "Create" button is gated on validity state that does NOT update from scripted input - verified 2026-06-22, even direct React-fiber `onChange` injection on every field failed to enable Create. **So Phase 1 hands the Power-Up form to the user**: Claude opens it and explains exactly what to type; the user fills **App name**, **Workspace**, and **Email** and clicks **Create** by hand (real keystrokes/clicks register where automation can't). Everything after that - API-key generation, the token authorize + Allow, token capture - Claude drives normally.

The skill has two phases:

- **Phase 1 - Install & Connect (Playwright + one manual form step).** Claude drives the developer console, hands the Power-Up *creation form* to the user, then auto-generates the API key, runs the token authorize flow (user clicks Allow), captures the token, stores both, and verifies.
- **Phase 2 - Use the connector.** curl against the REST API with `?key=&token=`.

**Which phase to run** - Before any Trello action, check for `~/.config/trello/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\trello\credentials.env` (native Windows). If it exists with a non-empty `TRELLO_API_KEY` **and** `TRELLO_TOKEN`, run the Phase 0 smoke ping; on success go to Phase 2; on 401 re-run Phase 1's token step. Otherwise run Phase 1.

**Full account access.** A `read,write,account` token with `expiration=never` can read and modify everything the user can across their boards. Treat the token like a password (the key is public-safe).

---

## Communication rules for Phase 1

The user is a non-technical business owner, but Phase 1 has an unavoidable hands-on moment (the Power-Up form). Rules:

- **Drive everything you can; hand off only the Power-Up form.** Be explicit and visual about the one manual step - the user fills three fields and clicks Create. Offer a screenshot if they can't find a field/button.
- **Warn about the two "Create" buttons.** The Trello top-nav has a blue "Create" (makes boards); the form's "Create" is at the **bottom-right of the form card** and starts **greyed out**. Tell the user to use the bottom one, and that it turns blue once the fields are filled with real typing.
- **Plain English only** otherwise. No jargon (API, token, key, REST, curl, scope, Playwright, env, JSON). Call the token "your connection key"; the Power-Up "a small app Trello needs you to create to allow the connection."
- **Never echo the token** (the `ATTA…` value). The API key is public-safe and may be shown.
- **No restart needed** - no MCP server.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are unavailable, install Playwright first (see `skills/CLAUDE.md`):

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Ask the user to reopen Claude Code once, then retry. The `--user-data-dir` keeps the Trello login alive.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/trello/credentials.env"
if [ -f "$CRED" ] && grep -q '^TRELLO_API_KEY=.\+' "$CRED" && grep -q '^TRELLO_TOKEN=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → smoke ping; HTTP 200 → **Phase 2**; HTTP 401 → re-run the token step in Phase 1 (the Power-Up + key may still exist; just re-mint the token).
- `not-configured` → **Phase 1**.

Smoke ping (token never printed):

```bash
set -a; . "$HOME/.config/trello/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' "https://api.trello.com/1/members/me?key=$TRELLO_API_KEY&token=$TRELLO_TOKEN"
```

---

## PHASE 1 - Install & Connect

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

## PHASE 2 - Use the connector (REST runtime loop)

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
- **401 / "invalid token"** → token revoked (user disabled it) or wrong → re-run Phase 1 Step 4 (re-mint token; key/Power-Up persist).
- **Rate limits:** 300 req/10s per key and 100 req/10s per token; back off on 429.
- **Deleting is permanent** for cards via DELETE; prefer `closed=true` (archive) for reversible "deletes" when the user may want it back.

## Token handling

The token is a bearer-equivalent secret in `~/.config/trello/credentials.env` (mode 600), read into a shell var at call time, **never** echoed. The API key is public-safe. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (token redacted), including the automation-resistant-form hand-off.
- `references/rest-api.md` - endpoints, auth, write params, archive-vs-delete.
- `skills/CLAUDE.md` - the direct-REST connector family and the Playwright contingency.
