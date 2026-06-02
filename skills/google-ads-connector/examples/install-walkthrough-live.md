# Google Ads Connector — Install Walkthrough (Basic Access / live mode)

> **Status: illustrative, not yet captured.** This walkthrough was authored from the SKILL design without an end-to-end run against Google's Basic Access review process (which takes 1-3 business days and could not be completed in a single session). Specific timings, form-field IDs, email addresses, customer IDs, and DOM responses below are projections, not measurements. The walkthrough will be updated with a real captured run once the SKILL has been smoke-tested against an actual Google Ads account that has gone through the Basic Access workflow.

This walkthrough covers the **opt-in Live install path** (Phase 0 → Phase 1 shared → Phase 1L Basic Access dev token application → Phase 1T fallback so the participant has something today). Companion to `install-walkthrough.md` (test-only path).

**Key fact:** Basic Access requires Google's review (1-3 business days). Phase 1L submits the application AND configures Test mode immediately so the participant isn't blocked. Phase 0 on later sessions polls for approval.

**Pre-conditions:** identical to the test walkthrough.

---

## Step 0 — Mode prompt

```
Participant: Connect my real Google Ads.
Claude:      OK — I'll kick off Google's approval too. While we wait
             for them (1 to 3 business days), I'll set you up in test
             mode so you can use the connection right away. About 6
             minutes for the setup.
```

`MODE=basic`. Phase 1 shared steps run normally (Steps 1-10, identical to the test walkthrough). After Step 10, Phase 1L runs instead of Phase 1T.

---

## Phase 1L — Basic Access application

### Step 1L.1 — Navigate to API Center, click "Apply for Basic Access"

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Projected page state: Test-tier dev token visible AND an `Apply for Basic Access` button below it. Claude clicks the button. A multi-step application form opens.

### Step 1L.2 — Fill the application form

The form has approximately 10 fields. Illustrative default values:

| Field | Default value |
|---|---|
| Tool name | `Claude Google Ads Connector` |
| Tool URL | A real URL the participant owns (LinkedIn profile, personal site). Google may reject placeholder URLs like `https://example.com` — confirm at smoke-test time. |
| Tool description | "Personal API access to my own Google Ads account for reporting and management via Claude, an AI assistant. Used by me only; not redistributed." |
| Intended use | "Reports and basic management of my own ads accounts" |
| Email | participant's signed-in Google account email |
| Contact preferences | Opted OUT of API news emails by default |
| Are you an agency? | No |
| Will the tool be used for an agency's clients? | No |
| Will any features automatically buy or sell ads? | No |
| Industry | Ask the participant — varies per account |

Claude used the React-friendly setter pattern (per QBO Phase 1L's documented script) for each field.

### Step 1L.3 — Pre-submit review

Illustrative exchange:

```
Claude: Here's what I'll send Google for the review:
        - Tool name: Claude Google Ads Connector
        - Purpose: Personal API access to my own Google Ads account
        - Industry: <participant's answer>
        - Email: <participant's email>
        Want me to adjust anything before I send it?
Participant: Looks good, send it.
```

Claude clicks **Submit**. Wait for the confirmation banner:

```
mcp__playwright__browser_wait_for({ text: "submitted" })
```

Projected: post-submit page shows "Your Basic Access request has been submitted. Google typically responds within 1-3 business days."

### Step 1L.4 — Test-mode fallback + save credentials

Claude runs Phase 1T sub-steps 1T.1 and 1T.2 to capture the Test dev token from the same API Center page (the Test token stays valid for use while Basic Access is under review).

Projected `credentials.json` with `mode=pending-basic`:

```json
{
  "mode": "pending-basic",
  "client_id": "<71 chars>",
  "client_secret": "<35 chars>",
  "access_token": "<token>",
  "refresh_token": "<token>",
  "expires_at": "2026-06-02T06:11:48Z",
  "developer_token": "<22 chars — TEST token, used while waiting>",
  "customer_id": "4123456789",
  "google_cloud_project": "my-personal-projects-2024",
  "basic_application": {
    "applied_at": "2026-06-02T05:11:48Z",
    "status": "submitted"
  }
}
```

```
Claude: Application sent to Google — they usually review within 1
        to 3 business days and email you. In the meantime, I've set
        up test mode so you can use the connection today. When
        Google's email arrives, just say 'check my Google Ads
        approval' and I'll switch you over.
```

---

## Phase 0.3 — Resume after approval

Later session (~36 hours after submit):

```
Participant: Check my Google Ads approval.
Claude:      (Phase 0 reads credentials.json, sees mode=pending-basic,
             reads basic_application.applied_at — 36 hours > 24-hour
             threshold, drives Playwright to check status.)
```

```
mcp__playwright__browser_navigate({ url: "https://ads.google.com/aw/apicenter" })
```

Two outcomes:

**Approved.** The page shows "Basic Access" in the access tier badge and a NEW (different from Test) developer token. Claude DOM-extracts the new token, updates `credentials.json`:

- `mode` → `basic`
- `developer_token` → new Basic Access token
- `basic_application` block removed

Tells participant:

```
Claude: Google approved you — you're now on real Google Ads data.
        Anything you ask me will hit your actual account from
        here on.
```

The next tool call triggers Phase 2 Gate 1 (real-data confirmation).

**Still pending.** Page still shows "Pending Review" and no new token. Claude tells the participant:

```
Claude: Google's still reviewing — usually 1 to 3 business days.
        Want to use test mode in the meantime?
```

If yes: proceed with Phase 2 in Test mode (no Phase 0 changes). If no: stop.

---

## Phase 2 sample in Basic Access mode

```
Participant: What's my Google Ads spend this month?
Claude:      # Phase 2 — first invocation triggers Gate 1
             # Silently runs SELECT customer.descriptive_name FROM customer LIMIT 1
             # Returns "Selrai Marketing"
Claude:      Just confirming — you're connected to your real Google
             Ads account Selrai Marketing (ID 4123456789). Anything
             I do here will read or change your live campaigns. OK
             to proceed with showing your spend this month?
Participant: Yes.
Claude:      # GAQL Pattern 1
             SELECT metrics.cost_micros FROM customer
               WHERE segments.date DURING THIS_MONTH
             # → cost_micros: "473850000" → $473.85
Claude:      $473.85 spent so far this month.
```

A write would also trigger Gate 2:

```
Participant: Pause my "Q3 brand search" campaign.
Claude:      # GAQL: find campaign ID by name first
             SELECT campaign.id FROM campaign WHERE campaign.name = 'Q3 brand search'
             # → 17234567890
Claude:      I'm about to pause campaign Q3 brand search (ID
             17234567890). It will stop showing ads immediately. OK?
Participant: Yes.
Claude:      # Pattern 9: campaigns:mutate with status=PAUSED
             # → success
Claude:      Campaign Q3 brand search is now paused.
```

---

## Total projected timing (illustrative)

| Stage | Estimated wall-clock |
|---|---|
| Phase 1 shared (Steps 1-10) | ~4 min (same as test walkthrough) |
| Step 1L.1 (Apply button click + form open) | 5 s |
| Step 1L.2 (form fill via Playwright setter pattern) | 25 s |
| Step 1L.3 (participant review + submit) | 30 s |
| Step 1L.4 (Test fallback dev-token extract + save credentials.json) | 8 s |
| **Total Phase 1L wall-clock** | **~5.5 min projected** |
| **Plus Google review** | **1-3 business days** (asynchronous; participant uses Test mode meanwhile) |

---

## Failure modes anticipated from design review (will be confirmed once smoke run is performed)

| Failure | Cause | Fix |
|---|---|---|
| `Apply for Basic Access` button absent | Account already has Basic Access OR application already submitted | Re-check status via the dev-token tier badge; if `Basic Access`, jump to Phase 1T-equivalent (which is now Phase 1L's "approval already in" branch — capture Basic Access token). |
| Form submission rejected with "Tool URL invalid" | Some Google fields reject placeholder URLs | Ask participant for a real URL they own, or use their LinkedIn profile URL. |
| Form submission rejected with "Industry required but blank" | Industry was a dropdown the setter didn't trigger | Use `browser_evaluate` to programmatically click the dropdown option matching the participant's answer. |
| Phase 0.3 polls but page state ambiguous | Google UI variant — sometimes shows "Approved" without showing the new token until refresh | `browser_navigate` to the same URL to force a re-render, then re-extract. |
| Google approval email links a different OAuth client | Some Google accounts have multi-project complexity | Re-run Phase 1 from Step 3 with the project the email references. |

For Phase 1 shared failures (Steps 1-10), see `install-walkthrough.md`.
