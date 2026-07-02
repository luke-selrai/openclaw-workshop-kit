# Agent Creator — Test Plan

QA artifact for the `agent-creator` skill. Not loaded as skill content. Run these scenarios to verify the skill (1) **fires** on the right phrasing and **routes out** on the wrong phrasing, (2) **offers the right agent shape** for the user's need, and (3) **does all the setup itself** and then **teaches a non-technical user how to use the result**.

## How to run

1. Sync the skill to `~/.claude/skills/agent-creator/` and restart the session (so the live skill matches the repo copy).
2. **Reset the workspace before EVERY scenario.** Empty `.claude/agents/` and delete any `.claude/team/` or `.agents/` scaffolding left from a prior run. Leftover fixtures bias shape-selection (a pre-seeded `.claude/team/` pushed C5 onto the file-log fallback on turn 1) and invalidate the result. Shape and handoff tests (Sections B–C) are only trustworthy from a clean slate.
3. For each scenario, type the **User says** prompt verbatim into a fresh conversation.
4. Compare against **Expected**. Mark PASS / FAIL / PARTIAL.
5. A scenario only PASSES if every checkbox under it is met.

Pass-rate target before a re-vet: **100% on Section A (routing)** and **100% on Section E (evidence)**, **≥90% on Sections B–C**.

> Section E and A10–A12 exist specifically to verify the three dev-feedback weaknesses are closed: differentiation + trigger fidelity (the routing collision with `mcp-creator`/`skill-creator`) and **evidence** (the gating `evidence: 2` score — the worked example and the removed `~45 min` claim). A re-vet reads the shipped artifact; Section E mirrors that read.

---

## Section A — Trigger discrimination (does the right skill fire?)

The single biggest risk: `agent-creator`, `skill-creator`, and `mcp-creator` collide. These tests prove the routing table works.

### A1 — Clear agent request → FIRES
**User says:** "Create an agent that reviews my pull requests for security issues."
**Expected:**
- [ ] `agent-creator` fires (not skill-creator/mcp-creator).
- [ ] It recognises this as a single delegated specialist (review work that should leave the main context).

### A2 — Domain expert request → FIRES
**User says:** "Make me a database optimisation expert."
**Expected:**
- [ ] `agent-creator` fires.
- [ ] Routes to Technical Expert template, single-agent shape.

### A3 — Inline workflow request → ROUTES OUT to skill-creator
**User says:** "I want a /changelog command that summarises my git history the way I like it."
**Expected:**
- [ ] Skill **does not** scaffold an agent.
- [ ] It explicitly redirects to **skill-creator**, stating the reason: this runs inline in the main conversation, it is not a delegated worker.

### A4 — External API request → ROUTES OUT to mcp-creator
**User says:** "I need a custom tool so Claude can read and update records in our Salesforce."
**Expected:**
- [ ] Skill **does not** scaffold an agent.
- [ ] It redirects to **mcp-creator**, reason: connecting to an external API/database is an MCP server, not an agent.

### A5 — "MCP server" phrasing → ROUTES OUT to mcp-creator
**User says:** "Build me an MCP server for the Stripe API."
**Expected:**
- [ ] Redirects to **mcp-creator** immediately; no agent scaffolding.

### A6 — Ambiguous "custom tool" → CLARIFIES, then routes
**User says:** "Can you set up a custom tool for me?"
**Expected:**
- [ ] Skill asks one clarifying question to disambiguate: a delegated worker (agent), an inline command (skill), or an external connection (MCP)?
- [ ] Routes correctly based on the answer; does not assume agent by default.

### A7 — Interactive authoring → ROUTES OUT to advanced-skill-builder
**User says:** "Walk me through building a skill step by step, asking me questions as we go."
**Expected:**
- [ ] Redirects to **advanced-skill-builder** (dialogue-driven skill authoring).

### A8 — Invoking an existing agent → DOES NOT fire
**User says:** "Use the code-reviewer agent to check my latest commit."
**Expected:**
- [ ] Skill **does not** fire — this is invoking an agent that already exists, not creating one.
- [ ] The existing agent is simply invoked.

### A9 — Tiny edit / quick fix → DOES NOT recommend a subagent
**User says:** "Fix this typo in line 12."
**Expected:**
- [ ] Skill does not propose building an agent.
- [ ] Matches the "Skip the subagent for: tiny edits, fast quick fixes" rule — work is done inline.

### A10 — Literal "new skill" → ROUTES OUT to skill-creator
*Verifies the flagged phrase "new skill" doesn't get grabbed by agent-creator.*
**User says:** "Build me a new skill that reformats my meeting notes the way I like."
**Expected:**
- [ ] Skill **does not** scaffold an agent.
- [ ] Routes to **skill-creator** — a reusable inline prompt, not a delegated worker. Proves agent-creator yields on the literal word "skill".

### A11 — Literal "agent design" → FIRES
*Verifies the flagged phrase "agent design" resolves to this skill (it's a legitimate agent-creator phrase, not a collision).*
**User says:** "Help me with the agent design for a specialist that audits my Terraform."
**Expected:**
- [ ] `agent-creator` fires (not skill-creator/mcp-creator).
- [ ] Treats it as a single delegated specialist.

### A12 — "Agent" wording but really an MCP need → ROUTES OUT to mcp-creator (over-grab guard)
*The differentiation test in the other direction: the word "agent" must not greedily pull this skill in when the real need is an external connection.*
**User says:** "I want an agent-like helper that just connects to our Salesforce and pulls live records."
**Expected:**
- [ ] Skill **does not** scaffold an agent as the primary artifact.
- [ ] Recognises the core need is an external API connection → routes to **mcp-creator**; only mentions wrapping it in an agent as a secondary step (see D1).

---

## Section B — Shape selection (which kind of agent does it offer?)

These prove the Step-4 "which agent shape?" decision table drives the recommendation, and that the guard rule ("default to a single agent") holds.

### B1 — One self-contained job → SINGLE AGENT
**User says:** "I keep pasting slow SQL queries and asking why they're slow. Can you make something that just handles that?"
**Expected:**
- [ ] Offers a **single agent** (Technical Expert).
- [ ] Read-only tools (`Read, Grep, Glob, Bash`); does not over-provision Write.

### B2 — Pipeline / sequential dependency → CHAIN
**User says:** "First I want something to find performance problems in my code, then something else to actually fix them."
**Expected:**
- [ ] Offers a **chain** of two single agents (e.g. reviewer → optimizer), run in sequence by the main conversation.
- [ ] Explains the output of the first feeds the second.

### B3 — Independent investigations that merge → PARALLEL SET
**User says:** "I need to understand three parts of my app at once — the login, the database, and the API — and then get one summary."
**Expected:**
- [ ] Offers a **parallel set** of subagents, fanned out then synthesised.
- [ ] Mentions the parallel-edit hazard only if they would write (here it's research/read, so no conflict).

### B4 — Coordination is the work → ORCHESTRATOR
**User says:** "I want one thing that takes a feature request, decides who does what, hands pieces to specialists, and stitches the result together."
**Expected:**
- [ ] Offers an **orchestrator** over worker agents.
- [ ] Notes the orchestrator runs as the main session (subagents can't spawn subagents).

### B5 — Build + review separation → TEAM with role split
**User says:** "I want to build features but I don't trust one agent to also check its own work."
**Expected:**
- [ ] Recommends **separating implementation from review**: implementer → reviewer → security-reviewer → tester.
- [ ] Suggests the **minimal starter team** (planner, implementer, test-runner, code-reviewer), not the full roster.
- [ ] Assigns least-privilege per role (reviewer/security read-only; tester `Read, Bash`; implementer `Read, Edit, Write`).

### B6 — Long-lived coordinating workers → AGENT TEAMS feature
**User says:** "I want several agents running for hours, each keeping its own memory and talking to each other."
**Expected:**
- [ ] Points to Claude Code **agent teams** (sustained parallelism), not a single-session chain.

### B7 — Unsure user → DEFAULT to single agent
**User says:** "I think I need a bunch of agents but honestly I'm not sure."
**Expected:**
- [ ] Applies the guard rule: starts with **one agent**, says it will split later only if the work clearly forks.
- [ ] Does **not** over-build a team up front.

### B8 — Durable memory for a read-only role → `memory:` field, NOT Write
*Verifies the v2.0.2 least-privilege fix (the regression a prior live run caused).*
**User says:** "I want a research agent that remembers what it learned about my codebase between sessions."
**Expected:**
- [ ] Sets `memory: project` (or `user`) in the frontmatter for cross-session notes.
- [ ] Keeps tools read-only (`Read, Grep, Glob`) — does **not** grant `Edit`/`Write` just so it can take notes.
- [ ] Explains, in one line, that `memory:` auto-scopes Read/Write to a managed memory dir.

### B9 — Many unattended jobs, no inter-agent talk → BACKGROUND AGENTS
*The only Step-4 shape row with zero coverage; tests background-vs-team discrimination.*
**User says:** "I want to kick off about ten independent cleanup jobs overnight and check them in the morning — they don't need to talk to each other."
**Expected:**
- [ ] Recommends **background agents**, not an agent team.
- [ ] Reasons explicitly: independent + unattended + no inter-agent messaging → background, not team.

### B10 — Design/copy work → CREATIVE/DESIGN template
*The Creative/Design template is otherwise untested (only Technical + Orchestrator are exercised).*
**User says:** "Make me an agent that critiques my landing-page copy and suggests punchier headlines."
**Expected:**
- [ ] Offers a **single agent** built from the **Creative/Design** template (design philosophy, process, quality bar) — not the Technical Expert template.
- [ ] Read-only or read+write as the task needs; does not over-provision.

---

## Section C — End-to-end creation + non-technical handoff

The user is assumed **not technical** and **does not know how to create or use an agent**. The skill must do 100% of the setup and then teach them to use the result. The user's only job is to *use* what was created.

### C1 — Full build, zero prior knowledge
**User says:** "I run a fire-protection business. I get the same kind of slow report queries all the time. I have no idea how any of this works — can you just make me something that helps?"
**Expected (creation):**
- [ ] Skill runs the 7-step workflow itself; asks at most the few requirements questions (domain, recurring problem, in/out of scope) in plain language — not jargon.
- [ ] **Writes the agent file itself** to `.claude/agents/` (or via `/agents`). The user is never asked to create or edit a file, paste YAML, or run setup commands.
- [ ] Picks shape (single agent), template, least-privilege tools, and model **without** making the user decide the technical bits — it recommends and explains in one line each.

**Expected (handoff — the critical part):**
- [ ] After creating, the skill **tells the user how to use it** in plain English: the exact phrase to type to invoke it (e.g. *"Use the report-helper agent to…"*).
- [ ] Tells them the **one action they must take**: restart the session (or that `/agents` needs no restart) — explained as *what* to do, not *why* mechanically.
- [ ] Gives an **initial recommendation / next step**: "try it now with this example…" and a concrete first prompt they can copy.
- [ ] Confirms what the agent will and won't do (scope), so the user has correct expectations.

**Expected (the written file is valid — inspect the created `.claude/agents/*.md`):**
- [ ] Valid YAML frontmatter with `name`, `description`, `tools`, `model`.
- [ ] `name` is lowercase-kebab-case and narrow (not `super-agent`); `tools` is a comma-list scoped to least privilege.
- [ ] `description` is phrased as **when to use me** (trigger-phrased), not **what I am** — per the "description says what, not when" anti-pattern.
- [ ] If it's a coding/implementation agent, the body **opens with the repo-recon step** (read similar files → reuse patterns → avoid needless abstractions).

### C2 — Post-creation usage check
**User says (after C1):** "Okay it's made. Now what do I actually do?"
**Expected:**
- [ ] Skill restates the invocation phrase and a ready-to-paste first example.
- [ ] No assumption that the user knows about sessions, files, tools, or frontmatter.

### C3 — User wants to change it later
**User says:** "It's not picking it up when I ask — it ignores me."
**Expected:**
- [ ] Skill diagnoses the most common cause first: the `description` isn't trigger-phrased, or the file needs a session restart to load.
- [ ] Fixes the file itself; tells the user the one thing to do (restart / re-ask with the agent named).

### C4 — Setup is fully owned by the skill (negative check)
**Across C1–C3, the skill must NEVER:**
- [ ] Ask the user to open or edit a markdown file by hand.
- [ ] Ask the user to write YAML / choose tools by raw name without a plain-English recommendation.
- [ ] Leave the user with "now save this file in `.claude/agents/`" as a manual step (it should do the write).
- [ ] Hand over a stack trace or raw error.

### C5 — Windows agent-team panes handoff
The Windows user wants a native agent team **and** to watch the teammates side by side — the case the Step 7 Windows note + `references/windows-agent-teams-setup.md` exist for.
**User says:** "I'm on Windows 11. I want a team of agents — a researcher, a coder, and a reviewer — that work together, and I want to watch them work side by side. Set it up for me."
**Expected (the Windows note fires):**
- [ ] Sets up / explains the agent team (researcher + coder + reviewer).
- [ ] Tells the user, in plain English, that agent teams are **experimental** and that on **Windows** the side-by-side panes only show under **WSL + tmux** — in plain Windows Terminal there are no panes and you cycle teammates with **Shift+Down**.
- [ ] **Reassures** that the team still runs and coordinates without the panes (so the user isn't alarmed by their absence).
- [ ] **Offers** to walk them through WSL + tmux setup if they want the visual view.

**Follow-up — user says:** "Yes, set up whatever I need to see them side by side."
**Expected (the walkthrough fires):**
- [ ] Walks the WSL + tmux steps from `references/windows-agent-teams-setup.md`: install WSL (`wsl --install`, restart) → open Ubuntu → install tmux → install Node + Claude Code **inside WSL** → set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, start `tmux`, run `claude` inside it → reach Windows files under `/mnt/c/`.
- [ ] Notes the WSL Claude Code is a **separate login**.
- [ ] One step at a time, plain English, exact commands — never assumes Linux familiarity.

---

## Section D — Edge cases & negative tests

### D1 — Request spans two lanes (agent + MCP)
**User says:** "I want an agent that can also pull live data from our Airtable."
**Expected:**
- [ ] Builds the **agent** (primary artifact) and notes the Airtable access is an MCP dependency → wires it via `mcpServers`, deferring the server build to mcp-creator.
- [ ] Does not silently skip the data-access half.

### D2 — Grandiose / unfocused request
**User says:** "Make me one super-agent that can do everything — code, design, testing, research."
**Expected:**
- [ ] Skill pushes back per the golden rule and "vague persona / grandiose name" anti-pattern: recommends splitting into focused agents, not one `super-agent`.

### D3 — Over-broad tools requested
**User says:** "Give the reviewer agent full access just in case."
**Expected:**
- [ ] Skill declines full access for a read-only role; explains least privilege in one line and sets `Read, Grep, Glob`.

### D4 — General coding (not an agent)
**User says:** "Write me a Python function to parse this CSV."
**Expected:**
- [ ] Skill does not fire; the task is handled directly / by a language skill.

### D5 — Knowledge-dump risk
**User says:** "Here are our 40 pages of internal docs — put all of this into the agent."
**Expected:**
- [ ] Skill curates the load-bearing checklist into the body and links out for depth; does not paste 40 pages (knowledge-dump anti-pattern). Body stays ~10–40 lines.

### D6 — High-volume / cost-sensitive → cheaper model
*Tests the model column of the tools/model table (otherwise untested).*
**User says:** "I need something that triages hundreds of log lines fast and cheap."
**Expected:**
- [ ] Recommends `model: haiku` (faster/cheaper for high-volume triage), with read-only tools (`Read, Grep, Glob`).
- [ ] Explains the model choice in one line; does not silently default to the inherited model.

### D7 — Parallel agents that write → surfaces the edit hazard
*B3 only covers the read-only parallel case; this is the write case where the hazard matters.*
**User says:** "I want three agents all editing my source files at the same time to speed things up."
**Expected:**
- [ ] Surfaces the **parallel-edit hazard**: concurrent writes to the same files conflict.
- [ ] Recommends a mitigation — separate file scopes, `isolation: worktree`, or sequential merge — rather than blindly setting up simultaneous writers.

---

## Section E — Evidence & artifact checks (static — no conversation)

These mirror what a re-vet reads off disk. They exist to verify the gating **`evidence: 2`** weakness is closed and the routing fix is actually shipped (not just behaviorally inferred from Section A). Inspect the files directly; mark PASS only if present and substantive.

### E1 — Worked example is a complete, valid agent
**Check:** `references/creation-process.md`.
- [ ] Contains the **db-optimizer** worked example as a full agent (valid frontmatter + body), not merely a description of the 7-step process.
- [ ] An outsider can read it and see the actual output the workflow produces — the verifiable evidence the vetter asked for.

### E2 — Unverified time claim is gone
**Check:** `SKILL.md` and `references/`.
- [ ] No `~45 minutes` / `45-minute` time-to-build claim survives in the live skill (Effort labels light/medium/heavy replace it). A CHANGELOG history note referencing the removal is acceptable.

### E3 — Frontmatter description routes by phrasing
**Check:** `SKILL.md` frontmatter `description`.
- [ ] Carries the symmetrical NOT-clause: inline prompt / slash-command / workflow → **skill-creator**; external API/tool/database → **mcp-creator**.
- [ ] Spells out which user phrases trigger this skill (not the abstract "meta-agent for creating agents, skills, and MCPs").

### E4 — Routing table present and complete
**Check:** `SKILL.md` body.
- [ ] A "Route first" table at the top maps user intent → agent-creator / skill-creator / advanced-skill-builder / mcp-creator with a one-line reason each.

### E5 — Reference files present and substantive
**Check:** `references/`.
- [ ] All six exist and are non-trivial: `agents-master-guide.md`, `subagent-reference.md`, `agent-templates.md`, `creation-process.md`, `mcp-integration.md`, `windows-agent-teams-setup.md`.

---

## Scoring sheet

| Section | Scenarios | Target | Guards which weakness |
|---|---|---|---|
| A — Routing / firing | A1–A12 | 12/12 | trigger fidelity + differentiation (the routing collision) |
| B — Shape selection | B1–B10 | ≥9/10 | shape table coverage; B8 guards the `memory:` least-privilege fix |
| C — Build + non-technical handoff | C1–C5 | 5/5 (C1 handoff + file-validity mandatory) | usable handoff; C5 = Windows agent-team note |
| D — Edge cases | D1–D7 | ≥6/7 | anti-patterns, tools/model, parallel-edit hazard |
| **E — Evidence / artifacts** | **E1–E5** | **5/5** | **the gating `evidence: 2` score + shipped routing fix** |

**Re-vet gate:** Section A and Section E must be **100%** before re-vetting — they map directly onto the three scores blocking Production (`trigger_fidelity 3`, `differentiation 3`, `evidence 2`). Behavioral routing (A) without the shipped artifact (E) won't move `evidence`.

**Known watch-items:**
- **Section C** (non-technical handoff — teaching the user how to *use* the agent and owning 100% of setup) is the area most likely to PARTIAL, because the skill is written for a technical builder. If C1's handoff checkboxes fail, the fix is to add an explicit "after creation, teach the user how to invoke it + give a first example + state the one action they must take" step to the skill's workflow.
- **C5** PARTIAL'd on first run because a leftover `.claude/team/` fixture biased shape selection. Re-run from a clean workspace (step 2 of How to run) before judging it.
