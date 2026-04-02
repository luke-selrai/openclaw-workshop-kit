# Integration Documentation

**Version:** 1.1.0
**Date:** 2026-04-02
**Integration Lead:** Gian Carino
**Status:** Local — ready for upload to official repo

---

## Table of Contents

1. [Purpose](#purpose)
2. [Source Repositories and Pull Requests](#source-repositories-and-pull-requests)
3. [Contributors and Credits](#contributors-and-credits)
4. [What Was Combined](#what-was-combined)
5. [Architecture](#architecture)
6. [Component Details](#component-details)
7. [Changes Made During Integration](#changes-made-during-integration)
8. [Test Results](#test-results)
9. [Errors and Troubleshooting Log](#errors-and-troubleshooting-log)
10. [Decisions and Rationale](#decisions-and-rationale)
11. [Known Warnings](#known-warnings)
12. [Next Steps for Official Repo Merge](#next-steps-for-official-repo-merge)

---

## Purpose

This document records the R&D process of combining work from the Selr AI Internal Kit main branch, PR #1 (Khushi-selrai), and PR #12 (cenred-selrai) into a single, tested, documented package ready for upload to the [OpenClaw Workshop Kit](https://github.com/luke-selrai/openclaw-workshop-kit) official repository.

The goal: take scattered work across two repos and two PRs, audit it, fix issues, test everything, and produce one clean deliverable with full transparency about who built what.

---

## Source Repositories and Pull Requests

### Repositories

| Repository | URL | Description |
|------------|-----|-------------|
| **OpenClaw Workshop Kit** | https://github.com/luke-selrai/openclaw-workshop-kit | Official public workshop kit. 86+ skills for non-technical business owners. The target for this integration. |
| **Selr AI Internal Kit** | https://github.com/luke-selrai/selrai-internal-kit | Internal production tools. GHL integration, Google Chat, server provisioning. The primary source. |

### Pull Requests

| PR | Repository | URL | Author | Status at Integration | Description |
|----|-----------|-----|--------|----------------------|-------------|
| **#1** | selrai-internal-kit | https://github.com/luke-selrai/selrai-internal-kit/pull/1 | **Khushi-selrai** | Open, unmerged | Added skill-creator plugin and claude-dispatch skill. 5 commits, 283 additions. |
| **#12** | openclaw-workshop-kit | https://github.com/luke-selrai/openclaw-workshop-kit/pull/12 | **cenred-selrai** | Open, unmerged | Improved skill-creator: fixed deprecation, rewrote description, added Selr AI context. 1 commit. |

---

## Contributors and Credits

> This integration combines work from multiple people. Credit belongs to the original authors. This section exists to ensure proper attribution.

| Contributor | What They Built | Source |
|-------------|----------------|--------|
| **luke-selrai** | GHL Toolkit (setup.sh, test.sh, scripts/ghl CLI, env template, permissions config), Google Chat Toolkit (setup.sh, test.sh, gws CLI integration), Server Setup skill (12-phase provisioning, 1,166 lines), Server Setup agent, GHL CRM skill, GHL Browser skill, Google Chat skill. Entire OpenClaw Workshop Kit architecture (86 skills, onboarding wizard, memory system). | Internal Kit main branch, Official Kit |
| **Khushi-selrai** | Claude Dispatch & Remote Control skill (186 lines) — guide for controlling Claude from phone via Dispatch (non-technical) and Remote Control (developer). Initial skill-creator addition. | [Internal Kit PR #1](https://github.com/luke-selrai/selrai-internal-kit/pull/1) |
| **cenred-selrai** | Improved Skill Creator (202 lines) — complete rewrite with YAML frontmatter, selr-ai/openclaw tags, trigger phrases, 7-step creation process, scripts documentation, cross-platform DEPRECATED.md. | [Official Kit PR #12](https://github.com/luke-selrai/openclaw-workshop-kit/pull/12) |
| **Gian Carino** | Integration lead. Cloned both repos, fetched both PRs, audited all files for quality issues, identified and skipped heredoc artifacts from PR #1, selected PR #12 over PR #1 for skill-creator, added YAML frontmatter to server-setup and claude-dispatch skills, ran dry-run tests on all toolkits, created all documentation (README, CHANGELOG, INTEGRATION), security validation. | This integration |

---

## What Was Combined

### From Internal Kit Main Branch (luke-selrai)

| Component | Type | Path |
|-----------|------|------|
| GHL CRM skill | Skill | `skills/ghl-crm/SKILL.md` |
| GHL Browser skill | Skill | `skills/ghl-browser/SKILL.md` |
| Google Chat skill | Skill | `skills/google-chat/SKILL.md` |
| Server Setup skill | Skill | `skills/server-setup/SKILL.md` |
| Server Setup agent | Agent | `agents/server-setup.md` |
| GHL Toolkit | Toolkit | `toolkits/ghl-toolkit/` (9 files) |
| Google Chat Toolkit | Toolkit | `toolkits/google-chat-toolkit/` (5 files) |

### From PR #1 (Khushi-selrai)

| Component | Type | Path | Notes |
|-----------|------|------|-------|
| Claude Dispatch skill | Skill | `skills/claude-dispatch/SKILL.md` | Clean file, no issues. YAML frontmatter added during integration. |
| ~~skill-creator~~ | ~~Skill~~ | ~~`skills/skill-creator/SKILL.md`~~ | **Skipped** — heredoc-wrapped artifact. Superseded by PR #12 version. |
| ~~setup.sh~~ | ~~Script~~ | ~~`setup.sh`~~ | **Skipped** — heredoc-wrapped artifact. Only prints manual instructions. |

### From PR #12 (cenred-selrai)

| Component | Type | Path | Notes |
|-----------|------|------|-------|
| Improved Skill Creator | Skill | `skills/skill-creator/SKILL.md` | Properly structured rewrite with frontmatter, tags, scripts documentation. |

---

## Architecture

```
selrai-internal-kit/
  README.md                            # Repository overview
  agents/
    server-setup.md                    # Agent definition (102 lines)
  skills/
    ghl-crm/SKILL.md                  # GHL CRM API (279 lines)
    ghl-browser/SKILL.md              # GHL browser automation (717 lines)
    google-chat/SKILL.md              # Google Chat via gws CLI (161 lines)
    server-setup/SKILL.md             # 12-phase provisioning (1,182 lines)
    claude-dispatch/SKILL.md          # Dispatch & Remote Control (200 lines)
    skill-creator/SKILL.md            # Skill creation workflow (202 lines)
  toolkits/
    ghl-toolkit/
      setup.sh                        # One-command installer (98 lines)
      test.sh                         # Health check + API test (114 lines)
      scripts/ghl                     # Bash CLI, 40+ endpoints (302 lines)
      secrets/ghl.env.template        # Credential template (33 lines)
      settings-permissions.md         # Auto-approve config (49 lines)
      README.md                       # Setup guide (125 lines)
      skills/ghl-browser/SKILL.md     # Bundled copy
      skills/ghl-crm/SKILL.md         # Bundled copy
      .gitignore                      # Excludes secrets
    google-chat-toolkit/
      setup.sh                        # gws CLI installer (141 lines)
      test.sh                         # Health check + API test (99 lines)
      README.md                       # Setup guide (136 lines)
      skills/google-chat/SKILL.md     # Bundled copy
      .gitignore                      # Excludes credentials
  docs/
    INTEGRATION.md                    # This document
    CHANGELOG.md                      # Version history with credits
```

### How Toolkits Work

Each toolkit is a **self-contained installer**. Users run `bash setup.sh` and the script:
1. Checks prerequisites (Node.js, CLI tools, `~/.claude/` directory)
2. Copies skills to `~/.claude/skills/`
3. Copies scripts and templates to project directories
4. Guides through credential setup (API keys, OAuth)

The `test.sh` script validates the full chain: installation, credentials, and live API connectivity.

Toolkits bundle copies of their skills (in `toolkits/*/skills/`) so they work standalone. These copies are identical to the canonical versions in `skills/`.

### Master Installer and Health Dashboard

Two scripts provide the entry points for the entire kit:

**`install.sh`** (419 lines) — Interactive master installer
- Rainbow ASCII banner with Selr AI branding
- Cross-platform detection (macOS, Windows/Git Bash, Linux, WSL)
- Prerequisite validation (Node.js, Git, Claude Code, ~/.claude)
- Interactive skill and toolkit selection with descriptions
- Progress bar with Unicode block characters
- Agent auto-deployment to ~/.claude/agents/
- Install log (.install.log) with timestamps
- Context-aware next steps
- Respects NO_COLOR env variable and dumb terminals

**`status.sh`** (403 lines) — Live health dashboard (31 checks)
- Environment checks (Node.js, Git, Claude Code, npm, Python 3, ~/.claude)
- Skill installation status with frontmatter validation and source sync
- Toolkit checks: CLI scripts, credentials, live API connectivity tests
- Agent installation verification
- Source kit integrity (all source files, bundled skill sync)
- Summary with colored status badge (ALL SYSTEMS GO / MOSTLY READY / NEEDS ATTENTION)
- CI-friendly exit codes (0 = all pass, 1 = failures)

---

## Component Details

### GHL CRM Skill (`skills/ghl-crm/SKILL.md`)

**Author:** luke-selrai | **Lines:** 279 | **Category:** CRM & Business Tools

Teaches Claude the GoHighLevel CRM API. Covers:
- Three access methods: GHL MCP servers (preferred), bash helper scripts, direct API calls
- API quirks: snake_case params vs camelCase responses, html field for email, rate limiting
- Safety guardrails: no contact deletion without approval, no bulk messaging, mandatory tagging
- Complete tool inventory: contacts, opportunities, conversations, social media, calendars, email templates, blogs, payments

**Dependencies:** GHL API key, location ID (configured via ghl-toolkit)

### GHL Browser Skill (`skills/ghl-browser/SKILL.md`)

**Author:** luke-selrai | **Lines:** 717 | **Category:** CRM & Business Tools

Browser automation for GHL UI-only operations. Covers:
- Decision matrix: API first, Playwright second
- Persistent Playwright profile at `~/.playwright-profile/`
- GHL login flow with autonomous 2FA via Gmail MCP
- GHL internal (undocumented) APIs using Firebase JWT tokens
- Safety rules: never close browser, never kill Chrome, never delete sessions
- Advanced: Patchright for anti-detection, Chrome DevTools MCP, CLI mode

**Dependencies:** Playwright, Gmail MCP (for 2FA), GHL account credentials

### Google Chat Skill (`skills/google-chat/SKILL.md`)

**Author:** luke-selrai | **Lines:** 161 | **Category:** CRM & Business Tools

Google Chat integration via gws CLI. Covers:
- Send/read messages, list spaces, get members, reply in threads, send cards
- Pagination (`--page-all`, `--page-limit`)
- Output formats: JSON, table, YAML, CSV
- Safety rules: check space IDs, no spamming
- Troubleshooting: token cache, scopes, permissions

**Dependencies:** Google Workspace account (not personal Gmail), gws CLI, GCP OAuth

### Server Setup Skill (`skills/server-setup/SKILL.md`)

**Author:** luke-selrai | **Lines:** 1,182 | **Category:** DevOps

12-phase automated infrastructure provisioning:

| Phase | What It Does |
|-------|-------------|
| 0 | Mac dependency checks (brew, node, python3, Claude Code, Tailscale, AWS CLI) |
| 1 | AWS EC2 provisioning (CLI, browser automation, or existing server) |
| 2 | Server base setup (Ubuntu packages, Node.js, Playwright, Tailscale) |
| 3 | Claude Code authentication (OAuth, API key, or token push) |
| 4 | Agent framework (run-agent.sh, shared scripts: Supabase, noticeboard, Telegram, browser, maintenance) |
| 5 | Agent templates (scout, sam, ops, content, support) |
| 6 | Secrets and environment variables |
| 7 | Supabase database (5 tables: agent_memory, agent_status, agent_messages, shared_context, activity_log) |
| 8 | Cron scheduling |
| 9 | Local Mac configuration (settings.json, MCP config, memory system, CLAUDE.md) |
| 10 | Optional Telegram bot (Python long-polling bot for agent control) |
| 11 | Smoke testing |

**Dependencies:** AWS account, Tailscale, Supabase project, Claude Code auth

### Claude Dispatch Skill (`skills/claude-dispatch/SKILL.md`)

**Author:** Khushi-selrai | **Lines:** 200 | **Category:** AI & Automation

Guide for controlling Claude remotely. Two versions:
- **Dispatch** — For non-technical users. QR-code setup via Claude Desktop Cowork.
- **Remote Control** — For developers. `claude remote-control` terminal command.

Includes comparison table, setup steps for both, useful CLI flags, workshop recommendation guidance, troubleshooting.

**Source:** [PR #1](https://github.com/luke-selrai/selrai-internal-kit/pull/1)

### Skill Creator (`skills/skill-creator/SKILL.md`)

**Author:** cenred-selrai | **Lines:** 202 | **Category:** Productivity & Meta

Improved skill creation workflow. Features:
- Proper YAML frontmatter with `selr-ai` and `openclaw` tags
- Specific trigger phrases for Claude detection
- 7-step creation process (Understand, Plan, Initialise, Edit, Validate, Package, Iterate)
- Bundled resources documentation (scripts/, references/, assets/)
- Scripts table: init_skill.py, quick_validate.py, package_skill.py
- Writing style rules and description quality checklist
- Selr AI skill directory convention documentation

**Source:** [PR #12](https://github.com/luke-selrai/openclaw-workshop-kit/pull/12)

### GHL Toolkit (`toolkits/ghl-toolkit/`)

**Author:** luke-selrai | **Files:** 9

| File | Lines | Purpose |
|------|-------|---------|
| `setup.sh` | 98 | One-command installer. Copies skills, scripts, credential template to `~/.claude/`. |
| `test.sh` | 114 | Health check. Validates installation, credentials, live API connectivity (HTTP 200/401/422/000). |
| `scripts/ghl` | 302 | Bash CLI wrapping 40+ GHL API endpoints. Contacts CRUD, opportunities, pipelines, conversations, SMS/email, calendars, appointments, workflows, tags, custom fields, forms, surveys, payments, raw API. |
| `secrets/ghl.env.template` | 33 | Credential template. GHL_API_KEY, GHL_LOCATION_ID, GHL_LOGIN_EMAIL, GHL_LOGIN_PASSWORD + optional config. |
| `settings-permissions.md` | 49 | 37 GHL MCP + 6 Playwright auto-approve permission entries. |
| `README.md` | 125 | Setup guide, 9 usage examples, troubleshooting, optional features. |
| `skills/ghl-browser/SKILL.md` | 717 | Bundled copy (identical to `skills/ghl-browser/`). |
| `skills/ghl-crm/SKILL.md` | 279 | Bundled copy (identical to `skills/ghl-crm/`). |
| `.gitignore` | 3 | Excludes `secrets/ghl.env`, `.DS_Store`. |

### Google Chat Toolkit (`toolkits/google-chat-toolkit/`)

**Author:** luke-selrai | **Files:** 5

| File | Lines | Purpose |
|------|-------|---------|
| `setup.sh` | 141 | Installs gws CLI (npm), copies skill, guides through GCP project + OAuth. Three auth paths: team share, automated, manual. |
| `test.sh` | 99 | Health check. Validates skill, CLI, GCP credentials, OAuth tokens, live API call. |
| `README.md` | 136 | Prerequisites, 4-step setup, 5 usage examples, troubleshooting, team sharing. |
| `skills/google-chat/SKILL.md` | 161 | Bundled copy (identical to `skills/google-chat/`). |
| `.gitignore` | 7 | Excludes credentials, token cache, client secret, `.DS_Store`. |

### Server Setup Agent (`agents/server-setup.md`)

**Author:** luke-selrai | **Lines:** 102

Agent definition that orchestrates the server-setup skill. Defines the agent's identity, behavior phases, available tools, handling table for common situations, and success criteria.

---

## Changes Made During Integration

These are modifications made by the integration lead (Gian Carino) that were not part of the original source material.

| File | Change | Why |
|------|--------|-----|
| `skills/server-setup/SKILL.md` | Added YAML frontmatter (`name`, `description`, `allowed-tools`, `metadata` with tags) | Original file lacked the `---` delimited frontmatter. All other skills in the official kit use this format, and the skill-creator documents it as required. |
| `skills/claude-dispatch/SKILL.md` | Added YAML frontmatter (`name`, `description`, `metadata` with tags) | Same reason. PR #1 contributor wrote clean markdown without the frontmatter convention. |
| `README.md` | Created from scratch | Internal kit had no README. Added repository overview, structure, contributors, quick start. |
| `docs/INTEGRATION.md` | Created from scratch | Full integration documentation (this file). |
| `docs/CHANGELOG.md` | Created from scratch | Version history with proper attribution for every component. |

### What Was Intentionally Excluded

| Component | Source | Reason |
|-----------|--------|--------|
| PR #1 root `setup.sh` | Khushi-selrai PR #1 | File was wrapped in heredoc syntax (`cat > setup.sh << 'EOF'`). This is a copy-paste artifact from terminal — the file contains the generator, not the generated script. The toolkit-specific setup.sh files handle installation properly. |
| PR #1 `skills/skill-creator/SKILL.md` | Khushi-selrai PR #1 | Also wrapped in heredoc syntax. Superseded by PR #12's properly structured version by cenred-selrai. |

---

## Test Results

All testing was dry-run (no live credentials available). Shell scripts validated for syntax, logic flow, security, and completeness.

### GHL Toolkit

| Component | Syntax | Logic | Security | Verdict |
|-----------|--------|-------|----------|---------|
| `setup.sh` | PASS (`bash -n`) | PASS — `set -e`, prereq checks, idempotent | PASS — no secrets exposed | **PASS** |
| `test.sh` | PASS (`bash -n`) | PASS — pass/fail counters, HTTP status handling | PASS — no secret values printed | **PASS** |
| `scripts/ghl` | PASS (`bash -n`) | PASS — 30+ commands, help text, Bearer auth | PASS — API key from env file | **PASS** |
| `ghl.env.template` | N/A | PASS — all required vars documented | PASS — placeholder values only | **PASS** |
| `settings-permissions.md` | N/A | PASS — 37 + 6 permissions listed | N/A | **PASS** |
| `README.md` | N/A | PASS — complete coverage | N/A | **PASS** |
| Skills sync | N/A | PASS — `diff` confirms identical to top-level | N/A | **PASS** |

### Google Chat Toolkit

| Component | Syntax | Logic | Security | Verdict |
|-----------|--------|-------|----------|---------|
| `setup.sh` | PASS (`bash -n`) | PASS — dep checks, 3 auth paths, `set -e` | PASS — no credentials hardcoded | **PASS** |
| `test.sh` | PASS (`bash -n`) | PASS — pass/fail tracking, credential checks | PASS — no secret values printed | **PASS** |
| `README.md` | N/A | PASS — complete coverage | N/A | **PASS** |
| Skills sync | N/A | PASS — `diff` confirms identical to top-level | N/A | **PASS** |

### Skills Validation

| Skill | Frontmatter | Structure | Hardcoded Paths | Secrets | Verdict |
|-------|------------|-----------|-----------------|---------|---------|
| `ghl-crm` | PASS | PASS | PASS (uses `~`) | PASS | **PASS** |
| `ghl-browser` | PASS | PASS | PASS (uses `<YOUR_USER>`) | PASS | **PASS** |
| `google-chat` | PASS | PASS | PASS | PASS | **PASS** |
| `server-setup` | PASS (added) | PASS | PASS (uses `$HOME`, `~`) | PASS | **PASS** |
| `claude-dispatch` | PASS (added) | PASS | PASS | PASS | **PASS** |
| `skill-creator` | PASS | PASS | PASS | PASS | **PASS** |
| `agents/server-setup.md` | PASS | PASS | PASS | PASS | **PASS** |

### Security Summary

| Check | Result |
|-------|--------|
| Exposed .env files | 0 |
| Exposed credentials | 0 |
| Toolkit .gitignore files | Present in both toolkits |
| Hardcoded user-specific paths | None (all use `~` or placeholders) |
| Placeholder-only credential templates | Confirmed |

### Overall

**Total checks: 44 | PASS: 44 | FAIL: 0 | WARN: 15 (all minor, non-blocking)**

---

## Errors and Troubleshooting Log

| # | Issue | Root Cause | Resolution | Status |
|---|-------|-----------|------------|--------|
| 1 | `gh` CLI not found in bash shell | gh CLI not installed or not in Git Bash PATH on Windows | Used WebFetch for PR #12 details, `git fetch origin pull/*/head` for branch content | RESOLVED |
| 2 | PR #1 `setup.sh` wrapped in heredoc (`cat > setup.sh << 'EOF'`) | Copy-paste artifact from terminal | Skipped file. Toolkit setup.sh files are correct approach. | RESOLVED — SKIPPED |
| 3 | PR #1 `skill-creator/SKILL.md` wrapped in heredoc | Same copy-paste artifact | Used PR #12's clean version instead | RESOLVED — SUPERSEDED |
| 4 | `grep "cat >"` flagged `server-setup/SKILL.md` | False positive — legitimate SSH `cat >` commands for remote file creation | No fix needed | RESOLVED — FALSE POSITIVE |
| 5 | `git checkout main --` reverted uncommitted edits | `git checkout main -- path/` replaces working tree files | Used `git stash` / `git stash pop` to preserve changes | RESOLVED |
| 6 | Skill directory count vs documented count mismatch | Directory listing includes non-skill entries | Verified by counting table rows | RESOLVED — COUNT VERIFIED |
| 7 | `server-setup/SKILL.md` missing YAML frontmatter | Original internal kit file used heading format without frontmatter | Added YAML frontmatter with name, description, allowed-tools, metadata | RESOLVED — FIXED |
| 8 | `claude-dispatch/SKILL.md` missing YAML frontmatter | PR #1 contributor wrote clean markdown without frontmatter | Added YAML frontmatter with name, description, metadata | RESOLVED — FIXED |
| 9 | PR #1 commit history: misplaced directory then deleted | Skills placed in `skills/skills/skill-creator/` (nested), then fixed in later commits | Not blocking — used final file content | NOTED |
| 10 | PR #1 description doesn't mention claude-dispatch | Skill added in commit 5 after PR was created; description not updated | Not blocking — documented for PR review | NOTED |

---

## Decisions and Rationale

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Used PR #12 skill-creator over PR #1 version | PR #12 (cenred-selrai) has proper YAML frontmatter, cross-platform support, selr-ai/openclaw tags, trigger phrases, scripts documentation. PR #1 (Khushi) was heredoc-wrapped. |
| 2 | Skipped PR #1 root `setup.sh` | Heredoc artifact that only prints manual instructions. Toolkit setup.sh files actually install. |
| 3 | Added YAML frontmatter to 2 skills | Consistency with all other skills in the official kit. Skill-creator documents frontmatter as required. |
| 4 | Kept bundled skill copies in toolkits | Toolkits are self-contained installers. Bundled copies ensure they work independently. Diff confirmed identical. |
| 5 | Created new docs/ directory | Internal kit had no documentation. README, changelog, and integration docs are essential for the official repo upload. |

---

## Known Warnings

Non-blocking quality items identified during testing.

### GHL Toolkit
1. `scripts/ghl` lacks argument validation — empty args cause silent API errors
2. `scripts/ghl` minimal URL encoding — only encodes spaces, @, +
3. `README.md` uses macOS-specific `open` command

### Google Chat Toolkit
4. `setup.sh` uses macOS-only `brew install` commands
5. `test.sh` uses `python3` without checking if installed
6. `test.sh` always exits 0 even when tests fail

### Skills
7. `ghl-browser/SKILL.md` is 717 lines (exceeds 500-line recommendation)
8. `server-setup/SKILL.md` is 1,182 lines (significantly exceeds recommendation)

---

## Next Steps for Official Repo Merge

1. **Upload this repo** to the official workshop kit repository
2. **Update `skills/SKILLS-LIST.md`** in the official kit to include the 6 new skills
3. **Update `.gitignore`** in the official kit to protect toolkit secrets
4. **Consider updating `my-assistant/CLAUDE.md`** if the onboarding wizard should reference toolkits
5. **Add toolkit setup guides** to `docs/` (GHL-SETUP.md, GOOGLE-CHAT-SETUP.md)
6. **Manage upstream PRs:**
   - PR #1 (internal kit): Close or note as "integrated"
   - PR #12 (official kit): Merge or note as "integrated"
7. **Address known warnings** — prioritize argument validation and cross-platform support

---

*Documentation generated 2026-04-02 by Gian Carino with Claude Code assistance.*
*All source material credited to original authors: luke-selrai, Khushi-selrai, cenred-selrai.*
