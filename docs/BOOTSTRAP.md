# Bootstrap Prompt — Claude Code AI Business Assistant

This prompt is used by workshop attendees to set up their AI Business Assistant.

**Primary source:** The workshop Notion page (selrai.notion.site) — attendees copy from there.
**This file:** Version-controlled backup. Update here whenever the Notion page is updated.
**Also appears in:** `docs/FULL-SETUP-PAGE.md` Step 5 — keep both in sync.

---

## The Setup Prompt

Copy everything below and paste it into Claude Code:

---

I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

1. Download the workshop content by running:
   git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit

   NOTE: On Mac, if a popup appears asking to install developer tools,
   tell me to click "Install" and wait a few minutes before continuing.

2. Create a folder called "my-assistant" in my home directory.

3. Copy this file from the downloaded workshop-kit into my-assistant:
   - workshop-kit/my-assistant/CLAUDE.md → my-assistant/CLAUDE.md

4. Install all 99 skills: copy every folder from workshop-kit/skills/
   into ~/.claude/skills/ (create the skills directory if it does not exist).
   Do not copy SKILLS-LIST.md — only the folders.

5. When everything is done, tell me to open the folder "my-assistant" in VS Code:
   - Mac: Cmd+Shift+P → type "open folder" → navigate to my home folder → my-assistant
   - Windows: Ctrl+Shift+P → type "open folder" → navigate to C:\Users\[my username]\my-assistant

Talk to me like I am not technical. Plain English, one step at a time.
