#!/usr/bin/env bash
# Install Claude Code <-> Codex skill sync for the current user.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SCRIPT="$SKILL_DIR/scripts/sync-codex-skills"
BIN_DIR="$HOME/bin"
BIN_SCRIPT="$BIN_DIR/sync-codex-skills"
PLIST_LABEL="com.local.claude-codex-skill-sync"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "install: missing $SOURCE_SCRIPT" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$HOME/.claude/skills" "$HOME/.codex/skills"
cp "$SOURCE_SCRIPT" "$BIN_SCRIPT"
chmod 700 "$BIN_SCRIPT"

"$BIN_SCRIPT"

if [ "$(uname -s 2>/dev/null || true)" = "Darwin" ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WatchPaths</key>
    <array>
        <string>$HOME/.claude/skills</string>
        <string>$HOME/.codex/skills</string>
    </array>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>/tmp/claude-codex-skill-sync.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-codex-skill-sync.log</string>
</dict>
</plist>
PLIST
  launchctl load "$PLIST_PATH" >/dev/null 2>&1 || true
  echo "install: LaunchAgent installed at $PLIST_PATH"
else
  echo "install: non-macOS system detected, LaunchAgent skipped"
fi

echo "install: sync installed at $BIN_SCRIPT"

