---
name: gcp-deployment-expert
description: "Expert in deploying AI assistants and services on GCP VMs. Activate on: GCP setup, Compute Engine, VM provisioning, gcloud, systemd service, Linux server setup, OAuth on server, gws auth, port forwarding, headless auth, Claude server deployment, single-user server. NOT for: Kubernetes (use devops-automator), Terraform (use terraform-iac-expert), general cloud architecture (use devops-automator)."
allowed-tools: Read,Write,Edit,Bash(gcloud:*,ssh:*,systemctl:*,loginctl:*)
metadata:
  category: DevOps & Infrastructure
  pairs-with:
  - skill: devops-automator
    reason: For multi-service or container-based deployments beyond a single VM
  - skill: site-reliability-engineer
    reason: For monitoring, alerting, and uptime guarantees on the deployed service
  tags:
  - gcp
  - compute-engine
  - systemd
  - linux
  - oauth
  - headless-auth
  - claude-deployment
---

# GCP Deployment Expert

Expert in provisioning and configuring GCP Compute Engine VMs to run AI assistants (Claude Code) and related services 24/7. Covers the full lifecycle: VM creation, system setup, auth flows, service management, and Google Workspace integration on headless servers.

## Activation Triggers

**Activate on:** "GCP", "Google Cloud", "Compute Engine", "VM", "gcloud", "systemd", "Linux server", "headless auth", "OAuth on server", "gws auth", "port forwarding", "Claude server", "deploy assistant", "24/7 server", "service not starting", "VM setup"

**NOT for:** Kubernetes / container orchestration → `devops-automator` | Terraform IaC → `terraform-iac-expert` | General cloud architecture → `devops-automator`

---

## Quick Start — Deploy Claude on a GCP VM

```
1. Get zone    → gcloud compute zones list --filter="region:<region>" --format="value(name)"
2. Create VM   → gcloud compute instances create <name> --zone=<zone> --machine-type=e2-standard-2
                   --image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud
                   --boot-disk-size=50GB --boot-disk-type=pd-standard
3. Wait 15s    → gcloud compute ssh <name> --command="echo OK"
4. Install     → swap → apt tools → Node.js → Bun → Whisper → Claude Code
5. Workspace   → git clone workshop-kit → copy CLAUDE.md → copy skills
6. Service     → write start-claude.sh (PTY wrapper) → write systemd unit → enable + start
7. Auth        → user SSHs in, runs claude ., signs in, installs plugin, pairs messaging
```

---

## VM Provisioning

### Correct Image Name Pattern

Never hardcode an image name — use the family flag so it always resolves to the latest:

```bash
--image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud
```

Do NOT use: `--image=ubuntu-2404-lts-amd64` (this breaks when the image is updated)

### Machine Type Decision

| Use case | Machine type | RAM | Notes |
|---|---|---|---|
| Single user, light tasks | e2-standard-2 | 8 GB | Default for workshop |
| Single user, heavy research | e2-standard-4 | 16 GB | If hitting memory limits |
| Multi-user | e2-standard-4+ | 16 GB+ | One Claude process per user |

Always add **4 GB swap** — Claude Code and Whisper together can spike past physical RAM:

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Zone Selection

Pick the first available zone in the user's region — do not ask:

```bash
gcloud compute zones list --filter="region:<region>" --format="value(name)" | head -1
```

| Region label | Region ID |
|---|---|
| Australia (Sydney) | australia-southeast1 |
| USA (Iowa) | us-central1 |
| USA (Virginia) | us-east1 |
| Europe (Belgium) | europe-west1 |
| Asia (Singapore) | asia-southeast1 |

---

## Installation Stack

Run all installs in a single `gcloud compute ssh --command` call where possible. Correct order:

```bash
# 1. System tools
sudo apt-get update -qq && sudo apt-get install -y \
  curl git ffmpeg python3 python3-pip build-essential unzip

# 2. Node.js v22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. Bun
curl -fsSL https://bun.sh/install | bash
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc

# 4. Whisper + tiny model (pre-download so it is ready for voice messages)
pip3 install openai-whisper --quiet --break-system-packages
echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
python3 -c "import whisper; whisper.load_model('tiny')"

# 5. Claude Code
curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

---

## Systemd Service Pattern

### PTY Wrapper (required — Claude needs a pseudo-terminal)

```python
#!/usr/bin/env python3
# ~/start-claude.sh
import pty, os

def read(fd):
    return os.read(fd, 1024)

pty.spawn(
    [os.path.expanduser("~/.local/bin/claude"), "--channels", "plugin:<platform>@claude-plugins-official"],
    master_read=read
)
```

Platform values: `telegram` | `discord` | `whatsapp` | `imessage`

### Service Unit

```ini
# ~/.config/systemd/user/claude-assistant.service
[Unit]
Description=Claude AI Assistant
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/my-assistant
Environment=PATH=/home/<user>/.local/bin:/home/<user>/.bun/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=%h
Environment=WHISPER_CACHE_DIR=%h/.cache/whisper
ExecStart=/usr/bin/python3 /home/<user>/start-claude.sh
Restart=on-failure
RestartSec=10
StandardOutput=append:%h/claude-assistant.log
StandardError=append:%h/claude-assistant.log

[Install]
WantedBy=default.target
```

### Enable and Start

```bash
loginctl enable-linger $USER          # survive SSH logout
systemctl --user daemon-reload
systemctl --user enable claude-assistant
systemctl --user start claude-assistant
```

### Verify

```bash
systemctl --user status claude-assistant --no-pager
tail -20 ~/claude-assistant.log
```

**Healthy log contains:** `Listening for channel messages from: plugin:<platform>@claude-plugins-official`
**Problem log contains:** `plugin not installed` → user must install the plugin interactively (see Plugin Install section)

---

## Auth Flows

### Claude Code (interactive — user must do this)

```bash
cd ~/my-assistant && claude .
# Press 1 → open URL in browser → sign in → return
```

### Messaging Plugin (interactive — user must do this)

```
/plugins              → install the platform plugin
/telegram:configure <token>   → save bot token
/exit
claude . --channels plugin:telegram@claude-plugins-official
# Message bot in Telegram → get 6-char code
/telegram:access pair <code>
/telegram:access policy allowlist
/exit
```

### Google Workspace on Headless Server (automated except user signs in via browser)

This is the most complex auth flow. Follow all four steps in order — skipping any step causes the next to fail.

**Step 1 — Authenticate gcloud as user (no browser needed):**
```bash
gcloud auth login --no-launch-browser
# Prints URL → user opens in laptop browser → pastes code back
```
Why: `gws auth setup` uses gcloud credentials to create the GCP project. Without this it fails with "insufficient scopes".

**Step 2 — Create OAuth app (first time only):**
```bash
gws auth setup
# Project ID: gws-claude-assistant (6–30 chars, lowercase, hyphens only)
```

**Step 3 — Add user as test user (prevents "Access blocked"):**
Open `console.cloud.google.com` → APIs & Services → OAuth consent screen → Test users → Add email → Save

**Step 4 — Reconnect SSH with port-forward tunnel, then sign in:**
```bash
# On laptop
gcloud compute ssh <vm> --project=<project> --zone=<zone> -- -L 9966:localhost:9966

# On server
gws auth login -s drive,gmail,sheets,calendar
# ALWAYS use -s flag — without it, Google rejects due to 85+ scopes requested
```

**Known errors and fixes:**

| Error | Cause | Fix |
|---|---|---|
| `gws auth setup` fails: "insufficient scopes" | Step 1 skipped | Run `gcloud auth login --no-launch-browser` first |
| "Access blocked: request is invalid" | User not in test users | Add email in GCP Console → OAuth consent screen → Test users |
| `gws auth login` hangs or callback fails | No tunnel | Reconnect SSH with `-L 9966:localhost:9966` |
| Too many scopes rejected | Missing `-s` flag | Always use `gws auth login -s drive,gmail,sheets,calendar` |
| Wrong Google account | Previous auth cached | `gws auth logout` then redo Step 4 |

---

## Workspace Setup

```bash
git clone https://github.com/luke-selrai/openclaw-workshop-kit.git ~/workshop-kit
mkdir -p ~/my-assistant
cp ~/workshop-kit/my-assistant/CLAUDE.md ~/my-assistant/CLAUDE.md
mkdir -p ~/.claude/skills
cp -r ~/workshop-kit/skills/*/ ~/.claude/skills/
```

### Mark as Trusted (prevents prompts on first launch)

```bash
python3 -c "
import json, os
path = os.path.expanduser('~/.claude.json')
with open(path) as f: d = json.load(f)
d['hasCompletedOnboarding'] = True
d['lastOnboardingVersion'] = 100
d['theme'] = 'dark'
if 'projects' not in d: d['projects'] = {}
home = os.path.expanduser('~')
d['projects'][home + '/my-assistant'] = {
    'hasTrustDialogAccepted': True,
    'projectOnboardingSeenCount': 1,
    'hasClaudeMdExternalIncludesApproved': True,
    'hasClaudeMdExternalIncludesWarningShown': True,
    'allowedTools': [], 'mcpContextUris': [], 'mcpServers': {},
    'enabledMcpjsonServers': [], 'disabledMcpjsonServers': []
}
with open(path, 'w') as f: json.dump(d, f, indent=2)
print('Done')
"
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| VM creation fails: image not found | Use `--image-family=ubuntu-2404-lts --image-project=ubuntu-os-cloud` not a hardcoded image name |
| SSH fails immediately after VM creation | Wait 15–20s after creation before connecting |
| `claude .` crashes with OOM | Add more swap or upgrade to e2-standard-4 |
| Service starts but log shows "plugin not installed" | User must install plugin interactively: `claude .` → `/plugins` → install → `/exit` |
| Service keeps restarting | Check `journalctl --user -u claude-assistant -n 50` for the actual error |
| `gws: command not found` | `source ~/.bashrc` — PATH not loaded in non-login shell |
| `loginctl enable-linger` fails | Run as the actual user, not root |
| Whisper voice transcription fails | Model not downloaded: `python3 -c "import whisper; whisper.load_model('tiny')"` |
| GCP project quota exceeded | Use a different project or request quota increase in GCP Console |

---

## Cost Reference (AUD, approximate)

| Resource | e2-standard-2 24/7 | e2-standard-4 24/7 |
|---|---|---|
| Compute | ~$45–55/month | ~$90–110/month |
| 50 GB disk | ~$3/month | ~$3/month |
| Egress (light) | ~$1–3/month | ~$1–3/month |
| **Total** | **~$49–61/month** | **~$94–116/month** |

Stop the VM when not in use to reduce compute costs:
```bash
gcloud compute instances stop <vm-name> --project=<project> --zone=<zone>
```
