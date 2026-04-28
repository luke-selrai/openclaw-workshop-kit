---
name: wordpress-connector
description: "Connect the user's WordPress site to Claude Code so Claude can read, draft, and publish posts on their behalf. Drives the entire setup autonomously through the user's WordPress admin in a Playwright MCP browser: installs and activates the official WordPress/mcp-adapter plugin, generates an Application Password, reads the spaced token from the DOM, and writes the connection to ~/.claude.json — all without copy-paste. The only human moment is the user logging in to their WordPress admin once. Use this skill when the user says 'connect my WordPress', 'install the WordPress connector', 'help me set up WordPress', 'connect my WP site', 'let Claude post to my blog', or asks about Application Passwords, the mcp-adapter plugin, or the WordPress Abilities API."
allowed-tools: Bash, Read, Write, Edit, mcp__wordpress__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - wordpress
    - cms
    - publishing
    - mcp
    - mcp-adapter
    - application-password
  pairs-with:
    - skill: first-run-setup
      reason: Shares the shell-detection + PATH patterns used during install
    - skill: telegram-connector
      reason: Same Playwright-MCP-driven autonomous-install pattern. Reference for the rules + cleanup branches.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the user's WordPress admin
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting plugin install, Application Password, or REST endpoint failures
---

# WordPress Connector

## Overview

This skill connects a user's WordPress site to Claude Code so the assistant can read, draft, and publish posts on their behalf via the **official Automattic + WordPress.org MCP pair**:

- **WordPress side:** [`WordPress/mcp-adapter`](https://github.com/WordPress/mcp-adapter) — a free plugin from WordPress.org that bridges the WordPress Abilities API to MCP. Runs inside the user's WP site.
- **Claude side:** [`@automattic/mcp-wordpress-remote`](https://github.com/Automattic/mcp-wordpress-remote) — the npm-published bridge that loads in `~/.claude.json` and talks to the user's WP site over the REST API using their Application Password.

**The user does exactly ONE thing across the entire setup. Everything else is autonomous.**

1. Log in to their WordPress admin in the Playwright browser when it opens (Step 4). One-time, their credentials, on screen they already know.

That's the complete list. **The user does NOT search the plugin directory, does NOT click Install, does NOT generate the Application Password, does NOT copy or paste it.** After Step 4 the Playwright window is logged into the user's WP admin AS the user. Claude drives every WP admin action from there: navigating Plugins → Add New, searching `mcp-adapter`, clicking Install + Activate, navigating to Users → Profile → Application Passwords, naming the password, clicking Add New, reading the spaced token from the DOM, stripping spaces, and writing `~/.claude.json` directly.

If you find yourself about to ask the user to "open your WP admin and click Plugins", "copy the Application Password back to me", or "paste this into your config", stop. That's the wrong path. Drive WP admin in the Playwright window instead.

**Which phase to run.** Phase 1 is first-time setup. Phase 2 is day-to-day operation — using the connector once it's wired.

---

## Golden rule — Claude drives WordPress admin for EVERY WordPress action

**The default path for every WP-admin-side action is the Playwright MCP browser.** Once Step 4 logs the Playwright window into the user's WP admin (the user enters their username + password), that window IS the user's WP admin client for the rest of the flow. Claude uses it for:

- Step 5: Plugins → Add New → search `mcp-adapter` → Install → Activate.
- Step 6: Users → Profile → Application Passwords → name + Add New → read the spaced token from the DOM.

Both happen in the same Playwright window, driven by `mcp__plugin_playwright_playwright__browser_*` tools. Same WordPress account, same admin session — the WP REST API will accept the resulting Application Password because it was issued to that user.

**Do NOT, at any point in Phase 1, ask the user to:**

- Open their WordPress admin themselves (after the login in Step 4)
- Search for, install, or activate any plugin manually
- Navigate to their user profile
- Click "Add New Application Password" themselves
- Copy the Application Password back to you
- Paste any token, URL, or username into chat

If you find yourself about to type any of those, stop. The Playwright window can do all of them.

The **REST-Direct Fallback** section at the bottom of this file is the contingency for when the Playwright MCP browser cannot be used at all (extension not installed, non-recoverable launch failure after two attempts). It is NOT the path to use because manual instructions feel simpler — they don't, they make the user do extra work.

---

## Autonomy rule — Claude does the work, the user does not paste commands

WordPress's REST API + Application Password design means there is **no slash-command surface** for the user to invoke even if they wanted to. Everything happens via Claude's tools:

- `~/.claude.json` `mcpServers.wordpress` block — written via `Write` (instead of any user-paste of `/configure ...`)
- WP admin UI clicks — driven via `mcp__plugin_playwright_playwright__browser_click` (instead of user-side instructions)
- DOM reads for the Application Password — `mcp__plugin_playwright_playwright__browser_evaluate` (instead of "copy the token back to me")

Same end result, no paste required. The Application Password lands in `~/.claude.json` without ever appearing in chat output, on the user's clipboard, or in any tool-call return value.

The only thing the user types across the entire flow is their WordPress admin password into the WP login form (Step 4) — and that goes directly to WordPress, not to Claude. Claude never sees it.

If you find yourself about to type "paste this into the chat", stop. Either run it via Bash, write the file directly, or note that this is a true exception and explain why.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise with `curl https://<site>/wp-admin/...`, do not edit the user's `wp-config.php`, do not invent SQL. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message during Phase 1 follows these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, terminal, MCP, REST API, env var, plugin slug, JSON, contenteditable, selector, OAuth, JWT. The phrase "the browser window I'm using" is preferred over "Playwright". For other technical things, name them plainly: "a small connection helper", "a one-time password just for me", "your WordPress admin", "the plugin we need".
- **Tell them what is about to happen.** Before any action: "I'm going to open your WordPress admin in a browser window now. This takes a few seconds."
- **React warmly.** Good: "That worked. Your WordPress is now connected." Bad: "200 OK. Application Password persisted to mcpServers.wordpress.env."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem, let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths** to the user. Claude runs them; the user does not see them. (No "type X in your terminal" — there is no user-side terminal step in this skill.)
- **Security: never echo the Application Password.** Once written to `~/.claude.json`, the token's job is done. Do not re-read that file, do not echo it in any later message, do not include it in any tool-call return value the user can see. Same rule for the user's WP login password — Claude never sees it (it goes to the WP login form), and Claude must never ask for it.
- **No em dashes inside italicised user-facing strings or `> "..."` blockquotes.** Use commas or full stops in user-facing speech. Em dashes are fine in section headings and Claude-facing prose.

---

## PHASE 1 — Install & Connect

**Run Steps 1 through 7 in order, all in this one Claude Code session.** Step 4 opens the user's WP admin in the Playwright MCP browser and waits for the user's login. Step 5 drives the plugin install autonomously inside that browser. Step 6 drives the Application Password generation autonomously inside that browser. Step 7 verifies. The REST-Direct Fallback section at the bottom is only for when Step 4 fails twice in a row — do not start there.

**Resume check.** If the user is starting a new conversation but `~/.claude.json` already has an `mcpServers.wordpress` block with non-empty `WP_API_URL`, `WP_API_USERNAME`, and `WP_API_PASSWORD`, the connector was at least partially configured by an earlier run. Ask: *"Looks like you started this earlier. Want me to pick up where you left off, or start completely fresh?"*

- **Pick up** → skip to **Step 7** (verify). If verify fails, fall back to Step 4 with a fresh credential rotation.
- **Fresh** → wipe the existing `mcpServers.wordpress` block (preserving every other `mcpServers` entry), then start at Step 1. Note this only wipes the local connection key; the user's old Application Password still exists in their WP admin and should be revoked manually — guide them to do that at the end if they want to.

---

### Step 1 — Prerequisite check

Before any technical step, confirm three things in plain English. Send one question at a time, wait for each answer.

**Question 1 (account):**

> *"Before we begin, three quick checks. First, do you have **admin access** to your WordPress site? (You'd be the one who can install plugins and add users. If someone else manages your site, they'd need to do this part with you, or we'd need their password.)"*

- Yes → Question 2.
- No / not sure → *"That's the first thing to sort. This setup needs a WordPress admin login because we'll install a plugin. Is there someone you can ask, or do you want to pause here and come back?"* If they cannot get an admin login, stop the skill and tell them to come back when they have one.

**Question 2 (host):**

> *"Second, what hosts your WordPress site? Common ones are WP Engine, Kinsta, GoDaddy, Bluehost, SiteGround, or just 'I'm not sure'. WordPress.com Free plan can't install custom plugins, which would block us, so I want to check before we go further."*

- Any managed/self-hosted setup → Question 3.
- WordPress.com Free → *"WordPress.com Free doesn't allow custom plugins, so this skill can't connect to that site. If you upgrade to a Business plan or move to a self-hosted WordPress, this connector will work. I'll stop here for now."* Stop the skill.
- Not sure → *"No worries, we'll find out when I open your admin. If your host blocks plugin installs we'll see it then and stop cleanly."* Continue to Question 3.

**Question 3 (URL):**

> *"Last one. What's the URL of your WordPress site? Something like `https://example.com` or `https://blog.example.com`. Just the address, not the wp-admin path."*

Capture the URL. Validate it: must start with `https://` or `http://`, must not include `/wp-admin` or trailing slashes that confuse later URL building. Normalise: strip trailing slashes, strip `/wp-admin`, strip `/wp-login.php`. Store as `WP_BASE_URL`.

If the user gives a URL that fails to resolve in a quick `curl --head -m 10 <url>`, tell them: *"I can't reach that address. Can you double-check the URL?"* Wait for retry. If it still fails after two tries, stop and tell them to verify the site is online.

---

### Step 2 — Detect OS, shell, and Node version

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
node --version     # required: 18.0.0 or higher (the @automattic/mcp-wordpress-remote bridge uses fetch which is GA in Node 18+; the README recommends Node 22+)
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Treat the same way `whatsapp-connector` and `telegram-connector` do — Claude continues to drive everything via Bash/Write; the OS detection is for path-resolving `~/.claude.json` (`%USERPROFILE%\.claude.json` on Windows; `$HOME/.claude.json` on Mac/Linux).

**Node version handling:**

- **Node >= 18** → continue to Step 3.
- **Node < 18** (or `node --version` reports `command not found`) → tell the user: *"You'll need a slightly newer version of Node.js for this connector. Want me to install it for you, or you can install it yourself first?"* If yes, drive `nvm install --lts` (Mac/Linux with nvm available) or guide the user to https://nodejs.org for a fresh installer. After install, ask the user to restart their Claude Code session and tell you ready, then re-verify.

---

### Step 3 — Confirm Playwright MCP is available

Silently check whether `mcp__playwright__browser_navigate` (or `mcp__plugin_playwright_playwright__browser_navigate` — Claude Code may expose either name depending on whether the user installed via `claude mcp add` or via a marketplace plugin) is in the available tool surface. If yes → Step 4.

If the Playwright MCP server is not registered, install it autonomously via Bash. Mirror the install logic from `skills/first-run-setup/SKILL.md` (its "Playwright MCP server" section is canonical):

```bash
# Primary path — registers an npx-launched Playwright MCP server scoped to this user
claude mcp add playwright npx @playwright/mcp@latest --scope user
```

If that command errors with `Cannot find module @playwright/mcp` or similar npm-resolution failure, fall back to the global-install path:

```bash
npm install -g @playwright/mcp
claude mcp add playwright @playwright/mcp --scope user
```

Tell the user: *"Almost ready. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them, then re-verify the tool surface.

If the server still doesn't show up after restart, fall back to **REST-Direct Fallback** (the rare path that does not need Playwright).

---

### Step 4 — Open the user's WordPress admin in the Playwright MCP browser

Tell the user: *"I'm going to open your WordPress admin in a browser window now. You'll need to log in once. After that I'll handle everything."*

**Pre-flight cleanup.** A previous Playwright Chrome instance with the same user-data-dir can hold a singleton lock and block the next launch. Try the navigation first; if it errors with `SingletonLock`, `process is already running`, or similar, run the cleanup branch then retry once:

- **Mac:**
  ```bash
  pkill -9 -f "Google Chrome.*Playwright" 2>/dev/null
  rm -f "$HOME/Library/Application Support/Google/Chrome/SingletonLock"
  ```
- **Linux:**
  ```bash
  pkill -9 -f "(chrome|chromium|brave).*Playwright" 2>/dev/null
  rm -f "$HOME/.config/google-chrome/SingletonLock"
  rm -f "$HOME/.config/chromium/SingletonLock"
  rm -f "$HOME/.config/BraveSoftware/Brave-Browser/SingletonLock"
  ```
- **Windows (PowerShell, run via `powershell.exe -Command`):** scope to Playwright-launched processes only — do NOT use `Stop-Process` on all chrome processes (that would kill the user's normal browser tabs and other admin sessions):
  ```powershell
  Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='chromium.exe' OR Name='brave.exe' OR Name='msedge.exe'" | Where-Object { $_.CommandLine -like '*Playwright*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```

Trigger this cleanup branch on any of these error patterns from `browser_navigate` (case-insensitive): `SingletonLock`, `process is already running`, `Failed to launch the browser process`, `EADDRINUSE`, `lock file already exists`. Do not run cleanup pre-emptively — only after a launch failure, and only once.

**Navigate.** Use `mcp__plugin_playwright_playwright__browser_navigate` to `<WP_BASE_URL>/wp-admin`.

**Wait for login form.** Use `mcp__plugin_playwright_playwright__browser_snapshot` to confirm the page rendered. The login screen has two visible fields: username/email and password.

Tell the user: *"Your WordPress login screen is open. Please log in with your admin username and password. I'll wait, just tell me 'done' when you're in."*

**Wait for login.** After the user confirms, take a fresh snapshot. The WP admin dashboard should be visible (left sidebar with "Dashboard", "Posts", "Plugins", "Users", etc.). If still on the login screen after 30 seconds, ask the user if they hit any issues and re-take the snapshot.

If login fails repeatedly (more than two retries), or the user reports they cannot get past their host's two-factor / login-protect layer, fall back to **REST-Direct Fallback**.

**Detect WP version.** Footer parsing is fragile — many admin themes (WP Engine, Kinsta white-labels, Astra Pro, Divi) override or hide the `Version 6.X.Y` footer. Use the RSS generator tag instead, which WordPress emits unconditionally:

```bash
# From outside the Playwright session — runs in parallel during admin login
curl -s "<WP_BASE_URL>/feed/" | grep -oE '<generator>[^<]+</generator>' | grep -oE 'WordPress [0-9.]+'
```

Parse the version. The plugin requires **WordPress 6.8 or higher** (`Requires at least: 6.8` in the plugin header), with **6.9 strongly recommended** because 6.9 includes the WordPress Abilities API in core. On 6.8, the user would need a separate `WordPress/abilities-api` companion plugin (whose own repository was archived in February 2026), so the workshop's clean path is 6.9+.

- **Version >= 6.9** → continue.
- **Version 6.8** → tell the user: *"Your WordPress is on 6.8, which technically works with this plugin but needs an extra helper that's harder to install. Updating to 6.9 or later (free, one click in the Updates page) is the smooth path. Want me to handle the update now, or stop here so you can do it on your own time?"* If yes, drive Dashboard → Updates → Update WordPress autonomously, wait for completion, re-run the version check. If no, stop.
- **Version < 6.8** → tell the user: *"Your WordPress version is too old for this connector. The good news is updating WordPress is one click in the Updates page, and it's free. Want me to do it now? If yes, I'll handle it. Otherwise we can stop here and pick up after you've updated."* Same handling as the 6.8 branch.

If the RSS generator tag is missing (some hosts strip it), fall back to driving the dashboard footer in the Playwright window. If both fail, push on to Step 5 — the plugin's own activation will reject the install with a clear "requires WordPress 6.8" error if the version is below floor, and that error becomes the user-facing diagnostic.

---

### Step 5 — Install both required plugins autonomously

The default `mcp-adapter` install registers only three meta-abilities (`discover_abilities`, `get_ability_info`, `execute_ability`). To get a useful day-to-day surface (posts, pages, users, comments), the user needs the companion `Enable Abilities for MCP` plugin alongside `mcp-adapter`. This step installs **both**, autonomously.

**Important context for Claude:** `mcp-adapter` is the official WordPress.org / Automattic plugin but is **NOT in the wp.org plugin directory** as of v0.5.0. It ships via GitHub Releases. The wp.org plugin search will return zero results for it, and other "mcp"-named third-party plugins in the search results are unrelated. Do NOT install any of them. Use the GitHub Releases ZIP upload path documented below.

The companion `Enable Abilities for MCP` IS in the wp.org plugin directory (slug: `enable-abilities-for-mcp`, by fabiomontenegro1987), so it installs via the standard search path.

#### Step 5A — Install `mcp-adapter` from the GitHub Release ZIP

Tell the user: *"I'm installing the WordPress side of the connector now. This takes about 30 seconds."*

**Fetch the latest release ZIP** to a temp path. Use Bash (not the Playwright window):

```bash
curl -L -o /tmp/mcp-adapter.zip "https://github.com/WordPress/mcp-adapter/releases/latest/download/mcp-adapter.zip"
```

On Windows, replace `/tmp/` with `$env:TEMP\` (PowerShell) or `%TEMP%\` (cmd) and use `curl.exe -L -o ...` (curl ships with Windows 10+).

If the curl returns an HTTP error or the file size is < 100KB, the release URL has changed or the user is offline to github.com. Tell the user: *"I couldn't reach the WordPress plugin from GitHub. Either your computer can't reach github.com right now, or the plugin moved. Want to retry, or stop here?"* On retry, fetch the latest release metadata first via `gh api repos/WordPress/mcp-adapter/releases/latest --jq '.assets[0].browser_download_url'` and re-curl from the parsed URL. After two failures, stop.

**Drive the upload-install in the Playwright window:**

1. Navigate to `<WP_BASE_URL>/wp-admin/plugin-install.php?tab=upload`. (Don't try to navigate by clicking — the upload tab anchor is unreliable across WP admin themes; URL-navigate directly.)
2. Wait for the `<input type="file" name="pluginzip">` field to be present (`browser_snapshot`).
3. Use `mcp__playwright__browser_file_upload` (or `mcp__plugin_playwright_playwright__browser_file_upload`) to attach the local `/tmp/mcp-adapter.zip` to that input.
4. Click the `Install Now` button (`#install-plugin-submit` is the stable selector).
5. Wait for the success page that contains a link `Activate Plugin` (or button `.button.button-primary` with text "Activate Plugin"). Snapshot to confirm.
6. Click `Activate Plugin`.
7. Wait for the redirect to `plugins.php?activate=true`. Snapshot to confirm `MCP Adapter` shows up in the Active plugins list with no error notice underneath it.

**If the upload fails with "destination folder already exists":** the plugin was previously installed. Navigate to `<WP_BASE_URL>/wp-admin/plugins.php`, locate the `MCP Adapter` row, click `Activate` if Inactive. If already Active, proceed to 5B.

**If the upload fails with `requires WordPress X.Y` activation error:** the version check from Step 4 missed (RSS generator was stripped). Tell the user the plugin needs WordPress 6.8 or higher and offer to drive the WP update flow. Same handling as the Step 4 version branches.

**If the upload fails with a permission / `chmod` / `umask` error:** the host has restricted plugin uploads. WP Engine, Kinsta, and similar managed hosts sometimes do this during cache deploys or plugin-upload restrictions. Tell the user: *"Your host returned a permission error during the upload. This sometimes happens on managed hosts during cache deploys or plugin-upload restrictions. Want to retry in a moment, or stop and investigate?"* On retry, wait 30 seconds and try once more. After two failures, stop.

#### Step 5B — Install `Enable Abilities for MCP` from the wp.org directory

This plugin IS in the wp.org plugin directory and installs via the standard search-and-install flow.

1. Navigate to `<WP_BASE_URL>/wp-admin/plugin-install.php?s=enable-abilities-for-mcp&tab=search&type=term`. (Pass the search term as a URL parameter rather than typing into the search input — the input has a debounced XHR auto-search that's timing-sensitive.)
2. Wait for `.plugin-card-enable-abilities-for-mcp` to be present in the DOM (this is the result row's stable class — the slug becomes part of the CSS class name).
3. Click the `Install Now` button inside that row (selector: `.plugin-card-enable-abilities-for-mcp .install-now`).
4. Wait for the same button to change to `Activate` (its class flips to `.activate-now` and text updates).
5. Click `Activate`.
6. Wait for the redirect / success notice.

**If the result row is not present after 10 seconds:** the wp.org search may have temporary issues, or the user's host blocks the wp.org search XHR (rare). Fall back to the same GitHub-Releases-style approach: download from `https://downloads.wordpress.org/plugin/enable-abilities-for-mcp.latest-stable.zip` to `/tmp/enable-abilities-for-mcp.zip` and use the upload-install flow from 5A.

**If the activate fails with an "incompatible with WP version" error:** the user is on WP < 6.9 and `Enable Abilities for MCP` requires 6.9. Tell them: *"This plugin needs WordPress 6.9 or later. Want me to drive a WordPress update first, or stop?"* On yes, drive Dashboard → Updates → Update WordPress, then retry the activation.

#### Step 5C — Verify both plugins are active

Take a snapshot of `<WP_BASE_URL>/wp-admin/plugins.php`. Confirm both `MCP Adapter` and `Enable Abilities for MCP` show in the Active plugins list with no fatal-error notice.

**Verify the MCP route is reachable.** From Bash (not the Playwright window — we want to confirm external HTTP reach):

```bash
curl -s -o /dev/null -w "%{http_code}\n" "<WP_BASE_URL>/wp-json/mcp/mcp-adapter-default-server"
```

Expected response: HTTP `401` (Unauthorized — the route exists, just needs Application Password auth) or `405` (Method Not Allowed for GET — the route is POST-only). Either confirms the route is registered. **HTTP `404`** = route not registered → drive `Settings → Permalinks → Save Changes` in the Playwright window to flush rewrite rules, then retry the curl. If still 404, the install is incomplete; stop and tell the user.

If the user's host has persistent object cache (WP Engine, Kinsta, sites with W3 Total Cache or LiteSpeed Cache + object-cache addons), the rewrite-rules cache may stay stale even after a permalinks flush. Drive `Tools → Site Health → Cache` in the Playwright window. If a "Object Cache" notice is present, click the "Flush" button. Retry the route check.

---

### Step 6 — Generate the Application Password autonomously

Still in the Playwright window. The plugin is active; now Claude needs an Application Password to authenticate API calls.

**Navigate to the user profile.** Click `Users` in the left sidebar, then `Profile` (or click the user-avatar in the top right and select "Edit Profile"). Confirm by snapshot — the page title should be "Profile".

**Find the Application Passwords section.** Scroll the profile page to the bottom. The section is labelled "Application Passwords" with a help text about how they're used.

**If the section is missing:** Application Passwords are disabled on this site. Common causes:

- **Solid Security** (formerly iThemes Security, renamed in March 2023): Solid Security → Settings → Configure → **Application Passwords** → toggle to enabled.
- **Wordfence**: Wordfence → Login Security → Settings → **Disable Application Passwords** is checked. Or Wordfence → Firewall → All Firewall Options → **Application Passwords** toggle.
- **All-In-One Security (AIOS)**: WP Security → Brute Force → **Application Passwords** tab.
- **The site is served over plain HTTP without `WP_ENVIRONMENT_TYPE=local`** (WordPress core requires HTTPS for Application Passwords by default).

Tell the user: *"This site has Application Passwords disabled. That's usually a setting in a security plugin like Solid Security, Wordfence, or All-In-One Security. Want me to drive into the plugin's settings and enable them, or stop here so you can do it on your own?"* If they say drive in, navigate to the most likely security-plugin settings page in the Playwright window (check `<WP_BASE_URL>/wp-admin/plugins.php` first to identify which security plugin is active), find the Application Passwords toggle, enable it, and re-attempt the password generation. If they say stop, stop.

**Generate the password.**

1. Click the input with `id="new_application_password_name"` (the visible label is "New Application Password Name", but click by the stable id, not by visible label — visible text localizes to the user's WP admin language).
2. Type `Claude Assistant`.
3. Click the submit button with `id="do_new_application_password"` (the visible label is "Add New Application Password" in English, but localizes — for example, German renders as "Neues Anwendungspasswort hinzufügen". Click by id.)

**Read the password from the DOM.** After submit, WordPress reveals the new Application Password inline in a dismissible admin notice that appears above the existing Application Passwords table (not in a separate dialog). The password text is rendered inside a `<p class="application-password-display">` element. Use `mcp__playwright__browser_evaluate` (or the `mcp__plugin_playwright_playwright__` equivalent) to read its content:

```javascript
() => document.querySelector('.application-password-display')?.textContent.trim() || null
```

If the result is `null`, the form submission did not produce the notice (possibly because of a security-plugin block — see "If the section is missing" branch above). Stop and surface the diagnostic.

The format is four-character groups separated by spaces, for example `cUAn CKZ1 u5DN abcd EFGH 5678`. The notice element also contains a copy button — the `textContent` includes only the password text node (the button is a sibling, not nested), so a plain `textContent` read is safe; defensively trim whitespace.

**Strip spaces.** WordPress accepts the password with or without the readability spaces; `@automattic/mcp-wordpress-remote` strips spaces server-side, but strip them on our side too for cleanliness:

```javascript
appPassword.replaceAll(' ', '')
```

**Capture the username.** From the same profile page, read the "Username" field (it is read-only in the profile but visible). Store as `WP_API_USERNAME`.

**Close the new-password notice.** Click the "OK, I've saved it" / dismiss button so the page returns to the normal Application Passwords list state.

If at any point the user asks "what's that password?" — tell them: *"It's a one-time key WordPress just generated for me. I've stored it safely on your computer; you don't need to write it down or remember it. If you want a fresh one later, just tell me and I'll rotate it."*

---

### Step 7 — Save credentials and verify

**Build the URL.** The mcp-adapter plugin's default endpoint is `<WP_BASE_URL>/wp-json/mcp/mcp-adapter-default-server`. Construct the full URL.

**Write `~/.claude.json`.** Resolve the path:
- Mac/Linux: `$HOME/.claude.json`
- Windows: `%USERPROFILE%\.claude.json`

**Tell the user FIRST, before writing:** *"I'm about to save your connection details. Please make sure Claude Code itself is closed in any other windows. If it's open elsewhere it might be writing to the same file at the same time. Tell me when you've checked."*

Wait for confirmation. This avoids the harness-vs-skill write race that can corrupt the file.

**Always back up before write.** Regardless of parse success, snapshot the current file to `~/.claude.json.backup-<UTC-timestamp>`:

```bash
cp -p "$HOME/.claude.json" "$HOME/.claude.json.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null
```

(Windows PowerShell: `Copy-Item "$env:USERPROFILE\.claude.json" "$env:USERPROFILE\.claude.json.backup-$(Get-Date -Format 'yyyyMMddTHHmmssZ')"` — or skip if the file does not exist yet.)

Then read the existing file (use `Read`). Parse as JSON. If the file does not exist, the JSON to write is just the WordPress block. If it exists but cannot be parsed, **STOP. Do not write.** Tell the user in plain English: *"Your settings file looks corrupted. I can rebuild it from scratch, but you'd lose any other connections you had set up (like Xero, HubSpot, etc.) and need to reinstall those. I've saved a backup of the corrupted version. Want me to rebuild, or stop here so you can recover the file manually first?"* Wait for explicit consent before writing the fresh config.

If parseable, merge into the existing `mcpServers` object:

```json
{
  "mcpServers": {
    "wordpress": {
      "command": "npx",
      "args": ["-y", "@automattic/mcp-wordpress-remote"],
      "env": {
        "WP_API_URL": "<WP_BASE_URL>/wp-json/mcp/mcp-adapter-default-server",
        "WP_API_USERNAME": "<wp username from Step 6>",
        "WP_API_PASSWORD": "<spaces-stripped Application Password from Step 6>"
      }
    }
  }
}
```

**Rules:**

- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other entry the user already has.
- File permissions: on Mac/Linux, ensure `~/.claude.json` is mode `600` (`chmod 600 $HOME/.claude.json`). On Windows, the default user-profile ACL is sufficient.
- Never echo any of the three env values back to the user after writing them.

**After write, read back and validate.** Re-read `~/.claude.json` with `Read`, parse as JSON, confirm:
1. The parse succeeds.
2. `mcpServers.wordpress` exists.
3. `mcpServers.wordpress.env.WP_API_URL`, `WP_API_USERNAME`, `WP_API_PASSWORD` are all present and non-empty.
4. Every other `mcpServers.*` entry that was present before the write is still present (compare against the pre-write parse).

If any of (1)-(4) fails, **do not** instruct the user to restart yet. Restore from the most recent `~/.claude.json.backup-<timestamp>` and retry the merge once. After two failures, stop and tell the user the connection write is unstable, with the backup path. Do NOT silently proceed with a partial-write — that leaves the user's other MCP servers broken AND may leave a half-written Application Password in WP admin as a forgotten unrevoked credential.

**Tell the user:** *"I've saved the connection. One more step. Please close Claude Code completely and open it again, then tell me you're back. This is so it picks up the new connection."*

**Wait for restart.** When the user returns, tell them: *"Welcome back. Let me check that everything is talking to your WordPress."*

**Verify.** mcp-adapter's default install exposes exactly three meta-abilities surfaced as MCP tools:

- `mcp__wordpress__discover_abilities` — list all abilities the WP site has registered
- `mcp__wordpress__get_ability_info` — get details for a named ability
- `mcp__wordpress__execute_ability` — invoke a named ability with arguments

Call `mcp__wordpress__discover_abilities` with `{}` (no arguments). Handle the response:

- **Returns a non-empty array of abilities** → connection is alive. The exact ability set depends on which abilities-aware plugins are installed on the WP side. With the `Enable Abilities for MCP` companion plugin from Step 5B activated, expect post / page / user / comment / category / tag / media abilities under names like `wp/posts/list`, `wp/posts/create`, `wp/users/list`, etc. (The exact namespace prefix may vary across `Enable Abilities for MCP` versions; the abilities are discovered at runtime, not hard-coded.) Capture the count of abilities in the response, then tell the user:
  > *"All done. I'm now connected to your WordPress site, with [N] capabilities available. You can ask me things like 'show me my recent posts', 'draft a post about [topic]', or 'list my draft posts'. Give it a try."*

- **Tool returns `WordPress connection failed during initialization` (the bridge's own error code -32603)** → The `WP_API_URL` resolved but the WP site rejected the credentials. Re-run Step 6 (regenerate Application Password — the previous one may have been one-time-shown but never saved correctly). If second attempt also fails, tell the user the WP site is rejecting the password and stop.

- **Tool returns `401 Unauthorized` or `Invalid username or password`** → Same as above. Username is wrong or password didn't get written correctly. Re-run Step 6.

- **Tool returns `404 Not Found`** → The mcp-adapter plugin route is not registered. Re-check the plugin is active (Step 5 verification). If it is, the route may need a permalink flush — drive `Settings → Permalinks → Save` in the Playwright window (no field changes needed; just clicking Save flushes rewrite rules), then retry the verification.

- **Tool surface is not yet available (`mcp__wordpress__*` tools missing entirely)** → Claude Code didn't pick up the new MCP server. Tell the user: *"Looks like Claude Code didn't pick up the new connection yet. Please make sure you fully closed it (not just the window) and opened it again, then let me know."* Repeat the restart instruction.

- **Any other error** → Translate to plain English, never raw. Retry once. If still failing, tell the user the connection isn't responding and offer to reset and try again.

---

## PHASE 2 — Use Tools

Once configured, use the `mcp__wordpress__*` MCP tools to read and modify WordPress content.

### The tool surface is two-layer (and one of them is dynamic)

**Layer 1 — fixed meta-tools.** `mcp-adapter`'s default install exposes exactly **three** MCP tools, regardless of which plugins are on the WP side. These are the entry points to everything else:

| Tool | Purpose | Use when |
|---|---|---|
| `mcp__wordpress__discover_abilities` | List every ability the WP site has registered | First call of a session, or whenever you suspect new plugins were installed. Returns `[{name, summary, ...}, ...]`. |
| `mcp__wordpress__get_ability_info` | Get the full input/output schema and docs for one named ability | Before invoking an unfamiliar ability. Returns the JSON schema for `arguments` so you build the call correctly. |
| `mcp__wordpress__execute_ability` | Invoke a named ability with arguments | Day-to-day work. Pass `{name: "<ability-name>", arguments: { ... }}`. Returns whatever the ability returns. |

**Layer 2 — dynamic ability registry.** `mcp-adapter` is a passthrough to the WordPress Abilities API. The set of abilities depends entirely on which abilities-aware plugins the user has installed:

- **Bare `mcp-adapter` only** → almost zero domain abilities (posts, pages, comments are not exposed).
- **`mcp-adapter` + `Enable Abilities for MCP`** (the companion installed in Step 5B) → posts, pages, users, comments, categories, tags, media abilities are registered. Exact ability names depend on the companion plugin's version. As of `Enable Abilities for MCP` v2.0.2, expect ability names roughly under the `wp/<resource>/<verb>` shape (e.g. `wp/posts/list`, `wp/posts/create`, `wp/comments/list`). **Always discover first**; do not assume names.
- **`mcp-adapter` + your custom plugin** → whatever your plugin called `wp_register_ability()` for, with `meta.mcp.public = true`.
- **Plugins like WooCommerce, Yoast SEO, ACF** can register additional abilities, but only if those plugins (or a companion) explicitly register them with the Abilities API. Most don't yet (as of late 2026). Treat their abilities as bonus, not assumed.

**Practical implication:** before the first domain action in a session, call `mcp__wordpress__discover_abilities`. Cache the response for the session. Only then call `execute_ability` with confidence about which `name` is valid. If a user asks for something whose ability isn't registered, surface that fact instead of fabricating a tool call.

### Worked example — list recent posts

User: *"Show me my recent posts."*

```
1. Call mcp__wordpress__discover_abilities with {}
2. Filter the response for an ability whose name matches /post.*list/ (case-insensitive). Most commonly: "wp/posts/list" with Enable Abilities for MCP installed.
3. If found, call mcp__wordpress__get_ability_info with {name: "wp/posts/list"} to read its argument schema.
4. Call mcp__wordpress__execute_ability with {name: "wp/posts/list", arguments: { per_page: 10, status: "any" }} (use the actual schema-allowed argument names).
5. Render the result as a readable list (title + status + date), not raw JSON.
```

If step 2 finds nothing, tell the user: *"I'm connected to your WordPress, but the post-listing capability isn't registered on your site. The `Enable Abilities for MCP` companion should give us that. Let me check it's still active."* Then drive `<WP_BASE_URL>/wp-admin/plugins.php` in Playwright to verify, or stop and ask the user to investigate.

### Prompt-to-tool mapping

The user-facing intents below all route through the meta-tool / ability discovery pattern. The right-hand column is the abstract intent, not a hard-coded tool name (because the tool name is dynamic per Layer 2).

| What the user says | What Claude does |
|---|---|
| "Connect my WordPress" / "Install the WordPress connector" | **Run Phase 1** (starting with the prereq check at Step 1) |
| "Show me my recent posts" | `discover_abilities` → find post-list → `execute_ability` |
| "Show me my drafts" | Same path with `status: draft` argument |
| "What's the latest published post?" | Same path with `status: publish`, sort by date desc, limit 1 |
| "Draft a post about [topic]" | Find post-create ability → `execute_ability` with `status: draft` — **confirm before calling** |
| "Update post [N] to add [content]" | Find post-update ability → `execute_ability` — **confirm before calling** |
| "Publish draft [N]" | Find post-update ability → `execute_ability` setting `status: publish` — **confirm before calling**, treat as a high-stakes action since the post becomes live |
| "Delete post [N]" / "Trash post [N]" | Find post-delete ability → `execute_ability` — **confirm before calling**, default to trash (recoverable) not force-delete |
| "List my pages" | Find page-list ability → `execute_ability` |
| "Show me comments on post [N]" | Find comment-list ability → `execute_ability` filtered by post ID |
| "Mark comment [N] as spam" | Find comment-update ability with status:spam → `execute_ability` — **confirm before calling** |
| "List my categories" | Find taxonomy-list ability with taxonomy:category → `execute_ability` |
| "What's my site about? / What's my site title?" | Find site-info ability → `execute_ability` |
| "What can my WordPress do?" | `discover_abilities` and present a grouped summary of available abilities |
| "Add a new user" / "Promote [user] to admin" / "Delete [user]" | Find the user-mutation ability → `execute_ability` — **HIGH-STAKES, requires explicit unambiguous user confirmation, never inferred** |

### Behaviour Guidelines (Phase 2)

- **Always confirm before publishing or deleting.** Drafts are safe; publishing makes a post live to the world. Summarise what you're about to do (title + first paragraph + status change) and wait for the user's OK before calling the tool.
- **Drafts by default.** When asked to "write a post about X", create as `status: draft` first, surface the draft content for the user's review, and only publish on explicit second confirmation.
- **Format content cleanly.** Posts created via the API should use Gutenberg block syntax (`<!-- wp:paragraph -->...<!-- /wp:paragraph -->`) for proper rendering in the editor. Plain HTML works but loses the block-editing experience.
- **Discover-then-call discipline.** Always run `discover_abilities` once per session before the first domain call. Do not invent ability names. If a user asks for something not in the discovered set, say so; don't pretend.
- **User-mutation guardrail.** Any ability whose discovered name contains `user_create`, `user_delete`, `user_role`, `user_promote`, or any role-elevation verb is treated as ADMIN-level and requires explicit, unambiguous user confirmation (never inferable). The skill never auto-creates, auto-elevates, or auto-deletes users.
- **Settings guardrail.** Any ability whose discovered name contains `option_set`, `setting_set`, or `site_url` is similarly high-stakes (changing site URL or admin email mid-session can lock the user out). Confirm-first, no exceptions.
- **Pagination defaults.** Default to 10 items per list call. Offer to fetch more if there are additional pages.
- **Don't bulk operate without warning.** If the user says "delete all draft posts older than 6 months", count first, summarise, get confirmation, then operate one-at-a-time with a small delay so a misclick doesn't nuke everything.
- **Single site per connector.** This skill is locked to one WP site per Application Password. To connect a second site, run Phase 1 again with that site's URL — it'll add a second `mcpServers.wordpress-<n>` block.
- **Never echo or log credentials.** `WP_API_URL`, `WP_API_USERNAME`, and `WP_API_PASSWORD` must never appear in any output visible to the user.

---

## Error Handling (Phase 2)

| Error | What to say to the user | How to fix |
|---|---|---|
| `WordPress connection failed during initialization` (bridge code -32603) | "Your WordPress connection isn't working, let me check why." | Run `wp_site_info` (or any read tool) to surface the underlying cause. Common: Application Password revoked from WP admin, site moved to a new URL, user account disabled. If the password was revoked, run Phase 1 Step 6 to mint a new one. |
| `401 Unauthorized` on a specific call | "Your connection key isn't being accepted, let me sort that now." | Same as above — likely the Application Password was revoked or the user's role was downgraded. Re-run Step 6. |
| `403 Forbidden` on a specific call | "I don't have permission for that, let me check your role." | The user's WP role doesn't include the capability that ability requires. Tell the user which capability they're missing in plain English (e.g. "publishing posts is restricted to editors and admins"). |
| `429 Too Many Requests` | "WordPress is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds, retry once. If still 429, tell the user their host's rate limiting is tight and suggest waiting a minute. |
| `404 Not Found` for a specific tool | "I couldn't find that tool — let me see what's available." | Call `tools/list` to see what abilities are registered. The user may need to install the plugin that provides the ability they want (e.g. WooCommerce abilities require WooCommerce + an abilities-aware extension). |
| `500 Internal Server Error` | "Your WordPress site hit an error, let me see if there's more info." | Surface the response body if there's a useful message. Common: a plugin conflict on the WP side. The user may need to deactivate suspicious plugins or check their error log. Do not auto-fix. |
| MCP server not discovered (`mcp__wordpress__*` tools missing) | "The WordPress connection isn't active in this session. Please close Claude Code fully and reopen it, then try again." | User restarts Claude Code. |

---

## Security Assessment

This skill grants Claude broad authority to read, draft, publish, modify, and delete content on the user's WordPress site through their Application Password. The risks below are catalogued so the prereq check, autonomy rule, and Phase 2 confirmation prompts can defend against them.

| # | Risk | Likelihood | Impact | Mitigation in this skill |
|---|---|---|---|---|
| 1 | **Application Password leak via leaked `~/.claude.json`.** Token grants full role-equivalent access until revoked. | Medium | High (attacker can publish, edit, delete, manage users) | File permissions guidance in Step 7 (mode `600` on Mac/Linux). Token never echoed back. Encourage user to enable filesystem encryption. Recommend rotating the password from WP admin if the file is ever shared. |
| 2 | **WordPress admin password leak via Step 4.** Mitigated structurally — the user types directly into the WP login form in the Playwright window; Claude never sees the credentials. | Low | High | The skill explicitly does not capture the login form values. `browser_evaluate` reads only the post-login dashboard state, not the password field. |
| 3 | **Unauthorised content publishing.** Anyone with shell access can call `wp_post_create` with `status: publish` to publish anything to the user's site. | Medium | High (brand damage, legal exposure for offensive content) | Phase 2 publishing tools all require **explicit confirmation**. Drafts are the default. Recommend pairing with `~/.claude.json` filesystem encryption. |
| 4 | **Comment moderation abuse.** Token holder can spam, trash, or unapprove legitimate comments — the user may not notice. | Medium | Medium (silenced critics, hidden customer feedback) | `wp_comment_spam` and `wp_comment_trash` are confirm-first. Skill instructs Claude to summarise the comment text before destructive action. |
| 5 | **User-management abuse.** With admin role, the connector can add/remove users, change roles, and lock the legitimate admin out. | Low | Critical (account takeover) | User-modification tools are confirm-first and require explicit, unambiguous user prompts (not inferred). The skill never auto-creates or auto-elevates users. Recommend the user keep a separate admin account that does not have an Application Password issued. |
| 6 | **Plugin install authority.** mcp-adapter exposes whatever abilities are registered, including potentially plugin-install abilities if a plugin chooses to expose them. Future plugins could add destructive abilities. | Low | High | Phase 2 calls `tools/list` before invoking unfamiliar tools. The skill warns Claude to treat `_install`, `_activate`, `_deactivate`, `_delete` abilities as confirm-first regardless of which family they belong to. |
| 7 | **Site-wide settings change.** `wp_options_set` (if registered) can change site URL, admin email, default post status — silent destabilisation. | Low | High | Settings-mutation abilities are confirm-first. The skill flags any `_options_set` or `_settings_*` call as high-risk and requires explicit user OK. |
| 8 | **Application Password not revocable silently.** Tokens appear in WP admin → Profile → Application Passwords with name + last-used time. User can revoke any time. | Low | (positive) High visibility | The skill names the password `Claude Assistant` so it's identifiable. Recommend the user check the list quarterly and revoke any they didn't expect. |
| 9 | **Plugin conflict silent fail.** Some security plugins (Wordfence, iThemes Security) block REST API or restrict Application Passwords by default — the connector will appear to work then 401 on every call. | Medium | Low (just confusing, not destructive) | Step 6 detects disabled Application Passwords and stops with a clear message. Phase 2 401-handling explicitly covers the "post-Phase 1 the security plugin started blocking" case. |
| 10 | **Fall-back path leaks credentials.** The REST-Direct Fallback at the bottom of this file involves the user copying the Application Password manually if Playwright is unavailable. That manual path puts the password in chat / clipboard. | Low | High (in fallback only) | Fallback explicitly warns the user, advises rotating the password after install regardless, and minimises the period the password is visible. |

**Recommended user-side hardening (not in this skill, but worth telling the user):**

- Enable two-factor auth on the WP admin account that owns the Application Password.
- Review WP admin → Users → Profile → Application Passwords quarterly. Revoke any that aren't `Claude Assistant`-named.
- Keep at least one separate admin account with NO Application Passwords issued, as a recovery account in case `Claude Assistant` is compromised.
- Rotate the `Claude Assistant` Application Password every 90 days. Ask Claude to do it for you ("rotate my WordPress connection key").

---

## Scope Limitations

The WordPress connector **can** do (via `@automattic/mcp-wordpress-remote` + `WordPress/mcp-adapter`):

- Read and write posts, pages, comments, terms (categories + tags), media metadata, site options
- Create new drafts; publish on explicit confirmation
- Moderate comments (approve, spam, trash)
- Read user list; modify users with admin role
- Discover dynamically registered abilities from any abilities-aware plugin (WooCommerce, Yoast SEO, ACF, etc.)

The WordPress connector **cannot** do:

- **Modify the database directly.** mcp-adapter only exposes the Abilities API; arbitrary SQL is out of reach.
- **Install or activate plugins from Phase 2.** Plugin install was a Phase 1 admin-UI step; runtime ability for plugin install is not exposed by default.
- **Edit `wp-config.php`, theme files, or other server files.** No file-system access on the WP host.
- **Manage WP Multisite networks.** mcp-adapter targets a single site. Network-level admin requires separate tooling.
- **Connect to multiple WP sites at once on a single connection.** Each site needs its own `mcpServers.wordpress-<n>` block.
- **Bypass security plugins** (Wordfence rules, iThemes Security restrictions). If those plugins block REST API or Application Passwords, this connector cannot work until the user adjusts the plugin's settings.
- **Use OAuth or JWT auth modes.** This skill only configures the Application Password mode. OAuth + JWT are documented in `mcp-wordpress-remote` and possible advanced extensions.

---

## REST-Direct Fallback (only when Playwright is unavailable)

Use this section ONLY when:

- `mcp__plugin_playwright_playwright__*` tools are not in the available surface AND
- The plugin install fix in Step 3 has been attempted twice with restart in between AND
- The user explicitly confirms they cannot install Playwright MCP for any reason.

The fallback path requires the user to do steps Claude would normally automate. Tell the user upfront:

> *"Quick heads up. The smooth automated setup needs a browser-driving tool I can't get installed on your computer right now. We can still set this up, but I'll need to walk you through three short manual steps in your WordPress admin. Total: about three minutes. Want to proceed, or stop here?"*

If they say proceed:

1. **Plugin install.** *"Open your WP admin in any browser. Go to Plugins → Add New, search for 'mcp-adapter', and click Install Now then Activate on the result by WordPress.org or Automattic. Tell me when you see the green 'Plugin activated' message."* Wait for confirmation.

2. **Application Password.** *"Now go to Users → Profile in the same admin. Scroll to the bottom, you'll see an 'Application Passwords' section. In the name field, type 'Claude Assistant' and click 'Add New Application Password'. WordPress will show you a long password broken into groups of 4 characters. Copy that whole password (including spaces) and paste it back to me."* Wait for the paste. Strip spaces silently. Capture as `WP_API_PASSWORD`.

3. **Username.** *"Last thing. On that same Profile page, find your Username (it's read-only, near the top). Tell me what it is."* Capture as `WP_API_USERNAME`.

Then proceed to Step 7 normally.

**After verify succeeds, AUTOMATICALLY drive a credential rotation** — the manual path put the token in chat history, the harness's session log, possibly the user's terminal scrollback, and possibly an upstream API request log. The token must be killed and re-issued ASAP.

Tell the user: *"Last thing. Because we did this manually, that password is sitting in our chat history. I'm going to retire it now and mint a fresh one. This takes about 60 seconds and means there's no leftover risk. Open your WordPress admin one more time and let me know when you're back at Users, then Profile."*

When they confirm:
1. Drive Users → Profile → Application Passwords → find the row named `Claude Assistant` → click `Revoke`. Confirm the revocation in the dismissal dialog.
2. Immediately mint a new one: name `Claude Assistant`, click Add New Application Password.
3. Read the new spaced password from the DOM (same `.application-password-display` selector as Step 6).
4. Update `~/.claude.json` `mcpServers.wordpress.env.WP_API_PASSWORD` with the new value (preserve everything else).
5. Tell the user to close + reopen Claude Code one more time, then re-run the verify (Step 7).

End state: the chat-leaked password is dead within 60 seconds of being created. Any session log copy is now stale.

The fallback path is a security regression vs Phase 1's autonomous flow. Use it only when there is no other option, and always with the auto-rotation tail.

---

## Related Skills

- **first-run-setup**: The source pattern for cross-platform shell detection.
- **telegram-connector**: Sibling autonomous-Playwright connector. Reference for the rules + cleanup branches + Playwright-MCP-driven flow.
- **playwright-skill**: The Playwright MCP browser is the engine that drives this skill's WP admin work.
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting plugin conflicts, security-plugin restrictions, REST API errors, or Application Password edge cases.
- **xero-connector**: Sibling Phase-2-tool-table connector. Same `~/.claude.json` + restart pattern, different platform, different (older) install pattern.
