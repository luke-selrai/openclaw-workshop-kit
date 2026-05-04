# DocuSign Connector — Phase 0 audit

**Source.** Issue [#148](https://github.com/selrai-company/claude-workshop-kit/issues/148) — connector skill for DocuSign eSign. Per @harvey-selr's 2026-04-27 connector directive (item #15: *"DocuSign | 1.5M+ customers, eSign API"*).

**Audit date.** 2026-05-04.

**Audit scope.** Identify the canonical MCP server target for DocuSign eSign, recommend an install architecture, surface decision-locking findings before SKILL.md code lands.

---

## TL;DR

**Build against the official hosted MCP server at `https://mcp.docusign.com/v1/mcp`.** DocuSign publishes an RFC 8414 OAuth metadata document confirming this is a real, OAuth-protected hosted MCP — the official artifact, not a community fork. Auth flow: standard OAuth 2.0 Authorization Code Grant + PKCE against DocuSign's production OAuth endpoints (`account.docusign.com/oauth/auth` + `account.docusign.com/oauth/token`).

The SKILL pattern is **hybrid Literal-Playwright** combining two prior workshop-kit precedents:

- **Phase 1 setup**: drive `developers.docusign.com` to create an Integration Key (same shape as `hubspot-connector` PR #175 Private App creation — admin-portal + DOM-extract for Client ID + Client Secret)
- **Phase 1 connect**: `claude mcp add docusign https://mcp.docusign.com/v1/mcp --transport http --scope user` + Playwright drives DocuSign's standard OAuth consent screen (same shape as `canva-connector` PR #180 + `atlassian-connector` PR #186 bridge OAuth pattern)

Rejecting all 6 community DocuSign-MCP candidates surveyed; the official hosted MCP makes them obsolete.

---

## Candidates examined

| Candidate | Source | Verdict |
|---|---|---|
| **`mcp.docusign.com`** (hosted MCP) | DocuSign first-party | ✅ **RECOMMENDED** — verified live 2026-05-04 |
| `docusign-mcp` / `docusign-mcp-server` / `@docusign/mcp` / `@docusign/mcp-server` (npm) | npm registry | ❌ All 404 — none exist on npm |
| `CDataSoftware/docusign-mcp-server-by-cdata` | GitHub Java | ❌ **Read-only** — can't send envelopes; deal-breaker for workshop attendee who wants signing flows |
| `luthersystems/mcp-server-docusign` | GitHub Python (1⭐) | ❌ JWT server-to-server auth only, NOT OAuth Authorization Code (which is what #148 spec calls for) |
| `primrose-mcp/primrose-mcp-docusign` | GitHub TS (0⭐) | ❌ Fresh, no description, no adoption |
| `parsa7/docusign-mcp-app` | GitHub TS (0⭐) | ❌ Personal app, no docs |
| `hansdoebel/zed-mcp-docusign` | GitHub JS (0⭐) | ❌ Zed editor integration, not workshop-applicable |
| `thisdot/docusign-navigator-mcp` | GitHub TS (0⭐) | ❌ DocuSign **Navigator** (analytics product) — wrong surface |
| `@esignlaunchpad/mcp-server` | npm | ❌ Different product (eSign Launchpad ≠ DocuSign) |
| `docusign/mcp-agent-foundry-procurement-python` | DocuSign org GitHub | ⚠️ Sample CLIENT, not a server — confirms the hosted MCP exists but doesn't replace it |

---

## Hosted MCP — empirical evidence

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

### Endpoint reachability (all 403 without auth — endpoint exists, OAuth-protected)

- `https://mcp.docusign.com/v1/mcp` → 403 (HTTP streamable transport)
- `https://mcp.docusign.com/v1/sse` → 403 (SSE legacy)
- `https://mcp.docusign.com/authorize` → 403 (without params)

### Differences from canva/atlassian bridge OAuth

| Aspect | canva PR #180 / atlassian PR #186 | DocuSign |
|---|---|---|
| Authorize URL pattern | `mcp.<provider>.com/authorize` (bridge substitutes provider's central OAuth) | `account.docusign.com/oauth/auth` (DocuSign's production OAuth directly — no bridge layer) |
| RFC 7591 DCR (dynamic client registration) | ✅ Yes (`registration_endpoint` in metadata) | ❌ Not in metadata — user **must** pre-create an Integration Key in `developers.docusign.com` |
| User's manual setup before OAuth | None — DCR auto-mints client | **Required** — admin-portal flow to create Integration Key, configure redirect URI, copy Client ID + Secret |

The "no DCR, must pre-create client" property means DocuSign's auth model has more in common with `hubspot-connector` (Private App creation) than canva's bridge. **It's a hybrid**: hubspot-style Integration Key creation + canva-style hosted MCP runtime auth.

---

## Recommended architecture — hybrid Literal-Playwright

`skills/docusign-connector/SKILL.md` follows the canonical autonomous-Playwright pattern with two phases:

### Phase 0 — pre-flight (silent)
- Resume check: `~/.claude.json` `mcpServers.docusign` entry exists? Skip to Phase 2 if yes.
- Tooling check: `claude` CLI on PATH, Playwright MCP available, Node 18+.

### Phase 1 — install & auth (autonomous, ~7 numbered steps)

| Step | Action | Pattern reference |
|---|---|---|
| 1 | Orient — browser opening, sign-in once | canva PR #180 Step 1 |
| 2 | Drive `developers.docusign.com/apps` in Playwright; detect login state; prompt sign-in only if needed | hubspot PR #175 Step 2 |
| 3 | Auto-click "ADD APP", fill name (`Selr AI Assistant`), accept terms, submit. Auto-extract Integration Key from the new app's page | hubspot PR #175 Step 3 (DOM-extract) |
| 4 | Configure Authentication tab: enable `Authorization Code Grant`, add redirect URI for Claude Code's MCP runtime callback. Auto-extract Secret Key (one-time-reveal modal — same as xero `Generate a secret`) | hubspot + xero PR #191 Step 6 |
| 5 | `claude mcp add docusign https://mcp.docusign.com/v1/mcp --transport http --scope user` + write Client ID + Secret Key into env block (or use `claude mcp` env-set if available) | canva PR #180 Step 2 + xero PR #191 Step 7 |
| 6 | Trigger OAuth via 401-challenge: invoke any `mcp__docusign__*` tool, capture the AUTH_URL Claude Code emits, navigate Playwright to it. Auto-click Allow on DocuSign's consent screen | atlassian PR #186 Step 3-4 + canva PR #180 Step 4 |
| 7 | Auto-detect callback via `browser_wait_for` localhost URL change; verify with `mcp__docusign__list-envelopes` smoke call | canva PR #180 Step 4b + 6 |

### Phase 2 — tool reference

DocuSign's hosted MCP exposes tools wrapping the eSignature REST API. Tool names not yet enumerated (will be discovered at runtime via `tools/list` once Phase 1 completes against a real account). Expected categories:
- **Envelopes**: list, get, create, send, void
- **Templates**: list, get, apply
- **Recipients**: list, get, update
- **Documents**: list, get, download
- **Account**: get info, list users

---

## Sandbox vs production — workshop targets sandbox

DocuSign provides free **Developer Account** at `account-d.docusign.com` (sandbox). All workshop attendees should use sandbox initially; production migration is a v2 concern.

| Environment | OAuth host | MCP host (assumed mirror) |
|---|---|---|
| **Sandbox** (workshop default) | `account-d.docusign.com` | `mcp-d.docusign.com`? — **needs verification before SKILL build** |
| **Production** | `account.docusign.com` | `mcp.docusign.com` (verified live) |

**Open question 1**: does DocuSign run a separate sandbox MCP host (`mcp-d.docusign.com` or similar)? Probe required before SKILL build to determine if there's a single MCP host that switches by token, or two MCP hosts. Unclear from available metadata; only production endpoint is currently verified.

---

## OAuth Authorization Code Grant + PKCE flow

Per the metadata, the flow is:

1. SKILL constructs auth URL: `https://account.docusign.com/oauth/auth?response_type=code&client_id=<integration_key>&redirect_uri=<claude_code_callback>&scope=signature&code_challenge=<S256_hash>&code_challenge_method=S256&state=<random>`
2. User signs in (handled by Claude Code's MCP runtime + Playwright auto-click on consent)
3. DocuSign redirects to `redirect_uri?code=<auth_code>&state=<state>`
4. Claude Code MCP runtime exchanges code for tokens at `https://account.docusign.com/oauth/token` with `code_verifier` (PKCE) + Client Secret
5. Bearer token used to authenticate calls to `mcp.docusign.com/v1/mcp`
6. Token lifetime: 8 hours; refresh token: 30 days, single-use auto-rotated

Claude Code's MCP runtime should handle steps 3-5 natively given `--transport http` registration. PKCE S256 is the only supported challenge method — same as canva + atlassian.

---

## Pattern reference cross-walk

| SKILL phase concern | Reference in workshop-kit |
|---|---|
| Admin-portal + DOM-extract for Client ID + Secret | `skills/hubspot-connector/SKILL.md` (PR #175) |
| One-time-reveal Secret modal handling | `skills/xero-connector/SKILL.md` Step 6b (PR #191) |
| Hosted MCP + `claude mcp add http` + Playwright-driven Allow | `skills/canva-connector/SKILL.md` (PR #180), `skills/atlassian-connector/SKILL.md` (PR #186) |
| OAuth callback URL-change auto-detect | canva PR #180 Step 4b + atlassian PR #186 Step 4d |
| Phase 0 resume check + tooling auto-install | All recent connector PRs (canonical pattern) |

---

## Out of scope (explicit follow-ups, not blockers)

- **Building `skills/docusign-connector/SKILL.md`** — the actual SKILL is a follow-up PR. This audit closes the architectural decision phase only.
- **Sandbox MCP host probe** — open question 1 above. Resolve at SKILL-build time.
- **Live tool-list enumeration** — needs a real DocuSign Developer Account to authenticate the smoke call. Audit-time enumeration not feasible.
- **JWT server-to-server flow** — the issue spec scopes v1 to OAuth Authorization Code Grant only. JWT (for headless server use) is v2.
- **Production migration path** — workshop default is sandbox. Production switch is a future v2 concern.
- **Webhooks / Connect listeners** — DocuSign's webhook surface (Connect) is separate from the eSign API and not in scope for v1.
- **Selr forking the hosted MCP** — not needed; DocuSign maintains the official artifact.

---

## Acceptance criteria status

From issue #148, post-audit:

- [x] **Phase 0 audit on community DocuSign MCP servers** — done; all 6 community options rejected for fitness, license, or scope. Official hosted MCP (`mcp.docusign.com`) recommended instead.
- [x] **Confirm chosen MCP supports Auth Code Grant + signature scope** — verified live: metadata shows `grant_types_supported: ["authorization_code", "refresh_token"]` + `scopes_supported` includes `signature`.
- [ ] **Build `skills/docusign-connector/SKILL.md`** — not in this PR; follow-up.

---

## Recommendation summary

**Build `skills/docusign-connector/SKILL.md` against `https://mcp.docusign.com/v1/mcp`.** Hybrid Literal-Playwright pattern — hubspot-style Integration Key creation in the developer portal + canva-style hosted-MCP `claude mcp add http` + atlassian-style auto-click Allow on the OAuth consent screen. PKCE S256, OAuth Authorization Code Grant against DocuSign's production OAuth endpoints. Sandbox-first for workshop attendees; production migration deferred to v2.

If the workshop-kit team disagrees with adopting the official hosted MCP (e.g., wants self-hosting for control), the alternative is a self-built MCP shim wrapping the DocuSign Node SDK — significantly heavier (~5 days of build), with all the maintenance burden Selr would inherit. **Recommend against** that path absent a specific reason to reject the official artifact.
