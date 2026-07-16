# Advanced - Using VS Code Instead of Claude Desktop

> **This is an advanced fallback.** The recommended path for the workshop is [Claude Desktop](https://claude.ai/download) + the main [full-setup](../start/full-setup.md) guide. Use this page only if you are already comfortable with VS Code and would rather run the assistant through the Claude Code extension.

---

## When to Use This Path

Pick VS Code + the extension only if **all** of these are true:

- You already use VS Code daily for coding or writing
- You are comfortable opening the Extensions panel, signing into accounts from inside the editor, and running commands in the VS Code integrated terminal
- You prefer to keep the assistant inside an IDE alongside other work (multiple projects, git, debugging)

If none of those apply, stop and use Claude Desktop - it is faster to install and less to learn.

---

## Setup Flow (VS Code path)

### Step 1 - Claude Max subscription

Same as the main flow: sign up at [claude.ai](https://claude.ai), upgrade to Claude Max ($100 USD/month).

### Step 2 - Install VS Code

**Mac:**

1. Go to [code.visualstudio.com](https://code.visualstudio.com)
2. Click **"Download for Mac"**
3. Open the downloaded `.zip`
4. Drag **Visual Studio Code** into **Applications**
5. Open it from Applications

**Windows:**

1. Go to [code.visualstudio.com](https://code.visualstudio.com)
2. Click **"Download for Windows"**
3. Run the installer
4. On **"Select Additional Tasks"**: tick **"Add to PATH"**
5. Click **Install**, then **Finish**

### Step 3 - Install the Claude Code extension

1. Open VS Code
2. Click the **Extensions** icon on the left sidebar (four squares) - or press **Cmd+Shift+X** (Mac) / **Ctrl+Shift+X** (Windows)
3. Search: **Claude Code**
4. Find the one by **Anthropic** and click **Install**
5. A Claude icon appears in the sidebar - click it and sign in with your Claude account

### Step 4 - (Windows only) Install Git for Windows

Same as the main flow: [Git for Windows](https://git-scm.com/download/win), default settings, click through to Finish.

If Git is not recognised after install, the Claude Code extension can still fix your PATH conversationally once the bootstrap prompt is running - or you can fix it manually via System Properties → Environment Variables.

### Step 5 - Node.js and Bun

Same as the main flow. Install Node.js from [nodejs.org](https://nodejs.org), then Bun if you want Telegram / WhatsApp / iMessage channels.

### Step 6 - Paste the bootstrap prompt

1. In VS Code, click the **Claude** icon in the sidebar to open the extension
2. Paste the bootstrap prompt from the workshop Notion page (same prompt as the Desktop path - see [bootstrap](../start/bootstrap.md))
3. The assistant handles the clone, skill copy, and workspace creation

### Step 7 - Open your workspace

1. **Mac:** Cmd+Shift+P → "Open Folder" → `~/Desktop/my-assistant`
2. **Windows:** Ctrl+Shift+P → "Open Folder" → `C:\Users\[you]\Desktop\my-assistant`
3. Click the Claude icon in the sidebar again
4. Say **hello** and let the onboarding agent take over

---

## Differences From the Main Desktop Flow

| Topic | Claude Desktop (main) | VS Code + extension (advanced) |
|---|---|---|
| App to install | 1 (Claude Desktop) | 2 (VS Code + Claude Code extension) |
| How to open the workspace | Click folder icon in Code session | Cmd/Ctrl+Shift+P → "Open Folder" |
| How to open the terminal | Built-in bottom panel of a Code session | `Terminal → New Terminal` menu in VS Code |
| Sign-in | Inside Claude Desktop | Inside the VS Code extension |
| Admin-restart fixes (Windows) | Right-click Claude Desktop → Run as Administrator | Right-click VS Code → Run as Administrator |

Everything else is the same: skills live at `~/.claude/skills/`, workspace at `~/Desktop/my-assistant/`, connector guides work identically, MCP installs work identically.

---

## Troubleshooting (VS Code specifics)

**"I can't find Claude Code in VS Code"**
1. Open VS Code
2. Extensions icon (left sidebar, four squares)
3. Search **"Claude Code"**, install the one by Anthropic
4. Restart VS Code once it finishes
5. If it still isn't there, close VS Code completely and reopen

**Skills not showing up**
Close VS Code completely and reopen. Skills load on fresh start.

**Node.js "command not found" after install**
Restart VS Code completely. If still broken, reinstall from [nodejs.org](https://nodejs.org).

**"EPERM" or "permission denied" during `npm install` on Windows**
Close VS Code, right-click it, choose **Run as Administrator**, reopen, retry.

**Everything else** → the main [troubleshoot](../troubleshoot.md) applies - the only difference is "restart Claude Desktop" becomes "restart VS Code" for you.

---

## Why We Recommend Claude Desktop Instead

The April 2026 Claude Desktop overhaul brought the app close to IDE parity - folder-open, built-in terminal, Code sessions - without requiring attendees to learn VS Code's panels, keyboard shortcuts, and extension mechanics. For the non-technical business owner audience this workshop targets, Claude Desktop is simply one less tool to learn. VS Code is still a great editor and the extension still works perfectly - it is just overkill for someone who only needs the assistant.

If you decide later that you want to switch from VS Code to Claude Desktop (or the other way), nothing in your skills, memory, or workshop kit needs to change. Both paths read the same files.

---

*Claude Code Workshop - selrai.com.au*
