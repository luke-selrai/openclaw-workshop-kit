# PandaDoc Connector - Install Walkthrough

> **Status: fully captured, 2026-06-05 against rodolfo@selrai.com.au's PandaDoc account.** Phase 0 + Phase 1 (full OAuth flow, including the `mcp__pandadoc__authenticate` → callback → in-session tool reconciliation path) captured live, AND **Phase 2 tool contracts verified live** by enumerating the real `mcp__pandadoc__*` surface and inspecting all 22 tool schemas + running read smokes. The first capture (initial release) was partial - the deferred-tool pair hadn't reconciled yet; a follow-up smoke from a fresh chat session completed it. **Two capture rounds, 7 MAJOR + 4 MINOR + 2 NIT drifts total** were captured and folded into the SKILL - see *Drifts captured 2026-06-05* at the bottom. PandaDoc OAuth authorization-server metadata is captured live (`mcp.pandadoc.com/.well-known/oauth-authorization-server`); see `scripts/verify-well-known.sh` for the re-runnable check.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL - PandaDoc MCP is OAuth-only with no API-key fallback through MCP (PandaDoc's REST API supports API keys, but the MCP server is OAuth-only). The participant's real PandaDoc account (Essentials, Business, or Enterprise) is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed and reachable.
- `claude` CLI on PATH; `claude --version` returns cleanly.
- Node 18+ on PATH.
- Internet access to `mcp.pandadoc.com`, `app.pandadoc.com`, and Claude Code's localhost callback.
- Participant has a PandaDoc account. **Caveat:** Enterprise / SSO workspaces may have third-party integrations blocked by the workspace administrator. Phase 1 Step 5 detects this and surfaces a clean exit; there is no API-key bypass through MCP.

Projected total: ~25 seconds warm; ~60-90 seconds cold (first sign-in + 2FA if enabled).

---

## Step 0 - Resume check

```bash
$ node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const pd = (j.mcpServers || {}).pandadoc;
console.log(pd ? 'REGISTERED' : 'NOT_CONFIGURED');
"
NOT_CONFIGURED

$ claude mcp list 2>/dev/null | grep -iE 'pandadoc.*Connected'
(no output - claude.ai-layer also not registered)
```

→ neither signal matches - run Phase 1 from Step 1.

---

## Step 1 - Welcome

> "I'll connect your PandaDoc now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

---

## Step 2 - Register the hosted PandaDoc MCP server

```bash
$ claude mcp add pandadoc https://mcp.pandadoc.com/v1/mcp --transport http --scope user
Added HTTP MCP server pandadoc with URL: https://mcp.pandadoc.com/v1/mcp to user config
File modified: /home/<user>/.claude.json
```

Reference shape of the entry written:

```json
{
  "mcpServers": {
    "pandadoc": {
      "type": "http",
      "url": "https://mcp.pandadoc.com/v1/mcp"
    }
  }
}
```

No token is stored in this file - the MCP runtime owns the token lifecycle after Step 4 completes.

---

## Step 3 - Mint OAuth start URL + open in Playwright

```
{ authorization_url } = mcp__pandadoc__authenticate()
// Captured live 2026-06-05:
// → "https://mcp.pandadoc.com/authorize?response_type=code
//     &client_id=https%3A%2F%2Fclaude.ai%2Foauth%2Fclaude-code-client-metadata
//     &code_challenge=<...>&code_challenge_method=S256
//     &redirect_uri=http%3A%2F%2Flocalhost%3A<port>%2Fcallback
//     &state=<...>&scope=read+read%2Bwrite
//     &resource=https%3A%2F%2Fmcp.pandadoc.com%2Fv1%2Fmcp"
// NOTE: client_id is the client-id-metadata-document URL, NOT a DCR-minted client.

mcp__playwright__browser_navigate({ url: authorization_url })
mcp__playwright__browser_snapshot()
```

**Captured 2026-06-05 - OAuth authorization-server metadata** (from `mcp.pandadoc.com/.well-known/oauth-authorization-server`):

```json
{
  "issuer": "https://mcp.pandadoc.com/",
  "authorization_endpoint": "https://mcp.pandadoc.com/authorize",
  "token_endpoint": "https://mcp.pandadoc.com/token",
  "registration_endpoint": "https://mcp.pandadoc.com/register",
  "scopes_supported": ["read", "read+write"],
  "response_types_supported": ["code"],
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "token_endpoint_auth_methods_supported": ["client_secret_post", "client_secret_basic"],
  "code_challenge_methods_supported": ["S256"],
  "client_id_metadata_document_supported": true
}
```

Two SKILL-relevant facts captured from this metadata (and corrected against the live flow):

1. **Claude Code uses the client-id-metadata-document flow** (`client_id_metadata_document_supported: true`). Live, `authenticate()` returns a `client_id` of `https://claude.ai/oauth/claude-code-client-metadata` - the runtime presents a metadata document rather than minting a DCR client. (The `registration_endpoint` is publicly reachable, but the runtime does **not** use DCR for this server.) The grant is then re-framed through PandaDoc's pre-registered MCP bridge client_id `f88018a252b20dcb8987`, which is why prior-consent users auto-grant.
2. **Scopes are coarse-grained - only `read` and `read+write`**. The live URL requests `scope=read read+write`. The consent screen shows 2 permission levels rather than Canva's ~15 per-resource scopes.

**Tool-availability precondition.** On the first session after `claude mcp add pandadoc ...`, the deferred-tool reconciliation may not have fired yet. If `mcp__pandadoc__authenticate` is missing from the tool surface, ask the participant *once*: *"I've added PandaDoc. Please close and reopen the chat once, then say 'connect to my PandaDoc' and I'll finish."* On resume, Phase 0 re-enters at Step 3.

Projected snapshot post-navigate:

- **Already signed in to PandaDoc**: snapshot lands on PandaDoc's consent UI - "Allow Claude access to your PandaDoc account" with **Allow access** button (per the docs).
- **Not signed in**: snapshot shows PandaDoc's sign-in form. Tell the participant *once*: *"Please sign in to your PandaDoc account in the browser window I just opened - I'll wait."*

---

## Step 4 - Auto-click Allow access + Authorize + auto-detect callback

### 4a - Read scope summary, narrate, click Allow access

Snapshot the consent page. Extract human-readable scope items:

```js
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"], p')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 200);
  return items.slice(0, 12);
}
```

Projected return (informed by the coarse `read+write` scope): a short list of plain-language capability descriptions - *"View your PandaDoc documents, templates, and folders"*, *"Create and update documents on your behalf"*, *"Send documents for signature"*, *"Manage webhooks"*. Far fewer items than Canva's consent screen.

Narrate (3-5 representative items, plain English):

> "PandaDoc is showing the permissions screen - it's asking to view your documents and templates, create and update documents, send for signature, and manage webhooks. Clicking **Allow access** now."

Drive the **two-button** consent flow:

```
mcp__playwright__browser_click({
  target: <ref of button matching role:button, name:/^allow access$/i>,
  element: "Allow access button on the PandaDoc consent screen"
})

mcp__playwright__browser_wait_for({ text: "Authorize" })

mcp__playwright__browser_click({
  target: <ref of button matching role:button, name:/^authorize$/i>,
  element: "Authorize button on the PandaDoc consent screen"
})
```

### 4b - Capture callback URL + submit via `complete_authentication`

```
mcp__playwright__browser_wait_for({ time: 600 })
// Note: Playwright MCP's browser_wait_for hard-caps at 30s. Poll
// window.location.href in browser_evaluate for longer waits.

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
// → "http://localhost:<port>/callback?code=<opaque>&state=<opaque>"

mcp__pandadoc__complete_authentication({ callback_url })
```

**Captured live 2026-06-05 (auto-grant path).** For a user with a prior bridge grant, the navigate in Step 3 lands on `mcp.pandadoc.com/consent?txn_id=<opaque>` and then **auto-redirects to the localhost callback with no buttons rendered** - confirming the Step 4 auto-grant race. In this case the Claude Code runtime detected the callback and reconciled the tool surface **automatically**: the `mcp__pandadoc__complete_authentication` tool was *replaced* by the 22 real `mcp__pandadoc__*` tools, and a direct `complete_authentication` call returned `No such tool available` because reconciliation had already happened. Either way, on success the `mcp__pandadoc__*` tool surface becomes available in the same session - no chat restart needed.

---

## Step 5 - Admin / SSO restriction interstitial

For PandaDoc Enterprise / SSO accounts with restricted third-party integrations, detect:

```js
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /administrator (must |approve|approval)/i,
    /admin (consent|approval) (required|needed)/i,
    /workspace administrator/i,
    /your admin/i,
    /SSO (required|enforced)/i,
    /not authorized to install/i,
  ];
  return markers.some(re => re.test(text));
}
```

If `true`, surface the clean exit and stop. No API-key bypass through MCP.

---

## Step 6 - Smoke verification

```
mcp__pandadoc__documents_list({ count: 5 })
// Captured live 2026-06-05: → {"results":[]} on an empty account (still 200 OK = ready).
// On a populated account: → {"results":[{...document objects...}]}.
// NOTE: no user_intent param - schemas are additionalProperties:false and reject it.
```

Success message (include the live count when non-zero):

> "All done! Your PandaDoc is now connected. You can ask me things like 'create a contract from the Master Services Agreement template', 'show me documents waiting for signatures', 'summarize the signed Acme contract', or 'report on contracts signed this quarter'. Give it a try!"

---

## Phase 2 sample - contract-from-template flow (immediately after install)

```
Participant: List my templates.
Claude:      mcp__pandadoc__templates_list({ count: 50 })
             # → {"results":[ 10 templates incl Master Services Agreement, NDA, ... ]}
Claude:      You have 10 templates. The MSA, NDA, and Statement of Work
             are the most-used. Want me to start from one?

Participant: Create a contract from the MSA template for Acme Corp,
             counterparty john@acme.com.
Claude:      mcp__pandadoc__templates_details_get({ template_id: "TPL-xxx" })
             # → roles: [client], fields: customer_name, total_amount, ...
Claude:      I'm about to create a new "Master Services Agreement - Acme
             Corp" document with customer Acme Corp, counterparty
             john@acme.com. This creates a draft (not yet sent). OK?
Participant: Yes.
Claude:      mcp__pandadoc__documents_create({
               template_uuid: "TPL-xxx",
               name: "Master Services Agreement - Acme Corp",
               recipients: [{ email: "john@acme.com", role: "client",
                              first_name: "John", last_name: "Smith" }],
               fields: { customer_name: { value: "Acme Corp" } }
             })
             # → { id: "DOC-yyy", status: "document.uploaded" → "document.draft", ... }
Claude:      Draft created - "Master Services Agreement - Acme Corp"
             with John (john@acme.com) as the counterparty. Want me to
             send it for signature now?

Participant: Yes, send it.
Claude:      mcp__pandadoc__documents_details_get({ document_id: "DOC-yyy" })
             # → confirms recipient + per-recipient status
Claude:      I'm about to SEND "Master Services Agreement - Acme Corp"
             to John Smith (john@acme.com) for signature. This sends a
             real email and creates a binding signature request. OK?
Participant: Yes.
Claude:      mcp__pandadoc__documents_send({ document_id: "DOC-yyy",
               subject: "Master Services Agreement for signature",
               message: "Hi John, please review and sign." })
             # → { id: "DOC-yyy", status: "document.sent", ... }
Claude:      Sent - John will receive the email shortly. You can ask me
             "what's the status of the Acme contract?" any time.
```

### Find-unsigned flow (there is NO reminder tool)

PandaDoc MCP has **no** "send reminder" endpoint. The honest flow finds and reports
unsigned documents, then directs the user to the PandaDoc UI to actually nudge signers:

```
Participant: Remind anyone who hasn't signed.
Claude:      mcp__pandadoc__documents_list({ status: 1, count: 100 })
             # status 1 = sent (awaiting signature)
             # → {"results":[ 9 sent documents ]}
Claude:      I found **9 contracts still awaiting signature**:
             - Acme MSA (sent 12 days ago)
             - Beta SOW (sent 8 days ago)
             - ... +7 more
             Heads-up: PandaDoc's connector can't send reminder emails
             directly - you can nudge signers from the PandaDoc app
             (open the document → Send reminder). Want me to open the
             list so you can do that, or pull details on any one of these?
```

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (resume check) | 0.2 s |
| Step 1 (welcome) | 0 s |
| Step 2 (`claude mcp add` + reconcile) | 2 s |
| Step 3 (mint URL + open + sign-in detect) | 5 s warm / 45 s cold |
| Step 4 (Allow access + Authorize + callback) | 10 s |
| Step 5 (admin-block probe) | 1 s (when consent succeeds) |
| Step 6 (smoke `documents_list`) | 2 s |
| **Total (warm)** | **~20 s** |
| **Total (cold, no 2FA)** | **~65 s** |

---

## Failure modes anticipated

| Failure | Cause | Fix |
|---|---|---|
| Step 2 `claude mcp add` errors | Older Claude Code build; CLI not on PATH | Fall back to Node merge pattern |
| Step 3 `mcp__pandadoc__authenticate` missing | Deferred-tool reconciliation pending | Close-and-reopen chat; resume at Step 3 |
| Step 4 Allow access button not located | PandaDoc consent UI shifted | One-time prompt to click manually |
| Step 4b callback never arrives | Localhost firewall / remote VM | Clean message + retry |
| Step 5 admin-block detected | Enterprise / SSO admin restriction | Clean exit; admin must allowlist |
| Step 6 401 invalid_token immediately | Clock skew / race | Re-run Step 3 once; do not re-`claude mcp add` |
| Step 6 403 plan_required on specific tool | User's plan doesn't grant that capability | Translate per Error Handling table |
| Phase 2 - destructive op fired without confirm | SKILL bug | Always re-read recipient + document name (via `documents_details_get`) before `documents_send` |
| Phase 2 - tool call rejected with validation error | Passed `user_intent` or other undocumented field | Remove it - schemas are `additionalProperties:false`; pass only documented params |

For Phase 2 failures, see the SKILL's Error Handling section.

---

## Re-vetting hook

To re-validate PandaDoc's OAuth metadata shape without re-running the install, see `../scripts/verify-well-known.sh`. That script re-fetches `mcp.pandadoc.com/.well-known/oauth-authorization-server` and structurally validates the response against the 2026-06-05 captured shape. Run on a schedule to catch shape drift early.

---

## Drifts captured 2026-06-05

Live smoke against rodolfo@selrai.com.au's PandaDoc account ran in **two rounds** (initial release + a follow-up Phase 2 smoke from a fresh chat session) and surfaced **7 MAJOR + 4 MINOR + 2 NIT drifts** total. All were folded into the SKILL.md commits that accompany this walkthrough.

### Round 1 - install / OAuth (initial release)

| # | Severity | Drift | Folded into SKILL |
|---|---|---|---|
| 1 | MAJOR | PandaDoc MCP uses **bridge / proxy OAuth** (same architecture as Canva), NOT direct OAuth at mcp.pandadoc.com. Redirect chain: `mcp.pandadoc.com/authorize` → `mcp.pandadoc.com/consent?txn_id=<opaque>` → `app.pandadoc.com/oauth2/authorize/confirm?client_id=f88018a252b20dcb8987` → `localhost:<port>/callback?code=...&state=...` (4 hops, not 2) | SKILL.md Overview note + Step 3 narration; this walkthrough's Step 3 reflects the full chain |
| 2 | MAJOR | PandaDoc **auto-skips the consent screen** for users with a prior bridge grant - re-installers (including any chat-restart re-install) get NO Allow access / Authorize buttons, just an immediate callback redirect. SKILL's `browser_wait_for({ text: "Allow access" })` would hang | SKILL.md Step 4 now races consent-screen detection vs auto-grant callback URL via parallel polling; first-fires-wins |
| 3 | MAJOR | PandaDoc supports **RFC 7591 Dynamic Client Registration publicly** (no auth required on `mcp.pandadoc.com/register`). Different from Canva, which uses a pre-registered MCP app | SKILL.md Overview captured-note explains the per-user-per-bridge consent model |
| 4 | MAJOR | The bridge MCP client_id is `f88018a252b20dcb8987` (load-bearing - all Claude Code → PandaDoc grants share this). To revoke, user goes to PandaDoc Connected Apps and revokes the entry for this bridge | SKILL.md Step 5 adds revoke-pointer to PandaDoc → Settings → Integrations → Connected Apps |
| 5 | MINOR | OAuth redirect chain has 4 hops, not 2 (projected walkthrough showed 2) | Walkthrough Step 3 + drifts table above enumerate the 4 hops |
| 6 | NIT | `GET https://mcp.pandadoc.com/v1/mcp` returns `405 Method Not Allowed`, `Allow: DELETE, POST`. Not a bug - MCP transport uses POST - but worth noting for a debugger inspecting the endpoint manually | Noted in failure modes |

### Round 2 - Phase 2 tool contracts (follow-up smoke, fresh chat session)

The follow-up smoke ran the **real** `mcp__pandadoc__authenticate()` → Playwright → callback path
(auto-granted via the prior bridge consent), let the runtime reconcile the tool surface in-session,
then enumerated all 22 tools and inspected every schema + ran read smokes (`documents_list`,
`templates_list` → both `200 OK`, `{"results":[]}` on the empty account).

| # | Severity | Drift | Folded into SKILL |
|---|---|---|---|
| 7 | MAJOR | Tool surface is **22 tools across 3 namespaces** (`documents_*` 15, `recipients_*` 4, `templates_*` 3), NOT "~50 operations across 10 categories" | SKILL Overview + Phase 2 intro + full Tool Reference rewritten to the 22 verified tools |
| 8 | MAJOR | **`user_intent` is NOT a parameter** - every schema is `additionalProperties:false`, so passing it (per the Canva precedent the SKILL assumed) is *rejected*. The guidance to "pass user_intent on every call" was actively breaking | Removed from Tool Reference note, Step 6, Behaviour Guidelines; replaced with explicit "never pass it" guidance |
| 9 | MAJOR | **Naming is `namespace_object_verb` snake_case** (`documents_list`, `templates_details_get`), NOT kebab (`list-documents`). Entire Prompt-to-Tool Mapping used non-existent names | Naming-convention section + Prompt-to-Tool Mapping rewritten with real names |
| 10 | MAJOR | **No webhook tools, no reminder tool, no signed-PDF download** exist - three documented categories/ops have zero backing tools | Moved to a "What the server does NOT expose" section + Scope Limitations; reminder flow rewritten to find-and-report |
| 11 | MINOR | mark-paid / decline / expire / complete are **one** tool `documents_status_change` (status codes 2/10/11/12), not 4 separate ops | Tool Reference + Prompt-to-Tool Mapping collapsed to the one tool |
| 12 | MINOR | `recipients_reassign` reassigns a **signer** (contact), not the document sender - SKILL conflated them | Tool Reference + Scope Limitations clarify; sender change is `documents_send.sender` |
| 13 | MINOR | Document status is an **integer code 0-13** with a specific mapping the SKILL never documented (and code 11 is `voided` in `documents_list` but `expired` in `documents_search`) | Added a Document-status-codes table to Phase 2 |
| 14 | NIT | OAuth `client_id` is the **client-id-metadata-document URL** `https://claude.ai/oauth/claude-code-client-metadata`, not a DCR-minted per-install client_id as Round 1 implied | Corrected the Overview captured-note + Step 3 (here and in SKILL) |

**Round 1 methodology note (superseded).** The Round 1 capture could not complete the OAuth flow in-session
(deferred tools hadn't reconciled) and reconstructed the bridge architecture by hand-driving Playwright through
a DCR-minted client. Round 2 corrected the most load-bearing Round-1 inference: the runtime uses the
**client-id-metadata-document** flow, not DCR (Drift 14). Round 2 also confirmed the auto-grant (Drift 2) live -
the consent page auto-redirected straight to the localhost callback with no buttons rendered.

**Populated response shapes captured (follow-up, same session).** A recipient-less throwaway draft was created
via `documents_create_from_markdown` (so no email ever left), read through the read tools, then archived
(`{"archived":true, "forever":false}`) - leaving zero residue. Captured live:

- `documents_create_from_markdown` → `{id, name, status:"document.uploaded", date_created, date_modified, version, uuid, links:[{rel,href,type}], info_message, document_url}` - **async**, poll `documents_status_get` until `document.draft`.
- `documents_list` (populated) → `{"results":[{id, name, status, date_created, date_modified, date_completed, expiration_date, version, document_url}]}`.
- `documents_search` → `{"total":N, "has_next_page":bool, "scope":"full", "results":[...]}` - richer envelope than `documents_list` (NIT not previously documented).
- `documents_details_get` → rich: `ref_number`, `folder_uuid`, `created_by{...}`, `tokens:[{name,value}]`, `fields:[]`, `pricing:{tables,quotes,total}`, `recipients:[]`, `grand_total:{amount,currency:"PHP"}`, `metadata`, `approval_execution`; `uuid` can be `null` for a markdown-created draft (use `id`).
- `documents_content_get` / `documents_summary_get` → `{"retry_after":N}` while rendering.
- `documents_status_get` → `{"id":..., "status":"document.draft"}`; `documents_archive` → `{"archived":true, "document_id":..., "forever":false}`.

**Still not verified:** plan-gating boundaries (no `403 plan_required` observed), fresh-*new*-user consent-screen
button text (auto-granted again via the prior bridge consent), rendered `documents_content_get` success body (the
draft was still rendering at archive time - only the `{retry_after}` envelope was captured). Destructive tools that
need recipients or a sent/live document - `documents_send`, `documents_create` (from template), `documents_update`,
`documents_fields_assign`, `documents_status_change`, `recipients_*` - had their **schemas** inspected but were **not
invoked** (the test account has no templates and the draft had no recipients).

> **Note on the DCR client used during the Round 1 smoke** - a low-risk transcript leak occurred: `curl POST https://mcp.pandadoc.com/register` echoed the freshly-minted `client_id` + `client_secret` to stdout. Risk is low because the client is fresh, has no user grants, and the secret alone is useless without an authorization_code. Round 2 did not use DCR at all (the runtime uses the metadata-document flow), so no secret was minted in Round 2.
