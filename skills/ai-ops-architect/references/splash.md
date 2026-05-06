# /ai-ops-architect — what this is

> The driver agent prints this on first invocation in a session, then asks the user "ready?" before starting Phase 0. After it prints, the agent writes `.state/splash-shown` so subsequent invocations skip straight to the work.

```
                    YOU (or workshop attendee)
                            |
                            | "What should I automate?"
                            v
                  +-----------------------+
                  |   /ai-ops-architect   |   <-- THE BRAIN
                  | (orchestrator skill)  |       (8-question intake +
                  +-----------------------+        opportunity scoring +
                            |                      runtime decision)
                            |
            +---------------+---------------+
            |               |               |
            | "workflow"    | "agent"       | "both"
            v               v               v
     +-------------+  +--------------+  +-------------+
     |    /n8n     |  | /managed-    |  |  HYBRID     |
     | (workflows) |  |  agents-     |  |  (agent     |
     |             |  |  setup)      |  |  + n8n      |
     |             |  |              |  |  tools)     |
     +-------------+  +--------------+  +-------------+
            |               |               |
            +---------------+---------------+
                            |
                            v
                  +-----------------------+
                  |  Handoff one-pager    |
                  | (kill switch, cost,   |
                  |  what's running, URLs)|
                  +-----------------------+
```

## In one sentence

**You answer 8 short questions about your business. We rank what's worth automating. You pick 1-3. We build them and hand you a one-pager that tells you what's running and how to switch it off.**

## What we'll do together (Phase 0 → 7)

| Phase | What happens | Who does it |
|---|---|---|
| 0 | Quick check we have the tools we need | Claude (auto) |
| 1 | 8 questions about your business | You answer, Claude listens |
| 2 | Claude ranks 50+ patterns against your answers | Claude (auto) |
| 3 | You pick 1-3 you actually want | You |
| 4 | Claude picks the right runtime per pick | Claude (auto) |
| 5 | We build them | Claude (auto, you approve) |
| 6 | We connect any services needed (Stripe, Xero, etc.) | Claude + you for OAuth clicks |
| 7 | Handoff doc + kill switch + cost cap | Claude (auto) |

## What you'll never have to do

- Type a command line
- Write any code or JSON
- Configure a webhook URL
- Decide which side owns the credential
- Manage two skills in parallel

## What you can ask any time

- "Why this not that?"
- "What's the cost?"
- "Show me what's already running"
- "Pause the agent"
- "Walk me through the handoff again"

## Ready?

Type **yes** or hit enter to start Phase 0. Type **tell me more** to see the deeper how-it-works. Type **show me an example** to walk through a worked recipe (gym owner / lawyer / e-commerce).
