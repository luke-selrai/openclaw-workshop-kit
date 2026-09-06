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
- Any file in `COUNT_FREE_FILES` carries a marker block or a hard count (`COUNT_FREE_RULES`, see below)

### Count-free surfaces (CORE-116)

`docs/start/setup.md` is deliberately **absent** from `TARGET_FILES`: ADR-0001 §7 keeps hard skill counts out of the pasted setup prompt so it can never drift from the markers, and orientation quotes live numbers instead - it runs after the install and can read the disk.

Absence from a list is not a check, though. Nothing stopped a future edit writing "installs all 196 skills" into the completion banner, with the audit staying green while the kit shipped a number that goes stale on the next merge. So the omission is now paired with a positive assertion: `setup.md` is checked to contain neither a `skills-audit:` marker nor a hard count (two or more digits within two words of "skills"/"connectors"). Two digits is the floor on purpose - "the 4 power-user skills" is a fixed set that cannot drift, while any audit-derived total is well past ten. Nothing here auto-fixes: the correct content is no number at all.

**CI wiring:** `.github/workflows/audit-skills.yml` runs `--check` on every PR that touches `skills/`, `docs/`, `visuals/`, or any of the count-bearing top-level docs.

### Description budget (CORE-93)

Same script, second content rule. Every skill's frontmatter description is always-on context in every attendee session, and Claude Code silently drops descriptions once the whole listing passes ~1% of the context window — so an oversized description can strip *another* skill's triggers with no error. Spec: [CORE-91](https://linear.app/selr-ai/issue/CORE-91).

Rules, applied to every `skills/**/SKILL.md`:

- **description-over-budget** - the description is over **500 characters**. Target is 150-250: what it does + when to use it. Procedure belongs in the body.
- **description-first-person** / **description-second-person** - the description talks as "we/our/I" or addresses the reader as "you". Descriptions are third person about the skill.

Pronouns inside **quoted trigger phrases** (`Use when the user says 'connect my Xero'`) are not flagged - quoting the user's own words is the recommended way to write triggers. Nor are pronouns glued into paths, domains, or hyphenated compounds (`users/me`, `my.freshbooks.com`, `build-your-own-CRM`), nor all-caps `US` (the country).

**Mode - enforcing since CORE-98:**

```js
// scripts/audit-skills.mjs
const DESCRIPTION_BUDGET_MODE = "enforce";
```

Any violation in a **first-party** skill fails `--check` with exit 1, and the failing output prints the rule's reason so the run alone tells an author what to fix. There is no baseline: `scripts/description-budget-baseline.json` existed only for the expand phase (CORE-93) while the ~200 rewrites landed, and CORE-98 deleted it along with the classification code.

**The one exemption - vendored, lock-pinned skills.** `skills-lock.json` pins skills vendored from upstream repos (expo, stripe, inngest, vercel-labs, mcollina, …) to a `computedHash` of the SKILL.md as it was originally fetched. Those hashes are historical artifacts of that fetch and **cannot be regenerated from this repo**, so editing a pinned SKILL.md would leave the lock permanently wrong - the exhaustive attempt is documented on [PR #414](https://github.com/selrai-company/claude-workshop-kit/pull/414). The text is upstream's, not this repo's to rewrite.

So a pinned skill is exempt from the hard failure. It is **not** exempt from the scan: every exempt hit is printed on every run under an explicit `vendored (lock-pinned) exemptions: N` heading, because an exemption nobody can see is how upstream bloat quietly becomes permanent.

The exempt set is derived from `skills-lock.json` **at audit time** - one source of truth, no hardcoded skill list in the audit script. Vendoring a skill exempts it; un-vendoring one puts it back under the rule, both with no code change here.

A lock key resolves to an on-disk directory two ways, and deliberately only two: **verbatim** (`node`, `fastify-best-practices`) and **slugified** (`Expo UI SwiftUI` → `expo-ui-swiftui`). Between them they cover all 51 current entries. The obvious third candidate - the `skillPath`'s parent, i.e. upstream's own folder - is left out because it resolves nothing extra while adding aliases that match no skill here (`fastify`, `react-best-practices`, `composition-patterns`), and those are plausible *first-party* names. The set is a name union with no check that the matched entry relates to the skill, so that candidate's only live effect would be to silently exempt a future first-party skill. The rule fails closed instead: a vendored skill neither candidate resolves is not exempted and fails loudly, and someone widens the resolver on purpose.

At the time of the flip: 204 skills scanned, 13 violations, **all 13 lock-pinned**, 0 failing.

```bash
# The check CI runs — exit 1 on any first-party violation
node scripts/audit-skills.mjs --check

# Also list every lock-pinned skill actually present on disk
node scripts/audit-skills.mjs --check --verbose
```

`--write-description-baseline` and `--descriptions-enforce` were **removed** by CORE-98 (the baseline is gone; enforce is the shipped mode, so there is nothing to preview). Both still exit 2 with an explanation rather than being silently ignored - a removed flag that no-ops looks exactly like one that worked, and both used to change whether CI passed.

The frontmatter parser handles every YAML scalar style in the library (plain, single/double quoted incl. multi-line, literal `|` and folded `>-` blocks, and a bare key with an indented block) - the repo has no YAML dependency.

## verify-conform.mjs

Asserts the kit's **install-canon** invariants - originally the Loup-deliverable PRD ([#385](https://github.com/selrai-company/claude-workshop-kit/issues/385) / slice [#386](https://github.com/selrai-company/claude-workshop-kit/issues/386)), redesigned against [ADR-0001](../docs/adr/0001-pointer-block-install-model.md) by [CORE-116](https://linear.app/selr-ai/issue/CORE-116).

ADR-0001 made the kit home a per-install fact, written into the pointer block and the manifest at install time, which inverted this checker's central rule: it used to police references to the *old* home while treating the Loup home as canonical, and it now treats **any hardcoded home** as the violation. [ADR-0003](../docs/adr/0003-the-loup-door-is-retired.md) then retired the Loup door, so the two Loup path rules collapsed into one: a path under the user's `.loup` folder is an **old Loup install** to find and remove, never a live kit home, and naming one outside the MIGRATE and uninstall handling is the violation.

**Usage:**

```bash
node scripts/verify-conform.mjs                   # exit 1 on any hard failure (used by CI)
node scripts/verify-conform.mjs --check           # the same thing, said explicitly
node scripts/verify-conform.mjs --verbose         # also print every passing check
node scripts/verify-conform.mjs --update-baseline # re-snapshot the old-canon debt (see below)
```

Unrecognised flags exit **2** rather than silently running the default - a mistyped `--updat-baseline` used to look like a passing check.

**Hard failures (fail CI):**

- **old-canon** - an old-canon install reference survives outside the surfaces allowed to carry one. Three families: the **retired homes** (`~/workshop-kit`, `$HOME/workshop-kit`, `%USERPROFILE%\workshop-kit`, `C:\Users\…\workshop-kit`, `~/claude-workshop-kit/whatsapp`), a **hardcoded kit home** (including any `.loup` path, ADR-0003), and the **dead workspace model** (`~/Desktop/my-assistant`, `~/my-assistant`, `.first-run-pending`).
- **single-install-surface** - `docs/start` carries anything other than exactly one install document (`setup.md`), or one of the retired `bootstrap.md` / `full-setup.md` reappears.
- **install-method** - the pasted prompt doesn't carry the door canon: one silent `git ls-remote` probe with `GIT_TERMINAL_PROMPT=0` on the same line, a shallow clone door, a *not-open-yet* door on a refused probe (named as such, saying it opens when the room opens, waiting and re-probing on the attendee's word), a wifi-retry door, always-re-fetch, the door declared as plumbing - and no install-type question anywhere in the document (the prompt *and* the prose around it). The install-type question patterns still name Loup on purpose: "do you have a Loup account?" is exactly the question ADR-0003 makes unaskable.
- **install-artifacts** - the prompt doesn't produce the three install artifacts (the `@`-import rule is anchored to the import **line**, since a bare at-sign is satisfied by `@louphq` elsewhere in the prompt): the marker-delimited pointer block in the global `~/.claude/CLAUDE.md`, the persona **copied out** to `~/.claude/selr-assistant.md`, and `~/.claude/selr-kit-manifest.json`; the `@`-import isn't an absolute path; or the prompt writes a workspace `my-assistant/CLAUDE.md`.
- **verify-gate-paths** - `my-assistant/CLAUDE.md` or `skills/` is missing at the repo root. These are the repo **sources** the prompt copies out of; ADR-0001 §2 keeps `my-assistant/CLAUDE.md` as the persona's source of truth even though it is no longer an install artifact.
- **windows-node-path** - the setup prompt's Windows branch doesn't install Node via `winget`, refresh the session PATH from the registry (machine + user) in the same PowerShell invocation as `node --version` / `npx`, gate the quit/reopen step behind a failing post-refresh `node --version` (never speculative), and keep the Playwright nodejs.org last-resort fallback. (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385), slice [#387](https://github.com/selrai-company/claude-workshop-kit/issues/387).)

**The retired byte-identity checker.** `bootstrap-consistency` diffed the prompt body between `docs/start/bootstrap.md` and `docs/start/full-setup.md` between canonical anchors. CORE-112 deleted both files, and ADR-0001 §4 retires the check outright: the shared text exists exactly once, so drift is not something to diff for - it is structurally impossible. CORE-112 left it printing a loud `SKIP`; CORE-116 removed it. What stands in its place is `single-install-surface`, because the property that actually needs guarding is *there is still only one copy* - a second copy is how drift returns.

**The old-canon baseline.** Inverting the home rule turned ~50 pre-existing references into violations overnight, in files owned by sibling ADR-0001 tickets (CORE-113 persona, CORE-114 orientation, CORE-117 stale-doc sweep). Rather than exempt them, `scripts/old-canon-baseline.json` records a per-file **count** of the debt, and the check ratchets:

- a file **not** in the baseline that gains a reference → **fail**
- a baselined file whose count **goes up** → **fail**
- a baselined file whose count goes **down**, or reaches zero → **warn**, printed on every run, with the instruction to re-snapshot

So no new old-canon reference can enter the tree anywhere, and the file can only shrink. When it is empty, delete it.

Three holes, documented in the file's own `__doc__` so a green ratchet is not read as more than it is: a line counts **once per pattern**, not per occurrence (rewrapping can move a number without changing meaning); the count is per file, so a same-file **swap** - one reference deleted, a different one added - is invisible, because the ratchet catches accumulation rather than substitution; and `--update-baseline` snapshots with **no gate**, so it will happily record new debt. It is a maintenance command for after a sweep lands, not a way to make a failing check pass - a raised number is a reviewable diff, and that is the enforcement. Genuinely permanent surfaces are **not** baselined - the migration fixture, the migration recipe, the ADR itself, `docs/uninstall.md` and the uninstall skill are in `OLD_CANON_ALLOWLIST`, because each exists to move a machine off the old canon and cannot do that without naming it.

**`docs/start/setup.md` is scoped by section, not allowlisted.** It legitimately names every legacy path - it probes the legacy-workspace candidate list, the three legacy kit homes, and it deletes a confirmed-stale `~/workshop-kit`. A file-level exemption on the most attendee-facing document in the kit would hide a real regression (a stale "your assistant folder on the Desktop" line in the completion banner would sail through), so the exemption covers only the **bodies of Steps 1-4** - mode detection, acquisition, pointer block + MIGRATE retirement, and the manifest. The intro, Steps 0 and 5-10, the completion banner and the trailing prose are held to the same rule as any other document.

`windows-node-path` is unchanged by the redesign - it runs against the pasted prompt sliced out of `docs/start/setup.md`, and the winget install, the machine+user registry refresh, the one-invocation `node --version`, the process-only statement and the nodejs.org fallback are all door-agnostic and still enforced.

Its Loup-specific clause survives as a **conditional** that is now inert. If a body invokes `npx @louphq/install` it must still say how the refreshed PATH reaches that line, either on the line or via the blanket "prepend the same refresh to every later PowerShell command" rule. Since ADR-0003 no conformant document invokes it at all, so the clause never fires. It is kept rather than deleted because it costs nothing and a resurrected paste-this-command step should not sail through.

The **informational snapshot-shape line** is gone with ADR-0003. It measured the tree against Loup's caps, and Loup no longer ships this kit.

## check-resilient-install.mjs

Asserts the setup prompt's **failure-recovery** contract - the resilient-install slice (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385) / slice [#388](https://github.com/selrai-company/claude-workshop-kit/issues/388)). Slice [#386](https://github.com/selrai-company/claude-workshop-kit/issues/386) gave the bootstrap a hard-stop verify-gate; this checker is the cheap backstop that the **self-resolve loop** (diagnose → targeted fix → retry → repeat, no human in the loop) stays intact. ADR-0001 collapsed the two bootstrap copies into the single `docs/start/setup.md`, so the checker reads that one file. It still slices the **pasted prompt** out of the document (between the `## The prompt` and `## Before workshop day` headings) rather than scanning the whole file - every rule is a presence regex, so the attendee prose wrapped around the prompt must not be able to satisfy a rule the prompt itself dropped. A missing marker is a hard failure, not a silent whole-file fallback.

**Usage:**

```bash
node scripts/check-resilient-install.mjs            # exit 1 on any failure
node scripts/check-resilient-install.mjs --verbose  # also print every passing check
```

**Failures (exit 1)** - each checked against the setup prompt:

- **hard-stop** - on a failed verify-gate the bootstrap stops and does not cascade into steps 3-7.
- **real-output** - the real, unedited command output is shown to the attendee, never swallowed.
- **partial-report** - a half-finished download (folder present but a checked path missing) is reported, not silently treated as success.
- **one-fix-per-round** - the recovery loop changes one thing at a time rather than shotgunning fixes at a failed download.
- **no-retry-cap** - the loop states there is no limit on retries.
- **no-escalation** - no human-escalation wording (`notify` / `facilitator` / `Luke` / `Harvey` / `escalate`) appears in the body.

The **probe/clone** surface (ADR-0001 §1, added by CORE-116, retired to one live door by [ADR-0003](../docs/adr/0003-the-loup-door-is-retired.md)) fails the same way, but the probe splits three ways and none of the three is ever a credential problem:

- **silent-probe** - the repo is probed with `git ls-remote` and `GIT_TERMINAL_PROMPT=0` **on the same line**, so a closed repo fails fast instead of hanging on a credential prompt. Same-line, not same-document: the clone a few paragraphs later also disables prompting, and a document-wide test would keep passing while the probe itself was left free to hang.
- **three-doors** - success → clone, refused → wait for the room to open, timeout/network → wifi retry.
- **no-credential-ask** - a refused probe never turns into a password ask.
- **not-open-yet** - a refused probe is named for what it is: the kit is not open yet, it opens when the room opens, and the host says when. Never the attendee's access, never something they can fix by fetching a credential.
- **wait-then-retry** - what replaced the Loup re-mint loop. The refused door waits for the attendee's word and re-runs the same probe when they give it.
- **network-is-wifi** - a network failure is named as the wifi and routed to an online check plus a re-probe. This is the one that matters on venue wifi: a dropped connection reads as "your access was revoked" to a naive installer, and the attendee ends up hunting for credentials that were never the problem.
- **always-refetch** - the kit is re-acquired fresh on every run, never updated in place.
- **clone-safety** - an existing kit-home folder is deleted only after it is confirmed to be a kit download, never on its name alone. Anchored to its own sentence, so the rule cannot be satisfied by the words appearing anywhere in the prompt.
- **no-retired-delivery-surface** - the inverted rule ADR-0003 added. No Loup surface, dashboard, token, install command, sign-in destination or unqualified credential ask anywhere in the prompt. It is checked with the **legacy-home lines stripped out first**, because MIGRATE and the retirement step still have to name the old Loup install folders they delete - naming a folder to remove it is not a door. The credential-ask half is negation-aware, so "never ask me for a password" reads as the contract it is.

**Harness wiring:** runs in CI on every event via `.github/workflows/audit-skills.yml`, alongside `verify-conform.mjs`.

## check-install-narration.mjs

Asserts the **venue-wifi install-narration** contract ([LOUP-20](https://linear.app/selr-ai/issue/LOUP-20)) - kills the "Claude silently hangs for minutes while something downloads over venue wifi" experience. Two layers: deep treatment in the setup prompt body (preflight at the very start, before/visible/after narration on every download point), and one always-on rule in `my-assistant/CLAUDE.md` for sessions where the prompt is not loaded. ADR-0001 §7 retired the second deep surface: the skill that used to install things is now `orientation`, which installs nothing.

**Usage:**

```bash
node scripts/check-install-narration.mjs            # exit 1 on any failure
node scripts/check-install-narration.mjs --verbose  # also print every passing check
```

**Failures (exit 1)** - checked per surface (`bootstrap-body` and `bootstrap-prework`, both reading `docs/start/setup.md` - `bootstrap-body` over the sliced prompt only, `bootstrap-prework` over the whole file since the pre-workshop Node line sits outside the prompt - plus `kit-rule`):

- **preflight-network** - a preflight checks the network against `registry.npmjs.org` with a hard timeout (bootstrap body).
- **looks-frozen** - the key sentence survives: a slow download may *look frozen* without being frozen (all surfaces).
- **narrate-before** - narration happens BEFORE the command runs, because Claude cannot talk mid-command (bootstrap body).
- **generous-timeout** / **fails-loudly** - slow commands carry a generous timeout so a dead download fails loudly instead of hanging forever (all surfaces).
- **confirm-after** - after the command, success is confirmed or what failed is stated plainly (bootstrap body + kit rule).
- **node-prework** - the "have Node.js installed before you arrive" pre-workshop line exists in `docs/start/setup.md`.
- **browser-download-warning** - the prompt warns that the first Playwright launch downloads the browser itself (bootstrap body only).
- **every-download-warned** - one blanket rule at the top of the prompt binds **every** download in it, spoken before the command runs. Both halves must sit in the **same paragraph**: an unanchored "before" is satisfied by any of the prompt's dozens of other uses of the word. The two-prompt era narrated its two or three download points by hand; the universal prompt has eight or nine, and enumerating them in a checker would rot on the first reorder, so the contract moved up a level.
- **mode-announcement** - the detected mode (fresh / update / migrate) is announced in one line of plain English, before anything on the machine changes.

**Harness wiring:** runs in CI on every event via `.github/workflows/audit-skills.yml`, after the resilient-install steps.

## check-mp-skills-install.mjs

Asserts the **Matt Pocock power-user-skills install contract** in `docs/start/setup.md`, Step 6's "Power-user skills" item ([LOUP-19](https://linear.app/selr-ai/issue/LOUP-19)). The slice ends at whichever comes first - the next numbered item in the step, or the next heading. The old `### Step 7` end anchor sliced to the end of *Step 6*, which was correct only by accident (item 4 happens to be last today); a fifth item would have silently widened the slice and let unrelated prompt text satisfy this step's rules. It lived in the onboarding skill's install phase until ADR-0001 moved every install into the one setup prompt; the checker followed it, dropping the four rules the prompt does not state (listed in the script header - re-deciding them is [CORE-116](https://linear.app/selr-ai/issue/CORE-116)). Upstream renamed `diagnose` → `diagnosing-bugs` and the hardcoded selector silently stripped skills from attendees, with a "probably a network hiccup" hand-wave hiding it; this checker keeps the fixed contract intact.

**Usage:**

```bash
node scripts/check-mp-skills-install.mjs            # static rules; exit 1 on any failure
node scripts/check-mp-skills-install.mjs --verbose  # also print every passing check
node scripts/check-mp-skills-install.mjs --live     # + list the live mattpocock/skills repo and
                                                    #   assert every expected skill still exists
```

**Failures (exit 1)** - checked against the sliced power-user-skills body:

- **current-selectors / verify-paths** - the install command selects, and the verify list checks, every skill in `EXPECTED_SKILLS` (`grill-me`, `handoff`, `diagnosing-bugs`, `teach`) under its current upstream name.
- **no-stale-names** - no retired name (`diagnose`) survives as a selector, path, or bold mention.
- **self-heal-listing / rename-resolution / recheck-after-heal** - a miss triggers listing the repo's live skills (`skills add … -l`), resolving renames dynamically, retrying, and re-checking the disk rather than assuming the heal worked.
- **per-skill-report** - the step ends by reporting status per skill, not one blanket outcome.
- **no-handwave** - no "network hiccup" hand-wave or facilitator escalation.

`--live` makes CI go red at the **next** upstream rename (an expected name vanishing from the live repo) instead of attendees silently losing skills. On a rename: re-resolve the new name, update `EXPECTED_SKILLS` and the setup prompt's power-user-skills step together.

**Harness wiring:** runs in CI (with `--live`) on every event via `.github/workflows/audit-skills.yml`.

## Tests

Plain Node, no framework - each prints `PASS`/`FAIL` and exits non-zero on any failure.

```bash
node scripts/test-anti-patterns.mjs      # regression for audit-skills anti-pattern rules
node scripts/test-description-budget.mjs # description-budget rules, parser, and the report/enforce switch
node scripts/test-verify-conform.mjs     # every verify-conform rule, each proven by a seeded violation
node scripts/test-count-free.mjs         # the count-free assertion on docs/start/setup.md
node scripts/test-resilient-install.mjs  # resilience rules pass on both copies; fire on a bad fixture
node scripts/test-install-narration.mjs  # narration rules pass on all surfaces; fire on a bad fixture
node scripts/test-mp-skills-install.mjs  # install-contract rules pass on the setup prompt; fire on a bad fixture
```

`test-description-budget.mjs` imports the rules from `audit-skills.mjs` (no mirrored regexes) and runs them over fixture skills in `scripts/__fixtures__/descriptions/`: an over-budget one, a first-person one, a second-person one, a compliant one, one whose description is exactly 500 characters (the rule fires strictly *above* the limit), and a `vendored-over-budget` one pinned by the fixture lock `scripts/__fixtures__/descriptions-lock.json`. It asserts the over-budget **non-pinned** fixture fails in enforcing mode, the compliant fixtures pass, the pinned fixture is scanned but exempt, and the real library has **zero** failing violations with every remaining one matching a `skills-lock.json` key exactly. Fixtures live outside `skills/`, so the real scan never sees them.

Its last section tests the thing CI actually consumes - **exit codes**. `audit-skills.mjs` derives its `ROOT` from its own location, so the test copies the script into a temp sandbox alongside a disposable `skills/` tree and lock, then runs it for real: compliant exits 0, a lock-pinned violation exits 0 but is listed, an identical *non-pinned* violation exits 1 with the rule's reason printed, and both removed flags exit 2. Without this, mis-wiring the fail gate (passing all hits instead of the failing ones) would break every build with every unit assertion still green.

`test-verify-conform.mjs` covers every rule in the checker, and every rule is paired with a **seeded violation** - a good input plus a mutation that removes exactly one property - because a regex over prose that has never been made to fail is not a check. It reads two allowlisted fixtures (`scripts/__fixtures__/conform-stale.md` for the retired homes, `scripts/__fixtures__/old-canon-bad.md` for the inverted rules) and asserts each pattern fires on the exact line; it drives the setup-doc section scoping in **both** directions (the same sentence exempt in Step 1, a violation in Step 9 and in the trailing prose); it unit-tests the baseline ratchet (new file fails, over-baseline fails, under-baseline warns); it mutates a conformant Step 2 thirteen ways to prove each door clause fires; and it drives the conditional npx clause in all three states (invoked with the blanket rule, invoked with neither, never invoked). Its `windows-node-path` bad cases prove each surviving clause fires; the "split npx invocation" case was removed alongside the clause it guarded, since a bad case for a deleted rule passes for the wrong reason.

`test-count-free.mjs` covers the count-free assertion in `audit-skills.mjs`. The rule stands in for an *absence* - `docs/start/setup.md` is deliberately left out of `TARGET_FILES` so no marker writes a number into the pasted prompt - and an absence passes trivially on any document that happens not to mention skills, so the fixture (`scripts/__fixtures__/count-free-bad.md`) pins both halves: the lines that must fire (a marker block, "196 skills", "16 connectors", "200+ ready-made skills") and the lines that must not ("20-30 minutes", "the 4 power-user skills").

`test-resilient-install.mjs` imports `evaluateResilience()` from the checker, confirms the real setup document's sliced prompt passes every rule, and asserts a deliberately non-resilient fixture (`scripts/__fixtures__/resilient-install-bad.md`) fails every one - so each detector is proven to fire. Since CORE-385 that fixture carries the retired Loup walkthrough, which gives the forbidden-surface rule something real to catch, and the test drives the legacy-home carve-out in both directions: naming an old Loup install folder is not a delivery surface, the same words one line off such a path still are.

`test-mp-skills-install.mjs` does the same for `check-mp-skills-install.mjs`: the real power-user-skills step passes every rule, the pre-fix fixture (`scripts/__fixtures__/mp-skills-install-bad.md`) fails every one, and the live-listing parser is exercised against fake GitHub tree responses (flat + category-nested layouts, rename detection, API-failure throw) with no network.
