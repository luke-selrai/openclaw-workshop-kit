# Claude Code Automation

## /loop, /schedule (Cloud Routines), Desktop Scheduled Tasks, and the Routine Packager

Prepared for: Claude Code Workshop Kit
Built by: Selr AI - selrai.com.au

---

## Table of Contents

1. [Overview](#1-overview)
2. [The Four Options - At a Glance](#2-the-four-options--at-a-glance)
3. [/loop - Recurring Tasks While the Session Is Open](#3-loop--recurring-tasks-while-the-session-is-open)
4. [/schedule - Cloud Routines](#4-schedule--cloud-routines)
5. [/package-as-routine - When the Task Needs Your Tools and Sign-ins](#5-package-as-routine--when-the-task-needs-your-tools-and-sign-ins)
6. [Desktop Scheduled Tasks - Local, No Session Needed](#6-desktop-scheduled-tasks--local-no-session-needed)
7. [Always-On Server - Continuous Listeners](#7-always-on-server--continuous-listeners)
8. [How to Recommend the Right One](#8-how-to-recommend-the-right-one)
9. [Official Documentation Reference](#9-official-documentation-reference)

---

## 1. Overview

Claude Code supports automation in four ways, each suited to a different kind of task:

1. **`/loop`** - recurring tasks that run while your session is open
2. **`/schedule`** - creates a **cloud routine** that runs on Anthropic's infrastructure and does not need your computer. Each run starts fresh in the cloud, so it only suits self-contained tasks.
3. **`/package-as-routine`** - the kit's routine packager plugin. Use it when the scheduled task needs your connectors, sign-ins, or installed tools. It packages those into the cloud routine so the run actually works.
4. **Desktop scheduled task** - runs on your machine on a schedule without an open session, with full access to your local files and tools. Your computer must be on.

The first two are built into Claude Code. The third is a plugin bundled with this kit and installed during setup. The fourth is created in the Claude Desktop app.

**The single most important rule:** a plain `/schedule` cloud routine starts from a clean cloud machine. It cannot see your local files, your signed-in CLIs (like `gh` or `xero`), or MCP servers configured on your laptop. If the task depends on any of those, use `/package-as-routine` instead - otherwise the scheduled run fails silently.

---

## 2. The Four Options - At a Glance

| | /loop | /schedule (cloud routine) | /package-as-routine | Desktop scheduled task |
|---|---|---|---|---|
| **What it does** | Runs a task on a timer while your session is open | Runs a self-contained task in the cloud on a schedule | Packages a skill plus its tools and sign-ins into a cloud routine | Runs a task on your machine on a schedule, no open session needed |
| **Where it runs** | Your computer, inside the session | Anthropic's cloud | Anthropic's cloud (after packaging) | Your computer |
| **Needs your computer on?** | Yes | No | No | Yes |
| **Access to local files, sign-ins, CLIs** | Yes (inherits the session) | **No - starts fresh every run** | Yes - carried across by the packager | Yes |
| **Minimum interval** | 1 minute | 1 hour | 1 hour | 1 minute |
| **How long does it last?** | Expires 7 days after creation | Until you pause or delete it | Until you pause or delete it | Until you delete it |
| **How to create** | `/loop 5m <prompt>` | `/schedule`, or claude.ai/code/routines | `/package-as-routine` | Desktop app: Routines > New routine > Local |
| **Best for** | Quick checks and monitoring while you work | Simple recurring prompts needing no local tools | Daily briefs, reports, and workflows that use your connectors or CLIs | Local-file tasks on a schedule while the machine is on |

**Quick decision rule:**

- Need it only **while you're working**? Use `/loop`.
- Need it when the **computer is off**, and the task is fully self-contained? Use `/schedule`.
- Need it when the **computer is off**, and the task uses your connectors, sign-ins, or installed tools? Use `/package-as-routine`.
- Need **local files** on a schedule and the computer stays on? Use a Desktop scheduled task.

---

## 3. /loop - Recurring Tasks While the Session Is Open

### What It Does

Runs a task on a timer while your current session is open. When the session ends, the loop stops firing (resuming the same conversation restores a loop that has not expired).

### How to Use It

```
/loop 5m /some-command
```

This runs `/some-command` every 5 minutes. Supported units: `s` (seconds, rounded up to the nearest minute), `m` (minutes), `h` (hours), `d` (days).

If you leave out the interval, Claude paces itself: after each run it picks the next wait based on what it observed, checking more often while something is active and less often when things are quiet.

### Important Limitations

- **Session-scoped** - fires only while the session is open and idle.
- **Expires 7 days after creation**, even if the session stays open.
- **Minimum interval is 1 minute** - cron has one-minute granularity.
- **Uses your local timezone.**

### Best Use Cases

- Checking a website every few minutes for changes
- Watching for new messages or replies
- Monitoring something while you work
- Testing an automation before making it permanent as a routine

---

## 4. /schedule - Cloud Routines

### What It Does

`/schedule` creates a **routine**: a saved prompt that runs automatically on Anthropic's cloud infrastructure. It keeps running when your computer is off. Manage routines at https://claude.ai/code/routines or with `/schedule list`, `/schedule update`, and `/schedule run`.

### What Each Run Actually Gets

This is where automations most often go wrong, so be precise:

- Each run starts a **fresh cloud machine**. Nothing from your laptop is there.
- Your **claude.ai connectors** (the integrations connected on your claude.ai account) are included by default.
- Your **local files, locally configured MCP servers, and signed-in CLIs are NOT available**. A routine cannot use `gh`, a local Xero token, a local database, or anything else that lives on your machine - unless it was packaged in (see the next section).

### Key Details

- **Minimum interval:** once per hour.
- **Runs until you pause or delete it.**
- **Requires a claude.ai subscription sign-in** (Pro, Max, Team, or Enterprise with Claude Code on the web enabled).
- Times are entered in your local timezone.

### Best Use Cases

- A daily prompt that only needs claude.ai connectors (for example, summarise a Notion page each morning)
- Recurring research or drafting tasks with no local dependencies
- Anything self-contained that must run while you are away

---

## 5. /package-as-routine - When the Task Needs Your Tools and Sign-ins

### What It Does

The routine packager is a plugin bundled with this kit (installed during setup; it activates after a Claude Desktop restart). It takes a skill that works on your laptop and produces a cloud routine that works the same way: it inspects what the skill depends on, generates the setup script and configuration the cloud machine needs, carries your credentials across as secret environment variables, and creates the routine end to end, finishing with a test run.

### When to Use It

Use `/package-as-routine` instead of a plain `/schedule` whenever the task touches any of these:

- A connector or MCP server configured on your laptop
- A signed-in CLI (for example `gh`, `wrangler`, `vercel`)
- Local credentials, tokens, or files the task reads

If you set up a plain `/schedule` for such a task, the routine starts clean, finds none of those things, and fails - usually silently.

### How to Use It

```
/package-as-routine
```

Or say it naturally: "package my morning-brief skill as a routine, run daily at 8am."

---

## 6. Desktop Scheduled Tasks - Local, No Session Needed

Created in the Claude Desktop app: **Routines > New routine > Local**. The task runs on your machine on a schedule, without you keeping a session open.

- Full access to local files and tools, because it runs where they live.
- Minimum interval: 1 minute.
- The computer must be on and awake at run time.

Use it when the task genuinely needs your local machine (local files, local software) and the machine is reliably on - for example an office desktop that never sleeps.

---

## 7. Always-On Server - Continuous Listeners

All four options above are periodic: they wake up, run, and stop. If an automation must **listen continuously** and react within seconds - a 24/7 Telegram or WhatsApp bot, a webhook endpoint, a real-time queue watcher - a periodic wake-up is not enough. That calls for Claude Code running as a continuous process on a server you own.

That setup is its own project and lives in a separate kit: [`advanced-claude-workshop-kit`](https://github.com/selrai-company/advanced-claude-workshop-kit), which deploys a 24/7 agent stack on AWS. Most workshop users never need this - if every job is "wake up at time X, do Y, exit", use a routine instead.

---

## 8. How to Recommend the Right One

**If the request is ambiguous about when and where it should run** (for example "make this run every day at 7"), do not guess and do not create anything yet. Ask first, plainly and with no recommendation attached:

> "What type of automation do you want? a) something that runs only in this chat, b) something that runs at your set time while your computer is awake, or c) something that runs even while your computer is off?"

Route the answer: a = `/loop`, b = Desktop scheduled task, c = cloud routine (then check dependencies: connectors, sign-ins, or installed tools mean `/package-as-routine`; fully self-contained means `/schedule`).

**When the request is already explicit**, ask yourself: **does the task use any of the user's connectors, sign-ins, or installed tools?** Then use this table:

| User says... | Recommend |
|---|---|
| "Check this every few minutes while I work" | `/loop` |
| "Keep an eye on this while I work" | `/loop` |
| "Poll this until it is done" | `/loop` |
| "Do this every morning" and the task is fully self-contained | `/schedule` |
| "Do this every morning" and it uses Gmail, Xero, GHL, `gh`, or any local tool | `/package-as-routine` |
| "Run this even when my computer is off" and it needs my sign-ins | `/package-as-routine` |
| "Run this on my machine overnight" (machine stays on, needs local files) | Desktop scheduled task |
| "I want a Telegram bot that replies to messages 24/7" | Always-on server (see Section 7) |
| "I need a webhook endpoint Claude can answer" | Always-on server (see Section 7) |

> **Important:** the difference between `/schedule` and `/package-as-routine` is not the schedule - both create cloud routines. The difference is whether the run can reach what the task depends on. When in doubt, use `/package-as-routine`; it never hurts, while a plain `/schedule` fails silently when a dependency is missing.

---

## 9. Official Documentation Reference

- Routines (cloud): https://code.claude.com/docs/en/routines
- In-session scheduling and /loop: https://code.claude.com/docs/en/scheduled-tasks
- Desktop scheduled tasks: https://code.claude.com/docs/en/desktop-scheduled-tasks

This guidance applies to all automation tasks including Telegram, iMessage, WhatsApp, Notion, and any other channel, plugin, or connector automation.

---

*Built for the Claude Code Workshop by Selr AI - selrai.com.au*
