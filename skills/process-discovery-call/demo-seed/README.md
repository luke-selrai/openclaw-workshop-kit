# Demo Seed Data

Files needed to initialise the process-discovery-call demo. This is a synthetic example - a fictional prospect ("Tom Calleia" at "Ridgeline Industrial") so you can rehearse the workflow end-to-end before pointing it at a real call.

## Files

- `tom_calleia_transcript.txt` - synthetic discovery call transcript. Wall of text, timestamps `MM:SS`, no speaker labels. ~8KB.

## How to initialise the demo

1. **Upload transcript to Drive.** Create a Google Doc named exactly `Discovery call - Tom Calleia - Ridgeline - 2026-05-19` and paste the contents of `tom_calleia_transcript.txt`. Save in the default Drive root.

2. **Create GHL contact** (`POST https://services.leadconnectorhq.com/contacts/`):
   - locationId: `<YOUR_GHL_LOCATION_ID>` // your GHL sub-account location ID
   - firstName: `Tom`, lastName: `Calleia`
   - email: `tom.calleia+pending@example.com`
   - companyName: `Ridgeline Industrial`
   - city/state/country: `Brisbane` / `QLD` / `AU`
   - tags: `["new-lead"]`

3. **Create opportunity in your sales pipeline at the "New Lead" (or equivalent first) stage** (`POST /opportunities/`):
   - locationId: `<YOUR_GHL_LOCATION_ID>`
   - pipelineId: `<YOUR_PIPELINE_ID>` // your sales pipeline ID
   - pipelineStageId: `<YOUR_NEW_LEAD_STAGE_ID>` // the first stage in your pipeline
   - contactId: from step 2
   - name: `Ridgeline Industrial - Tom Calleia`
   - monetaryValue: `15000`

4. **Trigger via Telegram.** From your phone, message `<YOUR_TELEGRAM_BOT_USERNAME>` (your bot username from the telegram-connector setup): `Process discovery call with Tom Calleia`.

The skill will: find the Drive transcript → populate ~10 custom fields on the contact → add a discovery note to the opportunity → move stage from New Lead → Discovery call → draft a follow-up email in Gmail → reply on Telegram with a TL;DR.

## After the demo - clean-up

- Delete GHL opportunity, then contact (DELETE `/opportunities/{id}` and `/contacts/{id}`)
- Delete Drive doc
- Delete Gmail draft (search "calleia" or "ridgeline" in Drafts)
