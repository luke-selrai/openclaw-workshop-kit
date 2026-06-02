"""
ab-test-example.py runs the A/B significance calculator from the skill on
sample numbers so you see the shape of the verdict before wiring your own data.

Setup
-----
    pip install scipy

Run:
    python ab-test-example.py

Expected output (see the block comment at the bottom for the exact text):
the variant lifts conversion from 4.00% to 5.00%, the chi-square test returns
a p-value well under 0.05, so the recommendation is to deploy the variant.
"""

from scipy import stats


def ab_test_significance(
    control_conversions: int,
    control_visitors: int,
    variant_conversions: int,
    variant_visitors: int,
    confidence: float = 0.95,
) -> dict:
    control_rate = control_conversions / control_visitors
    variant_rate = variant_conversions / variant_visitors
    lift = (variant_rate - control_rate) / control_rate * 100

    _, p_value = stats.chi2_contingency(
        [
            [control_conversions, control_visitors - control_conversions],
            [variant_conversions, variant_visitors - variant_conversions],
        ]
    )[:2]

    significant = p_value < (1 - confidence)

    return {
        "control_rate": f"{control_rate*100:.2f}%",
        "variant_rate": f"{variant_rate*100:.2f}%",
        "lift": f"{lift:+.1f}%",
        "p_value": round(p_value, 4),
        "significant": significant,
        "recommendation": "Deploy variant"
        if significant and lift > 0
        else "Keep control",
    }


if __name__ == "__main__":
    # Control: 400 conversions / 10,000 visitors = 4.00%
    # Variant: 500 conversions / 10,000 visitors = 5.00%
    result = ab_test_significance(
        control_conversions=400,
        control_visitors=10_000,
        variant_conversions=500,
        variant_visitors=10_000,
    )
    for key, value in result.items():
        print(f"{key:>15}: {value}")

# Expected printed output:
#     control_rate: 4.00%
#     variant_rate: 5.00%
#             lift: +25.0%
#          p_value: 0.0007
#      significant: True
#   recommendation: Deploy variant
#
# (p_value uses scipy's default Yates continuity correction for a 2x2 table;
#  the exact value is ~0.00073, well under the 0.05 threshold.)
#
# A sample-ratio-mismatch caution: this example holds visitors equal at 10,000
# each. If your real split is lopsided (say 10,000 vs 8,200) when it was meant
# to be 50/50, fix the randomisation before trusting any p-value.
