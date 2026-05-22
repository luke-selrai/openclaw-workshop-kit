# Contributing to the SelrAI workshop kits

This is the **canonical, author-facing convention guide** for all three SelrAI workshop kits:

- `claude-workshop-kit` — Phase 1 — the AI Business Assistant (**this repo**)
- `claude-workshop-v2-automation` — Phase 2 — automation / running Claude 24/7
- `claude-workshop-v3-building` — Phase 3 — app & website building

It lives in `claude-workshop-kit` because Phase 1 is the foundation every kit builds on — so anyone working on *any* kit already has this repo. The Phase 2 and Phase 3 repos each carry a short `CONTRIBUTING.md` that points here. **This file is the single source of truth for kit conventions; do not copy its contents into other repos.**

**Workshop attendees can ignore this file.** It is build guidance for whoever authors or maintains a kit — not setup instructions. It contains no secrets; it is simply not useful to a participant.

> The *why* behind the three-repo structure, the drift analysis, and the workshop's strategic decisions live in SelrAI's internal team wiki, not here. This file is the *how* — the conventions you follow when changing a kit.

## Why these conventions exist

The kits are three separate repos — for drift isolation and clean per-segment boundaries. Every workshop attendee gets all three; there is no per-phase gating. Separate repos drift. These conventions are how they stay coherent: non-text conventions are enforced by each kit's own check script; text conventions stay consistent by everyone reading this one file.

## 1. SKILL.md frontmatter schema

Every `skills/<name>/SKILL.md` MUST have YAML frontmatter:

```yaml
---
name: <kebab-case>          # REQUIRED. Must equal the parent directory name.
description: <string>       # REQUIRED. The trigger text — when should this skill fire.
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
- `description` is the only thing Claude sees when deciding whether to load the skill — it must contain concrete trigger phrases, not a vague summary.
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

- `skills` and `mcpServers` frontmatter fields are **not** honoured when a subagent definition runs as an Agent Teams teammate — teammates load skills/MCP from project + user settings. Do not put them in teammate definitions.
- The body is appended to (not replacing) the teammate's system prompt.

## 3. Participant-facing tone rules

These apply to anything an attendee reads — READMEs, `docs/`, bootstrap prompts, and the user-facing `CLAUDE.md`. They do NOT apply to author-facing docs such as this `CONTRIBUTING.md`.

- **Plain English.** Banned jargon in user-facing text: `MCP`, `npx`, `bash`, `JSON`, `OAuth`, `token`, `client_id`, `curl`, `API`, `endpoint`, `environment variable`, `CLI`, `redirect URI`, `callback`. If a technical thing must be named, name it plainly ("the connection key", "your account details").
- **Narrate at action boundaries.** Tell the attendee what is about to happen before it happens.
- **Never echo credentials** in narration, tool output, or logs.
- Phase 3 is more technical than Phase 1 (it is app-building) — some code vocabulary is unavoidable there — but setup/onboarding docs still target an attendee, not a developer.

## 4. Repo / doc structure

Each kit repo follows this shape (scaled to the kit — not every kit needs every folder):

```
<kit>/
├── README.md              ← participant-facing pitch + read order
├── CONTRIBUTING.md         ← canonical here (CWK); a pointer in other kits
├── VERSION                ← semver, see §6
├── docs/
│   ├── install/           ← what to buy / install before the workshop
│   ├── start/             ← bootstrap prompt + setup walkthrough
│   ├── use/               ← first prompts, what it remembers
│   ├── skills/  (or agents/) ← catalogue of what the kit adds
│   └── extend/            ← optional advanced paths
├── skills/                ← SKILL.md folders (if the kit ships skills)
├── agents/                ← subagent definitions (if the kit ships teammate roles)
└── scripts/               ← preflight + the kit's right-sized check
```

## 5. Drift-prevention rules

- **No-copy skill rule.** A skill or subagent definition lives in **exactly one kit**. Never copy it into another kit. If two kits need it, it belongs in `claude-workshop-kit` (the foundation every attendee installs first) and the others reference it. The `voice-transcription` fork between CWK and `advanced-claude-workshop-kit` is the cautionary tale — it drifted *because it was copied*.
- **Right-sized tooling, never copied tooling.** Each kit gets a skill-check sized to it. CWK's `audit-skills.mjs` (174 skills, 10 marker-tracked docs) is NOT copied into smaller kits. Phase 2 gets `check-skills.mjs`; Phase 3 gets a ~20-line `check-kit.mjs`. **Review checkpoint:** if you are about to copy a tooling script from another kit — stop. Right-size a new one instead.
- **Keep team-internal material out of kit repos.** Kit repos are handover artifacts shipped to attendees. Strategy, decision history, and operational runbooks live in the team wiki — not here. Author-facing *build conventions* (this `CONTRIBUTING.md`) are fine: they are guidance, not internal strategy.

## 6. Versioning

Every kit MUST have:
- A `VERSION` file at the repo root — semver (`MAJOR.MINOR.PATCH`).
- A git tag per release (`v1.2.0`).
- A GitHub release per tag.

Downstream kits declare a compatibility floor in their README ("Phase 3 v1 needs Phase 1 ≥ v2"). The progression flow reads the installed version from the attendee's **local** clone (`~/workshop-kit/VERSION`), never a remote call. **Missing-`VERSION` fallback:** a clone with no `VERSION` file predates tagging — treat it as "pre-v1, oldest" and warn the attendee, do not crash.

## 7. Workshop progress contract

How the three kits know which phase an attendee is on, and how that state survives across phases. This is the **state seam** that sews the kits together.

> **Implementation status (2026-05-22).** This is the **target contract**. The `continue-workshop` skill (CWK, shipped) currently uses interim heuristic detection — prose markers in `CLAUDE.md` plus on-disk artifact checks. The contract below is implemented in full alongside the Phase 2 build + the 3-repo connection test. It is documented **now**, before Phase 2 exists, specifically so **Phase 2's bootstrap follows it from the start** instead of inventing its own progress-tracking.

### The file

`~/Desktop/my-assistant/.workshop-progress` — a JSON file in the attendee's workspace, beside `CLAUDE.md`. Dotfile prefix: it is machine state, not participant-facing content (same convention as `.first-run-pending`). Read and written only by Claude / kit scripts — never by a human, so JSON is appropriate.

### Schema (v1)

```json
{
  "schema": 1,
  "phases": {
    "1": { "installed": true,  "version": "1.4.0", "installed_at": "2026-05-22" },
    "2": { "installed": false, "version": null,    "installed_at": null },
    "3": { "installed": false, "version": null,    "installed_at": null }
  }
}
```

- All three phase keys are always present.
- `version` is read from that kit's `VERSION` file (§6) at install time; `null` if the kit has no `VERSION` file.
- `installed_at` is an ISO date.
- There is **no** `current_phase` field — "the next phase" is *derived* (lowest key with `installed: false`). One source of truth; nothing to fall out of sync.
- `schema` lets the format evolve without breaking old readers.

### Write / read protocol

The file is owned by a protocol, not a single component. **The discipline that keeps it drift-proof: each phase's bootstrap touches only its own key — no phase ever rewrites the whole file.**

| Actor | Action |
|---|---|
| Phase 1 (CWK) bootstrap | **Creates** the file. Seeds `phases."1"` installed; `phases."2"` and `"3"` not installed. The only component that creates it. |
| Phase 2 bootstrap | **Updates only `phases."2"`** to installed + version + date. Never recreates the file; never touches keys 1 or 3. |
| Phase 3 bootstrap | **Updates only `phases."3"`**, same rule. |
| `continue-workshop` skill | **Reads** the file. Next phase = lowest key with `installed: false`. All installed → workshop complete. |
| Each phase's bootstrap | Also **reads** it for a compatibility check (e.g. Phase 3 confirms `phases."1".version` meets its floor — §6). |

### Self-healing rule

`continue-workshop` MUST NOT trust the file blindly:

1. Try to read and parse `.workshop-progress`.
2. If **missing or malformed** → reconstruct phase state from on-disk artifacts (CWK skills present in `~/.claude/skills/` → phase 1; a Phase 3 teammate definition in `~/.claude/agents/` → phase 3; and so on).
3. **Rewrite a clean `.workshop-progress`** from what was detected.

The file is the fast path; artifact detection is the fallback that also repairs the file. An attendee on a pre-contract kit, or one whose file was deleted, self-heals on the next "what's next" — they are never stranded.

## 8. Merge conventions

Identical across all three kit repos:

- Default `gh pr merge --squash`.
- Branches are **not** auto-deleted on merge.
- For stacked PRs, cascade-rebase each downstream PR onto updated `main` before merging — both `--squash` and `--rebase` merges break a stack otherwise.
