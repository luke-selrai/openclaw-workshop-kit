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
//   4. ONE-FIX-PER-ROUND   the recovery loop changes one thing at a time rather
//                          than shotgunning fixes at a failed download.
//   5. NO-RETRY-CAP        the loop states there is no limit on retries.
//   6. NO-ESCALATION       no human-escalation wording (notify / facilitator /
//                          Luke / Harvey / escalate) appears anywhere in the body.
//
// CORE-116 added the GitHub probe/clone surface. CORE-385 retired the Loup door
// behind it (ADR-0003): there is ONE live door now, and a refused probe means
// the kit is not open yet. The probe still fails in three ways, and none of them
// is ever a credential problem the attendee can fix by signing in somewhere:
//   7. SILENT-PROBE        a cheap `git ls-remote` with GIT_TERMINAL_PROMPT=0,
//                          so a closed repo fails fast instead of hanging on a
//                          credential prompt.
//   8. THREE-DOORS         success → clone; refused → wait for the room to open;
//                          timeout/network → retry the wifi.
//   9. NO-CREDENTIAL-ASK   a refused probe never turns into a password ask.
//  10. NOT-OPEN-YET        a refused probe is named for what it is: the kit is
//                          not open yet, it opens when the room opens, and the
//                          host says when. Never an access fault of the
//                          attendee's, never something they can fix by fetching
//                          a credential.
//  11. WAIT-THEN-RETRY     the refused door waits for the attendee's word and
//                          re-runs the same probe when they give it. This is
//                          what replaced the Loup re-mint loop (ADR-0003).
//  12. NETWORK-IS-WIFI     a network failure is named as the wifi and routed to
//                          an online check plus a re-probe. This is the one that
//                          matters on venue wifi: a dropped connection reads as
//                          "your access was revoked" to a naive installer, and
//                          the attendee ends up hunting for credentials that
//                          were never the problem.
//  13. ALWAYS-REFETCH      the kit is re-acquired fresh on every run, never
//                          updated in place.
//  14. CLONE-SAFETY        an existing kit-home folder is only deleted after it
//                          is confirmed to be a kit download — never on its name.
//
// Plus a FORBIDDEN set (must not appear at all): the retired Loup delivery
// surface and any place to sign in. Those are checked over the prompt with the
// permitted legacy-home mentions blanked out first, because MIGRATE and retirement
// still have to name the old Loup install folders they delete, and naming a
// folder in order to remove it is not a door.

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
//
// "wait for your host to say the room is open" is deliberately NOT escalation:
// nobody is being asked to fix anything for the attendee, and no message is sent
// to anyone. The room opening is a scheduled event, not a support request.
const ESCALATION_PATTERNS = [
  { id: "notify", re: /\bnotify\b/i },
  { id: "facilitator", re: /\bfacilitator\b/i },
  { id: "luke", re: /\bLuke\b/ },
  { id: "harvey", re: /\bHarvey\b/ },
  { id: "escalate", re: /\bescalat/i },
];

// The two mentions of the old world that survive on purpose (ADR-0003): the
// path of an old Loup install folder, and the label that says that is what it
// is. MIGRATE fingerprint reconstruction and the MIGRATE retirement step both
// have to find and remove those folders, and neither can do that without
// naming them.
//
// Only these two SPANS are carved out, not the whole line. Dropping the line
// would let a real violation hide on it ("delete the old kit folder once you
// have your token"); this way the path and its label disappear and anything
// else on the line still faces the FORBIDDEN scan.
const LEGACY_HOME_PATH = /(?:~|\$HOME|%USERPROFILE%)?[/\\]?\.loup[/\\][^\s`)]*/g;
const LEGACY_HOME_LABEL = /\(an old Loup install\)/gi;

/** The prompt with the permitted legacy-home mentions blanked out. */
function withoutLegacyHomeMentions(body) {
  return body.replace(LEGACY_HOME_PATH, "<legacy kit home>").replace(LEGACY_HOME_LABEL, "");
}

// Delivery surfaces and credential hunts the prompt must never contain, checked
// against the body with the legacy-home lines already stripped. Every one of
// these is something an attendee cannot do and must never be sent to do: there
// is no dashboard, no token, no install command to paste, and nowhere to sign
// in. The kit opens with the room or it does not open.
const FORBIDDEN_PATTERNS = [
  { id: "loup-delivery", re: /loup/i, why: "Loup is retired as a delivery channel (ADR-0003)" },
  { id: "dashboard", re: /\bdashboard\b/i, why: "there is no dashboard to send the attendee to" },
  { id: "token", re: /\btokens?\b/i, why: "the attendee never has, needs or is asked for a token" },
  { id: "install-command", re: /install command/i, why: "there is no install command to mint or paste" },
  {
    id: "sign-in-destination",
    // A URL offered on the same line as a sign-in. The prompt carries plenty of
    // URLs (github.com, nodejs.org, example.com); what it must never carry is a
    // place to log in.
    re: /^(?=.*https?:\/\/)(?=.*\b(sign[- ]?in|log[- ]?in|logged in)\b).*$/im,
    why: "a refused probe never sends the attendee somewhere to sign in",
  },
];

// An unqualified instruction to ask the attendee for a credential. Negated
// mentions ("never ask me for a password") are the contract, not a violation,
// so this is evaluated per line with the negation carved out.
const CREDENTIAL_ASK = /\bask(?:ing|s)?\s+(?:me|you|them|the user)\b[^\n]{0,60}\b(password|sign[- ]?in|credentials?|username|account)\b/i;
const NEGATED_ASK = /\b(never|not|no|don't|do not|without|rather than)\b[^\n]{0,40}\bask/i;

/** Forbidden-surface hits, as [{ id, why }]. */
function scanForbidden(body) {
  const stripped = withoutLegacyHomeMentions(body);
  const hits = FORBIDDEN_PATTERNS.filter((p) => p.re.test(stripped)).map((p) => ({ id: p.id, why: p.why }));
  for (const line of stripped.split(/\r?\n/)) {
    if (CREDENTIAL_ASK.test(line) && !NEGATED_ASK.test(line)) {
      hits.push({ id: "credential-ask", why: `asks the attendee for a credential: "${line.trim().slice(0, 80)}"` });
      break;
    }
  }
  return hits;
}

/** True when a single line of `body` matches every pattern given. */
function sameLine(body, ...patterns) {
  return body.split(/\r?\n/).some((line) => patterns.every((p) => p.test(line)));
}

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
    id: "one-fix-per-round",
    why: "the recovery loop changes one thing at a time (one targeted fix per round)",
    test: (b) => /one targeted fix per round/i.test(b),
  },
  {
    id: "no-retry-cap",
    why: "state there is no limit on retries",
    test: (b) => /\bno limit\b/i.test(b),
  },

  // ---- The one live door (CORE-116, retired to one door by ADR-0003) ------
  {
    id: "silent-probe",
    why: "probe the repo with `git ls-remote` and GIT_TERMINAL_PROMPT=0 so a closed repo fails fast instead of hanging on a credential prompt",
    // Same LINE, not merely same document: the clone command a few paragraphs
    // later also disables prompting, and a document-wide test would keep
    // passing while the probe itself — the one command that runs against a
    // possibly-private repo — was left free to hang on a credential prompt.
    test: (b) => sameLine(b, /GIT_TERMINAL_PROMPT/, /git ls-remote/),
  },
  {
    id: "three-doors",
    why: "the probe splits three ways: success → clone, refused → wait for the room to open, timeout → wifi retry",
    test: (b) =>
      /git clone --depth 1/.test(b) &&
      /not open yet/i.test(b) &&
      /(times? out|network problem|network error)/i.test(b),
  },
  {
    id: "no-credential-ask",
    why: "a refused probe never turns into a password ask",
    test: (b) => /(do not|don't|never)[\s\S]{0,60}password/i.test(b),
  },
  {
    id: "not-open-yet",
    why: "a refused probe is named plainly: the kit is not open yet, it opens when the room opens, and the host says when",
    test: (b) =>
      /(refused|authentication error|not found)/i.test(b) &&
      /not open yet/i.test(b) &&
      // Whitespace-tolerant: the prompt is hard-wrapped, so the sentence
      // straddles a line break.
      /opens?\s+when\s+the\s+room\s+opens/i.test(b) &&
      /\bhost\b/i.test(b),
  },
  {
    id: "wait-then-retry",
    why: "the refused door waits for the attendee's word, then re-runs the same probe when they say to try again",
    test: (b) =>
      /\bwait\b/i.test(b) &&
      /try again/i.test(b) &&
      /(run the same probe again|probe again)/i.test(b),
  },
  {
    id: "network-is-wifi",
    why: "a network failure is the wifi, not the kit, so check I am online and probe again",
    test: (b) =>
      /(times? out|network problem|network error)[\s\S]{0,300}\bwifi\b/i.test(b) &&
      /(times? out|network problem|network error)[\s\S]{0,400}(online|hotspot)/i.test(b),
  },
  {
    id: "always-refetch",
    why: "the kit is re-acquired fresh every run, never updated in place",
    test: (b) =>
      /(fresh copy|ALWAYS take a fresh)/i.test(b) &&
      /never\s+update-in-place/i.test(b),
  },
  {
    id: "clone-safety",
    why: "an existing kit-home folder is deleted only after it is confirmed to be a kit download, never on its name alone",
    // Anchored to its own sentence. The `|| /on its name alone/` fallback this
    // replaces subsumed the first branch and reduced the rule to a bare phrase
    // match, which any sentence containing the words would satisfy.
    test: (b) => /never delete a folder\b[^.]{0,60}\bon its name alone/i.test(b),
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

  const forbidden = scanForbidden(body);
  rules.push({
    id: "no-retired-delivery-surface",
    ok: forbidden.length === 0,
    why: "no Loup delivery surface, dashboard, token, install command or sign-in destination outside the legacy-home lines",
    detail: forbidden.length === 0
      ? "none present"
      : forbidden.map((h) => `${h.id} (${h.why})`).join("; "),
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

export {
  sameLine,
  evaluateResilience,
  extractBootstrapBody,
  extractPromptBody,
  scanForbidden,
  withoutLegacyHomeMentions,
  PRESENCE_RULES,
  ESCALATION_PATTERNS,
  FORBIDDEN_PATTERNS,
  BOOTSTRAP_COPIES,
};

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
