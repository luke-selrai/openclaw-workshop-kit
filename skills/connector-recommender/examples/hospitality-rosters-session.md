# Worked example: detect business type and recommend the right connector stack

A reference end-to-end session showing the skill produce a concrete connector stack from a free-text business description. **You:** is the user, **Claude:** is the response.

The skill's job: parse the business, identify industry + persona + operational pain points, recommend the top 5 connectors plus install order, name what's NOT a fit.

---

## You

I run a 40-cover Italian restaurant in Brisbane. 8 floor staff, 4 kitchen, mostly casual. We use Toast POS, Resy for bookings, Deputy for rostering, Mailchimp for our newsletter, and Square for online ordering. The biggest pain is no-shows on Friday and Saturday nights, we lose 8-12 covers per service to bookings that don't turn up.

## Claude

Reading the brief.

> [Parse] Extracts industry: Hospitality. Persona: Non-technical owner. tools_currently_used: [toast, resy, deputy, mailchimp, square]. Pain points: [no-shows on weekends]. Engagement type: unknown (probably workshop or ASA, depending on budget).

> [Pre-filter] Loads the kit-index corpus. Filters Production-verdict kits where industry matches Hospitality or tools_integrated overlaps with the user's stack.

### Stack recommendation

Top 5 for this business, in install order:

#### 1. resy-mcp-setup (Production)

**Why:** No-show prevention starts at the reservation. Resy's API exposes booking-level guest history, deposit flags, and SMS-confirmation timestamps. The MCP lets Claude pull a "high-risk no-show" list each morning so the host can hand-confirm dicey bookings before service.

**What it gives you:** Daily "today's bookings + risk flag" report. The flag combines: first-time guest + >2 prior bookings cancelled + booking made within 2h of seating + party size >4.

**Install order: first.** Solves the headline pain.

#### 2. toast-mcp-setup (Production)

**Why:** Toast is your source of truth for cover counts and revenue per service. Pair with Resy to know exactly which no-shows cost what, "8 covers no-showed at avg cover $87 = $696 lost on Friday".

**What it gives you:** Daily revenue + no-show cost report into a single Slack/email post.

**Install order: second.** Quantifies the pain Resy connector mitigates.

#### 3. sent-mcp-setup (Production)

**Why:** Multi-channel guest messaging (SMS + WhatsApp + RCS). Pre-shift confirmation reminders sent 4 hours before booking dramatically cut no-show rate. AU restaurants doing this report 60-80% no-show reduction.

**What it gives you:** Automated "see you at 7pm tonight" SMS to every booking, with one-tap confirm/reschedule link.

**Install order: third.** Closes the no-show loop. Combine with Resy data for "high-risk bookings get a 4h reminder, everyone else gets a 24h reminder".

#### 4. deputy-mcp-setup (Production)

**Why:** Rostering is fine until a service is unexpectedly short. If Resy + Toast surface "tonight is heavier than Tuesday" early, Deputy can prompt a stand-by staff member without you doing manual rostering math.

**What it gives you:** "Tonight's covers vs roster" guard, alerts if you're under-staffed.

**Install order: fourth.** Reactive value, not the headline.

#### 5. mailchimp-mcp-setup (Production)

**Why:** Lowest-leverage of the five but you already pay for Mailchimp. Connector lets Claude segment your newsletter by guest behaviour (repeat bookings, no-show history, last-visited date) without you manually exporting + reimporting CSVs.

**What it gives you:** "Send the 60-day-inactive guest a 15% off come-back offer" workflow, end-to-end.

**Install order: last.** Real value, low urgency.

---

### What's NOT a fit (and why)

- **klaviyo-mcp-setup**: You're on Mailchimp. Klaviyo is the ecom-shaped alternative, would be a tool swap, not an addition. Don't double-pay.
- **shopify-connector**: You're not selling product online, you're selling reservations + covers. Square handles your online ordering already.
- **synthflow-mcp-setup**: A voice AI taking reservations sounds clever but Resy already handles booking + waitlist via its own native voice. Adding a second voice layer creates conflict.
- **ghl-crm**: GoHighLevel is for B2B sales pipelines, not hospitality guest CRM. Resy's guest profile + Mailchimp covers your guest-CRM needs.

---

### What's MISSING from the kit-index for your business

- **AU Fair Work Modern Award compliance**, penalty rates, casual loading, public-holiday hours. Deputy does the rostering math but doesn't generate a "this week's Modern Award compliance check" report. If this is a pain, flag it; could be a custom build at the next workshop.
- **Supplier ordering**, restaurant ordering platforms (Foodbomb, Marketplacer) don't yet have indexed connectors. Manual for now.

---

### Sequenced install plan

| Day | What | Time |
|---|---|---|
| Day 1 morning | resy-mcp-setup + toast-mcp-setup | 90 min in workshop |
| Day 1 afternoon | sent-mcp-setup + the no-show SMS workflow | 90 min |
| Within 7 days post-workshop | deputy-mcp-setup + the under-staff guard | 30 min, self-serve via Claude Dispatch |
| Within 14 days | mailchimp-mcp-setup + first segment workflow | 45 min, self-serve |

Total install time at the workshop: ~3 hours. The two "self-serve" items can be dispatched from your phone after Day 1 if Claude Dispatch is also installed.

---

## What this transcript proves

- The brief was parsed into structured fields (industry, tools, pain points) before any kit was named.
- The recommendation is 5 specific kits, in install order, with a one-line "what it gives you" each.
- The skill explicitly names what NOT to install + why, with reasoning specific to the user's stack (not generic).
- The skill names gaps in the kit-index for this vertical, which doubles as a build-queue signal for Selr AI.
- The install plan is timeboxed and realistic for a workshop delivery.

The session above was run against the real kit-index corpus in May 2026 with a synthetic but realistic restaurant brief.
