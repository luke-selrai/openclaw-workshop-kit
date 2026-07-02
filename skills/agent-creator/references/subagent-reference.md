# Subagent Reference (Claude Code mechanics)

Authoritative quick-reference for how custom subagents actually work in Claude Code. Source: https://code.claude.com/docs/en/sub-agents and https://code.claude.com/docs/en/agent-sdk/subagents.

## File format

A subagent is a markdown file: YAML frontmatter (config) + body (system prompt).

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices. Use immediately after edits.
tools: Read, Glob, Grep
model: sonnet
---

You are a code reviewer. When invoked, analyze the changes and provide
specific, actionable feedback on quality, security, and best practices.
```

The body **replaces** the default system prompt for that agent — the subagent does not inherit Claude Code's main system prompt. Only `name` and `description` are required.

## Frontmatter fields

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Lowercase + hyphens, unique across the whole agents tree. Identity comes from this, not the filename. |
| `description` | Yes | **When** Claude should delegate here. This is what delegation matches on — write it as a trigger, and add "use proactively"/"use immediately after…" to encourage auto-delegation. |
| `tools` | No | Allowlist, comma-separated (`Read, Grep, Glob`). Omit to inherit all tools. To preload skills use `skills`, not `Skill` here. |
| `disallowedTools` | No | Denylist, removed from the inherited/specified set. If both set: `disallowedTools` applied first, then `tools`. |
| `model` | No | `sonnet`, `opus`, `haiku`, a full ID (`claude-opus-4-8`), or `inherit`. Defaults to `inherit`. |
| `permissionMode` | No | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`. Ignored for plugin subagents. |
| `skills` | No | Skill names to preload (full content injected at startup). |
| `mcpServers` | No | MCP servers for this subagent: a name referencing a configured server, or an inline definition. |
| `memory` | No | `user` / `project` / `local` — gives the agent a persistent memory dir for cross-session learning. Auto-scopes Read/Write to that dir, so it needs no broad file tools to keep notes. |
| `maxTurns` | No | Cap on agentic turns. |
| `effort` | No | `low`/`medium`/`high`/`xhigh`/`max` — overrides session effort. |
| `background` | No | `true` runs it as a non-blocking background task. |
| `isolation` | No | `worktree` runs it in a temporary git worktree (isolated copy of the repo). |
| `color` | No | UI color: red, blue, green, yellow, purple, orange, pink, cyan. |
| `hooks` | No | Lifecycle hooks scoped to this subagent (`PreToolUse`, `PostToolUse`, `Stop`). |

## Scopes / where the file goes

Higher priority wins when names collide.

| Location | Scope | Priority |
|---|---|---|
| Managed settings dir | Organization-wide | 1 (highest) |
| `--agents` CLI flag (JSON) | Current session only | 2 |
| `.claude/agents/` | Current project (check into VCS) | 3 |
| `~/.claude/agents/` | All your projects | 4 |
| Plugin `agents/` dir | Where plugin enabled | 5 (lowest) |

Both `.claude/agents/` and `~/.claude/agents/` are scanned recursively — subfolders (e.g. `agents/review/`) are fine and don't change the agent's identity.

## Two creation paths

- **`/agents` command** — Library tab → Create new agent → choose Personal (`~/.claude/agents/`) or Project (`.claude/agents/`) → Generate with Claude → pick tools/model/color/memory → save. Takes effect immediately.
- **Write the file directly** — loads at session start; restart the session to pick up new/edited files. (`/agents`-created agents need no restart.)

## Tool restrictions

| Use case | tools |
|---|---|
| Read-only analysis | `Read, Grep, Glob` |
| Test execution | `Bash, Read, Grep` |
| Code modification | `Read, Edit, Write, Grep, Glob` |
| Full access | omit the field |

Never available to subagents (even if listed): `Agent`, `AskUserQuestion`, `EnterPlanMode`, `ExitPlanMode` (unless `permissionMode: plan`), `ScheduleWakeup`, `WaitForMcpServers`. **A subagent cannot spawn another subagent.**

For finer control than allow/deny lists, use a `PreToolUse` hook to validate calls (e.g. block SQL writes). On Windows, write hook scripts in PowerShell and add `shell: powershell` to the hook entry.

## Model resolution order

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var
2. Per-invocation `model` parameter Claude passes
3. The definition's `model` frontmatter
4. The main conversation's model

Route high-volume/low-stakes work to `haiku` for speed and cost; reserve `opus` for high-stakes reasoning.

## Invocation

- **Automatic** — Claude delegates based on the `description`. Sharpen it if delegation isn't firing.
- **Natural language** — "Use the test-runner subagent to fix failing tests."
- **@-mention** — `@"code-reviewer (agent)"` forces that specific agent for one task.
- **Whole session** — `claude --agent code-reviewer` runs the main thread as that agent; or set `"agent": "code-reviewer"` in `.claude/settings.json`.

## What loads into a subagent at startup

A non-fork subagent starts fresh — it does **not** see the parent conversation, prior tool results, or already-read files. It receives:

- Its own system prompt (the body) + environment details
- The delegation prompt Claude writes when handing off (the only parent→child channel — put file paths, errors, decisions here)
- `CLAUDE.md` / memory hierarchy (built-in Explore and Plan skip this)
- A git-status snapshot
- Any skills named in `skills`

So: anything the subagent must know has to be in its prompt body or in the delegation message.

## Built-in subagents (don't recreate these)

| Agent | Model | Purpose |
|---|---|---|
| Explore | Haiku | Fast read-only codebase search |
| Plan | inherit | Read-only research during plan mode |
| general-purpose | inherit | Multi-step tasks needing exploration + action |

## Agent teams

Three runtimes, kept distinct: **subagents** = one session, fresh isolated context, can't nest; **background agents** = many independent sessions run unattended and monitored from one place (https://code.claude.com/docs/en/agent-view); **agent teams** = sessions that communicate via `SendMessage`/resume (https://code.claude.com/docs/en/agent-teams, needs `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Pick teams only when workers must coordinate.

Subagents work within a single session and can't nest. For multiple coordinated workers:

- **Chain / parallel from the main conversation** — see SKILL.md "Agent teams".
- **Claude Code agent teams** (sustained parallelism, workers with independent context, inter-agent messaging) — https://code.claude.com/docs/en/agent-teams. A subagent definition's `tools` and `model` are reused when it's spawned as a teammate.

## Common failure: Claude won't delegate

1. The `description` says *what* it is, not *when* to use it — rewrite as a trigger.
2. The task doesn't clearly match — name the agent explicitly in the prompt.
3. New file added on disk mid-session — restart to load it.

## SDK note (programmatic agents)

The Agent SDK defines agents via the `agents` parameter of `query()` (TS) / `ClaudeAgentOptions` (Python) using `AgentDefinition` — same fields as frontmatter (`description`, `prompt`, `tools`, `model`, `skills`, etc.). Include `Agent` in `allowedTools` so subagent invocations auto-approve. Programmatic definitions take precedence over filesystem agents of the same name. Use this path when embedding agents in an app rather than the Claude Code CLI.
