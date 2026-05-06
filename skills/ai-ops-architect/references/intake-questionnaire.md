# Intake Questionnaire — 8 questions

The skill asks these in order, one screen at a time. Each answer is captured into `.state/audit-result.json` so subsequent phases can reference them. Skip-to-default is allowed if the user already has a populated `~/.claude/projects/-Users-<name>/memory/MEMORY.md` — `audit.sh` extracts what it can and only asks for gaps.

## The 8 questions

### 1. What's your industry or trade?
**Why we ask**: drives template-library filter and managed-agent preset selection.
**Format**: single-select with "Other (type yours)" fallback.
**Options**:
- Real estate (sales / property management)
- Trades (plumber, sparky, builder, HVAC, etc.)
- Coach / consultant / advisor
- Ecommerce / online store
- Agency (marketing, design, dev)
- Professional services (accounting, legal, allied health)
- Hospitality (cafe, restaurant, salon, gym)
- Creator / content business
- Other

### 2. How big is your team?
**Why we ask**: determines whether we lean on solo-friendly tooling or need shared inboxes / role-based access.
**Format**: single-select.
**Options**: Solo · 2-5 · 6-20 · 20-100 · 100+

### 3. Which of these tools are you already using? (multi-select)
**Why we ask**: drives connector strategy. Each toggled item is a candidate for Tier 1 (Claude Desktop passthrough) or Tier 2 (Rube) before we suggest installing anything new.
**Categories** (multi-select within each):
- **CRM**: GoHighLevel · HubSpot · Salesforce · Pipedrive · Airtable · Notion · None
- **Email**: Gmail / Google Workspace · Outlook / 365 · ProtonMail · Other
- **Calendar**: Google · Outlook · Calendly · Cal.com · None
- **Payments**: Stripe · Square · PayPal · Xero invoicing · None
- **Accounting**: Xero · QuickBooks · MYOB · None
- **Messaging**: Slack · Microsoft Teams · Telegram · Discord · None
- **Social**: Instagram (ManyChat?) · Facebook · LinkedIn · TikTok · YouTube · Twitter/X
- **Ecom**: Shopify · WooCommerce · Etsy · Amazon · None

### 4. What are your top 3 time-wasters right now?
**Why we ask**: opportunity-catalog matching. We rank candidates by which pains they kill.
**Format**: free text, three lines, ~one sentence each. Examples shown:
- "Manually retyping leads from Gmail into GHL"
- "Quote follow-ups falling through cracks"
- "Hand-copying invoice details into Xero"

### 5. Roughly how much volume per month?
**Why we ask**: scales the ROI calculation in the audit output ("this saves ~X hrs/month at YOUR volume"). Without this every estimate is generic.
**Format**: three numeric inputs with sensible defaults:
- New leads / enquiries / month: ___
- Customer transactions / month: ___
- Internal team messages or tasks / day: ___

### 6. Technical comfort, 1 to 5
**Why we ask**: gates whether we offer "auto-deploy" templates only, or include "30min-custom" options. Also shapes language in handoff docs.
**Format**: single-select 1-5.
- 1 = I avoid the terminal, please don't show me YAML
- 2 = I can copy-paste a key into a form
- 3 = I've used Zapier / n8n / Make before
- 4 = I write basic scripts, comfortable with APIs
- 5 = I can debug a webhook payload and read a stack trace

### 7. Monthly budget for tools and AI?
**Why we ask**: prevents the skill from recommending Managed Agents (~$0.08/sess-hr + tokens) for someone on a $50/mo budget. Also flags when Rube ($25/mo paid tier eventually) is acceptable vs free-tier-only.
**Format**: single-select.
- Under $100
- $100-$500
- $500-$2,000
- $2,000+

### 8. If you could fix ONE thing in the next 90 days, what would it be?
**Why we ask**: the north-star outcome. Phase 3 (select) defaults to whichever opportunity-catalog match has the highest correlation with this answer. Free text — examples shown:
- "Stop missing inbound leads"
- "Automate quote follow-ups"
- "Get my inbox to zero by Friday"
- "Daily sales pipeline visibility"

## Output shape

The 8 answers produce `.state/audit-result.json`:

```json
{
  "intake_completed_at": "2026-05-05T17:00:00Z",
  "industry": "trades",
  "team_size": "solo",
  "tools": {
    "crm": ["GoHighLevel"],
    "email": ["Gmail"],
    "calendar": ["Google"],
    "payments": ["Stripe"],
    "accounting": ["Xero"],
    "messaging": ["Telegram"],
    "social": [],
    "ecom": []
  },
  "pains": [
    "Quote follow-ups falling through cracks",
    "Manually copying job details from email into GHL",
    "No daily summary of new leads"
  ],
  "volume": {
    "leads_per_month": 60,
    "transactions_per_month": 25,
    "messages_per_day": 30
  },
  "tech_comfort": 3,
  "budget": "$100-$500",
  "north_star": "Stop letting quotes slip"
}
```

## Skip-to-default rules (Luke + future users with existing memory)

`audit.sh` extracts these without asking when memory contains them:
- `industry` → from `selrai-business-model.md` heading or known patterns
- `tools` → from MEMORY.md "Tools Connected" section
- `tech_comfort` → 5 if memory exists at all
- Defaults the rest to "answer me" — so even Luke gets asked the pains + north-star, because those change.

## Edit / update

The user can re-run `bash scripts/audit.sh --reset` to wipe and start over, or `--update <field>` to change one answer. The audit-result is a living doc; opportunities re-rank when it changes.
