---
name: apify-competitor-intelligence
description: Pull competitor data via Apify Actors — Google Maps locations and reviews, Booking.com hotel benchmarking, Facebook Pages and Ads Library, Instagram profiles and reels, YouTube channels, TikTok creators. Use this skill when the user says "competitor analysis", "who are my competitors", "scrape Facebook ads", "compare hotels on Booking", "analyse competitor Instagram", "benchmark Google Maps reviews", "find competitor emails", or asks to compare a named brand to its rivals on any of these platforms. For analytics on the user's OWN accounts use apify-content-analytics. For market sizing/demand research (Google Trends, Marketplace pricing) use apify-market-research.
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

## Step 0 — Check the install before starting

Both checks below are cheap and run silently. If either fails, surface the fix to the user once in plain English (no terminal jargon) before any Actor work.

```bash
# (a) Is the APIFY_TOKEN set in the current working dir's .env?
if [ ! -f .env ] || ! grep -q '^APIFY_TOKEN=' .env 2>/dev/null; then
  echo "MISSING_TOKEN"
fi

# (b) Is mcpc installed globally?
command -v mcpc >/dev/null 2>&1 || echo "MISSING_MCPC"
```

If `MISSING_TOKEN`:
> *"I need your Apify token before I can pull competitor data. Open https://console.apify.com/account/integrations in your browser, click 'Personal API tokens', copy the token, and paste it here — I'll save it in a `.env` file in this folder."*

When the user pastes the token, write it to `.env` (mode 600). Never echo the token back.

If `MISSING_MCPC`:
> *"I need to install a small Apify helper tool first — this is a one-off, about 30 seconds."* Then run `npm install -g @apify/mcpc` and confirm completion.

Both checks together are the equivalent of the "Phase 0 resume check" the canonical CWK connectors use — see `skills/CLAUDE.md` for the full pattern. Once both pass, proceed to Step 1.

## Workflow

Copy this checklist and track progress:

```
Task Progress:
- [ ] Step 0: APIFY_TOKEN + mcpc verified
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

Tell the user once: *"Looking up what this Actor needs as input — one quick query to Apify."* Then run:

```bash
export $(grep APIFY_TOKEN .env | xargs) && mcpc --json mcp.apify.com --header "Authorization: Bearer $APIFY_TOKEN" tools-call fetch-actor-details actor:="ACTOR_ID" | jq -r ".content"
```

Replace `ACTOR_ID` with the selected Actor (e.g., `compass/crawler-google-places`).

This returns the Actor description, README, required and optional input parameters, and output fields. Use the schema to build the JSON input for Step 4 — never hard-code params, as Apify Actor schemas drift.

### Step 3: Ask User Preferences

Before running, ask:
1. **Output format**:
   - **Quick answer** — display top few results in chat (no file saved). Good for "show me the 3 closest competitors" exploratory queries.
   - **CSV** — full export with all fields. Good for handing the data to a spreadsheet for further analysis.
   - **JSON** — full export in JSON format. Good when feeding the data into another agent or script.
2. **Number of results**: pick a sensible default based on the user's question — 10 for "give me a list", 50 for benchmarking, 100+ for a full audit.

### Step 4: Run the Script

Tell the user once: *"Running the analysis now — this usually takes between 30 seconds and 3 minutes depending on how much data the Actor pulls."* Then run the appropriate variant:

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
- Number of competitors analyzed
- File location and name (if saved)
- Key competitive insights — top 3-5 observations a human would care about (review-score gaps, ad-creative themes, follower-count outliers, geographic clusters)
- Suggested next steps — *"Want me to drill into the top 3 by review count?"* / *"Want me to compare ad creative themes across these competitors?"*

Reference deliverables are bundled at `examples/` (see Examples section below) — match that shape when the user asks for a written summary.

## Examples

Two reference deliverables live in `examples/`:

- **`examples/competitor-google-maps.json`** — what a `compass/crawler-google-places` run looks like, structured for spreadsheet import.
- **`examples/facebook-ads-summary.md`** — what a Step 5 narrative summary of a `apify/facebook-ads-scraper` run reads like, with the three-observation shape.

Show workshop attendees one of these BEFORE running, so they know what the deliverable looks like.

## Error Handling

`APIFY_TOKEN not found` — Caught at Step 0 if the install check runs. If it slipped through (older session, .env in different dir): repeat the Step 0 token prompt.

`mcpc not found` — Same as above; Step 0 should catch. Otherwise: `npm install -g @apify/mcpc`.

`Actor not found` — Check Actor ID spelling; Apify Actor IDs are case-sensitive and use slashes (e.g. `apify/facebook-ads-scraper`, NOT `apify-facebook-ads-scraper`).

`Run FAILED` — Open the Apify console link in the error output; the run logs explain whether it was a rate limit, a paywalled Actor on the user's plan, or a broken Actor (rare).

`Timeout` — Reduce input size, narrow geographic scope, or increase `--timeout`. Some Actors (especially `compass/Google-Maps-Reviews-Scraper`) are slow per result; budget realistically.
