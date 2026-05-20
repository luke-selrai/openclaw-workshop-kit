# install-wrangler.ps1
# Install Wrangler globally on Windows. Falls back to npx if global install fails.

$ErrorActionPreference = 'Stop'

# Skip if already installed
$wrangler = Get-Command wrangler -ErrorAction SilentlyContinue
if ($wrangler) {
    $version = & wrangler --version 2>&1 | Select-Object -First 1
    Write-Output "Wrangler is already installed: $version"
    exit 0
}

Write-Output "Installing Wrangler globally..."
$npmInstall = & npm install -g wrangler 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Output "Wrangler installed globally."
} else {
    Write-Output "Global install failed. Will use 'npx wrangler' going forward."
    $stateDir = "$env:USERPROFILE\.claude\state"
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    '{"wrangler_mode":"npx"}' | Out-File -FilePath "$stateDir\cloudflare-wrangler-mode.json" -Encoding utf8
    # Verify npx can resolve it
    $npxTest = & npx --yes wrangler --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Output "npx wrangler is reachable."
        exit 0
    } else {
        Write-Output "npx wrangler also failed. Run PowerShell as administrator, or fix your npm prefix."
        exit 1
    }
}

# Optional: install preview unified CLI
Write-Output "Attempting optional install of @cloudflare/cf (preview unified CLI)..."
try { & npm install -g '@cloudflare/cf' 2>$null } catch { Write-Output "(@cloudflare/cf not available — skipping. This is optional.)" }

# Verify
& wrangler --version
