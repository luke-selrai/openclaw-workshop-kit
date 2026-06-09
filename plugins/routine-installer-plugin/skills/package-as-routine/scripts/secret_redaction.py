#!/usr/bin/env python3
"""Shared redaction helpers so the resolution/mcp-bundle pipeline never prints
real credential values into the model's chat context.

The pipeline keeps REAL values on disk (in the scratch folder, gitignored) via
each script's --out flag. What gets written to STDOUT — which the agent reads
into context and may echo to the user — is masked by default.

Masking preserves a length signal (`<redacted:N chars>`) so the agent can still
reason about and narrate the structure without ever seeing the secret.
"""

REDACTION_MARKER = "<redacted:"


def maskValue(value):
    """Mask a single string value, preserving its character-length signal.

    Non-strings and empty strings pass through unchanged (nothing to leak)."""
    if not isinstance(value, str) or value == "":
        return value
    return f"{REDACTION_MARKER}{len(value)} chars>"


def looksRedacted(value):
    """True if a string value has already been masked by maskValue."""
    return isinstance(value, str) and value.startswith(REDACTION_MARKER)


def redactResolution(resolution):
    """Return a deep-ish copy of a resolution with every MCP header value
    masked. Header values are the only secret-bearing fields in the resolution
    shape; connector names, paths and flags are safe."""
    redacted = dict(resolution)
    servers = []
    for server in resolution.get("mcp_servers", []):
        s = dict(server)
        if "headers" in s and isinstance(s["headers"], dict):
            s["headers"] = {k: maskValue(v) for k, v in s["headers"].items()}
        if "env" in s and isinstance(s["env"], dict):
            s["env"] = {k: maskValue(v) for k, v in s["env"].items()}
        servers.append(s)
    redacted["mcp_servers"] = servers
    return redacted


def redactMcpBundle(bundle):
    """Return a copy of a generate_mcp_json bundle with every env_var `value`
    masked. The `mcp_json` portion is already placeholder-only (no secrets) and
    is left intact so the agent can write `.mcp.json` from stdout if it wants."""
    redacted = dict(bundle)
    envVars = []
    for record in bundle.get("env_vars", []):
        r = dict(record)
        if "value" in r:
            r["value"] = maskValue(r["value"])
        envVars.append(r)
    redacted["env_vars"] = envVars
    return redacted
