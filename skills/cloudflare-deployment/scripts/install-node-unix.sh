#!/usr/bin/env bash
# install-node-unix.sh
# Install Node.js 22 LTS on macOS or Linux. Idempotent.

set -e

# Detect existing Node version
if command -v node >/dev/null 2>&1; then
  CURRENT=$(node --version | sed 's/v//' | cut -d. -f1)
  if [ "$CURRENT" -ge 20 ]; then
    echo "Node.js v$(node --version) is already installed. Skipping."
    exit 0
  fi
fi

OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  # macOS — prefer Homebrew
  if command -v brew >/dev/null 2>&1; then
    echo "Installing Node.js 22 via Homebrew..."
    brew install node@22
    brew link --overwrite node@22 || true
  else
    echo "Homebrew not found. Falling back to nvm..."
    if ! command -v nvm >/dev/null 2>&1; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi
    nvm install 22
    nvm use 22
    nvm alias default 22
  fi
elif [ "$OS" = "Linux" ]; then
  # Linux — use NodeSource setup script
  echo "Installing Node.js 22 via NodeSource..."
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
  elif command -v dnf >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
    sudo dnf install -y nodejs
  elif command -v yum >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
    sudo yum install -y nodejs
  else
    echo "Unsupported Linux package manager. Falling back to nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
    nvm alias default 22
  fi
else
  echo "Unsupported OS: $OS. Please install Node.js 22+ manually from https://nodejs.org"
  exit 1
fi

# Verify
echo "Installed Node.js version: $(node --version)"
echo "Installed npm version: $(npm --version)"
