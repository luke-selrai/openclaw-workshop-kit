# Developer Notes — Claude Workshop Kit

**Repo:** https://github.com/selrai-company/claude-workshop-kit
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
claude-workshop-kit/
├── README.md                        # End-user quickstart
├── DEVELOPER.md                     # This file
├── SKILLS-GUIDE.md                  # Skill categories with examples (attendee-facing)
│
├── my-assistant/                    # THIS is what gets copied to ~/my-assistant/
│   ├── CLAUDE.md                    # AI agent brain — onboarding + demo agent
│   └── memory/
│       ├── USER.md                  # Onboarding placeholder (status: not-yet-onboarded)
│       ├── SETUP.md                 # Setup status tracker
│       └── MEMORY.md               # Persistent memory across conversations
│
├── skills/                          # 99 bundled business skills
│   ├── SKILLS-LIST.md               # Master reference — all 99 skills with tier and examples
│   ├── [22 CORE skills]             # Surfaced to all attendees via skills-discovery
│   ├── [69 ADVANCED skills]         # Available on request (includes all connector skills)
│   └── [8 DEV-ONLY skills]          # For web app / technical integration use cases
│
├── docs/
│   ├── BOOTSTRAP.md                 # Version-controlled copy of the Notion bootstrap prompt
│   ├── FULL-SETUP-PAGE.md           # Complete end-to-end setup guide
│   ├── COMPLETION-GUIDE.md          # Finishing setup at home after workshop
│   ├── ACCOUNTS-AND-LOGINS.md       # Every account to create before the workshop
│   ├── SUBSCRIPTIONS-AND-SOFTWARE.md # Full cost breakdown
│   ├── FIRST-5-PROMPTS.md           # Print + hand out — copy-paste prompts
│   ├── GLOSSARY.md                  # Plain-English tech terms
│   ├── SKILLS-REFERENCE.md          # Most-used skills explained with examples
│   ├── TROUBLESHOOTING.md           # Common problems and fixes
│   ├── AUTOMATION-LOOP-AND-SCHEDULE.md  # /loop and /schedule reference
│   ├── CRON-TASKS.md                # Scheduled task internals (developer reference)
│   ├── GOOGLE-WORKSPACE-SETUP.md   # Gmail, Calendar, Drive connector
│   ├── OUTLOOK-SETUP.md             # Microsoft 365 connector
│   ├── TELEGRAM-SETUP.md            # Telegram bot setup
│   ├── WHATSAPP-SETUP.md            # WhatsApp channel setup
│   ├── IMESSAGE-SETUP.md            # iMessage plugin (Mac only)
│   ├── SHOPIFY-SETUP.md             # Shopify connector
│   ├── GHL-SETUP.md                 # GoHighLevel CRM connector
│   ├── QUICKBOOKS-SETUP.md          # QuickBooks Online connector
│   ├── STRIPE-SETUP.md              # Stripe payments connector
│   ├── GOOGLE-CHAT-SETUP.md         # Google Chat connector
│   ├── dispatch/DISPATCH-SETUP.md   # Claude Dispatch (multi-agent)
│   └── known-issues/                # Known issues with fixes
│
├── visuals/                         # Printable 4-page reference set
│   ├── PAGE-1-AI-MODELS.md          # What AI is, Claude vs GPT vs Gemini, pricing
│   ├── PAGE-2-YOUR-SETUP.md         # VS Code + Terminal + Claude Code diagram
│   ├── PAGE-3-SKILLS-AND-AGENTS.md  # Skills, agents, Telegram/WhatsApp explained
│   └── PAGE-4-FULL-ECOSYSTEM.md     # Full ecosystem diagram
│
├── xero-connector/                  # Xero OAuth MCP server (Node.js)
└── whatsapp-channel/                # WhatsApp channel server (Bun/TypeScript)
```

---

## How the Setup Flow Works

The setup is fully conversational — no bash scripts involved.

**Step 1: Bootstrap prompt (in any directory)**

Attendees copy a bootstrap prompt from the workshop Notion page and paste it into Claude Code. The bootstrap prompt instructs Claude to:
1. Clone the repo to `~/workshop-kit`
2. Copy skills from `skills/` to `~/.claude/skills/`
3. Copy `my-assistant/` to `~/my-assistant/`
4. Add Playwright MCP via `claude mcp add` command (no `.mcp.json` file needed)

Mac and Linux: no pre-installs needed.
Windows: attendees need [Git for Windows](https://gitforwindows.org) installed first — everything else (Node.js, PATH fixes, PowerShell execution policy, Defender EBUSY, OneDrive path-too-long) is handled conversationally by `skills/first-run-setup/SKILL.md`.

**Step 2: Open the workspace**

The user opens `~/my-assistant/` in VS Code and starts Claude Code. Claude reads `my-assistant/CLAUDE.md` and the agent takes over:
1. **Onboarding:** Asks 7 questions about their business, saves to `~/my-assistant/memory/USER.md`
2. **Demo:** Runs a live demo task matched to their stated business challenge

**Key design decisions:**
- The Notion page is the single source of truth for attendees — the bootstrap prompt lives there and can be updated without pushing to GitHub
- Playwright MCP is added via `claude mcp add` at the user scope, not via a `.mcp.json` file in the workspace
- The conversation IS the product — no silent installer scripts. Everything happens through Claude so errors are caught and explained conversationally

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

### MEDIUM — Playwright smoke test

After setup, there should be a quick test to confirm Playwright is working:
```
# Ask Claude: "Take a screenshot of google.com"
# It should succeed and describe what it sees
```

### LOW — Skills validation

Each skill in `skills/` is a SKILL.md file. Ongoing check:
- No personal references (team member names, personal API keys, internal-only business context)
- Descriptions appropriate for non-technical business owners
- Example prompts are realistic for a small business owner

### RESOLVED — Windows setup

Windows guidance was consolidated into `README.md` (one-line Git prerequisite) and `skills/first-run-setup/SKILL.md` (runtime snags). `docs/WINDOWS-SETUP.md` was removed in #85.

### RESOLVED — Google Workspace

Handled via `gws` CLI. See `docs/GOOGLE-WORKSPACE-SETUP.md`.

### RESOLVED — Xero, Shopify, GHL, QuickBooks, Stripe, Google Chat

All major business connectors now have skills and setup docs. See `docs/` for individual setup guides.

---

## Update System

Attendees can pull updates from GitHub:

```bash
cd ~/workshop-kit && git pull origin main
```

For pushing updates to everyone: just commit to `main`. Next time they pull, they get everything new. The bootstrap prompt on Notion can also be updated independently — it is the single source of truth for the setup flow.

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
