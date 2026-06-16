# Deputy REST API — reference

Loaded on demand during Phase 2. Authoritative source: https://developer.deputy.com/ — consult it for any endpoint/field not covered here.

## Base + auth

- **Base URL:** `https://{install}.{geo}.deputy.com/api/v1`, where `{install}.{geo}` is the install subdomain read from the post-login URL (e.g. `b9e78716081714.au.deputy.com`).
- **Auth:** Bearer — `Authorization: Bearer <permanent-token>` on every request. In curl: `-H "Authorization: Bearer $DEPUTY_API_TOKEN"`.
- **Format:** JSON. Resource GETs return an array of records; `/me` returns a single object.

## Verification status

`GET /me` (read) and a **resource write path** were **live-verified 2026-06-16**: `POST /resource/OperationalUnit` (create) → `GET /resource/OperationalUnit/{id}` (read-back) → `DELETE /resource/OperationalUnit/{id}` all succeeded (DELETE → **HTTP 200**). Note: the create initially failed **HTTP 417 "Column 'show_on_roster' cannot be null"** until `ShowOnRoster` was supplied — Deputy enforces non-null required columns per object, so a minimal create body is often rejected (see "Required fields" below). Other endpoints/fields are from Deputy's official docs and should be confirmed live before being relied on.

## Token model

The Permanent Token is minted via an OAuth client at `https://{install}.{geo}.deputy.com/exec/devapp/oauth_clients` → **New OAuth Client** (Name + Redirect URI) → **Save** → **Get An Access Token**. Deputy states the token "will last 10 years" and it carries the creating user's permissions. There is also a full OAuth 2.0 authorization-code flow for distributed apps; this connector uses the simpler Permanent Token because it targets a single install the user owns.

## Resource catalogue (per Deputy docs)

Deputy exposes a generic resource API at `/api/v1/resource/<Object>`:

| Object | Endpoint | Purpose |
|---|---|---|
| (auth user) | `me` | the user the token belongs to; includes `CompanyObject` |
| Employee | `resource/Employee` | team members / staff |
| Roster | `resource/Roster` | scheduled shifts |
| Timesheet | `resource/Timesheet` | worked/approved time |
| OperationalUnit | `resource/OperationalUnit` | areas / locations within a business |
| Company | `resource/Company` | businesses / locations |
| Leave | `resource/Leave` | leave / time-off |
| Address | `resource/Address` | addresses linked to records |
| Comment | `resource/Comment` | comments on records |

CRUD per object:

- **Read one:** `GET /api/v1/resource/<Object>/<id>`
- **Read many:** `GET /api/v1/resource/<Object>` (returns up to the API's page size)
- **Create:** `POST /api/v1/resource/<Object>` with a JSON body
- **Update:** `POST /api/v1/resource/<Object>/<id>` with the changed fields
- **Delete:** `DELETE /api/v1/resource/<Object>/<id>`

## Querying (the `QUERY` search API)

For filtered/paged reads, `POST /api/v1/resource/<Object>/QUERY` with a JSON body:

```json
{
  "search": { "f1": { "field": "Active", "type": "eq", "data": true } },
  "sort":   { "DisplayName": "asc" },
  "join":   [],
  "start":  0,
  "max":    100
}
```

- `search` — named filters; `type` is one of Deputy's operators (`eq`, `ne`, `gt`, `lt`, `ge`, `le`, `like`, `is`, `in`, …).
- `sort` — field → `asc`/`desc`.
- `join` — related objects to embed.
- `start` / `max` — pagination (`max` caps per page; page by incrementing `start`).

## Required fields (creates)

Deputy enforces non-null database columns, so a minimal create body is often rejected with **HTTP 417** (`"Column 'X' cannot be null"`). The error names the missing column (snake_case) — map it to the PascalCase field and resend. Verified example:

- `POST /resource/OperationalUnit` needs at least `OperationalUnitName`, `Company`, **`ShowOnRoster`**, and `RosterActive` — `{"OperationalUnitName":"…","Company":1,"ShowOnRoster":1,"RosterActive":1}` succeeds; omitting `ShowOnRoster` returns `417 "Column 'show_on_roster' cannot be null"`.

When a create returns 417, read the column name from the message, add that field, and retry — do not assume a fixed minimal body across objects.

## Common recipes

Who am I / which company:

```bash
DEP "$DEPUTY_API_BASE/me" | jq '{Name, Company, CompanyObject: .CompanyObject.CompanyName}'
```

Active employees:

```bash
DEP -X POST -H "Content-Type: application/json" \
  -d '{"search":{"a":{"field":"Active","type":"eq","data":true}},"max":100}' \
  "$DEPUTY_API_BASE/resource/Employee/QUERY" | jq '[.[] | {Id, DisplayName}]'
```

Create an employee (capture the new Id):

```bash
DEP -X POST -H "Content-Type: application/json" \
  -d '{"FirstName":"Test","LastName":"Employee"}' \
  "$DEPUTY_API_BASE/resource/Employee" | jq '.Id'
```

(`DEP` is the helper from SKILL.md Phase 2: curl with the Bearer header + Accept.)

## Errors

- **200** OK. **2xx** on create/update.
- **401** invalid/revoked token, or missing Authorization header.
- **403** the user's role lacks permission for the resource.
- **429** rate limited — back off and retry.

Official docs: https://developer.deputy.com/ · "Hello World": https://developer.deputy.com/docs/the-hello-world-of-deputy
