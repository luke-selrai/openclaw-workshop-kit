---
name: apify-competitor-intelligence
description: "Benchmarks named competitors with Apify Actors - their Google Maps reviews, Booking.com hotels, Facebook pages and ads, Instagram, YouTube and TikTok. Use when the user wants rivals scraped or compared - not their own accounts (apify-content-analytics) or a market (apify-market-research)."
---

# Competitor Intelligence

Pull competitor data from Google Maps, Booking.com, Facebook, Instagram, YouTube, and TikTok via Apify Actors.

## Which Apify skill should fire?

Three apify-* skills share the run-Actor runtime but route by **whose data the user wants**. Before continuing, sanity-check the intent:

| User says… | Right skill |
|---|---|
| "compare competitor X to Y", "who are my rivals", "scrape competitor ads", "benchmark competitor reviews" | **apify-competitor-intelligence** (this one) |
| "how is MY Instagram performing", "audit MY Facebook page", "MY top reels this month", "track MY follower growth" | apify-content-analytics |
| "how big is the market for X", "Google Trends for Y", "validate a product launch", "hashtag size for #foo" | apify-market-research |

If the user said "analyse Instagram" with no possessive, ask one clarifying question: *"Are you analysing competitors, your own account, or the broader market?"*

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
- [ ] Step 1: Identify competitor analysis type (select Actor)
- [ ] Step 2: Fetch Actor schema via mcpc
- [ ] Step 3: Ask user preferences (format, filename)
- [ ] Step 4: Run the analysis script
- [ ] Step 5: Summarize findings
```

### Step 1: Identify Competitor Analysis Type

Select the appropriate Actor based on analysis needs:

| User Need | Actor ID | Best For |
|-----------|----------|----------|
| Competitor business data | `compass/crawler-google-places` | Location analysis |
| Competitor contact discovery | `poidata/google-maps-email-extractor` | Email extraction |
| Feature benchmarking | `compass/google-maps-extractor` | Detailed business data |
| Competitor review analysis | `compass/Google-Maps-Reviews-Scraper` | Review comparison |
| Hotel competitor data | `voyager/booking-scraper` | Hotel benchmarking |
| Hotel review comparison | `voyager/booking-reviews-scraper` | Review analysis |
| Competitor ad strategies | `apify/facebook-ads-scraper` | Ad creative analysis |
| Competitor page metrics | `apify/facebook-pages-scraper` | Page performance |
| Competitor content analysis | `apify/facebook-posts-scraper` | Post strategies |
| Competitor reels performance | `apify/facebook-reels-scraper` | Reels analysis |
| Competitor audience analysis | `apify/facebook-comments-scraper` | Comment sentiment |
| Competitor event monitoring | `apify/facebook-events-scraper` | Event tracking |
| Competitor audience overlap | `apify/facebook-followers-following-scraper` | Follower analysis |
| Competitor review benchmarking | `apify/facebook-reviews-scraper` | Review comparison |
| Competitor ad monitoring | `apify/facebook-search-scraper` | Ad discovery |
| Competitor profile metrics | `apify/instagram-profile-scraper` | Profile analysis |
| Competitor content monitoring | `apify/instagram-post-scraper` | Post tracking |
| Competitor engagement analysis | `apify/instagram-comment-scraper` | Comment analysis |
| Competitor reel performance | `apify/instagram-reel-scraper` | Reel metrics |
| Competitor growth tracking | `apify/instagram-followers-count-scraper` | Follower tracking |
| Comprehensive competitor data | `apify/instagram-scraper` | Full analysis |
| API-based competitor analysis | `apify/instagram-api-scraper` | API access |
| Competitor video analysis | `streamers/youtube-scraper` | Video metrics |
| Competitor sentiment analysis | `streamers/youtube-comments-scraper` | Comment sentiment |
| Competitor channel metrics | `streamers/youtube-channel-scraper` | Channel analysis |
| TikTok competitor analysis | `clockworks/tiktok-scraper` | TikTok data |
| Competitor video strategies | `clockworks/tiktok-video-scraper` | Video analysis |
| Competitor TikTok profiles | `clockworks/tiktok-profile-scraper` | Profile data |

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

Replace `ACTOR_ID` with the selected Actor (e.g., `compass/crawler-google-places`).

This returns the Actor description, README, required and optional input parameters, and output fields. Use the schema to build the JSON input for Step 4 - never hard-code params, as Apify Actor schemas drift.

### Step 3: Ask User Preferences

Before running, ask:
1. **Output format**:
   - **Quick answer** - display top few results in chat (no file saved). Good for "show me the 3 closest competitors" exploratory queries.
   - **CSV** - full export with all fields. Good for handing the data to a spreadsheet for further analysis.
   - **JSON** - full export in JSON format. Good when feeding the data into another agent or script.
2. **Number of results**: pick a sensible default based on the user's question - 10 for "give me a list", 50 for benchmarking, 100+ for a full audit.

### Step 4: Run the Script

Tell the user once: *"Running the analysis now - this usually takes between 30 seconds and 3 minutes depending on how much data the Actor pulls."* Then run the appropriate variant:

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
- Number of competitors analyzed
- File location and name (if saved)
- Key competitive insights - top 3-5 observations a human would care about (review-score gaps, ad-creative themes, follower-count outliers, geographic clusters)
- Suggested next steps - *"Want me to drill into the top 3 by review count?"* / *"Want me to compare ad creative themes across these competitors?"*

Reference deliverables are bundled at `examples/` (see Examples section below) - match that shape when the user asks for a written summary.

## Examples

Two reference deliverables live in `examples/`:

- **`examples/competitor-google-maps.json`** - what a `compass/crawler-google-places` run looks like, structured for spreadsheet import.
- **`examples/facebook-ads-summary.md`** - what a Step 5 narrative summary of a `apify/facebook-ads-scraper` run reads like, with the three-observation shape.

Show workshop attendees one of these BEFORE running, so they know what the deliverable looks like.

## Error Handling

`APIFY_TOKEN not found` - `~/.claude/apify.env` is missing or empty. Dispatch to `apify-installer` per Step 0; the installer rewrites the env file from scratch.

`mcpc not found` - The CLI install didn't complete. Re-run `apify-installer` from Phase 1; it reinstalls both `apify-cli` and `@apify/mcpc`.

`Actor not found` - Check Actor ID spelling; Apify Actor IDs are case-sensitive and use slashes (e.g. `apify/facebook-ads-scraper`, NOT `apify-facebook-ads-scraper`).

`Run FAILED` - Open the Apify console link in the error output; the run logs explain whether it was a rate limit, a paywalled Actor on the user's plan, or a broken Actor (rare).

`Timeout` - Reduce input size, narrow geographic scope, or increase `--timeout`. Some Actors (especially `compass/Google-Maps-Reviews-Scraper`) are slow per result; budget realistically.
