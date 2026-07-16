# Facebook Page Connector - Phase 0 audit

**Source.** Issue [#153](https://github.com/selrai-company/claude-workshop-kit/issues/153) - split-out from [#151](https://github.com/selrai-company/claude-workshop-kit/issues/151) (Meta Business Suite). PR [#152](https://github.com/selrai-company/claude-workshop-kit/pull/152) shipped the Instagram + Threads slice via `@mikusnuz/meta-mcp`; this audit closes the **Facebook Page organic posting** gap that PR explicitly excluded.

**Audit date:** 2026-05-01.

**Audit scope.** Identify the strongest candidate MCP server for Facebook Page organic posting (text + image + video + link), recommend a path forward (build, defer, or change shape), and produce enough evidence for the next person to pick up the SKILL build with the decision pre-locked.

---

## TL;DR

**Winner: [`HagaiHen/facebook-mcp-server`](https://github.com/HagaiHen/facebook-mcp-server)** - 148 stars, MIT, last pushed 2026-04-23, **40 tools** covering posting (text + image), scheduling, comments (read / reply / hide / unhide / delete / bulk), insights (impressions / engagement / clicks / share count), per-reaction-type counts (like / love / wow / haha / sorry / anger), DMs, and page info. Auth model is **`FACEBOOK_ACCESS_TOKEN` + `FACEBOOK_PAGE_ID` in env vars** - same Page Access Token shape Phase 1 of `meta-business-suite-connector` already mints via Graph API Explorer.

**Caveat.** It is **Python-only** (installed via `uv pip install -r requirements.txt`), not npm-published. Wiring it into the workshop-kit means **introducing the first Python-MCP-server install path in the workshop-kit's connector inventory.** This is a precedent shift, not a blocker - the install adds ~1 minute to Phase 0 (`curl -LsSf https://astral.sh/uv/install.sh | sh`) and the SKILL can wrap the rest autonomously. The Page Access Token + Page ID auth model maps cleanly onto Claude Code's `~/.claude.json` `env` block once `uvx` is present.

**Recommendation.** Build `skills/facebook-page-connector/` against HagaiHen's server. Add a Phase 0 prerequisite check that auto-installs `uv` if missing, mirroring the way `whatsapp-connector` Phase 0 auto-installs Bun if missing. Do not adopt `@supercorp/facebook-mcp` - its 2-tool surface is materially insufficient for the "ads + posting" framing, and its install model (Meta Developer App + Redirect URI + Upstash Redis) is heavier than HagaiHen's despite being npm-published.

---

## Candidates examined

| Candidate | Source | Status |
|---|---|---|
| `@builderhub/mcp-facebook` | npm (per #153 spec) | ❌ **Does not exist on npm** - `npm view` returns 404. Audit-author had this as a candidate from the issue body; it was likely a placeholder that never got published. |
| `@supercorp/facebook-mcp` | npm + [supercorp-ai/facebook-mcp](https://github.com/supercorp-ai/facebook-mcp) | ⚠️ **Exists but unfit** - see detail below |
| `@pullapi/facebook-scraper-mcp` | npm + [basitmakine/pullapi/.../facebook](https://github.com/basitmakine/pullapi/tree/master/mcp/packages/facebook) | ❌ **Wrong tool** - keywords explicitly say "scraper / Marketplace search". Read-only, doesn't post |
| **`HagaiHen/facebook-mcp-server`** | [GitHub Python](https://github.com/HagaiHen/facebook-mcp-server) (MIT) | ✅ **Recommended winner** |
| `gomarble-ai/facebook-ads-mcp-server` | GitHub Python (316 ⭐) | ❌ **Ads-only**, not organic posting |
| `proxy-intell/facebook-ads-library-mcp` | GitHub Python (206 ⭐) | ❌ **Ads library research only**, no posting |
| `tiroshanm/facebook-mcp-server` | GitHub Python (71 ⭐) | ❌ **Unmaintained** (last push 2025-04-14, ~1 year stale) |
| `RamsesAguirre777/facebook-ads-library-mcp` | GitHub Python (31 ⭐) | ❌ **Ads library**, not posting |
| `Tisik79/MCP-Facebook` | GitHub TS (12 ⭐) | ❌ **Czech docs, ads-focused** |
| `jdcodes1/facebook-marketplace-mcp` | GitHub TS (12 ⭐) | ❌ **Marketplace search via Chrome cookies**, not posting |
| `codprocess/facebook-ads-mcp` | GitHub JS (6 ⭐) | ❌ **Ads-only** |
| `Livia-Zaharia/just_facebook_mcp` | GitHub Python (5 ⭐) | ❌ **Same description as HagaiHen** - likely a fork |
| `MarecoX/mcp-facebook-insights` | GitHub JS (4 ⭐) | ❌ **Marketing Insights API only**, Portuguese docs |

**Search methodology.** `npm search facebook-page-mcp / facebook-mcp-server / fb-page-mcp / meta-page-mcp / graph-api-mcp` (npm registry), `gh api /search/repositories?q=facebook+mcp+in:name&sort=stars` (GitHub top 10 by stars). All ad-focused, marketplace-scraper, or unmaintained candidates excluded since the issue spec is **Facebook Page organic posting**.

---

## Comparison matrix - top 2 viable candidates

| Criterion | `@supercorp/facebook-mcp` | `HagaiHen/facebook-mcp-server` |
|---|---|---|
| **npm-installable** | ✅ Yes (`@supercorp/facebook-mcp@1.9.2`) | ❌ Python only (`uv pip install`) |
| **License** | ISC (npm) | MIT |
| **GitHub stars** | 2 | **148** |
| **GitHub forks** | 1 | **45** |
| **Last activity** | 2025-10-17 (~6 months stale) | **2026-04-23 (last week)** |
| **Repo created** | 2025-03-27 | 2025-05-08 |
| **npm downloads (30d)** | 31 | n/a (not on npm) |
| **MCP tool count** | 2 | **40** |
| **Tool surface** | List pages + post to a page | Post (text + image), schedule, reply, comments (read/hide/unhide/delete/bulk), insights (impressions/engagement/clicks/reactions/share), DMs, page info |
| **Auth model** | Meta Developer App: App ID + App Secret + Redirect URI + Upstash Redis token store | **`FACEBOOK_ACCESS_TOKEN` + `FACEBOOK_PAGE_ID` env vars** (long-lived Page Access Token) |
| **OAuth flow at install** | Yes - full OAuth 2 with redirect URI | No - token minted once via Graph API Explorer |
| **External dependencies at runtime** | Upstash Redis (token store) OR memory-with-storage-key | None beyond Python deps |
| **Match with `@mikusnuz/meta-mcp` install pattern** | Different model (App-based OAuth) | **Same model (Page Access Token)** |
| **Workshop install ergonomics** | Heavy - attendee creates Meta Developer App + redirect URI + (optionally) provisions Redis | Light - attendee already has Page Access Token from `meta-business-suite-connector` work; install Python via uv |

---

## Detail per candidate

### `HagaiHen/facebook-mcp-server` - **RECOMMENDED**

**What it is.** A Python MCP server (FastMCP-based) wrapping the Facebook Graph API for a single Facebook Page. Uses long-lived Page Access Tokens.

**Tool inventory** (verified by counting `@mcp.tool` decorators in upstream `server.py` at HEAD `61b21285`, dated 2026-04-23, snapshot date 2026-05-04 - **40 tools**. The upstream README lists 34, but `server.py` exposes 6 additional tools beyond the README. **Re-verify if upstream HEAD is later than `61b21285` at SKILL build time** - tool count may drift):

```
post_to_facebook
post_image_to_facebook
schedule_post
update_post
get_scheduled_posts
get_page_posts
get_post_permalink
delete_post

reply_to_comment
get_post_comments
get_comment_replies
get_number_of_comments
get_post_top_commenters
filter_negative_comments

delete_comment
hide_comment
unhide_comment
delete_comment_from_post
bulk_delete_comments
bulk_hide_comments
bulk_unhide_comments

get_number_of_likes
get_post_insights
get_post_impressions
get_post_impressions_unique
get_post_impressions_paid
get_post_impressions_organic
get_post_engaged_users
get_post_clicks
get_post_reactions_like_total
get_post_reactions_love_total
get_post_reactions_wow_total
get_post_reactions_haha_total
get_post_reactions_sorry_total
get_post_reactions_anger_total
get_post_reactions_breakdown
get_post_share_count

send_dm_to_user
get_page_fan_count
get_page_info
```

(Tools listed in `server.py` but absent from the README: `get_post_insights` plus the 5 per-reaction-type counts `love/wow/haha/sorry/anger` - only `like` is in the README. Source-of-truth for the SKILL build is `server.py`'s `@mcp.tool` decorators, not the README.)

**Auth requirements** (verbatim from upstream README):

- `FACEBOOK_ACCESS_TOKEN` - page access token from [Graph API Explorer](https://developers.facebook.com/tools/explorer)
- `FACEBOOK_PAGE_ID` - the Page's ID

Stored in a `.env` file in HagaiHen's repo, but the workshop-kit pattern would put them in `~/.claude.json` `mcpServers.facebook-page.env` instead - same as `meta-business-suite-connector`'s INSTAGRAM_ACCESS_TOKEN/INSTAGRAM_USER_ID pair.

**Install path (upstream)**: `uv pip install -r requirements.txt`. The naive `uvx --from git+...` invocation **does not work** for this repo - verified live: HagaiHen has only `README.md` + `requirements.txt` + 4 `.py` files at root, **no `pyproject.toml` / `setup.py` / `setup.cfg`**. Without Python package metadata, `uvx --from` cannot resolve a buildable entrypoint. The workshop-kit-friendly form is **clone-and-run**: `git clone` to a stable path, install deps via `uv pip install -r requirements.txt` into a managed venv, then invoke `python server.py` with the env vars in scope. Phase 0 of the SKILL handles the clone + venv creation idempotently.

**What's NOT covered** (gaps to surface in the SKILL):
- **Video posting**: HagaiHen's `post_image_to_facebook` covers images only. Video posts would need either an upstream PR or a separate Graph API helper. Document as a known limitation.
- **Link previews**: Not in the listed tools. Plain text posts include URLs that Facebook will preview, but no explicit `post_link` tool.
- **Multi-page**: One Page per env-var pair. Multi-Page setups need multiple connector entries (acceptable for v1).

### `@supercorp/facebook-mcp` - Considered, rejected

**Why npm-installability isn't enough.** Empirical smoke test (2026-05-01, fake creds):

- Spawn requires `--facebookAppId`, `--facebookAppSecret`, `--facebookRedirectUri` CLI args. Without these, exits code 1 with `Missing required arguments` error.
- With those provided, requires `--storage` mode (memory or upstash-redis-rest) and a `--storageHeaderKey` for the in-memory or Redis-backed token store.
- This is a full OAuth 2.0 server architecture: workshop attendees would need to (1) create a Meta Developer App, (2) generate App ID + App Secret, (3) configure a redirect URI, (4) either provision Upstash Redis or run with in-memory storage that loses tokens between restarts.

**What it actually exposes** (from the package description; tool list not verified live since the install model fails the workshop-friendliness gate before tool surface matters): "list pages and post to a page" - 2 tools, materially below the "ads + posting" framing.

**Adoption signal**: 2 stars, 1 fork, 31 npm downloads/month. Single-author project (`nedomas` / Domas Bitvinskas). 6 months since last commit.

### `@builderhub/mcp-facebook` - Considered, doesn't exist

`npm view @builderhub/mcp-facebook` returns 404 Not Found. The package was listed in the `#153` issue body's candidate table but was never published. Audit eliminates it.

### `@pullapi/facebook-scraper-mcp` - Considered, wrong tool

Keywords on the npm package include `scraper`, `marketplace`, `facebook-pages` (read), `facebook-posts` (read). Description: "Facebook MCP server - pages, profiles, posts & Marketplace search. For Claude, Cursor & AI agents." This is a read-only research tool, not a publishing surface. Excluded.

### Ad-focused alternatives - out of scope

`gomarble-ai/facebook-ads-mcp-server` (316 ⭐), `proxy-intell/facebook-ads-library-mcp` (206 ⭐), and similar are **Meta Ads servers, not organic posting**. Luke's `lukeselr/meta-ads-mcp-setup` already owns the ads lane. None of these fill the FB Page organic posting gap.

---

## Recommendation - three-question framework

### 1. Should the workshop-kit ship a Facebook Page connector at all?

**Yes.** The 2026-04-26 connector directive named "Meta Business Suite | ads + posting"; PR #152 explicitly carved out only the IG/Threads slice. The Facebook Page slice is real outstanding work and is currently a gap.

### 2. Which candidate should the SKILL wrap?

**`HagaiHen/facebook-mcp-server`.** It is the only candidate that pairs (a) a non-trivial tool surface - 40 tools - with (b) a sane auth model - long-lived Page Access Token + Page ID env vars - and (c) recent maintenance - last commit 2026-04-23. Adoption signal (148 ⭐) corroborates real-world use.

The npm-installability gap is real but solvable in the SKILL's Phase 0:

```bash
# Phase 0 - install uv if missing (one-line, no admin)
which uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
```

The workshop-kit already has connectors that auto-install platform-specific tooling (whatsapp-connector auto-installs Bun if missing per `whatsapp-connector/SKILL.md` Phase 0). Adding `uv` follows the same shape, only on a different ecosystem.

### 3. What's the Phase 1 install pattern?

The canonical autonomous-Playwright pattern from the Literal-Playwright sub-method (see `feedback_autonomous_connector_pattern.md`) applies, mirroring `meta-business-suite-connector`:

1. **Safety gate** - ask the user which Facebook Page they want to connect; confirm they own the Page (admin role, not just a viewer).
2. **Phase 0** - auto-install `uv` if missing. Pre-flight check that `~/.claude.json` doesn't already have a `facebook-page` entry; resume-check if it does.
3. **Phase 1 Step 1** - Orient ("opening Meta's Graph API Explorer for you").
4. **Phase 1 Step 2** - Drive Playwright to `developers.facebook.com/tools/explorer`. Detect login state. Prompt sign-in if needed (the only manual moment).
5. **Phase 1 Step 3** - Auto-fill the Graph API Explorer form: select the user's Meta App (or create one if missing - same shape as `meta-business-suite-connector`), tick the required permission scopes (`pages_show_list`, `pages_read_engagement`, `pages_manage_posts`, `pages_manage_engagement`, `pages_messaging`, `read_insights`), click **Generate Access Token**, accept the OAuth dialog autonomously.
6. **Phase 1 Step 4** - Auto-extract the short-lived Page Access Token from the DOM. Exchange it for a long-lived Page Access Token via `curl https://graph.facebook.com/v21.0/oauth/access_token?grant_type=fb_exchange_token...` (60-day token, then renew indefinitely).
7. **Phase 1 Step 5** - Auto-resolve the Page ID via `GET /me/accounts?fields=id,name,access_token` - the user picks the Page if multi-Page, narrate-and-pick if single-Page.
8. **Phase 1 Step 6** - Register via `claude mcp add facebook-page --scope user --env FACEBOOK_ACCESS_TOKEN="$TOK" --env FACEBOOK_PAGE_ID="$PID" -- python <CLONE_PATH>/server.py`. **`<CLONE_PATH>` per platform**: `~/.loup/selr-ai/workshop-kit/connectors/facebook-mcp-server/` on macOS / Linux / Git-Bash / WSL (matches existing zip-install path per `project_workshop_kit_zip_install_2026_05_01.md`); `%USERPROFILE%\.loup\selr-ai\workshop-kit\connectors\facebook-mcp-server\` on **Windows native PowerShell**. **Critical for Windows attendees**: when the SKILL writes `<CLONE_PATH>` into Claude Desktop's MCP config or `~/.claude.json`, the path must be FULLY RESOLVED at write time - `~` is NOT expanded inside JSON literals by Claude Desktop's MCP launcher (only PowerShell's path provider expands `~`, and only for cmdlets that go through it). Use Node's `os.homedir()` / Python's `Path.home()` / Bash's `$HOME` substitution at SKILL-runtime to produce an absolute path before writing to config. Avoid `~/.local/share/...` (XDG Base Dir spec is Linux/macOS-only - Windows attendees end up with a literal `.local\share\` folder that doesn't honour Windows conventions). Pin to a specific upstream SHA at clone time (HEAD `61b21285` as of 2026-05-04) so downstream `tools/list` count is reproducible. The `uvx --from git+...` shape **does not work** because the upstream repo has no `pyproject.toml`/`setup.py`/`setup.cfg` (verified live 2026-05-04). JSON merge fallback for older Claude Code.
9. **Phase 1 Step 7** - Smoke-verify with `mcp__facebook_page__get_page_info`. Surface the Page name in the success message.

The token-extraction pattern + curl-based long-lived exchange is identical to PR #152's `meta-business-suite-connector`'s Step 4-7. The SKILL author can lift those steps directly.

---

## Open questions / forward-looking

### Q1. ANSWERED - `uvx --from git+...` does NOT work for HagaiHen

Verified live 2026-05-04 against `https://api.github.com/repos/HagaiHen/facebook-mcp-server/contents/`. Root contents:

```text
.gitignore (22 bytes)
LICENSE (1066 bytes)
README.md (6547 bytes)
config.py (278 bytes)
facebook_api.py (4162 bytes)
manager.py (7470 bytes)
requirements.txt (27 bytes)
server.py (9331 bytes)
```

**No `pyproject.toml`. No `setup.py`. No `setup.cfg`.** Without Python package metadata, `uvx --from` cannot resolve a buildable project. The naive invocation pattern that the original audit's Phase 1 Step 6 sketch used **will not work as written**.

Three viable alternatives, in order of workshop-friendliness:

1. **Clone + python server.py** (recommended). Phase 0 of the SKILL clones to a per-platform absolute path (`$HOME/.loup/selr-ai/workshop-kit/connectors/facebook-mcp-server/` on macOS/Linux/WSL, `%USERPROFILE%\.loup\selr-ai\workshop-kit\connectors\facebook-mcp-server\` on Windows native), runs `uv pip install -r requirements.txt` to populate a managed venv, then writes the FULLY-RESOLVED clone path (no `~` literal) into the `claude mcp add facebook-page ... -- python <abs-clone>/server.py` invocation. Idempotent (skip clone if dir exists; pull latest on rerun if user opts in). Pin to a specific commit SHA so the downstream tool count is reproducible (HEAD `61b21285` at 2026-05-04 had 40 `@mcp.tool` decorators).
2. **`uv run --with-requirements` with absolute path**. Once cloned, `uv run --with-requirements <clone>/requirements.txt python <clone>/server.py`. Avoids managing a separate venv but requires `uv` ≥ 0.4.x for `--with-requirements`.
3. **Selr-published npm/pypi wrapper**. Selr forks HagaiHen, adds `pyproject.toml`, publishes to pypi as `selr-facebook-mcp` (or similar), then `uvx --from selr-facebook-mcp` works. Heavier maintenance burden (Q4 below).

Recommend **path 1** for v1 - simplest, no fork, fully workshop-friendly with `uv` as a Phase 0 prereq. Path 3 is the cleanest long-term but adds Selr maintenance load that isn't justified yet.

### Q2. Long-lived Page Access Token expiry

Page Access Tokens minted via Graph API Explorer with `fb_exchange_token` are typically **non-expiring (Page tokens, unlike user tokens)**. This is a meaningful UX advantage over IG, where tokens last 60 days and need refresh. The SKILL should document this - once connected, the Page connector should keep working until the user revokes the token or the Meta App is deleted.

### Q3. Video upload coverage

HagaiHen has `post_image_to_facebook` but no documented `post_video`. Two paths:
- **Upstream PR**: contribute a `post_video_to_facebook` tool to HagaiHen - uses Graph API `POST /<page>/videos` resumable-upload protocol.
- **Workshop deferral**: ship v1 with text + image only, document video as a known gap, file follow-up issue.

Recommend the workshop deferral path for v1; add video in v2 once base flow is stable.

### Q4. Should Selr fork HagaiHen?

Forking would let Selr publish an npm wrapper (e.g. `@selrai/facebook-page-mcp`) that bundles HagaiHen's Python via `uvx` internally, restoring the npm-only install model.

**Pros**: keeps workshop-kit npm-only convention; Selr controls maintenance cadence.
**Cons**: ongoing Selr maintenance burden; risk of falling behind upstream; HagaiHen is MIT-licensed so fork is fine but partnership-and-credit etiquette matters.

**Recommendation: do not fork in v1.** Document upstream attribution in the SKILL.md, contribute back via PRs if useful, revisit forking only if HagaiHen goes unmaintained or if the workshop-kit decides to consolidate Python tooling under a Selr namespace anyway.

### Q5. Live-QA before merge

Per `feedback_live_qa_workflow_every_skill.md`: this connector - like every other Phase 1 reworked under the autonomous-Playwright pattern - needs end-to-end live-QA against a real Facebook Page before merge. Selr's QA constraint:

- A real **Facebook Page** the user has admin access to
- A real Meta Developer App with `pages_*` permission scopes approved (some need App Review for production)
- Long-lived Page Access Token minting via Graph API Explorer

The first two are pre-existing Meta-app artefacts from PR #152's QA pass. Should be reusable.

---

## Out of scope

- **Building the SKILL itself.** This audit closes Phase 0; the SKILL build is a follow-up PR.
- **Live-MCP smoke test of HagaiHen's tool surface.** The 40-tool count comes from counting `@mcp.tool` decorators in upstream `server.py`. A live MCP-protocol handshake (init + tools/list) against a running instance is more efficient to run during the SKILL build phase against a real Page; the static decorator count is the audit-time evidence.
- **App Review / approved permission scopes.** Meta requires App Review for `pages_manage_posts`, `pages_manage_engagement`, `pages_messaging` in production. Workshop attendees in development mode can use the same Meta App they used for `meta-business-suite-connector` (already approved or in-dev). Document the App Review path in the SKILL Phase 0 for non-developer-mode usage.
- **Other Facebook surfaces** - Messenger Platform, Marketplace, Groups - out of scope. This audit is Page organic posting only.

---

## Acceptance criteria status

From issue #153 acceptance criteria, post-audit:

- [x] **Phase 0 audit on @builderhub/mcp-facebook, @supercorp/facebook-mcp, and one alternative** - done, plus 10 GitHub-search alternatives swept. `@builderhub` doesn't exist; `@supercorp` rejected for thin tool surface + heavy install; `HagaiHen` recommended.
- [x] **Confirm chosen MCP can publish text + image + video + link posts** - partial: text + image confirmed via tool list. Video deferred to v2 (Q3 above). Link posts work via text content.
- [ ] **Build `skills/facebook-page-connector/`** - not in this PR; follow-up SKILL build.

---

## Recommendation summary

**Build `skills/facebook-page-connector/` against `HagaiHen/facebook-mcp-server`.** Adopt a Phase 0 prerequisite that auto-installs `uv` if missing. Mirror `meta-business-suite-connector`'s Phase 1 token-mint pattern for the Page Access Token + Page ID extraction. Defer video posting to v2. Live-QA against the Meta App already approved for `meta-business-suite-connector`.

If the workshop-kit team rejects introducing a Python-MCP install path, the alternative is **defer the connector** and revisit when an npm-installable best-in-class FB Page MCP emerges. `@supercorp/facebook-mcp` is not a viable fallback - its 2-tool surface is materially insufficient for the framed use case.
