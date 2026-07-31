#!/usr/bin/env node
// Verifies the Matt Pocock power-user-skills install contract in the setup
// prompt (docs/start/setup.md, Step 6's "Power-user skills" item). LOUP-19.
//
// The contract used to live in the onboarding skill's install phase.
// ADR-0001 §1/§7 moved every install into the one setup prompt and rewrote
// that skill as `orientation`, which installs nothing — so the checker follows
// the contract to its new home. Four rules were dropped with it,
// because the prompt genuinely does not state them and inventing them here
// would assert a contract nothing upholds:
//   zero-installed-case  — the prompt heals on "if any are missing", which
//                          covers all four without naming the case.
//   visible-summary      — the ✅/❌ block was Phase 2.5 formatting; the prompt
//                          asks for a per-skill status report instead (checked
//                          by the per-skill-report rule below).
//   honest-reporting     — "never invent a cause" lived in the deleted phase.
//                          The prompt's own show-the-real-output rule sits in
//                          Step 2, outside this step's slice.
//   non-blocking         — "continue to Phase 3 either way" named a phase that
//                          no longer exists.
// CORE-116 (the conformance-tooling redesign) made that call: all four stay
// dropped. Three are genuinely subsumed — the healing pass covers the
// zero-installed case, the per-skill report replaces the ✅/❌ block, and both
// named phases of a document that no longer has phases. The fourth,
// honest-reporting, is not lost either: "show me the real, unedited output,
// never hide it" is a whole-prompt property, and check-resilient-install's
// real-output rule enforces it over the entire pasted body — a narrower copy
// inside this slice would assert the same thing twice and rot separately.
//
// One SEMANTIC change came with the move, and it is deliberate rather than
// incidental: the old first-run-setup phase said a power-user-skills miss was
// "NOT a setup blocker" and carried on. In the setup prompt these four skills
// are inside Step 9's verify gate ("fix it with me now, re-check, and only then
// continue"), so a miss is now hard-blocking. That is the right way round — the
// non-blocking rule existed because the old phase ran AFTER the user was
// already working, whereas the prompt is still installing and can heal it on
// the spot — but it is a behaviour change, not just a regex refresh, and the
// dropped `non-blocking` rule below is downstream of it.
//
// History: upstream renamed `diagnose` → `diagnosing-bugs` and the hardcoded
// `-s diagnose` selector silently stripped skills from attendees, with a
// failure branch that hand-waved it as "probably a network hiccup". This
// checker is the regression backstop for the fixed contract: current names,
// on-disk verification, a self-heal (list → resolve renames → retry) pass,
// and a per-skill report.
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

const TARGET = "docs/start/setup.md";
const UPSTREAM_REPO = "mattpocock/skills";

// The four skills the workshop installs, under their CURRENT upstream names.
// When upstream renames one, update it here AND in the prompt step body — the
// --live check is what tells you a rename happened.
export const EXPECTED_SKILLS = ["grill-me", "handoff", "diagnosing-bugs", "teach"];

// Names that no longer exist upstream and must never reappear in the step.
export const STALE_NAMES = ["diagnose"];

// Anchors around the setup prompt's power-user-skills item. Slicing matters:
// the rest of the prompt installs other things, and must not be able to
// satisfy a rule this step dropped.
//
// The end anchor was `### Step 7` — the end of the whole of Step 6, not the end
// of this item. That was only correct by accident: the power-user-skills item
// happens to be the last one in Step 6 today. Add a fifth item and the slice
// silently widens, and unrelated prompt text can satisfy self-heal-listing,
// rename-resolution, recheck-after-heal and verify-paths — which is precisely
// the invariant this comment claims. So the slice now ends at whichever comes
// FIRST: the next numbered item in the step, or the next heading (`### Step 7`
// being the one that closes it today).
const STEP_START = "4. **Power-user skills**";
const NEXT_ITEM = /\n\d+\.\s+\*\*/;
const NEXT_HEADING = /\n#{2,4}\s/;

export function extractStepBody(text) {
  const start = text.indexOf(STEP_START);
  if (start === -1) {
    return { error: `power-user-skills start anchor not found (${STEP_START})` };
  }
  const after = text.slice(start + STEP_START.length);
  const ends = [NEXT_ITEM, NEXT_HEADING]
    .map((re) => after.search(re))
    .filter((i) => i !== -1);
  if (ends.length === 0) {
    return { error: "power-user-skills end anchor not found (no following numbered item or heading)" };
  }
  return { body: text.slice(start, start + STEP_START.length + Math.min(...ends)) };
}

// Each rule must hold in the sliced power-user-skills body.
export const RULES = [
  {
    id: "current-selectors",
    why: `install command selects every expected skill by its current name (${EXPECTED_SKILLS.join(", ")})`,
    test: (b) => EXPECTED_SKILLS.every((s) => new RegExp(`-s ${s}(?![\\w-])`).test(b)),
  },
  {
    // Accepts either one path per skill, or the brace-expanded single-line
    // form the setup prompt uses (~/.claude/skills/{a,b,c,d}/SKILL.md).
    id: "verify-paths",
    why: "every expected skill's ~/.claude/skills/<name>/SKILL.md path is checked on disk",
    test: (b) =>
      EXPECTED_SKILLS.every(
        (s) =>
          b.includes(`~/.claude/skills/${s}/SKILL.md`) ||
          new RegExp(`~/\\.claude/skills/\\{[^}]*\\b${s}\\b[^}]*\\}/SKILL\\.md`).test(b),
      ),
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
    id: "recheck-after-heal",
    why: "the healed install is re-verified on disk, never assumed to have worked",
    test: (b) => /re-?check/i.test(b),
  },
  {
    id: "per-skill-report",
    why: "the step ends by reporting status per skill, not one blanket outcome",
    test: (b) => /per-?skill/i.test(b) && /report|status/i.test(b),
  },
  {
    id: "no-handwave",
    why: 'no "network hiccup" hand-wave and no tell-a-facilitator escalation',
    test: (b) => !/network hiccup/i.test(b) && !/facilitator/i.test(b),
  },
];

/**
 * Evaluate the install contract against a power-user-skills body. Returns
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
