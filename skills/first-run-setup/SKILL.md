---
name: first-run-setup
description: First-run setup and onboarding for the AI Business Assistant. MUST be invoked on the user's first message of any new session whenever the file `~/Desktop/my-assistant/.first-run-pending` exists in the workspace — even if the user only said "hi" or "hello". Also invoke when the user explicitly says "my setup is broken", "fix my install", or "re-run setup". Deletes the `.first-run-pending` marker as its final action.
---

# First Run Setup

<!-- Path conventions: most file paths in this skill resolve relative to the user's home folder. .claude/skills/ means $HOME/.claude/skills/ on Mac and Linux, and %USERPROFILE%\.claude\skills\ on Windows. workshop-kit/ lives at $HOME/workshop-kit/. The user's WORKSPACE — where the .first-run-pending state file and the per-workspace CLAUDE.md sit — is at $HOME/Desktop/my-assistant/ on all platforms. When reading or copying files, always resolve paths relative to the user's home folder — never hardcode an absolute path or a username. Shell commands inside fenced bash blocks may use ~/ and $HOME natively (the shell expands them); shell commands inside fenced PowerShell blocks must use $HOME or $env:USERPROFILE. -->

You are setting up a non-technical business owner's AI Business Assistant for the first time. Follow these phases in order. Do not skip steps. Do not add extra checks beyond what is listed here.

**IMPORTANT:** Only perform the steps listed below. Do NOT check for Git, Claude Code, Playwright, or any other software not listed here. The bootstrap process already handled those. Your job is to verify skills, install Node.js, onboard the user, and show them a demo.

---

## PHASE 1 — SETUP VERIFICATION

Say:
> "Hi! I am your AI Business Assistant, built by Selr AI. Let me quickly check that everything is set up correctly, then I will get to know you and your business."

### Step 1 — Verify Skills Installed

Check the user-level Claude skills folder — `.claude/skills/` inside the user's home folder. On Mac and Linux that resolves to `$HOME/.claude/skills/`; on Windows it resolves to `%USERPROFILE%\.claude\skills\`. Use the correct path for the user's operating system — never hardcode a username.

- If it has skill directories inside it → "Your skills are ready." Move to Step 2.
- If empty or missing → "It looks like your skills did not copy correctly. Let me fix that."
  1. Check if the workshop kit's skills folder exists at `workshop-kit/skills/` inside the user's home folder.
  2. If yes → copy all skill folders (but not `SKILLS-LIST.md`) from the workshop kit's `skills/` folder into the user-level Claude skills folder. Use the correct copy command for the user's operating system — `cp -R` on Mac/Linux, `Copy-Item -Recurse` (or `xcopy /E /I`) on Windows.
  3. If no → the workshop kit folder is missing and must be re-cloned from GitHub. The repo is public:
     - Run `git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit` (or the PowerShell equivalent on Windows — `~` resolves to home in PowerShell 6+, Git Bash, and zsh/bash).
     - Sanity-check that both `workshop-kit/my-assistant/CLAUDE.md` and `workshop-kit/skills/` exist inside the user's home folder. If either is missing, the clone failed — stop, tell the user what happened, and ask them to retry.
     - Once the workshop kit is in place, copy the skill folders into `.claude/skills/` as in step 2 above.
     - If `git clone` fails (e.g. `git: command not found` on Windows), the user needs Git for Windows installed first. Tell them: "I need Git installed before I can fetch the kit. On Windows, install it from https://git-scm.com/download/win, click through with the default settings, then fully quit and reopen Claude Desktop and tell me you're ready." On Mac, the first `git` invocation will trigger a popup to install the Xcode Command Line Tools — tell the user to click Install and wait 3–5 minutes, then retry.

### Step 2 — Detect Operating System

Detect whether the user is on Mac, Windows, or Linux. Claude's memory will retain this automatically once you've noted it — no explicit save step needed.

### Step 3 — Install Node.js

Node.js is needed for browser automation, email, and calendar connections. Check if it is already installed:

Run: `node --version`

- If it shows a version number → "Node.js is ready." Move to Step 4.
- If not found → install it:

Install Node.js directly from the terminal — do NOT send the user to a website to download an installer. Tell the user what is happening in plain English ("I am going to install Node.js for you now — it will take about a minute"), then run the commands yourself.

**Mac and Linux — install via nvm (Node Version Manager):**

nvm installs Node.js into the user's home folder, so it never needs sudo and never hits the permission errors that break a manual install.

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
```

Then verify: `node --version`

If `node --version` still says "command not found":
1. Source the user's shell profile: `source ~/.zshrc` (or `source ~/.bash_profile` if they are on bash) and try again.
2. If it still fails with a permission error like EACCES, run `sudo chown -R $(whoami) ~/.nvm` and retry. Tell the user "I need to fix a permission on a folder in your home directory — this is safe."
3. Only if every terminal path has failed, use Playwright to drive https://nodejs.org and download the LTS installer automatically. Never tell the user to click through it themselves.

**Windows — install via winget (built into Windows 10 1709+ and Windows 11):**

```powershell
winget install --id OpenJS.NodeJS.LTS -e --source winget
```

Then tell the user: "I need you to close this terminal window and open a new one so the new tools can be picked up." After they reopen, verify: `node --version`.

If winget says "access denied", tell the user: "I need to run this with administrator access. Please right-click Claude Desktop, choose Run as Administrator, then come back to me." After they restart Claude Desktop as admin, retry the winget command.

If winget is not available at all (very old Windows), use Playwright to drive https://nodejs.org and download the LTS installer automatically — do not ask the user to do it manually.

**General rule — never send the user to a website to manually click through an installer.** Always try in this order: (1) terminal install via the platform-native package manager, (2) Playwright-driven automated download, (3) manual click-through only as an absolute last resort with no other option available.

### Step 4 — Setup Complete

Say:
> "Everything looks good! Now let me learn a bit about you and your business. I am going to ask 7 quick questions — after this I will remember everything about you across every conversation."

→ Move to Phase 2.

Note to the assistant: Claude's native `/memory` captures everything the user tells you automatically across sessions. Do NOT write to any `my-assistant/memory/` file — there is no such folder and no workshop-managed memory files. Setup-state like "this user has been onboarded" is implicit: if you know their name and business from memory, setup is done.

---

## PHASE 2 — ONBOARDING

If you already know the user's name and business from memory, skip this phase entirely and greet them by name. Otherwise, ask these 7 questions one at a time:

1. "What is your first name?"
2. "What is your business called, and what do you do in one sentence?"
3. "Who are your customers — who do you help?"
4. "What is the biggest frustration or problem in your business right now?"
5. "What apps or tools do you use? For example: Gmail, Facebook, Xero, Instagram."
6. "How do you prefer I communicate — casual and friendly, or professional and direct?"
7. "What would feel like a win for you from today?"

Ask them conversationally, one at a time, per the Communication Rules in CLAUDE.md. Claude's memory retains everything they tell you automatically — you do NOT need to write anything to disk or "save a profile note". Just acknowledge each answer naturally and move to the next question.

After the last question, say:
> "Done! I'll remember all of this from now on. Now let me connect the tools that will make me really useful for you."

→ Move to Phase 2.5.

---

## PHASE 2.5 — CONNECT TOOLS

Say:
> "I need to connect a few things so I can help you properly. I will do all the technical work — you just watch and approve things when I ask."

### Step 1 — Install Claude Command Line Helper

Say:
> "First I am going to install my command-line helper. This is what lets me connect to your browser and other tools. It will take about a minute."

Run: `claude --version`

- Shows a version number → "Already installed." → skip to Step 2
- Command not found → install it:

```bash
npm install -g @anthropic-ai/claude-code
```

After install, verify: `claude --version`

If it shows a version number:
> "That worked! My command-line helper is ready."

**Mac note:** If `claude --version` still says "command not found" after install, run:
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```
Then try `claude --version` again.

**Windows note:** If it still says "command not found", tell the user: "Close Claude Desktop completely and reopen it, then say 'continue' to me."

### Step 2 — Connect Browser Automation (Playwright MCP — non-negotiable, primary browser tool)

Playwright MCP is the assistant's primary browser tool. Every connector SKILL in this kit is written against it. This step is non-negotiable — do not skip it, do not substitute Chrome MCP, computer-use, or any other browser surface. If Playwright MCP fails to install in any branch below, treat it as a setup blocker and tell the user honestly; do not silently continue without it.

Say:
> "Now I am going to connect to your browser. Once this is done, I can open websites and fill in forms for you. The browser also remembers your logins — once you sign in to a site through me, you stay signed in next time."

Install with a persistent profile directory so logins survive across sessions (this is critical — workshop attendees should never have to re-login to the same site twice):

Mac/Linux (bash/zsh):
```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Windows (PowerShell):
```powershell
claude mcp add playwright --scope user -- npx -y "@playwright/mcp@latest" --user-data-dir "$HOME\.cache\playwright-mcp-profile"
```

Verify the entry is registered:
```bash
claude mcp list
```

If `playwright` is NOT listed, try the fallback (still with the persistent profile):
```bash
npm install -g @playwright/mcp
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

If BOTH attempts fail to register, stop and tell the user: "I could not install the browser tool — every other tool in this kit needs it. Let me show you the error and we will fix it before continuing." Do not move on without Playwright MCP working.

#### Step 2a — Mandatory Claude Desktop restart

**Playwright MCP is registered, but its tools (`mcp__playwright__*`) are NOT visible to the current session.** New MCP servers only become callable after Claude Desktop fully restarts and reloads them. Do not attempt to call any `mcp__playwright__*` tool in this session — it will fail.

Say to the user, exactly:

> "Your browser tool is installed, but I need you to **fully quit Claude Desktop and reopen it** before I can use it.
>
> 1. Right-click the Claude Desktop icon in your dock (Mac) or system tray (Windows) and choose **Quit** — pressing Cmd+Q on Mac also works. Just closing the chat window is NOT enough.
> 2. Reopen Claude Desktop.
> 3. Come back to this same chat and type **ready**.
>
> When you say ready, I will run a quick test to confirm the browser is working."

Then stop. Wait for the user to come back and say "ready", "continue", "ok", "done" or similar. Do not narrate anything else in the meantime.

#### Step 2b — Smoke-test Playwright (after restart)

Once the user is back and confirms they have restarted, immediately verify Playwright is alive. Do not skip this — silent installs that "look fine" but never actually launch a browser are a real failure mode, and the only way to catch it is to drive a real page load.

Run, in this exact order:

1. `mcp__playwright__browser_navigate` to `https://example.com` — a tiny page that loads in under a second. The browser window opens visibly (headed mode, default for Playwright MCP) — the user will see a small browser pop up on their screen.
2. `mcp__playwright__browser_snapshot` — confirm the page rendered. The snapshot should contain the text "Example Domain". If it does not, Playwright is installed but not actually loading pages; stop and diagnose.
3. `mcp__playwright__browser_close` — close the browser window immediately. The user sees it close.

If `mcp__playwright__*` tools are STILL not visible after the user says "ready", they did not fully quit — closing the window is not enough. Say:

> "I still cannot see the browser tools. That means Claude Desktop did not fully restart. Please **right-click the Claude Desktop icon in your dock (Mac) or system tray (Windows) and choose Quit** — pressing Cmd+Q on Mac also works. Closing the window does not quit the app. Once it's fully closed, reopen it and tell me ready again."

Then wait again. Do NOT proceed to Phase 3 until the smoke test passes.

After a successful smoke test, say:

> "Browser is working. You just saw example.com open and close — that confirms I can drive a real browser for you. From now on, when I need to do anything in a browser (open a website, fill a form, log you in to a service), I will use this. Your logins will also be remembered, so you only sign in to each site once.
>
> Now let me show you what I can actually do for your business."

Mention to yourself in memory which tools came online — Claude's memory will retain that context automatically.

→ Move to Phase 3.

---

## PHASE 3 — LIVE DEMO

Pick based on their stated challenge:

**Marketing/content challenge:**
> "Let me research your competitors right now. Who is your main competitor? I will have a report in 2 minutes."
Use skills: `deep-research`, `competitor-alternatives`

**Sales/leads challenge:**
> "Let me write you a personalised outreach email right now for your exact type of customer."
Use skills: `copywriting`, `email-composer`, `avoid-ai-writing`

**Too busy/overwhelmed:**
> "Let me map out which tasks in your business I could take off your plate this week."
Use skills: `brainstorming`. If the user has the Superpowers plugin installed, follow on with `superpowers:writing-plans` to produce the formal plan; otherwise walk the plan through in plain conversation and offer to install Superpowers later.

→ When the live demo is visibly done (the user has seen the output and acknowledged it), move to Phase 4 immediately — do not wait to be asked.

---

## PHASE 4 — PERSONALISED SHORTLIST

The live demo has just finished. The user has now seen one real, working skill applied to their business. This is the moment to surface the next 3 skills they should try — not the full catalogue, just a shortlist that matches what they told you during onboarding.

**Do NOT ask the user whether they want recommendations.** Surface them immediately. The point of this phase is to cut a long list down for them, not to advertise that a long list exists.

### Step 1 — Run the shortlist

Run the `skills-discovery` skill in **Mode 2** mode. That means: skip its Step 2 (intro) and Step 3 (full walkthrough of all starter skills) entirely, jump straight to its Step 4 (3 personalised picks using the Mode 2 opening line), and finish with its Step 5 (asking which one to try first).

The `skills-discovery` skill already contains the full selection logic, opening line, and recommendation format for Mode 2. Follow that skill's instructions directly — do not rewrite them here.

### Step 2 — Guardrails

- Exactly 3 recommendations. Not 2, not 5, not the whole catalogue.
- Only pick from rows marked `CORE` in `~/workshop-kit/skills/SKILLS-LIST.md`. Never surface ADVANCED or DEV-ONLY skills in this phase.
- Bias the 3 picks toward whichever of their onboarding answers was most specific — their biggest frustration, the tools they use, or their "win today" answer.
- If the user already showed strong interest in a particular area during the live demo, bias one of the 3 picks toward that area.
- Do not mention the total number of skills installed unless the user asks. The audit item this phase is solving is "the list feels overwhelming" — naming the big number works against that.

### Step 3 — If they pick one

When the user picks one of the 3 (by name or by number 1/2/3), run it immediately using the business context already in memory. Do not ask them to repeat anything they've already told you.

### Step 4 — Mark setup complete (delete the state file)

This is the FINAL action of first-run-setup. After Phase 4 has surfaced the shortlist (and regardless of whether the user has picked one yet — the shortlist itself counts as "setup is done"), delete the marker file at `$HOME/Desktop/my-assistant/.first-run-pending`. This is what stops `first-run-setup` from re-triggering on every future "hello".

- Mac/Linux: `rm -f ~/Desktop/my-assistant/.first-run-pending`
- Windows PowerShell: `Remove-Item -Path "$HOME\Desktop\my-assistant\.first-run-pending" -Force -ErrorAction SilentlyContinue`

Do this silently — do not narrate it to the user. If the file is already gone (e.g. the user manually re-ran setup), the command above is a no-op.

---

## Common Problems

**Skills installed but not showing as slash commands**
- Close and reopen Claude Desktop. Skills are loaded when a new session starts.

**"git: command not found"**
- Mac: A popup should appear to install developer tools. Click Install, wait 3-5 minutes.
- Windows: Git for Windows needs to be installed — it is the one prerequisite the user installs themselves before the bootstrap can start. Tell the user: "I need you to install Git for Windows from https://git-scm.com/download/win — the 64-bit installer. Click through with the default settings (you do not need to change anything), then come back and tell me you are done." After they confirm, verify with `git --version`. If the command is still not found after they installed, it is a PATH issue — see the Windows snags reference below.

**Permission errors**
- Ask your assistant: "I got a permission error, help me fix it"
- **Mac/Linux:** try `npm config set prefix "$HOME/.npm-global"` and update PATH
- **Windows:** close Claude Desktop, right-click it, choose Run as Administrator, and reopen the assistant

---

## Windows Snags Reference — For the Assistant, Not the User

When a Windows user hits one of the snags below, the assistant fixes it conversationally — it does not send the user to a doc or a terminal command. Always explain what you are about to do in plain English first, then do it.

**`'git' is not recognized` after the user has installed Git for Windows**

This is a PATH problem — the Git installer is supposed to add `C:\Program Files\Git\cmd` to the System PATH but does not always succeed.

**Important — you (the assistant) cannot run the fix mid-conversation and have it take effect immediately.** Claude Desktop's terminal inherits the Windows environment at launch time. A PATH change made via PowerShell writes to the registry but does NOT update the currently-running Claude Desktop process. The user must fully quit and reopen Claude Desktop before `git` becomes available.

Two paths forward, in this order:

**Path A — Try the PowerShell fix (fast, needs admin):**

1. Tell the user: "Windows can't find Git yet. I'm going to add it to your PATH — this takes about 30 seconds, but you'll need to fully quit and reopen Claude Desktop afterwards for the change to take effect."
2. Run (in PowerShell):
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Git\cmd", [EnvironmentVariableTarget]::Machine)
   ```
   This needs administrator privileges.
3. If it succeeds: tell the user: "Done. Please fully quit Claude Desktop (not minimise — actually close it) and reopen it, then come back and tell me you're ready. The new PATH only applies to Claude Desktop after a restart."
4. If it fails with an access-denied error, admin is required and likely not available. Fall through to Path B.
5. After the user restarts Claude Desktop, verify with `git --version`.

**Path B — Send the user to the manual fallback in the setup docs:**

If Path A fails or admin isn't available, tell the user: "Windows needs me to use the Environment Variables dialog to fix this, but I don't have admin access from here. The setup guide has a step-by-step fallback for exactly this situation — open the guide, find the section titled **Fallback — If Git still isn't recognised after restarting Claude Desktop** in the Windows Users Only — Install Git section, and follow those 11 steps. Come back and tell me when `git --version` works."

**Do not tell the user you've 'fixed' their PATH and then try to run `git clone` in the same session — the current session cannot see the new PATH until Claude Desktop restarts. Always ask them to restart before you continue.**

If Git is installed in a non-default location, substitute the actual path. Check with `dir "C:\Program Files\Git\cmd"` first if uncertain.

**PowerShell says "running scripts is disabled" / "cannot be loaded because running scripts is disabled on this system"**

The user's PowerShell execution policy blocks local scripts. Fix by setting it to `RemoteSigned` at the `CurrentUser` scope — this is the safe choice recommended by Microsoft and does not require admin.

1. Tell the user: "Windows is blocking scripts on your computer — this is a safety setting. I'm going to change it to the standard recommended setting, which still blocks unsigned scripts from the internet but allows your own scripts to run. This takes one command."
2. Run (in PowerShell):
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
   ```
3. Verify with `Get-ExecutionPolicy -Scope CurrentUser` — it should return `RemoteSigned`.
4. Retry whatever command originally failed.

**`EPERM` or "permission denied" during `npm install`**

Claude Desktop does not have the permissions it needs. The fix is to run Claude Desktop as administrator.

1. Tell the user: "Windows is blocking the install because Claude Desktop does not have permission to write to this folder. Please close Claude Desktop completely, then right-click the Claude Desktop icon and choose Run as Administrator. Come back and tell me when you are ready."
2. After they return, retry the install.

**`EBUSY` during `npm install` (Windows Defender scanning files)**

Defender's real-time scanning is locking files as npm tries to write them.

1. Tell the user: "Windows Defender is scanning files faster than I can install them, which is blocking the install. I need you to temporarily pause Real-Time Protection for about 2 minutes — I'll tell you when it's safe to turn it back on. Do this: open **Windows Security** (you can search for it in the Start menu), click **Virus & threat protection**, click **Manage settings** under *Virus & threat protection settings*, and toggle **Real-time protection** to Off. Tell me when it is off."
2. After they confirm, retry the install.
3. When it succeeds, tell the user: "All done. Please turn Real-time protection back on now — same place, flip the toggle back to On."

**"Path too long" / `ENAMETOOLONG` / dependencies fail to extract**

The user's workshop folder is nested too deep. Windows has a 260-character path limit and OneDrive/Desktop paths like `C:\Users\Jane\OneDrive - Company Pty Ltd\Desktop\workshop-kit\node_modules\...\something.js` blow past it.

1. Tell the user: "Your folder is in a location with a really long path, which is breaking the install. I need you to move the workshop folder to a shorter path. Create a folder called `workshop` directly on your C drive (`C:\workshop`), then move the `workshop-kit` folder into it so the new path is `C:\workshop\workshop-kit`. Come back and tell me when you have done that."
2. Confirm the new path in your next reply so Claude's memory picks up the change.
3. Retry the install from the new location.

**Bun install fails on Windows / `bun: command not found` after install**

Bun is not yet shipped via winget on all Windows builds. Fall back to the PowerShell one-liner from bun.sh.

1. Run (in PowerShell):
   ```powershell
   powershell -c "irm bun.sh/install.ps1 | iex"
   ```
2. Tell the user: "Bun is installed. Please close this terminal and open a new one — the new tool will not be available until the terminal restarts. Come back and tell me you are ready."
3. Verify with `bun --version`.

**"Access denied" when editing System environment variables**

The user's account does not have administrator rights on the machine.

1. Tell the user: "You need administrator access to change this setting. If this is your personal laptop, right-click Claude Desktop and choose Run as Administrator. If this is a work laptop, you may need to ask your IT team for help — or let me know and we can work around it."
2. If it is a work laptop and IT is not available, try user-scoped alternatives (e.g. user PATH instead of system PATH for the Git fix above) and tell the user what you did.

---
