# Deployment Notes — VM Setup (selrai-rnd)

**VM:** `claude-assistant-test-rodolfo`
**Zone:** `australia-southeast1-b`
**Project:** `selrai-rnd`
**Date:** 2026-03-31

---

## Blockers Encountered and Fixed

### 1. Disk full (100%) — crashed SSH and killed Claude

**What happened:** The 20 GB disk filled completely. This caused:
- SSH connections to fail (exit code 255)
- Claude process to be OOM-killed by the kernel
- systemd journal writes to fail

**Fix applied:**
- Resized disk from 20 GB → 50 GB via `gcloud compute disks resize`
- Freed enough space to run `growpart` by clearing journal logs
- Ran `growpart /dev/sda 1` + `resize2fs /dev/sda1` to expand the live filesystem
- Updated guide minimum disk recommendation from 20 GB → 50 GB

---

### 2. No swap space — Claude OOM-killed under load

**What happened:** The VM (e2-small, ~2 GB RAM) had no swap. When Claude Code uses more memory than available, the Linux OOM killer terminates the process.

**Fix applied:**
- Added 2 GB swap file (`/swapfile`) to both current VM and guide
- Made permanent via `/etc/fstab`

---

### 3. Whisper not in service PATH — voice transcription failing

**What happened:** The systemd service `PATH` did not include `/opt/shared-env/bin/`, where `whisper` is installed. Claude couldn't find the `whisper` binary when transcribing voice messages from Telegram.

**Fix applied:**
- Updated PATH in both users' service files from:
  `PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin`
  to:
  `PATH=/opt/shared-env/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin`
- Also updated `settings.json` `env.PATH` for the same reason
- Fixed in guide template (`add-team-member.sh`)

---

### 4. WHISPER_CACHE_DIR missing from service files

**What happened:** The live service files for both `cx559824` and `developer` were missing `WHISPER_CACHE_DIR`. Without it, Whisper downloads its model (~72 MB) to each user's home directory on first use instead of using the shared cache at `/opt/shared-env/whisper-models`.

**Fix applied:** Added `Environment=WHISPER_CACHE_DIR=/opt/shared-env/whisper-models` to both service files and restarted services.

---

## Current Live State (as of 2026-03-31)

| User | Role | Service | Claude login | Telegram | Skills |
|---|---|---|---|---|---|
| `cx559824` | admin | ✅ running | ✅ | ✅ | ✅ symlinked |
| `developer` | test user | ✅ running | ✅ | ✅ | ✅ symlinked |

VM health:
- Disk: 48 GB total, ~19 GB used, ~30 GB free (38%)
- RAM: 1.9 GB + 2 GB swap
- Both services set to `Restart=always` + `loginctl enable-linger`

---

## Files Referenced During Setup

| File | Location | Purpose |
|---|---|---|
| Onboarding script | `/opt/workshop-kit/add-team-member.sh` | Creates a new user with full Claude + Telegram setup |
| Pairing script | `/opt/workshop-kit/pair-user.sh` | Links a user's Telegram account after first message |
| PTY wrapper | `~/start-claude.sh` (per user) | Keeps Claude running as a daemon with a pseudo-terminal |
| Systemd service | `~/.config/systemd/user/claude-assistant.service` | Starts Claude on boot, restarts on crash |
| Claude settings | `~/.claude/settings.json` | Enables Telegram plugin, sets PATH |
| Telegram config | `~/.claude/channels/telegram/.env` | Bot token |
| Telegram access | `~/.claude/channels/telegram/access.json` | Who can message the bot |
| Workshop CLAUDE.md | `~/my-assistant/CLAUDE.md` | Claude's instructions and personality |
| Skills symlink | `~/.claude/skills → /opt/workshop-kit/skills` | Points to shared skills library |
| Shared Python env | `/opt/shared-env/` | Whisper + dependencies (shared across all users) |
| Whisper models | `/opt/shared-env/whisper-models/` | Pre-downloaded voice model cache |

---

## Directory Structure — Multi-User Layout

```
/opt/
├── workshop-kit/               ← Git repo (shared, admin-managed)
│   ├── add-team-member.sh      ← Run to add a new user
│   ├── pair-user.sh            ← Run to link Telegram
│   ├── my-assistant/
│   │   └── CLAUDE.md           ← Template copied to each user
│   ├── skills/                 ← Skill library (symlinked to all users)
│   └── docs/                   ← This guide + other documentation
│
└── shared-env/                 ← Python virtual environment (shared)
    ├── bin/
    │   ├── whisper             ← Voice transcription CLI
    │   └── python              ← Python runtime
    └── whisper-models/
        └── tiny.pt             ← Pre-downloaded Whisper model

/home/
├── cx559824/                   ← Admin user
│   ├── my-assistant/
│   │   ├── CLAUDE.md           ← Claude's instructions (copied from /opt)
│   │   └── memory/             ← Claude's persistent memory (private)
│   ├── .claude/
│   │   ├── settings.json       ← Plugin config + PATH
│   │   ├── channels/
│   │   │   └── telegram/.env   ← Bot token (private)
│   │   ├── plugins/            ← Telegram plugin (copied from admin)
│   │   └── skills → /opt/workshop-kit/skills   ← Symlink
│   ├── start-claude.sh         ← PTY wrapper daemon
│   ├── claude-assistant.log    ← Service output log
│   └── .config/systemd/user/
│       └── claude-assistant.service   ← Always-on service
│
└── developer/                  ← Team member user (same structure)
    ├── my-assistant/           ← Their private workspace
    ├── .claude/                ← Their private Claude config
    ├── start-claude.sh
    └── .config/systemd/user/
        └── claude-assistant.service
```

Each user's home directory is private (`drwxr-x---`). They cannot see each other's files or conversations.

---

## How It Stays Running After SSH Disconnect

1. `loginctl enable-linger <username>` — allows user systemd services to run without an active login session
2. `claude-assistant.service` with `Restart=always` — restarts Claude if it crashes
3. The PTY wrapper (`start-claude.sh`) — allocates a pseudo-terminal, which Claude Code requires to run non-interactively
4. `Restart=always` + `RestartSec=10` — if Claude exits for any reason, systemd restarts it after 10 seconds

Without the PTY wrapper, Claude Code exits immediately because it detects there's no terminal.

---

_Maintained by Selr AI — [selrai.com.au](https://selrai.com.au)_
