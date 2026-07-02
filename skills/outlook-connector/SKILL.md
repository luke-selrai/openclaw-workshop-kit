---
name: outlook-connector
description: Install and operate the Microsoft Outlook & 365 connector. Use this skill when the user asks to set up Outlook, connect Microsoft 365, or interact with emails, calendar, OneDrive, Teams, SharePoint, OneNote, Excel, Contacts, or To Do. Drives the entire OAuth flow inside a Playwright MCP browser - never opens the user's own browser.
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
      reason: The Playwright MCP browser is how this skill drives the sign-in flow
---

# Outlook & Microsoft 365 Connector

## Overview

This skill does two things:
1. **Installs** the connector on the user's computer (one-time setup)
2. **Operates** the connector - reading emails, calendar, files, Teams, etc.

The connector uses the **PnP CLI for Microsoft 365** (`@pnp/cli-microsoft365`).
Full command reference: https://pnp.github.io/cli-microsoft365/

> **Account support:** Enterprise / work / school Microsoft 365 accounts only.
> Personal accounts (outlook.com, hotmail.com) are not currently supported by the CLI.
> If the user has a personal account, use the Playwright fallback (Part 9).

---

## Golden rule - do not open the user's own browser

Every OAuth step in this skill runs inside the **Playwright MCP** browser (`mcp__plugin_playwright_playwright__browser_*`). Never shell out to `--authType browser` or anything that launches the user's default browser. The only human-in-the-loop moment is **password entry** - the user types their password into the Playwright-controlled window. Claude navigates, clicks, and reads results; nothing bounces back to the user's own Chrome/Safari.

If a CLI command is about to open the user's own browser, stop and switch to the device-code path.

---

## No-deviation rule

If a step in this skill fails, follow the `if X fails, try Y` branch documented for that step. **Do not improvise** with `gcloud`, `mgc` (Microsoft Graph CLI), `az`, or any other tool this skill does not name. If you hit a failure with no documented recovery, tell the user exactly what failed and stop - don't silently pivot to a different toolchain.

---

## Part 1 - Installation

Guide conversationally - one step at a time.

### Step 0: Admin role preflight (do this FIRST)

Registering an Entra app requires **Application Administrator** or **Global Administrator**. A regular Member account will fail silently mid-`m365 setup` with a 403. Check before starting.

Ask the user:
> "Before we start, I need to confirm you have the right admin role on your Microsoft tenant. Do you know if you're an Application Administrator or a Global Administrator?"

If they're not sure, have them open this URL and check their assigned roles:

https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/AdministrativeRole

**Branches:**
- **User has Application Administrator or Global Administrator** → continue to Step 1.
- **User does NOT have either role but has a tenant admin available** → two options. Either the tenant admin grants them one of those roles once (preferred - they own the registration), or the tenant admin runs `m365 setup` themselves while signed in as admin, then transfers use to the user. Pause here until resolved.
- **User is on a personal Microsoft account** (outlook.com / hotmail.com) → the CLI doesn't support personal accounts at all. Skip to **Part 9 - Playwright Fallback** and stop.

### Step 1: Check if already installed
```bash
m365 --version
```
If this returns a version number, skip to Step 5 (pre-configure for device code). If "command not found", continue from Step 2.

### Step 2: Check Node.js
```bash
node --version
```
Needs v20 or higher. If missing or too old, tell the user to install from https://nodejs.org (LTS version) before continuing. Do not attempt to install Node yourself.

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

Verify:
```bash
m365 --version
```
If it still fails, tell the user to open a new terminal and tell you to continue.

### Step 4: Pre-configure for device-code auth

Before running `m365 setup`, force the CLI to use device code instead of opening the user's browser. This is what makes the rest of the flow drivable from Playwright MCP.

```bash
m365 cli config set --key authType --value deviceCode
m365 cli config set --key autoOpenLinksInBrowser --value false
```

### Step 5: Run `m365 setup` (the seven-prompt wizard)

```bash
m365 setup
```

This registers a custom Entra app against the user's tenant (the default PnP app was permanently deleted September 9, 2024, so every user needs their own).

**The wizard asks seven interactive prompts.** Defaults are often wrong. Answer them exactly as below:

| # | Prompt | Answer |
|---|---|---|
| 1 | Create a new app registration / use existing / skip | **Create new** |
| 2 | What scopes do you want to use? | **All** (second option - `User.Read` alone will cause 403s later) |
| 3 | How do you plan to use the CLI? | **Scripting for automation, Interactively for daily use** |
| 4 | Use PowerShell? | **No** (Mac/Linux/unless the user is specifically on Windows PowerShell) |
| 5 | How experienced are you? | **Beginner** (controls help verbosity only) |
| 6 | Apply these settings? | **Yes** |
| 7 | Sign in now to create the app registration? | **Yes** (default is No - easy to miss, and you need Yes here to actually register) |

**If the wizard needs to be run unattended**, pipe answers via an expect-style script:

```bash
expect <<'EOF'
spawn m365 setup
expect "Create" ; send "\r"
expect "scopes" ; send -- "-All\r"
expect "plan to use" ; send -- "-Scripting\r"
expect "PowerShell" ; send "n\r"
expect "experience" ; send -- "-Beginner\r"
expect "Apply" ; send "y\r"
expect "Sign in" ; send "y\r"
expect eof
EOF
```

Prompt 7 triggers a sign-in. Because the CLI is pre-configured for device code (Step 4), the terminal prints a URL and a code. Drive sign-in via Playwright MCP using the flow in Step 6.

### Step 6: Drive sign-in via Playwright MCP

When the CLI prints something like `To sign in, use a web browser to open https://microsoft.com/devicelogin and enter the code ABCD-1234`:

1. Capture the code from the CLI output.
2. `mcp__plugin_playwright_playwright__browser_navigate` to `https://microsoft.com/devicelogin`.
3. `mcp__plugin_playwright_playwright__browser_snapshot` to see the form.
4. `mcp__plugin_playwright_playwright__browser_type` the code into the code input, then click Next.
5. `mcp__plugin_playwright_playwright__browser_snapshot` - the user will see an email input. Ask the user for their M365 email, type it in, click Next.
6. **Ask the user to type their password into the Playwright browser.** This is the one unavoidable human step - do not type passwords on behalf of the user.
7. After password, handle MFA if prompted (user completes on phone / authenticator).
8. `mcp__plugin_playwright_playwright__browser_snapshot` - click Accept / Allow / Yes on any consent screens.
9. Wait for the "You have signed in" / device-code success page.
10. Return to the terminal - the CLI should have completed the app registration by now.

**Save the `clientId`** from the wizard output - you'll need it in Step 8. If lost, retrieve with:
```bash
m365 status --output json
```
The `appId` field is your `clientId`.

### Step 7: Verify sign-in (stable check)

Do NOT parse the login command's live output - it's brittle. Run `m365 status` separately and check its structured output.

```bash
m365 status --output json
```

Expect a JSON blob with `connectedAs` set to the user's email and `appId` present. If `connectedAs` is empty or the command errors, sign-in failed - go back to Step 6 and retry, or fall back to device-code path (Step 8 of Part 8).

### Step 8: Verify scopes were granted (mandatory - `m365 setup` lies about this)

The setup wizard *registers* ~50 delegated permissions, but it does **not always grant admin consent** for them - `--grantAdminConsent` silently skips when the permission is already present without consent. Calls to Graph endpoints return 403 until consent is actually applied.

Check what's consented:
```bash
m365 request --url "https://graph.microsoft.com/v1.0/me/oauth2PermissionGrants"
```

The response has a `value` array where each entry has a `scope` string. Look for these scopes in the combined scope strings:
- `Mail.ReadWrite`
- `Mail.Send`
- `Calendars.ReadWrite`
- `Files.ReadWrite`
- `ChannelMessage.Send`

**Branches:**

- **All critical scopes present** → continue to Step 9.
- **Scopes missing, user IS tenant admin** → drive Playwright MCP to the Entra portal to grant consent:
  1. Navigate to `https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade`
  2. Click the app named "CLI for Microsoft 365" (or whatever the wizard named it)
  3. Open **API permissions**
  4. Click **Grant admin consent for [tenant]**
  5. Confirm
  6. Then in terminal: `m365 logout && m365 login` - old token keeps 403-ing until you re-login.
- **Scopes missing, user is NOT tenant admin** → print a clean forwarded message for the user to send to their tenant admin. Include:
  - The direct consent URL: `https://login.microsoftonline.com/{tenantId}/adminconsent?client_id={clientId}`
  - The list of scopes requested
  - A plain-English explanation of what the app does
  
  Do NOT proceed past Step 8 until consent is granted. Ask the user to tell you when their admin has done it.

### Step 9: Verify the connector end-to-end
```bash
m365 outlook message list --folderName "inbox" --pageSize 3
```
If three message subjects appear, the connector is fully working.

If this fails with 403 and Step 8 reported scopes as granted, run `m365 logout && m365 login` to refresh the token (old tokens cache 403s), then retry.

### Step 10: `.onmicrosoft.com`-only tenant deliverability note

If the user's only domain is `<tenant>.onmicrosoft.com` (no verified custom domain), tell them:

> "Your tenant doesn't have a verified custom domain, so outbound mail comes from a low-reputation address. Emails to Gmail, Yahoo, or other external providers may be delayed 1-5 minutes or filtered to spam. That's a tenant-level thing, not a connector bug. Check your Outlook Sent Items to confirm the send succeeded regardless of where it lands externally."

---

## Part 2 - Email (Outlook)

> **CLI note:** In v11.x the command is `m365 outlook message ...`, not `m365 outlook mail ...`. Older docs show the deprecated form.

### List recent emails
```bash
m365 outlook message list --folderName "inbox" --pageSize 10
```

### List unread emails only
```bash
m365 outlook message list --folderName "inbox" --pageSize 10 --query "(isRead eq false)"
```

### Search by subject or sender
```bash
m365 outlook message list --folderName "inbox" --pageSize 10 --query "contains(subject,'invoice')"
m365 outlook message list --folderName "inbox" --pageSize 10 --query "from/emailAddress/address eq 'person@example.com'"
```

### Read a specific email
```bash
m365 outlook message get --id "<messageId>"
```

### Send an email
```bash
m365 outlook mail send \
  --to "recipient@example.com" \
  --subject "Subject here" \
  --bodyContents "Email body here" \
  --bodyContentType Text
```
> Always confirm recipient, subject, and body with the user before sending.

### Reply to an email (v11 - uses Graph API directly)

The CLI no longer ships `m365 outlook mail reply` in v11.x. Use Graph via `m365 request`:

```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/messages/<messageId>/reply" \
  --method post \
  --content-type "application/json" \
  --body '{"comment":"Reply text here"}'
```

For reply-all:
```bash
m365 request \
  --url "https://graph.microsoft.com/v1.0/me/messages/<messageId>/replyAll" \
  --method post \
  --content-type "application/json" \
  --body '{"comment":"Reply text here"}'
```

### Move email to folder
```bash
m365 outlook message move --id "<messageId>" --targetFolderName "Archive"
```

### Audit rule for every command above

Before running any `m365 outlook ...` command in a new session, sanity-check with `m365 <command> --help` - v11 occasionally renames subcommands between point releases. If `--help` shows a different shape, use the shape `--help` shows, not the shape documented here, and flag the drift to the user.

---

## Part 3 - Calendar (via Graph API)

> **Note:** m365 CLI v11.x has no built-in calendar event commands. Everything goes through `m365 request` with the Microsoft Graph API. `Calendars.ReadWrite` is in the default "All" scope set (Part 1, Step 5, prompt 2) and should have been consented in Part 1, Step 8.

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

**If this returns 403**, Calendars.ReadWrite wasn't actually consented despite the "All" preset. Go back to Part 1, Step 8 and verify/grant consent.

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

## Part 4 - OneDrive

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

## Part 5 - SharePoint

```bash
# Search documents
m365 spo search --query "annual report" --selectProperties "Title,Path,Author"

# List files in a document library
m365 spo file list \
  --webUrl "https://yourcompany.sharepoint.com/sites/YourSite" \
  --folder "/Shared Documents"
```

---

## Part 6 - Microsoft Teams

```bash
# List teams
m365 teams team list

# List channels in a team
m365 teams channel list --teamId "<teamId>"

# Read recent messages
m365 teams message list --teamId "<teamId>" --channelId "<channelId>"

# Send a message
m365 teams chat message send \
  --teamId "<teamId>" \
  --channelId "<channelId>" \
  --message "Your message here"
```

---

## Part 7 - Contacts, OneNote, To Do

```bash
# Contacts
m365 outlook contact list
m365 outlook contact add --displayName "Name" --emailAddresses "email@example.com"

# OneNote - list notebooks and pages
m365 onenote notebook list
m365 onenote page list --sectionId "<sectionId>"

# Microsoft To Do
m365 todo list list
m365 todo task list --listName "Tasks"
m365 todo task add --listName "Tasks" --title "Task description"
m365 todo task set --listId "<listId>" --id "<taskId>" --status "completed"
```

---

## Part 8 - Auth & Session

### Check who is signed in
```bash
m365 status
```
This is also the canonical success check after any login - do not parse login output directly.

### Sign out
```bash
m365 logout
```

### Sign in (device-code, Playwright-driven - the default for this skill)
```bash
m365 login
```
With `authType` pre-configured to `deviceCode` (Part 1, Step 4), this prints a URL and code. Drive Playwright MCP through the flow from Part 1, Step 6.

### Common sign-in errors
| Error code | Meaning | Fix |
|---|---|---|
| AADSTS53003 | Conditional Access blocks sign-in | Ask tenant admin to whitelist the Entra app |
| AADSTS90094 | Admin consent required | Part 1, Step 8 - grant consent in Entra portal |
| AADSTS70043 | Token expired | `m365 logout && m365 login` |
| AADSTS50020 | Account doesn't exist in tenant | Personal account - switch to Part 9 Playwright fallback |

### If sign-in hangs on the device-code page
- Confirm `autoOpenLinksInBrowser` is `false` (`m365 cli config list`).
- Confirm Playwright MCP is actually on the code-entry page (`mcp__plugin_playwright_playwright__browser_snapshot`).
- If Playwright isn't installed, stop and tell the user - do not fall back to opening their own browser.

---

## Part 9 - Playwright Fallback (personal accounts only)

Use this ONLY when the CLI genuinely cannot help:
- Personal Microsoft account (outlook.com / hotmail.com) - CLI does not support these at all
- A CLI command returns `access denied` on a work account for Teams or SharePoint after consent has been verified

This is different from Part 1, Step 6. In Step 6, Playwright drives the OAuth device-code flow to authenticate the CLI. In Part 9, Playwright is the connector itself - no CLI involved - because the account type isn't supported.

### Personal account - read emails via Playwright
Navigate to `https://outlook.live.com`. Sign in, navigate to Inbox, extract the email list from the DOM.

### Personal account - read calendar via Playwright
Navigate to `https://outlook.live.com/calendar`. Extract events from the calendar view.

### Work account Playwright fallback (Teams/SharePoint access denied)
Navigate to `https://teams.microsoft.com` or the SharePoint site URL. Sign in if needed, navigate to the channel or document library.

Always try the CLI command first on work accounts. Only switch to Playwright-as-connector if the CLI returns an error AND Part 1, Step 8 confirmed consent is granted.

---

## Behaviour Guidelines

- **Always run `m365 status` first** at the start of a session to confirm the user is signed in. Do NOT parse login command output to infer success - `m365 status` is the source of truth.
- **Never open the user's own browser** for OAuth. Use Playwright MCP. This is a hard rule.
- **Confirm before acting** - always confirm recipient/subject/time with the user before sending emails, creating meetings, or deleting anything.
- **Use ISO 8601 dates** - format: `2026-04-08T10:00:00`. Confirm timezone if ambiguous.
- **Get IDs from list commands** - most action commands need an item ID; run the list first.
- **No deviation** - if a documented step fails, follow the documented `if X fails` branch. Do not improvise with `gcloud`, `mgc`, `az`, or any other tool. If you hit an undocumented failure, report it clearly and stop.
- **Personal accounts** → skip CLI entirely, go straight to Part 9.
