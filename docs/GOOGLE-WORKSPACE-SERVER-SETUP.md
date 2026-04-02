---
title: Google Workspace Setup Guide — Server / Headless VM
version: 2.0
date: 2026-04-02
---

# Google Workspace — Server Setup Guide

This guide is for setting up Google Workspace on a **Linux server or GCP VM that has no desktop or browser**. You will do this once per user on the server.

For laptop/desktop setup, see [GOOGLE-WORKSPACE-SETUP.md](GOOGLE-WORKSPACE-SETUP.md).

> **If you are running the assistant via the GCP single-user setup:** your assistant (Claude) will walk you through this automatically when you ask it to connect Google Workspace. You do not need to follow this guide manually unless something goes wrong.

---

## What You Need Before Starting

- SSH access to the server (via `gcloud compute ssh` or similar)
- `gcloud` CLI installed on your **local laptop**
- A Google account for the user being set up

---

## Overview

Because the server has no browser, authentication requires two things:

1. **`gcloud auth login --no-launch-browser`** — authenticates the gcloud CLI using a URL + code flow. No tunnel needed.
2. **`gws auth login -s drive,gmail,sheets,calendar`** — authenticates the GWS CLI using an OAuth callback. You open an SSH tunnel on port 9966 so the callback reaches your laptop browser.

> **Always use `-s drive,gmail,sheets,calendar`** with `gws auth login`. Without it, Google blocks the login because the unverified app requests 85+ scopes by default.

---

## Step 1 — SSH Into the Server

```bash
gcloud compute ssh <YOUR-VM-NAME> \
  --project=<YOUR-PROJECT> \
  --zone=<YOUR-ZONE>
```

---

## Step 2 — Install the GWS CLI

Install to the user's home directory to avoid permission errors:

```bash
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
npm install -g @googleworkspace/cli
```

Verify:

```bash
gws --version
```

✅ You should see a version number.

---

## Step 3 — Authenticate gcloud as Your Google Account

The server uses a system service account by default, not your personal Google account. This step fixes that — it is required before `gws auth setup` will work.

```bash
gcloud auth login --no-launch-browser
```

A long URL will print. Open it in your **laptop browser**, sign in with your Google account, copy the verification code, paste it back into the terminal, and press Enter.

✅ You should see: `You are now logged in as [yourname@gmail.com]`

---

## Step 4 — Reconnect SSH With Port Forwarding

Exit your current SSH session. Reconnect with a tunnel on port 9966 — this lets the OAuth callback from `gws auth login` reach your laptop browser:

```bash
# Run this on your LAPTOP (not on the server)
gcloud compute ssh <YOUR-VM-NAME> \
  --project=<YOUR-PROJECT> \
  --zone=<YOUR-ZONE> \
  -- -L 9966:localhost:9966
```

Then reload your PATH:

```bash
source ~/.bashrc
```

---

## Step 5 — Create the OAuth App (First Time Only)

> **Skip if you have already done this on this server.** The OAuth app is shared across users.

```bash
gws auth setup
```

When prompted for a project ID, enter something short (6–30 characters, lowercase letters, digits, and hyphens only — no underscores or spaces):

```
gws-claude-assistant
```

✅ You should see: `Setup complete`

---

## Step 6 — Add Your Email as a Test User

Before logging in, add your Google account as a test user in the OAuth consent screen — otherwise you will see "Access blocked" during login.

1. Open [console.cloud.google.com](https://console.cloud.google.com) on your laptop
2. Select the project you just created (e.g. `gws-claude-assistant`)
3. Go to **APIs & Services → OAuth consent screen**
4. Scroll to **Test users** → click **Add users**
5. Enter your Google email address → click **Save**

---

## Step 7 — Log In

```bash
gws auth login -s drive,gmail,sheets,calendar
```

A URL will print. Open it in your **laptop browser**. Sign in and click Allow. The port forwarding tunnel (port 9966) carries the OAuth callback from your browser back to the server automatically.

✅ You should see a success message in both the browser and the terminal.

---

## Step 8 — Verify

```bash
gws auth status
```

✅ You should see your authenticated Google account listed.

Test it:

```bash
gws gmail messages list --max-results 3
```

---

## Step 9 — Restart the Assistant

For the GWS tools to be available in the running Claude service:

```bash
systemctl --user restart claude-assistant
```

---

## Adding More Users

For each additional user (e.g. `alice`, `bob`):

1. `sudo su - <username>`
2. Repeat Steps 2–3 (install gws, `gcloud auth login --no-launch-browser`)
3. Reconnect SSH with port forwarding (Step 4)
4. Add their email as test user in the OAuth consent screen (Step 6)
5. Run `gws auth login -s drive,gmail,sheets,calendar` (skip Step 5 — OAuth app already exists)

Each user ends up authenticated with their own Google account and their own token.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `npm install -g` gives permission denied | Follow the `~/.npm-global` method in Step 2 exactly |
| `gws auth setup` says "permission denied" or "insufficient scopes" | You skipped Step 3 — run `gcloud auth login --no-launch-browser` first |
| Project ID rejected as invalid | Must be 6–30 characters, lowercase letters, digits, hyphens only — no underscores or spaces |
| `gws auth login` URL does not complete / hangs | Make sure you reconnected SSH with `-L 9966:localhost:9966` before running the command |
| "Access blocked: This app's request is invalid" | Add your email as a test user — see Step 6 |
| `gws: command not found` | Run `source ~/.bashrc` to reload the PATH |
| Login rejected with scope error | Use `gws auth login -s drive,gmail,sheets,calendar` — never plain `gws auth login` |
| Wrong Google account connected | `gws auth logout` then `gws auth login -s drive,gmail,sheets,calendar` |
| Tools not responding after setup | `systemctl --user restart claude-assistant` |

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
