#!/bin/bash
# setup-server.sh — Bootstrap a fresh Ubuntu/Debian server for multi-user Claude Code deployment.
#
# This script is run by Claude Code when the admin pastes the Part A prompt from
# MULTI-USER-DEPLOYMENT.md. It is NOT intended to be run directly by the admin.
#
# Idempotent: safe to re-run. Each step checks before acting.
# Does NOT include: claude login (interactive) or /plugin install (done inside Claude Code).

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() { echo -e "\n${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }

# ── 1. System packages ──────────────────────────────────────────────────────
step "Installing system packages: git curl unzip ffmpeg python3-venv python3-pip"
apt-get update -qq
apt-get install -y git curl unzip ffmpeg python3-venv python3-pip

# ── 2. Bun ─────────────────────────────────────────────────────────────────
step "Installing bun (required for Telegram plugin)"
if command -v bun &>/dev/null; then
    echo "  bun already installed at $(command -v bun) — skipping"
else
    curl -fsSL https://bun.sh/install | bash
    # Make bun available system-wide (not just in the current user's PATH)
    if [ -f "$HOME/.bun/bin/bun" ]; then
        cp "$HOME/.bun/bin/bun" /usr/local/bin/bun
        echo "  bun installed and copied to /usr/local/bin/bun"
    else
        warn "bun binary not found at expected location. Check ~/.bun/bin/"
    fi
fi

# ── 3. Swap ─────────────────────────────────────────────────────────────────
step "Setting up 2 GB swap file at /swapfile"
if swapon --show | grep -q '/swapfile'; then
    echo "  Swap already active at /swapfile — skipping"
elif [ -f /swapfile ]; then
    echo "  /swapfile exists but is not active — activating"
    swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
else
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "  2 GB swap created and activated"
fi
free -h | grep -i swap

# ── 4. Clone workshop kit ───────────────────────────────────────────────────
step "Cloning workshop kit to /opt/workshop-kit"
if [ -d /opt/workshop-kit/.git ]; then
    echo "  /opt/workshop-kit already exists — pulling latest"
    git -C /opt/workshop-kit pull
else
    git clone https://github.com/luke-selrai/openclaw-workshop-kit.git /opt/workshop-kit
    echo "  Cloned successfully"
fi
chmod -R 755 /opt/workshop-kit

# ── 5. Shared Python environment ────────────────────────────────────────────
step "Setting up shared Python environment at /opt/shared-env"

if [ ! -d /opt/shared-env ]; then
    python3 -m venv /opt/shared-env
    echo "  Virtual environment created"
else
    echo "  /opt/shared-env already exists — checking packages"
fi

# CPU-only PyTorch first — prevents pulling in ~4 GB of CUDA packages
if /opt/shared-env/bin/python3 -c "import torch" 2>/dev/null; then
    echo "  torch already installed — skipping"
else
    echo "  Installing CPU-only PyTorch..."
    /opt/shared-env/bin/pip install --quiet torch --index-url https://download.pytorch.org/whl/cpu
fi

# openai-whisper and dependencies
if /opt/shared-env/bin/python3 -c "import whisper" 2>/dev/null; then
    echo "  openai-whisper already installed — skipping"
else
    echo "  Installing openai-whisper..."
    /opt/shared-env/bin/pip install --quiet openai-whisper --no-deps
    /opt/shared-env/bin/pip install --quiet numba numpy tiktoken more-itertools tqdm regex --no-cache-dir
fi

# ── 6. Pre-download Whisper tiny model ──────────────────────────────────────
step "Pre-downloading Whisper tiny model"
mkdir -p /opt/shared-env/whisper-models

if [ -f /opt/shared-env/whisper-models/tiny.pt ]; then
    echo "  tiny.pt already exists — skipping download"
else
    echo "  Downloading tiny.pt (~72 MB)..."
    /opt/shared-env/bin/python3 -c "
import whisper
whisper.load_model('tiny', download_root='/opt/shared-env/whisper-models')
print('  Download complete')
"
fi

# Ensure the model file is world-readable (required — non-root users get PermissionError otherwise)
chmod 644 /opt/shared-env/whisper-models/tiny.pt
chmod -R 755 /opt/shared-env
chmod 644 /opt/shared-env/whisper-models/tiny.pt  # re-apply after recursive chmod
echo "  tiny.pt permissions set to 644"

# ── 7. Make onboarding scripts executable ───────────────────────────────────
step "Making onboarding scripts executable"
chmod +x /opt/workshop-kit/add-team-member.sh
chmod +x /opt/workshop-kit/pair-user.sh
echo "  add-team-member.sh and pair-user.sh are now executable"

# ── 8. Status summary ───────────────────────────────────────────────────────
echo ""
echo "=========================================================="
echo "  Server setup complete — status summary"
echo "=========================================================="
echo ""

echo "System packages:"
for pkg in git curl unzip ffmpeg python3 pip3; do
    if command -v $pkg &>/dev/null; then
        echo "  [OK] $pkg — $(command -v $pkg)"
    else
        echo "  [MISSING] $pkg"
    fi
done

echo ""
echo "Bun:"
if command -v bun &>/dev/null; then
    echo "  [OK] bun — $(bun --version)"
else
    echo "  [MISSING] bun not found in PATH"
fi

echo ""
echo "Swap:"
free -h | grep -i swap | awk '{print "  Total: " $2 "  Used: " $3 "  Free: " $4}'

echo ""
echo "Workshop kit:"
if [ -d /opt/workshop-kit/.git ]; then
    echo "  [OK] /opt/workshop-kit ($(git -C /opt/workshop-kit log -1 --format='%h %s'))"
else
    echo "  [MISSING] /opt/workshop-kit"
fi

echo ""
echo "Shared Python environment:"
if /opt/shared-env/bin/python3 -c "import torch, whisper" 2>/dev/null; then
    echo "  [OK] torch + openai-whisper installed"
else
    echo "  [ISSUE] torch or whisper not importable — check /opt/shared-env"
fi

echo ""
echo "Whisper model:"
if [ -f /opt/shared-env/whisper-models/tiny.pt ]; then
    PT_PERMS=$(stat -c "%a" /opt/shared-env/whisper-models/tiny.pt)
    PT_SIZE=$(du -sh /opt/shared-env/whisper-models/tiny.pt | cut -f1)
    echo "  [OK] tiny.pt — ${PT_SIZE}, permissions ${PT_PERMS}"
else
    echo "  [MISSING] /opt/shared-env/whisper-models/tiny.pt"
fi

echo ""
echo "Onboarding scripts:"
for script in add-team-member.sh pair-user.sh; do
    if [ -x /opt/workshop-kit/$script ]; then
        echo "  [OK] /opt/workshop-kit/$script (executable)"
    else
        echo "  [NOT EXECUTABLE] /opt/workshop-kit/$script"
    fi
done

echo ""
echo "Next steps:"
echo "  1. In Claude Code, run: /plugin install telegram@claude-plugins-official"
echo "  2. To add a team member, tell Claude:"
echo "     Run: sudo /opt/workshop-kit/add-team-member.sh <username> \"<bot-token>\""
echo ""
