# Instagram Monthly Performance — Example Summary

**Source:** `apify/instagram-scraper` + `apify/instagram-reel-scraper`
**Account:** @selrai_workshops (the user's own account)
**Period:** 2026-04-29 → 2026-05-29 (30 days)
**Posts pulled:** 18 (12 feed posts, 4 reels, 2 carousels)

This is what a Step 5 plain-English summary of a monthly Instagram pull reads like for an account the user OWNS. Workshop attendees should see this shape before running their own, so the deliverable is concrete in their head.

---

## Top 3 observations

### 1. One reel carried 60% of the month's reach

Your **2026-05-14 reel ("How a workshop attendee shipped a Telegram bot in 4 hours")** pulled 28,400 views — more than the other three reels combined (11,200 views across them). Engagement rate on that reel was 8.4% (vs. an account average of 2.1% over the month).

Implication: there is a strong "case study" content format the audience is hungry for. Three of four reels in May used a generic "skill demo" frame; the one that used the named-attendee narrative outperformed by 5×. Consider rebranding the format as "Workshop wins" and committing to one per week.

### 2. Hashtag-bearing posts outperformed no-hashtag posts 3:1

The 11 posts with branded hashtags (#ClaudeCode + 3-5 niche tags) averaged 1,250 reach and 87 engagements. The 7 posts without hashtags averaged 410 reach and 28 engagements.

Implication: hashtags are still working for the account's niche reach. Recommend a small hashtag set (5-7 max — Instagram's algorithm caps relevance signals beyond that) on every post going forward.

### 3. Posting between 7-9pm AEST beat morning posts

Reach-per-post averaged 1,890 for posts sent between 7-9pm AEST and 530 for posts sent before 11am AEST. The pattern held across all 18 posts (no morning post beat the median evening post).

Implication: the audience is engaging in the wind-down window. Default the workshop's posting calendar to 7:30pm AEST and only use morning slots for time-sensitive announcements.

---

## File location

```
2026-05-29_instagram-monthly-selrai-workshops.csv
```

18 rows × 24 columns (postId, caption, mediaType, postedAt, likeCount, commentCount, viewCount, hashtags, mentions, location, etc.). Open in Sheets for further pivot work — recommended pivots: mediaType × averageReach, postedAt-hour × engagementRate, hashtag × averageEngagement.

## Suggested next steps

- *"Want me to drill into the 2026-05-14 reel — pull the comments and look at what the audience is actually saying?"*
- *"Want me to run this same query next month and post a side-by-side delta so we can see what's moving?"*
- *"Want me to pull the same metrics for @harvey_shaw — your co-founder — so we can compare account growth trajectories?"* (Note: that would route to apify-competitor-intelligence if Harvey's account isn't owned by you.)

---

> **Workshop attendee note:** Notice the summary leads with three observations a content strategist would actually act on, NOT with the raw CSV columns. Step 5 of apify-content-analytics is about extracting *insight* about YOUR OWN account, not echoing data. If your summary reads like a row dump, push another layer — "what should I do differently next month based on this?"
