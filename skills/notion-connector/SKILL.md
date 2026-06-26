---
name: notion-connector
description: "Connect the user's Notion workspace to Claude Code by installing the official Notion plugin from Claude Code's plugin marketplace. Install is autonomous, Claude runs `claude plugin install notion@claude-plugins-official` directly via Bash; the user's only manual moment is signing in to Notion and clicking Allow in the browser window the plugin opens. Use this skill when the user asks to connect Notion, set up Notion, or mentions Notion pages, databases, or meeting notes for the first time and the plugin isn't installed yet. Once the plugin is installed, Claude Code's built-in Notion skills (Notion:search, Notion:create-page, Notion:database-query, and the related task-board skills) take over for everyday use, this skill's job is only the one-time install walkthrough."
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
    - skill: telegram-connector
      reason: Sibling autonomous-install connector wrapping a first-party plugin (`telegram@claude-plugins-official`), same `claude plugin install` shape
    - skill: hubspot-connector
      reason: Sibling integration, similar "walk the user through one-time setup in plain English" flow (HubSpot ships a wrapper rather than a first-party plugin)
---

# Notion Connector

> **Install pattern:** Plugin-marketplace, see [skills/CLAUDE.md](../CLAUDE.md) for the canonical reference (telegram-connector).

## Overview

This skill connects a user's Notion workspace to Claude Code by installing the **official Claude Code Notion plugin** (authored jointly by Anthropic and Notion) from the plugin marketplace. It has **one phase**: the autonomous install + browser-OAuth walkthrough.

Unlike the other connectors in this kit (Xero, HubSpot, QuickBooks, etc.), this skill does **not** hand-wire an MCP server into `~/.claude.json` or ship a Phase 2 tool reference. Notion's MCP wiring and skill set are handled by the official plugin itself. Once the plugin is installed and authorised, Claude Code automatically loads the plugin's curated skills for Notion operations:

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

**This skill's job is only the one-time install walkthrough.** After install, the user interacts with the plugin's skills directly, you don't need a Phase 2 in this file.

### Which phase to run

Before running the install walkthrough, check whether the plugin is already installed. Three signals, in order:

1. `Notion:search` (or any other `Notion:*` skill) is available in the current session.
2. `mcp__plugin_Notion_notion__*` tools are available.
3. `claude plugin list | grep notion@claude-plugins-official` returns a line with a version string.

If **any** signal is present, treat the plugin as already installed and skip straight to the "already connected" short-circuit below. If **none** is present, run the install walkthrough.

### Already-connected short-circuit

If the user says *"connect my Notion"* or similar and the plugin is already installed, respond warmly and briefly:

> "Good news, your Notion is already connected through the official Claude Code plugin. You can ask me things like 'search my Notion for meeting notes', 'create a new Notion page called R&D Log', or 'what's in my Tasks database?'. Want me to demo it?"

Don't re-run the install walkthrough. Don't touch `~/.claude.json`. The plugin handles its own lifecycle.

---

## Why we use the plugin, not a custom wrapper

This skill follows the wrap-existing-tooling principle we apply across the kit (QuickBooks via `qbo-cli`, HubSpot via `@hubspot/mcp-server`, Xero via `@xeroapi/xero-mcp-server`, GoHighLevel via HighLevel's hosted MCP), taken one step further: when a **first-party Claude Code plugin** already ships curated skills + MCP wiring for an integration, installing the plugin is strictly better than writing our own wrapper. We get:

- **Notion + Anthropic maintain it**, not us
- Upstream bug fixes and new Notion API coverage for free
- Curated skill prompts tuned by the plugin authors, not improvised
- Zero custom Node code in this repo
- OAuth handled by the plugin, no manual `claude mcp add` commands, no token management, no user-facing config edits

If you find yourself writing a Phase 2 tool reference for Notion inside this skill, stop, something has gone wrong, and you should be recommending the plugin's own skills instead.

---

## Communication rules for the install walkthrough

The user is a non-technical business owner. Phase 1 is autonomous, Claude does the work, the user only signs in to Notion in the browser window the plugin opens and clicks Allow. Every message follows the rules in `my-assistant/CLAUDE.md`:

- **You drive, not them.** Never ask the user to type slash commands, click menus, or paste anything. The only thing you ever ask them to do is sign in to Notion in the browser window the plugin opens, and click **Allow** on the consent screen.
- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say MCP, OAuth, plugin marketplace (say "the Notion plugin"), token, API, config, slash command. If you must name a technical thing, name it plainly: "the connection", "your browser", "the sign-in window".
- **Tell them what is about to happen.** "I'm installing the Notion plugin now, takes about a minute."
- **React warmly.** Good: "Your Notion is now connected." Bad: "Plugin installation successful, MCP server registered."
- **Short messages.** Maximum 8 lines per message.
- **Never show raw errors** to the user, translate into plain English and diagnose silently.

---

## PHASE 1, Install the Notion Plugin

### Step 1, Orient the user

Tell the user, in one short message:

> "Notion connects to Claude Code through an official plugin that Notion and Anthropic maintain together. I'll install it for you now, about a minute. The only thing you'll need to do is sign in to Notion in a browser window when it pops up. Ready?"

Wait for the user's "yes" or equivalent before continuing.

### Step 2, Install the Notion plugin (autonomous)

Tell the user: *"Installing the Notion plugin now. About 30 seconds."*

Silently run the install via Bash:

```bash
claude plugin install notion@claude-plugins-official
```

Verify with a separate, stable command (do not parse the install output):

```bash
claude plugin list | grep notion@claude-plugins-official
```

Expect a line showing `notion@claude-plugins-official` with a version. The plugin's own skills (`Notion:search`, `Notion:create-page`, etc.) won't be loaded into the running session until a restart, but that's fine, the only thing that matters here is that the plugin is registered in `~/.claude/plugins/installed_plugins.json` so the OAuth flow in Step 3 can launch.

Branch on the install result:

- **Success** → "That's done." Continue to Step 3.
- **Already installed** (verify command finds the entry on first try) → short-circuit to the "already connected" message and stop.
- **Permissions error** (`EACCES`, `EPERM`) → translate: *"Your computer needs a small permission fix, give me a moment to sort it."* Apply guidance from `skills/first-run-setup/SKILL.md`, then retry once.
- **Network error** → *"Your network is blocking the install. This sometimes happens on company laptops. Could you try again from a home connection or switch off any VPN?"*
- **Plugin not found in marketplace** (`plugin not found`, `unknown plugin` from the install output) → translate: *"It looks like the Notion plugin isn't available in your plugin marketplace yet. Could you check with Luke at luke@selrai.com.au whether your Claude Code setup has the plugin marketplace enabled?"* Do not attempt to hand-wire the MCP server as a fallback, that would undo the whole point of using the plugin.

### Step 3, Authorise the plugin with Notion (browser OAuth, the only user moment)

The plugin uses Notion's official hosted MCP server, which requires a one-time browser sign-in to authorise access to the user's workspace. The plugin's own launcher opens the browser window automatically on first use of any `Notion:*` skill or `mcp__plugin_Notion_notion__*` tool, or it may open immediately as part of the install if the plugin chooses to prompt up-front.

Tell the user, in one short message:

> "A browser window should open for you to sign in to Notion. Sign in with your Notion account, pick which workspace you want me to use (if you have more than one), and click **Allow**. Come back here when you see a 'connected' or 'success' message in the browser."

Wait for confirmation.

**If the browser doesn't open automatically:**

> "No problem, the plugin sometimes waits to authorise until the first time it's used. Let me try again."

Call any safe `Notion:*` skill or `mcp__plugin_Notion_notion__*` tool (e.g. a search with a benign query). The plugin will then prompt for OAuth. If it still doesn't open a browser, translate to plain English and ask the user to describe what they see.

**If the user accidentally clicks Deny or the browser closes before finishing:**

> "No worries, let me retry that for you."

Re-run the install command silently:

```bash
claude plugin install notion@claude-plugins-official
```

The plugin re-launches its OAuth flow. The user signs in again.

### Step 4, Verify the plugin is live

After the user confirms the install completed and they clicked Allow, verify the plugin is actually loaded in the current session. Three checks, in order:

1. **Skill presence.** Check whether `Notion:search` (or any other `Notion:*` skill) is now available. If yes, the plugin is loaded, go to success.
2. **Tool presence (fallback).** If skills aren't showing yet (they may require a session reload), check for `mcp__plugin_Notion_notion__*` tools. If yes, the plugin is loaded, go to success.
3. **Registry presence (silent).** Run `claude plugin list | grep notion@claude-plugins-official` once more. A version line confirms the plugin is registered, even if the running session hasn't picked up its skills/tools yet.

**If only signal 3 is present** (registry yes, skills/tools no), the running session needs a reload for plugin discovery to kick in. Tell the user:

> "The plugin is installed, but Claude Code needs to refresh to pick it up. Please close this chat and start a new one, then say 'test my Notion' and I'll check the connection."

**If the user comes back after a reload and signals 1+2 are still absent:**

- Translate to plain English: *"Something is off with the connection, let me think about this."*
- Re-run `claude plugin list | grep notion@claude-plugins-official` to confirm the plugin row is still present.
- If the plugin row is present but the skills/tools still aren't loading, this is outside our recovery path, suggest contacting Luke at luke@selrai.com.au.

### Step 5, Success message

When the plugin is confirmed live, say in one short message:

> "All done! Your Notion is connected through the official Claude Code plugin. You can now ask me things like 'search my Notion for meeting notes', 'create a Notion page called R&D Log', 'add today's progress to my R&D page', or 'list the items in my Tasks database'. Give it a try!"

That's it. No Phase 2 in this file, the plugin's own skills take over from here.

---

## Troubleshooting summary

| Problem | What to tell the user | What you do |
|---|---|---|
| `claude plugin install` errors with permissions (`EACCES`, `EPERM`) | "Your computer needs a small permission fix, give me a moment to sort it." | Apply guidance from `first-run-setup/SKILL.md`, then retry once |
| `claude plugin install` errors with network failure | "Your network is blocking the install. Could you try again from a home connection or switch off any VPN?" | Wait, then retry once after the user confirms |
| Plugin not found in marketplace | "It looks like the Notion plugin isn't available in your plugin marketplace yet. Please reach out to Luke at luke@selrai.com.au." | Stop, do not hand-wire an MCP fallback |
| Browser didn't open for Notion sign-in | "Let me try again." | Call a benign `Notion:*` skill or `mcp__plugin_Notion_notion__*` tool to re-trigger OAuth |
| User accidentally clicked Deny | "No worries, let me retry that." | Re-run `claude plugin install notion@claude-plugins-official` to relaunch OAuth |
| Plugin installed but `Notion:*` skills not showing in current session | "Close this chat and start a new one, Claude Code will pick up the plugin on the next session." | Wait for the user to reload |
| `Notion:*` skills returning "not authorised" / "expired token" | "Let me reconnect that for you." | Re-run `claude plugin install notion@claude-plugins-official` to re-trigger OAuth |
| `claude plugin list` doesn't show `notion@claude-plugins-official` after install | "The install didn't take, let me try once more." | Retry install once; if still missing, surface in plain English and stop |

---

## Scope Limitations

This skill **can** do:

- Install the official Claude Code Notion plugin autonomously via Bash
- Verify the plugin is registered, loaded, and authorised
- Re-trigger OAuth for re-auth or after a denied prompt, autonomously, without asking the user to type any slash commands
- Short-circuit when the plugin is already installed and authorised

This skill **cannot** do:

- Operate Notion after install, that's the plugin's own `Notion:*` skills
- Wrap the hosted Notion MCP server directly (and shouldn't, that's what the plugin is for)
- Install the plugin without network access to the plugin marketplace

If a user asks you to do something with Notion and the plugin isn't installed, run Phase 1 above. If the plugin **is** installed, the request will route to `Notion:search`, `Notion:create-page`, `Notion:database-query`, or one of the other plugin skills automatically based on their descriptions.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; the install walkthrough above follows the same rules
- **telegram-connector**: Sibling autonomous-install connector wrapping a first-party plugin (`telegram@claude-plugins-official`), same `claude plugin install` shape and the canonical reference for this skill's flow
- **hubspot-connector** / **xero-connector** / **quickbooks-connector**: Sibling integrations that ship their own wrappers because no first-party Claude Code plugin exists for them yet. If any of those products ships an official plugin in the future, they should be refactored to use this same plugin-installer pattern.
