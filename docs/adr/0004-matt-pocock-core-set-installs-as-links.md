# ADR-0004 — The Matt Pocock core set installs as links out of the `skills` CLI's shared store

- **Status:** Accepted, 2026-09-08
- **Deciders:** Harvey Shaw, ticket [Install the core Matt Pocock skills (engineering + productivity) as symlinks during setup (CORE-430)](https://linear.app/selr-ai/issue/CORE-430)
- **Scope:** which third-party skills the setup prompt installs beside the kit, and how they land on disk. Everything else in [ADR-0001](0001-pointer-block-install-model.md) stands: kit skills are still copied, fingerprinted and manifest-tracked.

## Context

Since [LOUP-19](https://linear.app/selr-ai/issue/LOUP-19) the setup prompt's Step 6 has installed four hand-picked skills from [mattpocock/skills](https://github.com/mattpocock/skills) (`grill-me`, `handoff`, `diagnosing-bugs`, `teach`) with `npx skills add … -a claude-code … --copy`: loose copies in `~/.claude/skills/`, outside the manifest, refreshed only by re-running the command.

Two things changed:

1. **The set is the wrong size.** The workshop's lessons lean on `grill-me` and `handoff`, but the kit's own maintainers run the whole core set daily, and the four-skill pick was an accident of when LOUP-19 was written rather than a decision. Upstream now organises the repo into buckets: `engineering/` and `productivity/` are the promoted core (also what its Claude Code plugin ships), while `in-progress/`, `misc/` and `deprecated/` are explicitly not.
2. **The layout is wrong for a set that updates.** The maintainer's machines carry these skills the way the `skills` CLI installs them by default: one materialised copy per skill in the CLI's shared store, `~/.agents/skills/<name>/`, and `~/.claude/skills/<name>` as a link into it. One source of truth, and every re-run refreshes in place. The kit's `--copy` form instead left a second, ageing copy of each skill that nothing but a re-paste of the prompt would ever update.

ADR-0001 rejected "symlinks instead of copies" for the **kit's** skills on three grounds: Windows privilege friction, the clone becoming load-bearing, and silent loss of user edits. None of the three transfers to this set, which is why this is a scoped exception rather than a reversal:

- **Windows.** Verified against `skills@1.5.24`: on `win32` the CLI creates a **directory junction** (`fs.symlink(target, link, "junction")`), which needs neither administrator rights nor Developer Mode. On Mac it writes a relative symlink. When linking fails for any reason the CLI falls back to copying and reports it, so the install never dead-ends.
- **Load-bearing clone.** The link target is the CLI's shared store, not the kit clone. The kit home can be deleted and re-fetched freely, exactly as ADR-0001 requires.
- **User edits.** These are not kit skills and never were: the manifest does not list them, the fingerprint sync never touches them, and uninstall leaves them. An attendee who wants to edit one edits the store copy, which the CLI's own `skills update` respects.

One more fact governs the command's shape. The CLI only uses the store-plus-links layout when **more than one agent** is named; a single `-a claude-code` global install copies (verified in a throwaway home directory: `-a claude-code` alone prints "copied", `-a claude-code -a codex` prints "symlinked: Claude Code" and writes the store). Codex is a "universal" agent that reads `~/.agents/skills/` directly, so naming it installs nothing else on the machine; it is purely the switch that turns links on. The CLI also removes an existing plain directory at the link path before linking, so the four old copies from the LOUP-19 form are replaced on the first re-run without a move-aside step.

## Decision

### 1. The set is the upstream core, spelled out

The prompt installs every skill under `skills/engineering/` and `skills/productivity/` of `mattpocock/skills`, and nothing from `in-progress/`, `misc/` or `deprecated/`. The names are **hardcoded** in the install command, one `-s <name>` each, and mirrored in `EXPECTED_SKILLS` in `scripts/check-mp-skills-install.mjs`.

Hardcoding is deliberate. The alternative, parsing the CLI's `-l` listing at install time and installing whatever appears under its "Mattpocock Skills" heading (the form `mp-skills-kit` uses), makes an attendee's Claude session the parser of a TUI listing on venue wifi, with "install nothing" and "install everything" as the failure modes. A fixed list fails loudly instead, and CI owns the drift: `--live` fetches the upstream tree and asserts `EXPECTED_SKILLS` equals the live core set **in both directions**, so a rename, removal, demotion or addition upstream turns the `audit-skills` check red at the next run rather than silently changing what attendees get.

### 2. The layout is the CLI's store plus links

The command is the two-agent, no-`--copy` form:

```
npx -y skills@latest add mattpocock/skills -g -a claude-code -a codex -y -s <name> … -s <name>
```

Same command on Mac and Windows. Skills materialise in `~/.agents/skills/<name>/`; `~/.claude/skills/<name>` is a symlink (Mac) or junction (Windows) into it. The prompt says so in one plain line and forbids asking the attendee to enable Developer Mode or run anything elevated.

### 3. Verification opens the file through the link

A link that leads nowhere passes a naive folder-exists check, so Step 6 and the Step 9 verify gate both require `~/.claude/skills/<name>/SKILL.md` to **open** for every name in the command. The self-heal from LOUP-19 (list live → resolve renames → re-run → re-check → per-skill report) is unchanged, with one addition: the report must name any skill that landed as a plain copy, because that copy will not refresh itself on the next run.

### 4. Still outside the kit's state

Nothing here enters `~/.claude/selr-kit-manifest.json`. The Step 5 sync rule ("anything in `~/.claude/skills/` that is not a kit skill is mine") continues to cover both the links and any store copy. `docs/uninstall.md` keeps them in its "left in place on purpose" group. No kit skill shares a name with any core skill (checked at decision time; the `--live` run would surface a future collision as an unexpected name only if it were also added to `EXPECTED_SKILLS`, so the no-collision rule is part of updating that list).

### 5. The prompt stays count-free

The setup document may not carry a two-or-more-digit count next to the word "skills" (`audit-skills.mjs`, count-free rule). The step therefore says "the engineering and productivity set", never how many that is.

## Consequences

- Attendees who ran the LOUP-19 form get their four copies replaced by links on the next UPDATE run, plus the rest of the core set. Nothing is asked of them.
- `check-mp-skills-install.mjs` grows three rules (`no-copy-flag`, `two-agent-link-form`, `link-verified`) and its `--live` check becomes two-sided. The bad fixture fails every one of them.
- The day page (`selrai-company/selr-install-day`, `index.html`) carries a copy of this prompt and changes in the same PR pair.
- If the CLI ever changes the rule that two agents means links, `two-agent-link-form` is the rule to revisit; the empirical check that established it is in the ticket.

## Rejected alternatives

| Rejected | Why |
| --- | --- |
| Keep four copied skills | The set was an accident of LOUP-19's date, and copies never refresh themselves |
| Read the live listing at install time (`mp-skills-kit` form) | Makes an attendee's session parse a TUI listing; failure modes are "nothing" or "everything". CI can own drift instead |
| `-s '*'` | Pulls in `in-progress/`, `misc/` and `deprecated/`, which upstream itself excludes from the plugin |
| Upstream's Claude Code plugin (`claude plugins install mattpocock-skills`) | A read-only bundle outside `~/.claude/skills/`; does not match the maintainer's layout the ask was parity with, and installing both routes leaves every skill twice |
| Move existing copies aside to `.bak` before installing | The CLI already replaces a plain directory at the link path; a `.bak` folder inside `~/.claude/skills/` is itself a loadable skill |
| Vendor the skills into `skills/` | Breaks the no-copy skill rule in `CONTRIBUTING.md` and ships a stale copy of a fast-moving library |
