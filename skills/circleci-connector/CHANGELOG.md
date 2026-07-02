# circleci-connector changelog

## [Unreleased] - 2026-05-23

Pass 1 Promising to Production upgrade pass. Vetter scored 5/4/5/5/3 with evidence as the blocker.

### Added

- `examples/circleci-failed-builds-session.md` worked end-to-end transcript covering cold start (token paste + chat restart), warm start, and the multi-project failure summary that is the kit's core value.
- `references/circleci-mcp-shape-snapshot.json` captured shape of the CircleCI MCP server at the SKILL's empirical-verification timestamp. Drift-check recipe included.

### Changed

- SKILL.md "Bundled artifacts" pointer added at the top.

### Not touched

- All Phase 1 install steps and Phase 2 tool reference unchanged.
- Parent claude-workshop-kit repo and its sibling skills unchanged.
- No tests/, scripts/, or .github/workflows/ files touched.
