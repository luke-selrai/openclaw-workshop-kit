# Cron Tasks — Claude Code Internal Tools

> **See also:** `docs/extend/automation-loop-and-schedule.md` for the user-facing `/loop` and `/schedule` commands that sit on top of these tools.

---

## Overview

Claude Code has 3 built-in cron tools that power the `/schedule` command. Users do not call them directly — Claude uses them internally when a user asks to create, list, or delete scheduled tasks. Understanding them helps when troubleshooting or building advanced automations.

---

## The 3 Tools

| Tool | What It Does |
|---|---|
| **CronCreate** | Creates a new scheduled task with a cron expression |
| **CronList** | Lists all existing scheduled tasks |
| **CronDelete** | Deletes a scheduled task by ID |

These run automatically when the user types `/schedule` or asks in plain language (e.g. "create a task that runs every morning at 8am").

---

## Cron Expression Format

```
┌─── Minute (0–59)
│ ┌─── Hour (0–23)
│ │ ┌─── Day of month (1–31)
│ │ │ ┌─── Month (1–12)
│ │ │ │ ┌─── Day of week (0–7, Sun=0 or 7)
│ │ │ │ │
* * * * *
```

### Common Expressions

| Expression | When It Runs |
|---|---|
| `0 8 * * *` | Every day at 8am |
| `0 9 * * 1` | Every Monday at 9am |
| `0 * * * *` | Every hour |
| `*/30 * * * *` | Every 30 minutes |
| `0 8 * * 1-5` | Every weekday at 8am |
| `0 0 1 * *` | First day of every month |

---

## How They Relate to /loop and /schedule

| | Cron tools (CronCreate / CronList / CronDelete) | /schedule | /loop |
|---|---|---|---|
| **What it is** | Internal Claude tools | User command | User command |
| **Who uses it** | Claude (automatically) | Users | Users |
| **Runs in cloud** | Yes | Yes | No |
| **Needs computer on** | No | No | Yes |
| **Duration** | Permanent until deleted | Permanent until cancelled | Max 3 days |
| **Minimum interval** | 1 hour | 1 hour | Seconds |

`/schedule` is the conversational wrapper — it calls CronCreate under the hood. Both achieve the same result.

---

## Managing Tasks

Users can manage scheduled tasks in three ways:

1. **Plain language** — "Show me my scheduled tasks" (Claude calls CronList)
2. **Command** — `/schedule` in a Claude Code session
3. **Web** — https://claude.ai/code/scheduled

---

## Limitations

- Minimum interval is once per hour
- Requires Claude Pro or Max subscription
- Cron expressions use the user's local timezone
- Task history and logs are at `claude.ai/code/scheduled`, not in the terminal
- CronCreate/CronList/CronDelete are internal — users interact through plain language or `/schedule`

---

## Official Documentation

- Scheduled Tasks: https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks

---

*Original content by Khushi (PR #66). Cleaned up and merged by Selr AI.*
