#!/usr/bin/env node
// Verifies the resilient-install invariants for the bootstrap (PRD #385, slice #388).
// Pure Node, no dependencies — run with `node scripts/check-resilient-install.mjs`.
//
// Slice 1 (#386) gave the bootstrap a hard-stop verify-gate. This slice hardens
// the FAILURE RECOVERY so a failed install resolves between the attendee and
// Claude — diagnose → targeted fix → retry → repeat — with no human in the loop.
// This checker is the cheap regression backstop for that contract: it asserts the
// setup prompt still carries every resilience property.
//
// ADR-0001 collapsed the two-document bootstrap (docs/start/bootstrap.md +
// docs/start/full-setup.md) into one universal setup document, so the "both
// copies must agree" premise is gone and the file list below is a single file.
// There is no second copy to diff against, which is exactly why the
// byte-identity checker retired. The pasted-prompt body is still sliced out of
// the document rather than scanned whole (see extractPromptBody), so the
// attendee prose wrapped around it cannot satisfy a rule the prompt itself
// dropped. Anchor-based extraction stays exported for the bad fixtures, which
// still carry the old anchors.
// The wider conformance redesign is CORE-116.
//
// Modes:
//   (default) / --check   read-only; exit 1 on any failure (used by preflight/CI)
//   --verbose             also print every passing check
//
// Failures (exit 1) — checked against each copy's bootstrap body:
//   1. HARD-STOP           on a failed verify-gate, the bootstrap stops and does
//                          not cascade into the later steps.
//   2. REAL-OUTPUT         the real, unedited command output is shown, not swallowed.
//   3. PARTIAL-REPORT      a half-finished download (folder present but a checked
//                          path missing) is reported, not silently treated as OK.
//   4. REJECTED-DIAGNOSIS  a refused install is named as the common cause, with
//                          both causes — a stale command and a grant not yet active.
//   5. REMINT-FIX          the primary fix is re-mint guidance via "Get install
//                          command", and the attendee retries.
//   6. NO-RETRY-CAP        the loop states there is no limit on retries.
//   7. NO-ESCALATION       no human-escalation wording (notify / facilitator /
//                          Luke / Harvey / escalate) appears anywhere in the body.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Legacy anchors — the two-copy bootstrap era. Kept only because the bad
// fixtures still carry them and prove each detector fires.
const START_ANCHOR = "I am setting up my Claude Code AI Business Assistant with Selr AI.";
const END_ANCHOR = "Talk to me like I am not technical. Plain English, one step at a time.";

// The single setup document's pasted-prompt body: everything between the
// "## The prompt" heading and the first heading after it. Slicing matters — the
// document also carries attendee-facing prose (intro, pre-workshop note,
// troubleshooting) that must NOT be able to satisfy a rule the prompt itself
// dropped. A missing marker is a hard failure, never a silent whole-file scan.
const PROMPT_START_MARKER = "## The prompt";
const PROMPT_END_MARKER = "## Before workshop day";

function extractPromptBody(text) {
  const lines = text.split(/\r?\n/);
  const start = lines.indexOf(PROMPT_START_MARKER);
  const end = lines.indexOf(PROMPT_END_MARKER);
  if (start === -1 || end === -1 || end < start) {
    return { error: `prompt markers not found (start=${start}, end=${end})` };
  }
  return { body: lines.slice(start + 1, end).join("\n") };
}

// The setup surface that must carry the resilient-install contract.
const BOOTSTRAP_COPIES = ["docs/start/setup.md"];

// Human-escalation wording the bootstrap must never contain. Slice #388: the
// attendee and Claude resolve any install problem between themselves.
const ESCALATION_PATTERNS = [
  { id: "notify", re: /\bnotify\b/i },
  { id: "facilitator", re: /\bfacilitator\b/i },
  { id: "luke", re: /\bLuke\b/ },
  { id: "harvey", re: /\bHarvey\b/ },
  { id: "escalate", re: /\bescalat/i },
];

// Each "present" rule must match the body; the escalation rule must NOT match.
const PRESENCE_RULES = [
  {
    id: "hard-stop",
    why: "stop and do not cascade into the later steps on a failed verify-gate",
    test: (b) => /\bSTOP here\b/.test(b) && /\bDo not run any of steps 3\b/.test(b),
  },
  {
    id: "real-output",
    why: "show the real, unedited command output (never swallow it)",
    test: (b) => /\breal\b/i.test(b) && /\b(unedited|do not hide|don't hide|never hide|not hide)\b/i.test(b),
  },
  {
    id: "partial-report",
    why: "report a half-finished download (folder present but a checked path missing)",
    test: (b) => /\bpartial\b/i.test(b) && /\bmissing\b/i.test(b),
  },
  {
    id: "rejected-diagnosis",
    why: "name a refused install, plus both its causes — a stale command and a grant not yet active",
    test: (b) =>
      /\b(refused|rejected|not accepted)\b/i.test(b) &&
      /\bstale\b/i.test(b) &&
      /switched on|not yet active|grant/i.test(b),
  },
  {
    id: "remint-fix",
    why: "primary fix is re-minting via \"Get install command\" and retrying",
    test: (b) => /"Get install command"/.test(b) && /\bmint\b/i.test(b),
  },
  {
    id: "no-retry-cap",
    why: "state there is no limit on retries",
    test: (b) => /\bno limit\b/i.test(b),
  },
];

/**
 * Evaluate the resilient-install contract against a single bootstrap body.
 * Returns { pass, rules: [{ id, ok, why, detail }] } so callers (CLI + tests)
 * share one source of truth rather than mirroring regexes.
 */
function evaluateResilience(body) {
  const rules = PRESENCE_RULES.map((r) => ({
    id: r.id,
    ok: r.test(body),
    why: r.why,
    detail: r.test(body) ? "present" : `missing: ${r.why}`,
  }));

  const escalationHits = ESCALATION_PATTERNS.filter((p) => p.re.test(body)).map((p) => p.id);
  rules.push({
    id: "no-escalation",
    ok: escalationHits.length === 0,
    why: "no human-escalation wording (notify / facilitator / Luke / Harvey / escalate)",
    detail: escalationHits.length === 0 ? "none present" : `found: ${escalationHits.join(", ")}`,
  });

  return { pass: rules.every((r) => r.ok), rules };
}

function extractBootstrapBody(text) {
  const lines = text.split(/\r?\n/);
  const start = lines.indexOf(START_ANCHOR);
  const end = lines.indexOf(END_ANCHOR);
  if (start === -1 || end === -1 || end < start) {
    return { error: `anchors not found (start=${start}, end=${end})` };
  }
  return { body: lines.slice(start, end + 1).join("\n") };
}

export { evaluateResilience, extractBootstrapBody, extractPromptBody, PRESENCE_RULES, ESCALATION_PATTERNS, BOOTSTRAP_COPIES };

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

  for (const rel of BOOTSTRAP_COPIES) {
    let text;
    try {
      text = readFileSync(join(ROOT, rel), "utf8");
    } catch (e) {
      note(false, `${rel} read`, e.message);
      continue;
    }
    const { body, error } = extractPromptBody(text);
    if (error) {
      note(false, `${rel} prompt markers`, error);
      continue;
    }
    const { rules } = evaluateResilience(body);
    for (const r of rules) note(r.ok, `${rel} [${r.id}]`, r.detail);
  }

  if (!failed) console.log("\n✅ check-resilient-install: setup recovery loop intact");
  process.exit(failed ? 1 : 0);
}
