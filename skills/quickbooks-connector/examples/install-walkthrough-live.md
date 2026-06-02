# QuickBooks Connector — Live (Production) Install Walkthrough

This is a concrete, time-stamped example of what the Phase 1L (live-mode) install looks like end-to-end. It mirrors `install-walkthrough.md` (which documents the sandbox flow) and is intended to be read alongside the SKILL.md when debugging a specific step.

**When does Phase 1L run?** When Phase 0 picks `MODE=production` — i.e., when the participant says "real", "live", "connect", or gives no specific answer to the "real vs practice company" question.

**Pre-conditions** (taken from this walkthrough's reference machine, 2026-06-02):

- macOS 14, Linux Wayland, or Windows Git Bash with Playwright MCP installed.
- Node ≥ 18, git, Playwright MCP browser session opened.
- Internet access (Cloudflare + Intuit OAuth endpoints reachable).
- Participant has (or is willing to create) a Cloudflare account and an Intuit developer account.
- Participant has at least one real QuickBooks Online company they own.

The reference run below took ~6 minutes total, with about 2 minutes of that being human moments (Cloudflare sign-in, Intuit sign-in, two consent clicks). Everything else was Playwright-driven.

---

## Step 0 — Mode detection

Conversation:

```
User: Connect my QuickBooks.
Claude: I can connect QuickBooks for you — want to connect your **real
        QuickBooks** (your actual company data) or set up a **practice
        company** first to try it out? Real is the default — most
        business owners want real.
User: Real, please.
```

Claude sets `MODE=production` and continues to Phase 1L.

---

## Step 1L-A.1 — Install wrangler

```bash
$ command -v wrangler || npm install -g wrangler
# (~8 seconds if installing fresh; instant if already present)

$ wrangler --version
 ⛅️ wrangler 3.84.1
```

---

## Step 1L-A.2 — Cloudflare login

Reference run: participant already had a Cloudflare account but was not authenticated to wrangler.

```bash
$ wrangler login
⎔ Attempting to login via OAuth...
Opening a link in your default browser:
https://dash.cloudflare.com/oauth2/auth?response_type=code&client_id=...
```

Claude captures the URL from the log and navigates Playwright to it. Cloudflare's consent screen appears. Claude clicks **Allow**. After ~3 seconds:

```
Successfully logged in.
```

`wrangler whoami` confirms:

```
👋 You are logged in with an OAuth Token, associated with the email reference-user@example.com.
```

---

## Step 1L-A.3 — Build legal-pages directory

```bash
$ SLUG="qbo-legal-9876543"
$ PAGES_DIR="$HOME/.local/share/qbo-mcp/pages-$SLUG"
$ mkdir -p "$PAGES_DIR/legal" "$PAGES_DIR/qbo"
$ # Copy the 4 templates from the SKILL's assets/legal/ dir into the structured layout
$ ls -la "$PAGES_DIR/legal" "$PAGES_DIR/qbo"
$PAGES_DIR/legal:
-rw-r--r--  1 user  staff  2843 Jun  2 11:17 eula.html
-rw-r--r--  1 user  staff  3808 Jun  2 11:17 privacy.html

$PAGES_DIR/qbo:
-rw-r--r--  1 user  staff  1082 Jun  2 11:17 launch.html
-rw-r--r--  1 user  staff  1091 Jun  2 11:17 disconnect.html
```

---

## Step 1L-A.4 — Pages deploy

```bash
$ wrangler pages deploy "$PAGES_DIR" --project-name="$SLUG" --branch=main
✨ Compiled Worker successfully
🌍 Uploading... (4/4)

✨ Success! Uploaded 4 files (1.43 sec)

✨ Deployment complete! Take a peek over at https://5c8b3a91.qbo-legal-9876543.pages.dev
```

The unique deploy URL is `https://5c8b3a91.qbo-legal-9876543.pages.dev`. The stable alias is `https://qbo-legal-9876543.pages.dev` (without the per-deploy prefix). Claude uses the stable alias for the Intuit form values.

---

## Step 1L-A.5 — Smoke-test URLs

```bash
$ PAGES_URL="https://qbo-legal-9876543.pages.dev"
$ for path in /legal/eula.html /legal/privacy.html /qbo/launch.html /qbo/disconnect.html; do
    curl -sI -o /dev/null -w "$path -> %{http_code}\n" "$PAGES_URL$path"
  done
/legal/eula.html -> 200
/legal/privacy.html -> 200
/qbo/launch.html -> 200
/qbo/disconnect.html -> 200
```

All four return 200. Total elapsed for Step 1L-A: ~90 seconds.

---

## Step 1L-B — Intuit sign-in + app creation

```
Claude: Opening a browser for you — please sign in to developer.intuit.com,
        and approve any 2FA. About a minute.
```

(Participant signs in.) Playwright detects the post-sign-in `Workspaces` page via `browser_wait_for({ text: "Workspaces" })` — no sign-in page snapshot.

Reference run: app `Claude Assistant` was already created on a prior sandbox install. Claude reused it (no recreate). For a brand-new run, the create-app form fields (name = "Claude Assistant", scope = `com.intuit.quickbooks.accounting`) are identical to Phase 1S Step 5.

Navigation to Production Settings:

```
mcp__playwright__browser_navigate({
  url: "https://developer.intuit.com/appdetail/settings?appId=djQuMTo6OGQzYmJlYTI3Yg:4204facc-0232-491c-842d-44c19fcc03ab&id=9341456862813230&tab=production"
})
```

`browser_wait_for({ text: "Production app settings" })` confirms the page loaded.

---

## Step 1L-C — Production Settings form fill

Reference run: all 5 fields empty (first Production install for this app).

Playwright fills each field via the React-friendly setter pattern:

| Field | Value typed |
|---|---|
| Host domain | `qbo-legal-9876543.pages.dev` |
| App URL (Launch URL) | `https://qbo-legal-9876543.pages.dev/qbo/launch.html` |
| Disconnect Landing Page URL | `https://qbo-legal-9876543.pages.dev/qbo/disconnect.html` |
| EULA URL | `https://qbo-legal-9876543.pages.dev/legal/eula.html` |
| Privacy Policy URL | `https://qbo-legal-9876543.pages.dev/legal/privacy.html` |

Industry questions: all defaults to **No** via the no-radio script.

Save button: clicked via `scrollIntoView + click` (button is below the fold).

Wait:

```
mcp__playwright__browser_wait_for({ text: "Production credentials" })
```

After ~6 seconds, Intuit's confirmation banner appears: "Your production credentials are ready." The Production tab now shows Client ID + Client Secret keys.

Optional App Store prompt:

```
Claude: You're now able to connect QuickBooks. Optional: you can also
        list this app on the QuickBooks App Store so other QuickBooks
        users can install it — that's a 4-6 week review by Intuit.
        Most people skip it. Should I submit it for you, or skip and
        proceed to connecting your QuickBooks?
User: Skip, just connect mine.
```

---

## Step 1L-D.1 — Cloudflared install + tunnel start

Reference run: `cloudflared` was not installed.

```bash
$ command -v cloudflared || brew install cloudflared
==> Downloading https://homebrew-bottles.s3.amazonaws.com/cloudflared-2026.05.0...
🍺 /opt/homebrew/Cellar/cloudflared/2026.05.0: 8 files, 15.2MB
$ cloudflared --version
cloudflared version 2026.5.0 (built 2026-05-12T19:43:12Z)
```

(~25 seconds for the brew install.)

Tunnel start:

```bash
$ cloudflared tunnel --url http://localhost:8000 > /tmp/qbo-tunnel.log 2>&1 &
$ sleep 4
$ grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/qbo-tunnel.log | head -1
https://example-tunnel-name-here.trycloudflare.com
```

Tunnel URL: `https://example-tunnel-name-here.trycloudflare.com` (the literal value here is anonymized; in a real run it's a 4-5 word slug from Cloudflare's word list).

---

## Step 1L-D.2 — Add tunnel URL to Production redirect URIs

Navigate to the redirect URI settings page, click the **Production** sub-tab, then add `${TUNNEL_URL}/callback`. Reference run had no prior trycloudflare URLs, so the prune step was a no-op.

Save. Reload. Verify the new URI is in the list.

---

## Step 1L-D.3 — DOM-extract Production credentials

Navigate to `/appdetail/keys?...&tab=production`, click **Show credentials** toggle, run the clipboard-transit extract:

```js
// (same script as Phase 1S Step 7 — returns lengths only, never values)
=> { ok: true, client_id_len: 50, client_secret_len: 40 }
```

Click toggle again to hide. Production credentials are typically the same shape as sandbox (50/40 chars).

---

## Step 1L-D.4 — Write .env

```bash
$ awk -F= '{print $1, "(len:", length($2), ")"}' "$HOME/.local/share/qbo-mcp/.env"
QUICKBOOKS_CLIENT_ID (len: 50)
QUICKBOOKS_CLIENT_SECRET (len: 40)
QUICKBOOKS_REDIRECT_URI (len: 67)         # https://example-tunnel-name-here.trycloudflare.com/callback
QUICKBOOKS_ENVIRONMENT (len: 10)          # production
$ stat -c %a "$HOME/.local/share/qbo-mcp/.env"
600
```

---

## Step 1L-D.5 — npm run auth + Production consent

```bash
$ cd "$HOME/.local/share/qbo-mcp"
$ npm run auth > /tmp/qbo-auth.log 2>&1 &

$ sleep 3
$ grep -oE 'https://appcenter\.intuit\.com/connect/oauth2[^[:space:]]+' /tmp/qbo-auth.log | head -1
https://appcenter.intuit.com/connect/oauth2?client_id=<REDACTED>&redirect_uri=https%3A%2F%2Fexample-tunnel-name-here.trycloudflare.com%2Fcallback&response_type=code&scope=com.intuit.quickbooks.accounting&state=testState
```

Playwright navigates to the auth URL. Intuit's **production** consent screen appears:

```
[Reference Run Pty Ltd] will allow Claude Assistant to:
  View and edit your QuickBooks data.

[Cancel]  [Connect]
```

Playwright clicks **Connect**. The browser redirects to `https://example-tunnel-name-here.trycloudflare.com/callback?code=...&realmId=...`. The tunnel forwards to `localhost:8000`. The auth-server captures the code, exchanges it for tokens, and writes them to `.env`:

```bash
$ grep -E '✓|saved' /tmp/qbo-auth.log
✓ Successfully authenticated with QuickBooks!
Tokens have been saved to your .env file.

$ awk -F= '/^QUICKBOOKS_/ {print $1, "(len:", length($2), ")"}' "$HOME/.local/share/qbo-mcp/.env"
QUICKBOOKS_CLIENT_ID (len: 50)
QUICKBOOKS_CLIENT_SECRET (len: 40)
QUICKBOOKS_REDIRECT_URI (len: 67)
QUICKBOOKS_ENVIRONMENT (len: 10)
QUICKBOOKS_REFRESH_TOKEN (len: 41)
QUICKBOOKS_REALM_ID (len: 16)         # ← the participant's REAL company ID
```

All 6 keys present.

---

## Step 1L-D.6 — Teardown tunnel + restore .env REDIRECT_URI

```bash
$ pgrep -f 'cloudflared tunnel --url http://localhost:8000' | xargs kill
$ sed -i.bak 's|^QUICKBOOKS_REDIRECT_URI=.*|QUICKBOOKS_REDIRECT_URI=http://localhost:8000/callback|' "$HOME/.local/share/qbo-mcp/.env"
$ rm -f "$HOME/.local/share/qbo-mcp/.env.bak"
$ awk -F= '/REDIRECT_URI/' "$HOME/.local/share/qbo-mcp/.env"
QUICKBOOKS_REDIRECT_URI=http://localhost:8000/callback
```

---

## Step 1L-E — MCP register

```bash
$ set -a; . "$HOME/.local/share/qbo-mcp/.env"; set +a
$ claude mcp add quickbooks --scope user \
    --env "QUICKBOOKS_CLIENT_ID=$QUICKBOOKS_CLIENT_ID" \
    --env "QUICKBOOKS_CLIENT_SECRET=$QUICKBOOKS_CLIENT_SECRET" \
    --env "QUICKBOOKS_REFRESH_TOKEN=$QUICKBOOKS_REFRESH_TOKEN" \
    --env "QUICKBOOKS_REALM_ID=$QUICKBOOKS_REALM_ID" \
    --env "QUICKBOOKS_REDIRECT_URI=$QUICKBOOKS_REDIRECT_URI" \
    --env "QUICKBOOKS_ENVIRONMENT=production" \
    -- node "$HOME/.local/share/qbo-mcp/dist/index.js" >/dev/null 2>&1
$ echo $?
0

$ claude mcp list 2>&1 | grep quickbooks
quickbooks: node /home/user/.local/share/qbo-mcp/dist/index.js - ✓ Connected
```

Tell the participant:

```
Claude: All set — your QuickBooks is now connected to your real company
        data. One last step: please close this window and reopen Claude
        Code, then say hi. I'll show you your live QuickBooks once
        you're back.
```

Save a memory marker that QuickBooks is installed in **live mode**.

---

## After restart — Phase 0 + Phase 2 smoke

Next session:

```
User: hi
Claude: # Phase 0 — detects MODE=production from claude mcp get
        # Phase 2 — first invocation triggers Gate 1 (real-data confirm)
        mcp__quickbooks__get_company_info({})
        # → { CompanyInfo: { CompanyName: "Reference Run Pty Ltd", ... } }
Claude: Just confirming — you're connected to your real QuickBooks
        company **Reference Run Pty Ltd**. Anything I do here will
        hit your live data. Want me to show you something specific,
        or just show your recent invoices to confirm it's working?
User: Show recent invoices.
Claude: # Reads — no further gate
        mcp__quickbooks__search_invoices({ limit: 20 })
        # → presents 20 actual invoices from the real company
```

A write would trigger Gate 2:

```
User: Create an invoice for ABC Pty Ltd, $1,250, due July 15.
Claude: I'm about to create a real invoice for **ABC Pty Ltd** for
        **$1,250.00**, due **2026-07-15**. This will appear in your
        QuickBooks immediately. OK?
User: Yes.
Claude: # Creates the real invoice; reports back the DocNumber
```

---

## Total reference timing

| Stage | Wall-clock |
|---|---|
| Phase 0 (mode prompt + reply) | 10 s |
| 1L-A.1 (wrangler install) | 8 s (fresh; 0 s if cached) |
| 1L-A.2 (Cloudflare login, including human sign-in) | 50 s |
| 1L-A.3 (build legal-pages dir) | 1 s |
| 1L-A.4 (Pages deploy) | 15 s |
| 1L-A.5 (URL smoke) | 2 s |
| 1L-B (Intuit sign-in + app reuse) | 30 s |
| 1L-C (Production Settings form fill + save) | 25 s |
| 1L-D.1 (cloudflared install) | 25 s (fresh; 0 s if cached) |
| 1L-D.1 (tunnel start) | 5 s |
| 1L-D.2 (add redirect URI) | 12 s |
| 1L-D.3 (DOM-extract creds) | 8 s |
| 1L-D.4 (.env write) | 1 s |
| 1L-D.5 (npm run auth + consent) | 20 s |
| 1L-D.6 (teardown) | 2 s |
| 1L-E (claude mcp add + list) | 4 s |
| **Total** | **~3.5 min** with binaries cached; **~6 min** for a cold install with sign-up moments |

---

## Failure modes seen during reference development

| Failure | Cause | Fix |
|---|---|---|
| `wrangler pages deploy` errors with `Project not found` and `--project-name` rejected | Account doesn't have Pages enabled (extremely rare on Free tier) | Prompt participant to visit `dash.cloudflare.com/<account>/pages` once to enable, then retry |
| Intuit Production Settings form save returns "URL not reachable" | Pages deploy hadn't propagated yet | Sleep 15 seconds after deploy before form fill |
| `Production credentials` text never appears after save | Intuit's UI variant — the success state shows "Keys generated" instead | Use a broader `browser_wait_for` regex: `/credentials|keys generated|tab is now/i` |
| Consent flow shows "Choose a company" with no real companies listed | Participant signed into developer.intuit.com with an account that has no QBO subscription | Prompt: "Please make sure you're signed in to QuickBooks with a real account in another tab, then we'll continue." |
| `claude mcp list` shows `✗ Failed to connect` after register | The MCP server itself runs but fails first call — env vars wrong or stale | Re-read `.env`, re-run `claude mcp remove quickbooks -s user` then re-run Phase 1L-E |
| trycloudflare URL is `522 Bad Gateway` | Tunnel was killed between Step D.1 and D.5 | Restart tunnel from D.1 |

For anything not covered here, capture the full log and ask in the workshop kit's issue tracker.
