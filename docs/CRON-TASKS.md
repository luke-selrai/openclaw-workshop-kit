# Cron Tasks — Built-in Claude Code Tools

Prepared for: Claude Code Workshop Kit
Built by: Selr AI — selrai.com.au

---

## Table of Contents

1. [Overview](#1-overview)
2. [The 3 Built-in Cron Tools](#2-the-3-built-in-cron-tools)
3. [How CronCreate Works](#3-how-croncreate-works)
4. [How CronList Works](#4-how-cronlist-works)
5. [How CronDelete Works](#5-how-crondelete-works)
6. [Cron Tools vs /loop and /schedule](#6-cron-tools-vs-loop-and-schedule)
7. [When to Use Each](#7-when-to-use-each)
8. [Examples](#8-examples)
9. [Limitations](#9-limitations)
10. [Official Documentation](#10-official-documentation)

---

## 1. Overview

Claude Code has **3 built-in cron tools** that work 
underneath the `/schedule` command. These tools are what 
Claude uses internally to create, list, and delete scheduled 
tasks — participants do not need to use them directly, but 
understanding them helps when troubleshooting or building 
advanced automations.

> **Already using /loop and /schedule?**
> See `docs/AUTOMATION-LOOP-AND-SCHEDULE.md` for full 
> documentation on those commands. This document covers 
> the underlying cron tools that power them.

---

## 2. The 3 Built-in Cron Tools

Claude Code includes 3 internal tools for managing 
scheduled tasks:

| Tool | What It Does |
|---|---|
| **CronCreate** | Creates a new scheduled cron task |
| **CronList** | Lists all existing scheduled tasks |
| **CronDelete** | Deletes a scheduled task by ID |

These tools run automatically when you use `/schedule` — 
Claude calls them in the background. You can also ask 
Claude to use them directly in plain language.

---

## 3. How CronCreate Works

CronCreate creates a new recurring task with a cron 
expression defining when it runs.

**Claude uses this automatically when you run:**

/schedule

**Or you can ask Claude directly:**

Create a cron task that runs every morning at 8am
to summarise my unread emails

**Claude will generate the cron expression for you.**

### Cron Expression Format

│ │ │ │ └── Day of week (0–7, Sun=0 or 7)
│ │ │ └──── Month (1–12)
│ │ └────── Day of month (1–31)
│ └──────── Hour (0–23)
└────────── Minute (0–59)

### Common Cron Expressions

| Expression | When It Runs |
|---|---|
| `0 8 * * *` | Every day at 8am |
| `0 9 * * 1` | Every Monday at 9am |
| `0 * * * *` | Every hour |
| `*/30 * * * *` | Every 30 minutes |
| `0 8 * * 1-5` | Every weekday at 8am |
| `0 0 1 * *` | First day of every month |

---

## 4. How CronList Works

CronList shows all scheduled tasks currently set up 
in the session or project.

**Ask Claude directly:**
Show me all my scheduled tasks
or
List my cron tasks

**What it returns:**
- Task ID
- Cron expression
- Task description
- Date created
- Last run status

You can also view scheduled tasks at:
https://claude.ai/code/scheduled

---

## 5. How CronDelete Works

CronDelete removes a scheduled task by its ID.

**Ask Claude directly:**
Delete the cron task that sends my morning email summary
or
Cancel my scheduled Monday report

Claude will run CronList first to find the correct task ID, 
then confirm with you before deleting.

You can also manage and cancel tasks at:
https://claude.ai/code/scheduled

---

## 6. Cron Tools vs /loop and /schedule

The 3 cron tools, `/loop`, and `/schedule` all relate to 
automation but serve different purposes:

| | CronCreate / CronList / CronDelete | /schedule | /loop |
|---|---|---|---|
| What it is | Internal Claude tools | User command | User command |
| Who uses it | Claude (automatically) | Participants | Participants |
| Runs in cloud | ✅ | ✅ | ❌ |
| Needs computer on | ❌ | ❌ | ✅ |
| Duration | Permanent | Permanent | Max 7 days |
| Minimum interval | 1 hour | 1 hour | Seconds |
| Best for | Building automations via chat | Long-term tasks | Short-term or testing |

**Summary:**
- Participants use `/schedule` and `/loop` as commands
- Claude uses CronCreate, CronList, CronDelete internally
- Both achieve the same result — `/schedule` just makes 
  it conversational

---

## 7. When to Use Each

| Participant says... | Recommend |
|---|---|
| "Create a recurring task for me" | Ask Claude in plain language — it uses CronCreate |
| "Show me what tasks I have scheduled" | Ask Claude to list — it uses CronList |
| "Cancel that scheduled task" | Ask Claude to delete — it uses CronDelete |
| "Run this every morning" | `/schedule` command |
| "Run this for the next few days" | `/loop` command |
| "I want to automate this — where do I start?" | Start with `/schedule` for permanent, `/loop` for testing |

---

## 8. Examples

### Example 1 — Create via plain language
"Create a task that runs every weekday at 9am,
checks my Gmail for unread emails, and sends me
a summary in Telegram"

Claude will:
1. Ask for clarification if needed
2. Generate cron expression: `0 9 * * 1-5`
3. Call CronCreate to register the task
4. Confirm the task is scheduled

---

### Example 2 — List all tasks
"What tasks do I have scheduled?"

Claude will:
1. Call CronList
2. Show all active tasks with descriptions and next run times

---

### Example 3 — Delete a task
"Cancel the task that checks my emails every morning"

Claude will:
1. Call CronList to find the task
2. Confirm which task to delete
3. Call CronDelete to remove it
4. Confirm deletion

---

### Example 4 — Troubleshoot a task not running
"My scheduled email summary stopped running"

Claude will:
1. Call CronList to check the task status
2. Check last run result for errors
3. Suggest fix based on error type
4. Recreate with CronCreate if needed

---

## 9. Limitations

- Minimum schedule interval is once per hour — 
  cannot schedule more frequently than hourly
- Cloud-based cron tasks require a Claude Pro or 
  Max subscription
- Local cron tasks require the computer to stay on
- CronCreate, CronList, CronDelete are internal tools — 
  participants interact with them through plain language, 
  not direct commands
- Task history and logs are available at 
  `claude.ai/code/scheduled` but not directly in terminal
- Cron expressions use local timezone — not UTC

---

## 10. Official Documentation

- Scheduled Tasks: https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks
- Full automation reference: https://docs.anthropic.com/en/docs/claude-code/cron-tasks

> Always check the official docs for the latest behaviour — 
> Claude Code is updated frequently and task limits or 
> intervals may change.

---

## Related Documents

- `docs/AUTOMATION-LOOP-AND-SCHEDULE.md` — full docs for 
  `/loop` and `/schedule` commands
- `my-assistant/CLAUDE.md` — automation awareness baked 
  into the workshop assistant

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*