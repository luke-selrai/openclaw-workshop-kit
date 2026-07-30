---
name: agent-creator
description: "Designs and scaffolds Claude Code subagents and agent teams in .claude/agents/. Use when the user wants a custom subagent, a domain-expert agent, or parallel specialists - not an inline prompt (skill-creator) or an MCP server (mcp-creator)."
allowed-tools: Read,Write,Edit,Glob,Grep,Bash,WebFetch
metadata:
  category: Productivity & Meta
  pairs-with:
  - skill: skill-creator
    reason: When the user wants a skill (reusable prompt) rather than a delegated agent
  - skill: mcp-creator
    reason: When the agent needs an external tool integration (MCP server)
  - skill: advanced-skill-builder
    reason: Interactive, dialogue-driven skill authoring
  tags:
  - agents
  - subagents
  - agent-teams
  - claude-code
  - meta
  - skill-development
---

# Agent Creator

Designs and scaffolds custom **Claude Code subagents** - specialized AI assistants defined as markdown files in `.claude/agents/` that Claude automatically delegates matching tasks to. Each runs in its own context window with a focused system prompt, restricted tools, and an optional cheaper/faster model. This skill also covers wiring several subagents into an **agent team**.

## Route first - am I the right skill?

Match the user's actual goal before scaffolding anything:

| The user wants… | Use | Why |
|---|---|---|
| A specialist Claude **delegates a task to** ("review my code", "research X"), running in its own context | **agent-creator** (this skill) | Subagents isolate context and can be tool-restricted |
| Several specialists coordinating on one job | **agent-creator** → [Agent teams](#agent-teams) | Teams are subagents wired together |
| A reusable **prompt or workflow** that runs in the *main* conversation ("/changelog", "summarize this doc my way") | **skill-creator** | Skills aren't delegated; they run inline |
| Hand-held, dialogue-driven skill authoring | **advanced-skill-builder** | Interactive requirements → skill |
| An **MCP server** - connecting Claude to an external API/tool/database | **mcp-creator** | MCP is a protocol, not an agent |

Subagent vs. skill is the common mix-up: **subagent = a worker Claude hands a self-contained task to and gets a summary back; skill = instructions Claude follows itself.** If the answer should leave the main conversation's context, it's an agent.

New to the agent landscape (subagents vs background agents vs agent teams, built-ins, creation paths, lifecycle, fork mode)? Read `references/agents-master-guide.md` first to understand the whole picture before scaffolding.

**Skip the subagent for:** tiny edits, fast quick fixes, highly iterative back-and-forth, and tasks needing shared evolving context. A subagent starts fresh with no shared context and adds handoff overhead - for these, just do the work inline.

## The golden rule

A good subagent has **one responsibility, small context, clear success criteria, and minimal permissions**. The more focused the agent, the better the output. Every design choice below serves this - when in doubt, narrow the scope.

## What a subagent actually is (zero-knowledge primer)

A subagent is one markdown file. The YAML frontmatter is its config; the body is its system prompt.

```markdown
---
name: code-reviewer
description: Expert code review specialist. Use immediately after writing or modifying code.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior code reviewer ensuring high standards of quality and security.
When invoked, run git diff, focus on changed files, and report issues by priority.
```

- Drop this file in `.claude/agents/` (this project) or `~/.claude/agents/` (all your projects).
- Claude reads the **`description`** to decide when to delegate - this is the single most important field. Write it as *when to use me*, not *what I am*.
- The user can also force it: "Use the code-reviewer agent to…".

Full field reference, scopes, and invocation rules: **`references/subagent-reference.md`**.

## Two ways to create one

1. **`/agents` command (interactive).** In Claude Code, run `/agents` → Library → Create new agent → Generate with Claude. It generates the name, description, and prompt, lets you pick tools/model/color, and saves the file. Takes effect immediately, no restart.
2. **Write the file by hand** (this skill's default when scaffolding for someone). Files added directly to disk load at session start - tell the user to restart their session.

When building for a non-technical user, prefer writing the file directly: it lets Claude make every tool/model/scope choice, so the user's only step is a one-time restart. Use `/agents` only when the user wants to pick options themselves.

## The 7-step design workflow

Apply this whether using `/agents` or writing the file directly. The Effort column is rough relative weight and ordering, not a time guarantee.

| Step | Effort | Activity | Output |
|---|---|---|---|
| 1. Understand the need | light | What task keeps recurring? What should leave the main context? | One-sentence job statement |
| 2. Design the persona | light | What expert would own this? Role, depth, voice | `description` + opening line of the prompt |
| 3. Map the knowledge | heavy | What must it know - frameworks, checklists, pitfalls? Curate, don't dump | Body sections |
| 4. Choose the agent shape | medium | One agent / chain / team / orchestrator, then a template (`references/agent-templates.md`) | Frontmatter + body skeleton |
| 5. Restrict tools + model | light | Least privilege. Read-only? Needs Bash? Cheap model for high-volume work? | `tools`, `model` fields |
| 6. Add concrete examples | medium | Runnable examples / a worked checklist in the body | Body examples |
| 7. Test, refine, and hand off | medium | Invoke by name, watch it work, tighten the description; then hand the user the invocation phrase + a first example | Verified agent the user can run |

A worked end-to-end run (database-optimization agent, real file output) is in `references/creation-process.md` - use it to show a user exactly what the workflow produces.

Two steps get an expanded section below because they carry the decisions: **Step 4 - which agent shape?** and **Step 7 - hand off to the user**.

## Step 4 - which agent shape?

Pick the shape before the template. The template (Technical / Creative / Orchestrator) fills in *one* agent; the shape decides *how many* and how they relate.

| The work looks like… | Shape | Build |
|---|---|---|
| One self-contained job for one specialist | **Single agent** | One file (Technical or Creative template) |
| A pipeline - output of A is input to B | **Chain** | Two+ single agents; the main conversation runs them in sequence |
| Independent investigations that merge at the end | **Parallel set** | Two+ single agents; the main conversation fans out, then synthesizes |
| Coordination *is* the work - routing, conflict resolution, integration | **Orchestrator** | An orchestrator agent (Orchestrator template) over worker agents |
| Long-lived workers that hold their own context and message each other | **Agent team** | Native Claude Code [agent teams](https://code.claude.com/docs/en/agent-teams) (set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; teammates talk via native `SendMessage`). Fallback when the flag isn't enabled: a shared-log file the orchestrator and workers read/write. |
| Many independent jobs running unattended, checked later from one place (no inter-agent talk) | **Background agents** | Claude Code [background agents](https://code.claude.com/docs/en/agent-view) |
| You're unsure | **Single agent** | Start here; split later if the work clearly forks |

**Guard rule:** Default to a single agent. Add a second only when the work splits cleanly; reach for an orchestrator/team only when coordination itself is the work.

**Background agents vs agent teams:** background = many independent sessions you monitor; teams = sessions that message each other. Pick teams only when they must coordinate. For "talk to each other," reach for native agent teams first; the shared-log file is the fallback path when the env flag isn't set.

Patterns and an orchestrator skeleton are in `references/agent-templates.md`; chain/parallel mechanics are under [Agent teams](#agent-teams).

## Step 7 - hand off to the user

Always do this when you wrote the file for someone. After scaffolding, give the user a copy-the-shape handoff so a non-technical person can use the agent immediately:

1. **Invocation phrase**, filled with the real name: *"Use the `<name>` agent to …"*.
2. **A ready-to-paste first prompt** specific to their need (a real example, not a placeholder).
3. **The one action they must take**, stated as what-to-do: *"I've created it - restart this session once and it's ready"* (or *"It's live now, no restart needed"* if you used `/agents`).
4. **Scope**, one line: what it will do and what it won't.

**If you set up a native agent team, add this to the handoff:** agent teams are **experimental**, and the agents run and coordinate fine - but on **Windows** the side-by-side panes only show under **WSL + tmux**. In plain Windows Terminal you won't see panes; cycle through teammates with **Shift+Down** instead. Say this plainly so the user isn't confused when no panes appear, and offer to help set up WSL + tmux (or an equivalent) if they want the visual view. (Mac/Linux show the panes natively.) Full setup walkthrough in `references/windows-agent-teams-setup.md`.

## Choosing tools and model

Least privilege keeps agents safe and focused. Common combinations:

| Use case | tools | model |
|---|---|---|
| Read-only analysis / review | `Read, Grep, Glob` | `inherit` or `sonnet` |
| Test running / scripts | `Bash, Read, Grep` | `inherit` |
| Code modification | `Read, Edit, Write, Grep, Glob` | `inherit` |
| High-volume search / triage | `Read, Grep, Glob` | `haiku` (faster, cheaper) |
| Full access | omit `tools` | `inherit` |

Map permissions to the agent's **role**: researcher / reviewer / security-reviewer → read-only (`Read, Grep, Glob`); tester → `Read, Bash`; implementer → `Read, Edit, Write`. Anthropic warns against overusing `bypassPermissions` - grant the narrowest set the role needs.

`Agent`, `AskUserQuestion`, and a few UI-bound tools are never available to subagents - and a subagent **cannot spawn another subagent**. For nested delegation, chain subagents from the main conversation or use an agent team.

**Persistent memory.** For an agent that must remember across sessions, set `memory: user|project|local` in its frontmatter. This gives the agent a managed memory dir and auto-scopes Read/Write to *that dir only* - so a read-only role (researcher, reviewer) keeps its notes without you granting codebase `Edit`/`Write`. Use `memory:` for durable notes; reserve `Edit`/`Write` for agents that actually change project files. Detail in `references/subagent-reference.md` and `references/agents-master-guide.md`.

## Coding agents: open with repo recon

Most agents fail by acting too early. Every implementation/coding agent body should start its workflow with a recon step - drop this in verbatim:

```
Before writing code:
1. Read similar files to learn the conventions.
2. Reuse existing patterns and utilities.
3. Avoid new abstractions unless clearly necessary.
```

The Technical Expert template already carries this.

## Agent templates

Each template in `references/agent-templates.md` ships with valid `.claude/agents/` frontmatter:

| Template | Best for | Key elements |
|---|---|---|
| **Technical Expert** | Domain specialists (DBA, security, perf) | Problem-solving framework, checklists, code examples, restricted tools |
| **Creative/Design** | Copy, UX, naming, design critique | Design philosophy, process, quality bar |
| **Orchestrator** | Coordinating a multi-step job | Delegation strategy, integration, QA |

## Agent teams

When one job needs several specialists working together (not just one delegation), build a team: a set of subagent files plus an orchestrator that delegates to them. Two patterns:

- **Chain** - main conversation runs agents in sequence: "Use `code-reviewer` to find issues, then `optimizer` to fix them." Each returns a summary that feeds the next.
- **Parallel** - independent investigations run at once: "Research auth, database, and API modules in parallel using separate subagents," then Claude synthesizes.

**Separate implementation from review.** Quality jumps when build and check are different agents: `implementer → reviewer → security-reviewer → tester`. One agent grading its own work is the weakest link. Standard role roster to draw from:

| Role | Owns | Permissions |
|---|---|---|
| planner | breaks the job into steps | read-only |
| researcher | gathers context, conventions | read-only |
| implementer | writes the change | `Read, Edit, Write` |
| reviewer | correctness, style | read-only |
| security-reviewer | vulnerabilities, secrets | read-only |
| tester | runs tests, reports failures | `Read, Bash` |
| refactorer | cleanups after green | `Read, Edit, Write` |

**Minimal starter team:** planner, implementer, tester, reviewer. Ship those four and add roles only when a gap shows up - don't build the full roster up front.

**Parallel-edit hazard:** multiple agents editing the same files at once cause conflicts. Give each a separate file scope, run them in a git worktree (`isolation: worktree`, see `references/subagent-reference.md`), or merge sequentially.

For sustained parallelism beyond a single session, point the user at Claude Code's [agent teams](https://code.claude.com/docs/en/agent-teams) feature. Design patterns and an orchestrator skeleton are in `references/agent-templates.md`.

## When to use

**Use for:**
- Creating a new domain-expert subagent
- Designing an agent team or orchestrator ("orchestrate these agents", "coordinate specialists on one job")
- Running several specialists in parallel or as a chain ("research these modules in parallel", "review then fix")
- Turning a recurring "go research/check/triage this" task into a reusable delegated worker

**Do NOT use for:**
- A reusable prompt / slash-command / workflow that runs inline → **skill-creator** / **advanced-skill-builder**
- Connecting Claude to an external API, tool, or database → **mcp-creator**
- Invoking an agent that already exists (just name it in your prompt)
- General coding (use the language-specific skill)

## Anti-patterns

### Knowledge dump
**Looks like**: pasting whole docs into the body.
**Why wrong**: bloats context, poor retrieval.
**Instead**: curate the essential checklist; link out for depth.

### Vague persona / grandiose name
**Looks like**: "You are a helpful expert assistant" named `super-programmer` or `ultimate-agent`.
**Why wrong**: generic outputs, weak delegation matching; a generalist name signals an unfocused scope.
**Instead**: a narrow role name (`react-ui-engineer`, `postgres-optimizer`, `security-reviewer`) + specific role + when-to-use `description`.

### Instruction overload
**Looks like**: a 500-line body packed with every rule you can think of.
**Why wrong**: Claude starts ignoring rules under context overload, so consistency drops.
**Instead**: ~10-40 lines of concrete rules + a clear workflow. Cut anything not load-bearing.

### Description that says *what*, not *when*
**Looks like**: `description: A code reviewer.`
**Why wrong**: Claude matches on the description; "what" gives it nothing to trigger on.
**Instead**: `description: Reviews code for bugs and security. Use immediately after edits.`

### Over-broad tools
**Looks like**: every agent inherits all tools.
**Why wrong**: a read-only reviewer that can `Write` or `Bash` is a hazard.
**Instead**: least privilege - `tools: Read, Grep, Glob`.

### No examples
**Looks like**: abstract instructions only.
**Why wrong**: the agent improvises format and depth.
**Instead**: a concrete checklist or runnable example in the body.

## Reference files

- `references/agents-master-guide.md` - the full agent landscape: subagents vs background agents vs agent teams, built-ins, creation paths, lifecycle, fork mode. Read this first to understand the whole picture.
- `references/subagent-reference.md` - authoritative Claude Code mechanics: every frontmatter field, scopes/locations, `/agents`, tool restrictions, model resolution, invocation, what loads at startup, agent teams.
- `references/agent-templates.md` - Technical Expert, Creative/Design, Orchestrator templates with valid frontmatter, plus persona/knowledge-encoding and team patterns.
- `references/creation-process.md` - the 7-step workflow with a full worked example (database-optimization agent) you can show end to end.
- `references/mcp-integration.md` - quick pointer for when an agent needs an MCP tool (defer to **mcp-creator** for the build).
- `references/windows-agent-teams-setup.md` - plain-English WSL + tmux walkthrough so a Windows user can see the side-by-side agent-team panes. Linked from Step 7's Windows note.

---

**Core insight**: a great subagent isn't a knowledge dump - it's a narrowly-scoped worker with a sharp *when-to-use* description, least-privilege tools, and a concrete example of the output you expect.
