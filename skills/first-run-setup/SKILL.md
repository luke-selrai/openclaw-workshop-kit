---
name: first-run-setup
description: First-run setup and onboarding for the AI Business Assistant. Use when setup_complete is false in memory, when skills are missing, when the user says "my setup is broken", "fix my install", or "re-run setup".
---

# First Run Setup

<!-- Path conventions: every file path in this skill is relative to the user's home folder. .claude/skills/ means $HOME/.claude/skills/ on Mac and Linux, and %USERPROFILE%\.claude\skills\ on Windows (Claude Code stores its user-level config in .claude inside the home folder on all platforms). workshop-kit/ and my-assistant/ are siblings inside the same home folder. When reading or copying files, always resolve paths relative to the user's home folder — never hardcode an absolute path or a username. Shell commands inside fenced bash blocks may use ~/ and $HOME natively (the shell expands them); shell commands inside fenced PowerShell blocks must use $HOME or $env:USERPROFILE. -->

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
  2. If yes → copy all skill folders (but not `SKILLS-LIST.md`) from the workshop kit's `skills/` folder into the user-level Claude skills folder.
  3. If no → re-download the workshop kit into the user's home folder, then copy the skills:
     - **Mac and Linux:** `git clone https://github.com/selrai-company/claude-workshop-kit.git "$HOME/workshop-kit"`
     - **Windows (PowerShell):** `git clone https://github.com/selrai-company/claude-workshop-kit.git "$HOME\workshop-kit"`

  Use the correct copy command for the user's operating system — `cp -R` on Mac/Linux, `Copy-Item -Recurse` (or `xcopy /E /I`) on Windows.

### Step 2 — Detect Operating System

Detect whether the user is on Mac, Windows, or Linux. Save this to memory.

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

### Step 4 — Mark Setup Complete

Save to memory:
- `setup_complete: true`
- `setup_date: [today's date]`
- `os: [Mac, Windows, or Linux]`
- `skills_installed: 87`

Say:
> "Everything looks good! Now let me learn a bit about you and your business. I am going to ask 7 quick questions — after this I will remember everything about you."

→ Move to Phase 2.

---

## PHASE 2 — ONBOARDING

Check memory for a user profile. If no profile exists → ask these questions one at a time:

1. "What is your first name?"
2. "What is your business called, and what do you do in one sentence?"
3. "Who are your customers — who do you help?"
4. "What is the biggest frustration or problem in your business right now?"
5. "What apps or tools do you use? For example: Gmail, Facebook, Xero, Instagram."
6. "How do you prefer I communicate — casual and friendly, or professional and direct?"
7. "What would feel like a win for you from today?"

Save all answers to memory as a user profile note covering: name, business, customers, biggest challenge, tools, communication style, workshop goal, and OS. Include a "How to Speak to Them" summary (2-3 sentences) and an "Always Remember" list of key facts.

Say:
> "Done! I have saved everything. I will always know who you are from now on. Now let me connect the tools that will make me really useful for you."

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

### Step 2 — Connect Browser Automation

Say:
> "Now I am going to connect to your browser. Once this is done, I can open websites and help you with things automatically."

```bash
claude mcp add playwright npx @playwright/mcp@latest --scope user
```

Verify:
```bash
claude mcp list
```

Look for `playwright` in the list. If it is there:
> "Your browser remote control is connected."

If it failed, try:
```bash
npm install -g @playwright/mcp
claude mcp add playwright @playwright/mcp --scope user
```

Save to memory which tools were connected.

Say:
> "All connected! Now let me show you what I can actually do for your business."

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
Use skills: `brainstorming`, `writing-plans`

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

Almost always a PATH problem — the Git installer is supposed to add `C:\Program Files\Git\cmd` to the System PATH but does not always succeed. Fix by editing the PATH directly:

1. Tell the user: "The Git install completed but Windows cannot find it yet. I'm going to add it to your PATH so every terminal can see it — this takes about 30 seconds."
2. Run (in PowerShell):
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Git\cmd", [EnvironmentVariableTarget]::Machine)
   ```
   This needs administrator privileges. If it fails with an access-denied error, tell the user: "I need to do this with administrator access. Please right-click Claude Desktop, choose Run as Administrator, then come back and tell me you are ready." After they reopen as admin, retry.
3. Tell the user: "I added it to your PATH. Please close Claude Desktop completely and reopen it — the new PATH will not be picked up until Claude Desktop restarts. Come back and tell me you are ready."
4. Verify with `git --version` after they return.

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
2. Update any stored paths in memory (`home_folder` / `workshop_path`) to the new location.
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
