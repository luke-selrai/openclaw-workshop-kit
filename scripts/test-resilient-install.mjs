#!/usr/bin/env node
// Regression test for the resilient-install rules in check-resilient-install.mjs.
// Imports the checker's own evaluateResilience() (one source of truth — no
// mirrored regexes) and asserts:
//   1. The real setup document's PASTED PROMPT satisfies every resilience rule.
//   2. A deliberately non-resilient fixture FAILS every rule (each detector fires).
// Follows scripts/test-verify-conform.mjs's PASS/FAIL + fixture convention, but
// imports the checker's evaluateResilience() instead of mirroring its regexes,
// so the rules have one source of truth.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  evaluateResilience,
  extractBootstrapBody,
  extractPromptBody,
  PRESENCE_RULES,
  BOOTSTRAP_COPIES,
} from "./check-resilient-install.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "..");
const FIXTURE = join(HERE, "__fixtures__", "resilient-install-bad.md");

const ALL_RULE_IDS = [...PRESENCE_RULES.map((r) => r.id), "no-escalation"];

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};

// 1. The real setup document must be fully resilient. Both the file list and the
//    slicing come from the checker itself, so this test cannot drift from what
//    CI actually enforces. Slicing matters as much here as in the checker: every
//    rule is a presence regex, so scanning the whole document would let the
//    attendee prose wrapped around the prompt satisfy a rule the prompt itself
//    had dropped, and this test would go green on a real regression.
for (const rel of BOOTSTRAP_COPIES) {
  const { body, error } = extractPromptBody(readFileSync(join(ROOT, rel), "utf8"));
  if (error) {
    check(false, `${rel}: ${error}`);
    continue;
  }
  const { pass, rules } = evaluateResilience(body);
  check(pass, `${rel}: all resilience rules pass`);
  for (const r of rules) check(r.ok, `${rel} [${r.id}]: ${r.detail}`);
}

// 2. The bad fixture must fail every rule — proves each detector actually fires
//    rather than the real doc passing by accident. The fixture predates the
//    one-document collapse and still carries the old anchors, so it is sliced
//    with extractBootstrapBody rather than the prompt-heading markers.
const { body: badBody, error: badErr } = extractBootstrapBody(readFileSync(FIXTURE, "utf8"));
if (badErr) {
  check(false, `fixture anchors: ${badErr}`);
} else {
  const { pass, rules } = evaluateResilience(badBody);
  check(!pass, "fixture: non-resilient body is rejected overall");
  const seen = new Set(rules.map((r) => r.id));
  for (const id of ALL_RULE_IDS) {
    check(seen.has(id), `fixture: rule [${id}] is evaluated`);
  }
  for (const r of rules) {
    check(!r.ok, `fixture [${r.id}]: detector fires (expected fail)`);
  }
}

process.exit(failed ? 1 : 0);
