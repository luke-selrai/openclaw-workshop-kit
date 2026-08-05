#!/usr/bin/env bash
# install-netlify-unix.sh
# Install Node.js (if missing) + Netlify CLI on macOS or Linux. Idempotent.

set -eo pipefail

# --- Step 1: Node.js >= 20 ---
NODE_OK=0
if command -v node >/dev/null 2>&1; then
  CURRENT=$(node --version | sed 's/v//' | cut -d. -f1)
  if [ "$CURRENT" -ge 20 ]; then
    echo "Node.js $(node --version) is already installed. Skipping Node install."
    NODE_OK=1
  fi
fi

if [ "$NODE_OK" -eq 0 ]; then
  OS="$(uname -s)"
  if [ "$OS" = "Darwin" ]; then
    # macOS — prefer Homebrew
    if command -v brew >/dev/null 2>&1; then
      echo "Installing Node.js 22 via Homebrew..."
      brew install node@22
      brew link --overwrite --force node@22 || true
      export PATH="$(brew --prefix node@22)/bin:$PATH"
    else
      echo "Homebrew not found. Falling back to nvm..."
      if ! command -v nvm >/dev/null 2>&1; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      fi
      nvm install 22 && nvm use 22 && nvm alias default 22
    fi
  elif [ "$OS" = "Linux" ]; then
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
      nvm install 22 && nvm use 22 && nvm alias default 22
    fi
  else
    echo "Unsupported OS: $OS. Please install Node.js 22+ manually from https://nodejs.org"
    exit 1
  fi
  echo "Installed Node.js version: $(node --version)"
fi

# --- Step 2: Netlify CLI ---
if command -v netlify >/dev/null 2>&1; then
  echo "Netlify CLI is already installed: $(netlify --version 2>&1 | head -n1)"
  exit 0
fi

echo "Installing Netlify CLI globally (this can take a minute or two)..."
if npm install -g netlify-cli 2>&1 | tail -n 5; then
  :
else
  echo "Global install failed (likely a permission issue). Verifying 'npx netlify' as fallback..."
  if npx --yes netlify-cli --version >/dev/null 2>&1; then
    echo "npx netlify-cli is reachable. Use 'npx netlify' in place of 'netlify'."
    exit 0
  else
    echo "npx netlify-cli also failed. Try 'sudo npm install -g netlify-cli' or fix your npm prefix."
    exit 1
  fi
fi

# --- Step 3: Verify ---
if command -v netlify >/dev/null 2>&1; then
  echo "Installed: $(netlify --version 2>&1 | head -n1)"
else
  echo "Netlify CLI installed, but the shell needs a restart to find it. Open a new terminal."
  exit 2
fi
