# ADR-0002 — Vendored reference packs ride cold inside a router skill

- **Status:** Accepted, 2026-09-03
- **Deciders:** Harvey Shaw, via the wayfinder map [CORE-362](https://linear.app/selr-ai/issue/CORE-362), ticket [Bring in Google's skill pack (CORE-384)](https://linear.app/selr-ai/issue/CORE-384)
- **Scope:** how a large third-party skill pack is carried in this kit without its descriptions entering every attendee session

## Context

Google publishes 131 official Agent Skills across two Apache-2.0 repos (`google/skills`: Google Ads, Google Analytics, Google Cloud, developer tooling; `google-gemini/gemini-skills`: the Gemini API). They are good, Luke had already vendored them into the internal kit behind a one-page router, and the 2026-09-01 prep meeting asked for them in this kit.

Three facts of this kit shape where they can go:

1. **Every top-level `skills/<name>/` folder is installed** into `~/.claude/skills/` by the setup prompt, and a skill's `name` + `description` are always-on context. The listing is already 206 skills; `skills/CLAUDE.md` budgets it at roughly 1% of the context window.
2. **The audit only reads top-level skills.** `scripts/audit-skills.mjs` enumerates `skills/*/SKILL.md` (one level), so anything deeper is neither counted nor held to the description rules. The vendored-skill exemption in `skills-lock.json` exists for *top-level* upstream skills that the audit does scan.
3. **Claude Code only discovers `~/.claude/skills/<name>/SKILL.md`** (one level; verified against the Claude Code skills docs, 2026-09-03). The "nested skills" feature is about `.claude/skills/` folders in project subdirectories, not deeper folders under a skill.

So a `SKILL.md` two levels down inside a skill folder is, to both the kit and Claude Code, a supporting file: installed with its skill, invisible to discovery, zero context until read.

## Decision

- **One hot, first-party router skill** at `skills/google-stack/SKILL.md`: a one-page intent → path map with the guardrails (spend, customer-data upload, long-lived keys). It is Selr-authored, so it sits under every description rule like any other kit skill.
- **The pack rides cold inside it** at `skills/google-stack/pack/{ads,analytics,cloud,developers,gemini}/`, upstream trees verbatim, with `LICENSE`, `PROVENANCE.md` (pinned commits) and `update.sh` (clean re-pull). Nothing under `pack/` is ever edited; a fix goes upstream or into the router.
- **The pack is not in `skills-lock.json`.** The lock's job is to exempt top-level vendored skills from the description audit; the audit never reads the pack, so an entry would exempt nothing. Provenance is pinned in `pack/PROVENANCE.md` instead.
- **The pack is read by relative path**, never copied up into `~/.claude/skills/` and never installed via `npx skills add` or the upstream plugin marketplace. The router says so.
- **The Google Workspace CLI's own 95 `gws-*` skills are deliberately not vendored.** Claude's built-in Gmail, Calendar and Drive connectors are the default route (CORE-367, CORE-395); the `gws` route survives for the gaps, and the CLI generates its skills locally (`gws generate-skills`), version-matched to the installed binary, which a vendored snapshot would drift from. `google-workspace-connector` carries that step.

## Consequences

- The skill count rises by exactly one. The attendee's listing gains one description, not 131.
- Each install copies about 5.6 MB more into `~/.claude/skills/google-stack/`. The setup's per-skill fingerprint covers `SKILL.md` only, so a pack update arrives as an in-place overwrite of kit files, never a wipe.
- The kit is now the canonical home of the pack. The internal kit's copy (`selrai-internal-kit/.claude/skills-cold/google-skills/`) should become a pointer to this one, per the no-copy rule in `CONTRIBUTING.md` §5; that is a follow-up on the internal kit, not this repo.
- The same shape is available to any future reference pack that is worth carrying but not worth 100 descriptions of always-on context: one router, one `pack/`, one `PROVENANCE.md`.

## Alternatives rejected

- **131 top-level skills.** Correct by the letter of the install model, wrong by its budget: the listing would grow by more than half, mostly Kubernetes and Vertex material a business owner never asks for, and the audit would need 131 lock entries to stay green.
- **Pack at the kit-home root, outside `skills/`.** Keeps `~/.claude/skills/` small, but every read would need the kit-home path resolved from the manifest, and the kit home differs per install door (ADR-0001). Inside the skill folder the path is always relative to the file being read.
- **Point at Google's live catalogue only** (`developers/finding-google-skills` fetches `index.json` from GitHub on demand). No disk footprint, but no offline use, no pinned version, and it follows whatever the fetch returns. Kept inside the pack as the way to check for newer skills, not as the route.
