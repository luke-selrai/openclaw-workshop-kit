---
name: wordpress-connector
description: "Connect WordPress to Claude by switching on the built-in WordPress.com connector, or by installing its official MCP server for a self-hosted site. Use when the user asks to set up or connect WordPress or their WP site, or wants WordPress or blog work (reading, drafting and publishing posts, pages, comments) and WordPress isn't connected yet. WordPress.com sites then run through the `mcp__claude_ai_WordPress_com__*` tools; self-hosted sites run through `mcp__wordpress__*`."
allowed-tools: Bash, Read, Write, Edit, mcp__wordpress__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, mcp__claude_ai_WordPress_com__*
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
    - skill: telegram-connector
      reason: Same Playwright-MCP-driven autonomous-install pattern. Reference for the rules + cleanup branches.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives the user's WordPress admin
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting plugin install, Application Password, or REST endpoint failures
---

# WordPress Connector

## Overview

This skill connects a user's WordPress site to Claude so the assistant can read, draft, and publish posts on their behalf. **There are two kinds of WordPress site and they take completely different routes, so the first thing to establish is which kind this user has.**

**WordPress.com-hosted sites → the built-in connector (the default route).** Automattic publishes a connector in Claude's own connector directory (`https://claude.com/connectors/wordpress-com`, display name **WordPress.com**, made by Automattic, read & write). It carries 60+ abilities - content creation and management, publishing and editing posts and pages, performance tracking, site organisation, accessibility auditing. It is one click, no plugin install, no Application Password. It works **only** for sites hosted on WordPress.com.

**Self-hosted WordPress.org sites → the kit's own route.** Most business sites are this kind: WordPress running on the user's own hosting (WP Engine, Kinsta, GoDaddy, Bluehost, SiteGround, a VPS). The built-in connector does not reach them at all. For these, the kit installs the **official Automattic + WordPress.org MCP pair**:

- **WordPress side:** [`WordPress/mcp-adapter`](https://github.com/WordPress/mcp-adapter), the free official bridge, installed from its GitHub Releases ZIP using Step 5A, not a plugin-directory search. Install the separate `Enable Abilities for MCP` companion from the plugin directory using Step 5B to expose content abilities. WordPress 7.1's core Abilities API does not replace that companion.
- **Claude side:** [`@automattic/mcp-wordpress-remote`](https://github.com/Automattic/mcp-wordpress-remote) - the pinned npm bridge launched by a registered wrapper that reads a separate private credential file and talks to the user's WP site over the REST API using their Application Password.

Both routes can live on one machine at once - a user with a WordPress.com blog and a self-hosted client site can have both. Never tear one down to set the other up.

**On the kit's own route, the user does exactly ONE thing across the entire setup. Everything else is autonomous.**

1. Log in to their WordPress admin in the Playwright browser when it opens (Step 4). One-time, their credentials, on screen they already know.

That's the complete list. **The user does NOT search the plugin directory, does NOT click Install, does NOT generate the Application Password, does NOT copy or paste it.** After Step 4 the Playwright window is logged into the user's WP admin AS the user. Claude drives every WP admin action from there: uploading and activating the official GitHub Releases ZIP, installing and activating `Enable Abilities for MCP` from the directory, then using one protected filename-backed evaluation to name, create and capture the application password and registering a wrapper through the supported Claude command. The password never enters tool returns or global MCP configuration.

If you find yourself about to ask the user to "open your WP admin and click Plugins", "copy the Application Password back to me", or "paste this into your config", stop. That's the wrong path. Drive WP admin in the Playwright window instead.

**Which phase to run.** Always start at Phase 0, then *Route by need*. Phase 1 switches on the built-in WordPress.com connector. PHASE 1 - Install & Connect is the kit's own route for self-hosted sites. PHASE 2 is day-to-day operation - using whichever connector is wired.

---

## Golden rule - Claude drives WordPress admin for EVERY WordPress action

**On the kit's own route, the default path for every WP-admin-side action is the Playwright MCP browser.** Once Step 4 logs the Playwright window into the user's WP admin (the user enters their username + password), that window IS the user's WP admin client for the rest of the flow. Claude uses it for:

- Step 5A: download the official `mcp-adapter` GitHub Releases ZIP → Plugins → Upload Plugin → Install → Activate. Step 5B: search only `Enable Abilities for MCP` in the plugin directory → Install → Activate.
- Step 6: private output probe → Users → Profile → one filename-backed evaluation to create/capture the new password → validate and save the exact private artifact.

Both happen in the same Playwright window, driven by `mcp__plugin_playwright_playwright__browser_*` tools. Same WordPress account, same admin session - the WP REST API will accept the resulting Application Password because it was issued to that user.

**Do NOT, at any point in the kit's own route, ask the user to:**

- Open their WordPress admin themselves (after the login in Step 4)
- Search for, install, or activate any plugin manually
- Navigate to their user profile
- Click "Add New Application Password" themselves
- Copy the Application Password back to you
- Paste any token, URL, or username into chat

If you find yourself about to type any of those, stop. The Playwright window can do all of them.

The **Capture capability fallback** section at the bottom of this file is the contingency for when the Playwright MCP browser cannot be used at all (extension not installed, non-recoverable launch failure after two attempts). It is NOT the path to use because manual instructions feel simpler - they don't, they make the user do extra work.

**Browser routing for the built-in connector.** Follow Phase 1's Desktop in-app-first route and account-matched browser handoff. Use available UI tools; ask the user only for input the harness cannot complete. The kit's separate credential-capture browser rules still apply to its own route.

---

## Autonomy rule - Claude does the work, the user does not paste commands

WordPress's REST API + Application Password design means there is **no slash-command surface** for the user to invoke even if they wanted to. Everything happens via Claude's tools:

- A uniquely named local MCP server registered via `claude mcp add`, containing only wrapper paths; private credentials stay outside global configuration
- WP admin UI clicks - driven via `mcp__plugin_playwright_playwright__browser_click` (instead of user-side instructions)
- Application Password creation and capture in one `browser_evaluate` with verified private `filename` output, never a secret-returning evaluation

Same end result, no paste required. The Application Password lands in an owned mode-600 credential file without ever appearing in chat output, on the user's clipboard, or in any tool-call return value.

The only thing the user types across the entire flow is their WordPress admin password into the WP login form (Step 4) - and that goes directly to WordPress, not to Claude. Claude never sees it.

If you find yourself about to type "paste this into the chat", stop. Use the protected capture helper or report the precise missing capture capability; a secret paste is not an exception path.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise with `curl https://<site>/wp-admin/...`, do not edit the user's `wp-config.php`, do not invent SQL. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## Communication rules

The user is a non-technical business owner. Every message during either connect route follows these rules:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, terminal, MCP, REST API, env var, plugin slug, JSON, contenteditable, selector, OAuth, JWT. The phrase "the browser window I'm using" is preferred over "Playwright". For other technical things, name them plainly: "a small connection helper", "a one-time password just for me", "your WordPress admin", "the plugin we need".
- **Tell them what is about to happen.** Before any action: "I'm going to open your WordPress admin in a browser window now. This takes a few seconds."
- **React warmly.** Good: "That worked. Your WordPress is now connected." Bad: "200 OK. Application Password persisted to mcpServers.wordpress.env."
- **Never show raw error messages.** Translate into plain English, then diagnose silently: "No problem, let me try a different way."
- **Short messages.** Maximum 8 lines per message.
- **Never show commands or paths** to the user. Claude runs them; the user does not see them. (No "type X in your terminal" - there is no user-side terminal step in this skill.)
- **Security: never echo the Application Password.** Once saved in the private connector credential file, the token's job is done. Do not re-read that file, do not echo it in any later message, do not include it in any tool-call return value the user can see. Same rule for the user's WP login password - Claude never sees it (it goes to the WP login form), and Claude must never ask for it.
- **No em dashes inside italicised user-facing strings or `> "..."` blockquotes.** Use commas or full stops in user-facing speech. Em dashes are fine in section headings and Claude-facing prose.

---

## Phase 0 - Is WordPress already connected?

Identify the calling surface first. Desktop's visible account, Connectors view, and actual runtime tools are its evidence. Terminal `claude auth status` and `claude mcp list` describe the CLI account, even when run from Desktop's Bash; they do not establish Desktop identity or access. WordPress.com credentials are independent of either Claude login. Discover existing tools and perform the read below for the intended vendor account before claiming a connection. Preserve a working route.

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** In Desktop, discover this session's WordPress.com tools (including opaque-ID prefixes) and inspect the app's Connectors view. For a terminal/VS Code caller only: `claude mcp list` → look for the line `claude.ai WordPress.com` (that is the exact display name; in the tool namespace the dot becomes an underscore, `mcp__claude_ai_WordPress_com__*`).
   - Connected in the caller or tools present → skip to PHASE 2. Prove it first with one read: call any read tool in the `mcp__claude_ai_WordPress_com__*` namespace (list recent posts, or read the site's title) and check a real answer comes back.
   - Reconnect or `! Needs authentication` → reconnect in the same caller's Connectors view. In Desktop, start inside the app; for a browser route, verify its Claude account matches the caller before opening `https://claude.ai/customize/connectors`. Complete WordPress.com sign-in and repeat the actual read.
   - No usable built-in in the caller → continue to step 2; a missing CLI line alone says nothing about Desktop.
2. **The kit's own route.** Discover the current caller's WordPress server tools. For bundled private state, run `python3 scripts/connect.py check` from this skill directory; it reports only schema status and the unique server name. Never use `Read` on global configuration or credential files. A saved file or registration is not proof: discover abilities and execute a real read for the intended site. Preserve any working legacy registration; do not migrate or overwrite its credentials merely because it uses an older format. If tools or valid saved credentials exist but the read fails, preserve partial state and use Step 7's diagnosis; do not create another password automatically.
3. **Nothing found** → Route by need, then Phase 1.

**No shell?** Runtime discovery and reads still apply. Skip unavailable command/file checks; only set up a connection if no working route is found, following the existing route-by-need rules.

---

## Route by need - which kind of WordPress site is this?

**Ask this before opening anything.** The two routes are not interchangeable and the answer decides everything that follows:

> *"Quick question first. Is your site hosted on WordPress.com, or is it WordPress running on your own hosting somewhere else (WP Engine, Kinsta, GoDaddy, Bluehost, SiteGround, or a host your developer set up)? If you're not sure, tell me the address of the site and I'll work it out."*

If they aren't sure, check the site yourself: a WordPress.com-hosted site's admin lives at `wordpress.com/home/<site>` and its login is `wordpress.com/log-in`; a self-hosted site's admin lives at `<their-domain>/wp-admin`. A `*.wordpress.com` address is always the WordPress.com kind. A custom domain can be either, so if the check is ambiguous, ask where they log in.

| What the user has, or wants | Route |
|---|---|
| Site hosted on WordPress.com (any plan) | Built-in connector (Phase 1) - 60+ abilities, one click, no plugin |
| WordPress.com: publish or edit a post or page, track performance, organise the site, audit accessibility | Built-in connector (Phase 1) |
| Self-hosted WordPress.org on the user's own hosting - **most business sites** | The kit's own route (PHASE 1 - Install & Connect) |
| Site whose admin is at `<their-domain>/wp-admin` and who installs their own plugins | The kit's own route |
| Both - a WordPress.com blog *and* a self-hosted client site | Both, one at a time. They coexist. |

Route on the site, not on the task: no amount of retrying makes the built-in connector reach a self-hosted site, and the kit's own route needs a plugin install that WordPress.com-hosted sites do not allow on every plan. If the user only has a WordPress.com site, stop after Phase 1 - do not walk them through the plugin install they don't need. Say in one line what you are not setting up and why, so they can ask for it later.

---

## Phase 1 - Switch on the built-in WordPress.com connector (the default route)

Run this when the user's site is hosted on WordPress.com. It is a one-time, once-per-account job. Claude handles the available setup steps; the user supplies any sign-in input that requires them. This skill handles no Application Password and no plugin install on this route.

**Step 1 - Check this session can see built-in connectors.** In Desktop, use its visible signed-in account and Connectors view, then continue inside that app. The following auth/settings checks apply only to a terminal/VS Code caller, not Desktop: `claude auth status` must show `"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has `disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in connectors will not appear here: tell the user in one line that this copy of Claude is signed in a different way. For a WordPress.com site there is no kit fallback - the kit's own route needs a plugin install, which WordPress.com only permits on Business and above - so say so plainly and stop.

**Step 2 - Open the connector page for them.**

Say: *"I'll open WordPress.com's connection page and handle the setup. I'll let you know if it needs you to sign in."*

**Desktop first:** use the app's **+ → Connectors → Browse connectors → WordPress.com → Connect** (or the equivalent visible Customize/Connectors menu). Keep the exact app-created browser handoff URL, including its parameters. Open it in a browser profile whose Claude account you have confirmed matches Desktop, using an isolated profile when needed. If that profile is signed out or belongs to another account, complete sign-in to the matching Claude account in an isolated profile before continuing. Confirm the intended WordPress.com account before approval. Do not replace it with a directory link from another Claude account.

**Terminal/VS Code or browser fallback:** open `https://claude.com/connectors/wordpress-com` (or `https://claude.ai/directory/wordpress-com`) in a browser whose Claude account matches the caller. Use `open` (Mac), `xdg-open` (Linux), or `start` (Windows) only after confirming that browser's account. If the page fails, use `https://claude.ai/customize/connectors` → **Browse** → search "WordPress.com" → **Connect** in that same account.

Drive navigation and approval with available UI tools. If a step requires user input or the harness has no suitable UI tool, give only the exact short next step; do not describe every click as inherently human-only.

**Step 3 - Wait.** Complete the visible flow with available tools; wait for any sign-in input that requires the user. Never ask for a password, a code, or a screenshot of the sign-in.

**Step 4 - Verify.**

Check WordPress.com in Desktop's own Connectors view, or `claude mcp list` for a terminal/VS Code caller. Connected is registration evidence only; proceed to the real read in Step 5. Reconnect uses the same account's Connectors view. A missing CLI line says nothing about Desktop. If Desktop still lacks a connection completed through the browser directory, verify **Connected** in that browser's matching Claude account. Once that account check passes, rediscover Desktop's tools and use Step 5's one-time Desktop refresh if needed; do not repeat **Connect** to repair a stale app view. Return to Step 2 only when neither the caller's view nor the account-matched browser confirms a completed connection.

**Step 5 - Prove it.** Call one real read through the connector - any read tool in the `mcp__claude_ai_WordPress_com__*` namespace (list recent posts, or read the site title). Only a real answer counts. A tool error here is not "connected". In the desktop app's Code tab the same tools arrive as `mcp__<id>__<tool>` under an opaque id instead of `mcp__claude_ai_<Name>__`, so look for the tool names, never the prefix, and never hard-code the id (it changes on reconnect). If tools are missing, first rediscover deferred tools and confirm the same caller account is connected; only then consider a stale session: a terminal or VS Code session loads its claude.ai connectors once, at start, so ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows: close the window and quit from the tray; VS Code: **Developer: Reload Window**), then run Phase 0 again. In the desktop app it depends on how the Connect was made (checked live 2026-09-04): through the app's own **+ → Connectors → Browse connectors** route the tools appear in the running session with no restart; through the directory page in a browser the app does not notice at all and a new session does not help, so ask them to fully quit and reopen the desktop app, then start a new session.

**Step 6 - Hand off.** Two lines: it's connected, and three things they can ask for now - *"show me my recent posts"*, *"draft a post about [topic]"*, *"how is my site performing?"*.

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their Claude admin has to switch WordPress.com on for the organisation first. Say so plainly and stop; do not fall back to the kit's route just to get past an admin gate.

**Local entry precedence (terminal/VS Code only).** If a server registered locally with `claude mcp add` points at the same URL, it takes precedence and hides the built-in one. If it works, leave it and say so. If it is broken, prefer the built-in and remove the local entry only with the user's OK. Desktop may expose local and built-in tools simultaneously; discover the actual runtime and keep each result attached to its connection.

**Multiple WordPress.com sites.** The connector follows the WordPress.com account the user signs in with, so every site on that account comes along. Confirm which site you are acting on before any publish or delete.

---

## PHASE 1 - Install & Connect

> **When to run this.** The kit's own route, for **self-hosted WordPress.org sites only** - the answer to *Route by need* above was "my own hosting". Do not run it for a WordPress.com-hosted site; use Phase 1 instead. Both routes can coexist on one machine; setting this one up does not switch a built-in WordPress.com connection off.

**Run Steps 1 through 7 in order, all in this one Claude Code session.** Step 4 opens the user's WP admin in the Playwright MCP browser and waits for the user's login. Step 5 drives the plugin install autonomously inside that browser. Step 6 drives the Application Password generation autonomously inside that browser. Step 7 verifies. The Capture capability fallback section at the bottom is only for when Step 4 fails twice in a row - do not start there.

**Resume check.** Preserve existing private files, registered entries and WordPress passwords. Use the helper's structural `check` and actual caller's tools; do not dump configuration or ask whether to wipe it. Valid private capture resumes at Step 7. An incomplete capture follows the private reference's exact artifact recovery, never another Add New click. Authentication failure requires diagnosis, not automatic rotation or deletion.
---

### Step 1 - Prerequisite check

Use the site, admin access and host already established in the conversation. Ask only for missing information, one question at a time; do not repeat known prerequisites.

**Question 1 (account):**

> *"Before we begin, three quick checks. First, do you have **admin access** to your WordPress site? (You'd be the one who can install plugins and add users. If someone else manages your site, they'd need to do this part with you, or we'd need their password.)"*

- Yes → Question 2.
- No / not sure → *"That's the first thing to sort. This setup needs a WordPress admin login because we'll install a plugin. Is there someone you can ask, or do you want to pause here and come back?"* If they cannot get an admin login, stop the skill and tell them to come back when they have one.

**Question 2 (host):**

> *"Second, what hosts your WordPress site? Common ones are WP Engine, Kinsta, GoDaddy, Bluehost, SiteGround, or just 'I'm not sure'."*

- Any managed/self-hosted setup → Question 3.
- WordPress.com (any plan) → this is the wrong route. Go back to **Phase 1** and switch on the built-in WordPress.com connector instead: it needs no plugin at all, which is what makes it the only route that works on a WordPress.com Free plan (Free cannot install custom plugins, so the plugin install below would fail). Say: *"Good news, yours is the easy kind. There's a ready-made WordPress.com connection I can switch on instead of installing anything."*
- Not sure → *"No worries, we'll find out when I open your admin. If your host blocks plugin installs we'll see it then and stop cleanly."* Continue to Question 3.

**Question 3 (URL):**

> *"Last one. What's the URL of your WordPress site? Something like `https://example.com` or `https://blog.example.com`. Just the address, not the wp-admin path."*

Capture the URL. Validate it: require HTTPS, allowing HTTP only for explicitly local `localhost`, `127.0.0.1` or `[::1]` fixtures; must not include `/wp-admin` or trailing slashes that confuse later URL building. Normalise: strip trailing slashes, strip `/wp-admin`, strip `/wp-login.php`. Store as `WP_BASE_URL`.

If the user gives a URL that fails to resolve in a quick `curl --head -m 10 <url>`, tell them: *"I can't reach that address. Can you double-check the URL?"* Wait for retry. If it still fails after two tries, stop and tell them to verify the site is online.

---

### Step 2 - Detect OS, shell, and Node version

Silently run, in order:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
node --version     # required: 18.0.0 or higher (the @automattic/mcp-wordpress-remote bridge uses fetch which is GA in Node 18+; the README recommends Node 22+)
```

On Windows (if the above fails), the user is almost certainly in PowerShell or Command Prompt. Treat the same way `whatsapp-connector` and `telegram-connector` do - Claude continues to drive everything via Bash/Write; the OS detection is for path-resolving `~/.claude.json` (`%USERPROFILE%\.claude.json` on Windows; `$HOME/.claude.json` on Mac/Linux).

**Node version handling:**

- **Node >= 18** → continue to Step 3.
- **Node < 18** (or `node --version` reports `command not found`) → tell the user: *"You'll need a slightly newer version of Node.js for this connector. Want me to install it for you, or you can install it yourself first?"* If yes, drive `nvm install --lts` (Mac/Linux with nvm available) or guide the user to https://nodejs.org for a fresh installer. After install, ask the user to restart their Claude Code session and tell you ready, then re-verify.

---

### Step 3 - Confirm Playwright MCP is available

Silently check whether `mcp__playwright__browser_navigate` (or `mcp__plugin_playwright_playwright__browser_navigate` - Claude Code may expose either name depending on whether the user installed via `claude mcp add` or via a marketplace plugin) is in the available tool surface. If yes → Step 4.

If the Playwright MCP server is not registered, install it autonomously via Bash. Mirror the install logic from `docs/start/setup.md` (its Step 6 Playwright command is canonical):

```bash
# Primary path - registers an npx-launched Playwright MCP server scoped to this user
claude mcp add playwright npx @playwright/mcp@latest --scope user
```

If that command errors with `Cannot find module @playwright/mcp` or similar npm-resolution failure, fall back to the global-install path:

```bash
npm install -g @playwright/mcp
claude mcp add playwright @playwright/mcp --scope user
```

Tell the user: *"Almost ready. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them, then re-verify the tool surface.

If the server still doesn't show up after restart, use **Capture capability fallback** to report the missing browser/capture capability and preserve progress.

---

### Step 4 - Open the user's WordPress admin in the Playwright MCP browser

Tell the user: *"I'm going to open your WordPress admin in a browser window now. You'll need to log in once. After that I'll handle everything."*

**Browser isolation.** Use the task's isolated browser/profile and preserve the everyday browser, native keyboard and clipboard. On a launch lock failure, inspect the exact task-owned browser process/profile and use its supported close/relaunch once. Never broadly kill browser processes or remove singleton locks from a normal browser profile. If isolation cannot be established, stop at that specific capability gap.

**Navigate.** Use `mcp__plugin_playwright_playwright__browser_navigate` to `<WP_BASE_URL>/wp-admin`.

**Wait for login form.** Use `mcp__plugin_playwright_playwright__browser_snapshot` to confirm the page rendered. The login screen has two visible fields: username/email and password.

Tell the user: *"Your WordPress login screen is open. Please log in with your admin username and password. I'll wait, just tell me 'done' when you're in."*

**Wait for login.** After the user confirms, take a fresh snapshot. The WP admin dashboard should be visible (left sidebar with "Dashboard", "Posts", "Plugins", "Users", etc.). If still on the login screen after 30 seconds, ask the user if they hit any issues and re-take the snapshot.

If login fails repeatedly (more than two retries), or the user reports they cannot get past their host's two-factor / login-protect layer, fall back to **Capture capability fallback**.

**Detect WP version.** Footer parsing is fragile - many admin themes (WP Engine, Kinsta white-labels, Astra Pro, Divi) override or hide the `Version 6.X.Y` footer. Use the RSS generator tag instead, which WordPress emits unconditionally:

```bash
# From outside the Playwright session - runs in parallel during admin login
curl -s "<WP_BASE_URL>/feed/" | grep -oE '<generator>[^<]+</generator>' | grep -oE 'WordPress [0-9.]+'
```

Parse the version. The plugin requires **WordPress 6.8 or higher** (`Requires at least: 6.8` in the plugin header), with **6.9 strongly recommended** because 6.9 includes the WordPress Abilities API in core. On 6.8, the user would need a separate `WordPress/abilities-api` companion plugin (whose own repository was archived in February 2026), so the workshop's clean path is 6.9+.

- **Version >= 6.9** → continue.
- **Version 6.8** → tell the user: *"Your WordPress is on 6.8, which technically works with this plugin but needs an extra helper that's harder to install. Updating to 6.9 or later (free, one click in the Updates page) is the smooth path. Want me to handle the update now, or stop here so you can do it on your own time?"* If yes, drive Dashboard → Updates → Update WordPress autonomously, wait for completion, re-run the version check. If no, stop.
- **Version < 6.8** → tell the user: *"Your WordPress version is too old for this connector. The good news is updating WordPress is one click in the Updates page, and it's free. Want me to do it now? If yes, I'll handle it. Otherwise we can stop here and pick up after you've updated."* Same handling as the 6.8 branch.

If the RSS generator tag is missing (some hosts strip it), fall back to driving the dashboard footer in the Playwright window. If both fail, push on to Step 5 - the plugin's own activation will reject the install with a clear "requires WordPress 6.8" error if the version is below floor, and that error becomes the user-facing diagnostic.

---

### Step 5 - Install both required plugins autonomously

The default `mcp-adapter` install registers only three meta-abilities (`discover_abilities`, `get_ability_info`, `execute_ability`). To get a useful day-to-day surface (posts, pages, users, comments), the user needs the companion `Enable Abilities for MCP` plugin alongside `mcp-adapter`. This step installs **both**, autonomously.

**Important context for Claude:** `mcp-adapter` is the official WordPress.org / Automattic plugin but is **NOT in the wp.org plugin directory** as of v0.5.0. It ships via GitHub Releases. The wp.org plugin search will return zero results for it, and other "mcp"-named third-party plugins in the search results are unrelated. Do NOT install any of them. Use the GitHub Releases ZIP upload path documented below.

The companion `Enable Abilities for MCP` IS in the wp.org plugin directory (slug: `enable-abilities-for-mcp`, by fabiomontenegro1987), so it installs via the standard search path.

#### Step 5A - Install `mcp-adapter` from the GitHub Release ZIP

Tell the user: *"I'm installing the WordPress side of the connector now. This takes about 30 seconds."*

**Fetch the latest release ZIP** to a temp path. Use Bash (not the Playwright window):

```bash
curl -L -o /tmp/mcp-adapter.zip "https://github.com/WordPress/mcp-adapter/releases/latest/download/mcp-adapter.zip"
```

On Windows, replace `/tmp/` with `$env:TEMP\` (PowerShell) or `%TEMP%\` (cmd) and use `curl.exe -L -o ...` (curl ships with Windows 10+).

If the curl returns an HTTP error or the file size is < 100KB, the release URL has changed or the user is offline to github.com. Tell the user: *"I couldn't reach the WordPress plugin from GitHub. Either your computer can't reach github.com right now, or the plugin moved. Want to retry, or stop here?"* On retry, fetch the latest release metadata first via `gh api repos/WordPress/mcp-adapter/releases/latest --jq '.assets[0].browser_download_url'` and re-curl from the parsed URL. After two failures, stop.

**Drive the upload-install in the Playwright window:**

1. Navigate to `<WP_BASE_URL>/wp-admin/plugin-install.php?tab=upload`. (Don't try to navigate by clicking - the upload tab anchor is unreliable across WP admin themes; URL-navigate directly.)
2. Wait for the `<input type="file" name="pluginzip">` field to be present (`browser_snapshot`).
3. Use `mcp__playwright__browser_file_upload` (or `mcp__plugin_playwright_playwright__browser_file_upload`) to attach the local `/tmp/mcp-adapter.zip` to that input.
4. Click the `Install Now` button (`#install-plugin-submit` is the stable selector).
5. Wait for the success page that contains a link `Activate Plugin` (or button `.button.button-primary` with text "Activate Plugin"). Snapshot to confirm.
6. Click `Activate Plugin`.
7. Wait for the redirect to `plugins.php?activate=true`. Snapshot to confirm `MCP Adapter` shows up in the Active plugins list with no error notice underneath it.

**If the upload fails with "destination folder already exists":** the plugin was previously installed. Navigate to `<WP_BASE_URL>/wp-admin/plugins.php`, locate the `MCP Adapter` row, click `Activate` if Inactive. If already Active, proceed to 5B.

**If the upload fails with `requires WordPress X.Y` activation error:** the version check from Step 4 missed (RSS generator was stripped). Tell the user the plugin needs WordPress 6.8 or higher and offer to drive the WP update flow. Same handling as the Step 4 version branches.

**If the upload fails with a permission / `chmod` / `umask` error:** the host has restricted plugin uploads. WP Engine, Kinsta, and similar managed hosts sometimes do this during cache deploys or plugin-upload restrictions. Tell the user: *"Your host returned a permission error during the upload. This sometimes happens on managed hosts during cache deploys or plugin-upload restrictions. Want to retry in a moment, or stop and investigate?"* On retry, wait 30 seconds and try once more. After two failures, stop.

#### Step 5B - Install `Enable Abilities for MCP` from the wp.org directory

This plugin IS in the wp.org plugin directory and installs via the standard search-and-install flow.

1. Navigate to `<WP_BASE_URL>/wp-admin/plugin-install.php?s=enable-abilities-for-mcp&tab=search&type=term`. (Pass the search term as a URL parameter rather than typing into the search input - the input has a debounced XHR auto-search that's timing-sensitive.)
2. Wait for `.plugin-card-enable-abilities-for-mcp` to be present in the DOM (this is the result row's stable class - the slug becomes part of the CSS class name).
3. Click the `Install Now` button inside that row (selector: `.plugin-card-enable-abilities-for-mcp .install-now`).
4. Wait for the same button to change to `Activate` (its class flips to `.activate-now` and text updates).
5. Click `Activate`.
6. Wait for the redirect / success notice.

**If the result row is not present after 10 seconds:** the wp.org search may have temporary issues, or the user's host blocks the wp.org search XHR (rare). Fall back to the same GitHub-Releases-style approach: download from `https://downloads.wordpress.org/plugin/enable-abilities-for-mcp.latest-stable.zip` to `/tmp/enable-abilities-for-mcp.zip` and use the upload-install flow from 5A.

**If the activate fails with an "incompatible with WP version" error:** the user is on WP < 6.9 and `Enable Abilities for MCP` requires 6.9. Tell them: *"This plugin needs WordPress 6.9 or later. Want me to drive a WordPress update first, or stop?"* On yes, drive Dashboard → Updates → Update WordPress, then retry the activation.

#### Step 5C - Verify both plugins are active

Take a snapshot of `<WP_BASE_URL>/wp-admin/plugins.php`. Confirm both `MCP Adapter` and `Enable Abilities for MCP` show in the Active plugins list with no fatal-error notice.

**Verify the MCP route is reachable.** From Bash (not the Playwright window - we want to confirm external HTTP reach):

```bash
curl -s -o /dev/null -w "%{http_code}\n" "<WP_BASE_URL>/wp-json/mcp/mcp-adapter-default-server"
```

Expected response: HTTP `401` (Unauthorized - the route exists, just needs Application Password auth) or `405` (Method Not Allowed for GET - the route is POST-only). Either confirms the route is registered. **HTTP `404`** = route not registered → drive `Settings → Permalinks → Save Changes` in the Playwright window to flush rewrite rules, then retry the curl. If still 404, the install is incomplete; stop and tell the user.

If the user's host has persistent object cache (WP Engine, Kinsta, sites with W3 Total Cache or LiteSpeed Cache + object-cache addons), the rewrite-rules cache may stay stale even after a permalinks flush. Drive `Tools → Site Health → Cache` in the Playwright window. If a "Object Cache" notice is present, click the "Flush" button. Retry the route check.

---

### Step 6 - Generate and capture the Application Password privately

Follow [references/private-setup.md](references/private-setup.md) before clicking Add New. It probes the optional `browser_evaluate(filename)` capability using public data, protects the actual output directory, pre-creates exact mode-600 destinations and verifies the reported artifact path. Unsupported private output is a capture capability gate; do not substitute a credential-returning tool call, snapshot, clipboard or chat paste.

Navigate to the intended account's own `<WP_BASE_URL>/wp-admin/profile.php`. Confirm Application Passwords are available. If absent, inspect the actual reason: WordPress requires HTTPS except explicitly local development, and security plugins may disable the feature. Preserve those settings unless the user has authorized the specific change; never enable a bypass on a public HTTP site.

Use the generated async function in one filename-backed evaluation to name and create the new application password, read `#new-application-password-value.value` and `#user_login.value`, and remove the notice before any automatic post-operation snapshot. Do not issue a separate Add New click: that click's returned snapshot could contain the password. Current WordPress's `.application-password-display.textContent` contains label/button text and is not the credential value.

Accept only the exact tracked private output using the helper. It validates the intended profile URL and schema, saves private credentials without printing them and removes only the accepted capture file. Clear the temporary tab capture state after acceptance. An uncertain creation or failed file save is preserved for recovery; never generate another password or revoke an unrelated one to compensate.

### Step 7 - Register safely and prove the actual connection

Continue the private reference: install pinned official `@automattic/mcp-wordpress-remote@0.4.0` into the owned runtime directory, resolve absolute Node, and run the registration helper. It calls supported `claude mcp add` with a unique server name and wrapper paths only. The wrapper loads the private credential file into the child environment with `OAUTH_ENABLED=false`; no secret enters command arguments or global MCP configuration. The helper checks that other registered entries remain intact without exposing their contents.

Do not read/write/restore `~/.claude.json` directly, create credential-bearing global backups, or ask the user to close all other Claude windows. Preserve partial registration and private files if anything fails. A same-name conflict is not permission to replace another server. Authentication failures do not trigger password regeneration.

In the actual caller, rediscover tools and use its supported reconnect/refresh control. If needed and supported, create a fresh task session while preserving unrelated work. CLI registration does not by itself prove Desktop's tool pickup. Record each caller separately.

Discover the new server's meta-tools (its name includes a unique suffix), call `discover_abilities`, inspect an available read ability with `get_ability_info`, then execute a real site-info or recent-post read. Check the intended site/account. Registration and a non-empty ability list alone do not complete verification. On success say: “Your WordPress connection is ready. I checked it by reading your site.”

For a 401, preserve the current password and confirm exact site, username and application-password status privately; do not print bridge logs or rotate automatically. For a 404, use Step 5's plugin/route check. Missing tools are caller pickup work, not another credential creation. Diagnose one bounded retry of a read; unresolved errors remain incomplete with their exact observed cause.

---

## PHASE 2 - Use Tools

**Which tools you have depends on which route connected, and they differ materially.**

- **Built-in WordPress.com connector** → the tools are `mcp__claude_ai_WordPress_com__*`. Automattic ships 60+ named abilities as ordinary tools - content creation and management, publishing and editing posts and pages, performance tracking, site organisation, accessibility auditing. There is **no** discover-then-call step: the tools are the surface, so read the tool list rather than calling a discovery meta-tool.
- **The kit's own route (self-hosted)** → the tools are `mcp__wordpress__*`, and there are only three of them. They are meta-tools; the real surface is discovered at runtime. That two-layer shape is described below and applies **only** to this route.

Everything below this line is the kit's own route. The confirm-before-publishing, drafts-by-default, user-mutation and settings guardrails in *Behaviour Guidelines* apply to **both** routes.

### The tool surface is two-layer (and one of them is dynamic) - the kit's own route

**Layer 1 - fixed meta-tools.** `mcp-adapter`'s default install exposes exactly **three** MCP tools, regardless of which plugins are on the WP side. These are the entry points to everything else:

| Tool | Purpose | Use when |
|---|---|---|
| `mcp__wordpress__discover_abilities` | List every ability the WP site has registered | First call of a session, or whenever you suspect new plugins were installed. Returns `[{name, summary, ...}, ...]`. |
| `mcp__wordpress__get_ability_info` | Get the full input/output schema and docs for one named ability | Before invoking an unfamiliar ability. Returns the JSON schema for `arguments` so you build the call correctly. |
| `mcp__wordpress__execute_ability` | Invoke a named ability with arguments | Day-to-day work. Pass `{name: "<ability-name>", arguments: { ... }}`. Returns whatever the ability returns. |

**Layer 2 - dynamic ability registry.** `mcp-adapter` is a passthrough to the WordPress Abilities API. The set of abilities depends entirely on which abilities-aware plugins the user has installed:

- **Bare `mcp-adapter` only** → almost zero domain abilities (posts, pages, comments are not exposed).
- **`mcp-adapter` + `Enable Abilities for MCP`** (the companion installed in Step 5B) → posts, pages, users, comments, categories, tags, media abilities are registered. Exact ability names depend on the companion plugin's version. As of `Enable Abilities for MCP` v2.0.2, expect ability names roughly under the `wp/<resource>/<verb>` shape (e.g. `wp/posts/list`, `wp/posts/create`, `wp/comments/list`). **Always discover first**; do not assume names.
- **`mcp-adapter` + your custom plugin** → whatever your plugin called `wp_register_ability()` for, with `meta.mcp.public = true`.
- **Plugins like WooCommerce, Yoast SEO, ACF** can register additional abilities, but only if those plugins (or a companion) explicitly register them with the Abilities API. Most don't yet (as of late 2026). Treat their abilities as bonus, not assumed.

**Practical implication:** before the first domain action in a session, call `mcp__wordpress__discover_abilities`. Cache the response for the session. Only then call `execute_ability` with confidence about which `name` is valid. If a user asks for something whose ability isn't registered, surface that fact instead of fabricating a tool call.

### Worked example - list recent posts

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
| "Connect my WordPress" / "Install the WordPress connector" | **Run Phase 0, then Route by need** - establish WordPress.com vs self-hosted before anything else |
| "Show me my recent posts" | `discover_abilities` → find post-list → `execute_ability` |
| "Show me my drafts" | Same path with `status: draft` argument |
| "What's the latest published post?" | Same path with `status: publish`, sort by date desc, limit 1 |
| "Draft a post about [topic]" | Find post-create ability → `execute_ability` with `status: draft` - **confirm before calling** |
| "Update post [N] to add [content]" | Find post-update ability → `execute_ability` - **confirm before calling** |
| "Publish draft [N]" | Find post-update ability → `execute_ability` setting `status: publish` - **confirm before calling**, treat as a high-stakes action since the post becomes live |
| "Delete post [N]" / "Trash post [N]" | Find post-delete ability → `execute_ability` - **confirm before calling**, default to trash (recoverable) not force-delete |
| "List my pages" | Find page-list ability → `execute_ability` |
| "Show me comments on post [N]" | Find comment-list ability → `execute_ability` filtered by post ID |
| "Mark comment [N] as spam" | Find comment-update ability with status:spam → `execute_ability` - **confirm before calling** |
| "List my categories" | Find taxonomy-list ability with taxonomy:category → `execute_ability` |
| "What's my site about? / What's my site title?" | Find site-info ability → `execute_ability` |
| "What can my WordPress do?" | `discover_abilities` and present a grouped summary of available abilities |
| "Add a new user" / "Promote [user] to admin" / "Delete [user]" | Find the user-mutation ability → `execute_ability` - **HIGH-STAKES, requires explicit unambiguous user confirmation, never inferred** |

### Behaviour Guidelines (PHASE 2)

- **Always confirm before publishing or deleting.** Drafts are safe; publishing makes a post live to the world. Summarise what you're about to do (title + first paragraph + status change) and wait for the user's OK before calling the tool.
- **Drafts by default.** When asked to "write a post about X", create as `status: draft` first, surface the draft content for the user's review, and only publish on explicit second confirmation.
- **Format content cleanly.** Posts created via the API should use Gutenberg block syntax (`<!-- wp:paragraph -->...<!-- /wp:paragraph -->`) for proper rendering in the editor. Plain HTML works but loses the block-editing experience.
- **Discover-then-call discipline.** Always run `discover_abilities` once per session before the first domain call. Do not invent ability names. If a user asks for something not in the discovered set, say so; don't pretend.
- **User-mutation guardrail.** Any ability whose discovered name contains `user_create`, `user_delete`, `user_role`, `user_promote`, or any role-elevation verb is treated as ADMIN-level and requires explicit, unambiguous user confirmation (never inferable). The skill never auto-creates, auto-elevates, or auto-deletes users.
- **Settings guardrail.** Any ability whose discovered name contains `option_set`, `setting_set`, or `site_url` is similarly high-stakes (changing site URL or admin email mid-session can lock the user out). Confirm-first, no exceptions.
- **Pagination defaults.** Default to 10 items per list call. Offer to fetch more if there are additional pages.
- **Don't bulk operate without warning.** If the user says "delete all draft posts older than 6 months", count first, summarise, get confirmation, then operate one-at-a-time with a small delay so a misclick doesn't nuke everything.
- **Single site per connector.** This skill is locked to one WP site per Application Password. To connect a second self-hosted site, run **PHASE 1 - Install & Connect** again with that site's URL - it'll add a second `mcpServers.wordpress-<n>` block.
- **Never echo or log credentials.** `WP_API_URL`, `WP_API_USERNAME`, and `WP_API_PASSWORD` must never appear in any output visible to the user.

---

## Error Handling (PHASE 2)

| Error | What to say to the user | How to fix |
|---|---|---|
| `WordPress connection failed during initialization` (bridge code -32603) | "Your WordPress connection isn't working, let me check why." | Run `wp_site_info` (or any read tool) to surface the underlying cause. Common: Application Password revoked from WP admin, site moved to a new URL, user account disabled. Verify the exact cause privately. Replacement is a separately authorized repair using protected capture, never an automatic retry. |
| `401 Unauthorized` on a specific call | "Your connection key isn't being accepted, let me sort that now." | Preserve the saved password and inspect the exact site/account and password status privately. Do not regenerate automatically. |
| `403 Forbidden` on a specific call | "I don't have permission for that, let me check your role." | The user's WP role doesn't include the capability that ability requires. Tell the user which capability they're missing in plain English (e.g. "publishing posts is restricted to editors and admins"). |
| `429 Too Many Requests` | "WordPress is asking me to slow down. I'll wait a moment and try again." | Wait 10 seconds, retry once. If still 429, tell the user their host's rate limiting is tight and suggest waiting a minute. |
| `404 Not Found` for a specific tool | "I couldn't find that tool - let me see what's available." | Call `tools/list` to see what abilities are registered. The user may need to install the plugin that provides the ability they want (e.g. WooCommerce abilities require WooCommerce + an abilities-aware extension). |
| `500 Internal Server Error` | "Your WordPress site hit an error, let me see if there's more info." | Surface the response body if there's a useful message. Common: a plugin conflict on the WP side. The user may need to deactivate suspicious plugins or check their error log. Do not auto-fix. |
| MCP server not discovered (`mcp__wordpress__*` tools missing) | "The connection is saved; I'm checking whether this session has picked it up." | Use the actual caller's supported refresh/reconnect or a fresh task session, preserving unrelated windows. |

---

## Security Assessment

This skill grants Claude broad authority to read, draft, publish, modify, and delete content on the user's WordPress site through their Application Password. The risks below are catalogued so the prereq check, autonomy rule, and PHASE 2 confirmation prompts can defend against them. They describe the kit's own route, which is the route that issues an Application Password; the built-in WordPress.com connector issues none, so rows 1, 2, 8 and 10 do not apply to it. The content, comment, user and settings risks (3-7, 9) apply to any route with write access.

| # | Risk | Likelihood | Impact | Mitigation in this skill |
|---|---|---|---|---|
| 1 | **Application Password leak via its private credential file.** Token grants full role-equivalent access until revoked. | Medium | High (attacker can publish, edit, delete, manage users) | Private-file checks in Steps 6–7 (mode `600` on Mac/Linux), with no secret in global MCP configuration. Token never echoed back. Encourage user to enable filesystem encryption. Recommend rotating the password from WP admin if the file is ever shared. |
| 2 | **WordPress admin password leak via Step 4.** Mitigated structurally - the user types directly into the WP login form in the Playwright window; Claude never sees the credentials. | Low | High | The skill explicitly does not capture the login form values. `browser_evaluate` reads only the post-login dashboard state, not the password field. |
| 3 | **Unauthorised content publishing.** Anyone with shell access can call `wp_post_create` with `status: publish` to publish anything to the user's site. | Medium | High (brand damage, legal exposure for offensive content) | PHASE 2 publishing tools all require **explicit confirmation**. Drafts are the default. Keep the owned credential directory protected. |
| 4 | **Comment moderation abuse.** Token holder can spam, trash, or unapprove legitimate comments - the user may not notice. | Medium | Medium (silenced critics, hidden customer feedback) | `wp_comment_spam` and `wp_comment_trash` are confirm-first. Skill instructs Claude to summarise the comment text before destructive action. |
| 5 | **User-management abuse.** With admin role, the connector can add/remove users, change roles, and lock the legitimate admin out. | Low | Critical (account takeover) | User-modification tools are confirm-first and require explicit, unambiguous user prompts (not inferred). The skill never auto-creates or auto-elevates users. Recommend the user keep a separate admin account that does not have an Application Password issued. |
| 6 | **Plugin install authority.** mcp-adapter exposes whatever abilities are registered, including potentially plugin-install abilities if a plugin chooses to expose them. Future plugins could add destructive abilities. | Low | High | PHASE 2 calls `tools/list` before invoking unfamiliar tools. The skill warns Claude to treat `_install`, `_activate`, `_deactivate`, `_delete` abilities as confirm-first regardless of which family they belong to. |
| 7 | **Site-wide settings change.** `wp_options_set` (if registered) can change site URL, admin email, default post status - silent destabilisation. | Low | High | Settings-mutation abilities are confirm-first. The skill flags any `_options_set` or `_settings_*` call as high-risk and requires explicit user OK. |
| 8 | **Application Password not revocable silently.** Tokens appear in WP admin → Profile → Application Passwords with name + last-used time. User can revoke any time. | Low | (positive) High visibility | The skill gives the password a unique `Claude Assistant <suffix>` name so the exact created row is identifiable. Recommend the user check the list quarterly and revoke any they didn't expect. |
| 9 | **Plugin conflict silent fail.** Some security plugins (Wordfence, iThemes Security) block REST API or restrict Application Passwords by default - the connector will appear to work then 401 on every call. | Medium | Low (just confusing, not destructive) | Step 6 detects disabled Application Passwords and stops with a clear message. PHASE 2 401-handling explicitly covers the "post-install the security plugin started blocking" case. |
| 10 | **Fall-back path leaks credentials.** An unavailable private browser capture could tempt the caller to request a manual secret paste. | Low | High (in fallback only) | Fallback stops before credential creation until a protected transfer route is available; chat/clipboard transfer is not offered. |

**Recommended user-side hardening (not in this skill, but worth telling the user):**

- Enable two-factor auth on the WP admin account that owns the Application Password.
- Review WP admin → Users → Profile → Application Passwords quarterly. Revoke any that aren't `Claude Assistant`-named.
- Keep at least one separate admin account with NO Application Passwords issued, as a recovery account in case `Claude Assistant` is compromised.
- Rotate the `Claude Assistant` Application Password every 90 days. Ask Claude to do it for you ("rotate my WordPress connection key").

---

## Scope Limitations

**Built-in WordPress.com connector.** 60+ abilities over WordPress.com-hosted sites: content creation and management, publishing and editing posts and pages, performance tracking, site organisation, accessibility auditing. It **cannot** reach a self-hosted WordPress.org site at all - there is no setting, plan or workaround that changes this. It also does not install plugins or touch the site's files.

**The kit's own route** (everything below):

The WordPress connector **can** do (via `@automattic/mcp-wordpress-remote` + `WordPress/mcp-adapter`):

- Read and write posts, pages, comments, terms (categories + tags), media metadata, site options
- Create new drafts; publish on explicit confirmation
- Moderate comments (approve, spam, trash)
- Read user list; modify users with admin role
- Discover dynamically registered abilities from any abilities-aware plugin (WooCommerce, Yoast SEO, ACF, etc.)

The WordPress connector **cannot** do:

- **Modify the database directly.** mcp-adapter only exposes the Abilities API; arbitrary SQL is out of reach.
- **Install or activate plugins from PHASE 2.** Plugin install was a PHASE 1 - Install & Connect admin-UI step; runtime ability for plugin install is not exposed by default.
- **Edit `wp-config.php`, theme files, or other server files.** No file-system access on the WP host.
- **Manage WP Multisite networks.** mcp-adapter targets a single site. Network-level admin requires separate tooling.
- **Connect to multiple WP sites at once on a single connection.** Each site needs its own `mcpServers.wordpress-<n>` block.
- **Bypass security plugins** (Wordfence rules, iThemes Security restrictions). If those plugins block REST API or Application Passwords, this connector cannot work until the user adjusts the plugin's settings.
- **Use OAuth or JWT auth modes.** This skill only configures the Application Password mode. OAuth + JWT are documented in `mcp-wordpress-remote` and possible advanced extensions.

---

## Capture capability fallback

If the available browser cannot complete ordinary admin navigation, repair its supported isolated launch once and retry. If private filename output cannot be demonstrated with the public probe, preserve progress and report that exact capture capability gap. Do not ask the user to create and paste an application password, expose it in a tool response, or rotate it afterwards to justify the exposure. Resume at the failed step once a protected capture route is available; keep installed plugins and existing passwords intact.

---

## Related Skills

- **orientation**: The plain-English, non-technical narration pattern this skill's user-facing steps follow. Cross-platform command detection now lives in the setup prompt (`docs/start/setup.md`).
- **telegram-connector**: Sibling autonomous-Playwright connector. Reference for the rules + cleanup branches + Playwright-MCP-driven flow.
- **playwright-skill**: The Playwright MCP browser is the engine that drives this skill's WP admin work.
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting plugin conflicts, security-plugin restrictions, REST API errors, or Application Password edge cases.
- **xero-connector**: Sibling Phase-2-tool-table connector. Related publishing/account connector; use this skill's private wrapper and caller-specific refresh instructions.
