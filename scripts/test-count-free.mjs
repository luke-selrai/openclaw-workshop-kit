#!/usr/bin/env node
// Regression test for the count-free rule in audit-skills.mjs (CORE-116).
//
// The rule is a POSITIVE assertion standing in for an absence: docs/start/setup.md
// is left out of TARGET_FILES so no marker ever writes a number into the pasted
// prompt, and this rule proves nothing has hand-written one either. A rule like
// that is worthless without a seeded violation, because it passes trivially on
// any document that happens not to mention skills.
//
// Asserts:
//   1. the real count-free file(s) are clean
//   2. a fixture that quotes counts fails on exactly the lines that quote them
//   3. the sentences a setup document legitimately contains ("20-30 minutes",
//      "the 4 power-user skills") do NOT fire

import { auditCountFree, COUNT_FREE_FILES } from "./audit-skills.mjs";

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};

// 1. The real surfaces.
const realHits = auditCountFree();
check(realHits.length === 0,
  `real count-free surfaces are clean (${COUNT_FREE_FILES.join(", ")})${realHits.length ? ` — ${realHits.map((h) => `${h.relPath}:${h.line}`).join(", ")}` : ""}`);

// 2 + 3. The seeded fixture. Line numbers are asserted exactly, which is what
// pins down BOTH halves: the counts that must fire and the prose that must not.
const EXPECTED = [
  [7, "no-count-markers"], // caught by the marker rule; the number inside a
                           // marker is glued to the closing comment, so the
                           // prose rule does not double-report it
  [8, "no-hard-count"],
  [9, "no-hard-count"],
  [10, "no-hard-count"],
];
const hits = auditCountFree(["scripts/__fixtures__/count-free-bad.md"]).map((h) => `${h.line}:${h.rule}`);
const want = EXPECTED.map(([l, r]) => `${l}:${r}`);
check(hits.join(",") === want.join(","), `fixture: expected [${want.join(", ")}], got [${hits.join(", ")}]`);

process.exit(failed ? 1 : 0);
