# Trello REST API - connector reference

Companion to `trello-connector/SKILL.md`. Verified live against a real account (user `rodolforaquion`) on 2026-06-22.

## Auth

- **Two secrets, both as query params on every call:** `?key=<API_KEY>&token=<TOKEN>`.
  - **API key** - 32-char hex, **public-safe** ("intended to be publicly accessible" per Trello docs).
  - **Token** - `ATTA`-prefixed, ~76 chars, mixed-case, **secret**. Regex: `ATTA[A-Za-z0-9]{50,}` (the legacy 64-hex format is gone).
- **Base URL:** `https://api.trello.com/1`
- **No OAuth refresh.** Token minted with `expiration=never`, `scope=read,write,account`.

## Getting credentials (setup)

1. Accept Trello Developer Terms (one-time) at `trello.com/power-ups/admin`.
2. **Create a Power-Up** at `trello.com/power-ups/admin/new` - **this form resists automation; the user must complete it by hand** (App name, Workspace, Email → form's bottom-right Create).
3. On the app's **API Key** tab → "Generate a new API key" → confirm → 32-hex key.
4. Token: open `https://trello.com/1/authorize?expiration=never&scope=read,write,account&response_type=token&key=<KEY>&name=Claude%20Code` → **Allow** → token shown on `https://trello.com/1/token/approve` for copy.

## Core entities

| Entity | Endpoint(s) | Verbs | Notes |
|---|---|---|---|
| Members | `/members/me`, `/members/<id>` | GET | `me` = token owner. `?fields=id,username,fullName,email`. |
| Boards | `/members/me/boards`, `/boards/<id>` | GET/POST/PUT/DELETE | `?fields=name,url,closed`. |
| Lists | `/boards/<id>/lists`, `/lists/<id>`, `/lists/<id>/cards` | GET/POST/PUT | Columns. Archive with `?closed=true`. |
| Cards | `/lists/<id>/cards`, `/cards/<id>`, `/members/me/cards` | GET/POST/PUT/DELETE | Central object. Create requires `idList`. Fields: `name`, `desc`, `due`, `dueComplete`, `idList`, `idMembers`, `idLabels`, `pos`, `closed`. |
| Checklists | `/cards/<id>/checklists`, `/checklists/<id>/checkItems` | GET/POST/PUT/DELETE | |
| Labels | `/boards/<id>/labels`, `/cards/<id>/idLabels` | GET/POST | Attach: `POST /cards/<id>/idLabels?value=<labelId>`. |
| Comments | `/cards/<id>/actions/comments` | POST | Stored as `commentCard` actions; read via `/cards/<id>/actions?filter=commentCard`. |
| Members on card | `/cards/<id>/idMembers` | POST/DELETE | Assign/unassign. |
| Workspaces | `/members/me/organizations`, `/organizations/<id>` | GET | "organizations" == workspaces. |
| Search | `/search?query=...` | GET | Cross-entity search. |

## Recipes

```bash
set -a; . "$HOME/.config/trello/credentials.env"; set +a
A="key=$TRELLO_API_KEY&token=$TRELLO_TOKEN"; B="https://api.trello.com/1"

# boards → lists → cards
curl -s "$B/members/me/boards?fields=name&$A" | jq '.[] | {id,name}'
curl -s "$B/boards/<boardId>/lists?fields=name&$A" | jq '.[] | {id,name}'
curl -s "$B/lists/<listId>/cards?fields=name,due&$A" | jq '.[] | {id,name,due}'

# my upcoming cards with due dates
curl -s "$B/members/me/cards?fields=name,due,idList&$A" | jq '[.[] | select(.due!=null)] | sort_by(.due) | .[] | {name,due}'

# create a card
curl -s -X POST "$B/cards?idList=<listId>&name=Send%20invoice&desc=Net%2014&$A" | jq '.id'

# move card + set due
curl -s -X PUT "$B/cards/<cardId>?idList=<listId>&due=2026-06-30T17:00:00Z&$A" | jq '{id,idList,due}'

# comment
curl -s -X POST "$B/cards/<cardId>/actions/comments?text=Following%20up&$A" | jq '.id'

# archive (reversible) vs delete (permanent)
curl -s -X PUT    "$B/cards/<cardId>?closed=true&$A" | jq '.closed'   # archive
curl -s -X DELETE "$B/cards/<cardId>?$A"                              # permanent
```

## Pagination & limits

- Most list endpoints return the **full array** (no cursor). For large/time-ordered collections (notably `/actions`), use `limit` (max 1000), and `before`/`since` (action IDs or ISO dates) to page.
- **Rate limits:** 300 requests / 10s per API key, and 100 requests / 10s per token. On `429`, back off and retry.

## Errors

| Code | Meaning | Action |
|---|---|---|
| 400 | Bad params (e.g., create card without `idList`) | Add required params. |
| 401 | `invalid token` / `invalid key` | Token revoked or wrong → re-mint token (key/Power-Up persist). |
| 404 | Wrong id or no access | Verify the board/list/card id and membership. |
| 429 | Rate limited | Back off (per-key + per-token budgets). |

## Source

- Live verification 2026-06-22 (user `rodolforaquion`): key+token query-param auth, `/members/me`, boards→lists→cards reads, and a create→delete card write cycle (delete 200, subsequent GET 404). Token format confirmed `ATTA…` 76 chars.
- Official docs: https://developer.atlassian.com/cloud/trello/rest/
