---
title: Google Connected to Wrong Account
date: 2026-03-27
status: resolved
---

# Google Connected to Wrong Account

## What Happens

After running `gws auth login`, the Google Workspace tool connects to the wrong Google account. This typically happens when multiple Google accounts are signed in to the browser.

## Why It Happens

When the sign-in screen opens in your browser, it defaults to whichever Google account is already logged in. If you have multiple accounts (e.g. personal Gmail and a work account), you may click "Allow" without noticing it selected the wrong one.

## How to Fix

1. Run this in the command window to sign out:
   ```
   gws auth logout
   ```

2. Sign in again:
   ```
   gws auth login
   ```

3. When the browser opens, **carefully select the correct Google account** before clicking Allow.

## Prevention

When the Google sign-in screen appears, always check which account is shown at the top of the page before clicking Allow. If the wrong account is pre-selected, click on the account switcher to pick the right one.
