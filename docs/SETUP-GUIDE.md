---
title: Claude Code Local Setup Guide
version: 1.0
date: 2026-03-24
---

# Claude Code — Local Setup Guide

A step-by-step guide for setting up Claude Code on a user's computer and connecting their tools.

---

## Step 1 — Install Node.js

Node.js is required for all tool connections below.

### Mac
1. Open your web browser
2. Go to **nodejs.org**
3. Click the big green button that says **"Download Node.js (LTS)"**
4. Open the downloaded file
5. Click **Continue**, then **Continue** again, then **Install**
6. Enter your Mac password if asked

### Windows
1. Open your web browser
2. Go to **nodejs.org**
3. Click the big green button that says **"Download Node.js (LTS)"**
4. Open the downloaded file
5. Click **Next**, then **Next**, then **Next**, then **Install**
6. Close and fully reopen VS Code (or your command window)

### Verify
Type this in the command window and press Enter:
```
node --version
```
You should see a version number like `v22.x.x`. If you see an error, restart your command window and try again.

---

## Step 2 — Connect Gmail

1. Type this in the command window and press Enter:
   ```
   claude mcp add gmail npx @gptscript-ai/gmail-mcp --scope user
   ```
2. A Google sign-in screen will open in your browser
3. **Important:** Make sure you select the correct Google account — the one you want emails sent from
4. Click **Allow** to give permission
5. Go back to the command window — it should confirm the connection

**If the wrong account gets connected:** See the [Gmail Account Switch guide](known-issues/gmail-account-switch.md).

---

## Step 3 — Connect Google Calendar

1. Type this in the command window and press Enter:
   ```
   claude mcp add google-calendar npx @gptscript-ai/google-calendar-mcp --scope user
   ```
2. A Google sign-in screen will open in your browser
3. Select the correct Google account
4. Click **Allow**

---

## Step 4 — Connect Playwright (Browser Automation)

This lets Claude open websites and perform tasks in the browser automatically.

1. Type this in the command window and press Enter:
   ```
   claude mcp add playwright npx @playwright/mcp@latest --scope user
   ```
2. No sign-in needed — it installs automatically

---

## Step 5 — Connect Telegram (Notifications)

1. Install Telegram on your phone (App Store on iPhone, Google Play on Android)
2. Sign up with your phone number
3. Open Telegram and search for **@BotFather** (look for the blue checkmark)
4. Tap **Start**
5. Type `/newbot` and press Send
6. BotFather will ask for a name — type any name you like
7. BotFather will ask for a username — type a name that ends in `bot` (e.g. `myassistantbot`)
8. BotFather will give you a token — copy it and save it somewhere safe

---

## After Setup

Once connected, restart Claude Code to make sure all tools are active.

To check what's connected, type:
```
claude mcp list
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "command not found" when running `node` | Restart your command window, or reinstall Node.js |
| Gmail connects to wrong account | See [Gmail Account Switch guide](known-issues/gmail-account-switch.md) |
| Sign-in screen doesn't appear | Check that Node.js is installed (Step 1) |
| Tool not responding after setup | Restart Claude Code |
| "Permission denied" error (Mac) | Add `sudo` before the command |
