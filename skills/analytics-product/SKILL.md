---
name: analytics-product
description: 'Product analytics — PostHog, Mixpanel, events, funnels, cohorts, retention, north star metric, OKRs, and product dashboards. Use for: event tracking setup, conversion funnel analysis, cohort retention, DAU/MAU, feature flags, A/B testing, north star metrics, OKRs, product dashboards.'
risk: none
source: selrai-company/claude-workshop-kit
date_added: '2026-03-06'
tags:
- analytics
- product
- metrics
- posthog
- mixpanel
tools:
- claude-code
---

# ANALYTICS-PRODUCT — Decide With Data

## Overview

Product analytics skill covering PostHog, Mixpanel, events, funnels, cohorts, retention, north star metric, OKRs, and product dashboards. Use for: event tracking setup, conversion funnel analysis, cohort retention, DAU/MAU, feature flags, A/B testing, north star metrics, OKRs, and product dashboards.

> Note: Code examples throughout this skill use a sample SaaS product as reference — adapt event names, metrics, and targets to your own product.

> You do not need to write code to use this skill. Just ask in plain language, for example "what events should I track?", "is this A/B test significant?", or "where are users dropping off in my funnel?", and it does the analysis and gives you the answer. The Python snippets and the `examples/` folder are optional. They are there for when you or a developer wire the numbers into a tool like PostHog.

## When to Use This Skill

Reach for this skill when you say things like:

- "Set up analytics for my product" or "what events should I track?"
- "Design an event taxonomy" or "name these events properly"
- "Build a retention dashboard" or "calculate cohort retention for my users"
- "Is this A/B test statistically significant?" or "did the variant actually win?"
- "Define our north star metric" or "what should our north star be?"
- "Score my activation funnel" or "where are users dropping off before the aha moment?"
- "What's a good W4 retention benchmark for SaaS?"
- "Write an OKR for the product team this quarter"

## Do Not Use This Skill When

- The task is raw data-warehouse modelling, SQL schema design, or ETL pipeline work. That is a database / DBA task, not product analytics.
- You need the actual analytics vendor SDK installed and wired into a production app. This skill gives you the taxonomy, math, and reference code, but the user installs and runs the libraries.
- The question is marketing-attribution or ad-spend ROAS modelling. Adjacent, but a different discipline with its own tooling.
- You want financial forecasting or revenue recognition. That is finance, not product analytics.

## How It Works

```
[object]_[past_verb]

Correct:  user_signed_up, conversation_started, upgrade_completed
Wrong:    signup, click, conversion
```

## Analytics-Product — Decide With Data

> "In God we trust. All others must bring data." — W. Edwards Deming

---

## Essential Events (Example)

> The events below are from a sample SaaS product. They are a starting shape, not your taxonomy. Rename every event to match what your own users actually do.

```python
PRODUCT_EVENTS = {
    # Acquisition
    "user_signed_up":        {"props": ["source", "medium", "campaign"]},
    "onboarding_started":    {"props": ["step_count"]},
    "onboarding_completed":  {"props": ["time_to_complete", "steps_skipped"]},

    # Activation
    "first_conversation":    {"props": ["intent", "response_time"]},
    "aha_moment_reached":    {"props": ["trigger", "session_number"]},
    "feature_discovered":    {"props": ["feature_name", "discovery_method"]},

    # Retention
    "conversation_started":  {"props": ["intent", "user_tier", "device"]},
    "conversation_completed":{"props": ["messages_count", "duration", "rating"]},
    "session_started":       {"props": ["days_since_last", "platform"]},

    # Revenue
    "upgrade_viewed":        {"props": ["trigger", "current_tier"]},
    "upgrade_started":       {"props": ["target_tier", "trigger"]},
    "upgrade_completed":     {"props": ["tier", "plan", "revenue"]},
    "subscription_canceled": {"props": ["reason", "tier", "tenure_days"]},
    "payment_failed":        {"props": ["attempt_count", "error_code"]},
}
```

## PostHog Implementation (Python)

> Setup: this snippet needs `posthog` installed and a PostHog project key. Run `pip install "posthog>=7" python-dotenv` first, then put `POSTHOG_API_KEY=phc_...` in a `.env` file beside your script. The `load_dotenv()` call below reads it so you never hard-code the key. Use your PostHog PROJECT API key (the `phc_...` ingest key), NOT a personal API key. A runnable version of this wrapper ships at `examples/posthog-init.py`. This targets PostHog Python SDK v7+ (v7 removed identify(); use set()).

```python
from posthog import Posthog
from dotenv import load_dotenv
import os

load_dotenv()  # reads POSTHOG_API_KEY (and POSTHOG_HOST) from a .env file beside this script

posthog = Posthog(
    project_api_key=os.environ["POSTHOG_API_KEY"],
    host=os.environ.get("POSTHOG_HOST", "https://app.posthog.com")
)

def track(user_id: str, event: str, properties: dict = None):
    posthog.capture(
        distinct_id=user_id,
        event=event,
        properties=properties or {}
    )

def identify(user_id: str, traits: dict):
    # PostHog 7.x removed identify(); set() updates the person's traits.
    posthog.set(
        distinct_id=user_id,
        properties=traits
    )

## Usage:

track("user_123", "conversation_started", {
    "intent": "business_advice",
    "device": "mobile",
    "user_tier": "pro"
})
```

---

## Activation Funnel (Example)

```
Visits landing page          (100%)
    | [target: 40%]
Clicks "Try it"               (40%)
    | [target: 70%]
Completes sign-up             (28%)
    | [target: 60%]
Has first conversation        (17%)  <- AHA MOMENT
    | [target: 50%]
Returns next day              (8.5%)
    | [target: 40%]
Uses 3+ days per week         (3.4%)
    | [target: 20%]
Converts to Pro               (0.7%)
```

## Optimising the Funnel

```
For each drop-off above benchmark:
1. Identify: where exactly does the user leave?
2. Understand: why? (session recordings, surveys)
3. Hypothesise: what change could improve this?
4. Test: A/B test with a statistically significant sample
5. Measure: minimum 2 weeks, p-value < 0.05
6. Learn: even failures improve your understanding of the user
```

---

## Cohort Analysis (Weekly Retention)

```python
def calculate_cohort_retention(events_df):
    """
    events_df: DataFrame with columns [user_id, event_date, event_name]
    Returns: retention matrix [cohort_week x week_number]
    """
    import pandas as pd

    first_session = events_df[events_df.event_name == "session_started"] \
        .groupby("user_id")["event_date"].min() \
        .dt.to_period("W")

    sessions = events_df[events_df.event_name == "session_started"].copy()
    sessions["cohort"] = sessions["user_id"].map(first_session)
    sessions["weeks_since"] = (
        sessions["event_date"].dt.to_period("W") - sessions["cohort"]
    ).apply(lambda x: x.n)

    cohort_data = sessions.groupby(["cohort", "weeks_since"])["user_id"].nunique()
    cohort_sizes = cohort_data.unstack().iloc[:, 0]
    retention = cohort_data.unstack().divide(cohort_sizes, axis=0) * 100

    return retention
```

## Retention Benchmarks (SaaS Reference)

| Week | Poor | OK | Good | Excellent |
|------|------|----|------|-----------|
| W1 | <20% | 20-35% | 35-50% | >50% |
| W4 | <10% | 10-20% | 20-30% | >30% |
| W8 | <5% | 5-12% | 12-20% | >20% |

---

## Defining Your North Star Metric

```
Framework:
1. What creates real value for the user?  -> Conversations that generate insight/action
2. What predicts long-term growth?        -> Users with 3+ conversations per week
3. How to measure it?                     -> "Weekly Active Conversationalists" (WAC)

North Star: WAC (Weekly Active Conversationalists)
Definition: Users with >= 3 conversations per week lasting >= 2 minutes

Year 1 Target: 10,000 WAC
Year 2 Target: 100,000 WAC
```

## North Star Dashboard

```python
def calculate_north_star(db):
    wac = db.query("""
        SELECT COUNT(DISTINCT user_id) as wac
        FROM conversations
        WHERE
            created_at >= NOW() - INTERVAL '7 days'
            AND duration_seconds >= 120
        GROUP BY user_id
        HAVING COUNT(*) >= 3
    """).scalar()

    return {
        "wac": wac,
        "wow_growth": calculate_wow_growth(db, "wac"),
        "target": 10000,
        "progress": f"{wac/10000*100:.1f}%"
    }
```

---

## Feature Flags with PostHog

```python
def is_feature_enabled(user_id: str, feature: str) -> bool:
    return posthog.feature_enabled(feature, user_id)

if is_feature_enabled(user_id, "new-onboarding-v2"):
    show_new_onboarding()
else:
    show_old_onboarding()
```

## A/B Test Significance Calculator

```python
from scipy import stats
import numpy as np

def ab_test_significance(
    control_conversions: int,
    control_visitors: int,
    variant_conversions: int,
    variant_visitors: int,
    confidence: float = 0.95
) -> dict:
    control_rate = control_conversions / control_visitors
    variant_rate = variant_conversions / variant_visitors
    lift = (variant_rate - control_rate) / control_rate * 100

    _, p_value = stats.chi2_contingency([
        [control_conversions, control_visitors - control_conversions],
        [variant_conversions, variant_visitors - variant_conversions]
    ])[:2]

    significant = p_value < (1 - confidence)

    return {
        "control_rate": f"{control_rate*100:.2f}%",
        "variant_rate": f"{variant_rate*100:.2f}%",
        "lift": f"{lift:+.1f}%",
        "p_value": round(p_value, 4),
        "significant": significant,
        "recommendation": "Deploy variant" if significant and lift > 0 else "Keep control"
    }
```

---

## What This Skill Can Do For You

This is a skill, not a set of slash commands. Ask in plain language and it will help you with any of these actions:

| Action | What you get |
|--------|--------------|
| Design an event taxonomy | A named, `[object]_[past_verb]` event list mapped to your product's acquisition, activation, retention, and revenue stages |
| Analyse a conversion funnel | Step-by-step drop-off scoring against benchmarks, plus where to look next (session recordings, surveys) |
| Calculate cohort retention | A weekly retention matrix from your events, read against the SaaS benchmark table below |
| Define or review a north star metric | A single value-aligned metric (the WAC worked example shows the method) with year-one and year-two targets |
| Check A/B test significance | A p-value and lift verdict so you ship the variant only when the result is real, not noise |
| Set up a product dashboard | The metrics that belong on it (north star, funnel, retention curve) and the queries behind them |
| Draft product OKRs | An objective plus measurable key results tied to the metrics above |

## Best Practices

- Track outcomes, not clicks. An event like `upgrade_completed` is worth ten `button_clicked` events. Name events for what the user achieved.
- Pick exactly one north star metric and align it with user value, not vanity. Revenue is an outcome of the north star, not the north star itself.
- Hold an A/B test for a minimum of two full business weeks and require `p < 0.05` before you call a winner. Underpowered tests lie.
- Read retention as a curve that flattens, not a single number. A flat curve at any height beats a high W1 that decays to zero.
- Always read a metric against a benchmark. "30% W4 retention" means nothing until you know good SaaS is 20-30%.

## Common Pitfalls

- Vanity metrics. Page views, total signups, and cumulative downloads always go up and tell you nothing. Track active, retained, and converting users instead.
- Sample-ratio mismatch. If your A/B split should be 50/50 but the traffic lands 55/45, the randomisation is broken and the result is invalid before you even read the p-value.
- P-hacking. Peeking at the test daily and stopping the moment it crosses `p < 0.05` manufactures false winners. Fix the sample size and the duration up front.
- Celebrating bad retention. A W4 number looks fine until you compare it to the benchmark. Without the reference table you cannot tell a healthy curve from a leaking bucket.
- Aggregate-only thinking. A flat DAU line can hide that you are churning and re-acquiring the same volume. Cohort analysis exposes what the aggregate hides.

## Related Disciplines

- Growth experimentation: turns the funnel drop-offs this skill finds into acquisition and activation experiments.
- Monetization and pricing: takes the upgrade and revenue events defined here into pricing and packaging decisions.
- Product design: acts on the qualitative "why" behind the quantitative drop-offs this skill surfaces.
