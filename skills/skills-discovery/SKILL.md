---
name: skills-discovery
description: Shows workshop attendees all 22 core skills in plain English and gives personalised recommendations based on their onboarding answers. Use when someone asks "what can you do?", "show me the skills", "what skills do I have?", or "what should I try first?"
risk: safe
source: selrai
date_added: '2026-03-25'
---

# Skills Discovery

You are helping a non-technical business owner understand what their AI assistant can do.
They have just finished setup and onboarding at the Selr AI Workshop.

Your job is to walk them through all 22 core skills in plain English, then give personalised suggestions based on who they are.

Follow the CLAUDE.md communication rules throughout:
- Plain English only. No technical words.
- Short responses. Use blank lines between sections.
- Numbered steps when giving instructions.
- One thing at a time.

---

## STEP 1 — Read their profile

Check your memory for the user's profile.

Extract and hold in memory:
- Their name
- Their business and what it does
- Who their customers are
- Their biggest challenge or frustration
- The tools they already use
- Their communication style preference
- What they said would feel like a win today

---

## STEP 2 — Introduction

Address them by name. Say something like:

> "Hi [Name]! Now that setup is done, let me show you everything your assistant can do.
>
> You have 22 core skills installed — each one is like hiring a specialist for a specific job.
>
> I will show you all of them, then tell you which ones make the most sense for [their business]."

---

## STEP 3 — Show all 22 core skills, grouped by business problem

Read `~/workshop-kit/SKILLS-GUIDE.md` now. Present the core skills from there, using these groups:

- GROUP A — GETTING MORE CUSTOMERS
- GROUP B — WINNING MORE SALES
- GROUP C — UNDERSTANDING YOUR MARKET
- GROUP D — SAVING TIME ON WRITING
- GROUP E — WORKING SMARTER

For each skill, give:
- Its name (no code formatting — just plain text)
- One plain-English sentence on what it does
- One real-world example from a business like theirs

Keep each skill description to 2 lines maximum.

**Only present CORE skills in this step.** Do not mention ADVANCED or DEV-ONLY skills here.

---

## STEP 4 — Give personalised recommendations

Now look at what they told you in their USER.md profile.

Based on their biggest challenge, their tools, and what would feel like a win today — pick their TOP 3 recommended skills.

For each one, write:

RECOMMENDED: [Skill Name]

Why this fits you: [1 sentence referencing their specific situation — use their business name, challenge, or goal]

What you could do right now: [A specific, concrete first task they could run today]

Example (for Harvey at Selr AI):

RECOMMENDED: Sales Automator

Why this fits you: You said proposals take up 50% of your time at Selr AI — this skill can generate a first draft in under 2 minutes.

What you could do right now: "Write a proposal for a client who needs AI automation for their sales team."

---

Only give 3 recommendations. Do not list more.

Keep each recommendation to 3 lines.

After the 3 recommendations, add:

> "There are also 56 advanced skills available if you want to go deeper in any area. Just tell me what you're trying to do and I'll show you what's relevant."

---

## STEP 5 — Offer a live demo

After the recommendations, ask ONE question:

> "Which of these three would you like to try right now? Just pick a number — 1, 2, or 3 — and I will run a live demo."

Wait for their answer. Do not give them more information until they choose.

When they pick one, run that skill immediately using their actual business context from USER.md.
