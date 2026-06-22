# Brevo (Sendinblue) REST API — connector reference

Companion to `brevo-connector/SKILL.md`. Verified live against a real account (SelrAI, rodolfo@selrai.com.au, free plan) on 2026-06-22.

## Auth

- **Custom header `api-key: <key>`** (NOT `Authorization`). Raw key value, no scheme prefix.
- **Key format:** prefix `xkeysib-`, **~89 chars, contains hyphens** (`xkeysib-<hex>-<suffix>`). Validate with `xkeysib-[A-Za-z0-9-]+`. **Shown once** at generation; reCAPTCHA-gated; capture via the reveal modal's Copy button.
- **Base URL:** `https://api.brevo.com/v3`
- **Verify:** `GET /account` → `{ email, companyName, plan: [...] }`.
- Generate at `app.brevo.com/settings/keys/api` → Generate API key → name + expiry (pick **No expiration**) → Generate.

## Core entities

| Entity | Endpoint(s) | Verbs | Notes |
|---|---|---|---|
| Account | `/account` | GET | verify; plan/credits |
| Contacts | `/contacts`, `/contacts/{email-or-id}` | GET/POST/PUT/DELETE | POST with `updateEnabled:true` = upsert; DELETE → 204 |
| Contact lists | `/contacts/lists`, `/contacts/lists/{id}`, `/contacts/lists/{id}/contacts` | GET/POST/PUT | |
| List membership | `/contacts/lists/{id}/contacts/add`, `/remove` | POST | body `{"emails":[...]}` |
| Folders | `/contacts/folders` | GET/POST | list containers |
| Senders | `/senders` | GET/POST | must be verified to send |
| Marketing campaigns | `/emailCampaigns`, `/emailCampaigns/{id}` | GET/POST/PUT | create/schedule/send email campaigns |
| Transactional email | `/smtp/email` | POST | **actually sends**; returns `messageId` |
| Transactional templates | `/smtp/templates` | GET/POST | |
| Statistics | `/emailCampaigns/{id}/report`, `/smtp/statistics/*` | GET | |

## Conventions

- **Pagination:** `?limit=N&offset=M` (limit max typically 50–1000 per endpoint); responses include a top-level `count`.
- **Contact identifier** in the path can be the email (URL-encoded) or the numeric `id`.
- **Upsert:** `POST /contacts` with `updateEnabled:true` updates if the email exists instead of erroring.
- **Sending is real:** `/smtp/email` and campaign send/schedule actually deliver to recipients — gate behind explicit user confirmation.

## Recipes

```bash
set -a; . "$HOME/.config/brevo/credentials.env"; set +a
H="api-key: $BREVO_API_KEY"; B="https://api.brevo.com/v3"
BV(){ curl -s -H "$H" -H "accept: application/json" "$@"; }

BV "$B/account" | jq '{email, company:.companyName}'
BV "$B/contacts/lists" | jq '.lists[] | {id,name,totalSubscribers}'
# paginate contacts
off=0; while :; do
  r=$(BV "$B/contacts?limit=50&offset=$off")
  echo "$r" | jq -c '.contacts[] | {id,email}'
  n=$(echo "$r" | jq '.contacts|length'); [ "$n" -lt 50 ] && break; off=$((off+50))
done
# upsert a contact onto a list
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"email":"jane@example.com","attributes":{"FNAME":"Jane"},"listIds":[2],"updateEnabled":true}' "$B/contacts" | jq '.id'
# delete a contact (204)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "$H" "$B/contacts/jane@example.com"
# send transactional (CONFIRM first — this sends)
curl -s -X POST -H "$H" -H "Content-Type: application/json" \
  -d '{"sender":{"email":"rodolfo@selrai.com.au"},"to":[{"email":"jane@example.com"}],"subject":"Hi","htmlContent":"<p>Hello</p>"}' "$B/smtp/email" | jq '.messageId'
```

## Errors

| Code | Meaning | Action |
|---|---|---|
| 400 | Bad body (e.g. existing contact without `updateEnabled`) | Add `updateEnabled:true` / fix payload. |
| 401 | Bad/revoked key, or used `Authorization` instead of `api-key` | Re-mint (Phase 1); fix the header. |
| 404 | Wrong contact/list id | Verify the identifier. |
| 429 | Rate limit | Back off (per-endpoint budgets). |

## Source

- Live verification 2026-06-22 (SelrAI account): `api-key` header auth, `/account`, contacts/lists/senders reads, and a create-contact (201) → read → delete (204) → 404 cycle. Key format `xkeysib-…` 89 chars with hyphens; generation reCAPTCHA-gated, shown once.
- Official docs: https://developers.brevo.com/reference
