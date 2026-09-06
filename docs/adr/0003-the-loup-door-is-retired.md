# ADR-0003 — The Loup door is retired: the kit opens with the room

- **Status:** Accepted, 2026-09-07
- **Deciders:** Harvey Shaw, via the wayfinder map [CORE-362](https://linear.app/selr-ai/issue/CORE-362), ticket [Retire the Loup install method (CORE-385)](https://linear.app/selr-ai/issue/CORE-385)
- **Scope:** how the kit is acquired. Everything else in ADR-0001 stands: the pointer block, the manifest, the one universal prompt, MIGRATE, uninstall.

## Context

[ADR-0001 §1](0001-pointer-block-install-model.md) put two co-equal doors behind one silent probe: a `git clone` during a temporary public window, and a Loup install (`npx @louphq/install`, a minted token, a dashboard walkthrough) whenever the probe was refused. Loup was the workshop path and the only access-control model; the clone was for school-community drops.

That is no longer true. Loup is discontinued as a delivery channel for this kit. Every workshop now runs the same way the drops do: the repo is flipped public for the room by `scripts/kit-gate.sh open` in the install-day repo at workshop start, and closed after.

What the second door actually cost, once it stopped being the workshop path:

1. **It was the only step that could dead-end.** Every other failure in the prompt resolves between the attendee and Claude. The Loup door could not: a missing grant email, a used sign-in link or an inactive entitlement all ended in "that is not something you and I can fix from here", in the middle of a room where nobody is answering questions.
2. **It taught the attendee to hunt for credentials.** A dashboard, a sign-in, a token, a pasted install command. None of that exists in the world the kit ships into, and a refused probe on venue wifi is far more often a closed room than a lost entitlement.
3. **Two live homes made every downstream surface conditional.** `installPath` had two values, `kitVersion` had two derivations, the plugin-marketplace remove-first guard existed for machines that crossed between doors, and no old kit folder could be safely deleted because one of them might be the live one.
4. **Loup's snapshot caps still bound the repo.** `check-snapshot-shape.mjs` gated file count and archive size against limits belonging to a publisher that no longer publishes this kit.

## Decision

### 1. One live door

- **Door A (probe succeeds) is unchanged.** Fresh `git clone --depth 1` over HTTPS into `~/claude-workshop-kit`, still with `GIT_TERMINAL_PROMPT=0`, still always re-fetched rather than updated in place.
- **Door B (probe refused: authentication error or repository not found) becomes "the kit is not open yet".** The kit is open while the room is open and closed the rest of the time. Claude says so plainly, waits, and re-runs the same probe when the attendee says to try again. No limit on rounds; the real, unedited output every time.
- **Door C (timeout or network failure) is unchanged**, except that it no longer has a token to refuse to ask for. It is the wifi: check you are online, probe again.
- **Nothing in door B asks for a credential.** No dashboard, no token, no install command, no password, no GitHub sign-in, and no URL to sign in at. There is nothing for the attendee to fetch and nowhere to log in, so being sent to look is pure harm.

The probe still splits three ways and the door is still plumbing the attendee never needs to know about. What changed is that two of the three outcomes are now "not yet, try again" rather than "here is another way in".

The exact door B text lives in `docs/start/setup.md`, Step 2. It is written for a non-technical attendee: short sentences, no jargon, and it never implies the refusal is the attendee's fault or their access.

### 2. One live kit home

`~/claude-workshop-kit`, always. The manifest's `installPath` is always `"github"` and `kitVersion` is always the clone's HEAD commit. Every "two live doors" branch is gone: the door-choice conditional in the manifest, the crossed-door justification for the plugin-marketplace remove-first guard (the guard stays, for stale kit folders), and the rule that two of the three old kit homes could not be deleted because one might be live.

### 3. Old Loup homes stay, as MIGRATE targets

`~/.loup/selr-ai/workshop-kit` and `~/.loup/selrai-company/claude-workshop-kit` are real installs sitting on attendee laptops. They are demoted from live doors to legacy homes, and every legacy-home behaviour still finds them, exactly as it finds `~/workshop-kit`:

- **MIGRATE detection and fingerprint reconstruction** (setup prompt Step 1.2) probe all four old kit locations.
- **MIGRATE retirement** (Step 3.4) deletes all three stale download folders on the same confirmation test: a `skills/` folder plus one of the kit's own files. `~/claude-workshop-kit` is the one it must never touch, because that is the home this run just downloaded into.
- **Uninstall** keeps checking all three paths when there is no install record.

Docs call these "old Loup installs". Never a door, never a delivery path.

The `loup` shape in `scripts/make-legacy-fixture.mjs` stays for the same reason: the before-state is still real, and the standing migration check has to keep proving it migrates.

### 4. Loup's snapshot caps no longer bind the kit

`scripts/check-snapshot-shape.mjs` and its test are deleted, along with the informational snapshot-shape line `verify-conform.mjs` printed. The caps were a contract with a publisher that no longer ships this kit; a gate nobody enforces reads as coverage.

### 5. The conformance rules follow

- `verify-conform.mjs`'s two Loup path rules collapse into one: **no runtime reference to a `~/.loup/` path** outside the MIGRATE and uninstall handling. Naming a folder in order to delete it is not a door; naming one anywhere else is a reference to a channel that does not exist.
- The install-method check asserts the new door B (refused → not open yet → wait → re-probe) instead of the dashboard walkthrough.
- `check-resilient-install.mjs` keeps the shape of its contract and changes its content: the re-mint loop is replaced by wait-then-retry, and a **forbidden** set is added. No Loup surface, dashboard, token, install command, sign-in destination or unqualified credential ask anywhere in the prompt. It is checked with the two permitted legacy-home spans blanked out first, the path and its "(an old Loup install)" label, so that a violation cannot hide on the same line as a folder the prompt is telling Claude to delete.
- The install-type question patterns (`do-you-have-loup`, `github-or-loup`) stay. They are exactly the questions this retirement makes unaskable.

## What this supersedes in ADR-0001

| ADR-0001 | Superseded by |
| --- | --- |
| §1 "Two co-equal distribution paths" | One path. The public window is the only access control. |
| §1 Loup kit home `~/.loup/selr-ai/workshop-kit` | Legacy home only (§3 above). One live home, `~/claude-workshop-kit`. |
| §1 refused probe → Loup dashboard walkthrough, fresh-mint retry loop | Refused probe → "the kit is not open yet", wait, re-probe on the attendee's word. |
| §1 "the Loup door re-runs the user's install command" | Always a fresh clone. |
| §3 `"installPath": "github \| loup"` | Always `"github"`. `kitVersion` is always the clone HEAD. |
| §5 "A confirmed-stale `~/workshop-kit` is deleted" | All three stale homes are deleted on the same test. |
| Accepted gap: "a Loup-entitled user installing during a public window silently takes the GitHub path" | No entitlements. |
| Accepted gap: "`kitVersion` on the Loup door depends on what the installer reports" | No Loup door. |

Everything else in ADR-0001 stands unamended, including the accepted gap that a revoked or renamed repo is indistinguishable from a closed window at the probe. That gap now reads correctly, as "not open yet".

## Rejected alternatives

| Rejected | Why |
| --- | --- |
| Keep the Loup door as a fallback | It is the only step that can dead-end in a room where nobody answers questions, and a fallback nobody tests is a trap, not a safety net. |
| Ask the attendee to sign in to GitHub when the probe is refused | A private repo they have no access to stays private after they sign in. It teaches a credential hunt that cannot succeed. |
| Cap the retries on door B | The room opens when it opens. A cap turns "wait two minutes" into a dead end. |
| Delete the `loup` fixture shape | The before-state is still on laptops. Deleting the shape deletes the only standing proof those machines migrate. |
| Delete the old Loup homes from the uninstall fallback | Uninstall without a manifest has to find whatever is actually on disk, and for some attendees that is still a Loup install. |
| Leave the snapshot-shape check in place "just in case" | A gate against a contract nobody holds reads as coverage while enforcing nothing. |
