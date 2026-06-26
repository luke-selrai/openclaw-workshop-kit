---
name: analytics-product
description: 'Product analytics, PostHog, Mixpanel, events, funnels, cohorts, retention, north star metric, OKRs, and product dashboards. Use for: event tracking setup, conversion funnel analysis, cohort retention, DAU/MAU, feature flags, A/B testing, north star metrics, OKRs, product dashboards.'
risk: none
source: community
date_added: '2026-03-06'
tags:
- analytics
- product
- metrics
- posthog
- mixpanel
tools:
- claude-code
- cursor
- gemini-cli
---

# ANALYTICS-PRODUCT, Decide With Data

## Overview

Product analytics skill covering PostHog, Mixpanel, events, funnels, cohorts, retention, north star metric, OKRs, and product dashboards. Use for: event tracking setup, conversion funnel analysis, cohort retention, DAU/MAU, feature flags, A/B testing, north star metrics, OKRs, and product dashboards.

> Note: Code examples throughout this skill use a sample SaaS product as reference, adapt event names, metrics, and targets to your own product.

## When to Use This Skill

- When you need specialized assistance with this domain

## Do Not Use This Skill When

- The task is unrelated to analytics product
- A simpler, more specific tool can handle the request
- The user needs general-purpose assistance without domain expertise

## How It Works

```
[object]_[past_verb]

Correct:  user_signed_up, conversation_started, upgrade_completed
Wrong:    signup, click, conversion
```

## Analytics-Product, Decide With Data

> "In God we trust. All others must bring data.", W. Edwards Deming

---

## Essential Events (Example)

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

```python
from posthog import Posthog
import os

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
    posthog.identify(
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

## Commands

| Command | Action |
|---------|--------|
| `/event-taxonomy` | Define event taxonomy |
| `/funnel-analysis` | Analyse conversion funnel |
| `/cohort-retention` | Calculate cohort retention |
| `/north-star` | Define or review North Star Metric |
| `/ab-test` | Calculate A/B test significance |
| `/dashboard-setup` | Create product dashboard |
| `/okr-template` | OKR template for product teams |

## Best Practices

- Provide clear, specific context about your project and requirements
- Review all suggestions before applying them to production code
- Combine with other complementary skills for comprehensive analysis

## Common Pitfalls

- Using this skill for tasks outside its domain expertise
- Applying recommendations without understanding your specific context
- Not providing enough project context for accurate analysis

## Related Skills

- `growth-engine` - Complementary skill for enhanced analysis
- `monetization` - Complementary skill for enhanced analysis
- `product-design` - Complementary skill for enhanced analysis
- `product-inventor` - Complementary skill for enhanced analysis
