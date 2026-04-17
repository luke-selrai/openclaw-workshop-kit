---
title: CircleCI — Setup Guide
version: 1.0
date: 2026-04-15
---

# CircleCI — Setup Guide

This guide connects your CircleCI account to your AI assistant using the **official CircleCI MCP server** built and maintained by CircleCI themselves. Once set up, your assistant can check pipeline status, pull failure logs, find flaky tests, trigger builds, and more — all through plain English.

**Setup takes about two minutes.** You create one connection key in CircleCI, paste it to your assistant, and you're done.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A CircleCI account (any plan — Free, Performance, or Scale)
- Node.js 20 or newer installed (check with `node --version`)
- An internet connection

> **No coding experience required.** Your assistant handles everything technical. You only copy and paste one value from CircleCI.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM | Yes |
| Mac — Intel | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

Once set up, your assistant can:

| Area | What Your Assistant Can Do |
|---|---|
| **Pipeline status** | Check the current state of any pipeline on any branch |
| **Build failures** | Pull detailed failure logs and summarise the root cause |
| **Test results** | Show which tests passed, failed, or were skipped in a job |
| **Flaky tests** | Identify tests that are intermittently failing |
| **Artifacts** | List build outputs (coverage reports, binaries, logs) |
| **Usage & spend** | Pull CircleCI credit usage from the Usage API |
| **Right-sizing** | Find jobs running on oversized resource classes |
| **Pipeline triggers** | Start a new pipeline run on a branch |
| **Reruns** | Rerun a workflow from start or from the failure point |
| **Rollbacks** | Trigger a configured rollback pipeline |
| **Config validation** | Check your `.circleci/config.yml` for errors |
| **Component versions** | Look up available versions of orbs and images |

This is powered by the [official `@circleci/mcp-server-circleci`](https://github.com/CircleCI-Public/mcp-server-circleci) — maintained by CircleCI themselves, published to npm.

---

## Step 1 — Create a Personal API Token in CircleCI (You Do This)

This is the only manual step. Your assistant will walk you through it conversationally — you can **skip reading this section** and just say *"Help me connect my CircleCI"* to your assistant. The steps below are here for reference.

1. Go to [app.circleci.com/settings/user/tokens](https://app.circleci.com/settings/user/tokens) and sign in
2. Click the **Create New Token** button
3. For the name, type: **Claude Assistant** (or any name you like)
4. Click **Add API Token**
5. Copy the token that appears — it's a long string starting with letters and numbers
6. **Save it somewhere safe** — you will paste it to your assistant in Step 2

> **Important:** Treat this token like a password. Do not share it or post it online.
> 
> **The token is only shown once.** If you lose it, you'll need to create a new one (which leaves the old one active — you can revoke it from the same page).
> 
> **The token inherits your account's permissions.** It can see every project you follow in CircleCI.

---

## Step 2 — Tell Your Assistant to Connect

Open Claude Code and say:

> **"Help me connect my CircleCI account"**

Your assistant will:

1. Walk you through Step 1 conversationally, one step at a time — so if you haven't done Step 1 yet, it will guide you through it now
2. Ask you to paste the Personal API Token from Step 1
3. Save the connection details securely on your computer
4. Ask you to restart Claude Code once so the connection becomes active
5. Verify the connection is working and tell you which projects it can see

You will not run any commands yourself. Your assistant handles all the technical work. You just answer its questions in plain English and paste the one value when asked.

When your assistant tells you it's finished, try asking:

- *"What's the status of my latest build?"*
- *"Why did the last build fail?"*
- *"List my CircleCI projects"*
- *"Are any of my tests flaky?"*

If your assistant responds with your CircleCI data, you're all set.

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Check latest build status** | *"What's the status of my latest build on main?"* |
| **Diagnose a failed build** | *"Why did the last build fail?"* |
| **See test results** | *"Which tests failed in my latest build?"* |
| **Find flaky tests** | *"Find flaky tests in my project"* |
| **List projects** | *"What CircleCI projects am I connected to?"* |
| **Trigger a pipeline** | *"Run a build on the feature-payments branch"* |
| **Rerun a workflow** | *"Rerun the last failed workflow"* |
| **List artifacts** | *"Show me the build artifacts for job 12345"* |
| **Check usage** | *"How much CircleCI credit have I used this month?"* |
| **Right-size jobs** | *"Which of my jobs are using oversized resource classes?"* |
| **Validate config** | *"Check my CircleCI config file for errors"* |
| **Roll back a deployment** | *"Roll back the last deployment on main"* |
| **Reconnect** | *"My CircleCI connection has stopped working"* |

---

## Keeping Your Connection Active

Personal API Tokens don't expire automatically — as long as:

1. Your **CircleCI account is active**
2. Your **Personal API Token hasn't been revoked** from the tokens page

…your assistant will keep working silently in the background with no expiry, no refresh cycle, and no re-auth.

**If something does stop working**, just say to your assistant:

> **"My CircleCI connection has stopped working"**

Your assistant will check what's wrong and walk you through the fix. The most common causes:

- The token was revoked from the tokens page
- The project you're asking about isn't followed by your account
- Your CircleCI account permissions changed

---

## Adding More Projects to the Connection

The Personal API Token inherits your CircleCI account's full read access — you don't need to do anything extra to give your assistant access to new projects. Just follow the project in CircleCI the normal way:

1. Go to [app.circleci.com/projects](https://app.circleci.com/projects)
2. Find the project you want to track
3. Click **Follow**

Your assistant will see it on the next tool call — no restart, no reconnect.

---

## Troubleshooting

### Setup Problems

| Problem | Fix |
|---|---|
| *"I can't find the Personal API Tokens page"* | Click your avatar in the bottom-left of CircleCI → **User Settings** → **Personal API Tokens**. Or go straight to [app.circleci.com/settings/user/tokens](https://app.circleci.com/settings/user/tokens). |
| *"I got asked to pick a project"* | That's the project-level tokens page — not what we want. Go directly to [app.circleci.com/settings/user/tokens](https://app.circleci.com/settings/user/tokens) for the personal one. |
| *"The token didn't show up after clicking Add API Token"* | Refresh the page and try again. If still nothing, try a different browser. |
| *"I lost the token"* | Go back to the tokens page, click **Create New Token** to make a new one, and tell your assistant: *"I have a new CircleCI connection key."* The old one stays active until you revoke it — you can delete it from the same page. |
| *"Connection key not working"* (401) | Double-check you copied the full token — no extra spaces, no missing characters. Ask your assistant to save the details again. |

### After Setup

| Problem | Fix |
|---|---|
| Assistant says *"tool not available"* | Close Claude Code completely and reopen it. The connection becomes active on restart. |
| *"I can't see any projects"* | Go to [app.circleci.com/projects](https://app.circleci.com/projects) and follow at least one project. Your token inherits account access. |
| *"Project not found"* when you ask about a specific project | Make sure you're following the project in CircleCI ([app.circleci.com/projects](https://app.circleci.com/projects)). |
| *"CircleCI is asking me to slow down"* (rate limit) | CircleCI enforces rate limits per token. Wait a moment and try again — rare in normal use. |
| Rollback fails with *"no rollback configured"* | Your project doesn't have a rollback pipeline defined. You'd need to add one in CircleCI first before your assistant can trigger it. |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Security Notes

- Your Personal API Token is stored only in your local Claude Code settings file on your computer — never sent to Anthropic, Selr AI, or any third party
- Your assistant uses the **official CircleCI MCP server** published and maintained by CircleCI themselves at [github.com/CircleCI-Public/mcp-server-circleci](https://github.com/CircleCI-Public/mcp-server-circleci)
- Personal API Tokens inherit your CircleCI account's read permissions — the assistant can see everything you can see
- You can revoke the connection at any time from [app.circleci.com/settings/user/tokens](https://app.circleci.com/settings/user/tokens) — revocation is instant
- Never share your Personal API Token with anyone — treat it like a password

---

## Note for CircleCI Server (Self-Hosted)

This connector assumes you're using CircleCI's SaaS service at `https://circleci.com`. If you run **CircleCI Server** (the self-hosted on-prem product), the connection needs a `CIRCLECI_BASE_URL` override that this version doesn't handle — contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) for the self-hosted setup path.

---

## Still Having Trouble?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more fixes, or ask your assistant:
> "Something went wrong with my CircleCI connection. Help me fix it."

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
