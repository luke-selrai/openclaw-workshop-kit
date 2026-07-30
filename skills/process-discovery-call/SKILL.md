---
name: process-discovery-call
description: "Processes a recorded discovery call from its Google Drive transcript into a GHL CRM update, a Gmail follow-up draft and a Telegram summary. Use when the user asks to process a discovery call with a named prospect."
---

# Process Discovery Call

This skill turns a recorded discovery call into a CRM update, a drafted follow-up email, and a Telegram summary. The whole workflow runs from one Telegram message.

## When to use this skill

Trigger: an incoming Telegram message that says something like "Process discovery call with [prospect name]". Examples:

- "Process discovery call with Tom Calleia"
- "Process the call I just had with Sarah from Mainline"
- "Run the discovery call workflow on Tom"

Extract the prospect name from the message. Don't ask the user to repeat themselves if it's obvious who they mean.

## Step 1: Find the transcript in Google Drive

Search Google Drive for the transcript document, matching by prospect name. Use the `gws` CLI via Bash.

### Canonical commands (use these, don't re-derive)

**Search Drive for a doc:**

```
gws drive files list --params '{"q":"name contains '"'"'NAME'"'"'","orderBy":"modifiedTime desc","pageSize":10,"fields":"files(id,name,mimeType,modifiedTime,webViewLink)"}'
```

**Full-text content search (when title search fails):**

```
gws drive files list --params '{"q":"fullText contains '"'"'NAME'"'"' and mimeType='"'"'application/vnd.google-apps.document'"'"'","orderBy":"modifiedTime desc","pageSize":5}'
```

**Export a Google Doc to plain text:**

```
gws drive files export --params '{"fileId":"FILE_ID","mimeType":"text/plain"}' -o transcript.txt
```

**Important:** the `-o` path must be relative to the current working directory. The `gws` CLI rejects absolute paths outside CWD (e.g. `-o /tmp/...`) with a validation error. If you need the file in a specific location, `cd` there first or use a relative path. If you omit `-o` entirely, the file is saved as `download.txt` in CWD.

Then `Read` the local file. Do not try alternative gws flags like `+search`, `--file-id`, or top-level `--q` - those don't exist and waste time.

### Search strategy, in order

Stop as soon as you find a confident match:

1. Title contains the full name as given. Recent first.
2. Title contains only the last name.
3. Title contains only the first name.
4. Full-text content search via `fullText contains 'NAME'` if title searches fail.
5. Try obvious misspellings or transcription quirks of the name (vowel swaps, dropped letters).

If multiple matches at any step, pick the most recently modified.

If after all five fail, reply on Telegram with: "Couldn't find a transcript matching '[name]'. Paste the Drive link and I'll process it."

Once you find the doc, export to `./<slug>_transcript.txt` in your current working directory and `Read` it into context. Don't summarise before reading.

### Transcript format expectations

The transcript will be a wall of text with timestamps in `MM:SS` or `HH:MM:SS` format at the start of each line. There are no speaker labels - you'll need to infer who's speaking from context. Generally:

- The host (you, or whoever ran the call) asks open questions and steers the conversation
- The prospect describes their business, pain, budget, and timeline
- The host wraps up with commitments and next steps

## Step 2: Extract signals from the transcript

Read the full transcript and pull the following structured signals. Be specific. Quote evidence from the transcript where helpful - don't paraphrase into vagueness.

| Signal | What to capture |
|---|---|
| Prospect full name | First + last, as spoken |
| Role / title | Their job at the company |
| Company name | As stated |
| Industry / niche | Specific (e.g. "industrial auto parts distribution", not "B2B sales") |
| Company size | Revenue band + headcount if mentioned |
| Location / geography | Where they're based, where they sell |
| Current stack | All tools / software named (CRM, accounting, ecommerce, etc.) |
| Prior automation attempts | Any tools they've tried and abandoned, with reasons |
| Pain points | Top 3, each with a one-line quote or paraphrase of evidence |
| Quantified pain | Any dollar figures or hour estimates the prospect mentioned tying to the pain |
| Desired outcomes | What success looks like in their words |
| Budget signal | Range they named or implied. Quote it |
| Timeline / urgency | When they want it running |
| Decision authority | Who recommends, who signs |
| Other decision-makers | Names of anyone else who needs to be in the room |
| Commitments made by the host | What was promised, by when |
| Commitments made by the prospect | What they agreed to do, by when |
| Fit score | 1-10 with one-line reasoning |
| Stage recommendation | Which pipeline stage this opportunity belongs in after the call (see Step 3) |

If a signal genuinely wasn't surfaced on the call, mark it "not surfaced" - don't invent.

## Step 3: Update the GHL contact and opportunity

Use the GHL MCP tools (`mcp__ghl__*`) for most operations. **Important exception: the MCP is currently broken for `customFields` writes** - it accepts the parameter, returns success, but silently drops the data. Until that's fixed, use direct `curl` calls to the GHL API for any customFields write. See section 3.1.5 for the curl pattern.

Location ID: `<YOUR_GHL_LOCATION_ID>` // Replace this with your own GHL location ID - find it in your GHL sub-account URL or via the ghl-connector skill.
Pipeline ID: `<YOUR_PIPELINE_ID>` (the sales pipeline you want discovery-call opportunities to live in - grab the ID via `mcp__ghl__opportunities_get-pipelines`).
PIT lives in `~/.claude.json` under `mcpServers.ghl.headers.Authorization` (Bearer token).

### 3.1 Find or upsert the contact

Search for the contact via `mcp__ghl__contacts_get-contacts` by name + company (and email if mentioned on the call). If found, use that contact ID. If not found, create via `mcp__ghl__contacts_upsert-contact`.

**GHL upsert requires email OR phone.** If the transcript didn't surface a real email or phone:

- **Do not spend time hunting for one** across Gmail, Calendar, other CRMs. That wastes 2-3 minutes and rarely succeeds for a brand-new prospect.
- **Use a placeholder email immediately:** `firstname.lastname+pending@example.com` (lower-case, no spaces). Use your own domain - the `+pending` plus-tag works on Gmail/Workspace addresses. Gmail plus-addressing routes safely back to you if the draft is sent accidentally, and `+pending` flags it as a placeholder.
- **Always flag the placeholder in the Telegram TL;DR** so the user replaces it before sending.

Upsert with basic info only (firstName, lastName, email or placeholder, phone if available, companyName, city, state, country, timezone, source, tags). **Do not include customFields in the upsert** - they will be silently dropped. Set them via curl in section 3.1.5.

Apply the following custom fields from the signals extracted in Step 2 (using the curl pattern in section 3.1.5). **Only write a field if the signal was clearly surfaced on the call. Skip fields where the signal was not mentioned. Do not write "None" or "Other" as a default.**

#### Core fields (write whenever the signal was surfaced)

| Signal | GHL field key | Type | How to write |
|---|---|---|---|
| Industry / niche | `contact.industry__business_type` | SINGLE_OPTIONS | Pick the closest match from: Professional Services (Legal, Accounting, Consulting), Real Estate & Property, Construction & Trades, Healthcare & Medical, Retail & E-commerce, Hospitality & Food Service, Technology & Software, Marketing & Creative Agency, Finance & Insurance, Education & Training, Manufacturing & Distribution, Non-Profit & Community, Other |
| Company size / headcount | `contact.number_of_employees` | SINGLE_OPTIONS | Pick the bracket: Just me (Solopreneur), 2-5 employees, 6-10 employees, 11-20 employees, 21-50 employees, 51-100 employees, 100+ employees |
| Budget range (free-text) | `contact.budget_range` | TEXT | Quote the prospect's words. E.g. "$10-20K AUD, open to higher if payback's clear" |
| Budget bracket | `contact.whats_your_budget_for_this_build` | SINGLE_OPTIONS | Pick: $2,500 - $3,000, $4,000 - $6,000, $6,000 - $8,000, $10,000 - $50,000, $50,000+, Not sure yet. Only if budget was clearly stated |
| Urgency / why now | `contact.why_now_whats_driving_the_urgency_to_solve_this` | TEXT | Free-text. E.g. "Q3 2026 install during slower season - July onwards" |
| Decision-maker | `contact.who_is_the_decisionmaker_for_approving_implementations_and_changes` | TEXT | Free-text. E.g. "Mark (owner, final yes). Tom recommends and presents." |
| Biggest challenge (top pain, one line) | `contact.biggest_challenge_quick_summary` | LARGE_TEXT | The single biggest pain in their words |
| Expanded challenge (all 3 pains with evidence) | `contact.expanded_challenge_details_250_words` | LARGE_TEXT | Bullet list of all pains surfaced with one-line evidence each |

#### Optional fields (write only if the stack / process was clearly surfaced)

| Signal | GHL field key | Type | Picklist |
|---|---|---|---|
| Where business data lives | `contact.where_does_your_important_business_data_currently_live` | CHECKBOX (multi) | CRM, Spreadsheets, Project management tool, Accounting software, Multiple disconnected systems, In people's heads/emails |
| Project management tool | `contact.what_project_management_tool_do_you_use` | SINGLE_OPTIONS | Asana, Monday, ClickUp, Trello, Notion, Basecamp, None, Other |
| Email marketing platform | `contact.what_email_marketing_platform_do_you_use` | SINGLE_OPTIONS | Mailchimp, ActiveCampaign, Klaviyo, HubSpot, ConvertKit, None, Other |
| Automation platforms | `contact.do_you_currently_use_any_automation_platforms` | CHECKBOX (multi) | Zapier, Make (Integromat), n8n, Power Automate, None, Other |
| AI tools | `contact.do_you_currently_use_any_ai_tools` | CHECKBOX (multi) | ChatGPT, Claude, Gemini, Grok, Grammarly, None, Other |
| Invoicing / payment | `contact.what_invoicingpayment_system_do_you_use` | SINGLE_OPTIONS | Same as accounting, Stripe, Square, PayPal, GoCardless, None, Other |

#### Catch-all

For anything important that doesn't map to a structured field - specific tool names not in the picklists (e.g. "Pipedrive", "Shopify B2B"), referrer info, prior failed automation attempts and why, sidebar context - write to:

`contact.au_additional_notes_or_information` (LARGE_TEXT)

Structure that note like this:

```
Discovery call [date]:
Referrer: [if any]
Stack details: [specific tools not in picklists]
Prior attempts: [any tools they tried + why they failed]
Other context: [anything else worth knowing]
```

### 3.1.5 Write custom fields via curl (MCP workaround)

Until the GHL MCP custom-fields bug is fixed, use this pattern from the Bash tool to write all custom field values for the contact in one request:

```
curl -s -X PUT "https://services.leadconnectorhq.com/contacts/{CONTACT_ID}" \
  -H "Authorization: Bearer {PIT_TOKEN}" \
  -H "Version: 2021-07-28" \
  -H "Content-Type: application/json" \
  -d '{
    "customFields": [
      {"id": "{FIELD_ID}", "field_value": "{value or array}"}
    ]
  }'
```

- `{CONTACT_ID}` from the upsert response
- `{PIT_TOKEN}` from `~/.claude.json` → `mcpServers.ghl.headers.Authorization` (strip the "Bearer " prefix)
- `{FIELD_ID}` from the field mapping tables above (the IDs in the first column)
- `{value}` is the string (for TEXT/LARGE_TEXT/SINGLE_OPTIONS) or array (for CHECKBOX multi-select)

Verify after the call: GET the contact and confirm `customFields` is populated. If the array is empty after the write, the request format is wrong - do NOT silently continue.

### 3.2 Find the existing opportunity in your sales pipeline

Search for an existing opportunity for this contact in the pipeline you configured above. If your GHL is workflow-automated (inbound leads auto-create opportunities), an opportunity in this pipeline almost always already exists when a contact reaches discovery.

If no opportunity is found in this pipeline for this contact:
- Skip the opportunity update + stage move
- Write everything to the contact (fields + notes) as above
- Flag in the Telegram reply: "No existing opportunity found in [pipeline name] for [name]. Contact updated. You'll need to create the opportunity manually."

The official HighLevel MCP does not expose a create-opportunity tool, so the agent cannot create one. Do not attempt to.

### 3.3 Update the opportunity with a rich note

Append a structured note to the opportunity. Use the `mcp__ghl__opportunities_update-opportunity` tool (notes field, or whichever field accepts long-form context).

Format the note like this:

```
Discovery call - [date]
Fit: [score]/10. [one-line reasoning]

Pain:
- [pain 1] - [one-line evidence/quote]
- [pain 2] - [one-line evidence/quote]
- [pain 3] - [one-line evidence/quote]

Budget: [range and any quotes]
Timeline: [when]
Decision: [who recommends, who signs, who else needs to be on the next call]
Stack: [tools mentioned, including ones not in the contact picklist fields]

Commitments:
- Host: [what + by when]
- Prospect: [what + by when]
```

### 3.4 Apply a stage move

Read the opportunity's current stage. Apply the following decision matrix. Replace each `<...>` stage ID placeholder with the matching stage ID from your own pipeline (find them via `mcp__ghl__opportunities_get-pipelines`).

| Current stage | Call signals | Move to | Stage ID |
|---|---|---|---|
| Any pre-discovery stage (e.g. New Lead, Follow up, Positive Response, Needs Human) | Discovery call just happened, prospect has any genuine interest | **Discovery call** | `<DISCOVERY_CALL_STAGE_ID>` |
| Any pre-Discovery-call stage | Bad fit, no budget, no timeline, prospect declined to move forward | **Lost** | `<LOST_STAGE_ID>` |
| Any pre-Discovery-call stage | Some interest but real blocker (no budget yet, wrong contact, bad timing, fit score 5-6) | **Nurture / On Hold** | `<NURTURE_STAGE_ID>` |
| Any pre-Discovery-call stage | Fit score genuinely ambiguous (5-7), agent confidence low | **Needs Human** | `<NEEDS_HUMAN_STAGE_ID>` |
| **Discovery call** | Anything | **Stay put** - don't move | (no move) |
| **Proposal Sent** or later | Anything | **Stay put** - don't move backwards | (no move) |

Important rules:
- **Never move backwards.** Once an opportunity is at Proposal Sent or beyond, don't move it back to Discovery call. The discovery call was a retrospective check-in, not a fresh entry
- **Show reasoning.** Output a one-line explanation of WHY you picked the stage you picked. "Moved to Discovery call - clear budget, owner-alignment path confirmed for Tuesday" beats silent stage moves
- **If currently at Discovery call already, don't waste an API call** - just acknowledge no move needed

Apply the move using `mcp__ghl__opportunities_update-opportunity` with the new stage ID.

## Step 4: Draft the follow-up email

Draft a follow-up email in Gmail. **Save as a draft. Never send.**

This is a POST-CALL follow-up, not an intro pitch. The call already happened. The prospect already knows you understand their business. The job of this email is to confirm what's happening next, not to re-prove anything.

### Template to follow

Use whatever meeting follow-up template your business already has as the structural base. The shape below is a sensible default if you don't have one.

Adapted shape:

```
Subject: Following Up - [first name] / [company]

Hi [first name],

Thanks for the call today!

Action items:
- [Host commitment, by when, with specifics]
- [Other party commitment, by when]

Next steps:
[One line on what happens at the next call]

Let me know if I've missed anything.

Kind Regards,
```

### Voice and tone

- **From:** the user (use their default Gmail account - `gws gmail +reply` or the equivalent draft helper)
- **Voice:** the user speaking, post-call. Direct, warm but functional. Like a continuation of the call, not a fresh approach
- **English:** match the user's locale (e.g. Australian English uses organise, recognise, prioritise - never mix with American spellings)

### Hard rules

- **No em dashes.** Use hyphens, full stops, commas, or parentheses. Em dashes read as AI-generated
- **No "I hope this finds you well", "great chat today", "as discussed", "per our conversation".** Boilerplate gets cut
- **No re-litigation.** Don't reflect their pain back at them. Don't reframe what they said into a consulting framework ("that's not a tooling problem, it's a coordination problem" is exactly the kind of pitchy reframe to avoid). The discovery call already did that work
- **No selling.** This is logistics. The next call does the selling
- **Capture only commitments actually made on the call.** Don't fabricate. If the host didn't promise a deliverable on the call, don't put it in the action items
- **Hyphens, not em dashes, in the subject line.** Format: `Following Up - [first name] / [company]`

### Length

60-100 words. Tight. If you're writing more, you're probably re-pitching.

### Sign-off and Gmail signature

The body ends with just:

```
Kind Regards,
```

**Do NOT type the user's name after "Kind Regards,"** - the user's name is already in the signature block (the image card / signature shows their name and role). Typing the name plus appending the signature produces a duplicated name on screen.

**Critical:** Gmail signatures do NOT auto-append to API-created drafts. You must fetch the signature HTML and append it yourself. Do this every run (don't hardcode - the user may update their signature).

**Fetch the signature:**

```
gws gmail users settings sendAs list --params '{"userId":"me"}' | grep -v "keyring" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print([s['signature'] for s in d['sendAs'] if s.get('isPrimary')][0])"
```

This returns HTML that looks roughly like:

```
<div dir="ltr"><div><span style="font-family:Arial">Kind Regards, <br><br></span><div>...<img src="..."><br>...<span ...>This email may contain confidential information...</span></div></div></div>
```

**Strip the leading `Kind Regards, <br><br>`** (already in the body) so it isn't duplicated. Keep the rest (the image card + confidentiality disclaimer block). The visible result should be: `Kind Regards,` (one line) followed by the signature image card with name/role/contact details, followed by the disclaimer.

### Draft, not send - canonical command

Use the `+send --draft --html` helper. Do NOT re-derive multipart/base64 encoding in Python - that path is fragile (escaping bugs, lost contractions) and adds about a minute of trial-and-error.

```
gws gmail +send --draft --html \
  --to "PROSPECT_EMAIL" \
  --subject "Following Up - FIRST_NAME / COMPANY" \
  --body "<HTML_BODY_WITH_SIGNATURE>"
```

Where `<HTML_BODY_WITH_SIGNATURE>` is the email body converted to HTML (each paragraph wrapped in `<p>`, line breaks as `<br>`, bullet lists as `<ul><li>`), followed by `<br>` and the trimmed signature HTML from the fetch above.

**Recipient handling.** Use the real email if surfaced. Otherwise use the placeholder from section 3.1 (`firstname.lastname+pending@example.com`, using your own domain) and flag in Telegram that the user needs to update it before sending.

## Step 5: Reply on Telegram with a TL;DR

**Send exactly ONE Telegram message back.** If the reply tool returns success, do not retry. Don't send a second "now done" wrap-up message.

Use `mcp__plugin_telegram_telegram__reply` with `chat_id` from the inbound message's channel envelope.

### Format

```
✅ [Prospect full name] / [Company] processed

Fit: [N]/10 - [one-line reasoning covering referrer, signal density, decision path]

Pain: [pain 1, short with $$ if quantified]; [pain 2]; [pain 3]

Budget: [signal]
Timeline: [when]

[⚠️ block - only include if there are manual fixes needed. One bullet per fix. Be specific.]

[N] custom fields populated. Discovery call note added. Gmail draft saved.

Next: [specific commitment from host + date] + [next call detail + date]
```

### Example output (good)

```
✅ Tom Calleia / Ridgeline Industrial processed

Fit: 9/10 - referred by a previous workshop attendee, $8M industrial parts distributor, all three pains quantified, budget aligned, decision path clear with the owner on next call.

Pain: quote turnaround 2-3 days vs hours (~$10K+/mo leaking); reps stuck on stock-check calls (3-4 hrs/day/rep); ~600 dormant trade accounts (~$250-300K/yr recoverable).

Budget: $10-20K AUD, open above if payback's clear.
Timeline: Q3 install (July, slower season).

⚠️ Two manual fixes:
1. Email is a placeholder (tom.calleia+pending@example.com). Real email not on call or in Gmail/Calendar - chase it before sending the draft.
2. No opportunity existed in the sales pipeline (MCP can't create opps). Add it manually and set stage to Discovery call.

10 custom fields populated. Discovery call note added. Gmail draft saved.

Next: scoping outline to Tom by Friday + call early next week with the owner (assistant to send times).
```

### Length

Aim for under 20 lines including blank lines. Telegram messages don't truncate but readability drops past one phone screen. Cut the ⚠️ block entirely if there are no manual fixes.

## Failure handling

If any step fails (Drive can't find the doc, GHL write rejects, Gmail draft fails), reply on Telegram with:

- What you tried
- What failed
- What you need from the user to recover

**Don't half-execute.** If Step 1 fails, don't write to GHL. If Step 3 succeeds but Step 4 fails, mention the partial state explicitly so the user knows what's already been done.
