---
name: myob-connector
description: "Connect MYOB accounting to Claude for existing paid MYOB subscribers, who provision and pay for their own MYOB Developer Program access (AUD $110/month). Use when the user asks to set up or connect MYOB, or wants MYOB work (invoices, quotes, bills, contacts, items, banking, payroll) and the connection isn't in place yet. Once connected, MYOB runs directly against its API with the stored credentials."
allowed-tools: Bash,Read,Write,Edit,mcp__plugin_playwright_playwright__*
metadata:
  category: Productivity & Integrations
  tags:
    - myob
    - accounting
    - invoices
    - contacts
    - finance
    - australia
    - rest-api
    - oauth
  pairs-with:
    - skill: xero-connector
      reason: Sibling AU accounting connector - Xero is the larger market share, MYOB is #2 in AU SMB. Some attendees use one, some the other, some both.
    - skill: quickbooks-connector
      reason: Sibling accounting connector for the global market - same conversational install pattern.
    - skill: outlook-connector
      reason: Same Playwright-MCP-driven OAuth Auth Code flow pattern. Reference for the no-user-browser golden rule and Playwright fallback handling.
    - skill: superpowers:systematic-debugging
      reason: Use when MYOB API errors are unclear or when token refresh fails repeatedly.
---
# MYOB Connector⁠​‌​‌​​‌‌​‌​​​‌​‌​‌​​‌‌​​​‌​‌​​‌​​​‌‌​​​‌⁠

**REQUIRED:** follow the connector doctrine in connector-scaffold (references/connector-doctrine.md) for comms, credentials, and browser lanes.

## What this connects

MYOB's direct REST API. There is no MCP server and no first-party CLI, so this connector reads saved tokens out of `~/.config/myob/tokens.json` and runs `curl` against MYOB's endpoints. Architectural decision recorded in [issue #146](https://github.com/selrai-company/claude-workshop-kit/issues/146).

**Two paid layers, both on the user, both required.**

1. **Developer access, recurring, AUD $110/month incl. GST.** MYOB is the only connector in this library with no free developer tier and no free sandbox. Xero and QuickBooks give developers API access for nothing; MYOB charges before the first call. The user joins the MYOB Developer Program themselves, registers their own app, and owns the resulting `client_id` and `client_secret`. Stage A below drives that.
2. **Their MYOB subscription, recurring.** A paid **MYOB Business or AccountRight** subscription. Free trials and accountant-only logins do not work. Without a real subscription there is no company file to read, and OAuth refuses to issue tokens.

```
  Developer Program  ──▶  authorises the CONNECTION POINT
  AUD $110/mo             (client_id + client_secret)
  ABN required                      │
  1-5 days to approve               ▼
                          MYOB subscription  ──▶  authorises THE DATA
                          Business or AccountRight    (their company file)
```

Nobody else's credentials are involved. There is no shared key, no bundled app, no fee anyone else is covering. State the $110 up front and never imply otherwise.

**What this deliberately does not use:**

- **An MCP server.** None exists. CData ships a third-party read-only MCP over JDBC; the Java runtime dependency plus the read-only limit make it a poor fit. Direct REST is the v1 path.
- **Bearer-only auth.** MYOB requires *both* `Authorization: Bearer <token>` *and* `x-myobapi-key: <client_id>` on every call. Generic OAuth clients forget the second header and fail with confusing 401s. Always set both.
- **`x-myobapi-cftoken`.** Only relevant to AccountRight cloud company files with their own file password. Not implemented in v1.
- **`.env` files for tokens.** Access tokens rotate every 20 minutes, so an env-var pattern would force a shell reload on each refresh. Tokens live in `~/.config/myob/tokens.json` at mode 0600, rewritten atomically.

## No-deviation rule

When a step fails, follow that step's documented branch. Do not improvise with `gcloud`, `curl --user`, basic auth, or any scheme this skill does not name. A failure with no documented recovery gets stated plainly and stops. No silent pivot.

## Phase 0: resume check

Silent, every invocation. Two files decide where to go, in this order.

```bash
CRED=~/.config/myob/credentials.json     # their developer app: client_id + client_secret
TOK=~/.config/myob/tokens.json           # their live connection: access + refresh + company file
```

| State on disk | Where to go |
|---|---|
| `tokens.json` has `access_token` + `refresh_token` + `company_file.uri` | **Phase 2.** Connected. Never make them redo setup. |
| `credentials.json` has both keys, no valid `tokens.json` | **Phase 1 Stage B.** They already own a developer app; just connect it. |
| Neither, or `credentials.json` incomplete | **Phase 1 Stage A.** They need developer access first. |

Native Windows uses `%APPDATA%\myob\` for both. Never narrate any of this.

`credentials.json`, mode 0600, directory 0700, never committed anywhere:

```json
{ "client_id": "<their-app-key>", "client_secret": "<their-app-secret>" }
```

## Safety gate: is MYOB even the right answer

The skill may have loaded on an ambient match ("can you connect my accounting?") rather than a real MYOB need. Ask before pushing anything:

> "Quick check before I help: do you currently have a **paid MYOB subscription** that you use for your business, or are you just curious about MYOB?"

| They say | You say |
|---|---|
| They pay for MYOB | Continue to the cost gate. |
| Not currently using it / just curious / shopping around | *"No worries. I won't set up MYOB, since it only makes sense if you already pay for a subscription. If you're using **Xero**, that's ready to go here and I can connect it now. QuickBooks too. What does your business actually use today?"* Then route to `xero-connector` or `quickbooks-connector`. Do not return to MYOB. |
| They use something else | Route to the matching connector. Do not return to MYOB. |

## Cost gate: the $110, said out loud, before any browser

**This gate is mandatory and it runs before Stage A.** MYOB charges for API access and the user pays it. Never soften it, never bury it, never open a browser before they have said yes to the money.

Send ONE message and wait:

> **"Before we start, the one thing you need to know about MYOB.**
>
> **MYOB charges AUD $110 a month (including GST) just to let outside software connect to your account.** That's paid to MYOB, on top of your normal MYOB subscription. Xero and QuickBooks don't charge this; MYOB does. It's their fee, not mine, and there's no free version of it.
>
> **There's also a wait.** You have to join MYOB's Developer Program, which takes 1 to 5 business days to approve, and you'll need your ABN handy.
>
> **So the honest picture:** today I can get your application in. In a few days, when MYOB approves you, we finish the connection in about two minutes.
>
> **Want me to start the application?"**

| They say | You do |
|---|---|
| Yes | Stage A. |
| Not at that price | *"Completely fair. If you use Xero as well, that connects for about $5 a month instead, and I can do it right now. Otherwise, say 'connect my MYOB' whenever you want to revisit it."* Stop. Route to `xero-connector` if they use Xero. |
| Asks why it costs so much | *"No good reason I can defend. MYOB charges developers for access where Xero and QuickBooks don't. It's a pricing decision on their end and it applies to every tool that connects to MYOB, not just this one."* Then re-ask once. |
| Asks whether they can avoid it | *"Not through MYOB's connection, no. The only way around it is exporting reports out of MYOB by hand, which I can then read. Slower, but free."* |
| Already has developer access | Skip the money talk, go straight to Stage A step 4 and collect the existing app's keys. |

Never proceed on silence or a vague answer. The user is agreeing to a recurring charge; get a real yes.

## Subscription and product line

### Their login must be on the account

**Without a real paid subscription, MYOB refuses to issue OAuth tokens. There is no company file to authorise.** Two answers need handling before anything else:

| They say | You do |
|---|---|
| No subscription / free trial | *"In that case I won't set up MYOB. It only works with a real subscription. If you already use Xero or QuickBooks, I can connect either instead. What does your business currently use?"* Route to `xero-connector`, the closest sibling for AU SMBs. Stop here. |
| Has MYOB only through their accountant | *"Got it. I'll need a login that's directly on the MYOB account, typically the business owner's. Do you have one, or would you need to request access first?"* Wait for clarification. |

### Product line

The product line changes the endpoint shape, so confirm it.

> "Great. MYOB makes two flavours of accounting software, and the connection works slightly differently for each:
>
> - **MYOB Business** is the cloud-first one most newer accounts use. Plans are called Lite, Pro, or Solo, with a monthly subscription.
> - **MYOB AccountRight** is the older desktop-and-cloud hybrid. Plans are called Plus or Premier.
>
> Which do you have? If you're not sure, sign in at my.myob.com and the product name appears at the top of your dashboard."

| They say | You do |
|---|---|
| MYOB Business | Main path. Most accounts opened in the last few years. |
| MYOB AccountRight | *"That works too, the connection's similar, the data just lives in a slightly different shape."* Continue, but use the AccountRight company file URI shape (`/accountright/<file-id>/...`) in Phase 2 rather than the Business shape. |
| Not sure | *"Easiest way: open my.myob.com and tell me what the dashboard says at the top."* Wait, then proceed. |
| MYOB Solo only | *"Solo is MYOB's mobile-first product and it doesn't expose the same data through the connection I use, so I can't connect Solo accounts."* Stop. Solo runs on a different API surface. |
| Refuses to clarify | *"No problem, we can pick this up another time. Just say 'connect my MYOB' whenever you're ready."* Do not proceed. |

One developer app works against either product line. The only differences are the company-file URI returned during discovery and the resource paths in Phase 2.

## Phase 1 Stage A: get their own developer access

Skip this entire stage when `~/.config/myob/credentials.json` already holds both keys.

Runs on the doctrine's browser lane ladder: Claude's native browser lane first, then `agent-browser`, then Playwright MCP as the documented fallback. Every step is a goal, not a selector. Snapshot, read what is actually on the page, act, re-snapshot after every state change. MYOB reshapes this portal regularly; a hardcoded selector will rot and a snapshot will not.

**This stage spans days, not minutes.** Steps 1-2 happen now. Steps 3-5 happen after MYOB emails their approval. Say so plainly rather than leaving them waiting on a browser that has gone quiet.

### Step 1: the application

Ask for the two things the form needs, in one message:

> "I'll fill in the application. Two things I need from you: your **ABN**, and the **business email** you want MYOB to use for the developer account."

Then navigate to the Developer Program application form:

```
https://apisupport.myob.com/hc/en-us/requests/new?ticket_form_id=6175906535311
```

Fill it from their answers and submit. Never ask them to fill it themselves; you drive, they answer questions in chat.

| What goes wrong | Handling |
|---|---|
| Form asks for something only they know (trading name, industry, expected call volume) | Ask for that one field in plain English, then keep going. Volume: say "a handful of requests a day, one business". |
| Form has changed shape or moved | Snapshot, read the page, adapt. If the URL 404s, search `developer.myob.com` for the current application path rather than guessing. |
| Submission fails | Retry once. Then: *"MYOB's application form isn't accepting submissions right now. I'll leave this here and we can try again later, nothing's lost."* |

### Step 2: tell them what happens next

> "Application's in. MYOB reviews it, which takes **1 to 5 business days**, and they'll email you when it's approved. Two things happen then: you'll set up the **$110 a month** developer subscription, and I'll finish the connection in about two minutes.
>
> When that email lands, just come back and say **'connect my MYOB'** and I'll pick up exactly where we left off."

Then stop. Do not poll, do not schedule anything, do not leave a browser open. Phase 0's resume check is what brings them back to the right place.

### Step 3: activate the subscription (after approval)

When they return approved, navigate to `https://developer.myob.com` and have them sign in. The Developer Access subscription is activated from the account or billing area of the portal.

**Payment details are theirs to enter.** Take them to the right screen, then say:

> "This is the payment page for MYOB's $110 a month developer access. I'll leave the card details to you. Tell me when it's gone through."

Never type card numbers. Never read them back. Wait for their confirmation.

### Step 4: register the app

In the developer portal, create a new app. Fill:

| Field | Value |
|---|---|
| App name | `Claude Assistant` |
| Description | `Reads and updates my MYOB data on my behalf` |
| Redirect URI | `http://localhost:8765/callback` |

The redirect URI is the one that matters and it must match Stage B exactly, character for character. A mismatch here surfaces later as an opaque `invalid_grant` and is the single most common cause of a failed first connection.

If the portal offers a scope or permission list, select the sales, purchases, banking, contacts, inventory, general-ledger and company-file scopes. Skip payroll unless they have asked for payroll specifically; extra scope is extra exposure.

### Step 5: capture the keys

Read the `client_id` (MYOB may label it "API Key" or "Client ID") and `client_secret` off the app detail page. Some portals hide the secret behind a "show" or "reveal" control — click it, then read.

Validate before saving: both non-empty, no whitespace, secret longer than 16 characters. A value failing the shape check means re-snapshot and re-read, never save-and-hope.

```bash
mkdir -p ~/.config/myob && chmod 700 ~/.config/myob
jq -n --arg cid "$CLIENT_ID" --arg csec "$CLIENT_SECRET" \
  '{client_id:$cid, client_secret:$csec}' > ~/.config/myob/credentials.json.tmp
chmod 600 ~/.config/myob/credentials.json.tmp
mv ~/.config/myob/credentials.json.tmp ~/.config/myob/credentials.json
```

**Never echo either value.** Not to chat, not to a log, not truncated, not "for your reference". Capture, validate, write, close the browser. Then go straight into Stage B in the same session.

## Phase 1 Stage B: connect

Runs on the doctrine's browser lane ladder: Claude's native browser lane first, then `agent-browser`, then Playwright MCP (`mcp__plugin_playwright_playwright__browser_*`) as the documented fallback. Never send the user to open a link in their own browser. You drive the sign-in and read the redirect out of the address bar yourself.

### Step 1: orient

> "Great, let's connect your MYOB. I'll open MYOB's sign-in page in a small browser window in just a moment. Sign in like normal, pick the business you want me to connect to, and approve. The whole thing takes about two minutes."

### Step 2: loopback listener

Silently start a localhost listener on port 8765 to catch the redirect carrying the authorization code:

```bash
nohup python3 -c "
import http.server, urllib.parse, sys
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a, **k): pass
    def do_GET(self):
        q = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(q)
        code = params.get('code', [''])[0]
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(b'<h1>MYOB connected. You can close this tab.</h1>')
        with open('/tmp/myob-auth-code', 'w') as f:
            f.write(code)
        sys.exit(0)
http.server.HTTPServer(('127.0.0.1', 8765), H).serve_forever()
" > /tmp/myob-listener.log 2>&1 &
echo $! > /tmp/myob-listener.pid
```

Port 8765 in use means incrementing to 8766, 8767 and so on, and updating the `redirect_uri` in Step 3 to match.

### Step 3: open the authorization page

Load their own credentials first, then build the URL. The default scope set covers everything this skill supports; trim only if the user wants a subset.

```bash
MYOB_CLIENT_ID=$(jq -r .client_id ~/.config/myob/credentials.json)
MYOB_CLIENT_SECRET=$(jq -r .client_secret ~/.config/myob/credentials.json)
```

Both are read from disk on every use. Never echo either one.

```
https://secure.myob.com/oauth2/account/authorize
  ?client_id=<MYOB_CLIENT_ID>
  &redirect_uri=http%3A%2F%2Flocalhost%3A8765%2Fcallback
  &response_type=code
  &scope=CompanyFile%20la.global%20sme-company-file%20sme-company-settings%20sme-sales%20sme-purchases%20sme-banking%20sme-contacts-customer%20sme-contacts-supplier%20sme-contacts-employee%20sme-payroll%20sme-inventory%20sme-general-ledger
  &prompt=consent
```

Navigate to it on the browser lane, then:

> "I've opened MYOB's sign-in window. Please sign in with the email and password you use for MYOB, then pick the business you want me to connect to and click Allow."

Poll `/tmp/myob-auth-code` every 3 seconds for up to 5 minutes. The authorization code expires 2 to 5 minutes after MYOB issues it, so a longer wait is wasted.

| What goes wrong | Handling |
|---|---|
| The login has no company file attached; the post-Allow page says "no companies available" | *"Looks like the account you signed in with doesn't have a business attached yet. If you have a different MYOB login tied to your business, let's try that, otherwise you'd need to set up a company file in MYOB first."* Stop and let them choose. |
| User cancels at Allow; the redirect carries `?error=access_denied` | *"No worries, looks like you didn't approve the connection. Want to try again, or stop here?"* |
| The browser window closes | Re-open the same URL. They may need to sign in again. |

### Step 4: exchange the code for tokens

```bash
AUTH_CODE=$(cat /tmp/myob-auth-code)
RESP=$(curl -sf https://secure.myob.com/oauth2/v1/authorize \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$MYOB_CLIENT_ID" \
  -d "client_secret=$MYOB_CLIENT_SECRET" \
  -d "scope=CompanyFile" \
  -d "code=$AUTH_CODE" \
  -d "redirect_uri=http://localhost:8765/callback" \
  -d "grant_type=authorization_code")

# Tear down the listener
kill "$(cat /tmp/myob-listener.pid)" 2>/dev/null
rm -f /tmp/myob-auth-code /tmp/myob-listener.pid /tmp/myob-listener.log
```

The response carries `access_token`, `refresh_token`, `expires_in` (seconds), `scope` and `user`. Hold it for Step 5; nothing hits disk yet.

| Failure | Handling |
|---|---|
| 400 `invalid_grant` | The code expired, more than 5 minutes since Allow. *"The connection code timed out, let's try once more, faster."* Restart from Step 2. |
| 400 `invalid_client` | Their app keys are wrong, revoked, or the developer subscription has lapsed. *"MYOB isn't accepting the connection keys. That usually means the developer subscription has lapsed or the app was removed. Let me check your developer account and re-register it."* Re-run Stage A from step 4. Do not retry the exchange. |
| Network error | Retry once after 5 seconds. Still failing: *"MYOB's servers aren't responding right now. Want to try again in a minute?"* |

### Step 5: discover the company file

The token unlocks the API but says nothing about which file to target.

```bash
ACCESS_TOKEN=$(echo "$RESP" | jq -r .access_token)
FILES=$(curl -sf https://api.myob.com/accountright \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-myobapi-key: $MYOB_CLIENT_ID" \
  -H "x-myobapi-version: v2" \
  -H "Accept: application/json")
```

A JSON array comes back, each item with `Id`, `Name`, `Uri`, `LibraryPath`. Show the user names only.

- **One file** → pick it silently, continue.
- **Several** → "I can see a few businesses on your MYOB account: **Acme Trading**, **Beta Holdings**, **Gamma Pty Ltd**. Which one would you like me to connect to?" Match case-insensitively.
- **None** → "Hmm, your MYOB account doesn't seem to have any businesses set up yet. You'd need to create one in MYOB first: happy to wait if you want to do that now." Stop.

**AccountRight cloud files.** If the picked file's `"ProductLevel": { "Code": ... }` indicates a cloud-stored file with a company-file password, data calls would need `x-myobapi-cftoken: Base64(file-username:file-password)`. v1 does not support that: *"This MYOB file has its own password I can't get past from here, so the connection can't read it yet."* Stop.

### Step 6: save tokens and verify

Compute `expires_at` as now plus `expires_in`, ISO 8601 UTC, then write atomically:

```bash
mkdir -p ~/.config/myob
chmod 700 ~/.config/myob

EXPIRES_AT=$(python3 -c "
import datetime, sys
secs = int(sys.argv[1])
print((datetime.datetime.utcnow() + datetime.timedelta(seconds=secs)).strftime('%Y-%m-%dT%H:%M:%SZ'))
" "$(echo "$RESP" | jq -r .expires_in)")

jq -n \
  --arg at "$(echo "$RESP" | jq -r .access_token)" \
  --arg rt "$(echo "$RESP" | jq -r .refresh_token)" \
  --arg sc "$(echo "$RESP" | jq -r .scope)" \
  --arg user "$(echo "$RESP" | jq -r .user.username)" \
  --arg fid "$FILE_ID" \
  --arg fname "$FILE_NAME" \
  --arg furi "$FILE_URI" \
  --arg exp "$EXPIRES_AT" \
  '{access_token:$at, refresh_token:$rt,
    expires_at:$exp, scope:$sc, username:$user,
    company_file:{id:$fid, name:$fname, uri:$furi}}' \
  > ~/.config/myob/tokens.json.tmp

chmod 600 ~/.config/myob/tokens.json.tmp
mv ~/.config/myob/tokens.json.tmp ~/.config/myob/tokens.json
```

Always write `.tmp`, chmod, then rename. A partially written `tokens.json` must never exist on disk. File mode 0600, directory mode 0700.

**`tokens.json` holds session state only.** The `client_id` and `client_secret` live in `credentials.json` and are never copied here. One file, one copy, one thing to revoke.

Then one live read, the lowest-stakes one every account has:

```bash
COMPANY_URI=$(jq -r .company_file.uri ~/.config/myob/tokens.json)
curl -sf "$COMPANY_URI/Contact/Customer?\$top=1" \
  -H "Authorization: Bearer $(jq -r .access_token ~/.config/myob/tokens.json)" \
  -H "x-myobapi-key: $(jq -r .client_id ~/.config/myob/credentials.json)" \
  -H "x-myobapi-version: v2" \
  -H "Accept: application/json" > /dev/null
```

| Result | Handling |
|---|---|
| HTTP 200 | *"All done, your MYOB is now connected to **[company file name]**. You can ask me things like 'show me my recent invoices', 'who owes me money?', or 'create an invoice for [client] for [amount]'."* No restart needed. |
| HTTP 401 | Run the refresh flow once, retry the verify. Still 401 means re-running Stage B from Step 2. |
| HTTP 403 | Scope mismatch. *"I'm connected, but I'm missing one permission. Let me re-run the connection with the right one."* Restart Stage B with the missing scope added in Step 3. |
| Anything else | *"The connection went through but I can't read anything yet. Let me try once more."* Retry once, then name the problem plainly ("MYOB's saying 503, its servers may be having a moment") and ask whether to retry or stop. |

---

## Phase 2: runtime loop

```
1. Read ~/.config/myob/tokens.json.
   - Missing → back to Phase 0's resume check, which routes to Stage A or Stage B correctly.
   - expires_at within the next 60 seconds → refresh first.
2. Build the request:
   - URL = company_file.uri + endpoint path
   - Headers (every call):
       Authorization: Bearer <access_token>
       x-myobapi-key: <client_id>   (from credentials.json)
       x-myobapi-version: v2
       Accept: application/json
   - Headers (POST/PUT only): Content-Type: application/json
3. Execute via curl with -sf so non-2xx exits non-zero.
4. Handle the response:
   - 2xx → parse, present in plain English, never raw JSON.
   - 401 → refresh, retry the original request once.
   - 403 → scope missing. Name the capability, offer to re-run Stage B.
   - 429 → respect Retry-After (default 30s), wait, retry once.
   - 5xx → say MYOB is having trouble, offer one retry.
   - other 4xx → translate to plain English, do not retry blindly.
```

### Refresh

Access tokens live 20 minutes (1200s). Refresh proactively under 60 seconds to expiry, or reactively on the first 401.

```bash
RESP=$(curl -sf https://secure.myob.com/oauth2/v1/authorize \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$(jq -r .client_id ~/.config/myob/credentials.json)" \
  -d "client_secret=$(jq -r .client_secret ~/.config/myob/credentials.json)" \
  -d "refresh_token=$(jq -r .refresh_token ~/.config/myob/tokens.json)" \
  -d "grant_type=refresh_token")

EXPIRES_AT=$(python3 -c "
import datetime, sys
print((datetime.datetime.utcnow() + datetime.timedelta(seconds=int(sys.argv[1]))).strftime('%Y-%m-%dT%H:%M:%SZ'))
" "$(echo "$RESP" | jq -r .expires_in)")

jq --arg at "$(echo "$RESP" | jq -r .access_token)" \
   --arg rt "$(echo "$RESP" | jq -r .refresh_token)" \
   --arg exp "$EXPIRES_AT" \
   '.access_token=$at | .refresh_token=$rt | .expires_at=$exp' \
   ~/.config/myob/tokens.json > ~/.config/myob/tokens.json.tmp
chmod 600 ~/.config/myob/tokens.json.tmp
mv ~/.config/myob/tokens.json.tmp ~/.config/myob/tokens.json
```

Refresh tokens **rotate** on every refresh, so always save the new one. `invalid_grant` on refresh means the chain is dead: run Stage B from Step 2. Their credentials are still good; only the user session died. Refreshing is invisible to the user, do not narrate it.

### Endpoints

Full catalogue, OData filter syntax and field-shape notes: [references/rest-api.md](references/rest-api.md).

### Prompt to action mapping

| What the user says | What you do |
|---|---|
| "Connect my MYOB" / "Set up MYOB" / "Help with my MYOB" | Phase 0 resume check, then the safety gate and cost gate |
| "Show me my invoices" | GET `/Sale/Invoice/Item?$top=10&$orderby=Date desc` |
| "List unpaid invoices" / "Who hasn't paid me?" | GET `/Sale/Invoice/Item?$filter=Status eq 'Open'` |
| "Show me overdue invoices" | Same, then filter client-side by `DueDate < today` |
| "Find invoices for [client]" | GET `/Contact/Customer?$filter=substringof('[name]',CompanyName)` for the UID, then `/Sale/Invoice/Item?$filter=Customer/UID eq guid'<UID>'` |
| "Create an invoice for [client] for [amount]" | **Confirm first.** POST `/Sale/Invoice/Item` with the customer UID, today's date, and the line. |
| "Find [name] in my contacts" | GET `/Contact/Customer?$filter=substringof('[name]',CompanyName)` |
| "Add a new customer for [name]" | **Confirm first.** POST `/Contact/Customer`. |
| "Show me my chart of accounts" | GET `/GeneralLedger/Account` |
| "List my bank transactions" | GET `/Banking/SpendMoneyTxn` and `/Banking/ReceiveMoneyTxn`, merged by date |
| "Record a payment from [client] for [amount]" | **Confirm first.** POST `/Banking/ReceiveMoneyTxn`. |
| "What tax codes are available?" | GET `/GeneralLedger/TaxCode` |
| "Show me my products" / "List my items" | GET `/Inventory/Item` |
| "Show me my suppliers" | GET `/Contact/Supplier` |
| "Create a quote for [client]" | **Confirm first.** POST `/Sale/Quote/Item`. |
| "Show me my bills" / "What do I owe?" | GET `/Purchase/Bill/Item?$filter=Status eq 'Open'` |
| "Switch to my other MYOB business" | Re-run Stage B from Step 5. Auth tokens stay valid; only `company_file.*` changes. |

### Operating rules

- **Confirm before creating, updating, or moving money.** Summarise first: *"I'm going to create an invoice for Acme Trading for $1,200 plus GST, dated today: does that look right?"*
- **MYOB invoices are created Open, not Draft.** Different from Xero, so be explicit: *"I've created the invoice: it's now in MYOB ready to send. You can preview and email it from the MYOB website."*
- **Look up reference data before every write.** Customer UID before an invoice, account code before a bank transaction, tax code before an invoice in a tax-registered file. Never guess a UID.
- **Currency comes from the company file.** Default AUD for AU MYOB; respect the file's currency where multi-currency is on.
- **Readable summaries, never raw JSON.** *"You have 12 unpaid invoices totalling $34,500. The biggest is Acme Trading for $8,200, dated 14 days ago. Want me to list them all?"*
- **Small pages.** `$top=10` unless asked for everything, then offer more.
- **One company file at a time.** A question about a different business gets: *"I'm currently connected to [current company file]. Want me to switch over?"* then a Stage B Step 5 re-run.

### Service-specific failures

| Error | What you say | How to fix |
|---|---|---|
| 401 first time | (silent) | Refresh, retry once |
| 401 after refresh | "Your MYOB connection has expired, let me reconnect you." | Stage B from Step 2 |
| 403 / `insufficient_scope` | "I'm connected, but I don't have permission for that yet, let me get the right access." | Read the missing scope from the error body, re-run Stage B with it added to the Step 3 URL |
| 400 field validation error | Translate the field name plainly: *"MYOB says the invoice date is wrong, let me fix that and try again."* | Correct and retry once. If the user's input is the problem, ask. |
| `invalid_grant` on refresh | "Your MYOB connection has expired completely, let me reconnect you from scratch." | Stage B from Step 2 |
| `tokens.json` missing or corrupt | "Looks like your MYOB connection got reset, let's set it up again." | Stage B from Step 2 |
| Company file URI returns 404 | "The MYOB business I was connected to seems to have been deleted or renamed, let me re-pick it." | Stage B from Step 5 |

## Can and cannot

Can: read invoices, quotes, bills, contacts (customer, supplier, employee), inventory items, bank transactions, the chart of accounts and tax codes; create invoices (item and service), quotes, bills, customers, suppliers, items, and spend-money / receive-money transactions; read payroll metadata where `sme-payroll` was granted; switch company files on the same login; refresh tokens silently every 20 minutes.

Cannot, in v1:

- **Delete** records. MYOB UI only.
- **Email** invoices or quotes to customers. The user sends from the MYOB UI after the draft exists.
- **Reconcile** bank transactions against statement lines.
- **File** BAS, IAS, or any tax return or payroll lodgement.
- **Connect several company files at once.** One file per `tokens.json`; switching means a Stage B Step 5 re-run.
- **Read AccountRight cloud files with a company-file password.** `x-myobapi-cftoken` is unimplemented.
- **Reach MYOB Solo.** Mobile-only product on a different API surface.
- **Pull pre-built reports.** MYOB's REST API exposes no P&L or Balance Sheet the way Xero does. Compose them from `/Sale/Invoice`, `/Banking/*` and `/GeneralLedger/Account` aggregations if asked.

## Honest status: what has and has not been proven

**Read this before promising anything.** Every endpoint path, scope name and header in this skill comes from MYOB's published documentation. **None of it has been exercised against a live MYOB account**, because that requires the $110/month developer access and nobody has held it yet. The architecture is sound and the flow is complete; the wiring is unverified.

Say so if asked. Never claim this connector is proven.

Settled, and not worth revisiting:

- [x] **Direct REST via `curl`.** No MCP server exists for MYOB and no first-party CLI. CData's third-party MCP is read-only over JDBC and drags in a Java runtime. Direct REST is the path.
- [x] **The user pays and owns their developer app.** No shared key, no bundled credentials, no fee absorbed elsewhere. Revised 2026-08-06.
- [x] **Scoped to existing paid subscribers.** The skill self-filters and routes everyone else to the Xero connector, which is cheaper and already proven.

Unproven, in rough order of how likely each is to bite:

- [ ] **First live call.** No request has ever returned a real 200. Expect at least one surprise on the first genuine connection.
- [ ] **The developer portal walkthrough.** Stage A steps 3 to 5 are written from MYOB's documented flow, not from driving the real portal. Snapshot and adapt rather than trusting the described layout.
- [ ] **AccountRight company-file URI shape.** The endpoint reference is written for MYOB Business. AccountRight may need an `/accountright/<file-id>/...` prefix instead of the `Uri` that discovery returns.
- [ ] **Native Windows.** Phase 1 is bash, so macOS and WSL only. Windows needs PowerShell equivalents.
- [ ] **Idempotent re-run.** A second Phase 1 should detect valid tokens and skip; corrupt or expired tokens should trigger fresh auth without confusing the user. Untested.
- [ ] **Troubleshooting coverage.** The failure tables cover documented errors, not errors seen in the wild.

Whoever gets the first live connection working: correct this section from what actually happened, and tick what genuinely passed. Leave the rest unticked. An unverified box is worth more than a confidently wrong one.

## Pairs with

- `xero-connector`: the other major AU accounting connector, larger market share, different auth model (Custom Connection `client_credentials`, no per-user OAuth). Route by which platform the user actually pays for.
- `quickbooks-connector`: sibling accounting connector for the global market, same conversational install pattern
- `outlook-connector`: reference implementation for the browser-driven OAuth authorization-code flow
- `first-run-setup`: the conversational bootstrap pattern Phase 1 follows
- `superpowers:systematic-debugging`: when token refresh fails repeatedly or an API error has no documented recovery

Router key `sk-r4g89o` — resolved by the skills index on load.
