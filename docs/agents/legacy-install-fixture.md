# Legacy-install fixture

How to rebuild a machine as the **old** bootstrap left it, in a sandbox, and dry-run the
new one-paste setup prompt against it.

This exists because 10+ school-community members are already installed the old way. The
install-model overhaul has to migrate them without re-onboarding them and without eating
their work, and that claim is only worth anything if it has actually been run. This is a
**standing check**, not a one-off: re-run it against every future change to the setup
prompt.

Tracked as [CORE-109](https://linear.app/selr-ai/issue/CORE-109) under the install-model
overhaul map ([CORE-99](https://linear.app/selr-ai/issue/CORE-99)).

## The before-state

Reconstructed from `docs/start/bootstrap.md` steps 2-6 at a pinned ref, so it is derived
from the kit's own record of what it did rather than from memory:

| Path | What it is |
| --- | --- |
| `~/Desktop/my-assistant/CLAUDE.md` | the persona, copied into the workspace (**not** imported globally) |
| `~/Desktop/my-assistant/.first-run-pending` | the orientation marker the new model retires |
| `~/.loup/selr-ai/workshop-kit/` | the kit, as the Loup install dropped it |
| `~/.claude/skills/` | one flat directory per kit skill, no `SKILLS-LIST.md` |
| `~/.claude/plugins/`, `~/.claude/settings.json` | marketplace + routine-installer, written by the real `claude plugin` CLI |

Three things are **absent**, and their absence is the point of the fixture — the migration
has to create them, so the dry-run must assert it did rather than assume:

- no pointer block in `~/.claude/CLAUDE.md`
- no `~/.claude/selr-assistant.md`
- no `selr-kit-manifest.json`

## Build it

```
node scripts/make-legacy-fixture.mjs --out /tmp/legacy --ref <kit-ref>
```

`--ref` is the kit version to reconstruct from (default `HEAD`). **Pin it to the version
the attendees actually have** — a fixture built from today's `main` tests a migration
nobody is going to perform. If that version isn't known yet, build from `HEAD` to exercise
the mechanics and rebuild with the real ref before trusting the result.

Useful flags:

- `--global-claude-md user-content` — seeds a hand-written `~/.claude/CLAUDE.md` with no
  pointer block. This is the case that matters: the migration must **add** the block
  without destroying what the user already wrote. Run the fixture both ways.
- `--force` — replace an existing `--out`
- `--pristine` — skip user-content seeding (see below)
- `--no-plugins` — skip the real `claude plugin` calls, for offline runs

By default the fixture is **not** pristine. It plants the three things that make the
interesting migration branches reachable at all:

1. a user-authored file in the workspace (`my-notes.md`) — must survive untouched
2. a user-authored skill not from the kit (`my-own-skill/`) — must survive untouched
3. an **edited** copy of a real kit skill — must trip keep-and-report, not be silently
   overwritten

A pristine fixture only ever exercises the happy path, which is the path least likely to
break. `FIXTURE.json` in the output records exactly what was planted, plus the ref, commit,
and skill count, so a dry-run can assert against it without re-deriving anything.

## Dry-run the prompt against it

Isolation is `HOME` + `CLAUDE_CONFIG_DIR`. `CLAUDE_CONFIG_DIR` relocates the whole config
tree (`settings.json`, `plugins/`, `.claude.json`) and `~` in the prompt's own shell
commands follows `HOME`, so nothing touches the real machine. The build command prints the
exact invocation; it is:

```
HOME="/tmp/legacy/home" \
CLAUDE_CONFIG_DIR="/tmp/legacy/home/.claude" \
claude --add-dir "/tmp/legacy/home"
```

Start it in `.../home/Desktop/my-assistant` to reproduce the attendee's own starting
folder, and separately from an unrelated folder to test the "works from any folder" claim.
Then paste the setup prompt.

Run it against **both** acquisition branches if feasible — the public-window/GitHub clone
branch and the Loup branch — since the prompt's three-way probe decides between them and
records the outcome as the kit home.

## What to verify

After the prompt completes, check each of these. They come from the decisions locked in
[CORE-104](https://linear.app/selr-ai/issue/CORE-104); this list is the acceptance
criteria, not a suggestion.

- [ ] **Persona imported globally** — pointer block present in `~/.claude/CLAUDE.md`,
      persona at `~/.claude/selr-assistant.md`
- [ ] **Pre-existing global content survived** — on the `user-content` fixture, the
      hand-written instructions are still there, intact, alongside the new block
- [ ] **Manifest written** with the kit-named skills adopted into the receipt
- [ ] **`onboarded: true`** in the manifest — the migrating user is not re-onboarded
- [ ] **`.first-run-pending` cannot retrigger orientation** — the retired marker is inert
      whether it was removed or merely ignored
- [ ] **Kit home recorded per the probe outcome** — matches whichever branch the probe took
- [ ] **Old workspace handled per spec**
- [ ] **User-made content untouched** — `my-notes.md` and `my-own-skill/` byte-identical
- [ ] **Edited kit skill kept and reported**, not silently overwritten
- [ ] **"Works from any folder" note fires exactly once**

## Status

The fixture half is built and verified. The dry-run half is **blocked** on the universal
one-paste prompt landing ([CORE-106](https://linear.app/selr-ai/issue/CORE-106)) — there
is no new prompt to run yet.
