# Changelog

## [2.1.0] - 2026-05-23

Pass 1 Promising to Production upgrade pass. Vetter scored 5/5/4/4/3 with evidence as the blocker (no worked transcript bundled).

### Added

- `examples/competitive-mapping-session.md` worked end-to-end transcript. Walks the full 6-step process (Define Space, Identify Players, Analyse Positioning, Find White Space, Recommend Positioning, Stress-Test) against a real Selr AI engagement. Real positioning statement, real white-space gaps, real stress-test failure modes.
- SKILL.md "Bundled artifacts" pointer at the top so the example is discoverable.

### Not touched

- The 6-step process documentation, references, and scripts unchanged.
- `pairs-with` metadata unchanged (the vetter noted `design-archivist` and `vibe-matcher` mismatch but those are separate-PR territory).
- No tests/ or scripts/ files touched.

## [2.0.0] - 2026-03-17

### Changed
- **SKILL.md restructured** for progressive disclosure (407 → ~125 lines)
- TypeScript interfaces and examples extracted to reference files

### Added
- `references/mapping-process.md` - Detailed 6-step methodology, CompetitorProfile/CompetitiveMap interfaces, dimension pairs
- `references/domain-positioning.md` - Portfolio, SaaS, consulting-specific positioning strategies with example maps
- `references/troubleshooting.md` - Common issues (no white space, user resists differentiation), validation methods
- 6-step process summary table
- Types of white space (intersection, under-served audience, contrarian)

### Migration Guide
- No changes to frontmatter or activation triggers
- Full example competitive maps now in domain-positioning.md
- Troubleshooting guide provides solutions to common blockers
