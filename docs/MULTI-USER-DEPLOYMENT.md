---
title: Multi-User Server Deployment Guide
version: 6.0
date: 2026-03-31
---

# Multi-User Server Deployment — One VM, Many Assistants

This guide sets up a single server where every team member gets their own Claude Code instance and their own Telegram bot. Each person messages their bot from their phone and gets a dedicated AI assistant.

**Design principle: let Claude do the work.** After a three-command bootstrap, the admin opens Claude Code and pastes prompts. Claude runs the shell commands. Manual steps only appear where Claude genuinely cannot help — interactive `claude login` and the initial install before Claude exists.

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

## Part 0 — What You Need

Before you start, confirm you have:

- **A Linux VM** — Ubuntu 22.04+ or Debian 12+
  - Minimum: 2 CPU, 8 GB RAM (up to ~4 users)
  - Recommended: 4 CPU, 16 GB RAM (5–10 users)
  - **Disk: 50 GB minimum** — the shared Python environment alone is ~1.5 GB; logs, npm, and node_modules fill small disks fast
  - Budget ~1–2 GB RAM per active Claude Code instance
- **SSH access** with sudo privileges
- **A Claude Max subscription per team member** (required for Claude Code)
- **One Telegram bot per team member** — free, created via @BotFather (takes 30 seconds)

---

## Part A — One-Time Server Bootstrap (Admin, Fresh Server)

These are the only manual steps. Everything after this is handled by Claude.

### Step 1 — Install Node.js and Claude Code

Paste into your terminal:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g @anthropic-ai/claude-code
```

### Step 2 — Log in to Claude (interactive — required)

```bash
claude login
```

A URL will appear. Open it in your browser and complete the login. This authenticates Claude Code on the admin account.

### Step 3 — Start Claude Code in your working directory

```bash
claude
```

### Step 4 — Paste this prompt into Claude Code (copy exactly)

> You are setting up a fresh Ubuntu server for multi-user Claude Code deployment. Please do the following in order and confirm each step before moving on:
>
> 1. Install system packages: git, curl, unzip, ffmpeg, python3-venv, python3-pip, bun
> 2. Set up a 2 GB swap file at /swapfile (skip if swap already exists)
> 3. Clone the workshop kit: git clone https://github.com/luke-selrai/openclaw-workshop-kit.git /opt/workshop-kit
> 4. Set up a shared Python environment at /opt/shared-env with CPU-only PyTorch, openai-whisper, and dependencies
> 5. Pre-download the Whisper tiny model to /opt/shared-env/whisper-models/ and set chmod 644 on the .pt file
> 6. Install the Telegram plugin: /plugin install telegram@claude-plugins-official
> 7. Make the onboarding scripts executable: chmod +x /opt/workshop-kit/add-team-member.sh /opt/workshop-kit/pair-user.sh
> 8. Confirm everything is ready and show me a status summary

That is it for server setup. Claude handles steps 1–8. The underlying script Claude will run is at `/opt/workshop-kit/setup-server.sh` (cloned in step 3).

> **Note on step 6:** `/plugin install` is interactive inside Claude Code — it is one of the few things Claude runs on your behalf rather than delegating to a shell script.

---

## Part B — Add a Team Member

Again, as much as possible through Claude.

### Step 1 — Team member creates their Telegram bot

1. Open Telegram → search **@BotFather** → tap **Start**
2. Send `/newbot`
3. Choose a display name (e.g. "Alice's Assistant")
4. Choose a username ending in `bot` (e.g. `alice_selrai_bot`)
5. Copy the token (looks like `123456789:AAHfiqksKZ8...`) and send it to the admin

### Step 2 — Admin tells Claude to add the user (replacing values)

Paste into Claude Code:

> Add a new team member to this server. Their username will be `alice` and their Telegram bot token is `123456789:AAHfiqksKZ8...`. Run: sudo /opt/workshop-kit/add-team-member.sh alice "123456789:AAHfiqksKZ8..."

Claude runs the script, which creates the Linux account, workspace, Telegram config, plugin, PTY wrapper, and systemd service.

### Step 3 — Claude login for the new user (manual — interactive terminal required)

`claude login` opens a browser flow and cannot be automated. After the script finishes:

```bash
sudo su - alice
export XDG_RUNTIME_DIR=/run/user/$(id -u)
claude login
# A URL appears — copy it and send it to alice
# Wait for her to log in and give you the confirmation code to paste back
systemctl --user restart claude-assistant
exit
```

### Step 4 — Pair Telegram

Alice messages her bot and gets a 6-digit pairing code. She sends it to the admin. Admin tells Claude:

> alice just messaged her bot and got the code `a1b2c3`. Pair her: sudo /opt/workshop-kit/pair-user.sh alice a1b2c3

Done. Alice's assistant is live.

---

## Part C — Day-to-Day Management via Claude

The admin never needs to remember shell commands. Just describe what you want to Claude Code.

### "Check which assistants are running"

Claude will run:

```bash
for user in $(ls /home/); do
    echo -n "$user: "
    sudo -u "$user" XDG_RUNTIME_DIR=/run/user/$(id -u "$user") \
        systemctl --user is-active claude-assistant 2>/dev/null || echo "not set up"
done
```

### "Restart alice's assistant"

Claude will run:

```bash
sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user restart claude-assistant
```

### "Update the skills for everyone"

Skills are symlinked — pulling the shared repo updates everyone instantly. Claude will run:

```bash
cd /opt/workshop-kit && sudo git pull
```

### "Push the updated CLAUDE.md to all users and restart their services"

Claude will run:

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

### "Show me the logs for developer"

Claude will run:

```bash
sudo tail -f /home/developer/claude-assistant.log
```

Or for journal logs:

```bash
sudo -u developer XDG_RUNTIME_DIR=/run/user/$(id -u developer) \
    journalctl --user -u claude-assistant -f
```

### "Remove the user alice from the server"

Claude will run:

```bash
sudo -u alice XDG_RUNTIME_DIR=/run/user/$(id -u alice) systemctl --user stop claude-assistant
sudo userdel -r alice   # removes home directory; omit -r to keep it as a backup
```

---

## Part D — Voice Message Transcription

Voice message support works out of the box. When a user sends a voice message to their bot:

1. The bot downloads the `.oga` audio file from Telegram
2. `ffmpeg` converts it to `.wav`
3. Whisper transcribes it using `/opt/shared-env/whisper-models/tiny.pt`
4. Claude responds as if the user had typed the text

This is driven by instructions in `~/my-assistant/CLAUDE.md`. No extra setup is needed beyond what the bootstrap already configured, as long as:

- `ffmpeg` is installed (`which ffmpeg` to verify)
- `tiny.pt` exists and is world-readable (`ls -la /opt/shared-env/whisper-models/`)
- `WHISPER_CACHE_DIR=/opt/shared-env/whisper-models` is set in the systemd service (the onboarding script handles this automatically)
- The service `PATH` includes `/opt/shared-env/bin` (also set by the onboarding script)

> **Important:** `chmod 644 tiny.pt` is required. Without it, non-root users get a `PermissionError` when Whisper tries to open the model file.

To use a more accurate model (larger download):

```bash
sudo /opt/shared-env/bin/python3 -c "
import whisper
whisper.load_model('base', download_root='/opt/shared-env/whisper-models')
"
sudo chmod 644 /opt/shared-env/whisper-models/base.pt
```

Then update the model name in `/opt/workshop-kit/my-assistant/CLAUDE.md` and push to all users (see Part C above).

---

## Part E — Server Directory Structure

```
/
├── usr/bin/claude                         → symlink to Claude Code (npm global)
│
├── opt/
│   ├── workshop-kit/                      ← shared read-only source (git repo)
│   │   ├── add-team-member.sh             ← onboarding script (admin only)
│   │   ├── pair-user.sh                   ← Telegram pairing script (admin only)
│   │   ├── setup-server.sh                ← bootstrap script (run by Claude in Part A)
│   │   ├── my-assistant/
│   │   │   └── CLAUDE.md                  ← template copied to each new user
│   │   ├── skills/                        ← 86+ skills (symlinked into ~/.claude/skills)
│   │   └── docs/
│   │       └── MULTI-USER-DEPLOYMENT.md   ← this file
│   │
│   └── shared-env/                        ← shared Python venv (all users)
│       ├── bin/python3
│       ├── bin/whisper
│       └── whisper-models/
│           └── tiny.pt                    ← pre-downloaded, 72 MB, chmod 644
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
    │       ├── plugins/                  ← Telegram plugin (installed in Part A Step 6)
    │       └── skills/                   → symlink → /opt/workshop-kit/skills/
    │
    └── <username>/                       ← each team member (same structure)
        ├── start-claude.sh               ← PTY wrapper (written by onboarding script)
        ├── claude-assistant.log          ← service log
        ├── my-assistant/
        │   ├── CLAUDE.md                 ← copied from template
        │   └── memory/                   ← persistent user memory notes
        └── .claude/
            ├── settings.json             ← bypass perms + Telegram plugin enabled
            ├── .credentials.json         ← their own claude login token
            ├── channels/telegram/
            │   ├── .env                  ← their bot token (chmod 600)
            │   ├── access.json           ← who can DM their bot
            │   └── approved/             ← paired users (written at pairing time)
            ├── plugins/cache/            ← Telegram plugin (copied from admin)
            └── skills/                   → symlink → /opt/workshop-kit/skills/
```

---

## Part F — Troubleshooting

| Problem | Fix |
|---------|-----|
| Service won't start | `sudo tail -f /home/<user>/claude-assistant.log` — look for the error |
| Claude exits immediately on startup | `settings.json` must have `"skipDangerousModePermissionPrompt": true` and `"permissions": {"defaultMode": "bypassPermissions"}` |
| `claude login` shows no URL | Requires an interactive terminal: `sudo su - <user>` → `export XDG_RUNTIME_DIR=/run/user/$(id -u)` → `claude login` |
| `systemctl --user` fails with "No medium found" | Run `export XDG_RUNTIME_DIR=/run/user/$(id -u)` before the systemctl command |
| Telegram bot not responding | Check service is active; check `~/.cache/claude-cli-nodejs/` for MCP logs |
| Voice messages not transcribing | Verify: `ffmpeg` installed; `tiny.pt` is `chmod 644`; `WHISPER_CACHE_DIR` set in service; service `PATH` includes `/opt/shared-env/bin` |
| Whisper PermissionError on model file | `sudo chmod 644 /opt/shared-env/whisper-models/*.pt` |
| Whisper install pulls in CUDA (~4 GB) | Install torch CPU-only first: `pip install torch --index-url https://download.pytorch.org/whl/cpu` |
| Plugin not copied by onboarding script | Install plugin on admin account first (Part A Step 6), then re-run `add-team-member.sh` |
| Skills not loading | `ls -la ~/.claude/skills` should be a symlink to `/opt/workshop-kit/skills` |
| "linger not enabled" error | `sudo loginctl enable-linger <username>` |
| PATH errors (bun, whisper not found) | The service `PATH` in `settings.json` must include `/opt/shared-env/bin:/usr/local/bin` — the onboarding script sets this |
| Need to update Claude Code | `sudo npm update -g @anthropic-ai/claude-code` then restart all services |
| Bot token compromised | Revoke via @BotFather (`/revoke`), update `~/.claude/channels/telegram/.env`, restart service |
| Slow performance with multiple users | Upgrade VM — budget 1–2 GB RAM per active Claude instance |
| No swap / OOM kills | `free -h` — if swap is 0, add it: `sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo '/swapfile none swap sw 0 0' \| sudo tee -a /etc/fstab` |
| Disk full / SSH not working | `df -h /` — resize disk in cloud console, then: `sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1` |

---

## Part G — Cost Summary

| Item                                  | Cost                | Notes                            |
|---------------------------------------|---------------------|----------------------------------|
| Linux VM (4 CPU, 16 GB, 50 GB disk)   | ~$20–50/month       | DigitalOcean, Hetzner, AWS, etc. |
| Claude Max per person                 | $100/month each     | Required for Claude Code         |
| Telegram bots                         | Free                | Unlimited via @BotFather         |
| **5-person team (Max)**               | ~$520–550/month     | 1 VM + 5× Max                    |
| **10-person team (Max)**              | ~$1,020–1,050/month | 1 VM + 10× Max                   |

---

_Built by Selr AI — [selrai.com.au](https://selrai.com.au)_
