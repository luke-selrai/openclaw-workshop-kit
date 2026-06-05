# Connector SKILLs — install patterns reference

This is the canonical reference for the three install patterns the `*-connector`
SKILLs in this directory have converged on. If you are authoring or reviewing a
new connector, start here, then read the per-pattern reference SKILL it points
to.

If a connector does not fit one of the three patterns below
(CLI-based: `gws`, `gh`, `qbo`, `notion` (`ntn`); direct REST: `ghl`, `myob`; first-party stdio:
`hubspot`, `paypal`, `slack`, `square`, `stripe`, `shopify`, `xero`,
`voice-transcription`, `whatsapp`, `wordpress`), it has its own shape and is
out of scope for this doc — see the SKILL itself.

## Which pattern do I use?

```
Is there an official Claude Code plugin in the marketplace?
├── yes → Pattern 3: Plugin-marketplace        (reference: telegram-connector)
└── no
    └── Is the SaaS server hosted (the vendor publishes an MCP URL)?
        ├── yes
        │   └── Does the auth flow use OAuth (consent screen)?
        │       ├── yes → Pattern 1: Hosted-OAuth          (reference: linear-connector)
        │       └── no  → Pattern 2: Hosted-bearer-PAT     (reference: monday-connector)
        └── no  → out of scope; see the per-connector SKILL
```

If both an OAuth flow and a Personal Access Token surface exist for the same
vendor, prefer Pattern 1 (Hosted-OAuth) and keep the PAT as a fallback inside
that SKILL. `linear-connector` does this — see Step 3B there.

## Cross-cutting: Phase 0 resume-check

Every connector SKILL begins with the same Phase 0 check: "is this already
installed?" The shape is identical across all 11 SKILLs and lives once here so
new connectors do not re-derive it.

Read `~/.claude.json`, look for a `mcpServers.<service>` entry, and decide:

- **Found** → skip Phase 1 entirely, run a single smoke tool call to verify the
  connection still works, report success.
- **Not found** → run Phase 1.

The exact "is it configured?" predicate varies by pattern:

| Pattern | What "configured" looks like in `~/.claude.json` |
|---|---|
| Hosted-OAuth | `mcpServers.<service>` entry with `type: "http"` (token is stored by the MCP runtime, not in this file) |
| Hosted-bearer-PAT | `mcpServers.<service>` entry with `headers.Authorization` (HTTP) **or** `env.<TOKEN>` (local npx) |
| Plugin-marketplace | Skill presence (e.g. `Telegram:configure`), tool presence (`mcp__plugin_<service>_*`), or `claude plugin list \| grep <name>@claude-plugins-official` — there is no `mcpServers` entry for plugins |

For the plugin-marketplace pattern specifically, also check that the plugin's
own state files (e.g. `~/.claude/plugins/telegram-connector/access.json`)
exist and are populated before declaring the connector "ready".

## Cross-cutting: Playwright MCP install contingency

Patterns 1 and 2 both drive a browser via the Playwright MCP server. If the
SKILL author can't reach `mcp__playwright__*` or
`mcp__plugin_playwright_playwright__*` tools, install Playwright first:

```bash
claude mcp add playwright --scope user -- npx -y @playwright/mcp@latest --user-data-dir "$HOME/.cache/playwright-mcp-profile"
```

The `--user-data-dir` flag is mandatory — it gives the Playwright browser a
persistent profile so user logins survive across sessions. Workshop attendees
should never have to re-login to the same site twice; that friction is one of
the top complaints when Playwright MCP is installed without it.

After install, ask the user to close and reopen Claude Code once so the new
MCP surface reconciles, then retry. This is identical across hosted-OAuth and
hosted-bearer-PAT and lives once here.

Pattern 3 (plugin-marketplace) does not need Playwright unless the plugin
itself uses it (e.g. `telegram-connector` drives Telegram Web through it).

---

## Pattern 1 — Hosted-OAuth

**Reference SKILL:** [linear-connector](linear-connector/SKILL.md) — uses this
pattern in its post-#198 form, plus a Personal API key fallback in Step 3B.

**Other SKILLs on this pattern:** [atlassian-connector](atlassian-connector/SKILL.md),
[calendly-connector](calendly-connector/SKILL.md),
[canva-connector](canva-connector/SKILL.md),
[jotform-connector](jotform-connector/SKILL.md).

**When it fits:** the vendor publishes a hosted MCP URL (e.g. `https://mcp.linear.app/mcp`)
and authentication is OAuth — the user sees a consent screen.

**Registration command:**

```bash
claude mcp add <server> <url> --transport http --scope user
```

**Tool-pair contract.** After registration and a Claude Code reconciliation,
two tools appear in the deferred-tool surface:

- `mcp__<server>__authenticate()` — returns the OAuth start URL.
- `mcp__<server>__complete_authentication({ callback_url })` — submits the
  post-redirect URL captured from the browser.

These are runtime artifacts produced by Claude Code from the server's
well-known OAuth metadata — there is no `claude mcp authenticate` CLI verb
(see [#200](https://github.com/selrai-company/claude-workshop-kit/issues/200)
and the `audit-skills.mjs` anti-pattern guard).

**Deferred-tool reconciliation timing.** The `authenticate` /
`complete_authentication` pair only appears after the runtime has reconciled
the new server. If the tools are not visible immediately after `claude mcp
add`, ask the user to close and reopen Claude Code once, then retry. Do not
proceed by guessing the OAuth URL — that defeats the contract.

**Playwright redirect-and-capture sub-flow:**

1. Call `mcp__<server>__authenticate()` and open the returned URL inside the
   Playwright MCP browser.
2. Snapshot to detect login state. If the user is signed out, narrate ("sign
   in to <service>") and `browser_wait_for` the consent screen.
3. Auto-click **Allow** (or its vendor-specific equivalent — "Authorize",
   "Approve").
4. Wait for the redirect to a `localhost` / `127.0.0.1` callback URL.
5. Capture `window.location.href` via `browser_evaluate` **before** the tab
   closes.
6. Pass that URL to `mcp__<server>__complete_authentication({ callback_url })`.
7. Close the browser and verify with one `mcp__<server>__*` smoke call.

**Resume / re-auth on token expiry.** If a smoke call fails with an auth
error, re-run the `authenticate` / `complete_authentication` pair — do not
re-register the server. The MCP runtime owns token storage; the SKILL never
reads or writes it directly.

**Common branches** (vendor-specific; document inside the SKILL, not here):

- Workspace picker after consent (`atlassian-connector` Step 4a).
- Admin-block / no-access interstitial (`atlassian-connector`, `canva-connector`).
- Personal API key fallback when OAuth is admin-blocked (`linear-connector`
  Step 3B — drives the SaaS settings page, captures the key from the DOM,
  re-registers the entry with an `Authorization: Bearer` header).

---

## Pattern 2 — Hosted-bearer-PAT

**Reference SKILL:** [monday-connector](monday-connector/SKILL.md) — cleanest
deep-link-based token capture flow.

**Other SKILLs on this pattern:** [airtable-connector](airtable-connector/SKILL.md),
[github-connector](github-connector/SKILL.md).

**When it fits:** the vendor publishes a hosted MCP URL (or a local stdio
server), and authentication is a Personal Access Token captured from a
settings page — there is no OAuth consent surface for this MCP.

**Registration command (HTTP hosted):**

```bash
claude mcp add <server> <url> --transport http \
  --header "Authorization: Bearer <token>" --scope user
```

**Registration command (local stdio):**

```bash
claude mcp add <server> --scope user -- npx -y <package> --env <SERVICE>_TOKEN="<token>"
```

`monday-connector` supports both shapes; the choice is vendor-driven.

**Playwright token-mint sub-flow:**

1. Navigate to the SaaS's "create token" deep link (e.g.
   `airtable.com/create/tokens`, the workspace `/admin/integrations/api`
   page on monday.com).
2. Snapshot to detect login state. If signed out, narrate and wait for the
   user to authenticate.
3. Walk the create-token UI: name the token, tick the required scopes, scope
   to "all bases / all data" (or vendor equivalent).
4. Click **Create**.
5. Read the freshly minted token from the DOM via `browser_evaluate` — match
   it with a regex sized to the vendor's token shape (e.g. `pat[A-Za-z0-9]+`
   for Airtable, JWT-shape for monday.com).
6. If the token is masked, click the reveal/show control first, re-snapshot,
   re-read.
7. Hand the token to `claude mcp add` with the appropriate header / env flag.
8. Close the browser and verify with one `mcp__<server>__*` smoke call.

**Token-permission scoping.** This is the bulk of each SKILL's value and is
vendor-specific — Airtable has four data + schema scopes, GitHub has
read-vs-write tiers, monday.com has optional `--read-only` /
`--enable-dynamic-api-tools` flags (mutually exclusive). Document the scope
choice inside the SKILL.

**Token-expiry / rotation.** Most providers do not expire PATs by default.
For those that do, surface the expiry choice during the mint walk and document
re-mint as the resume path (the SKILL re-runs Phase 1; the registration
command overwrites the prior entry).

**Conversational fallback.** Some vendors (notably GitHub) require the user
to copy a token from a notification dialog that the page does not expose to
the DOM. In that case, fall back to asking the user to paste the token; that
is a small leak (the token transits the transcript) and an accepted
trade-off — call it out in the SKILL.

**Direct-config fallback.** If `claude mcp add` fails for any reason, write
directly to `~/.claude.json`, merging into the `mcpServers` object:

```jsonc
// HTTP hosted
{ "type": "http", "url": "...", "headers": { "Authorization": "Bearer ..." } }

// Local stdio
{ "command": "npx", "args": [...], "env": { "<SERVICE>_TOKEN": "..." } }
```

---

## Pattern 3 — Plugin-marketplace

**Reference SKILL:** [telegram-connector](telegram-connector/SKILL.md) —
the canonical reference for this shape.

**Other SKILLs on this pattern:** [imessage-connector](imessage-connector/SKILL.md).

> `notion-connector` previously used this pattern (via the
> `notion@claude-plugins-official` plugin) but **moved to a CLI-based connector**
> (the official `ntn` CLI) so the OAuth token lives in the OS keychain rather
> than a Bearer header in `~/.claude.json`. See `notion-connector/SKILL.md` and
> the CLI-based list at the top of this doc.

**When it fits:** the vendor (or Anthropic) publishes an official Claude Code
plugin in `claude-plugins-official`. The plugin owns the OAuth handshake (or
local-permission grant) internally; the SKILL just orchestrates install +
permission prompts + verify.

**Install command:**

```bash
claude plugin install <name>@claude-plugins-official
```

**Verify install:**

```bash
claude plugin list | grep <name>@claude-plugins-official
```

Three signals to check, in order of strength:

1. **Skill presence** — e.g. `Telegram:configure`, `Telegram:access` appear in
   the available-skills list.
2. **Tool presence** — `mcp__plugin_<service>_*` tools appear in the deferred
   surface.
3. **Registry presence** — `claude plugin list` shows the
   `<name>@claude-plugins-official` line.

If the registry shows the plugin but the skills/tools are not visible, ask the
user to close and reopen Claude Code once so the surface reconciles. This is
the plugin equivalent of the deferred-tool reconciliation in Pattern 1.

**OAuth choreography (when the plugin uses it).** Some plugins launch OAuth
automatically the first time the user invokes one of the plugin's skills — the
SKILL does **not** call `authenticate` directly. The user signs in, picks a
workspace, clicks Allow; the plugin captures the callback. Subsequent
invocations reuse the stored token.

**Restart-the-chat semantics.** Plugin-installed skills and tools become
visible after the runtime reconciles. If the user invokes a `<plugin>:*` skill
that is not yet visible, treat that as the reconciliation contingency — close
and reopen, do not retry-loop.

**Re-auth path.** Re-running `claude plugin install <name>@claude-plugins-official`
re-triggers the plugin's OAuth flow. Use this on token expiry rather than
attempting to refresh the token from the SKILL.

**Plugin-managed state.** Some plugins maintain state files outside
`~/.claude.json`:

- `telegram-connector` writes `access.json` (allowlist) and `.env` (bot token,
  via clipboard transit so the token never lands in a tool return).
- `imessage-connector` reads `~/Library/Messages/chat.db` directly and replies
  via AppleScript — there is no token; the dependency is macOS Full Disk
  Access permission, granted via System Settings.

These are out-of-band from `claude plugin install`; the SKILL's Phase 1 must
walk the user through them.

---

## Token handling

| Pattern | Where the secret lives | Can it appear in a tool return? |
|---|---|---|
| Hosted-OAuth | MCP runtime token store (Claude Code internal) | No — never visible to the SKILL |
| Hosted-bearer-PAT | `mcpServers.<service>.headers.Authorization` in `~/.claude.json` | DOM read via `browser_evaluate` — must use clipboard-transit or careful regex extraction; never echoed back |
| Plugin-marketplace | Plugin-internal state (varies); for Telegram, `.env` / `access.json` written via clipboard-transit | No — same clipboard-transit rule when applicable |

Never echo a captured token in a narration line, a tool return value, or a
log file. The Pattern-2 reference SKILLs read the token, hand it to `claude
mcp add`, and discard it from the working set — copy that shape.

## Communication rules

These are identical across all 11 SKILLs and live in each SKILL's "Voice" or
"Communication" section. Restate the user-facing rules in your SKILL; do not
link out for them. Briefly: plain English, no jargon (`MCP`, `npx`, `bash`,
`JSON` are banned in user-facing text), narrate at action boundaries, never
echo credentials.

## See also

- [SKILLS-LIST.md](SKILLS-LIST.md) — the full skill index with tier and category.
- [linear-connector/SKILL.md](linear-connector/SKILL.md) — Pattern 1 reference.
- [monday-connector/SKILL.md](monday-connector/SKILL.md) — Pattern 2 reference.
- [telegram-connector/SKILL.md](telegram-connector/SKILL.md) — Pattern 3 reference.
- [#198](https://github.com/selrai-company/claude-workshop-kit/issues/198) — the Phase 1 Step 3 rewrite that grounded Pattern 1.
- [#199](https://github.com/selrai-company/claude-workshop-kit/issues/199) — this doc's tracking issue.
- [#200](https://github.com/selrai-company/claude-workshop-kit/issues/200) — anti-pattern audit guard for the deprecated `claude mcp authenticate` / `WWW-Authenticate: Bearer` claims.
