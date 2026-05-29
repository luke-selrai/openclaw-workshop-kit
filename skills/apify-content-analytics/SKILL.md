---
name: apify-content-analytics
description: Track engagement metrics on the user's OWN social accounts via Apify Actors — Instagram post and reel performance, follower growth, Facebook page audits, ad analytics, YouTube video and Shorts metrics, TikTok content stats. Use this skill when the user says "how is my Instagram performing", "top reels this month", "audit my Facebook page", "YouTube video metrics", "track my follower growth", "MY ad performance", "review MY hashtag stats", or asks about the performance of an account they own or operate. For competitor analysis (THEIR accounts) use apify-competitor-intelligence. For market sizing or product validation use apify-market-research.
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

## Step 0 — Check the install before starting

Run both checks silently; surface a fix only if one fails.

```bash
# (a) Is the APIFY_TOKEN set in the current working dir's .env?
if [ ! -f .env ] || ! grep -q '^APIFY_TOKEN=' .env 2>/dev/null; then
  echo "MISSING_TOKEN"
fi

# (b) Is mcpc installed globally?
command -v mcpc >/dev/null 2>&1 || echo "MISSING_MCPC"
```

If `MISSING_TOKEN`:
> *"I need your Apify token before I can pull engagement data. Open https://console.apify.com/account/integrations in your browser, click 'Personal API tokens', copy the token, and paste it here — I'll save it in a `.env` file in this folder."*

When the user pastes the token, write it to `.env` (mode 600). Never echo the token back.

If `MISSING_MCPC`:
> *"I need to install a small Apify helper tool first — this is a one-off, about 30 seconds."* Then run `npm install -g @apify/mcpc` and confirm completion.

Both checks together are the equivalent of the "Phase 0 resume check" the canonical CWK connectors use — see `skills/CLAUDE.md` for the full pattern. Once both pass, proceed to Step 1.

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 0: APIFY_TOKEN + mcpc verified
- [ ] Step 1: Identify content analytics type (select Actor)
- [ ] Step 2: Fetch Actor schema via mcpc
- [ ] Step 3: Ask user preferences (format, filename)
- [ ] Step 4: Run the analytics script
- [ ] Step 5: Summarize findings
```

### Step 1: Identify Content Analytics Type

Select the appropriate Actor based on analytics needs. Each row below assumes the account being analysed is OWNED/MANAGED by the user — otherwise route to apify-competitor-intelligence instead.

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

Tell the user once: *"Looking up what this Actor needs as input — one quick query to Apify."* Then run:

```bash
export $(grep APIFY_TOKEN .env | xargs) && mcpc --json mcp.apify.com --header "Authorization: Bearer $APIFY_TOKEN" tools-call fetch-actor-details actor:="ACTOR_ID" | jq -r ".content"
```

Replace `ACTOR_ID` with the selected Actor (e.g., `apify/instagram-post-scraper`).

This returns the Actor description, README, required and optional input parameters, and output fields. Build the JSON input for Step 4 from this schema — never hard-code params, as Apify schemas drift.

### Step 3: Ask User Preferences

Before running, ask:
1. **Output format**:
   - **Quick answer** — display top few results in chat (no file saved). Good for "show me my top 5 reels this month" snapshot queries.
   - **CSV** — full export with all fields. Good for monthly reporting + handing to a dashboard.
   - **JSON** — full export in JSON format. Good when feeding the data into another agent or script.
2. **Number of results**: pick a sensible default based on the user's question — 10 for "top of mind", 50 for a monthly audit, 100+ for a full year-over-year analysis.

### Step 4: Run the Script

Tell the user once: *"Running the analytics pull now — this usually takes between 30 seconds and 3 minutes depending on how much data the Actor pulls."* Then run the appropriate variant:

**Quick answer (display in chat, no file):**
```bash
node --env-file=.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT'
```

**CSV:**
```bash
node --env-file=.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT' \
  --output YYYY-MM-DD_OUTPUT_FILE.csv \
  --format csv
```

**JSON:**
```bash
node --env-file=.env ${CLAUDE_PLUGIN_ROOT}/reference/scripts/run_actor.js \
  --actor "ACTOR_ID" \
  --input 'JSON_INPUT' \
  --output YYYY-MM-DD_OUTPUT_FILE.json \
  --format json
```

### Step 5: Summarize Findings

After completion, report in plain English (not raw JSON):
- Number of content pieces analyzed
- File location and name (if saved)
- Key performance insights — top 3-5 observations a content strategist would care about (top-performer outliers, falling engagement on a content type, hashtag-vs-no-hashtag deltas, posting-time patterns)
- Suggested next steps — *"Want me to dig into why the top reel outperformed the rest?"* / *"Want me to run this monthly so we have a delta vs last month?"*

Reference deliverables are bundled at `examples/` (see Examples section below) — match that shape when the user asks for a written summary.

## Examples

Two reference deliverables live in `examples/`:

- **`examples/instagram-monthly-summary.md`** — what a Step 5 narrative summary of a monthly Instagram run reads like (top reel, follower delta, hashtag winners, posting-time pattern, three suggested next moves).
- **`examples/facebook-page-audit.csv`** — what a `apify/facebook-pages-scraper` audit export looks like, structured for direct opening in Sheets/Excel.

Show workshop attendees one of these BEFORE running, so they know what the deliverable looks like.

## Error Handling

`APIFY_TOKEN not found` — Caught at Step 0 if the install check runs. If it slipped through (older session, .env in different dir): repeat the Step 0 token prompt.

`mcpc not found` — Same as above; Step 0 should catch. Otherwise: `npm install -g @apify/mcpc`.

`Actor not found` — Check Actor ID spelling; Apify Actor IDs are case-sensitive and use slashes (e.g. `apify/instagram-post-scraper`, NOT `apify-instagram-post-scraper`).

`Run FAILED` — Open the Apify console link in the error output; the run logs explain whether it was a rate limit, a paywalled Actor on the user's plan, or a private-profile gate (the Actor can't read followers-only accounts the user hasn't authenticated against).

`Timeout` — Reduce input size, narrow date range, or increase `--timeout`. `apify/instagram-comment-scraper` is the slowest per result — budget realistically for high-comment posts.
