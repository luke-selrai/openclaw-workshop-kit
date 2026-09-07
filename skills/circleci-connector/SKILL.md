---
name: circleci-connector
description: "Connect CircleCI to Claude through its official connector, with a Personal API Token fallback. Use when the user asks to set up or connect CircleCI, or wants CircleCI work (pipeline status, build failure logs, flaky tests, artifacts, pipeline runs) and CircleCI isn't connected yet. Once connected, use the CircleCI tools exposed in the calling session."
allowed-tools: mcp__circleci__*, mcp__claude_ai_CircleCI__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Developer Tools & CI/CD
  tags:
    - circleci
    - ci-cd
    - pipelines
    - builds
    - devops
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for diagnosing failing CircleCI builds and flaky tests
    - skill: xero-connector
      reason: Same Personal-Token → ~/.claude.json wrap-existing-tooling pattern for a different first-party MCP server
    - skill: hubspot-connector
      reason: Same single-token conversational-bootstrap shape
---

# CircleCI Connector

Bundled artifacts (offline schema evidence and an illustrative workflow; live access still needs verification):

- [`examples/circleci-failed-builds-session.md`](examples/circleci-failed-builds-session.md), illustrative cold/warm-start and build-failure workflow; not live onboarding evidence.
- [`references/circleci-mcp-shape-snapshot.json`](references/circleci-mcp-shape-snapshot.json), version-scoped offline tool discovery for the legacy npm server; no authenticated-read claim. Drift-check recipe included.
- [`CHANGELOG.md`](CHANGELOG.md), version history.

## Overview

This skill connects CircleCI and uses the actual caller's tools to inspect pipelines, logs, tests, and artifacts. Prefer the official connector in Claude's directory. CircleCI also documents a hosted server at `https://mcp.circleci.com/v1/mcp`, with browser sign-in and a Personal API Token fallback. The older `@circleci/mcp-server-circleci` package is deprecated; preserve a working existing installation, but do not choose it for a fresh connection when the hosted route works. Sources: [CircleCI connection guide](https://circleci.com/docs/guides/toolkit/connecting-to-the-circleci-mcp-server/), [legacy server repository](https://github.com/CircleCI-Public/mcp-server-circleci).

- **Phase 1, Install & Connect.** Claude drives the available setup tools; ask the user only for sign-in or approval input that requires them. Use plain English and never ask them to run commands.
- **Phase 2, Use Tools.** Discover the names and input schemas available in this session. Tool sets differ between hosted, CLI, and legacy npm servers; the reference below is version-scoped, not a promised fixed count.

### Phase 0, Resume in the actual caller

Discover CircleCI tools, including deferred tools, and call an available read such as `list_followed_projects` using its exposed schema. A successful authenticated response for the intended CircleCI account is the resume check; a config entry or Connected badge alone is not enough. Preserve a working route and its credentials.

Desktop connectors can use opaque-ID namespaces. `mcp__circleci__*` and Claude Code's `mcp__claude_ai_CircleCI__*` are examples, not exhaustive names. Desktop's account, terminal `claude auth status`, and CircleCI credentials are independent. Terminal `claude mcp list` does not establish the Desktop account or its callable tools. If both local and built-in tools are exposed, use the working intended-account route; do not assume local precedence hides the Desktop connector.

If no tools are available, inspect the caller's connector settings. For local config checks, parse only whether a matching server and credential are present; never dump `~/.claude.json`, Desktop config, headers, or environment values. Configured but unavailable means reconnect/discover in that host, not immediately create another token. Otherwise run Phase 1.

### Scope of setup

This skill targets CircleCI SaaS. CircleCI Server (self-hosted) requires separately verified server-specific setup. The legacy server's Docker alternative remains outside this skill; do not deploy a network-facing token proxy as a fallback.

---

## Communication rules for Phase 1

The user is a non-technical business owner or team lead. Every message you send during Phase 1 must follow the rules in the installed assistant persona (`~/.claude/selr-assistant.md`):

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, MCP, endpoint, JSON, environment variable, or Personal API Token as a technical concept. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now, this takes just a moment."
- **React warmly.** Good: "That worked, your CircleCI is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1, Install & Connect

### Preferred route, the calling account's connector

1. In **Claude Desktop**, start inside the signed-in app: **+ → Connectors → Browse connectors → CircleCI → Connect** (or **Customize → Connectors → + → Browse connectors**, if that is the visible navigation). Use the official CircleCI listing. Drive these steps when the harness has the necessary UI tools; otherwise give the exact short next click.
2. Complete the actual setup prompts. Any browser handoff must stay bound to that Desktop account: open the exact app-created URL in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended CircleCI identity before approval. Do not substitute an everyday-browser directory URL when it belongs to another Claude account. The listing's availability does not by itself establish its authentication method; follow its actual prompts.
3. If the official listing is unavailable, CircleCI's [documented hosted setup](https://circleci.com/docs/guides/toolkit/connecting-to-the-circleci-mcp-server/) supports **Settings → Connectors → Add custom connector**, URL `https://mcp.circleci.com/v1/mcp`, then browser sign-in. In Claude Code (terminal or its VS Code extension), the harness can register `claude mcp add --transport http circleci https://mcp.circleci.com/v1/mcp`, then use that host's `/mcp` → CircleCI → **Authenticate**. Reuse an existing registration rather than duplicating it. These terminal steps do not configure a different Desktop account.
4. Rediscover tools in the same session and run the Step 5 read below. If app settings show connected but tools are absent, first refresh/discover there; only request a restart if the caller still cannot load them. Retry the read after restart. Do not use a pipeline run as a connection test.

### Personal API Token fallback

Use this when the MCP host cannot complete the supported browser sign-in, or when maintaining a chosen legacy local installation. Claude handles the technical steps and browser actions its tools support. Prefer the hosted server for new PAT connections. The local npm recipe below is retained for existing installations that need it.

### Step 1, Orient the user

Tell the user in one short message:

> "Great, let's connect your CircleCI. I'll walk you through creating a small connection key inside CircleCI, then I'll save it on your computer and check everything is talking. This takes about two minutes."

### Step 2, Walk the user through creating a Personal API Token

Use the intended CircleCI account's authenticated browser session. Drive the token-page steps with available browser tools; ask the user only for input the harness cannot supply. Transfer a newly created token directly into protected configuration without returning it in browser output, narration, or logs. If that is unavailable, use a supported masked secret-input mechanism; do not require a token pasted into chat.

When the user must perform a browser step, give only the next instruction; otherwise perform it and continue:

1. "Please open this page in your browser: **https://app.circleci.com/settings/user/tokens**, and sign in with your CircleCI account. Let me know when you see the tokens page."

2. When they confirm → "Click the **Create New Token** button. A small dialog will appear asking for a name. Tell me when you see it."

3. When they see the dialog → "For the name, type: **Claude Assistant**. Then click **Add API Token**. A long string will appear, that's your key."

4. Capture the value through the protected mechanism above and proceed to Step 3. If a key is already stored and working, reuse it; do not create a duplicate.

**Common mistakes to look out for (and correct by re-asking):**

- The protected input contains a placeholder like `CIRCLECI_TOKEN` or `your_token_here` → ask again: "That looks like an example value. Please enter the real key in the secure input."
- The protected input contains something very short (under 20 characters) → "That value looks incomplete. Please check the secure input."
- The user says *"I can't find Personal API Tokens"* → "No worries, in CircleCI, click your avatar in the bottom-left corner, choose **User Settings**, then **Personal API Tokens** from the left menu. Or go straight to https://app.circleci.com/settings/user/tokens."
- The user says *"It asked me to pick a project"* → "That's the project-level token page, not what we want. We need the personal one, try https://app.circleci.com/settings/user/tokens directly."

### Step 3, Save the credentials

Save into the actual caller's supported configuration. For Claude Code, this is the user-level `mcpServers` entry in `~/.claude.json`. For a new hosted PAT connection, use an HTTP entry with URL `https://mcp.circleci.com/v1/mcp` and `headers.Authorization` set to `Bearer <captured token>`; prefer the host's secret store where supported. Never interpolate the token into visible commands or logs.

For a retained **legacy local npm** route, the structure is below. Claude Desktop uses its own `claude_desktop_config.json` (macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`; Windows: `%APPDATA%\Claude\claude_desktop_config.json`), not Claude Code's `~/.claude.json`. Locate the actual host config before editing.

The legacy structure:

```json
{
  "mcpServers": {
    "circleci": {
      "command": "npx",
      "args": ["-y", "@circleci/mcp-server-circleci@latest"],
      "env": {
        "CIRCLECI_TOKEN": "<token from Step 2>"
      }
    }
  }
}
```

**Rules:**
- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other `mcpServers` entry the user already has.
- If the selected host config does not exist, create it with just the CircleCI entry. Restrict config and backups to owner-only access (mode `0600` on Mac/Linux).
- If the file cannot be parsed as JSON, preserve it and repair its syntax before merging; never replace all existing configuration with only CircleCI. Verify only server/credential presence after saving, without outputting values.
- Never echo the token back to the user after writing it. Never include it in any output visible to the user.

Tell the user in one short message:

> "I've saved your connection details. I'll check whether this conversation can use CircleCI now."

If tools remain unavailable after discovery, explain the one restart needed in Step 4.

### Step 4, Reload the calling host when needed

First rediscover the caller's tools. If they are still unavailable after saving, wait for that host to restart. When they return, tell them: *"Welcome back. Let me just check that everything is talking to CircleCI."*

### Step 5, Verify the connection

Discover and call `list_followed_projects` from the selected CircleCI connection using its actual input schema (legacy 0.20.0 accepts an empty object). If that route exposes a different authenticated project/account read, use it instead. Check tool-level errors as well as transport success. Handle the response:

- **Tool returns one or more projects** → Count them and name the first few. Tell the user:
  > "All done! I can see **[N]** CircleCI projects on your account, including **[project 1]**, **[project 2]**, and **[project 3]**. You can now ask me things like 'what's the status of my latest build on main?', 'why did the last build fail?', or 'list my recent pipelines'. Give it a try!"

- **Tool returns an empty list** → "Your connection is working, but I can't see any projects yet. That usually means you haven't followed any projects in CircleCI. Head to https://app.circleci.com/projects, click the projects you want me to see, and then ask me to try again." Do not treat this as a failure.

- **PAT route returns `401 Unauthorized`** → "Hmm, the connection key didn't work, let me take it again." Check the protected capture and whether the token was revoked; repair the selected host's entry and retry. For the browser-sign-in route, reconnect through the same host instead of requesting a PAT.

- **Tool returns `403 Forbidden`** → verify the intended CircleCI account and project access. Explain the missing permission; do not blindly mint another key.

- **Tool is not yet available** → recheck the actual caller's connector state and deferred tools, then use Step 4 if a reload is needed. Another terminal's successful listing is not evidence for this session.

- **Any other error** → "Something's not quite right, let me try once more." Retry the tool call once. If it still fails, tell the user in plain English what you saw (translated, never raw errors), and ask if they want to retry or stop.

---

## PHASE 2, Use Tools

Once a real read succeeds, use the tools exposed by that connection. The following names were observed in offline `tools/list` from legacy `@circleci/mcp-server-circleci@0.20.0`. Hosted/CLI tools may differ: inspect their current schemas before calling and never invent an absent tool.

**Tool naming convention:** A locally named `circleci` server can expose `mcp__circleci__get_latest_pipeline_status`, etc. Use the actual caller's namespace; built-in and other local registrations may have different prefixes.

### Core read tools

| Tool | Description | Use when |
|---|---|---|
| `list_followed_projects` | Lists the CircleCI projects the user has followed (and that the token has access to) | User asks "what projects am I connected to?" or you need to verify the connection is alive |
| `get_latest_pipeline_status` | Returns the current pipeline state for a given project + branch | User asks about their latest build, current pipeline, or the status of a branch |
| `get_build_failure_logs` | Retrieves detailed failure information from a failed build | User asks "why did the last build fail?", "what's wrong with my build?", or asks about a specific failed job |
| `get_job_test_results` | Extracts test metadata and outcomes for a specific job | User asks about test results, which tests failed, or how many tests ran |
| `list_artifacts` | Shows build outputs (artifacts) from completed jobs | User asks about build outputs, coverage reports, or downloadable artifacts |
| `find_flaky_tests` | Identifies unreliable tests via test history analysis | User asks about flaky tests, intermittent failures, or unreliable tests |
| `find_underused_resource_classes` | Locates jobs with low CPU/RAM utilization | User asks about right-sizing their CircleCI jobs, or cost optimisation |
| `download_usage_api_data` | Retrieves usage metrics from the CircleCI Usage API | User asks about CircleCI credit usage, monthly spend, or usage trends |
| `list_component_versions` | Lists deployment component versions for a project and environment | User asks which component versions were deployed or are live; use returned project, environment, and component IDs |
| `config_helper` | Validates a CircleCI configuration file | User asks to check their `.circleci/config.yml`, or pastes a config for review |

### Write / action tools, **always confirm with the user before calling**

| Tool | Description | Use when |
|---|---|---|
| `run_pipeline` | Triggers a pipeline execution for a given project + branch | User asks to "run a build", "trigger a pipeline", or "kick off CI", **confirm first** |
| `rerun_workflow` | Restarts a workflow from start or from the failure point | User asks to "rerun the last build", "try again", or "retry the failed jobs", **confirm first** |
| `run_rollback_pipeline` | Initiates a rollback pipeline (if the project has one configured) | User asks to roll back a deployment, **confirm first, and double-check they mean it** |

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my CircleCI" / "Help me set up CircleCI" | **Run Phase 1** |
| "What CircleCI projects am I connected to?" | `list_followed_projects` |
| "What's the status of my latest build?" | `get_latest_pipeline_status` |
| "What's the status of [branch]?" | `get_latest_pipeline_status` with branch filter |
| "Why did the last build fail?" | `get_build_failure_logs` |
| "Show me the failure logs for [job]" | `get_build_failure_logs` |
| "Which tests failed?" / "Show me test results" | `get_job_test_results` |
| "Are any of my tests flaky?" / "Find flaky tests" | `find_flaky_tests` |
| "Show me build artifacts" / "Download the build output" | `list_artifacts` |
| "How much CircleCI credit have I used this month?" | `download_usage_api_data` |
| "Am I wasting money on oversized jobs?" / "Right-size my jobs" | `find_underused_resource_classes` |
| "Which versions of this component are deployed?" | `list_component_versions` |
| "Check my CircleCI config" / "Validate my config.yml" | `config_helper` |
| "Run a build on [branch]" / "Trigger a pipeline" | `run_pipeline`, **confirm first** |
| "Rerun the last build" / "Retry failed jobs" | `rerun_workflow`, **confirm first** |
| "Roll back the deployment" | `run_rollback_pipeline`, **confirm first, double-check** |

---

## Error Handling (Phase 2)

When a CircleCI tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say to the user | How to fix |
|---|---|---|
| `401 Unauthorized` / `invalid token` | "Your CircleCI connection key isn't working, let me sort that now." | Reconnect the selected browser-sign-in route, or check protected capture/revocation for a PAT route. Do not switch authentication methods solely because a read failed. |
| `403 Forbidden` | "I don't have permission to do that on your CircleCI account, that's usually because the project isn't followed, or your token doesn't cover it." | Check account, project visibility, and permissions in the chosen route. A replacement key does not grant missing account access. |
| `404 Not Found` on a project | "I can't find that project. Let me show you which ones I can see." | Call `list_followed_projects` and ask the user which one they meant. |
| `404 Not Found` on a pipeline/build | "I couldn't find that build, let me look at the most recent ones." | Call `get_latest_pipeline_status` on the user's current branch and offer those. |
| `429 Rate limited` | "CircleCI is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest waiting a minute. |
| `run_rollback_pipeline` fails with "no rollback configured" | "Your project doesn't have a rollback pipeline set up yet, you'd need to configure one in CircleCI first. Want me to explain how?" | Point the user to CircleCI's rollback pipeline docs; do not try to auto-configure it. |
| CircleCI tools unavailable | "The CircleCI connection is not active in this conversation yet. I'll check it." | Follow Phase 0 and reload the actual caller only if needed. |
| Any other API error | "Something went wrong with CircleCI, let me try again." | Retry once; if still failing, check the token is active. |

---

## Scope Limitations

The legacy 0.20.0 server **can** do the following; other routes must be checked against their exposed tools:

- Read pipeline status, build logs, test results, and artifacts for any project the user's token can access
- Find flaky tests and underused resource classes for optimisation
- Retrieve usage API data for spend monitoring
- Trigger pipeline runs, workflow reruns, and rollback pipelines
- Validate CircleCI config files

The legacy 0.20.0 tool surface does **not expose**:
- **Modify project settings**, no add/remove env vars, no SSH key management, no context management
- **Manage projects**, no follow/unfollow projects, no create/delete projects, no move projects
- **Manage contexts or contexts' secrets**, the MCP surface is read-oriented with trigger actions, not configuration
- **Access CircleCI Server (self-hosted)**, requires a `CIRCLECI_BASE_URL` override not handled in this skill
- **Cancel a running pipeline**, not exposed by the MCP server
- **Approve manual-approval jobs**, not exposed by the MCP server
- **See real-time streaming logs**, logs are fetched on-demand after a job completes

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before triggering a pipeline, rerunning a workflow, or running a rollback**, summarise what you are about to do and wait for the user's OK before calling the tool. Rollbacks especially: repeat the project and environment, and ask "are you sure?"
- **Default to the user's current branch** when they don't specify one. If you don't know the branch, ask or call `list_followed_projects` first and infer.
- **Summarise failure logs**, `get_build_failure_logs` can return a lot of text. Read it, summarise the root cause in 2-3 sentences, and offer to show the full log if the user wants.
- **Present test results clearly**, when showing `get_job_test_results`, group by status (failed, passed, skipped) and highlight failures with file + test name.
- **Pagination**, default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits**, CircleCI enforces rate limits per token. If you hit a 429, wait before retrying.
- **Never log or echo credentials**, the `CIRCLECI_TOKEN` must never appear in any output visible to the user.
- **One step at a time**, do not dump all data at once. Summarise first, then offer to show details.

---

## Related Skills

- **orientation**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For diagnosing failing CircleCI builds, flaky tests, and CI/CD issues
- **xero-connector**: Same Personal-Token → `~/.claude.json` wrap-existing-tooling pattern for a different first-party MCP server
- **hubspot-connector**: Same single-token conversational-bootstrap shape
- **github-actions-pipeline-builder**: Sibling CI/CD skill for GitHub Actions users
