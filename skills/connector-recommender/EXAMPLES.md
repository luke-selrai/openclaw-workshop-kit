# Connector Recommender — Worked Examples

Concrete end-to-end transcripts so a reviewer can verify in under five minutes
that the skill produces sensible output. Each example shows the **user message**,
the **registry calls** the skill makes, and the **verbatim assistant output** in
the Step 4 / Step 5 format. These are the reference outputs the test cases in
[TESTCASES.md](TESTCASES.md) assert against.

> Registry results below reflect a machine where Gmail, Google Calendar, Google
> Sheets, Airtable, Notion, Stripe, Shopify, Slack, GitHub and n8n are present,
> and GoHighLevel / Linear / WhatsApp Business / Figma / Mailchimp / Salesforce
> are absent. Your machine may differ — the skill always re-checks (Step 2).

---

## Example 1 — Ecommerce, with a stated pain point (happy path)

**User:** "I run a Shopify store selling custom t-shirts with 5 staff. I'm
drowning in customer refund emails."

**Skill internal actions:**
- Detects vertical: `ecommerce` (signals: "Shopify store", "selling")
- Captures pain point: refund email overload → tie a connector to it
- Captures team size: 5 staff (small team)
- Already-used tool: Shopify (acknowledge, don't re-pitch as new)
- `mcp__mcp-registry__search_mcp_registry("Shopify")` → present
- `mcp__mcp-registry__search_mcp_registry("Gmail")` → present
- `mcp__mcp-registry__search_mcp_registry("Stripe")` → present
- `mcp__mcp-registry__search_mcp_registry("Google Sheets")` → present
- `mcp__mcp-registry__search_mcp_registry("Slack")` → present
- Mailchimp is **(verify)** → skipped (absent), not shown to user

**Assistant output:**

```
You mentioned Shopify — let's get that connected. Based on your store, here are
the integrations that'll have the biggest impact:

Core (start here):
1. Gmail — tame those refund emails; I can draft a refund-handling reply template you reuse.
2. Shopify — pull orders, products, and stock so refunds and inventory line up.
3. Stripe — process refunds and see revenue in one place.

Level up (when you're ready):
4. Google Sheets — a simple sales-and-refunds dashboard your 5 staff can share.
5. Slack — order and refund alerts land in your team channel automatically.

Gmail + Shopify together means I can match a refund email to its order in seconds.

Would you like me to set these up? I'll walk you through one at a time.
```

**Why this is correct:** Gmail is ranked #1 because it solves the *stated pain*
(refund emails), ahead of Shopify even though Shopify is the platform. Exactly
5 recommendations, Core first. Mailchimp was silently dropped (absent from
registry). The synergy hint is tied to their actual workflow.

---

## Example 2 — Agency that already uses some tools, GHL absent

**User:** "We're a digital marketing agency with 15 clients. We already use
Gmail and Notion."

**Skill internal actions:**
- Detects vertical: `agency`
- Already-used: Gmail, Notion → exclude from recommendations, acknowledge
- `search_mcp_registry("GoHighLevel")` → **absent** → substitute Airtable (CRM)
- `search_mcp_registry("Google Calendar")` → present
- `search_mcp_registry("Airtable")` → present
- `search_mcp_registry("Slack")` → present

**Assistant output:**

```
You're already on Gmail and Notion — nice, that's two of the big ones done.
For a 15-client agency, here's what I'd add next:

Core (start here):
1. Google Calendar — client meetings and deadlines in one shared view.
2. Airtable — a client + campaign tracker so nothing slips across 15 accounts.

Level up (when you're ready):
3. Slack — per-client channels keep conversations out of your inbox.

Airtable + Notion together: the database tracks every client, your Notion docs
hold the playbooks.

Would you like me to set these up? I'll start with Calendar.
```

**Why this is correct:** Gmail and Notion are NOT re-recommended (acknowledged
instead). GoHighLevel — the table's first-choice CRM for agencies — was absent
from the registry, so the skill substituted **Airtable** without ever naming a
connector the user can't connect. Count is under 5.

---

## Example 3 — Unavailable connector requested by name

**User:** "Can you connect me to Salesforce?"

**Skill internal actions:**
- `search_mcp_registry("Salesforce")` → **absent**
- Map to closest available CRM substitute: Airtable (or GoHighLevel if present)

**Assistant output:**

```
Salesforce isn't available as a direct connector yet. The closest thing I can
set up today is Airtable — it'll hold your contacts, deals, and pipeline with
the views you'd expect from a CRM. If you outgrow it later we can revisit.

Want me to set up Airtable as your CRM?
```

**Why this is correct:** Registry checked before answering. Honest about
unavailability, no jargon, offers a concrete substitute, ends with one clear
next step.

---

## Example 4 — Setup execution (user accepts, one at a time)

**User:** (after Example 1's recommendations) "Yes, set them up."

**Skill internal actions, in order:**
- Gmail: `search_mcp_registry("Gmail")` → present, not yet connected →
  `suggest_connectors(["Gmail"])` shows the Connect button.

**Assistant output (turn 1):**

```
Great — let's start with Gmail since it'll take the refund-email load off you first.

[Connect button appears]

Click "Connect" and follow the sign-in steps. Tell me when you're done.
```

**User:** "done"

**Assistant output (turn 2):**

```
Connected! Quick tip: I can now draft you a refund-handling reply template you
reuse for every refund request.

Next up is Shopify — ready?
```

**Why this is correct:** One connector at a time, Connect button via
`suggest_connectors`, a vertical-specific quick win after the connection (not
the generic "search your inbox"), then a single gated next step.

---

## Example 5 — Registry tools absent (graceful degradation)

Some sessions don't have the MCP registry tools (`search_mcp_registry`,
`suggest_connectors`) loaded. The skill must still help — from its built-in
maps — and must NOT invent an install path.

**User:** (after Example 1's recommendations) "Yes, set up Gmail."

**Session state:** `mcp__mcp-registry__suggest_connectors` is **not present**.

**Assistant output (correct):**

```
To connect Gmail, open the connectors menu in Claude (the plug/settings icon),
find Gmail, and click Connect — then sign in when your browser opens. Tell me
once it's connected and I'll set up the next one.
```

**Forbidden output (the bug this guards against):**

```
Gmail needs a small helper tool on your computer. Let me check if it's installed...
[runs `node --version`]
Great news — the helper tool is already there. I'll run a quick setup command and
a Google sign-in window will pop up...
```

**Why the bad version is wrong:** there is no "helper tool", no Node.js
dependency, and no "setup command" that connects a connector — connecting is a UI
action. Running a terminal command for a non-technical user is a hard rule
violation (see Golden Rules in SKILL.md). This path was caught by a live
skill-qa-harness run; see [QA-NOTES.md](QA-NOTES.md).

## How these map to the test suite

| Example | Test case | Asserts |
|---|---|---|
| 1 | TC-01 | Ecommerce detected, pain-point ranking, 5 recs, setup offer |
| 2 | TC-02 / TC-07 | Agency detected, existing tools excluded, GHL substituted |
| 3 | TC-11 | Registry checked, honest unavailable answer, substitute offered |
| 4 | TC-08 | `suggest_connectors` used, one-at-a-time, quick win after each |
