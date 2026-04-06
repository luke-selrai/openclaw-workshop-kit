---
name: port-to-server
description: Ports a local Claude Code setup (skills, agents, memories, MCP 
  config, env files, cron tasks) to a remote AWS or GCP server in one guided 
  sweep. Use when user says "move to server", "port my setup", "put Claude on 
  a server", "run Claude 24/7", "set up remote server", or "transfer my agents 
  to cloud". Do NOT use for local-only setup or standard workshop install steps.
metadata:
  author: Khushi Bhanderi (Selr AI)
  version: 1.0.0
  category: server-infrastructure
---

# Port-to-Server Skill

Transfers a complete local Claude Code environment to a remote AWS EC2 or GCP 
VM so the assistant runs 24/7 without requiring the user's computer to stay on.

---

## Instructions

### Step 1: Detect Local Setup

Before transferring anything, map what exists locally.

Run the following inside Claude Code:
```bash
ls ~/.claude/
ls ~/.claude/agents/
ls ~/.claude/skills/
cat ~/.claude/mcp_config.json
```

Expected output: list of skills, agent `.md` files, memories, MCP config, 
and any `.env` files in the project folder.

Check the transfer manifest to confirm what will be ported:
Consult `config/transfer-manifest.json` for the full list.

---

### Step 2: Choose Cloud Provider

Ask the user which provider they are using:

- **AWS EC2** — recommended default
- **GCP Compute Engine** — also supported

If unsure, recommend AWS EC2 (free tier eligible for testing).

---

### Step 3: Run Port Script

Run the transfer script:
```bash
bash scripts/port-to-server.sh
```

The script will:
1. Package all local Claude Code files listed in `transfer-manifest.json`
2. Create a `.tar.gz` bundle in the home folder
3. Prompt the user for their server IP address and SSH username
4. Use `scp` to transfer the bundle to the server

**Note:** This is where the SSH boundary begins. Claude Code can prepare 
and initiate the transfer but the user must have SSH access configured 
on their machine before running this step.

---

### Step 4: Manual SSH Steps (User Action Required)

Instruct the user to SSH into their server and complete setup:
```bash
ssh ubuntu@YOUR_SERVER_IP
cd ~
tar -xzf claude-transfer.tar.gz
npm install -g @anthropic-ai/claude-code
claude
```

Once inside Claude Code on the server, run the setup prompt to restore 
the assistant with all ported skills, agents, and config.

---

### Step 5: Verify Transfer

Run the verification script locally to confirm all files landed correctly:
```bash
bash scripts/verify-transfer.sh
```

Expected output: checklist confirming skills, agents, memories, MCP config, 
and cron tasks are present on the server.

---

### Step 6: Workshop Recommendation

Tell the user:
- Telegram bots and cron tasks will now run 24/7 without needing their 
  laptop open
- They can SSH back in at any time to update skills or agents
- To keep the Claude session alive use `screen` or `tmux` on the server

---

## Examples

### Example 1: Basic Port Request

User says: "I want to run my Claude setup on a server 24/7"

Actions:
1. Run local detection to map all files
2. Confirm transfer manifest with user
3. Run port script — packages and transfers files via scp
4. Guide user through SSH steps to complete install
5. Run verify script to confirm success

Result: Full Claude Code environment running on remote server

---

### Example 2: Partial Port (Agents Only)

User says: "Just move my agents to the server"

Actions:
1. Check `~/.claude/agents/` for agent files
2. Edit transfer manifest to include agents only
3. Run port script with agents-only flag
4. Guide SSH steps for agents folder only

Result: Agent files ported without touching skills or memories

---

## Troubleshooting

### Error: `scp: command not found`

Cause: OpenSSH not installed on Windows
Solution: Install via `winget install Microsoft.OpenSSH.Client` or use WSL

### Error: `Permission denied (publickey)`

Cause: SSH key not configured for the server
Solution: Generate SSH key with `ssh-keygen` and add public key to server's 
`~/.ssh/authorized_keys`

### Error: `claude: command not found` on server

Cause: Node.js not installed on server
Solution: Run `curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E 
bash - && sudo apt-get install -y nodejs` then reinstall Claude Code

### Error: MCP connectors not working after transfer

Cause: API keys in `.env` files not transferred
Solution: Manually re-add API keys on the server or include `.env` in the 
transfer manifest before running the script

---

## Known Limitations

- Claude Code cannot SSH into the server autonomously — this is a manual 
  boundary by design
- Sleep mode or shutdown on the host machine will interrupt the transfer 
  mid-way
- Cloud provider firewall rules must allow SSH (port 22) before transfer
- Memories are project-scoped — they transfer correctly only if the same 
  project folder structure is recreated on the server
