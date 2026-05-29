# Google Trends — Example Summary (Australia, 2026)

**Source:** `apify/google-trends-scraper`
**Query:** `["AI agent", "Claude Code", "ChatGPT plugin"]` across `AU` over `today 12-m`
**Run date:** 2026-05-29

This is what a Step 5 plain-English summary of a Google Trends multi-term run reads like. Workshop attendees should see this shape before running their own, so the "market-validation answer" feels concrete.

---

## Headline

**"Claude Code" search interest in Australia is up 4× year-over-year as of May 2026, has overtaken "ChatGPT plugin", but is still ~30% of "AI agent" volume.**

---

## Top 3 observations

### 1. "Claude Code" overtook "ChatGPT plugin" in March 2026 and never looked back

The relative-interest index for `"Claude Code"` was 12 in June 2025 (vs. 41 for `"ChatGPT plugin"`). By April 2026 the lines crossed: `"Claude Code"` at 38, `"ChatGPT plugin"` at 22. In May 2026 the gap widened — `"Claude Code"` at 47, `"ChatGPT plugin"` at 18.

Implication for SelrAI: the workshop's branding around Claude Code is on the right side of the demand curve. We're not just on a hyped technology; we're on the one users specifically search for, and the substitute (ChatGPT plugins) is in decline.

### 2. The umbrella term "AI agent" still 3-5× the volume of "Claude Code"

`"AI agent"` runs at a steady 130-180 relative-interest index across the whole period, with a small May 2026 bump to 195. `"Claude Code"` peaks at 47.

Implication: there is a large pool of "I want an AI agent" intent that hasn't yet narrowed to "I want Claude Code specifically." The content-marketing opportunity is workshops/explainers titled "How to build an AI agent (using Claude Code)" — capturing the broad-intent search and converting it to the specific-tool path.

### 3. Demand concentrates in NSW + VIC; QLD is the lagging region

Regional cut for `"Claude Code"` in May 2026:
- NSW: 64 (relative interest)
- VIC: 51
- ACT: 38
- WA: 22
- QLD: 14
- SA: 11
- TAS: 8

Implication: the launch sequencing for in-person workshop dates should prioritise Sydney and Melbourne (which is what we're already doing). The QLD lag suggests a Brisbane workshop should NOT be the second city; aim for Canberra (ACT, smaller market but higher density of interest) before Brisbane.

---

## File location

```
2026-05-29_google-trends-au-aiagent.csv
```

156 rows × 6 columns (term, geo, weekStarting, relativeInterest, isPartial, source). Open in Sheets — recommended pivot: term × geo (filter by latest 4 weeks) for a regional decision-making cut.

## Suggested next steps

- *"Want me to add `\"agent stack\"` and `\"agent teams\"` to the comparison — those are SelrAI's branded vocabulary and we should track whether they're gaining standalone interest?"*
- *"Want me to pull the same query for the US and UK markets — is the Claude Code vs ChatGPT plugin crossover pattern the same elsewhere?"*
- *"Want me to drill into the related-queries data Google Trends returns — what are people searching for ALONGSIDE 'Claude Code' that would tell us what their next question is?"*

---

> **Workshop attendee note:** Notice the summary's three observations all lead to a *founder decision* (branding bet, content-marketing strategy, launch sequencing). Google Trends data is most valuable when it's translated into "what should I do differently this quarter?" — not "here are some numbers." If your Step 5 summary stops at numbers, push another layer — what's the implication for the next move?
