# Opportunity Catalog - 60 SMB automation patterns

Each pattern is one row of a static catalog the audit phase ranks against the user's intake. Match score uses: industry tag overlap × pain-keyword match × tools-they-have coverage.

Schema for each entry:
- **id** (slug)
- **title** (one-line outcome)
- **industries** (tags)
- **trigger** (one line)
- **runtime** (n8n / managed-agent / routine / server-cron - per decision matrix)
- **services** (required external services)
- **value** (estimated hrs/mo saved at typical SMB volume)
- **difficulty** (auto-deploy / 5min-config / 30min-custom)
- **pain_keywords** (substrings that match user's free-text pains)

---

## Lead capture (8)

### lead-form-to-crm
- **title**: Web form submission → contact in CRM with tags
- **industries**: all
- **trigger**: webform POST to webhook
- **runtime**: n8n
- **services**: web form provider, CRM
- **value**: 4-8 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: lead, form, retype, manual entry, CRM

### stripe-payment-to-crm
- **title**: Stripe payment → contact + receipt + tag in CRM
- **industries**: ecommerce, coaches, consultants, agencies, hospitality
- **trigger**: Stripe webhook (charge.succeeded)
- **runtime**: n8n
- **services**: Stripe, CRM
- **value**: 3-5 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: payment, stripe, receipt, customer, post-purchase

### calendly-booking-flow
- **title**: Calendly booking → CRM contact + calendar event + welcome email
- **industries**: coaches, consultants, professional-services, real-estate
- **trigger**: Calendly webhook
- **runtime**: n8n
- **services**: Calendly, CRM, email/calendar
- **value**: 2-4 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: booking, calendly, calendar, appointment

### missed-call-sms
- **title**: Missed inbound call → SMS follow-up + CRM ticket
- **industries**: trades, real-estate, hospitality, professional-services
- **trigger**: VoIP/Twilio missed-call webhook
- **runtime**: n8n
- **services**: VoIP/Twilio, SMS, CRM
- **value**: 6-10 hrs/mo (huge for trades - most missed calls = lost jobs)
- **difficulty**: 30min-custom
- **pain_keywords**: missed, call, phone, callback

### linkedin-msg-to-crm
- **title**: LinkedIn DM → CRM contact + drip sequence
- **industries**: agencies, consultants, b2b
- **trigger**: LinkedIn (manual export or PhantomBuster)
- **runtime**: n8n
- **services**: LinkedIn / PhantomBuster, CRM, email
- **value**: 3-5 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: linkedin, outreach, b2b

### ig-dm-to-crm
- **title**: Instagram DM → ManyChat → CRM with intent tag
- **industries**: coaches, creators, ecommerce, hospitality
- **trigger**: ManyChat flow
- **runtime**: n8n (transform) + managed-agent (qualify intent)
- **services**: ManyChat, CRM
- **value**: 8-15 hrs/mo for high-DM accounts
- **difficulty**: 30min-custom
- **pain_keywords**: dm, instagram, ig, manychat

### form-with-attachment
- **title**: Webform with file upload → cloud storage + CRM note
- **industries**: trades, real-estate, professional-services
- **trigger**: form POST with file
- **runtime**: n8n
- **services**: form provider, Google Drive / Dropbox, CRM
- **value**: 2-4 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: attachment, file, document, upload

### newsletter-signup-sync
- **title**: Mailchimp / ConvertKit signup → CRM contact
- **industries**: creators, coaches, ecommerce
- **trigger**: ESP webhook
- **runtime**: n8n
- **services**: Mailchimp/ConvertKit, CRM
- **value**: 2-3 hrs/mo
- **difficulty**: auto-deploy
- **pain_keywords**: newsletter, mailchimp, signup, list

---

## Email (6)

### inbox-triage-agent
- **title**: Triage incoming email by intent → tag + auto-reply
- **industries**: all
- **trigger**: Gmail/Outlook poll every 15min
- **runtime**: managed-agent (Haiku for high volume)
- **services**: email, CRM
- **value**: 6-12 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: inbox, email, triage, sort, reply

### quote-request-ack
- **title**: Quote request email → auto-acknowledge + CRM ticket
- **industries**: trades, agencies, professional-services
- **trigger**: email with subject keywords
- **runtime**: n8n
- **services**: email, CRM
- **value**: 3-5 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: quote, request, acknowledge

### no-reply-followup
- **title**: Auto-schedule follow-up if no reply in 3 days
- **industries**: agencies, consultants, trades
- **trigger**: email sent (tracked)
- **runtime**: n8n + scheduled-task
- **services**: email, CRM
- **value**: 4-8 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: follow-up, no reply, ghosted, chase

### daily-leads-digest
- **title**: Daily digest of yesterday's new leads to Slack/Telegram
- **industries**: all
- **trigger**: cron 9am daily
- **runtime**: routine
- **services**: CRM, Slack/Telegram
- **value**: 1-2 hrs/mo (visibility)
- **difficulty**: auto-deploy
- **pain_keywords**: digest, summary, daily, visibility

### email-attachment-to-invoice
- **title**: Supplier invoice email → draft Xero/QuickBooks bill
- **industries**: trades, agencies, professional-services
- **trigger**: email with PDF attachment matching pattern
- **runtime**: n8n + managed-agent (OCR/parse)
- **services**: email, OCR, Xero/QB
- **value**: 4-8 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: invoice, bill, supplier, xero, accounting

### email-parser-to-crm
- **title**: Parse structured fields from email body into CRM
- **industries**: real-estate, agencies
- **trigger**: email matching template
- **runtime**: n8n
- **services**: email, CRM
- **value**: 3-6 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: parse, extract, fields, REA, domain

---

## CRM / Pipeline (6)

### stale-lead-detector
- **title**: Lead untouched 7+ days → reminder to owner
- **industries**: all
- **trigger**: daily scan of CRM
- **runtime**: routine
- **services**: CRM, Slack/Telegram
- **value**: 4-8 hrs/mo (saves dropped leads)
- **difficulty**: 5min-config
- **pain_keywords**: stale, dropped, forgotten, lost

### pipeline-stage-auto
- **title**: Auto-move pipeline stage based on activity (call done, email opened)
- **industries**: agencies, real-estate, consultants
- **trigger**: CRM activity event
- **runtime**: n8n
- **services**: CRM
- **value**: 2-3 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: pipeline, stage, manual, status

### new-lead-realtime-ping
- **title**: New CRM lead → instant Slack/Telegram ping with details
- **industries**: all (esp. solo)
- **trigger**: CRM webhook on new contact
- **runtime**: n8n
- **services**: CRM, messaging
- **value**: 1-2 hrs/mo (speed-to-lead)
- **difficulty**: auto-deploy
- **pain_keywords**: notify, alert, instant, lead

### won-deal-fulfillment
- **title**: Deal marked won → kick off fulfillment checklist + welcome email
- **industries**: agencies, consultants, ecommerce
- **trigger**: CRM stage change to "Won"
- **runtime**: n8n
- **services**: CRM, email, project tool
- **value**: 3-5 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: onboard, won, kickoff, fulfillment

### lost-lead-winback
- **title**: Lead marked lost → 30/60/90 day win-back sequence
- **industries**: agencies, ecommerce, real-estate
- **trigger**: CRM stage change to "Lost"
- **runtime**: n8n + scheduled
- **services**: CRM, email
- **value**: 2-4 hrs/mo + win-back revenue
- **difficulty**: 5min-config
- **pain_keywords**: lost, winback, re-engage

### birthday-reach-out
- **title**: Customer birthday → personalised SMS / email
- **industries**: hospitality, salons, ecommerce
- **trigger**: daily CRM scan
- **runtime**: routine
- **services**: CRM, SMS/email
- **value**: 1-2 hrs/mo (relationship)
- **difficulty**: auto-deploy
- **pain_keywords**: birthday, anniversary, retention

---

## Ecommerce (5)

### shopify-order-log
- **title**: Shopify order → Notion log + receipt + Slack alert
- **industries**: ecommerce
- **trigger**: Shopify webhook (orders/create)
- **runtime**: n8n
- **services**: Shopify, Notion, Slack
- **value**: 3-5 hrs/mo
- **difficulty**: auto-deploy
- **pain_keywords**: order, shopify, log, fulfillment

### abandoned-cart
- **title**: Abandoned cart → email + SMS sequence
- **industries**: ecommerce
- **trigger**: Shopify checkout abandonment event
- **runtime**: n8n + scheduled
- **services**: Shopify, email, SMS
- **value**: 4-8 hrs/mo + recovered revenue
- **difficulty**: 5min-config
- **pain_keywords**: cart, abandon, recovery

### refund-handler
- **title**: Refund → CRM tag + auto-survey
- **industries**: ecommerce
- **trigger**: Stripe/Shopify refund event
- **runtime**: n8n
- **services**: Stripe/Shopify, CRM, survey tool
- **value**: 1-2 hrs/mo
- **difficulty**: auto-deploy
- **pain_keywords**: refund, return, churn

### oos-reorder-draft
- **title**: Out-of-stock → draft supplier reorder email
- **industries**: ecommerce
- **trigger**: Shopify inventory webhook
- **runtime**: n8n + managed-agent (drafts email)
- **services**: Shopify, email
- **value**: 3-5 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: stock, inventory, reorder, supplier

### review-response-draft
- **title**: New product review → draft response in your voice
- **industries**: ecommerce
- **trigger**: review platform webhook
- **runtime**: managed-agent (Sonnet for tone)
- **services**: review platform, email
- **value**: 2-4 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: review, response, reputation

---

## Content / Social (5)

### blog-to-social
- **title**: New blog post → cross-post to LinkedIn + X + IG
- **industries**: creators, agencies, b2b
- **trigger**: RSS / CMS webhook
- **runtime**: n8n + managed-agent (rewrite per platform)
- **services**: CMS, LinkedIn, X, IG
- **value**: 3-6 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: blog, social, cross-post, distribution

### youtube-to-blog
- **title**: New YouTube upload → blog post draft + email newsletter
- **industries**: creators, coaches
- **trigger**: YouTube RSS/webhook
- **runtime**: managed-agent (long-form drafting)
- **services**: YouTube, CMS, ESP
- **value**: 4-8 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: youtube, repurpose, content

### social-mentions-monitor
- **title**: Brand mentions on X/IG/Reddit → Slack + CRM tag
- **industries**: agencies, creators, ecommerce
- **trigger**: search API poll
- **runtime**: routine
- **services**: search API, Slack, CRM
- **value**: 2-4 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: mentions, brand, listening

### content-calendar-fill
- **title**: Idea bank → auto-fill empty slots in content calendar
- **industries**: creators, agencies, coaches
- **trigger**: weekly cron
- **runtime**: routine
- **services**: Notion/Airtable, CMS
- **value**: 2-3 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: content, calendar, schedule, ideas

### social-engagement-tag
- **title**: User comments/likes 3+ times → CRM warm-lead tag
- **industries**: coaches, creators, ecommerce
- **trigger**: social API poll
- **runtime**: managed-agent + n8n
- **services**: social API, CRM
- **value**: 3-6 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: engagement, warm, lead, fan

---

## Ops / Monitoring (4)

### daily-kpis-digest
- **title**: Daily digest of revenue, leads, bookings, errors
- **industries**: all
- **trigger**: cron 8am
- **runtime**: routine
- **services**: CRM, Stripe, calendar, monitoring
- **value**: 1-2 hrs/mo (visibility)
- **difficulty**: 5min-config
- **pain_keywords**: kpi, dashboard, daily, summary

### uptime-monitor
- **title**: Website / API down → Telegram + on-call
- **industries**: all (digital businesses)
- **trigger**: cron every 5min
- **runtime**: server-cron (sub-1hr) or 3rd-party uptime
- **services**: monitoring, Telegram
- **value**: priceless when it fires
- **difficulty**: 5min-config
- **pain_keywords**: down, uptime, monitor, alert

### saas-spend-audit
- **title**: Monthly SaaS spend audit → list unused subs
- **industries**: all
- **trigger**: monthly cron
- **runtime**: routine
- **services**: bank/credit-card feed (Plaid/Akahu/Revolut), email
- **value**: $$ saved
- **difficulty**: 30min-custom
- **pain_keywords**: subscriptions, saas, waste, spend

### error-on-call
- **title**: Critical error in app → Telegram + create Linear issue
- **industries**: all (digital)
- **trigger**: error log webhook
- **runtime**: n8n
- **services**: log source, Telegram, Linear
- **value**: response time
- **difficulty**: 5min-config
- **pain_keywords**: error, alert, on-call, bug

---

## Finance (4)

### invoice-from-timesheet
- **title**: Hubstaff/Toggl timesheet → draft Xero invoice
- **industries**: agencies, consultants, professional-services
- **trigger**: weekly cron
- **runtime**: routine + n8n
- **services**: Hubstaff/Toggl, Xero
- **value**: 3-6 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: timesheet, invoice, hubstaff, toggl

### receipt-ocr-expense
- **title**: Receipt photo (email/Telegram) → categorised expense in Xero
- **industries**: all
- **trigger**: receipt arrives
- **runtime**: managed-agent (OCR + categorise)
- **services**: email/Telegram, Xero, OCR
- **value**: 4-8 hrs/mo at tax time
- **difficulty**: 30min-custom
- **pain_keywords**: receipt, expense, categorise, xero

### overdue-invoice-reminder
- **title**: Overdue invoice (7/14/30 days) → escalating reminders
- **industries**: agencies, consultants, trades
- **trigger**: daily cron
- **runtime**: routine
- **services**: Xero, email, SMS
- **value**: cash flow
- **difficulty**: auto-deploy
- **pain_keywords**: overdue, invoice, debtor, chase

### bank-txn-categorise
- **title**: New bank txn → auto-categorise + push to Xero
- **industries**: all
- **trigger**: bank API webhook
- **runtime**: managed-agent (Haiku)
- **services**: bank API, Xero
- **value**: 6-12 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: bank, transaction, categorise, reconcile

---

## AI Agents - high leverage (5)

### support-triage-agent
- **title**: Inbound support ticket → categorise + draft reply
- **industries**: all
- **trigger**: helpdesk webhook
- **runtime**: managed-agent (Haiku)
- **services**: helpdesk (Zendesk/Intercom/Front), CRM
- **value**: 8-20 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: support, ticket, helpdesk, triage

### lead-qualifier-agent
- **title**: New lead → research + qualify + score before owner sees
- **industries**: agencies, b2b, consultants
- **trigger**: CRM new contact
- **runtime**: managed-agent (Sonnet)
- **services**: CRM, web_search, LinkedIn
- **value**: 6-10 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: qualify, score, research, BANT

### proposal-drafter-agent
- **title**: Calendly call booked → research prospect → draft pre-call brief
- **industries**: consultants, agencies, professional-services
- **trigger**: Calendly webhook
- **runtime**: managed-agent (Opus for quality)
- **services**: Calendly, web_search, doc tool
- **value**: 4-8 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: proposal, prospect, prep, brief

### research-agent
- **title**: Topic / competitor → daily/weekly research digest
- **industries**: agencies, consultants, ecommerce
- **trigger**: weekly cron + on-demand
- **runtime**: managed-agent (Sonnet) or routine
- **services**: web_search, doc tool
- **value**: 3-6 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: research, competitor, intel

### content-gen-agent
- **title**: One topic → caption + hook + email + thread
- **industries**: creators, coaches, agencies
- **trigger**: on-demand
- **runtime**: managed-agent
- **services**: writing platforms
- **value**: 4-8 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: caption, hook, copy, write

---

## Industry-specific (7)

### trades-quote-triage
- **title**: Quote request → urgency + size classify → reply + GHL pipeline
- **industries**: trades
- **trigger**: email + form + ManyChat poll
- **runtime**: managed-agent (Haiku) + n8n
- **services**: email, ManyChat, CRM
- **value**: 8-15 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: quote, trade, plumber, sparky, builder

### realestate-viewing-followup
- **title**: Viewing booked → confirmation + day-of reminder + post-viewing follow-up
- **industries**: real-estate
- **trigger**: viewing scheduled
- **runtime**: n8n
- **services**: CRM, SMS, email
- **value**: 5-8 hrs/mo
- **difficulty**: 5min-config
- **pain_keywords**: viewing, inspection, real estate

### coach-dm-responder
- **title**: IG DM → context-aware reply that never sells in first message
- **industries**: coaches, consultants
- **trigger**: ManyChat / IG webhook
- **runtime**: managed-agent (Sonnet)
- **services**: ManyChat, CRM
- **value**: 10-20 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: dm, coach, instagram, mentor

### agency-client-onboard
- **title**: New deal won → 14-step onboarding sequence (kickoff, intake, access)
- **industries**: agencies
- **trigger**: CRM stage Won
- **runtime**: n8n + scheduled
- **services**: CRM, email, project tool, doc tool
- **value**: 6-12 hrs/mo per new client
- **difficulty**: 30min-custom
- **pain_keywords**: onboard, agency, kickoff, intake

### restaurant-reservation
- **title**: Booking via OpenTable / web → confirmation + day-of SMS + post-visit review ask
- **industries**: hospitality (restaurants)
- **trigger**: booking platform webhook
- **runtime**: n8n
- **services**: booking platform, SMS, review platform
- **value**: 4-8 hrs/mo + reviews
- **difficulty**: 5min-config
- **pain_keywords**: booking, reservation, restaurant, table

### salon-booking-confirm
- **title**: Mindbody / Fresha booking → confirm + 24h reminder + rebook ask
- **industries**: hospitality (salons, fitness)
- **trigger**: booking platform webhook
- **runtime**: n8n
- **services**: Mindbody/Fresha, SMS, email
- **value**: 5-10 hrs/mo + retention
- **difficulty**: 5min-config
- **pain_keywords**: booking, salon, fitness, mindbody

### property-mgmt-maintenance
- **title**: Tenant maintenance request → triage urgency + dispatch + tenant updates
- **industries**: real-estate (property mgmt)
- **trigger**: email/form/portal
- **runtime**: managed-agent (Haiku for triage) + n8n
- **services**: email/form, CRM, SMS, contractor list
- **value**: 8-15 hrs/mo
- **difficulty**: 30min-custom
- **pain_keywords**: maintenance, tenant, property, repair

---

## Match scoring (used by recommend.sh)

For each opportunity, `recommend.sh` computes:
```
score = +3   if the user's industry is in the opportunity's industries (or industries = "all")
      + 5    per matched pain keyword (opportunity pain_keywords found in the user's pains + north-star)
      + 2    per service the user already has that the opportunity needs
      - 3    if difficulty is "30min-custom" and tech_comfort <= 2
      + 1    if difficulty is "auto-deploy"
```

Opportunities scoring > 0 are ranked highest-first; the top 5 are shown. (No budget term is applied today - keep this block in sync with `recommend.sh` `score()`.)

## How this catalog grows

This is v1 - 50 patterns. Each new client engagement should produce 1-2 new patterns observed from real workflows. PR them into this file with the same schema. The catalog is the moat: the more patterns we have, the better the matching, the more value users get on first run.

## Sister skills (delegate, don't reinvent)

When an opportunity is heavy on a single domain, delegate to the sister skill rather than building from scratch:

| Domain emphasis | Skill to delegate to | Why |
|---|---|---|
| Marketing-heavy (ads, content, brand, SEO, social posting) | `/marketing-agency` | Full autonomous marketing replacement: scrapes business + competitors, plans campaigns, creates content, schedules posts |
| User wants integration suggestions but no build yet | `/connector-recommender` | Detects business type and recommends + sets up the highest-impact integrations. Run BEFORE Phase 6 if user is unsure which services they need |
| User wants the menu of all available skills | `/skills-discovery` | Workshop attendee tour of the 22 core skills in plain English. Reference at Phase 7 handoff |
| Single managed-agent build, no orchestration needed | `/managed-agents-setup` | Phase 0 to 7 install of one Anthropic Managed Agent + Routine. Already delegated to in Phase 5 |
| Single n8n workflow, no orchestration needed | `/n8n` | Workflow runtime sister skill. Already delegated to in Phase 5 |

## Professional services patterns (legal, accounting, consultants)

Service businesses bill on time, not products. The general catalog skews e-commerce/SaaS - these are the patterns that actually fit a 5-10 person professional firm.

### legal-conflict-check
- **title**: New matter intake → search client/matter DB → flag conflicts → hold for partner sign-off
- **industries**: professional-services
- **runtime**: hybrid
- **services**: practice management DB, document store
- **value**: compliance must-have (avoids a conflict-of-interest breach)
- **difficulty**: 30min-custom
- **pain_keywords**: conflict check, matter intake, compliance, legal, due diligence

### matter-intake-to-billing
- **title**: New-matter event (Clio/LEAP/LawMaster) → Xero retainer invoice + time-entry shell + welcome
- **industries**: professional-services
- **runtime**: n8n
- **services**: Clio, LEAP, Xero
- **value**: 2-4 hrs/wk of admin
- **difficulty**: 30min-custom
- **pain_keywords**: matter intake, retainer, invoice, onboarding, billing

### time-entry-to-wip-bill
- **title**: Toggl/Hubstaff/Harvest weekly export → group by matter → draft Xero invoice for review
- **industries**: professional-services
- **runtime**: n8n
- **services**: Toggl, Harvest, Xero
- **value**: hours saved every billing cycle
- **difficulty**: 30min-custom
- **pain_keywords**: time entry, wip, billing, invoice, timesheet

### trust-account-reconcile
- **title**: Daily bank feed → match trust receipts to matter ledgers → flag unallocated funds
- **industries**: professional-services
- **runtime**: hybrid
- **services**: bank feed, trust ledger
- **value**: avoids a disciplinary trust-account breach
- **difficulty**: 30min-custom
- **pain_keywords**: reconciliation, trust account, compliance, ledger, accounting

### client-doc-request
- **title**: Matter awaiting docs 7+ days → personalised reminder email + Slack ping to the associate
- **industries**: professional-services
- **runtime**: hybrid
- **services**: email, Slack, practice management DB
- **value**: matters move faster, less manual chasing
- **difficulty**: 5min-config
- **pain_keywords**: document chase, reminder, follow-up, awaiting docs, outstanding

`runtime: hybrid` entries are offered, not forced - see `hybrid-pattern.md`. Pure-`n8n` entries deploy as a single workflow with no agent.

## Hybrid opportunities (Agent + n8n tools)

These are flagged `runtime: hybrid`. The orchestrator offers them with hybrid as the suggested default, single-runtime as fallback options. See `hybrid-pattern.md` for the full pattern.

### hot-lead-triage-hybrid
- **title**: Agent classifies new leads (hot/warm/cold) → routes hot to sales SMS+CRM, warm to email sequence
- **industries**: all
- **runtime**: hybrid
- **services**: CRM, SMS, email
- **value**: more hot leads worked, fewer dropped
- **difficulty**: 30min-custom
- **pain_keywords**: lead triage, routing, follow-up, sales, qualification

### inbox-triage-hybrid
- **title**: Agent classifies inbox (invoice/support/urgent/spam) → lookup in Xero, ticket in GHL, escalate via Telegram
- **industries**: all
- **runtime**: hybrid
- **services**: Gmail, Xero, GHL, Telegram
- **value**: inbox handled, nothing urgent missed
- **difficulty**: 30min-custom
- **pain_keywords**: inbox, email triage, support, invoices, escalation

### customer-support-hybrid
- **title**: Agent reads WhatsApp/SMS, identifies intent → lookup orders, process refunds, or escalate
- **industries**: all
- **runtime**: hybrid
- **services**: WhatsApp, SMS, Shopify
- **value**: faster support replies, fewer escalations
- **difficulty**: 30min-custom
- **pain_keywords**: customer support, refunds, orders, whatsapp, intent

### morning-ops-hybrid
- **title**: Agent pulls metrics via workflow, synthesises prose, flags anomalies, sends Telegram digest
- **industries**: all
- **runtime**: hybrid
- **services**: metrics sources, Telegram
- **value**: 30-second daily read on the business
- **difficulty**: 30min-custom
- **pain_keywords**: daily digest, metrics, reporting, anomaly, summary

### content-publisher-hybrid
- **title**: Agent drafts a post → platform-specific publish workflows (Instagram/LinkedIn) handle Buffer + API quirks
- **industries**: all
- **runtime**: hybrid
- **services**: Instagram, LinkedIn, Buffer
- **value**: consistent posting without the manual grind
- **difficulty**: 30min-custom
- **pain_keywords**: content, publishing, social media, posting, schedule

When the user picks a hybrid opportunity, the orchestrator runs `/n8n` first (builds workflows as webhook tools), then `/managed-agents-setup` (creates agent with `scripts/build-hybrid-tool.py`-generated tool specs). One handoff doc, one kill switch.

## Where to find more automations (community)

The 60 opportunities here are the curated starter set. The 290+ n8n templates under `templates/n8n/` cover most ground. If a workshop attendee wants to keep going after their first 1-3 builds:

- **Local skill discovery first**: `/skills-discovery` (workshop attendee tour) and `/find-skill` (search across 130+ installed skills) - already invoked at Phase 7 handoff.
- **Browse n8n.io directly**: <https://n8n.io/workflows/> - 9,000+ templates, search by integration name (Stripe, Xero, Shopify, etc.). Templates curated here are filtered for ≥3 nodes + non-empty description; n8n.io has plenty more for niche needs.
- **Awesome Claude Code** (community curated, MIT): <https://github.com/hesreallyhim/awesome-claude-code> - definitive list of skills, hooks, slash commands, agent orchestrators, and plugins.
- **Awesome Claude Skills** (Composio): <https://github.com/ComposioHQ/awesome-claude-skills> - 1000+ skills/plugins. Composio MCP is already wired so installing one is low-friction.
- **Anthropic plugin marketplace docs**: <https://code.claude.com/docs/en/plugin-marketplaces> - official guide. As of 2026 there are 2,500+ marketplaces with 4,200+ skills + 770+ MCP servers.

**Rule for attendees**: install ONE thing at a time, run it, decide if it earns its keep, then add the next. Don't pre-load 20 skills before the first build pays off.
