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
// SHIPPING MODE — CORE-98 flipped this, closing the expand/contract pair
// CORE-93 opened.
//   "report"  : violations are printed, CI stays green. The expand phase, while
//               the 200-odd rewrites landed. It read a baseline file
//               (scripts/description-budget-baseline.json) to separate
//               pre-existing violations from new ones; both the file and the
//               classification code went away with the flip.
//   "enforce" : any violation in a first-party skill fails `--check`. Shipped.
const DESCRIPTION_BUDGET_MODE = "enforce";
const DESCRIPTION_MAX_CHARS = 500;

// VENDORED (LOCK-PINNED) EXEMPTION
//
// skills-lock.json pins skills vendored from upstream repos (expo, stripe,
// inngest, vercel-labs, …) to a `computedHash` of the SKILL.md as it was
// fetched. Those hashes are historical artifacts of the original fetch and
// cannot be regenerated from this repo, so editing a pinned SKILL.md would
// leave the lock permanently wrong — the exhaustive attempt is documented on
// PR #414. Their descriptions are upstream's text, not this repo's to rewrite.
//
// So a pinned skill is exempt from hard-fail. It is NOT exempt from the scan:
// every exempt hit is printed under an explicit "vendored (lock-pinned)
// exemptions: N" heading on every run, because an exemption nobody can see is
// how upstream bloat quietly becomes permanent.
//
// The exempt set is derived from skills-lock.json at audit time — one source of
// truth, no hardcoded skill list. Adding a skill to the lock exempts it;
// un-vendoring one puts it back under the rule with no code change here.
//
// This is the rule's only exemption. A FIRST-PARTY skill gets rewritten, never
// exempted; the rule's own fixtures live outside skills/, so they never need it.
const SKILLS_LOCK_FILE = join(ROOT, "skills-lock.json");

// Pronoun patterns. Contractions need no alternatives of their own — the bare
// pronoun already matches ("I" in "I'm", "you" in "you're"), and that is the
// token reported. The "I" form is case-SENSITIVE on purpose: a lowercase
// standalone "i" is almost always "i.e.". Likewise all-caps "US" is the country
// ("Tier-1 connector for US SMBs"), not the pronoun.
const PERSON_PATTERNS = [
  { rule: "description-first-person", regex: /\bI\b/g },
  {
    rule: "description-first-person",
    regex: /\b(?:me|my|mine|myself|we|us|our|ours|ourselves)\b/gi,
    skip: (token) => token === "US",
  },
  {
    rule: "description-second-person",
    regex: /\b(?:you|your|yours|yourself|yourselves)\b/gi,
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
// `GET /api/3/users/me`, `app.asana.com/0/my-apps`, `my.freshbooks.com`,
// `build-your-own-CRM`. The test is on the whole whitespace-delimited chunk the
// pronoun sits in, not just its neighbouring character — otherwise real prose
// like "you/they" or "read/write/your files" would be silently swallowed and a
// genuine violation would escape the rule.
const PATH_LIKE = /^[~./]|:\/\/|[A-Za-z0-9]\.[A-Za-z]{2,}/;
const IDENTIFIER_LIKE = /[_@\\]/;
const HYPHEN_COMPOUND = /[A-Za-z0-9]-[A-Za-z0-9]/;

function isGluedToken(prose, index, token) {
  let start = index;
  let end = index + token.length;
  while (start > 0 && !/\s/.test(prose[start - 1])) start--;
  while (end < prose.length && !/\s/.test(prose[end])) end++;
  const chunk = prose.slice(start, end).replace(/[.,;:!?)\]]+$/, "");
  if (chunk === token) return false;
  return PATH_LIKE.test(chunk) || IDENTIFIER_LIKE.test(chunk) || HYPHEN_COMPOUND.test(chunk);
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

// Content between the opening quote and the FIRST real closing quote — not the
// last one, or a trailing YAML comment (`description: "…"  # note`) would be
// swallowed into the value, inflating its length and importing stray pronouns.
// `\"` escapes inside double quotes; `''` escapes inside single quotes.
function stripQuotes(raw, quote) {
  for (let i = 1; i < raw.length; i++) {
    if (quote === '"' && raw[i] === "\\") {
      i++;
      continue;
    }
    if (raw[i] !== quote) continue;
    if (quote === "'" && raw[i + 1] === "'") {
      i++;
      continue;
    }
    return raw.slice(1, i);
  }
  return raw.slice(1);
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

  // Only an UNINDENTED `---` closes the frontmatter. An indented one is content
  // inside a block scalar, and treating it as the terminator would silently
  // truncate the description (hiding the rest of it from both rules).
  let end = -1;
  for (let i = 1; i < lines.length; i++) {
    if (/^(?:---|\.\.\.)\s*$/.test(lines[i])) {
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
    if (value === null) continue;
    for (const hit of evaluateDescription(value)) {
      hits.push({ relPath, line, chars: value.length, ...hit });
    }
  }
  return hits;
}

// A lock key is the upstream skill's own name, which is usually already the
// local directory name ("node", "hyperframes") but is occasionally a display
// name ("Expo UI SwiftUI" → skills/expo-ui-swiftui/).
function slugifyLockKey(key) {
  return key
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// Every name a lock entry could be known by locally, unioned across entries.
// Three candidates per entry, because none is reliable alone:
//   - the key verbatim              ("fastify-best-practices")
//   - the key slugified             ("Expo UI SwiftUI" → "expo-ui-swiftui")
//   - the skillPath's parent dir    (upstream's own folder, which sometimes
//                                    differs from the local one both ways:
//                                    key "vercel-react-view-transitions" ships
//                                    from upstream "skills/react-view-transitions/")
// Membership is tested against a real on-disk skill directory name, so the
// extra candidates cannot exempt anything that does not exist.
function loadPinnedSkillDirs(lockFile = SKILLS_LOCK_FILE) {
  if (!existsSync(lockFile)) return new Set();
  const parsed = JSON.parse(readFileSync(lockFile, "utf8"));
  const pinned = new Set();
  for (const [key, entry] of Object.entries(parsed.skills || {})) {
    pinned.add(key);
    pinned.add(slugifyLockKey(key));
    const skillPath = entry && entry.skillPath;
    if (typeof skillPath === "string") {
      const segments = skillPath.split("/").filter(Boolean);
      if (segments.length >= 2) pinned.add(segments.at(-2));
    }
  }
  return pinned;
}

// "skills/xero-connector/SKILL.md" → "xero-connector"
function skillDirFromRelPath(relPath) {
  const segments = String(relPath).split("/").filter(Boolean);
  return segments.length >= 2 ? segments.at(-2) : null;
}

// exempt  = the skill's directory is pinned in skills-lock.json (vendored
//           upstream text — reported every run, never fails the check)
// failing = everything else, i.e. first-party skills this repo owns and can fix
function partitionDescriptionHits(hits, pinned = loadPinnedSkillDirs()) {
  const exempt = [];
  const failing = [];
  for (const hit of hits) {
    (pinned.has(skillDirFromRelPath(hit.relPath)) ? exempt : failing).push(hit);
  }
  return { exempt, failing };
}

// The one place the mode decides CI's fate. Takes the FAILING hits — exempt
// ones have already been partitioned out by the caller.
function descriptionBudgetFails(failingHits, mode = DESCRIPTION_BUDGET_MODE) {
  return mode === "enforce" && failingHits.length > 0;
}

// Expand-phase scaffolding CORE-98 removed. Kept as an explicit error rather
// than dropped silently: a removed flag that no-ops looks exactly like a flag
// that worked, and both of these used to change whether CI passed.
const REMOVED_FLAGS = {
  "--write-description-baseline":
    "the baseline was deleted when the rule flipped to enforce. Fix the description " +
    "instead of re-baselining it — a vendored, lock-pinned skill is already exempt.",
  "--descriptions-enforce":
    "enforce is the shipped mode now, so there is nothing left to preview.",
};

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

  for (const [flag, why] of Object.entries(REMOVED_FLAGS)) {
    if (args.includes(flag)) {
      console.error(`❌ ${flag} was removed by CORE-98 — ${why}`);
      process.exit(2);
    }
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
  const { exempt, failing } = partitionDescriptionHits(descriptionHits);
  const enforcing = DESCRIPTION_BUDGET_MODE === "enforce";

  console.log("");
  console.log("Description budget (CORE-91 / CORE-93, enforced by CORE-98)");
  console.log("==========================================================");
  console.log(`Mode                        : ${enforcing ? "ENFORCING — violations fail the check" : "report-only"}`);
  console.log(`Budget                      : ${DESCRIPTION_MAX_CHARS} chars`);
  console.log(`Descriptions scanned        : ${stats.totalSkills}`);
  console.log(`Violations                  : ${descriptionHits.length} (failing ${failing.length} / vendored-exempt ${exempt.length})`);

  const show = (hit, withReason = false) => {
    console.log(`   ${hit.relPath}:${hit.line} [${hit.rule}] ${hit.detail}`);
    if (withReason) console.log(`     ${hit.reason}`);
  };

  // Printed in full on every run, pass or fail. The exemption is a standing
  // debt against upstream text, and a debt nobody is shown stops being one.
  console.log("");
  console.log(`vendored (lock-pinned) exemptions: ${exempt.length}`);
  if (exempt.length > 0) {
    for (const hit of exempt) show(hit);
    console.log("   Pinned in skills-lock.json to an upstream hash this repo cannot regenerate,");
    console.log("   so the text is not ours to rewrite. Scanned and reported, never failed.");
  }

  if (failing.length > 0) {
    // Same shape as the anti-pattern block above: every failing hit prints the
    // reason it failed, so an author can act on the output alone.
    console.log("");
    console.log(`❌ Description-budget violations in first-party skills (${failing.length}):`);
    for (const hit of failing) show(hit, true);
  } else {
    console.log("");
    console.log("✓ Every first-party skills/**/SKILL.md description is within budget and in third person.");
  }

  if (verbose) {
    console.log("");
    console.log(`Lock-pinned skill names (${loadPinnedSkillDirs().size} aliases across skills-lock.json entries).`);
  }

  const budgetFails = descriptionBudgetFails(failing);
  if (budgetFails) {
    console.log("");
    console.log(`❌ ${failing.length} description-budget violation(s) — see above.`);
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
  slugifyLockKey,
  loadPinnedSkillDirs,
  partitionDescriptionHits,
  descriptionBudgetFails,
  REMOVED_FLAGS,
  DESCRIPTION_RULES,
  DESCRIPTION_MAX_CHARS,
  DESCRIPTION_BUDGET_MODE,
  SKILLS_LOCK_FILE,
};

// Run only as a CLI, so tests can import the rules without triggering the audit.
if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  main();
}
