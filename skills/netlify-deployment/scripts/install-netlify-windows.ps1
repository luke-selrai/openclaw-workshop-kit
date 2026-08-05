# install-netlify-windows.ps1
# Install Node.js (if missing) + Netlify CLI on Windows. Idempotent.

$ErrorActionPreference = 'Stop'

# --- Step 1: Node.js >= 20 ---
$node = Get-Command node -ErrorAction SilentlyContinue
$nodeOk = $false
if ($node) {
    $version = (& node --version) -replace 'v',''
    $major = [int]($version -split '\.')[0]
    if ($major -ge 20) {
        Write-Output "Node.js v$version is already installed. Skipping Node install."
        $nodeOk = $true
    }
}

if (-not $nodeOk) {
    # Try winget first
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Output "Installing Node.js 22 LTS via winget..."
        winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Output "winget install failed. Trying direct MSI download..."
            $msiUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
            $msiPath = "$env:TEMP\nodejs-22.msi"
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
            Start-Process msiexec.exe -Wait -ArgumentList "/i $msiPath /quiet /norestart"
            Remove-Item $msiPath -Force
        }
    } else {
        Write-Output "winget not available. Downloading Node.js MSI directly..."
        $msiUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
        $msiPath = "$env:TEMP\nodejs-22.msi"
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
        Start-Process msiexec.exe -Wait -ArgumentList "/i $msiPath /quiet /norestart"
        Remove-Item $msiPath -Force
    }

    # Refresh PATH for the current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    $node = Get-Command node -ErrorAction SilentlyContinue
    if (-not $node) {
        Write-Output "Node.js installed, but the terminal needs a restart to find it. Close this terminal and open a new one, then re-run this script."
        exit 2
    }
    Write-Output "Installed Node.js version: $(& node --version)"
}

# --- Step 2: Netlify CLI ---
$netlify = Get-Command netlify -ErrorAction SilentlyContinue
if ($netlify) {
    $version = & netlify --version 2>&1 | Select-Object -First 1
    Write-Output "Netlify CLI is already installed: $version"
    exit 0
}

Write-Output "Installing Netlify CLI globally (this can take a minute or two)..."
# Route through cmd so npm's stderr warnings can't trip $ErrorActionPreference='Stop'
# (npm deprecation warnings go to stderr; under Stop that's a fatal NativeCommandError in PS 5.1)
& cmd /c "npm install -g netlify-cli 2>&1" | Select-Object -Last 5
if ($LASTEXITCODE -ne 0) {
    Write-Output "Global install failed. Verifying 'npx netlify' as fallback..."
    $npxTest = & cmd /c "npx --yes netlify-cli --version 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Output "npx netlify-cli is reachable. Use 'npx netlify' in place of 'netlify'."
        exit 0
    } else {
        Write-Output "npx netlify-cli also failed. Run PowerShell as administrator, or fix your npm prefix."
        exit 1
    }
}

# Refresh PATH so the new shim resolves in this session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# --- Step 3: Verify ---
$netlify = Get-Command netlify -ErrorAction SilentlyContinue
if ($netlify) {
    Write-Output "Installed: $(& netlify --version 2>&1 | Select-Object -First 1)"
} else {
    Write-Output "Netlify CLI installed, but the terminal needs a restart to find it. Close this terminal and open a new one."
    exit 2
}
