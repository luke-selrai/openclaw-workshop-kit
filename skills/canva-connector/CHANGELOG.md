# canva-connector changelog

All notable changes to this SKILL are documented here.

## [Unreleased] - 2026-05-23

Pass 1 Promising-to-Production upgrade pass. The vetter scored canva-connector 5/5/5/5/3 with evidence as the only weak dimension. This release closes the evidence gap with bundled artifacts and tightens two documentation rough edges.

### Added

- **`examples/canva-export-designs-session.md`** worked end-to-end transcript. Walks the full flow a non-technical owner runs: Phase 0 resume check, Phase 1 OAuth via Playwright with sign-in narration, Phase 2 multi-tool flow ("connect my Canva and export the last 5 designs as PNGs"). Real Claude output, real artifact references, plain-English narration. Lets an outsider verify the bridge-OAuth path and the export-tool chain in under 5 minutes from the repo alone.
- **`references/canva-mcp-shape-snapshot.json`** captured shape of `mcp.canva.com/.well-known/oauth-protected-resource` at the SKILL's empirical-verification timestamp. Paired text doc explains how to compare a future fetch against this snapshot manually if the consent screen scope-count changes. No automated script (stays out of test territory by design).

### Changed

- **SKILL.md Prompt-to-Tool Mapping** gained brand-kits and help-answers routing rows. A non-technical owner saying `"check my brand colours"` or `"show me the Canva help on backgrounds"` now hits the table at the top instead of having to scroll to the late-section reference.
- **SKILL.md transactional editing section** expanded with what "transaction in progress" actually means to the user (one transaction owns the design's edit lock; nobody else, including the user in the Canva UI, can save changes until the transaction commits or cancels), what happens on partial failure (the SKILL calls `cancel-editing-transaction` automatically so the lock releases), and explicit rollback semantics (cancelling discards every operation applied in the open transaction; there is no per-operation undo).

### Not touched

- The full 6-step Phase 1 install flow is unchanged.
- All Phase 2 tool reference entries, error-handling table, and rate-limit numbers are unchanged.
- The OAuth bridge / proxy explanation in "How auth works under the hood" is unchanged.
