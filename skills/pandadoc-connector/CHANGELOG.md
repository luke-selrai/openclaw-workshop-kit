# Changelog - pandadoc-connector

All notable changes to this skill, oldest at the bottom.

## [0.3.0] - 2026-09-02

**Native-first (CORE-395).** PandaDoc is in Claude's own connector directory, so
the built-in connector is now the default route and the kit's Playwright install
is the fallback. Both reach the same `https://mcp.pandadoc.com/v1/mcp` server and
the same 22 tools; the built-in is one button press with nothing registered on
the user's computer. The one real exception is carried through the whole file:
**EU-hosted accounts (`app.pandadoc.eu`) are excluded from the directory** and
must use the kit's route or a hand-added custom connection.

### Added

- **SKILL.md Phase 0 - "Is PandaDoc already connected?"** Replaces the old
  pre-flight resume check and absorbs the claude.ai-layer probe that used to sit
  under `0.1`. Checks `claude mcp list` for `claude.ai PandaDoc` first
  (`✔ Connected` → Phase 2 after a real read; `! Needs authentication` → the
  Reconnect path), then the `mcpServers.pandadoc` Node probe, then Phase 1. Notes
  the local-entry-takes-precedence rule and the no-shell branch.
- **SKILL.md Phase 1 - "Switch on the built-in PandaDoc connector".** Six steps:
  confirm the session can see built-in connectors (`claude auth status` →
  `"authMethod": "claude.ai"`, plus the two kill-switches), open
  `https://claude.ai/directory/pandadoc` in the user's own browser, wait, verify,
  prove with a one-document read, hand off. Carries the no-`user_intent` rule into
  the smoke call, and the Team/Enterprise **Request**-instead-of-**Connect** stop.
- **EU-account routing**, stated three times where it bites: the overview, a
  callout at the head of Phase 1, and the Scope Limitations list.

### Changed

- **The old Phase 1 is now `PHASE 1-alt, Install & Auth`**, with a short
  when-to-use paragraph headed by the EU case. All six steps, the four-hop bridge
  capture, the auto-grant race, the two-button consent flow, the admin/SSO
  interstitial detection and the revoke note are unchanged.
- **Frontmatter `description`** rewritten to the Template B two-route shape;
  `allowed-tools` gains `mcp__claude_ai_PandaDoc__*`.
- **Phase 2** opens with a namespace line: `mcp__claude_ai_PandaDoc__*` on the
  built-in connector, `mcp__pandadoc__*` on the kit's route, same
  `namespace_object_verb` names on both, same `user_intent` prohibition.
- **Prompt-to-Tool mapping and the error-handling table** route re-auth through
  Phase 0 rather than "walk Phase 1 from Step 3", since the fix differs by route.
- **Communication rules** retitled to cover both routes.

### Not touched

- The 22-tool reference, status codes, response shapes, confirmation gates and
  Behaviour Guidelines are unchanged.
- `examples/` and `scripts/` are unchanged.

## [0.2.0] - 2026-06-05

**Phase 2 verified live (follow-up smoke from a fresh chat session).** The 0.1.0
Tool Reference was written from PandaDoc's published capability brochure, not from
live tool enumeration - the deferred-tool pair hadn't reconciled at release time.
A follow-up smoke completed the OAuth flow (auto-granted via the prior bridge
consent), let the runtime reconcile the `mcp__pandadoc__*` surface in-session,
enumerated **all 22 tools**, inspected every schema, and ran read smokes
(`documents_list`, `templates_list` → both `200 OK`). The connector works
end-to-end; the Phase 2 docs drifted hard from the live surface.

**7 MAJOR + 4 MINOR + 2 NIT drifts** captured (Round 2); see
`examples/install-walkthrough.md` *Drifts captured 2026-06-05 → Round 2* for the
full table.

### Changed

- **Tool surface corrected: 22 tools across 3 namespaces**, NOT "~50 operations
  across 10 categories". `documents_*` (15), `recipients_*` (4), `templates_*` (3).
  SKILL Overview, Phase 2 intro, and the entire Tool Reference rewritten to the 22
  verified tools with real params and confirmation gates.
- **`user_intent` guidance reversed (was breaking).** PandaDoc tools do NOT accept
  `user_intent`; every schema is `additionalProperties: false`, so the 0.1.0
  instruction to "pass user_intent on every call" (Canva precedent) would make
  every call fail validation. Removed from the Tool Reference note, Step 6, and
  Behaviour Guidelines; replaced with explicit "never pass it" guidance.
- **Tool naming corrected** to `namespace_object_verb` snake_case
  (`documents_list`, `templates_details_get`) - the 0.1.0 Prompt-to-Tool Mapping
  used non-existent kebab names (`list-documents`, `send-document`). Mapping fully
  rewritten with real tool names.
- **Status codes documented** - added the integer status-code table (0-13) used by
  `documents_list` / `documents_search` / `documents_status_change`, incl. the
  code-11 `voided`-vs-`expired` server inconsistency.
- mark-paid / decline / expire / complete consolidated to the single real tool
  `documents_status_change` (status codes 2/10/11/12), not 4 separate ops.
- `recipients_reassign` clarified as a **signer** swap (not a sender/ownership
  transfer - that's `documents_send.sender` / `documents_create.owner`).
- OAuth architecture note corrected: the runtime uses the
  **client-id-metadata-document** flow (`client_id=https://claude.ai/oauth/claude-code-client-metadata`),
  not DCR as 0.1.0 inferred. Step 3 + the Overview captured-note updated; auto-grant
  confirmed live (consent page → straight to localhost callback, no buttons).
- `examples/install-walkthrough.md` promoted from *partial captured* to *fully
  captured*; Phase 2 sample flows rewritten with real tool names; the bulk-reminder
  flow replaced with an honest find-and-report flow.

### Added

- SKILL "What the server does NOT expose as tools" section + Scope Limitations
  entries: **no reminder tool, no webhook tools, no signed-PDF download, no
  file-upload doc creation, no embedded session-URL tools** (all verified absent).
- SKILL "Response shapes (captured live 2026-06-05)" subsection + walkthrough
  capture block, from a recipient-less throwaway draft (created via
  `documents_create_from_markdown`, read, then archived - zero residue). Documents
  the `documents_search` richer envelope (`total`/`has_next_page`/`scope`), the
  `documents_details_get` field set, the async `document.uploaded`→poll create
  flow, the `{retry_after:N}` envelope for content/summary/metadata, and the
  account-currency caveat (`grand_total.currency`, e.g. `PHP`).

### Not verified

- Plan-gating boundaries (no `403 plan_required` observed), fresh-new-user consent
  button text (auto-granted again), rendered `documents_content_get` success body
  (still rendering at archive time). Destructive tools needing recipients or a
  sent/live document (`documents_send`, `documents_create` from template,
  `documents_update`, `documents_fields_assign`, `documents_status_change`,
  `recipients_*`) had schemas inspected but were not invoked.

## [0.1.0] - 2026-06-05

Initial release. Pattern 1 hosted-OAuth connector for the official
first-party PandaDoc MCP server at `https://mcp.pandadoc.com/v1/mcp`.
**Live-smoked 2026-06-05 against rodolfo@selrai.com.au's PandaDoc** -
4 MAJOR + 1 MINOR + 1 NIT drifts captured and folded into the SKILL
before this release ships. See `examples/install-walkthrough.md`
*Drifts captured 2026-06-05* table for the complete drift list.

**Headline captured-smoke findings:**
- PandaDoc MCP is a **bridge / proxy OAuth server** (same architecture as
  Canva). Bridge client_id is `f88018a252b20dcb8987` - load-bearing.
- **Auto-grant on re-install** for users with a prior bridge grant
  (no consent screen on second install). SKILL Step 4 now races consent
  detection vs auto-grant callback.
- **RFC 7591 Dynamic Client Registration is public** - Claude Code's
  MCP runtime mints DCR clients freely, but consent is per-user-per-bridge.
- 4-hop redirect chain captured verbatim for SKILL Step 3 narration.

### Added

- `SKILL.md` - Phase 0 resume check (with claude.ai-Connectors-layer
  fallback, lesson learned from canva-connector v1.4.0 smoke), Phase 1
  6-step Playwright-driven OAuth install (mirror of the
  `linear-connector` / `canva-connector` Pattern 1 reference), Phase 2
  tool catalog covering ~50 first-party PandaDoc MCP operations across
  10 categories (document creation & templates, content management,
  status & lifecycle, signing & completion, search & filtering, bulk
  operations & reminders, analytics & reporting, webhooks & notifications,
  advanced operations, error handling & diagnostics).
- `examples/install-walkthrough.md` - partial captured reference,
  2026-06-05 (Phase 0 + Phase 1 Steps 1-2 + the bridge OAuth
  architecture captured live; full deferred-tool path and Phase 2
  contracts pending a follow-up smoke after chat restart). Includes
  per-step DOM fragments, timing table, worked Phase 2 multi-tool flow,
  and a 6-row *Drifts captured 2026-06-05* table at the bottom.
- `scripts/verify-well-known.sh` - re-runnable OAuth metadata shape
  check for `mcp.pandadoc.com/.well-known/oauth-protected-resource` and
  `oauth-authorization-server`. Exit 0 PASS / 1 soft drift / 2 hard
  drift. Tested live.
- `CHANGELOG.md` - this file.

### Why

PandaDoc was identified as a high-value workshop connector for the
sales-ops attendee persona - e-signature automation is a frequent
top-3 ask in workshop pre-surveys, and PandaDoc's published MCP
surface (~50 operations) is one of the broadest among the
hosted-OAuth-pattern MCPs the workshop kit ships.

Built using `canva-connector` v1.4.0 (the most recent Pattern 1
captured-smoke release) as the reference shape. The Phase 2 catalog
includes destructive-op confirmation gates appropriate to legal
documents (extra confirm-text-before-send for `send-document`,
`mark-documents-as-paid`, `decline-documents-with-notes`, and bulk
reminder sends).

Follow-up smoke targets (NOT verified live this session - would lift
Evidence further on a re-smoke from a fresh chat session):
- Exact `mcp__pandadoc__*` tool names (deferred tools not yet reconciled;
  Tool Reference categories enumerate capabilities, not tool IDs)
- Whether `user_intent` is mandatory per the Canva MCP precedent
- Plan-gating boundaries (Essentials / Business / Enterprise)
- Consent screen exact button text - auto-skipped on the captured run
  because Rodolfo had a prior bridge grant; needs a fresh-user capture
- Response shapes - could not verify without completed OAuth + tool calls
