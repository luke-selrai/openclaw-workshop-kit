#!/usr/bin/env node
// Regression test for verify-conform.mjs.
//
// Every rule in that checker is a regex over prose, so the only thing that
// proves a rule works is a SEEDED VIOLATION that makes it fail. Each section
// below therefore pairs a good input with a mutation that removes exactly one
// property, and asserts the checker rejects the mutation.
//
// Covered:
//   1. old-canon patterns fire on the fixtures (both the retired homes and the
//      CORE-116-inverted rules: hardcoded live kit homes, the dead workspace
//      folder, the dead first-run marker)
//   2. the setup.md section-scoped exemption, in BOTH directions
//   3. the baseline ratchet (new file fails, over-baseline fails, under-baseline
//      warns instead of failing)
//   4. the two-door canon (checkTwoDoorCanon) + the install-type question rule
//   5. the rift-test kit-side install artifacts (checkInstallArtifacts)
//   6. the Windows Node PATH branch (checkWindowsNodePath, slice #387)

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import {
  checkWindowsNodePath,
  checkTwoDoorCanon,
  checkNoInstallTypeQuestion,
  checkInstallArtifacts,
  scanOldCanon,
  setupLegacyLineWindow,
  evaluateOldCanonRatchet,
} from "./verify-conform.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const FIXTURE = join(HERE, "__fixtures__", "conform-stale.md");
const OLD_CANON_FIXTURE = join(HERE, "__fixtures__", "old-canon-bad.md");

let failed = false;
const check = (ok, label) => {
  if (!ok) failed = true;
  console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}`);
};

// ---- 1a. The retired-kit-home fixture -------------------------------------
// Exact (line, rule) pairs, asserted against the checker's own scanner rather
// than mirrored regexes.
const STALE_EXPECTED = [
  [7, "tilde-home"],
  [8, "HOME-home"],
  [9, "userprofile-home"],
  [10, "windows-users-home"],
  [11, "whatsapp-clone-fallback"],
  // The same line is also a hardcoded GitHub-door home under the inverted rules
  // — it was only ever a "fallback" because the clone path used to be dead.
  [11, "hardcoded-github-home"],
];
const staleHits = scanOldCanon(readFileSync(FIXTURE, "utf8")).map((h) => `${h.line}:${h.id}`);
check(
  staleHits.join(",") === STALE_EXPECTED.map(([l, id]) => `${l}:${id}`).join(","),
  `retired-home fixture: expected [${STALE_EXPECTED.map(([l, id]) => `${l}:${id}`).join(", ")}], got [${staleHits.join(", ")}]`,
);

// ---- 1b. The inverted (CORE-116) fixture ----------------------------------
const INVERTED_EXPECTED = [
  [10, "hardcoded-loup-home"],
  [11, "hardcoded-loup-home"], // the Windows backslash form of the same home
  [12, "hardcoded-github-home"],
  [13, "windows-github-home"],
  [14, "legacy-workspace-desktop"],
  [15, "legacy-workspace-home"],
  [16, "first-run-pending"],
];
const invertedHits = scanOldCanon(readFileSync(OLD_CANON_FIXTURE, "utf8")).map((h) => `${h.line}:${h.id}`);
check(
  invertedHits.join(",") === INVERTED_EXPECTED.map(([l, id]) => `${l}:${id}`).join(","),
  `inverted fixture: expected [${INVERTED_EXPECTED.map(([l, id]) => `${l}:${id}`).join(", ")}], got [${invertedHits.join(", ")}]`,
);

// Both fixtures must be allowlisted, or the main pass would flag them.
const conformSrc = readFileSync(resolve(HERE, "verify-conform.mjs"), "utf8");
for (const f of ["scripts/__fixtures__/conform-stale.md", "scripts/__fixtures__/old-canon-bad.md"]) {
  check(conformSrc.includes(f), `allowlist: ${f} is in OLD_CANON_ALLOWLIST`);
}

// ---- 2. setup.md section scoping -------------------------------------------
// The reviewer of PR #423 flagged that a file-level allowlist on the most
// attendee-facing document can hide a real regression. These two cases are the
// proof that the replacement is line-scoped: the SAME sentence is exempt inside
// a migration step and a violation in the completion banner.
const LEGACY_LINE = "Look in `~/Desktop/my-assistant` for the old install.";
const SETUP_SHAPE = (whereLegacyGoes) =>
  [
    "# Setup",
    "",
    "## The prompt",
    "",
    "### Step 1 — Read my current state",
    whereLegacyGoes === "step1" ? LEGACY_LINE : "Pick the mode from the manifest.",
    "",
    "### Step 9 — Verify gate",
    whereLegacyGoes === "step9" ? LEGACY_LINE : "Check the pointer block is there.",
    "",
    "## Before workshop day",
    whereLegacyGoes === "prose" ? LEGACY_LINE : "Install Node before you arrive.",
  ].join("\n");

for (const [where, expectHit] of [["step1", false], ["step9", true], ["prose", true]]) {
  const text = SETUP_SHAPE(where);
  const hits = scanOldCanon(text, { allowedLines: setupLegacyLineWindow(text) });
  check(
    (hits.length > 0) === expectHit,
    `setup section scoping: a legacy-workspace path in ${where} is ${expectHit ? "a violation" : "exempt"} (got ${hits.length} hit(s))`,
  );
}

// ---- 3. The baseline ratchet ------------------------------------------------
{
  const baseline = { "docs/legacy.md": 3 };
  const cases = [
    ["a clean tree passes", {}, 0, 1],
    ["a baselined file at its number passes", { "docs/legacy.md": 3 }, 0, 0],
    ["a baselined file under its number warns, never fails", { "docs/legacy.md": 1 }, 0, 1],
    ["a baselined file over its number FAILS", { "docs/legacy.md": 4 }, 1, 0],
    ["a NEW file with any reference FAILS", { "docs/legacy.md": 3, "skills/new/SKILL.md": 1 }, 1, 0],
  ];
  for (const [label, counts, wantFails, wantWarns] of cases) {
    const { failures, warnings } = evaluateOldCanonRatchet(counts, baseline);
    check(failures.length === wantFails && warnings.length === wantWarns,
      `ratchet: ${label} (failures=${failures.length}/${wantFails}, warnings=${warnings.length}/${wantWarns})`);
  }
}

// ---- 4. The two-door canon --------------------------------------------------
const GOOD_DOORS = [
  "### Step 2 — Get the kit",
  "",
  'Tell me only "Downloading your kit now." Which door it comes through is',
  "plumbing I never need to know about.",
  "",
  "Silently probe the repository, with a generous timeout:",
  "",
  "    GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/x/y.git HEAD",
  "",
  "**A. The probe succeeds → clone.** We ALWAYS take a fresh copy, never",
  "update-in-place:",
  "",
  "    GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/x/y.git",
  "",
  "**B. The probe is refused (authentication error / repository not found) → the",
  "kit comes through Loup.** Do NOT ask me for a GitHub password. Open my Loup",
  'dashboard, click "Get install command", and paste the line:',
  "",
  "    npx @louphq/install selrai-company/claude-workshop-kit --token loupit_...",
  "",
  "Even in UPDATE mode, always re-run my install command like this. If it is",
  "refused, have me mint a fresh command and paste the new line.",
  "",
  "**C. The probe times out or fails like a network problem → it is the wifi.**",
  "Never send me to Loup or ask for any token from this branch. Check I am",
  "online and probe again.",
].join("\n");

const DOOR_BAD_CASES = [
  ["no probe at all", GOOD_DOORS.replace(/    GIT_TERMINAL_PROMPT=0 git ls-remote[^\n]*/, "    (just try the clone and see what happens)")],
  ["probe without prompting disabled", GOOD_DOORS.replace("    GIT_TERMINAL_PROMPT=0 git ls-remote", "    git ls-remote")],
  ["clone without prompting disabled", GOOD_DOORS.replace("    GIT_TERMINAL_PROMPT=0 git clone", "    git clone")],
  ["no generous timeout", GOOD_DOORS.replace("with a generous timeout", "quickly")],
  ["no clone door", GOOD_DOORS.replace("git clone --depth 1", "git pull")],
  ["no Loup door", GOOD_DOORS.replace("npx @louphq/install selrai-company/claude-workshop-kit --token loupit_...", "ask someone for the files")],
  ["network branch sends me to Loup", GOOD_DOORS.replace("Never send me to Loup or ask for any token from this branch.", "Get a fresh token from Loup.")],
  ["asks for a GitHub password", GOOD_DOORS.replace("Do NOT ask me for a GitHub password.", "Ask me for my GitHub password.")],
  ["updates in place", GOOD_DOORS.replace("We ALWAYS take a fresh copy, never\nupdate-in-place", "Pull the latest changes").replace("always re-run my install command", "skip the install")],
  ["door is a question", `${GOOD_DOORS}\n\nFirst, ask me: is this a GitHub or Loup install?`],
  ["door is not declared plumbing", GOOD_DOORS.replace("plumbing I never need to know about.", "something I should understand.")],
];

const goodDoors = checkTwoDoorCanon(GOOD_DOORS);
check(goodDoors.ok, `two-door canon: a conformant Step 2 is accepted${goodDoors.ok ? "" : ` — ${goodDoors.detail}`}`);
for (const [name, body] of DOOR_BAD_CASES) {
  check(!checkTwoDoorCanon(body).ok, `two-door canon "${name}": rejected as expected`);
}

// The whole-document question rule, separately: a prompt can be clean while the
// prose around it asks the question.
check(checkNoInstallTypeQuestion("The probe decides which door to use.").ok,
  "install-type question: clean prose accepted");
for (const asked of [
  "Are you installing from GitHub or through Loup?",
  "Which install type do you have?",
  "Did you get the kit from Loup or from the repo?",
  "Do you have a Loup account?",
]) {
  check(!checkNoInstallTypeQuestion(asked).ok, `install-type question: "${asked}" rejected`);
}

// ---- 5. Install artifacts (kit-side half of the rift test) -----------------
const GOOD_ARTIFACTS = [
  "Copy `<kit home>/my-assistant/CLAUDE.md` to `~/.claude/selr-assistant.md`.",
  "Write the managed block into `~/.claude/CLAUDE.md`:",
  "",
  "    <!-- selr-kit:begin -->",
  "    Kit home: <the path Step 2 decided>",
  "    @<the resolved path to ~/.claude/selr-assistant.md>",
  "    <!-- selr-kit:end -->",
  "",
  "Write REAL absolute paths, not `~`.",
  "",
  "Then write `~/.claude/selr-kit-manifest.json`:",
  "",
  '    { "kitHome": "…", "installPath": "…", "onboarded": false, "skills": {} }',
].join("\n");

const ARTIFACT_BAD_CASES = [
  ["no pointer block", GOOD_ARTIFACTS.replace("<!-- selr-kit:begin -->", "## Selr AI")],
  ["persona imported from the kit instead of copied out", GOOD_ARTIFACTS.replace(
    "Copy `<kit home>/my-assistant/CLAUDE.md` to `~/.claude/selr-assistant.md`.",
    "Import the persona straight from `<kit home>/my-assistant/CLAUDE.md`.",
  )],
  ["no manifest", GOOD_ARTIFACTS.replace(/Then write `~\/\.claude\/selr-kit-manifest\.json`:[\s\S]*$/, "Done.")],
  ["home-relative import path", GOOD_ARTIFACTS.replace("Write REAL absolute paths, not `~`.", "Use `@~/` paths.")],
  ["writes a workspace persona", `${GOOD_ARTIFACTS}\n\nAlso write ~/Desktop/my-assistant/CLAUDE.md for the workspace.`],
  // The import line vanishing entirely used to pass: the old rule tested for
  // any at-sign, and `@louphq` elsewhere in the prompt satisfied it.
  ["no @-import line at all", GOOD_ARTIFACTS.replace("    @<the resolved path to ~/.claude/selr-assistant.md>", "    (the persona is loaded some other way)")],
];

const goodArtifacts = checkInstallArtifacts(GOOD_ARTIFACTS);
check(goodArtifacts.ok, `install artifacts: pointer block + persona copy + manifest accepted${goodArtifacts.ok ? "" : ` — ${goodArtifacts.detail}`}`);
for (const [name, body] of ARTIFACT_BAD_CASES) {
  check(!checkInstallArtifacts(body).ok, `install artifacts "${name}": rejected as expected`);
}

// ---- 6. checkWindowsNodePath (slice #387) ----------------------------------
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
  "     For the rest of setup, prepend the same refresh to every later command.",
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
const WIN_BAD_CASES = [
  ["no winget", GOOD_WIN.replace(/winget install --id OpenJS\.NodeJS\.LTS/, "choco install nodejs-lts")],
  ["no user-scope refresh", GOOD_WIN.replaceAll(" + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')", "")],
  ["split node invocation", GOOD_WIN.replace("'); node --version", "')\n         node --version")],
  ["speculative reopen", GOOD_WIN.replace(/ONLY if `node --version` still fails after that refresh: tell me to fully quit\n     and reopen/, "tell me to fully quit\n     and reopen")],
  ["no playwright fallback", GOOD_WIN.replace(/\(Playwright\) and download the LTS installer for me automatically\./, "and download it.")],
];

// The npx clause is conditional (CORE-116 review): a body that never invokes
// the Loup installer owes nothing, one that does must say how the refreshed
// PATH reaches it — either on the line, or via the blanket rule.
const WIN_NPX = `${GOOD_WIN}\n\n     Then paste your install command: npx @louphq/install selrai-company/claude-workshop-kit`;
check(checkWindowsNodePath(WIN_NPX).ok,
  "windows-node-path: npx invoked + blanket 'prepend the same refresh to every later command' rule accepted");
check(!checkWindowsNodePath(WIN_NPX.replace("For the rest of setup, prepend the same refresh to every later command.", "")).ok,
  "windows-node-path: npx invoked with neither the refresh on the line nor the blanket rule is rejected");
check(checkWindowsNodePath(GOOD_WIN.replace("For the rest of setup, prepend the same refresh to every later command.", "")).ok,
  "windows-node-path: a document that never invokes npx owes nothing (clause stays inert)");

const good = checkWindowsNodePath(GOOD_WIN);
check(good.ok, `windows-node-path: well-formed Windows branch accepted${good.ok ? "" : ` — ${good.detail}`}`);
for (const [name, body] of WIN_BAD_CASES) {
  check(!checkWindowsNodePath(body).ok, `windows-node-path "${name}": rejected as expected`);
}

process.exit(failed ? 1 : 0);
