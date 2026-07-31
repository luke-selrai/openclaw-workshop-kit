---
name: orientation
description: "Runs a first-time user's orientation - a quick install sanity check, seven onboarding questions, one live demo on their real business, and three personalised skill picks - then records that onboarding is done. Use when the install manifest says onboarded is false, or when the user asks to redo their onboarding."
---

# Orientation

<!-- Path conventions: every path here resolves relative to the user's home folder. ~/.claude/ means $HOME/.claude/ on Mac and Linux, and %USERPROFILE%\.claude\ on Windows. There is no workspace folder - the assistant is installed globally and works from any folder. Never hardcode an absolute path or a username. Shell commands in fenced bash blocks may use ~/ and $HOME natively; PowerShell blocks must use $HOME or $env:USERPROFILE. -->

This is the first real conversation a non-technical business owner has with their assistant. Setup already ran and installed everything - **this skill installs nothing**. It checks that the install landed, gets to know the user, shows them one thing working on their own business, and points them at what to try next.

Work through the phases in order. Do not add checks beyond the ones listed here, and never start installing or repairing software: if the sanity check in Phase 1 fails, say so plainly and send the user back to the setup prompt.

## When this skill runs

Two entry points:

1. **Automatically, on the first message of any new session**, when `~/.claude/selr-kit-manifest.json` has `"onboarded": false` - and that applies even if the user only said "hi". Do not greet generically and carry on; run Phase 1 through Phase 4.
2. **On request**, when the user asks to redo their onboarding or says the assistant has forgotten who they are. Re-running the whole skill is safe.

Phase 4 Step 4 sets `"onboarded": true` in the manifest as this skill's final action. That flag is what stops orientation re-triggering on every future "hello", so never set it without having actually walked the phases. A user who migrated from an older install arrives with the flag already `true` and never sees this skill - that is deliberate; they were onboarded long ago.

---

## PHASE 1 - SANITY CHECK

Say:
> "Hi! I am your AI Business Assistant, built by Selr AI. Let me take one quick look at your setup, then I will get to know you and your business."

Read `~/.claude/selr-kit-manifest.json` - the receipt setup wrote. One read, no repairs:

- **It parses and its `skills` map has entries** → spot-check that three of those named skill folders actually exist in `~/.claude/skills/`. All three there → "Everything's in place." Move to Phase 2.
- **It is missing, does not parse, has an empty `skills` map, or a spot-checked folder is not on disk** → setup did not finish. Do not try to fix it and do not install anything. Tell the user plainly what you found and what to do:
  > "Your setup didn't quite finish - some of your skills aren't on your computer. The fix is to run the setup prompt again; it is safe to re-run and it will keep anything you have already customised."

  Then stop. Everything below this point needs a working install.

Keep this quiet when it passes: one short line, not a report.

Note to the assistant: Claude's native memory captures everything the user tells you, across sessions. There is no workshop-managed memory file to write - do not create one.

---

## PHASE 2 - ONBOARDING

If you already know the user's name and business from memory, skip this phase entirely and greet them by name. Otherwise ask these 7 questions, one at a time:

1. "What is your first name?"
2. "What is your business called, and what do you do in one sentence?"
3. "Who are your customers - who do you help?"
4. "What is the biggest frustration or problem in your business right now?"
5. "What apps or tools do you use? For example: Gmail, Facebook, Xero, Instagram."
6. "How do you prefer I communicate - casual and friendly, or professional and direct?"
7. "What would feel like a win for you from today?"

Ask them conversationally, one at a time, per the Communication Rules in the assistant's instructions. Memory retains everything they tell you automatically - you do NOT need to write anything to disk or "save a profile note". Acknowledge each answer naturally and move to the next question.

After the last question, say:
> "Done! I'll remember all of this from now on. Let me show you something useful right away."

→ Move to Phase 3.

---

## PHASE 3 - LIVE DEMO

Pick based on what they told you in Phase 2:

**Marketing/content challenge:**
> "Let me research your competitors right now. Who is your main competitor? I'll pull together a short snapshot of where they sit and where you could stand out."
Use skills: `competitor-alternatives`, then `deep-research` for a deeper multi-source dive. Both run on Claude's built-in web search, so there is nothing extra to install and no API key to set up.

**Sales/leads challenge:**
> "Let me write you a personalised outreach email right now for your exact type of customer."
Use skills: `copywriting`, `email-composer`, `avoid-ai-writing`

**Too busy/overwhelmed:**
> "Let me map out which tasks in your business I could take off your plate this week."
Use skills: `brainstorming`. If the user has the Superpowers plugin installed, follow on with `superpowers:writing-plans` to produce the formal plan; otherwise walk the plan through in plain conversation and offer to install Superpowers later.

→ When the live demo is visibly done (the user has seen the output and acknowledged it), move to Phase 4 immediately - do not wait to be asked.

---

## PHASE 4 - PERSONALISED SHORTLIST

The live demo has just finished. The user has now seen one real, working skill applied to their business. This is the moment to surface the next 3 skills they should try - not the full catalogue, just a shortlist that matches what they told you during onboarding.

**Do NOT ask the user whether they want recommendations.** Surface them immediately. The point of this phase is to cut a long list down for them, not to advertise that a long list exists.

### Step 1 - Run the shortlist

Run the `skills-discovery` skill in **Mode 2** mode. That means: skip its Step 2 (intro) and Step 3 (full walkthrough of all starter skills) entirely, jump straight to its Step 4 (3 personalised picks using the Mode 2 opening line), and finish with its Step 5 (asking which one to try first).

The `skills-discovery` skill already contains the full selection logic, opening line, and recommendation format for Mode 2. Follow that skill's instructions directly - do not rewrite them here.

### Step 2 - Guardrails

- Exactly 3 recommendations. Not 2, not 5, not the whole catalogue.
- Only pick from rows marked `CORE` in `<kit home>/skills/SKILLS-LIST.md` - the kit home is recorded in the manifest and in the Selr block of `~/.claude/CLAUDE.md`. Never surface ADVANCED or DEV-ONLY skills in this phase.
- Bias the 3 picks toward whichever of their onboarding answers was most specific - their biggest frustration, the tools they use, or their "win today" answer.
- If the user already showed strong interest in a particular area during the live demo, bias one of the 3 picks toward that area.
- Do not volunteer the total number of skills installed - the problem this phase solves is "the list feels overwhelming", and naming the big number works against that. If the user asks outright, count the folders in `~/.claude/skills/` and give them that live number; never quote a figure from memory or from a doc.

### Step 3 - If they pick one

When the user picks one of the 3 (by name or by number 1/2/3), run it immediately using the business context already in memory. Do not ask them to repeat anything they've already told you.

### Step 4 - Mark onboarding complete (set the flag)

This is the FINAL action of orientation. After Phase 4 has surfaced the shortlist - and regardless of whether the user has picked one yet, the shortlist itself counts as "orientation done" - set `"onboarded": true` in `~/.claude/selr-kit-manifest.json`.

Read the file, change that one value, write it back. Never rewrite the manifest from scratch and never drop the other keys: `kitHome`, `installPath`, `kitVersion`, `installedAt`, `installMode` and the whole `skills` map are the install's receipt, and updates and uninstall both read them.

Do this silently - do not narrate it to the user. If the flag is already `true` (the user asked to redo their onboarding), leave it `true`.

---

## Common Problems

**Skills installed but not showing up**
- Close and reopen Claude Desktop. Skills are loaded when a new session starts.

**The user says they have already done this before**
- Their manifest flag was probably never set, or the manifest was replaced. Ask what they would like: skip to the shortlist and set the flag, or run the questions again. Either way, set `"onboarded": true` at the end.

**Anything about installing, repairing, or updating the kit**
- Not this skill's job. The setup prompt in `docs/start/setup.md` does all of it, and it is safe to re-run - it detects on its own whether it is installing, updating, or migrating, and keeps anything the user has customised.
