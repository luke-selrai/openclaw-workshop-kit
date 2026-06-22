# FreshBooks REST API — connector reference

Companion to `freshbooks-connector/SKILL.md`. Verified live against a real account (Selr AI, account_id `qKQxnJ`) on 2026-06-22.

## Auth (OAuth2 only)

- **No personal API token.** Authorization-code grant: register app → consent → code → tokens.
- **Authorize URL:** `https://auth.freshbooks.com/oauth/authorize/?response_type=code&redirect_uri=<ENC_REDIRECT>&client_id=<CLIENT_ID>`
- **Token URL:** `https://api.freshbooks.com/auth/oauth/token` (POST, JSON body).
  - Code exchange: `{"grant_type":"authorization_code","client_id","client_secret","code","redirect_uri"}`
  - Refresh: `{"grant_type":"refresh_token","client_id","client_secret","refresh_token","redirect_uri"}`
- **Access token** ~12 h (`expires_in` ≈ 43199). **Refresh token is ONE-TIME-USE** — each refresh returns a new one; persist it atomically or the chain breaks.
- **API calls:** `Authorization: Bearer <access_token>` + `Content-Type: application/json`.
- **Redirect URI:** public **HTTPS** required; `localhost` → 422. App names are **globally unique** → 422 "Name has already been taken" on collision.

## IDs

- **account_id** — alphanumeric (e.g. `qKQxnJ`); used by all *accounting* endpoints. Discover via `GET https://api.freshbooks.com/auth/api/v1/users/me` → `response.business_memberships[].business.account_id`.
- **business_id** — numeric (e.g. `14713850`); used by the *Projects/time-tracking* API (out of scope here).

## Accounting API

Base: `https://api.freshbooks.com/accounting/account/<account_id>`

**Response envelope:** list → `{"response":{"result":{"<plural>":[...],"page","pages","per_page","total"}}}`; single/created → `{"response":{"result":{"<singular>":{...}}}}`. Pagination: `?page=N&per_page=M` (max per_page 100).

| Entity | Path | List key / body key | Verbs |
|---|---|---|---|
| Invoices | `/invoices/invoices` (`/invoices/invoices/<id>`) | `invoices` / `invoice` | GET, POST, PUT, (delete = PUT `vis_state:1`) |
| Clients | `/users/clients` (`/users/clients/<id>`) | `clients` / `client` | GET, POST, PUT |
| Expenses | `/expenses/expenses` | `expenses` / `expense` | GET, POST, PUT |
| Payments | `/payments/payments` | `payments` / `payment` | GET, POST, PUT |
| Items/Other | `/items/items`, `/estimates/estimates`* | `items`/`estimates` | GET (write needs extra scopes) |
| Reports | `/reports/accounting/profitloss_entity`, `/reports/accounting/balance_sheet` | under `result` | GET |

\* estimates/items require scopes not added by default in this connector (add via the dev console if needed).

### Filtering & search

- Status: `?search[v3_status]=overdue` (also `paid`, `draft`, `sent`, `partial`, `disputed`).
- Date: `?search[date_min]=2026-01-01&search[date_max]=2026-12-31`.
- Client: `?search[customerid]=<id>`.
- Include sublists: `?include[]=lines` (invoices).

## Recipes

```bash
set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
B="https://api.freshbooks.com/accounting/account/$FRESHBOOKS_ACCOUNT_ID"
FB(){ curl -s -H "Authorization: Bearer $FRESHBOOKS_ACCESS_TOKEN" -H "Content-Type: application/json" "$@"; }

# Overdue invoices
FB "$B/invoices/invoices?search[v3_status]=overdue&per_page=100" \
  | jq '.response.result.invoices[] | {number:.invoice_number, who:.organization, amount:.amount.amount, due:.due_date}'

# Paginate all clients
page=1; while :; do
  r=$(FB "$B/users/clients?per_page=100&page=$page")
  echo "$r" | jq -c '.response.result.clients[] | {id,organization,email}'
  pages=$(echo "$r" | jq '.response.result.pages'); [ "$page" -ge "$pages" ] && break; page=$((page+1))
done

# Create a client then an invoice
cid=$(FB -X POST "$B/users/clients" -d '{"client":{"organization":"Acme Pty Ltd","email":"ap@acme.example"}}' | jq -r '.response.result.client.id')
FB -X POST "$B/invoices/invoices" -d "{\"invoice\":{\"customerid\":$cid,\"create_date\":\"2026-06-30\",\"lines\":[{\"name\":\"Consulting\",\"unit_cost\":{\"amount\":\"150.00\"},\"qty\":\"4\"}]}}" | jq '.response.result.invoice.id'

# Profit & Loss report
FB "$B/reports/accounting/profitloss_entity?start_date=2026-01-01&end_date=2026-12-31" | jq '.response.result'
```

### Refresh on 401 (one-time-use — rotate + persist atomically)

```bash
R=$(curl -s -X POST "https://api.freshbooks.com/auth/oauth/token" -H "Content-Type: application/json" \
  -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"$FRESHBOOKS_CLIENT_ID\",\"client_secret\":\"$FRESHBOOKS_CLIENT_SECRET\",\"refresh_token\":\"$FRESHBOOKS_REFRESH_TOKEN\",\"redirect_uri\":\"$FRESHBOOKS_REDIRECT_URI\"}")
# extract access_token + refresh_token, write both back with temp-file+rename, reload. See SKILL fb_refresh().
```

## Errors

| Code | Meaning | Action |
|---|---|---|
| 401 | Access token expired/invalid | Run refresh (rotate refresh token), retry once. |
| 403 | Scope/permission not granted | Add the scope in the dev console + re-consent. |
| 404 | Wrong account_id or entity id | Verify `account_id` (not business_id) and the id. |
| 422 | Validation (app create: name taken / localhost redirect; writes: bad body) | Read the error body; fix name/redirect/body. |
| 429 | Rate limit | Back off; paginate with per_page=100. |

## Source

- Live verification 2026-06-22: OAuth code+refresh grants, account_id discovery, and invoices/clients/expenses reads (all 200, totals 0 on a fresh account); refresh-token rotation confirmed (new refresh token each call).
- Official docs: https://www.freshbooks.com/api (authentication, accounting endpoints).
