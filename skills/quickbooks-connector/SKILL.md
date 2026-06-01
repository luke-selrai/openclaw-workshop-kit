---
name: quickbooks-connector
description: "Install and operate the QuickBooks Online connector autonomously. Drives developer.intuit.com setup end-to-end inside a Playwright MCP browser: finds or creates an Intuit developer app named 'Claude Assistant', adds http://localhost:8844/callback to the Development redirect URIs, DOM-extracts the Client ID and Client Secret with the Show-credentials toggle bracketing the read, persists them to the OS-appropriate shell startup file(s) (~/.zshrc on macOS / Linux-zsh, ~/.bashrc on Linux-bash and Git Bash on Windows, $PROFILE on PowerShell) with idempotent BEGIN/END marker comments plus a ~/.config/qbo/credentials.env backup, and runs qbo auth login --sandbox --manual (the --manual flag suppresses qbo's default browser auto-open so Playwright stays the only browser; the localhost:8844 OAuth listener keeps running). The user's only manual moments are signing in to developer.intuit.com once and any 2FA challenge their Intuit account requires. Read and update QuickBooks Online accounting data via the qbo CLI (github.com/voska/qbo-cli). Handles invoices (list, view, create, filter by status), customers (list, create), the chart of accounts, bank transactions, customer payments, the Profit and Loss report, the Balance Sheet, and company information. Supports sandbox only — production is out of scope. Use this skill when the user asks about their QuickBooks, QBO, invoices, unpaid invoices, overdue invoices, customers, profit and loss, balance sheet, bank transactions, chart of accounts, payments received, or when they say 'connect my QuickBooks' or 'help me set up QuickBooks'. On the first use of any QuickBooks feature, run Phase 1 to install qbo and authenticate before attempting any tool calls."
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

This skill lets you read and update a user's QuickBooks Online data on their behalf. It is a **thin Bash wrapper around [`voska/qbo-cli`](https://github.com/voska/qbo-cli)** — a single-binary Go CLI with structured JSON output, machine-readable exit codes, and OS-keyring token storage. There is no MCP server, no Node.js layer, and no wrapper code in this repo.

The skill has two phases:

- **Phase 1 — Install & Auth (autonomous via Playwright).** Claude installs the `qbo` binary, drives the entire `developer.intuit.com` developer-app flow inside a Playwright MCP browser (find or create an app named "Claude Assistant", add `http://localhost:8844/callback` to the Development redirect URIs, DOM-extract Client ID + Client Secret with Show-credentials toggle bracketing), persists credentials to the OS-appropriate shell startup file(s) plus a `~/.config/qbo/credentials.env` backup, and runs `qbo auth login --sandbox --manual` (the `--manual` flag suppresses qbo's default browser auto-open so Playwright is the only browser driving the OAuth consent). The user's only manual moments are signing in to `developer.intuit.com` once and approving any 2FA prompt. Everything else — workspace + app discovery / creation, redirect URI upsert, credential capture, OAuth click-through — is autonomous.
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

Claude installs the `qbo` binary, drives developer.intuit.com end-to-end via Playwright MCP to set up the Intuit developer app + capture credentials + add the localhost redirect URI, persists those credentials to the user's shell startup file(s) (plus a small backup file at `~/.config/qbo/credentials.env`), and runs `qbo auth login --sandbox --manual` (the `--manual` flag suppresses qbo's default browser auto-open so Playwright is the only browser driving the OAuth flow; the listener on `localhost:8844` keeps running). The user's only role is signing in to developer.intuit.com when prompted (and only the first time — the persistent Playwright profile keeps the session for future runs) and approving any 2FA challenge their account requires.

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

### Step 8 — Persist the credentials (silent, cross-platform)

The qbo CLI reads `QBO_CLIENT_ID` and `QBO_CLIENT_SECRET` from the process environment. To make `qbo` work natively in any terminal the participant opens (the workshop UX goal — they should never need to source a file or remember a prefix), persist the credentials into the OS-appropriate shell startup file(s) using an idempotent marker block.

**Two writes happen here, in order:**

1. **Backup file** — always write `~/.config/qbo/credentials.env` (mode 600). This is the cross-block source of truth: Claude Code runs each fenced bash block as a separate `bash -c` invocation, so shell-level `export` in one block does NOT propagate to the next block. Every later step that needs the credentials sources this backup file at the top of its block.
2. **OS-appropriate rc file(s)** — the source the participant's shell sees on the next interactive shell launch, so a participant or maintainer typing `qbo …` in a fresh terminal after Phase 1 finds the env naturally.

**Step 8a — Backup file (always):**

```bash
mkdir -p ~/.config/qbo
umask 077
cat > ~/.config/qbo/credentials.env <<EOF
QBO_CLIENT_ID="<value from Step 7>"
QBO_CLIENT_SECRET="<value from Step 7>"
EOF
chmod 600 ~/.config/qbo/credentials.env
```

**Step 8b — rc file write (OS-conditional).** Define the marker-idempotent helper once, then dispatch by `uname`. The awk-based delete swallows the BEGIN..END block AND any leading blank lines so re-running the SKILL doesn't accumulate blank-line drift:

```bash
write_qbo_block_bash() {
  local rc="$1"
  local begin="# === BEGIN qbo credentials (managed by claude-workshop-kit) ==="
  local end="# === END qbo credentials ==="
  local var val
  mkdir -p "$(dirname "$rc")" 2>/dev/null || true
  touch "$rc"
  # Remove existing block + any leading blank-line drift
  awk -v b="$begin" -v e="$end" '
    BEGIN { in_block = 0; pending = "" }
    $0 == b { in_block = 1; pending = ""; next }
    in_block && $0 == e { in_block = 0; next }
    in_block { next }
    /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
  # One blank-line separator before the block if the file isn't already empty/blank-terminated
  [ -n "$(tail -n 1 "$rc")" ] && echo "" >> "$rc"
  {
    echo "$begin"
    # Iterate the fixed list of expected QBO vars; emit only those set in the env.
    # This lets Step 8 call us with 2 vars set, and Step 9 call us with 3 set.
    for var in QBO_CLIENT_ID QBO_CLIENT_SECRET QBO_COMPANY_ID; do
      val="$(printenv "$var" 2>/dev/null)"
      [ -n "$val" ] && printf 'export %s=%q\n' "$var" "$val"
    done
    echo "$end"
  } >> "$rc"
}

write_qbo_block_pwsh() {
  local profile="$1"
  local begin="# === BEGIN qbo credentials (managed by claude-workshop-kit) ==="
  local end="# === END qbo credentials ==="
  local var val
  mkdir -p "$(dirname "$profile")" 2>/dev/null || true
  touch "$profile"
  awk -v b="$begin" -v e="$end" '
    BEGIN { in_block = 0; pending = "" }
    $0 == b { in_block = 1; pending = ""; next }
    in_block && $0 == e { in_block = 0; next }
    in_block { next }
    /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "$profile" > "$profile.tmp" && mv "$profile.tmp" "$profile"
  [ -n "$(tail -n 1 "$profile")" ] && echo "" >> "$profile"
  {
    echo "$begin"
    for var in QBO_CLIENT_ID QBO_CLIENT_SECRET QBO_COMPANY_ID; do
      val="$(printenv "$var" 2>/dev/null)"
      [ -n "$val" ] && printf "\$env:%s = '%s'\n" "$var" "$val"
    done
    echo "$end"
  } >> "$profile"
}

# Dispatch by OS
set -a; . ~/.config/qbo/credentials.env; set +a
case "$(uname -s)" in
  Darwin)
    # macOS Catalina+ default: zsh. Older Macs may use bash — write to both for safety.
    write_qbo_block_bash "$HOME/.zshrc"
    [ -f "$HOME/.bash_profile" ] && write_qbo_block_bash "$HOME/.bash_profile"
    ;;
  Linux)
    SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
    if [ "$SHELL_NAME" = "zsh" ]; then
      write_qbo_block_bash "$HOME/.zshrc"
    else
      write_qbo_block_bash "$HOME/.bashrc"
    fi
    ;;
  MINGW*|CYGWIN*|MSYS*)
    # Windows: write to BOTH Git Bash rc AND PowerShell profile(s).
    write_qbo_block_bash "$HOME/.bashrc"
    # PowerShell 5.1 (Windows default) and PowerShell 7 use different profile paths.
    # Write to both so the participant's shell choice doesn't matter.
    UP="${USERPROFILE:-$HOME}"
    write_qbo_block_pwsh "$UP/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
    write_qbo_block_pwsh "$UP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
    ;;
esac
```

> **No "export in current Claude session" step.** Earlier drafts of this SKILL included a Step 8c that ran `export QBO_CLIENT_ID; export QBO_CLIENT_SECRET` to "make them available to Step 9". That was a misunderstanding of Claude Code's Bash tool — each fenced bash block runs as a separate `bash -c` invocation, so shell-level exports never propagate across blocks. The backup file (Step 8a) is what carries the credentials across block boundaries; every later step that needs them prepends `set -a; . ~/.config/qbo/credentials.env; set +a`.

> **Why the rc-file write, not just the backup file.** Earlier versions of this SKILL kept credentials only in `~/.config/qbo/credentials.env` and required every qbo invocation to prefix `set -a && source ~/.config/qbo/credentials.env && set +a && qbo …`. That works for Claude-driven invocations (Claude can always add the prefix) but creates friction the moment a participant or maintainer types `qbo …` directly in a fresh terminal — they get `✗ set QBO_CLIENT_ID and QBO_CLIENT_SECRET before logging in`. Persisting the env vars in the user's shell startup file removes that friction. Trade-off: the credentials are now in the shell environment of every shell the participant opens, not just qbo-invoking subshells. For QBO **sandbox-only** credentials (the scope of this SKILL — production is out of scope), that surface area is acceptable.

> **Idempotency.** Re-running Phase 1 (e.g., because tokens expired and the participant needs a fresh Client Secret) calls `write_qbo_block_*` again, which detects the existing marker block, removes it (along with any leading blank-line drift), and appends the fresh block. Re-running N times always leaves exactly one block.

> **Marker comments are sacred.** Never rename the `# === BEGIN qbo credentials (managed by claude-workshop-kit) ===` / `# === END qbo credentials ===` strings. The awk delete matches them by exact equality, so a renamed marker means future re-runs orphan the old block rather than replacing it.

Never echo the captured values back to the user. Never include them in any output visible to the user.

### Step 9 — Run qbo auth login (autonomous via Playwright)

Tell the user: *"Connecting to QuickBooks now — this takes about ten seconds."*

The `qbo` CLI on default settings does two things: it spawns an OAuth listener on `localhost:8844`, AND it tries to auto-open the OAuth URL in the user's default browser (via `xdg-open` on Linux, `open` on macOS, `rundll32 url.dll,FileProtocolHandler` on Windows). The auto-open races Playwright — the participant sees their default browser pop up alongside the Playwright window, which is confusing and means Playwright is no longer actually driving the credential moment.

The fix is the **`--manual` flag**, which suppresses the auto-open while keeping the listener running. Verified live 2026-06-01: `qbo auth login --sandbox --manual` does NOT shut down the listener (the earlier docs that claimed it did were wrong); it only skips the platform-specific browser-open call. Playwright is the only browser involved, and qbo's listener still catches the callback at `localhost:8844`.

**Launch qbo in the background** (source credentials from the backup file written in Step 8a; each fenced bash block is a separate `bash -c` invocation so the env vars from prior steps don't persist):

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
rm -f /tmp/qbo-auth.log
nohup qbo auth login --sandbox --manual > /tmp/qbo-auth.log 2>&1 &
QBO_PID=$!
sleep 2
```

No pty wrapper, no fifo, no stdin pipe — the listener stays alive on its own as long as the process runs.

**Read the auth URL** from the log (strip any ANSI banner codes):

```bash
AUTH_URL="$(sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' /tmp/qbo-auth.log | grep -oE 'https://appcenter\.intuit\.com/connect/oauth2[^[:space:]]+' | head -1)"
```

If `AUTH_URL` is empty after 5 seconds, sleep another 3 and retry. If still empty, the qbo process has likely errored — `cat /tmp/qbo-auth.log` for the cause and diagnose silently.

**Drive Playwright through the consent flow.** Navigate to the URL:

```
mcp__playwright__browser_navigate({ url: "<AUTH_URL>" })
```

Take a `browser_snapshot`. Three possible states:

- **Auto-redirect to `localhost:8844/callback`** (fast — under a second; happens when the persistent Playwright profile already has Intuit consent for this app) → qbo's listener catches the redirect; the page shows "Authenticated! You can close this window." Skip to the wait-for-success step below.
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

**Wait for qbo to complete AND persist QBO_COMPANY_ID in one block.** Polling for `✓ authenticated for company <realm-id>` and the subsequent persistence must live in the same fenced bash block because `REALM_ID` is a shell variable — Claude Code's Bash tool runs each fenced bash block as a separate `bash -c` invocation, so a `REALM_ID=` assignment in one block doesn't survive into the next. If the loop times out without success, the block exits non-zero and you read `/tmp/qbo-auth.log` for the actual error. Common causes: the `http://localhost:8844/callback` redirect URI hasn't propagated yet on Intuit's side (re-check Step 6 ran and saved), or the participant cancelled the consent flow in Playwright.

This block is **self-contained** — it sources `~/.config/qbo/credentials.env` (so `QBO_CLIENT_ID` and `QBO_CLIENT_SECRET` are in the env when the rc-write helpers iterate the env-var list) and redefines the helper functions inline. If you update the helper bodies, update them in BOTH Step 8b and here.

```bash
set -a; . ~/.config/qbo/credentials.env; set +a

# Wait for qbo to print its success line
for i in $(seq 1 30); do
  if grep -q '✓ authenticated for company' /tmp/qbo-auth.log; then break; fi
  sleep 1
done
REALM_ID="$(sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' /tmp/qbo-auth.log | grep -oE 'authenticated for company [0-9]+' | awk '{print $4}')"

if [ -z "$REALM_ID" ]; then
  echo "ERROR: qbo auth login did not complete; log follows:" >&2
  cat /tmp/qbo-auth.log >&2
  exit 1
fi
export QBO_COMPANY_ID="$REALM_ID"

# --- Re-define helpers (identical to Step 8b — keep in sync if either is updated) ---
write_qbo_block_bash() {
  local rc="$1"
  local begin="# === BEGIN qbo credentials (managed by claude-workshop-kit) ==="
  local end="# === END qbo credentials ==="
  local var val
  mkdir -p "$(dirname "$rc")" 2>/dev/null || true
  touch "$rc"
  awk -v b="$begin" -v e="$end" '
    BEGIN { in_block = 0; pending = "" }
    $0 == b { in_block = 1; pending = ""; next }
    in_block && $0 == e { in_block = 0; next }
    in_block { next }
    /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"
  [ -n "$(tail -n 1 "$rc")" ] && echo "" >> "$rc"
  {
    echo "$begin"
    for var in QBO_CLIENT_ID QBO_CLIENT_SECRET QBO_COMPANY_ID; do
      val="$(printenv "$var" 2>/dev/null)"
      [ -n "$val" ] && printf 'export %s=%q\n' "$var" "$val"
    done
    echo "$end"
  } >> "$rc"
}

write_qbo_block_pwsh() {
  local profile="$1"
  local begin="# === BEGIN qbo credentials (managed by claude-workshop-kit) ==="
  local end="# === END qbo credentials ==="
  local var val
  mkdir -p "$(dirname "$profile")" 2>/dev/null || true
  touch "$profile"
  awk -v b="$begin" -v e="$end" '
    BEGIN { in_block = 0; pending = "" }
    $0 == b { in_block = 1; pending = ""; next }
    in_block && $0 == e { in_block = 0; next }
    in_block { next }
    /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "$profile" > "$profile.tmp" && mv "$profile.tmp" "$profile"
  [ -n "$(tail -n 1 "$profile")" ] && echo "" >> "$profile"
  {
    echo "$begin"
    for var in QBO_CLIENT_ID QBO_CLIENT_SECRET QBO_COMPANY_ID; do
      val="$(printenv "$var" 2>/dev/null)"
      [ -n "$val" ] && printf "\$env:%s = '%s'\n" "$var" "$val"
    done
    echo "$end"
  } >> "$profile"
}
# --- end helpers ---

# Backup file — idempotent grep-or-append, no dupes on re-run
mkdir -p ~/.config/qbo
umask 077
if grep -q '^QBO_COMPANY_ID=' ~/.config/qbo/credentials.env 2>/dev/null; then
  sed -i.bak "s|^QBO_COMPANY_ID=.*|QBO_COMPANY_ID=\"${REALM_ID}\"|" ~/.config/qbo/credentials.env
  rm -f ~/.config/qbo/credentials.env.bak
else
  echo "QBO_COMPANY_ID=\"${REALM_ID}\"" >> ~/.config/qbo/credentials.env
fi
chmod 600 ~/.config/qbo/credentials.env

# rc file(s) — same dispatch as Step 8b, now with QBO_COMPANY_ID also in the env so the
# helpers emit the 3-export block (replacing the prior 2-export block). Re-run idempotent.
case "$(uname -s)" in
  Darwin)
    write_qbo_block_bash "$HOME/.zshrc"
    [ -f "$HOME/.bash_profile" ] && write_qbo_block_bash "$HOME/.bash_profile"
    ;;
  Linux)
    SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
    if [ "$SHELL_NAME" = "zsh" ]; then
      write_qbo_block_bash "$HOME/.zshrc"
    else
      write_qbo_block_bash "$HOME/.bashrc"
    fi
    ;;
  MINGW*|CYGWIN*|MSYS*)
    write_qbo_block_bash "$HOME/.bashrc"
    UP="${USERPROFILE:-$HOME}"
    write_qbo_block_pwsh "$UP/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1"
    write_qbo_block_pwsh "$UP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
    ;;
esac
```

> **Why the iterate-and-detect pattern.** The first call (Step 8b) runs before `qbo auth login`, when only `QBO_CLIENT_ID` and `QBO_CLIENT_SECRET` are known. The second call (here) runs after `qbo auth login` succeeds and `QBO_COMPANY_ID` has been exported. Same helper logic, same files — the awk delete removes the prior 2-var block before appending the new 3-var block. After Phase 1 completes, every relevant rc file contains all three exports.

> **Empirical history.** This Step 9 was verified live 2026-06-01 on Linux + Hyprland (Wayland). qbo auth login --sandbox --manual completed in ~3 seconds with no fifo, no stdin pipe, no pty wrapper. The persistent Playwright profile's stored Intuit consent meant the auth URL auto-redirected to `localhost:8844/callback` and qbo's listener caught it cleanly. macOS + Windows variants of this Step 9 follow the same shape (the `--manual` flag has identical semantics across all three platforms per the Go source at `github.com/voska/qbo-cli/internal/auth/oauth.go:182`), but have not been end-to-end tested in this PR. Reviewers walking the install on macOS or Windows should flag any divergence.

### Step 10 — Verify the connection

Tell the user: *"Let me just double-check everything is talking to QuickBooks correctly."*

Silently run two verification commands. Each is in its own bash block (separate `bash -c` invocations), so each must source the backup file:

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
qbo auth status 2>&1
```

- Exit 0 with `authenticated true` → continue.
- Any other exit → diagnose and retry from Step 9.

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
qbo company info --sandbox --json
```

- Exit 0 and valid JSON in stdout → parse `QueryResponse.CompanyInfo[0].CompanyName`. That's what you show the user in Step 11.
- Exit 5 (`not_found`) or "no company ID" → run `qbo company list --sandbox --json`. If exactly one company, run `qbo company switch <realm-id>` with its ID. If multiple, ask the user which one to use. If zero, the user has no sandbox company yet — tell them: *"You need to create a practice company first. Please go to developer.intuit.com → My Hub → Sandbox → Add sandbox → QuickBooks Online Plus. Wait 30 seconds, then tell me to try again."*

### Step 11 — Success message

Tell the user, in one short message:

> "All done — I'm now connected to your QuickBooks practice company **[company name]**. You can ask me things like *'show me my recent invoices'* or *'what's my profit and loss this month?'*."

Save to memory that the qbo CLI is installed and authenticated, so on the next use you go straight to Phase 2.

---

## PHASE 2 — Use Tools

Once Phase 1 has completed (qbo installed AND `qbo auth login --sandbox --manual` succeeded), there are TWO distinct execution contexts to keep in mind:

**Context A — interactive shells the participant opens after Phase 1.** The rc-file marker block (written by Step 8b and refreshed at the end of Step 9 to include `QBO_COMPANY_ID`) is sourced automatically by the shell on launch. The participant can type `qbo …` directly in a new terminal and it just works:

```bash
qbo <command>          # Works in any new interactive shell the participant opens
```

**Context B — Claude's own Bash tool invocations during Phase 2.** Claude Code's Bash tool runs each fenced bash block as a separate `bash -c` invocation, which does NOT source the user's rc file. So Phase 2 bash blocks executed by Claude must source the backup file (`~/.config/qbo/credentials.env`, which Phase 1 keeps in sync with the rc-file contents):

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
qbo <command>          # Claude-executed bash block
```

For brevity, the Phase 2 recipes below show just `qbo <command>`. When Claude runs them via the Bash tool, prepend the source line. When the participant runs them in their own terminal, they don't need to.

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
- **qbo finds its credentials in the environment** (`QBO_CLIENT_ID`, `QBO_CLIENT_SECRET`, `QBO_COMPANY_ID`). Phase 1 writes these to the user's shell startup file(s) so any *new interactive shell* sees them. But Claude Code's Bash tool runs each fenced bash block as a separate `bash -c` invocation, which does NOT source the user's rc file — so when YOU run a qbo command via Bash, always prepend `set -a; . ~/.config/qbo/credentials.env; set +a;` to source the backup file. If qbo exits 10 (`config_error`), the most likely cause is that you forgot the source prefix.
- **Always use `--json --results-only`** on list commands when you're going to parse the output — it strips the QBO pagination wrapper and gives you a clean array.
- **Unwrap `get` responses** — they come back as `{"Invoice": {...}}`. Pipe through `jq '.Invoice'` (or the relevant entity key) to get the flat object.
- **Format currency correctly** — 2 decimal places, use the currency from the QuickBooks response.
- **Present reports clearly** — when showing P&L or Balance Sheet, format as readable tables, not raw JSON.
- **Sandbox awareness** — remind the user gently, when relevant, that they are looking at practice data, not real figures. Say "practice company" when referring to the sandbox, not "sandbox".
- **Token errors (exit 4)** → run Phase 1 from Step 9. Do not ask the user to "run a command" — you run it.
- **Never log or echo credentials** — Client ID, Client Secret, and token values must never appear in any output visible to the user.

---

## Related Skills

- **first-run-setup**: The source pattern for conversational bootstrap (Phase 1's communication-rules layer borrows from this; Phase 1's autonomy layer is closer to `github-connector` and `stripe-connector`)
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended): For troubleshooting qbo auth or API errors
- **xero-connector**: Sibling accounting connector for Xero users — same Playwright-driven autonomous-Phase-1 pattern
- **stripe-connector** / **github-connector**: Sibling autonomous-Phase-1 connectors — closest reference shapes for the Playwright-drives-the-developer-portal pattern this skill follows
- **voska/qbo-cli** (external, installed in Phase 1 Step 3): Comprehensive reference for every qbo entity and command
