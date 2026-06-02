# analytics-product examples

Runnable reference files for the analytics-product skill. They let you see the
shape of the output before you install anything against your own product.

| File | What it shows | Needs |
|------|---------------|-------|
| `posthog-init.py` | A PostHog init plus `track` / `identify` wrapper, env-var loaded, with a clean error if the key is missing | `pip install "posthog>=7" python-dotenv` and a `.env` with `POSTHOG_API_KEY` |
| `ab-test-example.py` | The significance calculator run on sample numbers, with the exact expected printed output in a comment | `pip install scipy` |
| `cohort-output.csv` | A small worked weekly-retention matrix so you see the shape of a cohort table | nothing, open it in any viewer |

The event names in these files come from a sample SaaS product. Rename them to
match what your own users actually do before shipping.
