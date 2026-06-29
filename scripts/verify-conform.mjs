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
//
// Informational (never fails): snapshot file count + a note if Loup's caps are
// at risk. Media trimming is a separate slice; this only reports.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, resolve, relative, extname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const VERBOSE = process.argv.includes("--verbose");

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

let hardFailed = false;
const note = (ok, label, detail) => {
  if (!ok) hardFailed = true;
  if (!ok || VERBOSE) {
    console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` — ${detail}` : ""}`);
  }
};

// ---- Check 1: PATH-CONFORM ------------------------------------------------
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
  if (text.includes("\u0000")) continue; // binary guard: skip files with NUL bytes
  const lines = text.split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    for (const p of STALE_PATTERNS) {
      if (p.re.test(lines[i])) staleHits.push(`${rel}:${i + 1} [${p.id}] ${lines[i].trim().slice(0, 100)}`);
    }
  }
}
note(staleHits.length === 0, "path-conform", staleHits.length === 0 ? `no stale kit-home refs; home is ${KIT_HOME}` : `${staleHits.length} stale ref(s):\n  ${staleHits.join("\n  ")}`);

// ---- Check 2 + 3: BOOTSTRAP-CONSIST + INSTALL-METHOD -----------------------
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
}

// ---- Check 4: VERIFY-GATE-PATHS -------------------------------------------
const gatePaths = ["my-assistant/CLAUDE.md", "skills"];
const missingGate = gatePaths.filter((p) => !existsSync(join(ROOT, p)));
note(missingGate.length === 0, "verify-gate-paths",
  missingGate.length === 0
    ? `${gatePaths.join(" + ")} present at repo root`
    : `missing: ${missingGate.join(", ")}`);

// ---- Informational: snapshot file count -----------------------------------
const snapshotFiles = walk(ROOT).filter((f) => !relative(ROOT, f).startsWith(".git"));
const FILE_CAP = 2000;
console.log(`INFO snapshot-shape — ${snapshotFiles.length} files (Loup cap < ${FILE_CAP})${snapshotFiles.length >= FILE_CAP ? " ⚠️ AT RISK" : ""}`);

if (!hardFailed) console.log("\n✅ verify-conform: all hard checks passed");
process.exit(hardFailed ? 1 : 0);
