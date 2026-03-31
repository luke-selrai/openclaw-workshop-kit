---
title: Google Workspace Setup Guide — Server / Headless VM
version: 1.0
date: 2026-03-31
---

# Google Workspace — Server Setup Guide

This guide is for setting up Google Workspace on a **Linux server or GCP VM that has no desktop or browser**. You will do this once per user on the server.

For laptop/desktop setup, see [GOOGLE-WORKSPACE-SETUP.md](GOOGLE-WORKSPACE-SETUP.md).

---

## What You Need Before Starting

- SSH access to the server (via `gcloud compute ssh` or similar)
- `gcloud` CLI installed on your **local laptop**
- A Google account for each user you are setting up

---

## Overview

Because the server has no browser, authentication works like this:

1. **`gcloud auth login --no-launch-browser`** — prints a URL you open on your laptop, then paste a code back. No tunnel needed.
2. **`gws auth login`** — opens a URL that requires a redirect callback. You tunnel port 9966 from the server to your laptop so the callback lands on your local browser.

You repeat this process for each user.

---

## Step 1 — SSH Into the Server

Open your terminal on your laptop and connect:

```bash
gcloud compute ssh <YOUR-VM-NAME> \
  --project=<YOUR-PROJECT> \
  --zone=<YOUR-ZONE>
```

Then switch to the user you are setting up:

```bash
sudo su - developer   # replace "developer" with the actual username
```

---

## Step 2 — Install gws for This User

Install the Google Workspace CLI to the user's home directory to avoid permission errors:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
npm install -g @googleworkspace/cli
```

Verify it worked:

```bash
gws --version
```

✅ You should see a version number printed.

---

## Step 3 — Authenticate as the User's Google Account

The server normally uses its system service account, not your personal Google account. This step fixes that.

```bash
gcloud auth login --no-launch-browser
```

A long URL will be printed. Copy it and open it in your **laptop browser**. Sign in with the Google account for this user. You will receive a verification code — paste it back into the terminal and press Enter.

✅ You should see: `You are now logged in as [yourname@gmail.com]`

> **Why this step?** Without it, `gws auth setup` will fail with "permission denied" or "insufficient authentication scopes" because it tries to use the server's system account instead of your personal Google account.

---

## Step 4 — Reconnect SSH With Port Forwarding

Exit your current SSH session and reconnect with a tunnel. This allows the OAuth callback to reach your laptop browser in the next step:

```bash
# Run this on your LAPTOP
gcloud compute ssh <YOUR-VM-NAME> \
  --project=<YOUR-PROJECT> \
  --zone=<YOUR-ZONE> \
  -- -L 9966:localhost:9966
```

Switch to the user again:

```bash
sudo su - developer
source ~/.bashrc
```

---

## Step 5 — Create the Google Cloud OAuth App (First Time Only)

> **Skip this step if you have already done it for another user on this server.** The OAuth app is shared — only one needs to be created.

```bash
gws auth setup
```

When prompted for a project ID, enter something **short** (6–30 characters, lowercase, hyphens only):

```
gws-claude-assistant
```

Follow the prompts. It will automatically create a Google Cloud project and OAuth credentials.

✅ You should see: `Setup complete`

---

## Step 6 — Log In With the User's Google Account

```bash
gws auth login
```

A URL will be printed. Open it in your **laptop browser**. Sign in and click Allow. The port forwarding tunnel (port 9966) carries the OAuth callback from your laptop back to the server automatically.

✅ You should see a success message in both the browser and the terminal.

---

## Step 7 — Verify It Worked

```bash
gws auth status
```

✅ You should see the authenticated Google account listed.

Test it:

```bash
gws gmail messages list --max-results 5
```

---

## Step 8 — Repeat for Each Additional User

For every other user on the server (e.g. `cx559824`, `alice`, `bob`):

1. `sudo su - <username>`
2. Repeat Steps 2–3 (install gws, `gcloud auth login --no-launch-browser`)
3. Reconnect SSH with port forwarding (Step 4)
4. Run `gws auth login` (skip Step 5 — OAuth app already exists)

Each user ends up authenticated with their **own Google account** and their own token.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `npm install -g` gives permission denied | Follow the `~/.npm-global` method in Step 2 exactly |
| `gws auth setup` says "permission denied" or "insufficient scopes" | You skipped Step 3 — run `gcloud auth login --no-launch-browser` first |
| Project ID rejected as invalid | Must be 6–30 characters, lowercase letters, digits, and hyphens only. No underscores or spaces. |
| `gws auth login` URL does not complete / hangs | Make sure you reconnected SSH with `-L 9966:localhost:9966` before running the command |
| `gws: command not found` | Run `source ~/.bashrc` to reload the PATH update |
| Wrong Google account connected | Run `gws auth logout` then `gws auth login` again |
| Tools not responding after setup | Restart the Claude assistant service: `systemctl --user restart claude-assistant` |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
