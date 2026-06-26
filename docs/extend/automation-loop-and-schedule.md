# Claude Code Automation

## /loop, /schedule, and Always-On Server, Full Documentation

Prepared for: Claude Code Workshop Kit
Built by: Selr AI, selrai.com.au

---

## Table of Contents

1. [Overview](#1-overview)
2. [The Three Tiers, At a Glance](#2-the-three-tiers--at-a-glance)
3. [/loop, Temporary Recurring Tasks](#3-loop--temporary-recurring-tasks)
4. [/schedule, Persistent Recurring Tasks](#4-schedule--persistent-recurring-tasks)
5. [Always-On Server, Your Own Machine, Running 24/7](#5-always-on-server--your-own-machine-running-247)
6. [How to Recommend the Right One](#6-how-to-recommend-the-right-one)
7. [Official Documentation Reference](#7-official-documentation-reference)
8. [Changelog, What We Updated](#8-changelog--what-we-updated)

---

## 1. Overview

Claude Code supports automation at **three different tiers**, each suited to a different kind of task:

1. **`/loop`**, temporary, recurring tasks that run while your session is open
2. **`/schedule`**, persistent, hourly-or-slower tasks that run on Anthropic's cloud and don't need your computer
3. **Always-on server** ([`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)), Claude Code running 24/7 on a server you own, for things that need to listen continuously (Telegram bots, WhatsApp, headless Slack, daemon mode)

The first two are built into Claude Code and need zero setup. The third is a separate workshop kit you deploy on your own infrastructure when you have an automation that genuinely needs to run continuously rather than periodically.

This document covers all three, explains when to use which, and includes the changelog of updates made to the workshop assistant's CLAUDE.md file.

---

## 2. The Three Tiers, At a Glance

Claude Code automation comes in three tiers. Think of them as three different tools in a toolbox, one for quick jobs while you are at your desk, one for periodic jobs that need to run on their own, and one for jobs that have to listen continuously.

| | /loop | /schedule | Always-on server |
|---|---|---|---|
| **What it does** | Runs a task on a timer while your session is open | Wakes up periodically and runs a task on Anthropic's cloud | Keeps Claude Code running continuously on a server you own |
| **Where it runs** | On your computer, inside your current session | On Anthropic's cloud servers | On a server you provision (e.g. EC2, VM, home Linux box) |
| **Setup needed** | None | None | Yes, provision a server, install Claude Code, run setup scripts from [`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit) |
| **Needs your computer on?** | Yes | No | No |
| **How often can it run?** | Every few seconds to every few days | Minimum once per hour | Continuously, runs all the time |
| **Periodic or always-on?** | Periodic | Periodic | Always-on |
| **How long does it last?** | Stops when you close the session (auto-expires after 3 days) | Runs indefinitely until you cancel it | Runs until you stop the server |
| **How to create** | Type `/loop 5m /some-command` | Type `/schedule`, or use claude.ai/code/scheduled, or the Desktop app | Follow the deployment guide in [`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit) |
| **Best for** | Quick checks, monitoring while you work, testing something | Daily reports, weekly posts, hourly-or-slower recurring tasks | 24/7 Telegram bots, headless WhatsApp/Slack listeners, daemon-mode Claude Code, server-hosted MCP listeners |
| **Cost** | Free (your machine) | Free (Anthropic's cloud) | Whatever your server costs |
| **Timezone** | Uses your local timezone | Uses your local timezone | Whatever the server is set to |

**Quick decision rule:**

- Need it to run **only while you're working**? → `/loop`
- Need it to **wake up periodically** (hourly or slower) when your computer is off? → `/schedule`
- Need it to **listen continuously** (e.g. respond to inbound Telegram messages the moment they arrive)? → **Always-on server** via `claude-cloud-kit`

**`/schedule` and the always-on server are not the same thing.** `/schedule` runs on Anthropic's infrastructure with zero setup but only fires periodically (minimum once per hour). The always-on server is a machine you own, running Claude Code as a continuous process, needed whenever a periodic wake-up is not enough.

---

## 3. /loop, Temporary Recurring Tasks

### What It Does

Runs a task on a timer while your current session is open. When you close the session, the loop stops automatically. Think of it like setting a kitchen timer, it keeps going until you turn it off or leave the kitchen.

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

- **Session-scoped**, stops when you close the session.
- **Auto-expires after 3 days**, even if you leave the session open, the loop will stop after 3 days.
- **Uses your local timezone**, not UTC or any other timezone.
- **Only runs while your computer is on** and the session is active.

### Best Use Cases

- Checking a website every few minutes for changes
- Watching for new messages or replies
- Monitoring something while you work
- Testing an automation before making it permanent with `/schedule`

---

## 4. /schedule, Persistent Recurring Tasks

### What It Does

Creates a task that runs automatically on a schedule in the cloud. It keeps running even when your computer is off, Anthropic's servers handle it for you. Think of it like hiring someone to do a job on a set schedule, whether you are in the office or not.

### How to Create a Scheduled Task

There are two ways to create a scheduled task:

**In Claude Desktop:** Type `/schedule` in the chat and follow the prompts, or use the scheduling feature in the app directly.

**On the web:** Go to https://claude.ai/code/scheduled and create it there.

### Key Details

- **Minimum interval:** once per hour, you cannot schedule anything more frequently than hourly.
- **Each run starts a fresh session** with full access to your files, tools, skills, and connectors.
- **Runs on Anthropic's cloud**, your computer does not need to be on.
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

## 5. Always-On Server, Your Own Machine, Running 24/7

### What It Does

Runs Claude Code as a continuous process on a server you own, your own EC2 instance, a VM, a home Linux box, anything that stays on all the time. Unlike `/schedule` (which wakes up periodically on Anthropic's cloud), this is a **persistent process** that listens continuously and reacts the moment something happens.

Think of it like the difference between a postman who comes once an hour to check your mailbox (`/schedule`) and a receptionist who sits at the front desk all day waiting for someone to walk in (always-on server). For some jobs you only need the postman. For others, like answering a doorbell, you need someone there every second.

### When You Actually Need This

You only need an always-on server when a periodic `/schedule` wake-up is genuinely not enough. The honest answer is: most workshop users will never need this. The use cases that justify it are:

- **24/7 inbound message bots**, Telegram, WhatsApp, Slack, Discord listeners that need to reply within seconds of a user messaging them. `/schedule`'s 1-hour minimum is far too slow.
- **Headless channel daemons**, running a WhatsApp or Slack connector continuously without a logged-in laptop holding the session open.
- **Server-hosted MCP listeners**, MCP servers that need to be reachable from anywhere on the internet (e.g. webhooks from Stripe, Square, GHL).
- **Daemon-mode Claude Code**, long-running agents that watch a queue, a webhook endpoint, or a real-time data feed.

If your task is "do X every morning at 9am" or "run this every Monday", you do **not** need this, use `/schedule`.

### Setup

The setup lives in a separate workshop kit: **[`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)**. It includes provisioning scripts for AWS and Azure, a server auth flow for Google Workspace and Microsoft 365, systemd unit templates, and headless pairing guides for the channels.

Setup is a real engineering task, you provision a server (cost: whatever the cloud bill is), install Claude Code on it, configure systemd to run it as a service, set up the channel pairings, and lock down access. Plan for 30-60 minutes for a first-time setup if you are familiar with cloud servers, and significantly more if you are not.

### How to Decide vs `/schedule`

Use this checklist. If any answer is yes, you probably need an always-on server:

- Does it need to **respond within seconds** rather than within an hour?
- Does it need to **listen continuously** for incoming events (messages, webhooks, real-time data)?
- Is it a **channel daemon** (Telegram bot, WhatsApp listener, etc.) that has to maintain a live connection?
- Does it need to be **reachable from the internet** (incoming webhooks)?

If all answers are no, every job is "wake up at time X, do Y, exit", `/schedule` is enough and you should use it instead.

---

## 6. How to Recommend the Right One

When a user asks about automating something, use this table to recommend the right approach:

| User says... | Recommend |
|---|---|
| "Check this every few minutes" | `/loop` |
| "Do this every morning" | `/schedule` |
| "Keep an eye on this while I work" | `/loop` |
| "Send me a report every Monday" | `/schedule` |
| "Poll this until it is done" | `/loop` |
| "Run this even when my computer is off" | `/schedule` |
| "I want a Telegram bot that replies to messages 24/7" | Always-on server ([`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)) |
| "Keep my WhatsApp / Slack / Discord listener running all the time" | Always-on server ([`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)) |
| "I need a webhook endpoint Claude can answer" | Always-on server ([`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)) |
| "Run this as a background daemon on a Linux box" | Always-on server ([`claude-cloud-kit`](https://github.com/selrai-company/claude-cloud-kit)) |

> **Important:** `/schedule` is for *periodic wake-ups* on Anthropic's cloud (no setup, hourly minimum). The always-on server is for *continuous listeners* on a server you own (real setup, runs 24/7). They are not the same thing, see Section 5 for the decision checklist.

---

## 7. Official Documentation Reference

For the full, up-to-date documentation on both /loop and /schedule, refer to the official Anthropic documentation:

https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks

This documentation applies to all automation tasks including Telegram, iMessage, WhatsApp, Notion, and any other channel, plugin, or connector automation.

---

## 8. Changelog, What We Updated

**Date:** April 02, 2026
**Branch:** cron-tasks

### Added: Automation Section

Added a new "AUTOMATION, /loop and /schedule" section to `my-assistant/CLAUDE.md`, placed between Phase 4 (Skills Discovery) and the "If Something Breaks" section.

This section includes:

- Quick decision rule for choosing between /loop and /schedule
- /loop documentation, syntax, time units, session-scoped behaviour, 3-day auto-expiry, local timezone
- /schedule documentation, cloud-based execution, minimum 1-hour interval, three creation methods (CLI, web, Desktop app)
- Plain-English examples for how to explain each feature to non-technical users
- Recommendation table mapping common user phrases to the correct tool
- "If You Get Stuck" pointer to official Anthropic docs with full URL

### Revised: Plain English Pass

Removed developer-facing jargon to match the non-technical tone of the rest of CLAUDE.md:

| Removed | Replaced With |
|---|---|
| CronCreate, CronList, CronDelete | (removed entirely, internal tools, not user-facing) |
| UTC | "your local timezone" |
| "polling a build or deployment" | "checking a website", "watching for new messages" |
| "remote agent" | "task that runs in the cloud" |
| "Anthropic cloud infrastructure" | "the cloud" / "Anthropic's servers" |
| "MCP servers" | "tools, skills, and connectors" |

### Updated: Official Docs URL

Changed the docs reference from the bare domain (`code.claude.com/docs/en/scheduled-tasks`) to the full clickable URL (`https://docs.anthropic.com/en/docs/claude-code/scheduled-tasks`).

### Updated: Channel References

Changed "Telegram, iMessage, Discord, and any other plugin or channel" to "Telegram, iMessage, WhatsApp, and any other channel, plugin, or connector", matching the actual channels covered in the workshop kit.

---

*Built for the Claude Code Workshop by Selr AI, selrai.com.au*
