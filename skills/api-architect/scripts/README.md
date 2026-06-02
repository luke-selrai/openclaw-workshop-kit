# validate-api-spec.sh

A zero-dependency linter for the API contract files in a directory. It
catches the structural mistakes the SKILL's anti-pattern list warns about —
verb-based URLs, missing pagination/error schemas, unsigned webhooks,
missing versioning — before they reach review.

## Dependencies

- **Bash** (4.x+) and **grep** — that's it. No `npm install`, no network.
- Runs on macOS, Linux, WSL, and Git Bash on Windows.

It does *not* parse YAML/SDL/proto semantically — it's a fast grep-based
gate, not a replacement for a real validator. Pair it with
`npx @redocly/cli lint` (OpenAPI), `npx graphql` (SDL), or `protoc`
(proto) for full schema validation. See "Deeper validation" below.

## Usage

Run it from the directory that holds your specs (it globs the current
directory):

```bash
cd path/to/specs
bash /path/to/scripts/validate-api-spec.sh
```

It inspects every `*.yaml`, `*.yml`, `*.graphql`, and `*.proto` file it
finds, plus the `openapi/`, `api/`, `schema/`, `graphql/`, and `proto/`
subdirectories.

## What it checks

| Surface | Checks |
|---------|--------|
| OpenAPI | `openapi:` version, `info`/`servers`/`securitySchemes` sections, `operationId` on operations, verb-based URLs (error), 4xx error responses |
| GraphQL | `Query` type, Relay `Connection` → `PageInfo`, mutation `errors` payloads, custom scalar definitions |
| Protobuf | `proto3` syntax, `package`, `go_package`, field number 0 in messages (error) |
| Webhooks | retry policy + request signing in any webhook/delivery config |
| Common | hardcoded `localhost`/IPs, presence of a versioning strategy |

## Exit codes

| Condition | Exit | Banner |
|-----------|------|--------|
| No errors, ≤5 warnings | `0` | `✅ Validation PASSED` |
| No errors, >5 warnings | `0` | `⚠️  Validation PASSED with warnings` |
| Any error | `1` | `❌ Validation FAILED` |
| No specs found to check | `2` | `⚠️  Validation INCONCLUSIVE` |

Errors are blockers (verb URLs, missing `info`/`package`, field-number 0,
`nullable` in an OpenAPI 3.1 spec). Warnings are advisories you should review
but that won't fail CI. Exit `2` means the script ran against a directory with
no API specs — a green pass on nothing would be misleading, so it's called out
separately. The summary prints a `Files checked:` count so you can confirm it
actually inspected what you expected.

## Sample run — PASS

Against the bundled `references/` directory:

```
$ cd references && bash ../scripts/validate-api-spec.sh
📋 Checking OpenAPI specifications...
  Checking: openapi-spec.yaml
🔷 Checking GraphQL schemas...
  Checking: graphql-schema.graphql
🔌 Checking Protocol Buffer definitions...
  Checking: grpc-service.proto
🪝 Checking webhook delivery configs...
  Checking: webhook-delivery.yaml
🔍 Checking for common API design issues...
  Versioning strategy detected ✅

Files checked: 4
Errors:   0
Warnings: 0
✅ Validation PASSED
$ echo $?
0
```

## Sample run — FAIL

Against a directory with a verb-based, info-less spec and an unsigned
one-shot webhook config:

```
$ bash validate-api-spec.sh
📋 Checking OpenAPI specifications...
  Checking: bad-openapi.yaml
❌ ERROR: bad-openapi.yaml missing info section
⚠️  WARN: bad-openapi.yaml missing servers section
⚠️  WARN: bad-openapi.yaml missing security schemes
⚠️  WARN: bad-openapi.yaml missing operationId (required for SDK generation)
❌ ERROR: bad-openapi.yaml contains verb-based URLs (use nouns, let HTTP methods convey action)
⚠️  WARN: bad-openapi.yaml missing 4xx error responses
🪝 Checking webhook delivery configs...
  Checking: hooks.yaml
⚠️  WARN: hooks.yaml webhook config missing a retry policy (use at-least-once + backoff)
⚠️  WARN: hooks.yaml webhook config missing request signing (receivers can't verify authenticity)

Files checked: 2
Errors:   2
Warnings: 6
❌ Validation FAILED - fix errors before publishing API
$ echo $?
1
```

## Deeper validation

This script is a first gate. For full semantic validation:

```bash
npx @redocly/cli lint openapi-spec.yaml          # OpenAPI
npx graphql-schema-linter graphql-schema.graphql # GraphQL SDL
protoc --proto_path=. grpc-service.proto -o /dev/null   # protobuf
```