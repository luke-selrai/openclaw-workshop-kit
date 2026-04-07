---
name: first-run-setup
description: First-run setup and onboarding for the AI Business Assistant. Use when setup_complete is false in memory, when skills are missing, when the user says "my setup is broken", "fix my install", or "re-run setup".
---

# First Run Setup

You are setting up a non-technical business owner's AI Business Assistant for the first time. Follow these phases in order. Do not skip steps. Do not add extra checks beyond what is listed here.

**IMPORTANT:** Only perform the steps listed below. Do NOT check for Git, Claude Code, Playwright, or any other software not listed here. The bootstrap process already handled those. Your job is to verify skills, install Node.js, onboard the user, and show them a demo.

---

## PHASE 1 — SETUP VERIFICATION

Say:
> "Hi! I am your AI Business Assistant, built by Selr AI. Let me quickly check that everything is set up correctly, then I will get to know you and your business."

### Step 1 — Verify Skills Installed

Check if `~/.claude/skills/` has skill directories inside it.

- If it has directories → "Your skills are ready." Move to Step 2.
- If empty or missing → "It looks like your skills did not copy correctly. Let me fix that."
  1. Check if `~/workshop-kit/skills/` exists
  2. If yes → copy all skill folders (not SKILLS-LIST.md) to `~/.claude/skills/`
  3. If no → re-download: `git clone https://github.com/luke-selrai/claude-workshop-kit.git ~/workshop-kit` then copy.
  Use the correct commands for the user's operating system (Mac vs Windows).

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

If winget says "access denied", tell the user: "I need to run this with administrator access. Please right-click VS Code, choose Run as Administrator, then come back to me." After they restart VS Code as admin, retry the winget command.

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

**Windows note:** If it still says "command not found", tell the user: "Close VS Code completely and reopen it, then say 'continue' to me."

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
- Close and reopen VS Code. Skills are loaded when a new session starts.

**"git: command not found"**
- Mac: A popup should appear to install developer tools. Click Install, wait 3-5 minutes.
- Windows: Git for Windows needs to be installed. See the workshop Notion page for instructions.

**Permission errors**
- Ask your assistant: "I got a permission error, help me fix it"
- Mac: try `npm config set prefix ~/.npm-global` and update PATH
- Windows: Run VS Code as Administrator
