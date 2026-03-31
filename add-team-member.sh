#!/bin/bash
# Usage: sudo ./add-team-member.sh <username> <telegram-bot-token>
#
# Fully automated setup. Admin-only — new user never needs to SSH.
# After running this script, two steps remain:
#   1. Share the Claude login URL with the user (printed at the end)
#   2. Once they message their Telegram bot, run: sudo ./pair-user.sh <username> <code>

set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <telegram-bot-token>}"
BOT_TOKEN="${2:?Usage: $0 <username> <telegram-bot-token>}"
HOME_DIR="/home/$USERNAME"

# ── 1. Create Linux user ────────────────────────────────────────────────────
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists. Skipping user creation."
else
    echo "Creating user: $USERNAME"
    useradd -m -s /bin/bash "$USERNAME"
    # Lock password — access is via sudo su only (gcloud environment)
    passwd -l "$USERNAME"
fi

# ── 2. Workspace ────────────────────────────────────────────────────────────
echo "Setting up workspace..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/my-assistant/memory"
cp /opt/workshop-kit/my-assistant/CLAUDE.md "$HOME_DIR/my-assistant/CLAUDE.md"
cp /opt/workshop-kit/my-assistant/memory/USER.md "$HOME_DIR/my-assistant/memory/USER.md" 2>/dev/null || true
cp /opt/workshop-kit/my-assistant/memory/SETUP.md "$HOME_DIR/my-assistant/memory/SETUP.md" 2>/dev/null || true
cp /opt/workshop-kit/my-assistant/memory/MEMORY.md "$HOME_DIR/my-assistant/memory/MEMORY.md" 2>/dev/null || true

# ── 3. Skills symlink ───────────────────────────────────────────────────────
echo "Linking skills..."
sudo -u "$USERNAME" mkdir -p "$HOME_DIR/.claude"
ln -sf /opt/workshop-kit/skills "$HOME_DIR/.claude/skills"

# ── 4. Copy Telegram plugin (no /plugin install needed) ─────────────────────
echo "Copying Telegram plugin..."
PLUGIN_SRC=$(find /home -name "installed_plugins.json" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
if [ -n "$PLUGIN_SRC" ] && [ -d "$PLUGIN_SRC/cache/claude-plugins-official/telegram" ]; then
    PLUGIN_VERSION=$(ls "$PLUGIN_SRC/cache/claude-plugins-official/telegram/" | sort -V | tail -1)
    PLUGIN_CACHE_DST="$HOME_DIR/.claude/plugins/cache/claude-plugins-official/telegram/$PLUGIN_VERSION"
    mkdir -p "$PLUGIN_CACHE_DST"
    cp -r "$PLUGIN_SRC/cache/claude-plugins-official/telegram/$PLUGIN_VERSION/." "$PLUGIN_CACHE_DST/"
    # Write installed_plugins.json for the new user
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
    echo "  Plugin copied (v$PLUGIN_VERSION)"
else
    echo "  WARNING: Could not find installed plugin to copy. User will need to run /plugin install manually."
fi

# ── 5. settings.json ────────────────────────────────────────────────────────
echo "Writing settings.json..."
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

# ── 6. Telegram bot token + access policy ───────────────────────────────────
echo "Configuring Telegram bot..."
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
echo "Creating PTY wrapper..."
cat > "$HOME_DIR/start-claude.sh" << 'WRAPPER'
#!/usr/bin/env python3
"""
PTY wrapper for Claude Code daemon.
Allocates a pseudo-terminal (required) and auto-accepts the workspace
trust dialog by sending Enter (Yes is pre-selected by default).
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
echo "Creating systemd service..."
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

[Install]
WantedBy=default.target
SYSTEMD

# ── 9. Fix ownership + enable linger ───────────────────────────────────────
chown -R "$USERNAME:$USERNAME" "$HOME_DIR"
loginctl enable-linger "$USERNAME"

# ── 10. Claude login — run as user, capture the auth URL ───────────────────
echo ""
echo "Launching claude login for $USERNAME..."
echo "(A URL will appear below — copy it and send it to the user)"
echo "──────────────────────────────────────────────────────────"
sudo -u "$USERNAME" HOME="$HOME_DIR" claude login 2>&1 || true
echo "──────────────────────────────────────────────────────────"

# ── 11. Start the service ───────────────────────────────────────────────────
echo ""
echo "Starting claude-assistant service..."
sudo -u "$USERNAME" XDG_RUNTIME_DIR=/run/user/$(id -u "$USERNAME") \
    systemctl --user enable --now claude-assistant 2>/dev/null && \
    echo "Service started." || echo "WARNING: Could not start service. Run manually after user logs in."

echo ""
echo "=========================================="
echo "  Setup complete for: $USERNAME"
echo "=========================================="
echo ""
echo "Remaining steps:"
echo "  1. Send the login URL above to $USERNAME — they click it once"
echo "  2. Ask them to message their Telegram bot — they'll get a 6-digit code"
echo "  3. Run: sudo /opt/workshop-kit/pair-user.sh $USERNAME <code>"
echo ""
