# circleci-connector changelog

## [Unreleased] - 2026-09-07

- Prefer the calling account's official connector, with documented hosted sign-in and PAT fallback; preserve working legacy local access.
- Verify actual caller reads and tool schemas, separating Desktop identity from terminal configuration.
- Replace inconsistent counts and absent-tool recipes with offline discovery from legacy npm 0.20.0. The bundled example is illustrative, not live-access evidence.

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
