#!/usr/bin/env node
// Regression test for anti-pattern audit rules in audit-skills.mjs.
// Reads scripts/__fixtures__/anti-patterns.md directly and asserts both
// rules fire on the expected line numbers. The fixture itself is on the
// audit allowlist so the main audit pass does not see it.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURE = join(HERE, "__fixtures__", "anti-patterns.md");

const RULES = [
  { id: "www-authenticate-bearer", regex: /WWW-Authenticate:\s*Bearer/i, expectedLine: 8 },
  { id: "claude-mcp-authenticate-cli", regex: /claude\s+mcp\s+authenticate\b/, expectedLine: 11 },
];

const text = readFileSync(FIXTURE, "utf8");
const lines = text.split(/\r?\n/);
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

// Also assert the fixture is on the allowlist in audit-skills.mjs, so the
// main audit pass does not flag it.
const auditSrc = readFileSync(resolve(HERE, "audit-skills.mjs"), "utf8");
if (!auditSrc.includes("scripts/__fixtures__/anti-patterns.md")) {
  console.error("FAIL allowlist: scripts/__fixtures__/anti-patterns.md is not in ANTI_PATTERN_ALLOWLIST");
  failed = true;
} else {
  console.log("PASS allowlist: fixture is allowlisted");
}

process.exit(failed ? 1 : 0);
