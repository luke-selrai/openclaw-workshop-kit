---
name: gcloud-connector
description: Install and configure the Google Cloud CLI (gcloud) on the user's laptop. Use this skill when the user asks to set up GCP, connect Google Cloud, use BigQuery, Cloud Storage, Cloud Run, or any Google Cloud service locally. Handles installation, authentication, and project setup conversationally.
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - gcp
    - google-cloud
    - gcloud
    - bigquery
    - cloud-storage
    - installer
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting gcloud auth or permission errors
---

# Google Cloud CLI Connector

## Overview

This skill does two things:
1. **Installs** the `gcloud` CLI on the user's computer (one-time setup)
2. **Operates** the CLI — interacting with GCP services (BigQuery, Cloud Storage, Cloud Run, etc.)

> **This is for local laptop setup only.** Server/VM provisioning lives in [claude-cloud-kit](https://github.com/selrai-company/claude-cloud-kit).

---

## Part 1 — Installation

Guide conversationally — one step at a time:

### Step 1: Check if already installed

Run `gcloud --version`. If it returns a version number, say:
> "Google Cloud is already installed on your computer. Let me check if you're signed in."

Skip to Part 2.

If "command not found", say:
> "We need to install the Google Cloud command-line tool first. This will take about a minute."

### Step 2: Install based on OS

Detect OS with `uname -s` (or check if PowerShell is available for Windows).

**macOS (Homebrew) — say:**
> "I'm going to install the Google Cloud tool using Homebrew."

```bash
brew install --cask google-cloud-sdk
```

After install, restart the shell or run:
```bash
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
```

If Homebrew is not installed, say:
> "I'll download the installer directly from Google instead."

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Linux — say:**
> "I'm going to download and install the Google Cloud tool."

```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows — say:**
> "I'll need you to download the installer. Open this link in your browser: https://cloud.google.com/sdk/docs/install#windows — then run it and click through the steps. Let me know when it's done."

### Step 3: Verify

Run `gcloud --version`. If it works, say:
> "That worked! Google Cloud is installed. Now let's sign you in."

If it still fails after install, say:
> "The terminal needs a refresh. Please close this terminal and open a new one, then tell me to continue."

---

## Part 2 — Authentication

### Step 4: Log in

Say:
> "I'm going to sign you in to Google Cloud now. A browser window will open — sign in with your Google account."

```bash
gcloud auth login
```

**If the browser opens** — wait for the user to sign in and click Allow. After success, say:
> "You're signed in. Now let's set your default project."

**If the browser does not open** — say:
> "A link appeared in the terminal. Copy it, open it in your browser, sign in with your Google account, and click Allow."

For headless/remote environments:
```bash
gcloud auth login --no-browser
```

This prints a command to run on another machine with a browser.

### Step 5: Set default project

Run:
```bash
gcloud projects list
```

**If one project** — set it automatically and say:
> "You have one project. I've set it as your default."

```bash
gcloud config set project <project-id>
```

**If multiple projects** — say:
> "You have a few projects. Which one would you like to use as your default?"

Show the list and let the user pick.

**If no projects** — say:
> "You don't have a Google Cloud project yet. You'll need to create one at https://console.cloud.google.com. Would you like me to help you with that?"

Use Playwright to guide them through the console if needed.

### Step 6: Verify

Run:
```bash
gcloud config list
```

If it shows the account and project, say:
> "That worked! You're connected to Google Cloud with the [project name] project. Your Google Cloud is ready to go."

---

## Part 3 — What to Try First

After setup, suggest simple tasks:

> "Want to try something? Here are a few things I can do with your Google Cloud:"

```
"Show me my Cloud Storage buckets."
"What projects do I have?"
"List my Compute Engine VMs."
```

Say:
> "Start with something simple. Once you're comfortable, I can help with more complex tasks like deploying apps or querying BigQuery."

---

## Part 4 — Common Operations

### BigQuery

```bash
# List datasets
gcloud bq datasets list

# Run a query
bq query --use_legacy_sql=false 'SELECT * FROM `project.dataset.table` LIMIT 10'
```

> BigQuery commands use the `bq` tool which is bundled with the gcloud SDK.

### Cloud Storage

```bash
# List buckets
gcloud storage ls

# List files in a bucket
gcloud storage ls gs://bucket-name/

# Download a file
gcloud storage cp gs://bucket-name/file.csv ./file.csv

# Upload a file
gcloud storage cp ./local-file.csv gs://bucket-name/
```

### Cloud Run

```bash
# List services
gcloud run services list

# Deploy a service
gcloud run deploy SERVICE_NAME --source . --region REGION
```

### Compute Engine

```bash
# List VMs
gcloud compute instances list

# SSH into a VM
gcloud compute ssh INSTANCE_NAME --zone ZONE
```

### App Engine

```bash
# Deploy
gcloud app deploy

# View logs
gcloud app logs tail
```

---

## Part 5 — Application Default Credentials

Some tools and libraries need Application Default Credentials (ADC). If the user is running code locally that accesses GCP APIs, say:
> "Your code needs a different type of sign-in. I'll set that up now."

```bash
gcloud auth application-default login
```

This is needed when:
- Using client libraries (Python, Node.js, Go, Java)
- Running code locally that accesses GCP APIs
- Using Terraform with GCP

---

## Part 6 — Auth & Session

```bash
# Check who is signed in
gcloud auth list

# Check current config
gcloud config list

# Switch accounts
gcloud config set account another@gmail.com

# Log out
gcloud auth revoke

# Log back in
gcloud auth login

# Switch projects
gcloud config set project other-project-id

# List all available projects
gcloud projects list
```

---

## Part 7 — Troubleshooting

| Problem | Fix |
|---|---|
| `gcloud: command not found` | Shell needs restart — run `exec -l $SHELL` or open a new terminal |
| `ERROR: (gcloud.auth.login) could not open browser` | Copy the URL from terminal and open it manually in a browser |
| `ERROR: The project property is set to the empty string` | Run `gcloud config set project <project-id>` |
| `ERROR: PERMISSION_DENIED` | User's Google account doesn't have access — check IAM at console.cloud.google.com |
| `ERROR: Billing account not enabled` | Project needs billing — link at console.cloud.google.com/billing |
| `Could not find project` | Check spelling of project ID (not name) with `gcloud projects list` |
| Auth works but commands fail | Try `gcloud auth application-default login` — some APIs need ADC |
| `WARNING: Cannot find installation directory` | Reinstall: `curl https://sdk.cloud.google.com | bash` |

When an error occurs, say:
> "No problem — let me try a different way."

Then diagnose and fix. Never show raw error messages to the user — translate them into plain English.

---

## Part 8 — Playwright Fallback

Use Playwright when:
- The browser does not open automatically during `gcloud auth login`
- The user needs help navigating the GCP Console (e.g. creating a project, enabling billing, granting IAM roles)

### Auth fallback
```
Navigate to the URL printed by gcloud auth login
Sign in with the user's Google account → click Allow
```

### Console navigation
```
Navigate to: https://console.cloud.google.com
Help the user find: IAM, Billing, APIs & Services, or project creation
```

Always try the CLI command first. Only switch to Playwright if the CLI returns an error or the user needs help in the console.

---

## Behaviour Guidelines

- **Always run `gcloud auth list` first** at the start of a session to confirm the user is signed in.
- **Confirm before destructive actions** — deleting resources, stopping VMs, removing IAM bindings.
- **Project context matters** — always check `gcloud config get-value project` before running commands.
- **Auth errors** → `gcloud auth login` or `gcloud auth application-default login`.
- **gcloud not found** → restart shell or reinstall.
- **Billing required** → direct user to console.cloud.google.com/billing.
- **One step at a time** — do not dump all instructions at once. Say what to do, wait, then give the next step.
