#!/usr/bin/env node
// Verifies the Loup-deliverable invariants for the kit (PRD #385, slice #386).
// Pure Node, no dependencies — run with `node scripts/verify-conform.mjs`.
//
// Modes:
//   (default) / --check   read-only; exit 1 on any hard failure (used in CI)
//   --verbose             also print every passing check
//
// Hard failures (exit 1):
//   1. PATH-CONFORM       no stale kit-home reference (~/workshop-kit,
//                         $HOME/workshop-kit, %USERPROFILE%\workshop-kit,
//                         ~/claude-workshop-kit/whatsapp) survives anywhere in
//                         the tree. The kit home is ~/.loup/selr-ai/workshop-kit.
//   2. BOOTSTRAP-CONSIST  the bootstrap prompt body is byte-identical between
//                         the version-controlled mirror (docs/start/bootstrap.md)
//                         and the full-setup duplicate (docs/start/full-setup.md),
//                         taken between the canonical start/end anchors.
//   3. INSTALL-METHOD     the bootstrap installs via `npx @louphq/install` and
//                         no longer `git clone`s the kit into the home folder.
//   4. VERIFY-GATE-PATHS  the post-unpack verify-gate paths the bootstrap checks
//                         (my-assistant/CLAUDE.md + skills/) exist at the repo root.
//   5. WINDOWS-NODE-PATH  the bootstrap's Windows branch installs Node via winget,
//                         refreshes the session PATH from the registry (machine +
//                         user) in the SAME PowerShell invocation as the node
//                         check, gates the quit/reopen step behind a failing
//                         post-refresh `node --version` (never speculative), and
//                         keeps the Playwright nodejs.org last-resort fallback.
//                         (PRD #385 slice #387.)
//
// Informational (never fails): snapshot file count + a note if Loup's caps are
// at risk. Media trimming is a separate slice; this only reports.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, resolve, relative, extname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const VERBOSE = process.argv.includes("--verbose");
// Run the CLI checks only when invoked directly; stays inert when imported
// (the regression test imports checkWindowsNodePath without triggering a run).
const IS_MAIN = process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url);

const KIT_HOME = "~/.loup/selr-ai/workshop-kit";

// Canonical anchors that delimit the bootstrap prompt body in every copy
// (same anchors the workshop-preflight harness diffs against).
const START_ANCHOR = "I am setting up my Claude Code AI Business Assistant with Selr AI.";
const END_ANCHOR = "Talk to me like I am not technical. Plain English, one step at a time.";

// Stale kit-home reference forms. Each must return ZERO hits post-conform.
// Crafted to NOT match the new home (~/.loup/...), nor the repo/marketplace
// identifiers (claude-workshop-kit, selrai-workshop-kit, online-workshop-kit).
const STALE_PATTERNS = [
  { id: "tilde-home", re: /~\/workshop-kit/ },
  { id: "HOME-home", re: /\$HOME\/workshop-kit/ },
  { id: "userprofile-home", re: /%USERPROFILE%\\workshop-kit/ },
  { id: "windows-users-home", re: /[A-Za-z]:\\Users\\[^\\]*\\workshop-kit/ },
  { id: "whatsapp-clone-fallback", re: /~\/claude-workshop-kit\/whatsapp/ },
];

// Directories never walked.
const SKIP_DIRS = new Set([".git", "node_modules", ".loup"]);
// Binary-ish extensions never read.
const SKIP_EXT = new Set([
  ".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp4", ".mov", ".pdf", ".zip",
  ".gz", ".woff", ".woff2", ".ttf", ".otf", ".ico", ".icns",
]);
// Files allowed to mention the stale forms (this checker documents them; the
// fixture exists to exercise the detector — see scripts/test-verify-conform.mjs).
const STALE_ALLOWLIST = new Set([
  relative(ROOT, fileURLToPath(import.meta.url)),
  "scripts/__fixtures__/conform-stale.md",
  "scripts/README.md", // documents the legacy forms the checker catches
]);

// Asserts the bootstrap's Windows Node branch is the gated in-session-refresh
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
  //    invocation: the $env:Path assignment joined by `;` to `node --version`
  //    (the verify) AND to the `npx` install (the AC names both by name).
  const lines = body.split(/\r?\n/);
  const nodeOneLine = lines.some((line) => /\$env:Path\s*=.*;\s*node --version/.test(line));
  if (!nodeOneLine) {
    fails.push("refresh and `node --version` must run in one PowerShell invocation (`$env:Path = ...; node --version`)");
  }
  const npxOneLine = lines.some((line) => /\$env:Path\s*=.*;\s*npx @louphq\/install/.test(line));
  if (!npxOneLine) {
    fails.push("refresh must be prepended to the `npx` install in one PowerShell invocation (`$env:Path = ...; npx @louphq/install ...`)");
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

// Extracts the bootstrap prompt body between the canonical anchors.
function extractBootstrapBody(relPath) {
  const text = readFileSync(join(ROOT, relPath), "utf8");
  const lines = text.split(/\r?\n/);
  const start = lines.indexOf(START_ANCHOR);
  const end = lines.indexOf(END_ANCHOR);
  if (start === -1 || end === -1 || end < start) {
    return { error: `anchors not found in ${relPath} (start=${start}, end=${end})` };
  }
  return { body: lines.slice(start, end + 1).join("\n") };
}

function main() {
  let hardFailed = false;
  const note = (ok, label, detail) => {
    if (!ok) hardFailed = true;
    if (!ok || VERBOSE) {
      console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` — ${detail}` : ""}`);
    }
  };

  // ---- Check 1: PATH-CONFORM ----------------------------------------------
  const files = walk(ROOT).filter((f) => !SKIP_EXT.has(extname(f).toLowerCase()));
  const staleHits = [];
  for (const file of files) {
    const rel = relative(ROOT, file);
    if (STALE_ALLOWLIST.has(rel)) continue;
    let text;
    try {
      text = readFileSync(file, "utf8");
    } catch {
      continue;
    }
    if (text.includes(String.fromCharCode(0))) continue; // binary guard: skip files with NUL bytes
    const lines = text.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      for (const p of STALE_PATTERNS) {
        if (p.re.test(lines[i])) staleHits.push(`${rel}:${i + 1} [${p.id}] ${lines[i].trim().slice(0, 100)}`);
      }
    }
  }
  note(staleHits.length === 0, "path-conform", staleHits.length === 0 ? `no stale kit-home refs; home is ${KIT_HOME}` : `${staleHits.length} stale ref(s):\n  ${staleHits.join("\n  ")}`);

  // ---- Check 2 + 3 + 5: BOOTSTRAP-CONSIST + INSTALL-METHOD + WINDOWS-NODE --
  const mirror = extractBootstrapBody("docs/start/bootstrap.md");
  const dup = extractBootstrapBody("docs/start/full-setup.md");
  if (mirror.error || dup.error) {
    note(false, "bootstrap-consistency", mirror.error || dup.error);
  } else {
    note(mirror.body === dup.body, "bootstrap-consistency",
      mirror.body === dup.body
        ? "docs/start/bootstrap.md ≡ docs/start/full-setup.md (between anchors)"
        : "bootstrap body differs between the mirror and full-setup duplicate");

    const body = mirror.body;
    const hasNpx = /npx @louphq\/install selr-ai\/workshop-kit/.test(body);
    const clonesKit = /git clone[^\n]*workshop-kit/.test(body);
    note(hasNpx && !clonesKit, "install-method",
      hasNpx && !clonesKit
        ? "bootstrap installs via `npx @louphq/install`, no git clone of the kit"
        : `expected npx install (found=${hasNpx}) and no git-clone-of-kit (cloneFound=${clonesKit})`);

    const win = checkWindowsNodePath(body);
    note(win.ok, "windows-node-path", win.detail);
  }

  // ---- Check 4: VERIFY-GATE-PATHS -----------------------------------------
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

if (IS_MAIN) main();
