---
name: google-workspace-connector
description: "Connect Google Workspace to Claude by switching on the built-in Gmail, Google Calendar and Google Drive connectors, or the `gws` CLI for the gaps. Use when the user asks to connect Google, Gmail, Calendar, Drive, Docs, Sheets or Google Chat, or wants email, meeting, file or spreadsheet work and Google isn't connected yet. Once connected, Workspace runs through the `mcp__claude_ai_Gmail__*`, `mcp__claude_ai_Google_Calendar__*` and `mcp__claude_ai_Google_Drive__*` tools or `gws`."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__claude_ai_Gmail__*, mcp__claude_ai_Google_Calendar__*, mcp__claude_ai_Google_Drive__*
metadata:
  category: Productivity & Integrations
  tags:
    - google-workspace
    - gmail
    - calendar
    - drive
    - docs
    - sheets
    - google-chat
    - installer
    - oauth
  pairs-with:
    - skill: email-composer
      reason: Compose the email content with email-composer, then send it via this connector
    - skill: google-chat-connector
      reason: Google Chat connects through this skill; google-chat-connector holds the day-to-day Chat reference
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting OAuth scope, unverified-app, or token failures
---

# Google Workspace Connector

## Overview

Google Workspace reaches Claude by two routes, and this skill owns both.

1. **The built-in connectors** — three separate listings in Claude's own connector
   directory, all built by Google: **Gmail**, **Google Calendar** and **Google
   Drive**. One button each, no install, no project setup. This is the default
   route and covers most of what people ask for, including sending mail.
2. **The kit's own route — the `gws` tool** (`@googleworkspace/cli`, command name
   `gws`). It reaches the handful of things no built-in connector can do:
   changing a Doc or Sheet that already exists, spreadsheets where formulas and
   cell structure matter, working with an email already saved as a draft,
   trashing mail, filters, the out-of-office responder, Google Tasks, and the
   full Google Chat surface.

**Both routes can coexist on one machine.** Never tear one down to set the other
up. A user who has the built-in connectors on and also signs in to `gws` has
gained reach, not created a conflict.

**Connect only what the user actually needs.** Run the interview below before
opening anything. If nobody needs to edit a live spreadsheet, they should never
be walked through the `gws` install.

**Google Chat** connects through this skill too, on the `gws` route (see the Chat
row in *Route by need*). Once Chat is connected, `google-chat-connector` is the reference for
operating it — spaces, formatting, safety rules, error handling.

---

## Communication rules

The user is a non-technical business owner. Every message follows the rules in
the installed assistant persona (`~/.claude/selr-assistant.md`):

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** Never say Node.js, npm, CLI, OAuth, scopes, PATH,
  terminal, shell, env var. If you must name a technical thing, describe it
  plainly: "the Google Workspace tool", "your browser", "the command window".
- **Tell them what is about to happen.** Before any action: "I'm going to install
  the Google Workspace tool for you - this takes about a minute."
- **React warmly.** Good: "Your Google account is connected - I can see your Gmail
  now." Bad: "OAuth flow completed, scopes `drive,gmail,sheets,calendar` granted."
- **Never show raw error messages.** Translate into plain English.
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths.** You run them; you do not paste them into chat.
- **Never ask for a password, a sign-in code, or a screenshot of a sign-in page.**
  Neither route needs one, and the built-in route handles no credentials at all.

---

## Phase 0 — What is already connected?

Run these silently, in order. Record the answer for each of the three built-in
connectors separately — a user can easily have Gmail on and Drive off.

1. **Built-in connectors.** `claude mcp list` → look for lines starting
   `claude.ai Gmail`, `claude.ai Google Calendar`, `claude.ai Google Drive`
   — and `claude.ai Google Chat`, if Chat came up, which if present is a custom
   connector someone added by hand rather than a directory listing. Match the
   vendor words case-insensitively; there is no `--json` flag.
   - `✔ Connected` → that surface is ready. Prove it before saying so, with one
     read from that connector's `mcp__claude_ai_<Name>__*` namespace.
   - `! Needs authentication` → the connection is on the account but its sign-in
     has lapsed. Open `https://claude.ai/customize/connectors` for the user and
     say: *"Your Google connection needs a quick re-sign-in. Press Reconnect next
     to it, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → not connected on this account (or the check in Phase 1 Step 1
     failed).
2. **The kit's own route.** Silently run `gws --version`, then `gws auth status`.
   A version plus a valid sign-in, confirmed by one cheap read
   (`gws gmail list --max-results 1`), means `gws` is already live. Keep it —
   say *"Google Workspace is already connected"* and do not set anything up on
   top of it.
3. **Everything the user needs is already covered** → skip to Phase 2.
   **Anything is missing** → run the interview.

If you cannot run commands at all (you are in claude.ai chat or the desktop app
rather than Claude Code), skip steps 1–2. Go straight to the interview, then
prove the result at Phase 1 Step 5 by calling one of the connector's tools.

**A local entry can hide a built-in one.** If a server was previously registered
locally at the same address (`~/.claude.json` under `mcpServers.<x>`), it takes
precedence and `/mcp` shows the built-in as hidden. If it works, leave it and say
so. If it is broken, prefer the built-in — and remove the local entry only with
the user's explicit OK.

---

## The interview — ask this before you open anything

Google Workspace is wide. Ask **one** question, in plain English:

> *"What would you like me to do with your Google account? For example — read and
> send your email? Manage your calendar? Find and read files in Drive? Update a
> spreadsheet you already have?"*

Ask about Chat **once**, in the same reply, whatever they named — nothing else
surfaces it, and it decides whether the `gws` route runs at all. If they
under-specify — "connect my email" — double-check the neighbours in that reply
too:

> *"Just email, or your calendar and files too? And does your team use Google
> Chat?"*

Then:

- Route each named need through the table below.
- **Connect only what they named.** Three built-in connectors is three separate
  Connect buttons; do not switch on Drive because it was convenient.
- Say in one line what you are **not** connecting, and why, so they can ask for it
  later: *"I've left your calendar out for now — say the word and it's one click."*
- Run the `gws` route **only** if a named need lands in the `gws` column. If the
  extra setup is not needed, do not put the user through it.

---

## Route by need

| What the user wants | Route |
|---|---|
| Search, read and summarise email; pull the thread behind a meeting | **Gmail** built-in |
| Draft an email; send, reply to or forward one | **Gmail** built-in |
| Apply labels, work with threads, list saved drafts | **Gmail** built-in |
| See email attachment names, sizes and types | **Gmail** built-in |
| **Change or send an email already saved as a draft** | `gws` |
| **Move mail to trash, delete mail** | `gws` |
| **Mail filters / rules; the out-of-office responder** | `gws` |
| **Open the contents of an attachment** | `gws` (the built-in sees the details, not the contents) |
| Anything calendar: view events and shared calendars, create, update, delete, RSVP, recurring meetings, attendee lists, find a time everyone is free, book a room | **Google Calendar** built-in |
| Find, read and summarise files: Docs, Sheets, Slides, PDFs, images, Word/Excel/PowerPoint | **Google Drive** built-in |
| Put something new into Drive: upload a file (converting it to Google format if wanted), save a file Claude just made, create folders | **Google Drive** built-in |
| Share, move or trash a file; see who has access; list recent changes | **Google Drive** built-in |
| **Change a Doc or Sheet that already exists, in place** | `gws` |
| **Spreadsheets where formulas, cell structure or formatting matter** | `gws` |
| **Rename a file; comment on a document** | `gws` |
| **Google Tasks** | `gws` |
| **Google Chat, all of it** | `gws` — unless a custom Chat connector is already on the machine; see the Chat note below |

Facts behind the table, worth saying out loud when they matter:

- **Sending is approval-gated.** Every Gmail send, reply and forward, and every
  Drive share, move and trash, asks the user to approve it first. That is on by
  default. On Team and Enterprise accounts the owner decides whether members may
  let those run without asking each time.
- **New Docs and Sheets are fine; existing ones are not.** Claude can produce a
  **new** Doc or Sheet through Drive two ways — upload with conversion to Google
  format, or save a Claude-made file. What no built-in connector can do is touch a
  document that **already exists**. Do not offer create-a-copy-and-replace as a
  substitute: it destroys comments, revision history and sharing settings. That
  workflow needs `gws`.
- **Sheets read as a flattened export.** Through the built-in, a spreadsheet
  arrives as plain comma-separated rows and Slides arrive as plain text — no
  formulas, no formatting, no cell-level structure, no comments or suggestions.
  If the user's question depends on any of that, it is a `gws` job.
- **There is no separate Google Docs or Google Sheets connector.** Docs and
  Sheets are reached through Drive, and only as above.
- **Personal Gmail and Workspace accounts behave the same** on the built-in
  route. The only Workspace-specific step is the admin trust in Phase 1.
- **The directory's Read / Read-&-write badges lag reality.** Route on this table,
  not on the badge.

### Google Chat — the note

**There is no built-in Google Chat connector.** Chat is not in the connector
directory and there is no tile to find in Browse. **Chat rides the `gws` route** —
the same Google Cloud project the ladder in Phase 1-alt already creates, with
`chat` added to the sign-in scopes. That is the whole setup story for Chat in
this skill.

One thing to check for, though. A machine may **also** carry a custom Google Chat
connector someone added by hand: it shows up in `claude mcp list` as
`claude.ai Google Chat` and its tools are `mcp__claude_ai_Google_Chat__*` —
listing and searching messages, searching conversations, and sending a message.
On the connector settings page it is typed **Web Custom**, not plain Web, which
is the tell. It points at Google's Developer Preview server and getting it there
takes the user's own Google Cloud OAuth client plus a hand-pasted address.

- **Phase 0 finds one already connected** → use it for reading, searching and
  sending messages, and `gws` for everything else Chat can do (spaces and member
  listings, threaded replies, rich cards, output formats).
- **Phase 0 finds none** → do not set one up. It needs the same Google Cloud
  work as `gws` plus an extra address paste, and buys nothing over `gws`. Run the
  `gws` route with `chat` in the scopes.

Once Chat is connected either way, hand the day-to-day work to
`google-chat-connector`.

---

## Phase 1 — Switch on the built-in connectors (the default route)

One-time, once per Google account. The only thing the user does is press a
button and sign in. Nothing here touches a password or a code, and none of it
needs anything installed.

**Step 1 — Check this session can see built-in connectors.** `claude auth status`
must show `"authMethod": "claude.ai"`. If it shows anything else, or
`~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or
`ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear
here. Tell the user in one line that this copy of Claude is signed in a different
way, and run the kit's own route (Phase 1-alt) instead.

**Step 2 — Open the connector page(s) for them.** Open each one the interview
named, in the user's **own** browser (`open` on Mac, `xdg-open` on Linux,
`start ""` on Windows) — that is where they are signed in to Claude and to Google.

| Surface | Page |
|---|---|
| Gmail | `https://claude.ai/directory/gmail` |
| Google Calendar | `https://claude.ai/directory/google-calendar` |
| Google Drive | `https://claude.ai/directory/google-drive` |

All three slugs were verified live on 2 September 2026 at
`https://claude.com/connectors/<slug>`, the public mirror of each listing.
Google Chat has no row here on purpose — it is not in the directory, and Phase 1
never connects it. Chat is handled by the `gws` route in Phase 1-alt.

If a page doesn't load, open `https://claude.ai/customize/connectors` instead and
tell them: **Browse** → search the name → **Connect**.

- **They named one surface** → open that page and say: *"I'm opening Gmail's page
  in your browser. Press **Connect to Claude**, sign in to Google the way you
  normally do, and say yes when it asks for access. That's the only part only you
  can do — tell me when it says Connected."*
- **They named two or three** → make it **one trip**, not three. Open all the
  named pages in tabs at once and say: *"I've opened them in your browser — one
  tab each. Press **Connect to Claude** in each one and sign in with the same
  Google account. Tell me when they all say Connected."* Naming the same Google
  account matters: three connectors signed into three different accounts is the
  most common mess here.

**Never drive this sign-in with Playwright.** Hand the link to the user's own
browser and step back. The kit's usual caution about not touching a
participant's browser exists because the custom path reads secrets off a page —
this path reads nothing, so opening a link in their browser is the right move.

**Step 3 — Wait.** Stay hands-off while they sign in.

**Step 4 — Verify.** `claude mcp list` again. A `✔ Connected` line for each
surface they connected is the pass.
- Not there yet → no restart will change this answer: `claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes. Read on:
- Still missing → `! Needs authentication` means Reconnect on the Customize page.
  No line at all means the Connect didn't finish — send them back to Step 2.

**Step 5 — Prove it.** Call one real read through each connector — one tool from
the `mcp__claude_ai_Gmail__*`, `mcp__claude_ai_Google_Calendar__*` or
`mcp__claude_ai_Google_Drive__*` namespace. Only a real answer counts; a tool
error is not "connected". Those tools are often deferred in a session, so fetch
the namespace before calling. In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app, connectors added during a session are documented to appear without a restart; if one doesn't, start a new session there.

**Step 6 — Hand off.** Two lines: it's connected, and three things they can ask
for now.

### The two gates that stop this route

**Claude-side (Team or Enterprise).** If the page shows **Request** instead of
**Connect**, the user's Claude admin has to switch the connector on for the
organisation first, and connectors only work inside private projects. Say so
plainly and stop. Do not fall back to the `gws` route just to get past an admin
gate.

**Google-side.** Only bites when the user's Workspace restricts outside apps.
Then their Google admin does this once, at admin.google.com → Security → Access
and data control → API controls → Manage third-party app access → Add app →
search Claude → mark **Trusted**. It takes about **15 minutes to take effect** —
tell the user to expect the wait rather than retrying in a loop.

Assume a paid Claude plan. The published guidance conflicts on whether the newer
sending actions are paid-only; plan for paid.

---

## Phase 1-alt — The kit's own route: install and sign in to `gws`

Run this **only** when a need the user actually named lands in the `gws` column
of the routing table, or when Phase 1 Step 1 showed this copy of Claude can't see
built-in connectors, or when the user explicitly asks for the local tool. It is a
longer setup and it is not needed for everyday Gmail, Calendar or Drive work.

This part installs the `gws` tool, runs the one-time Google Cloud project setup,
and completes sign-in. It works on Windows, Mac, and Linux.

### Step 1 - Detect the user's OS

Silently run:

```bash
uname -s           # darwin = Mac, linux = Linux
```

On Windows the above will fail - detect Windows separately (e.g., check
`OS=Windows_NT` in env, or presence of `where.exe`).

Remember the OS - you'll adjust permissions messaging in Step 2.

### Step 2 - Check that Node.js is installed

Tell the user: *"I'm checking if Node.js is already on your computer. Takes a few seconds."*

Silently run:

```bash
node --version
```

- If a version prints → "Node.js is ready." Go to Step 3. Needs v18 or higher.
- If not found or too old → install it. Follow `docs/start/setup.md` Step 0
  ("Node") for the platform-appropriate install path (nvm on Mac/Linux, winget on
  Windows). Do NOT send the user to a website.

### Step 3 - Install the Google Workspace tool

Tell the user: *"I'm installing the Google Workspace tool now. About 30 seconds."*

Silently run:

```bash
npm install -g @googleworkspace/cli
```

If the install fails with a permission error on macOS/Linux, retry with
`sudo npm install -g @googleworkspace/cli`.

Refresh PATH so the command is available immediately without a restart:

**Mac/Linux:**
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```

**Windows (Command Prompt):**
```bat
for /f "tokens=*" %i in ('npm prefix -g') do set PATH=%i\bin;%PATH%
```

Verify:

```bash
gws --version
```

- Version prints → "That's ready." Go to Step 4.
- `gws: command not found` → PATH issue. Apply the Windows PATH refresh from
  `docs/start/setup.md` (Step 0), then re-verify.
- Permissions error on Windows → tell the user plainly: *"The install needs
  administrator rights. Please close the window, right-click it and choose 'Run as
  administrator', then say 'ready'."* Wait, then retry.

### Step 4 - One-time Google Cloud project setup

If the user has never set up `gws` on this computer before, they need a Google
Cloud project to act as the OAuth client. There are three paths - pick one based
on what the user has.

Tell the user: *"Before signing you in, I need to set up a small Google Cloud
project in your Google account - it's the thing that actually talks to Gmail,
Calendar, and Drive. The tool does this automatically. Takes about a minute."*

**Path A - a teammate already set it up (fastest).** If someone on the user's
team already configured this, ask them for their `client_secret.json` file. It is
safe to share within an org - it identifies the app, not any individual's login.
Save it to `~/.config/gws/client_secret.json` and skip to Step 5.

**Path B - let the tool do it.** Silently run:

```bash
gws auth setup
```

Follow the prompts on the user's behalf:

- When it asks for a project ID, use something short and user-specific, like
  `gws-<firstname>-assistant`. If you don't know their first name, use
  `gws-my-assistant`.
- If it asks for confirmation, confirm.
- Expected output: `Setup complete`.

If the user has the `gcloud` tool already authenticated, `gws auth setup --login`
does the whole thing in one shot - it creates the project, switches on the Chat,
Gmail, Calendar and Drive interfaces, configures the client, and signs in. If
they don't have `gcloud`, either install it via
[gcloud-connector](../gcloud-connector/SKILL.md) first, or use Path C.

**Path C - manual, when both of the above fail.**

1. Go to https://console.cloud.google.com
2. Create a new project (or use an existing one)
3. Enable these APIs: Gmail API, Google Calendar API, Google Drive API, and
   **Google Chat API** if the interview said the team uses Chat
4. Go to **APIs & Services → Credentials → Create Credentials → OAuth client ID**
5. If prompted, configure the OAuth consent screen (choose **Internal** if inside
   a Workspace org)
6. Application type: **Desktop app** → name it → **Create**
7. Click **Download JSON** on the credential you just made
8. Save it as `~/.config/gws/client_secret.json`

**If the user has already done this before on this computer** - skip this step.
Silently checking whether `gws auth setup` has run before is tricky; if you're
not sure, just run it - the tool handles the "already set up" case gracefully.

### Step 5 - Sign the user in

Tell the user: *"Now I'm going to open your browser so you can sign into the
Google account you want me to use. Pick the right one - if you use one for
personal and one for business, the one you pick here is the one I'll work with."*

Silently run — **include `chat` in the scope list only if the interview said the
team uses Google Chat**:

```bash
gws auth login -s drive,gmail,sheets,calendar,docs,tasks        # no Chat
gws auth login -s chat,drive,gmail,sheets,calendar,docs,tasks   # with Chat
```

This opens the user's default browser to Google's sign-in page. Walk them through
it in plain English before they click:

1. *"Your browser just opened Google's sign-in page. Pick the account you want me to use."*
2. *"You might see a warning that says 'Google hasn't verified this app' - that's normal. Click 'Continue' or 'Advanced' and then 'Go to \[your project name\] (unsafe)'. It's your own project, it's safe."*
3. *"Then click 'Allow' to give me permission to read and write on your behalf."*
4. *"You'll see a success message in the browser - that's it."*

Wait for the tool to return to the prompt with a success message.

**If the browser doesn't open automatically** - look for a URL in the terminal
output starting with `https://accounts.google.com/...`. Copy it and tell the
user: *"Open this link in your browser manually and follow the same steps."*

**If the user hits 'Access blocked'** - two fixes, both covered in `gws` docs:
1. Limit scopes: retry with `gws auth login -s drive,gmail,sheets,calendar`
   (unverified apps are capped at around 25 scopes total) — keep `chat` in the
   list if the interview said the team uses Google Chat.
2. Add the user's email as a test user: tell them to go to the GCP Console →
   APIs & Services → OAuth consent screen → Test users → Add, paste their email,
   save, then retry.

### Step 6 - Confirm it works

Tell the user: *"Let me check it's working - I'll glance at your inbox. Won't send anything."*

Silently run a read-only command, e.g.:

```bash
gws gmail list --max-results 1
```

- Returns a message → *"Looks good - your Google account is connected. You can ask
  me to send emails, check your calendar, find files in Drive, or anything else
  Google-related now."*
- Returns a scope error → rerun `gws auth login` with the full scope list and walk
  the user through sign-in again. Explain plainly: *"I need a little more
  permission - let me re-do the sign-in with the right set of tick-boxes."*

**If Chat is in scope**, confirm it separately — `gws auth status` should show
`"token_valid": true`, then:

```bash
gws chat spaces list --format table
```

A list of spaces, even an empty one, is a pass. Two things to know before you
run it:

- **Google Chat through `gws` is Workspace-only.** A personal `@gmail.com`
  account cannot use it — that surface is a work/school-domain feature. If the
  user is on a personal account, say so before setting anything up rather than
  after: *"Google Chat only works with a work or school Google account. Yours is
  a personal one, so that part won't connect — everything else will."*
- **An empty list with no error** means either the user genuinely has no spaces,
  or they signed in with a personal account. Check the signed-in address.

### Step 7 - Optional: install the Google Workspace tool's own skills

The `gws` tool generates a skill for each Workspace product it covers (Docs,
Sheets, Slides, Forms, Tasks, Chat, plus Gmail, Calendar and Drive) and a set of
personas and recipes. This is **optional** - the connector works without them.
The ones worth having on this route are the Docs, Sheets, Slides, Forms, Tasks and
Chat set: that is exactly the ground the built-in connectors do not cover. The
Gmail, Calendar and Drive ones only earn their place when the built-in connectors
are **not** connected on this machine (Phase 0 said so), because the routing table
sends that work to the built-in otherwise. Skip the personas and recipes.

Ask the user: *"Want me to install the deeper Google Docs, Sheets and Chat skills?
They let me work inside spreadsheets and documents you already have. Totally
optional - you can skip this and I'll still handle everything."*

If yes, silently run the block below. Two facts, verified with `gws` 0.22.5: the
command writes `skills/` and `docs/skills.md` **into the current folder** and takes
no output flag, so it must run in a scratch folder, never in the user's project;
and every generated skill reads `gws-shared` first, so that one always comes along.

```bash
TMP="$(mktemp -d)" && ( cd "$TMP" && gws generate-skills >/dev/null ) \
  && mkdir -p ~/.claude/skills \
  && for s in gws-shared gws-docs gws-docs-write gws-sheets gws-sheets-read gws-sheets-append \
              gws-slides gws-forms gws-tasks gws-chat gws-chat-send; do
       rm -rf ~/.claude/skills/"$s" && cp -R "$TMP/skills/$s" ~/.claude/skills/; done \
  && rm -rf "$TMP"
```

Add `gws-gmail gws-gmail-send gws-gmail-read gws-gmail-reply gws-calendar
gws-calendar-agenda gws-calendar-insert gws-drive gws-drive-upload` to that list
only on a machine with no built-in Gmail, Calendar and Drive connectors.

On Windows (PowerShell) the same shape: create a temp folder, `Set-Location` into
it, run `gws generate-skills`, then `Copy-Item -Recurse` each wanted folder from
`.\skills\` into `$HOME\.claude\skills\`, and remove the temp folder.

Tell the user: *"Done. You've got the deeper Docs, Sheets and Chat skills now -
they kick in automatically when you ask for them."*

Phase 1-alt is complete.

---

## PHASE 2 - Operate the Connector

Use whichever route the user is connected on. Never paste a command at them; run
it and summarise the result in plain English.

**Which tools.** Through the built-in connectors the tools are
`mcp__claude_ai_Gmail__*`, `mcp__claude_ai_Google_Calendar__*` and
`mcp__claude_ai_Google_Drive__*` (and `mcp__claude_ai_Google_Chat__*` for Chat).
Through the kit's route they are `gws` subcommands. If both are live on a
machine, prefer the built-in for anything in its column of the routing table and
reach for `gws` only for the gaps.

**Where the two differ materially,** and it is worth saying to the user:

- A built-in send asks the user to approve it. A `gws` send does not — which is
  why the safety rules below make you confirm by hand.
- A built-in read of a spreadsheet is a flattened export. A `gws` read is the real
  sheet.
- A built-in cannot change an existing Doc or Sheet at all. If a request needs
  that and only the built-in is connected, say so and offer the `gws` route
  rather than working around it with a copy.

### Common `gws` commands

Use `gws --help` or `gws <subcommand> --help` to discover options if you're
unsure. Core subcommands (as of April 2026):

| User asks for | Subcommand shape |
|---|---|
| "Send an email" | `gws gmail send --to "..." --subject "..." --body "..."` |
| "Check my inbox" | `gws gmail list --max-results 20` |
| "What's on my calendar today / this week" | `gws calendar list --today` or `gws calendar list --this-week` |
| "Schedule a meeting" | `gws calendar create --title "..." --start "..." --end "..." --attendees "..."` |
| "Find a file in Drive" | `gws drive search "query"` |
| "Create a Google Doc" | `gws docs create --title "..."` |
| "Add a row to [sheet]" | `gws sheets append --sheet-id "..." --range "..." --values "..."` |
| "Show my Google Tasks" | `gws tasks list` |
| "Send a message in Google Chat" | use the `google-chat-connector` skill for the full Chat reference |

### Multi-step workflows

When the user asks for something that spans multiple steps (e.g., "find John's
email then check his calendar availability then draft a meeting invite"), chain
the calls silently and summarise only the outcome. Do not narrate the individual
steps.

### Safety rules

- **Confirm before sending emails.** For any outbound email, draft the content,
  show the user the subject + recipient + first two lines of the body in plain
  text, and ask *"Send this?"* Wait for explicit yes before sending. The built-in
  route also asks for its own approval; yours comes first.
- **Confirm before creating calendar events that affect other people.** For events
  with attendees, show the user the title, time, and attendees first. Events with
  no attendees (personal blocks) can skip confirmation.
- **Never delete without confirmation.** Anything that would remove data (emails,
  files, events, rows) must be confirmed with the user first.
- **Read-only first.** If the user says something ambiguous like "show me" or
  "check", default to a read.
- **Never echo credentials.** The built-in route handles none at all. On the
  `gws` route, the sign-in lives in `~/.config/gws/` and stays there — never in
  the transcript, a tool return, or a log.

---

## Troubleshooting

### Built-in route

| Symptom | Likely cause | What you do |
|---|---|---|
| No `claude.ai Gmail` / `Google Calendar` / `Google Drive` line at all | Not connected on this account, or this session can't see built-in connectors | Re-run Phase 1 Step 1; if that passes, send them back to Phase 1 Step 2 |
| `! Needs authentication` | The sign-in lapsed | `https://claude.ai/customize/connectors` → **Reconnect** next to that row |
| Connected on claude.ai, still not visible in Claude Code | The session loaded its connectors at start | Fully quit and reopen Claude Code once, then re-check |
| Page shows **Request**, not **Connect** | Team/Enterprise admin hasn't enabled it | Their Claude admin enables it for the organisation; stop until they do |
| Connect finishes but every call is refused | Workspace restricts outside apps | Google admin marks Claude **Trusted** at admin.google.com (Phase 1 gates), then wait ~15 minutes |
| Built-in shows as hidden in `/mcp` | A locally registered server at the same address takes precedence | If it works, leave it; if broken, remove the local entry with the user's OK |
| A Doc or Sheet won't update | No built-in connector can change an existing file | Say so; offer the `gws` route |

### `gws` route

| Symptom | Likely cause | What you do |
|---|---|---|
| `gws: command not found` after install | PATH not refreshed | Close and reopen terminal, or `export PATH="$(npm prefix -g)/bin:$PATH"`; on Windows apply the PATH refresh from `docs/start/setup.md` (Step 0) |
| `permission denied` during `npm install` | Needs admin / sudo | Windows: close the terminal, right-click, "Run as administrator", retry. Mac/Linux: retry with `sudo` |
| `Access blocked` during sign-in | Unverified-app scope cap or missing test user | Retry with limited scopes: `gws auth login -s drive,gmail,sheets,calendar`. If that still fails, add the user as a test user in GCP Console → OAuth consent screen |
| Wrong Google account signed in | User picked the wrong one on the sign-in screen | `gws auth logout`, then `gws auth login` again; tell the user to double-check which account they pick |
| Browser didn't open during sign-in | No default browser / running headless | Copy the URL from the terminal, tell the user to open it manually |
| "Google hasn't verified this app" warning | Normal for personal projects | Tell the user it's safe - their own project, not a third party |
| `gws` works in terminal but Claude Code says "not found" | Claude Desktop's terminal inherits env at launch | Tell the user to fully quit Claude Desktop and reopen it |
| Subcommand returns a scope error | Sign-in missed a scope | Re-run sign-in with the full list: `gws auth login -s chat,drive,gmail,sheets,calendar,docs,tasks` |
| `failed to decrypt token cache` | Local cache corrupted | `rm ~/.config/gws/token_cache.json`, then sign in again |

For anything not covered here, if the Superpowers plugin is installed, invoke
`superpowers:systematic-debugging`. Otherwise work through the failure step by
step - isolate what changed, form a hypothesis, verify before fixing - and
summarise the outcome in plain English.

---

## Reference - what lives where

- **Built-in connectors:** Gmail (`https://claude.ai/directory/gmail`), Google
  Calendar (`.../google-calendar`), Google Drive (`.../google-drive`), all built
  by Google; slugs verified 2 September 2026 on the public mirror
  `https://claude.com/connectors/<slug>`. Google Chat is **not** in the directory
  and has no page — it rides the `gws` route.
- **Connections are account-level.** Connect once on claude.ai or the desktop app
  and it is available everywhere on that account, including Claude Code, as long
  as Claude Code is signed in with that same claude.ai account.
- **No sign-in can be switched on programmatically**, on any plan. Every route
  ends with the user pressing the button themselves.
- `gws` CLI source: npm package `@googleworkspace/cli`
- OAuth client config: user's own Google Cloud project (created by `gws auth setup`)
- Access tokens: stored by `gws` under `~/.config/gws/` (path is OS-specific; the
  tool handles it)
- Optional deeper skills: `gws generate-skills` writes them into `skills/` under the
  **current folder** (no output flag); Step 7 runs it in a scratch folder and copies
  the wanted ones into `~/.claude/skills/`
- Google Chat day-to-day reference: [google-chat-connector](../google-chat-connector/SKILL.md)
