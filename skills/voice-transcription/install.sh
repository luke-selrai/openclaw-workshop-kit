#!/usr/bin/env bash
# install.sh — provision whisper.cpp + the cloudkit-transcribe wrapper.
#
# Idempotent. Designed for Ubuntu/Debian (apt-based). Runs the build as the
# `cloudkit` OS user when present (server install) or the calling user when
# not (laptop install).
#
# Usage:
#   sudo ./install.sh                       # base.en model, default
#   sudo ./install.sh --model small.en      # better accuracy, ~470 MB model
#   sudo ./install.sh --model tiny.en       # smaller/faster, less accurate
#   ./install.sh --dry-run                  # show actions, no changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
MODEL="base.en"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)   MODEL="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) sed -n '2,/^$/p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: $*"; else echo "+ $*"; "$@"; fi
}

# Pick which user owns the build. Prefer cloudkit (server install); fall back to invoking user.
if id cloudkit >/dev/null 2>&1; then
  BUILD_USER=cloudkit
  BUILD_GROUP=cloudkit
else
  BUILD_USER="${SUDO_USER:-$USER}"
  BUILD_GROUP="$(id -gn "$BUILD_USER")"
fi
echo "── Build will run as: $BUILD_USER:$BUILD_GROUP ──"

# ── 1. Install dependencies ────────────────────────────────────────────────
echo "── apt: build-essential cmake ffmpeg git ──"
if [[ $DRY_RUN -eq 0 && "$EUID" -ne 0 ]]; then
  echo "ERROR: real install needs root. Re-run with sudo (or pass --dry-run)." >&2
  exit 2
fi
run apt-get update -qq
run apt-get install -y -qq build-essential cmake ffmpeg git

# ── 2. Clone whisper.cpp into /opt ────────────────────────────────────────
WHISPER_DIR=/opt/whisper.cpp
echo "── Clone $WHISPER_DIR ──"
run install -d -o "$BUILD_USER" -g "$BUILD_GROUP" -m 0755 "$WHISPER_DIR"

if [[ -d "$WHISPER_DIR/.git" ]]; then
  echo "  whisper.cpp already cloned"
else
  run sudo -u "$BUILD_USER" git clone --depth=1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
fi

# ── 3. Build (cmake; ARM-NEON / x86-AVX auto-detected) ────────────────────
echo "── Build whisper.cpp ──"
WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
if [[ -x "$WHISPER_BIN" ]]; then
  echo "  whisper-cli already built at $WHISPER_BIN"
else
  run sudo -u "$BUILD_USER" cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DCMAKE_BUILD_TYPE=Release
  run sudo -u "$BUILD_USER" cmake --build "$WHISPER_DIR/build" -j --config Release
fi

# ── 4. Download model ──────────────────────────────────────────────────────
MODEL_FILE="$WHISPER_DIR/models/ggml-${MODEL}.bin"
echo "── Download model: $MODEL ($MODEL_FILE) ──"
run install -d -o "$BUILD_USER" -g "$BUILD_GROUP" -m 0755 "$WHISPER_DIR/models"

if [[ -f "$MODEL_FILE" ]]; then
  echo "  model already present ($(du -h "$MODEL_FILE" | cut -f1))"
else
  run sudo -u "$BUILD_USER" curl -L --progress-bar \
    -o "$MODEL_FILE" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
fi

# ── 5. Install the cloudkit-transcribe wrapper ──────────────────────────────
WRAPPER_SRC="$SCRIPT_DIR/cloudkit-transcribe"
WRAPPER_DST=/usr/local/bin/cloudkit-transcribe

echo "── Install wrapper: $WRAPPER_DST ──"
[[ -f "$WRAPPER_SRC" ]] || { echo "ERROR: $WRAPPER_SRC missing" >&2; exit 2; }
run install -m 0755 "$WRAPPER_SRC" "$WRAPPER_DST"

# ── 6. Smoke test ──────────────────────────────────────────────────────────
echo ""
echo "── Smoke test: 2-second sine wave ──"
if [[ $DRY_RUN -eq 0 ]]; then
  ffmpeg -loglevel error -y -f lavfi -i "sine=f=440:d=2" -ar 16000 -ac 1 /tmp/cloudkit-smoke.wav
  RESULT=$("$WRAPPER_DST" /tmp/cloudkit-smoke.wav 2>&1 || true)
  echo "  whisper output: '$RESULT'"
  rm -f /tmp/cloudkit-smoke.wav
fi

cat <<EOF

── Done ──
Binary:   $WHISPER_BIN
Model:    $MODEL_FILE
Wrapper:  $WRAPPER_DST
Default:  ggml-${MODEL}.bin

Use it:
  cloudkit-transcribe /path/to/audio.ogg
  WHISPER_MODEL=small.en cloudkit-transcribe /path/to/audio.ogg

Add another model later:
  sudo bash $SCRIPT_DIR/install.sh --model small.en
EOF
