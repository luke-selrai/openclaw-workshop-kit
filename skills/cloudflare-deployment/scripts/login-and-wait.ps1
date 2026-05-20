# login-and-wait.ps1
# Trigger `wrangler login` and poll the wrangler config dir until credentials land.
# Times out at 120 seconds.

$ErrorActionPreference = 'Stop'

$configPaths = @(
    "$env:USERPROFILE\.wrangler\config\default.toml",
    "$env:APPDATA\.wrangler\config\default.toml",
    "$env:USERPROFILE\.config\.wrangler\config\default.toml"
)

# If already authenticated, skip
$whoami = & wrangler whoami 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Output "Already authenticated to Cloudflare."
    Write-Output $whoami
    exit 0
}

Write-Output "Opening Cloudflare OAuth in your browser. Click Allow to approve, then come back here..."

# Start wrangler login as a background job
$job = Start-Job -ScriptBlock { & wrangler login }

$elapsed = 0
$interval = 2
$timeout = 120

while ($elapsed -lt $timeout) {
    foreach ($path in $configPaths) {
        if (Test-Path $path) {
            $check = & wrangler whoami 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Output "Authentication complete."
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -ErrorAction SilentlyContinue
                Write-Output $check
                exit 0
            }
        }
    }
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Output "Login timed out after $timeout seconds."
Stop-Job $job -ErrorAction SilentlyContinue
Remove-Job $job -ErrorAction SilentlyContinue
Write-Output "Run this skill again, or use the Playwright fallback path."
exit 1
