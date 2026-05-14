# verify.ps1
# Read-only verification: prints account, KV namespaces, R2 buckets, D1 dbs.

$ErrorActionPreference = 'Continue'

Write-Output "===== wrangler whoami ====="
& wrangler whoami
Write-Output ""
Write-Output "===== KV namespaces ====="
& wrangler kv namespace list
Write-Output ""
Write-Output "===== R2 buckets ====="
& wrangler r2 bucket list
Write-Output ""
Write-Output "===== D1 databases ====="
& wrangler d1 list
