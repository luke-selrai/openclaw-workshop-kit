# Changelog

All notable changes to the Selr AI Internal Kit are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

---

## [1.5.0] - 2026-04-02

### Feature: Connector Recommender + Test Suite Update

**Authors:** Gian Carino, vishwa603
**Source:** [claude-workshop/connector-recommender](https://github.com/vishwa603/claude-workshop/tree/main/connector-recommender)

#### Added

- **skills/connector-recommender/SKILL.md** (219 lines)
  Business integration advisor. Detects user's business type (ecommerce, agency, SaaS, local business, freelancer, real estate, construction) and recommends 3-5 most impactful connectors. Guides setup using MCP registry (search_mcp_registry, suggest_connectors). Handles existing tools, hybrid businesses, operations-based fallback.

- **skills/connector-recommender/REFERENCE.md** (273 lines)
  Full architecture documentation: 4-phase flow (Context Detection, Recommendation Engine, Presentation, Setup Execution), component details, integration points with automation-intelligence and n8n skills, limitations, FAQ.

- **skills/connector-recommender/TESTCASES.md** (265 lines)
  15 test scenarios covering: all 7 business types, unclear input, existing tools, setup accept/decline, unavailable connectors, multiple business types, operations-only, negative case, overwhelm handling. Test summary matrix included.

#### Changed

- **skills/SKILLS-LIST.md** — Updated from 92 to 93 skills. Added connector-recommender under CRM & Business Tools as CORE tier. Updated footer (24 CORE).
- **docs/INTEGRATION.md** — Added vishwa603 to Contributors and Credits table.
- **docs/CHANGELOG.md** — Added v1.5.0 entry for connector-recommender.
- **tests/01-smoke.sh** — Updated to include connector-recommender in skill checks. Fixed skill count assertion for official kit context (was hardcoded to 6).
- **tests/02-skills.sh** — Added connector-recommender to ALL_SKILLS array for validation.
- **tests/05-docs.sh** — Adapted README tests for official kit context. Added vishwa603 credit check. Added integration doc file existence checks.
- Test suite expanded from 324 to 334 tests.

---

## [1.4.0] - 2026-04-02

### Feature: Doctor, Uninstaller, Updater

**Author:** Gian Carino

#### Added

- **doctor.sh** (431 lines)
  Diagnoses environment issues AND offers interactive auto-fix. Inspired by `flutter doctor` and `brew doctor`.
  - Checks Node.js (version >= 18), Git, Claude Code CLI, ~/.claude directory
  - Validates all 6 skills (installation, frontmatter, source sync) with offer to re-install outdated versions
  - Validates agent installation with auto-install on missing
  - GHL toolkit: script executable, credentials configured vs placeholder, live API test (HTTP 200/401/422/000)
  - Google Chat toolkit: gws CLI, GCP credentials, live API test
  - Source kit integrity check
  - `--auto-fix` flag for non-interactive repair
  - Tracks and reports total fixes applied per session

- **uninstall.sh** (214 lines)
  Professional clean removal with safety features:
  - `--dry-run` flag shows what WOULD be removed without removing anything
  - `--keep-credentials` preserves ghl.env and GCP tokens while removing everything else
  - `--yes` flag for non-interactive removal
  - Ownership-aware: only removes kit-managed components, never touches user-created files
  - Scans and reports items with sizes before confirmation
  - Cleans up empty directories after removal
  - Explicitly states source kit is preserved

- **update.sh** (206 lines)
  One-command updater that pulls latest and re-installs only what changed:
  - `--check` flag to see what's outdated without installing
  - `--force` flag to re-install everything regardless
  - Git-aware: fetches remote, shows how many commits behind, pulls, shows changelog
  - Component-level diff: only re-installs skills/agents that actually changed
  - Tracks updated vs new vs unchanged counts
  - Works without git (compares local source to installed)

#### Changed

- Test suite expanded from 286 to 324 tests to cover all 3 new scripts

---

## [1.3.0] - 2026-04-02

### Feature: Full Test Suite (324 Tests)

**Author:** Gian Carino

#### Added

- **tests/test-runner.sh** — Lightweight TAP-compliant test harness with 12 assertion types (file_exists, dir_exists, executable, syntax_ok, contains, not_contains, equals, greater_than, grep, no_grep, diff, frontmatter), colored output, NO_COLOR support, failure tracking.

- **tests/01-smoke.sh** (38 tests) — Verifies all files exist, directories are present, scripts are executable, file counts are correct. The "does it even exist?" layer.

- **tests/02-skills.sh** (62 tests) — YAML frontmatter validation (open/close delimiters, required fields), skill name matches directory, content quality (line count, word count, headings), no hardcoded user paths (smart exclusion of example text), ecosystem tags, no heredoc artifacts, bundled skill sync.

- **tests/03-toolkits.sh** (66 tests) — Shell syntax validation (bash -n) for all 7 scripts, install.sh logic (platform detection, progress bar, NO_COLOR, agent copying), status.sh logic (all check categories, status badges, exit codes), GHL toolkit (setup.sh, test.sh, CLI commands, env template), Google Chat toolkit (setup.sh, test.sh, .gitignore).

- **tests/04-security.sh** (27 tests) — Secret scanning (AWS keys, GitHub PATs, Slack tokens, hardcoded API keys), credential file exposure (.env, client_secret, .pem, token_cache), .gitignore protection for both toolkits, credential template safety (placeholders only, no real JWTs or emails), hardcoded password scanning across all scripts.

- **tests/05-docs.sh** (57 tests) — Documentation completeness and content length, README structure (title, links, sections, all 4 contributors credited), PREREQUISITES structure (all 10 required sections, all 6 tools/services mentioned), CHANGELOG structure (all versions, credits, PR references), INTEGRATION structure, internal link validation, toolkit README completeness.

- **tests/06-cross-platform.sh** (36 tests) — Shebang portability, ANSI color safety (\\033 not \\e for Git Bash), NO_COLOR and dumb terminal support, path handling (no Windows backslashes, uses $HOME), platform detection (macOS/Linux/Windows/WSL), line endings (LF not CRLF), Unicode hex encoding, temp directory safety.

- **tests/run-all.sh** — Master test runner. Runs all 6 suites in sequence with timing, colored suite-level pass/fail banners, grand summary with status badge, CI-friendly exit codes.

---

## [1.2.0] - 2026-04-02

### Feature: Master Installer + Health Dashboard

**Author:** Gian Carino

#### Added

- **install.sh** (419 lines)
  Interactive master installer with:
  - Rainbow ASCII banner
  - Cross-platform detection (macOS, Windows/Git Bash, Linux, WSL)
  - Prerequisite checks (Node.js, Git, Claude Code, ~/.claude)
  - Interactive skill selection (choose individual skills or 'all')
  - Interactive toolkit selection with descriptions
  - Progress bar with Unicode block characters
  - Agent auto-deployment to ~/.claude/agents/
  - Install log saved to .install.log
  - Context-aware next steps based on what was installed
  - Color-coded output with NO_COLOR and dumb terminal support
  - `set -e` for error safety

- **docs/PREREQUISITES.md** (400+ lines)
  Complete requirements guide covering:
  - Quick checklist (print-and-tick format)
  - System requirements (OS, hardware, terminal)
  - Per-component breakdowns (Core, GHL, Google Chat, Server Setup, Dispatch, Skill Creator)
  - Every software dependency with version, check command, and install method
  - Every account with cost and sign-up link
  - Every credential with where to find it and step-by-step instructions
  - Network/firewall requirements (domains, ports)
  - Cost summary at 4 tiers ($20/mo minimum to $162/mo full stack)
  - Pre-install verification commands

- **status.sh** (403 lines)
  Live health dashboard with 31 checks across 5 categories:
  - **Environment:** Node.js, Git, Claude Code CLI, npm, Python 3, ~/.claude
  - **Skills:** Installation status, frontmatter validation, source sync check
  - **Toolkits:** GHL CLI script, credentials, live API connectivity test; gws CLI, GCP credentials, live Chat API test
  - **Agents:** Installation and frontmatter check
  - **Source Kit Integrity:** installer presence, source skills, toolkit setup scripts, documentation, bundled skill sync
  - Summary with status badge (ALL SYSTEMS GO / MOSTLY READY / NEEDS ATTENTION)
  - Exit code 0 on all-pass, 1 on any failure (CI-friendly)

---

## [1.1.0] - 2026-04-02

### Integration: Combined Internal Kit + PR #1 + PR #12

**Integration Lead:** Gian Carino
**Branch:** `integration/combined-with-docs`

#### Added

- **skills/claude-dispatch/SKILL.md** (200 lines)
  Dispatch & Remote Control guide — control Claude from your phone or any browser.
  Covers Dispatch (non-technical, QR-code via Cowork) and Remote Control (developer, terminal).
  Includes comparison table, setup steps for both approaches, troubleshooting.
  *Original author: **Khushi-selrai** via [selrai-internal-kit PR #1](https://github.com/luke-selrai/selrai-internal-kit/pull/1)*

- **skills/skill-creator/SKILL.md** (202 lines)
  Improved skill creation workflow. Complete rewrite with:
  - Proper YAML frontmatter (name, description, allowed-tools, license, metadata)
  - `selr-ai` and `openclaw` tags for ecosystem context
  - Specific trigger phrases for Claude detection
  - 7-step creation process documentation
  - Bundled resources guide (scripts/, references/, assets/)
  - Scripts table (init_skill.py, quick_validate.py, package_skill.py)
  *Original author: **cenred-selrai** via [openclaw-workshop-kit PR #12](https://github.com/luke-selrai/openclaw-workshop-kit/pull/12)*

- **docs/INTEGRATION.md** — Full integration documentation
- **docs/CHANGELOG.md** — This file
- **README.md** — Repository overview with structure, contributors, quick start

#### Changed

- **skills/server-setup/SKILL.md** — Added YAML frontmatter (name, description, allowed-tools, metadata with tags). Original file lacked the `---` delimited frontmatter used by all other skills.
  *Fix by: Gian Carino during integration*

- **skills/claude-dispatch/SKILL.md** — Added YAML frontmatter (name, description, metadata with tags). Original PR #1 file was clean markdown without frontmatter.
  *Fix by: Gian Carino during integration*

---

## [1.0.2] - 2026-04-01

**Commit:** `54c9934` by luke-selrai

#### Added

- **toolkits/google-chat-toolkit/** — Self-contained Google Chat installer
  - `setup.sh` — Installs gws CLI, copies skill, guides through GCP OAuth
  - `test.sh` — Health check (skill, CLI, credentials, live API test)
  - `README.md` — Setup guide with prerequisites and troubleshooting
  - `skills/google-chat/SKILL.md` — Bundled copy of skill
  - `.gitignore` — Excludes credentials, token cache, client secret

- **skills/google-chat/SKILL.md** (161 lines)
  Google Chat via gws CLI — send/read messages, list spaces, manage threads, card messages.
  *Author: **luke-selrai***

---

## [1.0.1] - 2026-04-01

**Commit:** `a951df9` by luke-selrai

#### Added

- **toolkits/ghl-toolkit/** — Complete GHL CRM integration package
  - `setup.sh` (98 lines) — One-command installer
  - `test.sh` (114 lines) — Health check with live API test
  - `scripts/ghl` (302 lines) — Bash CLI wrapping 40+ GHL API endpoints
  - `secrets/ghl.env.template` (33 lines) — Credential template
  - `settings-permissions.md` (49 lines) — 37 GHL + 6 Playwright auto-approve entries
  - `README.md` (125 lines) — Setup guide, usage examples, troubleshooting
  - `skills/ghl-browser/SKILL.md` — Bundled copy
  - `skills/ghl-crm/SKILL.md` — Bundled copy
  - `.gitignore` — Excludes secrets/ghl.env

- **skills/ghl-crm/SKILL.md** (279 lines)
  GoHighLevel CRM API skill — contacts CRUD, opportunities, conversations, campaigns, calendars, email templates, payments. Three access methods: MCP servers, bash helper scripts, direct API calls. Safety guardrails included.
  *Author: **luke-selrai***

- **skills/ghl-browser/SKILL.md** (717 lines)
  GHL browser automation — Playwright-based, persistent profiles, autonomous 2FA via Gmail MCP, GHL internal API access via Firebase JWT. Decision matrix: API first, Playwright second.
  *Author: **luke-selrai***

---

## [1.0.0] - 2026-04-01

**Commit:** `0727507` by luke-selrai

#### Added

- **agents/server-setup.md** (102 lines)
  Agent definition for zero-to-production server provisioning. Orchestrates the server-setup skill across 12 phases.
  *Author: **luke-selrai***

- **skills/server-setup/SKILL.md** (1,166 lines, now 1,182 with frontmatter)
  12-phase automated infrastructure provisioning:
  Phase 0: Mac dependency checks | Phase 1: AWS EC2 provisioning | Phase 2: Server base setup | Phase 3: Claude Code auth | Phase 4: Agent framework | Phase 5: Agent templates | Phase 6: Secrets | Phase 7: Supabase (5 tables) | Phase 8: Cron scheduling | Phase 9: Local Mac config | Phase 10: Telegram bot | Phase 11: Smoke testing
  *Author: **luke-selrai***

---

## Source Repositories

| Repository | URL | Role |
|------------|-----|------|
| **Selr AI Internal Kit** | https://github.com/luke-selrai/selrai-internal-kit | This repo — internal production tools |
| **OpenClaw Workshop Kit** | https://github.com/luke-selrai/openclaw-workshop-kit | Target — official public workshop kit |

## Pull Requests Referenced

| PR | URL | Author | What It Added |
|----|-----|--------|---------------|
| **PR #1** (Internal Kit) | https://github.com/luke-selrai/selrai-internal-kit/pull/1 | **Khushi-selrai** | claude-dispatch skill, initial skill-creator |
| **PR #12** (Official Kit) | https://github.com/luke-selrai/openclaw-workshop-kit/pull/12 | **cenred-selrai** | Improved skill-creator (rewrite with frontmatter, cross-platform, Selr AI context) |

---

*Maintained by the Selr AI team*
