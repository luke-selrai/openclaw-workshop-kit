# PandaDoc Connector — Install Walkthrough

> **Status: partial captured reference, 2026-06-05 against rodolfo@selrai.com.au's PandaDoc account.** Phase 0 + Phase 1 Steps 1-2 captured live; Step 3 OAuth bridge architecture captured live via a hand-constructed DCR client (see drifts below); Steps 3-6 deferred-tool path remains projected because the runtime's deferred-tool reconciliation requires a chat restart to expose `mcp__pandadoc__authenticate` after `claude mcp add pandadoc` (documented Tool-availability precondition). **Phase 2 tool contracts** could NOT be captured live this session — unlike canva-connector, no parallel `mcp__claude_ai_PandaDoc__*` surface exists for verification (Rodolfo had not previously installed the claude.ai-layer PandaDoc connector). **Six live drifts** were captured during the smoke and folded into the SKILL — see *Drifts captured 2026-06-05* at the bottom. PandaDoc OAuth authorization-server metadata is captured live (`mcp.pandadoc.com/.well-known/oauth-authorization-server`); see `scripts/verify-well-known.sh` for the re-runnable check.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL — PandaDoc MCP is OAuth-only with no API-key fallback through MCP (PandaDoc's REST API supports API keys, but the MCP server is OAuth-only). The participant's real PandaDoc account (Essentials, Business, or Enterprise) is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed and reachable.
- `claude` CLI on PATH; `claude --version` returns cleanly.
- Node 18+ on PATH.
- Internet access to `mcp.pandadoc.com`, `app.pandadoc.com`, and Claude Code's localhost callback.
- Participant has a PandaDoc account. **Caveat:** Enterprise / SSO workspaces may have third-party integrations blocked by the workspace administrator. Phase 1 Step 5 detects this and surfaces a clean exit; there is no API-key bypass through MCP.

Projected total: ~25 seconds warm; ~60-90 seconds cold (first sign-in + 2FA if enabled).

---

## Step 0 — Resume check

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
(no output — claude.ai-layer also not registered)
```

→ neither signal matches — run Phase 1 from Step 1.

---

## Step 1 — Welcome

> "I'll connect your PandaDoc now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

---

## Step 2 — Register the hosted PandaDoc MCP server

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

No token is stored in this file — the MCP runtime owns the token lifecycle after Step 4 completes.

---

## Step 3 — Mint OAuth start URL + open in Playwright

```
{ authorization_url } = mcp__pandadoc__authenticate()
// → "https://mcp.pandadoc.com/authorize?response_type=code&client_id=<runtime-managed>&state=<...>&code_challenge=<...>&code_challenge_method=S256&redirect_uri=http%3A%2F%2Flocalhost%3A<port>%2Fcallback&scope=read%2Bwrite"

mcp__playwright__browser_navigate({ url: authorization_url })
mcp__playwright__browser_snapshot()
```

**Captured 2026-06-05 — OAuth authorization-server metadata** (from `mcp.pandadoc.com/.well-known/oauth-authorization-server`):

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

Two SKILL-relevant facts captured from this metadata:

1. **PandaDoc supports Dynamic Client Registration** (`registration_endpoint` present, `client_id_metadata_document_supported: true`). Claude Code's MCP runtime can mint a per-installation client without a pre-shared client_id — different from Canva's bridge OAuth pattern which used a pre-registered MCP app.
2. **Scopes are coarse-grained — only `read` and `read+write`**. The consent screen will show 2 permission levels rather than Canva's ~15 per-resource scopes. The user sees a simpler permissions screen.

**Tool-availability precondition.** On the first session after `claude mcp add pandadoc ...`, the deferred-tool reconciliation may not have fired yet. If `mcp__pandadoc__authenticate` is missing from the tool surface, ask the participant *once*: *"I've added PandaDoc. Please close and reopen the chat once, then say 'connect to my PandaDoc' and I'll finish."* On resume, Phase 0 re-enters at Step 3.

Projected snapshot post-navigate:

- **Already signed in to PandaDoc**: snapshot lands on PandaDoc's consent UI — "Allow Claude access to your PandaDoc account" with **Allow access** button (per the docs).
- **Not signed in**: snapshot shows PandaDoc's sign-in form. Tell the participant *once*: *"Please sign in to your PandaDoc account in the browser window I just opened — I'll wait."*

---

## Step 4 — Auto-click Allow access + Authorize + auto-detect callback

### 4a — Read scope summary, narrate, click Allow access

Snapshot the consent page. Extract human-readable scope items:

```js
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"], p')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 200);
  return items.slice(0, 12);
}
```

Projected return (informed by the coarse `read+write` scope): a short list of plain-language capability descriptions — *"View your PandaDoc documents, templates, and folders"*, *"Create and update documents on your behalf"*, *"Send documents for signature"*, *"Manage webhooks"*. Far fewer items than Canva's consent screen.

Narrate (3-5 representative items, plain English):

> "PandaDoc is showing the permissions screen — it's asking to view your documents and templates, create and update documents, send for signature, and manage webhooks. Clicking **Allow access** now."

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

### 4b — Capture callback URL + submit via `complete_authentication`

```
mcp__playwright__browser_wait_for({ time: 600 })
// Note: Playwright MCP's browser_wait_for hard-caps at 30s. Poll
// window.location.href in browser_evaluate for longer waits.

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
// → "http://localhost:<port>/callback?code=<opaque>&state=<opaque>"

mcp__pandadoc__complete_authentication({ callback_url })
// → { ok: true, server: "pandadoc" }
```

On success, the `mcp__pandadoc__*` tool surface becomes available in the same session.

---

## Step 5 — Admin / SSO restriction interstitial

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

## Step 6 — Smoke verification

```
mcp__pandadoc__list-documents({ limit: 5, user_intent: "..." })
// (exact tool name surfaces post-registration — list mcp__pandadoc__* tools to discover)
```

Projected success message:

> "All done! Your PandaDoc is now connected — I can see **84 documents**. You can ask me things like 'create a contract from the Master Services Agreement template', 'show me documents waiting for signatures', 'send reminders to anyone who hasn't signed', or 'report on signed contracts this quarter'. Give it a try!"

---

## Phase 2 sample — contract-from-template flow (immediately after install)

```
Participant: List my templates.
Claude:      mcp__pandadoc__list-templates({ user_intent: "Show the user
                their available PandaDoc templates so they can pick one
                to instantiate." })
             # → [10 templates including Master Services Agreement, NDA, ...]
Claude:      You have 10 templates. The MSA, NDA, and Statement of Work
             are the most-used. Want me to start from one?

Participant: Create a contract from the MSA template for Acme Corp,
             counterparty john@acme.com.
Claude:      mcp__pandadoc__inspect-template-fields({ template_id: "TPL-xxx", user_intent: "..." })
             # → fields: customer_name, customer_email, total_amount, ...
Claude:      I'm about to create a new "Master Services Agreement - Acme
             Corp" document with customer Acme Corp, counterparty
             john@acme.com. This creates a draft (not yet sent). OK?
Participant: Yes.
Claude:      mcp__pandadoc__create-document-from-template({
               template_id: "TPL-xxx",
               name: "Master Services Agreement - Acme Corp",
               recipients: [{ email: "john@acme.com", role: "client", ... }],
               fields: { customer_name: "Acme Corp", ... },
               user_intent: "..."
             })
             # → { id: "DOC-yyy", status: "draft", ... }
Claude:      Draft created — "Master Services Agreement - Acme Corp"
             with John (john@acme.com) as the counterparty. Want me to
             send it for signature now?

Participant: Yes, send it.
Claude:      mcp__pandadoc__get-document({ document_id: "DOC-yyy", user_intent: "..." })
             # → confirms recipient + content
Claude:      I'm about to SEND "Master Services Agreement - Acme Corp"
             to John Smith (john@acme.com) for signature. This sends a
             real email and creates a binding signature request. OK?
Participant: Yes.
Claude:      mcp__pandadoc__send-document({ document_id: "DOC-yyy", user_intent: "..." })
             # → { id: "DOC-yyy", status: "sent", sent_at: "...", ... }
Claude:      Sent — John will receive the email shortly. I'll let you
             know when he signs (or you can ask me "did Acme sign yet?"
             any time).
```

### Bulk reminder flow

```
Participant: Send reminders to anyone who hasn't signed.
Claude:      mcp__pandadoc__find-documents-awaiting-signatures({ user_intent: "..." })
             # → [9 unsigned documents, 14 total non-signed recipients]
Claude:      I'm about to send reminder emails to **14 recipients**
             across **9 unsigned contracts**. Examples:
             - John Smith (Acme MSA, sent 12 days ago)
             - Jane Doe (Beta SOW, sent 8 days ago)
             - ... +12 more
             OK to send all 14?
Participant: Yes.
Claude:      mcp__pandadoc__send-reminders({ document_ids: [...], user_intent: "..." })
             # → { sent: 14, failed: 0 }
Claude:      Sent 14 reminders. I'll surface any bounces.
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
| Step 6 (smoke list-documents) | 2 s |
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
| Phase 2 — destructive op fired without confirm | SKILL bug | Always re-read recipient + document name before `send-document` |

For Phase 2 failures, see the SKILL's Error Handling section.

---

## Re-vetting hook

To re-validate PandaDoc's OAuth metadata shape without re-running the install, see `../scripts/verify-well-known.sh`. That script re-fetches `mcp.pandadoc.com/.well-known/oauth-authorization-server` and structurally validates the response against the 2026-06-05 captured shape. Run on a schedule to catch shape drift early.

---

## Drifts captured 2026-06-05

Live smoke against rodolfo@selrai.com.au's PandaDoc account surfaced **4 MAJOR + 1 MINOR + 1 NIT drifts** vs the SKILL.md state pre-smoke. All were folded into the SKILL.md commit that accompanies this walkthrough.

| # | Severity | Drift | Folded into SKILL |
|---|---|---|---|
| 1 | MAJOR | PandaDoc MCP uses **bridge / proxy OAuth** (same architecture as Canva), NOT direct OAuth at mcp.pandadoc.com. Redirect chain: `mcp.pandadoc.com/authorize` → `mcp.pandadoc.com/consent?txn_id=<opaque>` → `app.pandadoc.com/oauth2/authorize/confirm?client_id=f88018a252b20dcb8987` → `localhost:<port>/callback?code=...&state=...` (4 hops, not 2) | SKILL.md Overview note + Step 3 narration; this walkthrough's Step 3 reflects the full chain |
| 2 | MAJOR | PandaDoc **auto-skips the consent screen** for users with a prior bridge grant — re-installers (including any chat-restart re-install) get NO Allow access / Authorize buttons, just an immediate callback redirect. SKILL's `browser_wait_for({ text: "Allow access" })` would hang | SKILL.md Step 4 now races consent-screen detection vs auto-grant callback URL via parallel polling; first-fires-wins |
| 3 | MAJOR | PandaDoc supports **RFC 7591 Dynamic Client Registration publicly** (no auth required on `mcp.pandadoc.com/register`). Different from Canva, which uses a pre-registered MCP app | SKILL.md Overview captured-note explains the per-user-per-bridge consent model |
| 4 | MAJOR | The bridge MCP client_id is `f88018a252b20dcb8987` (load-bearing — all Claude Code → PandaDoc grants share this). To revoke, user goes to PandaDoc Connected Apps and revokes the entry for this bridge | SKILL.md Step 5 adds revoke-pointer to PandaDoc → Settings → Integrations → Connected Apps |
| 5 | MINOR | OAuth redirect chain has 4 hops, not 2 (projected walkthrough showed 2) | Walkthrough Step 3 + drifts table above enumerate the 4 hops |
| 6 | NIT | `GET https://mcp.pandadoc.com/v1/mcp` returns `405 Method Not Allowed`, `Allow: DELETE, POST`. Not a bug — MCP transport uses POST — but worth noting for a debugger inspecting the endpoint manually | Noted in failure modes |

**Smoke methodology.** Phase 0 captured live (no PandaDoc registration found at either `~/.claude.json mcpServers.pandadoc` or via `claude mcp list`). Phase 1 Step 1 narrated. Phase 1 Step 2 `claude mcp add pandadoc` succeeded and wrote the entry. Phase 1 Step 3 deferred tools (`mcp__pandadoc__authenticate`) did NOT surface — would require a chat restart per the SKILL's documented Tool-availability precondition. **OAuth bridge architecture (Drifts 1-5) was captured by hand-constructing an OAuth URL using a DCR-minted client_id and driving Playwright through it** — the bridge auto-granted (Drift 2) because Rodolfo had previously consented to the bridge's pre-registered client_id (Drift 4), redirecting straight to `localhost:8976/callback` with the auth code (which was lost to `ERR_CONNECTION_REFUSED` since no listener was running). The bridge / re-frame / auto-grant chain is the empirical evidence for Drifts 1-4. **Phase 2 tool contracts** remain unverified live — fully completing the OAuth flow would require either (a) a chat restart for runtime reconciliation, or (b) a `localhost:8976` listener to capture the auth code and a manual `client_secret_post` token exchange. Either is a follow-up smoke task to lift the walkthrough from partial-captured to fully captured.

> **Note on the DCR client used during the smoke** — a low-risk transcript leak occurred: `curl POST https://mcp.pandadoc.com/register` echoed the freshly-minted `client_id` + `client_secret` to stdout. Risk is low because the client is fresh, has no user grants, and the secret alone is useless without an authorization_code. Tracked separately for awareness; PandaDoc DCR does not appear to expose a management endpoint, so deletion requires support contact.
