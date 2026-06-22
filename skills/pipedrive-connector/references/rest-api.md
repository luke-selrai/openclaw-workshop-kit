# Pipedrive REST API — connector reference

Companion to `pipedrive-connector/SKILL.md`. Everything here was verified live against a real Pipedrive account (domain `selrai`) on 2026-06-22.

## Auth + base URL

- **Header:** `x-api-token: <token>` on every request. The token is a 40-char hex personal API token from *Settings → Personal preferences → API* (`https://<company>.pipedrive.com/settings/api`).
- **Do NOT use `Authorization: Bearer`** — that is for OAuth access tokens and returns `401` with a personal API token. (Verified: Bearer → 401, `x-api-token` → 200.)
- **Legacy alternative:** `?api_token=<token>` query param works on both v1 and v2 but leaks the secret into URLs/logs — prefer the header.
- **Base URL is company-scoped:** `https://<company>.pipedrive.com`. The `<company>` subdomain comes from the post-login URL host and is stored as `PIPEDRIVE_COMPANY_DOMAIN`.

## v1 vs v2 — which to call

Pipedrive is mid-migration. Most CRUD is on **v2 (GA)**; some entities remain **v1-only**.

| Concern | v2 (`/api/v2`) | v1 (`/api/v1`) |
|---|---|---|
| Pagination | **cursor**: `limit` + `cursor`; next page in `additional_data.next_cursor` (null = done) | **offset**: `start` + `limit`; continue while `additional_data.pagination.more_items_in_collection == true` |
| Update verb | `PATCH /<entity>/<id>` | `PUT /<entity>/<id>` |
| Create verb | `POST /<entity>` | `POST /<entity>` |
| Response envelope | `{ success, data, additional_data }` | `{ success, data, additional_data }` |

**Rule of thumb:** try v2 first; if a `PATCH`/`GET` returns 404 for the entity, it is v1-only (leads, notes, filters, files).

## Core entities

| Entity | Endpoint | Verbs | Notes |
|---|---|---|---|
| Deals | `/api/v2/deals` | GET/POST/PATCH/DELETE | Central object. Key fields: `title`, `value`, `currency`, `status` (open/won/lost/deleted), `stage_id`, `pipeline_id`, `person_id`, `org_id`, `owner_id`, `expected_close_date`. |
| Deal search | `/api/v2/deals/search?term=…` | GET | Full-text; results under `data.items[].item`. |
| Persons (contacts) | `/api/v2/persons` | GET/POST/PATCH/DELETE | Fields: `name`, `emails[]`, `phones[]`, `org_id`, `owner_id`. |
| Person search | `/api/v2/persons/search?term=…&fields=email` | GET | `fields` ∈ name,email,phone,notes,custom_fields. |
| Organizations | `/api/v2/organizations` | GET/POST/PATCH/DELETE | Fields: `name`, `owner_id`, `address`. |
| Pipelines | `/api/v2/pipelines` | GET/POST/PATCH/DELETE | Default account seeds **Sales pipeline** + **Onboarding pipeline**. |
| Stages | `/api/v2/stages` | GET/POST/PATCH/DELETE | Each has `pipeline_id`. Move a deal by setting its `stage_id`. |
| Activities | `/api/v2/activities` | GET/POST/PATCH/DELETE | Calls/meetings/tasks; `type`, `due_date`, `due_time`, `deal_id`, `person_id`, `done`. |
| Products | `/api/v2/products` | GET/POST/PATCH/DELETE | Catalogue; attach to deals via deal products. |
| Users | `/api/v1/users`, `/api/v1/users/me` | GET | `/me` returns the token owner (use for smoke test): `name`, `email`, `company_name`, `company_domain`. |
| Leads | `/api/v1/leads` | GET/POST/PATCH/DELETE | **v1 only.** Pre-deal inbox; convert to deal. |
| Notes | `/api/v1/notes` | GET/POST/PUT/DELETE | **v1 only.** Attach via `deal_id` / `person_id` / `org_id`. |
| Filters | `/api/v1/filters` | GET/POST/PUT/DELETE | **v1 only.** Saved filters. |
| Files | `/api/v1/files` | GET/POST/DELETE | **v1 only.** Multipart upload; attach to records. |

## Recipes

```bash
set -a; . "$HOME/.config/pipedrive/credentials.env"; set +a
PD() { curl -s -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Accept: application/json" \
         "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com$@"; }

# Open deals, newest first
PD "/api/v2/deals?limit=50&sort_by=add_time&sort_direction=desc&status=open" \
  | jq '.data[] | {id, title, value, currency, stage_id}'

# All stages grouped by pipeline (note the `.data |` — group_by operates on the array, not the envelope)
PD "/api/v2/stages" | jq '.data | group_by(.pipeline_id) | map({pipeline: .[0].pipeline_id, stages: map(.name)})'

# Find a person by email, then their open deals
pid=$(PD "/api/v2/persons/search?term=jane%40example.com&fields=email" | jq -r '.data.items[0].item.id // empty')
[ -n "$pid" ] && PD "/api/v2/deals?person_id=$pid&status=open" | jq '.data[] | {id,title,value}'

# Create a person, then a deal for them (CONFIRM with user before writing)
new_pid=$(curl -s -X POST -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","emails":[{"value":"jane@example.com","primary":true,"label":"work"}]}' \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/persons" | jq -r '.data.id')
curl -s -X POST -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Content-Type: application/json" \
  -d "{\"title\":\"Jane Doe — new enquiry\",\"value\":2500,\"currency\":\"AUD\",\"person_id\":$new_pid,\"pipeline_id\":2,\"stage_id\":6}" \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/deals" | jq '.data.id'

# Move a deal to another stage (PATCH = v2)
curl -s -X PATCH -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"stage_id":9}' \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v2/deals/123" | jq '.data | {id,stage_id}'

# Add a note to a deal (notes are v1 → POST, no PATCH)
curl -s -X POST -H "x-api-token: $PIPEDRIVE_API_TOKEN" -H "Content-Type: application/json" \
  -d '{"content":"Called — following up Friday.","deal_id":123}' \
  "https://$PIPEDRIVE_COMPANY_DOMAIN.pipedrive.com/api/v1/notes" | jq '.data.id'
```

## Errors & limits

| Code | Meaning | Action |
|---|---|---|
| 401 | Bad/regenerated/revoked token, or used `Authorization: Bearer` | Re-run Phase 1; confirm `x-api-token` header. |
| 403 | Token owner lacks visibility/permission for the record | User-permission limit (no read-only token type). |
| 404 | Wrong version for the entity (e.g. v2 PATCH on a v1-only entity) | Fall back to the v1 endpoint + `PUT`. |
| 410 | Endpoint retired | Check v1↔v2 table. |
| 429 | Rate budget exhausted (per-company + per-user token budget) | Back off + retry; bulk-read with `limit=100` + cursor. |

## Source

- Live verification: account `selrai`, 2026-06-22 (auth header, v1/v2 split, cursor pagination, pipelines/stages all confirmed).
- For exact field schemas, fetch live via context7 (`/pipedrive/api-docs`) or the per-entity `…Fields` endpoints (`/api/v2/dealFields`, `/api/v2/personFields`).
