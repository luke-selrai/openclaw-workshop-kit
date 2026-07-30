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

**2. Git credentials are neutralised, and must stay that way.** The prompt picks its
acquisition door with an unauthenticated `git ls-remote` probe. A developer machine reads
the **private** repo just fine (the real global gitconfig routes github.com through
`gh auth git-credential`), so an un-neutralised probe *succeeds* and the dry-run silently
tests the GitHub-clone door — the wrong branch, and a false pass. An attendee has no
credentials, is refused, and lands on the Loup door. The fixture therefore writes a
`.gitconfig` with an empty `credential.helper`.

To test the **GitHub-clone door**, don't try to smuggle credentials in — a sandboxed `HOME`
drops `gh`'s own config and keyring access, so it fails back to the Loup door regardless.
Run the fixture while the repo is genuinely **public**, during a drop window. A public repo
needs no credentials, so the neutralised fixture is already the faithful test of that door.

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
- [ ] **Kit home recorded per the probe outcome** — matches the door actually taken
- [ ] **Old workspace handled per spec** — check this **per shape**, not just on `loup`
- [ ] **User-made content untouched** — `my-notes.md` and `my-own-skill/` byte-identical
- [ ] **Edited kit skill kept and reported**, not silently overwritten
- [ ] **"Works from any folder" note fires exactly once**

## Findings so far

Dry-run against `github-home` (ancient shape), Loup door, Steps 0-6:

- **MIGRATE detection fires correctly** on the ancient shape — but only via the
  "kit skills in `~/.claude/skills/`" clause, since the `~/Desktop/my-assistant/CLAUDE.md`
  clause cannot match a home-folder workspace. That second clause is **load-bearing for
  every pre-Desktop install**, not the nicety it reads as in design note 4.
- **The prompt fails safe.** With no way to obtain the kit it stopped cleanly, refused to
  fabricate a Loup command, and left the machine completely untouched — no partial
  mutation before the kit is in hand.
- **Open, from reading the spec rather than the run** (the run stopped at acquisition):
  Step 3.3 retires the old workspace by absolute path — it renames
  `~/Desktop/my-assistant/CLAUDE.md` and deletes `~/Desktop/my-assistant/.first-run-pending`.
  On `github-home` that folder does not exist, so the stale persona at
  `~/my-assistant/CLAUDE.md` is never renamed. A user who later opens that folder would
  load the old project-level persona **and** the new global one. Needs either a
  shape-aware retirement step or an explicit decision to accept it; feeds
  [CORE-108](https://linear.app/selr-ai/issue/CORE-108).
