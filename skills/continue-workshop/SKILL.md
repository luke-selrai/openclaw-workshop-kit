---
name: continue-workshop
description: Use when a workshop attendee has finished a phase of the SelrAI workshop and is ready to move to the next one. Triggers on "what's next", "I'm ready for the next part", "continue the workshop", "next phase", "we finished this segment", "move on to phase 2", "move on to phase 3", "start the next module". Detects which workshop phases are already installed, then installs the next kit and hands off to it.
---

# Continue Workshop

<!-- Path conventions: paths resolve relative to the user's home folder. The user's WORKSPACE — where the per-workspace CLAUDE.md sits — is $HOME/Desktop/my-assistant/ on all platforms. Workshop kits clone into $HOME/ (e.g. $HOME/workshop-kit/, $HOME/workshop-v3-building/). Skills install into $HOME/.claude/skills/, subagent definitions into $HOME/.claude/agents/. Resolve every path relative to the home folder — never hardcode an absolute path or a username. Shell commands in fenced bash blocks may use ~/ and $HOME natively; PowerShell blocks must use $HOME or $env:USERPROFILE. -->

The SelrAI workshop runs in **three phases**, delivered across one workshop. Every attendee does all three. This skill carries the attendee from one phase to the next — no hunting for prompts, no switching folders. They finish a segment, they say "what's next", and the next kit installs itself.

Apply the Communication Rules from the workspace CLAUDE.md: **one step at a time, plain English, narrate before you act.** The person is a business owner, not a developer.

## The three phases

| Phase | What it teaches | Repo | Clones to |
|---|---|---|---|
| 1 | The AI Business Assistant — skills, memory, connectors | `claude-workshop-kit` | `~/workshop-kit/` |
| 2 | Automation — keeping your assistant working 24/7 | `claude-workshop-v2-automation` | `~/workshop-v2-automation/` |
| 3 | Building apps and websites with a team of agents | `claude-workshop-v3-building` | `~/workshop-v3-building/` |

If this skill is running, **Phase 1 is already installed** — it ships inside the Phase 1 kit.

## Step 1 — Work out which phase is next

Read the workspace CLAUDE.md at `~/Desktop/my-assistant/CLAUDE.md`. Each phase, when it installs, adds its own section to that file:

- A section mentioning **Phase 2** → Phase 2 is installed.
- A section mentioning **Phase 3** → Phase 3 is installed.

The **next phase** is the lowest-numbered phase that is NOT yet installed. Cross-check for Phase 3: if `~/.claude/agents/frontend-builder.md` exists, Phase 3 is installed even if its section is missing from CLAUDE.md.

- If Phase 2 is not installed → the next phase is **Phase 2**.
- If Phase 2 is installed but Phase 3 is not → the next phase is **Phase 3**.
- If all three are installed → tell the attendee they have completed the full workshop, congratulate them warmly, and stop here.

## Step 2 — Confirm with the attendee

Tell the attendee which phase is next and what it covers (use the table above — one short, plain sentence). Then ask them to confirm they have finished the current segment and are ready to move on.

**Wait for a clear yes.** If they are not ready, tell them that is fine — they can come back and say "what's next" whenever they are. Do not install anything until they confirm.

## Step 3 — Install the next kit

Clone the next phase's repository into the user's home folder.

For **Phase 3**:

```bash
git clone https://github.com/selrai-company/claude-workshop-v3-building.git ~/workshop-v3-building
```

For **Phase 2** (when it is the next phase): repo `claude-workshop-v2-automation`, cloning to `~/workshop-v2-automation/`. On Windows, `~` resolves to the home folder in PowerShell 6+, Git Bash, and zsh/bash.

**If the clone fails** with "repository not found" or an access/permission error: that phase's materials are simply not switched on for this account yet. This is not a bug — do not try to debug it, retry it, or work around it. Tell the attendee plainly:

> "The next part of the workshop isn't open on your account yet. Let your workshop facilitator know and they'll switch it on — then say 'what's next' again and we'll pick straight up."

Then stop.

## Step 4 — Run the next kit's setup

Once the repo is cloned, open its bootstrap file at `<clone-folder>/docs/start/bootstrap.md` (for Phase 3 that is `~/workshop-v3-building/docs/start/bootstrap.md`).

**That bootstrap file is the next kit's own install guide.** It knows how to set itself up — copy its skills and subagent roles into place, record itself in the workspace CLAUDE.md, and point the attendee at their first activity. Follow it step by step, exactly as written, applying the Communication Rules as you go.

Do not improvise the install from memory and do not skip the bootstrap file — each kit owns its own setup, and the bootstrap is the source of truth for it.

## Step 5 — Hand off

The bootstrap file finishes by pointing the attendee at the first activity of the new phase. Let it do that — do not add your own summary on top. The attendee is now in the next phase of the workshop.

## What this skill does NOT do

- It does not gate access or check payment — every workshop attendee gets all three phases. If a clone fails, that is an access-not-switched-on situation for the facilitator, never a "you didn't pay" situation.
- It does not re-implement each kit's install. Step 4 always defers to the target kit's own `docs/start/bootstrap.md`.
- It does not move the attendee backwards. There is no "undo a phase" — the phases only go forward.
