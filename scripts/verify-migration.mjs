#!/usr/bin/env node
// Migration verifier — checks a legacy fixture's state AFTER the new setup
// prompt has been dry-run against it, so "the migration worked" is a tick list
// rather than an impression.
//
// Pairs with make-legacy-fixture.mjs: that builds the before-state and records
// what it planted in FIXTURE.json; this reads that record and asserts what the
// migration should have done to it. Keeping the expectations in the fixture's
// own record is what lets this work across all three legacy shapes without
// hardcoding any one layout.
//
// The checks come from the decisions locked in CORE-104. Run it against a
// fixture that has been through Steps 0-6 of the prompt; the restart-gated
// items (Playwright smoke test) are out of scope and not checked.
//
// Usage:
//   node scripts/verify-migration.mjs /tmp/legacy
//   node scripts/verify-migration.mjs /tmp/legacy --json
//
// Exit codes: 0 = every check passed, 1 = at least one failed, 2 = bad usage.

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

function read(p) {
  try {
    return readFileSync(p, "utf8");
  } catch {
    return null;
  }
}

function main() {
  const args = process.argv.slice(2);
  const json = args.includes("--json");
  const dir = args.find((a) => !a.startsWith("--"));
  if (!dir) {
    console.error("Usage: node scripts/verify-migration.mjs <fixture-dir> [--json]");
    process.exit(2);
  }

  const root = resolve(dir);
  const fx = read(join(root, "FIXTURE.json"));
  if (!fx) {
    console.error(`verify-migration: no FIXTURE.json in ${root}`);
    process.exit(2);
  }
  const rec = JSON.parse(fx);
  const home = rec.run.HOME;
  const claude = join(home, ".claude");
  const workspace = join(home, rec.layout.workspace.replace(/^~\//, ""));

  const checks = [];
  const check = (name, pass, detail = "") => checks.push({ name, pass: !!pass, detail });

  // --- pointer block + persona ---------------------------------------------
  const globalMd = read(join(claude, "CLAUDE.md")) || "";
  const blocks = (globalMd.match(/<!--\s*selr-kit:begin\s*-->/g) || []).length;
  check("pointer block present exactly once", blocks === 1, `found ${blocks}`);

  const persona = read(join(claude, "selr-assistant.md"));
  check("persona installed and non-empty", persona && persona.trim().length > 0);

  if (rec.options.globalClaudeMd === "user-content") {
    check(
      "pre-existing global content survived",
      globalMd.includes("Always call me Sam"),
      "hand-written instructions must not be eaten by the pointer block",
    );
  }

  // --- manifest -------------------------------------------------------------
  const manRaw = read(join(claude, "selr-kit-manifest.json"));
  check("manifest exists", manRaw !== null);
  let man = null;
  if (manRaw) {
    try {
      man = JSON.parse(manRaw);
    } catch {
      /* reported below */
    }
    check("manifest parses", man !== null);
  }
  if (man) {
    check("installMode is migrate", man.installMode === "migrate", `got ${man.installMode}`);
    check("onboarded is true (no re-onboarding)", man.onboarded === true, `got ${man.onboarded}`);
    const skillCount = man.skills ? Object.keys(man.skills).length : 0;
    check("manifest skills map populated", skillCount > 0, `${skillCount} entries`);
    check("kit home recorded", typeof man.kitHome === "string" && man.kitHome.length > 0, man.kitHome || "");
  }

  // --- old workspace retirement (shape-aware) -------------------------------
  check(
    "old workspace CLAUDE.md retired",
    existsSync(join(workspace, "CLAUDE.md.pre-migration")) && !existsSync(join(workspace, "CLAUDE.md")),
    `workspace ${rec.layout.workspace}`,
  );
  if (rec.layout.marker) {
    check("legacy marker removed", !existsSync(join(workspace, ".first-run-pending")));
  }

  // --- user-made content ----------------------------------------------------
  const seeded = rec.state.seeded;
  if (seeded) {
    if (seeded.workspaceFile) {
      const t = read(join(home, seeded.workspaceFile));
      check("user's workspace file untouched", t && t.includes("Do not lose this file."));
    }
    if (seeded.ownSkill) {
      const t = read(join(home, seeded.ownSkill, "SKILL.md"));
      check("user's own skill untouched", t && t.includes("Mine, not the kit's."));
    }
    if (seeded.editedKitSkill) {
      const t = read(join(home, seeded.editedKitSkill));
      check(
        "edited kit skill kept, not overwritten",
        t && t.includes("do not silently overwrite me"),
        seeded.editedKitSkill,
      );
    }
  }

  const failed = checks.filter((c) => !c.pass);
  if (json) {
    console.log(JSON.stringify({ shape: rec.shape, checks, passed: failed.length === 0 }, null, 2));
  } else {
    console.log(`Migration verification — shape: ${rec.shape}  (${root})`);
    for (const c of checks) {
      console.log(`  ${c.pass ? "PASS" : "FAIL"}  ${c.name}${c.detail ? `  [${c.detail}]` : ""}`);
    }
    console.log(
      failed.length === 0
        ? `\nAll ${checks.length} checks passed.`
        : `\n${failed.length} of ${checks.length} checks FAILED.`,
    );
  }
  process.exit(failed.length === 0 ? 0 : 1);
}

main();
