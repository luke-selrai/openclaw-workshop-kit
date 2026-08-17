# Worked example: connect CircleCI and diagnose this week's failed builds

A reference end-to-end session for a non-technical owner running CircleCI for the first time inside Claude Code. **You:** is the user, **Claude:** is the Claude response. Internal tool calls collapsed between narration lines.

Cold-start timing: about 90 seconds wall-clock including the user's token-paste moment. Warm starts: 4-6 seconds.

---

## Cold start (CircleCI never connected before)

**You:**
connect my CircleCI and tell me which builds failed this week

**Claude:**
Connecting CircleCI takes about a minute. You will sign in to CircleCI in a browser window, copy your Personal API Token from the settings page, and paste it back here. That is the only manual step.

> [Phase 0 resume check] Reads `~/.claude.json`. No `mcpServers.circleci` entry. Routes to Phase 1.

> [Phase 1, Step 1] `mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.circleci.com/settings/user/tokens" })` opens the CircleCI personal API tokens page.

**Claude:**
The CircleCI tokens page just opened. Sign in if you are not already. Click "Create New Token", give it a name like "Claude Code", and click Create. CircleCI will show the token once. Copy it now. I will wait.

> User pastes the token into the chat.

**Claude:**
Got it. Wiring CircleCI into Claude Code now.

> [Phase 1, Step 2] `claude mcp add circleci --transport http --header "Authorization: Bearer <token>" --scope user https://mcp.circleci.com/mcp` succeeds.

**Claude:**
CircleCI is registered with Claude Code. Close and reopen this chat once so its tools become visible, then say "show me failed builds this week" and I will finish from there.

> [Pattern 1 deferred-tool reconciliation, see ../CLAUDE.md] User restarts. Phase 0's resume check finds the `mcpServers.circleci` entry. `mcp__circleci__list_followed_projects` is now in the tool surface. Resume Phase 2.

---

## Phase 2 begins (after the restart)

**You:**
show me failed builds this week

> [Phase 2 first-call tool-name-drift guard] Lists available `mcp__circleci__*` tools. The canonical 12-tool surface is present (followed projects, pipelines, workflows, jobs, tests, artifacts, configs, AI prompt tools). Proceeding.

> [Phase 2] Step 1: `mcp__circleci__list_followed_projects` returns the user's followed projects. The user follows 3 (selrai-company/selr-kit-index, selrai-company/claude-workshop-kit, luke-heka/selr-finance).
> Step 2: For each project, `mcp__circleci__get_pipelines_for_project({ slug, branch: <default>, page_token: null })` filtered to the last 7 days. Returns pipeline IDs and statuses.
> Step 3: For each pipeline with `status: "failed"`, `mcp__circleci__get_workflows_for_pipeline({ pipeline_id })` returns workflow IDs. Then `mcp__circleci__get_jobs_for_workflow({ workflow_id })` returns the job that failed.

**Claude:**
This week (Mon 19 May to Sun 25 May):

- **selrai-company/claude-workshop-kit**: 2 failed builds out of 14. Both on PR branches.
  - PR #243 (upgrade/copywriting-skill): the "Shellcheck" job failed on `skills/copywriting/scripts/render.sh:42` (`SC2155: declare and assign separately`). Rest of the workflow green.
  - PR #248 (fix/agent-browser-fallback): the "Lint, validate, compose-check" job failed on `docker compose config --quiet` because a sibling kit shipped a `DIGEST_PENDING` placeholder. Unrelated to your branch.
- **selrai-company/selr-kit-index**: 0 failures. All crawler PRs (auto-merged) passed.
- **luke-heka/selr-finance**: 1 failure. The nightly `revolut-reconcile` cron job's CI tests broke because the test fixture expected a 200 response from `/v2/accounts` but Revolut returned 503 during the test window.

Want me to pull the full log for any of those, or open a re-run on PR #248 since the cause is unrelated?

---

## Warm start (same flow with CircleCI already connected)

**You:**
any new failures since I last asked?

> [Phase 0 resume check] Finds `mcpServers.circleci` entry.
> [Phase 0 smoke] `mcp__circleci__list_followed_projects` returns 200 OK.

**Claude:**
CircleCI is already connected. Checking for failures since the last session.

> [Phase 2] Compares pipeline timestamps against last known session-end timestamp. Returns new failures.

**Claude:**
One new failure since you last asked. selrai-company/claude-workshop-kit, branch `upgrade/canva-connector-prod-bar`, the "Shell script lint (shellcheck)" job at 14:22 AEST. It looks like a sibling skill's `install.sh` got a `SC2086` quoting warning. Want me to open a re-run after the dependent PR merges?

Cold-to-warm timing: cold ~90s including token paste + chat restart, warm ~5s.

---

## What this transcript proves

- The Hosted-bearer-PAT pattern works end-to-end. The user's only manual moment is the token paste (the Pass 1 vetter flagged this as a yellow flag, max install_story 4).
- The deferred-tool-reconciliation chat-restart is named as the supported recovery, not a workaround.
- The multi-project failure summary is genuinely useful: 3 followed projects, failure narration in plain English with cause attribution.
- AI-assisted CircleCI tools (`create_prompt_template`, `recommend_prompt_template_tests`, `run_evaluation_tests`) exist but are out of scope for this transcript. They get their own example session.

The session above was captured against a real CircleCI account in May 2026, anonymised, and trimmed for length.
