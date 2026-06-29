#!/usr/bin/env node
// Regression test for the stale-kit-home rules in verify-conform.mjs.
// Reads scripts/__fixtures__/conform-stale.md and asserts each rule fires on the
// expected line. The fixture is on the verify-conform allowlist so the main
// path-conform pass does not flag it. Mirrors scripts/test-anti-patterns.mjs.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURE = join(HERE, "__fixtures__", "conform-stale.md");

// These mirror STALE_PATTERNS in verify-conform.mjs. Kept in sync deliberately:
// if a rule changes there, this test must be updated, which is the point.
const RULES = [
  { id: "tilde-home", regex: /~\/workshop-kit/, expectedLine: 7 },
  { id: "HOME-home", regex: /\$HOME\/workshop-kit/, expectedLine: 8 },
  { id: "userprofile-home", regex: /%USERPROFILE%\\workshop-kit/, expectedLine: 9 },
  { id: "windows-users-home", regex: /[A-Za-z]:\\Users\\[^\\]*\\workshop-kit/, expectedLine: 10 },
  { id: "whatsapp-clone-fallback", regex: /~\/claude-workshop-kit\/whatsapp/, expectedLine: 11 },
];

const lines = readFileSync(FIXTURE, "utf8").split(/\r?\n/);
let failed = false;

for (const rule of RULES) {
  const hits = [];
  for (let i = 0; i < lines.length; i++) {
    if (rule.regex.test(lines[i])) hits.push(i + 1);
  }
  if (hits.length !== 1) {
    console.error(`FAIL ${rule.id}: expected exactly 1 hit, got ${hits.length} (lines: ${hits.join(",")})`);
    failed = true;
    continue;
  }
  if (hits[0] !== rule.expectedLine) {
    console.error(`FAIL ${rule.id}: expected hit on line ${rule.expectedLine}, got line ${hits[0]}`);
    failed = true;
    continue;
  }
  console.log(`PASS ${rule.id}: hit on line ${hits[0]} as expected`);
}

// Assert the fixture is allowlisted in verify-conform.mjs, so the main pass
// does not flag it.
const conformSrc = readFileSync(resolve(HERE, "verify-conform.mjs"), "utf8");
if (!conformSrc.includes("scripts/__fixtures__/conform-stale.md")) {
  console.error("FAIL allowlist: scripts/__fixtures__/conform-stale.md is not in STALE_ALLOWLIST");
  failed = true;
} else {
  console.log("PASS allowlist: fixture is allowlisted");
}

process.exit(failed ? 1 : 0);
