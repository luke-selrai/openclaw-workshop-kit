# Hybrid pattern - agent + n8n workflows as tools

## The 30-second version

Most automations look like one of these:

- **Pure workflow**: rule-based pipeline. Stripe payment → email customer → add to Xero. Predictable, cheap, no judgement needed.
- **Pure agent**: LLM in a loop. Read the inbox, decide what's urgent, draft replies. Judgement-heavy, more expensive per run.

The **hybrid** is the production pattern most builders skip:

> **An agent makes the decisions. n8n workflows are its hands.** The agent calls a workflow as a tool, the workflow does the deterministic mechanical work, the agent reads the result and decides the next move.

You burn LLM cost only at decision points. The boring "create the contact, send the email, log the row" steps are cheap n8n executions. You get judgement AND throughput without paying for either alone.

```
            +---------------------+
            |    Managed Agent    |
            |  (decides what to   |
            |   do, in plain      |
            |   English)          |
            +---------------------+
                    |
                    | "call the qualify_lead tool"
                    v
            +---------------------+
            | n8n webhook URL     |
            |  /webhook/qualify   |
            +---------------------+
                    |
                    v
            +---------------------+
            |   n8n workflow      |
            |  (Stripe lookup +   |
            |   GHL update +      |
            |   Slack ping +      |
            |   email send)       |
            +---------------------+
                    |
                    | returns JSON result
                    v
            +---------------------+
            |   Managed Agent     |
            |  (reads result,     |
            |   decides next move)|
            +---------------------+
```

## When the orchestrator should suggest hybrid

Use the hybrid path when ALL three are true:

- **Decision needs judgement** - "is this lead hot?", "is this email urgent?", "should we reply or escalate?"
- **Action is mechanical and reusable** - the actual CRM update / email send / database write is the same every time
- **The action involves 3+ services** - wiring those into the agent directly costs prompt tokens; wrapping them in one webhook is cheaper

If any one of those is false, pick a single runtime instead.

## Why workshop attendees can't figure this out themselves

Three real reasons:

1. **They don't know it's allowed.** Most n8n tutorials show pure workflow chains. Most managed-agent tutorials show the agent calling Anthropic's built-in tools (web search, code execution). Nobody shows them you can paste an n8n webhook URL into the agent's tool list as a custom tool.
2. **The tool JSON shape is intimidating.** `name`, `description`, `input_schema` with JSON Schema, `url`, auth headers - it's a wall of syntax to a non-coder.
3. **Connector ownership is unclear.** "Does the agent have the Xero credential, or the n8n workflow?" Right answer for hybrid: **n8n owns the credential**. The agent just calls a webhook with the result it wants. Cleaner security too - agent never sees raw API keys.

The orchestrator handles all 3 of those for them.

## Five worked recipes

### Recipe 1 - Hot lead triage

| | |
|---|---|
| **The agent's job** | Read incoming form submission, classify hot / warm / cold, route accordingly |
| **The n8n tools** | `qualify_lead(email, company, message)` returns `{tier, confidence}`<br>`route_hot_lead(contact_id, sales_rep)` does GHL update + SMS + Slack ping<br>`nurture_warm_lead(contact_id)` adds to email sequence + tags |
| **Run cost** | ~$0.005-0.01 per lead (one classification + one tool call) |
| **Why hybrid** | "Is this hot?" needs reading between the lines. The CRM update is identical every time. |

### Recipe 2 - Inbox triage

| | |
|---|---|
| **The agent's job** | Read each new email, classify (invoice question / support / urgent / spam), decide reply or escalate |
| **The n8n tools** | `lookup_invoice(customer_email)` queries Xero, returns invoice list<br>`create_support_ticket(subject, body, priority)` creates GHL ticket<br>`telegram_notify(message)` for urgent escalation |
| **Run cost** | ~$0.02-0.05 per email batch (multi-classify + lookups) |
| **Why hybrid** | Classification is judgement. Xero lookup, ticket creation, notifications are mechanical and identical. |

### Recipe 3 - Customer support replier (WhatsApp / SMS)

| | |
|---|---|
| **The agent's job** | Read incoming message, identify intent, decide reply or escalate to human |
| **The n8n tools** | `lookup_order_status(customer_phone)` queries Shopify<br>`process_refund_request(order_id, reason)` creates Shopify refund + emails confirmation<br>`escalate_to_human(conversation_id)` flags in CRM and pings team Slack |
| **Run cost** | ~$0.01-0.02 per message |
| **Why hybrid** | Intent recognition is LLM work. Order lookups and refund processing are pure mechanical Shopify calls. |

### Recipe 4 - Morning ops dashboard

| | |
|---|---|
| **The agent's job** | Pull yesterday's metrics, decide what's anomalous, write a 4-bullet summary in plain English, send to Telegram |
| **The n8n tools** | `pull_daily_metrics()` returns Stripe revenue + GHL bookings + ad spend (one workflow, three API calls)<br>`send_telegram(message)` posts to the user's chat (n8n owns the bot token; agent never sees it). If using Anthropic native Telegram MCP instead, credential moves to vault - note this consciously |
| **Run cost** | ~$0.015-0.04 per morning report |
| **Why hybrid** | The synthesis ("revenue dropped 30% but ad spend held steady - flag this") is judgement. The metric pull is three identical API calls every day. |

### Recipe 5 - Content publisher

| | |
|---|---|
| **The agent's job** | Generate a draft post from a brief, schedule it on the right platform |
| **The n8n tools** | `publish_to_instagram(image_url, caption, hashtags)` handles Buffer + Meta Graph API quirks<br>`publish_to_linkedin(text, image_url)` handles LinkedIn formatting<br>`schedule_post(platform, time, payload)` for delayed publish |
| **Run cost** | ~$0.04-0.10 per post (drafting heavy) (LLM does the writing) |
| **Why hybrid** | Drafting is creative work. The platform-specific publishing is mechanical and changes API contracts often - easier to maintain in n8n than in agent prompts. |

## How the orchestrator wires it (Phase 5)

When the user picks an opportunity flagged `runtime: hybrid`, the orchestrator runs both skills in sequence:

1. **First**: `/n8n` builds the workflows as webhook-callable endpoints. Each gets a unique URL like `https://selrai.app.n8n.cloud/webhook/qualify-lead`.
2. **Second**: `/managed-agents-setup` creates the agent. During Phase 5 (Create the agent), it reads the webhook URLs from the n8n build's output and uses `scripts/build-hybrid-tool.py` to generate the tool JSON spec, which the managed-agents-setup skill loads as the agent's tool definitions.
3. **The user sees**: one combined handoff doc listing the agent + all its workflow tools, with one kill switch that pauses everything.

## Connector strategy in hybrid mode

In a hybrid build, **the n8n workflow owns the credential**, not the agent. This is cleaner:

- Stripe API key lives in n8n's credential vault - the agent never sees it
- The agent just knows there's a tool called `lookup_invoice` that takes an email and returns invoice data
- If a credential rotates, only n8n needs updating; the agent's prompt doesn't change
- Audit trail is cleaner: every external API call has an n8n execution log entry

## Cost guardrails for hybrid builds

The cost monitor (managed-agents-setup `daily-cost-monitor.py`) tracks LLM spend on the agent. The n8n side is essentially free (n8n cloud bills per execution count, not per dollar of work).

Rule of thumb: a hybrid agent that runs 100 times a day with 2-3 tool calls per run costs around **$1-4/day** at workshop-attendee model choices (Sonnet 4.6 = $3/M input, $15/M output). The same logic done as a pure agent (every API call wrapped in a prompt, larger context per turn) typically runs **$10-25/day**. Hybrid is roughly 3-5x cheaper at the same throughput. **Numbers are ballpark - actual cost varies heavily with prompt size and output tokens. Use the cost monitor + Anthropic /v1/organizations/cost_report API for ground truth.**

## What the user does NOT need to learn

This is the whole point. A workshop attendee picking a hybrid opportunity:

- Does NOT write JSON tool schemas
- Does NOT figure out webhook URL conventions
- Does NOT decide which side owns the credential
- Does NOT manage two skills in parallel

The orchestrator does all of that. They pick the opportunity, approve the prompt, get the handoff one-pager.
