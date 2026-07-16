#!/usr/bin/env node
// Regression test for the install-narration rules in check-install-narration.mjs.
// Imports the checker's own evaluateNarration() (one source of truth — no
// mirrored regexes) and asserts:
//   1. Every real surface file satisfies every rule that applies to it.
//   2. A deliberately narration-free fixture FAILS every bootstrap-body rule
//      (each detector fires), and also fails the first-run and kit-rule
//      surfaces' rules — proving the real docs don't pass by accident.
// Follows scripts/test-resilient-install.mjs's PASS/FAIL + fixture convention.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { evaluateNarration, SURFACES } from "./check-install-narration.mjs";
import { extractBootstrapBody } from "./check-resilient-install.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "..");
const FIXTURE = join(HERE, "__fixtures__", "install-narration-bad.md");

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};

// 1. Every real surface must satisfy its full rule set.
for (const surface of SURFACES) {
  for (const rel of surface.files) {
    const { body, error } = surface.extract(readFileSync(join(ROOT, rel), "utf8"));
    if (error) {
      check(false, `${rel}: ${error}`);
      continue;
    }
    const { pass, rules } = evaluateNarration(surface.id, body);
    check(pass, `${rel} [${surface.id}]: all narration rules pass`);
    for (const r of rules) check(r.ok, `${rel} [${surface.id}/${r.id}]: ${r.detail}`);
  }
}

// 2. The bad fixture must fail every rule of every surface — proves each
//    detector actually fires. The fixture carries the bootstrap anchors so the
//    bootstrap-body extraction path is exercised too.
const fixtureText = readFileSync(FIXTURE, "utf8");
const { body: badBody, error: badErr } = extractBootstrapBody(fixtureText);
if (badErr) {
  check(false, `fixture anchors: ${badErr}`);
} else {
  for (const surface of SURFACES) {
    const text = surface.id === "bootstrap-body" ? badBody : fixtureText;
    const { pass, rules } = evaluateNarration(surface.id, text);
    check(!pass, `fixture [${surface.id}]: narration-free text is rejected overall`);
    for (const r of rules) {
      check(!r.ok, `fixture [${surface.id}/${r.id}]: detector fires (expected fail)`);
    }
  }
}

process.exit(failed ? 1 : 0);
