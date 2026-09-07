#!/usr/bin/env node
// Regression test for the Matt Pocock skills-install rules in
// check-mp-skills-install.mjs (LOUP-19). Imports the checker's own
// evaluateInstallContract() (one source of truth — no mirrored regexes) and
// asserts:
//   1. The real docs/start/setup.md Matt Pocock skills step satisfies every rule.
//   2. The deliberately broken fixture (the pre-fix step: stale `diagnose`
//      selector, no self-heal, "network hiccup" hand-wave) FAILS every rule —
//      proving each detector actually fires.
//   3. fetchLiveSkillNames() parses both flat and category-nested tree shapes,
//      and fetchLiveCoreSkillNames() returns exactly the engineering/ +
//      productivity/ buckets (via an injected fake fetch — no network in tests).
// Follows the scripts/test-resilient-install.mjs convention.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  evaluateInstallContract,
  extractStepBody,
  fetchLiveSkillNames,
  fetchLiveCoreSkillNames,
  CORE_BUCKETS,
  EXPECTED_SKILLS,
  RULES,
} from "./check-mp-skills-install.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "..");
const FIXTURE = join(HERE, "__fixtures__", "mp-skills-install-bad.md");

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};

// 1. The real Matt Pocock skills step must satisfy the full contract.
{
  const rel = "docs/start/setup.md";
  const { body, error } = extractStepBody(readFileSync(join(ROOT, rel), "utf8"));
  if (error) {
    check(false, `${rel}: ${error}`);
  } else {
    const { pass, rules } = evaluateInstallContract(body);
    check(pass, `${rel}: all install-contract rules pass`);
    for (const r of rules) check(r.ok, `${rel} [${r.id}]: ${r.detail}`);
  }
}

// 2. The broken fixture must fail every rule — proves each detector fires
//    rather than the real doc passing by accident.
{
  const { body, error } = extractStepBody(readFileSync(FIXTURE, "utf8"));
  if (error) {
    check(false, `fixture anchors: ${error}`);
  } else {
    const { pass, rules } = evaluateInstallContract(body);
    check(!pass, "fixture: the broken Matt Pocock skills step is rejected overall");
    const seen = new Set(rules.map((r) => r.id));
    for (const r of RULES) check(seen.has(r.id), `fixture: rule [${r.id}] is evaluated`);
    for (const r of rules) check(!r.ok, `fixture [${r.id}]: detector fires (expected fail)`);
  }
}

// 2b. The slice must end at the Matt Pocock skills ITEM, not at the end of Step
//     6. The old `### Step 7` end anchor was correct only by accident — item 4
//     happens to be last today — so a fifth item would have silently widened
//     the slice and let unrelated prompt text satisfy this step's rules. Seed
//     exactly that: an item 5 stuffed with the phrases self-heal-listing,
//     rename-resolution and recheck-after-heal look for.
{
  const real = readFileSync(join(ROOT, "docs/start/setup.md"), "utf8");
  const seeded = real.replace(
    "### Step 7 — The one restart",
    "5. **Something else** — re-check the disk, list what the repo offers now\n" +
      "   (`npx -y skills@latest add mattpocock/skills -l`), match renamed skills\n" +
      "   once resolved, and re-run.\n\n### Step 7 — The one restart",
  );
  const { body, error } = extractStepBody(seeded);
  check(!error && !body.includes("Something else"),
    "slice stops at the next numbered item, not at the end of Step 6");
}

// 3. Live-listing parser handles both upstream tree shapes with a fake fetch.
{
  const treeOf = (paths) => ({
    ok: true,
    json: async () => ({ tree: paths.map((p) => ({ path: p })) }),
  });

  // Category-nested (upstream's current layout) + flat entries mixed. Every
  // expected skill sits in its real bucket, plus one flat entry, one
  // in-progress entry and one misc entry that must NOT count as core.
  const PRODUCTIVITY = EXPECTED_SKILLS.slice(0, 7);
  const ENGINEERING = EXPECTED_SKILLS.slice(7);
  const fakeFetch = async () =>
    treeOf([
      ...PRODUCTIVITY.map((s) => `skills/productivity/${s}/SKILL.md`),
      ...ENGINEERING.map((s) => `skills/engineering/${s}/SKILL.md`),
      "skills/flat-one/SKILL.md", // flat shape must also parse
      "skills/in-progress/claude-handoff/SKILL.md", // present upstream, not core
      "skills/misc/setup-pre-commit/SKILL.md", // present upstream, not core
      "skills/engineering/diagnosing-bugs/README.md", // non-SKILL.md ignored
      "skills/engineering/tdd/references/SKILL.md", // nested deeper: still tdd's bucket
      "docs/SKILL.md", // outside skills/ ignored
    ]);

  const names = await fetchLiveSkillNames(fakeFetch);
  for (const s of EXPECTED_SKILLS) check(names.has(s), `live parser: finds [${s}]`);
  check(names.has("flat-one"), "live parser: flat skills/<name>/SKILL.md parses");
  check(!names.has("docs"), "live parser: ignores SKILL.md outside skills/");

  // The core set is exactly the two buckets — nothing from in-progress/, misc/
  // or a flat entry leaks in, and nothing expected is left out.
  check(CORE_BUCKETS.join(",") === "engineering,productivity", "core buckets are engineering + productivity");
  const core = await fetchLiveCoreSkillNames(fakeFetch);
  check([...core].sort().join(",") === [...EXPECTED_SKILLS].sort().join(","),
    "live core set: equals EXPECTED_SKILLS exactly (no in-progress/misc/flat leakage)");
  check(!core.has("references"), "live core set: a SKILL.md nested inside a skill folder does not create a core entry");

  // An upstream addition to a core bucket shows up as a name outside EXPECTED_SKILLS.
  const grown = await fetchLiveCoreSkillNames(async () =>
    treeOf(["skills/engineering/brand-new/SKILL.md", ...ENGINEERING.map((s) => `skills/engineering/${s}/SKILL.md`)]),
  );
  check(grown.has("brand-new") && !EXPECTED_SKILLS.includes("brand-new"),
    "live core set: an upstream addition reads as not-yet-expected");

  // A rename shows up as an absent expected name.
  const renamed = await fetchLiveSkillNames(async () =>
    treeOf(["skills/engineering/diagnosing-bugs-v2/SKILL.md"]),
  );
  check(!renamed.has("diagnosing-bugs"), "live parser: a renamed skill reads as missing");

  // API failure throws rather than returning an empty (falsely green) set.
  let threw = false;
  try {
    await fetchLiveSkillNames(async () => ({ ok: false, status: 403 }));
  } catch {
    threw = true;
  }
  check(threw, "live parser: non-2xx API response throws");
}

process.exit(failed ? 1 : 0);
