# calendly-connector changelog

All notable changes to this SKILL are documented here.

## [0.2.0] - 2026-09-02

**Native-first (CORE-395).** Calendly is in Claude's own connector directory, so
the built-in connector is now the default route and the kit's Playwright install
is the fallback. Both routes reach the same `https://mcp.calendly.com` server, so
this is a shorter path to the same tools - one button press, no local
registration, and it works on any Calendly plan including free.

### Added

- **SKILL.md Phase 0 - "Is Calendly already connected?"** Replaces the old
  pre-flight resume check. Checks `claude mcp list` for a `claude.ai Calendly`
  line first (`✔ Connected` → Phase 2 after a real read; `! Needs authentication`
  → the Reconnect path on `claude.ai/customize/connectors`), then the existing
  `mcpServers.calendly` Node probe, then falls through to Phase 1. Notes the
  local-entry-takes-precedence rule and the no-shell branch for claude.ai chat
  and the desktop app.
- **SKILL.md Phase 1 - "Switch on the built-in Calendly connector".** Six steps:
  confirm the session can see built-in connectors (`claude auth status` →
  `"authMethod": "claude.ai"`, plus the `disableClaudeAiConnectors` and
  `ENABLE_CLAUDEAI_MCP_SERVERS` kill-switches), open
  `https://claude.ai/directory/calendly` in the user's own browser, wait, verify,
  prove with one read, hand off. Includes the Team/Enterprise **Request**-instead-
  of-**Connect** stop, and a note on why this route uses the user's own browser
  when Phase 1-alt uses its own window.

### Changed

- **The old Phase 1 is now `PHASE 1-alt, Install & Auth`**, with a short
  when-to-use paragraph: the session can't see built-in connectors, the listing
  is missing, or the user wants the connection on their own computer. All six
  steps, the admin-restriction interstitial, the drift guard and the
  Claude Code minimum-version note are unchanged.
- **Frontmatter `description`** rewritten to the Template B two-route shape;
  `allowed-tools` gains `mcp__claude_ai_Calendly__*`.
- **Phase 2** opens with a namespace line: `mcp__claude_ai_Calendly__*` on the
  built-in connector, `mcp__calendly__*` on the kit's route, same
  `<category>-<action>` names on both.
- **"What this skill does NOT use"** - the claim that the Calendly directory
  entry is a Claude Desktop feature unavailable in Claude Code is corrected:
  directory connections are account-level and reach Claude Code when it is
  signed in with the same claude.ai account.
- **Prompt-to-Tool mapping and the error-handling table** route re-auth through
  Phase 0 rather than "walk Phase 1 from Step 3", since the fix differs by route.
- **Communication rules** retitled to cover both routes.

### Not touched

- The 35-tool reference, the category table, rate limits, scope limitations and
  Behaviour Guidelines are unchanged.
- `examples/` and `references/` are unchanged.

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
