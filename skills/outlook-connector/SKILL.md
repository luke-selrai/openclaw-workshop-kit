---
name: outlook-connector
description: Install and operate the Microsoft Outlook & 365 connector. Use this skill when the user asks to set up Outlook, connect Microsoft 365, or interact with emails, calendar, OneDrive, Teams, SharePoint, OneNote, Excel, Contacts, or To Do. Handles full installation and uses Playwright for any browser-based steps.
allowed-tools: Bash,Read,Write,Edit,mcp__Claude_in_Chrome__navigate,mcp__Claude_in_Chrome__computer,mcp__Claude_in_Chrome__get_page_text,mcp__Claude_in_Chrome__find,mcp__Claude_in_Chrome__javascript_tool
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

This registers the PnP Management Shell app with the user's Microsoft tenant. Required because the default PnP app was permanently deleted September 9, 2024.

```bash
m365 setup --interactive
```

**This opens a browser.** Use Playwright to handle it:
1. Run the command — it will output a URL
2. Navigate Playwright to that URL
3. The user signs in and clicks Accept/Allow
4. Wait for the success message before proceeding

If you see `admin consent required` — the user's IT admin needs to approve the app at:
`https://entra.microsoft.com` → Enterprise Applications → PnP Management Shell → Grant admin consent

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

## Part 3 — Calendar

### List upcoming events
```bash
m365 outlook calendar event list \
  --startDateTime "2026-04-07T00:00:00Z" \
  --endDateTime "2026-04-14T23:59:59Z"
```

### Create a meeting
```bash
m365 outlook calendar event add \
  --subject "Meeting title" \
  --startDateTime "2026-04-08T10:00:00" \
  --endDateTime "2026-04-08T10:30:00" \
  --attendees "person@example.com"
```
> Always confirm date, time, and attendees with the user before creating.

### Update or delete a meeting
```bash
m365 outlook calendar event set --id "<eventId>" --subject "New title"
m365 outlook calendar event remove --id "<eventId>"
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
