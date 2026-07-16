#!/usr/bin/env bash
# install-cli.sh — Install ant CLI + Anthropic SDKs. Idempotent.
set -euo pipefail

echo "[install] Checking Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "[install] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "[install] Checking ant CLI..."
if ! command -v ant >/dev/null 2>&1; then
  echo "[install] Installing ant CLI via Homebrew tap..."
  brew tap anthropics/tap
  brew install anthropics/tap/ant
  # Strip macOS quarantine on the binary
  ANT_BIN="$(brew --prefix)/bin/ant"
  if [ -f "$ANT_BIN" ]; then
    xattr -d com.apple.quarantine "$ANT_BIN" 2>/dev/null || true
  fi
else
  echo "[install] ant already installed: $(ant --version 2>&1 | head -1)"
fi

echo "[install] Checking Python 3..."
if ! command -v python3 >/dev/null 2>&1; then
  brew install python3
fi

echo "[install] Installing Anthropic Python SDK..."
# PEP-668 / Homebrew Python marks the environment externally-managed, so a bare
# `pip install --user` exits non-zero and would trip `set -e` and abort the whole
# install. Guard it: try --user, then pipx, then --break-system-packages, and
# never let a failure kill the script (print a plain-English hint instead).
if python3 -m pip install --user --upgrade anthropic >/dev/null 2>&1; then
  :
elif command -v pipx >/dev/null 2>&1 && pipx install anthropic >/dev/null 2>&1; then
  :
elif python3 -m pip install --user --break-system-packages --upgrade anthropic >/dev/null 2>&1; then
  :
else
  echo "[install] WARN: Could not auto-install the Anthropic Python SDK."
  echo "[install]       Your Python is likely 'externally managed' (Homebrew / PEP-668)."
  echo "[install]       Install it by hand in a venv, e.g.:"
  echo "[install]         python3 -m venv ~/.anthropic-venv && ~/.anthropic-venv/bin/pip install anthropic"
fi

echo "[install] Checking Node.js..."
if ! command -v node >/dev/null 2>&1; then
  brew install node
fi

echo "[install] Installing Anthropic TypeScript SDK (global, optional)..."
npm install -g @anthropic-ai/sdk >/dev/null 2>&1 || echo "[install] TS SDK install skipped (non-fatal)."

echo "[install] Checking jq..."
command -v jq >/dev/null 2>&1 || brew install jq

echo "[install] Setting ANTHROPIC_API_KEY from keychain if available..."
# Pick the RC file by the user's actual login shell ($SHELL), not by which file
# happens to exist — writing zsh autoload into ~/.bashrc (or vice versa) silently
# never loads. Default to ~/.zshrc (macOS default shell) when $SHELL is unknown.
case "$SHELL" in
  */zsh) SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
  *) SHELL_RC="$HOME/.zshrc" ;;
esac

if security find-generic-password -a "$USER" -s "anthropic-managed-agents" -w >/dev/null 2>&1; then
  KEY=$(security find-generic-password -a "$USER" -s "anthropic-managed-agents" -w)
  if ! grep -q "anthropic-managed-agents" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" <<RC

# Anthropic Managed Agents — injected by managed-agents-setup skill
if command -v security >/dev/null 2>&1; then
  export ANTHROPIC_API_KEY="\$(security find-generic-password -a \"\$USER\" -s anthropic-managed-agents -w 2>/dev/null)"
fi
RC
    echo "[install] Added key loader to $SHELL_RC"
  fi
  export ANTHROPIC_API_KEY="$KEY"
else
  echo "[install] WARN: No key in keychain. Set one with:"
  echo "  security add-generic-password -a \"\$USER\" -s \"anthropic-managed-agents\" -w \"sk-ant-...\" -U"
fi

echo "[install] Versions:"
ant --version 2>&1 | head -1 || true
python3 -c "import anthropic; print('anthropic-python', anthropic.__version__)" 2>/dev/null || true
npm list -g --depth=0 2>/dev/null | grep "@anthropic-ai/sdk" || true
echo "[install] Done."
