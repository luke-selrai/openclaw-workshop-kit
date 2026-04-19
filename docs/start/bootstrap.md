# Bootstrap Prompt — Claude Code AI Business Assistant

This prompt is used by workshop attendees to set up their AI Business Assistant.

**Primary source:** The workshop Notion page (selrai.notion.site) — attendees copy from there.
**This file:** Version-controlled backup. Update here whenever the Notion page is updated.
**Also appears in:** `docs/start/full-setup.md` Step 5 — keep both in sync.

---

## The Setup Prompt

Copy everything below and paste it into a new Code session in Claude Desktop:

---

I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

1. Download the workshop content by running:
   git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit

   NOTE: On Mac, if a popup appears asking to install developer tools,
   tell me to click "Install" and wait a few minutes before continuing.
   On Windows, if Git is not recognised, pause and tell me to install
   Git for Windows from https://git-scm.com/download/win, then to close
   and reopen Claude Desktop before we continue.

2. Create a folder called "my-assistant" in my home directory.

3. Copy this file from the downloaded workshop-kit into my-assistant:
   - workshop-kit/my-assistant/CLAUDE.md → my-assistant/CLAUDE.md

4. Install all <!-- skills-audit:total -->108<!-- /skills-audit:total --> skills: copy every folder from workshop-kit/skills/
   into ~/.claude/skills/ (create the skills directory if it does not exist).
   Do not copy SKILLS-LIST.md — only the folders.

5. When everything is done, tell me to start a new Code session in Claude
   Desktop and click the folder icon at the top to point it at my
   "my-assistant" folder:
   - Mac: ~/my-assistant
   - Windows: C:\Users\[my username]\my-assistant

Talk to me like I am not technical. Plain English, one step at a time.
