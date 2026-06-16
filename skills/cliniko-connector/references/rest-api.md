# Cliniko REST API — reference

Loaded on demand during Phase 2. Authoritative source: https://docs.api.cliniko.com/ — consult it for any endpoint/field not covered here.

## Base + auth

- **Base URL:** `https://api.{shard}.cliniko.com/v1`, where `{shard}` is the region appended to the API key (e.g. `…-au5` → `api.au5.cliniko.com`). Keys with no suffix predate sharding and use `au1`.
- **Auth:** HTTP **Basic** — the API key as the username, **blank password**. In curl: `-u "$CLINIKO_API_KEY:"` (the trailing colon suppresses the password prompt).
- **User-Agent:** **required** — Cliniko asks integrators to send a `User-Agent` identifying the app plus a contact email; requests without one are rejected.
- **Format:** JSON. List responses are wrapped: `{ "<resource>": [ … ], "total_entries": N, "links": { "self": "…", "next": "…" } }`.

## Verification status

`GET /practitioners` (read) and the **patient write path** were **live-verified 2026-06-16**: `POST /patients` (create) → `GET /patients/{id}` (read-back) → `DELETE /patients/{id}` all succeeded, with DELETE archiving the patient (**HTTP 204**). Other endpoints/fields below are from Cliniko's official docs and should be confirmed live before being relied on.

## Resource catalogue (per Cliniko docs)

| Resource | Endpoint | Purpose |
|---|---|---|
| Practitioners | `practitioners` | clinicians; `id`, `label`, `first_name`, `last_name`, `active` |
| Patients | `patients` | patients/clients (PHI) |
| Individual appointments | `individual_appointments` | one-on-one bookings |
| Group appointments | `group_appointments` | multi-patient bookings |
| Bookings | `bookings` | booking records |
| Availability blocks | `availability_blocks` | practitioner availability |
| Appointment types | `appointment_types` | services offered |
| Businesses | `businesses` | clinic locations |
| Invoices | `invoices` | billing |
| Products | `products` | sellable items |
| Contacts | `contacts` | non-patient contacts |
| Users | `users` | Cliniko staff users |

A single record is `GET /v1/<resource>/<id>`. Create with `POST /v1/<resource>`; update with `PUT /v1/<resource>/<id>`; remove with `DELETE /v1/<resource>/<id>`.

## Filtering, ordering, pagination (per Cliniko docs)

- **Filter** with repeated `q[]` params of the form `q[]=<field>:<operator><value>` — operators include `=`, `>`, `<`, `>=`, `<=`, `~` (contains), `!=`. URL-encode: `q[]` → `q%5B%5D`, `>` → `%3E`.
  - Example: `?q%5B%5D=updated_at:%3E2026-01-01T00:00:00Z`
- **Order** with `order=` (e.g. `order=created_at:desc`).
- **Paginate** with `per_page` (default 25–50, **max 100**) and follow `links.next` until absent. `total_entries` gives the full count.
- **Archived records** are excluded by default; query archived data via the documented `archived_at` filters where supported.

## Common recipes

List active practitioners:

```bash
CK "$CLINIKO_API_BASE/practitioners" | jq '[.practitioners[] | select(.active==true) | {id, label}]'
```

Count patients updated since a date:

```bash
CK "$CLINIKO_API_BASE/patients?per_page=100&q%5B%5D=updated_at:%3E2026-01-01T00:00:00Z" | jq '.total_entries'
```

Create a patient (capture the new id):

```bash
CK -X POST -H "Content-Type: application/json" \
  -d '{"first_name":"Test","last_name":"Patient"}' \
  "$CLINIKO_API_BASE/patients" | jq '.id'
```

(`CK` is the helper defined in SKILL.md Phase 2: curl with `-u "$CLINIKO_API_KEY:"`, the User-Agent, and Accept headers.)

## Errors

- **200** OK. **201** on create.
- **401** invalid/removed key, trial/account lapsed, or missing/blank credentials.
- **403** the user's security role lacks permission for the resource.
- **422** validation error on a write (body explains which field).
- **429** rate limited — back off and retry.

Official docs: https://docs.api.cliniko.com/ · base URLs & shards: https://docs.api.cliniko.com/guides/urls
