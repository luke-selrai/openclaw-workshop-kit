---
name: meta-business-suite-connector
description: "Connect the user's Instagram Business and Threads to Claude Code so Claude can read, publish, and manage content on their behalf via the @mikusnuz/meta-mcp server. Drives the entire setup autonomously through the Meta Developer Portal + Graph API Explorer in a Playwright MCP browser: creates the Meta Developer App, captures the App ID and App secret from the DOM, drives Graph API Explorer to mint the access token, exchanges short-lived for long-lived via curl, and writes ~/.claude.json directly. The only human moments are the user logging in to Facebook and ticking permission boxes in Meta's OAuth dialog. Phase 2 covers Instagram publishing (photos, videos, carousels, Reels, stories), media management, comments and replies, profile and account insights, hashtag search, mentions, DMs; Threads publishing (text, image, video, carousels, polls, link attachments), replies, search, profile, post insights; plus Meta platform token management. Use this skill when the user says 'connect my Instagram', 'install the Meta Business Suite connector', 'help me set up Instagram', 'connect Threads', or 'help me post to Instagram'. Does NOT cover Meta Ads (use lukeselr/meta-ads-mcp-setup for that) or Facebook Page organic posting (separate connector, not yet built)."
allowed-tools: mcp__meta__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - instagram
    - threads
    - meta
    - social-media
    - publishing
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Meta access tokens or Graph API errors
    - skill: canva-connector
      reason: Generate the image/video/Reel cover, then publish through this skill
    - skill: ad-creative
      reason: Draft the post copy and creative concept, then publish through this skill
    - skill: telegram-connector
      reason: Same Playwright-MCP-driven autonomous-install pattern. Reference for the rules + cleanup branches.
    - skill: playwright-skill
      reason: The Playwright MCP browser is how this skill drives Meta's developer portal and Graph API Explorer.
---

# Meta Business Suite Connector

## Overview

This skill lets you read and publish a user's **Instagram Business** and **Threads** content on their behalf using the **community [`@mikusnuz/meta-mcp`](https://github.com/mikusnuz/meta-mcp)** server (npm-published, MIT-licensed, MCP SDK v1.26+, Graph API v25.0). It has two phases:

- **Phase 1 - Install & Connect (autonomous).** Claude drives the entire Meta Developer Portal + Graph API Explorer flow inside a Playwright MCP browser. The user does exactly TWO things: (1) log in to Facebook in the Playwright window with the account that owns their Page, (2) tick the permission boxes in Meta's OAuth consent dialog. Everything else - creating the App, capturing the App ID and App secret from the DOM, generating the access token, exchanging short-lived for long-lived via curl, finding the linked IG Business Account ID, writing `~/.claude.json` - is autonomous. The user never copies, never pastes, never opens a tab themselves, never reads a token aloud, never types into chat anything other than confirmations.
- **Phase 2 - Use Tools.** Once the connector is configured, you call the `mcp__meta__*` native tools to read and publish. The server exposes **57 tools** across Instagram (33), Threads (18), and Meta platform token management (6). All 57 are documented in the Phase 2 tables below.

**Which phase to run** - Before any tool call, check whether the Meta MCP server is already configured. Read `~/.claude.json` (on Mac/Linux: `$HOME/.claude.json`; on Windows: `%USERPROFILE%\.claude.json`) and look for an `mcpServers.meta` entry with `INSTAGRAM_ACCESS_TOKEN` and `INSTAGRAM_USER_ID` (or, if the user only wants Threads, `THREADS_ACCESS_TOKEN` and `THREADS_USER_ID`) in its `env` block. If the relevant pair exists and is non-empty, treat the connector as configured and skip to Phase 2. Otherwise, run Phase 1.

### What this skill does NOT cover

- **Meta Ads (paid campaigns, ad sets, audiences, creatives, insights for paid spend).** Use Luke's [`lukeselr/meta-ads-mcp-setup`](https://github.com/lukeselr/meta-ads-mcp-setup) for that. The two skills can coexist - they wrap different MCP servers and use different tokens.
- **Facebook Page organic posting.** This skill is intentionally Instagram + Threads only. A separate `facebook-page-connector` is the right home for that surface and has not been built yet.
- **Personal Instagram accounts.** The Graph API only supports Business and Creator accounts. The user must convert (free, takes 30 seconds in IG settings) before this skill works. Phase 0 catches this.
- **Messenger / Facebook Page DMs.** This skill exposes Instagram DMs only.
- **Cross-posting from Instagram to Facebook.** That is a per-post toggle in the Instagram app and is not exposed via Graph API publishing endpoints.

---

## Phase 0 - Pre-flight check (BEFORE the safety gate)

Before anything else, confirm the user has the right kind of account on the right platform. These three checks save 20 minutes of dead-end troubleshooting later. Ask one at a time, wait for each answer.

**Say this verbatim (or close to it):**

> "Quick check before we start, I need to make sure your account setup will work. Three short questions:"
>
> "**1.** Is your Instagram a **Business** or **Creator** account, or a personal one? (If you're not sure, open Instagram on your phone, go to your profile, tap Settings, and look for 'Account type'. Personal accounts won't work, but switching is free and takes about 30 seconds.)"

Wait for the answer.

- **User says Business or Creator** → proceed to question 2.
- **User says Personal** → tell them: *"All good. Open Instagram on your phone, go to Settings, then 'Account type and tools', and tap 'Switch to professional account'. Pick Business or Creator. Tell me when you're done."* Wait for confirmation, then go to question 2.
- **User says they don't have Instagram at all** → tell them: *"No worries, this skill needs an Instagram Business account to work. If you'd like to set one up first, that's a separate task. Otherwise we can skip Instagram and just connect Threads, if you have a Threads account. Want to do that?"* Branch to Threads-only setup if yes; stop if no.

> "**2.** Is your Instagram Business account **linked to a Facebook Page**? (Meta requires this. It's a one-time link in Instagram settings. Most Business accounts already have it.)"

Wait for the answer.

- **User says yes** → proceed to question 2b.
- **User says no or doesn't know** → tell them: *"That's the next step then. On your phone, open Instagram, tap your profile, go to Settings, find 'Linked accounts' or 'Account Center', and link your Facebook Page. If you don't have a Facebook Page, you'll need to create one. It can be a simple one and you don't need to use it. Tell me when it's linked."* Wait for confirmation, then go to question 2b.

> "**2b.** When you switched your Instagram to Business and linked it to a Page, did you finish the link from the Facebook side too? On a desktop browser, open your Facebook Page, go to **Settings**, then find **Linked Accounts** or **Instagram**, and confirm your Instagram account is showing as connected there. (Some accounts get the Instagram-side toggle but never the Facebook-side confirmation, and Meta's API treats them as unlinked.)"

Wait for the answer.

- **User confirms** → proceed to question 3.
- **User says they don't see it linked on the Facebook side** → walk them through the Page Settings → Linked Accounts → Instagram → Connect flow. If they cannot complete the link (e.g., Instagram-side ownership mismatch), stop here and tell them this needs to be sorted in Meta Business Suite before the connector can work.

> "**3.** Will you also want to post to **Threads**? (Threads is separate from Instagram for tokens, but I can set both up in one go if you want.)"

Wait for the answer. Remember it for Step 5 of Phase 1 (the Threads use-case selection happens at app-creation time).

Only proceed past Phase 0 when the user has a Business or Creator IG account linked to a Facebook Page (or has confirmed Threads-only setup).

---

## ⚠️ Safety gate - run this BEFORE Phase 1 Step 1

Two real constraints the user must acknowledge before you touch anything. These are non-negotiable and need to be raised in plain English, upfront, with explicit confirmation.

**Say this verbatim (or very close to it) and wait for the user's answer:**

> "Two more quick things you need to know about connecting Instagram to me:"
>
> "**1. Token expiry.** The connection key Meta gives me lasts about **60 days**. After that you'll need to refresh it. I can do the refresh for you in one command when the time comes, but I can't do it silently behind your back, so it's worth knowing."
>
> "**2. What I can do.** Once connected, I'll be able to **post, edit, and delete content** on your Instagram, **reply to and hide comments**, and **read your DMs**. That's a lot of authority. Are you comfortable with that?"
>
> "If yes, we'll start. If you want to limit any of those, tell me which and I'll set it up with narrower permissions."

**Handle the response:**

- **User confirms both** → proceed to Step 1.
- **User wants narrower scope** → say: *"Good instinct. Tell me which of the three you want to drop (posting, comment moderation, or DM access) and I'll leave that permission out of the connection. We can always add it back later."* Then proceed to Step 1, remembering to omit the corresponding permissions in Step 3.
- **User is hesitant** → say: *"Totally fair. Want me to walk you through what each permission actually lets me do before you decide?"* Answer questions if asked, then wait for clear consent before proceeding.
- **User refuses** → say: *"No problem, we can skip Instagram for now. If you change your mind later, just say 'connect my Instagram' and we'll pick this back up."* Do not proceed.

Only proceed past this gate when the user has explicitly confirmed they're okay with the authority level.

---

## Golden rule - Claude drives Meta's developer surfaces for EVERY action

**The default path for every Meta-side action is the Playwright MCP browser.** Once Phase 1 Step 4 logs the Playwright window into Facebook (the user enters their FB credentials), that window IS the user's Meta-developer client for the rest of the flow. Claude uses it for:

- Step 5: developers.facebook.com/apps to create the Meta Developer App, then App Settings → Basic to read the App ID and App secret from the DOM (the user does only the show-app-secret password challenge).
- Step 6: developers.facebook.com/tools/explorer/ to drive the Graph API Explorer, click Generate Access Token, and read the resulting short-lived token from the DOM (the user does only the OAuth permissions tick + Continue).
- Step 7 (optional): same flow again with Threads scopes.

These all happen in the same Playwright window, driven by `mcp__playwright__browser_*` (or `mcp__plugin_playwright_playwright__browser_*`) tools. Same Facebook account, same browser session - the App ID and tokens that Claude reads are exactly the same values the user would see if they were doing this manually.

**Do NOT, at any point in Phase 1, ask the user to:**

- Open developers.facebook.com themselves (after the login in Step 4)
- Click Create App, fill the create-app form, or click Add Product
- Read the App ID or App secret aloud or paste it back to Claude
- Open Graph API Explorer themselves
- Read the access token aloud or paste it back to Claude
- Open any other browser tab manually

If you find yourself about to type any of those, stop. The Playwright window can do all of them.

The **REST-Direct Fallback** section at the bottom of this file is the contingency for when the Playwright MCP browser cannot be used at all (extension not installed, non-recoverable launch failure after two attempts). It is NOT the path to use because manual instructions feel simpler - they don't, they make the user do extra work and they put long-lived tokens in chat history.

---

## Autonomy rule - Claude does the work, the user does not paste tokens

Meta's developer surfaces (Developer Portal + Graph API Explorer) are entirely web-driven - there is no slash-command surface for the user to invoke even if they wanted to. Everything happens via Claude's tools:

- `~/.claude.json` `mcpServers.meta` block - written via `Write` (instead of any user-paste of `/configure ...`)
- App ID, App secret, short-lived and long-lived tokens - read via `browser_evaluate` against the relevant DOM nodes (instead of "copy and paste these values back to me")
- Token exchange (short-lived → 60-day long-lived) - performed via Bash `curl` against `graph.facebook.com/v25.0/oauth/access_token`
- Page-to-Instagram-Business-Account lookup - performed via Bash `curl` against `graph.facebook.com/v25.0/me/accounts` and `<PAGE_ID>?fields=instagram_business_account`

Same end result, no paste required. Tokens land in `~/.claude.json` without ever appearing in chat output, on the user's clipboard, or in any tool-call return value.

The only things the user types across the entire flow are: their Facebook login credentials in the FB login form (which goes directly to Facebook, not to Claude - Claude never sees the password) and clicks on the OAuth permissions consent dialog (which goes directly to Meta, not to Claude).

If you find yourself about to type "paste this into the chat", stop. Either run it via Bash, write the file directly, or note that this is a true exception and explain why.

---

## No-deviation rule

If a step in this skill fails, follow the documented `if X fails, try Y` branch for that step. Do not improvise with `curl https://graph.facebook.com/...` outside the documented endpoints, do not edit the user's Facebook account settings, do not invent shortcuts. If you hit an undocumented failure, tell the user exactly what failed in plain English and stop. Do not silently pivot.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Every message you send during Phase 1 must follow the rules in `my-assistant/CLAUDE.md`:

- **One step at a time.** Never stack two instructions in one message.
- **Plain English only.** No jargon. Never say npm, npx, bash, CLI, API, terminal, config file, OAuth, scope, token, tenant, MCP, endpoint, JSON, environment variable, Graph API, or app secret as a technical concept. If you must refer to a technical thing, name it plainly: "a connection key", "a small setting on your computer", "the connection details".
- **Tell them what is about to happen.** Before any action you take: "I'm going to save your connection details now, this takes just a moment."
- **React warmly.** Good: "That worked, your Instagram is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem, let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **No em dashes in italicised user-facing strings.** Em dashes are fine in section headings and Claude-facing prose, but the user-visible italic quotes above use commas or full stops instead.

---

## PHASE 1 - Install & Connect (autonomous)

**Run Steps 1 through 9 in order, all in this one Claude Code session.** Step 4 opens developers.facebook.com in the Playwright MCP browser and waits for the user's Facebook login. Step 5 drives the App-creation flow autonomously inside that browser, including reading the App ID and App secret from the DOM. Step 6 drives Graph API Explorer autonomously to mint the access token (the user only ticks OAuth permissions). Step 7 (optional, conditional on Phase 0 Q3) does the same for Threads. Step 8 writes `~/.claude.json` with backup + read-back validation. Step 9 verifies. The REST-Direct Fallback section at the bottom is only for when Step 4 fails twice in a row - do not start there.

**Resume check.** If the user is starting a new conversation but `~/.claude.json` already has an `mcpServers.meta` entry with non-empty `INSTAGRAM_ACCESS_TOKEN` + `INSTAGRAM_USER_ID` (or `THREADS_ACCESS_TOKEN` + `THREADS_USER_ID` for Threads-only), the connector was at least partially configured by an earlier run. Ask: *"Looks like you started this earlier. Want me to pick up where you left off, or start completely fresh?"*

- **Pick up** → skip to **Step 9** (verify). If verify fails, fall back to Step 6 with a token rotation.
- **Fresh** → wipe the existing `mcpServers.meta` block (preserving every other `mcpServers` entry), then start at Step 1. The old long-lived token still exists in the user's Meta security settings until it expires; if they want to revoke it manually, guide them to **https://www.facebook.com/settings?tab=business_tools** at the end.

---

### Step 1 - Orient the user

Tell the user in one short message:

> "Great, let's connect your Instagram. I'll open Meta's developer area in a browser window. You'll log in once, tick a few permission boxes when Meta asks, and I'll handle the rest. The whole thing takes about three minutes."

### Step 2 - Detect OS, shell, and Node version

Silently run:

```bash
uname -s           # darwin = Mac, linux = Linux
echo $SHELL        # /bin/zsh, /bin/bash, etc.
node --version     # required: 18.0.0 or higher
```

On Windows (if `uname` fails), the user is in PowerShell or Command Prompt. The OS detection is for path-resolving `~/.claude.json` (`%USERPROFILE%\.claude.json` on Windows; `$HOME/.claude.json` on Mac/Linux).

**Node version handling:**

- **Node >= 18** → continue.
- **Node < 18** (or `command not found`) → tell the user: *"You'll need a slightly newer version of Node.js. Want me to install it for you, or you can install it yourself first?"* If yes, drive `nvm install --lts` (Mac/Linux with nvm) or guide them to https://nodejs.org. After install, ask them to restart Claude Code and tell you ready, then re-verify.

### Step 3 - Confirm Playwright MCP is available

Silently check whether `mcp__playwright__browser_navigate` (or `mcp__plugin_playwright_playwright__browser_navigate`) is in the available tool surface. If yes → Step 4.

If the Playwright MCP server is not registered, install it autonomously via Bash. The canonical command (per `skills/first-run-setup/SKILL.md`):

```bash
claude mcp add playwright npx @playwright/mcp@latest --scope user
```

If that errors with `Cannot find module @playwright/mcp` or similar, fall back:

```bash
npm install -g @playwright/mcp
claude mcp add playwright @playwright/mcp --scope user
```

Tell the user: *"Almost ready. Please close this window completely and open a fresh one, then tell me 'ready'."* Wait for them, then re-verify the tool surface.

If the server still doesn't show up after restart, fall back to **REST-Direct Fallback**.

### Step 4 - Open developers.facebook.com in the Playwright MCP browser

Tell the user: *"I'm going to open Meta's developer area now. You'll need to log in to Facebook with the account that owns your Page. After that I'll handle everything."*

**Pre-flight cleanup.** A previous Playwright Chrome instance with the same user-data-dir can hold a singleton lock. Try the navigation first; if it errors with `SingletonLock`, `process is already running`, `Failed to launch the browser process`, `EADDRINUSE`, or `lock file already exists`, run the cleanup branch then retry once:

- **Mac:**
  ```bash
  pkill -9 -f "(Google Chrome|Chromium|Brave Browser|Microsoft Edge).*Playwright" 2>/dev/null
  rm -f "$HOME/Library/Application Support/Google/Chrome/SingletonLock"
  rm -f "$HOME/Library/Application Support/Chromium/SingletonLock"
  rm -f "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/SingletonLock"
  rm -f "$HOME/Library/Application Support/Microsoft Edge/SingletonLock"
  ```
- **Linux:**
  ```bash
  pkill -9 -f "(chrome|chromium|brave).*Playwright" 2>/dev/null
  rm -f "$HOME/.config/google-chrome/SingletonLock"
  rm -f "$HOME/.config/chromium/SingletonLock"
  rm -f "$HOME/.config/BraveSoftware/Brave-Browser/SingletonLock"
  ```
- **Windows (PowerShell, run via `powershell.exe -Command`):** scope to Playwright-launched processes only:
  ```powershell
  Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='chromium.exe' OR Name='brave.exe' OR Name='msedge.exe'" | Where-Object { $_.CommandLine -like '*Playwright*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
  ```

Do not run cleanup pre-emptively - only after a launch failure, and only once.

**Navigate.** Use `mcp__playwright__browser_navigate` (or `mcp__plugin_playwright_playwright__browser_navigate`) to `https://developers.facebook.com/apps`.

**Wait for login.** Use `browser_snapshot` to confirm the page rendered. If the user is not signed in, the page redirects to `facebook.com/login` and shows email + password fields.

Tell the user: *"A Facebook login screen has opened. Please sign in with the Facebook account that owns the Page linked to your Instagram. I'll wait, just tell me 'done' when you're in."*

**Wait for login.** After the user confirms, take a fresh snapshot. The Apps dashboard should be visible (header reads "Apps", left sidebar with My Apps / Create App buttons). If still on the login screen after 30 seconds, ask the user if they hit any issues and re-take the snapshot. If 2FA was triggered, give the user time to complete it.

If login fails repeatedly (more than two retries), or the user reports they cannot get past Facebook's two-factor protection, fall back to **REST-Direct Fallback**.

### Step 5 - Drive the Meta Developer App creation autonomously

Once the user is logged into developers.facebook.com, Claude does the entire create-app flow in the Playwright window. The user does not click anything until the show-app-secret password challenge in 5C.

#### Step 5A - Create the App (with use cases selected up-front)

1. Click the green **Create app** button (top right). Selector: a button with text matching `/create app/i` near the top header. If the page already shows an existing "Claude Assistant" app from a previous run, ask the user *"You already have a Claude Assistant app from before. It might already have the right setup, or it might be from an older flow. Want me to use that one, or make a fresh one? Fresh is safer if you set it up before September 2024 because Meta renamed some permissions since then."* On reuse → skip to 5C with the existing app, but flag in a Claude-facing note that the existing token may have stale `business_*` scope names that need regenerating in Step 6. On fresh → first **show the user what's about to break:** *"Before I delete the old app, heads-up: any other tools you connected to it (Zapier, third-party schedulers, etc.) will break too. Sure you want to delete?"* If they confirm, click into the existing app, click Settings → Advanced → Delete app, confirm, then return to the Apps list.

2. Wait for the create-app form. Fill the fields via `browser_type` / `browser_select` / `browser_fill_form`:
   - **App display name** (or **App name**): `Claude Assistant`
   - **App contact email**: the user's email (ask once: *"What email do you want me to use as the contact email for the app? It's just for Meta to reach you about app issues."*). Note Meta occasionally reorders these fields between UI revisions; if the form has a different order, fill whichever appears next, the values are the same.
   - Click **Next** when the form moves to the use-case selector.
   - **Use cases** screen: this is where Meta wires up the Instagram + Threads integration **at app-creation time** (post-2024 UI; "Add product" later is no longer the path). Tick:
     - **Other** (gives access to the standard Graph API surface and the Instagram product).
     - **Access Threads API** (only if the user said yes to Threads in Phase 0 Q3, otherwise leave unticked).
   - Click **Next**.
   - **App type**: `Business`. Click **Next**.
   - **Business portfolio**: select the one linked to the user's Facebook Page (or click `Don't connect a business portfolio yet` / equivalent if Meta lets you skip).
   - Click **Create app**.

3. Wait for the app dashboard to load. Confirm by snapshot - the page title reads "Claude Assistant" and the left sidebar shows App settings, Use cases, etc. The Instagram and (if selected) Threads use cases should already be wired up.

#### Step 5B - Confirm Instagram product is wired

1. Click **Use cases** in the left sidebar (post-2024 UI replaced "Add product" for most flows).
2. Locate the **Instagram** card (note: Meta renamed this from "Instagram Graph API" in 2024, the UI now reads simply "Instagram"). Confirm it's listed as Active. If not, click its **Customize** button and complete any pending setup.

> **Claude-facing note.** If Step 5A used the older "Add product" path on a UI revision Meta hasn't fully migrated, the same Instagram card lives under **Add product** instead of **Use cases**. Both paths converge to the same product wired-up state. Snapshot first to determine which sidebar entry exists, then click the live one.

#### Step 5C - Read App ID and App secret from the DOM (with mask-race guard)

1. Click **App settings** → **Basic** in the left sidebar.
2. Wait for the page to render via `browser_wait_for` against an element containing the literal text "App ID".
3. Read the App ID from the DOM via `browser_evaluate`. Use a **label-anchored** selector to survive Meta's React refactors:

   ```javascript
   () => {
     const labels = [...document.querySelectorAll('label, span, div')];
     const lbl = labels.find(el => el.textContent.trim() === 'App ID');
     if (!lbl) return null;
     let sib = lbl.parentElement;
     for (let i = 0; i < 5 && sib; i++) {
       const input = sib.querySelector('input[readonly], input[type="text"], input[type="number"]');
       if (input?.value && /^\d{10,20}$/.test(input.value)) return input.value;
       const codeEl = sib.querySelector('code, [class*="App"], [class*="readOnly"]');
       if (codeEl?.textContent && /^\d{10,20}$/.test(codeEl.textContent.trim())) return codeEl.textContent.trim();
       sib = sib.nextElementSibling || sib.parentElement;
     }
     return null;
   }
   ```

   App IDs are 13-20 digit numeric strings. If the read returns null, take a snapshot and surface to the user.

4. The **App secret** is hidden behind a **Show** button. Click the **Show** button adjacent to the "App secret" label.

5. Meta will prompt the user to re-enter their Facebook password to reveal the App secret. **This is the only Step 5 user touchpoint.** Tell the user: *"Meta is asking you to confirm your Facebook password to reveal the app secret. Please go ahead and enter it. I'll wait."*

6. Wait for the user to confirm. **Now the mask-race guard.** Do NOT snapshot immediately - between user-confirms-password and Meta-server-side-verification, the DOM may briefly show the masked value `••••••••` (32 dots). Use `browser_wait_for` with a predicate polling for the unmasked 32-char hex value:

   ```javascript
   () => {
     const labels = [...document.querySelectorAll('label, span, div')];
     const lbl = labels.find(el => el.textContent.trim() === 'App secret');
     if (!lbl) return false;
     let sib = lbl.parentElement;
     for (let i = 0; i < 5 && sib; i++) {
       const input = sib.querySelector('input[type="text"], input[readonly]');
       if (input?.value && /^[0-9a-f]{32}$/.test(input.value)) return true;
       const codeEl = sib.querySelector('code, [class*="readOnly"]');
       if (codeEl?.textContent && /^[0-9a-f]{32}$/.test(codeEl.textContent.trim())) return true;
       sib = sib.nextElementSibling || sib.parentElement;
     }
     return false;
   }
   ```

   Poll every 200ms with a 10s timeout. On timeout, ask the user *"Hmm, the secret is still hidden. Could you try clicking 'Show' again?"* and retry once. After two timeouts, stop with a clear diagnostic.

7. Once the wait predicate returns true, read the App secret using the same label-anchored selector as App ID but with the `[0-9a-f]{32}` regex. Capture App ID and App secret as in-memory variables (NOT echoed back to the user).

**If the show-app-secret password challenge fails (Meta returns "Wrong password"):** tell them: *"That didn't go through, want to try the password again?"* Retry up to 3 times. If they still can't reveal the secret, stop the skill and tell them to run `forgot password` on Facebook first.

### Step 6 - Drive Graph API Explorer to mint the access token

Stay in the same Playwright window. Claude opens Graph API Explorer in a new tab to keep the App dashboard's session alive.

1. **Open a new tab** in the Playwright window via `browser_tabs` (the @playwright/mcp server exposes a `browser_tabs` tool that supports list / switch / new / close - verify by calling it without arguments to see the action surface). If `browser_tabs` is unavailable, fall back to `browser_navigate` in the existing tab - Meta's dev portal state is server-side, so navigating away does not lose progress.

2. **Navigate** to `https://developers.facebook.com/tools/explorer/`.

3. **Wait for page render** via `browser_wait_for` against the literal text "Graph API Explorer" or the Application dropdown.

4. **Select the app.** Click the **Application** dropdown (top right). From the dropdown options, click `Claude Assistant`. `browser_wait_for` until the dropdown's visible text reads `Claude Assistant`.

5. **Click Generate Access Token.** Selector: button with text matching `/generate access token/i` (Meta's label has shifted between "Generate Access Token" and "Get User Access Token" across UI revisions). Just below the Application dropdown.

6. **Handle the popup window.** Meta's Login Dialog opens in a **separate browser window**, not an in-page modal. The autonomous-tick approach won't work because `browser_click` calls fire on the active tab, and after the popup opens, the active tab is the Graph API Explorer (not the popup).

   The reliable path is to **hand the OAuth approval to the user**:

   - Confirm the popup opened (snapshot the existing tab; if the tab list now has 2 tabs OR the page focus shifted, the popup is up).
   - Tell the user: *"Meta has just opened a permission window. Please tick all of the following permissions in that window, then click Continue as [your name] to approve. I'll wait. Tell me 'done' once the window closes."*
   - List the required scopes (and which to omit per Phase 0 / safety-gate user choices):
     - `instagram_basic`
     - `instagram_content_publish` (omit if user dropped publishing)
     - `instagram_manage_comments` (omit if user dropped comment moderation)
     - `instagram_manage_insights`
     - `instagram_manage_messages` (omit if user dropped DM access)
     - `pages_show_list`
     - `pages_read_engagement`
   - **Tester role note (Claude-facing).** Meta's permissions reference says these scopes require **App Review** before they work in Live mode. In Development mode (where workshop attendees stay), they only work for users listed under the app's **Roles → Testers**. The user who created the app is automatically App Admin (which counts as Tester). If they later want a teammate to use the same connector, the teammate must be added at developers.facebook.com → Roles → Testers and accept the invite. Without that, scope grants succeed but tool calls return error code 200 / permission-denied.

   > **Auth-flow note (Claude-facing).** This skill uses the **Facebook-Login flow**. Under that flow, the scope names above are correct. The **Instagram-Login flow** (a separate Meta product) renames `instagram_manage_messages` → `instagram_business_manage_messages` and `instagram_manage_insights` → `instagram_business_manage_insights`. The Sept 2024 changelog also deprecated the older `business_basic` / `business_content_publish` family with a Jan 27, 2025 cut-off; if a user reuses an app from before Sept 2024 (Step 5A reuse branch), regenerate the token here to pick up the renamed scopes.

7. **Wait for user confirmation.** When the user says done, snapshot the Graph API Explorer tab. The Access Token field now contains a long string.

8. **Read the short-lived token from the DOM** via `browser_evaluate`. Use multiple selectors for resilience:

    ```javascript
    () => {
      const sels = [
        '[data-testid="access-token"] textarea',
        'textarea[name="access_token"]',
        'input[name="access_token"]',
        'textarea[placeholder*="access token" i]',
        'textarea[aria-label*="access token" i]',
      ];
      for (const s of sels) {
        const el = document.querySelector(s);
        if (el?.value) return el.value.trim();
      }
      // Last-ditch: any textarea on the page with a Bearer-token-shaped value
      for (const ta of document.querySelectorAll('textarea, input')) {
        if (ta.value && ta.value.length > 100 && /^EAA/.test(ta.value)) return ta.value.trim();
      }
      return null;
    }
    ```

    (Meta short-lived user-access tokens currently start with `EAA` followed by a base64-like body.)

9. **Exchange short-lived for long-lived (60-day) token via Bash, using POST + `--data-urlencode` to keep the App secret out of process argv and shell history:**

    ```bash
    # Disable history capture for this curl
    set +o history 2>/dev/null
    HISTFILE=/dev/null
    curl -s -X POST "https://graph.facebook.com/v25.0/oauth/access_token" \
      --data-urlencode "grant_type=fb_exchange_token" \
      --data-urlencode "client_id=$APP_ID" \
      --data-urlencode "client_secret=$APP_SECRET" \
      --data-urlencode "fb_exchange_token=$SHORT_LIVED_TOKEN"
    ```

    Pass `APP_ID`, `APP_SECRET`, `SHORT_LIVED_TOKEN` as Bash environment variables (set in the same Bash call) rather than interpolating into the command string.

    Parse the JSON response, capture `access_token`. This is the long-lived token.

    **Common mistakes to handle:**
    - **Response is not valid JSON** (Meta sometimes returns an HTML error page during outages) → capture the first 500 chars of the response and surface to the user: *"Meta returned something unexpected. Want me to retry, or stop?"*
    - **Response is JSON but `access_token` is missing** → look for `error.code` and `error.message`. Common codes:
      - **`190`** - token invalid or expired → redo Step 6 part 5 (the short-lived token expires in ~1 hour).
      - **`OAuthException` + "Error validating application"** or **"Invalid OAuth access token signature"** → re-read the App secret from the DOM (Step 5C). The value may have been read while still masked (the C5 mask-race) or with whitespace.

10. **Find the Instagram Business Account ID via Bash, with pagination for users with >25 Pages:**

    ```bash
    # First page (max 100 per page)
    curl -s "https://graph.facebook.com/v25.0/me/accounts?limit=100&access_token=$LONG_LIVED_TOKEN"
    ```

    If the response includes `paging.next`, follow that URL to fetch additional pages until exhausted. Concatenate all `data` arrays.

    For each Page in the combined list, call:

    ```bash
    curl -s "https://graph.facebook.com/v25.0/$PAGE_ID?fields=instagram_business_account&access_token=$LONG_LIVED_TOKEN"
    ```

    Capture the Instagram Business Account ID from any Page that returns one.

    **Common mistakes to handle:**
    - **No Pages returned (across all pages)** → the user signed into Facebook with the wrong account in Step 4. Ask them to log out via the Playwright window, log back in with the Page-admin account, and re-run from Step 5C.
    - **`instagram_business_account` is null on every Page** → the Instagram account is not linked to any Page on this user's account. Loop back to Phase 0 question 2.
    - **Multiple Pages with IG accounts** → ask the user *"You manage [N] Pages with Instagram. Which one should I connect: [list names]?"* Use their answer.

### Step 7 - (Optional) Mint the Threads access token

Only run this step if the user said yes to Threads in Phase 0 question 3. Otherwise skip to Step 8.

Because the Threads use case was selected at app-creation time (Step 5A), the Threads API is already wired into the app. We just need a Threads-scoped token alongside the Instagram one.

1. **In the same Playwright window**, navigate to `https://developers.facebook.com/tools/explorer/`. Confirm `Claude Assistant` is selected in the Application dropdown.

2. **Click Generate Access Token** again. A new OAuth permissions popup opens.

3. **Hand the OAuth approval to the user** (same pattern as Step 6 part 6 - Meta opens a popup window, autonomous tick is unreliable across the popup boundary). Tell them: *"Meta's permission window just opened again. This time it's for Threads. Please tick all of the following permissions in that window, then click Continue. Tell me 'done' once the window closes."* List the Threads scopes (omit per user choice):
   - `threads_basic`
   - `threads_content_publish`
   - `threads_manage_replies`
   - `threads_read_replies`
   - `threads_manage_insights`
   - `threads_keyword_search` (omit if user does not want public-post search)
   - `threads_delete` (omit if user does not want delete authority)

4. **Read the short-lived Threads token from the DOM** (same selector pattern as Step 6 part 8 - Threads user-access tokens also start with `THAA` or `EAA` depending on the Meta API surface used).

5. **Exchange short-lived for long-lived via the same POST endpoint as Step 6 part 9.** The same Meta `fb_exchange_token` endpoint accepts Threads tokens minted from a Threads-use-case-enabled app.

6. **Capture the Threads user ID via Bash:**

    ```bash
    curl -s "https://graph.threads.net/v1.0/me?fields=id,username&access_token=$LONG_LIVED_THREADS_TOKEN"
    ```

    The `id` field is the Threads user ID. Capture as `THREADS_USER_ID`.

**If Step 7 fails because the Threads use case is missing on the app** (the user reused an old app from Step 5A that didn't include Threads): tell the user *"This app wasn't set up for Threads. I can either add it now (it's a one-click toggle in Use cases on your app dashboard), or I can stop and we'll come back to Threads later. What would you like?"* On add-now → drive **Use cases** in the left sidebar of the app dashboard, toggle on **Access Threads API**, then return to Step 7 part 1. On stop → skip to Step 8 with Instagram only.

### Step 8 - Save the credentials with backup + read-back validation

**App-secret persistence - ask before writing it.** `META_APP_SECRET` is only required by the four `meta_*` token-management tools (`meta_exchange_token`, `meta_refresh_token`, `meta_debug_token`, `meta_subscribe_webhook`). The 33 IG tools and 18 Threads tools work without it. Persisting the App secret long-term increases the blast radius of a `~/.claude.json` leak - token + App secret = full account takeover, vs token alone = 60 days of damage that the user can revoke from Meta security.

Ask the user: *"One last security choice. The connection key plus a separate 'app secret' is what I need if you ever want me to refresh the connection automatically. Most users never need to do that. When the connection expires in 60 days, you can come back to me and we'll mint a fresh one. The safer default is for me NOT to save the app secret on your computer. Want me to skip saving it (recommended), or save it for the auto-refresh convenience?"*

- **Skip (recommended)** → omit `META_APP_SECRET` from the JSON write. Note in a Claude-facing memory that this user will see clear errors if they try to call `meta_*` tools, and the skill should respond by asking them to paste the App secret on demand for that one operation.
- **Save** → include `META_APP_SECRET` as documented below.

**Tell the user before writing:** *"I'm about to save your connection details. Please make sure Claude Code itself is closed in any other windows. If it's open elsewhere it might be writing to the same file at the same time. Tell me when you've checked."*

Wait for confirmation. This avoids the harness-vs-skill write race that can corrupt `~/.claude.json`.

**Always back up before write.** Snapshot the current file to `~/.claude.json.backup-<UTC-timestamp>` regardless of whether parsing will succeed:

```bash
cp -p "$HOME/.claude.json" "$HOME/.claude.json.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null
```

(On Windows, run via the PowerShell tool directly, not interpolated through Bash:
`Copy-Item "$env:USERPROFILE\.claude.json" "$env:USERPROFILE\.claude.json.backup-$(Get-Date -Format 'yyyyMMddTHHmmssZ')"`. Skip if file does not exist.)

Then read the existing file (use `Read`). Parse as JSON. If the file does not exist, the JSON to write is just the Meta entry. **If it exists but cannot be parsed, STOP. Do not write.** Tell the user: *"Your settings file looks corrupted. I can rebuild it from scratch, but you'd lose any other connections you had set up (like Xero, HubSpot, etc.) and need to reinstall those. I've saved a backup of the corrupted version. Want me to rebuild, or stop here so you can recover the file manually first?"* Wait for explicit consent before writing.

If parseable, merge into the existing `mcpServers` object. **Default (App secret skipped):**

```json
{
  "mcpServers": {
    "meta": {
      "command": "npx",
      "args": ["-y", "@mikusnuz/meta-mcp@latest"],
      "env": {
        "INSTAGRAM_ACCESS_TOKEN": "<long-lived IG token from Step 6>",
        "INSTAGRAM_USER_ID": "<IG Business Account ID from Step 6>",
        "META_APP_ID": "<App ID from Step 5C>"
      }
    }
  }
}
```

**If user opted to save App secret**, add `"META_APP_SECRET": "<App secret from Step 5C>"` to the `env` block.

If the user opted into Threads (Step 7), also include in `env`:

```json
        "THREADS_ACCESS_TOKEN": "<long-lived Threads token from Step 7>",
        "THREADS_USER_ID": "<Threads user ID from Step 7>"
```

**Rules:**
- Merge into the existing `mcpServers` object rather than overwriting it. Preserve every other entry.
- Never echo any access token, App ID, or App secret back to the user after writing them.
- File permissions: on Mac/Linux, `chmod 600 $HOME/.claude.json`. On Windows, default user-profile ACL is sufficient.

**After write, read back and validate.** Re-read `~/.claude.json` with `Read`, parse as JSON, confirm:
1. Parse succeeds.
2. `mcpServers.meta` exists.
3. `mcpServers.meta.env.INSTAGRAM_ACCESS_TOKEN`, `INSTAGRAM_USER_ID`, `META_APP_ID`, `META_APP_SECRET` (and Threads pair if applicable) are all present and non-empty.
4. Every other `mcpServers.*` entry that was present before the write is still present (compare against the pre-write parse).

If any of (1)-(4) fails, **do not** instruct the user to restart yet. Restore from the most recent `~/.claude.json.backup-<timestamp>` and retry the merge once. After two failures, stop and tell the user the connection write is unstable, with the backup path.

Tell the user: *"I've saved the connection. One more step. Please close Claude Code completely and open it again, then tell me you're back. This is so it picks up the new connection."*

### Step 9 - Verify the connection

Wait for the user to restart. When they return, tell them: *"Welcome back. Let me check that everything is talking."*

Branch the verify call by which tokens were written:

- If `INSTAGRAM_ACCESS_TOKEN` is in `~/.claude.json` → call `mcp__meta__ig_get_profile` (no arguments).
- If `THREADS_ACCESS_TOKEN` is in `~/.claude.json` → call `mcp__meta__threads_get_profile` (no arguments).
- If both → call both, in the order written.

Handle the response (apply to whichever calls succeeded):

- **Tool returns profile info with username** → Capture the username. Tell the user the appropriate one of:
  > "All done. I'm now connected to your Instagram **@[username]**. You can ask me things like 'show me my recent posts', 'post this photo to Instagram', 'what's the engagement on my last Reel', or 'reply to that comment'. Give it a try."
  >
  > "All done. I'm now connected to your Threads **@[username]**. You can ask me things like 'show me my recent threads', 'post this to Threads', or 'how is my Threads doing'. Give it a try."

  If both Instagram and Threads were configured, combine the two confirmations in one message.

- **Tool returns `Invalid OAuth access token` or `190` error code** → "Hmm, the connection key didn't work, let me take it again." Note that the user's restart in Step 8 closed the Playwright window and ended the Facebook login session, so re-running from Step 6 is not enough - re-run from **Step 4** (re-open the Playwright window, ask the user to log in to Facebook again, re-mint the token via Step 6, re-write `~/.claude.json` via Step 8, restart Claude Code, retry verify).

- **Tool returns `Permissions error` or `200` error code (insufficient permissions)** → "Your connection is working, but I need one or two extra permissions. Let me redo the token with the right boxes ticked." Same restart caveat: the Playwright session is dead, so re-run from **Step 4** with the Facebook login → Step 6 with the missing scope ticked → Step 8 rewrite → Claude Code restart → re-verify. **Restart of Claude Code IS needed** for new tokens - Meta's tokens are env-var-injected at MCP server boot, so any token rewrite requires a Claude Code restart to pick up the new env.

- **Tool returns `permission denied` (error code 10)** → if `META_APP_SECRET` was skipped in Step 8 and the user is asking me to call a `meta_*` token tool, the runtime will fail because the secret isn't loaded. Tell the user: *"This particular tool needs the app secret you chose not to save earlier. Want me to add it temporarily, or skip this and use a different approach?"* On add-temporarily → drive Step 4 + Step 5C to re-read the App secret from the DOM, write it to `~/.claude.json`, restart, retry. On skip → suggest the equivalent action via a non-`meta_*` tool if available.

- **Tool is not yet available (`mcp__meta__*` tools not discoverable)** → "Looks like Claude Code didn't pick up the new connection yet. Please make sure you fully closed it (not just the window) and opened it again, then let me know." Repeat Step 8's restart instruction.

- **Any other error** → "Something's not quite right, let me try once more." Retry the tool call once. If it still fails, tell the user in plain English what you saw (translated, never raw errors), and ask if they want to retry or stop.

---

## PHASE 2 - Use Tools

Once the connector is configured, use the `mcp__meta__*` MCP tools below. The server exposes **57 tools total** across Instagram (33), Threads (18), and Meta platform token management (6). All 57 are catalogued in the tables that follow; resources (`instagram://profile`, `threads://profile`) and prompts (`content_publish`, `analytics_report`) are also exposed by the server but are not surfaced as tools - see [the maintainer's `llms.txt`](https://github.com/mikusnuz/meta-mcp/blob/main/llms.txt) for those.

### Instagram - Publishing

| Tool | Description | Use when |
|---|---|---|
| `ig_publish_photo` | Publish a photo post (supports `alt_text`) | User asks to post a photo to Instagram |
| `ig_publish_video` | Publish a video post | User asks to post a video to Instagram |
| `ig_publish_carousel` | Publish a carousel/album (2-10 items, `alt_text` per item) | User asks to post multiple photos/videos as one post |
| `ig_publish_reel` | Publish a Reel (supports `alt_text`) | User asks to post a Reel |
| `ig_publish_story` | Publish a Story (24-hour) | User asks to post a Story |
| `ig_get_container_status` | Check media container processing status | After publishing video/Reel, before assuming it's live |

### Instagram - Media

| Tool | Description | Use when |
|---|---|---|
| `ig_get_media_list` | List published media | User asks "show me my recent posts" |
| `ig_get_media` | Get media details | User asks about a specific post |
| `ig_delete_media` | Delete a media post | User asks to delete a post - **confirm first** |
| `ig_get_media_insights` | Get media analytics (views, reach, saved, shares) | User asks about post performance |
| `ig_toggle_comments` | Enable/disable comments on a post | User asks to lock comments on a post |

### Instagram - Comments

| Tool | Description | Use when |
|---|---|---|
| `ig_get_comments` | Get comments on a post | User asks to see comments on a post |
| `ig_get_comment` | Get comment details | User asks about a specific comment |
| `ig_post_comment` | Post a comment on a post | User asks to comment on a post - **confirm first** |
| `ig_get_replies` | Get replies to a comment | User asks to see replies under a comment |
| `ig_reply_to_comment` | Reply to a comment | User asks to reply to a comment - **confirm first** |
| `ig_hide_comment` | Hide/unhide a comment | User asks to hide a negative comment |
| `ig_delete_comment` | Delete a comment (own comments only) | User asks to delete their own comment - **confirm first** |

### Instagram - Profile & Insights

| Tool | Description | Use when |
|---|---|---|
| `ig_get_profile` | Get account profile info | Verifying connection or showing account stats |
| `ig_get_account_insights` | Account-level analytics (views, reach, follower_count) | User asks "how is my account doing?" |
| `ig_business_discovery` | Look up another business account by username | User asks "what's @competitor's stats?" |
| `ig_get_collaboration_invites` | Get pending collaboration invites | User asks about collab requests |
| `ig_respond_collaboration_invite` | Accept or decline collaboration invite | User asks to accept/decline a collab - **confirm first** |

### Instagram - Hashtags

| Tool | Description | Use when |
|---|---|---|
| `ig_search_hashtag` | Search hashtag by name | Hashtag research |
| `ig_get_hashtag` | Get hashtag info | Detail on a specific hashtag |
| `ig_get_hashtag_recent` | Get recent media for a hashtag | "Show me recent posts for #[tag]" |
| `ig_get_hashtag_top` | Get top media for a hashtag | "Show me top posts for #[tag]" |

### Instagram - Mentions, Tags & Messaging

| Tool | Description | Use when |
|---|---|---|
| `ig_get_mentioned_comments` | Get comments mentioning you | "Who mentioned me recently?" |
| `ig_get_tagged_media` | Get media you're tagged in | "Show me posts I'm tagged in" |
| `ig_get_conversations` | List DM conversations | "Show me my DMs" |
| `ig_get_messages` | Get messages in a conversation | Reading a specific DM thread |
| `ig_send_message` | Send a DM | User asks to send a DM - **confirm first** |
| `ig_get_message` | Get message details | Reading a specific message |

### Threads - Publishing

| Tool | Description | Use when |
|---|---|---|
| `threads_publish_text` | Publish text post (polls, GIFs, link attachments, topic tags, quote, spoiler) | User asks to post text to Threads |
| `threads_publish_image` | Publish image post (alt_text, topic tags, spoiler) | User asks to post image to Threads |
| `threads_publish_video` | Publish video post (alt_text, topic tags, spoiler) | User asks to post video to Threads |
| `threads_publish_carousel` | Publish carousel (2-20 items, alt_text per item) | User asks to post multiple items to Threads |
| `threads_delete_post` | Delete a Threads post (maintainer notes a 100/day cap; verify against current Meta policy before bulk deletes) | User asks to delete a thread - **confirm first** |
| `threads_get_container_status` | Check container processing status | After publishing, before assuming it's live |
| `threads_get_publishing_limit` | Check remaining quota (250 posts/day) | Before bulk publishing |

### Threads - Read, Replies & Insights

| Tool | Description | Use when |
|---|---|---|
| `threads_get_posts` | List published posts | "Show me my recent threads" |
| `threads_get_post` | Get post details | Detail on a specific thread |
| `threads_search_posts` | Search public posts by keyword or topic tag | Research |
| `threads_get_replies` | Get replies to a post | "Who replied to my thread?" |
| `threads_reply` | Reply to a post (supports image/video attachments) | User asks to reply to a thread - **confirm first** |
| `threads_hide_reply` | Hide a reply | User asks to hide a reply |
| `threads_unhide_reply` | Unhide a reply | User asks to unhide |
| `threads_get_profile` | Get Threads profile info | Verifying Threads connection |
| `threads_get_user_threads` | List threads for an arbitrary user_id (defaults to connected user when omitted) | Use when the user asks for someone else's public threads by user_id; for the connected user use `threads_get_posts` instead |
| `threads_get_post_insights` | Post analytics (views, likes, replies, reposts, quotes, clicks) | User asks about post performance |
| `threads_get_user_insights` | Account-level analytics | User asks "how is my Threads doing?" |

### Meta Platform - Token & App management

| Tool | Description | Use when |
|---|---|---|
| `meta_exchange_token` | Exchange short-lived token for long-lived (~60 days) | After regenerating a token in Graph API Explorer |
| `meta_refresh_token` | Refresh a long-lived token before expiration | At the 50-day mark, to extend another 60 days |
| `meta_debug_token` | Inspect token validity, expiration, and scopes | Troubleshooting auth errors |
| `meta_get_app_info` | Get Meta App information | Verifying app config |
| `meta_subscribe_webhook` | Subscribe to webhook notifications | Setting up event-driven workflows |
| `meta_get_webhook_subscriptions` | List current webhook subscriptions | Auditing what events are wired up |

> **Note:** This skill documents all 57 tools above. The server also exposes resources (`instagram://profile`, `threads://profile`) and prompts (`content_publish`, `analytics_report`) which are not surfaced as tools. Consult [the maintainer's `llms.txt`](https://github.com/mikusnuz/meta-mcp/blob/main/llms.txt) for those.

---

## Prompt-to-Tool Mapping

| What the user says | Tool to use |
|---|---|
| "Connect my Instagram" / "Install the Meta Business Suite connector" | **Run Phase 1** (starting with Phase 0 pre-flight, then the safety gate) |
| "Connect Threads" | **Run Phase 1**, but skip directly to Step 4 if Instagram is already configured |
| "Post this photo to Instagram" | `ig_publish_photo` - **confirm first** |
| "Post a Reel" | `ig_publish_reel` - **confirm first** |
| "Post a carousel" | `ig_publish_carousel` - **confirm first** |
| "Post a story" | `ig_publish_story` - **confirm first** |
| "Show me my recent posts" | `ig_get_media_list` |
| "How did my last Reel do?" | `ig_get_media_insights` on the latest video |
| "What's my account growth?" | `ig_get_account_insights` |
| "Show me comments on [post]" | `ig_get_comments` |
| "Reply to that comment" | `ig_reply_to_comment` - **confirm first** |
| "Hide that troll comment" | `ig_hide_comment` |
| "Show me my DMs" | `ig_get_conversations` |
| "Reply to [name]'s DM" | `ig_send_message` - **confirm first** |
| "Top posts for #[tag]" | `ig_get_hashtag_top` |
| "What's @[competitor] doing?" | `ig_business_discovery` |
| "Who mentioned me?" | `ig_get_mentioned_comments` |
| "Post this to Threads" | `threads_publish_text` (or `_image` / `_video`) - **confirm first** |
| "Reply to that thread" | `threads_reply` - **confirm first** |
| "How is my Threads doing?" | `threads_get_user_insights` |
| "Refresh my connection key" | `meta_refresh_token` |
| "Is my connection still valid?" | `meta_debug_token` |

---

## Error Handling (Phase 2)

When a Meta tool call fails, diagnose and respond in plain English. Never show raw error messages.

| Error | What to say to the user | How to fix |
|---|---|---|
| `Invalid OAuth access token` / error code `190` | "Your Instagram connection key has expired or been revoked, let me sort that now." | Run Phase 1 from Step 3 (regenerate short-lived token, re-exchange, rewrite `~/.claude.json`, restart). If repeats, check `meta_debug_token` for clues. |
| Error code `200` (insufficient permissions) | "I need one extra permission for that, let me show you which box to tick." | Run Phase 1 from Step 3 with the missing scope ticked, re-exchange, rewrite, restart. The Graph API Explorer dialog determines scopes - they cannot be added on the fly. |
| Error code `4` (App-level rate cap, rare) | "Meta is asking me to slow down at the app level. I'll wait a moment and try again." | Wait 60 seconds and retry once. Code 4 is the app-wide cap, almost never hit by a workshop user. |
| Error code `17` (user-level throttling) / Error code `32` (Page-level throttling) | "Meta is asking me to slow down on this account. I'll wait a moment and try again." | Wait 60 seconds and retry once. If still throttled, fall back to the BUC budget guidance below in Phase 2 Behaviour Guidelines. |
| Error code `10` (permission denied) | "I'm not allowed to do that, let me check why." | Cause is one of: (a) the scope was never granted on the token, (b) it was revoked in Meta settings, or (c) in production mode the feature requires Meta App Review. Workshop users on dev mode are exempt from App Review **as long as they are listed as a Tester** on the app's Roles → Testers list. Diagnose with `meta_debug_token`. |
| Error code `100` (invalid parameter) | Summarise which field is invalid in plain English (e.g., *"Instagram says the image URL isn't reachable, let me fix it and try again"*) | Correct the request and retry once. Common: image URL not publicly accessible, Reels exceed 15-minute max or are below 3-second min, carousel mixing photos and videos in unsupported order. |
| Container `status_code: ERROR` after publish | "Instagram couldn't process the media, let me check what went wrong." | Call `ig_get_container_status` and read the `error_message`. Common: bitrate too high (Reels max 25Mbps video bitrate), aspect ratio outside the 0.01:1-10:1 Reels range or 4:5-1.91:1 feed-post range, file size over 300MB, or unsupported codec (Reels need H.264 or HEVC + AAC). |
| `OAuthException` with `Error validating application` in the message | "Your App secret didn't validate, let me recheck it." | Re-run Step 2 part 5 to recopy the App secret. Compare to what's in `~/.claude.json`. |
| Daily publishing limit hit (Instagram: 100/day, Threads: 250/day) | "You've hit Meta's daily posting limit. Try again tomorrow or pace your posts." | No fix - the limit is real. Carousels count as 1 toward the 100/day Instagram cap. Defer to next 24-hour window. |
| MCP server not discovered (`mcp__meta__*` tools missing) | "The Meta connection isn't active in this session. Please close Claude Code fully and reopen it, then try again." | User restarts Claude Code. |
| Any other Graph API error | "Something went wrong with Meta, let me try again." | Retry once; if still failing, run `meta_debug_token` to inspect token state. |

---

## Security Assessment

This skill grants broad publishing and read authority over the user's Instagram Business and Threads accounts. The risks below are catalogued so the safety gate, scope-narrowing offer, and Phase 2 confirmation prompts can defend against them.

| # | Risk | Likelihood | Impact | Mitigation in this skill |
|---|---|---|---|---|
| 1 | **Token theft via leaked `~/.claude.json`.** Long-lived token grants 60-day full-account access if exfiltrated. | Medium | High (attacker can post, delete, DM as the user) | File permissions guidance in Step 5 (mode `600` on Mac/Linux). Token never echoed back. Encourage user to enable filesystem encryption. Recommend `meta_refresh_token` rotation if the file is ever shared. |
| 2 | **App secret leak.** `META_APP_SECRET` is in `~/.claude.json` - required for token-management tools but enables impersonation if stolen. | Low | High (attacker can mint new tokens) | Step 5 stores it alongside the token (same file, same protection). Note: app secret is not strictly required for IG/Threads runtime tool calls, only for `meta_*` token tools (`meta_exchange_token`, `meta_refresh_token`, `meta_debug_token`, `meta_subscribe_webhook`). **Optional hardening:** if the user does not plan to use those tools after install, omit `META_APP_SECRET` from `~/.claude.json` and paste it back temporarily when refreshing or debugging. **Caveat:** removing `META_APP_SECRET` disables Phase 2 troubleshooting via `meta_debug_token`. If the user relies on that error-handling path, leave the secret in place. |
| 3 | **Unauthorised content publishing.** Anyone with shell access can call `ig_publish_*` to post anything to the user's account. | Medium | High (brand damage, legal exposure for offensive content) | Phase 2 publishing tools all require **explicit confirmation**. The skill never auto-publishes. Recommend pairing with `~/.claude.json` filesystem encryption. |
| 4 | **Comment moderation abuse.** Token holder can hide/delete legitimate user comments - the user may not notice. | Medium | Medium (silenced critics, hidden customer complaints) | `ig_hide_comment` and `ig_delete_comment` are noted as confirm-first. Skill instructs Claude to summarise the comment text before hiding/deleting. |
| 5 | **DM exfiltration.** With `instagram_manage_messages`, all Messenger/IG inbox content is readable. Includes private customer data. | Medium | High (privacy breach, potential GDPR/Privacy Act exposure for AU clients) | Safety gate offers to drop `instagram_manage_messages`. If dropped, `ig_send_message` and `ig_get_*` message tools fail at runtime - the skill should detect a `permissions` error and explain. |
| 6 | **Account takeover.** Long-lived tokens cannot be revoked silently - they appear in the user's Meta security settings. | Low | High | The safety gate explicitly tells the user about token authority. `meta_debug_token` lets the user audit the live token. Users should review Meta → Settings → Security → Apps and Websites monthly. |
| 7 | **Scope creep at install.** User ticks every permission "to be safe" without understanding. | High | Medium | Phase 0 + safety gate force the user to opt in to each permission category (publish, comment moderation, DMs). Step 3 part 4 calls out which scopes belong to which authority. |
| 8 | **Webhook hijack.** `meta_subscribe_webhook` can register external URLs that receive event notifications including post and comment data. | Low | High (silent data exfil to attacker-controlled URL) | This skill **does not call `meta_subscribe_webhook` automatically.** It is reserved for advanced workflows. If a user requests webhooks, treat as a sensitive action and show the URL plainly before calling. |
| 9 | **Rate limit triggering account flag.** Mass operations (bulk hide-comment, bulk DM) can trigger Meta's anti-spam systems and shadow-ban the account. | Medium | Medium (reduced reach, account restriction) | Phase 2 instructs Claude to throttle bulk operations, add 1-2 second delays, and warn the user before any operation touching >10 items. |
| 10 | **App Review bypass risk.** Workshop users in dev mode skip Meta App Review by adding themselves as Testers. The Tester role is silent and persistent. | Low | Low | Note in error handling - if a user offboards a developer, they should remove that developer from the app's Roles → Testers list. The skill itself does not modify the Tester list. |

**Recommended user-side hardening (not in this skill, but worth telling the user):**
- Enable two-factor auth on the Facebook account that owns the App.
- Review **Meta Settings → Security → Apps and Websites** quarterly and revoke unused.
- Rotate the long-lived token via `meta_refresh_token` every 50 days (don't wait for expiry).
- If Claude Code is shared on a machine, **do not** add `META_APP_SECRET` to `~/.claude.json` permanently - paste it only when running `meta_exchange_token`/`meta_refresh_token`.

---

## Scope Limitations

The Meta Business Suite connector **can** do (via `@mikusnuz/meta-mcp`):

- Publish to Instagram Business: photos, videos, carousels, Reels, stories
- Read Instagram media list, media details, media insights
- Manage Instagram comments: post, reply, hide, delete (own comments only)
- Read/send Instagram DMs (with `instagram_manage_messages` scope)
- Search Instagram hashtags, look up other Business accounts via `ig_business_discovery`
- Publish to Threads: text, image, video, carousels, polls, link attachments, quotes, replies
- Read Threads posts, replies, search public posts
- Read account-level + post-level insights for both Instagram and Threads
- Manage Meta tokens: exchange, refresh, debug

The Meta Business Suite connector **cannot** do:

- **Post to a Facebook Page** organically. Use a separate `facebook-page-connector` (not yet built).
- **Run Meta Ads** (paid campaigns, ad sets, targeting, creatives). Use Luke's `lukeselr/meta-ads-mcp-setup`.
- **Schedule posts for later.** Meta Graph API does not expose scheduled publishing for organic content. The user can use Meta Business Suite's UI scheduler, or pair this skill with a cron-based skill.
- **Post to personal Instagram accounts.** Graph API only supports Business and Creator accounts.
- **Cross-post Instagram → Facebook automatically.** This is a per-post toggle in the Instagram app and is not exposed via Graph API.
- **Create Instagram Shopping product tags.** Requires the separate Catalog API and is out of scope.
- **Access Stories highlights, archive, or close-friends list** beyond what `ig_get_media_list` returns.
- **Manage Facebook Messenger DMs** (Page-side). Only Instagram DMs are exposed.
- **Read or post to Threads private/restricted accounts** other than the connected one.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before publishing, deleting, or sending DMs.** Summarise what you're about to post (caption + hashtags + media URL or filename) and wait for the user's OK before calling the publish tool. Same for `ig_send_message`, `ig_delete_media`, `ig_delete_comment`, `threads_delete_post`.
- **Container processing is asynchronous.** After `ig_publish_video` or `ig_publish_reel`, call `ig_get_container_status` once before assuming the post is live. Same for Threads media containers via `threads_get_container_status`.
- **Never echo or log credentials.** `INSTAGRAM_ACCESS_TOKEN`, `THREADS_ACCESS_TOKEN`, `META_APP_SECRET`, and `META_APP_ID` must never appear in any output visible to the user.
- **One platform, one tool call at a time.** Do not parallel-publish to Instagram and Threads in a single batched action without confirming both with the user.
- **Format insights clearly.** When showing media insights or account insights, format as a readable summary (top metrics first), not raw JSON. Highlight surprising values.
- **Pagination.** `ig_get_media_list` and `threads_get_posts` default to a small page. Show the first page and offer to fetch more.
- **Rate limits are real.** Instagram uses a **Business Use Case (BUC) rate limit**: roughly **4,800 calls per 24-hour rolling window per impression count**. High-impression accounts get more headroom; new or quiet accounts get less. Instagram publishing has a separate cap: **100 published posts per 24 hours** (carousels count as 1). Threads: **250 publishes per day**. If the user is doing bulk work, pace it. Catch error codes 17 (user throttle) and 32 (page throttle) and back off.
- **Check token expiry before risky operations.** If the user is about to publish a multi-step Reel or carousel, optionally call `meta_debug_token` first to confirm the token has >7 days left. Avoid the publish-fails-mid-batch surprise.
- **Hashtag and `@` mentions.** Instagram captions can include hashtags and mentions, but Graph API does not validate them - typos won't error, they'll just sit dead in the caption. Spell-check before publishing.
- **Reels constraints.** Aspect ratio range **0.01:1 to 10:1** (9:16 recommended). Duration **3 seconds minimum, 15 minutes maximum**. Container **MP4 or MOV**. Video codec **H.264 or HEVC** with frame rate **23-60 FPS** and bitrate **≤25 Mbps**. Audio codec **AAC**, **≤48 kHz**, **1-2 channels**. Max file size **300 MB**. If the user provides something outside these bounds, warn before the publish call rather than letting Meta reject it.
- **Comment moderation tone.** When asked to hide or delete comments, summarise the comment text first so the user is making the decision, not Claude.
- **DM privacy.** Treat DM content as confidential. Don't include DM bodies in summaries unless the user asks. Don't suggest reading DMs proactively.
- **Single account per platform.** The connector is locked to one Instagram Business account and one Threads account per token pair. Switching accounts requires re-running Phase 1 with new tokens.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap; Phase 1 above follows the same rules.
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting Meta access tokens or Graph API errors.
- **canva-connector**: Generate the image, video, or Reel cover, then publish through this skill.
- **ad-creative**: Draft the post copy and creative concept, then publish through this skill.
- **xero-connector**: Sibling first-party-style connector - same `~/.claude.json` + restart pattern, different platform.
- **wordpress-connector**: Same `npx + ~/.claude.json` install pattern using `@rnaga/wp-mcp`.
- **(future) facebook-page-connector**: Will cover Facebook Page organic posting; not yet built.
- **(external) lukeselr/meta-ads-mcp-setup**: Covers Meta Ads. Coexists with this skill - they wrap different MCP servers and use different tokens.
