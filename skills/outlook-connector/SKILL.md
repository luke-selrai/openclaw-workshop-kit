---
name: outlook-connector
description: Install and operate the Microsoft Outlook & 365 connector. Use this skill when the user asks to set up Outlook, connect Microsoft 365, or interact with emails, calendar, OneDrive, Teams, SharePoint, OneNote, Excel, Contacts, or To Do. Handles full installation and uses Playwright for any browser-based steps.
allowed-tools: Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - outlook
    - microsoft365
    - email
    - calendar
    - onedrive
    - teams
    - sharepoint
    - installer
  pairs-with:
    - skill: email-composer
      reason: Compose the email content with email-composer, then send it via the Outlook connector
    - skill: playwright-skill
      reason: Used as fallback for any Microsoft 365 browser-based actions the CLI cannot perform
---

# Outlook & Microsoft 365 Connector

## Overview

This skill does two things:
1. **Installs** the connector on the user's computer (one-time setup)
2. **Operates** the connector — reading emails, calendar, files, Teams, etc.

The connector uses the **PnP CLI for Microsoft 365** (`@pnp/cli-microsoft365`).
Full command reference: https://pnp.github.io/cli-microsoft365/

> **Account support:** Enterprise / work / school Microsoft 365 accounts only.
> Personal accounts (outlook.com, hotmail.com) are not currently supported by the CLI.
> If the user has a personal account, use Playwright browser automation as the fallback (see bottom of this skill).

---

## Part 1 — Installation

### Step 1: Check if already installed
```bash
m365 --version
```
If this returns a version number, skip to Step 4 (sign-in check). If "command not found", continue from Step 2.

### Step 2: Check Node.js
```bash
node --version
```
Needs v20 or higher. If missing or too old, tell the user to install from https://nodejs.org (LTS version) before continuing.

### Step 3: Install the CLI
```bash
npm install -g @pnp/cli-microsoft365
```
After install, refresh PATH so the command is available immediately:

**Mac/Linux:**
```bash
export PATH="$(npm prefix -g)/bin:$PATH"
```
**Windows (Command Prompt):**
```bat
for /f "tokens=*" %i in ('npm prefix -g') do set PATH=%i\bin;%PATH%
```

### Step 4: Run m365 setup (one-time, enterprise accounts)

This registers a custom Entra app with the user's Microsoft tenant. Required because the default PnP app was permanently deleted September 9, 2024.

```bash
m365 setup
```

> **Do NOT use `m365 setup --interactive`** — that only configures CLI settings and skips app registration.

**This opens a browser.** The user signs in and clicks Accept/Allow. Wait for the success message (shows `clientId` and `tenantId`) before proceeding.

> **Save the `clientId`** — you will need it in Step 4b. If you lose it, retrieve it later with:
> ```bash
> m365 status --output json
> ```
> The `appId` field is your `clientId`.

If you see `admin consent required` — the user's IT admin needs to approve the app at:
`https://entra.microsoft.com` → Enterprise Applications → Grant admin consent

### Step 4b: Upgrade calendar permission

The default app registers `Calendars.Read` (read-only). To create/update events, upgrade to `Calendars.ReadWrite`.

> **Tip:** The user can just say "Upgrade my Outlook calendar permission to read-write" and the assistant will run these commands automatically.

```bash
# 1. Get the app's clientId from m365 status (or use the saved value from Step 4)
APP_ID=$(m365 status --output json | python3 -c "import json,sys; print(json.load(sys.stdin)['appId'])")
echo "Using app: $APP_ID"

# 2. Add Calendars.ReadWrite permission to the app registration
m365 entra app permission add --appId "$APP_ID" \
  --delegatedPermissions "https://graph.microsoft.com/Calendars.ReadWrite" \
  --grantAdminConsent

# 3. Get the service principal object ID
SP_ID=$(m365 entra enterpriseapp list --output json \
  --query "[?appId=='$APP_ID'].id" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['id'] if isinstance(d[0],dict) else d[0])")
echo "Service principal: $SP_ID"

# 4. Find the Graph API grant and update scope in one step
eval $(m365 entra oauth2grant list --spObjectId "$SP_ID" --output json | python3 -c "
import json, sys
grants = json.load(sys.stdin)
for g in grants:
    if 'Calendars' in g.get('scope', ''):
        scope = g['scope'].replace('Calendars.Read', 'Calendars.ReadWrite')
        print(f'export GRANT_ID=\"{g[\"id\"]}\"')
        print(f'export SCOPE=\"{scope}\"')
        break
")

# 5. Apply the updated scope
m365 entra oauth2grant set --grantId "$GRANT_ID" --scope "$SCOPE"

# 6. Re-login to pick up the new permission
m365 logout && m365 login --authType browser
```

### Step 5: Sign in

```bash
m365 login --authType browser
```

**This opens a browser.** Use Playwright to handle it:
1. Run the command — it will open a browser tab automatically
2. If no browser opens, run `m365 login` instead (device code method)
3. Device code method outputs a URL + short code — navigate Playwright to `https://aka.ms/devicelogin`, enter the code
4. The user completes sign-in
5. Confirm success: `m365 status`

**Common sign-in errors:**
| Error code | Meaning | Fix |
|---|---|---|
| AADSTS53003 | Conditional Access blocks browser | Switch to `m365 login` (device code) |
| AADSTS90094 | Admin consent required | IT admin approves at Entra admin center |
| AADSTS70043 | Token expired | `m365 logout` then re-login |

### Step 6: Verify
```bash
m365 outlook mail list --pageSize 3
```
If emails appear, the connector is working. If this fails but sign-in succeeded, that is usually fine — tell the user to try asking the assistant directly.

---

## Part 2 — Email (Outlook)

### List recent emails
```bash
m365 outlook mail list --pageSize 10
```

### List unread emails only
```bash
m365 outlook mail list --pageSize 10 --query "(isRead eq false)"
```

### Search by subject or sender
```bash
m365 outlook mail list --subject "invoice" --pageSize 10
m365 outlook mail list --from "person@example.com" --pageSize 10
```

### Read a specific email
```bash
m365 outlook mail message get --id "<messageId>"
```

### Send an email
```bash
m365 outlook mail send \
  --to "recipient@example.com" \
  --subject "Subject here" \
  --body "Email body here"
```
> Always confirm recipient, subject, and body with the user before sending.

### Reply to an email
```bash
m365 outlook mail reply --id "<messageId>" --body "Reply text here"
```

### Move email to folder
```bash
m365 outlook mail move --id "<messageId>" --destinationFolderName "Archive"
```

---

## Part 3 — Calendar (via Graph API)

> **Note:** The m365 CLI v11.x has no built-in calendar event commands. Use `m365 request` with the Microsoft Graph API.

### List upcoming events
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/events?\$top=10&\$orderby=start/dateTime" \
  --method get
```

### List events in a date range
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/calendarView?\$top=20&startDateTime=2026-04-07T00:00:00Z&endDateTime=2026-04-14T23:59:59Z" \
  --method get
```

### Create a meeting
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/events" \
  --method post \
  --content-type "application/json" \
  --body '{"subject":"Meeting title","start":{"dateTime":"2026-04-08T10:00:00","timeZone":"Asia/Singapore"},"end":{"dateTime":"2026-04-08T10:30:00","timeZone":"Asia/Singapore"},"attendees":[{"emailAddress":{"address":"person@example.com"},"type":"required"}]}'
```
> Always confirm date, time, timezone, and attendees with the user before creating.
> Requires `Calendars.ReadWrite` permission (see Step 4b in Part 1).

### Update a meeting
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/events/<eventId>" \
  --method patch \
  --content-type "application/json" \
  --body '{"subject":"New title"}'
```

### Delete a meeting
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/events/<eventId>" \
  --method delete
```

---

## Part 4 — OneDrive

```bash
# List files
m365 onedrive file list

# List files in a folder
m365 onedrive file list --folderUrl "/Documents/Projects"

# Search for a file
m365 onedrive file list --query "budget"

# Download a file
m365 onedrive file download --sourceUrl "/Documents/report.xlsx" --targetFile "./report.xlsx"
```

---

## Part 5 — SharePoint

```bash
# Search documents
m365 spo search --query "annual report" --selectProperties "Title,Path,Author"

# List files in a document library
m365 spo file list \
  --webUrl "https://yourcompany.sharepoint.com/sites/YourSite" \
  --folder "/Shared Documents"
```

---

## Part 6 — Microsoft Teams

```bash
# List teams
m365 teams team list

# List channels in a team
m365 teams channel list --teamId "<teamId>"

# Read recent messages
m365 teams message list --teamId "<teamId>" --channelId "<channelId>"

# Send a message
m365 teams message send \
  --teamId "<teamId>" \
  --channelId "<channelId>" \
  --message "Your message here"
```

---

## Part 7 — Contacts, OneNote, To Do

```bash
# Contacts
m365 outlook contact list
m365 outlook contact add --displayName "Name" --emailAddresses "email@example.com"

# OneNote — list notebooks and pages
m365 onenote notebook list
m365 onenote page list --sectionId "<sectionId>"

# Microsoft To Do
m365 todo list list
m365 todo task list --listName "Tasks"
m365 todo task add --listName "Tasks" --title "Task description"
m365 todo task set --listId "<listId>" --id "<taskId>" --status "completed"
```

---

## Part 8 — Auth & Session

```bash
# Check who is signed in
m365 status

# Sign out
m365 logout

# Sign back in (browser)
m365 login --authType browser

# Sign in via device code (when browser unavailable or blocked)
m365 login
```

---

## Part 9 — Playwright Fallback

Use Playwright when:
- The user has a **personal Microsoft account** (outlook.com / hotmail.com) — CLI does not support these
- A CLI command returns `access denied` on a work account for Teams or SharePoint
- Any browser step (setup, login) needs to be guided rather than manual

### Personal account — read emails via Playwright
```
Navigate to: https://outlook.live.com
Sign in → navigate to Inbox → extract email list from DOM
```

### Personal account — read calendar via Playwright
```
Navigate to: https://outlook.live.com/calendar
Extract events from the calendar view
```

### Work account Playwright fallback (Teams/SharePoint access denied)
```
Navigate to: https://teams.microsoft.com  or  https://sharepoint.com
Sign in if needed → navigate to the relevant channel or document library
```

Always try the CLI command first. Only switch to Playwright if the CLI returns an error or the account type is personal.

---

## Behaviour Guidelines

- **Always run `m365 status` first** at the start of a session to confirm the user is signed in.
- **Confirm before acting** — always confirm recipient/subject/time with the user before sending emails, creating meetings, or deleting anything.
- **Use ISO 8601 dates** — format: `2026-04-08T10:00:00`. Confirm timezone if ambiguous.
- **Get IDs from list commands** — most action commands need an item ID; run the list first.
- **Auth errors** → `m365 login --authType browser` or device code fallback.
- **m365 not found** → refresh PATH or direct user to run setup script.
- **Personal accounts** → skip CLI, go straight to Playwright fallback.
