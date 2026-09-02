# Xero portal walkthrough: Playwright fallback recipe

Lane 3 of the doctrine ladder. Use Claude's native browser lane first, then `agent-browser`. These verbatim tool calls stay documented for Codex sessions, servers, and any run where lanes 1 and 2 are unavailable.

Every step below is still a goal, not a hardcoded contract. Snapshot, read what is actually rendered, act, re-snapshot after each state change. Xero ships UI changes often.

If Playwright MCP tools (`mcp__plugin_playwright_playwright__*`) are missing from the session, **this lane is unavailable for the current run and cannot be made available mid-session.** Go back to lane 1 or lane 2 and finish the install there.

There is no `claude mcp add-from-marketplace` subcommand — that line used to sit here, with its failure hidden behind `2>/dev/null || true`, so it silently did nothing and the run carried on calling tools that were never going to exist. The real command registers the server for *next* start-up, because MCP servers only load at launch:

```bash
claude mcp add playwright -- npx @playwright/mcp@latest
```

Run that only when lanes 1 and 2 are both genuinely unavailable, tell the user it needs a full quit and reopen before it does anything, and never treat it as an in-run recovery.

---

## 2.1: Open the developer portal

```
mcp__plugin_playwright_playwright__browser_navigate
  url: https://developer.xero.com/app/manage
```

## 2.2: Verify sign-in

```
mcp__plugin_playwright_playwright__browser_snapshot
```

Scan for the user's name or email, a **New app** button, and any "Verify your email" banner.

## 2.3: New app

```
mcp__plugin_playwright_playwright__browser_click
  element: "New app button"
  ref: <ref from snapshot>
```

## 2.4: Fill the creation form

```
mcp__plugin_playwright_playwright__browser_fill_form
  fields:
    - name: App name
      value: "Claude Assistant"
    - name: Company or application URL
      value: "https://claude.ai"
    - name: Integration type
      value: "Custom connection"
```

If Integration type renders as a radio group or dropdown, click the specific "Custom connection" option instead.

## 2.5: Terms and create

```
mcp__plugin_playwright_playwright__browser_click
  element: "terms and conditions checkbox"

mcp__plugin_playwright_playwright__browser_click
  element: "Create app button"
```

## 2.6: Select the organisation

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Organisation"

mcp__plugin_playwright_playwright__browser_click
  element: "organisation dropdown"
```

Snapshot the open dropdown, then click the option matching `ORG_NAME`:

```
mcp__plugin_playwright_playwright__browser_click
  element: "<ORG_NAME> option in dropdown"
```

## 2.7: Scopes into view

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: "() => document.querySelector('[data-testid=\"scopes\"]')?.scrollIntoView()"
```

Then one `browser_click` per checkbox, targeting by label.

## 2.8: Save

```
mcp__plugin_playwright_playwright__browser_click
  element: "Save button"

mcp__plugin_playwright_playwright__browser_wait_for
  text: "Saved" OR "successful" OR similar confirmation
```

## 2.9: Activation

Payment method already on file:

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Connection active" OR "Activated" OR "Subscription confirmed"
  timeout: 30000
```

No payment method on file, after the user says they have entered their card:

```
mcp__plugin_playwright_playwright__browser_wait_for
  text: "Connection active"
  timeout: 300000
```

## 2.10: Client ID extractor

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: |
    () => {
      // Xero displays the Client ID in a read-only text field or <code> element
      const selectors = [
        '[data-testid="client-id"]',
        'input[name="clientId"]',
        'input[aria-label*="Client ID"]',
        'code.client-id',
        // Fallback: find the label "Client ID" and walk to the adjacent value
      ];
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (el) return el.value || el.textContent.trim();
      }
      // Fallback: label-based search
      const labels = [...document.querySelectorAll('label, dt, .label')];
      for (const lbl of labels) {
        if (/client\s*id/i.test(lbl.textContent)) {
          const val = lbl.nextElementSibling?.textContent?.trim()
                   || lbl.parentElement?.querySelector('input,code,span')?.textContent?.trim();
          if (val && val.length > 20) return val;
        }
      }
      return null;
    }
```

Validate: hex-like, 32+ characters, no whitespace. On failure, re-snapshot and try a fresh selector strategy. Two attempts before changing approach.

## 2.11: Generate and capture the Client Secret

```
mcp__plugin_playwright_playwright__browser_click
  element: "Generate a secret button"
```

The secret is shown once. Capture immediately:

```
mcp__plugin_playwright_playwright__browser_evaluate
  function: |
    () => {
      // The secret often appears in a modal <code> or <input readonly>
      const selectors = [
        '[data-testid="client-secret"]',
        'input[name="clientSecret"][readonly]',
        'input[aria-label*="Client Secret"]',
        '.modal code',
        '.reveal-secret',
      ];
      for (const sel of selectors) {
        const el = document.querySelector(sel);
        if (el) {
          const v = el.value || el.textContent.trim();
          if (v && v.length > 30) return v;
        }
      }
      return null;
    }
```

Validate: 40+ characters, base64-like charset, no whitespace.

If the selectors miss, `browser_snapshot` the full accessibility tree and find the secret element by its surrounding warning text ("Save this secret", "it will not be shown again"), then extract via its ref.

## 2.12: Close the reveal

```
mcp__plugin_playwright_playwright__browser_click
  element: "I've saved the secret" OR "Close" OR "Done" button
```

Read `window.location.href` before closing the browser. After close there is no page left to read.
