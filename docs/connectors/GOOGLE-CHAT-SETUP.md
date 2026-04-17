---
title: Google Chat Setup Guide
version: 1.0
date: 2026-04-14
---

# Google Chat — Setup Guide

This guide connects your Google Chat to your AI assistant using the **Google Workspace CLI** (`gws`). Once set up, your assistant can list your team spaces, read messages, send messages and replies, post rich card updates, and generally handle anything you'd normally click through in Google Chat — all through plain English.

**Total time: about 10 minutes. Six parts.**

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- A **Google Workspace** account — this is the work/school email your organisation gave you (e.g. `you@company.com`). Personal Gmail accounts (`@gmail.com`) do NOT work — the Google Chat API is a Workspace-only feature.
- **Node.js** installed (check with `node --version` — needs v18 or higher)

> **No personal Gmail?** If you only have a `@gmail.com` account, Google Chat won't work for you. Use [Telegram](TELEGRAM-SETUP.md) or [WhatsApp](WHATSAPP-SETUP.md) instead — both work with any account.

> **Don't have Node.js?** On Mac: `brew install node`. On Windows: download the installer from [nodejs.org](https://nodejs.org) and run it.

---

## Compatible Computers

| Computer | Supported |
|---|---|
| Windows 10 / 11 — x64 | Yes |
| Windows 11 on ARM (Surface Pro X and newer) | Yes |
| Mac — Intel (2020 and older) | Yes |
| Mac — Apple Silicon (M1, M2, M3, M4) | Yes |

---

## What This Unlocks

| Area | What Your Assistant Can Do |
|---|---|
| **Spaces** | List all your spaces, DMs, and group chats |
| **Messages** | Send new messages to any space you're a member of |
| **Reading** | Read recent messages in any space, summarise long threads |
| **Threads** | Reply in an existing thread so the conversation stays together |
| **Members** | List who's in a space |
| **Rich cards** | Post formatted update cards (deploy status, build results, daily digests) |
| **Formatting** | Bold, italic, inline code, code blocks — all supported |

> **Not covered (yet):** Creating new spaces, editing space settings, managing webhooks, or clicking buttons on card messages. For those, your assistant falls back to opening `https://chat.google.com` in a browser so you can do it yourself.

---

## Part A — Install the Google Workspace CLI

We use the **Google Workspace CLI** (`gws`) — a single tool that talks to the Chat API with OAuth handled for you. Same tool also covers Gmail, Calendar, and Drive if you want to expand later.

**Step 1 — Install it**

In your terminal:

```
npm install -g @googleworkspace/cli
```

> On Mac/Linux, if you see a permission error, run `sudo npm install -g @googleworkspace/cli` instead.

**Step 2 — Verify**

```
gws --version
```

You should see a version number. If you see "command not found", close and reopen your terminal and try again.

---

## Part B — Set Up a GCP Project

The Google Chat API needs a **GCP project** with an OAuth client — this is Google's way of saying "an app that is allowed to talk to Chat on your behalf". You only need to do this once per organisation. Pick **one** of the three options below.

### Option A — Get the file from a teammate (easiest)

If someone on your team already did this setup, ask them for their `client_secret.json` file. It's safe to share within your company — it identifies the OAuth app, not your personal login.

Save it to:

```
~/.config/gws/client_secret.json
```

(Create the folder first if it doesn't exist: `mkdir -p ~/.config/gws`.)

Then skip to **Part C**.

### Option B — Automated (fastest if you have `gcloud`)

If you have the `gcloud` CLI installed and logged in, just run:

```
gws auth setup --login
```

This creates the GCP project, enables the Chat/Gmail/Calendar/Drive APIs, configures OAuth, and authenticates you in one shot. Skip to **Part D**.

> Don't have `gcloud`? Install it from [cloud.google.com/sdk/docs/install](https://cloud.google.com/sdk/docs/install) — or on Mac: `brew install --cask google-cloud-sdk`. Or just use Option C.

### Option C — Manual

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click the project dropdown at the top → **New Project** → give it a name like "Claude Chat" → **Create**
3. Make sure the new project is selected
4. In the left menu: **APIs & Services → Library**
5. Search for and enable each of these four APIs (one at a time):
   - **Google Chat API**
   - **Gmail API**
   - **Google Calendar API**
   - **Google Drive API**
6. Go to **APIs & Services → Credentials**
7. If you've never used this project before, you'll be asked to configure the **OAuth consent screen** first. Choose **Internal** if your org has Google Workspace, give it a name, and save.
8. Back on the Credentials page, click **Create Credentials → OAuth client ID**
9. Application type: **Desktop app** → give it a name → **Create**
10. Click the **Download JSON** button on the credential you just made
11. Save the file as:

```
~/.config/gws/client_secret.json
```

---

## Part C — Authenticate

Now that `gws` knows about your app, sign in with your Google Workspace account:

```
gws auth login -s chat,gmail,calendar,drive
```

A browser window opens. Sign in with your **Workspace** email and approve the scopes. When the browser says "you can close this window", you're authenticated.

> The first time, Google may warn you that the app is "unverified" — that's expected because this is a desktop app you just made. Click **Advanced → Go to [your app name] (unsafe)** to continue. You're not bypassing anything unsafe; you're just telling Google that yes, you trust an app you built yourself.

---

## Part D — Verify It Works

Check that authentication worked:

```
gws auth status
```

Look for `"token_valid": true`. Then do a cheap test call to confirm the Chat API is reachable:

```
gws chat spaces list --format table
```

You should see a table of your Google Chat spaces. If you see a list (even an empty one), **you're done with setup**. If you see an error, check the **Troubleshooting** section at the bottom.

---

## Part E — Let Claude Map Your Spaces

Open Claude Code and ask:

> "List all my Google Chat spaces and update the google-chat-connector skill file with the space names and IDs."

Your assistant will call the API, list your spaces, and save them into the skill file. That way, next time you say "send a message to the Dev Team", it already knows which space ID to use — no lookup needed.

---

## Part F — Try It

Ask your assistant any of these:

- "List my Google Chat spaces"
- "Send a message to the Dev Team saying standup is cancelled"
- "Read the latest 10 messages in the Workshop R&D chat"
- "Who's in the Leadership team chat?"
- "Reply in the thread about the deploy: 'All green now, thanks.'"
- "Post a card to the #announcements room when the build finishes"

---

## Sharing the GCP Project with Teammates

The hardest part of setup is the GCP project + OAuth, but you only ever need to do it once per organisation. To make it easy for the rest of your team:

1. **One person** does **Part B** (Option B or Option C) once.
2. That person sends the `client_secret.json` file to the rest of the team — Slack, email, internal file share, whatever. This file is **not** a secret; it identifies the app, not any individual.
3. Each teammate saves it to `~/.config/gws/client_secret.json` on their laptop.
4. Each teammate runs `gws auth login -s chat,gmail,calendar,drive` with their own Google account.

Every person authenticates individually — the GCP project is just the shared "app wrapper" they all point at.

---

## Troubleshooting

**"No spaces showing up"**
You're probably signed in with a personal Gmail account. The Chat API only works with Google Workspace accounts. Run `gws auth logout` and log in again with your work/school Workspace email.

**"failed to decrypt token cache"**
The local token cache is corrupted. Fix:
```
rm ~/.config/gws/token_cache.json
gws auth login -s chat,gmail,calendar,drive
```

**"PERMISSION_DENIED" or "insufficient authentication scopes"**
Your OAuth grant is missing the Chat scope. Re-authenticate with the full scope list:
```
gws auth login -s chat,gmail,calendar,drive
```

**"PERMISSION_DENIED" on a specific space**
You can only read or write to spaces you're a member of. Join the space in the Google Chat UI first, then try again.

**"gws: command not found"**
Your terminal didn't pick up the new global npm bin. Close and reopen the terminal, or run:
```
export PATH="$(npm prefix -g)/bin:$PATH"
```
On Mac/Linux you may need `sudo` when installing: `sudo npm install -g @googleworkspace/cli`.

**"Error 403: access_denied" in the browser during login**
Your OAuth consent screen is set to **External** and your app hasn't been published. If you're in a Workspace org, go back to the Google Cloud Console → **OAuth consent screen** and change it to **Internal**. Then re-run `gws auth login`.

**"I need to switch to a different Google account"**
```
gws auth logout
gws auth login -s chat,gmail,calendar,drive
```

**"The Google Cloud Console is confusing and I'm stuck on Part B"**
Ask someone on your team if they've done the setup already (Option A — they can just share their `client_secret.json`). Or ask your assistant: *"Walk me through creating a GCP project for Google Chat step by step."* It has the full flow in the [gcloud-connector skill](../skills/gcloud-connector/SKILL.md).

---

## What's Next

- [TELEGRAM-SETUP.md](TELEGRAM-SETUP.md) — add Telegram as a second messaging channel for mobile
- [WHATSAPP-SETUP.md](WHATSAPP-SETUP.md) — add WhatsApp
- [GOOGLE-WORKSPACE-SETUP.md](GOOGLE-WORKSPACE-SETUP.md) — the same `gws` CLI also handles Gmail, Calendar, and Drive
- [OUTLOOK-SETUP.md](OUTLOOK-SETUP.md) — Microsoft 365 equivalent if your org uses Outlook instead
