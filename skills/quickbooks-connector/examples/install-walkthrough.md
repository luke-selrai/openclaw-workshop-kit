# quickbooks-connector — install walkthrough

This file shows what a successful Phase 1 install looks like end-to-end. It's a narrative reference for two audiences:

- **Workshop attendees** debugging an install that didn't quite finish ("did the SKILL get this far?")
- **Maintainers** verifying that a change to the SKILL didn't regress the happy path

The walkthrough is synthesised from a verified-live dry-run on 2026-06-01 (Linux + Wayland, qbo-cli v0.2.0, Intuit sandbox). Times in parentheses are from that run.

## What success looks like (the 60-second version)

A workshop attendee says **"set up QuickBooks"** or **"connect my QuickBooks"** to Claude. From their perspective:

1. A browser window opens. Claude says: *"Opening a browser window for you — please sign in to developer.intuit.com when it appears (and approve any 2FA prompt). I'll do the rest. About two minutes."*
2. The attendee signs in to their Intuit developer account (and handles 2FA if their account asks). They do nothing else.
3. ~2 minutes later Claude says: *"All done — I'm now connected to your QuickBooks practice company **Sandbox Company AU e43d**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this month?'."*

That's the whole user-facing experience. Everything else is autonomous.

## What Claude is actually doing under the hood

Each step below corresponds to a section in `SKILL.md`. Times are from the 2026-06-01 dry-run on a returning Intuit account (Claude Assistant app already exists). A fresh-account install adds ~30 seconds for the create-app form.

### Step 1 — Is qbo installed? (0s)

```
$ qbo --version
Usage: qbo <command> [flags]
QuickBooks Online CLI for humans and AI agents.
...
$? = 0
```

Exit 0 → qbo is installed, skip to Step 4. (Note: qbo doesn't actually have a `--version` flag; it prints help on any non-recognised root command and exits 0. The SKILL still routes correctly.)

If qbo wasn't installed (exit 127), Steps 2-3 install it via Homebrew / Scoop / Go install / binary download fallback. The 2026-06-01 dry-run skipped these because qbo was already on PATH.

### Step 4 — Open developer.intuit.com and confirm a logged-in session (~30s on a returning account)

Playwright navigates to `https://developer.intuit.com/workspaces`. One of two states:

- **Already signed in** (persistent Playwright profile retained the session) → land on `/workspaces` showing your workspace cards. Continue silently.
- **Signed out** (default for first-time fresh install or after Intuit session expiry) → land on `accounts.intuit.com/app/sign-in`. Claude polls `browser_wait_for({ text: "Workspaces" })` silently until the user signs in. No prompt to re-ask.

### Step 5 — Find or create the "Claude Assistant" app (~10s)

In the workspace dashboard at `developer.intuit.com/dashboard?id=<workspace-id>&tab=apps`:

- **App exists** → Claude clicks the existing card. URL becomes `developer.intuit.com/appdetail/overview?appId=<base64-prefix:uuid>&id=<workspace-id>`. Both IDs captured for Step 6 / 7 navigation.
- **App doesn't exist** → Claude clicks the `+` create-card, picks "QuickBooks Online and Payments", names the app "Claude Assistant", ticks the `com.intuit.quickbooks.accounting` scope, clicks **Create app**. Captures the new appId from the post-create URL.

The 2026-06-01 dry-run found the existing app (created 05/08/2026 in a prior session). `appId=djQuMTo6OGQzYmJlYTI3Yg:4204facc-0232-491c-842d-44c19fcc03ab`, `workspace=9341456862813230`.

### Step 6 — Redirect URI idempotent upsert (~5s)

Claude navigates to `appdetail/settings?...&tab=redirect-uris`, reads all `input[aria-label="url-location"]` values from the Development tabpanel, and checks whether `http://localhost:8844/callback` is already in the list.

- **Already present** → skip the Save click. No-op. (This was the dry-run path.)
- **Not present** → click **Add URI**, fill the new input via a React-friendly setter (native HTMLInputElement.prototype.value setter + dispatched input/change events), click **Save**, reload and verify.

The 2026-06-01 dry-run had 3 URIs already registered: `https://developer.intuit.com/v2/OAuth2Playground/RedirectUrl`, `http://localhost:3000/callback`, `http://localhost:8844/callback`. Idempotent — no Save triggered.

### Step 7 — DOM-extract Client ID and Client Secret (~15s)

Claude navigates to `appdetail/keys?...`. The values are masked behind a "Show credentials" toggle.

The credential read uses a **clipboard-transit pattern** so the literal values never appear in tool returns or the conversation transcript:

1. Save the user's existing clipboard (so we can restore it after).
2. Click **Show credentials** to reveal the values in the DOM.
3. `browser_evaluate` walks up from the "Client ID:" / "Client secret:" labels to find the values, calls `navigator.clipboard.writeText(JSON.stringify({client_id, client_secret}))`, returns ONLY `{ ok: true, client_id_len: 50, client_secret_len: 40 }`.
4. Click **Show credentials** again to hide.
5. `wl-paste` reads the clipboard, `jq` formats the two `QBO_CLIENT_ID="..."` / `QBO_CLIENT_SECRET="..."` lines, redirected directly to `~/.config/qbo/credentials.env` (mode 600) without ever touching stdout.
6. Restore the user's original clipboard.

A workshop attendee never sees their Client ID or Client Secret — the SKILL design keeps them in the file system, not the conversation.

### Step 8 — Persist credentials (cross-platform shell-env write) (~2s)

Two writes happen in this order:

1. **`~/.config/qbo/credentials.env`** — mode 600 backup file. Carries credentials across Claude Code's separate-`bash -c`-per-block invocations.
2. **OS-appropriate shell startup file(s)** — with idempotent `# === BEGIN qbo credentials (managed by claude-workshop-kit) ===` / `# === END qbo credentials ===` marker block:

   | OS | rc file(s) |
   |---|---|
   | macOS | `~/.zshrc` (Catalina+ default); `~/.bash_profile` if present |
   | Linux | `~/.zshrc` or `~/.bashrc` based on `$SHELL` |
   | Windows | BOTH `~/.bashrc` (Git Bash) AND `$PROFILE` in PowerShell 5.1 + PowerShell 7 locations |

The helper iterates a fixed list `QBO_CLIENT_ID QBO_CLIENT_SECRET QBO_COMPANY_ID` and emits `export` (or `$env:`) lines only for vars set in the env at call time. This Step 8 call emits 2 lines (the company ID isn't known yet); Step 9 re-calls the same helper after `qbo auth login` succeeds and emits the 3-line block.

awk-based delete removes any prior marker block AND any leading blank-line drift, so re-running Phase 1 always leaves exactly one block, no matter how many times.

### Step 9 — Run qbo auth login (~3s)

Claude launches `qbo auth login --sandbox --manual` in the background. The `--manual` flag is critical: without it, qbo's Go-side `openBrowser()` (`internal/auth/oauth.go:182`) calls `xdg-open` / `open` / `rundll32` to auto-launch the user's default browser, which would race the Playwright window. With `--manual`, that call is suppressed; the localhost:8844 OAuth listener still spawns and waits for the callback.

Claude reads the auth URL from `/tmp/qbo-auth.log`, navigates Playwright to it, and either:

- **Auto-redirects to `localhost:8844/callback`** under a second (persistent Playwright profile already has Intuit consent for this app) → qbo's listener catches the redirect; the page shows "Authenticated! You can close this window."
- **Shows a sandbox company picker or Connect / Authorize button** → Playwright clicks the first sandbox company / the Connect button.

The dry-run hit path #1 in ~0.5s.

A single bash block then captures `REALM_ID` from `/tmp/qbo-auth.log`, appends `QBO_COMPANY_ID="<realm-id>"` to the backup file (idempotent grep-or-append), and re-calls `write_qbo_block_bash` / `write_qbo_block_pwsh` to refresh the rc-file marker block with all 3 exports. The combined block is necessary because `REALM_ID` is a shell variable — it doesn't survive across separate `bash -c` invocations.

### Step 10 — Verify the connection (~1s)

Two source-prefixed checks (Claude's Bash invocations don't inherit the rc file; the source prefix is needed inside Claude even though it's not needed for the participant's interactive shells):

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
qbo auth status 2>&1
```

Expected: `authenticated=true, expired=false`. From the dry-run:
```
authenticated  company_id        company_name  environment  expired  token_expiry
true           9341456862969697                sandbox      false    2026-06-01T17:22:10+08:00
```

```bash
set -a; . ~/.config/qbo/credentials.env; set +a
qbo company info --sandbox --json | jq -r '.QueryResponse.CompanyInfo[0].CompanyName'
```

Expected: the practice company's name. From the dry-run: `Sandbox Company AU e43d`.

### Step 11 — Success message (~0s)

Claude tells the user: *"All done — I'm now connected to your QuickBooks practice company **[company name]**. You can ask me things like 'show me my recent invoices' or 'what's my profit and loss this month?'."*

That's the end of Phase 1. The skill saves to memory that qbo is installed and authenticated, so next session goes straight to Phase 2.

## Phase 2 smoke test — fetching real data

After Phase 1 completes, an outsider can verify the install with these two commands. Run them in a fresh terminal (any new interactive shell sources the rc-file marker block and gets the QBO env vars without a prefix):

```bash
# In a fresh interactive shell — no source prefix needed
$ qbo auth status
authenticated  company_id        company_name  environment  expired  token_expiry
true           9341456862969697                sandbox      false    2026-06-01T17:22:10+08:00

$ qbo list invoices --sandbox --json --results-only | jq 'length'
18

$ qbo list customers --sandbox --json --results-only | jq 'length'
27
```

If those numbers look like real sandbox data (and not `[]` or an error), the install worked end-to-end.

## Two known platform-level issues to be aware of

These aren't QBO-SKILL bugs. They're Claude Code / Playwright MCP behaviours that affect every connector SKILL with the same install shape. Documented here so workshop attendees aren't surprised.

1. **Skill-tool `$N` arg interpolation.** If a participant invokes the SKILL via `Skill quickbooks-connector` with multi-word args (e.g. "set up my QuickBooks"), Claude Code's Skill-tool display shell-interpolates `$N` positional refs in the SKILL.md content against the words of the args string. Bash positional parameters in the SKILL's code blocks get corrupted in what Claude sees. The disk file is unaffected. Workaround: Claude must Read the SKILL.md from disk for code blocks, not trust the loaded display.

2. **Playwright `browser_snapshot` captures password values.** When the Playwright browser hits a sign-in page, password managers (Keeper, 1Password, browser autofill) populate the password field on page load — before the user clicks Sign in. A snapshot taken at that moment returns the literal password value in the accessibility tree. Mitigation: don't snapshot the sign-in page; use `browser_wait_for({ text: "<post-auth marker>" })` instead.

Both findings are logged as memory references for maintainers and have not yet been addressed upstream.

## When to re-read this file

- A workshop attendee reports "the SKILL got stuck" → walk through each step's expected output against what they actually saw. Most "stuck" reports correspond to a specific step (Steps 4-9 are where the interactive moments live).
- A maintainer changes the SKILL's code → use the dry-run expected outputs as a regression-test baseline. If a step's output drifts from what's documented here, the change either broke something or this walkthrough is stale.
- Onboarding a new maintainer to the SKILL → read this end-to-end before opening SKILL.md. The walkthrough explains the *why* of design choices that SKILL.md's body assumes you know.

## See also

- `../SKILL.md` — the actual instructions Claude follows.
- CWK PR #284 — the cross-platform shell-env persistence + `--manual` auth refactor that this walkthrough verifies.
- selr-kit-index PR #170 — the initial Pass 1 vet that scored this SKILL 4/4/5/5/3 (Promising). This walkthrough is the artifact that bumps Evidence to 4 (or 5 when a screencast follows).
