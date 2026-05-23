# calendly-connector changelog

All notable changes to this SKILL are documented here.

## [Unreleased] - 2026-05-23

Pass 1 Promising-to-Production upgrade pass. The vetter scored calendly-connector 5/5/5/5/3 with evidence as the only weak dimension. This release closes the evidence gap with bundled artifacts and tightens five smaller documentation rough edges.

### Added

- **`examples/calendly-meetings-list-session.md`** worked end-to-end transcript. Walks the autonomous flow a non-technical owner runs: Phase 0 resume check, Phase 1 six-step Playwright-driven install with sign-in narration, the success message, and a Phase 2 `meetings-list_events` call against the freshly connected account. Real Claude output, plain English narration, branches for the deferred-tool-reconciliation restart, the admin-restricted Enterprise interstitial, and the token-expiry re-auth path.
- **`references/calendly-mcp-shape-snapshot.json`** captured shape of `mcp.calendly.com/.well-known/oauth-protected-resource` at the SKILL's empirical-verification timestamp. Drift-check recipe included so an outsider can validate the SKILL's claims against the live MCP via a one-line curl without needing a smoke test harness.

### Changed

- **SKILL.md Phase 0 tooling check** now names the minimum Claude Code version required to expose the `mcp__calendly__authenticate` / `mcp__calendly__complete_authentication` runtime tool pair. If the user is on an older Claude Code build, Phase 1 Step 4b surfaces a plain-English version-upgrade prompt instead of silently failing.
- **SKILL.md tool-availability precondition** clarifies that the close-and-reopen ask is the only known supported recovery for the first-session deferred-tool-reconciliation gap as of Claude Code v2.1.140 (per the canonical Pattern 1 doc at [skills/CLAUDE.md](../CLAUDE.md)). No programmatic `/reload-mcp` exists. The phrasing is now an apology plus the action, not a blank request.
- **SKILL.md Phase 2 first-call tool-name-drift guard.** Before the first `mcp__calendly__*` call in any Phase 2 session, Claude lists the available `mcp__calendly__*` tools and confirms the canonical 35-tool surface is present. If a canonical name is missing, Claude surfaces a "Calendly may have renamed a tool, here is what I see" message rather than silently mis-routing the user's request. The check is in-SKILL guidance, not a smoke test.
- **SKILL.md scope-limitation list** softened. The webhooks-not-supported line no longer says "use Calendly REST API directly" (jargon for a non-technical owner). It now says: "This connector cannot set up webhooks. Calendly has a separate developer setup for that. Want me to walk you through it?"

### Not touched

- All 6 Phase 1 install steps unchanged.
- All Phase 2 tool reference entries, the 35-tool category table, error-handling table, and rate-limit numbers are unchanged.
- The OAuth bridge / proxy explanation in "How auth works under the hood" is unchanged.
- No tests, scripts, or workflow files touched. The new artifacts live entirely under `skills/calendly-connector/`.
