# Worked walkthrough — a real ai-ops-architect session

What an audit → opportunity-map session actually looks like, captured from a real run
(qa-harness, 2026-06-08). Use it to see the flow before you sit down with an owner.
This is the intended, hardened flow: **conversational intake → persist via `audit.sh --ingest`
→ `recommend.sh`** (no `AskUserQuestion`, no interactive terminal prompts).

---

**Owner:** "I run a small mobile car-detailing business with 2 staff. Everyone keeps telling me I
should be using AI but honestly I don't even know where to start. What should I automate?"

**ai-ops-architect:** Auto-invokes. It already knows the industry (mobile detailing) and team size
(you + 2), so it skips those and asks the rest **conversationally — plain text, reply however you
like** (it does NOT pop a multiple-choice UI):

> 1. What tools do you already use? (bookings, email, payments, accounting, customer chat)
> 2. Your top 3 time-wasters?
> 3. Rough monthly volumes (enquiries / jobs / messages-a-day)?
> 4. How techy are you, 1–5?
> 5. Monthly budget for tools + AI?
> 6. If you could magically fix ONE thing in 90 days, what would it be?

**Owner:** "Bookings: just a paper diary. Payments: Square. Email: Gmail. Accounting: my accountant
handles it. Customers mostly text me, some Facebook Messenger. Time-wasters: people text at 9pm for
a quote and I forget to reply; chasing review stars; re-typing booking details. ~50 quote requests
and ~40 jobs a month, ~15 messages a day. Tech comfort 2. Budget under $100. One thing: never miss
another quote request."

**ai-ops-architect:** "Got everything I need. Let me persist your answers and run the ranking." It
writes the answers to a temp JSON, then runs:

```bash
bash scripts/audit.sh --ingest /tmp/aoa-answers.json   # → .state/audit-result.json
bash scripts/recommend.sh                              # → .state/audit-output.md
```

**Output (`.state/audit-output.md`):**

```
# Your AI Ops Audit
**Industry**: trades · **Team**: 2-5 · **Tech comfort**: 2/5 · **Budget**: under-100
**North star**: never miss another quote request

## Top opportunities for you
### 1. Missed inbound call → SMS follow-up + CRM ticket
- Runtime: n8n   - Value: 6-10 hrs/mo (most missed calls = lost jobs)   - Difficulty: 30min-custom
### 2. Quote request → auto-acknowledge + CRM ticket
- Runtime: n8n   - Value: stops quote ghosting (the owner's #1 pain)
...
```

The owner confirms 1–3 to build; `bash scripts/select.sh --auto 1,2` writes
`.state/selected-builds.json` with the runtime + `delegate_to` per pick, and Phase 5 hands each to
`/n8n` or `/managed-agents-setup`.

---

*Provenance: captured from a qa-harness run on 2026-06-08 against the hardened skill
(transcript SHA256 `e89894625879078f737a06d456e5d7fbebcce089cc11d75eb9219672a6cf4eb0`).
A short screencast of this same flow is the next addition to this folder.*
