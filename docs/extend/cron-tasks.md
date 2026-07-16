# Cron Tasks - Claude Code Internal Tools

> **See also:** `docs/extend/automation-loop-and-schedule.md` for the full picture of `/loop`, `/schedule` (cloud routines), `/package-as-routine`, and Desktop scheduled tasks.

---

## Overview

Claude Code has 3 built-in cron tools that power **in-session scheduling**: `/loop`, one-time reminders, and any task that fires inside the current session. Users do not call them directly - Claude uses them internally when a user asks to create, list, or delete a session task.

These tools are **not** what `/schedule` uses. `/schedule` creates a **cloud routine** on Anthropic's infrastructure - a separate system managed at https://claude.ai/code/routines. Keep the two apart when troubleshooting: session tasks live and die with the conversation; routines live in the cloud.

---

## The 3 Tools

| Tool | What It Does |
|---|---|
| **CronCreate** | Creates a new session task with a cron expression (recurring or one-shot) |
| **CronList** | Lists the session's scheduled tasks with their IDs |
| **CronDelete** | Deletes a session task by ID |

These run automatically when the user types `/loop` or asks in plain language (for example "remind me at 3pm to check the deploy").

---

## Cron Expression Format

```
┌─── Minute (0-59)
│ ┌─── Hour (0-23)
│ │ ┌─── Day of month (1-31)
│ │ │ ┌─── Month (1-12)
│ │ │ │ ┌─── Day of week (0-7, Sun=0 or 7)
│ │ │ │ │
* * * * *
```

### Common Expressions

| Expression | When It Runs |
|---|---|
| `*/5 * * * *` | Every 5 minutes |
| `0 8 * * *` | Every day at 8am |
| `0 9 * * 1` | Every Monday at 9am |
| `0 * * * *` | Every hour |
| `0 8 * * 1-5` | Every weekday at 8am |
| `0 0 1 * *` | First day of every month |

---

## How They Relate to /loop and /schedule

| | Cron tools (CronCreate / CronList / CronDelete) | /loop | /schedule (cloud routine) |
|---|---|---|---|
| **What it is** | Internal Claude tools | User command (uses the cron tools) | User command (separate cloud system) |
| **Runs in cloud** | No - inside your session | No | Yes |
| **Needs computer on** | Yes | Yes | No |
| **Duration** | Expires 7 days after creation | Expires 7 days after creation | Until paused or deleted |
| **Minimum interval** | 1 minute | 1 minute | 1 hour |

`/loop` is the conversational wrapper - it calls CronCreate under the hood. `/schedule` does not; it saves a routine to your claude.ai account instead.

---

## Managing Tasks

**Session tasks** (created by /loop or the cron tools):

1. **Plain language** - "Show me my scheduled tasks" (Claude calls CronList), "cancel the deploy check" (CronDelete)
2. **Esc** - pressing Esc while a /loop waits cancels its next fire

**Cloud routines** (created by /schedule or /package-as-routine): manage at https://claude.ai/code/routines, or with `/schedule list`, `/schedule update`, and `/schedule run`.

---

## Limitations

- Session tasks fire only while the session is open and idle; they expire 7 days after creation
- A session holds at most 50 scheduled tasks
- Cron expressions use the user's local timezone
- Fire times get a small fixed offset (jitter) so many sessions do not all start at the same wall-clock moment
- CronCreate/CronList/CronDelete are internal - users interact through plain language or `/loop`

---

## Official Documentation

- In-session scheduling and /loop: https://code.claude.com/docs/en/scheduled-tasks
- Routines (cloud): https://code.claude.com/docs/en/routines

---

*Built for the Claude Code Workshop by Selr AI - selrai.com.au*
