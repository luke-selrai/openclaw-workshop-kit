# install-node-windows.ps1
# Install Node.js 22 LTS on Windows via winget. Idempotent.

$ErrorActionPreference = 'Stop'

# Detect existing Node
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $version = (& node --version) -replace 'v',''
    $major = [int]($version -split '\.')[0]
    if ($major -ge 20) {
        Write-Output "Node.js v$version is already installed. Skipping."
        exit 0
    }
}

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

# Verify
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    Write-Output "Installed Node.js version: $(& node --version)"
    Write-Output "Installed npm version: $(& npm --version)"
} else {
    Write-Output "Node.js installed, but the terminal needs a restart to find it. Close this terminal and open a new one."
    exit 2
}
