# Known Issue - Square: Connector Is in Beta

**Status:** Known limitation (upstream)
**Affects:** square-connector
**Symptoms:** Unexpected tool errors, tool name changes between sessions, intermittent auth failures on the real-account path

---

## What Is Happening

The Square MCP server (`mcp.squareup.com`) is Square's **official** connector for Claude Code, but it is currently in **beta**. This means:

- Tool names and parameters can change without notice between Square's server updates
- Intermittent errors may occur on Square's side - these are usually not your connection or your account
- New features (e.g. bookings, disputes) may appear or disappear between updates
- The real-account path (browser sign-in to `mcp.squareup.com`) can occasionally time out or return an auth error even on a valid account

---

## Real Account vs. Sandbox

The connector supports two modes:

| Mode | Data | Setup |
|---|---|---|
| **Real account** | Your actual live Square business data | Browser sign-in to mcp.squareup.com - no token needed |
| **Sandbox** | Fake test data from Square's developer sandbox | Requires a free sandbox token from developer.squareup.com |

For everyday business use, the **real account** path is recommended. The **sandbox** is only useful for testing or workshops where you want to experiment without touching live data. The sandbox defaults to read-only for safety.

---

## Fixing Intermittent Auth Errors (Real Account)

If a tool call returns an auth error on the real-account path:

1. Tell your assistant: *"My Square connection dropped. Please reconnect it."*
2. Your assistant will guide you to sign back in to Square via the browser - this takes about 30 seconds.

The first time you use the connector in a new Claude Code session, Square's server will automatically open a browser sign-in page. This is expected - just sign in and click **Allow**, then come back and tell your assistant you're done.

---

## Fixing Sandbox Token Errors

If the sandbox returns an auth error:

1. The sandbox token may have expired or been deleted from your Square developer account
2. Tell your assistant: *"My Square sandbox key stopped working. Can you walk me through getting a new one?"*
3. Your assistant will guide you to developer.squareup.com to generate a fresh sandbox token

---

## Tool Errors That Look Like Bugs

If a tool returns an unexpected error (not an auth error), try:
1. Retrying the same request once - beta-side blips usually clear on the second attempt
2. If it consistently fails, tell your assistant what you were trying to do - it will find an alternative approach or flag it as a known beta limitation
3. If nothing works after a couple of retries, email Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) with a description of what you asked and what error appeared

---

## Related

- Connector docs: `skills/square-connector/SKILL.md`
- General troubleshooting: `docs/troubleshoot.md`
