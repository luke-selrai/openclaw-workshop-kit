# Connector Recommender - Test Cases

## How to verify this skill works (under 5 minutes)

Two levels of evidence back these cases:

1. **Recorded reference outputs** — [EXAMPLES.md](EXAMPLES.md) contains four full
   transcripts (user message → registry calls → verbatim assistant output) for
   the core paths. TC-01, TC-02/TC-07, TC-08 and TC-11 each map to a recorded
   example you can read against the criteria below. This is the fastest check.

2. **Live autonomous QA** — run the skill against a real Claude session with the
   [skill-qa-harness](https://github.com/selrai-company/skill-qa-harness). From a
   workspace where this skill is installed under `.claude/skills/`:

   ```bash
   node qa-driver.mjs \
     --cwd <workspace-with-connector-recommender> \
     --opening "I run an online store selling custom t-shirts, help me set up tools" \
     --no-playwright
   ```

   `--no-playwright` is correct: this skill drives no browser. Drive the
   conversation with the non-technical persona, then check the criteria below
   against the live turns. See [QA-NOTES.md](QA-NOTES.md) for the latest run's
   findings and known limitations (e.g. the MCP registry tools are absent in a
   bare SDK session — the skill must degrade gracefully).

The checkboxes below are **assertions to verify**, not a claim that they already
passed. A box maps to "this must be true of the output."

## TC-01: Ecommerce Business

**Input:** "I run an online store selling custom t-shirts"
**Expected Behavior:**
- Detects: "online store" → ecommerce
- Recommends: Shopify, Gmail, Google Sheets, Stripe, Notion
- Each connector has a 1-sentence reason
- Asks: "Would you like me to set these up?"

**Pass Criteria:**
- [x] Business type correctly identified as ecommerce
- [x] 3-5 connectors recommended
- [x] Shopify and Stripe included (core for ecom)
- [x] Reasons are relevant to selling t-shirts
- [x] Ends with setup offer

---

## TC-02: Marketing Agency

**Input:** "We're a digital marketing agency with about 15 clients"
**Expected Behavior:**
- Detects: "digital marketing agency" → agency
- Recommends: GoHighLevel, Gmail, Google Calendar, Notion, Airtable
- Acknowledges team/client context

**Pass Criteria:**
- [x] Business type correctly identified as agency
- [x] CRM tool recommended (GoHighLevel)
- [x] Project/client management tool included
- [x] Recommendations scaled for multi-client operation

---

## TC-03: SaaS Startup

**Input:** "I'm building a SaaS product for HR teams"
**Expected Behavior:**
- Detects: "SaaS product" → SaaS/startup
- Recommends: Stripe, Gmail, GitHub, Notion, Airtable
- Reasons relate to product development and user management

**Pass Criteria:**
- [x] Business type correctly identified as SaaS
- [x] Stripe included for billing
- [x] GitHub included for development
- [x] Recommendations fit product-building context

---

## TC-04: Local Business (Salon)

**Input:** "I own a hair salon downtown"
**Expected Behavior:**
- Detects: "salon" → local business
- Recommends: Google Calendar, Gmail, Google Sheets, WhatsApp Business, Notion
- Reasons relate to appointments and customer communication

**Pass Criteria:**
- [x] Business type correctly identified as local business
- [x] Google Calendar prioritized (appointment-heavy business)
- [x] WhatsApp included for customer messaging
- [x] No overly technical tools recommended

---

## TC-05: Freelancer

**Input:** "I'm a freelance graphic designer"
**Expected Behavior:**
- Detects: "freelance" → freelancer
- Recommends: Gmail, Google Calendar, Stripe, Notion, Google Sheets
- Reasons relate to client work and invoicing

**Pass Criteria:**
- [x] Business type correctly identified as freelancer
- [x] Payment tool included (Stripe)
- [x] Communication tool prioritized
- [x] Lean recommendations (no enterprise-scale tools)

---

## TC-06: Unclear Business Type

**Input:** "I need to set up some tools for my business"
**Expected Behavior:**
- Business type is unclear
- Asks ONE clarifying question
- Does NOT recommend anything yet

**Pass Criteria:**
- [x] Does NOT guess the business type
- [x] Asks exactly ONE question about business type
- [x] Question is friendly and gives examples
- [x] No recommendations before answer

---

## TC-07: User Already Mentions Tools

**Input:** "I run an agency and I already use Gmail and Notion"
**Expected Behavior:**
- Detects: agency + already uses Gmail and Notion
- Acknowledges existing tools
- Recommends remaining relevant ones (GoHighLevel, Calendar, Airtable)
- Does NOT re-recommend Gmail or Notion

**Pass Criteria:**
- [x] Acknowledges existing tools
- [x] Gmail and Notion NOT in recommendations
- [x] Remaining recommendations still relevant
- [x] Says something like "You're already using Gmail and Notion — great"

---

## TC-08: User Says Yes to Setup

**Input:** (after receiving recommendations) "Yes, set them up"
**Expected Behavior:**
- Checks connector availability via MCP registry
- Presents connected ones as ready
- Shows Connect buttons for unconnected ones
- Goes one at a time

**Pass Criteria:**
- [x] Uses `search_mcp_registry` to check each connector
- [x] Uses `suggest_connectors` for unconnected ones
- [x] One connector at a time (not all at once)
- [x] Confirms each successful connection
- [x] Provides summary at the end

---

## TC-09: User Declines Setup

**Input:** (after receiving recommendations) "Not right now, maybe later"
**Expected Behavior:**
- Respects the decision
- Does NOT push or re-ask
- Offers to help whenever they're ready

**Pass Criteria:**
- [x] No pressure to set up
- [x] Graceful acknowledgment
- [x] Brief response (1-2 sentences)
- [x] Does NOT list the connectors again

---

## TC-10: Real Estate Business

**Input:** "I'm a realtor working with residential buyers and sellers"
**Expected Behavior:**
- Detects: "realtor" → real estate
- Recommends: Gmail, Google Calendar, Google Sheets, Airtable, Notion
- Reasons relate to listings, viewings, and client management

**Pass Criteria:**
- [x] Business type correctly identified as real estate
- [x] Calendar included (viewings/open houses)
- [x] Tracking tool included (listings/deals)
- [x] Recommendations fit real estate workflow

---

## TC-11: Connector Not Available

**Input:** "Can you connect me to Salesforce?"
**Expected Behavior:**
- Searches MCP registry for Salesforce
- If not available, explains clearly
- Suggests alternatives or workarounds

**Pass Criteria:**
- [x] Searches registry before responding
- [x] Honest about unavailability
- [x] Suggests alternative (e.g., Airtable as CRM)
- [x] No jargon in explanation

---

## TC-12: Multiple Business Types

**Input:** "I run an ecommerce store and also do marketing consulting on the side"
**Expected Behavior:**
- Detects: ecommerce + consulting/agency
- Merges recommendations from both categories
- Keeps to 5 max, prioritizing overlap

**Pass Criteria:**
- [x] Both business types recognized
- [x] Recommendations cover both needs
- [x] Still capped at 5 connectors
- [x] Overlap tools mentioned once (e.g., Gmail)

---

## TC-13: Operations-Based Request (No Business Type)

**Input:** "I need to manage leads, send emails, and track my sales"
**Expected Behavior:**
- Detects operations: leads, email, sales tracking
- Maps to connectors without needing business type
- Recommends: Gmail, Airtable/GoHighLevel, Google Sheets

**Pass Criteria:**
- [x] Operations detected correctly
- [x] Does NOT ask for business type (enough info from operations)
- [x] Each connector mapped to a stated need
- [x] Recommendations are practical

---

## TC-14: No Integration Intent (Negative Case)

**Input:** "What's the weather like today?"
**Expected Behavior:**
- No integration or business signals detected
- Skill does NOT activate
- Handles normally

**Pass Criteria:**
- [x] No false positive trigger
- [x] No connector recommendations
- [x] Normal response

---

## TC-15: User Wants All At Once

**Input:** "Set up everything — Gmail, Calendar, Sheets, Notion, Airtable, Stripe, GitHub all at once"
**Expected Behavior:**
- Acknowledges the request
- Suggests starting with top 3 for biggest impact
- Proceeds one at a time in order of importance

**Pass Criteria:**
- [x] Does NOT attempt all 7 simultaneously
- [x] Suggests prioritization
- [x] Starts with most impactful
- [x] One-at-a-time setup flow

---

## Test Summary Matrix

| TC   | Input Type                | Recommends? | Setup? | Clarify? |
|------|---------------------------|-------------|--------|----------|
| TC-01| Ecommerce explicit        | Yes (5)     | Offers | No       |
| TC-02| Agency explicit           | Yes (5)     | Offers | No       |
| TC-03| SaaS explicit             | Yes (5)     | Offers | No       |
| TC-04| Local business explicit   | Yes (5)     | Offers | No       |
| TC-05| Freelancer explicit       | Yes (5)     | Offers | No       |
| TC-06| Unclear business          | No          | No     | Yes (1Q) |
| TC-07| Has existing tools        | Yes (3)     | Offers | No       |
| TC-08| User accepts setup        | N/A         | Runs   | No       |
| TC-09| User declines setup       | N/A         | No     | No       |
| TC-10| Real estate explicit      | Yes (5)     | Offers | No       |
| TC-11| Unavailable connector     | Alternative | No     | No       |
| TC-12| Multiple business types   | Yes (5)     | Offers | No       |
| TC-13| Operations only           | Yes (3)     | Offers | No       |
| TC-14| No intent (negative)      | No          | No     | No       |
| TC-15| Wants too many at once    | Prioritized | Staged | No       |
