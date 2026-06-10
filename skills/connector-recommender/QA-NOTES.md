# Connector Recommender — QA Notes

Live autonomous QA run via [skill-qa-harness](https://github.com/selrai-company/skill-qa-harness)
(Claude Agent SDK, persona = non-technical small-business owner). Single-scenario
runs; no Playwright (this skill drives no browser).

## Run 1 — 2026-06-10 (pre-fix)

- **Scenario:** Ecommerce, stated pain point. Opening: *"I run an online store
  selling custom t-shirts with 5 staff. I'm drowning in customer refund emails.
  What tools should I set up?"*
- **Session:** model `claude-opus-4-7[1m]`. MCP servers present: Notion, Canva,
  Google Drive. **`mcp__mcp-registry__*` tools were NOT present** — the registry
  is not loaded in every session.
- **Verdict:** ABORTED — HIGH-severity anti-pattern.

### What passed
- Recommendation turn was excellent: detected ecommerce, ranked **Gmail #1
  because it solved the stated pain** (refund emails) ahead of the platform tool,
  3 Core + synergy hint + one gated next step, plain English, no jargon.

### Bug found (HIGH)
When the user accepted setup, the registry's `suggest_connectors` tool was
absent, so the model **improvised an install path that exists nowhere in
SKILL.md**:
- Turn 6: *"Gmail needs a small helper tool on your computer… I'm going to
  quickly check if it's already installed."* → ran `Bash: node --version`.
- Turn 8: *"Great news — the helper tool is already on your computer… 1. I'll run
  a quick setup command 2. A Google sign-in window will pop up…"*

This violates the skill's own premise (it installs nothing; connecting is a UI
action) and would strand or mislead a non-technical user into a terminal/Node
install flow. Note: the `allowed-tools` frontmatter whitelist did **not** prevent
the `Bash` call under the SDK harness — prose guardrails were required.

## Fix applied

- **Golden Rules** block added at the top of SKILL.md: installs nothing; never
  run terminal/shell commands; never tell a non-technical user to install
  software; if expected MCP tools are absent, follow the explicit fallbacks
  instead of improvising; never invent a setup mechanism.
- **Step 2** — added a "registry tool not available" branch: recommend from the
  built-in maps, skip unconfirmable `(verify)` connectors, don't claim to have
  "checked," never run a command to compensate.
- **Step 5b-alt** — added a "`suggest_connectors` not available" branch: hand off
  to Claude's connectors UI in plain English, one at a time, gating on the
  user's "done." Explicitly forbids terminal commands / "helper tool" / "popup
  after a command" framing.
- **EXAMPLES.md** — added Example 5 documenting the correct degradation output
  and the forbidden output, as a regression anchor.

## Run 2 — 2026-06-10 (post-fix)

- Same scenario, same registry-absent session.
- **Recommendation turn:** still correct (Gmail #1 for the pain point, Core +
  Growth, gated next step).
- **Setup turn (the regression check):** `num_turns=1`, **no tool calls** — no
  `Bash`, no `node --version`, no "helper tool", no "setup command". Output
  routed the user to the connectors UI in plain words:
  > "Look for the plug or settings icon… open the connectors menu… find Gmail
  > and click Connect… a Google sign-in page will open in your browser… Tell me
  > once you see 'Connected'."
- **Verdict:** PASS. Bug resolved; matches EXAMPLES.md Example 5.

### Minor observations (not blockers)
- The connect hand-off lists 4 numbered sub-steps in one message. These are
  sub-steps of a single UI action and the turn gates at the end on "tell me once
  connected," so it reads fine for a non-technical user. Watch it if it grows.

## Known limitations / coverage
- One scenario per run (the harness's design). Ecommerce happy-path + the
  registry-absent setup branch are covered. Other verticals and TC-09 (declines),
  TC-14 (negative/no-trigger), TC-15 (wants-everything) are asserted in
  TESTCASES.md but not yet exercised live — run them with the same harness command
  if regressing.
- When the registry IS present, the Connect-button path (`suggest_connectors`)
  was not exercised here because the test session lacked the registry MCP. That
  path is unchanged from the original skill.
