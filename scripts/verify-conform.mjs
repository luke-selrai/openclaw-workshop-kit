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
//                         RETIRED by ADR-0001 §4 — see the note above check 2.
//   3. INSTALL-METHOD     the bootstrap installs via `npx @louphq/install` and
//                         no longer `git clone`s the kit into the home folder.
//                         SUPERSEDED by ADR-0001 §1 — see the note above check 2.
//   4. VERIFY-GATE-PATHS  the post-unpack verify-gate paths the bootstrap checks
//                         (my-assistant/CLAUDE.md + skills/) exist at the repo root.
//   5. WINDOWS-NODE-PATH  the setup prompt's Windows branch installs Node via winget,
//                         refreshes the session PATH from the registry (machine +
//                         user) in the SAME PowerShell invocation as the node
//                         check, gates the quit/reopen step behind a failing
//                         post-refresh `node --version` (never speculative), and
//                         keeps the Playwright nodejs.org last-resort fallback.
//                         (PRD #385 slice #387.) Stays LIVE post-ADR-0001,
//                         checked against the pasted prompt sliced out of
//                         docs/start/setup.md; only its Loup-specific
//                         `npx @louphq/install` clause was dropped.
//
// Informational (never fails): snapshot file count + a note if Loup's caps are
// at risk. Media trimming is a separate slice; this only reports.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { extractPromptBody } from "./check-resilient-install.mjs";
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
  // The legacy-install fixture RECONSTRUCTS the pre-conform machine states in a
  // sandbox so migration can be dry-run against them. ~/workshop-kit is the
  // literal old kit home for both GitHub-era shapes — reproducing it is the
  // point, so these are stale-by-design, not drift.
  "scripts/make-legacy-fixture.mjs",
  "docs/agents/legacy-install-fixture.md",
  // ADR-0001 SPECIFIES the migration away from the legacy homes, so it names
  // them deliberately (MIGRATE fingerprint reconstruction, stale-home cleanup).
  "docs/adr/0001-pointer-block-install-model.md",
  // The setup document IMPLEMENTS that migration: Step 1.2 probes all three
  // legacy kit homes to rebuild skill fingerprints, and Step 3.4 deletes a
  // confirmed-stale ~/workshop-kit. Naming the old homes is the whole job here.
  "docs/start/setup.md",
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
  //
  // TWO of the three are pinned to the two-document, Loup-only canon that
  // ADR-0001 replaced (CORE-112 deleted docs/start/bootstrap.md and
  // docs/start/full-setup.md in favour of the single docs/start/setup.md):
  //   - bootstrap-consistency is retired outright by ADR-0001 §4 — the shared
  //     text now exists exactly once, so byte-drift is structurally impossible
  //     and there is no second copy to diff.
  //   - install-method asserts `npx @louphq/install` AND no git-clone-of-kit;
  //     ADR-0001 §1 made GitHub-clone and Loup CO-EQUAL doors behind one silent
  //     probe, so the new document must contain both. The assertion is now
  //     false by design, not by drift.
  // Re-expressing those two against the new canon is CORE-116, deliberately NOT
  // done here. Until then they skip loudly rather than being deleted or quietly
  // passing: an invariant nobody can see is how a regression gets in.
  //
  // windows-node-path is NOT in that category and stays live. Only its
  // Loup-specific `npx @louphq/install` clause died with the two-door change
  // (see checkWindowsNodePath clause c); the winget install, the machine+user
  // registry refresh, the one-invocation `node --version`, the process-only
  // statement and the nodejs.org fallback are all door-agnostic and still
  // enforced — now against the pasted prompt sliced out of setup.md, so the
  // attendee prose around it cannot satisfy a clause the prompt dropped.
  const legacyCanonPresent =
    existsSync(join(ROOT, "docs/start/bootstrap.md")) &&
    existsSync(join(ROOT, "docs/start/full-setup.md"));

  if (!legacyCanonPresent) {
    console.log(
      "SKIP bootstrap-consistency + install-method — docs/start/bootstrap.md " +
        "and docs/start/full-setup.md were replaced by docs/start/setup.md " +
        "(ADR-0001 §1/§4). Re-expressing these against the new canon is CORE-116.",
    );

    const setupRel = "docs/start/setup.md";
    let setupText = null;
    try {
      setupText = readFileSync(join(ROOT, setupRel), "utf8");
    } catch (e) {
      note(false, "windows-node-path", `cannot read ${setupRel}: ${e.message}`);
    }
    if (setupText !== null) {
      const { body, error } = extractPromptBody(setupText);
      if (error) {
        note(false, "windows-node-path", `${setupRel}: ${error}`);
      } else {
        const win = checkWindowsNodePath(body);
        note(win.ok, "windows-node-path", `${setupRel} (pasted prompt) — ${win.detail}`);
      }
    }
  } else {
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
