# CLAUDE.md - claude-workshop-kit

Guidance for any Claude Code session working in this repo. Full conventions are in `CONTRIBUTING.md`; this file is the short, must-not-miss rule.

## Before you commit: regenerate the count markers

This kit keeps skill-count markers (`<!-- skills-audit:total -->N<!-- /skills-audit:total -->` and friends) in sync across its discovery-surface docs. They are generated from the on-disk `skills/` tree, not hand-edited.

If you change anything under `skills/**`, `docs/**`, `visuals/**`, `README.md`, or `skills/SKILLS-LIST.md`, run this before you commit and include the regenerated files in the same commit:

```
node scripts/audit-skills.mjs --write
```

Why it matters: the PR check runs `node scripts/audit-skills.mjs --check` and fails the build if the markers drift. `main` auto-fixes drift on merge, but pull requests do not, so regenerate locally first. Forgetting this step is the single most common cause of a red `audit-skills` check.

You can verify your tree is clean at any time with `node scripts/audit-skills.mjs --check` (read-only, exits non-zero on drift).

Note: the same check also enforces anti-pattern content rules over every `SKILL.md` (a content check `--write` does NOT auto-fix). If `--check` fails on a content rule rather than marker drift, read its output and fix the flagged `SKILL.md` by hand.

## Agent skills

### Issue tracker

Issues live in Linear, under the Core Builds team — not GitHub Issues, even though this repo is hosted on GitHub. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five canonical labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) — already present on the Core Builds Linear team with matching names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Everything else

See `CONTRIBUTING.md` for the rest: the no-copy skill rule, right-sized tooling, plain-English user-facing text, and the repo structure.
