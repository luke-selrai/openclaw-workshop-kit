#!/usr/bin/env node
// Audits skill counts and connector lists against the on-disk truth and
// rewrites or verifies marker-bracketed sections in the discovery-surface docs.
//
// Modes:
//   --check   read-only; exit 1 on any drift (used in CI)
//   --write   apply changes to bring docs in sync (used by humans before commit)
//
// Source of truth:
//   - Total skills        : count of skills/*/SKILL.md
//   - Connectors          : skills/*-connector/ directories, alphabetised
//   - CORE / ADVANCED     : tier column in skills/SKILLS-LIST.md
//   - DEV-ONLY            : tier column in skills/SKILLS-LIST.md
//
// Marker shapes (case-sensitive):
//   <!-- skills-audit:total -->97<!-- /skills-audit:total -->
//   <!-- skills-audit:core -->22<!-- /skills-audit:core -->
//   <!-- skills-audit:advanced -->56<!-- /skills-audit:advanced -->
//   <!-- skills-audit:dev-only -->8<!-- /skills-audit:dev-only -->
//   <!-- skills-audit:connectors-count -->16<!-- /skills-audit:connectors-count -->

import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS_DIR = join(ROOT, "skills");
const SKILLS_LIST = join(SKILLS_DIR, "SKILLS-LIST.md");

const TARGET_FILES = [
  "README.md",
  "SKILLS-GUIDE.md",
  "docs/BOOTSTRAP.md",
  "docs/FULL-SETUP-PAGE.md",
  "docs/SKILLS-REFERENCE.md",
  "docs/SUBSCRIPTIONS-AND-SOFTWARE.md",
  "docs/TELEGRAM-SETUP.md",
  "skills/SKILLS-LIST.md",
  "visuals/PAGE-1-AI-MODELS.md",
  "visuals/PAGE-2-YOUR-SETUP.md",
  "visuals/PAGE-3-SKILLS-AND-AGENTS.md",
  "visuals/PAGE-4-FULL-ECOSYSTEM.md",
];

const MARKERS = ["total", "core", "advanced", "dev-only", "connectors-count"];

function gatherStats() {
  const skillDirs = readdirSync(SKILLS_DIR).filter((name) => {
    const p = join(SKILLS_DIR, name);
    return statSync(p).isDirectory() && existsSync(join(p, "SKILL.md"));
  });

  const totalSkills = skillDirs.length;

  const connectors = skillDirs
    .filter((name) => name.endsWith("-connector"))
    .sort();

  // Parse SKILLS-LIST.md table for tier counts.
  // Rows look like: | `skill-name` | description | example | TIER |
  const list = readFileSync(SKILLS_LIST, "utf8");
  const tierRowRegex = /^\|\s*`([a-z0-9-]+)`\s*\|.*\|\s*(CORE|ADVANCED|DEV-ONLY)\s*\|/gim;
  const classified = new Map();
  let m;
  while ((m = tierRowRegex.exec(list)) !== null) {
    classified.set(m[1], m[2]);
  }

  const coreCount = [...classified.values()].filter((t) => t === "CORE").length;
  const advancedCount = [...classified.values()].filter((t) => t === "ADVANCED").length;
  const devOnlyCount = [...classified.values()].filter((t) => t === "DEV-ONLY").length;
  const classifiedTotal = coreCount + advancedCount + devOnlyCount;

  const onDisk = new Set(skillDirs);
  const inList = new Set(classified.keys());
  const missingFromList = [...onDisk].filter((s) => !inList.has(s)).sort();
  const missingFromDisk = [...inList].filter((s) => !onDisk.has(s)).sort();

  return {
    totalSkills,
    coreCount,
    advancedCount,
    devOnlyCount,
    classifiedTotal,
    connectors,
    connectorsCount: connectors.length,
    missingFromList,
    missingFromDisk,
  };
}

function rewriteFile(absPath, stats) {
  if (!existsSync(absPath)) return { changed: false, content: null };

  const original = readFileSync(absPath, "utf8");
  let updated = original;

  const replacements = {
    total: String(stats.totalSkills),
    core: String(stats.coreCount),
    advanced: String(stats.advancedCount),
    "dev-only": String(stats.devOnlyCount),
    "connectors-count": String(stats.connectorsCount),
  };

  for (const marker of MARKERS) {
    const re = new RegExp(
      `<!--\\s*skills-audit:${marker}\\s*-->[\\s\\S]*?<!--\\s*/skills-audit:${marker}\\s*-->`,
      "g",
    );
    updated = updated.replace(
      re,
      `<!-- skills-audit:${marker} -->${replacements[marker]}<!-- /skills-audit:${marker} -->`,
    );
  }

  return { changed: updated !== original, content: updated };
}

function main() {
  const args = process.argv.slice(2);
  const mode = args.includes("--write") ? "write" : "check";
  const verbose = args.includes("--verbose");

  const stats = gatherStats();

  console.log("Skill audit");
  console.log("===========");
  console.log(`Total skills on disk        : ${stats.totalSkills}`);
  console.log(`  CORE (from SKILLS-LIST)   : ${stats.coreCount}`);
  console.log(`  ADVANCED (from list)      : ${stats.advancedCount}`);
  console.log(`  DEV-ONLY (from list)      : ${stats.devOnlyCount}`);
  console.log(`  Classified total          : ${stats.classifiedTotal}`);
  console.log(`  Unclassified              : ${stats.totalSkills - stats.classifiedTotal}`);
  console.log(`Connectors on disk          : ${stats.connectorsCount}`);
  console.log("");

  // Classification gaps are soft warnings — they don't fail CI on their own.
  // Only file-content drift (markers out of sync with disk truth) fails the check.
  let fileDrift = false;

  if (stats.missingFromList.length > 0) {
    console.log(`⚠️  Skills on disk but missing from skills/SKILLS-LIST.md (${stats.missingFromList.length}) — soft warning, does not fail CI:`);
    for (const s of stats.missingFromList) console.log(`     - ${s}`);
    console.log("");
  }

  if (stats.missingFromDisk.length > 0) {
    console.log(`⚠️  Skills in skills/SKILLS-LIST.md but missing from disk (${stats.missingFromDisk.length}) — soft warning, does not fail CI:`);
    for (const s of stats.missingFromDisk) console.log(`     - ${s}`);
    console.log("");
  }

  if (verbose) {
    console.log(`Connectors (${stats.connectorsCount}):`);
    for (const c of stats.connectors) console.log(`  - ${c}`);
    console.log("");
  }

  const changedFiles = [];
  const unchangedFiles = [];
  for (const rel of TARGET_FILES) {
    const abs = join(ROOT, rel);
    const result = rewriteFile(abs, stats);
    if (result.content === null) {
      console.log(`  (skip — not found) ${rel}`);
      continue;
    }
    if (result.changed) {
      changedFiles.push(rel);
      if (mode === "write") writeFileSync(abs, result.content);
    } else {
      unchangedFiles.push(rel);
    }
  }

  if (mode === "write") {
    if (changedFiles.length > 0) {
      console.log(`✏️  Wrote updates to ${changedFiles.length} file(s):`);
      for (const f of changedFiles) console.log(`     - ${f}`);
    } else {
      console.log("✓ All marker sections already in sync — nothing to write.");
    }
  } else {
    if (changedFiles.length > 0) {
      console.log(`❌ Drift detected in ${changedFiles.length} file(s):`);
      for (const f of changedFiles) console.log(`     - ${f}`);
      console.log("");
      console.log("Run `node scripts/audit-skills.mjs --write` to fix, then commit the result.");
      fileDrift = true;
    } else {
      console.log(`✓ All ${unchangedFiles.length} target file(s) in sync.`);
    }
  }

  if (mode === "check" && fileDrift) {
    process.exit(1);
  }
}

main();
