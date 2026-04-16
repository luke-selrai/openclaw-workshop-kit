---
title: Microsoft Outlook & 365 Setup Guide
version: 3.1
date: 2026-04-01
---

# Microsoft Outlook & 365 — Setup Guide

This guide connects your Microsoft account to your AI assistant. Once set up, your assistant can read and send emails, check your calendar, access OneDrive files, work with Excel, browse SharePoint, use OneNote, interact with Teams, and manage your contacts — all through plain English.

---

## What You Need Before Starting

- Claude Code installed and working (follow [FULL-SETUP-PAGE.md](FULL-SETUP-PAGE.md) if not done yet)
- Node.js **version 20 or higher** installed — check by typing `node --version` in the command window
- A Microsoft account — personal (outlook.com, hotmail.com) or work/school (Microsoft 365)
- An internet connection

> **If `node --version` shows v18 or lower:** Update Node.js from [nodejs.org](https://nodejs.org) before continuing.

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

| Tool | What Your Assistant Can Do |
|---|---|
| **Outlook Email** | Read, search, send, reply, and organise your emails |
| **Outlook Calendar** | Check, create, and update meetings and appointments |
| **Contacts** | Look up and manage your contacts |
| **OneDrive** | Find, open, and work with your files |
| **SharePoint** | Browse and search company documents |
| **Teams** | Read messages and channel conversations |
| **OneNote** | Read and add to your notebooks |
| **Excel** | Read and update spreadsheets |
| **To Do** | Manage your Microsoft To Do tasks |

---

## Step 1 — Install the Microsoft 365 Tool

Type this in the command window and press Enter:

```
npm install -g @pnp/cli-microsoft365
```

This may take 1–2 minutes. When it finishes, verify it worked:

```
m365 --version
```

You should see a version number. If you see "command not found":
- **Windows:** Close the command window completely and open a new one, then try again
- **Mac:** Run `export PATH="$(npm prefix -g)/bin:$PATH"` and try again

---

## Step 2 — Register Your Microsoft App (One-Time)

This step creates a secure private link between the tool and your Microsoft account. It only needs to be done once.

```
m365 setup
```

> **Important:** Do NOT use `m365 setup --interactive` — that only configures CLI settings and skips app registration.

A browser window will open. Sign in with your Microsoft account and click **Accept** when asked. This registers a custom Entra app in your tenant with the permissions the CLI needs.

When it finishes you should see a `clientId` and `tenantId` in the output — that means it worked.

> **Save the `clientId` value** — you may need it later. If you lose it, you can always retrieve it by running:
> ```
> m365 status
> ```
> The `appId` shown is your `clientId`.

> If you see any errors during setup, contact your workshop facilitator.

---

## Step 3 — Sign In to Your Microsoft Account

```
m365 login --authType browser
```

A browser window will open:

1. **Select the Microsoft account you want to use** — double-check this is the right one
2. You may see a permissions screen — click **"Accept"** or **"Allow"**
3. You should see a success message in the browser

> **If the browser does not open automatically**, use this instead:
> ```
> m365 login
> ```
> This shows a short code and a URL. Open `https://aka.ms/devicelogin` in your browser, enter the code, and sign in.

---

## Step 4 — Add Calendar Write Permission

The default app has read-only calendar access. To create and update events, you need to upgrade the permission.

**Easiest way — ask your assistant:**

> "Upgrade my Outlook calendar permission to read-write."

Your assistant will run the necessary commands automatically. Once done, it will sign you out and back in to apply the change.

**After the upgrade**, re-sign in if your assistant hasn't already:

```
m365 logout
m365 login --authType browser
```

> **Manual method:** If you prefer to run the commands yourself, see the [Appendix](#appendix--manual-calendar-permission-upgrade) at the bottom of this page.

---

## Step 5 — Test It

Once signed in, test it by asking your assistant:

- "Show me my unread Outlook emails"
- "What meetings do I have this week?"
- "List my recent OneDrive files"

Or test directly in the command window:

```
m365 outlook mail list
```

Calendar events use the Graph API (no built-in calendar command in the CLI):

```bash
m365 request --url "https://graph.microsoft.com/v1.0/me/events?\$top=5" --method get
```

---

## What Your Assistant Can Do Now

| Task | What to Say |
|---|---|
| **Read emails** | "Show me my unread emails" |
| **Send an email** | "Send an email to john@example.com about tomorrow's meeting" |
| **Reply to an email** | "Reply to Sarah's email and say I will be there at 3pm" |
| **Search emails** | "Find emails from my accountant in the last month" |
| **Check calendar** | "What meetings do I have this week?" |
| **Create a meeting** | "Schedule a call with Lisa on Thursday at 10am" |
| **Find a file** | "Find the budget spreadsheet in my OneDrive" |
| **Check Teams** | "Show me the latest messages in the General channel" |
| **Search SharePoint** | "Find the company policy document on SharePoint" |
| **Check contacts** | "Find the phone number for [contact name]" |
| **Manage tasks** | "Show me my Microsoft To Do tasks" |

---

## Troubleshooting

### Installation Problems

| Problem | Fix |
|---|---|
| "m365: command not found" after install | Close and reopen your terminal. On Mac, also run: `export PATH="$(npm prefix -g)/bin:$PATH"` |
| Node.js version too old | Update from [nodejs.org](https://nodejs.org) — download the LTS version (v22 or v20) |
| **EPERM / permission denied** during install on Windows | Close Claude Desktop, right-click it → "Run as administrator", reopen, and ask Claude to retry the install |
| **EACCES** during install on Mac | Avoid using `sudo npm`. Instead install via nvm: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh \| bash` then `nvm install --lts` and retry |
| **EINTEGRITY** error during install | npm cache is corrupted. Run `npm cache clean --force` then try again |
| **ECONNRESET / 403** during install | Your corporate firewall is blocking npmjs.com. Ask IT to allow `registry.npmjs.org:443` |
| install fails on Mac — "command not found: node" | nvm installed but not loaded. Run `source ~/.nvm/nvm.sh` then retry |
| Script blocked on Mac ("cannot be opened because the developer cannot be verified") | Right-click `setup.sh` → Open, or run: `xattr -d com.apple.quarantine setup.sh` |
| **Script blocked on Windows** ("running scripts is disabled") | Run in PowerShell: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` then retry |
| Windows Defender blocks npm install (EBUSY) | Temporarily pause Real-Time Protection in Windows Security, ask Claude to retry the install, then re-enable Real-Time Protection |
| Path too long error on Windows | Your folder path may exceed Windows' 260-character limit. Move the `outlook-connector` folder to `C:\workshop\` and try again |

### Setup & Sign-in Problems

| Problem | Fix |
|---|---|
| `m365 setup` fails or browser never opens | Run `m365 setup` (without `--interactive`) in a new terminal window |
| `m365 setup` shows "admin consent required" | Ask your IT department or workshop facilitator to approve the PnP Management Shell app at: `https://entra.microsoft.com` → Enterprise Applications → Grant admin consent |
| `m365 setup` hangs with no response | Press Ctrl+C, close the terminal, open a new one, and retry |
| Browser does not open during sign-in | Run `m365 login` (without `--authType browser`) — use the device code shown at `https://aka.ms/devicelogin` |
| **AADSTS53003** — Conditional Access error | Your organisation's security policy blocks browser auth. Use device code instead: `m365 login` |
| **AADSTS90094** — Admin consent required for sign-in | Your tenant requires IT admin approval. Contact your IT department to grant consent for the PnP Management Shell app |
| **AADSTS70043** — Token expired | Run `m365 logout` then `m365 login --authType browser` to get a fresh session |
| Sign-in fails even with device code — corporate proxy | Set the proxy for the auth engine: `set HTTPS_PROXY=http://proxy.company.com:8080` (Windows) or `export HTTPS_PROXY=...` (Mac), then retry |
| Wrong Microsoft account connected | Run `m365 logout` then `m365 login --authType browser` and select the correct account |
| Multiple accounts — keeps picking the wrong one | Run `m365 logout --all` then `m365 login --authType browser` and pick carefully |

### After Setup

| Problem | Fix |
|---|---|
| "Access denied" for Teams or SharePoint | Personal outlook.com accounts have full access. Work accounts may need IT admin approval |
| "No emails found" after connecting | Try `m365 outlook mail list --pageSize 20` — your inbox may just be empty or filtered |
| Sign-in stops working after a few weeks | Tokens refresh automatically, but some corporate Conditional Access policies expire them in 1–24 hours. Run `m365 login --authType browser` again |
| Something else | Contact Luke at [luke@selrai.com.au](mailto:luke@selrai.com.au) |

---

## Note for Work / Company Accounts

If your Outlook is managed by your employer, some features (Teams, SharePoint) may require your IT administrator to approve the connection during the `m365 setup` step. For personal outlook.com or hotmail.com accounts, everything works immediately with no restrictions.

---

## Server / Headless VM Setup

If you are running your assistant on a GCP server (or any headless VM without a browser), follow these steps instead:

### One-time prerequisite — run on your laptop (not the server)

The app registration (`m365 setup`) requires a browser and only needs to be done **once per Microsoft tenant**:

```bash
# On your LAPTOP (not the server)
m365 setup
```

Sign in, click Accept. Once you see `clientId` and `tenantId` in the output, the app is registered in your tenant.

### On the server — sign in via device code

```bash
# On the SERVER (via SSH)
npm install -g @pnp/cli-microsoft365
m365 login
```

This shows a short code and a URL (`https://aka.ms/devicelogin`). Open that URL on your phone or laptop browser, enter the code, and sign in. The server receives the token automatically.

Verify:

```bash
m365 status
m365 outlook mail list --pageSize 3
```

### Token refresh

Tokens refresh automatically. Some corporate tenants expire them in 1–24 hours — if that happens, run `m365 login` again (device code).

---

## Playwright Fallback

If any Outlook feature is unavailable through the CLI, your assistant can use its built-in browser automation (Playwright) to access Outlook Web directly. Just ask normally — for example, "Open my Outlook and check the email from last week" — and the assistant will use the browser if the CLI cannot handle it.

---

## Appendix — Manual Calendar Permission Upgrade

If you prefer to run the calendar upgrade commands yourself instead of asking your assistant:

```bash
# 1. Get your app's clientId (if you didn't save it from Step 2)
m365 status

# 2. Add Calendars.ReadWrite to the app registration
m365 entra app permission add \
  --appId <YOUR_CLIENT_ID> \
  --delegatedPermissions "https://graph.microsoft.com/Calendars.ReadWrite" \
  --grantAdminConsent

# 3. Get the service principal object ID
m365 entra enterpriseapp list --output json --query "[?appId=='<YOUR_CLIENT_ID>'].{id:id}"

# 4. List the current Graph API grant to get the grantId
m365 entra oauth2grant list --spObjectId <SERVICE_PRINCIPAL_ID> --output json

# 5. Update the OAuth2 grant scope (replace Calendars.Read with Calendars.ReadWrite in the full scope string)
m365 entra oauth2grant set --grantId "<GRANT_ID>" --scope "<FULL_SCOPE_STRING_WITH_Calendars.ReadWrite>"

# 6. Re-login to pick up the new permission
m365 logout
m365 login --authType browser
```

Replace `<YOUR_CLIENT_ID>` with the `appId` from `m365 status`, `<SERVICE_PRINCIPAL_ID>` with the `id` from step 3, and `<GRANT_ID>` and scope from step 4.

---

## Still Having Trouble?

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more fixes, or ask your assistant:
> "Something went wrong with my Outlook connection. Help me fix it."

---

*Built by Selr AI — [selrai.com.au](https://selrai.com.au)*
