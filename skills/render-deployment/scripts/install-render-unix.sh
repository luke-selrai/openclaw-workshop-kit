#!/usr/bin/env bash
# install-render-unix.sh
# Installs (or upgrades) the Render CLI on macOS / Linux. Idempotent.
# - macOS:  Homebrew tap render-oss/render
# - Linux:  official curl installer (https://render.com/install.sh)
# Re-running is safe: existing installs are upgraded in place.

set -euo pipefail

MIN_VERSION="2.10.0"

log() { printf '[render-install] %s\n' "$*"; }
err() { printf '[render-install] ERROR: %s\n' "$*" >&2; }

# --- version helpers ---------------------------------------------------------

# Print the installed render CLI version (just the bare semver, no prefix) or
# nothing if not installed.
get_installed_version() {
  if ! command -v render >/dev/null 2>&1; then
    return 0
  fi
  # `render --version` typically prints "render version v2.10.3" or similar.
  # Grab the first semver-looking token.
  render --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true
}

# Returns 0 if $1 >= $2 (semver compare), 1 otherwise.
version_ge() {
  # sort -V puts the smaller version first; if $2 sorts first, $1 >= $2.
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# --- OS-specific install -----------------------------------------------------

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is not installed. Install it from https://brew.sh and re-run this script."
    exit 1
  fi

  log "Tapping render-oss/render (idempotent)..."
  brew tap render-oss/render >/dev/null

  if brew list --formula 2>/dev/null | grep -q '^render$'; then
    log "Render CLI already installed via brew - upgrading if newer..."
    brew upgrade render || true
  else
    log "Installing Render CLI via brew..."
    brew install render
  fi
}

install_linux() {
  log "Running the official Render installer (curl https://render.com/install.sh)..."
  # The installer is idempotent - it replaces the existing binary.
  curl -fsSL https://render.com/install.sh | sh
}

# --- main --------------------------------------------------------------------

OS="$(uname -s)"
log "Detected OS: $OS"

INSTALLED_VERSION="$(get_installed_version || true)"

if [ -n "$INSTALLED_VERSION" ]; then
  log "Existing Render CLI version: $INSTALLED_VERSION"
  if version_ge "$INSTALLED_VERSION" "$MIN_VERSION"; then
    log "Version $INSTALLED_VERSION meets minimum $MIN_VERSION - nothing to do."
    render --version
    exit 0
  fi
  log "Version $INSTALLED_VERSION is below required $MIN_VERSION - upgrading..."
fi

case "$OS" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *)
    err "Unsupported OS: $OS. This script handles macOS and Linux only."
    err "For Windows use scripts/install-render-windows.ps1."
    exit 1
    ;;
esac

# Re-detect and verify.
NEW_VERSION="$(get_installed_version || true)"
if [ -z "$NEW_VERSION" ]; then
  err "render CLI is still not on PATH after install. Open a new terminal and re-run, or check the install logs above."
  exit 1
fi

log "Installed Render CLI version: $NEW_VERSION"
if ! version_ge "$NEW_VERSION" "$MIN_VERSION"; then
  err "Installed version $NEW_VERSION is still below required $MIN_VERSION."
  err "Try: brew upgrade render  (macOS) or re-run the curl installer (Linux)."
  exit 1
fi

log "Render CLI is ready."
render --version
