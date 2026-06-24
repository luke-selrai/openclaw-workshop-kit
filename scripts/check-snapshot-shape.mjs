#!/usr/bin/env node
// Snapshot-shape invariant — the gating check that keeps the kit deliverable
// through Loup. Loup ships the kit as a verbatim repo snapshot, so the kit is
// responsible for staying under Loup's snapshot limits with headroom; if a
// re-snapshot ever breaches a cap, an attendee's install breaks live.
//
// Measures the committed tree at a ref (default HEAD — what Loup actually
// publishes) and asserts:
//   - file count    < 2000
//   - archive bytes  < 45 MB   (gzipped tar, proxy for Loup's archive cap)
//   - unpacked bytes < 80 MB
//   - the post-unpack verify-gate paths the bootstrap checks are present at the
//     repo root: my-assistant/CLAUDE.md and skills/
//
// Caps come from the kit ↔ Loup contract (PRD selrai-company/claude-workshop-kit#385).
//
// Usage:
//   node scripts/check-snapshot-shape.mjs          human report, exit 1 if any cap breached
//   node scripts/check-snapshot-shape.mjs --json    machine-readable report
//
// Exit codes: 0 = within caps, 1 = a cap is breached, 2 = could not read git.

import { execFileSync } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Loup's snapshot ceilings are exclusive — a value AT the cap already fails, so
// the kit always sits strictly under with room to grow. WARN at 90% gives an
// early heads-up before a cap is actually hit.
export const CAPS = {
  maxFiles: 2000,
  maxArchiveBytes: 45 * 1024 * 1024,
  maxUnpackedBytes: 80 * 1024 * 1024,
  warnRatio: 0.9,
};

// Paths the bootstrap's Step 2 verify-gate checks after the snapshot unpacks.
// They must exist at the repo root or the verbatim-unpacked kit is unusable.
export const REQUIRED_PATHS = ["my-assistant/CLAUDE.md"];
export const REQUIRED_PREFIXES = ["skills/"];

// Pure decision function — given the measured shape, decide pass/warn/fail.
// Separated from git I/O so it can be unit-tested at the cap boundaries.
export function evaluateSnapshot(
  { fileCount, archiveBytes, unpackedBytes, paths },
  caps = CAPS,
) {
  const checks = [];

  const limit = (label, value, cap, unit) => {
    const over = value >= cap;
    const warn = !over && value >= cap * caps.warnRatio;
    checks.push({
      label,
      value,
      cap,
      unit,
      status: over ? "FAIL" : warn ? "WARN" : "PASS",
    });
  };

  limit("File count", fileCount, caps.maxFiles, "files");
  limit("Archive bytes (gzipped tar)", archiveBytes, caps.maxArchiveBytes, "bytes");
  limit("Unpacked bytes", unpackedBytes, caps.maxUnpackedBytes, "bytes");

  const pathSet = new Set(paths);
  for (const p of REQUIRED_PATHS) {
    const present = pathSet.has(p);
    checks.push({ label: `Verify-gate path: ${p}`, present, status: present ? "PASS" : "FAIL" });
  }
  for (const prefix of REQUIRED_PREFIXES) {
    const present = paths.some((p) => p.startsWith(prefix));
    checks.push({ label: `Verify-gate path: ${prefix}*`, present, status: present ? "PASS" : "FAIL" });
  }

  const ok = checks.every((c) => c.status !== "FAIL");
  return { checks, ok };
}

function git(args) {
  // 256 MB buffer comfortably holds the gzipped-tar archive (~tens of MB).
  return execFileSync("git", ["-C", ROOT, ...args], { maxBuffer: 256 * 1024 * 1024 });
}

// Measure the snapshot Loup would ship from `ref` (the committed tree).
export function gatherSnapshot(ref = "HEAD") {
  const archiveBytes = git(["archive", "--format=tar.gz", ref]).length;

  // `ls-tree -r -l` lines: "<mode> <type> <object> <size>\t<path>".
  const lsTree = git(["ls-tree", "-r", "-l", ref]).toString("utf8");
  let fileCount = 0;
  let unpackedBytes = 0;
  const paths = [];
  for (const line of lsTree.split("\n")) {
    if (!line) continue;
    const tab = line.indexOf("\t");
    if (tab === -1) continue;
    const meta = line.slice(0, tab).trim().split(/\s+/); // [mode, type, object, size]
    const path = line.slice(tab + 1);
    if (meta[1] !== "blob") continue; // skip submodule gitlinks etc.
    fileCount++;
    const size = meta[3];
    if (size !== "-") unpackedBytes += Number(size);
    paths.push(path);
  }

  return { fileCount, archiveBytes, unpackedBytes, paths };
}

function fmt(value, unit) {
  if (unit === "bytes") return `${(value / (1024 * 1024)).toFixed(1)} MB`;
  return `${value} ${unit}`;
}

function main() {
  const args = process.argv.slice(2);
  const asJson = args.includes("--json");

  let snapshot;
  let commit = "?";
  try {
    snapshot = gatherSnapshot("HEAD");
    commit = git(["rev-parse", "--short", "HEAD"]).toString("utf8").trim();
  } catch (e) {
    console.error(`Snapshot-shape check could not read git HEAD: ${e.message}`);
    process.exit(2);
  }

  const { checks, ok } = evaluateSnapshot(snapshot);

  if (asJson) {
    const { paths, ...measured } = snapshot;
    console.log(JSON.stringify({ commit, ...measured, checks, ok }, null, 2));
    process.exit(ok ? 0 : 1);
  }

  console.log("Snapshot-shape check");
  console.log("====================");
  console.log(`Measuring committed tree at HEAD (${commit})`);
  console.log("");
  for (const c of checks) {
    const icon = c.status === "PASS" ? "✓" : c.status === "WARN" ? "⚠️ " : "❌";
    if ("cap" in c) {
      const pct = ((c.value / c.cap) * 100).toFixed(0);
      console.log(`  ${icon} ${c.label.padEnd(28)} ${fmt(c.value, c.unit).padStart(12)}  (cap ${fmt(c.cap, c.unit)}, ${pct}%)`);
    } else {
      console.log(`  ${icon} ${c.label.padEnd(28)} ${c.present ? "present" : "MISSING"}`);
    }
  }
  console.log("");

  if (ok) {
    const warned = checks.some((c) => c.status === "WARN");
    console.log(warned
      ? "⚠️  Within Loup's snapshot caps, but approaching one — trim soon."
      : "✓ Snapshot is within Loup's caps with headroom.");
  } else {
    console.log("❌ Snapshot breaches a Loup cap (or a verify-gate path is missing).");
    console.log("   Trim the repo (see the media-trim slice) before re-snapshotting.");
  }

  process.exit(ok ? 0 : 1);
}

// Only run main() when invoked directly, not when imported by the test.
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
