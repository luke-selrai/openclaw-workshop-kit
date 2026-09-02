---
name: github-connector
description: "Connect GitHub to Claude by installing and signing in to the `gh` CLI. Use when the user asks to set up or connect GitHub, or wants GitHub work (repositories, issues, pull requests, commits, releases, Actions runs, code search) and the `gh` CLI isn't signed in yet. Once connected, GitHub runs directly through the `gh` CLI."
allowed-tools: Bash, Read, Write, Edit, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Developer Tools & Integrations
  tags:
    - github
    - git
    - repositories
    - issues
    - pull-requests
    - actions
    - cli
    - gh
  pairs-with:
    - skill: github-provision
      reason: "External (full-stack-builder-pack) - the install-day foundation step that creates the GitHub account, installs git and `gh`, and sets the git identity. This skill adopts the sign-in that skill leaves behind and never repeats its work"
    - skill: github-actions-pipeline-builder
      reason: Complementary - that skill designs GitHub Actions workflows, this skill operates them (`gh run`, `gh workflow`)
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting GitHub sign-in or request errors
---

# GitHub Connector

> **Install pattern:** CLI-based (first-party CLI + browser sign-in), like `notion-connector` (`ntn`), `quickbooks-connector` (`qbo`) and `google-chat-connector` (`gws`). **Not** a hosted-MCP, bearer-token or plugin connector - see [skills/CLAUDE.md](../CLAUDE.md) for the CLI-based column of the description template.

## Overview

This skill connects and operates a user's GitHub account through the **official GitHub CLI**, `gh` (https://cli.github.com), signed in over HTTPS. It has three phases:

- **Phase 0 - Resume check (silent).** `gh auth status`. A machine that is already signed in is already connected: adopt it, never sign it out, never re-authenticate.
- **Phase 1 - Install & sign in.** Claude installs `gh` if it is missing, runs `gh auth login -h github.com --web --git-protocol https -s repo,workflow,user`, reads the one-time code the command prints, and shows it to the user. The user enters that code in the browser and clicks **Authorize github**. Claude then runs `gh auth setup-git` so pushes over HTTPS authenticate, and verifies. The access key is stored by `gh` in the operating system's keychain - never in a file this skill writes, never in `~/.claude.json`.
- **Phase 2 - Operate.** Claude runs `gh` commands to read and change repositories, issues, pull requests, Actions runs, releases and everything else on the user's behalf.

The only manual moments for the user are signing in to GitHub if the browser is signed out, and the one **Authorize github** click. A grant click is always theirs - it is never automated.

### Why the `gh` CLI

The built-in GitHub connector in claude.ai's connector directory, and GitHub's remote MCP server at `api.githubcopilot.com/mcp`, are **deliberately not used by this kit** - the command line is faster and lighter for clients. Beyond that:

1. **No secret ever lands in a file this skill controls.** `gh auth login` stores the access key in the OS keychain (macOS Keychain, Windows Credential Manager, Linux Secret Service; it falls back to `~/.config/gh/hosts.yml` where no keychain exists). There is no `Authorization: Bearer …` line in `~/.claude.json` - the leak-prone shape this skill used to have.
2. **Works in any session.** A CLI runs the same whether or not a tool surface has reconciled. There is no "close and reopen Claude Code before the tools appear" step.
3. **One sign-in, two jobs.** The same sign-in that lets Claude read and write GitHub also authenticates `git push` over HTTPS (`gh auth setup-git`), so committing and pushing work in the same breath as opening the pull request.
4. **It is already there.** The install-day foundation step (`github-provision`, from the full-stack-builder-pack) signs `gh` in on the same machine. Phase 0 adopts that sign-in rather than creating a second one.

> If you ever find yourself adding an `mcpServers.github` entry with a Bearer key to `~/.claude.json`, **stop** - that is the path this skill replaced. Use `gh auth login` instead.

### What this skill does NOT use

- **The built-in claude.ai GitHub connector and GitHub's remote MCP server** (`https://api.githubcopilot.com/mcp`) - as above, out of scope for this kit by choice, not by limitation.
- **A minted Personal Access Token pasted into a config file.** No browser walk through `github.com/settings/personal-access-tokens/new`, no reading a key out of a page, no `Authorization: Bearer` header. `gh auth login` replaces all of it.
- **`@modelcontextprotocol/server-github`** - this old npm package is **deprecated as of April 2025**. Do not use it.
- **Docker / `ghcr.io/github/github-mcp-server`** - the local container version requires Docker Desktop installed and running. Not needed; `gh` covers the same ground.
- **A GitHub App with Client ID / Client Secret / redirect URI.** `gh` is GitHub's own first-party client and already has one; the sign-in below rides it.

### What this skill leaves to `github-provision`

`github-provision` (external, in the `full-stack-builder-pack`) owns the install-day foundation:

- **Creating a GitHub account.** A machine with no GitHub account at all is that skill's job, not this one's. Say so and route there rather than walking a signup here.
- **Setting the git identity** (`git config --global user.name` / `user.email`, including the `<id>+<login>@users.noreply.github.com` noreply address when the profile email is private).
- **Confirming the primary email is verified.**

This skill assumes the account exists. Where Phase 0 or Phase 1 turns up "no GitHub account anywhere on this machine", hand off in one line: *"There's no GitHub account here yet - the setup step that creates one should run first."*

### GitHub Enterprise Server

Deferred. `gh` **can** sign in to a GHES host (`gh auth login -h <your-host>`) and every command below takes `--hostname` / `-R <host>/<owner>/<repo>`, but this skill's flow pins `github.com`. Treat GHES as out of scope for this version.

---

## Security and credential rules

- **Never print the access key.** Never run `gh auth token`, never read back `~/.config/gh/hosts.yml`, never echo the key into narration, a tool return, or a log file. `gh` holds it; this skill never needs to see it.
- **The one-time sign-in code is not a credential.** It is a short-lived pairing code that GitHub only accepts from a browser signed in as the user, and it expires in about fifteen minutes. It **must** be shown to the user - that is the whole point of it. Show it plainly, once.
- **Never ask for a password.** Not in chat, not in a browser this skill drives, not "just to confirm". The password goes between the user and GitHub only.
- **The Authorize click is the user's.** Reaching the Authorize screen is Claude's job; pressing the button is not, on any path, in any browser.
- **Never paste config files into chat.** Not `~/.claude.json`, not `hosts.yml`, not `.git-credentials`.

---

## Communication rules for Phase 1

The user is a non-technical business owner or a developer who does not want to think about configuration. Claude does the work; the user signs in once and presses one button. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or hunt through settings. The only actions you ever request are "please sign in to GitHub in the window that just opened", "please type this code", "please press Authorize", and (if challenged) "please approve the prompt on your phone".
- **Plain English only.** No jargon. Never say MCP, CLI, terminal, command, bash, script, token, PAT, Bearer, HTTP, API, scope, OAuth, device code, config file, JSON, endpoint, environment variable, keychain, Playwright, browser automation, or DOM. If you must name a technical thing, name it plainly:
  - The `gh` CLI → **"the GitHub tool I use on your computer"**
  - The access key / token → **"your GitHub connection"**
  - Scopes / permissions → **"permissions"**
  - The one-time device code → **"your one-time sign-in code"**
  - `gh auth setup-git` → nothing; do it silently
  - Restart Claude Code → **"close and reopen"**
- **Narrate at action boundaries, not inside command sequences.** Tell the user once when you start, once when you need them (the code, the sign-in, the Authorize press), once when you're done. No commentary in between.
- **React to success and failure warmly.** Good: "That worked - your GitHub is now connected." Bad: "Token refreshed with scopes repo, workflow, user."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, or page-structure details** to the user. You run them; you do not describe them.
- **No fabricated UI assertions.** Don't reference button colours or specific positioning - read the live page. GitHub's sign-in pages change.
- **Never echo the access key** back to the user, in any output, ever.

---

## PHASE 0 - Resume check (silent)

Before installing anything, find out whether this machine is already signed in. `github-provision` may have done it on install day; so may the user, months ago. Either way: **adopt what is there, never re-authenticate.**

```bash
command -v gh >/dev/null 2>&1 && gh --version    # installed?
gh auth status                                    # signed in? which account? which permissions?
```

Read `gh auth status` and act on the first branch that matches:

- **Signed in to github.com, and the listed permissions include `repo` and `workflow`** → **already connected.** Prove it with one real read - `gh api user --jq .login` - then skip to Phase 2. Greet once: *"Good news - your GitHub is already connected as **@username**. Want me to look at your repositories, or your open pull requests?"*
- **Signed in, but the permissions are short of `repo`, `workflow` or `user`** → top up, do not re-login:

  ```bash
  gh auth refresh -h github.com -s repo,workflow,user
  ```

  This is the **same one-time-code moment** as Phase 1 Step 3 - the command prints a code, waits on its "Press Enter to open github.com in your browser" beat, the user enters the code and presses **Authorize github**. Run it exactly the way Step 3 runs `gh auth login`, then re-check `gh auth status` and go to Phase 2. This is a click, not a question, and it is gone by the next run.
- **Signed in to the wrong account** (several accounts on the machine, the active one is not the one the user means) → `gh auth switch` to the right one. Never sign an account out.
- **`gh` is installed but not signed in** ("You are not logged into any GitHub hosts") → Phase 1, skipping Step 1.
- **`gh` is not installed** (`command not found`) → Phase 1 from Step 1.

Also worth a silent look where the account question is open: `git config --global user.email` and `git config --global user.name`. Unset values are `github-provision`'s job, not this skill's - note it and move on.

---

## PHASE 1 - Install & sign in

### Step 1 - Install `gh` (silent)

Only if `gh --version` failed. Pick the platform's package manager:

```bash
# macOS
brew install gh

# Windows
winget install --id GitHub.cli -e

# Debian / Ubuntu
sudo apt update && sudo apt install gh
```

Notes that bite:

- **A CLI installed this run is invisible to the current shell.** Re-detect `gh --version` in a **fresh** shell invocation (a new Bash call), not the one that ran the installer. A "command not found" straight after a successful install is almost always this.
- **A Mac without Homebrew** needs Homebrew first (the one command on https://brew.sh). Warn the user once, plainly, that their computer will ask for their password for that - and stay hands-off while they type it.
- **Older Debian/Ubuntu** may carry no `gh` package. Fall back to GitHub's documented apt repository setup at https://github.com/cli/cli/blob/trunk/docs/install_linux.md, or `sudo snap install gh`.
- **Windows without winget** → `choco install gh` or `scoop install gh`.
- Any other platform → https://cli.github.com has the current install matrix. Do not invent a package name.

Verify:

```bash
gh --version     # expect e.g. "gh version 2.62.0 (2025-01-01)"
```

### Step 2 - Orient the user

One short message, before anything opens:

> "I'll connect your GitHub now. In a moment I'll give you a short code to type into a GitHub page, and then one button to press. That's your whole part - about a minute."

### Step 3 - Sign in

```bash
gh auth login -h github.com --web --git-protocol https -s repo,workflow,user
```

Three things about this command, all load-bearing:

- **`repo` and `workflow` are the pair that matters.** `repo` is read and write across repositories; `workflow` is what lets a push carry GitHub Actions files without being rejected. `user` is what makes the profile readable, which is how everything downstream identifies the account without asking.
- **`--git-protocol https`** pairs with Step 4 so `git push` authenticates through the same sign-in. Do not switch it to `ssh` - that needs a key the user does not have yet.
- **The command has one interactive beat.** It prints the one-time code and then **waits on "Press Enter to open github.com in your browser"**. Answer it - write a newline to its stdin. Backgrounding the command and only reading its output stalls there forever.

Drive it:

1. **Read the one-time code** from the command's output (an eight-character, hyphenated code such as `A1B2-C3D4`).
2. **Show the code to the user, and answer the keypress.** One message:

   > "Here's your one-time sign-in code: **A1B2-C3D4**. I'm opening the GitHub page now - type that code in, then press **Authorize github**. I'll wait."

   Then send the newline so the page opens.
3. **The user enters the code and presses Authorize github.** Stay hands-off from the moment a password, an identity challenge, or the Authorize screen is on the user's side of the glass - no reads, no screenshots, no keystrokes - until they say they're done.
4. **Wait for the command to exit.** `Logged in as <login>` closes the moment. If the user gets stuck on the page, re-read the code to them; if it has expired (GitHub says so plainly), re-run the command for a fresh one.

**Two-factor challenges** are normal on the GitHub sign-in page and happen on the user's phone or hardware key. Narrate once - *"GitHub is asking to confirm it's you - please approve the prompt on your phone"* - then wait.

**A strictly read-only connection.** `gh auth login --web` grants read **and** write; there is no read-only variant of it. Where a user explicitly wants a key that cannot write, create a read-only fine-grained personal access token on GitHub and sign in with it instead:

```bash
gh auth login -h github.com --with-token < <(printf '%s' "$TOKEN")
gh auth setup-git
```

Say plainly what that costs: no creating issues, no opening or merging pull requests, no pushes. Otherwise, the safer default is the standard sign-in **plus** the confirm-before-write discipline in [Behaviour Guidelines](#behaviour-guidelines-phase-2) - which is where read-only-by-default actually lives in this skill.

### Step 4 - Wire up pushes (silent)

```bash
gh auth setup-git
```

Idempotent, silent, no prompts. It makes `git push` over HTTPS authenticate through the sign-in instead of stopping on a username prompt no session can answer. Skipping it is the cause of `could not read Username for 'https://github.com'` later.

### Step 5 - Verify

```bash
gh auth status --active     # the account, and the permissions the sign-in carries
gh api user --jq '.login'   # a real read - only a real answer counts
```

Pass = an active `github.com` account, permissions listing `repo` and `workflow` (and `user`), and a login name returned. A command that errors here is not "connected". Re-run Step 3 once; if it persists, translate to plain English and stop.

### Step 6 - Hand off

> "All done - your GitHub is connected as **@username**. You can ask me things like *'show me my repositories'*, *'list the open issues in acme/widget'*, or *'what pull requests are waiting on me?'*. Give it a try!"

Three prompts, no more. Do not list what else is possible - Phase 2 has it.

### If a sign-in error needs a browser (contingency)

The happy path above needs no driven browser at all - `gh` opens the user's own. Where it does not (a headless machine, a broken default-browser handler), a Playwright browser the user is **already signed in to** may be used to reach `https://github.com/login/device` and **type the one-time code**. Nothing more:

- **Never type the password** into a driven browser. Hands off the moment a credential field is on screen.
- **Never press Authorize github** in a driven browser. Reaching the page is Claude's; the grant is the user's, on every rung.
- **Never read a key out of a page.** There is no key on any page in this flow.

If `mcp__playwright__*` / `mcp__plugin_playwright_playwright__*` tools are not reachable, install Playwright per [skills/CLAUDE.md](../CLAUDE.md) → "Playwright MCP install contingency", ask the user to close and reopen Claude Code once, then retry.

---

## PHASE 2 - Operate (the `gh` command surface)

Everything below runs through `gh`. Two flags carry most of the weight:

- **`-R owner/repo`** targets a repository regardless of the current directory. Use it whenever the working directory is not the repo in question - which, in a workshop, is most of the time.
- **`--json <fields> --jq '<filter>'`** returns exactly the fields needed instead of a wall of text. Prefer it over dumping raw output. `gh <command> --json` with no value lists that command's available fields.

`gh api` is the escape hatch: it speaks the whole of GitHub's REST surface (`gh api repos/{owner}/{repo}/…`, `--method POST|PATCH|PUT|DELETE`, `-f key=value` for fields, `--jq` for filtering) and, via `gh api graphql -f query='…'`, everything REST does not reach. Anything the tables below do not name has a `gh api` form.

### Who am I

| What you need | Command |
|---|---|
| The signed-in user's profile | `gh api user` |
| Just the login name | `gh api user --jq '.login'` |
| The sign-in's account and permissions | `gh auth status --active` |
| The user's teams | `gh api user/teams --jq '.[].slug'` |
| Members of an org team | `gh api orgs/<org>/teams/<team-slug>/members --jq '.[].login'` |
| The user's organisations | `gh org list` (or `gh api user/orgs`) |

### Repositories

| What you need | Command | Notes |
|---|---|---|
| List the user's repos | `gh repo list <owner> --limit 30` | omit `<owner>` for the signed-in user |
| Search repos across GitHub | `gh search repos "<query>" --limit 20` | |
| Repo details | `gh repo view owner/repo` | `--json name,description,defaultBranchRef,visibility` for fields |
| Read a file | `gh api -H "Accept: application/vnd.github.raw" repos/<owner>/<repo>/contents/<path>` | raw file body |
| List a directory | `gh api repos/<owner>/<repo>/contents/<path> --jq '.[].name'` | |
| Full file tree | `gh api "repos/<owner>/<repo>/git/trees/<branch>?recursive=1" --jq '.tree[].path'` | large repos: filter, don't dump |
| List branches | `gh api repos/<owner>/<repo>/branches --jq '.[].name'` | |
| Recent commits | `gh api "repos/<owner>/<repo>/commits?per_page=20" --jq '.[] \| .sha[0:7] + " " + .commit.message'` | |
| One commit | `gh api repos/<owner>/<repo>/commits/<sha>` | |
| Code search | `gh search code "<term>" --repo owner/repo --limit 20` | drop `--repo` to search all of GitHub |
| Clone a repo | `gh repo clone owner/repo <dir>` | |
| Create a repo | `gh repo create <name> --private --source=. --push` | **confirm first** |
| Fork a repo | `gh repo fork owner/repo --clone` | **confirm first** |
| Create a branch | `git switch -c <name>` locally, or `gh api repos/<owner>/<repo>/git/refs --method POST -f ref=refs/heads/<name> -f sha=<base-sha>` | **confirm first** |
| Add or edit one file | edit locally, then `git add`, `git commit`, `git push` | **confirm first**; `gh api --method PUT repos/<owner>/<repo>/contents/<path>` is the no-clone form |
| Commit several files | `git add …`, `git commit`, `git push` | **confirm first** - one commit, one push |
| Delete a file | `git rm <path>`, `git commit`, `git push` | **confirm first** |
| Open the repo in a browser | `gh browse -R owner/repo` | |

### Issues

| What you need | Command | Notes |
|---|---|---|
| List issues | `gh issue list -R owner/repo --state open --limit 30` | `--label`, `--assignee`, `--author` to narrow |
| Search issues | `gh search issues "<query>" --limit 20` | GitHub search syntax |
| Read an issue | `gh issue view <number> -R owner/repo --comments` | `--json title,body,labels,assignees,state` for fields |
| Create an issue | `gh issue create -R owner/repo --title "…" --body "…"` | **confirm first**; `--label`, `--assignee`, `--project` |
| Edit an issue | `gh issue edit <number> -R owner/repo --title/--body/--add-label/--add-assignee` | **confirm first** |
| Comment on an issue | `gh issue comment <number> -R owner/repo --body "…"` | **confirm first** |
| Close / reopen an issue | `gh issue close <number> -R owner/repo` / `gh issue reopen <number> -R owner/repo` | **confirm first** |
| Sub-issues | `gh api repos/<owner>/<repo>/issues/<number>/sub_issues` (add: `--method POST -F sub_issue_id=<id>`) | **confirm first** |
| Issue types configured in an org | `gh api orgs/<org>/issue-types --jq '.[].name'` | |
| Labels | `gh label list -R owner/repo`; `gh label create`, `gh label edit`, `gh label delete` | writes: **confirm first** |

### Pull requests

| What you need | Command | Notes |
|---|---|---|
| List PRs | `gh pr list -R owner/repo --state open --limit 30` | |
| Search PRs | `gh search prs "<query>" --limit 20` | |
| PRs waiting on the user | `gh pr status -R owner/repo` | created / assigned / review-requested |
| Read a PR | `gh pr view <number> -R owner/repo` | `--json files,reviews,commits,statusCheckRollup` |
| A PR's diff | `gh pr diff <number> -R owner/repo` | `--name-only` for just the files |
| Create a PR | `gh pr create -R owner/repo --base main --head <branch> --title "…" --body "…"` | **confirm first**; ready for review, never `--draft`, unless the user asks |
| Edit a PR | `gh pr edit <number> -R owner/repo --title/--body/--base/--add-reviewer` | **confirm first** |
| Merge a PR | `gh pr merge <number> -R owner/repo --squash` | **DOUBLE-CONFIRM - irreversible.** Squash is this kit's default; branches are not auto-deleted |
| Sync a PR branch with its base | `gh pr update-branch <number> -R owner/repo` | **confirm first** |
| Review a PR | `gh pr review <number> -R owner/repo --approve` / `--request-changes --body "…"` / `--comment --body "…"` | **confirm first** |
| Comment on a specific line | `gh api repos/<owner>/<repo>/pulls/<number>/comments --method POST -f body=… -f commit_id=… -f path=… -F line=…` | **confirm first** |
| Reply in a review thread | `gh api repos/<owner>/<repo>/pulls/<number>/comments/<comment-id>/replies --method POST -f body="…"` | **confirm first** |
| Check a PR's CI | `gh pr checks <number> -R owner/repo` | `--watch` to follow live |
| Mark a draft ready | `gh pr ready <number> -R owner/repo` | **confirm first** |
| Check out a PR locally | `gh pr checkout <number> -R owner/repo` | |

### Actions (workflows and runs)

| What you need | Command | Notes |
|---|---|---|
| Recent runs | `gh run list -R owner/repo --limit 20` | `--status failure`, `--workflow <file>`, `--branch <name>` |
| One run | `gh run view <run-id> -R owner/repo` | |
| Why a run failed | `gh run view <run-id> -R owner/repo --log-failed` | the failed steps' logs only |
| Full logs | `gh run view <run-id> -R owner/repo --log` | large - filter before showing |
| Follow a run live | `gh run watch <run-id> -R owner/repo` | |
| Re-run | `gh run rerun <run-id> -R owner/repo --failed` | **confirm first** |
| Cancel a run | `gh run cancel <run-id> -R owner/repo` | **confirm first** |
| List workflows | `gh workflow list -R owner/repo` | |
| Trigger a workflow | `gh workflow run <file-or-name> -R owner/repo -f key=value` | **confirm first**; needs `workflow_dispatch` on the workflow |
| Enable / disable a workflow | `gh workflow enable` / `gh workflow disable` | **confirm first** |
| Repository secrets and variables | `gh secret set <NAME> -R owner/repo` (value on stdin), `gh variable set <NAME> -R owner/repo` | **confirm first**; never echo the value |
| Actions caches | `gh cache list -R owner/repo`, `gh cache delete` | |

### Releases and tags

| What you need | Command |
|---|---|
| List releases | `gh release list -R owner/repo` |
| The latest release | `gh release view -R owner/repo` |
| A release by tag | `gh release view <tag> -R owner/repo` |
| Create a release | `gh release create <tag> -R owner/repo --title "…" --notes "…"` - **confirm first** |
| Attach a file to a release | `gh release upload <tag> <file> -R owner/repo` - **confirm first** |
| List tags | `gh api repos/<owner>/<repo>/tags --jq '.[].name'` |
| One tag | `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` |

### Search

| What you need | Command |
|---|---|
| Code | `gh search code "<term>" --limit 20` |
| Repositories | `gh search repos "<query>" --limit 20` |
| Issues | `gh search issues "<query>" --limit 20` |
| Pull requests | `gh search prs "<query>" --limit 20` |
| Users | `gh search users "<query>" --limit 20` |
| Commits | `gh search commits "<query>" --limit 20` |

### Everything else, via `gh api`

| Area | Command |
|---|---|
| Notifications (inbox) | `gh api notifications --jq '.[] \| .subject.title'`; mark all read: `gh api --method PUT notifications` - **confirm first** |
| Dismiss one notification | `gh api --method PATCH notifications/threads/<thread-id>` - **confirm first** |
| Gists | `gh gist list`, `gh gist view <id>`, `gh gist create <file>`, `gh gist edit <id>` - writes **confirm first** |
| Projects (v2) | `gh project list --owner <owner>`, `gh project view <number>`, `gh project item-list <number>`, `gh project item-create` - writes **confirm first** |
| Discussions | `gh api graphql -f query='…'` - Discussions are GraphQL-only; there is no first-class `gh discussion` command |
| Code scanning alerts | `gh api repos/<owner>/<repo>/code-scanning/alerts` |
| Dependabot alerts | `gh api repos/<owner>/<repo>/dependabot/alerts` |
| Secret scanning alerts | `gh api repos/<owner>/<repo>/secret-scanning/alerts` |
| Security advisories | `gh api advisories` (global), `gh api repos/<owner>/<repo>/security-advisories` |
| Star / unstar a repo | `gh api --method PUT user/starred/<owner>/<repo>` / `--method DELETE` - **confirm first**; list: `gh api user/starred --jq '.[].full_name'` |
| Ask Copilot to review a PR | `gh pr edit <number> -R owner/repo --add-reviewer <copilot-reviewer-handle>` - **confirm first**; assigning the Copilot coding agent to an issue is a `gh api graphql` mutation |
| Rate limit remaining | `gh api rate_limit --jq '.rate'` |
| Repository rulesets | `gh ruleset list -R owner/repo`, `gh ruleset view` |

> **Note:** if a command errors with `unknown command`, this machine's `gh` is older than the subcommand. Check `gh --version`, offer to update (`brew upgrade gh` / `winget upgrade --id GitHub.cli`), and in the meantime use the `gh api` form of the same job - the REST surface does not move.

---

## Prompt-to-command mapping

| What the user says | Command |
|---|---|
| "What repos do I have?" | `gh repo list --limit 30` |
| "Show me open issues in acme/widget" | `gh issue list -R acme/widget --state open` |
| "Find issues about login bug" | `gh search issues "login bug" --limit 20` |
| "Create an issue in acme/widget saying X" | `gh issue create -R acme/widget --title "X" --body "…"` - **confirm first** |
| "Close issue 12 in acme/widget" | `gh issue close 12 -R acme/widget` - **confirm first** |
| "Show me open PRs in acme/widget" | `gh pr list -R acme/widget --state open` |
| "Review PR #42 in acme/widget" | `gh pr view 42 -R acme/widget` then `gh pr diff 42 -R acme/widget` |
| "Create a PR from feat/foo to main" | `gh pr create -R acme/widget --base main --head feat/foo --title "…" --body "…"` - **confirm first** |
| "Merge PR #42" | `gh pr merge 42 -R acme/widget --squash` - **DOUBLE-CONFIRM** |
| "Is PR #42 passing?" | `gh pr checks 42 -R acme/widget` |
| "Show me recent commits in acme/widget" | `gh api "repos/acme/widget/commits?per_page=20"` |
| "Search for `useState` in acme/widget" | `gh search code "useState" --repo acme/widget` |
| "Show me the README of acme/widget" | `gh api -H "Accept: application/vnd.github.raw" repos/acme/widget/contents/README.md` |
| "What's the latest release of acme/widget?" | `gh release view -R acme/widget` |
| "Create a branch called feat/foo in acme/widget" | `git switch -c feat/foo` (in a clone) - **confirm first** |
| "Push this file to acme/widget" | `git add`, `git commit`, `git push` - **confirm first** |
| "Show me failed GitHub Actions runs on acme/widget" | `gh run list -R acme/widget --status failure --limit 20` |
| "Why did the CI fail on run 12345?" | `gh run view 12345 -R acme/widget --log-failed` |
| "Who am I connected as?" | `gh api user --jq '.login'` |
| "Show me my notifications" | `gh api notifications` |
| "Star this repo" | `gh api --method PUT user/starred/acme/widget` - **confirm first** |
| "Connect my GitHub" / "Help me set up GitHub" | **Run Phase 0, then Phase 1 if needed** |
| "I don't have a GitHub account" | Route to `github-provision` - account creation is not this skill |

---

## Error handling (Phase 2)

When a `gh` command fails, diagnose and respond in plain English. Never show raw error output.

| Error | What to say | How to fix |
|---|---|---|
| `You are not logged into any GitHub hosts` | "Your GitHub connection isn't set up yet - let me sort that." | Run Phase 1 |
| `HTTP 401: Bad credentials` | "Your GitHub connection has expired or was revoked - let me reconnect you." | Re-run Phase 1 Step 3 (`gh auth login`), then Step 4 and Step 5 |
| `HTTP 403` / `must have admin rights` / a missing-permission message | "I need an extra permission to do that - one moment." | `gh auth refresh -h github.com -s <the missing permission>` - same one-time-code moment as Phase 1 Step 3. Never a re-login |
| `HTTP 404` on a repo the user owns | "I can't see that repo. Either the name is slightly off, or this connection doesn't reach it." | Correct the name (`gh repo list <owner>` to find it), or check `gh auth status` is on the right account - `gh auth switch` if not |
| `HTTP 422 Unprocessable Entity` | "GitHub rejected that - the details may not be valid. Let me check and try again." | Read the message, fix the input, retry once |
| `HTTP 429` / `secondary rate limit` | "GitHub is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds, retry once. `gh api rate_limit` shows what's left. If still limited, tell the user and suggest a minute |
| `command not found: gh` | "One small install and we're going." | Phase 1 Step 1 - and re-detect in a **fresh** shell |
| `unknown command` / `unknown flag` | (nothing - handle silently) | This `gh` is older than the subcommand. Use the `gh api` equivalent, and offer an update |
| `could not read Username for 'https://github.com'` on a push | "Let me fix how your computer talks to GitHub." | `gh auth setup-git` was never run - run it (Phase 1 Step 4), then retry the push |
| `GH007: Your push would publish a private email address` | "GitHub is protecting your email address - one moment." | Set the noreply address (`github-provision` territory): `git config --global user.email "<id>+<login>@users.noreply.github.com"`, then retry |
| `refusing to allow ... to create or update workflow` | "I need one more permission to change your automations." | The sign-in is missing `workflow` - `gh auth refresh -h github.com -s repo,workflow,user` |
| `gh` waiting on a question the session can't answer | (nothing - handle silently) | Re-run the command with every value given as a flag (`-R`, `--title`, `--body`, `--yes`) so nothing is interactive |
| Any other failure | "Something went wrong with GitHub - let me try again." | Retry once; if it persists, run Phase 0's checks and re-verify the sign-in |

---

## Scope limitations

Through `gh` (plus `gh api`), this connector **can**:

- Read and write repositories, files, branches, commits, releases and tags
- Clone, create and fork repositories
- Create and manage issues, comments, labels and sub-issues
- Create, review, update and merge pull requests, and read their checks and diffs
- List, inspect, re-run, cancel and trigger GitHub Actions workflow runs, and read job logs
- Set repository secrets and variables
- Browse notifications and dismiss them
- Create and update gists
- Read and update Projects (v2), and read Discussions through GraphQL
- Read code scanning, Dependabot and secret scanning alerts, and security advisories
- Star and unstar repositories
- Search code, repos, issues, pull requests, commits and users
- Authenticate `git push` over HTTPS, so committing and pushing work end to end

It **cannot** (deferred or deliberately out of the sign-in's reach):

- **GitHub Enterprise Server** - `gh` supports it with `-h <your-host>`, but this skill's flow pins `github.com`. Out of scope for this version
- **Organisation admin operations** - billing, member management, SSO. Some of it is readable through `gh api`; changing it is out of scope
- **Deleting repositories** - `gh repo delete` needs the `delete_repo` permission, which this sign-in deliberately does not request. Irreversible; use GitHub's website
- **Webhook management** - `gh api repos/<owner>/<repo>/hooks` needs `admin:repo_hook`, not requested
- **GitHub App installation or management**
- **File uploads larger than GitHub's request limits** - push through git, or attach to a release with `gh release upload`
- **Creating a GitHub account, or setting the git identity** - that is `github-provision`
- **Anything the sign-in's permissions do not cover** - top up with `gh auth refresh -h github.com -s <permission>` and retry. Never re-login for this

---

## Behaviour guidelines (Phase 2)

- **Always confirm before writes** - creating issues, opening pull requests, pushing files, creating branches, creating repositories, adding comments, changing labels, setting secrets, triggering workflows. Summarise what you are about to do and wait for the user's OK before running the command.
- **Double-confirm merges.** `gh pr merge` is irreversible - re-summarise the target branch and the commit count, and ask explicitly: "Are you sure you want me to merge this into main? This cannot be undone." Wait for an explicit yes. Default to `--squash`; do not add `--delete-branch` (this kit does not auto-delete branches).
- **Read-only by default.** List and read commands (`gh issue list`, `gh pr view`, `gh run list`, `gh api …` GETs) need no confirmation - run them freely when the user asks.
- **Never echo credentials.** Never run `gh auth token`. Never print `hosts.yml`. Secret values passed to `gh secret set` go in on stdin and are never repeated back.
- **Identify repos as `owner/repo`, and pass `-R`.** If the user says "my widget repo", get their login with `gh api user --jq '.login'` and try `-R <login>/widget`; fall back to `gh repo list <login>` or `gh search repos widget`.
- **Cap output.** `--limit 10-30` on list and search commands. `gh api --paginate` walks every page - avoid it unless the user has asked for everything, and say how long it will take if you do. Summarise first, offer to show more.
- **Present data clearly.** Use `--json <fields> --jq '<filter>'` and format the result as a readable table or a short summary. Never paste raw output at the user.
- **Issue and PR numbers are integers.** Do not confuse them with commit SHAs (hex strings) or GraphQL node IDs.
- **Respect a read-only choice.** If the user asked for a read-only connection in Phase 1 and now wants a write, say so plainly - *"This connection can look but not change. Want me to upgrade it?"* - and re-run Phase 1 Step 3 if they say yes. Do not attempt the write first.
- **Rate limits.** An authenticated sign-in gets 5,000 requests an hour; code search is lower. Hitting it is rare in normal use - `gh api rate_limit` shows what's left.
- **Large repos.** Before `git/trees?recursive=1` on a repo with thousands of files, ask whether the user wants the whole tree or a filtered subset.
- **Adopt, never re-auth.** If mid-conversation something suggests the connection is stale, run Phase 0 first. A working sign-in is never torn down to build a new one.

---

## Related skills

- **github-provision** (external - `full-stack-builder-pack`): the install-day foundation step. Creates the GitHub account, installs git and `gh`, signs in with the same `repo,workflow,user` permissions, sets the git identity and confirms the primary email is verified. On a machine with both, this skill **adopts** what that one left; on a machine with no GitHub account at all, route there first.
- **github-actions-pipeline-builder**: complementary - that skill designs GitHub Actions workflows, this skill operates them (`gh run`, `gh workflow`).
- **notion-connector**, **quickbooks-connector**, **google-chat-connector**: sibling CLI-based connectors - same install-and-sign-in-to-a-first-party-CLI shape.
- **orientation**: the source pattern for conversational bootstrap; Phase 1 above follows the same rules.
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): for troubleshooting GitHub sign-in or request errors.
