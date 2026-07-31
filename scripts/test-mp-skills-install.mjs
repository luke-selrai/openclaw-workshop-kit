#!/usr/bin/env node
// Regression test for the Matt Pocock skills-install rules in
// check-mp-skills-install.mjs (LOUP-19). Imports the checker's own
// evaluateInstallContract() (one source of truth — no mirrored regexes) and
// asserts:
//   1. The real docs/start/setup.md power-user-skills step satisfies every rule.
//   2. The deliberately broken fixture (the pre-fix step: stale `diagnose`
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

// 1. The real power-user-skills step must satisfy the full contract.
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
    check(!pass, "fixture: the broken power-user-skills step is rejected overall");
    const seen = new Set(rules.map((r) => r.id));
    for (const r of RULES) check(seen.has(r.id), `fixture: rule [${r.id}] is evaluated`);
    for (const r of rules) check(!r.ok, `fixture [${r.id}]: detector fires (expected fail)`);
  }
}

// 2b. The slice must end at the power-user-skills ITEM, not at the end of Step
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
