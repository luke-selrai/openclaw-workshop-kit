# Google Chat Toolkit for Claude Code

Send messages, read conversations, and manage your Google Chat spaces by talking to Claude in plain English.

"Send a message to the Dev Team saying the deploy is done" -- and Claude does it.

## Prerequisites

- **Google Workspace account** (this does NOT work with personal Gmail accounts)
- **Node.js** installed (`brew install node` or from nodejs.org)

---

## Setup (10 minutes)

### Step 1: Run the installer

```bash
cd google-chat-toolkit
bash setup.sh
```

This installs the `gws` CLI and the Claude Code skill automatically.

### Step 2: Set up a GCP project

The Google Chat API requires a GCP project with OAuth credentials. You have three options:

**Option A: Get the file from your team lead**
If someone on your team already set this up, they can share their `client_secret.json` file with you. Save it to `~/.config/gws/client_secret.json`.

**Option B: Automated setup (needs gcloud CLI)**
```bash
gws auth setup --login
```
This creates the GCP project, enables the APIs, and authenticates you in one step.

**Option C: Manual setup**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project
3. Enable these APIs: **Chat API**, Gmail API, Drive API, Calendar API
4. Go to APIs & Services > Credentials > Create OAuth Client ID
   - Application type: **Desktop app**
   - Download the JSON file
5. Save it as `~/.config/gws/client_secret.json`

### Step 3: Authenticate

```bash
gws auth login -s chat,gmail,calendar,drive
```

This opens your browser. Sign in with your Google Workspace account and approve the permissions.

### Step 4: Test it

```bash
bash test.sh
```

All `[pass]`? You're good. Open Claude Code and start chatting.

---

## What you can do

Once set up, just ask Claude Code:

- "List my Google Chat spaces"
- "Send a message to the Dev Team saying standup is cancelled"
- "Read the latest messages in the Workshop R&D chat"
- "Who's in the Leadership team chat?"
- "Reply in the thread about the deploy"

Claude finds the right space, formats the message, and sends it.

---

## What's in the box

| File | What it does |
|------|-------------|
| `skills/google-chat/SKILL.md` | Teaches Claude the gws CLI commands, message formatting, space types, and safety rules |
| `setup.sh` | Installs the gws CLI and skill, walks through GCP + OAuth setup |
| `test.sh` | Verifies CLI, credentials, and live API connectivity |

## After setup: let Claude map your spaces

Once authenticated, ask Claude Code:

> "List all my Google Chat spaces and update the skill file with the space names and IDs"

Claude will call the API, get your spaces, and write them into the skill so it knows where to send messages.

---

## Sharing the GCP project with your team

The hardest part of setup is the GCP project + OAuth. To make it easy for teammates:

1. One person sets up the GCP project (Step 2 above)
2. Share the `client_secret.json` file with the team (this is NOT a secret, it's the OAuth app identifier)
3. Each person saves it to `~/.config/gws/client_secret.json`
4. Each person runs `gws auth login -s chat` to authenticate with their own Google account

The `client_secret.json` is safe to share within your org. It just identifies your GCP app. The actual authentication happens per-user via OAuth.

---

## Troubleshooting

**"failed to decrypt token cache"**
```bash
rm ~/.config/gws/token_cache.json
gws auth login -s chat
```

**"PERMISSION_DENIED" or "insufficient scopes"**
Re-auth with Chat scopes:
```bash
gws auth login -s chat
```

**No spaces showing up**
Google Chat API requires a Google Workspace account. Personal Gmail (@gmail.com) accounts don't have access to the Chat API.

**"gws: command not found"**
```bash
npm install -g @googleworkspace/cli
```

**Need to use a different Google account**
```bash
gws auth logout
gws auth login -s chat,gmail,calendar,drive
```
