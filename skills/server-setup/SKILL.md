# Server Setup Skill — Zero-to-Production Agent Infrastructure

> **Purpose**: Take a completely blank Mac + AWS account and set up a fully operational Claude Code agent system with autonomous agents, shared scripts, MCP integrations, memory, cron scheduling, and monitoring. The user just watches and clicks "approve" when prompted.
>
> **Audience**: Non-technical business owners at Selr AI workshops. They should never need to type a command, edit a file, or troubleshoot anything.

---

## How This Skill Works

This skill is used by the **server-setup agent** (see `~/.claude/agents/server-setup.md`). The agent walks through each phase sequentially, automating everything via SSH, Playwright browser automation, and local CLI commands. The user only needs to:

1. Provide their AWS credentials (or we create the account via browser)
2. Approve tool executions when prompted
3. Watch it happen

---

## Phase 0: Pre-Flight Checks

Before starting, verify the local Mac environment:

```bash
# Check Claude Code is installed
which claude || echo "NEED: Install Claude Code first"

# Check Homebrew
which brew || echo "NEED: Install Homebrew"

# Check SSH
ls ~/.ssh/id_rsa.pub 2>/dev/null || ls ~/.ssh/id_ed25519.pub 2>/dev/null || echo "NEED: Generate SSH key"

# Check Node.js (needed for MCP servers)
which node || echo "NEED: Install Node.js"

# Check Python 3
which python3 || echo "NEED: Install Python 3"
```

### Install missing dependencies automatically:

```bash
# Homebrew (if missing)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js
brew install node

# Python 3
brew install python3

# AWS CLI
brew install awscli

# Claude Code (if not installed)
npm install -g @anthropic-ai/claude-code

# Tailscale
brew install --cask tailscale

# GitHub CLI
brew install gh

# jq for JSON processing
brew install jq
```

---

## Phase 1: AWS EC2 Server Provisioning

### Option A: CLI provisioning (if AWS CLI configured)

```bash
# Configure AWS CLI
aws configure
# Prompts for: Access Key ID, Secret Access Key, Region (use ap-southeast-2 for AU), Output format (json)

# Create SSH key pair
aws ec2 create-key-pair \
  --key-name claude-agent-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/claude-agent-key.pem
chmod 400 ~/.ssh/claude-agent-key.pem

# Create security group
aws ec2 create-security-group \
  --group-name claude-agents \
  --description "Claude Code agent server"

SG_ID=$(aws ec2 describe-security-groups --group-names claude-agents --query 'SecurityGroups[0].GroupId' --output text)

# Allow SSH
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 22 --cidr 0.0.0.0/0

# Allow webhook port (8080)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0

# Launch EC2 instance (Ubuntu 24.04, t3.medium = 2 vCPU, 4GB RAM, good starting point)
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id ami-0f5d1713c9af4fe30 \
  --instance-type t3.medium \
  --key-name claude-agent-key \
  --security-group-ids $SG_ID \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=claude-agents}]' \
  --query 'Instances[0].InstanceId' --output text)

# Wait for running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get public IP
SERVER_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Server IP: $SERVER_IP"
```

### Option B: Browser automation (if no AWS CLI)

Use Playwright MCP to:
1. Navigate to aws.amazon.com
2. Log in (user provides credentials)
3. Launch EC2 instance through the console
4. Download the key pair
5. Note the public IP

### Option C: User provides existing server

```bash
# User provides: IP address, SSH key path, username
# Verify connectivity
ssh -o ConnectTimeout=10 -i <KEY_PATH> <USER>@<IP> 'echo "Connected successfully"'
```

---

## Phase 2: Server Base Setup

SSH into the server and install everything:

```bash
SSH_CMD="ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP"

# Update system
$SSH_CMD 'sudo apt update && sudo apt upgrade -y'

# Install essentials
$SSH_CMD 'sudo apt install -y \
  curl git jq python3 python3-pip python3-venv \
  build-essential unzip wget tmux htop \
  chromium-browser fonts-liberation \
  libnss3 libatk-bridge2.0-0 libdrm2 libxcomposite1 \
  libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 \
  libcairo2 libasound2t64'

# Install Node.js 20 LTS
$SSH_CMD 'curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs'

# Install Claude Code
$SSH_CMD 'sudo npm install -g @anthropic-ai/claude-code'

# Install Playwright browsers (for headless browser automation)
$SSH_CMD 'npx playwright install chromium --with-deps'

# Install Tailscale
$SSH_CMD 'curl -fsSL https://tailscale.com/install.sh | sh'
$SSH_CMD 'sudo tailscale up'
# This outputs a URL, user clicks it to authenticate in their Tailscale account

# Get Tailscale IP
$SSH_CMD 'tailscale ip -4'
```

---

## Phase 3: Claude Code Authentication on Server

Two options for authenticating Claude Code on the server:

### Option A: OAuth (recommended, auto-refreshes)

```bash
# On server, start Claude Code to trigger OAuth login
$SSH_CMD 'claude auth login'
# This will output a URL. User opens it in browser, authorizes, done.

# Create OAuth refresh script
$SSH_CMD 'cat > ~/refresh-oauth.sh << '\''SCRIPT'\''
#!/bin/bash
# Refresh Claude Code OAuth token
# Run via cron every 6 hours
TOKEN_FILE="$HOME/.claude/oauth_token.json"
if [ -f "$TOKEN_FILE" ]; then
    REFRESH_TOKEN=$(jq -r .refresh_token "$TOKEN_FILE")
    if [ "$REFRESH_TOKEN" != "null" ] && [ -n "$REFRESH_TOKEN" ]; then
        claude auth refresh 2>/dev/null || echo "$(date): OAuth refresh failed" >> ~/oauth-refresh.log
    fi
fi
SCRIPT
chmod +x ~/refresh-oauth.sh'

# Add to cron
$SSH_CMD '(crontab -l 2>/dev/null; echo "0 */6 * * * ~/refresh-oauth.sh >> ~/oauth-refresh.log 2>&1") | crontab -'
```

### Option B: API Key (simpler, costs money)

```bash
# User provides their Anthropic API key
$SSH_CMD "echo 'export ANTHROPIC_API_KEY=sk-ant-...' >> ~/agents-cc/shared/secrets.env"
```

### Option C: Mac pushes OAuth token to server (Luke's approach)

```bash
# On Mac, create push script
cat > ~/push-oauth-token.sh << 'SCRIPT'
#!/bin/bash
# Push local OAuth token to server every 4 hours
TOKEN=$(security find-generic-password -s "claude-oauth" -w 2>/dev/null)
if [ -n "$TOKEN" ]; then
    ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP \
        "echo '$TOKEN' > ~/.claude/oauth_token"
fi
SCRIPT
chmod +x ~/push-oauth-token.sh
```

---

## Phase 4: Agent Framework Deployment

Create the entire agents-cc directory structure on the server:

```bash
# Create directory structure
$SSH_CMD 'mkdir -p ~/agents-cc/{shared/scripts,shared/skills,logs}'

# Create run-agent.sh (the core agent runner)
$SSH_CMD 'cat > ~/agents-cc/run-agent.sh << '\''SCRIPT'\''
#!/bin/bash
# run-agent.sh v6 — Universal agent runner
# Usage: run-agent.sh <agent_name> "<message>" [timeout_seconds]

set -euo pipefail

AGENT="$1"
MESSAGE="${2:-}"
TIMEOUT="${3:-300}"
AGENT_DIR="$HOME/agents-cc/$AGENT"
LOG_FILE="$AGENT_DIR/run.log"
ERROR_LOG="$AGENT_DIR/error.log"
LOCK_FILE="/tmp/claude-agent-$AGENT.lock"

# Ensure agent directory exists
mkdir -p "$AGENT_DIR"

# Source secrets
if [ -f "$HOME/agents-cc/shared/secrets.env" ]; then
    source "$HOME/agents-cc/shared/secrets.env"
fi

# Flock to prevent concurrent runs of same agent
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo "$(date): $AGENT already running, skipping" >> "$ERROR_LOG"
    exit 0
fi

# Log start
echo "$(date): Starting $AGENT run" >> "$LOG_FILE"

# Build preamble from noticeboard
PREAMBLE=""
if [ -f "$HOME/agents-cc/shared/scripts/noticeboard.sh" ]; then
    NOTICES=$("$HOME/agents-cc/shared/scripts/noticeboard.sh" read "$AGENT" 2>/dev/null || true)
    if [ -n "$NOTICES" ]; then
        PREAMBLE="[NOTICEBOARD MESSAGES]\n$NOTICES\n[END NOTICEBOARD]\n\n"
    fi
fi

# Report status to Supabase (if script exists)
if [ -f "$HOME/agents-cc/shared/scripts/report-status.sh" ]; then
    "$HOME/agents-cc/shared/scripts/report-status.sh" "$AGENT" "running" "$MESSAGE" &
fi

# Run Claude Code
FULL_MESSAGE="${PREAMBLE}${MESSAGE}"
timeout "$TIMEOUT" claude -p "$FULL_MESSAGE" \
    --model sonnet \
    --dangerously-skip-permissions \
    --output-format text \
    2>>"$ERROR_LOG" | tee -a "$LOG_FILE"

EXIT_CODE=$?

# Report completion
if [ -f "$HOME/agents-cc/shared/scripts/report-status.sh" ]; then
    if [ $EXIT_CODE -eq 0 ]; then
        "$HOME/agents-cc/shared/scripts/report-status.sh" "$AGENT" "completed" "" &
    else
        "$HOME/agents-cc/shared/scripts/report-status.sh" "$AGENT" "failed" "exit code $EXIT_CODE" &
    fi
fi

echo "$(date): Finished $AGENT run (exit: $EXIT_CODE)" >> "$LOG_FILE"
exit $EXIT_CODE
SCRIPT
chmod +x ~/agents-cc/run-agent.sh'
```

### Create shared scripts

#### supabase.sh (database operations)

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/supabase.sh << '\''SCRIPT'\''
#!/bin/bash
# supabase.sh — Supabase CRUD for agents
# Usage: supabase.sh <command> [args...]
# Commands: save, recall, context-get, context-set, status-update, query

source "$HOME/agents-cc/shared/secrets.env" 2>/dev/null

BASE_URL="${SUPABASE_URL}/rest/v1"
AUTH_HEADER="apikey: ${SUPABASE_ANON_KEY}"
SERVICE_HEADER="Authorization: Bearer ${SUPABASE_SERVICE_KEY}"

case "$1" in
    save)
        # save <agent_id> <category> <content>
        curl -s -X POST "$BASE_URL/agent_memory" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER" \
            -H "Content-Type: application/json" \
            -d "{\"agent_id\":\"$2\",\"category\":\"$3\",\"content\":\"$4\"}"
        ;;
    recall)
        # recall <agent_id> [category] [limit]
        FILTER="agent_id=eq.$2"
        [ -n "${3:-}" ] && FILTER="$FILTER&category=eq.$3"
        LIMIT="${4:-10}"
        curl -s "$BASE_URL/agent_memory?$FILTER&order=created_at.desc&limit=$LIMIT" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER"
        ;;
    context-get)
        # context-get <key>
        curl -s "$BASE_URL/shared_context?key=eq.$2" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER"
        ;;
    context-set)
        # context-set <key> <value> <updated_by>
        curl -s -X POST "$BASE_URL/shared_context" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "{\"key\":\"$2\",\"value\":\"$3\",\"updated_by\":\"${4:-system}\"}"
        ;;
    status-update)
        # status-update <agent_id> <status> [current_task]
        curl -s -X POST "$BASE_URL/agent_status" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "{\"agent_id\":\"$2\",\"agent_name\":\"$2\",\"status\":\"$3\",\"current_task\":\"${4:-}\",\"last_active\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        ;;
    query)
        # query <table> <filter>
        curl -s "$BASE_URL/$2?$3" \
            -H "$AUTH_HEADER" -H "$SERVICE_HEADER"
        ;;
    *)
        echo "Usage: supabase.sh {save|recall|context-get|context-set|status-update|query} [args...]"
        exit 1
        ;;
esac
SCRIPT
chmod +x ~/agents-cc/shared/scripts/supabase.sh'
```

#### noticeboard.sh (inter-agent messaging)

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/noticeboard.sh << '\''SCRIPT'\''
#!/bin/bash
# noticeboard.sh — Inter-agent communication via filesystem
# Usage: noticeboard.sh <command> [args...]

BOARD_DIR="$HOME/agents-cc/shared/noticeboard"
mkdir -p "$BOARD_DIR"

case "$1" in
    send)
        # send <from> <to> <priority> <message>
        TIMESTAMP=$(date +%s)
        FILE="$BOARD_DIR/${3}_${2}_${TIMESTAMP}.msg"
        echo "{\"from\":\"$2\",\"to\":\"$3\",\"priority\":\"${4:-info}\",\"message\":\"$5\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$FILE"
        ;;
    read)
        # read <agent_name>
        for f in "$BOARD_DIR"/*_"$2"_*.msg "$BOARD_DIR"/*_all_*.msg; do
            [ -f "$f" ] && cat "$f" && echo ""
        done
        ;;
    done)
        # done <agent_name> — clear messages for agent
        rm -f "$BOARD_DIR"/*_"$2"_*.msg 2>/dev/null
        ;;
    clean)
        # clean — remove messages older than 24h
        find "$BOARD_DIR" -name "*.msg" -mmin +1440 -delete
        ;;
    *)
        echo "Usage: noticeboard.sh {send|read|done|clean} [args...]"
        ;;
esac
SCRIPT
chmod +x ~/agents-cc/shared/scripts/noticeboard.sh'
```

#### telegram.sh (notifications)

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/telegram.sh << '\''SCRIPT'\''
#!/bin/bash
# telegram.sh — Send messages to user via Telegram bot
# Usage: telegram.sh <message> [chat_id]

source "$HOME/agents-cc/shared/secrets.env" 2>/dev/null

MESSAGE="$1"
CHAT_ID="${2:-$TELEGRAM_CHAT_ID}"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN or CHAT_ID not set"
    exit 1
fi

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"$MESSAGE\",\"parse_mode\":\"Markdown\"}"
SCRIPT
chmod +x ~/agents-cc/shared/scripts/telegram.sh'
```

#### report-status.sh

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/report-status.sh << '\''SCRIPT'\''
#!/bin/bash
# report-status.sh — Report agent run status to Supabase
AGENT="$1"
STATUS="$2"
TASK="${3:-}"

"$HOME/agents-cc/shared/scripts/supabase.sh" status-update "$AGENT" "$STATUS" "$TASK"
SCRIPT
chmod +x ~/agents-cc/shared/scripts/report-status.sh'
```

#### browser.sh (headless browser)

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/scripts/browser.sh << '\''SCRIPT'\''
#!/bin/bash
# browser.sh — Headless browser operations via Playwright
# Usage: browser.sh <command> <url> [args...]

case "$1" in
    screenshot)
        # screenshot <url> [output_path]
        OUTPUT="${3:-/tmp/screenshot-$(date +%s).png}"
        node -e "
        const { chromium } = require('playwright');
        (async () => {
            const browser = await chromium.launch({ headless: true });
            const page = await browser.newPage();
            await page.goto('$2', { waitUntil: 'networkidle', timeout: 30000 });
            await page.screenshot({ path: '$OUTPUT', fullPage: true });
            console.log('Screenshot saved: $OUTPUT');
            await browser.close();
        })().catch(e => { console.error(e); process.exit(1); });
        "
        ;;
    scrape)
        # scrape <url> — returns page text content
        node -e "
        const { chromium } = require('playwright');
        (async () => {
            const browser = await chromium.launch({ headless: true });
            const page = await browser.newPage();
            await page.goto('$2', { waitUntil: 'networkidle', timeout: 30000 });
            const text = await page.evaluate(() => document.body.innerText);
            console.log(text);
            await browser.close();
        })().catch(e => { console.error(e); process.exit(1); });
        "
        ;;
    pdf)
        # pdf <url> [output_path]
        OUTPUT="${3:-/tmp/page-$(date +%s).pdf}"
        node -e "
        const { chromium } = require('playwright');
        (async () => {
            const browser = await chromium.launch({ headless: true });
            const page = await browser.newPage();
            await page.goto('$2', { waitUntil: 'networkidle', timeout: 30000 });
            await page.pdf({ path: '$OUTPUT', format: 'A4' });
            console.log('PDF saved: $OUTPUT');
            await browser.close();
        })().catch(e => { console.error(e); process.exit(1); });
        "
        ;;
    *)
        echo "Usage: browser.sh {screenshot|scrape|pdf} <url> [output_path]"
        ;;
esac
SCRIPT
chmod +x ~/agents-cc/shared/scripts/browser.sh'
```

#### maintenance.sh (daily cleanup)

```bash
$SSH_CMD 'cat > ~/agents-cc/maintenance.sh << '\''SCRIPT'\''
#!/bin/bash
# maintenance.sh — Daily log rotation, cleanup, health check
# Run via cron at 3am daily

LOG_DIR="$HOME/agents-cc"

# Rotate logs (keep last 7 days)
for agent_dir in "$LOG_DIR"/*/; do
    [ -d "$agent_dir" ] || continue
    for log in "$agent_dir"/*.log; do
        [ -f "$log" ] || continue
        # Truncate logs over 10MB
        SIZE=$(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null || echo 0)
        if [ "$SIZE" -gt 10485760 ]; then
            tail -1000 "$log" > "${log}.tmp" && mv "${log}.tmp" "$log"
        fi
    done
done

# Clean old noticeboard messages
"$LOG_DIR/shared/scripts/noticeboard.sh" clean 2>/dev/null

# Clean old temp files
find /tmp -name "screenshot-*" -mtime +3 -delete 2>/dev/null
find /tmp -name "page-*" -mtime +3 -delete 2>/dev/null

# Report disk usage
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_PCT" -gt 85 ]; then
    "$LOG_DIR/shared/scripts/telegram.sh" "⚠️ Server disk at ${DISK_PCT}% — cleanup needed" 2>/dev/null
fi

echo "$(date): Maintenance complete" >> "$LOG_DIR/maintenance.log"
SCRIPT
chmod +x ~/agents-cc/maintenance.sh'
```

### Create AGENT_PROTOCOL.md (injected into every agent run)

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/AGENT_PROTOCOL.md << '\''PROTOCOL'\''
# Agent Protocol — Every Run

You are an autonomous agent running on a headless Linux server via Claude Code CLI.
You have no GUI. You have no human watching. Execute your task and report results.

## Available Tools

All scripts are in ~/agents-cc/shared/scripts/:
- supabase.sh — Save/recall memories, update status, query data
- noticeboard.sh — Send messages to other agents
- telegram.sh — Send notifications to the user
- browser.sh — Headless browser (screenshot, scrape, pdf)
- report-status.sh — Update your run status

## Rules

1. **Check noticeboard first** — read messages addressed to you
2. **Report status** — update Supabase with what you are doing
3. **Save important findings** — use supabase.sh save
4. **Notify on critical items** — use telegram.sh for urgent things
5. **Never loop forever** — if stuck, log the error and exit
6. **No interactive prompts** — everything must be automated
7. **Clean up** — mark noticeboard messages as done when processed

## Error Handling

- HTTP 429 (rate limit): wait 60s, retry once
- HTTP 500: log error, skip task, continue
- HTTP 401: log auth error, notify via telegram
- Timeout: log and exit gracefully
PROTOCOL'
```

### Create SELF_REPAIR_PROTOCOL.md

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/SELF_REPAIR_PROTOCOL.md << '\''REPAIR'\''
# Self-Repair Protocol

When an agent encounters errors, follow this escalation:

## Level 1: Auto-Fix
- Missing directory → create it
- Missing env var → check secrets.env
- Permission denied → check file permissions
- Connection refused → retry with backoff (5s, 15s, 30s)

## Level 2: Workaround
- API down → use cached data if available
- Rate limited → reduce batch size, add delays
- Disk full → clean logs, notify user

## Level 3: Escalate
- Auth expired → notify user via Telegram
- Data corruption → stop, log everything, notify user
- Unknown error → log full stack trace, notify user

## Never Do
- Never delete production data to fix an error
- Never skip authentication checks
- Never ignore repeated failures (3+ = escalate)
REPAIR'
```

---

## Phase 5: Create Agent Templates

Each agent gets its own directory with a CLAUDE.md file. Here is the template:

```bash
create_agent() {
    AGENT_NAME="$1"
    AGENT_ROLE="$2"
    AGENT_DESCRIPTION="$3"

    $SSH_CMD "mkdir -p ~/agents-cc/$AGENT_NAME"
    $SSH_CMD "cat > ~/agents-cc/$AGENT_NAME/CLAUDE.md << AGENTEOF
# $AGENT_NAME — $AGENT_ROLE

## Identity
You are **$AGENT_NAME**, an autonomous AI agent. $AGENT_DESCRIPTION

## Environment
- Server: Ubuntu on AWS EC2
- Runner: ~/agents-cc/run-agent.sh
- Scripts: ~/agents-cc/shared/scripts/
- Protocol: ~/agents-cc/shared/AGENT_PROTOCOL.md

## Your Task
Read the message provided to you and execute it completely.
Use the shared scripts for database, messaging, and browser operations.
Report your results via Supabase and Telegram (for critical items).

## Scripts Available
- \\\`~/agents-cc/shared/scripts/supabase.sh\\\` — Database CRUD
- \\\`~/agents-cc/shared/scripts/noticeboard.sh\\\` — Agent-to-agent messaging
- \\\`~/agents-cc/shared/scripts/telegram.sh\\\` — User notifications
- \\\`~/agents-cc/shared/scripts/browser.sh\\\` — Headless browser
- \\\`~/agents-cc/shared/scripts/report-status.sh\\\` — Status updates
AGENTEOF"
}

# Example agents for a typical business:
create_agent "scout" "Lead Hunter" "You find and qualify business leads using web scraping and API calls."
create_agent "sam" "Sales Outreach" "You handle email outreach, follow-ups, and deal progression."
create_agent "ops" "Operations Manager" "You monitor server health, manage cron jobs, and handle maintenance."
create_agent "content" "Content Creator" "You create social media posts, blog content, and marketing copy."
create_agent "support" "Customer Success" "You handle client communications, scheduling, and follow-ups."
```

---

## Phase 6: Secrets & Environment Variables

Create the secrets file (user provides values interactively):

```bash
$SSH_CMD 'cat > ~/agents-cc/shared/secrets.env << '\''SECRETS'\''
# ============================================
# Agent System Secrets
# DO NOT commit this file to git
# ============================================

# --- Anthropic (if using API key auth) ---
# ANTHROPIC_API_KEY=sk-ant-...

# --- Supabase ---
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_KEY=eyJ...

# --- Telegram Bot ---
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# --- CRM (GoHighLevel) ---
# GHL_API_KEY=
# GHL_LOCATION_ID=

# --- Email ---
# EMAIL_ADDRESS=
# EMAIL_PASSWORD=

# --- Stripe ---
# STRIPE_API_KEY=
# STRIPE_SECRET_KEY=

# --- Other ---
# Add your API keys here as needed
SECRETS
chmod 600 ~/agents-cc/shared/secrets.env'
```

---

## Phase 7: Supabase Database Setup

### Option A: Use Supabase MCP (if connected)

Create the required tables via Supabase MCP or dashboard.

### Option B: SQL migration

```sql
-- Run in Supabase SQL Editor (via browser automation or MCP)

-- Agent memory (long-term storage)
CREATE TABLE IF NOT EXISTS agent_memory (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    agent_id TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT DEFAULT 'general',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_agent_memory_agent ON agent_memory(agent_id);
CREATE INDEX idx_agent_memory_category ON agent_memory(category);

-- Agent status (current state)
CREATE TABLE IF NOT EXISTS agent_status (
    agent_id TEXT PRIMARY KEY,
    agent_name TEXT,
    platform TEXT DEFAULT 'claude-code',
    channel TEXT DEFAULT 'server',
    status TEXT DEFAULT 'idle',
    current_task TEXT,
    last_active TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

-- Agent messages (inter-agent comms, persistent)
CREATE TABLE IF NOT EXISTS agent_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    from_agent TEXT NOT NULL,
    to_agent TEXT NOT NULL,
    message_type TEXT DEFAULT 'task',
    priority TEXT DEFAULT 'normal',
    payload JSONB NOT NULL,
    requires_response BOOLEAN DEFAULT FALSE,
    deadline TIMESTAMPTZ,
    responded_at TIMESTAMPTZ,
    response JSONB,
    status TEXT DEFAULT 'pending'
);

-- Shared context (key-value store for cross-agent data)
CREATE TABLE IF NOT EXISTS shared_context (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_by TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activity log (audit trail)
CREATE TABLE IF NOT EXISTS activity_log (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    agent_id TEXT,
    action TEXT NOT NULL,
    details JSONB DEFAULT '{}'
);

-- Enable RLS
ALTER TABLE agent_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_context ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Service role can do everything (agents use service key)
CREATE POLICY "service_all" ON agent_memory FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "service_all" ON agent_status FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "service_all" ON agent_messages FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "service_all" ON shared_context FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "service_all" ON activity_log FOR ALL USING (true) WITH CHECK (true);
```

---

## Phase 8: Cron Schedule Setup

Create the crontab for automated agent runs:

```bash
$SSH_CMD 'cat > ~/agents-cc/crontab.txt << '\''CRON'\''
# ============================================
# Agent Cron Schedule
# All times UTC — adjust for your timezone
# Install: crontab ~/agents-cc/crontab.txt
# ============================================

# --- Daily Maintenance (3am UTC) ---
0 3 * * * ~/agents-cc/maintenance.sh >> ~/agents-cc/maintenance.log 2>&1

# --- OAuth Refresh (every 6 hours) ---
0 */6 * * * ~/refresh-oauth.sh >> ~/oauth-refresh.log 2>&1

# --- Ops/Health Check (every 6 hours) ---
30 */6 * * * ~/agents-cc/run-agent.sh ops "Run health check: disk, memory, agent logs, cron status" 120 >> ~/agents-cc/ops/run.log 2>&1

# --- Add your agent schedules below ---
# Example: Scout runs lead hunting at 8am UTC Mon-Fri
# 0 8 * * 1-5 ~/agents-cc/run-agent.sh scout "Run daily lead hunt" 300 >> ~/agents-cc/scout/run.log 2>&1

# Example: Content posts review at 10am UTC Mon/Wed
# 0 10 * * 1,3 ~/agents-cc/run-agent.sh content "Review and schedule social posts" 300 >> ~/agents-cc/content/run.log 2>&1
CRON
crontab ~/agents-cc/crontab.txt'
```

---

## Phase 9: Local Mac Configuration

Set up Claude Code on the user's Mac with MCP servers, permissions, and memory:

### Claude Code settings

```bash
# Create settings.json with sensible defaults
mkdir -p ~/.claude
cat > ~/.claude/settings.json << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "NotebookEdit",
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(pwd)",
      "Bash(which *)",
      "Bash(echo *)",
      "Bash(ssh *)",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(python3 *)",
      "Bash(curl *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod *)",
      "Bash(touch *)",
      "Bash(find *)",
      "Bash(grep *)",
      "Bash(jq *)",
      "Bash(gh *)",
      "Bash(scp *)",
      "Bash(rsync *)",
      "Bash(brew *)",
      "Bash(ping *)",
      "Bash(date *)",
      "Bash(ps *)",
      "Bash(kill *)",
      "Bash(open *)",
      "Bash(tmux *)",
      "WebFetch",
      "WebSearch",
      "Agent",
      "mcp__playwright__browser_navigate",
      "mcp__playwright__browser_fill_form",
      "mcp__playwright__browser_click",
      "mcp__playwright__browser_snapshot",
      "mcp__playwright__browser_wait_for",
      "mcp__playwright__browser_take_screenshot",
      "mcp__playwright__browser_tabs",
      "mcp__playwright__browser_type",
      "mcp__playwright__browser_evaluate",
      "mcp__playwright__browser_press_key"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)"
    ]
  }
}
SETTINGS
```

### MCP Server Configuration

```bash
# Playwright MCP (browser automation on Mac)
cat > ~/.mcp.json << 'MCP'
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["@anthropic-ai/mcp-playwright"]
    }
  }
}
MCP
```

### Memory System

```bash
# Create memory directory
mkdir -p ~/.claude/projects/-Users-$(whoami)/memory

# Create MEMORY.md index
cat > ~/.claude/projects/-Users-$(whoami)/memory/MEMORY.md << 'MEMORY'
# Memory Index

## Quick Reference
- **SSH**: `ssh -i ~/.ssh/claude-agent-key.pem ubuntu@<SERVER_IP>`
- **Trigger agent**: `~/agents-cc/run-agent.sh <agent> "<message>" <timeout>`
- **Supabase**: `https://<PROJECT>.supabase.co`

## Memory Files
- **`infrastructure.md`** — Server details, agent roster, scripts, APIs
MEMORY
```

### CLAUDE.md (project instructions)

```bash
# Create project-level CLAUDE.md
cat > ~/.claude/projects/-Users-$(whoami)/CLAUDE.md << 'CLAUDEMD'
# CLAUDE.md — Project Instructions

## Infrastructure
- **Server**: AWS EC2 Ubuntu, accessible via SSH
- **Agents**: Claude Code CLI agents on server, triggered by cron and manual runs
- **Memory**: ~/.claude/projects/ memory system + Supabase shared_context table
- **MCP**: Playwright (browser), add more as needed

## Workflow
1. Read memory files at start of session
2. Use SSH to manage server agents
3. Save important findings to memory
4. Use subagents for parallel work

## Agent Management
```bash
# SSH to server
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@<SERVER_IP>

# Run an agent
~/agents-cc/run-agent.sh <agent_name> "<task message>" <timeout>

# Check logs
cat ~/agents-cc/<agent_name>/run.log

# Update cron
crontab ~/agents-cc/crontab.txt
```
CLAUDEMD
```

---

## Phase 10: Telegram Bot (Optional)

For users who want Telegram control of their agents:

```bash
$SSH_CMD 'cat > ~/agents-cc/telegram-bot/bot.py << '\''BOT'\''
#!/usr/bin/env python3
"""Simple Telegram bot for agent control."""
import os
import subprocess
import sys
import json
from urllib.request import Request, urlopen
from urllib.parse import quote
import time

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
ALLOWED_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "")
AGENTS_DIR = os.path.expanduser("~/agents-cc")

def send_message(chat_id, text):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    data = json.dumps({"chat_id": chat_id, "text": text[:4096], "parse_mode": "Markdown"}).encode()
    req = Request(url, data=data, headers={"Content-Type": "application/json"})
    urlopen(req)

def handle_command(chat_id, text):
    if str(chat_id) != ALLOWED_CHAT_ID:
        send_message(chat_id, "Unauthorized.")
        return

    parts = text.strip().split(maxsplit=1)
    cmd = parts[0].lower().lstrip("/")
    message = parts[1] if len(parts) > 1 else ""

    # Check if it is an agent name
    agent_dir = os.path.join(AGENTS_DIR, cmd)
    if os.path.isdir(agent_dir) and os.path.exists(os.path.join(agent_dir, "CLAUDE.md")):
        if not message:
            send_message(chat_id, f"Usage: /{cmd} <task message>")
            return
        send_message(chat_id, f"Dispatching to {cmd}...")
        try:
            result = subprocess.run(
                [os.path.join(AGENTS_DIR, "run-agent.sh"), cmd, message, "300"],
                capture_output=True, text=True, timeout=310
            )
            output = result.stdout[-3000:] if result.stdout else "No output"
            send_message(chat_id, f"*{cmd} result:*\n{output}")
        except subprocess.TimeoutExpired:
            send_message(chat_id, f"{cmd} timed out after 5 minutes")
        except Exception as e:
            send_message(chat_id, f"Error: {e}")
        return

    if cmd == "status":
        agents = [d for d in os.listdir(AGENTS_DIR)
                  if os.path.isdir(os.path.join(AGENTS_DIR, d))
                  and os.path.exists(os.path.join(AGENTS_DIR, d, "CLAUDE.md"))]
        status_lines = []
        for a in sorted(agents):
            log = os.path.join(AGENTS_DIR, a, "run.log")
            if os.path.exists(log):
                mtime = os.path.getmtime(log)
                ago = int(time.time() - mtime)
                if ago < 3600:
                    status_lines.append(f"  {a}: {ago//60}m ago")
                else:
                    status_lines.append(f"  {a}: {ago//3600}h ago")
            else:
                status_lines.append(f"  {a}: never run")
        send_message(chat_id, "*Agent Status:*\n" + "\n".join(status_lines))
        return

    send_message(chat_id, "Unknown command. Use /<agent_name> <task> or /status")

def poll():
    offset = 0
    while True:
        try:
            url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates?offset={offset}&timeout=30"
            resp = json.loads(urlopen(url).read())
            for update in resp.get("result", []):
                offset = update["update_id"] + 1
                msg = update.get("message", {})
                if "text" in msg:
                    handle_command(msg["chat"]["id"], msg["text"])
        except Exception as e:
            print(f"Poll error: {e}", file=sys.stderr)
            time.sleep(5)

if __name__ == "__main__":
    if not BOT_TOKEN:
        print("Set TELEGRAM_BOT_TOKEN in secrets.env")
        sys.exit(1)
    print("Bot starting...")
    poll()
BOT'

# Create systemd user service
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/telegram-bot.service << 'SERVICE'
[Unit]
Description=Agent Telegram Bot
After=network.target

[Service]
Type=simple
EnvironmentFile=%h/agents-cc/shared/secrets.env
ExecStart=/usr/bin/python3 %h/agents-cc/telegram-bot/bot.py
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
SERVICE

systemctl --user daemon-reload
systemctl --user enable telegram-bot
systemctl --user start telegram-bot'
```

---

## Phase 11: Verification & Smoke Test

Run a complete verification after setup:

```bash
# Test SSH connectivity
ssh -o ConnectTimeout=10 -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP 'echo "SSH OK"'

# Test Claude Code on server
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP 'claude -p "Say hello" --model sonnet --output-format text'

# Test Supabase connectivity
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP '~/agents-cc/shared/scripts/supabase.sh status-update test-agent "testing" "smoke test"'

# Test agent runner
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP '~/agents-cc/run-agent.sh ops "Report: server uptime, disk space, memory usage" 60'

# Test Telegram (if configured)
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP '~/agents-cc/shared/scripts/telegram.sh "Setup complete! Your agent server is live."'

# Verify cron is installed
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP 'crontab -l'

# Check all scripts are executable
ssh -i ~/.ssh/claude-agent-key.pem ubuntu@$SERVER_IP 'ls -la ~/agents-cc/shared/scripts/'
```

---

## Setup Checklist (for the agent to track)

- [ ] Mac dependencies installed (brew, node, python3, claude, tailscale, aws-cli)
- [ ] AWS EC2 instance running
- [ ] SSH key created and tested
- [ ] Tailscale connected (server + Mac)
- [ ] Server base packages installed
- [ ] Claude Code installed on server
- [ ] Claude Code authenticated on server
- [ ] agents-cc directory structure created
- [ ] Shared scripts deployed (supabase, noticeboard, telegram, browser, etc.)
- [ ] AGENT_PROTOCOL.md and SELF_REPAIR_PROTOCOL.md created
- [ ] At least one agent created with CLAUDE.md
- [ ] secrets.env created with user's API keys
- [ ] Supabase tables created
- [ ] Cron schedule installed
- [ ] Mac Claude Code configured (settings.json, .mcp.json, memory)
- [ ] Telegram bot running (optional)
- [ ] Smoke test passed
- [ ] User shown how to trigger agents manually
