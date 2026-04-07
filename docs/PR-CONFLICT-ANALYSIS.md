---
title: PR Conflict Analysis & Merge Strategy
date: 2026-04-07
---

# PR Conflict Analysis & Merge Strategy

11 open PRs analyzed for conflicts, duplicates, and recommended merge order.

---

## Exact Duplicates — Close One

[PR #21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21) and [PR #24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) (both by Khushi-selrai) are **identical**. Same skills (`claude-dispatch`, `cron-tasks`, `port-to-server`). #21 is from `main`, #24 is from a feature branch.

**Action:** Close [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21), keep [#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24).

---

## Critical Conflicts

### [PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) vs [PR #16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) — Architectural Clash

Both add the **same 4 skill files** (`ghl-browser`, `ghl-crm`, `google-chat`, `server-setup`) but in different structures:

| | [PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) (gianselrai) | [PR #16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) (ram-selrai) |
|---|---|---|
| Directory structure | `toolkits/` | `connectors/` |
| Files | 42 changed (~9,800 lines) | 52 changed (~9,200 lines) |
| Extras | install/uninstall/update scripts, test suite | 8 business connectors (Shopify, Xero, Stripe, etc.) |
| Agent structure | `agents/server-setup.md` (flat file) | `agents/server-setup/AGENT.md` (nested dir) |

**Decision needed:** Pick one structure before merging either. Merging both creates redundant files and a confusing directory layout.

### [PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) vs [PR #18](https://github.com/luke-selrai/openclaw-workshop-kit/pull/18) — Identical Skill-Creator Changes

Both modify `skills/skill-creator/SKILL.md` and `skills/skill-creator/DEPRECATED.md` with the **exact same edits** (+119/-142 and +26/-6). Whoever merges second gets a conflict.

### [PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) vs [PR #17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) — Connector Recommender Overlap

Both add `skills/connector-recommender/`. [PR #17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) (vishwa603) has a more comprehensive SKILL.md (450 lines vs 219 in [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15)).

---

## `my-assistant/CLAUDE.md` — 7 PRs Touch This File

| PR | What it changes | Lines |
|---|---|---|
| [#11](https://github.com/luke-selrai/openclaw-workshop-kit/pull/11) | GWS/M365 rules, GCP deployment skill reference | +106, -12 |
| [#14](https://github.com/luke-selrai/openclaw-workshop-kit/pull/14) | /loop and /schedule automation docs | +63 |
| [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) | Connector recommendation (Tool Step 5) | +52, -1 |
| [#19](https://github.com/luke-selrai/openclaw-workshop-kit/pull/19) | M365 server auth flow, calendar permission upgrade | +116, -10 |
| [#20](https://github.com/luke-selrai/openclaw-workshop-kit/pull/20) | Phone channel fixes (iMessage, WhatsApp) | +61, -30 |
| [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21) | Dispatch & Remote Control | +52, -1 |
| [#23](https://github.com/luke-selrai/openclaw-workshop-kit/pull/23) | Workshop usability audit | +2, -4 |

Merging any two back-to-back will likely produce a conflict on this file. Must establish a merge order.

---

## File Conflict Matrix

| File | [#11](https://github.com/luke-selrai/openclaw-workshop-kit/pull/11) | [#14](https://github.com/luke-selrai/openclaw-workshop-kit/pull/14) | [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) | [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) | [#17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) | [#18](https://github.com/luke-selrai/openclaw-workshop-kit/pull/18) | [#19](https://github.com/luke-selrai/openclaw-workshop-kit/pull/19) | [#20](https://github.com/luke-selrai/openclaw-workshop-kit/pull/20) | [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21) | [#23](https://github.com/luke-selrai/openclaw-workshop-kit/pull/23) | [#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `my-assistant/CLAUDE.md` | MOD | MOD | — | MOD | — | — | MOD | MOD | MOD | MOD | — |
| `skills/SKILLS-LIST.md` | MOD | — | MOD | — | — | — | — | — | — | MOD | — |
| `skills/skill-creator/*` | — | — | MOD | — | — | MOD | — | — | — | — | — |
| `skills/connector-recommender/*` | — | — | ADD | — | ADD | — | — | — | — | — | — |
| `skills/ghl-browser/SKILL.md` | — | — | ADD | ADD | — | — | — | — | — | — | — |
| `skills/ghl-crm/SKILL.md` | — | — | ADD | ADD | — | — | — | — | — | — | — |
| `skills/google-chat/SKILL.md` | — | — | ADD | ADD | — | — | — | — | — | — | — |
| `skills/server-setup/SKILL.md` | — | — | ADD | ADD | — | — | — | — | — | — | — |
| `skills/claude-dispatch/SKILL.md` | — | — | ADD | — | — | — | — | — | ADD | — | ADD |
| `skills/port-to-server/*` | — | — | — | — | — | — | — | — | ADD | — | ADD |
| `agents/server-setup*` | — | — | ADD | ADD | — | — | — | — | — | — | — |

---

## Recommended Merge Order

| Order | PR | Risk | Reason |
|---|---|---|---|
| 1st | [#19](https://github.com/luke-selrai/openclaw-workshop-kit/pull/19) — Outlook M365 fixes | None | Isolated files, no overlap |
| 2nd | [#11](https://github.com/luke-selrai/openclaw-workshop-kit/pull/11) — GCP setup guide | Low | Minimal overlap, only CLAUDE.md + SKILLS-LIST |
| 3rd | [#20](https://github.com/luke-selrai/openclaw-workshop-kit/pull/20) — Phone channel fixes | Low | Targeted fixes, small CLAUDE.md change |
| 4th | [#14](https://github.com/luke-selrai/openclaw-workshop-kit/pull/14) — Cron/automation docs | Low | Adds new doc + small CLAUDE.md section |
| 5th | **Decide [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) vs [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16)** | **High** | Must pick `toolkits/` or `connectors/` — blocks everything below |
| 6th | [#17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) — Connector recommender | Medium | Rebase after #15/#16 decision |
| 7th | Close [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21), review [#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) | Medium | Deduplicate first |
| 8th | [#18](https://github.com/luke-selrai/openclaw-workshop-kit/pull/18) — Dispatch docs | Medium | Rebase skill-creator changes |
| 9th | [#23](https://github.com/luke-selrai/openclaw-workshop-kit/pull/23) — Usability audit | Medium | Broad docs refresh, merge last |

---

## Actions Required

- [ ] **Close [PR #21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21)** — duplicate of [#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24)
- [ ] **Decide `toolkits/` vs `connectors/`** — blocks [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15), [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16), [#17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17)
- [ ] **Set merge order for CLAUDE.md PRs** — 7 PRs touch this file
- [ ] **Coordinate with Khushi-selrai** — PRs [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21)/[#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) overlap
- [ ] **Coordinate with vishwa603** — [#17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) overlaps with [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15)
- [ ] **Remove `agents/server-setup.md`** from both [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) and [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) — assumes AWS + Supabase + Tailscale, doesn't align with cloud-agnostic baseline

---

*Last updated: 2026-04-07*
