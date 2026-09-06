#!/usr/bin/env node
// Verifies the install-narration + preflight contract for slow venue wifi (LOUP-20).
// Pure Node, no dependencies — run with `node scripts/check-install-narration.mjs`.
//
// The contract kills the "Claude silently hangs for minutes while something
// downloads over venue wifi" experience. It has two layers:
//   Layer 1 — deep treatment in the setup prompt body: a preflight (Node +
//             network sane) at the very start, and a before/visible/after
//             narration pattern on every download point.
//   Layer 2 — one tight always-on rule in my-assistant/CLAUDE.md covering any
//             session where the setup prompt is not loaded.
//
// ADR-0001 §7 removed the second Layer-1 surface: every download the kit
// performs now happens in the setup prompt, and the skill that used to install
// things became `orientation`, which installs nothing. Its
// one narration rule that had no equivalent elsewhere — the first-page-load
// browser-download warning — moved onto the bootstrap-body surface, where the
// setup prompt's Step 8 carries it. Wider redesign: CORE-116.
//
// Modes:
//   (default) / --check   read-only; exit 1 on any failure (used by CI)
//   --verbose             also print every passing check
//
// Rules per surface:
//   bootstrap-body   preflight-network, looks-frozen, narrate-before,
//                    generous-timeout, fails-loudly, confirm-after,
//                    browser-download-warning
//   bootstrap-prework  the "have Node installed before you arrive" line
//                      (outside the pasted prompt, whole-file scan)
//   kit-rule         looks-frozen, generous-timeout, fails-loudly,
//                    confirm-after (the 3–4 line CLAUDE.md rule)

import { readFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { extractPromptBody } from "./check-resilient-install.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Shared rule primitives — one regex per contract phrase, reused across surfaces.
const R = {
  "preflight-network": {
    why: "network-sanity preflight against registry.npmjs.org with a hard timeout",
    test: (b) => /preflight/i.test(b) && /registry\.npmjs\.org/.test(b),
  },
  "looks-frozen": {
    why: 'the key sentence: it may "look frozen" without being frozen',
    test: (b) => /look(s|ing)? (frozen|stuck)/i.test(b),
  },
  "narrate-before": {
    why: "narration happens BEFORE the command runs (Claude cannot talk mid-command)",
    test: (b) => /\bbefore\b/i.test(b) && /cannot (talk|speak)|can't speak|can not (talk|speak)/i.test(b),
  },
  "generous-timeout": {
    why: "slow commands get a generous timeout",
    test: (b) => /generous timeout/i.test(b),
  },
  "fails-loudly": {
    why: "a dead download fails loudly instead of hanging forever",
    test: (b) => /fails? loudly/i.test(b) && /hang/i.test(b),
  },
  "confirm-after": {
    why: "after the command: confirm success or state plainly what failed",
    test: (b) => /confirm/i.test(b) && /what failed/i.test(b),
  },
  "node-prework": {
    why: '"have Node.js installed before you arrive" pre-workshop guidance',
    test: (b) => /Node\.?js/i.test(b) && /before you arrive/i.test(b),
  },
  "browser-download-warning": {
    why: "warn that the first Playwright launch downloads the browser itself",
    // Whitespace-tolerant: the setup prompt is hard-wrapped, so either phrase
    // can straddle a line break.
    test: (b) =>
      /first\s+(browser\s+launch|page\s+load|navigate)/i.test(b) &&
      /downloads?\s+the\s+browser\s+itself/i.test(b),
  },
  // ---- CORE-116: rules for the universal setup document -------------------
  // The two-prompt bootstrap narrated its two or three download points by hand.
  // The universal prompt has more of them (Node, git, the probe, the clone, the
  // CLI, the plugin, Playwright, the power-user skills),
  // and enumerating each one in the checker would rot on the first reorder. So
  // the contract moved up a level: ONE blanket rule at the top of the prompt
  // that binds every slow command in the document.
  "every-download-warned": {
    why: "one blanket rule covering EVERY download in the prompt, spoken before the command runs",
    // Both halves must sit in the SAME paragraph: an unanchored /\bbefore\b/
    // over the whole prompt is satisfied by any of the dozens of other uses of
    // the word, so the rule would survive the blanket rule losing its "say it
    // BEFORE you start" clause.
    test: (b) => b.split(/\n\s*\n/).some((p) => /every download/i.test(p) && /\bbefore\b/i.test(p)),
  },
  "mode-announcement": {
    why: "the detected mode (fresh / update / migrate) is announced in one line of plain English, before anything changes",
    test: (b) =>
      /in plain (words|English)/i.test(b) &&
      /fresh setup/i.test(b) &&
      /updating/i.test(b),
  },
};

// Each surface: which files it reads, how to get the checked text, which rules apply.
const SURFACES = [
  // ADR-0001 collapsed bootstrap.md + full-setup.md into one universal setup
  // document, so both surfaces now read the same single file. bootstrap-body
  // still checks only the PASTED PROMPT, sliced out by heading marker, so the
  // attendee prose around it cannot satisfy a rule the prompt dropped;
  // bootstrap-prework deliberately reads the whole file, because the
  // "install Node before you arrive" line lives outside the prompt.
  // Wider conformance redesign: CORE-116.
  {
    id: "bootstrap-body",
    files: ["docs/start/setup.md"],
    extract: (text) => extractPromptBody(text),
    rules: [
      "preflight-network",
      "looks-frozen",
      "narrate-before",
      "generous-timeout",
      "fails-loudly",
      "confirm-after",
      "browser-download-warning",
      // CORE-116: the universal document also owns the two narration points the
      // two-prompt era spread across bootstrap and first-run-setup — the blanket
      // every-download rule and the plain-English mode announcement.
      "every-download-warned",
      "mode-announcement",
    ],
  },
  {
    id: "bootstrap-prework",
    files: ["docs/start/setup.md"],
    extract: (text) => ({ body: text }),
    rules: ["node-prework"],
  },
  {
    id: "kit-rule",
    files: ["my-assistant/CLAUDE.md"],
    extract: (text) => ({ body: text }),
    rules: ["looks-frozen", "generous-timeout", "fails-loudly", "confirm-after"],
  },
];

/**
 * Evaluate one surface's narration rules against a body of text.
 * Returns { pass, rules: [{ id, ok, why, detail }] } — same shape as
 * check-resilient-install's evaluateResilience, so tests share the pattern.
 */
function evaluateNarration(surfaceId, body) {
  const surface = SURFACES.find((s) => s.id === surfaceId);
  if (!surface) throw new Error(`unknown surface: ${surfaceId}`);
  const rules = surface.rules.map((id) => {
    const ok = R[id].test(body);
    return { id, ok, why: R[id].why, detail: ok ? "present" : `missing: ${R[id].why}` };
  });
  return { pass: rules.every((r) => r.ok), rules };
}

export { evaluateNarration, SURFACES, R };

// ---- CLI ------------------------------------------------------------------
if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  const VERBOSE = process.argv.includes("--verbose");
  let failed = false;

  const note = (ok, label, detail) => {
    if (!ok) failed = true;
    if (!ok || VERBOSE) {
      console[ok ? "log" : "error"](`${ok ? "PASS" : "FAIL"} ${label}${detail ? ` — ${detail}` : ""}`);
    }
  };

  for (const surface of SURFACES) {
    for (const rel of surface.files) {
      let text;
      try {
        text = readFileSync(join(ROOT, rel), "utf8");
      } catch (e) {
        note(false, `${rel} read`, e.message);
        continue;
      }
      const { body, error } = surface.extract(text);
      if (error) {
        note(false, `${rel} anchors`, error);
        continue;
      }
      const { rules } = evaluateNarration(surface.id, body);
      for (const r of rules) note(r.ok, `${rel} [${surface.id}/${r.id}]`, r.detail);
    }
  }

  if (!failed) console.log("\n✅ check-install-narration: venue-wifi narration contract intact in all surfaces");
  process.exit(failed ? 1 : 0);
}
