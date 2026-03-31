---
title: Multi-User Server Deployment Guide
version: 5.0
date: 2026-03-31
---

# Setting Up an AI Assistant Server for Your Team

This guide walks through setting up a single server where every team member gets their own personal AI assistant. Each person chats with their assistant through Telegram — no technical knowledge required to use it.

**Who this guide is for:** The person setting up the server (the admin). You don't need to be a developer, but you'll need to copy-paste some commands into a terminal.

**What your team gets:** Each person messages their own private Telegram bot and gets a dedicated AI assistant that's always on, even when you're not connected.

---

## How It Works

```
Your server (always running)
│
├── Alice  →  @alice_bot on Telegram  →  Her own AI assistant
├── Bob    →  @bob_bot on Telegram    →  His own AI assistant
└── Carol  →  @carol_bot on Telegram  →  Her own AI assistant
```

Each person has their own assistant. They can't see each other's conversations.

---

## What Each Person Gets

| Their own | Shared (saves cost) |
|-----------|---------------------|
| AI assistant | Server (1 VM for everyone) |
| Telegram bot | Python + Whisper (voice transcription) |
| Claude account login | Skills library |
| Private workspace + memory | Workshop kit files |

---

## What You Need Before Starting

- **A server or VM** running Ubuntu 22.04 or newer
  - Minimum for up to 4 people: 2 CPU cores, 4 GB RAM
  - Recommended for 5–10 people: 4 CPU cores, 16 GB RAM
  - **Disk: at least 50 GB** (fills up faster than you'd expect)
  - **Add swap space** — prevents Claude from crashing on small VMs (covered in Step 4)
- **SSH access** to the server with admin (sudo) privileges
- **Each team member needs their own Claude subscription**
  - Pro plan ($20/month) — works for most people
  - Max plan ($100/month) — for heavy daily use

---

## Part 1 — One-Time Server Setup

Do these steps once. You won't need to repeat them when adding new people.

---

### Step 1 — Connect to your server

Open your terminal and connect to your server:

```bash
ssh your-username@your-server-ip
```

On Google Cloud:
```bash
gcloud compute ssh your-vm-name --zone=your-zone
```

> ✅ You should see a command prompt ending in `$`

---

### Step 2 — Install required software

Copy and paste this entire block. It installs Node.js, Python tools, and ffmpeg (needed for voice messages):

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl unzip ffmpeg python3-venv python3-pip

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

curl -fsSL https://bun.sh/install | bash
sudo cp ~/.bun/bin/bun /usr/local/bin/bun
```

> ✅ No red errors? You're good. Warnings in yellow are fine.

---

### Step 3 — Install Claude Code

```bash
sudo npm install -g @anthropic-ai/claude-code
```

Check it worked:

```bash
claude --version
```

> ✅ You should see a version number like `1.x.x`

---

### Step 4 — Add swap space (prevents crashes on small servers)

By default, small servers have no swap space. Without it, Claude gets killed when memory runs low. Run this once:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Check it worked:

```bash
free -h
```

> ✅ You should see `Swap: 2.0Gi` in the output

---

### Step 5 — Download the workshop kit

```bash
sudo git clone https://github.com/luke-selrai/openclaw-workshop-kit.git /opt/workshop-kit
sudo chmod -R 755 /opt/workshop-kit
```

> ✅ You should see `/opt/workshop-kit` with files inside when you run `ls /opt/workshop-kit`

---

### Step 6 — Set up voice transcription (Whisper)

This installs the speech-to-text tool that lets your team send voice messages. It's installed once and shared by everyone.

```bash
sudo python3 -m venv /opt/shared-env

sudo /opt/shared-env/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu

sudo /opt/shared-env/bin/pip install openai-whisper --no-deps
sudo /opt/shared-env/bin/pip install numba numpy tiktoken more-itertools tqdm regex --no-cache-dir

sudo chmod -R 755 /opt/shared-env
```

Pre-download the voice model so the first voice message doesn't have a delay:

```bash
sudo mkdir -p /opt/shared-env/whisper-models
sudo WHISPER_CACHE_DIR=/opt/shared-env/whisper-models \
  /opt/shared-env/bin/python -c "import whisper; whisper.load_model('tiny')"
sudo chmod -R 755 /opt/shared-env/whisper-models
```

> ✅ This step takes a few minutes. Done when you see the prompt again.

---

### Step 7 — Install the Telegram plugin

Log in to Claude Code on the admin account and install the plugin once. New users will get a copy automatically — they don't need to do this themselves.

```bash
claude
```

Inside Claude Code, type:

```
/plugin install telegram@claude-plugins-official
```

Then type `exit` to quit.

> ✅ You should see the plugin listed as installed

---

### Step 8 — Save the setup scripts

These two scripts are how you'll add new team members and link their Telegram accounts.

**Save the onboarding script** as `/opt/workshop-kit/add-team-member.sh`:

```bash
cat > /tmp/add-team-member.sh << 'ENDOFSCRIPT'
#!/bin/bash
# Usage: sudo ./add-team-member.sh <username> <telegram-bot-token>
#
# Sets up everything for a new team member automatically.
# After this script, two steps remain:
#   1. Send the Claude login URL to the user
#   2. Once they message their bot, run: sudo ./pair-user.sh <username> <code>

set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <telegram-bot-token>}"
BOT_TOKEN="${2:?Usage: $0 <username> <telegram-bot-token>}"
HOME_DIR="/home/$USERNAME"

echo "=============================="
echo "  Setting up: $USERNAME"
echo "=============================="

# ── 1. Create Linux user ────────────────────────────────────────────────────
if id "$USERNAME" &>/dev/null; then
    echo "[skip] User $USERNAME already exists."
else
    echo "[1/9] Creating user account..."
    useradd -m -s /bin/bash "$USERNAME"
    passwd -l "$USERNAME"
fi

# ── 2. Workspace ────────────────────────────────────────────────────────────
echo "[2/9] Setting up workspace..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/my-assistant/memory"
cp /opt/workshop-kit/my-assistant/CLAUDE.md "$HOME_DIR/my-assistant/CLAUDE.md"

# ── 3. Skills symlink ───────────────────────────────────────────────────────
echo "[3/9] Linking shared skills..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.claude"
ln -sf /opt/workshop-kit/skills "$HOME_DIR/.claude/skills"

# ── 4. Copy Telegram plugin ─────────────────────────────────────────────────
echo "[4/9] Copying Telegram plugin..."
PLUGIN_SRC=$(find /home -name "installed_plugins.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
if [ -n "$PLUGIN_SRC" ] && [ -d "$PLUGIN_SRC/cache/claude-plugins-official/telegram" ]; then
    PLUGIN_VERSION=$(ls "$PLUGIN_SRC/cache/claude-plugins-official/telegram/" | sort -V | tail -1)
    PLUGIN_CACHE_DST="$HOME_DIR/.claude/plugins/cache/claude-plugins-official/telegram/$PLUGIN_VERSION"
    mkdir -p "$PLUGIN_CACHE_DST"
    cp -r "$PLUGIN_SRC/cache/claude-plugins-official/telegram/$PLUGIN_VERSION/." "$PLUGIN_CACHE_DST/"
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    cat > "$HOME_DIR/.claude/plugins/installed_plugins.json" << PLUGINJSON
{
  "version": 2,
  "plugins": {
    "telegram@claude-plugins-official": [
      {
        "scope": "user",
        "installPath": "$PLUGIN_CACHE_DST",
        "version": "$PLUGIN_VERSION",
        "installedAt": "$NOW",
        "lastUpdated": "$NOW"
      }
    ]
  }
}
PLUGINJSON
    echo "   Plugin copied (v$PLUGIN_VERSION)"
else
    echo "   WARNING: Plugin not found. Complete Step 7 first, then re-run this script."
fi

# ── 5. Claude settings ──────────────────────────────────────────────────────
echo "[5/9] Writing Claude settings..."
cat > "$HOME_DIR/.claude/settings.json" << 'SETTINGSJSON'
{
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  },
  "env": {
    "PATH": "/opt/shared-env/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
  }
}
SETTINGSJSON

# ── 6. Telegram bot token ───────────────────────────────────────────────────
echo "[6/9] Configuring Telegram..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.claude/channels/telegram"
echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN" > "$HOME_DIR/.claude/channels/telegram/.env"
chmod 600 "$HOME_DIR/.claude/channels/telegram/.env"
cat > "$HOME_DIR/.claude/channels/telegram/access.json" << 'ACCESSJSON'
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {},
  "pending": {}
}
ACCESSJSON

# ── 7. PTY wrapper ──────────────────────────────────────────────────────────
echo "[7/9] Creating startup script..."
cat > "$HOME_DIR/start-claude.sh" << 'WRAPPER'
#!/usr/bin/env python3
"""
PTY wrapper — keeps Claude running as a background service.
Allocates a pseudo-terminal (required by Claude Code) and auto-accepts
the workspace trust prompt on first launch.
"""
import os, pty, select, sys, time, fcntl, termios

CLAUDE_CMD = ['/usr/bin/claude', '--dangerously-skip-permissions',
              '--channels', 'plugin:telegram@claude-plugins-official']

def run():
    master_fd, slave_fd = pty.openpty()
    pid = os.fork()
    if pid == 0:
        os.close(master_fd)
        os.setsid()
        fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)
        os.dup2(slave_fd, 0); os.dup2(slave_fd, 1); os.dup2(slave_fd, 2)
        if slave_fd > 2: os.close(slave_fd)
        os.execv(CLAUDE_CMD[0], CLAUDE_CMD)
        sys.exit(1)
    os.close(slave_fd)
    trust_answered = False
    buf = b''
    while True:
        try:
            r, _, _ = select.select([master_fd], [], [], 1.0)
            if r:
                try:
                    data = os.read(master_fd, 4096)
                    if not data: break
                    buf += data
                    if not trust_answered and b'trust' in buf.lower():
                        time.sleep(0.5)
                        os.write(master_fd, b'\r')
                        trust_answered = True
                        buf = b''
                except OSError: break
        except: break
    try: os.waitpid(pid, 0)
    except: pass

if __name__ == '__main__': run()
WRAPPER
chmod +x "$HOME_DIR/start-claude.sh"

# ── 8. Systemd service ──────────────────────────────────────────────────────
echo "[8/9] Creating background service..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.config/systemd/user"
cat > "$HOME_DIR/.config/systemd/user/claude-assistant.service" << SYSTEMD
[Unit]
Description=Claude Assistant for $USERNAME
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $HOME_DIR/start-claude.sh
WorkingDirectory=$HOME_DIR/my-assistant
Restart=always
RestartSec=10
Environment=HOME=$HOME_DIR
Environment=PATH=/opt/shared-env/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin
Environment=WHISPER_CACHE_DIR=/opt/shared-env/whisper-models
StandardOutput=append:$HOME_DIR/claude-assistant.log
StandardError=append:$HOME_DIR/claude-assistant.log

[Install]
WantedBy=default.target
SYSTEMD

# ── 9. Ownership + linger + login + start ───────────────────────────────────
echo "[9/9] Starting assistant..."
chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
loginctl enable-linger "$USERNAME"

echo ""
echo "──────────────────────────────────────────────────────────"
echo "  Claude login URL for $USERNAME (send this to them):"
echo "──────────────────────────────────────────────────────────"
sudo -u "$USERNAME" HOME="$HOME_DIR" claude login 2>&1 || true
echo "──────────────────────────────────────────────────────────"

sudo -u "$USERNAME" XDG_RUNTIME_DIR=/run/user/$(id -u "$USERNAME") \
    systemctl --user enable --now claude-assistant 2>/dev/null && \
    echo "" && echo "✅ Assistant is running for $USERNAME" || \
    echo "⚠️  Could not start service automatically. Try: sudo systemctl --user start claude-assistant"

echo ""
echo "=========================================="
echo "  Done! Next steps for $USERNAME:"
echo "=========================================="
echo ""
echo "  1. Send them the login URL above — they click it once"
echo "  2. Ask them to message their Telegram bot"
echo "  3. They'll get a 6-digit code — send it to you"
echo "  4. Run: sudo /opt/workshop-kit/pair-user.sh $USERNAME <code>"
echo ""
ENDOFSCRIPT

sudo mv /tmp/add-team-member.sh /opt/workshop-kit/add-team-member.sh
sudo chmod +x /opt/workshop-kit/add-team-member.sh
echo "Saved to /opt/workshop-kit/add-team-member.sh"
```

**Save the pairing script** as `/opt/workshop-kit/pair-user.sh`:

```bash
cat > /tmp/pair-user.sh << 'ENDOFSCRIPT'
#!/bin/bash
# Usage: sudo ./pair-user.sh <username> <6-digit-code>
#
# Run this after the user messages their Telegram bot and gives you the code.

set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <telegram-code>}"
CODE="${2:?Usage: $0 <username> <telegram-code>}"
HOME_DIR="/home/$USERNAME"

echo "Linking $USERNAME's Telegram account..."
sudo -u "$USERNAME" HOME="$HOME_DIR" claude \
    --dangerously-skip-permissions \
    --print "/telegram:access pair $CODE" 2>/dev/null

echo "Locking to their account only..."
sudo -u "$USERNAME" HOME="$HOME_DIR" claude \
    --dangerously-skip-permissions \
    --print "/telegram:access policy allowlist" 2>/dev/null

echo ""
echo "✅ Done! $USERNAME can now chat with their assistant on Telegram."
ENDOFSCRIPT

sudo mv /tmp/pair-user.sh /opt/workshop-kit/pair-user.sh
sudo chmod +x /opt/workshop-kit/pair-user.sh
echo "Saved to /opt/workshop-kit/pair-user.sh"
```

> ✅ Server setup is complete. You only need to do this once.

---

## Part 2 — Adding a New Team Member

Repeat these steps for each person you add. The whole process takes about 5 minutes.

---

### Step 1 — They create a Telegram bot

The team member does this themselves (takes 2 minutes):

1. Open Telegram on their phone
2. Search for **@BotFather** and tap **Start**
3. Send `/newbot`
4. Choose a display name (e.g. "Sarah's Assistant")
5. Choose a username ending in `bot` (e.g. `sarah_selrai_bot`)
6. Copy the token — it looks like `123456789:AAHfiqksKZ8...`
7. Send you (the admin) that token

---

### Step 2 — Run the setup (admin)

On the server, run one command:

```bash
sudo /opt/workshop-kit/add-team-member.sh sarah "123456789:AAHfiqksKZ8..."
```

Replace `sarah` with their first name (lowercase, no spaces) and paste their bot token in quotes.

The script will print a login URL at the end — **copy it**.

> ✅ You should see `✅ Assistant is running for sarah`

---

### Step 3 — They log in to Claude (team member)

Send them the URL the script printed. They:

1. Click the link (on phone or computer)
2. Log in with their own Claude account
3. That's it — nothing else on their side for now

---

### Step 4 — Link their Telegram account

1. Ask them to open Telegram and message their bot (e.g. `@sarah_selrai_bot`) — send anything
2. The bot replies with a **6-digit code** — they send you that code
3. You run:

```bash
sudo /opt/workshop-kit/pair-user.sh sarah 123456
```

> ✅ Their assistant is now live. They can start chatting immediately.

---

## Part 3 — Managing Your Team

### Check if everyone's assistant is running

```bash
for user in $(ls /home/); do
    status=$(sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user is-active claude-assistant 2>/dev/null || echo "not set up")
    echo "$user: $status"
done
```

### Restart someone's assistant

```bash
sudo -u sarah XDG_RUNTIME_DIR=/run/user/$(id -u sarah) systemctl --user restart claude-assistant
```

### See what's happening in someone's assistant (logs)

```bash
sudo tail -f /home/sarah/claude-assistant.log
```

### Remove someone from the server

```bash
# Stop their assistant
sudo -u sarah XDG_RUNTIME_DIR=/run/user/$(id -u sarah) systemctl --user stop claude-assistant

# Remove their account (keeps files as backup)
sudo userdel sarah

# Remove completely including all their data
sudo userdel -r sarah
```

### Update Claude Code (when a new version is released)

```bash
sudo npm update -g @anthropic-ai/claude-code

# Restart everyone's assistant after updating
for user in $(ls /home/); do
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user restart claude-assistant 2>/dev/null || true
done
```

### Update the skills library

```bash
cd /opt/workshop-kit && sudo git pull
```

Everyone gets the updated skills automatically — no restarts needed.

---

## Part 4 — Google Workspace (Optional)

If a team member wants their assistant to read Gmail, Calendar, and Drive, run this while logged in as that user:

```bash
sudo su - sarah
claude mcp add google-workspace --scope user \
  -e GOOGLE_CLIENT_ID=<their-client-id> \
  -e GOOGLE_CLIENT_SECRET=<their-client-secret> \
  -- npx @dguido/google-workspace-mcp
exit
```

Each person connects their own Google account separately.

---

## Cost Estimate

| Setup | Monthly cost |
|---|---|
| Server (4 CPU, 16 GB RAM, 50 GB disk) | ~$20–50 |
| Claude Pro per person | $20/person |
| Claude Max per person (heavy users) | $100/person |
| Telegram bots | Free |
| **5-person team on Pro** | ~$120–150/month |
| **10-person team on Pro** | ~$220–250/month |

> Start everyone on Pro. Upgrade to Max only if someone hits usage limits regularly.

---

## Troubleshooting

**Assistant not responding on Telegram**
```bash
# Check if it's running
sudo -u sarah XDG_RUNTIME_DIR=/run/user/$(id -u sarah) systemctl --user status claude-assistant

# If not running, restart it
sudo -u sarah XDG_RUNTIME_DIR=/run/user/$(id -u sarah) systemctl --user restart claude-assistant
```

**Voice messages not working**
```bash
# Check Whisper is installed
/opt/shared-env/bin/python -c "import whisper; print('OK')"

# Check ffmpeg is installed
which ffmpeg
```

If Whisper is missing, re-run Step 6. If ffmpeg is missing: `sudo apt install -y ffmpeg`

**Can't SSH into the server**
```bash
# Check disk isn't full (a full disk breaks SSH)
df -h /
```
If disk is over 90% full, you need to expand it — see your cloud provider's docs for resizing a disk, then run:
```bash
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
```

**Claude keeps crashing**
```bash
# Check available memory
free -h

# Check swap exists
swapon --show
```
If no swap is listed, re-run Step 4.

**"Plugin not found" when adding a user**
You need to complete Step 7 (install the Telegram plugin on the admin account) before adding users.

**Telegram bot not responding after server restart**
Linger should handle this automatically. If it doesn't:
```bash
sudo loginctl enable-linger sarah
sudo -u sarah XDG_RUNTIME_DIR=/run/user/$(id -u sarah) systemctl --user start claude-assistant
```

---

## Quick Reference

```bash
# Add a new person
sudo /opt/workshop-kit/add-team-member.sh <name> "<bot-token>"

# Finish linking their Telegram (after they send you the 6-digit code)
sudo /opt/workshop-kit/pair-user.sh <name> <code>

# Check everyone's status
for user in $(ls /home/); do echo -n "$user: "; sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") systemctl --user is-active claude-assistant 2>/dev/null || echo "inactive"; done

# See logs for a user
sudo tail -f /home/<name>/claude-assistant.log

# Restart a user's assistant
sudo -u <name> XDG_RUNTIME_DIR=/run/user/$(id -u <name>) systemctl --user restart claude-assistant
```

---

_Built by Selr AI — [selrai.com.au](https://selrai.com.au)_
