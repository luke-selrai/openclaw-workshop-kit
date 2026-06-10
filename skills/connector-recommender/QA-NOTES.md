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

## Root cause (corrected framing)

The bug was **not** "Claude ran a command." Many connectors genuinely require
Claude to install a CLI binary and register a server — there often is no simple
Connect button, and we shouldn't pretend there is. The two real defects were:

1. **Fabrication** — the "helper tool" / "quick setup command" / "popup will
   appear" narrative was ungrounded; `node --version` proves nothing about
   connecting Gmail, and no popup was actually wired up.
2. **Wrong division of labour** — it was drifting toward making the *user* own
   the technical steps instead of Claude doing them.

The correct behaviour: **Claude drives the whole technical install itself**,
grounded in a real path (the dedicated `*-connector` skill or the connector's
documented install pattern), pausing the user only for the OAuth sign-in and
hard physical actions.

## Fix applied

- **Golden Rules** rewritten: *you do the work, the user does not*. Claude drives
  CLI installs / server registration / browser login end-to-end; the user only
  approves OAuth and does physical actions; never hand the user a technical step;
  don't sugarcoat that some connectors need real setup; ground every step in a
  real install path (prefer the dedicated `*-connector` skill) and never
  fabricate one.
- **Frontmatter** — `allowed-tools` widened to include `Bash` and `Skill` (Claude
  needs them to run installs and invoke the dedicated connector skills); `risk`
  note updated to reflect end-to-end install orchestration.
- **Step 2** — registry-tool-absent branch clarified: it changes how connectors
  are *discovered*, not whether *Claude* does the setup.
- **Step 5b** — now four explicit cases: already-connected, one-click hosted
  (real Connect button), needs-technical-setup (Claude drives it via the
  dedicated skill / install pattern), and genuinely-unavailable.
- **Step 5b-alt** — "can't summon a Connect button" no longer means "punt to the
  user": for hosted connectors the single OAuth click is the irreducible user
  action; for CLI connectors Claude drives the install. Still forbids fabricated
  "helper tool" / fake "setup command" / phantom popup.
- **EXAMPLES.md** — Example 5 rewritten around a CLI connector (Linear): the
  correct output is Claude driving the install via `linear-connector` and pausing
  only for sign-in; two forbidden outputs captured (punting to the user;
  fabricating an ungrounded flow).

## Run 2 — 2026-06-10 (verified the fabrication was gone)

- Same scenario, same registry-absent session.
- **Recommendation turn:** correct (Gmail #1 for the pain point, Core + Growth,
  gated next step).
- **Setup turn:** `num_turns=1`, **no tool calls** — no `Bash`, no
  `node --version`, no "helper tool", no fabricated "setup command". The
  fabrication defect (#1 above) was gone.
- **Caveat:** this run was against the *interim* version that routed the user to
  the connectors menu. That's correct for Gmail (a genuine one-click hosted
  connector) but the broader guidance was then corrected to "Claude drives the
  install" for CLI connectors. See Run 3 for the corrected-behaviour check.
- **Verdict:** Fabrication bug resolved.

## Run 3 — 2026-06-10 (corrected Case-3/Case-4 behaviour)

- **Scenario:** CLI-style connector. Opening: *"I run a small software startup
  with a few engineers. Can you connect Linear so I can track our issues and
  sprints?"*
- **Session:** model `claude-opus-4-7[1m]`. No `mcp-registry`, no Linear
  connector, no dedicated `linear-connector` skill, `--no-playwright`. This is the
  realistic shipped state — see "Repo reality" below.
- **Turn 3 (bare model, before the skill loaded):** *"I will set up Linear for you
  now. A browser window will open asking you to sign in…"* — right ownership
  ("I will set up… for you"), but over-promised a popup before grounding it.
- **Turn 5:** invoked the `connector-recommender` skill (Skill tool).
- **Turn 7 (skill-grounded — the key result):**
  > "Quick honesty check — Linear isn't available as a direct connector I can plug
  > in for you right now. But… you already have Notion connected. I can build you
  > a proper issue tracker and sprint board there — same job, just in Notion.
  > Want me to set that up?"
  No fabrication (no "helper tool", no fake command, **no phantom popup**), no
  punting technical steps to the user. Honest about the limit (Golden Rule 5),
  and grounded the alternative in a connector that's *actually present* (Notion),
  offering to do real work. This is exactly Case 4 / Golden Rule 5.
- **Verdict:** PASS for the corrected behaviour. The original fabrication failure
  mode is gone; when it can't ground a real install it says so and offers a real
  substitute rather than inventing a flow.

### Minor observations (not blockers)
- **Pre-skill over-promise.** The bare-model turn 3 said a browser window "will
  open" before the skill had grounded whether Linear is connectable; the
  skill-grounded turn 7 then walked it back honestly. The skill itself was
  correct — the gap is the assistant answering optimistically *before* delegating
  to the skill. Low severity (it self-corrected within the same exchange), but if
  it recurs, the routing layer should defer the "here's what will happen" promise
  until after the skill runs.
- For one-click connectors, keep the sign-in hand-off to a single gated action.

## Repo reality (relevant to grounding)
- The dedicated `*-connector` skills referenced in `skills/CLAUDE.md`
  (linear-connector, monday-connector, telegram-connector, etc.) are **not present
  in this repo or `skills-lock.json`** — only `connector-recommender` ships here.
  They're a separate distribution the recommender coexists with at workshop-install
  time. So in the shipped-alone state, Step 5b Case 3's "invoke the dedicated
  `<service>-connector` skill" has nothing to delegate to, and the skill correctly
  falls through to Case 4 (honest unavailable + grounded substitute), as Run 3
  shows. `EXAMPLES.md` Example 5 references `linear-connector` as the design-intent
  path for when those skills *are* co-installed; that path is not exercisable in
  this repo alone.

## Known limitations / coverage
- One scenario per run (the harness's design). Covered live: ecommerce happy-path,
  registry-absent setup (Run 1/2), and the corrected Case-3/4 grounding (Run 3).
- **Not yet exercised live:** a true Case-3 *success* (a dedicated `*-connector`
  skill co-installed, Claude driving a real CLI install + OAuth to completion) —
  needs a workspace with one of those skills present. TC-09/TC-14/TC-15 and the
  other verticals remain asserted in TESTCASES.md but not run live.
- When the registry IS present, the one-click Connect path (`suggest_connectors`)
  was not exercised — the test sessions lacked the registry MCP. That path is
  unchanged from the original skill.
