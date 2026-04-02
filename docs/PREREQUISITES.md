# Prerequisites and Requirements

**Read this BEFORE running `bash install.sh`.**

This document covers every dependency, account, credential, and system requirement needed to run the Selr AI Internal Kit. Requirements are organized by component so you only set up what you need.

---

## Table of Contents

1. [Quick Checklist](#quick-checklist)
2. [System Requirements](#system-requirements)
3. [Core Requirements (Everyone)](#core-requirements-everyone)
4. [GHL Toolkit Requirements](#ghl-toolkit-requirements)
5. [Google Chat Toolkit Requirements](#google-chat-toolkit-requirements)
6. [Server Setup Requirements](#server-setup-requirements)
7. [Claude Dispatch Requirements](#claude-dispatch-requirements)
8. [Skill Creator Requirements](#skill-creator-requirements)
9. [Network and Firewall](#network-and-firewall)
10. [Cost Summary](#cost-summary)
11. [Pre-Install Verification](#pre-install-verification)

---

## Quick Checklist

Print this and tick off before you start.

### Minimum (Core Kit)

- [ ] macOS, Windows, or Linux computer
- [ ] Bash shell (Terminal on Mac, Git Bash on Windows)
- [ ] Node.js LTS installed (`node --version` shows v18+)
- [ ] Git installed (`git --version`)
- [ ] Claude Code CLI installed (`claude --version` shows v2.0+)
- [ ] `~/.claude/` directory exists (created by running `claude` once)
- [ ] Active Claude subscription (Pro or Max)

### If Using GHL Toolkit

- [ ] GoHighLevel account with API access
- [ ] GHL API Key (Settings > Business Profile > API Key)
- [ ] GHL Location ID (from your GHL dashboard URL)
- [ ] GHL login email and password (for browser automation)

### If Using Google Chat Toolkit

- [ ] Google Workspace account (NOT personal Gmail)
- [ ] GCP project with Chat API enabled
- [ ] OAuth Desktop App credentials (client_secret.json)

### If Using Server Setup

- [ ] AWS account with billing enabled
- [ ] Supabase account (free tier is fine)
- [ ] Tailscale account (free tier is fine)
- [ ] SSH key pair or ability to generate one

### If Using Claude Dispatch

- [ ] Claude **Pro or Max** subscription (API keys not supported)
- [ ] Claude Desktop app (latest version, macOS or Windows)
- [ ] Claude mobile app (iOS or Android, latest version)

---

## System Requirements

### Supported Operating Systems

| OS | Status | Terminal |
|----|--------|----------|
| **macOS** (Ventura 13+) | Primary target | Terminal.app or iTerm2 |
| **Windows 10/11** | Supported | Git Bash (MINGW64) |
| **Windows WSL** | Supported | Ubuntu terminal |
| **Linux** (Ubuntu 20.04+) | Supported | Any bash terminal |

### Hardware (Local Machine)

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| RAM | 4 GB | 8 GB+ |
| Disk space | 500 MB (kit + skills) | 2 GB (with toolkits and caches) |
| Internet | Required | Stable broadband |

### Hardware (Server — only for server-setup)

| Requirement | Spec |
|-------------|------|
| Instance type | AWS EC2 `t3.medium` (2 vCPU, 4 GB RAM) |
| Disk | 30 GB gp3 EBS volume |
| OS | Ubuntu 24.04 LTS |
| Estimated cost | ~$30 USD/month |

---

## Core Requirements (Everyone)

These are required regardless of which components you install.

### Software

| Tool | Version | Check Command | Install |
|------|---------|---------------|---------|
| **Node.js** | LTS (v18+) | `node --version` | [nodejs.org](https://nodejs.org/) or `brew install node` |
| **npm** | 8+ (comes with Node) | `npm --version` | Bundled with Node.js |
| **Git** | 2.30+ | `git --version` | [git-scm.com](https://git-scm.com/) or `brew install git` |
| **Claude Code** | v2.0+ | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| **Bash** | 4.0+ | `bash --version` | Pre-installed (macOS/Linux) or Git Bash (Windows) |
| **curl** | Any | `curl --version` | Pre-installed on macOS/Linux |

### Accounts

| Account | Cost | Sign Up |
|---------|------|---------|
| **Anthropic / Claude** | Pro $20/mo or Max $100/mo | [claude.ai](https://claude.ai/) |

### First-Time Setup

Before running `install.sh`, make sure Claude Code has been initialized:

```bash
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Run once to create ~/.claude/ directory and authenticate
claude

# Verify
ls ~/.claude/
```

---

## GHL Toolkit Requirements

**Component:** `toolkits/ghl-toolkit/` + `skills/ghl-crm/` + `skills/ghl-browser/`

### Software

| Tool | Required? | Purpose |
|------|-----------|---------|
| curl | REQUIRED | API calls to GHL |
| Claude Code | REQUIRED | Skill execution |
| Playwright MCP | Optional | Browser automation for UI-only GHL operations |
| Gmail MCP | Optional | Autonomous 2FA during GHL login |
| Patchright | Optional | Anti-detection browser profiles |

### Account

| Account | Cost | Where to Get It |
|---------|------|-----------------|
| **GoHighLevel** | $25/mo USD (via Selr AI agency sub-account) or $97-$297/mo direct | Contact your Selr AI workshop facilitator or [gohighlevel.com](https://www.gohighlevel.com/) |

### Credentials You Need

| Credential | Where to Find It | Example |
|------------|-------------------|---------|
| **GHL API Key** | GHL > Settings > Business Profile > API Key | `eyJhbGciOiJSUzI1NiIs...` |
| **GHL Location ID** | Your GHL URL: `app.gohighlevel.com/v2/location/THIS_PART/...` | `abc123def456` |
| **GHL Login Email** | Your GHL login email | `user@example.com` |
| **GHL Login Password** | Your GHL login password | (for browser automation only) |

### How to Get Your GHL API Key

1. Log into GoHighLevel
2. Go to **Settings** (gear icon, bottom left)
3. Click **Business Profile**
4. Scroll down to **API Key**
5. Copy the key

### How to Get Your Location ID

1. Log into GoHighLevel
2. Look at the URL bar
3. The Location ID is the string after `/location/` and before the next `/`
4. Example: `app.gohighlevel.com/v2/location/`**`abc123def456`**`/dashboard`

---

## Google Chat Toolkit Requirements

**Component:** `toolkits/google-chat-toolkit/` + `skills/google-chat/`

### Software

| Tool | Required? | Purpose | Install |
|------|-----------|---------|---------|
| Node.js | REQUIRED | Runs gws CLI | [nodejs.org](https://nodejs.org/) |
| gws CLI | REQUIRED (auto-installed by setup.sh) | Google Workspace CLI | `npm install -g @googleworkspace/cli` |
| gcloud CLI | Optional | Automated GCP project setup | `brew install --cask google-cloud-sdk` |
| Python 3 | Optional | JSON parsing in test.sh | `brew install python3` |

### Account

| Account | Cost | Important Note |
|---------|------|----------------|
| **Google Workspace** | $7.20/mo+ (Business Starter) | **Personal Gmail does NOT work.** Must be a Workspace account. |
| **Google Cloud Platform** | Free tier | Only needs OAuth credentials + Chat API enabled |

### GCP Setup (One-Time, ~10 minutes)

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Create a new project (or use existing)
3. Enable the **Google Chat API**:
   - Go to APIs & Services > Library
   - Search "Google Chat API"
   - Click Enable
4. Create **OAuth Desktop App** credentials:
   - Go to APIs & Services > Credentials
   - Click "Create Credentials" > "OAuth client ID"
   - Application type: **Desktop app**
   - Download the `client_secret.json` file
5. Place the file:
   ```bash
   mkdir -p ~/.config/gws/
   mv ~/Downloads/client_secret*.json ~/.config/gws/client_secret.json
   ```
6. Authenticate:
   ```bash
   gws auth login --scopes chat,gmail,calendar,drive
   ```

### Team Sharing

The `client_secret.json` file identifies the GCP project, not the user. It's safe to share within your team. Each person runs `gws auth login` to generate their own per-user credentials.

---

## Server Setup Requirements

**Component:** `skills/server-setup/` + `agents/server-setup.md`

This is the most dependency-heavy component. Only install if you need automated agent infrastructure.

### Software (Local Mac)

| Tool | Required? | Install |
|------|-----------|---------|
| Homebrew | REQUIRED (macOS) | [brew.sh](https://brew.sh/) |
| Node.js | REQUIRED | `brew install node` |
| Python 3 | REQUIRED | `brew install python3` |
| AWS CLI | REQUIRED | `brew install awscli` |
| Claude Code | REQUIRED | `npm install -g @anthropic-ai/claude-code` |
| Tailscale | REQUIRED | `brew install --cask tailscale` |
| GitHub CLI | REQUIRED | `brew install gh` |
| jq | REQUIRED | `brew install jq` |
| SSH | REQUIRED | Pre-installed |

### Quick Install (macOS)

```bash
# Install all server-setup dependencies at once
brew install node python3 awscli gh jq
brew install --cask tailscale
npm install -g @anthropic-ai/claude-code
```

### Accounts

| Account | Cost | Purpose | Sign Up |
|---------|------|---------|---------|
| **AWS** | ~$30/mo (t3.medium) | EC2 server hosting | [aws.amazon.com](https://aws.amazon.com/) |
| **Supabase** | Free tier | Agent database (5 tables) | [supabase.com](https://supabase.com/) |
| **Tailscale** | Free (personal) | Secure mesh VPN to server | [tailscale.com](https://tailscale.com/) |
| **Telegram** | Free | Optional: mobile agent control bot | [telegram.org](https://telegram.org/) |

### AWS Setup (Before Running Server-Setup)

1. **Create an AWS account** at [aws.amazon.com](https://aws.amazon.com/)
2. **Enable billing** (required for EC2)
3. **Create an IAM user** with programmatic access:
   - Go to IAM > Users > Add user
   - Attach policy: `AmazonEC2FullAccess`
   - Save the Access Key ID and Secret Access Key
4. **Configure AWS CLI** locally:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, Region (e.g., ap-southeast-2), Output format (json)
   ```
5. **Verify:**
   ```bash
   aws sts get-caller-identity
   ```

### Supabase Setup (Before Running Server-Setup)

1. Create a project at [supabase.com](https://supabase.com/)
2. Go to **Settings > API**
3. Note down:
   - **Project URL** (`https://YOUR_PROJECT.supabase.co`)
   - **anon public** key
   - **service_role** key (keep secret)

### Credentials Summary

| Credential | Where It Goes | Source |
|------------|--------------|--------|
| AWS Access Key ID | `aws configure` | IAM console |
| AWS Secret Access Key | `aws configure` | IAM console |
| Supabase URL | `secrets.env` on server | Project Settings > API |
| Supabase anon key | `secrets.env` on server | Project Settings > API |
| Supabase service key | `secrets.env` on server | Project Settings > API |
| Tailscale auth key | Interactive login | Tailscale admin console |
| Telegram bot token | `secrets.env` on server | @BotFather on Telegram |
| Telegram chat ID | `secrets.env` on server | Send `/start` to your bot, check updates API |
| SSH key pair | `~/.ssh/claude-agent-key.pem` | Auto-generated by server-setup |

---

## Claude Dispatch Requirements

**Component:** `skills/claude-dispatch/`

### Software

| Tool | Version | Purpose |
|------|---------|---------|
| Claude Code | v2.1.51+ | Remote Control (`claude remote-control`) |
| Claude Desktop | Latest | Dispatch (QR-code setup via Cowork) |
| Claude Mobile App | Latest (iOS/Android) | Phone control interface |

### Account

| Requirement | Details |
|-------------|---------|
| **Claude Pro or Max subscription** | **Mandatory.** API keys are NOT supported for Dispatch or Remote Control. |
| Full-scope login token | Run `/login` in Claude Code if you get auth errors |

### Important Notes

- Desktop computer must **stay awake** during Dispatch/Remote Control sessions
- Enable "Prevent Sleep" in Dispatch setup or adjust power settings
- If on a Team/Enterprise plan, admin must enable Remote Control in Claude Code admin settings

---

## Skill Creator Requirements

**Component:** `skills/skill-creator/`

| Tool | Required? | Purpose |
|------|-----------|---------|
| Python 3 | REQUIRED | Runs init_skill.py, quick_validate.py, package_skill.py |
| Claude Code | REQUIRED | Skill execution environment |

No accounts or credentials needed.

---

## Network and Firewall

### Domains That Must Be Accessible

| Domain | Component | Purpose |
|--------|-----------|---------|
| `services.leadconnectorhq.com` | GHL Toolkit | GHL public API |
| `app.gohighlevel.com` | GHL Browser | GHL web UI |
| `backend.leadconnectorhq.com` | GHL Browser | GHL internal API |
| `console.cloud.google.com` | Google Chat | GCP setup |
| `accounts.google.com` | Google Chat, GHL | OAuth flows |
| `api.telegram.org` | Server Setup | Telegram bot API |
| `*.supabase.co` | Server Setup | Database API |
| `tailscale.com` | Server Setup | VPN mesh |
| `claude.ai` | Dispatch | Remote Control sessions |
| `aws.amazon.com` | Server Setup | AWS console |
| `deb.nodesource.com` | Server Setup | Node.js packages (on server) |
| `raw.githubusercontent.com` | Server Setup | Homebrew install script |

### Ports (EC2 Server Only)

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH access |
| 8080 | TCP | Webhook endpoint |

### Local Machine

- Standard outbound HTTPS (port 443) must be open
- No inbound ports required on your local machine
- VPN/proxy must allow connections to the domains listed above

---

## Cost Summary

### Minimum (Core Kit Only)

| Item | Cost |
|------|------|
| Claude Pro subscription | $20 USD/mo |
| **Total** | **$20 USD/mo** |

### With GHL Toolkit

| Item | Cost |
|------|------|
| Claude Pro or Max | $20-$100 USD/mo |
| GoHighLevel sub-account | $25 USD/mo (via Selr AI) |
| **Total** | **$45-$125 USD/mo** |

### With Google Chat

| Item | Cost |
|------|------|
| Claude Pro or Max | $20-$100 USD/mo |
| Google Workspace | $7.20 USD/mo+ |
| GCP (Chat API) | Free tier |
| **Total** | **$27-$107 USD/mo** |

### Full Stack (Everything)

| Item | Cost |
|------|------|
| Claude Max | $100 USD/mo |
| GoHighLevel | $25 USD/mo |
| Google Workspace | $7.20 USD/mo |
| AWS EC2 (t3.medium) | ~$30 USD/mo |
| Supabase | Free |
| Tailscale | Free |
| **Total** | **~$162 USD/mo** |

---

## Pre-Install Verification

Run these commands before `bash install.sh` to verify you're ready:

```bash
# Core checks
node --version          # Should show v18+
git --version           # Should show 2.30+
claude --version        # Should show 2.0+
ls ~/.claude/           # Should exist

# GHL Toolkit (if using)
curl --version          # Should be installed

# Google Chat (if using)
# After gws install:
gws --version           # Should show version
gws auth status         # Should show authenticated

# Server Setup (if using, macOS)
brew --version          # Should be installed
aws --version           # Should show aws-cli/2.x
tailscale version       # Should show version
gh --version            # Should show gh version
jq --version            # Should show jq-1.x
python3 --version       # Should show 3.x
```

Or just run the health dashboard — it checks everything for you:

```bash
bash status.sh
```

---

*This document is part of the Selr AI Internal Kit.*
*Last updated: 2026-04-02*
