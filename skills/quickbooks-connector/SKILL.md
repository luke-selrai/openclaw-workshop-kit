---
name: quickbooks-connector
description: "Connect QuickBooks Online to Claude by installing and authenticating Intuit's official MCP server. Use when the user asks to connect or set up QuickBooks, or wants QBO work (invoices, customers, bills, bank transactions, profit and loss, balance sheet) and QuickBooks isn't connected yet. Once connected, QBO runs directly through the mcp__quickbooks__* tools."
allowed-tools: mcp__quickbooks__*, mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - quickbooks
    - qbo
    - accounting
    - invoices
    - customers
    - finance
    - mcp
    - intuit
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting QuickBooks auth or API errors
    - skill: xero-connector
      reason: Sibling accounting connector - same Playwright-driven autonomous-Phase-1 pattern (different vendor)
---

# QuickBooks Connector

## Overview

This skill lets you read and update a user's QuickBooks Online data on their behalf. It is a **thin wrapper around [`intuit/quickbooks-online-mcp-server`](https://github.com/intuit/quickbooks-online-mcp-server)** - Intuit's official Model Context Protocol server, Apache-2.0 licensed, actively maintained by Intuit's developer relations team. The server exposes 144 tools across 29 entity types (Customer, Invoice, Bill, Vendor, Estimate, Item, Account, Journal Entry, Payment, etc.) plus 11 financial reports (Balance Sheet, Profit & Loss, Cash Flow, Trial Balance, General Ledger, customer/vendor aging reports).

**US books have a one-click alternative.** QuickBooks has a listing in Claude's own connector directory (`https://claude.ai/directory/quickbooks`, display name **Intuit QuickBooks**) covering **US QuickBooks accounts**. Check this route before building the local server. **Australian and other non-US books use the kit's own route below**; keep the existing region and live/practice choice intact.

**Check the calling runtime.** Desktop's account can differ from the standalone CLI, even when commands run in Desktop's Bash. Discover QuickBooks tools in the calling session and inspect the app's Connectors view where accessible. Desktop can deliver built-in tools under `mcp__<id>__`; match by name and description, never a stored id. In terminal/VS Code, `claude mcp list` can show `claude.ai Intuit QuickBooks` and tools use `mcp__claude_ai_Intuit_QuickBooks__*`. That command and `claude auth status` describe the CLI account, not Desktop. Local QuickBooks credentials are independent of either Claude login.

**Connect the built-in for US books.** In Desktop, start with **+ → Connectors → Browse connectors → Intuit QuickBooks → Connect**. Use available computer-use tools, or give that short sequence if the app is inaccessible. Keep the exact handoff URL in a browser profile signed into the same Claude account as Desktop; use a matching or isolated profile if the everyday account differs. Preserve its parameters, never invent app deep links, and check account matching if **Continue connecting** loops before retrying; start a fresh in-app Connect if the handoff expired. For browser or terminal/VS Code setup, open `https://claude.ai/directory/quickbooks` in a browser signed into the calling Claude account; fallback: `https://claude.ai/customize/connectors` → **Browse** → **Intuit QuickBooks** → **Connect**. With only a shell, use `open` on Mac, `xdg-open` on Linux, or `start ""` on Windows after checking the browser account. Use available browser tools for authorised setup and approval; request sign-in when needed, or only the next click when a surface is inaccessible. **Request** instead of **Connect** is an administrator gate; stop there rather than using the local route to bypass it.

**Prove the built-in here.** Verify connected state in the calling account's Connectors view, then call an actual read tool such as company information in this session and confirm the intended company. Another account's CLI status or a connected badge alone is not proof. A real read is required; report errors as unproven and retain the kit route below as appropriate to the user's need. For re-authentication, choose **Reconnect** from that same account. If connected state passes but runtime tools remain absent, recheck discovery first: an in-app Connect can appear in the running Desktop session; a browser-directory Connect can require fully quitting and reopening Desktop. Terminal sessions load account connectors at start; restart that session once (VS Code: **Developer: Reload Window**) and repeat the read. Restarting cannot repair an account mismatch. A proven built-in connection needs no local install; use its discovered tools for subsequent authorised work, preserving the real-data safeguards in Phase 2.

The skill has two phases:

- **Phase 1 - Install & Auth (autonomous via Playwright).** Claude clones the Intuit MCP server to `~/.local/share/qbo-mcp/`, builds it (`npm install` + `npm run build`), drives the entire `developer.intuit.com` developer-app flow inside a Playwright MCP browser (find or create an app named "Claude Assistant", register the redirect URI, DOM-extract Client ID + Client Secret with Show-credentials toggle bracketing), writes the credentials to `~/.local/share/qbo-mcp/.env` (mode 600), runs `npm run auth` to drive the OAuth flow, and finally registers the MCP server with Claude Code via `claude mcp add quickbooks --env ... -- node ~/.local/share/qbo-mcp/dist/index.js`. Two details differ by mode: **sandbox (Phase 1S)** adds `http://localhost:8000/callback` to the app's **Development** redirect URIs and lets the bundled `auth-server.ts` listen on port 8000 for the callback; **live (Phase 1L - the default)** adds `${TUNNEL_URL}/callback` to the app's **Production** redirect URIs instead, because Intuit refuses `localhost` for Production. The user's manual moments are signing in to `developer.intuit.com` once and approving any 2FA prompt - plus, in live mode, signing in to or signing up for Cloudflare and confirming any verification email. After Phase 1 completes, the user closes and reopens Claude Code once so the `mcp__quickbooks__*` tools reconcile into the deferred-tool surface.
- **Phase 2 - Use Tools.** Once the MCP server is registered and Claude Code has reconciled, you call `mcp__quickbooks__*` tools directly - no Bash subprocess wrapping needed. This skill documents the 10 most common workshop prompt patterns. For advanced entities (bills, vendors, estimates, journal entries, budgets, etc.) the MCP server's 144-tool surface covers everything; introspect via the tool descriptions or consult [the Intuit MCP repo README](https://github.com/intuit/quickbooks-online-mcp-server) for the full tool catalogue.

**Which phase to run on the kit's own route** - If the built-in has not already met the user's need, check the local QuickBooks registration. The following command describes this machine's local server and the CLI account; it does not rule out Desktop's built-in tools:

```bash
claude mcp list 2>&1 | grep -i quickbooks
```

- A line like `quickbooks: node /home/<user>/.local/share/qbo-mcp/dist/index.js - ✓ Connected` → MCP server is registered. Run **Phase 0** to discover the mode (live vs sandbox) from the registered env and require its company-info read in this calling session before Phase 2.
- No quickbooks line → run **Phase 0** to pick a mode, then **Phase 1L** (live) or **Phase 1S** (sandbox).
- A quickbooks line followed by `✗ Failed to connect` → run Phase 0 to learn the mode, then re-run Phase 1's auth-only sub-flow for that mode (Phase 1S Step 9 for sandbox; Phase 1L sub-phase D for live - Phase 1L sub-phases A/B/C are one-time, no re-run needed).

**Live by default; sandbox is opt-in.** This skill supports both modes:

- **Live (Production-Development tier)** - connects to the participant's real QuickBooks company. Default. Each participant has their own Intuit Production app and their own Cloudflare Pages deploy hosting the four legal/landing URLs Intuit's Production Settings form requires. No SelrAI hosting. Phase 1L drives all of this via Playwright.
- **Sandbox** - connects to a practice company. Opt-in via Phase 0 prompt. Phase 1S is the existing zero-config-required sandbox install.

The MCP server itself reads `QUICKBOOKS_ENVIRONMENT` (`production` or `sandbox`) and switches its API base URL accordingly. Phase 2 tool calls are identical across modes; only the soft-gate + destructive-op confirmation behaviour changes for live (see Phase 2 below).

**App Store publishing (Intuit tier 2 - 4-6 week App Assessment) is NOT in scope.** Tier 1 (Production-Development mode, ~5-company cap, no human review, credentials issued immediately on Production Settings save) is sufficient for any participant connecting their own one QBO company. If a participant ever wants to publish their app on the QBO App Store so other QBO users can install it, that's a separate optional follow-up documented in `examples/install-walkthrough-app-store.md` (future).

**This is a Playwright-driven autonomous-Phase-1 connector** - same shape as `xero-connector`, `stripe-connector`, `github-connector`. The `skills/CLAUDE.md` install-pattern decision tree currently lists three canonical patterns (Hosted-OAuth, Hosted-bearer-PAT, Plugin-marketplace); this SKILL fits a candidate **fourth pattern**: *Vendor-published local stdio MCP* - clone + build the vendor's MCP server locally, drive their auth flow, register via `claude mcp add` with stdio command. If two or three more connectors land on this same pattern (Salesforce's `@salesforce/mcp` is the obvious next candidate), the pattern should be formalised in `skills/CLAUDE.md`.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work. In sandbox mode (Phase 1S) the user only signs in to developer.intuit.com once (and answers 2FA if challenged). In live mode (Phase 1L - the default) the list is slightly longer: they also sign in to or sign up for Cloudflare and confirm any verification email (see the Phase 1L workshop-UX recap). Everything else is still yours to drive. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to developer.intuit.com in the browser window I just opened" and (if challenged) "please approve the 2FA prompt on your phone."
- **Plain English only.** No jargon. Never say MCP, CLI, npm, npx, clone, build, repo, PATH, env var, export, OAuth, scope, token, callback, redirect URI, realmId, JSON, DOM, Playwright, stdio, server, restart, reconcile, or terminal. If you must refer to a technical thing, name it plainly: "the QuickBooks tool I need", "your browser", "a small one-time setup step on your computer".
- **Tell them what is about to happen.** Before any action: "I am going to connect QuickBooks for you - this takes about three minutes."
- **React to success and failure warmly.** Good: "That worked - your QuickBooks is now connected." Bad: "MCP server registration failed."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem - let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the Client ID, Client Secret, refresh token, or realm ID** back to the user. All four are stored locally; never include them in any output visible to the user.
- **Restart-the-chat moment.** Phase 1 ends with one specific instruction the user MUST do: close and reopen Claude Code so the new QuickBooks tools become available. Frame it warmly: *"All connected - one last step: please close this window and reopen Claude Code, then say hi. The QuickBooks tools will be ready for you."*

---

## PHASE 0 - Mode Detection (live vs sandbox)

Run Phase 0 before any Phase 1 work. It picks live or sandbox and surfaces the choice so Phase 1L vs Phase 1S can branch correctly. If the MCP server is already registered, Phase 0 derives the existing mode from `claude mcp get quickbooks` and skips the prompt.

### Step 0.1 - Discover existing mode (if registered)

```bash
EXISTING_MODE="$(claude mcp get quickbooks 2>/dev/null | awk -F= '/QUICKBOOKS_ENVIRONMENT=/ {print $2}' | head -1)"
echo "${EXISTING_MODE:-not-registered}"
```

- Output `production` or `sandbox` → MCP already registered in this mode. Tell the user warmly: *"You're already connected in [live / practice] mode - let me check it still works."* Then run a single `mcp__quickbooks__get_company_info` smoke call. On success → Phase 2 (and set `MODE=$EXISTING_MODE` for Phase 2's behavioural switches). On auth-expired error → run the auth-only sub-flow for `$EXISTING_MODE` (Phase 1S Step 9 for sandbox; Phase 1L sub-phase D for live).
- Output `not-registered` → continue to Step 0.2.

### Step 0.2 - Ask live vs sandbox

If not already registered, ask the user in one warm message:

> "Want to connect your **real QuickBooks** (your actual company data) or set up a **practice company** first to try it out? Real is the default - most business owners want real."

Map their reply:

- "real", "live", "production", "yes", "go", "connect", or no specific answer → `MODE=production` → **Phase 1L**.
- "practice", "sandbox", "test", "try first" → `MODE=sandbox` → **Phase 1S**.
- Ambiguous reply → ask once for clarification, default `MODE=production`.

Set `MODE` as a shell variable that Phase 1's downstream steps read. Do NOT say the word "sandbox" to the user during this prompt - use "practice company" (workshop UX rule from `feedback_workshop_kit_update_format`).

---

## PHASE 1S - Sandbox Install & Auth (autonomous via Playwright)

Run this branch when Phase 0 selects `MODE=sandbox`. This is the original zero-config-required sandbox flow - no Cloudflare, no Production Settings form, localhost callback URI directly.

Claude clones + builds the Intuit MCP server, drives developer.intuit.com end-to-end via Playwright MCP to set up the Intuit developer app + capture credentials + add the localhost:8000 redirect URI on the **Development** sub-tab, runs the bundled `npm run auth` flow to capture refresh tokens, and registers the MCP server with Claude Code via `claude mcp add`. The user's only role is signing in to developer.intuit.com when prompted (and only the first time - the persistent Playwright profile keeps the session for future runs) and approving any 2FA challenge their account requires.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Show credentials toggle and read the Client ID input from the same panel"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form` / `browser_select_option`. Match elements by their visible labels and `aria-label` attributes ("Show credentials", "Add URI", inputs with `aria-label="url-location"`), not by selector paths - Intuit's developer portal UI evolves.

> **Workshop-UX finding: never snapshot a sign-in page.** If you snapshot `accounts.intuit.com/app/sign-in` (or any auth page), the Playwright accessibility tree will include the literal password value when a password manager has auto-filled the field. Use `browser_wait_for({ text: "<post-auth marker>" })` to poll for the post-redirect page instead. Documented in memory `reference_playwright_snapshot_password_leak`.

### Step 1 - Check if the QuickBooks MCP server is already registered

Silently run:

```bash
claude mcp list 2>&1 | grep -i quickbooks
```

- Matches a line like `quickbooks: ... ✓ Connected` → MCP server already registered. Run a single `mcp__quickbooks__get_company_info` smoke call. If it returns data, jump to Phase 2 with success message. If it errors (auth expired), continue from Step 9 (re-auth only).
- No match → continue to Step 2.

Also check that the install directory exists:

```bash
ls -la "$HOME/.local/share/qbo-mcp/dist/index.js" 2>&1 | head -1
```

If `dist/index.js` exists, Steps 2-3 can be skipped (server already built); jump to Step 4.

### Step 2 - Install prerequisites (Node.js + git + Playwright MCP)

The Intuit MCP server is a Node.js project. The participant needs Node.js ≥ 18 and git installed. Most workshop attendees have these from earlier kit setup, but verify:

```bash
node --version 2>&1 | head -1   # expect v18+ or v20+
git --version 2>&1 | head -1     # expect git 2.x
```

If `node: command not found`:

- **macOS**: `brew install node` (install Homebrew first if not present, via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`)
- **Linux**: use the system package manager (`apt install nodejs npm`, `dnf install nodejs`, `pacman -S nodejs npm`) OR install via `nvm` (`curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && nvm install --lts`)
- **Windows (Git Bash)**: download installer from `nodejs.org` (LTS), run silently if possible. Scoop alternative: `scoop install nodejs-lts`.

If `git: command not found`: similar OS-conditional install. On Windows, git is bundled with the Git Bash environment the participant should already have per kit setup.

**Playwright MCP check.** If `mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` tools are not available in this session, install Playwright first per `skills/CLAUDE.md`'s "Cross-cutting: Playwright MCP install contingency" section:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close + reopen Claude Code, and retry. The `--user-data-dir` flag is mandatory for the persistent profile pattern.

### Step 3 - Clone + build the Intuit MCP server

Silently run, narrating to the user "Setting up the QuickBooks tool - give me about a minute":

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
mkdir -p "$(dirname "$INSTALL_DIR")"

if [ -d "$INSTALL_DIR/.git" ]; then
  # Existing install - pull latest
  cd "$INSTALL_DIR" && git pull --ff-only 2>&1 | tail -3
else
  # Fresh clone
  git clone https://github.com/intuit/quickbooks-online-mcp-server.git "$INSTALL_DIR" 2>&1 | tail -3
fi

cd "$INSTALL_DIR"
npm install 2>&1 | tail -3
npm run build 2>&1 | tail -3
```

Verify `dist/index.js` exists and is executable after the build:

```bash
ls -la "$INSTALL_DIR/dist/index.js"
```

If the build fails (npm errors, missing peer deps, TypeScript errors), translate to plain English ("Something on your computer is stopping me from setting up the QuickBooks tool. Are you on a corporate laptop that might block downloads?") and diagnose silently.

> **Why `~/.local/share/qbo-mcp`?** This is the XDG Base Directory convention (`$XDG_DATA_HOME` defaults to `~/.local/share/`) - cross-platform-safe (works on macOS, Linux, Windows Git Bash), and it keeps the clone out of the user's home directory's top level. The MCP server's runtime artifacts (logs, `.env`) all live in the same directory tree, simple to find or wipe.

### Step 4 - Open developer.intuit.com and confirm a logged-in session

Tell the user, in one short message:

> "Opening a browser window for you - please sign in to developer.intuit.com when it appears (and approve any 2FA prompt). I'll do the rest. About two minutes."

Call:

```
mcp__playwright__browser_navigate({ url: "https://developer.intuit.com/workspaces" })
```

**Do NOT snapshot the sign-in page** (password-leak risk). Instead, poll silently with:

```
mcp__playwright__browser_wait_for({ text: "Workspaces", time: 15 })
```

`browser_wait_for` returns the page text reference without exposing form-field values. If it times out (the default cap is around 30 seconds regardless of the `time` parameter), check in with the user: *"Still on the sign-in page? Anything I can help with?"* and re-poll.

Once `Workspaces` is visible, you're past the sign-in page. From here, snapshots are safe.

### Step 5 - Find or create the "Claude Assistant" app

Walk the workspace UI to either reuse an existing Claude Assistant app or create one.

**5a. Pick a workspace.** From the snapshot at `/workspaces`, locate a workspace card (e.g., "Sample Workspace" - the default one new accounts get). Click into it via `browser_click`. The URL becomes `developer.intuit.com/dashboard?id=<workspace-id>&tab=apps` and an app list appears.

If the user has zero workspaces, click **Create workspace** and follow Intuit's wizard with sensible defaults (workspace name `My Workspace`).

**5b. Find or create the app.** In the workspace's app list, look for a card whose title contains `Claude Assistant`.

- **App exists** → click into it. The URL becomes `developer.intuit.com/appdetail/overview?appId=<...>&id=<workspace-id>`. Note the `appId` (a base64-prefixed UUID, e.g., `djQuMTo6OGQzYmJlYTI3Yg:4204facc-0232-491c-842d-44c19fcc03ab`) and the workspace `id` from the URL - Step 6 / 7 navigation reuses both.
- **App does not exist** → click the `+` create-card or **Create an app** button. Intuit asks for app type - pick **QuickBooks Online and Payments**. Set the name to `Claude Assistant`. Tick the `com.intuit.quickbooks.accounting` scope. Click **Create app**. Capture the resulting `appId` from the post-create URL.

> **Robustness note.** The find-existing-app path is verified-live (this is what runs on returning users where Phase 1 has been completed before, even if Phase 1 was abandoned mid-flow). The create-new-app path was validated on a fresh Intuit account 2026-06-01 - sandbox create-app form fields match this description. Production app onboarding (security questionnaire, breach disclosures, etc.) is a separate flow Intuit only triggers when you click "Submit for App Assessment" on the Production tab; sandbox-only setup does NOT touch it.

### Step 6 - Add the localhost:8000 redirect URI on the Development tab

Navigate to the redirect URI settings:

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/settings?appId=<appId>&id=<workspaceId>&tab=redirect-uris"
})
```

`mcp__playwright__browser_wait_for({ text: "Redirect URI" })`. Take a snapshot.

The page shows two sub-tabs at the top (**Development** and **Production**) and a list of existing redirect URI inputs in the Development tabpanel. The Development tab is selected by default; verify by inspecting the snapshot and clicking the Development tab via `browser_click` if needed.

**Idempotent upsert.** Check whether `http://localhost:8000/callback` is already registered:

```js
() => {
  const tabpanel = document.querySelector('[role="tabpanel"]');
  const inputs = Array.from(tabpanel.querySelectorAll('input[aria-label="url-location"]'));
  return {
    uris: inputs.map(i => i.value),
    has_8000: inputs.some(i => i.value === 'http://localhost:8000/callback'),
  };
}
```

- **Already present** → skip to Step 7. Do not click Save.
- **Not present** → click **Add URI** to spawn a new empty `aria-label="url-location"` input. Then fill it via `browser_evaluate` using a React-friendly setter:

  ```js
  () => {
    const tabpanel = document.querySelector('[role="tabpanel"]');
    const inputs = Array.from(tabpanel.querySelectorAll('input[aria-label="url-location"]'));
    const target = inputs.find(i => !i.value || i.value === '');
    if (!target) return { ok: false, reason: 'no empty url-location input' };
    const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
    target.focus();
    setter.call(target, 'http://localhost:8000/callback');
    target.dispatchEvent(new Event('input', { bubbles: true }));
    target.dispatchEvent(new Event('change', { bubbles: true }));
    return { ok: true };
  }
  ```

  Then click **Save**. The Save button (`#edit-save-button`) may be outside the viewport; use `browser_evaluate` to scroll-and-click as a defensive pattern:

  ```js
  () => {
    const btn = document.querySelector('#edit-save-button');
    if (!btn || btn.disabled) return { ok: false };
    btn.scrollIntoView({block: 'center'});
    btn.click();
    return { ok: true };
  }
  ```

  Reload the page (`browser_navigate` to the same URL) and re-evaluate the URI list to confirm persistence - Intuit's Save flow can briefly leave the form in a dirty-but-saved state where the Save button stays enabled.

> **Why the React-friendly setter.** Intuit's redirect URI input is a controlled React component. Naive `el.value = '...'` writes the DOM value but does not fire React's `onChange` handler, so React re-renders and resets the value to its prior state on the next render. Calling the prototype's native setter and dispatching `input` + `change` events with `bubbles: true` makes React see the change and update its state. This pattern is empirically required here.

> **Multi-URI coexistence.** The user may already have other redirect URIs registered for other tools (e.g., `http://localhost:3000/callback` for a previous Next.js project, `http://localhost:8844/callback` from a prior voska/qbo-cli setup, or `https://developer.intuit.com/v2/OAuth2Playground/RedirectUrl` for the Intuit OAuth Playground). Never delete or replace existing URIs - only append. Intuit allows up to 25 per app.

> **Note on 8844 vs 8000.** The Intuit MCP server's auth-server.ts listens on port 8000 by default (configurable via `QUICKBOOKS_REDIRECT_URI`). Earlier versions of this SKILL wrapped `voska/qbo-cli` which used 8844; that's why returning users may see both ports in their redirect URI list. Both can coexist harmlessly.

### Step 7 - DOM-extract Client ID and Client Secret

Navigate to:

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/keys?appId=<appId>&id=<workspaceId>"
})
```

`mcp__playwright__browser_wait_for({ text: "Client ID" })`. Take a snapshot.

The page shows two sub-tabs (Development / Production). Development is selected by default. The Client ID and Client Secret values are masked behind a **Show credentials** toggle (a `role="switch"` named `Show credentials`).

**Bracket the toggle around the read, using clipboard-transit so the literal credential values never appear in a tool return or transcript**:

1. Save the user's existing clipboard so we can restore it after:

   ```bash
   SAVED_CLIPBOARD=$(wl-paste 2>/dev/null | base64 -w0)   # Linux/Wayland; use pbpaste on macOS, Get-Clipboard on PowerShell
   echo "$SAVED_CLIPBOARD" > /tmp/qbo-prev-clipboard.b64
   ```

2. Click the Show credentials toggle:

   ```
   mcp__playwright__browser_click({ target: 'role=switch[name="Show credentials"]' })
   ```

3. Read the values via `browser_evaluate`, write them to the clipboard, and return ONLY length metadata (no values):

   ```js
   async () => {
     const allEls = Array.from(document.querySelectorAll('*'));
     const labels = allEls.filter(el => /^client (id|secret)\s*:?$/i.test((el.innerText||'').trim()));
     const out = {};
     for (const label of labels) {
       const which = /id/i.test(label.innerText) ? 'client_id' : 'client_secret';
       if (out[which]) continue;
       let candidate = label.parentElement;
       for (let depth = 0; depth < 6 && candidate; depth++) {
         const inputs = Array.from(candidate.querySelectorAll('input'));
         const v = inputs.map(i => i.value).find(v => v && v.length > 10);
         if (v) { out[which] = v; break; }
         const lines = (candidate.innerText || '').trim().split('\n').map(s => s.trim()).filter(Boolean);
         const credLine = lines.find(l => l.length > 20 && /^[A-Za-z0-9_\-\.]+$/.test(l));
         if (credLine) { out[which] = credLine; break; }
         candidate = candidate.parentElement;
       }
     }
     if (!out.client_id || !out.client_secret) return { ok: false, found: Object.keys(out) };
     try {
       await navigator.clipboard.writeText(JSON.stringify({ client_id: out.client_id, client_secret: out.client_secret }));
       return { ok: true, client_id_len: out.client_id.length, client_secret_len: out.client_secret.length };
     } catch (err) {
       return { ok: false, reason: 'clipboard_write_failed', message: String(err.message || err) };
     }
   }
   ```

4. Click the Show credentials toggle a second time to hide them again.

**Validation (silent).** Client ID is typically ~50 characters, alphanumeric. Client Secret is typically 40 characters, alphanumeric. Both are URL-safe (`[A-Za-z0-9_\-\.]+`). If either field is empty or fails this shape check, re-snapshot, ensure the Development tab (not Production) is selected, retry once.

**Conversational fallback.** If two extract attempts don't surface valid credentials (e.g., Intuit has moved the values to a non-DOM-readable widget on this account), narrate once: *"I'm having trouble reading the credentials automatically - could you paste your Client ID and Client Secret for me?"* Wait for the user to paste, validate the shape, and continue. The credentials transit the transcript in this fallback path; that's an accepted trade-off.

### Step 8 - Write `.env` to the MCP install dir (silent)

The Intuit MCP server reads its config from `<install-dir>/.env`. The `.env` needs CLIENT_ID + CLIENT_SECRET upfront so the next step (`npm run auth`) can run. REFRESH_TOKEN + REALM_ID are written by `npm run auth` itself on success.

Silently run, reading credentials from the clipboard (set in Step 7):

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
mkdir -p "$INSTALL_DIR"
umask 077

# Read CLIENT_ID + CLIENT_SECRET from clipboard via jq (no values exposed)
CLIENT_ID="$(wl-paste | jq -r '.client_id')"
CLIENT_SECRET="$(wl-paste | jq -r '.client_secret')"

cat > "$INSTALL_DIR/.env" <<EOF
QUICKBOOKS_CLIENT_ID=${CLIENT_ID}
QUICKBOOKS_CLIENT_SECRET=${CLIENT_SECRET}
QUICKBOOKS_REDIRECT_URI=http://localhost:8000/callback
QUICKBOOKS_ENVIRONMENT=sandbox
EOF
chmod 600 "$INSTALL_DIR/.env"

# Restore the user's original clipboard
base64 -d /tmp/qbo-prev-clipboard.b64 | wl-copy
rm -f /tmp/qbo-prev-clipboard.b64

unset CLIENT_ID CLIENT_SECRET
```

> **Cross-platform clipboard tools.** Linux/Wayland uses `wl-paste` / `wl-copy`. Linux/X11 uses `xclip -selection clipboard -o` / `xclip -selection clipboard -i`. macOS uses `pbpaste` / `pbcopy`. Windows (Git Bash) uses `powershell.exe Get-Clipboard` / `powershell.exe Set-Clipboard`. Detect at runtime and use the appropriate pair.

> **No rc-file marker block.** Unlike the prior voska/qbo-cli SKILL, this version does NOT write to the user's shell startup file. The env vars travel via `claude mcp add --env ...` in Step 10 - Claude Code stores them inside `~/.claude.json`'s `mcpServers.quickbooks.env`, scoped to the MCP server's runtime only. The participant's interactive shells stay clean.

Never echo the captured values back to the user. Never include them in any output visible to the user.

### Step 9 - Run `npm run auth` and capture refresh token

The Intuit MCP server ships a bundled OAuth helper at `src/auth-server.ts` (compiled to `dist/auth-server.js`). Run it in the background; it spawns a local web server on port 8000, prints the OAuth URL to stdout, waits for the callback, exchanges the code for tokens, writes REFRESH_TOKEN + REALM_ID to `.env`, and exits 0.

**Tell the user:** *"Connecting to QuickBooks now - this takes about ten seconds."*

Launch:

```bash
cd "$HOME/.local/share/qbo-mcp"
rm -f /tmp/qbo-mcp-auth.log
exec npm run auth > /tmp/qbo-mcp-auth.log 2>&1
```

(Run in the background - use the Bash tool's `run_in_background: true` option.)

After ~3 seconds, read the auth URL from the log:

```bash
sleep 3
AUTH_URL="$(grep -oE 'https://appcenter\.intuit\.com/connect/oauth2[^[:space:]]+' /tmp/qbo-mcp-auth.log | head -1)"
```

If `AUTH_URL` is empty, the auth-server has likely errored; `cat /tmp/qbo-mcp-auth.log` to diagnose. Common cause: missing CLIENT_ID/CLIENT_SECRET in `.env` (re-do Step 8).

**Drive Playwright through the consent flow.** Navigate to the auth URL:

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Take a `browser_snapshot`. Three possible states (same as the prior SKILL's Step 9):

- **Auto-redirect to `localhost:8000/callback`** (fast - under a second; happens when the persistent Playwright profile already has Intuit consent for this app) → the auth-server catches the redirect; the page shows "✓ Successfully connected to QuickBooks!". Skip to the wait-for-success step below.
- **Sandbox company picker** (a list of practice companies the user has access to) → click the first sandbox company.
- **Connect / Authorize button visible** ("Connect", "Allow access", "Authorize") → DOM-extract and click via `browser_evaluate`:

  ```js
  () => {
    const btns = Array.from(document.querySelectorAll('button, a'));
    const target = btns.find(b => /^(connect|authorize|allow)( access)?$/i.test((b.innerText||'').trim()));
    if (target) { target.scrollIntoView({block:'center'}); target.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

**Wait for the auth-server to write tokens to .env.** Poll the log until you see `Tokens have been saved to your .env file`:

```bash
for i in $(seq 1 30); do
  if grep -q 'Tokens have been saved' /tmp/qbo-mcp-auth.log; then break; fi
  sleep 1
done
```

If the loop times out without success, read the full log for the actual error and diagnose. Common causes:

- The `http://localhost:8000/callback` redirect URI is NOT registered in the Intuit app (re-check Step 6 ran and saved).
- The participant cancelled the consent flow in Playwright.
- Port 8000 was already in use by another process (uncommon but possible - `ss -tlnp | grep ':8000'` to check).

**Verify .env now has all 6 keys:**

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
awk -F= '/^QUICKBOOKS_/ {key=$1; val_len=length($0) - length(key) - 1; printf "  %s: %s\n", key, (val_len>0 ? "SET" : "EMPTY")}' "$INSTALL_DIR/.env"
```

Expect all six: `CLIENT_ID`, `CLIENT_SECRET`, `REDIRECT_URI`, `ENVIRONMENT`, `REFRESH_TOKEN`, `REALM_ID` - each SET.

### Step 10 - Register the MCP server with Claude Code

Now that the .env has all credentials, register the MCP server with Claude Code. The registration command runs `claude mcp add` with all env vars passed via `--env KEY=value` flags. **Important: redirect stdout to `/dev/null`** - `claude mcp add` v2.1.x prints `--env` and `--header` values verbatim on stdout (see memory `reference_claude_mcp_add_token_echo`).

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
cd "$INSTALL_DIR"
set -a; . ./.env; set +a

claude mcp add quickbooks --scope user \
  --env "QUICKBOOKS_CLIENT_ID=$QUICKBOOKS_CLIENT_ID" \
  --env "QUICKBOOKS_CLIENT_SECRET=$QUICKBOOKS_CLIENT_SECRET" \
  --env "QUICKBOOKS_REFRESH_TOKEN=$QUICKBOOKS_REFRESH_TOKEN" \
  --env "QUICKBOOKS_REALM_ID=$QUICKBOOKS_REALM_ID" \
  --env "QUICKBOOKS_REDIRECT_URI=$QUICKBOOKS_REDIRECT_URI" \
  --env "QUICKBOOKS_ENVIRONMENT=$QUICKBOOKS_ENVIRONMENT" \
  -- node "$INSTALL_DIR/dist/index.js" >/dev/null 2>&1
```

Verify registration:

```bash
claude mcp list 2>&1 | grep -iE 'quickbooks'
```

Expect a line like `quickbooks: node /home/<user>/.local/share/qbo-mcp/dist/index.js - ✓ Connected`. If `✗ Failed to connect`, the .env values may be wrong; re-run Step 9.

### Step 11 - Ask the user to restart Claude Code

The `mcp__quickbooks__*` tools only appear in the deferred-tool surface after Claude Code's MCP runtime reconciles the new server. This requires a Claude Code restart.

Tell the user, in one short warm message:

> "All connected - one last step: please close this window and reopen Claude Code, then say hi. The QuickBooks tools will be ready for you."

Save to memory that the QuickBooks MCP server is installed and authenticated, so on the next session you go straight to Phase 2.

### Step 12 - Verify after restart (Phase 0 on the next session)

The next time the participant invokes anything QuickBooks-related, the SKILL's Phase 0 check runs:

```bash
claude mcp list 2>&1 | grep -i quickbooks
```

If `✓ Connected` and `mcp__quickbooks__*` tools are visible (use `ToolSearch +quickbooks` to confirm), run a smoke call to verify the auth still works:

```
mcp__quickbooks__get_company_info({})
```

Expect a JSON response with `CompanyInfo` containing the sandbox company's name (e.g., "Sandbox Company AU e43d"). On success, tell the user:

> "All done - I'm now connected to your QuickBooks practice company **[company name]**. You can ask me things like *'show me my recent invoices'* or *'what's my profit and loss this month?'*."

If the smoke call errors with `auth_expired` or similar, re-run Phase 1 from Step 9 (re-auth only - clone + build + dev-portal walk are unchanged).

---

## PHASE 1L - Live Install & Auth (autonomous via Playwright)

Run this branch when Phase 0 selects `MODE=production`. Connects to the participant's real QuickBooks company. Five sub-phases:

- **1L-A** - Cloudflare onboarding: wrangler install + login + Pages deploy of the four legal/landing HTML templates (`assets/legal/{launch,disconnect,eula,privacy}.html`) from this SKILL.
- **1L-B** - Intuit Production app creation and navigation: same find-or-create as Phase 1S Step 5 but navigates to the **Production** Settings tab.
- **1L-C** - Production Settings form fill: Playwright fills 5 URL fields with the participant's own Pages URLs (NOT SelrAI URLs), saves, waits for Intuit to issue Production credentials.
- **1L-D** - OAuth tunnel + auth: Cloudflare quick tunnel for the callback only, Playwright drives Production consent flow.
- **1L-E** - MCP register with `QUICKBOOKS_ENVIRONMENT=production` + restart prompt + smoke.

Phase 1L assumes Phase 1S Steps 2 (prereqs: Node ≥ 18, git, Playwright MCP) and 3 (clone + build the Intuit MCP server) have ALREADY RUN - these are mode-agnostic and reused as-is. Skip to Step 1L-A if those are complete; otherwise run Phase 1S Steps 2-3 first.

> **Workshop-UX recap.** The communication rules from the top of this SKILL apply throughout: plain English, no jargon, never ask the user to click menus or paste values in the happy path. The user's only manual moments in Phase 1L are: signing in to (or signing up for) Cloudflare, signing in to (or signing up for) developer.intuit.com, and any verification-email step Cloudflare/Intuit requires for new accounts. Playwright drives everything else.

### Step 1L-A - Cloudflare onboarding (wrangler install + login + Pages deploy)

Cloudflare hosts the four small HTML pages whose URLs go into Intuit's Production Settings form. Each participant deploys to their **own** Cloudflare Pages account - SelrAI hosts nothing.

#### 1L-A.1 - Install wrangler if absent

Silently run, narrating to the user "Setting up where your QuickBooks app stores its legal pages - about a minute":

```bash
if ! command -v wrangler >/dev/null 2>&1; then
  npm install -g wrangler 2>&1 | tail -3
fi
wrangler --version 2>&1 | head -1
```

If the global install fails (permission denied on Linux/macOS without sudo, or Windows path issues), fall back to `npx wrangler` for the remaining steps - slower per-call but no install required.

#### 1L-A.2 - Cloudflare login

```bash
wrangler whoami 2>&1 | tail -3
```

- If output contains `You are logged in` → skip to 1L-A.3.
- If output contains `You are not authenticated` → run the OAuth flow:

  ```bash
  rm -f /tmp/wrangler-login.log
  exec wrangler login > /tmp/wrangler-login.log 2>&1
  ```
  (Run in the background - `run_in_background: true`.)

  After ~3 seconds, extract the auth URL from the log and navigate Playwright to it:

  ```bash
  sleep 3
  CF_AUTH_URL="$(grep -oE 'https://dash\.cloudflare\.com/oauth2/auth[^[:space:]]+' /tmp/wrangler-login.log | head -1)"
  ```

  ```
  mcp__playwright__browser_navigate({ url: "<CF_AUTH_URL>" })
  ```

  Three states the page can be in:

  - **Already logged in** → page auto-redirects to a Cloudflare "Authorize wrangler" consent screen. Playwright clicks the **Allow** button (`role=button[name=/^Allow$/i]`).
  - **Cloudflare sign-in page** → tell the user: *"Please sign in to your Cloudflare account in the browser window - I'll continue once you're in."* Use `browser_wait_for({ text: "Authorize" })` to detect the post-sign-in consent screen (NOT `browser_snapshot` on the sign-in page - same password-leak risk as Intuit, see `reference_playwright_snapshot_password_leak`). Then click **Allow**.
  - **Sign-up page** → tell the user: *"You don't have a Cloudflare account yet - please create one in the browser window (the free tier is fine), confirm the verification email, and let me know when you're signed in. I'll continue from there."* Wait for the user's reply. Then re-navigate to `<CF_AUTH_URL>` and click **Allow**.

  After **Allow**, the browser shows a success page and `wrangler login` exits 0. Confirm:

  ```bash
  wrangler whoami 2>&1 | grep -E '(logged in|email)' | head -1
  ```

#### 1L-A.3 - Build the legal-pages directory from SKILL assets

The SKILL ships four HTML templates at `skills/quickbooks-connector/assets/legal/{launch,disconnect,eula,privacy}.html`. Copy them into a working dir with the URL-path structure Intuit's form expects:

```bash
SKILL_DIR="$(dirname "$(find ~/.claude ~/.config -path '*/skills/quickbooks-connector/SKILL.md' 2>/dev/null | head -1)")"
# Fallback: if not in a plugin cache, try the workshop kit repo location
if [ -z "$SKILL_DIR" ] || [ ! -d "$SKILL_DIR/assets/legal" ]; then
  SKILL_DIR="$(find "$HOME" -maxdepth 8 -type d -name quickbooks-connector -path '*/skills/*' 2>/dev/null | head -1)"
fi

LEGAL_SRC="$SKILL_DIR/assets/legal"
SLUG="qbo-legal-$(date +%s | tail -c 7)$RANDOM"
PAGES_DIR="$HOME/.local/share/qbo-mcp/pages-$SLUG"

mkdir -p "$PAGES_DIR/legal" "$PAGES_DIR/qbo"
cp "$LEGAL_SRC/eula.html"       "$PAGES_DIR/legal/eula.html"
cp "$LEGAL_SRC/privacy.html"    "$PAGES_DIR/legal/privacy.html"
cp "$LEGAL_SRC/launch.html"     "$PAGES_DIR/qbo/launch.html"
cp "$LEGAL_SRC/disconnect.html" "$PAGES_DIR/qbo/disconnect.html"

ls -la "$PAGES_DIR/legal/" "$PAGES_DIR/qbo/"
```

`SLUG` is a unique-ish per-install identifier (Pages project names must be unique within a Cloudflare account). The `qbo-legal-<slug>` naming makes the project's purpose obvious in the Cloudflare dashboard.

#### 1L-A.4 - Deploy to Cloudflare Pages

```bash
wrangler pages deploy "$PAGES_DIR" --project-name="$SLUG" --branch=main 2>&1 | tee /tmp/wrangler-pages-deploy.log | tail -10
```

On success, the log contains a per-deploy URL like `https://<deploy-id>.<slug>.pages.dev` AND a stable project alias `https://<slug>.pages.dev`. The Intuit form needs the stable alias, which is deterministic from the `$SLUG` we set in 1L-A.3 - construct it directly instead of parsing the log:

```bash
PAGES_URL="https://${SLUG}.pages.dev"
echo "$PAGES_URL"
```

(Cloudflare Pages always exposes `https://<project-name>.pages.dev` as the stable alias for the project's production branch; we set `--branch=main` in 1L-A.4 so the production-branch alias is what we get.)

#### 1L-A.5 - Smoke-test all 4 URLs

```bash
for path in /legal/eula.html /legal/privacy.html /qbo/launch.html /qbo/disconnect.html; do
  code="$(curl -sI -o /dev/null -w '%{http_code}' "$PAGES_URL$path")"
  echo "$PAGES_URL$path -> $code"
done
```

All four should return `200`. If any return `404`, the deploy didn't pick up the file - re-run the deploy with the `--commit-dirty=true` flag, or check `ls -la "$PAGES_DIR/legal" "$PAGES_DIR/qbo"` for missing files.

Pages takes ~5-15 seconds to propagate the first time; if any URL returns `522` or `523`, sleep 10 and retry once.

> **Why per-install slug.** Cloudflare Pages project names are unique within an account. A returning participant who has already done Phase 1L still has a working Pages project from the prior run - those URLs are reusable forever (Pages keeps deploys live until you delete the project). Phase 0 catches this case via the MCP-registered branch; we only land in 1L-A when no prior registration exists. The new slug per fresh install is therefore safe AND prevents accidental collision when the participant's Cloudflare account has many projects.

### Step 1L-B - Find or create the Intuit Production app

Mostly the same as Phase 1S Steps 4 and 5 with one key change: we set up the app's **Production** Settings tab, not Development.

#### 1L-B.1 - Sign in to developer.intuit.com

Identical to Phase 1S Step 4. **Do not snapshot the sign-in page.** Use `browser_wait_for({ text: "Workspaces" })` to detect post-sign-in.

If the participant doesn't have an Intuit developer account, tell them: *"You'll need an Intuit developer account - please sign up in the browser window (it's free), confirm any verification email, and let me know when you're at the Workspaces page."* Wait for their reply, then continue.

#### 1L-B.2 - Find or create the "Claude Assistant" app

Identical to Phase 1S Step 5 logic. Reuse if the app already exists from a prior install. Note the `appId` and workspace `id` from the post-create URL.

#### 1L-B.3 - Navigate to the Production Settings tab

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/settings?appId=<appId>&id=<workspaceId>&tab=production"
})
```

`mcp__playwright__browser_wait_for({ text: "Production app settings" })`. Take a snapshot.

Two states the page can be in:

- **Production Settings already filled** (Pages URLs from a prior 1L install present in all 5 fields) → skip to Step 1L-D.
- **Production Settings empty** (or partially filled with old/missing URLs) → continue to Step 1L-C.

### Step 1L-C - Fill the Production Settings form (Playwright-driven)

Intuit's Production Settings form has 5 required URL fields plus industry/regulated questions. Each participant's form references their own Pages URLs from Step 1L-A.

#### 1L-C.1 - Fill the 5 URL fields

The form fields and their target values:

| Field name (visible label) | Form input identifier | Value to type |
|---|---|---|
| Host domain | `aria-label="host-domain"` or `name="host_domain"` | `<slug>.pages.dev` (no scheme) |
| App URL (Launch URL) | `aria-label="launch-url"` | `${PAGES_URL}/qbo/launch.html` |
| Disconnect Landing Page URL | `aria-label="disconnect-url"` | `${PAGES_URL}/qbo/disconnect.html` |
| End User License Agreement (EULA) URL | `aria-label="eula-url"` | `${PAGES_URL}/legal/eula.html` |
| Privacy Policy URL | `aria-label="privacy-policy-url"` | `${PAGES_URL}/legal/privacy.html` |

Field identifiers are best-effort - verify against the page snapshot before relying on a specific `aria-label`. Intuit's UI evolves; match by visible label as primary.

Use the **React-friendly setter** pattern from Phase 1S Step 6 (controlled-component setter + dispatch `input`/`change` events). Naive `el.value = '...'` does NOT work on Intuit's React inputs.

```js
(fieldLabel, value) => {
  const labels = Array.from(document.querySelectorAll('label, div, span, p'));
  const labelEl = labels.find(el => new RegExp(`^${fieldLabel}`, 'i').test((el.innerText||'').trim()));
  if (!labelEl) return { ok: false, reason: `no label for ${fieldLabel}` };
  // Find the input that follows this label
  let scope = labelEl.parentElement;
  for (let depth = 0; depth < 4 && scope; depth++) {
    const input = scope.querySelector('input[type="text"], input[type="url"], input:not([type])');
    if (input) {
      const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
      input.focus();
      setter.call(input, value);
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      input.blur();
      return { ok: true, value_len: value.length };
    }
    scope = scope.parentElement;
  }
  return { ok: false, reason: 'no input found near label' };
}
```

Call once per field (5 invocations) with the label and value from the table above.

#### 1L-C.2 - Answer the industry questions

Intuit asks one or two questions about regulated industries (healthcare, financial services, gambling, etc.). For a workshop-scope connector, defaults of **No** are correct.

Walk each question via `browser_evaluate` to select the "No" radio button:

```js
() => {
  const noRadios = Array.from(document.querySelectorAll('input[type="radio"]'))
    .filter(r => /\bno\b/i.test(r.value || r.getAttribute('aria-label') || ''));
  noRadios.forEach(r => {
    if (!r.checked) {
      r.click();
      r.dispatchEvent(new Event('change', { bubbles: true }));
    }
  });
  return { clicked: noRadios.length };
}
```

If the participant's app is for a regulated industry, surface the questions to them in plain English first: *"Intuit asks if your business is in healthcare, financial services, or gambling. Default is 'no' - say so unless any of those apply."*

#### 1L-C.3 - Save the form

The Save button is typically at the bottom and may be outside the viewport.

```js
() => {
  const btn = Array.from(document.querySelectorAll('button')).find(b => /^save( settings)?$/i.test((b.innerText||'').trim()));
  if (!btn || btn.disabled) return { ok: false };
  btn.scrollIntoView({block: 'center'});
  btn.click();
  return { ok: true };
}
```

Wait for the post-save confirmation:

```
mcp__playwright__browser_wait_for({ text: "Production credentials" })
```

(Or whatever text Intuit shows on save success - verify via snapshot if the wait times out.)

#### 1L-C.4 - Optional: ask about App Store submission

After Production credentials are issued, the Production tab typically shows a **Submit for App Assessment** button (this triggers Intuit's 4-6 week review for App Store publishing). For workshop participants connecting their own QBO company, this is NOT needed.

Tell the user, in one short message:

> "You're now able to connect QuickBooks. Optional: you can also list this app on the QuickBooks App Store so other QuickBooks users can install it - that's a 4-6 week review process by Intuit. Most people skip it. Should I submit it for you, or skip and proceed to connecting your QuickBooks?"

Default: skip. Only run the submission flow if the participant explicitly opts in (covered in `examples/install-walkthrough-app-store.md`, future).

### Step 1L-D - OAuth tunnel + Production credentials + auth

Like Phase 1S Steps 6-9, but on the **Production** sub-tab and using a Cloudflare quick tunnel for the HTTPS callback URL (Intuit refuses `localhost` for Production redirect URIs).

#### 1L-D.1 - Start the Cloudflare quick tunnel

Detect `cloudflared` and install if absent:

```bash
if ! command -v cloudflared >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)  brew install cloudflared 2>&1 | tail -3 ;;
    Linux)   curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null && echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/cloudflared.list && sudo apt-get update && sudo apt-get install -y cloudflared ;;
    MINGW*|MSYS*|CYGWIN*)  scoop install cloudflared 2>&1 | tail -3 ;;
  esac
fi
cloudflared --version | head -1
```

If sudo is required, surface to the user: *"I need to install a small tool called Cloudflared (free, from Cloudflare) so QuickBooks can connect securely. May I install it? It'll need your computer password."* - wait for OK, then proceed.

Start the tunnel:

```bash
rm -f /tmp/qbo-tunnel.log
exec cloudflared tunnel --url http://localhost:8000 > /tmp/qbo-tunnel.log 2>&1
```

(Run in the background.)

Wait for the tunnel URL to appear:

```bash
TUNNEL_URL=""
for i in $(seq 1 30); do
  TUNNEL_URL="$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/qbo-tunnel.log | head -1)"
  if [ -n "$TUNNEL_URL" ]; then break; fi
  sleep 1
done
echo "${TUNNEL_URL:-NO_TUNNEL}"
```

If `TUNNEL_URL` is empty after 30 seconds, read `/tmp/qbo-tunnel.log` and surface to the user in plain English: *"Cloudflared isn't connecting - your network might be blocking it. Can you check if your work VPN is on?"*

#### 1L-D.2 - Add the tunnel URL to the Production redirect URIs

Same pattern as Phase 1S Step 6 (React-friendly setter, Add URI button, Save), but:

- Navigate to the redirect URIs page and click the **Production** sub-tab BEFORE adding the URI. The sub-tab switcher is a `role="tab"` named `Production`.
- Add `${TUNNEL_URL}/callback` (NOT `http://localhost:8000/callback`).
- **Prune step**: before saving, scan the existing URIs and remove any `*.trycloudflare.com/callback` entries OLDER than the current run (regex match on the hostname, keep last 5). This prevents the URI list from growing unbounded over repeat runs.

```js
() => {
  const tabpanel = document.querySelector('[role="tabpanel"]');
  const inputs = Array.from(tabpanel.querySelectorAll('input[aria-label="url-location"]'));
  const stale = inputs.filter(i => /\.trycloudflare\.com\/callback/.test(i.value));
  // Keep the most-recent 5; remove the rest by finding their adjacent remove buttons
  if (stale.length > 4) {
    const toRemove = stale.slice(0, stale.length - 4);
    toRemove.forEach(input => {
      const row = input.closest('[role="row"], li, .uri-row, div');
      const removeBtn = row && Array.from(row.querySelectorAll('button')).find(b => /remove|delete|trash/i.test(b.ariaLabel || b.innerText || ''));
      if (removeBtn) removeBtn.click();
    });
    return { pruned: toRemove.length };
  }
  return { pruned: 0 };
}
```

#### 1L-D.3 - DOM-extract Production credentials

Same as Phase 1S Step 7, but on the **Production** sub-tab of `/appdetail/keys`:

```
mcp__playwright__browser_navigate({ url: "https://developer.intuit.com/appdetail/keys?appId=<appId>&id=<workspaceId>&tab=production" })
```

Wait for `Client ID`, click the Production-tab Show credentials toggle, run the clipboard-transit extract (return lengths only), click the toggle again to hide. Identical script as Phase 1S Step 7.

#### 1L-D.4 - Write `.env` for live mode

Same as Phase 1S Step 8 but with three different values:

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
mkdir -p "$INSTALL_DIR"
umask 077

CLIENT_ID="$(wl-paste | jq -r '.client_id')"
CLIENT_SECRET="$(wl-paste | jq -r '.client_secret')"

cat > "$INSTALL_DIR/.env" <<EOF
QUICKBOOKS_CLIENT_ID=${CLIENT_ID}
QUICKBOOKS_CLIENT_SECRET=${CLIENT_SECRET}
QUICKBOOKS_REDIRECT_URI=${TUNNEL_URL}/callback
QUICKBOOKS_ENVIRONMENT=production
EOF
chmod 600 "$INSTALL_DIR/.env"

base64 -d /tmp/qbo-prev-clipboard.b64 | wl-copy 2>/dev/null
rm -f /tmp/qbo-prev-clipboard.b64
unset CLIENT_ID CLIENT_SECRET
```

Key deltas vs Phase 1S Step 8:
- `QUICKBOOKS_REDIRECT_URI` is the tunnel URL, not `http://localhost:8000/callback`.
- `QUICKBOOKS_ENVIRONMENT=production` (sandbox would be `sandbox`).

#### 1L-D.5 - Run `npm run auth` and drive Production consent

Same as Phase 1S Step 9. The auth-server reads `QUICKBOOKS_REDIRECT_URI` from .env (verified in `src/clients/quickbooks-client.ts:38`) and emits the consent URL with the tunnel host. Playwright drives the consent - but on the **production** OAuth endpoint, not sandbox.

Two practical differences in the consent flow:

- **No company picker**: production OAuth presents a list of the participant's REAL QBO companies (not sandbox practice companies). If the participant has multiple companies, they choose which one to connect.
- **Real authorization screen**: the copy reads "**[Participant's company name]** will allow Claude Assistant to: view and edit your data". Playwright clicks Connect/Allow as usual.

Wait for tokens written, verify all 6 .env keys are set, same as Phase 1S Step 9.

#### 1L-D.6 - Tear down the tunnel

After tokens captured:

```bash
TUNNEL_PID="$(pgrep -f 'cloudflared tunnel --url http://localhost:8000' | head -1)"
[ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID"
```

Then rewrite `QUICKBOOKS_REDIRECT_URI` in .env back to `http://localhost:8000/callback` as a placeholder. Future re-auth (if the 100-day refresh token eventually expires) re-runs Phase 1L sub-phase D with a fresh tunnel anyway, so the placeholder is purely cosmetic - but it keeps the .env coherent.

```bash
sed -i.bak 's|^QUICKBOOKS_REDIRECT_URI=.*|QUICKBOOKS_REDIRECT_URI=http://localhost:8000/callback|' "$HOME/.local/share/qbo-mcp/.env"
rm -f "$HOME/.local/share/qbo-mcp/.env.bak"
```

(`sed -i` works on Linux; on macOS use `sed -i ''`; the .bak/rm pattern is portable.)

### Step 1L-E - Register the MCP server and prompt restart

Same as Phase 1S Steps 10-12, but with `QUICKBOOKS_ENVIRONMENT=production` in the `--env` list:

```bash
INSTALL_DIR="$HOME/.local/share/qbo-mcp"
cd "$INSTALL_DIR"
set -a; . ./.env; set +a

claude mcp add quickbooks --scope user \
  --env "QUICKBOOKS_CLIENT_ID=$QUICKBOOKS_CLIENT_ID" \
  --env "QUICKBOOKS_CLIENT_SECRET=$QUICKBOOKS_CLIENT_SECRET" \
  --env "QUICKBOOKS_REFRESH_TOKEN=$QUICKBOOKS_REFRESH_TOKEN" \
  --env "QUICKBOOKS_REALM_ID=$QUICKBOOKS_REALM_ID" \
  --env "QUICKBOOKS_REDIRECT_URI=$QUICKBOOKS_REDIRECT_URI" \
  --env "QUICKBOOKS_ENVIRONMENT=production" \
  -- node "$INSTALL_DIR/dist/index.js" >/dev/null 2>&1
```

Verify with `claude mcp list 2>&1 | grep quickbooks` (expect `✓ Connected`), then prompt the participant to restart Claude Code:

> "All set - your QuickBooks is now connected to your real company data. One last step: please close this window and reopen Claude Code, then say hi. I'll show you your live QuickBooks once you're back."

Save a memory marker that QuickBooks is installed in **live mode** so the next session's Phase 0 picks `production` from `claude mcp get quickbooks` and goes straight to Phase 2 with the live-mode behavioural switches on.

### Phase 1L re-auth (when refresh token expires)

Intuit refresh tokens have a rolling ~100-day lifetime. When Phase 2 returns `auth_expired`, re-run **only Phase 1L sub-phase D** - sub-phases A (Cloudflare Pages still alive), B (Intuit app already exists), C (Production Settings already filled) are one-time and not re-run. The tunnel is per-run.

---

## PHASE 2 - Use Tools

Once Phase 1 is complete and Claude Code has been restarted, the `mcp__quickbooks__*` tools are available. There are 144 of them across 29 entities + 11 reports - far more than the 10 most-common patterns documented here. For advanced operations, introspect via the tool descriptions in your deferred-tool surface (search via `ToolSearch +quickbooks`), or consult [the Intuit MCP repo README](https://github.com/intuit/quickbooks-online-mcp-server) for the full tool catalogue.

**Mode awareness (set at session start).** Read `QUICKBOOKS_ENVIRONMENT` from the registered MCP config - `claude mcp get quickbooks | grep QUICKBOOKS_ENVIRONMENT` - and remember the value for the session as `MODE`. Phase 2 behaviour switches on `MODE`:

- **`MODE=production` (live):** every tool call operates on the participant's **real** company data. The two production-mode gates below apply.
- **`MODE=sandbox` (practice):** every tool call operates on a practice company. Use the word "practice company" with the user, never "sandbox" (workshop UX rule). If the user says "real numbers" or "live data", offer to re-run Phase 1L to switch - don't pretend sandbox is live.

### Production-mode gate 1 - Soft "real-data" confirmation on first invocation

On the **first** Phase 2 tool call of any session where `MODE=production`, do NOT call the requested tool immediately. Instead:

1. Call `mcp__quickbooks__get_company_info({})` first, silently.
2. Extract `CompanyInfo.CompanyName` from the response.
3. Tell the user, in one short message:

   > "Just confirming - you're connected to your real QuickBooks company **[CompanyName]**. Anything I do here will hit your live data. OK to proceed with **[summary of what they asked]**?"

4. Wait for the user's OK. Then proceed with the original tool call.

Apply this gate ONCE per session, not per tool call. Once the user has confirmed for the session, subsequent reads (search, get) proceed silently; subsequent writes still trigger Gate 2 below.

### Production-mode gate 2 - Destructive-op confirmation

For every `create_*` / `update_*` / `delete_*` tool call when `MODE=production`, confirm in plain English BEFORE invoking the tool:

| Operation | Example confirmation prompt |
|---|---|
| `create_invoice` | "I'm about to create a real invoice for **[Customer]** for **$[Amount]**, due **[DueDate]**. This will appear in your QuickBooks immediately. OK?" |
| `update_invoice` | "I'm about to update invoice **[DocNumber]** - changing [field] from [old] to [new]. This will save to your QuickBooks. OK?" |
| `delete_invoice` | "I'm about to **delete** invoice **[DocNumber]** for **[Customer]** (**$[TotalAmt]**). This can't be undone from here - you'd have to recreate it. Are you sure?" |
| `create_customer` | "I'm about to add a new customer **[DisplayName]** to your QuickBooks. OK?" |
| `update_customer` | "I'm about to update **[DisplayName]**'s [field] from [old] to [new]. OK?" |
| `delete_customer` | "I'm about to **delete** customer **[DisplayName]** from your QuickBooks. They have **[N]** invoices that will become orphaned. Are you sure?" |
| `create_bill` / `update_bill` / `delete_bill` | Similar phrasing - name the vendor, amount, date. |
| `create_*` / `update_*` / `delete_*` for other entities | Same pattern: name the operation in plain English, name the key fields, ask for OK. |

The gate is **per write call**, not per session. A read after a confirmed write does NOT re-trigger the gate; the next write does.

The MCP server itself does NOT enforce these gates - this is SKILL-prose enforcement. Claude reads the SKILL at session start and applies them. If a future participant configures `QUICKBOOKS_DISABLE_WRITE=true` (read-only mode), Gate 2 becomes moot for the disabled categories.

**`MODE=sandbox` does not trigger either gate.** Practice-company writes are not confirmed - they're a learning sandbox.

### Common Pattern 1 - List recent invoices

```
mcp__quickbooks__search_invoices({ limit: 20 })
```

Returns an array of invoice objects. Fields of interest: `Id`, `DocNumber`, `CustomerRef.name`, `TxnDate`, `DueDate`, `TotalAmt`, `Balance`, `CurrencyRef.value`.

**Use when:** The user asks "show me my invoices", "recent invoices", "latest invoices".

### Common Pattern 2 - List unpaid / overdue invoices

```
mcp__quickbooks__search_invoices({ where: "Balance > '0'", limit: 50 })
```

Returns only invoices with an outstanding balance. Derive "overdue" vs "pending" client-side by comparing `DueDate` to today.

**Use when:** The user asks "show me unpaid invoices", "what invoices are overdue?", "who owes me money?".

### Common Pattern 3 - Get a specific invoice by ID

```
mcp__quickbooks__read_invoice({ id: "145" })
```

Returns the full invoice object. Line items are in the `Line` array. `SalesItemLineDetail` line types contain the billable amounts.

**Use when:** The user asks "show me invoice 145" or "details of invoice INV-1022". (QuickBooks uses numeric `Id` internally; `DocNumber` like "1022" is the user-facing label. If the user gives a `DocNumber`, first run `search_invoices({ where: "DocNumber = '1022'" })` to get the `Id`.)

> **Naming quirks - three styles coexist in Intuit's MCP server.** Verified against `src/tools/*.tool.ts` (run `grep -rhoE '"(create|read|update|delete|search|get)[_-][a-z_-]+"' ~/.local/share/qbo-mcp/src/` to enumerate locally):
>
> 1. **`read_*` (snake_case)** - only 2 entities use this prefix: `read_invoice`, `read_item`.
> 2. **`get-*`, `create-*`, `update-*`, `delete-*` (kebab-case)** - only 2 entities use this hyphenated style: **Bill** (`get-bill`, `create-bill`, `update-bill`, `delete-bill`) and **Vendor** (`get-vendor`, `create-vendor`, `update-vendor`, `delete-vendor`). Their `search` variants stay snake_case: `search_bills`, `search_vendors`.
> 3. **`get_*`, `create_*`, `update_*`, `delete_*` (snake_case)** - everyone else (24+ entities including customer, account, employee, estimate, journal_entry, payment, purchase, sales_receipt, credit_memo, deposit, transfer, etc.) and all 11 reports (`get_balance_sheet`, `get_profit_and_loss`, etc.).
>
> So: fetching a Bill by ID is `mcp__quickbooks__get-bill({ id: ... })` (with a hyphen), but fetching a Customer is `mcp__quickbooks__get_customer({ id: ... })` (with an underscore). This is genuine source inconsistency in `intuit/quickbooks-online-mcp-server`, not a SKILL bug. When in doubt, search `ToolSearch +quickbooks` after Phase 1 completes to see the actual tool names as Claude Code exposes them.

### Common Pattern 4 - Create an invoice

Creating an invoice requires a customer (auto-create if missing) and at least one Product/Service Item. Confirm all details with the user in plain English before calling the tool.

Steps:

1. **Find or create the customer:**

   ```
   mcp__quickbooks__search_customers({ where: "DisplayName = 'Acme Corp'" })
   ```

   If empty, create one:

   ```
   mcp__quickbooks__create_customer({ DisplayName: "Acme Corp" })
   ```

   Capture `Customer.Id` from the response.

2. **Find a default Product/Service Item** (QuickBooks requires one on every invoice line):

   ```
   mcp__quickbooks__search_items({ limit: 10 })
   ```

   Pick the first active item. Capture its `Id` and `Name`. If zero items exist, tell the user: "Before I can create invoices, QuickBooks needs at least one product or service in your company. Please open QuickBooks, go to Sales then Products and Services, create a basic service item, and tell me when it is done."

3. **Build and submit the invoice:**

   ```
   mcp__quickbooks__create_invoice({
     CustomerRef: { value: "<customer-id>" },
     Line: [{
       Amount: 500,
       DetailType: "SalesItemLineDetail",
       Description: "Consulting services",
       SalesItemLineDetail: {
         ItemRef: { value: "<item-id>" },
         Qty: 1,
         UnitPrice: 500
       }
     }],
     DueDate: "2026-07-01",   // optional
     DocNumber: "INV-1042"    // optional
   })
   ```

After the tool returns, tell the user: "I've saved an invoice for **[Customer]** for **$[Amount]**. Review and send it from QuickBooks when ready." - never imply the invoice has been emailed.

### Common Pattern 5 - List customers

```
mcp__quickbooks__search_customers({ limit: 50 })
```

To search by name:

```
mcp__quickbooks__search_customers({ where: "DisplayName LIKE '%Smith%'" })
```

Fields of interest: `Id`, `DisplayName`, `PrimaryEmailAddr.Address`, `PrimaryPhone.FreeFormNumber`, `Balance`, `Active`.

**Use when:** The user asks "show me my customers", "find [name]", "list active customers".

### Common Pattern 6 - Create a customer

```
mcp__quickbooks__create_customer({
  DisplayName: "ABC Pty Ltd",
  PrimaryEmailAddr: { Address: "info@abc.com" },
  PrimaryPhone: { FreeFormNumber: "+61 412 345 678" }
})
```

Only `DisplayName` is required. Email and phone are optional.

### Common Pattern 7 - List accounts (chart of accounts)

```
mcp__quickbooks__search_accounts({ limit: 100 })
```

Filter by type:

```
mcp__quickbooks__search_accounts({ where: "AccountType = 'Expense'" })
mcp__quickbooks__search_accounts({ where: "AccountType = 'Bank'" })
```

Valid `AccountType` values: `Bank`, `Accounts Receivable`, `Income`, `Expense`, `Cost of Goods Sold`, `Fixed Asset`, `Other Asset`, `Credit Card`, `Accounts Payable`, `Long Term Liability`, `Equity`.

### Common Pattern 8 - Bank transactions (purchases + deposits)

```
mcp__quickbooks__search_purchases({ limit: 50 })
mcp__quickbooks__search_deposits({ limit: 50 })
```

QuickBooks models bank transactions as `Purchase` (money out) and `Deposit` (money in) entities. Run both and merge client-side for a full view.

Fields: `Id`, `TxnDate`, `EntityRef.name` (payee), `AccountRef.name`, `TotalAmt`, `CurrencyRef.value`.

### Common Pattern 9 - Profit and Loss report

```
mcp__quickbooks__get_profit_and_loss({})
```

With a date range:

```
mcp__quickbooks__get_profit_and_loss({ start_date: "2026-01-01", end_date: "2026-12-31" })
```

Default date range is from 1 Jan of the current year to today. Response shape is `{Header: {...}, Rows: {...}}` - the `Rows.Row` tree is nested and needs recursive walking to flatten into a display table.

Present to the user as a clean table with sections (Income, Cost of Goods Sold, Gross Profit, Expenses, Net Income) - never as raw JSON.

### Common Pattern 10 - Balance Sheet report

```
mcp__quickbooks__get_balance_sheet({})
```

With a specific as-of date:

```
mcp__quickbooks__get_balance_sheet({ end_date: "2026-04-14" })
```

Same nested response shape as Profit and Loss. Present as Assets / Liabilities / Equity sections.

---

## Advanced Entities - 144 tools available

This skill documents the 10 most common workshop prompts. The Intuit MCP server exposes **144 tools across 29 entities + 11 reports**. If the user asks about any entity not covered above - bills, vendors, estimates, journal entries, credit memos, sales receipts, refund receipts, purchase orders, vendor credits, transfers, time activities, classes, departments, terms, payment methods, tax codes/rates/agencies, employees, attachments - the corresponding `create_*`, `get_*`, `update_*`, `delete_*`, `search_*` tools are available via `mcp__quickbooks__*`.

**Discover available tools at runtime:**

```
ToolSearch with query "+quickbooks" - lists all mcp__quickbooks__* tools
```

For complete entity coverage tables, see the [Intuit MCP repo README](https://github.com/intuit/quickbooks-online-mcp-server#available-tools).

**Per-category disable flags.** The server respects three env vars to suppress entire tool categories:

- `QUICKBOOKS_DISABLE_WRITE=true` - suppresses `create_*` tools
- `QUICKBOOKS_DISABLE_UPDATE=true` - suppresses `update_*` tools
- `QUICKBOOKS_DISABLE_DELETE=true` - suppresses `delete_*` tools

`get_*` and `search_*` tools are always available. Useful for a "read-only" mode - set the disable flags in Step 10's `claude mcp add --env` and the participant gets a safer read-only setup.

---

## Prompt-to-Tool Mapping

| What the user says | MCP tool |
|---|---|
| "Show me my invoices" | `mcp__quickbooks__search_invoices({ limit: 20 })` |
| "List unpaid invoices" | `mcp__quickbooks__search_invoices({ where: "Balance > '0'" })` |
| "Show me invoice 1022" | `mcp__quickbooks__read_invoice({ id: "<id>" })` (note: `read_*` not `get_*` for invoice/item) |
| "Create an invoice for [client]" | Pattern 4 above |
| "Find [name] in my customers" | `mcp__quickbooks__search_customers({ where: "DisplayName LIKE '%<name>%'" })` |
| "Add a new customer" | `mcp__quickbooks__create_customer({ DisplayName: "..." })` |
| "Show me my accounts" | `mcp__quickbooks__search_accounts({})` |
| "List my bank transactions" | `search_purchases` + `search_deposits`, merge |
| "Show me recent payments" | `mcp__quickbooks__search_payments({ limit: 20 })` |
| "Profit and loss for this year" | `mcp__quickbooks__get_profit_and_loss({})` |
| "Get the balance sheet" | `mcp__quickbooks__get_balance_sheet({})` |
| "What QuickBooks company am I connected to?" | `mcp__quickbooks__get_company_info({})` |
| "List my bills" | `mcp__quickbooks__search_bills({})` |
| "Show me bill 42" | `mcp__quickbooks__get-bill({ id: "42" })` (kebab-case for bill/vendor) |
| "Show me my vendors" | `mcp__quickbooks__search_vendors({})` |
| "Show me vendor 7" | `mcp__quickbooks__get-vendor({ id: "7" })` (kebab-case for bill/vendor) |
| "Connect my QuickBooks" / "Help me set up QuickBooks" | **Run Phase 1** |

---

## Error Handling

MCP tool calls return either a result or an error. Translate errors to plain English for the user. Common error patterns:

| Error pattern | What it means | How to respond |
|---|---|---|
| `Tool not found: mcp__quickbooks__*` | Claude Code hasn't reconciled the new MCP server yet | Ask the user to close + reopen Claude Code |
| `Failed to authenticate / refresh token expired` | QuickBooks refresh token expired (100-day window) | Check `MODE` - if `sandbox`, re-run Phase 1S Step 9 (re-auth only). If `production`, re-run Phase 1L sub-phase D (tunnel + auth - sub-phases A/B/C already done). |
| `Resource not found` | The entity ID doesn't exist | Tell the user "I couldn't find [resource]. Let me list the recent ones so you can pick." Then run a search command. |
| `Permission denied` / `forbidden` | Unusual - possible scope mismatch | Translate: "QuickBooks says I don't have permission for that. Let me reconnect you." Re-run the auth-only sub-flow for the current `MODE` (Phase 1S Step 9 for sandbox, Phase 1L sub-phase D for live). |
| `Rate limit exceeded` | API rate limit hit | Wait 30 seconds, retry once. If still rate-limited, tell the user: "QuickBooks is asking me to slow down. Let me wait a minute and try again." |
| `No company ID` / `Realm not set` | `QUICKBOOKS_REALM_ID` env var missing or wrong | Re-run Step 9 - the refresh-token flow re-captures REALM_ID. |
| Generic JSON parse error | Transient API hiccup | Retry once after a 2-second delay. |

When in doubt, translate the error to plain English, tell the user what you're doing next, and re-run or fall back to Phase 1 as appropriate. Never show raw error messages to the user.

---

## Scope Limitations

This connector **can** read and write all 29 QuickBooks Online entity types (invoices, customers, vendors, bills, estimates, sales receipts, credit memos, refund receipts, purchase orders, vendor credits, payments, bill payments, deposits, purchases, transfers, journal entries, items, accounts, classes, departments, terms, payment methods, time activities, employees, attachments, tax codes/rates/agencies, company info) and pull all 11 financial reports (Balance Sheet, Profit & Loss, Cash Flow, Trial Balance, General Ledger, Customer Sales, Customer Balance, Aged Receivables, Aged Payables, Vendor Balance, Vendor Expenses).

It **cannot** access:

- **App Store publishing (Intuit tier 2 - 4-6 week App Assessment)** - not in scope for the workshop install flow. Tier 1 (Production-Development mode, immediate credentials, ~5-company cap) is what Phase 1L sets up, and is sufficient for any participant connecting their own one QBO company. App Store submission is an optional follow-up the participant can do on their own from the Intuit dev portal at any time (see `examples/install-walkthrough-app-store.md`, future).
- Payroll or employee payroll data (no payroll API in the MCP server's tool set).
- QuickBooks Payments processing (credit card processing).
- File attachments beyond the basic `Attachable` entity.
- Sending invoices by email (user does this in QuickBooks).
- Bank reconciliation / bank feed matching.

It **requires** at least one Product/Service Item to exist in the company before creating an invoice. Auto-picks the first available Item if the user doesn't specify one.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating** invoices or customers - summarise what you are about to create and wait for the user's OK before calling the tool.
- **Invoices are saved, not emailed** - never imply an invoice has been sent. Say "I've saved the invoice in QuickBooks - review and send it from QuickBooks when ready."
- **Customer auto-creation** - when creating an invoice for a new customer, tell the user a new customer was created alongside the invoice.
- **`mcp__quickbooks__*` tools are stateless** - each call goes to the QuickBooks API; no local caching. Free to call without setup.
- **Date format** - QuickBooks accepts ISO-8601 dates (`YYYY-MM-DD`). When the user says "last week", "Q1", "year-to-date", convert to explicit start_date / end_date before calling reports.
- **Format currency correctly** - 2 decimal places, use the currency from the QuickBooks response (`CurrencyRef.value`).
- **Present reports clearly** - when showing P&L or Balance Sheet, format as readable tables, not raw JSON.
- **Mode awareness** - `MODE=sandbox` operations target a practice company (say "practice company" to the user, never "sandbox"). `MODE=production` operations target real company data; the two gates above apply on first invocation and on every write call.
- **Auth errors** → re-run the auth-only sub-flow for the current `MODE` (Phase 1S Step 9 for sandbox; Phase 1L sub-phase D for live). Do not ask the user to "run a command" - you run it.
- **Never log or echo credentials** - CLIENT_ID, CLIENT_SECRET, REFRESH_TOKEN, REALM_ID values must never appear in any output visible to the user.

---

## Related Skills

- **orientation**: The source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer is closer to `xero-connector` and `stripe-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting QuickBooks auth or API errors
- **xero-connector**: Sibling accounting connector for Xero users - same Playwright-driven autonomous-Phase-1 pattern (different vendor; Xero uses a Custom Connection model instead of refresh tokens)
- **stripe-connector** / **github-connector**: Sibling autonomous-Phase-1 connectors - closest reference shapes for the Playwright-drives-the-developer-portal pattern this skill follows
- **intuit/quickbooks-online-mcp-server** (external, cloned in Phase 1 Step 3): The Intuit-maintained MCP server this SKILL wraps. Source of all 144 tool implementations.

## See also

- [Issue #320](https://github.com/selrai-company/claude-workshop-kit/issues/320) - original live-account (production-mode) tracking issue; implemented by this Phase 1L flow
- `assets/legal/` - the 4 HTML templates Phase 1L-A copies into the participant's Cloudflare Pages deploy (eula, privacy, launch, disconnect)
- Cloudflare Pages - https://developers.cloudflare.com/pages/ (the hosting target for Phase 1L-A)
- `cloudflared` - https://github.com/cloudflare/cloudflared (the OAuth-callback tunnel binary)
- `wrangler` - https://developers.cloudflare.com/workers/wrangler/ (the Cloudflare deploy CLI used by Phase 1L-A)
- [Intuit MCP repo](https://github.com/intuit/quickbooks-online-mcp-server) - README + full tool catalogue
- `skills/CLAUDE.md` - the four install-pattern decision tree (this SKILL is the prototype for a candidate fourth pattern: "Vendor-published local stdio MCP")
- Memory `reference_skill_tool_arg_interpolation` - Skill-tool `$N` arg interpolation workshop-UX issue affecting all connector SKILLs
- Memory `reference_playwright_snapshot_password_leak` - Playwright `browser_snapshot` returning auto-filled password values; mitigation pattern documented inline in Step 4
