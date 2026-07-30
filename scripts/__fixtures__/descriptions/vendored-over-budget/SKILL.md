---
name: vendored-over-budget
description: >-
  Builds Acme Framework applications with the upstream vendor's own recommended
  project layout, router conventions and data-loading primitives. Phase 0 detects
  which major version the workspace is on by reading the lockfile. Phase 1
  scaffolds the route tree and the shared layout module. Phase 2 wires the data
  loaders, including the streaming and deferred variants. Phase 3 configures the
  bundler targets for both the server and the browser build. Phase 4 sets up the
  production adapter and prints the deploy command for the detected host.
---

# Vendored over-budget fixture

Fixture for `scripts/test-description-budget.mjs`. Identical in kind to the
`over-budget` fixture — an over-length description with no pronouns — but this
one is pinned by `scripts/__fixtures__/descriptions-lock.json`, so it must be
partitioned into the *exempt* bucket rather than the failing one.

It exists so the lock-pinned exemption is proved on a fixture rather than only
against the real `skills-lock.json`, which is not the audit tool's to change.
