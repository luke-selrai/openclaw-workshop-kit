# Competitor Facebook Ads - Example Summary

**Source:** `apify/facebook-ads-scraper`
**Query:** Active ads for top 3 competitors in the "boutique fitness Sydney" space
**Run date:** 2026-05-29
**Ads pulled:** 47 active creatives across the 3 advertisers

This is what a Step 5 plain-English summary of a Facebook Ads scrape reads like. Workshop attendees should see this shape before running their own analysis, so the deliverable is concrete in their head.

---

## Top 3 observations

### 1. Two of three competitors lead with the same hook

Both **Bondi Body Co** (28 active ads) and **RisePilates Bondi** (15 active ads) open with a "First class free" headline and a smiling-instructor portrait. **Coast Strength** (4 active ads) instead leads with "Strength for the over-40s" and a barbell shot.

Implication for our positioning: the "first class free" lane is crowded. We can either dial that promo up (price-match aggressively) or differentiate on a hook neither is using - e.g., "small-group attention," "named coach by name," or a measurable-outcome hook ("hit your first pull-up").

### 2. Video-first vs static-image creative is split 70/30

33 of 47 active ads (~70%) are video, mostly 8-15 second class-room or transformation clips. The 14 static ads concentrate at **Bondi Body Co** (8 of their 28 ads) and **RisePilates Bondi** (2 of their 15 ads). All 4 of **Coast Strength's** active ads are static - they don't run video at all, which is consistent with their lower volume and a more text-heavy "strength for the over-40s" hook that translates poorly to short-form video.

Implication: workshop attendees who want to enter this competitive set should plan to produce video unless they have a strongly text-driven differentiator like Coast Strength's. The cost ceiling shifts here - a still-image-only ad strategy at scale (Bondi Body Co or RisePilates volume) won't hit competitive CPMs.

### 3. Ad spend concentrates Thursday-Sunday for class-launch promos

Looking at the `adDeliveryStartTime` timestamps, 31 of 47 ads launched on a Thursday or Friday. Most run through the weekend. The Monday-Wednesday "low" suggests competitors are matching peak booking window (weekend training planning happens Thu-Sat).

Implication: a Tuesday ad-launch cycle is contrarian and might catch the same audience with less competition for the impression. Worth testing.

---

## File location

```
2026-05-29_competitor-fb-ads-bondi.csv
```

47 rows × 18 columns (advertiser, headline, body text, creative type, start date, country, page-like count, etc.). Open in Sheets/Excel for further pivot work.

## Suggested next steps

- *"Want me to drill into the ad-creative themes - group ads by headline keyword and count, so we can spot which messages each competitor doubles down on?"*
- *"Want me to pull Instagram ads for the same three brands and compare - they may be running different creative on Reels than on Feed."*
- *"Want me to run this every Monday and post a weekly delta - new ads, retired ads, ones that just spun up?"*

---

> **Workshop attendee note:** Notice the summary leads with three observations a human would care about, NOT with raw CSV column dumps. Step 5 of the apify-competitor-intelligence skill is about extracting *insight*, not echoing data. If your summary reads like a table of numbers, push another layer - "what does this *mean* for the user's positioning?"
