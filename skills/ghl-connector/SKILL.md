---
name: ghl-connector
description: "Connect and operate GoHighLevel via the official HighLevel hosted MCP server. Use when the user asks to set up GHL, connect their sub-account, or interact with contacts, conversations, opportunities, pipelines, calendar, payments, blogs, email templates, or social posts. On first use, run Phase 1 — Claude drives the browser end-to-end via Playwright; the user only signs in to GHL once. Phase 2 uses `mcp__ghl__*` native tools. Falls back to Playwright only for UI-only surfaces (visual workflow editor, full email campaign authoring)."
allowed-tools: mcp__ghl__*,Bash,Read,Write,Edit,mcp__playwright__*,mcp__plugin_playwright_playwright__*
metadata:
  category: CRM & Marketing
  tags:
    - ghl
    - gohighlevel
    - crm
    - contacts
    - pipelines
    - opportunities
    - calendar
    - campaigns
    - mcp
  pairs-with:
    - skill: superpowers:systematic-debugging
      reason: Use for troubleshooting PIT/scope or MCP connection errors
    - skill: playwright-skill
      reason: Used only as a fallback for UI-only surfaces the official MCP server doesn't cover (SMS composer, visual workflow editor)
    - skill: xero-connector
      reason: Same pattern — MCP connector for an external SaaS
    - skill: connector-recommender
      reason: Use when the user is picking which connectors to set up
---

# GoHighLevel (GHL) Connector

> **Install pattern:** Hosted-bearer-PAT — see [skills/CLAUDE.md](../CLAUDE.md) for the cross-pattern overview, and [monday-connector](../monday-connector/SKILL.md) for the canonical reference. GHL is a two-header variant of the pattern (`Authorization` + `locationId`).

## Overview

This skill lets you read and update a user's GoHighLevel sub-account on their behalf using the **official HighLevel hosted MCP server**. It has two phases:

- **Phase 1 — Install & Auth.** An autonomous bootstrap. Claude opens GHL in a Playwright-driven browser, waits for the user to sign in, captures the sub-account ID from the URL, navigates to Settings → Private Integrations, creates a Private Integration Token with all the permissions the hosted MCP server needs, captures the token from the one-time-reveal modal, writes the connection settings, and verifies — without ever asking the user to copy, paste, or navigate menus themselves. Their only action is logging in to GHL once.
- **Phase 2 — Use Tools.** Once the connector is configured, you call the `mcp__ghl__*` native tools to read and update GHL data.

**Which phase to run** — Before any GHL tool call, check whether the MCP server is already configured. Read `~/.claude.json` (Mac/Linux) or `%USERPROFILE%\.claude.json` (Windows) and look for an `mcpServers.ghl` entry with both an `Authorization: Bearer ...` header and a `locationId` header. If both are present, run a single `mcp__ghl__ghl_get_location` smoke call. If it returns a sub-account name, ask the user *"I'm currently connected to [name] — is that right?"* and only skip to Phase 2 after they confirm. If the entry is missing, the smoke call returns 401, the smoke call returns a name the user doesn't recognise, or the user wants to switch sub-accounts, run Phase 1.

<!-- DRY-RUN STATUS 2026-05-11: 2 of 8 VERIFY markers resolved against live SELR Group HighLevel account (URL pattern + canonical PIT page route — both confirmed across 3 sub-accounts and at agency level). The remaining 6 require a HighLevel account with Labs enabled (which is the gate for Private Integrations per HighLevel docs: "If you don't find it under settings, please make sure that you have enabled the feature on Labs"). SELR Group HighLevel account checked 2026-05-11 lacks the Labs feature entirely (the `/settings/labs` agency-level route redirects to `/sub-accounts`), so PIT cannot be self-enabled here — looks like a HighLevel plan-tier requirement. Remaining markers will be resolved once a Labs-enabled environment is available. -->

<!-- VERIFY (sandbox dry-run): exact response shape from `mcp__ghl__ghl_get_location` — confirm it contains a `name` field for the sub-account name we then echo back to the user. If the canonical field is `companyName` or `locationName`, update the resume-check prose. -->

---

## Technical reference (for Claude only — never narrate to the user)

- **Endpoint:** `https://services.leadconnectorhq.com/mcp/`
- **Auth:** `Authorization: Bearer <PIT>` + `locationId: <sub-account-id>` headers
- **Transport:** HTTP MCP — no custom server, no source tree, no shell envvars
- **Tool surface:** over 200 tools across 20+ resource areas (Contacts, Conversations, Opportunities, Calendar, Payments, Blogs, Email Templates, Social Media, plus invoices, estimates, products, custom objects, and more)

> **Fallback:** A small number of GHL surfaces are UI-only (the visual workflow builder, full email campaign authoring in the campaign builder UI). For those, and **only** those, fall back to [playwright-skill](../playwright-skill/SKILL.md). Never reach for Playwright when an `mcp__ghl__*` tool exists for the task.

---

## Communication rules for Phase 1

The user is a non-technical business owner. Phase 1 is autonomous — Claude does the work, the user only signs in to GHL when prompted. Every message you send during Phase 1 must follow these rules:

- **You drive, not them.** Never ask the user to click menus, copy text, paste values, or pick permissions. The only action you ever request is "please sign in to the browser window I just opened." **Exception:** if the user must choose between irreversible options (e.g. which existing connection key to delete to free a slot at the per-location 5-key cap, or which sub-account to connect when they own several), surface the named choice in plain English and wait for their pick — but never ask them to copy, paste, or navigate.
- **Plain English only.** No jargon. Never say PIT, Private Integration, token, scope, locationId, sub-account, hosted MCP server, MCP, endpoint, JSON, config file, terminal, bash, headers, Authorization Bearer, OAuth, or environment variable. The browser window you open is "a browser window I just opened for you" or "the connection page" — not "Playwright" or "Chromium". The Private Integration Token is "your connection key". A sub-account is "your GoHighLevel account" (singular) or, when the user owns several, named by its label.
- **Narrate at action boundaries, not inside tool sequences.** Tell the user once when you start ("I'm opening GoHighLevel for you now"), once when you need them ("please sign in"), once when you're done ("your GoHighLevel is connected"). No commentary in between.
- **React to success and failure warmly.** Good: "That worked — your GoHighLevel is now connected." Bad: "MCP server initialized with 200 OK."
- **Never show error messages directly.** Translate into plain English. If something fails, say "No problem — let me try a different way," then diagnose silently.
- **Short responses.** Maximum 8 lines per message during Phase 1.
- **Never mention file paths, commands, scripts, permission names, or DOM/snapshot details** to the user. You run them; you do not describe them.

---

## PHASE 1 — Install & Auth (autonomous via Playwright)

Claude drives the user's browser end-to-end via Playwright MCP. The user's only role is to sign in to GHL when prompted (and approve 2FA if their account requires it). Claude handles every other step — navigation, sub-account ID capture, permission selection, token reveal, capture, settings write, verify.

> **Reasoning model.** Each Playwright step describes a *goal* (e.g., "find the Create button on the Private Integrations page"). Achieve it by taking a `browser_snapshot`, reasoning about what's on the page, and calling the appropriate `browser_click` / `browser_evaluate` / `browser_navigate`. Do not hardcode CSS selectors — GHL's UI changes. Re-snapshot whenever the page state changes.

> **Sub-account context.** GHL has two scopes: agency view (manages multiple sub-accounts) and sub-account view (one location at a time). This skill connects ONE sub-account. If the user lands on the agency view after login, drive them into the target sub-account before capturing credentials. If they own multiple sub-accounts, ask which one to connect (by name) and handle the rest.

> **Playwright profile policy.** The Playwright MCP runs in whatever profile Claude Code's MCP config has set — typically a fresh ephemeral profile per launch. The user's GoHighLevel session cookie therefore lands in a temporary profile and goes away when the browser closes. **Do not pin Phase 1 to a persistent shared profile** — multiple workshop attendees on the same machine could re-use a teammate's session. After Step 7's `browser_close()`, the workshop attendee's GHL credentials live only in cookies inside the ephemeral profile, which Playwright cleans up on next launch. (For attendees on their own machine running their own Selr work, see `feedback_playwright_persistent_profile_own_account.md` — that's a different posture from this skill's default.)

### Step 1 — Confirm access level, then orient the user

**First, ask the user about access level** (named-choice exception per Communication Rules):

> "Quick question before we start: do you want me to be able to **read only** your GoHighLevel data, or **read AND update** it? Read-only is safer if you're not sure — you can always upgrade later. Read-and-update lets me move opportunities, send messages, and create blog posts on your behalf."

Wait for the user to pick. Save their answer as `<ACCESS_LEVEL>` (one of `read-only` or `read-write`) for Step 5. The default if they answer ambiguously: ask once more, then default to `read-only`.

**Then orient them:**

> "Got it. I'm opening a browser window for you — please sign in there when it appears, and I'll handle the rest. Should take about a minute."

### Step 2 — Open GHL and confirm a logged-in sub-account session

Call `mcp__playwright__browser_navigate({ url: "https://app.gohighlevel.com" })`.

Take a `mcp__playwright__browser_snapshot()`. Reason from the snapshot:

- **Logged in to a sub-account** (left nav with Conversations / Calendars / Contacts / Opportunities, sub-account name in the top bar) → continue to Step 3.
- **Logged in to agency view** (sub-account list, "All Sub-Accounts" header, agency-level menu) → if exactly one sub-account is shown, click it. If multiple are shown, **do not list every name in the chat transcript** (the names are usually client business names — listing 12 names exposes the user's whole client roster to whoever sees the transcript). Instead, count them and ask the user to filter:
  - If 2-3 accounts: list all names — low PII risk.
  - If 4-10 accounts: ask *"You have several GoHighLevel accounts. Which one should I connect? You can tell me by first letter or by the first word of the name."* — then once they say "starts with M" or "the one for Acme", filter the snapshot list to matching candidates and present those (1-3 names) for confirmation.
  - If more than 10 accounts: ask *"You have a lot of GoHighLevel accounts. What's the first letter or first word of the one I should connect?"* and only present candidates that match.

  Once the user picks one, click it, **save the displayed name as `<EXPECTED_NAME>` for Step 7's cross-check**, then re-snapshot.

If the user lands directly in a sub-account (no agency view), capture the sub-account name from the top-bar via `browser_evaluate(() => document.title || /* fallback to header text */)` and save as `<EXPECTED_NAME>`. If neither method yields a name, leave `<EXPECTED_NAME>` empty and Step 7's cross-check will simply ask the user to confirm.
- **Not logged in** (sign-in form, marketing landing page) → tell the user *once*: *"The browser window is open — please sign in to GoHighLevel when you're ready."* Then poll silently: call `mcp__playwright__browser_wait_for({ text: "Conversations" })` (or any post-login element from the snapshot — Calendars, Opportunities, dashboard widgets) with a generous timeout. Do **not** ask the user to confirm when they're done — detect the logged-in shell from the snapshot yourself. 2FA, password resets, and SSO redirects all resolve to the same dashboard.

If `browser_wait_for` times out (5+ minutes), then — and only then — check in with the user: *"Still on the sign-in page? Anything I can help with?"*

### Step 3 — Capture the sub-account ID from the URL

Once inside the GoHighLevel account, the URL follows the pattern `https://app.gohighlevel.com/v2/location/<LOC_ID>/...`. Read it via:

```
mcp__playwright__browser_evaluate({ function: "() => { const m = window.location.href.match(/[/]v2[/]location[/]([^/?#]+)/); return m ? m[1] : null; }" })
```

The character classes (`[/]`) sidestep a JSON-double-escape pitfall: when the function string is serialised through the Playwright MCP tool-call envelope, `\/` requires double-escaping (`\\\\/` in the JSON source) for the decoded regex literal to be valid. Character classes need no escapes and serialise cleanly through any envelope.

<!-- VERIFIED 2026-05-11: URL pattern `/v2/location/<LOC_ID>/` confirmed against 3 SELR Group sub-accounts. All observed LOC_IDs were 20 chars alphanumeric and matched the `^[A-Za-z0-9]{18,24}$` regex below. Pattern stable as of 2026-05. -->

A valid sub-account ID matches the regex `^[A-Za-z0-9]{18,24}$` (~20-character alphanumeric, example shape `VuWT1234abcd5678efgh`). Reject any other shape — a malicious page that mutates `window.location.href` via `history.replaceState` could embed a payload that the looser `[^/?#]+` capture would accept. Save the validated value as `<LOC_ID>` for Step 7.

A second cross-check happens at Step 7's verification: after the headers are written and `mcp__ghl__ghl_get_location` returns, the skill asks the user to confirm the returned account name matches the one they navigated to. If it doesn't match (e.g. URL was tampered, or the user clicked the wrong sub-account), the skill aborts and re-runs Phase 1 from this step.

If the URL match returns null (unusual navigation pattern), fall back to the Settings → Business Profile method:

1. Click the settings/gear icon visible in the snapshot, or navigate to the Settings area.
2. From the settings menu, click **Business Profile**.
3. `browser_snapshot` and reason from the page — the sub-account ID (sometimes labelled "Location ID" or "Business ID") sits near the bottom of the Business Profile form.
4. Read it via `browser_evaluate` reading the visible alphanumeric value, validate it's ~20 characters alphanumeric.

<!-- VERIFY (sandbox dry-run): Business Profile fallback DOM shape — exact field label ("Location ID" / "Business ID" / other), exact element type (text node / `<input readonly>` / span), and whether the value is selectable text or behind a Show/Reveal/Copy button. -->

If neither method yields a sub-account ID after two snapshot attempts, stop and tell the user: *"I'm having trouble finding your account — could you read me what's at the top of the page in your browser?"*

### Step 4 — Open the Private Integrations page

Click the **Settings** menu (gear icon, typically bottom-left of the account nav), then look for **Private Integrations** in the settings sidebar.

**Missing-feature guard (added 2026-05-11).** Before clicking, scan the Settings sidebar for a "Private Integrations" link. Per HighLevel's 2026 docs, *"If you don't find it under settings, please make sure that you have enabled the feature on Labs"* — Labs is the gate. If the sidebar link is missing, navigate to the canonical deep-link `https://app.gohighlevel.com/v2/location/<LOC_ID>/settings/private_integrations` (snake-case — the kebab-case variant `private-integrations` redirects to `/dashboard` instead of rendering). Wait at least 5 seconds for hydration, then probe `browser_evaluate(() => document.body.innerText.length)`. If the body stays at 0 chars (the Vue router has no view for this route on the user's plan), Private Integrations isn't available on this HighLevel account — surface to the user: *"Your GoHighLevel account doesn't have Private Integrations enabled. Per HighLevel's docs, this is gated behind the 'Labs' feature. Open Settings → Labs (agency level) and enable Private Integrations there; if Labs itself isn't visible either, the feature isn't on your HighLevel plan tier — you'll need to contact HighLevel support or your agency admin to unlock it. Once it's enabled I can pick up where I left off."* and stop. Empirical reference: SELR Group HighLevel account checked 2026-05-11 lacked Labs entirely — `/settings/labs` at agency level redirected to `/sub-accounts`, and 3 sub-accounts + the agency-level `/settings/private_integrations` route all rendered empty under this signature. PIT primarily lives at agency level per HighLevel docs; sub-account-level access requires explicit agency-admin permission.

If the sidebar link is present (or the deep-link page hydrates with content), click through and take a `browser_snapshot`. Reason from it:

- **Below the per-location 5-key cap** — empty state or 1-4 existing integrations. The "Create new Integration" button (or similarly-named CTA) is visible and active. Continue to Step 5.
- **At the 5-key cap** — the list shows 5 existing integrations and the Create button is disabled. Stop and surface the named choice to the user (per the Communication Rules exception): *"You've reached the maximum of 5 connection keys on this account. To make room, I'd need to remove one. Here are the names of the ones you have: [list names from snapshot]. Which one is safe to remove?"* Wait for the user to name one. After they pick, drive the deletion via the row's delete control, re-snapshot to confirm the count is now 4, then continue to Step 5.

If the list state is ambiguous after one snapshot, re-snapshot once before proceeding.

<!-- PARTIALLY VERIFIED 2026-05-11: canonical deep-link confirmed as `/v2/location/<LOC_ID>/settings/private_integrations` (snake-case). The kebab-case variant `/settings/private-integrations` redirects to `/dashboard` and is NOT canonical. Page DOM (anchors, modal selectors, list shape) still pending live walk — see missing-feature guard above. -->

<!-- VERIFY (sandbox dry-run): page DOM once a PIT-provisioned account loads — list-table shape, "Create new Integration" CTA exact label + selector, and 5-key cap detection (count vs disabled-button vs error toast). -->

<!-- VERIFY (sandbox dry-run): the at-cap delete control — exact row-level button label ("Delete" / "Remove" / icon-only) and whether deletion needs a confirmation modal. -->


### Step 5 — Create the Private Integration Token

Click **Create new Integration**. A creation form appears — name, description, and permission selector.

Capture today's date via `Bash` so it lands in UTC correctly regardless of the user's browser timezone:

```bash
date -u +%Y-%m-%d
```

(Windows PowerShell: `Get-Date -AsUTC -Format yyyy-MM-dd`.)

Fill the form:

- **Name:** `Claude Code — <date captured above>`. Example: `Claude Code — 2026-05-08`.
- **Description:** `Auto-created by Claude Code for the GoHighLevel connector on <date>. Has full read+write access (or read-only, depending on user choice). Revoke when Claude Code no longer needs GoHighLevel access — Settings → Private Integrations → row "Claude Code — <date>" → Delete.`
- **Permissions:** select the permissions the hosted MCP server requires for `<ACCESS_LEVEL>` (captured in Step 1). Per GHL's MCP help doc the full list is around 22-23 entries; the read-only subset is fewer.

  **Full canonical list (used when `<ACCESS_LEVEL>` is `read-write`):**

  1. View/Edit Contacts
  2. View/Edit Conversations
  3. View/Edit Conversation Messages
  4. View/Edit Opportunities
  5. View Calendars & Calendar Events
  6. View Locations
  7. View Payment Orders & Transactions
  8. View Custom Fields
  9. View Forms
  10. Check Blog Post Slug
  11. Update Blog Post
  12. Create Blog Post
  13. View Blog Authors
  14. View Blog Categories
  15. View Blog Posts (read-only)
  16. View Blog List (read-only)
  17. Create, Update and Delete Email Templates
  18. View Email Templates
  19. View Social Media Accounts
  20. View Social Media Statistics
  21. Edit Social Media Posts
  22. View Social Media Posts

  **Read-only subset (used when `<ACCESS_LEVEL>` is `read-only`):** items 5, 6, 7, 8, 9, 13, 14, 15, 16, 18, 19, 20, 22 from the list above (the `View *` permissions that don't include any Edit/Update/Create/Delete capability). For items 1-4 (the combined `View/Edit *`), branch on what the live picker exposes: if separate `View Contacts` and `Edit Contacts` permissions exist, tick only the `View *` half; if the picker only exposes the combined `View/Edit *`, tick that AND tell the user post-install: *"GoHighLevel doesn't separate read and write permissions for [contacts/conversations/etc.] in your account, so I had to take both. Let me know if you want a more locked-down setup later."*

  <!-- VERIFY (sandbox dry-run): copy the canonical list verbatim from the live permission picker DOM and reconcile against this list. Items 15-16 may be doc-rendering duplicates of the same underlying scope; the live picker will reveal the real cardinality. Confirm whether items 1-4 expose separate View / Edit variants or only the combined View/Edit. Update this list, the count language above, the read-only subset, and the count claim in `## Phase 2 Error Handling` if any of these diverge. -->

Reason from the snapshot — the permission selector is most likely a multi-checkbox list (one row per permission) but may be a search-and-add combobox or a tree view grouped by resource. For each permission in the list above, find the matching control and tick it via `browser_click`.

**Snapshot cadence (perf-bounded):** take an initial `browser_snapshot` to read the picker layout, tick the first 5 permissions, then re-snapshot once to confirm the layout still matches expectations and catch any label drift early. Tick the remaining permissions without further snapshots. Take a final `browser_snapshot` once you believe all are ticked, to confirm completion before clicking Create.

If a permission name in the snapshot doesn't match this canonical list (GHL may rename labels), use **case-insensitive substring matching on the resource noun** — match on `contact`, `conversation`, `opportunity`, `calendar`, `location`, `payment`, `custom field`, `form`, `blog`, `email template`, `social media` — and prefer the most permissive option in any same-resource pair (e.g. "View/Edit Contacts" over "View Contacts (read-only)"). If no match exists for a major resource, fall back to asking the user (per the named-choice exception in the Communication Rules): *"I can't find a permission for [resource] in your version of GoHighLevel — could you tell me what's listed?"*

Once all permissions are ticked, click the final **Create** button.

<!-- VERIFY (sandbox dry-run): permission selector UI shape (multi-checkbox vs tree vs combobox), exact final-button label (Create / Save / Generate). -->

### Step 6 — Capture the token from the one-time-reveal modal

After clicking Create, GHL displays the new PIT in a one-time-reveal modal with the warning *"Don't forget to copy the token generated as you won't be able to do it again later."*

**Anchor on the modal container before reading.** A bare `document.querySelector('textarea, code, ...')` returns the FIRST DOM match in document order across the whole page — on a real GHL admin page this is typically the chat/help-widget input, NOT the modal's token field. A malicious GHL Marketplace app or reflected-XSS could also plant a hidden textarea earlier in DOM order. To prevent silent token swap, scope the query to the visible reveal modal:

```
mcp__playwright__browser_evaluate({
  function: "() => { const modal = Array.from(document.querySelectorAll('[role=\"dialog\"], .modal, [class*=\"Modal\"]')).find(el => /Don't forget to copy|won't be able to do it again/i.test(el.innerText || '')); if (!modal) return null; const sel = modal.querySelector('input[readonly], textarea[readonly], [data-testid*=\"pit\"], [data-testid*=\"token\"], code'); return sel ? (sel.value || sel.textContent).trim() : null; }"
})
```

The function (a) finds the visible modal whose text contains the GHL warning string, (b) queries WITHIN that modal only, and (c) prefers the most specific token-value selectors first (`input[readonly]`, `textarea[readonly]`, `data-testid*="pit"`/`*="token"`) before falling back to any `code` block. If no modal matches, it returns null and the skill should re-snapshot rather than guess.

**Validate the captured string locally before saving — all six must hold:**

- **Length:** at least 60 characters (PITs in practice are JWT-shaped; 60 is a safer floor than 40 and rejects short padding strings).
- **Positive shape:** matches the regex `^[A-Za-z0-9._\-]+$` (alphanumeric, dots, dashes, underscores only — no spaces, quotes, angle brackets, or curly braces). May have a `pit-` prefix (third-party docs show it; official docs do not confirm — accept either form).
- **Mixed character set:** contains at least one digit AND at least one letter (rejects degenerate inputs like 60 dashes or 60 dots that pass the length + positive-shape checks).
- **Negative shape:** does not contain `<`, `>`, `{`, `}`, `"`, `'`, backtick, or any whitespace.
- **Not a placeholder:** is not the literal string `<your-token>` and does not contain the substring `example`.
- **Substring of warning text:** is NOT a substring of the modal's warning prose (`Don't forget to copy`, `won't be able to do it again`, etc.) — defends against the modal-detection heuristic mistakenly grabbing the warning text itself.

If validation fails, re-snapshot once and try alternate selectors. If still failing, stop and tell the user: *"I'm having trouble reading the connection key from the page — could you tell me what kind of box it's in (a long text field? a Copy button? a code block?). Don't paste the key itself — just describe what you see."*

The "don't paste the key itself" guard is critical: a user reading the prompt literally would otherwise paste the token into the chat transcript, where it persists in any user-side log and may be shared as a screenshot for support.

<!-- VERIFY (sandbox dry-run): exact token shape (with or without `pit-` prefix), full character set, length range, reveal-modal DOM structure (role/class), the warning text GHL shows, and whether `data-testid*="pit"` or `data-testid*="token"` is the actual attribute the picker uses. Tighten the regex and the modal-detection heuristic if the live shape is more constrained. -->

### Step 7 — Save the connection (silent), close the browser, and verify

**Pre-write user-confirmation (parallel-session race protection).** Before any write to `~/.claude.json`, tell the user: *"Just before I save your connection — please make sure Claude Code itself is closed in any other windows. I'll wait."* Wait for the user's confirmation. This prevents a concurrent Claude Code session (e.g. another open project) from racing the read-modify-write of `~/.claude.json` and losing one of the two writes.

Once they confirm, decide between the two save paths:

- **Default — direct JSON write** (single-user-system safe, multi-user-system safe, and avoids the process-table-leakage risk that comes with putting the PIT on a Bash command line where `ps aux | grep claude` can capture it during the sub-second `claude mcp add` invocation). Use this path on any shared dev box, multi-user macOS/Linux, CI runner, or whenever you cannot rule out other local users observing process tables.
- **`claude mcp add` (single-user-system convenience)** — the official CLI path, handles JSON shape correctly. Acceptable on a single-user laptop where no other local accounts exist. **Verified:** the CLI accepts multiple `--header` flags and stores them as a JSON object on `mcpServers.ghl.headers` (bench-tested locally on 2026-05-08 against Claude Code 2.1.121 on Windows — both `Authorization` and `locationId` headers landed correctly and the smoke handshake to `https://services.leadconnectorhq.com/mcp/` succeeded at the transport layer).

If you choose `claude mcp add`, prefer env-var indirection so the PIT does not appear in plaintext on the process command line:

```bash
CLAUDE_GHL_PIT="<PIT captured in Step 6>" \
  claude mcp add ghl \
    --scope user \
    --transport http \
    --header "Authorization: Bearer $CLAUDE_GHL_PIT" \
    --header "locationId: <LOC_ID captured in Step 3>" \
    -- https://services.leadconnectorhq.com/mcp/
unset CLAUDE_GHL_PIT
```

(Windows PowerShell: `$env:CLAUDE_GHL_PIT = "<PIT>"; claude mcp add ghl --scope user --transport http --header "Authorization: Bearer $env:CLAUDE_GHL_PIT" --header "locationId: <LOC_ID>" -- https://services.leadconnectorhq.com/mcp/; Remove-Item Env:CLAUDE_GHL_PIT`.)

The env var still appears in the spawned process's environment block (visible via `ps -e` on Linux), but `ps aux | grep` without `-e` will not show it — narrower exposure than baking the PIT into argv.

**Confirm registration before declaring success.** After `claude mcp add` returns, run:

```bash
claude mcp list | grep -i "^ghl"
```

(Windows PowerShell: `claude mcp list | Out-String -Stream | Select-String '^ghl'`. **Do not** add `2>&1` on PowerShell 5.1 — redirecting native-command stderr there wraps lines as `NativeCommandError` and sets `$?` false even on exit-0, breaking the success-detection heuristic.) If the line includes `ghl` and the URL `https://services.leadconnectorhq.com/mcp/`, registration landed at user scope. If the line is missing despite a zero exit code (e.g. project-scope shadow file at the working directory's `.claude.json` redirected the write), fall through to the direct-JSON-write path below.

#### Direct-JSON-write path (default for multi-user systems; fallback when `claude mcp add` registration is not visible)

**Always back up before write.** Regardless of parse success, snapshot the current file with `chmod 600` immediately after copy so the backup never sits on disk world-readable:

```bash
cp -p "$HOME/.claude.json" "$HOME/.claude.json.backup-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null
chmod 600 "$HOME/.claude.json.backup-"* 2>/dev/null
```

(Windows PowerShell: `Copy-Item "$env:USERPROFILE\.claude.json" "$env:USERPROFILE\.claude.json.backup-$(Get-Date -AsUTC -Format 'yyyyMMddTHHmmssZ')"` — default user-profile ACL is restrictive enough on Windows; no chmod equivalent needed. Skip if the source file does not exist.)

**Purge stale backups.** Plaintext PITs sitting in old backup files are revocable but typically not revoked, accumulating credential history. After a successful write below, prune any `~/.claude.json.backup-*` older than 7 days:

```bash
find "$HOME" -maxdepth 1 -name '.claude.json.backup-*' -mtime +7 -delete 2>/dev/null
```

(Windows PowerShell: `Get-ChildItem "$env:USERPROFILE\.claude.json.backup-*" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force`.) **Tell the user once, in plain English:** *"I've cleaned up some old connection-key backup files (older than a week). If you ever rotate a connection key in GoHighLevel, the old key only stays valid until you revoke it in GHL admin — the cleanup just removes the disk copies."*

Then read the existing file (use `Read` on `$HOME/.claude.json` for Mac/Linux/Bash, or `$env:USERPROFILE\.claude.json` for Windows PowerShell). Parse as JSON. If the file does not exist, the JSON to write is just the `ghl` entry block. If it exists but cannot be parsed, **STOP. Do not write.** Tell the user in plain English: *"Your settings file looks corrupted. I can rebuild it from scratch, but you'd lose any other connections you had set up (like Xero, HubSpot, etc.) and would need to reinstall those. I've saved a backup of the corrupted version. Want me to rebuild, or stop here so you can recover the file manually first?"* Wait for explicit consent before writing the fresh config.

**Safe-merge rails (prototype-pollution defence).** If the existing file is parseable, build the output object via **direct property assignment on a fresh object**, not via recursive deep-merge:

```javascript
// Pseudocode — implement the equivalent in whatever Bash/Node/Python tool the agent uses
const newGhlEntry = {
  url: "https://services.leadconnectorhq.com/mcp/",
  headers: {
    Authorization: "Bearer <PIT>",
    locationId: "<LOC_ID>"
  }
};
const output = Object.assign({}, existing);
output.mcpServers = Object.assign({}, existing.mcpServers || {});
// Reject any pre-existing dangerous keys before merge
for (const k of Object.keys(output.mcpServers)) {
  if (k === "__proto__" || k === "constructor" || k === "prototype") {
    throw new Error("Refusing to merge: existing file has dangerous key " + k);
  }
}
output.mcpServers.ghl = newGhlEntry;  // direct assignment, never spread an attacker-controlled object into our entry
```

**Do NOT use `_.merge`, `_.defaultsDeep`, or any third-party recursive-merge function** — Lodash's `merge` is famously prototype-polluting; any unguarded recursive merge that walks an attacker-controlled `__proto__` key opens a generic gadget surface for the rest of the Claude Code session.

**Rules:**

- Preserve every other entry the user already has — do not touch `mcpServers.<other>` keys.
- File permissions: on Mac/Linux, ensure the file is mode `600` (`chmod 600 "$HOME/.claude.json"`). On Windows, the default user-profile ACL is sufficient.
- Never echo the PIT back to the user. Never include it in any output visible to the user. Never log it to the conversation, even truncated. (A `pit-` prefix-only echo is acceptable for debugging — but never the full key.)

**After write, read back and validate.** Re-read the file with `Read`, parse as JSON, confirm all six:

1. The parse succeeds.
2. `mcpServers.ghl` exists.
3. `mcpServers.ghl.url` equals `https://services.leadconnectorhq.com/mcp/`.
4. `mcpServers.ghl.headers.Authorization` and `mcpServers.ghl.headers.locationId` are both present and non-empty.
5. Every other `mcpServers.*` entry that was present before the write is still present **with byte-identical contents** (URL, headers, command, args, env all unchanged from the pre-write parse). Not just key-presence — value-equality. A merge bug or attack could leave keys present but flip a sibling URL to an attacker-controlled relay.
6. No new top-level key in the parsed object equals `__proto__`, `constructor`, or `prototype`, AND `Object.getPrototypeOf(parsed)` is the standard Object prototype (not polluted).

If any of (1)-(6) fails, **do not** instruct the user to restart yet. Restore from the most recent `~/.claude.json.backup-<timestamp>` and retry the merge once. After two failures, stop. Drive the orphan-PIT cleanup (next paragraph) before bailing.

**Orphan-PIT cleanup on final failure.** If the write fails twice and the skill must abort, the PIT minted in Step 5 is now an orphaned write-capable credential sitting valid in GHL admin that the user does not know exists. Drive Playwright back to Settings → Private Integrations and delete the row whose name matches `Claude Code — <date captured in Step 5>` before bailing. If the deletion also fails (network down, page changed), tell the user explicitly: *"I created a connection key in your GoHighLevel admin earlier but couldn't save it on my side. Please open Settings → Private Integrations and delete the entry called 'Claude Code — [date]' to keep your account clean."*

Close the Playwright browser via `mcp__playwright__browser_close()`. The token now lives only in `~/.claude.json`.

Tell the user: *"I've saved your connection — let me check it works."*

The verification depends on whether the MCP server has reloaded in the current session:

- **If `mcp__ghl__*` tools are available** (the MCP server reloaded in-session): call `mcp__ghl__ghl_get_location`. If it returns an account name, capture it for the cross-check below.
- **If the tools are not yet available** (most likely on first setup, since the MCP config was just written): tell the user *"All saved. Please close GoHighLevel and Claude Code completely, then open Claude Code again so the connection becomes active. Once you're back, say 'test my GoHighLevel connection' and I'll verify it."*

If the verification tool returns an error:

- `401 Unauthorized` → *"The connection key didn't take — let me grab a fresh one."* Re-run Steps 4-6 to mint a new key and overwrite the config. Drive the orphan-PIT cleanup on the OLD key first if it was successfully written.
- `403 Insufficient scope` → *"Your connection key is missing a permission — let me re-create it with the right access."* Re-run Steps 4-6.
- `404 Location not found` / wrong-account data → *"Looks like the account ID didn't match. Let me re-check it."* Re-run Step 3 to re-capture, then update the config.
- Any other error → *"Something went wrong — let me try again."* Retry once; if still failing, re-run Phase 1 from Step 2.

**Account-name cross-check (S-M2).** Once `mcp__ghl__ghl_get_location` succeeds and returns a name, compare it to `<EXPECTED_NAME>` (captured in Step 2). Three cases:

- **Match** (case-insensitive substring either direction) → proceed to the success message.
- **Empty `<EXPECTED_NAME>`** (Step 2 couldn't capture a name) → ask the user: *"Just to confirm — I'm now connected to your GoHighLevel account named **[name from get_location]**. Is that the right one?"* Wait for yes/no. On no, abort and re-run Phase 1 from Step 2.
- **Mismatch** → tell the user: *"Hmm, I think I connected to the wrong account. The page said **[name from get_location]** but you opened **[EXPECTED_NAME]**. Let me try again."* Drive orphan-PIT cleanup on the new key, then re-run Phase 1 from Step 2.

Once the cross-check passes, tell the user, in one short message:

> "All done! I'm now connected to your GoHighLevel account **[name from get_location]**. You can ask me things like 'show me my pipelines', 'find the contact for jane@example.com', or 'what's on the calendar tomorrow'. Give it a try!"

If `<ACCESS_LEVEL>` was `read-only`, append: *"Heads up — I'm in read-only mode. If you ever want me to update opportunities, send messages, or create posts, just say 'upgrade my GoHighLevel connection to read-write' and I'll re-do this with broader access."*

---

## Available Tools

The HighLevel MCP server exposes **over 200 tools** across 20+ resource areas (count drifts as GHL ships new tools — last live count was around 207 against `https://services.leadconnectorhq.com/mcp/`). Exact tool names surface as `mcp__ghl__ghl_*` at runtime. The nine areas below cover the most common workshop operations; for everything else (invoices, estimates, custom objects, shipping, etc.), see **Additional resource areas** at the end of this section, the Prompt-to-Tool Mapping below, or tab-complete on `mcp__ghl__ghl_` in the tool selector.

### Contacts (6 tools)

| Tool | Purpose |
|---|---|
| `get_contact` | Fetch a single contact by ID |
| `get_contacts` | List contacts in the sub-account with pagination |
| `create_contact` | Create a new contact |
| `update_contact` | Patch an existing contact |
| `upsert_contact` | Create or update in one call (matches on email/phone) |
| `get_all_tasks` | List tasks across contacts |

**Use when:** The user asks to find a person, create/update a lead, or look up their assigned tasks.

**Example:**
```
User: "Find jane@example.com and tag her as VIP"
→ mcp__ghl__upsert_contact  (matches Jane by email, returns contactId)
→ mcp__ghl__add_tags         (contactId, tags: ["VIP"])
→ "Found Jane Doe and tagged her as VIP."
```

### Contacts Management (2 tools)

| Tool | Purpose |
|---|---|
| `add_tags` | Add one or more tags to a contact |
| `remove_tags` | Remove one or more tags from a contact |

**Use when:** Segmenting, opting in/out of lists, or applying workflow entry tags.

### Conversations (3 tools)

| Tool | Purpose |
|---|---|
| `search_conversations` | Find conversations by contact, channel, or query |
| `get_messages` | Fetch the message history for a conversation |
| `send_message` | Send a new message (SMS/Email/GMB/etc.) into a conversation |

**Use when:** Reading conversation history or sending a reply. For outbound SMS, use `mcp__ghl__ghl_send_sms` — it requires `confirmAction: true`, so confirm the body and recipient with the user before passing the flag. For outbound email use `mcp__ghl__ghl_send_email_message` (same `confirmAction: true` gate). Only fall back to Playwright if the user wants a UI-driven draft they can edit before sending.

### Opportunities & Pipelines (4 tools)

| Tool | Purpose |
|---|---|
| `get_pipelines` | List pipelines and their stages for the sub-account |
| `search_opportunities` | Find opportunities by pipeline, stage, status, or contact |
| `get_opportunity` | Fetch a single opportunity with full detail |
| `update_opportunity` | Move stages, change status (won/lost), or patch fields |

**Use when:** Looking at the sales pipeline, moving deals, marking won/lost, or searching by customer.

**Example:**
```
User: "Move the Acme Co deal to Proposal Sent"
→ mcp__ghl__get_pipelines          (find Proposal Sent stageId)
→ mcp__ghl__search_opportunities    (find Acme Co opportunityId)
→ Confirm source stage + target stage with the user
→ mcp__ghl__update_opportunity     (opportunityId, pipelineStageId)
```

### Calendar (2 tools)

| Tool | Purpose |
|---|---|
| `get_calendar_events` | List bookings for a calendar in a time range |
| `get_appointment_notes` | Read notes attached to an appointment |

**Use when:** "What's on the calendar tomorrow?", "Did anyone leave notes on the 3 PM discovery call?", etc.

> **Booking CRUD is in the MCP surface.** Use `mcp__ghl__ghl_create_appointment`, `mcp__ghl__ghl_update_appointment`, and `mcp__ghl__ghl_delete_appointment` (the delete tool requires `confirmAction: true`). For blocking time on a calendar without booking a contact, use `mcp__ghl__ghl_create_blocked_slot`. Only fall back to Playwright if the user wants UI-driven calendar manipulation.

### Payments (2 tools)

| Tool | Purpose |
|---|---|
| `list_transactions` | List payments / transactions for the sub-account |
| `get_order` | Fetch a single order by ID |

**Use when:** "What did Jane pay last month?", "Show me the order for this contact."

### Locations & Fields (2 tools)

| Tool | Purpose |
|---|---|
| `get_location` | Fetch details of the connected sub-account (name, timezone, etc.) |
| `get_custom_fields` | List custom fields defined for contacts/opportunities |

**Use when:** Confirming which sub-account is connected (run at the start of a session), or discovering field IDs before an update.

### Blogs (7 tools)

| Tool | Purpose |
|---|---|
| `get_blogs_by_location` | List all blogs for the sub-account |
| `get_blog_posts_by_blog_id` | List posts inside a blog |
| `create_blog_post` | Create a new blog post |
| `update_blog_post` | Edit an existing blog post |
| `get_blog_authors` | List available authors |
| `get_blog_categories` | List blog categories |
| `check_blog_url_slug` | Validate a URL slug before publishing |

**Use when:** Drafting, publishing, or editing blog content inside GHL.

### Email Templates (2 tools)

| Tool | Purpose |
|---|---|
| `get_email_templates` | List available email templates |
| `create_email_template` | Create a new email template |

**Use when:** Authoring a template for campaigns. Note that **sending** a one-off email uses `send_message` under Conversations, not these tools.

### Social Media (6 tools)

| Tool | Purpose |
|---|---|
| `get_social_media_accounts` | List connected social accounts |
| `get_social_media_statistics` | Pull reach/engagement stats |
| `create_social_media_post` | Schedule or publish a post |
| `update_social_media_post` | Edit an existing post |
| `get_social_media_post` | Fetch one post |
| `get_social_media_posts` | List posts with filtering |

**Use when:** Scheduling content across the user's connected social channels.

### Additional resource areas

The MCP also exposes full or partial coverage for: **invoices** (CRUD + schedules + templates + record-payment + void + send + text2pay), **estimates** (CRUD + templates + send), **subscriptions** (read + list), **transactions** (read + list), **orders + fulfillments** (read + create), **products + collections** (CRUD), **shipping zones + rates** (CRUD), **coupons** (CRUD), **custom objects** (schemas + records, CRUD), **associations + relations** (CRUD), **media library** (search + upload + delete), **surveys** (read + submissions), **workflows + campaigns** (read + add/remove contact), **bulk operations** (bulk-update-contacts, bulk-delete-social-media-posts), **verification** (`verify_email`), and **payment config** (late-fee, store-settings, payment-integrations, custom-payment-providers).

For these, tab-complete `mcp__ghl__ghl_<verb>_<resource>` to discover the right tool name, or browse the live MCP endpoint at `https://services.leadconnectorhq.com/mcp/` for the canonical reference. Common patterns: `get_*` / `get_*s` for read, `create_*` for create, `update_*` for patch, `delete_*` (with `confirmAction: true`) for destructive ops, `search_*` for filtered list, `send_*` (with `confirmAction: true`) for outbound messaging, `upsert_*` for create-or-update.

---

## Prompt-to-Tool Mapping

| What the user says | Tool(s) to use |
|---|---|
| "What GHL account am I on?" | `get_location` |
| "Find jane@example.com" | `get_contacts` or `upsert_contact` |
| "Add a new contact" | `create_contact` (or `upsert_contact` if you want idempotency) |
| "Tag this contact as VIP" | `add_tags` |
| "What are my pipelines?" | `get_pipelines` |
| "List opportunities in 'Proposal Sent'" | `search_opportunities` (filter by stage) |
| "Move Acme Co to 'Won'" | `get_pipelines` → `search_opportunities` → `update_opportunity` |
| "What's on the calendar tomorrow?" | `get_calendar_events` |
| "Show me recent conversations with Jane" | `search_conversations` → `get_messages` |
| "Send Jane a follow-up email" | `send_message` (type: Email) |
| "How much has Jane paid?" | `list_transactions` filtered by contact |
| "Draft a blog post titled …" | `create_blog_post` |
| "Schedule a LinkedIn post for Thursday" | `create_social_media_post` |

---

## Playwright Fallback (UI-only surfaces)

Use [playwright-skill](../playwright-skill/SKILL.md) **only** for the narrow set of operations the MCP does not cover:

| Task | Why MCP doesn't cover it | Playwright approach |
|---|---|---|
| **Edit the visual workflow builder** | Not in the API | Open the workflow, let the user edit live |
| **Full email campaign authoring** (builder UI) | MCP has `create_email_template` and `create_email_campaign` for header-level campaign creation but not the full visual builder | Open the campaign builder and hand control back |

**Rules for Playwright fallback:**
- Reuse the saved storage state at `~/.claude/state/ghl-storage.json`. If missing or expired (you land on the login page), run a one-time login script first.
- Write every Playwright script to `/tmp/ghl-*.js`, never inside the skill dir.
- Launch `headless: false` so the user can see (and take over) what's happening.
- **Never auto-click Send, Delete, or Cancel.** Draft the state and hand the browser to the user.
- If a selector fails, **stop and ask** — GHL's UI changes often; don't retry destructive clicks.

---

## Error Handling

When a GHL MCP tool call fails, diagnose and respond in plain English. Never show raw JSON errors or the connection key (the PIT).

| Error | What to say | How to fix |
|---|---|---|
| 401 / "Unauthorized" | "Your GoHighLevel connection key is no longer valid — let me help you reconnect." | Run **Phase 1 from Step 4** (mint a fresh PIT and overwrite the saved connection) |
| 403 / "Insufficient scope" | "Your connection key is missing a permission for this action." | Run **Phase 1 from Step 4** to re-create the connection key with the full hosted-MCP permission set |
| 404 on a contactId/opportunityId | "I couldn't find that record in your sub-account." | Try `get_contacts` / `search_opportunities` with the user's hint instead |
| "Wrong location" / data from another sub-account | "I'm connected to a different sub-account than you expected." | Run **Phase 1 from Step 2** to re-capture the correct sub-account ID and overwrite the saved connection |
| 429 / rate limit | "GHL is rate-limiting me — I'll wait a few seconds and retry." | Wait 5s, retry once. On a mutating call, re-confirm with the user before retry. |
| Connection unreachable / network error | "I can't reach HighLevel right now." | Check `curl -I https://services.leadconnectorhq.com/mcp/` (or `Invoke-WebRequest -Method Head https://services.leadconnectorhq.com/mcp/` on Windows), retry in a minute |

---

## Scope Limitations

The GHL connector **can** (via MCP):
- Read and create/update contacts (`get_contacts`, `create_contact`, `update_contact`, `upsert_contact`, `get_contact`)
- Tag and untag contacts (`add_tags`, `remove_tags`)
- Read contact tasks (`get_all_tasks`)
- Read and update opportunities; read pipelines (`get_pipelines`, `search_opportunities`, `get_opportunity`, `update_opportunity`)
- Read calendar events and appointment notes
- Send messages (SMS/Email/etc.) via `send_message`, search conversations, read messages
- Read transactions and orders
- Manage blog posts (CRUD) and social media posts (CRUD)
- Create/list email templates
- Read the connected location and custom fields

The GHL connector **cannot** (needs Playwright fallback, or isn't exposed at all):
- Draft an SMS for user review before sending (send is immediate via MCP)
- Create or cancel a calendar booking
- Edit the visual workflow builder
- Author full email campaigns in the campaign builder
- Manage agency-wide settings (this skill operates at sub-account scope by default)
- Delete contacts or opportunities
- Create custom fields or manage forms/surveys
- Manage multiple sub-accounts simultaneously (one `locationId` per `~/.claude.json` entry)

---

## Behaviour Guidelines

- **Verify connection first** — at the start of a session that touches GHL, call `get_location` to confirm which sub-account is connected. Report the name back to the user before mutating anything.
- **Confirm before mutating** — always confirm with the user before creating or updating contacts, moving opportunities, sending messages, or publishing blog/social posts. Echo the contact's name, opportunity title, or post body back before the tool call.
- **Default to sub-account scope** — never attempt agency-wide changes without explicit user confirmation.
- **Send is immediate in MCP** — `send_message` goes out the moment it's called. If the user wants to "draft" or "review first," use the Playwright fallback, not `send_message`.
- **Never auto-click Send, Delete, or Cancel in the browser** — Playwright drafts the state; the user clicks.
- **One step at a time** — don't dump all results at once. Summarise counts first ("You have 12 opportunities in 'Proposal Sent'"), then offer to show details.
- **Mask PII when echoing** — when summarising contacts back in the transcript, partially mask phone numbers (`+61 400 *** 000`) and emails (`j***@example.com`) unless the user explicitly asks for the full value.
- **Token hygiene** — never echo `Authorization` or the connection key (the PIT) to the transcript, never write them to a file inside the project, never include them in a commit. The connection key lives in `~/.claude.json` only.
- **Selector failure in Playwright** → stop and ask the user. Never blind-retry a destructive click.
- **Wrong-location errors** → stop, report the locationId to the user, and ask them to confirm before you edit `~/.claude.json`.

---

## Related Skills

- **monday-connector** — canonical Hosted-bearer-PAT install pattern; GHL's Phase 1 mirrors monday's structure with two-header (Authorization + locationId) variations
- **first-run-setup** — source pattern for conversational bootstrap; Phase 1 above follows the same rules
- **playwright-skill** — required fallback engine for UI-only surfaces (visual workflow builder, full email campaign authoring)
- **xero-connector** — sibling MCP connector for accounting
- **connector-recommender** — recommending which connectors to set up
- **superpowers:systematic-debugging** (official Anthropic Superpowers plugin, optional but recommended) — troubleshooting PIT scope or MCP connection errors
- **email-composer** — drafting campaign copy before pushing it into a GoHighLevel email template
- **n8n-workflow-patterns** — building GoHighLevel-triggered automations
