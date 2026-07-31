# Setup - Bring Your Assistant to Life

One page, one prompt. The same prompt sets the assistant up for the first time, updates it later, and moves an older install onto the current setup. You never have to work out which of those you are doing - the prompt works it out.

**How to use it:** open Claude Code in Claude Desktop, copy everything in the box below, paste it in, and press Enter. It works from any folder, and there is nothing to download or create first. (Claude Desktop is the supported path here - the one restart in the middle is written for it. Running Code in a terminal or the VS Code extension works too, but you will have to translate that one step yourself.)

**Time:** around 20-30 minutes, most of which is downloads. There is one restart in the middle, and the prompt tells you exactly when.

---

## The prompt

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

1. **Internet sanity** — a preflight check that cannot hang. Hit both places
   this setup downloads from, each with a hard timeout:
   - Mac/Linux:
     ```
     curl -m 10 -sI https://github.com/ && curl -m 10 -sI https://registry.npmjs.org/
     ```
   - Windows PowerShell:
     ```
     Invoke-WebRequest -Uri "https://github.com" -Method Head -TimeoutSec 10; Invoke-WebRequest -Uri "https://registry.npmjs.org" -Method Head -TimeoutSec 10
     ```
   If either errors or crawls, tell me plainly: the wifi is struggling, downloads
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

Nothing on my machine changes during this step. Read only.

**1.1 Pick the mode.** Look for `~/.claude/selr-kit-manifest.json`. Tell me which
mode you picked in one line, in plain words ("this is a fresh setup" / "I'm
updating your existing assistant" / "I'm moving your assistant to the new
setup"):

- Manifest exists → **UPDATE**. Keep its full contents in hand — the skill sync
  in Step 5 needs its skill fingerprints, and `onboarded` carries over.
- No manifest, but an older install is detected → **MIGRATE** (move me onto the
  current setup, keep everything I have learned and customised, no
  re-onboarding). Detect this if EITHER is true:
  - a `CLAUDE.md` exists at any of these two paths — the **older-setup folders**
    (the kit's own docs call these the legacy-workspace candidate list):
    `~/Desktop/my-assistant` and `~/my-assistant`; or
  - Selr kit skills are already sitting in `~/.claude/skills/`.

  Do not check the contents of anything here — presence is enough. Do not go
  hunting anywhere else for a folder I may have renamed or moved.
- Neither → **FRESH** (first-ever install).

**1.2 MIGRATE only — snapshot the old kit before it is overwritten.** An older
install has no manifest, so there is no record of which skills I edited myself.
Rebuild that record now, from the old kit still on my disk. Do it in THIS step:
Step 2 overwrites the old kit folder, so after Step 2 the evidence is gone.

Look for the old kit in all three places it may have been installed
(check every one — any of them may be the real one):

- `~/.loup/selr-ai/workshop-kit/skills/`
- `~/workshop-kit/skills/`
- `~/claude-workshop-kit/skills/`

Then, for every skill folder already in `~/.claude/skills/`:

- If its `SKILL.md` is byte-identical to the same-named skill's `SKILL.md` in
  ANY of the old kit folders you found, I never touched it → record its content
  hash in an in-memory list. Call this list the **rebuilt fingerprints**; Step 5
  uses it exactly as UPDATE uses a real manifest.
- Otherwise — different content, or the skill is in no old kit folder at all —
  record NO fingerprint for it. Step 5 then treats it as customised and keeps my
  version.

If none of the three old kit folders survived, nothing can match, so every kit
skill counts as customised and every one is kept. That is deliberate: keeping a
file I might have edited is safe, and Step 5's report tells me how to take the
kit's version of any of them whenever I want.

Never ask me which skills I customised. I cannot know, and this step works it
out.

Keep the rebuilt fingerprints in this session only — do not write them to disk.
If this session dies before Step 5, the next run finds the old kit already
replaced, matches nothing, and keeps every skill. That is the safe outcome, and
the report tells me how to take the kit's version of anything I want refreshed.

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

1. If `~/claude-workshop-kit` already exists, check it really is a kit download
   before removing it: it must contain BOTH `skills/` and
   `my-assistant/CLAUDE.md`. If it does, delete it — a kit download folder is a
   pure download area, nothing of mine lives in it, and my customisations live
   in `~/.claude/`, which this never touches. If it does NOT look like a kit,
   stop and tell me: "There's already a folder at `~/claude-workshop-kit` that
   doesn't look like the kit, so I haven't touched it." Never delete a folder
   on its name alone.
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
   stale; the other: the access I was granted is not switched on yet), have me
   mint a fresh command from the dashboard and paste the new line. Loop with no
   limit on attempts: show me the real, unedited output every time — never hide
   it — tell me plainly which part failed, one targeted fix per round.

**C. The probe times out or fails like a network problem → it is the wifi, not
access.** Never send me to Loup or ask for any token from this branch. Have me
check I am online (hotspot as backup), then probe again — no limit on retries.

Whichever door it came through, verify before anything else:
`<kit home>/my-assistant/CLAUDE.md` and `<kit home>/skills/` must both exist.
If only some of them arrived, that is a partial download — say so plainly rather
than treating a missing path as success. Show me the real, unedited output and
loop on the fix with me until both exist. STOP here if they never do:
Do not run any of steps 3 onwards against a kit that is not on disk — a failed
download must stop the setup, not cascade through it. **From here on, "the kit
home" means the absolute path this step decided — every later step uses it.**

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
3. **In MIGRATE mode, also retire the old wiring.** Check BOTH older-setup
   folders from Step 1.1 — `~/Desktop/my-assistant` and `~/my-assistant`. Both
   can be retired in the same run.

   For each one that exists, first check it really is the kit's: open its
   `CLAUDE.md` and confirm the **first line is exactly**
   `# Your AI Business Assistant`.
   - It matches → rename that `CLAUDE.md` to `CLAUDE.md.pre-migration` (kept as
     a backup, no longer read), and delete that same folder's
     `.first-run-pending` if it has one. Everything else in the folder is mine
     and stays untouched.
   - It does NOT match → leave the whole folder completely alone and TELL me:
     "There's a folder at `<path>` that isn't the assistant's, so I've left it
     exactly as it is." Never rename or delete anything on a folder that fails
     this check, and never skip it silently.

4. **In MIGRATE mode, clear out the old kit download folder.** Only
   `~/workshop-kit`, and only when it is definitely the old kit and not a folder
   of mine that happens to share the name: it must contain a `skills/` folder AND at least one
   of the old kit's own files (`my-assistant/CLAUDE.md` or
   `skills/SKILLS-LIST.md`). If it qualifies, delete it and tell me in one line.
   If it does not, leave it alone and say so.

   Leave the other two old locations exactly where they are, whether or not this
   run happened to touch them. `~/workshop-kit` is the only one to remove: it
   belongs to a distribution that no longer exists, while the other two are the
   current kit homes for the two live doors, so deleting either could delete the
   kit this run just installed.

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

Step 5 fills `skills` with one entry per kit skill, in exactly this shape — other
parts of the kit (orientation, uninstall) read these keys by name, so do not
rename them:

```json
"skills": {
  "<skill-name>": { "hash": "<SKILL.md content hash>", "customised": true }
}
```

`customised` is present only on a skill whose version I edited and you kept.

`onboarded` is the assistant's only first-run signal: `false` makes the next
session run orientation; orientation flips it to `true` when done. The old
`.first-run-pending` marker file is dead — never create it.

### Step 5 — Sync the skills (respecting my customisations)

Skills install to `~/.claude/skills/` (create it if missing), one folder per
skill, copied from `<kit home>/skills/` (folders only — skip `SKILLS-LIST.md`
and any loose files).

- **FRESH:** copy every skill folder in. No questions.
- **UPDATE and MIGRATE:** identical from here on. UPDATE uses the old manifest's
  fingerprints (read in Step 1.1); MIGRATE uses the rebuilt fingerprints from
  Step 1.2. Either way, for each kit skill:
  - my installed copy matches its fingerprint (I never touched it) → overwrite
    silently with the new version. "Overwrite" means replace the kit's own files
    in place — never empty the folder first, because anything in there the kit
    did not ship is mine (notes, a script) and the fingerprint only covers
    `SKILL.md`;
  - it does not match, or it has no fingerprint at all → I have customised it →
    KEEP my version, skip the overwrite, and add it to a report list;
  - the skill is new in the kit and not on my disk → simply copy it in.

  Anything in `~/.claude/skills/` that is not a kit skill is mine — never touch
  it, and never list it in the manifest.

Never ask me a blanket "refresh everything or keep everything?" question in any
mode. The fingerprints answer it skill by skill.

A skill you decided to keep stays kept for the rest of the run. If a copy is
slow, hangs, or has to be retried, never widen the retry to cover it and never
copy over it "just to be sure" — that is my work, and re-running the sync must
leave it exactly where it is.

As you sync, record every kit skill into the new manifest's `skills` map: the
fingerprint (content hash of the skill's `SKILL.md` as installed), and for a
kept-customised skill record the KIT version's hash marked
`"customised": true` (so a later "update X anyway" knows what the kit shipped,
and the next update can heal anything I later let go).

At the end of this step, if any customised skills were kept, show the report:
> "Kept your customised versions of: X, Y. Say 'update X anyway' any time to
> take the kit's version."

### Step 6 — Plugins and tools (safe to re-run; all BEFORE the one restart)

1. **Claude CLI** — `claude --version`; if missing, `npm install -g @anthropic-ai/claude-code`
   and re-verify (Mac fallback: `export PATH="$(npm prefix -g)/bin:$PATH"`).
2. **Routine packager plugin** — register the marketplace and install, using the
   kit home from Step 2:
   ```
   claude plugin marketplace remove selrai-workshop-kit
   claude plugin marketplace add <kit home>
   claude plugin install routine-installer-plugin@selrai-workshop-kit
   ```
   Remove first (ignore the error if there was nothing registered): a machine
   that installed through one door and updated through the other would otherwise
   keep pointing at the old kit folder and quietly serve stale content.
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
   - Windows PowerShell — same two commands, but PowerShell has no `|| true`, so
     let the remove fail quietly on its own:
     ```
     claude mcp remove --scope user playwright 2>$null
     claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME\.cache\playwright-mcp-profile"
     ```
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

Anything failing: fix it with me now, re-check, and only then continue. No limit
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

## Before workshop day

If you are coming to a workshop, having **Node.js** installed before you arrive saves everyone ten minutes of venue wifi. Grab the LTS installer from [nodejs.org](https://nodejs.org) and run it. If you do not get to it, the prompt installs Node for you - it is just slower on the day.

## If something goes wrong

Ask your assistant directly, in the same session: *"Something broke. Here's the error: [paste the error]. Help me fix it."* The prompt is written to diagnose and retry with you rather than give up. If that does not sort it, see [troubleshoot.md](../troubleshoot.md).

## What comes after

Start a new session and say hi - your assistant runs a short orientation the first time, then you are into [use/](../use/README.md).

---

*Built by Selr AI - selrai.com.au*
