# Changelog

All notable changes to the `agent-tool-builder` skill.

## [1.0.0] — 2026-07-10

Initial release.

### Added
- Read-surface / control-surface boundary as the skill's spine: rewrite the read-surface, flag control-surface smells without changing them (`flag, don't re-architect`).
- 7-step design/harden procedure; exhaustiveness guards stated inline in the scoring steps.
- Three-part output contract: scored checklist · hardened read-surface · control-surface flags (kept structurally separate).
- `references/read-surface-checklist.md` — the 8 checks, each traced to Anthropic's *Writing effective tools for AI agents*.
- `examples/search-vs-list.before-after.md` — a two-tool set-mode harden showing both flag-don't-re-architect moments.
- `examples/sample-scored-output.md` — the three-part output contract on a single-tool repair run.
- `examples/design-from-scratch.md` — designing a new tool's read-surface from a plain-English ask (the design path, single-tool).
