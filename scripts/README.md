# scripts/

Repo maintenance scripts. Plain Node, no dependencies - run with `node scripts/<name>.mjs`.

## audit-skills.mjs

Keeps the hand-maintained skill counts and tier breakdowns in sync with the on-disk truth across the discovery-surface docs. Tracked in [#115](https://github.com/selrai-company/claude-workshop-kit/issues/115).

**Usage:**

```bash
# Verify all marker-bracketed counts match the disk (used by CI)
node scripts/audit-skills.mjs --check

# Rewrite any drifted counts in place (run before committing)
node scripts/audit-skills.mjs --write

# Add the alphabetised connector list to stdout
node scripts/audit-skills.mjs --check --verbose
```

**Source of truth:**

- **Total skills** - count of `skills/*/SKILL.md` files
- **Connectors** - `skills/*-connector/` directories
- **CORE / ADVANCED / DEV-ONLY** - tier column in `skills/SKILLS-LIST.md`

**Marker shapes** (case-sensitive, inline):

```
<!-- skills-audit:total -->105<!-- /skills-audit:total -->
<!-- skills-audit:core -->22<!-- /skills-audit:core -->
<!-- skills-audit:advanced -->56<!-- /skills-audit:advanced -->
<!-- skills-audit:dev-only -->8<!-- /skills-audit:dev-only -->
<!-- skills-audit:connectors-count -->16<!-- /skills-audit:connectors-count -->
```

To add a new claim that should stay in sync, wrap the number in the appropriate marker pair anywhere in any file in the `TARGET_FILES` list at the top of the script.

**Soft warnings (don't fail CI):**

- Skills on disk but not classified in `SKILLS-LIST.md`
- Skills in `SKILLS-LIST.md` but missing from disk

These are content-decision drift - the script reports them so a human can classify, but it doesn't block PRs that didn't touch classification.

**Hard failures (fail CI):**

- Any marker-bracketed number doesn't match the disk-true value
- Any `skills/**/SKILL.md` hits an anti-pattern rule (`ANTI_PATTERN_RULES`)

**CI wiring:** `.github/workflows/audit-skills.yml` runs `--check` on every PR that touches `skills/`, `docs/`, `visuals/`, or any of the count-bearing top-level docs.

### Description budget (CORE-93)

Same script, second content rule. Every skill's frontmatter description is always-on context in every attendee session, and Claude Code silently drops descriptions once the whole listing passes ~1% of the context window — so an oversized description can strip *another* skill's triggers with no error. Spec: [CORE-91](https://linear.app/selr-ai/issue/CORE-91).

Rules, applied to every `skills/**/SKILL.md`:

- **description-over-budget** - the description is over **500 characters**. Target is 150-250: what it does + when to use it. Procedure belongs in the body.
- **description-first-person** / **description-second-person** - the description talks as "we/our/I" or addresses the reader as "you". Descriptions are third person about the skill.

Pronouns inside **quoted trigger phrases** (`Use when the user says 'connect my Xero'`) are not flagged - quoting the user's own words is the recommended way to write triggers. Nor are pronouns glued into paths, domains, or hyphenated compounds (`users/me`, `my.freshbooks.com`, `build-your-own-CRM`), nor all-caps `US` (the country).

**Mode - the expand/contract switch:**

```js
// scripts/audit-skills.mjs
const DESCRIPTION_BUDGET_MODE = "report";  // CORE-98 flips this to "enforce"
```

- `"report"` (today) - violations are printed, **CI stays green**. `scripts/description-budget-baseline.json` records the violations that already existed when the rule shipped, so the report separates *baselined* from *new*. New ones are called out loudly but still don't fail.
- `"enforce"` - any violation fails `--check`. To contract (CORE-98): set the constant and **delete the baseline file**. Nothing else changes; the baseline is only read in report mode.

```bash
# Preview the enforcing outcome without flipping the switch (exits 1 today)
node scripts/audit-skills.mjs --check --descriptions-enforce

# List every baselined violation and any baseline entry already fixed
node scripts/audit-skills.mjs --check --verbose

# Regenerate the baseline (report mode only — prefer fixing over baselining)
node scripts/audit-skills.mjs --write-description-baseline
```

`--write-description-baseline` still runs the whole audit (markers, anti-patterns, budget report) and still exits 1 on marker drift - regenerating the baseline is never a way to skip the check. It exits 2 rather than writing if `DESCRIPTION_BUDGET_MODE` is not `"report"`, since after CORE-98 the baseline is deleted on purpose.

The frontmatter parser handles every YAML scalar style in the library (plain, single/double quoted incl. multi-line, literal `|` and folded `>-` blocks, and a bare key with an indented block) - the repo has no YAML dependency.

## check-snapshot-shape.mjs

Asserts the kit stays under Loup's snapshot caps, so re-snapshotting the private repo never breaks an attendee's install live. Loup ships the kit as a verbatim repo snapshot; this is the kit's own size invariant (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385), slice [#389](https://github.com/selrai-company/claude-workshop-kit/issues/389)).

**Usage:**

```bash
# Human report, exit 1 if any cap is breached (used by the workshop-preflight harness)
node scripts/check-snapshot-shape.mjs

# Machine-readable report
node scripts/check-snapshot-shape.mjs --json
```

Measures the committed tree at `HEAD` (what Loup actually publishes) and gates on:

- **File count** < 2000
- **Archive bytes** (gzipped tar, proxy for Loup's archive cap) < 45 MB
- **Unpacked bytes** < 80 MB
- The post-unpack **verify-gate paths** the bootstrap checks - `my-assistant/CLAUDE.md` and `skills/` - present at the repo root

Caps are exclusive (a value AT the cap fails); it WARNs at 90% so there's early signal before a cap is hit. Exit codes: `0` within caps, `1` a cap breached, `2` could not read git.

**Harness wiring:** the `workshop-preflight` skill runs this as a Phase 1 gating check during the pre-workshop dry run.

## verify-conform.mjs

Asserts the Loup-deliverable invariants (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385) / slice [#386](https://github.com/selrai-company/claude-workshop-kit/issues/386)). The kit home is `~/.loup/selr-ai/workshop-kit`.

**Usage:**

```bash
node scripts/verify-conform.mjs            # exit 1 on any hard failure (used by CI)
node scripts/verify-conform.mjs --verbose  # also print every passing check
```

**Hard failures (fail CI):**

- **path-conform** - any stale kit-home reference survives (`~/workshop-kit`, `$HOME/workshop-kit`, `%USERPROFILE%\workshop-kit`, `C:\Users\…\workshop-kit`, or the old `~/claude-workshop-kit/whatsapp` fallback).
- **bootstrap-consistency** - the bootstrap prompt body is not byte-identical between `docs/start/bootstrap.md` and `docs/start/full-setup.md` (taken between the start/end anchors).
- **install-method** - the bootstrap doesn't install via `npx @louphq/install`, or still `git clone`s the kit.
- **verify-gate-paths** - `my-assistant/CLAUDE.md` or `skills/` is missing at the repo root.
- **windows-node-path** - the bootstrap's Windows branch doesn't install Node via `winget`, refresh the session PATH from the registry (machine + user) in the same PowerShell invocation as `node --version` / `npx`, gate the quit/reopen step behind a failing post-refresh `node --version` (never speculative), and keep the Playwright nodejs.org last-resort fallback. (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385), slice [#387](https://github.com/selrai-company/claude-workshop-kit/issues/387).)

**Informational (never fails):** snapshot file count vs Loup's `< 2000` cap.

## check-resilient-install.mjs

Asserts the bootstrap's **failure-recovery** contract - the resilient-install slice (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385) / slice [#388](https://github.com/selrai-company/claude-workshop-kit/issues/388)). Slice [#386](https://github.com/selrai-company/claude-workshop-kit/issues/386) gave the bootstrap a hard-stop verify-gate; this checker is the cheap backstop that the **self-resolve loop** (diagnose → targeted fix → retry → repeat, no human in the loop) stays intact in **both** copies of the bootstrap body (`docs/start/bootstrap.md` and the `docs/start/full-setup.md` Step 5 duplicate).

**Usage:**

```bash
node scripts/check-resilient-install.mjs            # exit 1 on any failure
node scripts/check-resilient-install.mjs --verbose  # also print every passing check
```

**Failures (exit 1)** - each checked against every copy's bootstrap body:

- **hard-stop** - on a failed verify-gate the bootstrap stops and does not cascade into steps 3-7.
- **real-output** - the real, unedited command output is shown to the attendee, never swallowed.
- **partial-report** - a half-finished download (folder present but a checked path missing) is reported, not silently treated as success.
- **rejected-diagnosis** - a refused install is named as the common cause, with both of its causes (a stale command and a grant not yet active). Plain English - §3 of `CONTRIBUTING.md` bans jargon like `token`/`401` from attendee-facing prose, so the rule guards the diagnosis, not the error string.
- **remint-fix** - the primary fix is re-minting via "Get install command" and retrying.
- **no-retry-cap** - the loop states there is no limit on retries.
- **no-escalation** - no human-escalation wording (`notify` / `facilitator` / `Luke` / `Harvey` / `escalate`) appears in the body.

**Harness wiring:** runs in CI on every event via `.github/workflows/audit-skills.yml`, alongside `verify-conform.mjs`.

## check-install-narration.mjs

Asserts the **venue-wifi install-narration** contract ([LOUP-20](https://linear.app/selr-ai/issue/LOUP-20)) - kills the "Claude silently hangs for minutes while something downloads over venue wifi" experience. Two layers: deep treatment in the bootstrap body (both copies) + `skills/first-run-setup/SKILL.md` (preflight at the very start, before/visible/after narration on every download point), and one always-on rule in `my-assistant/CLAUDE.md` for sessions where neither is loaded.

**Usage:**

```bash
node scripts/check-install-narration.mjs            # exit 1 on any failure
node scripts/check-install-narration.mjs --verbose  # also print every passing check
```

**Failures (exit 1)** - checked per surface (`bootstrap-body` in both copies, `bootstrap-prework`, `first-run`, `kit-rule`):

- **preflight-network** - a preflight checks the network against `registry.npmjs.org` with a hard timeout (bootstrap body + first-run).
- **looks-frozen** - the key sentence survives: a slow download may *look frozen* without being frozen (all surfaces).
- **narrate-before** - narration happens BEFORE the command runs, because Claude cannot talk mid-command (bootstrap body + first-run).
- **generous-timeout** / **fails-loudly** - slow commands carry a generous timeout so a dead download fails loudly instead of hanging forever (all surfaces).
- **confirm-after** - after the command, success is confirmed or what failed is stated plainly (bootstrap body + kit rule).
- **node-prework** - the "have Node.js installed before you arrive" pre-workshop line exists in `docs/start/bootstrap.md`.
- **browser-download-warning** - first-run warns that the first Playwright launch downloads the browser itself (first-run only).

**Harness wiring:** runs in CI on every event via `.github/workflows/audit-skills.yml`, after the resilient-install steps.

## check-mp-skills-install.mjs

Asserts the **Matt Pocock power-user-skills install contract** in `skills/first-run-setup/SKILL.md` Phase 2.5 Step 3 ([LOUP-19](https://linear.app/selr-ai/issue/LOUP-19)). Upstream renamed `diagnose` → `diagnosing-bugs` and the hardcoded selector silently stripped skills from attendees, with a "probably a network hiccup" hand-wave hiding it; this checker keeps the fixed contract intact.

**Usage:**

```bash
node scripts/check-mp-skills-install.mjs            # static rules; exit 1 on any failure
node scripts/check-mp-skills-install.mjs --verbose  # also print every passing check
node scripts/check-mp-skills-install.mjs --live     # + list the live mattpocock/skills repo and
                                                    #   assert every expected skill still exists
```

**Failures (exit 1)** - checked against the Step 3 body:

- **current-selectors / verify-paths** - the install command selects, and the verify list checks, every skill in `EXPECTED_SKILLS` (`grill-me`, `handoff`, `diagnosing-bugs`, `teach`) under its current upstream name.
- **no-stale-names** - no retired name (`diagnose`) survives as a selector, path, or bold mention.
- **self-heal-listing / rename-resolution / zero-installed-case** - a miss triggers listing the repo's live skills (`skills add … -l`), resolving renames dynamically, and retrying - explicitly covering the all-four-missing case, not just partial misses.
- **visible-summary / honest-reporting** - the step always ends with a per-skill ✅/❌ summary quoting real command output, never an invented cause.
- **no-handwave / non-blocking** - no "network hiccup" hand-wave or facilitator escalation, and a miss never blocks the rest of setup.

`--live` makes CI go red at the **next** upstream rename (an expected name vanishing from the live repo) instead of attendees silently losing skills. On a rename: re-resolve the new name, update `EXPECTED_SKILLS` and the Step 3 body together.

**Harness wiring:** runs in CI (with `--live`) on every event via `.github/workflows/audit-skills.yml`.

## Tests

Plain Node, no framework - each prints `PASS`/`FAIL` and exits non-zero on any failure.

```bash
node scripts/test-anti-patterns.mjs      # regression for audit-skills anti-pattern rules
node scripts/test-description-budget.mjs # description-budget rules, parser, and the report/enforce switch
node scripts/test-snapshot-shape.mjs     # cap-boundary + real-repo checks for the snapshot invariant
node scripts/test-verify-conform.mjs     # stale-ref + bootstrap-consistency rules for verify-conform
node scripts/test-resilient-install.mjs  # resilience rules pass on both copies; fire on a bad fixture
node scripts/test-install-narration.mjs  # narration rules pass on all surfaces; fire on a bad fixture
node scripts/test-mp-skills-install.mjs  # install-contract rules pass on Step 3; fire on a bad fixture
```

`test-description-budget.mjs` imports the rules from `audit-skills.mjs` (no mirrored regexes) and runs them over fixture skills in `scripts/__fixtures__/descriptions/`: an over-budget one, a first-person one, a second-person one, a compliant one, and one whose description is exactly 500 characters (the rule fires strictly *above* the limit). It asserts the over-budget fixture fails in **enforcing** mode, the compliant fixtures pass, report mode never fails, and the shipped baseline still covers the real library. Fixtures live outside `skills/`, so the real scan never sees them.

`test-verify-conform.mjs` reads `scripts/__fixtures__/conform-stale.md` (allowlisted in `verify-conform.mjs`) and asserts each stale-ref rule fires on the expected line.

`test-resilient-install.mjs` imports `evaluateResilience()` from the checker, confirms both real bootstrap copies pass every rule, and asserts a deliberately non-resilient fixture (`scripts/__fixtures__/resilient-install-bad.md`) fails every one - so each detector is proven to fire.

`test-mp-skills-install.mjs` does the same for `check-mp-skills-install.mjs`: the real Step 3 passes every rule, the pre-fix fixture (`scripts/__fixtures__/mp-skills-install-bad.md`) fails every one, and the live-listing parser is exercised against fake GitHub tree responses (flat + category-nested layouts, rename detection, API-failure throw) with no network.
