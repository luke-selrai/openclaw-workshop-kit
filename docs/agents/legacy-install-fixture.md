# Legacy-install fixture

How to rebuild a machine as an **old** bootstrap left it, in a sandbox, and dry-run the new
one-paste setup prompt against it.

This exists because people are already installed the old way — across more than one old
way. The install-model overhaul has to migrate all of them without re-onboarding them and
without eating their work, and that claim is only worth something if it has actually been
run. This is a **standing check**: re-run it against every future change to the setup
prompt.

Tracked as [CORE-109](https://linear.app/selr-ai/issue/CORE-109) under the install-model
overhaul map ([CORE-99](https://linear.app/selr-ai/issue/CORE-99)).

## Three legacy shapes

The kit was distributed three ways, and they do **not** share a layout. Each shape is read
off `docs/start/bootstrap.md` at that era's own ref, so the fixture is derived from the
kit's own record of what it did rather than from memory.

| shape | kit home | workspace | `.first-run-pending` | plugins | pinned ref |
| --- | --- | --- | --- | --- | --- |
| `loup` (default) | `~/.loup/selr-ai/workshop-kit` | `~/Desktop/my-assistant` | yes | yes | `ad124f1` |
| `github-desktop` | `~/workshop-kit` | `~/Desktop/my-assistant` | yes | yes | `6265b8e` |
| `github-home` | `~/workshop-kit` | `~/my-assistant` | **no** | **no** | `ddb68ec` |

All three are **legacy shapes**. `loup` reconstructs an **old Loup install**, not a live
one: [ADR-0003](../adr/0003-the-loup-door-is-retired.md) retired Loup as a delivery channel,
and the shape stays because those before-states are still on attendee laptops. Migration has
to find that kit home, rebuild fingerprints from it, and then delete it exactly as it
deletes `~/workshop-kit`.

`github-home` is the ancient pre-revive shape and the one that bites: its workspace is in
the **home folder, not the Desktop**, and it predates both the marker file and the plugin
marketplace step. Anything that hardcodes `~/Desktop/my-assistant` silently skips it.

The short-lived local-zip era has the same end-state as `github-home` — only how the kit
arrived differed, and nothing reads that — so it needs no separate shape.

In every shape three things are **absent**, and their absence is the point: no pointer
block in `~/.claude/CLAUDE.md`, no `~/.claude/selr-assistant.md`, no
`selr-kit-manifest.json`. Migration has to create them, so the dry-run asserts it did
rather than assuming.

## Build it

```
node scripts/make-legacy-fixture.mjs --out /tmp/legacy --shape github-home
```

Each shape carries its own pinned default ref, so you normally don't pass `--ref` at all.
Override it only to reconstruct a specific build within an era.

Useful flags:

- `--global-claude-md user-content` — seeds a hand-written `~/.claude/CLAUDE.md` with no
  pointer block. This is the case that matters: migration must **add** the block without
  destroying what the user already wrote. Run it both ways.
- `--force` — replace an existing `--out`
- `--pristine` — skip user-content seeding (see below)
- `--no-plugins` — skip the real `claude plugin` calls, for offline runs

By default the fixture is **not** pristine. It plants the three things that make the
interesting migration branches reachable at all:

1. a user-authored file in the workspace (`my-notes.md`) — must survive untouched
2. a user-authored skill not from the kit (`my-own-skill/`) — must survive untouched
3. an **edited** copy of a real kit skill — must trip keep-and-report, not be silently
   overwritten

A pristine fixture only exercises the happy path, which is the path least likely to break.
`FIXTURE.json` records exactly what was planted, plus shape, ref, commit, layout and skill
count, so a dry-run can assert against it without re-deriving anything.

Fidelity check: at their pinned refs the shapes install 204 (`loup`) and 117
(`github-home`) skills — matching each era's own `skills-audit:total` marker.

## Two things that will silently give you a false pass

**1. Sandbox with `HOME` alone — never `CLAUDE_CONFIG_DIR`.** Redirecting
`CLAUDE_CONFIG_DIR` does relocate the config tree, but it also breaks auth: the CLI reports
`Not logged in` and nothing can be run at all. With `HOME` sandboxed and
`CLAUDE_CONFIG_DIR` unset, the config dir resolves to the fixture's own `~/.claude` anyway
— same isolation, working auth.

**2. Git credentials are neutralised, and must stay that way.** The prompt decides what to
do with an unauthenticated `git ls-remote` probe. A developer machine reads the **closed**
repo just fine (the real global gitconfig routes github.com through `gh auth
git-credential`), so an un-neutralised probe *succeeds* and the dry-run silently tests the
clone branch while claiming to test a closed room, which is a false pass either way. An
attendee has
no credentials, is refused, and is told the kit is not open yet. The fixture therefore
writes a `.gitconfig` with an empty `credential.helper`.

Since ADR-0003 there is only one door, so a **refused probe dry-runs to a stop**: the prompt
says the kit is not open yet, waits for the room, and touches nothing. That is a real thing
to verify, and it is all a closed-repo run can verify. To exercise the clone and everything
after it, run the fixture while the repo is genuinely **public**, during a drop window,
which is exactly the state attendees run it in. Don't try to smuggle credentials in; a
sandboxed `HOME` drops `gh`'s own config and keyring access, so the probe is refused
regardless.

## Dry-run the prompt against it

Interactively — the build command prints this:

```
cd /tmp/legacy/home/my-assistant
env -u CLAUDE_CONFIG_DIR HOME=/tmp/legacy/home claude
```

Then paste the setup prompt. Start in the workspace to reproduce the attendee's own
starting folder, and separately from an unrelated folder to test "works from any folder".

Headless (for a scripted check) additionally needs an OAuth token in the environment, since
the sandboxed `HOME` can't reach the keychain:

```
TOKEN=$(security find-generic-password -s "Claude Code-credentials" -w \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])")

env -u CLAUDE_CONFIG_DIR HOME=/tmp/legacy/home CLAUDE_CODE_OAUTH_TOKEN="$TOKEN" \
  claude -p "$(cat prompt.md)" --dangerously-skip-permissions \
  --append-system-prompt "Automated dry-run: no human is available, never ask questions; stop at the restart step and report what changed."
```

A headless run cannot complete the whole flow — Step 7 requires a real quit-and-reopen of
Claude Desktop — so it covers Steps 0-6 and stops. The Playwright smoke test and the final
banner need an interactive run.

## What to verify

From the decisions locked in [CORE-104](https://linear.app/selr-ai/issue/CORE-104). This is
acceptance criteria, not a suggestion.

- [ ] **Correct mode chosen** — MIGRATE, and the prompt says so in one plain line
- [ ] **Persona imported globally** — pointer block in `~/.claude/CLAUDE.md`, persona at
      `~/.claude/selr-assistant.md`
- [ ] **Pre-existing global content survived** — on the `user-content` fixture the
      hand-written instructions are still intact alongside the new block
- [ ] **Manifest written**, with kit-named skills adopted into the receipt
- [ ] **`onboarded: true`** — the migrating user is not re-onboarded
- [ ] **`.first-run-pending` inert** — cannot retrigger orientation (shapes that have one)
- [ ] **Kit home recorded**: `~/claude-workshop-kit`, with `installPath: github`
- [ ] **Old workspace handled per spec** — check this **per shape**, not just on `loup`
- [ ] **Old kit download folder removed**: the shape's own kit home is gone, including both
      old Loup homes (ADR-0003 §3). `~/claude-workshop-kit` is never touched.
- [ ] **User-made content untouched** — `my-notes.md` and `my-own-skill/` byte-identical
- [ ] **Edited kit skill kept and reported**, not silently overwritten
- [ ] **"Works from any folder" note fires exactly once**

## Run one launcher at a time

If you script the three shapes in parallel, guard the launcher with a lockfile. Re-running
the launcher while an earlier one is still alive puts **two migrations over the same
fixture**, and the second one sees the first one's output as pre-existing state — the tell
is a run reporting that "a prior run had already done" the workspace rename. The end state
can still verify green while being meaningless. Check `ps aux | grep run.sh` before
relaunching, and delete the fixture between runs rather than reusing it.

## Verify the result

```
node scripts/verify-migration.mjs /tmp/legacy
```

Reads the fixture's own `FIXTURE.json` for the shape's layout and the user content that was
planted, so one verifier covers all three shapes. Exit 0 = every check passed. Sanity
property: run it against a fixture that has **not** been migrated and it must fail the
state checks — a verifier that goes green on the before-state is worthless.

## Findings

All three legacy shapes were dry-run against the accepted prompt with the repo public, so
the GitHub-clone door was exercised — the door attendees actually use. `loup` was then run
end-to-end interactively, through the restart.

### Everything verified

`loup` and `github-desktop` passed 14/14; `github-home` passed 13/13 (it has no marker to
remove). CORE-385 added the old-kit-home check, so the totals are one higher from here on. In every shape: one pointer block, persona installed, pre-existing hand-written
global content survived, manifest with `installMode: migrate`, `onboarded: true`, 204
fingerprints and an absolute kit home, old workspace `CLAUDE.md` renamed to
`.pre-migration`, and all user-made content untouched. `my-own-skill` is correctly
recognised as the user's own and excluded from both the kit sync and the manifest.

The interactive run additionally cleared the three restart-gated items: the Step 10 MIGRATE
note fires **exactly once**, the Playwright smoke test passes, and the completion banner
renders with nothing after it.

Strongest single signal: the assistant addressed the user as "Sam" — the name in the
fixture's seeded pre-existing `~/.claude/CLAUDE.md`. That proves the hand-written global
content survived the pointer-block write *and* is honoured at runtime, which a
file-presence check cannot show.

### The prompt fails safe

In an earlier run where the kit could not be obtained (repo closed), it stopped cleanly,
refused to fabricate a way in, and left the machine completely untouched. No partial
mutation before the kit is in hand. ADR-0003 made this the *designed* behaviour of a refused
probe rather than an accident of a dead-ending walkthrough: the prompt says the kit is not
open yet, waits, and re-probes on the attendee's word.

### MIGRATE detection leans on its second clause

Detection fires on "`~/Desktop/my-assistant/CLAUDE.md` present **or** kit skills in
`~/.claude/skills/`". On `github-home` the first clause cannot match — the workspace is in
the home folder — so the second clause is what makes migration work at all for every
pre-Desktop install. It is load-bearing, not the nicety it reads as in design note 4.

### Two places the spec relies on inference

Neither is a defect; both went right in the run. They are worth naming in the ADR so
correctness does not depend on the model generalising.

- **Workspace retirement** is written as an absolute path (`~/Desktop/my-assistant`). On
  `github-home` the model generalised it and correctly renamed `~/my-assistant/CLAUDE.md`.
  A stricter implementation would follow the literal path and silently skip every
  pre-Desktop install. See CORE-110.
- **The customisation question is asked blind.** It *is* asked properly, as an
  `AskUserQuestion` whose destructive option warns "If you edited a skill yourself, that
  edit would be replaced" — the resulting overwrite is informed consent, not silent loss.
  But the recommended option is the destructive one and the user cannot see which skills
  are affected. Since the old kit is still on disk in every legacy shape, the prompt could
  name them instead of making the user guess. See CORE-111.

### Reading a transcript: parse tool calls, not prose

The customisation question is a `tool_use` block and the answer a `tool_result` — neither
is assistant text. Scanning text blocks, or grepping for a question mark, makes a
correctly-asked question look like it never happened. This cost one wrong conclusion during
this exercise; check tool calls before concluding an interaction did not occur.
