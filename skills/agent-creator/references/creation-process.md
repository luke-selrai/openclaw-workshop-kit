# Agent Creation Process

The 7-step workflow end to end, with a complete worked example so you can show a user exactly what the process produces.

## The 7 steps

Effort is rough relative weight and ordering, not a time guarantee.

| Step | Effort | Activity |
|---|---|---|
| 1. Understand the need | light | What task recurs? What should leave the main context? |
| 2. Design the persona | light | What expert owns this? Role, depth, voice. |
| 3. Map the knowledge | heavy | Frameworks, checklists, pitfalls. Curate, don't dump. |
| 4. Choose the agent shape | medium | Pick the shape (single / chain / parallel / orchestrator / team / background), then a template — full table in SKILL.md. |
| 5. Restrict tools + model | light | Least privilege; cheap model for high-volume work. |
| 6. Add concrete examples | medium | A runnable example or checklist in the body. |
| 7. Test, refine, and hand off | medium | Invoke by name, watch it, tighten the description; then give the user the invocation phrase, a ready-to-paste prompt, the restart step, and one line of scope. |

## Requirements questions (step 1)

- What domain expertise is needed?
- Who is the target user?
- What recurring problem should this agent own?
- What's in/out of scope?
- Does its output need to stay out of the main conversation (lots of files/logs)? → yes means a subagent fits.

---

## Worked example: database-optimization agent

A full run of the workflow against the request **"Create an agent for database optimization."**

**Step 1 — Need.** Backend devs repeatedly paste slow queries and ask why they're slow. The diagnosis involves reading schemas and `EXPLAIN` output — verbose, one-off context that shouldn't clog the main conversation. → Good subagent candidate.

**Step 2 — Persona.** Senior DBA, ~20 years, PostgreSQL/MySQL focus. Voice: direct, evidence-first (always cites the plan).

**Step 3 — Knowledge.** EXPLAIN/EXPLAIN ANALYZE reading; index strategy (composite, covering, partial); common anti-patterns (SELECT *, N+1, unindexed FKs, functions on indexed columns); when *not* to index (write-heavy tables).

**Step 4 — Shape + template.** One self-contained job for one specialist → single agent, Technical Expert template.

**Step 5 — Tools + model.** Diagnoses and recommends; can run read-only queries to inspect plans, never mutates data. → `tools: Read, Grep, Glob, Bash`, `model: inherit`. (Lock writes harder with a `PreToolUse` hook if the agent will touch a live DB — see `subagent-reference.md`.)

**Step 6 — Examples.** A worked rewrite in the body so output format is set.

**Step 7 — Test.** "Use the db-optimizer agent to speed up this query: …" Confirm it reads the plan, names the cause, gives a fix. Tighten the description if delegation doesn't fire.

### Output — `.claude/agents/db-optimizer.md`

```markdown
---
name: db-optimizer
description: Database query optimization specialist for PostgreSQL and MySQL. Use proactively whenever a query is slow, an EXPLAIN plan needs reading, or indexing/schema advice is requested.
tools: Read, Grep, Glob, Bash
model: inherit
---

You are a senior database administrator with 20 years of experience optimizing
PostgreSQL and MySQL. You are direct and evidence-first: every recommendation
cites the execution plan or schema fact that justifies it.

## When invoked
1. Get the query and, if available, the schema and an EXPLAIN (ANALYZE, BUFFERS) plan.
   If you only have read access, run EXPLAIN yourself — never run the query's writes.
2. Read the plan: find the dominant cost (seq scans on large tables, nested loops
   over big row counts, sorts spilling to disk, misestimated row counts).
3. Diagnose the root cause, then prescribe the minimal change.

## What to look for
- Sequential scans on large tables where a selective index would help
- Missing indexes on JOIN / WHERE / ORDER BY columns; unindexed foreign keys
- Functions or type casts on indexed columns (kills index usage)
- SELECT * pulling unneeded columns; N+1 access patterns
- Composite index column order wrong for the query's predicates
- Row-count misestimates → stale statistics (ANALYZE)

## What NOT to do
- Don't add indexes blindly: each one slows writes. Skip them on write-heavy
  tables unless the read win is clear.
- Don't recommend rewrites you can't justify from the plan.

## Output format
**Diagnosis** — the dominant cost, quoted from the plan.
**Fix** — the specific index/rewrite, as runnable SQL.
**Expected impact** — what changes in the plan and why.
**Trade-offs** — write cost, storage, or correctness caveats.

### Example
Diagnosis: Seq Scan on orders (1.2M rows), filtered by customer_id; 41,000 rows
removed by filter — no usable index.
Fix:
    CREATE INDEX CONCURRENTLY idx_orders_customer_id ON orders (customer_id);
Expected impact: Seq Scan → Index Scan; cost drops from ~24,000 to ~85.
Trade-offs: ~30 MB index; small INSERT/UPDATE overhead on orders.
```

This file is the literal output of the workflow — drop it in `.claude/agents/`, restart the session (or create it via `/agents` for no restart), and invoke: *"Use the db-optimizer agent to speed up this query."*

### Step 7 — the handoff message for db-optimizer

The exact message to give the user after writing the file:

- **Invocation phrase:** "Use the `db-optimizer` agent to …"
- **Ready-to-paste first prompt:** "Use the db-optimizer agent to speed up this query — it does a full table scan: `SELECT * FROM orders WHERE customer_id = 42;`"
- **Restart step:** "I've created it — restart this session once and it's ready." (Or, if you used `/agents`: "It's live now, no restart needed.")
- **Scope:** "It diagnoses slow Postgres/MySQL queries and gives you the index or rewrite to fix them. It won't run writes or change your data."

---

## Quality checklist

The golden rule, made checkable: one responsibility, small context, clear success criteria, minimal permissions. A body over ~40 lines or an agent that both builds and grades its own work usually fails one of these.

**Expertise**
- [ ] Clear domain boundaries
- [ ] Specific, actionable guidance (a fix, not just a diagnosis)
- [ ] Real examples in the body
- [ ] Common pitfalls covered

**Usability**
- [ ] `description` reads as *when to use*, not *what it is*
- [ ] Scannable structure, explicit output format
- [ ] Appropriate voice

**Integration / safety**
- [ ] Least-privilege `tools`
- [ ] Right `model` for cost/stakes
- [ ] Chains/teams cleanly with other agents

## Refining after release
Watch how delegation behaves. If Claude isn't picking the agent up, the `description` is almost always the cause — make the trigger condition explicit. Then tighten knowledge gaps and output format from real runs.
