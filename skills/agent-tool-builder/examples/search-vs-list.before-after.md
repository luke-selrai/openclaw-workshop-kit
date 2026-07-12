# Worked example — `search_tickets` vs `list_tickets`

A two-tool set-mode harden. Synthetic support-ticket domain; every value here is invented. Demonstrates the read-surface rewrite **and** the two flag-don't-re-architect moments where the boundary holds.

## Before (verbatim schemas)

**`search_tickets`** — *"Search tickets by free text across subject, ticket ID, and requester. Use this to find a specific ticket."*
- `query` — required, "Text to search for"
- `limit` — default **25**

**`list_tickets`** — *"List support tickets, optionally filtered by status. Status values: open, pending, on hold, closed-won. Returns subject, requester, the three SLA statuses, and dates."*
- `status` — enum
- `limit` — default **50**

## Scored checklist

| # | Check | search_tickets | list_tickets |
|---|---|---|---|
| 1 | Name | pass | pass |
| 2 | Boundary | **fail** — never mentions `list_tickets` | **fail** — never mentions `search_tickets` |
| 3 | Explicit context | pass | **fail** — "the three SLA statuses" undefined; reader must guess |
| 4 | Params | **fail** — `limit` defaults 25 vs sibling's 50 (same concept, inconsistent) | **fail** — same default mismatch |
| 5 | Examples | **fail** — free-text `query` has no example | pass |
| 6 | Return contract | **fail** — return shape undocumented | pass |
| 7 | Errors | not declared → **fail** (ask for a sample error payload) | not declared → **fail** |
| 8 | Distinguishability | **fail** — neither description references the other; model can't choose | **fail** |

Extra defect surfaced across both: **terminology drift** — "tickets / ticket / support tickets" name the same entity three ways (check 3).

## Two flag-don't-re-architect moments

1. **Merge into one `find_tickets(query?, status?)`?** That collapses two tools into one — a capability-split decision on the **control-surface**. → **Flag only.**
2. **The enum inconsistency `on hold` (space) vs `closed-won` (hyphen).** Those strings are the *actual accepted values* the API matches on; renaming them changes the contract, not the read-surface. → **Gloss them in the description, flag the inconsistency — do not rewrite the values.**

## After (read-surface rewrite only)

**`search_tickets`** — *"Find specific tickets when you already know a term — matches free text against subject, ticket ID, or requester. Returns the same fields as `list_tickets`. Use when you have a subject/ID/requester; use `list_tickets` to browse by status instead. Example `query`: `\"login page 500\"`, `\"T-10432\"`, `\"acme.com\"`."*
- `query` — required. Free text; matches subject, ticket ID, or requester.
- `limit` — default **50** (aligned with `list_tickets`).

**`list_tickets`** — *"Browse tickets by stage when you have no search term. Returns subject, requester, the three SLA statuses (first-response · next-update · resolution), and key dates. Use to scan a stage; use `search_tickets` when you know a subject/ID/requester."*
- `status` — enum. `open` (unassigned), `pending` (awaiting requester), `on hold` (blocked), `closed-won` (resolved). *Values kept verbatim — see flag #2.*
- `limit` — default **50**.

## Control-surface flags — NOT changed, your call

1. **Merge candidate** — `search_tickets` and `list_tickets` could become one `find_tickets(query?, status?)`. Read-surface disambiguation (above) is enough for now; consolidation is your architecture call.
2. **Enum naming** — `on hold` (space) is inconsistent with the hyphenated `closed-won`. Left verbatim because these are the accepted values; rename only in a coordinated API change.
