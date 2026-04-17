---
name: circleci-connector
description: "Read CircleCI build, pipeline, workflow, and test data on behalf of the user via the official @circleci/mcp-server-circleci. Handles pipeline status, build failure logs, flaky test detection, job test results, artifact listing, followed projects, config validation, and pipeline triggers (run, rerun, rollback). Use this skill when the user asks about their CircleCI, builds, pipelines, workflows, failed jobs, flaky tests, build logs, or when they say 'connect my CircleCI' or 'help me set up CircleCI'. On the first use of any CircleCI feature, run Phase 1 to collect a Personal API Token and wire the MCP server into Claude Code before attempting any tool calls."
allowed-tools: mcp__circleci__*, Bash, Read, Write, Edit
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

## Overview

This skill lets you read CircleCI build and pipeline data on a user's behalf using the **official first-party [`@circleci/mcp-server-circleci`](https://github.com/CircleCI-Public/mcp-server-circleci)** (maintained by CircleCI, published to npm). It has two phases:

- **Phase 1 — Install & Connect.** A conversational bootstrap (≤5 steps). The user has never used this before. You walk them through creating a Personal API Token in their CircleCI account settings, collecting the token, and wiring the MCP server into Claude Code. The user should never see the words "npm", "npx", "bash", "terminal", "MCP", "JSON", "env var", or any file paths.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__circleci__*` native tools to answer questions about pipelines, builds, workflows, flaky tests, and more. The official server exposes 16 tools; this skill documents them all.

**Which phase to run** — Before any tool call, check whether the CircleCI MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.circleci` entry with `CIRCLECI_TOKEN` in its `env` block. If present and non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT use

- **The shell command from [circleci.com/product/mcp](https://circleci.com/product/mcp/)** — that page instructs users to paste a raw `claude mcp add ...` command into their terminal. That's a second install path and violates the conversational-bootstrap directive. We write the config to `~/.claude.json` directly instead, same shape as `xero-connector` and `hubspot-connector`.
- **The Docker install option** — CircleCI's docs offer a Docker alternative. We default to `npx` because it's simpler for non-technical users and doesn't require a Docker install.
- **OAuth** — CircleCI's MCP uses a static Personal API Token. There's no browser-based sign-in flow.
- **CircleCI Server (self-hosted)** — this skill assumes SaaS `https://circleci.com`. Self-hosted Server support would need a `CIRCLECI_BASE_URL` override, which is out of scope for this skill.

---

## Communication rules for Phase 1

The user is a non-technical business owner or team lead. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, MCP, endpoint, JSON, environment variable, or Personal API Token as a technical concept. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now — this takes just a moment."
- **React warmly.** Good: "That worked — your CircleCI is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Connect (≤5 steps)

This phase gets the Personal API Token collected, the MCP server wired into Claude Code, and the connection verified. You do every technical action; the user only clicks things in their browser and pastes one value.

### Step 1 — Orient the user

Tell the user in one short message:

> "Great — let's connect your CircleCI. I'll walk you through creating a small connection key inside CircleCI, then I'll save it on your computer and check everything is talking. This takes about two minutes."

### Step 2 — Walk the user through creating a Personal API Token

The user needs to create a Personal API Token inside their CircleCI account settings. You cannot do this step for them — CircleCI requires their authenticated session.

Tell the user, one instruction at a time, waiting for confirmation between each:

1. "Please open this page in your browser: **https://app.circleci.com/settings/user/tokens** — and sign in with your CircleCI account. Let me know when you see the tokens page."

2. When they confirm → "Click the **Create New Token** button. A small dialog will appear asking for a name. Tell me when you see it."

3. When they see the dialog → "For the name, type: **Claude Assistant**. Then click **Add API Token**. A long string will appear — that's your key."

4. When they confirm → "Please copy the full key and paste it to me. Don't worry about remembering it — I'll save it for you, and you can always revoke it later from the same page."

**Common mistakes to look out for (and correct by re-asking):**

- The user pasted a placeholder like `CIRCLECI_TOKEN` or `your_token_here` → ask again: "I think that was a copy mistake — please try again with the real value."
- The user pasted something very short (under 20 characters) → "That doesn't look quite right — the real value is longer. Can you double-check and try again?"
- The user says *"I can't find Personal API Tokens"* → "No worries — in CircleCI, click your avatar in the bottom-left corner, choose **User Settings**, then **Personal API Tokens** from the left menu. Or go straight to https://app.circleci.com/settings/user/tokens."
- The user says *"It asked me to pick a project"* → "That's the project-level token page, not what we want. We need the personal one — try https://app.circleci.com/settings/user/tokens directly."

### Step 3 — Save the credentials

Once the user pastes the Personal API Token, silently add or update the CircleCI MCP entry in the user's `~/.claude.json` file (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`).

The structure to add:

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
- If `~/.claude.json` does not exist, create it with just the CircleCI entry.
- If the file exists but cannot be parsed as JSON, back it up to `~/.claude.json.backup` first, then write a fresh config with just the CircleCI entry. Never silently lose the user's existing config.
- Never echo the token back to the user after writing it. Never include it in any output visible to the user.

Tell the user in one short message:

> "I've saved your connection details. One more step — you'll need to close Claude Code and open it again so it picks up the new connection. Do that now, and tell me when you're back."

### Step 4 — User restarts Claude Code

Wait for the user to restart. When they return, tell them: *"Welcome back. Let me just check that everything is talking to CircleCI."*

### Step 5 — Verify the connection

Call the `mcp__circleci__list_followed_projects` tool (no arguments). Handle the response:

- **Tool returns one or more projects** → Count them and name the first few. Tell the user:
  > "All done! I can see **[N]** CircleCI projects on your account, including **[project 1]**, **[project 2]**, and **[project 3]**. You can now ask me things like 'what's the status of my latest build on main?', 'why did the last build fail?', or 'list my recent pipelines'. Give it a try!"

- **Tool returns an empty list** → "Your connection is working, but I can't see any projects yet. That usually means you haven't followed any projects in CircleCI. Head to https://app.circleci.com/projects, click the projects you want me to see, and then ask me to try again." Do not treat this as a failure.

- **Tool returns `401 Unauthorized`** → "Hmm, the connection key didn't work — let me take it again." Silently go back to Step 2 Part 4 and ask the user to re-copy the token (they may have copied an incomplete string). Rewrite `~/.claude.json` with the fresh value, ask them to restart Claude Code, and try Step 5 again.

- **Tool returns `403 Forbidden`** → "Your key is valid but doesn't have the right permissions. Can you head back to https://app.circleci.com/settings/user/tokens and create a fresh one? Personal API Tokens have full read access by default, so something unusual may be going on with your account permissions — let's try a new key first."

- **Tool is not yet available (`mcp__circleci__*` tools not discoverable)** → "Looks like Claude Code didn't pick up the new connection yet. Please make sure you fully closed it (not just the window) and opened it again, then let me know." Repeat Step 4.

- **Any other error** → "Something's not quite right — let me try once more." Retry the tool call once. If it still fails, tell the user in plain English what you saw (translated — never raw errors), and ask if they want to retry or stop.

---

## PHASE 2 — Use Tools

Once the connector is configured, use the `mcp__circleci__*` MCP tools below to answer questions and trigger actions in CircleCI. The `@circleci/mcp-server-circleci` exposes **16 tools**; this reference covers all of them.

**Tool naming convention:** The official server uses underscore-separated names (e.g. `get_latest_pipeline_status`). In Claude Code they appear as `mcp__circleci__get_latest_pipeline_status`, `mcp__circleci__get_build_failure_logs`, etc.

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
| `list_component_versions` | Enumerates available versions of a CircleCI component (orb, image, etc.) | User asks what versions of a particular orb or image are available |
| `config_helper` | Validates a CircleCI configuration file | User asks to check their `.circleci/config.yml`, or pastes a config for review |
| `analyze_diff` | Checks git diffs against cursor rules / CircleCI rules for violations | User asks to review a diff against CI rules before committing |

### Write / action tools — **always confirm with the user before calling**

| Tool | Description | Use when |
|---|---|---|
| `run_pipeline` | Triggers a pipeline execution for a given project + branch | User asks to "run a build", "trigger a pipeline", or "kick off CI" — **confirm first** |
| `rerun_workflow` | Restarts a workflow from start or from the failure point | User asks to "rerun the last build", "try again", or "retry the failed jobs" — **confirm first** |
| `run_rollback_pipeline` | Initiates a rollback pipeline (if the project has one configured) | User asks to roll back a deployment — **confirm first, and double-check they mean it** |

### Advanced / AI tools

These are specialised tools CircleCI ships for AI-assisted workflows. Most users won't ask about them by name.

| Tool | Description | Use when |
|---|---|---|
| `create_prompt_template` | Generates structured AI prompt templates | User is building an AI-assisted CircleCI workflow |
| `recommend_prompt_template_tests` | Creates test scenarios for prompt templates | Follow-up to `create_prompt_template` |
| `run_evaluation_tests` | Executes prompt testing pipelines | Follow-up to `recommend_prompt_template_tests` |

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
| "What versions of [orb] are available?" | `list_component_versions` |
| "Check my CircleCI config" / "Validate my config.yml" | `config_helper` |
| "Run a build on [branch]" / "Trigger a pipeline" | `run_pipeline` — **confirm first** |
| "Rerun the last build" / "Retry failed jobs" | `rerun_workflow` — **confirm first** |
| "Roll back the deployment" | `run_rollback_pipeline` — **confirm first, double-check** |

---

## Error Handling (Phase 2)

When a CircleCI tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say to the user | How to fix |
|---|---|---|
| `401 Unauthorized` / `invalid token` | "Your CircleCI connection key isn't working — let me sort that now." | Run Phase 1 from Step 2 (re-copy the Personal API Token). If re-copying doesn't help, ask the user to check whether the token was revoked from the tokens page. |
| `403 Forbidden` | "I don't have permission to do that on your CircleCI account — that's usually because the project isn't followed, or your token doesn't cover it." | Send the user to https://app.circleci.com/projects to follow the project, or have them generate a fresh Personal API Token. |
| `404 Not Found` on a project | "I can't find that project. Let me show you which ones I can see." | Call `list_followed_projects` and ask the user which one they meant. |
| `404 Not Found` on a pipeline/build | "I couldn't find that build — let me look at the most recent ones." | Call `get_latest_pipeline_status` on the user's current branch and offer those. |
| `429 Rate limited` | "CircleCI is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds and retry once. If still 429, tell the user and suggest waiting a minute. |
| `run_rollback_pipeline` fails with "no rollback configured" | "Your project doesn't have a rollback pipeline set up yet — you'd need to configure one in CircleCI first. Want me to explain how?" | Point the user to CircleCI's rollback pipeline docs; do not try to auto-configure it. |
| MCP server not discovered (`mcp__circleci__*` tools missing) | "The CircleCI connection isn't active in this session. Please close Claude Code fully and reopen it, then try again." | User restarts Claude Code. |
| Any other API error | "Something went wrong with CircleCI — let me try again." | Retry once; if still failing, check the token is active. |

---

## Scope Limitations

The CircleCI connector **can** do (via `@circleci/mcp-server-circleci`):

- Read pipeline status, build logs, test results, and artifacts for any project the user's token can access
- Find flaky tests and underused resource classes for optimisation
- Retrieve usage API data for spend monitoring
- Trigger pipeline runs, workflow reruns, and rollback pipelines
- Validate CircleCI config files
- Analyse diffs against CircleCI rules

The CircleCI connector **cannot** do:
- **Modify project settings** — no add/remove env vars, no SSH key management, no context management
- **Manage projects** — no follow/unfollow projects, no create/delete projects, no move projects
- **Manage contexts or contexts' secrets** — the MCP surface is read-oriented with trigger actions, not configuration
- **Access CircleCI Server (self-hosted)** — requires a `CIRCLECI_BASE_URL` override not handled in this skill
- **Cancel a running pipeline** — not exposed by the MCP server
- **Approve manual-approval jobs** — not exposed by the MCP server
- **See real-time streaming logs** — logs are fetched on-demand after a job completes

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before triggering a pipeline, rerunning a workflow, or running a rollback** — summarise what you are about to do and wait for the user's OK before calling the tool. Rollbacks especially: repeat the project and environment, and ask "are you sure?"
- **Default to the user's current branch** when they don't specify one. If you don't know the branch, ask or call `list_followed_projects` first and infer.
- **Summarise failure logs** — `get_build_failure_logs` can return a lot of text. Read it, summarise the root cause in 2–3 sentences, and offer to show the full log if the user wants.
- **Present test results clearly** — when showing `get_job_test_results`, group by status (failed, passed, skipped) and highlight failures with file + test name.
- **Pagination** — default to 10 items unless the user asks for more. Offer to show more if there are additional pages.
- **Rate limits** — CircleCI enforces rate limits per token. If you hit a 429, wait before retrying.
- **Never log or echo credentials** — the `CIRCLECI_TOKEN` must never appear in any output visible to the user.
- **One step at a time** — do not dump all data at once. Summarise first, then offer to show details.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For diagnosing failing CircleCI builds, flaky tests, and CI/CD issues
- **xero-connector**: Same Personal-Token → `~/.claude.json` wrap-existing-tooling pattern for a different first-party MCP server
- **hubspot-connector**: Same single-token conversational-bootstrap shape
- **github-actions-pipeline-builder**: Sibling CI/CD skill for GitHub Actions users
