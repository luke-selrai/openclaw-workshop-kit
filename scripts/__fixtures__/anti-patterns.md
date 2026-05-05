# anti-patterns fixture

Used by scripts/test-anti-patterns.mjs to verify both audit rules fire with
correct line numbers. This file lives under the audit allowlist so the main
audit-skills.mjs --check pass ignores it.

Line 7 should hit Rule A:
The MCP transport returns 401 WWW-Authenticate: Bearer realm="OAuth" with resource_metadata=...

Line 10 should hit Rule B:
Run claude mcp authenticate myserver to bootstrap OAuth.
