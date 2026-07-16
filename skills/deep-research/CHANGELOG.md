# deep-research changelog

## [2026-07-02] - native default, no API key

Rewrote the SKILL so its default, supported method is Claude's built-in web search: plan, search, read multiple sources, synthesise a cited report. No Python, no GEMINI_API_KEY, and no bundled script required. The upstream `research.py` was never shipped with this kit, so the previous Python-only instructions could not run at all. The Gemini/Python batch mode is retained as a clearly-optional, bring-your-own advanced section. This fixes the first-run first-win path, which routed a cold non-technical owner here and hit a missing-script / missing-key wall on their very first prompt.

## [Unreleased] - 2026-05-23

Pass 1 Promising to Production upgrade pass. Adds a worked transcript + version history so an outsider can verify the SKILL works end-to-end without invoking it live.

### Added

- `examples/deep-research-session.md` worked transcript.
- SKILL.md "Bundled artifacts" pointer at the top.

### Not touched

- The SKILL.md body and references unchanged.
