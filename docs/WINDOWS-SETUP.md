# Windows Setup Guide

**For Windows users attending the Claude Code Workshop**

Windows needs a few extra steps compared to Mac. This guide covers everything. Total time: about 10 minutes.

---

## Quick Option — Automatic Installer

If you already have Node.js and Git installed, you can skip this entire guide and run the automatic installer instead:

1. Open the `workshop-kit` folder on your computer
2. Double-click **setup.bat**
3. It checks everything, installs what is needed, and sets up your workspace
4. When it finishes, open VS Code and start your assistant

> If setup.bat finds anything missing, it will tell you exactly what to install and where to get it.

**If setup.bat completed successfully — you are done. Do not follow the manual steps below.**

---

## Manual Setup — Step by Step

> **Only follow these steps if you did NOT use setup.bat, or if setup.bat reported an error.**

### Step 1 — Install Git for Windows

Claude Code needs Git to download and update your workshop kit.

1. Go to: **https://git-scm.com/download/win**
2. The download should start automatically. If not, click the download link for **64-bit Git for Windows Setup**
3. Run the downloaded installer
4. Click through the installer — **all default settings are fine**, you do not need to change anything
5. Click **Install**, then **Finish**

---

### Step 2 — Fix the PATH (Important)

The Git installer is supposed to add itself to your system PATH automatically, but it does not always work. This manual fix makes sure Windows and VS Code can find Git.

Follow these steps exactly:

1. Press the **Windows key** on your keyboard
2. Type: **Environment Variables**
3. Click **Edit the system environment variables** (the one that says "Control Panel")
4. A "System Properties" window opens — click the **Environment Variables** button at the bottom
5. In the bottom section labelled **System variables**, find the row called **Path** and click on it to select it
6. Click **Edit**
7. Click **New**
8. Type exactly: **C:\Program Files\Git\cmd**
9. Click **OK** to close the Edit window
10. Click **OK** to close the Environment Variables window
11. Click **OK** to close the System Properties window

---

### Step 3 — Install Node.js

Node.js is needed to connect Gmail, Calendar, browser automation, and Telegram.

1. Go to: **https://nodejs.org**
2. Click the big green button that says **"Download Node.js (LTS)"**
3. Run the downloaded installer
4. Click **Next**, **Next**, **Next**, then **Install**
5. When it finishes, **close and reopen VS Code completely**

---

### Step 4 — Close and Reopen VS Code

**This step is required.** VS Code needs a full restart to pick up the PATH changes from Git and Node.js.

1. Close VS Code completely (not just the tab — close the whole app)
2. Wait a few seconds
3. Reopen VS Code

---

### Step 5 — Verify Everything Works

Open a terminal in VS Code: press **Ctrl+`** (backtick key, next to the number 1)

Type each of these and press Enter:

```
git --version
```
You should see something like: `git version 2.47.1.windows.1`

```
node --version
```
You should see something like: `v22.x.x`

If both show version numbers, you are ready. Continue with the workshop setup guide.

---

## Common Windows Problems

| Problem | Fix |
|---|---|
| `'git' is not recognized` after restart | Go back to Step 2 and make sure you added the PATH entry to **System variables** (bottom section), not User variables (top section). The path must be exactly `C:\Program Files\Git\cmd` |
| `'node' is not recognized` | Close VS Code completely and reopen it. If still not working, reinstall Node.js from [nodejs.org](https://nodejs.org) |
| Cannot find "Environment Variables" in search | Type the full phrase: `Edit the system environment variables` |
| "Access denied" or cannot edit System variables | You need administrator access on your laptop. If this is a work laptop, ask IT for help |
| Git installed in a different location | If you changed the install location, use that path instead of `C:\Program Files\Git\cmd` |
| PowerShell says "running scripts is disabled" | Open PowerShell and run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then press Y and Enter |
| npm install fails with "EPERM" or permission error | Close VS Code, right-click it, choose **Run as administrator**, then try again |
| npm install fails with "EBUSY" | Windows Defender is scanning files. Temporarily pause Real-Time Protection in Windows Security, run the install, then re-enable it |
| Path too long error | Your folder is nested too deep (OneDrive or Desktop). Move the workshop folder closer to `C:\` — for example `C:\workshop\` |
| Bun install fails on Windows | Use the PowerShell command: `powershell -c "irm bun.sh/install.ps1 \| iex"` — close and reopen your terminal after |
| Claude Code extension not appearing | Make sure VS Code is up to date. Go to Help > Check for Updates. Then search "Claude Code" in Extensions again |

---

## Windows vs Mac — Key Differences

| Action | Mac | Windows |
|---|---|---|
| Open terminal in VS Code | Cmd+` | Ctrl+` |
| Open folder in VS Code | Cmd+Shift+P > "open folder" | Ctrl+Shift+P > "open folder" |
| Home directory | `/Users/yourname/` | `C:\Users\yourname\` |
| Git install | Automatic (Xcode tools) | Manual (git-scm.com) |
| Node.js PATH | Usually automatic | Usually automatic |
| Git PATH | Automatic | Sometimes needs manual fix (Step 2) |
| iMessage channel | Supported | Not available |

---

## After Windows Setup

Once Git and Node.js are verified, continue with the main setup guide:

1. Open VS Code
2. Click the **Claude Code** icon in the left sidebar
3. Paste the **bootstrap prompt** from the workshop page
4. Follow the assistant's instructions

Or use **setup.bat** to do it all automatically.

---

## Need Help?

Email **luke@selrai.com.au** before the workshop if anything does not work.

---

*Claude Code Workshop — selrai.com.au*
