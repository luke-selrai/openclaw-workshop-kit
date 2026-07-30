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
  const skillDirs = listSkillDirs(SKILLS_DIR);
  const allHits = [];
  for (const name of skillDirs) {
    const abs = join(SKILLS_DIR, name, "SKILL.md");
    const rel = `skills/${name}/SKILL.md`;
    if (ANTI_PATTERN_ALLOWLIST.has(rel)) continue;
    allHits.push(...scanSkillForAntiPatterns(abs, rel));
  }
  return allHits;
}

// ---------------------------------------------------------------------------
// Description budget (CORE-93 / spec CORE-91)
//
// Every skill's frontmatter description is loaded into every attendee session
// before they type a word. Claude Code caps the whole skill listing at ~1% of
// the context window and silently drops descriptions past that, so an oversized
// description doesn't just waste tokens — it can strip another skill's triggers
// with no error. The canonical shape is third person: what it does + when to
// use it, procedure lives in the body.
//
// Rules over every skills/**/SKILL.md description:
//   description-over-budget      > DESCRIPTION_MAX_CHARS characters
//   description-first-person     "we / our / I / us …"
//   description-second-person    "you / your / yourself …"
//
// SHIPPING MODE — this is the switch CORE-98 flips.
//   "report"  : violations are reported, CI stays green (expand phase, while
//               the 200-odd rewrites land).
//   "enforce" : any violation fails `--check`.
// To contract (CORE-98): set DESCRIPTION_BUDGET_MODE to "enforce" and delete
// scripts/description-budget-baseline.json. Nothing else needs to change —
// the baseline is only ever read in report mode.
// `--descriptions-enforce` previews the enforcing outcome without flipping it.
const DESCRIPTION_BUDGET_MODE = "report";
const DESCRIPTION_MAX_CHARS = 500;
const DESCRIPTION_BASELINE_FILE = join(ROOT, "scripts", "description-budget-baseline.json");

// Escape hatch, same convention as ANTI_PATTERN_ALLOWLIST: explicit
// repo-root-relative paths. Empty on purpose — the rule's own fixtures live
// outside skills/, and a real skill gets fixed rather than allowlisted.
const DESCRIPTION_ALLOWLIST = new Set([]);

// Pronoun patterns. The "I" forms are case-SENSITIVE on purpose — a lowercase
// standalone "i" is almost always "i.e.", not a pronoun. Likewise all-caps "US"
// is the country ("Tier-1 connector for US SMBs"), not the pronoun.
const PERSON_PATTERNS = [
  { rule: "description-first-person", regex: /\b(?:I|I['’](?:m|ve|ll|d))\b/g },
  {
    rule: "description-first-person",
    regex: /\b(?:me|my|mine|myself|we|we['’](?:re|ve|ll|d)|us|our|ours|ourselves|let['’]s)\b/gi,
    skip: (token) => token === "US",
  },
  {
    rule: "description-second-person",
    regex: /\b(?:you|you['’](?:re|ve|ll|d)|your|yours|yourself|yourselves)\b/gi,
  },
];

// Quoted trigger phrases — `Use when the user says "connect my Xero"` — quote
// the USER's own words, which is exactly the recommended way to write triggers.
// Pronouns inside them are legitimate, so quoted spans are stripped before the
// person check only — never before the length check.
//
// Single quotes are the dominant style in this library (the YAML value itself is
// usually double-quoted), so they have to be handled, but a bare apostrophe
// (`the user's`) must not open a span: an opening quote has to follow the start
// of the string or an opening delimiter, and a closing quote has to be followed
// by whitespace, punctuation, or the end.
// The content may contain an apostrophe that is part of a word ("I'm using
// Next.js"), so an inner quote is allowed when a letter follows it.
const DOUBLE_QUOTED = /"[^"]*"|[“][^”]*[”]/g;
const SINGLE_QUOTED =
  /(^|[\s([])(?:'(?:[^']|'(?=[A-Za-z])){0,300}?'|[‘](?:[^’]|[’](?=[A-Za-z])){0,300}?[’])(?=[\s,.;:)\]!?]|$)/g;

function stripQuotedSpans(value) {
  return value.replace(DOUBLE_QUOTED, " ").replace(SINGLE_QUOTED, "$1 ");
}

// A pronoun glued into a path, domain, or hyphenated compound is not prose:
// `users/me`, `app.asana.com/0/my-apps`, `my.freshbooks.com`, `build-your-own-CRM`.
const GLUE_BEFORE = new Set(["/", ".", "-", "_", "@", "\\"]);
const GLUE_AFTER = new Set(["/", ".", "-", "_", "@", "\\"]);

function isGluedToken(prose, index, token) {
  if (index > 0 && GLUE_BEFORE.has(prose[index - 1])) return true;
  const after = prose[index + token.length];
  const afterNext = prose[index + token.length + 1];
  return GLUE_AFTER.has(after) && afterNext !== undefined && /[A-Za-z0-9]/.test(afterNext);
}

function matchPronouns(value, rule) {
  const prose = stripQuotedSpans(value);
  const found = [];
  for (const pattern of PERSON_PATTERNS) {
    if (pattern.rule !== rule) continue;
    for (const m of prose.matchAll(pattern.regex)) {
      if (pattern.skip?.(m[0])) continue;
      if (isGluedToken(prose, m.index, m[0])) continue;
      if (!found.includes(m[0])) found.push(m[0]);
    }
  }
  return found;
}

const DESCRIPTION_RULES = [
  {
    id: "description-over-budget",
    reason:
      `frontmatter description is over the ${DESCRIPTION_MAX_CHARS}-character budget. ` +
      "The skill listing is always-on context; procedure belongs in the SKILL.md body, " +
      "not the description. Target 150-250 chars: what it does + when to use it.",
    check: (value) =>
      value.length > DESCRIPTION_MAX_CHARS
        ? `${value.length} chars (budget ${DESCRIPTION_MAX_CHARS}, over by ${value.length - DESCRIPTION_MAX_CHARS})`
        : null,
  },
  {
    id: "description-first-person",
    reason:
      "frontmatter description uses first person. Descriptions are written in third " +
      "person about the skill ('Connects X…', 'Use when the user asks…'), not as the " +
      "author or the agent speaking.",
    check: (value) => {
      const found = matchPronouns(value, "description-first-person");
      return found.length ? `first-person pronouns: ${found.join(", ")}` : null;
    },
  },
  {
    id: "description-second-person",
    reason:
      "frontmatter description addresses the reader as 'you'. Descriptions are written " +
      "in third person about the skill and its trigger ('Use when the user wants…').",
    check: (value) => {
      const found = matchPronouns(value, "description-second-person");
      return found.length ? `second-person pronouns: ${found.join(", ")}` : null;
    },
  },
];

// --- Frontmatter description parsing ---------------------------------------
// The library uses every YAML scalar style: plain, double/single quoted,
// literal (|) and folded (>-) blocks, and a bare key with an indented block.
// No YAML dependency in this repo, so parse the one key we need.

function dedent(lines) {
  const indents = lines
    .filter((l) => l.trim() !== "")
    .map((l) => l.match(/^\s*/)[0].length);
  const cut = indents.length ? Math.min(...indents) : 0;
  return lines.map((l) => l.slice(cut));
}

// YAML folding: a single line break becomes a space, a blank line a newline.
function foldLines(lines) {
  let out = "";
  let pendingBreak = false;
  for (const raw of lines) {
    const t = raw.trim();
    if (t === "") {
      pendingBreak = out !== "";
      continue;
    }
    if (out === "") out = t;
    else if (pendingBreak) {
      out += `\n${t}`;
      pendingBreak = false;
    } else out += ` ${t}`;
  }
  return out;
}

function stripQuotes(raw, quote) {
  const close = raw.lastIndexOf(quote);
  return close > 0 ? raw.slice(1, close) : raw.slice(1);
}

function decodeScalar(head, continuation) {
  const first = head.trim();
  const body = dedent(continuation);

  if (/^[|>][+-]?\d*$/.test(first)) {
    return first.startsWith(">") ? foldLines(body) : body.join("\n");
  }
  if (first === "") return foldLines(body);
  if (first.startsWith('"')) {
    const inner = stripQuotes(foldLines([first, ...body]), '"');
    try {
      return JSON.parse(`"${inner}"`);
    } catch {
      return inner.replace(/\\(.)/g, "$1");
    }
  }
  if (first.startsWith("'")) {
    return stripQuotes(foldLines([first, ...body]), "'").replace(/''/g, "'");
  }
  return foldLines([first, ...body]);
}

// Returns { value, line } — line is the 1-based file line of the description
// key — or null when the file has no frontmatter or no description key.
function extractDescription(text) {
  const lines = text.split(/\r?\n/);
  if (lines[0]?.trim() !== "---") return null;

  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === "---" || t === "...") {
      end = i;
      break;
    }
  }
  if (end === -1) return null;

  const frontmatter = lines.slice(1, end);
  const keyIndex = frontmatter.findIndex((l) => /^description\s*:/.test(l));
  if (keyIndex === -1) return null;

  const head = frontmatter[keyIndex].replace(/^description\s*:/, "");
  const continuation = [];
  for (let i = keyIndex + 1; i < frontmatter.length; i++) {
    const l = frontmatter[i];
    if (l.trim() === "" || /^\s/.test(l)) continuation.push(l);
    else break;
  }
  while (continuation.length && continuation.at(-1).trim() === "") continuation.pop();

  return { value: decodeScalar(head, continuation).trim(), line: keyIndex + 2 };
}

function listSkillDirs(skillsDir) {
  return readdirSync(skillsDir).filter((name) => {
    const p = join(skillsDir, name);
    return statSync(p).isDirectory() && existsSync(join(p, "SKILL.md"));
  });
}

// [{ relPath, line, value }] for every SKILL.md under skillsDir. `value` is
// null when no description could be parsed.
function readSkillDescriptions({ skillsDir = SKILLS_DIR, relPrefix = "skills" } = {}) {
  return listSkillDirs(skillsDir).map((name) => {
    const relPath = `${relPrefix}/${name}/SKILL.md`;
    const parsed = extractDescription(readFileSync(join(skillsDir, name, "SKILL.md"), "utf8"));
    return { relPath, line: parsed ? parsed.line : null, value: parsed ? parsed.value : null };
  });
}

// [{ rule, detail }] for one description string.
function evaluateDescription(value) {
  const hits = [];
  for (const rule of DESCRIPTION_RULES) {
    const detail = rule.check(value);
    if (detail) hits.push({ rule: rule.id, detail, reason: rule.reason });
  }
  return hits;
}

// [{ relPath, line, rule, detail, reason, chars }] across a skills tree.
function auditDescriptions(options = {}) {
  const hits = [];
  for (const { relPath, line, value } of readSkillDescriptions(options)) {
    if (value === null || DESCRIPTION_ALLOWLIST.has(relPath)) continue;
    for (const hit of evaluateDescription(value)) {
      hits.push({ relPath, line, chars: value.length, ...hit });
    }
  }
  return hits;
}

function loadDescriptionBaseline() {
  if (!existsSync(DESCRIPTION_BASELINE_FILE)) return { violations: {} };
  const parsed = JSON.parse(readFileSync(DESCRIPTION_BASELINE_FILE, "utf8"));
  return { ...parsed, violations: parsed.violations || {} };
}

// known  = hit is in the baseline (a pre-existing violation, tolerated)
// novel  = hit is not in the baseline (regression or newly added skill)
// stale  = baseline entry with no matching hit (already fixed — safe to prune)
function classifyDescriptionHits(hits, baseline = loadDescriptionBaseline()) {
  const recorded = (baseline && baseline.violations) || {};
  const known = [];
  const novel = [];
  for (const hit of hits) {
    ((recorded[hit.relPath] || []).includes(hit.rule) ? known : novel).push(hit);
  }
  const live = new Set(hits.map((h) => `${h.relPath}::${h.rule}`));
  const stale = [];
  for (const [relPath, rules] of Object.entries(recorded)) {
    for (const rule of rules) {
      if (!live.has(`${relPath}::${rule}`)) stale.push({ relPath, rule });
    }
  }
  return { known, novel, stale };
}

// The one place the mode decides CI's fate. Report mode never fails.
function descriptionBudgetFails(hits, mode = DESCRIPTION_BUDGET_MODE) {
  return mode === "enforce" && hits.length > 0;
}

function writeDescriptionBaseline(hits) {
  const violations = {};
  for (const hit of hits.slice().sort((a, b) => a.relPath.localeCompare(b.relPath))) {
    (violations[hit.relPath] ||= []).push(hit.rule);
  }
  for (const rules of Object.values(violations)) rules.sort();
  const payload = {
    note:
      "CORE-93 report-only baseline: description-budget violations that already existed " +
      "when the rule shipped. Regenerate with `node scripts/audit-skills.mjs " +
      "--write-description-baseline`. CORE-98 (contract) DELETES this file and sets " +
      "DESCRIPTION_BUDGET_MODE = 'enforce' in scripts/audit-skills.mjs.",
    budget: DESCRIPTION_MAX_CHARS,
    generated: new Date().toISOString().slice(0, 10),
    count: hits.length,
    violations,
  };
  writeFileSync(DESCRIPTION_BASELINE_FILE, `${JSON.stringify(payload, null, 2)}\n`);
  return payload;
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
  const skillDirs = listSkillDirs(SKILLS_DIR);

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
  const budgetMode = args.includes("--descriptions-enforce") ? "enforce" : DESCRIPTION_BUDGET_MODE;

  if (args.includes("--write-description-baseline")) {
    const payload = writeDescriptionBaseline(auditDescriptions());
    console.log(
      `✏️  Wrote scripts/description-budget-baseline.json — ${payload.count} violation(s) across ${Object.keys(payload.violations).length} skill(s).`,
    );
    return;
  }

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

  // Description budget — always runs in both modes; never auto-mutates.
  const descriptionHits = auditDescriptions();
  const { known, novel, stale } = classifyDescriptionHits(descriptionHits);
  const enforcing = budgetMode === "enforce";
  const skillCount = readSkillDescriptions().length;

  console.log("");
  console.log("Description budget (CORE-93)");
  console.log("============================");
  console.log(`Mode                        : ${enforcing ? "ENFORCING — violations fail the check" : "report-only (CORE-98 flips to enforce)"}`);
  console.log(`Budget                      : ${DESCRIPTION_MAX_CHARS} chars`);
  console.log(`Descriptions scanned        : ${skillCount}`);
  console.log(`Violations                  : ${descriptionHits.length}${enforcing ? "" : ` (baselined ${known.length} / new ${novel.length})`}`);

  const show = (hit) => {
    console.log(`   ${hit.relPath}:${hit.line} [${hit.rule}] ${hit.detail}`);
  };

  if (enforcing) {
    for (const hit of descriptionHits) show(hit);
  } else {
    if (novel.length > 0) {
      console.log("");
      console.log(`❌ New description-budget violations, not in the baseline (${novel.length}):`);
      for (const hit of novel) show(hit);
      console.log("");
      for (const id of new Set(novel.map((h) => h.rule))) {
        console.log(`   [${id}] ${DESCRIPTION_RULES.find((r) => r.id === id).reason}`);
      }
      console.log("");
      console.log("Report-only mode, so this does not fail CI — but fix these rather than");
      console.log("baselining them; CORE-98 turns the rule into a hard failure.");
    }
    if (verbose) {
      for (const hit of known) show(hit);
      for (const entry of stale) {
        console.log(`   (fixed since baseline) ${entry.relPath} [${entry.rule}]`);
      }
    } else if (stale.length > 0) {
      console.log(`Fixed since baseline        : ${stale.length} (rerun --write-description-baseline to prune)`);
    }
  }

  if (descriptionHits.length === 0) {
    console.log("✓ Every skills/**/SKILL.md description is within budget and in third person.");
  }

  const budgetFails = descriptionBudgetFails(descriptionHits, budgetMode);
  if (budgetFails) {
    console.log("");
    console.log(`❌ ${descriptionHits.length} description-budget violation(s) — see above.`);
  }

  if (mode === "check" && (fileDrift || antiPatternHits.length > 0 || budgetFails)) {
    process.exit(1);
  }
}

export {
  extractDescription,
  evaluateDescription,
  readSkillDescriptions,
  auditDescriptions,
  classifyDescriptionHits,
  descriptionBudgetFails,
  loadDescriptionBaseline,
  writeDescriptionBaseline,
  DESCRIPTION_RULES,
  DESCRIPTION_MAX_CHARS,
  DESCRIPTION_BUDGET_MODE,
};

// Run only as a CLI, so tests can import the rules without triggering the audit.
if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  main();
}
