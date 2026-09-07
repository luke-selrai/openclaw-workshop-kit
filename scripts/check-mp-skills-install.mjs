#!/usr/bin/env node
// Verifies the Matt Pocock skills install contract in the setup prompt
// (docs/start/setup.md, Step 6's "Matt Pocock's skills" item). LOUP-19,
// widened by CORE-430 from four copied skills to the whole core set, installed
// as links (see docs/adr/0004-matt-pocock-core-set-installs-as-links.md).
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

// The skills the workshop installs, under their CURRENT upstream names: the
// whole core set, i.e. every skill under upstream's engineering/ and
// productivity/ buckets (CORE_BUCKETS below). in-progress/, misc/ and
// deprecated/ are deliberately NOT installed. When upstream renames, adds or
// removes a core skill, update it here AND in the prompt step body — the --live
// check is what tells you it happened (it asserts set equality both ways).
export const CORE_BUCKETS = ["engineering", "productivity"];
export const EXPECTED_SKILLS = [
  // productivity/
  "grill-me", "grilling", "handoff", "teach", "to-questionnaire", "wait-what", "writing-for-agents",
  // engineering/
  "ask-matt", "code-review", "codebase-design", "diagnosing-bugs", "domain-modeling", "grill-with-docs",
  "implement", "improve-codebase-architecture", "prototype", "research", "resolving-merge-conflicts",
  "setup-matt-pocock-skills", "tdd", "to-spec", "to-tickets", "triage", "wayfinder", "wizard",
];

// Names that no longer exist upstream and must never reappear in the step.
export const STALE_NAMES = ["diagnose"];

// Anchors around the setup prompt's Matt Pocock skills item. Slicing matters:
// the rest of the prompt installs other things, and must not be able to
// satisfy a rule this step dropped.
//
// The end anchor was `### Step 7` — the end of the whole of Step 6, not the end
// of this item. That was only correct by accident: the Matt Pocock skills item
// happens to be the last one in Step 6 today. Add a fifth item and the slice
// silently widens, and unrelated prompt text can satisfy self-heal-listing,
// rename-resolution, recheck-after-heal and verify-paths — which is precisely
// the invariant this comment claims. So the slice now ends at whichever comes
// FIRST: the next numbered item in the step, or the next heading (`### Step 7`
// being the one that closes it today).
const STEP_START = "4. **Matt Pocock's skills**";
const NEXT_ITEM = /\n\d+\.\s+\*\*/;
const NEXT_HEADING = /\n#{2,4}\s/;

export function extractStepBody(text) {
  const start = text.indexOf(STEP_START);
  if (start === -1) {
    return { error: `Matt Pocock skills start anchor not found (${STEP_START})` };
  }
  const after = text.slice(start + STEP_START.length);
  const ends = [NEXT_ITEM, NEXT_HEADING]
    .map((re) => after.search(re))
    .filter((i) => i !== -1);
  if (ends.length === 0) {
    return { error: "Matt Pocock skills end anchor not found (no following numbered item or heading)" };
  }
  return { body: text.slice(start, start + STEP_START.length + Math.min(...ends)) };
}

// Each rule must hold in the sliced Matt Pocock skills body.
export const RULES = [
  {
    id: "current-selectors",
    why: `install command selects every expected skill by its current name (${EXPECTED_SKILLS.join(", ")})`,
    test: (b) => EXPECTED_SKILLS.every((s) => new RegExp(`-s ${s}(?![\\w-])`).test(b)),
  },
  {
    // Accepts one path per skill, the brace-expanded single-line form
    // (~/.claude/skills/{a,b,c}/SKILL.md), or — now that the set is too long to
    // spell out twice — the placeholder form the prompt uses: the literal
    // `~/.claude/skills/<name>/SKILL.md` bound to "every skill named in the
    // command". The placeholder only counts when every expected name is also
    // present in the body (current-selectors guarantees that for a good step,
    // and a stale fixture fails it).
    id: "verify-paths",
    why: "every expected skill's ~/.claude/skills/<name>/SKILL.md path is checked on disk",
    test: (b) => {
      const placeholder =
        b.includes("~/.claude/skills/<name>/SKILL.md") &&
        /(every|each) skill named/i.test(b) &&
        EXPECTED_SKILLS.every((s) => new RegExp(`(^|[^\\w-])${s}(?![\\w-])`).test(b));
      return (
        placeholder ||
        EXPECTED_SKILLS.every(
          (s) =>
            b.includes(`~/.claude/skills/${s}/SKILL.md`) ||
            new RegExp(`~/\\.claude/skills/\\{[^}]*\\b${s}\\b[^}]*\\}/SKILL\\.md`).test(b),
        )
      );
    },
  },
  {
    // CORE-430: the set installs as links out of the skills CLI's shared store,
    // never as loose copies. --copy anywhere in the install command breaks that
    // silently (the install still "succeeds").
    id: "no-copy-flag",
    why: "the install command does not carry --copy (links, not loose copies)",
    // Tested on the command line itself: the prose around it is allowed (and
    // expected) to say "do NOT add --copy".
    test: (b) => {
      const cmd = b.match(/npx -y skills@latest add mattpocock\/skills[^\n]*-s [^\n]*/);
      return !!cmd && !/--copy/.test(cmd[0]);
    },
  },
  {
    // The CLI only uses the shared store + links when more than one agent is
    // named; a single `-a claude-code` install copies. Verified empirically
    // against skills@1.5.24 (CORE-430) — see ADR-0004.
    id: "two-agent-link-form",
    why: "the install command names both agents (-a claude-code -a codex), which is what makes the CLI link rather than copy",
    test: (b) => {
      const cmd = b.match(/npx -y skills@latest add mattpocock\/skills[^\n]*-s [^\n]*/);
      return !!cmd && /-a claude-code(?![\w-])/.test(cmd[0]) && /-a codex(?![\w-])/.test(cmd[0]);
    },
  },
  {
    // A link that leads nowhere passes a naive "folder exists" check. The
    // verify step has to open the SKILL.md through the link, and the report has
    // to say when the CLI fell back to copying.
    id: "link-verified",
    why: "verification treats a dangling link as missing and reports any skill that landed as a copy",
    // Whitespace-tolerant: the prompt is hard-wrapped.
    test: (b) => /link\s+that\s+(leads|goes|points)\s+nowhere|dangling|broken\s+link/i.test(b) && /plain\s+copy|as\s+a\s+copy/i.test(b),
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
 * List the live upstream repo's skills via the GitHub API (the git tree, one
 * request, no cloning). Returns the set of directory names that contain a
 * SKILL.md anywhere under skills/, and a per-bucket map (the first path segment
 * under skills/, e.g. "engineering") so callers can reason about the core set.
 */
export async function fetchLiveSkillTree(fetchImpl = fetch) {
  const res = await fetchImpl(
    `https://api.github.com/repos/${UPSTREAM_REPO}/git/trees/main?recursive=1`,
    { headers: { accept: "application/vnd.github+json", "user-agent": "claude-workshop-kit-ci" } },
  );
  if (!res.ok) throw new Error(`GitHub API ${res.status} listing ${UPSTREAM_REPO}`);
  const { tree } = await res.json();
  const names = new Set();
  const buckets = new Map();
  for (const entry of tree) {
    const parts = entry.path.split("/");
    if (parts[0] !== "skills" || parts.at(-1) !== "SKILL.md" || parts.length < 3) continue;
    const inner = parts.slice(1, -1); // the directories between skills/ and SKILL.md
    names.add(inner.at(-1));
    // Bucket membership is decided at exactly skills/<bucket>/<name>/SKILL.md.
    // A flat skills/<name>/SKILL.md files under "". A SKILL.md nested deeper
    // inside a skill folder (references/, templates/) is that skill's own
    // business and never creates a core entry.
    const key = inner.length === 1 ? "" : inner.length === 2 ? inner[0] : null;
    if (key === null) continue;
    if (!buckets.has(key)) buckets.set(key, new Set());
    buckets.get(key).add(inner.at(-1));
  }
  return { names, buckets };
}

/** Back-compat: the flat set of every skill name under skills/. */
export async function fetchLiveSkillNames(fetchImpl = fetch) {
  return (await fetchLiveSkillTree(fetchImpl)).names;
}

/**
 * The live core set: every skill under CORE_BUCKETS. This is what
 * EXPECTED_SKILLS must equal exactly — a name missing here was renamed or
 * removed upstream; a name here but not in EXPECTED_SKILLS was added upstream
 * and the prompt is silently under-installing.
 */
export async function fetchLiveCoreSkillNames(fetchImpl = fetch) {
  const { buckets } = await fetchLiveSkillTree(fetchImpl);
  const core = new Set();
  for (const b of CORE_BUCKETS) for (const n of buckets.get(b) ?? []) core.add(n);
  return core;
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
      const live = await fetchLiveCoreSkillNames();
      for (const s of EXPECTED_SKILLS) {
        note(
          live.has(s),
          `live upstream [${s}]`,
          live.has(s)
            ? "exists in a core bucket"
            : `not found under ${CORE_BUCKETS.join("/")} in ${UPSTREAM_REPO} — upstream renamed, removed or demoted it; re-resolve and update EXPECTED_SKILLS + the prompt step`,
        );
      }
      const expected = new Set(EXPECTED_SKILLS);
      const added = [...live].filter((s) => !expected.has(s)).sort();
      note(
        added.length === 0,
        "live upstream [core set complete]",
        added.length === 0
          ? "EXPECTED_SKILLS covers every core skill"
          : `upstream added to the core set: ${added.join(", ")} — add each to EXPECTED_SKILLS and the prompt's install command`,
      );
    } catch (e) {
      note(false, "live upstream listing", String(e));
    }
  }

  if (!failed && !VERBOSE) console.log(`PASS ${TARGET} install contract intact${LIVE ? " (incl. live upstream)" : ""}`);
  process.exit(failed ? 1 : 0);
}
