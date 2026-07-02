# Agents Master Guide

The full agent landscape — read this before scaffolding to understand the whole picture. It is the conceptual + lifecycle companion to `subagent-reference.md` (the CLI/frontmatter mechanics quick-ref). For the full frontmatter field table, scopes, and model-resolution order, see `subagent-reference.md`; this guide does not repeat them.

Sources: Claude Code subagents (https://code.claude.com/docs/en/sub-agents), Agent SDK subagents (https://code.claude.com/docs/en/agent-sdk/subagents), background agents (https://code.claude.com/docs/en/agent-view), agent teams (https://code.claude.com/docs/en/agent-teams).

## 1. The agent landscape — three runtimes

Never conflate these. They differ on scope, nesting, and whether the workers talk to each other.

| Concept | Scope | Can nest? | Communicate? | Use when | Docs |
|---|---|---|---|---|---|
| **Subagents** | One session, fresh isolated context | No — a subagent cannot spawn a subagent | No | A specialist Claude delegates one self-contained task to and gets a summary back | /en/sub-agents |
| **Background agents** | Many independent sessions, run unattended | Each is its own session | No (independent) | Many separate jobs running on their own, monitored later from one place | /en/agent-view |
| **Agent teams** | Multiple sessions that coordinate | Sessions, not nested subagents | Yes — `SendMessage` / resume | Workers must hand off, react to, or build on each other's output | /en/agent-teams |

Decision: one delegated task → subagent. Many parallel jobs you check on later → background agents. Jobs that must coordinate → agent teams (set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).

When workers must message each other, the mechanism is **native agent teams**: enable the env flag and teammates communicate through native `SendMessage`. Build this first for "talk to each other / hand off / coordinate." A file-based shared-log pattern (orchestrator and workers read/write one log file) is the **fallback** only when the flag isn't set — don't hand-roll it as the default.

## 2. Built-in subagents — don't recreate these

| Agent | Model | Behavior |
|---|---|---|
| **Explore** | Haiku | Fast read-only codebase search; skips CLAUDE.md + git snapshot |
| **Plan** | inherit | Read-only research during plan mode |
| **general-purpose** | inherit (all tools) | Multi-step tasks needing exploration + action |

`general-purpose` can be spawned without defining anything — use it for ad-hoc delegation before deciding a custom agent is warranted. Build a custom subagent only when these three don't fit the role.

## 3. Three ways to create a custom subagent

| Path | Loads | Restart? | Use when |
|---|---|---|---|
| **`/agents` interactive** | Immediately | No | The user wants to pick tools/model/color themselves |
| **Filesystem markdown** in `.claude/agents/` (project) or `~/.claude/agents/` (user) | At session start | Yes | Scaffolding for someone — Claude makes every choice, user's only step is a restart |
| **SDK `agents` param / `--agents` JSON** | Session only (programmatic) | n/a | Embedding agents in an app, not the CLI flow most workshop users want |

Precedence when names collide: programmatic/managed > CLI flag > project (`.claude/agents/`) > user (`~/.claude/agents/`) > plugin. Full scope table in `subagent-reference.md`.

## 4. What a subagent inherits at startup

A non-fork subagent starts fresh. The delegation prompt is the **only** parent→child channel — put file paths, error text, and decisions there.

**Receives:**
- Its own system prompt (the body) + environment details
- The delegation / `Agent`-tool prompt Claude writes at handoff
- CLAUDE.md / memory hierarchy (Explore and Plan skip this)
- A git-status snapshot
- Any skills named in `skills` (full content preloaded)

**Does NOT receive:**
- Parent conversation history
- Parent tool results or already-read files
- Parent system prompt
- Skill content that wasn't preloaded via `skills`

## 5. Invocation

- **Automatic** — Claude matches the request against the `description`. Sharpen it if delegation isn't firing.
- **Natural language by name** — "Use the test-runner subagent to fix failing tests."
- **@-mention** — `@"code-reviewer (agent)"` forces that specific agent for one task.
- **Whole session** — `claude --agent code-reviewer`, or `"agent": "code-reviewer"` in `.claude/settings.json`.
- **SDK** — include `Agent` in `allowedTools` so subagent invocations auto-approve.

## 6. Lifecycle

- **Background vs foreground** — `background: true` runs a subagent as a non-blocking task; foreground blocks the main thread until it returns.
- **Resume** — subagents retain their full transcript. Resume via `SendMessage` (teams) or the SDK `resume: sessionId` plus the agent id. Transcripts persist separately from the main conversation and are cleaned per `cleanupPeriodDays` (default 30).
- **Auto-compaction** — a subagent compacts its own context around ~95% capacity, so long-running agents keep going without manual intervention.

## 7. Fork mode (experimental)

Set `CLAUDE_CODE_FORK_SUBAGENT=1`. A forked subagent **inherits the full parent conversation** instead of starting fresh, and is cheaper because it shares the parent's prompt cache.

- **Forked subagent** — sees everything the parent saw; use when a fresh agent would need so much background that the delegation prompt becomes unwieldy.
- **Named (non-fork) subagent** — clean isolated context; use when the task is self-contained and a sharp prompt body is enough. This is the default and the right choice for most scaffolding.

## 8. Choosing the shape

Pick the shape (single / chain / parallel / orchestrator / team / background) using the Step-4 table in `SKILL.md` — not repeated here. One-line guard: **default to a single agent; add a second only when the work splits cleanly, and reach for an orchestrator or team only when coordination itself is the work.**

## 9. Tool and permission restrictions

- **`tools`** is an allowlist; **`disallowedTools`** is a denylist. When both are set, `disallowedTools` is applied first, then `tools`.
- **Never available to subagents** (even if listed): `Agent`, `AskUserQuestion`, plan-mode tools (`EnterPlanMode`/`ExitPlanMode` unless `permissionMode: plan`), and a few UI-bound tools. A subagent **cannot spawn another subagent**.
- **Map permissions to role:** researcher / reviewer / security-reviewer → read-only (`Read, Grep, Glob`); tester → `Read, Bash`; implementer → `Read, Edit, Write`.
- **Durable memory without broad write:** to let an agent remember across sessions, set the `memory:` frontmatter field (`user`/`project`/`local`). It provisions a managed memory dir and auto-scopes Read/Write to that dir — so a read-only role keeps notes without you granting codebase `Edit`/`Write`. Don't widen file tools just to give an agent a scratchpad. Field detail in `subagent-reference.md`.
- For finer control than allow/deny lists, use a `PreToolUse` hook to validate calls (e.g. block SQL writes). On Windows, write the hook in PowerShell and add `shell: powershell`.

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Claude won't delegate | `description` says *what* not *when* | Rewrite as a trigger ("Use proactively when…") |
| Claude won't delegate | `Agent` tool not approved | Name the agent explicitly, or include `Agent` in `allowedTools` (SDK) |
| Claude won't delegate | Task doesn't clearly match | Name the agent explicitly in the prompt |
| New agent not picked up | File added mid-session | Restart the session (or create via `/agents` for no restart) |
| Prompt truncated on Windows | 8191-char command-line limit | Keep the prompt concise, or use a filesystem agent instead of `--agents` JSON |

## SDK minimal definition

The Agent SDK defines agents via the `agents` parameter using `AgentDefinition` — same fields as frontmatter:

```ts
agents: {
  "code-reviewer": {
    description: "Reviews code for bugs and security. Use immediately after edits.",
    prompt: "You are a senior code reviewer. Report issues by priority.",
    tools: ["Read", "Grep", "Glob"],
    model: "inherit",
  },
}
```

Programmatic definitions take precedence over filesystem agents of the same name. Use this path only when embedding agents in an app.
