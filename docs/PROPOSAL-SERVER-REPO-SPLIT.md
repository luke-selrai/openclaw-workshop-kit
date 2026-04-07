# Proposal: Separate Server Setup into Its Own Repo

**From:** @rodolfo-selrai
**Date:** 2026-04-07
**Status:** Proposal — feedback welcome
**Reviewers:** @luke-selrai @gianselrai @ram-selrai @merwin-selrai @jesie-cmd @mike-selrai @cenred-selrai @harvey-selr @Khushi-selrai @vishwa603

---

## Summary

We're proposing to move all server/cloud setup content out of [claude-workshop-kit](https://github.com/luke-selrai/claude-workshop-kit) and into a new separate repo (`claude-server-kit`). The workshop kit stays focused on local laptop/desktop setup for workshop participants. The server kit handles 24/7 cloud deployments for those who want always-on hosting.

---

## Why

The workshop kit currently mixes two very different audiences and complexity levels:

| | Workshop Kit (local) | Server Kit (cloud) |
|---|---|---|
| **Audience** | Non-technical business owner at a workshop | Someone (or their tech person) setting up 24/7 hosting |
| **Complexity** | Install apps, paste a prompt, click buttons | VM provisioning, SSH, systemd, port-forwarding, headless auth |
| **Prerequisites** | Laptop + Claude subscription | Cloud account + billing + SSH knowledge |
| **Tone** | "Click the button that says Download" | Commands, scripts, troubleshooting tables |
| **Who does it** | Every workshop participant | Only those who want always-on access |

Keeping them in one repo means workshop participants see server setup files they'll never use, and PRs for server features conflict with PRs for workshop content (7 PRs currently touch `my-assistant/CLAUDE.md`).

---

## What Moves to the Server Repo

| Item | Currently | Moves to | Owner |
|---|---|---|---|
| `gcp-setup/setup.sh` and `setup.bat` | [PR #11](https://github.com/luke-selrai/claude-workshop-kit/pull/11) branch | `claude-server-kit/gcp-setup/` | @rodolfo-selrai |
| `docs/GCP-SINGLE-USER-SETUP.md` | [PR #11](https://github.com/luke-selrai/claude-workshop-kit/pull/11) branch | `claude-server-kit/docs/` | @rodolfo-selrai |
| `skills/gcp-deployment-expert/` | [PR #11](https://github.com/luke-selrai/claude-workshop-kit/pull/11) branch | `claude-server-kit/skills/` | @rodolfo-selrai |
| GWS + M365 headless auth flows | `my-assistant/CLAUDE.md` | `claude-server-kit/docs/SERVER-AUTH-GUIDE.md` | @rodolfo-selrai |
| Port-to-server skill | [PR #24](https://github.com/luke-selrai/claude-workshop-kit/pull/24) | `claude-server-kit/skills/` | @Khushi-selrai |
| `agents/server-setup.md` | [PR #15](https://github.com/luke-selrai/claude-workshop-kit/pull/15) and [PR #16](https://github.com/luke-selrai/claude-workshop-kit/pull/16) | `claude-server-kit/agents/` (rewritten for cloud-agnostic) | @gianselrai / @ram-selrai |
| AWS setup (planned) | [Issue #30](https://github.com/luke-selrai/claude-workshop-kit/issues/30) | `claude-server-kit/aws-setup/` | TBD |
| Azure setup (planned) | [Issue #31](https://github.com/luke-selrai/claude-workshop-kit/issues/31) | `claude-server-kit/azure-setup/` | TBD |

---

## What Stays in the Workshop Kit

| Item | Owner |
|---|---|
| Local setup guide (`docs/FULL-SETUP-PAGE.md`) | @jesie-cmd |
| All 87 skills | Team |
| Connector skills (M365, GWS, QuickBooks, Xero, Shopify, etc.) | Team |
| Messaging setup (Telegram, WhatsApp, iMessage) | @jesie-cmd |
| Workshop docs (completion guide, accounts, glossary, troubleshooting) | Team |
| `my-assistant/CLAUDE.md` — local-only rules, no server auth flows | @luke-selrai |

---

## Proposed Server Repo Structure

```
claude-server-kit/
├── gcp-setup/
│   ├── setup.sh
│   └── setup.bat
├── aws-setup/                     ← planned
│   ├── setup.sh
│   └── setup.bat
├── azure-setup/                   ← planned
│   ├── setup.sh
│   └── setup.bat
├── skills/
│   ├── gcp-deployment-expert/
│   ├── aws-deployment-expert/     ← planned
│   ├── azure-deployment-expert/   ← planned
│   └── port-to-server/
├── docs/
│   ├── GCP-SINGLE-USER-SETUP.md
│   ├── AWS-SINGLE-USER-SETUP.md   ← planned
│   ├── AZURE-SINGLE-USER-SETUP.md ← planned
│   ├── SERVER-AUTH-GUIDE.md        ← GWS + M365 headless auth
│   └── INTEGRATION-STATUS.md
├── CLAUDE.md                       ← server-specific rules
└── README.md
```

The server repo references the workshop kit: "Clone the workshop kit onto your server" — so skills, CLAUDE.md, and connectors still come from the main repo.

---

## Impact on Open PRs

| PR | Author | Impact |
|---|---|---|
| [PR #11](https://github.com/luke-selrai/claude-workshop-kit/pull/11) — GCP setup | @rodolfo-selrai | Already closed. Content moves to server repo. |
| [PR #15](https://github.com/luke-selrai/claude-workshop-kit/pull/15) — Internal kit | @gianselrai | `agents/server-setup.md` moves to server repo. Rest stays. |
| [PR #16](https://github.com/luke-selrai/claude-workshop-kit/pull/16) — Connector framework | @ram-selrai | `agents/server-setup/AGENT.md` moves to server repo. Rest stays. |
| [PR #19](https://github.com/luke-selrai/claude-workshop-kit/pull/19) — M365 fixes | @rodolfo-selrai | Server auth sections move to server repo. Local fixes stay. |
| [PR #24](https://github.com/luke-selrai/claude-workshop-kit/pull/24) — Port-to-server | @Khushi-selrai | Entire PR moves to server repo. |

**PRs not affected** (stay in workshop kit as-is):
- [PR #14](https://github.com/luke-selrai/claude-workshop-kit/pull/14) — /loop and /schedule (@merwin-selrai)
- [PR #17](https://github.com/luke-selrai/claude-workshop-kit/pull/17) — Connector recommender (@vishwa603)
- [PR #18](https://github.com/luke-selrai/claude-workshop-kit/pull/18) — Dispatch docs (@cenred-selrai)
- [PR #20](https://github.com/luke-selrai/claude-workshop-kit/pull/20) — Phone channel fixes (@jesie-cmd)
- [PR #23](https://github.com/luke-selrai/claude-workshop-kit/pull/23) — Usability audit (@vishwa603)

---

## Impact on GitHub Issues

| Issue | Author | Impact |
|---|---|---|
| [#29](https://github.com/luke-selrai/claude-workshop-kit/issues/29) — GCP connector | @rodolfo-selrai | Moves to server repo |
| [#30](https://github.com/luke-selrai/claude-workshop-kit/issues/30) — AWS setup | Unassigned | Moves to server repo |
| [#31](https://github.com/luke-selrai/claude-workshop-kit/issues/31) — Azure setup | Unassigned | Moves to server repo |
| [#47](https://github.com/luke-selrai/claude-workshop-kit/issues/47) — PR #11 GCP issue | @rodolfo-selrai | Close — PR already closed |
| [#54](https://github.com/luke-selrai/claude-workshop-kit/issues/54) — Port-to-server | @Khushi-selrai | Moves to server repo |

**Issues not affected** (stay in workshop kit):
- [#25](https://github.com/luke-selrai/claude-workshop-kit/issues/25) — Mac installer
- [#26](https://github.com/luke-selrai/claude-workshop-kit/issues/26) — Windows installer
- [#27](https://github.com/luke-selrai/claude-workshop-kit/issues/27) — GWS connector (local)
- [#28](https://github.com/luke-selrai/claude-workshop-kit/issues/28) — M365 connector (local)
- [#32](https://github.com/luke-selrai/claude-workshop-kit/issues/32)-[#39](https://github.com/luke-selrai/claude-workshop-kit/issues/39) — Business tool connectors
- [#40](https://github.com/luke-selrai/claude-workshop-kit/issues/40)-[#46](https://github.com/luke-selrai/claude-workshop-kit/issues/46) — Documentation issues
- [#48](https://github.com/luke-selrai/claude-workshop-kit/issues/48)-[#53](https://github.com/luke-selrai/claude-workshop-kit/issues/53), [#55](https://github.com/luke-selrai/claude-workshop-kit/issues/55) — PR-related issues

---

## Benefits

1. **Workshop participants** see a clean, focused repo — no server files they'll never use
2. **Server setup complexity** doesn't pollute workshop guides
3. **Fewer merge conflicts** — server PRs won't touch `my-assistant/CLAUDE.md` in the workshop repo
4. **Separate visibility** — workshop repo can go public for workshops; server repo stays private or has different access controls
5. **Different pace** — server features can iterate independently without risking workshop stability
6. **Clearer ownership** — server infra work is tracked separately from workshop content

---

## Next Steps

| Step | Owner | Depends on |
|---|---|---|
| Team agrees on the split | @luke-selrai (approval) | This proposal |
| Create `claude-server-kit` repo | @luke-selrai or @rodolfo-selrai | Approval |
| Move GCP content from [PR #11](https://github.com/luke-selrai/claude-workshop-kit/pull/11) branch | @rodolfo-selrai | Repo created |
| Move server-setup agent from [PR #15](https://github.com/luke-selrai/claude-workshop-kit/pull/15) / [PR #16](https://github.com/luke-selrai/claude-workshop-kit/pull/16) | @gianselrai / @ram-selrai | Repo created |
| Move port-to-server from [PR #24](https://github.com/luke-selrai/claude-workshop-kit/pull/24) | @Khushi-selrai | Repo created |
| Strip server auth flows from [PR #19](https://github.com/luke-selrai/claude-workshop-kit/pull/19) | @rodolfo-selrai | Repo created |
| Update workshop kit — remove server references | @rodolfo-selrai | All moves complete |
| Close or redirect affected issues ([#29](https://github.com/luke-selrai/claude-workshop-kit/issues/29), [#30](https://github.com/luke-selrai/claude-workshop-kit/issues/30), [#31](https://github.com/luke-selrai/claude-workshop-kit/issues/31), [#47](https://github.com/luke-selrai/claude-workshop-kit/issues/47), [#54](https://github.com/luke-selrai/claude-workshop-kit/issues/54)) | @rodolfo-selrai | All moves complete |
| Create new project board for server repo | @rodolfo-selrai | Repo created |
| Add all team members as collaborators | @luke-selrai | Repo created |

---

## Open Questions

1. Should the server repo be public or private?
2. Should we create a shared GitHub org (e.g., `selrai`) instead of keeping repos under `luke-selrai`?
3. Who owns the AWS and Azure setup guides? (@gianselrai? @Khushi-selrai? Someone else?)
4. Should the `agents/server-setup.md` be rewritten to be cloud-agnostic, or should we have one per cloud (GCP, AWS, Azure)?

---

**Please react or comment with your thoughts.** The main question: does this split make sense, or is there a reason to keep everything in one repo?

**Project board:** [Workshop Kit — Development Board](https://github.com/users/luke-selrai/projects/1)
