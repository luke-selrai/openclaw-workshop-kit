# ADR-0001 — Kit install model: pointer block, manifest, universal one-paste setup

> **Amended by [ADR-0003](0003-the-loup-door-is-retired.md) (2026-09-07):** the Loup door is retired. There is one live door and one kit home; §1's second path, §3's `installPath` values and §5's stale-home rule are superseded there. The history below is left as written.

- **Status:** Accepted, 2026-07-31
- **Deciders:** Harvey Shaw, via the wayfinder map [CORE-99](https://linear.app/selr-ai/issue/CORE-99) (decision detail lives on its child tickets, linked throughout)
- **Scope:** how the workshop kit is installed, updated, migrated, and uninstalled — on both distribution paths

## Context

The kit previously installed through a workspace-folder model: a two-prompt flow (`docs/start/bootstrap.md` + `docs/start/full-setup.md`) that created `~/Desktop/my-assistant/`, put the assistant persona in that folder's `CLAUDE.md`, and marked first-run state with a `.first-run-pending` file. Distribution was Loup-only; an earlier GitHub-clone path had been retired — for **kit privacy**, not (as the 0007 contract recorded) Git-for-Windows friction.

Three drivers forced a redesign:

1. **School-community drops.** The kit is repeatedly distributed to the school community during **temporary public windows** of this repo — a co-equal GitHub-clone path, not a workshop path.
2. **The workspace folder was a lie of placement.** The assistant only worked from one folder, installs weren't updatable without trampling user edits, and nothing recorded what the kit had actually put on a machine.
3. **No uninstall existed**, which becomes unacceptable the moment the kit writes into the *global* Claude config.

Everything below was decided ticket-by-ticket on the map; the [CORE-100 ledger](https://linear.app/selr-ai/issue/CORE-100) holds the foundational session. This ADR is the single canonical statement; the tickets hold the reasoning trail.

## Decision

### 1. Two co-equal distribution paths, one silent probe

- **GitHub path**: real `git clone --depth 1` over HTTPS during temporary public windows. Kit home `~/claude-workshop-kit`. A public window *is* the access control — no entitlement, no commercial role.
- **Loup path**: unchanged platform mechanics (`npx @louphq/install`, token mint, dashboard). Kit home `~/.loup/selr-ai/workshop-kit`. Loup remains the workshop/commercial path and the only access-control model.
- The setup prompt **never asks which install type** the user is doing. An early cheap probe (`git ls-remote` with `GIT_TERMINAL_PROMPT=0`, generous timeout) splits three ways: success → clone door; auth-refused/not-found → Loup door (dashboard walkthrough, fresh-mint retry loop, never a GitHub password ask); timeout/network error → wifi retry loop, **never** a token ask. Narration stays generic ("downloading your kit now").
- **Always re-fetch, never update-in-place**: the GitHub door deletes and re-clones; the Loup door re-runs the user's install command. The kit home is a pure download area; HEAD is truth; no remote-state reasoning for the installer to fumble.
- Accepted consequences: a Loup-entitled user installing during a public window silently takes the GitHub path (identical kit, entitlement unexercised); a genuinely revoked/renamed repo reads as a private window (Loup's walkthrough dead-ends politely). ([CORE-104](https://linear.app/selr-ai/issue/CORE-104), [CORE-106](https://linear.app/selr-ai/issue/CORE-106))

### 2. Pointer-block architecture — the install is global

There is **no workspace folder**. Each install writes a managed, marker-delimited block into the global `~/.claude/CLAUDE.md`:

```
<!-- selr-kit:begin -->
## Selr AI Business Assistant

Kit home: <ABSOLUTE PATH>
Install details: ~/.claude/selr-kit-manifest.json

@<ABSOLUTE PATH TO ~/.claude/selr-assistant.md>
<!-- selr-kit:end -->
```

- The kit home is a **lazy** plain-text fact; the persona is an **eager** `@`-import. Eager content must earn eagerness — imports cost full inline tokens and are never a size-limit bypass.
- The persona is **copied out** of the kit to `~/.claude/selr-assistant.md` (re-copied on every update), so deleting the kit home never lobotomises the assistant. The repo source stays `my-assistant/CLAUDE.md`; only the installed copy is renamed.
- **Absolute paths, not `~`**: `@~/` resolution on Windows is unverified upstream ([CORE-102](https://linear.app/selr-ai/issue/CORE-102)).
- **Nothing model-facing inside the HTML-comment markers** — Claude strips comments from context; the markers only fence the block for update and uninstall.
- The block replaces in place between its markers and never touches anything outside them — hand-written global content survives (verified live in [CORE-109](https://linear.app/selr-ai/issue/CORE-109)).
- **Always global, no power-user branch.** One install model; the block is small, marked, and removable.

### 3. The manifest — the install is stateful

`~/.claude/selr-kit-manifest.json`, written fresh on every run:

```json
{
  "kitHome": "<absolute path the probe decided>",
  "installPath": "github | loup",
  "kitVersion": "<github: clone HEAD commit; loup: installer-reported version, else omit>",
  "installedAt": "<ISO timestamp>",
  "installMode": "fresh | update | migrate",
  "onboarded": false,
  "skills": { "<skill-name>": { "hash": "<SKILL.md content hash>", "customised": true } }
}
```

- **Fingerprints are SKILL.md-hash-only** — cheap, and it is the file people actually edit.
- The manifest powers three behaviours: **updates** (installed copy matches receipt → overwrite silently; differs → user customised → keep theirs and report, with a "say 'update X anyway'" escape hatch — kept entries record the *kit* hash with `customised: true` so the next update heals whatever the user unfreezes); **first-run** (`onboarded` is the assistant's *only* first-run signal — `.first-run-pending` is dead); **uninstall** (the exact inventory of what the kit put there).
- Everything downstream — pointer block, skills sync, plugin marketplace, updates, uninstall — reads the kit home **from the manifest**, so a machine switching paths between installs self-heals.
- Ordering: the manifest is written *before* the skills sync (the old manifest's fingerprints, read up front, drive keep-and-report; the new manifest's `skills` map fills during sync). A death between the two leaves a manifest with no receipts; the verify gate catches it and a re-paste self-heals.

### 4. One universal prompt, one setup document, one session

- A **single setup document** holds a **single pasted prompt** covering install, update, and migration. `bootstrap.md` and `full-setup.md` are deleted; their byte-identity checker retires — the shared text exists once, so drift is structurally impossible.
- Mode is detected in Step 1, before anything changes: manifest exists → **UPDATE**; no manifest but a legacy install detected → **MIGRATE**; neither → **FRESH**.
- **One-session setup with a single restart**: preflight (network sanity, Node, git — git is a preflight-installed dependency of the GitHub path) → probe + acquire → pointer block + persona copy → manifest → skills sync → plugin/marketplace → Playwright MCP (remove-first guard — `claude mcp add` errors on re-run; marketplace/plugin/skills installs are re-run-safe, [CORE-103](https://linear.app/selr-ai/issue/CORE-103)) → power-user skills → one full quit-and-reopen → in-session Playwright smoke test → verify gate → count-free completion banner ("start a new session and say hi").
- The accepted concrete prompt is the [CORE-106](https://linear.app/selr-ai/issue/CORE-106) prototype (draft PR #418, including its 9 accepted design calls), amended by §5 and §6 below; it graduates into the real document via CORE-112 and the draft dies.

### 5. Migration — gentle, automatic, no re-onboarding

- MIGRATE moves a legacy install onto the global model, sets `onboarded: true` (no re-onboarding), and tells the user once, in two lines, that the assistant now works from every folder.
- **The bulk skills question is dead** ([CORE-111](https://linear.app/selr-ai/issue/CORE-111)). MIGRATE has no old manifest, so Step 1 **reconstructs the fingerprints** by hashing installed skills against the on-disk old kit, probing all three legacy kit homes — `~/.loup/selr-ai/workshop-kit`, `~/workshop-kit`, `~/claude-workshop-kit`. A match against **any** probed copy proves the skill untouched. The snapshot happens in Step 1 because Step 2 overwrites the Loup path and re-clones. MIGRATE's sync then collapses into UPDATE's keep-and-report rule.
- **Fallback** when no old kit survives: treat every kit skill as customised — keep-and-report, no question. Safe by default; the report's escape hatch and `customised: true` receipts let the next update heal it.
- A confirmed-stale `~/workshop-kit` (contains `skills/` plus the era's markers — never a same-named user folder) is deleted alongside the workspace retirement.
- Migration was verified against **all three** legacy shapes — `loup`, `github-desktop`, and the ancient `github-home` — end-to-end through the restart, smoke test, and banner ([CORE-109](https://linear.app/selr-ai/issue/CORE-109)); the fixture builder + verifier are a standing check.

### 6. Named concepts: the legacy-workspace candidate list and the fingerprint guard

Defined **here, once**; every surface that touches legacy workspaces references these by name ([CORE-110](https://linear.app/selr-ai/issue/CORE-110)):

- **Legacy-workspace candidate list:** `~/Desktop/my-assistant` and `~/my-assistant`. Canonical paths only — **no hunting** for renamed/relocated workspaces.
- **Fingerprint guard:** a `CLAUDE.md` is the kit's persona iff its **first line is exactly `# Your AI Business Assistant`** (verified identical across all three era refs).
- **Retirement** (setup prompt Step 3.3): every candidate that exists *and* passes the fingerprint → rename `CLAUDE.md` → `CLAUDE.md.pre-migration`, delete its `.first-run-pending`. Fingerprint fails → **skip and tell**, never silent. Both candidates can retire in one run.
- **Detection** (Step 1) uses the same list but stays **deliberately looser**: persona *present* at any candidate path OR kit skills in `~/.claude/skills/`, no fingerprint. The asymmetry is intentional — detection erring loose is safe (migration is gentle); retirement erring loose destroys user work.
- **Uninstall symmetry:** the kept-and-reported legacy folder is "any candidate-list folder", the same named concept.

### 7. Orientation replaces first-run-setup

`first-run-setup` is renamed **`orientation`** — full rename, no alias — and rewritten to what remains once the prompt absorbs the mechanical phase: the 7-question onboarding, live demo, personalised shortlist, and a light manifest-driven sanity check. It triggers on manifest `onboarded: false` and **sets the flag true** when done (it no longer deletes a state file). Orientation may quote live skill counts; the setup banner never does, so the prompt cannot drift from the audit markers. ([CORE-104](https://linear.app/selr-ai/issue/CORE-104))

### 8. The persona — kept, trimmed, surface-neutral

The persona survives per-rule existence justification at 241 → 108 lines (PR #417, [CORE-101](https://linear.app/selr-ai/issue/CORE-101)): its dispositional content (installer disposition, install narration, credentials ordering, Playwright-primary discipline, automation routing, restart rules) cannot live in lazy skills. The communication-rules section is gone — replaced by a 4-line audience note whose principle is *name the real thing, define it once in one short line, then use the real word*; the old canon ("we will install Claude Code" while installing npm) instructed lying and is the suspected cause of kit-Claude feeling less predictable than stock Claude. The persona is surface-neutral (Desktop, VS Code extension, terminal), and its file references use the pointer/`<kit home>` paths.

### 9. Uninstall — load-bearing, manifest-exact, deliberately narrow

"Hey, uninstall it" works with nothing to paste ([CORE-105](https://linear.app/selr-ai/issue/CORE-105)):

- **One-line kit skill → one canonical doc**: the skill resolves the kit home from the manifest, reads `docs/uninstall.md` there, and follows it. The skill carries no logic, so skill and doc cannot drift; the setup document carries no uninstall steps.
- **Removes (manifest-exact, in order):** pointer block; persona copy; kit home (from the manifest, never guessed); kit-named unmodified skills (including `orientation` and the uninstall skill itself); plugin + marketplace registration; the manifest **last**.
- **Keeps and reports:** customised skills (hash mismatch), memory, any legacy-workspace candidate-list folder. Purging these takes a separate explicit request.
- **Never touches, no opt-in offered:** Playwright MCP + profile + browsers; the four power-user skills; connector MCP entries and credentials; Node/nvm; the Claude Code CLI; Claude Desktop. The report ends: "Claude Code itself is untouched — you can keep using it."
- **One confirmation gate**: the full manifest-derived inventory grouped *delete / kept-because-customised / left-in-place*, one "proceed?", then no further prompts.
- **Partial uninstall**: skill granularity only, low priority, **no tombstones** — a later update reinstalls removed skills and the report says so plainly.
- **Manifest-missing fallback**: a best-effort checklist (markers, persona path, plugin names, kit-named skills, both kit homes) that reports anything unverifiable. The escape hatch does not depend on the thing it escapes from.
- Design centre, verbatim intent: uninstall exists to kill the skill bloat and get the persona out of the global CLAUDE.md — everything beyond that was deliberately ruled overkill.

### 10. Operations: school drops

The flip-public → announce → flip-private cycle becomes its **own Harvey-internal skill** (like `workshop-preflight`, never shipped to attendees): pre-flip checks, visibility flip with an *unauthenticated* probe verification each way, announcement draft, window tracking, and a drop log recording date + HEAD commit — so "which version do legacy users have" is answerable at the next migration.

## Rejected alternatives

| Rejected | Why |
| --- | --- |
| Symlinks instead of copies | Windows privilege friction; the clone becomes load-bearing; silent loss of user edits |
| `git fetch`/`pull` update-in-place | Remote-state reasoning for a prompt-executing installer to fumble; re-clone is truth |
| Power-user (non-global) install branch | One install model; the global block is small, marked, removable |
| Asking the user which install type they have | They cannot know — it is our plumbing; the probe knows |
| The MIGRATE bulk skills question | Blind, destructive-by-default; fingerprint reconstruction answers it deterministically |
| Home-folder hunting for renamed workspaces | Small population, non-destructive failure mode; named as an accepted gap instead |
| Connector/Playwright teardown in uninstall | Ruled overkill; removable by hand; nobody uninstalling the kit needs it |
| Tombstones for partially-removed skills | Update-reinstalls-it is acceptable and plainly reported |
| Hard skill counts in the completion banner | The prompt must never drift from the audit markers; orientation quotes live numbers |
| Deleting the persona (skills-only assistant) | Dispositional content cannot live in lazy skills; survived per-rule justification |

## Accepted gaps

- Renamed/relocated legacy workspaces are not discovered (stale second persona possible; annoying, not destructive).
- A revoked/renamed repo is indistinguishable from a private window at the probe.
- `kitVersion` on the Loup door depends on what the installer reports — "else omit"; nothing load-bearing needs it.
- Manifest *and* kit home both destroyed → uninstall doc unreachable locally; a support case, not designed for.

## Consequences — implementation breakdown

Implementation proceeds as ordinary Core Builds tickets. [CORE-112](https://linear.app/selr-ai/issue/CORE-112) is the keystone; everything else is blocked behind it.

| Ticket | Delivers |
| --- | --- |
| [CORE-112](https://linear.app/selr-ai/issue/CORE-112) | The universal setup document (replaces `bootstrap.md` + `full-setup.md`), folding in the §5 MIGRATE reconstruction and §6 named concepts; deletes the draft; re-runs the three-shape migration check |
| [CORE-113](https://linear.app/selr-ai/issue/CORE-113) | Merges the trimmed pointer-block persona (PR #417) |
| [CORE-114](https://linear.app/selr-ai/issue/CORE-114) | `first-run-setup` → `orientation`, manifest-triggered; `.first-run-pending` retired everywhere |
| [CORE-115](https://linear.app/selr-ai/issue/CORE-115) | `docs/uninstall.md` + the one-line uninstall skill |
| [CORE-116](https://linear.app/selr-ai/issue/CORE-116) | Conformance-tooling redesign: inverted canon checks, probe/clone surface, retired byte-identity checker, rift-test kit-side assertions |
| [CORE-117](https://linear.app/selr-ai/issue/CORE-117) | Stale-doc sweep (incl. the Git-for-Windows correction: preflight dependency, not retired) |
| [CORE-118](https://linear.app/selr-ai/issue/CORE-118) | Notion bootstrap page updated to the universal prompt (byte-identical copy) |
| [CORE-119](https://linear.app/selr-ai/issue/CORE-119) | `workshop-preflight` rewrite (also blocked by CORE-118) |
| [CORE-120](https://linear.app/selr-ai/issue/CORE-120) | The school-drop ritual skill (§10) |

Standing checks that outlive the map: the legacy-install fixture + migration verifier (`scripts/make-legacy-fixture.mjs`, `scripts/verify-migration.mjs`, recipe in `docs/agents/legacy-install-fixture.md`) re-run against every future change to the setup prompt.

Cross-repo: the 0007 private-kit-delivery contract was amended for the co-equal GitHub path on 2026-07-30 ([CORE-107](https://linear.app/selr-ai/issue/CORE-107)) — a deliberately local-only artifact at `the-platform/features/0007-private-kit-delivery-loup.md`; Loup-side impact: none.
