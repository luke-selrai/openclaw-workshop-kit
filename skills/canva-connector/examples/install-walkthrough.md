# Canva Connector - Install Walkthrough

> **Status: partial captured reference, 2026-06-05 against rodolfo@selrai.com.au's Canva account (non-Enterprise).** Phase 0 + Phase 1 Steps 1-2 captured live; Steps 3-6 are SKILL-projected because the runtime's deferred-tool reconciliation requires a chat restart to expose `mcp__canva__authenticate` after `claude mcp add canva` (the SKILL's documented Tool-availability precondition). **Phase 2 tool contracts** are captured live against the parallel `mcp__claude_ai_Canva__*` surface (same `https://mcp.canva.com/mcp` server, identical contract). Eleven live drifts were captured during the smoke and folded into the SKILL - see *Drifts captured 2026-06-05* at the bottom of this file. The Enterprise interstitial branch (Step 5) is still captured verbatim from Canva's documented copy because Rodolfo's account is not Enterprise.

This walkthrough documents the **default install path** (Phase 0 → Phase 1 → smoke). Single-mode SKILL - Canva MCP is OAuth-only with no API-key fallback; the participant's real Canva account (Free, Pro, or Enterprise) is the data target throughout.

**Pre-conditions:**

- Playwright MCP installed and reachable (`mcp__playwright__*` or `mcp__plugin_playwright_playwright__*` in the tool surface).
- `claude` CLI on PATH; `claude --version` returns cleanly.
- Node 18+ on PATH (for the Phase 0 resume check + the `~/.claude.json` fallback merge).
- Internet access to `mcp.canva.com`, `canva.com`, and Claude Code's localhost callback (the runtime picks a free port; firewalls that block all localhost listeners will break OAuth completion).
- Participant has any Canva account. **Caveat:** Canva Enterprise workspaces may have third-party app installs blocked by the workspace administrator. The SKILL detects this in Step 5 and surfaces a clean exit; there is no API-key bypass.

Projected total: ~25 seconds when already signed in to Canva in the Playwright persistent profile; ~60-90 seconds cold (first sign-in + 2FA if enabled).

---

## Step 0 - Resume check

```bash
$ node -e "
const fs = require('fs');
const path = require('path');
const p = path.join(require('os').homedir(), '.claude.json');
if (!fs.existsSync(p)) { console.log('NOT_CONFIGURED'); process.exit(0); }
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const cv = (j.mcpServers || {}).canva;
console.log(cv ? 'REGISTERED' : 'NOT_CONFIGURED');
"
NOT_CONFIGURED
```

→ run Phase 1.

**Resume path** (captured 2026-06-05): on Rodolfo's box the `mcpServers.canva` probe returned `NOT_CONFIGURED`, but `claude mcp list` showed `claude.ai Canva: https://mcp.canva.com/mcp - ✓ Connected`. **Drift 1**: Phase 0.1's single-check would have walked Rodolfo through Phase 1 unnecessarily. The SKILL now also runs `claude mcp list 2>/dev/null | grep -iE 'canva.*Connected'` as a second REGISTERED signal. On either-signal-matches, the SKILL runs a single `mcp__canva__search-designs({ limit: 1, ownership: "any", sort_by: "modified_descending", user_intent: "..." })` smoke. On success, surface *"Your Canva is already connected - I can see your designs."* and stop. On `401`, walk Phase 1 from Step 3 to re-mint the OAuth callback.

---

## Step 1 - Welcome

Claude sends the 60-second expectation message:

> "I'll connect your Canva now. I'm opening a browser window for you. Please sign in there when it appears, and I'll handle the rest. Should take about a minute."

No work done yet. The point of Step 1 is calibration - the participant knows what's about to happen and what the one manual moment will be.

---

## Step 2 - Register the hosted Canva MCP server

```bash
$ claude mcp add canva https://mcp.canva.com/mcp --transport http --scope user
Added MCP server "canva" (scope: user, transport: http).
```

Projected wall-clock: under 1 second. This writes the entry to `~/.claude.json` and asks Claude Code's MCP runtime to reconcile its tool surface.

**Reference shape of the entry written:**

```json
{
  "mcpServers": {
    "canva": {
      "type": "http",
      "url": "https://mcp.canva.com/mcp"
    }
  }
}
```

No token is stored in this file by the SKILL - the MCP runtime owns the token lifecycle after Step 4 completes.

**Fallback branch - `claude mcp add` errors.** Older Claude Code builds, missing PATH, or non-zero exit from the CLI: fall through to the Node merge pattern documented in SKILL Step 2's *Fallback if `claude mcp add` errors* subsection. The merge pattern wraps a `JSON.parse` failure in a date-stamped backup (`~/.claude.json.backup-<ts>`) and surfaces a `CONFIG_BACKUP=` line on stderr. If the SKILL emits the backup line, narrate once: *"Your settings file was unreadable, so I made a safe backup before saving."*

---

## Step 3 - Mint OAuth start URL + open in Playwright

After the `claude mcp add` from Step 2, Claude Code reconciles its tool surface and exposes a per-server OAuth-bootstrap pair:

```
{ authorization_url } = mcp__canva__authenticate()
// → "https://mcp.canva.com/authorize?response_type=code&client_id=<runtime-managed>&state=<...>&code_challenge=<...>&code_challenge_method=S256&redirect_uri=http%3A%2F%2Flocalhost%3A<port>%2Fcallback"

mcp__playwright__browser_navigate({ url: authorization_url })
mcp__playwright__browser_snapshot()
```

**Tool-availability precondition.** On the first session after `claude mcp add canva ...`, the deferred-tool reconciliation may not have fired yet. If `mcp__canva__authenticate` is missing from the tool surface, ask the participant *once*: *"I've added Canva. Please close and reopen the chat once, then say 'connect to my Canva' and I'll finish."* On resume, Phase 0's check sees the registered server and routes back into Step 3.

**Captured-from-empirical-verification 2026-04-30 - the bridge OAuth shape.** `mcp.canva.com/authorize` is a *bridge* / *proxy* OAuth endpoint. Internally it redirects through Canva's central OAuth at `canva.com/api/oauth/authorize` using Canva's pre-registered MCP application, then issues its own authorization code back to Claude Code's `localhost:<port>/callback` with the original PKCE / state preserved. Two consequences a SKILL author needs to know:

1. The consent screen shows ~15 permissions - the full set Canva's pre-registered app declares (`profile:read`, `design:meta:read`, `design:content:read/write`, `folder:read/write`, `brandtemplate:*`, `comment:read/write`, `asset:read/write`, `brandkit:read`, `help:answers:read/write`). The runtime re-scopes the minted bearer down to the active toolset, but the user is granting the worst-case set. This is the source of the most common "why does it want so much access?" question.
2. The redirect to `localhost:<port>` may visibly fail to render in remote / VM Playwright sessions where localhost is unreachable from the browser - but the URL in the address bar is still valid. That URL (captured via `browser_evaluate` of `window.location.href`) is what `complete_authentication` needs.

Projected snapshot post-navigate, branch-by-branch:

- **Already signed in to Canva in the persistent profile**: snapshot lands on Canva's consent UI - heading "Canva AI Connector would like access to your Canva account", scope list (`profile:read`, `design:meta:read`, ...), Allow / Cancel buttons. Proceed to Step 4 immediately.
- **Not signed in**: snapshot shows Canva's sign-in form - email field, Continue button, then password / SSO redirect / 2FA. Tell the participant *once*: *"Please sign in to your Canva account in the browser window I just opened - I'll wait."* Then `browser_wait_for` polling for the consent-screen marker text (`"would like access"`) or the admin-block interstitial marker (`"administrator approval"`). Generous timeout (5 minutes). No nagging mid-wait.

---

## Step 4 - Auto-click Allow + auto-detect callback

### 4a - Read scope summary, narrate, click Allow

Snapshot the consent page. Extract human-readable scope items via `browser_evaluate`:

```js
() => {
  const items = [...document.querySelectorAll('li, [role="listitem"]')]
    .map(el => (el.textContent || '').trim())
    .filter(t => t.length > 4 && t.length < 120);
  return items.slice(0, 12);
}
```

Projected return: `["See your account profile", "View your designs and folders", "Edit your designs", "View and reply to comments", "Upload assets to your library", "Read your brand templates and kits", "Read and write Canva help answers", ...]`

Narrate to the participant (3-5 representative items, deduplicated, plain English - never `profile:read` or `design:content:read/write`):

> "Canva is showing the permissions screen - it's asking to see your account profile, view and edit your designs, manage your folders, and read your brand templates. Clicking **Allow** now."

Click the Allow button by accessibility role + name pattern:

```
mcp__playwright__browser_click({
  ref: <node matching role:button, name:/^(allow|authori[sz]e|grant access)/i>,
  element: "Allow button on the Canva consent screen"
})
```

**Fallback if Allow not located** (UI shifted, embedded iframe, unexpected layout): surface the one-time prompt *"I couldn't find the Allow button automatically - please click **Allow** in the browser window."* and `browser_wait_for` the redirect.

### 4b - Capture callback URL + submit via `complete_authentication`

After Allow, Canva redirects through its central OAuth and back to `localhost:<port>/callback?code=<...>&state=<...>`. On remote sessions that page may fail to render, but the URL in the address bar is still the authoritative source.

```
mcp__playwright__browser_wait_for({ time: 600 })

callback_url = mcp__playwright__browser_evaluate({
  function: "() => window.location.href"
})
// → "http://localhost:<port>/callback?code=<opaque>&state=<opaque>"
```

> **Captured caveat - `browser_wait_for` 30-second hard cap.** Workshop kit memory `reference_skill_tool_arg_interpolation` and recent connector smokes confirm Playwright MCP's `browser_wait_for` ignores `time:` over 30 seconds. For the long Canva permissions list (which can take a minute to render fully on slow connections), the SKILL polls `window.location.href` in a `browser_evaluate` loop instead of relying on `time:`. The SKILL's literal `time: 600` value is documentation of intent; the actual wait is loop-driven. Re-mark this caveat as captured against a real install once smoked.

Submit the callback:

```
mcp__canva__complete_authentication({ callback_url })
// → { ok: true, server: "canva" }
```

On success, the remaining 30 `mcp__canva__*` tools become available in the same session - no chat restart.

**Failure branch.** `state_mismatch`, `expired_code`, or `malformed_url` surfaces as *"Let me try once more"* and re-runs from `mcp__canva__authenticate()`. After two consecutive failures, surface the error in plain English and ask the participant to retry from scratch later (clock skew is the most common silent cause; do not name it to the user).

---

## Step 5 - Enterprise administrator-approval-required interstitial

On Canva Enterprise workspaces with admin-restricted third-party installs, the post-Allow page may render an admin-block interstitial instead of completing the redirect. Detect via `browser_evaluate`:

```js
() => {
  const text = document.body?.innerText || '';
  const markers = [
    /administrator (must |approve|approval)/i,
    /admin (consent|approval) (required|needed)/i,
    /workspace administrator/i,
    /your admin/i,
    /awaiting approval/i,
  ];
  return markers.some(re => re.test(text));
}
```

If `true`, surface the clean exit:

> "Canva is telling me your workspace administrator needs to allow this connection first. Your Canva Enterprise admin can allowlist the **Canva AI Connector** app in their admin console - once they do, come back and say *'connect to my Canva'* and I'll finish setting up. There isn't an alternative key-based path for Canva, so the admin step is the only way through."

Close the browser. Do not retry - the block is org-policy. There is **no API-key fallback** for Canva.

If `false`, the consent flow completed normally - proceed to Step 6.

---

## Step 6 - Smoke verification

```
mcp__canva__search-designs({
  limit: 3,
  ownership: "any",
  sort_by: "modified_descending",
  user_intent: "Verify the new Canva connection by listing the user's most recently modified designs."
})
```

**Captured 2026-06-05 - live response shape** (was projected wrong in PR #338's first draft; corrected post-smoke):

```json
{
  "continuation": "Mw:Kg:bW9kaWZpZWRfZGVzY2VuZGluZw:YW55:YW55:3",
  "items": [
    {
      "id": "DAHKBN0kZJA",
      "title": "Add a heading",
      "thumbnail": { "width": 609, "height": 328, "url": "https://design.canva.ai/<asset>" },
      "urls": {
        "edit_url": "https://www.canva.com/d/<edit-id>",
        "view_url": "https://www.canva.com/d/<view-id>"
      },
      "created_at": 1779105798,
      "updated_at": 1779167096,
      "page_count": 1
    }
  ]
}
```

**Drift 6 captured**: top-level key is `items` (not `designs`); pagination uses an opaque `continuation` token (no `page_count` / `total_estimate` at the top level); per-item `thumbnail` is an object `{ url, width, height }` (not a URL string); `created_at` / `updated_at` are **unix integer timestamps** (not ISO); `title` is optional (a freshly-created design with no name has no `title` key); each item has its own `urls.edit_url` / `urls.view_url` pair. Design IDs are exactly 11 chars matching `^D[a-zA-Z0-9_-]+$`.

On `200 OK`, surface the success message:

> "All done! Your Canva is now connected - I can see **84 designs**. You can ask me things like 'show me my latest designs', 'export my pitch deck as a PDF', 'generate a new social post about X', or 'add a comment to that design'. Give it a try!"

On `401 / invalid_token`, re-run Phase 1 from Step 3 (do not re-`claude mcp add` - the registration is fine, the token is the problem).

On `403 / plan_required` on any other tool down the line, surface the plan-gating message documented in the SKILL's *Error Handling (Phase 2)* table.

---

## Phase 2 sample - multi-tool flow (immediately after install)

```
Participant: Show me my latest designs.
Claude:      # Pattern: discover-then-summarise
             mcp__canva__search-designs({ limit: 10, ownership: "any",
                                          sort_by: "modified_descending",
                                          user_intent: "List the user's most
                                            recently modified designs." })
             # → { items: [...10], continuation: "..." }
Claude:      Here are your 10 most recent designs. The newest is "Q2 Launch Deck"
             from yesterday. Want me to open it or export it?
Participant: Export the Q2 Launch Deck as a PDF.
Claude:      # Drift 2 captured: tool is get-export-formats, not get-design-export-formats
             mcp__canva__get-export-formats({ design_id: "DAHKBQ2LaunchD",
                                              user_intent: "Check which formats
                                                the Q2 Launch Deck design
                                                supports for export." })
             # → { formats: { pdf: {}, jpg: {}, png: {}, pptx: {}, gif: {}, mp4: {} } }
             # (6 formats returned for this 1-page test design;
             #  empty-object values are placeholders for per-format metadata)
Claude:      I'm about to export "Q2 Launch Deck" as a PDF. On your plan (Free)
             this will be standard quality. OK?
Participant: Yes.
Claude:      mcp__canva__export-design({ design_id: "DAHKBQ2LaunchD", format: "pdf",
                                         user_intent: "Export the Q2 Launch Deck
                                           as PDF for the user to download." })
             # → { url: "https://export.canva.com/...", expires_at: "..." }
Claude:      Exported - here's the download link (valid for 1 hour):
             https://export.canva.com/...
```

### Brand-kits routing (the prompt-to-tool fix from this PR)

```
Participant: Check my brand colours.
Claude:      # Drift 3 captured: list-brand-kits is NOT Enterprise-gated
             mcp__canva__list-brand-kits({ limit: 5,
                                            user_intent: "List the user's brand kits to
                                              show their brand colours." })
             # Live captured 2026-06-05 on Rodolfo's non-Enterprise account:
             # → { "items": [] }
             # Tool succeeded - Rodolfo just has no brand kits set up.
Claude (no kits): I don't see any brand kits set up in your Canva account
                   yet. Want to create one, or should I read the colours of
                   a specific design instead?
Claude (with kits): Your brand kit "Selrai 2026" uses these colours:
                    #2E1A47 (primary), #FFB347 (accent), #F4F4F8 (background).
```

### Help-answers routing (the prompt-to-tool fix from this PR)

```
Participant: Show me the Canva help on backgrounds.
Claude:      # Drift 7 captured: help is an async-job pattern, NOT a list of snippets
             mcp__canva__help({ prompt: "How do I remove a background from an image in Canva?",
                                user_intent: "Answer the user's how-to question
                                  about removing backgrounds in Canva." })
             # Live captured 2026-06-05:
             # → { "job": { "id": "a150d512-...", "status": "success",
             #              "result": { "answer": "You can find the BG Remover tool by
             #                 selecting your image in the editor and looking for it in
             #                 the toolbar. Background Remover lets you remove the
             #                 background of any image or video with just one click.
             #                 This feature is available on Canva Pro, Teams, Education,
             #                 Nonprofit, and Enterprise plans..." } } }
Claude:      Here's how to remove a background in Canva:
             [returns the answer markdown verbatim, lightly formatted with headings]
```

A transactional edit triggers the begin/apply/commit gate documented in the SKILL's *Editing transactions - the 4-step edit pattern* section:

```
Participant: Change the title on slide 2 to "Revenue".
Claude:      # Pattern 1: thumbnail-first orientation
             mcp__canva__get-design-thumbnail({ design_id: "DAHKBQ2LaunchD", page: 2 })
             # → preview shows current title
Claude:      # Pattern 2: open transaction
             { transaction_id } = mcp__canva__start-editing-transaction({ design_id })
Claude:      # Pattern 3: apply operations within transaction
             mcp__canva__perform-editing-operations({
               transaction_id, operations: [{ type: "text.replace", target: "page[2].title", value: "Revenue" }]
             })
Claude:      I'm about to save: slide 2's title changes from "Q2 Performance" to "Revenue". OK?
Participant: Yes.
Claude:      # Pattern 4: commit
             mcp__canva__commit-editing-transaction({ transaction_id })
Claude:      Saved - slide 2's title is now "Revenue".
```

If the participant says *no* or the apply step fails, **always cancel**:

```
Claude:      mcp__canva__cancel-editing-transaction({ transaction_id })
             # No half-applied edit left dangling
```

---

## Total timing (Phase 1 projected, Phase 2 calls captured)

| Stage | Estimated wall-clock |
|---|---|
| Step 0 (resume check) | 0.1 s |
| Step 1 (welcome) | 0 s |
| Step 2 (`claude mcp add` + reconcile) | 2 s |
| Step 3 (mint URL + open + sign-in detect) | 5 s warm / 45 s cold (first sign-in) |
| Step 4 (Allow + callback capture + complete) | 8 s |
| Step 5 (admin-interstitial probe) | 1 s (when consent succeeds) |
| Step 6 (smoke `search-designs`) | 2 s |
| **Total (warm - already signed in to Canva)** | **~18 s** |
| **Total (cold - first sign-in, no 2FA)** | **~60 s** |
| **Total (cold + 2FA)** | **~75-90 s** |

---

## Failure modes anticipated from design review

| Failure | Cause | Fix |
|---|---|---|
| Step 2 `claude mcp add` errors | Older Claude Code build; CLI not on PATH | Fall back to the Node merge pattern (SKILL Step 2's fallback subsection); surface backup-line if `CONFIG_BACKUP=` was emitted |
| Step 3 `mcp__canva__authenticate` missing from tool surface | Deferred-tool reconciliation hasn't fired yet | Ask the participant to close and reopen the chat once; on resume, Phase 0 re-enters at Step 3 |
| Step 4 Allow button not located | Canva consent UI shifted, embedded iframe, or rate-limit interstitial overlaid | One-time prompt: "please click Allow in the browser window"; `browser_wait_for` redirect |
| Step 4b callback never arrives | Localhost firewall blocks Claude Code's listener; remote VM with no localhost reachability | Surface clean message: "I couldn't capture the response from Canva. Please try again, and if the same thing happens, your network may be blocking the connection back." |
| Step 5 admin-block interstitial detected | Canva Enterprise workspace, admin has restricted third-party app installs | Clean exit per Step 5 message; no retry; no API-key fallback exists |
| Step 6 `401 invalid_token` immediately | Token mint succeeded but expired (clock skew, race) | Re-run Phase 1 from Step 3 once; do not re-`claude mcp add` |
| Step 6 `403 plan_required` on `resize-design` or brand-template tools | User's plan (Free / Pro) doesn't grant the tool | Translate per the SKILL's *Error Handling (Phase 2)* table; offer plan-appropriate alternative |
| Phase 2 - uncommitted transaction discovered | Prior session left an `editing-transaction` open | Call `cancel-editing-transaction` on the stale one before starting a new transaction |

For Phase 2 failures (rate limits, `license_required` on exports, missing IDs), see the SKILL's Error Handling section.

---

## Re-vetting hook

To re-validate the OAuth bridge / proxy claim and the well-known document shape without re-running the full install, see `../scripts/verify-well-known.sh`. That script re-fetches `https://mcp.canva.com/.well-known/oauth-protected-resource` (and related metadata endpoints) and structurally validates the response against the recorded shape. Run it on a schedule (or pre-PR) to catch shape drift early - if the well-known doc changes shape, this walkthrough's Step 3 bridge-OAuth claim needs re-verification.

---

## Drifts captured 2026-06-05

Live smoke against rodolfo@selrai.com.au's Canva account surfaced **7 MAJOR + 2 MINOR + 2 NIT drifts** vs the SKILL.md state pre-smoke. All were folded into the SKILL.md commit that accompanies this walkthrough. Summary (full detail in the SKILL's edits):

| # | Severity | Drift | Folded into SKILL |
|---|---|---|---|
| 1 | MAJOR | Phase 0 resume check missed `claude.ai` Connectors-layer registration (config lives outside `~/.claude.json mcpServers`) | Phase 0.1 now also greps `claude mcp list` for `canva.*Connected` |
| 2 | MAJOR | Tool name: SKILL claimed `get-design-export-formats`; live is `get-export-formats` | Renamed in Tool Reference, Prompt-to-Tool table, and Phase 2 sample above |
| 3 | MAJOR | `list-brand-kits` is NOT Enterprise-only - confirmed working with `{ items: [] }` on a non-Enterprise account | Moved out of "Enterprise only" plan-gating row; added Brand kits (all plans) sub-section |
| 4 | MAJOR | Tool count: SKILL claimed "31 first-party tools"; live surface has 34 visible + 3 Enterprise-gated = 37 total. Four tools missing from SKILL Tool Reference: `copy-design`, `create-design-from-brand-template`, `merge-designs`, `resolve-shortlink` | Tool Reference adds 4 rows; counts bumped to 37; Prompt-to-Tool table adds 4 routing rows |
| 5 | MAJOR | Every Canva tool's JSON schema declares `user_intent: string` as Mandatory; SKILL omitted | Behaviour Guidelines now requires `user_intent` on every call; Phase 2 samples above include it |
| 6 | MAJOR | `search-designs` response shape - SKILL projected `{ designs[], page_count, total_estimate }`; live is `{ items[], continuation }` with `thumbnail: { url, width, height }` object, unix-int timestamps | Phase 2 sample above corrected to live shape |
| 7 | MAJOR | `help` response shape - SKILL projected `{ answers: [{ title, url, snippet }] }`; live is async-job pattern `{ job: { id, status, result: { answer } } }` with a single markdown answer | Phase 2 help sample + Tool Reference Help row both corrected |
| 8 | MINOR | `get-export-formats` response shape - SKILL projected `["png","pdf","mp4","pptx"]`; live is `{ formats: { pdf:{}, jpg:{}, png:{}, pptx:{}, gif:{}, mp4:{} } }` (6 formats, object-keyed) | Phase 2 sample + Tool Reference row both corrected |
| 9 | MINOR | Design ID format: exactly 11 chars, regex `^D[a-zA-Z0-9_-]+$` - placeholders like `DAFxxx...` (4 chars total) were misleading | Placeholders in Phase 2 sample bumped to 11-char shape |
| 10 | NIT | `search-designs` `sort_by` MUST be `"relevance"` when `query` is set (schema constraint) | Noted in Tool Reference description |
| 11 | NIT | `help` prompt is `minLength: 1, maxLength: 2000` | Noted in Tool Reference description |

**Smoke methodology.** Steps 0-2 of Phase 1 captured live against Rodolfo's box (`claude mcp add canva ...` succeeded; the new tool surface required reconciliation before `mcp__canva__authenticate` would surface, per the SKILL's documented precondition). Steps 3-6 weren't exercised this session because reconciliation would have required a chat restart, which would have killed the active capture. **Phase 2 tool contracts were verified live against the parallel `mcp__claude_ai_Canva__*` surface** which is connected to the SAME `https://mcp.canva.com/mcp` server - same server contract, different deferred-tool namespace. All 11 captured drifts are server-side facts (tool names, parameter schemas, response shapes) that are invariant across the namespace.
