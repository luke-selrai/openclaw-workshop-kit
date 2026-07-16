# Pattern Categories

Side-file companion to [SKILL.md](../SKILL.md). Each category names one tell, gives a one-line description, and shows a flagged example so the auditor knows what to look for. Severity tier (P0/P1/P2) noted where defined.

## 1. Em dashes (P1)
More than 1 per 1000 words signals AI rhythm.
Example: "The project - a sweeping reimagining of the field - embarks on a journey."

## 2. Bold overuse (P1)
**Random words** bolded for emphasis instead of structural use.
Example: "The **key insight** is that we need to **focus on outcomes**."

## 3. Emoji in headers
Section headers with leading emoji (🚀 Introduction, 💡 Key Insights).

## 4. Excessive bullets (P2)
Bullet lists of 8+ items in under 200 words, or bare noun phrases as bullets.

## 5. Hedging
"Perhaps," "could potentially," "may indicate" - uncertainty padding.
Example: "This could potentially be a useful approach."

## 6. Hollow intensifiers
"Genuine," "truly," "frankly," "really" - adds nothing.
Example: "This is truly a genuinely useful tool."

## 7. Rule of three (P2)
Compulsive "X, Y, and Z" triplets even when two or four would be honest.
Example: "Fast, reliable, and scalable."

## 8. Word/phrase replacements (P1)
Flagged vocabulary - see [replacements.md](replacements.md).
Example: "Leverage cutting-edge tools to streamline workflows."

## 9. Template phrases (P1)
"[Adjective] step towards [X]," "Whether you're [A] or [B]," "I recently had the pleasure of."
Example: "Whether you're a developer or a designer, this matters."

## 10. Transition phrases (P2)
"Moreover," "Furthermore," "Additionally," "In today's [X]," "It's worth noting," "When it comes to," "At the end of the day," "That said."
Example: "Moreover, in today's fast-paced world..."

## 11. Significance inflation (P0)
"Revolutionary," "groundbreaking," "paradigm shift" with no concrete claim behind them.
Example: "This is a revolutionary breakthrough in user engagement."

## 12. Copula avoidance (P2)
Replacing "is" with "serves as," "features," "boasts."
Example: "The app serves as a powerful tool that boasts robust integrations."

## 13. Synonym cycling (P1)
Restating the same noun three different ways in nearby sentences (tool/solution/platform/system).
Example: "Our tool is fast. The solution is scalable. The platform is reliable."

## 14. Vague attribution (P0)
"Experts say," "studies suggest," "many believe" - no named source.
Example: "Studies suggest that this approach works well."

## 15. Filler phrases (P1)
"At the end of the day," "the fact of the matter is," "needless to say."

## 16. Generic conclusions (P2)
"In conclusion," "As we've seen," and closing paragraphs that restate the opener.

## 17. Chatbot artifacts (P0)
"I hope this helps!" "Great question!" "Feel free to reach out!" "Let's dive in!"
Example: "Great question! Let me break this down for you."

## 18. Notability name-dropping
Four prestigious sources stacked without context (Harvard, MIT, Forbes, McKinsey in one paragraph).

## 19. Superficial -ing analyses
"Understanding the dynamics," "exploring the implications," "examining the trends" - gerund titles that promise more than the content delivers.

## 20. Promotional language
"Nestled," "vibrant hub," "thriving ecosystem" without specifics.
Example: "Nestled in a vibrant hub of innovation..."

## 21. Formulaic challenges
"Despite challenges, [X] continues to thrive" - unnamed challenge, unnamed response.

## 22. False ranges
"From A to Z," "from startups to enterprises" - implied breadth that isn't real.
Example: "From small businesses to Fortune 500 companies, everyone benefits."

## 23. Inline-header lists
Bold headers that repeat the bullet content verbatim.
Example: "**Speed:** The tool is fast." (header just restates the line)

## 24. Title case headings
Every word capitalized in headings ("How To Use This Tool" vs. "How to use this tool").

## 25. Cutoff disclaimers (P0)
"As of my knowledge cutoff," "I cannot verify recent events" - explicit chatbot scaffolding.

## 26. "It's not X, it's Y" constructions
Example: "It's not just a framework - it's a way of thinking."

## 27. Hashtag stuffing (P0)
6+ hashtags clustered at the end of a post.

## 28. Hedge-stacked predictions
"May potentially become one of the most important..." - three hedges in one clause.

## 29. "Let's" constructions
"Let's explore," "Let's break this down," "Let's dive in" - filler transition disguised as invitation.

## 30. Reasoning chain artifacts
"Let me think step by step," "Breaking this down," "Step 1:" - scaffolding leaking into output.

## 31. Rhetorical question openers
"But what does this mean for developers?" - stalling tactic before the real point.

## 32. Sycophantic tone
"Excellent point!" "You're absolutely right!" - reward framing from chat training.

## 33. Confidence calibration
"It's worth noting," "Interestingly," "Surprisingly," "Importantly" - pre-interpreting significance for the reader.

## See also

- [replacements.md](replacements.md) - the tiered word table
- [../SKILL.md](../SKILL.md) - invocation flow and second-pass gate
- [../examples/](../examples/) - before/after regression cases
