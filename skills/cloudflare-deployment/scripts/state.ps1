# state.ps1
# Read / write the state file at ~/.claude/state/cloudflare-deployment.json
# Usage:
#   . .\state.ps1
#   $s = Read-CfState
#   Write-CfState -State $s
#   Set-CfStateField -Field 'authenticated' -Value $true

$script:CfStatePath = Join-Path $env:USERPROFILE ".claude\state\cloudflare-deployment.json"

function Read-CfState {
    if (-not (Test-Path $script:CfStatePath)) {
        return [PSCustomObject]@{
            version                 = 1
            node_installed          = $false
            wrangler_installed      = $false
            wrangler_version        = $null
            skills_bundle_installed = $false
            authenticated           = $false
            account_id              = $null
            account_email           = $null
            last_verified_at        = $null
            playwright_fallback_used = $false
        }
    }
    return Get-Content $script:CfStatePath -Raw | ConvertFrom-Json
}

function Write-CfState {
    param([Parameter(Mandatory)] $State)
    $dir = Split-Path $script:CfStatePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $State | ConvertTo-Json -Depth 5 | Out-File -FilePath $script:CfStatePath -Encoding utf8
}

function Set-CfStateField {
    param(
        [Parameter(Mandatory)] [string] $Field,
        [Parameter(Mandatory)] $Value
    )
    $s = Read-CfState
    $s.$Field = $Value
    $s.last_verified_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Write-CfState -State $s
}
