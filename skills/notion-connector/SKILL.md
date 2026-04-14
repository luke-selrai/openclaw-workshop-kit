---
name: notion-connector
description: "Connect the user's Notion workspace to Claude Code by walking them through installing the official Notion plugin from Claude Code's plugin marketplace. Use this skill when the user asks to connect Notion, set up Notion, or mentions Notion pages, databases, or meeting notes for the first time and the plugin isn't installed yet. Once the plugin is installed, Claude Code's built-in Notion skills (Notion:search, Notion:create-page, Notion:database-query, and the related task-board skills) take over for everyday use — this skill's job is only the one-time install walkthrough."
allowed-tools: Bash, Read
metadata:
  category: Productivity & Integrations
  tags:
    - notion
    - workspace
    - documentation
    - plugin
    - mcp
  pairs-with:
    - skill: first-run-setup
      reason: Shares the conversational-bootstrap pattern for non-technical users
    - skill: hubspot-connector
      reason: Sibling integration — similar "walk the user through one-time setup in plain English" flow
---

# Notion Connector

## Overview

This skill connects a user's Notion workspace to Claude Code by walking them through installing the **official Claude Code Notion plugin** (authored jointly by Anthropic and Notion) from the plugin marketplace. It has **one phase**: the install walkthrough.

Unlike the other connectors in this kit (Xero, HubSpot, QuickBooks, etc.), this skill does **not** hand-wire an MCP server into `~/.claude.json` or ship a Phase 2 tool reference. Notion's MCP wiring and skill set are handled by the official plugin itself. Once the plugin is installed, Claude Code automatically loads the plugin's curated skills for Notion operations:

| Plugin skill | What it does |
|---|---|
| `Notion:search` | Search the user's Notion workspace |
| `Notion:find` | Quickly find pages or databases by title |
| `Notion:database-query` | Query a Notion database by name or ID |
| `Notion:create-page` | Create a new Notion page |
| `Notion:create-task` | Create a task in the user's Notion tasks database |
| `Notion:create-database-row` | Insert a new row into a database |
| `Notion:tasks:build`, `tasks:plan`, `tasks:setup`, `tasks:explain-diff` | Task-board workflow skills |

Plus 14 underlying MCP tools (`mcp__plugin_Notion_notion__notion-search`, `...notion-create-pages`, `...notion-update-page`, `...notion-fetch`, etc.) that the plugin exposes for direct tool use.

**This skill's job is only the one-time install walkthrough.** After install, the user interacts with the plugin's skills directly — you don't need a Phase 2 in this file.

### Which phase to run

Before running the install walkthrough, check whether the plugin is already installed. Two signals:

1. `Notion:search` (or any other `Notion:*` skill) is available in the current session.
2. `mcp__plugin_Notion_notion__*` tools are available.

If **either** signal is present, treat the plugin as already installed and skip straight to the "already connected" short-circuit below. If **neither** is present, run the install walkthrough.

### Already-connected short-circuit

If the user says *"connect my Notion"* or similar and the plugin is already installed, respond warmly and briefly:

> "Good news — your Notion is already connected through the official Claude Code plugin. You can ask me things like 'search my Notion for meeting notes', 'create a new Notion page called R&D Log', or 'what's in my Tasks database?'. Want me to demo it?"

Don't re-run the install walkthrough. Don't touch `~/.claude.json`. The plugin handles its own lifecycle.

---

## Why we use the plugin, not a custom wrapper

This skill follows the wrap-existing-tooling principle we apply across the kit (QuickBooks via `qbo-cli`, HubSpot via `@hubspot/mcp-server`, Xero via `@xeroapi/xero-mcp-server`, GoHighLevel via HighLevel's hosted MCP), taken one step further: when a **first-party Claude Code plugin** already ships curated skills + MCP wiring for an integration, installing the plugin is strictly better than writing our own wrapper. We get:

- **Notion + Anthropic maintain it**, not us
- Upstream bug fixes and new Notion API coverage for free
- Curated skill prompts tuned by the plugin authors, not improvised
- Zero custom Node code in this repo
- OAuth handled by the plugin — no manual `claude mcp add` commands, no token management, no user-facing config edits

If you find yourself writing a Phase 2 tool reference for Notion inside this skill, stop — something has gone wrong, and you should be recommending the plugin's own skills instead.

---

## Communication rules for the install walkthrough

The user is a non-technical business owner. Every message follows the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say MCP, OAuth, plugin marketplace (say "plugin menu"), token, API, config. If you must name a technical thing, name it plainly: "the plugin menu", "your browser", "the connection".
- **Tell them what is about to happen.** "I'm going to walk you through installing the Notion plugin now — it takes about two minutes."
- **React warmly.** Good: "Your Notion is now connected." Bad: "Plugin installation successful, MCP server registered."
- **Short messages.** Maximum 8 lines per message.
- **Never show raw errors** to the user — translate into plain English and diagnose silently.

---

## PHASE 1 — Install the Notion Plugin

### Step 1 — Orient the user

Tell the user, in one short message:

> "Notion connects to Claude Code through an official plugin that Notion and Anthropic maintain together. I'll walk you through installing it — it takes about two minutes. Ready?"

Wait for the user's "yes" or equivalent before continuing.

### Step 2 — Open the plugin menu

Tell the user:

> "In this chat, type `/plugin` — that's a forward slash followed by the word **plugin** — and press Enter. A menu of available plugins will appear. Let me know when you see the menu."

**Important:** You cannot type `/plugin` for the user yourself — slash commands in Claude Code are triggered from the user's input box, not from assistant messages. The user has to do this part themselves.

Wait for the user to confirm the menu is visible.

**If they report seeing nothing, or say the command wasn't recognised:**
- Their Claude Code version may be older than the plugin system. Tell them in plain English: *"Looks like the plugin menu isn't showing up in your version of Claude Code. Please make sure you've got the latest version installed — you can check by closing Claude Code and re-running the install command from the workshop-kit setup guide."*
- If they report *"the menu is empty"*, tell them: *"The plugin menu should list several available plugins — if yours is empty, please try typing `/plugins` with an 's' instead, or ask me to check your Claude Code version."*

### Step 3 — Select the Notion plugin

Tell the user:

> "In the plugin menu, look for **Notion** in the list and select it. Claude Code will show you a short description and an install button — go ahead and install it. Let me know when it says installed."

Wait for confirmation.

**If they can't find Notion in the list:**
- Ask them to describe what they see — there may be a search box, a filter, or a scroll-down list.
- If the plugin simply isn't listed, tell them: *"It looks like the Notion plugin isn't available in your plugin menu yet. Could you check with Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) whether your Claude Code setup has the plugin marketplace enabled?"*. Do not attempt to hand-wire the MCP server as a fallback — that would undo the whole point of using the plugin.

### Step 4 — Authorise the plugin with Notion

The plugin uses Notion's official hosted MCP server, which requires a one-time browser sign-in to authorise access to the user's workspace.

Tell the user:

> "After the plugin installs, it'll ask for permission to access your Notion workspace — a browser window should open automatically. Sign in with your Notion account, pick which workspace you want me to use (if you have more than one), and click **Allow**. Come back here when you see a 'connected' or 'success' message in the browser."

Wait for confirmation.

**If the browser doesn't open automatically:**
- Tell the user: *"No problem — the plugin will have a sign-in link somewhere in the install flow. Can you see a web address or a 'sign in' button anywhere? Click that and complete the sign-in in your browser."*

**If they say they accidentally clicked Deny or the browser closed before finishing:**
- Tell them: *"No worries — we can try again. Please type `/plugin` again, find Notion, and click the option to re-authorise or re-install it."*

### Step 5 — Verify the plugin is live

After the user confirms the install completed, verify the plugin is actually loaded in the current session. Two checks, in order:

1. **Skill presence:** Check whether `Notion:search` (or any other `Notion:*` skill) is now available. If yes, the plugin is loaded — go to success.
2. **Tool presence (fallback):** If skills aren't showing yet (they may require a reload), check for `mcp__plugin_Notion_notion__*` tools. If yes, the plugin is loaded — go to success.

**If neither signal is present**, the session may need a reload for plugin discovery to kick in. Tell the user:

> "The plugin is installed, but Claude Code needs to refresh to pick it up. Please close this chat and start a new one, then say 'test my Notion' and I'll check the connection."

**If the user comes back and the signals are still absent after a reload:**
- Translate to plain English: *"Something is off with the plugin install — let me think about this."*
- Ask the user to open `/plugin` again and check whether Notion is listed as **installed** or **enabled** (vs just listed as available to install).
- If the plugin appears installed but the skills/tools still aren't available, this is outside our recovery path — suggest contacting Luke at luke@selrai.com.au.

### Step 6 — Success message

When the plugin is confirmed live, say in one short message:

> "All done! Your Notion is connected through the official Claude Code plugin. You can now ask me things like 'search my Notion for meeting notes', 'create a Notion page called R&D Log', 'add today's progress to my R&D page', or 'list the items in my Tasks database'. Give it a try!"

That's it. No Phase 2 in this file — the plugin's own skills take over from here.

---

## Troubleshooting summary

| Problem | What to tell the user |
|---|---|
| `/plugin` command not recognised | Their Claude Code version is older than the plugin system — ask them to update via the workshop-kit setup guide |
| Plugin menu is empty | Try `/plugins` with an 's'; if still empty, check Claude Code version |
| Notion not in the plugin list | Plugin marketplace may not be enabled for their setup — refer to Luke |
| Browser didn't open for Notion sign-in | Look for a sign-in link in the plugin install flow and click it manually |
| Denied access accidentally | Re-run `/plugin` → Notion → re-install or re-authorise |
| Plugin installed but `Notion:*` skills not showing | Close the chat and start a new one so plugin discovery runs |
| `Notion:*` skills returning "not authorised" | Plugin needs re-auth — run `/plugin` → Notion → re-authorise |

---

## Scope Limitations

This skill **can** do:
- Walk a user through installing the official Claude Code Notion plugin conversationally
- Verify the plugin is live after install
- Short-circuit when the plugin is already installed

This skill **cannot** do:
- Install the plugin programmatically — slash commands are triggered by the user, not by Claude
- Operate Notion after install — that's the plugin's own `Notion:*` skills
- Wrap the hosted Notion MCP server directly (and shouldn't — that's what the plugin is for)

If a user asks you to do something with Notion and the plugin isn't installed, run Phase 1 above. If the plugin **is** installed, the request will route to `Notion:search`, `Notion:create-page`, `Notion:database-query`, or one of the other plugin skills automatically based on their descriptions.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; the install walkthrough above follows the same rules
- **hubspot-connector** / **xero-connector** / **quickbooks-connector**: Sibling integrations that ship their own wrappers because no first-party Claude Code plugin exists for them yet. If any of those products ships an official plugin in the future, they should be refactored to use this same plugin-installer pattern.
