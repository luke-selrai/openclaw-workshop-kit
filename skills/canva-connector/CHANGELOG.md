# Changelog - canva-connector

All notable changes to this skill, oldest at the bottom. Pulled from the
commits listed under `git log -- skills/canva-connector/` and from the
sibling-PRs that touched the connector via cross-cutting refactors.

## [1.4.0] - 2026-06-05

Live-smoke release combining the Promotion-prep evidence pack with
**7 MAJOR + 2 MINOR + 2 NIT drift fixes** captured from a 2026-06-05 live
smoke against rodolfo@selrai.com.au's Canva account. Ships as one release;
the projected-vs-captured story is preserved in `examples/install-walkthrough.md`'s
*Drifts captured 2026-06-05* (11-row) table.

### Added (captured-smoke fixes)

- SKILL.md Phase 0.1: secondary REGISTERED check via `claude mcp list |
  grep -iE 'canva.*Connected'`. Closes the claude.ai-Connectors-layer
  blind spot found on Rodolfo's box (he had Canva connected via the
  claude.ai web UI, which doesn't write into `~/.claude.json mcpServers`).
- SKILL.md Tool Reference: 4 new tool rows for `copy-design`,
  `create-design-from-brand-template`, `merge-designs`, `resolve-shortlink`.
  All present on the live `mcp.canva.com/mcp` surface; previously absent
  from the Tool Reference.
- SKILL.md Behaviour Guidelines: hard requirement that every Canva tool
  call passes a `user_intent: string` parameter. Captured from every
  loaded `mcp__canva__*` JSON schema; server-side framing requirement.
- SKILL.md Brand kits: new sub-section under "Brand kits (all plans)"
  documenting `list-brand-kits` as plan-agnostic. Previously listed under
  "Enterprise only" - live smoke on Rodolfo's non-Enterprise account
  returned `{ items: [] }` (success, empty) confirming the misclassification.
- SKILL.md Plan-gating row updates: "Enterprise only" row drops
  `list-brand-kits`; remaining Enterprise gating is just the three
  brand-template-autofill tools.

### Changed (captured-smoke corrections)

- SKILL.md Tool name fix: `get-design-export-formats` →
  `get-export-formats` everywhere. The shorter name is the live tool name
  on `mcp.canva.com/mcp`; the longer name was never valid. Calls using
  the documented name would return "tool not found."
- SKILL.md tool count: Overview, Phase 2 intro, and Scope Limitations
  bumped from 31 → 37 (34 plan-agnostic + 3 Enterprise-gated). The 31
  figure from the original 1.3.0 draft under-counted the Tool Reference
  itself (33 rows after recount) AND missed the 4 captured tools.
- examples/install-walkthrough.md status: "projected reference run" →
  "partial captured reference, 2026-06-05 against
  rodolfo@selrai.com.au's Canva account (non-Enterprise)". Phase 0 +
  Phase 1 Steps 1-2 + all Phase 2 contracts captured live; Phase 1
  Steps 3-6 remain SKILL-projected because the runtime's deferred-tool
  reconciliation requires a chat restart per the SKILL's documented
  Tool-availability precondition.
- examples/install-walkthrough.md Phase 2 samples: `search-designs`
  response shape (`items[] + continuation`, not `designs[] + page_count`),
  `get-export-formats` response shape (`{ formats: {...} }`, not array),
  `help` response shape (async-job `{ job: { result: { answer } } }`,
  not list of snippets), `list-brand-kits` branches (no longer
  Enterprise-only), all design IDs (11-char shape, not 4-char placeholder).
- examples/install-walkthrough.md adds an 11-row *Drifts captured
  2026-06-05* table at the bottom anchoring each fix to its SKILL.md edit.

### Promotion-prep additions (originally drafted as 1.3.0)

- `examples/install-walkthrough.md` - see above for current captured state.
- `scripts/verify-well-known.sh` - re-runnable shape check for
  `mcp.canva.com/.well-known/oauth-protected-resource` and
  `oauth-authorization-server`. Exit 0 PASS / 1 soft drift / 2 hard drift.
  Tested live - both required endpoints return the expected shape; OpenID
  discovery returns 404 (soft drift, expected).
- `CHANGELOG.md` - this file.
- SKILL.md prompt-to-tool mapping rows for *"check my brand colours"*,
  *"show me the Canva help on X"*, *"resolve this canva.link/X"*,
  *"copy this design"*, *"merge these designs"*, *"start from this brand
  template"*.
- SKILL.md Tool Reference Help row + Help sub-section.

### Why

The 2026-05-21 Pass 1 vetting scored canva-connector 5/5/5/5/3 - Evidence
was the lone Promising-blocker. The 1.3.0 draft (PR #338) closed the
Evidence gaps using projected artifacts. The 2026-06-05 live smoke
verified the OAuth-bootstrap path empirically and surfaced 11 drifts in
the SKILL itself - three of which (tool name, missing `user_intent`,
plan-gating misclassification) would have broken real workshop installs.
Closing them with captured fixes lifts the SKILL from "projected"
Evidence ≥4 → "captured" Evidence 5.

## [1.2.0] - 2026-04-30

Centralised the three connector install patterns into a single reference at
`skills/CLAUDE.md` and adjusted the canva-connector SKILL to reference it
rather than re-derive Pattern 1 inline (closes #199, PR #221).

### Changed

- SKILL.md header now points to `skills/CLAUDE.md` for the canonical
  Hosted-OAuth pattern. The bridge-OAuth specifics, Enterprise admin-block
  detection, and the consent-screen-surprise note remain in this SKILL -
  they are vendor-specific, not pattern-general.

## [1.1.0] - 2026-04-22

Anti-pattern guard: removed the deprecated `claude mcp authenticate` CLI
claim and the `WWW-Authenticate: Bearer` auth-discovery dance the original
SKILL inherited from pre-#198 connector templates. Audit-skills CI block
landed in PR #212 (closes #200).

### Changed

- Phase 1 Step 3 narration no longer references a non-existent `claude mcp
  authenticate` subcommand. The supported programmatic OAuth-bootstrap path
  is the runtime-exposed `mcp__canva__authenticate` /
  `mcp__canva__complete_authentication` tool pair.

## [1.0.0] - 2026-04-15

Refactor: adopt the `mcp__<server>__authenticate` /
`mcp__<server>__complete_authentication` runtime-exposed OAuth-bootstrap
tool pair for Phase 1 Step 3, replacing the earlier well-known-document
sniffing approach (PR #208, closes #198).

### Changed

- Phase 1 Step 3 mints the OAuth URL via `mcp__canva__authenticate()` and
  submits the captured callback via `mcp__canva__complete_authentication`.
  This is the pattern shared with the other four Pattern 1 connectors
  (atlassian, calendly, jotform, linear).

## [0.2.0] - 2026-04-08

Phase 1 made autonomous via Playwright (per issue #172). Sign-in is the
only user-side action; Allow click and callback capture are automatic.

### Added

- Phase 1 Steps 1-6 with Playwright-driven consent flow.
- Step 4a scope-summary narration (3-5 representative items in plain
  English).
- Step 5 Enterprise admin-block interstitial detection - surfaces a clean
  exit on `administrator approval required` markers and explicitly
  documents that no API-key fallback exists for Canva MCP.

## [0.1.0] - 2026-03-XX

Initial skill (PR #141) - Canva connector via the official first-party
Canva MCP server at `https://mcp.canva.com/mcp`. Originally 30 tools across
10 categories: designs, assets, folders, comments, exports, AI design
generation, transactional editing, brand templates, brand kits, and
help-answers. (The `help` tool became a documented Tool Reference row in
1.3.0; the 30 → 31 count update lands then too.)
