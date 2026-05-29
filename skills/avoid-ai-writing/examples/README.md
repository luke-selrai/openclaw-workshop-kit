# Regression examples

Fixed before/after pairs the skill should be able to reproduce within tolerance. Used to catch drift when SKILL.md is edited — if a rewrite starts re-introducing flagged terms, the eval surfaces it.

## How to run the eval

For each `case-*.md`:

1. Feed the **Input** block to a fresh Claude Code session with the skill active and the prompt: `Audit this for AI writing patterns.`
2. Compare the model's rewrite to the **Reference rewrite** block.
3. Pass criteria (judgement, not exact match):
   - All terms listed in **Must-flag** appear in the issues section.
   - No term listed in **Must-not-survive** appears in the rewrite.
   - Sentence count and meaning of the rewrite are within ±20% of the reference.
   - The second-pass audit section is present in the output.

## Cases

- [case-01-marketing-blog.md](case-01-marketing-blog.md) — generic SaaS landing copy
- [case-02-investor-email.md](case-02-investor-email.md) — pitch with significance inflation
- [case-03-technical-doc.md](case-03-technical-doc.md) — domain-term preservation check
- [case-04-linkedin-post.md](case-04-linkedin-post.md) — chatbot artifacts + hashtag stuffing

## When to update

Update a case only when SKILL.md or the references table changes in a way that legitimately changes the right answer. Drift caught by the eval is the point — don't paper over it by relaxing the reference.
