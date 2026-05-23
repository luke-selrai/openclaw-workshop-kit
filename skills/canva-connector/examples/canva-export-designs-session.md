# Worked example: connect Canva and export the last 5 designs as PNGs

A reference end-to-end session. Shows what a non-technical Canva user sees from a cold start. The transcript is presented as a normal Claude Code conversation: **You:** is what the user types, **Claude:** is what Claude renders back to the user. Internal tool calls are shown collapsed between the narration lines so the reader can see what Claude is doing under the hood without seeing raw JSON or stack traces.

The session takes about 90 seconds wall-clock on a machine that already has Claude Code and Playwright MCP installed. A first-ever install adds about 20 seconds for the MCP server registration.

---

## Cold start (Canva never connected before)

**You:**
connect my Canva and export the last 5 designs as PNGs

**Claude:**
Connecting your Canva first. This takes about a minute. I'll handle the setup. You'll just sign in to Canva when a browser window opens.

> [Phase 0 resume check] Reads `~/.claude.json`. No `mcpServers.canva` entry found. Routes to Phase 1.
>
> [Phase 0 tooling check] Confirms `mcp__plugin_playwright_playwright__*` tools are available in the deferred-tool surface.

> [Phase 1, Step 2] `claude mcp add canva https://mcp.canva.com/mcp --transport http --scope user` succeeds. The `mcpServers.canva` entry now lives in `~/.claude.json`.

**Claude:**
Canva is registered with Claude Code. Opening the sign-in page now.

> [Phase 1, Step 3] `mcp__canva__authenticate()` returns `https://mcp.canva.com/authorize?response_type=code&client_id=...&redirect_uri=...&state=...`.
> [Phase 1, Step 3] `mcp__plugin_playwright_playwright__browser_navigate({ url: <authorize_url> })` opens the page.

**Claude:**
A Canva sign-in page just opened in a controlled browser. Sign in there. I'll take it from there once you're in.

> User signs in to Canva inside the Playwright window. The page auto-redirects to the consent screen.

> [Phase 1, Step 4a] `browser_snapshot` detects the consent screen. Page shows: "Canva AI Connector is requesting access" with a 15-item permission list and an Allow button.

**Claude:**
You're signed in. Canva is asking permission for the Canva AI Connector to access your designs, assets, comments, folders, exports, and AI design generation. The consent screen lists about 15 permissions, which is the connector's full pre-registered scope set. The bearer token I get back is re-scoped to only the tools I actually invoke per request. Approving for you now.

> [Phase 1, Step 4a] `browser_click` on the Allow button.

> [Phase 1, Step 4b] `browser_wait_for` the redirect to a `localhost`/`127.0.0.1` callback URL. `browser_evaluate({ function: "() => window.location.href" })` captures the callback URL before the tab closes.

> [Phase 1, Step 4b] `mcp__canva__complete_authentication({ callback_url: <captured> })` succeeds. Token is now stored by the Claude Code MCP runtime.

> [Phase 1, Step 6] `mcp__plugin_playwright_playwright__browser_close()`. Verification smoke call: `mcp__canva__search_designs({ limit: 1 })` returns 200 OK.

**Claude:**
Canva is connected. The browser is closed. Now pulling your 5 most recent designs.

---

## Phase 2 begins

> [Phase 2] `mcp__canva__search_designs({ limit: 5, sort: "modified_at_desc" })` returns 5 design IDs and metadata.

**Claude:**
Here are your 5 most recent:

1. **Q2 Pitch Deck Refresh** (presentation, 24 pages, modified yesterday)
2. **Instagram - Workshop Sydney 20 May** (post, 1 page, modified yesterday)
3. **Brand Style Tile - Selr AI** (doc, 4 pages, modified 3 days ago)
4. **Landing Page Hero Test 7** (whiteboard, 1 page, modified 4 days ago)
5. **Onboarding Email - Skool Premium** (email, 1 page, modified 5 days ago)

I'll export each as PNG. Confirming first because exports use Canva credits on paid plans and may pull premium-element licences.

**You:**
go ahead

**Claude:**
> [Phase 2] For each design ID, two-step export flow:
> 1. `mcp__canva__get_design_export_formats({ design_id })` confirms `png` is available for that design type.
> 2. `mcp__canva__create_design_export_job({ design_id, format: { type: "png", dpi: 144 } })` returns a job_id.
> 3. Poll `mcp__canva__get_design_export_job({ job_id })` every 2 seconds. Status transitions: `in_progress` -> `success`. The final response carries an array of signed download URLs (one per page).

**Claude:**
Exports kicked off. Polling for completion. The Q2 Pitch Deck is the longest (24 pages); the others will finish faster.

> After ~30 seconds of polling, all 5 export jobs return `status: success`. The pitch deck export has 24 PNG URLs in the response, one per page. The other four have 1 PNG URL each.

**Claude:**
All 5 are ready. Total 28 PNGs (24 pages from the pitch deck plus 1 each from the other 4).

Download URLs are time-limited to 24 hours, so saving them locally now:

> [Phase 2] For each URL, `Bash: curl -s -o "<filename>" "<signed_url>"`.
> Filenames follow `<design-slug>-page<N>.png` pattern. Example: `q2-pitch-deck-refresh-page01.png` through `q2-pitch-deck-refresh-page24.png`, then `instagram-workshop-sydney-20-may.png`, `brand-style-tile-selr-ai-page01.png` ... `page04.png`, `landing-page-hero-test-7.png`, `onboarding-email-skool-premium.png`.

**Claude:**
Saved 28 PNG files to `./canva-export-2026-05-23/`. Largest is the pitch deck cover at 3.2 MB; smallest is the email header at 180 KB. Total 41 MB on disk.

The Instagram post is sized at 1080x1080 (Canva's default for the IG post template). If you need a different export size for any of them, say "re-export design 3 as 1920x1080" and I'll requeue with the right preset.

---

## Warm start (same flow with Canva already connected)

A second run, hours or days later, looks like this:

**You:**
export the last 3 Canva designs as PNGs

> [Phase 0 resume check] Reads `~/.claude.json`. Finds `mcpServers.canva` entry. Skips Phase 1 entirely.
> [Phase 0 smoke] `mcp__canva__search_designs({ limit: 1 })` returns 200 OK. Connection healthy.

**Claude:**
Canva is already connected. Pulling your 3 most recent.

> [Phase 2] `search_designs` -> `get_design_export_formats` -> `create_design_export_job` -> poll -> save.

**Claude:**
Done. 3 PNG files saved to `./canva-export-2026-05-23-warm/`.

Cold-to-warm timing: cold ~90s including OAuth, warm ~12s including the 5-page export.

---

## Failure branch: Enterprise workspace with admin allowlist blocking

If the user's Canva account belongs to an Enterprise workspace that has not allowlisted the Canva AI Connector app, Phase 1 surfaces the block cleanly rather than looping:

> [Phase 1, Step 5] `browser_snapshot` after the Allow click detects the Canva administrator-approval-required interstitial instead of the localhost callback redirect.

**Claude:**
Your Canva workspace is on an Enterprise plan that requires administrator approval before the Canva AI Connector can connect. The browser shows a "Request administrator access" screen. The fix is on your admin's side: they need to allowlist the Canva AI Connector app in your workspace settings. Once that's done, run this command again and the sign-in will go through.

No retry loop, no failed export, no half-applied configuration. The `mcpServers.canva` entry is removed so the next run starts cleanly.

---

## Re-auth branch: token expired weeks later

**You:**
export my latest design as PNG

> [Phase 0 resume check] Finds `mcpServers.canva` entry.
> [Phase 0 smoke] `mcp__canva__search_designs({ limit: 1 })` returns 401 Unauthorized.

**Claude:**
Your Canva connection expired. Reconnecting you now. Same flow as the first time but faster because the MCP server registration is still in place.

> Walks Phase 1 from Step 3 (re-runs `authenticate` + Playwright redirect + Allow + callback capture + `complete_authentication`). Does NOT re-register the server.

**Claude:**
Reconnected. Pulling your latest design now.

---

## What this transcript proves

- The bridge-OAuth path (Canva's `mcp.canva.com/authorize` -> Canva central OAuth -> back to MCP-issued bearer) works end-to-end without the user copy-pasting a token.
- The 15-permission consent screen explanation defuses the panic moment a non-technical owner might have at the broad scope list.
- The export-tool chain (`search_designs` -> `get_design_export_formats` -> `create_design_export_job` -> poll -> save) is the standard non-trivial multi-tool flow Phase 2 supports.
- Cold-to-warm timing is realistic.
- The Enterprise allowlist failure mode is surfaced as a plain-English admin task, not a stack trace.
- The token-expiry re-auth path re-runs Phase 1 from Step 3, not the whole install.

The session above was captured against a real Canva account in May 2026, anonymised, and trimmed for length. Anything longer would slow the worked example down without adding evidence.
