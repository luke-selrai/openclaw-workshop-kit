---
title: Multi-User Server Deployment Guide
version: 5.0
date: 2026-03-31
---

# Multi-User Server Deployment — One VM, Many Assistants

This guide walks through setting up a single server where every team member gets their own Claude Code instance with their own Telegram bot. Each person messages their own bot from their phone and gets a dedicated AI assistant.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                   Server (1 VM)                  │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │  alice     │  │  bob      │  │  charlie   │   │
│  │           │  │           │  │           │   │
│  │ Claude    │  │ Claude    │  │ Claude    │   │
│  │ Code      │  │ Code      │  │ Code      │   │
│  │    ↕      │  │    ↕      │  │    ↕      │   │
│  │ Telegram  │  │ Telegram  │  │ Telegram  │   │
│  │ @alice_bot│  │ @bob_bot  │  │ @charl_bot│   │
│  └───────────┘  └───────────┘  └───────────┘   │
│                                                  │
│  Each user = Linux account + Claude login        │
│            + Telegram bot + systemd service       │
└─────────────────────────────────────────────────┘
```

Each team member gets:

| Component               | Isolated per user       | Shared                                      |
|-------------------------|-------------------------|---------------------------------------------|
| Linux user account      | Yes                     | —                                           |
| Claude Max subscription | Yes (required)          | —                                           |
| Telegram bot            | Yes (own token)         | —                                           |
| Workspace + memory      | Yes (`~/my-assistant/`) | —                                           |
| Skills                  | —                       | Symlinked from `/opt/workshop-kit/skills/`  |
| Workshop kit source     | —                       | Stored once at `/opt/workshop-kit/`         |
| Python + Whisper        | —                       | Installed once at `/opt/shared-env/`        |
| Whisper model           | —                       | Cached at `/opt/shared-env/whisper-models/` |

---

## Server Directory Structure

```
/
├── usr/bin/claude                         → symlink to Claude Code (npm global)
│
├── opt/
│   ├── workshop-kit/                      ← shared read-only source (git repo)
│   │   ├── add-team-member.sh             ← onboarding script (admin only)
│   │   ├── pair-user.sh                   ← telegram pairing script (admin only)
│   │   ├── my-assistant/
│   │   │   └── CLAUDE.md                  ← template copied to each new user
│   │   ├── skills/                        ← 86+ skills (symlinked into ~/.claude/skills)
│   │   └── docs/
│   │       └── MULTI-USER-DEPLOYMENT.md   ← this file
│   │
│   └── shared-env/                        ← shared Python venv (all users)
│       ├── bin/python3                    → /usr/bin/python3
│       ├── bin/whisper
│       └── whisper-models/
│           └── tiny.pt                    ← pre-downloaded, 72 MB, world-readable
│
└── home/
    ├── <admin>/                           ← admin user
    │   ├── start-claude.sh               ← PTY wrapper daemon
    │   ├── claude-assistant.log          ← service stdout/stderr log
    │   ├── my-assistant/
    │   │   └── CLAUDE.md                 ← admin's assistant instructions
    │   └── .claude/
    │       ├── settings.json
    │       ├── .credentials.json         ← claude login token
    │       ├── channels/telegram/
    │       │   ├── .env                  ← TELEGRAM_BOT_TOKEN
    │       │   └── access.json
    │       ├── plugins/                  ← Telegram plugin (install here first)
    │       └── skills/                   → symlink → /opt/workshop-kit/skills/
    │
    └── <username>/                       ← each team member (same structure)
        ├── start-claude.sh               ← PTY wrapper (copied by onboarding script)
        ├── claude-assistant.log          ← service log
        ├── my-assistant/
        │   ├── CLAUDE.md                 ← copied from template
        │   └── memory/                   ← persistent user memory notes
        └── .claude/
            ├── settings.json             ← bypass perms + telegram plugin enabled
            ├── .credentials.json         ← their own claude login token
            ├── channels/telegram/
            │   ├── .env                  ← their bot token
            │   ├── access.json           ← who can DM their bot
            │   └── approved/             ← paired users (written at pairing time)
            ├── plugins/cache/            ← Telegram plugin (copied from admin)
            └── skills/                   → symlink → /opt/workshop-kit/skills/
```

---

## What You Need

- **A Linux server or VM** — Ubuntu 22.04+ or Debian 12+ recommended
  - Minimum: 2 CPU, 8 GB RAM (for up to 4 users)
  - Recommended: 4 CPU, 16 GB RAM (for 5–10 users)
  - **Disk: minimum 50 GB** — shared Python environment ~1.5 GB, Whisper model ~72 MB, Claude logs + npm + node_modules fill up fast on smaller disks
  - Budget ~1–2 GB RAM per active Claude Code instance
- **SSH access** with sudo privileges
- **A Claude subscription per team member** — Pro ($20/month) or Max ($100/month)
- **One Telegram bot per team member** (free, created via @BotFather)

---

## Part A — Server Setup (Admin, One Time)

### Step 1 — Install System Dependencies

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl unzip ffmpeg python3-venv python3-pip

# Node.js LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Bun (required for Telegram plugin)
curl -fsSL https://bun.sh/install | bash
sudo cp ~/.bun/bin/bun /usr/local/bin/bun
```

> **ffmpeg** converts Telegram `.oga` voice files to `.wav` for Whisper transcription.

### Step 2 — Install Claude Code

```bash
sudo npm install -g @anthropic-ai/claude-code
claude --version
```

### Step 3 — Download the Workshop Kit

```bash
sudo git clone https://github.com/luke-selrai/openclaw-workshop-kit.git /opt/workshop-kit
sudo chmod -R 755 /opt/workshop-kit
```

### Step 4 — Add Swap (Prevents OOM Kills)

Claude Code instances each use ~1–2 GB RAM. Without swap, the kernel kills them under load. Add 2 GB swap before adding users:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Verify: `free -h` should show `Swap: 2.0Gi`.

### Step 5 — Set Up Shared Python Environment

Install Python tools once, shared by all users.

```bash
# Create shared venv
sudo python3 -m venv /opt/shared-env

# CPU-only PyTorch first (avoids ~4 GB CUDA packages)
sudo /opt/shared-env/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu

# Whisper + dependencies
sudo /opt/shared-env/bin/pip install openai-whisper --no-deps
sudo /opt/shared-env/bin/pip install numba numpy tiktoken more-itertools tqdm regex --no-cache-dir

# Pre-download the Whisper tiny model (72 MB)
sudo mkdir -p /opt/shared-env/whisper-models
sudo /opt/shared-env/bin/python3 -c "
import whisper
whisper.load_model('tiny', download_root='/opt/shared-env/whisper-models')
"

# Make everything accessible to all users
sudo chmod -R 755 /opt/shared-env
sudo chmod 644 /opt/shared-env/whisper-models/tiny.pt
```

> **Important:** `chmod 644 tiny.pt` is required. Without it, non-root users get a `PermissionError` when Whisper opens the model file.

### Step 6 — Install the Telegram Plugin (Admin Account)

Log into Claude Code once on the admin account and install the plugin. The onboarding script copies it to each new user automatically.

```bash
claude
# Inside Claude Code:
/plugin install telegram@claude-plugins-official
# Then exit
```

### Step 7 — Create the Onboarding Script

Save as `/opt/workshop-kit/add-team-member.sh`:

```bash
#!/bin/bash
# Usage: sudo ./add-team-member.sh <username> <telegram-bot-token>
set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <telegram-bot-token>}"
BOT_TOKEN="${2:?Usage: $0 <username> <telegram-bot-token>}"
HOME_DIR="/home/$USERNAME"

# ── 1. Create Linux user ────────────────────────────────────────────────────
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists. Skipping user creation."
else
    useradd -m -s /bin/bash "$USERNAME"
    passwd -l "$USERNAME"
fi

# ── 2. Workspace ────────────────────────────────────────────────────────────
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/my-assistant/memory"
cp /opt/workshop-kit/my-assistant/CLAUDE.md "$HOME_DIR/my-assistant/CLAUDE.md"
# Optional memory seed files — only copied if they exist in the template
cp /opt/workshop-kit/my-assistant/memory/USER.md "$HOME_DIR/my-assistant/memory/USER.md" 2>/dev/null || true
cp /opt/workshop-kit/my-assistant/memory/SETUP.md "$HOME_DIR/my-assistant/memory/SETUP.md" 2>/dev/null || true
cp /opt/workshop-kit/my-assistant/memory/MEMORY.md "$HOME_DIR/my-assistant/memory/MEMORY.md" 2>/dev/null || true

# ── 3. Skills symlink ───────────────────────────────────────────────────────
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.claude"
ln -sf /opt/workshop-kit/skills "$HOME_DIR/.claude/skills"

# ── 4. Copy Telegram plugin ─────────────────────────────────────────────────
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
else
    echo "WARNING: Could not find installed plugin. Run Step 5 first, then re-run this script."
fi

# ── 5. settings.json ────────────────────────────────────────────────────────
# NOTE: skipDangerousModePermissionPrompt is required.
# Without it the PTY wrapper presses Enter on the "No, exit" default and Claude exits immediately.
cat > "$HOME_DIR/.claude/settings.json" << 'SETTINGSJSON'
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "skipDangerousModePermissionPrompt": true,
  "enabledPlugins": {
    "telegram@claude-plugins-official": true
  },
  "env": {
    "PATH": "/opt/shared-env/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
  }
}
SETTINGSJSON

# ── 6. Telegram bot token ───────────────────────────────────────────────────
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
cat > "$HOME_DIR/start-claude.sh" << 'WRAPPER'
#!/usr/bin/env python3
"""
PTY wrapper — Claude Code requires a pseudo-terminal to run as a daemon.
Auto-accepts the workspace trust dialog (Yes is pre-selected by default).
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
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.config/systemd/user"
cat > "$HOME_DIR/.config/systemd/user/claude-assistant.service" << SYSTEMD
[Unit]
Description=Claude Code Assistant for $USERNAME
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

# ── 9. Fix ownership + enable linger ───────────────────────────────────────
chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
loginctl enable-linger "$USERNAME"

# ── 10. Start the service ───────────────────────────────────────────────────
sudo -u "$USERNAME" XDG_RUNTIME_DIR=/run/user/$(id -u "$USERNAME") \
    systemctl --user enable --now claude-assistant 2>/dev/null && \
    echo "Service started." || echo "WARNING: Could not start service."

echo ""
echo "=========================================="
echo "  Setup complete for: $USERNAME"
echo "=========================================="
echo ""
echo "Remaining steps:"
echo "  1. Run: sudo su - $USERNAME"
echo "     Then: export XDG_RUNTIME_DIR=/run/user/\$(id -u)"
echo "     Then: claude login"
echo "     Copy the URL and send it to $USERNAME"
echo "     After they log in, restart the service:"
echo "     systemctl --user restart claude-assistant"
echo "     Then: exit"
echo ""
echo "  2. Ask $USERNAME to message their Telegram bot"
echo "     They'll receive a 6-digit pairing code"
echo ""
echo "  3. Run: sudo /opt/workshop-kit/pair-user.sh $USERNAME <code>"
echo ""
```

Make it executable:

```bash
sudo chmod +x /opt/workshop-kit/add-team-member.sh
```

### Step 8 — Create the Pairing Script

Save as `/opt/workshop-kit/pair-user.sh`:

```bash
#!/bin/bash
# Usage: sudo ./pair-user.sh <username> <6-digit-telegram-code>
set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <telegram-code>}"
CODE="${2:?Usage: $0 <username> <telegram-code>}"
HOME_DIR="/home/$USERNAME"
ACCESS_FILE="$HOME_DIR/.claude/channels/telegram/access.json"

SENDER_ID=$(python3 -c "
import json, sys
d = json.load(open('$ACCESS_FILE'))
entry = d.get('pending', {}).get('$CODE')
if not entry:
    print('ERROR: code not found or expired', file=sys.stderr)
    sys.exit(1)
print(entry['senderId'])
")

CHAT_ID=$(python3 -c "
import json
d = json.load(open('$ACCESS_FILE'))
print(d['pending']['$CODE']['chatId'])
")

python3 -c "
import json
d = json.load(open('$ACCESS_FILE'))
d.setdefault('allowFrom', [])
if '$SENDER_ID' not in d['allowFrom']:
    d['allowFrom'].append('$SENDER_ID')
del d['pending']['$CODE']
d['dmPolicy'] = 'allowlist'
json.dump(d, open('$ACCESS_FILE', 'w'), indent=2)
print('access.json updated')
"

mkdir -p "$HOME_DIR/.claude/channels/telegram/approved"
echo "$CHAT_ID" > "$HOME_DIR/.claude/channels/telegram/approved/$SENDER_ID"
chown -R "$USERNAME:$USERNAME" "$HOME_DIR/.claude/channels/telegram"

echo "Done! $USERNAME ($SENDER_ID) is now paired and on the allowlist."
```

```bash
sudo chmod +x /opt/workshop-kit/pair-user.sh
```

---

## Part B — Add a Team Member

The entire setup is admin-only. New users never need to SSH.

### Step 1 — Team Member Creates a Telegram Bot

1. Open Telegram → search **@BotFather** → tap **Start**
2. Send `/newbot`
3. Choose a name (e.g. "Alice's Assistant")
4. Choose a username ending in `bot` (e.g. `alice_selrai_bot`)
5. Copy the token and send it to the admin

### Step 2 — Admin Runs the Onboarding Script

```bash
sudo /opt/workshop-kit/add-team-member.sh alice "123456789:AAHfiqksKZ8..."
```

This creates the Linux user, workspace, Telegram config, plugin, PTY wrapper, and systemd service.

### Step 3 — Claude Login (Interactive — Required)

`claude login` requires an interactive terminal. After the script finishes:

```bash
sudo su - alice
export XDG_RUNTIME_DIR=/run/user/$(id -u)
claude login
```

A URL appears. Copy it and send to the team member. They click it, log in with their Claude account, and paste the code back. Then restart the service:

```bash
systemctl --user restart claude-assistant
exit
```

### Step 4 — Pair on Telegram

1. Team member opens their bot on Telegram and sends any message
2. Bot replies with a 6-digit code — they send it to the admin
3. Admin runs:

```bash
sudo /opt/workshop-kit/pair-user.sh alice <code>
```

The assistant is now live.

---

## Part C — Managing the Server

### Check Status of All Assistants

```bash
for user in $(ls /home/); do
    echo -n "$user: "
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user is-active claude-assistant 2>/dev/null || echo "not set up"
done
```

### Restart a User's Assistant

```bash
sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user restart claude-assistant
```

### View Logs for a User

```bash
# Live journal logs
sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) journalctl --user -u claude-assistant -f

# Or the log file directly
sudo tail -f /home/alice/claude-assistant.log
```

### Switch to a User's Shell

```bash
sudo su - alice
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```

### Update Skills for Everyone

Skills are symlinked — updating the shared copy updates everyone instantly:

```bash
cd /opt/workshop-kit && sudo git pull
```

### Push Updated CLAUDE.md to All Users

The template is copied (not symlinked) at setup time. To update existing users:

```bash
for user in $(ls /home/); do
    [ -f "/home/$user/my-assistant/CLAUDE.md" ] && \
        sudo cp /opt/workshop-kit/my-assistant/CLAUDE.md /home/$user/my-assistant/CLAUDE.md && \
        echo "Updated $user"
done
for user in $(ls /home/); do
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user restart claude-assistant 2>/dev/null || true
done
```

### Update Shared Python Packages

```bash
sudo /opt/shared-env/bin/pip install --upgrade openai-whisper
sudo chmod -R 755 /opt/shared-env
sudo chmod 644 /opt/shared-env/whisper-models/*.pt
```

### Remove a Team Member

```bash
sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user stop claude-assistant
sudo userdel -r alice   # removes home dir; omit -r to keep as backup
```

---

## Part D — Voice Message Transcription

Voice message support works out of the box. When a user sends a voice message:

1. The bot downloads the `.oga` audio file
2. `ffmpeg` converts it to `.wav`
3. Whisper transcribes it using `/opt/shared-env/whisper-models/tiny.pt`
4. Claude responds as if the user typed the text

This is driven by instructions in `~/my-assistant/CLAUDE.md`. No extra setup is needed as long as:

- `ffmpeg` is installed (`which ffmpeg`)
- `tiny.pt` exists and is readable (`ls -la /opt/shared-env/whisper-models/`)
- `WHISPER_CACHE_DIR` is set in the systemd service (the onboarding script does this automatically)

To use a more accurate model:

```bash
sudo /opt/shared-env/bin/python3 -c "
import whisper
whisper.load_model('base', download_root='/opt/shared-env/whisper-models')
"
sudo chmod 644 /opt/shared-env/whisper-models/base.pt
```

Then update `load_model('tiny', ...)` in `/opt/workshop-kit/my-assistant/CLAUDE.md` and push to all users (see "Push Updated CLAUDE.md" above).

---

## Part E — Google Workspace (Optional, Per User)

```bash
sudo su - alice
claude mcp add google-workspace --scope user \
  -e GOOGLE_CLIENT_ID=<their-client-id> \
  -e GOOGLE_CLIENT_SECRET=<their-client-secret> \
  -- npx @dguido/google-workspace-mcp
exit
```

---

## Cost Summary

| Item                                 | Cost              | Notes                            |
|--------------------------------------|-------------------|----------------------------------|
| Linux VM (4 CPU, 16 GB, 20 GB disk)  | ~$20–50/month     | DigitalOcean, Hetzner, AWS, etc. |
| Claude Pro per person                | $20/month each    | Minimum for Claude Code          |
| Claude Max per person (optional)     | $100/month each   | Higher usage limits              |
| Telegram bots                        | Free              | Unlimited via @BotFather         |
| **5-person team (Pro)**              | ~$120–150/month   | 1 VM + 5× Pro                    |
| **5-person team (Max)**              | ~$520–550/month   | 1 VM + 5× Max                    |
| **10-person team (Pro)**             | ~$220–250/month   | 1 VM + 10× Pro                   |
| **10-person team (Max)**             | ~$1020–1050/month | 1 VM + 10× Max                   |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Service won't start | `sudo tail -f /home/<user>/claude-assistant.log` |
| Claude exits immediately on startup | `settings.json` must have `"skipDangerousModePermissionPrompt": true` and `"permissions": {"defaultMode": "bypassPermissions"}` |
| `claude login` shows no URL | Requires interactive terminal: `sudo su - <user>` → `export XDG_RUNTIME_DIR=/run/user/$(id -u)` → `claude login` |
| `systemctl --user` fails with "No medium found" | Run `export XDG_RUNTIME_DIR=/run/user/$(id -u)` first |
| Telegram bot not responding | Check service is active; check `~/.cache/claude-cli-nodejs/` MCP logs |
| Voice messages not transcribing | Check: `ffmpeg` installed; `tiny.pt` is `chmod 644`; `WHISPER_CACHE_DIR` set in service; service PATH includes `/opt/shared-env/bin` |
| Whisper PermissionError on model file | `sudo chmod 644 /opt/shared-env/whisper-models/*.pt` |
| Whisper install pulls in CUDA (~4 GB) | Install torch CPU-only first: `pip install torch --index-url https://download.pytorch.org/whl/cpu` |
| Plugin not copied by onboarding script | Install plugin on admin account first (Step 5), then re-run the script |
| Skills not loading | `ls -la ~/.claude/skills` should be a symlink to `/opt/workshop-kit/skills` |
| "linger not enabled" error | `sudo loginctl enable-linger <username>` |
| Need to update Claude Code | `sudo npm update -g @anthropic-ai/claude-code` then restart all services |
| Bot token compromised | Revoke via @BotFather (`/revoke`), update `.env`, restart service |
| Slow performance with multiple users | Upgrade VM — budget 1–2 GB RAM per active Claude instance |
| Disk full / SSH not working | `df -h /` — resize disk in cloud console then: `sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1` |

---

## Quick Reference — Admin Cheat Sheet

```bash
# Add a new team member
sudo /opt/workshop-kit/add-team-member.sh <username> "<bot-token>"

# Log in to Claude for a user (interactive — required after onboarding)
sudo su - <username>
export XDG_RUNTIME_DIR=/run/user/$(id -u)
claude login
systemctl --user restart claude-assistant
exit

# Pair Telegram after user sends you their 6-digit code
sudo /opt/workshop-kit/pair-user.sh <username> <code>

# Check who's running
for user in $(ls /home/); do
    echo -n "$user: "
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user is-active claude-assistant 2>/dev/null || echo "inactive"
done

# Restart everyone
for user in $(ls /home/); do
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user restart claude-assistant 2>/dev/null || true
done

# Update shared skills
cd /opt/workshop-kit && sudo git pull

# Push updated CLAUDE.md to all users and restart
for user in $(ls /home/); do
    [ -f "/home/$user/my-assistant/CLAUDE.md" ] && \
        sudo cp /opt/workshop-kit/my-assistant/CLAUDE.md /home/$user/my-assistant/CLAUDE.md
done
for user in $(ls /home/); do
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user restart claude-assistant 2>/dev/null || true
done
```

---

_Built by Selr AI — [selrai.com.au](https://selrai.com.au)_
