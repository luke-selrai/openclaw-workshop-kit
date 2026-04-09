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
    - skill: systematic-debugging
      reason: Use for troubleshooting gcloud auth or permission errors
---

# Google Cloud CLI Connector

## Overview

This skill does two things:
1. **Installs** the `gcloud` CLI on the user's computer (one-time setup)
2. **Operates** the CLI — interacting with GCP services (BigQuery, Cloud Storage, Cloud Run, etc.)

> **This is for local laptop setup only.** Server/VM provisioning lives in [claude-cloud-kit](https://github.com/luke-selrai/claude-cloud-kit).

---

## Part 1 — Installation

### Step 1: Check if already installed

```bash
gcloud --version
```

If this returns a version number, skip to Step 3 (authentication). If "command not found", continue.

### Step 2: Install gcloud CLI

Detect the user's OS first:

```bash
uname -s
```

**macOS (Homebrew):**
```bash
brew install --cask google-cloud-sdk
```

If Homebrew is not installed, guide the user to download the installer instead:
- Go to https://cloud.google.com/sdk/docs/install
- Download the macOS package
- Run the installer and follow the prompts

After install, restart the shell or run:
```bash
source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
```

**macOS (without Homebrew):**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows (winget):**
```powershell
winget install Google.CloudSDK
```

If winget is unavailable, guide the user to download from:
https://cloud.google.com/sdk/docs/install#windows

### Step 3: Verify installation

```bash
gcloud --version
```

If this returns a version, installation is complete.

---

## Part 2 — Authentication

### Step 4: Log in

```bash
gcloud auth login
```

**This opens a browser.** The user signs in with their Google account and clicks Allow.

If the browser does not open automatically, the command will print a URL. Tell the user:
> "A link appeared in the terminal. Copy it, open it in your browser, sign in with your Google account, and click Allow."

If running in a headless/remote environment:
```bash
gcloud auth login --no-browser
```
This prints a command to run on another machine with a browser.

### Step 5: Set default project

List available projects:
```bash
gcloud projects list
```

If the user knows their project ID:
```bash
gcloud config set project <project-id>
```

If they don't know which project to use, help them pick one from the list. If the list is empty, they need to create a project at https://console.cloud.google.com.

### Step 6: Verify

```bash
gcloud config list
```

This should show the logged-in account and default project. If both appear, setup is complete.

---

## Part 3 — Common Operations

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

## Part 4 — Application Default Credentials

Some tools and libraries need Application Default Credentials (ADC) instead of user credentials. Set them up with:

```bash
gcloud auth application-default login
```

This is needed when:
- Using client libraries (Python, Node.js, Go, Java)
- Running code locally that accesses GCP APIs
- Using Terraform with GCP

---

## Part 5 — Auth & Session

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

## Part 6 — Troubleshooting

| Problem | Fix |
|---|---|
| `gcloud: command not found` | Shell needs restart — run `exec -l $SHELL` or open a new terminal |
| `ERROR: (gcloud.auth.login) could not open browser` | Copy the URL from terminal and open it manually in a browser |
| `ERROR: The project property is set to the empty string` | Run `gcloud config set project <project-id>` |
| `ERROR: PERMISSION_DENIED` | User's Google account doesn't have access to the project — check IAM at console.cloud.google.com |
| `ERROR: Billing account not enabled` | The project needs a billing account linked at console.cloud.google.com/billing |
| `Could not find project` | Check spelling of project ID (not project name) with `gcloud projects list` |
| Auth works but commands fail | Try `gcloud auth application-default login` — some APIs need ADC |
| `WARNING: Cannot find installation directory` | Reinstall: `curl https://sdk.cloud.google.com | bash` |

---

## Part 7 — Playwright Fallback

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
- **Project context matters** — always check `gcloud config get-value project` before running commands, to avoid operating on the wrong project.
- **Auth errors** → `gcloud auth login` or `gcloud auth application-default login`.
- **gcloud not found** → restart shell or reinstall.
- **Billing required** → direct user to console.cloud.google.com/billing.
