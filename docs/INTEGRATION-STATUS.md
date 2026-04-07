---
title: Integration & Cloud Platform Status Tracker
version: 1.0
date: 2026-04-06
---

# Integration & Cloud Platform Status

This document tracks the current state of all tool integrations (GWS, M365, AWS) and cloud platform setups (GCP, AWS, Azure), including what works, what's blocked, and what's next.

---

## Tool Integrations

### Google Workspace (GWS CLI — `gws` command)

| Environment | Status | Auth method | Notes |
|---|---|---|---|
| **Local (laptop/desktop)** | Working | `gws auth login` → opens browser | Scoped login: `-s drive,gmail,sheets,calendar`. "Access blocked" fix: add email as test user in GCP Console → OAuth consent screen. |
| **GCP Compute Engine** | Working (with friction) | SSH port-forward + `gws auth login` | **Problem:** `gws auth login` only supports OAuth with localhost callback. No device code fallback. The CLI picks a **random port** each time, so you can't pre-configure the SSH tunnel. Workaround: run `gws auth login`, read the port from the URL, then open a second SSH session with `-L <port>:localhost:<port>`. One-time auth — token refreshes automatically after. |

**Key issues:**
- No `--no-launch-browser` or device code auth in gws CLI
- Random port on each `gws auth login` makes SSH port-forward painful
- `gws auth setup` cannot run on headless VMs (needs browser to create OAuth client in GCP Console)
- **Workaround:** run `gws auth setup` on laptop first (one-time per project), copy `~/.config/gws/client_secret.json` to server, then do port-forward login

**What would fix this:**
- A `--port` flag on `gws auth login` to pin the callback port
- Or a device code auth flow (like m365 has)

---

### Microsoft 365 (PnP CLI — `m365` command)

| Environment | Status | Auth method | Notes |
|---|---|---|---|
| **Local (laptop/desktop)** | Working | `m365 setup` (registers Entra app) → `m365 login --authType browser` | Must use `m365 setup` (NOT `--interactive`). Default app only has `Calendars.Read` — needs manual upgrade to `Calendars.ReadWrite` via `m365 entra oauth2grant set`. |
| **GCP Compute Engine** | Working | Device code: `m365 login --appId <id> --tenant <id>` | Prints a code + URL. Open URL on any device (phone/laptop), enter code, sign in. Smooth, no port-forward needed. **Requires** `--appId` and `--tenant` flags since `m365 setup` wasn't run on the server. |

**Key issues:**
- `m365 setup` (app registration) requires a browser — must be done on laptop first (one-time per tenant)
- Default app has `Calendars.Read` only — calendar event creation fails with 403 until upgraded to `Calendars.ReadWrite`
- Calendar commands (`m365 outlook calendar event list/add`) don't exist in CLI v11.x — must use `m365 request` with Microsoft Graph API

**What we verified works from a headless VM:**
- `m365 login` via device code
- `m365 status` — shows connected account
- `m365 outlook message list` — read emails
- `m365 request --url "https://graph.microsoft.com/v1.0/me/events" --method post` — create calendar events
- `m365 request --url "https://graph.microsoft.com/v1.0/me/events" --method get` — list calendar events

**Upgrade Calendars.ReadWrite flow (tested, working):**
1. `m365 entra app permission add --appId <id> --delegatedPermissions "https://graph.microsoft.com/Calendars.ReadWrite" --grantAdminConsent`
2. `m365 entra oauth2grant list --spObjectId <sp-id>` → find Graph grant → replace `Calendars.Read` with `Calendars.ReadWrite` in scope
3. `m365 entra oauth2grant set --grantId <id> --scope "<updated scope>"`
4. `m365 logout && m365 login` (re-login to pick up new permission)

---

### AWS CLI

| Environment | Status | Auth method | Notes |
|---|---|---|---|
| **Local (laptop/desktop)** | Not started | — | AWS CLI not yet integrated into the workshop kit |
| **AWS EC2** | Not started | — | No setup guide or scripts created yet |

**What's needed:**
- Decide which AWS services to integrate (S3, SES, DynamoDB, Lambda?)
- Create an AWS setup guide (like GCP-SINGLE-USER-SETUP.md)
- Create `aws-setup/setup.sh` and `setup.bat`
- Add an AWS deployment skill (like `gcp-deployment-expert`)

---

## Cloud Platform Setups

### GCP (Google Cloud Platform)

| Item | Status | Details |
|---|---|---|
| **Setup guide** | Done | `docs/GCP-SINGLE-USER-SETUP.md` (v6) |
| **Setup scripts** | Done | `gcp-setup/setup.sh` (Mac/Linux), `gcp-setup/setup.bat` (Windows) — on branch `docs/gcp-single-user-setup`, PR #11 |
| **Deployment skill** | Done | `skills/gcp-deployment-expert/SKILL.md` |
| **VM image** | Tested | `--image-family=ubuntu-2404-lts-amd64 --image-project=ubuntu-os-cloud` |
| **Machine type** | Tested | `e2-standard-2` (2 vCPU, 8 GB RAM) — ~$49-61 AUD/month |
| **Claude service** | Working | systemd user service with PTY wrapper + `loginctl enable-linger` |
| **Telegram plugin** | Working | Runs via `--channels plugin:telegram@claude-plugins-official` |
| **GWS on server** | Working (friction) | Port-forward required — see GWS section above |
| **M365 on server** | Working | Device code auth — see M365 section above |

**Test VMs used:**
- `claude-assistant-v2` (australia-southeast1-b, e2-standard-2) — deleted
- `claude-assistant-test` (australia-southeast1-b, e2-standard-2) — deleted
- `claude-assistant-test-rodolfo` (australia-southeast1-b, e2-small) — still running, has GWS + M365 + Telegram working

---

### AWS (Amazon Web Services)

| Item | Status | Details |
|---|---|---|
| **Setup guide** | Not started | — |
| **Setup scripts** | Not started | — |
| **Deployment skill** | Not started | — |
| **VM testing** | Not started | Would use EC2 + Ubuntu 24.04 AMI |

**Notes:**
- `feat/internal-kit-integration` branch has an `agents/server-setup.md` that assumes AWS + Supabase + Tailscale — this is over-engineered for the workshop baseline
- AWS setup should follow the same pattern as GCP: just a VM + Claude + messaging, no extra services
- AWS-specific differences: `aws ec2 run-instances` instead of `gcloud compute instances create`, `aws ssm start-session` or `ssh -i key.pem` instead of `gcloud compute ssh`

---

### Azure (Microsoft Azure)

| Item | Status | Details |
|---|---|---|
| **Setup guide** | Not started | — |
| **Setup scripts** | Not started | — |
| **Deployment skill** | Not started | — |
| **VM testing** | Not started | Would use Azure VMs + Ubuntu 24.04 |

**Notes:**
- Potential advantage: native Entra ID integration could simplify M365 auth on Azure VMs
- Azure CLI: `az vm create`, `az ssh vm` for SSH
- Worth investigating whether Azure Managed Identity can replace the m365 device code flow entirely

---

## Feature Branches Under Review

| Branch | What it adds | Concern |
|---|---|---|
| `feat/internal-kit-integration` | Lifecycle scripts (install, update, uninstall), test suite, `toolkits/` directory, `agents/server-setup.md` | server-setup.md assumes AWS + Supabase + Tailscale — doesn't align with cloud-agnostic baseline |
| `feature/connector-framework` | 8 business connectors (GHL, Shopify, Xero, etc.), `connectors/` directory | Duplicates skills in two locations, adds connector recommendation to CLAUDE.md |
| `docs/gcp-single-user-setup` | GCP setup guide v6, setup.sh/setup.bat, gcp-deployment-expert skill, GWS/M365 CLAUDE.md rules | PR #11 — ready to merge |
| `fix/outlook-m365-guide-alignment` | Fixes m365 setup command, replaces fake calendar commands with Graph API, adds server auth flow | PR #19 — in review by gianselrai |

---

## Open Questions

1. **GWS on server:** Should we request a `--port` flag upstream, or build our own wrapper that pins the port?
2. **AWS setup:** Which region to default? Which instance type? (t3.medium is comparable to e2-standard-2)
3. **Azure setup:** Can Azure Managed Identity simplify M365 auth, or is device code still needed?
4. **Feature branches:** How to reconcile `toolkits/` vs `connectors/` naming before merging?
5. **agents/server-setup.md:** Rewrite for cloud-agnostic baseline, or remove from both branches?

---

*Last updated: 2026-04-06*
