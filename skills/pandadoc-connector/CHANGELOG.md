# Changelog — pandadoc-connector

All notable changes to this skill, oldest at the bottom.

## [0.1.0] — 2026-06-05

Initial release. Pattern 1 hosted-OAuth connector for the official
first-party PandaDoc MCP server at `https://mcp.pandadoc.com/v1/mcp`.
**Live-smoked 2026-06-05 against rodolfo@selrai.com.au's PandaDoc** —
4 MAJOR + 1 MINOR + 1 NIT drifts captured and folded into the SKILL
before this release ships. See `examples/install-walkthrough.md`
*Drifts captured 2026-06-05* table for the complete drift list.

**Headline captured-smoke findings:**
- PandaDoc MCP is a **bridge / proxy OAuth server** (same architecture as
  Canva). Bridge client_id is `f88018a252b20dcb8987` — load-bearing.
- **Auto-grant on re-install** for users with a prior bridge grant
  (no consent screen on second install). SKILL Step 4 now races consent
  detection vs auto-grant callback.
- **RFC 7591 Dynamic Client Registration is public** — Claude Code's
  MCP runtime mints DCR clients freely, but consent is per-user-per-bridge.
- 4-hop redirect chain captured verbatim for SKILL Step 3 narration.

### Added

- `SKILL.md` — Phase 0 resume check (with claude.ai-Connectors-layer
  fallback, lesson learned from canva-connector v1.4.0 smoke), Phase 1
  6-step Playwright-driven OAuth install (mirror of the
  `linear-connector` / `canva-connector` Pattern 1 reference), Phase 2
  tool catalog covering ~50 first-party PandaDoc MCP operations across
  10 categories (document creation & templates, content management,
  status & lifecycle, signing & completion, search & filtering, bulk
  operations & reminders, analytics & reporting, webhooks & notifications,
  advanced operations, error handling & diagnostics).
- `examples/install-walkthrough.md` — partial captured reference,
  2026-06-05 (Phase 0 + Phase 1 Steps 1-2 + the bridge OAuth
  architecture captured live; full deferred-tool path and Phase 2
  contracts pending a follow-up smoke after chat restart). Includes
  per-step DOM fragments, timing table, worked Phase 2 multi-tool flow,
  and a 6-row *Drifts captured 2026-06-05* table at the bottom.
- `scripts/verify-well-known.sh` — re-runnable OAuth metadata shape
  check for `mcp.pandadoc.com/.well-known/oauth-protected-resource` and
  `oauth-authorization-server`. Exit 0 PASS / 1 soft drift / 2 hard
  drift. Tested live.
- `CHANGELOG.md` — this file.

### Why

PandaDoc was identified as a high-value workshop connector for the
sales-ops attendee persona — e-signature automation is a frequent
top-3 ask in workshop pre-surveys, and PandaDoc's published MCP
surface (~50 operations) is one of the broadest among the
hosted-OAuth-pattern MCPs the workshop kit ships.

Built using `canva-connector` v1.4.0 (the most recent Pattern 1
captured-smoke release) as the reference shape. The Phase 2 catalog
includes destructive-op confirmation gates appropriate to legal
documents (extra confirm-text-before-send for `send-document`,
`mark-documents-as-paid`, `decline-documents-with-notes`, and bulk
reminder sends).

Follow-up smoke targets (NOT verified live this session — would lift
Evidence further on a re-smoke from a fresh chat session):
- Exact `mcp__pandadoc__*` tool names (deferred tools not yet reconciled;
  Tool Reference categories enumerate capabilities, not tool IDs)
- Whether `user_intent` is mandatory per the Canva MCP precedent
- Plan-gating boundaries (Essentials / Business / Enterprise)
- Consent screen exact button text — auto-skipped on the captured run
  because Rodolfo had a prior bridge grant; needs a fresh-user capture
- Response shapes — could not verify without completed OAuth + tool calls
