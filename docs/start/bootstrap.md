# Bootstrap Prompt — Claude Code AI Business Assistant

This prompt is used by workshop attendees to set up their AI Business Assistant.

**Primary source:** The workshop Notion page (selrai.notion.site) — attendees copy from there.
**This file:** Version-controlled backup. Update here whenever the Notion page is updated.
**Also appears in:** `docs/start/full-setup.md` Step 5 — keep both in sync.

---

## Before pasting — open Claude Code in the right folder

Workshop attendees are told (on the slide / Notion page) to do this BEFORE pasting the prompt:

1. Open **Claude Desktop** and start a **new Code session**.
2. When the file picker opens, click **Desktop** in the sidebar (left side of the window).
3. Click the **New Folder** button, name it exactly **my-assistant**, then click Open.
4. The Code session opens in `~/Desktop/my-assistant/`.
5. Paste the prompt below into the chat and press Enter.

---

## The Setup Prompt

Copy everything below and paste it into the new Code session you just opened in `~/Desktop/my-assistant/`:

---

I am setting up my Claude Code AI Business Assistant with Selr AI.

Do these steps one at a time, telling me what you are doing in plain English.
Use the correct commands for my operating system (detect whether I am on Mac or Windows).

The Code session you are running in right now is open at my workspace folder
(`~/Desktop/my-assistant/`). All of the file drops below go INTO this current
folder. Do not create a separate workspace anywhere else.

1. Clone the workshop kit from GitHub into my home folder:

   git clone https://github.com/selrai-company/claude-workshop-kit.git ~/workshop-kit

   (On Windows in PowerShell or Git Bash, the same command works — `~` resolves
   to my home folder.) If `~/workshop-kit` already exists, pause and ask me
   before overwriting it.

   After cloning, sanity-check that BOTH `~/workshop-kit/my-assistant/CLAUDE.md`
   and `~/workshop-kit/skills/` exist. If either is missing, the clone did not
   work — stop, tell me what happened, and ask me to retry.

2. Copy the assistant's instructions file into my current folder:
     - `~/workshop-kit/my-assistant/CLAUDE.md` → `./CLAUDE.md`
   (Note: `./CLAUDE.md` means the current folder, which is `~/Desktop/my-assistant/`.)

3. Create a small marker file in my current folder so the assistant knows to
   run first-run setup the next time I say hello:
     - touch `./.first-run-pending`
   (On Windows PowerShell: `New-Item -ItemType File -Path .\.first-run-pending`.)

4. Install all <!-- skills-audit:total -->120<!-- /skills-audit:total --> skills: copy every folder from `~/workshop-kit/skills/`
   into `~/.claude/skills/` (create the skills directory if it does not exist).
   Do not copy `SKILLS-LIST.md` — only the folders.

5. When everything is done, print this exact block to me, formatted as shown
   (separator lines included), with no extra paragraphs after it:

=========================================
 ✅ INSTALL COMPLETE
=========================================

DO THIS NEXT:

1. Click the folder icon at the top of Claude Desktop and start a NEW Code session.
2. In the file picker, click "my-assistant" in the Recent list (it will be at the top — Claude Desktop remembers it from this session).
3. The new session opens with your assistant's instructions loaded.
4. Type "hi" and press Enter.

Your assistant will introduce itself and finish setup from there.
=========================================

Talk to me like I am not technical. Plain English, one step at a time.
