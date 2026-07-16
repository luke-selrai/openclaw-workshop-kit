#!/usr/bin/env node
// Regression test for the Matt Pocock skills-install rules in
// check-mp-skills-install.mjs (LOUP-19). Imports the checker's own
// evaluateInstallContract() (one source of truth — no mirrored regexes) and
// asserts:
//   1. The real skills/first-run-setup/SKILL.md Step 3 satisfies every rule.
//   2. The deliberately broken fixture (the pre-fix Step 3: stale `diagnose`
//      selector, no self-heal, "network hiccup" hand-wave) FAILS every rule —
//      proving each detector actually fires.
//   3. fetchLiveSkillNames() parses both flat and category-nested tree shapes
//      (via an injected fake fetch — no network in tests).
// Follows the scripts/test-resilient-install.mjs convention.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  evaluateInstallContract,
  extractStepBody,
  fetchLiveSkillNames,
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

// 1. The real Step 3 must satisfy the full contract.
{
  const rel = "skills/first-run-setup/SKILL.md";
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
    check(!pass, "fixture: broken Step 3 is rejected overall");
    const seen = new Set(rules.map((r) => r.id));
    for (const r of RULES) check(seen.has(r.id), `fixture: rule [${r.id}] is evaluated`);
    for (const r of rules) check(!r.ok, `fixture [${r.id}]: detector fires (expected fail)`);
  }
}

// 3. Live-listing parser handles both upstream tree shapes with a fake fetch.
{
  const treeOf = (paths) => ({
    ok: true,
    json: async () => ({ tree: paths.map((p) => ({ path: p })) }),
  });

  // Category-nested (upstream's current layout) + flat entries mixed.
  const fakeFetch = async () =>
    treeOf([
      "skills/productivity/grill-me/SKILL.md",
      "skills/productivity/handoff/SKILL.md",
      "skills/engineering/diagnosing-bugs/SKILL.md",
      "skills/teach/SKILL.md", // flat shape must also parse
      "skills/engineering/diagnosing-bugs/README.md", // non-SKILL.md ignored
      "docs/SKILL.md", // outside skills/ ignored
    ]);

  const names = await fetchLiveSkillNames(fakeFetch);
  for (const s of EXPECTED_SKILLS) check(names.has(s), `live parser: finds [${s}]`);
  check(!names.has("docs"), "live parser: ignores SKILL.md outside skills/");

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
