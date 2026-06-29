# scripts/

Repo maintenance scripts. Plain Node, no dependencies — run with `node scripts/<name>.mjs`.

## audit-skills.mjs

Keeps the hand-maintained skill counts and tier breakdowns in sync with the on-disk truth across the discovery-surface docs. Tracked in [#115](https://github.com/selrai-company/claude-workshop-kit/issues/115).

**Usage:**

```bash
# Verify all marker-bracketed counts match the disk (used by CI)
node scripts/audit-skills.mjs --check

# Rewrite any drifted counts in place (run before committing)
node scripts/audit-skills.mjs --write

# Add the alphabetised connector list to stdout
node scripts/audit-skills.mjs --check --verbose
```

**Source of truth:**

- **Total skills** — count of `skills/*/SKILL.md` files
- **Connectors** — `skills/*-connector/` directories
- **CORE / ADVANCED / DEV-ONLY** — tier column in `skills/SKILLS-LIST.md`

**Marker shapes** (case-sensitive, inline):

```
<!-- skills-audit:total -->105<!-- /skills-audit:total -->
<!-- skills-audit:core -->22<!-- /skills-audit:core -->
<!-- skills-audit:advanced -->56<!-- /skills-audit:advanced -->
<!-- skills-audit:dev-only -->8<!-- /skills-audit:dev-only -->
<!-- skills-audit:connectors-count -->16<!-- /skills-audit:connectors-count -->
```

To add a new claim that should stay in sync, wrap the number in the appropriate marker pair anywhere in any file in the `TARGET_FILES` list at the top of the script.

**Soft warnings (don't fail CI):**

- Skills on disk but not classified in `SKILLS-LIST.md`
- Skills in `SKILLS-LIST.md` but missing from disk

These are content-decision drift — the script reports them so a human can classify, but it doesn't block PRs that didn't touch classification.

**Hard failures (fail CI):**

- Any marker-bracketed number doesn't match the disk-true value

**CI wiring:** `.github/workflows/audit-skills.yml` runs `--check` on every PR that touches `skills/`, `docs/`, `visuals/`, or any of the count-bearing top-level docs.

## check-snapshot-shape.mjs

Asserts the kit stays under Loup's snapshot caps, so re-snapshotting the private repo never breaks an attendee's install live. Loup ships the kit as a verbatim repo snapshot; this is the kit's own size invariant (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385), slice [#389](https://github.com/selrai-company/claude-workshop-kit/issues/389)).

**Usage:**

```bash
# Human report, exit 1 if any cap is breached (used by the workshop-preflight harness)
node scripts/check-snapshot-shape.mjs

# Machine-readable report
node scripts/check-snapshot-shape.mjs --json
```

Measures the committed tree at `HEAD` (what Loup actually publishes) and gates on:

- **File count** < 2000
- **Archive bytes** (gzipped tar, proxy for Loup's archive cap) < 45 MB
- **Unpacked bytes** < 80 MB
- The post-unpack **verify-gate paths** the bootstrap checks — `my-assistant/CLAUDE.md` and `skills/` — present at the repo root

Caps are exclusive (a value AT the cap fails); it WARNs at 90% so there's early signal before a cap is hit. Exit codes: `0` within caps, `1` a cap breached, `2` could not read git.

**Harness wiring:** the `workshop-preflight` skill runs this as a Phase 1 gating check during the pre-workshop dry run.

## verify-conform.mjs

Asserts the Loup-deliverable invariants (PRD [#385](https://github.com/selrai-company/claude-workshop-kit/issues/385) / slice [#386](https://github.com/selrai-company/claude-workshop-kit/issues/386)). The kit home is `~/.loup/selr-ai/workshop-kit`.

**Usage:**

```bash
node scripts/verify-conform.mjs            # exit 1 on any hard failure (used by CI)
node scripts/verify-conform.mjs --verbose  # also print every passing check
```

**Hard failures (fail CI):**

- **path-conform** — any stale kit-home reference survives (`~/workshop-kit`, `$HOME/workshop-kit`, `%USERPROFILE%\workshop-kit`, `C:\Users\…\workshop-kit`, or the old `~/claude-workshop-kit/whatsapp` fallback).
- **bootstrap-consistency** — the bootstrap prompt body is not byte-identical between `docs/start/bootstrap.md` and `docs/start/full-setup.md` (taken between the start/end anchors).
- **install-method** — the bootstrap doesn't install via `npx @louphq/install`, or still `git clone`s the kit.
- **verify-gate-paths** — `my-assistant/CLAUDE.md` or `skills/` is missing at the repo root.

**Informational (never fails):** snapshot file count vs Loup's `< 2000` cap.

## Tests

Plain Node, no framework — each prints `PASS`/`FAIL` and exits non-zero on any failure.

```bash
node scripts/test-anti-patterns.mjs     # regression for audit-skills anti-pattern rules
node scripts/test-snapshot-shape.mjs    # cap-boundary + real-repo checks for the snapshot invariant
node scripts/test-verify-conform.mjs    # stale-ref + bootstrap-consistency rules for verify-conform
```

`test-verify-conform.mjs` reads `scripts/__fixtures__/conform-stale.md` (allowlisted in `verify-conform.mjs`) and asserts each stale-ref rule fires on the expected line.
