# quickbooks-connector - install walkthrough (Intuit MCP edition)

This file shows what a successful Phase 1 install looks like end-to-end. It's a narrative reference for two audiences:

- **Workshop attendees** debugging an install that didn't quite finish ("did the SKILL get this far?")
- **Maintainers** verifying that a change to the SKILL didn't regress the happy path

The walkthrough is synthesised from a verified-live install on 2026-06-02 (Linux + Wayland, Node.js v22, `intuit/quickbooks-online-mcp-server` at HEAD, Intuit sandbox). Times in parentheses are from that run.

**Important context:** this walkthrough describes the *current* SKILL, which wraps Intuit's official MCP server (`intuit/quickbooks-online-mcp-server`). An earlier version of this SKILL wrapped `voska/qbo-cli` (a community Go binary); references to `qbo auth login`, `~/.config/qbo/credentials.env`, port `8844`, or rc-file marker blocks belong to that prior shape. See CWK PR #321 for the pivot context.

## What success looks like (the 60-second version)

A workshop attendee says **"set up QuickBooks"** or **"connect my QuickBooks"** to Claude. From their perspective:

1. A browser window opens. Claude says: *"Opening a browser window for you - please sign in to developer.intuit.com when it appears (and approve any 2FA prompt). I'll do the rest. About three minutes."*
2. The attendee signs in to their Intuit developer account (and handles 2FA if their account asks). They do nothing else.
3. ~3 minutes later Claude says: *"All connected - one last step: please close this window and reopen Claude Code, then say hi. The QuickBooks tools will be ready for you."*
4. The attendee closes + reopens Claude Code, says "hi", and Claude greets them: *"Welcome back - I'm now connected to your QuickBooks practice company **Sandbox Company AU e43d**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this month?'."*

That's the whole user-facing experience. Everything else is autonomous.

## What Claude is actually doing under the hood

Each step below corresponds to a section in `SKILL.md`. Times are from the 2026-06-02 install on a returning Intuit account (Claude Assistant app already exists; the Intuit MCP repo already cloned). A fresh-account install adds ~60-90 seconds for the npm install + build, plus 30-60 seconds for the create-app form.

### Step 1 - Is the QuickBooks MCP server already registered? (0s)

```bash
$ claude mcp list 2>&1 | grep -i quickbooks
quickbooks: node /home/cx559824/.local/share/qbo-mcp/dist/index.js - ✓ Connected
```

If this output shows `✓ Connected`, the MCP server is already registered and authenticated. Claude runs one `mcp__quickbooks__get_company_info` smoke call to confirm the auth still works, then jumps straight to Phase 2.

If `claude mcp list` shows no quickbooks entry, or shows `✗ Failed to connect`, Claude continues to Step 2.

Also check the install directory:

```bash
$ ls -la "$HOME/.local/share/qbo-mcp/dist/index.js"
-rwxr-xr-x 1 cx559824 cx559824 19318 Jun  2 09:08 /home/cx559824/.local/share/qbo-mcp/dist/index.js
```

If `dist/index.js` exists, Steps 2-3 (install + build) are skipped.

### Step 2 - Install prerequisites: Node.js + git + Playwright MCP (~0-90s depending on what's missing)

```bash
$ node --version
v22.20.0

$ git --version
git version 2.51.0
```

Both required. If missing, Claude drives the OS-appropriate installer (Homebrew on macOS, apt/dnf/pacman on Linux, scoop/installer on Windows).

The Playwright MCP server is checked separately - if `mcp__plugin_playwright_playwright__*` tools aren't in the deferred-tool surface, Claude runs `claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir ~/.cache/playwright-mcp-profile` and asks the participant to restart Claude Code (one-time cost).

### Step 3 - Clone + build the Intuit MCP server (~60s on a fresh install, 0s on returning)

```bash
$ INSTALL_DIR=$HOME/.local/share/qbo-mcp
$ git clone https://github.com/intuit/quickbooks-online-mcp-server.git "$INSTALL_DIR"
Cloning into '/home/cx559824/.local/share/qbo-mcp'...

$ cd "$INSTALL_DIR" && npm install
[npm progress output omitted]

$ npm run build
> @qboapi/qbo-mcp-server@0.0.1 build
> tsc && shx chmod +x dist/*.js

$ ls -la dist/index.js
-rwxr-xr-x 1 cx559824 cx559824 19318 Jun  2 09:08 dist/index.js
```

On a returning install, `git pull --ff-only` keeps the clone current. The `npm install` step is cached after the first run; `npm run build` is usually a no-op if no source changed.

### Step 4 - Open developer.intuit.com and confirm a logged-in session (~30s on a returning account)

Playwright navigates to `https://developer.intuit.com/workspaces`. One of two states:

- **Already signed in** (persistent Playwright profile retained the session) → land on `/workspaces` showing workspace cards.
- **Signed out** (first-time install or after Intuit session expiry) → land on `accounts.intuit.com/app/sign-in`. Claude polls `browser_wait_for({ text: "Workspaces" })` silently - **does NOT snapshot the sign-in page** because Playwright's `browser_snapshot` returns auto-filled password values when a password manager populates the field (documented in memory `reference_playwright_snapshot_password_leak`).

### Step 5 - Find or create the "Claude Assistant" app (~10s on returning, ~60s on fresh-app create)

In the workspace dashboard at `developer.intuit.com/dashboard?id=<workspace-id>&tab=apps`:

- **App exists** → click into it. URL becomes `developer.intuit.com/appdetail/overview?appId=<base64-prefix:uuid>&id=<workspace-id>`. Capture both IDs.
- **App doesn't exist** → click `+` create card → pick "QuickBooks Online and Payments" → name "Claude Assistant" → tick `com.intuit.quickbooks.accounting` scope → Create app → capture new appId.

The 2026-06-02 install found the existing app from prior sessions (`appId=djQuMTo6OGQzYmJlYTI3Yg:4204facc-0232-491c-842d-44c19fcc03ab`, `workspace=9341456862813230`).

### Step 6 - Redirect URI idempotent upsert (~5s)

Claude navigates to `appdetail/settings?...&tab=redirect-uris`, reads all `input[aria-label="url-location"]` values, and checks whether `http://localhost:8000/callback` is present.

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

The 2026-06-02 install found 3 URIs registered from prior sessions but missing `8000`. Claude:

1. Clicked **Add URI** to spawn an empty `aria-label="url-location"` input.
2. Filled it via the React-friendly setter (`Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set` + `input` + `change` events).
3. Clicked `#edit-save-button` via `browser_evaluate` (the button was off-screen; bypass the viewport check with `scrollIntoView({block:'center'}) + click()`).
4. Reloaded the page to verify persistence - Intuit's Save flow can briefly leave the form in a dirty-but-saved state.

After the upsert, 4 URIs were registered: the Intuit OAuth Playground default + `http://localhost:3000/callback` (from some other project) + `http://localhost:8844/callback` (from the prior voska/qbo-cli SKILL era) + the new `http://localhost:8000/callback`. They coexist harmlessly; Intuit allows up to 25 URIs per app.

### Step 7 - DOM-extract Client ID and Client Secret (~15s)

Claude navigates to `appdetail/keys?...`. The Client ID and Client Secret are masked behind a "Show credentials" toggle (a `role="switch"` named `Show credentials`).

The credential read uses a **clipboard-transit pattern** so the literal values never appear in tool returns or the conversation transcript:

1. Save the user's existing clipboard so we can restore it after.
2. Click **Show credentials** to reveal values in the DOM.
3. `browser_evaluate` walks up from "Client ID:" / "Client secret:" labels to find the input/text-node values, calls `navigator.clipboard.writeText(JSON.stringify({client_id, client_secret}))`, and returns ONLY `{ ok: true, client_id_len: 50, client_secret_len: 40 }`.
4. Click **Show credentials** again to hide.
5. Bash `wl-paste | jq -r '"QUICKBOOKS_CLIENT_ID=" + .client_id + "\nQUICKBOOKS_CLIENT_SECRET=" + .client_secret'` redirects credentials directly to `~/.local/share/qbo-mcp/.env` without ever touching stdout.
6. Restore the user's original clipboard.

A workshop attendee never sees their Client ID or Client Secret - the SKILL design keeps them in the file system, not the conversation.

### Step 8 - Write `.env` to the MCP install dir (~1s)

```bash
$ ls -la "$INSTALL_DIR/.env"
-rw------- 1 cx559824 cx559824 224 Jun  2 09:13 /home/cx559824/.local/share/qbo-mcp/.env

$ awk -F= '/^QUICKBOOKS_/ {key=$1; val_len=length($0)-length(key)-1; printf "  %s: %s (length %d)\n", key, (val_len>0 ? "SET" : "EMPTY"), val_len}' "$INSTALL_DIR/.env"
  QUICKBOOKS_CLIENT_ID: SET (length 50)
  QUICKBOOKS_CLIENT_SECRET: SET (length 40)
  QUICKBOOKS_REDIRECT_URI: SET (length 30)
  QUICKBOOKS_ENVIRONMENT: SET (length 7)
```

Mode 600. Four keys at this point. `REFRESH_TOKEN` and `REALM_ID` are added by Step 9.

Note: unlike the prior voska/qbo-cli SKILL, this version does **NOT** write to the participant's shell startup file (`~/.zshrc` etc.). The env vars travel via `claude mcp add --env ...` in Step 10 - Claude Code stores them inside `~/.claude.json`'s `mcpServers.quickbooks.env`, scoped to the MCP server's runtime only. The participant's interactive shells stay clean.

### Step 9 - Run `npm run auth` and capture refresh token (~5-10s)

Claude launches the Intuit MCP's bundled `auth-server.ts` (the `npm run auth` script) in the background:

```bash
$ cd "$INSTALL_DIR" && exec npm run auth > /tmp/qbo-mcp-auth.log 2>&1 &
```

After ~3 seconds, the log contains:

```
QuickBooks OAuth Authentication
================================

Starting OAuth flow...
A browser window will open for you to authorize the application.

[auth-server] Listening on :::8000 (family: IPv6)

=== QuickBooks Authorization ===
Open this URL in a browser to authorize:

https://appcenter.intuit.com/connect/oauth2?client_id=ABmIyQyCAkRltgyD2IExzaMwERyrbckLteb1BhstzFDbddNjz3&redirect_uri=http%3A%2F%2Flocalhost%3A8000%2Fcallback&response_type=code&scope=com.intuit.quickbooks.accounting&state=testState

Waiting for callback...
```

Claude extracts the auth URL from the log and navigates Playwright to it:

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Three possible states (same as the prior SKILL):

- **Auto-redirect to `localhost:8000/callback`** (~0.5s, persistent profile has stored consent) → auth-server catches it.
- **Sandbox company picker** → click first sandbox company.
- **Connect / Authorize button** → DOM-extract via `browser_evaluate` + click.

On success, the log shows:

```
[auth-server] GET /callback?code=XAB117803634738odSmSyrdyF5JbIPCLYm9tjOIonynABCUHuo&state=testState&realmId=9341456862969697
[auth-server] GET /favicon.ico

✓ Successfully authenticated with QuickBooks!
Tokens have been saved to your .env file.
```

The auth-server then exits 0. The browser tab shows "✓ Successfully connected to QuickBooks!".

After this step, `.env` contains all 6 keys:

```
  QUICKBOOKS_CLIENT_ID: SET (length 50)
  QUICKBOOKS_CLIENT_SECRET: SET (length 40)
  QUICKBOOKS_REDIRECT_URI: SET (length 30)
  QUICKBOOKS_ENVIRONMENT: SET (length 7)
  QUICKBOOKS_REFRESH_TOKEN: SET (length 41)
  QUICKBOOKS_REALM_ID: SET (length 16)
```

### Step 10 - Register the MCP server with Claude Code (~2s)

```bash
$ set -a; . "$INSTALL_DIR/.env"; set +a

$ claude mcp add quickbooks --scope user \
    --env "QUICKBOOKS_CLIENT_ID=$QUICKBOOKS_CLIENT_ID" \
    --env "QUICKBOOKS_CLIENT_SECRET=$QUICKBOOKS_CLIENT_SECRET" \
    --env "QUICKBOOKS_REFRESH_TOKEN=$QUICKBOOKS_REFRESH_TOKEN" \
    --env "QUICKBOOKS_REALM_ID=$QUICKBOOKS_REALM_ID" \
    --env "QUICKBOOKS_REDIRECT_URI=$QUICKBOOKS_REDIRECT_URI" \
    --env "QUICKBOOKS_ENVIRONMENT=$QUICKBOOKS_ENVIRONMENT" \
    -- node "$INSTALL_DIR/dist/index.js" >/dev/null 2>&1
# exit 0

$ claude mcp list 2>&1 | grep -i quickbooks
quickbooks: node /home/cx559824/.local/share/qbo-mcp/dist/index.js - ✓ Connected
```

**Critical:** the `claude mcp add` command's stdout is redirected to `/dev/null` because v2.1.x prints `--env` values verbatim (documented in memory `reference_claude_mcp_add_token_echo`). Without the redirect, the REFRESH_TOKEN would land in Claude's conversation context.

After registration, `~/.claude.json` contains:

```jsonc
{
  "mcpServers": {
    "quickbooks": {
      "command": "node",
      "args": ["/home/cx559824/.local/share/qbo-mcp/dist/index.js"],
      "env": {
        "QUICKBOOKS_CLIENT_ID": "...",
        "QUICKBOOKS_CLIENT_SECRET": "...",
        "QUICKBOOKS_REFRESH_TOKEN": "...",
        "QUICKBOOKS_REALM_ID": "...",
        "QUICKBOOKS_REDIRECT_URI": "http://localhost:8000/callback",
        "QUICKBOOKS_ENVIRONMENT": "sandbox"
      }
    }
  }
}
```

### Step 11 - Ask the participant to restart Claude Code (~0s of Claude time; minutes of participant time)

The `mcp__quickbooks__*` tools only appear in the deferred-tool surface after Claude Code's MCP runtime reconciles the new server. This requires a restart.

Claude tells the participant: *"All connected - one last step: please close this window and reopen Claude Code, then say hi. The QuickBooks tools will be ready for you."*

This is the single moment where Phase 1 hands off responsibility to the participant. They close the window and reopen.

### Step 12 - Verify after restart (Phase 0 on the next session, ~2s)

When the participant returns and says "hi" or invokes any QuickBooks-related prompt, the SKILL's Phase 0 check runs:

```bash
$ claude mcp list 2>&1 | grep -i quickbooks
quickbooks: node /home/cx559824/.local/share/qbo-mcp/dist/index.js - ✓ Connected
```

Then a smoke call:

```
mcp__quickbooks__get_company_info({})
```

Returns the sandbox company's name (`Sandbox Company AU e43d` for the 2026-06-02 install). Claude greets the participant warmly and they're ready for Phase 2.

## Phase 2 smoke test - fetching real data

After Phase 1 completes, an outsider can verify the install with these MCP tool calls (all 144 available; here are the top 5 most-likely):

```
mcp__quickbooks__get_company_info({})
→ { CompanyInfo: { CompanyName: "Sandbox Company AU e43d", Country: "AU", ... } }

mcp__quickbooks__search_invoices({ limit: 5 })
→ array of 5 invoice objects with Id, DocNumber, CustomerRef, TxnDate, TotalAmt, Balance

mcp__quickbooks__search_customers({ limit: 5 })
→ array of 5 customer objects

mcp__quickbooks__get_profit_and_loss({})
→ { Header: {...}, Rows: {Row: [...nested...]} }

mcp__quickbooks__get_balance_sheet({})
→ same shape as P&L
```

If those return data (and not errors), the install worked end-to-end.

## Three known platform-level issues to be aware of

These aren't QBO-SKILL bugs. They're Claude Code / Playwright MCP / Intuit MCP behaviours that affect every install of this shape. Documented here so workshop attendees aren't surprised.

1. **Skill-tool `$N` arg interpolation.** If a participant invokes the SKILL via `Skill quickbooks-connector` with multi-word args (e.g. "set up my QuickBooks"), Claude Code's Skill-tool display shell-interpolates `$N` positional refs in the SKILL.md content against the words of the args string. Bash positional parameters in the SKILL's code blocks get corrupted in what Claude sees. The disk file is unaffected. Workaround: Claude must Read the SKILL.md from disk for code blocks, not trust the loaded display. (Memory: `reference_skill_tool_arg_interpolation`.)

2. **Playwright `browser_snapshot` captures password values.** When the Playwright browser hits a sign-in page, password managers (Keeper, 1Password, browser autofill) populate the password field on page load - before the participant clicks Sign in. A snapshot taken at that moment returns the literal password value in the accessibility tree. Mitigation: don't snapshot the sign-in page; use `browser_wait_for({ text: "<post-auth marker>" })` instead. (Memory: `reference_playwright_snapshot_password_leak`.)

3. **Intuit MCP tool-naming inconsistencies.** Intuit's `quickbooks-online-mcp-server` uses three naming styles for the same kind of action: `read_invoice` / `read_item` (snake_case), `get-bill` / `get-vendor` (kebab-case for bill + vendor entities), and `get_customer` / `get_account` / `get_balance_sheet` / etc. (snake_case for everyone else). When in doubt, run `ToolSearch +quickbooks` after Phase 1 restart to see the actual tool names. The SKILL's Pattern 3 and Prompt-to-Tool Mapping table call out the quirks inline; future Intuit MCP updates may normalise them.

## When to re-read this file

- A workshop attendee reports "the SKILL got stuck" → walk through each step's expected output against what they actually saw. Most "stuck" reports correspond to a specific step (Steps 4-9 are where the interactive moments live).
- A maintainer changes the SKILL's code → use the documented expected outputs as a regression-test baseline. If a step's output drifts from what's documented here, the change either broke something or this walkthrough is stale.
- Onboarding a new maintainer to the SKILL → read this end-to-end before opening SKILL.md. The walkthrough explains the *why* of design choices that SKILL.md's body assumes you know.

## See also

- `../SKILL.md` - the actual instructions Claude follows.
- CWK PR #321 - the Intuit MCP pivot (this walkthrough validates the merged-2026-06-02 state).
- CWK PR #320 - live-account (production-mode) support tracking issue.
- [Intuit MCP repo](https://github.com/intuit/quickbooks-online-mcp-server) - README + full tool catalogue.
- selr-kit-index - see the quickbooks-connector entry for the current Pass 1 verdict.
