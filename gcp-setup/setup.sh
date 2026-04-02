#!/bin/bash
# Claude AI Business Assistant — GCP Server Setup
# Built by Selr AI — selrai.com.au

# ------------------------------------------------
# MAC: Remove Gatekeeper quarantine first
# ------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
    xattr -d com.apple.quarantine "$0" 2>/dev/null || true
    chmod +x "$0" 2>/dev/null || true
fi

set -uo pipefail

echo "================================================"
echo "  Claude AI Business Assistant — GCP Setup"
echo "  Built by Selr AI — selrai.com.au"
echo "================================================"
echo ""

# ------------------------------------------------
# STEP 1 — Check gcloud is installed and signed in
# ------------------------------------------------
echo "[1/8] Checking Google Cloud CLI..."
echo ""

if ! command -v gcloud &>/dev/null; then
    echo "  Google Cloud CLI is not installed."
    echo "  Install it from: https://cloud.google.com/sdk/docs/install"
    echo "  Then run this script again."
    echo ""
    exit 1
fi

GCLOUD_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -z "$GCLOUD_ACCOUNT" ]; then
    echo "  You are not signed in to Google Cloud."
    echo "  Run this command first:  gcloud auth login"
    echo "  Then run this script again."
    echo ""
    exit 1
fi

echo "  Google Cloud CLI found."
echo "  Signed in as: $GCLOUD_ACCOUNT"
echo ""

# ------------------------------------------------
# QUESTION 1 — GCP Project
# ------------------------------------------------
echo "  Your existing GCP projects:"
echo ""

mapfile -t PROJECT_IDS < <(gcloud projects list --format="value(projectId)" 2>/dev/null)
mapfile -t PROJECT_NAMES < <(gcloud projects list --format="value(name)" 2>/dev/null)

for i in "${!PROJECT_IDS[@]}"; do
    printf "  %2d. %-40s %s\n" "$((i+1))" "${PROJECT_IDS[$i]}" "${PROJECT_NAMES[$i]}"
done
echo ""

while true; do
    read -rp "  Which project? Enter the number, or NEW to create one: " PROJECT_CHOICE
    if [ "$PROJECT_CHOICE" = "NEW" ] || [ "$PROJECT_CHOICE" = "new" ]; then
        read -rp "  What would you like to call the new project? " NEW_PROJECT_NAME
        NEW_PROJECT_ID=$(echo "$NEW_PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-28)
        echo "  Creating project: $NEW_PROJECT_ID..."
        if ! gcloud projects create "$NEW_PROJECT_ID" --name="$NEW_PROJECT_NAME" 2>&1; then
            echo "  Project creation failed. Check the name and try again."
            exit 1
        fi
        PROJECT="$NEW_PROJECT_ID"
        break
    elif [[ "$PROJECT_CHOICE" =~ ^[0-9]+$ ]] && \
         [ "$PROJECT_CHOICE" -ge 1 ] && \
         [ "$PROJECT_CHOICE" -le "${#PROJECT_IDS[@]}" ]; then
        PROJECT="${PROJECT_IDS[$((PROJECT_CHOICE-1))]}"
        break
    else
        echo "  Please enter a number between 1 and ${#PROJECT_IDS[@]}, or NEW."
    fi
done
echo "  Using project: $PROJECT"
echo ""

# ------------------------------------------------
# QUESTION 2 — Region
# ------------------------------------------------
echo "  Which region is closest to you?"
echo ""
echo "  1. Australia (Sydney)  — australia-southeast1"
echo "  2. USA (Iowa)          — us-central1"
echo "  3. USA (Virginia)      — us-east1"
echo "  4. Europe (Belgium)    — europe-west1"
echo "  5. Asia (Singapore)    — asia-southeast1"
echo "  6. Other — I will type it myself"
echo ""

while true; do
    read -rp "  Enter number (1-6): " REGION_CHOICE
    case $REGION_CHOICE in
        1) REGION="australia-southeast1"; break ;;
        2) REGION="us-central1"; break ;;
        3) REGION="us-east1"; break ;;
        4) REGION="europe-west1"; break ;;
        5) REGION="asia-southeast1"; break ;;
        6) read -rp "  Type your region: " REGION; break ;;
        *) echo "  Please enter a number between 1 and 6." ;;
    esac
done

ZONE=$(gcloud compute zones list --filter="region:$REGION" --format="value(name)" 2>/dev/null | head -1)
if [ -z "$ZONE" ]; then
    echo "  Could not find a zone in region '$REGION'. Check the name and try again."
    exit 1
fi
echo "  Using region: $REGION (zone: $ZONE)"
echo ""

# ------------------------------------------------
# QUESTION 3 — Messaging platform
# ------------------------------------------------
echo "  Which messaging app would you like to use?"
echo ""
echo "  1. Telegram (recommended — easiest to set up)"
echo "  2. Discord"
echo "  3. WhatsApp"
echo "  4. iMessage (Mac only)"
echo ""

while true; do
    read -rp "  Enter number (1-4): " PLATFORM_CHOICE
    case $PLATFORM_CHOICE in
        1) PLATFORM="telegram"; break ;;
        2) PLATFORM="discord"; break ;;
        3) PLATFORM="whatsapp"; break ;;
        4) PLATFORM="imessage"; break ;;
        *) echo "  Please enter a number between 1 and 4." ;;
    esac
done

BOT_TOKEN=""
case $PLATFORM in
    telegram)
        echo ""
        echo "  You need a Telegram bot token."
        echo "  Open Telegram → search @BotFather → send /newbot → copy the token."
        echo ""
        read -rp "  Paste your bot token: " BOT_TOKEN
        ;;
    discord)
        echo ""
        echo "  You need a Discord bot token."
        echo "  Go to discord.com/developers → New Application → Bot → Reset Token."
        echo ""
        read -rp "  Paste your bot token: " BOT_TOKEN
        ;;
    whatsapp)
        echo ""
        echo "  You need a WhatsApp Business API token."
        echo "  Get it from developers.facebook.com (Meta Business account required)."
        echo ""
        read -rp "  Paste your API token: " BOT_TOKEN
        ;;
    imessage)
        echo "  No token needed for iMessage."
        ;;
esac
echo ""

# ------------------------------------------------
# STEP 2 — Create the VM
# ------------------------------------------------
echo "[2/8] Creating your server..."
echo ""

VM_NAME="claude-assistant"
EXISTING=$(gcloud compute instances list --project="$PROJECT" --filter="name=$VM_NAME" --format="value(name)" 2>/dev/null)
if [ -n "$EXISTING" ]; then
    VM_NAME="claude-assistant-v2"
    echo "  'claude-assistant' already exists — using 'claude-assistant-v2'."
fi

if ! gcloud compute instances create "$VM_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --machine-type=e2-standard-2 \
    --image-family=ubuntu-2404-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-standard \
    2>&1; then
    echo ""
    echo "  VM creation failed. Common causes:"
    echo "  - Billing not enabled on this project (visit console.cloud.google.com)"
    echo "  - Quota exceeded for this region (try a different region)"
    exit 1
fi

VM_IP=$(gcloud compute instances describe "$VM_NAME" \
    --project="$PROJECT" --zone="$ZONE" \
    --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)

echo ""
echo "  Server created: $VM_NAME — IP: $VM_IP"
echo "  Waiting 20 seconds for it to boot..."
sleep 20

echo "  Testing SSH..."
SSH_ATTEMPTS=0
until gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="echo OK" --quiet 2>/dev/null; do
    SSH_ATTEMPTS=$((SSH_ATTEMPTS + 1))
    if [ $SSH_ATTEMPTS -ge 4 ]; then
        echo "  SSH not responding after 4 attempts. Check the VM in GCP Console."
        exit 1
    fi
    echo "  Not ready yet — waiting 10 more seconds..."
    sleep 10
done
echo "  SSH working."
echo ""

# ------------------------------------------------
# STEP 3 — Install everything on the server
# ------------------------------------------------
echo "[3/8] Installing software on your server..."
echo "  This takes 3-5 minutes — normal."
echo ""

gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" -- bash -s << 'INSTALL'
set -e

echo "  [3a] Adding 4GB swap space..."
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile > /dev/null
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null

echo "  [3b] Installing system tools..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git ffmpeg python3 python3-pip build-essential unzip 2>&1 | tail -2

echo "  [3c] Installing Node.js v22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null
sudo apt-get install -y nodejs 2>&1 | tail -2
node --version

echo "  [3d] Installing Bun..."
curl -fsSL https://bun.sh/install | bash 2>/dev/null
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

echo "  [3e] Installing Whisper and downloading tiny voice model..."
pip3 install openai-whisper --quiet --break-system-packages
python3 -c "import whisper; whisper.load_model('tiny')" 2>/dev/null
echo "       Voice model ready."

echo "  [3f] Installing Claude Code..."
curl -fsSL https://claude.ai/install.sh -o /tmp/install.sh
bash /tmp/install.sh 2>/dev/null
echo "  All software installed."
INSTALL

echo ""

# ------------------------------------------------
# STEP 4 — Set up workspace
# ------------------------------------------------
echo "[4/8] Setting up assistant workspace..."
echo ""

gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" -- bash -s << 'WORKSPACE'
set -e

echo "  [4a] Cloning workshop kit..."
git clone https://github.com/luke-selrai/openclaw-workshop-kit.git ~/workshop-kit 2>&1 | tail -1

echo "  [4b] Copying assistant files and skills..."
mkdir -p ~/my-assistant
cp ~/workshop-kit/my-assistant/CLAUDE.md ~/my-assistant/CLAUDE.md
mkdir -p ~/.claude/skills
cp -r ~/workshop-kit/skills/*/ ~/.claude/skills/ 2>/dev/null || true

echo "  [4c] Marking workspace as trusted..."
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser('~/.claude.json')
with open(path) as f:
    d = json.load(f)
d['hasCompletedOnboarding'] = True
d['lastOnboardingVersion'] = 100
d['theme'] = 'dark'
if 'projects' not in d:
    d['projects'] = {}
home = os.path.expanduser('~')
d['projects'][home + '/my-assistant'] = {
    'allowedTools': [], 'mcpContextUris': [], 'mcpServers': {},
    'enabledMcpjsonServers': [], 'disabledMcpjsonServers': [],
    'hasTrustDialogAccepted': True, 'projectOnboardingSeenCount': 1,
    'hasClaudeMdExternalIncludesApproved': True,
    'hasClaudeMdExternalIncludesWarningShown': True
}
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
print('  Workspace trusted.')
PYEOF
WORKSPACE

echo ""

# ------------------------------------------------
# STEP 5 — Create service files
# ------------------------------------------------
echo "[5/8] Creating background service files..."
echo ""

# Write PTY wrapper locally with platform substituted, then copy to server
cat > /tmp/start-claude.sh << EOF
#!/usr/bin/env python3
import pty, os

def read(fd):
    return os.read(fd, 1024)

pty.spawn(
    [os.path.expanduser("~/.local/bin/claude"), "--channels", "plugin:${PLATFORM}@claude-plugins-official"],
    master_read=read
)
EOF

gcloud compute scp /tmp/start-claude.sh "$VM_NAME:~/start-claude.sh" \
    --project="$PROJECT" --zone="$ZONE" --quiet
gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="chmod +x ~/start-claude.sh"

# Write systemd service file over SSH
REMOTE_USER=$(gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="echo \$USER" --quiet 2>/dev/null)

cat > /tmp/claude-assistant.service << EOF
[Unit]
Description=Claude AI Assistant
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/my-assistant
Environment=PATH=/home/${REMOTE_USER}/.local/bin:/home/${REMOTE_USER}/.bun/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=%h
Environment=WHISPER_CACHE_DIR=%h/.cache/whisper
ExecStart=/usr/bin/python3 /home/${REMOTE_USER}/start-claude.sh
Restart=on-failure
RestartSec=10
StandardOutput=append:%h/claude-assistant.log
StandardError=append:%h/claude-assistant.log

[Install]
WantedBy=default.target
EOF

gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="mkdir -p ~/.config/systemd/user" --quiet
gcloud compute scp /tmp/claude-assistant.service \
    "$VM_NAME:~/.config/systemd/user/claude-assistant.service" \
    --project="$PROJECT" --zone="$ZONE" --quiet

echo "  Service files created."
echo ""

# ------------------------------------------------
# STEP 6 — Manual: sign in, install plugin, pair
# ------------------------------------------------
echo "[6/8] ACTION REQUIRED — Sign in and set up your messaging plugin"
echo "================================================================"
echo ""
echo "  Open a NEW terminal window on your laptop and run:"
echo ""
echo "  gcloud compute ssh $VM_NAME --project=$PROJECT --zone=$ZONE"
echo ""
echo "  ── STEP A: Sign in to Claude ──────────────────────────────"
echo "  On the server, run:"
echo ""
echo "    cd ~/my-assistant && claude ."
echo ""
echo "  When prompted, press 1 (I have a Claude subscription)."
echo "  A URL will appear — open it in your browser, sign in, come back."
echo ""
echo "  ── STEP B: Install the $PLATFORM plugin ───────────────────"
echo "  Inside Claude, type:"
echo ""
echo "    /plugins"
echo ""
echo "  Find '$PLATFORM' in the list and install it. Then type /exit."
echo ""
echo "  ── STEP C: Configure token and pair ───────────────────────"
echo "  Back in the server terminal, run:"
echo ""
echo "    claude . --channels plugin:${PLATFORM}@claude-plugins-official"
echo ""
if [ -n "$BOT_TOKEN" ]; then
    echo "  Inside Claude, type these one at a time:"
    echo ""
    case $PLATFORM in
        telegram)
            echo "    /telegram:configure $BOT_TOKEN"
            echo ""
            echo "  Then open Telegram, find your bot, send any message."
            echo "  Your bot will reply with a 6-character code. Then type:"
            echo ""
            echo "    /telegram:access pair <the-code>"
            echo "    /telegram:access policy allowlist"
            ;;
        discord)
            echo "    /discord:configure $BOT_TOKEN"
            echo ""
            echo "  Then follow the pairing instructions shown by Claude."
            ;;
        whatsapp)
            echo "    /whatsapp:configure $BOT_TOKEN"
            echo ""
            echo "  Then follow the pairing instructions shown by Claude."
            ;;
    esac
    echo ""
    echo "  When done, type:  /exit"
fi
echo ""
echo "================================================================"
echo ""
read -rp "  Press Enter when you have completed all steps above..."
echo ""

# ------------------------------------------------
# STEP 7 — Start the service
# ------------------------------------------------
echo "[7/8] Starting your assistant as a 24/7 background service..."
echo ""

gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" -- bash -s << 'STARTSERVICE'
set -e
loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable claude-assistant
systemctl --user start claude-assistant
echo "  Service started."
STARTSERVICE

echo "  Waiting 15 seconds..."
sleep 15
echo ""

# ------------------------------------------------
# STEP 8 — Verify
# ------------------------------------------------
echo "[8/8] Checking service status..."
echo ""

STATUS=$(gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="systemctl --user is-active claude-assistant 2>/dev/null" --quiet 2>/dev/null)

if [ "$STATUS" = "active" ]; then
    echo "  Service: running"
else
    echo "  Service: $STATUS (may still be starting)"
fi

LOG_OUTPUT=$(gcloud compute ssh "$VM_NAME" --project="$PROJECT" --zone="$ZONE" \
    --command="tail -5 ~/claude-assistant.log 2>/dev/null || echo '(log not yet available)'" --quiet 2>/dev/null)

echo "  Last log lines:"
echo "$LOG_OUTPUT" | sed 's/^/    /'
echo ""

if echo "$LOG_OUTPUT" | grep -q "plugin not installed"; then
    echo "  WARNING: Plugin not installed correctly."
    echo "  SSH back into the server and repeat Step B (install plugin via /plugins)."
    echo "  Then run: systemctl --user restart claude-assistant"
elif echo "$LOG_OUTPUT" | grep -q "Listening for channel messages"; then
    echo "  Confirmed: assistant is listening for messages."
fi

echo ""
echo "================================================"
echo "  Setup complete!"
echo ""
echo "  Server:   $VM_NAME"
echo "  IP:       $VM_IP"
echo "  Platform: $PLATFORM"
echo ""
echo "  Open $PLATFORM, find your bot, and send:"
echo "    hello"
echo ""
echo "  Your assistant will introduce itself and ask"
echo "  7 questions to learn about your business."
echo ""
echo "  Monthly cost estimate: ~AUD 49-61/month"
echo "  Stop the VM to save costs when not in use:"
echo "  gcloud compute instances stop $VM_NAME \\"
echo "    --project=$PROJECT --zone=$ZONE"
echo "================================================"
