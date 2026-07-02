# Connector Recommender - Reference Documentation

## What Is It?

**Connector Recommender** is a Claude Code skill that acts as a business integration advisor. When a user describes their business or asks about tools, this skill identifies what kind of business they run, recommends the most impactful integrations (connectors), and helps set them up — all in plain language.

It removes the guesswork of "what tools should I connect?" by mapping business types to proven connector stacks.

## Why Does It Exist?

Users often:
- Don't know which connectors are available
- Don't know which ones matter for their specific business
- Get overwhelmed by too many options
- Need guidance on setup order and priority

This skill solves all four problems. It narrows the options, explains why each matters, and walks through setup one step at a time.

## How It Works

### Flow Overview

```
User describes business or asks about tools
              |
              v
    ┌─────────────────────┐
    │  Context Detection   │
    │  - Business type     │
    │  - Operations        │
    │  - Existing tools    │
    └──────────┬──────────┘
               |
        Is business type clear?
        /                    \
      YES                    NO
      /                        \
     v                          v
┌──────────────┐    ┌──────────────────┐
│  Recommend    │    │  Ask ONE question │
│  3-5 tools    │    │  about business   │
└──────┬───────┘    └────────┬─────────┘
       |                     |
       v                     v
  "Want me to          User answers
   set these up?"           |
       |                    v
   ┌───┴───┐          Back to recommend
   |       |
  YES      NO
   |       |
   v       v
 Setup    Done
 one by   (graceful
  one      exit)
   |
   v
 Summary
```

### Phase 1: Context Detection

The skill scans for three types of signals:

**Business type keywords:**
| Keyword | Maps to |
|---------|---------|
| online store, shopify, ecom | Ecommerce |
| agency, marketing, digital | Agency |
| SaaS, software, app, startup | SaaS |
| salon, clinic, restaurant, gym | Local Business |
| freelance, consultant, coach | Freelancer |
| realtor, property, real estate | Real Estate |
| contractor, construction, trades | Construction |

**Operations keywords:**
| Keyword | Maps to |
|---------|---------|
| leads, CRM, pipeline | Lead management tools |
| emails, communication | Email tools |
| schedule, bookings, appointments | Calendar tools |
| payments, billing, invoices | Payment tools |
| tracking, reports, analytics | Spreadsheet/database tools |

**Existing tools:**
Any tool the user mentions they already use is noted and excluded from recommendations.

### Phase 2: Recommendation Engine

Each business type has a curated connector stack, ranked by impact:

```
┌─────────────────────────────────────────────────────┐
│                  Connector Stacks                    │
├──────────────┬──────────────────────────────────────┤
│ Ecommerce    │ Shopify → Gmail → Sheets → Stripe → Notion │
│ Agency       │ GoHighLevel → Gmail → Calendar → Notion → Airtable │
│ SaaS         │ Stripe → Gmail → GitHub → Notion → Airtable │
│ Local Biz    │ Calendar → Gmail → Sheets → WhatsApp → Notion │
│ Freelancer   │ Gmail → Calendar → Stripe → Notion → Sheets │
│ Real Estate  │ Gmail → Calendar → Sheets → Airtable → Notion │
│ Construction │ Calendar → Gmail → Sheets → Airtable → Notion │
└──────────────┴──────────────────────────────────────┘
```

**Selection rules:**
- Always recommend 3-5 connectors (never more)
- Remove any the user already has
- Rank by impact for that business type
- If business is hybrid, merge stacks and deduplicate

### Phase 3: Presentation

Recommendations are shown as a numbered list with one-sentence reasons tied to the user's specific context. The format is consistent:

```
Based on your [business type], here are the integrations I'd recommend:

1. **[Tool]** — [why it matters for them]
2. **[Tool]** — [why it matters for them]
3. **[Tool]** — [why it matters for them]

Would you like me to set these up for you?
```

### Phase 4: Setup Execution

When the user agrees to setup, the skill uses MCP registry tools:

```
For each recommended connector:
    |
    v
Search MCP registry (search_mcp_registry)
    |
    ├── Already connected → Confirm ✓, move to next
    |
    └── Not connected → Show Connect button (suggest_connectors)
                              |
                              v
                        User clicks Connect
                              |
                              v
                        Confirm success → Next connector
```

**Setup is always sequential** — one connector at a time to avoid overwhelming the user.

After all connectors are handled, a summary is shown:

```
All set! Here's what's connected:
- Gmail ✓
- Google Calendar ✓
- Airtable ✓

You're ready to go.
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   User Message                        │
└─────────────────────┬────────────────────────────────┘
                      │
                      v
┌──────────────────────────────────────────────────────┐
│            Connector Recommender Skill                │
│                                                       │
│  ┌────────────────┐  ┌────────────────────────────┐  │
│  │ Context         │  │  Recommendation             │  │
│  │ Detector        │  │  Engine                     │  │
│  │ - biz type      │  │  - stack lookup             │  │
│  │ - operations    │  │  - dedup existing           │  │
│  │ - existing tools│  │  - rank by impact           │  │
│  └───────┬────────┘  └─────────────┬──────────────┘  │
│          │                         │                  │
│          v                         v                  │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Presentation Layer                   │ │
│  │  - numbered list, 1-line reasons                  │ │
│  │  - setup offer                                    │ │
│  └──────────────────────┬──────────────────────────┘ │
│                         │                             │
│                    User says yes                      │
│                         │                             │
│  ┌──────────────────────v──────────────────────────┐ │
│  │              Setup Executor                       │ │
│  │  - search_mcp_registry per connector              │ │
│  │  - suggest_connectors for unconnected             │ │
│  │  - one-at-a-time flow                             │ │
│  │  - summary at end                                 │ │
│  └─────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────┘
                      │
                      v
        ┌──────────────────────────┐
        │  MCP Registry Tools       │
        │  - search_mcp_registry    │
        │  - suggest_connectors     │
        └──────────────────────────┘
```

## Key Components

### Context Detector
- Scans for business type keywords, operation phrases, and existing tool mentions
- Classifies into one of 7 business categories (or hybrid)
- Falls back to operations-based mapping if business type is unclear

### Recommendation Engine
- Looks up the curated stack for the detected business type
- Removes tools the user already has
- Merges stacks for hybrid businesses
- Caps output at 5 connectors

### Presentation Layer
- Formats recommendations as a clean numbered list
- Attaches one-sentence reasons specific to the user's context
- Always ends with a setup offer

### Setup Executor
- Checks each connector's status via MCP registry
- Presents Connect buttons for unconnected tools
- Processes one at a time
- Provides a final summary

## Integration with Other Skills

| Skill | How they connect |
|-------|-----------------|
| **automation-intelligence** | After connectors are set up, suggest automating workflows with them |
| **n8n tools** | For complex multi-step workflows between connected tools |
| **schedule / loop** | For recurring tasks using connected connectors |

Typical flow: **connector-recommender** (what to connect) → **automation-intelligence** (when to run it) → **n8n / schedule** (how to execute it)

## Limitations

| Limitation | Detail |
|------------|--------|
| Connector availability | Can only recommend connectors available in the MCP registry |
| Custom integrations | Cannot set up custom API integrations or webhooks directly |
| Business type coverage | 7 predefined categories — unusual businesses fall back to operations-based mapping |
| Max recommendations | Hard cap of 5 per interaction |
| Setup scope | Drives the full install (Connect button for hosted connectors; CLI install + server registration for the rest). The user only approves the OAuth sign-in and any hard physical action |

## File Structure

```
~/.claude/skills/connector-recommender/
├── SKILL.md          # Skill definition (core logic + instructions)
├── EXAMPLES.md       # 5 full worked transcripts (the reference outputs)
├── TESTCASES.md      # 15 test scenarios with pass criteria
├── QA-NOTES.md       # Live skill-qa-harness run findings + fixes
└── REFERENCE.md      # This document
```

## FAQ

**Q: Can this skill recommend tools not in the MCP registry?**
It can mention them as suggestions, but it can only facilitate setup for tools available as MCP connectors. For unavailable tools, it suggests alternatives.

**Q: What if the user's business doesn't fit any category?**
The skill falls back to operations-based mapping — it matches what the user *does* (manage leads, send emails, track data) to the right connectors, regardless of business type.

**Q: Does this skill install anything?**
Yes, when a connector needs it. Hosted connectors (e.g. Gmail) are a one-click Connect button. Many others need a command-line tool installed and a server registered first — for those, Claude does the entire technical setup itself (via the dedicated `*-connector` skill or the connector's install pattern). The user never runs a command or installs anything by hand; they only approve the sign-in. Nothing is installed without the user agreeing to set the connector up.

**Q: Can the user skip some recommendations?**
Yes. During setup, each connector is presented individually. The user can skip any they don't want.

**Q: How does it handle a user with everything already connected?**
It checks the registry, confirms everything is connected, and offers to help automate workflows instead of suggesting more tools.
