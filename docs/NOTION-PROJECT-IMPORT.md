# Workshop Kit — Project Board & Status Update

**GitHub Project Board:** [Workshop Kit — Development Board](https://github.com/users/luke-selrai/projects/1)
**Repository:** [luke-selrai/openclaw-workshop-kit](https://github.com/luke-selrai/openclaw-workshop-kit)
**Last Updated:** 2026-04-07

---

## Current Sprint Status

| Status | Count |
|---|---|
| Done | 3 |
| In Review | 4 |
| In Progress | 4 |
| Todo | 6 |
| Blocked | 6 |
| Backlog | 12 |

---

## What's Ready to Merge Now

These PRs have no conflicts and can merge immediately:

1. [PR #19 — Fix Outlook/M365 guides](https://github.com/luke-selrai/openclaw-workshop-kit/pull/19) — fixes `m365 setup` command, replaces fake calendar commands with Graph API, adds server auth flow. **Reviewer: gianselrai**
2. [PR #11 — GCP server setup guide](https://github.com/luke-selrai/openclaw-workshop-kit/pull/11) — full GCP setup with `setup.sh`/`setup.bat`, tested on VM. **Ready to merge**
3. [PR #20 — Phone channel fixes](https://github.com/luke-selrai/openclaw-workshop-kit/pull/20) — WhatsApp + iMessage fixes. Merge after #11 and #19

---

## Blockers — Decisions Needed

### `toolkits/` vs `connectors/` directory structure

[PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) (gianselrai) and [PR #16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) (ram-selrai) both add the **same 4 skills** in different structures. Must pick one before merging either.

**This blocks:** [PR #15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15), [PR #16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16), [PR #17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17), [PR #18](https://github.com/luke-selrai/openclaw-workshop-kit/pull/18)

### Duplicate PR

[PR #21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21) is a duplicate of [PR #24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) (both by Khushi-selrai). **Close #21.**

---

## P0 — Critical (Must Have for Workshop)

| Issue | Title | Status | Owner |
|---|---|---|---|
| [#25](https://github.com/luke-selrai/openclaw-workshop-kit/issues/25) | Local Setup: Mac installer (setup.sh) | Todo | Unassigned |
| [#26](https://github.com/luke-selrai/openclaw-workshop-kit/issues/26) | Local Setup: Windows installer (setup.bat) | Todo | Unassigned |
| [#27](https://github.com/luke-selrai/openclaw-workshop-kit/issues/27) | Connector: Google Workspace (gws CLI) | In Progress | rodolfo-selrai |
| [#28](https://github.com/luke-selrai/openclaw-workshop-kit/issues/28) | Connector: Microsoft 365 (m365 CLI) | In Progress | rodolfo-selrai |
| [#29](https://github.com/luke-selrai/openclaw-workshop-kit/issues/29) | Connector: GCP (Google Cloud Platform) | In Review | rodolfo-selrai |
| [#40](https://github.com/luke-selrai/openclaw-workshop-kit/issues/40) | Docs: FULL-SETUP-PAGE.md — main guide | In Progress | Unassigned |
| [#42](https://github.com/luke-selrai/openclaw-workshop-kit/issues/42) | Docs: Telegram setup guide | Done | jesie-cmd |
| [#47](https://github.com/luke-selrai/openclaw-workshop-kit/issues/47) | PR #11: GCP server setup — ready to merge | In Review | rodolfo-selrai |
| [#48](https://github.com/luke-selrai/openclaw-workshop-kit/issues/48) | PR #19: M365 fixes — awaiting review | In Review | rodolfo-selrai |
| [#51](https://github.com/luke-selrai/openclaw-workshop-kit/issues/51) | Architecture decision: toolkits/ vs connectors/ | Blocked | Decision needed |

## P1 — High (Should Have)

| Issue | Title | Status | Owner |
|---|---|---|---|
| [#30](https://github.com/luke-selrai/openclaw-workshop-kit/issues/30) | Connector: AWS | Backlog | Unassigned |
| [#41](https://github.com/luke-selrai/openclaw-workshop-kit/issues/41) | Docs: COMPLETION-GUIDE.md updates | Todo | Unassigned |
| [#43](https://github.com/luke-selrai/openclaw-workshop-kit/issues/43) | Docs: iMessage setup guide | Done | jesie-cmd |
| [#44](https://github.com/luke-selrai/openclaw-workshop-kit/issues/44) | Docs: WhatsApp setup guide | Todo | Unassigned |
| [#45](https://github.com/luke-selrai/openclaw-workshop-kit/issues/45) | Docs: Windows-specific setup | In Progress | Unassigned |
| [#50](https://github.com/luke-selrai/openclaw-workshop-kit/issues/50) | PR #20: Phone channel fixes | Todo | jesie-cmd |

## P2 — Medium (Nice to Have)

| Issue | Title | Status | Owner |
|---|---|---|---|
| [#31](https://github.com/luke-selrai/openclaw-workshop-kit/issues/31) | Connector: Azure | Backlog | Unassigned |
| [#32](https://github.com/luke-selrai/openclaw-workshop-kit/issues/32) | Connector: QuickBooks | Backlog | Unassigned |
| [#33](https://github.com/luke-selrai/openclaw-workshop-kit/issues/33) | Connector: Xero | Backlog | Unassigned |
| [#34](https://github.com/luke-selrai/openclaw-workshop-kit/issues/34) | Connector: Shopify | Backlog | Unassigned |
| [#35](https://github.com/luke-selrai/openclaw-workshop-kit/issues/35) | Connector: Stripe | Backlog | Unassigned |
| [#36](https://github.com/luke-selrai/openclaw-workshop-kit/issues/36) | Connector: HubSpot | Backlog | Unassigned |
| [#38](https://github.com/luke-selrai/openclaw-workshop-kit/issues/38) | Connector: GoHighLevel / GHL | Backlog | Unassigned |
| [#46](https://github.com/luke-selrai/openclaw-workshop-kit/issues/46) | Docs: Accounts/subscriptions guides | Done | — |
| [#49](https://github.com/luke-selrai/openclaw-workshop-kit/issues/49) | PR #14: /loop and /schedule automation | Todo | merwin-selrai |
| [#52](https://github.com/luke-selrai/openclaw-workshop-kit/issues/52) | PR #18: Dispatch docs | Blocked | cenred-selrai |
| [#53](https://github.com/luke-selrai/openclaw-workshop-kit/issues/53) | PR #23: Usability audit | Backlog | vishwa603 |
| [#54](https://github.com/luke-selrai/openclaw-workshop-kit/issues/54) | PR #24: Port-to-server skill | Backlog | Khushi-selrai |
| [#55](https://github.com/luke-selrai/openclaw-workshop-kit/issues/55) | PR #17: Connector recommender | Blocked | vishwa603 |

## P3 — Low (Future)

| Issue | Title | Status | Owner |
|---|---|---|---|
| [#37](https://github.com/luke-selrai/openclaw-workshop-kit/issues/37) | Connector: Square | Backlog | Unassigned |
| [#39](https://github.com/luke-selrai/openclaw-workshop-kit/issues/39) | Connector: Google Chat | Backlog | Unassigned |

---

## Integration Status Summary

### What's Working

| Integration | Local | Server (GCP) | Auth Method (Server) |
|---|---|---|---|
| **Google Workspace (gws)** | Working | Working (with friction) | SSH port-forward (random port issue) |
| **Microsoft 365 (m365)** | Working | Working | Device code (smooth) |
| **Telegram** | Working | Working | Plugin + pairing |
| **iMessage** | Working (Mac only) | N/A | Local only |
| **WhatsApp** | Working | Not tested | QR code scan |

### What's Not Started

| Integration | Notes |
|---|---|
| **AWS CLI** | No setup guide yet |
| **Azure CLI** | No setup guide yet |
| **QuickBooks** | Research needed — does CLI exist? |
| **Xero** | Research needed — does CLI exist? |
| **Shopify** | CLI exists: @shopify/cli |
| **Stripe** | CLI exists: stripe |
| **HubSpot** | CLI exists: @hubspot/cli |
| **Square** | Likely API-only |
| **GHL** | No CLI — Playwright browser automation |

---

## Open PRs — Conflict Map

7 out of 11 PRs modify `my-assistant/CLAUDE.md`. This is the #1 source of merge conflicts.

| PR | Author | Status | Conflicts With |
|---|---|---|---|
| [#11](https://github.com/luke-selrai/openclaw-workshop-kit/pull/11) | rodolfo-selrai | In Review | CLAUDE.md (minor) |
| [#14](https://github.com/luke-selrai/openclaw-workshop-kit/pull/14) | merwin-selrai | Todo | CLAUDE.md |
| [#15](https://github.com/luke-selrai/openclaw-workshop-kit/pull/15) | gianselrai | Blocked | **#16** (same skills), #17, #18 |
| [#16](https://github.com/luke-selrai/openclaw-workshop-kit/pull/16) | ram-selrai | Blocked | **#15** (same skills), CLAUDE.md |
| [#17](https://github.com/luke-selrai/openclaw-workshop-kit/pull/17) | vishwa603 | Blocked | #15 (connector-recommender) |
| [#18](https://github.com/luke-selrai/openclaw-workshop-kit/pull/18) | cenred-selrai | Blocked | #15 (skill-creator) |
| [#19](https://github.com/luke-selrai/openclaw-workshop-kit/pull/19) | rodolfo-selrai | In Review | None |
| [#20](https://github.com/luke-selrai/openclaw-workshop-kit/pull/20) | jesie-cmd | Todo | CLAUDE.md |
| [#21](https://github.com/luke-selrai/openclaw-workshop-kit/pull/21) | Khushi-selrai | **Duplicate — close** | #24 (identical) |
| [#23](https://github.com/luke-selrai/openclaw-workshop-kit/pull/23) | vishwa603 | Backlog | CLAUDE.md, SKILLS-LIST |
| [#24](https://github.com/luke-selrai/openclaw-workshop-kit/pull/24) | Khushi-selrai | Backlog | #15 (claude-dispatch skill) |

**Recommended merge order:** #19 → #11 → #20 → #14 → (decide #15 vs #16) → #17 → #24 → #18 → #23

---

## Team Access

| Member | GitHub | Repo Access | Board Access |
|---|---|---|---|
| Luke | luke-selrai | Owner | Admin |
| Rodolfo | rodolfo-selrai | Collaborator | Writer |
| Harvey | harvey-selr | Collaborator | Writer |
| Jesie | jesie-cmd | Collaborator | Writer |
| Ram | ram-selrai | Collaborator | Writer |
| Merwin | merwin-selrai | Collaborator | Writer |
| Gian | gianselrai | Collaborator | Writer |
| Mike | mike-selrai | Collaborator | Writer |
| Cenred | cenred-selrai | Collaborator | Writer |
| Khushi | Khushi-selrai | External (fork) | Writer |
| Vishwa | vishwa603 | External (fork) | Writer |

---

## Process Improvements Implemented

1. **GitHub Project Board** — all issues and PRs tracked with Status, Category, Priority
2. **Board visibility** — public, linked to repo, all team members have write access
3. **Issue labels** — baseline, connector, cloud-platform, server, productivity, business-tool, mac, windows

## Process Improvements Recommended

1. **CODEOWNERS file** — require review for `my-assistant/CLAUDE.md` changes
2. **Small PRs** — one connector per PR, not 8 in one
3. **Claim system** — create a GitHub issue before starting work
4. **CLAUDE.md sections** — structure as append-only to reduce conflicts
5. **Weekly sync** — 10-min standup on what's in flight
