#!/usr/bin/env bash
# verify.sh
# Read-only verification: prints account, KV namespaces, R2 buckets.

set -e

echo "===== wrangler whoami ====="
wrangler whoami
echo ""
echo "===== KV namespaces ====="
wrangler kv namespace list 2>&1 || echo "(no namespaces or KV not enabled)"
echo ""
echo "===== R2 buckets ====="
wrangler r2 bucket list 2>&1 || echo "(no buckets or R2 not enabled)"
echo ""
echo "===== D1 databases ====="
wrangler d1 list 2>&1 || echo "(no databases or D1 not enabled)"
