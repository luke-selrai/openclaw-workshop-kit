---
name: agent-tool-builder
description: "Designs or hardens a tool's model-facing read-surface — the name, description, input-schema, and return/error contract the LLM reads when deciding whether and how to call a tool — so the agent stops looping, guessing, or failing silently. Works for MCP tools, Agent SDK tools, or raw function-calling. Use when the user says 'design or improve a tool for an agent', 'write the description or JSON schema for this tool', 'my agent keeps looping on or misusing this tool', 'the model can't tell these two tools apart', 'I'm building a new tool — draft its schema and error contract', or 'why does my tool fail silently — harden its error returns'. NOT for deciding tool architecture — how many tools, capability splits, or call sequencing; this owns only the read-surface wording and schema shape."
risk: low
source: "SelrAI rebuild 2026-07; concept seeded by vibeship-spawner-skills (Apache-2.0)"
date_added: "2026-02-27"
allowed-tools: Read, Grep, Glob
metadata:
  category: Productivity & Meta
  tags: [tools, tool-design, read-surface, json-schema, function-calling, mcp]
---

# Agent Tool Builder

Design or harden one tool's **read-surface**: the wording and shape the LLM reads when deciding *whether and how* to call it. The model never sees your code — only the schema — so when a tool loops, misfires, or fails silently, the fault is almost always here, not in the implementation. Get it right up front on a new tool, or fix it here on an existing one.

## The boundary: read-surface vs control-surface

- **Read-surface — design or harden it:** name · description · input-schema shape · return/error contract. Same across MCP, Agent SDK, and raw function-calling.
- **Control-surface — flag, never change it:** tool count, capability splits (merge/decompose), when-to-call sequencing, retry/fallback, permissions, and an enum's *accepted values* (renaming those changes the contract callers depend on, not how the tool reads).

Rule: **flag, don't re-architect.** Name the control-surface smell and the option, then hand the decision back to the person you're working with.

## Process

1. **Scope.** Confirm the ask is to design or harden one tool's read-surface. If the real work is elsewhere, this isn't the tool for it.
2. **Ingest & normalize.** Take the tool in any form — MCP JSON, a function-calling `tools` entry, an SDK decorator + docstring — and lay name, description, and every parameter side by side.
3. **Get returns & errors.** JSON Schema is inputs-only, so the return shape and error messages — the highest-value read-surface — are usually missing from the paste. Ask for **one sample success payload and one sample error payload** when they aren't declared. For an existing tool, if none exist, record the absence as a defect; for a new tool, design the intended success and error shapes here — they're the highest-value read-surface to get right.
4. **Score.** Apply **every** check in `references/read-surface-checklist.md`, each marked pass/fail with the exact defect. Check 8 (**distinguishability**) activates only in set-mode (two+ tools); otherwise mark it n/a. Score all checks before moving on — no partial passes.
5. **Harden.** Write or rewrite name, description, params, returns, and errors until every check that failed in step 4 now passes.
6. **Flag the control-surface.** Collect every architecture smell — merges, splits, tool-count, enum-value renames — into a separate "your call" list. Flag each smell; change none of them.
7. **Deliver** the three-part output below.

## Output contract — three separate parts, in order

1. **Scored checklist** — each check pass/fail, with the exact defect on every failure.
2. **Finished read-surface** — the tool as designed or rewritten, and nothing else.
3. **Control-surface flags — NOT changed, your call** — merges, decompositions, enum-value renames, tool-count smells.

Final check: nothing from part 3 leaked into part 2 — that separation is the proof the boundary held.

See `examples/sample-scored-output.md` for the output shape on one repair run, `examples/design-from-scratch.md` for designing a new tool from a plain-English ask, and `examples/search-vs-list.before-after.md` for a full set-mode harden. Every checklist rule cites Anthropic's *Writing effective tools for AI agents* — https://www.anthropic.com/engineering/writing-tools-for-agents.
