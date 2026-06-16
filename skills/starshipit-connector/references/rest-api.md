# Starshipit REST API — reference

Loaded on demand during Phase 2. Authoritative source: https://api-docs.starshipit.com/ — consult it for any endpoint/field not covered here.

## Base + auth

- **Base URL:** `https://api.starshipit.com/api`
- **Auth (two keys, both required on every request):**
  - `StarShipIT-Api-Key: <api key>` — the account API key (Settings → API).
  - `Ocp-Apim-Subscription-Key: <subscription key>` — the Azure-APIM subscription key (Settings → API).
- **Format:** JSON. Send `Content-Type: application/json` on requests with a body.

## Verification status

The **dual-key auth and these reads were live-verified 2026-06-16** (HTTP 200): `GET /orders` (paged), `GET /orders/unshipped`, `GET /addressbook`. Other endpoints below are from Starshipit's official docs and should be confirmed live before being relied on for writes.

**Telling auth from path errors:** a wrong path returns `{"statusCode":404,"message":"Resource not found"}` (auth still OK); a real auth failure is **401/403**. `GET /deliveryservices` returns 404 — it is not the correct path; use the documented resources below.

## Resource catalogue (per Starshipit docs)

| Resource | Endpoint | Purpose |
|---|---|---|
| Unshipped orders | `GET /orders/unshipped` | dispatch/print queue (verified) |
| Shipped orders | `GET /orders/shipped` | already-dispatched orders |
| Orders (paged) | `GET /orders` | full order list with paging (verified) |
| Single order | `GET /orders?order_id=<id>` or `?order_number=<n>` | look up one order |
| Create order | `POST /orders` | create an order (import) |
| Update order | `PUT /orders` | update an order |
| Delete order | `DELETE /orders?order_id=<id>` | remove an order |
| Create shipment / label | `POST /orders/shipment` | generate a shipment + label |
| Address book | `GET /addressbook` | saved addresses (verified) |
| Tracking | `GET /track?tracking_number=<n>` | tracking events/status |

Responses wrap the payload, e.g. `{"orders":[…],"total_pages":N,"success":true}` or `{"addresses":[…]}`. Paged endpoints expose `page_number`, `page_size`, `total_pages`, `total_records`.

## Common recipes

(`SS` is the helper from SKILL.md Phase 2: `curl` with both key headers + `Content-Type`.)

Count orders waiting to ship:

```bash
SS "$STARSHIPIT_API_BASE/orders/unshipped" | jq '.orders | length'
```

List saved addresses:

```bash
SS "$STARSHIPIT_API_BASE/addressbook" | jq '.addresses'
```

Look up an order by number:

```bash
SS "$STARSHIPIT_API_BASE/orders?order_number=TEST-001" | jq '.order // .orders'
```

> **Write caution.** `POST /orders/shipment` generates a real shipping label and can incur carrier charges. Confirm with the user before any shipment/label write; prefer creating a draft order (`POST /orders`) when only demonstrating the write path, and delete it after.

## Errors & limits

- **200** OK. **2xx** on create/update.
- **401 / 403** invalid/missing keys (remember: BOTH headers).
- **404** with a JSON body → wrong path, auth still valid.
- **429** rate limited — ~2 req/s (Developer subscription) / ~20 req/s (Production). Back off and retry.

Official docs: https://api-docs.starshipit.com/ · "How to find your Starshipit API Key": https://support.starshipit.com/hc/en-us/articles/360001893576
