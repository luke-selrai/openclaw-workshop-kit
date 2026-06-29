#!/usr/bin/env node
// Tests for the snapshot-shape gating check (check-snapshot-shape.mjs).
//
// Unit tests exercise evaluateSnapshot() at the cap boundaries (exclusive caps,
// 90% warn band, missing verify-gate paths). An integration test runs the real
// script against this repo's HEAD and asserts it reports within caps — proving
// the git plumbing works and the kit is actually under Loup's limits.

import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { CAPS, evaluateSnapshot } from "./check-snapshot-shape.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
let failed = false;

function check(name, cond) {
  if (cond) {
    console.log(`PASS ${name}`);
  } else {
    console.error(`FAIL ${name}`);
    failed = true;
  }
}

// A baseline shape comfortably inside every cap, with both verify-gate paths.
const okShape = {
  fileCount: 1500,
  archiveBytes: 10 * 1024 * 1024,
  unpackedBytes: 20 * 1024 * 1024,
  paths: ["my-assistant/CLAUDE.md", "skills/example/SKILL.md"],
};

function statusOf(result, label) {
  return result.checks.find((c) => c.label.startsWith(label))?.status;
}

// 1. A healthy snapshot passes everything.
{
  const r = evaluateSnapshot(okShape);
  check("healthy shape is ok", r.ok === true);
  check("healthy shape has no FAIL/WARN", r.checks.every((c) => c.status === "PASS"));
}

// 2. Caps are exclusive — a value exactly AT the cap fails.
{
  const r = evaluateSnapshot({ ...okShape, fileCount: CAPS.maxFiles });
  check("file count at cap FAILs (cap is exclusive)", statusOf(r, "File count") === "FAIL");
  check("file count at cap makes snapshot not ok", r.ok === false);
}
{
  // One under the exclusive cap still clears the gate (it warns, since 1999 is
  // inside the 90% band, but it does not FAIL).
  const r = evaluateSnapshot({ ...okShape, fileCount: CAPS.maxFiles - 1 });
  check("file count one under cap does not FAIL", statusOf(r, "File count") !== "FAIL" && r.ok === true);
}
{
  // A value below the warn band is a clean PASS.
  const r = evaluateSnapshot({ ...okShape, fileCount: Math.floor(CAPS.maxFiles * 0.5) });
  check("file count well under cap PASSes", statusOf(r, "File count") === "PASS" && r.ok === true);
}

// 3. The 90% warn band warns without failing.
{
  const warnCount = Math.ceil(CAPS.maxFiles * CAPS.warnRatio); // 1800
  const r = evaluateSnapshot({ ...okShape, fileCount: warnCount });
  check("file count in warn band WARNs", statusOf(r, "File count") === "WARN");
  check("warn band stays ok (does not fail)", r.ok === true);
}

// 4. Byte caps fail at the limit.
{
  const r = evaluateSnapshot({ ...okShape, archiveBytes: CAPS.maxArchiveBytes });
  check("archive bytes at cap FAILs", statusOf(r, "Archive bytes") === "FAIL" && r.ok === false);
}
{
  const r = evaluateSnapshot({ ...okShape, unpackedBytes: CAPS.maxUnpackedBytes });
  check("unpacked bytes at cap FAILs", statusOf(r, "Unpacked bytes") === "FAIL" && r.ok === false);
}

// 5. Missing verify-gate paths fail.
{
  const r = evaluateSnapshot({ ...okShape, paths: ["skills/example/SKILL.md"] });
  check("missing my-assistant/CLAUDE.md FAILs", r.ok === false);
}
{
  const r = evaluateSnapshot({ ...okShape, paths: ["my-assistant/CLAUDE.md"] });
  check("missing skills/ prefix FAILs", r.ok === false);
}

// 6. Integration: the real script passes against this repo's HEAD.
{
  let ok = false;
  try {
    const out = execFileSync("node", [join(HERE, "check-snapshot-shape.mjs"), "--json"], {
      cwd: resolve(HERE, ".."),
      maxBuffer: 256 * 1024 * 1024,
    }).toString("utf8");
    const report = JSON.parse(out);
    ok = report.ok === true && report.fileCount < CAPS.maxFiles && report.archiveBytes < CAPS.maxArchiveBytes;
  } catch (e) {
    console.error(`  (integration run failed: ${e.message})`);
  }
  check("real repo HEAD is within snapshot caps", ok);
}

process.exit(failed ? 1 : 0);
