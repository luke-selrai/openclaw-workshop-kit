#!/usr/bin/env node
// Verifies the install-narration + preflight contract for slow venue wifi (LOUP-20).
// Pure Node, no dependencies — run with `node scripts/check-install-narration.mjs`.
//
// The contract kills the "Claude silently hangs for minutes while something
// downloads over venue wifi" experience. It has two layers:
//   Layer 1 — deep treatment in the setup prompt body (both in-repo copies) and
//             skills/first-run-setup/SKILL.md: a preflight (Node + network sane)
//             at the very start, and a before/visible/after narration pattern
//             on every download point.
//   Layer 2 — one tight always-on rule in my-assistant/CLAUDE.md covering any
//             session where neither bootstrap nor first-run is loaded.
//
// Modes:
//   (default) / --check   read-only; exit 1 on any failure (used by CI)
//   --verbose             also print every passing check
//
// Rules per surface:
//   bootstrap-body   preflight-network, looks-frozen, narrate-before,
//                    generous-timeout, fails-loudly, confirm-after
//   bootstrap-prework  the "have Node installed before you arrive" line
//                      (outside the pasted prompt, whole-file scan)
//   first-run        preflight-network, looks-frozen, narrate-before,
//                    generous-timeout, fails-loudly, browser-download-warning
//   kit-rule         looks-frozen, generous-timeout, fails-loudly,
//                    confirm-after (the 3–4 line CLAUDE.md rule)

import { readFileSync } from "node:fs";
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
    test: (b) => /first (browser launch|page load|navigate)/i.test(b) && /downloads? the browser itself/i.test(b),
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
    rules: ["preflight-network", "looks-frozen", "narrate-before", "generous-timeout", "fails-loudly", "confirm-after"],
  },
  {
    id: "bootstrap-prework",
    files: ["docs/start/setup.md"],
    extract: (text) => ({ body: text }),
    rules: ["node-prework"],
  },
  {
    id: "first-run",
    files: ["skills/first-run-setup/SKILL.md"],
    extract: (text) => ({ body: text }),
    rules: ["preflight-network", "looks-frozen", "narrate-before", "generous-timeout", "fails-loudly", "browser-download-warning"],
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
