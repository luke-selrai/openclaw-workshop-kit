# Known Issue — Notion: Plugin Marketplace Required

**Status:** Known limitation (by design)
**Affects:** notion-connector
**Symptom:** Notion setup cannot be completed via the terminal — it requires the Claude Code plugin menu

---

## What Is Happening

The Notion connector is installed through the **official Claude Code plugin marketplace**, not via a CLI or npm package. The plugin was built jointly by Anthropic and Notion and is the supported path for connecting Notion to Claude Code.

This means the setup cannot be done from a terminal command. Your assistant will walk you through the plugin menu instead.

---

## How Setup Works

1. Your assistant asks you to open the **plugin menu** in Claude Code (the puzzle-piece icon in the sidebar)
2. You search for "Notion" in the plugin list
3. You click Install — Claude Code handles the authentication with your Notion account
4. Once installed, Notion is available immediately — no restart needed

The whole process takes about two minutes. After that, your assistant can search pages, create new pages, query databases, and read meeting notes directly from your Notion workspace.

---

## What If Notion Doesn't Appear in the Plugin Menu?

If you open the plugin menu and Notion is not listed:

- Your Claude Code setup may not have the plugin marketplace enabled
- This is a configuration issue with your Claude Code installation, not with Notion itself
- Contact Selr AI at [selrai.com.au](https://selrai.com.au) to get the plugin marketplace enabled for your account

**Do not** attempt to connect Notion by manually adding an MCP server entry to `~/.claude.json`. The plugin-based setup is the supported path — bypassing it can cause authentication issues.

---

## What Notion Can and Cannot Do

Once the plugin is installed, your assistant can:
- Search all pages and databases in your workspace
- Read page content and database entries
- Create new pages and database items
- Update existing pages

Your assistant **cannot** (current plugin scope):
- Access pages in workspaces you have not connected
- Manage Notion users, permissions, or workspace settings
- Access pages that are not shared with the connected integration

---

## Related

- Connector docs: `skills/notion-connector/SKILL.md`
- General troubleshooting: `docs/troubleshoot.md`
