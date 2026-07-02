# Changelog

## [2.0.3] - 2026-05-29

### Added
- **Windows agent-teams handoff note** in `SKILL.md` Step 7: when a native agent team is set up, the handoff must tell the user that agent teams are experimental and that on Windows the side-by-side panes only appear under WSL + tmux — in plain Windows Terminal there are no panes and teammates are cycled with Shift+Down. Offers to help set up WSL + tmux. Prevents non-technical Windows users from thinking the team failed because they see no panes.
- **`references/windows-agent-teams-setup.md`** — plain-English numbered walkthrough to get the side-by-side panes working on Windows 11 (install WSL → open Ubuntu → install tmux → install Node + Claude Code in WSL → set the agent-teams flag and run Claude Code inside tmux → reach Windows files under `/mnt/c/`). Step 7's Windows note links to it.

## [2.0.2] - 2026-05-29

QA-driven fix from a live B6 run ("several agents running for hours, each keeping its own memory and talking to each other"), where the assistant hand-rolled a file-based orchestration and missed two native features.

### Changed
- **Step-4 "Agent team" row + disambiguation** now steer to **native Claude Code agent teams** (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, native `SendMessage` between teammates) as the first-class path for workers that message each other; the file-based shared-log pattern is named as the fallback when the flag isn't enabled, not the default.
- `agents-master-guide.md` three-runtime section makes the same native-teams-first / shared-log-fallback distinction explicit.

### Added
- **Persistent-memory note** in `SKILL.md` and `agents-master-guide.md`: set `memory: user|project|local` to give an agent durable cross-session memory. It auto-scopes Read/Write to a managed memory dir, so read-only roles keep notes without being granted codebase `Edit`/`Write` — closing the least-privilege regression from the QA run.
- `subagent-reference.md` `memory` field row clarified to note it auto-scopes Read/Write to the memory dir (no broad file tools needed).

## [2.0.1] - 2026-05-29

Refocus, accuracy, and non-technical-UX pass. Scopes the skill to what it actually owns (custom subagents + agent teams), routes cleanly against its siblings, and guarantees a usable handoff to non-technical users. Targets the vetting weaknesses: trigger fidelity, differentiation, evidence.

### Added
- `references/subagent-reference.md` — authoritative Claude Code mechanics from the official docs: full frontmatter field table, scopes/locations, `/agents`, tool restrictions, model resolution, invocation, what loads at startup, agent teams.
- `references/agents-master-guide.md` — conceptual + lifecycle master reference: the three runtimes (subagents / background agents / agent teams), built-in subagents, the three creation paths and their precedence, what a subagent inherits at startup, invocation, lifecycle (background/foreground, resume, auto-compaction), fork mode, tool/permission restrictions, and troubleshooting (including the Windows 8191-char prompt limit). Defers to `subagent-reference.md` for the field table.
- `TEST-PLAN.md` — QA scenarios covering routing/firing, agent-shape selection, the non-technical handoff, and edge cases.
- Routing table as the first SKILL.md section + a subagent-vs-skill explainer for zero-knowledge users.
- **Golden rule** (one responsibility, small context, clear success criteria, minimal permissions) as the top design principle.
- **"Which agent shape?" decision table** (single / chain / parallel / orchestrator / agent team / background) with a guard rule that defaults to a single agent, plus a "Pick me when" line above each of the three templates.
- **Step 7 — hand off to the user**: after scaffolding, give the invocation phrase with the real name, a ready-to-paste first prompt, the one restart action, and a one-line scope. Worked db-optimizer handoff block in `creation-process.md`.
- Worked `db-optimizer.md` example (a complete, valid agent produced by the 7-step workflow) — the verifiable evidence of what the process outputs.
- **Repo-recon** snippet for coding agents (read similar files → reuse patterns → avoid needless abstractions), baked into the Technical Expert template.
- Role roster table, **minimal four-agent starter team**, and the **build/review split** pattern (implementer → reviewer → security-reviewer → tester) in the Agent teams section.
- **"Skip the subagent for"** routing note (tiny edits, quick fixes, iterative work, shared evolving context).
- **Instruction overload** anti-pattern (~10–40 line bodies); tool/model selection table with a role→permissions mapping and a `bypassPermissions` caution.

### Changed
- Refocused the skill on **custom Claude Code subagents and agent teams** (the `.claude/agents/` markdown files) — what it owns versus its siblings.
- Rewrote the frontmatter `description` to route by user phrasing with a symmetrical NOT-clause: inline prompt/slash-command/workflow → `skill-creator`; external API/tool/database → `mcp-creator`. Added team/parallel/orchestrate trigger phrases.
- Rewrote the three templates as complete, valid `.claude/agents/` files (frontmatter + body).
- Replaced dead `pairs-with` references (`skill-coach`, `skill-documentarian`) with real skills (`skill-creator`, `mcp-creator`, `advanced-skill-builder`).
- "Two ways to create one" now frames filesystem authoring as the default for non-technical users (Claude makes every choice; the user's only step is a one-time restart) and `/agents` as the pick-options path.
- Renamed Step 4 to "Choose the agent shape"; folded the handoff into Step 7 (removed the confusing "7b"); fixed section ordering and internal contradictions.
- Clarified that `Agent(...)` is valid only on a main-thread orchestrator run via `claude --agent`; subagents never receive the `Agent` tool.
- Thinned `references/mcp-integration.md` to a pointer to `mcp-creator` plus how to wire an existing MCP server into an agent.
- Added a parallel-edit hazard note (separate scopes / `isolation: worktree` / sequential merge).

### Removed
- The unverified "~45 minutes" time claim — the 7-step workflow now uses **Effort** labels (light/medium/heavy), and the worked example carries the evidence instead of a minutes total.

## [2.0.0] - 2024-01-XX

### Changed
- **BREAKING**: Restructured from monolithic 602-line file to progressive disclosure architecture
- Fixed frontmatter format: `tools:` → `allowed-tools:` (comma-separated)
- Added NOT clause to description for precise activation boundaries
- Reduced SKILL.md from 602 lines to 150 lines (75% reduction)

### Added
- `references/agent-templates.md` - Technical Expert, Creative/Design, Orchestrator templates
- `references/mcp-integration.md` - MCP server template, official packages, creation steps
- `references/creation-process.md` - Rapid prototyping workflow, quality checklist
- Anti-patterns section with "What it looks like / Why wrong / Instead" format
- Quick reference table for agent templates
- 45-minute rapid prototyping workflow

### Removed
- Verbose template descriptions (moved to references)
- Inline MCP server code (moved to references)
- Redundant design philosophy sections

### Migration Guide
Reference files are now in `/references/` directory. Import patterns:
- Agent templates → `references/agent-templates.md`
- MCP server code → `references/mcp-integration.md`
- Creation workflow → `references/creation-process.md`
