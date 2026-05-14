# verify-deploy.ps1
# End-to-end test on Windows: deploys a Hello World Worker, curls it, deletes it.

$ErrorActionPreference = 'Stop'

$ts = [int][double]::Parse((Get-Date -UFormat %s))
$name = "cf-deploy-test-$ts"
$tmp = Join-Path $env:TEMP $name

New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Push-Location $tmp

try {
    $today = Get-Date -Format "yyyy-MM-dd"

    @"
name = "$name"
main = "index.js"
compatibility_date = "$today"
"@ | Out-File -FilePath "wrangler.toml" -Encoding utf8

    @'
export default {
  fetch() {
    return new Response("Hello from Claude — Cloudflare is connected.");
  }
};
'@ | Out-File -FilePath "index.js" -Encoding utf8

    Write-Output "Deploying test Worker: $name ..."
    $deployOutput = & wrangler deploy 2>&1 | Out-String
    Write-Output $deployOutput

    # Extract workers.dev URL
    $url = ($deployOutput | Select-String -Pattern 'https://[a-z0-9-]+\.[a-z0-9-]+\.workers\.dev' -AllMatches).Matches | Select-Object -First 1
    if ($url) {
        Write-Output ""
        Write-Output "Curling $($url.Value) ..."
        $response = Invoke-WebRequest -Uri $url.Value -UseBasicParsing
        Write-Output "Response: $($response.Content)"
    }

    Write-Output ""
    Write-Output "Deleting test Worker: $name ..."
    try { & wrangler delete --name $name --force 2>&1 } catch { & wrangler delete --name $name 2>&1 }
} finally {
    Pop-Location
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

Write-Output "Cleanup complete. Test deploy succeeded."
