# Uninstall - remove the Selr AI assistant

This is the **only** description of how the kit uninstalls itself. The `uninstall` skill is a
one-line pointer to this file, so there is nothing to keep in step with it. Follow the steps
here in order.

Read this as the assistant, with the user watching. Narrate in plain English, one step at a
time, and never delete anything before the confirmation gate in Step 3.

**What uninstalling is for:** taking the assistant's instructions back out of the global
Claude config and removing the pile of installed skills. That is the whole job. It is not a
general clean-up of everything the assistant ever helped set up, and it deliberately leaves
Claude Code itself completely alone.

## Step 1 - Read the install record

Everything below is driven by `~/.claude/selr-kit-manifest.json` - the record the setup wrote
of exactly what it put on this machine. Read it first and keep it in hand for the whole run.

From it you get:

- `kitHome` - the absolute path the kit was downloaded to. **Always use this value. Never
  guess a kit folder from its name.**
- `skills` - one entry per skill the kit installed: the fingerprint of its `SKILL.md`, and
  `customised: true` on any the user edited and the setup kept.

If the file is missing or will not parse, do not improvise from here - go straight to
[If there is no install record](#if-there-is-no-install-record) at the end of this document.

## Step 2 - Work out the three lists (nothing is deleted yet)

Sort everything into three groups. Read only in this step.

**A. To delete.** Exactly this, and nothing else:

1. The kit's block in the global `~/.claude/CLAUDE.md`, between the
   `<!-- selr-kit:begin -->` and `<!-- selr-kit:end -->` markers.
2. The assistant's instructions file, `~/.claude/selr-assistant.md`.
3. The kit folder, at the `kitHome` path from the install record.
4. Every kit skill in `~/.claude/skills/` whose installed `SKILL.md` still matches its
   fingerprint in the install record - the ones the user never edited. This includes
   `orientation` and `uninstall` itself.

   The fingerprints are SHA-256 hashes of `SKILL.md`. Take them in one pass, not a command
   per skill:

   ```
   find ~/.claude/skills -name SKILL.md -exec shasum -a 256 {} +
   ```

   A skill marked `customised: true` whose content now matches the recorded hash goes in
   **list B** - keeping is the safe answer, and the receipt says the user has edited this
   skill before.
5. The kit's plugin and its marketplace registration.
6. The install record itself, `~/.claude/selr-kit-manifest.json`.

**B. Kept because the user changed it.** Any kit skill whose installed `SKILL.md` does not
match its fingerprint, or that is marked `customised: true`. The user edited it, so it is
their work now, not the kit's. Keep the folder exactly as it is and list it in the report.

**C. Left in place on purpose.** Report these, do not offer to remove them:

- Anything in `~/.claude/skills/` that the install record does not list - those are the
  user's own skills, or skills from somewhere else entirely.
- Everything the assistant remembers about the user - memory is theirs and long outlives
  the kit.
- Any of the older-setup folders, if one is still on disk. These are the
  **legacy-workspace candidate list** - two canonical paths, defined once in ADR-0001 §6 and
  listed in the setup document's Step 1.1 under "older-setup folders". Open
  `<kitHome>/docs/start/setup.md` and read the two paths from there rather than working them
  out; check both, report any that exists, leave it untouched, and do not go hunting
  anywhere else.
- The browser tool (Playwright), its saved sign-in profile, and the browser it downloaded.
- The four power-user skills: `grill-me`, `handoff`, `diagnosing-bugs`, `teach`. They came
  from a different library and are useful without this kit.
- Every connection the user set up to an outside tool, and the saved sign-in details that go
  with them.
- Node.js, Claude Code, and Claude Desktop.

If the user wants anything in group B or C gone as well, that is a separate, explicit ask -
they can tell you afterwards. Never fold it into this run.

**Last, and do not skip it: take an inventory of the kit's own files.** Write it to a file -
it runs to thousands of lines across a couple of hundred skills, and it has to survive the
confirmation gate and everything after it:

```
find "<kitHome>/skills" -type f > /tmp/selr-kit-inventory.txt
```

Step 4 deletes the kit folder *before* it removes any skill, so this is the last moment that
list exists. Without it, Step 4.4 cannot tell a file the kit installed from a file the user
added, and a whole folder of the user's notes goes with the skill. Take the inventory now,
even though it feels early.

The inventory holds kit-side paths; the files to delete are the install-side ones. They differ
only in the prefix, so `<kitHome>/skills/<name>/<rest>` is the file
`~/.claude/skills/<name>/<rest>`.

## Step 3 - The one confirmation gate

Show all three lists, grouped and named, in one message: **what will be deleted**, **what is
kept because they changed it**, **what is left alone**. Name real paths and real skill names,
counted, not "your skills".

Then ask once:

> "Shall I go ahead?"

That is the only question in the whole uninstall. If they say yes, do everything in Step 4
without stopping to ask again. If they say no, change nothing and say so. Nothing is ever
deleted silently or without this gate.

## Step 4 - Remove, in this order

**Read all of Step 4 before you start it.** Step 4.3 deletes the kit folder, and this document
lives in it - after that point nothing here can be re-read. Take in the whole step, and the
Step 2 inventory file, while they still exist.

The order matters: the install record is what tells you where everything is, so it goes last.
If a step fails, say so plainly, carry on with the rest, and list the failure in the report.

1. **The block in the global `~/.claude/CLAUDE.md`.** Delete the marker lines and everything
   between them. **Touch nothing outside the markers** - the rest of that file is very often
   the user's own hand-written instructions, and it must come out of this byte-identical.
   If the markers are not there, say so and move on. If the file is left empty apart from
   blank lines, leaving the empty file is fine.
2. **`~/.claude/selr-assistant.md`.**
3. **The kit folder** at the `kitHome` path. Before deleting, confirm it looks like the kit:
   it must contain both `skills/` and `my-assistant/CLAUDE.md`. If it does not, leave it and
   report it - never delete a folder on its path alone.
4. **The unmodified kit skills** from list A.4, out of `~/.claude/skills/`. Skip every skill
   in list B. Anything in a skill's folder that the kit did not ship is the user's - notes, a
   script - so do not delete these folders outright. Use the Step 2 inventory and work in one
   uniform pass, with no per-folder judgement call:

   1. Delete, from each of those folders, exactly the files that appear in the Step 2
      inventory for that skill - reading each inventory line as its install-side path.
   2. Then delete each folder that is now empty.
   3. Any folder still holding something is holding the user's own file. Keep it, and name it
      and the file in the report.
5. **The plugin and its marketplace registration:**
   ```
   claude plugin uninstall routine-installer-plugin
   claude plugin marketplace remove selrai-workshop-kit
   ```
   "Not installed" or "not found" here is success, not an error.
6. **The install record**, `~/.claude/selr-kit-manifest.json`. This is the last thing to go.

## Step 5 - The report

Say what actually happened, in three short groups: removed, kept because they changed it,
left alone. Include anything that failed and what is still on disk because of it.

Then close with a fresh-session note and this exact line:

> Start a new session for the change to take effect. Claude Code itself is untouched - you
> can keep using it.

## Removing just some skills

The user can also ask for a specific skill or two to go, rather than the whole kit
("get rid of the ad-creative skill"). That works at skill granularity only - one or more skill
folders out of `~/.claude/skills/` - and nothing else in this document happens: the block,
the instructions file, the kit folder and the install record all stay.

Nothing is left behind to remember the removal. Tell them so plainly:

> "That's removed. The next time you update the kit it will come back - if you want it gone
> for good, just tell me again after an update."

## If there is no install record

Without `~/.claude/selr-kit-manifest.json` you cannot prove what the kit installed, so this is
a best-effort pass. Say that up front, then work the checklist below and **report every line
you could not verify** rather than assuming it was clean.

The confirmation gate in Step 3 still applies - show the list, ask once, then proceed.

1. **The block in `~/.claude/CLAUDE.md`** - search for the `<!-- selr-kit:begin -->` /
   `<!-- selr-kit:end -->` markers and remove that block only, exactly as in Step 4.1.
2. **`~/.claude/selr-assistant.md`** - delete it if it is there.
3. **The plugin and marketplace** - the same two commands as Step 4.5, by name:
   `routine-installer-plugin` and `selrai-workshop-kit`.
4. **Kit skills in `~/.claude/skills/`** - without fingerprints you cannot tell an edited
   skill from an untouched one. **Do item 4 before item 5**: item 5 deletes the kit folder,
   which is the only copy you can compare against.

   First find the kit folder (item 5 below says where it is) and take the same inventory
   Step 2 takes, for the same reason - it is what keeps a user's own file from going out with
   the skill:

   ```
   find "<kit folder>/skills" -type f > /tmp/selr-kit-inventory.txt
   ```

   Then decide which skills are unmodified, with **two commands and one comparison**, never a
   loop that runs a command per skill - there are a couple of hundred skills, and the
   per-skill shape takes long enough to look like it has hung:

   ```
   find "<kit folder>/skills" -name SKILL.md -exec shasum -a 256 {} +
   find ~/.claude/skills -name SKILL.md -exec shasum -a 256 {} +
   ```

   Read both lists once, and every skill whose two hashes agree is unmodified.

   Remove those skills with **exactly the three-substep pass in Step 4.4** - delete only the
   files in the inventory, then drop the folders that are now empty, then keep and report
   whatever is left. Do not delete a skill folder outright here either.

   Where you have nothing to compare against, **keep the skill and report it** - re-installing
   a skill later is easy, and deleting the user's own edit is not.
5. **The kit folder** - it is at one of two paths, so check both:
   `~/claude-workshop-kit` and `~/.loup/selr-ai/workshop-kit`. Apply the same test as Step
   4.3 - it must contain `skills/` and `my-assistant/CLAUDE.md` - and leave anything that
   fails it alone. This is the last thing to go, because item 4 needs it.

Everything in list C is still left alone here, unchanged.
