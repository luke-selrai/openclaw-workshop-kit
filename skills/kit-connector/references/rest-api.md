# Kit (ConvertKit) v4 REST API - connector reference

Companion to `kit-connector/SKILL.md`. Verified live against a real account (SelrAI, rodolfo@selrai.com.au, creator plan) on 2026-06-22.

## Auth

- **v4 API**, header **`X-Kit-Api-Key: <key>`** (not `Authorization`, not a query param).
- **Key:** self-serve, prefix `kit_`, ~36 chars, **shown once** at creation (capture via Copy). Generate at `app.kit.com/account_settings/developer_settings` → **V4 Keys → Add a new key**.
- **Base URL:** `https://api.kit.com/v4`
- **Verify:** `GET /account` → `{ "account": { name, primary_email_address, plan_type, ... } }`.
- **Ignore legacy v3** (`https://api.convertkit.com/v3`, `api_key`/`api_secret` query params) - different base + auth; v4 is current.

## Core entities

| Entity | Endpoint(s) | Verbs | Notes |
|---|---|---|---|
| Account | `/account` | GET | verify; plan info |
| Subscribers | `/subscribers`, `/subscribers/<id>` | GET/POST | POST = upsert by `email_address`; **no hard delete** → `/subscribers/<id>/unsubscribe` (POST) |
| Tags | `/tags`, `/tags/<id>` | GET/POST/DELETE | DELETE → 204 |
| Tag membership | `/tags/<id>/subscribers` | GET/POST/DELETE | tag/untag by `email_address` or subscriber id |
| Forms | `/forms`, `/forms/<id>/subscribers` | GET/POST | add subscribers via a form |
| Sequences | `/sequences`, `/sequences/<id>/subscribers` | GET/POST | email automations |
| Broadcasts | `/broadcasts`, `/broadcasts/<id>` | GET/POST/PUT | one-off emails - **publishing/sending delivers** |
| Custom fields | `/custom_fields` | GET/POST/PUT/DELETE | |
| Webhooks | `/webhooks` | GET/POST/DELETE | |

## Conventions

- **Cursor pagination** (NOT offset): pass `?per_page=N` (max 1000; default 500). Response carries `pagination: { has_next_page, has_previous_page, start_cursor, end_cursor }`. Page forward with `?after=<end_cursor>` while `has_next_page` is true (page back with `before=<start_cursor>`).
- **Subscriber state:** `active`, `inactive`, `cancelled`, etc. Creating a subscriber that exists updates it (upsert by email).
- **Sending is real:** broadcast send/publish and sequence enrollment email actual subscribers - gate behind explicit user confirmation.

## Recipes

```bash
set -a; . "$HOME/.config/kit/credentials.env"; set +a
H="X-Kit-Api-Key: $KIT_API_KEY"; B="https://api.kit.com/v4"
KIT(){ curl -s -H "$H" -H "Accept: application/json" "$@"; }

KIT "$B/account" | jq '.account | {name, email:.primary_email_address, plan:.plan_type}'

# paginate all subscribers (cursor)
after=""; while :; do
  r=$(KIT "$B/subscribers?per_page=500${after:+&after=$after}")
  echo "$r" | jq -c '.subscribers[] | {id,email_address,state}'
  more=$(echo "$r" | jq -r '.pagination.has_next_page')
  [ "$more" = "true" ] || break
  after=$(echo "$r" | jq -r '.pagination.end_cursor')
done

# upsert a subscriber, create a tag, tag them
KIT -X POST -H "Content-Type: application/json" -d '{"email_address":"jane@example.com","first_name":"Jane"}' "$B/subscribers" | jq '.subscriber.id'
TID=$(KIT -X POST -H "Content-Type: application/json" -d '{"name":"VIP"}' "$B/tags" | jq -r '.tag.id')
KIT -X POST -H "Content-Type: application/json" -d '{"email_address":"jane@example.com"}' "$B/tags/$TID/subscribers" | jq '.'

# delete a tag (204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/tags/$TID"
```

## Errors

| Code | Meaning | Action |
|---|---|---|
| 401 | Bad/revoked key, wrong header, or a v3 key against v4 | Re-mint v4 key (Phase 1); use `X-Kit-Api-Key`. |
| 404 | Wrong id | Verify subscriber/tag/form id. |
| 422 | Validation (bad email, missing field) | Fix payload. |
| 429 | Rate limit | Back off. |

## Source

- Live verification 2026-06-22 (SelrAI account): `X-Kit-Api-Key` v4 auth, `/account`, subscribers/tags/forms reads (cursor pagination), and a create-tag → delete-tag (204) → gone cycle. Key format `kit_…` 36 chars, shown once.
- Official docs: https://developers.kit.com/v4
