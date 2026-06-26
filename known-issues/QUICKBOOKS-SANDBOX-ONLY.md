# Known Issue, QuickBooks: Sandbox Mode Only

**Status:** Known limitation (by design)
**Affects:** quickbooks-connector
**Symptom:** Connector connects successfully but does not show real business data, only test/demo data

---

## What Is Happening

The QuickBooks connector uses `qbo-cli` (github.com/voska/qbo-cli), which currently **only supports QuickBooks Online sandbox environments**. Connecting to a production (live) QuickBooks company is not supported by this connector version.

This means:
- You can run the full setup and authenticate without errors
- All commands work correctly against the sandbox
- However, the invoices, customers, and transactions shown are **test data**, not your real books

---

## How to Tell Which Mode You Are In

When you run:
```bash
qbo company info
```

If the company name includes "Sandbox" (e.g., `Sandbox Company_US_1`) or displays generic placeholder data, you are in sandbox mode.

---

## Workaround

At this time, there is no supported path to point the connector at a live QuickBooks company through `qbo-cli`.

**Options:**

1. **Use the Xero connector instead**, if you have a Xero account, the xero-connector fully supports live production data.

2. **Use the QuickBooks Online web interface**, for live data queries, ask your assistant to use Playwright to navigate the QuickBooks web UI directly.

3. **Wait for a production-mode update**, tracking this at `github.com/voska/qbo-cli`. When production support is added, the connector will be updated.

---

## Related

- Connector docs: `skills/quickbooks-connector/SKILL.md`
- Xero alternative: `skills/xero-connector/SKILL.md`
