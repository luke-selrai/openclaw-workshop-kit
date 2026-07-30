---
name: apify-content-analytics
description: "Tracks the user's OWN social accounts with Apify Actors - Instagram posts and reels, follower growth, Facebook page and ad metrics, YouTube and TikTok. Use when the user asks 'how is my page performing' or 'how is my profile doing' - not a rival's (apify-competitor-intelligence) or a market (apify-market-research)."
---

# Content Analytics

Track and analyze content performance on accounts the user owns or operates, using Apify Actors to extract engagement metrics from Instagram, Facebook, YouTube, and TikTok.

## Which Apify skill should fire?

Three apify-* skills share the run-Actor runtime but route by **whose data the user wants**. The platform list overlaps heavily; intent does not.

| User says… | Right skill |
|---|---|
| "how is MY Instagram performing", "audit MY Facebook page", "MY top reels", "track MY follower growth", "MY ad ROI", "engagement on MY YouTube videos" | **apify-content-analytics** (this one) |
| "compare competitor X to Y", "who are my rivals", "scrape competitor ads", "benchmark competitor reviews" | apify-competitor-intelligence |
| "how big is the market for X", "Google Trends for Y", "validate a product launch", "hashtag size for #foo" | apify-market-research |

The disambiguator is the **possessive**: "my", "our", "this account I own/manage" → content-analytics. "Their", "competitor", a named brand the user doesn't own → competitor-intelligence. "The market for…", "demand for…", "how big is X" → market-research.

If the user said "analyse Instagram" with no possessive, ask one clarifying question: *"Are you analysing your own account, a competitor, or the broader market?"*

## Step 0 - Check the install (dispatches to apify-installer if missing)

This skill consumes a token + a CLI installed by the shared `apify-installer` skill. Check silently; if the token is missing, dispatch to `apify-installer` (autonomous CLI-callback install + auth - no terminal interaction beyond a single sign-in click). After `apify-installer` completes, the check returns READY on next invocation of this skill.

```bash
if [ -f "$HOME/.claude/apify.env" ] && grep -q '^APIFY_TOKEN=apify_api_' "$HOME/.claude/apify.env" 2>/dev/null; then
  echo "READY"
else
  echo "MISSING"
fi
```

If `MISSING`:
> *"Quick one-off setup - I'll get your Apify account connected. Takes about 90 seconds. You'll click Authorize once in a browser tab the installer opens."*

Then invoke the `apify-installer` skill. It installs the Apify CLI + MCP client, runs `apify login --method=console` which opens the user's default browser to Apify Console (sign-up or sign-in handled by the CLI's callback flow), hardens `~/.apify/auth.json` to mode 600, extracts the token, and writes `~/.claude/apify.env` mode-600 for this skill to source. When it returns success, this skill's check returns `READY` and Step 1 begins. Never ask the user to paste a token here - that's the installer's job and it does it without copy-paste.

If `READY`, proceed straight to Step 1.

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 0: Apify install verified (dispatch to apify-installer if missing)
- [ ] Step 1: Identify content analytics type (select Actor)
- [ ] Step 2: Fetch Actor schema via mcpc
- [ ] Step 3: Ask user preferences (format, filename)
- [ ] Step 4: Run the analytics script
- [ ] Step 5: Summarize findings
```

### Step 1: Identify Content Analytics Type

Select the appropriate Actor based on analytics needs. Each row below assumes the account being analysed is OWNED/MANAGED by the user - otherwise route to apify-competitor-intelligence instead.

| User Need | Actor ID | Best For |
|-----------|----------|----------|
| Post engagement metrics | `apify/instagram-post-scraper` | Post performance |
| Reel performance | `apify/instagram-reel-scraper` | Reel analytics |
| Follower growth tracking | `apify/instagram-followers-count-scraper` | Growth metrics |
| Comment engagement | `apify/instagram-comment-scraper` | Comment analysis |
| Hashtag performance | `apify/instagram-hashtag-scraper` | Branded hashtags |
| Mention tracking | `apify/instagram-tagged-scraper` | Tag tracking |
| Comprehensive metrics | `apify/instagram-scraper` | Full data |
| API-based analytics | `apify/instagram-api-scraper` | API access |
| Facebook post performance | `apify/facebook-posts-scraper` | Post metrics |
| Reaction analysis | `apify/facebook-likes-scraper` | Engagement types |
| Facebook Reels metrics | `apify/facebook-reels-scraper` | Reels performance |
| Ad performance tracking | `apify/facebook-ads-scraper` | Ad analytics |
| Facebook comment analysis | `apify/facebook-comments-scraper` | Comment engagement |
| Page performance audit | `apify/facebook-pages-scraper` | Page metrics |
| YouTube video metrics | `streamers/youtube-scraper` | Video performance |
| YouTube Shorts analytics | `streamers/youtube-shorts-scraper` | Shorts performance |
| TikTok content metrics | `clockworks/tiktok-scraper` | TikTok analytics |

### Step 2: Fetch Actor Schema

Tell the user once: *"Looking up what this Actor needs as input - one quick query to Apify."* Then run:

```bash
# Source the env file (sets APIFY_TOKEN in the shell)
set -a; source "$HOME/.claude/apify.env"; set +a

# mcpc 0.3.0+ uses a session-based syntax - connect first, call tool, close
mcpc connect mcp.apify.com @apify --header "Authorization: Bearer $APIFY_TOKEN" >/dev/null 2>&1
mcpc @apify tools-call fetch-actor-details actor:="ACTOR_ID"
mcpc close @apify >/dev/null 2>&1

unset APIFY_TOKEN
```

Replace `ACTOR_ID` with the selected Actor (e.g., `apify/instagram-post-scraper`).

This returns the Actor description, README, required and optional input parameters, and output fields. Build the JSON input for Step 4 from this schema - never hard-code params, as Apify schemas drift.

### Step 3: Ask User Preferences

Before running, ask:
1. **Output format**:
   - **Quick answer** - display top few results in chat (no file saved). Good for "show me my top 5 reels this month" snapshot queries.
   - **CSV** - full export with all fields. Good for monthly reporting + handing to a dashboard.
   - **JSON** - full export in JSON format. Good when feeding the data into another agent or script.
2. **Number of results**: pick a sensible default based on the user's question - 10 for "top of mind", 50 for a monthly audit, 100+ for a full year-over-year analysis.

### Step 4: Run the Script

Tell the user once: *"Running the analytics pull now - this usually takes between 30 seconds and 3 minutes depending on how much data the Actor pulls."* Then run the appropriate variant:

**Quick answer (display in chat, no file):**
```bash
node --env-file=$HOME/.claude/apify.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT'
```

**CSV:**
```bash
node --env-file=$HOME/.claude/apify.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT' \
  --output YYYY-MM-DD_OUTPUT_FILE.csv \
  --format csv
```

**JSON:**
```bash
node --env-file=$HOME/.claude/apify.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT' \
  --output YYYY-MM-DD_OUTPUT_FILE.json \
  --format json
```

### Step 5: Summarize Findings

After completion, report in plain English (not raw JSON):
- Number of content pieces analyzed
- File location and name (if saved)
- Key performance insights - top 3-5 observations a content strategist would care about (top-performer outliers, falling engagement on a content type, hashtag-vs-no-hashtag deltas, posting-time patterns)
- Suggested next steps - *"Want me to dig into why the top reel outperformed the rest?"* / *"Want me to run this monthly so we have a delta vs last month?"*

Reference deliverables are bundled at `examples/` (see Examples section below) - match that shape when the user asks for a written summary.

## Examples

Two reference deliverables live in `examples/`:

- **`examples/instagram-monthly-summary.md`** - what a Step 5 narrative summary of a monthly Instagram run reads like (top reel, follower delta, hashtag winners, posting-time pattern, three suggested next moves).
- **`examples/facebook-page-audit.csv`** - what a `apify/facebook-pages-scraper` audit export looks like, structured for direct opening in Sheets/Excel.

Show workshop attendees one of these BEFORE running, so they know what the deliverable looks like.

## Error Handling

`APIFY_TOKEN not found` - `~/.claude/apify.env` is missing or empty. Dispatch to `apify-installer` per Step 0; the installer rewrites the env file from scratch.

`mcpc not found` - The CLI install didn't complete. Re-run `apify-installer` from Phase 1; it reinstalls both `apify-cli` and `@apify/mcpc`.

`Actor not found` - Check Actor ID spelling; Apify Actor IDs are case-sensitive and use slashes (e.g. `apify/instagram-post-scraper`, NOT `apify-instagram-post-scraper`).

`Run FAILED` - Open the Apify console link in the error output; the run logs explain whether it was a rate limit, a paywalled Actor on the user's plan, or a private-profile gate (the Actor can't read followers-only accounts the user hasn't authenticated against).

`Timeout` - Reduce input size, narrow date range, or increase `--timeout`. `apify/instagram-comment-scraper` is the slowest per result - budget realistically for high-comment posts.
