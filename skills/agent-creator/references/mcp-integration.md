# MCP Integration (pointer)

**For building an MCP server, use the `mcp-creator` skill.** It owns secure, production-ready MCP server development (schema design, error handling, transports, testing). This file is only the thin slice agent-creator needs: how to give an *existing* MCP server to a subagent.

## Give a subagent access to an MCP server

Two ways in the subagent's frontmatter `mcpServers` field:

```yaml
---
name: browser-tester
description: Tests features in a real browser. Use for end-to-end UI checks.
mcpServers:
  # Reference an already-configured server by name
  - github
  # Or define one inline - connected only while this subagent runs
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
---

Use the Playwright tools to navigate, screenshot, and interact with pages.
```

- **By name** - reuses a server already configured in the session (shares its connection).
- **Inline** - connected when the subagent starts, disconnected when it finishes. Defining it inline here (rather than in `.mcp.json`) keeps its tool descriptions out of the main conversation's context.

Inline definitions use the same schema as `.mcp.json` entries (`stdio`, `http`, `sse`, `ws`).

## When does an agent need an MCP server at all?

Only when it must reach something outside the filesystem and shell - a SaaS API, a database over a driver, a browser, a ticketing system. If the work is reading/searching/editing files or running commands, the built-in tools are enough - don't build an MCP server for it.

If you do need one: hand off to **mcp-creator** to build it, then come back here to wire it into the agent via `mcpServers`.

## Quick test of a server

```bash
npx @modelcontextprotocol/inspector
```

Use the inspector UI to send tool calls and verify responses before wiring the server into an agent.
