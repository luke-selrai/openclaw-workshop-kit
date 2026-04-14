---
name: notion-connector
description: Connects Claude Code to Notion workspace using 
  Notion's official hosted MCP server. Enables searching, 
  reading, creating, updating pages and databases directly 
  from Claude Code. Use when user mentions Notion, workspace, 
  pages, databases, wiki, or knowledge base. Do NOT use for 
  Confluence, Coda, or other wiki/doc platforms.
metadata:
  author: Khushi Bhanderi (Selr AI)
  version: 1.0.0
  category: connectors
---

# Notion Connector

## What This Skill Does
Connects Claude Code to your Notion workspace using 
Notion's official hosted MCP server. Once connected, 
Claude can search pages, read documentation, create 
new pages, manage databases, and add comments — all 
directly from your terminal without copy-pasting.

## When Claude Recommends This Skill
- User mentions Notion, workspace, pages, or databases
- User wants to pull meeting notes or docs into Claude
- User wants to create or update Notion pages from terminal
- User wants to manage a Notion database with Claude

## Prerequisites
- Claude Code installed and running
- A Notion account (free or paid)
- Node.js v18 or higher

## Two Setup Methods

### Method 1 — Hosted MCP Server (Recommended)
Notion's official hosted server. Uses OAuth. 
No API key needed. Easiest setup.

### Method 2 — Open Source npm Package
More control. Requires an internal integration token.
Use this if OAuth is not available in your environment.

---

## Method 1 — Hosted MCP Server Setup

### Step 1 — Add Notion MCP to Claude Code
Run this in your terminal:

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

### Step 2 — Authenticate via OAuth
Inside Claude Code run:
/mcp
Follow the OAuth flow that appears.
Log in with your Notion account when prompted.

### Step 3 — Verify Connection
Inside Claude Code type:
Search my Notion workspace for "workshop"
If results appear — you are connected.

---

## Method 2 — Open Source npm Package Setup

### Step 1 — Create a Notion Integration
1. Go to: https://www.notion.so/profile/integrations
2. Click "New integration"
3. Give it a name (e.g. "Claude Code")
4. Copy the Internal Integration Token (starts with ntn_)

### Step 2 — Add to Claude Desktop Config
Add this to your claude_desktop_config.json:

**Mac:** ~/Library/Application Support/Claude/claude_desktop_config.json  
**Windows:** %APPDATA%\Claude\claude_desktop_config.json

```json
{
  "mcpServers": {
    "notionApi": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "NOTION_TOKEN": "ntn_YOUR_TOKEN_HERE"
      }
    }
  }
}
```

### Step 3 — Share Pages with Your Integration
⚠️ CRITICAL STEP — people miss this most often.

For every Notion page you want Claude to access:
1. Open the page in Notion
2. Click the ••• menu (top right)
3. Click "Add connections"
4. Select your integration name

Without this step you will get "object not found" 
errors even with a valid token.

### Step 4 — Restart Claude Code
Fully quit and relaunch Claude Code so it detects 
the new MCP server.

---

## What Claude Can Do Once Connected

| Action | Example Prompt |
|---|---|
| Search workspace | "Search my Notion for workshop notes" |
| Read a page | "Pull the V3.1 playbook from Notion" |
| Create a page | "Create a new Notion page called R&D Log" |
| Update a page | "Add today's progress to my R&D page" |
| Query a database | "List all items in my Tasks database" |
| Add a comment | "Add a comment to the meeting notes page" |

---

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| "object not found" | Page not shared with integration | Go to page → ••• → Add connections |
| OAuth flow not starting | MCP server not added correctly | Re-run the claude mcp add command |
| Connection timeout | MCP client issue | Use mcp-remote proxy: npx -y mcp-remote https://mcp.notion.com/mcp |
| No workspace access | OAuth interrupted | Disconnect and reconnect via /mcp |
| Token invalid | Wrong token copied | Go back to notion.so/profile/integrations and copy again |

---

## Workshop Placement
Introduce this after connectors setup (GWS, Outlook).  
Best used when participant mentions:
- "I use Notion for my team docs"
- "Can Claude read my project notes?"
- "I want to update Notion from the terminal"

Recommended flow:
1. Participant mentions Notion
2. Claude recommends this skill
3. Run Method 1 (hosted) for most participants
4. Use Method 2 (npm) only if OAuth fails
5. Test with a simple search prompt
6. Demo creating or updating a page live

---

## Important Notes
- Hosted MCP server is actively maintained by Notion
- Open source npm package (@notionhq/notion-mcp-server) 
  is no longer actively maintained — use hosted where possible
- Free Notion accounts fully supported
- Enterprise accounts: admins must approve MCP connections
  in workspace settings before users can connect
- MCP acts with your full Notion permissions — 
  it can access everything you can access
