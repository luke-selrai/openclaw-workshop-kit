#!/usr/bin/env node
// Verifies the Matt Pocock power-user-skills install contract in
// skills/first-run-setup/SKILL.md (Phase 2.5 Step 3). LOUP-19.
//
// History: upstream renamed `diagnose` → `diagnosing-bugs` and the hardcoded
// `-s diagnose` selector silently stripped skills from attendees, with a
// failure branch that hand-waved it as "probably a network hiccup". This
// checker is the regression backstop for the fixed contract: current names,
// on-disk verification, a self-heal (list → resolve renames → retry) pass
// that covers the all-four-missing case, and an honest per-skill summary.
//
// Modes:
//   (default) / --check   read-only static checks; exit 1 on any failure
//   --verbose             also print every passing check
//   --live                additionally list the live mattpocock/skills repo
//                         via the GitHub API and assert every expected skill
//                         still exists under its expected name — CI goes red
//                         at the NEXT upstream rename instead of attendees
//                         silently losing skills.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const TARGET = "skills/first-run-setup/SKILL.md";
const UPSTREAM_REPO = "mattpocock/skills";

// The four skills the workshop installs, under their CURRENT upstream names.
// When upstream renames one, update it here AND in the Step 3 body — the
// --live check is what tells you a rename happened.
export const EXPECTED_SKILLS = ["grill-me", "handoff", "diagnosing-bugs", "teach"];

// Names that no longer exist upstream and must never reappear in Step 3.
export const STALE_NAMES = ["diagnose"];

const STEP_START = "### Step 3 - Install power-user skills";
const STEP_END = "## PHASE 3";

export function extractStepBody(text) {
  const start = text.indexOf(STEP_START);
  const end = text.indexOf(STEP_END, start === -1 ? 0 : start);
  if (start === -1 || end === -1 || end < start) {
    return { error: `Step 3 anchors not found (start=${start}, end=${end})` };
  }
  return { body: text.slice(start, end) };
}

// Each rule must hold in the Step 3 body.
export const RULES = [
  {
    id: "current-selectors",
    why: `install command selects every expected skill by its current name (${EXPECTED_SKILLS.join(", ")})`,
    test: (b) => EXPECTED_SKILLS.every((s) => new RegExp(`-s ${s}(?![\\w-])`).test(b)),
  },
  {
    id: "verify-paths",
    why: "every expected skill's ~/.claude/skills/<name>/SKILL.md path is checked on disk",
    test: (b) => EXPECTED_SKILLS.every((s) => b.includes(`~/.claude/skills/${s}/SKILL.md`)),
  },
  {
    id: "no-stale-names",
    why: `no stale skill name survives as a selector, path, or bold mention (${STALE_NAMES.join(", ")})`,
    test: (b) =>
      STALE_NAMES.every(
        (s) => !new RegExp(`(-s ${s}|skills/${s}/|\\*\\*${s}\\*\\*)(?![\\w-])`).test(b),
      ),
  },
  {
    id: "self-heal-listing",
    why: "a miss triggers listing the repo's live skills (the CLI's -l flag), not a hardcoded retry",
    test: (b) => new RegExp(`add ${UPSTREAM_REPO} -l\\b`).test(b),
  },
  {
    id: "rename-resolution",
    why: "renames are resolved dynamically against the listing, then the install is retried",
    test: (b) => /renam/i.test(b) && /resolved/i.test(b) && /re-run|retry/i.test(b),
  },
  {
    id: "zero-installed-case",
    why: "the self-heal pass explicitly covers ALL four missing, not just a partial miss",
    test: (b) => /all[- ]four[- ](are[- ])?missing/i.test(b),
  },
  {
    id: "visible-summary",
    why: "step always ends with a per-skill ✅/❌ summary readable at a glance",
    test: (b) => b.includes("✅") && b.includes("❌") && /summary/i.test(b),
  },
  {
    id: "honest-reporting",
    why: "missing skills report the actual command output — no invented causes",
    test: (b) => /never (invent|paraphrase)/i.test(b),
  },
  {
    id: "no-handwave",
    why: 'no "network hiccup" hand-wave and no tell-a-facilitator escalation',
    test: (b) => !/network hiccup/i.test(b) && !/facilitator/i.test(b),
  },
  {
    id: "non-blocking",
    why: "a miss stays non-blocking — setup continues to Phase 3 either way",
    test: (b) => /NOT a setup blocker/i.test(b) && /continue to Phase 3 either way/i.test(b),
  },
];

/**
 * Evaluate the install contract against a Step 3 body. Returns
 * { pass, rules: [{ id, ok, why, detail }] } so the CLI and the regression
 * test share one source of truth rather than mirroring regexes.
 */
export function evaluateInstallContract(body) {
  const rules = RULES.map((r) => ({
    id: r.id,
    ok: r.test(body),
    why: r.why,
    detail: r.test(body) ? "present" : `missing: ${r.why}`,
  }));
  return { pass: rules.every((r) => r.ok), rules };
}

/**
 * List the live upstream repo's skill names via the GitHub API (the git tree,
 * one request, no cloning) and return the set of directory names that contain
 * a SKILL.md anywhere under skills/.
 */
export async function fetchLiveSkillNames(fetchImpl = fetch) {
  const res = await fetchImpl(
    `https://api.github.com/repos/${UPSTREAM_REPO}/git/trees/main?recursive=1`,
    { headers: { accept: "application/vnd.github+json", "user-agent": "claude-workshop-kit-ci" } },
  );
  if (!res.ok) throw new Error(`GitHub API ${res.status} listing ${UPSTREAM_REPO}`);
  const { tree } = await res.json();
  const names = new Set();
  for (const entry of tree) {
    const m = /^skills\/(?:[^/]+\/)*([^/]+)\/SKILL\.md$/.exec(entry.path);
    if (m) names.add(m[1]);
  }
  return names;
}

// ---- CLI ------------------------------------------------------------------
if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  const VERBOSE = process.argv.includes("--verbose");
  const LIVE = process.argv.includes("--live");
  let failed = false;

  const note = (ok, label, detail) => {
    if (!ok) failed = true;
    if (!ok || VERBOSE) {
      console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` — ${detail}` : ""}`);
    }
  };

  const { body, error } = extractStepBody(readFileSync(join(ROOT, TARGET), "utf8"));
  if (error) {
    note(false, TARGET, error);
  } else {
    const { rules } = evaluateInstallContract(body);
    for (const r of rules) note(r.ok, `${TARGET} [${r.id}]`, r.detail);
  }

  if (LIVE) {
    try {
      const live = await fetchLiveSkillNames();
      for (const s of EXPECTED_SKILLS) {
        note(
          live.has(s),
          `live upstream [${s}]`,
          live.has(s)
            ? "exists"
            : `not found in ${UPSTREAM_REPO} — upstream renamed/removed it; re-resolve and update EXPECTED_SKILLS + Step 3`,
        );
      }
    } catch (e) {
      note(false, "live upstream listing", String(e));
    }
  }

  if (!failed && !VERBOSE) console.log(`PASS ${TARGET} install contract intact${LIVE ? " (incl. live upstream)" : ""}`);
  process.exit(failed ? 1 : 0);
}
