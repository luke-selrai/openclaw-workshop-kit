#!/usr/bin/env bash
# voice-transcription/install.sh — multi-platform installer for whisper.cpp +
# the voice-transcribe wrapper.
#
# Idempotent. Builds whisper.cpp from source so the binary matches the host
# architecture (ARM-NEON / x86-AVX auto-detected). Downloads a Whisper model
# from Hugging Face. Installs the wrapper at /usr/local/bin/voice-transcribe.
#
# Platforms:
#   macOS  — installs deps via Homebrew, builds into ~/whisper.cpp (no sudo
#            unless writing /usr/local/bin/voice-transcribe needs it on your
#            mac).
#   Linux  — installs deps via apt, builds into /opt/whisper.cpp (needs sudo).
#   Windows — run from WSL2 (Ubuntu); script will detect and use the Linux path.
#
# Usage:
#   ./install.sh                       # macOS
#   sudo ./install.sh                  # Linux
#   sudo ./install.sh --model small.en # better accuracy, ~470 MB
#   ./install.sh --dry-run             # show actions, no changes

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

run() { if [[ $DRY_RUN -eq 1 ]]; then echo "DRY-RUN: $*"; else echo "+ $*"; "$@"; fi; }

# ── Detect platform ──
OS_KIND=""
case "$(uname -s)" in
  Darwin)  OS_KIND="macos" ;;
  Linux)   OS_KIND="linux" ;;
  *) echo "ERROR: unsupported OS $(uname -s). Use macOS or Linux (Windows users: run from WSL2)." >&2; exit 2 ;;
esac
echo "── Platform: $OS_KIND ──"

# ── 1. Install dependencies ────────────────────────────────────────────────
echo "── Installing build dependencies (cmake, ffmpeg, git, C++ compiler) ──"
case "$OS_KIND" in
  macos)
    if ! command -v brew >/dev/null 2>&1; then
      echo "ERROR: Homebrew not found. Install from https://brew.sh first, then re-run." >&2
      exit 2
    fi
    if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
      echo "ERROR: Xcode Command Line Tools not installed."
      echo "       Run: xcode-select --install"
      echo "       Wait for it to finish, then re-run this script."
      exit 2
    fi
    run brew install cmake ffmpeg git || true   # brew install is idempotent (re-installs are no-ops)
    ;;
  linux)
    if [[ $DRY_RUN -eq 0 && "$EUID" -ne 0 ]]; then
      echo "ERROR: real install on Linux needs root. Re-run with sudo (or pass --dry-run)." >&2
      exit 2
    fi
    run apt-get update -qq
    run apt-get install -y -qq build-essential cmake ffmpeg git
    ;;
esac

# ── 2. Pick install location for whisper.cpp ──
# Linux: /opt/whisper.cpp (system-wide, needs root). macOS: ~/whisper.cpp (per-user, no sudo).
case "$OS_KIND" in
  macos) WHISPER_DIR="$HOME/whisper.cpp" ;;
  linux) WHISPER_DIR="/opt/whisper.cpp"  ;;
esac

# ── 3. Clone whisper.cpp ──────────────────────────────────────────────────
echo "── Clone $WHISPER_DIR ──"
if [[ "$OS_KIND" == "linux" ]]; then
  # Build artefacts get owned by SUDO_USER (the operator) so they can rebuild later without sudo
  if [[ -n "${SUDO_USER:-}" ]]; then
    BUILD_USER="$SUDO_USER"
    BUILD_GROUP="$(id -gn "$SUDO_USER")"
  else
    BUILD_USER="$(id -un)"
    BUILD_GROUP="$(id -gn)"
  fi
  run install -d -o "$BUILD_USER" -g "$BUILD_GROUP" -m 0755 "$WHISPER_DIR"
  CLONE_CMD="sudo -u $BUILD_USER git clone --depth=1"
  CMAKE_PREFIX="sudo -u $BUILD_USER"
else
  mkdir -p "$WHISPER_DIR"
  CLONE_CMD="git clone --depth=1"
  CMAKE_PREFIX=""
fi

if [[ -d "$WHISPER_DIR/.git" ]]; then
  echo "  whisper.cpp already cloned"
else
  run $CLONE_CMD https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
fi

# ── 4. Build (cmake; ARM-NEON / x86-AVX auto-detected) ────────────────────
echo "── Build whisper.cpp ──"
WHISPER_BIN="$WHISPER_DIR/build/bin/whisper-cli"
if [[ -x "$WHISPER_BIN" ]]; then
  echo "  whisper-cli already built at $WHISPER_BIN"
else
  run $CMAKE_PREFIX cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DCMAKE_BUILD_TYPE=Release
  run $CMAKE_PREFIX cmake --build "$WHISPER_DIR/build" -j --config Release
fi

# ── 5. Download model ──────────────────────────────────────────────────────
MODEL_FILE="$WHISPER_DIR/models/ggml-${MODEL}.bin"
echo "── Download model: $MODEL ($MODEL_FILE) ──"
if [[ "$OS_KIND" == "linux" ]]; then
  run install -d -o "$BUILD_USER" -g "$BUILD_GROUP" -m 0755 "$WHISPER_DIR/models"
else
  mkdir -p "$WHISPER_DIR/models"
fi

if [[ -f "$MODEL_FILE" ]]; then
  echo "  model already present ($(du -h "$MODEL_FILE" | cut -f1))"
else
  if [[ "$OS_KIND" == "linux" ]]; then
    run sudo -u "$BUILD_USER" curl -L --progress-bar \
      -o "$MODEL_FILE" \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
  else
    run curl -L --progress-bar \
      -o "$MODEL_FILE" \
      "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-${MODEL}.bin"
  fi
fi

# ── 6. Install the voice-transcribe wrapper ────────────────────────────────
WRAPPER_SRC="$SCRIPT_DIR/voice-transcribe"
WRAPPER_DST=/usr/local/bin/voice-transcribe

echo "── Install wrapper: $WRAPPER_DST ──"
[[ -f "$WRAPPER_SRC" ]] || { echo "ERROR: $WRAPPER_SRC missing" >&2; exit 2; }

if [[ -w "$(dirname "$WRAPPER_DST")" ]]; then
  run install -m 0755 "$WRAPPER_SRC" "$WRAPPER_DST"
else
  # /usr/local/bin needs sudo on some macOS configs (especially Apple Silicon when not in /opt/homebrew)
  run sudo install -m 0755 "$WRAPPER_SRC" "$WRAPPER_DST"
fi

# ── 7. Smoke test ──────────────────────────────────────────────────────────
echo ""
echo "── Smoke test: 2-second sine wave ──"
if [[ $DRY_RUN -eq 0 ]]; then
  ffmpeg -loglevel error -y -f lavfi -i "sine=f=440:d=2" -ar 16000 -ac 1 /tmp/voice-smoke.wav
  RESULT=$("$WRAPPER_DST" /tmp/voice-smoke.wav 2>&1 || true)
  echo "  whisper output: '$RESULT'"
  echo "  (descriptive output like '(eerie music)' on a pure tone is normal — not real speech to transcribe)"
  rm -f /tmp/voice-smoke.wav
fi

cat <<EOF

── Done ──
Binary:   $WHISPER_BIN
Model:    $MODEL_FILE
Wrapper:  $WRAPPER_DST
Default:  ggml-${MODEL}.bin

Use it:
  voice-transcribe ~/Downloads/voice-memo.m4a
  voice-transcribe interview.mp3 > transcript.txt
  WHISPER_MODEL=small.en voice-transcribe ~/Downloads/quiet-recording.m4a

Add another model later (multiple coexist; pick at call time with WHISPER_MODEL):
  $([[ "$OS_KIND" == "linux" ]] && echo "sudo " || echo "")bash $SCRIPT_DIR/install.sh --model small.en
EOF
