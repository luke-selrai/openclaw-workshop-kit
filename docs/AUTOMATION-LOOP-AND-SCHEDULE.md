# Claude Code Automation

## /loop and /schedule — Full Documentation

Prepared for: Claude Code Workshop Kit
Built by: Selr AI — selrai.com.au

---

## Table of Contents

1. [Overview](#1-overview)
2. [The Two Packages — At a Glance](#2-the-two-packages--at-a-glance)
3. [/loop — Temporary Recurring Tasks](#3-loop--temporary-recurring-tasks)
4. [/schedule — Persistent Recurring Tasks](#4-schedule--persistent-recurring-tasks)
5. [How to Recommend the Right One](#5-how-to-recommend-the-right-one)
6. [Official Documentation Reference](#6-official-documentation-reference)
7. [Changelog — What We Updated](#7-changelog--what-we-updated)

---

## 1. Overview

Claude Code now supports two automation features that let users run tasks on a recurring basis. These are designed for non-technical business owners who want to automate parts of their workflow — posting to Notion, sending daily reports, checking a website, or any other repeated task.

This document covers both features in full, explains when to use which, and includes the changelog of updates made to the workshop assistant's CLAUDE.md file.

---

## 2. The Two Packages — At a Glance

Claude Code automation comes in two packages. Think of them like two different tools in a toolbox — one for quick jobs while you are at your desk, and one for jobs that need to run on their own.

| | /loop | /schedule |
|---|---|---|
| **What it does** | Runs a task on a timer while your session is open | Runs a task on a schedule in the cloud, even when your computer is off |
| **Where it runs** | On your computer, inside your current session | On Anthropic's cloud servers |
| **Needs your computer on?** | Yes | No |
| **How often can it run?** | Every few seconds to every few days | Minimum once per hour |
| **How long does it last?** | Stops when you close the session (auto-expires after 3 days) | Runs indefinitely until you cancel it |
| **How to create** | Type `/loop 5m /some-command` | Type `/schedule`, or use claude.ai/code/scheduled, or the Desktop app |
| **Best for** | Quick checks, monitoring while you work, testing something | Daily reports, weekly posts, anything long-term or overnight |
| **Timezone** | Uses your local timezone | Uses your local timezone |

**Quick decision rule:** Computer must be on? Use `/loop`. Needs to run even when your computer is off? Use `/schedule`.

---

## 3. /loop — Temporary Recurring Tasks

### What It Does

Runs a task on a timer while your current session is open. When you close the session, the loop stops automatically. Think of it like setting a kitchen timer — it keeps going until you turn it off or leave the kitchen.

### How to Use It

Type this in your Claude Code session:

```
/loop 5m /some-command
```

This runs `/some-command` every 5 minutes. If you leave out the time, it defaults to every 10 minutes.

### Time Options

| Unit | Meaning | Example |
|---|---|---|
| s | Seconds | `/loop 30s /check-status` |
| m | Minutes | `/loop 5m /check-website` |
| h | Hours | `/loop 2h /send-update` |
| d | Days | `/loop 1d /daily-check` |

### Important Limitations

- **Session-scoped** — stops when you close the session.
- **Auto-expires after 3 days** — even if you leave the session open, the loop will stop after 3 days.
- **Uses your local timezone** — not UTC or any other timezone.
- **Only runs while your computer is on** and the session is active.

### Best Use Cases

- Checking a website every few minutes for changes
- Watching for new messages or replies
- Monitoring something while you work
- Testing an automation before making it permanent with `/schedule`

---

## 4. /schedule — Persistent Recurring Tasks

### What It Does

Creates a task that runs automatically on a schedule in the cloud. It keeps running even when your computer is off — Anthropic's servers handle it for you. Think of it like hiring someone to do a job on a set schedule, whether you are in the office or not.

### How to Create a Scheduled Task

There are three ways to create a scheduled task:

**In Claude Code (CLI or VS Code):** Type `/schedule` and follow the prompts.

**On the web:** Go to https://claude.ai/code/scheduled and create it there.

**In the Desktop app:** Use the scheduling feature in the Claude Desktop app.

### Key Details

- **Minimum interval:** once per hour — you cannot schedule anything more frequently than hourly.
- **Each run starts a fresh session** with full access to your files, tools, skills, and connectors.
- **Runs on Anthropic's cloud** — your computer does not need to be on.
- **Runs indefinitely** until you cancel it.
- **Uses your local timezone.**

### Best Use Cases

- Posting to Notion every morning
- Sending a weekly summary report every Monday
- Daily social media content scheduling
- Recurring maintenance or cleanup tasks
- Anything that needs to run overnight or when you are away

### Managing Scheduled Tasks

You can view, edit, and cancel your scheduled tasks at any time by visiting https://claude.ai/code/scheduled or by typing `/schedule` in your Claude Code session.

---

## 5. How to Recommend the Right One

When a user asks about automating something, use this table to recommend the right approach:

| User says... | Recommend |
|---|---|
| "Check this every few minutes" | `/loop` |
| "Do this every morning" | `/schedule` |
| "Keep an eye on this while I work" | `/loop` |
| "Send me a report every Monday" | `/schedule` |
| "Poll this until it is done" | `/loop` |
| "Run this even when my computer is off" | `/schedule` |

---

## 6. Official Documentation Reference

For the full, up-to-date documentation on both /loop and /schedule, refer to the official Anthropic documentation:

https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks

This documentation applies to all automation tasks including Telegram, iMessage, WhatsApp, Notion, and any other channel, plugin, or connector automation.

---

## 7. Changelog — What We Updated

**Date:** April 02, 2026
**Branch:** cron-tasks

### Added: Automation Section

Added a new "AUTOMATION — /loop and /schedule" section to `my-assistant/CLAUDE.md`, placed between Phase 4 (Skills Discovery) and the "If Something Breaks" section.

This section includes:

- Quick decision rule for choosing between /loop and /schedule
- /loop documentation — syntax, time units, session-scoped behaviour, 3-day auto-expiry, local timezone
- /schedule documentation — cloud-based execution, minimum 1-hour interval, three creation methods (CLI, web, Desktop app)
- Plain-English examples for how to explain each feature to non-technical users
- Recommendation table mapping common user phrases to the correct tool
- "If You Get Stuck" pointer to official Anthropic docs with full URL

### Revised: Plain English Pass

Removed developer-facing jargon to match the non-technical tone of the rest of CLAUDE.md:

| Removed | Replaced With |
|---|---|
| CronCreate, CronList, CronDelete | (removed entirely — internal tools, not user-facing) |
| UTC | "your local timezone" |
| "polling a build or deployment" | "checking a website", "watching for new messages" |
| "remote agent" | "task that runs in the cloud" |
| "Anthropic cloud infrastructure" | "the cloud" / "Anthropic's servers" |
| "MCP servers" | "tools, skills, and connectors" |

### Updated: Official Docs URL

Changed the docs reference from the bare domain (`code.claude.com/docs/en/scheduled-tasks`) to the full clickable URL (`https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks`).

### Updated: Channel References

Changed "Telegram, iMessage, Discord, and any other plugin or channel" to "Telegram, iMessage, WhatsApp, and any other channel, plugin, or connector" — matching the actual channels covered in the workshop kit.

---

*Built for the Claude Code Workshop by Selr AI — selrai.com.au*
