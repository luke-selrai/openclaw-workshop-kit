# PROTOTYPE — New GitHub bootstrap prompt (one-paste install / update / migrate)

> **Status: prototype for CORE-106 — not live, not linked from any install surface.**
> This is the concrete draft to react to. It implements the locked model from the
> CORE-100 ledger: pointer-block architecture, manifest statefulness, always
> re-clone, one prompt for fresh install / update / legacy migration. When the
> ADR/spec ticket (CORE-108) lands, this file's content graduates into the real
> install surfaces and this draft is deleted.
>
> Design notes and open questions for the review are at the bottom, after the
> prompt itself.

---

## The Prompt

Copy everything below and paste it into any Claude Code session — it works from
any starting folder.

---

I am setting up (or updating) my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Detect whether I am on Mac or Windows and use the right commands throughout.
This works from any folder — do not ask me to move anywhere or create a
workspace folder.

Talk to me like I am not technical. Plain English, one step at a time.

**Downloads are the slow part.** For EVERY download below (Node, git, the kit,
anything fetched from the internet): tell me first that it can take several
minutes on slow wifi and may look frozen without being frozen (you cannot talk
to me while a command runs, so say it BEFORE you start); prefer command forms
that print progress; give every slow command a generous timeout so a dead
download fails loudly instead of hanging; confirm afterwards that it worked or
tell me plainly what failed.

### Step 0 — Preflight

Run these checks up front so the common problems surface in the first minute:

1. **Internet sanity** — a check that cannot hang:
   - Mac/Linux: `curl -m 10 -sI https://github.com/`
   - Windows PowerShell: `Invoke-WebRequest -Uri "https://github.com" -Method Head -TimeoutSec 10`
   If it errors or crawls, tell me plainly: the wifi is struggling, downloads
   will be slow, and a phone hotspot is my backup. Then carry on.

2. **Node** — run `node --version`. If it prints a version, skip ahead. If not,
   install it now (this is part of setup, not homework I missed):
   - **Mac/Linux** — via nvm (home-folder install, never needs admin):
     ```
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
     export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
     nvm install --lts && nvm use --lts
     ```
   - **Windows** — via winget, then refresh PATH in THIS session (both halves in
     ONE PowerShell invocation — a fresh shell loses the refreshed PATH):
     ```
     winget install --id OpenJS.NodeJS.LTS -e --source winget
     ```
     ```
     $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); node --version
     ```
     That PATH refresh changes this process only — nothing permanent. Prepend the
     same `$env:Path = ...;` refresh to every later PowerShell command in this
     setup. Only if `node --version` still fails after the refresh: have me fully
     quit and reopen Claude Desktop, then confirm when I am back.
   - If neither package manager works, open https://nodejs.org in the browser
     and download the LTS installer for me. Never make me click through a
     download myself.

3. **Git** — run `git --version`. If it prints a version, skip ahead. If not:
   - **Mac** — run `xcode-select --install` (an Apple dialog appears; I click
     Install) or, if that is unavailable, `brew install git` when Homebrew
     exists. Wait for the install to finish before continuing.
   - **Windows** — `winget install --id Git.Git -e --source winget`, then the
     same one-invocation PATH refresh as the Node step, ending in `git --version`.

### Step 1 — Get the kit (always a fresh copy)

The kit lives at `https://github.com/selrai-company/claude-workshop-kit` and
installs to `~/claude-workshop-kit`. We ALWAYS take a fresh copy — never
update-in-place — so what is on disk exactly matches the kit as published:

1. If `~/claude-workshop-kit` already exists, delete it first (it is a pure
   download area — nothing of mine lives in it; my customisations live in
   `~/.claude/`, which this never touches).
2. Clone with prompting disabled so a closed door fails fast instead of
   hanging on a password prompt:
   - Mac/Linux:
     ```
     GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/selrai-company/claude-workshop-kit.git ~/claude-workshop-kit
     ```
   - Windows PowerShell:
     ```
     $env:GIT_TERMINAL_PROMPT = "0"; git clone --depth 1 https://github.com/selrai-company/claude-workshop-kit.git "$HOME\claude-workshop-kit"
     ```
3. **If the clone is refused** (authentication error, repository not found):
   do NOT retry, do NOT ask me for a password, do NOT try any other way in.
   Tell me exactly this and stop the whole setup here:
   > "Kit access is currently closed. The Selr AI kit opens for download during
   > announced windows — when the next one is announced, paste this same prompt
   > again and it will work. Nothing on your machine has been changed."
4. **If it looks like a network failure** (timeout, dropped connection), have
   me check I am online and run the same clone again — no cap on retries.
5. Verify the download before anything else: `~/claude-workshop-kit/my-assistant/CLAUDE.md`
   and `~/claude-workshop-kit/skills/` must both exist. If not, show me the
   real, unedited clone output and loop on the fix with me until they do.

### Step 2 — Work out which situation this is

Read the state files and pick exactly one mode. Tell me which one in one line.

- `~/.claude/selr-kit-manifest.json` exists → **UPDATE** (I already run the new
  install model; refresh it).
- No manifest, but a legacy install exists (`~/Desktop/my-assistant/CLAUDE.md`
  is present, or Selr kit skills sit in `~/.claude/skills/`) → **MIGRATE**
  (move me onto the new model, keep everything I have learned and customised,
  no re-onboarding).
- Neither → **FRESH** (first-ever install).

### Step 3 — Point Claude at the kit (the pointer block)

The assistant lives in my global Claude config, so it works from ANY folder —
there is no workspace folder anymore.

1. **Copy the persona out of the clone** so deleting the clone never breaks the
   assistant: copy `~/claude-workshop-kit/my-assistant/CLAUDE.md` to
   `~/.claude/selr-assistant.md`, overwriting any previous copy.
2. **Write the managed block** into `~/.claude/CLAUDE.md` (create the file if it
   does not exist; if a previous Selr block is already there between the same
   markers, replace the block in place; never touch anything outside the
   markers):
   ```
   <!-- selr-kit:begin -->
   ## Selr AI Business Assistant

   Kit home: <ABSOLUTE PATH TO THE KIT, e.g. /Users/jane/claude-workshop-kit>
   Manifest: <ABSOLUTE PATH>/.claude/selr-kit-manifest.json equivalent — see ~/.claude/selr-kit-manifest.json

   @<ABSOLUTE PATH TO ~/.claude/selr-assistant.md>
   <!-- selr-kit:end -->
   ```
   Write REAL absolute paths, not `~` — resolve my home folder and substitute it
   (the `@` import line especially must be an absolute path so it loads on
   Windows too). Nothing model-facing goes inside the HTML-comment markers —
   Claude strips comments; the markers only fence the block for updates and
   uninstall.
3. In MIGRATE mode, also retire the old workspace wiring:
   - Rename `~/Desktop/my-assistant/CLAUDE.md` to `CLAUDE.md.pre-migration` (kept
     as a backup, no longer read). Everything else in that folder is mine and
     stays untouched.
   - Delete `~/Desktop/my-assistant/.first-run-pending` if it exists.

### Step 4 — Sync the skills (respecting my customisations)

Skills install to `~/.claude/skills/` (create it if missing), one folder per
skill, copied from `~/claude-workshop-kit/skills/` (folders only — skip
`SKILLS-LIST.md` and any loose files).

The manifest keeps a fingerprint (content hash) of every skill exactly as the
kit installed it. Use it to update without trampling my edits:

- **FRESH:** copy every skill folder in. No questions.
- **UPDATE:** for each kit skill: if my installed copy still matches its
  manifest fingerprint (I never touched it), overwrite silently with the new
  version. If it does NOT match, I have customised it — KEEP my version, skip
  the overwrite, and add it to a report list. Skills that are new in the kit
  are simply copied in. Anything in `~/.claude/skills/` that is not a kit skill
  is mine — never touch it.
- **MIGRATE (no manifest yet):** compare nothing skill-by-skill; instead ask me
  ONE bulk question up front: "I can't tell which skills you may have
  customised. Refresh all Selr kit skills to the newest versions (recommended),
  or keep everything as-is and only add new ones?" — then do what I choose.

At the end of this step, if any customised skills were kept, show the report:
> "Kept your customised versions of: X, Y. Say 'update X anyway' any time to
> take the kit's version."

### Step 5 — Plugins and tools (safe to re-run)

1. **Claude CLI** — `claude --version`; if missing, `npm install -g @anthropic-ai/claude-code`
   and re-verify (Mac fallback: `export PATH="$(npm prefix -g)/bin:$PATH"`).
2. **Routine packager plugin** — register the marketplace and install:
   ```
   claude plugin marketplace add ~/claude-workshop-kit
   claude plugin install routine-installer-plugin@selrai-workshop-kit
   ```
   "Already added / already installed" is success, but an already-installed
   plugin does NOT pick up new content by itself — in UPDATE and MIGRATE mode
   follow with:
   ```
   claude plugin marketplace update selrai-workshop-kit
   claude plugin update routine-installer-plugin
   ```
   (The plugin activates after the next full Claude Desktop restart; do not try
   to use it now.)
3. **Browser automation (Playwright — the assistant's primary browser tool,
   non-negotiable).** Re-adding an existing entry errors, so remove first —
   ignore the error if there is nothing to remove — then add with the
   persistent login profile:
   - Mac/Linux:
     ```
     claude mcp remove --scope user playwright || true
     claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
     ```
   - Windows PowerShell: same two commands with `"$HOME\.cache\playwright-mcp-profile"`.
   Verify `playwright` appears in `claude mcp list`. If not, fallback:
   `npm install -g @playwright/mcp` then re-run the add. If it still will not
   register, stop and tell me honestly — every connector in this kit needs it.
4. **Power-user skills** — same command on Mac and Windows, safe to re-run
   (it overwrites cleanly):
   ```
   npx -y skills@latest add mattpocock/skills -g -a claude-code -s grill-me -s handoff -s diagnosing-bugs -s teach -y --copy
   ```
   Then check the disk: `~/.claude/skills/{grill-me,handoff,diagnosing-bugs,teach}/SKILL.md`
   must all exist. If any are missing, list what the repo offers now
   (`npx -y skills@latest add mattpocock/skills -l`), match the missing skill by
   name/description (repos rename things), re-run with the resolved names, and
   re-check. One healing pass, then report per-skill status.

### Step 6 — Write the manifest (the install's receipt)

Write `~/.claude/selr-kit-manifest.json` fresh on every run:

```json
{
  "kitHome": "<absolute path to ~/claude-workshop-kit>",
  "kitVersion": "<the clone's HEAD commit hash, from git -C ~/claude-workshop-kit rev-parse HEAD>",
  "installedAt": "<ISO timestamp>",
  "installMode": "fresh | update | migrate",
  "installPath": "github",
  "onboarded": <false on FRESH; true on MIGRATE; keep the existing value on UPDATE>,
  "skills": { "<skill-name>": "<sha256 of the skill folder's SKILL.md as installed>", ... }
}
```

The `skills` map lists every kit skill actually installed or kept this run —
for kept-customised skills record the KIT version's hash (so a later "update X
anyway" knows what the kit shipped), and mark them:
`"<skill-name>": { "hash": "...", "customised": true }`.

`onboarded` is the assistant's only first-run signal: `false` makes the next
session run onboarding; the onboarding flow flips it to `true` when done. The
`.first-run-pending` marker file is dead — never create it.

### Step 7 — Verify gate

Do not declare success until every line passes. Check and show me a tick list:

- `~/.claude/CLAUDE.md` contains exactly one `<!-- selr-kit:begin -->` block
- `~/.claude/selr-assistant.md` exists and is non-empty
- `~/.claude/selr-kit-manifest.json` exists and parses
- `~/.claude/skills/` contains the kit skills (spot-check 3 named folders) and
  the 4 power-user skills
- `claude mcp list` shows `playwright`
- `claude plugin list` shows `routine-installer-plugin`

Anything failing: fix it with me now, re-check, and only then continue. No cap
on attempts; never paper over a failed line.

### Step 8 — Done

In MIGRATE mode, first tell me this (two lines, once, never again):
> "Your assistant has moved: it now works in EVERY Claude Code session, from any
> folder — you no longer need the my-assistant folder to talk to it."

Then print exactly this block (diagram in a fenced code block, banner below,
nothing after it):

Here's what your assistant can now do for you:

```
                              ┌───────────────────────┐
                              │      CLAUDE CODE      │
                              │   your AI assistant   │
                              └───────────┬───────────┘
                                          │
         ┌────────────────────┬───────────┴───────────┬────────────────────┐
         ▼                    ▼                       ▼                    ▼
┌─────────────────┐  ┌─────────────────┐     ┌─────────────────┐  ┌─────────────────┐
│     SKILLS      │  │   CONNECTORS    │     │     BROWSER     │  │     MEMORY      │
│                 │  │                 │     │                 │  │                 │
│ Saves hours on: │  │ Plugs into:     │     │ On the web:     │  │ Learns you:     │
│                 │  │                 │     │                 │  │                 │
│ • Writes quotes │  │ • Your email    │     │ • Connects apps │  │ • Your style    │
│ • Chases leads  │  │ • Your calendar │     │ • Creates ads   │  │ • Your clients  │
│ • Drafts emails │  │ • Slack/Teams   │     │ • Pulls quotes  │  │ • Your projects │
│ • Files reports │  │ • Your CRM      │     │ • Fills forms   │  │ • Your team     │
│ • Cleans data   │  │ • Cloud files   │     │ • Tests apps    │  │ • No repeating  │
└─────────────────┘  └─────────────────┘     └─────────────────┘  └─────────────────┘
```

## ✅ Install complete

### Do this next

1. **Fully quit Claude Desktop and reopen it** (right-click the dock/tray icon
   → Quit — closing the window is not enough)
2. **Start a new Code session** — any folder is fine now
3. **Type "hi"** and press Enter

Your assistant will introduce itself and take it from there.

---

*Why restart? Your assistant's instructions and browser tool were installed
during this session — a fresh start is what loads them.*

---

## Design notes for the review (not part of the prompt)

1. **Absolute paths in the pointer block.** CORE-102 found `@~/...` resolution
   on Windows is unverified upstream, so the prompt has the installer resolve
   and write absolute paths. Costs per-user variance in the block; buys
   certainty. Alternative: `@~/...` plus a Windows verify step.
2. **Restart folded to the end.** The old flow restarted mid-setup to smoke-test
   Playwright (first-run-setup Phase 2.5 Step 2a/2b). One-paste can't survive a
   restart mid-prompt, so this draft defers the smoke test to the next session
   (orientation). If a live smoke test must stay in the install, the prompt
   needs a "come back and type ready" hinge — decide which.
3. **Skill fingerprints = SKILL.md hash only,** not the whole folder — cheap and
   catches the file people actually edit. Whole-folder hashing is the stricter
   alternative.
4. **Legacy-skill detection for MIGRATE** keys on `~/Desktop/my-assistant/CLAUDE.md`
   OR kit skills present in `~/.claude/skills/`. The second clause catches
   half-broken legacy installs but could false-positive on someone who only
   installed skills manually — acceptable? (Migration is gentle either way.)
5. **Kept-customised manifest entries** store the kit hash + `customised: true`
   so "update X anyway" has the kit's reference. Slightly heavier schema;
   drop if too clever.
6. **`--depth 1` clone** — smallest possible download; history is never needed
   in the install area.
7. **The banner drops hard counts** (was "204 SKILLS") so the prompt never
   drifts from the audit markers; orientation can quote live numbers.
