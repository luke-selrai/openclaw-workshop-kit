# Case 02 - Investor email with significance inflation

## Input

> Our revolutionary platform serves as a game-changer in the rapidly evolving fintech ecosystem. We're a thought leader spearheading a paradigm shift that will unlock unprecedented value for our users. Whether you're a startup or a Fortune 500, our holistic, comprehensive solution will empower your team to embark on a transformative journey.

## Must-flag

- revolutionary (significance inflation)
- serves as (copula avoidance)
- game-changer (Tier 1)
- rapidly evolving (template phrase)
- ecosystem (Tier 2)
- thought leader (Tier 1)
- spearheading (Tier 2)
- paradigm shift (Tier 1: paradigm + significance inflation)
- unprecedented (Tier 3)
- Whether you're a startup or a Fortune 500 (template phrase, false range)
- holistic (Tier 1)
- comprehensive (Tier 1)
- empower (Tier 2)
- embark (Tier 1)
- transformative journey (significance inflation)

## Must-not-survive

revolutionary, game-changer, ecosystem, thought leader, spearheading, paradigm, unprecedented, holistic, comprehensive, empower, embark, transformative, journey

## Reference rewrite

> We help fintech teams move money faster and reconcile in real time. Two of our customers - one early-stage, one public - cut settlement times by more than half this quarter. We'd like 20 minutes to walk you through the numbers.

## Notes

This input has 15+ flagged terms and zero concrete claims. The reference rewrite replaces inflated language with one named metric and one specific ask. If the model rewrites by swapping flagged words 1:1 without adding substance, that is itself a flag - the second-pass audit should catch that the rewrite is still vague.
