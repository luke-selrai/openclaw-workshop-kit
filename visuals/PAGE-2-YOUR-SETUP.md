# PAGE 2 — Your Setup: How Everything Connects

---

## The Big Picture

Think of your AI setup like a kitchen — you're the head chef, Claude is your sous chef, and the tools are the equipment.

```
┌─────────────────────────────────────────────────────────────────┐
│                        YOUR COMPUTER                             │
│                                                                   │
│   ┌──────────────────────────────────────┐  ┌──────────────┐    │
│   │          CLAUDE DESKTOP              │  │   BROWSER    │    │
│   │                                      │  │              │    │
│   │   ┌──────────────┐ ┌──────────────┐  │  │ Claude can   │    │
│   │   │  Chat panel  │ │  Code session │  │──│ control this │    │
│   │   │              │ │  + folder     │  │  │ Fill forms   │    │
│   │   │  Ask & read  │ │  + terminal   │  │  │ Scrape sites │    │
│   │   └──────────────┘ └──────────────┘  │  └──────────────┘    │
│   │                  │                   │                        │
│   └──────────────────┼───────────────────┘                        │
│                      ▼                                            │
│   ┌─────────────────────────────────────────────────────────┐    │
│   │                  YOUR AI ASSISTANT                       │    │
│   │                                                          │    │
│   │  Reads:    CLAUDE.md — your instructions & who you are  │    │
│   │  Remembers: auto-memory — your business profile         │    │
│   │  Uses:     <!-- skills-audit:total -->182<!-- /skills-audit:total --> Skills — specialist capabilities          │    │
│   │  Connects: MCP tools — Gmail, Calendar, CRM, and more   │    │
│   └─────────────────────────────────────────────────────────┘    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## What Each Part Does

### Claude Desktop
The app where you work with your assistant. Three surfaces, one window:
- **Chat panel** — natural conversation with your assistant
- **Code session** — opens a folder on your computer (like `~/Desktop/my-assistant/`) so the assistant can read and edit files
- **Built-in terminal** — lives at the bottom of a Code session. You paste commands here when the assistant asks. Most days you won't need it.

Free. One download from [claude.ai/download](https://claude.ai/download). Replaces the old "VS Code + Claude Code extension" setup.

> Developer already using VS Code? See [ADVANCED-VSCODE.md](../docs/extend/vscode.md) — the extension still works.

### CLAUDE.md — Your Instructions File
A file you can read and edit that tells Claude who you are, how to talk to you, and what it can do. It loads automatically every time you open Claude.

> Like an instruction manual for a new employee that Claude re-reads every morning.

### Skills (<!-- skills-audit:total -->182<!-- /skills-audit:total --> installed)
Specialist training programs that give Claude deep expertise. When you ask Claude to write ad copy, it reads the copywriting skill first. When you ask for competitor research, it reads the research skill. No extra steps needed — it chooses automatically.

> Like giving your assistant access to <!-- skills-audit:total -->182<!-- /skills-audit:total --> specialist textbooks they can reference on demand.

### MCP Tools — App Connections
Live connections to your other apps. Once connected, Claude can read your emails, check your calendar, update your CRM, and control your browser — without you having to copy and paste anything.

> Like giving your assistant login access to your business apps.

### Memory — Auto-memory
Claude's built-in memory that remembers everything you tell it across every conversation — your name, business, customers, communication style. You view or edit it by typing `/memory` in a Code session. It stays on your computer.

> This is what makes it YOUR assistant, not just any AI.

---

## Your File Structure

```
YOUR COMPUTER (your home folder, plus Desktop)
│
├── Desktop/
│   └── my-assistant/                ← Your workspace (you open this in Claude Desktop)
│       ├── CLAUDE.md                ← Claude's instructions (loads every session)
│       └── .first-run-pending       ← Marker file — gone once setup is done
│
├── workshop-kit/                    ← Cloned from GitHub during install (out of sight)
│   ├── skills/                      ← Source for the <!-- skills-audit:total -->182<!-- /skills-audit:total --> skill files
│   └── docs/                        ← Guides and reference docs
│
└── .claude/
    ├── skills/                      ← Where Claude looks for your installed skills
    └── (auto-memory)                ← Claude's own memory store (view with /memory)
```

---

## How a Conversation Works

```
You type a message
        │
        ▼
Claude reads CLAUDE.md (your instructions — loads every time)
        │
        ▼
Claude's auto-memory surfaces what it already knows about you
        │
        ▼
Claude picks the right skill (e.g. copywriting skill for writing tasks)
        │
        ▼
Claude does the work (research, writing, browser, automation)
        │
        ▼
Claude responds in your preferred style and format
        │
        ▼
If it learned something new → auto-memory captures it automatically
```

---

## The 3 Things You Will Ever Need

1. **Start your AI assistant:** Open Claude Desktop → start a new Code session → click `my-assistant` in the Recent list (or click Desktop in the file picker → my-assistant)
2. **Check what tools are connected:** In the assistant's chat, ask *"What tools do you have connected?"*
3. **Install a new tool connection:** In the assistant's chat, ask *"Help me connect [tool name]"* — the assistant walks you through it

That is it. Claude handles everything else.

---

## The First Time You Open It

When you open `~/Desktop/my-assistant/` in Claude Desktop for the first time, your assistant will:

1. Greet you by name (once set up)
2. Tell you what it remembers about your business
3. Ask what you want to work on
4. Do the task — using your skills and connected tools

Every session after that, it already knows who you are. No re-explaining needed.

---

*Claude Code Workshop — selrai.com.au*
