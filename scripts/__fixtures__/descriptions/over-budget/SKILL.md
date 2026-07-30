---
name: over-budget
description: >-
  Connects the Acme accounting platform to Claude by installing its MCP server
  and completing the OAuth grant. Phase 0 checks whether the connection already
  exists by listing the session tools. Phase 1 installs the server with the
  documented add command and the vendor's hosted transport URL. Phase 2 runs the
  authenticate tool and waits for the browser grant to come back. Phase 3 lists
  the ledger accounts as a smoke test and reports the account name it found.
  Phase 4 writes the connection note into the project memory file so later
  sessions skip the install entirely.
---

# Over-budget fixture

Fixture for `scripts/test-description-budget.mjs`. The description narrates the
whole procedure and lands well over the 500-char budget, so the budget rule must
fire on it. It deliberately contains no first/second-person pronouns, so it
isolates the length rule from the person rule.
