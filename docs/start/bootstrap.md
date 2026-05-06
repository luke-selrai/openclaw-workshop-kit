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

1. Find the workshop kit zip. Look in my Downloads folder for the most recently
   downloaded .zip whose name is either:
     - a long random string of letters, numbers, and dashes — for example
       "bfdc1600-797b-42d3-9803-1a9260dc1e94.zip"
     - or "claude-workshop-kit-main.zip"
   If nothing matching is in Downloads, also check my Desktop. Once you find
   one, just use it — do not ask me to confirm the filename.

2. Extract that zip into my home folder. The zip should contain a single
   top-level folder whose name starts with either
   "selrai-company-claude-workshop-kit-" or "claude-workshop-kit-".
   Rename that folder to "workshop-kit" so the final path is exactly
   ~/workshop-kit. Leave the original .zip file where it is — do not delete it.
   If ~/workshop-kit already exists, pause and ask me before overwriting it.

   After extracting, sanity-check that BOTH ~/workshop-kit/my-assistant/CLAUDE.md
   and ~/workshop-kit/skills/ exist. If either is missing, the zip you picked
   was the wrong one — stop, tell me what you found, and ask me where the
   correct workshop kit zip is saved.

3. Create a folder called "my-assistant" in my home directory.

4. Copy this file from the extracted workshop-kit into my-assistant:
   - workshop-kit/my-assistant/CLAUDE.md → my-assistant/CLAUDE.md

5. Install all <!-- skills-audit:total -->120<!-- /skills-audit:total --> skills: copy every folder from workshop-kit/skills/
   into ~/.claude/skills/ (create the skills directory if it does not exist).
   Do not copy SKILLS-LIST.md — only the folders.

6. When everything is done, tell me to start a new Code session in Claude
   Desktop and click the folder icon at the top to point it at my
   "my-assistant" folder:
   - Mac: ~/my-assistant
   - Windows: C:\Users\[my username]\my-assistant

Talk to me like I am not technical. Plain English, one step at a time.
