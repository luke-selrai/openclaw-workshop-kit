# Case 03 — Technical doc, domain-term preservation

## Input

> This service is designed to be robust against partial network failures. It leverages a comprehensive set of retry policies with exponential backoff. The architecture serves as a foundation for downstream consumers that require seamless failover between regions.

## Must-flag

- leverages (Tier 1: leverage)
- comprehensive (Tier 1)
- serves as (copula avoidance)
- seamless (Tier 1)

## Must-NOT-flag (domain preservation)

- **robust** — in a reliability/networking doc, "robust" is the precise term of art for fault-tolerance. Preserve it.
- **failover** — domain term, not promotional.
- **exponential backoff** — domain term.

## Must-not-survive

leverages, comprehensive, serves as, seamless

## Reference rewrite

> This service is robust against partial network failures. It uses a set of retry policies with exponential backoff. The architecture is the foundation for downstream consumers that need failover between regions.

## Notes

This case exists to catch over-zealous replacement. A naive auditor will swap "robust" → "reliable" and degrade the doc's precision. The skill must preserve domain terminology when the flagged word is the precise term of art in context. If the rewrite replaces "robust" here, the eval fails.
