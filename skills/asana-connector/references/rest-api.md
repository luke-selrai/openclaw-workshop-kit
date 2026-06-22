# Asana REST API — connector reference

Companion to `asana-connector/SKILL.md`. Everything here was verified live against a real Asana account (workspace `selrai.com.au`) on 2026-06-22.

## Auth + base URL

- **Header:** `Authorization: Bearer <PAT>` on every request. No query-param token form.
- **PAT format:** `<version>/<user_gid>/<token_gid>:<hex>` — **three segments**, e.g. `2/1215919238271902/1215924623120615:52144db…` (68 chars in the verified case). A two-segment regex truncates it → silent 401. Created at the developer console `https://app.asana.com/0/my-apps` → Personal access tokens → Create new token. Shown **once**; grab it from the Token-details dialog's **Copy** button.
- **Base URL:** `https://app.asana.com/api/1.0`

## The two universal conventions

1. **`opt_fields` is mandatory for real data.** By default every object is `{gid, name, resource_type}`. Pass `opt_fields=` (comma-separated) to get more; dotted paths expand relations.
   ```
   /tasks/<gid>?opt_fields=name,due_on,completed,assignee.name,projects.name,custom_fields.name,custom_fields.display_value
   ```
2. **Writes wrap the body in `{"data": {...}}`.** Reads also return their payload under `data`. A bare body returns 400.

## Pagination

Offset-based opaque cursor. Pass `limit` (max **100**) and, for subsequent pages, `offset` taken from the previous response's `next_page.offset`. `next_page` is `null` on the last page.

```jsonc
{ "data": [ ... ], "next_page": { "offset": "eyJ0…", "path": "/...", "uri": "https://..." } }
// or
{ "data": [ ... ], "next_page": null }
```

## Listing scope rules

- `GET /tasks` **requires a scope** — one of: `project=<gid>`, `section=<gid>`, `tag=<gid>`, or `workspace=<gid>`+`assignee=<gid|me>`. A bare `GET /tasks` returns 400.
- Most workspace-level collections (projects, tags, custom_fields) require `workspace=<gid>`.
- `assignee=me` and `completed_since=now` (incomplete only) are handy task filters.

## Core entities

| Entity | Endpoint(s) | Verbs | Notes |
|---|---|---|---|
| Workspaces | `/workspaces`, `/workspaces/<gid>` | GET | Top-level container. Grab the gid first — most listings need it. |
| Users | `/users?workspace=<ws>`, `/users/me`, `/users/<gid>` | GET | `/me` = token owner; default fields incl. `email`, `workspaces`. |
| Teams | `/organizations/<ws>/teams`, `/teams/<gid>`, `/teams/<gid>/projects` | GET/POST | Org-tier (Division/Enterprise) grouping. |
| Projects | `/projects?workspace=<ws>`, `/projects/<gid>` | GET/POST/PUT/DELETE | Task containers. `opt_fields=name,archived,owner.name`. |
| Sections | `/projects/<gid>/sections`, `/sections/<gid>` | GET/POST/PUT/DELETE | Columns/groups within a project. Move a task with `/sections/<gid>/addTask`. |
| Tasks | `/tasks` (scoped), `/projects/<gid>/tasks`, `/tasks/<gid>` | GET/POST/PUT/DELETE | Central object. `due_on`, `due_at`, `completed`, `assignee`, `notes`, `projects[]`, `memberships[]`. |
| Subtasks | `/tasks/<gid>/subtasks` | GET/POST | Child tasks; POST creates one under the parent. |
| Stories | `/tasks/<gid>/stories`, `/stories/<gid>` | GET/POST | Comments + activity log. Create a comment with `{"data":{"text":"..."}}`. |
| Tags | `/tags?workspace=<ws>`, `/tasks/<gid>/tags` | GET/POST | Labels. Attach via `/tasks/<gid>/addTag`. |
| Custom fields | `/workspaces/<ws>/custom_fields`, `/custom_fields/<gid>` | GET/POST | Per-workspace definitions; set values inside a task's `custom_fields`. |
| Attachments | `/tasks/<gid>/attachments`, `/attachments/<gid>` | GET/POST/DELETE | Files on a task (multipart upload for POST). |

## Recipes

```bash
set -a; . "$HOME/.config/asana/credentials.env"; set +a
A() { curl -s -H "Authorization: Bearer $ASANA_PAT" -H "Accept: application/json" \
        "https://app.asana.com/api/1.0$1"; }

# Workspace gid (needed everywhere)
WS=$(A "/workspaces?opt_fields=name" | jq -r '.data[0].gid')

# My open tasks, with due dates and project names
A "/tasks?workspace=$WS&assignee=me&completed_since=now&opt_fields=name,due_on,projects.name&limit=50" \
  | jq '.data[] | {name, due_on, projects: [.projects[].name]}'

# All projects in the workspace
A "/projects?workspace=$WS&opt_fields=name,archived,owner.name" | jq '.data[] | {gid, name, archived}'

# Tasks in a project, paginated
off=""; while :; do
  resp=$(A "/projects/<project_gid>/tasks?opt_fields=name,completed,assignee.name&limit=100${off:+&offset=$off}")
  echo "$resp" | jq -c '.data[] | {gid, name, completed}'
  off=$(echo "$resp" | jq -r '.next_page.offset // empty'); [ -z "$off" ] && break
done

# Create a task (note the {"data":...} envelope)
curl -s -X POST -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
  -d '{"data":{"name":"Send invoice","notes":"Net 14","projects":["<project_gid>"],"assignee":"me","due_on":"2026-06-30"}}' \
  "https://app.asana.com/api/1.0/tasks" | jq '.data.gid'

# Complete a task
curl -s -X PUT -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
  -d '{"data":{"completed":true}}' "https://app.asana.com/api/1.0/tasks/<task_gid>" | jq '.data.completed'

# Comment on a task
curl -s -X POST -H "Authorization: Bearer $ASANA_PAT" -H "Content-Type: application/json" \
  -d '{"data":{"text":"Done — moving to review."}}' \
  "https://app.asana.com/api/1.0/tasks/<task_gid>/stories" | jq '.data.gid'
```

## Errors & limits

| Code | Meaning | Action |
|---|---|---|
| 400 | Missing scope (`GET /tasks` without project/assignee) or missing `{"data":...}` envelope | Add the required scope / wrap the body. |
| 401 | Bad/revoked/**truncated** token | Re-mint (Phase 1); confirm the full three-segment PAT. |
| 403 | Token owner lacks access to the object | User-permission limit (no read-only token type). |
| 404 | Wrong gid or object not visible to the owner | Verify the gid and the owner's membership. |
| 429 | Rate limit (free ~1500/min, 50 concurrent) | Respect `Retry-After`; batch with `limit=100` + offset. |

## Source

- Live verification: workspace `selrai.com.au` (gid `1214794193114114`), 2026-06-22 — Bearer auth, three-segment PAT, `opt_fields` default-minimal behavior, `next_page` offset pagination all confirmed.
- For full field schemas, see the official docs (`https://developers.asana.com/reference`) or request `opt_fields` incrementally per entity.
