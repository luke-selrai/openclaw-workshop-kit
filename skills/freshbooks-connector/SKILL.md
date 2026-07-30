---
name: freshbooks-connector
description: "Connect FreshBooks to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect FreshBooks, or wants accounting work (invoices, clients, expenses, payments, profit and loss) and the credentials aren't in place yet. Once connected, FreshBooks runs directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Finance & Accounting
  tags:
    - freshbooks
    - accounting
    - invoicing
    - expenses
    - oauth2
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting FreshBooks OAuth (401 / token refresh) or app-registration errors
    - skill: qbo
      reason: Sibling accounting connector - FreshBooks is the solo-tier counterpart to QuickBooks
    - skill: xero-connector
      reason: Sibling accounting connector; useful for migrations/comparisons
---

# FreshBooks Connector

## Overview

This skill lets Claude read and update a user's FreshBooks data on their behalf. FreshBooks is the solo/small-business cloud-accounting and invoicing app - the sub-QuickBooks/Xero tier. It publishes **no MCP server and no personal API token**: the API is **OAuth2-only**. So this is a **direct-REST connector with an OAuth2 front-end** - a heavier shape than the static-token connectors (`pipedrive`, `asana`, `servicem8`), closest in spirit to `qbo`'s app-registration flow but without a vendor CLI to lean on.

**Already-a-customer connector.** This skill is for users who **already have a FreshBooks account or trial**. Do NOT use it to recommend or pitch FreshBooks to users who do not already use it, and do not create a FreshBooks account for them.

Three FreshBooks facts drive the whole design:

- **OAuth2 authorization-code grant.** There is no API key to copy. You register a developer app (Client ID + Secret), send the user through a consent screen, capture an authorization `code`, and exchange it for an **access token (~12 h)** + a **refresh token**.
- **The redirect URI must be public HTTPS - `localhost` is rejected (HTTP 422).** Since attendees don't run a public HTTPS server, this connector registers a *neutral* public HTTPS redirect (`https://example.com/callback`) and **captures the `code` straight from the browser's address bar** after consent (example.com just loads a static page and ignores the query). The single-use code is exchanged within seconds.
- **Refresh tokens are ONE-TIME-USE.** Every refresh returns a *new* refresh token; the old one dies immediately. The runtime MUST persist the rotated refresh token atomically on every refresh, or the connector breaks permanently and the user must re-auth.

The skill has two phases:

- **Phase 1 - Install & Connect (Playwright-driven app registration + OAuth).** Claude drives the dev console to create the app, capture credentials, run consent, capture the code, exchange for tokens, discover the `account_id`, and persist. The user's manual moments are signing in to FreshBooks once and clicking **Allow** on the consent screen.
- **Phase 2 - Use the connector.** curl against the accounting API with Bearer auth, with transparent access-token refresh + refresh-token rotation.

**Which phase to run** - Before any FreshBooks action, check for `~/.config/freshbooks/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\freshbooks\credentials.env` (native Windows). If it exists with a non-empty `FRESHBOOKS_ACCESS_TOKEN` **and** `FRESHBOOKS_REFRESH_TOKEN` **and** `FRESHBOOKS_ACCOUNT_ID`, run the Phase 0 smoke ping; on success go to Phase 2; on 401 run the refresh recipe; if refresh fails, re-run Phase 1. Otherwise run Phase 1.

**Full account access.** The granted scopes (below) let the token read and write invoices, clients, expenses, payments, and reports for the authorizing user's business. Treat the tokens AND the Client Secret like passwords.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous - Claude does the work; the user signs in once and clicks Allow once. Every message during Phase 1 follows these rules:

- **You drive, not them.** The only actions you request are "please sign in to FreshBooks in the browser window I just opened" and "please click Allow on the permission screen."
- **Plain English only.** No jargon. Never say API, token, OAuth, client id/secret, redirect, scope, curl, header, DOM, Playwright, env, JSON, endpoint. Call it "the connection" / "your FreshBooks account" / "your browser."
- **Tell them what's about to happen.** "I'm going to connect FreshBooks for you - it takes a minute or two."
- **React warmly; never show raw errors.** Translate failures into plain English and try the documented recovery.
- **Short responses.** Max 8 lines per message during Phase 1.
- **Never echo any credential** - Client Secret, access token, refresh token, or authorization code - in narration, a tool return, or a log.
- **No restart needed.** No MCP server to reconcile.

---

## Cross-cutting: Playwright MCP install contingency

Phase 1 drives a browser via the Playwright MCP server. If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code once, and retry. The `--user-data-dir` flag keeps the FreshBooks login alive across sessions.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/freshbooks/credentials.env"
if [ -f "$CRED" ] && grep -q '^FRESHBOOKS_ACCESS_TOKEN=.\+' "$CRED" && grep -q '^FRESHBOOKS_REFRESH_TOKEN=.\+' "$CRED" && grep -q '^FRESHBOOKS_ACCOUNT_ID=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → run the smoke ping. On HTTP 200 → **Phase 2**. On HTTP 401 → run the **refresh recipe** (Phase 2 §Refresh); if that fails → **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (token read from file, never printed):

```bash
set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $FRESHBOOKS_ACCESS_TOKEN" -H "Content-Type: application/json" \
  "https://api.freshbooks.com/accounting/account/$FRESHBOOKS_ACCOUNT_ID/invoices/invoices?per_page=1"
```

---

## PHASE 1 - Install & Connect (Playwright-driven OAuth2)

> **Reasoning model.** Each step is a *goal*; achieve it via `browser_snapshot` → reason → click/type. Match elements by visible labels. FreshBooks' dev console is an Ember app - see the Ember gotchas inline.

> **Never snapshot the sign-in page** (auto-filled-password leak; memory `reference_playwright_snapshot_password_leak`). Detect login by polling `location.href`.

### Step 1 - Open the developer console; ensure signed in

Tell the user: *"Opening a browser window - please sign in to FreshBooks when it appears."*

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://my.freshbooks.com/#/developer" })
```

Poll `location.href` until the page is the developer "Apps" list (title contains "Apps"). SSO bounces are normal.

### Step 2 - Create the app

Click **Create New App**. In the dialog:

1. **Application Name** - must be **globally unique across all of FreshBooks** (not just this account). A plain `Claude Code` returns **HTTP 422 "Name has already been taken."** Use a unique name like `Claude Code - <Business or initials>` (e.g. `Claude Code - SelrAI`). If 422 on save, append more uniqueness and retry.
2. **Application Type** - choose **Private App** (not listed in the store).
3. **Scopes** - the default is only `user:profile:read`. Add the accounting set via **Add Scope** (one at a time): `user:invoices:read`, `user:invoices:write`, `user:clients:read`, `user:clients:write`, `user:expenses:read`, `user:payments:read`, `user:reports:read`. (Add more later by editing the app if the user needs estimates, taxes, projects, etc.)
4. **Redirect URIs** - type `https://example.com/callback`, then **click the "+" / add button to COMMIT it to the list**. If you skip the "+", the field shows "This cannot be blank" on save even though text is present. **Do NOT use `localhost`** - FreshBooks rejects it (422); HTTPS public host is required.
5. Click **Save**.

> **Ember form gotchas (verified 2026-06-22):** (a) `fill()`/synthetic clicks may not trigger Ember bindings - prefer the real click tool; for inputs, set value + dispatch `input`/`change`. (b) Adding scopes re-renders the form and can **blank the redirect field** - re-enter + re-commit the redirect right before Save. (c) The redirect "+" button is mandatory. (d) On a 422, read the response body (`browser_network_request` → response-body of the POST to `…/partners/applications`) to see the real reason - the inline error can be misleading (the redirect "blank" error masked the real "name taken" cause during the build).

### Step 3 - Capture Client ID + Secret

Open the app from the list (→ Edit Application). The page shows **Client ID** (64-hex, also in the URL) as plain text and **Client Secret** masked. Click the secret's reveal (eye) toggle, then DOM-read both. Persist them now (the secret is the long-lived app credential):

```bash
install -d -m 700 "$HOME/.config/freshbooks"; umask 177
cat > "$HOME/.config/freshbooks/credentials.env" <<EOF
# FreshBooks OAuth2 credentials - DO NOT COMMIT, DO NOT SHARE
FRESHBOOKS_CLIENT_ID=<client_id>
FRESHBOOKS_CLIENT_SECRET=<client_secret>
FRESHBOOKS_REDIRECT_URI=https://example.com/callback
FRESHBOOKS_ACCESS_TOKEN=
FRESHBOOKS_REFRESH_TOKEN=
FRESHBOOKS_ACCOUNT_ID=
EOF
chmod 600 "$HOME/.config/freshbooks/credentials.env"
```

> Prefer clipboard-transit for the secret (read via the reveal then `navigator.clipboard.writeText`, paste into the file in bash) so the value never lands in a tool-return. Never screenshot the reveal.

### Step 4 - Run consent; capture the authorization code

Build and open the authorize URL (the registered redirect must match exactly):

```
https://auth.freshbooks.com/oauth/authorize/?response_type=code&redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&client_id=<CLIENT_ID>
```

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "<authorize URL>" })
```

The user is already signed in → FreshBooks shows "Connect <app> … wants to: …". Ask the user to click **Allow** (or click it for them). The browser then lands on `https://example.com/callback?code=<CODE>` (example.com loads a static page; the `code` is in the URL). Read it from `location.href`:

```
mcp__plugin_playwright_playwright__browser_evaluate({ function: "() => { const u=new URL(location.href); return { code: u.searchParams.get('code') }; }" })
```

### Step 5 - Exchange the code for tokens (do immediately - codes are short-lived & single-use)

```bash
set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
CODE="<code from step 4>"
RESP=$(curl -s -X POST "https://api.freshbooks.com/auth/oauth/token" -H "Content-Type: application/json" \
  -d "{\"grant_type\":\"authorization_code\",\"client_id\":\"$FRESHBOOKS_CLIENT_ID\",\"client_secret\":\"$FRESHBOOKS_CLIENT_SECRET\",\"code\":\"$CODE\",\"redirect_uri\":\"$FRESHBOOKS_REDIRECT_URI\"}")
ACCESS=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
REFRESH=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("refresh_token",""))')
[ -n "$ACCESS" ] && [ -n "$REFRESH" ] || { echo "exchange failed"; echo "$RESP" | head -c 300; exit 1; }
```

### Step 6 - Discover account_id, persist, verify

```bash
ME=$(curl -s -H "Authorization: Bearer $ACCESS" -H "Content-Type: application/json" "https://api.freshbooks.com/auth/api/v1/users/me")
ACCOUNT_ID=$(echo "$ME" | python3 -c 'import sys,json;d=json.load(sys.stdin);r=d.get("response",d);bm=r.get("business_memberships") or [];print(next((b["business"]["account_id"] for b in bm if b.get("business",{}).get("account_id")),""))')
[ -n "$ACCOUNT_ID" ] || { echo "no account_id"; exit 1; }
# persist atomically
python3 - "$ACCESS" "$REFRESH" "$ACCOUNT_ID" <<'PY'
import sys,re,os
a,r,acct=sys.argv[1:4]; p=os.path.expanduser("~/.config/freshbooks/credentials.env"); s=open(p).read()
s=re.sub(r'^FRESHBOOKS_ACCESS_TOKEN=.*$','FRESHBOOKS_ACCESS_TOKEN='+a,s,flags=re.M)
s=re.sub(r'^FRESHBOOKS_REFRESH_TOKEN=.*$','FRESHBOOKS_REFRESH_TOKEN='+r,s,flags=re.M)
s=re.sub(r'^FRESHBOOKS_ACCOUNT_ID=.*$','FRESHBOOKS_ACCOUNT_ID='+acct,s,flags=re.M)
tmp=p+'.tmp'; open(tmp,'w').write(s); os.chmod(tmp,0o600); os.replace(tmp,p)
PY
# scrub Playwright snapshots (auth code / secret may appear in auto-snapshots)
rm -rf .playwright-mcp 2>/dev/null
# verify
set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
curl -s -o /dev/null -w 'verify http=%{http_code}\n' -H "Authorization: Bearer $FRESHBOOKS_ACCESS_TOKEN" -H "Content-Type: application/json" \
  "https://api.freshbooks.com/accounting/account/$FRESHBOOKS_ACCOUNT_ID/invoices/invoices?per_page=1"
```

Expect `200`. Tell the user: *"All connected - your FreshBooks is ready. Try 'show my unpaid invoices' or 'add a client'."* **No restart needed.**

> **Cross-platform note.** Native Windows stores at `%APPDATA%\freshbooks\credentials.env`; everywhere else `~/.config/freshbooks/credentials.env`.

---

## PHASE 2 - Use the connector (REST runtime loop, with refresh rotation)

```bash
set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
B="https://api.freshbooks.com/accounting/account/$FRESHBOOKS_ACCOUNT_ID"
FB() { curl -s -H "Authorization: Bearer $FRESHBOOKS_ACCESS_TOKEN" -H "Content-Type: application/json" "$@"; }
```

### Refresh (run on ANY 401 - refresh token is ONE-TIME-USE, rotate + re-persist)

```bash
fb_refresh() {
  set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
  local R; R=$(curl -s -X POST "https://api.freshbooks.com/auth/oauth/token" -H "Content-Type: application/json" \
    -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"$FRESHBOOKS_CLIENT_ID\",\"client_secret\":\"$FRESHBOOKS_CLIENT_SECRET\",\"refresh_token\":\"$FRESHBOOKS_REFRESH_TOKEN\",\"redirect_uri\":\"$FRESHBOOKS_REDIRECT_URI\"}")
  local A RF; A=$(echo "$R"|python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
  RF=$(echo "$R"|python3 -c 'import sys,json;print(json.load(sys.stdin).get("refresh_token",""))')
  [ -n "$A" ] && [ -n "$RF" ] || { echo "refresh failed - re-run Phase 1"; return 1; }
  python3 - "$A" "$RF" <<'PY'
import sys,re,os
a,r=sys.argv[1:3]; p=os.path.expanduser("~/.config/freshbooks/credentials.env"); s=open(p).read()
s=re.sub(r'^FRESHBOOKS_ACCESS_TOKEN=.*$','FRESHBOOKS_ACCESS_TOKEN='+a,s,flags=re.M)
s=re.sub(r'^FRESHBOOKS_REFRESH_TOKEN=.*$','FRESHBOOKS_REFRESH_TOKEN='+r,s,flags=re.M)
tmp=p+'.tmp'; open(tmp,'w').write(s); os.chmod(tmp,0o600); os.replace(tmp,p)
PY
  set -a; . "$HOME/.config/freshbooks/credentials.env"; set +a
}
```

**Pattern:** make the call; if HTTP 401, run `fb_refresh` once, reload creds, retry. Never refresh speculatively (each refresh burns the current refresh token - only refresh on a real 401).

### Reads (response under `response.result`; paginate with `page`/`per_page`)

```bash
# unpaid invoices
FB "$B/invoices/invoices?search[v3_status]=overdue&per_page=50" \
  | python3 -c 'import sys,json;r=json.load(sys.stdin)["response"]["result"];print("total",r["total"]);[print(i["invoice_number"],i["amount"]["amount"],i["organization"]) for i in r["invoices"]]'
# clients / expenses
FB "$B/users/clients?per_page=50" | jq '.response.result.clients[] | {id,organization,email:.email}'
FB "$B/expenses/expenses?per_page=50" | jq '.response.result.expenses[] | {id, amount:.amount.amount, vendor:.vendor}'
```

### Writes (wrap the body in the entity key)

```bash
# create a client
FB -X POST "$B/users/clients" -d '{"client":{"organization":"Acme Pty Ltd","email":"ap@acme.example"}}' | jq '.response.result.client.id'
# create an invoice (needs a client id)
FB -X POST "$B/invoices/invoices" -d '{"invoice":{"customerid":<CLIENT_ID>,"create_date":"2026-06-30","lines":[{"name":"Consulting","unit_cost":{"amount":"150.00"},"qty":"4"}]}}' | jq '.response.result.invoice.id'
```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint (under `/accounting/account/<id>`) | Notes |
|---|---|---|
| Invoices | `/invoices/invoices` | list/create/`PUT` update; body key `invoice` |
| Clients | `/users/clients` | body key `client` |
| Expenses | `/expenses/expenses` | body key `expense` |
| Payments | `/payments/payments` | body key `payment` |
| Reports | `/reports/accounting/profitloss_entity`, `…/accounting/balance_sheet` | P&L, balance sheet, etc. |

---

## Gotchas

- **One-time-use refresh tokens.** The single biggest footgun. Refresh ONLY on a 401, and ALWAYS persist the new refresh token atomically (temp-file + rename). A torn or skipped persist bricks the connector → Phase 1 re-auth. (Verified live 2026-06-22: refresh rotates the token every time.)
- **App name is globally unique** → `Claude Code` alone yields 422 "Name has already been taken." Suffix it.
- **`localhost` redirect is rejected (422).** Use a public HTTPS redirect and capture the code from the browser. The single-use code briefly transits the neutral host on the redirect GET - accepted trade-off.
- **Redirect "+" commit + scope re-render blanks** - see Step 2 Ember gotchas. Read the 422 response body to see the real cause.
- **`Authorization: Bearer` only** (the access token). Not the Client Secret, not a query param.
- **account_id ≠ business_id.** Accounting endpoints use the alphanumeric `account_id` (e.g. `qKQxnJ`); the Projects API uses the numeric `business_id`. This connector is accounting-scoped → use `account_id`.
- **Response shape:** reads return `{"response":{"result":{...}}}`; writes return the created object under `response.result.<entity>`. Errors return `{"response":{"errors":[...]}}` or top-level `{"error":...}` on the auth endpoint.
- **No substring-negation in self-checks.** Match `http_code==200` / presence of `response.result`, never "output lacks an error word."
- **Access token ~12 h.** Long sessions will hit 401 → refresh handles it.

## Token handling

Client Secret, access token, and refresh token are bearer-equivalent secrets. They live only in `~/.config/freshbooks/credentials.env` (mode 600), are read into shell vars at call time, and are **never** echoed to narration, a tool return, or a log. Add `**/credentials.env` to any nearby repo `.gitignore`.

## See also

- `examples/install-walkthrough-live.md` - the real, verified Phase 1 run (secrets redacted), incl. the name-taken / no-localhost / refresh-rotation findings.
- `references/rest-api.md` - endpoints, response envelope, pagination, write bodies, reports.
- `skills/CLAUDE.md` - connector patterns; FreshBooks is the OAuth2 direct-REST variant.
