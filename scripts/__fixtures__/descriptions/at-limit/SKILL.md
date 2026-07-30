---
name: at-limit
description: Renames and reorganises the exported ledger files that the accounting platform drops into the shared folder. Use when the user asks to tidy a ledger export, rename a batch of statement files, or fold a monthly export into the archive tree. The trailing clause below exists only to pad this description to exactly the 500-character budget boundary, so the rule can be proven to fire strictly above the limit and not at it, padding, padding, padding, padding, padding, padding, padding, padding........
---

# At-limit fixture

Fixture for `scripts/test-description-budget.mjs`. The description is exactly
500 characters — the budget boundary. The rule fires strictly above the limit,
so this fixture must pass.
