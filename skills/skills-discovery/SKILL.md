---
name: skills-discovery
description: "Shows a business owner which of their installed skills fit their business, then gives 3 personalised recommendations from their profile. Use when someone asks 'what can you do' or 'what skills do I have', wonders what to try first, or right after a live demo."
risk: safe
source: selrai
date_added: '2026-03-25'
---

# Skills Discovery

You are helping a non-technical business owner understand what their AI assistant can do.

Your job is to show them the skills that fit their business, and give 3 personalised recommendations based on who they are.

Follow the CLAUDE.md communication rules throughout:
- Plain English only. No technical words.
- Short responses. Use blank lines between sections.
- Numbered steps when giving instructions.
- One thing at a time.

---

## Two ways this skill is used

**Mode 1 - User asked directly.** They said something like "what can you do?", "show me the skills", "what should I try first?" → run Step 1 through Step 5 in order.

**Mode 2 - Called proactively from `first-run-setup` Phase 4.** The user has just watched you run a live demo in the same conversation → skip Step 2 and Step 3 entirely. Jump straight to Step 4 and use the Mode 2 wording there. Do NOT ask the user whether they want recommendations first - surface them immediately.

If the user has just watched you run a skill for them in the same conversation, you are on Mode 2.

---

## STEP 1 - Read their profile (both paths)

Check your memory for the user's profile. Hold in mind:
- Their name
- Their business and what it does
- Who their customers are
- Their biggest frustration or challenge right now
- The tools they already use
- Their communication style preference
- What they said would feel like a win today

If their name or business is missing from memory, stop and run `first-run-setup` instead - they have not been onboarded yet.

---

## STEP 2 - Introduction (Mode 1 only - skip on Mode 2)

Read the skill counts from `~/.loup/selr-ai/workshop-kit/skills/SKILLS-LIST.md`. The three numbers you need live inside markers:
- Total: `<!-- skills-audit:total -->N<!-- /skills-audit:total -->`
- Core: `<!-- skills-audit:core -->N<!-- /skills-audit:core -->`
- Advanced: `<!-- skills-audit:advanced -->N<!-- /skills-audit:advanced -->`

Use whatever numbers are in the file right now - never hardcode a count in your reply. These numbers change as the kit evolves.

Address them by name and say something like:

> "Hi [Name]! Let me show you what your assistant can do for [their business].
>
> You have [total] skills installed in total - but most business owners only need the [core count] starter ones to begin with. I'll walk you through those, then pick 3 that I think fit you best."

---

## STEP 3 - Walk through the starter skills (Mode 1 only - skip on Mode 2)

Read `~/.loup/selr-ai/workshop-kit/skills/SKILLS-LIST.md` and present only the rows whose **Tier** column is `CORE`. Never surface `ADVANCED` or `DEV-ONLY` skills in this step.

Group the CORE skills under the same category headings they appear under in the file (for example: AI & Automation, Content & Writing, Research & Intelligence, Sales & Growth, Strategy & Business, Process).

For each CORE skill, show:
- Its name in plain text (no code formatting, no backticks)
- One plain-English sentence explaining what it does - use the "What It Does" column as your base, rewrite for clarity if the column text is too technical
- A concrete, real-world example tailored to their business - adapt the "Example Prompt" column to their industry and customer type

Keep each skill description to 2 lines maximum.

---

## STEP 4 - Give 3 personalised recommendations (both paths)

Use the business context you already know from memory.

Read `~/.loup/selr-ai/workshop-kit/skills/SKILLS-LIST.md` and consider only rows whose **Tier** column is `CORE`. Pick 3 skills that best match:
- Their biggest frustration
- The tools they already use
- What would feel like a win today

Selection rules:
- All 3 picks must be CORE. Never pick ADVANCED or DEV-ONLY here.
- Do not rely on skill names you remember from previous sessions - always read them fresh from `SKILLS-LIST.md` for this conversation. Skill names and tier assignments change between kit versions.
- If the same skill could fit two of their criteria (for example both their frustration and their win), prefer it over a skill that only matches one.
- If the user's profile is thin (e.g., missing tools or win), pick 3 skills that cover the broadest range of starter value - writing, research, and one strategy skill.

### Mode 1 opening line (user asked directly)

Before the 3 recommendations, say:

> "Based on what you told me - [one-sentence summary tying their business + biggest frustration + win] - here are the 3 I'd start with."

### Mode 2 opening line (proactive, right after a live demo)

Before the 3 recommendations, say:

> "Quick shortlist before we wrap up. Based on what you told me about [their business / biggest frustration], here are 3 more I'd pick for you - ignore the rest for now, come back to those later."

### Recommendation format (same for both paths)

For each of the 3 picks:

RECOMMENDED: [skill name in plain text]

Why this fits you: [one sentence that references their specific situation - use their business name, their frustration, or their win]

Try it now: [a specific first task, based on the "Example Prompt" column from SKILLS-LIST.md, rewritten so it uses their industry, customer type, or tools]

Example (for a marketing agency owner who said proposals take up too much time):

RECOMMENDED: sales-automator

Why this fits you: You said proposals take up half your week - this one drafts outreach and sales follow-ups in under 2 minutes.

Try it now: "Write a cold outreach email to a restaurant owner who needs help with their social media strategy."

Only give 3 recommendations. Do not list more. Keep each one to 3 lines.

---

## STEP 5 - Offer to run one now (both paths)

After the 3 recommendations, ask ONE question:

> "Which one do you want me to try first? Just say the name, or pick 1, 2, or 3."

Wait for their answer. Do not give them more information until they choose.

When they pick one, run that skill immediately using the business context you already know about them from memory. Do not ask them to repeat anything they've already told you.

---

## If they ask "what about all the other skills?"

Read the advanced count marker from `~/.loup/selr-ai/workshop-kit/skills/SKILLS-LIST.md` (see Step 2) and say:

> "There are also [advanced count] advanced skills - deeper automation, integration setup, and technical work. Just tell me what you're trying to do and I'll pull in the right one when it fits."

Do not list the advanced skills. Only surface an advanced skill later when the user describes a task that matches one.
