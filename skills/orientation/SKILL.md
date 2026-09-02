---
name: orientation
description: "Runs a first-time user's orientation - an install sanity check, a quiet setup scan, eight onboarding questions saved to a reusable business profile, one live demo on their real business, and three personalised skill picks - then records that onboarding is done. Use when the install manifest says onboarded is false, or when the user asks to redo their onboarding."
---

# Orientation

<!-- Path conventions: every path here resolves relative to the user's home folder. ~/.claude/ means $HOME/.claude/ on Mac and Linux, and %USERPROFILE%\.claude\ on Windows. There is no workspace folder - the assistant is installed globally and works from any folder. Never hardcode an absolute path or a username. Shell commands in fenced bash blocks may use ~/ and $HOME natively; PowerShell blocks must use $HOME or $env:USERPROFILE. -->

This is the first real conversation a non-technical business owner has with their assistant. Setup already ran and installed everything - **this skill installs nothing**. It checks that the install landed, quietly scans what is already set up, gets to know the user and **saves what it learns to a profile on their computer**, shows them one thing working on their own business, and points them at what to try next.

Work through the phases in order. Do not add checks beyond the ones listed here, and never start installing or repairing software: if the sanity check in Phase 1 fails, say so plainly and send the user back to the setup prompt.

**Why the profile matters.** Later kit steps - most importantly the dashboard build, which runs hours after this conversation in a different session - read `~/.claude/about-you/` as their only source of who this person is. Conversation memory does not reach them. A rich profile is what lets those steps infer instead of interrogate: the more this skill captures now, the fewer questions the user faces later.

## When this skill runs

Two entry points:

1. **Automatically, on the first message of any new session**, when `~/.claude/selr-kit-manifest.json` has `"onboarded": false` - and that applies even if the user only said "hi". Do not greet generically and carry on; run Phase 1 through Phase 4.
2. **On request**, when the user asks to redo their onboarding or says the assistant has forgotten who they are. Re-running the whole skill is safe: an existing profile becomes prefills, and the re-run updates it in place.

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

Note to the assistant: Claude's native memory still picks up what the user says, but memory is conversational only - later kit steps cannot read it and it does not move between machines. The record the rest of the kit reads is the profile folder this skill writes in Phase 2. Knowing something "from memory" is never a reason to skip a question or a write.

---

## PHASE 2 - SCAN, THEN ONBOARDING

### Step 1 - The quiet scan

Before asking anything, take one silent read of what is already set up. Never present this as a report; it exists to prefill answers and cut questions, not to impress. Three checks - the same three detection authorities the dashboard kit's scan uses - plus a profile check:

1. **Connected tools (MCP servers).** Read the **keys** of the `mcpServers` object in `~/.claude.json`, `~/.mcp.json`, and the Claude Desktop config (Mac: `~/Library/Application Support/Claude/claude_desktop_config.json`; Windows: `%APPDATA%\Claude\claude_desktop_config.json`). Take server names only - never read any value out of these files; the values can hold tokens.
2. **CLI sign-ins (auth-file probes).** File existence only, never commands - some CLIs start a login flow when probed. A tool counts as signed in when its credential file exists and mentions a credential: `~/.config/gh/hosts.yml` containing `oauth_token` (GitHub); a Vercel `auth.json` containing `token` (at `~/Library/Application Support/com.vercel.cli/`, `~/.local/share/com.vercel.cli/`, or `~/.vercel/`); `~/.config/stripe/config.toml` containing `_mode_api_key` (Stripe). Test that the pattern appears; never quote, store, or repeat the value.
3. **Available connectors.** Folder names ending `-connector` in `~/.claude/skills/`. These ship with the kit, so a folder on disk means *available to connect*, never *connected*.
4. **Existing profile.** If `~/.claude/about-you/profile.json` exists, read it (and `profile.md`). Every field it holds becomes a prefill: shown back for a quick confirmation, never silently skipped - and a confirmed prefill is still written back.

The scan suppresses redundant *asking*, never redundant *saving*.

### Step 2 - The store

The profile lives in `~/.claude/about-you/` - the user's own asset, not a Selr file. Create it now if it is missing, with three parts:

- `profile.json` - the structured index: only what code needs (names, URLs, colour values, the team roster, flags).
- `profile.md` - the substance: the user's answers **verbatim and unsummarised**, plus your own short interpretation notes. This is the richest input later steps get; never trim their words down.
- `assets/` - logo files and brand documents. Orientation asks for the website only, but anything the user volunteers (a logo file, a brand PDF) is saved here and referenced from `profile.json`.

One rule keeps the pair honest: **no field lives in both files.** JSON is the index, markdown is the substance, so they can never disagree.

`profile.json` follows this shape:

```json
{
  "version": 1,
  "capturedAt": "<ISO timestamp>",
  "person": { "name": "", "email": "", "businessStatus": "owner" },
  "goals": [""],
  "businesses": [{
    "kind": "business",
    "name": "", "website": "",
    "team": [{ "name": "", "role": "", "email": "" }],
    "software": [""],
    "brand": { "logo": "", "brief": "", "colours": null, "derived": null }
  }]
}
```

- `businessStatus` is one of `owner | employee | pre-business | hobbyist | exploring`; `kind` is `business` or `workplace` (see the no-business branch).
- `brand.colours` holds colours only when the **user states them** (or hands over a brand document that does). Orientation records raw facts; it never derives.
- `brand.derived` belongs to the dashboard build, which writes its derivation there later. Never write it, and on a re-run never touch an existing `derived` block or anything marked `_lockedByUser`.

**Write incrementally - after every answer**, not at the end. A half-filled profile beats nothing when a workshop session gets interrupted. On first write, also add one key to `~/.claude/selr-kit-manifest.json` if it is not already there: `"aboutYou": "~/.claude/about-you"`. Read the manifest, add that one key, write it back - never rewrite the manifest wholesale and never drop its other keys.

**Privacy rules for everything in the folder:** no tokens, secrets, or absolute filesystem paths, ever. Emails are stored (they identify who gets a login later) but must never end up in anything that deploys or publishes. Never copy the folder, or any file in it, into a project or deploy folder.

### Step 3 - The questions

Open with the framing line:
> "Before we start, one thing: don't worry about being neat. The more you ramble the better I get - waffle away, I'll sort it out."

Then ask these 8 questions, one at a time, conversationally, per the Communication Rules in the assistant's instructions. Acknowledge each answer naturally, save it, and move on. Breadth over depth: take whatever they give and keep moving - never turn one question into an interrogation. The whole phase should sit inside a few minutes.

**Q1 - You** *(quick fact → `person.name`, `person.email`)*
> "First up, what's your name, and what's the best email for you? I'll use that to set you up properly later."

**Q2 - The business** *(open narrative → `businesses[0].name`, `.website`; the story verbatim into `profile.md`)*
> "Tell me about your business - what's it called, what do you actually do, and who do you do it for? Don't hold back, the more you tell me the better everything I build for you gets. And if you've got a website, drop the link in and I'll take a look myself."

If they give a URL, fetch it now: note the services, tone, and anything brand-shaped in `profile.md`. Never make them describe what the site already says - confirm, don't re-ask.

**Q3 - Who's in it** *(quick fact → `businesses[0].team[]` as `{name, role, email}`)*
> "Is it just you, or have you got a team? If there are others, give me their names and what each of them does."

If there is a team, follow up: "And their emails? That way I can get them logged in alongside you when we build this out." Emails are skippable - take names and roles rather than stalling; email can be filled in later.

**Q4 - Where it hurts** *(open narrative → verbatim into `profile.md`)*
> "What's the most frustrating part of running it right now? The thing that eats your week, or the bit you keep putting off. Give me the whole story - chasing quotes, invoices, whatever it is."

**Q5 - How it runs** *(quick-ish → `businesses[0].software[]`)*
> "What software do you use to run the business? Things like Gmail, Xero, Facebook, Instagram - whatever you've got. And the low-tech stuff counts too: spreadsheets, the notebook on the desk."

If the scan already found connected tools, lead with them instead of asking cold - "I can see you've already got [tools] hooked up - what else do you use?" - and save the confirmed full list.

**Q6 - What you want** *(open narrative → short phrases into `goals[]`; the full answer verbatim into `profile.md`)*
> "If you could have anything built for you - the thing you've thought 'someone should just make this' - what is it? A few ideas is fine, big or small."

**Q7 - Brand** *(quick; ask ONLY if Q2 produced no website)*
> "Have you got a logo or brand colours you'd want me to use? If not, no drama - I'll pick something sharp and you can change it later."

Stated colours go to `brand.colours`; a volunteered logo or brand document is saved into `assets/` and referenced from `brand.logo`. If they have **no brand at all**, ask them to describe the look they're after - colours, feel, other sites or brands they like - and capture that description word-for-word in `profile.md` with the gist in `brand.brief`. That description drives their generated design system just like a real brand would, so treat it as an answer worth having, not a shrug.

**Q8 - Anything else** *(open → verbatim into `profile.md`)*
> "Anything else I should know about you or the business? Doesn't have to be tidy."

#### The no-business branch

Trigger on any "I don't have a business / I work for X / just curious" at Q2. Do not force the business frame:

> "No worries at all, that's a really common one here - plenty of people come along to use this for work, or for something they're thinking about starting. So tell me about you instead: what do you do day to day, and what made you come along today?"

Then run Q4 (frustration → "in your work / in your week"), Q5 (tools) and Q6 (what you'd want built) unchanged; skip Q3 and Q7. Set `person.businessStatus` to `employee`, `pre-business`, `hobbyist`, or `exploring` - the dashboard generator uses it to swap sections (no money or sales panels for non-owners) instead of rendering empty ones. An employee's **workplace still gets captured as a business entry** with `"kind": "workplace"` - name, what they do there, the tools it runs on - so the work context is never lost and they still get a dashboard about something real.

### Step 4 - Close the phase

After the last question, say:
> "Done! I've saved all that to your computer so I don't have to ask again. Let me show you something useful right away."

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
- Bias the 3 picks toward whichever of their onboarding answers was most specific - their biggest frustration, the software they run on, or what they asked to have built.
- If the user already showed strong interest in a particular area during the live demo, bias one of the 3 picks toward that area.
- Do not volunteer the total number of skills installed - the problem this phase solves is "the list feels overwhelming", and naming the big number works against that. If the user asks outright, count the folders in `~/.claude/skills/` and give them that live number; never quote a figure from memory or from a doc.

### Step 3 - If they pick one

When the user picks one of the 3 (by name or by number 1/2/3), run it immediately using the business context already captured in this conversation and the profile. Do not ask them to repeat anything they've already told you.

### Step 4 - Mark onboarding complete (set the flag)

This is the FINAL action of orientation. After Phase 4 has surfaced the shortlist - and regardless of whether the user has picked one yet, the shortlist itself counts as "orientation done" - set `"onboarded": true` in `~/.claude/selr-kit-manifest.json`.

Read the file, change that one value, write it back. Never rewrite the manifest from scratch and never drop the other keys: `kitHome`, `installPath`, `kitVersion`, `installedAt`, `installMode`, the `aboutYou` pointer and the whole `skills` map are the install's receipt, and updates and uninstall both read them.

Do this silently - do not narrate it to the user. If the flag is already `true` (the user asked to redo their onboarding), leave it `true`.

---

## Common Problems

**Skills installed but not showing up**
- Close and reopen Claude Desktop. Skills are loaded when a new session starts.

**The user says they have already done this before**
- Their manifest flag was probably never set, or the manifest was replaced. Check `~/.claude/about-you/profile.json`: if it exists, show back what it holds and offer a quick confirm-and-update pass instead of the full questions; if it does not, offer to run the questions or skip straight to the shortlist. Either way, set `"onboarded": true` at the end.

**The onboarding got interrupted partway**
- Nothing is lost - the profile saves after every answer. On the next run the answered questions come back as prefills to confirm in seconds, and the conversation picks up at the first unanswered one.

**Anything about installing, repairing, or updating the kit**
- Not this skill's job. The setup prompt in `docs/start/setup.md` does all of it, and it is safe to re-run - it detects on its own whether it is installing, updating, or migrating, and keeps anything the user has customised.
