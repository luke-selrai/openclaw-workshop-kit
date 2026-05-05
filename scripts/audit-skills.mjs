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

// Anti-pattern rules applied to every skills/**/SKILL.md.
// Both patterns are descriptively wrong and would mislead anyone authoring a
// sibling connector by analogy. See issue #200 and PR #208 (closes #198).
//
// Allowlist entries are explicit — paths relative to repo root. Used only for
// the audit tool's own regression fixtures. Production SKILLs must be fixed,
// not allowlisted.
const ANTI_PATTERN_ALLOWLIST = new Set([
  "scripts/__fixtures__/anti-patterns.md",
]);

const ANTI_PATTERN_RULES = [
  {
    id: "www-authenticate-bearer",
    regex: /WWW-Authenticate:\s*Bearer/i,
    reason:
      "claims auth discovery via 'WWW-Authenticate: Bearer' challenge. " +
      "Hosted MCP servers use well-known OAuth discovery (/.well-known/oauth-protected-resource, " +
      "/.well-known/oauth-authorization-server). See c06edab on PR #192 for the corrected " +
      "description, or PR #208 (closes #198) for the broader rewrite.",
  },
  {
    id: "claude-mcp-authenticate-cli",
    regex: /claude\s+mcp\s+authenticate\b/,
    reason:
      "references 'claude mcp authenticate' as a CLI subcommand. No such verb exists in any " +
      "shipped Claude Code build (confirmed against `claude mcp --help` in 2.1.123). " +
      "Use the runtime-surfaced 'mcp__<server>__authenticate' tool instead. See PR #208 (closes #198).",
  },
];

function scanSkillForAntiPatterns(absPath, relPath) {
  const text = readFileSync(absPath, "utf8");
  const lines = text.split(/\r?\n/);
  const hits = [];
  for (let i = 0; i < lines.length; i++) {
    for (const rule of ANTI_PATTERN_RULES) {
      if (rule.regex.test(lines[i])) {
        hits.push({ rule: rule.id, line: i + 1, reason: rule.reason, relPath });
      }
    }
  }
  return hits;
}

function auditAntiPatterns() {
  const skillDirs = readdirSync(SKILLS_DIR).filter((name) => {
    const p = join(SKILLS_DIR, name);
    return statSync(p).isDirectory() && existsSync(join(p, "SKILL.md"));
  });
  const allHits = [];
  for (const name of skillDirs) {
    const abs = join(SKILLS_DIR, name, "SKILL.md");
    const rel = `skills/${name}/SKILL.md`;
    if (ANTI_PATTERN_ALLOWLIST.has(rel)) continue;
    allHits.push(...scanSkillForAntiPatterns(abs, rel));
  }
  return allHits;
}

const TARGET_FILES = [
  "README.md",
  "docs/skills/README.md",
  "docs/start/bootstrap.md",
  "docs/start/full-setup.md",
  "docs/install/subscriptions-and-software.md",
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

  // Anti-pattern scan — always runs in both modes; never auto-mutates.
  const antiPatternHits = auditAntiPatterns();
  if (antiPatternHits.length > 0) {
    console.log("");
    console.log(`❌ Anti-pattern hits (${antiPatternHits.length}):`);
    for (const hit of antiPatternHits) {
      console.log(`   ${hit.relPath}:${hit.line} [${hit.rule}]`);
      console.log(`     ${hit.reason}`);
    }
  } else {
    console.log("");
    console.log("✓ No anti-pattern hits across skills/**/SKILL.md.");
  }

  if (mode === "check" && (fileDrift || antiPatternHits.length > 0)) {
    process.exit(1);
  }
}

main();
