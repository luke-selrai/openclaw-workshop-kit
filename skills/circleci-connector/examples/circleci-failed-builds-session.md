# Worked example: connect CircleCI and inspect failed builds

This is an illustrative workflow, not a captured live connection or timing claim. Use SKILL.md for setup. Tool names and schemas come from the actual calling session; the legacy npm snapshot does not establish the hosted server's surface.

## Cold start

**User:** Connect CircleCI and tell me which builds failed this week.

**Claude:** I'll connect CircleCI, then check the builds I can access. I'll open a sign-in window if needed.

1. Discover CircleCI tools in the caller. If an authenticated read already succeeds for the intended account, preserve that connection and continue.
2. In Desktop, open the official CircleCI listing from the app's own connector browser. Complete its prompts using the same Desktop account and intended CircleCI account. Use the documented hosted custom-connector route if the directory route is unavailable. Use a PAT fallback only when needed; capture it through protected input, not chat.
3. Rediscover tools and make an authenticated project/account read. On the legacy 0.20.0 server, `list_followed_projects` accepts an empty object. A config entry, Connected badge, or offline tool list alone does not pass this check.
4. If the read succeeds with no projects, report the empty result and inspect project visibility; do not create a project or trigger a pipeline simply to make the test pass.

**Claude, after a successful read with projects:** CircleCI is connected. I can see your projects. I'll check which build history is available.

## Inspect failures using the exposed tools

- Discover each tool's schema before choosing arguments. Legacy 0.20.0 offers `get_latest_pipeline_status` and `get_build_failure_logs`; use them for the selected project and branch as their schemas permit.
- A latest-pipeline read is not a complete week's history. If the current connection exposes history tools, use their actual names, pagination, and date filters. Otherwise explain the coverage limit and offer the latest available failures; never invent `get_pipelines_for_project`, `get_workflows_for_pipeline`, or `get_jobs_for_workflow` to fill the gap.
- Summarise only returned failures: project, branch, job, timestamp, and the relevant log evidence. Do not fabricate counts, source-file failures, or a root cause beyond the logs.
- A request to inspect failures does not authorize a rerun. Offer a rerun separately and follow the skill's action confirmation rules.

## Warm start

**User:** Any new failures since I last asked?

Discover the selected connection's tools and repeat its authenticated read. If usable, preserve the existing route and credentials. Compare timestamps with the prior session only when the available history covers that interval; state any coverage limit. If authentication fails, repair that route. If tools are missing, inspect the actual caller's connector state before requesting a restart.

## What is verified separately

The bundled snapshot records offline discovery of the 13 tools in `@circleci/mcp-server-circleci@0.20.0`, with a placeholder credential and no CircleCI API call. Hosted setup and real account access require their own live test. The former example's fixed 12-tool count, absent prompt tools, old `/mcp` URL, and claimed captured failure history are not used as evidence.
