# Case 04 - LinkedIn post with chatbot artifacts

## Input

> Great question! Let's dive into this. I recently had the pleasure of working with an amazing team on a pivotal project. It's not just a product - it's a movement. We're embarking on a journey to revolutionize the space. Hope this helps!
>
> \#AI #Innovation #Leadership #Future #Tech #Startup #Growth

## Must-flag

- "Great question!" (chatbot artifact, P0)
- "Let's dive" (Let's construction)
- "I recently had the pleasure of" (template phrase)
- pivotal (Tier 1)
- "It's not just X - it's Y" (sentence-structure pattern)
- embarking (Tier 1)
- journey (significance inflation)
- revolutionize (Tier 2 + significance inflation)
- "Hope this helps!" (chatbot artifact, P0)
- 7 hashtags (hashtag stuffing, P0)
- em-dashes (frequency check)

## Must-not-survive

Great question, Let's dive, had the pleasure, pivotal, embarking, journey, revolutionize, Hope this helps

## Reference rewrite

> Spent two months with a small team rebuilding our onboarding flow. Drop-off at the email-verify step fell from 41% to 12%. Two things mattered: we let people skip verification until first save, and we replaced the welcome modal with a single inline prompt.

## Notes

The reference replaces filler-heavy "movement" rhetoric with two named metrics and two named decisions. If the rewrite keeps the post's shape but only swaps vocabulary, the second-pass audit should flag it as still vague - the underlying problem (no facts) is not solved by word substitution. Hashtag stuffing must be cut entirely or reduced to ≤3.
