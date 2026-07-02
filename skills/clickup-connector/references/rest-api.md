# ClickUp REST API - connector reference

Companion to `clickup-connector/SKILL.md`. Verified live against a real account (workspace "Selrai", user `Rodolfo Raquion` id 312738239) on 2026-06-22.

## Auth

- **Personal API token**, prefix `pk_`, self-serve at Settings → Apps (`app.clickup.com/settings/apps`).
- **Sent as a RAW `Authorization` header - NO `Bearer` prefix:** `Authorization: pk_123_ABC…`. (Bearer fails.)
- **Base URL:** `https://api.clickup.com/api/v2`
- **Verify:** `GET /user` → `{"user":{"id",...}}`.
- Token generation may pop a **"Sign in with Google to generate API Token"** modal (SSO accounts); the value is masked → use the **Copy** button. Re-clicking **Generate** regenerates (invalidates old).

## Hierarchy

`team` (workspace) → `space` → `folder` (optional) → `list` → `task` → subtask. Tasks always live in a list. There is no global "all my tasks" without a scope.

| Entity | Endpoint(s) | Verbs | Notes |
|---|---|---|---|
| User | `/user` | GET | token owner |
| Teams (workspaces) | `/team` | GET | `.teams[]` |
| Members | `/team/<id>/member` | GET | |
| Spaces | `/team/<id>/space`, `/space/<id>` | GET/POST/PUT/DELETE | `.spaces[]` |
| Folders | `/space/<id>/folder`, `/folder/<id>` | GET/POST/PUT/DELETE | `.folders[]`; each folder has `.lists[]` |
| Lists | `/space/<id>/list` (folderless), `/folder/<id>/list`, `/list/<id>` | GET/POST/PUT/DELETE | `.lists[]` |
| Tasks | `/list/<id>/task`, `/task/<id>`, `/team/<id>/task` | GET/POST/PUT/DELETE | central object; create needs a list; DELETE → 204 |
| Subtasks | `/list/<id>/task` with `parent=<taskId>` | POST | |
| Comments | `/task/<id>/comment` | GET/POST | body key `comment_text` |

## Conventions

- **Pagination:** task lists take `?page=0` (0-indexed); response includes `"last_page": true|false`. Loop incrementing `page` until `last_page` is true.
- **Dates are epoch milliseconds** (e.g. `due_date: 1781827200000`), not ISO. Set `due_date_time:true` if the time matters.
- **Status** on create/update is the status *name* string (e.g. `"to do"`, `"complete"`) - must be a status that exists in that list's workflow.
- **Custom fields:** `/list/<id>/field` to discover; set via `/task/<id>/field/<fieldId>`.

## Recipes

```bash
set -a; . "$HOME/.config/clickup/credentials.env"; set +a
H="Authorization: $CLICKUP_TOKEN"; B="https://api.clickup.com/api/v2"

# walk down to a list
TID=$(curl -s -H "$H" "$B/team" | jq -r '.teams[0].id')
SID=$(curl -s -H "$H" "$B/team/$TID/space" | jq -r '.spaces[0].id')
curl -s -H "$H" "$B/space/$SID/list"   | jq '.lists[]  | {id,name}'
curl -s -H "$H" "$B/space/$SID/folder" | jq '.folders[]| {id,name,lists:[.lists[]|{id,name}]}'

# tasks in a list (paginate)
page=0; while :; do
  r=$(curl -s -H "$H" "$B/list/<listId>/task?page=$page")
  echo "$r" | jq -c '.tasks[] | {id,name,status:.status.status}'
  [ "$(echo "$r" | jq '.last_page')" = "true" ] && break; page=$((page+1))
done

# create / complete / comment / delete
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"name":"Send invoice","status":"to do"}' "$B/list/<listId>/task" | jq '.id'
curl -s -X PUT  -H "$H" -H "Content-Type: application/json" \
  -d '{"status":"complete"}' "$B/task/<taskId>" | jq '.status.status'
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"comment_text":"On it"}' "$B/task/<taskId>/comment" | jq '.id'
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/task/<taskId>"   # 204
```

## Errors

| Code | Meaning | Action |
|---|---|---|
| 401 | Bad/regenerated token, or `Bearer` prefix added | Re-mint (Phase 1); use RAW header. |
| 404 | Wrong id, or no access | Verify the team/space/list/task id. |
| OAUTH_* / 400 | Bad status name, missing list, bad body | Use a status that exists in the list; create in a list. |
| 429 | Rate limit (~100 req/min per token) | Back off. |

## Source

- Live verification 2026-06-22 (workspace Selrai): RAW-header auth, `/user`, team→space→list walk, and a create-list → create-task → read → delete-task (204) → delete-list (200) cycle. Token format `pk_…`; generation required a Google re-auth modal.
- Official docs: https://developer.clickup.com/reference/
