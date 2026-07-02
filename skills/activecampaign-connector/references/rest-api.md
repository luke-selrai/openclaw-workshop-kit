# ActiveCampaign v3 REST API - connector reference

Companion to `activecampaign-connector/SKILL.md`. Verified live against a real account (selrai.activehosted.com, admin / rodolfo@selrai.com.au) on 2026-06-22.

## Auth

- **Two credentials** (both from Settings → Developer, shown persistently):
  - **API URL** - account-specific base, e.g. `https://selrai.api-us1.com` (region suffix varies: `api-us1`, etc.). Not secret.
  - **API Key** - long hex (~72 chars). Secret. Sent in the **`Api-Token`** header.
- **Header:** `Api-Token: <key>` (NOT `Authorization`, not a query param).
- **Base URL:** `<API_URL>/api/3`
- **Verify:** `GET /api/3/users/me` → `{ "user": { id, username, email } }`.

## Core entities

| Entity | Endpoint(s) | Verbs | Body key | Notes |
|---|---|---|---|---|
| User | `/users/me`, `/users` | GET | - | verify / token owner |
| Contacts | `/contacts`, `/contacts/<id>` | GET/POST/PUT/DELETE | `contact` | DELETE → 200; POST upserts-ish (409 if exists - use `/contact/sync` to upsert) |
| Contact sync | `/contact/sync` | POST | `contact` | create-or-update by email |
| Lists | `/lists`, `/lists/<id>` | GET/POST | `list` | mailing lists |
| List membership | `/contactLists` | POST | `contactList` | subscribe/unsubscribe (`status`: 1=active, 2=unsub) |
| Tags | `/tags`, `/tags/<id>` | GET/POST/DELETE | `tag` | `tagType`: `contact` or `template` |
| Contact tags | `/contactTags` | GET/POST/DELETE | `contactTag` | link contact↔tag |
| Deals (CRM) | `/deals`, `/dealStages`, `/pipelines` | GET/POST/PUT | `deal` | light CRM |
| Campaigns | `/campaigns` | GET/POST | `campaign` | **sending delivers real email** |
| Automations | `/automations`, `/contactAutomations` | GET/POST | - | enroll contacts into automations |
| Custom fields | `/fields`, `/fieldValues` | GET/POST/PUT | `field`/`fieldValue` | |

## Conventions

- **Pagination:** `?limit=N&offset=M` (limit max 100; default 20). Response carries `meta.total`.
- **Write envelope:** every create/update wraps the payload in the singular entity key - `{"contact":{...}}`, `{"tag":{...}}`, `{"deal":{...}}`.
- **DELETE returns 200** (with a body), not 204.
- **Filtering:** many list endpoints support `filters[<field>]=value` (e.g. `/contacts?filters[email]=jane@example.com`) and `?search=`.
- **Upsert contacts:** plain `POST /contacts` errors if the email exists; use `POST /contact/sync` to create-or-update.
- **Sending is real:** campaign send + automation enrollment email actual contacts - gate behind explicit user confirmation.

## Recipes

```bash
set -a; . "$HOME/.config/activecampaign/credentials.env"; set +a
H="Api-Token: $ACTIVECAMPAIGN_API_KEY"; B="$ACTIVECAMPAIGN_API_URL/api/3"
AC(){ curl -s -H "$H" -H "Accept: application/json" "$@"; }

AC "$B/users/me" | jq '.user | {username,email}'
AC "$B/lists" | jq '.lists[] | {id,name}'
# paginate contacts
off=0; while :; do
  r=$(AC "$B/contacts?limit=100&offset=$off")
  echo "$r" | jq -c '.contacts[] | {id,email}'
  tot=$(echo "$r" | jq -r '.meta.total'); off=$((off+100)); [ "$off" -ge "$tot" ] && break
done
# upsert a contact, create a tag, link them
cid=$(AC -X POST -H "Content-Type: application/json" -d '{"contact":{"email":"jane@example.com","firstName":"Jane"}}' "$B/contact/sync" | jq -r '.contact.id')
tid=$(AC -X POST -H "Content-Type: application/json" -d '{"tag":{"tag":"VIP","tagType":"contact"}}' "$B/tags" | jq -r '.tag.id')
AC -X POST -H "Content-Type: application/json" -d "{\"contactTag\":{\"contact\":\"$cid\",\"tag\":\"$tid\"}}" "$B/contactTags" | jq '.contactTag.id'
# delete a contact (200)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/contacts/$cid"
```

## Errors

| Code | Meaning | Action |
|---|---|---|
| 401/403 | Bad key, wrong account URL, or `Authorization` used instead of `Api-Token` | Re-mint/re-read (Phase 1); fix header + URL. |
| 404 | Wrong id, or wrong account region URL | Verify id and the `api-usN` base. |
| 422 | Validation (bad body / missing entity-key wrap / duplicate email on POST) | Wrap in entity key; use `/contact/sync` to upsert. |
| 429 | Rate limit (~5 req/sec per account) | Back off. |

## Source

- Live verification 2026-06-22 (selrai.activehosted.com): `Api-Token` header auth + account URL `https://selrai.api-us1.com`, `/users/me`, lists/tags/contacts reads (meta.total), and a create-contact → read → delete (200) → 404 cycle. Key ~72 hex chars; both URL + key shown persistently in Settings → Developer.
- Official docs: https://developers.activecampaign.com/reference
