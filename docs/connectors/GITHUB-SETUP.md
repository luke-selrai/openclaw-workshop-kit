---
title: GitHub — Setup Guide
version: 1.0
date: 2026-04-15
---

# GitHub — Setup Guide

This guide connects your GitHub account to your AI assistant using the official GitHub remote MCP server. Once set up, your assistant can browse your repositories, read and write code, manage issues and pull requests, check GitHub Actions runs, and more — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](../start/full-setup.md) if not done yet)
- A GitHub account (free at github.com)
- An internet connection

> **No coding experience required.** Your GitHub access key is stored locally on your computer and is never sent to third parties.

> **Windows users:** You may need a slightly different install command because of a known Windows quirk with HTTP connections — your assistant handles this automatically, you don't have to do anything different.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |
| Linux — x64 / ARM | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Repositories** | Browse repos, read files, search code, view commits, releases, and branches |
| **Issues** | List, search, read, create, update, and comment on issues |
| **Pull Requests** | List, review, create, update, merge, and approve PRs |
| **GitHub Actions** | See workflow runs, check failed CI, read job logs |
| **Notifications** | Browse and dismiss your GitHub inbox |
| **Code Search** | Full-text code search across your repos |
| **Releases & Tags** | Browse releases, check latest versions, manage tags |
| **Security Alerts** | Read Code Scanning, Dependabot, and secret scanning alerts |
| **Gists** | Create, read, and update code snippets |
| **Discussions** | Read and browse repo and org discussions |

---

## Step 1 — Choose Read-Only or Read + Write

Before you create your GitHub access key, decide how much you want your assistant to be able to do:

| Option | What it allows | Good for |
|---|---|---|
| **Read-only** | Browse repos, view files, read issues and PRs, see commits and Actions runs | Trying it out, code review, exploring a codebase, answering questions |
| **Read + Write** | Everything above, plus create issues, open PRs, push files, create branches, merge PRs | Daily development work, issue triage, shipping code |

> **You can always upgrade later.** Start with read-only if you're not sure — it only takes a minute to add write permissions later, no need to start over.

---

## Step 2 — Create a GitHub Access Key (you do this)

This step creates a secure connection key that lets your assistant talk to GitHub on your behalf.

1. Open **https://github.com/settings/personal-access-tokens/new** in your browser and sign in
2. Fill in **Token name**: `Claude Assistant`
3. Choose an **Expiration**:
   - **90 days** if you want to renew it every few months
   - **No expiration** (or the longest option GitHub offers) if you prefer set-and-forget
4. Under **Repository access**, choose one:
   - **All repositories** — your assistant can work across every repo you own
   - **Only select repositories** — pick a specific list from the dropdown
5. Scroll down to **Repository permissions** and set the following, based on your choice from Step 1:

   **For Read-Only:**
   | Permission | Access |
   |---|---|
   | **Contents** | Read-only |
   | **Issues** | Read-only |
   | **Pull requests** | Read-only |
   | **Metadata** | Read-only (already selected — required, leave it) |

   **For Read + Write:**
   | Permission | Access |
   |---|---|
   | **Contents** | Read and write |
   | **Issues** | Read and write |
   | **Pull requests** | Read and write |
   | **Metadata** | Read-only (already selected — required, leave it) |

6. Scroll to the bottom and click the green **Generate token** button
7. You will now see your **access key** — it starts with `github_pat_` (or `ghp_` for classic tokens)
8. **Copy this access key immediately** — this is the only time GitHub will show it to you. If you close the page without copying, you will have to create a new one.

> **Important:** Treat this access key like a password. Do not share it, do not post it online, and do not paste it into any public place.

> **Tip:** If you don't see **Repository permissions**, make sure you're on the **fine-grained** token page (the URL in Step 1 takes you there). The older "classic token" page looks different.

---

## Step 3 — Tell Your Assistant to Connect (your assistant does the rest)

Open Claude Code and say:

> "Help me connect my GitHub account"

Your assistant will:
1. Ask whether you want read-only or read + write (if you haven't already decided)
2. Ask you to paste the access key you copied in Step 2
3. Save the connection details securely on your computer
4. Ask you to fully close Claude Code and open it again
5. Verify the connection by greeting you with your GitHub username

> **After setup, fully close Claude Code and open it again** — not just the window, the whole app. That is how the new connection becomes active.

---

## What Your Assistant Can Do Now

Once set up, you can ask your assistant things like:

| Category | Example prompts |
|---|---|
| **Repos** | *"What repos do I have?"* / *"Show me the README of acme/widget"* / *"What's in the src folder of acme/widget?"* |
| **Code Search** | *"Find everywhere we call `loginUser` in acme/widget"* / *"Search for TODO comments in my repos"* |
| **Issues** | *"Show me open issues in acme/widget"* / *"Create an issue called 'Login flow is broken' with these details…"* / *"Show me issue #42"* |
| **Pull Requests** | *"Show me open PRs in acme/widget"* / *"Review PR #42 — what does it change?"* / *"Create a PR from feat/login to main"* |
| **Commits** | *"Show me the last 10 commits in acme/widget"* / *"What changed in commit abc123?"* |
| **Releases** | *"What's the latest release of acme/widget?"* / *"List the last 5 releases"* |
| **GitHub Actions** | *"Show me failed CI runs on acme/widget"* / *"Why did run #456 fail?"* |
| **Notifications** | *"Show me my GitHub notifications"* / *"Dismiss the notification about PR #42"* |
| **Account** | *"Who am I connected as?"* / *"What teams am I in?"* |

---

## Keeping Your Connection Active

GitHub fine-grained access keys **expire** based on the length you chose in Step 2:

- **If you chose 90 days**, GitHub will email you when it is about to expire. When that happens:
  1. Go to **https://github.com/settings/personal-access-tokens**
  2. Click **Claude Assistant**
  3. Click **Regenerate token** (or create a new one with the same permissions)
  4. Copy the new key
  5. Come back to Claude Code and say: *"I have a new GitHub access key"*
  6. Your assistant will walk you through updating the connection
- **If you chose No expiration**, the key stays valid until you revoke it. Your assistant will keep working silently in the background with no re-setup needed.

> **If your assistant ever says your connection has expired**, that is the signal to renew the key using the steps above.

---

## Adding More Permissions Later

If your assistant says it needs extra permissions for something:

1. Go to **https://github.com/settings/personal-access-tokens** and click on **Claude Assistant**
2. Scroll to **Repository permissions**
3. Change the relevant permission (e.g. **Issues** from Read-only to Read and write)
4. Click the green **Update** button at the bottom and confirm
5. Go back to Claude Code and try your request again — no restart needed

---

## Troubleshooting

### Setup problems

| Problem | Fix |
|---|---|
| Can't find the fine-grained token page | Go directly to **https://github.com/settings/personal-access-tokens/new** — if it still shows "classic tokens", check the URL says `personal-access-tokens` (plural, with hyphens) |
| Can't find Repository permissions | They are below Expiration and Repository access — keep scrolling. Make sure you are on the fine-grained page, not the classic one |
| Generate token button is greyed out | You need to pick at least one repository permission above the defaults — usually **Contents (Read-only)** is enough |
| Lost the access key after closing the page | GitHub only shows the key once — go back to the URL in Step 2 and create a new one with the same settings |

### Authentication problems

| Problem | Fix |
|---|---|
| "Your GitHub connection has expired" | The access key was revoked or expired. Create a new one (see **Step 2**) and tell your assistant: *"I have a new GitHub access key."* |
| "Bad credentials" error | Same as above — the key is no longer valid |
| "I need an extra permission" | See **Adding More Permissions Later** above. Your assistant will tell you which permission to change |

### After setup

| Problem | Fix |
|---|---|
| Assistant says GitHub isn't connected right after setup | Fully close Claude Code (not just the window — the whole app) and open it again. The connection only activates after a full restart |
| "I can't see that repo" | Either the repo name is slightly off, or your access key was set up with **Only select repositories** and that repo isn't on the list. Widen **Repository access** on your access key |
| Assistant is rate-limited ("GitHub is asking me to slow down") | GitHub caps fine-grained tokens at 5,000 requests per hour. Wait a minute and try again — this is very rare in normal use |
| Can't find the right repo when you say "my widget repo" | Tell your assistant the full name, e.g. *"acme/widget"* — GitHub repos are identified as `owner/repo` |

---

## Security Notes

- Your GitHub access key is stored locally on your computer in a settings file — it is never sent to third parties
- The key can be revoked at any time from **https://github.com/settings/personal-access-tokens**
- Your assistant will always confirm with you before creating, updating, or deleting anything
- Merges are double-confirmed because they are irreversible
- No OAuth, no browser redirects, no client secrets — just a single fine-grained access key
- The connection uses the official GitHub remote MCP server maintained by GitHub at `api.githubcopilot.com/mcp`
- Fine-grained access keys are safer than classic tokens — they let you limit access to specific repos and specific permissions, so if a key is ever leaked the blast radius is small

---

## What Is NOT Included (Yet)

This connector focuses on **everyday GitHub work** — repos, issues, pull requests, code search, releases, Actions, notifications, and security alerts.

The following are **not included** in this version and will be added in a future update if needed:

- GitHub Enterprise Server (requires a local container setup with a different hostname)
- Organization admin operations (billing, member management, SSO config)
- Deleting repositories (use the GitHub website — irreversible)
- GitHub App management and installation
- Webhook configuration
- Classic Personal Access Tokens (we use the safer fine-grained tokens)

If you need any of these, let your assistant know and they can check if support has been added.

---

## Still Having Trouble?

See [TROUBLESHOOTING.md](../troubleshoot.md) for more fixes, or ask your assistant:
> "Something went wrong with my GitHub connection. Help me fix it."

For known limitations (read-only tokens, Enterprise Server, rate limits), see [known-issues/GITHUB-REMOTE-MCP-CAVEATS.md](../known-issues/GITHUB-REMOTE-MCP-CAVEATS.md).

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
