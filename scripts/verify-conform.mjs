#!/usr/bin/env node
// Verifies the kit's install-canon invariants (ADR-0001, redesigned by CORE-116).
// Pure Node, no dependencies — run with `node scripts/verify-conform.mjs`.
//
// Modes:
//   (default) / --check   read-only; exit 1 on any hard failure (used in CI)
//   --verbose             also print every passing check
//   --update-baseline     rewrite scripts/old-canon-baseline.json from the tree
//                         (the only way the baseline ever changes; see below)
//
// Hard failures (exit 1):
//   1. OLD-CANON          no old-canon install reference survives outside the
//                         surfaces that legitimately name the old world. This
//                         check was INVERTED by CORE-116: it used to police
//                         only the retired homes (~/workshop-kit and friends)
//                         while treating ~/.loup/selr-ai/workshop-kit as the
//                         one true home. Under ADR-0001 §2/§3 there is no one
//                         true home — the kit home is per-install, declared in
//                         the pointer block and the manifest — so a HARDCODED
//                         kit home of EITHER live door is now a violation too,
//                         as is the dead workspace folder (~/Desktop/my-assistant)
//                         and the dead .first-run-pending marker.
//   2. SINGLE-SURFACE     docs/start carries exactly one install document
//                         (setup.md). This is what RETIRED the bootstrap ≡
//                         full-setup byte-identity checker (ADR-0001 §4): the
//                         shared text exists once, so drift is not something to
//                         diff for — it is structurally impossible. What
//                         replaces the diff is this: prove there is still only
//                         one copy, because a second copy is how drift returns.
//   3. INSTALL-METHOD     the two-door canon (ADR-0001 §1), replacing the old
//                         Loup-only assertion: one silent `git ls-remote` probe
//                         with GIT_TERMINAL_PROMPT=0, three doors behind it
//                         (clone / Loup dashboard / wifi retry), always
//                         re-fetch never update-in-place, and the install type
//                         is never a question put to the user.
//   4. VERIFY-GATE-PATHS  the repo-root sources the setup document copies out of
//                         (my-assistant/CLAUDE.md + skills/) exist.
//   5. WINDOWS-NODE-PATH  the setup prompt's Windows branch installs Node via winget,
//                         refreshes the session PATH from the registry (machine +
//                         user) in the SAME PowerShell invocation as the node
//                         check, gates the quit/reopen step behind a failing
//                         post-refresh `node --version` (never speculative), and
//                         keeps the Playwright nodejs.org last-resort fallback.
//                         (PRD #385 slice #387.)
//   6. INSTALL-ARTIFACTS  the kit-side half of the cross-repo rift test: the
//                         install's post-conditions are the pointer block, the
//                         persona copy at ~/.claude/selr-assistant.md and the
//                         manifest — NOT a workspace my-assistant/CLAUDE.md.
//                         (0007 amendment §4, obligations A2/A3/A5.)
//
// Informational (never fails): snapshot file count + a note if Loup's caps are
// at risk. Media trimming is a separate slice; this only reports.

import { readFileSync, readdirSync, existsSync, writeFileSync } from "node:fs";
import { extractPromptBody, sameLine } from "./check-resilient-install.mjs";
import { join, dirname, resolve, relative, extname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
// `--check` is the default behaviour and accepted explicitly, so the flag this
// header documents is a real flag rather than an argument that happens to be
// ignored. Anything unrecognised exits 2 instead of silently running the
// default — a mistyped `--updat-baseline` used to look like a passing check.
const KNOWN_FLAGS = new Set(["--check", "--verbose", "--update-baseline"]);
const VERBOSE = process.argv.includes("--verbose");
// Run the CLI checks only when invoked directly; stays inert when imported
// (the regression test imports the pure checkers without triggering a run).
const IS_MAIN = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);

const BASELINE_FILE = "scripts/old-canon-baseline.json";

// ---------------------------------------------------------------------------
// Old-canon reference patterns (check 1)
//
// Every one of these names a fact about the install that the new canon says
// must be READ, not written down: the kit home comes from the pointer block /
// manifest, and there is no workspace folder or first-run marker file at all.
// ---------------------------------------------------------------------------
const OLD_CANON_PATTERNS = [
  // --- Retired kit homes (distributions that no longer exist) --------------
  { id: "tilde-home", re: /~\/workshop-kit/, why: "retired kit home ~/workshop-kit" },
  { id: "HOME-home", re: /\$HOME\/workshop-kit/, why: "retired kit home $HOME/workshop-kit" },
  { id: "userprofile-home", re: /%USERPROFILE%\\workshop-kit/, why: "retired kit home %USERPROFILE%\\workshop-kit" },
  { id: "windows-users-home", re: /[A-Za-z]:\\Users\\[^\\]*\\workshop-kit/, why: "retired kit home C:\\Users\\…\\workshop-kit" },
  { id: "whatsapp-clone-fallback", re: /~\/claude-workshop-kit\/whatsapp/, why: "retired clone-fallback path" },

  // --- INVERTED by CORE-116: a hardcoded LIVE kit home -------------------
  // Both doors' homes are per-install facts. Anything that hardcodes one is a
  // reference that breaks on the other door — exactly obligation A1 of the
  // 0007 amendment ("no hardcoded kit home anywhere in docs, skills or
  // persona — every reference reads the declared pointer").
  {
    id: "hardcoded-loup-home",
    re: /\.loup[/\\](?:selr-ai[/\\]workshop-kit|selrai-company[/\\]claude-workshop-kit)/,
    why: "hardcoded Loup-door kit home — read it from the pointer block / manifest instead",
  },
  {
    id: "hardcoded-github-home",
    re: /(?:~|\$HOME|%USERPROFILE%)[/\\]claude-workshop-kit/,
    why: "hardcoded GitHub-door kit home — read it from the pointer block / manifest instead",
  },
  {
    id: "windows-github-home",
    re: /[A-Za-z]:\\Users\\[^\\]*\\claude-workshop-kit/,
    why: "hardcoded GitHub-door kit home (Windows form)",
  },

  // --- INVERTED by CORE-116: the dead workspace model ----------------------
  {
    id: "legacy-workspace-desktop",
    re: /(?:~|\$HOME|%USERPROFILE%)[/\\]Desktop[/\\]my-assistant/,
    why: "the workspace folder is dead (ADR-0001 §2) — the install is global",
  },
  {
    id: "legacy-workspace-home",
    re: /(?:~|\$HOME|%USERPROFILE%)[/\\]my-assistant\b/,
    why: "the workspace folder is dead (ADR-0001 §2) — the install is global",
  },
  {
    id: "first-run-pending",
    re: /\.first-run-pending/,
    why: "the .first-run-pending marker is dead — the manifest's `onboarded` flag is the only first-run signal",
  },
];

// Directories never walked. `.claude` is local agent state, not shipped kit
// content: a checkout with stale agent worktrees under `.claude/worktrees/`
// would otherwise scan whole copies of the repo and report the same debt many
// times over. CI clones have no `.claude/`, so this only affects local runs.
const SKIP_DIRS = new Set([".git", "node_modules", ".loup", ".claude"]);
// Binary-ish extensions never read.
const SKIP_EXT = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp4", ".mov", ".pdf", ".zip",
  ".gz", ".woff", ".woff2", ".ttf", ".otf", ".ico", ".icns",
]);

// Files that legitimately name the old world, permanently. Every entry is a
// MIGRATION-ADJACENT surface: it exists precisely to move a machine off the old
// canon, and it cannot do that without naming what it is moving off.
//
// This is deliberately NOT where "a doc we haven't cleaned up yet" goes — that
// is the baseline below, which is a ratchet and shows its debt on every run.
const OLD_CANON_ALLOWLIST = new Set([
  relative(ROOT, fileURLToPath(import.meta.url)),
  "scripts/README.md", // documents the very forms this checker catches
  "scripts/__fixtures__/conform-stale.md",
  "scripts/__fixtures__/old-canon-bad.md",
  "scripts/test-verify-conform.mjs", // seeds violations inline to prove the rules fire
  BASELINE_FILE, // a list of paths-with-debt, not a reference to any of them
  // The legacy-install fixture RECONSTRUCTS pre-canon machine states in a
  // sandbox so migration can be dry-run against them. Reproducing the old homes
  // is the point, so these are stale-by-design, not drift.
  "scripts/make-legacy-fixture.mjs",
  "scripts/verify-migration.mjs",
  "docs/agents/legacy-install-fixture.md",
  // ADR-0001 SPECIFIES the migration away from the old canon, so it names it
  // deliberately (MIGRATE fingerprint reconstruction, stale-home cleanup).
  "docs/adr/0001-pointer-block-install-model.md",
  // Uninstall (CORE-115, a parallel ticket — allowlisted pre-emptively so the
  // two tickets can land in either order). ADR-0001 §9: uninstall's KEPT list
  // is "any legacy-workspace candidate-list folder", and its manifest-missing
  // fallback checks BOTH kit homes by name. Naming the old world is the job.
  "docs/uninstall.md",
  "skills/uninstall/SKILL.md",
]);

// docs/start/setup.md is NOT file-allowlisted. It is the most attendee-facing
// document in the kit, and a file-level exemption on it would hide a real
// regression — a stale "your assistant folder on the Desktop" line in the
// completion banner would sail straight through. Instead the exemption is
// SECTION-SCOPED: only the steps whose job is the old world may name it.
//
//   Step 1 — mode detection (probes the legacy-workspace candidate list and all
//            three legacy kit homes to rebuild fingerprints)
//   Step 2 — acquisition (decides and names this run's kit home per door)
//   Step 3 — pointer block + MIGRATE retirement of the old wiring
//   Step 4 — the manifest (states the .first-run-pending marker is dead)
//
// Everything else — the intro prose, Steps 0 and 5-10, the completion banner,
// "Before workshop day", the troubleshooting tail — must be clean.
const SETUP_DOC = "docs/start/setup.md";
const SETUP_LEGACY_SECTIONS = [1, 2, 3, 4];

/**
 * Line numbers (1-based) of docs/start/setup.md that are allowed to name the
 * old canon, i.e. the bodies of SETUP_LEGACY_SECTIONS. Exported so the test can
 * prove the scoping is real in both directions.
 */
export function setupLegacyLineWindow(text, allowedSteps = SETUP_LEGACY_SECTIONS) {
  const lines = text.split(/\r?\n/);
  const allowed = new Set();
  let current = null;
  for (let i = 0; i < lines.length; i++) {
    const m = /^#{2,4}\s+Step\s+(\d+)\b/.exec(lines[i]);
    if (m) current = Number(m[1]);
    else if (/^#{1,4}\s+/.test(lines[i])) current = null; // any other heading closes the step
    if (current !== null && allowedSteps.includes(current)) allowed.add(i + 1);
  }
  return allowed;
}

/**
 * Scan one file's text for old-canon references.
 * `allowedLines` (optional) is a Set of 1-based line numbers to skip.
 * Returns [{ line, id, why, text }] — one entry per pattern per line.
 */
export function scanOldCanon(text, { allowedLines = null } = {}) {
  const hits = [];
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    if (allowedLines && allowedLines.has(i + 1)) continue;
    for (const p of OLD_CANON_PATTERNS) {
      if (p.re.test(lines[i])) {
        hits.push({ line: i + 1, id: p.id, why: p.why, text: lines[i].trim().slice(0, 100) });
      }
    }
  }
  return hits;
}

/**
 * The ratchet. `counts` is { relPath: hitCount } for the current tree;
 * `baseline` is the same shape, loaded from BASELINE_FILE.
 *
 * Why a baseline at all: inverting this check turned ~50 pre-existing
 * references across docs/, skills/, visuals/ and the persona into violations
 * overnight. Those files belong to other tickets in the ADR-0001 breakdown
 * (CORE-113 persona, CORE-114 orientation, CORE-117 stale-doc sweep), so this
 * ticket cannot fix them and must not pretend they don't exist.
 *
 * The ratchet is monotonic and per-file-counted, which is what makes it a real
 * check rather than a blanket exemption:
 *   - a file NOT in the baseline that gains a reference        → FAIL
 *   - a baselined file whose count GOES UP                     → FAIL
 *   - a baselined file whose count goes DOWN, or hits zero     → WARN (lower it)
 * So the sweep tickets can only ever shrink this file, and no new old-canon
 * reference can enter the tree anywhere, baselined file or not.
 */
export function evaluateOldCanonRatchet(counts, baseline) {
  const failures = [];
  const warnings = [];
  for (const [rel, count] of Object.entries(counts)) {
    if (count === 0) continue;
    const allowed = baseline[rel];
    if (allowed === undefined) {
      failures.push({ rel, count, allowed: 0, kind: "new-file" });
    } else if (count > allowed) {
      failures.push({ rel, count, allowed, kind: "over-baseline" });
    } else if (count < allowed) {
      warnings.push({ rel, count, allowed, kind: "under-baseline" });
    }
  }
  for (const [rel, allowed] of Object.entries(baseline)) {
    if (rel.startsWith("__")) continue;
    if (!(counts[rel] > 0)) warnings.push({ rel, count: 0, allowed, kind: "cleared" });
  }
  return { failures, warnings };
}

// ---------------------------------------------------------------------------
// Check 3: the two-door canon (replaces the Loup-only install-method assertion)
// ---------------------------------------------------------------------------

// Questions the setup surface must never ask. ADR-0001's rejected-alternatives
// table is explicit: "asking the user which install type they have — they
// cannot know, it is our plumbing; the probe knows."
const INSTALL_TYPE_QUESTION_PATTERNS = [
  // Naming both doors is fine and necessary — the manifest records which one
  // ran (`"installPath": "<github or loup …>"`). What is forbidden is PUTTING
  // the pair to the user, so the pattern needs interrogative context, not the
  // bare phrase.
  { id: "github-or-loup", re: /(?:ask|question)[^\n]{0,40}(?:github or loup|loup or github)|(?:github or loup|loup or github)[^\n]{0,80}\?/i },
  { id: "which-install", re: /which (install|download|delivery|setup) (type|path|method|door|route)/i },
  { id: "where-did-you-get", re: /(did|do) you (get|receive|have) the kit (from|through|via)/i },
  { id: "do-you-have-loup", re: /do you have (a |an )?loup\b/i },
  { id: "are-you-installing-from", re: /are you installing (from|via|through)\b/i },
];

/**
 * The two-door canon, asserted against the pasted prompt body.
 * Pure + exported so the regression test can drive it with crafted bodies.
 */
export function checkTwoDoorCanon(body) {
  const fails = [];

  // a) One silent probe, prompting disabled, fails fast rather than hanging.
  //    Same LINE, not merely same document — see the identical note on
  //    check-resilient-install's silent-probe rule.
  if (!sameLine(body, /GIT_TERMINAL_PROMPT/, /git ls-remote/)) {
    fails.push("missing the silent probe (`git ls-remote` on one line with GIT_TERMINAL_PROMPT=0)");
  }
  if (!/generous timeout/i.test(body)) {
    fails.push("the probe/download must be given a generous timeout");
  }

  // b) Door A — clone, shallow, over HTTPS, still with prompting disabled: the
  //    repo can go private between the probe and the clone.
  if (!sameLine(body, /GIT_TERMINAL_PROMPT/, /git clone --depth 1/)) {
    fails.push("missing the GitHub door (`git clone --depth 1` on one line with GIT_TERMINAL_PROMPT=0)");
  }

  // c) Door B — Loup dashboard walkthrough on a REFUSED probe.
  const refusedNamed = /(refused|rejected|authentication error|not found)/i.test(body);
  const loupDoor = /npx @louphq\/install/.test(body) && /dashboard/i.test(body);
  if (!refusedNamed || !loupDoor) {
    fails.push(`missing the Loup door on a refused probe (refusedNamed=${refusedNamed}, loupWalkthrough=${loupDoor})`);
  }

  // d) Door C — a network failure is the wifi, never an access problem. This is
  //    the clause that keeps a flaky venue connection from turning into a
  //    credential hunt.
  const networkDoor = /(times? out|network problem|network error)/i.test(body) &&
    /never[\s\S]{0,160}(token|loup)/i.test(body);
  if (!networkDoor) {
    fails.push("missing the network door (timeout/network failure → retry the wifi, never a token ask)");
  }

  // e) Never a GitHub credential ask on the refused door either.
  if (!/(do not|don't|never)[\s\S]{0,60}password/i.test(body)) {
    fails.push("must state a refused probe never leads to a GitHub password ask");
  }

  // f) Always re-fetch, never update-in-place — both doors.
  const reFetch = /(fresh copy|never update-in-place|ALWAYS take a fresh|always re-run)/i.test(body);
  if (!reFetch) {
    fails.push("must state the kit is always re-fetched fresh, never updated in place");
  }

  // g) The door is plumbing, not a question. Both halves: the positive
  //    statement, and no install-type question anywhere in the body.
  const doorIsPlumbing = /(plumbing|never need to know|do not need to know|don't need to know)/i.test(body);
  if (!doorIsPlumbing) {
    fails.push("must state which door the kit came through is plumbing the user never needs to know");
  }
  const asked = INSTALL_TYPE_QUESTION_PATTERNS.filter((p) => p.re.test(body)).map((p) => p.id);
  if (asked.length > 0) {
    fails.push(`asks the user which install type they have: ${asked.join(", ")}`);
  }

  return {
    ok: fails.length === 0,
    detail: fails.length === 0
      ? "one silent probe → three doors (clone / Loup dashboard / wifi retry); always re-fetched; install type never asked"
      : fails.join("; "),
  };
}

/** The install-type question rule on its own, for scanning a whole document. */
export function checkNoInstallTypeQuestion(text) {
  const asked = INSTALL_TYPE_QUESTION_PATTERNS.filter((p) => p.re.test(text)).map((p) => p.id);
  return {
    ok: asked.length === 0,
    detail: asked.length === 0 ? "no install-type question anywhere in the document" : `found: ${asked.join(", ")}`,
  };
}

// ---------------------------------------------------------------------------
// Check 6: install artifacts — the kit-side half of the rift test
//
// The cross-repo rift test lives in the-platform (it drives a real publish →
// grant → mint → install through both Loup installer twins). Its post-install
// assertions were amended on 2026-07-30: "assert the pointer block, the persona
// copy at ~/.claude/selr-assistant.md, and the manifest — not
// my-assistant/CLAUDE.md". That is a statement about what the KIT must produce,
// so the kit owes the other repo a surface that pins the same three artifacts.
// This is it: the assertions in one place, exported, so the rift test asserts
// the same post-conditions this repo enforces on its own document.
// ---------------------------------------------------------------------------
export const INSTALL_ARTIFACTS = [
  {
    id: "pointer-block",
    why: "a marker-delimited managed block in the GLOBAL ~/.claude/CLAUDE.md, carrying the kit home as plain text",
    test: (b) =>
      /<!-- selr-kit:begin -->/.test(b) &&
      /<!-- selr-kit:end -->/.test(b) &&
      /~\/\.claude\/CLAUDE\.md/.test(b) &&
      /Kit home:/.test(b),
  },
  {
    id: "persona-copy",
    why: "the persona is COPIED OUT of the kit to ~/.claude/selr-assistant.md, so deleting the kit home never lobotomises the assistant",
    test: (b) => /~\/\.claude\/selr-assistant\.md/.test(b) && /cop(y|ies|ied)/i.test(b),
  },
  {
    id: "manifest",
    why: "~/.claude/selr-kit-manifest.json is written fresh on every run and carries kitHome + installPath + onboarded + skills",
    test: (b) =>
      /~\/\.claude\/selr-kit-manifest\.json/.test(b) &&
      /"kitHome"/.test(b) &&
      /"installPath"/.test(b) &&
      /"onboarded"/.test(b),
  },
  {
    id: "absolute-import-path",
    why: "the @-import line exists and is written as a resolved absolute path (home-relative @~/ is unverified on Windows)",
    // Anchored to the import LINE, not to any at-sign in the document: a bare
    // /@/ is satisfied by an email address, a decorator, or the `@louphq`
    // package name, so the rule survived the import line disappearing entirely.
    test: (b) =>
      b.split(/\r?\n/).some((line) => /^@[^\n]*selr-assistant\.md/.test(line.trimStart())) &&
      /absolute path/i.test(b),
  },
  {
    id: "no-workspace-artifact",
    why: "the install must NOT produce a workspace my-assistant/CLAUDE.md — the workspace model is dead",
    test: (b) => !/(?:~|\$HOME|%USERPROFILE%)[/\\](?:Desktop[/\\])?my-assistant[/\\]CLAUDE\.md(?!\.pre-migration)/.test(b),
  },
];

/** Assert the setup document produces exactly the three post-install artifacts. */
export function checkInstallArtifacts(body) {
  const rules = INSTALL_ARTIFACTS.map((r) => ({ id: r.id, ok: r.test(body), why: r.why }));
  const bad = rules.filter((r) => !r.ok);
  return {
    ok: bad.length === 0,
    rules,
    detail: bad.length === 0
      ? "pointer block + persona copy + manifest, absolute @-import, no workspace artifact"
      : bad.map((r) => `${r.id}: ${r.why}`).join("; "),
  };
}

// Asserts the setup prompt's Windows Node branch is the gated in-session-refresh
// shape (slice #387), not the old speculative reopen. Pure + exported so the
// regression test can drive it with crafted bodies. Returns { ok, detail }.
export function checkWindowsNodePath(body) {
  const fails = [];

  // a) Node installed via winget.
  if (!/winget install --id OpenJS\.NodeJS\.LTS/.test(body)) {
    fails.push("missing winget install of OpenJS.NodeJS.LTS");
  }

  // b) PATH refreshed from BOTH registry scopes (machine + user).
  const readsMachine = /GetEnvironmentVariable\(\s*['"]Path['"]\s*,\s*['"]Machine['"]\s*\)/.test(body);
  const readsUser = /GetEnvironmentVariable\(\s*['"]Path['"]\s*,\s*['"]User['"]\s*\)/.test(body);
  if (!readsMachine || !readsUser) {
    fails.push(`PATH refresh must read registry machine + user scope (machine=${readsMachine}, user=${readsUser})`);
  }

  // c) Refresh + the command that needs it must share ONE PowerShell
  //    invocation: the $env:Path assignment joined by `;` to `node --version`.
  //
  //    Slice #387's AC also required the refresh be prepended to the
  //    `npx @louphq/install` line, because the Loup installer was the only way
  //    the kit arrived. ADR-0001 §1 made the GitHub-clone door co-equal, so a
  //    document that never invokes `npx @louphq/install` is now conformant and
  //    that clause has been dropped. The property it protected — a fresh shell
  //    loses the refreshed PATH — survives in the prose the document carries
  //    ("prepend the same refresh to every later PowerShell command") and in
  //    the `node --version` check below, which still proves the one-invocation
  //    shape is stated at least once.
  const lines = body.split(/\r?\n/);
  const nodeOneLine = lines.some((line) => /\$env:Path\s*=.*;\s*node --version/.test(line));
  if (!nodeOneLine) {
    fails.push("refresh and `node --version` must run in one PowerShell invocation (`$env:Path = ...; node --version`)");
  }

  //    The npx clause is restored as a CONDITIONAL rather than dropped: a
  //    document that never invokes the Loup installer owes nothing, but one
  //    that does must still say how the refreshed PATH reaches it. Two ways
  //    satisfy that, because setup.md's `npx @louphq/install` is a QUOTED
  //    EXAMPLE of the line the user pastes from the dashboard, not a command
  //    the prompt composes — there is nothing there to prepend to. So either
  //    the refresh sits on the npx line, or the document states the blanket
  //    rule that it is prepended to every later PowerShell command.
  if (/npx @louphq\/install/.test(body)) {
    const refreshOnNpx = lines.some((line) => /\$env:Path\s*=.*;.*npx @louphq\/install/.test(line));
    // Whitespace-tolerant: the document is hard-wrapped, so "Prepend the / same
    // refresh to every later PowerShell command" straddles a line break.
    const blanketRule = /prepend\s+the\s+same[\s\S]{0,80}?(every|each|all)\s+later[\s\S]{0,40}?command/i.test(body);
    if (!refreshOnNpx && !blanketRule) {
      fails.push("document invokes `npx @louphq/install` but never says how the refreshed PATH reaches it (prepend the refresh to that line, or state the blanket \"prepend to every later PowerShell command\" rule)");
    }
  }

  // d) Refresh is process-only, never the persisted registry.
  if (!/never writes? to the registry|current process|this process only|process only/i.test(body)) {
    fails.push("must state the refresh changes the current process only, never the registry");
  }

  // e) Quit/reopen is GATED behind a failing post-refresh node check, not
  //    spoken unconditionally.
  const gatedReopen = /only if[\s\S]{0,120}node --version[\s\S]{0,160}reopen/i.test(body);
  if (!gatedReopen) {
    fails.push("quit/reopen must be gated behind a failing post-refresh `node --version` (e.g. \"ONLY if `node --version` still fails ... reopen\")");
  }

  // f) Playwright nodejs.org last-resort fallback survives (both OSes).
  if (!/nodejs\.org/.test(body) || !/playwright/i.test(body)) {
    fails.push("missing Playwright nodejs.org last-resort fallback");
  }

  return { ok: fails.length === 0, detail: fails.length === 0 ? "winget + gated in-session PATH refresh; reopen is fallback-only; Playwright fallback intact" : fails.join("; ") };
}

function walk(dir, out = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (SKIP_DIRS.has(entry.name)) continue;
      walk(full, out);
    } else if (entry.isFile()) {
      out.push(full);
    }
  }
  return out;
}

/** Old-canon hit counts for the whole tree, keyed by repo-relative path. */
function scanTree() {
  const files = walk(ROOT).filter((f) => !SKIP_EXT.has(extname(f).toLowerCase()));
  const counts = {};
  const detail = {};
  for (const file of files) {
    const rel = relative(ROOT, file);
    if (OLD_CANON_ALLOWLIST.has(rel)) continue;
    let text;
    try {
      text = readFileSync(file, "utf8");
    } catch {
      continue;
    }
    if (text.includes(String.fromCharCode(0))) continue; // binary guard
    const allowedLines = rel === SETUP_DOC ? setupLegacyLineWindow(text) : null;
    const hits = scanOldCanon(text, { allowedLines });
    if (hits.length > 0) {
      counts[rel] = hits.length;
      detail[rel] = hits;
    }
  }
  return { counts, detail };
}

function loadBaseline() {
  try {
    return JSON.parse(readFileSync(join(ROOT, BASELINE_FILE), "utf8"));
  } catch {
    return {};
  }
}

function main() {
  const unknown = process.argv.slice(2).filter((a) => !KNOWN_FLAGS.has(a));
  if (unknown.length > 0) {
    console.error(`❌ unknown flag(s): ${unknown.join(", ")} — expected any of ${[...KNOWN_FLAGS].join(", ")}`);
    process.exit(2);
  }

  let hardFailed = false;
  const note = (ok, label, detail) => {
    if (!ok) hardFailed = true;
    if (!ok || VERBOSE) {
      console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` — ${detail}` : ""}`);
    }
  };

  // ---- Check 1: OLD-CANON --------------------------------------------------
  const { counts, detail } = scanTree();

  if (process.argv.includes("--update-baseline")) {
    const baseline = loadBaseline();
    const next = { __doc__: baseline.__doc__ };
    for (const rel of Object.keys(counts).sort()) next[rel] = counts[rel];
    writeFileSync(join(ROOT, BASELINE_FILE), `${JSON.stringify(next, null, 2)}\n`);
    console.log(`✏️  wrote ${BASELINE_FILE} (${Object.keys(counts).length} file(s) carrying old-canon debt)`);
    process.exit(0);
  }

  const baseline = loadBaseline();
  const { failures, warnings } = evaluateOldCanonRatchet(counts, baseline);

  const lines = [];
  for (const f of failures) {
    const hits = (detail[f.rel] || []).map((h) => `      ${f.rel}:${h.line} [${h.id}] ${h.text}\n        ${h.why}`);
    lines.push(
      f.kind === "new-file"
        ? `    ${f.rel}: ${f.count} old-canon reference(s) in a file with no baseline debt\n${hits.join("\n")}`
        : `    ${f.rel}: ${f.count} old-canon reference(s), baseline allows ${f.allowed}\n${hits.join("\n")}`,
    );
  }
  note(failures.length === 0, "old-canon",
    failures.length === 0
      ? `no new old-canon references; ${Object.keys(baseline).filter((k) => !k.startsWith("__")).length} file(s) still carrying baselined debt`
      : `${failures.length} file(s) over baseline:\n${lines.join("\n")}`);

  // Warnings print on every run, pass or fail: a baseline entry that has been
  // paid off but not deleted is how a ratchet quietly stops ratcheting.
  if (warnings.length > 0) {
    console.log(`ℹ️  old-canon baseline is now loose in ${warnings.length} place(s) — lower it with \`node scripts/verify-conform.mjs --update-baseline\`:`);
    for (const w of warnings) {
      console.log(`     - ${w.rel}: baseline ${w.allowed}, actual ${w.count}${w.count === 0 ? " (entry can be deleted)" : ""}`);
    }
  }

  // ---- Check 2: SINGLE-SURFACE --------------------------------------------
  //
  // The retirement of the bootstrap ≡ full-setup byte-identity checker
  // (ADR-0001 §4). The old check diffed two copies of the same prompt between
  // canonical anchors. There is now one copy, so there is nothing to diff — and
  // an assertion that cannot fail is worse than no assertion, because it reads
  // as coverage. What actually protects the property now is the absence of a
  // second copy, which is what this asserts.
  const RETIRED_DOCS = ["docs/start/bootstrap.md", "docs/start/full-setup.md"];
  const resurrected = RETIRED_DOCS.filter((p) => existsSync(join(ROOT, p)));
  const startDocs = existsSync(join(ROOT, "docs/start"))
    ? readdirSync(join(ROOT, "docs/start")).filter((f) => f.endsWith(".md") && f !== "README.md")
    : [];
  const singleSurfaceOk = resurrected.length === 0 && startDocs.length === 1 && startDocs[0] === "setup.md";
  note(singleSurfaceOk, "single-install-surface",
    singleSurfaceOk
      ? "docs/start carries exactly one install document (setup.md) — byte-identity drift is structurally impossible"
      : `expected only docs/start/setup.md; found ${startDocs.join(", ") || "nothing"}${resurrected.length ? ` (retired docs back: ${resurrected.join(", ")})` : ""}`);

  // ---- Checks 3 + 5 + 6: read the setup document once ----------------------
  let setupText = null;
  try {
    setupText = readFileSync(join(ROOT, SETUP_DOC), "utf8");
  } catch (e) {
    note(false, "setup-document", `cannot read ${SETUP_DOC}: ${e.message}`);
  }

  if (setupText !== null) {
    const { body, error } = extractPromptBody(setupText);
    if (error) {
      note(false, "setup-document", `${SETUP_DOC}: ${error}`);
    } else {
      const doors = checkTwoDoorCanon(body);
      note(doors.ok, "install-method", `${SETUP_DOC} (pasted prompt) — ${doors.detail}`);

      // The question rule also runs over the WHOLE document: the prompt could
      // be clean while the attendee-facing prose around it asks "are you
      // installing from GitHub or through Loup?" — which is the same mistake.
      const q = checkNoInstallTypeQuestion(setupText);
      note(q.ok, "install-method/no-question", `${SETUP_DOC} (whole document) — ${q.detail}`);

      const win = checkWindowsNodePath(body);
      note(win.ok, "windows-node-path", `${SETUP_DOC} (pasted prompt) — ${win.detail}`);

      const artifacts = checkInstallArtifacts(body);
      note(artifacts.ok, "install-artifacts", `${SETUP_DOC} (pasted prompt) — ${artifacts.detail}`);
    }
  }

  // ---- Check 4: VERIFY-GATE-PATHS -----------------------------------------
  // The repo-root SOURCES the setup document copies out of. my-assistant/CLAUDE.md
  // stays the persona's source of truth (ADR-0001 §2: "the repo source stays
  // my-assistant/CLAUDE.md; only the installed copy is renamed") — what changed
  // is that it is no longer an INSTALL artifact, which is check 6's business.
  const gatePaths = ["my-assistant/CLAUDE.md", "skills"];
  const missingGate = gatePaths.filter((p) => !existsSync(join(ROOT, p)));
  note(missingGate.length === 0, "verify-gate-paths",
    missingGate.length === 0
      ? `${gatePaths.join(" + ")} present at repo root`
      : `missing: ${missingGate.join(", ")}`);

  // ---- Informational: snapshot file count ---------------------------------
  const snapshotFiles = walk(ROOT).filter((f) => !relative(ROOT, f).startsWith(".git"));
  const FILE_CAP = 2000;
  console.log(`INFO snapshot-shape — ${snapshotFiles.length} files (Loup cap < ${FILE_CAP})${snapshotFiles.length >= FILE_CAP ? " ⚠️ AT RISK" : ""}`);

  if (!hardFailed) console.log("\n✅ verify-conform: all hard checks passed");
  process.exit(hardFailed ? 1 : 0);
}

export { OLD_CANON_PATTERNS, OLD_CANON_ALLOWLIST, INSTALL_TYPE_QUESTION_PATTERNS, SETUP_DOC, SETUP_LEGACY_SECTIONS, BASELINE_FILE };

if (IS_MAIN) main();
