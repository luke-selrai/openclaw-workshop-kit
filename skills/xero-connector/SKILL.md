---
name: xero-connector
description: "Connect Xero to Claude by switching on its built-in connector or its read-only Custom Connection. Use when the user asks to set up or connect Xero, or wants Xero or accounting work (invoices, contacts, bills, quotes, credit notes, the chart of accounts, bank transactions, payments, tax rates, tracking categories, profit and loss, balance sheet, trial balance, aged receivables) and Xero isn't connected yet. Neither route writes to the books."
allowed-tools: mcp__claude_ai_Xero__*, mcp__xero__*, mcp__playwright__*, Bash, Read, Write, Edit
---

# Xero Connector⁠​‌​‌​​‌‌​‌​​​‌​‌​‌​​‌‌​​​‌​‌​​‌​​​‌‌​​​‌⁠

**Provenance.** This skill is Luke's, vendored from [SelrAI-Skool-Community/xero-preparation-stack](https://github.com/SelrAI-Skool-Community/xero-preparation-stack) (`xero-connector/`, upstream commit `5202bf8`, 2026-08-12; upstream `SKILL.md` sha256 `653ee6f3469f738e5e347c5e1f455ad059190a778f4f6de0b9f043479a56be18`). The kit's copy differs in three places only: the frontmatter (Template B description, `allowed-tools`), the two stack-path references just below, and the built-in-connector routing layer ("Two routes into Xero" through the built-in Phase 1). Everything from "What this connects" down is upstream, unchanged. Re-sync by diffing against that commit; never edit the locks.

**Fresh-machine use:** connect your own Xero Custom Connection; the operator's Keeper and
launchers are optional deployment notes. This skill ships in this kit on its own; the full
12-skill Xero stack it comes from is optional and lives at
[github.com/SelrAI-Skool-Community/xero-preparation-stack](https://github.com/SelrAI-Skool-Community/xero-preparation-stack)
(deployment notes in `xero-api-core/references/INSTALL.md` there).

**If `connector-scaffold` is installed beside this skill, follow its connector doctrine
(references/connector-doctrine.md) for comms, credentials and browser lanes.** It does not ship
in this kit — it belongs to the optional stack at
[github.com/SelrAI-Skool-Community/xero-preparation-stack](https://github.com/SelrAI-Skool-Community/xero-preparation-stack).
It is a house style for connector skills, not a dependency of this one: nothing below needs it,
and a release that ships this skill on its own is complete. It used to be marked REQUIRED while
not being part of any install list, which left a reader looking for a file that was never sent.

## Two routes into Xero — interview first

Xero has two read routes into Claude, and this skill switches on whichever one the user's
actual need calls for. **Neither route writes.** Nothing set up here can create, edit,
approve or delete anything in Xero — changes stay in Xero, by design. Say that plainly in
the interview and again at hand-off.

Before opening anything, ask **one** question in plain English: what do they want Claude to
do with Xero? Offer the surfaces as examples (*"a quick read on how the business is going —
profit, who owes you, cash? Or digging into individual invoices, contacts and bank
transactions?"*). If they under-specify ("connect my accounting"), double-check the adjacent
need once, in the same message. Then route:

| The user's need | Route |
|---|---|
| "How is the business going" — profit and loss, who owes them money (receivables), cash position, top customers | **The built-in Xero connector** (Phase 0/1 below). No fee, one click, read-only. First stop for these questions. |
| Detailed reads — individual invoices, contacts, bank lines, quotes, credit notes, manual journals, all reports; the full 51-tool read surface | **The Custom Connection route** — everything from "What this connects" onward. Read-only by design; $10 AUD/month Xero fee. |

Connect only what they named, and say in one line what you are *not* connecting and why, so
they can ask for it later. Both routes can coexist on one machine — never tear one down to
set the other up. The tool namespaces differ: the built-in's tools are
`mcp__claude_ai_Xero__*`; the Custom Connection's are `mcp__xero__*` (or
`mcp__xero-<orgslug>__*` for a second organisation).

Everything from "What this connects" down is the Custom Connection route, unchanged; its
"Phase 0 addition" and "Phase 1" headings number that route's own flow.

## Phase 0 — Is Xero already connected?

Run these silently, in order, and act on the first that answers.

1. **Built-in connector.** `claude mcp list` → look for a line starting `claude.ai Xero`.
   - `✔ Connected` → nothing to set up. Prove it with one read from the
     `mcp__claude_ai_Xero__*` namespace (e.g. this month's profit and loss) before saying so,
     then answer the user's question.
   - `! Needs authentication` → the connection has lapsed. Open
     `https://claude.ai/customize/connectors` for the user and say: *"Your Xero connection
     needs a quick re-sign-in. Press Reconnect next to Xero, sign in, and tell me when it
     says Connected."* Then re-run this check.
   - no such line → continue.
2. **The kit's own route.** Run the Custom Connection audit under "Phase 0 addition" below:
   any `mcpServers.xero` or `mcpServers."xero-<orgslug>"` entry, with both locks checked. If
   an entry is present and `mcp__xero__list-organisation-details` answers, keep using it —
   say *"Xero is already connected"* and go answer the question. Do not set the built-in up
   on top of a working connection.
3. **Nothing found** → run the interview above, then Phase 1 for the built-in route or the
   Custom Connection route for detailed reads.

If you cannot run commands at all (you are in claude.ai chat or the desktop app rather than
Claude Code), skip steps 1–2: go straight to Phase 1 and prove the result at Phase 1 step 5
by calling one of Xero's tools.

## Phase 1 — Switch on the built-in Xero connector (the default route)

This is a one-time, once-per-account job. The only thing the user does is press one button
and sign in. It covers the read-only "how is the business going" surface — profit and loss,
receivables, cash position, top customers — with no Xero fee.

**Step 1 — Check this session can see built-in connectors.** `claude auth status` must show
`"authMethod": "claude.ai"`. If it shows anything else, or `~/.claude/settings.json` has
`disableClaudeAiConnectors: true`, or `ENABLE_CLAUDEAI_MCP_SERVERS=false` is set, built-in
connectors will not appear here: tell the user in one line that this copy of Claude is
signed in a different way, and run the Custom Connection route instead.

**Step 2 — Open the connector page for them.** Say: *"I'm opening Xero's page in your
browser. Press **Connect to Claude**, sign in to Xero the way you normally do, and say yes
when it asks for access. That is the only part only you can do — tell me when it says
Connected."* Then open `https://claude.ai/directory/xero` in their own browser (`open` /
`xdg-open` / `start`). If that page doesn't load, open
`https://claude.ai/customize/connectors` instead and tell them: Browse → search "Xero" →
Connect. Opening the user's own browser is correct here even though the Custom Connection
route below never does it — that route reads credentials off pages in a driven browser; this
one reads nothing.

**Step 3 — Wait.** Stay hands-off while they sign in. Never ask for a password, a code, or a
screenshot of the sign-in.

**Step 4 — Verify.** `claude mcp list` again. `claude.ai Xero … ✔ Connected` is the pass.
Not there yet → ask them to fully quit and reopen Claude Code once (Mac: Cmd+Q; Windows:
close the window and quit from the tray), then check again. Still missing →
`! Needs authentication` means Reconnect on the Customize page; no line at all means the
Connect didn't complete — send them back to Step 2.

**Step 5 — Prove it.** Call one real read through the connector — one
`mcp__claude_ai_Xero__*` tool, e.g. this month's profit and loss. Only a real answer counts.
A tool error here is not "connected".

**Step 6 — Hand off.** Three lines: it's connected; it reads the books and can never change
them; and three things they can ask for now (the profit and loss, who owes them money, the
cash position).

**Team or Enterprise accounts:** if the page shows **Request** instead of **Connect**, their
Claude admin has to switch Xero on for the organisation first. Say so plainly and stop; do
not fall back to the Custom Connection route just to get past an admin gate.

---

## What this connects

Xero's official MCP server, `@xeroapi/xero-mcp-server`, installed globally and launched locally by absolute `node` path, authenticated with a **Custom Connection**. That is a Xero app type using the OAuth 2.0 `client_credentials` grant, bound to exactly one organisation. No consent screen, no refresh dance, no expiring user session. A Client ID and a Client Secret minted in the Xero developer portal are the whole credential.

Two facts shape everything below.

- One Custom Connection maps to one Xero organisation, 1:1 by design. A second org needs a second app and a second MCP entry.
- Xero charges a monthly fee to activate it. That gate runs first.

This connector's own steps call `jq` and `curl`. If `jq` is missing, `brew install jq --quiet` silently.

**Launch shape — the one thing that must not be changed back.** The MCP entry runs an absolute `node` binary against a globally installed, version-pinned copy of the server. It does **not** run `npx`. `npx -y <pkg>@latest` resolves the package from the npm registry *at launch time*: on a cold npm cache that download runs longer than Claude Code's MCP start-up window, so the server never prints a byte, the tools never register, and nothing anywhere logs a reason. A first-ever install is always a cold cache. Installing globally during setup moves that download to a moment where it can be waited on, and pinning the version keeps it cacheable. This machine's own four `~/bin` launchers already avoid npx for the same reason.

## Phase 0 addition

On top of the doctrine's pre-flight, check for an existing Xero entry before touching the portal. There may be more than one: a second organisation lives under `mcpServers."xero-<orgslug>"`, so audit every Xero entry, not just the plain one.

An existing entry is **never** assumed safe. Earlier versions of this connector, and other setup guides for the same MCP server, wrote write-capable configurations. Audit both locks on every entry before skipping ahead.

```bash
CONFIG="$HOME/.claude.json"
SETTINGS="$HOME/.claude/settings.json"

ENTRIES=$(jq -r '(.mcpServers // {}) | keys[] | select(. == "xero" or startswith("xero-"))' \
  "$CONFIG" 2>/dev/null)

[ -n "$ENTRIES" ] || echo "not configured — run the whole flow"

# `while read` with a here-string, not `for x in $ENTRIES`. zsh — the default Mac
# shell — does not word-split an unquoted parameter, so the loop would run once
# with every entry name mashed into one string and report the dangerous case clean.
while IFS= read -r ENTRY; do
  [ -n "$ENTRY" ] || continue
  CID=$(jq -r --arg e "$ENTRY" '.mcpServers[$e].env.XERO_CLIENT_ID // empty' "$CONFIG")
  CMD=$(jq -r --arg e "$ENTRY" '.mcpServers[$e].command // empty' "$CONFIG")
  PINNED=$(jq -r --arg e "$ENTRY" '.mcpServers[$e].env.XERO_SCOPES // empty' "$CONFIG")

  # Lock 1: is a read-only scope string pinned at all?
  # Do not write `grep -qv '\.read$'`. On BSD grep (every Mac) `-q` with `-v`
  # exits 1 even when a non-matching line exists — the dangerous case reads clean.
  OFFENDERS=$(printf '%s' "$PINNED" | tr ' ' '\n' | grep -v '\.read$')

  echo "--- mcpServers.$ENTRY"
  [ -n "$CID" ] && echo "    credentials present" || echo "    REPAIR: no client id"
  case "$CMD" in
    */node) echo "    launch shape OK" ;;
    ""|*npx) echo "    REPAIR: launched through npx, hangs on a cold cache" ;;
    *)      echo "    REPAIR: unrecognised launch command: $CMD" ;;
  esac
  if [ -z "$PINNED" ]; then
    echo "    REPAIR: no scope pin, the server would request its write-capable defaults"
  elif [ -n "$OFFENDERS" ]; then
    echo "    REPAIR: a write-capable scope is pinned: $(echo $OFFENDERS)"
  else
    echo "    lock 1 holds"
  fi
done <<EOF
$ENTRIES
EOF

# Lock 2: are the mutator deny rules present, on both tool-name forms?
for verb in create update delete add approve revert; do
  for prefix in "mcp__xero__" "mcp__xero-*__"; do
    jq -e --arg r "${prefix}${verb}-*" '.permissions.deny | index($r)' \
      "$SETTINGS" >/dev/null 2>&1 \
      || echo "REPAIR: ${prefix}${verb}-* is not denied"
  done
done
```

No entries at all means not configured — run the whole flow.

Entries present mean already configured, so never make the user redo setup. The credentials are reused and the portal is never reopened. Act on what the audit printed:

| What you found | Do |
|---|---|
| Both locks hold, `.command` is an absolute path ending in `node` | Nothing to repair. Skip to **restart and verify** and confirm it still works. |
| Either lock printed `REPAIR` | Re-run **write the config** and **Lock 2 — the deny rules** below with `ENTRY` set to the affected entry name, keeping its existing `XERO_CLIENT_ID` and `XERO_CLIENT_SECRET`. Both steps are merges, so nothing else in either file is disturbed. Then quit and reopen. |
| `.command` is `npx` (or anything ending in `npx`) | A legacy entry that hangs on a cold cache. Run the global install, then re-run **write the config** to rewrite `command`, `args` and `XERO_SCOPES` in place. Keep only the two credential values from the old `env` block, never the old scope string. |

**Say what you repaired.** If either lock was missing, tell the user plainly: *"Your Xero connection was set up without the read-only lock. I've pinned it to read-only and blocked every change-making tool. Nothing about your books changed, and you don't need to redo anything in Xero."*

A scope pinned in the config is not the same as a scope ticked in the Xero portal. Repairing lock 1 stops this machine ever *requesting* write authority, which is what matters here. If the portal app itself was created with write scopes ticked, lock 2 is what holds, and it holds regardless. Rebuilding the portal app as read-only is optional and is covered under **Write access** below.

**One exception, and do not get it wrong.** If the pinned string is the legacy V1 set (`accounting.transactions accounting.contacts accounting.settings accounting.reports.read`), the check above correctly reports it as write-capable — but **do not repair it by swapping in the granular read-only string blind.** A pre-29-Apr-2026 app that cannot serve granular scopes stops issuing tokens the moment you do, and a working connection breaks. Prove the replacement first with the smoke test below, which asks for the granular read-only set and falls back to the legacy read-only set on `invalid_scope`. Pin whichever `ACCEPTED_SCOPES` comes back.

**And never repair a write-capable pin by deleting it.** On an existing install that accepts neither read-only set, leaving the broad pin in place is the lesser evil: removing it makes the server request its own defaults, which are broader still. Repair lock 2, leave the pin, and say: *"Your connection uses Xero's older permission model and won't accept the read-only version of it. I've blocked every change-making tool on my side, so I can read your books and can't alter them. Rebuilding it as a fresh read-only connection is worth doing — say 'make it read-only' and I'll walk it."* A fresh install in that position writes no config at all; this rule is only for a connection that already exists and already works.

## Phase 1: cost and country gate (mandatory)

Send ONE message. Wait for all three answers before opening a browser.

> **"Before we start, three quick things:**
>
> **1. Cost.** Xero charges **$10 AUD a month including GST** for this type of connection, on top of your normal Xero subscription. Outside Australia, Xero bills in that country's own currency — read the amount off Xero's activation screen and quote that, because the screen is the price and this page is not. (Published at [developer.xero.com/custom-development](https://developer.xero.com/custom-development), verified 2026-08-10.)
>
> **2. Country.** This only works for Xero organisations in **Australia, New Zealand, UK, or US**.
>
> **3. Which Xero organisation** do you want me to connect? (If you only have one, just say 'the one I have'.)**
>
> **If you're happy with all three, give me your country + organisation name and I'll take it from here. You'll sign in once, then I'll do everything else."**

| User provides | You do |
|---|---|
| Country (AU/NZ/UK/US) + org name + implicit cost consent | Continue with `ORG_NAME` set |
| Country outside AU/NZ/UK/US | Stop cleanly: *"Xero Custom Connections aren't available for [country] orgs. The standard OAuth 2.0 app flow is the alternative. Say 'connect my Xero the standard way' and I'll drive that instead."* |
| Hesitant about cost | Answer calmly. Wait for explicit consent. No pressure. |
| Refuses cost | *"No problem. Say 'connect my Xero' any time."* |
| Only one field given | Ask once for the missing fields, combined into a single message |

## Phase 1: portal walkthrough

Run this on the browser lane ladder from the doctrine: Claude's native browser lane first, then `agent-browser`, then Playwright MCP. Verbatim Playwright tool calls and the DOM extractor functions live in [references/playwright-fallback.md](references/playwright-fallback.md).

Each step is a goal. Snapshot, read what is on the page, act, re-snapshot after every state change.

**1. Open the developer portal.** Navigate to `https://developer.xero.com/app/manage`. Tell the user: *"I've opened the Xero developer site. Sign in with your Xero email and password, and your 2FA code if you have one."*

**2. Confirm sign-in.** The signed-in state shows the user's name or email plus a **New app** button on the My apps page. A "Verify your email" banner means the developer account is unverified: the user checks their inbox, verifies, then you refresh and wait for the banner to clear.

**3. Create the app.** Click **New app**. Fill:

| Field | Value |
|---|---|
| App name | `Claude Assistant` |
| Company or application URL | `https://claude.ai` (any valid URL works) |
| Integration type | **Custom connection** |

Integration type is the one that matters. **Do not select "Web app"**. That grant type is incompatible with this MCP server. If the control is a radio group or dropdown, click the specific "Custom connection" option.

**4. Accept and create.** Tick the terms checkbox, click **Create app**, wait for the app detail page.

**5. Select the organisation.** Open the organisation dropdown, snapshot the open list, click the option matching `ORG_NAME`. If several match or none match exactly, name the options you can see and ask which one. An empty dropdown means that Xero login has no organisations attached. Say so and ask them to check they signed in with the right account.

**6. Tick the scopes — read-only.** Xero moved Custom Connections to **granular scopes** on 29 April 2026. Any app created today presents the granular list. Scroll the scopes section into view and tick, by label:

- `accounting.invoices.read`
- `accounting.payments.read`
- `accounting.banktransactions.read`
- `accounting.manualjournals.read`
- `accounting.reports.aged.read`
- `accounting.reports.balancesheet.read`
- `accounting.reports.profitandloss.read`
- `accounting.reports.trialbalance.read`
- `accounting.contacts.read`
- `accounting.settings.read`

That is the whole reporting surface with none of the write authority. The install covers every question a business owner actually asks — what am I owed, what do I owe, what did I spend, what does the P&L say — and cannot alter a single record while answering them. Ticking `accounting.invoices` instead of `accounting.invoices.read` hands the connection authority to create, edit and authorise invoices in the user's real books; the two labels sit next to each other in the portal, so read the suffix on every one before saving.

**Do not tick the server's own default set.** Read the note under *write the config*: the server's own defaults are write-capable, and the config pins the read-only string above so they are never requested. Someone who wants write access asks for it — see **Write access** below.

**No payroll. Tick nothing beginning `payroll.`, whatever the user asks for.** This connector does not do payroll, and the ten scopes above are the whole list. The plain `payroll.employees`, `payroll.settings` and `payroll.timesheets` labels are *view and manage* — write authority over somebody's real pay runs — and the server registers six payroll mutators behind them, `delete-timesheet` among them, the only delete it has. They also end in something other than `.read`, so the assertion in *write the config* rejects them and the install fails. Asked for payroll, say: *"This connection is accounting only, and read-only. Payroll needs write permissions I don't take on someone's live pay runs."*

**Legacy branch — app created before 29 Apr 2026.** Older apps were granted the broad V1 set: `accounting.transactions`, `accounting.contacts`, `accounting.settings`, `accounting.reports.read`. Three of those four carry write authority.

**Leave a working legacy app's portal scopes alone.** Saving a scope edit deactivates the connection until it is re-authorised, and Xero does not let a removed broad scope be re-added — a one-way ratchet. Nothing on this branch touches the portal.

**Read-only forms of those scopes exist.** This page used to say they did not, and that was wrong: Xero publishes `accounting.transactions.read`, `accounting.contacts.read` and `accounting.settings.read`, and `accounting.reports.read` is already read-only. `accounting.transactions.read` is marked deprecated and usable until September 2027; the other two were never part of the granular split and carry no deprecation at all. Since 29 April 2026 every Custom Connection can request granular scopes, and only *removing* a broad scope in the portal is irreversible — requesting a narrower set at token time is not. So lock 1 is very likely available here, and the honest way to find out is to ask Xero rather than assume either way.

The smoke test below does the work: it asks for the granular read-only set, and on `invalid_scope` retries with `LEGACY_READ_ONLY_SCOPES`. Pin whichever one Xero accepted. Then:

| Result | Do | Say |
|---|---|---|
| Either read-only set returns a token | Pin `ACCEPTED_SCOPES` and carry on | *"Your connection was set up under Xero's older permission model, but I've pinned it to the read-only version of those permissions, so I can read your books and can't change them. Nothing in Xero needed editing."* |
| Neither read-only set is accepted | **Write no config.** Do not pin the broad set to get an install finished | *"This connection only accepts Xero's older change-making permissions, and I won't set up a link to your books on those. Let's create a fresh connection instead — it takes the same few minutes and it comes out read-only."* |

**Never retry with, and never pin, a write-capable scope string.** There is no row on this table where that is the answer. Rebuilding means a new app from step 3, not a scope edit. The deny rules in *Two structural locks* below are mandatory on every branch, including the one that installs nothing.

**Scope override.** The server honours a `XERO_SCOPES` env var: set it in the MCP entry's `env` block to a space-separated scope string and the server requests exactly that, skipping the V1→V2 fallback. This install always sets it — see *write the config*.

> **⚠️ WARNING — editing scopes DEACTIVATES the connection.** Since the Apr-2026 change, saving any scope edit on a Custom Connection deactivates it. Tokens stop issuing (`Connection deactivated`) until the connection is re-authorised/re-activated (step 8 flow). Never casually edit the scopes of a live connection — and never touch the live selrai/heka connections' scopes without planning the re-activation immediately after.

**7. Save.** Click **Save** and wait for the confirmation state ("Saved", "successful", or the equivalent wording on the page).

**8. Activate, the paid step.** Xero now prompts to activate the connection, and the monthly charge starts here. Read the amount Xero shows on this screen and say it back to the user before confirming; if it differs from the figure quoted in the cost gate, Xero's screen wins and the user gets told the real number before anything is activated.

- *Payment method already on file:* activation confirms itself. Wait up to 30 seconds for "Connection active", "Activated", or "Subscription confirmed".
- *No payment method on file:* Xero shows a card form. This is the one field you never fill. Card entry is the user's own action. Say: *"Xero is asking for a payment method for the connection charge. Fill in your card details in the browser window I opened. I'll wait. Let me know when Xero says the connection is active."* Then wait up to 5 minutes for "Connection active".
- *Card rejected:* *"Xero couldn't process that card. Try a different one."* Wait and retry.
- *Activation asks for business details:* new developer accounts sometimes do. Fill what you can read off the page; ask only for what cannot be inferred.

**9. Read the Client ID off the page.** Xero renders it in a read-only field or a `<code>` element. Try `[data-testid="client-id"]`, `input[name="clientId"]`, `input[aria-label*="Client ID"]`, `code.client-id`, then a label-text walk from the "Client ID" label to the adjacent value.

Validate before keeping it: hex-like, 32+ characters, no whitespace. Invalid means re-snapshot and try a fresh selector strategy, twice, before anything else.

**10. Generate and capture the Client Secret.** Click **Generate a secret**. Xero reveals it once, in a modal or inline reveal, alongside a warning like "Save this secret" that it will not be shown again. Capture immediately: `[data-testid="client-secret"]`, `input[name="clientSecret"][readonly]`, `input[aria-label*="Client Secret"]`, `.modal code`, `.reveal-secret`, or a snapshot-driven walk from that warning text.

Validate: 40+ characters, base64-like charset, no whitespace.

**11. Close the reveal.** Click **I've saved the secret** / **Close** / **Done**.

Read `window.location.href` before closing the browser, then close it.

## Phase 1: smoke test before writing anything

Credentials that read cleanly off a page can still be wrong. Prove them against Xero before they touch config. This catches misreads, missing scopes, and an inactive subscription.

```bash
# The read-only granular set — apps created on/after 29 Apr 2026, the default today.
# This exact string is reused in the config below; keep the two identical.
READ_ONLY_SCOPES="accounting.invoices.read accounting.payments.read accounting.banktransactions.read accounting.manualjournals.read accounting.reports.aged.read accounting.reports.balancesheet.read accounting.reports.profitandloss.read accounting.reports.trialbalance.read accounting.contacts.read accounting.settings.read"

# That generation's own read-only set, for an app created before 29 Apr 2026.
# Every entry ends .read. Neither string contains a payroll scope.
LEGACY_READ_ONLY_SCOPES="accounting.transactions.read accounting.contacts.read accounting.settings.read accounting.reports.read"

# Whichever read-only set Xero actually accepted. Empty means connect nothing.
ACCEPTED_SCOPES=""

request_token() {
  curl -s -X POST "https://identity.xero.com/connect/token" \
    -u "${CLIENT_ID}:${CLIENT_SECRET}" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "scope=$1"
}

RESPONSE=$(request_token "$READ_ONLY_SCOPES")
ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty')

if [ -n "$ACCESS_TOKEN" ]; then
  ACCEPTED_SCOPES="$READ_ONLY_SCOPES"
elif [ "$(echo "$RESPONSE" | jq -r '.error // empty')" = "invalid_scope" ]; then
  # Legacy app. Retry with that generation's read-only set, never a write scope.
  RESPONSE=$(request_token "$LEGACY_READ_ONLY_SCOPES")
  ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token // empty')
  [ -n "$ACCESS_TOKEN" ] && ACCEPTED_SCOPES="$LEGACY_READ_ONLY_SCOPES"
fi

if [ -n "$ACCESS_TOKEN" ] && [ -n "$ACCEPTED_SCOPES" ]; then
  TENANT=$(curl -s -X GET "https://api.xero.com/connections" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" | jq -r '.[0].tenantName // empty')
  [ -n "$TENANT" ] && echo "OK: linked to $TENANT" || echo "FAIL: no tenant linked"
else
  echo "FAIL: $(echo "$RESPONSE" | jq -r '.error // .error_description // "unknown"')"
  echo "FAIL: no read-only scope set was accepted. Write no config for this app."
fi
```

**No write-capable scope string exists on this page to be pinned, and none is to be written.** The block asks for the granular read-only set, falls back to the legacy read-only set on `invalid_scope`, and stops. `ACCEPTED_SCOPES` is what *write the config* pins; empty means write nothing at all and tell the user to create a new Custom Connection. Both requests are token calls, not portal edits — neither can deactivate a live connection or remove a granted scope, so this is safe to run against an existing legacy app.

**An unpinned entry is not the safe middle ground; it is the worst state on this page.** Left unset, the server requests its own defaults: `XERO_DEFAULT_AUTH_SCOPES_V1` leads with `accounting.transactions` and carries the payroll write scopes, and the V2 fallback carries `accounting.invoices`, `accounting.payments`, `accounting.banktransactions` and `accounting.manualjournals`. Dropping the pin to avoid pinning a write scope hands over more authority than pinning one would.

| Xero says | Silent fix |
|---|---|
| `invalid_client` | A read-only placeholder was captured instead of the real value. Re-run steps 9 and 10 once. |
| `invalid_scope` on an app created before 29 Apr 2026 | The block already retried with `LEGACY_READ_ONLY_SCOPES` and pins that. **Never retry with, or pin, a write-capable scope string.** If the legacy read-only set was also rejected, `ACCEPTED_SCOPES` stays empty: write no config, and ask the user to create a new Custom Connection. |
| `invalid_scope` on a current app | A granular read scope is unticked. Tick it, Save, **then re-activate the connection (step 8): saving a scope edit deactivates it** — and retry the granular grant. |
| `Connection deactivated` | Either activation never completed (return to step 8 and check the payment flow) or a scope edit just deactivated it (re-activate, step 8). |
| No tenant linked | The organisation was never selected. Return to step 5. |
| Network timeout | Retry once. If it persists: *"Xero's API is slow, give me a minute."* |

## Phase 1: install the server globally

Do this before the config is written. It is the step that makes the first launch instant instead of a silent timeout.

```bash
PINNED_VERSION="0.0.17"

npm i -g "@xeroapi/xero-mcp-server@${PINNED_VERSION}" --silent

NODE_BIN="$(command -v node)"
SERVER_ENTRY="$(npm root -g)/@xeroapi/xero-mcp-server/dist/index.js"

[ -n "$NODE_BIN" ] || { echo "FAIL: node is not on PATH"; exit 1; }
[ "$("$NODE_BIN" -p 'process.versions.node.split(".")[0]')" -ge 18 ] \
  || { echo "FAIL: node 18+ required, found $("$NODE_BIN" -v)"; exit 1; }
[ -f "$SERVER_ENTRY" ] || { echo "FAIL: global install missing at $SERVER_ENTRY"; exit 1; }

echo "OK: $("$NODE_BIN" -v) will run $SERVER_ENTRY"
```

Tell the user plainly while it downloads: *"Installing Xero's connector — this is the slow bit, about a minute the first time."* Only a `FAIL:` line stops the flow; on a slow link, wait rather than retry.

Keep the pin current: it is checked against the installed package by `tests/test_launch_config.py`, so bumping the version and re-running the suite is the whole upgrade.

## Phase 1: write the config

Merge, never overwrite. Back up with a timestamp first, quarantine a corrupt file rather than losing it. `NODE_BIN` and `SERVER_ENTRY` come from the install step above and must both be non-empty here.

```bash
CLAUDE_CONFIG="$HOME/.claude.json"

# The entry this run writes. First organisation: xero. A second organisation
# sets ENTRY="xero-<orgslug>" before running this — see Multi-org below. Every
# assertion downstream reads back THIS name, so a slugged install is checked
# rather than skipped.
ENTRY="${ENTRY:-xero}"

cp "$CLAUDE_CONFIG" "${CLAUDE_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"

if ! jq empty "$CLAUDE_CONFIG" 2>/dev/null; then
  QUARANTINE="${CLAUDE_CONFIG}.corrupt.$(date +%Y%m%d-%H%M%S)"
  mv "$CLAUDE_CONFIG" "$QUARANTINE"
  echo '{"mcpServers": {}}' > "$CLAUDE_CONFIG"
  echo "WARNING: ~/.claude.json was not valid JSON and could not be merged into."
  echo "WARNING: it is saved at $QUARANTINE and a fresh minimal config now stands"
  echo "WARNING: in its place. EVERY other MCP server configured on this machine is"
  echo "WARNING: gone from the live config until that file is repaired by hand."
fi

[ -f "$SERVER_ENTRY" ] || { echo "FAIL: refusing to write a config that points nowhere"; exit 1; }

jq --arg name "$ENTRY" \
   --arg cid "$CLIENT_ID" --arg sec "$CLIENT_SECRET" \
   --arg node "$NODE_BIN" --arg entry "$SERVER_ENTRY" \
   --arg scopes "$READ_ONLY_SCOPES" '
  .mcpServers = (.mcpServers // {}) |
  .mcpServers[$name] = {
    "command": $node,
    "args": [$entry],
    "env": {
      "XERO_CLIENT_ID": $cid,
      "XERO_CLIENT_SECRET": $sec,
      "XERO_SCOPES": $scopes
    }
  }
' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp" && mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"

# Verify the setting that ROUTES, on the entry that was actually written.
# Two traps, both of which make the dangerous case report clean:
#   `grep -qv` exits 1 on BSD grep (every Mac) even when a non-matching line exists,
#   and zsh does not word-split an unquoted parameter — so split with `tr`, not the shell.
PINNED=$(jq -r --arg name "$ENTRY" '.mcpServers[$name].env.XERO_SCOPES // empty' "$CLAUDE_CONFIG")
OFFENDERS=$(printf '%s' "$PINNED" | tr ' ' '\n' | grep -v '\.read$')
[ -n "$PINNED" ] || { echo "FAIL: no scopes pinned on mcpServers.$ENTRY"; exit 1; }
[ -z "$OFFENDERS" ] || { echo "FAIL: a write-capable scope is pinned on mcpServers.$ENTRY: $(echo $OFFENDERS)"; exit 1; }
echo "OK: read-only scopes pinned on mcpServers.$ENTRY"
```

**If the config was quarantined, say so before anything else.** Losing every other MCP server out of the live config is the largest thing this skill can do to a machine, and it must never be discovered later: *"Your Claude settings file was corrupted — not by anything we did, it was already unreadable. I've saved the old one and started a clean file, so Xero works, but any other connectors you had set up are not in the new file. The old one is kept at [path] and nothing in it was deleted."*

**`XERO_SCOPES` is mandatory here, not optional.** Left unset, **the server's own defaults are write-capable**: it requests `XERO_DEFAULT_AUTH_SCOPES_V1` first, which leads with `accounting.transactions` — full write authority over bank transactions, invoices and payments — and falls back to a V2 set that includes `accounting.invoices`, `accounting.payments`, `accounting.banktransactions` and `accounting.manualjournals`. Pinning the read-only string is what makes the install read-only, and it is a belt-and-braces second lock: even if a write scope were ticked in the portal by mistake, the server never asks for it.

**Never write `"command": "npx"`.** The npx form only exists as a last resort when a global install is genuinely impossible (a locked-down machine with no write access to the global `node_modules`). If it is ever used, pin the version — `["-y", "@xeroapi/xero-mcp-server@0.0.17"]` — run the package once by hand first to warm the cache, and expect the first launch after a cache clear to fail silently.

**Multi-org.** A second run for a second organisation sets `ENTRY="xero-<orgslug>"` before the block above, reusing the same `$node` and `$entry`. It writes `mcpServers."xero-<orgslug>"` and its tools appear as `mcp__xero-<orgslug>__*`. Setting `ENTRY` is the whole change: the scope readback and the deny-rule verification both key off it, so the second organisation is checked exactly as hard as the first. Never write a slugged entry by hand-editing the jq filter — that was how a second org used to install with neither lock verified.

**A legacy app.** The block above pins `$READ_ONLY_SCOPES`. On a legacy app, pin `$ACCEPTED_SCOPES` from the smoke test instead — it holds whichever read-only set Xero took. Both are all-`.read`, so the assertion passes unchanged and there is never a reason to edit it.

If `ACCEPTED_SCOPES` is empty, **write no config at all.** No entry, no credentials, nothing. An app that accepts neither read-only set does not get connected to a set of real books by this skill, and the way out is a fresh Custom Connection, not a broader pin.

## Phase 1: restart and verify

The MCP server only loads at start-up, so a window refresh will not do it:

> "All the setup is done on my end. **Fully quit Claude Code and reopen it**. Mac: Cmd+Q, then open again. Windows: close the window AND right-click the tray icon → Quit, then open again. Tell me when you're back."

Then call the real tool. Never report success before this returns:

```
mcp__xero__list-organisation-details
```

| Outcome | Action |
|---|---|
| Returns org name + details | Success. Name the org in the message and hand off. |
| `mcp__xero__*` tools not discoverable, and `.mcpServers.xero.command` is `npx` | The launch is resolving the package from the registry on a cold npm cache and timing out before it answers, silently. **Never diagnose this as an incomplete quit** — no number of restarts fixes it. Run the global install, rewrite the entry to the absolute-node shape, then quit and reopen. |
| `mcp__xero__*` tools not discoverable, and `.mcpServers.xero.command` is an absolute node path | Now it really is an incomplete quit — or the global install moved. Check `[ -f "$SERVER_ENTRY" ]` first, then repeat the quit instruction, wait, retry. |
| `invalid_client` / 401 | Trailing whitespace in the saved secret. Strip, rewrite config, retry. |
| `403 insufficient_scope` | Reopen the app's scopes page, tick the scope named in the error, Save — **saving deactivates the connection, so re-activate it (step 8) before retrying**. No Claude restart needed once tokens issue again. |

## Phase 1: hand-off

> "Done. You're connected to **[OrgName]**. Try one of these:
>
> 1. *'Show me my unpaid invoices.'*
> 2. *'Pull my P&L for this year.'*
> 3. *'Who owes me money, sorted by how overdue.'*
>
> 51 Xero tools are available. Ask me anything and I'll use them."

## Setup checklist

Do not say "done" before every box is ticked.

- [ ] Existing config checked (or skipped straight to verify)
- [ ] Country confirmed AU/NZ/UK/US, cost accepted, org name captured
- [ ] Browser open on developer.xero.com, sign-in confirmed from the snapshot
- [ ] App created as **Custom connection**, not Web app
- [ ] Correct organisation selected
- [ ] All 10 granular accounting scopes ticked, every one ending `.read` (legacy 4-scope set only for pre-Apr-2026 apps)
- [ ] No write-capable scope ticked: not `accounting.invoices`, `accounting.payments`, `accounting.banktransactions` or `accounting.manualjournals`
- [ ] No `payroll.` scope ticked at all
- [ ] Save confirmed on the page
- [ ] Activation completed, subscription active
- [ ] Client ID captured and format-validated
- [ ] Client Secret captured and format-validated
- [ ] Smoke test returned a valid `access_token`
- [ ] `/connections` returned a non-empty array (tenant linked)
- [ ] `~/.claude.json` backed up and merged, not overwritten
- [ ] `XERO_SCOPES` in the written entry read back, every scope ending `.read`
- [ ] User confirmed a full quit and reopen
- [ ] `list-organisation-details` returned the correct org
- [ ] Three starter prompts matched to their business

## Phase 2: operating rules

**Read-only is the posture, not just the scope.** The install grants read scopes only, so the `create-*` and `update-*` tools in the catalog return `403 insufficient_scope` — that is the design working, not a fault. Never diagnose one of those 403s as a missing scope to be ticked; say what was attempted and that this connection reads only.

**Never guess codes.** Call `list-accounts` before quoting an account. Call `list-tax-rates` for GST-inclusive orgs. Use the org's own currency from the API response, two decimal places.

**Rate limit.** Xero allows roughly 60 calls per minute per tenant.

Full tool list: [references/tool-catalog.md](references/tool-catalog.md).

## Write access — this connector does not grant it

**This connector reaches exactly one organisation: the reader's own. That is real books, and real books get no write authority from this skill.** There is no upgrade procedure here, no explicit-yes path, and no "they asked for it in words" exception. The 51 tools include 19 accounting mutators and 6 payroll mutators — among them `create-bank-transaction`, `create-payment` and `delete-timesheet`, the server's only delete. None of them belong on somebody's live accounts.

This is the same rule the rest of the stack already enforces in code. `xero-api-core`'s `TENANT_PROFILES` gives `selr`, `heka` **and `local`** an empty `write_scopes_allowed` map, so `normalise_scopes` refuses a write scope for any of them before a token is ever minted. `local` is the reader's own organisation. This page used to carry a write-upgrade procedure that excluded only `selr` and `heka` — i.e. it excluded the operator's books and left the reader's open, which is exactly backwards.

Asked to create, edit, approve or delete something in Xero, do the read half and say:

> **"I can read your Xero, not change it. That's deliberate — this connection is set up so I can't create invoices, move money between accounts, or touch timesheets in your real books. To make a change, do it in Xero directly; I'll pull the numbers you need first."**

Never route around it: not by re-scoping the connection, not by building a second app with write scopes, not by editing `XERO_SCOPES`, not by reaching for a different Xero tool. **Writes belong on the Xero Demo Company** (`demo` in `TENANT_PROFILES`) — a free, disposable sandbox that resets every 28 days and holds no real books. If someone genuinely needs a write lane exercised, that is where it runs.

The live `selr` and `heka` connections on the operator's Mac sit under the same freeze, from 2026-07-18, and their scopes are not to be touched either.

## Two structural locks, both mandatory

"I won't run anything that changes your books" is a promise about behaviour, and a promise is not a lock. Two locks, and neither depends on anything deciding to behave:

**Lock 1 — the scope pin.** `XERO_SCOPES` in the MCP entry pins the read-only string, so the server never even asks for write authority. Verified by the `grep -v '\.read$'` assertion in *write the config* above.

**Lock 2 — the deny rules.** The harness refuses the mutator tools outright, whatever any model decides to call. This is the lock that still holds on a **legacy app**, where Xero has no read-only scope form and lock 1 genuinely cannot help. Write it during install, for every install:

```bash
SETTINGS="$HOME/.claude/settings.json"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "${SETTINGS}.backup.$(date +%Y%m%d-%H%M%S)"

# Every mutator the server registers, by prefix. Covers the slugged multi-org
# form (mcp__xero-<orgslug>__*) as well as the plain one.
jq '
  .permissions = (.permissions // {}) |
  .permissions.deny = ((.permissions.deny // []) + [
    "mcp__xero__create-*", "mcp__xero__update-*", "mcp__xero__delete-*",
    "mcp__xero__add-*", "mcp__xero__approve-*", "mcp__xero__revert-*",
    "mcp__xero-*__create-*", "mcp__xero-*__update-*", "mcp__xero-*__delete-*",
    "mcp__xero-*__add-*", "mcp__xero-*__approve-*", "mcp__xero-*__revert-*"
  ] | unique)
' "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"

# Verify the rule that BLOCKS, not the file that was written — on BOTH tool-name
# forms. Checking only `mcp__xero__*` passes a machine whose only Xero entry is a
# slugged multi-org one, where every mutator is reachable as `mcp__xero-<slug>__*`.
for verb in create update delete add approve revert; do
  for prefix in "mcp__xero__" "mcp__xero-*__"; do
    jq -e --arg r "${prefix}${verb}-*" '.permissions.deny | index($r)' "$SETTINGS" >/dev/null \
      || { echo "FAIL: ${prefix}${verb}-* is not denied"; exit 1; }
  done
done
echo "OK: all 25 Xero mutators denied at the harness, plain and slugged"
```

A legacy app therefore installs with lock 1 unavailable and lock 2 doing the whole job — which is a real lock, not a posture. Say so plainly: *"Your connection uses Xero's older permission model, which has no read-only setting. I've blocked every change-making tool on my side instead, so I can read your books and can't alter them."*

## Can and cannot

Reads, out of the box: invoices, contacts, quotes, credit notes, items, bank transactions, payments, manual journals, tracking categories, the chart of accounts and tax rates. Full reports: P&L, balance sheet, trial balance, aged receivables and payables.

Writes are off by default and available only through the gated section above.

Cannot:

- Delete records (Xero UI only)
- Email invoices (the user sends from Xero after approving)
- Reconcile bank transactions (UI only)
- File BAS or VAT (not exposed)
- Upload attachments (scope exists, the MCP server does not expose upload)
- Reach Projects, Fixed Assets, Budgets, or Expenses (separate Xero products)
- Connect multiple Xero orgs through one Custom Connection (1:1 by design)

## Service-specific failures

| Symptom | Diagnosis | Fix |
|---|---|---|
| "Verify your email" banner on developer.xero.com | Unverified Xero developer account | User verifies from their inbox, then refresh and wait for the banner to clear |
| App creation returns 500 | Xero backend flake | Retry once, then check Xero's status page |
| Organisation dropdown empty | That Xero login has no organisations | *"Your Xero account doesn't show any organisations I can connect to. Check you're signed in with the right account."* |
| Client ID extraction returns null | Xero changed selectors | Three strategies: `data-testid`, `aria-label`, label-text walk. Re-snapshot between attempts. |
| Secret modal closes before capture | Race condition | Wait for the modal before clicking, raise the timeout |
| `jq` merge fails | Corrupt `~/.claude.json` | Quarantine the file, write a fresh minimal one carrying the Xero entry |
| MCP server will not start after restart | Node < 18, or npm registry blocked | Upgrade Node. Test with `npm ping`. Then re-run the global install step and confirm `[ -f "$SERVER_ENTRY" ]`. |
| `npm i -g` fails: `EACCES` / no write access to the global `node_modules` | Locked-down machine | Point npm at a user-writable prefix (`npm config set prefix "$HOME/.npm-global"`), re-run the install, and re-derive `SERVER_ENTRY` from `npm root -g`. Do not fall back to `npx` to dodge this. |
| First launch after a cleared npm cache never registers the tools | The config is on the `npx` fallback shape, not the global install | Convert it to the absolute-node shape. A cold cache is the normal state of a machine that has never run this before. |
| Every call returns "organisation not found" | The org was unlinked in the Xero UI | Reopen the app page, re-select the org, save |

## Security notes

- Client ID and Secret live in `~/.claude.json` on the user's machine, in plain text, unencrypted. Never committed to a repository.
- **The Client Secret passes through the model on the way there, and that is unavoidable in this design.** Step 10 has Claude read the secret off the Xero page and step 11 writes it into the config, so the value is part of the conversation exactly like any other tool output — it goes wherever the rest of this conversation goes, and it may sit in transcript or session history. Do not claim the secret never leaves the machine. It is not a password to the user's Xero login and it grants only the read scopes pinned above, but it is a live credential handled in the open. Say this before generating the secret, not after. Anyone who does not want a credential going through a conversation should stop here — the alternative is deleting the app in the developer portal, which revokes the secret outright.
- Access tokens last 30 minutes and are refreshed by the MCP server through the `client_credentials` grant. The user never re-approves.
- Revocation: delete the app at developer.xero.com. The monthly charge stops at the next billing cycle.
- The API call itself is the user's machine to Xero, and it does not pass through Selr AI. The data Xero returns is a different question: it is handed to Claude as tool output, which makes it part of the conversation and sends it to Anthropic under Anthropic's terms, exactly as pasting a bank statement into a chat would. The connection is local. The financial data you read through it is not private to your machine. Decide whether that is acceptable for these books before connecting them.


## Pairs with

- `quickbooks-connector`: sibling accounting connector, same wrap-existing-tooling pattern on a different platform
- `myob-connector`: the other major AU accounting connector; route users who pay for MYOB rather than Xero
- `hubspot-connector`: sibling admin-portal connector with the same create-app-then-read-credential shape
- `monday-connector`: sibling admin-portal connector, same create-app-and-capture-token flow
- `slack-connector`: sibling multi-step app-create, scope-tick, credential-capture flow
- `superpowers:systematic-debugging`: for Custom Connection or Xero API errors with no documented recovery

## Reference

- Official MCP server: [github.com/XeroAPI/xero-mcp-server](https://github.com/XeroAPI/xero-mcp-server)
- Xero developer portal: [developer.xero.com/app/manage](https://developer.xero.com/app/manage)
- Custom Connections guide: [developer.xero.com/documentation/guides/oauth2/custom-connections](https://developer.xero.com/documentation/guides/oauth2/custom-connections)
- Xero API reference: [developer.xero.com/documentation/api](https://developer.xero.com/documentation/api)
- [references/tool-catalog.md](references/tool-catalog.md): the 51 MCP tools, grouped read / write / payroll
- [references/playwright-fallback.md](references/playwright-fallback.md): verbatim Playwright recipe and DOM extractors for the portal walkthrough

If Xero changes its UI and an extraction breaks, re-derive the selectors from the live page and update this skill. It self-heals.

Router key `sk-1vsbgtl` — resolved by the skills index on load.
