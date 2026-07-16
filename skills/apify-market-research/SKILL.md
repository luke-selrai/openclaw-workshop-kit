---
name: apify-market-research
description: Validate market size, demand, regional interest, and product-launch viability via Apify Actors. Lead use case is Google Trends search-interest analysis, plus Facebook Marketplace pricing, TripAdvisor and Booking.com hospitality data, Google Maps market density, and Instagram hashtag sizing. Use this skill when the user says "how big is the market for X", "Google Trends for Y", "validate a product launch", "search interest in Z", "market density near me", "hashtag size for #foo", "pricing on Marketplace for X", "Booking demand for Y city". For analytics on the user's OWN accounts use apify-content-analytics. For benchmarking specific NAMED competitors use apify-competitor-intelligence.
---

# Market Research

Size markets, validate demand, and quantify regional interest using Apify Actors - with **Google Trends as the headline data source** and Facebook Marketplace / TripAdvisor / Booking.com / Google Maps as the supporting set.

## Why Google Trends is the headline

Among the three sibling `apify-*` skills, this one uniquely covers `apify/google-trends-scraper`, `apify/facebook-marketplace-scraper`, and `maxcopell/tripadvisor-reviews` - none of which appear in competitor-intelligence or content-analytics. (`voyager/booking-scraper` is also covered here, but it overlaps with apify-competitor-intelligence - the difference is intent: market-research uses it for destination-demand sizing across a region, competitor-intelligence uses it for benchmarking a specific named hotel.) If you can frame the user's question as "what's the demand signal for X across a region or time period", lead with Google Trends first; it's the highest-signal-per-API-call data source for market-validation questions.

## Which Apify skill should fire?

Three apify-* skills share the run-Actor runtime but route by **what kind of question the user is asking**.

| User says… | Right skill |
|---|---|
| "how big is the market for X", "Google Trends for Y", "demand for Z near me", "validate a launch", "hashtag size", "Marketplace pricing for X", "Booking demand for Y" | **apify-market-research** (this one) |
| "how is MY Instagram performing", "audit MY page", "MY top reels", "MY ad ROI" | apify-content-analytics |
| "compare competitor X to Y", "scrape competitor ads", "benchmark named brand reviews" | apify-competitor-intelligence |

The disambiguator: market-research is about the **market or category**, not a named brand. If the user named a specific competitor, route to competitor-intelligence. If they said "my", route to content-analytics. If they're asking "how big / how much demand / how trending", you're in the right place.

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
- [ ] Step 1: Identify market-research type (select Actor)
- [ ] Step 2: Fetch Actor schema via mcpc
- [ ] Step 3: Ask user preferences (format, filename)
- [ ] Step 4: Run the analysis script
- [ ] Step 5: Summarize findings
```

### Step 1: Identify Market Research Type

Pick the Actor based on the research goal. The first block is the **unique value-add** of this skill - these Actors do not appear in the two sibling apify-* skills, so they are the headline reach.

**Unique to apify-market-research:**

| User Need | Actor ID | Best For |
|-----------|----------|----------|
| Search-interest trends over time / by region | `apify/google-trends-scraper` | Demand signal, regional cuts, multi-term comparison |
| Marketplace pricing + listing density | `apify/facebook-marketplace-scraper` | Resale prices, second-hand demand, used-product sizing |
| Tourism reputation + visitor sentiment | `maxcopell/tripadvisor-reviews` | Destination viability, attraction popularity |

**Shared with sibling apify-* skills** (use these when the question genuinely needs them; otherwise prefer the unique ones above). Disambiguate by intent: same Actor, different question shape.

| User Need | Actor ID | Best For | Also in |
|-----------|----------|----------|---------|
| Hospitality demand + price signal across a destination | `voyager/booking-scraper` | Hotel availability, ADR signals, region-wide demand sizing | apify-competitor-intelligence (named-hotel benchmarking) |
| Market density (count of operators in a region) | `compass/crawler-google-places` | "How many gyms / cafes / dentists in this postcode" | apify-competitor-intelligence |
| Geospatial business mapping | `compass/google-maps-extractor` | Coordinates + categories for clustering | apify-competitor-intelligence |
| Event market sizing | `apify/facebook-events-scraper` | Event count + attendee proxy for a category | apify-competitor-intelligence |
| Consumer-need group research | `apify/facebook-groups-scraper` | What people are asking for / complaining about | - (genuinely unique here, no sibling overlap) |
| Hashtag size + reach signal | `apify/instagram-hashtag-stats` | "How big is #pilatesbondi" pre-launch sizing | - (genuinely unique here, no sibling overlap) |
| Hashtag-driven content sampling | `apify/instagram-hashtag-scraper` | What content currently dominates a hashtag | apify-content-analytics |

> **Note on tightened mappings.** Earlier versions of this skill listed `apify/instagram-reel-scraper` under "Market activity" and `apify/facebook-photos-scraper` under "Cultural insights" - both were stretches. They've been removed; the right home for them is `apify-content-analytics` (if the reels are on the user's own account) or `apify-competitor-intelligence` (if scraping a named brand's reels). Don't reach for them from this skill.

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

Replace `ACTOR_ID` with the selected Actor (e.g., `apify/google-trends-scraper`).

This returns the Actor description, README, required and optional input parameters, and output fields. Use the schema to build the JSON input for Step 4 - never hard-code params, as Apify Actor schemas drift.

> **Google Trends-specific note.** The `apify/google-trends-scraper` schema (verified live via `mcpc fetch-actor-details` on 2026-05-29) expects:
>
> - `searchTerms` - array of strings (required if no `spreadsheetId`)
> - `geo` - **singular string** ISO country code (`AU`, `US`, `GB`, etc.). Defaults to Worldwide. Cannot use sub-region codes like `AU-NSW` here; that level of detail comes back automatically in the dataset for larger countries.
> - `viewedFrom` - **lowercase** ISO country code for residential proxy origin (`us`, `au`, etc.). Optional; helps avoid Google's anti-scrape if direct requests fail.
> - `timeRange` - one of: `""` (default, Past 12 months), `now 1-H`, `now 4-H`, `now 1-d`, `now 7-d`, `today 1-m`, `today 3-m`, `today 5-y`, `all`. **`today 12-m` is NOT a valid value** - Google Trends doesn't expose 12-month as a discrete option in their UI either; pass `""` (empty/omit) for the default Past 12 months window.
> - `customTimeRange` - optional `YYYY-MM-DD YYYY-MM-DD` format. Takes precedence over `timeRange` if both are set.
>
> Multi-term comparison is the killer feature - pass 2-5 related terms in one request and you get the relative-interest comparison Google Trends UI shows.
>
> **Known reliability issue (verified 2026-05-29):** `apify/google-trends-scraper` runs frequently fail with Puppeteer selector timeouts because Google Trends actively blocks scraping. Symptom: status "Crawled 0/N pages" + log line `Failed to handle embed widget RELATED_QUERIES: TimeoutError: Waiting for selector trends-widget[widget-name*="RELATED_QUERIES"] failed`. This is upstream - not a SKILL bug - and happens to any user including direct Apify Console runs. Workarounds: (a) retry the same input 2-3 times across different residential proxy origins via `viewedFrom`; (b) use a different time range (`today 3-m` had higher success than `today 5-y` in testing); (c) for queries that consistently fail, fall back to the Marketplace + TripAdvisor + Booking Actors which don't have this issue. Apify's status page may flag the Actor as degraded during outages.

### Step 3: Ask User Preferences

Before running, ask:
1. **Output format**:
   - **Quick answer** - display top few results in chat (no file saved). Good for "is this trending up or down" snapshot questions.
   - **CSV** - full export with all fields. Good for time-series charts in Sheets or a downstream BI tool.
   - **JSON** - full export in JSON format. Good for feeding into another agent or script.
2. **Number of results / time range**: pick a sensible default based on the user's question - 12 months for trend questions, 7 days for "is this real-time hot", 5 years for "is this a long-term shift".

### Step 4: Run the Script

Tell the user once: *"Running the market pull now - Google Trends usually takes 30-60 seconds; Marketplace and Booking can take 2-3 minutes depending on result count."* Then run the appropriate variant:

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

After completion, report in plain English (not raw data):
- Market-size headline number (operators in region / hashtag posts count / Google Trends index)
- File location and name (if saved)
- Key market insights - top 3-5 observations a founder validating a launch would care about (trend direction, regional concentration, price band, seasonal pattern, competitor density)
- Suggested next steps - *"Want me to drill into the regional cut - is the demand concentrated in one city?"* / *"Want me to compare against a related search term to see if a substitute is eating the market?"*

Reference deliverables are bundled at `examples/` (see Examples section below) - match that shape when the user asks for a written summary.

## Examples

Two reference deliverables live in `examples/`:

- **`examples/google-trends-aus-2026.md`** - what a Step 5 narrative summary of a Google Trends multi-term run reads like (trend headline, regional cut, seasonal pattern, three founder-actionable next moves).
- **`examples/market-density-bondi.csv`** - what a `compass/crawler-google-places` market-density export looks like (count operators in a region, structured for spreadsheet clustering).

Show workshop attendees one of these BEFORE running, so they know what the deliverable looks like.

## Error Handling

`APIFY_TOKEN not found` - `~/.claude/apify.env` is missing or empty. Dispatch to `apify-installer` per Step 0; the installer rewrites the env file from scratch.

`mcpc not found` - The CLI install didn't complete. Re-run `apify-installer` from Phase 1; it reinstalls both `apify-cli` and `@apify/mcpc`.

`Actor not found` - Check Actor ID spelling; Apify Actor IDs are case-sensitive and use slashes (e.g. `apify/google-trends-scraper`, NOT `apify-google-trends-scraper`).

`Run FAILED` - Open the Apify console link in the error output; the run logs explain whether it was a rate limit, a paywalled Actor on the user's plan, or a Google-anti-bot block (Trends in particular).

`Timeout` - Reduce input size, narrow `timeRange`, or increase `--timeout`. `apify/facebook-marketplace-scraper` is the slowest per result - budget realistically for broad city-wide searches.
