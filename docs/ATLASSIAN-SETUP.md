---
title: Atlassian (Jira + Confluence) - Setup Guide
version: 1.0
date: 2026-04-20
---

# Atlassian (Jira + Confluence) - Setup Guide

Connect your Atlassian Cloud workspace - **Jira** (tickets, sprints, boards) and **Confluence** (docs, spaces) - to your assistant. After a one-minute setup you can say things like *"show me my Jira tickets"*, *"create a Confluence page called Release Notes"*, or *"move PROJ-123 to Done"* and your assistant handles it.

> **The easy way:** just say to your assistant *"connect my Atlassian"* - it runs this entire guide for you, conversationally, in about a minute. This page is for reference if anything goes sideways, or if you want to understand what's happening behind the scenes.

---

## Before You Start

- **You need an Atlassian Cloud account.** This guide does **not** work for self-hosted Data Center or Server installations - the official Atlassian MCP server is Cloud-only.
- **If your team has more than one Atlassian workspace** (for example, separate workspaces for different clients or departments), decide which one you want to connect first. You can switch later by saying *"switch my Atlassian workspace"*.
- You do **not** need an Atlassian API token. The setup uses a standard browser sign-in - no tokens to generate, copy, or store.

---

## What Will Happen

1. Your assistant saves a tiny connection setting on your computer
2. You restart Claude Code so the setting becomes active
3. You say *"connect to my atlassian now"* - a browser window opens
4. You sign in to Atlassian and pick which workspace to use
5. Your assistant checks the connection works - you're done

Total time: about one minute.

---

## Step 1 - Ask your assistant to connect

In a Claude Code chat, say:

> **"Connect my Atlassian."**

Your assistant will:
- Tell you what's about to happen
- Save the connection details on your computer silently
- Ask you to restart Claude Code so the new setting becomes active

---

## Step 2 - Restart Claude Code

Close Claude Code completely, then open it again. This is what makes the new connection "live" in your next conversation.

Come back to your chat and confirm you're back.

---

## Step 3 - Sign in to Atlassian

Your assistant will ask you to say:

> **"Connect to my atlassian now."**

A browser window will open. This is Atlassian's own sign-in page - not something your assistant made up.

1. Sign in with your Atlassian email and password (or skip if you're already signed in)
2. On the **Allow** screen, you'll see:
   - A **picker for which Atlassian workspace to connect** - if you have more than one, choose the right one here
   - An **Allow** button
3. Make sure the correct workspace is selected, then click **Allow**
4. Come back to Claude Code and say you're back

**If you only have one Atlassian workspace**, you might not see a picker at all - Atlassian skips that step and just shows Allow. That's fine.

---

## Step 4 - Verify it works

Your assistant will run a quick read-only check to confirm the connection is alive. You'll see a message like:

> "All done! Your Atlassian is now connected - that covers your Jira and Confluence."

From here, just talk to your assistant naturally.

---

## Try it

Good first prompts to test the connection:

- *"Show me my Jira tickets."*
- *"What's assigned to me this sprint?"*
- *"Search Confluence for onboarding."*
- *"What Jira projects do I have?"*

---

## What you can ask your assistant to do

**Jira - tickets**
- List tickets assigned to you, by project, by status, by sprint
- Read a specific ticket by key (e.g. `PROJ-123`) including comments
- Create a new bug, story, or task (your assistant will confirm fields before creating)
- Update a ticket's description, assignee, priority, labels
- Move a ticket through its workflow (To Do → In Progress → Done)
- Comment on a ticket

**Confluence - docs**
- Search pages across any space
- Read a specific page
- Create a new page in a space (with title and content)
- Edit an existing page

**Metadata**
- List Jira projects and Confluence spaces

Your assistant **always confirms** before it creates, updates, moves, or comments - you'll get a summary and a yes/no before anything changes.

---

## Switching workspaces

If you realise you connected to the wrong Atlassian workspace, just say:

> **"Switch my Atlassian workspace."**

Your assistant re-runs the browser sign-in so you can pick a different one on the Allow screen.

---

## If something goes wrong

| What you see | What it means | What to do |
|---|---|---|
| "The sign-in didn't quite stick" | The browser window was closed before you clicked **Allow** | Say *"try again"* - your assistant re-triggers the sign-in |
| "Your Atlassian user doesn't have permission" | Your Atlassian account is connected, but it can't see that project or page | Ask the project/page owner to share access inside Atlassian |
| "Looks like we connected to a different workspace" | You picked the wrong one on the Allow screen, or you have multiple workspaces and the wrong one was auto-selected | Say *"switch my Atlassian workspace"* |
| "Atlassian is asking me to slow down" | You hit the rate limit - common with bulk actions | Wait 30 seconds and try again; for bulk imports, let your assistant batch the work |
| "The Atlassian connection isn't active yet" | The connection was saved but Claude Code hasn't been restarted | Close and reopen Claude Code, then try again |
| "This site can't be reached" in the browser | Network issue, not an Atlassian problem | Check your internet connection, then say *"try again"* |

If none of these match, just tell your assistant what you're seeing in plain English - it's trained to translate Atlassian errors and try the next most-likely fix.

---

## What this connector cannot do

- **Self-hosted Atlassian (Data Center / Server)** - not supported. Only Atlassian Cloud works with this connector.
- **Configure Jira** itself - workflows, custom fields, screens, permission schemes, Forge apps, and automations are not exposed through the MCP server. Use the Atlassian UI for these.
- **Manage Atlassian users, groups, or billing** - admin-only work stays in the Atlassian admin console.
- **Bulk export** tickets or pages to CSV / PDF / Word - use Atlassian's native export.
- **Connect Bitbucket, Trello, or Statuspage** - those are separate Atlassian products with their own integrations.
- **Connect multiple Atlassian workspaces at once** - one workspace per connection. Use *"switch my Atlassian workspace"* to change which one is active.

---

## How it works under the hood (technical)

> You can skip this section if you don't care. It's here for anyone who wants to know what the setup actually does.

- **Transport:** HTTPS streamable remote MCP - the endpoint is `https://mcp.atlassian.com/v1/mcp`
- **Auth:** OAuth 2.1 - handled by Claude Code itself. No API tokens, no manual token management. The OAuth grant includes a site-selection step so the user picks which Atlassian site (workspace) to grant access to.
- **Config location:** `~/.claude.json` on Mac and Linux, `%USERPROFILE%\.claude.json` on Windows. The connector adds an `mcpServers.atlassian` entry with just the URL. Your assistant merges this in without touching other MCP server entries you already have.
- **Deprecated endpoint:** Atlassian's legacy `https://mcp.atlassian.com/v1/sse` endpoint sunsets **30 June 2026**. This connector always uses the current `/v1/mcp` streamable endpoint.
- **Tool discovery:** Atlassian does not publish a fixed tool list. Tool names are discovered at runtime in your first Phase 2 session.
- **Upstream:** [atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server) - the first-party repository under Atlassian's GitHub organisation.

---

## Related

- The skill that drives this setup: [`skills/atlassian-connector/SKILL.md`](../skills/atlassian-connector/SKILL.md)
- General troubleshooting: [`docs/troubleshoot.md`](troubleshoot.md)
- Full skill catalogue: [`docs/skills/README.md`](skills/README.md)

*Built by Selr AI - selrai.com.au*
