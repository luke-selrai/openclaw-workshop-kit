# ServiceM8 REST API - reference

Loaded on demand during Phase 2 when a request needs an endpoint or field not covered by the SKILL's core-resources table.

## Base + auth

- **Base URL:** `https://api.servicem8.com/api_1.0`
- **Auth header:** `X-API-Key: <key>` on every request (the key minted in Phase 1).
- **Format:** JSON. Read with `GET /<resource>.json`; a single record is `GET /<resource>/<uuid>.json`.
- **Create:** `POST /<resource>.json` with a JSON body; the new record's `uuid` is returned (also in the `x-record-uuid` response header).
- **Update:** `PUT /<resource>/<uuid>.json` with the changed fields.
- **Delete:** `DELETE /<resource>/<uuid>.json` (Full Access only; confirm with the user first). This is a **soft-delete** - ServiceM8 returns `200` and sets `active: 0`; the record is hidden from active lists, not purged. A create returns `{"errorCode":0,"message":"OK"}` with the new uuid in the `x-record-uuid` response header. (Create / read / note / delete all verified live 2026-06-16.)

## Resource catalogue

| Resource | Endpoint | Purpose / key fields |
|---|---|---|
| Company info | `company.json` | the businesses/clients in the account. `uuid`, `name`, `address`, `active`, `is_individual`, `abn_number` |
| Company contact | `companycontact.json` | people at a client. `company_uuid`, `first`, `last`, `email`, `mobile`, `type` |
| Job | `job.json` | central object. `uuid`, `generated_job_id`, `status`, `job_address`, `company_uuid`, `job_description`, `total_invoice_amount`, `date` |
| Job activity | `jobactivity.json` | bookings/time on the dispatch board. `job_uuid`, `staff_uuid`, `start_date`, `end_date`, `activity_was_scheduled` |
| Job material | `jobmaterial.json` | line items. `job_uuid`, `name`, `quantity`, `price`, `total_amount` |
| Job note | `note.json` | notes on a job. `related_object`, `related_object_uuid`, `note` |
| Attachment | `attachment.json` | photos/files. `related_object`, `related_object_uuid`, `attachment_name`, `file_type` |
| Staff | `staff.json` | technicians. `uuid`, `first`, `last`, `email`, `mobile`, `active` |
| Queue | `queue.json` | dispatch-board columns. `uuid`, `name`, `active` |
| Job contact | `jobcontact.json` | the contact(s) linked to a specific job |

`job.status` values: **Quote**, **Work Order**, **Invoice**, **Completed** (plus **Unsuccessful**). A job moves through these as it progresses from enquiry to paid.

## Filtering, ordering, fields

ServiceM8 supports OData-style query params (URL-encode them - `$` is `%24`, space is `%20`, single quotes wrap string literals):

- **Filter:** `?%24filter=status%20eq%20'Work%20Order'` → `$filter=status eq 'Work Order'`
- **Operators:** `eq`, `ne`, `gt`, `ge`, `lt`, `le`, and `and` / `or`.
- **Date filter:** `?%24filter=edit_date%20gt%20'2026-06-01%2000:00:00'`
- **Single record by uuid:** prefer `GET /job/<uuid>.json` over a filter.

Most list endpoints return all records; filter server-side where possible to keep responses small, then shape with `jq` client-side.

## Common recipes

List active clients:

```bash
curl -s -H "X-API-Key: $SERVICEM8_API_KEY" "$SERVICEM8_API_BASE/company.json" \
  | jq '[.[] | select(.active==1) | {uuid, name}]'
```

Open work orders:

```bash
curl -s -H "X-API-Key: $SERVICEM8_API_KEY" \
  "$SERVICEM8_API_BASE/job.json?%24filter=status%20eq%20'Work%20Order'" \
  | jq '.[] | {generated_job_id, job_address, total_invoice_amount}'
```

Create a quote job for a client (capture the new uuid from the response header):

```bash
curl -s -D - -X POST -H "X-API-Key: $SERVICEM8_API_KEY" -H "Content-Type: application/json" \
  -d '{"status":"Quote","company_uuid":"<client-uuid>","job_address":"12 Smith St","job_description":"Inspect hot water system"}' \
  "$SERVICEM8_API_BASE/job.json" | grep -i '^x-record-uuid'
```

Add a note to a job:

```bash
curl -s -X POST -H "X-API-Key: $SERVICEM8_API_KEY" -H "Content-Type: application/json" \
  -d '{"related_object":"job","related_object_uuid":"<job-uuid>","note":"Customer prefers morning visits"}' \
  "$SERVICEM8_API_BASE/note.json"
```

## Rate limits & errors

- **200** OK - including on create: `POST` returns `{"errorCode":0,"message":"OK"}` with the new record's uuid in the `x-record-uuid` response header (verified live 2026-06-16).
- **401** invalid/removed key, or trial/account lapsed → re-run the SKILL's Phase 1.
- **403** the key is Read Only and the call was a write → mint a Full Access key.
- **429** rate limited → back off and retry with a short sleep.

Official docs: https://developer.servicem8.com/docs (authentication, resources).
