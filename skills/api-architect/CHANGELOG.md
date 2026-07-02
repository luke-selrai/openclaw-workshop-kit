# Changelog

All notable changes to the api-architect skill will be documented in this file.

## [2.1.0] - 2026-06-01

Production-hardening pass — closes the five vetting weaknesses that held the
skill at "Promising" (Evidence=3).

### Added
- `references/webhook-delivery.yaml` — at-least-once delivery, backoff
  retries + dead-letter, HMAC signing, event envelope, consumer contract
- 11th anti-pattern: "Webhooks Without Retries or Signing" + a checklist item
- "Choosing a Paradigm" decision matrix (payload shape, latency, public vs
  internal, streaming, caching, tooling maturity) replacing the one-line
  REST/GraphQL/gRPC guidance
- `scripts/README.md` — dependencies, usage, and real PASS/FAIL sample runs
- Skim-able "What's inside" preamble at the top of every reference file
- Webhook retry/signing checks in `validate-api-spec.sh`
- Concrete generate-from-contract commands for the API docs, SDK, and
  Postman output artifacts (Redocly, openapi-generator, openapi-to-postman)

### Fixed
- `validate-api-spec.sh` aborted on the first warning under `set -e`
  (`((WARNINGS++))` returns the pre-increment `0` → exit 1). Switched to
  `VAR=$((VAR + 1))` so the script completes its full report
- Versioning detection no longer false-negatives on `/v1` server URLs
  (regex required a trailing slash)
- SKILL.md reference table replaced stale line-count column (counts had
  drifted: grpc 95→102, rate-limiting 85→98, etc.) with content summaries
- `validate-api-spec.sh` now errors on `nullable` in an OpenAPI 3.1 spec
  (removed in 3.1; the grep validator previously passed specs a real parser
  rejects). Surfaced by a skill-qa-harness live run.
- `validate-api-spec.sh` no longer prints a green pass when it inspected zero
  specs — it reports `Files checked:` and exits `2` (INCONCLUSIVE) instead

## [2.0.0] - 2024-12-12

### Changed
- **BREAKING**: Restructured SKILL.md from 561 lines to ~170 lines for progressive disclosure
- Moved all large code examples to `./references/` directory
- Expanded anti-patterns section from 5 to 10 patterns

### Added
- `references/openapi-spec.yaml` - Complete OpenAPI 3.1 specification example
- `references/graphql-schema.graphql` - Full GraphQL schema with Relay connections
- `references/grpc-service.proto` - Protocol Buffer with all streaming patterns
- `references/rate-limiting.yaml` - Tier-based rate limiting configuration
- `references/api-security.yaml` - Authentication, authorization, and security headers
- `scripts/validate-api-spec.sh` - Validation script for OpenAPI, GraphQL, and Protobuf
- New anti-patterns: Inconsistent Naming, Missing Pagination, No Idempotency, Leaky Abstractions, Missing CORS
- Expanded quality checklist with 12 items
- Version number in frontmatter

### Removed
- Inline code examples (now in references/)
- Redundant capability descriptions

## [1.0.0] - 2024-12-10

### Added
- Initial release
- REST API design patterns
- GraphQL schema design
- gRPC service definitions
- API security patterns
- Rate limiting design
- Developer experience guidelines
