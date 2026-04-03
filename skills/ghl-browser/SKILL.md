---
name: ghl-browser
description: Browser automation skill — Playwright MCP, Chrome safety, GHL UI ops, 2FA handling, and general web automation for ANY software. The SINGLE source of truth for all browser interaction.
---

# Browser & GHL Automation Skill

**The authoritative reference for ALL browser automation** with GHL and other SaaS tools.

---

## Decision Matrix: Which Tool to Use

```
STEP 1: Can an API do it?
  → GHL data (contacts, opps, tags) → GHL API (MCP / bash helper)
  → Any REST API → curl / dedicated MCP tool
  → YES? Stop here. API is always faster, cheaper, more reliable.

STEP 2: Need browser? Pick the right mode:

  Standard automation (GHL UI, form filling, scraping):
    → Mac: Playwright MCP (--user-data-dir, persistent profile)
    → Server: browser.sh (headless, public only) or standalone Node.js

  Google SSO / TikTok / YouTube re-auth (blocked by Google Workspace):
    → Mac: Playwright MCP Bridge extension (--extension flag)
    → Connects to REAL Chrome with existing Google login

  Cloudflare / bot detection blocking you:
    → Patchright (drop-in Playwright replacement, anti-detection)
    → Rebrowser patches (alternative, enable/disable on demand)

  Need DevTools (network, performance, console debugging):
    → Chrome DevTools MCP (--remote-debugging-port=9222)

  Bulk scraping (many pages, token-sensitive):
    → Playwright MCP CLI mode (npx @playwright/mcp --cli) — 75% fewer tokens
```

### Priority Chain (when one approach fails)
1. **API** (GHL MCP / bash helper / direct curl) — always first
2. **Playwright MCP** `--user-data-dir` — persistent profile, most operations
3. **Playwright MCP Bridge** `--extension` — real Chrome, Google SSO flows
4. **Patchright** — anti-detection when Cloudflare/DataDome blocks you
5. **Chrome DevTools MCP** — when you need network/perf/console data
6. **GHL Internal API** — undocumented endpoints, last resort
7. **Storage state export/import** — session transfer between environments

---

## Environment: Mac (Playwright MCP)

### Configuration
The Playwright MCP server is configured in `~/.claude.json`:
```json
{
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@playwright/mcp@latest", "--user-data-dir", "/Users/<YOUR_USER>/.playwright-profile"],
  "env": {}
}
```

### Persistent Profile
- **Path**: `/Users/<YOUR_USER>/.playwright-profile/`
- Stores cookies, localStorage, saved passwords, Google login, GHL session
- The user only needs to log in ONCE — sessions persist across Playwright restarts
- **NEVER delete this directory** or all saved sessions are lost
- If Playwright can't launch, check for stale `SingletonLock` files in the profile dir:
  ```bash
  rm -f ~/.playwright-profile/SingletonLock
  ```

### Chrome Safety Rules (CRITICAL)

1. **NEVER call `browser_close`** — it destroys the user's open tabs and session state
2. **NEVER kill Chrome processes** (`killall`, `pkill`, `kill -9` on Chrome) — the user has many tabs open
3. **NEVER close tabs** you didn't open — the user's tabs are sacred
4. **If Playwright loses connection**: Ask the user to restart the Playwright MCP server. Do NOT try to "fix" it by closing/reopening.
5. **Let pages stay open** — don't close them when done. The user can close them.

### Available MCP Tools
```
mcp__playwright__browser_navigate     — Go to URL
mcp__playwright__browser_snapshot     — Get page accessibility tree (use instead of screenshot for data)
mcp__playwright__browser_click        — Click element by ref or text
mcp__playwright__browser_fill_form    — Fill form fields
mcp__playwright__browser_type         — Type text (for search boxes, etc.)
mcp__playwright__browser_wait_for     — Wait for element/navigation
mcp__playwright__browser_take_screenshot — Visual screenshot (use sparingly)
mcp__playwright__browser_evaluate     — Run JS in page context
mcp__playwright__browser_tabs         — List open tabs (READ ONLY — never close)
mcp__playwright__browser_press_key    — Press keyboard keys
mcp__playwright__browser_hover        — Hover over element
mcp__playwright__browser_select_option — Select dropdown option
mcp__playwright__browser_run_code     — Run Playwright code directly
mcp__playwright__browser_handle_dialog — Accept/dismiss dialogs
```

**Preferred tools for reading page content:**
- `browser_snapshot` — returns structured accessibility tree, fast, no image overhead
- `browser_evaluate` — run JS to extract specific data (`document.querySelector(...)`)
- `browser_take_screenshot` — only when you need to SEE the visual layout

---

## Environment: Server (Standalone Scripts)

### browser.sh (Headless)
Location: `~/scripts/browser.sh (if using server-side automation)`

```bash
# Screenshot a page
browser.sh screenshot <url> <output_path>

# Scrape text content
browser.sh scrape <url> [css_selector]

# Fill a form field
browser.sh fill <url> <selector> <value>

# Click an element
browser.sh click <url> <selector>

# Save page as PDF
browser.sh pdf <url> <output_path>
```

- Runs headless Chromium — no persistent profile, no auth
- Good for public pages, screenshots, scraping
- NOT suitable for authenticated GHL operations (no session cookies)
- Timeout: `BROWSER_TIMEOUT` env var (default 30000ms)

### Standalone Node.js Scripts (Server — Authenticated)
For server-side GHL UI operations that need auth, write an inline Node.js script:

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext();
    // ... your automation code ...
    await browser.close();
})();
"
```

Server Playwright install: `npx playwright install chromium`

---

## GHL Login Flow

### When Login Is Needed
GHL sessions expire. When Playwright navigates to `app.gohighlevel.com` and hits a login page, handle it automatically.

### Step-by-Step Login (Mac — Playwright MCP)

**Step 1: Navigate to GHL**
```
browser_navigate → https://app.gohighlevel.com/
```

**Step 2: Check if already logged in**
Take a `browser_snapshot`. If you see the dashboard/sidebar, you're logged in — skip to your task.

**Step 3: Enter credentials**
If you see a login form:
```
browser_fill_form → email field: your_email@example.com
browser_fill_form → password field: (from secrets or stored in persistent profile)
browser_click → "Sign in" button
```

**Step 4: Handle 2FA (if triggered)**
See next section.

**Step 5: Location selection**
If prompted to select a location, choose "[YOUR BUSINESS NAME]" (`<YOUR_LOCATION_ID>`).

### GHL Credentials
- **Email**: your_email@example.com
- **Password**: In `~/.claude/projects/<your-project>/secrets/ghl.env` (vars: `GHL_LOGIN_EMAIL`, `GHL_LOGIN_PASSWORD`)
- **Location**: [YOUR BUSINESS NAME]
- **Read password**: `grep GHL_LOGIN_PASSWORD ~/.claude/projects/<your-project>/secrets/ghl.env`

---

## GHL 2FA Handling (Fully Autonomous)

**HARD RULE: NEVER ask the user for the 2FA code. Retrieve it automatically.**

### Flow
1. GHL presents 2FA screen asking for security code
2. Click **"Send code to email"** (shows `your email`)
3. Click **"Send Security Code"** button
4. Wait 5-10 seconds for email delivery
5. Use **Gmail MCP** to retrieve the code:
   ```
   mcp__claude_ai_Gmail__gmail_search_messages
   query: "from:noreply subject:security code newer_than:1d"
   ```
6. Read the email to extract the 6-digit code:
   ```
   mcp__claude_ai_Gmail__gmail_read_message
   message_id: <from search results>
   ```
7. Enter the code into the form:
   ```
   browser_fill_form → security code input (use slowly: true on first spinbutton)
   browser_click → "Verify" or "Submit" button
   ```

### Troubleshooting 2FA
- If email doesn't arrive within 15 seconds, click "Resend code"
- Gmail MCP searches `your_email@example.com` inbox by default
- The code is typically in the email snippet — look for a 6-digit number
- If the code field is a `spinbutton` type, use `browser_type` with `slowly: true`

---

## Common GHL UI Operations

### Navigate to Specific Sections
```
Dashboard:     /v2/location/{locationId}/dashboard
Contacts:      /v2/location/{locationId}/contacts/smart_list/All
Pipelines:     /v2/location/{locationId}/opportunities/list
Calendars:     /v2/location/{locationId}/calendars/view
Conversations: /v2/location/{locationId}/conversations/conversations
Workflows:     /v2/location/{locationId}/automation/workflows
Social Planner:/v2/location/{locationId}/marketing/social-planner
Marketing:     /v2/location/{locationId}/marketing/emails/statistics
Sites/Funnels: /v2/location/{locationId}/funnels-websites/funnels
Memberships:   /v2/location/{locationId}/memberships/client-portal/dashboard
Media Storage: /v2/location/{locationId}/media-storage
Reputation:    /v2/location/{locationId}/reputation/overview
Reporting:     /v2/location/{locationId}/reporting/reports
Payments:      /v2/location/{locationId}/payments/invoices
Settings:      /v2/location/{locationId}/settings/company
```
Base URL: `https://app.gohighlevel.com`
Location ID: `<YOUR_LOCATION_ID>`

**IMPORTANT URL notes:**
- Settings/social-media returns empty page — use `/marketing/social-planner` instead
- Workflows is `/automation/workflows` (NOT `/workflows`)
- Contacts is `/contacts/smart_list/All` (NOT just `/contacts`)
- Calendars is `/calendars/view` (NOT just `/calendars`)

### Pipeline Stage Management (UI Only)
GHL's public API does NOT support creating/modifying pipeline stages. This must be done via UI.

**To create stages:**
1. Navigate to Pipelines page
2. Click the pipeline name
3. Click "Add Stage" or the + button
4. Fill in stage name, click Save
5. After creating, read stage IDs via API: `ghl pipelines` or MCP `opportunities_get-pipelines`

**To reorder/rename stages:**
1. Navigate to pipeline
2. Drag stages to reorder, or click stage name to edit
3. Save changes

### Workflow Management (UI-Heavy)
GHL workflows are visual drag-and-drop. Creating workflows via API is extremely limited.

**Publishing/unpublishing workflows** (internal API — use with caution):
```
PUT https://backend.leadconnectorhq.com/workflow/{locationId}/change-status/{workflowId}
Headers:
  token-id: <Firebase JWT from GHL iframe>
  Content-Type: application/json
Body: {"status": "published", "updatedBy": "<userId>"}
```
Getting the Firebase JWT requires extracting it from a logged-in GHL session.

### Social Media Re-Auth (UI Only)
When social accounts expire (TikTok, YouTube, etc.):
1. Navigate to `/marketing/social-planner` → notification banner has "Re-integrate" button
2. OR: Social Planner → Settings tab → Social Accounts → filter by "Expired"
3. Click "Reconnect" → select the account in the dialog → click "Reconnect" again
4. Complete the OAuth flow in the browser
5. Persistent profile means the social platform login may already be saved

**Known limitation:**
- TikTok Business re-auth via "Continue with Google" fails — Google Workspace blocks automated browsers with `ERR_CONNECTION_CLOSED`. Google's OAuth uses `prompt=select_account` which forces fresh sign-in even with persistent profile.
- **Workaround**: If TikTok account has direct email/password login, use "phone / email / username" instead of Google SSO. Need TikTok credentials stored in secrets.
- **Best fix**: Install the Playwright MCP Browser Extension (see "Chrome Extension Mode" section below). This connects to the user's real Chrome where Google is already logged in — bypasses the OAuth block entirely.

### Form & Survey Builder (UI Only)
- Navigate to Sites → Forms or Surveys
- These are drag-and-drop builders — not automatable via API
- For reading form submissions, use the API: `ghl form-submissions <formId>`

---

## GHL Internal APIs (Undocumented — Use Carefully)

These endpoints are NOT part of GHL's public API. They work with the internal Firebase JWT that GHL's SPA uses.

### Getting the Internal Token
When logged into GHL via Playwright, extract the token:
```javascript
// Run via browser_evaluate
const token = await page.evaluate(() => {
    // GHL stores auth in localStorage
    const keys = Object.keys(localStorage);
    const authKey = keys.find(k => k.includes('firebase:authUser'));
    if (authKey) {
        const data = JSON.parse(localStorage[authKey]);
        return data.spiTokens?.token || data.accessToken;
    }
    return null;
});
```

### Known Internal Endpoints
```
# Workflow status change
PUT backend.leadconnectorhq.com/workflow/{locationId}/change-status/{workflowId}
Headers: token-id, channel: APP

# Pipeline stage creation (UNVERIFIED — may not work)
POST backend.leadconnectorhq.com/pipelines/stage
Headers: token-id, channel: APP
```

**Warning**: Internal APIs can change without notice. Always have a fallback plan.

---

## Troubleshooting

### Playwright Won't Launch
```bash
# Check for stale lock
rm -f ~/.playwright-profile/SingletonLock

# Check if another Chromium instance holds the profile
ps aux | grep -i playwright | grep -v grep

# If needed, restart the MCP server (ask user or use Claude Code /mcp restart)
```

### GHL Returns 403/Blocked
- Cloudflare may block automated requests. Use realistic User-Agent headers.
- Set a custom User-Agent header like `YourBusiness-GHL/2.0.0` in API scripts.
- If Playwright gets Cloudflare challenge: wait for it, the persistent profile usually passes.

### GHL Session Expired
- Navigate to GHL → if redirected to login → follow the Login Flow above
- Persistent profile usually keeps the session alive for days
- After re-login, the session cookie updates in the profile automatically

### MCP Tool Returns Error
- `ghl-official` tools: Auto-inject OAuth. If they fail, the OAuth token may need refresh.
- `ghl-community` tools: May return 401 if auth headers aren't injected. Use ghl-official or bash helper instead.
- Fallback: Use the bash helper (`ghl <command>`) or direct curl.

### Playwright Timeout on GHL Pages
GHL's SPA is heavy. Increase wait times:
```
browser_wait_for → timeout: 30000 (30 seconds)
```
Use `waitUntil: 'networkidle'` for navigation. Some GHL pages take 10-15 seconds to fully load.

**Typical loading pattern:**
1. Navigate → page shows "Loading fresh data..." / "Initializing..."
2. Wait 10-15s with `browser_wait_for(textGone: "Loading fresh data", time: 15)`
3. Take `browser_snapshot` — if still sparse, wait another 10s
4. Workflows page loads inside an **iframe** (`workflow-builder`) — elements have `f32eXXX` refs. Use iframe-aware clicks: Playwright handles this automatically.
5. Social Planner loads inline (no iframe) — normal refs.
6. GHL may show modals (e.g., "AI Builder Enabled") — dismiss with `browser_click` on "Got it" or close button.

---

## General Web Automation (Non-GHL)

The Playwright MCP persistent profile stores sessions for ALL sites the user has logged into — not just GHL. This means you can automate interactions with any SaaS tool.

### Known Logged-In Services (via persistent profile)
- **GHL** — app.gohighlevel.com (primary CRM)
- **Google** — accounts.google.com (Gmail, Drive, Calendar, etc.)
- **Facebook/Meta** — facebook.com, business.facebook.com
- **Stripe** — dashboard.stripe.com (if previously logged in)
- **Xero** — app.xero.com (if previously logged in)
- **LinkedIn** — linkedin.com

### Pattern: Automating Any SaaS Tool

```
1. Navigate to the tool's URL
2. browser_snapshot → check if logged in (look for dashboard elements vs login form)
3. If logged in → proceed with your task
4. If login required → fill credentials (check secrets/ or persistent profile auto-fill)
5. If 2FA required → check email via Gmail MCP (same pattern as GHL)
6. Execute your task using browser_click, browser_fill_form, browser_evaluate
7. Leave the tab open when done (never close)
```

### Handling 2FA for Non-GHL Services
Same Gmail MCP pattern works for any service that sends codes to your_email@example.com:
1. Trigger the "send code" flow on the login page
2. Gmail MCP search: `from:<service-noreply> subject:<code/verify> newer_than:1d`
3. Read the email, extract the code, enter it

For services that use authenticator apps (TOTP) — this cannot be automated. Flag to the user with what's blocked and why.

### Scraping & Data Extraction
For extracting data from any web page:
```
# Get structured content (fast, no images)
browser_snapshot

# Run JS to extract specific data
browser_evaluate → document.querySelectorAll('.price').forEach(e => console.log(e.textContent))

# Visual capture (when you need to SEE layout)
browser_take_screenshot

# Extract table data
browser_evaluate → JSON.stringify([...document.querySelectorAll('table tr')].map(r => [...r.cells].map(c => c.textContent)))
```

### Filling Forms & Submitting Data
```
# Fill a form field
browser_fill_form → selector: "#email", value: "your_email@example.com"

# Select a dropdown
browser_select_option → selector: "#country", value: "AU"

# Click a button
browser_click → text: "Submit" or ref: "button[type=submit]"

# Upload a file
browser_file_upload → selector: "input[type=file]", paths: ["/path/to/file"]
```

### Handling Popups, Modals & Dialogs
```
# Accept/dismiss browser dialogs (alert, confirm, prompt)
browser_handle_dialog → accept: true

# For in-page modals: click the close button or the overlay
browser_click → text: "Close" or ref: ".modal-close"

# Wait for a modal to appear
browser_wait_for → selector: ".modal", timeout: 5000
```

### Heavy SPA Pages (React/Angular apps)
Many SaaS tools are SPAs that load slowly:
- Use `browser_wait_for` with generous timeouts (15-30s)
- After navigation, wait for key elements before interacting
- GHL, Xero, Stripe dashboards all take 5-15 seconds to fully render
- If `browser_snapshot` returns sparse content, wait and retry

---

## Advanced: Performance & Token Optimization

### CLI Mode (4x Token Savings)
Playwright MCP has a CLI mode that uses 75% fewer tokens (~27k vs ~114k per session):
```bash
npx @playwright/mcp --cli
```
- Saves snapshots and screenshots to disk files instead of streaming into context
- Best for high-throughput automation tasks
- Use standard MCP mode for exploratory/interactive work, CLI for bulk operations

### Snapshot vs Screenshot
- **Always prefer `browser_snapshot`** over `browser_take_screenshot`
- Snapshots use the accessibility tree (text-based, fast, no vision model needed)
- Screenshots are only for when you need to SEE visual layout
- Snapshots are cheaper and more reliable for element interaction

### Environment Variables
Add to MCP config for better performance:
- `PLAYWRIGHT_MCP_CDP_TIMEOUT=60000` — increase from 30s default for slow SaaS pages
- `PLAYWRIGHT_MCP_CONSOLE_LEVEL=error` — reduce noise in context window

---

## Advanced: Alternative Approaches

### Chrome Extension Mode (Solves Google OAuth Blocker)
The Playwright MCP Bridge extension connects to the user's REAL Chrome browser — with all existing logged-in sessions (Google, TikTok, etc.). This bypasses the Google Workspace OAuth block that prevents `--user-data-dir` mode from authenticating.

**When to use**: For flows that require Google SSO, TikTok login, or any service that blocks automated browsers.

**Setup** (one-time):
1. Install "Playwright MCP Bridge" from Chrome Web Store (or load unpacked from GitHub)
2. Add a second MCP server config in `~/.claude.json`:
```json
"playwright-extension": {
  "type": "stdio",
  "command": "npx",
  "args": ["@playwright/mcp@latest", "--extension"]
}
```
3. When the MCP connects, it opens a tab selection page — choose which tab the agent controls
4. Agent uses the REAL Chrome session with all cookies/auth intact

**Key differences from `--user-data-dir` mode**:
- Uses the user's actual Chrome profile (not a separate Playwright profile)
- All Google/TikTok/social logins already active
- No SingletonLock issues
- Agent only sees the tab you select (safer)
- BUT: Must be careful — this IS the user's real Chrome, so Chrome safety rules are even more critical

**Status**: Not yet installed. Should be set up to handle TikTok/YouTube re-auth and any Google SSO flows.

### Chrome DevTools MCP (Alternative Browser Control)
Google's official Chrome DevTools MCP — connects to a running Chrome instance via remote debugging port. Different from Playwright MCP: uses Puppeteer under the hood, exposes 26 tools across 6 categories (input, navigation, debugging, network, performance, emulation).

**When to use**: When you need Chrome DevTools features (network inspection, performance traces, console monitoring) alongside automation. Higher token cost (~10k/page vs Playwright's ~2k/snapshot).

**Setup**:
```bash
# 1. Launch Chrome with debugging port
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.chrome-debug-profile"

# 2. Add MCP server
claude mcp add --transport stdio chrome-devtools -- npx -y chrome-devtools-mcp@latest --browserUrl=http://127.0.0.1:9222
```

**Trade-offs vs Playwright MCP**:
- Pro: Full DevTools access (network, performance, console with source maps)
- Pro: Connects to real Chrome (not Chromium) — same as extension mode
- Con: ~5x more tokens per page than Playwright snapshot
- Con: Requires Chrome launched with special flags
- Con: Known bug: drops first characters in text input

**Status**: Available as plugin in Claude Code marketplace (`chrome-devtools-mcp`). Not yet configured — Playwright MCP handles our needs well. Consider adding for debugging/performance analysis tasks.

### Patchright (Anti-Detection — Cloudflare/DataDome Bypass)
Drop-in Playwright replacement that avoids automation detection. Works by not using `Runtime.enable` CDP method (which any website can detect).

```bash
npm install patchright
```

**Key facts**:
- Only patches Chromium (not Firefox/Webkit)
- Removes `navigator.webdriver` flag, hides automation traces
- Reduces CreepJS detection from 100% to ~67%
- Same API as Playwright — just swap the import
- Use ONLY on your own accounts — never for scraping third-party sites
- **Rebrowser patches** (`rebrowser-patches`) is an alternative — patches puppeteer/playwright directly, can be enabled/disabled on demand

**When to use**: When Cloudflare challenge pages or DataDome CAPTCHAs block standard Playwright on YOUR OWN accounts (e.g., a SaaS tool that flags automated browsers).

### Storage State Export (Session Backup & Recovery)
Playwright can export/import authentication state (cookies + localStorage) as JSON. This is a safety net for session recovery.

**Export after successful login**:
```javascript
// Via browser_run_code after authenticating
const state = await context.storageState();
require('fs').writeFileSync('/tmp/ghl-auth-state.json', JSON.stringify(state));
```

**Import to restore session**:
```javascript
const context = await browser.newContext({
  storageState: '/tmp/ghl-auth-state.json'
});
```

**Use cases**:
- Backup GHL session before risky operations
- Quick recovery if persistent profile gets corrupted
- Transfer auth between `--user-data-dir` and standalone scripts
- Server agents: export from Mac Playwright, import on server for authenticated headless ops

### Token Efficiency: Tool Selection Guide
Browser automation burns context tokens fast. Choose the right tool for the job:

```
Task                          | Best Tool              | Tokens/page
------------------------------|------------------------|------------
Read page text/structure      | browser_snapshot        | ~800-2,000
Extract specific data         | browser_evaluate (JS)   | ~200-500
Visual layout check           | browser_take_screenshot | ~5,000-15,000
Full DevTools inspection      | Chrome DevTools MCP     | ~10,000+
Bulk scraping (many pages)    | CLI mode (--cli)        | ~27k/session
```

**Rules**:
1. Always try `browser_snapshot` first — it's the cheapest
2. Use `browser_evaluate` to run JS and extract just the data you need
3. Only use `browser_take_screenshot` when you need to SEE the visual layout
4. For bulk operations, switch to CLI mode to save 75% tokens
5. Save snapshots to files (`filename` param) to avoid flooding context

---

## Playbook: Handling Any Browser Situation

### Site blocks automated browsers (Cloudflare challenge)
```
1. Try Playwright MCP normally → if Cloudflare challenge page appears:
2. Wait 5-10s (Cloudflare sometimes auto-resolves with persistent profile)
3. If still blocked → switch to Patchright for that site
4. If still blocked → use Playwright MCP Bridge (--extension) to use real Chrome
5. Last resort → browser_evaluate to check for challenge, manually solve via extension mode
```

### Need to log into a site with no saved credentials
```
1. Check secrets/ directory for credentials
2. Check if Google SSO is available (many SaaS tools support it)
3. Navigate to login page → fill credentials → handle 2FA via Gmail MCP
4. If Google SSO fails (Workspace block) → use --extension mode
5. After login succeeds → session persists in profile automatically
```

### Need to extract data from a complex SPA page
```
1. browser_snapshot → get accessibility tree (cheapest, ~800 tokens)
2. If snapshot is sparse/loading → wait 15s → retry
3. If you need specific data → browser_evaluate with targeted JS:
   document.querySelectorAll('.target').forEach(e => console.log(e.textContent))
4. If data is in a table → extract as JSON via JS:
   JSON.stringify([...document.querySelectorAll('tr')].map(r => [...r.cells].map(c => c.textContent)))
5. If you need iframes → Playwright handles cross-iframe automatically
6. Only use screenshot if you need VISUAL layout confirmation
```

### Need to automate a multi-step workflow (forms, wizards)
```
1. browser_snapshot → understand the current state
2. browser_fill_form → fill all visible fields
3. browser_click → submit / next step
4. browser_wait_for → wait for next page/step to load
5. Repeat until workflow complete
6. For file uploads → browser_file_upload with absolute path
7. For dropdowns → browser_select_option
8. For date pickers → try browser_fill_form first, then browser_click on calendar
```

### Session expired mid-task
```
1. browser_snapshot → detect login page (look for "Sign in" / email field)
2. If GHL → follow GHL Login Flow (credentials from ghl.env)
3. If other service → check secrets/ for credentials
4. Handle 2FA → Gmail MCP pattern
5. After re-auth → navigate back to where you were
6. Persistent profile updates session cookie automatically
```

### Transfer auth from Mac to server agent
```
1. On Mac: Export storage state after login
   browser_run_code → context.storageState() → save to JSON
2. SCP the state file to server
3. On server: Use in standalone Node.js script
   browser.newContext({ storageState: 'state.json' })
4. Caution: cookies expire — this is a temporary transfer, not permanent
```

---

## Safety Rules Summary

| Rule | Why |
|------|-----|
| Never call `browser_close` | Destroys open tabs and sessions |
| Never kill Chrome processes | The user may have important tabs open |
| Never close tabs you didn't open | The user's tabs are sacred |
| Never ask the user for 2FA codes | Auto-retrieve from Gmail MCP |
| Never ask the user to do anything manually | 100% autonomous execution |
| Never delete `~/.playwright-profile/` | Destroys all saved sessions |
| API first, browser second | Browser is slow and fragile — API is reliable |
| Always check if logged in before login flow | Don't re-login if session is active |
| Server browser.sh is headless only | No auth, no persistent state — public pages only |

---

## Quick Reference Card

```
# Mac — Playwright MCP (authenticated, persistent)
browser_navigate → URL
browser_snapshot → read page content
browser_click → interact with elements
browser_fill_form → fill inputs

# Mac — GHL bash helper (API, no browser)
ghl search-contacts "query"
ghl pipelines
ghl send-sms <contactId> "message"
ghl raw GET "/endpoint"

# Server — browser.sh (headless, public only)
browser.sh screenshot <url> <output>
browser.sh scrape <url> [selector]

# 2FA — fully autonomous
Gmail MCP → search "from:noreply subject:security code newer_than:1d"
Gmail MCP → read message → extract 6-digit code → enter in form

# GHL URLs (locationId = <YOUR_LOCATION_ID>)
Dashboard:  app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/dashboard
Contacts:   app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/contacts/smart_list/All
Pipelines:  app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/opportunities/list
Workflows:  app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/automation/workflows
Social:     app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/marketing/social-planner
Settings:   app.gohighlevel.com/v2/location/<YOUR_LOCATION_ID>/settings/company
```
