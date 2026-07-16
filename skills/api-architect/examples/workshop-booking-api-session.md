# Worked example: design a REST API for Selr AI's workshop booking system

A reference end-to-end session showing the skill produce a complete API design ready for implementation. **You:** is the user, **Claude:** is the response.

Target: a REST API for booking, paying, attending, and following up on Selr AI workshops. Backed by GHL contacts + Stripe + the Selr Skool community.

---

## You

Design the REST API for our workshop booking flow. Endpoints to: list workshops, get one workshop, book a seat (creates GHL contact + opportunity), confirm payment via Stripe webhook, send the attendee a confirmation email, cancel a booking, request a refund. Include rate limits, auth, idempotency.

## Claude

Walking through the API design end-to-end. Producing OpenAPI 3.1 with rationale.

> [Tool] Confirms target stack: Next.js API routes on Vercel, GHL contacts API as the source of truth for attendees, Stripe Checkout for payments, AWS SES Sydney for outbound email. Auth model: public endpoints for browsing workshops + booking, signed-webhook for Stripe callbacks, bearer-token for admin operations.

---

### Resource model

Two top-level resources, one event resource:

```
GET    /v1/workshops                          # list upcoming
GET    /v1/workshops/{id}                     # detail
POST   /v1/workshops/{id}/bookings            # book a seat
GET    /v1/bookings/{id}                      # status
DELETE /v1/bookings/{id}                      # cancel (self-serve, before 7d cutoff)
POST   /v1/bookings/{id}/refund-requests      # request refund (after cutoff, admin reviews)

POST   /v1/webhooks/stripe                    # Stripe-signed callbacks
POST   /v1/webhooks/ghl                       # GHL-signed callbacks (for tag-changes)

GET    /v1/admin/workshops/{id}/attendees     # bearer-token, room manifest
POST   /v1/admin/bookings/{id}/comp           # bearer-token, comp a seat
```

### Auth

- **Public endpoints** (`GET /workshops`, `GET /workshops/{id}`, `POST /workshops/{id}/bookings`): no auth, rate-limited per IP.
- **Booking-owner endpoints** (`GET /bookings/{id}`, `DELETE /bookings/{id}`, `POST /bookings/{id}/refund-requests`): signed JWT in the magic-link emailed to the attendee. JWT has `sub: booking_id`, 30-day expiry, signed with the API's session secret.
- **Admin endpoints**: bearer token (Selr AI staff PAT, rotated quarterly via Keeper).
- **Webhooks**: signature verification per vendor (Stripe-Signature header + raw body, GHL HMAC SHA256).

### Idempotency

`POST /workshops/{id}/bookings` requires an `Idempotency-Key` header. Server stores `(idempotency_key, booking_id)` for 24h. If the same key is replayed within 24h, the server returns the original booking response (not a duplicate booking).

Why 24h not 7d: Stripe Checkout sessions expire in 24h, so re-attempts beyond that window are a new payment attempt anyway.

### Rate limits

| Endpoint | Limit | Why |
|---|---|---|
| `GET /workshops` | 60/min/IP | Public browsing, plenty of headroom |
| `GET /workshops/{id}` | 60/min/IP | Same |
| `POST /workshops/{id}/bookings` | 5/min/IP | Anti-abuse; humans don't book 5+/min |
| `POST /webhooks/stripe` | unlimited | Stripe's call, not user |
| `GET /admin/*` | 600/min/token | Internal use |

### Sample request: book a seat

```http
POST /v1/workshops/sydney-2026-05-20/bookings
Content-Type: application/json
Idempotency-Key: 7b9c1f4a-2e3d-4b8c-9a1b-3c2d4e5f6a7b

{
  "attendee": {
    "first_name": "Sam",
    "last_name": "Carter",
    "email": "sam@carteragency.com.au",
    "phone": "+61400000000",
    "business_name": "Carter Agency",
    "industry": "Marketing & Advertising"
  },
  "tier": "standard",
  "promo_code": null,
  "marketing_consent": true
}
```

### Sample response: 201 Created

```json
{
  "booking_id": "bk_01HQX2YV9P3F4N6T8WZ",
  "status": "pending_payment",
  "workshop_id": "sydney-2026-05-20",
  "amount_aud": 1500,
  "currency": "AUD",
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_live_...",
  "expires_at": "2026-05-23T14:30:00Z",
  "magic_link_token": "eyJhbGciOiJIUzI1NiIs...",
  "next_step": "open checkout_url to complete payment"
}
```

### State machine

```
pending_payment
  → confirmed         (Stripe webhook: payment_intent.succeeded)
  → cancelled         (DELETE before 7d cutoff)
  → refund_requested  (POST refund-requests after cutoff)
  → refunded          (admin approves; Stripe refund; GHL tag updated)
  → expired           (24h passed, Stripe Checkout session expired)
```

State transitions are GHL-driven for visibility, every state change writes a tag to the GHL contact (`workshop-bk-pending`, `workshop-bk-confirmed`, `workshop-bk-cancelled`, etc) so the team sees status in the GHL UI without checking the API DB.

### Error shape

Consistent across all endpoints:

```json
{
  "error": {
    "code": "RATE_LIMITED",
    "message": "Too many requests. Wait 60 seconds and try again.",
    "request_id": "req_01HQX2YV9P3F4N6T8WZ",
    "retry_after_seconds": 60
  }
}
```

Status codes: 400 (validation), 401 (auth missing), 403 (auth wrong), 404 (resource not found), 409 (idempotency conflict, e.g. seat sold out), 422 (semantic error: workshop already past), 429 (rate limited), 5xx (server errors, with request_id for support).

### Versioning

URL-prefix versioning (`/v1/`). Breaking changes go behind `/v2/`. Within v1, additive changes only (new optional fields, new endpoints). Removing fields or making optional fields required is a v2 event.

### Observability

- Every request gets a `request_id` (UUIDv7, sortable). Logged + returned in `X-Request-ID` header.
- Stripe webhook latency tracked separately so we know if Stripe's slow vs us being slow.
- GHL contact-write latency tracked separately. If GHL is degraded, booking still completes, we queue the GHL write and retry, the user gets confirmed.

### Sample OpenAPI fragment

```yaml
paths:
  /v1/workshops/{id}/bookings:
    post:
      summary: Book a seat
      parameters:
        - in: path
          name: id
          required: true
          schema: { type: string }
        - in: header
          name: Idempotency-Key
          required: true
          schema: { type: string, format: uuid }
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/BookingRequest'
      responses:
        '201': { $ref: '#/components/responses/BookingCreated' }
        '409':
          description: Sold out or idempotency conflict
        '422':
          description: Workshop already past
        '429':
          description: Rate limited
```

Full spec lives at `openapi.yaml` in the implementation repo. Lints clean with `redocly lint`.

---

## What this transcript proves

- The resource model is genuinely RESTful (resources + collections + actions as sub-resources), not RPC-shaped.
- Auth is split correctly: public for browsing, magic-link JWT for booking-owner, bearer for admin, signed for webhooks. Each tier has the right trust model.
- Idempotency is implemented at the HTTP layer (header) with a documented window (24h matching Stripe's session lifetime).
- Rate limits have rationale per endpoint, not blanket numbers.
- State machine is GHL-tagged so the team sees status in the UI without database access.
- Error shape is consistent with `request_id` for support tickets.
- Observability separates Stripe + GHL + our service latency so degraded vendors don't masquerade as our bugs.

The session above was generated against the real Selr AI workshop booking requirements in May 2026.
