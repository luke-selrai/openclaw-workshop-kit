#!/usr/bin/env node
// Regression test for the description-budget rule in audit-skills.mjs (CORE-93).
// Imports the audit script's own functions (one source of truth — no mirrored
// regexes) and asserts:
//   1. The frontmatter description parser handles every YAML scalar style the
//      library actually uses (plain, quoted, literal/folded block, multi-line).
//   2. Each rule fires on its own fixture skill and stays silent on the
//      compliant + exactly-at-the-limit fixtures.
//   3. In ENFORCING mode an over-budget non-pinned fixture fails and the
//      compliant fixtures pass.
//   4. A skill pinned in a skills-lock.json is exempted from the failure —
//      still scanned and reported, never fatal (CORE-98).
//   5. The real library is clean: zero failing violations, every remaining one
//      vendored and lock-pinned. This is the CI-green guarantee.
// Follows scripts/test-resilient-install.mjs's PASS/FAIL + fixture convention.

import { execFileSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  extractDescription,
  evaluateDescription,
  auditDescriptions,
  readSkillDescriptions,
  slugifyLockKey,
  loadPinnedSkillDirs,
  partitionDescriptionHits,
  descriptionBudgetFails,
  REMOVED_FLAGS,
  DESCRIPTION_MAX_CHARS,
  DESCRIPTION_BUDGET_MODE,
  DESCRIPTION_RULES,
  SKILLS_LOCK_FILE,
} from "./audit-skills.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(HERE, "__fixtures__", "descriptions");
const FIXTURE_LOCK = join(HERE, "__fixtures__", "descriptions-lock.json");
const ROOT = resolve(HERE, "..");

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};
const eq = (actual, expected, label) =>
  check(
    actual === expected,
    `${label}${actual === expected ? "" : ` (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`}`,
  );

// ---------------------------------------------------------------------------
// 1. Frontmatter parsing — every YAML scalar style present in skills/**.
// ---------------------------------------------------------------------------
const PARSE_CASES = [
  {
    label: "plain scalar",
    text: "---\nname: a\ndescription: Does a thing. Use when asked.\n---\n\nbody\n",
    value: "Does a thing. Use when asked.",
    line: 3,
  },
  {
    label: "double-quoted scalar",
    text: '---\nname: a\ndescription: "Does a \\"thing\\". Use when asked."\n---\n',
    value: 'Does a "thing". Use when asked.',
    line: 3,
  },
  {
    label: "single-quoted scalar",
    text: "---\nname: a\ndescription: 'Does a thing''s job. Use when asked.'\n---\n",
    value: "Does a thing's job. Use when asked.",
    line: 3,
  },
  {
    label: "literal block scalar",
    text: "---\nname: a\ndescription: |\n  Does a thing.\n  Use when asked.\nallowed-tools:\n  - Bash\n---\n",
    value: "Does a thing.\nUse when asked.",
    line: 3,
  },
  {
    label: "folded block scalar",
    text: "---\nname: a\ndescription: >-\n  Does a thing.\n  Use when asked.\n---\n",
    value: "Does a thing. Use when asked.",
    line: 3,
  },
  {
    label: "plain multi-line scalar (empty key line)",
    text: "---\nname: a\ndescription:\n  Does a thing.\n  Use when asked.\nmodel: opus\n---\n",
    value: "Does a thing. Use when asked.",
    line: 3,
  },
  {
    label: "multi-line double-quoted scalar",
    text: '---\nname: a\ndescription: "Does a thing.\n  Use when asked."\n---\n',
    value: "Does a thing. Use when asked.",
    line: 3,
  },
  {
    // An indented `---` is block-scalar content, not the frontmatter
    // terminator. Treating it as one would truncate the description and hide
    // the rest of it (and any violation in it) from both rules.
    label: "block scalar containing an indented ---",
    text: "---\nname: a\ndescription: |\n  Does a thing.\n  ---\n  Use when you ask.\n---\n",
    value: "Does a thing.\n---\nUse when you ask.",
    line: 3,
  },
  {
    // A trailing YAML comment must not be absorbed into the value: it inflates
    // the char count and can import pronouns that aren't in the description.
    label: "quoted scalar with a trailing comment",
    text: '---\nname: a\ndescription: "Does a thing."  # you should rewrite this\n---\n',
    value: "Does a thing.",
    line: 3,
  },
];

for (const c of PARSE_CASES) {
  const got = extractDescription(c.text);
  eq(got && got.value, c.value, `parse ${c.label}: value`);
  eq(got && got.line, c.line, `parse ${c.label}: line number`);
}

eq(extractDescription("no frontmatter here\n"), null, "parse: no frontmatter returns null");
eq(extractDescription("---\nname: a\n---\n"), null, "parse: no description key returns null");
check(
  extractDescription("---\nname: a\ndescription: x\n") === null,
  "parse: unterminated frontmatter returns null",
);

// ---------------------------------------------------------------------------
// 2. Rules fire on their own fixture and nowhere else.
// ---------------------------------------------------------------------------
const ALL_RULE_IDS = DESCRIPTION_RULES.map((r) => r.id);
eq(DESCRIPTION_MAX_CHARS, 500, "budget is 500 chars");

const fixtureHits = auditDescriptions({ skillsDir: FIXTURES, relPrefix: "scripts/__fixtures__/descriptions" });
const byFixture = new Map();
for (const hit of fixtureHits) {
  const name = hit.relPath.split("/").at(-2);
  if (!byFixture.has(name)) byFixture.set(name, new Set());
  byFixture.get(name).add(hit.rule);
}
const rulesFor = (name) => [...(byFixture.get(name) || [])].sort().join(",");

eq(rulesFor("compliant"), "", "compliant fixture: no hits");
eq(rulesFor("at-limit"), "", "at-limit fixture (exactly 500 chars): no hits");
eq(rulesFor("over-budget"), "description-over-budget", "over-budget fixture: length rule only");
eq(
  rulesFor("vendored-over-budget"),
  "description-over-budget",
  "vendored-over-budget fixture: length rule fires (the exemption is applied later, not by skipping the scan)",
);
eq(rulesFor("first-person"), "description-first-person", "first-person fixture: person rule only");
eq(rulesFor("second-person"), "description-second-person", "second-person fixture: person rule only");

// Every declared rule is exercised by at least one fixture — proves no rule is
// dead code that silently never fires.
const firedIds = new Set(fixtureHits.map((h) => h.rule));
for (const id of ALL_RULE_IDS) check(firedIds.has(id), `rule [${id}] is exercised by a fixture`);

// Hits carry the reporting payload the audit output depends on.
const overBudgetHit = fixtureHits.find((h) => h.rule === "description-over-budget");
check(!!overBudgetHit && overBudgetHit.chars > DESCRIPTION_MAX_CHARS, "over-budget hit reports its char count");
check(!!overBudgetHit && overBudgetHit.line > 0, "over-budget hit reports a line number");
check(!!overBudgetHit && typeof overBudgetHit.detail === "string" && overBudgetHit.detail.length > 0, "over-budget hit carries a detail string");

// Boundary: the rule fires strictly above the limit, not at it.
eq(evaluateDescription("x".repeat(DESCRIPTION_MAX_CHARS)).length, 0, "exactly at the limit: no hit");
eq(
  evaluateDescription("x".repeat(DESCRIPTION_MAX_CHARS + 1)).map((h) => h.rule).join(","),
  "description-over-budget",
  "one char over the limit: hit",
);

// The person rules must not fire on the canonical third-person shape.
eq(
  evaluateDescription("Connects Xero to Claude. Use when the user asks to set up Xero, or wants invoice work and the connection isn't in place yet.").length,
  0,
  "canonical third-person description: no hits",
);
// ...nor on words that merely contain a pronoun (word-boundary guards).
eq(
  evaluateDescription("Uses the busy hours report for useful mineral website download work. Yourself is a word.").map((h) => h.rule).sort().join(","),
  "description-second-person",
  "substring pronouns don't fire; a real 'Yourself' does",
);

// Known false-positive shapes the rule must stay quiet on. Each one is a real
// pattern from the library — quoting the user's own trigger words is the
// recommended way to write a description, so pronouns inside quotes are fine.
const NO_HIT_CASES = [
  ["double-quoted trigger phrase", 'Connects Asana. Use when the user says "connect my Asana" or "set up my board".'],
  ["single-quoted trigger phrase", "Connects Xero. Use when the user says 'connect my Xero' or 'help me with invoices'."],
  ["apostrophe inside a quoted phrase", "Connects Medusa. Use when the user says 'I'm using Next.js + Medusa' or 'connect my store'."],
  ["possessive apostrophe outside quotes", "Reads the dialog's Copy button and the user's own account, then says 'connect my Asana'."],
  ["pronoun glued into a path or domain", "Opens app.asana.com/0/my-apps, verifies with GET /api/3/users/me, and posts to my.freshbooks.com/#/developer."],
  ["pronoun inside a hyphenated compound", "Supports a build-your-own-CRM team extending the workspace."],
  ["all-caps US is the country", "Tier-1 connector for US SMBs running W-2 payroll in AU/NZ/UK/US only."],
  ["lowercase i.e. is not the pronoun", "Formats ledger exports, i.e. the monthly statement bundle."],
];
for (const [label, value] of NO_HIT_CASES) {
  eq(evaluateDescription(value).map((h) => h.rule).join(","), "", `no hit: ${label}`);
}

// ...but unquoted first/second person in the skill's own prose still fires.
eq(
  evaluateDescription("Use when we need to refresh our contact list.").map((h) => h.rule).join(","),
  "description-first-person",
  "unquoted first person still fires",
);
eq(
  evaluateDescription("Trello requires you to create a Power-Up before setup.").map((h) => h.rule).join(","),
  "description-second-person",
  "unquoted second person still fires",
);

// The path/domain/compound exemption is judged on the whole whitespace-delimited
// chunk, so a slash between two prose words must NOT swallow the pronoun.
eq(
  evaluateDescription("Use when you/they disagree about the plan.").map((h) => h.rule).join(","),
  "description-second-person",
  "a slash between prose words does not suppress the pronoun",
);
eq(
  evaluateDescription("Handles read/write/your access levels.").map((h) => h.rule).join(","),
  "description-second-person",
  "a slash-separated word list does not suppress the pronoun",
);

// ---------------------------------------------------------------------------
// 3. The mode switch — CORE-98 flipped it to "enforce".
// ---------------------------------------------------------------------------
eq(DESCRIPTION_BUDGET_MODE, "enforce", "shipped mode is enforce (CORE-98 contract)");

const fixturePinned = loadPinnedSkillDirs(FIXTURE_LOCK);
const compliantOnly = fixtureHits.filter(
  (h) => h.relPath.includes("/compliant/") || h.relPath.includes("/at-limit/"),
);
eq(compliantOnly.length, 0, "compliant + at-limit fixtures produce no hits at all");
check(!descriptionBudgetFails(compliantOnly, "enforce"), "enforce mode: compliant fixtures pass");

const nonPinnedOverBudget = fixtureHits.filter((h) => h.relPath.includes("/over-budget/"));
eq(nonPinnedOverBudget.length, 1, "the non-pinned over-budget fixture produces exactly one hit");
check(
  descriptionBudgetFails(nonPinnedOverBudget, "enforce"),
  "enforce mode: an over-budget NON-PINNED fixture fails",
);
check(!descriptionBudgetFails(nonPinnedOverBudget, "report"), "report mode never fails, whatever the hits");

// Every failing hit must carry the reason string the enforcing output prints —
// that output path is all an author gets when CI goes red.
for (const hit of nonPinnedOverBudget) {
  check(
    typeof hit.reason === "string" && hit.reason.length > 0,
    `failing hit carries its rule reason [${hit.rule}]`,
  );
}

// The expand-phase flags are gone, and gone loudly rather than silently.
for (const flag of ["--write-description-baseline", "--descriptions-enforce"]) {
  check(typeof REMOVED_FLAGS[flag] === "string" && REMOVED_FLAGS[flag].length > 0, `removed flag ${flag} still explains itself`);
}
check(
  !existsSync(join(ROOT, "scripts", "description-budget-baseline.json")),
  "the description baseline file has been deleted",
);

// ---------------------------------------------------------------------------
// 4. The lock-pinned exemption (CORE-98).
// ---------------------------------------------------------------------------
// Resolution: a lock key is the upstream skill's name — sometimes the local
// directory verbatim, sometimes a display name that has to be slugified.
eq(slugifyLockKey("Expo UI SwiftUI"), "expo-ui-swiftui", "slugify: display name to directory name");
eq(slugifyLockKey("node"), "node", "slugify: an already-slug key is unchanged");

const realPinned = loadPinnedSkillDirs();
const realLock = JSON.parse(readFileSync(SKILLS_LOCK_FILE, "utf8"));
const realLockKeys = Object.keys(realLock.skills || {});
check(realLockKeys.length > 0, `the real skills-lock.json has entries (${realLockKeys.length})`);
for (const [dir, why] of [
  ["node", "key matches the directory verbatim"],
  ["fastify-best-practices", "key matches the directory (upstream folder is skills/fastify/)"],
  ["expo-ui-swiftui", "only the slugified display name matches"],
  ["vercel-react-view-transitions", "key matches (upstream folder is react-view-transitions)"],
]) {
  check(realPinned.has(dir), `pinned: ${dir} (${why})`);
}
// Every lock entry must resolve to a real skill directory. If one stops
// resolving, the rule starts hard-failing on vendored text nobody can edit —
// so this is the assertion that catches a widened lock before CI does.
const onDiskDirs = new Set(readSkillDescriptions().map((r) => r.relPath.split("/").at(-2)));
const unresolved = realLockKeys.filter((k) => !onDiskDirs.has(k) && !onDiskDirs.has(slugifyLockKey(k)));
eq(unresolved.length, 0, `every skills-lock.json key resolves to a skill directory${unresolved.length ? ` (${unresolved.join(", ")})` : ""}`);

// The resolver must NOT fall back to upstream's own folder name: those are
// plausible first-party names ("fastify", "react-best-practices") and the set is
// a name union with no check that the matched entry relates to the skill.
for (const ghost of ["fastify", "react-best-practices", "composition-patterns", "react-view-transitions"]) {
  check(!realPinned.has(ghost), `upstream folder name "${ghost}" is NOT an exemption alias`);
}
// First-party skills must never land in the exempt set.
for (const dir of ["ghl-connector", "xero-connector", "ai-ops-architect"]) {
  check(!realPinned.has(dir), `not pinned: first-party skill ${dir}`);
}
check(existsSync(SKILLS_LOCK_FILE), "SKILLS_LOCK_FILE points at a lock that exists");
eq(loadPinnedSkillDirs(join(ROOT, "no-such-lock.json")).size, 0, "a missing lock exempts nothing");

// Partition on the fixtures: the pinned fixture is exempt, the identical
// non-pinned one still fails.
const fixturePart = partitionDescriptionHits(fixtureHits, fixturePinned);
eq(
  fixturePart.exempt.map((h) => h.relPath.split("/").at(-2)).join(","),
  "vendored-over-budget",
  "partition: only the lock-pinned fixture is exempt",
);
check(
  fixturePart.failing.some((h) => h.relPath.includes("/over-budget/")),
  "partition: the non-pinned over-budget fixture stays in the failing bucket",
);
check(descriptionBudgetFails(fixturePart.failing, "enforce"), "enforce: the failing bucket still fails");
check(
  !descriptionBudgetFails(
    partitionDescriptionHits(
      fixtureHits.filter((h) => h.relPath.includes("/vendored-over-budget/")),
      fixturePinned,
    ).failing,
    "enforce",
  ),
  "enforce: a pinned fixture's violation alone does NOT fail",
);
// Exempt does not mean unscanned — the hit still exists, with its detail.
const exemptHit = fixturePart.exempt[0];
check(!!exemptHit && exemptHit.chars > DESCRIPTION_MAX_CHARS, "exempt hit is still measured and reported");
eq(
  partitionDescriptionHits(fixtureHits, new Set()).exempt.length,
  0,
  "an empty pinned set exempts nothing",
);
eq(
  fixturePart.exempt.length + fixturePart.failing.length,
  fixtureHits.length,
  "partition is total: every hit lands in exactly one bucket",
);

// ---------------------------------------------------------------------------
// 5. The real library — the CI-green guarantee.
// ---------------------------------------------------------------------------
const libraryHits = auditDescriptions();
const { exempt: libraryExempt, failing: libraryFailing } = partitionDescriptionHits(libraryHits, realPinned);

eq(
  libraryFailing.length,
  0,
  `enforce: zero first-party description violations in skills/**${libraryFailing.length ? ` (${libraryFailing.map((h) => `${h.relPath} [${h.rule}]`).join(", ")})` : ""}`,
);
check(!descriptionBudgetFails(libraryFailing), "enforce: skills/** keeps CI green");
check(
  libraryExempt.length === libraryHits.length,
  `every remaining violation is vendored and lock-pinned (${libraryExempt.length}/${libraryHits.length})`,
);

// The exemption is derived from the lock, not from a list in this repo — so
// every exempt skill must be findable in skills-lock.json itself.
// Exact key match, not a substring scan: `node` is a substring of the unrelated
// key `nodejs-core`, so a substring test would pass for the wrong reason.
const lockKeyAliases = new Set(realLockKeys.flatMap((k) => [k, slugifyLockKey(k)]));
for (const dir of new Set(libraryExempt.map((h) => h.relPath.split("/").at(-2)))) {
  check(lockKeyAliases.has(dir), `exempt skill ${dir} matches a skills-lock.json key exactly`);
}

// Every skill has a parseable description — a skill the parser can't read would
// silently escape the rule.
const readings = readSkillDescriptions();
check(readings.length > 100, `read every skill in the library (${readings.length} SKILL.md files)`);
const unreadable = readings.filter((r) => r.value === null);
eq(unreadable.length, 0, `every skills/**/SKILL.md has a parseable frontmatter description${unreadable.length ? ` (${unreadable.map((r) => r.relPath).join(", ")})` : ""}`);

// The fixtures live outside skills/, so the real scan can never see them.
check(
  !libraryHits.some((h) => h.relPath.includes("__fixtures__")),
  "fixtures are outside the scanned skills/ tree",
);

// ---------------------------------------------------------------------------
// 6. Exit codes — the contract CI actually consumes.
// ---------------------------------------------------------------------------
// Everything above tests the rule's functions. What makes a build red is
// main()'s wiring: partition -> descriptionBudgetFails(failing) -> exit 1.
// Passing the unpartitioned hits at that last step would fail every build and
// not one assertion above would notice, so the script is run for real.
//
// audit-skills.mjs derives its ROOT from its own location, so a copy of it in
// <sandbox>/scripts/ audits <sandbox>/skills/ — a whole disposable library
// whose contents this test controls, exercised through a real execFileSync run
// rather than by importing main().
const runAudit = (cwd, args = ["--check"]) => {
  try {
    const stdout = execFileSync("node", [join(cwd, "scripts", "audit-skills.mjs"), ...args], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { status: 0, out: stdout };
  } catch (e) {
    return { status: e.status ?? -1, out: `${e.stdout || ""}${e.stderr || ""}` };
  }
};

const describe = (name, text) => `---\nname: ${name}\ndescription: ${text}\n---\n\n# ${name}\n`;
const WITHIN_BUDGET = "Does one thing. Use when the user asks for that thing.";
const OVER_BUDGET = `Does one thing, at length. ${"Filler prose that pads the description past the budget. ".repeat(12)}`;

// realpathSync matters: audit-skills.mjs only runs main() when process.argv[1]
// matches its own import.meta.url, and on macOS os.tmpdir() is a symlink
// (/var/folders/… -> /private/var/folders/…). Passing the un-resolved path
// makes the script import silently and exit 0 without auditing anything —
// which is exactly the false green this section exists to rule out.
const sandbox = realpathSync(mkdtempSync(join(tmpdir(), "core98-audit-")));
try {
  mkdirSync(join(sandbox, "scripts"), { recursive: true });
  copyFileSync(join(HERE, "audit-skills.mjs"), join(sandbox, "scripts", "audit-skills.mjs"));

  const addSkill = (name, description) => {
    mkdirSync(join(sandbox, "skills", name), { recursive: true });
    writeFileSync(join(sandbox, "skills", name, "SKILL.md"), describe(name, description));
  };
  // gatherStats reads this; the marker targets are simply skipped when absent.
  mkdirSync(join(sandbox, "skills"), { recursive: true });
  writeFileSync(join(sandbox, "skills", "SKILLS-LIST.md"), "| skill | what | example | tier |\n");
  writeFileSync(
    join(sandbox, "skills-lock.json"),
    `${JSON.stringify({ version: 1, skills: { "Sandbox Vendored": { source: "acme/skills", skillPath: "skills/whatever/SKILL.md", computedHash: "0".repeat(64) } } }, null, 2)}\n`,
  );

  addSkill("first-party-ok", WITHIN_BUDGET);
  const clean = runAudit(sandbox);
  eq(clean.status, 0, "exit code: a compliant library exits 0");
  check(clean.out.includes("vendored (lock-pinned) exemptions: 0"), "exit code: the exemptions section prints even at zero");

  // The pinned skill is over budget. Reported, never fatal.
  addSkill("sandbox-vendored", OVER_BUDGET);
  const vendored = runAudit(sandbox);
  eq(vendored.status, 0, "exit code: a lock-pinned skill's violation alone still exits 0");
  check(vendored.out.includes("vendored (lock-pinned) exemptions: 1"), "exit code: the pinned violation is counted as an exemption");
  check(vendored.out.includes("skills/sandbox-vendored/SKILL.md"), "exit code: the exempt skill is named in the output, not hidden");
  check(
    vendored.out.includes("(failing 0 / vendored-exempt 1)"),
    "exit code: the summary line separates failing from exempt",
  );

  // Same violation in a skill nobody pinned. Fatal, with the reason printed.
  addSkill("first-party-bloated", OVER_BUDGET);
  const bad = runAudit(sandbox);
  eq(bad.status, 1, "exit code: an over-budget NON-pinned skill exits 1");
  check(bad.out.includes("skills/first-party-bloated/SKILL.md"), "exit code: the failing skill is named");
  check(
    bad.out.includes("over the 500-character budget"),
    "exit code: the rule's reason is printed on the failure path",
  );
  check(
    vendored.out.includes("skills/sandbox-vendored/SKILL.md") && bad.out.includes("vendored (lock-pinned) exemptions: 1"),
    "exit code: the exemption survives alongside a failure — a red build still lists it",
  );

  // The removed expand-phase flags refuse rather than no-op.
  for (const flag of Object.keys(REMOVED_FLAGS)) {
    const removed = runAudit(sandbox, ["--check", flag]);
    eq(removed.status, 2, `exit code: ${flag} exits 2 instead of being ignored`);
    check(removed.out.includes(flag), `exit code: ${flag} names itself in the refusal`);
  }
} finally {
  rmSync(sandbox, { recursive: true, force: true });
}

// The real repo, end to end: the run CI performs must be green.
const realRun = runAudit(ROOT);
eq(realRun.status, 0, "exit code: `audit-skills.mjs --check` on this repo exits 0");
check(
  realRun.out.includes(`vendored (lock-pinned) exemptions: ${libraryExempt.length}`),
  `exit code: the real run lists all ${libraryExempt.length} vendored exemptions`,
);

process.exit(failed ? 1 : 0);
