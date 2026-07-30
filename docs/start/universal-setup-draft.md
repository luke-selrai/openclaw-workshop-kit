# PROTOTYPE — Universal one-paste setup prompt (install / update / migrate)

> **Status: prototype for CORE-106 — not live, not linked from any install surface.**
> This is the concrete draft to react to. It implements the locked model from the
> CORE-100 ledger **plus the CORE-104 Loup-path conformance decision**: one
> universal prompt in one setup document (this draft replaces BOTH
> `docs/start/bootstrap.md` and `docs/start/full-setup.md` when it graduates),
> silent three-way acquisition probe, pointer-block architecture, manifest
> statefulness, one-session setup with a single mid-session restart and an
> in-session Playwright smoke test. When the ADR/spec ticket (CORE-108) lands,
> this content graduates into the real setup document and this draft is deleted.
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

### Step 1 — Read my current state (before anything changes)

Look for `~/.claude/selr-kit-manifest.json` and pick exactly one mode. Tell me
which in one line, in plain words ("this is a fresh setup" / "I'm updating your
existing assistant" / "I'm moving your assistant to the new setup"):

- Manifest exists → **UPDATE**. Keep its full contents in hand — the skill sync
  in Step 5 needs its skill fingerprints, and `onboarded` carries over.
- No manifest, but a legacy install exists (`~/Desktop/my-assistant/CLAUDE.md`
  is present, or Selr kit skills sit in `~/.claude/skills/`) → **MIGRATE**
  (move me onto the new model, keep everything I have learned and customised,
  no re-onboarding).
- Neither → **FRESH** (first-ever install).

### Step 2 — Get the kit

Tell me only "Downloading your kit now — this can take a few minutes and may
look frozen without being frozen." Which door the download comes through is
plumbing I never need to know about.

First, silently probe the kit repository — a cheap check that fails fast
instead of hanging on a password prompt:

- Mac/Linux: `GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/selrai-company/claude-workshop-kit.git HEAD`
- Windows PowerShell: `$env:GIT_TERMINAL_PROMPT = "0"; git ls-remote https://github.com/selrai-company/claude-workshop-kit.git HEAD`

Give it a generous timeout. Three outcomes, three doors:

**A. The probe succeeds → clone from GitHub. Kit home: `~/claude-workshop-kit`.**
We ALWAYS take a fresh copy — never update-in-place — so what is on disk
exactly matches the kit as published:

1. If `~/claude-workshop-kit` already exists, delete it (it is a pure download
   area — nothing of mine lives in it; my customisations live in `~/.claude/`,
   which this never touches).
2. Clone, still with prompting disabled:
   - Mac/Linux:
     ```
     GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/selrai-company/claude-workshop-kit.git ~/claude-workshop-kit
     ```
   - Windows PowerShell:
     ```
     $env:GIT_TERMINAL_PROMPT = "0"; git clone --depth 1 https://github.com/selrai-company/claude-workshop-kit.git "$HOME\claude-workshop-kit"
     ```

**B. The probe is refused (authentication error / repository not found) → the
kit comes through Loup. Kit home: `~/.loup/selr-ai/workshop-kit`.** Do NOT
retry the clone, do NOT ask me for a GitHub password. Instead:

1. Ask me to open my Loup dashboard at https://louphq.com/dashboard/buyer. If I
   am already signed in it just opens. If it asks me to sign in, the way in is
   the email Loup sent me (subject like "You've been given access to ... on
   Loup"): the sign-in link in any ONE of those emails signs my whole account
   in — I do not need every email. If no Loup email arrived, or my link says it
   was already used, the fix is a fresh sign-in link from whoever gave me the
   kit — that is not something you and I can fix from here.
2. On the dashboard, have me click "Get install command" on the workshop kit,
   copy the whole line — it looks like
   `npx @louphq/install selr-ai/workshop-kit --token loupit_...` — and paste it
   to you. Run exactly what I paste (same command on Mac and Windows). Even in
   UPDATE mode, always re-run my install command like this — it overwrites the
   kit folder with a fresh copy, same as the clone door.
3. If the install is refused (by far the most common cause: my command has gone
   stale), have me mint a fresh command from the dashboard and paste the new
   line. Loop with no cap on attempts: show me the real, unedited output every
   time, tell me plainly which part failed, one targeted fix per round.

**C. The probe times out or fails like a network problem → it is the wifi, not
access.** Never send me to Loup or ask for any token from this branch. Have me
check I am online (hotspot as backup), then probe again — no cap on retries.

Whichever door it came through, verify before anything else:
`<kit home>/my-assistant/CLAUDE.md` and `<kit home>/skills/` must both exist.
If not, show me the real, unedited output and loop on the fix with me until
they do. **From here on, "the kit home" means the absolute path this step
decided — every later step uses it.**

### Step 3 — Point Claude at the kit (the pointer block)

The assistant lives in my global Claude config, so it works from ANY folder —
there is no workspace folder anymore.

1. **Copy the persona out of the kit** so deleting the kit folder never breaks
   the assistant: copy `<kit home>/my-assistant/CLAUDE.md` to
   `~/.claude/selr-assistant.md`, overwriting any previous copy.
2. **Write the managed block** into `~/.claude/CLAUDE.md` (create the file if it
   does not exist; if a previous Selr block is already there between the same
   markers, replace the block in place; never touch anything outside the
   markers):
   ```
   <!-- selr-kit:begin -->
   ## Selr AI Business Assistant

   Kit home: <ABSOLUTE PATH TO THE KIT HOME>
   Install details: ~/.claude/selr-kit-manifest.json

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

### Step 4 — Write the manifest (the install's receipt)

Write `~/.claude/selr-kit-manifest.json` fresh on every run (Step 5 fills in
its `skills` map as it syncs):

```json
{
  "kitHome": "<the absolute kit home from Step 2>",
  "installPath": "<github or loup — whichever door Step 2 took>",
  "kitVersion": "<github door: the clone's HEAD commit from git -C <kit home> rev-parse HEAD; loup door: the kit version the installer reported, else omit>",
  "installedAt": "<ISO timestamp>",
  "installMode": "fresh | update | migrate",
  "onboarded": <false on FRESH; true on MIGRATE; carry the old value on UPDATE>,
  "skills": {}
}
```

`onboarded` is the assistant's only first-run signal: `false` makes the next
session run orientation; orientation flips it to `true` when done. The old
`.first-run-pending` marker file is dead — never create it.

### Step 5 — Sync the skills (respecting my customisations)

Skills install to `~/.claude/skills/` (create it if missing), one folder per
skill, copied from `<kit home>/skills/` (folders only — skip `SKILLS-LIST.md`
and any loose files).

The old manifest (read in Step 1) fingerprints every skill exactly as the kit
last installed it. Use it to update without trampling my edits:

- **FRESH:** copy every skill folder in. No questions.
- **UPDATE:** for each kit skill: if my installed copy still matches its old
  fingerprint (I never touched it), overwrite silently with the new version.
  If it does NOT match, I have customised it — KEEP my version, skip the
  overwrite, and add it to a report list. Skills new in the kit are simply
  copied in. Anything in `~/.claude/skills/` that is not a kit skill is mine —
  never touch it.
- **MIGRATE (no old manifest):** compare nothing skill-by-skill; instead ask me
  ONE bulk question up front: "I can't tell which skills you may have
  customised. Refresh all Selr kit skills to the newest versions (recommended),
  or keep everything as-is and only add new ones?" — then do what I choose.

As you sync, record every kit skill into the new manifest's `skills` map: the
fingerprint (content hash of the skill's `SKILL.md` as installed), and for a
kept-customised skill record the KIT version's hash marked
`"customised": true` (so a later "update X anyway" knows what the kit shipped).

At the end of this step, if any customised skills were kept, show the report:
> "Kept your customised versions of: X, Y. Say 'update X anyway' any time to
> take the kit's version."

### Step 6 — Plugins and tools (safe to re-run; all BEFORE the one restart)

1. **Claude CLI** — `claude --version`; if missing, `npm install -g @anthropic-ai/claude-code`
   and re-verify (Mac fallback: `export PATH="$(npm prefix -g)/bin:$PATH"`).
2. **Routine packager plugin** — register the marketplace and install, using the
   kit home from Step 2:
   ```
   claude plugin marketplace add <kit home>
   claude plugin install routine-installer-plugin@selrai-workshop-kit
   ```
   "Already added / already installed" is success, but an already-installed
   plugin does NOT pick up new content by itself — in UPDATE and MIGRATE mode
   follow with:
   ```
   claude plugin marketplace update selrai-workshop-kit
   claude plugin update routine-installer-plugin
   ```
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

### Step 7 — The one restart

Everything is installed; now Claude Desktop needs one full restart to load the
browser tool. Say to me exactly:

> "Nearly there — one restart and we're done.
>
> 1. Right-click the Claude Desktop icon in your dock (Mac) or system tray
>    (Windows) and choose **Quit** — Cmd+Q on Mac also works. Just closing the
>    window is NOT enough.
> 2. Reopen Claude Desktop.
> 3. Come back to THIS same chat and type **done**.
>
> When you say done, I'll test the browser and finish up."

Then stop and wait. Do not narrate anything else in the meantime.

### Step 8 — Browser smoke test (after I come back)

When I am back: warn me first that the very first page load downloads the
browser itself (a few hundred MB) — it can take a few minutes on slow wifi and
may look frozen without being frozen; after this first time it opens in a
second. Then, in this exact order:

1. `mcp__playwright__browser_navigate` to `https://example.com` — a tiny page.
   A small browser window opens visibly on my screen.
2. `mcp__playwright__browser_snapshot` — it must contain "Example Domain". If
   it does not, Playwright is installed but not loading pages; stop and
   diagnose with me.
3. `mcp__playwright__browser_close` — I see the window close.

If the `mcp__playwright__*` tools are not visible at all, I did not fully quit
— closing the window is not quitting. Repeat the quit instructions from Step 7
and wait again. Do not continue until this smoke test passes.

### Step 9 — Verify gate

Do not declare success until every line passes. Check and show me a tick list:

- `~/.claude/CLAUDE.md` contains exactly one `<!-- selr-kit:begin -->` block
- `~/.claude/selr-assistant.md` exists and is non-empty
- `~/.claude/selr-kit-manifest.json` exists, parses, and its `skills` map is
  populated
- `~/.claude/skills/` contains the kit skills (spot-check 3 named folders) and
  the 4 power-user skills
- `claude mcp list` shows `playwright`, and the smoke test passed
- `claude plugin list` shows `routine-installer-plugin`

Anything failing: fix it with me now, re-check, and only then continue. No cap
on attempts; never paper over a failed line.

### Step 10 — Done

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

## ✅ Setup complete

### Do this next

1. **Start a new Code session** — any folder is fine
2. **Type "hi"** and press Enter

Your assistant will introduce itself and take it from there.

---

*Why a new session? Your assistant's instructions were installed during this
session — a fresh session reads them at startup.*

---

## Design notes for the review (not part of the prompt)

1. **Absolute paths in the pointer block.** CORE-102 found `@~/...` resolution
   on Windows is unverified upstream, so the prompt has the installer resolve
   and write absolute paths. Costs per-user variance in the block; buys
   certainty. Alternative: `@~/...` plus a Windows verify step.
2. **Manifest before skills sync (CORE-104 running order).** The new manifest
   is written in Step 4 with an empty `skills` map that Step 5 fills as it
   syncs; the OLD manifest's fingerprints (read in Step 1, before anything
   changes) drive the keep-and-report decisions. If a run dies between Steps 4
   and 5, the manifest exists with no receipts — the verify gate catches it,
   and a re-paste self-heals. Alternative: write the manifest once, after the
   sync, accepting a divergence from the CORE-104 stated order.
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
8. **`kitVersion` on the Loup door** — the GitHub door records the HEAD commit;
   what the Loup installer exposes as a version needs confirming (the draft
   says "else omit"). If nothing reliable exists, uninstall/update don't
   actually need the field — it could go entirely.
9. **Probe refusal wording.** Branch B assumes any auth/not-found refusal means
   "private window, go via Loup". A genuinely revoked/renamed repo looks
   identical — accepted, since Loup's dashboard walkthrough dead-ends politely
   anyway.
