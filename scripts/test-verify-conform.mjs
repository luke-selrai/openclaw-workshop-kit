#!/usr/bin/env node
// Regression test for the stale-kit-home rules in verify-conform.mjs.
// Reads scripts/__fixtures__/conform-stale.md and asserts each rule fires on the
// expected line. The fixture is on the verify-conform allowlist so the main
// path-conform pass does not flag it. Mirrors scripts/test-anti-patterns.mjs.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { checkWindowsNodePath } from "./verify-conform.mjs";

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

// ---- checkWindowsNodePath (slice #387) -----------------------------------
// A body in the correct gated in-session-refresh shape.
const GOOD_WIN = [
  "   - On **Windows**, install it with winget, then make it usable in THIS session:",
  "",
  "         winget install --id OpenJS.NodeJS.LTS -e --source winget",
  "",
  "     Refresh the PATH and check Node in ONE PowerShell command:",
  "",
  "         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); node --version",
  "",
  "     That changes the PATH for this process only — it never writes to the registry.",
  "     For the rest of setup, prepend the same refresh — e.g. the npx install becomes:",
  "",
  "         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); npx @louphq/install selr-ai/workshop-kit --token loupit_...",
  "",
  "     ONLY if `node --version` still fails after that refresh: tell me to fully quit",
  "     and reopen Claude Desktop, then say I'm ready.",
  "",
  "   - If neither package manager works, open https://nodejs.org in the browser",
  "     (Playwright) and download the LTS installer for me automatically.",
].join("\n");

// Each mutation should break exactly the property it removes.
//
// There is deliberately no "split npx invocation" case any more: ADR-0001 §1
// made the GitHub-clone door co-equal with Loup, so requiring the PATH refresh
// on an `npx @louphq/install` line would fail every conformant document that
// never runs the Loup installer. The clause was removed from the checker, and
// the case that proved it fired went with it — a bad case for a rule that no
// longer exists would pass for the wrong reason.
const BAD_CASES = [
  ["no winget", GOOD_WIN.replace(/winget install --id OpenJS\.NodeJS\.LTS/, "choco install nodejs-lts")],
  ["no user-scope refresh", GOOD_WIN.replaceAll(" + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')", "")],
  ["split node invocation", GOOD_WIN.replace("'); node --version", "')\n         node --version")],
  ["speculative reopen", GOOD_WIN.replace(/ONLY if `node --version` still fails after that refresh: tell me to fully quit\n     and reopen/, "tell me to fully quit\n     and reopen")],
  ["no playwright fallback", GOOD_WIN.replace(/\(Playwright\) and download the LTS installer for me automatically\./, "and download it.")],
];

const good = checkWindowsNodePath(GOOD_WIN);
if (!good.ok) {
  console.error(`FAIL windows-node-path good-body: expected ok, got — ${good.detail}`);
  failed = true;
} else {
  console.log("PASS windows-node-path: well-formed Windows branch accepted");
}

for (const [name, body] of BAD_CASES) {
  const res = checkWindowsNodePath(body);
  if (res.ok) {
    console.error(`FAIL windows-node-path "${name}": expected the check to fail, but it passed`);
    failed = true;
  } else {
    console.log(`PASS windows-node-path "${name}": rejected as expected`);
  }
}

process.exit(failed ? 1 : 0);
