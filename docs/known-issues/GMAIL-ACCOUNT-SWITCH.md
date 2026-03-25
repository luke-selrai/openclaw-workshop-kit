---
title: Gmail Connected to Wrong Account
date: 2026-03-24
status: unresolved
---

# Gmail Connected to Wrong Account

## What Happened

After setting up Gmail through the local command window, it connected to the wrong Google account instead of the intended one. This typically happens when multiple Google accounts are signed in to the browser.

## What We Tried

1. Removed the Gmail connection locally:
   `claude mcp remove gmail --scope user`

2. Re-added it:
   `claude mcp add gmail npx @gptscript-ai/gmail-mcp --scope user`

3. Cleared cached login files:
   `rm -rf ~/.gmail-mcp`

4. Restarted Claude Code.

**None of these changed the connected account.**

## Why It Didn't Work

The Gmail connection is managed through the **Claude.ai online account settings**, not through the local setup. Removing and re-adding locally has no effect on which Google account is linked.

## Likely Fix

1. Go to **claude.ai** in the browser
2. Open **Settings** (profile icon, bottom-left)
3. Find the **Gmail integration** and disconnect it
4. Reconnect — sign in with the correct Google account this time

## Note

When the Google sign-in screen appears, it defaults to whichever account is already logged into the browser. Users must **manually select the correct account** before clicking Allow.
