---
name: outlook-connector
description: "Connect Outlook and Microsoft 365 to Claude by switching on its built-in connector or by signing in to the `m365` CLI. Use when the user asks to set up Outlook or connect Microsoft 365, or wants mail, calendar, OneDrive, SharePoint, Teams, OneNote, Contacts or To Do work and Microsoft 365 isn't connected yet. Once connected, Microsoft 365 runs through the `mcp__claude_ai_Microsoft_365__*` tools or the `m365` CLI."
allowed-tools: Bash,Read,Write,Edit,mcp__claude_ai_Microsoft_365__*,mcp__playwright__*,mcp__plugin_playwright_playwright__*
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
      reason: The Playwright MCP browser is how this skill drives the sign-in flow on the kit's own route
---

# Outlook & Microsoft 365 Connector

## Overview

This skill does two things:
1. **Connects** Microsoft 365 to Claude (one-time setup)
2. **Operates** the connection - reading and writing mail, calendar, files, Teams, etc.

There are two routes, and they can both exist on the same machine. Never tear one down to set the other up.

- **The built-in Microsoft 365 connector (the default).** Anthropic-built, one button, no setup on the Microsoft side beyond an approval. Covers Outlook mail and calendar, OneDrive and SharePoint files, and Teams chat. Directory page: `https://claude.com/connectors/microsoft-365`.
- **The kit's own route: the `m365` CLI** (the **PnP CLI for Microsoft 365**, `@pnp/cli-microsoft365`). Full command reference: https://pnp.github.io/cli-microsoft365/. Wider reach - admin and tenant work, OneNote, To Do, Contacts, Excel cells, sending Teams messages - at the cost of a real install and an app registration. Run it **only when a need the user actually named requires it**.

> **Account support.**
> - The **built-in connector** requires a Microsoft 365 account on a Microsoft Entra tenant tied to a Microsoft **Business** plan. Personal accounts (outlook.com, hotmail.com) are explicitly unsupported and fail at sign-in.
> - The **`m365` CLI** supports enterprise / work / school Microsoft 365 accounts only. Personal accounts are not supported by the CLI either.
> - So a personal Microsoft account has no connector on either route - go to **Part 9 - Playwright Fallback**.

---

## Start here - ask what they want first (do not skip)

Before opening anything, ask **one** question in plain English:

> "What do you want Claude to do with Microsoft 365 - read and send email? your calendar? files in OneDrive or SharePoint? Teams chats?"

If they under-specify ("connect my email"), double-check the neighbours once, in the same message:

> "Just email, or your calendar, files and Teams too?"

Then route each named need with the table below. **Connect only what they named.** Say in one line what you are *not* setting up and why, so they can ask for it later. If the extra setup isn't needed, don't burden them with it.

---

## Route by need

Harvey's rule, in one line: **read-only mail goes to the built-in connector; writing goes to the built-in connector only if the extra approval for write tools has been granted, otherwise the `m365` route.**

| What they want | Route |
|---|---|
| Read, search or summarise Outlook mail | **Built-in** |
| Read the calendar, check availability, find a time to meet | **Built-in** |
| Find or read files in OneDrive or SharePoint | **Built-in** |
| Read Teams chats, meeting transcripts and recordings | **Built-in** |
| Send mail, write or send drafts, reply, forward, set an auto-reply, sort mail into folders or rules | **Built-in *if* the write tools are switched on for their organisation** (a separate approval - see Phase 1 Step 6). Otherwise the `m365` route. |
| Create, change, delete or RSVP to calendar events | **Built-in *if* the write tools are switched on.** Otherwise the `m365` route. |
| Upload, update, move, rename or delete files in OneDrive/SharePoint | **Built-in *if* the write tools are switched on.** Otherwise the `m365` route. |
| Send mail **with an attachment** | **`m365` route.** Attachments are unsupported in the built-in connector's write tools, by design. |
| **Send** a Teams message | **`m365` route.** The built-in connector reads Teams chats; it has no send tool. |
| OneNote, Microsoft To Do, Contacts | **`m365` route.** The built-in connector has no tools for these. |
| Excel workbook *cells* (read or edit a sheet's contents) | **`m365` route** via Graph (Part 7). Not verified on the built-in connector's file tools - probe there first if the user prefers it, and fall back on a real failure. |
| Admin / tenant work: app registrations, tenant settings, anything in the admin centre | **`m365` route.** |
| Their organisation's Microsoft admin won't approve the write tools | **`m365` route** for the write half; keep the built-in for reads. |
| Personal Microsoft account (outlook.com / hotmail.com) | **Neither connector supports it.** Go to **Part 9 - Playwright Fallback**. |

The directory page badges Microsoft 365 as read-only. **That badge is wrong** - the connector ships 30+ write tools. Route on this table, not on the badge.

---

## Phase 0 - Is Microsoft 365 already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Microsoft 365`.
   - `✔ Connected` → skip to the operating parts (Part 2 onward). Prove it first with one read: `mcp__claude_ai_Microsoft_365__get_me`.
   - `! Needs authentication` → the connection has lapsed. Open `https://claude.ai/customize/connectors` for the user and say: *"Your Microsoft 365 connection needs a quick re-sign-in. Press Reconnect next to Microsoft 365, sign in, and tell me when it says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** `m365 status --output json` - a JSON blob with `connectedAs` set to the user's email means the CLI is signed in. If it is present and a smoke call works (`m365 outlook message list --folderName "inbox" --pageSize 3`), keep using it - say *"Microsoft 365 is already connected"* and skip to the operating parts. Do not set the built-in connector up on top of a working connection.
3. **Nothing found** → route with the table above, then Phase 1 (built-in) and/or Part 1 (the `m365` route).

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than Claude Code), skip steps 1-2: go straight to Phase 1 and prove the result at Step 5 by calling `mcp__claude_ai_Microsoft_365__get_me`.

---

## Phase 1 - Switch on the built-in Microsoft 365 connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button and sign in.

**Step 1 - Check this session can see built-in connectors.** `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way, and run the kit's own route (Part 1) instead.

**Step 2 - Check the one-time company approval.** Before *anyone* on a Microsoft Entra tenant can connect, a Microsoft Entra **Global Administrator** has to approve Claude once for the whole tenant. On Claude **Team or Enterprise** plans there is a second gate: the Claude organisation owner must switch Microsoft 365 on under Organization Settings → Connectors first. On Free / Pro / Max plans only the Global Administrator consent applies. Ask: *"Has whoever looks after your company's Microsoft accounts already approved Claude? If not, they'll need to do that once before this works for anyone."* If they haven't, hand the user that sentence to forward and pause - do not fall back to the `m365` route just to get past an approval gate.

**Step 3 - Open the connector page for them.** Say: *"I'm opening the Microsoft 365 page in your browser. Press **Connect to Claude**, sign in to Microsoft the way you normally do, and say yes when it asks for access. That's the only part only you can do - tell me when it says Connected."* Then open `https://claude.ai/directory/microsoft-365` in **their own browser** (`open` on Mac, `xdg-open` on Linux, `start "" <url>` on Windows). If that page doesn't load, open `https://claude.ai/customize/connectors` instead and tell them: Browse → search "Microsoft 365" → Connect. In the desktop app's Code tab the better route is the composer's **+** → **Connectors** → **Browse connectors** → the **+** next to it: that one shows up in the running session without a restart, whereas the browser page needs the app quit and reopened before any session sees the tools.

**Step 4 - Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 5 - Verify, then prove it.** `claude mcp list` again; `claude.ai Microsoft 365 … ✔ Connected` is the pass. Not there yet → no restart will change this answer (`claude mcp list` runs fresh each time, so it shows a connector the moment the Connect finishes): `! Needs authentication` means Reconnect on the Customize page; no line at all means the Connect didn't complete, so send them back to Step 3. Then call `mcp__claude_ai_Microsoft_365__get_me`. Only a real answer counts; a tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If the tools are missing from this session entirely even though Step 4 passed, the session started before the Connect: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - If they named a writing job, check the write tools are on.** The write half (sending mail, drafts, calendar changes, file changes, mailbox settings) sits behind a **separate, expanded approval** that a Microsoft Entra administrator has to grant on top of the first one. Organisations that connected before the write tools existed have them blocked by default until an admin enables them. Test it rather than assuming: attempt the smallest real write the user asked for (e.g. `mcp__claude_ai_Microsoft_365__outlook_create_draft`) and read the result.
- Works → you are done; writing goes through the built-in connector.
- Refused for permissions → say in one line: *"Reading your mail works. Sending needs one more approval from whoever manages your Microsoft accounts."* Then either wait for that approval, or run **Part 1** for the writing half and keep the built-in connector for reads.

**Step 7 - Hand off.** Two lines: it's connected, and three things they can ask for now, drawn from what they named in the interview.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch Microsoft 365 on for the organisation first. Say so plainly and stop.

**Nothing here handles credentials.** The built-in route never sees a password, a code or a key - the sign-in happens entirely between the user and Microsoft.

**Access notes worth knowing (from Anthropic's security guide).** Requests reach Microsoft from Anthropic's address range `160.79.104.0/21`, so location- or network-based Conditional Access rules may need allowing for. Multi-factor sign-in is enforced when connecting, not re-checked on every later call, and device-compliance rules are evaluated at connection time. An admin can revoke access at any level: one user, the whole connector in Claude, individual permissions in Entra, or the whole tenant. Write operations are rate-limited per user.

---

## Golden rule - do not open the user's own browser (the `m365` route only)

Every sign-in step on **the kit's `m365` route** runs inside the **Playwright MCP** browser (`mcp__plugin_playwright_playwright__browser_*`). Never shell out to `--authType browser` or anything that launches the user's default browser. The only human-in-the-loop moment is **password entry** - the user types their password into the Playwright-controlled window. Claude navigates, clicks, and reads results; nothing bounces back to the user's own Chrome/Safari.

If a CLI command is about to open the user's own browser, stop and switch to the device-code path.

**Carve-out for Phase 1.** This rule exists because the `m365` route reads secrets off the page in a driven browser. The built-in connector reads nothing, so Phase 1 Step 3 deliberately opens the link in the user's *own* browser - that is where they are already signed in to Claude and to Microsoft. Do not drive the built-in connector's sign-in with Playwright.

---

## No-deviation rule

If a step in this skill fails, follow the `if X fails, try Y` branch documented for that step. **Do not improvise** with `gcloud`, `mgc` (Microsoft Graph CLI), `az`, or any other tool this skill does not name. If you hit a failure with no documented recovery, tell the user exactly what failed and stop - don't silently pivot to a different toolchain.

---

## Part 1 - The kit's own route: install and sign in to `m365`

**Run this only when a need the user actually named needs it** - the `m365` rows in the routing table, a session that can't see built-in connectors (Phase 1 Step 1 failed), a Microsoft admin who won't grant the expanded approval for write tools, or a user who explicitly wants the local command-line route. Otherwise stop at Phase 1; the built-in connector is the default.

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

  This is a *different* approval from the one the built-in connector needs (Phase 1 Steps 2 and 6). Granting one does not grant the other; an admin who refused one may still agree to the other, so it is worth asking.

### Step 9: Verify the connector end-to-end
```bash
m365 outlook message list --folderName "inbox" --pageSize 3
```
If three message subjects appear, the connector is fully working.

If this fails with 403 and Step 8 reported scopes as granted, run `m365 logout && m365 login` to refresh the token (old tokens cache 403s), then retry.

### Step 10: `.onmicrosoft.com`-only tenant deliverability note

If the user's only domain is `<tenant>.onmicrosoft.com` (no verified custom domain), tell them:

> "Your tenant doesn't have a verified custom domain, so outbound mail comes from a low-reputation address. Emails to Gmail, Yahoo, or other external providers may be delayed 1-5 minutes or filtered to spam. That's a tenant-level thing, not a connector bug. Check your Outlook Sent Items to confirm the send succeeded regardless of where it lands externally."

This applies to whichever route sends the mail.

---

## Operating: which route's tools

From here on, Parts 2-9 document **the kit's `m365` route**. Through the **built-in connector** the tools are `mcp__claude_ai_Microsoft_365__*` instead; the names differ materially, so the map below is the translation. Where a job has no built-in tool, that is a `m365`-route row in the routing table.

| Job | Built-in connector tool | `m365` route |
|---|---|---|
| Who am I / prove the connection | `get_me` | `m365 status` |
| Search and read mail | `outlook_email_search`, `read_resource` | `m365 outlook message list` / `get` (Part 2) |
| Draft, reply, forward, send mail | `outlook_create_draft`, `outlook_update_draft`, `outlook_send_draft`, `outlook_delete_draft`, `outlook_create_reply_draft`, `outlook_create_reply_all_draft`, `outlook_forward_mail`, `outlook_send_mail` | `m365 outlook mail send`, `m365 request` for replies (Part 2) |
| Folders, categories, rules, auto-reply, trash | `outlook_create_label`, `outlook_update_label`, `outlook_delete_label`, `outlook_modify_labels`, `outlook_batch_modify_labels`, `outlook_modify_thread_labels`, `outlook_create_filter`, `outlook_delete_filter`, `outlook_set_vacation`, `outlook_trash_thread`, `outlook_untrash_thread`, `outlook_batch_delete_messages` | `m365 outlook message move` (Part 2) and `m365 request` against Graph |
| Calendar read, availability | `outlook_calendar_search`, `outlook_find_available_time`, `find_meeting_availability` | `m365 request` against Graph (Part 3) |
| Create / change / delete / RSVP events | `outlook_create_event`, `outlook_update_event`, `outlook_delete_event`, `outlook_respond_to_event` | `m365 request` against Graph (Part 3) |
| OneDrive & SharePoint files | `sharepoint_search`, `sharepoint_folder_search`, `sharepoint_upload_file`, `sharepoint_update_file`, `sharepoint_create_folder`, `sharepoint_copy_item`, `sharepoint_move_item`, `sharepoint_rename_item`, `sharepoint_delete_item` | `m365 onedrive file …`, `m365 spo …` (Parts 4-5) |
| Teams | `teams_list_chats`, `chat_message_search` (read only) | `m365 teams …`, including sending (Part 6) |
| OneNote, To Do, Contacts, Excel cells | none | Part 7 |

Everything in the write rows above needs the expanded approval described in Phase 1 Step 6 before it will run on the built-in connector.

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
> Always confirm recipient, subject, and body with the user before sending. The same confirmation rule applies on the built-in connector's `outlook_send_mail` / `outlook_send_draft`.

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

> **Note:** m365 CLI v11.x has no built-in calendar event commands. Everything goes through `m365 request` with the Microsoft Graph API. `Calendars.ReadWrite` is in the default "All" scope set (Part 1, Step 5, prompt 2) and should have been consented in Part 1, Step 8. On the built-in connector, calendar work is the `outlook_calendar_search` / `outlook_create_event` family instead - no Graph calls needed.

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

> The built-in connector reads Teams (`teams_list_chats`, `chat_message_search`) but cannot send. Sending a Teams message is this route's job.

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

## Part 7 - Contacts, OneNote, To Do, Excel

> The built-in connector has no tools for any of these - this route is the only one that reaches them.

> **Excel workbooks** have no dedicated `m365` command. Reach them through Graph with `m365 request`, the same pattern as Part 3's calendar calls - e.g. `--url "https://graph.microsoft.com/v1.0/me/drive/items/<itemId>/workbook/worksheets"` to list sheets, then `.../worksheets/<name>/usedRange` to read cells. Find the workbook's `itemId` with the OneDrive or SharePoint commands in Parts 4-5 first.

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

## Part 8 - Auth & Session (the `m365` route)

### Check who is signed in
```bash
m365 status
```
This is also the canonical success check after any login - do not parse login output directly.

### Sign out
```bash
m365 logout
```

Signing out of the CLI has no effect on the built-in connector, and disconnecting the built-in connector has no effect on the CLI. They are separate connections.

### Sign in (device-code, Playwright-driven - the default for this route)
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

### Built-in connector equivalents
- "Who is signed in" → `mcp__claude_ai_Microsoft_365__get_me`.
- Sign-in lapsed (`! Needs authentication` in `claude mcp list`) → the user presses **Reconnect** at `https://claude.ai/customize/connectors`. There is no command that re-authenticates it for them.

---

## Part 9 - Playwright Fallback (personal accounts only)

Use this ONLY when neither connector can help:
- Personal Microsoft account (outlook.com / hotmail.com) - the built-in connector requires a Microsoft Business plan tenant and the CLI does not support personal accounts at all
- A CLI command returns `access denied` on a work account for Teams or SharePoint after consent has been verified, and the built-in connector cannot cover the job either

This is different from Part 1, Step 6. In Step 6, Playwright drives the device-code sign-in to authenticate the CLI. In Part 9, Playwright is the connector itself - no CLI involved - because the account type isn't supported.

### Personal account - read emails via Playwright
Navigate to `https://outlook.live.com`. Sign in, navigate to Inbox, extract the email list from the DOM.

### Personal account - read calendar via Playwright
Navigate to `https://outlook.live.com/calendar`. Extract events from the calendar view.

### Work account Playwright fallback (Teams/SharePoint access denied)
Navigate to `https://teams.microsoft.com` or the SharePoint site URL. Sign in if needed, navigate to the channel or document library.

Always try the built-in connector, then the CLI command, before switching to Playwright-as-connector on a work account - and only after Part 1, Step 8 confirmed consent is granted.

---

## Behaviour Guidelines

- **Ask what they want before you set anything up.** One question, one double-check of the neighbouring surfaces, then connect only what they named.
- **Check what's already connected first** - Phase 0. `claude mcp list` for the built-in connector, `m365 status` for the kit's route. Do NOT parse login command output to infer success; `m365 status` is the source of truth for the CLI, and a real read is the source of truth for the built-in connector.
- **The built-in connector is the default.** Only run Part 1 when a named need requires it.
- **Both routes can coexist.** Never disconnect one to set up the other.
- **Never open the user's own browser** for the `m365` sign-in - use Playwright MCP. This is a hard rule. The one exception is the built-in connector's Connect page (Phase 1, Step 3), which must be opened in their own browser.
- **Confirm before acting** - always confirm recipient/subject/time with the user before sending emails, creating meetings, or deleting anything, on either route.
- **Never echo credentials** in narration, output or logs. The built-in route handles none at all.
- **Use ISO 8601 dates** - format: `2026-04-08T10:00:00`. Confirm timezone if ambiguous.
- **Get IDs from list commands** - most action commands need an item ID; run the list first.
- **No deviation** - if a documented step fails, follow the documented `if X fails` branch. Do not improvise with `gcloud`, `mgc`, `az`, or any other tool. If you hit an undocumented failure, report it clearly and stop.
- **Personal accounts** → neither connector works; go straight to Part 9.
