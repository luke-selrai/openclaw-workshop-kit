---
name: starshipit-connector
description: "Connect Starshipit to Claude by installing and authenticating its API credentials. Use when the user asks to set up or connect Starshipit, or wants Starshipit work (orders, shipments, labels, tracking, manifests, the address book) and the credentials aren't in place yet. Once connected, Starshipit runs directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - starshipit
    - shipping
    - fulfilment
    - logistics
    - ecommerce
    - tracking
    - rest
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting Starshipit auth (401/403) or wrong-path (404) errors
    - skill: servicem8-connector
      reason: Sibling direct-REST connector - same Playwright key-capture + curl-runtime shape
---

# Starshipit Connector

## Overview

This skill lets Claude read and update a user's Starshipit data on their behalf. Starshipit is the shipping / fulfilment / label-printing / tracking platform used by ecommerce and retail businesses (popular in AU/NZ). It publishes **no MCP server**, so this is a **standalone direct-REST connector** - the same shape as the `servicem8`, `cliniko`, `deputy`, `myob`, and `ghl` direct-REST family in `skills/CLAUDE.md`.

> **Scope note (partial gap).** Generic multi-carrier shipping is already reachable through the kit's Tier-2 broker (ShipEngine / Shipday). Starshipit's distinct value is its **AU/NZ carrier coverage and label/manifest workflow** for businesses that already run on it - that's who this connector is for. Don't pitch Starshipit to someone who doesn't use it.

The architecture is dead simple, with one Starshipit quirk: **two keys**. Every call sends **both**:

- `StarShipIT-Api-Key: <api key>` - the account API key (Settings → API; pre-exists per account).
- `Ocp-Apim-Subscription-Key: <subscription key>` - the Azure-APIM subscription key (Settings → API; may need generating once).

Both live in `~/.config/starshipit/credentials.env`; Claude reads them and `curl`s `https://api.starshipit.com/api`. **Forgetting the subscription key is the #1 mistake** - calls fail without it.

The skill has two phases:

- **Phase 1 - Install & Connect (autonomous via Playwright).** The user signs in; Claude opens Settings → API, reads the existing API key, generates + saves the subscription key if it's empty, captures both, writes `~/.config/starshipit/credentials.env` (mode 600), and verifies with a live ping. The user's only manual moment is signing in.
- **Phase 2 - Use the connector.** Once both keys are saved, Claude calls the Starshipit REST API via `curl`: orders, address book, shipments/labels, tracking.

**Which phase to run** - Before any Starshipit action, check for `~/.config/starshipit/credentials.env` (Mac/Linux/WSL) or `%APPDATA%\starshipit\credentials.env` (native Windows). If it exists with a non-empty `STARSHIPIT_API_KEY` **and** `STARSHIPIT_SUBSCRIPTION_KEY`, run the Phase 0 smoke ping; on success, skip to Phase 2. Otherwise run Phase 1.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous. Every message follows these rules:

- **You drive, not them.** The only action you request is "please sign in to Starshipit in the browser window I just opened."
- **Their own browser is never opened.** Everything happens inside the separate Playwright-controlled browser window with its own profile - the user's day-to-day browser and its logged-in sessions are never touched.
- **Plain language only.** No jargon - no API, key, subscription, REST, curl, header, DOM, Playwright, env, JSON, endpoint. Name things plainly: "the connection", "your Starshipit account", "your browser".
- **Tell them what's about to happen** before each action; **react warmly**; **never show raw errors**.
- **Short responses** - max 8 lines per message.
- **Never echo either key** in a narration line, a tool return, or a log.
- **No restart needed** - works the instant the keys are saved; do NOT ask the user to restart Claude Code.

---

## Cross-cutting: Playwright MCP install contingency

If `mcp__plugin_playwright_playwright__*` (or `mcp__playwright__*`) tools are not available, install Playwright first, per `skills/CLAUDE.md`:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

Then ask the user to close and reopen Claude Code, and retry.

---

## PHASE 0 - Resume check

```bash
CRED="$HOME/.config/starshipit/credentials.env"
if [ -f "$CRED" ] && grep -q '^STARSHIPIT_API_KEY=.\+' "$CRED" && grep -q '^STARSHIPIT_SUBSCRIPTION_KEY=.\+' "$CRED"; then echo configured; else echo not-configured; fi
```

- `configured` → run the smoke ping. On HTTP 200, tell the user "You're already connected - let me check it still works," then go to **Phase 2**. On 401/403, a key was revoked/regenerated - re-run **Phase 1**.
- `not-configured` → **Phase 1**.

Smoke ping (keys read from file, never printed):

```bash
set -a; . "$HOME/.config/starshipit/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "StarShipIT-Api-Key: $STARSHIPIT_API_KEY" \
  -H "Ocp-Apim-Subscription-Key: $STARSHIPIT_SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  "$STARSHIPIT_API_BASE/orders/unshipped"
```

---

## PHASE 1 - Install & Connect (autonomous via Playwright)

> **Reasoning model.** Each step is a *goal*; achieve it via `browser_snapshot`/`browser_evaluate` → reason → click. The API page is a legacy ASP.NET form - match fields by their visible "API Key" / "Subscription"/"Azure" labels; the `ctl00_ContentPlaceHolder1_*` ids below are observed-live but may drift.

> **Never snapshot the sign-in page** - the accessibility tree can include an auto-filled password. Detect post-login with `browser_wait_for`.

### Step 1 - Sign in

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.starshipit.com/" })
```

This redirects to the login page. Tell the user: *"Please sign in to Starshipit in the browser window (complete any code it emails)."* Then poll:

```
mcp__plugin_playwright_playwright__browser_wait_for({ text: "Orders", time: 30 })
```

### Step 2 - Open Settings → API

```
mcp__plugin_playwright_playwright__browser_navigate({ url: "https://app.starshipit.com/Members/Settings/API2.aspx" })
```

Inspect the two key fields and whether the subscription key needs generating (returns lengths only, never values):

```js
() => {
  const api = document.getElementById('ctl00_ContentPlaceHolder1_tbApiKey');
  const sub = document.getElementById('ctl00_ContentPlaceHolder1_tbAzurePrimaryKey');
  return { apiKeyLen: api?(api.value||'').length:null, subKeyLen: sub?(sub.value||'').length:null };
}
```

- `apiKeyLen` is normally ~32 (pre-exists). If 0, click the API-key **Generate**/**Regenerate** control first.
- `subKeyLen` 0 → generate it in Step 3. `subKeyLen` ~32 → skip to Step 4.

### Step 3 - Generate + save the subscription key (if missing)

```
mcp__plugin_playwright_playwright__browser_click({ element: "Generate subscription key", target: "#ctl00_ContentPlaceHolder1_RadButton_GenerateAzurePrimaryKey_input" })
mcp__plugin_playwright_playwright__browser_click({ element: "Save", target: "#ctl00_ContentPlaceHolder1_bSave_input" })
```

Re-check that `tbAzurePrimaryKey` is now ~32 chars before continuing.

### Step 4 - Capture both keys (DOM-extract, never screenshot)

Read both field values into the clipboard as JSON, returning only lengths:

```js
async () => {
  const api = (document.getElementById('ctl00_ContentPlaceHolder1_tbApiKey')||{}).value || '';
  const sub = (document.getElementById('ctl00_ContentPlaceHolder1_tbAzurePrimaryKey')||{}).value || '';
  if (api.length < 8 || sub.length < 8) return { ok:false, apiLen:api.length, subLen:sub.length };
  try { await navigator.clipboard.writeText(JSON.stringify({api_key:api, sub_key:sub})); return { ok:true, apiLen:api.length, subLen:sub.length }; }
  catch(e){ return { ok:false, reason:'clipboard', apiLen:api.length, subLen:sub.length }; }
}
```

If `ok:false`, re-check the page and retry once. Conversational fallback: ask the user to paste both keys (accepted transcript-leak trade-off).

### Step 5 - Store both keys (silent), scrub artifacts

```bash
install -d -m 700 "$HOME/.config/starshipit"
CB="$( wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || pbpaste 2>/dev/null )"
AK="$(printf '%s' "$CB" | jq -r '.api_key')"; SK="$(printf '%s' "$CB" | jq -r '.sub_key')"
umask 077
cat > "$HOME/.config/starshipit/credentials.env" <<EOF
# Starshipit REST API credentials - DO NOT COMMIT, DO NOT SHARE
# Auth: BOTH headers on every call - StarShipIT-Api-Key + Ocp-Apim-Subscription-Key
STARSHIPIT_API_KEY=${AK}
STARSHIPIT_SUBSCRIPTION_KEY=${SK}
STARSHIPIT_API_BASE=https://api.starshipit.com/api
EOF
chmod 600 "$HOME/.config/starshipit/credentials.env"
( printf '' | wl-copy 2>/dev/null ) || ( printf '' | xclip -selection clipboard -i 2>/dev/null ) || true
rm -rf .playwright-mcp 2>/dev/null   # snapshots of the API page can contain the keys; never grep+rm on a key substring
unset CB AK SK
```

### Step 6 - Smoke test and report

```bash
set -a; . "$HOME/.config/starshipit/credentials.env"; set +a
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "StarShipIT-Api-Key: $STARSHIPIT_API_KEY" \
  -H "Ocp-Apim-Subscription-Key: $STARSHIPIT_SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  "$STARSHIPIT_API_BASE/orders/unshipped"
```

Expect `200`. Tell the user: *"All connected - your Starshipit is ready. Ask me things like 'how many orders are waiting to ship?' or 'what's in my address book?'."* **No restart needed.**

---

## PHASE 2 - Use the connector (REST runtime loop)

Once `~/.config/starshipit/credentials.env` exists, follow this loop on every Starshipit request.

1. Load both keys (never printed):

   ```bash
   set -a; . "$HOME/.config/starshipit/credentials.env"; set +a
   SS() { curl -s -H "StarShipIT-Api-Key: $STARSHIPIT_API_KEY" -H "Ocp-Apim-Subscription-Key: $STARSHIPIT_SUBSCRIPTION_KEY" -H "Content-Type: application/json" "$@"; }
   ```

2. Read:

   ```bash
   SS "$STARSHIPIT_API_BASE/orders/unshipped" | jq '.orders | length'
   SS "$STARSHIPIT_API_BASE/addressbook" | jq '.addresses | length'
   ```

3. Write - `POST` with a JSON body. Always **confirm order/shipment writes with the user first** (these can create real labels / charges):

   ```bash
   SS -X POST -d '{"order":{"order_number":"TEST-001","destination":{ ... }}}' \
     "$STARSHIPIT_API_BASE/orders"
   ```

**Core resources** (full catalogue in `references/rest-api.md`):

| Resource | Endpoint | Notes |
|---|---|---|
| Unshipped orders | `orders/unshipped` | the print/dispatch queue (live-verified) |
| Shipped orders | `orders/shipped` | already-dispatched |
| Orders (paged) | `orders` | full list with paging (live-verified) |
| Address book | `addressbook` | saved addresses (live-verified) |
| Shipments / labels | `orders/shipment` | create a shipment + label (per docs) |
| Tracking | `track` | tracking status (per docs) |

---

## Gotchas

- **Two keys, always.** Every call needs BOTH `StarShipIT-Api-Key` and `Ocp-Apim-Subscription-Key`. Sending only the API key is the most common failure.
- **404 with a JSON body ≠ auth failure.** `{"statusCode":404,"message":"Resource not found"}` means the *path* is wrong but auth passed; a real auth failure is **401/403**. Use this to tell "wrong endpoint" from "bad keys".
- **Subscription key may need generating once.** A fresh account often has the API key but an empty subscription key - Generate + Save it (Phase 1 Step 3). It's reversible (regenerate to rotate).
- **Both keys are full-account secrets.** Store mode 600, never in git, never echo. Rotate via Settings → API (Regenerate).
- **Never snapshot the sign-in page** (password leak); detect login via `browser_wait_for`.
- **No substring-negation in self-checks.** Verify success by the explicit condition (`http_code == 200`), never "output does NOT contain an error word".
- **Capture keys via clipboard-transit, lengths only** - do not let any tool return print the key value (verified clean this way on install).
- **Rate limits:** ~2 req/s (Developer subscription) / ~20 req/s (Production); exceeding → **429**. Back off and retry.
- **Writes create real shipments/labels** (and can incur carrier charges) - confirm with the user before any order/shipment `POST`.

## Token handling

Both keys are bearer-equivalent secrets stored in `~/.config/starshipit/credentials.env` (mode 600), read into shell variables at call time, and **never** echoed to a narration line, tool return, or log. Add `**/credentials.env` to any nearby repo `.gitignore`; the canonical location is outside any repo.

## See also

- `examples/install-walkthrough-live.md` - a real, verified Phase 1 transcript (keys redacted).
- `references/rest-api.md` - endpoint catalogue, the dual-key header scheme, rate limits.
- `skills/CLAUDE.md` - direct-REST connector family (`ghl`, `myob`, `servicem8`, `cliniko`, `deputy`) and the Playwright contingency.
