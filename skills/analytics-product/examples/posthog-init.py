"""
posthog-init.py: runnable PostHog initialisation + track/identify wrapper.

This is the reference wrapper from the skill, ready to run. The event names
("conversation_started", etc.) come from a sample SaaS product. Rename them to
match what your own users actually do before you ship this.

Setup
-----
    pip install "posthog>=7" python-dotenv

This example targets the PostHog Python SDK v7+ (v7 removed identify(); use set()).

Put a .env file beside this script:

    POSTHOG_API_KEY=phc_your_project_key_here
    # optional, defaults to PostHog Cloud US:
    # POSTHOG_HOST=https://eu.posthog.com

Use your PostHog PROJECT API key (the phc_... ingest key), NOT a personal API key.

Then run:

    python posthog-init.py

If POSTHOG_API_KEY is missing, the script prints exactly what to fix and exits
without crashing, so a non-Python-native reader does not fall on the env step.
"""

import os
import sys

try:
    from dotenv import load_dotenv
    from posthog import Posthog
except ImportError:
    print(
        "Required libraries are not installed.\n"
        "Install them, then run this script again:\n"
        "    pip install posthog python-dotenv\n"
        "then run:  python posthog-init.py",
        file=sys.stderr,
    )
    sys.exit(1)

load_dotenv()  # reads POSTHOG_API_KEY (and POSTHOG_HOST) from .env beside this file

API_KEY = os.environ.get("POSTHOG_API_KEY")
if not API_KEY:
    print(
        "POSTHOG_API_KEY is not set.\n"
        "Create a .env file beside this script containing:\n"
        "    POSTHOG_API_KEY=phc_your_project_key_here\n"
        "then run:  pip install posthog python-dotenv  &&  python posthog-init.py",
        file=sys.stderr,
    )
    sys.exit(1)

posthog = Posthog(
    project_api_key=API_KEY,
    host=os.environ.get("POSTHOG_HOST", "https://app.posthog.com"),
)


def track(user_id: str, event: str, properties: dict | None = None) -> None:
    """Capture a product event. Event names follow [object]_[past_verb]."""
    posthog.capture(
        distinct_id=user_id,
        event=event,
        properties=properties or {},
    )


def identify(user_id: str, traits: dict) -> None:
    """Attach traits to a user so cohorts and funnels can segment on them."""
    # PostHog 7.x removed identify(); set() updates the person's traits.
    posthog.set(
        distinct_id=user_id,
        properties=traits,
    )


if __name__ == "__main__":
    # A worked example. Replace the event name and properties with your own.
    identify("user_123", {"plan": "pro", "signup_source": "organic"})

    track(
        "user_123",
        "conversation_started",
        {
            "intent": "business_advice",
            "device": "mobile",
            "user_tier": "pro",
        },
    )

    # capture() is async/batched; flush before the process exits so the event sends.
    posthog.flush()
    print("Sent identify + conversation_started for user_123. Check PostHog Live Events.")
