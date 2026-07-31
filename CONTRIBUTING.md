# Contributing to the SelrAI workshop kits

This is the **canonical, author-facing convention guide** for all three SelrAI workshop kits:

- `claude-workshop-kit` - Phase 1 - the AI Business Assistant (**this repo**)
- `claude-workshop-kit-v2` - Phase 2 - automation: the installer chainer + 24/7 deployment router
- `claude-workshop-v3-building` - Phase 3 - app & website building

It lives in `claude-workshop-kit` because Phase 1 is the foundation every kit builds on - so anyone working on *any* kit already has this repo. The Phase 2 and Phase 3 repos each carry a short `CONTRIBUTING.md` that points here. **This file is the single source of truth for kit conventions; do not copy its contents into other repos.**

**Workshop attendees can ignore this file.** It is build guidance for whoever authors or maintains a kit - not setup instructions. It contains no secrets; it is simply not useful to a participant.

> The *why* behind the three-repo structure, the drift analysis, and the workshop's strategic decisions live in SelrAI's internal team wiki, not here. This file is the *how* - the conventions you follow when changing a kit.

## Why these conventions exist

The kits are three separate repos - for drift isolation and clean per-segment boundaries. Every workshop attendee gets all three; there is no per-phase gating. Separate repos drift. These conventions are how they stay coherent: non-text conventions are enforced by each kit's own check script; text conventions stay consistent by everyone reading this one file.

## 1. SKILL.md frontmatter schema

Every `skills/<name>/SKILL.md` MUST have YAML frontmatter:

```yaml
---
name: <kebab-case>          # REQUIRED. Must equal the parent directory name.
description: <string>       # REQUIRED. The trigger text - when should this skill fire.
                            #   Write it as "Use when…" + concrete trigger phrases.
allowed-tools: <csv>        # OPTIONAL. Comma-separated tool allowlist.
metadata:                   # OPTIONAL.
  category: <string>        #   Grouping for SKILLS-LIST.md.
  tags: [<string>, ...]
  pairs-with:               #   Cross-references to related skills.
    - skill: <name>
      reason: <string>
---
```

Rules:
- `name` is kebab-case and **must match the directory name** exactly.
- `description` is the only thing Claude sees when deciding whether to load the skill - it must contain concrete trigger phrases, not a vague summary.
- A skill is a directory: `skills/<name>/SKILL.md` plus optional supporting files (`references/`, `scripts/`, `templates/`).

## 2. Subagent-definition frontmatter schema

Phase 3 teammate roles are **subagent definitions**, not skills. They live in `agents/<name>.md` (single file, no directory) and are copied to `~/.claude/agents/` at install. Distinct schema:

```yaml
---
name: <kebab-case>          # REQUIRED.
description: <string>       # REQUIRED. When the lead should spawn this teammate.
tools: <csv>                # OPTIONAL. Tool allowlist for this teammate.
model: <opus|sonnet|haiku>  # OPTIONAL. Defaults to the lead's model.
---

<body = the system-prompt addition appended to the teammate's prompt>
```

- `skills` and `mcpServers` frontmatter fields are **not** honoured when a subagent definition runs as an Agent Teams teammate - teammates load skills/MCP from project + user settings. Do not put them in teammate definitions.
- The body is appended to (not replacing) the teammate's system prompt.

## 3. Participant-facing tone rules

These apply to anything an attendee reads - READMEs, `docs/`, the setup prompt, and the user-facing persona. They do NOT apply to author-facing docs such as this `CONTRIBUTING.md`.

- **Plain English.** Banned jargon in user-facing text: `MCP`, `npx`, `bash`, `JSON`, `OAuth`, `token`, `client_id`, `curl`, `API`, `endpoint`, `environment variable`, `CLI`, `redirect URI`, `callback`. If a technical thing must be named, name it plainly ("the connection key", "your account details").
- **Narrate at action boundaries.** Tell the attendee what is about to happen before it happens.
- **Never echo credentials** in narration, tool output, or logs.
- Phase 3 is more technical than Phase 1 (it is app-building) - some code vocabulary is unavoidable there - but setup/onboarding docs still target an attendee, not a developer.

## 4. Repo / doc structure

Each kit repo follows this shape (scaled to the kit - not every kit needs every folder):

```
<kit>/
├── README.md              ← participant-facing pitch + read order
├── CONTRIBUTING.md         ← canonical here (CWK); a pointer in other kits
├── CLAUDE.md              ← author guidance auto-loaded by Claude Code sessions
├── VERSION                ← semver, see §6
├── docs/
│   ├── install/           ← what to buy / install before the workshop
│   ├── start/             ← the single setup document (install / update / migrate)
│   ├── use/               ← first prompts, what it remembers
│   ├── skills/  (or agents/) ← catalogue of what the kit adds
│   └── extend/            ← optional advanced paths
├── skills/                ← SKILL.md folders (if the kit ships skills)
├── agents/                ← subagent definitions (if the kit ships teammate roles)
└── scripts/               ← preflight + the kit's right-sized check
```

## 5. Drift-prevention rules

- **Regenerate the count markers before you commit.** Any change under `skills/**`, `docs/**`, `visuals/**`, `README.md`, or `skills/SKILLS-LIST.md` can shift the skill-count markers the discovery docs carry. Run `node scripts/audit-skills.mjs --write` and commit the regenerated files before you push. The PR check runs `node scripts/audit-skills.mjs --check` and fails if you forget; `main` auto-fixes on merge, but PRs do not, so do it locally first.
- **No-copy skill rule.** A skill or subagent definition lives in **exactly one kit**. Never copy it into another kit. If two kits need it, it belongs in `claude-workshop-kit` (the foundation every attendee installs first) and the others reference it. The `voice-transcription` fork between CWK and `advanced-claude-workshop-kit` is the cautionary tale - it drifted *because it was copied*.
- **Right-sized tooling, never copied tooling.** Each kit gets a check sized to it. CWK's `audit-skills.mjs` (173 skills, 10 marker-tracked docs) is NOT copied into smaller kits - `claude-workshop-kit-v2` has its own engine test suite; Phase 3 gets a ~20-line `check-kit.mjs`. **Review checkpoint:** if you are about to copy a tooling script from another kit - stop. Right-size a new one instead.
- **Keep team-internal material out of kit repos.** Kit repos are handover artifacts shipped to attendees. Strategy, decision history, and operational runbooks live in the team wiki - not here. Author-facing *build conventions* (this `CONTRIBUTING.md`) are fine: they are guidance, not internal strategy.

## 6. Versioning

Every kit MUST have:
- A `VERSION` file at the repo root - semver (`MAJOR.MINOR.PATCH`).
- A git tag per release (`v1.2.0`).
- A GitHub release per tag.

Downstream kits declare a compatibility floor in their README ("Phase 3 v1 needs Phase 1 ≥ v2"). The progression flow reads the installed version from the attendee's **local** kit home (`<kit home>/VERSION`, where `<kit home>` is the path recorded in `~/.claude/selr-kit-manifest.json` - never a hardcoded path, because it differs per install door), never a remote call. **Missing-`VERSION` fallback:** a kit home with no `VERSION` file predates tagging - treat it as "pre-v1, oldest" and warn the attendee, do not crash.

## 7. Cross-phase state & the installer

The three kits are installed and sewn together by the **kit-v2 chainer** - a manifest-driven installer engine in `claude-workshop-kit-v2`. It runs each phase as an ordered, gated, resumable stage.

Authoring rule for a kit: **a kit does not manage cross-phase progress state itself.** The chainer owns that - a single ledger at `~/.claude-workshop/state.json`. Each kit's bootstrap is invoked by the chainer as a stage `install_prompt`; the bootstrap installs that kit and leaves the kit's own setup marker (e.g. CWK's `memory/SETUP.md`), which the chainer reads as a `verify` input. Kits never read or write `state.json`, and kits do not implement their own phase-progression logic.

The canonical description of the chainer, the stage manifest, and the state model lives in **`claude-workshop-kit-v2/ARCHITECTURE.md` + `install/stages.yaml`** - read those before changing how a kit is installed or invoked.

## 8. Merge conventions

Identical across all three kit repos:

- Default `gh pr merge --squash`.
- Branches are **not** auto-deleted on merge.
- For stacked PRs, cascade-rebase each downstream PR onto updated `main` before merging - both `--squash` and `--rebase` merges break a stack otherwise.
