---
name: api-architect
description: 'Expert API designer for REST, GraphQL, gRPC architectures. Activate on: API design, REST API, GraphQL schema, gRPC service, OpenAPI, Swagger, API versioning, endpoint design, rate limiting,
  OAuth flow. NOT for: database schema (use data-pipeline-engineer), frontend consumption (use web-design-expert), deployment (use devops-automator).'
allowed-tools: Read,Write,Edit,Bash(npm:*,npx:*,openapi-generator:*)
metadata:
  category: Code Quality & Testing
  pairs-with:
  - skill: data-pipeline-engineer
    reason: Data layer design under APIs
  - skill: devops-automator
    reason: Deployment and infrastructure for APIs
  tags:
  - api
  - rest
  - graphql
  - grpc
  - architecture
---

# API Architect

Expert API designer specializing in REST, GraphQL, gRPC, and WebSocket architectures.

## Activation Triggers

**Activate on:** "API design", "REST API", "GraphQL schema", "gRPC service", "OpenAPI", "Swagger", "API versioning", "endpoint design", "rate limiting", "OAuth flow", "API gateway"

**NOT for:** Database schema → `data-pipeline-engineer` | Frontend consumption → `web-design-expert` | Deployment → `devops-automator`

## Quick Start

1. **Define API contract first** (API-first design)
2. **Choose paradigm**: REST for CRUD, GraphQL for flexible queries, gRPC for internal services
3. **Write the spec**: OpenAPI for REST, SDL for GraphQL, .proto for gRPC
4. **Design error responses** with consistent structure
5. **Plan versioning** before your first release

## Core Capabilities

| Domain | Technologies |
|--------|-------------|
| **REST** | OpenAPI 3.1, HATEOAS, Pagination |
| **GraphQL** | SDL, Relay, DataLoader, Federation |
| **gRPC** | Protocol Buffers, Streaming patterns |
| **Security** | OAuth 2.0, JWT, API Keys, RBAC |
| **DX** | Swagger UI, SDK generation, Sandboxes |

## Choosing a Paradigm

Quick start says "REST for CRUD, GraphQL for flexible queries, gRPC for
internal services." When the choice isn't obvious, use the matrix:

| Factor | REST | GraphQL | gRPC |
|--------|------|---------|------|
| **Payload shape** | Fixed per endpoint | Client picks fields | Fixed, binary (protobuf) |
| **Best for** | CRUD, public APIs | Aggregating many resources, varied clients | High-throughput service-to-service |
| **Latency / size** | Moderate (JSON) | Moderate; one round-trip for nested data | Lowest (binary + HTTP/2 multiplexing) |
| **Public vs internal** | Public-friendly (cacheable, curl-able) | Public or internal | Internal (needs gen'd clients; weak browser support) |
| **Streaming** | SSE / polling | Subscriptions | First-class (server/client/bidi) |
| **Caching** | Easy (HTTP verbs + URLs) | Hard (POST, single endpoint) | Manual |
| **Tooling maturity** | Highest (Swagger, Postman, everywhere) | Strong (Apollo, Relay) | Strong but codegen-bound (protoc) |
| **Skip it when** | Clients need wildly different field sets | You need HTTP caching or simple ops | Callers are browsers or third parties |

Rule of thumb: **REST by default**, GraphQL when client field needs vary
widely, gRPC when both ends are yours and latency/throughput dominate.

## Architecture Patterns

### API-First Development
```
Design Contract → Generate Stubs → Implement → Test Against Spec
```

### Response Envelope
```yaml
success: { data: <resource>, meta: { page, total } }
error: { error: { code, message, details: [{ field, issue }] } }
```

### Versioning Options
- URL: `/v1/users` (most explicit)
- Header: `Accept: application/vnd.api+json;version=1`
- Query: `/users?version=1`

## Reference Files

Full working examples in `./references/`. Each file opens with a "What's
inside" preamble so you can skim before opening it. All three contract
files (`openapi`, `graphql`, `grpc`) pass `scripts/validate-api-spec.sh`.

| File | What's inside |
|------|---------------|
| `openapi-spec.yaml` | OpenAPI 3.1 User Service — versioned server, JWT auth, cursor pagination, `data`/`meta` envelope, `ValidationError` schema. Copy as a REST starting point. |
| `graphql-schema.graphql` | SDL with Query/Mutation/Subscription, Relay `Connection`/`PageInfo` pagination, and mutation payloads that return an `errors` array. |
| `grpc-service.proto` | proto3 `UserService` showing all four RPC shapes (unary, server-, client-, bidi-streaming) plus `FieldMask` partial updates and `oneof`. |
| `rate-limiting.yaml` | Four-tier policy, `X-RateLimit-*` headers, sliding-log vs token-bucket, per-endpoint overrides, the 429 body. Config, not a contract. |
| `api-security.yaml` | Auth (API key / JWT / OAuth2 flows), RBAC + ABAC, input validation, CORS, security headers, leak-free error handling. Config, not a contract. |
| `webhook-delivery.yaml` | At-least-once delivery, exponential-backoff retries + dead-letter, HMAC signing, the event envelope, and the consumer idempotency contract. |

## Anti-Patterns (AVOID These)

### 1. Verb-Based URLs
**Symptom**: `/getUsers`, `/createOrder`, `/deleteProduct`
**Fix**: Use nouns (`/users`, `/orders`), let HTTP methods convey action

### 2. Inconsistent Response Envelopes
**Symptom**: `{data: [...]}` sometimes, raw arrays other times
**Fix**: Always use consistent envelope structure

### 3. Breaking Changes Without Versioning
**Symptom**: Removing fields, changing types without warning
**Fix**: Semantic versioning, deprecation headers, sunset periods

### 4. N+1 in GraphQL
**Symptom**: Resolver queries database per item in list
**Fix**: DataLoader pattern for batching, `@defer` for large payloads

### 5. Over-fetching REST Endpoints
**Symptom**: `/users` returns 50 fields when clients need 3
**Fix**: Sparse fieldsets (`?fields=id,name,email`) or GraphQL

### 6. Missing Pagination
**Symptom**: List endpoints return all records
**Fix**: Default limits, cursor-based pagination, `hasMore` indicator

### 7. No Idempotency Keys
**Symptom**: Duplicate POST requests create duplicate resources
**Fix**: Accept `Idempotency-Key` header, return cached response

### 8. Leaky Internal Errors
**Symptom**: Stack traces, SQL errors exposed in 500 responses
**Fix**: Generic error messages in production, request IDs for debugging

### 9. Missing CORS Configuration
**Symptom**: Browser clients blocked with CORS errors
**Fix**: Configure allowed origins, methods, headers explicitly

### 10. No Rate Limiting
**Symptom**: API vulnerable to abuse, no usage visibility
**Fix**: Implement limits per tier, return `X-RateLimit-*` headers

### 11. Webhooks Without Retries or Signing
**Symptom**: Webhook fires once with no signature; a consumer that's down
for 5 seconds loses the event, and receivers can't tell a real delivery
from a spoofed POST
**Fix**: At-least-once delivery with exponential-backoff retries + a
dead-letter queue; sign payloads (HMAC-SHA256 over `timestamp.body`) and
have consumers verify; stable event IDs so consumers stay idempotent. See
`references/webhook-delivery.yaml`.

## Validation Script

`./scripts/validate-api-spec.sh` lints the spec files in the current
directory. It's **pure Bash + grep — no install step**. Run it from the
folder holding your specs:

```bash
cd references && bash ../scripts/validate-api-spec.sh
```

It checks:
- OpenAPI specs for versions, security schemes, operationIds, verb-based URLs
- GraphQL schemas for Query types, Relay pagination, mutation error payloads
- Protocol Buffers for proto3 syntax, packages, field numbers
- Webhook configs for retry + signing semantics
- Common issues like hardcoded URLs and missing versioning

Sample run against the bundled references (exit 0):

```
✅ Validation PASSED
Errors:   0
Warnings: 0
```

Errors fail the run (exit 1); >5 warnings pass with a review note. Full
docs, dependencies, and a sample failure are in
[`scripts/README.md`](scripts/README.md).

## Quality Checklist

```
[ ] All endpoints use nouns, not verbs
[ ] Consistent response envelope structure
[ ] Error responses include codes and actionable messages
[ ] Pagination on all list endpoints
[ ] Authentication/authorization documented
[ ] Rate limit headers defined
[ ] Versioning strategy documented
[ ] CORS configured for known origins
[ ] Idempotency keys for mutating operations
[ ] Webhooks signed and retried (at-least-once + dead-letter)
[ ] OpenAPI spec validates without errors
[ ] SDK generation tested
[ ] Examples for all request/response types
```

## Output Artifacts

The first three are written by hand from the references above. The last
three are **generated from the contract** — never hand-maintained, so they
can't drift from the spec.

1. **OpenAPI Specifications** — Complete API contracts (start from `references/openapi-spec.yaml`)
2. **GraphQL Schemas** — Type definitions with connections (start from `references/graphql-schema.graphql`)
3. **Protocol Buffers** — gRPC service definitions (start from `references/grpc-service.proto`)
4. **API Documentation** — Render the OpenAPI spec; don't write docs by hand:
   ```bash
   npx @redocly/cli build-docs openapi-spec.yaml -o docs.html   # static HTML
   # or serve interactive Swagger UI from the same spec
   ```
5. **SDK Examples** — Generate typed clients from the contract:
   ```bash
   npx @openapitools/openapi-generator-cli generate \
     -i openapi-spec.yaml -g typescript-fetch -o ./sdk/ts
   # swap -g for python, go, java, … ; for gRPC use protoc + the language plugin
   ```
6. **Postman Collections** — Import `openapi-spec.yaml` directly (Postman → Import →
   OpenAPI) or convert in CI: `npx openapi-to-postmanv2 -s openapi-spec.yaml -o collection.json`

## Tools Available

- `Read`, `Write`, `Edit` - File operations for specs
- `Bash(npm:*, npx:*)` - OpenAPI linting, code generation
- `Bash(openapi-generator:*)` - SDK generation
