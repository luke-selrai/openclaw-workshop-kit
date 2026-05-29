---
name: avoid-ai-writing
description: "Audit and rewrite content to remove 21+ categories of AI writing patterns with a tiered word/phrase replacement table"
risk: none
source: https://github.com/conorbronsdon/avoid-ai-writing
date_added: "2026-03-06"
---

# Avoid AI Writing — Audit & Rewrite

Detects and fixes AI writing patterns ("AI-isms") that make text sound machine-generated. Bundles a tiered word/phrase replacement table, a categorised pattern list, and a regression eval suite.

## When to Use This Skill

- When asked to "remove AI-isms," "clean up AI writing," or "make this sound less like AI"
- After drafting content with AI and before publishing
- When editing any text that sounds like it was generated rather than written
- When auditing documentation, blog posts, marketing copy, or internal communications for AI tells

## Bundled references — load these on invocation

The skill body is the orchestrator. The lookup data lives in side files so it stays consistent across runs and can be updated without editing the orchestrator.

- [references/replacements.md](references/replacements.md) — tiered word/phrase replacement table (47 Tier 1 always-replace entries, 35 Tier 2 cluster-flag entries, 12 Tier 3 density-flag entries, 10 Tier 3 phrase entries).
- [references/categories.md](references/categories.md) — 30+ pattern categories with one-line description and a flagged example each.
- [examples/](examples/) — regression eval suite (4 before/after cases) to verify the skill's behaviour hasn't drifted.

When invoked, read both reference files into context before scanning the input. Do not rely on memory of the table — the side files are the source of truth.

## Audit flow

Run all four sections. The output structure is fixed.

### 1. Issues found
Quote every flagged term. For each, name the category (em dash, transition phrase, Tier 1 word, etc.) and link it to the entry in [categories.md](references/categories.md) or [replacements.md](references/replacements.md).

### 2. Rewritten version
Apply the replacements and structural fixes. Preserve the author's facts; if the input has no facts, say so in section 3 — do not invent any.

### 3. What changed
Summarise the edits: which categories fired, how many terms were swapped, what structural moves were made (paragraph re-shuffles, bullet collapses, etc.).

### 4. Second-pass audit — REQUIRED
Re-read the rewrite against the same table. List every pattern that survived, or write "no surviving patterns found." This section is mandatory on every run — do not skip it for short inputs and do not skip it because the rewrite "looks fine." If the second pass finds new hits, fix them before returning to the user.

## Domain-terminology caveat

The replacement table is a default, not a rule. In specialist contexts a flagged term may be the precise word:

- "robust" in a reliability/networking doc = fault-tolerance property, not generic praise. Preserve.
- "leverage" in finance = ratio of borrowed funds to equity. Preserve.
- "framework" in a software doc = a specific class of library. Preserve.
- "platform" in product strategy = a specific architectural commitment. Preserve.

Before swapping a Tier 1 term, ask: is this the precise term of art for this domain? If yes, leave it and note the preservation in section 3. See [case-03-technical-doc.md](examples/case-03-technical-doc.md) for the canonical example.

## Limitations

- Audits prose only — does not detect AI-generated code.
- Pattern matching is guideline-based, not absolute — some flagged words are fine in context (see domain caveat above).
- The replacement table suggests starting points; the best choice depends on context and voice.
- Cannot verify factual claims or find real citations to replace vague attributions. If the input has no facts, the rewrite cannot add any — flag this in section 3.
- The skill flattens voice if used carelessly. Run it as a final pass, not a writing aid.

## Verifying behaviour after edits

If you change SKILL.md, the references, or the table:

1. Run each `examples/case-*.md` input through a fresh session.
2. Check the rewrite against the case's **Must-not-survive** list and the **Reference rewrite**.
3. Anything that regresses is the edit's fault — fix the edit, not the reference.

See [examples/README.md](examples/README.md) for the eval procedure.
