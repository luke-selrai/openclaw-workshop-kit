---
description: Package one or more of the user's local skills, automations, or processes into a Remote Routine on claude.ai/code/routines so it runs on a schedule in the cloud, carrying across the tools and credentials it needs.
---

Invoke the `package-as-routine` skill to drive the full packaging flow.

If the user supplied a skill name (or names) in arguments, pass them along: `$ARGUMENTS`. Otherwise, let the skill discover what's available locally and ask the user which to package.

Follow the skill exactly. The flow is intentionally sequential with "tell me when done" checkpoints - do not collapse steps or skip helpers.
