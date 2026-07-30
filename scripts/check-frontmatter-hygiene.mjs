#!/usr/bin/env node
// Asserts the skill library's frontmatter hygiene invariants (CORE-92, under
// the CORE-91 skill-description revamp).
//
// Two failure modes this catches, both found by the 2026-07-30 library scan:
//
//   1. name mismatch      - skills/<dir>/SKILL.md declares a frontmatter `name`
//                           that isn't <dir>. The kit's discovery surfaces
//                           (skills/SKILLS-LIST.md, docs/skills/README.md) all
//                           address skills by directory name, so a divergent
//                           frontmatter name means the documented handle and
//                           the invocable handle are different strings.
//   2. nonstandard keys   - frontmatter carries a key outside the agreed set.
//                           Ad-hoc keys are invisible to every consumer that
//                           reads frontmatter, so information parked in one is
//                           information lost.
//
// Neither rule is new policy: CONTRIBUTING.md §1 already requires `name` to
// match the directory name exactly and defines the frontmatter schema. This is
// the enforcement that section never had. STANDARD_KEYS is the tolerated set
// listed there — the two are kept in lockstep, and widening the set means
// editing both together.
//
// Usage:
//   node scripts/check-frontmatter-hygiene.mjs            # exit 1 on any violation
//   node scripts/check-frontmatter-hygiene.mjs --verbose  # also print every passing skill

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DEFAULT_SKILLS_DIR = join(ROOT, "skills");

export const STANDARD_KEYS = new Set([
  "name",
  "description",
  "metadata",
  "allowed-tools",
  "license",
  "version",
  "tags",
  "source",
  "category",
  "risk",
  "date_added",
  "requires",
  "argument-hint",
  "user_invocable",
  "disable-model-invocation",
]);

// A top-level frontmatter key sits at column 0. Nested mapping keys and YAML
// sequence items are indented, and block-scalar bodies (`description: |`) are
// indented too, so the column-0 anchor is what separates a real key from value
// content that happens to contain a colon.
const TOP_LEVEL_KEY = /^([A-Za-z0-9_-]+)\s*:\s*(.*)$/;

/**
 * Extract top-level frontmatter keys and the declared `name` from a SKILL.md.
 * Returns `{ hasFrontmatter, keys, name }`; `name` is null when absent.
 */
export function parseFrontmatter(text) {
  const lines = text.split(/\r?\n/);
  if (lines[0]?.trim() !== "---") {
    return { hasFrontmatter: false, keys: [], name: null };
  }

  const keys = [];
  let name = null;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i].trim() === "---") break;
    const match = TOP_LEVEL_KEY.exec(lines[i]);
    if (!match) continue;
    const [, key, rawValue] = match;
    keys.push(key);
    if (key === "name") name = stripQuotes(rawValue.trim());
  }

  return { hasFrontmatter: true, keys, name };
}

function stripQuotes(value) {
  const quoted = /^(['"])([\s\S]*)\1$/.exec(value);
  return quoted ? quoted[2] : value;
}

/**
 * Evaluate every skills/<dir>/SKILL.md under `skillsDir`.
 * Returns `{ skills, violations }` where each violation is
 * `{ rule, skill, relPath, detail }`.
 */
export function evaluateFrontmatter(skillsDir = DEFAULT_SKILLS_DIR) {
  const skillDirs = readdirSync(skillsDir)
    .filter((name) => {
      const p = join(skillsDir, name);
      return statSync(p).isDirectory() && existsSync(join(p, "SKILL.md"));
    })
    .sort();

  const violations = [];
  for (const skill of skillDirs) {
    const relPath = `skills/${skill}/SKILL.md`;
    const { hasFrontmatter, keys, name } = parseFrontmatter(
      readFileSync(join(skillsDir, skill, "SKILL.md"), "utf8"),
    );

    if (!hasFrontmatter) {
      violations.push({
        rule: "frontmatter-present",
        skill,
        relPath,
        detail: "no YAML frontmatter block at the top of the file",
      });
      continue;
    }

    if (name === null) {
      violations.push({
        rule: "name-matches-dirname",
        skill,
        relPath,
        detail: `frontmatter has no \`name\` key (expected \`${skill}\`)`,
      });
    } else if (name !== skill) {
      violations.push({
        rule: "name-matches-dirname",
        skill,
        relPath,
        detail: `frontmatter name \`${name}\` does not match directory \`${skill}\``,
      });
    }

    const nonStandard = keys.filter((key) => !STANDARD_KEYS.has(key));
    for (const key of nonStandard) {
      violations.push({
        rule: "standard-keys-only",
        skill,
        relPath,
        detail: `nonstandard frontmatter key \`${key}\` — move its content into the body or a standard key`,
      });
    }
  }

  return { skills: skillDirs, violations };
}

function main() {
  const args = process.argv.slice(2);
  const verbose = args.includes("--verbose");

  const { skills, violations } = evaluateFrontmatter(DEFAULT_SKILLS_DIR);

  console.log("Skill frontmatter hygiene");
  console.log("=========================");
  console.log(`Skills scanned : ${skills.length}`);
  console.log("");

  if (violations.length === 0) {
    console.log(`✓ ${skills.length} skill(s): name matches directory, standard keys only.`);
    if (verbose) for (const s of skills) console.log(`     - ${s}`);
    return;
  }

  console.log(`❌ Frontmatter violations (${violations.length}):`);
  for (const v of violations) {
    console.log(`   ${v.relPath} [${v.rule}]`);
    console.log(`     ${v.detail}`);
  }
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main();
}
