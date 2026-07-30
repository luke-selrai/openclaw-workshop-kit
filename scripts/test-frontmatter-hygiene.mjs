#!/usr/bin/env node
// Regression test for check-frontmatter-hygiene.mjs (CORE-92).
//
// Two halves, both required:
//   - the real skills/ tree passes every rule (the acceptance criterion:
//     0 name mismatches, 0 nonstandard keys);
//   - a deliberately broken fixture tree fires every rule, so each detector is
//     proven to actually fire rather than being vacuously green.

import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  evaluateFrontmatter,
  parseFrontmatter,
  STANDARD_KEYS,
} from "./check-frontmatter-hygiene.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const REAL_SKILLS = resolve(HERE, "..", "skills");
const FIXTURES = join(HERE, "__fixtures__", "frontmatter-hygiene");

let failed = false;

function check(label, condition, detail = "") {
  if (condition) {
    console.log(`PASS ${label}`);
  } else {
    console.error(`FAIL ${label}${detail ? `: ${detail}` : ""}`);
    failed = true;
  }
}

// --- The real library is clean -------------------------------------------

const real = evaluateFrontmatter(REAL_SKILLS);
check(
  "real-tree-scanned",
  real.skills.length > 0,
  `expected to find skills under ${REAL_SKILLS}`,
);
check(
  "real-tree-clean",
  real.violations.length === 0,
  real.violations.map((v) => `${v.relPath} [${v.rule}] ${v.detail}`).join(" | "),
);

// --- Each rule fires on the broken fixture tree ---------------------------

const fixture = evaluateFrontmatter(FIXTURES);
const bySkill = new Map();
for (const v of fixture.violations) {
  if (!bySkill.has(v.skill)) bySkill.set(v.skill, []);
  bySkill.get(v.skill).push(v);
}

const rulesFor = (skill) => (bySkill.get(skill) ?? []).map((v) => v.rule);

check(
  "fixture-good-skill-passes",
  !bySkill.has("good-skill"),
  `good-skill unexpectedly flagged: ${JSON.stringify(rulesFor("good-skill"))}`,
);
check(
  "fixture-name-mismatch-fires",
  rulesFor("mismatched-name").includes("name-matches-dirname"),
  `got ${JSON.stringify(rulesFor("mismatched-name"))}`,
);
check(
  "fixture-nonstandard-keys-fire",
  rulesFor("nonstandard-keys").filter((r) => r === "standard-keys-only").length === 2,
  `expected 2 standard-keys-only hits, got ${JSON.stringify(rulesFor("nonstandard-keys"))}`,
);
check(
  "fixture-missing-frontmatter-fires",
  rulesFor("no-frontmatter").includes("frontmatter-present"),
  `got ${JSON.stringify(rulesFor("no-frontmatter"))}`,
);

// A missing frontmatter block reports once — it must not also cascade into a
// name-mismatch report for the same file.
check(
  "fixture-missing-frontmatter-reports-once",
  rulesFor("no-frontmatter").length === 1,
  `got ${JSON.stringify(rulesFor("no-frontmatter"))}`,
);

// --- Parser unit checks ---------------------------------------------------

const blockScalar = parseFrontmatter(
  ["---", "name: demo", "description: |", "  indented: not-a-key", "---", "# Body"].join("\n"),
);
check(
  "parser-ignores-indented-keys",
  blockScalar.keys.join(",") === "name,description",
  `got ${JSON.stringify(blockScalar.keys)}`,
);
check("parser-reads-name", blockScalar.name === "demo", `got ${blockScalar.name}`);

const quoted = parseFrontmatter(["---", "name: 'quoted-name'", "---"].join("\n"));
check("parser-strips-quotes", quoted.name === "quoted-name", `got ${quoted.name}`);

const noBlock = parseFrontmatter("# Just a heading\n");
check("parser-detects-missing-frontmatter", noBlock.hasFrontmatter === false);

// A stray body line at column 0 after the closing fence must not be counted.
const bodyKey = parseFrontmatter(
  ["---", "name: demo", "---", "", "note: this is body prose", ""].join("\n"),
);
check(
  "parser-stops-at-closing-fence",
  bodyKey.keys.join(",") === "name",
  `got ${JSON.stringify(bodyKey.keys)}`,
);

check(
  "standard-keys-exported",
  STANDARD_KEYS.has("name") && STANDARD_KEYS.has("metadata") && !STANDARD_KEYS.has("tools"),
);

process.exit(failed ? 1 : 0);
