# Bootstrap Prompt - Claude Code AI Business Assistant

This prompt is used by workshop attendees to set up their AI Business Assistant.

**Primary source:** The workshop Notion page (selrai.notion.site) - attendees copy from there.
**This file:** Version-controlled backup. Update here whenever the Notion page is updated.
**Also appears in:** `docs/start/full-setup.md` Step 5 - keep both in sync (byte-identical
between the anchors `I am setting up my Claude Code AI Business Assistant with Selr AI.`
and `Talk to me like I am not technical. Plain English, one step at a time.`).

---

## Before pasting - open Claude Code in the right folder

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

1. Make sure Node.js is installed. First check by running `node --version`.
   If that prints a version number, Node is already installed - skip the rest of
   this step. If it says "command not found" (or similar), install it now. This
   is part of setup, not something I needed to do beforehand:

   - On **Mac or Linux**, install it with nvm (the Node Version Manager). nvm
     installs Node into my home folder, so it never needs admin rights and never
     hits the permission errors a manual install can. Run:

         curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
         export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
         nvm install --lts
         nvm use --lts

     Then confirm with `node --version`. Node, npm, and npx are usable in this
     same session straight away - nothing needs to be reopened.

   - On **Windows**, install it with winget, then make it usable in THIS session
     without reopening anything:

         winget install --id OpenJS.NodeJS.LTS -e --source winget

     A Windows "allow this app to make changes?" box may appear - I just click
     Yes. When winget finishes, Node is on disk but this session's PATH has not
     picked it up yet. Refresh the PATH from the registry (machine + user) and
     check Node in ONE PowerShell command - both halves must run in the SAME
     invocation, because a fresh shell would lose the refreshed PATH:

         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); node --version

     That assignment changes the PATH for THIS process only - it never writes to
     the registry, so nothing on my machine is permanently changed and a later
     reopen behaves exactly as the proven baseline. If `node --version` now
     prints a version, Node is ready immediately and I do NOT need to reopen
     anything. For the rest of setup, prepend that same `$env:Path = ...;`
     refresh to every PowerShell command you run (each command is a new shell
     that has not seen the new PATH) - e.g. the `npx` install in step 2 becomes:

         $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User'); npx @louphq/install selr-ai/workshop-kit --token loupit_...

     ONLY if `node --version` still fails after that refresh: tell me to fully
     quit and reopen Claude Desktop so the new tools are picked up, then come
     back to this chat and tell you I'm ready. Once I'm back, confirm with
     `node --version`. Do not ask me to reopen unless the refresh actually
     failed - it almost always works without it.

   - If neither package manager is available, open https://nodejs.org in the
     browser (Playwright) and download the LTS installer for me automatically.
     Never ask me to click through a download myself.

2. Get and run my personalised install command. The workshop kit is delivered
   privately through Loup, so I paste in my own command rather than cloning
   anything:

   - Ask me to open my Loup dashboard, click "Get install command", copy the
     whole line - it looks like
     `npx @louphq/install selr-ai/workshop-kit --token loupit_...` - and paste it
     to you here.
   - Run exactly the command I paste. The same command works on Mac and Windows.
   - Then check the kit actually downloaded before going any further. The kit
     folder is `~/.loup/selr-ai/workshop-kit`. Confirm that this folder exists
     AND that BOTH `~/.loup/selr-ai/workshop-kit/my-assistant/CLAUDE.md` and
     `~/.loup/selr-ai/workshop-kit/skills/` exist inside it.
   - If that check passes, carry on to step 3.
   - If it does NOT pass, STOP here. Do not run any of steps 3-7 - they all
     depend on the kit being downloaded, so running them now would only pile
     confusing errors on top of the real one. From here you and I fix this
     together, in this chat, until the check passes. There is no limit on how
     many tries we take, and there is no one else to bring in - we sort it out
     between us. Loop through this until the kit is there:

       a. Show me the real, unedited output of the install command - every line
          it printed, word for word. Never swallow it, shorten it, or hide it
          behind a summary; that output is what tells us what went wrong.
       b. Tell me in plain English exactly which part of the check failed:
          whether the `~/.loup/selr-ai/workshop-kit` folder is missing
          altogether, or it exists but `my-assistant/CLAUDE.md` or `skills/`
          inside it is missing - a partial, half-finished download.
       c. Give me the one targeted fix that matches what you saw:
            - If the install was refused and the kit did not download - my
              command was not accepted (by far the most common cause: my command
              has gone stale, or my access had not switched on yet) - then the
              fix is to mint a fresh command. Ask me to open my Loup dashboard,
              click "Get install command" again, copy the whole new line, and
              paste it back to you. A freshly minted command almost always
              clears it on the next try.
            - If it looks like a network or download problem - a timeout, a
              dropped connection, a half-finished download - have me check I am
              online and run the same command again.
            - For anything else, tell me plainly what the output points to and
              the single next thing to try.
       d. Let me run the fix, then re-check the folder exactly as above.

     Keep repeating a-d - with no cap on attempts - until the check passes.
     Only then carry on to step 3.

3. Copy the assistant's instructions file into my current folder:
     - `~/.loup/selr-ai/workshop-kit/my-assistant/CLAUDE.md` → `./CLAUDE.md`
   (Note: `./CLAUDE.md` means the current folder, which is `~/Desktop/my-assistant/`.)

4. Create a small marker file in my current folder so the assistant knows to
   run first-run setup the next time I say hello:
     - touch `./.first-run-pending`
   (On Windows PowerShell: `New-Item -ItemType File -Path .\.first-run-pending`.)

5. Install all <!-- skills-audit:total -->204<!-- /skills-audit:total --> skills: copy every folder from `~/.loup/selr-ai/workshop-kit/skills/`
   into `~/.claude/skills/` (create the skills directory if it does not exist).
   Do not copy `SKILLS-LIST.md` - only the folders.

6. Install the routine packager. The kit bundles a plugin that lets me turn one
   of my skills into a scheduled cloud routine. Set it up now so it is ready
   when I need it. Run both commands:
     - claude plugin marketplace add ~/.loup/selr-ai/workshop-kit
     - claude plugin install routine-installer-plugin@selrai-workshop-kit
   If either reports it is already added or installed, that is fine. Carry on.
   (The packager only becomes active after the next Claude Desktop restart;
   nothing else is needed now. Do not try to use it yet.)

7. When everything is done, print this exact block to me, formatted as shown
   (the diagram inside a fenced code block, then the markdown banner below it),
   with no extra paragraphs after it:

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
│   192 SKILLS    │  │  42 CONNECTORS  │     │     BROWSER     │  │     MEMORY      │
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

1. **Start a new Code session** in Claude Desktop
2. **Type "hi"** and press Enter

Your assistant will introduce itself and walk you through the rest from there.

---

*Why a new session? Your assistant's instructions are now in this folder, but this session started before those instructions existed. A fresh session reads them at startup.*

Talk to me like I am not technical. Plain English, one step at a time.
