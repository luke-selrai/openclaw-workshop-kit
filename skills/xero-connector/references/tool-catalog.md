# Xero MCP tool catalog

Regenerated from the installed `@xeroapi/xero-mcp-server` v0.0.17 source (registered tool names in `dist/tools/`). **51 tools total**: 18 read, 19 write, 14 payroll. Every tool is reachable as `mcp__xero__<name>` once the connection is live. A second organisation installed under a slugged server name exposes the same set as `mcp__xero-<orgslug>__<name>`.

There are no single-record `get-*` tools for accounting data (no `get-invoice`, no `get-contact`) — fetch a single record through the matching `list-*` tool with filters. The only `get-*` tool is payroll's `get-timesheet`.

## Read (safe) — 18 tools

| Category | Tools |
|---|---|
| Org | `list-organisation-details` |
| Invoices | `list-invoices` |
| Contacts | `list-contacts` |
| Accounts | `list-accounts` |
| Bank | `list-bank-transactions`, `list-payments` |
| Items | `list-items` |
| Quotes | `list-quotes` |
| Credit notes | `list-credit-notes` |
| Journals | `list-manual-journals` |
| Tax | `list-tax-rates` |
| Groups | `list-contact-groups` |
| Tracking | `list-tracking-categories` |
| Reports | `list-profit-and-loss`, `list-report-balance-sheet`, `list-trial-balance`, `list-aged-receivables-by-contact`, `list-aged-payables-by-contact` |

## Write (confirm first, then call) — 19 tools

**Registered by the server, and unreachable through this connector — by design, permanently.** Two independent locks sit in front of every tool below. The scope pin means the token never carries write authority, so a call returns `403 insufficient_scope`; the harness deny rules mean the call does not leave the machine at all. A 403 here is the design holding, not a scope to go and tick, and there is no procedure in SKILL.md for unlocking them: the reader's own organisation is real books. Writes belong on the Xero Demo Company.

| Category | Tools |
|---|---|
| Invoices | `create-invoice` (DRAFT), `update-invoice` |
| Contacts | `create-contact`, `update-contact` |
| Quotes | `create-quote`, `update-quote` |
| Credit notes | `create-credit-note`, `update-credit-note` |
| Payments | `create-payment` |
| Bank | `create-bank-transaction`, `update-bank-transaction` |
| Items | `create-item`, `update-item` |
| Journals | `create-manual-journal`, `update-manual-journal` |
| Tracking | `create-tracking-category`, `update-tracking-category`, `create-tracking-options`, `update-tracking-options` |

## Payroll (NZ and UK only) — 14 tools

Available only when the payroll scopes were ticked at setup. Timesheet tool names carry no `payroll-` prefix.

Reads: `list-payroll-employees`, `list-payroll-employee-leave`, `list-payroll-employee-leave-balances`, `list-payroll-employee-leave-types`, `list-payroll-leave-periods`, `list-payroll-leave-types`, `list-timesheets`, `get-timesheet`

Writes — denied, same two locks as the accounting mutators: `create-timesheet`, `add-timesheet-line`, `update-timesheet-line`, `approve-timesheet`, `revert-timesheet`, `delete-timesheet` (the server's only delete tool). `approve-timesheet` is not hypothetical: an unauthorised approval of a real employee's timesheet is what closed the global write allowlist on 2026-08-08.

## Call discipline

- **Every mutator here is denied.** A refusal is the expected result, not a fault to work around.
- Roughly 60 calls per minute per tenant. On 429, wait 10 seconds and retry once.
- The `create-invoice`-produces-a-DRAFT and verify-after-every-write conventions belong to the `demo` tenant lane, which is the only place a write runs.
