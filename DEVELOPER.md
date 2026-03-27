# Developer Notes — OpenClaw Workshop Kit

**Repo:** https://github.com/luke-selrai/openclaw-workshop-kit
**Contact:** Workshop facilitator — see your team contacts
**Workshop:** [DATE TBD], non-technical business owners, 3 hours

---

## What This Is

A self-installing AI business assistant kit. Non-technical business owners:
1. Install VS Code + Claude Code extension (done before workshop)
2. Paste a bootstrap prompt (from a Notion page) into Claude Code
3. Claude Code clones the repo, copies skills, creates the workspace — all conversationally
4. They open `~/my-assistant/` in VS Code, start Claude Code, and the CLAUDE.md agent takes over for onboarding and demos

---

## Repo Structure

```
openclaw-workshop-kit/
├── README.md                        # End-user quickstart
│
├── my-assistant/                    # THIS is what gets copied to ~/my-assistant/
│   ├── CLAUDE.md                    # AI agent brain — onboarding + demo agent
│   └── memory/
│       ├── USER.md                  # Onboarding placeholder (status: not-yet-onboarded)
│       ├── SETUP.md                 # Setup status tracker
│       └── MEMORY.md               # Persistent memory across conversations
│
├── skills/                          # 86 bundled business skills
│   ├── [25 CORE skills]             # Surfaced to all attendees via skills-discovery
│   ├── [~61 ADVANCED skills]        # Available on request
│   └── [8 DEVELOPER-ONLY skills]    # For web app / technical integration use cases
│
├── docs/
│   ├── BOOTSTRAP.md                 # Version-controlled copy of the Notion bootstrap prompt
│   ├── SUBSCRIPTIONS-AND-SOFTWARE.md # Full cost breakdown
│   ├── FIRST-5-PROMPTS.md           # Print + hand out — copy-paste prompts
│   ├── GLOSSARY.md                  # Plain-English tech terms
│   ├── COMPLETION-GUIDE.md          # Finishing setup at home after workshop
│   └── SKILLS-REFERENCE.md         # Every skill explained with examples
│
└── visuals/                         # Printable 4-page reference set
    ├── PAGE-1-AI-MODELS.md          # What AI is, Claude vs GPT vs Gemini, pricing
    ├── PAGE-2-YOUR-SETUP.md         # VS Code + Terminal + Claude Code diagram
    ├── PAGE-3-SKILLS-AND-AGENTS.md  # Skills, agents, Telegram/WhatsApp explained
    ├── PAGE-4-FULL-ECOSYSTEM.md     # Full ecosystem diagram
    └── page-1 to page-4 .png        # Generated image versions
```

---

## How the Setup Flow Works

The setup is now fully conversational — no bash scripts involved.

**Step 1: Bootstrap prompt (in any directory)**

Attendees copy a bootstrap prompt from the workshop Notion page and paste it into Claude Code. The bootstrap prompt instructs Claude to:
1. Clone the repo to `~/workshop-kit`
2. Copy skills from `skills/` to `~/.claude/skills/`
3. Copy `my-assistant/` to `~/my-assistant/`
4. Add Playwright MCP via `claude mcp add` command (no `.mcp.json` file needed)

No Node.js or Git pre-install needed on Mac. Windows users only need Git for Windows.

**Step 2: Open the workspace**

The user opens `~/my-assistant/` in VS Code and starts Claude Code. Claude reads `my-assistant/CLAUDE.md` and the agent takes over:
1. **Onboarding:** Asks 7 questions about their business, saves to `~/my-assistant/memory/USER.md`
2. **Demo:** Runs a live demo task matched to their stated business challenge

**Key design decisions:**
- The Notion page is the single source of truth for attendees — the bootstrap prompt lives there and can be updated without pushing to GitHub
- Playwright MCP is added via `claude mcp add` at the user scope, not via a `.mcp.json` file in the workspace

---

## What Needs Work (Priority Order)

### HIGH — Test the full bootstrap flow

The most important thing is a clean end-to-end test:
1. On a fresh Mac (or a new Mac user account) — not a developer machine
2. Open VS Code, start Claude Code, paste the bootstrap prompt
3. Does the repo clone, skill copy, and workspace creation all succeed?
4. Does opening `~/my-assistant/` in VS Code + starting Claude Code trigger the onboarding agent?
5. Does the Playwright MCP install step work (`claude mcp add` at user scope)?
6. Does onboarding save to the right path?

**Known potential issues:**
- `git clone` may trigger Xcode popup on fresh Mac — the bootstrap prompt should handle this gracefully
- Playwright MCP install command: `claude mcp add playwright npx @playwright/mcp@latest --scope user` — verify this is the correct syntax for the current Claude Code version
- `~/.claude/skills/` path — verify the bootstrap prompt copies skills here correctly

### HIGH — Windows support

Windows users need Git for Windows installed before running the bootstrap prompt. No other pre-installs required.
- Verify the bootstrap prompt works in Git Bash / PowerShell terminal inside VS Code
- `docs/WINDOWS-SETUP.md` should reflect the new bootstrap flow

### RESOLVED — Google Workspace

Gmail, Calendar, Drive, Docs, Sheets, and more are now handled by the Google Workspace CLI:
```bash
npm install -g @googleworkspace/cli
gws auth login
```
See `docs/GOOGLE-WORKSPACE-SETUP.md` for the full guide. Covers Gmail + Calendar + Drive + Docs + Sheets + Slides + Chat + Tasks + Contacts.

### MEDIUM — Playwright smoke test

After setup, there should be a quick test to confirm Playwright is working:
```bash
# Claude should be able to run something like:
# "Take a screenshot of google.com"
# and have it succeed
```

### LOW — Skills validation

Each skill in `skills/` is a SKILL.md file. Quick scan to check:
- All SKILL.md files are valid
- No Luke-specific content (personal API keys, specific business references)
- Descriptions are appropriate for non-technical business owners

---

## Update System

Attendees can pull updates from GitHub:

```bash
cd ~/workshop-kit && git pull origin main
```

For pushing updates to everyone: just commit to `main`. Next time they pull, they get everything new. The bootstrap prompt on Notion can also be updated independently — it is the single source of truth for the setup flow.

**Planned future updates:**
- More skills as they get built
- Additional MCP connections (Slack, HubSpot, Xero, etc.)
- Improved onboarding questions
- Server setup guide (for always-on agents)

---

## Tech Stack

- **Claude Code** — Anthropic's CLI tool (`@anthropic-ai/claude-code`)
- **Playwright MCP** — Browser automation (`@playwright/mcp`)
- **Skills system** — Plain markdown files in `~/.claude/skills/`
- **Memory system** — Plain markdown files in `~/my-assistant/memory/`
- **CLAUDE.md** — Plain markdown, read by Claude Code on startup
- **No database, no backend, no build step** — intentionally simple

---

## Questions

Anything unclear — reach out to the workshop facilitator via your team contacts.

