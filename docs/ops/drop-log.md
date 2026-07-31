# Drop log

A record of every school-community drop: each temporary window during which this repo was public, and **which commit** was served while it was.

## Why this file exists

The GitHub distribution path has no install-time record on our side. There is no token minted, no account created, no telemetry - a public window is the access control (ADR-0001 §1), and people clone anonymously. Once the window closes, the only evidence a drop happened is this file.

That matters at migration time. When the kit's install model changes, the question is always "which version do legacy users have?" - and for anyone who arrived through a school drop, the answer is the commit recorded here, not `main`. Without a commit pinned per window, that question is unanswerable and migration has to guess.

It is written by the `school-drop` skill (Phase 6, after the window closes), not by hand. That skill is Harvey-internal and never ships to attendees, so it is not in this repo - it lives in the workspace-global skills tree at `~/selrai/.claude/skills/school-drop/`. This log is the part of the ritual that belongs in the repo, because the record has to outlive any one machine.

## Entry format

Newest first. One entry per window. Copy the shape below; the values in it are placeholders illustrating the format, not a record of a drop.

```
## YYYY-MM-DD - <destination>

- Commit served: `<full 40-char sha>` (`<short sha>`)
- Window: `<open ISO-8601>` to `<close ISO-8601>`
- Agreed duration: <e.g. 48 hours> | Actual: <e.g. 49h 12m>
- Announcement: <where it was posted>
- Notes: <anything worth carrying forward, or "none">
```

Notes worth recording: more than one commit served (a push landed mid-window - list every commit), a close that overran the agreed duration, or a problem people hit while the window was open.

## Drops

## 2026-07-31 - Skool community live call

- Commit served: `b91a45b87561dd08efff641ecc02492ed79f4ed9` (`b91a45b`)
- Window: `2026-07-31T01:30:00Z` (approximate - opened by hand shortly before the call; not captured to the second) to `2026-07-31T03:40:51Z`
- Agreed duration: one live session | Actual: ~2h 10m
- Announcement: none posted - the prompt was shared directly during the live call, not via a written post
- Notes: first drop under the pointer-block install model (ADR-0001). One commit served for the whole window. Flip-private verified by the credential-free probe (repo refused, control green) plus authenticated visibility check. Open timestamp is approximate because the flip was done manually outside the school-drop skill; future windows should run the skill so both timestamps are captured exactly.
