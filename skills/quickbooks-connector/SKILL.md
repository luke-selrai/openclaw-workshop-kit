---
name: quickbooks-connector
description: "Install and operate the QuickBooks Online connector autonomously. Drives developer.intuit.com setup end-to-end inside a Playwright MCP browser: finds or creates an Intuit developer app named 'Claude Assistant', adds http://localhost:8844/callback to the Development redirect URIs, DOM-extracts the Client ID and Client Secret with the Show-credentials toggle bracketing the read, persists them to ~/.config/qbo/credentials.env, and runs qbo auth login --sandbox under a pty wrapper so the local OAuth listener stays alive. The user's only manual moments are signing in to developer.intuit.com once and any 2FA challenge their Intuit account requires. Read and update QuickBooks Online accounting data via the qbo CLI (github.com/voska/qbo-cli). Handles invoices (list, view, create, filter by status), customers (list, create), the chart of accounts, bank transactions, customer payments, the Profit and Loss report, the Balance Sheet, and company information. Supports sandbox only — production is out of scope. Use this skill when the user asks about their QuickBooks, QBO, invoices, unpaid invoices, overdue invoices, customers, profit and loss, balance sheet, bank transactions, chart of accounts, payments received, or when they say 'connect my QuickBooks' or 'help me set up QuickBooks'. On the first use of any QuickBooks feature, run Phase 1 to install qbo and authenticate before attempting any tool calls."
allowed-tools: mcp__playwright__*, mcp__plugin_playwright_playwright__*, Bash, Read, Write, Edit
metadata:
  category: Productivity & Integrations
  tags:
    - quickbooks
    - qbo
    - accounting
    - invoices
    - customers
    - finance
    - cli
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting qbo auth or API errors
    - skill: xero-connector
      reason: Sibling accounting connector — same Playwright-driven autonomous-Phase-1 pattern
---

# QuickBooks Connector

## Overview

This skill lets you read and update a user's QuickBooks Online accounting data on their behalf — invoices, customers, the chart of accounts, bank transactions, customer payments, and the Profit & Loss / Balance Sheet reports. Once it is connected, the owner can ask things like *"show me my unpaid invoices"* or *"what's my profit and loss this year?"* in plain English and get answers back, no spreadsheets or logins required.

Under the hood it is a **thin Bash wrapper around [`voska/qbo-cli`](https://github.com/voska/qbo-cli)** — a single-binary Go CLI with structured JSON output, machine-readable exit codes, and OS-keyring token storage. There is no MCP server, no Node.js layer, and no wrapper code in this repo.

The skill has two phases:

- **Phase 1 — Install & Auth (autonomous via Playwright).** Claude installs the `qbo` binary, drives the entire `developer.intuit.com` developer-app flow inside a Playwright MCP browser (find or create an app named "Claude Assistant", add `http://localhost:8844/callback` to the Development redirect URIs, DOM-extract Client ID + Client Secret with Show-credentials toggle bracketing), persists credentials to `~/.config/qbo/credentials.env`, and runs `qbo auth login --sandbox` under a pty wrapper so the OAuth listener stays alive. The user's only manual moments are signing in to `developer.intuit.com` once and approving any 2FA prompt. Everything else — workspace + app discovery / creation, redirect URI upsert, credential capture, OAuth click-through — is autonomous.
- **Phase 2 — Use Tools.** Once qbo is installed and authenticated, you shell out to `qbo` via Bash to answer questions and make changes. This skill documents the 10 most common workshop prompt patterns. For advanced entities (bills, vendors, estimates, journal entries, budgets, etc.) delegate to the official `voska/qbo-cli` skill installed in Phase 1 Step 3.

**Which phase to run** — Before any tool call, check whether qbo is installed and authenticated. Run:

```bash
qbo auth status 2>&1
```

- Exit code 0 → authenticated. Go to Phase 2.
- Exit code 4 (`auth_required`) or exit code 127 (`command not found`) → run Phase 1 from the appropriate step.
- Any other exit → translate the error, diagnose, run Phase 1 if needed.

**Sandbox only.** This skill supports QuickBooks Online sandbox only. Production requires Intuit app assessment and a non-localhost redirect URI, which is out of scope for the workshop.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work. The user only signs in to developer.intuit.com once (and answers 2FA if challenged). Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, scroll, or paste values in the happy path. The only actions you ever request are "please sign in to developer.intuit.com in the browser window I just opened" and (if challenged) "please approve the 2FA prompt on your phone."
- **Plain English only.** No jargon. Never say CLI, binary, PATH, env var, export, Homebrew, Scoop, keyring, keychain, OAuth, scope, token, callback, redirect URI, realmId, JSON, MCP, DOM, Playwright, pty, or terminal. If you must refer to a technical thing, name it plainly: "the QuickBooks tool I need", "your browser", "a small one-time setup step on your computer".
- **Tell them what is about to happen.** Before any action: "I am going to connect QuickBooks for you — this takes about two minutes."
- **React to success and failure warmly.** Good: "That worked — your QuickBooks is now connected." Bad: "exit 4 auth_required."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, or scripts** to the user. You run them; you do not describe them.
- **Never echo the Client ID or Client Secret** back to the user. Both are stored locally; never include them in any output visible to the user.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude installs the `qbo` binary, drives developer.intuit.com end-to-end via Playwright MCP to set up the Intuit developer app + capture credentials + add the localhost redirect URI, persists those credentials to a small file, and runs `qbo auth login --sandbox` under a pty wrapper. The user's only role is signing in to developer.intuit.com when prompted (and only the first time — the persistent Playwright profile keeps the session for future runs) and approving any 2FA challenge their account requires.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Show credentials toggle and read the Client ID input from the same panel"). Achieve it via `mcp__playwright__browser_snapshot` → reason → `browser_click` / `browser_evaluate` / `browser_fill_form` / `browser_select_option`. Match elements by their visible labels and `aria-label` attributes ("Show credentials", "Add URI", inputs with `aria-label="url-location"`), not by selector paths — Intuit's developer portal UI evolves.

### Step 1 — Check if qbo is already installed

Silently run:

```bash
qbo --version 2>&1
```

If it prints a version string, jump to Step 3. If it errors with "command not found" (exit 127), continue to Step 2. Any other error → translate and continue to Step 2 (re-install is the safest path).

### Step 2 — Install the qbo CLI

Tell the user: "I am going to install a small tool I need to talk to QuickBooks — this will take about one minute."

Silently detect the user's OS and run the install command:

**macOS (Intel or Apple Silicon):**

```bash
brew install voska/tap/qbo
```

- Success → Step 3.
- "brew: command not found" → install Homebrew first via `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`, then retry. If Homebrew install fails on a corporate laptop (common), fall back to the binary download path below.

**Linux:**

```bash
brew install voska/tap/qbo
```

- If Homebrew isn't present, fall back to:

  ```bash
  go install github.com/voska/qbo-cli/cmd/qbo@latest
  ```

- If Go isn't present either, fall back to the binary download path below.

**Windows (Git Bash):**

```bash
scoop bucket add voska https://github.com/voska/scoop-bucket && scoop install qbo
```

- "scoop: command not found" → fall straight through to the binary download path below. Don't try to install Scoop automatically — it requires PowerShell elevation.

> **Windows PATH note.** scoop appends to the user PATH but the current shell may not see it until a fresh terminal. Resolve the binary directly for the rest of this session if `qbo --version` still 127s after scoop install — derived from PR #238's defensive-path-handling pattern:
>
> ```bash
> QBO_BIN="$(find "$USERPROFILE/scoop/apps/qbo" -name 'qbo.exe' 2>/dev/null | head -1)"
> alias qbo="\"$QBO_BIN\""
> ```
>
> The user's next fresh terminal will see `qbo` on PATH naturally; this alias keeps Phase 1 working without forcing a restart mid-flow.

**Binary download fallback (any platform, when the package manager path fails):**

Fetch the latest release metadata and pick the asset matching the user's OS+arch:

```bash
curl -s https://api.github.com/repos/voska/qbo-cli/releases/latest
```

| OS | Arch | Asset name pattern |
|---|---|---|
| Windows | x64 | `qbo_windows_amd64.zip` or `qbo_windows_amd64.exe` |
| macOS | Intel | `qbo_darwin_amd64.tar.gz` |
| macOS | Apple Silicon | `qbo_darwin_arm64.tar.gz` |
| Linux | x64 | `qbo_linux_amd64.tar.gz` |
| Linux | arm64 | `qbo_linux_arm64.tar.gz` |

Download, extract the `qbo` binary, place it on PATH (`~/.local/bin/qbo` on Mac/Linux; `~/bin/qbo.exe` on Windows). `chmod +x` on Mac/Linux. Verify:

```bash
qbo --version 2>&1
```

If still not found, tell the user: *"I couldn't install the QuickBooks tool automatically on your computer. It usually means something on your system is blocking downloads. Are you on a work laptop?"* Escalate or retry from a different network.

### Step 3 — Install the official qbo skill (best-effort)

The qbo CLI project publishes its own Claude Code skill that documents every command and supported entity. Installing it gives Claude a second reference for advanced patterns beyond the 10 common ones this skill covers.

Silently run:

```bash
npx skills add -g voska/qbo-cli -y 2>&1
```

- Success → Step 4.
- Any failure → ignore silently and continue to Step 4. This step is best-effort. Do not tell the user it failed. The skill works fine without it.

### Step 4 — Open developer.intuit.com and confirm a logged-in session

Tell the user, in one short message:

> "Opening a browser window for you — please sign in to developer.intuit.com when it appears (and approve any 2FA prompt). I'll do the rest. About two minutes."

Call:

```
mcp__playwright__browser_navigate({ url: "https://developer.intuit.com/workspaces" })
```

Take a `mcp__playwright__browser_snapshot()`. Reason from it:

- **Logged in** (you see a "Workspaces" heading and at least one workspace card OR an empty state with a "Create workspace" affordance) → continue to Step 5.
- **Not logged in** (you're at `accounts.intuit.com/app/sign-in`, with Email + Password fields) → poll silently with `mcp__playwright__browser_wait_for({ text: "Workspaces" })`. Do not ask the user to confirm; detect login completion yourself.
- **2FA challenge** ("Two-factor authentication", "Verify", "Authenticator app", "Confirm sign in") → poll silently with `browser_wait_for({ text: "Workspaces" })`. The 2FA action happens on the user's phone or hardware key; the SKILL just waits.

If `browser_wait_for` times out (5+ minutes), check in: *"Still on the sign-in page? Anything I can help with?"*

### Step 5 — Find or create the "Claude Assistant" app

Walk the workspace UI to either reuse an existing Claude Assistant app or create one.

**5a. Pick a workspace.** From the snapshot at `/workspaces`, locate a workspace card (e.g., "Sample Workspace" — the default one new accounts get). Click into it via `browser_click`. The URL becomes `developer.intuit.com/dashboard?id=<workspace-id>&tab=apps` and an app list appears.

If the user has zero workspaces, click **Create workspace** and follow Intuit's wizard with sensible defaults (workspace name `My Workspace`).

**5b. Find or create the app.** In the workspace's app list, look for a card whose title contains `Claude Assistant`.

- **App exists** → click into it. The URL becomes `developer.intuit.com/appdetail/overview?appId=<...>&id=<workspace-id>`. Note the `appId` (a base64-prefixed UUID, e.g., `djQuMTo6OGQzYmJlYTI3Yg:4204facc-0232-491c-842d-44c19fcc03ab`) and the workspace `id` from the URL — Step 6 / 7 navigation reuses both.
- **App does not exist** → click the `+` create-card or **Create an app** button. Intuit asks for app type — pick **QuickBooks Online and Payments**. Set the name to `Claude Assistant`. Tick the `com.intuit.quickbooks.accounting` scope. Click **Create app**. Capture the resulting `appId` from the post-create URL.

> **Robustness note.** The find-existing-app path is the verified-live shape (this is what runs on returning users where Phase 1 has been completed before, even if Phase 1 was abandoned mid-flow). The create-new-app path is written from snapshot evidence of the workspace UI's `+` create card; reviewers should confirm on a fresh Intuit account that the create-app form fields match the labels above (Intuit's portal UI shifts).

### Step 6 — Add the localhost redirect URI on the Development tab

Navigate to the redirect URI settings:

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/settings?appId=<appId>&id=<workspaceId>&tab=redirect-uris"
})
```

`mcp__playwright__browser_wait_for({ text: "Redirect URI" })`. Take a snapshot.

The page shows two sub-tabs at the top (**Development** and **Production**) and a list of existing redirect URI inputs in the Development tabpanel. The Development tab is selected by default; verify by inspecting the snapshot and clicking the Development tab via `browser_click` if needed.

**Idempotent upsert.** Check whether `http://localhost:8844/callback` is already registered:

```js
() => {
  const tabpanel = document.querySelector('[role="tabpanel"]');
  const inputs = Array.from(tabpanel.querySelectorAll('input[aria-label="url-location"]'));
  return {
    uris: inputs.map(i => i.value),
    has_8844: inputs.some(i => i.value === 'http://localhost:8844/callback'),
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
    setter.call(target, 'http://localhost:8844/callback');
    target.dispatchEvent(new Event('input', { bubbles: true }));
    target.dispatchEvent(new Event('change', { bubbles: true }));
    return { ok: true };
  }
  ```

  Then click **Save**. Reload the page (`browser_navigate` to the same URL) and re-evaluate the URI list to confirm persistence — Intuit's Save flow can briefly leave the form in a dirty-but-saved state where the Save button stays enabled.

> **Why the React-friendly setter.** Intuit's redirect URI input is a controlled React component. Naive `el.value = '...'` writes the DOM value but does not fire React's `onChange` handler, so React re-renders and resets the value to its prior state on the next render. Calling the prototype's native setter and dispatching `input` + `change` events with `bubbles: true` makes React see the change and update its state. This pattern is empirically required here.

> **Multi-URI coexistence.** The user may already have other redirect URIs registered for other tools (e.g., `http://localhost:3000/callback` for a previous Next.js project, or `https://developer.intuit.com/v2/OAuth2Playground/RedirectUrl` for the Intuit OAuth Playground). Never delete or replace existing URIs — only append. Intuit allows up to 25 per app. If the user previously used a different QuickBooks tool with `:3000` registered, both `:3000` and `:8844` can coexist.

> **Avoid the page Search input footgun.** The developer portal has a global "Search..." input in the header that can be picked first by naive empty-input filters. Always scope the input search to `document.querySelector('[role="tabpanel"]')` to constrain it to the redirect URIs panel.

### Step 7 — DOM-extract Client ID and Client Secret

Navigate to:

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/keys?appId=<appId>&id=<workspaceId>"
})
```

`mcp__playwright__browser_wait_for({ text: "Client ID" })`. Take a snapshot.

The page shows two sub-tabs (Development / Production). Development is selected by default. The Client ID and Client Secret values are masked behind a **Show credentials** toggle (a `role="switch"` named `Show credentials`).

**Bracket the toggle around the read** so the values are on screen for the minimum time:

1. Click the Show credentials toggle:

   ```
   mcp__playwright__browser_click({ target: 'role=switch[name="Show credentials"]' })
   ```

2. Read the values via `browser_evaluate` — walk up from the visible "Client ID:" and "Client secret:" labels to find the value-bearing input (or text node) inside the same parent:

   ```js
   () => {
     const labels = Array.from(document.querySelectorAll('*')).filter(el => /^client (id|secret)\s*:?$/i.test((el.innerText||'').trim()));
     const out = {};
     for (const label of labels) {
       const which = /id/i.test(label.innerText) ? 'client_id' : 'client_secret';
       if (out[which]) continue;
       let candidate = label.parentElement;
       for (let depth = 0; depth < 5 && candidate; depth++) {
         const inputs = Array.from(candidate.querySelectorAll('input'));
         const v = inputs.map(i => i.value).find(v => v && v.length > 10);
         if (v) { out[which] = v; break; }
         const txt = (candidate.innerText||'').trim().split('\n').map(s=>s.trim()).filter(Boolean);
         const credLine = txt.find(l => l.length > 20 && /^[A-Za-z0-9_\-\.]+$/.test(l));
         if (credLine) { out[which] = credLine; break; }
         candidate = candidate.parentElement;
       }
     }
     return out;
   }
   ```

3. Click the Show credentials toggle a second time to hide them again.

**Validation (silent).** Client ID is typically ~50 characters, alphanumeric. Client Secret is typically 40 characters, alphanumeric. Both are URL-safe (`[A-Za-z0-9_\-\.]+`). If either field is empty or fails this shape check, re-snapshot, ensure the Development tab (not Production) is selected, retry once.

**Conversational fallback.** If two extract attempts don't surface valid credentials (e.g., Intuit has moved the values to a non-DOM-readable widget on this account), narrate once: *"I'm having trouble reading the credentials automatically — could you paste your Client ID and Client Secret for me?"* Wait for the user to paste, validate the shape, and continue. The credentials transit the transcript in this fallback path; that's an accepted trade-off.

### Step 8 — Save the credentials (silent)

Silently write `~/.config/qbo/credentials.env`:

```bash
mkdir -p ~/.config/qbo
cat > ~/.config/qbo/credentials.env <<EOF
QBO_CLIENT_ID="<value from Step 7>"
QBO_CLIENT_SECRET="<value from Step 7>"
EOF
chmod 600 ~/.config/qbo/credentials.env
```

If the file already exists, overwrite — fresh credentials always take precedence over stale ones.

> **Why a separate file (not `~/.zshrc`).** Isolating QBO credentials in their own file keeps them out of the user's globally-sourced shell config. Every Phase 1 and Phase 2 qbo invocation prefixes with `set -a && source ~/.config/qbo/credentials.env && set +a` to load them just for that subprocess. Bash subshells don't auto-source `~/.zshrc`, so a global-export approach would silently fail in many invocation contexts.

Never echo the captured values back to the user. Never include them in any output visible to the user.

### Step 9 — Run qbo auth login (autonomous via Playwright)

Tell the user: *"Connecting to QuickBooks now — this takes about ten seconds."*

The `qbo` CLI's OAuth listener requires a controlling pseudo-terminal to keep running; without one (the default in any Bash subshell), `qbo` prints the auth URL and exits before the listener spawns, so the OAuth callback never lands. Wrap qbo in a pty.

**Mac / Linux (primary path).** Use `script -qfc` to allocate a pty for the wrapped command:

```bash
rm -f /tmp/qbo-auth.log
script -qfc "set -a && source ~/.config/qbo/credentials.env && set +a && qbo auth login --sandbox" /tmp/qbo-auth.log < /dev/null > /dev/null 2>&1 &
QBO_PID=$!
```

The listener spawns on `localhost:8844`. Output goes to `/tmp/qbo-auth.log`.

**Windows (Git Bash) — fallback.** `script` is not present in Git Bash by default. Use the `--manual` mode + Playwright callback URL capture instead — see Step 9b alternate flow at the bottom of this step. This path is documented from the manual walkthrough but not extensively tested on Windows; flag any deviations to reviewers.

**Drive Playwright through the consent flow.** Read the auth URL printed to `/tmp/qbo-auth.log` (strip ANSI escape codes from terminal banners):

```bash
sleep 2
AUTH_URL="$(sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' /tmp/qbo-auth.log | grep -oE 'https://appcenter\.intuit\.com/connect/oauth2[^[:space:]]+' | head -1)"
```

Navigate Playwright to the URL:

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Take a `browser_snapshot`. Three possible states:

- **Auto-redirect to `localhost:8844/callback`** (fast — under a second; happens when the persistent Playwright profile already has Intuit consent for this app) → the qbo listener catches the redirect; nothing more to do in the browser. The browser tab will show ERR_CONNECTION_REFUSED briefly only because we're racing the listener's response — qbo completes regardless. Skip to the wait-for-success step below.
- **Sandbox company picker** (a list of practice companies the user has access to) → click the first sandbox company. If multiple, prefer one matching the user's region or the most-recently-created one.
- **Connect / Authorize button visible** ("Connect", "Allow access", "Authorize") → DOM-extract and click via `browser_evaluate`:

  ```js
  () => {
    const btns = Array.from(document.querySelectorAll('button, a'));
    const target = btns.find(b => /^(connect|authorize|allow)( access)?$/i.test((b.innerText||'').trim()));
    if (target) { target.scrollIntoView({block:'center'}); target.click(); return { clicked: true }; }
    return { clicked: false };
  }
  ```

**Wait for qbo to complete.** Poll the wrapped output file until you see `✓ authenticated for company <realm-id>`:

```bash
for i in $(seq 1 30); do
  if grep -q '✓ authenticated for company' /tmp/qbo-auth.log; then break; fi
  sleep 1
done
REALM_ID="$(sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' /tmp/qbo-auth.log | grep -oE 'authenticated for company [0-9]+' | awk '{print $4}')"
```

Capture the realm ID. If the loop times out without success, read the full log for the actual error and fall back to Step 9b below.

**Append `QBO_COMPANY_ID` to the credentials file** so future qbo calls don't need `--company-id`:

```bash
echo "QBO_COMPANY_ID=\"${REALM_ID}\"" >> ~/.config/qbo/credentials.env
```

**Step 9b — `--manual` fallback** (Windows Git Bash, or when `script` is unavailable):

1. Run `qbo auth login --sandbox --manual` in the background; capture stdout to a file or fifo.
2. Read the printed auth URL from the output.
3. Drive Playwright to the URL using the same consent-flow logic as the primary path.
4. After Playwright auto-Allow / consent click, the browser navigates to `http://localhost:8844/callback?code=...&state=...&realmId=...`. The page will show ERR_CONNECTION_REFUSED (no listener was started in `--manual` mode) but the URL is still in the address bar.
5. Capture the URL via `browser_evaluate(() => window.location.href)` — note: Chrome's error page replaces `window.location.href` with `chrome-error://chromewebdata/`, so capture **before** the error page renders by polling URL state during the redirect. Alternatively, retrieve the URL from the tabs list returned by Playwright snapshot (the open-tabs section retains the original navigation target for a short window).
6. Pipe the captured callback URL to qbo's stdin so it can extract the code and exchange it for tokens.
7. Wait for qbo to print success and exit.

> **Empirical caveat.** Step 9 was verified live on Linux + Hyprland (Wayland). Mac and Windows variants follow the same shape but have not been end-to-end tested in this PR. Reviewers walking the install on Mac / Windows should flag any divergence in browser-launch behavior (`xdg-open` vs `open` vs `start`) or in `script`'s behavior across BSD vs GNU userlands.

### Step 10 — Verify the connection

Tell the user: *"Let me just double-check everything is talking to QuickBooks correctly."*

Silently run two verification commands (also packaged together as [`scripts/smoke.sh`](scripts/smoke.sh), which runs both checks and exits non-zero on any failure — use it to re-confirm the connection later, or in CI):

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo auth status 2>&1
```

- Exit 0 with `authenticated true` → continue.
- Any other exit → diagnose and retry from Step 9.

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo company info --sandbox --json
```

- Exit 0 and valid JSON in stdout → parse `QueryResponse.CompanyInfo[0].CompanyName`. That's what you show the user in Step 11.
- Exit 5 (`not_found`) or "no company ID" → run `qbo company list --sandbox --json`. If exactly one company, run `qbo company switch <realm-id>` with its ID. If multiple, ask the user which one to use. If zero, the user has no sandbox company yet — tell them: *"You need to create a practice company first. Please go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds, then tell me to try again."*

### Step 11 — Success message

Tell the user, in one short message:

> "All done — I'm now connected to your QuickBooks practice company **[company name]**. You can ask me things like *'show me my recent invoices'* or *'what's my profit and loss this month?'*."

Save to memory that the qbo CLI is installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once qbo is installed and authenticated, shell out to it via Bash to answer questions and make changes. **Every Phase 2 command must be prefixed with the credentials source line**:

```bash
set -a && source ~/.config/qbo/credentials.env && set +a && qbo <command>
```

For brevity, the recipes below omit the prefix — but you must include it in every actual Bash invocation.

### Common Pattern 1 — List recent invoices

```bash
qbo list invoices --sandbox --json --results-only
```

Returns an array of invoice objects. Fields of interest: `Id`, `DocNumber`, `CustomerRef.name`, `TxnDate`, `DueDate`, `TotalAmt`, `Balance`, `CurrencyRef.value`.

**Use when:** The user asks "show me my invoices", "recent invoices", "latest invoices".

### Common Pattern 2 — List unpaid / overdue invoices

```bash
qbo list invoices --where "Balance > '0'" --sandbox --json --results-only
```

Returns only invoices with an outstanding balance. Derive "overdue" vs "pending" client-side by comparing `DueDate` to today.

**Use when:** The user asks "show me unpaid invoices", "what invoices are overdue?", "who owes me money?".

### Common Pattern 3 — Get a specific invoice by ID

```bash
qbo get invoice <id> --sandbox --json
```

Response is wrapped: `{"Invoice": {...}}`. Pipe through `jq '.Invoice'` to unwrap:

```bash
qbo get invoice 145 --sandbox --json | jq '.Invoice'
```

Line items are in the `Line` array. `SalesItemLineDetail` line types contain the billable amounts.

**Use when:** The user asks "show me invoice 145" or "details of invoice INV-1022". (QuickBooks uses numeric `Id` internally; `DocNumber` like "1022" is the user-facing label. If the user gives a `DocNumber`, first run `qbo list invoices --where "DocNumber = '1022'" --sandbox --json --results-only` to get the `Id`.)

### Common Pattern 4 — Create an invoice

Creating an invoice requires a customer (auto-create if missing) and at least one Product/Service Item. Confirm all details with the user in plain English before building the JSON.

Steps:

1. **Find or create the customer:**
   ```bash
   qbo list customers --where "DisplayName = 'Acme Corp'" --sandbox --json --results-only
   ```
   If empty, create one:
   ```bash
   echo '{"DisplayName":"Acme Corp"}' | qbo create customer -f - --sandbox --json
   ```
   Capture `Customer.Id` from the wrapped response.

2. **Find a default Product/Service Item** (QuickBooks requires one on every invoice line):
   ```bash
   qbo list items --sandbox --json --results-only
   ```
   Pick the first active item. Capture its `Id` and `Name`. If zero items exist, tell the user: "Before I can create invoices, QuickBooks needs at least one product or service in your company. Please open QuickBooks, go to Sales then Products and Services, create a basic service item, and tell me when it is done."

3. **Build and submit the invoice JSON:**
   ```bash
   echo '{
     "CustomerRef": {"value": "<customer-id>"},
     "Line": [{
       "Amount": 500,
       "DetailType": "SalesItemLineDetail",
       "Description": "Consulting services",
       "SalesItemLineDetail": {
         "ItemRef": {"value": "<item-id>"},
         "Qty": 1,
         "UnitPrice": 500
       }
     }]
   }' | qbo create invoice -f - --sandbox --json
   ```

   Optional top-level fields: `"DueDate": "2026-05-01"`, `"DocNumber": "INV-1042"`.

After the command returns, tell the user: "I've saved an invoice for **[Customer]** for **$[Amount]**. Review and send it from QuickBooks when ready." — never imply the invoice has been emailed.

### Common Pattern 5 — List customers

```bash
qbo list customers --sandbox --json --results-only
```

To search by name:

```bash
qbo list customers --where "DisplayName LIKE '%Smith%'" --sandbox --json --results-only
```

Fields of interest: `Id`, `DisplayName`, `PrimaryEmailAddr.Address`, `PrimaryPhone.FreeFormNumber`, `Balance`, `Active`.

**Use when:** The user asks "show me my customers", "find [name]", "list active customers".

### Common Pattern 6 — Create a customer

```bash
echo '{"DisplayName":"ABC Pty Ltd","PrimaryEmailAddr":{"Address":"info@abc.com"},"PrimaryPhone":{"FreeFormNumber":"+61 412 345 678"}}' \
  | qbo create customer -f - --sandbox --json
```

Only `DisplayName` is required. Email and phone are optional.

### Common Pattern 7 — List accounts (chart of accounts)

```bash
qbo list accounts --sandbox --json --results-only
```

Filter by type:

```bash
qbo list accounts --where "AccountType = 'Expense'" --sandbox --json --results-only
qbo list accounts --where "AccountType = 'Bank'" --sandbox --json --results-only
```

Valid `AccountType` values: `Bank`, `Accounts Receivable`, `Income`, `Expense`, `Cost of Goods Sold`, `Fixed Asset`, `Other Asset`, `Credit Card`, `Accounts Payable`, `Long Term Liability`, `Equity`.

### Common Pattern 8 — Bank transactions (purchases)

```bash
qbo list purchases --sandbox --json --results-only
```

QuickBooks models bank transactions as `Purchase` (money out) and `Deposit` (money in) entities. To get both money flows, run both and merge client-side:

```bash
qbo list purchases --sandbox --json --results-only
qbo list deposits --sandbox --json --results-only
```

Fields: `Id`, `TxnDate`, `EntityRef.name` (payee), `AccountRef.name`, `TotalAmt`, `CurrencyRef.value`.

### Common Pattern 9 — Profit and Loss report

```bash
qbo report profit-and-loss --sandbox --json
```

With a date range:

```bash
qbo report profit-and-loss --start-date 2026-01-01 --end-date 2026-12-31 --sandbox --json
```

Default date range is from 1 Jan of the current year to today. Response shape is `{"Header": {...}, "Rows": {...}}` — the `Rows.Row` tree is nested and needs recursive walking to flatten into a display table.

Present to the user as a clean table with sections (Income, Cost of Goods Sold, Gross Profit, Expenses, Net Income) — never as raw JSON.

### Common Pattern 10 — Balance Sheet report

```bash
qbo report balance-sheet --sandbox --json
```

With a specific as-of date:

```bash
qbo report balance-sheet --end-date 2026-04-14 --sandbox --json
```

Same nested response shape as Profit and Loss. Present as Assets / Liabilities / Equity sections.

---

## Advanced Entities — Delegate to the Official Skill

This skill documents the 10 most common workshop prompts. The `qbo` CLI supports full CRUD on **29 entities**: Account, Bill, BillPayment, Budget, Class, CompanyInfo, CreditMemo, Customer, Department, Deposit, Employee, Estimate, Invoice, Item, JournalEntry, Payment, PaymentMethod, Preferences, Purchase, PurchaseOrder, RefundReceipt, SalesReceipt, TaxCode, TaxRate, Term, TimeActivity, Transfer, Vendor, VendorCredit.

If the user asks about any entity not covered above (bills, vendors, estimates, journal entries, credit memos, sales receipts, time activities, transfers, etc.), **consult the official `voska/qbo-cli` skill installed in Phase 1 Step 3** — it documents every entity and every report type. You can also introspect at runtime:

```bash
qbo schema --json              # Full CLI tree with all entities
qbo schema get --json          # Schema for the get command specifically
qbo list <entity> --sandbox --json --results-only
```

---

## Prompt-to-Command Mapping

| What the user says | Command |
|---|---|
| "Show me my invoices" | `qbo list invoices --sandbox --json --results-only` |
| "List unpaid invoices" | `qbo list invoices --where "Balance > '0'" --sandbox --json --results-only` |
| "Show me invoice 1022" | `qbo get invoice <id> --sandbox --json \| jq '.Invoice'` |
| "Create an invoice for [client]" | Pattern 4 above |
| "Find [name] in my customers" | `qbo list customers --where "DisplayName LIKE '%<name>%'" --sandbox --json --results-only` |
| "Add a new customer" | `qbo create customer -f - --sandbox --json` with JSON via echo |
| "Show me my accounts" | `qbo list accounts --sandbox --json --results-only` |
| "List my bank transactions" | `qbo list purchases` + `qbo list deposits`, merge |
| "Show me recent payments" | `qbo list payments --sandbox --json --results-only` |
| "Profit and loss for this year" | `qbo report profit-and-loss --sandbox --json` |
| "Get the balance sheet" | `qbo report balance-sheet --sandbox --json` |
| "What QuickBooks company am I connected to?" | `qbo company info --sandbox --json` |
| "Connect my QuickBooks" / "Help me set up QuickBooks" | **Run Phase 1** |

---

## Exit Code Handling

`qbo` uses structured exit codes for machine-readable error handling. Every Phase 2 invocation should check the exit code and respond accordingly:

| Code | Name | What it means | How to respond |
|---|---|---|---|
| 0 | `success` | Operation completed | Parse stdout, present to user |
| 1 | `error` | General error | Translate stderr to plain English; retry once if likely transient |
| 2 | `usage` | Invalid arguments | Bug in the command you constructed; diagnose and fix |
| 3 | `empty` | No results | **Not an error.** Tell the user "I didn't find any [invoices/customers/etc.] matching that." Do not retry. |
| 4 | `auth_required` | Token expired or missing | **Run Phase 1 from Step 9** — re-do the browser sign-in. Do not ask the user to run anything; you run it. |
| 5 | `not_found` | Resource not found (e.g. invoice ID doesn't exist) | Tell the user "I couldn't find [resource]. Let me list the recent ones so you can pick." Then run a list command. |
| 6 | `forbidden` | Permission denied (rare on sandbox) | Translate: "QuickBooks says I don't have permission for that. This is unusual on a practice company — let me reconnect you." Run Phase 1 from Step 9. |
| 7 | `rate_limited` | API rate limit exceeded | Wait 30 seconds, then retry once. If still rate-limited, tell the user: "QuickBooks is asking me to slow down. Let me wait a minute and try again." |
| 8 | `retryable` | Transient error | **Automatically retry once** after a 2-second delay. If still failing, translate and continue as a regular error. |
| 10 | `config_error` | Missing/invalid config (e.g. `QBO_CLIENT_ID` not set) | You forgot to source `~/.config/qbo/credentials.env` in the Bash call. Fix the command and retry. If the file is missing entirely, run Phase 1 from Step 8. |

When in doubt, translate stderr to plain English, tell the user what you're doing next, and re-run or fall back to Phase 1 as appropriate. Never show raw exit codes or stderr to the user.

---

## Scope Limitations

The qbo connector **can** read and write: invoices, customers, accounts, bank transactions (purchases and deposits), customer payments, items, reports (P&L, Balance Sheet, and 4 others), and company info. It can also full-CRUD on 20+ additional entities via the official voska skill.

It **cannot** access:
- **Production QuickBooks companies** — this skill is sandbox only. Production requires Intuit app assessment and a non-localhost redirect URI, which is out of scope for the workshop.
- Payroll or employee payroll data
- QuickBooks Payments processing (credit card processing)
- File attachments
- Sending invoices by email (user does this in QuickBooks)
- Bank reconciliation / bank feed matching

It **requires** at least one Product/Service Item to exist in the company before creating an invoice. Auto-picks the first available Item if the user doesn't specify one.

---

## Behaviour Guidelines (Phase 2)

- **Always confirm before creating** invoices or customers — summarise what you are about to create and wait for the user's OK before calling the tool.
- **Invoices are saved, not emailed** — never imply an invoice has been sent. Say "I've saved the invoice in QuickBooks — review and send it from QuickBooks when ready."
- **Customer auto-creation** — when creating an invoice for a new customer, tell the user a new customer was created alongside the invoice.
- **Always prefix qbo calls** with `set -a && source ~/.config/qbo/credentials.env && set +a &&` — never call `qbo` without sourcing the credentials file first. `qbo` will exit 10 (`config_error`) if you forget.
- **Always use `--json --results-only`** on list commands when you're going to parse the output — it strips the QBO pagination wrapper and gives you a clean array.
- **Unwrap `get` responses** — they come back as `{"Invoice": {...}}`. Pipe through `jq '.Invoice'` (or the relevant entity key) to get the flat object.
- **Format currency correctly** — 2 decimal places, use the currency from the QuickBooks response.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as readable tables, not raw JSON.
- **Sandbox awareness** — remind the user gently, when relevant, that they are looking at practice data, not real figures. Say "practice company" when referring to the sandbox, not "sandbox".
- **Token errors (exit 4)** → run Phase 1 from Step 9. Do not ask the user to "run a command" — you run it.
- **Never log or echo credentials** — Client ID, Client Secret, and token values must never appear in any output visible to the user.

---

## Verification status

Honest record of what has been walked end-to-end versus what is written from snapshot evidence and still needs a live confirmation. After Phase 1, run [`scripts/smoke.sh`](scripts/smoke.sh) to confirm a working connection in one command — it checks the binary, the credentials, authentication, and a live sandbox company read, and exits non-zero on any failure.

| Path | Platform | Status |
|---|---|---|
| Full Phase 1 happy path — find existing app → redirect-URI upsert → credential extract → `qbo auth login` under a pty → live verify | Linux (Hyprland / Wayland) | ✅ Verified live 2026-05-29 |
| Phase 2 read/report commands (invoices, customers, P&L, balance sheet) | Linux | ✅ Exercised against a sandbox company |
| Phase 1 **create-new-app** path (Step 5b) | any | ⚠️ Written from workspace-UI snapshot evidence; not yet confirmed on a fresh Intuit account |
| Phase 1 install + auth | macOS | ⚠️ Same shape; not end-to-end tested — flag any `open` / `brew` divergence |
| Phase 1 `--manual` callback capture (Step 9b) | Windows (Git Bash) | ⚠️ Documented from a manual walkthrough; not extensively tested — flag any `script` / `start` divergence |

When you walk one of the ⚠️ paths successfully, update its status and date here so the record stays honest — this table is the proof-it-works artifact the kit is graded on. The per-step `⚠️` notes in Steps 5b, 9, and 9b are the point-of-use reminders for the same gaps.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer is closer to `github-connector` and `stripe-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting qbo auth or API errors
- **xero-connector**: Sibling accounting connector for Xero users — same Playwright-driven autonomous-Phase-1 pattern
- **stripe-connector** / **github-connector**: Sibling autonomous-Phase-1 connectors — closest reference shapes for the Playwright-drives-the-developer-portal pattern this skill follows
- **voska/qbo-cli** (external, installed in Phase 1 Step 3): Comprehensive reference for every qbo entity and command
