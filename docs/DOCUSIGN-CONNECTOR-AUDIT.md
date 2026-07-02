# DocuSign Connector - Phase 0 audit

**Source.** Issue [#148](https://github.com/selrai-company/claude-workshop-kit/issues/148) - connector skill for DocuSign eSign. Per @harvey-selr's 2026-04-27 connector directive (item #15: *"DocuSign | 1.5M+ customers, eSign API"*).

**Audit date.** 2026-05-04.

**Audit scope.** Identify the canonical MCP server target for DocuSign eSign, recommend an install architecture, surface decision-locking findings before SKILL.md code lands.

---

## TL;DR

**Build against the official hosted MCP server at `https://mcp.docusign.com/v1/mcp`.** DocuSign publishes an RFC 8414 OAuth metadata document confirming this is a real, OAuth-protected hosted MCP - the official artifact, not a community fork. Auth flow: standard OAuth 2.0 Authorization Code Grant + PKCE against DocuSign's production OAuth endpoints (`account.docusign.com/oauth/auth` + `account.docusign.com/oauth/token`).

The SKILL pattern is **hybrid Literal-Playwright** combining two prior workshop-kit precedents:

- **Phase 1 setup**: drive `admindemo.docusign.com/api-integrator-key` (sandbox; `admin.docusign.com/api-integrator-key` for production) to create an Integration Key - same shape as `hubspot-connector` PR #175 Private App creation (admin-portal + DOM-extract for Client ID + Client Secret).
- **Phase 1 connect**: `claude mcp add docusign https://mcp-d.docusign.com/v1/mcp --transport http --scope user` (sandbox URL) + post-[#198](https://github.com/selrai-company/claude-workshop-kit/issues/198) `mcp__docusign__authenticate()` / `complete_authentication({callback_url})` pair - Claude Code's MCP-runtime tools acquire the OAuth URL programmatically and finalise the callback, replacing the deprecated 401-challenge URL-grep pattern that older canva/atlassian SKILLs use.

Rejecting all 6 community DocuSign-MCP candidates surveyed; the official hosted MCP makes them obsolete.

---

## Candidates examined

| Candidate | Source | Verdict |
|---|---|---|
| **`mcp.docusign.com`** (hosted MCP) | DocuSign first-party | ✅ **RECOMMENDED** - verified live 2026-05-04 |
| `docusign-mcp` / `docusign-mcp-server` / `@docusign/mcp` / `@docusign/mcp-server` (npm) | npm registry | ❌ All 404 - none exist on npm |
| `CDataSoftware/docusign-mcp-server-by-cdata` | GitHub Java | ❌ **Read-only** - can't send envelopes; deal-breaker for workshop attendee who wants signing flows |
| `luthersystems/mcp-server-docusign` | GitHub Python (1⭐) | ❌ JWT server-to-server auth only, NOT OAuth Authorization Code (which is what #148 spec calls for) |
| `primrose-mcp/primrose-mcp-docusign` | GitHub TS (0⭐) | ❌ Fresh, no description, no adoption |
| `parsa7/docusign-mcp-app` | GitHub TS (0⭐) | ❌ Personal app, no docs |
| `hansdoebel/zed-mcp-docusign` | GitHub JS (0⭐) | ❌ Zed editor integration, not workshop-applicable |
| `thisdot/docusign-navigator-mcp` | GitHub TS (0⭐) | ❌ DocuSign **Navigator** (analytics product) - wrong surface |
| `@esignlaunchpad/mcp-server` | npm | ❌ Different product (eSign Launchpad ≠ DocuSign) |
| `docusign/mcp-agent-foundry-procurement-python` | DocuSign org GitHub | ⚠️ Sample CLIENT, not a server - confirms the hosted MCP exists but doesn't replace it |

---

## Hosted MCP - empirical evidence

Verified live 2026-05-04 against `https://mcp.docusign.com`:

### RFC 8414 OAuth metadata (`/.well-known/oauth-authorization-server`)

```json
{
  "issuer": "https://account.docusign.com/",
  "authorization_endpoint": "https://account.docusign.com/oauth/auth",
  "token_endpoint": "https://account.docusign.com/oauth/token",
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "response_types_supported": ["code"],
  "code_challenge_methods_supported": ["S256"],
  "scopes_supported": [
    "signature", "click.manage", "me_profile", "room_forms",
    "inproductcommunication_read", "data_explorer_signing_insights",
    "notary_read", "notary_write", "search_read", "search_write",
    "webforms_manage", "dtr", "valmod_manage", "models_esign_manage",
    ...
  ]
}
```

### Endpoint reachability (all 403 without auth - endpoint exists, OAuth-protected)

- `https://mcp.docusign.com/v1/mcp` → 403 (HTTP streamable transport)
- `https://mcp.docusign.com/v1/sse` → 403 (SSE legacy)
- `https://mcp.docusign.com/authorize` → 403 (without params)

### Differences from canva/atlassian bridge OAuth

| Aspect | canva PR #180 / atlassian PR #186 | DocuSign |
|---|---|---|
| Authorize URL pattern | `mcp.<provider>.com/authorize` (bridge substitutes provider's central OAuth) | `account.docusign.com/oauth/auth` (DocuSign's production OAuth directly - no bridge layer) |
| RFC 7591 DCR (dynamic client registration) | ✅ Yes (`registration_endpoint` in metadata) | ❌ Not in metadata - user **must** pre-create an Integration Key in `developers.docusign.com` |
| User's manual setup before OAuth | None - DCR auto-mints client | **Required** - admin-portal flow to create Integration Key, configure redirect URI, copy Client ID + Secret |

The "no DCR, must pre-create client" property means DocuSign's auth model has more in common with `hubspot-connector` (Private App creation) than canva's bridge. **It's a hybrid**: hubspot-style Integration Key creation + canva-style hosted MCP runtime auth.

---

## Recommended architecture - hybrid Literal-Playwright

`skills/docusign-connector/SKILL.md` follows the canonical autonomous-Playwright pattern with two phases:

### Phase 0 - pre-flight (silent)
- Resume check: `~/.claude.json` `mcpServers.docusign` entry exists? Skip to Phase 2 if yes.
- Tooling check: `claude` CLI on PATH, Playwright MCP available, Node 18+.

### Phase 1 - install & auth (autonomous, ~8 numbered steps)

| Step | Action | Pattern reference |
| --- | --- | --- |
| 1 | Orient - browser opening, sign-in once | canva PR #180 Step 1 |
| 2 | Drive `https://admindemo.docusign.com/api-integrator-key` in Playwright (sandbox; `https://admin.docusign.com/api-integrator-key` for production); detect login state; prompt sign-in only if needed | hubspot PR #175 Step 2 |
| 3 | Auto-click "ADD APP", fill name (`Selr AI Assistant`), accept terms, submit. Auto-extract Integration Key from the new app's page | hubspot PR #175 Step 3 (DOM-extract) |
| 4 | Configure Authentication tab: enable `Authorization Code Grant`, add redirect URI matching Claude Code's MCP-runtime callback (`http://localhost:<port>/callback`), tick V1 scope set (default `signature` only - see scope triage below). Auto-extract Secret Key from the one-time-reveal modal (same one-shot pattern as xero `Generate a secret`) | hubspot + xero PR #191 Step 6 |
| 5 | `claude mcp add docusign https://mcp-d.docusign.com/v1/mcp --transport http --scope user --env DOCUSIGN_INTEGRATION_KEY=<id> --env DOCUSIGN_SECRET=<key>` (sandbox URL; `mcp.docusign.com` for production) | canva PR #180 Step 2 + xero PR #191 Step 7 |
| 6 | `mcp__docusign__authenticate()` (no args) - returns the OAuth start URL programmatically. **Replaces the deprecated 401-challenge URL-grep pattern per [#198](https://github.com/selrai-company/claude-workshop-kit/issues/198).** | post-#198 canonical (jotform/calendly/linear/atlassian/canva rewrite scope) |
| 7 | `browser_navigate(returned_url)`; **user signs in (the only manual moment)**; Claude auto-clicks the Allow button on DocuSign's consent screen via `mcp__playwright__browser_click` after locating it from the snapshot by matching `role: button` against the consent verbs (allow / authorise / grant access) - narrate the consent line ("DocuSign wants access to envelopes, templates, account info - clicking Allow now") so the user can intervene if the scopes look wrong; `browser_wait_for` URL match `localhost:*/callback`; `browser_evaluate(() => window.location.href)` to capture the full callback URL **before** `browser_close` | post-#198 canonical + `feedback_human_touch_only_login.md` (strict: Allow is auto-clicked, not user-clicked) |
| 8 | `mcp__docusign__complete_authentication({ callback_url })` finalises OAuth in-session (no chat restart needed); verify with `mcp__docusign__<smoke_tool>` (smoke call name TBD at SKILL build time per Phase 2 enumeration) | post-#198 canonical |

### Phase 2 - tool reference

DocuSign's hosted MCP exposes tools wrapping the eSignature REST API. Tool names not yet enumerated (will be discovered at runtime via `tools/list` once Phase 1 completes against a real account). Expected categories:
- **Envelopes**: list, get, create, send, void
- **Templates**: list, get, apply
- **Recipients**: list, get, update
- **Documents**: list, get, download
- **Account**: get info, list users

---

## Sandbox vs production - workshop targets sandbox

DocuSign provides free **Developer Account** at `account-d.docusign.com` (sandbox). All workshop attendees should use sandbox initially; production migration is a v2 concern.

| Environment | OAuth host | MCP host | Admin portal |
| --- | --- | --- | --- |
| **Sandbox** (workshop default) | `account-d.docusign.com` | `https://mcp-d.docusign.com/v1/mcp` | `https://admindemo.docusign.com/api-integrator-key` |
| **Production** | `account.docusign.com` | `https://mcp.docusign.com/v1/mcp` | `https://admin.docusign.com/api-integrator-key` |

All four sandbox endpoints + both admin-portal URLs verified live 2026-05-04. Sandbox MCP metadata fetched at `https://mcp-d.docusign.com/.well-known/oauth-authorization-server`:

```json
{
  "issuer": "https://account-d.docusign.com/",
  "authorization_endpoint": "https://account-d.docusign.com/oauth/auth",
  "token_endpoint": "https://account-d.docusign.com/oauth/token",
  "grant_types_supported": ["authorization_code", "refresh_token"],
  "code_challenge_methods_supported": ["S256"]
}
```

**Protocol-level OAuth-Bearer challenge confirmed** (verified live 2026-05-04). A `POST` against `https://mcp-d.docusign.com/v1/mcp` with `Authorization: Bearer bogus` returns:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="https://mcp-d.docusign.com/v1/mcp", error="invalid_token"
```

This is the **RFC 6750 OAuth Bearer challenge shape** - the same shape `mcp.canva.com/v1/mcp` returns (`WWW-Authenticate: Bearer realm="OAuth", error="invalid_token"`). Identical bridge-OAuth pattern. This is the trigger Claude Code's MCP runtime needs to auto-emit the per-server `mcp__docusign__authenticate()` / `complete_authentication({callback_url})` tool pair (the post-#198 canonical pattern). The full handshake test (a valid bearer → `tools/list` → returned tool inventory) still requires a real Developer Account; only the OAuth-protected-MCP shape is verified at audit time.

Sandbox + production share an identical 54-scope catalogue. Same Auth Code Grant + PKCE-S256 constraints. The two environments are logically separate accounts - Integration Keys created in `admindemo` only authenticate against `account-d`, and vice versa.

## Sandbox → production migration (v2 concern, but document the trap)

Sandbox and production are logically separate DocuSign accounts. Workshop attendees who build against the sandbox and later flip to production discover:

- Their sandbox Integration Key is valid only on `account-d.docusign.com`. They must create a NEW Integration Key in `admin.docusign.com/api-integrator-key` (production portal).
- The production app needs separate consent - going through the OAuth flow once on sandbox does not consent the production app.
- `~/.claude.json` `mcpServers.docusign` entry must be updated: change `mcp-d.docusign.com` → `mcp.docusign.com`, and replace `DOCUSIGN_INTEGRATION_KEY` + `DOCUSIGN_SECRET` with production values.

**SKILL implication**: support a `DOCUSIGN_ENV=production` switch in the SKILL's Phase 0 that drives the production portal + production MCP host instead of sandbox. Document the migration path in the SKILL's "Reconnect to production" section so attendees don't end up debugging a dead key.

---

## OAuth Authorization Code Grant + PKCE flow

Per the metadata, the flow is:

1. SKILL constructs auth URL: `https://account-d.docusign.com/oauth/auth?response_type=code&client_id=<integration_key>&redirect_uri=<claude_code_callback>&scope=signature&code_challenge=<S256_hash>&code_challenge_method=S256&state=<random>` (sandbox; swap host for production)
2. User signs in (handled by Claude Code's MCP runtime + Playwright auto-click on consent)
3. DocuSign redirects to `redirect_uri?code=<auth_code>&state=<state>`
4. Claude Code MCP runtime exchanges code for tokens at `https://account-d.docusign.com/oauth/token` with `code_verifier` (PKCE) + Client Secret
5. Bearer token used to authenticate calls to `mcp-d.docusign.com/v1/mcp`
6. Token lifetime: 8 hours; refresh token: 30 days, single-use auto-rotated

Claude Code's MCP runtime should handle steps 3-5 natively given `--transport http` registration. PKCE S256 is the only supported challenge method - same as canva + atlassian. Per the post-[#198](https://github.com/selrai-company/claude-workshop-kit/issues/198) pattern, the SKILL acquires the auth URL via `mcp__docusign__authenticate()` (returned programmatically by Claude Code's MCP runtime) instead of constructing it manually or scraping a 401-challenge response. The callback URL is submitted via `mcp__docusign__complete_authentication({ callback_url })` rather than letting the runtime swallow it silently - this finalises auth in-session, no chat restart needed.

## Default scope set (workshop minimum-permission - provisional, verify at SKILL-build time)

Sandbox metadata exposes 54 scopes. Triaged for the workshop's "send envelope, list envelopes, get signed status" canonical demo flow:

| Tier | Scopes | Default in SKILL |
| --- | --- | --- |
| 1 - core eSign (documented baseline) | `signature` | ✅ ticked - **provisional baseline; verify per-tool requirements when Phase 2 is enumerated against a live account** |
| 2 - common eSign add-ons | `click.manage`, `webforms_manage`, `me_profile`, `account_read` | optional, commented-out toggle |
| 3 - admin/niche | `user_read`, `group_read`, `notary_read`, `notary_write`, `room_forms` | off |
| 4 - IAM/Navigator/AI/ops platform internals | 40+ scopes (`adm_*`, `act_*`, `cds_*`, `aow_*`, `spring_*`, `clause_*`, `models_*`, `dcf_*`, `ai_jobs_engine_*`, `iam_folders_*`, `audit_log_read`, etc.) | off (different product surfaces - IAM is separate from eSign) |

**Caveat - Tier 1 scope claim is unverified.** `signature` is the documented baseline scope per DocuSign's eSignature REST API auth docs, and matches the xero V1 minimum-permission pattern (PR #191). It has NOT been live-tested against the SKILL's planned smoke call (`mcp__docusign__list-envelopes` or equivalent). DocuSign's scope model historically requires `signature impersonation` for some account-level flows and `extended` for refresh-token rotation; the per-tool minimum may differ from the per-API-surface minimum. **Action at SKILL build time**: before locking the scope set, authenticate with `signature` only and run the SKILL's planned smoke tools - if any return 403/insufficient_scope, escalate to Tier 2 or specifically add the missing scope. Document the actual minimum once verified.

---

## Pattern reference cross-walk

| SKILL phase concern | Reference in workshop-kit |
| --- | --- |
| Admin-portal + DOM-extract for Client ID + Secret | `skills/hubspot-connector/SKILL.md` (PR #175) |
| One-time-reveal Secret modal handling | `skills/xero-connector/SKILL.md` Step 6b (PR #191) |
| Hosted MCP + `claude mcp add http` registration | `skills/canva-connector/SKILL.md` (PR #180), `skills/atlassian-connector/SKILL.md` (PR #186) |
| `authenticate()` / `complete_authentication()` OAuth bootstrap (post-#198 canonical) | Tracked in [#198](https://github.com/selrai-company/claude-workshop-kit/issues/198); will be reflected in jotform/calendly/linear/atlassian/canva once #198 lands. **Build docusign-connector against the post-#198 shape directly so it's forward-compatible regardless of #198 sequencing.** |
| OAuth callback URL-change auto-detect (`browser_wait_for` + `browser_evaluate`) | post-#198 canonical |
| Phase 0 resume check + tooling auto-install | All recent connector PRs (canonical pattern) |

---

## Out of scope (explicit follow-ups, not blockers)

- **Building `skills/docusign-connector/SKILL.md`** - the actual SKILL is a follow-up PR. This audit closes the architectural decision phase only.
- **Live tool-list enumeration** - needs a real DocuSign Developer Account to authenticate the smoke call. Audit-time enumeration not feasible.
- **JWT server-to-server flow** - the issue spec scopes v1 to OAuth Authorization Code Grant only. JWT (for headless server use) is v2.
- **Production migration path** - workshop default is sandbox. Production switch is a future v2 concern.
- **Webhooks / Connect listeners** - DocuSign's webhook surface (Connect) is separate from the eSign API and not in scope for v1.
- **Selr forking the hosted MCP** - not needed; DocuSign maintains the official artifact.

---

## Acceptance criteria status

From issue #148, post-audit:

- [x] **Phase 0 audit on community DocuSign MCP servers** - done; all 6 community options rejected for fitness, license, or scope. Official hosted MCP (`mcp.docusign.com`) recommended instead.
- [x] **Confirm chosen MCP supports Auth Code Grant + signature scope** - verified live: metadata shows `grant_types_supported: ["authorization_code", "refresh_token"]` + `scopes_supported` includes `signature`.
- [ ] **Build `skills/docusign-connector/SKILL.md`** - not in this PR; follow-up.

---

## Recommendation summary

**Build `skills/docusign-connector/SKILL.md` against `https://mcp-d.docusign.com/v1/mcp` for sandbox (parameterise on a `DOCUSIGN_ENV` switch for production).** Hybrid Literal-Playwright pattern - hubspot-style Integration Key creation in the `admin[demo].docusign.com/api-integrator-key` portal + post-#198 `mcp__docusign__authenticate()` / `complete_authentication({callback_url})` pair for the OAuth bootstrap (replacing the deprecated 401-challenge URL-grep pattern). Default scope set: `signature` only (Tier 1). PKCE S256, OAuth Authorization Code Grant against DocuSign's `account[-d].docusign.com` endpoints. Sandbox-first for workshop attendees; production migration deferred to v2.

If the workshop-kit team disagrees with adopting the official hosted MCP (e.g., wants self-hosting for control), the alternative is a self-built MCP shim wrapping the DocuSign Node SDK - significantly heavier (~5 days of build), with all the maintenance burden Selr would inherit. **Recommend against** that path absent a specific reason to reject the official artifact.
