# Replacement Table

Side-file companion to [SKILL.md](../SKILL.md). Load this when auditing or rewriting. Three tiers by enforcement strength.

> Domain caveat: these replacements are defaults, not rewrites by fiat. In specialist contexts (security engineering, legal, medical, finance) a flagged term may be the precise word — "robust" in a security doc often means a specific resilience property, not generic praise. Preserve domain terminology and only swap when the simpler word carries the same load.

## Tier 1 — Always replace (47 entries)

Flag every occurrence and propose the mapped alternative. The alternative is a starting point; pick the contextually correct option from the listed choices.

| Flagged | Replacement |
|---|---|
| delve | explore, dig into |
| landscape | field, space |
| tapestry | describe complexity |
| realm | area, field |
| paradigm | model, approach |
| embark | start, begin |
| beacon | rewrite |
| testament to | shows, proves |
| robust | strong, reliable |
| comprehensive | thorough, complete |
| cutting-edge | latest, newest |
| leverage | use |
| pivotal | important, key |
| underscores | highlights, shows |
| meticulous | careful, detailed |
| seamless | smooth, easy |
| game-changer | describe what changed |
| utilize | use |
| watershed moment | turning point |
| nestled | is located |
| vibrant | describe activity |
| thriving | growing, active |
| deep dive | examine, explore |
| unpack | explain, break down |
| bustling | busy, active |
| intricate | complex, detailed |
| complexities | name them |
| ever-evolving | changing, growing |
| enduring | lasting |
| daunting | hard, difficult |
| holistic | complete, full |
| actionable | practical, useful |
| impactful | effective, significant |
| learnings | lessons, findings |
| thought leader | expert, authority |
| best practices | what works |
| at its core | cut |
| synergy | describe effect |
| interplay | relationship, connection |
| in order to | to |
| due to the fact that | because |
| serves as | is |
| features | has, includes |
| boasts | has |
| commence | start |
| ascertain | find out |
| endeavor | effort, attempt |
| embrace | adopt, accept, use |

## Tier 2 — Flag in clusters (≥2 per paragraph)

Single occurrence is fine. Two or more in the same paragraph is an AI tell — propose alternatives or restructure.

harness, navigate, foster, elevate, unleash, streamline, empower, bolster, spearhead, resonate, revolutionize, facilitate, underpin, nuanced, crucial, multifaceted, ecosystem, myriad, plethora, encompass, catalyze, reimagine, galvanize, augment, cultivate, illuminate, elucidate, juxtapose, cornerstone, paramount, poised, burgeoning, nascent, quintessential, overarching.

## Tier 3 — Flag at density (≥3% word saturation)

Common words that only fire when they dominate. Count occurrences ÷ total words; if ≥3% or the same word appears 3+ times in short text, propose variety or specifics.

significant, innovative, effective, dynamic, scalable, compelling, unprecedented, exceptional, remarkable, sophisticated, instrumental, world-class.

## Tier 3 phrases — Flag at 2+ uses or 3+ distinct phrases

Boilerplate multi-word strings. Two repeats of the same phrase, or three different ones in the same piece, is the threshold.

"emerging sector," "integration of," "intersection of," "community-driven," "long-term sustainability," "user engagement," "decentralized compute," "reward emissions," "tokenized incentive structures," "designed for long-term [X]."

## How to use this table

1. First pass — scan for Tier 1 hits, flag every occurrence with the table entry.
2. Per paragraph — count Tier 2 hits; flag the paragraph if ≥2.
3. Whole piece — compute Tier 3 density; flag if ≥3% or 2+ repeats.
4. Apply replacements, then re-check — see the second-pass gate in [SKILL.md](../SKILL.md).
