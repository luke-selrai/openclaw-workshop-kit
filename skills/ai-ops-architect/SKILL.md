---
name: ai-ops-architect
description: Use when a user (especially a non-technical business owner or workshop attendee) wants to figure out what AI / automation to build for their business and actually deploy it. Runs an 8-question intake (or extracts from existing memory), produces an opportunity map ranked against their pains/tools/budget, then delegates building to /n8n or /managed-agents-setup based on the runtime decision matrix. Auto-invoke on phrases like "what should I automate", "where do I start", "audit my business for AI", "set up my AI ops", "what would you build for me", "I want to automate my business", "save me time on X", "I run a [business type] - what should I automate", "I want an AI assistant for my business but don't know where to start". Do NOT auto-invoke for narrow technical tasks already handled by /n8n or /managed-agents-setup directly.
---

# AI Ops Architect

> Pairs `/n8n` (workflows) + `/managed-agents-setup` (agents) into one guided experience. The user answers 8 questions, gets a ranked opportunity map, picks 1-3 to build, and the right child skill takes over.

## When to use

- New user / workshop attendee asks "what should I build?"
- Existing user wants a fresh audit ("what am I missing?")
- Onboarding a client - runs on their laptop, produces their plan

## When NOT to use

- User already knows what they want and which runtime - go directly to `/n8n` or `/managed-agents-setup`
- Narrow tweaks to existing workflows / agents - use the child skill that owns it
- Pure research / strategy questions with no build intent

## Phases

The skill walks Phase 0 → 7 in sequence, with confirmation between each.

| # | Phase | Script / output |
|---|-------|----------------|
| 0 | Pre-flight | We auto-check the few tools we need. If anything's missing, we tell you in plain English what to do - no command-line jargon. |
| 1 | Intake | ask 8 Qs conversationally → `bash scripts/audit.sh --ingest <answers.json>` → `.state/audit-result.json` |
| 2 | Audit | `bash scripts/recommend.sh` → `.state/audit-output.md` |
| 3 | Select | user picks 1-3 from top 5 opportunities |
| 4 | Route | per selection, decision matrix picks runtime |
| 5 | Build | delegates: workflow → `/n8n`, agent → `/managed-agents-setup`, **hybrid (agent + n8n tools) → both in sequence** (see `references/hybrid-pattern.md`) |
| 6 | Connect | Tier 1 (Claude Desktop) → Tier 2 (Rube) → Tier 3 (direct MCP) → Tier 4 (manual) |
| 7 | Handoff | one-page summary + URLs + cost guardrails |

## Quick start - intake mechanics (READ THIS; it is the #1 thing that breaks here)

The 8-question intake is **conversational**. YOU (Claude) ask the questions in plain English in the
chat; the owner replies in plain text. Then you persist the answers and rank.

1. **Ask the 8 questions conversationally** - batch them into 2-3 plain-text messages (content in
   `references/intake-questionnaire.md`). Do **NOT** use the `AskUserQuestion` tool: it errors in
   headless / automated / SDK runs and is not needed. Do **NOT** run `audit.sh` with no args - the
   interactive path uses python `input()` and needs a real TTY, so it hangs/crashes when you run it.
2. **Persist the answers** - write what you collected to a temp JSON file, then run:
   ```bash
   bash scripts/audit.sh --ingest /tmp/aoa-answers.json   # → .state/audit-result.json
   ```
   Shape: `{"industry","team_size","tools":{"crm":[],"email":[],"payments":[],"accounting":[]},
   "pains":[...],"volume":{"leads_per_month":N,"transactions_per_month":N,"messages_per_day":N},
   "tech_comfort":1-5,"budget","north_star"}`. Anything you omit is marked `TBC` (the script tells you which).
3. **Rank** - `bash scripts/recommend.sh` → writes `.state/audit-output.md`; read it back to the owner.
4. Owner picks 1-3 → the right child skill (`/n8n`, `/managed-agents-setup`) delegates the build.

> Phases 4-7 (Route/Build) read `.state/`. If you skip step 2, the chain has nothing to read - never
> free-style the ranking without persisting the audit first.

## Reference index - load on demand

| If user asks about | Load |
|---|---|
| "How do you decide which runtime?" | `references/runtime-decision-matrix.md` |
| "What automations do other businesses run?" | `references/opportunity-catalog.md` |
| "How does the connector setup work?" | `references/connector-strategy.md` (Phase 3) |
| "What questions will you ask me?" | `references/intake-questionnaire.md` |

## Hard rules

- **NEVER invent business facts** - if the audit can't tell whether a user has GHL or HubSpot, the skill asks. Sister to `feedback_never_fabricate_facts.md`.
- **Quality over coverage** - better to recommend 3 strong opportunities than 10 mid ones.
- **Free-the-user-from-typing** - every phase ends with a short confirmation, not a prompt-pile. Keep intake to 2-3 plain-text messages and ask conversationally; **never use the `AskUserQuestion` tool** for intake (it errors in headless/automated runs and is not needed).
- **Boundary card from /n8n still applies** - for Luke's own infra, n8n is for client work / explicit asks. The skill propagates this rule by reading `feedback_no_n8n.md` if it exists.

## Decision matrix (collapsed)

```text
client-facing? → n8n
webhook + 2+ SaaS + no reasoning? → n8n
webhook + reasoning? → server → Managed Agents
cadence < 1hr? → server cron (if available) else Routine
stateful conversation? → Managed Agents
cadence ≥ 1hr + reasoning? → Routines
cadence ≥ 1hr + bash? → server cron (else Routine)
else → server cron (else Routine)
```

Full version with comparison table and worked examples: `references/runtime-decision-matrix.md`.

## Worked examples

**User: "I'm a plumber, what should I automate?"**
→ Audit: industry=trades, top pain=missed quote follow-ups
→ Recommend: trades-quote-triage (managed-agent), missed-call-sms (n8n), daily-leads-digest (routine)
→ Build: managed-agents-setup creates the triage agent with Rube; n8n creates the SMS workflow; schedule skill creates the daily routine

**User: "I'm a coach with 50 IG DMs/day"**
→ Audit: industry=coaches, top pain=DM volume
→ Recommend: coach-dm-responder (managed-agent, Sonnet), ig-dm-to-crm (n8n), birthday-reach-out (routine)
→ Build: managed-agent connects to ManyChat via Rube, never-sells-first-message system prompt baked in

**User: "Audit my existing setup" (with populated MEMORY.md)**
→ audit.sh extracts industry/tools/comfort from memory → only asks for pains + north-star
→ recommend.sh ranks against the user's actual stack
→ Output skips opportunities they already have running

## Refusal rules

> Each rule is self-contained and stands on its own. The `feedback_*.md` citations point at the
> SelrAI internal-kit feedback files that *reinforce* these rules when that kit is present; they are
> optional - this skill does not ship them and does not depend on them.

- **"Build me everything you recommended"** → refuse bulk. Force selection of 1-3 max per session. Quality > volume.
- **"Use n8n for my own stack" (Luke specifically)** → refuse per `feedback_no_n8n.md` boundary, route to managed-agents/server-cron.
- **Anything Xero in n8n** → hard refuse, route to existing server scripts + MCP (per `n8n` skill's own boundary).
- **Generic "make a Claude bot"** → refuse without an outcome. The intake's north-star question is required.
- **"Just give me instructions, I'll deploy later"** → refuse for monitor/watchdog/alerter builds. Per `feedback_deploy_monitors_live.md`: monitors must be deployed live to AWS server with cron + Telegram wired before handoff. Setup instructions are not a delivered build.
- **Asserting venues, prices, dates, names without explicit source** → hard refuse per `feedback_never_fabricate_facts.md`. If user-provided source is missing for a real-world fact, mark as TBC and ask. Inference from past context is never confirmation.
- **Mixing personal finance / banking / tax / bankruptcy with marketing copy** → hard refuse per `feedback_no_finance_in_marketing.md`. Personal financial details are off-limits for any ad, post, sales asset, or public output.
- **Promising refunds / money-back / satisfaction guarantees in marketing** → hard refuse per `feedback_no_refund_promises.md`.
- **Promising ongoing support, weekly Q&A, or helpdesk in marketing copy** → hard refuse per `feedback_no_support_promises.md`. Use process language, not outcome guarantees.
- **Inviting casual drop-ins or free chats in copy** → hard refuse per `feedback_no_drop_in_invites.md`. Every unpaid chat displaces a $1,500 scoping call.

## State

`.state/` (chmod 700, gitignored) holds:
- `audit-result.json` - the 8-question answers
- `opportunities-ranked.json` - scored top-N
- `audit-output.md` - human-readable recommendation
- `selected-builds.json` - what the user picked to deploy this session
- `ship.log` - append-only, one line per completed deploy
