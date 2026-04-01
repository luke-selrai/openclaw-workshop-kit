---
name: outlook-connector
description: Interact with Microsoft Outlook, Calendar, OneDrive, Teams, SharePoint, OneNote, Excel, Contacts, and To Do using the m365 CLI. Use this skill whenever the user asks about their emails, meetings, files, tasks, or anything Microsoft 365 related.
allowed-tools: Bash,Read,Write,Edit
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
  pairs-with:
    - skill: email-composer
      reason: Compose the email with email-composer, then send it through the Outlook connector
    - skill: deep-research
      reason: Use deep-research to find information, then draft and send a summary via Outlook
---

# Outlook & Microsoft 365 Connector

## Quick start

This skill uses the `m365` CLI (PnP CLI for Microsoft 365) to read and act on the user's Microsoft account. Before using any command, verify the tool is installed and the user is signed in.

### Check connection status
```bash
m365 status
```
If output shows `Logged out` or any error, the user needs to run setup first. Direct them to:
```
~/workshop-kit/outlook-connector/setup.bat   (Windows)
~/workshop-kit/outlook-connector/setup.sh    (Mac)
```

---

## Email (Outlook)

### Read recent emails
```bash
m365 outlook mail list --pageSize 10
```

### Read unread emails only
```bash
m365 outlook mail list --pageSize 10 --query "(isRead eq false)"
```

### Search emails by keyword
```bash
m365 outlook mail list --subject "budget" --pageSize 10
```

### Search emails from a specific sender
```bash
m365 outlook mail list --from "john@example.com" --pageSize 10
```

### Read a specific email (use ID from list output)
```bash
m365 outlook mail message get --id "<messageId>"
```

### Send an email
```bash
m365 outlook mail send \
  --to "recipient@example.com" \
  --subject "Meeting follow-up" \
  --body "Hi, thanks for today's call. Here's a quick summary..."
```

### Send to multiple recipients
```bash
m365 outlook mail send \
  --to "person1@example.com,person2@example.com" \
  --subject "Team update" \
  --body "Hello everyone..."
```

### Reply to an email
```bash
m365 outlook mail reply --id "<messageId>" --body "Thanks for reaching out..."
```

### Move email to a folder
```bash
m365 outlook mail move --id "<messageId>" --destinationFolderName "Archive"
```

---

## Calendar

### List upcoming events (next 7 days)
```bash
m365 outlook calendar event list \
  --startDateTime "$(date -u +%Y-%m-%dT00:00:00Z)" \
  --endDateTime "$(date -u -d '+7 days' +%Y-%m-%dT23:59:59Z)"
```

> On Windows, replace the date command with explicit dates e.g. `--startDateTime "2026-04-01T00:00:00Z"`

### List events for a specific date range
```bash
m365 outlook calendar event list \
  --startDateTime "2026-04-07T00:00:00Z" \
  --endDateTime "2026-04-11T23:59:59Z"
```

### Create a meeting
```bash
m365 outlook calendar event add \
  --subject "Sync with Sarah" \
  --startDateTime "2026-04-08T10:00:00" \
  --endDateTime "2026-04-08T10:30:00" \
  --attendees "sarah@example.com"
```

### Create an all-day event
```bash
m365 outlook calendar event add \
  --subject "Company Holiday" \
  --startDateTime "2026-04-10T00:00:00" \
  --endDateTime "2026-04-10T23:59:59" \
  --isAllDay true
```

### Update a meeting
```bash
m365 outlook calendar event set --id "<eventId>" --subject "Updated: Sync with Sarah"
```

### Delete a meeting
```bash
m365 outlook calendar event remove --id "<eventId>"
```

---

## Contacts

### List all contacts
```bash
m365 outlook contact list
```

### Search for a contact by name
```bash
m365 outlook contact list --query "displayName eq 'Sarah Jones'"
```

### Add a new contact
```bash
m365 outlook contact add \
  --displayName "Sarah Jones" \
  --emailAddresses "sarah@example.com" \
  --businessPhones "+61 400 000 000"
```

---

## OneDrive

### List files and folders at root
```bash
m365 onedrive file list
```

### List files in a specific folder
```bash
m365 onedrive file list --folderUrl "/Documents/Projects"
```

### Search for a file
```bash
m365 onedrive file list --query "budget"
```

### Download a file
```bash
m365 onedrive file download --sourceUrl "/Documents/report.xlsx" --targetFile "./report.xlsx"
```

### Upload a file
```bash
m365 onedrive file copy --webUrl "https://..." --targetFolderUrl "/Documents"
```

---

## SharePoint

### Search SharePoint for documents
```bash
m365 spo search --query "annual report" --selectProperties "Title,Path,Author"
```

### List SharePoint sites you have access to
```bash
m365 spo site list
```

### List files in a SharePoint document library
```bash
m365 spo file list --webUrl "https://yourcompany.sharepoint.com/sites/YourSite" --folder "/Shared Documents"
```

---

## Microsoft Teams

### List your teams
```bash
m365 teams team list
```

### List channels in a team
```bash
m365 teams channel list --teamId "<teamId>"
```

### Read recent messages in a channel
```bash
m365 teams message list --teamId "<teamId>" --channelId "<channelId>"
```

### Send a message to a Teams channel
```bash
m365 teams message send \
  --teamId "<teamId>" \
  --channelId "<channelId>" \
  --message "Hello team! Here's today's update..."
```

### List your Teams chats (1:1 and group)
```bash
m365 teams chat list
```

---

## OneNote

### List all notebooks
```bash
m365 onenote notebook list
```

### List sections in a notebook
```bash
m365 onenote section list --notebookId "<notebookId>"
```

### List pages in a section
```bash
m365 onenote page list --sectionId "<sectionId>"
```

---

## Microsoft To Do / Tasks

### List all task lists
```bash
m365 todo list list
```

### List tasks in a specific list
```bash
m365 todo task list --listName "Tasks"
```

### Add a new task
```bash
m365 todo task add --listName "Tasks" --title "Review project proposal"
```

### Complete a task
```bash
m365 todo task set --listId "<listId>" --id "<taskId>" --status "completed"
```

---

## Auth & Session Management

### Check who is currently signed in
```bash
m365 status
```

### Sign out
```bash
m365 logout
```

### Sign in again (browser)
```bash
m365 login --authType browser
```

### Sign in via device code (when browser unavailable)
```bash
m365 login
# Follow the link shown and enter the code at https://aka.ms/devicelogin
```

---

## Behaviour Guidelines

- **Always run `m365 status` first** if the user hasn't used the connector in this session, to confirm they are signed in.
- **For listing**, default to `--pageSize 10` unless the user asks for more. Large inboxes can take time.
- **For sending emails or creating meetings**, confirm the key details (recipient, subject, time) with the user before running the command — these actions cannot be undone easily.
- **Dates and times**: Always use ISO 8601 format (`2026-04-08T10:00:00`). Confirm timezone with the user if ambiguous.
- **IDs**: Many commands require an item ID from a previous list command. Run the list first, find the item, then act on it.
- **If a command fails with an auth error**: Direct the user to run `m365 login --authType browser` and try again.
- **If m365 is not found**: Direct the user to run the setup script for their platform.
- **Work accounts**: Teams and SharePoint commands may require IT admin approval. Offer to use Playwright browser automation as a fallback if CLI access is denied.
