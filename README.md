# Claude Code Workshop — AI Business Assistant Kit

**Built by Selr AI — [selrai.com.au](https://selrai.com.au)**

> Give your business an AI assistant that remembers who you are, learns your business, and gets smarter every time you use it — without writing a single line of code.

---

## What Is This?

This kit sets up a personal AI business assistant on your laptop. Not a chatbot you close and forget — an assistant that:

- **Remembers your business** — your name, your customers, your biggest challenges
- **Lives on your computer** — runs locally, not in a browser tab
- **Controls your browser** — can open websites, fill forms, and do research for you
- **Has <!-- skills-audit:total -->188<!-- /skills-audit:total --> specialist skills** — research, copywriting, sales emails, social content, competitor analysis, and more
- **Gets smarter over time** — every conversation builds on the last

It is built on [Claude Code](https://claude.ai/claude-code) by Anthropic — configured specifically for your business.

---

## Read the docs in this order

Everything you need is in [`docs/`](docs/). The reading order:

| Step | Folder | When |
|---|---|---|
| 1 | [`docs/install/`](docs/install/) — what to buy and sign up for | **Before the workshop** |
| 2 | [`docs/start/`](docs/start/) — paste the bootstrap prompt, run the setup walkthrough | **During the workshop** |
| 3 | [`docs/use/`](docs/use/) — first prompts, what your assistant remembers, plain-English glossary | **Right after setup** |
| 4 | [`docs/skills/`](docs/skills/) — every skill your assistant can use, grouped by business problem (connecting outside tools is part of Group H) | **Week 1** |
| 5 | [`docs/extend/`](docs/extend/) — optional: VS Code path, scheduling, automation loops | **Month 2+** |
| — | [`docs/troubleshoot.md`](docs/troubleshoot.md) — when something is not working | **Any time** |

If you prefer VS Code over Claude Desktop, see [`docs/extend/vscode.md`](docs/extend/vscode.md) — advanced fallback, not recommended for first-time users.

---

## Quick Start

**Before the workshop**, complete these 2 steps — takes about 10 minutes:

1. Get a **Claude Max** subscription at [claude.ai](https://claude.ai) ($100 USD/month)
2. Install **Claude Desktop** at [claude.ai/download](https://claude.ai/download) and sign in

**Windows users:** also install [Git for Windows](https://gitforwindows.org) before arriving. Everything else (Node.js, Bun, Windows-specific snags) is handled conversationally by your assistant when you paste the bootstrap prompt.

No other pre-installs needed on Mac.

Full pre-workshop details: [`docs/install/`](docs/install/).

---

## At the Workshop

1. Open **Claude Desktop** and start a new Code session
2. In the file picker, click **Desktop** in the sidebar, click **New Folder**, name it `my-assistant`, and open it. The Code session opens in `~/Desktop/my-assistant/`.
3. Copy the **bootstrap prompt** from the workshop Notion page and paste it into the Code session
4. Claude handles everything — clones the kit from GitHub, copies skills, writes its instructions into your workspace
5. When it finishes, start a new Code session — you're already inside `my-assistant`, so the new session uses the same folder automatically
6. Type `hi` — the onboarding agent greets you, asks about your business, and shows you what it can do

Your assistant handles it all conversationally, one step at a time. No scripts to run, no commands to memorise.

Full walkthrough: [`docs/start/full-setup.md`](docs/start/full-setup.md).

---

## Common Questions

**Is my data private?**
Yes. Your `CLAUDE.md` and Claude's auto-memory (viewable with `/memory`) live on your computer only. Nothing is sent to a third party except your conversations with Claude (which go to Anthropic, same as using claude.ai normally).

**What does it cost after the workshop?**
Claude Max is $100 USD/month (~$155 AUD). That is the only required cost. Everything else in this kit is free.

**What if I miss a step during setup?**
Your assistant will notice and offer to fix it. Just open Claude Desktop, start a new Code session, and click `my-assistant` in the Recent list (or click Desktop → my-assistant in the file picker) — your assistant picks up where you left off.

**Can I use this on Windows?**
Yes. Install [Git for Windows](https://gitforwindows.org) beforehand, then paste the bootstrap prompt — your assistant walks you through everything else conversationally, including any Windows-specific snags. See [`docs/troubleshoot.md`](docs/troubleshoot.md) if something goes wrong.

---

## Support

- Workshop guides: [`docs/`](docs/)
- Selr AI: [selrai.com.au](https://selrai.com.au)

---

*Claude Code Workshop Kit — Built by Selr AI*
