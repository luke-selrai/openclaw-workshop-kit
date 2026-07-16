# install-render-windows.ps1
# Installs (or upgrades) the Render CLI on Windows. Idempotent.
# Tries winget first, falls back to scoop, then to a direct GitHub release zip.
# Designed for Windows PowerShell 5.1 - no && / || / ternary / -AsHashtable.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$MinVersion = [version]'2.10.0'

function Write-Step { param([string]$Message) Write-Host "[render-install] $Message" }
function Write-Err  { param([string]$Message) Write-Host "[render-install] ERROR: $Message" -ForegroundColor Red }

function Get-InstalledRenderVersion {
    # Return [version] of installed render, or $null if not installed / not parseable.
    $cmd = Get-Command render -ErrorAction SilentlyContinue
    if ($null -eq $cmd) { return $null }
    try {
        $raw = & render --version 2>$null
    } catch {
        return $null
    }
    if (-not $raw) { return $null }
    $match = [regex]::Match($raw, '\d+\.\d+\.\d+')
    if (-not $match.Success) { return $null }
    try {
        return [version]$match.Value
    } catch {
        return $null
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-ViaWinget {
    Write-Step "Trying winget install Render.RenderCLI..."
    # --accept-source-agreements/--accept-package-agreements prevent prompts.
    $wingetArgs = @(
        'install', '--id', 'Render.RenderCLI',
        '--silent',
        '--accept-source-agreements',
        '--accept-package-agreements'
    )
    & winget @wingetArgs | Out-Host
    $wingetCode = $LASTEXITCODE

    if ($wingetCode -ne 0) {
        Write-Step "winget exit code $wingetCode - attempting upgrade in case it is already installed..."
        & winget upgrade --id Render.RenderCLI --silent --accept-source-agreements --accept-package-agreements *> $null
    }

    # Whatever winget says, the real test is whether `render` is now callable.
    # Refresh PATH in this session before checking.
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"

    if (Get-Command render -ErrorAction SilentlyContinue) {
        return $true
    }
    Write-Step "winget did not actually place render on PATH - falling through."
    return $false
}

function Install-ViaScoop {
    Write-Step "Trying scoop install render..."
    if (-not (Test-CommandExists 'scoop')) {
        Write-Step "scoop is not installed - skipping scoop path."
        return $false
    }
    & scoop install render | Out-Host
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
    if ($LASTEXITCODE -eq 0 -and (Get-Command render -ErrorAction SilentlyContinue)) { return $true }
    Write-Step "scoop exit code $LASTEXITCODE - attempting scoop update..."
    & scoop update render | Out-Host
    if ($LASTEXITCODE -eq 0 -and (Get-Command render -ErrorAction SilentlyContinue)) { return $true }
    return $false
}

function Install-ViaGithubRelease {
    Write-Step "Falling back to direct GitHub release download..."
    $apiUrl = 'https://api.github.com/repos/render-oss/cli/releases/latest'
    try {
        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing -Headers @{ 'User-Agent' = 'render-deployment-skill' }
    } catch {
        Write-Err "Could not reach GitHub API: $($_.Exception.Message)"
        return $false
    }

    $asset = $release.assets | Where-Object { $_.name -match 'windows.*amd64.*\.zip$' } | Select-Object -First 1
    if ($null -eq $asset) {
        Write-Err "No windows_amd64 zip in the latest GitHub release."
        return $false
    }

    $tempZip = Join-Path $env:TEMP "render-cli-$($release.tag_name).zip"
    $tempDir = Join-Path $env:TEMP "render-cli-$($release.tag_name)"
    Write-Step "Downloading $($asset.browser_download_url)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -UseBasicParsing

    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

    # Render's release ships the binary under various names across versions:
    # 'render.exe' (older), 'cli.exe' (mid), 'cli_v2.17.0.exe' (current).
    # Match any .exe whose name starts with 'render' or 'cli', then rename to
    # 'render.exe' when we copy so the user always has 'render' on PATH.
    $exe = Get-ChildItem -Path $tempDir -Recurse -File -Filter '*.exe' |
        Where-Object { $_.Name -match '^(render|cli)([._-]|\.exe$)' } |
        Select-Object -First 1
    if ($null -eq $exe) {
        $allExes = (Get-ChildItem -Path $tempDir -Recurse -Filter '*.exe' | ForEach-Object { $_.Name }) -join ', '
        Write-Err "No render/cli .exe inside the release zip. Found: $allExes"
        return $false
    }
    Write-Step "Found $($exe.Name) inside the release zip."

    $binDir = Join-Path $env:USERPROFILE 'bin'
    if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Path $binDir | Out-Null }
    Copy-Item -Path $exe.FullName -Destination (Join-Path $binDir 'render.exe') -Force

    # Add %USERPROFILE%\bin to the user PATH if not already there.
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $userPath) { $userPath = '' }
    if (-not ($userPath -split ';' | Where-Object { $_ -eq $binDir })) {
        Write-Step "Adding $binDir to user PATH..."
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $binDir } else { "$userPath;$binDir" }
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = "$env:Path;$binDir"
    }

    return $true
}

# --- main --------------------------------------------------------------------

$existing = Get-InstalledRenderVersion
if ($null -ne $existing) {
    Write-Step "Existing Render CLI version: $existing"
    if ($existing -ge $MinVersion) {
        Write-Step "Version $existing meets minimum $MinVersion - nothing to do."
        & render --version
        exit 0
    }
    Write-Step "Version $existing is below required $MinVersion - upgrading..."
}

$installed = $false

# Cast to [bool] defensively in case a function leaks native-command output
# into its return pipeline (PowerShell collects all uncaptured output as the
# function result, which can turn a $false into a truthy array).
if (Test-CommandExists 'winget') {
    $result = Install-ViaWinget
    $installed = [bool]($result | Select-Object -Last 1)
} else {
    Write-Step "winget is not on this machine - skipping."
}

if (-not $installed) {
    $result = Install-ViaScoop
    $installed = [bool]($result | Select-Object -Last 1)
}

if (-not $installed) {
    $result = Install-ViaGithubRelease
    $installed = [bool]($result | Select-Object -Last 1)
}

if (-not $installed) {
    Write-Err "All install paths failed (winget, scoop, GitHub release)."
    Write-Err "Open a browser, download the latest release from https://github.com/render-oss/cli/releases, extract render.exe to %USERPROFILE%\bin, and add that folder to PATH."
    exit 1
}

# Re-detect (refresh PATH in current session).
$machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath    = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath"

$final = Get-InstalledRenderVersion
if ($null -eq $final) {
    Write-Err "render CLI is still not on PATH. Close this terminal and open a new one, then re-run."
    exit 1
}

Write-Step "Installed Render CLI version: $final"
if ($final -lt $MinVersion) {
    Write-Err "Installed version $final is still below required $MinVersion."
    Write-Err "Try: winget upgrade Render.RenderCLI"
    exit 1
}

Write-Step "Render CLI is ready."
& render --version
