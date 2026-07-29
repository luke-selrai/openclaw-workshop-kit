# Issue tracker: Linear

Issues for this repo live in **Linear**, under the **Core Builds** team (`31b5d025-ec1d-4a51-983d-a811b52d7a34`). This is the only issue tracker for this repo — do not use `gh issue create` or GitHub Issues for anything triage/spec/ticket related, even though the repo is hosted on GitHub.

Use the `mcp__linear__*` tools for all operations.

## Conventions

- **Create an issue**: `mcp__linear__save_issue` with `team: "Core Builds"`, `title`, and `description` (Markdown, literal newlines — not escape sequences). Omit `id`.
- **Read an issue**: `mcp__linear__get_issue` with the issue identifier (e.g. `COR-123`).
- **List issues**: `mcp__linear__list_issues` with `team: "Core Builds"`, filtered by `label`, `state`, `assignee` as needed.
- **Comment on an issue**: `mcp__linear__save_comment` with `issueId` and `body`.
- **Apply / remove labels**: `mcp__linear__save_issue` with `id` set and `labels` — this **replaces the full label set**, so pass the complete list of labels the issue should end up with, not just the ones being added.
- **Change status**: `mcp__linear__save_issue` with `id` and `state` (e.g. `"Done"`, `"Canceled"`, `"Todo"`, `"In Progress"`, `"In Review"`, `"Backlog"`, `"Duplicate"` — see `mcp__linear__list_issue_statuses` for the live list).
- **Close** (as "won't fix" or done): set `state` to `"Canceled"` or `"Done"` via `save_issue`, plus a closing comment via `save_comment` if context is useful.

## Pull requests as a triage surface

**PRs as a request surface: no.** This repo's PRs stay on GitHub as normal code review; they are not pulled into Linear triage.

## When a skill says "publish to the issue tracker"

Create a Linear issue under the Core Builds team via `mcp__linear__save_issue`.

## When a skill says "fetch the relevant ticket"

Run `mcp__linear__get_issue` with the issue identifier.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map` (create the label via `mcp__linear__create_issue_label` if it doesn't yet exist on the Core Builds team), holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: create via `save_issue` with `parentId` set to the map's issue ID — Linear's native sub-issue relationship. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, set `assignee` to the driving dev (`"me"` if the agent is claiming it).
- **Blocking**: use `blockedBy` / `blocks` on `save_issue` — Linear's native issue relations. These are append-only via the tool; use `removeBlockedBy` / `removeBlocks` to clear one.
- **Frontier query**: `list_issues` with `parentId` set to the map's ID and `state` open, then drop any with an open blocker or an existing `assignee`; first in map order wins.
- **Claim**: `save_issue` with `id` and `assignee: "me"` — the session's first write.
- **Resolve**: `save_comment` with the answer, then `save_issue` with `state: "Done"`, then append a context pointer (gist + link) to the map's Decisions-so-far.
