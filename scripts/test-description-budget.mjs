#!/usr/bin/env node
// Regression test for the description-budget rule in audit-skills.mjs (CORE-93).
// Imports the audit script's own functions (one source of truth — no mirrored
// regexes) and asserts:
//   1. The frontmatter description parser handles every YAML scalar style the
//      library actually uses (plain, quoted, literal/folded block, multi-line).
//   2. Each rule fires on its own fixture skill and stays silent on the
//      compliant + exactly-at-the-limit fixtures.
//   3. In ENFORCING mode the over-budget fixture fails and the compliant
//      fixture passes; in REPORT-ONLY mode neither fails.
//   4. The shipped baseline covers the real library, so CI is green today.
// Follows scripts/test-resilient-install.mjs's PASS/FAIL + fixture convention.

import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  extractDescription,
  evaluateDescription,
  auditDescriptions,
  readSkillDescriptions,
  classifyDescriptionHits,
  descriptionBudgetFails,
  loadDescriptionBaseline,
  baselineWriteBlockedReason,
  DESCRIPTION_MAX_CHARS,
  DESCRIPTION_BUDGET_MODE,
  DESCRIPTION_RULES,
} from "./audit-skills.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(HERE, "__fixtures__", "descriptions");

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
// 3. The mode switch CORE-98 flips.
// ---------------------------------------------------------------------------
const compliantOnly = fixtureHits.filter(
  (h) => h.relPath.includes("/compliant/") || h.relPath.includes("/at-limit/"),
);
check(descriptionBudgetFails(fixtureHits, "enforce"), "enforce mode: over-budget fixture fails");
eq(compliantOnly.length, 0, "compliant + at-limit fixtures produce no hits at all");
check(!descriptionBudgetFails(compliantOnly, "enforce"), "enforce mode: compliant fixtures pass");
check(!descriptionBudgetFails(fixtureHits, "report"), "report mode: violations never fail CI");
check(
  DESCRIPTION_BUDGET_MODE === "report" || DESCRIPTION_BUDGET_MODE === "enforce",
  `shipped mode is a known value (${DESCRIPTION_BUDGET_MODE})`,
);

// Re-baselining is a report-mode tool only. Once CORE-98 flips the mode, the
// baseline is gone on purpose — re-minting it would quietly undo the contract.
eq(baselineWriteBlockedReason("report"), null, "baseline write allowed in report mode");
check(
  typeof baselineWriteBlockedReason("enforce") === "string" &&
    baselineWriteBlockedReason("enforce").includes("report mode only"),
  "baseline write blocked in enforce mode, with a reason",
);
eq(
  baselineWriteBlockedReason() === null,
  DESCRIPTION_BUDGET_MODE === "report",
  "the guard follows the shipped mode",
);

// ---------------------------------------------------------------------------
// 4. Baseline classification.
// ---------------------------------------------------------------------------
const sampleBaseline = {
  violations: {
    "scripts/__fixtures__/descriptions/over-budget/SKILL.md": ["description-over-budget"],
    "skills/gone/SKILL.md": ["description-over-budget"],
  },
};
const classified = classifyDescriptionHits(fixtureHits, sampleBaseline);
eq(classified.known.length, 1, "classify: baselined hit counted as known");
eq(classified.novel.length, fixtureHits.length - 1, "classify: everything else counted as novel");
eq(classified.stale.map((s) => s.relPath).join(","), "skills/gone/SKILL.md", "classify: fixed baseline entry reported as stale");
eq(classifyDescriptionHits(fixtureHits, { violations: {} }).novel.length, fixtureHits.length, "classify: empty baseline makes every hit novel");

// ---------------------------------------------------------------------------
// 5. The real library — the CI-green guarantee.
// ---------------------------------------------------------------------------
const libraryHits = auditDescriptions();
const baseline = loadDescriptionBaseline();

if (DESCRIPTION_BUDGET_MODE === "report") {
  const { novel, known } = classifyDescriptionHits(libraryHits, baseline);
  check(known.length > 0, `baseline is populated (${known.length} known violations)`);
  check(novel.length === 0, `no un-baselined violations in skills/** (${novel.length} novel)`);
  check(!descriptionBudgetFails(libraryHits, DESCRIPTION_BUDGET_MODE), "report-only: skills/** keeps CI green");
} else {
  // CORE-98 contract state: baseline deleted, library must be clean.
  eq(Object.keys(baseline.violations).length, 0, "enforce mode: baseline has been dropped");
  eq(libraryHits.length, 0, "enforce mode: skills/** has zero description violations");
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

process.exit(failed ? 1 : 0);
